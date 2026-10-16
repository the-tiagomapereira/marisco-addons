local _, ns = ...

local UI = {}
ns.UI = UI

local ROW_H = 18
local PAD = 20          -- inner margin from the window edge
local TOP = 34          -- content starts below the title bar
local FOOTER_H = 112
local BOTTOM = 30       -- space under the footer (author line)
local MIN_W, MIN_H = 470, 500
local MAX_W, MAX_H = 1100, 1300

-- Shopping list column widths (right to left)
local COL_TOTAL, COL_EACH, COL_QTY, COL_HAVE = 92, 92, 40, 44

local SOURCES = {
    { value = "all",     text = "All sources" },
    { value = "vendor",  text = "Vendor" },
    { value = "drop",    text = "Drop / gathered" },
    { value = "crafted", text = "Crafted" },
}
local SOURCE_TAG = {
    vendor  = "|cff69ccf0vendor|r",
    crafted = "|cffe6cc80crafted|r",
}

UI.backdropFrames, UI.templateFrames, UI.alphaTextures = {}, {}, {}

StaticPopupDialogs["PROFESSIONSHOPPINGLIST_CLEAR_NOTES"] = {
    text = "Clear the Notes text?",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function() UI:ClearNotes() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["PROFESSIONSHOPPINGLIST_SHARE_GUIDE"] = {
    text = "Share this leveling list with which player?\n|cff9d9d9dIt will be sent to them by whisper.|r",
    button1 = "Share",
    button2 = CANCEL or "Cancel",
    hasEditBox = 1,
    maxLetters = 64,
    OnShow = function(self)
        local eb = self.editBox or self.EditBox
        if eb then eb:SetText("") eb:SetFocus() end
    end,
    OnAccept = function(self)
        local eb = self.editBox or self.EditBox
        UI:ShareGuide(eb and eb:GetText())
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        UI:ShareGuide(self:GetText())
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["PROFESSIONSHOPPINGLIST_CLEAR"] = {
    text = "Clear the whole shopping list?",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function() ns:ClearList() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function Money(copper)
    if not copper then return "|cff808080-|r" end
    if copper == 0 then return "0" end
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local out = ""
    if g > 0 then out = out .. g .. "g " end
    if s > 0 or g > 0 then out = out .. s .. "s " end
    return out .. c .. "c"
end

local function Plural(n, word)
    return n .. " " .. word .. (n == 1 and "" or "s") .. " ago"
end

local function Ago(t)
    if not t then return "never" end
    local d = math.max(0, time() - t)
    if d < 60 then return Plural(d, "second") end
    if d < 3600 then return Plural(math.floor(d / 60), "minute") end
    if d < 86400 then return Plural(math.floor(d / 3600), "hour") end
    return Plural(math.floor(d / 86400), "day")
end

-- "12g 05s 07c" with white numbers and coloured g/s/c
local function MoneyFull(copper)
    copper = math.max(0, math.floor(copper or 0))
    local g = math.floor(copper / 10000)
    local sv = math.floor((copper % 10000) / 100)
    local c = copper % 100
    return string.format("|cffffffff%d|r|cffffd700g|r |cffffffff%02d|r|cffc7c7cfs|r |cffffffff%02d|r|cffeda55fc|r", g, sv, c)
end

local function PriceText(p)
    if not p then return "|cff808080not scanned|r" end
    if p.none then return "|cffff6060none listed|r" end
    local s = Money(p.price)
    if p.t and time() - p.t > 86400 then s = "|cffaaaaaa" .. s .. "|r" end
    return s
end

local function AddBackdrop(f)
    if not f.SetBackdrop then return end
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    UI.backdropFrames[#UI.backdropFrames + 1] = f
end

local function HasTemplate(name)
    if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
        return C_XMLUtil.GetTemplateInfo(name) ~= nil
    end
    return false
end

-- A window in the modern Blizzard style (same frame template the auction house
-- uses). Falls back to a plain dark panel if the template isn't available.
local function CreatePanel(name, parent, titleText)
    local f
    if HasTemplate("ButtonFrameTemplate") then
        f = CreateFrame("Frame", name, parent, "ButtonFrameTemplate")
        if ButtonFrameTemplate_HidePortrait then pcall(ButtonFrameTemplate_HidePortrait, f) end
        if ButtonFrameTemplate_HideButtonBar then pcall(ButtonFrameTemplate_HideButtonBar, f) end
        if f.Inset then f.Inset:Hide() end
        if f.TitleContainer then f.TitleContainer:Hide() end
        if f.TitleText then f.TitleText:Hide() end
        UI.templateFrames[#UI.templateFrames + 1] = f
    else
        f = CreateFrame("Frame", name, parent, "BackdropTemplate")
        AddBackdrop(f)
    end
    if not f.CloseButton then
        f.CloseButton = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        f.CloseButton:SetSize(24, 24)
        f.CloseButton:SetPoint("TOPRIGHT", -3, -3)
    end
    -- The template draws its border on a child frame (NineSlice) that sits
    -- above the window's own text. Our title and buttons live on an overlay
    -- that is raised above that border.
    local ov = CreateFrame("Frame", nil, f)
    ov:SetAllPoints(f)
    f.PSLOverlay = ov
    f.PSLTitle = ov:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.PSLTitle:SetJustifyH("LEFT")
    f.PSLTitle:SetText(titleText)
    f:EnableMouse(true)
    UI.RaiseOverlay(f)
    f:HookScript("OnShow", UI.RaiseOverlay)
    return f
end

function UI.RaiseOverlay(f)
    local ov = f.PSLOverlay
    if not ov then return end
    local lvl = f:GetFrameLevel()
    if f.NineSlice then lvl = math.max(lvl, f.NineSlice:GetFrameLevel()) end
    if f.CloseButton then lvl = math.max(lvl, f.CloseButton:GetFrameLevel()) end
    ov:SetFrameLevel(lvl + 2)
end

function UI:ApplyAlpha()
    local a = ns.db.settings.bgAlpha or 0.92
    for _, f in ipairs(self.backdropFrames) do
        f:SetBackdropColor(0.05, 0.05, 0.08, a)
        f:SetBackdropBorderColor(0.6, 0.6, 0.6, math.max(a, 0.3))
    end
    for _, f in ipairs(self.templateFrames) do
        if f.Bg then f.Bg:SetAlpha(a) end
        if f.TopTileStreaks then f.TopTileStreaks:SetAlpha(a) end
    end
    for _, t in ipairs(self.alphaTextures) do t:SetColorTexture(0, 0, 0, 0.35 * a) end
end

local function DarkBg(frame)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    UI.alphaTextures[#UI.alphaTextures + 1] = bg
    return bg
end

local function MakeButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h or 22)
    b:SetText(text)
    return b
end

local function IconButton(parent, texture, size, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b:SetNormalTexture(texture)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b.tip = tip
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.tip)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function CheckBox(parent, label, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    fs:SetText(label)
    cb.label = fs
    return cb
end

-- Hand-built slider (avoids template differences between clients)
local function MakeSlider(parent, width, minV, maxV, step, onChange)
    local sl = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    sl:SetOrientation("HORIZONTAL")
    sl:SetSize(width, 17)
    if sl.SetBackdrop then
        sl:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
            edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 3, right = 3, top = 6, bottom = 6 },
        })
    end
    sl:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(step)
    if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
    sl:EnableMouseWheel(true)
    sl:SetScript("OnMouseWheel", function(self, d) self:SetValue(self:GetValue() + d * step) end)
    sl:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        onChange(v)
    end)
    return sl
end

-- Turn the frame's current spot into a plain TOPLEFT anchor on the screen.
local function AnchorAbsolute(f)
    local l, t = f:GetLeft(), f:GetTop()
    if l and t then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
        return l, t
    end
end

local function MakeMovable(f, posKey, onMoved)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local l, t = AnchorAbsolute(self)
        if l then ns.db[posKey] = { "TOPLEFT", "BOTTOMLEFT", l, t } end
        if onMoved then onMoved() end
    end)
end

local function RestorePos(f, posKey, default)
    f:ClearAllPoints()
    local pos = ns.db[posKey]
    if pos then
        f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    elseif default then
        default(f)
    end
end

local function ShowItemTooltip(owner, e, extraHint, withPrices)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if e.id then
        GameTooltip:SetHyperlink("item:" .. e.id)
    else
        GameTooltip:AddLine(e.name, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    if withPrices then
        local p = ns:GetPrice(e.name, e.id)
        GameTooltip:AddDoubleLine("AH price (each):", PriceText(p), 1, 0.82, 0, 1, 1, 1)
        if p then GameTooltip:AddDoubleLine("Last scanned:", Ago(p.t), 1, 0.82, 0, 1, 1, 1) end
    end
    local src = ns:GetSource(e)
    local vp = ns:GetVendorPrice(e.id)
    if src == "vendor" then
        GameTooltip:AddDoubleLine("Source:", vp and ("Vendor (" .. Money(vp) .. " each)") or "Vendor", 1, 0.82, 0, 0.41, 0.8, 0.94)
    elseif src == "crafted" then
        GameTooltip:AddDoubleLine("Source:", "Crafted", 1, 0.82, 0, 0.9, 0.8, 0.5)
    else
        GameTooltip:AddDoubleLine("Source:", "Drop / gathered", 1, 0.82, 0, 0.8, 0.8, 0.8)
    end
    if withPrices and e.id then GameTooltip:AddDoubleLine("You own (bags+bank):", ns:GetOwned(e.id), 1, 0.82, 0, 1, 1, 1) end
    if extraHint then GameTooltip:AddLine(extraHint, 0.5, 0.8, 1, true) end
    GameTooltip:Show()
end

local function HandleDrop()
    local kind, id, link = GetCursorInfo()
    if kind ~= "item" then return end
    local name = (id and ns.GetItemInfo(id)) or (link and link:match("%[(.-)%]"))
    ClearCursor()
    if not name then return end
    local prof = ns.db.settings.profession
    ns:LearnMaterial(prof, name, id)
    ns:AddToList(name, id, 1)
    ns:RebuildKnown()
    ns.Print("Added " .. name .. " (also saved under " .. prof .. ").")
end

-- Shared click / hover behaviour for material entries (list rows and grid cells)
local function MatOnClick(self, button)
    local e = self.entry
    if not e then return end
    if button == "RightButton" then
        ns:ChangeQty(e.name, -1)
    else
        ns:AddToList(e.name, e.id, IsShiftKeyDown() and 5 or 1)
    end
end

local function MatOnEnter(self)
    if self.entry then
        ShowItemTooltip(self, self.entry, "Click +1, shift-click +5, right-click -1.")
    end
end

---------------------------------------------------------------------------
-- Popup menu (used for the profession and source pickers)
---------------------------------------------------------------------------
function UI:ShowMenu(anchor, items, current, onSelect)
    local pop = self.menu
    if not pop then
        pop = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        pop:SetFrameStrata("FULLSCREEN_DIALOG")
        pop:EnableMouse(true)
        AddBackdrop(pop)
        pop:SetBackdropColor(0.05, 0.05, 0.08, 0.97)
        pop.buttons = {}
        pop:Hide()
        self.menu = pop
    end
    if pop:IsShown() and pop.anchor == anchor then pop:Hide() return end
    pop.anchor = anchor
    local width = math.max(anchor:GetWidth(), 150)
    for i, item in ipairs(items) do
        local b = pop.buttons[i]
        if not b then
            b = CreateFrame("Button", nil, pop)
            b:SetHeight(18)
            local hl = b:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.15)
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.text:SetPoint("LEFT", 6, 0)
            b:SetScript("OnClick", function(btn)
                pop:Hide()
                if btn.onSelect then btn.onSelect(btn.value) end
            end)
            pop.buttons[i] = b
        end
        b:SetWidth(width - 12)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 18)
        b.value, b.onSelect = item.value, onSelect
        b.text:SetText(item.value == current and ("|cffffd100" .. item.text .. "|r") or item.text)
        b:Show()
    end
    for i = #items + 1, #pop.buttons do pop.buttons[i]:Hide() end
    pop:SetSize(width, 12 + #items * 18)
    pop:ClearAllPoints()
    pop:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    pop:Show()
end

function UI:HideMenu()
    if self.menu then self.menu:Hide() end
end

---------------------------------------------------------------------------
-- Thin vertical scrollbar on the right edge of a scrolling area. It only
-- shows when there is something to scroll.
---------------------------------------------------------------------------
local SCROLL_W = 12   -- room kept free on the right of lists for the bar

local function CreateScrollbar(parent, anchor, getRange, getValue, setValue)
    local sl = CreateFrame("Slider", nil, parent)
    sl:SetOrientation("VERTICAL")
    sl:SetWidth(8)
    sl:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -2, -2)
    sl:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -2, 2)
    sl:SetFrameLevel(anchor:GetFrameLevel() + 5)
    local track = sl:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0, 0, 0, 0.55)
    local thumb = sl:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(0.85, 0.7, 0.25, 0.85)
    thumb:SetSize(8, 28)
    sl:SetThumbTexture(thumb)
    sl.wheelStep = 1
    sl:SetScript("OnValueChanged", function(self, v)
        if not self.updating then setValue(v) end
    end)
    sl:EnableMouseWheel(true)
    sl:SetScript("OnMouseWheel", function(self, d) self:SetValue(self:GetValue() - d * self.wheelStep) end)
    function sl:Update()
        local range = getRange() or 0
        if range <= 0 then self:Hide() return end
        self.updating = true
        self:SetMinMaxValues(0, range)
        self:SetValue(getValue() or 0)
        self.updating = false
        self:Show()
    end
    sl:Hide()
    return sl
end

-- Scrollbar for a ScrollFrame (notes, release notes, leveling guide)
local function AttachFrameScrollbar(sf)
    local bar = CreateScrollbar(sf:GetParent(), sf,
        function() return sf:GetVerticalScrollRange() end,
        function() return sf:GetVerticalScroll() end,
        function(v) sf:SetVerticalScroll(v) end)
    bar.wheelStep = 30
    sf:HookScript("OnScrollRangeChanged", function() bar:Update() end)
    sf:HookScript("OnVerticalScroll", function() bar:Update() end)
    return bar
end

---------------------------------------------------------------------------
-- Scrolling list with a variable number of rows (mouse wheel)
---------------------------------------------------------------------------
local function CreateList(parent, setupRow, updateRow)
    local list = CreateFrame("Frame", nil, parent)
    list.rows, list.data, list.offset, list.numRows, list.topInset = {}, {}, 0, 0, 0
    DarkBg(list)

    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(self, delta) self:ScrollBy(-delta * 3) end)

    list.empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    list.empty:SetPoint("CENTER")

    function list:SetRowCount(n)
        n = math.max(1, n)
        for i = #self.rows + 1, n do
            local r = CreateFrame("Button", nil, self)
            r:SetHeight(ROW_H)
            r:SetPoint("TOPLEFT", 0, -(self.topInset + (i - 1) * ROW_H))
            r:SetPoint("TOPRIGHT", -SCROLL_W, -(self.topInset + (i - 1) * ROW_H))
            r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            r:SetScript("OnReceiveDrag", HandleDrop)

            local hl = r:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.12)

            r.icon = r:CreateTexture(nil, "ARTWORK")
            r.icon:SetSize(16, 16)
            r.icon:SetPoint("LEFT", 2, 0)

            r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
            r.name:SetJustifyH("LEFT")
            r.name:SetWordWrap(false)

            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            setupRow(r)
            self.rows[i] = r
        end
        self.numRows = n
        self:Refresh()
    end

    function list:SetData(d, emptyText)
        self.data = d or {}
        self.emptyText = emptyText
        self:Refresh()
    end

    function list:ScrollBy(n)
        local maxOff = math.max(0, #self.data - self.numRows)
        self.offset = math.min(maxOff, math.max(0, self.offset + n))
        self:Refresh()
    end

    function list:Refresh()
        local maxOff = math.max(0, #self.data - self.numRows)
        if self.offset > maxOff then self.offset = maxOff end
        for i, r in ipairs(self.rows) do
            local e = (i <= self.numRows) and self.data[i + self.offset]
            if e then
                r.entry = e
                updateRow(r, e)
                r:Show()
            else
                r.entry = nil
                r:Hide()
            end
        end
        local n = #self.data
        if self.countText then
            if n > self.numRows then
                self.countText:SetText(string.format("%d-%d of %d", self.offset + 1, math.min(n, self.offset + self.numRows), n))
            else
                self.countText:SetText(n > 0 and (n .. " item(s)") or "")
            end
        end
        self.empty:SetText(n == 0 and (self.emptyText or "") or "")
        if self.bar then self.bar:Update() end
    end

    list.bar = CreateScrollbar(list, list,
        function() return math.max(0, #list.data - list.numRows) end,
        function() return list.offset end,
        function(v) list.offset = math.floor(v + 0.5) list:Refresh() end)

    return list
end

---------------------------------------------------------------------------
-- Grid of large icons with the name underneath
---------------------------------------------------------------------------
local function CreateGrid(parent)
    local g = CreateFrame("Frame", nil, parent)
    g.cells, g.data, g.rowOffset, g.cols, g.rows = {}, {}, 0, 1, 1
    DarkBg(g)

    g.empty = g:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    g.empty:SetPoint("CENTER")

    g:EnableMouseWheel(true)
    g:SetScript("OnMouseWheel", function(self, delta)
        self.rowOffset = self.rowOffset - delta
        self:Refresh()
    end)

    function g:GetCell(i)
        local c = self.cells[i]
        if c then return c end
        c = CreateFrame("Button", nil, self)
        c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        c:SetScript("OnReceiveDrag", HandleDrop)
        c:SetScript("OnClick", MatOnClick)
        c:SetScript("OnEnter", MatOnEnter)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local hl = c:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.10)

        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetPoint("TOP", 0, -4)

        c.glow = c:CreateTexture(nil, "BORDER")
        c.glow:SetPoint("TOPLEFT", c.icon, "TOPLEFT", -2, 2)
        c.glow:SetPoint("BOTTOMRIGHT", c.icon, "BOTTOMRIGHT", 2, -2)
        c.glow:SetColorTexture(0.25, 1, 0.25, 0.6)

        c.qty = c:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        c.qty:SetPoint("BOTTOMRIGHT", c.icon, "BOTTOMRIGHT", -1, 2)

        c.owned = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        c.owned:SetPoint("TOPRIGHT", c.icon, "TOPRIGHT", -1, -2)

        c.tag = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        c.tag:SetPoint("TOPLEFT", c.icon, "TOPLEFT", 2, -2)

        c.name = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        c.name:SetPoint("TOP", c.icon, "BOTTOM", 0, -2)
        c.name:SetJustifyH("CENTER")
        c.name:SetJustifyV("TOP")
        c.name:SetWordWrap(true)
        if c.name.SetMaxLines then c.name:SetMaxLines(2) end

        self.cells[i] = c
        return c
    end

    function g:SetData(d, emptyText)
        self.data = d or {}
        self.emptyText = emptyText
        self:Refresh()
    end

    function g:Refresh()
        if not self:IsShown() then return end
        local size = ns.db.settings.iconSize or 40
        local W, H = self:GetWidth(), self:GetHeight()
        W = W - SCROLL_W
        if not W or W <= 0 or not H or H <= 0 then return end
        local minCellW = math.max(size + 20, 64)
        local cellH = size + 34
        local cols = math.max(1, math.floor(W / minCellW))
        local rows = math.max(1, math.floor(H / cellH))
        local cellW = W / cols
        local totalRows = math.ceil(#self.data / cols)
        local maxOff = math.max(0, totalRows - rows)
        self.rowOffset = math.min(maxOff, math.max(0, self.rowOffset))
        self.cols, self.rows = cols, rows

        local n = cols * rows
        for i = 1, n do
            local e = self.data[self.rowOffset * cols + i]
            local c = self:GetCell(i)
            if e then
                local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
                c:ClearAllPoints()
                c:SetSize(cellW, cellH)
                c:SetPoint("TOPLEFT", col * cellW, -row * cellH)
                c.icon:SetSize(size, size)
                c.name:SetWidth(cellW - 6)
                c.entry = e
                c.icon:SetTexture(ns:Icon(e.id))

                local inList = ns:FindInList(e.name)
                if inList then
                    c.glow:Show()
                    c.qty:SetText("|cff40ff40x" .. inList.qty .. "|r")
                    c.name:SetText("|cff40ff40" .. e.name .. "|r")
                else
                    c.glow:Hide()
                    c.qty:SetText("")
                    c.name:SetText(e.name)
                end
                c.owned:SetText("")
                local src = ns:GetSource(e)
                c.tag:SetText(src == "vendor" and "|cff69ccf0V|r" or (src == "crafted" and "|cffe6cc80C|r" or ""))
                c:Show()
            else
                c.entry = nil
                c:Hide()
            end
        end
        for i = n + 1, #self.cells do
            self.cells[i].entry = nil
            self.cells[i]:Hide()
        end

        local total = #self.data
        if self.countText then
            if totalRows > rows then
                local first = self.rowOffset * cols + 1
                self.countText:SetText(string.format("%d-%d of %d", first, math.min(total, first + n - 1), total))
            else
                self.countText:SetText(total > 0 and (total .. " item(s)") or "")
            end
        end
        self.empty:SetText(total == 0 and (self.emptyText or "") or "")
        if self.bar then self.bar:Update() end
    end

    g.bar = CreateScrollbar(g, g,
        function() return math.max(0, math.ceil(#g.data / g.cols) - g.rows) end,
        function() return g.rowOffset end,
        function(v) g.rowOffset = math.floor(v + 0.5) g:Refresh() end)

    g:SetScript("OnSizeChanged", function(self) self:Refresh() end)
    g:SetScript("OnShow", function(self) self:Refresh() end)
    return g
end

---------------------------------------------------------------------------
-- Main window
---------------------------------------------------------------------------
function UI:Create()
    if self.frame then return end
    local s = ns.db.settings

    local f = CreatePanel("ProfessionShoppingListFrame", UIParent,
        ns.TITLE .. "  |cff9d9d9d" .. ns.VERSION .. "|r")
    self.frame = f
    f:SetFrameStrata("HIGH")
    f:SetSize(s.width or 520, s.height or 640)
    f:SetClampedToScreen(true)
    MakeMovable(f, "pos", function()
        UI.docked = false
        UI:ArrangePanels()
    end)
    f:SetResizable(true)
    if f.SetResizeBounds then
        f:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
    elseif f.SetMinResize then
        f:SetMinResize(MIN_W, MIN_H)
        f:SetMaxResize(MAX_W, MAX_H)
    end
    f:SetScript("OnReceiveDrag", HandleDrop)
    f:HookScript("OnShow", function() UI:Layout() UI:ApplyResizeSetting() end)
    f:HookScript("OnHide", function()
        if UI.settings then UI.settings:Hide() end
        UI:HideMenu()
    end)
    f:HookScript("OnSizeChanged", function() UI:Layout() end)
    f:Hide()

    ---------------- Title bar ----------------
    -- side collapse (toward the auction house)
    local ov = f.PSLOverlay
    local side = IconButton(ov, "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up", 22, "Collapse toward the auction house")
    side:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    side:SetPoint("TOPLEFT", 6, -1)
    side:SetScript("OnClick", function() UI:SetSideCollapsed(true) end)

    f.PSLTitle:SetPoint("TOPLEFT", 32, -7)

    local close = f.CloseButton
    -- Minimize button: same size and art style as the X close button
    local cw, ch = close:GetSize()
    if not cw or cw < 1 then cw, ch = 24, 24 end
    local collapse = CreateFrame("Button", nil, ov)
    collapse:SetSize(cw, ch)
    collapse:SetPoint("RIGHT", close, "LEFT", 2, 0)
    collapse:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    collapse.tip = "Collapse / expand"
    collapse:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.tip)
        GameTooltip:Show()
    end)
    collapse:SetScript("OnLeave", function() GameTooltip:Hide() end)
    collapse:SetScript("OnClick", function() UI:SetCollapsed(not ns.db.settings.collapsed) end)
    self.collapseBtn = collapse
    self:SetCollapseArt(false)

    -- Side tabs (spellbook-style) on the right edge: Settings, Notes, Release notes
    self.sideTabs = {}
    local function SideTab(index, icon, tip, onClick)
        local t = CreateFrame("CheckButton", nil, f)
        t:SetSize(32, 32)
        if index == "bottom" then
            t:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", 0, 40)
        else
            t:SetPoint("TOPLEFT", f, "TOPRIGHT", 0, -36 - (index - 1) * 42)
        end
        local bg = t:CreateTexture(nil, "BACKGROUND")
        bg:SetSize(64, 64)
        bg:SetPoint("TOPLEFT", -3, 11)
        bg:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
        t:SetNormalTexture(icon)
        t:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        t:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
        t.tip = tip
        t:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tip)
            GameTooltip:Show()
        end)
        t:SetScript("OnLeave", function() GameTooltip:Hide() end)
        t:SetScript("OnClick", function(self)
            onClick()
            UI:UpdateSideTabs()
        end)
        self.sideTabs[#self.sideTabs + 1] = t
        return t
    end
    self.guideTab    = SideTab(1, "Interface\\Icons\\INV_Misc_Book_09", "Leveling guide", function() UI:ToggleGuide() end)
    self.notesTab    = SideTab(2, "Interface\\Icons\\INV_Misc_Note_01", "Notes", function() UI:ToggleNotes() end)
    self.settingsTab = SideTab(3, "Interface\\Icons\\INV_Misc_Gear_01", "Settings", function() UI:ToggleSettings() end)
    self.releaseTab  = SideTab("bottom", "Interface\\Icons\\INV_Misc_Book_09", "Release notes", function() UI:ToggleReleaseNotes() end)

    f.PSLTitle:SetWordWrap(false)

    ---------------- Content (hidden when collapsed) ----------------
    local c = CreateFrame("Frame", nil, f)
    c:SetPoint("TOPLEFT")
    c:SetPoint("BOTTOMRIGHT")
    self.content = c

    -- Profession selector:  [<] [ Leatherworking v ] [>]       [filter]
    local prev = MakeButton(c, "<", 26)
    prev:SetPoint("TOPLEFT", PAD, -TOP)
    local profBtn = MakeButton(c, "", 180)
    profBtn:SetPoint("LEFT", prev, "RIGHT", 4, 0)
    local nextB = MakeButton(c, ">", 26)
    nextB:SetPoint("LEFT", profBtn, "RIGHT", 4, 0)
    self.profBtn = profBtn
    prev:SetScript("OnClick", function() UI:CycleProfession(-1) end)
    nextB:SetScript("OnClick", function() UI:CycleProfession(1) end)
    profBtn:SetScript("OnClick", function(btn)
        local items = {}
        for _, p in ipairs(ns:GetProfessions()) do items[#items + 1] = { value = p, text = p } end
        UI:ShowMenu(btn, items, ns.db.settings.profession, function(v) UI:SetProfession(v) end)
    end)

    local filter = CreateFrame("EditBox", nil, c, "InputBoxTemplate")
    filter:SetSize(140, 20)
    filter:SetPoint("TOPRIGHT", -PAD - 2, -TOP - 1)
    filter:SetAutoFocus(false)
    filter:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    filter:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    filter:SetScript("OnTextChanged", function(box)
        UI.filterText = (box:GetText() or ""):lower()
        UI.matList.offset = 0
        UI.matGrid.rowOffset = 0
        UI:Refresh()
    end)
    local ph = filter:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph:SetPoint("LEFT", 2, 0)
    ph:SetText("Search...")
    filter:SetScript("OnEditFocusGained", function() ph:Hide() end)
    filter:SetScript("OnEditFocusLost", function(box) if box:GetText() == "" then ph:Show() end end)

    ---------------- Materials bar ----------------
    local matBar = CreateFrame("Frame", nil, c)
    matBar:SetHeight(22)
    matBar:SetPoint("TOPLEFT", PAD, -(TOP + 28))
    matBar:SetPoint("TOPRIGHT", -PAD, -(TOP + 28))

    local matLabel = matBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    matLabel:SetPoint("LEFT", 0, 0)
    matLabel:SetText("Materials")
    local matCount = matBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    matCount:SetPoint("LEFT", matLabel, "RIGHT", 6, 0)

    local viewBtn = MakeButton(matBar, "Grid view", 76, 20)
    viewBtn:SetPoint("RIGHT", 0, 0)
    viewBtn:SetScript("OnClick", function()
        s.viewMode = (s.viewMode == "grid") and "list" or "grid"
        UI:Refresh()
    end)
    self.viewBtn = viewBtn

    local srcBtn = MakeButton(matBar, "", 120, 20)
    srcBtn:SetPoint("RIGHT", viewBtn, "LEFT", -4, 0)
    srcBtn:SetScript("OnClick", function(btn)
        UI:ShowMenu(btn, SOURCES, s.sourceFilter, function(v)
            s.sourceFilter = v
            UI.matList.offset = 0
            UI.matGrid.rowOffset = 0
            UI:Refresh()
        end)
    end)
    self.srcBtn = srcBtn

    local sizeSlider = MakeSlider(matBar, 70, 24, 64, 4, function(v)
        s.iconSize = v
        UI.matGrid:Refresh()
    end)
    sizeSlider:SetPoint("RIGHT", srcBtn, "LEFT", -10, 0)
    local sizeLabel = matBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sizeLabel:SetPoint("RIGHT", sizeSlider, "LEFT", -4, 0)
    sizeLabel:SetText("Size")
    self.sizeSlider, self.sizeLabel = sizeSlider, sizeLabel

    ---------------- Materials area (list or grid) ----------------
    local matArea = CreateFrame("Frame", nil, c)
    matArea:SetPoint("TOPLEFT", matBar, "BOTTOMLEFT", 0, -4)
    matArea:SetPoint("TOPRIGHT", matBar, "BOTTOMRIGHT", 0, -4)
    matArea:SetHeight(150)
    self.matArea = matArea

    self.matList = CreateList(matArea,
        function(r)
            r.name:SetPoint("RIGHT", -4, 0)
            r:SetScript("OnClick", MatOnClick)
            r:SetScript("OnEnter", MatOnEnter)
        end,
        function(r, e)
            r.icon:SetTexture(ns:Icon(e.id))
            local text = e.name
            local inList = ns:FindInList(e.name)
            if inList then text = "|cff40ff40" .. e.name .. "|r |cffaaaaaax" .. inList.qty .. "|r" end
            local tag = SOURCE_TAG[ns:GetSource(e)]
            if tag then text = text .. "  " .. tag end
            r.name:SetText(text)
        end)
    self.matList:SetAllPoints(matArea)
    self.matList.countText = matCount

    self.matGrid = CreateGrid(matArea)
    self.matGrid:SetAllPoints(matArea)
    self.matGrid.countText = matCount
    self.matGrid:Hide()

    ---------------- Separator ----------------
    local sep = c:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(2)
    sep:SetPoint("TOPLEFT", matArea, "BOTTOMLEFT", 0, -9)
    sep:SetPoint("TOPRIGHT", matArea, "BOTTOMRIGHT", 0, -9)
    sep:SetColorTexture(0.85, 0.7, 0.25, 0.55)
    local sepShadow = c:CreateTexture(nil, "ARTWORK")
    sepShadow:SetHeight(1)
    sepShadow:SetPoint("TOPLEFT", sep, "BOTTOMLEFT")
    sepShadow:SetPoint("TOPRIGHT", sep, "BOTTOMRIGHT")
    sepShadow:SetColorTexture(0, 0, 0, 0.6)

    ---------------- Shopping list ----------------
    local listBar = CreateFrame("Frame", nil, c)
    listBar:SetHeight(18)
    listBar:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -6)
    listBar:SetPoint("TOPRIGHT", sep, "BOTTOMRIGHT", 0, -6)
    local listLabel = listBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listLabel:SetPoint("LEFT", 0, 0)
    listLabel:SetText("Shopping List")
    local listHint = listBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    listHint:SetPoint("LEFT", listLabel, "RIGHT", 6, 0)
    listHint:SetText("(type a quantity, alt-click to search the Auction House)")

    self.shopList = CreateList(c,
        function(r)
            local x = CreateFrame("Button", nil, r)
            x:SetSize(16, 16)
            x:SetPoint("LEFT", 0, 0)
            local xt = x:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            xt:SetPoint("CENTER")
            xt:SetText("|cffff3333X|r")
            x:SetScript("OnEnter", function(self)
                xt:SetText("|cffff8080X|r")
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetText("Remove from list")
                GameTooltip:Show()
            end)
            x:SetScript("OnLeave", function() xt:SetText("|cffff3333X|r") GameTooltip:Hide() end)
            x:SetScript("OnClick", function() if r.entry then ns:RemoveFromList(r.entry.name) end end)
            r.icon:ClearAllPoints()
            r.icon:SetPoint("LEFT", x, "RIGHT", 2, 0)

            r.total = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.total:SetPoint("RIGHT", -4, 0)
            r.total:SetWidth(COL_TOTAL)
            r.total:SetJustifyH("RIGHT")
            r.each = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.each:SetPoint("RIGHT", r.total, "LEFT", -4, 0)
            r.each:SetWidth(COL_EACH)
            r.each:SetJustifyH("RIGHT")

            -- vendor vs. auction house comparison icon
            local cmp = CreateFrame("Button", nil, r)
            cmp:SetSize(13, 13)
            cmp:SetPoint("RIGHT", r.each, "LEFT", 22, 0)
            cmp.tex = cmp:CreateTexture(nil, "ARTWORK")
            cmp.tex:SetAllPoints()
            cmp.tex:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
            cmp.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            cmp:SetScript("OnEnter", function(self)
                local d = self.data
                if not d then return end
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:AddLine("Vendor vs. auction house")
                GameTooltip:AddDoubleLine("Vendor (used):", Money(d.vendor), 1, 0.82, 0, 0.41, 0.8, 0.94)
                GameTooltip:AddDoubleLine("Auction house:", Money(d.ah), 1, 0.82, 0, 1, 1, 1)
                if d.ah < d.vendor then
                    GameTooltip:AddLine("The AH is " .. Money(d.vendor - d.ah) .. " cheaper each.", 0.25, 1, 0.25, true)
                elseif d.ah > d.vendor then
                    GameTooltip:AddLine("The vendor is " .. Money(d.ah - d.vendor) .. " cheaper each.", 0.25, 1, 0.25, true)
                else
                    GameTooltip:AddLine("Same price.", 1, 1, 1)
                end
                GameTooltip:Show()
            end)
            cmp:SetScript("OnLeave", function() GameTooltip:Hide() end)
            cmp:Hide()
            r.cmp = cmp

            local q = CreateFrame("EditBox", nil, r, "InputBoxTemplate")
            q:SetSize(COL_QTY - 4, 16)
            q:SetPoint("RIGHT", r.each, "LEFT", -8, 0)
            q:SetAutoFocus(false)
            q:SetNumeric(true)
            q:SetMaxLetters(5)
            q:SetJustifyH("CENTER")
            local function commit(box)
                if box.editName then
                    local n = tonumber(box:GetText())
                    if n then ns:SetQty(box.editName, n) end
                    box.editName = nil
                end
                ns:RequestRefresh()
            end
            q:SetScript("OnEditFocusGained", function(box)
                box.editName = r.entry and r.entry.name
                box:HighlightText()
            end)
            q:SetScript("OnEnterPressed", function(box) commit(box) box:ClearFocus() end)
            q:SetScript("OnTabPressed", function(box) commit(box) box:ClearFocus() end)
            q:SetScript("OnEditFocusLost", function(box) commit(box) end)
            q:SetScript("OnEscapePressed", function(box) box.editName = nil box:ClearFocus() ns:RequestRefresh() end)
            r.qtyBox = q

            r.have = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.have:SetPoint("RIGHT", q, "LEFT", -10, 0)
            r.have:SetWidth(COL_HAVE)
            r.have:SetJustifyH("RIGHT")
            r.name:SetPoint("RIGHT", r.have, "LEFT", -4, 0)

            r:SetScript("OnClick", function(self)
                if self.entry and IsAltKeyDown() then ns.Auction:StartScan(self.entry) end
            end)
            r:SetScript("OnEnter", function(self)
                if self.entry then ShowItemTooltip(self, self.entry, "Alt-click to search the auction house for this item.", true) end
            end)
        end,
        function(r, e)
            r.icon:SetTexture(ns:Icon(e.id))
            local cur = ns.Auction:Current()
            if cur and e.id == cur then
                r.name:SetText("|cffffff00> " .. e.name .. "|r")
            else
                r.name:SetText(e.name)
            end
            if not r.qtyBox:HasFocus() then r.qtyBox:SetText(tostring(e.qty)) end

            local owned = ns:GetOwned(e.id)
            if owned >= e.qty then
                r.have:SetText("|cff40ff40" .. owned .. "|r")
            elseif owned > 0 then
                r.have:SetText("|cffffd100" .. owned .. "|r")
            else
                r.have:SetText("|cff8080800|r")
            end

            local need = e.qty
            if ns.db.settings.subtractOwned then need = math.max(0, e.qty - owned) end
            local p = ns:GetPrice(e.name, e.id)
            local unit, kind = ns:GetUnitPrice(e)
            if kind == "vendor" then
                r.each:SetText("|cff69ccf0" .. Money(unit) .. "|r")
                if p and p.price then
                    r.cmp.data = { vendor = unit, ah = p.price }
                    if p.price < unit then
                        r.cmp.tex:SetVertexColor(0.4, 1, 0.4)   -- AH is cheaper
                    elseif p.price > unit then
                        r.cmp.tex:SetVertexColor(1, 0.45, 0.45) -- AH costs more
                    else
                        r.cmp.tex:SetVertexColor(1, 1, 1)
                    end
                    r.cmp:Show()
                else
                    r.cmp.data = nil
                    r.cmp:Hide()
                end
            else
                r.each:SetText(PriceText(p))
                r.cmp.data = nil
                r.cmp:Hide()
            end
            if need == 0 then
                r.total:SetText("|cff40ff40have all|r")
            elseif unit then
                r.total:SetText(Money(unit * need))
            else
                r.total:SetText("|cff808080-|r")
            end
        end)
    self.shopList:SetPoint("TOPLEFT", listBar, "BOTTOMLEFT", 0, -6)
    self.shopList:SetPoint("TOPRIGHT", listBar, "BOTTOMRIGHT", 0, -6)
    self.shopList:SetHeight(150)
    self.shopList.topInset = 22
    self.shopList.bar:ClearAllPoints()
    self.shopList.bar:SetPoint("TOPRIGHT", self.shopList, "TOPRIGHT", -2, -22)
    self.shopList.bar:SetPoint("BOTTOMRIGHT", self.shopList, "BOTTOMRIGHT", -2, 48)

    -- Column headers inside the dark box
    local colRow = CreateFrame("Frame", nil, self.shopList)
    colRow:SetHeight(18)
    colRow:SetPoint("TOPLEFT", 0, -2)
    colRow:SetPoint("TOPRIGHT", 0, -2)
    local colLine = colRow:CreateTexture(nil, "ARTWORK")
    colLine:SetHeight(1)
    colLine:SetPoint("BOTTOMLEFT", 4, 0)
    colLine:SetPoint("BOTTOMRIGHT", -4, 0)
    colLine:SetColorTexture(1, 1, 1, 0.12)
    local listCount = colRow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    listCount:SetPoint("LEFT", 6, 0)
    self.shopList.countText = listCount
    local rTotal = 4 + SCROLL_W
    local rEach = rTotal + COL_TOTAL + 4
    local rQty = rEach + COL_EACH + 8
    local rHave = rQty + COL_QTY + 6
    local function colHeader(text, rightOffset)
        local fs = colRow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        fs:SetPoint("RIGHT", colRow, "RIGHT", -rightOffset, 0)
        fs:SetText(text)
    end
    colHeader("Total", rTotal)
    colHeader("Each", rEach)
    colHeader("Qty", rQty + 8)
    colHeader("Have", rHave)

    local clearList = MakeButton(self.shopList, "Clear list", 90, 20)
    clearList:SetPoint("BOTTOMRIGHT", -4, 22)
    clearList:SetScript("OnClick", function()
        if #ns.db.list == 0 then return end
        StaticPopup_Show("PROFESSIONSHOPPINGLIST_CLEAR")
    end)
    self.clearListBtn = clearList

    ---------------- Footer ----------------
    local foot = CreateFrame("Frame", nil, c)
    foot:SetPoint("TOPLEFT", self.shopList, "BOTTOMLEFT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -PAD, BOTTOM)

    -- separator, same style as the one between materials and the shopping list
    local sep2 = foot:CreateTexture(nil, "ARTWORK")
    sep2:SetHeight(2)
    sep2:SetPoint("TOPLEFT", 0, -9)
    sep2:SetPoint("TOPRIGHT", 0, -9)
    sep2:SetColorTexture(0.85, 0.7, 0.25, 0.55)
    local sep2Shadow = foot:CreateTexture(nil, "ARTWORK")
    sep2Shadow:SetHeight(1)
    sep2Shadow:SetPoint("TOPLEFT", sep2, "BOTTOMLEFT")
    sep2Shadow:SetPoint("TOPRIGHT", sep2, "BOTTOMRIGHT")
    sep2Shadow:SetColorTexture(0, 0, 0, 0.6)

    -- dark box holding the totals
    local totBox = CreateFrame("Frame", nil, foot)
    totBox:SetPoint("TOPLEFT", sep2, "BOTTOMLEFT", 0, -8)
    totBox:SetPoint("BOTTOMRIGHT", foot, "BOTTOMRIGHT", 0, 0)
    DarkBg(totBox)

    -- block of totals, centred vertically inside the box
    local block = CreateFrame("Frame", nil, totBox)
    block:SetHeight(54)
    self.totalsBlock = block
    block:SetPoint("LEFT", totBox, "LEFT", 8, 0)
    block:SetPoint("RIGHT", totBox, "RIGHT", -8, 0)

    local totalLabel = block:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    totalLabel:SetPoint("TOPLEFT", 0, 0)
    self.totalLabel = totalLabel

    local haveLabel = block:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    haveLabel:SetPoint("TOPLEFT", totalLabel, "BOTTOMLEFT", 0, -5)
    self.haveLabel = haveLabel

    local afterLabel = block:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    afterLabel:SetPoint("TOPLEFT", haveLabel, "BOTTOMLEFT", 0, -3)
    self.afterLabel = afterLabel

    local missingLabel = block:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    missingLabel:SetPoint("TOPLEFT", afterLabel, "BOTTOMLEFT", 0, -4)
    self.missingLabel = missingLabel

    -- Last scan: inside the box, bottom right, under the buttons
    local lastScan = self.shopList:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lastScan:SetPoint("RIGHT", self.shopList, "BOTTOMRIGHT", -8, 12)
    lastScan:SetJustifyH("RIGHT")
    self.lastScanLabel = lastScan

    -- Bottom bar inside the shopping list: [x] Subtract ...      [Scan list] [Clear list]
    local cb = CheckBox(self.shopList, "Subtract what I already own", function(v)
        s.subtractOwned = v
        UI:Refresh()
    end)
    cb:SetPoint("LEFT", self.shopList, "BOTTOMLEFT", 2, 12)
    self.subtractCheck = cb

    local scan = MakeButton(self.shopList, "Scan list", 110, 20)
    scan:SetPoint("RIGHT", clearList, "LEFT", -6, 0)
    scan:SetScript("OnClick", function()
        if ns.Auction.scanning then ns.Auction:StopScan() else ns.Auction:StartScan() end
        UI:UpdateTimers()
    end)
    self.scanBtn = scan

    -- Author line
    local author = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    author:SetPoint("BOTTOMLEFT", PAD, 11)
    author:SetText("Author: " .. ns.AUTHOR)

    -- Ticks once a second: live "last scan" timer and the Scan button cooldown
    local ticker = CreateFrame("Frame", nil, c)
    ticker.elapsed = 0
    ticker:SetScript("OnUpdate", function(self, el)
        self.elapsed = self.elapsed + el
        if self.elapsed >= 0.5 then
            self.elapsed = 0
            UI:UpdateTimers()
        end
    end)

    ---------------- Resize grip (bottom-right) ----------------
    local grip = CreateFrame("Button", nil, ov)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -6, 6)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        s.width, s.height = math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5)
        if UI.docked then
            UI:Dock()
        else
            local l, t = AnchorAbsolute(f)
            if l then ns.db.pos = { "TOPLEFT", "BOTTOMLEFT", l, t } end
        end
        UI:Layout()
    end)
    self.grip = grip

    -- Simple rectangle used while collapsed (the template art can't shrink that far)
    if f.NineSlice then
        local cbg = CreateFrame("Frame", nil, f, "BackdropTemplate")
        cbg:SetAllPoints(f)
        cbg:SetFrameLevel(f:GetFrameLevel())
        AddBackdrop(cbg)
        cbg:Hide()
        self.collapsedBg = cbg
    end

    self:CreateSideTab()
    self:CreateSettings()
    self:CreateNotes()
    self:CreateReleaseNotes()
    self:CreateGuide()
    self:UpdateGuideTabIcon()
    UI.RaiseOverlay(f)
    RestorePos(f, "pos", function(fr) fr:SetPoint("CENTER", UIParent, "CENTER", 250, 0) end)
    self:SetCollapsed(s.collapsed)
    self:ApplyAlpha()
end

function UI:SetCollapseArt(collapsed)
    local b = self.collapseBtn
    if not b then return end
    if collapsed then
        b:SetNormalTexture("Interface\\Buttons\\UI-Panel-BiggerButton-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-Panel-BiggerButton-Down")
    else
        b:SetNormalTexture("Interface\\Buttons\\UI-Panel-HideButton-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-Panel-HideButton-Down")
    end
    -- side tabs would float below a collapsed title bar, so hide them then
    for _, t in ipairs(self.sideTabs or {}) do t:SetShown(not collapsed) end
end

function UI:UpdateSideTabs()
    if not self.settingsTab then return end
    self.settingsTab:SetChecked(self.settings and self.settings:IsShown() or false)
    self.notesTab:SetChecked(self.notes and self.notes:IsShown() or false)
    self.releaseTab:SetChecked(self.release and self.release:IsShown() or false)
    self.guideTab:SetChecked(self.guide and self.guide:IsShown() or false)
end

function UI:ApplyResizeSetting()
    if not self.grip then return end
    local allow = ns.db.settings.allowResize and not ns.db.settings.collapsed
    self.grip:SetShown(allow and true or false)
end

---------------------------------------------------------------------------
-- Layout: split the free height between materials and the shopping list
---------------------------------------------------------------------------
function UI:Layout()
    if not self.matArea or ns.db.settings.collapsed then return end
    local H = self.frame:GetHeight()
    local fixed = (TOP + 28 + 22 + 4)          -- title, profession row, materials bar
                + (9 + 3 + 6 + 18 + 6)          -- separator, "Shopping List" subtitle + margin
                + (FOOTER_H + BOTTOM)           -- totals + author line
    local avail = math.max(ROW_H * 8, H - fixed)
    local matH = math.floor(avail * 0.45)
    local listH = avail - matH
    self.matArea:SetHeight(matH)
    self.shopList:SetHeight(listH)
    self.matList:SetRowCount(math.floor(matH / ROW_H))
    -- header row (22) on top, last-scan line + buttons (46) at the bottom
    self.shopList:SetRowCount(math.floor((listH - 22 - 46) / ROW_H))
    self:Refresh()
end

---------------------------------------------------------------------------
-- Collapse (title bar only) and side collapse (thin tab facing the AH)
---------------------------------------------------------------------------
function UI:SetCollapsed(collapsed)
    local s = ns.db.settings
    s.collapsed = collapsed and true or false
    local f = self.frame
    if collapsed then
        self.content:Hide()
        self:HideMenu()
        if f.NineSlice then f.NineSlice:Hide() end
        if f.Bg then f.Bg:Hide() end
        if f.TopTileStreaks then f.TopTileStreaks:Hide() end
        if self.collapsedBg then self.collapsedBg:Show() end
        f:SetHeight(30)
        self:SetCollapseArt(true)
    else
        self.content:Show()
        if f.NineSlice then f.NineSlice:Show() end
        if f.Bg then f.Bg:Show() end
        if f.TopTileStreaks then f.TopTileStreaks:Show() end
        if self.collapsedBg then self.collapsedBg:Hide() end
        f:SetHeight(s.height or 640)
        self:SetCollapseArt(false)
        self:Layout()
    end
    self:ApplyResizeSetting()
end

function UI:CreateSideTab()
    local t = CreateFrame("Button", "ProfessionShoppingListTab", UIParent, "BackdropTemplate")
    t:SetSize(30, 132)
    t:SetFrameStrata("HIGH")
    t:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
    AddBackdrop(t)
    t:Hide()
    self.tab = t

    local arrow = t:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(24, 24)
    arrow:SetPoint("TOP", 0, -6)
    arrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")

    local icon = t:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("TOP", arrow, "BOTTOM", 0, -4)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")

    local word = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    word:SetPoint("TOP", icon, "BOTTOM", 0, -6)
    word:SetText("L\nI\nS\nT")

    local hl = t:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 4, -4)
    hl:SetPoint("BOTTOMRIGHT", -4, 4)
    hl:SetColorTexture(1, 1, 1, 0.08)

    t:SetScript("OnClick", function() UI:SetSideCollapsed(false) end)
    t:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ns.TITLE)
        local total = ns:ComputeTotal()
        GameTooltip:AddDoubleLine("Shopping list total:", Money(total), 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddLine("Click to expand", 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function UI:SetSideCollapsed(v)
    ns.db.settings.sideCollapsed = v and true or false
    if v then
        self.frame:Hide()
        self.tab:Show()
    else
        self.tab:Hide()
        self.frame:Show()
    end
    self:ArrangePanels()
end

---------------------------------------------------------------------------
-- Profession picker
---------------------------------------------------------------------------
-- Profession spell IDs, used for the profession icons in the guide's grid
local PROFESSION_SPELLS = {
    ["Alchemy"] = 2259, ["Blacksmithing"] = 2018, ["Cooking"] = 2550, ["Enchanting"] = 7411,
    ["Engineering"] = 4036, ["First Aid"] = 3273, ["Fishing"] = 7620, ["Herbalism"] = 2366,
    ["Leatherworking"] = 2108, ["Mining"] = 2575, ["Skinning"] = 8613, ["Tailoring"] = 3908,
}
local GUIDE_PROFESSIONS = {
    "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering", "First Aid",
    "Fishing", "Herbalism", "Leatherworking", "Mining", "Skinning", "Tailoring",
}

local function ProfessionIcon(prof)
    local id = PROFESSION_SPELLS[prof]
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    if GetSpellTexture then return GetSpellTexture(id) end
end

-- Generic guide icon. Some icon files don't exist in WoW Forever, so try a
-- few and keep the first one the game can actually load.
local GUIDE_TAB_ICONS = {
    "Interface\\Icons\\INV_Misc_Book_11",
    "Interface\\Icons\\INV_Misc_Book_07",
    "Interface\\Icons\\INV_Misc_Book_03",
    "Interface\\Icons\\INV_Scroll_05",
    "Interface\\Icons\\INV_Misc_Book_09",
}
function UI:UpdateGuideTabIcon()
    if not self.guideTab then return end
    local probe = self.guideTab:CreateTexture(nil, "BACKGROUND")
    local chosen = GUIDE_TAB_ICONS[#GUIDE_TAB_ICONS]
    for _, path in ipairs(GUIDE_TAB_ICONS) do
        if probe:SetTexture(path) then chosen = path break end
    end
    probe:Hide()
    self.guideTab:SetNormalTexture(chosen)
end

function UI:SetProfession(prof)
    ns.db.settings.profession = prof
    if self.guide and self.guide:IsShown() then self:UpdateGuide() end
    self.matList.offset = 0
    self.matGrid.rowOffset = 0
    self:Refresh()
end

function UI:CycleProfession(dir)
    local profs = ns:GetProfessions()
    local idx = 1
    for i, p in ipairs(profs) do
        if p == ns.db.settings.profession then idx = i end
    end
    idx = ((idx - 1 + dir) % #profs) + 1
    self:SetProfession(profs[idx])
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------
function UI:CreateSettings()
    local s = CreatePanel("ProfessionShoppingListSettings", self.frame, "Settings")
    s:SetSize(260, 300)
    s:SetClampedToScreen(true)
    self:RegisterSidePanel(s)
    s:SetFrameStrata("DIALOG")
    s:Hide()
    s.PSLTitle:SetPoint("TOPLEFT", 14, -7)
    self.settings = s
    local st = ns.db.settings

    local cbAH = CheckBox(s, "Open with the auction house", function(v) st.openWithAH = v end)
    cbAH:SetPoint("TOPLEFT", 10, -TOP)
    local cbDock = CheckBox(s, "Attach to the auction house", function(v) st.attachToAH = v end)
    cbDock:SetPoint("TOPLEFT", cbAH, "BOTTOMLEFT", 0, 0)
    local cbMM = CheckBox(s, "Show minimap button", function(v)
        st.showMinimap = v
        ns.Minimap:UpdateVisibility()
    end)
    cbMM:SetPoint("TOPLEFT", cbDock, "BOTTOMLEFT", 0, 0)
    local cbResize = CheckBox(s, "Allow resizing the window", function(v)
        st.allowResize = v
        UI:ApplyResizeSetting()
    end)
    cbResize:SetPoint("TOPLEFT", cbMM, "BOTTOMLEFT", 0, 0)
    local beta = s:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    beta:SetPoint("TOPLEFT", cbResize.label, "BOTTOMLEFT", 0, -2)
    beta:SetText("|cffff9933Beta|r - may not work as intended")

    local lbl = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", cbResize, "BOTTOMLEFT", 6, -20)
    lbl:SetText("Background opacity")
    local val = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val:SetPoint("LEFT", lbl, "RIGHT", 8, 0)

    local sl = MakeSlider(s, 210, 0, 100, 5, function(v)
        val:SetText(v .. "%")
        st.bgAlpha = v / 100
        UI:ApplyAlpha()
    end)
    sl:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -8)
    local lo = s:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    lo:SetPoint("TOPLEFT", sl, "BOTTOMLEFT", 2, -2)
    lo:SetText("clear")
    local hi = s:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hi:SetPoint("TOPRIGHT", sl, "BOTTOMRIGHT", -2, -2)
    hi:SetText("solid")

    -- credits at the bottom
    -- sits just under the slider; the window height follows the text
    local credLine = s:CreateTexture(nil, "ARTWORK")
    credLine:SetHeight(1)
    credLine:SetPoint("TOPLEFT", lo, "BOTTOMLEFT", -4, -12)
    credLine:SetPoint("RIGHT", s, "RIGHT", -14, 0)
    credLine:SetColorTexture(0.85, 0.7, 0.25, 0.4)
    local author = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    author:SetPoint("TOPLEFT", credLine, "BOTTOMLEFT", 2, -10)
    author:SetText("|cffffd100Author:|r " .. ns.AUTHOR)
    local thanks = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    thanks:SetPoint("TOPLEFT", author, "BOTTOMLEFT", 0, -8)
    thanks:SetPoint("RIGHT", s, "RIGHT", -16, 0)
    thanks:SetJustifyH("LEFT")
    thanks:SetSpacing(3)
    thanks:SetText("|cffffd100Special thanks to|r Seeme || Pilanatesta |cffffd100for their feedback|r")
    s.creditsBottom = thanks

    s:SetScript("OnShow", function()
        cbAH:SetChecked(st.openWithAH)
        cbDock:SetChecked(st.attachToAH)
        cbMM:SetChecked(st.showMinimap)
        cbResize:SetChecked(st.allowResize)
        -- fit the window to its content once it has been positioned
        C_Timer.After(0, function()
            local top, bottom = s:GetTop(), thanks:GetBottom()
            if top and bottom then s:SetHeight(math.floor(top - bottom + 16)) end
        end)
        sl:SetValue((st.bgAlpha or 0.92) * 100)
    end)
end

function UI:ToggleSettings()
    if ns.db.settings.sideCollapsed then self:SetSideCollapsed(false) end
    if not self.frame:IsShown() then self.frame:Show() end
    self:TogglePanel(self.settings)
end

---------------------------------------------------------------------------
-- Side panels (settings, notes, release notes) open next to the window:
-- on the right by default, on the left when there isn't room on the right.
-- Several open panels stack under each other on the same side.
---------------------------------------------------------------------------
UI.sidePanels = {}

function UI:RegisterSidePanel(p)
    p:HookScript("OnHide", function()
        UI:ArrangePanels()
        UI:UpdateSideTabs()
    end)
    p:HookScript("OnShow", function() UI:UpdateSideTabs() end)
end

function UI:TogglePanel(p)
    if p:IsShown() then p:Hide() return end
    for i, q in ipairs(self.sidePanels) do
        if q == p then table.remove(self.sidePanels, i) break end
    end
    table.insert(self.sidePanels, p)
    p.userMoved = false
    p:Show()
    self:ArrangePanels()
end

function UI:ArrangePanels()
    local anchor
    if self.frame and self.frame:IsShown() then
        anchor = self.frame
    elseif self.tab and self.tab:IsShown() then
        anchor = self.tab
    end

    local visible, widest = {}, 0
    for _, p in ipairs(self.sidePanels) do
        if p:IsShown() and not p.userMoved then
            visible[#visible + 1] = p
            widest = math.max(widest, p:GetWidth())
        end
    end
    if #visible == 0 then return end

    local side = "right"
    local l, r = anchor and anchor:GetLeft(), anchor and anchor:GetRight()
    if l and r then
        local screenRight = UIParent:GetRight() or GetScreenWidth()
        local spaceRight, spaceLeft = screenRight - r, l
        if spaceRight < widest + 36 then
            if spaceLeft >= widest + 4 or spaceLeft > spaceRight then side = "left" end
        end
    end

    local prev
    for _, p in ipairs(visible) do
        p:ClearAllPoints()
        if prev then
            if side == "right" then
                p:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -4)
            else
                p:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -4)
            end
        elseif anchor then
            if side == "right" then
                -- leave room for the side tabs on the main window's right edge
                p:SetPoint("TOPLEFT", anchor, "TOPRIGHT", anchor == self.frame and 36 or 4, 0)
            else
                p:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -4, 0)
            end
        else
            p:SetPoint("CENTER")
        end
        prev = p
    end
end

---------------------------------------------------------------------------
-- Notes window (free text, saved)
---------------------------------------------------------------------------
function UI:CreateNotes()
    local n = CreatePanel("ProfessionShoppingListNotes", UIParent, "Notes")
    n:SetSize(300, 280)
    n:SetFrameStrata("HIGH")
    MakeMovable(n, "notesPos", function() n.userMoved = true end)
    self:RegisterSidePanel(n)
    n:Hide()
    n.PSLTitle:SetPoint("TOPLEFT", 14, -7)
    self.notes = n

    local hint = n:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetParent(n.PSLOverlay)
    hint:SetPoint("RIGHT", n.CloseButton, "LEFT", -4, 0)
    hint:SetText("saved automatically")

    local sf = CreateFrame("ScrollFrame", nil, n)
    sf:SetPoint("TOPLEFT", 14, -TOP)
    sf:SetPoint("BOTTOMRIGHT", -14, 40)
    DarkBg(sf)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.min(range, math.max(0, self:GetVerticalScroll() - delta * 20)))
    end)

    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(256)
    eb:SetMaxLetters(0)
    eb:SetTextInsets(4, 4, 4, 4)
    eb:SetText(ns.db.notes or "")
    -- faded placeholder shown while the notes are empty
    local ph = sf:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    ph:SetPoint("TOPLEFT", 8, -8)
    ph:SetPoint("TOPRIGHT", -8, -8)
    ph:SetJustifyH("LEFT")
    ph:SetJustifyV("TOP")
    ph:SetAlpha(0.6)
    ph:SetText("Use this space to write whatever you want, vent about your life, or make a Christmas list.")
    local function UpdatePlaceholder()
        ph:SetShown((eb:GetText() or "") == "" and not eb:HasFocus())
    end
    self.UpdateNotesPlaceholder = UpdatePlaceholder

    eb:SetScript("OnTextChanged", function(self)
        ns.db.notes = self:GetText()
        UpdatePlaceholder()
    end)
    eb:SetScript("OnEditFocusGained", UpdatePlaceholder)
    eb:SetScript("OnEditFocusLost", UpdatePlaceholder)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnCursorChanged", function(_, _, y, _, h)
        local vs, height = sf:GetVerticalScroll(), sf:GetHeight()
        y = -y
        if y < vs then
            sf:SetVerticalScroll(y)
        elseif y + h > vs + height then
            sf:SetVerticalScroll(y + h - height)
        end
    end)
    sf:SetScrollChild(eb)
    AttachFrameScrollbar(sf)
    self.notesEdit = eb
    UpdatePlaceholder()

    local clearNotes = MakeButton(n, "Clear", 80, 20)
    clearNotes:SetPoint("BOTTOMRIGHT", -14, 12)
    clearNotes:SetScript("OnClick", function()
        if (eb:GetText() or "") == "" then return end
        StaticPopup_Show("PROFESSIONSHOPPINGLIST_CLEAR_NOTES")
    end)
    sf:EnableMouse(true)
    sf:SetScript("OnMouseDown", function()
        eb:SetFocus()
        eb:SetCursorPosition(#(eb:GetText() or ""))
    end)
end

function UI:ClearNotes()
    ns.db.notes = ""
    if self.notesEdit then
        self.notesEdit:SetText("")
        self.notesEdit:ClearFocus()
        if self.UpdateNotesPlaceholder then self.UpdateNotesPlaceholder() end
    end
end

function UI:ToggleNotes()
    self:TogglePanel(self.notes)
end

---------------------------------------------------------------------------
-- Release notes window
---------------------------------------------------------------------------
local NOTE_KINDS = {
    { key = "added",   label = "Added",   color = "|cff40ff40", mark = "+" },
    { key = "changed", label = "Changed", color = "|cff69ccf0", mark = "*" },
    { key = "fixed",   label = "Fixed",   color = "|cffffd100", mark = "*" },
    { key = "removed", label = "Removed", color = "|cffff6060", mark = "-" },
}

local function BuildReleaseText()
    local out = {}
    for _, rel in ipairs(ns.RELEASE_NOTES or {}) do
        out[#out + 1] = "|cffffd100" .. rel.version .. "|r" .. (rel.date and ("  |cff9d9d9d" .. rel.date .. "|r") or "")
        for _, kind in ipairs(NOTE_KINDS) do
            local items = rel[kind.key]
            if items and #items > 0 then
                out[#out + 1] = "  " .. kind.color .. kind.label .. "|r"
                for _, line in ipairs(items) do
                    out[#out + 1] = "    " .. kind.color .. kind.mark .. "|r " .. line
                end
            end
        end
        out[#out + 1] = " "
    end
    return table.concat(out, "\n")
end

function UI:CreateReleaseNotes()
    local r = CreatePanel("ProfessionShoppingListReleaseNotes", UIParent, "Release notes  |cff9d9d9d" .. ns.VERSION .. "|r")
    r:SetSize(420, 460)
    r:SetFrameStrata("DIALOG")
    MakeMovable(r, "releasePos", function() r.userMoved = true end)
    self:RegisterSidePanel(r)
    r:Hide()
    r.PSLTitle:SetPoint("TOPLEFT", 14, -7)
    self.release = r

    local sf = CreateFrame("ScrollFrame", nil, r)
    sf:SetPoint("TOPLEFT", 16, -TOP)
    sf:SetPoint("BOTTOMRIGHT", -16, 16)
    DarkBg(sf)

    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(366, 10)
    local text = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 6, -6)
    text:SetWidth(352)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetSpacing(2)
    sf:SetScrollChild(child)
    AttachFrameScrollbar(sf)

    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.min(range, math.max(0, self:GetVerticalScroll() - delta * 30)))
    end)

    r:HookScript("OnShow", function()
        text:SetText(BuildReleaseText())
        child:SetHeight(text:GetStringHeight() + 12)
        sf:SetVerticalScroll(0)
    end)
end

function UI:ToggleReleaseNotes()
    self:TogglePanel(self.release)
end

---------------------------------------------------------------------------
-- Leveling guide panel
---------------------------------------------------------------------------
local function Intersect(lists)
    local count, out = {}, {}
    for _, l in ipairs(lists) do
        for _, v in ipairs(l) do count[v] = (count[v] or 0) + 1 end
    end
    for v, c in pairs(count) do
        if c == #lists then out[#out + 1] = v end
    end
    table.sort(out)
    return out
end

-- Skill breakpoints that exist on every route, so the range never depends on a route.
local function GuideBreakpoints(guide)
    if not guide.routes then return ns:GetGuideBreakpoints(guide, nil) end
    local lists = {}
    for _, r in ipairs(guide.routes) do lists[#lists + 1] = ns:GetGuideBreakpoints(guide, r.key) end
    return Intersect(lists)
end

local function PlanCost(mats)
    local total, missing = 0, 0
    for _, m in ipairs(mats) do
        local unit = ns:GetUnitPrice(m)
        if unit then total = total + unit * m.qty else missing = missing + 1 end
    end
    return total, missing
end

function UI:GuidePrefs(prof, guide)
    ns.db.guidePrefs[prof] = ns.db.guidePrefs[prof] or {}
    local p = ns.db.guidePrefs[prof]
    local bps = GuideBreakpoints(guide)
    if not p.from or not tContains(bps, p.from) then p.from = bps[1] end
    if not p.to or not tContains(bps, p.to) or p.to <= p.from then p.to = bps[#bps] end
    return p, bps
end

-- Picks the route automatically: the cheapest one once every material has a
-- price, otherwise the guide's first (recommended) route.
function UI:CurrentPlan()
    local prof = self.guideProf or ns.db.settings.profession
    local guide = ns.LevelingGuides[prof]
    if not guide then return prof end
    local p = self:GuidePrefs(prof, guide)
    if not guide.routes then
        local steps, mats = ns:ComputePlan(guide, nil, p.from, p.to)
        return prof, guide, p, steps, mats
    end
    local best
    for i, r in ipairs(guide.routes) do
        local steps, mats = ns:ComputePlan(guide, r.key, p.from, p.to)
        local cost, missing = PlanCost(mats)
        local cand = { route = r, steps = steps, mats = mats, cost = cost, missing = missing }
        if i == 1 then
            best = cand
        elseif missing == 0 and best.missing == 0 and cost < best.cost then
            best = cand
        end
    end
    return prof, guide, p, best.steps, best.mats, best.route
end

function UI:CreateGuide()
    local g = CreatePanel("ProfessionShoppingListGuide", UIParent, "Leveling Guide")
    g:SetSize(370, 470)
    g:SetFrameStrata("HIGH")
    MakeMovable(g, "guidePos", function() g.userMoved = true end)
    self:RegisterSidePanel(g)
    g:Hide()
    g.PSLTitle:SetPoint("TOPLEFT", 14, -7)
    self.guide = g

    local prof = g:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    prof:SetPoint("TOPLEFT", 16, -TOP)
    g.profLabel = prof

    local rangeLbl = g:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rangeLbl:SetPoint("TOPLEFT", 16, -TOP - 28)
    rangeLbl:SetText("Skill:")
    local fromBtn = MakeButton(g, "", 70, 20)
    fromBtn:SetPoint("LEFT", rangeLbl, "RIGHT", 8, 0)
    local toLbl = g:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    toLbl:SetPoint("LEFT", fromBtn, "RIGHT", 6, 0)
    toLbl:SetText("to")
    local toBtn = MakeButton(g, "", 70, 20)
    toBtn:SetPoint("LEFT", toLbl, "RIGHT", 6, 0)
    g.rangeLbl, g.fromBtn, g.toLbl, g.toBtn = rangeLbl, fromBtn, toLbl, toBtn

    -- dark box: scrolling steps/materials on top, estimated cost pinned to the bottom
    local box = CreateFrame("Frame", nil, g)
    box:SetPoint("TOPLEFT", 16, -TOP - 56)
    box:SetPoint("TOPRIGHT", -16, -TOP - 56)
    box:SetHeight(200)
    DarkBg(box)
    g.box = box

    local cost = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cost:SetPoint("BOTTOMLEFT", 8, 8)
    cost:SetJustifyH("LEFT")
    g.cost = cost
    local costNote = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    costNote:SetPoint("BOTTOMLEFT", cost, "TOPLEFT", 0, 3)
    costNote:SetPoint("RIGHT", box, "RIGHT", -8, 0)
    costNote:SetJustifyH("LEFT")
    g.costNote = costNote
    local costLine = box:CreateTexture(nil, "ARTWORK")
    costLine:SetHeight(1)
    costLine:SetPoint("BOTTOMLEFT", 6, 44)
    costLine:SetPoint("BOTTOMRIGHT", -6, 44)
    costLine:SetColorTexture(1, 1, 1, 0.12)

    local sf = CreateFrame("ScrollFrame", nil, box)
    sf:SetPoint("TOPLEFT", 0, 0)
    sf:SetPoint("BOTTOMRIGHT", 0, 46)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(322, 10)
    local text = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 6, -6)
    text:SetWidth(312)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetSpacing(2)
    sf:SetScrollChild(child)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.min(range, math.max(0, self:GetVerticalScroll() - delta * 30)))
    end)
    g.scroll, g.child, g.text = sf, child, text
    AttachFrameScrollbar(sf)

    local note = g:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("BOTTOMLEFT", 16, 62)
    note:SetPoint("BOTTOMRIGHT", -16, 62)
    note:SetJustifyH("LEFT")
    note:SetJustifyV("BOTTOM")
    g.note = note

    -- credit: clickable site name opens the link dialog
    local srcLbl = g:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    srcLbl:SetPoint("BOTTOMLEFT", 16, 42)
    srcLbl:SetText("Source:")
    local src = CreateFrame("Button", nil, g)
    src:SetPoint("LEFT", srcLbl, "RIGHT", 4, 0)
    local srcText = src:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    srcText:SetPoint("LEFT")
    srcText:SetText("|cff69ccf0" .. ns.GUIDE_SOURCE .. "|r")
    src:SetSize(srcText:GetStringWidth() + 2, 16)
    src:SetScript("OnEnter", function(self)
        srcText:SetText("|cffa0e0ff" .. ns.GUIDE_SOURCE .. "|r")
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Open the guide link")
        GameTooltip:Show()
    end)
    src:SetScript("OnLeave", function()
        srcText:SetText("|cff69ccf0" .. ns.GUIDE_SOURCE .. "|r")
        GameTooltip:Hide()
    end)
    src:SetScript("OnClick", function()
        local _, guide = UI:CurrentPlan()
        UI:ShowLinkDialog(guide and guide.url or ("https://www." .. ns.GUIDE_SOURCE))
    end)
    g.src, g.srcLbl = src, srcLbl

    local share = MakeButton(g, "Share list", 110, 22)
    share:SetPoint("BOTTOMRIGHT", -16, 14)
    share:SetScript("OnClick", function() StaticPopup_Show("PROFESSIONSHOPPINGLIST_SHARE_GUIDE") end)
    local add = MakeButton(g, "Add to list", 110, 22)
    add:SetPoint("RIGHT", share, "LEFT", -6, 0)
    add:SetScript("OnClick", function()
        if #ns.db.list > 0 then
            UI:ShowAddGuideDialog()
        else
            UI:ApplyGuide(false)
        end
    end)
    g.addBtn, g.shareBtn = add, share

    local back = MakeButton(g, "< Back", 70, 20)
    back:SetPoint("TOPRIGHT", -16, -TOP + 2)
    back:SetScript("OnClick", function() UI.guideProf = nil UI:UpdateGuide() end)
    g.backBtn = back

    g.planWidgets = { g.profLabel, g.rangeLbl, g.fromBtn, g.toLbl, g.toBtn, g.box, g.note,
                      g.srcLbl, g.src, g.addBtn, g.shareBtn, g.backBtn }

    -- Profession grid (first screen)
    local grid = CreateFrame("Frame", nil, g)
    grid:SetPoint("TOPLEFT", 16, -TOP)
    grid:SetPoint("BOTTOMRIGHT", -16, 16)
    g.grid = grid
    local gh = grid:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gh:SetPoint("TOPLEFT", 0, -70)
    gh:SetText("Choose a profession")
    local gsub = grid:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    gsub:SetPoint("LEFT", gh, "RIGHT", 8, 0)
    gsub:SetText("Source: " .. ns.GUIDE_SOURCE)

    local area = CreateFrame("Frame", nil, grid)
    area:SetPoint("TOPLEFT", 0, -92)
    area:SetPoint("BOTTOMRIGHT", 0, 0)
    DarkBg(area)

    local COLS, CELL_H = 3, 88
    local cellW = (370 - 32) / COLS
    for i, prof in ipairs(GUIDE_PROFESSIONS) do
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        local c = CreateFrame("Button", nil, area)
        c:SetSize(cellW, CELL_H)
        c:SetPoint("TOPLEFT", col * cellW, -6 - row * CELL_H)
        local hl = c:CreateTexture(nil, "HIGHLIGHT")
        hl:SetPoint("TOPLEFT", 4, -2)
        hl:SetPoint("BOTTOMRIGHT", -4, 2)
        hl:SetColorTexture(1, 1, 1, 0.08)

        local icon = c:CreateTexture(nil, "ARTWORK")
        icon:SetSize(38, 38)
        icon:SetPoint("TOP", 0, -8)
        icon:SetTexture(ProfessionIcon(prof) or "Interface\\Icons\\INV_Misc_QuestionMark")

        local name = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        name:SetPoint("TOP", icon, "BOTTOM", 0, -4)
        name:SetText(prof)

        local status = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        status:SetPoint("TOP", name, "BOTTOM", 0, -2)

        local ready = ns.LevelingGuides[prof] ~= nil
        if ready then
            local lo, hi = ns:GetGuideRange(ns.LevelingGuides[prof])
            status:SetText("|cffffd100" .. lo .. " to " .. hi .. "|r")
        else
            icon:SetDesaturated(true)
            icon:SetAlpha(0.6)
            name:SetText("|cff9d9d9d" .. prof .. "|r")
            status:SetText("Coming soon")
        end

        c:SetScript("OnClick", function()
            if ns.LevelingGuides[prof] then
                UI.guideProf = prof
                UI:UpdateGuide()
            end
        end)
        c:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(prof)
            if ns.LevelingGuides[prof] then
                GameTooltip:AddLine("Click to open the leveling guide", 0.5, 0.8, 1)
            else
                GameTooltip:AddLine("Coming soon", 0.6, 0.6, 0.6)
            end
            GameTooltip:Show()
        end)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- "Your professions": one skill bar per primary profession
    local mine = CreateFrame("Frame", nil, grid)
    mine:SetPoint("TOPLEFT", 0, 0)
    mine:SetPoint("TOPRIGHT", 0, 0)
    mine:SetHeight(66)
    local mh = mine:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mh:SetPoint("TOPLEFT", 0, 0)
    mh:SetText("Your professions")

    local check = MakeButton(mine, "Check for updates", 130, 20)
    check:SetPoint("TOPRIGHT", 0, 3)
    check:SetScript("OnClick", function() UI:ShowGuideCheck() end)
    check:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Check if the guides are outdated")
        GameTooltip:AddLine("Compares the guides with your game version and with the recipes in your profession windows.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    check:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local none = mine:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    none:SetPoint("TOPLEFT", 0, -24)
    none:SetText("You haven't learned a profession yet.")
    g.profNone = none
    g.profBars = {}
    for i = 1, 2 do
        local b = CreateFrame("Button", nil, mine)
        b:SetHeight(20)
        b:SetPoint("TOPLEFT", 0, -18 - (i - 1) * 24)
        b:SetPoint("TOPRIGHT", 0, -18 - (i - 1) * 24)

        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(18, 18)
        b.icon:SetPoint("LEFT", 0, 0)

        -- skill bar in the style of the character Skills tab
        local frame = CreateFrame("Frame", nil, b, "BackdropTemplate")
        frame:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
        frame:SetPoint("RIGHT", b, "RIGHT", 0, 0)
        frame:SetHeight(18)
        if frame.SetBackdrop then
            frame:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 8, edgeSize = 8,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            frame:SetBackdropColor(0, 0, 0, 0.7)
            frame:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
        end
        local bar = CreateFrame("StatusBar", nil, frame)
        bar:SetPoint("TOPLEFT", 3, -3)
        bar:SetPoint("BOTTOMRIGHT", -3, 3)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetStatusBarColor(0.0, 0.33, 0.8)
        bar:SetMinMaxValues(0, 1)
        b.bar = bar

        b.name = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.name:SetPoint("LEFT", 6, 0)
        b.value = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.value:SetPoint("RIGHT", -6, 0)

        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(frame)
        hl:SetColorTexture(1, 1, 1, 0.08)

        b:SetScript("OnClick", function(self)
            if self.prof and ns.LevelingGuides[self.prof.name] then
                UI.guideProf = self.prof.name
                UI:UpdateGuide()
            end
        end)
        b:SetScript("OnEnter", function(self)
            local p = self.prof
            if not p then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(p.name)
            GameTooltip:AddDoubleLine("Skill:", p.rank .. " / " .. p.max, 1, 0.82, 0, 1, 1, 1)
            if (p.bonus or 0) > 0 then
                GameTooltip:AddDoubleLine("Bonus:", "+" .. p.bonus, 1, 0.82, 0, 0.25, 1, 0.25)
            end
            if ns.LevelingGuides[p.name] then
                GameTooltip:AddLine("Click to open the leveling guide", 0.5, 0.8, 1)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        g.profBars[i] = b
    end

    -- keep the bars live while the window is open
    local watcher = CreateFrame("Frame", nil, g)
    for _, ev in ipairs({ "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "TRADE_SKILL_LIST_UPDATE" }) do
        pcall(watcher.RegisterEvent, watcher, ev)
    end
    watcher:SetScript("OnEvent", function()
        if g:IsShown() and UI.guideProf == nil then UI:UpdateProfessionBars() end
    end)

    -- always open on the profession grid
    g:HookScript("OnShow", function()
        UI.guideProf = nil
        UI:UpdateGuide()
    end)
end

function UI:UpdateProfessionBars()
    local g = self.guide
    if not g or not g.profBars then return end
    local ok, profs = pcall(ns.GetPrimaryProfessions, ns)
    if not ok then profs = {} end
    for i, b in ipairs(g.profBars) do
        local p = profs[i]
        b.prof = p
        if p then
            b.icon:SetTexture(p.icon or ProfessionIcon(p.name) or "Interface\\Icons\\INV_Misc_QuestionMark")
            b.bar:SetMinMaxValues(0, math.max(1, p.max))
            b.bar:SetValue(p.rank)
            b.name:SetText(p.name)
            local val = p.rank .. " / " .. p.max
            if (p.bonus or 0) > 0 then val = val .. " |cff40ff40(+" .. p.bonus .. ")|r" end
            b.value:SetText(val)
            b:Show()
        else
            b:Hide()
        end
    end
    g.profNone:SetShown(#profs == 0)
end

function UI:UpdateGuide()
    local g = self.guide
    if not g then return end
    local onGrid = self.guideProf == nil
    g.grid:SetShown(onGrid)
    for _, w in ipairs(g.planWidgets) do w:SetShown(not onGrid) end
    if onGrid then
        self:UpdateProfessionBars()
        g:SetHeight(510)
        return
    end
    local prof, guide, p, steps, mats, route = self:CurrentPlan()
    g.profLabel:SetText(prof)

    local has = guide ~= nil
    for _, w in ipairs({ g.rangeLbl, g.fromBtn, g.toLbl, g.toBtn, g.addBtn, g.shareBtn }) do w:SetShown(has) end

    if not has then
        self:RenderGuideRows({})
        g.text:SetText("No leveling guide for " .. prof .. " yet.\n\nPick another profession in the main window.")
        g.note:SetText("")
        g.cost:SetText("")
        g.costNote:SetText("")
        g.child:SetHeight(g.text:GetStringHeight() + 12)
        return
    end
    g.note:SetText(guide.note or "")

    -- range pickers
    local bps = GuideBreakpoints(guide)
    g.fromBtn:SetText(p.from .. "  v")
    g.toBtn:SetText(p.to .. "  v")
    g.fromBtn:SetScript("OnClick", function(btn)
        local items = {}
        for _, v in ipairs(bps) do if v < p.to then items[#items + 1] = { value = v, text = tostring(v) } end end
        UI:ShowMenu(btn, items, p.from, function(v) p.from = v; UI:UpdateGuide() end)
    end)
    g.toBtn:SetScript("OnClick", function(btn)
        local items = {}
        for _, v in ipairs(bps) do if v > p.from then items[#items + 1] = { value = v, text = tostring(v) } end end
        UI:ShowMenu(btn, items, p.to, function(v) p.to = v; UI:UpdateGuide() end)
    end)

    -- steps + materials, in aligned columns
    g.text:SetText("")
    local rows = { { header = "Steps", c1 = "Crafts" } }
    for _, st in ipairs(steps) do
        rows[#rows + 1] = {
            left = string.format("|cff9d9d9d%d-%d|r  %s", st.from, st.to, st.recipe),
            c1 = "x" .. st.crafts,
        }
    end
    rows[#rows + 1] = { spacer = true }
    rows[#rows + 1] = { header = "Materials to buy", c1 = "Qty", c2 = "Price" }
    for _, m in ipairs(mats) do
        local unit = ns:GetUnitPrice(m)
        local name = m.name
        if ns:GetSource(m) == "vendor" then name = name .. "  |cff69ccf0vendor|r" end
        rows[#rows + 1] = {
            left = name,
            c1 = "x" .. m.qty,
            c2 = unit and Money(unit * m.qty) or "|cff808080not priced|r",
        }
    end
    self:RenderGuideRows(rows)

    -- estimated cost, pinned to the bottom of the box
    local total, missing = PlanCost(mats)
    g.cost:SetText("Estimated cost: " .. MoneyFull(total))
    local notes = {}
    if missing > 0 then notes[#notes + 1] = missing .. " item(s) not priced yet - add them to your list and Scan." end
    if route and guide.routes then
        -- only mention the route when the chosen range actually differs between routes
        local differs = false
        for _, st in ipairs(steps) do if st.route then differs = true end end
        if differs then notes[#notes + 1] = "Using: " .. route.text .. (missing == 0 and " (cheapest)" or "") end
    end
    g.costNote:SetText(table.concat(notes, "  "))

    self:FitGuide()
end

-- Sizes the guide window to its content. From the bottom up, the fixed part is:
-- buttons (14-36), source line (42-54), the guide note (from 62, any height),
-- then a 10px gap. The grey box above grows with the steps/materials.
local GUIDE_BOX_MIN, GUIDE_BOX_MAX = 150, 380
function UI:FitGuide()
    local g = self.guide
    local noteH = math.ceil(g.note:GetStringHeight() or 0)
    local bottomPart = 62 + noteH + 10
    local boxH = math.ceil(g.child:GetHeight() + 46 + 4)
    boxH = math.max(GUIDE_BOX_MIN, math.min(GUIDE_BOX_MAX, boxH))
    g.box:SetHeight(boxH)
    g:SetHeight(TOP + 56 + boxH + bottomPart)
end

-- Draws rows into the guide's scroll area: name on the left, then two
-- right-aligned columns (crafts / quantity, and price).
local GUIDE_ROW_H, GUIDE_C1_W, GUIDE_C2_W = 15, 44, 86
function UI:RenderGuideRows(rows)
    local g = self.guide
    g.rows = g.rows or {}
    local width = g.child:GetWidth()
    local y = -6
    local used = 0
    for i, row in ipairs(rows) do
        local r = g.rows[i]
        if not r then
            r = {}
            r.left = g.child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.left:SetJustifyH("LEFT")
            r.left:SetWordWrap(false)
            r.c2 = g.child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.c2:SetJustifyH("RIGHT")
            r.c2:SetWidth(GUIDE_C2_W)
            r.c1 = g.child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.c1:SetJustifyH("RIGHT")
            r.c1:SetWidth(GUIDE_C1_W)
            g.rows[i] = r
        end
        used = i
        for _, fs in ipairs({ r.left, r.c1, r.c2 }) do fs:ClearAllPoints() fs:SetText("") fs:Show() end
        if row.spacer then
            y = y - 8
        else
            r.c2:SetPoint("TOPRIGHT", g.child, "TOPLEFT", width - 6, y)
            r.c1:SetPoint("TOPRIGHT", g.child, "TOPLEFT", width - 6 - GUIDE_C2_W - 6, y)
            r.left:SetPoint("TOPLEFT", g.child, "TOPLEFT", row.header and 6 or 12, y)
            r.left:SetPoint("RIGHT", r.c1, "LEFT", -6, 0)
            if row.header then
                r.left:SetText("|cffffd100" .. row.header .. "|r")
                r.c1:SetText(row.c1 and ("|cffffd100" .. row.c1 .. "|r") or "")
                r.c2:SetText(row.c2 and ("|cffffd100" .. row.c2 .. "|r") or "")
            else
                r.left:SetText(row.left or "")
                r.c1:SetText(row.c1 and ("|cffaaaaaa" .. row.c1 .. "|r") or "")
                r.c2:SetText(row.c2 or "")
            end
            y = y - GUIDE_ROW_H
        end
    end
    for i = used + 1, #g.rows do
        local r = g.rows[i]
        r.left:Hide() r.c1:Hide() r.c2:Hide()
    end
    g.child:SetHeight(math.max(10, -y + 6))
end

-- Text version of the current plan, used by "Share list".
function UI:GuideShareLines()
    local prof, guide, p, steps, mats = self:CurrentPlan()
    if not guide then return nil end
    local lines = { string.format("[Shopping List] %s %d-%d (source: %s)", prof, p.from, p.to, ns.GUIDE_SOURCE) }
    lines[#lines + 1] = "Steps:"
    for _, st in ipairs(steps) do
        lines[#lines + 1] = string.format("  %d-%d: %s x%d", st.from, st.to, st.recipe, st.crafts)
    end
    lines[#lines + 1] = "Materials to buy:"
    for _, m in ipairs(mats) do
        lines[#lines + 1] = string.format("  %s x%d", m.name, m.qty)
    end
    local total, missing = PlanCost(mats)
    if total > 0 then
        local g, sv, c = math.floor(total / 10000), math.floor((total % 10000) / 100), total % 100
        lines[#lines + 1] = string.format("Estimated cost: %dg %02ds %02dc%s", g, sv, c, missing > 0 and " (some items not priced)" or "")
    end
    return lines
end

-- Sends the plan as whispers, one line at a time, spaced out to avoid chat throttling.
function UI:ShareGuide(target)
    target = (target or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if target == "" then return end
    local lines = self:GuideShareLines()
    if not lines then return end
    for i, line in ipairs(lines) do
        C_Timer.After((i - 1) * 0.35, function()
            SendChatMessage(line:sub(1, 250), "WHISPER", nil, target)
        end)
    end
    ns.Print("Sharing the leveling list with " .. target .. " (" .. #lines .. " lines).")
end

---------------------------------------------------------------------------
-- Link dialog (WoW can't open web pages, so the link is shown for copying)
---------------------------------------------------------------------------
-- Asked when "Add to list" is pressed while the shopping list already has items.
function UI:ShowAddGuideDialog()
    local d = self.addDialog
    if not d then
        d = CreatePanel("ProfessionShoppingListAddGuide", UIParent, "Leveling Guide")
        d:SetSize(440, 130)
        d:SetFrameStrata("FULLSCREEN_DIALOG")
        d:SetPoint("CENTER", 0, 120)
        MakeMovable(d, "addDialogPos")
        d.PSLTitle:SetPoint("TOPLEFT", 14, -7)
        self.addDialog = d

        local msg = d:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        msg:SetPoint("TOP", 0, -TOP - 6)
        msg:SetText("You are about to add additional items to your existing list!")

        local addMore = MakeButton(d, "Add more", 110, 22)
        local clear = MakeButton(d, "Clear current shopping list", 190, 22)
        local cancel = MakeButton(d, "Cancel", 90, 22)
        -- the three buttons are laid out as one group centred in the popup
        local gap = 6
        local groupW = addMore:GetWidth() + clear:GetWidth() + cancel:GetWidth() + gap * 2
        addMore:SetPoint("BOTTOMLEFT", d, "BOTTOM", -groupW / 2, 16)
        clear:SetPoint("LEFT", addMore, "RIGHT", gap, 0)
        cancel:SetPoint("LEFT", clear, "RIGHT", gap, 0)

        addMore:SetScript("OnClick", function() d:Hide() UI:ApplyGuide(false) end)
        clear:SetScript("OnClick", function() d:Hide() UI:ApplyGuide(true) end)
        cancel:SetScript("OnClick", function() d:Hide() end)

        -- Escape closes it like Cancel
        tinsert(UISpecialFrames, "ProfessionShoppingListAddGuide")
    end
    d:Show()
end

-- Report window for "Check for updates"
function UI:ShowGuideCheck()
    local d = self.checkDialog
    if not d then
        d = CreatePanel("ProfessionShoppingListGuideCheck", UIParent, "Guide check")
        d:SetSize(400, 430)
        d:SetFrameStrata("DIALOG")
        d:SetPoint("CENTER")
        MakeMovable(d, "checkPos")
        d.PSLTitle:SetPoint("TOPLEFT", 14, -7)
        tinsert(UISpecialFrames, "ProfessionShoppingListGuideCheck")
        self.checkDialog = d

        local sf = CreateFrame("ScrollFrame", nil, d)
        sf:SetPoint("TOPLEFT", 16, -TOP)
        sf:SetPoint("BOTTOMRIGHT", -16, 48)
        DarkBg(sf)
        local child = CreateFrame("Frame", nil, sf)
        child:SetSize(354, 10)
        local text = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("TOPLEFT", 8, -8)
        text:SetWidth(338)
        text:SetJustifyH("LEFT")
        text:SetJustifyV("TOP")
        text:SetSpacing(3)
        sf:SetScrollChild(child)
        sf:EnableMouseWheel(true)
        sf:SetScript("OnMouseWheel", function(self, delta)
            local range = self:GetVerticalScrollRange() or 0
            self:SetVerticalScroll(math.min(range, math.max(0, self:GetVerticalScroll() - delta * 30)))
        end)
        AttachFrameScrollbar(sf)
        d.sf, d.child, d.text = sf, child, text

        local close = MakeButton(d, "Close", 90, 22)
        close:SetPoint("BOTTOMRIGHT", -16, 14)
        close:SetScript("OnClick", function() d:Hide() end)
        local site = MakeButton(d, "Latest guides online", 150, 22)
        site:SetPoint("RIGHT", close, "LEFT", -6, 0)
        site:SetScript("OnClick", function() UI:ShowLinkDialog(ns.GUIDE_HOME) end)
    end

    local rep = ns:CheckGuides()
    local GREEN, YELLOW, RED, GREY, GOLD = "|cff40ff40", "|cffffff00", "|cffff5050", "|cff9d9d9d", "|cffffd100"
    local out = {}
    out[#out + 1] = GOLD .. "Guide data|r"
    out[#out + 1] = "  Copied from " .. ns.GUIDE_SOURCE .. " on " .. ns.GUIDE_DATA.date
        .. " (" .. ns.GUIDE_DATA.note .. " " .. ns.GUIDE_DATA.gameVersion .. ")"
    out[#out + 1] = "  Your game: " .. tostring(rep.version) .. " (build " .. tostring(rep.build) .. ")"
    if rep.versionMatches then
        out[#out + 1] = "  " .. GREEN .. "Same game version as the guides.|r"
    else
        out[#out + 1] = "  " .. YELLOW .. "The game has been updated since the guides were made - recipes may have changed.|r"
    end
    out[#out + 1] = " "
    out[#out + 1] = GOLD .. "Recipes compared with your game|r"
    local outdated, unchecked = 0, 0
    for _, p in ipairs(rep.professions) do
        if not p.snap then
            unchecked = unchecked + 1
            out[#out + 1] = "  " .. GREY .. p.name .. ": not checked - open your " .. p.name .. " window once.|r"
        elseif #p.changes == 0 then
            local line = "  " .. GREEN .. p.name .. ": " .. p.checked .. " recipe(s) match.|r"
            if p.unknown > 0 then line = line .. GREY .. " (" .. p.unknown .. " not learned yet)|r" end
            out[#out + 1] = line
        else
            outdated = outdated + 1
            out[#out + 1] = "  " .. RED .. p.name .. ": " .. #p.changes .. " recipe(s) changed - guide may be outdated.|r"
            for _, c in ipairs(p.changes) do
                out[#out + 1] = "     " .. c.recipe
                for _, diff in ipairs(c.diffs) do
                    out[#out + 1] = "        " .. GREY .. diff .. "|r"
                end
            end
        end
    end
    out[#out + 1] = " "
    if outdated > 0 then
        out[#out + 1] = RED .. "Some guides look outdated.|r Check " .. ns.GUIDE_SOURCE .. " and look for an addon update."
    elseif not rep.versionMatches then
        out[#out + 1] = YELLOW .. "No recipe changes found so far, but the game version changed.|r Open your profession windows to check more recipes."
    else
        out[#out + 1] = GREEN .. "Everything checked is up to date.|r"
    end
    if unchecked > 0 then
        out[#out + 1] = GREY .. "Only recipes you have learned can be checked. The addon can't go online, "
            .. "so new guide versions on the website aren't detected here.|r"
    end

    d.text:SetText(table.concat(out, "\n"))
    d.child:SetHeight(d.text:GetStringHeight() + 16)
    d.sf:SetVerticalScroll(0)
    d:Show()
end

function UI:ShowLinkDialog(url)
    local d = self.linkDialog
    if not d then
        d = CreatePanel("ProfessionShoppingListLink", UIParent, "Open link")
        d:SetSize(360, 140)
        d:SetFrameStrata("FULLSCREEN_DIALOG")
        d:SetPoint("CENTER")
        MakeMovable(d, "linkPos")
        d.PSLTitle:SetPoint("TOPLEFT", 14, -7)
        self.linkDialog = d

        local msg = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        msg:SetPoint("TOPLEFT", 16, -TOP)
        msg:SetPoint("TOPRIGHT", -16, -TOP)
        msg:SetJustifyH("LEFT")
        msg:SetText("Open this page in your web browser:")
        d.msg = msg

        local eb = CreateFrame("EditBox", nil, d, "InputBoxTemplate")
        eb:SetSize(320, 20)
        eb:SetPoint("TOPLEFT", 22, -TOP - 20)
        eb:SetAutoFocus(false)
        eb:SetScript("OnTextChanged", function(self, user)
            if user then self:SetText(d.url or "") self:HighlightText() end
        end)
        eb:SetScript("OnEscapePressed", function() d:Hide() end)
        eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        d.eb = eb

        local close = MakeButton(d, "Close", 100, 22)
        close:SetPoint("BOTTOMRIGHT", -16, 14)
        close:SetScript("OnClick", function() d:Hide() end)
        local copy = MakeButton(d, "Copy URL", 100, 22)
        copy:SetPoint("RIGHT", close, "LEFT", -6, 0)
        copy:SetScript("OnClick", function()
            -- addons can't write to the clipboard, so select the text for Ctrl+C
            eb:SetFocus()
            eb:HighlightText()
            d.msg:SetText("|cff40ff40Selected - now press Ctrl+C to copy.|r")
        end)
    end
    d.url = url
    d.msg:SetText("Open this page in your web browser:")
    d.eb:SetText(url)
    d.eb:SetCursorPosition(0)
    d:Show()
end

function UI:ApplyGuide(replace)
    local prof, guide, p, _, mats = self:CurrentPlan()
    if not guide then return end
    if replace then wipe(ns.db.list) end
    for _, m in ipairs(mats) do
        ns:LearnMaterial(prof, m.name, m.id)
        ns:AddToList(m.name, m.id, m.qty)
    end
    ns:RebuildKnown()
    ns:RequestRefresh()
    ns.Print(string.format("%s %d-%d: added %d material(s) to your shopping list.", prof, p.from, p.to, #mats))
end

function UI:ToggleGuide()
    if ns.db.settings.sideCollapsed then self:SetSideCollapsed(false) end
    if not self.frame:IsShown() then self.frame:Show() end
    self:TogglePanel(self.guide)
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------
local function SourceText(v)
    for _, item in ipairs(SOURCES) do
        if item.value == v then return item.text end
    end
    return "All sources"
end

function UI:Refresh()
    local f = self.frame
    if not f or not f:IsShown() or ns.db.settings.collapsed then return end
    local s = ns.db.settings
    self.profBtn:SetText(s.profession .. "  v")
    self.srcBtn:SetText(SourceText(s.sourceFilter) .. "  v")

    local mats = ns:GetMaterials(s.profession)
    local filter = self.filterText
    local src = s.sourceFilter or "all"
    if (filter and filter ~= "") or src ~= "all" then
        local filtered = {}
        for _, e in ipairs(mats) do
            local okText = not filter or filter == "" or e.name:lower():find(filter, 1, true)
            local okSrc = src == "all" or ns:GetSource(e) == src
            if okText and okSrc then filtered[#filtered + 1] = e end
        end
        mats = filtered
    end
    local emptyText = (src ~= "all" or (filter and filter ~= ""))
        and "Nothing matches this filter."
        or "No materials. Open your profession window to learn them."

    local grid = (s.viewMode == "grid")
    self.viewBtn:SetText(grid and "List view" or "Grid view")
    self.sizeSlider:SetShown(grid)
    self.sizeLabel:SetShown(grid)
    if grid then
        self.sizeSlider:SetValue(s.iconSize or 40)
        self.matList:Hide()
        self.matGrid:Show()
        self.matGrid:SetData(mats, emptyText)
    else
        self.matGrid:Hide()
        self.matList:Show()
        self.matList:SetData(mats, emptyText)
    end
    self.shopList:SetData(ns.db.list, "Click materials from the list above, or drag items from your bag to here.")

    -- Totals vs. the gold you have
    local total, missing = ns:ComputeTotal()
    local money = GetMoney()
    if total > money then
        -- whole amount turns red when you can't afford it
        local g = math.floor(total / 10000)
        local sv = math.floor((total % 10000) / 100)
        self.totalLabel:SetText(string.format("Total: |cffff3333%dg %02ds %02dc|r", g, sv, total % 100))
    else
        self.totalLabel:SetText("Total: " .. MoneyFull(total))
    end
    self.haveLabel:SetText("|cffffd100You have:|r " .. MoneyFull(money))
    local after = money - total
    if after >= 0 then
        self.afterLabel:SetText("|cffffd100After buying:|r " .. MoneyFull(after))
    else
        self.afterLabel:SetText("|cffff3333Short by:|r " .. MoneyFull(-after))
    end

    if #ns.db.list == 0 then
        self.missingLabel:SetText("")
    elseif missing > 0 then
        self.missingLabel:SetText(missing .. " item(s) have no price yet - open the AH and press Scan list.")
    else
        self.missingLabel:SetText("All items priced.")
    end

    -- size the totals block to its visible lines so it sits centred
    local h = self.totalLabel:GetStringHeight() + 5 + self.haveLabel:GetStringHeight()
            + 3 + self.afterLabel:GetStringHeight()
    if (self.missingLabel:GetText() or "") ~= "" then h = h + 4 + self.missingLabel:GetStringHeight() end
    self.totalsBlock:SetHeight(math.max(1, h))

    self.subtractCheck:SetChecked(s.subtractOwned)
    if self.guide and self.guide:IsShown() then self:UpdateGuide() end
    if #ns.db.list > 0 then self.clearListBtn:Enable() else self.clearListBtn:Disable() end
    self:UpdateTimers()
end

-- Cheap update that runs every half second while the window is open.
function UI:UpdateTimers()
    if not self.lastScanLabel then return end
    local ls = ns.db.lastScan[ns.realmKey]
    if ls then
        self.lastScanLabel:SetText("Last scan: " .. date("%d %b %H:%M", ls) .. "  |cff9d9d9d(" .. Ago(ls) .. ")|r")
    else
        self.lastScanLabel:SetText("Last scan: |cff9d9d9dnever|r")
    end

    local A = ns.Auction
    local cd = A:CooldownLeft()
    if A.scanning then
        self.scanBtn:SetText("Stop scan")
        self.scanBtn:Enable()
    elseif cd > 0 then
        self.scanBtn:SetText("Scan list (" .. cd .. ")")
        self.scanBtn:Disable()
    else
        self.scanBtn:SetText("Scan list")
        if ns.ahOpen then self.scanBtn:Enable() else self.scanBtn:Disable() end
    end
end

---------------------------------------------------------------------------
-- Show / hide / docking
---------------------------------------------------------------------------
function UI:ShowWindow()
    if ns.db.settings.sideCollapsed then
        self.frame:Hide()
        self.tab:Show()
    else
        self.tab:Hide()
        self.frame:Show()
    end
end

function UI:Toggle()
    if self.frame:IsShown() or self.tab:IsShown() then
        self.frame:Hide()
        self.tab:Hide()
    else
        self:ShowWindow()
    end
end

function UI:ResetPosition()
    self.docked = false
    RestorePos(self.frame, "pos", function(fr) fr:SetPoint("CENTER", UIParent, "CENTER", 250, 0) end)
end

function UI:Dock()
    local ah = _G.AuctionHouseFrame or _G.AuctionFrame
    if not ah then return false end
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", ah, "TOPRIGHT", 2, 0)
    self.docked = true
    self:ArrangePanels()
    return true
end

function UI:OnAuctionHouseShown()
    if not self.frame then return end
    if ns.db.settings.attachToAH then self:Dock() end
    if ns.db.settings.openWithAH then self:ShowWindow() end
    self:Refresh()
end

function UI:OnAuctionHouseClosed()
    if not self.frame or not self.docked then return end
    -- stay where we are on screen instead of following the closed AH window
    self.docked = false
    if not AnchorAbsolute(self.frame) then self:ResetPosition() end
end
