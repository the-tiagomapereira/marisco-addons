-- Marisco's Companion Keeper - Tracker
-- The minimized view: a small movable panel with your companion, its happiness bar, today's
-- hearts and the daily challenges, so you can play with the main window closed.

local ADDON, ns = ...

local T = {}
ns.Tracker = T

local WIDTH  = 270
local ROW_H  = 17
local TOP_H  = 86    -- portrait, name, hearts and bar
local f

local function Sound(kit, fallback)
    local id = SOUNDKIT and SOUNDKIT[kit] or fallback
    if id then pcall(PlaySound, id) end
end

local function Backdrop(frame, edgeSize, bgAlpha, border)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = edgeSize,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.05, 0.04, 0.03, bgAlpha)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], 1)
end

local function SavePosition()
    local point, _, relPoint, x, y = f:GetPoint(1)
    if point then ns.db.tracker.pos = { point, relPoint, x, y } end
end

local function RestorePosition()
    f:ClearAllPoints()
    local p = ns.db.tracker.pos
    if type(p) == "table" and p[1] then
        f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
    else
        f:SetPoint("RIGHT", UIParent, "RIGHT", -60, 120)
    end
end

function T:Build()
    if f then return end
    local B = ns.Buddy
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    f = CreateFrame("Frame", "MariscosCompanionKeeperTracker", UIParent, template)
    f:SetWidth(WIDTH)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    Backdrop(f, 14, 0.85, { 0.6, 0.5, 0.2 })
    f:Hide()

    -- portrait: click to summon / summon back
    local pf = CreateFrame("Button", nil, f, template)
    pf:SetSize(50, 50)
    pf:SetPoint("TOPLEFT", 8, -8)
    if pf.SetBackdrop then
        pf:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                         edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        pf:SetBackdropColor(0.06, 0.05, 0.03, 0.9)
        pf:SetBackdropBorderColor(0.8, 0.65, 0.2, 1)
    end
    pf:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    pf:SetScript("OnClick", function() ns.UI:SummonChosen() end)
    pf:SetScript("OnEnter", function(self)
        local out = ns.Journal.summonedID and ns.Journal.summonedID == ns.Buddy:ChosenID()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(out and "Click: Summon back" or "Click: Summon", 1, 1, 1)
        GameTooltip:AddLine("Drag the panel to move it.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    pf:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.portrait = pf

    local model = CreateFrame("PlayerModel", nil, pf)
    model:SetPoint("TOPLEFT", 3, -3)
    model:SetPoint("BOTTOMRIGHT", -3, 3)
    f.model = model
    f.icon = pf:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("TOPLEFT", 4, -4)
    f.icon:SetPoint("BOTTOMRIGHT", -4, 4)
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.icon:Hide()

    -- top-right: back to the full window, close
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() T:Close() end)
    local expand = CreateFrame("Button", nil, f)
    expand:SetSize(24, 24)
    expand:SetPoint("RIGHT", close, "LEFT", 4, 0)
    expand:SetNormalTexture("Interface\\Buttons\\UI-Panel-BiggerButton-Up")
    expand:SetPushedTexture("Interface\\Buttons\\UI-Panel-BiggerButton-Down")
    expand:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    expand:SetScript("OnClick", function() T:Expand() end)
    expand:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Open the full window", 1, 1, 1)
        GameTooltip:Show()
    end)
    expand:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- name, status, hearts
    f.name = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.name:SetPoint("TOPLEFT", pf, "TOPRIGHT", 8, -1)
    f.name:SetPoint("RIGHT", expand, "LEFT", -2, 0)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    f.status = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    f.status:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3)
    f.status:SetPoint("RIGHT", f, "RIGHT", -8, 0)
    f.status:SetJustifyH("LEFT")
    f.hearts = {}
    for i = 1, B.HEARTS_PER_DAY do
        local h = f:CreateTexture(nil, "ARTWORK")
        h:SetSize(16, 16)
        h:SetPoint("TOPLEFT", f.status, "BOTTOMLEFT", (i - 1) * 18, -3)
        h:SetTexture(B.HEART_EMPTY)
        h.base = 16
        f.hearts[i] = h
    end

    -- happiness bar
    local border = CreateFrame("Frame", nil, f, template)
    border:SetPoint("TOPLEFT", 6, -62)
    border:SetPoint("TOPRIGHT", -6, -62)
    border:SetHeight(18)
    if border.SetBackdrop then
        border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
                             bgFile = "Interface\\Buttons\\WHITE8X8", insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        border:SetBackdropColor(0, 0, 0, 0.6)
        border:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
    end
    local bar = CreateFrame("StatusBar", nil, border)
    bar:SetPoint("TOPLEFT", 3, -3)
    bar:SetPoint("BOTTOMRIGHT", -3, 3)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER", 0, 0)
    f.bar = bar

    -- Pet and Play, right of the hearts
    local function Mini(icon, tip, onClick)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(20, 20)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexture(icon)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(tip, 1, 1, 1)
            local left = self.left or 0
            if left > 0 then GameTooltip:AddLine("Ready in " .. B.FormatTime(left), 1, 0.5, 0.25) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end
    local function Warn(msg)
        if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(msg, 1, 0.5, 0.25) end
    end
    f.play = Mini(B.MEDIA .. "Ball", "Play fetch", function() ns.Fetch:Open() end)
    f.play:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -40)
    f.pet = Mini(B.MEDIA .. "Paw", "Pet your companion", function()
        local ok, why = B:Pet()
        if not ok then Warn(why) end
    end)
    f.pet:SetPoint("RIGHT", f.play, "LEFT", -4, 0)

    -- floating "+N"
    f.float = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.float:Hide()

    -- today's challenges (filled in by Update)
    f.rows = {}
    for i = 1, B.DAILY_COUNT do
        local r = CreateFrame("Frame", nil, f)
        r:SetHeight(ROW_H)
        r:SetPoint("TOPLEFT", 10, -TOP_H - (i - 1) * ROW_H)
        r:SetPoint("TOPRIGHT", -10, -TOP_H - (i - 1) * ROW_H)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(14, 14)
        r.icon:SetPoint("LEFT", 0, 0)
        r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        r.name = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
        r.status = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        r.status:SetPoint("RIGHT", -18, 0)
        r.name:SetPoint("RIGHT", r.status, "LEFT", -6, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.mark = r:CreateTexture(nil, "ARTWORK")
        r.mark:SetSize(13, 13)
        r.mark:SetPoint("RIGHT", 0, 0)
        f.rows[i] = r
    end
    f.todayLine = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.todayLine:SetPoint("TOPLEFT", 10, -TOP_H - B.DAILY_COUNT * ROW_H - 2)
    f.todayLine:SetPoint("TOPRIGHT", -10, -TOP_H - B.DAILY_COUNT * ROW_H - 2)
    f.todayLine:SetJustifyH("LEFT")
    f.walk = ns.UI.NewWalkBar(f, 16)
    f.walk:SetPoint("TOPLEFT", f.todayLine, "BOTTOMLEFT", -4, -4)
    f.walk:SetPoint("TOPRIGHT", f.todayLine, "BOTTOMRIGHT", 4, -4)
    f:SetHeight(TOP_H + B.DAILY_COUNT * ROW_H + 50)

    -- day change / reset timer
    local acc = 0
    f:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc >= 1 then
            acc = 0
            T:Update()
        end
    end)

    RestorePosition()
end

function T:Update()
    if not (f and f:IsShown()) then return end
    local B, J = ns.Buddy, ns.Journal
    local id = B:ChosenID()
    local p = id and J:Get(id)

    if not p then
        f.name:SetText(ns.TITLE)
        f.status:SetText(J.state == "loading" and "|cff9d9d9dReading your Companion Journal...|r"
                                              or "|cff9d9d9dNo companion chosen yet.|r")
        f.status:SetTextColor(1, 1, 1)
        f.model:Hide()
        f.icon:SetTexture(ns.ICON)
        f.icon:Show()
        f.model.petID = nil
    else
        if f.model.petID ~= p.id then
            f.model.petID = p.id
            pcall(f.model.ClearModel, f.model)
            local shown = false
            if p.displayID and p.displayID ~= 0 then shown = pcall(f.model.SetDisplayInfo, f.model, p.displayID) end
            if not shown and p.creatureID and p.creatureID ~= 0 then shown = pcall(f.model.SetCreature, f.model, p.creatureID) end
            pcall(f.model.SetFacing, f.model, 0.5)
            pcall(f.model.SetPortraitZoom, f.model, 0.6)
            f.model:SetShown(shown)
            f.icon:SetTexture(p.icon)
            f.icon:SetShown(not shown)
        end
        f.name:SetText(p.name)
        if J.summonedID == p.id then
            f.status:SetText("Running alongside you")
            f.status:SetTextColor(0.25, 1, 0.25)
        else
            f.status:SetText("In its cage")
            f.status:SetTextColor(1, 0.3, 0.3)
        end
    end

    local r = p and B:Record(id)
    local hearts = r and r.hearts or 0
    for i, h in ipairs(f.hearts) do
        h:SetTexture(i <= hearts and B.HEART_FULL or B.HEART_EMPTY)
        h:SetShown(p and true or false)
    end

    local happy = r and r.happy or 0
    local _, level, nextLevel = B:Level(happy)
    f.bar:SetStatusBarColor(level.color[1], level.color[2], level.color[3])
    if nextLevel then
        f.bar:SetMinMaxValues(level.at, nextLevel.at)
        f.bar:SetValue(happy)
        f.bar.text:SetText(("%s  %d / %d"):format(level.name, happy - level.at, nextLevel.at - level.at))
    else
        f.bar:SetMinMaxValues(0, 1)
        f.bar:SetValue(1)
        f.bar.text:SetText(level.name)
    end

    local capped = hearts >= B.HEARTS_PER_DAY
    local actions = B:TodayActions(r)
    for i, row in ipairs(f.rows) do
        local a = actions[i]
        if a then
            row.icon:SetTexture(a.icon)
            row.name:SetText(a.name)
            local done = r and r.done[a.key]
            local dim = (not p) or done
            row.name:SetTextColor(dim and 0.5 or 1, dim and 0.5 or 1, dim and 0.5 or 1)
            row.icon:SetDesaturated(dim and true or false)
            if r then
                local text, mark = ns.UI.ChallengeState(r, a, capped)
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

    f.pet:SetShown(p and true or false)
    f.play:SetShown(p and true or false)
    if p then
        f.pet.left, f.play.left = B:CooldownLeft("pet"), B:CooldownLeft("fetch")
        f.pet.icon:SetDesaturated(f.pet.left > 0)
        f.play.icon:SetDesaturated(f.play.left > 0)
        f.pet:SetAlpha(f.pet.left > 0 and 0.6 or 1)
        f.play:SetAlpha(f.play.left > 0 and 0.6 or 1)
        f.todayLine:SetText(("Today: |cffffffff+%d|r happiness"):format(r.today or 0))
        ns.UI.SetWalkBar(f.walk, r, true)
        f.walk:Show()
    else
        f.todayLine:SetText("")
        f.walk:Hide()
    end
end

-- "+N" floating up from the portrait.
function T:Float(text)
    if not (f and f:IsShown()) then return end
    local fs, t = f.float, 0
    fs:SetText(text)
    fs:SetTextColor(1, 0.45, 0.6)
    fs:Show()
    local driver = f.floatDriver or CreateFrame("Frame", nil, f)
    f.floatDriver = driver
    driver:SetScript("OnUpdate", function(self, dt)
        t = t + dt
        local k = math.min(1, t / 1.2)
        fs:ClearAllPoints()
        fs:SetPoint("BOTTOM", f.portrait, "TOP", 0, -10 + k * 30)
        fs:SetAlpha(1 - k * k)
        if k >= 1 then
            fs:Hide()
            self:SetScript("OnUpdate", nil)
        end
    end)
end

-- Little pop on a heart that was just earned.
function T:PopHeart(n)
    if not (f and f:IsShown() and f.hearts[n]) then return end
    local h, t = f.hearts[n], 0
    local anim = f.anim or CreateFrame("Frame", nil, f)
    f.anim = anim
    anim:SetScript("OnUpdate", function(self, dt)
        t = t + dt
        local k = math.min(1, t / 0.45)
        local size = h.base + math.sin(k * math.pi) * 10
        h:SetSize(size, size)
        if k >= 1 then
            h:SetSize(h.base, h.base)
            self:SetScript("OnUpdate", nil)
        end
    end)
end

-- Show the tracker (it stays on until you close it; it steps aside while the full window is open).
function T:Show()
    self:Build()
    ns.db.tracker.shown = true
    if ns.UI:IsMainShown() then return end
    f:Show()
    self:Update()
end

function T:Close()
    ns.db.tracker.shown = false
    if f then f:Hide() end
    Sound("IG_MAINMENU_CLOSE", 851)
end

function T:Expand()
    if f then f:Hide() end
    ns.UI:Open()
end

-- The full window opened or closed.
function T:OnMainShown(isShown)
    if not ns.db.tracker.shown then return end
    self:Build()
    f:SetShown(not isShown)
    if not isShown then self:Update() end
end

function T:Toggle()
    if ns.db.tracker.shown then
        self:Close()
        ns.Print("mini tracker hidden.")
    else
        self:Show()
    end
end

function T:ResetPosition()
    if f then RestorePosition() end
end
