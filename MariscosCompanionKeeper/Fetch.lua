-- Marisco's Companion Keeper - Fetch
-- A tiny mini-game: catch the bouncing ball 3 times in 10 seconds while your companion watches.

local ADDON, ns = ...

local F = {}
ns.Fetch = F

local NEED       = 3
local TIME_LIMIT = 10
local BALL       = 34
local ARENA_W, ARENA_H = 300, 190

local f, arena, ball
local playing, catches, timeLeft = false, 0, 0

local function Sound(kit, fallback)
    local id = SOUNDKIT and SOUNDKIT[kit] or fallback
    if id then pcall(PlaySound, id) end
end

local function RandomVelocity(speed)
    local angle = math.random() * math.pi * 2
    return math.cos(angle) * speed, math.sin(angle) * speed
end

local function PlaceBall()
    ball.x = math.random(10, ARENA_W - BALL - 10)
    ball.y = math.random(10, ARENA_H - BALL - 10)
    ball.vx, ball.vy = RandomVelocity(140 + catches * 60)
    ball:ClearAllPoints()
    ball:SetPoint("BOTTOMLEFT", arena, "BOTTOMLEFT", ball.x, ball.y)
end

local function UpdateText()
    f.score:SetText(("Catches: |cffffffff%d / %d|r"):format(catches, NEED))
    f.timer:SetValue(math.max(0, timeLeft))
end

local function Finish(won)
    playing = false
    ball:Hide()
    f.start:Show()
    f.start:SetText("Play again")
    if won then
        f.msg:SetText("|cff40ff40Fetched! Your companion is overjoyed.|r")
        Sound("IG_QUEST_LIST_COMPLETE", 878)
        ns.Buddy:FetchWon()
        local ok = ns.Buddy:CanPlay()
        f.start:SetEnabled(ok)
    else
        f.msg:SetText("|cffff8040The ball got away! Try again.|r")
        Sound("IG_QUEST_FAILED", 847)
    end
end

local function Start()
    local ok, why = ns.Buddy:CanPlay()
    if not ok then
        f.msg:SetText("|cffff8040" .. why .. "|r")
        return
    end
    playing, catches, timeLeft = true, 0, TIME_LIMIT
    f.msg:SetText("Click the ball!")
    f.start:Hide()
    ball:Show()
    PlaceBall()
    UpdateText()
end

function F:Build()
    if f then return end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil

    f = CreateFrame("Frame", "MariscosCompanionKeeperFetch", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(ARENA_W + 24, ARENA_H + 96)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    tinsert(UISpecialFrames, "MariscosCompanionKeeperFetch")
    local title = f.TitleText or (f.TitleContainer and f.TitleContainer.TitleText)
    if not title then
        title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", 0, -5)
    end
    title:SetText("Fetch!")

    f.score = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.score:SetPoint("TOPLEFT", 14, -32)

    local timer = CreateFrame("StatusBar", nil, f)
    timer:SetSize(120, 10)
    timer:SetPoint("TOPRIGHT", -16, -35)
    timer:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    timer:SetStatusBarColor(1, 0.82, 0)
    timer:SetMinMaxValues(0, TIME_LIMIT)
    timer.bg = timer:CreateTexture(nil, "BACKGROUND")
    timer.bg:SetAllPoints()
    timer.bg:SetColorTexture(0, 0, 0, 0.6)
    f.timer = timer

    arena = CreateFrame("Frame", nil, f, template)
    arena:SetSize(ARENA_W, ARENA_H)
    arena:SetPoint("TOP", 0, -52)
    if arena.SetBackdrop then
        arena:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        arena:SetBackdropColor(0.10, 0.16, 0.08, 0.95)
        arena:SetBackdropBorderColor(0.6, 0.5, 0.2, 1)
    end
    if arena.SetClipsChildren then pcall(arena.SetClipsChildren, arena, true) end

    -- your companion watching from the corner
    local model = CreateFrame("PlayerModel", nil, arena)
    model:SetSize(90, 90)
    model:SetPoint("BOTTOMLEFT", 4, 4)
    f.model = model

    ball = CreateFrame("Button", nil, arena)
    ball:SetSize(BALL, BALL)
    ball:SetFrameLevel(model:GetFrameLevel() + 5)
    ball.tex = ball:CreateTexture(nil, "ARTWORK")
    ball.tex:SetAllPoints()
    ball.tex:SetTexture(ns.Buddy.MEDIA .. "Ball")
    ball:RegisterForClicks("LeftButtonDown")
    ball:SetScript("OnClick", function()
        if not playing then return end
        catches = catches + 1
        Sound("IG_MAINMENU_OPTION_CHECKBOX_ON", 856)
        UpdateText()
        if catches >= NEED then
            Finish(true)
        else
            PlaceBall()
        end
    end)
    ball:Hide()
    f.ball = ball

    f.msg = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    f.msg:SetPoint("TOP", arena, "BOTTOM", 0, -9)
    f.msg:SetWidth(ARENA_W - 110)

    local start = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    start:SetSize(100, 22)
    start:SetPoint("BOTTOMRIGHT", -12, 10)
    start:SetScript("OnClick", Start)
    f.start = start

    f:SetScript("OnUpdate", function(_, dt)
        if not playing then return end
        timeLeft = timeLeft - dt
        if timeLeft <= 0 then
            UpdateText()
            Finish(false)
            return
        end
        ball.x = ball.x + ball.vx * dt
        ball.y = ball.y + ball.vy * dt
        if ball.x < 4 then ball.x, ball.vx = 4, math.abs(ball.vx) end
        if ball.y < 4 then ball.y, ball.vy = 4, math.abs(ball.vy) end
        if ball.x > ARENA_W - BALL - 4 then ball.x, ball.vx = ARENA_W - BALL - 4, -math.abs(ball.vx) end
        if ball.y > ARENA_H - BALL - 4 then ball.y, ball.vy = ARENA_H - BALL - 4, -math.abs(ball.vy) end
        ball:ClearAllPoints()
        ball:SetPoint("BOTTOMLEFT", arena, "BOTTOMLEFT", ball.x, ball.y)
        UpdateText()
    end)
    f:SetScript("OnHide", function()
        playing = false
        ball:Hide()
    end)
end

function F:Open()
    local ok, why = ns.Buddy:CanPlay()
    if not ok then
        if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(why, 1, 0.5, 0.25) end
        ns.Print(why)
        return
    end
    self:Build()
    local p = ns.Journal:Get(ns.Buddy:ChosenID())
    pcall(f.model.ClearModel, f.model)
    local shown = false
    if p and p.displayID and p.displayID ~= 0 then shown = pcall(f.model.SetDisplayInfo, f.model, p.displayID) end
    if not shown and p and p.creatureID and p.creatureID ~= 0 then shown = pcall(f.model.SetCreature, f.model, p.creatureID) end
    pcall(f.model.SetFacing, f.model, 0.6)
    f.model:SetShown(shown)

    playing, catches, timeLeft = false, 0, TIME_LIMIT
    UpdateText()
    f.msg:SetText(("Catch the ball %d times in %d seconds!"):format(NEED, TIME_LIMIT))
    f.start:SetText("Start")
    f.start:SetEnabled(true)
    f.start:Show()
    ball:Hide()
    f:Show()
end

function F:IsPlaying() return playing end
