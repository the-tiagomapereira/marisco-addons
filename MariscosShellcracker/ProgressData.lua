-- Marisco's Shellcracker - levels, titles, talents and items (data only)
local _, ns = ...

ns.MAX_LEVEL = 60
ns.TALENT_START = 10                   -- first talent point at level 10, one per level after (51 at 60)

-- experience to go from level L to L+1
function ns.XPToNext(L) return math.floor(15 * L ^ 1.5 + 100) end

-- Classic PvP ranks, one title every 10 levels (rank badge icons from the honor system)
ns.TITLES = {
    Horde    = { "Scout", "Sergeant", "Stone Guard", "Legionnaire", "Champion", "Warlord", "High Warlord" },
    Alliance = { "Private", "Sergeant", "Knight", "Knight-Captain", "Lieutenant Commander", "Field Marshal", "Grand Marshal" },
}
ns.TITLE_BADGES = { 1, 3, 6, 8, 10, 13, 14 }    -- Interface\PvPRankBadges\PvPRankNN

function ns.TitleFor(level, faction)
    local i = math.min(7, math.floor(level / 10) + 1)
    local list = ns.TITLES[faction] or ns.TITLES.Horde
    return list[i], ("Interface\\PvPRankBadges\\PvPRank%02d"):format(ns.TITLE_BADGES[i]), i
end

---------------------------------------------------------------------------
-- Talents: 3 trees, 7 tiers, 4 columns. Tier N needs (N-1)*5 points in that tree.
-- fx: effect per rank. text: %s is replaced by the per-rank value times the rank.
---------------------------------------------------------------------------
ns.TREES = {
    { name = "Arms",       icon = "Interface\\Icons\\Ability_Warrior_SavageBlow",        bg = "Interface\\TalentFrame\\WarriorArms-TopLeft",
      desc = "Raw damage and critical hits." },
    { name = "Tidecaller", icon = "Interface\\Icons\\Spell_Frost_SummonWaterElemental",  bg = "Interface\\TalentFrame\\ShamanElementalCombat-TopLeft",
      desc = "Combos, cascades and special gems." },
    { name = "Protection", icon = "Interface\\Icons\\INV_Shield_06",                     bg = "Interface\\TalentFrame\\WarriorProtection-TopLeft",
      desc = "Health, defence, gold and experience." },
}

local T = {}
local function talent(tree, tier, col, max, id, name, icon, fx, text)
    T[#T+1] = { tree = tree, tier = tier, col = col, max = max, id = id, name = name,
                icon = "Interface\\Icons\\" .. icon, fx = fx, text = text }
end

-- Arms
talent(1, 1, 1, 5, "heavyBlows",   "Heavy Blows",           "Ability_Warrior_SavageBlow",  { dmg = 2 },        "Increases all damage you deal by %s%%.")
talent(1, 1, 2, 5, "cruelty",      "Cruelty",               "Ability_Rogue_Eviscerate",    { crit = 1 },       "Increases your chance to critically hit by %s%%. Critical hits deal 50%% more damage.")
talent(1, 2, 1, 3, "sundering",    "Sundering Strikes",     "Ability_Warrior_Sunder",      { plain = 5 },      "Plain 3-gem matches deal %s%% more damage.")
talent(1, 2, 2, 2, "impale",       "Impale",                "Ability_SearingArrow",        { critDmg = 15 },   "Your critical hits deal %s%% more damage.")
talent(1, 2, 3, 2, "shellBreaker", "Shell Breaker",         "INV_Misc_Shell_02",           { shellPierce = 50 }, "Hard shells block %s%% less of your damage.")
talent(1, 3, 1, 3, "opportunity",  "Opportunity",           "Ability_BackStab",            { firstStrike = 10 }, "Your first 3 moves against each makrura deal %s%% more damage.")
talent(1, 3, 2, 5, "weaponSpec",   "Weapon Specialization", "INV_Axe_09",                  { weapon = 10 },    "Increases your Damage stat by %s%%.")
talent(1, 3, 4, 3, "bloodCraze",   "Blood Craze",           "Spell_Shadow_SummonImp",      { comboHeal = 10 }, "Each x3 or bigger combo heals you for %s health.")
talent(1, 4, 2, 2, "execute",      "Improved Execute",      "INV_Sword_48",                { execute = 15 },   "You deal %s%% more damage to makrura below 20%% health.")
talent(1, 4, 3, 5, "enrage",       "Enrage",                "Spell_Shadow_UnholyFrenzy",   { lastStand = 5 },  "While you are below 30%% health, you deal %s%% more damage.")
talent(1, 5, 1, 3, "overpower",    "Overpower",             "Ability_MeleeDamage",         { overpower = 10 }, "After a makrura hits you, your next move deals %s%% more damage.")
talent(1, 6, 2, 5, "flurry",       "Flurry",                "Ability_GhoulFrenzy",         { flurry = 4 },     "After a critical hit, your next move deals %s%% more damage.")
talent(1, 7, 2, 1, "mortalStrike", "Mortal Strike",         "Ability_Warrior_DecisiveStrike", { dmg = 10, critDmg = 20 },
    "Increases all damage you deal by 10%% and your critical hits deal 20%% more damage.")

-- Tidecaller
talent(2, 1, 1, 5, "risingTide",   "Rising Tide",           "Spell_Frost_FrostBolt02",     { combo = 3 },      "Combos deal %s%% more damage for each cascade after the first.")
talent(2, 1, 3, 5, "gemcutting",   "Gemcutting",            "INV_Misc_Gem_02",             { special = 4 },    "Gems destroyed by explosions and Hypercubes deal %s%% more damage.")
talent(2, 2, 1, 3, "kindling",     "Kindling",              "Spell_Fire_Fire",             { kindling = 1 },   "Each makrura fight starts with %s Flame Gem(s) on the board.")
talent(2, 2, 2, 1, "undertow",     "Undertow",              "Spell_Frost_Stun",            { stagger2 = 1 },   "x2 combos also stagger the makrura, delaying its attack.")
talent(2, 2, 4, 3, "chainLightning", "Chain Lightning",     "Spell_Nature_ChainLightning", { starBonus = 20 }, "Star Gem explosions deal %s%% more damage.")
talent(2, 3, 1, 3, "arcaneConc",   "Arcane Concentration",  "Spell_Shadow_ManaBurn",       { hyperBonus = 15 }, "Hypercube blasts deal %s%% more damage.")
talent(2, 3, 3, 5, "tidalSurge",   "Tidal Surge",           "Spell_Frost_IceStorm",        { tidal3 = 4 },     "x3 or bigger combos deal an extra %s%% damage.")
talent(2, 4, 2, 3, "ignite",       "Ignite",                "Spell_Fire_Incinerate",       { flameBonus = 10 }, "Flame Gem explosions deal %s%% more damage.")
talent(2, 4, 3, 2, "masterElements", "Master of Elements",  "Spell_Fire_MasterOfElements", { forgeHeal = 10 }, "Forging a special gem heals you for %s health.")
talent(2, 5, 2, 5, "tidebringer",  "Tidebringer",           "Spell_Nature_StormReach",     { tidebringer = 2 }, "You deal %s%% more damage for each special gem on the board (up to 5).")
talent(2, 6, 3, 3, "elemPrecision", "Elemental Precision",  "Spell_Frost_WizardMark",      { comboCrit = 2 },  "x2 or bigger combos have %s%% more chance to critically hit.")
talent(2, 7, 2, 1, "tidalWave",    "Tidal Wave",            "Spell_Frost_SummonWaterElemental", { startHyper = 1 }, "Each makrura fight starts with a Hypercube on the board.")

-- Protection
talent(3, 1, 2, 5, "toughness",    "Toughness",             "Spell_Holy_Devotion",         { hp = 30 },        "Increases your maximum health by %s.")
talent(3, 1, 3, 5, "anticipation", "Anticipation",          "Spell_Nature_MirrorImage",    { dodge = 1 },      "%s%% chance to dodge a makrura attack.")
talent(3, 2, 1, 3, "ironWill",     "Iron Will",             "Spell_Magic_MageArmor",       { armorPct = 3 },   "Reduces the damage you take by %s%%.")
talent(3, 2, 2, 3, "healingWaters", "Healing Waters",       "Spell_Nature_HealingWaveGreater", { emerald = 10 }, "Each Huge Emerald you match heals %s more health.")
talent(3, 2, 4, 2, "treasureHunter", "Treasure Hunter",     "INV_Misc_Coin_01",            { gold = 10 },      "Makrura drop %s%% more gold.")
talent(3, 3, 1, 3, "secondWind",   "Second Wind",           "Spell_Nature_Rejuvenation",   { waveHeal = 50 },  "You recover %s more health after each makrura you defeat.")
talent(3, 3, 2, 2, "hamstring",    "Hamstring",             "Ability_ShockWave",           { hamstring = 8 },  "%s%% chance that a move doesn't bring the makrura's attack closer.")
talent(3, 3, 4, 3, "scholar",      "Scholar",               "INV_Misc_Book_11",            { xp = 5 },         "You gain %s%% more experience.")
talent(3, 4, 2, 1, "shieldWall",   "Shield Wall",           "Ability_Warrior_ShieldWall",  { shieldWall = 1 }, "A hit that would leave you below 250 health deals half damage.")
talent(3, 4, 3, 2, "mortalWounds", "Mortal Wounds",         "Ability_CriticalStrike",      { mendCut = 25 },   "The mending tide heals %s%% less.")
talent(3, 5, 1, 1, "lastStand",    "Last Stand",            "Spell_Holy_AshesToAshes",     { cheatDeath = 1 }, "Once per run, a killing blow leaves you at 1 health instead.")
talent(3, 5, 3, 3, "prospector",   "Prospector",            "INV_Pick_02",                 { drop = 10 },      "Makrura are %s%% more likely to drop an item, and better items drop more often.")
talent(3, 6, 2, 5, "vitality",     "Vitality",              "Spell_Nature_UnyeildingStamina", { hp = 40 },     "Increases your maximum health by %s.")
talent(3, 7, 2, 1, "bulwark",      "Bulwark",               "Ability_Warrior_DefensiveStance", { slow = 1 },   "Makrura attack one move later.")

ns.TALENTS = T
ns.TALENT_BY_ID = {}
for _, t in ipairs(T) do ns.TALENT_BY_ID[t.id] = t end

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------
-- Equipment types (what an item is) and gear slots (where it goes), like WoW.
-- budget = share of the full stat range (like WoW's item budgets: big pieces get more)
-- armor  = armor pieces always roll Armor; weapon = always roll Damage
ns.ITEM_TYPES = {
    HEAD     = { name = "Head",            budget = 1.00, armor = true, slots = { "HEAD" } },
    NECK     = { name = "Neck",            budget = 0.55, slots = { "NECK" } },
    SHOULDER = { name = "Shoulder",        budget = 0.75, armor = true, slots = { "SHOULDER" } },
    BACK     = { name = "Back",            budget = 0.55, armor = true, slots = { "BACK" } },
    CHEST    = { name = "Chest",           budget = 1.00, armor = true, slots = { "CHEST" } },
    WRIST    = { name = "Wrist",           budget = 0.55, armor = true, slots = { "WRIST" } },
    HANDS    = { name = "Hands",           budget = 0.75, armor = true, slots = { "HANDS" } },
    WAIST    = { name = "Waist",           budget = 0.75, armor = true, slots = { "WAIST" } },
    LEGS     = { name = "Legs",            budget = 1.00, armor = true, slots = { "LEGS" } },
    FEET     = { name = "Feet",            budget = 0.75, armor = true, slots = { "FEET" } },
    FINGER   = { name = "Finger",          budget = 0.55, slots = { "FINGER1", "FINGER2" } },
    TRINKET  = { name = "Trinket",         budget = 0.55, slots = { "TRINKET1", "TRINKET2" } },
    ["1H"]   = { name = "One-Hand",        budget = 0.65, weapon = true, slots = { "MAINHAND", "OFFHAND" } },
    ["2H"]   = { name = "Two-Hand",        budget = 1.30, weapon = true, slots = { "MAINHAND" } },
    SHIELD   = { name = "Off Hand",        budget = 0.55, armor = true, slots = { "OFFHAND" }, shield = true },
    RANGED   = { name = "Ranged",          budget = 0.55, weapon = true, slots = { "RANGED" } },
}
-- drop weights per type (one-handers and armor are the most common, like in WoW)
ns.TYPE_WEIGHTS = { HEAD = 6, NECK = 4, SHOULDER = 5, BACK = 4, CHEST = 6, WRIST = 4, HANDS = 5, WAIST = 5,
                    LEGS = 6, FEET = 5, FINGER = 5, TRINKET = 4, ["1H"] = 6, ["2H"] = 4, SHIELD = 3, RANGED = 3 }

-- gear slots in paper-doll order: left column, right column, weapons row
ns.SLOTS = {
    { id = "HEAD",     name = "Head",      tex = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Head",          col = "L" },
    { id = "NECK",     name = "Neck",      tex = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Neck",          col = "L" },
    { id = "SHOULDER", name = "Shoulder",  tex = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shoulder",      col = "L" },
    { id = "BACK",     name = "Back",      tex = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest",         col = "L" },
    { id = "CHEST",    name = "Chest",     tex = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest",         col = "L" },
    { id = "WRIST",    name = "Wrist",     tex = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Wrists",        col = "L" },
    { id = "HANDS",    name = "Hands",     tex = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Hands",         col = "R" },
    { id = "WAIST",    name = "Waist",     tex = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Waist",         col = "R" },
    { id = "LEGS",     name = "Legs",      tex = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Legs",          col = "R" },
    { id = "FEET",     name = "Feet",      tex = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Feet",          col = "R" },
    { id = "FINGER1",  name = "Finger",    tex = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger",        col = "R" },
    { id = "FINGER2",  name = "Finger",    tex = "Interface\\PaperDoll\\UI-PaperDoll-Slot-RFinger",       col = "R" },
    { id = "TRINKET1", name = "Trinket",   tex = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket",       col = "R" },
    { id = "TRINKET2", name = "Trinket",   tex = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket",       col = "R" },
    { id = "MAINHAND", name = "Main Hand", tex = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand",      col = "B" },
    { id = "OFFHAND",  name = "Off Hand",  tex = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand", col = "B" },
    { id = "RANGED",   name = "Ranged",    tex = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Ranged",        col = "B" },
}
ns.SLOT_BY_ID = {}
for i, s in ipairs(ns.SLOTS) do ns.SLOT_BY_ID[s.id] = s; s.index = i end

ns.BAG_SIZE = 16
ns.BUYBACK_SIZE = 12

-- quality: 0 poor (grey junk), 1 common, 2 uncommon, 3 rare, 4 epic, 5 legendary
-- stats = how many stats it rolls, min/max = value of each stat on an item level 60 item
-- effects = how many effects, extraChance = chance of one more, tier = strength of its effects (1-3)
ns.QUALITY = {
    [0] = { name = "Poor",      color = "ff9d9d9d", stats = 0, price = 0.3 },
    [1] = { name = "Common",    color = "ffffffff", stats = 2, min = 1,  max = 15, price = 0.6 },
    [2] = { name = "Uncommon",  color = "ff1eff00", stats = 2, min = 15, max = 25, effects = 1, tier = 1, price = 1.0 },
    [3] = { name = "Rare",      color = "ff0070dd", stats = 3, min = 25, max = 35, effects = 1, extraChance = 0.30, tier = 2, price = 3.0 },
    [4] = { name = "Epic",      color = "ffa335ee", stats = 4, min = 40, max = 50, effects = 2, tier = 3, price = 10.0 },
    [5] = { name = "Legendary", color = "ffff8000", stats = 4, min = 60, max = 80, legendary = true, price = 25.0 },
}
-- stat values shrink for lower item levels: value x (item level / 60) ^ 2.5 (at least 1)
ns.ILVL_POWER = 2.5

-- Shellcracker stats: what one point does
ns.STAT_INFO = {
    sta     = { name = "Stamina",          short = "Stamina",   each = 10,   how = "+10 maximum health per point",                  suffix = "of the Bear" },
    dmg     = { name = "Damage",           short = "Damage",    each = 1,    how = "+1 damage to every match per point",            suffix = "of the Tiger" },
    crit    = { name = "Critical Strike",  short = "Crit",      each = 0.1,  how = "+0.1%% critical hit chance per point",          suffix = "of the Falcon" },
    combo   = { name = "Combo Power",      short = "Combo",     each = 0.2,  how = "+0.2%% damage per cascade level per point",     suffix = "of the Tides" },
    boom    = { name = "Explosive Power",  short = "Explosive", each = 0.5,  how = "+0.5%% special gem damage per point",           suffix = "of Blasting" },
    armor   = { name = "Armor",            short = "Armor",     each = 1,    how = "reduces the damage you take (diminishing)",     suffix = "of Defense" },
    resto   = { name = "Restoration",      short = "Resto",     each = 1,    how = "+1%% Huge Emerald healing per point",           suffix = "of the Owl" },
    fortune = { name = "Fortune",          short = "Fortune",   each = 0.5,  how = "+0.5%% gold and +0.25%% item drop chance per point", suffix = "of the Monkey" },
}
ns.STAT_ORDER = { "sta", "dmg", "crit", "combo", "boom", "armor", "resto", "fortune" }
ns.ARMOR_K = 600           -- damage reduction = armor / (armor + ARMOR_K), at most 50%
ns.ARMOR_CAP = 0.5

-- item effects: value by tier (uncommon, rare, epic)
ns.ITEM_EFFECTS = {
    { key = "emeraldProc", tiers = { { 20, 100 }, { 25, 150 }, { 30, 250 } },
      text = function(v) return ("Matching a Huge Emerald has a %d%% chance to heal you for %d more."):format(v[1], v[2]) end },
    { key = "freezeChance", tiers = { 3, 5, 8 },  text = "+%d%% chance that Aquamarine freezes the makrura." },
    { key = "curseChance",  tiers = { 3, 5, 8 },  text = "+%d%% chance that Shadowgem curses the makrura." },
    { key = "capDmg",       tiers = { 3, 5, 8 },  text = "Diamond Edge can grow %d%% higher per tide." },
    { key = "capDr",        tiers = { 1, 2, 3 },  text = "Ruby Ward can grow %d%% higher per tide." },
    { key = "capLoot",      tiers = { 5, 8, 12 }, text = "Citrine Fortune and Pearl Luck can grow %d%% higher per tide." },
    { key = "tidal3",       tiers = { 5, 8, 12 }, text = "x3 and bigger combos deal %d%% more damage." },
    { key = "killHeal",     tiers = { 2, 4, 6 },  text = "Defeating a makrura heals you for %d%% of your maximum health." },
    { key = "doubleHit",    tiers = { 2, 3, 5 },  text = "Each match has a %d%% chance to deal double damage." },
}

-- the 8 legendaries, one per slot; each effect is unique and doesn't scale
ns.LEGENDARIES = {
    { id = "clawAngler",   slot = "1H",      name = "Claw of Lord Angler",     icon = "INV_Misc_MonsterClaw_04",
      text = "Every x3 or bigger combo forges a Flame Gem on the board." },
    { id = "crownTide",    slot = "HEAD",    name = "Crown of the Tidelord",   icon = "INV_Helmet_53",
      text = "Each makrura fight starts with a Hypercube on the board." },
    { id = "shellAncient", slot = "CHEST",   name = "Shell of the Ancients",   icon = "INV_Chest_Plate16",
      text = "The first hit of every makrura fight is fully absorbed." },
    { id = "gripsUndertow", slot = "HANDS",  name = "Grips of the Undertow",   icon = "INV_Gauntlets_30",
      text = "Forging a Hypercube also forges a Supernova." },
    { id = "legsAbyss",    slot = "LEGS",    name = "Leggings of the Abyss",   icon = "INV_Pants_Plate_17",
      text = "Shadowgem curses stack, up to 3 at once." },
    { id = "treadsTide",   slot = "FEET",    name = "Treads of the Low Tide",  icon = "INV_Boots_Plate_06",
      text = "Makrura attack one move later." },
    { id = "bandTides",    slot = "FINGER",  name = "Band of Endless Tides",   icon = "INV_Jewelry_Ring_36",
      text = "All gem buff caps are 50% higher." },
    { id = "heartDeep",    slot = "TRINKET", name = "Heart of the Deep",       icon = "INV_Misc_Gem_Pearl_06",
      text = "You heal for 3% of all the damage you deal." },
}
ns.LEGENDARY_BY_ID = {}
for _, l in ipairs(ns.LEGENDARIES) do ns.LEGENDARY_BY_ID[l.id] = l end

-- drop rules
ns.DROP = {
    normal = 0.22, rare = 0.6, boss = 1.0,            -- chance of an item
    legendaryEvery = 5, legendaryChance = 0.02,       -- every 5th makrura of a run can drop a legendary (2%)
    legendaryBoss = 0.20,                             -- bosses (Lord Angler): 20%
    crazedChance = 0.05,                              -- a normal makrura may be Loot-Crazed (5%)
    crazedOdds = { [3] = 50, [4] = 30, [5] = 20 },    -- Loot-Crazed: always Rare or better
    crazedGold = 3,
}

ns.ITEM_BASES = {
    HEAD     = { "Barnacled Helm", "Coral Circlet", "Saltcrusted Coif", "Tideworn Cap", "Shellplate Helm", "Fisherman's Hood" },
    NECK     = { "Pearl Necklace", "Coral Pendant", "Sharktooth Choker", "Kelp-strung Amulet", "Tidestone Locket" },
    SHOULDER = { "Shellplate Pauldrons", "Barnacled Spaulders", "Kelpweave Mantle", "Tideworn Shoulderpads", "Coral Epaulets" },
    BACK     = { "Sailcloth Cape", "Netweave Cloak", "Kelpweave Drape", "Tideworn Cloak", "Sealskin Cape" },
    CHEST    = { "Kelpweave Robe", "Shellplate Breastplate", "Saltcrusted Tunic", "Tideworn Vest", "Barnacled Hauberk", "Scaled Jerkin" },
    WRIST    = { "Coral Bracers", "Shellplate Vambraces", "Kelpweave Cuffs", "Tideworn Wristguards", "Barnacled Bindings" },
    HANDS    = { "Pincer Gauntlets", "Netmender's Gloves", "Coral Handguards", "Tideworn Gloves", "Shellplate Gauntlets" },
    WAIST    = { "Rope Belt", "Shellplate Girdle", "Kelpweave Sash", "Tideworn Waistband", "Barnacled Cord" },
    LEGS     = { "Kelpweave Leggings", "Tideworn Trousers", "Barnacled Legguards", "Shellplate Greaves", "Scaled Kilt" },
    FEET     = { "Sandstrider Boots", "Wading Boots", "Barnacled Sabatons", "Tideworn Sandals", "Coral Treads" },
    FINGER   = { "Pearl Ring", "Coral Band", "Shell Loop", "Tidestone Signet", "Kelp-woven Ring" },
    TRINKET  = { "Makrura Claw", "Lucky Fishing Lure", "Glowing Shell", "Conch of the Tides", "Polished Pearl", "Smooth Tidestone" },
    ["1H"]   = { "Gutting Knife", "Coral Blade", "Claw Cleaver", "Barnacled Mace", "Boarding Axe", "Cutlass" },
    ["2H"]   = { "Harpoon", "Driftwood Maul", "Trident", "Barbed Spear", "Anchor Hammer", "Greatcleaver" },
    SHIELD   = { "Shell Shield", "Turtle-plate Buckler", "Coral Bulwark", "Barnacled Kite Shield" },
    RANGED   = { "Fishing Bow", "Harpoon Gun", "Coral Wand", "Driftwood Crossbow", "Salt-crusted Rifle" },
}
ns.POOR_PREFIX = { "Cracked", "Waterlogged", "Rusty", "Torn", "Brittle", "Salt-eaten" }

ns.ITEM_ICONS = {
    HEAD     = { "INV_Helmet_01", "INV_Helmet_08", "INV_Helmet_25", "INV_Helmet_29", "INV_Helmet_34" },
    NECK     = { "INV_Jewelry_Necklace_01", "INV_Jewelry_Necklace_04", "INV_Jewelry_Necklace_07", "INV_Jewelry_Amulet_02" },
    SHOULDER = { "INV_Shoulder_02", "INV_Shoulder_05", "INV_Shoulder_09", "INV_Shoulder_14" },
    BACK     = { "INV_Misc_Cape_01", "INV_Misc_Cape_06", "INV_Misc_Cape_11", "INV_Misc_Cape_16" },
    CHEST    = { "INV_Chest_Chain_04", "INV_Chest_Cloth_21", "INV_Chest_Leather_07", "INV_Chest_Plate06" },
    WRIST    = { "INV_Bracer_02", "INV_Bracer_05", "INV_Bracer_07", "INV_Bracer_13" },
    HANDS    = { "INV_Gauntlets_04", "INV_Gauntlets_05", "INV_Gauntlets_19", "INV_Gauntlets_29" },
    WAIST    = { "INV_Belt_03", "INV_Belt_04", "INV_Belt_09", "INV_Belt_13" },
    LEGS     = { "INV_Pants_02", "INV_Pants_06", "INV_Pants_Mail_03", "INV_Pants_Plate_05" },
    FEET     = { "INV_Boots_01", "INV_Boots_05", "INV_Boots_Chain_04", "INV_Boots_Plate_03" },
    FINGER   = { "INV_Jewelry_Ring_03", "INV_Jewelry_Ring_05", "INV_Jewelry_Ring_09", "INV_Jewelry_Ring_15", "INV_Jewelry_Ring_22" },
    TRINKET  = { "INV_Misc_Gem_Pearl_03", "INV_Jewelry_Talisman_01", "INV_Misc_Orb_01", "INV_Misc_Bone_08", "INV_Misc_Shell_01" },
    ["1H"]   = { "INV_Sword_04", "INV_Sword_23", "INV_Mace_01", "INV_Axe_04", "INV_Weapon_ShortBlade_05" },
    ["2H"]   = { "INV_Spear_04", "INV_Spear_06", "INV_Sword_39", "INV_Axe_09", "INV_Hammer_04", "INV_Staff_08" },
    SHIELD   = { "INV_Shield_04", "INV_Shield_05", "INV_Shield_09", "INV_Shield_17" },
    RANGED   = { "INV_Weapon_Bow_01", "INV_Weapon_Bow_05", "INV_Weapon_Rifle_01", "INV_Wand_01", "INV_Weapon_Crossbow_01" },
}
