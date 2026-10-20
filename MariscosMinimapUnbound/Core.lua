-- Marisco's Minimap Unbound
-- Takes the stock minimap (map, top bar, coordinates) out of Edit Mode's clamped cluster and
-- puts each part in its own free holder. Nothing in Edit Mode is moved or saved by this addon.

local ADDON, ns = ...

ns.VERSION = "0.3.1"
ns.VERSION_LABEL = "v0.3.1 Beta"
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
  barSide = "original",       -- original | above | below (parts still on the bar)
  coordMode = "auto",         -- auto (Forever's own) | own | hidden
  parts = {},                 -- parts moved on their own: key -> { point, x, y }
  partOpts = {},              -- per part: { scale, hidden, above (nil = follow the global setting) }
  partNames = {},             -- names given to parts in the settings
  above = false,              -- set parts above the minimap
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
local partList = {}     -- every part with its own holder (not the map, not the coordinates)
ns.partList = partList
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

---------------------------------------------------------------------------
-- Per-part options: scale, shown, layer (above the map or stock)
---------------------------------------------------------------------------
local EMPTY = {}

function ns.PartOpts(key, create)
  local t = ns.db.partOpts[key]
  if not t and create then
    t = {}
    ns.db.partOpts[key] = t
  end
  return t or EMPTY
end

-- a part's own choice wins; otherwise the global "Set parts above the minimap"
local function IsAbove(key)
  local o = ns.db.partOpts[key]
  if o and o.above ~= nil then return o.above end
  return ns.db.above and true or false
end
ns.IsAbove = IsAbove

-- what the game had before we touched it, to put it back exactly
local function CaptureExtras(p)
  local o = p.obj
  p.isRegion = not o.GetFrameStrata
  p.parent = o:GetParent()
  p.scale = o.GetScale and o:GetScale() or 1
  p.strata = (not p.isRegion) and o:GetFrameStrata() or nil
  p.mouse = (o.IsMouseEnabled and o:IsMouseEnabled()) and true or false
end

-- A part inside another part (the zone name inside the top bar) already gets that part's
-- scale from its parent, so it is divided out again.
local function AncestorScale(obj, self)
  local f = 1
  for _, part in ipairs(partList) do
    if part ~= self and IsDescendant(obj, part.piece.obj) then
      f = f * ((ns.db.partOpts[part.key] or EMPTY).scale or 1)
    end
  end
  return f
end

-- which parts sit inside others: parents first, and hiding a parent only hides its own
-- textures so the parts inside it stay visible
local function ComputeTree()
  for _, part in ipairs(partList) do part.depth, part.hasChildParts = 0, false end
  for _, part in ipairs(partList) do
    for _, other in ipairs(partList) do
      if other ~= part and IsDescendant(part.piece.obj, other.piece.obj) then
        part.depth = part.depth + 1
        other.hasChildParts = true
      end
    end
  end
  if stock then
    for _, p in ipairs(stock.pieces) do
      if p.group == "coords" then
        for _, other in ipairs(partList) do
          if IsDescendant(p.obj, other.piece.obj) then other.hasChildParts = true end
        end
      end
    end
  end
  table.sort(partList, function(a, b)
    if a.depth ~= b.depth then return a.depth < b.depth end
    return a.key < b.key
  end)
end

local function StylePiece(p, holder, scale, above, shown, ownOnly)
  local o = p.obj
  if p.isRegion then
    -- a bare text or texture can't change layer itself: it moves into its holder instead
    local target = above and holder or p.parent
    if target and o:GetParent() ~= target then o:SetParent(target) end
  elseif o.SetFrameStrata and p.strata then
    o:SetFrameStrata(above and "MEDIUM" or p.strata)
  end
  if o.SetScale then pcall(o.SetScale, o, (p.scale or 1) * scale) end
  if ownOnly then
    p.regionAlpha = p.regionAlpha or {}
    for _, r in ipairs({ o:GetRegions() }) do
      local isPiece = false
      for _, q in ipairs(stock.pieces) do if q.obj == r then isPiece = true break end end
      if not isPiece then
        if p.regionAlpha[r] == nil then p.regionAlpha[r] = r:GetAlpha() end
        r:SetAlpha(shown and p.regionAlpha[r] or 0)
      end
    end
    o:SetAlpha(p.alpha or 1)
  else
    o:SetAlpha(shown and (p.alpha or 1) or 0)
  end
  if not p.isRegion and p.mouse and o.EnableMouse then o:EnableMouse(shown and true or false) end
end

local function UnstylePiece(p)
  local o = p.obj
  if p.isRegion and p.parent and o:GetParent() ~= p.parent then o:SetParent(p.parent) end
  if not p.isRegion and p.strata and o.SetFrameStrata then o:SetFrameStrata(p.strata) end
  if o.SetScale and p.scale then pcall(o.SetScale, o, p.scale) end
  if p.regionAlpha then for r, a in pairs(p.regionAlpha) do r:SetAlpha(a) end end
  if not p.isRegion and p.mouse and o.EnableMouse then o:EnableMouse(true) end
  o:SetAlpha(p.alpha or 1)
end

function ns.PartChoices()
  local list = { { key = "coords", label = (ns.db.partNames.coords ~= nil and ns.db.partNames.coords ~= "")
    and ns.db.partNames.coords or "Coordinates" } }
  for _, part in ipairs(partList) do list[#list + 1] = { key = part.key, label = ns.PartLabel(part) } end
  return list
end

local FRIENDLY = {
  BorderTop = "Top bar", MinimapBorderTop = "Top bar",
  ZoneTextButton = "Zone name", MinimapZoneTextButton = "Zone name",
  Tracking = "Tracking (search)", MiniMapTracking = "Tracking (search)", MiniMapTrackingFrame = "Tracking (search)",
  MiniMapTrackingButton = "Tracking (search)",
  TimeManagerClockButton = "Clock", GameTimeFrame = "Calendar",
  IndicatorFrame = "Mail and indicators", MiniMapMailFrame = "Mail",
  InstanceDifficulty = "Instance difficulty", MiniMapInstanceDifficulty = "Instance difficulty",
  AddonCompartmentFrame = "Addon compartment", ExpansionLandingPageMinimapButton = "Landing page button",
}
-- A frame without a name of its own gets an id from where it sits: its parent's key for it
-- (MinimapCluster.BorderTop), or its place among its parent's children (MinimapCluster/Frame3).
-- Unlike the frame's memory address, that is the same at every login, so its settings stick.
local function StableKey(obj, depth)
  depth = depth or 0
  local n = obj.GetName and obj:GetName()
  if n and n ~= "" then return n end
  local parent = obj.GetParent and obj:GetParent()
  if not parent or depth > 6 then return DebugName(obj) end
  local pkey = StableKey(parent, depth + 1)
  for k, v in pairs(parent) do
    if v == obj and type(k) == "string" then return pkey .. "." .. k end
  end
  local kind = obj:GetObjectType()
  local list = (kind == "Texture" or kind == "FontString") and { parent:GetRegions() } or { parent:GetChildren() }
  local i = 0
  for _, c in ipairs(list) do
    if c.GetObjectType and c:GetObjectType() == kind then i = i + 1 end
    if c == obj then return pkey .. "/" .. kind .. i end
  end
  return DebugName(obj)
end

-- the sun/moon circle has no name: recognise it by its artwork
local function LooksLikeDayNight(obj)
  if not obj.GetRegions then return false end
  for _, r in ipairs({ obj:GetRegions() }) do
    if r.GetObjectType and r:GetObjectType() == "Texture" then
      local a = r.GetAtlas and r:GetAtlas()
      local t = r.GetTexture and r:GetTexture()
      local txt = (tostring(a or "") .. " " .. tostring(t or "")):lower()
      if txt:find("daynight") or txt:find("day%-night") or txt:find("sun") or txt:find("moon")
         or txt:find("timeofday") or txt:find("gametime") then
        return true
      end
    end
  end
  return false
end

function ns.PartLabel(part)
  local custom = ns.db.partNames and ns.db.partNames[part.key]
  if custom and custom ~= "" then return custom end
  return part.label
end

local function Friendly(key)
  local last = key:gsub("#%d+$", ""):match("([^%.]+)$") or key
  return FRIENDLY[last] or last
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
    CaptureExtras(st.pieces[#st.pieces])
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
        CaptureExtras(stock.pieces[#stock.pieces])
        ComputeTree()
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
  local map = holders.map

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

  -- the bar line: an invisible frame the parts still on the bar line up on
  local barRect, coordRect = stock.bar, stock.coords
  local bar, coords = holders.bar, holders.coords
  if barRect then
    bar:SetSize(barRect.w, barRect.h)
    bar:ClearAllPoints()
    local mapTop = stock.map.b + stock.map.h
    local barAbove = (barRect.b + barRect.h / 2) >= (stock.map.b + stock.map.h / 2)
    local dx = (barRect.l + barRect.w / 2) - (stock.map.l + stock.map.w / 2)
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
  end

  -- the round border follows the map and grows with it
  for _, p in ipairs(stock.pieces) do
    if p.ring then
      local r = p.rect
      local cx = (r.l + r.w / 2) - (stock.map.l + stock.map.w / 2)
      local cy = (r.b + r.h / 2) - (stock.map.b + stock.map.h / 2)
      local w, h = r.w * ratio, r.h * ratio
      Anchor(p.obj, map, "CENTER", cx * ratio - w / 2, cy * ratio + h / 2, w, h)
      p.obj:SetAlpha(ns.ShowBlizzardRing() and (p.alpha or 1) or 0)
    end
  end

  -- every other part sits in its own holder: on its stock spot, or wherever it was moved
  for _, part in ipairs(partList) do
    local o = db.partOpts[part.key] or EMPTY
    local s = o.scale or 1
    local h, r = part.holder, part.rect
    local w, hh = r.w * s, r.h * s
    local above = IsAbove(part.key)
    h:SetSize(w, hh)
    h:SetFrameStrata(above and "MEDIUM" or (stock.mapStrata or "LOW"))
    h:ClearAllPoints()
    local free = db.parts[part.key]
    if free then
      Place(h, free)
    elseif part.group == "bar" and barRect then
      h:SetPoint("CENTER", bar, "TOPLEFT", r.l + r.w / 2 - barRect.l, (r.b + r.h / 2) - (barRect.b + barRect.h))
    else
      local cx = (r.l + r.w / 2) - (stock.map.l + stock.map.w / 2)
      local cy = (r.b + r.h / 2) - (stock.map.b + stock.map.h / 2)
      h:SetPoint("CENTER", map, "CENTER", cx * ratio, cy * ratio)
    end
    StylePiece(part.piece, h, s / AncestorScale(part.piece.obj, part), above, not o.hidden, part.hasChildParts)
    Anchor(part.piece.obj, h, "TOPLEFT", 0, 0, w, hh)
  end

  -- coordinates: Forever's, this addon's, or hidden; one part either way
  local co = db.partOpts.coords or EMPTY
  local cs = co.scale or 1
  local cAbove = IsAbove("coords")
  local cVisible = db.coordMode ~= "hidden" and not co.hidden
  local useOwn = db.coordMode == "own" or (db.coordMode == "auto" and not coordRect)
  local cw, ch
  if coordRect and not useOwn then cw, ch = coordRect.w, coordRect.h else cw, ch = 72, 14 end
  coords:SetSize(cw * cs, ch * cs)
  coords:SetFrameStrata(cAbove and "MEDIUM" or (stock.mapStrata or "LOW"))
  coords:ClearAllPoints()
  if db.parts.coords then
    Place(coords, db.parts.coords)
  elseif coordRect then
    local cx = (coordRect.l + coordRect.w / 2) - (stock.map.l + stock.map.w / 2)
    local cy = (coordRect.b + coordRect.h / 2) - (stock.map.b + stock.map.h / 2)
    coords:SetPoint("CENTER", map, "CENTER", cx * ratio, cy * ratio)
  else
    coords:SetPoint("BOTTOM", map, "BOTTOM", 0, 6)
  end
  for _, p in ipairs(stock.pieces) do
    if p.group == "coords" then
      local r = p.rect
      StylePiece(p, coords, cs / AncestorScale(p.obj), cAbove, cVisible and not useOwn, false)
      if useOwn then
        Anchor(p.obj, coords, "CENTER", -r.w * cs / 2, r.h * cs / 2, r.w * cs, r.h * cs)
      else
        Anchor(p.obj, coords, "TOPLEFT", (r.l - coordRect.l) * cs, ((r.b + r.h) - (coordRect.b + coordRect.h)) * cs,
          r.w * cs, r.h * cs)
      end
    end
  end
  coords:Show() -- always there, so its box can be found while editing
  if ownCoords.SetTextScale then pcall(ownCoords.SetTextScale, ownCoords, cs)
  elseif ownCoords.SetScale then pcall(ownCoords.SetScale, ownCoords, cs) end
  ownCoords:SetShown(useOwn and cVisible)
  UpdateOwnCoords()

  -- screen clamp: off by default, which is the whole point
  local clamp = db.clamp and true or false
  map:SetClampedToScreen(clamp)
  coords:SetClampedToScreen(clamp)
  for _, part in ipairs(partList) do part.holder:SetClampedToScreen(clamp) end

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
      if not p.ring then UnstylePiece(p) end
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
-- Editing the layout
-- Every part gets a highlight box. Drag: the whole minimap. Shift+drag: only that part.
-- Right-click a box: put that part back on its stock spot.
---------------------------------------------------------------------------
local moveMode = false
local overlays = {}
local editBar

local function AllParts()
  local list = {
    { key = "map", holder = holders.map, label = "Minimap" },
    { key = "coords", holder = holders.coords, label = "Coordinates" },
  }
  for _, part in ipairs(partList) do list[#list + 1] = part end
  return list
end

local function IsFree(key)
  if key == "map" then return ns.db.pos.map ~= nil end
  return ns.db.parts[key] ~= nil
end

-- Which holder a drag or nudge moves, and the key its position is saved under.
-- A part is turned into a free part on the spot, so it starts from where it is now.
local function Target(part, single)
  if part.key == "map" or not single then return holders.map, "map" end
  local db = ns.db
  if not db.parts[part.key] then
    local r = UIRect(part.holder)
    if not r then return holders.map, "map" end
    db.parts[part.key] = PosFromRect(r, false)
    Place(part.holder, db.parts[part.key])
  end
  return part.holder, part.key
end

local function SavePos(key, frame, snap)
  local r = UIRect(frame)
  if not r then return end
  if key == "map" then ns.db.pos.map = PosFromRect(r, snap) else ns.db.parts[key] = PosFromRect(r, snap) end
end

local function Nudge(part, single, dx, dy)
  local h, key = Target(part, single)
  local r = UIRect(h)
  if not r then return end
  r.l, r.b = r.l + dx, r.b + dy
  if key == "map" then ns.db.pos.map = PosFromRect(r, false) else ns.db.parts[key] = PosFromRect(r, false) end
  ns.Apply()
end

local function PutBack(part)
  if part.key == "map" then ns.db.pos.map = nil else ns.db.parts[part.key] = nil end
  ns.Apply()
end

local function ShowPartTooltip(o)
  local part = o.part
  GameTooltip:SetOwner(o, "ANCHOR_TOP")
  GameTooltip:AddLine(ns.PartLabel(part))
  if part.key == "map" then
    GameTooltip:AddLine(IsFree("map") and "Moved" or "On its stock spot", 0.7, 0.7, 0.7)
  else
    GameTooltip:AddLine(IsFree(part.key) and "Moved on its own" or "Moves with the minimap", 0.7, 0.7, 0.7)
    local po = ns.db.partOpts[part.key]
    if po and po.hidden then GameTooltip:AddLine("Turned off in the settings", 1, 0.4, 0.4) end
    if po and po.scale and po.scale ~= 1 then GameTooltip:AddLine(string.format("Scale %d%%", po.scale * 100 + 0.5), 0.7, 0.7, 0.7) end
    GameTooltip:AddLine(IsAbove(part.key) and "Above the minimap" or "Stock layer", 0.7, 0.7, 0.7)
    if part.piece and not part.piece.obj:IsShown() then
      GameTooltip:AddLine("Hidden right now (shows when the game needs it)", 0.7, 0.7, 0.7, true)
    end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Drag: move the whole minimap", 1, 1, 1)
  if part.key ~= "map" then GameTooltip:AddLine("Shift + drag: move only this part", 1, 1, 1) end
  GameTooltip:AddLine("Arrow keys: 1 px (Ctrl: 10 px, Shift: only this part)", 1, 1, 1, true)
  GameTooltip:AddLine(part.key == "map" and "Right-click: back to the stock spot" or "Right-click: put it back", 1, 1, 1)
  GameTooltip:AddLine(part.key == "map" and "Click: settings" or "Click: this part's settings (scale, show, layer)", 1, 1, 1)
  GameTooltip:Show()
end

local function MakeOverlay(part)
  local o = CreateFrame("Frame", nil, part.holder)
  o:SetAllPoints(part.holder)
  o:SetFrameStrata("DIALOG")
  o:EnableMouse(true)
  o:RegisterForDrag("LeftButton")
  o.part = part
  local bg = o:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  o.bg = bg
  o.edges = {}
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = o:CreateTexture(nil, "BORDER")
    if side == "TOP" or side == "BOTTOM" then
      t:SetHeight(1) t:SetPoint(side .. "LEFT") t:SetPoint(side .. "RIGHT")
    else
      t:SetWidth(1) t:SetPoint("TOP" .. side) t:SetPoint("BOTTOM" .. side)
    end
    o.edges[#o.edges + 1] = t
  end
  local fs = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("CENTER")
  fs:SetText(ns.PartLabel(part))
  o.text = fs

  o:SetScript("OnDragStart", function(self)
    if InCombatLockdown() then return end
    local h, key = Target(part, IsShiftKeyDown())
    h:StartMoving()
    self.drag = { h = h, key = key }
    self.dragged = true
    GameTooltip:Hide()
  end)
  o:SetScript("OnDragStop", function(self)
    local d = self.drag
    if not d then return end
    self.drag = nil
    d.h:StopMovingOrSizing()
    SavePos(d.key, d.h, ns.db.snap)
    ns.Apply()
  end)
  o:SetScript("OnMouseUp", function(self, btn)
    if btn == "RightButton" then
      PutBack(part)
      if self:IsMouseOver() then ShowPartTooltip(self) end
    elseif btn == "LeftButton" then
      if self.dragged then self.dragged = false return end
      if ns.SelectPart then ns.Safe(ns.SelectPart, part.key) end
    end
  end)
  o:SetScript("OnEnter", function(self)
    if not InCombatLockdown() then self:EnableKeyboard(true) end
    self.hover = true
    ns.UpdateOverlays()
    ShowPartTooltip(self)
  end)
  o:SetScript("OnLeave", function(self)
    if not InCombatLockdown() then self:EnableKeyboard(false) end
    self.hover = false
    ns.UpdateOverlays()
    GameTooltip:Hide()
  end)
  o:SetScript("OnKeyDown", function(self, k)
    local step = IsControlKeyDown() and 10 or 1
    local d = ({ UP = { 0, step }, DOWN = { 0, -step }, LEFT = { -step, 0 }, RIGHT = { step, 0 } })[k]
    if not InCombatLockdown() then self:SetPropagateKeyboardInput(not d) end
    if d then ns.Safe(Nudge, part, IsShiftKeyDown(), d[1], d[2]) end
  end)
  o:Hide()
  overlays[part.key] = o
  return o
end

-- cyan: moves with the minimap; gold: moved on its own; brighter while hovered
function ns.UpdateOverlays()
  local list = AllParts()
  -- smaller parts sit on top, so a button on the bar can be grabbed instead of the bar
  table.sort(list, function(a, b)
    local ra, rb = UIRect(a.holder), UIRect(b.holder)
    return (ra and ra.w * ra.h or 0) > (rb and rb.w * rb.h or 0)
  end)
  for rank, part in ipairs(list) do
    local o = overlays[part.key] or MakeOverlay(part)
    local show = moveMode and part.holder:IsShown()
    o:SetShown(show and true or false)
    if show then
      o:SetFrameLevel(20 + rank * 3)
      local free = IsFree(part.key) and part.key ~= "map"
      local r, g, b = 0, 0.8, 1
      if free then r, g, b = 1, 0.75, 0.1 end
      local selected = ns.IsConfigShown and ns.IsConfigShown() and ns.selectedPart == part.key
      o.bg:SetColorTexture(r, g, b, (o.hover or selected) and 0.45 or 0.22)
      for _, t in ipairs(o.edges) do t:SetColorTexture(r, g, b, 0.95) end
      o.text:SetText(ns.PartLabel(part))
      local rect = UIRect(part.holder)
      o.text:SetShown(rect and rect.w >= 50 and rect.h >= 12 or false)
    end
  end
end

local function MakeEditBar()
  local ok, b = pcall(CreateFrame, "Frame", "MariscosMinimapUnboundEditBar", UIParent, "BackdropTemplate")
  if not ok or not b then b = CreateFrame("Frame", "MariscosMinimapUnboundEditBar", UIParent) end
  b:SetSize(560, 64)
  b:SetPoint("TOP", UIParent, "TOP", 0, -110)
  b:SetFrameStrata("FULLSCREEN_DIALOG")
  b:SetClampedToScreen(true)
  b:EnableMouse(true)
  b:SetMovable(true)
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", b.StartMoving)
  b:SetScript("OnDragStop", b.StopMovingOrSizing)
  if b.SetBackdrop then
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    b:SetBackdropColor(0, 0, 0, 0.85)
    b:SetBackdropBorderColor(0, 0.8, 1, 1)
  end
  local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  t:SetPoint("TOPLEFT", 14, -10)
  t:SetText("Minimap Unbound: editing the layout")
  local h = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  h:SetPoint("TOPLEFT", 14, -30)
  h:SetPoint("RIGHT", -170, 0)
  h:SetJustifyH("LEFT")
  h:SetText("Drag: whole minimap   |cffffd200Shift + drag|r: one part\nRight-click: put a part back   Arrows: 1 px (Ctrl 10)")
  local function Btn(text, w, onClick)
    local x = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
    x:SetSize(w, 22)
    x:SetText(text)
    x:SetScript("OnClick", function() ns.Safe(onClick) end)
    return x
  end
  local done = Btn("Done", 70, function() ns.SetMoveMode(false) end)
  done:SetPoint("RIGHT", -12, 0)
  local back = Btn("Put all back", 90, function() ns.AttachAllParts() end)
  back:SetPoint("RIGHT", done, "LEFT", -4, 0)
  b:Hide()
  return b
end

function ns.SetMoveMode(on)
  if on and InCombatLockdown() then Print("can't edit the layout in combat.") return end
  if not ready then return end
  moveMode = on and true or false
  editBar = editBar or MakeEditBar()
  editBar:SetShown(moveMode)
  ns.UpdateOverlays()
  if ns.OnMoveModeChanged then ns.OnMoveModeChanged(moveMode) end
end
function ns.IsMoveMode() return moveMode end

-- every part back on the map (the map itself stays where it is)
function ns.AttachAllParts()
  ns.db.parts = {}
  ns.Apply()
  if ns.RefreshConfig then ns.RefreshConfig() end
end

-- everything back to the stock spot
function ns.ResetPositions()
  ns.db.pos = {}
  ns.db.parts = {}
  ns.Apply()
end

function ns.CountFreeParts()
  local n = 0
  for _ in pairs(ns.db.parts) do n = n + 1 end
  return n
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
    GameTooltip:AddLine("Right-click: edit the layout " .. (moveMode and "(on)" or "(off)"), 1, 1, 1)
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
    add("")
    add("== Parts (each movable on its own) ==")
    for _, part in ipairs(partList) do
      add(string.format("  %s = %s (%s), %s", ns.PartLabel(part), part.key, DebugName(part.piece.obj),
        ns.db.parts[part.key] and "moved" or "on its stock spot"))
    end
    add("  Coordinates = coords, " .. (ns.db.parts.coords and "moved" or "on its stock spot"))
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
  add(string.format("bar side %s, coordinates %s, clamp %s, snap %s, hide zoom %s, wheel %s",
      db.barSide, db.coordMode, tostring(db.clamp),
      tostring(db.snap), tostring(db.hideZoom), tostring(db.wheelZoom)))
  for k, p in pairs(db.pos) do add(string.format("  pos %s: %s %.1f %.1f", k, p.point, p.x, p.y)) end
  for k, p in pairs(db.parts) do add(string.format("  part %s: %s %.1f %.1f", k, p.point, p.x, p.y)) end
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

  -- one holder per part (everything but the map, its round border and the coordinates)
  local used, unnamed = {}, 0
  for _, p in ipairs(stock.pieces) do
    if not p.ring and p.group ~= "coords" then
      local key = StableKey(p.obj)
      if used[key] then key = key .. "#" .. (#partList + 1) end
      used[key] = true
      local h = CreateFrame("Frame", nil, UIParent)
      h:SetMovable(true)
      h:SetClampedToScreen(false)
      h:SetSize(p.rect.w, p.rect.h)
      local label = Friendly(key)
      if LooksLikeDayNight(p.obj) and p.obj ~= GameTimeFrame then
        label = "Day/Night Cycle"
      elseif label:find("/") or label:match("^%x+$") then
        unnamed = unnamed + 1
        label = unnamed > 1 and ("Unnamed part " .. unnamed) or "Unnamed part"
      end
      partList[#partList + 1] = { key = key, holder = h, label = label, group = p.group, piece = p, rect = p.rect }
    end
  end

  ComputeTree()

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
      -- v0.1 -> v0.2: the bar/coordinates holders became parts
      local db = ns.db
      if db.coordAttached == false and db.pos.coords then db.parts.coords = db.pos.coords end
      db.pos.bar, db.pos.coords, db.barAttached, db.coordAttached = nil, nil, nil, nil
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
  "/mmu edit - edit the layout: drag = whole minimap, Shift+drag = one part (again to finish)",
  "/mmu square | round - shape",
  "/mmu skin <stock|clean|line|framed|shadow|tooltip|dialog>",
  "/mmu size <80-400> - map size (/mmu size stock for the original)",
  "/mmu clamp - keep on screen on/off   /mmu snap - edge snapping on/off",
  "/mmu back - every part back on the map",
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
    if cmd == "edit" or cmd == "move" or cmd == "unlock" then ns.SetMoveMode(not moveMode)
      Print("editing the layout " .. OnOff(moveMode))
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
    elseif cmd == "back" then ns.AttachAllParts() Print("every part is back on the map.")
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
      Print(string.format("%s | %s, skin %s, size %d | %d part(s) moved on their own | coordinates %s | keep on screen %s | snap %s",
        OnOff(db.enabled), db.shape, db.skin, MapSize(), ns.CountFreeParts(), db.coordMode, OnOff(db.clamp), OnOff(db.snap)))
    else
      for _, l in ipairs(HELP) do Print(l) end
    end
  end)
end

function ns.LoadDefaults()
  local db = ns.db
  local keep = { pos = db.pos, parts = db.parts, partNames = db.partNames, button = db.button, configPos = db.configPos,
                 enabled = db.enabled }
  for k in pairs(db) do db[k] = nil end
  FillDefaults(db, ns.DEFAULTS)
  for k, v in pairs(keep) do db[k] = v end
end
