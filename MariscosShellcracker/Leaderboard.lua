-- Marisco's Shellcracker - character stats, leaderboard and top runs
-- Everything lives in the account-wide saved variables, so every character on the
-- account sees every other character's results (after that character logs out or /reloads).
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local Stats = {}
ns.Stats = Stats

local MAX_RUNS = 50
local SPECIALS = { "flame", "star", "hyper", "nova" }

local function comma(n)
    local s = tostring(floor(n or 0))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end
ns.comma = comma

local function Now() return time and time() or 0 end
local function Today() return date and date("%d %b %Y") or "" end

---------------------------------------------------------------------------
-- Records
---------------------------------------------------------------------------
local function NewChar(name, realm)
    return {
        name = name, realm = realm, class = nil, level = nil, created = Now(), lastPlayed = Now(),
        best = { score = 0, wave = 0, combo = 0, move = 0 },
        games = 0, kills = 0, bossKills = 0, totalScore = 0, moves = 0, gems = 0,
        damage = 0, taken = 0, healed = 0, time = 0,
        specials = { flame = 0, star = 0, hyper = 0, nova = 0 },
    }
end

function Stats:Key()
    local name = UnitName and UnitName("player") or "Unknown"
    local realm = GetRealmName and GetRealmName() or ""
    return name .. "-" .. realm, name, realm
end

-- the record of the character that is logged in (created the first time it plays)
function Stats:Char()
    local db = ns.db
    db.chars = db.chars or {}
    local key, name, realm = self:Key()
    local c = db.chars[key]
    if not c then
        c = NewChar(name, realm)
        db.chars[key] = c
    end
    if UnitClass then
        local _, classFile = UnitClass("player")
        c.class = classFile or c.class
    end
    if UnitLevel then c.level = UnitLevel("player") or c.level end
    return c, key
end

function Stats:Init()
    local db = ns.db
    db.chars = db.chars or {}
    db.runs = db.runs or {}
    -- 0.1-0.7 kept one account-wide best; give it to the first character that logs in
    if db.best and not db.statsMigrated then
        local c = self:Char()
        local b = db.best
        if (b.score or 0) > c.best.score then c.best.score = b.score end
        if (b.wave or 0) > c.best.wave then c.best.wave = b.wave end
        if (b.combo or 0) > c.best.combo then c.best.combo = b.combo end
        db.statsMigrated = true
    end
    self:Char().lastPlayed = Now()
end

-- current run counters (saved with the game in progress)
function Stats:NewRun() return { kills = 0, damage = 0, taken = 0, healed = 0, gems = 0, specials = 0, time = 0 } end

local function Run() return ns.Game and ns.Game.run end

function Stats:Add(field, n)
    n = n or 1
    local c = self:Char()
    c[field] = (c[field] or 0) + n
    local r = Run()
    if r and r[field] then r[field] = r[field] + n end
end

function Stats:Special(kind)
    local c = self:Char()
    c.specials[kind] = (c.specials[kind] or 0) + 1
    local r = Run()
    if r then r.specials = r.specials + 1 end
end

function Stats:Move(damage, cascades)
    local c = self:Char()
    c.moves = c.moves + 1
    if damage > (c.best.move or 0) then c.best.move = damage end
    if cascades > c.best.combo then c.best.combo = cascades end
end

function Stats:Tick(el)
    local c = self:Char()
    c.time = c.time + el
    local r = Run()
    if r then r.time = r.time + el end
end

-- best score / furthest makrura so far (also called during a run)
function Stats:UpdateBest(G)
    local c = self:Char()
    local b = c.best
    if G.score > b.score then
        b.score = G.score
        b.date = Today()
    end
    if G.wave > b.wave then b.wave = G.wave end
    if G.bestCombo > b.combo then b.combo = G.bestCombo end
end

-- a run ended: "slain" (lost the fight) or "left" (started a new game mid-fight)
function Stats:EndRun(G, how)
    if not G or (G.moves or 0) == 0 then return end
    local c, key = self:Char()
    self:UpdateBest(G)
    c.games = c.games + 1
    c.totalScore = c.totalScore + G.score
    c.lastPlayed = Now()
    local e = G.enemy or ns.GetEnemy(G.wave or 1)
    local r = G.run or self:NewRun()
    local runs = ns.db.runs
    runs[#runs+1] = {
        key = key, score = G.score, wave = G.wave, enemy = e.name, tide = e.tide or 1,
        combo = G.bestCombo, moves = G.moves, kills = r.kills, damage = r.damage,
        specials = r.specials, time = floor(r.time), how = how, date = Today(), at = Now(),
    }
    table.sort(runs, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.at < b.at end)
    while #runs > MAX_RUNS do table.remove(runs) end
end

function Stats:Remove(key)
    ns.db.chars[key] = nil
    local runs = ns.db.runs
    for i = #runs, 1, -1 do if runs[i].key == key then table.remove(runs, i) end end
end

function Stats:ResetAll()
    ns.db.chars = {}
    ns.db.runs = {}
end

---------------------------------------------------------------------------
-- Formatting
---------------------------------------------------------------------------
local function ClassColor(class)
    local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if cc then return ("|cff%02x%02x%02x"):format(cc.r * 255, cc.g * 255, cc.b * 255) end
    return "|cffffffff"
end

local function CharName(c, key, withRealm)
    local name = c and c.name or (key and key:match("^(.-)%-")) or key or "?"
    local s = ClassColor(c and c.class) .. name .. "|r"
    if withRealm and c and c.realm and c.realm ~= (GetRealmName and GetRealmName()) then
        s = s .. " |cff888888(" .. c.realm .. ")|r"
    end
    return s
end

local function Reached(wave)
    if not wave or wave < 1 then return "-" end
    local e = ns.GetEnemy(wave)
    local s = e.name
    if e.tide > 1 then s = s .. " |cff88ccff(Tide " .. e.tide .. ")|r" end
    return s
end

local function Duration(sec)
    sec = floor(sec or 0)
    local h, m = floor(sec / 3600), floor(sec % 3600 / 60)
    if h > 0 then return ("%dh %02dm"):format(h, m) end
    return ("%dm %02ds"):format(m, sec % 60)
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local L = {}
ns.Leaderboard = L
local win
local ROWS, ROW_H = 13, 19
local WIN_W, WIN_H = 640, 400

local TABS = { "Characters", "Top Runs", "Stats" }

local CHAR_COLS = {
    { key = "rank",   title = "#",          w = 26,  align = "RIGHT" },
    { key = "name",   title = "Character",  w = 140, align = "LEFT",  sort = function(c) return c.name or "" end },
    { key = "level",  title = "Lvl",        w = 44,  align = "CENTER", sort = function(c) return c.slevel or 1 end },
    { key = "score",  title = "Best score", w = 86,  align = "RIGHT", sort = function(c) return c.best.score end },
    { key = "wave",   title = "Furthest",   w = 140, align = "LEFT",  sort = function(c) return c.best.wave end },
    { key = "combo",  title = "Combo",      w = 50,  align = "CENTER", sort = function(c) return c.best.combo end },
    { key = "games",  title = "Games",      w = 50,  align = "RIGHT", sort = function(c) return c.games end },
    { key = "kills",  title = "Kills",      w = 44,  align = "RIGHT", sort = function(c) return c.kills end },
}
local RUN_COLS = {
    { key = "rank",   title = "#",          w = 26,  align = "RIGHT" },
    { key = "name",   title = "Character",  w = 120, align = "LEFT" },
    { key = "score",  title = "Score",      w = 76,  align = "RIGHT" },
    { key = "wave",   title = "Reached",    w = 140, align = "LEFT" },
    { key = "combo",  title = "Combo",      w = 46,  align = "CENTER" },
    { key = "kills",  title = "Kills",      w = 40,  align = "RIGHT" },
    { key = "moves",  title = "Moves",      w = 46,  align = "RIGHT" },
    { key = "date",   title = "Date",       w = 86,  align = "RIGHT" },
}

local function MakeTable(parent)
    local t = CreateFrame("Frame", nil, parent)
    t:SetPoint("TOPLEFT", 14, -62)
    t:SetPoint("BOTTOMRIGHT", -14, 36)
    t.headers, t.rows = {}, {}
    t:EnableMouseWheel(true)
    t:SetScript("OnMouseWheel", function(self, d)
        self.offset = max(0, min((self.offset or 0) - d * 3, max(0, (self.count or 0) - ROWS)))
        L:Refresh()
    end)
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, t)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", 0, -22 - (i - 1) * ROW_H)
        row:SetPoint("RIGHT", 0, 0)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0)
        row.bg = bg
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(); hl:SetColorTexture(1, 0.82, 0, 0.10)
        row.me = row:CreateTexture(nil, "BORDER")
        row.me:SetAllPoints(); row.me:SetColorTexture(1, 0.82, 0, 0.13)
        row.cells = {}
        t.rows[i] = row
    end
    return t
end

local function Layout(t, cols)
    for _, h in ipairs(t.headers) do h:Hide() end
    for _, row in ipairs(t.rows) do for _, c in ipairs(row.cells) do c:Hide() end end
    local x = 0
    for i, col in ipairs(cols) do
        local h = t.headers[i]
        if not h then
            h = CreateFrame("Button", nil, t)
            h:SetHeight(20)
            h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            h.text:SetAllPoints()
            local line = h:CreateTexture(nil, "BACKGROUND")
            line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
            line:SetColorTexture(0.6, 0.5, 0.25, 0.8)
            t.headers[i] = h
        end
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", x, 0)
        h:SetWidth(col.w)
        h.text:SetJustifyH(col.align)
        h.col = col
        h:Show()
        for _, row in ipairs(t.rows) do
            local fs = row.cells[i]
            if not fs then
                fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                if fs.SetWordWrap then fs:SetWordWrap(false) end
                row.cells[i] = fs
            end
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", x + (col.align == "RIGHT" and 0 or 4), 0)
            fs:SetWidth(col.w - 4)
            fs:SetJustifyH(col.align)
            fs:Show()
        end
        x = x + col.w + 4
    end
end

local function Fill(t, list, cols, cellsOf, isMe, onClick)
    t.count = #list
    t.offset = max(0, min(t.offset or 0, max(0, #list - ROWS)))
    for i, row in ipairs(t.rows) do
        local idx = i + t.offset
        local item = list[idx]
        if item then
            local cells = cellsOf(item, idx)
            for c = 1, #cols do row.cells[c]:SetText(cells[c] or "") end
            row.me:SetShown(isMe(item) and true or false)
            row:SetScript("OnClick", function(_, button) onClick(item, button) end)
            row:Show()
        else
            row:Hide()
        end
    end
    t.empty:SetShown(#list == 0)
end

local function HeaderTitles(t, cols, sortKey, desc)
    for i, col in ipairs(cols) do
        local h = t.headers[i]
        local title = col.title
        if sortKey and col.key == sortKey then title = title .. (desc and " v" or " ^") end
        h.text:SetText(title)
        if col.sort then
            h:SetScript("OnClick", function()
                if L.sortKey == col.key then L.sortDesc = not L.sortDesc
                else L.sortKey, L.sortDesc = col.key, col.key ~= "name" end
                L:Refresh()
            end)
        else
            h:SetScript("OnClick", nil)
        end
    end
end

-- stats page: two columns of label / value
local STAT_LINES = 13
local function MakeStats(parent)
    local s = CreateFrame("Frame", nil, parent)
    s:SetPoint("TOPLEFT", 14, -62)
    s:SetPoint("BOTTOMRIGHT", -14, 36)
    s.who = s:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    s.who:SetPoint("TOP", 0, -2)
    s.sub = s:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    s.sub:SetPoint("TOP", s.who, "BOTTOM", 0, -3)
    local prev = CreateFrame("Button", nil, s, "UIPanelButtonTemplate")
    prev:SetSize(28, 22); prev:SetPoint("TOPLEFT", 0, 0); prev:SetText("<")
    local nextB = CreateFrame("Button", nil, s, "UIPanelButtonTemplate")
    nextB:SetSize(28, 22); nextB:SetPoint("TOPRIGHT", 0, 0); nextB:SetText(">")
    prev:SetScript("OnClick", function() L:CycleStats(-1) end)
    s.remove = CreateFrame("Button", nil, s, "UIPanelButtonTemplate")
    s.remove:SetSize(140, 22)
    s.remove:SetPoint("BOTTOMRIGHT", 0, -28)
    s.remove:SetText("Remove character")
    s.remove:SetScript("OnClick", function()
        local key = L.shownKey
        local c = key and ns.db.chars[key]
        if not c then return end
        local dlg = StaticPopup_Show("MARISCOS_SHELLCRACKER_REMOVE", c.name)
        if dlg then dlg.data = key end
    end)
    nextB:SetScript("OnClick", function() L:CycleStats(1) end)
    s.lines = {}
    for col = 1, 2 do
        for i = 1, STAT_LINES do
            local l = s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            l:SetPoint("TOPLEFT", (col - 1) * 290 + 10, -46 - (i - 1) * 17)
            l:SetWidth(150); l:SetJustifyH("LEFT")
            local v = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            v:SetPoint("LEFT", l, "RIGHT", 0, 0)
            v:SetWidth(122); v:SetJustifyH("RIGHT")
            s.lines[#s.lines+1] = { l = l, v = v }
        end
    end
    return s
end

local function Build()
    local ok, f = pcall(CreateFrame, "Frame", "MariscosShellcrackerLeaderboard", UIParent, "BasicFrameTemplateWithInset")
    if not ok or not f then f = CreateFrame("Frame", "MariscosShellcrackerLeaderboard", UIParent, BackdropTemplateMixin and "BackdropTemplate") end
    f:SetSize(WIN_W, WIN_H)
    local main = ns.UI:GetFrame()
    if main and main:IsShown() then f:SetPoint("TOP", main, "BOTTOM", 0, -6) else f:SetPoint("CENTER") end
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local title = f.TitleText or (f.TitleContainer and f.TitleContainer.TitleText)
    if type(title) ~= "table" then
        title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -5)
    end
    title:SetText("Shellcracker Leaderboard")

    f.tabs = {}
    for i, name in ipairs(TABS) do
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(110, 24)
        b:SetPoint("TOPLEFT", 14 + (i - 1) * 114, -30)
        b:SetText(name)
        b:SetScript("OnClick", function() L.tab = i; L:Refresh() end)
        f.tabs[i] = b
    end

    f.table = MakeTable(f)
    f.table.empty = f.table:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    f.table.empty:SetPoint("CENTER")
    f.table.empty:SetText("No games played yet. Finish a fight to get on the board!")
    f.stats = MakeStats(f)

    f.foot = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.foot:SetPoint("BOTTOMLEFT", 16, 14)
    f.foot:SetPoint("BOTTOMRIGHT", -16, 14)
    f.foot:SetJustifyH("LEFT")

    tinsert(UISpecialFrames, "MariscosShellcrackerLeaderboard")
    f:Hide()
    return f
end

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs["MARISCOS_SHELLCRACKER_REMOVE"] = {
    text = "Remove %s from the Shellcracker leaderboard? Its stats and runs will be deleted.",
    button1 = YES or "Yes", button2 = NO or "No",
    OnAccept = function(_, key)
        if not key then return end
        Stats:Remove(key)
        if L.statKey == key or L.shownKey == key then L.statKey = "ALL" end
        L:Refresh()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function SortedChars()
    local list = {}
    for key, c in pairs(ns.db.chars or {}) do
        if c.games > 0 or c.best.score > 0 then list[#list+1] = { key = key, c = c } end
    end
    local col
    for _, cc in ipairs(CHAR_COLS) do if cc.key == L.sortKey then col = cc end end
    col = col or CHAR_COLS[4]
    local desc = L.sortDesc
    table.sort(list, function(a, b)
        local va, vb = col.sort(a.c), col.sort(b.c)
        if va ~= vb then if desc then return va > vb else return va < vb end end
        return a.c.best.score > b.c.best.score
    end)
    return list
end

-- characters shown in the Stats page cycle: "ALL" first, then by best score
function L:StatsKeys()
    local keys = { "ALL" }
    local list = {}
    for key, c in pairs(ns.db.chars or {}) do list[#list+1] = { key = key, s = c.best.score } end
    table.sort(list, function(a, b) return a.s > b.s end)
    for _, it in ipairs(list) do keys[#keys+1] = it.key end
    return keys
end

function L:CycleStats(d)
    local keys = self:StatsKeys()
    local cur = 1
    for i, k in ipairs(keys) do if k == self.statKey then cur = i end end
    cur = (cur - 1 + d) % #keys + 1
    self.statKey = keys[cur]
    self:Refresh()
end

local function Totals()
    local t = NewChar("All characters", "")
    local n = 0
    for _, c in pairs(ns.db.chars or {}) do
        n = n + 1
        for _, f in ipairs({ "games", "kills", "bossKills", "totalScore", "moves", "gems", "damage", "taken", "healed", "time" }) do
            t[f] = t[f] + (c[f] or 0)
        end
        for _, k in ipairs(SPECIALS) do t.specials[k] = t.specials[k] + (c.specials[k] or 0) end
        t.best.score = max(t.best.score, c.best.score)
        t.best.wave = max(t.best.wave, c.best.wave)
        t.best.combo = max(t.best.combo, c.best.combo)
        t.best.move = max(t.best.move, c.best.move or 0)
    end
    return t, n
end

function L:RefreshStats()
    local s = win.stats
    local _, myKey = Stats:Char()
    local key = self.statKey or myKey
    local c, n
    s.remove:SetShown(key ~= "ALL")
    self.shownKey = key
    if key == "ALL" then
        c, n = Totals()
        s.who:SetText("|cffffd100All characters|r")
        s.sub:SetText(n .. (n == 1 and " character" or " characters") .. " on this account")
    else
        c = ns.db.chars[key]
        if not c then self.statKey = nil; key = myKey; c = Stats:Char() end
        s.who:SetText(CharName(c, key, true))
        s.sub:SetText(("Level %d %s  ·  "):format(c.slevel or 1, (ns.TitleFor(c.slevel or 1, c.faction))) ..
            "Last played " .. (date and c.lastPlayed and date("%d %b %Y", c.lastPlayed) or "-"))
    end
    local avg = c.games > 0 and floor(c.totalScore / c.games) or 0
    local lines = {
        { "Games played", comma(c.games) },
        { "Best score", comma(c.best.score) },
        { "Average score", comma(avg) },
        { "Total score", comma(c.totalScore) },
        { "Furthest makrura", Reached(c.best.wave) },
        { "Biggest combo", c.best.combo > 0 and ("x" .. c.best.combo) or "-" },
        { "Best single move", comma(c.best.move or 0) .. " damage" },
        { "Makrura defeated", comma(c.kills) },
        { "Lord Angler defeated", comma(c.bossKills) },
        { "Time played", Duration(c.time) },
        { "Moves made", comma(c.moves) },
        { "Gems shattered", comma(c.gems) },
        { "", "" },
        { "Damage dealt", comma(c.damage) },
        { "Damage taken", comma(c.taken) },
        { "Health healed", comma(c.healed) },
        { "Gold looted", ns.Prog:Money(c.goldEarned or 0) },
        { "", "" },
        { "|cffff7f26Flame Gems|r made", comma(c.specials.flame) },
        { "|cff99ccffStar Gems|r made", comma(c.specials.star) },
        { "|cffffffffHypercubes|r made", comma(c.specials.hyper) },
        { "|cffffe680Supernovas|r made", comma(c.specials.nova) },
    }
    for i, ln in ipairs(s.lines) do
        local d = lines[i]
        ln.l:SetText(d and d[1] or "")
        ln.v:SetText(d and d[2] or "")
    end
    win.foot:SetText("|cff888888Use < > to switch between characters and the account total.|r")
end

function L:Refresh()
    if not win or not win:IsShown() then return end
    self.tab = self.tab or 1
    for i, b in ipairs(win.tabs) do
        if i == self.tab then b:Disable() else b:Enable() end
    end
    local t = win.table
    local _, myKey = Stats:Char()
    if self.tab == 3 then
        t:Hide(); win.stats:Show()
        return self:RefreshStats()
    end
    win.stats:Hide(); t:Show()
    if self.tab == 1 then
        self.sortKey = self.sortKey or "score"
        if self.sortDesc == nil then self.sortDesc = true end
        Layout(t, CHAR_COLS)
        HeaderTitles(t, CHAR_COLS, self.sortKey, self.sortDesc)
        Fill(t, SortedChars(), CHAR_COLS,
            function(it, idx)
                local c = it.c
                local _, badge = ns.TitleFor(c.slevel or 1, c.faction)
                return { idx .. ".", CharName(c, it.key, true), ("|T%s:14:14|t %d"):format(badge, c.slevel or 1), comma(c.best.score),
                         Reached(c.best.wave), c.best.combo > 0 and ("x" .. c.best.combo) or "-",
                         comma(c.games), comma(c.kills) }
            end,
            function(it) return it.key == myKey end,
            function(it, button)
                if button == "RightButton" then
                    local dlg = StaticPopup_Show("MARISCOS_SHELLCRACKER_REMOVE", it.c.name)
                    if dlg then dlg.data = it.key end
                else
                    self.statKey = it.key; self.tab = 3; self:Refresh()
                end
            end)
        win.foot:SetText("|cff888888Click a header to sort. Click a character for its stats; right-click to remove it.|r")
    else
        Layout(t, RUN_COLS)
        HeaderTitles(t, RUN_COLS)
        local runs = ns.db.runs or {}
        Fill(t, runs, RUN_COLS,
            function(r, idx)
                local c = ns.db.chars[r.key]
                local reached = r.enemy .. (r.tide and r.tide > 1 and (" |cff88ccff(Tide " .. r.tide .. ")|r") or "")
                if r.how == "left" then reached = reached .. " |cff888888(left)|r" end
                return { idx .. ".", CharName(c, r.key), comma(r.score), reached,
                         r.combo > 0 and ("x" .. r.combo) or "-", r.kills or 0, r.moves, r.date or "" }
            end,
            function(r) return r.key == myKey end,
            function(r) if ns.db.chars[r.key] then self.statKey = r.key; self.tab = 3; self:Refresh() end end)
        win.foot:SetText("|cff888888The " .. MAX_RUNS .. " best runs of all your characters. \"(left)\": a new game was started mid-fight.|r")
    end
end

function L:Toggle(tab)
    win = win or Build()
    if win:IsShown() and (not tab or tab == self.tab) then win:Hide() return end
    if tab then self.tab = tab end
    win:Show()
    self:Refresh()
end

function L:IsShown() return win and win:IsShown() end
