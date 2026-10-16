-- Marisco's Shellcracker - gems, makrura and balance numbers
local _, ns = ...

-- The 7 gem colors (Bejeweled has 7). Icons come from the real items; the path is a fallback.
-- rgb is used for sparks, beams and the gem's glow.
ns.GEMS = {
    { name = "Star Ruby",          item = 7910,  icon = "Interface\\Icons\\INV_Misc_Gem_Ruby_02",     rgb = { 1.00, 0.20, 0.20 } },
    { name = "Black Pearl",        item = 7971,  icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_04",    rgb = { 0.72, 0.72, 0.85 } },
    { name = "Citrine",            item = 3864,  icon = "Interface\\Icons\\INV_Misc_Gem_Topaz_02",    rgb = { 1.00, 0.90, 0.20 } },
    { name = "Huge Emerald",       item = 12364, icon = "Interface\\Icons\\INV_Misc_Gem_Emerald_02",  rgb = { 0.25, 1.00, 0.35 } },
    { name = "Aquamarine",         item = 7909,  icon = "Interface\\Icons\\INV_Misc_Gem_Crystal_02",  rgb = { 0.30, 0.80, 1.00 } },
    { name = "Shadowgem",          item = 1210,  icon = "Interface\\Icons\\INV_Misc_Gem_Amethyst_01", rgb = { 0.75, 0.35, 1.00 } },
    { name = "Azerothian Diamond", item = 12800, icon = "Interface\\Icons\\INV_Misc_Gem_Diamond_01",  rgb = { 0.95, 0.95, 1.00 } },
}
ns.EMERALD = 4          -- Huge Emerald matches heal you
ns.HEAL_PER_EMERALD = 20 -- minimum heal per Huge Emerald

-- What each gem colour does when you match it (counted per match, not per gem; gems destroyed
-- by explosions or Hypercubes don't trigger these, except the Emerald heal).
-- Run buffs last until you die; their cap rises with every tide (cap x tide).
ns.GEM_BONUS = {
    emeraldHit = 0.15,                            -- each Huge Emerald heals 15% of the hit you'd take from the makrura
    [5] = { kind = "freeze", chance = 15 },       -- Aquamarine: its next attack comes 1 move later
    [6] = { kind = "dot", chance = 15, pct = 1, moves = 10 },   -- Shadowgem: 1% of its max health per move, 10 moves
    [3] = { kind = "gold", per = 2, cap = 50 },   -- Citrine: +2% gold, cap +50% per tide
    [7] = { kind = "dmg",  per = 1, cap = 25 },   -- Azerothian Diamond: +1% damage, cap +25% per tide
    [1] = { kind = "dr",   per = 1, cap = 10, max = 30 },  -- Star Ruby: -1% damage taken, cap 10% per tide, 30% at most
    [2] = { kind = "drop", per = 1, cap = 20 },   -- Black Pearl: +1% item drop chance, cap +20% per tide
}
ns.BUFF_INFO = {
    dmg    = { gem = 7, name = "Diamond Edge",    text = "+%d%% damage for the rest of the run" },
    dr     = { gem = 1, name = "Ruby Ward",       text = "%d%% less damage taken for the rest of the run" },
    gold   = { gem = 3, name = "Citrine Fortune", text = "+%d%% gold for the rest of the run" },
    drop   = { gem = 2, name = "Pearl Luck",      text = "+%d%% item drop chance for the rest of the run" },
    dot    = { icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", name = "Shadowgem Curse",
               text = "The makrura takes shadow damage every move (%d moves left)" },
    freeze = { icon = "Interface\\Icons\\Spell_Frost_FrostNova", name = "Frozen",
               text = "Aquamarine froze the makrura: its next attack comes a move later" },
}

ns.SPECIAL_INFO = {
    flame = { name = "Flame Gem", icon = "Interface\\Icons\\Spell_Fire_Fire",               rgb = { 1, 0.45, 0.1 }, how = "Match 4 in a line. Explodes the 3x3 around it." },
    star  = { name = "Star Gem",  icon = "Interface\\Icons\\Spell_Nature_Lightning",        rgb = { 0.6, 0.8, 1 },  how = "Match an L or T shape. Destroys its whole row and column." },
    hyper = { name = "Hypercube", icon = "Interface\\Icons\\INV_Enchant_ShardBrilliantLarge", rgb = { 1, 1, 1 },     how = "Match 5 in a line. Swap it with a gem to destroy every gem of that color." },
    nova  = { name = "Supernova", icon = "Interface\\Icons\\Spell_Holy_HolyNova",           rgb = { 1, 0.9, 0.5 },  how = "Match 6 in a line. Destroys 3 rows and 3 columns." },
}

-- Makrura, from Durotar to Tidefury Cove.
-- model: an NPC id used for the 3D model (all of them are makrura models).
-- every: the makrura attacks after this many of your moves.
-- trait: shell = plain 3-gem matches deal half damage
--        mend  = when it attacks, it heals 20% of the damage you dealt since its last attack
--        fast  = attacks one move sooner (already in `every`)
ns.ENEMIES = {
    { name = "Makrura Clacker",     level = 7,  zone = "Durotar",            hp = 800,  dmg = 50,  every = 4, model = 3103 },
    { name = "Makrura Shellhide",   level = 7,  zone = "Durotar",            hp = 1000, dmg = 60,  every = 4, model = 3104, trait = "shell" },
    { name = "Makrura Snapclaw",    level = 9,  zone = "Durotar",            hp = 1250, dmg = 60,  every = 3, model = 3103, trait = "fast" },
    { name = "Makrura Elder",       level = 9,  zone = "Durotar",            hp = 1550, dmg = 70,  every = 4, model = 3104, trait = "mend" },
    { name = "Slimeshell Makrura",  level = 19, zone = "The Barrens",        hp = 1950, dmg = 80,  every = 4, model = 3103 },
    { name = "Murkshallow Snapclaw",level = 22, zone = "Blackfathom Deeps",  hp = 2450, dmg = 80,  every = 3, model = 3104, trait = "fast" },
    { name = "Muckshell Clacker",   level = 36, zone = "Dustwallow Marsh",   hp = 3050, dmg = 100, every = 4, model = 4401 },
    { name = "Muckshell Razorclaw", level = 44, zone = "Dustwallow Marsh",   hp = 3800, dmg = 120, every = 4, model = 4401 },
    { name = "Diamond Head",        level = 45, zone = "Feralas",            hp = 4750, dmg = 120, every = 4, model = 4401, trait = "shell", rare = true },
    { name = "Lord Angler",         level = 44, zone = "Tidefury Cove",      hp = 5500, dmg = 110, every = 4, model = 4401, trait = "mend", boss = true, scale = 1.25 },
}

ns.TRAIT_TEXT = {
    shell = "Hard shell: plain 3-gem matches deal half damage",
    mend  = "Mending tide: heals 20% of your damage when it attacks",
    fast  = "Quick claws: attacks every 3 moves",
}

ns.ENRAGE_AFTER = 30        -- a fight longer than 30 moves (50 for bosses): the makrura enrages,
ns.ENRAGE_AFTER_BOSS = 50
ns.ENRAGE_PER_MOVE = 5      -- hitting 5% harder for every move after that
ns.MEND_PCT = 0.20         -- mending tide: share of your damage (since its last attack) it heals back
ns.PLAYER_HP = 1000
ns.HEAL_BETWEEN_WAVES = 250
ns.STAGGER_CASCADE = 3      -- a move with this many cascades (or more) delays the next attack by 1
ns.ENDLESS_HP = 2.2         -- after Lord Angler the tide starts again: health x2.2 and damage x1.6 per tide
ns.ENDLESS_DMG = 1.6
ns.ENEMY_HP_PER_LEVEL = 0.04     -- makrura get +4% health and +2.5% damage for each of your levels
ns.ENEMY_DMG_PER_LEVEL = 0.025

-- Enemy n of the run (endless after the last one)
function ns.GetEnemy(wave)
    local count = #ns.ENEMIES
    local tide = math.floor((wave - 1) / count) + 1
    local base = ns.ENEMIES[(wave - 1) % count + 1]
    local e = {}
    for k, v in pairs(base) do e[k] = v end
    e.tide = tide
    if tide > 1 then
        e.hp = math.floor(base.hp * ns.ENDLESS_HP ^ (tide - 1))
        e.dmg = math.floor(base.dmg * ns.ENDLESS_DMG ^ (tide - 1) + 0.5)
    end
    return e
end

---------------------------------------------------------------------------
-- Sounds and music: all from the game's own files (FileDataIDs, original 1.x files)
---------------------------------------------------------------------------
ns.SFX = {
    -- the makrura strikes you: unarmed melee and weapon impacts on flesh
    impact = {
        567927, 567922, 567921,         -- unarmed attack medium a/b/c
        567920, 567930, 567918,         -- unarmed attack large a/b/c
        567880, 567881, 567883,         -- 1h sword hit flesh
        567621, 567620, 567632,         -- 1h axe hit flesh
        567750, 567741, 567738,         -- 1h mace hit flesh
        567711, 567710, 567704,         -- dagger hit flesh
        567661, 567651, 567645,         -- 2h axe hit flesh
        567788, 567803, 567801,         -- 2h mace hit flesh
        567899, 567909, 567915,         -- 2h sword hit flesh
    },
    impactCrit = { 567925, 567926, 567668, 567787, 567894, 567619, 567878 },  -- critical hits
    mobAttack  = { 546433, 546424, 546429 },     -- crab attack a/b/c (makrura are crustaceans)
    mobWound   = { 546426, 546428, 546421 },     -- crab wound a/b/c
    mobWoundCrit = { 546422 },
    mobDeath   = { 546431 },
    mobAggro   = { 546423 },
    -- the board
    gemPickup  = { 567568 },                     -- picking up gems (bags)
    gemPutdown = { 567574 },                     -- putting gems down
    badMove    = { 567415 },                     -- interface error
    forged     = { 567455 },                     -- magic click: a special gem is made
    flame      = { 568461, 568429, 569449 },     -- fireball impact a/b/c
    star       = { 568516 },                     -- lightning bolt impact
    hyper      = { 568678 },                     -- arcane explosion
    nova       = { 568641 },                     -- flamestrike
    board      = { 569222 },                     -- thunder clap
    gameOver   = { 567940 },                     -- large weapon swing crit
    dodge      = { 567938, 567935 },             -- medium weapon swing (a miss)
    levelUp    = { 567431 },                     -- level up
    coins      = { 567428 },                     -- loot coins (small)
    coinsBig   = { 567413 },                     -- loot coins (large): selling, buying
    loot       = { 567550 },                     -- picking up loot (chain)
    equip      = { 567569 },                     -- putting down metal: equipping
    talent     = { 567524 },                     -- spell icon drop: learning a talent
    untalent   = { 567489 },                     -- spell icon pickup: removing a point
    freeze     = { 569378 },                     -- frost nova: Aquamarine freeze
    curse      = { 569138 },                     -- shadow word: pain on a target: Shadowgem curse
}

-- Inn music (sound/music/zonemusic/tavern*). Songs split in two parts play in order.
ns.INN_SONGS = {
    { 53737 }, { 53738 },                              -- Alliance inns
    { 53739, 53740 }, { 53741, 53742 }, { 53743 },     -- dwarven inns
    { 53744 }, { 53745 }, { 53746 }, { 53747 },        -- Horde inns (incl. the undead dance)
    { 53748, 53749 }, { 53750, 53751 }, { 53752, 53753 }, -- human inns
    { 53754, 53755 },                                  -- night elf inns
    { 53756, 53757 }, { 53758, 53759 }, { 53760, 53761 }, -- orc rest areas
    { 53762, 53763 }, { 53764, 53765 }, { 53766, 53767 }, -- pirate taverns
    { 53768, 53769 }, { 53770, 53771 }, { 53772, 53773 }, -- tauren rest areas
    { 53774, 53775 }, { 53776 }, { 53777, 53778 },     -- undead taverns
}
