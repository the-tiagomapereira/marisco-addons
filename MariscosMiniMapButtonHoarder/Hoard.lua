-- Marisco's MiniMapButtonHoarder - collecting buttons, layouts, fan animation
local ADDON, ns = ...

local hoard   = {}    -- [button] = state
local ordered = {}    -- hoarded buttons, sorted by name
local hooked  = {}    -- buttons already hooked (hooks can't be removed, so they check hoard[])
local container       -- invisible frame the buttons live in, centered on the main button
local isOpen  = false
local anim            -- running animation, or nil
local idle    = 0     -- seconds the pointer has been away from the fan
local busy    = false -- true while we move a button ourselves
local hovered         -- the button under the pointer (hover zoom)

ns.hoard, ns.ordered = hoard, ordered

local OPEN_TIME, CLOSE_TIME, STAGGER = 0.30, 0.20, 0.03
ns.OPEN_TIME, ns.CLOSE_TIME, ns.STAGGER = OPEN_TIME, CLOSE_TIME, STAGGER

-- Blizzard's own minimap furniture stays where it is (use /mmbh add to take one anyway)
local BLIZZARD = {
    MinimapBackdrop = true, MinimapBorder = true, MinimapBorderTop = true,
    MinimapZoomIn = true, MinimapZoomOut = true, MinimapZoneTextButton = true,
    MiniMapTracking = true, MiniMapTrackingFrame = true, MiniMapTrackingButton = true,
    MiniMapMailFrame = true, MiniMapBattlefieldFrame = true, MiniMapWorldMapButton = true,
    MiniMapLFGFrame = true, LFGMinimapFrame = true, MinimapToggleButton = true,
    GameTimeFrame = true, TimeManagerClockButton = true, MiniMapMeetingStoneFrame = true,
    QueueStatusMinimapButton = true, MiniMapInstanceDifficulty = true,
    ExpansionLandingPageMinimapButton = true, GarrisonLandingPageMinimapButton = true,
    MinimapCompassTexture = true, MinimapNorthTag = true,
    MariscosMMBHButton = true, MariscosMMBHFan = true,
}
-- map pins and arrows from gathering / quest / waypoint addons are not buttons
local SKIP_PATTERNS = {
    "^MiniMap", "^Minimap", "^HandyNotes", "^GatherMate", "^GatherNote", "^Questie",
    "^TomTom", "^HBD", "Pin%d*$", "^Routes", "^RareScanner", "^RS_",
}

function ns.DisplayName(f)
    local n = f:GetName() or "?"
    return (n:gsub("^LibDBIcon10_", ""))
end

function ns.IsOpen() return isOpen end

local function SavePoints(f)
    local t = {}
    for i = 1, f:GetNumPoints() do
        local p, rel, rp, x, y = f:GetPoint(i)
        t[i] = { p, rel, rp, x, y }
    end
    return t
end

local function Apply(f)
    local st = hoard[f]
    if not st then return end
    local s = f:GetScale()
    if not s or s == 0 then s = 1 end
    busy = true
    f:ClearAllPoints()
    f:SetPoint("CENTER", container, "CENTER", (st.x or 0) / s, (st.y or 0) / s)
    busy = false
end

local function SetA(f, a)
    busy = true
    f:SetAlpha(a)
    busy = false
end

local function IsCandidate(f)
    if f.IsForbidden and f:IsForbidden() then return false end
    if f == ns.main or f == container then return false end
    local name = f.GetName and f:GetName()
    if type(name) ~= "string" then return false end
    local db = ns.db
    if db.ignore[name] then return false end
    if f:IsProtected() then return false end
    local t = f:GetObjectType()
    if t ~= "Button" and t ~= "Frame" and t ~= "CheckButton" then return false end
    if db.include[name] then return true end
    if name:find("^LibDBIcon10_") then return true end
    if BLIZZARD[name] then return false end
    for _, p in ipairs(SKIP_PATTERNS) do
        if name:find(p) then return false end
    end

    if not f:IsMouseEnabled() then return false end
    local clickable = (f:HasScript("OnClick") and f:GetScript("OnClick"))
        or (f:HasScript("OnMouseUp") and f:GetScript("OnMouseUp"))
        or (f:HasScript("OnMouseDown") and f:GetScript("OnMouseDown"))
    if not clickable then return false end

    local w, h = f:GetSize()
    if not w or not h or w < 14 or h < 14 or w > 50 or h > 50 then return false end
    if math.max(w, h) / math.min(w, h) > 1.6 then return false end

    -- real buttons sit on the rim of the minimap, not in the middle of it
    local fx, fy = f:GetCenter()
    local mx, my = Minimap:GetCenter()
    if fx and mx then
        local s = f:GetEffectiveScale() / Minimap:GetEffectiveScale()
        local dx, dy = fx * s - mx, fy * s - my
        if math.sqrt(dx * dx + dy * dy) < (Minimap:GetWidth() / 2) * 0.6 then return false end
    end
    return true
end

local RequestRelayout

local function Hook(f)
    if hooked[f] then return end
    hooked[f] = true
    -- the owning addon moves its button (login, minimap shape change, drag): keep it in the fan,
    -- and remember where it wanted to go for when the button is given back
    hooksecurefunc(f, "SetPoint", function(self)
        local st = hoard[self]
        if busy or not st then return end
        st.points = SavePoints(self)
        Apply(self)
    end)
    hooksecurefunc(f, "SetParent", function(self, parent)
        local st = hoard[self]
        if busy or not st or parent == container then return end
        st.parent = parent
        busy = true
        self:SetParent(container)
        self:SetFrameStrata("HIGH")
        self:SetFrameLevel(container:GetFrameLevel() + 2)
        busy = false
        Apply(self)
    end)
    hooksecurefunc(f, "SetAlpha", function(self)
        local st = hoard[self]
        if busy or not st then return end
        st.alpha0 = self:GetAlpha()
        SetA(self, st.a or 0)
    end)
    local function vis(self)
        if hoard[self] and not busy then RequestRelayout() end
    end
    hooksecurefunc(f, "Show", vis)
    hooksecurefunc(f, "Hide", vis)
    if f.SetShown then hooksecurefunc(f, "SetShown", vis) end
    -- buttons dragged with StartMoving() don't call SetPoint
    if f:HasScript("OnDragStop") then
        f:HookScript("OnDragStop", function(self)
            if hoard[self] then C_Timer.After(0, function() Apply(self) end) end
        end)
    end
end

---------------------------------------------------------------------------
-- Tidy icons. Minimap buttons draw their icon at a fixed spot that does not
-- line up with the hole of the round border texture (the hole sits up and to
-- the left), which leaves a dark crescent. Measured from the texture itself:
-- the hole's center is 30.1% / 28.7% of the border size from its top-left
-- corner. The icon is centered there, made round, and sized a little bigger
-- than the hole so the border covers its edge; a dark backing sits behind it.
---------------------------------------------------------------------------
ns.RING = { x = 0.301, y = 0.287, icon = 0.37, back = 0.40 }
local BORDER_ID, BACK_ID = 136430, 136467
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local BACK = "Interface\\Minimap\\UI-Minimap-Background"
local skinBusy = false

local function IsTex(tex, id, name)
    local t = tex.GetTexture and tex:GetTexture()
    if t == nil then return false end
    if t == id then return true end
    return type(t) == "string" and t:lower():find(name, 1, true) ~= nil
end

-- the round border, the dark background and the icon of a minimap button
local function FindParts(f)
    local border, back, icon
    local loose = {}
    local hl = f.GetHighlightTexture and f:GetHighlightTexture()
    for _, r in ipairs({ f:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" and r ~= hl then
            if IsTex(r, BORDER_ID, "minimap-trackingborder") then border = border or r
            elseif IsTex(r, BACK_ID, "ui-minimap-background") then back = back or r
            elseif r:GetDrawLayer() == "ARTWORK" then loose[#loose + 1] = r end
        end
    end
    if type(f.icon) == "table" and f.icon.GetObjectType and f.icon:GetObjectType() == "Texture" then
        icon = f.icon
    elseif #loose == 1 then
        icon = loose[1]
    end
    return border, back, icon
end

local function SaveTex(t)
    local w, h = t:GetSize()
    return { points = SavePoints(t), w = w, h = h, shown = t:IsShown() }
end

local function RestoreTex(t, s)
    t:ClearAllPoints()
    for _, p in ipairs(s.points) do t:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
    t:SetSize(s.w, s.h)
    if s.shown then t:Show() else t:Hide() end
end

local function PlaceSkin(f, sk)
    local R, B = ns.RING, sk.size
    local cx, cy = sk.bx + R.x * B, sk.by - R.y * B
    skinBusy = true
    sk.icon:ClearAllPoints()
    sk.icon:SetPoint("CENTER", f, "TOPLEFT", cx, cy)
    sk.icon:SetSize(R.icon * B, R.icon * B)
    sk.back:ClearAllPoints()
    sk.back:SetPoint("CENTER", f, "TOPLEFT", cx, cy)
    sk.back:SetSize(R.back * B, R.back * B)
    sk.back:Show()
    skinBusy = false
end

local skinHooked = {}

local function Skin(f, st)
    if st.skin or not ns.db.tidyIcons then return end
    local border, back, icon = FindParts(f)
    if not border or not icon then return end      -- not a standard round minimap button
    local p, rel, rp, bx, by = border:GetPoint(1)
    if p ~= "TOPLEFT" or (rel and rel ~= f) or (rp and rp ~= "TOPLEFT") then return end
    local sk = { size = border:GetWidth(), bx = bx or 0, by = by or 0, icon = icon, iconSave = SaveTex(icon) }
    if not sk.size or sk.size < 20 then return end
    if back then
        sk.back, sk.backSave = back, SaveTex(back)
    else
        st.ownBack = st.ownBack or f:CreateTexture(nil, "BACKGROUND")
        st.ownBack:SetTexture(BACK)
        sk.back = st.ownBack
    end
    if f.CreateMaskTexture and icon.AddMaskTexture then
        st.mask = st.mask or f:CreateMaskTexture()
        st.mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        st.mask:SetAllPoints(icon)
        icon:AddMaskTexture(st.mask)
        sk.masked = true
    end
    st.skin = sk
    PlaceSkin(f, sk)
    -- if the addon moves its icon again (some do on click), put it back in the middle
    if not skinHooked[icon] then
        skinHooked[icon] = true
        local function again()
            local s = hoard[f]
            if skinBusy or not s or not s.skin or s.skin.icon ~= icon then return end
            PlaceSkin(f, s.skin)
        end
        hooksecurefunc(icon, "SetPoint", again)
        hooksecurefunc(icon, "SetSize", again)
    end
end

local function Unskin(f, st)
    local sk = st.skin
    if not sk then return end
    st.skin = nil
    skinBusy = true
    if sk.masked and st.mask then sk.icon:RemoveMaskTexture(st.mask) end
    RestoreTex(sk.icon, sk.iconSave)
    if sk.backSave then RestoreTex(sk.back, sk.backSave) end
    if st.ownBack then st.ownBack:Hide() end
    skinBusy = false
end

function ns.ApplySkins()
    for f, st in pairs(hoard) do
        if ns.db.tidyIcons then Skin(f, st) else Unskin(f, st) end
    end
end

local function Collect(f)
    local st = {
        parent = f:GetParent(),
        strata = f:GetFrameStrata(),
        level = f:GetFrameLevel(),
        points = SavePoints(f),
        alpha0 = f:GetAlpha(),
        scale0 = f:GetScale() or 1,
        x = 0, y = 0, a = 0,
    }
    hoard[f] = st
    ordered[#ordered + 1] = f
    Hook(f)
    busy = true
    f:SetParent(container)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(container:GetFrameLevel() + 2)
    f:SetScale(st.scale0 * (ns.db.scale or 1))
    busy = false
    Skin(f, st)
    Apply(f)
    SetA(f, 0)
end

local function Release(f)
    local st = hoard[f]
    if not st then return end
    hoard[f] = nil
    if hovered == f then hovered = nil end
    Unskin(f, st)
    for i = #ordered, 1, -1 do
        if ordered[i] == f then table.remove(ordered, i) end
    end
    busy = true
    f:SetParent(st.parent or Minimap)
    if st.strata then f:SetFrameStrata(st.strata) end
    if st.level then f:SetFrameLevel(st.level) end
    f:SetScale(st.scale0 or 1)
    f:SetAlpha(st.alpha0 or 1)
    f:ClearAllPoints()
    local placed = false
    for _, p in ipairs(st.points or {}) do
        if p[2] ~= container then
            f:SetPoint(p[1], p[2], p[3], p[4], p[5])
            placed = true
        end
    end
    if not placed then f:SetPoint("CENTER", Minimap, "BOTTOMLEFT", 0, 0) end
    busy = false
end
ns.Release = Release

-- size = the button's own scale x the size setting x the hover zoom
local function SetZoom(f, st)
    busy = true
    f:SetScale((st.scale0 or 1) * (ns.db.scale or 1) * (st.zoom or 1))
    busy = false
    Apply(f)
end

-- button size setting
function ns.ApplyScale()
    for f, st in pairs(hoard) do SetZoom(f, st) end
end

---------------------------------------------------------------------------
-- Hover zoom: the button under the pointer grows, and shrinks back when the
-- pointer leaves. Eases toward its target every frame, so it stays smooth
-- even when the pointer sweeps quickly across several buttons.
---------------------------------------------------------------------------
local ZOOM_SPEED = 22   -- higher = faster (about 0.13 s to get there)

local function FindHovered()
    if not (isOpen and ns.db.hoverZoom) then return nil end
    local px, py = GetCursorPosition()
    local best, bestD
    for _, f in ipairs(ordered) do
        if f:IsShown() and f:IsMouseOver() then
            -- grown buttons can overlap a neighbour a little: take the one nearest the pointer
            local fx, fy = f:GetCenter()
            local s = f:GetEffectiveScale()
            local d = fx and ((fx * s - px) ^ 2 + (fy * s - py) ^ 2) or 0
            if not bestD or d < bestD then best, bestD = f, d end
        end
    end
    return best
end

local function UpdateHover(elapsed)
    local now = FindHovered()
    if now ~= hovered then
        local base = container:GetFrameLevel() + 2
        busy = true
        if hovered and hoard[hovered] then hovered:SetFrameLevel(base) end
        if now then now:SetFrameLevel(base + 4) end  -- the grown one sits on top
        busy = false
        hovered = now
    end
    local k = 1 - math.exp(-elapsed * ZOOM_SPEED)
    local big = ns.db.hoverScale or 1.25
    for f, st in pairs(hoard) do
        local goal = (f == hovered) and big or 1
        local z = st.zoom or 1
        if z ~= goal then
            z = z + (goal - z) * k
            if math.abs(goal - z) < 0.002 then z = goal end
            st.zoom = z
            SetZoom(f, st)
        end
    end
end

local function ResetZoom()
    for f, st in pairs(hoard) do
        if st.zoom and st.zoom ~= 1 then
            st.zoom = 1
            SetZoom(f, st)
        end
    end
    if hovered and hoard[hovered] then
        busy = true
        hovered:SetFrameLevel(container:GetFrameLevel() + 2)
        busy = false
    end
    hovered = nil
end

local function Sort()
    table.sort(ordered, function(a, b)
        return ns.DisplayName(a):lower() < ns.DisplayName(b):lower()
    end)
end

---------------------------------------------------------------------------
-- Layouts. Each shape is built in local space: u = away from the hoarder,
-- v = sideways. The settings preview uses the same function.
---------------------------------------------------------------------------
function ns.ShapePoints(kind, n, size, gap, start, minR, spreadDeg)
    local step = size + gap
    local pts = {}
    if kind == "horizontal" or kind == "vertical" then
        -- a straight line leading away from the hoarder
        for i = 0, n - 1 do pts[#pts + 1] = { start + i * step, 0 } end

    elseif kind == "box" then
        -- a square-ish grid, centered in front of the hoarder
        local cols = math.ceil(math.sqrt(n))
        local i, row = 0, 0
        while i < n do
            local count = math.min(cols, n - i)
            for k = 0, count - 1 do
                pts[#pts + 1] = { start + row * step, (k - (count - 1) / 2) * step }
            end
            i, row = i + count, row + 1
        end

    elseif kind == "triangle" then
        -- point at the hoarder, rows of 1, 2, 3... widening away from it (tightly packed)
        local rowStep = step * 0.87
        local i, row = 0, 0
        while i < n do
            local count = math.min(row + 1, n - i)
            for k = 0, count - 1 do
                pts[#pts + 1] = { start + row * rowStep, (k - (count - 1) / 2) * step }
            end
            i, row = i + count, row + 1
        end

    else
        -- arch: one wide semi-circle, evenly spaced end to end; it grows with the number of
        -- buttons, and only very many buttons get a second, larger arc around it
        spreadDeg = math.max(90, math.min(360, spreadDeg or 180))
        local spread = math.rad(spreadDeg)
        local full = spreadDeg >= 360
        local MAXR = math.max(minR, 170)
        local function capOf(r)
            if full then return math.max(1, math.floor(2 * math.pi * r / step)) end
            return math.floor(spread * r / step) + 1
        end
        local rings = {}
        local need = full and (n * step / (2 * math.pi)) or ((n - 1) * step / spread)
        if need <= MAXR then
            rings[1] = { r = math.max(minR, need), count = n }
        else
            local k, total = 1, capOf(minR)
            while total < n do
                total = total + capOf(minR + k * step)
                k = k + 1
            end
            local left = n
            for j = 0, k - 1 do
                local r = minR + j * step
                local count = (j == k - 1) and left or math.min(left, math.floor(n * capOf(r) / total + 0.5))
                rings[#rings + 1] = { r = r, count = count }
                left = left - count
            end
        end
        for _, ring in ipairs(rings) do
            for k = 0, ring.count - 1 do
                local a
                if ring.count == 1 then a = 0
                elseif full then a = 2 * math.pi * k / ring.count
                else a = -spread / 2 + spread * k / (ring.count - 1) end
                pts[#pts + 1] = { ring.r * math.cos(a), ring.r * math.sin(a) }
            end
        end
    end
    return pts
end

local OFFSETS = { 0, 15, -15, 30, -30, 45, -45, 60, -60, 75, -75, 90, -90, 120, -120, 150, -150, 180 }

local function AngDiff(a, b)
    local d = (a - b) % (2 * math.pi)
    if d > math.pi then d = 2 * math.pi - d end
    return d
end

-- directions to try, best first: the arch turns freely, the others stay straight
local function Candidates(kind, out)
    local list = {}
    if kind == "arch" or not kind then
        if (ns.db.spread or 180) >= 360 then return { out } end
        for _, off in ipairs(OFFSETS) do list[#list + 1] = out + math.rad(off) end
        return list
    elseif kind == "horizontal" then
        list = { 0, math.pi }
    elseif kind == "vertical" then
        list = { math.pi / 2, math.pi * 1.5 }
    else
        list = { 0, math.pi / 2, math.pi, math.pi * 1.5 }
    end
    table.sort(list, function(a, b) return AngDiff(a, out) < AngDiff(b, out) end)
    return list
end

local function ComputeLayout()
    local list = {}
    for _, f in ipairs(ordered) do
        if f:IsShown() then list[#list + 1] = f end
    end
    local n = #list
    if n == 0 then return list end

    local db = ns.db
    local size = 24 * (db.scale or 1)
    for _, f in ipairs(list) do
        local w, h = f:GetSize()
        local st = hoard[f]
        local s = (st.scale0 or 1) * (db.scale or 1)  -- ignore hover zoom, so the layout doesn't jump
        size = math.max(size, (w or 0) * s, (h or 0) * s)
    end
    local gap = db.gap or 6
    local start = (ns.main:GetWidth() or 31) / 2 + size / 2 + gap + 2
    local minR = math.max((db.radius or 70) * math.max(1, size / 31), start)
    local kind = db.layout or "arch"
    local pts = ns.ShapePoints(kind, n, size, gap, start, minR, db.spread or 180)

    -- face away from the minimap, turning as little as needed to stay on screen
    local mx, my = ns.main:GetCenter()
    local cx, cy = Minimap:GetCenter()
    local out = (mx and cx) and math.atan2(my - cy, mx - cx) or math.rad(db.angle or 225)
    local cands = Candidates(kind, out)
    local dir = cands[1]
    if mx and #cands > 1 then
        local es = container:GetEffectiveScale()
        local us = UIParent:GetEffectiveScale()
        local W, H = UIParent:GetWidth() * us / es, UIParent:GetHeight() * us / es
        local half = size / 2 + 2
        local best, bestOver
        for _, d in ipairs(cands) do
            local c, s = math.cos(d), math.sin(d)
            local over = 0
            for _, p in ipairs(pts) do
                local x = mx + p[1] * c - p[2] * s
                local y = my + p[1] * s + p[2] * c
                over = over + math.max(0, half - x) + math.max(0, x + half - W)
                    + math.max(0, half - y) + math.max(0, y + half - H)
            end
            if not bestOver or over < bestOver - 0.5 then best, bestOver = d, over end
            if over == 0 then break end
        end
        dir = best
    end

    local c, s = math.cos(dir), math.sin(dir)
    for i, f in ipairs(list) do
        local u, v = pts[i][1], pts[i][2]
        local st = hoard[f]
        st.tx, st.ty = u * c - v * s, u * s + v * c
    end
    ns.layoutSize = size
    return list
end

---------------------------------------------------------------------------
-- Animation
---------------------------------------------------------------------------
function ns.EaseOutBack(t)
    local c1 = 1.4
    local u = t - 1
    return 1 + (c1 + 1) * u * u * u + c1 * u * u
end

local function StartAnim(mode, list, stagger)
    for _, f in ipairs(list) do
        local st = hoard[f]
        st.sx, st.sy, st.sa = st.x or 0, st.y or 0, st.a or 0
    end
    anim = { mode = mode, t = 0, list = list, stagger = stagger and STAGGER or 0 }
end

local function Step(elapsed)
    anim.t = anim.t + elapsed
    local opening = anim.mode == "open"
    local dur = opening and OPEN_TIME or CLOSE_TIME
    local n = #anim.list
    local done = true
    for i, f in ipairs(anim.list) do
        local st = hoard[f]
        if st then
            local order = opening and (i - 1) or (n - i)
            local p = (anim.t - order * anim.stagger) / dur
            if p < 1 then done = false end
            if p < 0 then p = 0 elseif p > 1 then p = 1 end
            local tx, ty, ta, e, pa
            if opening then
                tx, ty, ta, e, pa = st.tx or 0, st.ty or 0, 1, ns.EaseOutBack(p), math.min(1, p * 2)
            else
                tx, ty, ta, e, pa = 0, 0, 0, p * p, p
            end
            st.x = st.sx + (tx - st.sx) * e
            st.y = st.sy + (ty - st.sy) * e
            st.a = st.sa + (ta - st.sa) * pa
            Apply(f)
            SetA(f, st.a)
        end
    end
    if done then
        anim = nil
        if not opening then container:Hide() end
    end
end

-- is the pointer on the hoarder, on one of the buttons, or in a menu one of them opened?
local function PointerNear()
    local dd = _G.DropDownList1
    if dd and dd:IsShown() then return true end
    local ld = _G.L_DropDownList1
    if ld and ld:IsShown() then return true end
    if _G.Menu and _G.Menu.GetManager then
        local ok, open = pcall(function()
            local m = _G.Menu.GetManager()
            return m and m.GetOpenMenu and m:GetOpenMenu()
        end)
        if ok and open then return true end
    end
    local mx, my = ns.main:GetCenter()
    if not mx then return true end
    local px, py = GetCursorPosition()
    local s = container:GetEffectiveScale()
    px, py = px / s - mx, py / s - my
    local gap = ns.db.gap or 6
    local near = 22 + gap
    if px * px + py * py <= near * near then return true end
    local pad = (ns.layoutSize or 31) / 2 + gap + 6
    for _, f in ipairs(ordered) do
        local st = hoard[f]
        if st and f:IsShown() then
            local dx, dy = px - (st.x or 0), py - (st.y or 0)
            if dx * dx + dy * dy <= pad * pad then return true end
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------
function ns.Open()
    if not container then return end
    if not ns.db.enabled then
        ns.Print("Hoarding is off. Type /mmbh on to turn it back on.")
        return
    end
    ns.Scan()
    local list = ComputeLayout()
    if #list == 0 then
        ns.Print("No minimap buttons found yet. Use Scan in the settings (right-click) or /mmbh scan.")
        return
    end
    if not container:IsShown() then
        for f, st in pairs(hoard) do
            st.x, st.y, st.a = 0, 0, 0
            Apply(f)
            SetA(f, 0)
        end
        container:Show()
    end
    isOpen = true
    idle = 0
    StartAnim("open", list, true)
    ns.UpdateMainState()
end

function ns.Close(instant)
    if not container then return end
    if instant then
        isOpen = false
        anim = nil
        container:Hide()
        ns.UpdateMainState()
        return
    end
    if not isOpen then return end
    isOpen = false
    local list = {}
    for _, f in ipairs(ordered) do
        if f:IsShown() then list[#list + 1] = f end
    end
    StartAnim("close", list, true)
    ns.UpdateMainState()
end

function ns.Toggle()
    if isOpen then ns.Close() else ns.Open() end
end

-- recompute the fan while it is open (a button appeared, hid, or settings changed)
function ns.Relayout()
    if not isOpen then return end
    local list = ComputeLayout()
    if #list == 0 then ns.Close(true) return end
    StartAnim("open", list, false)
end

local pending = false
RequestRelayout = function()
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        ns.UpdateBadge()
        ns.Relayout()
    end)
end
ns.RequestRelayout = RequestRelayout

function ns.Scan(verbose)
    if not container or not ns.db.enabled then
        if verbose then ns.Print("Hoarding is off (/mmbh on).") end
        return 0
    end
    local added = 0
    local function try(f)
        if not hoard[f] and IsCandidate(f) then
            Collect(f)
            added = added + 1
        end
    end
    for _, parent in ipairs({ Minimap, MinimapBackdrop }) do
        if parent and parent.GetChildren then
            for _, f in ipairs({ parent:GetChildren() }) do try(f) end
        end
    end
    for name in pairs(ns.db.include) do
        local f = _G[name]
        if type(f) == "table" and type(f.GetObjectType) == "function" then try(f) end
    end
    if added > 0 then
        Sort()
        RequestRelayout()
    end
    ns.UpdateBadge()
    if verbose then
        ns.Print(added > 0 and ("Found " .. added .. " new button" .. (added == 1 and "" or "s") .. ", " .. #ordered .. " hoarded.")
            or ("No new buttons, " .. #ordered .. " hoarded."))
    end
    return added
end

function ns.ReleaseAll()
    ns.Close(true)
    while #ordered > 0 do Release(ordered[#ordered]) end
    ns.UpdateBadge()
end

function ns.CreateContainer(main)
    container = CreateFrame("Frame", "MariscosMMBHFan", Minimap)
    container:SetSize(1, 1)
    container:SetPoint("CENTER", main, "CENTER")
    container:SetFrameStrata("HIGH")
    container:SetFrameLevel(math.max(1, main:GetFrameLevel() - 15))
    container:Hide()
    -- nothing stays grown once the buttons are put away
    container:SetScript("OnHide", ResetZoom)
    container:SetScript("OnUpdate", function(_, elapsed)
        if anim then Step(elapsed) end
        UpdateHover(elapsed)
        if not isOpen then return end
        -- stays open while the settings window is up, so changes show live
        if ns.SettingsShown and ns.SettingsShown() then
            idle = 0
            return
        end
        if ns.db.autoClose then
            -- timer: counts while the pointer is away from the buttons
            if PointerNear() then
                idle = 0
            else
                idle = idle + elapsed
                if idle >= (ns.db.closeDelay or 3) then ns.Close() end
            end
        else
            -- until clicked out: any click away from the hoarder and its buttons
            if (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) and not PointerNear() then
                ns.Close()
            end
        end
    end)
    ns.container = container
end
