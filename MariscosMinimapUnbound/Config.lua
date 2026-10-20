-- Settings window (Save / Default / Cancel, every change shows live) and the probe report window.

local ADDON, ns = ...

local W, H = 380, 700
local f
local ctl = {}
local backup, saved

local function db() return ns.db end

local function Live(full)
  if full then ns.ApplyAll() else ns.Apply() end
  if ns.RefreshConfig then ns.RefreshConfig() end
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
local function Header(parent, text, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", 14, y)
  fs:SetText(text)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(1, 0.82, 0, 0.25)
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", 14, y - 17)
  line:SetPoint("TOPRIGHT", -14, y - 17)
  return y - 28
end

local function Button(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(text)
  b:SetScript("OnClick", function(...) ns.Safe(onClick, ...) end)
  return b
end

local function Check(parent, label, y, onClick)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb:SetPoint("TOPLEFT", 10, y)
  if type(cb.Text) == "table" then cb.Text:SetText("") end
  if type(cb.text) == "table" then cb.text:SetText("") end
  local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("LEFT", cb, "RIGHT", 2, 1)
  fs:SetText(label)
  cb.label = fs
  cb:SetScript("OnClick", function(self) ns.Safe(onClick, self:GetChecked() and true or false) end)
  function cb:SetActive(on)
    self:SetEnabled(on)
    fs:SetTextColor(on and 1 or 0.5, on and 1 or 0.5, on and 1 or 0.5)
  end
  return cb
end

local function Slider(parent, label, y, minV, maxV, step, fmt, onChange)
  local h = CreateFrame("Frame", nil, parent)
  h:SetPoint("TOPLEFT", 16, y)
  h:SetPoint("TOPRIGHT", -16, y)
  h:SetHeight(36)
  local lab = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  lab:SetPoint("TOPLEFT")
  lab:SetText(label)
  local val = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  val:SetPoint("TOPRIGHT")
  local ok, s = pcall(CreateFrame, "Slider", nil, h, "UISliderTemplate")
  if not ok or not s then
    s = CreateFrame("Slider", nil, h)
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local bg = s:CreateTexture(nil, "BACKGROUND")
    bg:SetColorTexture(0, 0, 0, 0.5)
    bg:SetPoint("LEFT") bg:SetPoint("RIGHT") bg:SetHeight(6)
  end
  s:SetOrientation("HORIZONTAL")
  s:SetPoint("TOPLEFT", 0, -15)
  s:SetPoint("TOPRIGHT", 0, -15)
  s:SetHeight(17)
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  s:SetScript("OnValueChanged", function(_, v)
    v = math.floor(v / step + 0.5) * step
    val:SetText(fmt(v))
    if not h.silent then ns.Safe(onChange, v) end
  end)
  function h:Set(v)
    self.silent = true
    s:SetValue(v)
    val:SetText(fmt(v))
    self.silent = false
  end
  function h:SetActive(on)
    s:SetEnabled(on)
    s:SetAlpha(on and 1 or 0.4)
    lab:SetTextColor(on and 1 or 0.5, on and 1 or 0.5, on and 1 or 0.5)
  end
  return h
end

-- A row of buttons where one is selected.
local function Choice(parent, label, y, options, onPick)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", 16, y - 5)
  fs:SetText(label)
  local row = { buttons = {}, label = fs }
  local bw = math.floor((W - 16 - 16 - 110 - 4 * (#options - 1)) / #options)
  for i, o in ipairs(options) do
    local b = Button(parent, o.text, bw, function() onPick(o.key) end)
    b:SetPoint("TOPLEFT", 16 + 110 + (i - 1) * (bw + 4), y)
    row.buttons[o.key] = b
  end
  function row:Set(key)
    for k, b in pairs(self.buttons) do
      if k == key then b:LockHighlight() else b:UnlockHighlight() end
    end
  end
  function row:SetActive(on)
    for _, b in pairs(self.buttons) do b:SetEnabled(on) end
    fs:SetTextColor(on and 1 or 0.5, on and 1 or 0.5, on and 1 or 0.5)
  end
  return row
end

-- [<] value [>]
local function Cycler(parent, label, y, onStep)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", 16, y - 5)
  fs:SetText(label)
  local prev = Button(parent, "<", 26, function() onStep(-1) end)
  prev:SetPoint("TOPLEFT", 126, y)
  local nxt = Button(parent, ">", 26, function() onStep(1) end)
  nxt:SetPoint("TOPRIGHT", -16, y)
  local value = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  value:SetPoint("LEFT", prev, "RIGHT", 4, 0)
  value:SetPoint("RIGHT", nxt, "LEFT", -4, 0)
  return { value = value, label = fs }
end

---------------------------------------------------------------------------
-- Color picker
---------------------------------------------------------------------------
local function PickColor(c, onChange)
  local prev = { r = c.r, g = c.g, b = c.b, a = c.a or 1 }
  local function current()
    local r, g, b = ColorPickerFrame:GetColorRGB()
    local a
    if ColorPickerFrame.GetColorAlpha then a = ColorPickerFrame:GetColorAlpha()
    elseif OpacitySliderFrame then a = 1 - OpacitySliderFrame:GetValue() end
    onChange(r, g, b, a or prev.a)
  end
  local function cancel() onChange(prev.r, prev.g, prev.b, prev.a) end
  if ColorPickerFrame.SetupColorPickerAndShow then
    ColorPickerFrame:SetupColorPickerAndShow({
      r = c.r, g = c.g, b = c.b, opacity = c.a or 1, hasOpacity = true,
      swatchFunc = current, opacityFunc = current, cancelFunc = cancel,
    })
  else
    ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = current, current, cancel
    ColorPickerFrame.hasOpacity, ColorPickerFrame.opacity = true, 1 - (c.a or 1)
    ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
    ShowUIPanel(ColorPickerFrame)
  end
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local function Build()
  local ok
  ok, f = pcall(CreateFrame, "Frame", "MariscosMinimapUnboundConfig", UIParent, "PortraitFrameTemplate")
  if not ok or not f then
    f = CreateFrame("Frame", "MariscosMinimapUnboundConfig", UIParent, "BasicFrameTemplateWithInset")
  end
  f:SetSize(W, H)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local r = ns.UIRect(self)
    if r then db().configPos = ns.PosFromRect(r) end
  end)
  tinsert(UISpecialFrames, "MariscosMinimapUnboundConfig")

  local title = ns.TITLE .. " - |cffffffff" .. ns.VERSION_LABEL .. "|r"
  if f.SetTitle then f:SetTitle(title)
  elseif f.TitleText then f.TitleText:SetText(title)
  else
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOP", 0, -5)
    t:SetText(title)
  end
  if f.SetPortraitToAsset then pcall(f.SetPortraitToAsset, f, ns.ICON)
  elseif f.SetPortraitTextureRaw then pcall(f.SetPortraitTextureRaw, f, ns.ICON) end

  local okI, inset = pcall(CreateFrame, "Frame", nil, f, "InsetFrameTemplate")
  if not okI or not inset then inset = CreateFrame("Frame", nil, f) end
  inset:SetPoint("TOPLEFT", 10, -62)
  inset:SetPoint("BOTTOMRIGHT", -10, 42)
  local c = inset
  local y = -10

  ---------------- Map
  y = Header(c, "Map", y)
  ctl.shape = Choice(c, "Shape", y, { { key = "round", text = "Round" }, { key = "square", text = "Square" } },
    function(k) db().shape = k Live(true) end)
  y = y - 30
  ctl.skin = Cycler(c, "Skin", y, function(d)
    local s = ns.SKIN_BY_KEY[db().skin] or ns.SKINS[1]
    local i = (s.index - 1 + d) % #ns.SKINS + 1
    db().skin = ns.SKINS[i].key
    Live(true)
  end)
  y = y - 24
  ctl.skinDesc = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  ctl.skinDesc:SetPoint("TOPLEFT", 126, y)
  ctl.skinDesc:SetPoint("TOPRIGHT", -16, y)
  ctl.skinDesc:SetJustifyH("LEFT")
  y = y - 20

  local cl = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  cl:SetPoint("TOPLEFT", 16, y - 5)
  cl:SetText("Border color")
  ctl.colorLabel = cl
  local sw = CreateFrame("Button", nil, c)
  sw:SetSize(20, 20)
  sw:SetPoint("TOPLEFT", 126, y)
  local swBorder = sw:CreateTexture(nil, "BACKGROUND")
  swBorder:SetAllPoints()
  swBorder:SetColorTexture(0.8, 0.8, 0.8, 1)
  local swCol = sw:CreateTexture(nil, "ARTWORK")
  swCol:SetPoint("TOPLEFT", 2, -2)
  swCol:SetPoint("BOTTOMRIGHT", -2, 2)
  swCol:SetTexture("Interface\\Buttons\\WHITE8X8")
  sw.col = swCol
  sw:SetScript("OnClick", function()
    PickColor(db().borderColor, function(r, g, b, a)
      local bc = db().borderColor
      bc.r, bc.g, bc.b, bc.a = r, g, b, a
      Live()
    end)
  end)
  ctl.swatch = sw
  y = y - 30

  ctl.thickness = Slider(c, "Border thickness", y, 1, 8, 1, function(v) return v .. " px" end,
    function(v) db().thickness = v Live() end)
  y = y - 42
  ctl.size = Slider(c, "Map size", y, 120, 320, 2, function(v)
    return v .. (v == ns.StockSize() and " (stock)" or "") end,
    function(v) db().size = (v == ns.StockSize()) and nil or v Live(true) end)
  y = y - 42
  ctl.alpha = Slider(c, "Map opacity", y, 30, 100, 5, function(v) return v .. "%" end,
    function(v) db().alpha = v / 100 Live() end)
  y = y - 42
  ctl.hideZoom = Check(c, "Hide the zoom buttons", y, function(v) db().hideZoom = v Live() end)
  y = y - 24
  ctl.wheel = Check(c, "Zoom with the mouse wheel", y, function(v) db().wheelZoom = v Live() end)
  y = y - 34

  ---------------- Bar and coordinates
  y = Header(c, "Top bar and coordinates", y)
  ctl.barAttached = Check(c, "Top bar stays attached to the map", y, function(v) ns.SetAttached("bar", v) Live() end)
  y = y - 28
  ctl.barSide = Choice(c, "Bar sits", y, { { key = "original", text = "Original" }, { key = "above", text = "Above" },
    { key = "below", text = "Below" } }, function(k) db().barSide = k Live() end)
  y = y - 30
  ctl.coordAttached = Check(c, "Coordinates stay attached to the map", y, function(v) ns.SetAttached("coords", v) Live() end)
  y = y - 28
  local MODES = { "auto", "own", "hidden" }
  ctl.coords = Cycler(c, "Coordinates", y, function(d)
    local i = 1
    for n, m in ipairs(MODES) do if m == db().coordMode then i = n end end
    db().coordMode = MODES[(i - 1 + d) % #MODES + 1]
    Live()
  end)
  y = y - 34

  ---------------- Placement
  y = Header(c, "Placement", y)
  ctl.clamp = Check(c, "Keep on screen", y, function(v) db().clamp = v Live() end)
  local hint = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("LEFT", ctl.clamp.label, "RIGHT", 6, 0)
  hint:SetText("(off: can touch or pass the edge)")
  y = y - 24
  ctl.snap = Check(c, "Snap to the screen edge when dropped near it", y, function(v) db().snap = v Live() end)
  y = y - 32
  ctl.move = Button(c, "Move pieces", 150, function() ns.SetMoveMode(not ns.IsMoveMode()) end)
  ctl.move:SetPoint("TOPLEFT", 16, y)
  local reset = Button(c, "Reset positions", 150, function() ns.ResetPositions() Live() end)
  reset:SetPoint("TOPRIGHT", -16, y)

  ---------------- Save / Default / Cancel
  local bw = math.floor((W - 20 - 16) / 3)
  local save = Button(f, "Save", bw, function() saved = true f:Hide() end)
  save:SetPoint("BOTTOMLEFT", 10, 12)
  local def = Button(f, "Default", bw, function() ns.LoadDefaults() Live(true) end)
  def:SetPoint("BOTTOM", 0, 12)
  local cancel = Button(f, "Cancel", bw, function() f:Hide() end)
  cancel:SetPoint("BOTTOMRIGHT", -10, 12)

  f:SetScript("OnHide", function()
    ns.Safe(function()
      if ns.IsMoveMode() then ns.SetMoveMode(false) end
      if not saved and backup then
        local d = db()
        for k in pairs(d) do d[k] = nil end
        for k, v in pairs(ns.DeepCopy(backup)) do d[k] = v end
        ns.ApplyAll()
      end
      backup = nil
    end)
  end)
  f:Hide()
end

function ns.RefreshConfig()
  if not f or not f:IsShown() then return end
  local d = db()
  ctl.shape:Set(d.shape)
  local s = ns.SKIN_BY_KEY[d.skin] or ns.SKINS[1]
  ctl.skin.value:SetText(s.name)
  ctl.skinDesc:SetText(s.desc)
  local usesColor = ns.SkinUsesColor(d.skin)
  ctl.swatch.col:SetVertexColor(d.borderColor.r, d.borderColor.g, d.borderColor.b, d.borderColor.a or 1)
  ctl.swatch:SetEnabled(usesColor)
  ctl.swatch:SetAlpha(usesColor and 1 or 0.4)
  ctl.colorLabel:SetTextColor(usesColor and 1 or 0.5, usesColor and 1 or 0.5, usesColor and 1 or 0.5)
  ctl.thickness:Set(d.thickness)
  ctl.thickness:SetActive(ns.SkinUsesThickness(d.skin) or (d.shape ~= "square" and usesColor))
  ctl.size:Set(ns.MapSize())
  ctl.alpha:Set(math.floor((d.alpha or 1) * 100 + 0.5))
  ctl.hideZoom:SetChecked(d.hideZoom)
  ctl.wheel:SetChecked(d.wheelZoom)
  ctl.barAttached:SetChecked(d.barAttached)
  ctl.barSide:Set(d.barSide)
  ctl.barSide:SetActive(d.barAttached)
  ctl.coordAttached:SetChecked(d.coordAttached)
  local modeText = {
    auto = ns.HasForeverCoords() and "Forever's own" or "Auto (Forever's not found: own)",
    own = "This addon's", hidden = "Hidden" }
  ctl.coords.value:SetText(modeText[d.coordMode] or d.coordMode)
  ctl.clamp:SetChecked(d.clamp)
  ctl.snap:SetChecked(d.snap)
  ctl.move:SetText(ns.IsMoveMode() and "Lock pieces" or "Move pieces")
end

function ns.OnMoveModeChanged() ns.RefreshConfig() end

function ns.ToggleConfig()
  if not f then Build() end
  if f:IsShown() then f:Hide() return end
  if db().configPos then
    local p = db().configPos
    f:ClearAllPoints()
    f:SetPoint(p.point, UIParent, p.point, p.x, p.y)
  else
    f:ClearAllPoints()
    f:SetPoint("CENTER", -200, 0)
  end
  backup = ns.DeepCopy(db())
  saved = false
  f:Show()
  ns.RefreshConfig()
end

---------------------------------------------------------------------------
-- Report window (selectable text for Ctrl+C)
---------------------------------------------------------------------------
local rf
function ns.ShowReport(text)
  if not rf then
    local ok
    ok, rf = pcall(CreateFrame, "Frame", "MariscosMinimapUnboundReport", UIParent, "BasicFrameTemplateWithInset")
    if not ok or not rf then rf = CreateFrame("Frame", "MariscosMinimapUnboundReport", UIParent) end
    rf:SetSize(620, 440)
    rf:SetPoint("CENTER")
    rf:SetFrameStrata("DIALOG")
    rf:SetMovable(true)
    rf:EnableMouse(true)
    rf:RegisterForDrag("LeftButton")
    rf:SetScript("OnDragStart", rf.StartMoving)
    rf:SetScript("OnDragStop", rf.StopMovingOrSizing)
    local t = rf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOP", 0, -5)
    t:SetText("Minimap Unbound report - Ctrl+C to copy")
    local sf = CreateFrame("ScrollFrame", nil, rf, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, -30)
    sf:SetPoint("BOTTOMRIGHT", -32, 12)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(570)
    eb:SetScript("OnEscapePressed", function() rf:Hide() end)
    sf:SetScrollChild(eb)
    rf.eb = eb
    tinsert(UISpecialFrames, "MariscosMinimapUnboundReport")
  end
  rf.eb:SetText(text)
  rf:Show()
  rf.eb:SetFocus()
  rf.eb:HighlightText()
end
