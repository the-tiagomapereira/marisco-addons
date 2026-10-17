-- Marisco's Companion Keeper - Core
-- Saved settings, slash commands and start-up.

local ADDON, ns = ...

ns.VERSION       = "0.1"
ns.VERSION_LABEL = "v0.1 - Alpha"
ns.TITLE         = "Marisco's Companion Keeper"
ns.ICON          = "Interface\\Icons\\INV_Box_PetCarrier_01"

local PREFIX = "|cffffd100Companion Keeper:|r "

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

local DEFAULTS = {
    minimap  = { angle = 215, hide = false },
    selected = nil,   -- { id = petID, name = "...", speciesID = n }
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
        ns.UI:CreateMinimapButton()
    end
end)

local function Help()
    ns.Print("commands:")
    print("  |cffffd100/mck|r - open or close the window")
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
        ns.UI:ResetPositions()
        ns.Print("chosen companion, window and minimap button reset.")
    else
        Help()
    end
end
