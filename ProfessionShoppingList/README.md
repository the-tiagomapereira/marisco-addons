# Marisco's Profession Shopping List — v0.25 - Beta

For World of Warcraft: Forever 1.60.x (interface 16001).

Pick the materials you need for a profession, keep them in a shopping list beside the Auction
House, and see what the whole list costs. Leveling guides for most professions put a full
skill-up plan into the list with one click.

## Install
1. Close WoW.
2. Extract the zip into your Forever client's `Interface/AddOns` folder
   (during the beta that is `_classic_beta_/Interface/AddOns`).
3. You should end up with `Interface/AddOns/ProfessionShoppingList/ProfessionShoppingList.toc`.
4. Start the game and enable the addon in the AddOns list.

## Use
- `/psl` (or `/shoppinglist`) or the minimap button (note icon) opens the window. It attaches to
  the right side of the Auction House when that opens, and can collapse into a thin side tab.
- **Materials**: pick a profession with the dropdown or the < > arrows. Materials are listed
  alphabetically with a search box, a source filter (All, Vendor, Drop / gathered, Crafted) and
  an optional grid view with large icons. Click a material to add it to the shopping list, or
  drag items from your bags onto the window.
- **Shopping list**: type a quantity on each line, alt-click to search the Auction House, red X
  to remove a line. The Have column shows what you already own; tick
  **Subtract what I already own** to buy only what's missing.
- **Scan list** prices the whole list in one Auction House request (5-second cooldown), with a
  live "last scan" timer. Vendor items always use the vendor price; a coin icon shows whether the
  AH is cheaper (green) or more expensive (red).
- **Total, You have, After buying**: the cost of the list, the gold you carry and what you'd have
  left. The total turns red when you can't afford it.
- The addon learns vendor items and prices from vendor windows, and crafted items and recipe
  reagents from your profession windows.

## Leveling guide
Opens on a grid of all professions, plus **Your professions** with a skill bar for each of yours.
- Guides: Alchemy (1-290), Blacksmithing (1-225), Cooking (1-300), Enchanting (1-300),
  Engineering (1-300), First Aid (1-300), Leatherworking (1-225), Tailoring (1-225).
  Herbalism, Mining, Skinning and Fishing are coming soon. Source: wow-professions.com.
- Pick a skill range to see the steps, the materials to buy and the estimated cost. Guides with
  two routes pick the cheaper one once prices are scanned. Items made by earlier steps are
  subtracted automatically.
- **Add to list** puts the plan's materials into your shopping list (it asks first if the list
  already has items). **Share list** whispers the steps and materials to another player.
- **Check for updates** compares the guides with your game version and the real recipes in your
  profession windows, and lists any recipe whose reagents changed.

## Side tabs
Leveling guide, Notes (free text, saved automatically) and Settings on the window's right edge;
Release notes at the bottom. Side windows open beside the main window and stack instead of
overlapping. Settings: attach to the Auction House, open with the Auction House, background
opacity, resizable window (beta), minimap button.

## Commands (`/psl`, or `/shoppinglist`)
`/psl` · `/psl add <item>` · `/psl scan` · `/psl clear` · `/psl guide` · `/psl notes` ·
`/psl settings` · `/psl release` · `/psl learn` · `/psl minimap` · `/psl reset`

## Notes
- Settings and the shopping list are saved per account (`ProfessionShoppingListDB`).
- The full release notes are inside the addon (Release notes tab, or `/psl release`).

## Changelog (latest)
- 0.25: Leveling guide "Check for updates" button; the addon remembers each recipe's reagents
  when you open a profession window.
- 0.24: "Your professions" skill bars in the leveling guide; click one to open its guide.
- 0.23: Scrollbars on every scrolling area, shown only when needed.
- 0.22: Leveling guide window resizes to fit each guide; long guide notes no longer overlap the cost.
- 0.19: Guides for Alchemy, Blacksmithing, Cooking, Enchanting, Engineering, First Aid and
  Tailoring; cheaper route picked automatically.
- 0.13: Leveling guide tab with the Leatherworking route 1-225.
- 0.1: First release.
