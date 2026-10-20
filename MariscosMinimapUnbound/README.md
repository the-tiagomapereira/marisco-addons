# Marisco's Minimap Unbound — v0.2 - Beta

For World of Warcraft: Forever 1.60.x (interface 16001).

Takes the stock minimap out of Edit Mode's screen-clamped cluster and splits it into parts you
can place one by one: the map, the top bar, the zone name, the tracking (search glass) button, the
clock, the calendar, the coordinates and anything else Forever puts there (mail indicator...).
Move the whole minimap flush against the screen edge or past it, or put any part wherever you
like. Adds a square shape and border skins.

## Why Edit Mode stops short of the edge
Edit Mode moves the whole minimap cluster: map, top bar, coordinates and some empty padding.
The cluster is clamped to the screen, so its invisible edges hit the border while the map you
see is still a few pixels away. This addon moves each visible part in its own unclamped holder.

## Install
1. Close WoW.
2. Extract the zip into your Forever client's `Interface/AddOns` folder
   (during the beta that is `_classic_beta_/Interface/AddOns`).
3. You should end up with `Interface/AddOns/MariscosMinimapUnbound/MariscosMinimapUnbound.toc`.
4. Start the game and enable the addon in the AddOns list.

## Use
- On login the minimap looks exactly like before: the addon measures the stock layout first and
  rebuilds it in the same spot.
- **Edit the layout**: left-click the minimap button (eagle-eye icon), the **Edit layout** button in
  the settings, or `/mmu edit`. Every part gets a highlight box and a small bar at the top of the
  screen explains the controls:
  - **Drag** any part: the whole minimap moves (every part that is still on it comes along).
  - **Shift + drag** a part: only that part moves. Example: Shift-drag the coordinates from under
    the map to wherever you want them.
  - **Right-click** a part: it goes back to its stock spot on the minimap.
    Right-click the map: the whole minimap goes back to its stock spot.
  - **Arrow keys** while hovering a box: 1 px (Ctrl: 10 px). Hold Shift to nudge only that part.
  - Boxes are **cyan** for parts that move with the minimap and **gold** for parts moved on
    their own. Smaller parts sit on top, so a button on the bar can be grabbed instead of the bar.
  - Parts the game only shows sometimes (mail, instance difficulty) still get a box; hover it to
    see "Hidden right now".
  - **Done** (or the minimap button again) finishes. **Put all back** returns every part to the map.
- **Snap**: dropped within 8 px of a screen edge, a part snaps flush against it. Positions are
  saved from the nearest screen corner, so an edge-flush part stays flush when the resolution or
  UI scale changes.
- Combat ends the editing.

## Settings
Left-click the minimap button or type `/mmu`. Everything shows live; **Save** keeps it,
**Default** loads the defaults (positions kept; press Save), **Cancel**, the X or Escape undoes
everything since the window opened.

**Map**
- **Shape**: Round or Square. Square also tells other addons (LibDBIcon buttons) the map is square
  so their buttons sit on the square edge.
- **Skin** (< >): Stock (Blizzard's ring; on a square map a thin dark line), Clean (no border),
  Thin line, Framed (color between two dark lines), Shadowed (color with a soft shadow),
  Tooltip and Dialog (the game's own borders; square only, round maps use Framed).
- **Border color** (click the swatch, with opacity) and **Border thickness** (1–8 px), for the
  skins that use them.
- **Map size** (120–320; the stock size is marked) and **Map opacity** (30–100%).
- **Hide the zoom buttons**, **Zoom with the mouse wheel** (only added if the client has no
  wheel zoom of its own).

**Layout**
- **Edit layout** (see Use), how many parts are moved on their own, and **Put all back**.
- **Bar sits**: Original (where Blizzard had it), Above or Below the map, for the bar parts that
  are still on the minimap.
- **Coordinates**: Forever's own, this addon's own readout, or Hidden. If Forever's coordinates
  can't be found (they're blank in instances), Auto uses the addon's own.

**Placement**
- **Keep on screen** (off by default, so the map can touch or pass the edge).
- **Snap to the screen edge when dropped near it** (on).
- **Reset everything to the stock spot**: the map and every part.

## Minimap button
- Left-click: edit the layout on/off · Right-click: settings · Drag: move the button around the map
  (follows the square edge too). `/mmu minimap` hides or shows it.
- It's a normal named button, so MiniMapButtonHoarder picks it up.

## Commands (`/mmu`, or `/minimapunbound`)
`/mmu` · `/mmu edit` · `/mmu back` · `/mmu square` · `/mmu round` · `/mmu skin <stock|clean|line|framed|shadow|tooltip|dialog>` ·
`/mmu size <80-400|stock>` · `/mmu clamp` · `/mmu snap` ·
`/mmu coords auto|own|hidden` · `/mmu zoom` · `/mmu wheel` · `/mmu reset` · `/mmu default` ·
`/mmu minimap` · `/mmu probe` · `/mmu off` · `/mmu on` · `/mmu status`

## Notes
- **Edit Mode is left alone.** The addon never moves or saves Edit Mode's minimap; Blizzard's
  own frames are only re-anchored. Edit Mode's Minimap box still shows at the old (now empty)
  spot; use `/mmu edit` instead. If Blizzard re-anchors a piece (e.g. after an Edit Mode change),
  the addon puts it back on the next frame.
- Which Blizzard frames make up the bar is found by name first (BorderTop, ZoneTextButton,
  Tracking, GameTimeFrame, TimeManagerClockButton, plus the classic names), then anything else in
  the cluster goes with what it overlaps (bar or map). Coordinates are found by frame name or by
  text that reads like "45.2, 63.1".
- **`/mmu probe`** opens a copyable report: every child of the minimap cluster, what was taken
  over and where it is now, every part and whether it was moved, what was left alone, the
  settings and the last 10 errors. If a part
  stays behind or lands in the wrong place, this report is what's needed to fix it.
- Errors go through the game's normal error handler, so Marisco's Bug Catcher sees them.
- `/mmu off` gives everything back to Blizzard; a `/reload` after it makes sure the layout is
  exactly stock.
- Other addons that also move or reshape the minimap (SexyMap, BasicMinimap, ElvUI...) will
  fight over it; use one at a time.
- Settings are saved per account.

## Changelog
- 0.2 (beta): Every part moves on its own: map, top bar, zone name, tracking, clock, calendar,
  coordinates and any extra part found in the minimap cluster. Edit layout mode (minimap button
  left-click, `/mmu edit`): drag moves the whole minimap, Shift+drag moves one part, right-click
  puts it back, arrow-key nudging, cyan/gold boxes, editing bar with Done and Put all back.
  Minimap button: left-click edits, right-click opens the settings. Replaces the bar/coordinates
  "attached" options (a detached v0.1 coordinates position is kept). `/mmu edit`, `/mmu back`.
- 0.1 (beta): First release. Map, top bar and coordinates in their own unclamped holders,
  move mode with arrow-key nudging and edge snapping, round/square, 7 border skins with color,
  thickness, size and opacity, zoom options, own coordinates, `/mmu probe` report.
