-- Marisco's Minimap Unbound
-- Takes the stock minimap (map, top bar, coordinates) out of Edit Mode's clamped cluster and
-- puts each part in its own free holder. Nothing in Edit Mode is moved or saved by this addon.

local ADDON, ns = ...

ns.VERSION = "0.1"
ns.VERSION_LABEL = "v0.1 Beta"
ns.TITLE = "Marisco's Minimap Unbound"
ns.ICON = "Interface\\Icons\\Ability_Hunter_EagleEye"

local PREFIX = "|cff33ccffMinimap Unbound|r: "
local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg)) end
ns.Print = Print

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
ns.DEFAULTS = {
  enabled = true,
  shape = "round",            -- round | square
  skin = "stock",             -- see Skins.lua
  borderColor = { r = 0.85, g = 0.70, b = 0.35, a = 1 },
  thickness = 2,
  size = nil,                 -- nil = the stock size
  alpha = 1,
  barAttached = true,
  barSide = "original",       -- original | above | below
  coordAttached = true,
  coordMode = "auto",         -- auto (Forever's own) | own | hidden
  clamp = false,
  snap = true,
  hideZoom = false,
  wheelZoom = true,
  pos = {},                   -- map / bar / coords: { point, x, y }
  button = { angle = 210, hide = false },
  configPos = nil,
}

local function DeepCopy(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = DeepCopy(v) end
  return c
end
ns.DeepCopy = DeepCopy

local function FillDefaults(dst, src)
  for k, v in pairs(src) do
    if dst[k] == nil then
      dst[k] = DeepCopy(v)
    elseif type(v) == "table" and type(dst[k]) == "table" then
      FillDefaults(dst[k], v)
    end
  end
end
ns.FillDefaults = FillDefaults

---------------------------------------------------------------------------
-- Errors: every handler runs through Safe(). Errors still go to the game's
-- error handler (so BugGrabber-style addons catch them) and the last 10 are
-- kept for /mmu probe.
---------------------------------------------------------------------------
ns.errors = {}
local function ErrorHandler(e)
  local stack = debugstack and debugstack(2, 12, 0) or ""
  table.insert(ns.errors, 1, date("%H:%M:%S") .. "  " .. tostring(e) .. "\n" .. stack)
  while #ns.errors > 10 do table.remove(ns.errors) end
  local h = geterrorhandler and geterrorhandler()
  if h then pcall(h, e) end
  return e
end

local function Safe(fn, ...)
  local n, args = select("#", ...), { ... }
  return xpcall(function() return fn(unpack(args, 1, n)) end, ErrorHandler)
end
ns.Safe = Safe

---------------------------------------------------------------------------
-- Geometry helpers (everything measured in UIParent units)
---------------------------------------------------------------------------
local function EffScale(r)
  if r.GetEffectiveScale then return r:GetEffectiveScale() end
  local p = r.GetParent and r:GetParent()
  return p and p:GetEffectiveScale() or UIParent:GetEffectiveScale()
end

local function UIRect(r)
  if not r or not r.GetRect then return end
  local l, b, w, h = r:GetRect()
  if not l or not w or w <= 0 or h <= 0 then return end
  local s = EffScale(r) / UIParent:GetEffectiveScale()
  return { l = l * s, b = b * s, w = w * s, h = h * s }
end
ns.UIRect = UIRect

local function Union(a, b)
  if not a then return b and { l = b.l, b = b.b, w = b.w, h = b.h } end
  if not b then return a end
  local l, bt = math.min(a.l, b.l), math.min(a.b, b.b)
  local r, t = math.max(a.l + a.w, b.l + b.w), math.max(a.b + a.h, b.b + b.h)
  return { l = l, b = bt, w = r - l, h = t - bt }
end

local function Overlaps(a, b)
  return a and b and a.l < b.l + b.w and b.l < a.l + a.w and a.b < b.b + b.h and b.b < a.b + a.h
end

local function GetPoints(obj)
  local pts = {}
  for i = 1, (obj:GetNumPoints() or 0) do pts[i] = { obj:GetPoint(i) } end
  return pts
end

local function IsDescendant(obj, ancestor)
  local p = obj.GetParent and obj:GetParent()
  while p do
    if p == ancestor then return true end
    p = p:GetParent()
  end
  return false
end

local function Resolve(path)
  local obj = _G
  for part in path:gmatch("[^%.]+") do
    if type(obj) ~= "table" then return end
    obj = obj[part]
  end
  if type(obj) == "table" and obj.GetObjectType then return obj end
end

local function DebugName(obj)
  if not obj then return "nil" end
  local ok, n = pcall(obj.GetDebugName, obj)
  if ok and n and n ~= "" then return n end
  return (obj.GetName and obj:GetName()) or tostring(obj)
end
ns.DebugName = DebugName

-- Position in UIParent: anchored by the nearest screen corner, so a map pushed flush
-- against an edge stays flush when the resolution or UI scale changes.
local function PosFromRect(r, snap)
  local W, H = UIParent:GetWidth(), UIParent:GetHeight()
  local l, b = r.l, r.b
  if snap then
    local d = 8
    if math.abs(l) < d then l = 0 end
    if math.abs(l + r.w - W) < d then l = W - r.w end
    if math.abs(b) < d then b = 0 end
    if math.abs(b + r.h - H) < d then b = H - r.h end
  end
  local cx, cy = l + r.w / 2, b + r.h / 2
  local v = cy > H / 2 and "TOP" or "BOTTOM"
  local hz = cx > W / 2 and "RIGHT" or "LEFT"
  local x = (hz == "LEFT") and l or (l + r.w - W)
  local y = (v == "BOTTOM") and b or (b + r.h - H)
  return { point = v .. hz, x = math.floor(x * 10 + 0.5) / 10, y = math.floor(y * 10 + 0.5) / 10 }
end
ns.PosFromRect = PosFromRect

local function Place(frame, pos)
  frame:ClearAllPoints()
  frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
end

-- Anchor a Blizzard piece by two points so it keeps its size; offsets in UIParent units.
local function Anchor(obj, holder, hp, lx, ty, w, h)
  local k = EffScale(obj) / UIParent:GetEffectiveScale()
  obj:ClearAllPoints()
  obj:SetPoint("TOPLEFT", holder, hp, lx / k, ty / k)
  obj:SetPoint("BOTTOMRIGHT", holder, hp, (lx + w) / k, (ty - h) / k)
end

---------------------------------------------------------------------------
-- What counts as which part of the stock minimap
---------------------------------------------------------------------------
local BAR_NAMES = {
  "MinimapCluster.BorderTop", "MinimapBorderTop",
  "MinimapCluster.ZoneTextButton", "MinimapZoneTextButton",
  "MinimapCluster.Tracking", "MiniMapTracking", "MiniMapTrackingFrame", "MiniMapTrackingButton",
  "GameTimeFrame", "TimeManagerClockButton",
}
local RING_NAMES = { "MinimapBackdrop", "MinimapBorder", "MinimapCompassTexture", "MinimapNorthTag" }
local ZOOM_NAMES = { "Minimap.ZoomIn", "Minimap.ZoomOut", "MinimapZoomIn", "MinimapZoomOut" }
local COORD_PATTERN = "^%s*%(?%s*%-?%d+%.?%d*%s*[,/ ]%s*%-?%d+%.?%d*%s*%)?%s*$"

local stock          -- snapshot of the stock layout, taken once per session before we touch anything
local ready, applying, queued = false, false, false
local holders = {}
ns.holders = holders
local ownCoords
local hooked = {}
local wheelSet = false

local function NewHolder(key)
  local h = CreateFrame("Frame", nil, UIParent)
  h:SetSize(10, 10)
  h:SetMovable(true)
  h:SetClampedToScreen(false)
  h.key = key
  holders[key] = h
  return h
end

local function Queue()
  if applying or queued or not ready then return end
  queued = true
  C_Timer.After(0, function()
    queued = false
    ns.Apply()
  end)
end

local function Hook(obj)
  if not obj or hooked[obj] then return end
  hooked[obj] = true
  if obj.SetPoint then hooksecurefunc(obj, "SetPoint", Queue) end
  if obj.SetParent and obj.GetObjectType and obj:GetObjectType() ~= "FontString"
     and obj:GetObjectType() ~= "Texture" then
    hooksecurefunc(obj, "SetParent", Queue)
  end
end

local function FindCoords(exclude)
  -- 1) a frame whose name mentions coordinates
  for _, root in ipairs({ MinimapCluster, Minimap }) do
    if root then
      for _, c in ipairs({ root:GetChildren() }) do
        local n = DebugName(c)
        if n:lower():find("coord") and not exclude[c] then return c, "name: " .. n end
      end
    end
  end
  -- 2) a font string that reads like "45.2, 63.1"
  local found
  local function scan(frame, depth)
    if found or exclude[frame] then return end
    for _, r in ipairs({ frame:GetRegions() }) do
      if r.GetObjectType and r:GetObjectType() == "FontString" then
        local t = r:GetText()
        if t and t:match(COORD_PATTERN) then found = r return end
      end
    end
    if depth < 5 then
      for _, c in ipairs({ frame:GetChildren() }) do scan(c, depth + 1) end
    end
  end
  for _, root in ipairs({ MinimapCluster, Minimap }) do
    if root and not found then scan(root, 0) end
  end
  if not found then return end
  -- move the small frame that only holds the text, otherwise the text itself
  local p = found:GetParent()
  local pr, fr = UIRect(p), UIRect(found)
  if p and p ~= MinimapCluster and p ~= Minimap and not exclude[p] and pr and fr
     and pr.w * pr.h <= fr.w * fr.h * 4 then
    return p, "text in " .. DebugName(p)
  end
  return found, "text " .. DebugName(found)
end

local function Snapshot()
  local st = { pieces = {}, others = {}, notes = {} }
  local mm = Minimap
  st.mapParent = mm:GetParent()
  st.mapPoints = GetPoints(mm)
  st.mapSize = { mm:GetSize() }
  st.mapStrata = mm:GetFrameStrata()
  st.mapLevel = mm:GetFrameLevel()
  st.map = UIRect(mm)
  if not st.map then return end
  st.wheelScript = mm:GetScript("OnMouseWheel") and true or false

  local seen = { [mm] = true }
  local function add(obj, group, ring)
    if not obj or seen[obj] or obj == MinimapCluster then return end
    local r = UIRect(obj)
    if not r then return end
    seen[obj] = true
    table.insert(st.pieces, { obj = obj, group = group, ring = ring, rect = r, points = GetPoints(obj),
                              alpha = obj:GetAlpha() })
    return true
  end

  -- coordinates first, so they never get swept into the bar
  local exclude = {}
  local cobj, how = FindCoords(exclude)
  if cobj then add(cobj, "coords") st.coordHow = how end

  for _, n in ipairs(BAR_NAMES) do add(Resolve(n), "bar") end
  for _, n in ipairs(RING_NAMES) do add(Resolve(n), "map", true) end

  local barRect
  for _, p in ipairs(st.pieces) do if p.group == "bar" then barRect = Union(barRect, p.rect) end end

  -- anything else in the cluster: goes with whatever it overlaps
  local cl = MinimapCluster and UIRect(MinimapCluster)
  local container = MinimapCluster and MinimapCluster.MinimapContainer
  local kids = {}
  if MinimapCluster then for _, c in ipairs({ MinimapCluster:GetChildren() }) do kids[#kids + 1] = c end end
  if container and container.GetChildren then
    for _, c in ipairs({ container:GetChildren() }) do kids[#kids + 1] = c end
  end
  for _, c in ipairs(kids) do
    if c ~= mm and c ~= container and not seen[c] and c ~= (MinimapCluster and MinimapCluster.Selection) then
      local r = UIRect(c)
      local huge = r and cl and r.w >= cl.w * 0.9 and r.h >= cl.h * 0.9
      if r and not huge then
        if Overlaps(r, barRect) then add(c, "bar")
        elseif Overlaps(r, st.map) then add(c, "map")
        else table.insert(st.others, DebugName(c)) end
      elseif r then
        table.insert(st.others, DebugName(c) .. " (cluster-sized, left alone)")
      end
    end
  end

  for _, p in ipairs(st.pieces) do
    if p.group == "bar" then st.bar = Union(st.bar, p.rect) end
    if p.group == "coords" then st.coords = Union(st.coords, p.rect) end
  end
  return st
end

-- Coordinates may only appear later (empty in instances, or created late): keep looking a while.
local coordTries = 0
local function LookForCoordsLater()
  if stock.coords or coordTries >= 20 then return end
  coordTries = coordTries + 1
  C_Timer.After(3, function()
    if stock.coords then return end
    local exclude = {}
    for _, p in ipairs(stock.pieces) do if p.group == "coords" then exclude[p.obj] = true end end
    local obj, how = FindCoords(exclude)
    if obj then
      local r = UIRect(obj)
      if r then
        -- measured now: if it sits on the moved map, relate it to the map as it is now
        local cur = UIRect(holders.map)
        local base = stock.map
        if cur and Overlaps(r, { l = cur.l - 40, b = cur.b - 40, w = cur.w + 80, h = cur.h + 80 }) then
          base = cur
          local ratio = stock.map.w / cur.w
          local cx, cy = (r.l + r.w / 2 - (cur.l + cur.w / 2)) * ratio, (r.b + r.h / 2 - (cur.b + cur.h / 2)) * ratio
          r = { l = stock.map.l + stock.map.w / 2 + cx - r.w / 2, b = stock.map.b + stock.map.h / 2 + cy - r.h / 2, w = r.w, h = r.h }
        end
        table.insert(stock.pieces, { obj = obj, group = "coords", rect = r, points = GetPoints(obj), alpha = obj:GetAlpha() })
        stock.coords = r
        stock.coordHow = how .. " (found later)"
        Hook(obj)
        ns.Apply()
        return
      end
    end
    LookForCoordsLater()
  end)
end

---------------------------------------------------------------------------
-- Own coordinates (used when Forever's are missing, or by choice)
---------------------------------------------------------------------------
local function UpdateOwnCoords()
  if not ownCoords or not ownCoords:IsShown() then return end
  local text = "--, --"
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if mapID then
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if pos then
      local x, y = pos:GetXY()
      if x and y and (x > 0 or y > 0) then text = string.format("%.1f, %.1f", x * 100, y * 100) end
    end
  end
  ownCoords:SetText(text)
end

---------------------------------------------------------------------------
-- Apply
---------------------------------------------------------------------------
local function ZoomButtons()
  local list = {}
  for _, n in ipairs(ZOOM_NAMES) do
    local b = Resolve(n)
    if b then list[b] = true end
  end
  return list
end

local function OnWheel(_, delta)
  local z, max = Minimap:GetZoom(), Minimap:GetZoomLevels()
  if delta > 0 and z < max - 1 then Minimap:SetZoom(z + 1)
  elseif delta < 0 and z > 0 then Minimap:SetZoom(z - 1) end
end

local function MapSize()
  local s = ns.db.size or (stock and math.floor(stock.map.w + 0.5)) or 200
  return math.max(80, s)
end
ns.MapSize = MapSize

function ns.StockSize() return stock and math.floor(stock.map.w + 0.5) or 200 end
function ns.HasForeverCoords() return stock and stock.coords ~= nil end
function ns.IsSquare() return ns.db.shape == "square" end

local function ApplyInner()
  local db = ns.db
  local size = MapSize()
  local ratio = size / stock.map.w
  local map, bar, coords = holders.map, holders.bar, holders.coords

  -- map holder
  map:SetSize(size, size)
  map:SetFrameStrata(stock.mapStrata or "LOW")
  Place(map, db.pos.map or PosFromRect(stock.map))
  map:SetShown(not MinimapCluster or MinimapCluster:IsShown())

  local mm = Minimap
  if mm:GetParent() ~= map then mm:SetParent(map) end
  mm:ClearAllPoints()
  mm:SetPoint("CENTER", map, "CENTER", 0, 0)
  local ms = mm:GetScale()
  mm:SetSize(size / ms, size / ms)
  mm:SetAlpha(db.alpha)
  if mm.SetClampedToScreen then mm:SetClampedToScreen(false) end

  -- shape
  local square = db.shape == "square"
  mm:SetMaskTexture(square and "Interface\\Buttons\\WHITE8X8" or "Interface\\CharacterFrame\\TempPortraitAlphaMask")
  for _, fn in ipairs({ "SetArchBlobRingScalar", "SetQuestBlobRingScalar", "SetTaskBlobRingScalar" }) do
    if mm[fn] then pcall(mm[fn], mm, square and 0 or 1) end
  end

  -- pieces
  local barRect, coordRect = stock.bar, stock.coords
  for _, p in ipairs(stock.pieces) do
    local o, r = p.obj, p.rect
    if p.group == "map" then
      local cx = (r.l + r.w / 2) - (stock.map.l + stock.map.w / 2)
      local cy = (r.b + r.h / 2) - (stock.map.b + stock.map.h / 2)
      local w, h = r.w, r.h
      if p.ring then w, h = w * ratio, h * ratio end
      Anchor(o, map, "CENTER", cx * ratio - w / 2, cy * ratio + h / 2, w, h)
      if p.ring then o:SetAlpha(ns.ShowBlizzardRing() and (p.alpha or 1) or 0) end
    elseif p.group == "bar" then
      Anchor(o, bar, "TOPLEFT", r.l - barRect.l, (r.b + r.h) - (barRect.b + barRect.h), r.w, r.h)
    elseif p.group == "coords" then
      Anchor(o, coords, "TOPLEFT", r.l - coordRect.l, (r.b + r.h) - (coordRect.b + coordRect.h), r.w, r.h)
      o:SetAlpha(db.coordMode == "auto" and (p.alpha or 1) or 0)
    end
  end

  -- top bar
  if barRect then
    bar:SetSize(barRect.w, barRect.h)
    bar:Show()
    bar:ClearAllPoints()
    local mapTop = stock.map.b + stock.map.h
    local barAbove = (barRect.b + barRect.h / 2) >= (stock.map.b + stock.map.h / 2)
    local dx = (barRect.l + barRect.w / 2) - (stock.map.l + stock.map.w / 2)
    if db.barAttached then
      if db.barSide == "above" then
        local gap = barAbove and math.max(0, barRect.b - mapTop) or 2
        bar:SetPoint("BOTTOM", map, "TOP", 0, gap)
      elseif db.barSide == "below" then
        local gap = (not barAbove) and math.max(0, stock.map.b - (barRect.b + barRect.h)) or 2
        bar:SetPoint("TOP", map, "BOTTOM", 0, -gap)
      elseif barAbove then
        bar:SetPoint("CENTER", map, "TOP", dx * ratio, (barRect.b + barRect.h / 2) - mapTop)
      else
        bar:SetPoint("CENTER", map, "BOTTOM", dx * ratio, (barRect.b + barRect.h / 2) - stock.map.b)
      end
    else
      Place(bar, db.pos.bar or PosFromRect(barRect))
    end
  else
    bar:Hide()
  end

  -- coordinates
  local useOwn = db.coordMode == "own" or (db.coordMode == "auto" and not coordRect)
  local cw, ch
  if coordRect and not useOwn then cw, ch = coordRect.w, coordRect.h else cw, ch = 72, 14 end
  coords:SetSize(cw, ch)
  local coordFree = db.pos.coords or PosFromRect(coordRect or {
    l = stock.map.l + (stock.map.w - cw) / 2, b = stock.map.b - ch - 4, w = cw, h = ch })
  coords:ClearAllPoints()
  if db.coordAttached then
    if coordRect then
      local cx = (coordRect.l + coordRect.w / 2) - (stock.map.l + stock.map.w / 2)
      local cy = (coordRect.b + coordRect.h / 2) - (stock.map.b + stock.map.h / 2)
      coords:SetPoint("CENTER", map, "CENTER", cx * ratio, cy * ratio)
    else
      coords:SetPoint("BOTTOM", map, "BOTTOM", 0, 6)
    end
  else
    Place(coords, coordFree)
  end
  coords:SetShown(db.coordMode ~= "hidden")
  ownCoords:SetShown(useOwn and db.coordMode ~= "hidden")
  UpdateOwnCoords()

  -- screen clamp: off by default, which is the whole point
  for _, h in pairs(holders) do h:SetClampedToScreen(db.clamp and true or false) end

  -- zoom buttons
  for b in pairs(ZoomButtons()) do
    b:SetAlpha(db.hideZoom and 0 or 1)
    if b.EnableMouse then b:EnableMouse(not db.hideZoom) end
  end

  -- mouse-wheel zoom (only added when the client has none of its own)
  if not stock.wheelScript then
    if db.wheelZoom and not wheelSet then
      mm:EnableMouseWheel(true)
      mm:SetScript("OnMouseWheel", OnWheel)
      wheelSet = true
    elseif not db.wheelZoom and wheelSet then
      mm:SetScript("OnMouseWheel", nil)
      mm:EnableMouseWheel(false)
      wheelSet = false
    end
  end

  if ns.ApplySkin then ns.ApplySkin(map, size) end
  if ns.UpdateOverlays then ns.UpdateOverlays() end
end

function ns.Apply()
  if not ready or not ns.db.enabled then return end
  applying = true
  Safe(ApplyInner)
  applying = false
end

local lastShape
function ns.ApplyAll()
  ns.Apply()
  if ns.PlaceButton then ns.PlaceButton() end
  if lastShape ~= ns.db.shape then
    lastShape = ns.db.shape
    -- let LibDBIcon buttons find the new edge
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if lib and lib.GetButtonList and lib.Refresh then
      for _, name in ipairs(lib:GetButtonList()) do pcall(lib.Refresh, lib, name) end
    end
  end
end

-- Give everything back where Blizzard had it.
function ns.Restore()
  if not stock then return end
  applying = true
  Safe(function()
    for _, p in ipairs(stock.pieces) do
      p.obj:ClearAllPoints()
      for _, pt in ipairs(p.points) do p.obj:SetPoint(unpack(pt)) end
      p.obj:SetAlpha(p.alpha or 1)
    end
    local mm = Minimap
    mm:SetParent(stock.mapParent)
    mm:ClearAllPoints()
    for _, pt in ipairs(stock.mapPoints) do mm:SetPoint(unpack(pt)) end
    mm:SetSize(unpack(stock.mapSize))
    mm:SetAlpha(1)
    mm:SetMaskTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    for b in pairs(ZoomButtons()) do b:SetAlpha(1) if b.EnableMouse then b:EnableMouse(true) end end
    if wheelSet then mm:SetScript("OnMouseWheel", nil) mm:EnableMouseWheel(false) wheelSet = false end
    for _, h in pairs(holders) do h:Hide() end
  end)
  applying = false
end

---------------------------------------------------------------------------
-- Moving the pieces
---------------------------------------------------------------------------
local moveMode = false
local overlays = {}

local function DragTarget(key)
  local db = ns.db
  if key == "bar" and db.barAttached then return holders.map, "map" end
  if key == "coords" and db.coordAttached then return holders.map, "map" end
  return holders[key], key
end

local function SaveHolder(key, snap)
  local h = holders[key]
  local r = UIRect(h)
  if not r then return end
  ns.db.pos[key] = PosFromRect(r, snap)
end

local function Nudge(key, dx, dy)
  local h, k = DragTarget(key)
  local r = UIRect(h)
  if not r then return end
  r.l, r.b = r.l + dx, r.b + dy
  ns.db.pos[k] = PosFromRect(r, false)
  ns.Apply()
end

local LABELS = { map = "Minimap", bar = "Top bar", coords = "Coordinates" }

local function MakeOverlay(key)
  local o = CreateFrame("Frame", nil, holders[key])
  o:SetAllPoints(holders[key])
  o:SetFrameStrata("DIALOG")
  o:EnableMouse(true)
  o:RegisterForDrag("LeftButton")
  local bg = o:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0.8, 1, 0.30)
  o.bg = bg
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = o:CreateTexture(nil, "BORDER")
    t:SetColorTexture(0, 0.9, 1, 0.9)
    if side == "TOP" or side == "BOTTOM" then
      t:SetHeight(1) t:SetPoint(side .. "LEFT") t:SetPoint(side .. "RIGHT")
    else
      t:SetWidth(1) t:SetPoint("TOP" .. side) t:SetPoint("BOTTOM" .. side)
    end
  end
  local fs = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("CENTER")
  fs:SetText(LABELS[key])
  o.text = fs
  o:SetScript("OnDragStart", function()
    if InCombatLockdown() then return end
    local h = DragTarget(key)
    h:StartMoving()
    o.dragging = h
  end)
  o:SetScript("OnDragStop", function()
    local h = o.dragging
    if not h then return end
    o.dragging = nil
    h:StopMovingOrSizing()
    local _, k = DragTarget(key)
    SaveHolder(k, ns.db.snap)
    ns.Apply()
  end)
  o:SetScript("OnEnter", function(self)
    if not InCombatLockdown() then self:EnableKeyboard(true) end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(LABELS[key])
    local _, k = DragTarget(key)
    if k ~= key then GameTooltip:AddLine("Attached: dragging it moves the whole minimap.", 0.7, 0.7, 0.7, true) end
    GameTooltip:AddLine("Drag to move. Arrow keys: 1 px, Shift + arrows: 10 px.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  o:SetScript("OnLeave", function(self)
    if not InCombatLockdown() then self:EnableKeyboard(false) end
    GameTooltip:Hide()
  end)
  o:SetScript("OnKeyDown", function(self, k)
    local step = IsShiftKeyDown() and 10 or 1
    local d = ({ UP = { 0, step }, DOWN = { 0, -step }, LEFT = { -step, 0 }, RIGHT = { step, 0 } })[k]
    if not InCombatLockdown() then self:SetPropagateKeyboardInput(not d) end
    if d then Nudge(key, d[1], d[2]) end
  end)
  o:Hide()
  overlays[key] = o
  return o
end

function ns.UpdateOverlays()
  for key, o in pairs(overlays) do
    local show = moveMode and holders[key]:IsShown()
    o:SetShown(show and true or false)
    if show then
      local _, k = DragTarget(key)
      o.bg:SetColorTexture(0, 0.8, 1, k == key and 0.30 or 0.15)
      o.text:SetText(LABELS[key] .. (k ~= key and " (attached)" or ""))
    end
  end
end

function ns.SetMoveMode(on)
  if on and InCombatLockdown() then Print("can't move pieces in combat.") return end
  moveMode = on and true or false
  if not overlays.map then for key in pairs(LABELS) do MakeOverlay(key) end end
  ns.UpdateOverlays()
  if ns.OnMoveModeChanged then ns.OnMoveModeChanged(moveMode) end
end
function ns.IsMoveMode() return moveMode end

function ns.ResetPositions()
  ns.db.pos = {}
  ns.Apply()
end

-- Detaching keeps the piece where it is right now.
function ns.SetAttached(which, on)
  local key = which == "bar" and "barAttached" or "coordAttached"
  if not on then SaveHolder(which, false) end
  ns.db[key] = on and true or false
  ns.Apply()
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------
local button
function ns.PlaceButton()
  if not button then return end
  local db = ns.db
  button:SetShown(not db.button.hide)
  local a = math.rad(db.button.angle or 210)
  local x, y = math.cos(a), math.sin(a)
  local r = Minimap:GetWidth() / 2 + 5
  if db.shape == "square" then
    local d = r * 1.4142
    x = math.max(-r, math.min(x * d, r))
    y = math.max(-r, math.min(y * d, r))
  else
    x, y = x * r, y * r
  end
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateButton()
  button = CreateFrame("Button", "MariscosMinimapUnboundButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT")
  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetPoint("TOPLEFT", 7, -5)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17)
  icon:SetTexture(ns.ICON)
  icon:SetPoint("TOPLEFT", 7, -6)

  button:SetScript("OnClick", function(_, b)
    if b == "RightButton" then ns.SetMoveMode(not moveMode)
    else ns.ToggleConfig() end
  end)
  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local s = Minimap:GetEffectiveScale()
      local cx, cy = GetCursorPosition()
      ns.db.button.angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
      ns.PlaceButton()
    end)
  end)
  button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(ns.TITLE)
    GameTooltip:AddLine("Left-click: settings", 1, 1, 1)
    GameTooltip:AddLine("Right-click: move pieces " .. (moveMode and "(on)" or "(off)"), 1, 1, 1)
    GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

---------------------------------------------------------------------------
-- Report (/mmu probe)
---------------------------------------------------------------------------
local function RectText(r)
  if not r then return "no rect" end
  return string.format("x %.1f  y %.1f  %.1f x %.1f", r.l, r.b, r.w, r.h)
end

function ns.BuildReport()
  local L = {}
  local function add(s) L[#L + 1] = s end
  local v, build, _, iface = GetBuildInfo()
  add(ns.TITLE .. " " .. ns.VERSION_LABEL .. " report")
  add(string.format("Client %s build %s, interface %s", tostring(v), tostring(build), tostring(iface)))
  add(string.format("Screen (UIParent) %.1f x %.1f, UI scale %.3f", UIParent:GetWidth(), UIParent:GetHeight(), UIParent:GetEffectiveScale()))
  add("Enabled: " .. tostring(ns.db.enabled) .. "   ready: " .. tostring(ready))
  add("")
  add("== MinimapCluster ==")
  if MinimapCluster then
    add("rect " .. RectText(UIRect(MinimapCluster)) .. "  scale " .. string.format("%.3f", MinimapCluster:GetScale())
        .. "  shown " .. tostring(MinimapCluster:IsShown()) .. "  clamped " .. tostring(MinimapCluster:IsClampedToScreen()))
    for _, c in ipairs({ MinimapCluster:GetChildren() }) do
      add("  child " .. DebugName(c) .. " [" .. c:GetObjectType() .. "] " .. RectText(UIRect(c)) .. (c:IsShown() and "" or " (hidden)"))
    end
  else
    add("not found")
  end
  add("")
  add("== Minimap ==")
  add("parent " .. DebugName(Minimap:GetParent()) .. "  rect " .. RectText(UIRect(Minimap))
      .. "  scale " .. string.format("%.3f", Minimap:GetScale()) .. "  strata " .. Minimap:GetFrameStrata())
  if stock then
    add("stock rect " .. RectText(stock.map) .. "  stock parent " .. DebugName(stock.mapParent))
    add("own wheel zoom: " .. (stock.wheelScript and "client already has one" or (wheelSet and "added" or "off")))
  end
  add("GetMinimapShape: " .. (GetMinimapShape and tostring(GetMinimapShape()) or "missing")
      .. (ns.shapeOwner and "" or "  (defined by another addon, square may not reach LibDBIcon)"))
  local zb = {}
  for b in pairs(ZoomButtons()) do zb[#zb + 1] = DebugName(b) end
  add("zoom buttons: " .. (#zb > 0 and table.concat(zb, ", ") or "none found"))
  add("")
  add("== Pieces taken over ==")
  if stock then
    for _, p in ipairs(stock.pieces) do
      add(string.format("  [%s%s] %s [%s] stock %s  now %s", p.group, p.ring and ", ring" or "",
        DebugName(p.obj), p.obj:GetObjectType(), RectText(p.rect), RectText(UIRect(p.obj))))
    end
    add("bar rect " .. RectText(stock.bar))
    add("coordinates: " .. (stock.coordHow or "not found (own coordinates used in Auto)"))
    if #stock.others > 0 then add("left alone: " .. table.concat(stock.others, ", ")) end
  else
    add("no snapshot yet")
  end
  add("")
  add("== Holders ==")
  for k, h in pairs(holders) do
    add(string.format("  %s %s shown %s clamped %s", k, RectText(UIRect(h)), tostring(h:IsShown()), tostring(h:IsClampedToScreen())))
  end
  add("")
  add("== Settings ==")
  local db = ns.db
  add(string.format("shape %s, skin %s, thickness %d, size %d (stock %d), alpha %.2f", db.shape, db.skin, db.thickness,
      MapSize(), ns.StockSize(), db.alpha))
  add(string.format("bar attached %s (%s), coords attached %s (%s), clamp %s, snap %s, hide zoom %s, wheel %s",
      tostring(db.barAttached), db.barSide, tostring(db.coordAttached), db.coordMode, tostring(db.clamp),
      tostring(db.snap), tostring(db.hideZoom), tostring(db.wheelZoom)))
  for k, p in pairs(db.pos) do add(string.format("  pos %s: %s %.1f %.1f", k, p.point, p.x, p.y)) end
  add("")
  add("== Errors (latest first) ==")
  if #ns.errors == 0 then add("none") end
  for _, e in ipairs(ns.errors) do add(e) end
  return table.concat(L, "\n")
end

---------------------------------------------------------------------------
-- Start up
---------------------------------------------------------------------------
local function Init()
  if ready or not Minimap then return end
  stock = Snapshot()
  if not stock then
    Print("couldn't measure the minimap yet; trying again in 2 seconds.")
    C_Timer.After(2, Init)
    return
  end
  NewHolder("map")
  NewHolder("bar")
  NewHolder("coords")
  holders.map:SetFrameStrata(stock.mapStrata or "LOW")
  ownCoords = holders.coords:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ownCoords:SetPoint("CENTER")
  ownCoords:SetShadowOffset(1, -1)
  local elapsed = 0
  holders.coords:SetScript("OnUpdate", function(_, e)
    elapsed = elapsed + e
    if elapsed > 0.2 then elapsed = 0 UpdateOwnCoords() end
  end)
  if ns.CreateSkinLayers then ns.CreateSkinLayers(holders.map) end

  Hook(Minimap)
  for _, p in ipairs(stock.pieces) do Hook(p.obj) end
  if MinimapCluster then
    MinimapCluster:HookScript("OnShow", function() if ready and ns.db.enabled then holders.map:Show() end end)
    MinimapCluster:HookScript("OnHide", function() if ready and ns.db.enabled then holders.map:Hide() end end)
  end

  CreateButton()
  ready = true
  if ns.db.enabled then
    ns.ApplyAll()
  else
    for _, h in pairs(holders) do h:Hide() end
  end
  LookForCoordsLater()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("UI_SCALE_CHANGED")
ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
pcall(ev.RegisterEvent, ev, "EDIT_MODE_LAYOUTS_UPDATED")
ev:SetScript("OnEvent", function(_, event, arg1)
  Safe(function()
    if event == "ADDON_LOADED" and arg1 == ADDON then
      MariscosMinimapUnboundDB = MariscosMinimapUnboundDB or {}
      ns.db = MariscosMinimapUnboundDB
      FillDefaults(ns.db, ns.DEFAULTS)
      if not GetMinimapShape then
        ns.shapeOwner = true
        function GetMinimapShape()
          if ns.db and ns.db.enabled and ns.db.shape == "square" then return "SQUARE" end
          return "ROUND"
        end
      end
    elseif event == "PLAYER_ENTERING_WORLD" then
      if not ready then C_Timer.After(1.5, function() Safe(Init) end) else Queue() end
    elseif event == "PLAYER_REGEN_DISABLED" then
      if moveMode then ns.SetMoveMode(false) end
    else
      Queue()
    end
  end)
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local HELP = {
  "/mmu - settings",
  "/mmu move - show the cyan boxes to drag the pieces (again to lock)",
  "/mmu square | round - shape",
  "/mmu skin <stock|clean|line|framed|shadow|tooltip|dialog>",
  "/mmu size <80-400> - map size (/mmu size stock for the original)",
  "/mmu clamp - keep on screen on/off   /mmu snap - edge snapping on/off",
  "/mmu attach bar|coords - attach or detach",
  "/mmu coords auto|own|hidden",
  "/mmu zoom - hide/show zoom buttons   /mmu wheel - mouse-wheel zoom on/off",
  "/mmu reset - positions back to the stock spot   /mmu default - every setting back",
  "/mmu minimap - hide/show this addon's minimap button",
  "/mmu probe - report of what the addon found (copyable)",
  "/mmu off | on - give the minimap back to Blizzard / take it again",
  "/mmu status",
}

local function OnOff(v) return v and "|cff20ff20on|r" or "|cffff4040off|r" end

SLASH_MARISCOSMINIMAPUNBOUND1 = "/mmu"
SLASH_MARISCOSMINIMAPUNBOUND2 = "/minimapunbound"
SlashCmdList.MARISCOSMINIMAPUNBOUND = function(msg)
  Safe(function()
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    rest = (rest or ""):lower()
    local db = ns.db
    if cmd == "" or cmd == "config" or cmd == "options" then ns.ToggleConfig() return end
    if cmd == "help" then for _, l in ipairs(HELP) do Print(l) end return end
    if cmd == "probe" or cmd == "debug" then ns.ShowReport(ns.BuildReport()) return end
    if not ready then Print("still starting up, try again in a moment.") return end
    if cmd == "move" or cmd == "unlock" then ns.SetMoveMode(not moveMode)
      Print("move pieces " .. OnOff(moveMode))
    elseif cmd == "lock" then ns.SetMoveMode(false)
    elseif cmd == "square" or cmd == "round" then db.shape = cmd ns.ApplyAll()
    elseif cmd == "skin" then
      if ns.SKIN_BY_KEY and ns.SKIN_BY_KEY[rest] then db.skin = rest ns.ApplyAll() Print("skin " .. ns.SKIN_BY_KEY[rest].name)
      else Print("skins: " .. table.concat(ns.SKIN_KEYS or {}, ", ")) end
    elseif cmd == "size" then
      if rest == "stock" then db.size = nil
      else local n = tonumber(rest) if not n then Print("/mmu size <80-400>") return end
        db.size = math.max(80, math.min(400, math.floor(n))) end
      ns.ApplyAll()
    elseif cmd == "clamp" then db.clamp = not db.clamp ns.Apply() Print("keep on screen " .. OnOff(db.clamp))
    elseif cmd == "snap" then db.snap = not db.snap Print("snap to screen edges " .. OnOff(db.snap))
    elseif cmd == "attach" then
      if rest == "bar" then ns.SetAttached("bar", not db.barAttached) Print("bar attached " .. OnOff(db.barAttached))
      elseif rest == "coords" then ns.SetAttached("coords", not db.coordAttached) Print("coordinates attached " .. OnOff(db.coordAttached))
      else Print("/mmu attach bar|coords") end
    elseif cmd == "coords" then
      if rest == "auto" or rest == "own" or rest == "hidden" then db.coordMode = rest ns.Apply() else Print("/mmu coords auto|own|hidden") end
    elseif cmd == "zoom" then db.hideZoom = not db.hideZoom ns.Apply() Print("zoom buttons hidden " .. OnOff(db.hideZoom))
    elseif cmd == "wheel" then db.wheelZoom = not db.wheelZoom ns.Apply() Print("mouse-wheel zoom " .. OnOff(db.wheelZoom))
    elseif cmd == "reset" then ns.ResetPositions() Print("positions reset.")
    elseif cmd == "default" then ns.LoadDefaults() ns.ApplyAll() Print("settings back to default (positions kept).")
    elseif cmd == "minimap" then db.button.hide = not db.button.hide ns.PlaceButton()
    elseif cmd == "off" then
      db.enabled = false ns.SetMoveMode(false) ns.Restore()
      Print("the minimap is back with Blizzard. A /reload makes sure everything is exactly stock.")
    elseif cmd == "on" then db.enabled = true ns.ApplyAll() Print("on.")
    elseif cmd == "status" then
      Print(string.format("%s | %s, skin %s, size %d | bar %s, coords %s (%s) | keep on screen %s | snap %s",
        OnOff(db.enabled), db.shape, db.skin, MapSize(), db.barAttached and "attached" or "free",
        db.coordAttached and "attached" or "free", db.coordMode, OnOff(db.clamp), OnOff(db.snap)))
    else
      for _, l in ipairs(HELP) do Print(l) end
    end
  end)
end

function ns.LoadDefaults()
  local db = ns.db
  local keep = { pos = db.pos, button = db.button, configPos = db.configPos, enabled = db.enabled }
  for k in pairs(db) do db[k] = nil end
  FillDefaults(db, ns.DEFAULTS)
  for k, v in pairs(keep) do db[k] = v end
end
