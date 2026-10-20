-- Marisco's Bug Catcher - window, settings, minimap button, slash commands

local ADDON, ns = ...
local S = ns.S
local format = string.format

local KIND = {
    error   = { label = "Error",   color = { 1, 0.35, 0.35 } },
    blocked = { label = "Blocked", color = { 1, 0.6, 0.15 } },
    load    = { label = "Load",    color = { 0.75, 0.55, 1 } },
    warning = { label = "Warning", color = { 1, 0.85, 0.25 } },
}

local W, H = 820, 600
local ROWS, ROW_H = 10, 20

local f                       -- main window (built on first use)
local state = { session = nil, addon = nil, selected = nil, offset = 0, search = "", showWarnings = true, report = false }
local view = {}

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local function addonVersion(name)
    if not name or not GetMeta then return nil end
    local ok, v = pcall(GetMeta, name, "Version")
    return ok and v or nil
end

local function esc(s) return (tostring(s or ""):gsub("|", "||")) end

local function sessions() return ns.db and ns.db.sessions or { ns.cur } end

local function viewedSession()
    local list = sessions()
    if not state.session or not list[state.session] then state.session = #list end
    return list[state.session], state.session, #list
end

----------------------------------------------------------------------
-- Text for the details box and the report
----------------------------------------------------------------------
function ns.FormatEntry(e)
    local t = {}
    local k = KIND[e.kind] or KIND.error
    t[#t + 1] = format("[%s] %s   x%d", k.label, e.addon or "Unknown", e.count or 1)
    t[#t + 1] = format("First: %s   Last: %s%s", date("%Y-%m-%d %H:%M:%S", e.time or 0),
        date("%H:%M:%S", e.last or e.time or 0), e.combat and "   (in combat)" or "")
    local v = addonVersion(e.addon)
    if v then t[#t + 1] = "AddOn version: " .. v end
    t[#t + 1] = ""
    t[#t + 1] = "Message:"
    t[#t + 1] = e.msg or "?"
    if e.hint then
        t[#t + 1] = ""
        t[#t + 1] = "What it means:"
        t[#t + 1] = e.hint
    end
    if e.stack then
        t[#t + 1] = ""
        t[#t + 1] = "Stack:"
        t[#t + 1] = e.stack
    end
    if e.locals then
        t[#t + 1] = ""
        t[#t + 1] = "Locals:"
        t[#t + 1] = e.locals
    end
    return table.concat(t, "\n")
end

function ns.BuildReport(sess, list)
    local t = {}
    t[#t + 1] = format("Marisco's Bug Catcher v%s report", ns.VERSION)
    t[#t + 1] = format("Session %d, %s, started %s", sess.id or 0, sess.char or "?", date("%Y-%m-%d %H:%M", sess.start or 0))
    t[#t + 1] = "Client: " .. (sess.client or "?")
    local total = 0
    local addons, seen = {}, {}
    for _, e in ipairs(list) do
        total = total + (e.count or 1)
        if e.addon and not seen[e.addon] then
            seen[e.addon] = true
            local v = addonVersion(e.addon)
            addons[#addons + 1] = v and (e.addon .. " " .. v) or e.addon
        end
    end
    t[#t + 1] = format("Entries: %d unique, %d total%s", #list, total,
        sess.dropped and format(" (+%d not kept, session limit reached)", sess.dropped) or "")
    t[#t + 1] = "AddOns involved: " .. (#addons > 0 and table.concat(addons, ", ") or "none")
    for i, e in ipairs(list) do
        t[#t + 1] = ""
        t[#t + 1] = format("==================== %d ====================", i)
        t[#t + 1] = ns.FormatEntry(e)
    end
    return table.concat(t, "\n")
end

----------------------------------------------------------------------
-- Small widget helpers
----------------------------------------------------------------------
local function Text(parent, font, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function Button(parent, label, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 100, 22)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

local function Arrow(parent, dir, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(24, 24)
    local p = "Interface\\Buttons\\UI-SpellbookIcon-" .. (dir < 0 and "Prev" or "Next") .. "Page-"
    b:SetNormalTexture(p .. "Up")
    b:SetPushedTexture(p .. "Down")
    b:SetDisabledTexture(p .. "Disabled")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b:SetScript("OnClick", onClick)
    return b
end

local function Check(parent, label, onClick)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    c.label = Text(parent, "GameFontHighlight")
    c.label:SetPoint("LEFT", c, "RIGHT", 2, 1)
    c.label:SetText(label)
    c:SetScript("OnClick", onClick)
    return c
end

local function Area(parent)
    local a = CreateFrame("Frame", nil, parent)
    local bg = a:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.35)
    return a
end

-- Two clicks within 3 seconds, so nothing is wiped by accident.
local function Confirmed(b, label)
    if b.armed then
        b.armed = nil
        b:SetText(label)
        return true
    end
    b.armed = true
    b:SetText("Sure?")
    C_Timer.After(3, function()
        if b.armed then b.armed = nil; b:SetText(label) end
    end)
    return false
end

----------------------------------------------------------------------
-- Main window
----------------------------------------------------------------------
local Refresh

local function buildView()
    wipe(view)
    local sess = viewedSession()
    local search = state.search:lower()
    for _, e in ipairs(sess.errors) do
        if (not state.addon or e.addon == state.addon)
            and (state.showWarnings or e.kind ~= "warning")
            and (search == "" or (e.msg or ""):lower():find(search, 1, true)
                or (e.addon or ""):lower():find(search, 1, true)) then
            view[#view + 1] = e
        end
    end
    if S("newestFirst") then
        local n = #view
        for i = 1, math.floor(n / 2) do view[i], view[n - i + 1] = view[n - i + 1], view[i] end
    end
end

local function addonsIn(sess)
    local list, seen = {}, {}
    for _, e in ipairs(sess.errors) do
        if e.addon and not seen[e.addon] then seen[e.addon] = true; list[#list + 1] = e.addon end
    end
    table.sort(list)
    return list
end

local function sessionLabel(sess, i, n)
    local unique = ns.Counts(sess)
    local warn = #sess.errors - unique
    local when = (i == n and sess == ns.cur) and "now" or date("%m-%d %H:%M", sess.start or 0)
    local count = format("%d error%s", unique, unique == 1 and "" or "s")
    if warn > 0 then count = count .. format(", %d warn.", warn) end
    return format("Session %d · %s · %s", sess.id or 0, when, count)
end

local function setDetail(text)
    f.detail.fixed = text
    f.detail:SetText(text)
    f.detail:SetCursorPosition(0)
    f.detailScroll:SetVerticalScroll(0)
end

local function selectAllDetail(msg)
    f.detail:SetFocus()
    f.detail:HighlightText()
    f.status:SetText(msg or "Press Ctrl+C to copy.")
end

local function build()
    f = CreateFrame("Frame", "MariscosBugCatcherFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(W, H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        ns.db.settings.window = { p, rp, x, y }
    end)
    f:Hide()
    tinsert(UISpecialFrames, "MariscosBugCatcherFrame")

    local title = f.TitleText or Text(f, "GameFontNormal", "CENTER")
    if not f.TitleText then title:SetPoint("TOP", f, "TOP", 0, -5) end
    title:SetText(format("Marisco's Bug Catcher |cffffffff- v%s Beta|r", ns.VERSION))

    -- Top controls ---------------------------------------------------
    local y = -32
    f.sPrev = Arrow(f, -1, function()
        state.session = math.max(1, (state.session or 1) - 1)
        state.addon, state.selected, state.offset, state.report = nil, nil, 0, false
        Refresh()
    end)
    f.sPrev:SetPoint("TOPLEFT", 12, y)
    f.sLabel = Text(f, "GameFontHighlight", "CENTER")
    f.sLabel:SetSize(250, 24)
    f.sLabel:SetPoint("LEFT", f.sPrev, "RIGHT", 2, 0)
    f.sNext = Arrow(f, 1, function()
        state.session = math.min(#sessions(), (state.session or 1) + 1)
        state.addon, state.selected, state.offset, state.report = nil, nil, 0, false
        Refresh()
    end)
    f.sNext:SetPoint("LEFT", f.sLabel, "RIGHT", 2, 0)

    local function cycleAddon(dir)
        local list = addonsIn(viewedSession())
        local pos = 0
        for i, name in ipairs(list) do if name == state.addon then pos = i end end
        pos = (pos + dir) % (#list + 1)
        state.addon = list[pos]   -- index 0 is "All"
        state.selected, state.offset, state.report = nil, 0, false
        Refresh()
    end
    f.aPrev = Arrow(f, -1, function() cycleAddon(-1) end)
    f.aPrev:SetPoint("LEFT", f.sNext, "RIGHT", 14, 0)
    f.aLabel = Text(f, "GameFontHighlight", "CENTER")
    f.aLabel:SetSize(170, 24)
    f.aLabel:SetPoint("LEFT", f.aPrev, "RIGHT", 2, 0)
    f.aNext = Arrow(f, 1, function() cycleAddon(1) end)
    f.aNext:SetPoint("LEFT", f.aLabel, "RIGHT", 2, 0)

    f.warn = Check(f, "Warnings", function(self)
        state.showWarnings = self:GetChecked() and true or false
        state.selected, state.offset = nil, 0
        Refresh()
    end)
    f.warn:SetPoint("LEFT", f.aNext, "RIGHT", 12, 0)
    f.warn:SetChecked(state.showWarnings)

    local sb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    sb:SetSize(130, 20)
    sb:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, y - 2)
    sb:SetAutoFocus(false)
    sb.hint = Text(sb, "GameFontDisableSmall")
    sb.hint:SetPoint("LEFT", 2, 0)
    sb.hint:SetText("Search")
    sb:SetScript("OnEscapePressed", sb.ClearFocus)
    sb:SetScript("OnEnterPressed", sb.ClearFocus)
    sb:SetScript("OnTextChanged", function(self)
        local t = self:GetText() or ""
        sb.hint:SetShown(t == "" and not self:HasFocus())
        if t ~= state.search then
            state.search = t
            state.selected, state.offset, state.report = nil, 0, false
            Refresh()
        end
    end)
    sb:SetScript("OnEditFocusGained", function() sb.hint:Hide() end)
    sb:SetScript("OnEditFocusLost", function(self) sb.hint:SetShown((self:GetText() or "") == "") end)

    -- Column headers ---------------------------------------------------
    local hy = -64
    local cols = { { "Count", 14, 40 }, { "Time", 60, 60 }, { "Type", 124, 60 }, { "AddOn", 188, 160 }, { "Message", 352, 200 } }
    for _, c in ipairs(cols) do
        local h = Text(f, "GameFontNormalSmall")
        h:SetPoint("TOPLEFT", f, "TOPLEFT", c[2], hy)
        h:SetText(c[1])
    end

    -- Error list -------------------------------------------------------
    local list = Area(f)
    list:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -78)
    list:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -78)
    list:SetHeight(ROWS * ROW_H + 8)
    f.list = list

    f.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, list)
        r:SetHeight(ROW_H)
        r:SetPoint("TOPLEFT", list, "TOPLEFT", 2, -4 - (i - 1) * ROW_H)
        r:SetPoint("RIGHT", list, "RIGHT", -20, 0)
        r.sel = r:CreateTexture(nil, "BACKGROUND")
        r.sel:SetAllPoints()
        r.sel:SetColorTexture(1, 0.82, 0, 0.18)
        r.sel:Hide()
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        r.count = Text(r, "GameFontHighlightSmall", "RIGHT"); r.count:SetPoint("LEFT", 0, 0); r.count:SetWidth(34)
        r.time = Text(r); r.time:SetPoint("LEFT", 50, 0); r.time:SetWidth(60)
        r.kind = Text(r); r.kind:SetPoint("LEFT", 114, 0); r.kind:SetWidth(60)
        r.addon = Text(r); r.addon:SetPoint("LEFT", 178, 0); r.addon:SetWidth(158)
        r.msg = Text(r); r.msg:SetPoint("LEFT", 342, 0); r.msg:SetPoint("RIGHT", -4, 0)
        r:SetScript("OnClick", function(self)
            state.selected, state.report = self.e, false
            Refresh()
        end)
        r:SetScript("OnEnter", function(self)
            if not self.e then return end
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:AddLine(esc(self.e.addon), 1, 0.82, 0)
            local m = self.e.msg or ""
            if #m > 400 then m = m:sub(1, 400) .. "..." end
            GameTooltip:AddLine(esc(m), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.rows[i] = r
    end

    f.empty = Text(list, "GameFontDisable", "CENTER")
    f.empty:SetPoint("CENTER")

    local bar = CreateFrame("Slider", nil, list)
    bar:SetPoint("TOPRIGHT", list, "TOPRIGHT", -2, -4)
    bar:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -2, 4)
    bar:SetWidth(16)
    bar:SetOrientation("VERTICAL")
    bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    bar:GetThumbTexture():SetSize(18, 24)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(1, 1, 1, 0.05)
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
    bar:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        if v ~= state.offset then state.offset = v; Refresh() end
    end)
    f.bar = bar

    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        local max = math.max(0, #view - ROWS)
        state.offset = math.max(0, math.min(max, state.offset - delta * 2))
        Refresh()
    end)

    -- Details ------------------------------------------------------------
    local dl = Text(f, "GameFontNormalSmall")
    dl:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 4, -8)
    dl:SetText("Details (select, then Ctrl+C)")
    f.detailLabel = dl

    local area = Area(f)
    area:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -22)
    area:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 44)

    local sf = CreateFrame("ScrollFrame", "MariscosBugCatcherDetailScroll", area, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 6, -6)
    sf:SetPoint("BOTTOMRIGHT", -28, 6)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(GameFontHighlightSmall)
    eb:SetWidth(W - 70)
    eb:SetMaxLetters(0)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    eb:SetScript("OnTextChanged", function(self, user)
        if user then self:SetText(self.fixed or "") end   -- read only
    end)
    sf:SetScrollChild(eb)
    sf:EnableMouse(true)
    sf:SetScript("OnMouseDown", function() eb:SetFocus() end)
    f.detail, f.detailScroll = eb, sf

    -- Buttons --------------------------------------------------------------
    local copy = Button(f, "Copy", 90, function()
        selectAllDetail()
    end)
    copy:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 12)

    local report = Button(f, "Copy all", 90, function()
        local sess = viewedSession()
        state.report = true
        Refresh()
        setDetail(esc(ns.BuildReport(sess, view)))
        selectAllDetail(format("Report of %d entr%s selected. Press Ctrl+C.", #view, #view == 1 and "y" or "ies"))
    end)
    report:SetPoint("LEFT", copy, "RIGHT", 4, 0)

    local clear
    clear = Button(f, "Clear", 90, function()
        if not Confirmed(clear, "Clear") then return end
        ns.ClearSession(viewedSession())
        state.selected, state.offset, state.addon, state.report = nil, 0, nil, false
        Refresh()
    end)
    clear:SetPoint("LEFT", report, "RIGHT", 4, 0)

    local clearAll
    clearAll = Button(f, "Clear all", 90, function()
        if not Confirmed(clearAll, "Clear all") then return end
        ns.ClearAll()
        state.session, state.selected, state.offset, state.addon, state.report = nil, nil, 0, nil, false
        Refresh()
    end)
    clearAll:SetPoint("LEFT", clear, "RIGHT", 4, 0)

    local reload = Button(f, "Reload UI", 90, function() ReloadUI() end)
    reload:SetPoint("LEFT", clearAll, "RIGHT", 4, 0)

    local settings = Button(f, "Settings", 90, function() ns.ToggleSettings() end)
    settings:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)

    f.status = Text(f, "GameFontDisableSmall", "RIGHT")
    f.status:SetPoint("LEFT", reload, "RIGHT", 8, 0)
    f.status:SetPoint("RIGHT", settings, "LEFT", -8, 0)

    f:SetScript("OnShow", function()
        state.session = nil   -- open on the current session
        if ns.StopGlow then ns.StopGlow() end
        Refresh()
    end)
    f:SetScript("OnHide", function()
        if ns.settingsFrame then ns.settingsFrame:Hide() end
    end)

    local pos = ns.db.settings.window
    if type(pos) == "table" and pos[1] then
        f:ClearAllPoints()
        f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end
end

Refresh = function()
    if not f or not f:IsShown() then return end
    local sess, i, n = viewedSession()
    buildView()

    f.sLabel:SetText(sessionLabel(sess, i, n))
    f.sPrev:SetEnabled(i > 1)
    f.sNext:SetEnabled(i < n)
    f.aLabel:SetText("AddOn: " .. (state.addon and ("|cffffd100" .. esc(state.addon) .. "|r") or "All"))

    local max = math.max(0, #view - ROWS)
    if state.offset > max then state.offset = max end
    f.bar:SetMinMaxValues(0, max)
    f.bar:SetValue(state.offset)
    f.bar:SetShown(max > 0)

    -- keep the selection valid; pick the first entry otherwise
    local found = false
    for _, e in ipairs(view) do if e == state.selected then found = true break end end
    if not found then state.selected = view[1] end

    for r = 1, ROWS do
        local row, e = f.rows[r], view[r + state.offset]
        row.e = e
        if e then
            local k = KIND[e.kind] or KIND.error
            row.count:SetText(e.count > 1 and ("x" .. e.count) or "")
            row.time:SetText(date("%H:%M:%S", e.last or e.time or 0))
            row.kind:SetText(k.label)
            row.kind:SetTextColor(unpack(k.color))
            row.addon:SetText(esc(e.addon))
            row.addon:SetTextColor(ns.IsBlizzard(e.addon) and 0.6 or 1, ns.IsBlizzard(e.addon) and 0.6 or 0.82, ns.IsBlizzard(e.addon) and 0.6 or 0)
            local m = (e.msg or ""):match("^[^\n]*") or ""
            m = m:gsub("^.-[Aa]dd[Oo]ns[/\\][^/\\]+[/\\]", "")
            row.msg:SetText(esc(m))
            row.sel:SetShown(e == state.selected and not state.report)
            row:Show()
        else
            row:Hide()
        end
    end

    if #view == 0 then
        f.empty:SetText(#sess.errors == 0 and "Nothing caught in this session." or "Nothing matches the filter.")
        f.empty:Show()
    else
        f.empty:Hide()
    end

    if not state.report then
        if state.selected then
            setDetail(esc(ns.FormatEntry(state.selected)))
        else
            setDetail("Errors, blocked actions, Lua warnings and addons that failed to load appear in the list above.\n\n"
                .. "Click one to see its message, stack and locals here. 'Copy all' puts a full report of the list in this box, ready for Ctrl+C.")
        end
    end

    local status = ""
    if ns.handlerBlocked then
        status = "|cffff5555Another error catcher holds the Lua error handler.|r"
    elseif sess.dropped then
        status = format("%d more not kept (limit %d per session).", sess.dropped, ns.MAX_UNIQUE)
    end
    f.status:SetText(status)
end
ns.Refresh = function() Refresh() end

function ns.ShowWindow()
    if not ns.db then return end
    if not f then build() end
    f:Show()
end

function ns.ToggleWindow()
    if not ns.db then return end
    if not f then build() end
    f:SetShown(not f:IsShown())
end

----------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------
local OPTIONS = {
    { "chat", "Chat message for new errors" },
    { "sound", "Play a sound for new errors" },
    { "flash", "Flash the minimap button" },
    { "autoOpen", "Open this window on a new error", "Only out of combat." },
    { "blocked", "Catch blocked actions (taint)" },
    { "warnings", "Catch Lua warnings" },
    { "loadIssues", "Report addons that failed to load", "Checked when you log in or reload." },
    { "ignoreBlizzard", "Ignore errors in Blizzard's own UI" },
    { "blizzard", "Also show the game's error window", "Passes every Lua error on to the game's own error frame and turns on its 'Display Lua errors' setting." },
    { "newestFirst", "Newest first" },
}

function ns.ToggleSettings()
    if not f then build() end
    local sp = ns.settingsFrame
    if not sp then
        sp = CreateFrame("Frame", "MariscosBugCatcherSettings", f, "BasicFrameTemplateWithInset")
        sp:SetSize(320, 420)
        sp:SetPoint("TOPLEFT", f, "TOPRIGHT", 2, 0)
        sp:SetFrameStrata("HIGH")
        local t = sp.TitleText or Text(sp, "GameFontNormal", "CENTER")
        if not sp.TitleText then t:SetPoint("TOP", 0, -5) end
        t:SetText("Settings")
        sp.checks = {}
        local y = -34
        for _, o in ipairs(OPTIONS) do
            local key = o[1]
            local c = Check(sp, o[2], function(self)
                ns.db.settings[key] = self:GetChecked() and true or false
                if key == "blizzard" and ns.db.settings.blizzard and SetCVar then pcall(SetCVar, "scriptErrors", "1") end
                if f:IsShown() then Refresh() end
            end)
            c:SetPoint("TOPLEFT", 14, y)
            if o[3] then
                c:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(o[2], 1, 1, 1)
                    GameTooltip:AddLine(o[3], nil, nil, nil, true)
                    GameTooltip:Show()
                end)
                c:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
            c.key = key
            sp.checks[#sp.checks + 1] = c
            y = y - 28
        end

        local mm = Check(sp, "Minimap button", function(self)
            ns.db.settings.minimap.hide = not self:GetChecked()
            ns.UpdateMinimap()
        end)
        mm:SetPoint("TOPLEFT", 14, y)
        sp.mm = mm
        y = y - 34

        local kl = Text(sp, "GameFontHighlight")
        kl:SetPoint("TOPLEFT", 18, y - 5)
        local function updateKeep() kl:SetText(format("Sessions kept: |cffffd100%d|r", ns.db.settings.keep)) end
        local minus = Button(sp, "-", 26, function()
            ns.db.settings.keep = math.max(1, ns.db.settings.keep - 1); updateKeep()
        end)
        minus:SetPoint("TOPLEFT", 200, y)
        local plus = Button(sp, "+", 26, function()
            ns.db.settings.keep = math.min(50, ns.db.settings.keep + 1); updateKeep()
        end)
        plus:SetPoint("LEFT", minus, "RIGHT", 4, 0)
        sp.updateKeep = updateKeep

        local def = Button(sp, "Defaults", 100, function()
            local win = ns.db.settings.window
            ns.ResetSettings()
            ns.db.settings.window = win
            ns.UpdateMinimap()
            sp:GetScript("OnShow")(sp)
            Refresh()
        end)
        def:SetPoint("BOTTOM", 0, 12)

        sp:SetScript("OnShow", function(self)
            for _, c in ipairs(self.checks) do c:SetChecked(ns.db.settings[c.key] and true or false) end
            self.mm:SetChecked(not ns.db.settings.minimap.hide)
            self.updateKeep()
        end)
        ns.settingsFrame = sp
        sp:Hide()
    end
    if not f:IsShown() then f:Show() end
    sp:SetShown(not sp:IsShown())
end

----------------------------------------------------------------------
-- Minimap button
----------------------------------------------------------------------
local mb, glowAnim, glow

local function updateBadge()
    if not mb then return end
    local unique = ns.Counts(ns.cur)
    if unique > 0 then
        mb.badge:SetText(unique > 99 and "99+" or tostring(unique))
        mb.badge:Show()
    else
        mb.badge:Hide()
    end
end

function ns.StopGlow()
    if glowAnim then glowAnim:Stop(); glow:SetAlpha(0) end
end

function ns.UpdateMinimap()
    if not mb then return end
    local m = ns.db.settings.minimap
    mb:SetShown(not m.hide)
    local a = math.rad(m.angle or 215)
    local r = (Minimap:GetWidth() / 2) + 10
    mb:ClearAllPoints()
    mb:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function createMinimapButton()
    mb = CreateFrame("Button", "MariscosBugCatcherMinimapButton", Minimap)
    mb:SetSize(31, 31)
    mb:SetFrameStrata("MEDIUM")
    mb:SetFrameLevel(8)
    mb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mb:RegisterForDrag("LeftButton")
    mb:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = mb:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = mb:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\Spell_Nature_InsectSwarm")
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    mb.icon = icon
    local border = mb:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    glow = mb:CreateTexture(nil, "OVERLAY", nil, 7)
    glow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.15, 0.15)
    glow:SetAllPoints()
    glow:SetAlpha(0)
    glowAnim = glow:CreateAnimationGroup()
    glowAnim:SetLooping("BOUNCE")
    local fade = glowAnim:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetDuration(0.6)

    local badge = mb:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    badge:SetPoint("BOTTOMRIGHT", -2, 3)
    badge:SetTextColor(1, 0.3, 0.3)
    mb.badge = badge

    mb:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ns.PrintStatus()
        else
            ns.ToggleWindow()
        end
    end)
    mb:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            ns.db.settings.minimap.angle = math.deg(math.atan2(py / s - my, px / s - mx))
            ns.UpdateMinimap()
        end)
    end)
    mb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    mb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Marisco's Bug Catcher")
        local unique, total = ns.Counts(ns.cur)
        GameTooltip:AddLine(format("This session: %d error%s (%d total)", unique, unique == 1 and "" or "s", total), 1, 1, 1)
        local warn = #ns.cur.errors - unique
        if warn > 0 then GameTooltip:AddLine(format("%d Lua warning%s", warn, warn == 1 and "" or "s"), 1, 0.85, 0.25) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffffd100Left-click|r: open the bug list", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffffd100Right-click|r: summary in chat", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffffd100Drag|r: move", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    mb:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ns.UpdateMinimap()
    updateBadge()
end

----------------------------------------------------------------------
-- Live updates
----------------------------------------------------------------------
local refreshQueued = false
ns.OnRecord(function(e, isNew)
    updateBadge()
    if e and isNew and e.kind ~= "warning" and S("flash") and glowAnim and not (f and f:IsShown()) then
        glowAnim:Play()
    end
    if f and f:IsShown() and not refreshQueued then
        refreshQueued = true
        C_Timer.After(0.2, function() refreshQueued = false; Refresh() end)
    end
end)

ns.OnLogin = function()
    createMinimapButton()
    if ns.Counts(ns.cur) > 0 and S("flash") then glowAnim:Play() end
end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
function ns.PrintStatus()
    local unique, total = ns.Counts(ns.cur)
    local warn = #ns.cur.errors - unique
    print(format("|cffff5555[Bug Catcher]|r v%s · session %d: %d error%s (%d total), %d warning%s.",
        ns.VERSION, ns.cur.id, unique, unique == 1 and "" or "s", total, warn, warn == 1 and "" or "s"))
    local by = {}
    for _, e in ipairs(ns.cur.errors) do
        if e.kind ~= "warning" then by[e.addon or "Unknown"] = (by[e.addon or "Unknown"] or 0) + e.count end
    end
    for name, n in pairs(by) do print(format("   |cffffd100%s|r: %d", name, n)) end
    if ns.handlerBlocked then print("   |cffff5555Another error catcher holds the Lua error handler.|r") end
end

local function onOff(key, label)
    ns.db.settings[key] = not ns.db.settings[key]
    print(format("|cffff5555[Bug Catcher]|r %s: %s", label, ns.db.settings[key] and "|cff40ff40on|r" or "|cffff4040off|r"))
end

SLASH_MARISCOSBUGCATCHER1 = "/mbc"
SLASH_MARISCOSBUGCATCHER2 = "/bugcatcher"
SlashCmdList.MARISCOSBUGCATCHER = function(input)
    local cmd = (input or ""):lower():match("^%s*(%S*)") or ""
    if not ns.db then return end
    if cmd == "" or cmd == "show" or cmd == "toggle" then
        ns.ToggleWindow()
    elseif cmd == "test" then
        C_Timer.After(0, function()
            error("Bug Catcher test error: catching works. You can clear this one.")
        end)
    elseif cmd == "last" then
        local e = ns.cur.errors[#ns.cur.errors]
        if e then print("|cffff5555[Bug Catcher]|r " .. ns.FormatEntry({ kind = e.kind, msg = e.msg, addon = e.addon, count = e.count, time = e.time, last = e.last }))
        else print("|cffff5555[Bug Catcher]|r Nothing caught this session.") end
    elseif cmd == "clear" then
        ns.ClearSession(ns.cur); updateBadge(); ns.StopGlow(); Refresh()
        print("|cffff5555[Bug Catcher]|r This session's list is cleared.")
    elseif cmd == "clearall" then
        ns.ClearAll(); updateBadge(); ns.StopGlow(); state.session = nil; Refresh()
        print("|cffff5555[Bug Catcher]|r Everything is cleared.")
    elseif cmd == "config" or cmd == "settings" then
        ns.ToggleSettings()
    elseif cmd == "chat" then
        onOff("chat", "Chat messages")
    elseif cmd == "sound" then
        onOff("sound", "Sound")
    elseif cmd == "minimap" then
        ns.db.settings.minimap.hide = not ns.db.settings.minimap.hide
        ns.UpdateMinimap()
    elseif cmd == "status" then
        ns.PrintStatus()
    elseif cmd == "reset" then
        ns.ResetSettings()
        ns.UpdateMinimap()
        if f then f:ClearAllPoints(); f:SetPoint("CENTER") end
        print("|cffff5555[Bug Catcher]|r Settings and positions are back to default.")
    else
        print("|cffff5555[Bug Catcher]|r /mbc · /mbc test · /mbc last · /mbc clear · /mbc clearall · /mbc config · /mbc chat · /mbc sound · /mbc minimap · /mbc status · /mbc reset")
    end
end
