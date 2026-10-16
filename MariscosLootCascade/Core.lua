-- Marisco's Loot Cascade - Core
-- Target client: World of Warcraft: Forever 1.60.x (interface 16001)

local ADDON_NAME, ns = ...

ns.VERSION = "v1.0 - Release"
ns.TITLE   = "Marisco's Loot Cascade"
ns.SHORT   = "|cff69ccf0Marisco's Loot Cascade|r"
ns.ICON    = "Interface\\Icons\\INV_Misc_Bag_22"   -- Onyxia Hide Backpack

ns.defaults = {
    replace    = true,    -- take over the loot window (loot everything, hide Blizzard's frame)
    layout     = 2,       -- bumped when the default position/size changes
    point      = "TOP",   -- y is left empty: it defaults to about a third of the screen above center
    relPoint   = "CENTER",
    x          = 0,
    grow       = "down",  -- newest on top, older entries cascade down ("up" = the reverse)
    hold       = 5,       -- seconds an entry stays fully visible (rarer items stay longer)
    fade       = 1.6,     -- seconds of the slow fade-out
    maxLines   = 7,
    minQuality = 0,       -- 0 poor, 1 common, 2 uncommon, 3 rare, 4 epic, 5 legendary
    money      = true,
    pushed     = true,    -- quest rewards and other items pushed into your bags
    created    = true,    -- items you craft
    showCount  = true,    -- "(12)" total in bags
    mouse      = true,    -- hover for tooltip, shift-click to link
    scale      = 1.0,
    bgAlpha    = 0.84,    -- card background opacity
    rarityBonus = true,   -- rare +1 s, epic +2 s, legendary +3 s on screen
    minimap    = { hide = false, angle = 200 },
}

------------------------------------------------------------------------
-- Utilities
------------------------------------------------------------------------
function ns:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(ns.SHORT .. ": " .. tostring(msg))
end

-- Turns a localized format string ("You receive loot: %sx%d.") into a Lua pattern.
function ns.FormatToPattern(fmt)
    if not fmt then return nil end
    local p = fmt:gsub("%%%d?%$?([sd])", "\001%1")          -- protect %s / %d / %1$s
    p = p:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")      -- escape magic characters
    p = p:gsub("\001s", "(.+)"):gsub("\001d", "(%%d+)")
    return "^" .. p .. "$"
end

------------------------------------------------------------------------
-- API shims: the Forever client moved several old globals into C_Item / C_Container.
------------------------------------------------------------------------
local C_Item, C_Container = C_Item, C_Container

local function pick(...)
    for i = 1, select("#", ...) do
        local fn = select(i, ...)
        if type(fn) == "function" then return fn end
    end
end

local rawGetItemInfo  = pick(_G.GetItemInfo, C_Item and C_Item.GetItemInfo)
local rawGetItemCount = pick(_G.GetItemCount, C_Item and C_Item.GetItemCount)
local rawGetIconByID  = pick(_G.GetItemIcon, C_Item and C_Item.GetItemIconByID)
ns.GetNumSlots = pick(C_Container and C_Container.GetContainerNumSlots, _G.GetContainerNumSlots)
ns.GetSlotLink = pick(C_Container and C_Container.GetContainerItemLink, _G.GetContainerItemLink)

function ns.GetItemInfo(item)
    if not (rawGetItemInfo and item) then return end
    local r = { pcall(rawGetItemInfo, item) }
    if r[1] then return unpack(r, 2) end
end

function ns.GetItemCountSafe(item)
    if not (rawGetItemCount and item) then return end
    local ok, n = pcall(rawGetItemCount, item)
    return ok and n or nil
end

function ns.IsHyperlink(s) return type(s) == "string" and s:find("|H", 1, true) ~= nil end
function ns.ItemIDFromLink(link) return tonumber(link and link:match("item:(%-?%d+)")) end
function ns.NameFromText(s)
    if not s then return end
    return s:match("%[(.-)%]") or s
end

function ns.GetItemIcon(item)
    if not item then return end
    local icon = select(10, ns.GetItemInfo(item))
    if not icon and rawGetIconByID then
        local id = ns.ItemIDFromLink(item) or tonumber(item)
        if id then
            local ok, i = pcall(rawGetIconByID, id)
            if ok then icon = i end
        end
    end
    return icon
end

------------------------------------------------------------------------
-- Name -> item cache. Loot messages may carry only "[Item Name]" instead of a link,
-- so we remember links seen in the loot window and in the bags.
------------------------------------------------------------------------
ns.known = {}   -- name -> { link = , icon = , quality = }

function ns.Remember(link, icon, quality, name)
    name = name or ns.NameFromText(link)
    if not name or name == "" then return end
    local k = ns.known[name] or {}
    if link and ns.IsHyperlink(link) then k.link = link end
    k.icon = icon or k.icon
    if quality and quality >= 0 then k.quality = quality end
    ns.known[name] = k
end

function ns.ScanBagsFor(name)
    if not (ns.GetNumSlots and ns.GetSlotLink) then return end
    for bag = 0, 4 do
        for slot = 1, (ns.GetNumSlots(bag) or 0) do
            local link = ns.GetSlotLink(bag, slot)
            if link and ns.NameFromText(link) == name then
                ns.Remember(link, ns.GetItemIcon(link), nil, name)
                return link
            end
        end
    end
end

-- Returns link-or-name, icon, quality for whatever the loot message gave us.
function ns.ResolveItem(text, scanBags)
    if ns.IsHyperlink(text) then return text, ns.GetItemIcon(text), nil end
    local name = ns.NameFromText(text)
    local k = ns.known[name]
    if k and k.link then return k.link, k.icon or ns.GetItemIcon(k.link), k.quality end
    local _, link, quality, _, _, _, _, _, _, icon = ns.GetItemInfo(name)
    if link then ns.Remember(link, icon, quality, name); return link, icon, quality end
    if scanBags then
        link = ns.ScanBagsFor(name)
        if link then return link, ns.GetItemIcon(link), nil end
    end
    return name, k and k.icon, k and k.quality
end

------------------------------------------------------------------------
-- Saved variables and slash commands
------------------------------------------------------------------------
local function ApplyDefaults()
    MariscosLootCascadeDB = MariscosLootCascadeDB or {}
    local db = MariscosLootCascadeDB
    if (db.layout or 1) < 2 then
        -- v0.3 moved the feed to the center of the screen as cards: drop the old position
        db.point, db.relPoint, db.x, db.y, db.maxLines, db.grow = nil, nil, nil, nil, nil, nil
        db.layout = nil
    end
    for k, v in pairs(ns.defaults) do
        if MariscosLootCascadeDB[k] == nil then
            if type(v) == "table" then
                local copy = {}
                for kk, vv in pairs(v) do copy[kk] = vv end
                v = copy
            end
            MariscosLootCascadeDB[k] = v
        end
    end
    ns.db = MariscosLootCascadeDB
end

ns.ApplyDefaults = function() ApplyDefaults() end

local qualityNames = { [0] = "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary" }

local function OnOff(v) return v and "|cff20ff20on|r" or "|cffff4040off|r" end

local function Status()
    local d = ns.db
    ns:Print(ns.VERSION)
    print(("  Replace loot window: %s   Grow: %s   Max lines: %d"):format(OnOff(d.replace), d.grow, d.maxLines))
    print(("  Hold: %.1fs   Fade: %.1fs   Scale: %.2f"):format(d.hold, d.fade, d.scale))
    print(("  Min quality: %s   Money: %s   Quest/pushed: %s   Crafted: %s   Bag count: %s   Mouse: %s")
        :format(qualityNames[d.minQuality] or d.minQuality, OnOff(d.money), OnOff(d.pushed),
                OnOff(d.created), OnOff(d.showCount), OnOff(d.mouse)))
end

local function Help()
    ns:Print("commands:")
    print("  /mlc config - open the settings (or click the minimap button)")
    print("  /mlc minimap - show/hide the minimap button")
    print("  /mlc test - show some sample cards")
    print("  /mlc unlock | lock - move the feed")
    print("  /mlc replace - toggle replacing the loot window")
    print("  /mlc grow up|down - direction of the cascade")
    print("  /mlc hold <sec> | fade <sec> | lines <n> | scale <n>")
    print("  /mlc quality <0-5> - hide items below this quality (0 poor ... 4 epic)")
    print("  /mlc money | pushed | crafted | count | mouse - toggle")
    print("  /mlc status | reset")
end

local function Toggle(key, label)
    ns.db[key] = not ns.db[key]
    ns:Print(label .. " " .. OnOff(ns.db[key]))
end

SLASH_MARISCOSLOOTCASCADE1 = "/mlc"
SLASH_MARISCOSLOOTCASCADE2 = "/lootcascade"
SlashCmdList.MARISCOSLOOTCASCADE = function(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local num = tonumber(arg)
    local d = ns.db
    if cmd == "test" then
        ns.Feed:Test()
    elseif cmd == "unlock" or cmd == "move" then
        ns.Feed:SetUnlocked(true)
    elseif cmd == "lock" then
        ns.Feed:SetUnlocked(false)
    elseif cmd == "replace" then
        Toggle("replace", "Replace loot window")
        ns.Loot:ApplyReplace()
    elseif cmd == "grow" and (arg == "up" or arg == "down") then
        d.grow = arg; ns.Feed:Layout(true); ns:Print("Grow " .. arg)
    elseif cmd == "hold" and num then
        d.hold = math.max(0.5, math.min(60, num)); ns:Print(("Hold %.1fs"):format(d.hold))
    elseif cmd == "fade" and num then
        d.fade = math.max(0.1, math.min(10, num)); ns:Print(("Fade %.1fs"):format(d.fade))
    elseif cmd == "lines" and num then
        d.maxLines = math.max(1, math.min(20, math.floor(num))); ns.Feed:ApplySettings(); ns:Print("Max lines " .. d.maxLines)
    elseif cmd == "scale" and num then
        d.scale = math.max(0.5, math.min(2.5, num)); ns.Feed:ApplySettings(); ns:Print(("Scale %.2f"):format(d.scale))
    elseif cmd == "quality" and num then
        d.minQuality = math.max(0, math.min(5, math.floor(num)))
        ns:Print("Min quality " .. (qualityNames[d.minQuality] or d.minQuality))
    elseif cmd == "money" then Toggle("money", "Money")
    elseif cmd == "pushed" then Toggle("pushed", "Quest rewards / pushed items")
    elseif cmd == "crafted" then Toggle("created", "Crafted items")
    elseif cmd == "count" then Toggle("showCount", "Bag count")
    elseif cmd == "mouse" then Toggle("mouse", "Mouse (tooltips)"); ns.Feed:ApplySettings()
    elseif cmd == "config" or cmd == "options" or cmd == "settings" then ns.Options:Toggle()
    elseif cmd == "minimap" then
        ns.db.minimap.hide = not ns.db.minimap.hide
        ns.Minimap:Update()
        ns:Print("Minimap button " .. OnOff(not ns.db.minimap.hide))
    elseif cmd == "status" then Status()
    elseif cmd == "reset" then
        local mm = ns.db.minimap
        MariscosLootCascadeDB = nil
        ApplyDefaults()
        ns.db.minimap = mm
        ns.Feed:ApplySettings(); ns.Feed:Layout(true); ns.Loot:ApplyReplace()
        ns:Print("Settings reset.")
    else
        Help()
    end
end

------------------------------------------------------------------------
-- Boot
------------------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    ApplyDefaults()
    ns.Feed:Init()
    ns.Loot:Init()
    ns.Minimap:Init()
end)
