# Changelog

## v0.9 - Beta (2026-10-12)
- Fix: the info panel flickered while hovering gear in the bags. Bag slots re-set their
  tooltip many times per second, and the panel was hidden and rebuilt every time. It now
  stays put while the same item is shown, and only rebuilds when the item, stack size or
  scan data changes.

## v0.8 - Beta (2026-10-12)
- The info panel can no longer be covered by other tooltips: it sits below the lowest of the
  item tooltip and its comparison ("Equipped") tooltips, or above the highest one when there's
  no room below, and follows them as they appear or disappear.

## v0.7 - Beta (2026-10-12)
- Fix: text could run past the right edge of the info panel. The panel now sizes itself to its
  text (coin icons included) plus a 12-pixel margin, instead of a fixed 250-pixel width.

## v0.6 - Beta (2026-10-12)
- Fix: the info panel could stretch to the right edge of the screen (seen on action bar items).
  The panel now has exactly one anchor, a standard width of 250, and only grows when a line
  (long item or material names, big prices) needs more room. It also stays clamped on screen.

## v0.5 - Beta (2026-10-12)
- The addon's information now shows in its own panel attached under the game's tooltip
  (above it when there's no room below), instead of inside the game's tooltip.
  The panel matches the tooltip's width and fades out with it. Works for bags and chat links.

## v0.4 - Beta (2026-10-12)
- New: disenchant info in tooltips for green/blue/purple weapons and armor - possible materials
  (quantity, chance, AH price each), possible value range, expected value, and best option
  (Disenchant / Auction House / Vendor). Based on the Classic table by item level until Forever
  publishes its own.
- New: `/mivs de` toggles the disenchant section.

## v0.3 - Beta (2026-10-12)
- Fix: "Attempt to unregister unknown event AUCTION_ITEM_LIST_UPDATE". Forever uses the modern
  Auction House API, where that classic event doesn't exist; event (un)registering is now safe.
- New SAFE scan for Forever: blank browse search + "load more" (lowest price and quantity per
  item). No 15-minute server limit, light on the client and on other addons.
- FAST scan timeout now explains the ~15 minute server limit instead of a generic message.
- ProfessionShoppingList added to the "other AH addons" warning (froze the game during a
  FAST/replicate scan in testing).
- Tooltip: browse scans don't report auction counts, so the line shows quantity only.

## v0.2 - Beta (2026-10-12)
- Fix: scanning could crash the client. The full-AH dump is now opt-in (`/mivs fast`);
  the default SAFE scan reads one page at a time and waits for each page to finish loading.
- New: collision guard - if another addon queries the AH during our scan, the scan stops
  cleanly and saves partial results instead of mixing data.
- New: warning when other Auction House addons are loaded.
- Any Lua error during a scan now stops the scan instead of repeating every frame.
- Smaller work chunks per frame in FAST mode (500 -> 200).

## v0.1 - Beta (2026-10-12)
- First release: AH scan button with 15s cooldown, tooltip prices (vendor, AH, difference, live last-scan timer), minimap toggle button.
