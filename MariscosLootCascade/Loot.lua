-- Marisco's Loot Cascade - loot window replacement and loot messages
--
-- When "replace" is on, Blizzard's LootFrame no longer opens by itself. On LOOT_OPENED we take
-- every slot we can. If something is left that needs the player (bags full, master looter,
-- a declined Bind on Pickup, Shift held), we open Blizzard's frame as a fallback.
-- What lands in the bags is announced by the game's own loot messages, which feed the cascade.

local ADDON_NAME, ns = ...

local Loot = {}
ns.Loot = Loot

local f = CreateFrame("Frame")
local lootOpen = false
local lootSession = 0
local blizzardShown = false

------------------------------------------------------------------------
-- Blizzard loot frame control
------------------------------------------------------------------------
local function LootFrameAvailable()
    return LootFrame and LootFrame.GetScript and LootFrame:GetScript("OnEvent")
end

-- Events that make Blizzard's frame open itself. We only touch the ones it actually listens to,
-- and give back exactly those when "replace" is turned off.
local OPEN_EVENTS = { "LOOT_OPENED", "LOOT_READY" }
local taken = {}

function Loot:ApplyReplace()
    if not LootFrameAvailable() then return end
    for _, ev in ipairs(OPEN_EVENTS) do
        if ns.db.replace then
            if LootFrame:IsEventRegistered(ev) then
                LootFrame:UnregisterEvent(ev)
                taken[ev] = true
            end
        elseif taken[ev] then
            LootFrame:RegisterEvent(ev)
            taken[ev] = nil
        end
    end
end

local function ShowBlizzardLoot()
    if blizzardShown or not lootOpen then return end
    if not LootFrameAvailable() then return end
    blizzardShown = true
    local handler = LootFrame:GetScript("OnEvent")
    local ok, err = pcall(handler, LootFrame, "LOOT_OPENED", false)
    if not ok then
        geterrorhandler()(err)
    end
end

------------------------------------------------------------------------
-- Slot helpers (return layout differs between client versions)
------------------------------------------------------------------------
local function SlotLocked(slot)
    local t = { GetLootSlotInfo(slot) }
    if type(t[6]) == "boolean" then return t[6] end   -- texture, item, qty, currencyID, quality, locked
    if type(t[5]) == "boolean" then return t[5] end   -- texture, item, qty, quality, locked
    return false
end

local function SlotFilled(slot)
    if LootSlotHasItem and LootSlotHasItem(slot) then return true end
    local texture = GetLootSlotInfo(slot)
    return texture ~= nil
end

local function IAmMasterLooter()
    if not GetLootMethod then return false end
    local method, partyID = GetLootMethod()
    return method == "master" and partyID == 0
end

local function WantsManualWindow()
    -- Holding the auto-loot toggle key (Shift by default) gives you the normal window.
    if IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE") then return true end
    return IAmMasterLooter()
end

local function BindPopupVisible()
    return StaticPopup_Visible and (StaticPopup_Visible("LOOT_BIND") or StaticPopup_Visible("CONFIRM_LOOT_DISTRIBUTION"))
end

------------------------------------------------------------------------
-- Looting
------------------------------------------------------------------------
local function LootEverything()
    for slot = GetNumLootItems(), 1, -1 do
        if SlotFilled(slot) and not SlotLocked(slot) then
            LootSlot(slot)
        end
    end
end

-- After looting, see what is left over and decide what to do with it.
local function CheckLeftovers(session, tries)
    if session ~= lootSession or not lootOpen or blizzardShown then return end
    if BindPopupVisible() then
        C_Timer.After(0.3, function() CheckLeftovers(session, tries) end)
        return
    end
    local unlocked, locked = 0, 0
    for slot = 1, GetNumLootItems() do
        if SlotFilled(slot) then
            if SlotLocked(slot) then locked = locked + 1 else unlocked = unlocked + 1 end
        end
    end
    if unlocked > 0 then
        if tries < 2 then
            -- the server may still be handing items over; try once more before giving up
            LootEverything()
            C_Timer.After(0.35, function() CheckLeftovers(session, tries + 1) end)
        else
            ShowBlizzardLoot()
        end
    elseif locked > 0 or GetNumLootItems() == 0 then
        -- only items that are being rolled for (or nothing) left: close it like auto-loot does
        CloseLoot()
    end
end

-- Remember link, icon and quality of everything in the loot window, so loot messages that
-- carry only "[Item Name]" can still be shown with the right icon and color.
local function SnapshotSlots()
    for slot = 1, GetNumLootItems() do
        local t = { GetLootSlotInfo(slot) }
        local texture, name = t[1], t[2]
        local quality = (type(t[6]) == "boolean" or type(t[5]) == "number") and t[5] or t[4]
        if type(quality) ~= "number" then quality = nil end
        local link = GetLootSlotLink and GetLootSlotLink(slot)
        if name and name ~= "" then
            ns.Remember(link, texture, quality, name)
        elseif link then
            ns.Remember(link, texture, quality)
        end
    end
end

local function OnLootOpened()
    pcall(SnapshotSlots)
    lootOpen = true
    blizzardShown = false
    lootSession = lootSession + 1
    if not ns.db.replace then return end
    if WantsManualWindow() then
        ShowBlizzardLoot()
        return
    end
    LootEverything()
    local session = lootSession
    C_Timer.After(0.3, function() CheckLeftovers(session, 0) end)
end

------------------------------------------------------------------------
-- Loot messages -> feed
------------------------------------------------------------------------
local itemPatterns, moneyPatterns = {}, {}

local function AddItemPattern(global, kind)
    local fmt = _G[global]
    if not fmt then return end
    local pat = ns.FormatToPattern(fmt)
    -- "_MULTIPLE" formats carry a count; they must be tried first
    local multi = fmt:find("%%%d?%$?d") ~= nil
    table.insert(itemPatterns, multi and 1 or (#itemPatterns + 1), { pat = pat, kind = kind, multi = multi })
end

local function BuildPatterns()
    wipe(itemPatterns)
    AddItemPattern("LOOT_ITEM_SELF", "loot")
    AddItemPattern("LOOT_ITEM_PUSHED_SELF", "pushed")
    AddItemPattern("LOOT_ITEM_CREATED_SELF", "created")
    AddItemPattern("LOOT_ITEM_SELF_MULTIPLE", "loot")
    AddItemPattern("LOOT_ITEM_PUSHED_SELF_MULTIPLE", "pushed")
    AddItemPattern("LOOT_ITEM_CREATED_SELF_MULTIPLE", "created")

    wipe(moneyPatterns)
    local function coin(global, mult)
        local fmt = _G[global]
        if fmt then
            local p = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%d", "(%%d+)")
            moneyPatterns[#moneyPatterns + 1] = { pat = p, mult = mult }
        end
    end
    coin("GOLD_AMOUNT", 10000)
    coin("SILVER_AMOUNT", 100)
    coin("COPPER_AMOUNT", 1)
end

local function OnLootMessage(msg)
    for _, p in ipairs(itemPatterns) do
        local link, count = msg:match(p.pat)
        if link then
            if p.kind == "pushed" and not ns.db.pushed then return end
            if p.kind == "created" and not ns.db.created then return end
            ns.Feed:AddItem(link, tonumber(count) or 1)
            return
        end
    end
end

local function OnMoneyMessage(msg)
    local total = 0
    for _, p in ipairs(moneyPatterns) do
        local n = msg:match(p.pat)
        if n then total = total + tonumber(n) * p.mult end
    end
    if total > 0 then ns.Feed:AddMoney(total) end
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
f:SetScript("OnEvent", function(_, event, ...)
    if event == "LOOT_OPENED" then
        OnLootOpened()
    elseif event == "LOOT_CLOSED" then
        lootOpen = false
        blizzardShown = false
        lootSession = lootSession + 1
    elseif event == "CHAT_MSG_LOOT" then
        OnLootMessage((...))
    elseif event == "CHAT_MSG_MONEY" then
        OnMoneyMessage((...))
    elseif event == "UI_ERROR_MESSAGE" then
        local a, b = ...
        local msg = (type(b) == "string") and b or a
        if lootOpen and ns.db.replace and msg and msg == ERR_INV_FULL then
            ns.Feed:AddText("|cffff4040" .. ERR_INV_FULL .. "|r", "Interface\\Icons\\INV_Misc_Bag_08", 1, 0.25, 0.25)
            ShowBlizzardLoot()
        end
    end
end)

function Loot:Init()
    BuildPatterns()
    f:RegisterEvent("LOOT_OPENED")
    f:RegisterEvent("LOOT_CLOSED")
    f:RegisterEvent("CHAT_MSG_LOOT")
    f:RegisterEvent("CHAT_MSG_MONEY")
    f:RegisterEvent("UI_ERROR_MESSAGE")
    Loot:ApplyReplace()
end
