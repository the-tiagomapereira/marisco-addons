-- Marisco's Item Value Scanner - Disenchant estimates
--
-- Forever has not published its own disenchant table yet; guides say disenchanting
-- still works as in Classic, so this uses the Classic Era table, keyed by ITEM LEVEL.
-- Everything is in the tables below, so Forever-specific changes are easy to patch in.

local _, ns = ...

local GetItemInfoFn = (C_Item and C_Item.GetItemInfo) or GetItemInfo

------------------------------------------------------------------------
-- Materials (fallback names are used until the client has the item cached)
------------------------------------------------------------------------
local MAT = {
    STRANGE_DUST   = { id = 10940, name = "Strange Dust" },
    SOUL_DUST      = { id = 11083, name = "Soul Dust" },
    VISION_DUST    = { id = 11137, name = "Vision Dust" },
    DREAM_DUST     = { id = 11176, name = "Dream Dust" },
    ILLUSION_DUST  = { id = 16204, name = "Illusion Dust" },

    LESSER_MAGIC   = { id = 10938, name = "Lesser Magic Essence" },
    GREATER_MAGIC  = { id = 10939, name = "Greater Magic Essence" },
    LESSER_ASTRAL  = { id = 10998, name = "Lesser Astral Essence" },
    GREATER_ASTRAL = { id = 11082, name = "Greater Astral Essence" },
    LESSER_MYSTIC  = { id = 11134, name = "Lesser Mystic Essence" },
    GREATER_MYSTIC = { id = 11135, name = "Greater Mystic Essence" },
    LESSER_NETHER  = { id = 11174, name = "Lesser Nether Essence" },
    GREATER_NETHER = { id = 11175, name = "Greater Nether Essence" },
    LESSER_ETERNAL = { id = 16202, name = "Lesser Eternal Essence" },
    GREATER_ETERNAL= { id = 16203, name = "Greater Eternal Essence" },

    SMALL_GLIMMER  = { id = 10978, name = "Small Glimmering Shard" },
    LARGE_GLIMMER  = { id = 11084, name = "Large Glimmering Shard" },
    SMALL_GLOWING  = { id = 11138, name = "Small Glowing Shard" },
    LARGE_GLOWING  = { id = 11139, name = "Large Glowing Shard" },
    SMALL_RADIANT  = { id = 11177, name = "Small Radiant Shard" },
    LARGE_RADIANT  = { id = 11178, name = "Large Radiant Shard" },
    SMALL_BRILLIANT= { id = 14343, name = "Small Brilliant Shard" },
    LARGE_BRILLIANT= { id = 14344, name = "Large Brilliant Shard" },
    NEXUS          = { id = 20725, name = "Nexus Crystal" },
}

------------------------------------------------------------------------
-- Uncommon (green): dust + essence (+ small shard chance)
-- Armor: 75% dust / 20% essence / 5% shard. Weapons swap dust and essence.
-- { maxItemLevel, dust, dustMin, dustMax, essence, essMin, essMax, shard }
------------------------------------------------------------------------
local UNCOMMON = {
    { 15, MAT.STRANGE_DUST,  1, 2, MAT.LESSER_MAGIC,    1, 2, nil },
    { 20, MAT.STRANGE_DUST,  2, 3, MAT.GREATER_MAGIC,   1, 2, MAT.SMALL_GLIMMER },
    { 25, MAT.STRANGE_DUST,  4, 6, MAT.LESSER_ASTRAL,   1, 2, MAT.SMALL_GLIMMER },
    { 30, MAT.SOUL_DUST,     1, 2, MAT.GREATER_ASTRAL,  1, 2, MAT.LARGE_GLIMMER },
    { 35, MAT.SOUL_DUST,     2, 5, MAT.LESSER_MYSTIC,   1, 2, MAT.SMALL_GLOWING },
    { 40, MAT.VISION_DUST,   1, 2, MAT.GREATER_MYSTIC,  1, 2, MAT.LARGE_GLOWING },
    { 45, MAT.VISION_DUST,   2, 5, MAT.LESSER_NETHER,   1, 2, MAT.SMALL_RADIANT },
    { 50, MAT.DREAM_DUST,    1, 2, MAT.GREATER_NETHER,  1, 2, MAT.LARGE_RADIANT },
    { 55, MAT.DREAM_DUST,    2, 5, MAT.LESSER_ETERNAL,  1, 2, MAT.SMALL_BRILLIANT },
    { 60, MAT.ILLUSION_DUST, 1, 2, MAT.GREATER_ETERNAL, 1, 2, MAT.LARGE_BRILLIANT },
    { 999,MAT.ILLUSION_DUST, 2, 5, MAT.GREATER_ETERNAL, 2, 3, MAT.LARGE_BRILLIANT },
}

-- Rare (blue): one shard, 100% (high end has a small Nexus Crystal chance)
local RARE = {
    { 25,  MAT.SMALL_GLIMMER },
    { 30,  MAT.LARGE_GLIMMER },
    { 35,  MAT.SMALL_GLOWING },
    { 40,  MAT.LARGE_GLOWING },
    { 45,  MAT.SMALL_RADIANT },
    { 50,  MAT.LARGE_RADIANT },
    { 55,  MAT.SMALL_BRILLIANT },
    { 999, MAT.LARGE_BRILLIANT, nexus = true },
}

-- Epic (purple): 2-4 shards, or Nexus Crystals at the top
local EPIC = {
    { 45,  MAT.SMALL_RADIANT,   2, 4 },
    { 50,  MAT.LARGE_RADIANT,   2, 4 },
    { 55,  MAT.SMALL_BRILLIANT, 2, 4 },
    { 60,  MAT.NEXUS,           1, 1 },
    { 999, MAT.NEXUS,           1, 2 },
}

local function Bracket(tbl, ilvl)
    for _, row in ipairs(tbl) do
        if ilvl <= row[1] then return row end
    end
    return tbl[#tbl]
end

local NOT_DISENCHANTABLE_SLOTS = { INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_BAG = true }
local CLASS_WEAPON, CLASS_ARMOR = 2, 4

local function Out(mat, min, max, chance)
    return { id = mat.id, name = mat.name, min = min, max = max, chance = chance }
end

-- Returns a list of { id, name, min, max, chance } or nil if not disenchantable.
function ns.GetDisenchantOutcomes(link)
    local _, _, quality, ilvl, _, _, _, _, equipLoc, _, _, classID = GetItemInfoFn(link)
    if not quality or not ilvl or ilvl <= 0 then return nil end
    if quality < 2 or quality > 4 then return nil end
    if classID ~= CLASS_WEAPON and classID ~= CLASS_ARMOR then return nil end
    if equipLoc and NOT_DISENCHANTABLE_SLOTS[equipLoc] then return nil end
    if not equipLoc or equipLoc == "" then return nil end

    local outcomes = {}
    if quality == 2 then
        local r = Bracket(UNCOMMON, ilvl)
        local shardChance = r[8] and 0.05 or 0
        local main = 1 - shardChance - 0.20
        local dustChance, essChance = main, 0.20
        if classID == CLASS_WEAPON then dustChance, essChance = 0.20, main end
        outcomes[#outcomes + 1] = Out(r[2], r[3], r[4], dustChance)
        outcomes[#outcomes + 1] = Out(r[5], r[6], r[7], essChance)
        if r[8] then outcomes[#outcomes + 1] = Out(r[8], 1, 1, shardChance) end
    elseif quality == 3 then
        local r = Bracket(RARE, ilvl)
        if r.nexus then
            outcomes[#outcomes + 1] = Out(r[2], 1, 1, 0.995)
            outcomes[#outcomes + 1] = Out(MAT.NEXUS, 1, 1, 0.005)
        else
            outcomes[#outcomes + 1] = Out(r[2], 1, 1, 1)
        end
    else
        local r = Bracket(EPIC, ilvl)
        outcomes[#outcomes + 1] = Out(r[2], r[3], r[4], 1)
    end

    for _, o in ipairs(outcomes) do
        local name = GetItemInfoFn(o.id)
        if name then o.name = name end
    end
    return outcomes
end

-- Values each outcome with the scanned AH price of the material.
-- Returns expected, low, high, missingPrice (true if some material has no AH price).
function ns.ValueDisenchant(outcomes)
    local prices = ns.data and ns.data.prices or {}
    local expected, low, high, missing = 0, nil, nil, false
    for _, o in ipairs(outcomes) do
        local p = prices[o.id] and prices[o.id].min
        o.price = p
        if p then
            expected = expected + o.chance * ((o.min + o.max) / 2) * p
            local lo, hi = o.min * p, o.max * p
            if o.chance >= 0.05 then          -- ignore tiny-chance outcomes for the range floor
                low = low and math.min(low, lo) or lo
            end
            high = high and math.max(high, hi) or hi
        else
            missing = true
        end
    end
    return expected, low or 0, high or 0, missing
end
