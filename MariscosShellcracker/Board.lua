-- Marisco's Shellcracker - board engine (no UI code here)
-- Bejeweled 3 Classic rules on an 8x8 board.
-- grid[c][r]: c = column 1..8 (left to right), r = row 1..8 (top to bottom).
-- gem = { id = n, color = 1..7 (0 for hypercube), special = nil|"flame"|"star"|"hyper"|"nova" }

local _, ns = ...
ns = ns or {}

local Board = {}
Board.__index = Board
ns.Board = Board

local SIZE, COLORS = 8, 7
Board.SIZE, Board.COLORS = SIZE, COLORS

-- Points (all multiplied by the cascade level: 1st clear x1, 2nd x2, ...)
local MATCH_POINTS = { [3] = 50, [4] = 100, [5] = 150 }   -- 6+ = 50 per gem
local EXPLODED_GEM = 20                                   -- each gem destroyed by an explosion
local DETONATE_BONUS = { flame = 100, star = 200, hyper = 300, nova = 500 }

local floor = math.floor

local function key(c, r) return (c - 1) * SIZE + r end
local function unkey(k) return floor((k - 1) / SIZE) + 1, (k - 1) % SIZE + 1 end
Board.key, Board.unkey = key, unkey

local function inside(c, r) return c >= 1 and c <= SIZE and r >= 1 and r <= SIZE end

function Board.New(rng)
    local b = setmetatable({ grid = {}, nextId = 0, rng = rng or math.random }, Board)
    for c = 1, SIZE do b.grid[c] = {} end
    b:Fill()
    return b
end

function Board:Rand(n) return self.rng(n) end

function Board:NewGem(color, special)
    self.nextId = self.nextId + 1
    return { id = self.nextId, color = color, special = special }
end

function Board:Get(c, r) return inside(c, r) and self.grid[c][r] or nil end

-- color used for matching: hypercubes never match
local function mcolor(g) if g and g.special ~= "hyper" then return g.color end end

---------------------------------------------------------------------------
-- Fresh board: no matches, at least one move
---------------------------------------------------------------------------
function Board:Fill()
    for _ = 1, 200 do
        for c = 1, SIZE do
            for r = 1, SIZE do
                local color
                repeat
                    color = self:Rand(COLORS)
                    local bad = false
                    if c > 2 and mcolor(self.grid[c-1][r]) == color and mcolor(self.grid[c-2][r]) == color then bad = true end
                    if r > 2 and mcolor(self.grid[c][r-1]) == color and mcolor(self.grid[c][r-2]) == color then bad = true end
                until not bad
                self.grid[c][r] = self:NewGem(color)
            end
        end
        if self:FindHint() then return end
    end
end

---------------------------------------------------------------------------
-- Matching
---------------------------------------------------------------------------
function Board:FindRuns()
    local runs = {}
    local g = self.grid
    for r = 1, SIZE do                       -- horizontal
        local c = 1
        while c <= SIZE do
            local col = mcolor(g[c][r])
            local e = c
            if col then while e + 1 <= SIZE and mcolor(g[e+1][r]) == col do e = e + 1 end end
            if col and e - c + 1 >= 3 then
                local cells = {}
                for i = c, e do cells[#cells+1] = key(i, r) end
                runs[#runs+1] = { cells = cells, dir = "h", len = #cells, color = col }
            end
            c = e + 1
        end
    end
    for c = 1, SIZE do                       -- vertical
        local r = 1
        while r <= SIZE do
            local col = mcolor(g[c][r])
            local e = r
            if col then while e + 1 <= SIZE and mcolor(g[c][e+1]) == col do e = e + 1 end end
            if col and e - r + 1 >= 3 then
                local cells = {}
                for i = r, e do cells[#cells+1] = key(c, i) end
                runs[#runs+1] = { cells = cells, dir = "v", len = #cells, color = col }
            end
            r = e + 1
        end
    end
    return runs
end

-- Runs that share a gem (L, T and + shapes) become one group.
function Board:FindGroups()
    local runs = self:FindRuns()
    if #runs == 0 then return {} end
    local parent = {}
    for i = 1, #runs do parent[i] = i end
    local function find(i) while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end return i end
    local owner = {}
    for i, run in ipairs(runs) do
        for _, k in ipairs(run.cells) do
            if owner[k] then parent[find(i)] = find(owner[k]) else owner[k] = i end
        end
    end
    local byRoot, groups = {}, {}
    for i, run in ipairs(runs) do
        local root = find(i)
        local grp = byRoot[root]
        if not grp then
            grp = { set = {}, list = {}, color = run.color, maxLen = 0, h = false, v = false, dirOf = {} }
            byRoot[root] = grp
            groups[#groups+1] = grp
        end
        if run.len > grp.maxLen then grp.maxLen = run.len; grp.longest = run end
        grp[run.dir] = true
        for _, k in ipairs(run.cells) do
            if not grp.set[k] then grp.set[k] = true; grp.list[#grp.list+1] = k end
            grp.dirOf[k] = (grp.dirOf[k] or "") .. run.dir
        end
    end
    for _, grp in ipairs(groups) do
        for k, d in pairs(grp.dirOf) do
            if d:find("h") and d:find("v") then grp.cross = k end
        end
        -- Bejeweled 3: 6+ in a line = Supernova, 5 in a line = Hypercube,
        -- L/T/+ = Star gem, 4 in a line = Flame gem
        if grp.maxLen >= 6 then grp.special = "nova"
        elseif grp.maxLen == 5 then grp.special = "hyper"
        elseif grp.h and grp.v then grp.special = "star"
        elseif grp.maxLen == 4 then grp.special = "flame" end
        local n = #grp.list
        grp.points = MATCH_POINTS[n] or (50 * n)
    end
    return groups
end

---------------------------------------------------------------------------
-- Explosions
---------------------------------------------------------------------------
local function blastCells(kind, c, r, out)
    if kind == "flame" then
        for dc = -1, 1 do for dr = -1, 1 do if inside(c+dc, r+dr) then out[#out+1] = key(c+dc, r+dr) end end end
    elseif kind == "star" then
        for i = 1, SIZE do out[#out+1] = key(i, r); out[#out+1] = key(c, i) end
    elseif kind == "nova" then
        for d = -1, 1 do
            for i = 1, SIZE do
                if inside(1, r + d) then out[#out+1] = key(i, r + d) end
                if inside(c + d, 1) then out[#out+1] = key(c + d, i) end
            end
        end
    end
end

-- Starting from the keys in `queue` (already in `clear`), detonate every special gem
-- found, spreading the destruction. Fills step.effects and returns exploded-gem count.
function Board:Chain(step, clear, protected, queue, hyperColor)
    local exploded = 0
    local qi = 1
    while qi <= #queue do
        local k = queue[qi]; qi = qi + 1
        local c, r = unkey(k)
        local gem = self.grid[c][r]
        if gem and gem.special and not step.detonated[gem.id] then
            step.detonated[gem.id] = true
            local kind = gem.special
            step.bonus = step.bonus + (DETONATE_BONUS[kind] or 0)
            local cells = {}
            local eff = { kind = kind, c = c, r = r, color = gem.color }
            if kind == "hyper" then
                -- a hypercube caught in a blast wipes out a random color
                local color = hyperColor or self:Rand(COLORS)
                hyperColor = nil
                eff.color = color
                for cc = 1, SIZE do for rr = 1, SIZE do
                    local o = self.grid[cc][rr]
                    if o and o.color == color and o.special ~= "hyper" then cells[#cells+1] = key(cc, rr) end
                end end
                eff.cells = cells
            else
                blastCells(kind, c, r, cells)
            end
            step.effects[#step.effects+1] = eff
            for _, bk in ipairs(cells) do
                local bc, br = unkey(bk)
                if not clear[bk] and not protected[bk] and self.grid[bc][br] then
                    clear[bk] = true
                    exploded = exploded + 1
                    queue[#queue+1] = bk
                end
            end
        end
    end
    return exploded
end

local function newStep(cascade)
    return { cascade = cascade, cleared = {}, created = {}, transforms = {}, effects = {},
             groups = {}, detonated = {}, bonus = 0, score = 0, plainScore = 0,
             colorCount = {}, matchCount = 0 }
end

-- Remove the gems in `clear` and total up the score.
function Board:Commit(step, clear, groupPoints, exploded)
    for k in pairs(clear) do
        local c, r = unkey(k)
        local gem = self.grid[c][r]
        if gem then
            step.cleared[#step.cleared+1] = { id = gem.id, c = c, r = r, color = gem.color, special = gem.special }
            if gem.special ~= "hyper" then step.colorCount[gem.color] = (step.colorCount[gem.color] or 0) + 1 end
            self.grid[c][r] = nil
        end
    end
    for _, cr in ipairs(step.created) do
        local gem = self.grid[cr.c][cr.r]
        gem.special = cr.special
        if cr.special == "hyper" then gem.color = 0 end
    end
    local m = step.cascade
    step.score = (groupPoints + exploded * EXPLODED_GEM + step.bonus) * m
    step.explodeScore = (exploded * EXPLODED_GEM + step.bonus) * m      -- the part made by explosions
    step.plainScore = step.plainScore * m
    return step
end

---------------------------------------------------------------------------
-- One cascade step: clear all current matches. Returns nil if nothing matches.
-- prefer: optional { [key]=true } cells the player just moved (specials form there)
---------------------------------------------------------------------------
function Board:Step(cascade, prefer)
    local groups = self:FindGroups()
    if #groups == 0 then return nil end
    local step = newStep(cascade or 1)
    local clear, protected, queue = {}, {}, {}
    local groupPoints = 0
    for _, grp in ipairs(groups) do
        groupPoints = groupPoints + grp.points
        if not grp.special and #grp.list == 3 then step.plainScore = step.plainScore + grp.points end
        local origin
        if grp.special then
            if prefer then for _, k in ipairs(grp.list) do if prefer[k] then origin = k break end end end
            if not origin and grp.special == "star" then origin = grp.cross end
            if not origin then origin = grp.longest.cells[math.min(2, #grp.longest.cells)] end
            -- don't put the new special on top of an existing one if we can avoid it
            local oc, orr = unkey(origin)
            if self.grid[oc][orr].special then
                for _, k in ipairs(grp.list) do
                    local c, r = unkey(k)
                    if not self.grid[c][r].special and not protected[k] then origin = k break end
                end
            end
            oc, orr = unkey(origin)
            local ogem = self.grid[oc][orr]
            if not ogem.special and not protected[origin] then
                protected[origin] = true
                step.created[#step.created+1] = { id = ogem.id, c = oc, r = orr, special = grp.special, color = ogem.color }
            else
                origin = nil
            end
        end
        step.groups[#step.groups+1] = { list = grp.list, color = grp.color, special = grp.special, points = grp.points * step.cascade }
        for _, k in ipairs(grp.list) do
            if not protected[k] and not clear[k] then clear[k] = true; queue[#queue+1] = k end
        end
    end
    step.matchCount = #groups
    local exploded = self:Chain(step, clear, protected, queue)
    return self:Commit(step, clear, groupPoints, exploded)
end

---------------------------------------------------------------------------
-- Gravity: gems fall, new gems drop in from above.
-- Returns { moves = {{id,c,from,to}}, spawns = {{gem,c,from,to}} } (from < 1 = above the board)
---------------------------------------------------------------------------
function Board:Gravity()
    local out = { moves = {}, spawns = {} }
    for c = 1, SIZE do
        local col = self.grid[c]
        local w = SIZE
        for r = SIZE, 1, -1 do
            local gem = col[r]
            if gem then
                if r ~= w then
                    col[w] = gem; col[r] = nil
                    out.moves[#out.moves+1] = { id = gem.id, c = c, from = r, to = w }
                end
                w = w - 1
            end
        end
        for r = w, 1, -1 do
            local gem = self:NewGem(self:Rand(COLORS))
            col[r] = gem
            out.spawns[#out.spawns+1] = { gem = gem, c = c, from = r - w, to = r }
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Moves
---------------------------------------------------------------------------
local function adjacent(c1, r1, c2, r2)
    return (c1 == c2 and math.abs(r1 - r2) == 1) or (r1 == r2 and math.abs(c1 - c2) == 1)
end
Board.Adjacent = adjacent

function Board:RawSwap(c1, r1, c2, r2)
    local g = self.grid
    g[c1][r1], g[c2][r2] = g[c2][r2], g[c1][r1]
end

-- quick check: does the gem at c,r sit in a line of 3?
function Board:MatchAt(c, r)
    local col = mcolor(self.grid[c][r])
    if not col then return false end
    local n = 1
    local i = c - 1 while i >= 1 and mcolor(self.grid[i][r]) == col do n = n + 1; i = i - 1 end
    i = c + 1 while i <= SIZE and mcolor(self.grid[i][r]) == col do n = n + 1; i = i + 1 end
    if n >= 3 then return true end
    n = 1
    i = r - 1 while i >= 1 and mcolor(self.grid[c][i]) == col do n = n + 1; i = i - 1 end
    i = r + 1 while i <= SIZE and mcolor(self.grid[c][i]) == col do n = n + 1; i = i + 1 end
    return n >= 3
end

-- Try a player move.
-- returns "invalid" | "match" | "hyper", and for "hyper" the finished first step.
function Board:TrySwap(c1, r1, c2, r2)
    if not (inside(c1, r1) and inside(c2, r2) and adjacent(c1, r1, c2, r2)) then return "invalid" end
    local a, b = self.grid[c1][r1], self.grid[c2][r2]
    if not a or not b then return "invalid" end
    if a.special == "hyper" or b.special == "hyper" then
        return "hyper", self:HyperSwap(c1, r1, c2, r2)
    end
    self:RawSwap(c1, r1, c2, r2)
    if self:MatchAt(c1, r1) or self:MatchAt(c2, r2) then return "match" end
    self:RawSwap(c1, r1, c2, r2)
    return "invalid"
end

-- Hypercube swapped with a neighbour (c1,r1 or c2,r2 holds the cube)
--   cube + normal gem   : every gem of that color is destroyed
--   cube + flame/star/nova : every gem of that color becomes that special and detonates
--   cube + cube         : the whole board is destroyed
function Board:HyperSwap(c1, r1, c2, r2)
    local a = self.grid[c1][r1]
    local hc, hr, oc, or_ = c1, r1, c2, r2
    if a.special ~= "hyper" then hc, hr, oc, or_ = c2, r2, c1, r1 end
    local other = self.grid[oc][or_]
    local step = newStep(1)
    step.hyper = { c = hc, r = hr, tc = oc, tr = or_ }
    local clear, protected, queue = {}, {}, {}
    local exploded = 0
    local cube = self.grid[hc][hr]
    step.detonated[cube.id] = true
    clear[key(hc, hr)] = true
    if other.special == "hyper" then
        step.detonated[other.id] = true
        step.bonus = DETONATE_BONUS.hyper * 3
        local cells = {}
        for c = 1, SIZE do for r = 1, SIZE do
            local k = key(c, r)
            cells[#cells+1] = k
            if not clear[k] then clear[k] = true; queue[#queue+1] = k; exploded = exploded + 1 end
        end end
        step.effects[#step.effects+1] = { kind = "board", c = oc, r = or_, color = 0, cells = cells }
        -- the other cube is spent too: don't let it detonate
        for i = #queue, 1, -1 do if queue[i] == key(oc, or_) then table.remove(queue, i) end end
        exploded = exploded + self:Chain(step, clear, protected, queue)
    else
        local color, kind = other.color, other.special
        step.bonus = DETONATE_BONUS.hyper
        local cells = {}
        for c = 1, SIZE do for r = 1, SIZE do
            local g = self.grid[c][r]
            if g and g.color == color and g.special ~= "hyper" then
                local k = key(c, r)
                cells[#cells+1] = k
                if kind and kind ~= "hyper" and not g.special then
                    g.special = kind
                    step.transforms[#step.transforms+1] = { id = g.id, c = c, r = r, special = kind }
                end
                clear[k] = true; queue[#queue+1] = k; exploded = exploded + 1
            end
        end end
        step.effects[#step.effects+1] = { kind = "hyper", c = hc, r = hr, color = color, cells = cells }
        exploded = exploded + self:Chain(step, clear, protected, queue)
    end
    step.matchCount = 1
    return self:Commit(step, clear, 0, exploded)
end

function Board:CountSpecials()
    local n = 0
    for c = 1, SIZE do for r = 1, SIZE do if self.grid[c][r] and self.grid[c][r].special then n = n + 1 end end end
    return n
end

-- Put special gems on a fresh board (talents). Specials keep their color, a Hypercube has none,
-- so this never creates a match.
function Board:Seed(flames, hypers)
    local cells = {}
    for c = 1, SIZE do for r = 1, SIZE do cells[#cells+1] = { c, r } end end
    for i = #cells, 2, -1 do local j = self:Rand(i); cells[i], cells[j] = cells[j], cells[i] end
    local i = 0
    for _ = 1, hypers or 0 do
        i = i + 1
        local g = self.grid[cells[i][1]][cells[i][2]]
        g.special, g.color = "hyper", 0
    end
    for _ = 1, flames or 0 do
        i = i + 1
        if cells[i] then self.grid[cells[i][1]][cells[i][2]].special = "flame" end
    end
    if not self:FindHint() then self:Shuffle() end
end

-- First legal move found (or nil). Returns c1, r1, c2, r2.
function Board:FindHint()
    local g = self.grid
    for c = 1, SIZE do for r = 1, SIZE do
        if g[c][r] and g[c][r].special == "hyper" then
            local nc, nr = c + 1, r
            if not inside(nc, nr) then nc, nr = c - 1, r end
            return c, r, nc, nr
        end
    end end
    local found
    for c = 1, SIZE do
        for r = 1, SIZE do
            for _, d in ipairs({ { 1, 0 }, { 0, 1 } }) do
                local c2, r2 = c + d[1], r + d[2]
                if inside(c2, r2) then
                    self:RawSwap(c, r, c2, r2)
                    local ok = self:MatchAt(c, r) or self:MatchAt(c2, r2)
                    self:RawSwap(c, r, c2, r2)
                    if ok then found = { c, r, c2, r2 } break end
                end
            end
            if found then break end
        end
        if found then break end
    end
    if found then return found[1], found[2], found[3], found[4] end
end

-- The gem the player should move for the hint: the one that lands in a match.
-- Returns c, r (gem to move) and tc, tr (where it goes).
function Board:HintMover()
    local c1, r1, c2, r2 = self:FindHint()
    if not c1 then return end
    if self.grid[c1][r1].special == "hyper" then return c1, r1, c2, r2 end
    if self.grid[c2][r2].special == "hyper" then return c2, r2, c1, r1 end
    self:RawSwap(c1, r1, c2, r2)
    local firstLands = self:MatchAt(c2, r2)     -- gem from (c1,r1) now sits at (c2,r2)
    self:RawSwap(c1, r1, c2, r2)
    if firstLands then return c1, r1, c2, r2 end
    return c2, r2, c1, r1
end

-- No moves left: mix the gems (specials included) into a playable board.
-- Returns { {id, c, r} } with each gem's new spot.
function Board:Shuffle()
    local gems = {}
    for c = 1, SIZE do for r = 1, SIZE do gems[#gems+1] = self.grid[c][r] end end
    for _ = 1, 300 do
        for i = #gems, 2, -1 do
            local j = self:Rand(i)
            gems[i], gems[j] = gems[j], gems[i]
        end
        local i = 0
        for c = 1, SIZE do for r = 1, SIZE do i = i + 1; self.grid[c][r] = gems[i] end end
        if #self:FindRuns() == 0 and self:FindHint() then break end
    end
    -- give up on perfect: recolor until stable (very unlikely to be needed)
    if #self:FindRuns() > 0 or not self:FindHint() then
        for _, gem in ipairs(gems) do gem.special = nil end
        self:Fill()
    end
    local out = {}
    for c = 1, SIZE do for r = 1, SIZE do out[#out+1] = { id = self.grid[c][r].id, gem = self.grid[c][r], c = c, r = r } end end
    return out
end

---------------------------------------------------------------------------
-- Save / load (2 characters per gem: color digit + special letter)
---------------------------------------------------------------------------
local SPECIAL_CODE = { flame = "f", star = "s", hyper = "h", nova = "n" }
local CODE_SPECIAL = { f = "flame", s = "star", h = "hyper", n = "nova" }

function Board:Serialize()
    local t = {}
    for c = 1, SIZE do for r = 1, SIZE do
        local g = self.grid[c][r]
        t[#t+1] = tostring(g.color) .. (SPECIAL_CODE[g.special] or "-")
    end end
    return table.concat(t)
end

function Board.Load(str, rng)
    if type(str) ~= "string" or #str ~= SIZE * SIZE * 2 then return nil end
    local b = setmetatable({ grid = {}, nextId = 0, rng = rng or math.random }, Board)
    local i = 1
    for c = 1, SIZE do
        b.grid[c] = {}
        for r = 1, SIZE do
            local color = tonumber(str:sub(i, i))
            local sp = CODE_SPECIAL[str:sub(i + 1, i + 1)]
            if not color or color < 0 or color > COLORS then return nil end
            b.grid[c][r] = b:NewGem(color, sp)
            i = i + 2
        end
    end
    if #b:FindRuns() > 0 then return nil end
    if not b:FindHint() then b:Shuffle() end
    return b
end

return Board
