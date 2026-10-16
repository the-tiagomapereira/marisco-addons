# Marisco's Item Value Scanner — v0.9 - Beta

For World of Warcraft: Forever 1.60.x (interface 16001).

## Install
1. Close WoW.
2. Extract the zip into your Forever client's `Interface/AddOns` folder
   (during the beta that is `_classic_beta_/Interface/AddOns`).
3. You should end up with `Interface/AddOns/MariscosItemValueScanner/MariscosItemValueScanner.toc`.
4. Start the game and enable the addon in the AddOns list.

## Use
- Open the Auction House: a **Scan AH** button docks to the bottom-right corner of the AH window.
  Press it to scan every listing. The button grays out for 15 seconds with a countdown.
  Shift-drag moves it; on release it snaps back to the dock.
- Hover any item in your bags or a linked item in chat: a separate panel attached under the
  game's tooltip shows (it always sits clear of the comparison "Equipped" tooltips, below them
  or, near the bottom of the screen, above them):
  vendor price, AH price (lowest buyout per unit), the difference, and the
  last scan date/time with a live "x seconds/minutes/hours/days ago" timer.
  Stacks in bags also show the whole-stack value.
- Disenchantable gear (green, blue, purple weapons and armor) also shows the materials it can
  disenchant into, with quantity, chance and AH price of each, plus the possible value range,
  the expected value, and the best option (Disenchant, Auction House or Vendor).
  Materials are priced from the same AH scan, so scan first.
- Minimap button (Arcane Intellect icon): left-click toggles the AH scan button,
  right-click prints last-scan info, drag to move it.

## Commands
`/mivs scan` · `/mivs fast` · `/mivs de` · `/mivs toggle` · `/mivs minimap` · `/mivs status` · `/mivs reset`

## Notes
- Addons can't reach web APIs, so prices come from the in-game Auction House.
- Default scan is SAFE: a blank Auction House search, loaded in batches until the list is
  complete. It gives the lowest buyout and total quantity per item, has no 15-minute limit
  and is light on the client. Progress is shown next to the button.
- `/mivs fast` switches to the FAST scan (every single auction in one go). It is heavy, the
  server allows it about once every 15 minutes and silently ignores extra requests, and other
  addons that react to it (e.g. ProfessionShoppingList) can freeze the game.
- If another AH addon (Auctionator, AHledger, Aux, TSM...) sends its own AH query while we
  scan, our scan stops and keeps what it has, so results never mix. Don't run two scans at once.
- Prices are stored per realm and faction.
- Disenchant results are an estimate based on the Classic disenchant table by item level.
  Forever hasn't published its own table yet; it lives in `Disenchant.lua` for easy updates.
