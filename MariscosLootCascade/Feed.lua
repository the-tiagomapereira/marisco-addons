-- Marisco's Loot Cascade - the cascading feed
-- Entries slide in, hold, then fade out slowly; older entries glide away as new ones arrive.

local ADDON_NAME, ns = ...

local Feed = {}
ns.Feed = Feed

local ROW_H      = 32    -- card height
local ROW_GAP    = 5     -- space between cards
local RADIUS     = 9     -- corner radius of the cards
local ICON       = 22
local RING       = 26    -- quality ring around the round icon
local FADE_IN    = 0.35
local DROP       = 14    -- a new card drops into place from this far back
local DRIFT      = 10    -- a fading card drifts this far along the cascade
local FAST_OUT   = 0.45  -- fade used when a card is pushed out by overflow
local MERGE_TIME = 3     -- loot of the same item within the hold merges into one card
local BOX_W      = 360   -- size of the area the cards live in (the cyan box)

local WHITE  = "Interface\\Buttons\\WHITE8X8"
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local anchor, driver
local active = {}        -- newest first
local pool = {}
local unlocked = false
local MONEY_KEY = "money"

------------------------------------------------------------------------
-- Item helpers
------------------------------------------------------------------------
local ItemIDFromLink = ns.ItemIDFromLink

local function ItemQuality(link)
    local _, _, q = ns.GetItemInfo(link)
    if q then return q end
    local hex = link:match("|c(%x%x%x%x%x%x%x%x)")
    if hex and ITEM_QUALITY_COLORS then
        hex = hex:lower()
        for i = 0, 7 do
            local c = ITEM_QUALITY_COLORS[i]
            if c and c.hex and c.hex:lower():find(hex, 1, true) then return i end
        end
    end
    return nil
end

local function ItemIcon(link)
    return ns.GetItemIcon(link)
end

local function QualityColor(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b, c.hex end
    return 1, 1, 1, "|cffffffff"
end

local function CoinText(copper)
    local fn = GetCoinTextureString or (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString)
    if fn then
        local ok, s = pcall(fn, copper)
        if ok and s then return s end
    end
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local out = {}
    if g > 0 then out[#out + 1] = "|cffffd700" .. g .. "g|r" end
    if s > 0 then out[#out + 1] = "|cffc7c7cf" .. s .. "s|r" end
    if c > 0 or #out == 0 then out[#out + 1] = "|cffeda55f" .. c .. "c|r" end
    return table.concat(out, " ")
end

local function CoinIcon(copper)
    if copper >= 10000 then return "Interface\\Icons\\INV_Misc_Coin_02" end
    if copper >= 100 then return "Interface\\Icons\\INV_Misc_Coin_04" end
    return "Interface\\Icons\\INV_Misc_Coin_06"
end

------------------------------------------------------------------------
-- Rows
------------------------------------------------------------------------
local function Row_OnEnter(self)
    local e = self.entry
    if not e then return end
    e.hovered = true
    if e.phase == "out" then e.phase, e.t = "hold", 0 end   -- hovering rescues a fading entry
    if ns.IsHyperlink(e.link) then
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetHyperlink(e.link)
        GameTooltip:Show()
    end
end

local function Row_OnLeave(self)
    if self.entry then self.entry.hovered = false end
    GameTooltip:Hide()
end

local function Row_OnMouseUp(self)
    local e = self.entry
    if not (e and ns.IsHyperlink(e.link)) then return end
    local wantLink = (IsModifiedClick and IsModifiedClick("CHATLINK")) or IsShiftKeyDown()
    if wantLink and ChatEdit_InsertLink then ChatEdit_InsertLink(e.link) end
end

------------------------------------------------------------------------
-- Shapes: WoW has no rounded rectangles, so a card is built from 3 strips and
-- 4 quarter-circle corners (circle masks). The pieces never overlap, so a
-- translucent color stays even.
------------------------------------------------------------------------
local canMask

local function NewRoundRect(f, layer, sub, inset, radius, blend)
    if canMask == nil then canMask = f.CreateMaskTexture ~= nil end
    local rr = { pieces = {} }
    local r = radius - inset
    local function piece()
        local t = f:CreateTexture(nil, layer, nil, sub)
        t:SetTexture(WHITE)
        if blend then t:SetBlendMode(blend) end
        rr.pieces[#rr.pieces + 1] = t
        return t
    end
    local c = piece()                                    -- center strip, full height
    c:SetPoint("TOPLEFT", inset + r, -inset)
    c:SetPoint("BOTTOMRIGHT", -(inset + r), inset)
    local l = piece()                                    -- left strip between the corners
    l:SetPoint("TOPLEFT", inset, -(inset + r))
    l:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", inset + r, inset + r)
    local rt = piece()                                   -- right strip
    rt:SetPoint("TOPRIGHT", -inset, -(inset + r))
    rt:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", -(inset + r), inset + r)

    local corners = {
        { "TOPLEFT",     inset, -inset, "BOTTOMRIGHT" },
        { "TOPRIGHT",   -inset, -inset, "BOTTOMLEFT"  },
        { "BOTTOMLEFT",  inset,  inset, "TOPRIGHT"    },
        { "BOTTOMRIGHT",-inset,  inset, "TOPLEFT"     },
    }
    for _, cd in ipairs(corners) do
        local t = piece()
        t:SetSize(r, r)
        t:SetPoint(cd[1], cd[2], cd[3])
        if canMask then
            local m = f:CreateMaskTexture()
            m:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            m:SetSize(r * 2, r * 2)
            m:SetPoint("CENTER", t, cd[4])           -- circle centered on the inner corner
            t:AddMaskTexture(m)
        end
    end

    function rr:SetColor(cr, cg, cb, ca)
        for _, t in ipairs(self.pieces) do t:SetVertexColor(cr, cg, cb, ca or 1) end
    end
    function rr:SetAlpha(a)
        for _, t in ipairs(self.pieces) do t:SetAlpha(a) end
    end
    return rr
end

ns.NewRoundRect = function(...) return NewRoundRect(...) end

local function NewCircle(f, layer, sub, size, texture)
    if canMask == nil then canMask = f.CreateMaskTexture ~= nil end
    local t = f:CreateTexture(nil, layer, nil, sub)
    t:SetSize(size, size)
    t:SetTexture(texture or WHITE)
    if canMask then
        local m = f:CreateMaskTexture()
        m:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(t)
        t:AddMaskTexture(m)
    end
    return t
end

------------------------------------------------------------------------
-- Cards
------------------------------------------------------------------------
local FILL = { 0.05, 0.05, 0.07, 0.84 }

local function NewRow()
    local f = CreateFrame("Frame", nil, anchor)
    f:SetHeight(ROW_H)
    if canMask == nil then canMask = f.CreateMaskTexture ~= nil end

    -- quality-colored rim, then the dark fill 1px inside it
    f.rim  = NewRoundRect(f, "BACKGROUND", 0, 0, RADIUS)
    f.fill = NewRoundRect(f, "BACKGROUND", 1, 1, RADIUS)
    f.fill:SetColor(FILL[1], FILL[2], FILL[3], ns.db.bgAlpha)
    -- flash shown when the same item is looted again
    f.flash = NewRoundRect(f, "BORDER", 0, 1, RADIUS, "ADD")
    f.flash:SetAlpha(0)

    -- round icon with a quality ring
    f.ring = NewCircle(f, "ARTWORK", 0, RING)
    f.ring:SetPoint("LEFT", (ROW_H - RING) / 2 + 1, 0)
    f.icon = NewCircle(f, "ARTWORK", 1, ICON, "Interface\\Icons\\INV_Misc_QuestionMark")
    f.icon:SetPoint("CENTER", f.ring, "CENTER")
    if not canMask then f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.text:SetPoint("LEFT", f.ring, "RIGHT", 8, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetShadowColor(0, 0, 0, 1)
    f.text:SetShadowOffset(1, -1)

    f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.sub:SetPoint("LEFT", f.text, "RIGHT", 7, 0)
    f.sub:SetJustifyH("LEFT")
    f.sub:SetTextColor(0.62, 0.62, 0.66)

    f:SetScript("OnEnter", Row_OnEnter)
    f:SetScript("OnLeave", Row_OnLeave)
    f:SetScript("OnMouseUp", Row_OnMouseUp)
    return f
end

local function AcquireRow()
    local f = table.remove(pool) or NewRow()
    f:EnableMouse(ns.db.mouse)
    f:SetAlpha(0)
    f:Show()
    return f
end

local function ReleaseEntry(e)
    local f = e.frame
    if GameTooltip:IsOwned(f) then GameTooltip:Hide() end
    f.entry = nil
    f:Hide()
    f:ClearAllPoints()
    pool[#pool + 1] = f
end

local function RefreshText(e)
    local f = e.frame
    local main, sub = "", ""
    if e.kind == "money" then
        main = CoinText(e.count)
    elseif e.kind == "item" then
        local name = ns.NameFromText(e.link) or "?"
        main = (e.hex or "|cffffffff") .. name .. "|r"
        if e.count > 1 then main = main .. "  |cffffffff\195\151" .. e.count .. "|r" end   -- "×"
        if ns.db.showCount then
            local have = ns.GetItemCountSafe(e.link)
            if have and have > 0 then sub = "(" .. have .. ")" end
        end
    else
        main = e.text
    end
    f.text:SetText(main)
    f.sub:SetText(sub)
    local w = (ROW_H - RING) / 2 + 1 + RING + 8 + f.text:GetStringWidth() + 14
    if sub ~= "" then w = w + 7 + f.sub:GetStringWidth() end
    f:SetWidth(math.floor(w + 0.5))
end

------------------------------------------------------------------------
-- Layout and animation
------------------------------------------------------------------------
local function TargetY(i) return (i - 1) * (ROW_H + ROW_GAP) end

-- y = distance along the cascade from the top (or bottom, when growing up); cards are centered.
local function Place(e)
    local f = e.frame
    local off = e.y + e.dy
    f:ClearAllPoints()
    if ns.db.grow == "up" then
        f:SetPoint("BOTTOM", anchor, "BOTTOM", 0, off)
    else
        f:SetPoint("TOP", anchor, "TOP", 0, -off)
    end
end

function Feed:Layout(snap)
    for i, e in ipairs(active) do
        e.targetY = TargetY(i)
        if snap then e.y = e.targetY end
        Place(e)
    end
end

local function Smooth(x) return x * x * (3 - 2 * x) end
local function EaseOut(x) return 1 - (1 - x) ^ 3 end

local function OnUpdate(_, elapsed)
    if #active == 0 then driver:Hide(); return end
    local db = ns.db
    local k = math.min(1, elapsed * 8)
    for i = #active, 1, -1 do
        local e = active[i]
        local f = e.frame
        e.t = e.t + elapsed

        if e.phase == "in" then
            local a = math.min(1, e.t / FADE_IN)
            f:SetAlpha(Smooth(a))
            e.dy = -DROP * (1 - EaseOut(a))
            if a >= 1 then e.phase, e.t, e.dy = "hold", 0, 0 end
        elseif e.phase == "hold" then
            f:SetAlpha(1)
            e.dy = 0
            if not e.hovered and e.t >= e.holdTime then e.phase, e.t = "out", 0 end
        end

        if e.phase == "out" then
            local dur = e.fast and FAST_OUT or db.fade
            local a = math.min(1, e.t / dur)
            f:SetAlpha(1 - Smooth(a))
            e.dy = DRIFT * Smooth(a)
            if a >= 1 then
                table.remove(active, i)
                ReleaseEntry(e)
                Feed:Layout(false)
            end
        end

        if e.glowT and e.glowT > 0 then
            e.glowT = math.max(0, e.glowT - elapsed)
            f.flash:SetAlpha(0.45 * (e.glowT / 0.6))
        end

        if active[i] == e then
            e.y = e.y + (e.targetY - e.y) * k
            if math.abs(e.targetY - e.y) < 0.3 then e.y = e.targetY end
            Place(e)
        end
    end
end

local function HoldFor(quality)
    local extra = 0
    if ns.db.rarityBonus then extra = math.max(0, (quality or 1) - 2) end   -- rare +1s, epic +2s, legendary +3s
    return ns.db.hold + extra
end

-- Too many cards: the oldest ones fade out quickly, wherever they sit in the list.
local function TrimOverflow()
    local live = {}
    for _, e in ipairs(active) do
        if not (e.phase == "out" and e.fast) then live[#live + 1] = e end
    end
    table.sort(live, function(a, b) return a.seq < b.seq end)
    for i = 1, #live - ns.db.maxLines do
        live[i].phase, live[i].t, live[i].fast = "out", 0, true
    end
end

local seq = 0

-- atBottom: the new card goes under the others instead of on top (used by the sample loot,
-- so it reads money first, then gray ... legendary last).
local function Push(e, atBottom)
    seq = seq + 1
    e.seq = seq
    local f = AcquireRow()
    f.entry = e
    e.frame = f
    e.phase, e.t, e.y, e.dy = "in", 0, 0, -DROP
    e.holdTime = HoldFor(e.quality)

    f.icon:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    local r, g, b = e.r or 1, e.g or 1, e.b or 1
    f.rim:SetColor(r, g, b, 0.85)
    f.ring:SetVertexColor(r, g, b, 1)
    f.flash:SetColor(r, g, b, 1)
    f.flash:SetAlpha(0)
    RefreshText(e)

    if atBottom then
        table.insert(active, e)
    else
        table.insert(active, 1, e)   -- top slot; the others glide down to make room
    end
    for i, a in ipairs(active) do a.targetY = TargetY(i) end
    e.y = e.targetY
    Place(e)
    TrimOverflow()
    driver:Show()
end

local function FindMergeable(key)
    for _, e in ipairs(active) do
        if e.key == key and e.phase ~= "out" and (GetTime() - e.born) < (e.holdTime + MERGE_TIME) then
            return e
        end
    end
end

local function Bump(e, add)
    e.count = e.count + add
    e.t = (e.phase == "hold") and 0 or e.t
    e.glowT = 0.6
    RefreshText(e)
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------
-- `text` is whatever the loot message carried: a full item link or just "[Item Name]".
function Feed:AddItem(text, count, retried)
    if not text then return end
    count = count or 1
    local link, icon, quality = ns.ResolveItem(text, true)
    if not ns.IsHyperlink(link) and not retried then
        -- the item may not be in the bags yet when the message arrives; look again shortly
        C_Timer.After(0.4, function() Feed:AddItem(text, count, true) end)
        return
    end
    if ns.IsHyperlink(link) then quality = quality or ItemQuality(link) end
    quality = quality or 1
    if quality < ns.db.minQuality then return end
    local key = "item:" .. (ns.NameFromText(link) or link)
    local e = FindMergeable(key)
    if e then Bump(e, count); return end
    local r, g, b, hex = QualityColor(quality)
    Push({ kind = "item", key = key, link = link, id = ItemIDFromLink(link), count = count,
           quality = quality, hex = hex, icon = icon or ItemIcon(link),
           r = r, g = g, b = b, born = GetTime() })
end

function Feed:AddMoney(copper)
    if not ns.db.money or not copper or copper <= 0 then return end
    local e = FindMergeable(MONEY_KEY)
    if e then
        Bump(e, copper)
        e.frame.icon:SetTexture(CoinIcon(e.count))
        return
    end
    Push({ kind = "money", key = MONEY_KEY, count = copper, quality = 1, icon = CoinIcon(copper),
           r = 1, g = 0.82, b = 0, born = GetTime() })
end

function Feed:AddText(text, icon, r, g, b)
    local key = "text:" .. text
    local e = FindMergeable(key)
    if e then e.t = 0; e.glowT = 0.6; return end
    Push({ kind = "text", key = key, text = text, count = 1, quality = 1, icon = icon,
           r = r, g = g, b = b, born = GetTime() })
end

-- Icons for items that weren't cached when they were looted
function Feed:RefreshIcons()
    for _, e in ipairs(active) do
        if e.kind == "item" and not e.icon then
            e.icon = ItemIcon(e.link)
            if e.icon then e.frame.icon:SetTexture(e.icon) end
        end
    end
end

function Feed:RefreshCounts()
    for _, e in ipairs(active) do
        if e.kind == "item" then RefreshText(e) end
    end
end

local function BoxHeight() return ns.db.maxLines * (ROW_H + ROW_GAP) - ROW_GAP end

-- Default spot: horizontally centered, top edge about a third of the screen above center
-- (the area marked on the screenshot).
local function DefaultY() return math.floor((UIParent:GetHeight() or 768) * 0.34) end

function Feed:ApplySettings()
    local d = ns.db
    for _, e in ipairs(active) do e.frame.fill:SetColor(FILL[1], FILL[2], FILL[3], d.bgAlpha) end
    for _, f in ipairs(pool) do f.fill:SetColor(FILL[1], FILL[2], FILL[3], d.bgAlpha) end
    anchor:SetScale(d.scale)
    anchor:SetSize(BOX_W, BoxHeight())
    anchor:ClearAllPoints()
    -- the position is stored in screen (UIParent) units so resizing doesn't move the feed
    local sc = d.scale or 1
    anchor:SetPoint(d.point or "TOP", UIParent, d.relPoint or "CENTER", (d.x or 0) / sc, (d.y or DefaultY()) / sc)
    for _, e in ipairs(active) do e.frame:EnableMouse(d.mouse) end
    for _, f in ipairs(pool) do f:EnableMouse(d.mouse) end
end

function Feed:GetAnchor() return anchor end

function Feed:SetUnlocked(on, quiet)
    unlocked = on
    anchor.handle:SetShown(on)
    if quiet then return end
    if on then
        ns:Print("Feed unlocked: drag the cyan box, then type /mlc lock.")
        Feed:Test()
    else
        ns:Print("Feed locked.")
    end
end

------------------------------------------------------------------------
-- Sample loot: one card of every rarity, from gray to legendary.
-- Uses the real item when the client knows it, otherwise the name/icon/color below.
------------------------------------------------------------------------
local SAMPLE_UNCOMMON = {
    { name = "Runed Copper Breastplate", icon = "Interface\\Icons\\INV_Chest_Chain_05" },
    { name = "Hillman's Shoulders",      icon = "Interface\\Icons\\INV_Shoulder_07" },
    { name = "Green Iron Bracers",       icon = "Interface\\Icons\\INV_Bracer_07" },
    { name = "Barbaric Cloth Robe",      icon = "Interface\\Icons\\INV_Chest_Cloth_21" },
    { name = "Glowing Lizardscale Cloak", icon = "Interface\\Icons\\INV_Misc_Cape_18" },
}
local SAMPLE_RARE = {
    { name = "Cruel Barb",         icon = "Interface\\Icons\\INV_Sword_23", id = 5191 },
    { name = "Smite's Reaver",     icon = "Interface\\Icons\\INV_Axe_10" },
    { name = "Thrash Blade",       icon = "Interface\\Icons\\INV_Sword_36" },
    { name = "Cookie's Tenderizer", icon = "Interface\\Icons\\INV_Mace_04" },
}

local function Pick(list) return list[math.random(1, #list)] end

local function SampleSet()
    return {
        { name = "Defias Mask",  quality = 0, icon = "Interface\\Icons\\INV_Misc_Bandana_01" },
        { name = "Hearthstone",  quality = 1, icon = "Interface\\Icons\\INV_Misc_Rune_01", id = 6948 },
        (function() local t = Pick(SAMPLE_UNCOMMON); t.quality = 2; return t end)(),
        (function() local t = Pick(SAMPLE_RARE); t.quality = 3; return t end)(),
        { name = "Corrupted Ashbringer", quality = 4, icon = "Interface\\Icons\\INV_Sword_48", id = 22691 },
        { name = "Thunderfury, Blessed Blade of the Windseeker", quality = 5,
          icon = "Interface\\Icons\\INV_Sword_39", id = 19019 },
    }
end

local function AddSample(s)
    local r, g, b, hex = QualityColor(s.quality)
    local link, icon = nil, s.icon
    if s.id then
        local _, realLink, _, _, _, _, _, _, _, realIcon = ns.GetItemInfo(s.id)
        if realLink then
            link, icon = realLink, realIcon or icon
        else
            -- a hand-built link still opens the item tooltip
            link = (hex or "|cffffffff") .. "|Hitem:" .. s.id .. "::::::::|h[" .. s.name .. "]|h|r"
        end
    end
    link = link or ("[" .. s.name .. "]")
    Push({ kind = "item", key = "sample:" .. s.name .. ":" .. GetTime(), link = link, count = 1,
           quality = s.quality, hex = hex, icon = icon, r = r, g = g, b = b, born = GetTime() }, true)
end

function Feed:Test()
    local set = SampleSet()
    -- ask the client to load the real items (Hearthstone, Ashbringer, Thunderfury) for next time
    if C_Item and C_Item.RequestLoadItemDataByID then
        for _, s in ipairs(set) do if s.id then pcall(C_Item.RequestLoadItemDataByID, s.id) end end
    end
    local copper = math.random(1, 35) * 10000 + math.random(0, 99) * 100 + math.random(0, 99)
    if math.random() < 0.3 then copper = math.random(100, 9999) end   -- sometimes just silver
    -- start from a clean feed, then add money first and each rarity below the previous one
    for k = #active, 1, -1 do ReleaseEntry(active[k]); active[k] = nil end
    Push({ kind = "money", key = "sample:money:" .. GetTime(), count = copper, quality = 1,
           icon = CoinIcon(copper), r = 1, g = 0.82, b = 0, born = GetTime() }, true)
    for i, s in ipairs(set) do
        C_Timer.After(i * 0.4, function() AddSample(s) end)
    end
end

function Feed:Init()
    anchor = CreateFrame("Frame", "MariscosLootCascadeAnchor", UIParent)
    anchor:SetFrameStrata("MEDIUM")
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)

    local h = CreateFrame("Frame", nil, anchor)
    h:SetAllPoints()
    h:SetFrameLevel(anchor:GetFrameLevel() + 20)
    h.tex = h:CreateTexture(nil, "BACKGROUND")
    h.tex:SetAllPoints()
    h.tex:SetTexture(WHITE)
    h.tex:SetVertexColor(0, 0.9, 1, 0.18)
    local edges = { {"TOPLEFT","TOPRIGHT",nil,2}, {"BOTTOMLEFT","BOTTOMRIGHT",nil,2},
                    {"TOPLEFT","BOTTOMLEFT",2,nil}, {"TOPRIGHT","BOTTOMRIGHT",2,nil} }
    for _, ed in ipairs(edges) do
        local t = h:CreateTexture(nil, "BORDER")
        t:SetTexture(WHITE)
        t:SetVertexColor(0, 0.9, 1, 0.9)
        t:SetPoint(ed[1]); t:SetPoint(ed[2])
        if ed[3] then t:SetWidth(ed[3]) else t:SetHeight(ed[4]) end
    end
    h.label = h:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    h.label:SetPoint("CENTER")
    h.label:SetText("Loot Cascade\ndrag to move")

    -- 1: title and 2: instruction, above the box's top-left corner
    h.sub = h:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    h.sub:SetPoint("BOTTOMLEFT", h, "TOPLEFT", 0, 6)
    h.sub:SetText("Drag the cyan box on screen to move the feed")
    h.sub:SetShadowOffset(1, -1)
    h.title = h:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    h.title:SetPoint("BOTTOMLEFT", h.sub, "TOPLEFT", 0, 4)
    h.title:SetText("Position")
    h.title:SetShadowOffset(1, -1)

    -- Show sample loot: below the box's bottom-left corner
    h.sample = CreateFrame("Button", nil, h, "UIPanelButtonTemplate")
    h.sample:SetSize(150, 24)
    h.sample:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
    h.sample:SetText("Show sample loot")
    h.sample:SetScript("OnClick", function() Feed:Test() end)

    -- Reset position: below the box's bottom-right corner
    h.reset = CreateFrame("Button", nil, h, "UIPanelButtonTemplate")
    h.reset:SetSize(150, 24)
    h.reset:SetPoint("TOPRIGHT", h, "BOTTOMRIGHT", 0, -6)
    h.reset:SetText("Reset position")
    h.reset:SetScript("OnClick", function()
        for _, k in ipairs({ "point", "relPoint", "x", "y" }) do ns.db[k] = ns.defaults[k] end
        Feed:ApplySettings()
    end)
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function() anchor:StartMoving() end)
    h:SetScript("OnDragStop", function()
        anchor:StopMovingOrSizing()
        local p, _, rp, x, y = anchor:GetPoint(1)
        local sc = anchor:GetScale() or 1
        ns.db.point, ns.db.relPoint, ns.db.x, ns.db.y = p, rp, x * sc, y * sc
    end)
    h:Hide()
    anchor.handle = h

    driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", OnUpdate)
    driver:Hide()

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    ev:RegisterEvent("BAG_UPDATE")
    local pending = false
    ev:SetScript("OnEvent", function(_, event)
        if #active == 0 then return end
        if event == "GET_ITEM_INFO_RECEIVED" then
            Feed:RefreshIcons()
        elseif not pending then
            pending = true
            C_Timer.After(0.2, function() pending = false; Feed:RefreshCounts() end)
        end
    end)

    Feed:ApplySettings()
end
