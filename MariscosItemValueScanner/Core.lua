-- Marisco's Item Value Scanner - Core
-- Target client: World of Warcraft: Forever 1.60.x (interface 16001)

local ADDON_NAME, ns = ...

ns.VERSION       = "v0.9 - Beta"
ns.TITLE         = "Marisco's Item Value Scanner"
ns.SHORT         = "|cff69ccf0Marisco's IVS|r"
ns.SCAN_COOLDOWN = 15            -- seconds the scan button stays grayed out
ns.ICON          = "Interface\\Icons\\Spell_Holy_MagicalSentry" -- Arcane Intellect
ns.ahOpen        = false

------------------------------------------------------------------------
-- Utilities
------------------------------------------------------------------------
function ns:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(ns.SHORT .. ": " .. tostring(msg))
end

-- Live "time since" text:
-- seconds up to 59, then minutes up to 59, then hours up to 23, then days.
function ns.FormatAge(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local value, unit
    if seconds < 60 then
        value, unit = seconds, "second"
    elseif seconds < 3600 then
        value, unit = math.floor(seconds / 60), "minute"
    elseif seconds < 86400 then
        value, unit = math.floor(seconds / 3600), "hour"
    else
        value, unit = math.floor(seconds / 86400), "day"
    end
    return string.format("%d %s%s ago", value, unit, value == 1 and "" or "s")
end

function ns.FormatDate(t)
    return date("%Y-%m-%d %H:%M:%S", t)
end

local GOLD   = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

-- Always returns a non-negative coin string; callers add the sign.
function ns.FormatMoney(copper)
    copper = math.floor(math.abs(copper or 0) + 0.5)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local out = {}
    if g > 0 then out[#out + 1] = BreakUpLargeNumbers and BreakUpLargeNumbers(g) .. GOLD or g .. GOLD end
    if s > 0 then out[#out + 1] = s .. SILVER end
    if c > 0 or #out == 0 then out[#out + 1] = c .. COPPER end
    return table.concat(out, " ")
end

------------------------------------------------------------------------
-- Saved variables (prices are kept per realm + faction)
------------------------------------------------------------------------
local DEFAULTS = {
    showAHButton = true,
    showDisenchant = true, -- v0.4: disenchant estimate in tooltips (/mivs de)
    fastScan = false,      -- v0.2: full-dump scan is opt-in (/mivs fast)
    minimap = { angle = 225, hide = false },
    realms = {},
}

local function ApplyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            ApplyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function ns:GetRealmKey()
    return (GetRealmName() or "Unknown") .. " - " .. (UnitFactionGroup("player") or "Neutral")
end

function ns:InitDB()
    if type(MariscosIVS_DB) ~= "table" then MariscosIVS_DB = {} end
    ApplyDefaults(DEFAULTS, MariscosIVS_DB)
    ns.db = MariscosIVS_DB
    ns.db.addonVersion = ns.VERSION

    local key = ns:GetRealmKey()
    ns.db.realms[key] = ns.db.realms[key] or {}
    ns.data = ns.db.realms[key]
    ns.data.prices = ns.data.prices or {}
end

------------------------------------------------------------------------
-- Toggles
------------------------------------------------------------------------
function ns:ToggleAHButton()
    ns.db.showAHButton = not ns.db.showAHButton
    if ns.UpdateAHButtonVisibility then ns:UpdateAHButtonVisibility() end
    if ns.UpdateMinimapIcon then ns:UpdateMinimapIcon() end
    ns:Print("Auction House scan button " .. (ns.db.showAHButton and "|cff00ff00ON|r" or "|cffff4040OFF|r"))
end

function ns:PrintStatus()
    local last = ns.data.lastScan
    if last then
        ns:Print(string.format("Last scan %s (%s) - %d items%s.",
            ns.FormatDate(last), ns.FormatAge(time() - last), ns.data.lastScanItems or 0,
            ns.data.lastScanComplete and "" or ", |cffffd100partial|r"))
        ns:Print("Scan mode: " .. (ns.db.fastScan and "FAST" or "SAFE") .. " (/mivs fast to switch)")
    else
        ns:Print("No scan yet. Open the Auction House and press Scan AH.")
    end
end

------------------------------------------------------------------------
-- Other Auction House addons (warn once per session)
------------------------------------------------------------------------
local KNOWN_AH_ADDONS = {
    "Auctionator", "AHledger", "aux-addon", "TradeSkillMaster", "Auctioneer",
    "AuctionFaster", "Journalator", "WoWForeverTracker", "ProfessionShoppingList",
}

local function IsLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
    return IsAddOnLoaded and IsAddOnLoaded(name)
end

function ns:WarnOtherAHAddons()
    if ns.warnedOthers then return end
    ns.warnedOthers = true
    local found = {}
    for _, name in ipairs(KNOWN_AH_ADDONS) do
        if IsLoaded(name) then found[#found + 1] = name end
    end
    if #found > 0 then
        ns:Print("Other Auction House addon(s) loaded: |cffffd100" .. table.concat(found, ", ") ..
            "|r. Don't run their scans at the same time as ours - if one sends a query, our scan stops and keeps what it has.")
    end
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        ns:InitDB()
    elseif event == "PLAYER_LOGIN" then
        if not ns.data then ns:InitDB() end
        if ns.CreateMinimapButton then ns:CreateMinimapButton() end
        if ns.InitTooltips then ns:InitTooltips() end
        ns:Print(ns.VERSION .. " loaded. Type |cffffd100/mivs|r for options.")
    elseif event == "AUCTION_HOUSE_SHOW" then
        ns.ahOpen = true
        ns:WarnOtherAHAddons()
        if ns.OnAuctionHouseShow then ns:OnAuctionHouseShow() end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        ns.ahOpen = false
        if ns.Scanner and ns.Scanner:IsScanning() then ns.Scanner:Abort("Auction House closed") end
    end
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
SLASH_MARISCOSIVS1 = "/mivs"
SLASH_MARISCOSIVS2 = "/mariscos"
SlashCmdList.MARISCOSIVS = function(msg)
    msg = strlower(strtrim(msg or ""))
    if msg == "scan" then
        if ns.TryScan then ns:TryScan() end
    elseif msg == "toggle" then
        ns:ToggleAHButton()
    elseif msg == "minimap" then
        ns.db.minimap.hide = not ns.db.minimap.hide
        if ns.UpdateMinimapIcon then ns:UpdateMinimapIcon() end
        ns:Print("Minimap button " .. (ns.db.minimap.hide and "hidden" or "shown"))
    elseif msg == "fast" then
        ns.db.fastScan = not ns.db.fastScan
        ns:Print("Scan mode: " .. (ns.db.fastScan
            and "|cffffd100FAST|r (every auction in one go - heavy, server allows ~1 per 15 min)"
            or "|cff00ff00SAFE|r (search results in batches - light, no 15 min limit)"))
    elseif msg == "de" then
        ns.db.showDisenchant = not ns.db.showDisenchant
        ns:Print("Disenchant info in tooltips " .. (ns.db.showDisenchant and "|cff00ff00ON|r" or "|cffff4040OFF|r"))
    elseif msg == "status" then
        ns:PrintStatus()
    elseif msg == "reset" then
        wipe(ns.data.prices)
        ns.data.lastScan, ns.data.lastScanItems, ns.data.lastScanComplete = nil, nil, nil
        ns:Print("Price data for " .. ns:GetRealmKey() .. " cleared.")
    else
        ns:Print(ns.TITLE .. " " .. ns.VERSION)
        ns:Print("/mivs scan - scan the Auction House (AH must be open)")
        ns:Print("/mivs fast - switch between SAFE (default) and FAST scan")
        ns:Print("/mivs de - show/hide disenchant info in tooltips")
        ns:Print("/mivs toggle - show/hide the AH scan button")
        ns:Print("/mivs minimap - show/hide the minimap button")
        ns:Print("/mivs status - last scan info")
        ns:Print("/mivs reset - clear stored prices for this realm/faction")
    end
end
