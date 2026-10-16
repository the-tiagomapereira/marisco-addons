# Marisco's MiniMapButtonHoarder — v0.5 - Beta

For World of Warcraft: Forever 1.60.x (interface 16001).

One button on the minimap holds every other addon's minimap button. Click it and they slide out
from behind it into the layout you picked; click again (or let the timer run out) and they tuck
back in.

## Install
1. Close WoW.
2. Extract the zip into your Forever client's `Interface/AddOns` folder
   (during the beta that is `_classic_beta_/Interface/AddOns`).
3. You should end up with `Interface/AddOns/MariscosMiniMapButtonHoarder/MariscosMiniMapButtonHoarder.toc`.
4. Start the game and enable the addon in the AddOns list.

## Use
- The hoarder button (lockbox icon) sits on the minimap rim; a small number shows how many
  buttons it holds.
- **Left-click**: the buttons come out from behind it into the chosen layout, facing away from
  the minimap. A gold ring shows while they are out. Left-click again to put them away.
- **Right-click**: settings. **Drag**: move the hoarder around the minimap.
- The layout turns as little as needed to stay on screen.
- **Hover zoom**: the button under the pointer grows a little (125% by default) in a quick, smooth
  ease and shrinks back when the pointer leaves. It grows in place, sits on top of its neighbours
  while big, and the other buttons don't move.
- **Tidy icons**: most minimap buttons draw their icon a little up and to the left of the hole
  in their round border, leaving a dark crescent. The hoarder centers every icon in the hole,
  makes it round and big enough to fill it, with a dark backing behind (the hoarder's own button
  too). Buttons that don't use the standard round border are left exactly as they are, and every
  icon goes back to its addon's own look when the button is given back.
- The hoarded buttons work exactly as before (click, right-click, tooltips).
- If an addon hides its own icon (e.g. "hide minimap button" in its options), it leaves the fan;
  showing it again brings it back.

## Settings (right-click the button, or `/mmbh config`)
The buttons come out while the window is open, so every change shows right away.
- **Button size**: 60% to 150% of the buttons' normal size.
- **Spacing**: 0 to 30 between buttons.
- **Grow on hover**: turn the hover zoom on or off.
- **Hover size**: how big the hovered button gets, 110% to 150% (greys out when Grow on hover is
  off).
- **Center and fill icons**: the tidy icons above, on or off.
- **Fold back after**: slider with 3, 5, 10 or 15 seconds. The timer counts while the pointer is
  away from the buttons (hovering them pauses it, and it stays open while a menu from one of them
  is open).
- **Until clicked out**: the buttons stay out until you click anywhere else (the timer slider
  greys out).
- **Layout** — hover an option and a small preview window pops up next to the settings playing
  that animation:
  - **Arch**: one wide semi-circle, evenly spaced end to end (a second arc only appears with more
    than about 15 buttons).
  - **Triangle**: point at the hoarder, rows of 1, 2, 3... widening away from it.
  - **Boxed**: a neat square-ish grid in front of the hoarder.
  - **Horizontal**: one row to the left or right, whichever side has room.
  - **Vertical**: one column up or down, whichever side has room.
- **Scan for buttons**: look for buttons from addons that loaded late.
- **Defaults**: back to 100%, spacing 6, hover zoom on at 125%, tidy icons on, 3 seconds, Arch.
- Escape or the X closes the window.

## What gets hoarded
- Every LibDBIcon button (most addons: Questie, Details, DBM, WeakAuras, Auctionator...).
- Other named, clickable, button-sized frames on the minimap rim (like Marisco's own addons).
- Left alone: Blizzard's minimap buttons (tracking, mail, clock, zoom, world map...), map pins and
  arrows (HandyNotes, GatherMate, Questie, TomTom...), and protected/secure frames.
- Use `/mmbh ignore <name>` to keep a button on the minimap, `/mmbh add <FrameName>` to take one
  the scan missed.

## Commands (`/mmbh`, or `/hoarder`)
- `/mmbh` — show / hide the buttons · `/mmbh config` — settings
- `/mmbh scan` — look for new buttons · `/mmbh list` — list hoarded and ignored buttons
- `/mmbh ignore <name>` · `/mmbh unignore <name>` — give a button back / allow it again
- `/mmbh add <FrameName>` — always hoard this frame
- `/mmbh layout arch|triangle|boxed|horizontal|vertical`
- `/mmbh size <60-150>` · `/mmbh gap <0-30>` · `/mmbh delay 3|5|10|15`
- `/mmbh hover on|off|<110-150>` — hover zoom · `/mmbh tidy` — tidy icons on/off
- `/mmbh autoclose` — switch between the timer and "until clicked out"
- `/mmbh spread <deg>` · `/mmbh radius <n>` — fine-tune the Arch (default 180° and 70)
- `/mmbh on` · `/mmbh off` — hoard, or give every button back to the minimap
- `/mmbh status` · `/mmbh reset` (position and settings; ignore/add lists are kept)

## Notes
- Buttons are given back exactly where (and at the size) their addon wants them (`/mmbh off`,
  `/mmbh ignore`, or disabling this addon and reloading).
- If an addon moves its button while it is hoarded, the move is remembered for later and the
  button stays in the fan.
- Other minimap-button collectors (MBB, MinimapButtonButton, ElvUI/SexyMap button bags...) will
  fight over the same buttons; use one at a time.
- Settings are saved per account.

## Changelog
- 0.5: Icons are centered in their round border and fill it (no more dark crescent at the
  bottom-right). Positions measured from the border texture itself. New "Center and fill icons"
  checkbox and `/mmbh tidy`.
- 0.4: Hover zoom — the button under the pointer grows smoothly and shrinks back when the pointer
  leaves. New "Grow on hover" checkbox and "Hover size" slider in the settings, `/mmbh hover`.
- 0.3: Right-click now opens a settings window: button size, spacing, fold-back timer
  (3/5/10/15 s) or "until clicked out", and five layouts (Arch, Triangle, Boxed, Horizontal,
  Vertical) with an animated preview on hover. Scan moved into the settings. The old 1.5 s
  fold-back becomes 3 s.
- 0.2: Buttons now sit on one evenly spaced semi-circle instead of small stacked rings (which
  looked like a triangle). New `/mmbh radius`.
- 0.1: First release.
