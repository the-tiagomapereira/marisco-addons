local _, ns = ...

-- WoW Forever uses the modern auction house (C_AuctionHouse).
local A = CreateFrame("Frame")
ns.Auction = A
local AH = C_AuctionHouse
local CHUNK = 100  -- SearchForItemKeys accepts up to 100 items per request
local COOLDOWN = 5 -- seconds between scans, so the button can't spam the AH

function A:CooldownLeft()
    if not self.cooldownUntil then return 0 end
    return math.max(0, math.ceil(self.cooldownUntil - GetTime()))
end

local function Sorts()
    return { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
end

local function Ready()
    if AH.IsThrottledMessageSystemReady then return AH.IsThrottledMessageSystemReady() end
    return true
end

---------------------------------------------------------------------------
-- Recording prices
---------------------------------------------------------------------------
local function Known(k, id)
    return ns.known and ((k and ns.known[k]) or (id and ns.known["id:" .. id]))
end

function ns:RecordPrice(name, id, unit)
    if not unit or unit <= 0 then return end
    local k = ns.Key(name)
    if not Known(k, id) then return end
    local entry = { price = unit, t = time() }
    if id then ns.prices["id:" .. id] = entry end
    if k then ns.prices[k] = entry end
    if id and k then
        local e = ns:FindInList(name)
        if e and not e.id then e.id = id end
    end
    if A.scanning and id then A.seen[id] = true end
end

local function MarkNone(name, id)
    local entry = { none = true, t = time() }
    if id then ns.prices["id:" .. id] = entry end
    local k = ns.Key(name)
    if k then ns.prices[k] = entry end
end

---------------------------------------------------------------------------
-- Reading results (these also catch your own manual AH searches)
---------------------------------------------------------------------------
local function ReadBrowse()
    if not AH.GetBrowseResults then return end
    for _, r in ipairs(AH.GetBrowseResults() or {}) do
        local id = r.itemKey and r.itemKey.itemID
        if id and r.minPrice and r.minPrice > 0 and (r.totalQuantity or 1) > 0 then
            ns:RecordPrice(ns.GetItemInfo(id), id, r.minPrice)
        end
    end
    ns:RequestRefresh()
end

local function ReadCommodity(itemID)
    local best
    local n = AH.GetNumCommoditySearchResults(itemID) or 0
    for i = 1, n do
        local r = AH.GetCommoditySearchResultInfo(itemID, i)
        if r and r.unitPrice and r.unitPrice > 0 and (not best or r.unitPrice < best) then best = r.unitPrice end
    end
    if best then ns:RecordPrice(ns.GetItemInfo(itemID), itemID, best) end
    ns:RequestRefresh()
    return n
end

local function ReadItemSearch(itemKey)
    local best
    local n = AH.GetNumItemSearchResults(itemKey) or 0
    for i = 1, n do
        local r = AH.GetItemSearchResultInfo(itemKey, i)
        if r and r.buyoutAmount and r.buyoutAmount > 0 and (not best or r.buyoutAmount < best) then best = r.buyoutAmount end
    end
    local itemID = itemKey and itemKey.itemID
    if best and itemID then ns:RecordPrice(ns.GetItemInfo(itemID), itemID, best) end
    ns:RequestRefresh()
    return n, itemID
end

local function ReadReplicate()
    if not AH.GetNumReplicateItems then return end
    local mins, names = {}, {}
    for i = 0, (AH.GetNumReplicateItems() or 0) - 1 do
        local name, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = AH.GetReplicateItemInfo(i)
        if itemID and count and count > 0 and buyout and buyout > 0 then
            local unit = math.floor(buyout / count)
            if not mins[itemID] or unit < mins[itemID] then mins[itemID] = unit; names[itemID] = name end
        end
    end
    for id, unit in pairs(mins) do ns:RecordPrice(names[id], id, unit) end
    ns:RequestRefresh()
end

---------------------------------------------------------------------------
-- Scanner
---------------------------------------------------------------------------
local function ResolveId(e)
    if e.id then return e.id end
    local getInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local ok, id = pcall(getInstant, e.name)
    if ok and id then e.id = id; return id end
end

function A:Current()
    return self.scanning and self.ids and self.ids[self.pos]
end

function A:StartScan(onlyEntry)
    if not ns.ahOpen then ns.Print("Open the auction house first.") return end
    if not AH then ns.Print("No modern auction house API found on this client.") return end
    if self.scanning then return end
    if self:CooldownLeft() > 0 then
        ns.Print("Please wait " .. self:CooldownLeft() .. "s before scanning again.")
        return
    end

    local source = onlyEntry and { onlyEntry } or ns.db.list
    local ids, entries, skipped = {}, {}, 0
    for _, e in ipairs(source) do
        local id = ResolveId(e)
        if id then
            if not entries[id] then entries[id] = e; ids[#ids + 1] = id end
            ns.known["id:" .. id] = true
        else
            skipped = skipped + 1
        end
    end
    if skipped > 0 then
        ns.Print(skipped .. " item(s) have no item ID yet and were skipped. Open your profession window or drag the item onto the list once.")
    end
    if #ids == 0 then
        if #source == 0 then ns.Print("Your shopping list is empty.") end
        return
    end

    self.ids, self.entries, self.pos, self.seen = ids, entries, 1, {}
    self.fullScan = not onlyEntry
    self.batch = AH.SearchForItemKeys ~= nil
    self.scanning = true
    self.cooldownUntil = GetTime() + COOLDOWN
    self:SendWhenReady()
    ns:RequestRefresh()
end

function A:StopScan()
    self.scanning, self.awaiting = false, false
    self:SetScript("OnUpdate", nil)
    ns:RequestRefresh()
end

function A:Finish()
    local priced, none = 0, 0
    for _, id in ipairs(self.ids) do
        local p = ns.prices["id:" .. id]
        if p and p.price then priced = priced + 1 elseif p and p.none then none = none + 1 end
    end
    if self.fullScan then
        ns.db.lastScan[ns.realmKey] = time()
        ns.Print(string.format("Scan finished: %d priced, %d not listed.", priced, none))
    end
    self:StopScan()
end

function A:SendWhenReady()
    self.awaiting = false
    self.wait = 0
    self:SetScript("OnUpdate", A.OnUpdateSend)
end

local function ArmTimeout(self, seconds)
    self.token = (self.token or 0) + 1
    local token = self.token
    C_Timer.After(seconds, function()
        if self.scanning and self.awaiting and self.token == token then
            self:OnTimeout()
        end
    end)
end

function A.OnUpdateSend(self, elapsed)
    if not self.scanning then self:SetScript("OnUpdate", nil) return end
    self.wait = self.wait + elapsed
    if self.wait < 0.3 or not Ready() then return end
    self:SetScript("OnUpdate", nil)
    self.awaiting, self.gotEvent = true, false

    if self.batch then
        local keys = {}
        local last = math.min(#self.ids, self.pos + CHUNK - 1)
        for i = self.pos, last do keys[#keys + 1] = AH.MakeItemKey(self.ids[i]) end
        self.chunkEnd = last
        ArmTimeout(self, 10)
        AH.SearchForItemKeys(keys, Sorts())
    else
        ArmTimeout(self, 8)
        AH.SendSearchQuery(AH.MakeItemKey(self.ids[self.pos]), Sorts(), false)
    end
end

-- Batch mode: everything in this chunk that didn't come back isn't listed.
function A:FinishChunk(timedOut)
    self.debouncePending = false
    if not (self.scanning and self.awaiting) then return end
    self.awaiting = false
    if not timedOut or self.gotEvent then
        for i = self.pos, self.chunkEnd do
            local id = self.ids[i]
            if not self.seen[id] then MarkNone(self.entries[id].name, id) end
        end
    else
        ns.Print("The auction house didn't answer. Try Scan list again in a moment.")
    end
    self.pos = self.chunkEnd + 1
    if self.pos > #self.ids then self:Finish() else self:SendWhenReady() end
end

function A:NextSingle()
    self.awaiting = false
    self.pos = self.pos + 1
    if self.pos > #self.ids then self:Finish() else self:SendWhenReady() end
    ns:RequestRefresh()
end

function A:OnTimeout()
    if self.batch then self:FinishChunk(true) else self:NextSingle() end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
A:RegisterEvent("AUCTION_HOUSE_SHOW")
A:RegisterEvent("AUCTION_HOUSE_CLOSED")
for _, e in ipairs({ "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
                     "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED",
                     "REPLICATE_ITEM_LIST_UPDATE" }) do
    ns.SafeRegister(A, e)
end

A:SetScript("OnEvent", function(self, event, ...)
    if event == "AUCTION_HOUSE_SHOW" then
        ns.ahOpen = true
        if ns.UI then ns.UI:OnAuctionHouseShown() end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        ns.ahOpen = false
        self:StopScan()
        if ns.UI then ns.UI:OnAuctionHouseClosed() end
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        ReadBrowse()
        if self.scanning and self.batch and self.awaiting then
            self.gotEvent = true
            if not self.debouncePending then
                self.debouncePending = true
                C_Timer.After(0.6, function() A:FinishChunk(false) end)
            end
        end
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        local itemID = ...
        local n = ReadCommodity(itemID)
        if self.scanning and not self.batch and self.awaiting and self:Current() == itemID then
            if n == 0 then MarkNone(self.entries[itemID].name, itemID) end
            self:NextSingle()
        end
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        local itemKey = ...
        local n, itemID = ReadItemSearch(itemKey)
        if self.scanning and not self.batch and self.awaiting and self:Current() == itemID then
            if n == 0 then MarkNone(self.entries[itemID].name, itemID) end
            self:NextSingle()
        end
    elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
        ReadReplicate()
    end
end)
