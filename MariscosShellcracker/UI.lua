-- Marisco's Shellcracker - game window, animations and the makrura fight
local ADDON, ns = ...
local Board = ns.Board

local SIZE = Board.SIZE
local CELL, GEM = 44, 40
local BOARD_PX = SIZE * CELL
local PANEL_W = 206
local WHITE = "Interface\\Buttons\\WHITE8X8"
local RING = "Interface\\Buttons\\UI-ActionButton-Border"
local CRAB_ICON = "Interface\\Icons\\Ability_Hunter_Pet_Crab"

local floor, min, max, sin, abs = math.floor, math.min, math.max, math.sin, math.abs

local UI = {}
ns.UI = UI
local G = {}            -- the running game
ns.Game = G

---------------------------------------------------------------------------
-- small helpers
---------------------------------------------------------------------------
local function comma(n)
    local s = tostring(floor(n or 0))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

local function Sound(kit)
    if not (ns.db and ns.db.sound) then return end
    local id = SOUNDKIT and SOUNDKIT[kit]
    if id then pcall(PlaySound, id) end
end

-- Game sounds by FileDataID (lists in Data.lua). Never the same one twice in a row.
local lastPick = {}
local function SFX(kind)
    if not (ns.db and ns.db.sound and PlaySoundFile) then return end
    local list = ns.SFX[kind]
    if not list then return end
    local pick = list[math.random(#list)]
    if #list > 1 then
        while pick == lastPick[kind] do pick = list[math.random(#list)] end
    end
    lastPick[kind] = pick
    pcall(PlaySoundFile, pick, "SFX")
end

-- the makrura strikes: a melee/weapon impact plus its own attack cry
local function HitSound(crit)
    SFX(crit and "impactCrit" or "impact")
    SFX("mobAttack")
end

-- the makrura takes damage (several cascades in a row don't stack up)
local lastWound = 0
local function WoundSound(big)
    local now = GetTime and GetTime() or 0
    if big then SFX("mobWoundCrit"); SFX("impactCrit"); lastWound = now return end
    if now - lastWound < 0.3 then return end
    lastWound = now
    SFX("mobWound")
end

---------------------------------------------------------------------------
-- Inn music: the game's own inn songs, shuffled, played one after another.
-- The zone music is switched off while they play (otherwise both play at once)
-- and switched back to how it was when the game window closes.
---------------------------------------------------------------------------
local Music = { playing = false }
UI.Music = Music
local musicFrame

local function ShuffledSongs()
    local order = {}
    for i = 1, #ns.INN_SONGS do order[i] = i end
    for i = #order, 2, -1 do
        local j = math.random(i)
        order[i], order[j] = order[j], order[i]
    end
    return order
end

local function MuteZoneMusic()
    if ns.db.zoneMusicCVar == nil and GetCVar then
        ns.db.zoneMusicCVar = GetCVar("Sound_EnableMusic") or "1"
    end
    if SetCVar then SetCVar("Sound_EnableMusic", "0") end
end

function Music:RestoreZoneMusic()
    if ns.db and ns.db.zoneMusicCVar ~= nil then
        if SetCVar then SetCVar("Sound_EnableMusic", ns.db.zoneMusicCVar) end
        ns.db.zoneMusicCVar = nil
    end
end

function Music:PlayNext()
    if not self.order or self.song > #self.order then
        self.order, self.song, self.part = ShuffledSongs(), 1, 1
    end
    local parts = ns.INN_SONGS[self.order[self.song]]
    local id = parts[self.part]
    -- advance the pointer for next time
    self.part = self.part + 1
    if self.part > #parts then self.song, self.part = self.song + 1, 1 end
    local ok, willPlay, handle = pcall(PlaySoundFile, id, "Ambience")
    if not (ok and willPlay) then
        ok, willPlay, handle = pcall(PlaySoundFile, id, "Master")   -- Ambience switched off
    end
    self.handle = (ok and willPlay) and handle or nil
    self.started = GetTime and GetTime() or 0
end

function Music:Start()
    if self.playing then return end
    self.playing = true
    MuteZoneMusic()
    self:PlayNext()
    musicFrame = musicFrame or CreateFrame("Frame")
    local wait = 0
    musicFrame:SetScript("OnUpdate", function(_, el)
        wait = wait + el
        if wait < 0.5 then return end
        wait = 0
        local h = Music.handle
        local done
        if h and C_Sound and C_Sound.IsPlaying then
            done = not C_Sound.IsPlaying(h)
        else
            done = (GetTime() - (Music.started or 0)) > 180   -- no way to ask: move on after 3 minutes
        end
        if done then Music:PlayNext() end
    end)
end

function Music:Stop()
    if not self.playing then return end
    self.playing = false
    if musicFrame then musicFrame:SetScript("OnUpdate", nil) end
    if self.handle and StopSound then pcall(StopSound, self.handle, 1500) end
    self.handle = nil
    self:RestoreZoneMusic()
end

function UI:UpdateMusic()
    if ns.db and ns.db.music and UI:IsShown() then Music:Start() else Music:Stop() end
end

local iconCache = {}
local function GemIcon(color)
    if iconCache[color] then return iconCache[color] end
    local gem = ns.GEMS[color]
    local icon
    if C_Item and C_Item.GetItemIconByID then icon = C_Item.GetItemIconByID(gem.item) end
    if not icon and GetItemIcon then icon = GetItemIcon(gem.item) end
    icon = icon or gem.icon
    iconCache[color] = icon
    return icon
end

local function CellXY(c, r) return (c - 0.5) * CELL, -(r - 0.5) * CELL end

local EASE = {
    linear = function(p) return p end,
    outQuad = function(p) return 1 - (1 - p) * (1 - p) end,
    inQuad = function(p) return p * p end,
    outBack = function(p) local s = 1.7; p = p - 1; return p * p * ((s + 1) * p + s) + 1 end,
}

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------
local f, board, fxLayer, inputFrame, driver

local function MakeWindow()
    local ok, frame = pcall(CreateFrame, "Frame", "MariscosShellcrackerFrame", UIParent, "ButtonFrameTemplate")
    if not ok or not frame then
        ok, frame = pcall(CreateFrame, "Frame", "MariscosShellcrackerFrame", UIParent, "BasicFrameTemplateWithInset")
    end
    if not ok or not frame then frame = CreateFrame("Frame", "MariscosShellcrackerFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate") end
    frame:SetSize(14 + BOARD_PX + 14 + PANEL_W + 14, 64 + BOARD_PX + 52)   -- 52: the strip under the board (buttons, bags)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        ns.db.pos = { p, rp, x, y }
    end)
    if ButtonFrameTemplate_HideButtonBar then pcall(ButtonFrameTemplate_HideButtonBar, frame) end
    if frame.Inset then
        frame.Inset:ClearAllPoints()
        frame.Inset:SetPoint("TOPLEFT", 4, -58)
        frame.Inset:SetPoint("BOTTOMRIGHT", -6, 6)
    end
    local title = "Marisco's Shellcracker - v" .. ns.VERSION
    if frame.SetTitle then frame:SetTitle(title)
    elseif frame.TitleText then frame.TitleText:SetText(title)
    elseif frame.TitleContainer and frame.TitleContainer.TitleText then frame.TitleContainer.TitleText:SetText(title)
    else
        local t = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("TOP", 0, -6); t:SetText(title)
    end
    if frame.SetPortraitToAsset then pcall(frame.SetPortraitToAsset, frame, CRAB_ICON)
    else
        local p = frame.portrait or (frame.PortraitContainer and frame.PortraitContainer.portrait)
        if p then
            if SetPortraitToTexture then SetPortraitToTexture(p, CRAB_ICON) else p:SetTexture(CRAB_ICON) end
        end
    end
    tinsert(UISpecialFrames, "MariscosShellcrackerFrame")
    frame:Hide()
    return frame
end

local function Backdrop(fr, a)
    local bg = fr:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, a or 0.55)
    local edges = {}
    for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 },
                           { "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
        local e = fr:CreateTexture(nil, "BORDER")
        e:SetColorTexture(0.55, 0.45, 0.25, 0.9)
        e:SetPoint(pts[1]); e:SetPoint(pts[2])
        if pts[3] == 1 then e:SetWidth(1) else e:SetHeight(1) end
        edges[i] = e
    end
    fr.edges = edges
    return bg
end

---------------------------------------------------------------------------
-- Animation driver: sprite tweens (counted), free effects, timers
---------------------------------------------------------------------------
local moving, pending, idleCb = {}, 0, nil
local fxList, timers = {}, {}
local clock = 0

local function PlaceSprite(s, x, y, sc)
    sc = sc or s.sc or 1
    s.px, s.py = x, y
    if sc ~= s.sc then s.sc = sc; s:SetScale(max(sc, 0.01)) end
    s:ClearAllPoints()
    s:SetPoint("CENTER", board, "TOPLEFT", x / s.sc, y / s.sc)
end

local function Tween(s, o)
    if not s.tw then pending = pending + 1 end
    s.tw = {
        t = -(o.delay or 0), dur = o.dur or 0.2, ease = EASE[o.ease or "outQuad"],
        fx = s.px, fy = s.py, tx = o.x or s.px, ty = o.y or s.py,
        s0 = o.s0 or s.sc or 1, s1 = o.s1 or o.s0 or s.sc or 1,
        a0 = o.a0, a1 = o.a1, done = o.done,
    }
    moving[s] = true
end

local function WhenIdle(fn) idleCb = fn end
local function After(sec, fn) timers[#timers+1] = { t = sec, fn = fn } end

-- free effect on any region: { region, dur, delay, x0,y0,x1,y1 (CENTER offsets on `rel`), a0,a1, w0,h0,w1,h1, release }
local function FX(o)
    o.t = -(o.delay or 0)
    o.ease = EASE[o.ease or "outQuad"]
    if o.a0 and not o.keep then o.region:SetAlpha(o.t < 0 and 0 or o.a0) end
    o.region:Show()
    fxList[#fxList+1] = o
end

local function DriverUpdate(_, el)
    if G.board and not G.over and not G.paused and ns.Stats then ns.Stats:Tick(el) end
    clock = clock + el
    -- sprites
    local finished
    for s in pairs(moving) do
        local tw = s.tw
        tw.t = tw.t + el
        if tw.t >= 0 then
            local p = min(1, tw.t / tw.dur)
            local e = tw.ease(p)
            PlaceSprite(s, tw.fx + (tw.tx - tw.fx) * e, tw.fy + (tw.ty - tw.fy) * e, tw.s0 + (tw.s1 - tw.s0) * e)
            if tw.a0 then s:SetAlpha(tw.a0 + (tw.a1 - tw.a0) * e) end
            if p >= 1 then
                moving[s] = nil; s.tw = nil; pending = pending - 1
                if tw.done then finished = finished or {}; finished[#finished+1] = { tw.done, s } end
            end
        end
    end
    if finished then for _, d in ipairs(finished) do d[1](d[2]) end end
    -- effects
    for i = #fxList, 1, -1 do
        local o = fxList[i]
        o.t = o.t + el
        if o.t >= 0 then
            local p = min(1, o.t / o.dur)
            local e = o.ease(p)
            local r = o.region
            if o.x0 then
                local x = o.x0 + ((o.x1 or o.x0) - o.x0) * e
                local y = o.y0 + ((o.y1 or o.y0) - o.y0) * e
                r:ClearAllPoints(); r:SetPoint("CENTER", o.rel or board, o.relPoint or "TOPLEFT", x, y)
            end
            if o.a0 then r:SetAlpha(o.a0 + (o.a1 - o.a0) * p) end
            if o.w0 then r:SetSize(o.w0 + ((o.w1 or o.w0) - o.w0) * e, o.h0 + ((o.h1 or o.h0) - o.h0) * e) end
            if p >= 1 then
                table.remove(fxList, i)
                if o.release then o.release(r) elseif o.hide then r:Hide() end
                if o.done then o.done() end
            end
        end
    end
    -- timers
    for i = #timers, 1, -1 do
        local t = timers[i]
        t.t = t.t - el
        if t.t <= 0 then table.remove(timers, i); t.fn() end
    end
    if pending == 0 and idleCb then
        local cb = idleCb; idleCb = nil; cb()
    end
    UI:PulseSpecials()
    UI:InputUpdate(el)
end

---------------------------------------------------------------------------
-- Gem sprites
---------------------------------------------------------------------------
local sprites = {}        -- id -> sprite
local spritePool = {}

local function StyleSprite(s, gem)
    s.gem = gem
    s.special = gem.special
    local info = gem.special and ns.SPECIAL_INFO[gem.special]
    if gem.special == "hyper" then
        s.icon:SetTexture(info.icon)
        s.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        s.badge:Hide()
    else
        s.icon:SetTexture(GemIcon(gem.color))
        s.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        s.icon:SetVertexColor(1, 1, 1)
        if info then s.badge:SetTexture(info.icon); s.badge:Show() else s.badge:Hide() end
    end
    if info then
        local rgb = gem.special == "hyper" and { 1, 1, 1 } or ns.GEMS[gem.color].rgb
        if gem.special == "flame" then rgb = info.rgb end
        s.glow:SetVertexColor(rgb[1], rgb[2], rgb[3]); s.glow:Show()
    else
        s.glow:Hide()
    end
end

local function AcquireSprite(gem)
    local s = table.remove(spritePool)
    if not s then
        s = CreateFrame("Frame", nil, board)
        s:SetSize(GEM, GEM)
        s.shadow = s:CreateTexture(nil, "BACKGROUND")
        s.shadow:SetPoint("TOPLEFT", -1, 1); s.shadow:SetPoint("BOTTOMRIGHT", 1, -1)
        s.shadow:SetColorTexture(0, 0, 0, 0.6)
        s.icon = s:CreateTexture(nil, "ARTWORK")
        s.icon:SetAllPoints()
        s.glow = s:CreateTexture(nil, "OVERLAY")
        s.glow:SetTexture(RING); s.glow:SetBlendMode("ADD")
        s.glow:SetPoint("CENTER"); s.glow:SetSize(GEM * 1.8, GEM * 1.8)
        s.badge = s:CreateTexture(nil, "OVERLAY", nil, 2)
        s.badge:SetSize(17, 17); s.badge:SetPoint("BOTTOMRIGHT", 3, -3)
        s.badge:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        -- selection / hint glow: drawn on the gem itself so it sits above it and moves with it
        s.mark = s:CreateTexture(nil, "OVERLAY", nil, 4)
        s.mark:SetTexture(RING); s.mark:SetBlendMode("ADD")
        s.mark:SetPoint("CENTER"); s.mark:SetSize(GEM * 2.0, GEM * 2.0)
        s.markFill = s:CreateTexture(nil, "OVERLAY", nil, 3)
        s.markFill:SetTexture(WHITE); s.markFill:SetBlendMode("ADD")
        s.markFill:SetAllPoints(s.icon)
        -- two comets of light circling the selected gem
        s.orbit = {}
        for i = 1, 8 do
            local t = s:CreateTexture(nil, "OVERLAY", nil, 6)
            t:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
            t:SetBlendMode("ADD")
            t:Hide()
            s.orbit[i] = t
        end
    end
    for _, t in ipairs(s.orbit) do t:Hide() end
    s.markKind = nil
    s.mark:Hide(); s.markFill:Hide()
    s.sc = nil
    s:SetAlpha(1)
    s:SetFrameLevel(board:GetFrameLevel() + 2)
    StyleSprite(s, gem)
    s:Show()
    sprites[gem.id] = s
    return s
end

local function ReleaseSprite(s)
    if UI.selSprite == s then UI.selSprite = nil; UI.sel = nil end
    if UI.hintSprite == s then UI.hintSprite = nil end
    if s.tw then moving[s] = nil; s.tw = nil; pending = pending - 1 end
    if s.gem and sprites[s.gem.id] == s then sprites[s.gem.id] = nil end
    s.gem = nil
    s:Hide()
    spritePool[#spritePool+1] = s
end

function UI:PulseSpecials()
    local a = 0.55 + 0.35 * sin(clock * 5)
    for _, s in pairs(sprites) do
        if s.special then
            s.glow:SetAlpha(a)
            if s.special == "hyper" then
                local t = clock * 2
                s.icon:SetVertexColor(0.6 + 0.4 * sin(t), 0.6 + 0.4 * sin(t + 2.1), 0.6 + 0.4 * sin(t + 4.2))
                s.glow:SetVertexColor(0.6 + 0.4 * sin(t + 1), 0.6 + 0.4 * sin(t + 3.1), 0.6 + 0.4 * sin(t + 5.2))
            end
        end
    end
    local sel = UI.selSprite
    if sel then
        sel.mark:SetAlpha(0.3); sel.markFill:SetAlpha(0.12)
        -- light running around the gem: 2 heads, each with a fading tail
        local base = clock * 4.2
        local R = GEM * 0.56
        for i, t in ipairs(sel.orbit) do
            local head = (i - 1) % 2                  -- which comet
            local k = floor((i - 1) / 2)              -- 0 = head, 1..3 = tail
            local ang = base + head * math.pi - k * 0.3
            local size = 30 - k * 5
            t:ClearAllPoints()
            t:SetPoint("CENTER", sel, "CENTER", math.cos(ang) * R, math.sin(ang) * R)
            t:SetSize(size, size)
            if t.SetRotation then t:SetRotation(ang) end
            t:SetAlpha(1 - k * 0.27)
        end
    end
    local h = UI.hintSprite
    if h and h ~= sel then
        local p = abs(sin(clock * (UI.hintKind == "auto" and 3 or 4)))
        h.mark:SetAlpha(0.35 + 0.65 * p); h.markFill:SetAlpha(0.05 + 0.25 * p)
    end
end

-- glow colors: selected gem, Hint button, automatic hint
local MARK_RGB = {
    select = { 1.00, 0.82, 0.25 },
    manual = { 0.35, 1.00, 0.45 },
    auto   = { 0.35, 0.65, 1.00 },
}

local function SetMark(s, kind)
    if not s then return end
    if not kind then
        -- fall back to the hint glow if this gem still carries it
        if UI.hintSprite == s and UI.selSprite ~= s then kind = UI.hintKind end
    end
    s.markKind = kind
    for _, t in ipairs(s.orbit) do
        if kind == "select" then
            local rgb = MARK_RGB.select
            t:SetVertexColor(rgb[1], rgb[2], rgb[3]); t:Show()
        else
            t:Hide()
        end
    end
    if kind then
        local rgb = MARK_RGB[kind]
        s.mark:SetVertexColor(rgb[1], rgb[2], rgb[3]); s.markFill:SetVertexColor(rgb[1], rgb[2], rgb[3])
        s.mark:Show(); s.markFill:Show()
        if not s.tw then s:SetFrameLevel(board:GetFrameLevel() + 3) end
    else
        s.mark:Hide(); s.markFill:Hide()
        if not s.tw then s:SetFrameLevel(board:GetFrameLevel() + 2) end
    end
end

-- all sprites from the board, dropping in from above (column by column)
local function RebuildSprites(dropIn)
    UI.sel, UI.selSprite, UI.hintSprite, UI.hintKind = nil, nil, nil, nil
    for _, s in pairs(sprites) do s.gem = nil; s.mark:Hide(); s.markFill:Hide(); for _, t in ipairs(s.orbit) do t:Hide() end; s:Hide(); spritePool[#spritePool+1] = s end
    for s in pairs(moving) do moving[s] = nil; s.tw = nil end
    pending = 0
    wipe(sprites)
    for c = 1, SIZE do for r = 1, SIZE do
        local gem = G.board.grid[c][r]
        local s = AcquireSprite(gem)
        local x, y = CellXY(c, r)
        if dropIn then
            PlaceSprite(s, x, y + BOARD_PX + 20, 1)
            Tween(s, { y = y, dur = 0.45, delay = (c - 1) * 0.04 + (SIZE - r) * 0.025, ease = "outBack" })
        else
            PlaceSprite(s, x, y, 1)
        end
    end end
end

---------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------
local texPool, fontPool = {}, {}

local function GetTex(layerFrame, blend)
    local t = table.remove(texPool)
    if not t then t = fxLayer:CreateTexture(nil, "OVERLAY") end
    t:SetParent(layerFrame or fxLayer)
    t:SetDrawLayer("OVERLAY", 1)
    t:SetBlendMode(blend or "ADD")
    t:SetTexCoord(0, 1, 0, 1)
    t:SetVertexColor(1, 1, 1, 1)
    t:SetAlpha(1)
    return t
end
local function RelTex(t) t:Hide(); t:ClearAllPoints(); texPool[#texPool+1] = t end

local function GetFont(template, parent)
    local fs = table.remove(fontPool)
    if not fs then fs = fxLayer:CreateFontString(nil, "OVERLAY") end
    fs:SetParent(parent or fxLayer)
    fs:SetDrawLayer("OVERLAY", 7)
    fs:SetFontObject(template or "GameFontNormalLarge")
    fs:SetTextColor(1, 1, 1); fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 1)
    return fs
end
local function RelFont(fs) fs:Hide(); fs:ClearAllPoints(); fontPool[#fontPool+1] = fs end

local function Burst(c, r, rgb, size, delay)
    local t = GetTex()
    t:SetTexture(RING)
    t:SetVertexColor(rgb[1], rgb[2], rgb[3])
    local x, y = CellXY(c, r)
    FX({ region = t, dur = 0.35, delay = delay, x0 = x, y0 = y, a0 = 0.95, a1 = 0,
         w0 = size * 0.5, h0 = size * 0.5, w1 = size * 1.6, h1 = size * 1.6, release = RelTex })
end

local function Beam(horizontal, index, rgb, width, delay)
    local t = GetTex()
    t:SetTexture(WHITE)
    t:SetVertexColor(rgb[1], rgb[2], rgb[3])
    local x, y = CellXY(index, index)
    local o = { region = t, dur = 0.4, delay = delay, a0 = 0.9, a1 = 0, release = RelTex, ease = "outQuad" }
    if horizontal then
        o.x0, o.y0 = BOARD_PX / 2, y
        o.w0, o.h0, o.w1, o.h1 = BOARD_PX, CELL * width * 0.7, BOARD_PX, 2
    else
        o.x0, o.y0 = x, -BOARD_PX / 2
        o.w0, o.h0, o.w1, o.h1 = CELL * width * 0.7, BOARD_PX, 2, BOARD_PX
    end
    FX(o)
end

local function BoardFlash(rgb, alpha)
    local t = GetTex()
    t:SetTexture(WHITE); t:SetVertexColor(rgb[1], rgb[2], rgb[3])
    FX({ region = t, dur = 0.5, x0 = BOARD_PX / 2, y0 = -BOARD_PX / 2, a0 = alpha or 0.6, a1 = 0,
         w0 = BOARD_PX, h0 = BOARD_PX, release = RelTex })
end

-- floating text on the board (x,y board offsets) or on another frame
local function FloatText(text, x, y, rgb, template, rel, relPoint, rise, dur)
    local fs = GetFont(template, rel and UI.panelFx or fxLayer)   -- board texts (scores, gem names)
    fs:SetText(text)
    fs:SetTextColor(rgb[1], rgb[2], rgb[3])
    FX({ region = fs, rel = rel, relPoint = relPoint, dur = dur or 0.9, x0 = x, y0 = y, x1 = x, y1 = y + (rise or 30),
         a0 = 1, a1 = 0, ease = "outQuad", release = RelFont })
end

-- Battle text: a short combat log just above the window (movable in the settings).
-- New lines come in at the bottom and push older ones up; each line stays for
-- ns.db.btDuration seconds (Settings slider) and fades out over its last second.
local BT_W, BT_LINE, BT_MAX = 560, 17, 6
local BT_H = BT_LINE * BT_MAX + 10
local BT_FADE = 1.0
local BT_RGB = {
    dealt = { 1.00, 0.85, 0.30 },   -- damage to the makrura
    big   = { 1.00, 0.55, 0.15 },   -- big hits
    taken = { 1.00, 0.30, 0.25 },   -- damage to you
    heal  = { 0.35, 1.00, 0.45 },
    info  = { 0.70, 0.85, 1.00 },
    warn  = { 1.00, 0.45, 0.20 },
    xp    = { 0.75, 0.50, 1.00 },   -- experience
    loot  = { 1.00, 0.95, 0.60 },   -- gold and items
    dot   = { 0.80, 0.55, 1.00 },   -- shadow damage
}
local feed, linePool = {}, {}
-- every logged line is also kept in a short history, tagged with the move ("round") it belongs to,
-- so hovering the battle text can bring back the last 2 rounds
local history, seq = {}, 0
local HISTORY_MAX, HOVER_ROUNDS, HOVER_MAX_H = 80, 2, 420

local function NewLine(entry, hidden)
    local cfx = UI.combatFx
    local fs = table.remove(linePool) or cfx:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(entry.kind == "big" and "GameFontNormalLarge" or "GameFontNormal")
    fs:SetWidth(BT_W - 12)
    fs:SetJustifyH("CENTER")
    if fs.SetWordWrap then fs:SetWordWrap(true) end    -- long sentences take two rows
    fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 1)
    local rgb = BT_RGB[entry.kind] or BT_RGB.info
    fs:SetTextColor(rgb[1], rgb[2], rgb[3])
    fs:SetText(entry.text)
    fs:SetAlpha(0)
    fs:Show()
    local ln = { fs = fs, age = 0, y = -BT_LINE * 0.6, entry = entry, seq = entry.seq }
    entry.ln = ln
    return ln
end

local function BattleLog(kind, text, force)
    if not force and not ns.db.battleText then return end
    local cfx = UI.combatFx
    if not cfx then return end
    seq = seq + 1
    local entry = { seq = seq, kind = kind, text = text, round = (ns.Game and ns.Game.roundId) or 0 }
    if not force then                       -- the move-mode samples are not part of the history
        history[#history+1] = entry
        if #history > HISTORY_MAX then
            local old = table.remove(history, 1)
            old.ln = nil
        end
    end
    table.insert(feed, 1, NewLine(entry))
end
UI.BattleLog = BattleLog

local function ReleaseLine(i)
    local ln = feed[i]
    ln.fs:Hide(); ln.fs:ClearAllPoints()
    linePool[#linePool+1] = ln.fs
    if ln.entry and ln.entry.ln == ln then ln.entry.ln = nil end
    table.remove(feed, i)
end

-- the round ids of the last HOVER_ROUNDS rounds in the history
local function LastRounds()
    local set, n, last = {}, 0, nil
    for k = #history, 1, -1 do
        local r = history[k].round
        if r ~= last then
            if n >= HOVER_ROUNDS then break end
            set[r] = true; n = n + 1; last = r
        end
    end
    return set
end

local hovering = false
local function SetHover(on)
    local cfx = UI.combatFx
    hovering = on
    if on then
        -- keep only the last 2 rounds on show, bring back the lines that already faded
        local keep = LastRounds()
        for k = #feed, 1, -1 do
            local e = feed[k].entry
            if not (e and keep[e.round]) or not ns.db.battleText then feed[k].kill = feed[k].kill or 0.3 end
        end
        if ns.db.battleText then
            for _, e in ipairs(history) do
                if keep[e.round] then
                    if e.ln and e.ln.kill then e.ln.kill = nil end
                    if not e.ln then feed[#feed+1] = NewLine(e) end
                end
            end
        end
        table.sort(feed, function(a, b) return (a.seq or 0) > (b.seq or 0) end)
        for _, ln in ipairs(feed) do if not ln.kill then ln.age = min(ln.age, 0.15) end end
        cfx.hoverBg:Show()
    else
        -- from now on each line stays for the usual time, then fades
        for _, ln in ipairs(feed) do if not ln.kill then ln.age = min(ln.age, 0.15) end end
        cfx:SetHeight(BT_H)
        cfx.hoverBg:Hide()
    end
end

local function FeedUpdate(el)
    local cfx = UI.combatFx
    local over = (not UI.btMoving) and cfx:IsMouseOver() and #history > 0 and ns.db.battleText
    if over and not hovering then SetHover(true) elseif not over and hovering then SetHover(false) end
    local dur = ns.db.btDuration or 6
    local maxH = hovering and HOVER_MAX_H or BT_H
    local top = 5
    local i = 1
    while i <= #feed do
        local ln = feed[i]
        if not hovering or ln.kill then ln.age = ln.age + el end      -- hovering holds the lines
        local a = min(1, ln.age / 0.15) * max(0, min(1, (dur - ln.age) / BT_FADE))
        if hovering and not ln.kill then a = 1 end
        if ln.kill then
            ln.kill = ln.kill - el
            a = min(1, ln.age / 0.15) * max(0, ln.kill / 0.3)
            ln.y = ln.y + el * 40
        else
            local h = (ln.fs.GetStringHeight and ln.fs:GetStringHeight()) or BT_LINE
            if type(h) ~= "number" or h < 1 then h = BT_LINE - 3 end
            if top + h > maxH then
                ln.kill = 0.3                  -- no room left: the oldest lines leave quickly
            else
                ln.y = ln.y + (top - ln.y) * min(1, el * 12)
                top = top + h + 3
            end
        end
        if (a <= 0 and ln.age > 0.2) or (ln.kill and ln.kill <= 0) then
            ReleaseLine(i)
        else
            ln.fs:SetAlpha(a)
            ln.fs:ClearAllPoints()
            ln.fs:SetPoint("BOTTOM", cfx, "BOTTOM", 0, ln.y)
            i = i + 1
        end
    end
    -- while hovering the box grows upward to hold both rounds (and keeps the mouse "inside")
    if hovering then cfx:SetHeight(max(BT_H, top + 6)) end
end

-- names and numbers for the log lines
local function Me()
    local n = UnitName and UnitName("player")
    return "|cffffffff" .. (n or "You") .. "|r"
end
local function Foe()
    local e = G.enemy
    return (e.boss and "|cffff8000" or (e.rare and "|cffc0c0ff" or "|cffffd100")) .. e.name .. "|r"
end
local function Num(n) return "|cffffffff" .. comma(n) .. "|r" end
local function GemName(color)
    local g = ns.GEMS[color]
    local rgb = g.rgb
    return ("|cff%02x%02x%02x%s|r"):format(rgb[1] * 255, rgb[2] * 255, rgb[3] * 255, g.name)
end
local function Count(n, what) return (n == 1 and "a " or (n .. " ")) .. what .. (n == 1 and "" or "s") end
local function JoinList(t)
    if #t <= 1 then return t[1] or "" end
    return table.concat(t, ", ", 1, #t - 1) .. " and " .. t[#t]
end

function UI:PlaceBattleText()
    local o = ns.db.btOffset or { 0, 6 }
    UI.combatFx:ClearAllPoints()
    UI.combatFx:SetPoint("BOTTOM", f, "TOP", o[1], o[2])
end

function UI:ResetBattleText()
    ns.db.btOffset = nil
    UI:PlaceBattleText()
end

-- move mode: cyan box you can drag, with sample text so you see where it lands
function UI:SetBattleTextMovable(on)
    local cfx = UI.combatFx
    UI.btMoving = on and true or false
    cfx.box:SetShown(UI.btMoving)
    cfx:EnableMouse(UI.btMoving)
    UI.btSample = 0
    if not on then cfx.drag = nil end
end

local samples = {
    { "dealt", "|cffffffffYou|r match 3 Citrine: |cffffd100Makrura Clacker|r takes |cffffffff50|r damage." },
    { "dealt", "|cffffffffYou|r hit a x3 combo: |cffffd100Makrura Clacker|r takes |cffffffff450|r damage." },
    { "heal",  "|cffffffffYou|r heal for |cffffffff6|r from matching 3 Huge Emerald." },
    { "taken", "|cffffd100Makrura Clacker|r hits |cffffffffyou|r for |cffffffff5|r damage." },
    { "big",   "|cffffffffYour|r Supernova erupts: |cffffd100Makrura Clacker|r takes |cffffffff1,240|r damage!" },
}
local function BattleTextUpdate(cfx, el)
    if cfx.drag then
        local x, y = GetCursorPosition()
        local sc = cfx:GetEffectiveScale()
        local d = cfx.drag
        ns.db.btOffset = { floor(d.ox + (x - d.x) / sc + 0.5), floor(d.oy + (y - d.y) / sc + 0.5) }
        UI:PlaceBattleText()
    end
    if UI.btMoving then
        UI.btSample = (UI.btSample or 0) - el
        if UI.btSample <= 0 then
            UI.btSample = 1.2
            UI.btSampleI = (UI.btSampleI or 0) % #samples + 1
            local sm = samples[UI.btSampleI]
            BattleLog(sm[1], sm[2], true)
        end
    end
    FeedUpdate(el)
end

local function BuildBattleText()
    local cfx = CreateFrame("Frame", nil, f)
    UI.combatFx = cfx
    cfx:SetFrameStrata("DIALOG")
    cfx:SetSize(BT_W, BT_H)
    cfx:SetMovable(true)
    local box = CreateFrame("Frame", nil, cfx)
    box:SetAllPoints()
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0, 0.9, 1, 0.10)
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", "h" }, { "BOTTOMLEFT", "BOTTOMRIGHT", "h" },
                         { "TOPLEFT", "BOTTOMLEFT", "v" }, { "TOPRIGHT", "BOTTOMRIGHT", "v" } }) do
        local t = box:CreateTexture(nil, "BORDER")
        t:SetColorTexture(0.2, 0.95, 1, 0.95)
        t:SetPoint(e[1]); t:SetPoint(e[2])
        if e[3] == "h" then t:SetHeight(2) else t:SetWidth(2) end
    end
    local title = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 2, 3)
    title:SetText("Battle text")
    local how = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    how:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", -2, 4)
    how:SetText("Drag the box to move it")
    box:Hide()
    cfx.box = box
    cfx.hoverBg = cfx:CreateTexture(nil, "BACKGROUND")
    cfx.hoverBg:SetAllPoints()
    cfx.hoverBg:SetColorTexture(0, 0, 0, 0.55)
    cfx.hoverBg:Hide()
    cfx:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or not UI.btMoving then return end
        local x, y = GetCursorPosition()
        local o = ns.db.btOffset or { 0, 6 }
        self.drag = { x = x, y = y, ox = o[1], oy = o[2] }
    end)
    cfx:SetScript("OnMouseUp", function(self) self.drag = nil end)
    cfx:SetScript("OnUpdate", BattleTextUpdate)
    UI:PlaceBattleText()
end

local function Banner(text, rgb, sub, hold)
    local fs = GetFont("GameFontNormalHuge")
    fs:SetText(text)
    fs:SetTextColor(rgb[1], rgb[2], rgb[3])
    hold = hold or 0.9
    FX({ region = fs, dur = 0.2, x0 = BOARD_PX / 2, y0 = -BOARD_PX / 2 + 10, a0 = 0, a1 = 1 })
    FX({ region = fs, dur = 0.5, delay = 0.2 + hold, x0 = BOARD_PX / 2, y0 = -BOARD_PX / 2 + 10, y1 = -BOARD_PX / 2 + 30,
         a0 = 1, a1 = 0, keep = true, release = RelFont })
    if sub then
        local s2 = GetFont("GameFontHighlight")
        s2:SetText(sub)
        FX({ region = s2, dur = 0.2, x0 = BOARD_PX / 2, y0 = -BOARD_PX / 2 - 18, a0 = 0, a1 = 1 })
        FX({ region = s2, dur = 0.5, delay = 0.2 + hold, x0 = BOARD_PX / 2, y0 = -BOARD_PX / 2 - 18, y1 = -BOARD_PX / 2 + 2,
             a0 = 1, a1 = 0, keep = true, release = RelFont })
    end
end

local CHEERS = { [2] = "Good!", [3] = "Excellent!", [4] = "Awesome!", [5] = "Spectacular!", [6] = "Extraordinary!" }

---------------------------------------------------------------------------
-- Right panel: makrura, bars, stats
---------------------------------------------------------------------------
local P = {}

local function MakeBar(parent, w, h, r, g, b)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(w, h)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(r, g, b)
    Backdrop(bar, 0.7)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER")
    return bar
end

local function BuildPanel()
    local x0 = 14 + BOARD_PX + 14
    local box = CreateFrame("Frame", nil, f)
    box:SetSize(PANEL_W, 140)
    box:SetPoint("TOPLEFT", x0, -64)
    box:SetFrameLevel(f:GetFrameLevel() + 5)
    Backdrop(box, 0.75)
    P.box = box

    local water = box:CreateTexture(nil, "BACKGROUND", nil, 1)
    water:SetPoint("BOTTOMLEFT", 1, 1); water:SetPoint("BOTTOMRIGHT", -1, 1); water:SetHeight(50)
    water:SetTexture(WHITE)
    if water.SetGradient and CreateColor then
        pcall(water.SetGradient, water, "VERTICAL", CreateColor(0.02, 0.15, 0.22, 0.9), CreateColor(0, 0, 0, 0))
    else
        water:SetColorTexture(0.02, 0.12, 0.18, 0.6)
    end

    P.icon = box:CreateTexture(nil, "ARTWORK")
    P.icon:SetSize(64, 64); P.icon:SetPoint("CENTER", 0, -2)
    P.icon:SetTexture(CRAB_ICON); P.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local ok, model = pcall(CreateFrame, "PlayerModel", nil, box)
    if ok and model then
        model:SetPoint("TOPLEFT", 2, -18); model:SetPoint("BOTTOMRIGHT", -2, 14)
        P.model = model
    end

    P.name = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    P.name:SetPoint("TOP", 0, -6)
    P.level = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    P.level:SetPoint("BOTTOM", 0, 5)
    P.level:SetTextColor(0.8, 0.8, 0.8)

    P.hit = box:CreateTexture(nil, "OVERLAY")
    P.hit:SetAllPoints(); P.hit:SetTexture(WHITE); P.hit:SetBlendMode("ADD")
    P.hit:SetVertexColor(1, 0.2, 0.1); P.hit:SetAlpha(0)

    P.enemyBar = MakeBar(f, PANEL_W, 16, 0.85, 0.15, 0.1)
    P.enemyBar:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -6)

    P.attack = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    P.attack:SetPoint("TOPLEFT", P.enemyBar, "BOTTOMLEFT", 0, -7)
    P.attack:SetWidth(PANEL_W); P.attack:SetJustifyH("LEFT")

    P.trait = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    P.trait:SetPoint("TOPLEFT", P.attack, "BOTTOMLEFT", 0, -4)
    P.trait:SetWidth(PANEL_W); P.trait:SetJustifyH("LEFT")
    P.trait:SetTextColor(0.75, 0.75, 0.75)

    P.youLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    P.youLabel:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -72)
    P.youLabel:SetText((UnitName and UnitName("player")) or "You")
    P.youLevel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    P.youLevel:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, -84)
    P.playerBar = MakeBar(f, PANEL_W, 16, 0.15, 0.75, 0.2)
    P.playerBar:SetPoint("TOPLEFT", P.youLabel, "BOTTOMLEFT", 0, -4)
    P.xpBar = MakeBar(f, PANEL_W, 8, 0.58, 0.0, 0.55)
    P.xpBar:SetPoint("TOPLEFT", P.playerBar, "BOTTOMLEFT", 0, -3)
    P.xpBar.text:SetFontObject("GameFontHighlightSmall")
    P.xpBar.text:SetText("")
    P.xpBar:EnableMouse(true)
    P.xpBar:SetScript("OnEnter", function(self)
        local d = ns.Prog:Data()
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        if d.level >= ns.MAX_LEVEL then GameTooltip:SetText("Level " .. d.level .. " (max)")
        else
            GameTooltip:SetText(("Level %d: %s / %s experience"):format(d.level, comma(d.xp), comma(ns.XPToNext(d.level))))
        end
        GameTooltip:Show()
    end)
    P.xpBar:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- run buffs from gem colours: icon + value, only the active ones
    P.buffRow = CreateFrame("Frame", nil, f)
    P.buffRow:SetSize(PANEL_W, 18)
    P.buffRow:SetPoint("TOPLEFT", P.xpBar, "BOTTOMLEFT", 0, -6)
    P.buffs = {}
    for i = 1, 6 do
        local b = CreateFrame("Frame", nil, P.buffRow)
        b:SetSize(33, 18)
        b:SetPoint("LEFT", (i - 1) * 34, 0)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(16, 16); b.icon:SetPoint("LEFT")
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 1, 0)
        b:EnableMouse(true)
        b:SetScript("OnEnter", function(self)
            if not self.key then return end
            local info = ns.BUFF_INFO[self.key]
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(info.name)
            GameTooltip:AddLine(info.text:format(self.value or 0), 1, 1, 1, true)
            if self.cap then GameTooltip:AddLine(("Cap this tide: %d%%. Match more %s to build it up."):format(self.cap, ns.GEMS[info.gem].name), 0.7, 0.7, 0.7, true) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        P.buffs[i] = b
    end

    local stats = { "Score", "Biggest combo", "Loot" }
    P.stat = {}
    local prev = P.buffRow
    for i, label in ipairs(stats) do
        local l = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        l:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -12 or -5)
        l:SetText(label)
        local v = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        v:SetPoint("RIGHT", l, "LEFT", PANEL_W, 0)
        v:SetJustifyH("RIGHT")
        P.stat[label] = v
        prev = l
    end

    -- Hint / Settings / Menu sit in the strip under the board, centred on it both ways
    local STRIP_MID = 64 + BOARD_PX + 23          -- middle of the strip, above the window's bottom border
    local opt = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    opt:SetSize(86, 24)
    opt:SetPoint("CENTER", f, "TOPLEFT", 14 + BOARD_PX / 2, -STRIP_MID)
    opt:SetText("Settings")
    opt:SetScript("OnClick", function() ns.Settings:Toggle() end)
    P.optButton = opt
    local hint = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    hint:SetSize(86, 24)
    hint:SetPoint("RIGHT", opt, "LEFT", -8, 0)
    hint:SetText("Hint")
    hint:SetScript("OnClick", function() UI:ShowHint("manual") end)
    local new = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    new:SetSize(86, 24)
    new:SetPoint("LEFT", opt, "RIGHT", 8, 0)
    new:SetText("Menu")
    new:SetScript("OnClick", function() UI:Pause() end)

    -- bags, in the same strip under the right panel: click to see, equip and sell the loot
    local bag = CreateFrame("Button", "MariscosShellcrackerBagButton", f)
    bag:SetSize(34, 34)
    bag:SetPoint("RIGHT", f, "TOPLEFT", x0 + PANEL_W, -STRIP_MID)
    bag:SetFrameLevel(f:GetFrameLevel() + 6)
    bag:SetNormalTexture("Interface\\Buttons\\Button-Backpack-Up")
    bag:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    bag.glow = bag:CreateTexture(nil, "OVERLAY")
    bag.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    bag.glow:SetBlendMode("ADD")
    bag.glow:SetVertexColor(0.3, 1, 0.3)
    bag.glow:SetPoint("CENTER"); bag.glow:SetSize(64, 64)
    bag.glow:Hide()
    bag.badge = bag:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    bag.badge:SetPoint("BOTTOMRIGHT", -1, 2)
    bag:SetScript("OnClick", function() ns.Screens:ToggleBags() end)
    bag:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Backpack")
        local n = ns.Prog:NewCount()
        if n > 0 then GameTooltip:AddLine(n .. " new item" .. (n > 1 and "s" or "") .. " to look at.", 0.2, 1, 0.2) end
        GameTooltip:AddLine("Click to see your loot. Items found in this run can be equipped or sold straight away.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    bag:SetScript("OnLeave", function() GameTooltip:Hide() end)
    P.bagButton = bag
    P.bagText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    P.bagText:SetPoint("BOTTOMRIGHT", bag, "LEFT", -8, 1)
    P.bagText:SetJustifyH("RIGHT")
    P.bagNew = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    P.bagNew:SetPoint("TOPRIGHT", bag, "LEFT", -8, -1)
    P.bagNew:SetJustifyH("RIGHT")
    P.hintButton, P.newButton = hint, new

    P.header = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    P.header:SetPoint("TOPLEFT", 66, -35)
    local lb = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    lb:SetSize(100, 22)
    lb:SetPoint("TOPRIGHT", -14, -30)
    lb:SetText("Leaderboard")
    lb:SetScript("OnClick", function() ns.Leaderboard:Toggle() end)
    P.lbButton = lb
    P.headerRight = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    P.headerRight:SetPoint("RIGHT", lb, "LEFT", -10, 0)
end

StaticPopupDialogs["MARISCOS_SHELLCRACKER_NEW"] = {
    text = "Start a new game? Your current fight will be lost.",
    button1 = YES or "Yes", button2 = NO or "No",
    OnAccept = function() UI:NewGame() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- 3D model: retry until the creature is cached, keep the crab icon otherwise
local function LoadModel(e)
    local m = P.model
    P.icon:Show()
    if not m then return end
    m:Show()
    m:SetAlpha(1)
    local tries = 0
    local token = {}
    P.modelToken = token
    local function send()
        pcall(m.ClearModel, m)
        pcall(m.SetCreature, m, e.model)
        pcall(m.SetModelScale, m, e.scale or 1)
        pcall(m.SetFacing, m, -0.45)
    end
    local function poll()
        if P.modelToken ~= token then return end
        tries = tries + 1
        local ok, loaded = pcall(m.GetModelFileID, m)
        if not m.GetModelFileID then ok, loaded = true, 1 end
        if ok and loaded and loaded ~= 0 then
            P.icon:Hide()
            pcall(m.SetAnimation, m, 0)
        elseif tries < 12 then
            if tries % 3 == 0 then send() end
            After(0.4, poll)
        else
            m:Hide()     -- not cached: keep the crab icon
        end
    end
    send()
    After(0.2, poll)
end

local function ModelAnim(id, back)
    if P.model and P.model.SetAnimation then
        pcall(P.model.SetAnimation, P.model, id)
        if back then After(back, function() if G.enemyHP and G.enemyHP > 0 then pcall(P.model.SetAnimation, P.model, 0) end end) end
    end
end

-- header: makrura count in a fight, the screen's name elsewhere; rank badge + title + name on the right
function UI:UpdateHeader(screenTitle)
    if screenTitle then UI.headerTitle = screenTitle end
    if UI.headerTitle then
        P.header:SetText(UI.headerTitle)
    elseif G.wave then
        local count = #ns.ENEMIES
        P.header:SetText("Makrura " .. ((G.wave - 1) % count + 1) .. " of " .. count)
    end
    local title, badge = ns.Prog:Title()
    P.headerRight:SetText(("|T%s:16:16|t %s %s"):format(badge, title, (UnitName and UnitName("player")) or ""))
end

function UI:UpdateBagButton()
    if not P.bagButton then return end
    local n = ns.Prog:NewCount()
    P.bagText:SetText("Backpack  |cffffffff" .. ns.Prog:BagCount() .. "/" .. ns.BAG_SIZE .. "|r")
    P.bagNew:SetText(n > 0 and ("|cff20ff20" .. n .. " new item" .. (n > 1 and "s" or "") .. "|r") or "|cff888888Click to open|r")
    P.bagButton.badge:SetText(n > 0 and n or "")
    P.bagButton.glow:SetShown(n > 0)
end

function UI:UpdatePanel()
    local e = G.enemy
    if not e then return end
    local nameColor = e.boss and "|cffff8000" or (e.crazed and "|cffffe040" or (e.rare and "|cffc0c0ff" or "|cffffd100"))
    P.name:SetText(nameColor .. e.name .. "|r")
    P.level:SetText("Level " .. e.level .. " - " .. e.zone .. (e.tide > 1 and ("  (Tide " .. e.tide .. ")") or ""))
    P.enemyBar:SetMinMaxValues(0, e.hp)
    P.enemyBar:SetValue(max(0, G.enemyHP))
    P.enemyBar.text:SetText(comma(max(0, G.enemyHP)) .. " / " .. comma(e.hp))
    local hit = UI:HitSize()
    local rage = UI:EnragePct()
    local tail = rage > 0 and ("  |cffff4040enraged +" .. rage .. "%|r") or ""
    if G.timer <= 1 then
        P.attack:SetText("|cffff4040Attacks next move!|r  (" .. comma(hit) .. " damage)" .. tail)
    else
        P.attack:SetText("Attacks in |cffffd100" .. G.timer .. "|r moves  (" .. comma(hit) .. " damage)" .. tail)
    end
    P.trait:SetText(e.trait and ns.TRAIT_TEXT[e.trait] or "")
    local maxHP = G.maxHP or ns.PLAYER_HP
    P.playerBar:SetMinMaxValues(0, maxHP)
    P.playerBar:SetValue(max(0, G.playerHP))
    P.playerBar.text:SetText(max(0, G.playerHP) .. " / " .. maxHP)
    local pr = G.playerHP / maxHP
    if pr > 0.5 then P.playerBar:SetStatusBarColor(0.15, 0.75, 0.2)
    elseif pr > 0.25 then P.playerBar:SetStatusBarColor(0.9, 0.7, 0.1)
    else P.playerBar:SetStatusBarColor(0.9, 0.15, 0.1) end
    P.stat["Score"]:SetText(comma(G.score))
    P.stat["Biggest combo"]:SetText(G.bestCombo > 1 and ("x" .. G.bestCombo) or "-")
    local loot = G.loot or { gold = 0, items = 0 }
    P.stat["Loot"]:SetText(ns.Prog:Money(loot.gold) .. (loot.items > 0 and ("  |cff1eff00+" .. loot.items .. " item" .. (loot.items > 1 and "s" or "") .. "|r") or ""))
    UI:UpdateBagButton()
    local d = ns.Prog:Data()
    local title = ns.Prog:Title()
    P.youLevel:SetText("Level " .. d.level .. " " .. title)
    if d.level >= ns.MAX_LEVEL then P.xpBar:SetMinMaxValues(0, 1); P.xpBar:SetValue(1)
    else P.xpBar:SetMinMaxValues(0, ns.XPToNext(d.level)); P.xpBar:SetValue(d.xp) end
    UI:UpdateHeader()
    UI:UpdateBuffs()
end

---------------------------------------------------------------------------
-- Game flow
---------------------------------------------------------------------------
local function FreshBoard()
    local b = Board.New()
    local M = G.mods or {}
    if (M.kindling or 0) > 0 or (M.startHyper or 0) > 0 then b:Seed(M.kindling or 0, M.startHyper or 0) end
    return b
end

local function SetEnemy(wave, loading)
    G.wave = wave
    G.enemy = ns.Prog:ScaleEnemy(ns.GetEnemy(wave))
    G.enemy.wave = wave
    G.shellUsed = false
    -- every new tide (and every new run) brings new stock to the shop
    if not loading and (wave - 1) % #ns.ENEMIES == 0 then
        ns.Prog:NewTide()
        if wave > 1 then BattleLog("loot", "A new tide washes in: the shop has new stock.") end
    end
    if not loading and not G.enemy.boss and math.random() < ns.DROP.crazedChance then
        G.enemy.crazed = true
        G.enemy.name = "Loot-Crazed " .. G.enemy.name
        SFX("coinsBig")
        BattleLog("loot", ("A %s scuttles in, clutching a glittering sack! It will drop something Rare or better."):format(Foe()))
    end
    G.fightMoves = 0
    G.enemyHP = G.enemy.hp
    G.timer = G.enemy.every
    G.warned = false
    G.frozen = false
    G.dealtSince = 0
    LoadModel(G.enemy)
end

local function Save()
    if not G.board or G.over then ns.cdb.save = nil return end
    if G.busy then return end      -- mid-move: keep the last finished move
    ns.cdb.save = {
        board = G.board:Serialize(), score = G.score, wave = G.wave, enemyHP = G.enemyHP,
        playerHP = G.playerHP, timer = G.timer, moves = G.moves, bestCombo = G.bestCombo,
        run = G.run, dealtSince = G.dealtSince, loot = G.loot, cheatUsed = G.cheatUsed, hp10 = true,
        crazed = G.enemy and G.enemy.crazed, shellUsed = G.shellUsed,
        fightMoves = G.fightMoves, overpowerReady = G.overpowerReady, flurryReady = G.flurryReady,
        buffs = G.buffs, dot = G.dot, frozen = G.frozen,
    }
end
UI.Save = Save

local function RecordBest()
    ns.Stats:UpdateBest(G)
    if ns.Leaderboard:IsShown() then ns.Leaderboard:Refresh() end
end

local function ResetFlow()
    wipe(timers); idleCb = nil
end

function UI:HideOverlay() if P.overlay then P.overlay:Hide() end end

-- heal with Spirit / talent bonuses; returns the health actually gained
function UI:HealPlayer(amount)
    local M = G.mods or {}
    amount = floor(amount * (1 + (M.heal or 0) / 100) + 0.5)
    local before = G.playerHP
    G.playerHP = min(G.maxHP or ns.PLAYER_HP, G.playerHP + amount)
    local got = G.playerHP - before
    if got > 0 then ns.Stats:Add("healed", got) end
    return got
end

-- experience; level-ups raise your health and power straight away
function UI:GainXP(amount, why)
    if amount <= 0 then return 0 end
    local levels, got = ns.Prog:AddXP(amount)
    if got > 0 then BattleLog("xp", ("%s gains %s experience %s."):format(Me(), Num(got), why or "")) end
    for _, L in ipairs(levels) do
        local oldMax = G.maxHP or ns.PLAYER_HP
        G.mods = ns.Prog:Mods()
        G.maxHP = G.mods.maxHP
        if G.playerHP then G.playerHP = G.playerHP + (G.maxHP - oldMax) end
        local title = ns.Prog:Title(L)
        local newTitle = (L % 10 == 0)
        SFX("levelUp")
        Banner("Level " .. L .. "!", { 1, 0.82, 0 }, newTitle and ("You are now a " .. title .. "!") or "You feel stronger.", 1.2)
        BattleLog("big", ("Ding! %s reaches level %s."):format(Me(), Num(L)))
        if newTitle then BattleLog("big", ("%s earns the title |cffffd100%s|r."):format(Me(), title)) end
        if L >= ns.TALENT_START then BattleLog("xp", "You have a new talent point. Spend it from the menu once this run is over.") end
    end
    if #levels > 0 then ns.Stats:Char() end
    return got
end

-- gold and items from a defeated makrura
function UI:Loot(e)
    G.loot = G.loot or { gold = 0, items = 0 }
    local copper = floor(ns.Prog:KillGold(e) * (1 + ((G.buffs and G.buffs.gold) or 0) / 100) * (e.crazed and ns.DROP.crazedGold or 1))
    ns.Prog:AddGold(copper)
    G.loot.gold = G.loot.gold + copper
    ns.Stats:Add("goldEarned", copper)
    SFX("coins")
    BattleLog("loot", ("%s loots %s."):format(Me(), ns.Prog:Money(copper)))
    local item = ns.Prog:RollDrop(e, (G.buffs and G.buffs.drop) or 0)
    if item then
        -- what it is stays a surprise until you open your bags
        item.runId = G.run and G.run.id
        item.new = true
        if ns.Prog:AddToBags(item) then
            G.loot.items = G.loot.items + 1
            SFX("loot")
            BattleLog("loot", ("%s drops something! Open your bags to see what it is."):format(Foe()))
        else
            BattleLog("warn", "Your bags are full: the item it dropped is lost. Sell something from your bags.")
        end
        if ns.Screens and ns.Screens.RefreshBags then ns.Screens:RefreshBags() end
    end
end

-- gear put on mid-run (an item found in this run): health and power change straight away
function UI:GearChanged(item)
    if not G.board or G.over then return end
    local oldMax = G.maxHP or ns.PLAYER_HP
    G.mods = ns.Prog:Mods()
    G.maxHP = G.mods.maxHP
    if G.playerHP then G.playerHP = max(1, min(G.maxHP, G.playerHP + (G.maxHP - oldMax))) end
    if item then BattleLog("loot", ("%s equips %s."):format(Me(), ns.Prog:Link(item))) end
    UI:UpdatePanel()
    Save()
end

-- leave the fight for the menu (the run is kept)
function UI:Pause()
    if G.busy and not G.over then return end      -- let the move finish first
    UI:ClearSelection(); UI:HideHint()
    Save()
    UI:ShowMenu()
end

function UI:ShowMenu()
    G.paused = true
    if ns.Screens then ns.Screens:Show("menu") end
end

-- back to the fight in memory, or load the saved one
function UI:Continue()
    if G.board and not G.over then
        G.paused = false
        UI.headerTitle = nil
        if ns.Screens then ns.Screens:HideAll() end
        UI.idle = 0
        UI:UpdatePanel()
        return true
    end
    if UI:LoadGame() then
        if ns.Screens then ns.Screens:HideAll() end
        return true
    end
    return false
end

function UI:HasRun() return (G.board and not G.over) or (ns.cdb.save ~= nil) end

-- give up the current run (counts as a run on the leaderboard)
function UI:AbandonRun()
    if G.board and not G.over and (G.moves or 0) > 0 then
        ns.Stats:EndRun(G, "left")
    elseif not G.board and ns.cdb.save and (ns.cdb.save.moves or 0) > 0 then
        local s = ns.cdb.save
        ns.Stats:EndRun({ score = s.score, wave = s.wave, bestCombo = s.bestCombo, moves = s.moves, run = s.run,
                          enemy = ns.GetEnemy(s.wave or 1) }, "left")
    end
    ns.cdb.save = nil
    ResetFlow()
    G.board, G.over = nil, false
end


-- every run gets its own id: items that drop in it carry it, and only those can be equipped mid-run
local function NewRunId()
    return ("%d-%d"):format((time and time()) or 0, math.random(1, 999999))
end

function UI:NewGame()
    -- starting over in the middle of a fight still counts as a run
    if UI:HasRun() then UI:AbandonRun() end
    UI.headerTitle = nil
    ResetFlow()
    UI:HideOverlay()
    UI:ClearSelection(); UI:HideHint()
    G.mods = ns.Prog:Mods()
    G.maxHP = G.mods.maxHP
    G.score, G.moves, G.bestCombo, G.over, G.paused = 0, 0, 0, false, false
    G.run = ns.Stats:NewRun()
    G.run.id = NewRunId()
    G.loot = { gold = 0, items = 0 }
    G.cheatUsed, G.overpowerReady, G.flurryReady = false, false, false
    G.buffs, G.dot, G.frozen = { dmg = 0, dr = 0, gold = 0, drop = 0 }, nil, false
    G.playerHP = G.maxHP
    G.board = FreshBoard()
    SetEnemy(1)
    if ns.Screens then ns.Screens:HideAll() end
    G.busy = true
    ns.cdb.save = nil
    RebuildSprites(true)
    WhenIdle(function() G.busy = false; Save() end)
    Banner(G.enemy.name, { 1, 0.82, 0 }, "approaches from the shore!", 1.0)
    Sound("IG_CHARACTER_INFO_OPEN")
    UI:UpdatePanel()
end

function UI:LoadGame()
    local s = ns.cdb.save
    local b = s and Board.Load(s.board)
    if not b then return false end
    ResetFlow()
    UI:HideOverlay()
    G.board = b
    G.mods = ns.Prog:Mods()
    G.maxHP = G.mods.maxHP
    G.score, G.moves, G.bestCombo, G.over, G.paused = s.score or 0, s.moves or 0, s.bestCombo or 0, false, false
    G.run = s.run or ns.Stats:NewRun()
    G.run.id = G.run.id or NewRunId()
    G.loot = s.loot or { gold = 0, items = 0 }
    G.cheatUsed, G.overpowerReady, G.flurryReady = s.cheatUsed, s.overpowerReady, s.flurryReady
    G.buffs = s.buffs or { dmg = 0, dr = 0, gold = 0, drop = 0 }
    G.dot, G.frozen = s.dot, s.frozen
    SetEnemy(s.wave or 1, true)
    G.fightMoves = s.fightMoves or 0
    G.enemyHP = min(s.enemyHP or G.enemy.hp, G.enemy.hp)   -- a saved fight from before a rebalance
    G.dealtSince = s.dealtSince or 0
    local hp = s.playerHP or G.maxHP
    if not s.hp10 then hp = hp * 10 end
    G.playerHP = min(hp, G.maxHP)
    if s.crazed and not G.enemy.crazed and not G.enemy.boss then
        G.enemy.crazed = true
        G.enemy.name = "Loot-Crazed " .. G.enemy.name
    end
    G.shellUsed = s.shellUsed
    G.timer = s.timer or G.enemy.every
    G.busy = true
    RebuildSprites(true)
    WhenIdle(function() G.busy = false end)
    UI:UpdatePanel()
    return true
end

local function ShowOverlay(title, rgb, lines)
    if not P.overlay then
        local o = CreateFrame("Frame", nil, board)
        o:SetAllPoints()
        o:SetFrameLevel(board:GetFrameLevel() + 30)
        o:EnableMouse(true)
        local bg = o:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0.78)
        o.title = o:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        o.title:SetPoint("CENTER", 0, 60)
        o.text = o:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        o.text:SetPoint("TOP", o.title, "BOTTOM", 0, -16)
        o.text:SetSpacing(4)
        local btn = CreateFrame("Button", nil, o, "UIPanelButtonTemplate")
        btn:SetSize(130, 26); btn:SetPoint("TOPRIGHT", o.text, "BOTTOM", -4, -18)
        btn:SetText("New Game")
        btn:SetScript("OnClick", function() UI:NewGame() end)
        local menu = CreateFrame("Button", nil, o, "UIPanelButtonTemplate")
        menu:SetSize(130, 26); menu:SetPoint("TOPLEFT", o.text, "BOTTOM", 4, -18)
        menu:SetText("Menu")
        menu:SetScript("OnClick", function() UI:HideOverlay(); UI:ShowMenu() end)
        P.overlay = o
    end
    P.overlay.title:SetText(title)
    P.overlay.title:SetTextColor(rgb[1], rgb[2], rgb[3])
    P.overlay.text:SetText(table.concat(lines, "\n"))
    P.overlay:Show()
end

local function GameOver()
    G.over = true
    G.busy = true
    RecordBest()
    ns.Stats:EndRun(G, "slain")
    if ns.Leaderboard:IsShown() then ns.Leaderboard:Refresh() end
    ns.cdb.save = nil
    ModelAnim(16, nil)
    SFX("gameOver")
    local xp = UI:GainXP(ns.Prog:RunXP(G.score), "for the run")
    UI:UpdatePanel()
    local d = ns.Prog:Data()
    local loot = G.loot or { gold = 0, items = 0 }
    ShowOverlay("Defeated", { 1, 0.25, 0.2 }, {
        "Slain by " .. G.enemy.name .. " (makrura " .. G.wave .. ")",
        "Score: |cffffd100" .. comma(G.score) .. "|r   Best: " .. comma(ns.Stats:Char().best.score),
        "Biggest combo: x" .. max(1, G.bestCombo) .. "   Run experience: |cffb048f8+" .. comma(xp) .. "|r",
        "Loot: " .. ns.Prog:Money(loot.gold) .. (loot.items > 0 and ("  and " .. loot.items .. " item" .. (loot.items > 1 and "s" or "")) or ""),
    })
end

local function EnemyAttack()
    local e = G.enemy
    local M = G.mods or {}
    G.frozen = false                    -- an Aquamarine freeze is used up by the delayed attack
    ModelAnim(16, 1.0)
    if math.random() * 100 < (M.dodge or 0) then
        BattleLog("info", ("%s dodges %s's attack!"):format(Me(), Foe()))
        SFX("dodge")
    else
        local dmg = UI:HitSize()
        local note = ""
        if M.legendary and M.legendary.shellAncient and not G.shellUsed then
            G.shellUsed = true
            note = ". |cffff8000Shell of the Ancients|r absorbs it all"
            dmg = 0
        end
        if dmg > 0 and (M.shieldWall or 0) > 0 and G.playerHP - dmg < 250 then
            dmg = max(1, math.ceil(dmg / 2)); note = note .. " (Shield Wall halves it)"
        end
        if dmg > 0 and G.playerHP - dmg <= 0 and (M.cheatDeath or 0) > 0 and not G.cheatUsed then
            G.cheatUsed = true
            dmg = G.playerHP - 1
            note = note .. ". |cffffd100Last Stand!|r " .. Me() .. " refuses to fall"
        end
        ns.Stats:Add("taken", min(dmg, G.playerHP))
        G.playerHP = max(0, G.playerHP - dmg)
        BoardFlash({ 1, 0.1, 0.05 }, 0.45)
        BattleLog("taken", ("%s hits %s for %s damage%s."):format(Foe(), Me(), Num(dmg), note))
        HitSound(e.boss or e.rare)
        if (M.overpower or 0) > 0 then G.overpowerReady = true end
    end
    if G.playerHP > 0 and G.playerHP < (G.maxHP or ns.PLAYER_HP) * 0.1 then
        Sound("RAID_WARNING")                       -- almost dead
        BattleLog("warn", ("%s is badly hurt: only %s health left!"):format(Me(), Num(G.playerHP)))
    end
    if e.trait == "mend" and G.enemyHP > 0 then
        local cut = 1 - min(100, (G.mods and G.mods.mendCut) or 0) / 100
        local heal = min(floor((G.dealtSince or 0) * ns.MEND_PCT * cut), e.hp - G.enemyHP)
        G.enemyHP = G.enemyHP + heal
        if heal > 0 then
            BattleLog("info", ("%s's mending tide heals it for %s (a fifth of your last hits)."):format(Foe(), Num(heal)))
        end
    end
    G.dealtSince = 0
end

-- when the move has no legal follow-up
local function CheckMoves(done)
    if G.board:FindHint() then return done() end
    Banner("No more moves!", { 1, 0.5, 0.2 }, "The makrura strikes while you regroup", 0.8)
    BattleLog("warn", "No moves left! The gems reshuffle and " .. Foe() .. " gets a free attack.")
    EnemyAttack()
    G.timer = G.enemy.every
    UI:UpdatePanel()
    if G.playerHP <= 0 then return GameOver() end
    local spots = G.board:Shuffle()
    After(1.0, function()
        for _, sp in ipairs(spots) do
            local s = sprites[sp.id]
            if s then
                StyleSprite(s, sp.gem)
                local x, y = CellXY(sp.c, sp.r)
                Tween(s, { x = x, y = y, dur = 0.5, ease = "outQuad" })
            end
        end
        WhenIdle(done)
    end)
end

local function EnemyDefeated()
    local e = G.enemy
    ModelAnim(1, nil)      -- death
    SFX("mobDeath")
    Banner(e.name .. " defeated!", { 1, 0.82, 0 }, e.boss and "Tidefury Cove is clear... but the tide rises again!" or "Its shell cracks open", 1.1)
    if P.model then FX({ region = P.model, dur = 0.6, delay = 1.0, a0 = 1, a1 = 0, keep = true, hide = true }) end
    BattleLog("big", Foe() .. " is defeated!")
    ns.Stats:Add("kills")
    if (G.mods and G.mods.killHeal or 0) > 0 then
        local got = UI:HealPlayer(floor((G.maxHP or ns.PLAYER_HP) * G.mods.killHeal / 100))
        if got > 0 then BattleLog("heal", ("%s's gear heals for %s."):format(Me(), Num(got))) end
    end
    if e.boss then ns.Stats:Add("bossKills") end
    UI:Loot(e)
    UI:GainXP(ns.Prog:KillXP(e), "for " .. Foe())
    After(1.8, function()
        RecordBest()
        local M = G.mods or {}
        local got = UI:HealPlayer(ns.HEAL_BETWEEN_WAVES + (M.waveHeal or 0))
        if got > 0 then
            BattleLog("heal", ("%s catches a breath and recovers %s health."):format(Me(), Num(got)))
        end
        SetEnemy(G.wave + 1)
        BattleLog("info", ("%s approaches from %s."):format(Foe(), G.enemy.zone))
        Banner(G.enemy.name, G.enemy.boss and { 1, 0.5, 0 } or { 1, 0.82, 0 },
            G.enemy.boss and "The lord of Tidefury Cove rises!" or ("approaches from " .. G.enemy.zone), 0.9)
        SFX("mobAggro")
        UI:UpdatePanel()
        -- fresh board for the new fight: the old gems drop away, new ones fall in
        UI:ClearSelection(); UI:HideHint()
        for _, sp in pairs(sprites) do
            if sp.gem then
                local col = floor(sp.px / CELL) + 1
                Tween(sp, { y = sp.py - BOARD_PX - CELL, dur = 0.45, delay = (col - 1) * 0.03 + math.random() * 0.06,
                            ease = "inQuad", a0 = 1, a1 = 0.4 })
            end
        end
        WhenIdle(function()
            G.board = FreshBoard()
            RebuildSprites(true)
            WhenIdle(function() G.busy = false; UI.idle = 0; Save() end)
        end)
    end)
end

-- enrage: long fights make the makrura hit harder
function UI:EnrageAt() return (G.enemy and G.enemy.boss) and ns.ENRAGE_AFTER_BOSS or ns.ENRAGE_AFTER end
function UI:EnragePct()
    local over = (G.fightMoves or 0) - UI:EnrageAt()
    return over > 0 and over * ns.ENRAGE_PER_MOVE or 0
end

-- what the makrura's hit really does to you after armor, level, talents and Ruby Ward
function UI:HitSize()
    local e, M = G.enemy, G.mods or {}
    local ward = (G.buffs and G.buffs.dr) or 0
    local d = e.dmg * (1 + UI:EnragePct() / 100)
        * (1 - (M.armorRed or 0)) * (1 - (M.armorPct or 0) / 100) * (1 - (M.levelDef or 0) / 100) * (1 - ward / 100)
    return max(1, floor(d + 0.5))
end

-- turn a random plain gem on the board into a special gem (legendary effects)
function UI:ForgeSpecial(kind, source)
    local cells = {}
    for c = 1, SIZE do for r = 1, SIZE do
        local g = G.board.grid[c][r]
        if g and not g.special then cells[#cells+1] = g end
    end end
    if #cells == 0 then return end
    local g = cells[math.random(#cells)]
    g.special = kind
    local sp = sprites[g.id]
    if sp then
        StyleSprite(sp, g)
        Tween(sp, { s0 = 1.5, s1 = 1, dur = 0.3, ease = "outBack" })
    end
    BattleLog("loot", ("%s forges a %s."):format(source, ns.SPECIAL_INFO[kind].name))
end

-- current cap of a run buff (rises with every tide)
local function BuffCap(kind)
    for _, b in pairs(ns.GEM_BONUS) do
        if type(b) == "table" and b.kind == kind then
            local M = G.mods or {}
            local extra = (kind == "dmg" and (M.capDmg or 0)) or (kind == "dr" and (M.capDr or 0))
                or ((kind == "gold" or kind == "drop") and (M.capLoot or 0)) or 0
            local cap = (b.cap + extra) * ((G.enemy and G.enemy.tide) or 1)
            if M.legendary and M.legendary.bandTides then cap = floor(cap * 1.5) end
            if b.max then cap = min(cap, b.max * ((M.legendary and M.legendary.bandTides) and 1.5 or 1)) end
            return floor(cap)
        end
    end
    return 0
end

function UI:UpdateBuffs()
    if not P.buffs then return end
    local list = {}
    local B = G.buffs or {}
    for _, k in ipairs({ "dmg", "dr", "gold", "drop" }) do
        if (B[k] or 0) > 0 then list[#list+1] = { key = k, value = B[k], cap = BuffCap(k), text = B[k] .. "%" } end
    end
    if G.dot then list[#list+1] = { key = "dot", value = G.dot.left, text = ((G.dot.stacks or 1) > 1 and (G.dot.stacks .. "x") or tostring(G.dot.left)) } end
    if G.frozen then list[#list+1] = { key = "freeze", value = 0, text = "" } end
    for i, b in ipairs(P.buffs) do
        local it = list[i]
        if it then
            local info = ns.BUFF_INFO[it.key]
            b.icon:SetTexture(info.icon or GemIcon(info.gem))
            b.text:SetText(it.text)
            if it.cap and it.value >= it.cap then b.text:SetTextColor(1, 0.82, 0) else b.text:SetTextColor(1, 1, 1) end
            b.key, b.value, b.cap = it.key, it.value, it.cap
            b:Show()
        else
            b.key = nil
            b:Hide()
        end
    end
end

-- what the matched gem colours do (once per match)
local function GemBonuses(step)
    G.buffs = G.buffs or { dmg = 0, dr = 0, gold = 0, drop = 0 }
    for _, grp in ipairs(step.groups) do
        local b = ns.GEM_BONUS[grp.color]
        if b then
            if b.kind == "freeze" then
                if not G.frozen and math.random() * 100 < b.chance + ((G.mods and G.mods.freezeChance) or 0) then
                    G.frozen = true
                    G.timer = G.timer + 1
                    SFX("freeze")
                    BattleLog("info", ("%s freezes %s: its next attack comes a move later."):format(GemName(grp.color), Foe()))
                end
            elseif b.kind == "dot" then
                if math.random() * 100 < b.chance + ((G.mods and G.mods.curseChance) or 0) then
                    local fresh = not G.dot
                    local stacks = 1
                    if G.dot and G.mods and G.mods.legendary and G.mods.legendary.legsAbyss then
                        stacks = min(3, (G.dot.stacks or 1) + 1)
                    end
                    G.dot = { left = b.moves, stacks = stacks }
                    SFX("curse")
                    BattleLog("dot", ("%s %s %s: %d%% of its health in shadow damage every move for %d moves."):format(
                        GemName(grp.color), fresh and "curses" or "renews its curse on", Foe(), b.pct, b.moves))
                end
            else
                local cap = BuffCap(b.kind)
                local cur = G.buffs[b.kind] or 0
                if cur < cap then
                    G.buffs[b.kind] = min(cap, cur + b.per)
                    if G.buffs[b.kind] >= cap then
                        local info = ns.BUFF_INFO[b.kind]
                        BattleLog("info", ("%s is at its cap for this tide: %s."):format(info.name, info.text:format(cap)))
                    end
                end
            end
        end
    end
end

-- Shadowgem curse: one tick per move
local function CurseTick()
    if not G.dot or G.enemyHP <= 0 then return end
    local b = ns.GEM_BONUS[6]
    local d = max(1, floor(G.enemy.hp * b.pct / 100)) * (G.dot.stacks or 1)
    G.enemyHP = G.enemyHP - d
    G.dot.left = G.dot.left - 1
    ns.Stats:Add("damage", d)
    BattleLog("dot", ("%s suffers %s shadow damage (%d move%s left)."):format(Foe(), Num(d), G.dot.left, G.dot.left == 1 and "" or "s"))
    if G.dot.left <= 0 then G.dot = nil end
end

local function EndMove()
    local M = G.mods or {}
    G.moves = G.moves + 1
    G.fightMoves = (G.fightMoves or 0) + 1
    if G.moveCascades > G.bestCombo then G.bestCombo = G.moveCascades end
    ns.Stats:Move(G.moveDamage or 0, G.moveCascades)
    if G.critThisMove and (M.flurry or 0) > 0 then G.flurryReady = true end
    if G.moveCascades >= 3 and (M.comboHeal or 0) > 0 then
        local got = UI:HealPlayer(M.comboHeal)
        if got > 0 then BattleLog("heal", ("%s's Blood Craze heals for %s."):format(Me(), Num(got))) end
    end
    local cxp = ns.Prog:ComboXP(G.moveCascades)
    if cxp > 0 then UI:GainXP(cxp, ("for the x%d combo"):format(G.moveCascades)) end
    CurseTick()
    if G.enemyHP > 0 and G.moveCascades >= 3 and M.legendary and M.legendary.clawAngler then
        UI:ForgeSpecial("flame", "Claw of Lord Angler")
    end
    if G.enemyHP <= 0 then UI:UpdatePanel(); return EnemyDefeated() end
    if G.fightMoves == UI:EnrageAt() + 1 then
        SFX("mobAggro")
        BattleLog("warn", ("%s becomes enraged! Each move it hits %d%% harder."):format(Foe(), ns.ENRAGE_PER_MOVE))
    end
    local staggerAt = (M.stagger2 or 0) > 0 and 2 or ns.STAGGER_CASCADE
    if G.moveCascades >= staggerAt then
        BattleLog("info", ("%s's x%d combo staggers %s: its attack is delayed."):format(Me(), G.moveCascades, Foe()))
    elseif math.random() * 100 < (M.hamstring or 0) then
        BattleLog("info", ("Hamstring! %s's attack doesn't come any closer."):format(Foe()))
    else
        G.timer = G.timer - 1
    end
    if G.timer <= 0 then
        EnemyAttack()
        G.timer = G.enemy.every
    end
    if G.timer == 1 and G.playerHP > 0 and not G.warned then
        G.warned = true
        Sound("RAID_WARNING")
        BattleLog("warn", Foe() .. " raises its claws: it strikes after your next move!")
    elseif G.timer > 1 then
        G.warned = false
    end
    UI:UpdatePanel()
    if G.playerHP <= 0 then return GameOver() end
    CheckMoves(function()
        G.busy = false
        UI.idle = 0
        Save()
    end)
end

-- What caused this cascade step, as the start of a log sentence
local SPECIAL_ORDER = { "nova", "star", "hyper", "flame" }
local function DescribeStep(step)
    local me = Me()
    local eff = step.effects[1]
    if step.hyper and eff then
        if eff.kind == "board" then return me .. " smashes two Hypercubes together and clears the board" end
        if #step.transforms > 0 then
            local sp = ns.SPECIAL_INFO[step.transforms[1].special].name
            return ("%s's Hypercube turns every %s into a %s and sets them off"):format(me, GemName(eff.color), sp)
        end
        return ("%s's Hypercube destroys every %s"):format(me, GemName(eff.color))
    end
    local text
    if step.cascade >= 2 then
        text = ("%s hits a x%d combo"):format(me, step.cascade)
    else
        local parts = {}
        for i, grp in ipairs(step.groups) do
            if i > 2 then parts[#parts] = parts[#parts] .. " and more"; break end
            parts[#parts+1] = #grp.list .. " " .. GemName(grp.color)
        end
        text = me .. " matches " .. JoinList(parts)
    end
    local made = {}
    for _, cr in ipairs(step.created) do made[#made+1] = "a " .. ns.SPECIAL_INFO[cr.special].name end
    if #made > 0 then text = text .. ", forging " .. JoinList(made) end
    local counts = {}
    for _, e in ipairs(step.effects) do counts[e.kind] = (counts[e.kind] or 0) + 1 end
    local boom = {}
    for _, k in ipairs(SPECIAL_ORDER) do
        if counts[k] then boom[#boom+1] = Count(counts[k], ns.SPECIAL_INFO[k].name) end
    end
    if #boom > 0 then text = text .. (#made > 0 and " and setting off " or ", setting off ") .. JoinList(boom) end
    return text
end

-- Damage, heal and score for one cascade step
-- damage of one cascade step: the score, boosted by level, talents and gear
local function StepDamage(step, ignoreShell)
    local e, M = G.enemy, G.mods or {}
    local plain = step.plainScore or 0
    local boom = step.explodeScore or 0
    local rest = max(0, step.score - plain - boom)
    local plainMult = 1 + (M.plain or 0) / 100
    if e.trait == "shell" and not ignoreShell then
        plainMult = plainMult - 0.5 * (1 - min(100, M.shellPierce or 0) / 100)
    end
    local kinds = {}
    for _, ef in ipairs(step.effects) do kinds[ef.kind] = true end
    local boomPct = (M.special or 0) + (kinds.flame and (M.flameBonus or 0) or 0) + (kinds.star and (M.starBonus or 0) or 0)
        + ((kinds.hyper or kinds.board) and (M.hyperBonus or 0) or 0)
    local base = rest + plain * plainMult + boom * (1 + boomPct / 100) + (M.weaponFlat or 0)
    local c = step.cascade
    local comboMult = 1 + ((M.combo or 0) * (c - 1) + (c >= 3 and (M.tidal3 or 0) or 0)) / 100
    local pct = (M.dmg or 0) + (M.levelDmg or 0) + (G.moveBuff or 0) + ((G.buffs and G.buffs.dmg) or 0)
    if G.enemyHP < e.hp * 0.2 then pct = pct + (M.execute or 0) end
    if G.playerHP < (G.maxHP or 100) * 0.3 then pct = pct + (M.lastStand or 0) end
    if (G.fightMoves or 0) < 3 then pct = pct + (M.firstStrike or 0) end
    if (M.tidebringer or 0) > 0 then pct = pct + M.tidebringer * min(5, G.board:CountSpecials()) end
    return base * comboMult * (1 + pct / 100)
end

local function ApplyStep(step)
    local e = G.enemy
    local M = G.mods or {}
    local raw = StepDamage(step)
    local critChance = (M.crit or 0) + (step.cascade >= 2 and (M.comboCrit or 0) or 0)
    local crit = math.random() * 100 < critChance
    local critMult = crit and (1.5 + (M.critDmg or 0) / 100) or 1
    local double = math.random() * 100 < (M.doubleHit or 0)
    local dmg = max(1, floor(raw * critMult * (double and 2 or 1) + 0.5))
    local blocked = 0
    if e.trait == "shell" then blocked = max(0, floor(StepDamage(step, true) * critMult + 0.5) - dmg) end
    if crit then G.critThisMove = true end
    G.score = G.score + step.score
    G.enemyHP = G.enemyHP - dmg
    G.moveDamage = (G.moveDamage or 0) + dmg
    G.dealtSince = (G.dealtSince or 0) + dmg
    ns.Stats:Add("damage", dmg)
    ns.Stats:Add("gems", #step.cleared)
    G.moveCascades = max(G.moveCascades, step.cascade)
    -- hit on the makrura
    local big = dmg >= 500
    local line = DescribeStep(step) .. (": %s takes %s damage"):format(Foe(), Num(dmg))
    if crit then line = line .. " |cffff4040(critical)|r" end
    if double then line = line .. " |cffffd100(double damage)|r" end
    if blocked > 0 then line = line .. (" (its hard shell blocks %s)"):format(Num(blocked)) end
    BattleLog(big and "big" or "dealt", line .. (big and "!" or "."))
    local emeralds = step.colorCount[ns.EMERALD] or 0
    local perGem = max(ns.HEAL_PER_EMERALD, floor(UI:HitSize() * ns.GEM_BONUS.emeraldHit + 0.5))
    local heal = emeralds * (perGem + (M.emerald or 0)) * (1 + (M.resto or 0) / 100) + #step.created * (M.forgeHeal or 0)
    if M.emeraldProcChance then
        for _, grp in ipairs(step.groups) do
            if grp.color == ns.EMERALD and math.random() * 100 < M.emeraldProcChance then heal = heal + M.emeraldProcHeal end
        end
    end
    if M.legendary and M.legendary.heartDeep then heal = heal + floor(dmg * 0.03) end
    GemBonuses(step)
    if M.legendary and M.legendary.gripsUndertow then
        for _, cr in ipairs(step.created) do
            if cr.special == "hyper" then UI:ForgeSpecial("nova", "Grips of the Undertow") end
        end
    end
    if heal > 0 and G.playerHP > 0 then
        local got = UI:HealPlayer(heal)
        if got > 0 then
            local why
            if emeralds > 0 then
                why = step.cascade >= 2 and ("the x%d combo"):format(step.cascade)
                    or ("matching %d %s"):format(emeralds, GemName(ns.EMERALD))
            elseif #step.created > 0 and (M.forgeHeal or 0) > 0 then
                why = "forging a special gem"
            else
                why = "the Heart of the Deep"
            end
            BattleLog("heal", ("%s heals for %s from %s."):format(Me(), Num(got), why))
        end
    end
    FX({ region = P.hit, dur = 0.25, a0 = 0.35, a1 = 0 })
    WoundSound(big)
    if G.enemyHP > 0 then ModelAnim(9, 0.5) end
    UI.shake = 0.25
    UI:UpdatePanel()
end

-- Visuals for one cleared step, then call after()
local function ShowStep(step, after)
    local lifetime = #step.effects > 0 and 0.3 or 0.2
    local played = {}      -- one sound per kind of explosion per step
    for _, eff in ipairs(step.effects) do
        local info = ns.SPECIAL_INFO[eff.kind]
        local rgb = (eff.color and eff.color > 0 and ns.GEMS[eff.color].rgb) or (info and info.rgb) or { 1, 1, 1 }
        if eff.kind == "flame" then
            Burst(eff.c, eff.r, { 1, 0.45, 0.1 }, CELL * 3)
            Burst(eff.c, eff.r, { 1, 0.85, 0.3 }, CELL * 2, 0.08)
            if not played.flame then SFX("flame"); played.flame = true end
        elseif eff.kind == "star" then
            if not played.star then SFX("star"); played.star = true end
            Beam(true, eff.r, { 0.7, 0.85, 1 }, 1); Beam(false, eff.c, { 0.7, 0.85, 1 }, 1)
            Burst(eff.c, eff.r, { 0.7, 0.85, 1 }, CELL * 2)
        elseif eff.kind == "nova" then
            if not played.nova then SFX("nova"); played.nova = true end
            for d = -1, 1 do Beam(true, eff.r + d, { 1, 0.9, 0.5 }, 1); Beam(false, eff.c + d, { 1, 0.9, 0.5 }, 1) end
            BoardFlash({ 1, 0.9, 0.5 }, 0.35)
        elseif eff.kind == "hyper" or eff.kind == "board" then
            if not played[eff.kind] then SFX(eff.kind); played[eff.kind] = true end
            BoardFlash(eff.kind == "board" and { 1, 1, 1 } or rgb, 0.4)
            for i, k in ipairs(eff.cells or {}) do
                local c, r = Board.unkey(k)
                Burst(c, r, eff.kind == "board" and ns.GEMS[((i - 1) % 7) + 1].rgb or rgb, CELL, (i % 8) * 0.03)
            end
            lifetime = 0.45
        end
    end
    for _, cl in ipairs(step.cleared) do
        local s = sprites[cl.id]
        if s then
            local rgb = cl.color > 0 and ns.GEMS[cl.color].rgb or { 1, 1, 1 }
            Burst(cl.c, cl.r, rgb, CELL * 0.9)
            s:SetFrameLevel(board:GetFrameLevel() + 4)
            Tween(s, { s0 = 1, s1 = 1.35, a0 = 1, a1 = 0, dur = lifetime, ease = "outQuad", done = ReleaseSprite })
        end
    end
    for _, cr in ipairs(step.created) do
        ns.Stats:Special(cr.special)
        local s = sprites[cr.id]
        if s then
            StyleSprite(s, G.board.grid[cr.c][cr.r])
            s:SetFrameLevel(board:GetFrameLevel() + 5)
            Tween(s, { s0 = 1.5, s1 = 1, dur = 0.3, ease = "outBack", done = function(sp) sp:SetFrameLevel(board:GetFrameLevel() + 2) end })
            local info = ns.SPECIAL_INFO[cr.special]
            local x, y = CellXY(cr.c, cr.r)
            FloatText(info.name .. "!", x, y + 10, info.rgb, "GameFontNormal", nil, nil, 24, 1.1)
            SFX("forged")
        end
    end
    for _, tr in ipairs(step.transforms) do
        local s = sprites[tr.id]
        if s then StyleSprite(s, { id = tr.id, color = s.gem.color, special = tr.special }) end
    end
    -- score popups
    for _, grp in ipairs(step.groups) do
        local sx, sy = 0, 0
        for _, k in ipairs(grp.list) do local c, r = Board.unkey(k); local x, y = CellXY(c, r); sx = sx + x; sy = sy + y end
        sx, sy = sx / #grp.list, sy / #grp.list
        FloatText(comma(grp.points), sx, sy, ns.GEMS[grp.color].rgb, "GameFontNormalLarge", nil, nil, 26, 0.9)
    end
    if step.cascade >= 2 then
        local cheer = CHEERS[step.cascade] or "Unbelievable!"
        Banner(cheer, { 1, 0.85, 0.2 }, "Combo x" .. step.cascade, 0.35)
    end
    if #step.cleared > 0 then
        SFX("gemPutdown")
    end
    ApplyStep(step)
    WhenIdle(after)
end

local function ShowFall(g, after)
    for _, mv in ipairs(g.moves) do
        local s = sprites[mv.id]
        if s then
            local x, y = CellXY(mv.c, mv.to)
            Tween(s, { x = x, y = y, dur = 0.1 + 0.05 * (mv.to - mv.from), ease = "inQuad" })
        end
    end
    for _, sp in ipairs(g.spawns) do
        local s = AcquireSprite(sp.gem)
        local x, y = CellXY(sp.c, sp.from)
        PlaceSprite(s, x, y, 1)
        local tx, ty = CellXY(sp.c, sp.to)
        Tween(s, { x = tx, y = ty, dur = 0.1 + 0.05 * (sp.to - sp.from), ease = "inQuad" })
    end
    WhenIdle(after)
end

local function Cascade(cascade, prefer)
    local step = G.board:Step(cascade, prefer)
    if not step then return EndMove() end
    ShowStep(step, function()
        ShowFall(G.board:Gravity(), function() Cascade(cascade + 1) end)
    end)
end

---------------------------------------------------------------------------
-- Player moves
---------------------------------------------------------------------------
function UI:TrySwap(c1, r1, c2, r2)
    if G.busy or G.over or G.paused then return end
    UI:ClearSelection(); UI:HideHint()
    local a, b = G.board.grid[c1][r1], G.board.grid[c2][r2]
    local sa, sb = sprites[a.id], sprites[b.id]
    local x1, y1 = CellXY(c1, r1)
    local x2, y2 = CellXY(c2, r2)
    G.busy = true
    G.moveCascades = 0
    G.moveDamage = 0

    local result, hyperStep = G.board:TrySwap(c1, r1, c2, r2)
    if result ~= "invalid" then
        G.roundId = (G.roundId or 0) + 1
        -- Overpower / Flurry bonuses are used up by this move
        local M = G.mods or {}
        G.moveBuff = (G.overpowerReady and (M.overpower or 0) or 0) + (G.flurryReady and (M.flurry or 0) or 0)
        G.overpowerReady, G.flurryReady, G.critThisMove = false, false, false
    end
    sa:SetFrameLevel(board:GetFrameLevel() + 3)
    if result == "invalid" then
        -- slide into the intended spot, pause, slide back, then a little "no" shake
        Tween(sa, { x = x2, y = y2, dur = 0.16 }); Tween(sb, { x = x1, y = y1, dur = 0.16 })
        WhenIdle(function()
            Tween(sa, { x = x1, y = y1, dur = 0.16, delay = 0.08 }); Tween(sb, { x = x2, y = y2, dur = 0.16, delay = 0.08 })
            WhenIdle(function()
                SFX("badMove")
                local offsets = { 5, -5, 4, -3, 2, 0 }
                local i = 0
                local function nextShake(sp)
                    i = i + 1
                    if offsets[i] then
                        Tween(sp, { x = x1 + offsets[i], y = y1, dur = 0.045, ease = "linear", done = nextShake })
                    end
                end
                nextShake(sa)
                WhenIdle(function()
                    sa:SetFrameLevel(board:GetFrameLevel() + 2)
                    G.busy = false
                    UI.idle = 0
                end)
            end)
        end)
    elseif result == "hyper" then
        -- the cube flies into its target
        local cube = a.special == "hyper" and sa or sb
        local tx, ty = a.special == "hyper" and x2 or x1, a.special == "hyper" and y2 or y1
        Tween(cube, { x = tx, y = ty, dur = 0.16 })
        WhenIdle(function()
            G.moveCascades = 1
            ShowStep(hyperStep, function()
                ShowFall(G.board:Gravity(), function() Cascade(2) end)
            end)
        end)
    else
        Tween(sa, { x = x2, y = y2, dur = 0.16 }); Tween(sb, { x = x1, y = y1, dur = 0.16 })
        WhenIdle(function()
            Cascade(1, { [Board.key(c1, r1)] = true, [Board.key(c2, r2)] = true })
        end)
    end
end

-- selection / hint glows
function UI:ClearSelection()
    local old = UI.selSprite
    UI.sel, UI.selSprite = nil, nil
    if old then SetMark(old, nil) end
end

function UI:Select(c, r)
    UI:ClearSelection()
    local gem = G.board.grid[c][r]
    local sp = gem and sprites[gem.id]
    if not sp then return end
    UI.sel, UI.selSprite = { c, r }, sp
    SetMark(sp, "select")
end

function UI:HideHint()
    local old = UI.hintSprite
    UI.hintSprite, UI.hintKind = nil, nil
    if old and old ~= UI.selSprite then SetMark(old, nil) end
end

-- kind: "manual" (Hint button) or "auto" (no move found for a while)
function UI:ShowHint(kind)
    if G.busy or G.over or G.paused or not G.board then return end
    local c, r = G.board:HintMover()
    if not c then return end
    UI:HideHint()
    local sp = sprites[G.board.grid[c][r].id]
    if not sp then return end
    UI.hintSprite, UI.hintKind = sp, kind or "manual"
    if sp ~= UI.selSprite then SetMark(sp, UI.hintKind) end
    if kind ~= "auto" then UI.idle = 0 end
end

local function CursorCell()
    local x, y = GetCursorPosition()
    local s = board:GetEffectiveScale()
    x, y = x / s, y / s
    local cx, cy = x - board:GetLeft(), board:GetTop() - y
    local c, r = floor(cx / CELL) + 1, floor(cy / CELL) + 1
    if c < 1 or c > SIZE or r < 1 or r > SIZE then return nil end
    return c, r, cx, cy
end

local function OnMouseDown(_, button)
    if button ~= "LeftButton" or G.busy or G.over or G.paused then return end
    local c, r = CursorCell()
    if not c then return end
    UI.idle = 0
    if UI.sel and Board.Adjacent(UI.sel[1], UI.sel[2], c, r) then
        local s = UI.sel
        UI:TrySwap(s[1], s[2], c, r)
        return
    end
    if UI.sel and UI.sel[1] == c and UI.sel[2] == r then UI:ClearSelection() return end
    UI:Select(c, r)
    UI.drag = { c = c, r = r }
    SFX("gemPickup")
end

local function OnMouseUp() UI.drag = nil end

function UI:InputUpdate(el)
    -- makrura shake when hit
    if UI.shake and UI.shake > 0 and P.model then
        UI.shake = UI.shake - el
        local o = UI.shake > 0 and (sin(clock * 60) * 3) or 0
        P.model:ClearAllPoints()
        P.model:SetPoint("TOPLEFT", 2 + o, -18); P.model:SetPoint("BOTTOMRIGHT", -2 + o, 14)
    end
    if not G.board or G.paused then return end
    -- drag a gem onto a neighbour
    local d = UI.drag
    if d and not G.busy then
        if not IsMouseButtonDown("LeftButton") then UI.drag = nil
        else
            local _, _, cx, cy = CursorCell()
            if cx then
                local ox, oy = (d.c - 0.5) * CELL, (d.r - 0.5) * CELL
                local dx, dy = cx - ox, cy - oy
                if max(abs(dx), abs(dy)) > CELL * 0.55 then
                    local tc, tr = d.c, d.r
                    if abs(dx) > abs(dy) then tc = tc + (dx > 0 and 1 or -1) else tr = tr + (dy > 0 and 1 or -1) end
                    UI.drag = nil
                    if tc >= 1 and tc <= SIZE and tr >= 1 and tr <= SIZE then UI:TrySwap(d.c, d.r, tc, tr) end
                end
            end
        end
    end
    -- automatic hint after a while
    if not G.busy and not G.over and not G.paused and ns.db.autohint then
        UI.idle = (UI.idle or 0) + el
        if UI.idle > (ns.db.hintDelay or 15) and not UI.hintSprite then UI:ShowHint("auto") end
    end
    -- tooltip for special gems
    if inputFrame:IsMouseOver() then
        local c, r = CursorCell()
        local gem = c and G.board.grid[c][r]
        local sp = gem and gem.special
        if sp ~= UI.tipSpecial or (sp and (c ~= UI.tipC or r ~= UI.tipR)) then
            UI.tipSpecial, UI.tipC, UI.tipR = sp, c, r
            if sp then
                local info = ns.SPECIAL_INFO[sp]
                GameTooltip:SetOwner(inputFrame, "ANCHOR_CURSOR")
                local name = sp == "hyper" and info.name or (ns.GEMS[gem.color].name .. " " .. info.name)
                GameTooltip:SetText(name, info.rgb[1], info.rgb[2], info.rgb[3])
                GameTooltip:AddLine(info.how, 1, 1, 1, true)
                GameTooltip:Show()
            elseif GameTooltip:GetOwner() == inputFrame then
                GameTooltip:Hide()
            end
        end
    elseif UI.tipSpecial then
        UI.tipSpecial = nil
        if GameTooltip:GetOwner() == inputFrame then GameTooltip:Hide() end
    end
end

---------------------------------------------------------------------------
-- Build + show
---------------------------------------------------------------------------
function UI:Build()
    if f then return end
    f = MakeWindow()
    local pos = ns.db.pos
    f:ClearAllPoints()
    if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("CENTER") end

    board = CreateFrame("Frame", nil, f)
    board:SetSize(BOARD_PX, BOARD_PX)
    board:SetPoint("TOPLEFT", 14, -64)
    board:SetFrameLevel(f:GetFrameLevel() + 5)
    if board.SetClipsChildren then board:SetClipsChildren(true) end
    Backdrop(board, 0.7)
    for c = 1, SIZE do for r = 1, SIZE do
        local t = board:CreateTexture(nil, "BACKGROUND", nil, 2)
        t:SetSize(CELL, CELL)
        t:SetPoint("TOPLEFT", (c - 1) * CELL, -(r - 1) * CELL)
        local light = (c + r) % 2 == 0
        t:SetColorTexture(0.25, 0.35, 0.45, light and 0.22 or 0.10)
    end end

    fxLayer = CreateFrame("Frame", nil, board)
    fxLayer:SetAllPoints()
    fxLayer:SetFrameLevel(board:GetFrameLevel() + 10)
    -- effects over the side panel must not be clipped by the board
    UI.panelFx = CreateFrame("Frame", nil, f)
    UI.panelFx:SetAllPoints()
    UI.panelFx:SetFrameLevel(f:GetFrameLevel() + 40)
    BuildBattleText()

    inputFrame = CreateFrame("Frame", nil, board)
    inputFrame:SetAllPoints()
    inputFrame:SetFrameLevel(board:GetFrameLevel() + 20)
    inputFrame:EnableMouse(true)
    inputFrame:SetScript("OnMouseDown", OnMouseDown)
    inputFrame:SetScript("OnMouseUp", OnMouseUp)


    BuildPanel()

    driver = CreateFrame("Frame", nil, f)
    driver:SetScript("OnUpdate", DriverUpdate)

    f:SetScript("OnShow", function() UI:UpdateMusic() end)
    f:SetScript("OnHide", function()
        UI:UpdateMusic()
        Save()
        if GameTooltip:GetOwner() == inputFrame then GameTooltip:Hide() end
        Sound("IG_MAINMENU_CLOSE")
    end)
end

function UI:Toggle()
    UI:Build()
    if f:IsShown() then f:Hide() return end
    f:Show()
    Sound("IG_MAINMENU_OPEN")
    -- always open on the menu; a fight in progress waits behind "Continue"
    if G.board and not G.over and not G.busy then Save() end
    UI:ShowMenu()
end

function UI:Open() UI:Build(); if not f:IsShown() then UI:Toggle() end end
function UI:IsShown() return f and f:IsShown() end
function UI:GetFrame() return f end
