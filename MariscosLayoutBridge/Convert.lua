-- Marisco's Layout Bridge: conversion logic.
-- Takes an Edit Mode layout string from retail (or any other modern client),
-- lets the game decode it, then fills in whatever WoW: Forever expects
-- (interfaceStyle and any other new fields, missing frames, missing settings),
-- and re-encodes it with Forever's own encoder so the result is a native string.

local _, ns = ...
ns = ns or {}
MariscosLayoutBridge = ns

local SKIP_TOP = { systems = true, layoutName = true, layoutType = true }

local function DeepCopy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = DeepCopy(x) end
    return t
end
ns.DeepCopy = DeepCopy

local function SysKey(s)
    return tostring(s.system) .. ":" .. tostring(s.systemIndex or -1)
end

local function Trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

-- A frame name is usable as an anchor if the client actually has that frame.
local function FrameExists(name)
    if name == nil or name == "" or name == "UIParent" then return true end
    local f = _G[name]
    return type(f) == "table" and type(f.GetObjectType) == "function"
end
ns.FrameExists = FrameExists

-- The layout Forever is using right now: the template for every field it expects.
-- Every source of a "real" Forever layout the client can give us.
function ns.GetLayoutSources()
    local sources = {}
    local mgr = EditModeManagerFrame
    if mgr and mgr.GetActiveLayoutInfo then
        local ok, info = pcall(mgr.GetActiveLayoutInfo, mgr)
        if ok and type(info) == "table" and info.systems then sources[#sources + 1] = { "active layout", info } end
    end
    if C_EditMode and C_EditMode.GetLayouts then
        local ok, all = pcall(C_EditMode.GetLayouts)
        if ok and all and all.layouts then
            for i, l in ipairs(all.layouts) do
                if type(l) == "table" and l.systems then sources[#sources + 1] = { "saved layout " .. i, l } end
            end
        end
    end
    if EditModePresetLayoutManager and EditModePresetLayoutManager.GetCopyOfPresetLayouts then
        local ok, presets = pcall(EditModePresetLayoutManager.GetCopyOfPresetLayouts, EditModePresetLayoutManager)
        if ok and type(presets) == "table" then
            for i, l in ipairs(presets) do
                if type(l) == "table" and l.systems then sources[#sources + 1] = { "preset " .. i, l, true } end
            end
        end
    end
    return sources
end

-- Layouts the player can pick as the template: their own saved layouts first,
-- then the presets. The active layout is whichever of these is selected in Edit Mode.
function ns.GetTemplateChoices()
    local choices, seen = {}, {}
    for _, src in ipairs(ns.GetLayoutSources()) do
        local l = src[2]
        local name = l.layoutName
        if src[1] ~= "active layout" and name and not seen[name] then
            seen[name] = true
            choices[#choices + 1] = { name = name, layout = l, preset = src[3] and true or false }
        end
    end
    table.sort(choices, function(a, b)
        if a.preset ~= b.preset then return not a.preset end
        return false
    end)
    return choices
end

-- The template supplies everything the retail string does not: missing frames,
-- frames left at their default, unticked groups, and any fields Forever needs.
-- Default: the player's first own saved layout, never a preset.
function ns.GetReferenceLayout(templateName)
    local choices = ns.GetTemplateChoices()
    local pick
    for _, c in ipairs(choices) do
        if c.name == templateName then pick = c break end
    end
    if not pick then
        for _, c in ipairs(choices) do
            if not c.preset then pick = c break end
        end
    end
    pick = pick or choices[1]
    if not pick then
        local sources = ns.GetLayoutSources()
        if not sources[1] then return nil end
        pick = { name = sources[1][2].layoutName, layout = sources[1][2] }
    end
    local ref = DeepCopy(pick.layout)
    -- Top up fields from the player's other saved layouts (never presets:
    -- they carry preset-only fields like layoutIndex).
    for _, c in ipairs(choices) do
        if not c.preset then
            for k, v in pairs(c.layout) do
                if ref[k] == nil and not SKIP_TOP[k] then ref[k] = DeepCopy(v) end
            end
        end
    end
    ref.layoutIndex = nil
    return ref, pick.name
end

-- Which part of the UI each Edit Mode system belongs to.
ns.GROUPS = {
    { key = "bars",      label = "Action bars",          systems = { 0, 4, 5 } },
    { key = "unit",      label = "Unit frames",          systems = { 3 } },
    { key = "cast",      label = "Cast bar",             systems = { 1 } },
    { key = "auras",     label = "Buffs & debuffs",      systems = { 6 } },
    { key = "minimap",   label = "Minimap",              systems = { 2 } },
    { key = "chat",      label = "Chat",                 systems = { 8 } },
    { key = "tracker",   label = "Quest tracker",        systems = { 12 } },
    { key = "menu",      label = "Bags & menu",          systems = { 13, 14 } },
    { key = "status",    label = "XP / rep bars",        systems = { 15 } },
    { key = "cooldowns", label = "Cooldowns & resource", systems = { 20, 21, 22, 23 } },
    { key = "other",     label = "Everything else",      systems = {} },
}
local GROUP_OF = {}
for _, g in ipairs(ns.GROUPS) do
    for _, sys in ipairs(g.systems) do GROUP_OF[sys] = g.key end
end
local function GroupOf(system) return GROUP_OF[system] or "other" end

-- Pull an anchor back inside the screen when its offset would push the frame off it.
local MARGIN = 40
local function ClampAnchor(a)
    if type(a) ~= "table" or (a.relativeTo and a.relativeTo ~= "UIParent") then return false end
    if not (UIParent and UIParent.GetWidth) then return false end
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    if not (W and H and W > 0 and H > 0) then return false end
    local rp = tostring(a.relativePoint or a.point or "CENTER")
    local x, y = a.offsetX or 0, a.offsetY or 0
    local minX, maxX, minY, maxY
    if rp:find("LEFT") then minX, maxX = 0, W - MARGIN
    elseif rp:find("RIGHT") then minX, maxX = -(W - MARGIN), 0
    else minX, maxX = -(W / 2 - MARGIN), W / 2 - MARGIN end
    if rp:find("TOP") then minY, maxY = -(H - MARGIN), 0
    elseif rp:find("BOTTOM") then minY, maxY = 0, H - MARGIN
    else minY, maxY = -(H / 2 - MARGIN), H / 2 - MARGIN end
    local nx = math.max(minX, math.min(maxX, x))
    local ny = math.max(minY, math.min(maxY, y))
    if nx ~= x or ny ~= y then
        a.offsetX, a.offsetY = nx, ny
        return true
    end
    return false
end

local function Decode(str)
    local ok, info = pcall(C_EditMode.ConvertStringToLayoutInfo, str)
    if ok and type(info) == "table" and info.systems then return info end
    return nil, (not ok) and tostring(info) or "no layout returned"
end

local function Encode(info)
    local ok, str = pcall(C_EditMode.ConvertLayoutInfoToString, info)
    if ok and type(str) == "string" and str ~= "" then return str end
    return nil, (not ok) and tostring(str) or "empty result"
end

-- interfaceStyle values the client actually uses (Modern/Classic 0, Gamepad 1, ...).
local function ValidStyles()
    local valid = { [0] = true }
    for _, src in ipairs(ns.GetLayoutSources()) do
        local v = src[2].interfaceStyle
        if type(v) == "number" then valid[v] = true end
    end
    return valid
end

local function PreferredStyle(ref)
    if ref and type(ref.interfaceStyle) == "number" then return ref.interfaceStyle end
    return 0
end

-- Forever's header is "<version> <interfaceStyle> <count>"; older ones are
-- "<version> <count>". Read as-is, an old header puts the frame count into
-- interfaceStyle. So for any other version, rewrite the header first.
local function DecodeWithHeaderFix(str, ref, report)
    local refStr = Encode(ref)
    local fVersion = refStr and refStr:match("^(%d+)%s") or "5"
    local style = tostring(PreferredStyle(ref))

    local inVersion, rest = str:match("^(%d+)%s+(.+)$")
    if inVersion and inVersion ~= fVersion then
        local count = rest:match("^(%d+)%s")
        local info = Decode(fVersion .. " " .. style .. " " .. rest)
        if info then
            report[#report + 1] = string.format("Header rewritten: version %s -> %s, interface style %s, %s frames read (header says %s).",
                inVersion, fVersion, style, #info.systems, tostring(count))
            return info
        end
    end
    return (Decode(str))
end

-- Main entry. Returns forever-ready string (or nil), report lines, stats.
function ns.Convert(input, layoutName, opts)
    opts = opts or {}
    local groups = opts.groups or {}
    local report, stats = {}, { kept = 0, added = 0, dropped = 0, anchors = 0, settingsDropped = 0, settingsAdded = 0,
        fields = 0, defaults = 0, skipped = 0, clamped = 0 }
    input = Trim(input):gsub("[\r\n]+", " ")
    if input == "" then return nil, { "Paste a layout string first." }, stats end
    if not (C_EditMode and C_EditMode.ConvertStringToLayoutInfo and C_EditMode.ConvertLayoutInfoToString) then
        return nil, { "This client has no Edit Mode import API." }, stats
    end

    local ref, refName = ns.GetReferenceLayout(opts.template)
    if not ref then return nil, { "Could not read your current Forever layout to use as a template." }, stats end
    report[#report + 1] = "Template: " .. tostring(refName) .. "."

    local inVersion = input:match("^(%d+)")
    local info = DecodeWithHeaderFix(input, ref, report)
    if not info then
        return nil, { "The game could not read this string at all. Check that it was copied completely." }, stats
    end

    -- 1. Top-level fields Forever expects (interfaceStyle and anything newer).
    for k, v in pairs(ref) do
        if not SKIP_TOP[k] and info[k] == nil then
            info[k] = DeepCopy(v)
            stats.fields = stats.fields + 1
            report[#report + 1] = "Added missing field '" .. tostring(k) .. "' = " .. tostring(v) .. "."
        end
    end
    if not ValidStyles()[info.interfaceStyle] then
        local bad = info.interfaceStyle
        info.interfaceStyle = PreferredStyle(ref)
        stats.fields = stats.fields + 1
        report[#report + 1] = "Interface style " .. tostring(bad) .. " is not valid on Forever; set to " .. tostring(info.interfaceStyle) .. "."
    end
    info.layoutIndex = nil
    info.layoutName = (layoutName and layoutName ~= "") and layoutName or "Converted layout"
    info.layoutType = (Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account) or 1

    -- 2. Systems: keep the ones Forever has, drop unknown ones, add missing ones.
    local refByKey, refOrder = {}, {}
    for _, s in ipairs(ref.systems) do
        local key = SysKey(s)
        refByKey[key] = s
        refOrder[#refOrder + 1] = key
    end

    local inByKey = {}
    for _, s in ipairs(info.systems) do
        local key = SysKey(s)
        if refByKey[key] then
            inByKey[key] = s
        else
            stats.dropped = stats.dropped + 1
        end
    end

    local systems = {}
    for _, key in ipairs(refOrder) do
        local r, s = refByKey[key], inByKey[key]
        if not s then
            systems[#systems + 1] = DeepCopy(r)
            stats.added = stats.added + 1
        elseif groups[GroupOf(r.system)] == false then
            systems[#systems + 1] = DeepCopy(r)
            stats.skipped = stats.skipped + 1
        else
            stats.kept = stats.kept + 1
            -- Missing per-system fields.
            for k, v in pairs(r) do
                if s[k] == nil and k ~= "anchorInfo2" then s[k] = DeepCopy(v) end
            end
            -- Anchors pointing at frames Forever does not have.
            local a = s.anchorInfo
            if type(a) ~= "table" or not FrameExists(a.relativeTo) then
                s.anchorInfo = DeepCopy(r.anchorInfo)
                s.anchorInfo2 = DeepCopy(r.anchorInfo2)
                s.isInDefaultPosition = r.isInDefaultPosition
                stats.anchors = stats.anchors + 1
            else
                for k, v in pairs(r.anchorInfo or {}) do
                    if a[k] == nil then a[k] = DeepCopy(v) end
                end
                if s.anchorInfo2 and not FrameExists(s.anchorInfo2.relativeTo) then
                    s.anchorInfo2 = DeepCopy(r.anchorInfo2)
                end
            end
            -- Settings: keep the ones Forever knows, add the ones it needs.
            local refSet, have, settings = {}, {}, {}
            for _, st in ipairs(r.settings or {}) do refSet[st.setting] = st end
            for _, st in ipairs(s.settings or {}) do
                if refSet[st.setting] and not have[st.setting] then
                    settings[#settings + 1] = st
                    have[st.setting] = true
                else
                    stats.settingsDropped = stats.settingsDropped + 1
                end
            end
            for _, st in ipairs(r.settings or {}) do
                if not have[st.setting] then
                    settings[#settings + 1] = DeepCopy(st)
                    stats.settingsAdded = stats.settingsAdded + 1
                end
            end
            s.settings = settings
            -- The author never moved this frame: retail's default spot is not
            -- Forever's, so the frame keeps the template's position instead.
            if s.isInDefaultPosition and opts.keepDefaults ~= false then
                s.anchorInfo = DeepCopy(r.anchorInfo)
                s.anchorInfo2 = DeepCopy(r.anchorInfo2)
                s.isInDefaultPosition = r.isInDefaultPosition
                stats.defaults = stats.defaults + 1
            elseif opts.clamp ~= false then
                local c1 = ClampAnchor(s.anchorInfo)
                local c2 = ClampAnchor(s.anchorInfo2)
                if c1 or c2 then stats.clamped = stats.clamped + 1 end
            end
            systems[#systems + 1] = s
        end
    end
    info.systems = systems

    -- 3. Encode with Forever's own encoder and check it reads back.
    ns.lastInfo = info
    local out, err = Encode(info)
    if not out then
        report[#report + 1] = "Forever's encoder rejected the converted layout:"
        report[#report + 1] = "|cffffd100" .. tostring(err) .. "|r"
        report[#report + 1] = "Type /mlb debug and send the chat output to Claude."
        return nil, report, stats
    end
    local back, err2 = Decode(out)
    if not back then
        report[#report + 1] = "The converted string does not read back cleanly: " .. tostring(err2)
        return nil, report, stats
    end

    local outVersion = out:match("^(%d+)")
    table.insert(report, 1, string.format("Format %s -> %s. Frames kept %d, set to your current position %d, unknown dropped %d.",
        tostring(inVersion), tostring(outVersion), stats.kept, stats.added, stats.dropped))
    if stats.defaults > 0 then
        report[#report + 1] = stats.defaults .. " frame(s) the author left at retail's default keep your template position."
    end
    if stats.skipped > 0 then
        report[#report + 1] = stats.skipped .. " frame(s) in unticked groups kept your template position."
    end
    if stats.clamped > 0 then
        report[#report + 1] = stats.clamped .. " frame(s) were pulled back inside your screen."
    end
    if stats.anchors > 0 then
        report[#report + 1] = stats.anchors .. " frame(s) were attached to frames Forever does not have; they keep your current position."
    end
    if stats.settingsDropped + stats.settingsAdded > 0 then
        report[#report + 1] = string.format("Settings: %d unknown removed, %d missing filled in.", stats.settingsDropped, stats.settingsAdded)
    end
    return out, report, stats
end

-- /mlb debug: describe what Forever's layouts look like, field by field.
local function Describe(t)
    local keys = {}
    for k, v in pairs(t) do
        if k ~= "systems" and k ~= "settings" then
            local val = type(v) == "table" and "{table}" or tostring(v)
            keys[#keys + 1] = tostring(k) .. "=" .. val
        end
    end
    table.sort(keys)
    return table.concat(keys, ", ")
end

-- Collects the debug lines; prints them to chat unless silent. Returns plain text.
function ns.Debug(silent)
    local lines = {}
    local p = function(text)
        lines[#lines + 1] = text
        if not silent then print("|cff33ccffLayoutBridge:|r", text) end
    end
    local _, _, _, toc = GetBuildInfo()
    p("Client interface: " .. tostring(toc))
    p("C_EditMode functions:")
    local fns = {}
    for k in pairs(C_EditMode or {}) do fns[#fns + 1] = k end
    table.sort(fns)
    p(table.concat(fns, ", "))
    for _, src in ipairs(ns.GetLayoutSources()) do
        local name, l = src[1], src[2]
        p(name .. " top: " .. Describe(l))
        local s = l.systems and l.systems[1]
        if s then
            p(name .. " system[1]: " .. Describe(s))
            if type(s.anchorInfo) == "table" then p(name .. " anchorInfo: " .. Describe(s.anchorInfo)) end
            if s.settings and s.settings[1] then p(name .. " setting[1]: " .. Describe(s.settings[1])) end
        end
        local str, err = Encode(l)
        p(name .. " encodes: " .. (str and ("OK, header '" .. str:sub(1, 12) .. "'") or ("FAILED: " .. tostring(err))))
    end
    -- The list Edit Mode hands to C_EditMode.SaveLayouts. Run this right after a
    -- failed import (before /reload) to see which entry the error points at.
    local mgr = EditModeManagerFrame
    if mgr and type(mgr.layoutInfo) == "table" and type(mgr.layoutInfo.layouts) == "table" then
        p("Edit Mode save list: activeLayout=" .. tostring(mgr.layoutInfo.activeLayout) .. ", entries=" .. #mgr.layoutInfo.layouts)
        for i, l in ipairs(mgr.layoutInfo.layouts) do
            local style = l.interfaceStyle
            p(string.format("  #%d name=%s type=%s style=%s (%s) layoutIndex=%s systems=%s",
                i, tostring(l.layoutName), tostring(l.layoutType), tostring(style), type(style),
                tostring(l.layoutIndex), tostring(l.systems and #l.systems)))
        end
    else
        p("Edit Mode save list: not available (open Edit Mode once, then try again).")
    end
    if ns.lastInfo then
        p("last converted top: " .. Describe(ns.lastInfo))
        local s = ns.lastInfo.systems and ns.lastInfo.systems[1]
        if s then p("last converted system[1]: " .. Describe(s)) end
        local _, err = Encode(ns.lastInfo)
        p("last converted encode error: " .. tostring(err))
    else
        p("No conversion attempted yet this session.")
    end
    return table.concat(lines, "\n")
end
