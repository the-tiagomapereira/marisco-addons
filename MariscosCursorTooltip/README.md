# Marisco's Cursor Tooltip — v1.0

For World of Warcraft: Forever 1.60.x (interface 16001).

Anchors the game tooltip (items, spells, action buttons, units, buffs, everything that uses
the standard tooltip) to the mouse pointer instead of its fixed spot. You choose where around
the pointer it appears.

## Install
1. Close WoW.
2. Extract the zip into your Forever client's `Interface/AddOns` folder
   (during the beta that is `_classic_beta_/Interface/AddOns`).
3. You should end up with `Interface/AddOns/MariscosCursorTooltip/MariscosCursorTooltip.toc`.
4. Start the game and enable the addon in the AddOns list.

## Settings
Type `/mct` or left-click the minimap button (spyglass icon). Everything is on one screen:

**Center of the screen — tooltip position.** A pointer with a circle around it and a preview tooltip
that you drag with the left mouse button. The yellow dot marks the corner or edge of the
tooltip that faces the pointer, and it stays inside the circle. Scroll the mouse wheel
(outside the panel) to make the circle bigger or smaller. If the cursor ring is on, it's
drawn around the preview pointer too.

**Settings panel** in the game's own window style, titled with the addon version. It opens right beside the circle; drag it
by its title bar or any empty spot to move it, and it reopens where you left it. It has
three sections:
- **Tooltip position**: circle size (100–200, 150 default) with a slider, "Anchor the
  tooltip to the cursor", "Follow the cursor while it moves".
- **Cursor ring**: on/off, **Pulse the ring when you click** (a soft ripple that grows out
  from the cursor and fades on every left or right click; works even with the ring itself
  off), **Color** (a round preview of the ring in the chosen color and opacity; click it for
  the color picker), **Opacity**, **Radius**, **Thickness**.
- **Cursor trail (beta)**: on/off, **Fade time**, **Size**. Uses the ring's color and opacity.

Changes show live. **Save** keeps everything. **Default** loads the original tooltip position
(top right of the pointer) and the original ring/trail look, without switching the ring, pulse or
trail on or off, and moves the panel back beside the circle; press Save to keep it. **Cancel**, the X or ESC closes and puts every
setting back the way it was.

To go straight back to the original tooltip position, type `/mct reset`.

Near the screen edges the tooltip still flips to the other side of the pointer so it stays
visible. The ring and trail hide while you turn the camera with the mouse.

## Minimap button
- Left-click: settings
- Right-click: cursor ring on/off
- Drag: move the button around the minimap
- `/mct minimap` hides or shows it

## Commands (`/mct`, or the old `/ctt`)
- `/mct` — open the settings
- `/mct ring` · `/mct pulse` · `/mct trail` — turn the cursor ring / click pulse / trail on or off
- `/mct reset` — back to the original position (top right of the pointer)
- `/mct follow` — tooltip follows the pointer as you move (default)
- `/mct stick` — tooltip is placed at the pointer when it appears, then stays put
- `/mct offset <x> <y>` — set the offset by hand
- `/mct on` · `/mct off` · `/mct toggle` · `/mct minimap` · `/mct status`

## Notes
- Item comparison tooltips and panels attached to the tooltip (like the Item Value Scanner
  panel) move along with it.
- Clicked chat links open in their own window (ItemRefTooltip) and are left alone.
- Settings are saved per account. Your v0.2 settings carry over.

## Changelog
- **1.0 — release**: Window title centered in the title bar (between the portrait and the
  close button); version marked 1.0. Includes everything below. The cursor trail is still
  labelled beta.
- 0.7.2 Beta: Sliders restyled: label top-left, value top-right in yellow, slider across the
  full width with equal margins.
- 0.7.1 Beta: Every slider shows its number, with equal spacing between slider, number and
  window edge; circle size reads "150 default"; more space above it; smaller title with the
  version in white.
- 0.7 Beta: Version shown in the centered window title; circle-size slider (100–200) with
  "by default" hint; round ring preview as the color picker; sliders run to the panel margin;
  more space under the section headings.
- 0.6: Optional click pulse: a subtle ripple of the cursor ring on every left/right click.
- 0.5.1: Pointer, circle and preview centered on the screen; settings panel opens beside
  the circle and can be dragged (position remembered).
- 0.5: Position setup and ring/trail options combined into one settings screen; Save,
  Default and Cancel cover everything; ring preview around the setup pointer; minimap
  right-click toggles the cursor ring.
- 0.4: Cursor ring (color, opacity, radius, thickness), fading cursor trail (beta), options
  window on minimap right-click or `/mct options`.
- 0.3.2: Setup panel titled "Marisco's Cursor Tooltip" and built from the game's own window,
  inset and tooltip styles so it matches the Forever UI.
- 0.3.1: Save/Default/Cancel moved into a framed panel below the circle.
- 0.3: Drag-and-drop position setup (`/mct` or minimap button) with a circle around the
  pointer, Default/reset to the original position, minimap button, `/mct` command.
- 0.2: Fixed the tooltip briefly stretching to the right edge of the screen when moving the
  pointer between players.
- 0.1: First release.
