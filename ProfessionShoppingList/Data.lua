local _, ns = ...

-- Built-in material catalog (vanilla-era baseline, English names).
-- Format: { "Item Name", itemID }  -- itemID is optional and only used for icons/tooltips.
-- Names drive everything else (sorting, matching auction results).
--
-- WoW Forever adds many new recipes. Open your profession window in-game and the
-- addon reads every reagent from it and merges them into these lists automatically.

ns.BaseMaterials = {
    ["Alchemy"] = {
        {"Arcane Crystal", 12363}, {"Arthas' Tears", 8836}, {"Black Lotus", 13468},
        {"Black Vitriol", 9262}, {"Blackmouth Oil", 6370}, {"Blindweed", 8839},
        {"Briarthorn", 2450}, {"Bruiseweed", 2453}, {"Crystal Vial", 8925},
        {"Dreamfoil", 13463}, {"Earthroot", 2449}, {"Elemental Air", 7069},
        {"Elemental Earth", 7067}, {"Elemental Fire", 7068}, {"Elemental Water", 7070},
        {"Empty Vial", 3371}, {"Essence of Air", 7082}, {"Essence of Earth", 7076},
        {"Essence of Fire", 7078}, {"Essence of Undeath", 12808}, {"Essence of Water", 7080},
        {"Fadeleaf", 3818}, {"Fire Oil", 6371}, {"Firebloom", 4625},
        {"Firefin Snapper", 6359}, {"Ghost Mushroom", 8845}, {"Golden Sansam", 13464},
        {"Goldthorn", 3821}, {"Grave Moss", 3369}, {"Gromsblood", 8846},
        {"Icecap", 13467}, {"Imbued Vial", 18256}, {"Iron Bar", 3575},
        {"Khadgar's Whisker", 3358}, {"Kingsblood", 3356}, {"Large Venom Sac", 1288},
        {"Leaded Vial", 3372}, {"Liferoot", 3357}, {"Living Essence", 12803},
        {"Mageroyal", 785}, {"Mithril Bar", 3860}, {"Mountain Silversage", 13465},
        {"Oily Blackmouth", 6358}, {"Peacebloom", 2447}, {"Plaguebloom", 13466},
        {"Purple Lotus", 8831}, {"Silverleaf", 765}, {"Small Venom Sac", 1475},
        {"Stranglekelp", 3820}, {"Sungrass", 8838}, {"Swiftthistle", 2452},
        {"Thorium Bar", 12359}, {"Wild Steelbloom", 3355}, {"Wintersbite", 3819},
    },
    ["Blacksmithing"] = {
        {"Aquamarine", 7909}, {"Arcanite Bar", 12360}, {"Azerothian Diamond", 12800},
        {"Blue Sapphire", 12361}, {"Bronze Bar", 2841}, {"Citrine", 3864},
        {"Coarse Grinding Stone", 3478}, {"Coarse Stone", 2836}, {"Copper Bar", 2840},
        {"Core of Earth", 7075}, {"Dark Iron Bar", 11371}, {"Dense Grinding Stone", 12644},
        {"Dense Stone", 12365}, {"Elemental Earth", 7067}, {"Elemental Fire", 7068},
        {"Enchanted Thorium Bar", 12655}, {"Essence of Earth", 7076}, {"Essence of Fire", 7078},
        {"Gold Bar", 3577}, {"Green Dye", 2605}, {"Heart of Fire", 7077},
        {"Heavy Grinding Stone", 3486}, {"Heavy Leather", 4234}, {"Heavy Stone", 2838},
        {"Huge Emerald", 12364}, {"Iron Bar", 3575}, {"Jade", 1529},
        {"Large Opal", 12799}, {"Lesser Moonstone", 1705}, {"Light Leather", 2318},
        {"Linen Cloth", 2589}, {"Mageweave Cloth", 4338}, {"Malachite", 774},
        {"Medium Leather", 2319}, {"Mithril Bar", 3860}, {"Moss Agate", 1206},
        {"Rough Grinding Stone", 3470}, {"Rough Stone", 2835}, {"Rugged Leather", 8170},
        {"Runecloth", 14047}, {"Shadowgem", 1210}, {"Silk Cloth", 4306},
        {"Silver Bar", 2842}, {"Solid Grinding Stone", 7966}, {"Solid Stone", 7912},
        {"Star Ruby", 7910}, {"Steel Bar", 3859}, {"Strong Flux", 3466},
        {"Thick Leather", 4304}, {"Thorium Bar", 12359}, {"Tigerseye", 818},
        {"Truesilver Bar", 6037}, {"Weak Flux", 2880}, {"Wool Cloth", 2592},
    },
    ["Cooking"] = {
        {"Bear Meat", 3173}, {"Big Bear Meat", 3730}, {"Boar Intestines", 3172},
        {"Boar Ribs", 2677}, {"Chunk of Boar Meat", 769}, {"Clam Meat", 5503},
        {"Crawler Claw", 2675}, {"Crawler Meat", 2674}, {"Crocolisk Meat", 2924},
        {"Giant Egg", 3685}, {"Goretusk Liver", 723}, {"Hot Spices", 2692},
        {"Lion Meat", 3731}, {"Mild Spices", 2678}, {"Mystery Meat", 12037},
        {"Raptor Flesh", 12184}, {"Raw Brilliant Smallfish", 6291},
        {"Raw Bristle Whisker Catfish", 6308}, {"Raw Longjaw Mud Snapper", 6289},
        {"Raw Mithril Head Trout", 8365}, {"Raw Nightfin Snapper"},
        {"Raw Rainbow Fin Albacore", 6361}, {"Raw Redgill"}, {"Raw Rockscale Cod", 6362},
        {"Raw Slitherskin Mackerel", 6303}, {"Raw Spotted Yellowtail", 4603},
        {"Raw Sunscale Salmon"}, {"Raw Whitescale Salmon", 13889}, {"Red Wolf Meat", 12203},
        {"Refreshing Spring Water", 159}, {"Small Egg", 6889}, {"Soothing Spices", 3713},
        {"Stringy Wolf Meat", 2672}, {"Tangy Clam Meat", 5504}, {"Tender Crocolisk Meat", 3667},
        {"Tender Wolf Meat", 12208}, {"White Spider Meat", 12205}, {"Zesty Clam Meat", 7974},
    },
    ["Enchanting"] = {
        {"Arcanite Rod", 16206}, {"Copper Rod", 6217}, {"Dream Dust", 11176},
        {"Golden Rod", 11128}, {"Greater Astral Essence", 11082}, {"Greater Eternal Essence", 16203},
        {"Greater Magic Essence", 10939}, {"Greater Mystic Essence", 11135},
        {"Greater Nether Essence", 11175}, {"Illusion Dust", 16204},
        {"Large Brilliant Shard", 14344}, {"Large Glimmering Shard", 11084},
        {"Large Glowing Shard", 11139}, {"Large Radiant Shard", 11178},
        {"Lesser Astral Essence", 10998}, {"Lesser Eternal Essence", 16202},
        {"Lesser Magic Essence", 10938}, {"Lesser Mystic Essence", 11134},
        {"Lesser Nether Essence", 11174}, {"Living Essence", 12803}, {"Nexus Crystal", 20725},
        {"Righteous Orb", 12811}, {"Silver Rod", 6338}, {"Simple Wood", 4470},
        {"Small Brilliant Shard", 14343}, {"Small Glimmering Shard", 10978},
        {"Small Glowing Shard", 11138}, {"Small Radiant Shard", 11177},
        {"Soul Dust", 11083}, {"Strange Dust", 10940}, {"Truesilver Rod", 11144},
        {"Vision Dust", 11137},
    },
    ["Engineering"] = {
        {"Arcanite Bar", 12360}, {"Bronze Bar", 2841}, {"Bronze Framework", 4382},
        {"Bronze Tube", 4371}, {"Citrine", 3864}, {"Coarse Blasting Powder", 4364},
        {"Coarse Stone", 2836}, {"Copper Bar", 2840}, {"Copper Modulator", 4363},
        {"Copper Tube", 4361}, {"Core of Earth", 7075}, {"Dense Blasting Powder", 15992},
        {"Dense Stone", 12365}, {"Elemental Earth", 7067}, {"Elemental Fire", 7068},
        {"Essence of Earth", 7076}, {"Essence of Fire", 7078}, {"Fused Wiring", 7191},
        {"Gold Bar", 3577}, {"Gold Power Core", 10558}, {"Gyrochronatom", 4389},
        {"Handful of Copper Bolts", 4359}, {"Heart of Fire", 7077},
        {"Heavy Blasting Powder", 4377}, {"Heavy Leather", 4234}, {"Heavy Stone", 2838},
        {"Iron Bar", 3575}, {"Iron Strut", 4387}, {"Jade", 1529},
        {"Lesser Moonstone", 1705}, {"Light Leather", 2318}, {"Linen Cloth", 2589},
        {"Mageweave Cloth", 4338}, {"Malachite", 774}, {"Medium Leather", 2319},
        {"Mithril Bar", 3860}, {"Mithril Casing", 10561}, {"Mithril Tube", 10559},
        {"Moss Agate", 1206}, {"Rough Blasting Powder", 4357}, {"Rough Stone", 2835},
        {"Rugged Leather", 8170}, {"Runecloth", 14047}, {"Shadowgem", 1210},
        {"Silk Cloth", 4306}, {"Silver Bar", 2842}, {"Silver Contact", 4404},
        {"Solid Blasting Powder", 10505}, {"Solid Stone", 7912}, {"Star Ruby", 7910},
        {"Steel Bar", 3859}, {"Thick Leather", 4304}, {"Thorium Bar", 12359},
        {"Thorium Tube", 16000}, {"Thorium Widget", 15994}, {"Tigerseye", 818},
        {"Truesilver Bar", 6037}, {"Unstable Trigger", 10560},
        {"Whirring Bronze Gizmo", 4375}, {"Wool Cloth", 2592},
    },
    ["First Aid"] = {
        {"Large Venom Sac", 1288}, {"Linen Cloth", 2589}, {"Mageweave Cloth", 4338},
        {"Runecloth", 14047}, {"Silk Cloth", 4306}, {"Small Venom Sac", 1475},
        {"Wool Cloth", 2592},
    },
    ["Leatherworking"] = {
        {"Black Dye", 2325}, {"Black Whelp Scale", 7286}, {"Blue Dye", 6260},
        {"Bolt of Mageweave", 4339}, {"Bolt of Silk Cloth", 4305}, {"Chimera Leather", 15423},
        {"Coarse Thread", 2320}, {"Cured Heavy Hide", 4236}, {"Cured Light Hide", 4231},
        {"Cured Medium Hide", 4233}, {"Cured Rugged Hide", 15407}, {"Cured Thick Hide", 8172},
        {"Deviate Scale", 6470}, {"Devilsaur Leather", 15417}, {"Elemental Earth", 7067},
        {"Elemental Water", 7070}, {"Enchanted Leather", 12810}, {"Essence of Water", 7080},
        {"Fine Thread", 2321}, {"Frostsaber Leather", 15422}, {"Gray Dye", 4340},
        {"Green Dye", 2605}, {"Green Whelp Scale", 7392}, {"Heart of the Wild", 10286},
        {"Heavy Hide", 4235}, {"Heavy Leather", 4234}, {"Heavy Silken Thread", 8343},
        {"Iron Buckle", 7071}, {"Ironfeather", 15420}, {"Light Hide", 783},
        {"Light Leather", 2318}, {"Linen Cloth", 2589}, {"Living Essence", 12803},
        {"Mageweave Cloth", 4338}, {"Medium Hide", 4232}, {"Medium Leather", 2319},
        {"Perfect Deviate Scale", 6471}, {"Raptor Hide", 4461}, {"Red Whelp Scale", 7287},
        {"Refined Deeprock Salt", 15409}, {"Rugged Hide", 8171}, {"Rugged Leather", 8170},
        {"Ruined Leather Scraps", 2934}, {"Rune Thread", 14341}, {"Runecloth", 14047},
        {"Salt", 4289}, {"Scorpid Scale", 8154}, {"Silk Cloth", 4306},
        {"Silken Thread", 4291}, {"Thick Hide", 8169}, {"Thick Leather", 4304},
        {"Thick Wolfhide", 8368}, {"Turtle Scale", 8167}, {"Warbear Leather", 15419},
        {"Wool Cloth", 2592}, {"Worn Dragonscale", 8165},
    },
    ["Mining"] = {
        {"Coal", 3857}, {"Copper Bar", 2840}, {"Copper Ore", 2770}, {"Dark Iron Ore", 11370},
        {"Gold Ore", 2776}, {"Iron Bar", 3575}, {"Iron Ore", 2772}, {"Mithril Ore", 3858},
        {"Silver Ore", 2775}, {"Thorium Ore", 10620}, {"Tin Bar", 3576}, {"Tin Ore", 2771},
        {"Truesilver Ore", 7911},
    },
    ["Tailoring"] = {
        {"Bleach", 2324}, {"Blue Dye", 6260}, {"Bolt of Linen Cloth", 2996},
        {"Bolt of Mageweave", 4339}, {"Bolt of Runecloth", 14048}, {"Bolt of Silk Cloth", 4305},
        {"Bolt of Woolen Cloth", 2997}, {"Breath of Wind", 7081}, {"Coarse Thread", 2320},
        {"Core of Earth", 7075}, {"Elemental Air", 7069}, {"Elemental Earth", 7067},
        {"Elemental Fire", 7068}, {"Elemental Water", 7070}, {"Enchanted Leather", 12810},
        {"Essence of Undeath", 12808}, {"Essence of Water", 7080}, {"Felcloth", 14256},
        {"Fine Thread", 2321}, {"Globe of Water", 7079}, {"Gray Dye", 4340},
        {"Green Dye", 2605}, {"Heart of Fire", 7077}, {"Heavy Leather", 4234},
        {"Heavy Silken Thread", 8343}, {"Ichor of Undeath", 7972}, {"Iridescent Pearl", 5500},
        {"Iron Buckle", 7071}, {"Ironweb Spider Silk", 14227}, {"Light Leather", 2318},
        {"Linen Cloth", 2589}, {"Mageweave Cloth", 4338}, {"Medium Leather", 2319},
        {"Mooncloth", 14342}, {"Orange Dye", 6261}, {"Pink Dye", 10290},
        {"Purple Dye", 4342}, {"Red Dye", 2604}, {"Rugged Leather", 8170},
        {"Rune Thread", 14341}, {"Runecloth", 14047}, {"Shadow Silk", 10285},
        {"Shadowgem", 1210}, {"Silk Cloth", 4306}, {"Silken Thread", 4291},
        {"Small Lustrous Pearl", 5498}, {"Spider's Silk", 3182}, {"Thick Spider's Silk", 4337},
        {"Wool Cloth", 2592}, {"Yellow Dye", 4341},
    },
}

---------------------------------------------------------------------------
-- Material sources (baseline). The addon also learns these in-game:
--   * open any vendor window  -> everything it sells is marked "vendor"
--   * open a profession window -> everything it can craft is marked "crafted"
-- Anything not marked is treated as "drop / gathered".
---------------------------------------------------------------------------
local function Set(list)
    local t = {}
    for _, v in ipairs(list) do t[v] = true end
    return t
end

ns.VendorItems = Set({
    "Empty Vial", "Leaded Vial", "Crystal Vial", "Imbued Vial",
    "Coarse Thread", "Fine Thread", "Silken Thread", "Heavy Silken Thread", "Rune Thread",
    "Salt", "Bleach", "Gray Dye", "Black Dye", "Blue Dye", "Green Dye", "Red Dye",
    "Yellow Dye", "Purple Dye", "Orange Dye", "Pink Dye",
    "Weak Flux", "Strong Flux", "Coal", "Fused Wiring",
    "Simple Wood", "Copper Rod",
    "Mild Spices", "Hot Spices", "Soothing Spices", "Refreshing Spring Water",
})

ns.CraftedItems = Set({
    -- smelted bars
    "Copper Bar", "Tin Bar", "Bronze Bar", "Iron Bar", "Steel Bar", "Silver Bar", "Gold Bar",
    "Mithril Bar", "Truesilver Bar", "Thorium Bar", "Dark Iron Bar", "Arcanite Bar",
    "Enchanted Thorium Bar",
    -- cloth & leather work
    "Bolt of Linen Cloth", "Bolt of Woolen Cloth", "Bolt of Silk Cloth", "Bolt of Mageweave",
    "Bolt of Runecloth", "Mooncloth", "Enchanted Leather", "Refined Deeprock Salt",
    "Cured Light Hide", "Cured Medium Hide", "Cured Heavy Hide", "Cured Thick Hide", "Cured Rugged Hide",
    -- blacksmithing parts
    "Rough Grinding Stone", "Coarse Grinding Stone", "Heavy Grinding Stone", "Solid Grinding Stone",
    "Dense Grinding Stone", "Iron Buckle",
    -- enchanting rods
    "Silver Rod", "Golden Rod", "Truesilver Rod", "Arcanite Rod",
    -- engineering parts
    "Rough Blasting Powder", "Coarse Blasting Powder", "Heavy Blasting Powder",
    "Solid Blasting Powder", "Dense Blasting Powder", "Handful of Copper Bolts", "Copper Tube",
    "Copper Modulator", "Bronze Tube", "Bronze Framework", "Whirring Bronze Gizmo",
    "Gyrochronatom", "Iron Strut", "Silver Contact", "Mithril Tube", "Mithril Casing",
    "Unstable Trigger", "Gold Power Core", "Thorium Widget", "Thorium Tube",
})
