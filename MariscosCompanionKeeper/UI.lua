-- Marisco's Companion Keeper - UI
-- Main window (companion list + preview), minimap button and the probe report window.
-- Built from the client's own window templates so it matches the Forever UI.

local ADDON, ns = ...

local UI = {}
ns.UI = UI

local ROW_H   = 40
local frame           -- main window
local rows    = {}
local viewedID        -- companion shown on the right
local filterText = ""
local shownList = {}

------------------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------------------

local function TemplateExists(name)
    if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
        local ok, info = pcall(C_XMLUtil.GetTemplateInfo, name)
        return ok and info ~= nil
    end
    return nil -- can't tell, just try it
end

-- Create a frame from the first template this client knows.
local function NewFrame(frameType, name, parent, templates)
    for _, t in ipairs(templates or {}) do
        if TemplateExists(t) ~= false then
            local ok, f = pcall(CreateFrame, frameType, name, parent, t)
            if ok and f then return f, t end
        end
    end
    local ok, f = pcall(CreateFrame, frameType, name, parent, "BackdropTemplate")
    if ok and f then return f, "BackdropTemplate" end
    return CreateFrame(frameType, name, parent), nil
end

local function PlainBackdrop(f, dark)
    if not f.SetBackdrop then return end
    f:SetBackdrop({
        bgFile   = dark and "Interface\\Buttons\\WHITE8X8" or "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = dark and "Interface\\Tooltips\\UI-Tooltip-Border" or "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = dark and 12 or 32,
        insets = dark and { left = 3, right = 3, top = 3, bottom = 3 } or { left = 11, right = 12, top = 12, bottom = 11 },
    })
    if dark then
        f:SetBackdropColor(0, 0, 0, 0.55)
        f:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end
end

local function NewInset(parent)
    local f, t = NewFrame("Frame", nil, parent, { "InsetFrameTemplate" })
    if t ~= "InsetFrameTemplate" then PlainBackdrop(f, true) end
    return f
end

local function SetPortrait(f, tex)
    if f.SetPortraitToAsset and pcall(f.SetPortraitToAsset, f, tex) then return end
    local p = f.portrait or f.Portrait or (f.PortraitContainer and f.PortraitContainer.portrait)
    if p then
        if SetPortraitToTexture then
            pcall(SetPortraitToTexture, p, tex)
        else
            p:SetTexture(tex)
        end
    end
end

local function TitleFontString(f)
    return f.TitleText or (f.TitleContainer and f.TitleContainer.TitleText) or f.title
end

-- Title centered between the portrait and the close button, version in white.
local function SetWindowTitle(f, text, hasPortrait)
    local fs = TitleFontString(f)
    if not fs then
        fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.title = fs
    end
    fs:SetText(text)
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", f, "TOPLEFT", hasPortrait and 60 or 12, -13)
    fs:SetPoint("RIGHT", f, "TOPRIGHT", -28, -13)
    fs:SetJustifyH("CENTER")
end

local function Sound(kitName, fallbackID)
    local id = SOUNDKIT and SOUNDKIT[kitName] or fallbackID
    if id then pcall(PlaySound, id) end
end

local function FullTitle()
    return ns.TITLE .. "  |cffffffff" .. ns.VERSION_LABEL .. "|r"
end

------------------------------------------------------------------------------------------
-- Main window
------------------------------------------------------------------------------------------

local function CreateRow(child, i)
    local b = CreateFrame("Button", nil, child)
    b:SetHeight(ROW_H)
    b:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(i - 1) * ROW_H)
    b:SetPoint("RIGHT", child, "RIGHT", 0, 0)
    b:RegisterForClicks("LeftButtonUp")

    b.stripe = b:CreateTexture(nil, "BACKGROUND")
    b.stripe:SetAllPoints()
    b.stripe:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0)

    b.sel = b:CreateTexture(nil, "BORDER")
    b.sel:SetAllPoints()
    b.sel:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
    b.sel:SetBlendMode("ADD")
    b.sel:SetVertexColor(1, 0.82, 0, 0.55)
    b.sel:Hide()

    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(32, 32)
    b.icon:SetPoint("LEFT", 4, 0)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    b.iconBorder = b:CreateTexture(nil, "OVERLAY")
    b.iconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    b.iconBorder:SetPoint("TOPLEFT", b.icon, "TOPLEFT", -10, 10)
    b.iconBorder:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", 10, -10)
    b.iconBorder:SetAlpha(0.8)

    b.check = b:CreateTexture(nil, "OVERLAY")
    b.check:SetSize(20, 20)
    b.check:SetPoint("RIGHT", -2, 0)
    b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    b.check:Hide()

    b.name = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 8, -2)
    b.name:SetPoint("RIGHT", b, "RIGHT", -26, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)

    b.sub = b:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
    b.sub:SetPoint("RIGHT", b, "RIGHT", -26, 0)
    b.sub:SetJustifyH("LEFT")
    b.sub:SetWordWrap(false)

    b:SetScript("OnClick", function(self)
        UI:View(self.petID)
        Sound("IG_MAINMENU_OPTION_CHECKBOX_ON", 856)
    end)
    b:SetScript("OnDoubleClick", function(self)
        UI:View(self.petID)
        UI:SelectViewed()
    end)
    b:SetScript("OnEnter", function(self)
        local p = ns.Journal:Get(self.petID)
        if not p then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(p.name, 1, 0.82, 0)
        if p.customName and p.speciesName and p.customName ~= "" then
            GameTooltip:AddLine(p.speciesName, 1, 1, 1)
        end
        if ns.Journal.summonedID == p.id then
            GameTooltip:AddLine("Out with you right now", 0.25, 1, 0.25)
        end
        GameTooltip:AddLine("Click to view, double-click to choose.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    rows[i] = b
    return b
end

local function UpdateScrollbar()
    if not frame then return end
    local scroll, child = frame.scroll, frame.scrollChild
    local bar = scroll.ScrollBar or _G[(scroll:GetName() or "") .. "ScrollBar"]
    if not bar then return end
    local need = child:GetHeight() > scroll:GetHeight() + 1
    bar:SetShown(need)
    if not need then scroll:SetVerticalScroll(0) end
end

function UI:Build()
    if frame then return end

    local f, tmpl = NewFrame("Frame", "MariscosCompanionKeeperFrame", UIParent,
        { "PortraitFrameTemplate", "ButtonFrameTemplate", "BasicFrameTemplateWithInset" })
    frame = f
    local hasPortrait = (tmpl == "PortraitFrameTemplate" or tmpl == "ButtonFrameTemplate")

    f:SetSize(640, 460)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        ns.db.window = { point, relPoint, x, y }
    end)
    f:Hide()
    tinsert(UISpecialFrames, "MariscosCompanionKeeperFrame")

    if tmpl == "ButtonFrameTemplate" and f.Inset then f.Inset:Hide() end
    if not hasPortrait and tmpl ~= "BasicFrameTemplateWithInset" then
        PlainBackdrop(f, false)
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
    end
    if f.InsetBg then f.InsetBg:Hide() end
    if hasPortrait then SetPortrait(f, ns.ICON) end
    SetWindowTitle(f, FullTitle(), hasPortrait)

    f:SetScript("OnShow", function()
        Sound("IG_CHARACTER_INFO_OPEN", 839)
        ns.Journal:RequestScan(0.05)
        UI:Refresh()
    end)
    f:SetScript("OnHide", function() Sound("IG_CHARACTER_INFO_CLOSE", 840) end)

    local top = hasPortrait and -62 or -32

    -- header line
    f.count = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.count:SetPoint("TOPLEFT", f, "TOPLEFT", hasPortrait and 66 or 16, -36)
    f.hint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.hint:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -40)
    f.hint:SetText("Companions are shared by your whole account")

    -- left: companion list
    local left = NewInset(f)
    left:SetPoint("TOPLEFT", f, "TOPLEFT", 12, top)
    left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 30)
    left:SetWidth(262)
    f.left = left

    local search, stmpl = NewFrame("EditBox", "MariscosCompanionKeeperSearch", left, { "SearchBoxTemplate", "InputBoxTemplate" })
    search:SetSize(stmpl == "InputBoxTemplate" and 224 or 232, 20)
    search:SetPoint("TOPLEFT", left, "TOPLEFT", stmpl == "InputBoxTemplate" and 16 or 12, -8)
    search:SetAutoFocus(false)
    if search.Instructions then search.Instructions:SetText("Search companions") end
    search:HookScript("OnTextChanged", function(self)
        filterText = strlower(strtrim(self:GetText() or ""))
        UI:Refresh()
    end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    f.search = search

    local scroll = NewFrame("ScrollFrame", "MariscosCompanionKeeperScroll", left, { "UIPanelScrollFrameTemplate" })
    scroll:SetPoint("TOPLEFT", left, "TOPLEFT", 6, -34)
    scroll:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -26, 6)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(228, 1)
    scroll:SetScrollChild(child)
    if not scroll.ScrollBar and not _G["MariscosCompanionKeeperScrollScrollBar"] then
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(self, delta)
            local maxV = math.max(0, child:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.min(maxV, math.max(0, self:GetVerticalScroll() - delta * ROW_H)))
        end)
    end
    f.scroll, f.scrollChild = scroll, child

    f.noMatch = left:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    f.noMatch:SetPoint("TOP", left, "TOP", 0, -60)
    f.noMatch:SetText("No companion matches your search.")
    f.noMatch:Hide()

    -- right: preview
    local right = NewInset(f)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 30)
    f.right = right

    local stage = right:CreateTexture(nil, "BACKGROUND", nil, 1)
    stage:SetPoint("TOPLEFT", 4, -4)
    stage:SetPoint("TOPRIGHT", -4, -4)
    stage:SetHeight(190)
    stage:SetColorTexture(0.06, 0.05, 0.03, 0.75)
    local floor = right:CreateTexture(nil, "BACKGROUND", nil, 2)
    floor:SetPoint("BOTTOMLEFT", stage, "BOTTOMLEFT")
    floor:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT")
    floor:SetHeight(2)
    floor:SetColorTexture(1, 0.82, 0, 0.35)

    local model = CreateFrame("PlayerModel", nil, right)
    model:SetPoint("TOPLEFT", stage, "TOPLEFT", 6, -6)
    model:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT", -6, 4)
    model:EnableMouse(true)
    model.facing = 0.5
    model:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self.dragX = GetCursorPosition()
        self:SetScript("OnUpdate", function(m)
            local x = GetCursorPosition()
            m.facing = m.facing + (x - m.dragX) * 0.012
            m.dragX = x
            pcall(m.SetFacing, m, m.facing)
        end)
    end)
    model:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    model:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
    f.model = model

    f.modelIcon = right:CreateTexture(nil, "ARTWORK")
    f.modelIcon:SetSize(64, 64)
    f.modelIcon:SetPoint("CENTER", stage, "CENTER")
    f.modelIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.modelIcon:Hide()

    f.rotateHint = right:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.rotateHint:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT", -6, 6)
    f.rotateHint:SetText("Drag to turn")

    f.petName = right:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    f.petName:SetPoint("TOP", stage, "BOTTOM", 0, -12)
    f.petName:SetPoint("LEFT", right, "LEFT", 10, 0)
    f.petName:SetPoint("RIGHT", right, "RIGHT", -10, 0)
    f.petName:SetWordWrap(false)

    f.petSpecies = right:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    f.petSpecies:SetPoint("TOP", f.petName, "BOTTOM", 0, -4)

    f.petOut = right:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    f.petOut:SetPoint("TOP", f.petSpecies, "BOTTOM", 0, -8)
    f.petOut:SetTextColor(0.25, 1, 0.25)

    -- placeholder for the care features
    local care = CreateFrame("Frame", nil, right, BackdropTemplateMixin and "BackdropTemplate" or nil)
    care:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 14, 48)
    care:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -14, 48)
    care:SetHeight(40)
    if care.SetBackdrop then
        care:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
                           bgFile = "Interface\\Buttons\\WHITE8X8", insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        care:SetBackdropColor(0, 0, 0, 0.35)
        care:SetBackdropBorderColor(0.6, 0.5, 0.2, 0.8)
    end
    care.text = care:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    care.text:SetPoint("TOPLEFT", 8, -4)
    care.text:SetPoint("BOTTOMRIGHT", -8, 4)
    care.text:SetText("Happiness, feeding and play arrive in the next version.\nSummoned companions will earn bonus happiness.")
    f.care = care

    local selectBtn = NewFrame("Button", nil, right, { "UIPanelButtonTemplate" })
    selectBtn:SetSize(190, 26)
    selectBtn:SetPoint("BOTTOM", right, "BOTTOM", 0, 14)
    selectBtn:SetScript("OnClick", function() UI:SelectViewed() end)
    f.select = selectBtn

    f.chosenMark = right:CreateTexture(nil, "OVERLAY")
    f.chosenMark:SetSize(22, 22)
    f.chosenMark:SetPoint("RIGHT", selectBtn, "LEFT", -4, 1)
    f.chosenMark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")

    -- footer
    f.footer = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 11)
    f.footer:SetText("Click a companion to view it, double-click or press the button to choose it.")

    -- empty / loading / no-API overlay
    local over = CreateFrame("Frame", nil, f)
    over:SetPoint("TOPLEFT", left, "TOPLEFT")
    over:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT")
    over.bg = NewInset(over)
    over.bg:SetAllPoints()
    over.icon = over:CreateTexture(nil, "ARTWORK")
    over.icon:SetSize(56, 56)
    over.icon:SetPoint("CENTER", over, "CENTER", 0, 50)
    over.icon:SetTexture(ns.ICON)
    over.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    over.title = over:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    over.title:SetPoint("TOP", over.icon, "BOTTOM", 0, -14)
    over.text = over:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    over.text:SetPoint("TOP", over.title, "BOTTOM", 0, -10)
    over.text:SetWidth(420)
    over.text:SetJustifyH("CENTER")
    over:Hide()
    f.overlay = over

    UI:RestorePosition()
end

function UI:RestorePosition()
    if not frame then return end
    frame:ClearAllPoints()
    local w = ns.db.window
    if type(w) == "table" and w[1] then
        frame:SetPoint(w[1], UIParent, w[2] or w[1], w[3] or 0, w[4] or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
end

local function ShowOverlay(state)
    local o = frame.overlay
    if state == "loading" then
        o.icon:SetDesaturated(false)
        o.title:SetText("Reading your Companion Journal...")
        o.text:SetText("This only takes a moment after you log in.")
    elseif state == "noapi" then
        o.icon:SetDesaturated(true)
        o.title:SetText("Companion Journal not available")
        o.text:SetText("This client doesn't let addons read the Companion Journal.\nType |cffffd100/mck probe|r and send the report so the addon can be fixed.")
    else
        o.icon:SetDesaturated(true)
        o.title:SetText("No companions yet")
        o.text:SetText("There are no companion pets in your Companion Journal.\nCollect a companion and it will appear here.")
    end
    o:Show()
    frame.left:Hide()
    frame.right:Hide()
end

local function ShowModel(p)
    local m = frame.model
    pcall(m.ClearModel, m)
    local shown = false
    if p.displayID and p.displayID ~= 0 then
        shown = pcall(m.SetDisplayInfo, m, p.displayID)
    end
    if not shown and p.creatureID and p.creatureID ~= 0 then
        shown = pcall(m.SetCreature, m, p.creatureID)
    end
    m.facing = 0.5
    pcall(m.SetFacing, m, m.facing)
    m:SetShown(shown)
    frame.rotateHint:SetShown(shown)
    frame.modelIcon:SetTexture(p.icon)
    frame.modelIcon:SetShown(not shown)
end

local function UpdateDetail()
    local J = ns.Journal
    local p = J:Get(viewedID)
    if not p then
        frame.right:Hide()
        return
    end
    frame.right:Show()
    if frame.model.petID ~= p.id then
        frame.model.petID = p.id
        ShowModel(p)
    end
    frame.petName:SetText(p.name)
    if p.customName and p.customName ~= "" and p.speciesName then
        frame.petSpecies:SetText(p.speciesName)
    else
        frame.petSpecies:SetText("Companion")
    end
    frame.petOut:SetText(J.summonedID == p.id and "Out with you right now" or "")

    local sel = ns.db.selected
    local chosen = sel and sel.id == p.id
    frame.select:SetText(chosen and "Your companion" or "Choose this companion")
    frame.select:SetEnabled(not chosen)
    frame.chosenMark:SetShown(chosen)
end

function UI:Refresh()
    self:UpdateMinimapIcon()
    if not frame or not frame:IsShown() then return end
    local J = ns.Journal

    if J.state ~= "ready" then
        ShowOverlay(J.state)
        frame.count:SetText(J.state == "loading" and "" or "Companions owned: |cffffffff0|r")
        return
    end
    frame.overlay:Hide()
    frame.left:Show()

    wipe(shownList)
    for _, p in ipairs(J.pets) do
        if filterText == "" or strlower(p.name):find(filterText, 1, true)
           or (p.speciesName and strlower(p.speciesName):find(filterText, 1, true)) then
            shownList[#shownList + 1] = p
        end
    end

    if filterText ~= "" then
        frame.count:SetText(("Companions owned: |cffffffff%d|r  |cff9d9d9d(showing %d)|r"):format(#J.pets, #shownList))
    else
        frame.count:SetText(("Companions owned: |cffffffff%d|r"):format(#J.pets))
    end

    -- keep a sensible companion in view
    if not J:Get(viewedID) then
        local sel = ns.db.selected
        viewedID = (sel and J:Get(sel.id) and sel.id) or (J.pets[1] and J.pets[1].id)
    end

    local child = frame.scrollChild
    child:SetWidth(frame.scroll:GetWidth() > 0 and frame.scroll:GetWidth() or 228)
    local sel = ns.db.selected
    for i, p in ipairs(shownList) do
        local r = rows[i] or CreateRow(child, i)
        r.petID = p.id
        r.icon:SetTexture(p.icon)
        r.name:SetText(p.name)
        local sub = (p.customName and p.customName ~= "" and p.speciesName) or "Companion"
        if J.summonedID == p.id then sub = sub .. "  |cff40ff40- out with you|r" end
        r.sub:SetText(sub)
        local isChosen = sel and sel.id == p.id
        r.check:SetShown(isChosen)
        r.name:SetFontObject(isChosen and "GameFontNormal" or "GameFontHighlight")
        r.sel:SetShown(p.id == viewedID)
        r:Show()
    end
    for i = #shownList + 1, #rows do rows[i]:Hide() end
    child:SetHeight(math.max(1, #shownList * ROW_H))
    frame.noMatch:SetShown(#shownList == 0)
    C_Timer.After(0, UpdateScrollbar)

    UpdateDetail()
end

function UI:View(id)
    if not id then return end
    viewedID = id
    self:Refresh()
end

function UI:SelectViewed()
    local p = ns.Journal:Get(viewedID)
    if not p then return end
    local sel = ns.db.selected
    if sel and sel.id == p.id then return end
    ns.db.selected = { id = p.id, name = p.name, speciesID = p.speciesID }
    Sound("IG_QUEST_LIST_COMPLETE", 878)
    ns.Print(("|cffffffff%s|r is now your companion."):format(p.name))
    self:Refresh()
end

function UI:Toggle()
    self:Build()
    frame:SetShown(not frame:IsShown())
end

function UI:ResetPositions()
    if frame then self:RestorePosition() end
    if self.mm then
        self.mm:SetShown(true)
        self:PositionMinimapButton()
    end
    self:Refresh()
end

function UI:PrintStatus()
    local J = ns.Journal
    local sel = ns.db.selected
    local p = sel and J:Get(sel.id)
    local words = { ready = "read", empty = "read (no companions)", loading = "still loading", noapi = "not available to addons" }
    ns.Print(("Companion Journal %s, %d companion(s) found."):format(words[J.state] or tostring(J.state), #J.pets))
    if p then
        print("  Your companion: |cffffffff" .. p.name .. "|r" .. (J.summonedID == p.id and " |cff40ff40(out with you)|r" or ""))
    elseif sel then
        print("  Your companion: |cffffffff" .. tostring(sel.name) .. "|r (not found in the journal right now)")
    else
        print("  No companion chosen yet. Type /mck to choose one.")
    end
end

------------------------------------------------------------------------------------------
-- Minimap button (standard LibDBIcon-style layout, so MiniMapButtonHoarder picks it up)
------------------------------------------------------------------------------------------

function UI:PositionMinimapButton()
    local b = self.mm
    if not b then return end
    local angle = math.rad(ns.db.minimap.angle or 215)
    local r = (Minimap:GetWidth() / 2) + 10
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

function UI:UpdateMinimapIcon()
    if not self.mm then return end
    local sel = ns.db and ns.db.selected
    local p = sel and ns.Journal:Get(sel.id)
    self.mm.icon:SetTexture(p and p.icon or ns.ICON)
end

function UI:CreateMinimapButton()
    if self.mm then return end
    local b = CreateFrame("Button", "MariscosCompanionKeeperMinimapButton", Minimap)
    self.mm = b
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = b:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(17, 17)
    b.icon:SetPoint("TOPLEFT", 7, -6)
    b.icon:SetTexture(ns.ICON)

    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            UI:PrintStatus()
        else
            UI:Toggle()
        end
    end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            ns.db.minimap.angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
            UI:PositionMinimapButton()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(ns.TITLE, 1, 0.82, 0)
        local sel = ns.db.selected
        local p = sel and ns.Journal:Get(sel.id)
        GameTooltip:AddLine("Your companion: " .. (p and ("|cffffffff" .. p.name .. "|r") or "|cff9d9d9dnone chosen|r"), 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click: open", 1, 1, 1)
        GameTooltip:AddLine("Right-click: status", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self:PositionMinimapButton()
    b:SetShown(not ns.db.minimap.hide)
    self:UpdateMinimapIcon()
end

function UI:ToggleMinimap()
    ns.db.minimap.hide = not ns.db.minimap.hide
    if self.mm then self.mm:SetShown(not ns.db.minimap.hide) end
    ns.Print(ns.db.minimap.hide and "minimap button hidden (/mck minimap to show it)." or "minimap button shown.")
end

------------------------------------------------------------------------------------------
-- Probe report window (/mck probe)
------------------------------------------------------------------------------------------

function UI:ShowProbe()
    local report = ns.Journal:BuildProbeReport()
    local p = self.probe
    if not p then
        local f, tmpl = NewFrame("Frame", "MariscosCompanionKeeperProbe", UIParent,
            { "PortraitFrameTemplate", "ButtonFrameTemplate", "BasicFrameTemplateWithInset" })
        p = f
        self.probe = p
        local hasPortrait = (tmpl == "PortraitFrameTemplate" or tmpl == "ButtonFrameTemplate")
        f:SetSize(600, 440)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
        f:SetFrameStrata("DIALOG")
        f:SetToplevel(true)
        f:SetClampedToScreen(true)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        tinsert(UISpecialFrames, "MariscosCompanionKeeperProbe")
        if tmpl == "ButtonFrameTemplate" and f.Inset then f.Inset:Hide() end
        if not hasPortrait and tmpl ~= "BasicFrameTemplateWithInset" then
            PlainBackdrop(f, false)
            local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
            close:SetPoint("TOPRIGHT", -4, -4)
        end
        if f.InsetBg then f.InsetBg:Hide() end
        if hasPortrait then SetPortrait(f, ns.ICON) end
        SetWindowTitle(f, "Companion Journal report  |cffffffff" .. ns.VERSION_LABEL .. "|r", hasPortrait)

        local info = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        info:SetPoint("TOPLEFT", f, "TOPLEFT", hasPortrait and 66 or 16, -38)
        info:SetText("The report is selected: press |cffffd100Ctrl+C|r to copy it.")

        local inset = NewInset(f)
        inset:SetPoint("TOPLEFT", f, "TOPLEFT", 12, hasPortrait and -62 or -60)
        inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)

        local scroll = NewFrame("ScrollFrame", "MariscosCompanionKeeperProbeScroll", inset, { "UIPanelScrollFrameTemplate" })
        scroll:SetPoint("TOPLEFT", 8, -8)
        scroll:SetPoint("BOTTOMRIGHT", -28, 8)

        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(530)
        edit:SetScript("OnEscapePressed", function() f:Hide() end)
        edit:SetScript("OnTextChanged", function(self, userInput)
            if userInput then
                self:SetText(p.report or "")
                self:HighlightText()
            end
        end)
        edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        scroll:SetScrollChild(edit)
        p.edit = edit
    end
    p.report = report
    p.edit:SetText(report)
    p:Show()
    p.edit:SetFocus()
    p.edit:HighlightText()
end
