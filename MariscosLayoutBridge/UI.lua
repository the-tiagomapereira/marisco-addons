-- Marisco's Layout Bridge: window, minimap button and slash commands.

local ADDON, ns = ...
local VERSION = "0.2 Beta"
local TITLE = "Marisco's Layout Bridge - v" .. VERSION

local W, H, PAD = 540, 700, 16
local frame

local function MakeTextBox(parent, width, height, readOnly)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetSize(width, height)

    local bg = CreateFrame("Frame", nil, scroll, BackdropTemplateMixin and "BackdropTemplate" or nil)
    bg:SetPoint("TOPLEFT", -6, 6)
    bg:SetPoint("BOTTOMRIGHT", 26, -6)
    if bg.SetBackdrop then
        bg:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        bg:SetBackdropColor(0, 0, 0, 0.6)
        bg:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end
    bg:SetFrameLevel(scroll:GetFrameLevel() - 1)

    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetMaxLetters(0)
    box:SetFontObject(ChatFontSmall or ChatFontNormal)
    box:SetWidth(width)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    scroll:SetScrollChild(box)
    scroll:SetScript("OnMouseDown", function() box:SetFocus() end)

    if readOnly then
        box:SetScript("OnTextChanged", function(self, userInput)
            if userInput and self.locked then self:SetText(self.locked); self:HighlightText() end
        end)
        box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        box:SetScript("OnMouseUp", function(self) self:HighlightText() end)
    end
    return scroll, box
end

local function Header(parent, text, anchor, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
    fs:SetText(text)
    return fs
end

local function SetOutput(str)
    frame.output.locked = str
    frame.output:SetText(str or "")
    frame.copyButton:SetEnabled(str ~= nil)
end

local function Plain(text)
    return (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local details
local function ShowDetails()
    if not details then
        details = CreateFrame("Frame", "MariscosLayoutBridgeDetails", UIParent, "BasicFrameTemplateWithInset")
        details:SetSize(560, 420)
        details:SetPoint("CENTER", 40, -20)
        details:SetFrameStrata("FULLSCREEN_DIALOG")
        details:SetMovable(true)
        details:EnableMouse(true)
        details:RegisterForDrag("LeftButton")
        details:SetScript("OnDragStart", details.StartMoving)
        details:SetScript("OnDragStop", details.StopMovingOrSizing)
        details:SetClampedToScreen(true)
        tinsert(UISpecialFrames, "MariscosLayoutBridgeDetails")

        local t = details.TitleText or details:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        t:ClearAllPoints()
        t:SetPoint("TOP", details, "TOP", 0, -5)
        t:SetText("Layout Bridge - details")

        local hint = details:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hint:SetPoint("TOPLEFT", 16, -34)
        hint:SetText("Text is selected: press Ctrl+C, then paste it to Claude.")

        local scroll, box = MakeTextBox(details, 560 - 32 - 24, 310, true)
        scroll:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 6, -12)
        details.box = box

        local sel = CreateFrame("Button", nil, details, "UIPanelButtonTemplate")
        sel:SetSize(130, 24)
        sel:SetPoint("BOTTOMLEFT", 16, 12)
        sel:SetText("Select all")
        sel:SetScript("OnClick", function() box:SetFocus(); box:HighlightText() end)

        local close = CreateFrame("Button", nil, details, "UIPanelButtonTemplate")
        close:SetSize(90, 24)
        close:SetPoint("BOTTOMRIGHT", -16, 12)
        close:SetText("Close")
        close:SetScript("OnClick", function() details:Hide() end)
    end

    local text = "Marisco's Layout Bridge " .. VERSION .. "\n\n== Report ==\n"
        .. Plain(frame.report:GetText()) .. "\n\n== Debug ==\n" .. Plain(ns.Debug(true))
    details.box.locked = text
    details.box:SetText(text)
    details:Show()
    details.box:SetFocus()
    details.box:HighlightText()
end

local function Options()
    local db = MariscosLayoutBridgeDB
    return {
        template = db.template,
        groups = db.groups,
        keepDefaults = db.keepDefaults,
        clamp = db.clamp,
    }
end

local function DoConvert()
    frame.input:ClearFocus()
    local out, report = ns.Convert(frame.input:GetText(), frame.nameBox:GetText(), Options())
    SetOutput(out)
    local color = out and "|cff40ff40" or "|cffff5050"
    local head = out and "Converted. Copy the string below." or "Not converted."
    frame.report:SetText(color .. head .. "|r\n" .. table.concat(report or {}, "\n"))
    if out then
        frame.output:SetFocus()
        frame.output:HighlightText()
    end
end

-- Template picker: arrows cycle through the player's layouts (saved ones first).
local function RefreshTemplate()
    local choices = ns.GetTemplateChoices()
    local db = MariscosLayoutBridgeDB
    local idx
    for i, c in ipairs(choices) do
        if c.name == db.template then idx = i break end
    end
    if not idx then
        for i, c in ipairs(choices) do
            if not c.preset then idx = i break end
        end
        idx = idx or (choices[1] and 1)
        db.template = idx and choices[idx].name or nil
    end
    local c = idx and choices[idx]
    frame.templateText:SetText(c and (c.name .. (c.preset and " |cff999999(preset)|r" or "")) or "|cffff5050none|r")
    return choices, idx
end

local function CycleTemplate(step)
    local choices, idx = RefreshTemplate()
    if not idx or #choices == 0 then return end
    idx = (idx - 1 + step) % #choices + 1
    MariscosLayoutBridgeDB.template = choices[idx].name
    RefreshTemplate()
end

local function MakeCheck(parent, label, checked, onClick, tip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetChecked(checked)
    local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    fs:SetText(label)
    if cb.Text then cb.Text:SetText("") end
    if cb.text then cb.text:SetText("") end
    cb:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
    if tip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label)
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", GameTooltip_Hide)
    end
    return cb
end

local function Build()
    local db = MariscosLayoutBridgeDB
    frame = CreateFrame("Frame", "MariscosLayoutBridgeFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(W, H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()
    tinsert(UISpecialFrames, "MariscosLayoutBridgeFrame")

    local title = frame.TitleText or frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:ClearAllPoints()
    title:SetPoint("TOP", frame, "TOP", 0, -5)
    title:SetText(TITLE)

    local inner = W - PAD * 2 - 24

    -- 1. Input
    local h1 = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h1:SetPoint("TOPLEFT", PAD, -36)
    h1:SetText("1. Paste the retail / modern layout string")

    local inScroll, input = MakeTextBox(frame, inner, 80)
    inScroll:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 6, -10)
    frame.input = input

    -- Name + template
    local nameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", inScroll, "BOTTOMLEFT", -6, -18)
    nameLabel:SetText("Layout name")
    local nameBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    nameBox:SetSize(160, 22)
    nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 12, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetText("Retail import")
    nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    frame.nameBox = nameBox

    local tLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tLabel:SetPoint("LEFT", nameBox, "RIGHT", 16, 0)
    tLabel:SetText("Template")
    local prev = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    prev:SetSize(22, 22)
    prev:SetPoint("LEFT", tLabel, "RIGHT", 8, 0)
    prev:SetText("<")
    prev:SetScript("OnClick", function() CycleTemplate(-1) end)
    local tText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tText:SetPoint("LEFT", prev, "RIGHT", 6, 0)
    tText:SetWidth(96)
    tText:SetJustifyH("CENTER")
    tText:SetWordWrap(false)
    frame.templateText = tText
    local nextB = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    nextB:SetSize(22, 22)
    nextB:SetPoint("LEFT", tText, "RIGHT", 6, 0)
    nextB:SetText(">")
    nextB:SetScript("OnClick", function() CycleTemplate(1) end)
    for _, b in ipairs({ prev, nextB }) do
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine("Template")
            GameTooltip:AddLine("Your layout that fills in everything the retail string doesn't: frames it lacks, frames the author never moved, and unticked groups.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
    end

    -- Groups
    local gh = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gh:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -20)
    gh:SetText("Take from the string |cff999999(unticked parts stay like your template)|r")

    local COLS, COLW, ROWH = 3, (W - PAD * 2) / 3, 24
    for i, g in ipairs(ns.GROUPS) do
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        local cb = MakeCheck(frame, g.label, db.groups[g.key] ~= false, function(v) db.groups[g.key] = v end)
        cb:SetPoint("TOPLEFT", gh, "BOTTOMLEFT", col * COLW - 2, -6 - row * ROWH)
    end
    local rows = math.ceil(#ns.GROUPS / COLS)

    local keep = MakeCheck(frame, "Frames the author never moved keep my position", db.keepDefaults ~= false,
        function(v) db.keepDefaults = v end,
        "Retail's default spots are not Forever's. Without this, untouched frames go to Forever's defaults and can pile up on top of the author's frames.")
    keep:SetPoint("TOPLEFT", gh, "BOTTOMLEFT", -2, -12 - rows * ROWH)
    local clamp = MakeCheck(frame, "Keep frames on screen", db.clamp ~= false,
        function(v) db.clamp = v end,
        "Pulls back any frame whose position would put it past the edge of your screen.")
    clamp:SetPoint("TOPLEFT", keep, "BOTTOMLEFT", 0, -2)

    local convert = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    convert:SetSize(130, 26)
    convert:SetPoint("TOPRIGHT", gh, "BOTTOMLEFT", W - PAD * 2, -12 - rows * ROWH)
    convert:SetText("Convert")
    convert:SetScript("OnClick", DoConvert)

    -- Report
    local report = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    report:SetPoint("TOPLEFT", clamp, "BOTTOMLEFT", 2, -10)
    report:SetWidth(W - PAD * 2)
    report:SetJustifyH("LEFT")
    report:SetJustifyV("TOP")
    report:SetHeight(120)
    report:SetText("|cffaaaaaaPaste a string, pick a template and press Convert.|r")
    frame.report = report

    -- 2. Output
    local h3 = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h3:SetPoint("TOPLEFT", report, "BOTTOMLEFT", 0, -8)
    h3:SetText("2. Copy this string, then Edit Mode > Import")

    local detailsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    detailsBtn:SetSize(120, 22)
    detailsBtn:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    detailsBtn:SetPoint("TOP", report, "BOTTOM", 0, -2)
    detailsBtn:SetText("Copy details")
    detailsBtn:SetScript("OnClick", ShowDetails)

    local outScroll, output = MakeTextBox(frame, inner, 80, true)
    outScroll:SetPoint("TOPLEFT", h3, "BOTTOMLEFT", 6, -10)
    frame.output = output

    local copy = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    copy:SetSize(150, 24)
    copy:SetPoint("BOTTOMLEFT", PAD, 14)
    copy:SetText("Select for copy")
    copy:SetScript("OnClick", function() output:SetFocus(); output:HighlightText() end)
    copy:SetEnabled(false)
    frame.copyButton = copy

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", copy, "RIGHT", 10, 0)
    hint:SetText("then Ctrl+C")

    local clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clear:SetSize(90, 24)
    clear:SetPoint("BOTTOMRIGHT", -PAD, 14)
    clear:SetText("Clear")
    clear:SetScript("OnClick", function()
        input:SetText("")
        SetOutput(nil)
        report:SetText("|cffaaaaaaPaste a string, pick a template and press Convert.|r")
    end)

    frame:SetScript("OnShow", RefreshTemplate)
end

function ns.Toggle()
    if not frame then Build() end
    frame:SetShown(not frame:IsShown())
    if frame:IsShown() then frame.input:SetFocus() end
end

-- Minimap button (a plain named button, so MiniMapButtonHoarder picks it up).
local function UpdateMinimapPos(btn)
    local angle = math.rad(MariscosLayoutBridgeDB.minimapAngle or 200)
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end

local function BuildMinimapButton()
    local btn = CreateFrame("Button", "MariscosLayoutBridgeMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -5)
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    btn:SetScript("OnClick", function() ns.Toggle() end)
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(s)
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            MariscosLayoutBridgeDB.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            s:ClearAllPoints()
            UpdateMinimapPos(s)
        end)
    end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Marisco's Layout Bridge")
        GameTooltip:AddLine("Click: open converter", 1, 1, 1)
        GameTooltip:AddLine("Drag: move button", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    UpdateMinimapPos(btn)
    btn:SetShown(not MariscosLayoutBridgeDB.hideMinimap)
    ns.minimapButton = btn
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    MariscosLayoutBridgeDB = MariscosLayoutBridgeDB or {}
    MariscosLayoutBridgeDB.groups = MariscosLayoutBridgeDB.groups or {}
    BuildMinimapButton()
    self:UnregisterEvent("ADDON_LOADED")
end)

SLASH_MARISCOSLAYOUTBRIDGE1 = "/mlb"
SLASH_MARISCOSLAYOUTBRIDGE2 = "/layoutbridge"
SlashCmdList.MARISCOSLAYOUTBRIDGE = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "debug" then
        ns.Debug()
    elseif msg == "minimap" then
        MariscosLayoutBridgeDB.hideMinimap = not MariscosLayoutBridgeDB.hideMinimap
        ns.minimapButton:SetShown(not MariscosLayoutBridgeDB.hideMinimap)
    else
        ns.Toggle()
    end
end
