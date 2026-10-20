# Marisco's Minimap Unbound — v0.1 - Beta

For World of Warcraft: Forever 1.60.x (interface 16001).

Takes the stock minimap (the map, the top bar with the search glass, zone, server time and
calendar, and the coordinates) out of Edit Mode's screen-clamped cluster so you can place it
anywhere, flush against the screen edge or even past it. Adds a square shape and border skins.

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
- **Moving**: right-click the minimap button (eagle-eye icon) or `/mmu move`. Cyan boxes show the
  Minimap, Top bar and Coordinates. Drag them. Hover a box and use the **arrow keys** for 1 px
  steps, **Shift + arrows** for 10 px. Right-click again (or `/mmu move`) to lock.
  While the bar or coordinates are attached, dragging them moves the whole minimap.
- **Snap**: dropped within 8 px of a screen edge, a piece snaps flush against it. Positions are
  saved from the nearest screen corner, so an edge-flush minimap stays flush when the resolution
  or UI scale changes.
- Combat closes move mode.

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

**Top bar and coordinates**
- **Top bar stays attached to the map** (on): the bar moves with the map. Off: it's its own piece.
- **Bar sits**: Original (where Blizzard had it), Above or Below the map.
- **Coordinates stay attached to the map** (on), or a free piece.
- **Coordinates**: Forever's own, this addon's own readout, or Hidden. If Forever's coordinates
  can't be found (they're blank in instances), Auto uses the addon's own.

**Placement**
- **Keep on screen** (off by default, so the map can touch or pass the edge).
- **Snap to the screen edge when dropped near it** (on).
- **Move pieces** / **Reset positions** (back to the stock spot).

## Minimap button
- Left-click: settings · Right-click: move pieces on/off · Drag: move the button around the map
  (follows the square edge too). `/mmu minimap` hides or shows it.
- It's a normal named button, so MiniMapButtonHoarder picks it up.

## Commands (`/mmu`, or `/minimapunbound`)
`/mmu` · `/mmu move` · `/mmu square` · `/mmu round` · `/mmu skin <stock|clean|line|framed|shadow|tooltip|dialog>` ·
`/mmu size <80-400|stock>` · `/mmu clamp` · `/mmu snap` · `/mmu attach bar|coords` ·
`/mmu coords auto|own|hidden` · `/mmu zoom` · `/mmu wheel` · `/mmu reset` · `/mmu default` ·
`/mmu minimap` · `/mmu probe` · `/mmu off` · `/mmu on` · `/mmu status`

## Notes
- **Edit Mode is left alone.** The addon never moves or saves Edit Mode's minimap; Blizzard's
  own frames are only re-anchored. Edit Mode's Minimap box still shows at the old (now empty)
  spot; use `/mmu move` instead. If Blizzard re-anchors a piece (e.g. after an Edit Mode change),
  the addon puts it back on the next frame.
- Which Blizzard frames make up the bar is found by name first (BorderTop, ZoneTextButton,
  Tracking, GameTimeFrame, TimeManagerClockButton, plus the classic names), then anything else in
  the cluster goes with what it overlaps (bar or map). Coordinates are found by frame name or by
  text that reads like "45.2, 63.1".
- **`/mmu probe`** opens a copyable report: every child of the minimap cluster, what was taken
  over and where it is now, what was left alone, the settings and the last 10 errors. If a part
  stays behind or lands in the wrong place, this report is what's needed to fix it.
- Errors go through the game's normal error handler, so bug-catching addons see them.
- `/mmu off` gives everything back to Blizzard; a `/reload` after it makes sure the layout is
  exactly stock.
- Other addons that also move or reshape the minimap (SexyMap, BasicMinimap, ElvUI...) will
  fight over it; use one at a time.
- Settings are saved per account.

## Changelog
- 0.1 (beta): First release. Map, top bar and coordinates in their own unclamped holders,
  move mode with arrow-key nudging and edge snapping, round/square, 7 border skins with color,
  thickness, size and opacity, zoom options, own coordinates, `/mmu probe` report.
