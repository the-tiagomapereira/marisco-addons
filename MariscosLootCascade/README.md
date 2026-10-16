# Marisco's Loot Cascade — v1.0 - Release

For World of Warcraft: Forever 1.60.x (interface 16001).

Replaces the loot window with a cascading loot feed: everything is looted at once and each item
gets its own small rounded card in the middle of the screen. Cards drop into place, stay for a
few seconds, then fade out slowly while newer loot pushes older cards down.

## Install
1. Close WoW.
2. Extract the zip into your Forever client's `Interface/AddOns` folder
   (during the beta that is `_classic_beta_/Interface/AddOns`).
3. You should end up with `Interface/AddOns/MariscosLootCascade/MariscosLootCascade.toc`.
4. Start the game and enable the addon in the AddOns list.

## Use
- Loot a corpse, chest, fishing bobber, herb... The loot window no longer appears: every slot is
  taken and each item gets a card: round icon with a ring in the item's quality color, a rim in the
  same color, the name, the quantity (×3) and, in gray, how many you now have in your bags.
  Money gets its own card with a coin icon.
- Cards are centered horizontally, starting about a third of the screen above the center
  (up to 7 cards). Newest is on top.
- The same item looted again while its card is visible adds to that card (×2, ×3...) with a short flash.
- Rare items stay 1 second longer, epics 2, legendaries 3 (can be turned off in the settings).
- Hover a card to see the item tooltip (it stops fading while hovered), Shift-click to link it in chat.
- Also shown: quest rewards and other items pushed into your bags, and items you craft (both can be turned off).
- `/mlc test` shows a sample of every rarity.

## Settings
Minimap button (Onyxia Hide Backpack icon): **left-click** opens the settings, **right-click** shows sample loot,
drag it to move it around the minimap. `/mlc config` opens the settings too.

- **Size**: 60% to 160%. The feed stays in place while it grows or shrinks.
- **Background opacity**: how see-through the cards are, 0% to 100%.
- **Fade out after**: tick 3, 5 or 8 seconds for how long a card stays before it starts fading.
- **Rarity increases screen time**: when ticked, rare items stay 1 s longer, epics 2 s,
  legendaries 3 s. Untick it and every card stays the same time.
- **Position**: while the settings are open, the feed's area shows as a cyan box with a "Position"
  title and instruction above it; drag it anywhere. **Reset position** (under the box, right corner)
  puts it back in the default spot.
- **Show sample loot** (under the box, left corner): clears the feed, then one card of every rarity
  appears in this order, each below the previous: random money, Defias Mask (poor),
  Hearthstone (common), a random uncommon, a random rare, Corrupted Ashbringer (epic) and
  Thunderfury (legendary).
- **Save** keeps the changes and closes the window.
- **Default** puts size, opacity, timer and position back to the original settings (then Save).
- **Cancel**, the X or Escape closes and undoes the changes.

## When the normal loot window still opens
- Holding **Shift** (your auto-loot toggle key) while looting: pick items by hand.
- You are the **master looter**: you need the window to hand out items.
- Something can't be taken: **bags full** (a red "Inventory is full" card appears too), or a
  Bind on Pickup item whose confirmation you declined.
- If only items being rolled for are left (group loot), the loot is closed like auto-loot does;
  the roll windows are not affected.

## Commands
`/mlc config` · `/mlc minimap` · `/mlc test` · `/mlc unlock` · `/mlc lock` · `/mlc replace` · `/mlc grow up|down` · `/mlc hold <sec>` ·
`/mlc fade <sec>` · `/mlc lines <n>` · `/mlc scale <n>` · `/mlc quality <0-5>` · `/mlc money` ·
`/mlc pushed` · `/mlc crafted` · `/mlc count` · `/mlc mouse` · `/mlc status` · `/mlc reset`

Defaults: hold 5 s, fade 1.6 s, 7 cards, grows down, all qualities shown.

## Notes
- The feed reads the game's own loot messages, so it only shows what actually reached your bags,
  in any client language.
- `/mlc replace` turns the takeover off: the normal loot window is back and the feed keeps working
  as a loot notification on top of it.
- Other addons that also replace the loot window (ElvUI, XLoot, LS: Loot...) will clash; use one at a time.
- Settings are saved per account.

## Changelog
- 1.0 (release): Title centered in the title bar between the icon and the X. First full release.
- 0.14: Title centered in the title bar with the version in white; the inner dark area now has
  equal margins on both sides.
- 0.13: Settings window laid out like Marisco's Cursor Tooltip: title "Marisco's Loot Cascade -
  v0.13 Beta", narrower and taller window, same header, slider and tick box spacing.
- 0.12: Version shown in the window title; removed the rarity explanation line from the settings.
- 0.11: Settings window taller with even spacing (the icon no longer covers the first section),
  sliders span the full width, Fade out after is now 3 / 5 / 8 second checkboxes, new
  "Rarity increases screen time" toggle, version shown next to the window title.
- 0.10: Settings window restyled to match Marisco's Cursor Tooltip (game window frame, round
  portrait, gold section headers, Blizzard sliders, Save / Default / Cancel). New icon: Onyxia
  Hide Backpack, also on the minimap button and in the AddOns list.
- 0.9: Sample loot now appears in order (money first, legendary last), each card below the previous,
  starting from an empty feed. When there are too many cards, the oldest fade first.
- 0.8: Show sample loot and Reset position are normal buttons side by side under the cyan box,
  one in each corner.
- 0.7: Sample loot reads top to bottom from money to legendary. "Reset position" text is turned
  sideways inside its button.
- 0.6: Sample loot shows every rarity, from gray to Thunderfury. Show sample loot moved under the
  cyan box; Reset position is now a vertical button on the box's right edge.
- 0.5: Each setting sits in its own rounded box. Position title, instruction and a Reset position
  button moved next to the cyan box on screen.
- 0.4: Minimap button and settings box: size, background opacity, fade-out timer (3-10 s),
  drag to position, Save and Reset.
- 0.3: New look: each item in its own rounded card (quality rim, round icon with quality ring,
  bag count in gray), centered on the screen above your character. Cards drop in and drift
  away as they fade. The move box is the cyan area. The old v0.1/v0.2 position is reset once.
- 0.2: Fixed a Lua error on loot ("attempt to call a nil value", Feed.lua:31). The Forever client
  has no global `GetItemInfo`/`GetItemCount`/`GetItemIcon` (they live in `C_Item`), and its loot
  messages can carry only the item name instead of a link. Items are now matched by name against
  the loot window, the item cache and your bags, so they keep their icon, color and tooltip.
- 0.1: First release.
