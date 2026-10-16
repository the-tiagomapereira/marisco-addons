-- Marisco's Item Value Scanner - Tooltips (bags and chat links)
-- v0.5: the addon's information is shown in its own panel attached to the
-- game's tooltip instead of being appended inside it.

local _, ns = ...

local GetItemInfoFn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local tracked = {}   -- tooltip -> { fs = FontString, t = timestamp, stamp = string }

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

local function ItemIDFromLink(link)
    return link and tonumber(link:match("item:(%d+)"))
end

-- Stack size of the bag slot being hovered (1 for chat links).
local function GetStackCount(tooltip)
    if tooltip ~= GameTooltip then return 1 end
    local owner = tooltip:GetOwner()
    local count = owner and owner.count
    if type(count) == "number" and count > 1 then return count end
    return 1
end

local function MoneyLine(tooltip, label, copper, count)
    local text = ns.FormatMoney(copper)
    if count > 1 then
        text = text .. " |cffaaaaaa(x" .. count .. ": " .. ns.FormatMoney(copper * count) .. ")|r"
    end
    tooltip:AddDoubleLine(label, text, 1, 0.82, 0, 1, 1, 1)
end

------------------------------------------------------------------------
-- Our own tooltip panel, attached under (or above) the game's tooltip,
-- so the addon's information is clearly separate from Blizzard's.
------------------------------------------------------------------------
local companions = {}   -- game tooltip -> our panel

local MARGIN = 12   -- extra pixels added to the width the text needs
local GAP    = 2    -- space between the game tooltip and our panel

local Anchor   -- forward declaration

local function GetCompanion(parent)
    local c = companions[parent]
    if not c then
        c = CreateFrame("GameTooltip", "MariscosIVS_" .. (parent:GetName() or "Tooltip") .. "Panel",
            UIParent, "GameTooltipTemplate")
        c:SetFrameStrata("TOOLTIP")
        c:SetClampedToScreen(true)
        c:HookScript("OnUpdate", function(self)
            if not parent:IsShown() then self:Hide(); return end
            local ok, _, link = pcall(parent.GetItem, parent)
            if ok and link ~= self.__mivsLink and not (link and IsSecret(link)) then
                -- the game tooltip now shows something else (or no item): drop our panel
                self.__mivsSig, self.__mivsLink = nil, nil
                tracked[self] = nil
                self:Hide()
                return
            end
            self:SetAlpha(parent:GetAlpha())     -- follow the game tooltip's fade-out
            Anchor(self, parent)                 -- comparison tooltips come and go: keep clear of them
        end)
        companions[parent] = c
    end
    return c
end

-- Size to the text: let the tooltip measure its own lines (it counts coin icons
-- correctly), then add a small margin. Never force a fixed width.
local function Fit(c)
    if not c.SetMinimumWidth then c:Show(); return end
    c:SetMinimumWidth(0)
    c:Show()                                   -- natural width = widest line
    c:SetMinimumWidth(math.ceil(c:GetWidth()) + MARGIN)
    c:Show()
end

-- The game tooltip plus any comparison tooltips ("Equipped") shown next to it.
-- Returns their lowest bottom and highest top, in screen pixels.
local function GroupBounds(parent)
    local s = parent:GetEffectiveScale()
    local bottom, top = (parent:GetBottom() or 0) * s, (parent:GetTop() or 0) * s
    for _, t in ipairs(parent.shoppingTooltips or {}) do
        if t:IsShown() and t:GetBottom() then
            local ts = t:GetEffectiveScale()
            bottom = math.min(bottom, t:GetBottom() * ts)
            top    = math.max(top, t:GetTop() * ts)
        end
    end
    return bottom, top
end

-- Exactly ONE anchor, always clear of the whole tooltip group:
-- below the lowest tooltip, or above the highest one if there's no room below.
Anchor = function(c, parent, force)
    if not parent:GetBottom() then return end
    local ps, cs = parent:GetEffectiveScale(), c:GetEffectiveScale()
    local groupBottom, groupTop = GroupBounds(parent)
    local height = c:GetHeight() * cs

    local point, relPoint, y
    if groupBottom - height - GAP * cs >= 0 then
        point, relPoint = "TOPLEFT", "BOTTOMLEFT"
        y = (groupBottom - parent:GetBottom() * ps) / cs - GAP
    else
        point, relPoint = "BOTTOMLEFT", "TOPLEFT"
        y = (groupTop - parent:GetTop() * ps) / cs + GAP
    end

    if force or c:GetNumPoints() ~= 1 or c.__mivsPoint ~= point or math.abs((c.__mivsY or 0) - y) > 0.5 then
        c:ClearAllPoints()
        c:SetPoint(point, parent, relPoint, 0, y)
        c.__mivsPoint, c.__mivsY = point, y
    end
end

local function Place(c, parent)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -GAP)   -- anchor before showing (see v0.6 fix)
    Fit(c)
    Anchor(c, parent, true)
end

local function AddPriceLines(parent, link)
    if not link or IsSecret(link) then return end
    local itemID = ItemIDFromLink(link)
    if not itemID then return end

    local count = GetStackCount(parent)
    local sellPrice = select(11, GetItemInfoFn(link)) or 0
    local entry = ns.data and ns.data.prices[itemID]

    -- Bag slots re-set their tooltip many times per second. If the panel already shows
    -- this exact item (same stack size, same scan), leave it alone - rebuilding it each
    -- time is what made it flicker (v0.9 fix).
    local signature = link .. "#" .. count .. "#" .. tostring(ns.data and ns.data.lastScan)
    local existing = companions[parent]
    if existing and existing:IsShown() and existing.__mivsSig == signature then return end

    local tooltip = GetCompanion(parent)
    tooltip.__mivsSig, tooltip.__mivsLink = signature, link
    tooltip:SetOwner(parent, "ANCHOR_NONE")
    tooltip:ClearLines()
    tooltip:AddLine(ns.TITLE, 0.41, 0.8, 0.94)

    -- Vendor price (straight from the game)
    if sellPrice > 0 then
        MoneyLine(tooltip, "Vendor price:", sellPrice, count)
    else
        tooltip:AddDoubleLine("Vendor price:", "|cff808080Can't be sold|r", 1, 0.82, 0)
    end

    -- AH price (from the latest scan)
    local listedNow = entry and ns.data.lastScan and entry.t == ns.data.lastScan
    if entry then
        MoneyLine(tooltip, listedNow and "AH price (min buyout):" or "AH price (last seen):", entry.min, count)
        if listedNow then
            local listed = entry.auctions
                and string.format("%d listed in %d auction%s", entry.qty or 0, entry.auctions,
                    entry.auctions == 1 and "" or "s")
                or string.format("%d listed", entry.qty or 0)
            tooltip:AddDoubleLine("On the AH:", listed, 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
        else
            tooltip:AddDoubleLine(" ", ns.data.lastScanComplete
                and "|cffff8040Not listed in the latest scan|r"
                or "|cffffd100Not reached by the latest (partial) scan|r")
        end
    else
        tooltip:AddDoubleLine("AH price:", ns.data and ns.data.lastScan
            and "|cff808080Not seen on the AH|r" or "|cff808080No scan yet|r", 1, 0.82, 0)
    end

    -- Difference vendor vs AH
    if entry and sellPrice > 0 then
        local diff = (entry.min - sellPrice) * count
        local text
        if diff > 0 then
            text = "|cff00ff00+" .. ns.FormatMoney(diff) .. " on the AH|r"
        elseif diff < 0 then
            text = "|cffff4040+" .. ns.FormatMoney(diff) .. " at the vendor|r"
        else
            text = "|cffffffffSame either way|r"
        end
        tooltip:AddDoubleLine("Difference:", text, 1, 0.82, 0)
    end

    -- Disenchant: possible materials and their value
    if ns.db.showDisenchant and ns.GetDisenchantOutcomes then
        local outcomes = ns.GetDisenchantOutcomes(link)
        if outcomes then
            local expected, low, high, missing = ns.ValueDisenchant(outcomes)
            tooltip:AddLine("Disenchants into (estimate):", 0.64, 0.21, 0.93)
            for _, o in ipairs(outcomes) do
                local qty = o.min == o.max and ("x" .. o.min) or ("x" .. o.min .. "-" .. o.max)
                local chance = o.chance >= 0.01 and string.format("%d%%", math.floor(o.chance * 100 + 0.5))
                    or string.format("%.1f%%", o.chance * 100)
                local priceText = o.price and (ns.FormatMoney(o.price) .. " each") or "|cff808080no AH price|r"
                tooltip:AddDoubleLine(string.format("  %s %s |cffaaaaaa(%s)|r", o.name, qty, chance),
                    priceText, 1, 1, 1, 1, 1, 1)
            end
            if expected > 0 then
                tooltip:AddDoubleLine("Possible DE value:",
                    ns.FormatMoney(low) .. " - " .. ns.FormatMoney(high), 1, 0.82, 0, 1, 1, 1)
                tooltip:AddDoubleLine("Expected DE value:", ns.FormatMoney(expected) ..
                    (missing and " |cffffd100(some mats unpriced)|r" or ""), 1, 0.82, 0, 1, 1, 1)

                -- Best way to cash in this item
                local best, bestValue = "Disenchant", expected
                if entry and entry.min > bestValue then best, bestValue = "Auction House", entry.min end
                if sellPrice > bestValue then best, bestValue = "Vendor", sellPrice end
                tooltip:AddDoubleLine("Best option:", "|cff00ff00" .. best .. " (" .. ns.FormatMoney(bestValue) .. ")|r",
                    1, 0.82, 0)
            else
                tooltip:AddDoubleLine("Possible DE value:", "|cff808080scan the AH to price the mats|r", 1, 0.82, 0)
            end
        end
    end

    -- Last scan: date/time + live age
    local t = (entry and entry.t) or (ns.data and ns.data.lastScan)
    if t then
        local stamp = ns.FormatDate(t)
        tooltip:AddDoubleLine("Last scan:", stamp .. " |cffaaaaaa(" .. ns.FormatAge(time() - t) .. ")|r",
            1, 0.82, 0, 1, 1, 1)
        local name = tooltip:GetName()
        local fs = name and _G[name .. "TextRight" .. tooltip:NumLines()]
        if fs then tracked[tooltip] = { fs = fs, t = t, stamp = stamp } end
    end

    Place(tooltip, parent)
end

local function OnParentHide(parent)
    local c = companions[parent]
    if c then
        c.__mivsSig, c.__mivsLink = nil, nil
        tracked[c] = nil
        c:Hide()
    end
end

local function OnTooltipItem(tooltip)
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
    local ok, _, link = pcall(tooltip.GetItem, tooltip)
    if ok then AddPriceLines(tooltip, link) end
end

-- Keeps the "x seconds/minutes/hours/days ago" text ticking while a tooltip is open.
local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.5 then return end
    acc = 0
    for tooltip, info in pairs(tracked) do
        if tooltip:IsShown() and info.fs then
            local text = info.stamp .. " |cffaaaaaa(" .. ns.FormatAge(time() - info.t) .. ")|r"
            if info.fs:GetText() ~= text then
                local oldLen = #(info.fs:GetText() or "")
                info.fs:SetText(text)
                if #text ~= oldLen then Fit(tooltip) end   -- re-fit width
            end
        else
            tracked[tooltip] = nil
        end
    end
end)

function ns:InitTooltips()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipItem)
    else
        GameTooltip:HookScript("OnTooltipSetItem", OnTooltipItem)
        ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipItem)
    end
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
        -- Not OnTooltipCleared: bags clear and re-set their tooltip constantly, and hiding
        -- the panel on every clear made it flicker. Item changes are caught in OnUpdate.
        tt:HookScript("OnHide", OnParentHide)
    end
end
