-- Border skins: stacked flat layers behind the map (masked round for a round map),
-- or one of the game's own backdrop borders for a square map.

local ADDON, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

ns.SKINS = {
  { key = "stock",   name = "Stock",     desc = "Blizzard's own round border. Square: a thin dark line." },
  { key = "clean",   name = "Clean",     desc = "No border at all." },
  { key = "line",    name = "Thin line", desc = "One line in the border color." },
  { key = "framed",  name = "Framed",    desc = "The border color between two dark lines." },
  { key = "shadow",  name = "Shadowed",  desc = "The border color with a soft shadow around it." },
  { key = "tooltip", name = "Tooltip",   desc = "The game's tooltip border. Round maps use Framed." },
  { key = "dialog",  name = "Dialog",    desc = "The game's dialog-window border. Round maps use Framed." },
}
ns.SKIN_BY_KEY, ns.SKIN_KEYS = {}, {}
for i, s in ipairs(ns.SKINS) do
  s.index = i
  ns.SKIN_BY_KEY[s.key] = s
  ns.SKIN_KEYS[i] = s.key
end

-- does the skin use the color / thickness settings?
function ns.SkinUsesColor(key) return key == "line" or key == "framed" or key == "shadow" or key == "tooltip" or key == "dialog" end
function ns.SkinUsesThickness(key) return key == "line" or key == "framed" or key == "shadow" end

function ns.ShowBlizzardRing()
  return ns.db.skin == "stock" and ns.db.shape ~= "square"
end

local BACKDROPS = {
  tooltip = { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16, outset = 4 },
  dialog  = { edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 24, outset = 7 },
}

local layers, masks, masked = {}, {}, {}
local backdrop

function ns.CreateSkinLayers(holder)
  for i = 1, 5 do
    local t = holder:CreateTexture(nil, "BACKGROUND", nil, i - 8)
    t:SetTexture(WHITE)
    local m = holder:CreateMaskTexture()
    m:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIONAL", "CLAMPTOBLACKADDITIONAL")
    m:SetAllPoints(t)
    t:Hide()
    layers[i], masks[i] = t, m
  end
  local ok, f = pcall(CreateFrame, "Frame", nil, holder, "BackdropTemplate")
  if ok and f and f.SetBackdrop then
    backdrop = f
    backdrop:Hide()
  end
end

local function LayerList(key, square, t, c)
  local dark = { 0, 0, 0, 1 }
  local col = { c.r, c.g, c.b, c.a or 1 }
  if key == "stock" then
    return square and { { 1, 0, 0, 0, 0.9 } } or {}
  elseif key == "clean" then
    return {}
  elseif key == "line" then
    return { { t, unpack(col) } }
  elseif key == "shadow" then
    return { { t + 6, 0, 0, 0, 0.12 }, { t + 4, 0, 0, 0, 0.2 }, { t + 2, 0, 0, 0, 0.35 }, { t, unpack(col) } }
  else -- framed, and tooltip/dialog on a round map
    return { { t + 2, unpack(dark) }, { t + 1, unpack(col) }, { 1, unpack(dark) } }
  end
end

function ns.ApplySkin(holder, size)
  if not layers[1] then return end
  local db = ns.db
  local square = db.shape == "square"
  local key = db.skin
  if not ns.SKIN_BY_KEY[key] then key = "stock" db.skin = key end
  local c = db.borderColor
  local t = math.max(1, math.min(8, db.thickness or 2))

  local bd = square and BACKDROPS[key] and backdrop
  local list = bd and {} or LayerList(key, square, t, c)

  for i, tex in ipairs(layers) do
    local L = list[i]
    if L then
      local o = L[1]
      tex:ClearAllPoints()
      tex:SetPoint("TOPLEFT", holder, "TOPLEFT", -o, o)
      tex:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", o, -o)
      tex:SetVertexColor(L[2], L[3], L[4], L[5])
      if square and masked[i] then tex:RemoveMaskTexture(masks[i]) masked[i] = false
      elseif not square and not masked[i] then tex:AddMaskTexture(masks[i]) masked[i] = true end
      tex:Show()
    else
      tex:Hide()
    end
  end

  if backdrop then
    if bd then
      local spec = BACKDROPS[key]
      backdrop:ClearAllPoints()
      backdrop:SetPoint("TOPLEFT", holder, "TOPLEFT", -spec.outset, spec.outset)
      backdrop:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", spec.outset, -spec.outset)
      backdrop:SetBackdrop({ edgeFile = spec.edgeFile, edgeSize = spec.edgeSize })
      backdrop:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1)
      backdrop:SetFrameLevel(Minimap:GetFrameLevel() + 2)
      backdrop:Show()
    else
      backdrop:Hide()
    end
  end
end
