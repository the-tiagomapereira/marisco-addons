-- Marisco's Shellcracker - character progression: level, XP, talents, gold, bags, gear, shop
-- Saved per character (MariscosShellcrackerCharDB.prog). No UI code here.
local _, ns = ...

local floor, max, min, random = math.floor, math.max, math.min, math.random
local P = {}
ns.Prog = P

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------
function P:Data()
    local cdb = ns.cdb
    if not cdb.prog then
        cdb.prog = { level = 1, xp = 0, talents = {}, gold = 0, bags = {}, gear = {}, nextId = 1 }
    end
    local d = cdb.prog
    d.talents = d.talents or {}
    d.bags = d.bags or {}
    d.gear = d.gear or {}
    d.gold = d.gold or 0
    return d
end

function P:Faction()
    local f = UnitFactionGroup and UnitFactionGroup("player")
    return (f == "Alliance") and "Alliance" or "Horde"
end

function P:Level() return self:Data().level end
function P:Title(level) return ns.TitleFor(level or self:Level(), self:Faction()) end

-- a run in progress locks gear and talents
function P:Locked()
    local G = ns.Game
    if G and G.board and not G.over then return true end
    return ns.cdb and ns.cdb.save ~= nil
end

-- copy level and title into the account-wide leaderboard record
function P:Publish()
    if not ns.Stats then return end
    local c = ns.Stats:Char()
    local d = self:Data()
    c.slevel = d.level
    c.faction = self:Faction()
end

---------------------------------------------------------------------------
-- Experience and levels
---------------------------------------------------------------------------
-- returns the list of levels reached (empty if none)
function P:AddXP(amount)
    local d = self:Data()
    local gained = {}
    if d.level >= ns.MAX_LEVEL then return gained, 0 end
    amount = floor(amount * (1 + (self:Mods().xp or 0) / 100) + 0.5)
    d.xp = d.xp + amount
    while d.level < ns.MAX_LEVEL and d.xp >= ns.XPToNext(d.level) do
        d.xp = d.xp - ns.XPToNext(d.level)
        d.level = d.level + 1
        gained[#gained+1] = d.level
    end
    if d.level >= ns.MAX_LEVEL then d.xp = 0 end
    if #gained > 0 then self.cache = nil; self:Publish() end
    return gained, amount
end

function P:KillXP(e)
    local xp = 20 + 5 * e.level
    xp = xp * (1 + 0.5 * ((e.tide or 1) - 1))
    if e.boss then xp = xp * 2 elseif e.rare then xp = xp * 1.5 end
    return floor(xp)
end

function P:ComboXP(cascades)
    if cascades < 4 then return 0 end
    return 15 * (cascades - 3)
end

function P:RunXP(score) return floor((score or 0) / 50) end

---------------------------------------------------------------------------
-- Talents
---------------------------------------------------------------------------
function P:PointsTotal()
    local L = self:Level()
    if L < ns.TALENT_START then return 0 end
    return L - ns.TALENT_START + 1
end

function P:Rank(id) return self:Data().talents[id] or 0 end

function P:TreeSpent(tree, belowTier)
    local n = 0
    for _, t in ipairs(ns.TALENTS) do
        if t.tree == tree and (not belowTier or t.tier < belowTier) then n = n + self:Rank(t.id) end
    end
    return n
end

function P:PointsSpent()
    local n = 0
    for _, r in pairs(self:Data().talents) do n = n + r end
    return n
end

function P:PointsFree() return self:PointsTotal() - self:PointsSpent() end

function P:TierOpen(t) return self:TreeSpent(t.tree, t.tier) >= (t.tier - 1) * 5 end

-- why a point can't be added (nil if it can)
function P:AddBlock(t)
    if self:Locked() then return "Talents are locked during a run." end
    if self:Rank(t.id) >= t.max then return "Fully learned." end
    if self:PointsFree() <= 0 then
        return self:Level() < ns.TALENT_START and ("Talent points start at level " .. ns.TALENT_START .. ".") or "No talent points left."
    end
    if not self:TierOpen(t) then
        return ("Requires %d points in %s."):format((t.tier - 1) * 5, ns.TREES[t.tree].name)
    end
end

function P:RemoveBlock(t)
    if self:Locked() then return "Talents are locked during a run." end
    local r = self:Rank(t.id)
    if r <= 0 then return "No points to remove." end
    -- every deeper talent in this tree must still meet its tier requirement without this point
    local talents = self:Data().talents
    talents[t.id] = r - 1
    local bad
    for _, o in ipairs(ns.TALENTS) do
        if o.tree == t.tree and self:Rank(o.id) > 0 and o.tier > t.tier and not self:TierOpen(o) then bad = o break end
    end
    talents[t.id] = r
    if bad then return ("%s needs this point (tier %d requires %d points)."):format(bad.name, bad.tier, (bad.tier - 1) * 5) end
end

function P:AddPoint(t)
    if self:AddBlock(t) then return false end
    local d = self:Data()
    d.talents[t.id] = self:Rank(t.id) + 1
    self.cache = nil
    return true
end

function P:RemovePoint(t)
    if self:RemoveBlock(t) then return false end
    local d = self:Data()
    local r = self:Rank(t.id) - 1
    d.talents[t.id] = r > 0 and r or nil
    self.cache = nil
    return true
end

function P:ResetTalents()
    if self:Locked() then return false end
    wipe(self:Data().talents)
    self.cache = nil
    return true
end

function P:TalentText(t, rank)
    if rank < 1 then rank = 1 end
    local _, v = next(t.fx)
    return (t.text:format(tostring(v * rank)))
end

---------------------------------------------------------------------------
-- Gold
---------------------------------------------------------------------------
function P:Gold() return self:Data().gold end
function P:AddGold(c) local d = self:Data(); d.gold = max(0, d.gold + floor(c)) end

function P:KillGold(e)
    local c = e.level * e.level * (1 + random())
    if e.boss then c = c * 5 elseif e.rare then c = c * 2 end
    c = c * (1 + 0.5 * ((e.tide or 1) - 1)) * (1 + (self:Mods().gold or 0) / 100)
    return max(1, floor(c))
end

function P:Money(c)
    c = floor(c or 0)
    local g, s, cp = floor(c / 10000), floor(c % 10000 / 100), c % 100
    local GI = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
    local SI = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
    local CI = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
    local out = {}
    if g > 0 then out[#out+1] = g .. GI end
    if s > 0 or g > 0 then out[#out+1] = s .. SI end
    out[#out+1] = cp .. CI
    return table.concat(out, " ")
end

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------
local function pick(t) return t[random(#t)] end
local ITEM_VERSION = 3

local function Weighted(w)          -- w = { [quality] = weight }
    local total = 0
    for _, x in pairs(w) do total = total + x end
    local r = random() * total
    for q = 0, 5 do
        if w[q] then
            r = r - w[q]
            if r <= 0 then return q end
        end
    end
    return 2
end

-- quality of a normal drop (legendaries come from their own roll, see RollDrop)
local function RollQuality(boss, rare, luck)
    local w = boss and { [2] = 40, [3] = 45, [4] = 15 } or (rare and { [1] = 15, [2] = 45, [3] = 32, [4] = 8 })
        or { [0] = 18, [1] = 32, [2] = 35, [3] = 12, [4] = 3 }
    local mult = 1 + (luck or 0) / 50
    if w[3] then w[3] = w[3] * mult end
    if w[4] then w[4] = w[4] * mult end
    return Weighted(w)
end
P.RollQuality = RollQuality

local OLD_TYPE = { WEAPON = "1H", RING = "FINGER" }     -- 0.11 slot names

local function StatScale(ilvl) return (min(65, ilvl) / 60) ^ ns.ILVL_POWER end

-- the stats an item rolls: weapons always have Damage, armor pieces always have Armor
local function PickStats(typeId, n)
    local list, used = {}, {}
    local T = ns.ITEM_TYPES[typeId]
    if n > 0 and T.weapon then list[1] = "dmg"; used.dmg = true end
    if n > 0 and T.armor then list[1] = "armor"; used.armor = true end
    used.armor = true                  -- Armor only comes on armor pieces (as their fixed stat)
    while #list < n do
        local k = pick(ns.STAT_ORDER)
        if not used[k] then used[k] = true; list[#list+1] = k end
    end
    return list
end

local function RollEffect(tier, used)
    local e
    repeat e = pick(ns.ITEM_EFFECTS) until not used[e.key]
    used[e.key] = true
    return { key = e.key, v = e.tiers[tier] }
end

function P:EffectText(fx)
    if fx.legendary then return ns.LEGENDARY_BY_ID[fx.legendary].text end
    for _, e in ipairs(ns.ITEM_EFFECTS) do
        if e.key == fx.key then
            if type(e.text) == "function" then return e.text(fx.v) end
            return e.text:format(fx.v)
        end
    end
    return "?"
end

-- legendary: which one (prefers one you don't own yet)
function P:PickLegendary(slotId)
    if slotId then
        for _, l in ipairs(ns.LEGENDARIES) do if l.slot == slotId then return l end end
    end
    local owned = {}
    local d = self:Data()
    local function mark(it) if it and it.legendary then owned[it.legendary] = true end end
    for _, it in pairs(d.gear) do mark(it) end
    for i = 1, ns.BAG_SIZE do mark(d.bags[i]) end
    for _, it in ipairs(d.buyback or {}) do mark(it) end
    local free = {}
    for _, l in ipairs(ns.LEGENDARIES) do if not owned[l.id] then free[#free+1] = l end end
    if #free == 0 then free = ns.LEGENDARIES end
    return pick(free)
end

function P:NewItem(ilvl, quality, slotId)
    local d = self:Data()
    ilvl = max(1, min(65, floor(ilvl)))
    local Q = ns.QUALITY[quality]
    if slotId and not ns.ITEM_TYPES[slotId] then slotId = OLD_TYPE[slotId] end
    local leg
    if Q.legendary then
        leg = self:PickLegendary(slotId)
        slotId = leg.slot
    end
    if not slotId then                -- random item type, weighted like WoW drops
        local total = 0
        for _, w in pairs(ns.TYPE_WEIGHTS) do total = total + w end
        local r = random() * total
        for t, w in pairs(ns.TYPE_WEIGHTS) do
            r = r - w
            if r <= 0 then slotId = t break end
        end
        slotId = slotId or "1H"
    end
    local item = { v = ITEM_VERSION, id = d.nextId, slot = slotId, q = quality, ilvl = ilvl, stats = {}, fx = {} }
    d.nextId = d.nextId + 1
    -- stats
    local keys = PickStats(slotId, Q.stats)
    local f = StatScale(ilvl) * ns.ITEM_TYPES[slotId].budget
    for _, k in ipairs(keys) do
        item.stats[k] = max(1, floor(random(Q.min, Q.max) * f + 0.5))
    end
    -- effects
    local used = {}
    if leg then
        item.fx[1] = { legendary = leg.id }
        item.legendary = leg.id
    elseif Q.effects then
        for _ = 1, Q.effects do item.fx[#item.fx+1] = RollEffect(Q.tier, used) end
        if Q.extraChance and random() < Q.extraChance then item.fx[#item.fx+1] = RollEffect(Q.tier, used) end
    end
    -- name and icon
    local base = pick(ns.ITEM_BASES[slotId])
    item.icon = "Interface\\Icons\\" .. pick(ns.ITEM_ICONS[slotId])
    if leg then
        item.name, item.icon = leg.name, "Interface\\Icons\\" .. leg.icon
    elseif quality == 0 then
        item.name = pick(ns.POOR_PREFIX) .. " " .. base
    else
        -- the suffix follows the biggest stat that isn't the slot's fixed one
        local best, bestV
        for k, v in pairs(item.stats) do
            if (k ~= "armor" and k ~= "dmg") or #keys == 1 then
                if not bestV or v > bestV then best, bestV = k, v end
            end
        end
        best = best or keys[1]
        item.name = quality == 1 and base or (base .. " " .. ns.STAT_INFO[best].suffix)
    end
    item.sell = max(1, floor((ilvl * ilvl * 1.5 + ilvl * 10) * Q.price))
    return item
end

-- what a makrura drops (nil if nothing). e.wave = its place in the run, e.crazed = Loot-Crazed
function P:RollDrop(e, extraPct)
    local M = self:Mods()
    local D = ns.DROP
    local L = self:Level()
    local ilvl = L + random(-2, 1) + (e.boss and 2 or 0)
    -- legendary roll: Loot-Crazed makrura, bosses and every 5th makrura
    if e.crazed then
        return self:NewItem(ilvl, Weighted({ [3] = D.crazedOdds[3], [4] = D.crazedOdds[4], [5] = D.crazedOdds[5] }))
    end
    local legChance = e.boss and D.legendaryBoss or (((e.wave or 0) % D.legendaryEvery == 0) and D.legendaryChance or 0)
    if legChance > 0 and random() < legChance then return self:NewItem(ilvl, 5) end
    local chance = e.boss and D.boss or (e.rare and D.rare or D.normal)
    chance = chance * (1 + (M.drop or 0) / 100) + (extraPct or 0) / 100
    if random() > chance then return nil end
    return self:NewItem(ilvl, RollQuality(e.boss, e.rare, M.drop))
end

function P:Color(item) return "|c" .. ns.QUALITY[item.q].color end
function P:Link(item) return self:Color(item) .. "[" .. item.name .. "]|r" end

-- tooltip lines: { text, r, g, b }
function P:ItemLines(item)
    local L = {}
    local Q = ns.QUALITY[item.q]
    local function add(t, r, g, b) L[#L+1] = { t, r or 1, g or 1, b or 1 } end
    local hex = Q.color
    local r, g, b = tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255
    add(item.name, r, g, b)
    add(Q.name .. " " .. ns.ITEM_TYPES[item.slot].name .. "     |cff888888Item Level " .. item.ilvl .. "|r", 0.85, 0.85, 0.85)
    for _, k in ipairs(ns.STAT_ORDER) do
        if item.stats[k] then add("+" .. item.stats[k] .. " " .. ns.STAT_INFO[k].name) end
    end
    for _, e in ipairs(item.fx) do
        if e.legendary then add("Unique: " .. self:EffectText(e), 1, 0.5, 0)
        else add("Equip: " .. self:EffectText(e), 0.12, 1, 0) end
    end
    if item.q == 0 then add("Junk: sell it to a vendor.", 0.6, 0.6, 0.6) end
    add("Sell price: " .. self:Money(item.sell), 1, 1, 1)
    return L
end

-- older items: 0.10 and before had WoW stats (re-rolled with the same quality and level);
-- 0.11 had 8 slots (WEAPON / RING / TRINKET become One-Hand / Finger / Trinket)
local OLD_SLOT = { WEAPON = "MAINHAND", RING = "FINGER1", TRINKET = "TRINKET1" }
function P:Migrate()
    local d = self:Data()
    if d.itemVersion == ITEM_VERSION then return end
    local function redo(it)
        if not it then return nil end
        if (it.v or 1) < 2 then
            return self:NewItem(it.ilvl or d.level, min(4, it.q or 2), OLD_TYPE[it.slot] or it.slot)
        end
        it.slot = OLD_TYPE[it.slot] or it.slot
        it.v = ITEM_VERSION
        return it
    end
    for i = 1, ns.BAG_SIZE do d.bags[i] = redo(d.bags[i]) end
    local gear = {}
    for k, it in pairs(d.gear) do gear[OLD_SLOT[k] or k] = redo(it) end
    d.gear = gear
    for i, it in ipairs(d.buyback or {}) do d.buyback[i] = redo(it) end
    d.shop = nil
    d.itemVersion = ITEM_VERSION
    self.cache = nil
end

---------------------------------------------------------------------------
-- Bags and gear
---------------------------------------------------------------------------
function P:BagCount()
    local n = 0
    for i = 1, ns.BAG_SIZE do if self:Data().bags[i] then n = n + 1 end end
    return n
end

function P:AddToBags(item)
    local bags = self:Data().bags
    for i = 1, ns.BAG_SIZE do
        if not bags[i] then bags[i] = item; return i end
    end
    return nil
end

local function Power(it)
    if not it then return -1 end
    local n = #it.fx * 10 + (it.legendary and 100 or 0)
    for _, v in pairs(it.stats) do n = n + v end
    return n
end

-- where an item would go: target gear slot, plus slots that must be emptied
-- (a two-hander clears the off hand; an off-hand item clears a two-hander).
-- alt = true (Shift-click): the second ring/trinket, or the off hand for a one-hander.
function P:EquipTarget(item, alt)
    local g = self:Data().gear
    local t = item.slot
    local twoHanded = g.MAINHAND and g.MAINHAND.slot == "2H"
    if t == "2H" then return "MAINHAND", g.OFFHAND and { "OFFHAND" } or nil end
    if t == "SHIELD" then return "OFFHAND", twoHanded and { "MAINHAND" } or nil end
    if t == "1H" then
        if alt then return "OFFHAND", twoHanded and { "MAINHAND" } or nil end
        if not g.MAINHAND or twoHanded then return "MAINHAND" end
        if not g.OFFHAND then return "OFFHAND" end
        return "MAINHAND"
    end
    local slots = ns.ITEM_TYPES[t].slots
    if #slots == 1 then return slots[1] end
    local a, b = slots[1], slots[2]
    if alt then return b end
    if not g[a] then return a end
    if not g[b] then return b end
    return (Power(g[a]) <= Power(g[b])) and a or b      -- replace the weaker one
end

-- during a run only the items that dropped in this run can be put on
function P:FoundThisRun(item)
    local G = ns.Game
    return item ~= nil and item.runId ~= nil and G ~= nil and G.run ~= nil and G.board ~= nil
        and not G.over and item.runId == G.run.id
end

function P:CanEquipNow(item)
    return not self:Locked() or self:FoundThisRun(item)
end

-- items not yet looked at in the bags
function P:NewCount()
    local n = 0
    for i = 1, ns.BAG_SIZE do local it = self:Data().bags[i]; if it and it.new then n = n + 1 end end
    return n
end

function P:Equip(bagIndex, alt)
    local d = self:Data()
    local item = d.bags[bagIndex]
    if not item then return false end
    if not self:CanEquipNow(item) then return false, "During a run you can only equip items found in this run." end
    local target, clear = self:EquipTarget(item, alt)
    -- everything that comes off has to fit in the bags
    local off = {}
    if d.gear[target] then off[#off+1] = target end
    for _, k in ipairs(clear or {}) do if d.gear[k] and k ~= target then off[#off+1] = k end end
    local free = ns.BAG_SIZE - self:BagCount() + 1
    if #off > free then return false, "Your bags are full." end
    d.bags[bagIndex] = nil
    for _, k in ipairs(off) do
        self:AddToBags(d.gear[k])
        d.gear[k] = nil
    end
    d.gear[target] = item
    item.new = nil
    self.cache = nil
    if self:Locked() and ns.UI and ns.UI.GearChanged then ns.UI:GearChanged(item) end
    return true, target
end

function P:Unequip(slotId)
    if self:Locked() then return false, "Gear can't be taken off during a run." end
    local d = self:Data()
    local item = d.gear[slotId]
    if not item then return false end
    if not self:AddToBags(item) then return false, "Your bags are full." end
    d.gear[slotId] = nil
    self.cache = nil
    return true
end

-- selling keeps the item in the buyback list (last 12, newest first)
function P:Sell(bagIndex)
    local d = self:Data()
    local item = d.bags[bagIndex]
    if not item then return false end
    d.bags[bagIndex] = nil
    self:AddGold(item.sell)
    d.buyback = d.buyback or {}
    table.insert(d.buyback, 1, item)
    while #d.buyback > ns.BUYBACK_SIZE do table.remove(d.buyback) end
    return true, item
end

function P:Buyback() local d = self:Data(); d.buyback = d.buyback or {}; return d.buyback end

function P:BuyBack(i)
    local d = self:Data()
    local item = d.buyback and d.buyback[i]
    if not item then return false end
    if d.gold < item.sell then return false, "You don't have enough money." end
    if self:BagCount() >= ns.BAG_SIZE then return false, "Your bags are full." end
    d.gold = d.gold - item.sell
    table.remove(d.buyback, i)
    self:AddToBags(item)
    return true, item
end

---------------------------------------------------------------------------
-- Shop: 6 random items at your level; restocks after every run
---------------------------------------------------------------------------
P.SHOP_SIZE = 6

function P:Restock()
    local d = self:Data()
    local L = d.level
    d.shop = {}
    for i = 1, self.SHOP_SIZE do
        local r = random()
        local q = (r < 0.05) and 4 or ((r < 0.30) and 3 or 2)
        local item = self:NewItem(L + random(0, 2), q)
        item.price = item.sell * (q >= 4 and 8 or (q == 3 and 6 or 4))     -- better items cost more
        d.shop[i] = item
    end
end

function P:Shop()
    local d = self:Data()
    if not d.shop then self:Restock() end
    return d.shop
end

function P:RestockCost() local L = self:Level(); return L * L * 10 + 50 end

P.MAX_RESTOCKS = 3
function P:RestocksLeft() return self.MAX_RESTOCKS - (self:Data().restocks or 0) end

-- a new tide (or a new run) brings a new shop and new paid restocks
function P:NewTide()
    self:Restock()
    self:Data().restocks = 0
end

function P:PaidRestock()
    local d = self:Data()
    if self:RestocksLeft() <= 0 then return false, "No more restocks until the next tide." end
    local cost = self:RestockCost()
    if d.gold < cost then return false, "You don't have enough money." end
    d.gold = d.gold - cost
    d.restocks = (d.restocks or 0) + 1
    self:Restock()
    return true
end

function P:Buy(i)
    local d = self:Data()
    local item = d.shop[i]
    if not item then return false end
    if d.gold < item.price then return false, "You don't have enough money." end
    if self:BagCount() >= ns.BAG_SIZE then return false, "Your bags are full." end
    d.gold = d.gold - item.price
    item.price = nil
    self:AddToBags(item)
    d.shop[i] = false
    return true, item
end

---------------------------------------------------------------------------
-- Everything that changes the fight, added up (cached until something changes)
---------------------------------------------------------------------------
function P:Mods()
    if self.cache then return self.cache end
    local d = self:Data()
    local M = { stats = {}, legendary = {} }
    for _, k in ipairs(ns.STAT_ORDER) do M.stats[k] = 0 end
    local function add(k, v) M[k] = (M[k] or 0) + v end
    for id, rank in pairs(d.talents) do
        local t = ns.TALENT_BY_ID[id]
        if t then for k, v in pairs(t.fx) do add(k, v * rank) end end
    end
    for _, item in pairs(d.gear) do
        for k, v in pairs(item.stats) do if M.stats[k] then M.stats[k] = M.stats[k] + v end end
        for _, e in ipairs(item.fx) do
            if e.legendary then M.legendary[e.legendary] = true
            elseif e.key == "emeraldProc" then
                -- several procs: keep the best chance and add up the heals
                M.emeraldProcChance = max(M.emeraldProcChance or 0, e.v[1])
                add("emeraldProcHeal", e.v[2])
            else add(e.key, e.v) end
        end
    end
    local S, I = M.stats, ns.STAT_INFO
    local L = d.level
    add("hp", S.sta * I.sta.each)
    add("crit", S.crit * I.crit.each)
    add("combo", S.combo * I.combo.each)
    add("special", S.boom * I.boom.each)
    add("resto", S.resto * I.resto.each)
    add("gold", S.fortune * I.fortune.each)
    add("drop", S.fortune * 0.25)
    M.armor = S.armor
    M.armorRed = min(ns.ARMOR_CAP, M.armor / (M.armor + ns.ARMOR_K))
    M.weaponFlat = floor(S.dmg * (1 + (M.weapon or 0) / 100))
    M.level = L
    M.levelDmg = 3 * (L - 1)                         -- % more damage from level
    M.levelDef = 0.5 * (L - 1)                       -- % less damage taken from level
    M.maxHP = ns.PLAYER_HP + 10 * (L - 1) + (M.hp or 0)
    if M.legendary.crownTide then add("startHyper", 1) end
    if M.legendary.treadsTide then add("slow", 1) end
    self.cache = M
    return M
end

-- makrura get tougher with your level
function P:ScaleEnemy(e)
    local L = self:Level()
    e.hp = floor(e.hp * (1 + ns.ENEMY_HP_PER_LEVEL * (L - 1)))
    e.dmg = floor(e.dmg * (1 + ns.ENEMY_DMG_PER_LEVEL * (L - 1)) + 0.5)
    e.every = e.every + (self:Mods().slow or 0)
    return e
end
