-- Marisco's Companion Keeper - UI
-- Main window (companion list + preview), minimap button and the probe report window.
-- Built from the client's own window templates so it matches the Forever UI.

local ADDON, ns = ...

local UI = {}
ns.UI = UI

local ROW_H   = 40
local frame           -- main window
local rows    = {}
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

local LIST_W      = 262   -- companion list width
local PANEL_W     = 366   -- companion panel width with the list open
local WIN_H       = 672
local STAGE_H     = 290   -- 3D portrait height
local STRIP_H     = 56    -- name / status / button strip at the bottom of the portrait
local EXPANDED_W  = 12 + LIST_W + 8 + PANEL_W + 12

local STATUS_OUT  = "Running alongside you"
local STATUS_CAGE = "In its cage"
local busyUntil   = 0     -- Summon button pause after a click

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

    b.sub = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
    b.sub:SetPoint("RIGHT", b, "RIGHT", -26, 0)
    b.sub:SetJustifyH("LEFT")
    b.sub:SetWordWrap(false)

    b:SetScript("OnClick", function(self) UI:Choose(self.petID) end)
    b:SetScript("OnEnter", function(self)
        local p = ns.Journal:Get(self.petID)
        if not p then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(p.name, 1, 0.82, 0)
        if p.customName and p.speciesName and p.customName ~= "" then
            GameTooltip:AddLine(p.speciesName, 1, 1, 1)
        end
        if ns.Journal.summonedID == p.id then
            GameTooltip:AddLine(STATUS_OUT, 0.25, 1, 0.25)
        else
            GameTooltip:AddLine(STATUS_CAGE, 1, 0.3, 0.3)
        end
        GameTooltip:AddLine("Click to choose this companion.", 0.6, 0.6, 0.6)
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

local function SavePosition()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    if point then ns.db.window = { point, relPoint, x, y } end
end

-- Show or hide the companion list. The window keeps its size: the list slides away to the
-- left and the companion panel grows to fill the whole area (and back).
local SLIDE_TIME = 0.25
local slide = 0            -- 0 = list open, 1 = list hidden
local slideTarget = 0

local function SetSlide(t)
    slide = t
    local open = 1 - t
    frame.listHolder:SetWidth(math.max(1, LIST_W * open))
    frame.left:SetAlpha(open)
    frame.left:SetShown(t < 1 and ns.Journal.state == "ready")
    frame.right:ClearAllPoints()
    frame.right:SetPoint("TOPLEFT", frame, "TOPLEFT", 12 + (LIST_W + 8) * open, frame.contentTop)
    frame.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 30)
end

local function UpdateCollapseButton()
    local collapsed = ns.db.collapsed and true or false
    frame.footer:SetText(collapsed and "Use the arrow to show your companions."
                                   or "Click a companion to choose it.")
    local c = frame.collapse
    local page = collapsed and "Next" or "Prev"
    c:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. page .. "Page-Up")
    c:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. page .. "Page-Down")
    c:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. page .. "Page-Disabled")
end

local function ApplyLayout(animate)
    slideTarget = ns.db.collapsed and 1 or 0
    UpdateCollapseButton()
    if not animate or not frame:IsShown() then
        frame.animator:SetScript("OnUpdate", nil)
        SetSlide(slideTarget)
        return
    end
    local from = slide
    local elapsed = 0
    frame.animator:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local k = math.min(1, elapsed / SLIDE_TIME)
        k = k * k * (3 - 2 * k)  -- ease in and out
        SetSlide(from + (slideTarget - from) * k)
        if k >= 1 then
            self:SetScript("OnUpdate", nil)
            UI:Refresh()
        end
    end)
end

function UI:ToggleList()
    ns.db.collapsed = not ns.db.collapsed
    Sound(ns.db.collapsed and "IG_CHARACTER_INFO_CLOSE" or "IG_CHARACTER_INFO_OPEN", 840)
    if frame then
        ApplyLayout(true)
        self:Refresh()
    end
end

------------------------------------------------------------------------------------------
-- Actions box: happiness bar, today's hearts, daily actions
------------------------------------------------------------------------------------------

local ACTION_ROW_H = 22
local FormatTime = function(secs) return ns.Buddy.FormatTime(secs) end

-- Status text and mark for one daily challenge row (shared with the mini window).
function UI.ChallengeState(r, a, capped)
    local B = ns.Buddy
    if r.done[a.key] then
        return "", "Interface\\RaidFrame\\ReadyCheck-Ready", true
    end
    local need = a.need or 1
    local text = ""
    if a.format then
        text = a.format(r.prog[a.key], need)
    elseif need > 1 then
        text = ("%d/%d"):format(math.min(r.prog[a.key] or 0, need), need)
    end
    if capped then
        text = (text ~= "" and (text .. "  ") or "") .. ("|cffffd100+%d|r"):format(B.BONUS_POINTS)
        return text, nil, false
    end
    return text, B.HEART_EMPTY, false
end

-- Walk together bar: fills toward the next milestone, with the yards written inside.
function UI.NewWalkBar(parent, height)
    local B = ns.Buddy
    local border = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    border:SetHeight(height)
    if border.SetBackdrop then
        border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
                             bgFile = "Interface\\Buttons\\WHITE8X8", insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        border:SetBackdropColor(0, 0, 0, 0.6)
        border:SetBackdropBorderColor(0.45, 0.6, 0.75, 1)
    end
    border:EnableMouse(true)
    local bar = CreateFrame("StatusBar", nil, border)
    bar:SetPoint("TOPLEFT", 3, -3)
    bar:SetPoint("BOTTOMRIGHT", -3, 3)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.25, 0.6, 1)
    bar:SetMinMaxValues(0, 1)
    bar.icon = bar:CreateTexture(nil, "OVERLAY")
    bar.icon:SetSize(height - 6, height - 6)
    bar.icon:SetPoint("LEFT", 2, 0)
    bar.icon:SetTexture("Interface\\Icons\\Ability_Tracking")
    bar.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER", 4, 0)
    border.bar = bar
    border:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Walk together", 1, 0.82, 0)
        GameTooltip:AddLine("Distance travelled with your companion running alongside you. It adds up across days; flight paths don't count.", 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        for i, y in ipairs(B.WALK_STEPS) do
            local done = self.step and self.step > i
            GameTooltip:AddDoubleLine(("%sStep %d: %s yards"):format(done and "|cff40ff40" or "", i, B.Yards(y)),
                ("+%d"):format(B.WALK_REWARDS[i]), 1, 1, 1, 0.5, 1, 0.5)
        end
        GameTooltip:AddDoubleLine(("Then every %s yards"):format(B.Yards(B.WALK_AFTER)), ("+%d"):format(B.WALK_AFTER_REWARD), 1, 1, 1, 0.5, 1, 0.5)
        if self.total then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(("Walked together so far: %s yards"):format(B.Yards(self.total)), 0.6, 0.8, 1)
        end
        GameTooltip:Show()
    end)
    border:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return border
end

function UI.SetWalkBar(w, r, short)
    local B = ns.Buddy
    local goal, reward, n = B:WalkGoal(r)
    local start = B:WalkStart(r)
    w.total, w.step = r.walked, n
    local bar = w.bar
    bar:SetMinMaxValues(start, goal)
    bar:SetValue(math.min(r.walked, goal))
    if B.walkAvailable == false then
        bar.text:SetText("|cff9d9d9dWalk together: distance not available here|r")
    elseif short then
        bar.text:SetText(("Walk %s / %s yd"):format(B.Yards(r.walked), B.Yards(goal)))
    else
        local stage = n <= #B.WALK_STEPS and ("Step %d of %d"):format(n, #B.WALK_STEPS) or "Long journey"
        bar.text:SetText(("Walk together  %s:  %s / %s yd  |cffffd100+%d|r"):format(stage, B.Yards(r.walked), B.Yards(goal), reward))
    end
end

local function BuildActions(box)
    local B = ns.Buddy

    box.title = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    box.title:SetPoint("TOPLEFT", 12, -10)
    box.title:SetText("Happiness")

    box.level = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    box.level:SetPoint("TOPRIGHT", -12, -10)

    -- happiness bar
    local barBorder = CreateFrame("Frame", nil, box, BackdropTemplateMixin and "BackdropTemplate" or nil)
    barBorder:SetPoint("TOPLEFT", 10, -27)
    barBorder:SetPoint("TOPRIGHT", -10, -27)
    barBorder:SetHeight(18)
    if barBorder.SetBackdrop then
        barBorder:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
                                bgFile = "Interface\\Buttons\\WHITE8X8", insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        barBorder:SetBackdropColor(0, 0, 0, 0.6)
        barBorder:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
    end
    local bar = CreateFrame("StatusBar", nil, barBorder)
    bar:SetPoint("TOPLEFT", 3, -3)
    bar:SetPoint("BOTTOMRIGHT", -3, 3)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER", 0, 0)
    box.bar = bar

    -- today's hearts
    box.today = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    box.today:SetPoint("TOPLEFT", 12, -56)
    box.today:SetText("Today")
    box.hearts = {}
    for i = 1, B.HEARTS_PER_DAY do
        local h = box:CreateTexture(nil, "ARTWORK")
        h:SetSize(20, 20)
        h:SetPoint("LEFT", box.today, "RIGHT", 8 + (i - 1) * 24, 0)
        h:SetTexture(B.HEART_EMPTY)
        h.base = 20
        box.hearts[i] = h
    end
    box.reset = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    box.reset:SetPoint("TOPRIGHT", -12, -58)

    local sep = box:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 10, -76)
    sep:SetPoint("TOPRIGHT", -10, -76)
    sep:SetHeight(1)
    sep:SetColorTexture(0.6, 0.5, 0.2, 0.5)

    -- today's challenges (filled in by UpdateActions)
    box.rows = {}
    for i = 1, B.DAILY_COUNT do
        local r = CreateFrame("Frame", nil, box)
        r:SetHeight(ACTION_ROW_H)
        r:SetPoint("TOPLEFT", 10, -80 - (i - 1) * ACTION_ROW_H)
        r:SetPoint("TOPRIGHT", -10, -80 - (i - 1) * ACTION_ROW_H)
        r:EnableMouse(true)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(18, 18)
        r.icon:SetPoint("LEFT", 2, 0)
        r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        r.name = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
        r.status = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        r.status:SetPoint("RIGHT", -24, 0)
        r.name:SetPoint("RIGHT", r.status, "LEFT", -6, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.mark = r:CreateTexture(nil, "ARTWORK")
        r.mark:SetSize(16, 16)
        r.mark:SetPoint("RIGHT", -2, 0)
        r:SetScript("OnEnter", function(self)
            if not self.action then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.action.name, 1, 0.82, 0)
            GameTooltip:AddLine(self.action.desc, 1, 1, 1, true)
            GameTooltip:AddLine(("Earns a heart (+%d happiness) while today's hearts last, then +%d bonus.")
                :format(B.HEART_POINTS, B.BONUS_POINTS), 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        box.rows[i] = r
    end

    local top2 = -80 - B.DAILY_COUNT * ACTION_ROW_H - 4
    local sep2 = box:CreateTexture(nil, "ARTWORK")
    sep2:SetPoint("TOPLEFT", 10, top2)
    sep2:SetPoint("TOPRIGHT", -10, top2)
    sep2:SetHeight(1)
    sep2:SetColorTexture(0.6, 0.5, 0.2, 0.5)

    -- "Together": today's total and the next time-together point; hover for every way to earn
    local together = CreateFrame("Frame", nil, box)
    together:SetPoint("TOPLEFT", 10, top2 - 4)
    together:SetPoint("TOPRIGHT", -10, top2 - 4)
    together:SetHeight(20)
    together:EnableMouse(true)
    together.left = together:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    together.left:SetPoint("LEFT", 2, 0)
    together.right = together:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    together.right:SetPoint("RIGHT", -2, 0)
    together:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("More ways to make your companion happy", 1, 0.82, 0)
        for _, t in ipairs(B.TOGETHER) do
            GameTooltip:AddDoubleLine(("|T%s:14:14|t %s"):format(t.icon, t.name), t.text, 1, 1, 1, 0.5, 1, 0.5)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(("+%d%% on everything while your companion runs alongside you."):format(B.SUMMON_BONUS * 100), 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    together:SetScript("OnLeave", function() GameTooltip:Hide() end)
    box.together = together

    -- Walk together: distance milestones (3k, 6k, 8k, 10k yards, then every 5k)
    local walk = UI.NewWalkBar(box, 20)
    walk:SetPoint("TOPLEFT", 8, top2 - 27)
    walk:SetPoint("TOPRIGHT", -8, top2 - 27)
    box.walk = walk

    box.bonus = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    box.bonus:SetPoint("BOTTOMLEFT", 12, 9)
    box.bonus:SetPoint("BOTTOMRIGHT", -12, 9)
    box.bonus:SetJustifyH("LEFT")

    -- keep timers, cooldowns and the day change up to date
    local acc = 0
    box:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc >= 1 then
            acc = 0
            UI:UpdateActions()
        end
    end)
end

-- Pet and Play buttons on the portrait.
local function UpdateCareButton(b, left)
    local ready = left <= 0
    b.icon:SetDesaturated(not ready)
    b.shade:SetShown(not ready)
    b.cd:SetText(ready and "" or FormatTime(left))
end

local function BuildCareButtons(parent, anchor, level)
    local B = ns.Buddy
    local function Make(icon, label, tipTitle, tipText, onClick)
        local b = CreateFrame("Button", nil, parent)
        b:SetSize(36, 36)
        b:SetFrameLevel(level)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexture(icon)
        b.shade = b:CreateTexture(nil, "OVERLAY")
        b.shade:SetAllPoints()
        b.shade:SetColorTexture(0, 0, 0, 0.55)
        b.shade:Hide()
        b.cd = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.cd:SetPoint("CENTER", 0, 0)
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.label:SetPoint("TOP", b, "BOTTOM", 0, -2)
        b.label:SetText(label)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(tipTitle, 1, 1, 1)
            GameTooltip:AddLine(tipText, 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end
    local function Warn(msg)
        if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(msg, 1, 0.5, 0.25) end
    end
    local pet = Make(B.MEDIA .. "Paw", "Pet", "Pet your companion",
        ("+%d happiness. Once every 15 minutes."):format(B.PET_POINTS),
        function() local ok, why = B:Pet(); if not ok then Warn(why) end end)
    pet:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -8, -8)
    local play = Make(B.MEDIA .. "Ball", "Play", "Play fetch",
        ("Catch the ball 3 times in 10 seconds: +%d happiness. Once every 20 minutes."):format(B.FETCH_POINTS),
        function() ns.Fetch:Open() end)
    play:SetPoint("TOP", pet, "BOTTOM", 0, -18)
    return pet, play
end

-- Fill the actions box for the chosen companion.
function UI:UpdateActions()
    if not (frame and frame.actions and frame.actions.rows) then return end
    local B, J = ns.Buddy, ns.Journal
    local box = frame.actions
    local id = B:ChosenID()
    local chosen = id and J:Get(id)
    local r = chosen and B:Record(id)

    local happy = r and r.happy or 0
    local _, level, nextLevel = B:Level(happy)
    box.level:SetText(B.ColorText(level.color, level.name))
    box.bar:SetStatusBarColor(level.color[1], level.color[2], level.color[3])
    if nextLevel then
        box.bar:SetMinMaxValues(level.at, nextLevel.at)
        box.bar:SetValue(happy)
        box.bar.text:SetText(("%d / %d  to %s"):format(happy - level.at, nextLevel.at - level.at, nextLevel.name))
    else
        box.bar:SetMinMaxValues(0, 1)
        box.bar:SetValue(1)
        box.bar.text:SetText("Soulbound: together forever!")
    end

    local hearts = r and r.hearts or 0
    for i, h in ipairs(box.hearts) do
        h:SetTexture(i <= hearts and B.HEART_FULL or B.HEART_EMPTY)
    end

    local _, secs = B:DayKey()
    local capped = hearts >= B.HEARTS_PER_DAY
    box.reset:SetText((capped and "Hearts full. New ones in " or "New hearts in ") .. FormatTime(secs))

    local actions = B:TodayActions(r)
    for i, row in ipairs(box.rows) do
        local a = actions[i]
        row.action = a
        if a then
            row.icon:SetTexture(a.icon)
            row.name:SetText(a.name)
            local done = r and r.done[a.key]
            local dim = (not chosen) or done
            row.name:SetTextColor(dim and 0.5 or 1, dim and 0.5 or 1, dim and 0.5 or 1)
            row.icon:SetDesaturated(dim and true or false)
            if r then
                local text, mark = UI.ChallengeState(r, a, capped)
                row.status:SetText(text)
                row.mark:SetTexture(mark)
                row.mark:SetShown(mark ~= nil)
            else
                row.status:SetText("")
                row.mark:Hide()
            end
            row:Show()
        else
            row:Hide()
        end
    end

    -- together line
    local t = box.together
    t.left:SetText(("Today: |cffffffff+%d|r happiness"):format(r and r.today or 0))
    if not chosen then
        t.right:SetText("")
    elseif J.summonedID == id then
        t.right:SetText(("Time together: next +%d in %s"):format(B.TIME_POINTS, FormatTime(B.TIME_EVERY - (r.timeAcc or 0))))
    else
        t.right:SetText("|cff9d9d9dSummon it to earn time together|r")
    end

    -- walk together
    if r then
        UI.SetWalkBar(box.walk, r, false)
        box.walk:Show()
    else
        box.walk:Hide()
    end

    -- pet / play cooldowns
    if frame.petBtn then
        UpdateCareButton(frame.petBtn, chosen and B:CooldownLeft("pet") or 0)
        UpdateCareButton(frame.playBtn, chosen and B:CooldownLeft("fetch") or 0)
        frame.petBtn:SetShown(chosen and true or false)
        frame.playBtn:SetShown(chosen and true or false)
    end

    local pct = math.floor(B.SUMMON_BONUS * 100 + 0.5)
    if not chosen then
        box.bonus:SetText("Choose a companion to start earning happiness.")
    elseif J.summonedID == id then
        box.bonus:SetText(("|cff40ff40+%d%% happiness while %s runs alongside you.|r"):format(pct, chosen.name))
    else
        box.bonus:SetText(("Summon %s for +%d%% happiness from everything."):format(chosen.name, pct))
    end
end

-- "+N" floating up from the portrait when happiness is gained.
local floaters = {}
local function Float(parent, anchor, text, size)
    local fs
    for _, f in ipairs(floaters) do
        if not f.busy and f:GetParent() == parent then fs = f break end
    end
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        floaters[#floaters + 1] = fs
    end
    fs.busy = true
    fs:SetText(text)
    fs:SetTextColor(1, 0.45, 0.6)
    fs:Show()
    local t, x = 0, math.random(-20, 20)
    local driver = fs.driver or CreateFrame("Frame", nil, parent)
    fs.driver = driver
    driver:SetScript("OnUpdate", function(self, dt)
        t = t + dt
        local k = math.min(1, t / 1.4)
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", anchor, "CENTER", x, 10 + k * (size or 60))
        fs:SetAlpha(1 - k * k)
        if k >= 1 then
            fs:Hide()
            fs.busy = false
            self:SetScript("OnUpdate", nil)
        end
    end)
end

function UI:OnGain(points)
    local text = ("+%d %s"):format(points, ns.Buddy.HeartIcon(16))
    if frame and frame:IsShown() and frame.model then Float(frame.right, frame.model, text, 70) end
    if ns.Tracker and ns.Tracker.Float then ns.Tracker:Float(text) end
    self:Refresh()
end

-- Little pop on the heart that was just filled.
function UI:OnHeartEarned(n)
    self:Refresh()
    if ns.Tracker then ns.Tracker:PopHeart(n) end
    if not (frame and frame:IsShown() and frame.actions.hearts) then return end
    local h = frame.actions.hearts[n]
    if not h then return end
    local t = 0
    local animator = frame.heartAnim or CreateFrame("Frame", nil, frame)
    frame.heartAnim = animator
    animator:SetScript("OnUpdate", function(self, dt)
        t = t + dt
        local k = math.min(1, t / 0.45)
        local size = h.base + math.sin(k * math.pi) * 12
        h:SetSize(size, size)
        if k >= 1 then
            h:SetSize(h.base, h.base)
            self:SetScript("OnUpdate", nil)
        end
    end)
end

function UI:Build()
    if frame then return end

    local f, tmpl = NewFrame("Frame", "MariscosCompanionKeeperFrame", UIParent,
        { "PortraitFrameTemplate", "ButtonFrameTemplate", "BasicFrameTemplateWithInset" })
    frame = f
    local hasPortrait = (tmpl == "PortraitFrameTemplate" or tmpl == "ButtonFrameTemplate")

    f:SetSize(EXPANDED_W, WIN_H)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    f:Hide()
    tinsert(UISpecialFrames, "MariscosCompanionKeeperFrame")

    if tmpl == "ButtonFrameTemplate" and f.Inset then f.Inset:Hide() end
    if not hasPortrait and tmpl ~= "BasicFrameTemplateWithInset" then
        PlainBackdrop(f, false)
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        f.CloseButton = close
    end
    if f.InsetBg then f.InsetBg:Hide() end
    if hasPortrait then SetPortrait(f, ns.ICON) end
    SetWindowTitle(f, FullTitle(), hasPortrait)

    -- minimize: close the window and keep a small tracker on screen
    local mini = CreateFrame("Button", nil, f)
    mini:SetSize(24, 24)
    local closeBtn = f.CloseButton or f.closeButton
    if closeBtn then
        mini:SetPoint("RIGHT", closeBtn, "LEFT", 4, 0)
    else
        mini:SetPoint("TOPRIGHT", f, "TOPRIGHT", -26, -1)
    end
    mini:SetFrameLevel((closeBtn and closeBtn:GetFrameLevel() or f:GetFrameLevel() + 5))
    mini:SetNormalTexture("Interface\\Buttons\\UI-Panel-SmallerButton-Up")
    mini:SetPushedTexture("Interface\\Buttons\\UI-Panel-SmallerButton-Down")
    mini:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    mini:SetScript("OnClick", function() UI:Minimize() end)
    mini:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Minimize", 1, 1, 1)
        GameTooltip:AddLine("Keep a small tracker on screen while you play.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    mini:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.minimize = mini

    f:SetScript("OnShow", function()
        Sound("IG_CHARACTER_INFO_OPEN", 839)
        ns.Journal:RequestScan(0.05)
        UI:Refresh()
        if ns.Tracker then ns.Tracker:OnMainShown(true) end
    end)
    f:SetScript("OnHide", function()
        Sound("IG_CHARACTER_INFO_CLOSE", 840)
        if ns.Tracker then ns.Tracker:OnMainShown(false) end
    end)

    local top = hasPortrait and -62 or -32
    f.contentTop = top

    -- header line
    f.count = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.count:SetPoint("TOPLEFT", f, "TOPLEFT", hasPortrait and 66 or 16, -36)
    f.hint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.hint:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -40)
    f.hint:SetText("Companions are shared by your whole account")

    -- left: companion list (collapsible)
    local holder = CreateFrame("Frame", nil, f)
    holder:SetPoint("TOPLEFT", f, "TOPLEFT", 12, top)
    holder:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 30)
    holder:SetWidth(LIST_W)
    if holder.SetClipsChildren then pcall(holder.SetClipsChildren, holder, true) end
    f.listHolder = holder

    local left = NewInset(holder)
    left:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    left:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
    left:SetWidth(LIST_W)
    f.left = left
    f.animator = CreateFrame("Frame", nil, f)

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
    child:SetSize(LIST_W - 32, 1)
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

    -- right: companion panel
    local right = NewInset(f)
    f.right = right

    -- 3D portrait
    local stage = right:CreateTexture(nil, "BACKGROUND", nil, 1)
    stage:SetPoint("TOPLEFT", 4, -4)
    stage:SetPoint("TOPRIGHT", -4, -4)
    stage:SetHeight(STAGE_H)
    stage:SetColorTexture(0.06, 0.05, 0.03, 0.75)
    f.stage = stage

    local model = CreateFrame("PlayerModel", nil, right)
    model:SetPoint("TOPLEFT", stage, "TOPLEFT", 6, -6)
    model:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT", -6, STRIP_H)
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
    model:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText("Drag to turn", 1, 1, 1)
        GameTooltip:Show()
    end)
    model:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.model = model

    f.modelIcon = right:CreateTexture(nil, "ARTWORK")
    f.modelIcon:SetSize(80, 80)
    f.modelIcon:SetPoint("CENTER", model, "CENTER")
    f.modelIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.modelIcon:Hide()

    -- show / hide the companion list
    local collapse = CreateFrame("Button", nil, right)
    collapse:SetSize(28, 28)
    collapse:SetPoint("TOPLEFT", stage, "TOPLEFT", 4, -4)
    collapse:SetFrameLevel(model:GetFrameLevel() + 2)
    collapse:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    collapse:SetScript("OnClick", function() UI:ToggleList() end)
    collapse:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.db.collapsed and "Show your companions" or "Hide your companions", 1, 1, 1)
        GameTooltip:Show()
    end)
    collapse:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.collapse = collapse

    -- Pet and Play on the portrait
    f.petBtn, f.playBtn = BuildCareButtons(right, stage, model:GetFrameLevel() + 3)

    -- name, status and Summon button on the bottom of the portrait
    local strip = CreateFrame("Frame", nil, right)
    strip:SetPoint("BOTTOMLEFT", stage, "BOTTOMLEFT", 0, 0)
    strip:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT", 0, 0)
    strip:SetHeight(STRIP_H)
    strip:SetFrameLevel(model:GetFrameLevel() + 1)
    strip.bg = strip:CreateTexture(nil, "BACKGROUND")
    strip.bg:SetAllPoints()
    strip.bg:SetColorTexture(0, 0, 0, 0.55)
    strip.line = strip:CreateTexture(nil, "BORDER")
    strip.line:SetPoint("TOPLEFT")
    strip.line:SetPoint("TOPRIGHT")
    strip.line:SetHeight(1)
    strip.line:SetColorTexture(1, 0.82, 0, 0.35)
    f.strip = strip

    local summon = NewFrame("Button", nil, strip, { "UIPanelButtonTemplate" })
    summon:SetSize(100, 24)
    summon:SetPoint("RIGHT", strip, "RIGHT", -10, 0)
    summon:SetScript("OnClick", function() UI:SummonChosen() end)
    f.summon = summon

    -- Mini window: close this window and keep the small companion window on screen
    local miniBtn = NewFrame("Button", nil, strip, { "UIPanelButtonTemplate" })
    miniBtn:SetSize(100, 24)
    miniBtn:SetPoint("RIGHT", summon, "LEFT", -4, 0)
    miniBtn:SetText("Mini window")
    miniBtn:SetScript("OnClick", function() UI:Minimize() end)
    miniBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Mini window", 1, 1, 1)
        GameTooltip:AddLine("Close this window and keep a small companion window on screen, with "
            .. "the happiness bar, today's hearts and challenges, while you play.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    miniBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.miniBtn = miniBtn

    f.petName = strip:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    f.petName:SetPoint("BOTTOMLEFT", strip, "LEFT", 12, 1)
    f.petName:SetPoint("RIGHT", miniBtn, "LEFT", -6, 0)
    f.petName:SetJustifyH("LEFT")
    f.petName:SetWordWrap(false)

    f.petStatus = strip:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    f.petStatus:SetPoint("TOPLEFT", strip, "LEFT", 12, -3)
    f.petStatus:SetPoint("RIGHT", miniBtn, "LEFT", -6, 0)
    f.petStatus:SetWordWrap(false)
    f.petStatus:SetJustifyH("LEFT")

    -- companion actions: happiness, hearts and daily actions
    local actions = CreateFrame("Frame", nil, right, BackdropTemplateMixin and "BackdropTemplate" or nil)
    actions:SetPoint("TOPLEFT", stage, "BOTTOMLEFT", 6, -8)
    actions:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -10, 10)
    if actions.SetBackdrop then
        actions:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
                              bgFile = "Interface\\Buttons\\WHITE8X8", insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        actions:SetBackdropColor(0, 0, 0, 0.3)
        actions:SetBackdropBorderColor(0.6, 0.5, 0.2, 0.6)
    end
    BuildActions(actions)
    f.actions = actions

    -- footer
    f.footer = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 11)

    -- empty / loading / no-API overlay
    local over = CreateFrame("Frame", nil, f)
    over:SetPoint("TOPLEFT", f, "TOPLEFT", 12, top)
    over:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 30)
    over:SetFrameLevel(right:GetFrameLevel() + 10)
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
    over.text:SetPoint("LEFT", over, "LEFT", 20, 0)
    over.text:SetPoint("RIGHT", over, "RIGHT", -20, 0)
    over.text:SetJustifyH("CENTER")
    over:Hide()
    f.overlay = over

    UI:RestorePosition()
    ApplyLayout(false)
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
    frame.modelIcon:SetTexture(p.icon)
    frame.modelIcon:SetShown(not shown)
end

local function UpdateDetail()
    local J = ns.Journal
    local sel = ns.db.selected
    local p = sel and J:Get(sel.id)
    if not p then
        -- nothing chosen yet: show the first companion, button chooses + summons it
        p = J.pets[1]
    end
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
    local out = (J.summonedID == p.id)
    if out then
        frame.petStatus:SetText(STATUS_OUT)
        frame.petStatus:SetTextColor(0.25, 1, 0.25)
    else
        frame.petStatus:SetText(STATUS_CAGE)
        frame.petStatus:SetTextColor(1, 0.3, 0.3)
    end
    frame.summon.petID = p.id
    frame.summon:SetText(out and "Summon back" or "Summon")
    frame.summon:SetEnabled(GetTime() >= busyUntil)
    UI:UpdateActions()
end

function UI:Refresh()
    self:UpdateMinimapIcon()
    if ns.Tracker then ns.Tracker:Update() end
    if not frame or not frame:IsShown() then return end
    local J = ns.Journal

    if J.state ~= "ready" then
        ShowOverlay(J.state)
        frame.left:Hide()
        frame.right:Hide()
        frame.collapse:Hide()
        frame.count:SetText(J.state == "loading" and "" or "Companions owned: |cffffffff0|r")
        return
    end
    frame.overlay:Hide()
    frame.collapse:Show()
    frame.left:SetShown(slide < 1)

    wipe(shownList)
    for _, p in ipairs(J.pets) do
        if filterText == "" or strlower(p.name):find(filterText, 1, true)
           or (p.speciesName and strlower(p.speciesName):find(filterText, 1, true)) then
            shownList[#shownList + 1] = p
        end
    end

    if filterText ~= "" and not ns.db.collapsed then
        frame.count:SetText(("Companions owned: |cffffffff%d|r  |cff9d9d9d(showing %d)|r"):format(#J.pets, #shownList))
    else
        frame.count:SetText(("Companions owned: |cffffffff%d|r"):format(#J.pets))
    end

    local child = frame.scrollChild
    child:SetWidth(LIST_W - 32)
    local sel = ns.db.selected
    for i, p in ipairs(shownList) do
        local r = rows[i] or CreateRow(child, i)
        r.petID = p.id
        r.icon:SetTexture(p.icon)
        r.name:SetText(p.name)
        if J.summonedID == p.id then
            r.sub:SetText(STATUS_OUT)
            r.sub:SetTextColor(0.25, 1, 0.25)
        else
            r.sub:SetText(STATUS_CAGE)
            r.sub:SetTextColor(0.8, 0.3, 0.3)
        end
        local isChosen = sel and sel.id == p.id
        r.check:SetShown(isChosen)
        r.sel:SetShown(isChosen)
        r.name:SetFontObject(isChosen and "GameFontNormal" or "GameFontHighlight")
        r:Show()
    end
    for i = #shownList + 1, #rows do rows[i]:Hide() end
    child:SetHeight(math.max(1, #shownList * ROW_H))
    frame.noMatch:SetShown(#shownList == 0)
    C_Timer.After(0, UpdateScrollbar)

    UpdateDetail()
end

-- Clicking a companion in the list makes it yours.
function UI:Choose(id)
    local p = ns.Journal:Get(id)
    if not p then return end
    local sel = ns.db.selected
    if sel and sel.id == p.id then return end
    ns.db.selected = { id = p.id, name = p.name, speciesID = p.speciesID }
    Sound("IG_MAINMENU_OPTION_CHECKBOX_ON", 856)
    self:Refresh()
end

-- Summon your companion, or send it back to its cage if it's already out.
function UI:SummonChosen()
    if GetTime() < busyUntil then return end
    local J = ns.Journal
    local sel = ns.db.selected
    if not (sel and J:Get(sel.id)) then
        -- nothing chosen yet: the companion on show becomes yours
        local first = (frame and frame.summon and frame.summon.petID) or (J.pets[1] and J.pets[1].id)
        if not first then
            ns.Print("you have no companions to summon.")
            return
        end
        self:Choose(first)
        sel = ns.db.selected
    end
    local ok, msg = J:ToggleSummon(sel.id)
    if not ok then
        if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(msg, 1, 0.1, 0.1) end
        ns.Print("|cffff4040" .. msg .. "|r")
        return
    end
    -- short pause so a double click doesn't summon and dismiss straight away
    if frame then
        busyUntil = GetTime() + 1.2
        self:Refresh()
        C_Timer.After(1.25, function() UI:Refresh() end)
    end
end

function UI:Toggle()
    self:Build()
    frame:SetShown(not frame:IsShown())
end

function UI:Open()
    self:Build()
    frame:Show()
end

function UI:IsMainShown()
    return frame and frame:IsShown() or false
end

-- Close the window and show the small tracker instead.
function UI:Minimize()
    ns.db.tracker.shown = true
    if frame then frame:Hide() end   -- OnHide brings the tracker up
    ns.Tracker:Show()
end

function UI:ResetPositions()
    if frame then self:RestorePosition() end
    if ns.Tracker then ns.Tracker:ResetPosition() end
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
        elseif IsShiftKeyDown() then
            UI:SummonChosen()
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
        GameTooltip:AddLine("Shift-click: summon / summon back", 1, 1, 1)
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
