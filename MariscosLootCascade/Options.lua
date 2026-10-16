-- Marisco's Loot Cascade - settings panel
-- Same window style as Marisco's Cursor Tooltip: the game's own framed window with a round
-- portrait, gold section headers and Blizzard sliders.
-- Changes preview live. Save keeps them, Default loads the original settings, Cancel / X / Escape
-- closes and puts back what you had when you opened it.

local ADDON_NAME, ns = ...

local Options = {}
ns.Options = Options

local PANEL_NAME  = "MariscosLootCascadeOptions"
local TITLE_LEFT, TITLE_RIGHT = 44, 32   -- title bar area: right of the round icon, left of the X
local ADDON_TITLE = "Marisco's Loot Cascade"
-- "Marisco's Loot Cascade - v0.13 Beta", same format as Marisco's Cursor Tooltip
-- gold name, white version
local FULL_TITLE  = ADDON_TITLE .. " - |cffffffff" .. ns.VERSION:gsub(" %- ", " ") .. "|r"
local KEYS = { "scale", "bgAlpha", "hold", "rarityBonus", "point", "relPoint", "x", "y" }   -- what the panel controls

local panel
local widgets = {}
local snapshot, saved

local function Round(v) return math.floor(v + 0.5) end

local function T(v) if type(v) == "table" then return v end end   -- a frame/region, or nil

local function TryFrame(kind, name, parent, template)
    local ok, f = pcall(CreateFrame, kind, name, parent, template)
    if ok then return f end
end

------------------------------------------------------------------------
-- Widgets (same look as Marisco's Cursor Tooltip)
------------------------------------------------------------------------
local function Header(parent, text, y)
    local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetPoint("TOPLEFT", 24, y)
    h:SetText(text)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetHeight(1)
    line:SetPoint("LEFT", h, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", parent, "RIGHT", -24, 0)
    return h
end

local function Note(parent, text, y)
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("TOPLEFT", 26, y)
    t:SetPoint("RIGHT", parent, "RIGHT", -24, 0)
    t:SetJustifyH("LEFT")
    t:SetText(text)
    return t
end

-- Label on the left and value on the right above the bar; the bar spans the window's width.
local function MakeSlider(parent, label, minV, maxV, step, y, key, fmt)
    local s = CreateFrame("Slider", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetHeight(17)
    s:SetPoint("TOPLEFT", 26, y)
    s:SetPoint("TOPRIGHT", -26, y)
    if s.SetBackdrop then
        s:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
            edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 3, right = 3, top = 6, bottom = 6 },
        })
    end
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:EnableMouseWheel(true)

    local t = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 3)
    t:SetText(label)
    local v = s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    v:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", 0, 3)

    local function Snap(val) return Round(val / step) * step end

    s:SetScript("OnValueChanged", function(self, val)
        val = Snap(val)
        v:SetText(fmt(val))
        if self.loading then return end
        ns.db[key] = val
        ns.Feed:ApplySettings()
    end)
    s:SetScript("OnMouseWheel", function(self, d)
        self:SetValue(math.max(minV, math.min(maxV, self:GetValue() + d * step)))
    end)
    s.Refresh = function()
        s.loading = true
        local val = math.max(minV, math.min(maxV, ns.db[key] or minV))
        s:SetValue(val)
        v:SetText(fmt(Snap(val)))
        s.loading = false
    end
    widgets[#widgets + 1] = s
    return s
end

local function MakeCheck(parent, label, x, y, getter, setter)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    c:SetPoint("TOPLEFT", x, y)
    local t = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("LEFT", c, "RIGHT", 2, 1)
    t:SetText(label)
    c:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
    c.Refresh = function() c:SetChecked(getter() and true or false) end
    widgets[#widgets + 1] = c
    return c
end

local function Percent(v) return ("%d%%"):format(Round(v * 100)) end

------------------------------------------------------------------------
-- Panel
------------------------------------------------------------------------
local function Copy(src)
    local t = {}
    for _, k in ipairs(KEYS) do t[k] = src[k] end
    return t
end

local function RefreshAll()
    for _, w in ipairs(widgets) do w.Refresh() end
end

local function Build()
    local W, H = 330, 420
    local p = TryFrame("Frame", PANEL_NAME, UIParent, "ButtonFrameTemplate")
    local styled = p ~= nil
    if not styled then
        p = CreateFrame("Frame", PANEL_NAME, UIParent, BackdropTemplateMixin and "BackdropTemplate")
        p:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end
    panel = p
    p:SetSize(W, H)
    p:SetPoint("CENTER", UIParent, "CENTER", -430, 40)
    p:SetFrameStrata("DIALOG")
    p:SetClampedToScreen(true)
    p:EnableMouse(true)
    p:SetMovable(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving)
    p:SetScript("OnDragStop", p.StopMovingOrSizing)
    p:Hide()
    table.insert(UISpecialFrames, PANEL_NAME)   -- Escape closes it (= Cancel)

    local inset
    if styled then
        local t = T(p.TitleText) or (T(p.TitleContainer) and T(p.TitleContainer.TitleText)) or T(_G[PANEL_NAME .. "TitleText"])
        if p.SetTitle then pcall(p.SetTitle, p, FULL_TITLE) end
        if t then
            -- center the title across the whole title bar, a touch smaller (same as Cursor Tooltip)
            t:SetText(FULL_TITLE)
            local font, size, flags = t:GetFont()
            if font and size then t:SetFont(font, size - 1, flags) end
            -- centered in the title bar between the round icon and the X button
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", p, "TOPLEFT", TITLE_LEFT, -5)
            t:SetPoint("TOPRIGHT", p, "TOPRIGHT", -TITLE_RIGHT, -5)
            t:SetJustifyH("CENTER")
        end
        local portrait = (T(p.PortraitContainer) and T(p.PortraitContainer.portrait)) or T(p.portrait) or T(_G[PANEL_NAME .. "Portrait"])
        if portrait then
            if p.SetPortraitToAsset then p:SetPortraitToAsset(ns.ICON)
            elseif SetPortraitToTexture then SetPortraitToTexture(portrait, ns.ICON)
            else portrait:SetTexture(ns.ICON) end
        end
        inset = T(p.Inset) or T(_G[PANEL_NAME .. "Inset"])
    else
        local header = p:CreateTexture(nil, "OVERLAY")
        header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
        header:SetSize(340, 64)
        header:SetPoint("TOP", 0, 12)
        local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", header, "TOP", 0, -14)
        title:SetText(FULL_TITLE)
        local close = CreateFrame("Button", nil, p, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -6, -6)
    end
    if not inset then inset = TryFrame("Frame", nil, p, "InsetFrameTemplate") end
    if inset then
        inset:ClearAllPoints()
        -- the window's right border is 2 px thicker than the left one (Blizzard's own inset uses
        -- 4 / -6), so the inset is shifted by that much to leave equal margins on both sides
        inset:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -28)
        inset:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -12, 46)
    end

    -- Loot cards
    Header(p, "Loot cards", -62)
    Note(p, "Size and look of the cards. The cyan box on screen shows where they appear.", -80)
    MakeSlider(p, "Size", 0.6, 1.6, 0.05, -138, "scale", Percent)
    MakeSlider(p, "Background opacity", 0, 1, 0.05, -183, "bgAlpha", Percent)

    -- Fade out
    Header(p, "Fade out", -225)
    Note(p, "How long each card stays on screen before it slowly fades away.", -243)

    local after = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    after:SetPoint("TOPLEFT", 26, -285)
    after:SetText("Fade out after")
    local checks = {}
    local function Refresh() for _, c in ipairs(checks) do c.Refresh() end end
    for i, secs in ipairs({ 3, 5, 8 }) do
        -- ticking one unticks the others
        checks[i] = MakeCheck(p, secs .. " seconds", 22 + (i - 1) * 98, -300,
            function() return ns.db.hold == secs end,
            function() ns.db.hold = secs; Refresh() end)
    end

    MakeCheck(p, "Rarity increases screen time", 22, -330,
        function() return ns.db.rarityBonus end,
        function(v) ns.db.rarityBonus = v end)

    -- bottom buttons: Save / Default / Cancel
    local function Button(text, point, x)
        local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        b:SetSize(96, 22)
        b:SetPoint(point, x, 14)
        b:SetText(text)
        return b
    end
    local save = Button("Save", "BOTTOMLEFT", 14)
    save:SetScript("OnClick", function()
        saved = true
        p:Hide()
        ns:Print("Settings saved.")
    end)
    local default = Button("Default", "BOTTOM", 0)
    default:SetScript("OnClick", function()
        for _, k in ipairs(KEYS) do ns.db[k] = ns.defaults[k] end
        ns.Feed:ApplySettings()
        RefreshAll()
        ns.Feed:Test()
    end)
    local cancel = Button("Cancel", "BOTTOMRIGHT", -14)
    cancel:SetScript("OnClick", function() p:Hide() end)

    p:SetScript("OnShow", function()
        snapshot, saved = Copy(ns.db), false
        RefreshAll()
        ns.Feed:SetUnlocked(true, true)
        ns.Feed:Test()
    end)
    p:SetScript("OnHide", function()
        ns.Feed:SetUnlocked(false, true)
        if not saved and snapshot then
            for _, k in ipairs(KEYS) do ns.db[k] = snapshot[k] end
            ns.Feed:ApplySettings()
        end
        snapshot = nil
    end)
end

function Options:Toggle()
    if not panel then Build() end
    panel:SetShown(not panel:IsShown())
end
