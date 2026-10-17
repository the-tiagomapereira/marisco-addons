# Marisco's Companion Keeper — v0.1 - Alpha

For World of Warcraft: Forever 1.60.x (interface 16001).

Look after the companion pets you own. The addon reads your Companion Journal and every
companion on your account becomes one you can care for inside the addon. The pet you summon in
the world is never touched: it just follows you as normal.

> **Alpha:** this first version reads the journal and lets you choose your companion. Happiness,
> feeding and play come next. It also has a report (`/mck probe`) that shows exactly what
> Forever's Companion Journal gives to addons.

## Install
1. Close WoW.
2. Extract the zip into your Forever client's `Interface/AddOns` folder
   (during the beta that is `_classic_beta_/Interface/AddOns`).
3. You should end up with `Interface/AddOns/MariscosCompanionKeeper/MariscosCompanionKeeper.toc`.
4. Start the game and enable the addon in the AddOns list.

## Use
- `/mck` or left-click the minimap button (pet carrier icon) opens the window, built from the
  game's own window, inset and button styles.
- **Left**: every companion you own, alphabetical, with a search box. Renamed pets show their
  species underneath; the one out with you says "out with you" in green.
- **Right**: the companion you clicked, in 3D (drag to turn it), its name and species.
- **Choose this companion** (or double-click a row) makes it your companion: a check mark
  marks it in the list and the minimap button shows its icon.
- No companions in the journal: the window says so ("No companions yet").
- Right after login the journal can take a moment: the window shows "Reading your Companion
  Journal..." until it's ready.

## Planned
- Happiness, hunger, play and grooming per companion.
- Summoned companion earns a flat happiness bonus while it's out (amount to be decided).

## Commands (`/mck`, or `/companionkeeper`)
`/mck` · `/mck probe` · `/mck scan` · `/mck status` · `/mck minimap` · `/mck reset`

- `/mck probe` opens a report of the Companion Journal API (functions, counts, your pets,
  summoned pet, errors), already selected for Ctrl+C.

## Notes
- Companions are account-wide, so the chosen companion is saved per account.
- If the journal's own filters (search, families, sources) hide some of your pets, the addon
  opens all filters for one read and puts them back after. The journal's search text is cleared
  when that happens. It's skipped while the Companion Journal window is open.
- The minimap button is a normal named button, so MiniMapButtonHoarder picks it up.

## Changelog
- 0.1 (alpha): First release. Reads the Companion Journal, companion list with search and 3D
  preview, choose your companion, empty and loading states, `/mck probe` report, minimap button.
