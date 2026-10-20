-- Marisco's Companion Keeper - Core
-- Saved settings, slash commands and start-up.

local ADDON, ns = ...

ns.VERSION       = "0.7.1"
ns.VERSION_LABEL = "v0.7.1 - Alpha"
ns.TITLE         = "Marisco's Companion Keeper"
ns.ICON          = "Interface\\Icons\\INV_Box_PetCarrier_01"

local PREFIX = "|cffffd100Companion Keeper:|r "

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

local DEFAULTS = {
    minimap  = { angle = 215, hide = false },
    selected  = nil,   -- { id = petID, name = "...", speciesID = n }
    collapsed = false, -- companion list hidden
    pets      = {},    -- petID -> { happy, day, hearts, done, prog, seen }
    tracker   = { shown = false, pos = nil },  -- minimized view
    window   = nil,   -- { point, relativePoint, x, y }
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

-- If the game ever blocks something this addon did, say exactly what in chat (and in /mck probe).
local guard = CreateFrame("Frame")
guard:RegisterEvent("ADDON_ACTION_FORBIDDEN")
guard:RegisterEvent("ADDON_ACTION_BLOCKED")
guard:SetScript("OnEvent", function(_, event, addon, func)
    if addon ~= ADDON then return end
    local what = event == "ADDON_ACTION_FORBIDDEN" and "blocked" or "blocked in combat"
    local line = ("the game %s this action: |cffffffff%s|r. Please report it."):format(what, tostring(func))
    if ns.Journal and ns.Journal.errors then
        table.insert(ns.Journal.errors, event .. ": " .. tostring(func))
    end
    ns.Print("|cffff4040" .. line .. "|r")
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        if type(MariscosCompanionKeeperDB) ~= "table" then MariscosCompanionKeeperDB = {} end
        CopyDefaults(DEFAULTS, MariscosCompanionKeeperDB)
        ns.db = MariscosCompanionKeeperDB
    elseif event == "PLAYER_LOGIN" then
        ns.Journal:Init()
        ns.Buddy:Init()
        ns.UI:CreateMinimapButton()
        if ns.db.tracker.shown then ns.Tracker:Show() end
    end
end)

local function Help()
    ns.Print("commands:")
    print("  |cffffd100/mck|r - open or close the window")
    print("  |cffffd100/mck mini|r - show or hide the small tracker")
    print("  |cffffd100/mck pet|r, |cffffd100/mck play|r - pet your companion, play fetch")
    print("  |cffffd100/mck summon|r - summon your companion or send it back (works in a macro)")
    print("  |cffffd100/mck hearts|r - your companion's happiness and today's actions")
    print("  |cffffd100/mck test <action>|r - pretend an action happened (testing), |cffffd100/mck test reset|r clears today")
    print("  |cffffd100/mck probe|r - Companion Journal report (to copy and send back)")
    print("  |cffffd100/mck scan|r - read the Companion Journal again")
    print("  |cffffd100/mck status|r - what the addon sees right now")
    print("  |cffffd100/mck minimap|r - hide or show the minimap button")
    print("  |cffffd100/mck reset|r - clear the chosen companion, window and button position")
end

SLASH_MARISCOSCOMPANIONKEEPER1 = "/mck"
SLASH_MARISCOSCOMPANIONKEEPER2 = "/companionkeeper"
SlashCmdList.MARISCOSCOMPANIONKEEPER = function(msg)
    msg = strlower(strtrim(msg or ""))
    if msg == "" or msg == "show" then
        ns.UI:Toggle()
    elseif msg == "probe" or msg == "debug" or msg == "report" then
        ns.Journal:Scan()
        ns.UI:ShowProbe()
    elseif msg == "mini" or msg == "tracker" then
        ns.Tracker:Toggle()
    elseif msg == "hearts" then
        local B = ns.Buddy
        local id = B:ChosenID()
        if not id then ns.Print("no companion chosen yet.") return end
        local r = B:Record(id)
        local _, level = B:Level(r.happy)
        ns.Print(("%s: %s, %d happiness (+%d today), %d/%d hearts today."):format(
            tostring(ns.db.selected.name), B.ColorText(level.color, level.name), r.happy, r.today or 0, r.hearts, B.HEARTS_PER_DAY))
        for _, a in ipairs(B:TodayActions(r)) do
            local text = ns.UI.ChallengeState(r, a, false)
            print(("  %s %s %s"):format(r.done[a.key] and "|cff40ff40done|r" or "|cff9d9d9d....|r", a.name, text))
        end
        print(("  Pet: %s   Play: %s"):format(
            B:CooldownLeft("pet") > 0 and B.FormatTime(B:CooldownLeft("pet")) or "|cff40ff40ready|r",
            B:CooldownLeft("fetch") > 0 and B.FormatTime(B:CooldownLeft("fetch")) or "|cff40ff40ready|r"))
    elseif msg:match("^test") then
        local key = msg:match("^test%s+(%S+)")
        if key == "reset" then
            ns.Buddy:ResetToday()
            ns.Print("today's progress and pet/play cooldowns cleared for your companion (testing).")
        elseif key and ns.Buddy:Test(key) then
            -- message comes from the heart itself
        else
            local B = ns.Buddy
            local keys = {}
            for _, a in ipairs(B:TodayActions(B:Record(B:ChosenID()))) do keys[#keys + 1] = a.key end
            ns.Print("testing: /mck test <" .. table.concat(keys, "|") .. "|reset>  (today's challenges)")
        end
    elseif msg == "pet" then
        local ok, why = ns.Buddy:Pet()
        if not ok then ns.Print(why) end
    elseif msg == "play" or msg == "fetch" then
        ns.Fetch:Open()
    elseif msg == "summon" then
        ns.UI:SummonChosen()
    elseif msg == "scan" then
        ns.Journal:Scan()
        ns.Print(("found %d companion(s)."):format(#ns.Journal.pets))
    elseif msg == "status" then
        ns.UI:PrintStatus()
    elseif msg == "minimap" then
        ns.UI:ToggleMinimap()
    elseif msg == "reset" then
        ns.db.selected = nil
        ns.db.window = nil
        ns.db.minimap.angle = DEFAULTS.minimap.angle
        ns.db.minimap.hide = false
        ns.db.tracker.pos = nil
        ns.UI:ResetPositions()
        ns.Print("chosen companion, window, tracker and minimap button positions reset.")
    else
        Help()
    end
end
