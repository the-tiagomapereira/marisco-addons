# Marisco's Bug Catcher — v0.1.2 - Beta

For World of Warcraft: Forever 1.60.x (interface 16001).

Catches every Lua error, blocked action (taint), Lua warning and addon that fails to load during
your session, tells you which addon caused it, and keeps the full message, stack and locals ready
to copy. Made for debugging your own addons.

## Install
1. Close WoW.
2. Extract the zip into your Forever client's `Interface/AddOns` folder
   (during the beta that is `_classic_beta_/Interface/AddOns`).
3. You should end up with `Interface/AddOns/!MariscosBugCatcher/!MariscosBugCatcher.toc`.
   The `!` is on purpose: it makes the addon load before all others, so it also catches the
   errors other addons throw while they load.
4. Start the game and enable the addon in the AddOns list.
5. After login, chat shows "[Bug Catcher] v0.1.2 is watching for errors". No line means the
   addon isn't loading at all (check the folder and that it's ticked in the AddOns list).

## What it catches
- **Lua errors** from any addon (or Blizzard's own UI): message, stack trace and local variables.
- **Blocked actions**: "X has been blocked from an action only available to the Blizzard UI"
  (taint) and protected functions called in combat, with a short explanation of the usual causes.
- **Addons that failed to load**: out of date `## Interface`, missing dependencies, corrupt or
  missing files. Checked at every login and reload.
- **Lua warnings** (XML problems, missing inherited templates...) and saved variables too large to load.

The addon to blame is read from the file paths in the message and stack: the first non-Blizzard
addon wins, so an error inside Blizzard code called by your addon is still put on your addon.
The same error happening again only raises its count (x2, x3...), so an error in an OnUpdate
doesn't flood anything.

## Use
- On a new error: a chat line with the addon and the first line of the message (at most one every
  3 seconds; the rest are summed up), and the minimap button (insect swarm icon) glows red with a
  count of this session's errors.
- `/mbc` or left-click the minimap button opens the window:
  - **Session** arrows: the current session and the last 10 that caught something (each login or
    `/reload` is a new session, so errors from before a reload are still there).
  - **AddOn** arrows: show only one addon's entries. **Warnings** tick box. **Search** box.
  - The list: count, time, type (Error, Blocked, Load, Warning), addon, message. Hover for the
    full message, click to see the details below.
  - **Details**: message, what it means (for blocked/load entries), stack and locals.
    **Copy** selects it for Ctrl+C.
  - **Copy all**: a full report of everything in the list (client build, addon versions, every
    entry) selected for Ctrl+C, ready to paste into a chat with Claude.
  - **Clear** (this session) and **Clear all** need a second click to confirm. **Reload UI**.
- Right-click the minimap button: summary per addon in chat. Drag to move it.

## Settings (Settings button or `/mbc config`)
Chat message for new errors, sound for new errors, flash the minimap button, open the window on
a new error (out of combat), catch blocked actions, catch Lua warnings, report addons that failed
to load, ignore errors in Blizzard's own UI, also show the game's error window, newest first,
minimap button, sessions kept (1-50, default 10). Changes apply at once; **Defaults** resets them.

## Commands (`/mbc`, or `/bugcatcher`)
`/mbc` · `/mbc test` (throws a test error to check it works) · `/mbc last` · `/mbc clear` ·
`/mbc clearall` · `/mbc config` · `/mbc chat` · `/mbc sound` · `/mbc minimap` · `/mbc status` · `/mbc reset`

## Notes
- Errors are saved per account (`MariscosBugCatcherDB`), up to 150 unique entries per session.
  Sessions with nothing caught are not kept.
- Problems in Bug Catcher itself are printed in chat as "[Bug Catcher] internal error: ...";
  they are never hidden in its own list.
- If the client doesn't let addons own the Lua error handler, Bug Catcher says so at login and
  reads errors from the game's own error window instead. Any setup step that failed is listed in
  grey as "[Bug Catcher] setup: ...".
- Use one error catcher at a time. If BugGrabber/BugSack (or ElvUI's) holds the Lua error handler,
  the window says so: Lua errors can't be caught then, blocked actions and load problems still are.
- Errors from Blizzard's own UI before any addon loads can't be caught by any addon.
- Forever runs on the modern client: the addon doesn't touch the combat log or Blizzard tables,
  so it can't cause taint itself.
- The minimap button is a normal named button, so MiniMapButtonHoarder picks it up.

## Changelog
- 0.1.2: Fixed "could not start: saved data not loaded": the file stopped loading when the client
  refused a call that sets up error catching. Every such call is now protected and reported, and
  errors are read from the game's error window when the handler can't be set. `/mbc` says where
  loading stopped if it still can't start.
- 0.1.1: Fixed `/mbc` doing nothing when the saved data wasn't set up: setup is retried at login
  and on `/mbc`, and the reason is printed if it still fails. Errors in Bug Catcher's own code now
  go to chat instead of being swallowed. Login line confirms the addon is running.
- 0.1: First release.
