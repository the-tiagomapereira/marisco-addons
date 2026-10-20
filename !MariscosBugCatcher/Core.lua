-- Marisco's Bug Catcher - Core
-- Catches Lua errors, blocked/forbidden actions, Lua warnings and addon load failures.
-- The folder name starts with "!" so it loads before other addons and sees their load errors.

local ADDON, ns = ...
local SELF_TAG = "MariscosBugCatcher"
local format = string.format

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.VERSION = (GetMeta and GetMeta(ADDON, "Version")) or "0.1"

ns.MAX_UNIQUE = 150      -- unique entries kept per session
ns.MAX_STACK = 6000      -- characters
ns.MAX_LOCALS = 4000     -- characters

local defaults = {
    chat = true,            -- chat line for every new error
    sound = false,          -- sound for new errors
    flash = true,           -- minimap button glows on new errors
    autoOpen = false,       -- open the window on a new error (out of combat)
    blocked = true,         -- ADDON_ACTION_BLOCKED / FORBIDDEN
    warnings = true,        -- LUA_WARNING
    loadIssues = true,      -- addons that could not load
    ignoreBlizzard = false, -- skip errors from Blizzard's own UI
    blizzard = false,       -- also pass errors on to the game's own error window
    newestFirst = true,
    keep = 10,              -- sessions kept (sessions without errors are not kept)
    minimap = { angle = 215, hide = false },
}
ns.defaults = defaults

-- The current session. It goes into the saved variables once they are loaded.
local cur = { id = 0, start = time(), errors = {}, char = "?", client = "?" }
ns.cur = cur
local index = {}          -- key -> entry, current session only
ns.loggedIn = false

local function S(key)
    local db = ns.db
    if db and db.settings and db.settings[key] ~= nil then return db.settings[key] end
    return defaults[key]
end
ns.S = S

----------------------------------------------------------------------
-- Which addon is to blame
----------------------------------------------------------------------
local function isBlizzard(name)
    if not name then return false end
    return (name:find("^Blizzard_") or name == "FrameXML" or name == "SharedXML"
        or name == "GlueXML" or name == "Blizzard UI") and true or false
end
ns.IsBlizzard = isBlizzard

local function collect(text, out)
    if type(text) ~= "string" then return end
    for name in text:gmatch("[Aa]dd[Oo]ns[/\\]([^/\\\n\"%]]+)[/\\]") do out[#out + 1] = name end
    for name in text:gmatch("[Ii]nterface[/\\](%a+XML)[/\\]") do out[#out + 1] = name end
end

-- First addon named in the message, then the closest one in the stack.
-- Blizzard code is only blamed when no addon shows up at all.
function ns.FindAddon(msg, stack)
    local names = {}
    collect(msg, names)
    collect(stack, names)
    local blizz, self
    for _, name in ipairs(names) do
        if name:find(SELF_TAG, 1, true) then
            self = self or name
        elseif isBlizzard(name) then
            blizz = blizz or name
        else
            return name
        end
    end
    return blizz or self or "Unknown"
end

----------------------------------------------------------------------
-- Recording
----------------------------------------------------------------------
local listeners = {}
function ns.OnRecord(fn) listeners[#listeners + 1] = fn end
local function fire(e, isNew)
    for _, fn in ipairs(listeners) do pcall(fn, e, isNew) end
end

local function cut(s, max)
    if type(s) ~= "string" or s == "" then return nil end
    if #s > max then return s:sub(1, max) .. "\n... (cut)" end
    return s
end

-- Drops the leading stack lines that belong to this file's error handler.
local function cleanStack(stack)
    if type(stack) ~= "string" then return nil end
    local out, leading = {}, true
    for line in stack:gmatch("[^\n]+") do
        if leading and line:find(SELF_TAG, 1, true) and line:find("Core.lua", 1, true) then
            -- skip
        else
            leading = false
            out[#out + 1] = line
        end
    end
    return table.concat(out, "\n")
end

local function key(kind, msg) return kind .. "\001" .. msg end
function ns.Lookup(kind, msg) return index[key(kind, msg)] end

function ns.Record(kind, msg, stack, locals, addon, hint)
    msg = tostring(msg or "?")
    local k = key(kind, msg)
    local now = time()
    local e = index[k]
    if e then
        e.count = e.count + 1
        e.last = now
        fire(e, false)
        return e
    end
    stack = cleanStack(stack)
    addon = addon or ns.FindAddon(msg, stack)
    if S("ignoreBlizzard") and isBlizzard(addon) then return end
    if #cur.errors >= ns.MAX_UNIQUE then
        cur.dropped = (cur.dropped or 0) + 1
        return
    end
    e = {
        kind = kind, msg = msg, addon = addon, hint = hint,
        stack = cut(stack, ns.MAX_STACK), locals = cut(locals, ns.MAX_LOCALS),
        count = 1, time = now, last = now,
        combat = (InCombatLockdown and InCombatLockdown()) and true or nil,
    }
    cur.errors[#cur.errors + 1] = e
    index[k] = e
    fire(e, true)
    return e
end

function ns.ClearSession(sess)
    if not sess or sess == cur then
        wipe(cur.errors)
        wipe(index)
        cur.dropped = nil
    elseif ns.db then
        for i, s in ipairs(ns.db.sessions) do
            if s == sess then table.remove(ns.db.sessions, i) break end
        end
    end
    fire(nil, false)
end

function ns.ClearAll()
    if ns.db then
        wipe(ns.db.sessions)
        ns.db.sessions[1] = cur
    end
    ns.ClearSession(cur)
end

function ns.Counts(sess)
    sess = sess or cur
    local unique, total = 0, 0
    for _, e in ipairs(sess.errors) do
        if e.kind ~= "warning" then
            unique = unique + 1
            total = total + e.count
        end
    end
    return unique, total
end

----------------------------------------------------------------------
-- The Lua error handler
----------------------------------------------------------------------
local busy = false
local origHandler = geterrorhandler and geterrorhandler()

local function OnError(msg, ...)
    if not busy then
        busy = true
        local ok, m = pcall(tostring, msg)
        if not ok then m = "?" end
        local stack, locals
        if not ns.Lookup("error", m) then
            -- Level 1 is this handler; level 2 is where the error happened.
            stack = debugstack and debugstack(2) or nil
            local okL, l = pcall(debuglocals, 3)
            if not okL or not l or l == "" then okL, l = pcall(debuglocals, 2) end
            locals = okL and l or nil
        end
        pcall(ns.Record, "error", m, stack, locals)
        busy = false
    end
    if S("blizzard") and origHandler and origHandler ~= OnError then
        return origHandler(msg, ...)
    end
    return msg
end
ns.OnError = OnError
if seterrorhandler then seterrorhandler(OnError) end

ns.handlerBlocked = false
function ns.EnsureHandler()
    if not geterrorhandler or not seterrorhandler or ns.handlerBlocked then return end
    local h = geterrorhandler()
    if h ~= OnError then
        if h then origHandler = h end
        seterrorhandler(OnError)
        if geterrorhandler() ~= OnError then
            ns.handlerBlocked = true
            if ns.loggedIn then
                print("|cffff5555[Bug Catcher]|r Another error catcher (BugGrabber, BugSack, ElvUI...) holds the Lua error handler. Lua errors can't be caught; blocked actions and load problems still are. Use one error catcher at a time.")
            end
        end
    end
end
if hooksecurefunc and seterrorhandler then
    hooksecurefunc("seterrorhandler", function(h)
        if h ~= OnError and not ns.handlerBlocked and C_Timer then C_Timer.After(0, ns.EnsureHandler) end
    end)
end

----------------------------------------------------------------------
-- Hints shown with non-Lua problems
----------------------------------------------------------------------
local HINT_FORBIDDEN = "Taint: the addon touched something only Blizzard's own code may use. Common causes: "
    .. "writing into a Blizzard table or global (StaticPopupDialogs, UIPanelWindows, a Blizzard frame's fields), "
    .. "replacing a Blizzard function instead of using hooksecurefunc, or calling a protected function. "
    .. "The function named above is where the game noticed it, not always where the addon did it."
local HINT_BLOCKED = "A protected action was called by addon code, usually during combat "
    .. "(showing/hiding/moving secure frames, changing action bars, targeting, casting). "
    .. "Wait for PLAYER_REGEN_ENABLED before doing it, or use secure templates."
local LOAD_HINT = {
    INTERFACE_VERSION = "The addon's .toc '## Interface:' is not 16001. Update the number, or tick 'Load out of date AddOns' in the AddOns list.",
    DEP_MISSING = "A '## Dependencies' / '## RequiredDeps' addon in its .toc is not installed.",
    DEP_DISABLED = "An addon it depends on is disabled.",
    DEP_INTERFACE_VERSION = "An addon it depends on is out of date.",
    CORRUPT = "The .toc or its files could not be read. Check the folder name matches the .toc name.",
    MISSING = "The addon folder or its .toc file is missing.",
    INCOMPATIBLE = "The addon is not made for this client.",
}
local LOAD_REASONS = {
    INTERFACE_VERSION = true, DEP_MISSING = true, DEP_CORRUPT = true, DEP_INCOMPATIBLE = true,
    DEP_INTERFACE_VERSION = true, DEP_BANNED = true, CORRUPT = true, MISSING = true,
    INCOMPATIBLE = true, BANNED = true,
}

function ns.CheckLoadIssues()
    if not S("loadIssues") then return end
    local num = (C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns
    local info = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
    if not num or not info then return end
    for i = 1, num() do
        local name, _, _, _, reason = info(i)
        if name and reason and LOAD_REASONS[reason] then
            local text = _G["ADDON_" .. reason] or reason
            ns.Record("load", format("%s could not load: %s", name, text), nil, nil, name,
                LOAD_HINT[reason] or LOAD_HINT[reason:gsub("^DEP_", "")])
        end
    end
end

----------------------------------------------------------------------
-- Notifications (chat, sound); the UI adds the minimap glow
----------------------------------------------------------------------
local lastChat, lastSound, held, flushQueued, loadHeld = 0, 0, 0, false, 0

local function firstLine(s)
    s = (s or ""):match("^[^\n]*") or ""
    s = s:gsub("^.-[Aa]dd[Oo]ns[/\\]", "")   -- shorten the path
    if #s > 140 then s = s:sub(1, 137) .. "..." end
    return s
end

local function flush()
    flushQueued = false
    if held > 0 then
        print(format("|cffff5555[Bug Catcher]|r %d more new error%s. Type |cffffd100/mbc|r to see them.", held, held == 1 and "" or "s"))
        held = 0
        lastChat = GetTime()
    end
end

ns.OnRecord(function(e, isNew)
    if not e or not isNew or e.kind == "warning" then return end
    if not ns.loggedIn then
        loadHeld = loadHeld + 1
        return
    end
    local now = GetTime()
    if S("chat") then
        if now - lastChat >= 3 then
            print(format("|cffff5555[Bug Catcher]|r |cffffd100%s|r: %s |cff888888(/mbc)|r",
                e.addon or "Unknown", firstLine(e.msg)))
            lastChat = now
        else
            held = held + 1
            if not flushQueued and C_Timer then
                flushQueued = true
                C_Timer.After(3, flush)
            end
        end
    end
    if S("sound") and now - lastSound >= 5 then
        lastSound = now
        PlaySound((SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
    end
    if S("autoOpen") and ns.ShowWindow and not InCombatLockdown() then ns.ShowWindow() end
end)

----------------------------------------------------------------------
-- Saved variables and events
----------------------------------------------------------------------
local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for a, b in pairs(v) do t[a] = copy(b) end
    return t
end

function ns.TrimSessions()
    local list = ns.db.sessions
    -- Old sessions without anything caught are not worth keeping.
    for i = #list, 1, -1 do
        if list[i] ~= cur and #list[i].errors == 0 then table.remove(list, i) end
    end
    local keep = math.max(1, tonumber(S("keep")) or 10)
    while #list > keep do table.remove(list, 1) end
end

function ns.ResetSettings()
    ns.db.settings = copy(defaults)
end

local function initDB()
    MariscosBugCatcherDB = type(MariscosBugCatcherDB) == "table" and MariscosBugCatcherDB or {}
    local db = MariscosBugCatcherDB
    db.settings = type(db.settings) == "table" and db.settings or {}
    for k, v in pairs(defaults) do
        if db.settings[k] == nil then db.settings[k] = copy(v) end
    end
    if type(db.settings.minimap) ~= "table" then db.settings.minimap = copy(defaults.minimap) end
    db.sessions = type(db.sessions) == "table" and db.sessions or {}
    db.counter = (tonumber(db.counter) or 0) + 1
    cur.id = db.counter
    if GetBuildInfo then
        local version, build, _, toc = GetBuildInfo()
        cur.client = format("%s (build %s), interface %s, %s", tostring(version), tostring(build), tostring(toc), GetLocale and GetLocale() or "?")
    end
    db.sessions[#db.sessions + 1] = cur
    ns.db = db
    ns.TrimSessions()
end

local ev = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD",
    "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "MACRO_ACTION_BLOCKED", "MACRO_ACTION_FORBIDDEN",
    "LUA_WARNING", "SAVED_VARIABLES_TOO_LARGE" }) do
    pcall(ev.RegisterEvent, ev, event)   -- an event this client doesn't know is just skipped
end

ev:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "ADDON_LOADED" then
        if a1 == ADDON then initDB() end

    elseif event == "PLAYER_LOGIN" then
        local name, realm = UnitName("player"), GetRealmName and GetRealmName() or ""
        cur.char = (name or "?") .. (realm ~= "" and ("-" .. realm) or "")
        local _, class = UnitClass("player")
        cur.class = class
        ns.loggedIn = true
        ns.EnsureHandler()
        ns.CheckLoadIssues()
        if ns.handlerBlocked then
            print("|cffff5555[Bug Catcher]|r Another error catcher (BugGrabber, BugSack, ElvUI...) holds the Lua error handler. Lua errors can't be caught; blocked actions and load problems still are. Use one error catcher at a time.")
        end
        local unique = ns.Counts(cur)
        if unique > 0 and S("chat") then
            print(format("|cffff5555[Bug Catcher]|r %d problem%s caught while the UI loaded. Type |cffffd100/mbc|r to see %s.",
                unique, unique == 1 and "" or "s", unique == 1 and "it" or "them"))
            lastChat = GetTime()
        end
        loadHeld = 0
        if ns.OnLogin then ns.OnLogin() end
        if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(30, ns.EnsureHandler) end

    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.EnsureHandler()

    elseif event == "ADDON_ACTION_FORBIDDEN" or event == "ADDON_ACTION_BLOCKED" then
        if not S("blocked") then return end
        local addon, func = a1 or "Unknown", (tostring(a2 or "?"):gsub("%(%)$", ""))
        if event == "ADDON_ACTION_FORBIDDEN" then
            ns.Record("blocked", format("%s has been blocked from an action only available to the Blizzard UI: %s()", addon, func),
                nil, nil, addon, HINT_FORBIDDEN)
        else
            ns.Record("blocked", format("%s was blocked from calling the protected function %s()", addon, func),
                nil, nil, addon, HINT_BLOCKED)
        end

    elseif event == "MACRO_ACTION_FORBIDDEN" or event == "MACRO_ACTION_BLOCKED" then
        if not S("blocked") then return end
        ns.Record("blocked", format("A macro was blocked from calling %s()", tostring(a1)), nil, nil, "Macro", HINT_BLOCKED)

    elseif event == "LUA_WARNING" then
        if not S("warnings") then return end
        local text = a2 or a1
        ns.Record("warning", tostring(text), nil, nil, ns.FindAddon(tostring(text)))

    elseif event == "SAVED_VARIABLES_TOO_LARGE" then
        ns.Record("warning", format("Saved variables of %s are too large; the game did not load them.", tostring(a1)),
            nil, nil, tostring(a1), "The addon's saved data file in WTF is too big. It will start fresh unless the file is trimmed.")
    end
end)
