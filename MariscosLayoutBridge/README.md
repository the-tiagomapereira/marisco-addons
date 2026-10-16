# Marisco's Layout Bridge — v0.2 - Beta

For World of Warcraft: Forever 1.60.x (interface 16001).

Converts Edit Mode layout strings from retail (or any other modern client) so WoW: Forever
accepts them, and blends them with one of your own layouts so the result is a usable
approximation rather than retail positions dropped onto Forever's frames.

## Why retail strings fail on Forever
- Forever's string header is `<version> <interfaceStyle> <frame count>`, e.g. `5 0 59`.
- Retail's older header is `<version> <frame count>`, e.g. `2 50`.
- Forever's decoder reads every header as its own form, so `2 50 ...` gives
  `interfaceStyle = 50`. Valid styles are 0 (Modern/Classic) and 1 (Gamepad), so saving fails
  with `bad argument #4 ... [layouts,interfaceStyle]`.

## Why an imported retail layout looks wrong
- Frames the author never moved are flagged "default position". Retail's defaults are not
  Forever's, so those frames land in Forever's default spots and pile up on the author's frames.
- Frames anchored to retail-only frames (e.g. `MicroButtonAndBagsBar`) have nothing to attach to.
- Positions are offsets; on a smaller UI space they can run past the screen edge.

## Install
1. Close WoW.
2. Extract the zip into your Forever client's `Interface/AddOns` folder
   (during the beta that is `_classic_beta_/Interface/AddOns`).
3. You should end up with `Interface/AddOns/MariscosLayoutBridge/MariscosLayoutBridge.toc`.
4. Start the game and enable the addon in the AddOns list.

## Use
1. `/mlb` (or `/layoutbridge`, or click the minimap button, map icon) opens the converter.
2. Paste the retail layout string in box 1 and give it a name.
3. **Template**: use the arrows to pick one of your own layouts (your saved layouts come first,
   presets last). It fills in everything the retail string doesn't.
4. **Take from the string**: tick the parts to copy from the retail layout: Action bars, Unit
   frames, Cast bar, Buffs & debuffs, Minimap, Chat, Quest tracker, Bags & menu, XP / rep bars,
   Cooldowns & resource, Everything else. Unticked parts stay exactly like your template.
5. Options:
   - **Frames the author never moved keep my position** (on): default-flagged frames take your
     template's position instead of Forever's default.
   - **Keep frames on screen** (on): offsets that would push a frame past the screen edge are
     pulled back in.
6. Press **Convert**. The report says what changed. Box 2 holds the Forever-ready string, already
   selected: press Ctrl+C.
7. Open Edit Mode > layout dropdown > **Import**, paste, and save.
8. If something goes wrong, **Copy details** opens a window with the report and the full debug
   output, already selected for Ctrl+C.

Template, ticked groups and options are remembered.

## What the conversion does
- Rewrites an older header to Forever's form (`2 50 ...` -> `5 0 50 ...`) before decoding.
- Checks `interfaceStyle` against the styles Forever's own layouts use.
- Frames Forever doesn't have are dropped; frames the string lacks (e.g. Forever's systems
  24-29) take your template's position.
- Frames attached to parents Forever doesn't have take your template's position.
- Settings Forever doesn't know are removed; settings it needs are filled from your template.
- Re-encodes with Forever's own encoder (format 5) and checks that it reads back.

The addon never saves layouts itself: Blizzard's import does that, so nothing gets tainted.

## Commands
`/mlb` · `/mlb minimap` · `/mlb debug` (prints the fields of every Forever layout the client
has, Edit Mode's save list, whether each layout encodes, and the last conversion's error)

## Notes
- Expect an approximation: retail frames differ in size, so some hand-tuning in Edit Mode is
  normal. Converting only some groups (e.g. unit frames and buffs) gives the cleanest result.
- The minimap button is a normal named button, so MiniMapButtonHoarder picks it up.

## Changelog
- 0.2: Template picker (your own layouts first, never the active preset by default). Group
  checkboxes to take only parts of the retail layout. Frames the author left at retail's default
  now keep your template position. Off-screen offsets are pulled back in. Settings are remembered.
- 0.1.4: Debug output lists Edit Mode's save list.
- 0.1.3: Fixed "Current Field: [interfaceStyle]": older headers are rewritten before decoding,
  and invalid interface styles are corrected. Presets no longer add `layoutIndex`.
- 0.1.2: **Copy details** button with the report and debug output as selectable text.
- 0.1.1: `interfaceStyle` always added; encoder errors shown; `/mlb debug`.
- 0.1: First release.
