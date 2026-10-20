# Marisco's Companion Keeper — v0.7.1 - Alpha

For World of Warcraft: Forever 1.60.x (interface 16001).

Look after the companion pets you own. The addon reads your Companion Journal and every
companion on your account becomes one you can care for inside the addon. The pet you summon in
the world is never touched: it just follows you as normal.

> **Alpha:** choose your companion, summon it, and make it happier: daily challenges that earn
> hearts, plus petting, a fetch mini-game, walking together, quests, level-ups and time spent
> together. It also has a report (`/mck probe`) that shows exactly what Forever's Companion Journal
> gives to addons.

## Install
1. Close WoW.
2. Extract the zip into your Forever client's `Interface/AddOns` folder
   (during the beta that is `_classic_beta_/Interface/AddOns`).
3. You should end up with `Interface/AddOns/MariscosCompanionKeeper/MariscosCompanionKeeper.toc`.
4. Start the game and enable the addon in the AddOns list.

## Use
- `/mck` or left-click the minimap button (pet carrier icon) opens the window, built from the
  game's own window, inset and button styles.
- **Companion list** (left): every companion you own, alphabetical, with a search box. Under
  each name: **Running alongside you** (green) or **In its cage** (red). Click a companion to
  make it yours: it gets a check mark and its icon goes on the minimap button.
- **Hide / show the list**: the arrow in the portrait's top-left corner. The list slides away to
  the left and your companion fills the whole window (the window keeps its size). The arrow
  brings it back; the choice is remembered.
- **Portrait** (right): your companion in 3D (drag to turn it). Top right: **Pet** and **Play**
  (see below), greyed out with a countdown while they recharge. Along its bottom: the name, the
  status, **Mini window** (closes this window and keeps the small companion window on screen),
  and:
  - **Summon** brings your companion out.
  - **Summon back** sends it back to its cage.
  Shift-click on the minimap button and `/mck summon` (works in a macro) do the same.
  Not possible in combat or while dead; a red message says why.
- **Actions box** under the portrait: your companion's happiness, today's hearts, today's four
  challenges, a "Today: +N happiness" line (hover it for every way to earn happiness) and the
  **Walk together** progress bar.
- **Mini window** button (next to Summon), or the small button left of the X: the window closes
  and a **mini tracker** stays on screen so you can play normally (see below).
- No companions in the journal: the window says so ("No companions yet"). Right after login it
  can briefly show "Reading your Companion Journal...".

## Mini tracker
A small panel you can keep on screen while you play:
- your companion's **portrait** (click it to **Summon** / **Summon back**), name and status
  (Running alongside you / In its cage),
- **today's hearts**, small **Pet** and **Play** buttons, the **happiness bar** with the level,
  today's **challenges** with their progress, today's happiness total and the **Walk together**
  bar.

Drag it anywhere; it remembers where. The button with the window icon opens the full window
(the tracker steps aside while it's open and comes back when you close it). The X turns the
tracker off. It stays on across logins until you close it. `/mck mini` shows or hides it.

## Hearts and happiness
Like a buddy system: do things in the world and your chosen companion gets happier.

**Daily challenges.** Every day 4 challenges are picked from this pool of 8 (a new mix each day):
- Talk to an innkeeper
- Eat or drink something
- Defeat 5 enemies (enemies that give experience)
- Visit 2 different zones
- Complete 2 quests
- Relax in an inn or city (2 minutes in a resting area)
- Spend 15 minutes together (companion summoned)
- Win a game of fetch

The first 3 you finish each earn a **heart** (+10 happiness). Once today's 3 hearts are full,
the rest still pay **+5 bonus** (the row shows "+5"). Each challenge has a check script that
returns **1** (yes) or **0** (no); on 1 it counts.

**Together** (any time, no daily limit):
- **Pet** (paw button): +2, once every 15 minutes.
- **Play** (ball button): a **Fetch** mini-game. Catch the bouncing ball 3 times in 10 seconds while
  your companion watches: +3, once every 20 minutes (you can retry straight away if you miss).
- **Complete a quest**: +2 each.
- **Level up**: +15.
- **Time together**: +1 every 10 minutes your companion runs alongside you.
- **Walk together**: distance travelled with your companion running alongside you, in yards. It
  adds up across days, in steps:
  - Step 1: 3,000 yards, +15
  - Step 2: 6,000 yards, +25
  - Step 3: 8,000 yards, +35
  - Step 4: 10,000 yards, +50
  - then a "long journey" milestone every 5,000 yards, +20 each.

  A blue bar fills toward the next step with the yards written inside ("700 / 3,000 yd"); hover it
  for all the steps. Running is about 7 yards a second, so step 1 is roughly 7 minutes on foot;
  mounted is faster.
  Flight paths, teleports and loading screens don't count.

Everything gives **+20%** while your companion is running alongside you (time together already
needs it). Each gain floats up as "+N ♥" over the portrait.

**Levels:** Unhappy → Content (30) → Happy (120) → Joyful (300) → Best Friends (600) →
Soulbound (1000). An active day of play is roughly 60-100 happiness.

Each companion has its own happiness, hearts and cooldowns; everything counts for the companion
you've chosen. Hearts and challenges reset at the daily reset (the box shows how long until then).

## Commands (`/mck`, or `/companionkeeper`)
`/mck` · `/mck mini` · `/mck summon` · `/mck pet` · `/mck play` · `/mck hearts` · `/mck test <action>` · `/mck probe` · `/mck scan` · `/mck status` · `/mck minimap` · `/mck reset`

- `/mck hearts` prints your companion's happiness, today's challenges and the pet/play cooldowns.
- `/mck test <challenge>` pretends one of today's challenges happened (`/mck test` lists them);
  `/mck test walk` completes the current Walk together step,
  `/mck test reset` clears today's progress and the pet/play cooldowns (for testing).
- `/mck probe` opens a report of the Companion Journal API (functions, counts, your pets,
  summoned pet, the position used for Walk together, errors), already selected for Ctrl+C.

## Notes
- Companions are account-wide, so the chosen companion is saved per account.
- If the journal's own filters (search, families, sources) hide some of your pets, the addon
  opens all filters for one read and puts them back after. The journal's search text is cleared
  when that happens. It's skipped while the Companion Journal window is open.
- The minimap button is a normal named button, so MiniMapButtonHoarder picks it up.
- Forever runs on the modern client, where the combat log is off limits to addons (registering
  for it gets an addon blocked). This addon doesn't use it.
- If the game ever blocks something the addon does, the addon names the exact action in red in
  chat and in `/mck probe`.

## Changelog
- 0.7.1 (alpha): Walk together is now a filling bar with the yards inside, in both windows. Mini
  window is a bit wider; challenge names no longer run into their progress text.
- 0.7 (alpha): Walk together: distance with your companion out, in steps of 3,000 / 6,000 / 8,000 /
  10,000 yards (+15 / +25 / +35 / +50), then +20 every 5,000 yards. Progress bar in the window,
  line in the mini window, `/mck test walk`.
- 0.6 (alpha): Much more to do. Daily challenges rotate (4 a day from a pool of 8, new: quests,
  relaxing, time together, fetch); after the 3 hearts they still give +5 bonus. New Pet and Play
  buttons (Fetch mini-game), happiness from quests, level-ups and time together, floating "+N"
  on the portrait, "Today: +N" total, new top level Soulbound. `/mck pet`, `/mck play`.
- 0.5.2 (alpha): "Mini window" button next to Summon / Summon back.
- 0.5.1 (alpha): Fixed "MariscosCompanionKeeper has been blocked from an action only available to
  the Blizzard UI". The kill challenge listened to the combat log, which Forever blocks for
  addons; kills are now counted from the experience message. Any blocked action is now named in
  chat.
- 0.5 (alpha): Minimize button: the window closes and a mini tracker (portrait, status, hearts,
  happiness bar, challenges) stays on screen. Click the portrait to summon. `/mck mini`.
- 0.4 (alpha): Hearts and happiness. Four daily actions (innkeeper, meal, 5 kills, 2 zones), each
  with a check script; 3 hearts a day; happiness bar from Unhappy to Best Friends; +20% while
  summoned; daily reset timer. Taller window to fit it. `/mck hearts`, `/mck test`.
- 0.3.3 (alpha): Fixed the companion list coming back empty after hiding and showing it. The
  list now keeps its size and slides behind an edge instead of being squeezed.
- 0.3.2 (alpha): Collapsing the list no longer shrinks the window: the list slides away to the
  left and the companion panel grows to fill the whole area.
- 0.3.1 (alpha): Fixed "Dismissing failed: bad argument #1" on Summon back. Forever's
  `C_PetJournal.DismissSummonedPet` needs the pet's ID; if it ever fails, summoning the same pet
  again sends it back instead.
- 0.3 (alpha): Collapsible companion list. Bigger 3D portrait with the name and status
  (Running alongside you / In its cage) on it. One Summon / Summon back button. Clicking a
  companion chooses it. Empty actions box reserved for later.
- 0.2 (alpha): Your companion's button summons or dismisses it. Shift-click on the minimap
  button and `/mck summon` too. Clear messages when summoning isn't possible.
- 0.1 (alpha): First release. Reads the Companion Journal, companion list with search and 3D
  preview, choose your companion, empty and loading states, `/mck probe` report, minimap button.
