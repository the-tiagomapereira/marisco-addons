local _, ns = ...

-- Leveling routes for WoW Forever.
-- Source: wow-professions.com (used with permission, credited in-game).
--
-- Each step: from/to skill, recipe made, number of crafts, reagents PER CRAFT.
--   route   = only for that route (steps without it apply to every route)
--   yield   = items made per craft (default 1)
--   makeAll = this step also makes enough of its item for later steps in the
--             chosen range (e.g. Tailoring bolts), instead of buying the rest
-- Items made earlier in the chosen range are subtracted from what you buy.

ns.GUIDE_SOURCE = "wow-professions.com"
ns.GUIDE_HOME = "https://www.wow-professions.com/forever"
-- When the guide data in this addon was copied, and for which game version.
ns.GUIDE_DATA = { date = "2026-10-12", gameVersion = "1.60.1", note = "WoW Forever beta" }
local BASE = "https://www.wow-professions.com/forever/"

-- Item IDs for icons / auction searches (names still drive everything; items
-- missing here are looked up from the materials catalog or learned in-game).
ns.GuideItemIds = {
    -- leather & hides
    ["Ruined Leather Scraps"] = 2934, ["Light Leather"] = 2318, ["Light Hide"] = 783,
    ["Medium Leather"] = 2319, ["Medium Hide"] = 4232, ["Heavy Leather"] = 4234,
    ["Heavy Hide"] = 4235, ["Thick Leather"] = 4304, ["Cured Light Hide"] = 4231,
    ["Cured Medium Hide"] = 4233, ["Cured Heavy Hide"] = 4236, ["Fine Leather Belt"] = 4246,
    -- cloth, bolts, thread, dye
    ["Linen Cloth"] = 2589, ["Wool Cloth"] = 2592, ["Silk Cloth"] = 4306,
    ["Mageweave Cloth"] = 4338, ["Runecloth"] = 14047,
    ["Bolt of Linen Cloth"] = 2996, ["Bolt of Woolen Cloth"] = 2997, ["Bolt of Silk Cloth"] = 4305,
    ["Bolt of Mageweave"] = 4339, ["Coarse Thread"] = 2320, ["Fine Thread"] = 2321,
    ["Silken Thread"] = 4291, ["Heavy Silken Thread"] = 8343, ["Gray Dye"] = 4340,
    ["Red Dye"] = 2604, ["Green Dye"] = 2605, ["Salt"] = 4289, ["Iron Buckle"] = 7071,
    -- stone, bars, flux
    ["Rough Stone"] = 2835, ["Coarse Stone"] = 2836, ["Heavy Stone"] = 2838,
    ["Solid Stone"] = 7912, ["Dense Stone"] = 12365,
    ["Copper Bar"] = 2840, ["Bronze Bar"] = 2841, ["Silver Bar"] = 2842, ["Iron Bar"] = 3575,
    ["Steel Bar"] = 3859, ["Mithril Bar"] = 3860, ["Thorium Bar"] = 12359,
    ["Weak Flux"] = 2880, ["Strong Flux"] = 3466,
    ["Rough Grinding Stone"] = 3470, ["Coarse Grinding Stone"] = 3478,
    ["Heavy Grinding Stone"] = 3486, ["Solid Grinding Stone"] = 7966,
    -- gems
    ["Moss Agate"] = 1206, ["Shadowgem"] = 1210, ["Iridescent Pearl"] = 5500,
    ["Black Pearl"] = 7971, ["Golden Pearl"] = 13926,
    -- engineering parts
    ["Rough Blasting Powder"] = 4357, ["Coarse Blasting Powder"] = 4364,
    ["Heavy Blasting Powder"] = 4377, ["Solid Blasting Powder"] = 10505,
    ["Handful of Copper Bolts"] = 4359, ["Bronze Tube"] = 4371, ["Whirring Bronze Gizmo"] = 4375,
    ["Bronze Framework"] = 4382, ["Mithril Casing"] = 10561, ["Unstable Trigger"] = 10560,
    -- enchanting
    ["Copper Rod"] = 6217, ["Silver Rod"] = 6338, ["Golden Rod"] = 11128,
    ["Truesilver Rod"] = 11144, ["Arcanite Rod"] = 16206,
    ["Strange Dust"] = 10940, ["Soul Dust"] = 11083, ["Vision Dust"] = 11137,
    ["Dream Dust"] = 11176, ["Illusion Dust"] = 16204,
    ["Lesser Magic Essence"] = 10938, ["Greater Astral Essence"] = 11082,
    ["Greater Mystic Essence"] = 11135, ["Greater Eternal Essence"] = 16203,
    ["Small Brilliant Shard"] = 14343, ["Large Brilliant Shard"] = 14344,
    ["Maple Seed"] = 17034, ["Stranglethorn Seed"] = 17035,
    -- herbs, vials, potions
    ["Peacebloom"] = 2447, ["Silverleaf"] = 765, ["Mageroyal"] = 785, ["Earthroot"] = 2449,
    ["Briarthorn"] = 2450, ["Stranglekelp"] = 3820, ["Kingsblood"] = 3356, ["Liferoot"] = 3357,
    ["Arthas' Tears"] = 8836, ["Sungrass"] = 8838, ["Blindweed"] = 8839,
    ["Golden Sansam"] = 13464, ["Purple Lotus"] = 8831,
    ["Empty Vial"] = 3371, ["Leaded Vial"] = 3372, ["Crystal Vial"] = 8925,
    ["Firefin Snapper"] = 6359, ["Fire Oil"] = 6371, ["Elixir of Wisdom"] = 3383,
    -- cooking
    ["Raw Brilliant Smallfish"] = 6291, ["Raw Longjaw Mud Snapper"] = 6289,
    ["Raw Bristle Whisker Catfish"] = 6308, ["Raw Mithril Head Trout"] = 8365,
    ["Raw Spotted Yellowtail"] = 4603, ["Giant Egg"] = 3685, ["Zesty Clam Meat"] = 7974,
    ["Mild Spices"] = 2678, ["Hot Spices"] = 2692, ["Soothing Spices"] = 3713,
}

local UNTESTED = "Based on the WoW Forever beta. The part above 225 is untested by the guide. "
    .. "Counts are estimates: some crafts may not give a skill point."

ns.LevelingGuides = {
    ---------------------------------------------------------------- Leatherworking
    ["Leatherworking"] = {
        url = BASE .. "leatherworking-leveling-guide",
        note = "Based on the WoW Forever beta. Covers 1-225 (225+ not tested by the guide yet). "
            .. "Counts are estimates: some crafts may not give a skill point.",
        routes = {
            { key = "heavyhide",   text = "With Heavy Hide (Cured Heavy Hide)" },
            { key = "noheavyhide", text = "Without Heavy Hide" },
        },
        steps = {
            { from = 1,   to = 30,  recipe = "Light Leather", crafts = 33,
              mats = { { "Ruined Leather Scraps", 3 } } },
            { from = 30,  to = 55,  recipe = "Cured Light Hide", crafts = 27,
              mats = { { "Light Hide", 1 }, { "Salt", 1 } } },
            { from = 55,  to = 75,  recipe = "Embossed Leather Gloves", crafts = 21,
              mats = { { "Light Leather", 3 }, { "Coarse Thread", 2 } } },
            { from = 75,  to = 80,  recipe = "Medium Leather", crafts = 8,
              mats = { { "Light Leather", 4 } } },
            { from = 80,  to = 90,  recipe = "Cured Medium Hide", crafts = 10,
              mats = { { "Medium Hide", 1 }, { "Salt", 1 } } },
            { from = 90,  to = 100, recipe = "Fine Leather Belt", crafts = 19,
              mats = { { "Light Leather", 6 }, { "Coarse Thread", 2 } } },
            { from = 100, to = 115, recipe = "Light Leather Pants", crafts = 24,
              mats = { { "Light Leather", 10 }, { "Cured Light Hide", 1 }, { "Fine Thread", 1 } } },
            { from = 115, to = 125, recipe = "Dark Leather Belt", crafts = 10,
              mats = { { "Fine Leather Belt", 1 }, { "Cured Medium Hide", 1 }, { "Fine Thread", 2 }, { "Gray Dye", 1 } } },
            { from = 125, to = 130, recipe = "Heavy Leather", crafts = 7,
              mats = { { "Medium Leather", 5 } } },
            { from = 130, to = 140, recipe = "Cured Heavy Hide", crafts = 20, route = "heavyhide",
              mats = { { "Heavy Hide", 1 }, { "Salt", 3 } } },
            { from = 140, to = 155, recipe = "Hillman's Leather Gloves", crafts = 20, route = "heavyhide",
              mats = { { "Medium Leather", 14 }, { "Fine Thread", 4 } } },
            { from = 155, to = 165, recipe = "Barbaric Shoulders", crafts = 10, route = "heavyhide",
              mats = { { "Heavy Leather", 8 }, { "Cured Heavy Hide", 1 }, { "Fine Thread", 2 } } },
            { from = 165, to = 175, recipe = "Guardian Gloves", crafts = 10, route = "heavyhide",
              mats = { { "Heavy Leather", 4 }, { "Cured Heavy Hide", 1 }, { "Silken Thread", 1 } } },
            { from = 130, to = 155, recipe = "Hillman's Leather Gloves", crafts = 30, route = "noheavyhide",
              mats = { { "Medium Leather", 14 }, { "Fine Thread", 4 } } },
            { from = 155, to = 170, recipe = "Barbaric Leggings", crafts = 17, route = "noheavyhide",
              mats = { { "Heavy Leather", 10 }, { "Fine Thread", 2 }, { "Moss Agate", 1 } } },
            { from = 170, to = 175, recipe = "Barbaric Harness", crafts = 5, route = "noheavyhide",
              mats = { { "Heavy Leather", 14 }, { "Fine Thread", 2 }, { "Iron Buckle", 1 } } },
            { from = 175, to = 195, recipe = "Guardian Gloves", crafts = 26,
              mats = { { "Heavy Leather", 4 }, { "Cured Heavy Hide", 1 }, { "Silken Thread", 1 } } },
            { from = 195, to = 210, recipe = "Nightscape Headband", crafts = 21,
              mats = { { "Thick Leather", 5 }, { "Silken Thread", 2 } } },
            { from = 210, to = 225, recipe = "Nightscape Pants", crafts = 15,
              mats = { { "Thick Leather", 14 }, { "Silken Thread", 4 } } },
        },
    },

    ---------------------------------------------------------------- Alchemy
    ["Alchemy"] = {
        url = BASE .. "alchemy-leveling-guide",
        note = "Based on the WoW Forever beta. Covers 1-290: the guide hasn't decided the last 10 points yet, "
            .. "and 225+ is untested. Counts are estimates.",
        routes = {
            { key = "fireoil", text = "Fire Oil + Elixir of Fire Power" },
            { key = "manapot", text = "Lesser Mana Potions" },
        },
        steps = {
            { from = 1,   to = 10,  recipe = "Minor Arcane Elixir", crafts = 9,
              mats = { { "Peacebloom", 1 }, { "Empty Vial", 1 } } },
            { from = 10,  to = 55,  recipe = "Elixir of Minor Defense", crafts = 45,
              mats = { { "Silverleaf", 1 }, { "Peacebloom", 1 }, { "Empty Vial", 1 } } },
            { from = 55,  to = 65,  recipe = "Minor Mana Potion", crafts = 10,
              mats = { { "Mageroyal", 1 }, { "Peacebloom", 1 }, { "Empty Vial", 1 } } },
            { from = 65,  to = 90,  recipe = "Elixir of Minor Fortitude", crafts = 27,
              mats = { { "Earthroot", 2 }, { "Peacebloom", 1 }, { "Empty Vial", 1 } } },
            { from = 90,  to = 120, recipe = "Elixir of Wisdom", crafts = 30,
              mats = { { "Mageroyal", 1 }, { "Briarthorn", 2 }, { "Empty Vial", 1 } } },
            { from = 120, to = 130, recipe = "Lesser Mana Potion", crafts = 10,
              mats = { { "Mageroyal", 1 }, { "Stranglekelp", 1 }, { "Empty Vial", 1 } } },
            { from = 130, to = 150, recipe = "Fire Oil", crafts = 20, yield = 2, route = "fireoil",
              mats = { { "Firefin Snapper", 2 }, { "Empty Vial", 1 } } },
            { from = 150, to = 165, recipe = "Elixir of Fire Power", crafts = 15, route = "fireoil",
              mats = { { "Fire Oil", 2 }, { "Kingsblood", 1 }, { "Leaded Vial", 1 } } },
            { from = 130, to = 150, recipe = "Lesser Mana Potion", crafts = 20, route = "manapot",
              mats = { { "Mageroyal", 1 }, { "Stranglekelp", 1 }, { "Empty Vial", 1 } } },
            { from = 150, to = 165, recipe = "Lesser Mana Potion", crafts = 22, route = "manapot",
              mats = { { "Mageroyal", 1 }, { "Stranglekelp", 1 }, { "Empty Vial", 1 } } },
            { from = 165, to = 195, recipe = "Mana Potion", crafts = 36,
              mats = { { "Stranglekelp", 1 }, { "Kingsblood", 1 }, { "Leaded Vial", 1 } } },
            { from = 195, to = 225, recipe = "Nature Protection Potion", crafts = 36,
              mats = { { "Liferoot", 1 }, { "Stranglekelp", 1 }, { "Leaded Vial", 1 } } },
            { from = 225, to = 230, recipe = "Nature Protection Potion", crafts = 12,
              mats = { { "Liferoot", 1 }, { "Stranglekelp", 1 }, { "Leaded Vial", 1 } } },
            { from = 230, to = 265, recipe = "Draught of Detect Undead", crafts = 45,
              mats = { { "Arthas' Tears", 1 }, { "Crystal Vial", 1 } } },
            { from = 265, to = 275, recipe = "Superior Mana Potion", crafts = 10,
              mats = { { "Sungrass", 2 }, { "Blindweed", 2 }, { "Crystal Vial", 1 } } },
            { from = 275, to = 290, recipe = "Superior Mana Potion", crafts = 20,
              mats = { { "Sungrass", 2 }, { "Blindweed", 2 }, { "Crystal Vial", 1 } } },
        },
    },

    ---------------------------------------------------------------- Blacksmithing
    ["Blacksmithing"] = {
        url = BASE .. "blacksmithing-leveling-guide",
        note = "Based on the WoW Forever beta. Covers 1-225 (225-300 can't be tested on the beta yet). "
            .. "Counts are estimates: some crafts may not give a skill point.",
        steps = {
            { from = 1,   to = 25,  recipe = "Rough Sharpening Stone", crafts = 30,
              mats = { { "Rough Stone", 1 } } },
            { from = 25,  to = 50,  recipe = "Rough Grinding Stone", crafts = 30,
              mats = { { "Rough Stone", 2 } } },
            { from = 50,  to = 67,  recipe = "Coarse Grinding Stone", crafts = 36,
              mats = { { "Coarse Stone", 2 } } },
            { from = 67,  to = 75,  recipe = "Runed Copper Gauntlets", crafts = 8,
              mats = { { "Copper Bar", 8 }, { "Rough Grinding Stone", 2 } } },
            { from = 75,  to = 80,  recipe = "Runed Copper Belt", crafts = 5,
              mats = { { "Copper Bar", 10 } } },
            { from = 80,  to = 95,  recipe = "Rough Bronze Leggings", crafts = 15,
              mats = { { "Bronze Bar", 6 } } },
            { from = 95,  to = 100, recipe = "Patterned Bronze Bracers", crafts = 5,
              mats = { { "Bronze Bar", 5 }, { "Coarse Grinding Stone", 2 } } },
            { from = 100, to = 112, recipe = "Heavy Grinding Stone", crafts = 20,
              mats = { { "Heavy Stone", 3 } } },
            { from = 112, to = 125, recipe = "Patterned Bronze Bracers", crafts = 13,
              mats = { { "Bronze Bar", 5 }, { "Coarse Grinding Stone", 2 } } },
            { from = 125, to = 140, recipe = "Bronze Shortsword", crafts = 24,
              mats = { { "Bronze Bar", 5 }, { "Weak Flux", 4 }, { "Medium Leather", 2 } } },
            { from = 140, to = 150, recipe = "Bronze Warhammer", crafts = 10,
              mats = { { "Bronze Bar", 8 }, { "Strong Flux", 1 }, { "Medium Leather", 1 } } },
            { from = 150, to = 165, recipe = "Bronze Warhammer", crafts = 19,
              mats = { { "Bronze Bar", 8 }, { "Strong Flux", 1 }, { "Medium Leather", 1 } } },
            { from = 165, to = 175, recipe = "Green Iron Bracers", crafts = 15,
              mats = { { "Iron Bar", 6 }, { "Green Dye", 1 } } },
            { from = 175, to = 185, recipe = "Solid Grinding Stone", crafts = 40,
              mats = { { "Solid Stone", 4 } } },
            { from = 185, to = 215, recipe = "Mithril Plate Pants", crafts = 36,
              mats = { { "Mithril Bar", 12 } } },
            { from = 215, to = 225, recipe = "Steel Plate Helm", crafts = 21,
              mats = { { "Steel Bar", 14 }, { "Solid Grinding Stone", 1 } } },
        },
    },

    ---------------------------------------------------------------- Enchanting
    ["Enchanting"] = {
        url = BASE .. "enchanting-leveling-guide",
        note = UNTESTED .. " Artisan (225+) is only trained by Annora in Uldaman.",
        routes = {
            { key = "essence", text = "Lesser Magic Essence" },
            { key = "dust",    text = "Strange Dust" },
        },
        steps = {
            { from = 1,   to = 2,   recipe = "Runed Copper Rod", crafts = 1,
              mats = { { "Copper Rod", 1 }, { "Mote of Magic", 1 } } },
            { from = 2,   to = 20,  recipe = "Enchant Bracer - Inferior Stamina", crafts = 18,
              mats = { { "Mote of Magic", 1 } } },
            -- Lesser Magic Essence route
            { from = 20,  to = 70,  recipe = "Enchant Bracer - Minor Deflect", crafts = 50, route = "essence",
              mats = { { "Lesser Magic Essence", 1 } } },
            { from = 70,  to = 100, recipe = "Enchant Chest - Minor Absorption", crafts = 33, route = "essence",
              mats = { { "Lesser Magic Essence", 1 } } },
            { from = 100, to = 109, recipe = "Enchant Chest - Minor Absorption", crafts = 18, route = "essence",
              mats = { { "Lesser Magic Essence", 1 } } },
            { from = 110, to = 130, recipe = "Enchant 2H Weapon - Lesser Intellect", crafts = 20, route = "essence",
              mats = { { "Lesser Magic Essence", 4 } } },
            { from = 130, to = 150, recipe = "Enchant 2H Weapon - Lesser Intellect", crafts = 32, route = "essence",
              mats = { { "Lesser Magic Essence", 4 } } },
            -- Strange Dust route
            { from = 20,  to = 70,  recipe = "Enchant Chest - Inferior Stamina", crafts = 50, route = "dust",
              mats = { { "Strange Dust", 1 } } },
            { from = 70,  to = 100, recipe = "Enchant Bracer - Minor Stamina", crafts = 30, route = "dust",
              mats = { { "Strange Dust", 2 } } },
            { from = 100, to = 109, recipe = "Enchant Cloak - Minor Protection", crafts = 9, route = "dust",
              mats = { { "Strange Dust", 2 } } },
            { from = 110, to = 130, recipe = "Enchant Cloak - Minor Protection", crafts = 32, route = "dust",
              mats = { { "Strange Dust", 2 } } },
            { from = 130, to = 150, recipe = "Enchant Boots - Minor Stamina", crafts = 20, route = "dust",
              mats = { { "Strange Dust", 4 } } },
            -- both routes
            { from = 109, to = 110, recipe = "Runed Silver Rod", crafts = 1,
              mats = { { "Silver Rod", 1 }, { "Strange Dust", 3 }, { "Lesser Magic Essence", 4 }, { "Shadowgem", 1 } } },
            { from = 150, to = 151, recipe = "Runed Golden Rod", crafts = 1,
              mats = { { "Golden Rod", 1 }, { "Iridescent Pearl", 1 }, { "Greater Astral Essence", 1 }, { "Soul Dust", 1 } } },
            { from = 151, to = 165, recipe = "Minor Mana Oil", crafts = 16,
              mats = { { "Soul Dust", 1 }, { "Maple Seed", 2 }, { "Leaded Vial", 1 } } },
            { from = 165, to = 185, recipe = "Enchant Boots - Lesser Agility", crafts = 22,
              mats = { { "Soul Dust", 1 } } },
            { from = 185, to = 200, recipe = "Enchant Bracer - Strength", crafts = 15,
              mats = { { "Vision Dust", 1 } } },
            { from = 200, to = 201, recipe = "Runed Truesilver Rod", crafts = 1,
              mats = { { "Truesilver Rod", 1 }, { "Black Pearl", 1 }, { "Greater Mystic Essence", 1 }, { "Vision Dust", 1 } } },
            { from = 201, to = 220, recipe = "Lesser Wizard Oil", crafts = 25,
              mats = { { "Vision Dust", 1 }, { "Stranglethorn Seed", 2 }, { "Leaded Vial", 1 } } },
            { from = 220, to = 225, recipe = "Enchant Cloak - Greater Defense", crafts = 5,
              mats = { { "Vision Dust", 1 } } },
            { from = 225, to = 230, recipe = "Enchant Gloves - Agility", crafts = 5,
              mats = { { "Vision Dust", 1 } } },
            { from = 230, to = 235, recipe = "Enchant Boots - Stamina", crafts = 5,
              mats = { { "Vision Dust", 2 } } },
            { from = 235, to = 250, recipe = "Enchant Chest - Superior Stamina", crafts = 20,
              mats = { { "Vision Dust", 3 } } },
            { from = 250, to = 265, recipe = "Lesser Mana Oil", crafts = 20,
              mats = { { "Dream Dust", 1 }, { "Purple Lotus", 1 }, { "Crystal Vial", 1 } } },
            { from = 265, to = 294, recipe = "Enchant Shield - Greater Stamina", crafts = 32,
              mats = { { "Dream Dust", 6 } } },
            { from = 294, to = 295, recipe = "Runed Arcanite Rod", crafts = 1,
              mats = { { "Arcanite Rod", 1 }, { "Golden Pearl", 1 }, { "Illusion Dust", 10 },
                       { "Greater Eternal Essence", 4 }, { "Small Brilliant Shard", 4 }, { "Large Brilliant Shard", 2 } } },
            { from = 295, to = 300, recipe = "Enchant Cloak - Superior Defense", crafts = 5,
              mats = { { "Illusion Dust", 8 } } },
        },
    },

    ---------------------------------------------------------------- Engineering
    ["Engineering"] = {
        url = BASE .. "engineering-leveling-guide",
        note = UNTESTED .. " Choose Gnomish or Goblin Engineering at 200.",
        steps = {
            { from = 1,   to = 30,  recipe = "Rough Blasting Powder", crafts = 60,
              mats = { { "Rough Stone", 1 } } },
            { from = 30,  to = 50,  recipe = "Handful of Copper Bolts", crafts = 30,
              mats = { { "Copper Bar", 1 } } },
            { from = 50,  to = 51,  recipe = "Arclight Spanner", crafts = 1,
              mats = { { "Copper Bar", 6 } } },
            { from = 51,  to = 75,  recipe = "Rough Copper Bomb", crafts = 30,
              mats = { { "Copper Bar", 1 }, { "Handful of Copper Bolts", 1 }, { "Rough Blasting Powder", 2 }, { "Linen Cloth", 1 } } },
            { from = 75,  to = 90,  recipe = "Coarse Blasting Powder", crafts = 60,
              mats = { { "Coarse Stone", 1 } } },
            { from = 90,  to = 100, recipe = "Coarse Dynamite", crafts = 20,
              mats = { { "Coarse Blasting Powder", 3 }, { "Linen Cloth", 1 } } },
            { from = 100, to = 105, recipe = "Silver Contact", crafts = 5,
              mats = { { "Silver Bar", 1 } } },
            { from = 105, to = 125, recipe = "Bronze Tube", crafts = 25,
              mats = { { "Bronze Bar", 2 }, { "Weak Flux", 1 } } },
            { from = 125, to = 135, recipe = "Standard Scope", crafts = 10,
              mats = { { "Bronze Tube", 1 }, { "Moss Agate", 1 } } },
            { from = 135, to = 150, recipe = "Heavy Blasting Powder", crafts = 30,
              mats = { { "Heavy Stone", 1 } } },
            { from = 135, to = 150, recipe = "Whirring Bronze Gizmo", crafts = 15,
              mats = { { "Bronze Bar", 2 }, { "Wool Cloth", 1 } } },
            { from = 150, to = 160, recipe = "Bronze Framework", crafts = 15,
              mats = { { "Bronze Bar", 2 }, { "Medium Leather", 1 }, { "Wool Cloth", 1 } } },
            { from = 160, to = 175, recipe = "Explosive Sheep", crafts = 15,
              mats = { { "Heavy Blasting Powder", 2 }, { "Whirring Bronze Gizmo", 1 }, { "Bronze Framework", 1 }, { "Wool Cloth", 2 } } },
            { from = 175, to = 194, recipe = "Solid Blasting Powder", crafts = 60,
              mats = { { "Solid Stone", 2 } } },
            { from = 194, to = 195, recipe = "Gyromatic Micro-Adjustor", crafts = 1,
              mats = { { "Steel Bar", 4 } } },
            { from = 195, to = 200, recipe = "Mithril Tube", crafts = 6,
              mats = { { "Mithril Bar", 3 } } },
            { from = 200, to = 215, recipe = "Unstable Trigger", crafts = 20,
              mats = { { "Mithril Bar", 1 }, { "Mageweave Cloth", 1 }, { "Solid Blasting Powder", 1 } } },
            { from = 215, to = 238, recipe = "Mithril Casing", crafts = 40,
              mats = { { "Mithril Bar", 3 } } },
            { from = 238, to = 250, recipe = "Hi-Explosive Bomb", crafts = 20,
              mats = { { "Mithril Casing", 2 }, { "Unstable Trigger", 1 }, { "Solid Blasting Powder", 2 } } },
            { from = 250, to = 260, recipe = "Dense Blasting Powder", crafts = 30,
              mats = { { "Dense Stone", 2 } } },
            { from = 260, to = 285, recipe = "Thorium Widget", crafts = 35,
              mats = { { "Thorium Bar", 3 }, { "Runecloth", 1 } } },
            { from = 285, to = 300, recipe = "Thorium Tube", crafts = 20,
              mats = { { "Thorium Bar", 6 } } },
        },
    },

    ---------------------------------------------------------------- Tailoring
    ["Tailoring"] = {
        url = BASE .. "tailoring-leveling-guide",
        note = "Based on the WoW Forever beta. Covers 1-225 (225-300 not posted yet). "
            .. "Bolts are crafted from cloth for the later steps too. Counts are estimates.",
        steps = {
            { from = 1,   to = 30,  recipe = "Bolt of Linen Cloth", crafts = 30, makeAll = true,
              mats = { { "Linen Cloth", 2 } } },
            { from = 30,  to = 55,  recipe = "Linen Belt", crafts = 28,
              mats = { { "Bolt of Linen Cloth", 1 }, { "Coarse Thread", 1 } } },
            { from = 55,  to = 80,  recipe = "Bolt of Woolen Cloth", crafts = 45, makeAll = true,
              mats = { { "Wool Cloth", 3 } } },
            { from = 80,  to = 95,  recipe = "Woolen Cape", crafts = 22,
              mats = { { "Bolt of Woolen Cloth", 1 }, { "Fine Thread", 1 } } },
            { from = 95,  to = 100, recipe = "Double-stitched Woolen Shoulders", crafts = 5,
              mats = { { "Bolt of Woolen Cloth", 3 }, { "Fine Thread", 2 } } },
            { from = 100, to = 120, recipe = "Bolt of Silk Cloth", crafts = 40, makeAll = true,
              mats = { { "Silk Cloth", 4 } } },
            { from = 120, to = 125, recipe = "Double-stitched Woolen Shoulders", crafts = 8,
              mats = { { "Bolt of Woolen Cloth", 3 }, { "Fine Thread", 2 } } },
            { from = 125, to = 140, recipe = "Gloves of Meditation", crafts = 20,
              mats = { { "Bolt of Woolen Cloth", 4 }, { "Fine Thread", 3 }, { "Elixir of Wisdom", 1 } } },
            { from = 140, to = 150, recipe = "Bolt of Mageweave", crafts = 17, makeAll = true,
              mats = { { "Mageweave Cloth", 5 } } },
            { from = 150, to = 170, recipe = "Crimson Silk Vest", crafts = 20,
              mats = { { "Bolt of Silk Cloth", 4 }, { "Red Dye", 2 }, { "Fine Thread", 2 } } },
            { from = 170, to = 190, recipe = "Crimson Silk Pantaloons", crafts = 24,
              mats = { { "Bolt of Silk Cloth", 4 }, { "Red Dye", 2 }, { "Silken Thread", 2 } } },
            { from = 190, to = 215, recipe = "Black Mageweave Gloves", crafts = 38,
              mats = { { "Bolt of Mageweave", 2 }, { "Heavy Silken Thread", 2 } } },
            { from = 215, to = 225, recipe = "Mageweave Bag", crafts = 26,
              mats = { { "Bolt of Mageweave", 4 }, { "Silken Thread", 2 } } },
        },
    },

    ---------------------------------------------------------------- First Aid
    ["First Aid"] = {
        url = BASE .. "first-aid-leveling-guide",
        note = UNTESTED .. " Expert needs 'Expert First Aid - Under Wraps' at 125; 225 needs the Triage quest.",
        routes = {
            { key = "bandages", text = "Bandages (Linen Cloth)" },
            { key = "potions",  text = "Healing Potions (herbs)" },
        },
        steps = {
            { from = 1,   to = 40,  recipe = "Linen Bandage", crafts = 50, route = "bandages",
              mats = { { "Linen Cloth", 1 } } },
            { from = 40,  to = 75,  recipe = "Heavy Linen Bandage", crafts = 40, route = "bandages",
              mats = { { "Linen Cloth", 2 } } },
            { from = 1,   to = 75,  recipe = "Minor Healing Potion", crafts = 81, route = "potions",
              mats = { { "Peacebloom", 1 }, { "Mild Spices", 1 }, { "Empty Vial", 1 } } },
            { from = 75,  to = 80,  recipe = "Heavy Linen Bandage", crafts = 12,
              mats = { { "Linen Cloth", 2 } } },
            { from = 80,  to = 115, recipe = "Wool Bandage", crafts = 50,
              mats = { { "Wool Cloth", 1 } } },
            { from = 115, to = 150, recipe = "Heavy Wool Bandage", crafts = 50,
              mats = { { "Wool Cloth", 2 } } },
            { from = 150, to = 180, recipe = "Silk Bandage", crafts = 42,
              mats = { { "Silk Cloth", 1 } } },
            { from = 180, to = 210, recipe = "Heavy Silk Bandage", crafts = 46,
              mats = { { "Silk Cloth", 2 } } },
            { from = 210, to = 225, recipe = "Mageweave Bandage", crafts = 17,
              mats = { { "Mageweave Cloth", 1 } } },
            { from = 225, to = 240, recipe = "Superior Healing Potion", crafts = 16,
              mats = { { "Sungrass", 1 }, { "Soothing Spices", 1 }, { "Crystal Vial", 1 } } },
            { from = 240, to = 260, recipe = "Heavy Mageweave Bandage", crafts = 30,
              mats = { { "Mageweave Cloth", 2 } } },
            { from = 260, to = 275, recipe = "Runecloth Bandage", crafts = 20,
              mats = { { "Runecloth", 1 } } },
            { from = 275, to = 300, recipe = "Major Healing Potion", crafts = 30,
              mats = { { "Golden Sansam", 1 }, { "Soothing Spices", 3 }, { "Crystal Vial", 1 } } },
        },
    },

    ---------------------------------------------------------------- Cooking
    ["Cooking"] = {
        url = BASE .. "cooking-leveling-guide",
        note = UNTESTED .. " Needs the Expert Cookbook at 125 and the Clamlette Surprise quest at 225. "
            .. "The guide lists many alternative recipes per range; this uses the first one.",
        steps = {
            { from = 1,   to = 50,  recipe = "Brilliant Smallfish", crafts = 55,
              mats = { { "Raw Brilliant Smallfish", 1 } } },
            { from = 50,  to = 100, recipe = "Longjaw Mud Snapper", crafts = 55,
              mats = { { "Raw Longjaw Mud Snapper", 1 } } },
            { from = 100, to = 130, recipe = "Bristle Whisker Catfish", crafts = 30,
              mats = { { "Raw Bristle Whisker Catfish", 1 } } },
            { from = 130, to = 150, recipe = "Bristle Whisker Catfish", crafts = 25,
              mats = { { "Raw Bristle Whisker Catfish", 1 } } },
            { from = 150, to = 175, recipe = "Curiously Tasty Omelet", crafts = 25,
              mats = { { "Raptor Egg", 1 }, { "Hot Spices", 1 } } },
            { from = 175, to = 225, recipe = "Mithril Headed Trout", crafts = 50,
              mats = { { "Raw Mithril Head Trout", 1 } } },
            { from = 225, to = 225, recipe = "Clamlette Surprise (Artisan quest)", crafts = 1,
              mats = { { "Giant Egg", 12 }, { "Zesty Clam Meat", 10 }, { "Alterac Swiss", 20 } } },
            { from = 225, to = 275, recipe = "Spotted Yellowtail", crafts = 65,
              mats = { { "Raw Spotted Yellowtail", 1 } } },
            { from = 275, to = 300, recipe = "Poached Sunscale Salmon", crafts = 35,
              mats = { { "Raw Sunscale Salmon", 1 } } },
        },
    },
}

---------------------------------------------------------------------------
-- Plan calculation
---------------------------------------------------------------------------
local function StepApplies(step, route)
    return step.route == nil or step.route == route
end

-- Sorted skill breakpoints for a guide + route.
function ns:GetGuideBreakpoints(guide, route)
    local seen, out = {}, {}
    for _, st in ipairs(guide.steps) do
        if StepApplies(st, route) then
            for _, v in ipairs({ st.from, st.to }) do
                if not seen[v] then seen[v] = true; out[#out + 1] = v end
            end
        end
    end
    table.sort(out)
    return out
end

-- Lowest and highest skill a guide covers (for the profession grid).
function ns:GetGuideRange(guide)
    local lo, hi
    for _, st in ipairs(guide.steps) do
        if not lo or st.from < lo then lo = st.from end
        if not hi or st.to > hi then hi = st.to end
    end
    return lo, hi
end

-- Returns steps (in order, with final craft counts) and the net materials to
-- buy for skill range [from, to].
function ns:ComputePlan(guide, route, from, to)
    local steps = {}
    for _, st in ipairs(guide.steps) do
        if StepApplies(st, route) and st.from >= from and st.to <= to then
            local copy = {}
            for k, v in pairs(st) do copy[k] = v end
            steps[#steps + 1] = copy
        end
    end
    table.sort(steps, function(a, b)
        if a.from ~= b.from then return a.from < b.from end
        return a.to < b.to
    end)

    -- makeAll steps also craft what later steps in the range will use
    for i = #steps, 1, -1 do
        local st = steps[i]
        if st.makeAll then
            local demand = 0
            for j = i + 1, #steps do
                for _, m in ipairs(steps[j].mats) do
                    if m[1] == st.recipe then demand = demand + m[2] * steps[j].crafts end
                end
            end
            local needCrafts = math.ceil(demand / (st.yield or 1))
            if needCrafts > st.crafts then st.crafts = needCrafts end
        end
    end

    local needed, produced, order = {}, {}, {}
    for _, st in ipairs(steps) do
        for _, m in ipairs(st.mats) do
            local name, per = m[1], m[2]
            if not needed[name] then needed[name] = 0; order[#order + 1] = name end
            needed[name] = needed[name] + per * st.crafts
        end
        produced[st.recipe] = (produced[st.recipe] or 0) + st.crafts * (st.yield or 1)
    end
    local mats = {}
    for _, name in ipairs(order) do
        local qty = needed[name] - (produced[name] or 0)
        if qty > 0 then
            mats[#mats + 1] = { name = name, id = ns:FindItemId(name), qty = qty }
        end
    end
    table.sort(mats, function(a, b) return a.name:lower() < b.name:lower() end)
    return steps, mats
end

-- Compares every guide's recipes with the recipes the game showed in your
-- profession windows. Returns a report table.
function ns:CheckGuides()
    local version, build = GetBuildInfo()
    local report = {
        version = version, build = build,
        versionMatches = (version == ns.GUIDE_DATA.gameVersion),
        professions = {},
    }
    local names = {}
    for prof in pairs(ns.LevelingGuides) do names[#names + 1] = prof end
    table.sort(names)
    for _, prof in ipairs(names) do
        local guide = ns.LevelingGuides[prof]
        local snap = ns.db.recipeSnapshot[prof]
        local r = { name = prof, checked = 0, unknown = 0, changes = {}, snap = snap }
        if snap then
            local seen = {}
            for _, st in ipairs(guide.steps) do
                if not seen[st.recipe] then
                    seen[st.recipe] = true
                    local game = snap.recipes[st.recipe]
                    if game then
                        r.checked = r.checked + 1
                        -- compare reagents both ways
                        local diffs = {}
                        local guideMats = {}
                        for _, m in ipairs(st.mats) do
                            guideMats[m[1]] = m[2]
                            local g = game[m[1]]
                            if g == nil then
                                diffs[#diffs + 1] = m[1] .. " x" .. m[2] .. " is no longer used"
                            elseif g ~= m[2] then
                                diffs[#diffs + 1] = m[1] .. ": guide x" .. m[2] .. ", game x" .. g
                            end
                        end
                        for reagent, count in pairs(game) do
                            if guideMats[reagent] == nil then
                                diffs[#diffs + 1] = "new reagent: " .. reagent .. " x" .. count
                            end
                        end
                        if #diffs > 0 then
                            r.changes[#r.changes + 1] = { recipe = st.recipe, diffs = diffs }
                        end
                    else
                        r.unknown = r.unknown + 1
                    end
                end
            end
        end
        report.professions[#report.professions + 1] = r
    end
    return report
end

-- Look up an item ID by name from the guide table, learned data and the catalog.
function ns:FindItemId(name)
    if ns.GuideItemIds[name] then return ns.GuideItemIds[name] end
    local k = ns.Key(name)
    for _, learned in pairs(ns.db.learned) do
        if learned[k] and learned[k].id then return learned[k].id end
    end
    for _, list in pairs(ns.BaseMaterials) do
        for _, e in ipairs(list) do
            if e[1] == name and e[2] then return e[2] end
        end
    end
end
