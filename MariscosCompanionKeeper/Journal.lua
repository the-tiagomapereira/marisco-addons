-- Marisco's Companion Keeper - Journal
-- Reads the companion pets this account owns, and builds the /mck probe report.
-- Everything that touches the client API is wrapped in pcall: Forever is still in beta and
-- some values may be missing or restricted.

local ADDON, ns = ...

local J = {
    pets       = {},     -- sorted list of owned companions
    byID       = {},     -- petID -> entry
    state      = "loading", -- "loading" | "ready" | "empty" | "noapi"
    mode       = nil,    -- "journal" (C_PetJournal) | "companions" (GetCompanionInfo) | nil
    numOwned   = 0,      -- what the client says we own
    summonedID = nil,    -- petID of the companion out in the world
    loaded     = false,  -- the client has sent its first journal update (or we gave up waiting)
    errors     = {},
}
ns.Journal = J

local PJ = C_PetJournal

local function LogError(msg)
    table.insert(J.errors, tostring(msg))
    if #J.errors > 25 then table.remove(J.errors, 1) end
end

-- pcall that keeps every return value
local function Call(fn, ...)
    if type(fn) ~= "function" then return false end
    local r = { pcall(fn, ...) }
    if not r[1] then
        LogError(r[2])
        return false
    end
    return true, unpack(r, 2, table.maxn(r))
end

local function Str(v)
    local ok, s = pcall(tostring, v)
    return ok and s or "<unreadable>"
end

local function NonEmpty(s)
    local ok, res = pcall(function() return type(s) == "string" and s ~= "" end)
    return ok and res
end

------------------------------------------------------------------------------------------
-- C_PetJournal reading
------------------------------------------------------------------------------------------

-- Fill in model and name details from the pet's own record.
local function Enrich(e)
    if PJ and PJ.GetPetInfoByPetID then
        local ok, speciesID, customName, level, xp, maxXp, displayID, favorite, name, icon, petType, creatureID =
            Call(PJ.GetPetInfoByPetID, e.id)
        if ok then
            e.speciesID   = e.speciesID or speciesID
            e.customName  = e.customName or customName
            e.speciesName = e.speciesName or name
            e.icon        = e.icon or icon
            e.creatureID  = e.creatureID or creatureID
            e.displayID   = displayID
            if e.favorite == nil then e.favorite = favorite end
        end
    end
    e.name = NonEmpty(e.customName) and e.customName or (NonEmpty(e.speciesName) and e.speciesName) or "Unknown companion"
    e.icon = e.icon or ns.ICON
end

local function ReadIndexList(out)
    local ok, numPets, numOwned = Call(PJ.GetNumPets)
    if not ok then return 0 end
    numPets = tonumber(numPets) or 0
    for i = 1, numPets do
        pcall(function()
            local ok2, petID, speciesID, owned, customName, level, favorite, isRevoked, speciesName, icon, petType, creatureID =
                Call(PJ.GetPetInfoByIndex, i)
            if ok2 and petID and owned and not isRevoked then
                out[#out + 1] = {
                    id = petID, speciesID = speciesID, customName = customName,
                    speciesName = speciesName, icon = icon, creatureID = creatureID,
                    favorite = favorite, level = level,
                }
            end
        end)
    end
    return tonumber(numOwned) or 0
end

-- The journal list follows the player's own filters (search, collected, families, sources).
-- If that hides some owned pets, open every filter for one read and put them back after.
local function WithAllFilters(fn)
    local COLLECTED     = LE_PET_JOURNAL_FILTER_COLLECTED or 1
    local NOT_COLLECTED = LE_PET_JOURNAL_FILTER_NOT_COLLECTED or 2
    local saved = { types = {}, sources = {} }
    J.suppress = true

    pcall(function()
        if PJ.IsFilterChecked and PJ.SetFilterChecked then
            saved.collected    = PJ.IsFilterChecked(COLLECTED)
            saved.notCollected = PJ.IsFilterChecked(NOT_COLLECTED)
            PJ.SetFilterChecked(COLLECTED, true)
            PJ.SetFilterChecked(NOT_COLLECTED, false)
        end
        if PJ.GetNumPetTypes and PJ.IsPetTypeChecked and PJ.SetPetTypeFilter then
            for i = 1, PJ.GetNumPetTypes() do
                saved.types[i] = PJ.IsPetTypeChecked(i)
                PJ.SetPetTypeFilter(i, true)
            end
        end
        if PJ.GetNumPetSources and PJ.IsPetSourceChecked and PJ.SetPetSourceChecked then
            for i = 1, PJ.GetNumPetSources() do
                saved.sources[i] = PJ.IsPetSourceChecked(i)
                PJ.SetPetSourceChecked(i, true)
            end
        end
        if PJ.ClearSearchFilter then PJ.ClearSearchFilter() end
    end)

    local ok, err = pcall(fn)
    if not ok then LogError(err) end

    pcall(function()
        if saved.collected ~= nil then
            PJ.SetFilterChecked(COLLECTED, saved.collected)
            PJ.SetFilterChecked(NOT_COLLECTED, saved.notCollected)
        end
        for i, v in pairs(saved.types) do PJ.SetPetTypeFilter(i, v) end
        for i, v in pairs(saved.sources) do PJ.SetPetSourceChecked(i, v) end
    end)

    C_Timer.After(0.5, function() J.suppress = false end)
end

local function ReadJournal(list)
    -- Newer clients can hand over every owned pet directly.
    if PJ.GetOwnedPetIDs then
        local ok, ids = Call(PJ.GetOwnedPetIDs)
        if ok and type(ids) == "table" and #ids > 0 then
            for _, id in ipairs(ids) do list[#list + 1] = { id = id } end
            J.numOwned = #ids
            return
        end
    end

    J.numOwned = ReadIndexList(list)

    local journalOpen = PetJournal and PetJournal.IsShown and PetJournal:IsShown()
    if #list < J.numOwned and not journalOpen then
        wipe(list)
        WithAllFilters(function()
            local owned = ReadIndexList(list)
            if owned > 0 then J.numOwned = owned end
        end)
    end
end

------------------------------------------------------------------------------------------
-- Classic-style companions (fallback)
------------------------------------------------------------------------------------------

local function ReadCompanions(list)
    local ok, n = Call(GetNumCompanions, "CRITTER")
    n = ok and tonumber(n) or 0
    J.numOwned = n
    for i = 1, n do
        pcall(function()
            local ok2, creatureID, creatureName, spellID, icon, isSummoned = Call(GetCompanionInfo, "CRITTER", i)
            if ok2 and (spellID or creatureID) then
                list[#list + 1] = {
                    id = "critter:" .. Str(spellID or creatureID),
                    speciesName = creatureName, icon = icon, creatureID = creatureID,
                    spellID = spellID, summoned = isSummoned and true or false, index = i,
                }
            end
        end)
    end
end

------------------------------------------------------------------------------------------
-- Scan
------------------------------------------------------------------------------------------

function J:UpdateSummoned()
    local before = self.summonedID
    self.summonedID = nil
    if self.mode == "journal" and PJ.GetSummonedPetGUID then
        local ok, guid = Call(PJ.GetSummonedPetGUID)
        if ok and guid and self.byID[guid] then self.summonedID = guid end
    elseif self.mode == "companions" then
        for _, e in ipairs(self.pets) do
            if e.index then
                local ok, _, _, _, _, isSummoned = Call(GetCompanionInfo, "CRITTER", e.index)
                e.summoned = ok and isSummoned and true or false
                if e.summoned then self.summonedID = e.id end
            end
        end
    end
    return before ~= self.summonedID
end

function J:Scan()
    local list = {}

    if PJ and PJ.GetNumPets and (PJ.GetPetInfoByIndex or PJ.GetOwnedPetIDs) then
        self.mode = "journal"
        ReadJournal(list)
    elseif GetNumCompanions and GetCompanionInfo then
        self.mode = "companions"
        ReadCompanions(list)
    else
        self.mode = nil
    end

    -- de-duplicate, enrich, sort
    local seen, clean = {}, {}
    for _, e in ipairs(list) do
        if e.id and not seen[e.id] then
            seen[e.id] = true
            Enrich(e)
            clean[#clean + 1] = e
        end
    end
    pcall(table.sort, clean, function(a, b)
        local an, bn = strlower(a.name), strlower(b.name)
        if an == bn then return Str(a.id) < Str(b.id) end
        return an < bn
    end)

    self.pets = clean
    wipe(self.byID)
    for _, e in ipairs(clean) do self.byID[e.id] = e end

    if not self.mode then
        self.state = "noapi"
    elseif #clean > 0 then
        self.state = "ready"
        self.loaded = true
    elseif self.loaded then
        self.state = "empty"
    else
        self.state = "loading"
    end

    self:UpdateSummoned()
    if ns.UI then ns.UI:Refresh() end
end

function J:RequestScan(delay)
    if self.pending then return end
    self.pending = true
    C_Timer.After(delay or 0.3, function()
        self.pending = false
        self:Scan()
    end)
end

function J:Get(id) return id and self.byID[id] end

-- Summon a companion, or dismiss it if it is already out.
-- Returns true, or false and a message to show the player.
function J:ToggleSummon(id)
    local e = self:Get(id)
    if not e then return false, "That companion isn't in your Companion Journal right now." end
    if InCombatLockdown and InCombatLockdown() then
        return false, "You can't summon a companion while in combat."
    end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then
        return false, "You can't summon a companion while dead."
    end

    local isOut = (self.summonedID == id)

    if self.mode == "journal" then
        if not isOut and PJ.PetIsSummonable then
            local ok, can, _, errText = Call(PJ.PetIsSummonable, id)
            local blocked = false
            pcall(function() blocked = ok and can == false end)
            if blocked then
                return false, NonEmpty(errText) and errText or "This companion can't be summoned right now."
            end
        end
        if isOut and PJ.DismissSummonedPet then
            -- Forever's version needs the pet: DismissSummonedPet(petID).
            if not Call(PJ.DismissSummonedPet, id) then
                -- fall back to summoning the same pet again, which sends it back
                if not (PJ.SummonPetByGUID and Call(PJ.SummonPetByGUID, id)) then
                    return false, "Summoning back failed: " .. Str(self.errors[#self.errors])
                end
            end
        elseif PJ.SummonPetByGUID then
            -- Summoning the companion that is already out dismisses it.
            if not Call(PJ.SummonPetByGUID, id) then
                return false, "Summoning failed: " .. Str(self.errors[#self.errors])
            end
        else
            return false, "This client doesn't let addons summon companions."
        end
    elseif self.mode == "companions" then
        if isOut and DismissCompanion then
            Call(DismissCompanion, "CRITTER")
        elseif CallCompanion and e.index then
            if not Call(CallCompanion, "CRITTER", e.index) then
                return false, "Summoning failed: " .. Str(self.errors[#self.errors])
            end
        else
            return false, "This client doesn't let addons summon companions."
        end
    else
        return false, "The Companion Journal isn't available."
    end

    -- COMPANION_UPDATE normally reports the change; check again in case it doesn't arrive.
    for _, delay in ipairs({ 0.5, 1.5, 3 }) do
        C_Timer.After(delay, function()
            if J:UpdateSummoned() and ns.UI then ns.UI:Refresh() end
        end)
    end
    return true
end

function J:Init()
    local ev = CreateFrame("Frame")
    for _, name in ipairs({ "PET_JOURNAL_LIST_UPDATE", "COMPANION_LEARNED", "COMPANION_UNLEARNED",
                            "COMPANION_UPDATE", "UPDATE_SUMMONPETS_ACTION", "NEW_PET_ADDED", "PET_JOURNAL_PET_DELETED" }) do
        pcall(ev.RegisterEvent, ev, name)
    end
    ev:SetScript("OnEvent", function(_, event)
        if event == "COMPANION_UPDATE" or event == "UPDATE_SUMMONPETS_ACTION" then
            if J:UpdateSummoned() and ns.UI then ns.UI:Refresh() end
            return
        end
        if J.suppress then return end
        if event == "PET_JOURNAL_LIST_UPDATE" then J.loaded = true end
        J:RequestScan()
    end)

    self:Scan()
    -- The journal can be empty for a moment after login; stop waiting after a few seconds.
    C_Timer.After(6, function()
        if not J.loaded then
            J.loaded = true
            J:Scan()
        end
    end)
end

------------------------------------------------------------------------------------------
-- Probe report (/mck probe)
------------------------------------------------------------------------------------------

local function Vals(...)
    local t = {}
    for i = 1, select("#", ...) do t[i] = Str((select(i, ...))) end
    return table.concat(t, ", ")
end

-- Call a function and list its return values (without the pcall status).
local function CallVals(fn, ...)
    local r = { Call(fn, ...) }
    if not r[1] then return "error: " .. Str(J.errors[#J.errors]) end
    if table.maxn(r) < 2 then return "(nothing)" end
    return Vals(unpack(r, 2, table.maxn(r)))
end

function J:BuildProbeReport()
    local L = {}
    local function add(s) L[#L + 1] = s end

    add(("%s %s - Companion Journal report"):format(ns.TITLE, ns.VERSION_LABEL))
    add("Date: " .. Str(date("%Y-%m-%d %H:%M")))
    if GetBuildInfo then add("Build: " .. Vals(GetBuildInfo())) end
    if GetLocale then add("Locale: " .. Str(GetLocale())) end
    add("")

    add("== C_PetJournal ==")
    if not PJ then
        add("C_PetJournal: missing")
    else
        local keys = {}
        for k, v in pairs(PJ) do if type(v) == "function" then keys[#keys + 1] = k end end
        table.sort(keys)
        add(("Functions (%d): %s"):format(#keys, table.concat(keys, " ")))
        add("")

        if PJ.GetNumPets then
            add("GetNumPets(): " .. CallVals(PJ.GetNumPets))
        end
        if PJ.GetNumCollectedInfo then
            add("GetNumCollectedInfo(): " .. CallVals(PJ.GetNumCollectedInfo))
        end
        if PJ.GetOwnedPetIDs then
            local ok, ids = Call(PJ.GetOwnedPetIDs)
            add("GetOwnedPetIDs(): " .. (ok and type(ids) == "table" and (#ids .. " ids") or Str(ids)))
        end
        if PJ.GetSummonedPetGUID then
            add("GetSummonedPetGUID(): " .. CallVals(PJ.GetSummonedPetGUID))
        end
        if PJ.IsJournalUnlocked then
            add("IsJournalUnlocked(): " .. CallVals(PJ.IsJournalUnlocked))
        end
        if PJ.IsFilterChecked then
            add("Filter collected / not collected: " ..
                CallVals(PJ.IsFilterChecked, LE_PET_JOURNAL_FILTER_COLLECTED or 1) .. " / " ..
                CallVals(PJ.IsFilterChecked, LE_PET_JOURNAL_FILTER_NOT_COLLECTED or 2))
        end
        if PJ.GetNumPetTypes then add("GetNumPetTypes(): " .. CallVals(PJ.GetNumPetTypes)) end
        if PJ.GetNumPetSources then add("GetNumPetSources(): " .. CallVals(PJ.GetNumPetSources)) end
        add("")

        if PJ.GetNumPets and PJ.GetPetInfoByIndex then
            local ok, n = Call(PJ.GetNumPets)
            n = ok and tonumber(n) or 0
            add(("GetPetInfoByIndex (first %d of %d in the current filtered list):"):format(math.min(n, 12), n))
            add("  petID, speciesID, owned, customName, level, favorite, isRevoked, speciesName, icon, petType, companionID, ...")
            for i = 1, math.min(n, 12) do
                add(("  [%d] %s"):format(i, CallVals(PJ.GetPetInfoByIndex, i)))
            end
            add("")
        end
    end

    add("== Classic companions ==")
    add("GetNumCompanions: " .. (GetNumCompanions and "present" or "missing") ..
        ", GetCompanionInfo: " .. (GetCompanionInfo and "present" or "missing") ..
        ", CallCompanion: " .. (CallCompanion and "present" or "missing"))
    if GetNumCompanions then
        local ok, n = Call(GetNumCompanions, "CRITTER")
        add("GetNumCompanions(\"CRITTER\"): " .. Str(n))
        n = ok and tonumber(n) or 0
        for i = 1, math.min(n, 8) do
            add(("  [%d] %s"):format(i, CallVals(GetCompanionInfo, "CRITTER", i)))
        end
    end
    add("Other: C_MountJournal " .. (C_MountJournal and "present" or "missing") ..
        ", C_PetBattles " .. (C_PetBattles and "present" or "missing") ..
        ", C_XMLUtil " .. (C_XMLUtil and "present" or "missing"))
    add("")

    add("== What the addon sees ==")
    add(("Mode: %s   State: %s   Client says owned: %s   Companions listed: %d")
        :format(Str(self.mode), Str(self.state), Str(self.numOwned), #self.pets))
    add("Summoned: " .. Str(self.summonedID and self.byID[self.summonedID] and self.byID[self.summonedID].name or "none"))
    for i, e in ipairs(self.pets) do
        if i > 25 then add(("  ... and %d more"):format(#self.pets - 25)) break end
        add(("  %d. %s | id %s | species %s | creature %s | display %s | icon %s")
            :format(i, Str(e.name), Str(e.id), Str(e.speciesID), Str(e.creatureID), Str(e.displayID), Str(e.icon)))
    end
    local sel = ns.db and ns.db.selected
    add("Chosen companion: " .. (sel and (Str(sel.name) .. " (" .. Str(sel.id) .. ")") or "none"))
    if ns.Buddy and ns.Buddy.Position then
        local x, y, inst = ns.Buddy:Position()
        add("Walk together position: " .. (x and (("%.1f, %.1f (area %s)"):format(x, y, Str(inst))) or "not available"))
        add("UnitPosition: " .. CallVals(UnitPosition, "player"))
    end
    add("")

    add("== Errors ==")
    if #self.errors == 0 then add("none") end
    for _, e in ipairs(self.errors) do add("  " .. e) end

    return table.concat(L, "\n")
end
