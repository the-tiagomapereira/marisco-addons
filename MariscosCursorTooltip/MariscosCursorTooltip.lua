-- Marisco's Cursor Tooltip
-- Moves GameTooltip to the mouse pointer instead of its fixed default spot
-- (bottom-right corner, or next to the hovered button).
-- The position relative to the pointer is chosen in a drag-and-drop setup screen
-- (/mct or the minimap button).

local ADDON = ...
local PREFIX = "|cff69ccf0Cursor Tooltip:|r "

local defaults = {
    enabled = true,
    follow  = true,          -- true: follows the pointer; false: placed once at the pointer
    anchor  = "BOTTOMLEFT",  -- which point of the tooltip sits at pointer + offset
    x       = 20,            -- offset from the pointer (UI units, signed)
    y       = 10,
    radius  = 150,           -- size of the circle in the setup screen
}

local db
local needsPlace = false
local placing = false -- guard: our own SetPoint must not re-trigger the SetPoint hook

local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg) end
local function Round(n) return math.floor(n + 0.5) end

-- "BOTTOMLEFT" -> "BOTTOM", "LEFT";  "TOP" -> "TOP", "";  "CENTER" -> "", ""
local function SplitPoint(p)
    local v = p:match("^TOP") or p:match("^BOTTOM") or ""
    local h = p:match("LEFT$") or p:match("RIGHT$") or ""
    return v, h
end
local function JoinPoint(v, h)
    local p = v .. h
    return p == "" and "CENTER" or p
end

------------------------------------------------------------------------
-- Placing the real tooltip
------------------------------------------------------------------------
local function Place(tt)
    if not db or not db.enabled or placing then return end
    placing = true

    local s = tt:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / s, cy / s

    -- offsets are saved in UIParent units; convert to the tooltip's own scale
    local k = UIParent:GetEffectiveScale() / s
    local sw, sh = UIParent:GetWidth() * k, UIParent:GetHeight() * k
    local w, h = tt:GetWidth(), tt:GetHeight()
    local ox, oy = db.x * k, db.y * k
    local v, hz = SplitPoint(db.anchor)
    local x, y = cx + ox, cy + oy

    -- Mirror to the other side of the pointer when it would run off screen.
    if hz == "LEFT" and x + w > sw then hz, x = "RIGHT", cx - ox
    elseif hz == "RIGHT" and x - w < 0 then hz, x = "LEFT", cx - ox end
    if v == "BOTTOM" and y + h > sh then v, y = "TOP", cy - oy
    elseif v == "TOP" and y - h < 0 then v, y = "BOTTOM", cy - oy end

    tt:ClearAllPoints()
    tt:SetPoint(JoinPoint(v, hz), UIParent, "BOTTOMLEFT", x, y) -- offsets are in the tooltip's own scale
    placing = false
end

local function Hook(tt)
    tt:SetClampedToScreen(true)
    -- Whenever the game (or another addon) anchors the tooltip somewhere, replace that
    -- anchor at once, so it never sits on two anchors (stretching to the screen edge).
    hooksecurefunc(tt, "SetPoint", function(self) Place(self) end)
    tt:HookScript("OnShow", function(self)
        Place(self)
        needsPlace = true -- place again next frame, once the content has sized the tooltip
    end)
    tt:HookScript("OnUpdate", function(self)
        if db and db.enabled and (db.follow or needsPlace) then
            Place(self)
            needsPlace = false
        end
    end)
    hooksecurefunc(tt, "SetOwner", function(self)
        Place(self)
        needsPlace = true
    end)
end

------------------------------------------------------------------------
-- Shared helpers
------------------------------------------------------------------------
local ADDON_TITLE = "Marisco's Cursor Tooltip"
local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local VERSION = (GetMeta and GetMeta(ADDON, "Version")) or "1.0"
local WINDOW_TITLE = ("%s - |cffffffffv%s|r"):format(ADDON_TITLE, VERSION)
local ICON = "Interface\\Icons\\INV_Misc_Spyglass_03"
local ROUND_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function TryFrame(kind, name, parent, template)
    local ok, frame = pcall(CreateFrame, kind, name, parent, template)
    if ok and frame then return frame end
end

local function CursorUI()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s, y / s
end

local function Dot(parent, size, r, g, b, a, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetColorTexture(r, g, b, a)
    t:SetSize(size, size)
    return t
end

local function CopyTable(t)
    local c = {}
    for k, v in pairs(t) do c[k] = type(v) == "table" and CopyTable(v) or v end
    return c
end

------------------------------------------------------------------------
-- Cursor ring + fading trail (beta)
------------------------------------------------------------------------
local CURSOR_DEFAULTS = {
    ring      = false,
    r = 1, g = 0.82, b = 0,  -- gold
    alpha     = 0.8,
    radius    = 18,
    thickness = 2,
    pulse     = false,       -- ripple of the ring on mouse clicks
    trail     = false,
    trailFade = 0.4,         -- seconds until a trail dot is gone
    trailSize = 8,
}
local TRAIL_MAX = 250

local setup -- the settings screen (built later); declared here so the ring preview can update
local driver, ringFrame, trailFrame, pulseFrame
local pulseDots, pulseStart, wasDown = {}, nil, false
local PULSE_TIME, PULSE_SCALE = 0.35, 1.8 -- seconds, how far the ripple grows
local ringDots, trail = {}, {}
local trailHead, lastX, lastY = 0, nil, nil

-- Draw a ring from small dots on any frame (real ring, pulse, previews, color swatch).
local function DrawRing(frame, dots, radius, thickness, r, g, b, a, round)
    local spacing = math.max(1, thickness * 0.7)
    local n = math.max(32, math.min(240, math.floor(2 * math.pi * radius / spacing)))
    for i = 1, math.max(n, #dots) do
        local t = dots[i]
        if i <= n then
            if not t then
                t = frame:CreateTexture(nil, "OVERLAY")
                if not round or t:SetTexture(ROUND_TEX) == false then t:SetColorTexture(1, 1, 1, 1) end
                dots[i] = t
            end
            local ang = i / n * 2 * math.pi
            t:ClearAllPoints()
            t:SetPoint("CENTER", frame, "CENTER", math.cos(ang) * radius, math.sin(ang) * radius)
            t:SetSize(thickness, thickness)
            t:SetVertexColor(r, g, b, a)
            t:Show()
        elseif t then
            t:Hide()
        end
    end
end

-- the cursor ring with the current settings
local function LayoutRing(frame, dots)
    local c = db.cursor
    DrawRing(frame, dots, c.radius, c.thickness, c.r, c.g, c.b, c.alpha)
end

local function ClearTrail()
    for _, d in ipairs(trail) do d.born = nil; d.t:Hide() end
    lastX, lastY = nil, nil
end

local function SpawnTrailDot(x, y, now)
    trailHead = trailHead % TRAIL_MAX + 1
    local d = trail[trailHead]
    if not d then
        local t = trailFrame:CreateTexture(nil, "ARTWORK")
        if t:SetTexture(ROUND_TEX) == false then t:SetColorTexture(1, 1, 1, 1) end
        d = { t = t }
        trail[trailHead] = d
    end
    d.born = now
    d.t:ClearAllPoints()
    d.t:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    d.t:Show()
end

local function UpdateTrail(x, y, hidden)
    local c, now = db.cursor, GetTime()
    if hidden then
        lastX, lastY = nil, nil
    elseif lastX then
        local dx, dy = x - lastX, y - lastY
        local dist = math.sqrt(dx * dx + dy * dy)
        local spacing = math.max(1.5, c.trailSize * 0.35)
        if dist > 400 then          -- jumped (e.g. after turning the camera): no line across
            lastX, lastY = x, y
        elseif dist >= spacing then
            local steps = math.min(30, math.floor(dist / spacing))
            for i = 1, steps do SpawnTrailDot(lastX + dx * i / steps, lastY + dy * i / steps, now) end
            lastX, lastY = x, y
        end
    else
        lastX, lastY = x, y
    end
    for _, d in ipairs(trail) do
        if d.born then
            local p = (now - d.born) / c.trailFade
            if p >= 1 then
                d.born = nil
                d.t:Hide()
            else
                local s = c.trailSize * (1 - p * 0.6)
                d.t:SetSize(s, s)
                d.t:SetVertexColor(c.r, c.g, c.b, c.alpha * (1 - p))
            end
        end
    end
end

-- A copy of the ring that grows outward and fades each time a mouse button goes down.
local function UpdatePulse(x, y, hidden)
    local down = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
    if down and not wasDown and not hidden then pulseStart = GetTime() end
    wasDown = down
    if not pulseStart then return end
    local p = (GetTime() - pulseStart) / PULSE_TIME
    if p >= 1 or hidden then
        pulseStart = nil
        pulseFrame:Hide()
        return
    end
    local e = 1 - (1 - p) * (1 - p)          -- ease out: fast start, soft finish
    local s = 1 + (PULSE_SCALE - 1) * e
    pulseFrame:SetScale(s)
    pulseFrame:ClearAllPoints()
    pulseFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s) -- offsets are in the scaled frame's units
    pulseFrame:SetAlpha(0.7 * (1 - p))
    pulseFrame:Show()
end

local function ApplyCursor()
    local c = db.cursor
    if not driver then
        ringFrame = CreateFrame("Frame", nil, UIParent)
        ringFrame:SetFrameStrata("TOOLTIP")
        ringFrame:SetFrameLevel(120)
        ringFrame:SetSize(1, 1)
        trailFrame = CreateFrame("Frame", nil, UIParent)
        trailFrame:SetFrameStrata("TOOLTIP")
        trailFrame:SetFrameLevel(110)
        trailFrame:SetAllPoints(UIParent)
        pulseFrame = CreateFrame("Frame", nil, UIParent)
        pulseFrame:SetFrameStrata("TOOLTIP")
        pulseFrame:SetFrameLevel(115)
        pulseFrame:SetSize(1, 1)
        pulseFrame:Hide()
        driver = CreateFrame("Frame")
        driver:SetScript("OnUpdate", function()
            local x, y = CursorUI()
            -- the pointer is hidden while turning the camera with the mouse
            local hidden = IsMouselooking and IsMouselooking()
            if db.cursor.ring then
                ringFrame:SetShown(not hidden)
                ringFrame:ClearAllPoints()
                ringFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
            end
            if db.cursor.trail then UpdateTrail(x, y, hidden) end
            if db.cursor.pulse then UpdatePulse(x, y, hidden) end
        end)
    end
    if c.ring then LayoutRing(ringFrame, ringDots) end
    ringFrame:SetShown(c.ring)
    if not c.trail then ClearTrail() end
    trailFrame:SetShown(c.trail)
    if c.pulse then
        LayoutRing(pulseFrame, pulseDots)
        wasDown = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
    else
        pulseStart = nil
        pulseFrame:Hide()
    end
    driver:SetShown(c.ring or c.trail or c.pulse)

    if setup and setup.swatch then setup.swatch.Refresh() end

    -- ring preview around the fake pointer in the settings screen
    if setup and setup.previewRing then
        if c.ring then LayoutRing(setup.previewRing, setup.previewDots) end
        setup.previewRing:SetShown(c.ring)
    end
end

------------------------------------------------------------------------
-- UI widgets (styled after the game's own windows)
------------------------------------------------------------------------
-- A window built from the game's ButtonFrameTemplate, so it uses the client's current art.
-- Falls back to a plain dialog frame if the template doesn't exist.
local function StyledWindow(name, parent, w, h, onClose)
    local p = TryFrame("Frame", name, parent, "ButtonFrameTemplate")
    local styled = p ~= nil
    if not styled then
        p = CreateFrame("Frame", name, parent, BackdropTemplateMixin and "BackdropTemplate")
        p:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end
    p:SetSize(w, h)
    p:SetClampedToScreen(true)
    p:EnableMouse(true)

    local inset
    if styled then
        if p.SetTitle then p:SetTitle(WINDOW_TITLE) end
        local t = (p.TitleContainer and p.TitleContainer.TitleText) or p.TitleText or _G[name .. "TitleText"]
        if t then
            -- center the title across the whole title bar (not just the part right of the portrait)
            t:SetText(WINDOW_TITLE)
            local font, size, flags = t:GetFont()
            if font and size then t:SetFont(font, size - 1, flags) end
            t:ClearAllPoints()
            t:SetPoint("TOP", p, "TOP", 0, -5) -- until the window is shown and measured
            t:SetWidth(w - 80)
            t:SetJustifyH("CENTER")
            if t.SetJustifyV then t:SetJustifyV("MIDDLE") end
        end
        local portrait = (p.PortraitContainer and p.PortraitContainer.portrait) or p.portrait or _G[name .. "Portrait"]
        if portrait then
            if p.SetPortraitToAsset then p:SetPortraitToAsset(ICON)
            elseif SetPortraitToTexture then SetPortraitToTexture(portrait, ICON)
            else portrait:SetTexture(ICON) end
        end
        local close = p.CloseButton or _G[name .. "CloseButton"]
        if close then close:SetScript("OnClick", onClose) end
        inset = p.Inset or _G[name .. "Inset"]

        -- Center the title in the title bar: horizontally between the portrait and the X
        -- button, vertically on the X button's middle (it sits in the middle of the bar).
        if t then
            local function CenterTitle()
                local pl, pt, pr = p:GetLeft(), p:GetTop(), p:GetRight()
                if not (pl and pt and pr) then return end
                local L = portrait and portrait:GetRight() or (pl + 60)
                local R = close and close:GetLeft() or (pr - 24)
                local cy = close and select(2, close:GetCenter())
                t:ClearAllPoints()
                t:SetPoint("CENTER", p, "TOPLEFT", (L + R) / 2 - pl, cy and (cy - pt) or -12)
                t:SetWidth(math.max(50, R - L - 6))
            end
            p:HookScript("OnShow", function()
                CenterTitle()
                if C_Timer and C_Timer.After then C_Timer.After(0, CenterTitle) end
            end)
        end
    else
        local header = p:CreateTexture(nil, "OVERLAY")
        header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
        header:SetSize(340, 64)
        header:SetPoint("TOP", 0, 12)
        local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", header, "TOP", 0, -14)
        title:SetText(WINDOW_TITLE)
    end
    if not inset then inset = TryFrame("Frame", nil, p, "InsetFrameTemplate") end
    if inset then
        inset:ClearAllPoints()
        inset:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -28)
        inset:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -12, 46)
    end
    return p
end

local function OpenColorPicker(r, g, b, onChange)
    local function apply()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        onChange(nr, ng, nb)
    end
    local function cancel() onChange(r, g, b) end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = apply, cancelFunc = cancel,
        })
    else
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.func = apply
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.cancelFunc = cancel
        ColorPickerFrame.previousValues = { r, g, b }
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        if ShowUIPanel then ShowUIPanel(ColorPickerFrame) else ColorPickerFrame:Show() end
    end
    -- above the settings screen
    ColorPickerFrame:SetFrameStrata("TOOLTIP")
end

local function Header(parent, text, y)
    local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetPoint("TOPLEFT", 24, y)
    h:SetText(text)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetHeight(1)
    line:SetPoint("LEFT", h, "RIGHT", 8, 0)
    line:SetWidth(math.max(10, parent:GetWidth() - 48 - 8 - h:GetStringWidth()))
    return h
end

local function MakeCheck(parent, label, y, getter, setter)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    c:SetPoint("TOPLEFT", 26, y)
    local t = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("LEFT", c, "RIGHT", 4, 1)
    t:SetText(label)
    c:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
    c.Refresh = function() c:SetChecked(getter()) end
    return c
end

local MARGIN = 32 -- side margin inside the panel (same on the left and the right)

-- fmt = nil: no value column, the slider runs all the way to the right margin
local function MakeSlider(parent, label, minV, maxV, step, y, getter, setter, fmt)
    local s = CreateFrame("Slider", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    -- label top-left, value top-right, slider across the full width underneath
    local width = parent:GetWidth() - 2 * MARGIN
    s:SetSize(width, 17)
    s:SetPoint("TOPLEFT", MARGIN, y)
    s:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:EnableMouseWheel(true)
    local t = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 2, 3)
    t:SetText(label or "")
    s.labelText = t
    local v = s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    v:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", -2, 3)
    v:SetJustifyH("RIGHT")
    s.valueText = v
    fmt = fmt or function() return "" end
    s:SetScript("OnValueChanged", function(self, val)
        val = Round(val / step) * step
        v:SetText(fmt(val))
        if not self.loading then setter(val) end
    end)
    s:SetScript("OnMouseWheel", function(self, d)
        self:SetValue(math.max(minV, math.min(maxV, self:GetValue() + d * step)))
    end)
    s.Refresh = function()
        s.loading = true
        s:SetValue(getter())
        v:SetText(fmt(getter()))
        s.loading = false
    end
    return s
end

local function MakeSwatch(parent, y, onPick)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", MARGIN, y)
    label:SetText("Color")
    local sw = CreateFrame("Button", nil, parent)
    sw:SetSize(32, 32)
    sw:SetPoint("LEFT", label, "RIGHT", 12, 0)
    -- dark disc behind the ring so any color reads well
    local back = sw:CreateTexture(nil, "BACKGROUND")
    back:SetSize(30, 30)
    back:SetPoint("CENTER")
    if back:SetTexture(ROUND_TEX) == false then back:SetColorTexture(0, 0, 0, 1) end
    back:SetVertexColor(0, 0, 0, 0.55)
    local hl = sw:CreateTexture(nil, "HIGHLIGHT")
    hl:SetSize(30, 30)
    hl:SetPoint("CENTER")
    if hl:SetTexture(ROUND_TEX) == false then hl:SetColorTexture(1, 1, 1, 1) end
    hl:SetVertexColor(1, 1, 1, 0.15)
    local dots = {}
    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", sw, "RIGHT", 8, 0)
    hint:SetText("click to choose (also used by the trail)")
    -- preview of the ring: chosen color and opacity, drawn thicker so it shows well
    sw.Refresh = function()
        local c = db.cursor
        DrawRing(sw, dots, 11, 4, c.r, c.g, c.b, c.alpha, true)
    end
    sw:SetScript("OnClick", onPick)
    return sw
end

------------------------------------------------------------------------
-- Settings screen: circle + draggable preview on the left, one panel with
-- every option on the right (tooltip position, cursor ring, trail).
------------------------------------------------------------------------
local BOX_W, BOX_H = 180, 64
local CIRCLE_DOTS, LINE_DOTS = 96, 20
local R_MIN, R_MAX = 100, 200
local PANEL_W, PANEL_H = 340, 716
local PANEL_GAP = 40 -- space between the largest circle and the panel
local SCREEN_NAME = "MariscosCursorTooltipSettings"
local PANEL_NAME = SCREEN_NAME .. "Panel"

-- the fake pointer sits in the middle of the screen
local function Center()
    return UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
end

-- Box center -> which point of the box faces the pointer, and that point's offset
local function AnchorFromBox(bx, by)
    local cx, cy = Center()
    local dx, dy = bx - cx, by - cy
    local h = (math.abs(dx) < BOX_W / 2) and "" or (dx > 0 and "LEFT" or "RIGHT")
    local v = (math.abs(dy) < BOX_H / 2) and "" or (dy > 0 and "BOTTOM" or "TOP")
    local px = (h == "LEFT" and bx - BOX_W / 2) or (h == "RIGHT" and bx + BOX_W / 2) or bx
    local py = (v == "BOTTOM" and by - BOX_H / 2) or (v == "TOP" and by + BOX_H / 2) or by
    return v, h, px - cx, py - cy
end

-- Anchor point + offset -> box center
local function BoxFromAnchor(v, h, ox, oy)
    local cx, cy = Center()
    local bx = cx + ox + ((h == "LEFT" and BOX_W / 2) or (h == "RIGHT" and -BOX_W / 2) or 0)
    local by = cy + oy + ((v == "BOTTOM" and BOX_H / 2) or (v == "TOP" and -BOX_H / 2) or 0)
    return bx, by
end

-- Keep the anchor point inside the circle
local function Clamp(ox, oy, r)
    local d = math.sqrt(ox * ox + oy * oy)
    if d > r then return ox * r / d, oy * r / d end
    return ox, oy
end

local function Redraw()
    local f = setup
    local cx, cy = Center()

    f.pointer:ClearAllPoints()
    f.pointer:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)

    f.box:ClearAllPoints()
    f.box:SetPoint("CENTER", UIParent, "BOTTOMLEFT", f.bx, f.by)

    for i, t in ipairs(f.circle) do
        local a = (i / CIRCLE_DOTS) * 2 * math.pi
        t:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx + math.cos(a) * f.radius, cy + math.sin(a) * f.radius)
    end
    for i, t in ipairs(f.line) do
        local p = i / (LINE_DOTS + 1)
        t:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx + f.ox * p, cy + f.oy * p)
    end
    f.anchorDot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx + f.ox, cy + f.oy)

    f.warn:SetText((f.v == "" and f.h == "") and "Covers the pointer!" or "")
    if f.radiusSlider then f.radiusSlider.Refresh() end
end

local function SetFromOffset(v, h, ox, oy)
    local f = setup
    ox, oy = Clamp(ox, oy, f.radius)
    f.bx, f.by = BoxFromAnchor(v, h, ox, oy)
    f.v, f.h, f.ox, f.oy = AnchorFromBox(f.bx, f.by)
end

local function SetFromBox(bx, by)
    local v, h, ox, oy = AnchorFromBox(bx, by)
    SetFromOffset(v, h, ox, oy)
end

-- Panel opens right beside the circle, or where it was last dragged to
local function PlacePanel()
    local p = setup.panel
    p:ClearAllPoints()
    if db.panelPos then
        p:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.panelPos.x, db.panelPos.y)
    else
        local cx, cy = Center()
        p:SetPoint("LEFT", UIParent, "BOTTOMLEFT", cx + R_MAX + PANEL_GAP, cy)
    end
end

local function BuildSetup()
    local f = CreateFrame("Frame", SCREEN_NAME, UIParent)
    f:SetAllPoints(UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:Hide()
    tinsert(UISpecialFrames, SCREEN_NAME) -- ESC closes without saving

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetColorTexture(0, 0, 0, 0.45)

    ---------------- left side: pointer, circle, preview box ----------------
    f.pointer = CreateFrame("Frame", nil, f)
    f.pointer:SetSize(1, 1)
    local ptr = f.pointer:CreateTexture(nil, "OVERLAY")
    ptr:SetTexture("Interface\\Cursor\\Point")
    ptr:SetSize(32, 32)
    ptr:SetPoint("TOPLEFT", f.pointer, "CENTER", 0, 0)
    local center = Dot(f.pointer, 4, 1, 1, 1, 1, "OVERLAY")
    center:SetPoint("CENTER")

    -- preview of the cursor ring around the fake pointer
    f.previewRing = CreateFrame("Frame", nil, f)
    f.previewRing:SetSize(1, 1)
    f.previewRing:SetPoint("CENTER", f.pointer, "CENTER")
    f.previewRing:SetFrameLevel(f:GetFrameLevel() + 3)
    f.previewDots = {}

    f.circle, f.line = {}, {}
    for i = 1, CIRCLE_DOTS do f.circle[i] = Dot(f, 3, 0.41, 0.8, 0.94, 0.9) end
    for i = 1, LINE_DOTS do f.line[i] = Dot(f, 2, 1, 0.82, 0, 0.8) end

    -- preview box uses the game's own tooltip frame style when available
    local box = TryFrame("Frame", nil, f, "TooltipBackdropTemplate")
    if not box then
        box = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate")
        box:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        box:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
    end
    box:SetSize(BOX_W, BOX_H)
    box:SetFrameLevel(f:GetFrameLevel() + 30)
    box:EnableMouse(true)
    local bt = box:CreateFontString(nil, "OVERLAY", "GameTooltipHeaderText")
    bt:SetPoint("TOPLEFT", 10, -10)
    bt:SetText("Tooltip preview")
    local bb = box:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    bb:SetPoint("TOPLEFT", bt, "BOTTOMLEFT", 0, -6)
    bb:SetText("Drag me around the pointer")
    f.box = box
    f.anchorDot = Dot(box, 8, 1, 0.82, 0, 1, "OVERLAY")

    box:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        local mx, my = CursorUI()
        f.dragging, f.grabX, f.grabY = true, mx - f.bx, my - f.by
    end)
    box:SetScript("OnMouseUp", function() f.dragging = false end)
    f:SetScript("OnUpdate", function()
        if not f.dragging then return end
        if not IsMouseButtonDown("LeftButton") then f.dragging = false return end
        local mx, my = CursorUI()
        SetFromBox(mx - f.grabX, my - f.grabY)
        Redraw()
    end)
    f:SetScript("OnMouseWheel", function(_, delta)
        f.radius = math.max(R_MIN, math.min(R_MAX, f.radius + delta * 10))
        SetFromOffset(f.v, f.h, f.ox, f.oy)
        Redraw()
    end)

    ---------------- right side: the settings panel ----------------
    local p = StyledWindow(PANEL_NAME, f, PANEL_W, PANEL_H, function() f:Hide() end)
    p:SetFrameLevel(f:GetFrameLevel() + 10)
    -- drag the panel by its title bar or any empty spot; the spot is remembered
    p:SetMovable(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving)
    p:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local left, top = self:GetLeft(), self:GetTop()
        if left and top then db.panelPos = { x = Round(left), y = Round(top) } end
    end)
    p:EnableMouseWheel(true)                     -- wheel over the panel doesn't resize the circle
    p:SetScript("OnMouseWheel", function() end)
    f.panel = p

    local c = function() return db.cursor end
    local widgets = {}
    local function add(w) widgets[#widgets + 1] = w; return w end
    local function Refresh() for _, w in ipairs(widgets) do w.Refresh() end end
    f.Refresh = Refresh

    -- Tooltip position
    Header(p, "Tooltip position", -62)
    local help = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", 28, -82)
    help:SetWidth(PANEL_W - 56)
    help:SetJustifyH("LEFT")
    help:SetText("Drag the preview box around the pointer. Use the slider or scroll the mouse wheel outside this panel to resize the circle.")
    f.radiusSlider = MakeSlider(p, ("Circle size |cff888888(%d default)|r"):format(defaults.radius),
        R_MIN, R_MAX, 5, -146,
        function() return f.radius end,
        function(v)
            f.radius = v
            SetFromOffset(f.v, f.h, f.ox, f.oy)
            Redraw()
        end,
        function(v) return ("%d"):format(v) end)
    f.warn = p:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    f.warn:SetPoint("RIGHT", f.radiusSlider.valueText, "LEFT", -10, 0)
    add(MakeCheck(p, "Anchor the tooltip to the cursor", -174,
        function() return db.enabled end, function(v) db.enabled = v end))
    add(MakeCheck(p, "Follow the cursor while it moves", -198,
        function() return db.follow end, function(v) db.follow = v end))

    -- Cursor ring
    Header(p, "Cursor ring", -238)
    add(MakeCheck(p, "Show a ring around the cursor", -264,
        function() return c().ring end, function(v) c().ring = v; ApplyCursor() end))
    add(MakeCheck(p, "Pulse the ring when you click", -288,
        function() return c().pulse end, function(v) c().pulse = v; ApplyCursor() end))
    f.swatch = add(MakeSwatch(p, -326, function()
        OpenColorPicker(c().r, c().g, c().b, function(r, g, b)
            c().r, c().g, c().b = r, g, b
            ApplyCursor()
        end)
    end))
    add(MakeSlider(p, "Opacity", 0.1, 1, 0.05, -378,
        function() return c().alpha end, function(v) c().alpha = v; ApplyCursor() end,
        function(v) return ("%d%%"):format(Round(v * 100)) end))
    add(MakeSlider(p, "Radius", 6, 60, 1, -424,
        function() return c().radius end, function(v) c().radius = v; ApplyCursor() end,
        function(v) return ("%d"):format(v) end))
    add(MakeSlider(p, "Thickness", 1, 6, 1, -470,
        function() return c().thickness end, function(v) c().thickness = v; ApplyCursor() end,
        function(v) return ("%d"):format(v) end))

    -- Trail (beta)
    Header(p, "Cursor trail |cff888888(beta)|r", -512)
    add(MakeCheck(p, "Show a fading trail behind the cursor", -538,
        function() return c().trail end, function(v) c().trail = v; ApplyCursor() end))
    add(MakeSlider(p, "Fade time", 0.1, 1.5, 0.05, -588,
        function() return c().trailFade end, function(v) c().trailFade = v end,
        function(v) return ("%.2f s"):format(v) end))
    add(MakeSlider(p, "Size", 2, 16, 1, -634,
        function() return c().trailSize end, function(v) c().trailSize = v end,
        function(v) return ("%d"):format(v) end))

    -- Save / Default / Cancel
    local function Button(text, x, onClick)
        local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        b:SetSize(96, 22)
        b:SetText(text)
        b:SetPoint("BOTTOM", p, "BOTTOM", x, 14)
        b:SetScript("OnClick", onClick)
    end
    Button("Save", -104, function()
        db.anchor = JoinPoint(f.v, f.h)
        db.x, db.y = Round(f.ox), Round(f.oy)
        db.radius = f.radius
        f.saved = true
        f:Hide()
        Print("settings saved.")
    end)
    Button("Default", 0, function()
        f.radius = defaults.radius
        local v, h = SplitPoint(defaults.anchor)
        SetFromOffset(v, h, defaults.x, defaults.y)
        for k, v2 in pairs(CURSOR_DEFAULTS) do
            if k ~= "ring" and k ~= "trail" and k ~= "pulse" then db.cursor[k] = v2 end
        end
        ApplyCursor()
        Refresh()
        Redraw()
        db.panelPos = nil
        PlacePanel()
        Print("defaults loaded - press Save to keep them.")
    end)
    Button("Cancel", 104, function() f:Hide() end)

    -- Closing without Save (Cancel, X or ESC) puts every setting back.
    f:SetScript("OnHide", function()
        f.dragging = false
        if not f.saved and f.snapshot then
            for k, v in pairs(f.snapshot) do db[k] = v end
            ApplyCursor()
        end
        f.snapshot = nil
    end)

    return f
end

local function OpenSetup()
    if not db then return end
    if setup and setup:IsShown() then setup:Hide() return end
    setup = setup or BuildSetup()
    setup.saved = false
    setup.snapshot = {
        enabled = db.enabled, follow = db.follow,
        cursor = CopyTable(db.cursor),
    }
    setup.radius = math.max(R_MIN, math.min(R_MAX, db.radius or defaults.radius))
    local v, h = SplitPoint(db.anchor)
    SetFromOffset(v, h, db.x, db.y)
    Redraw()
    PlacePanel()
    setup.Refresh()
    ApplyCursor()
    GameTooltip:Hide()
    setup:Show()
end

------------------------------------------------------------------------
-- Minimap button
------------------------------------------------------------------------
local mmButton

local function UpdateMinimapPos()
    local a = math.rad(db.minimap.angle)
    local r = Minimap:GetWidth() / 2 + 5
    mmButton:ClearAllPoints()
    mmButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function Status()
    Print(("%s, %s, position %s %.0f %.0f"):format(
        db.enabled and "|cff00ff00on|r" or "|cffff0000off|r",
        db.follow and "follows the pointer" or "placed once at the pointer",
        db.anchor, db.x, db.y))
end

local function ToggleCursor(which)
    db.cursor[which] = not db.cursor[which]
    ApplyCursor()
    if setup and setup:IsShown() then setup.Refresh() end
    Print(("cursor %s %s."):format(which, db.cursor[which] and "|cff00ff00on|r" or "|cffff0000off|r"))
end

local function BuildMinimapButton()
    local b = CreateFrame("Button", "MariscosCursorTooltipMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ToggleCursor("ring")
        else
            OpenSetup()
        end
    end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            db.minimap.angle = math.deg(math.atan2(py / s - my, px / s - mx))
            UpdateMinimapPos()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(WINDOW_TITLE)
        GameTooltip:AddLine("Left-click: settings", 1, 1, 1)
        GameTooltip:AddLine("Right-click: cursor ring on/off", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    mmButton = b
    UpdateMinimapPos()
    if db.minimap.hide then b:Hide() end
end

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
local HELP = "/mct (opens the settings) | ring | pulse | trail | reset | on | off | toggle | follow | stick | "
    .. "offset <x> <y> | minimap | status"

local function Slash(msg)
    local cmd, a, b = strsplit(" ", strtrim(msg or ""):lower())
    if cmd == "" or cmd == "setup" or cmd == "config" or cmd == "options" or cmd == "opt" then
        OpenSetup()
        return
    elseif cmd == "ring" or cmd == "trail" or cmd == "pulse" then
        ToggleCursor(cmd)
        return
    elseif cmd == "reset" then
        db.anchor, db.x, db.y, db.radius = defaults.anchor, defaults.x, defaults.y, defaults.radius
        Print("position reset to default (top right of the pointer).")
    elseif cmd == "on" then
        db.enabled = true
    elseif cmd == "off" then
        db.enabled = false
    elseif cmd == "toggle" then
        db.enabled = not db.enabled
    elseif cmd == "follow" then
        db.follow = true
    elseif cmd == "stick" then
        db.follow = false
    elseif cmd == "offset" and tonumber(a) and tonumber(b) then
        db.x, db.y = tonumber(a), tonumber(b)
    elseif cmd == "minimap" then
        db.minimap.hide = not db.minimap.hide
        if mmButton then mmButton:SetShown(not db.minimap.hide) end
        Print(db.minimap.hide and "minimap button hidden (/mct minimap to show it)." or "minimap button shown.")
        return
    elseif cmd ~= "status" then
        Print(HELP)
        return
    end
    Status()
end

SLASH_MARISCOSCURSORTOOLTIP1 = "/mct"
SLASH_MARISCOSCURSORTOOLTIP2 = "/ctt"
SlashCmdList.MARISCOSCURSORTOOLTIP = Slash

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON then return end
    MariscosCursorTooltipDB = MariscosCursorTooltipDB or {}
    db = MariscosCursorTooltipDB
    for k, v in pairs(defaults) do
        if db[k] == nil then db[k] = v end
    end
    db.minimap = db.minimap or {}
    if db.minimap.angle == nil then db.minimap.angle = 225 end
    db.cursor = db.cursor or {}
    for k, v in pairs(CURSOR_DEFAULTS) do
        if db.cursor[k] == nil then db.cursor[k] = v end
    end
    Hook(GameTooltip)
    BuildMinimapButton()
    ApplyCursor()
    self:UnregisterEvent("ADDON_LOADED")
end)
