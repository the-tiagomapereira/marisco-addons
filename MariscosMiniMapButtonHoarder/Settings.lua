-- Marisco's MiniMapButtonHoarder - settings window and layout previews
local ADDON, ns = ...

local WIDTH, HEIGHT = 300, 586
local SLIDER_W = WIDTH - 48

local panel, demo
local sizeSlider, gapSlider, hoverSlider, hoverCheck, tidyCheck, timerSlider, clickCheck, timerHint
local radios = {}

local DEMO_ICONS = {
    "Interface\\Icons\\INV_Misc_Book_09",
    "Interface\\Icons\\INV_Misc_Coin_01",
    "Interface\\Icons\\Spell_Holy_MagicalSentry",
    "Interface\\Icons\\INV_Misc_Spyglass_03",
    "Interface\\Icons\\INV_Misc_Bag_08",
    "Interface\\Icons\\Spell_Nature_Polymorph",
}

local TOOLTIP_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local DIALOG_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

function ns.SettingsShown()
    return panel ~= nil and panel:IsShown()
end

---------------------------------------------------------------------------
-- Small widgets
---------------------------------------------------------------------------
local function Header(parent, text, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 20, y)
    fs:SetText(text)
    return fs
end

-- slider built by hand so it does not depend on a template the client may not have
local function Slider(parent, y, label, minV, maxV, step, fmt, get, set, ticks)
    local s = CreateFrame("Slider", nil, parent)
    s:SetPoint("TOPLEFT", 24, y - 18)
    s:SetSize(SLIDER_W, 17)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:EnableMouse(true)
    s:EnableMouseWheel(true)

    local edge = s:CreateTexture(nil, "BACKGROUND")
    edge:SetColorTexture(0.45, 0.45, 0.45, 0.9)
    edge:SetPoint("LEFT", -1, 0)
    edge:SetPoint("RIGHT", 1, 0)
    edge:SetHeight(8)
    local track = s:CreateTexture(nil, "BACKGROUND", nil, 1)
    track:SetColorTexture(0.04, 0.04, 0.04, 1)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(6)
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local thumb = s.GetThumbTexture and s:GetThumbTexture()
    if thumb then thumb:SetSize(32, 32) end

    local title = s:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 3)
    title:SetText(label)
    local value = s:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    value:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", 0, 3)

    if ticks then
        -- a label under every stop
        for i, text in ipairs(ticks) do
            local t = s:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
            local frac = (i - 1) / (#ticks - 1)
            t:SetPoint("TOP", s, "BOTTOMLEFT", 8 + frac * (SLIDER_W - 16), -1)
            t:SetText(text)
        end
    else
        local lo = s:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        lo:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -1)
        lo:SetText(fmt(minV))
        local hi = s:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        hi:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", 0, -1)
        hi:SetText(fmt(maxV))
    end

    local function snap(v)
        v = math.floor((v - minV) / step + 0.5) * step + minV
        return math.max(minV, math.min(maxV, v))
    end
    s:SetScript("OnValueChanged", function(self, v)
        v = snap(v)
        value:SetText(fmt(v))
        if not self.refreshing and v ~= self.last then
            self.last = v
            set(v)
        end
    end)
    s:SetScript("OnMouseWheel", function(self, d)
        if self.locked then return end
        self:SetValue(snap(self:GetValue() + d * step))
    end)
    function s:Refresh()
        self.refreshing = true
        local v = snap(get())
        self.last = v
        self:SetValue(v)
        value:SetText(fmt(v))
        self.refreshing = false
    end
    function s:SetLocked(locked)
        self.locked = locked
        self:EnableMouse(not locked)
        self:SetAlpha(locked and 0.35 or 1)
    end
    return s
end

---------------------------------------------------------------------------
-- Preview popup: a tiny hoarder that plays the layout in a loop
---------------------------------------------------------------------------
local DEMO_MAIN, DEMO_SIZE, DEMO_GAP = 22, 18, 5
local CYCLE, HOLD_UNTIL = 3.0, 1.9

-- minimap-button look at any size (same proportions as a 31px LibDBIcon button)
local function MiniButton(parent, iconPath, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    local R, B = ns.RING, 53 * size / 31
    local cx, cy = R.x * B, -R.y * B
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(R.back * B, R.back * B)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("CENTER", f, "TOPLEFT", cx, cy)
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(R.icon * B, R.icon * B)
    icon:SetTexture(iconPath)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("CENTER", f, "TOPLEFT", cx, cy)
    if f.CreateMaskTexture and icon.AddMaskTexture then
        local mask = f:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
    end
    local border = f:CreateTexture(nil, "OVERLAY")
    border:SetSize(B, B)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")
    return f
end

local function DemoUpdate(self, elapsed)
    self.t = self.t + elapsed
    if self.fade < 1 then
        self.fade = math.min(1, self.fade + elapsed / 0.15)
        self:SetAlpha(self.fade)
    end
    local t = self.t % CYCLE
    local n = #self.icons
    for i, f in ipairs(self.icons) do
        local e, a
        local q = (t - HOLD_UNTIL - (n - i) * ns.STAGGER) / ns.CLOSE_TIME
        if q > 0 then
            q = math.min(1, q)
            e, a = 1 - q * q, 1 - q
        else
            local p = math.max(0, math.min(1, (t - 0.15 - (i - 1) * ns.STAGGER * 1.5) / ns.OPEN_TIME))
            e, a = ns.EaseOutBack(p), math.min(1, p * 2)
        end
        f:ClearAllPoints()
        f:SetPoint("CENTER", self.stage, "CENTER", self.ox + f.tx * e, self.oy + f.ty * e)
        f:SetAlpha(a)
    end
end

local function BuildDemo()
    demo = CreateFrame("Frame", "MariscosMMBHPreview", panel, BACKDROP_TEMPLATE)
    demo:SetSize(220, 210)
    demo:SetFrameStrata("DIALOG")
    demo:SetFrameLevel(panel:GetFrameLevel() + 20)
    demo:SetClampedToScreen(true)
    if demo.SetBackdrop then
        demo:SetBackdrop(TOOLTIP_BACKDROP)
        demo:SetBackdropColor(0.04, 0.04, 0.07, 0.96)
        demo:SetBackdropBorderColor(0.65, 0.65, 0.65, 1)
    end
    demo.title = demo:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    demo.title:SetPoint("TOP", 0, -9)

    local stage = CreateFrame("Frame", nil, demo)
    stage:SetPoint("TOPLEFT", 8, -26)
    stage:SetPoint("BOTTOMRIGHT", -8, 8)
    demo.stage = stage

    demo.icons = {}
    for i, path in ipairs(DEMO_ICONS) do
        local f = MiniButton(stage, path, DEMO_SIZE)
        f:SetFrameLevel(stage:GetFrameLevel() + 2)
        f.tx, f.ty = 0, 0
        demo.icons[i] = f
    end
    -- the hoarder sits on top, so the buttons come out from behind it
    demo.hoarder = MiniButton(stage, ns.ICON, DEMO_MAIN)
    demo.hoarder:SetFrameLevel(stage:GetFrameLevel() + 10)

    demo.t, demo.fade, demo.ox, demo.oy = 0, 1, 0, 0
    demo:SetScript("OnUpdate", DemoUpdate)
    demo:Hide()
end

function ns.ShowDemo(key, row)
    if not panel then return end
    if not demo then BuildDemo() end
    local n = #demo.icons
    local start = DEMO_MAIN / 2 + DEMO_SIZE / 2 + DEMO_GAP + 2
    local pts = ns.ShapePoints(key, n, DEMO_SIZE, DEMO_GAP, start, 46, 180)
    local dir = (key == "horizontal") and 0 or math.pi / 2
    local c, s = math.cos(dir), math.sin(dir)

    -- center the whole picture (hoarder included) in the stage
    local minX, maxX, minY, maxY = -DEMO_MAIN / 2, DEMO_MAIN / 2, -DEMO_MAIN / 2, DEMO_MAIN / 2
    for i, f in ipairs(demo.icons) do
        local u, v = pts[i][1], pts[i][2]
        f.tx, f.ty = u * c - v * s, u * s + v * c
        minX = math.min(minX, f.tx - DEMO_SIZE / 2); maxX = math.max(maxX, f.tx + DEMO_SIZE / 2)
        minY = math.min(minY, f.ty - DEMO_SIZE / 2); maxY = math.max(maxY, f.ty + DEMO_SIZE / 2)
    end
    demo.ox, demo.oy = -(minX + maxX) / 2, -(minY + maxY) / 2
    demo.hoarder:ClearAllPoints()
    demo.hoarder:SetPoint("CENTER", demo.stage, "CENTER", demo.ox, demo.oy)

    demo.title:SetText(ns.LayoutLabel(key))
    demo:ClearAllPoints()
    local rowY
    if row then rowY = select(2, row:GetCenter()) end
    local top = panel:GetTop()
    if rowY and top then
        demo:SetPoint("TOPLEFT", panel, "TOPRIGHT", 2, (rowY - top) + 105)
    else
        demo:SetPoint("TOPLEFT", panel, "TOPRIGHT", 2, -230)
    end
    demo.t, demo.fade = 0, 0
    demo:SetAlpha(0)
    demo:Show()
    DemoUpdate(demo, 0)
end

function ns.HideDemo()
    if demo then demo:Hide() end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function RefreshRadios()
    for _, r in ipairs(radios) do r:SetChecked(r.key == (ns.db.layout or "arch")) end
end

local function RefreshTimer()
    local untilClick = not ns.db.autoClose
    clickCheck:SetChecked(untilClick)
    timerSlider:SetLocked(untilClick)
    timerHint:SetText(untilClick
        and "The buttons stay out until you click somewhere else."
        or "Counts while the pointer is away from the buttons.")
end

local function RefreshHover()
    hoverCheck:SetChecked(ns.db.hoverZoom)
    hoverSlider:SetLocked(not ns.db.hoverZoom)
end

function ns.RefreshSettings()
    if not panel then return end
    sizeSlider:Refresh()
    gapSlider:Refresh()
    hoverSlider:Refresh()
    RefreshHover()
    tidyCheck:SetChecked(ns.db.tidyIcons)
    timerSlider:Refresh()
    RefreshTimer()
    RefreshRadios()
end

function ns.SetLayout(key)
    ns.db.layout = key
    RefreshRadios()
    ns.Relayout()
end

local function TimerIndex()
    local d = ns.SnapTimer(ns.db.closeDelay)
    for i, t in ipairs(ns.TIMERS) do
        if t == d then return i end
    end
    return 1
end

local function BuildPanel()
    local ok, f = pcall(CreateFrame, "Frame", "MariscosMMBHSettings", UIParent, "BasicFrameTemplateWithInset")
    if not ok or not f then
        f = CreateFrame("Frame", "MariscosMMBHSettingsFrame", UIParent, BACKDROP_TEMPLATE)
        if f.SetBackdrop then f:SetBackdrop(DIALOG_BACKDROP) end
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
    end
    panel = f
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", -180, 40)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    table.insert(UISpecialFrames, f:GetName())  -- Escape closes it

    local title = f.TitleText or f.title
    if not title then
        title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -6)
    end
    title:SetText(ns.TITLE)

    local db = function() return ns.db end

    -- Buttons
    Header(f, "Buttons", -34)
    sizeSlider = Slider(f, -54, "Button size", 60, 150, 10,
        function(v) return v .. "%" end,
        function() return (db().scale or 1) * 100 end,
        function(v)
            db().scale = v / 100
            ns.ApplyScale()
            ns.Relayout()
        end)
    gapSlider = Slider(f, -106, "Spacing", 0, 30, 1,
        function(v) return tostring(v) end,
        function() return db().gap or 6 end,
        function(v)
            db().gap = v
            ns.Relayout()
        end)

    hoverCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    hoverCheck:SetSize(26, 26)
    hoverCheck:SetPoint("TOPLEFT", 20, -152)
    hoverCheck:SetHitRectInsets(0, -150, 0, 0)
    local hl = hoverCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    hl:SetPoint("LEFT", hoverCheck, "RIGHT", 2, 1)
    hl:SetText("Grow on hover")
    hoverCheck:SetScript("OnClick", function(self)
        db().hoverZoom = self:GetChecked() and true or false
        RefreshHover()
    end)
    hoverSlider = Slider(f, -184, "Hover size", 110, 150, 5,
        function(v) return v .. "%" end,
        function() return (db().hoverScale or 1.25) * 100 end,
        function(v) db().hoverScale = v / 100 end)

    tidyCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    tidyCheck:SetSize(26, 26)
    tidyCheck:SetPoint("TOPLEFT", 20, -234)
    tidyCheck:SetHitRectInsets(0, -170, 0, 0)
    local tl = tidyCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    tl:SetPoint("LEFT", tidyCheck, "RIGHT", 2, 1)
    tl:SetText("Center and fill icons")
    tidyCheck:SetScript("OnClick", function(self)
        db().tidyIcons = self:GetChecked() and true or false
        ns.ApplySkins()
    end)

    -- Folding back
    Header(f, "Folding back", -276)
    local ticks = {}
    for i, t in ipairs(ns.TIMERS) do ticks[i] = t .. " s" end
    timerSlider = Slider(f, -296, "Fold back after", 1, #ns.TIMERS, 1,
        function(i) return ns.TIMERS[i] .. " seconds" end,
        TimerIndex,
        function(i) db().closeDelay = ns.TIMERS[i] end,
        ticks)

    clickCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    clickCheck:SetSize(26, 26)
    clickCheck:SetPoint("TOPLEFT", 20, -342)
    clickCheck:SetHitRectInsets(0, -150, 0, 0)
    local cl = clickCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cl:SetPoint("LEFT", clickCheck, "RIGHT", 2, 1)
    cl:SetText("Until clicked out")
    clickCheck:SetScript("OnClick", function(self)
        db().autoClose = not self:GetChecked()
        RefreshTimer()
    end)
    timerHint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    timerHint:SetPoint("TOPLEFT", 26, -372)
    timerHint:SetWidth(WIDTH - 50)
    timerHint:SetJustifyH("LEFT")

    -- Layout
    local lh = Header(f, "Layout", -396)
    local lhint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    lhint:SetPoint("LEFT", lh, "RIGHT", 8, 0)
    lhint:SetText("(hover one to see it)")
    for i, l in ipairs(ns.LAYOUTS) do
        local r = CreateFrame("CheckButton", nil, f, "UIRadioButtonTemplate")
        r:SetSize(16, 16)
        r:SetPoint("TOPLEFT", 26, -418 - (i - 1) * 22)
        r:SetHitRectInsets(-4, -(WIDTH - 70), -3, -3)
        local t = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        t:SetPoint("LEFT", r, "RIGHT", 6, 0)
        t:SetText(l.label)
        local d = r:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        d:SetPoint("LEFT", r, "RIGHT", 82, 0)
        d:SetText(l.desc)
        r.key = l.key
        r:SetScript("OnClick", function(self) ns.SetLayout(self.key) end)
        r:SetScript("OnEnter", function(self) ns.ShowDemo(self.key, self) end)
        r:SetScript("OnLeave", ns.HideDemo)
        radios[i] = r
    end

    -- bottom buttons
    local scan = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    scan:SetSize(126, 22)
    scan:SetPoint("BOTTOMLEFT", 16, 14)
    scan:SetText("Scan for buttons")
    scan:SetScript("OnClick", function() ns.Scan(true) end)
    local defaults = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    defaults:SetSize(126, 22)
    defaults:SetPoint("BOTTOMRIGHT", -16, 14)
    defaults:SetText("Defaults")
    defaults:SetScript("OnClick", function() ns.ResetSettings() end)

    f:SetScript("OnShow", function()
        ns.RefreshSettings()
        -- show the real buttons too, so every change is visible right away
        if ns.db.enabled and not ns.IsOpen() then ns.Open() end
    end)
    f:SetScript("OnHide", function() ns.HideDemo() end)
    f:Hide()
end

function ns.ToggleSettings()
    if not panel then BuildPanel() end
    if panel:IsShown() then panel:Hide() else panel:Show() end
end
