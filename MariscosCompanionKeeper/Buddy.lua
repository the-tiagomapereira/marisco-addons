-- Marisco's Companion Keeper - Buddy
-- Daily actions, hearts and happiness (in the spirit of a buddy system).
--
-- Each action has a check script that runs when its game events fire and returns
--   1 = yes, the action happened   /   0 = no
-- Each day 4 challenges are picked from a pool of 8. Finishing one earns a heart (up to 3 a day);
-- after that, challenges still give bonus happiness. Pet, fetch, quests, level-ups and time spent
-- together add happiness on top, any time. Happiness climbs from Unhappy to Soulbound.

local ADDON, ns = ...

local B = {}
ns.Buddy = B

B.HEARTS_PER_DAY = 3
B.HEART_POINTS   = 10     -- happiness per heart
B.SUMMON_BONUS   = 0.20   -- +20% happiness while your companion is running alongside you
B.MEDIA          = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
B.HEART_FULL     = B.MEDIA .. "HeartFull"
B.HEART_EMPTY    = B.MEDIA .. "HeartEmpty"

-- Happiness levels: a companion starts Unhappy. "at" = happiness needed.
-- An active day of play is roughly 60-100 happiness.
B.LEVELS = {
    { name = "Unhappy",      at = 0,    color = { 1.00, 0.25, 0.25 } },
    { name = "Content",      at = 30,   color = { 1.00, 0.60, 0.20 } },
    { name = "Happy",        at = 120,  color = { 1.00, 0.85, 0.20 } },
    { name = "Joyful",       at = 300,  color = { 0.35, 0.90, 0.35 } },
    { name = "Best Friends", at = 600,  color = { 1.00, 0.45, 0.75 } },
    { name = "Soulbound",    at = 1000, color = { 0.65, 0.45, 1.00 } },
}

function B.HeartIcon(size)
    return ("|T%s:%d:%d|t"):format(B.HEART_FULL, size or 14, size or 14)
end

local function ColorText(c, text)
    return ("|cff%02x%02x%02x%s|r"):format(c[1] * 255, c[2] * 255, c[3] * 255, text)
end
B.ColorText = ColorText

------------------------------------------------------------------------------------------
-- Check scripts (return 1 for yes, 0 for no)
------------------------------------------------------------------------------------------

local BINDER_ICON = 132052  -- Interface\GossipFrame\BinderGossipIcon ("Make this inn your home")

local scanTip
local function NpcSubtitle()
    -- second tooltip line of the NPC you're talking to, e.g. "Innkeeper"
    local text
    pcall(function()
        if C_TooltipInfo and C_TooltipInfo.GetUnit then
            local data = C_TooltipInfo.GetUnit("npc")
            local line = data and data.lines and data.lines[2]
            text = line and line.leftText
        else
            if not scanTip then
                scanTip = CreateFrame("GameTooltip", "MariscosCompanionKeeperScanTip", nil, "GameTooltipTemplate")
            end
            scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
            scanTip:SetUnit("npc")
            local fs = _G["MariscosCompanionKeeperScanTipTextLeft2"]
            text = fs and fs:GetText()
            scanTip:Hide()
        end
    end)
    return text
end

local function TalkingToInnkeeper()
    local found = false
    pcall(function()
        if C_GossipInfo and C_GossipInfo.GetOptions then
            for _, o in ipairs(C_GossipInfo.GetOptions() or {}) do
                local name = type(o.name) == "string" and strlower(o.name) or ""
                if o.type == "binder" or o.icon == BINDER_ICON
                   or name:find("inn your home", 1, true) then
                    found = true
                end
            end
        end
        if not found and GetGossipOptions then
            local t = { GetGossipOptions() }
            for i = 2, #t, 2 do
                if t[i] == "binder" then found = true end
            end
        end
    end)
    if not found then found = (NpcSubtitle() == "Innkeeper") end
    return found
end

local FOOD_BUFFS = { ["Food"] = true, ["Drink"] = true, ["Food & Drink"] = true, ["Refreshment"] = true }
local function EatingOrDrinking()
    local found = false
    pcall(function()
        for i = 1, 40 do
            local name
            if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
                local d = C_UnitAuras.GetBuffDataByIndex("player", i)
                name = d and d.name
            elseif UnitBuff then
                name = UnitBuff("player", i)
            end
            if not name then break end
            if FOOD_BUFFS[name] then found = true break end
        end
    end)
    return found
end


-- Kills are read from the experience message ("<mob> dies, you gain N experience.").
-- The combat log is off limits to addons on Forever: registering for it gets the addon blocked.
local function CheckKill(event, msg)
    if type(msg) == "string" and msg:find(" dies", 1, true) then
        return 1
    end
    return 0
end

local function CheckNewZone()
    local zone = GetRealZoneText and GetRealZoneText()
    if type(zone) ~= "string" or zone == "" then return 0 end
    local r = B:Record(B:ChosenID())
    if not r then return 0 end
    if r.seen[zone] then return 0 end
    r.seen[zone] = true
    return 1
end

local function Minutes(prog, need)
    return ("%d/%d min"):format(math.min(math.floor((prog or 0) / 60), need / 60), need / 60)
end

------------------------------------------------------------------------------------------
-- Daily challenges: a pool of 8, four are picked each day
------------------------------------------------------------------------------------------

B.DAILY_COUNT = 4

B.ACTIONS = {
    {
        key = "inn", name = "Talk to an innkeeper",
        desc = "Speak with any innkeeper.",
        icon = "Interface\\Icons\\INV_Misc_Rune_01",
        reaction = "loved meeting the innkeeper!",
        events = { "GOSSIP_SHOW", "MERCHANT_SHOW" },
        check = function(event)
            return TalkingToInnkeeper() and 1 or 0
        end,
    },
    {
        key = "meal", name = "Eat or drink something",
        desc = "Sit down with food or drink.",
        icon = "Interface\\Icons\\INV_Misc_Food_15",
        reaction = "enjoyed sharing a meal with you!",
        events = { "UNIT_AURA" },
        check = function(event, unit)
            if unit ~= "player" then return 0 end
            return EatingOrDrinking() and 1 or 0
        end,
    },
    {
        key = "fight", name = "Defeat 5 enemies", need = 5,
        desc = "Defeat enemies that give you experience.",
        icon = "Interface\\Icons\\Ability_DualWield",
        reaction = "was thrilled by your adventure!",
        events = { "CHAT_MSG_COMBAT_XP_GAIN" },
        check = CheckKill,
    },
    {
        key = "travel", name = "Visit 2 different zones", need = 2,
        desc = "Zones you're in count once each, today.",
        icon = "Interface\\Icons\\INV_Misc_Map_01",
        reaction = "loved seeing the world with you!",
        events = { "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" },
        check = CheckNewZone,
    },
    {
        key = "quest", name = "Complete 2 quests", need = 2,
        desc = "Turn in any quests.",
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        reaction = "is proud of your good deeds!",
        events = { "QUEST_TURNED_IN" },
        check = function() return 1 end,
    },
    {
        key = "rest", name = "Relax in an inn or city", need = 120,
        desc = "Spend 2 minutes in a resting area (inn or city).",
        icon = "Interface\\Icons\\Spell_Nature_Sleep",
        reaction = "had a lovely nap by the fire!",
        format = Minutes,
        ticker = function() return IsResting and IsResting() end,
    },
    {
        key = "together", name = "Spend 15 minutes together", need = 900,
        desc = "Keep your companion running alongside you.",
        icon = "Interface\\Icons\\INV_Box_PetCarrier_01",
        reaction = "treasures the time with you!",
        format = Minutes,
        ticker = function() return B:IsOut() end,
    },
    {
        key = "fetch", name = "Win a game of fetch",
        desc = "Use the Play button and catch the ball.",
        icon = B.MEDIA .. "Ball",
        reaction = "can't stop wagging after that game!",
    },
}
B.byKey = {}
for _, a in ipairs(B.ACTIONS) do B.byKey[a.key] = a end

------------------------------------------------------------------------------------------
-- Together: interactions that never run out
------------------------------------------------------------------------------------------

B.BONUS_POINTS   = 5      -- a challenge finished after today's 3 hearts
B.PET_POINTS     = 2
B.PET_COOLDOWN   = 15 * 60
B.FETCH_POINTS   = 3
B.FETCH_COOLDOWN = 20 * 60
B.QUEST_POINTS   = 2
B.LEVEL_POINTS   = 15
B.TIME_POINTS    = 1      -- every 10 minutes running alongside you
B.TIME_EVERY     = 10 * 60

-- Walk together: yards travelled with your companion running alongside you (adds up across days).
-- Milestones at 3,000 / 6,000 / 8,000 / 10,000 yards, then every 5,000 yards after that.
B.WALK_STEPS   = { 3000, 6000, 8000, 10000 }
B.WALK_REWARDS = { 15, 25, 35, 50 }
B.WALK_AFTER   = 5000    -- after the last step: a milestone every 5,000 yards...
B.WALK_AFTER_REWARD = 20 -- ...worth this much
B.WALK_MAX_SPEED = 60    -- yards per second; anything faster is a teleport or a flight path

B.TOGETHER = {
    { name = "Pet",            text = ("+%d, every 15 min"):format(B.PET_POINTS),   icon = B.MEDIA .. "Paw" },
    { name = "Play fetch",     text = ("+%d, every 20 min"):format(B.FETCH_POINTS), icon = B.MEDIA .. "Ball" },
    { name = "Complete a quest", text = ("+%d each"):format(B.QUEST_POINTS),        icon = "Interface\\Icons\\INV_Misc_Note_01" },
    { name = "Level up",       text = ("+%d"):format(B.LEVEL_POINTS),              icon = "Interface\\Icons\\Spell_Holy_SurgeOfLight" },
    { name = "Time together",  text = ("+%d every 10 min while summoned"):format(B.TIME_POINTS), icon = "Interface\\Icons\\INV_Box_PetCarrier_01" },
    { name = "Walk together",  text = "+15 to +50 at 3k, 6k, 8k, 10k yards", icon = "Interface\\Icons\\Ability_Tracking" },
}

------------------------------------------------------------------------------------------
-- Days, records, levels
------------------------------------------------------------------------------------------

local function Now() return (GetServerTime and GetServerTime()) or time() end

-- An id for "today" that changes at the daily reset (or local midnight if the client can't say),
-- plus the seconds left until then.
function B:DayKey()
    local now = Now()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
        local ok, secs = pcall(C_DateAndTime.GetSecondsUntilDailyReset)
        if ok and type(secs) == "number" and secs > 0 then
            return "r" .. math.floor((now + secs) / 86400 + 0.5), secs
        end
    end
    local t = date("*t")
    return date("%Y-%m-%d"), 86400 - (t.hour * 3600 + t.min * 60 + t.sec)
end

-- Today's four challenges: the same for everyone on the same day, different every day.
local function PickForDay(day)
    local seed = 0
    for i = 1, #day do seed = (seed * 31 + day:byte(i)) % 2147483647 end
    local keys = {}
    for _, a in ipairs(B.ACTIONS) do keys[#keys + 1] = a.key end
    for i = #keys, 2, -1 do
        seed = (seed * 1103515245 + 12345) % 2147483648
        local j = (seed % i) + 1
        keys[i], keys[j] = keys[j], keys[i]
    end
    local picks = {}
    for i = 1, B.DAILY_COUNT do picks[i] = keys[i] end
    return picks
end
B.PickForDay = PickForDay

function B:ChosenID()
    local s = ns.db and ns.db.selected
    return s and s.id
end

function B:IsOut()
    local id = self:ChosenID()
    return id ~= nil and ns.Journal.summonedID == id
end

-- A companion's saved record, reset to a fresh day when the day changes.
function B:Record(id)
    if not id then return nil end
    ns.db.pets = ns.db.pets or {}
    local r = ns.db.pets[id]
    if not r then
        r = { happy = 0 }
        ns.db.pets[id] = r
    end
    local day = self:DayKey()
    if r.day ~= day then
        r.day, r.hearts, r.done, r.prog, r.seen, r.today = day, 0, {}, {}, {}, 0
        r.picks = PickForDay(day)
    end
    r.done, r.prog, r.seen = r.done or {}, r.prog or {}, r.seen or {}
    r.today = r.today or 0
    r.timeAcc = r.timeAcc or 0
    r.walked = r.walked or 0
    r.walkStep = r.walkStep or 1
    if type(r.picks) ~= "table" or #r.picks ~= self.DAILY_COUNT then r.picks = PickForDay(day) end
    return r
end

-- Today's challenge definitions, in order.
function B:TodayActions(r)
    local list = {}
    for _, key in ipairs((r and r.picks) or PickForDay(self:DayKey())) do
        if self.byKey[key] then list[#list + 1] = self.byKey[key] end
    end
    return list
end

function B:IsToday(r, key)
    for _, k in ipairs(r.picks) do if k == key then return true end end
    return false
end

function B:AllDone(r)
    for _, k in ipairs(r.picks) do if not r.done[k] then return false end end
    return true
end

-- Level index, the level, and the next level (nil at the top).
function B:Level(points)
    local idx = 1
    for i, l in ipairs(self.LEVELS) do
        if (points or 0) >= l.at then idx = i end
    end
    return idx, self.LEVELS[idx], self.LEVELS[idx + 1]
end

local function PlaySoundSafe(kit, fallback)
    local id = SOUNDKIT and SOUNDKIT[kit] or fallback
    if id then pcall(PlaySound, id) end
end

local function PetName(id)
    local pet = ns.Journal:Get(id)
    return (pet and pet.name) or (ns.db.selected and ns.db.selected.name) or "Your companion"
end

------------------------------------------------------------------------------------------
-- Happiness
------------------------------------------------------------------------------------------

-- Add happiness to the chosen companion. reason = chat line (nil = quiet), noBonus = skip the
-- summon bonus. Returns the points added.
function B:Gain(points, reason, noBonus)
    local id = self:ChosenID()
    if not id or points <= 0 then return 0 end
    local r = self:Record(id)
    local out = self:IsOut()
    if out and not noBonus then points = math.floor(points * (1 + self.SUMMON_BONUS) + 0.5) end

    local before = self:Level(r.happy)
    r.happy = r.happy + points
    r.today = r.today + points
    local after, level = self:Level(r.happy)
    local name = PetName(id)

    if reason then
        ns.Print(("%s |cffffffff%s|r %s |cff9d9d9d(+%d happiness%s)|r")
            :format(B.HeartIcon(14), name, reason, points, (out and not noBonus) and ", companion bonus" or ""))
    end
    if after > before then
        ns.Print(("|cffffffff%s|r is now %s!"):format(name, ColorText(level.color, level.name)))
        PlaySoundSafe("LEVELUP", 888)
    end
    if ns.UI and ns.UI.OnGain then ns.UI:OnGain(points) end
    return points
end

------------------------------------------------------------------------------------------
-- Daily challenge progress
------------------------------------------------------------------------------------------

function B:Complete(key)
    local id = self:ChosenID()
    local a = self.byKey[key]
    if not (id and a) then return false end
    local r = self:Record(id)
    if r.done[key] or not self:IsToday(r, key) then return false end

    r.done[key] = true
    r.prog[key] = a.need or 1

    if r.hearts < self.HEARTS_PER_DAY then
        r.hearts = r.hearts + 1
        self:Gain(self.HEART_POINTS, ("%s |cff9d9d9d(%d/%d hearts today)|r"):format(a.reaction, r.hearts, self.HEARTS_PER_DAY))
        PlaySoundSafe("IG_QUEST_LIST_COMPLETE", 878)
        if ns.UI and ns.UI.OnHeartEarned then ns.UI:OnHeartEarned(r.hearts) end
    else
        self:Gain(self.BONUS_POINTS, a.reaction .. " |cff9d9d9d(bonus)|r")
        PlaySoundSafe("IG_QUEST_LIST_COMPLETE", 878)
    end
    if self:AllDone(r) then
        ns.Print(("all of today's challenges done with |cffffffff%s|r. Pet and play keep it happy until tomorrow."):format(PetName(id)))
    end
    if ns.UI then ns.UI:Refresh() end
    return true
end

function B:Progress(key, amount, quiet)
    local id = self:ChosenID()
    local a = self.byKey[key]
    if not (id and a) then return end
    local r = self:Record(id)
    if r.done[key] or not self:IsToday(r, key) then return end
    r.prog[key] = (r.prog[key] or 0) + (amount or 1)
    if r.prog[key] >= (a.need or 1) then
        self:Complete(key)
    elseif ns.UI and not quiet then
        ns.UI:Refresh()
    end
end

------------------------------------------------------------------------------------------
-- Pet and fetch
------------------------------------------------------------------------------------------

-- Seconds left on a cooldown (0 = ready).
function B:CooldownLeft(which)
    local r = self:Record(self:ChosenID())
    if not r then return 0 end
    local at, cd
    if which == "pet" then
        at, cd = r.petAt, self.PET_COOLDOWN
    else
        at, cd = r.fetchAt, self.FETCH_COOLDOWN
    end
    return math.max(0, (at or 0) + cd - Now())
end

local PET_LINES = {
    "leans into your hand.", "closes its eyes happily.", "nuzzles you.",
    "does a happy little wiggle.", "looks very pleased with itself.",
}

function B:Pet()
    local id = self:ChosenID()
    if not id then return false, "Choose a companion first." end
    local left = self:CooldownLeft("pet")
    if left > 0 then
        return false, ("%s wants a little space. Pet again in %s."):format(PetName(id), B.FormatTime(left))
    end
    local r = self:Record(id)
    r.petAt = Now()
    self:Gain(self.PET_POINTS, PET_LINES[math.random(#PET_LINES)])
    PlaySoundSafe("IG_ABILITY_ICON_DROP", 1203)
    if ns.UI then ns.UI:Refresh() end
    return true
end

function B:CanPlay()
    local id = self:ChosenID()
    if not id then return false, "Choose a companion first." end
    local left = self:CooldownLeft("fetch")
    if left > 0 then
        return false, ("%s is still catching its breath. Play again in %s."):format(PetName(id), B.FormatTime(left))
    end
    return true
end

function B:FetchWon()
    local id = self:ChosenID()
    if not id then return end
    local r = self:Record(id)
    r.fetchAt = Now()
    self:Gain(self.FETCH_POINTS, "loved playing fetch with you!")
    self:Progress("fetch", 1)
    if ns.UI then ns.UI:Refresh() end
end

function B.FormatTime(secs)
    secs = math.max(0, math.floor(secs or 0))
    local h, m = math.floor(secs / 3600), math.floor((secs % 3600) / 60)
    if h > 0 then return ("%dh %dm"):format(h, m) end
    if m > 0 then return ("%dm"):format(m) end
    return ("%ds"):format(secs)
end

------------------------------------------------------------------------------------------
-- Event wiring
------------------------------------------------------------------------------------------

function B:Init()
    local byEvent = {}
    for _, a in ipairs(self.ACTIONS) do
        for _, e in ipairs(a.events or {}) do
            byEvent[e] = byEvent[e] or {}
            table.insert(byEvent[e], a)
        end
    end
    byEvent.QUEST_TURNED_IN = byEvent.QUEST_TURNED_IN or {}
    byEvent.PLAYER_LEVEL_UP = byEvent.PLAYER_LEVEL_UP or {}

    local f = CreateFrame("Frame")
    for e in pairs(byEvent) do pcall(f.RegisterEvent, f, e) end
    f:SetScript("OnEvent", function(_, event, ...)
        local list = byEvent[event]
        local id = B:ChosenID()
        if not (list and id) then return end

        -- Together rewards (any day, no limit)
        if event == "QUEST_TURNED_IN" then
            B:Gain(B.QUEST_POINTS, "is proud of your good deed!")
        elseif event == "PLAYER_LEVEL_UP" then
            B:Gain(B.LEVEL_POINTS, "is cheering for your new level!")
        end

        -- Daily challenges: run each check script, 1 = yes
        local r = B:Record(id)
        for _, a in ipairs(list) do
            if a.check and B:IsToday(r, a.key) and not r.done[a.key] then
                local ok, result = pcall(a.check, event, ...)
                if ok and result == 1 then B:Progress(a.key, 1) end
            end
        end
    end)
    self.frame = f

    -- Once a second: time-based challenges and time together.
    local acc = 0
    f:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 1 then return end
        local step = math.floor(acc)
        acc = acc - step
        local id = B:ChosenID()
        if not id then return end
        local r = B:Record(id)
        for _, a in ipairs(B.ACTIONS) do
            if a.ticker and B:IsToday(r, a.key) and not r.done[a.key] then
                local ok, yes = pcall(a.ticker)
                if ok and yes then B:Progress(a.key, step, true) end
            end
        end
        B:TrackWalk(r, step)
        if B:IsOut() then
            r.timeAcc = r.timeAcc + step
            if r.timeAcc >= B.TIME_EVERY then
                r.timeAcc = r.timeAcc - B.TIME_EVERY
                B:Gain(B.TIME_POINTS, nil, true)
            end
        end
    end)
end

------------------------------------------------------------------------------------------
-- Walk together
------------------------------------------------------------------------------------------

-- Player position in world yards: x, y, and an id for the continent / instance.
function B:Position()
    local ok, y, x, _, inst = pcall(UnitPosition, "player")
    if ok then
        local good = pcall(function() return x + y end)
        if good and type(x) == "number" and type(y) == "number" then return x, y, inst end
    end
    local ok2, x2, y2, cont = pcall(function()
        local mapID = C_Map.GetBestMapForUnit("player")
        local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
        if not pos then return end
        local c, world = C_Map.GetWorldPosFromMapPos(mapID, pos)
        if not world then return end
        local wx, wy = world:GetXY()
        return wx, wy, c
    end)
    if ok2 and type(x2) == "number" and type(y2) == "number" then return x2, y2, cont end
    return nil
end

-- The next milestone: yards needed, reward, and which step it is (1-4, then 5+ for the extras).
function B:WalkGoal(r)
    local n = r.walkStep or 1
    local steps = self.WALK_STEPS
    if n <= #steps then return steps[n], self.WALK_REWARDS[n], n end
    return steps[#steps] + (n - #steps) * self.WALK_AFTER, self.WALK_AFTER_REWARD, n
end

-- Start of the current milestone (for the progress bar).
function B:WalkStart(r)
    local n = r.walkStep or 1
    if n == 1 then return 0 end
    local prev = r.walkStep
    r.walkStep = n - 1
    local goal = self:WalkGoal(r)
    r.walkStep = prev
    return goal
end

local lastPos
function B:TrackWalk(r, step)
    local can = self:IsOut()
    pcall(function()
        if UnitOnTaxi and UnitOnTaxi("player") then can = false end
        if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then can = false end
    end)
    local x, y, inst = self:Position()
    self.walkAvailable = (x ~= nil)
    if not (can and x) then
        lastPos = x and { x, y, inst } or nil
        return
    end
    if lastPos and lastPos[3] == inst then
        local dx, dy = x - lastPos[1], y - lastPos[2]
        local d = math.sqrt(dx * dx + dy * dy)
        if d > 0.5 and d <= self.WALK_MAX_SPEED * step then
            self:AddWalk(r, d)
        end
    end
    lastPos = { x, y, inst }
end

function B:AddWalk(r, yards)
    r.walked = r.walked + yards
    local goal, reward, n = self:WalkGoal(r)
    while r.walked >= goal do
        r.walkStep = n + 1
        self:Gain(reward, ("walked %s yards with you! |cff9d9d9d(Walk together, step %d)|r")
            :format(B.Yards(goal), n), true)
        PlaySoundSafe("IG_QUEST_LIST_COMPLETE", 878)
        goal, reward, n = self:WalkGoal(r)
    end
end

function B.Yards(n)
    n = math.floor((n or 0) + 0.5)
    local s = tostring(n)
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

-- Testing: pretend a challenge happened (/mck test <key>).
function B:Test(key)
    local a = self.byKey[key] or (key == "walk" and { name = "Walk together" })
    if not a then return false end
    local r = self:Record(self:ChosenID())
    if r and key ~= "walk" and not self:IsToday(r, key) then
        ns.Print(("|cffffffff%s|r isn't one of today's challenges."):format(a.name))
        return true
    end
    if key == "fetch" then self:FetchWon() return true end
    if key == "walk" then
        local r = self:Record(self:ChosenID())
        local goal = self:WalkGoal(r)
        self:AddWalk(r, goal - r.walked)
        if ns.UI then ns.UI:Refresh() end
        return true
    end
    self:Progress(key, (a.need or 1))
    return true
end

-- Testing: clear today's progress and cooldowns for the chosen companion (/mck test reset).
function B:ResetToday()
    local id = self:ChosenID()
    if not id then return end
    local r = self:Record(id)
    r.hearts, r.done, r.prog, r.seen, r.today, r.petAt, r.fetchAt = 0, {}, {}, {}, 0, nil, nil
    if ns.UI then ns.UI:Refresh() end
end
