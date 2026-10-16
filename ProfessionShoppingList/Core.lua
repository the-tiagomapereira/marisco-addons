local addonName, ns = ...
ns.addonName = addonName
ns.sessionId = tostring(time())
ns.TITLE = "Marisco's Profession Shopping List"
ns.VERSION = "v0.25 - Beta"
ns.AUTHOR = "Arrozdemarisco"

-- API shims: modern clients move these into C_Item, classic keeps globals.
ns.GetItemInfo  = (C_Item and C_Item.GetItemInfo) or GetItemInfo
ns.GetItemIcon  = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
ns.GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount

ns.FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

function ns.Print(...)
    print("|cff33ccffMarisco's Shopping List:|r", ...)
end

function ns.Key(name)
    if type(name) ~= "string" or name == "" then return nil end
    return name:lower()
end

function ns.IdFromLink(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

function ns:Icon(id)
    if id then
        local icon = ns.GetItemIcon(id)
        if icon then return icon end
    end
    return ns.FALLBACK_ICON
end

-- Register events without erroring on clients where an event doesn't exist.
function ns.SafeRegister(frame, event)
    local ok = pcall(frame.RegisterEvent, frame, event)
    return ok
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------
local defaults = {
    list = {},          -- array of { name=, id=, qty= }
    learned = {},       -- [profession] = { [lowername] = { name=, id= } }
    prices = {},        -- [realm-faction] = { [key] = { price=, t=, none= } }
    lastScan = {},      -- [realm-faction] = time()
    vendorItems = {},   -- [itemID] = unit price, learned from merchant windows
    craftedIds = {},    -- [itemID] = true, learned from profession windows
    notes = "",
    guidePrefs = {},    -- [profession] = { route=, from=, to= }
    recipeSnapshot = {},-- [profession] = { t=, build=, recipes = { [recipe] = { [reagent] = count } } }
    settings = {
        profession = "Leatherworking",
        openWithAH = true,
        subtractOwned = false,
        bgAlpha = 0.92,
        showMinimap = true,
        minimapAngle = 225,
        collapsed = false,
        sideCollapsed = false,
        allowResize = true,
        attachToAH = true,
        viewMode = "list",      -- "list" or "grid"
        iconSize = 40,
        sourceFilter = "all",   -- "all", "vendor", "drop", "crafted"
        width = 520,
        height = 640,
    },
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

---------------------------------------------------------------------------
-- Catalog
---------------------------------------------------------------------------
function ns:GetProfessions()
    local seen, out = {}, {}
    for prof in pairs(ns.BaseMaterials) do
        if not seen[prof] then seen[prof] = true; out[#out + 1] = prof end
    end
    for prof in pairs(ns.db.learned) do
        if not seen[prof] then seen[prof] = true; out[#out + 1] = prof end
    end
    table.sort(out)
    return out
end

function ns:GetMaterials(prof)
    local out, seen = {}, {}
    local function add(name, id)
        local k = ns.Key(name)
        if not k then return end
        local e = seen[k]
        if not e then
            e = { name = name, id = id }
            seen[k] = e
            out[#out + 1] = e
        elseif id and not e.id then
            e.id = id
        end
    end
    -- learned first: their item IDs come straight from the game
    local learned = ns.db.learned[prof]
    if learned then
        for _, e in pairs(learned) do add(e.name, e.id) end
    end
    local base = ns.BaseMaterials[prof]
    if base then
        for _, e in ipairs(base) do add(e[1], e[2]) end
    end
    table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
    return out
end

-- Index of every name/id we care about, so price recording stays small.
function ns:RebuildKnown()
    local known = {}
    for _, prof in ipairs(ns:GetProfessions()) do
        for _, e in ipairs(ns:GetMaterials(prof)) do
            known[ns.Key(e.name)] = true
            if e.id then known["id:" .. e.id] = true end
        end
    end
    for _, e in ipairs(ns.db.list) do
        known[ns.Key(e.name)] = true
        if e.id then known["id:" .. e.id] = true end
    end
    ns.known = known
end

function ns:LearnMaterial(prof, name, id)
    local k = ns.Key(name)
    if not prof or prof == "" or not k then return false end
    ns.db.learned[prof] = ns.db.learned[prof] or {}
    local cur = ns.db.learned[prof][k]
    if not cur then
        ns.db.learned[prof][k] = { name = name, id = id }
        return true
    elseif id and not cur.id then
        cur.id = id
    end
    return false
end

---------------------------------------------------------------------------
-- Shopping list
---------------------------------------------------------------------------
local function SortList()
    table.sort(ns.db.list, function(a, b) return a.name:lower() < b.name:lower() end)
end

function ns:FindInList(name)
    local k = ns.Key(name)
    for i, e in ipairs(ns.db.list) do
        if ns.Key(e.name) == k then return e, i end
    end
end

function ns:AddToList(name, id, qty)
    if not ns.Key(name) then return end
    qty = qty or 1
    local e = ns:FindInList(name)
    if e then
        e.qty = e.qty + qty
        if id and not e.id then e.id = id end
    else
        table.insert(ns.db.list, { name = name, id = id, qty = qty })
        SortList()
        ns.known[ns.Key(name)] = true
        if id then ns.known["id:" .. id] = true end
    end
    ns:RequestRefresh()
end

function ns:ChangeQty(name, delta)
    local e, i = ns:FindInList(name)
    if not e then return end
    e.qty = e.qty + delta
    if e.qty <= 0 then table.remove(ns.db.list, i) end
    ns:RequestRefresh()
end

function ns:SetQty(name, qty)
    local e, i = ns:FindInList(name)
    if not e or not qty then return end
    qty = math.floor(qty)
    if qty <= 0 then
        table.remove(ns.db.list, i)
    else
        e.qty = qty
    end
    ns:RequestRefresh()
end

function ns:RemoveFromList(name)
    local _, i = ns:FindInList(name)
    if i then table.remove(ns.db.list, i) end
    ns:RequestRefresh()
end

function ns:ClearList()
    wipe(ns.db.list)
    ns:RequestRefresh()
end

---------------------------------------------------------------------------
-- Where a material comes from
---------------------------------------------------------------------------
-- Returns "vendor", "crafted" or "drop" (drop also covers gathered items).
function ns:GetSource(e)
    if (e.id and ns.db.vendorItems[e.id]) or ns.VendorItems[e.name] then return "vendor" end
    if (e.id and ns.db.craftedIds[e.id]) or ns.CraftedItems[e.name] then return "crafted" end
    return "drop"
end

function ns:GetVendorPrice(id)
    local p = id and ns.db.vendorItems[id]
    if type(p) == "number" then return p end
end

function ns:LearnFromMerchant()
    local n = (GetMerchantNumItems and GetMerchantNumItems()) or 0
    local added = 0
    for i = 1, n do
        local id = ns.IdFromLink(GetMerchantItemLink(i))
        if id then
            local price, qty
            if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
                local info = C_MerchantFrame.GetItemInfo(i)
                if info then price, qty = info.price, info.stackCount end
            elseif GetMerchantItemInfo then
                local _, _, p, q = GetMerchantItemInfo(i)
                price, qty = p, q
            end
            if price and price > 0 then
                if not ns.db.vendorItems[id] then added = added + 1 end
                ns.db.vendorItems[id] = math.floor(price / math.max(1, qty or 1))
            end
        end
    end
    if added > 0 then ns:RequestRefresh() end
end

---------------------------------------------------------------------------
-- Your primary professions, read from the character's skills
-- Returns { { name=, rank=, max= }, ... } (up to two)
---------------------------------------------------------------------------
function ns:GetPrimaryProfessions()
    local out = {}
    -- Classic-style skill list (Character > Skills)
    if GetNumSkillLines and GetSkillLineInfo then
        -- make sure the "Professions" header is open, or its lines are hidden
        local profHeader = TRADE_SKILLS or "Professions"
        for i = 1, GetNumSkillLines() do
            local name, isHeader, isExpanded = GetSkillLineInfo(i)
            if isHeader and name == profHeader and not isExpanded and ExpandSkillHeader then
                ExpandSkillHeader(i)
                break
            end
        end
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank, _, mod, maxRank, isAbandonable = GetSkillLineInfo(i)
            -- primary professions are the ones you can unlearn
            if name and not isHeader and isAbandonable and maxRank and maxRank > 0 then
                out[#out + 1] = { name = name, rank = (rank or 0), bonus = (mod or 0), max = maxRank }
            end
        end
        if #out > 0 then return out end
    end
    -- Modern profession API
    if GetProfessions and GetProfessionInfo then
        local p1, p2 = GetProfessions()
        for _, idx in ipairs({ p1, p2 }) do
            if idx then
                local name, icon, rank, max = GetProfessionInfo(idx)
                if name then out[#out + 1] = { name = name, rank = rank or 0, max = max or 0, icon = icon } end
            end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Prices
---------------------------------------------------------------------------
function ns:GetPrice(name, id)
    local p
    if id then p = ns.prices["id:" .. id] end
    if not p then
        local k = ns.Key(name)
        if k then p = ns.prices[k] end
    end
    return p
end

function ns:GetOwned(id)
    if not id then return 0 end
    local ok, n = pcall(ns.GetItemCount, id, true)
    return (ok and n) or 0
end

-- Returns total copper, number of list lines with no known price.
-- The price we count for one unit: vendor items always use the vendor price
-- (once learned from a vendor window); everything else uses the AH price.
-- Returns unitPrice, "vendor" | "ah"  (or nil when unknown).
function ns:GetUnitPrice(e)
    if ns:GetSource(e) == "vendor" then
        local vp = ns:GetVendorPrice(e.id)
        if vp then return vp, "vendor" end
    end
    local p = ns:GetPrice(e.name, e.id)
    if p and p.price then return p.price, "ah" end
end

function ns:ComputeTotal()
    local total, missing = 0, 0
    local subtract = ns.db.settings.subtractOwned
    for _, e in ipairs(ns.db.list) do
        local need = e.qty
        if subtract then need = math.max(0, e.qty - ns:GetOwned(e.id)) end
        if need > 0 then
            local unit = ns:GetUnitPrice(e)
            if unit then
                total = total + unit * need
            else
                missing = missing + 1
            end
        end
    end
    return total, missing
end

---------------------------------------------------------------------------
-- UI refresh throttle
---------------------------------------------------------------------------
local refreshPending = false
function ns:RequestRefresh()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0.15, function()
        refreshPending = false
        if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    end)
end

---------------------------------------------------------------------------
-- Learning reagents from the open profession window
---------------------------------------------------------------------------
function ns:LearnFromOpenProfession()
    local added, profName = 0, nil
    local snap = {}   -- [prof] = { [recipe] = { [reagent] = count } }
    local function recipe(prof, rname, reagent, count)
        if not (prof and rname and reagent) then return end
        snap[prof] = snap[prof] or {}
        snap[prof][rname] = snap[prof][rname] or {}
        snap[prof][rname][reagent] = count or 1
    end
    local function store(prof, name, id)
        if prof and prof ~= "UNKNOWN" and name then
            profName = prof
            if ns:LearnMaterial(prof, name, id) then added = added + 1 end
        end
    end

    -- Classic trade skill window
    if GetNumTradeSkills and GetTradeSkillLine then
        local prof = GetTradeSkillLine()
        for i = 1, (GetNumTradeSkills() or 0) do
            local recipeName, kind = GetTradeSkillInfo(i)
            if kind and kind ~= "header" and kind ~= "subheader" then
                local pid = GetTradeSkillItemLink and ns.IdFromLink(GetTradeSkillItemLink(i))
                if pid then ns.db.craftedIds[pid] = true end
                for j = 1, (GetTradeSkillNumReagents(i) or 0) do
                    local rName, _, rCount = GetTradeSkillReagentInfo(i, j)
                    local link = GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, j)
                    store(prof, rName, ns.IdFromLink(link))
                    recipe(prof, recipeName, rName, rCount)
                end
            end
        end
    end

    -- Classic craft window (Enchanting)
    if GetNumCrafts and GetCraftDisplaySkillLine then
        local prof = GetCraftDisplaySkillLine()
        if prof then
            for i = 1, (GetNumCrafts() or 0) do
                local craftName, _, kind = GetCraftInfo(i)
                if kind ~= "header" then
                    for j = 1, (GetCraftNumReagents(i) or 0) do
                        local rName, _, rCount = GetCraftReagentInfo(i, j)
                        local link = GetCraftReagentItemLink and GetCraftReagentItemLink(i, j)
                        store(prof, rName, ns.IdFromLink(link))
                        recipe(prof, craftName, rName, rCount)
                    end
                end
            end
        end
    end

    -- Modern profession UI (only if the classic API is absent)
    if not GetNumTradeSkills and C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
        local info = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
        local prof = info and info.professionName
        if prof then
            for _, rid in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
                local s = C_TradeSkillUI.GetRecipeSchematic(rid, false)
                if s and s.outputItemID then ns.db.craftedIds[s.outputItemID] = true end
                if s and s.reagentSlotSchematics then
                    for _, slot in ipairs(s.reagentSlotSchematics) do
                        for _, r in ipairs(slot.reagents or {}) do
                            if r.itemID then
                                local nm = ns.GetItemInfo(r.itemID)
                                if nm then
                                    store(prof, nm, r.itemID)
                                    recipe(prof, s.name, nm, slot.quantityRequired)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- keep the latest snapshot of each profession's recipes (used to check the guides)
    local build = select(2, GetBuildInfo())
    for prof, recipes in pairs(snap) do
        if prof ~= "UNKNOWN" then
            ns.db.recipeSnapshot[prof] = { t = time(), build = build, recipes = recipes }
        end
    end

    if added > 0 then
        ns.Print(string.format("Learned %d new material(s) for %s.", added, profName or "?"))
        ns:RebuildKnown()
        ns:RequestRefresh()
    end
end

local learnPending = false
local function ScheduleLearn()
    if learnPending then return end
    learnPending = true
    C_Timer.After(0.5, function()
        learnPending = false
        local ok, err = pcall(ns.LearnFromOpenProfession, ns)
        if not ok then ns.Print("Couldn't read the profession window: " .. tostring(err)) end
    end)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "CRAFT_SHOW", "CRAFT_UPDATE",
                     "TRADE_SKILL_LIST_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_MONEY",
                     "MERCHANT_SHOW", "MERCHANT_UPDATE" }) do
    ns.SafeRegister(ev, e)
end

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        ProfessionShoppingListDB = ProfessionShoppingListDB or {}
        CopyDefaults(defaults, ProfessionShoppingListDB)
        ns.db = ProfessionShoppingListDB
    elseif event == "PLAYER_LOGIN" then
        local realmKey = (GetRealmName() or "?") .. "-" .. (UnitFactionGroup("player") or "?")
        ns.realmKey = realmKey
        ns.db.prices[realmKey] = ns.db.prices[realmKey] or {}
        ns.prices = ns.db.prices[realmKey]
        ns:RebuildKnown()
        ns.UI:Create()
        ns.Minimap:Create()
        ns.Print("loaded. Type /psl to open, or use the minimap button.")
    elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
        if ns.db then
            local ok, err = pcall(ns.LearnFromMerchant, ns)
            if not ok then ns.Print("Couldn't read the vendor window: " .. tostring(err)) end
        end
    elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_MONEY" then
        if ns.db then ns:RequestRefresh() end
    elseif ns.db then
        ScheduleLearn()
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_PROFESSIONSHOPPINGLIST1 = "/psl"
SLASH_PROFESSIONSHOPPINGLIST2 = "/shoppinglist"
SlashCmdList["PROFESSIONSHOPPINGLIST"] = function(msg)
    msg = msg or ""
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" then
        ns.UI:Toggle()
    elseif cmd == "add" and rest ~= "" then
        local id = ns.IdFromLink(rest)
        local name = rest:match("%[(.-)%]") or (id and ns.GetItemInfo(id)) or rest
        local prof = ns.db.settings.profession
        ns:LearnMaterial(prof, name, id)
        ns:AddToList(name, id, 1)
        ns:RebuildKnown()
        ns.Print("Added " .. name .. " (also saved under " .. prof .. ").")
    elseif cmd == "clear" then
        ns:ClearList()
        ns.Print("Shopping list cleared.")
    elseif cmd == "scan" then
        ns.Auction:StartScan()
    elseif cmd == "reset" then
        ns.db.pos = nil
        ns.UI:ResetPosition()
        ns.Print("Window position reset.")
    elseif cmd == "learn" then
        ScheduleLearn()
    elseif cmd == "notes" then
        ns.UI:ToggleNotes()
    elseif cmd == "guide" then
        ns.UI:ToggleGuide()
    elseif cmd == "release" or cmd == "changelog" then
        ns.UI:ToggleReleaseNotes()
    elseif cmd == "settings" or cmd == "config" then
        ns.UI:ToggleSettings()
    elseif cmd == "minimap" then
        ns.db.settings.showMinimap = not ns.db.settings.showMinimap
        ns.Minimap:UpdateVisibility()
        ns.Print("Minimap button " .. (ns.db.settings.showMinimap and "shown." or "hidden."))
    else
        ns.Print("Commands: /psl, /psl add <item link>, /psl scan, /psl clear, /psl notes, /psl guide, /psl release, /psl settings, /psl minimap, /psl reset, /psl learn")
    end
end
