# Marisco's Shellcracker — v0.12.1 - Beta

For World of Warcraft: Forever 1.60.x (interface 16001).

A Bejeweled-style match-3 game inside WoW, played with Azeroth's gems. Every match, special
gem and combo hits the makrura in front of you; clear the shore from Durotar to Tidefury Cove.

## Install
1. Close WoW.
2. Extract the zip into your Forever client's `Interface/AddOns` folder
   (during the beta that is `_classic_beta_/Interface/AddOns`).
3. You should end up with `Interface/AddOns/MariscosShellcracker/MariscosShellcracker.toc`.
4. Start the game and enable the addon in the AddOns list.

## Menu
The game window always opens on the **menu**: your character card (rank badge, level, title,
experience, money, unspent talent points, bag space and best results) and the buttons
**Continue** (greyed out when there is no run to resume; shows the makrura and score you left at),
**New Game**, **Character & Bags**, **Talents**, **Shop**, **Leaderboard** and **Settings**.
During a fight the **Menu** button (bottom right) pauses the run and brings you back here.
A run survives closing the window, logging out and reloading: just press Continue.

## Play
`/shell` (or `/msc`) or left-click the minimap button (crab icon) opens the game window.

- **Swap** two neighbouring gems to line up 3 or more of the same kind: click one gem, then
  its neighbour, or drag a gem onto its neighbour. Two gold lights circle the selected gem until
  you move it or click it again to deselect it.
- A swap that makes no match slides into place, slides back and gives a little shake. It
  doesn't count as a move.
- Matched gems vanish, the gems above fall, new ones drop in. Every new match made by the fall
  is a **cascade**: the 2nd clear scores x2, the 3rd x3 and so on ("Good!", "Excellent!",
  "Awesome!", "Spectacular!", "Extraordinary!", "Unbelievable!").

### Gems
Star Ruby, Black Pearl, Citrine, Huge Emerald, Aquamarine, Shadowgem and Azerothian Diamond,
drawn with the real item icons.

### Special gems (Bejeweled 3 rules)
| Match | Creates | When it is matched or caught in a blast |
|---|---|---|
| 4 in a line | **Flame Gem** | Explodes the 3x3 around it |
| L or T shape | **Star Gem** | Destroys its whole row and column |
| 5 in a line | **Hypercube** | Swap it with any gem: every gem of that color is destroyed |
| 6 in a line | **Supernova** | Destroys 3 rows and 3 columns |

- **Hypercube + Flame/Star/Supernova**: every gem of that color turns into that special and
  detonates. **Hypercube + Hypercube**: the whole board is destroyed.
- A Hypercube caught in an explosion wipes out a random color.
- Special gems are made where you moved the gem; explosions chain into other specials.
- Hover a special gem to see what it does.

### Scoring
3 gems 50, 4 gems 100, 5 gems 150, 6+ gems 50 each. Each gem destroyed by an explosion 20.
Detonation bonus: Flame 100, Star 200, Hypercube 300, Supernova 500. Everything is multiplied
by the cascade level.

## Gem powers
Every colour does something when you match it (once per match, however many gems; gems destroyed
by explosions or Hypercubes don't count, except for Emerald healing). The four run buffs last until
you die and their cap goes up with every tide, so you keep getting stronger as the makrura do.

| Gem | Each match | Lasts | Cap |
|---|---|---|---|
| Huge Emerald | Each gem heals 15% of the hit you'd take from the makrura (at least 20) | Instant | - |
| Aquamarine | 15% chance to freeze the makrura: its next attack comes a move later | Until it attacks | One freeze at a time |
| Shadowgem | 15% chance to curse it: 1% of its max health as shadow damage every move for 10 moves (carries over to the next makrura) | 10 moves | A new curse restarts the 10 moves |
| Citrine | +2% gold (Citrine Fortune) | Whole run | +50% per tide |
| Azerothian Diamond | +1% damage (Diamond Edge) | Whole run | +25% per tide |
| Star Ruby | -1% damage taken (Ruby Ward) | Whole run | -10% per tide, -30% at most |
| Black Pearl | +1% item drop chance (Pearl Luck) | Whole run | +20% per tide |

The active ones show as icons under your experience bar (hover for details); the battle text tells
you about freezes, curses, shadow damage and caps reached.

## The fight
- **Enrage:** if a fight lasts more than 30 moves (50 against Lord Angler), the makrura enrages and
  hits 5% harder for every extra move. The side panel shows it.
- **Points are damage**: every point you score is taken off the makrura's health.
- The makrura **attacks after a set number of your moves** (shown under its health bar). Each hit
  plays a random melee impact from the game (unarmed blows and sword, axe, mace and dagger hits)
  with the makrura's attack cry; rares and Lord Angler land critical hits.
- **Warning sound** when the makrura will strike after your next move ("Attacks next move!"),
  and again when a hit leaves you below 10 health.
- **Battle text** is a short combat log in a box just above the window. New lines come in at the
  bottom and push older ones up, for example:
  - *Certified matches 3 Citrine: Makrura Clacker takes 50 damage.*
  - *Certified hits a x3 combo, forging a Flame Gem: Makrura Clacker takes 300 damage.*
  - *Certified heals for 6 from matching 3 Huge Emerald.*
  - *Makrura Clacker hits Certified for 5 damage.*
  - *Certified's x3 combo staggers Makrura Snapclaw: its attack is delayed.*
  - also: Hypercube blasts, hard-shell blocks, mending-tide heals, low health, defeats, the next
    makrura arriving and reshuffles.
  - **Hover** the battle text area to bring back everything from your last 2 moves (each move plus
    the makrura's answer), held on screen while you hover. Move away and they fade after the usual
    time. Clicks still go through the area.
- A move with a **3-cascade combo or more staggers** the makrura: its attack counter doesn't
  tick down that move.
- Defeat a makrura and you heal 25; the board is cleared and refilled for the next one.
- **No moves left**: the makrura gets a free attack while the gems are reshuffled.
- At 0 health the run ends. Score, furthest makrura and biggest combo are kept as your best.

| # | Makrura | Where | Health | Hits | Trait |
|---|---|---|---|---|---|
| 1 | Makrura Clacker | Durotar | 800 | 5 every 4 moves | |
| 2 | Makrura Shellhide | Durotar | 1,000 | 6 every 4 | Hard shell: plain 3-gem matches deal half damage |
| 3 | Makrura Snapclaw | Durotar | 1,250 | 6 every 3 | Quick claws |
| 4 | Makrura Elder | Durotar | 1,550 | 7 every 4 | Mending tide: heals 20% of your damage when it attacks |
| 5 | Slimeshell Makrura | The Barrens | 1,950 | 8 every 4 | |
| 6 | Murkshallow Snapclaw | Blackfathom Deeps | 2,450 | 8 every 3 | Quick claws |
| 7 | Muckshell Clacker | Dustwallow Marsh | 3,050 | 10 every 4 | |
| 8 | Muckshell Razorclaw | Dustwallow Marsh | 3,800 | 12 every 4 | |
| 9 | Diamond Head (rare) | Feralas | 4,750 | 12 every 4 | Hard shell |
| 10 | Lord Angler (boss) | Tidefury Cove | 5,500 | 11 every 4 | Mending tide |

After Lord Angler the tide rises again: the same ten come back with 50% more health and
3 more damage each round, for as long as you last.

## Levels and titles
Each character has its own Shellcracker level, from 1 to 60. Experience comes from every makrura
you defeat (more for later makrura, rares, Lord Angler and later tides), from big combos (x4 and
up) and from the run itself when it ends (your score / 50). Every level gives +3% damage, -0.5%
damage taken and +1 maximum health. Makrura scale with your level too (+4% health and +2.5%
damage per level), so talents and gear are what really make you stronger.

Every 10 levels you earn a new title (classic PvP ranks, by faction):

| Level | Horde | Alliance |
|---|---|---|
| 1 | Scout | Private |
| 10 | Sergeant | Sergeant |
| 20 | Stone Guard | Knight |
| 30 | Legionnaire | Knight-Captain |
| 40 | Champion | Lieutenant Commander |
| 50 | Warlord | Field Marshal |
| 60 | High Warlord | Grand Marshal |

## Talents
One talent point per level from level 10 (51 at level 60), like the real game. Three trees,
seven tiers; tier N needs (N-1)x5 points in that tree. **Left-click** to learn a rank,
**right-click** to unlearn it (only if no deeper talent depends on it). **Reset talents** refunds
everything. Talents can't be changed during a run.

**Arms** (damage): Heavy Blows 5 (+2% damage), Cruelty 5 (+1% crit; crits deal +50%), Sundering
Strikes 3 (+5% plain 3-gem matches), Impale 2 (+15% crit damage), Shell Breaker 2 (hard shells
block 50% less), Opportunity 3 (+10% on your first 3 moves against each makrura), Weapon
Specialization 5 (+10% weapon damage), Blood Craze 3 (x3+ combos heal 1), Improved Execute 2 (+15%
vs makrura under 20%), Enrage 5 (+5% while under 30% health), Overpower 3 (+10% on the move after
you're hit), Flurry 5 (+4% on the move after a crit), **Mortal Strike** 1 (+10% damage, +20% crit
damage).

**Tidecaller** (combos and special gems): Rising Tide 5 (+3% per cascade), Gemcutting 5 (+4%
explosion damage), Kindling 3 (start each fight with 1 Flame Gem per rank), Undertow 1 (x2 combos
stagger), Chain Lightning 3 (+20% Star Gems), Arcane Concentration 3 (+15% Hypercubes), Tidal
Surge 5 (+4% on x3+ combos), Ignite 3 (+10% Flame Gems), Master of Elements 2 (forging a special
gem heals 1), Tidebringer 5 (+2% per special gem on the board, up to 5), Elemental Precision 3 (+2%
crit on combos), **Tidal Wave** 1 (start each fight with a Hypercube).

**Protection** (survival and rewards): Toughness 5 (+3 health), Anticipation 5 (+1% dodge), Iron
Will 3 (-3% damage taken), Healing Waters 3 (+1 heal per Huge Emerald), Treasure Hunter 2 (+10%
gold), Second Wind 3 (+5 health after each makrura), Hamstring 2 (8% chance a move doesn't bring the
attack closer), Scholar 3 (+5% experience), Shield Wall 1 (a hit that would leave you under 25
health is halved), Mortal Wounds 2 (mending tide heals 25% less), Last Stand 1 (once per run a
killing blow leaves you at 1 health), Prospector 3 (+10% item drops, better quality), Vitality 5
(+4 health), **Bulwark** 1 (makrura attack one move later).

## Gear, bags, gold and the shop
Health works like WoW numbers: you start with 1,000 health (+10 per level); makrura hits and
all healing are on the same scale.

### Stats
| Stat | Per point |
|---|---|
| Stamina | +10 maximum health |
| Damage | +1 damage to every match |
| Critical Strike | +0.1% critical hit chance (crits deal +50%) |
| Combo Power | +0.2% damage per cascade level |
| Explosive Power | +0.5% special gem damage |
| Armor | reduces damage taken (diminishing, 600 Armor = -50%, the cap) |
| Restoration | +1% Huge Emerald healing |
| Fortune | +0.5% gold and +0.25% item drop chance |

### Gear slots (like WoW)
Head, Neck, Shoulder, Back, Chest, Wrist, Hands, Waist, Legs, Feet, two Finger slots, two
Trinket slots, Main Hand, Off Hand and Ranged.
- **Two-Hand** weapons take the main hand and leave the off hand empty (anything there comes off).
- **One-Hand** weapons go in either hand, so you can **dual wield**; **shields** go in the off hand.
- Bags: left-click equips into the free slot, or replaces the weaker ring/trinket. **Shift-click**
  puts it in the second ring/trinket slot, or a one-hander in the off hand.
- Bigger pieces carry more stats (like WoW item budgets): Head, Chest and Legs 100%, Shoulder,
  Hands, Waist, Feet 75%, One-Hand 65%, Two-Hand 130%, Neck, Back, Wrist, rings, trinkets,
  off-hands and ranged 55%.
- Weapons and ranged weapons always roll Damage; armor pieces and shields always roll Armor. Armor
  only appears on those.

### Rarities
| Rarity | Stats | Each stat (item level 60) | Effects |
|---|---|---|---|
| Poor (grey) | - | - | junk to sell |
| Common (white) | 2 | 1-15 | - |
| Uncommon (green) | 2 | 15-25 | 1 |
| Rare (blue) | 3 | 25-35 | 1, 30% chance of a 2nd |
| Epic (purple) | 4 | 40-50 | 2, stronger |
| Legendary (orange) | 4 | 60-80 | 1 unique |

Items drop at your level (+-2, bosses +2) and stats scale steeply with item level
(value x (item level / 60)^2.5), so a level-60 green beats a level-32 epic. A legendary's
unique effect never scales, so an older legendary can stay best in slot.

### Effects
Matching a Huge Emerald can heal extra (20%/25%/30% chance for 100/150/250), more Aquamarine
freeze chance (+3/5/8%), more Shadowgem curse chance (+3/5/8%), higher Diamond Edge cap (+3/5/8%
per tide), higher Ruby Ward cap (+1/2/3%), higher Citrine Fortune and Pearl Luck caps (+5/8/12%),
x3+ combos deal more (+5/8/12%), heal when a makrura dies (2/4/6% of max health), and a chance for
a match to deal double damage (2/3/5%). Values are uncommon / rare / epic.

### Legendaries
| Item | Slot | Unique effect |
|---|---|---|
| Claw of Lord Angler | Main Hand | Every x3+ combo forges a Flame Gem |
| Crown of the Tidelord | Head | Each fight starts with a Hypercube |
| Shell of the Ancients | Chest | The first hit of every fight is fully absorbed |
| Grips of the Undertow | Hands | Forging a Hypercube also forges a Supernova |
| Leggings of the Abyss | Legs | Shadowgem curses stack, up to 3 |
| Treads of the Low Tide | Feet | Makrura attack one move later |
| Band of Endless Tides | Finger | All gem buff caps are 50% higher |
| Heart of the Deep | Trinket | Heal for 3% of all damage you deal |

A legendary drop is always one you don't own yet, until you have all 8.

### Drops
- Every makrura drops gold (more for higher-level makrura and later tides).
- Items: 22% from normal makrura, 60% from Diamond Head, always from Lord Angler.
- **Legendaries** can only come from every 5th makrura of a run (2%), Lord Angler (20%) and the
  **Loot-Crazed Makrura** (20%).
- **Loot-Crazed Makrura:** any normal makrura has a 5% chance to show up Loot-Crazed (gold name,
  announced in the battle text). Same strength, but it always drops Rare or better (50% Rare, 30%
  Epic, 20% Legendary) and three times the gold.

### Character & Bags, Shop, Buyback
- 8 gear slots, your stats, and a 16-slot backpack. Bags: left-click to equip, right-click to
  sell (always asks Yes/No). Gear: click to take it off. Tooltips compare with what you wear.
  Gear and talents can't be changed during a run.
- **Shop:** six random items at your level. New stock arrives with every tide (including the start
  of each run). You can pay to restock at most 3 times per tide; then the button is greyed until
  the next tide. Rare and Epic items cost more.
- **Buyback:** the last 12 items you sold, in the Shop's Buyback tab (or the Buyback button under
  your bags), for exactly what you sold them for.

## Leaderboard and stats
**Leaderboard** button (top right of the game window), right-click on the minimap button, or
`/shell board`. It covers every character on your WoW account; each character's own fight is
saved separately, and whoever is logged in plays and records under their own name.
- **Characters**: one row per character in class colours: Shellcracker level with rank badge, best score, furthest makrura,
  biggest combo, games and makrura defeated. Click a column header to sort; the character you
  are on is highlighted. Click a row for that character's stats; right-click to remove it (asks first). The Stats tab also has a **Remove character** button.
- **Top Runs**: the 50 best runs of all your characters: score, makrura reached, combo, kills,
  moves and date. "(left)" marks a run ended by starting a new game mid-fight.
- **Stats** (`/shell stats`): per character, or *All characters* combined (use < >): games, best,
  average and total score, furthest makrura, biggest combo, best single move, makrura and Lord
  Angler defeated, time played, moves, gems shattered, damage dealt and taken, health healed and
  special gems made, and gold looted.
- Another character's new results appear once it has logged out (or done a /reload), because WoW
  only writes saved data then. `/shell resetscores` clears everything, after asking.

## Settings
**Settings** button (between Hint and New Game) or `/shell config`. The window opens beside the game:
- **Sound effects**: all of Shellcracker's sounds on or off.
- **Play music**: plays the songs from World of Warcraft's inns (Alliance, Horde, human, dwarf,
  night elf, orc, tauren, undead and pirate taverns), shuffled, one after another, while the game
  window is open. Your zone music is switched off meanwhile, so the two never play together,
  and is put back exactly as it was when you close the window (also on logout). The inn songs use
  the game's **Ambience** volume.
- **Show battle text**: battle text on or off.
- **Text stays for**: slider, 2 to 15 seconds (default 6). Each line fades out over its last second.
- **Move battle text**: shows the battle text box in cyan with sample numbers floating in it;
  drag it anywhere. Untick it, or close the settings, to lock it. It moves with the game window.
- **Reset position**: puts the battle text box back just above the window.

## Other
- **Hint** button: the gem you should move glows **green**.
- **Automatic hint**: after 15 seconds without a move, the gem to move glows **blue**, so you can
  tell it from a hint you asked for. Both hints go away when you make a move.
- **New Game** asks before throwing away a fight in progress.
- The fight is saved per character after every move: close the window, log out, and continue later.
- Minimap button: left-click plays, right-click prints your best scores, drag to move it.
  It is a normal named button, so Marisco's MiniMapButtonHoarder picks it up.

## Commands (`/shell`, or `/msc`)
`/shell` · `/shell new` · `/shell char` · `/shell talents` · `/shell shop` · `/shell board` · `/shell stats` · `/shell config` · `/shell music` · `/shell text` · `/shell hint` · `/shell hintdelay <3-60>` · `/shell sound` ·
`/shell minimap` · `/shell reset` · `/shell resetscores`

## Notes
- The makrura are shown with their 3D model when the client has the creature cached; until then
  the crab icon stands in.
- Balance numbers (health, damage, attack timers, healing) are all in `Data.lua`.
- Every sound is from the game itself: weapon and unarmed impacts, crustacean cries for the
  makrura (the makrura's own sound set only exists in later expansions), fireball, lightning bolt,
  arcane explosion, flamestrike and thunder clap for the special gems, the gem pickup sounds for
  the board, and the raid warning for danger.
- Settings and best scores are saved per account; the game in progress per character.

## Changelog
- 0.12.1: fixed "MariscosShellcracker has been blocked from an action only available to the Blizzard UI" when pressing Esc or opening Options. The addon no longer rewrites a Blizzard global (StaticPopupDialogs), which tainted the game menu.
- 0.12: WoW gear slots (neck, shoulder, back, wrist, waist, 2 rings, 2 trinkets, main hand, off hand,
  ranged), one-hand/two-hand weapons and dual wielding, shields. Shop restocks every tide, max 3
  paid restocks per tide. Leaderboard fits its window; Remove character button with confirmation.
- 0.11: New gear: Shellcracker stats (Stamina, Damage, Critical Strike, Combo Power, Explosive
  Power, Armor, Restoration, Fortune), 6 rarities with item effects, 8 unique legendaries, item
  level scaling. Loot-Crazed Makrura. Health x10. Enrage timer. Sell confirmation and Buyback.
  Taller window so the buffs fit. Old items are re-rolled into the new system.
- 0.10: Gem powers: every colour now does something (freeze, shadow curse, and run-long Citrine,
  Diamond, Ruby and Pearl buffs whose caps rise each tide). Emerald healing scales with the hits you
  take. Later tides have more health (x2 per tide). Side panel: buff icons (the "Best" line moved to
  the menu).
- 0.9.1: Hover the battle text to see the last 2 moves again.
- 0.9: Progression. Menu with Continue/New Game; character levels 1-60 with PvP-rank titles;
  three talent trees (Arms, Tidecaller, Protection); gear drops in five qualities, a 16-slot
  backpack, 8 gear slots and stats; gold and a shop. Makrura scale with your level; the endless
  tides after Lord Angler hit harder (health x1.8, damage x1.4 per tide).
- 0.8.1: Lord Angler nerfed. The mending tide now heals 20% of the damage you dealt since its
  last attack (it was 6% of max health, which out-healed normal play on Lord Angler). Lord Angler:
  5,500 health (was 9,000), hits for 11 (was 13).
- 0.8: Leaderboard across your characters (Characters, Top Runs, Stats). Best score is now per
  character (the old account-wide best goes to the first character that logs in).
- 0.7: All sounds are now the game's own (custom sounds removed). Makrura hits use random melee
  and weapon impacts. Music is now the real inn songs; the toggle is called "Play music" and the
  zone music is muted while it plays, then restored.
- 0.6: Tavern music on loop while you play, with a toggle in Settings (`/shell music`). Warning
  sound one move before the makrura attacks.
- 0.5: Battle text is now a combat log of full sentences (what you matched, combos, specials,
  damage, heals, attacks). New slider for how long the text stays (2-15 s, default 6; it used to
  vanish after about 1 second).
- 0.4: Flame gem no longer uses the Battle.net toast sound; explosions, special gems and combos
  have their own sounds (no more loot-toast or coin sounds). Random battle hit sounds (13) when the
  makrura strikes. Battle text sits in a box above the window. New Settings window: sound, battle
  text, move battle text, reset position.
- 0.3: Punch sound when the makrura hits you; the warning sound only plays below 10 health.
  A new makrura brings a fresh board. The selection glow now circles the gem. Combat text floats
  above the window. Tigerseye replaced by Black Pearl (too close to Citrine).
- 0.2: Hint button fixed (its glow was hidden behind the gems). Selected gem glows gold until
  moved or deselected. A bad swap now slides into place, back, and shakes. Automatic hint after
  15 seconds, in blue; the Hint button glows green. Hints mark the one gem to move.
- 0.1: First release.
