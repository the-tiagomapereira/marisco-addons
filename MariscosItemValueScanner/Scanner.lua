-- Marisco's Item Value Scanner - Auction House scanner
--
-- WoW addons run sandboxed inside the client and cannot make web requests,
-- so the "API" queried here is the game's own Auction House API.
--
-- Forever (1.60.x) uses the MODERN Auction House API (C_AuctionHouse); the old
-- classic events such as AUCTION_ITEM_LIST_UPDATE do not exist there.
--
-- Scan modes (picked automatically from what the client exposes):
--   SAFE (default)
--     modern : blank browse search + "load more" until the list is complete.
--              Returns the lowest price and total quantity per item. No 15-minute
--              server limit and only one small batch per event.
--     classic: page-by-page QueryAuctionItems (kept for older clients).
--   FAST (/mivs fast)
--     modern : C_AuctionHouse.ReplicateItems - every single auction in one go.
--              The server allows it about once every 15 minutes and silently
--              ignores extra requests; heavy on the client and on other addons.
--     classic: QueryAuctionItems getAll.
--
-- Collision guard: while we scan, an Auction House query that is NOT ours stops
-- our scan and keeps what was gathered, instead of mixing results.

local _, ns = ...

local Scanner = CreateFrame("Frame")
ns.Scanner = Scanner

Scanner.state = "idle"   -- idle | waiting | processing | paging | browsing
local CHUNK_PER_FRAME = 200
local PAGE_SIZE       = NUM_AUCTION_ITEMS_PER_PAGE or 50
local WAIT_TIMEOUT    = 60     -- seconds to wait for the server to answer
local PAGE_SETTLE     = 0.3
local PAGE_MAX_WAIT   = 3

local ourCall = false          -- true only while WE are calling a query API

------------------------------------------------------------------------
-- Safe event helpers: registering an event the client doesn't know is an error.
------------------------------------------------------------------------
function Scanner:SafeRegister(event)
    local ok = pcall(self.RegisterEvent, self, event)
    return ok
end

function Scanner:SafeUnregister(event)
    if self:IsEventRegistered(event) then pcall(self.UnregisterEvent, self, event) end
end

local ALL_EVENTS = {
    "REPLICATE_ITEM_LIST_UPDATE", "AUCTION_ITEM_LIST_UPDATE",
    "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
    "AUCTION_HOUSE_BROWSE_FAILURE",
}

------------------------------------------------------------------------
-- API detection
------------------------------------------------------------------------
local AH = C_AuctionHouse

local function HasBrowseAPI()
    return AH and AH.SendBrowseQuery and AH.GetBrowseResults
        and AH.RequestMoreBrowseResults and AH.HasFullBrowseResults
end

local function HasReplicateAPI()
    return AH and AH.ReplicateItems and AH.GetNumReplicateItems and AH.GetReplicateItemInfo
end

local function HasLegacyAPI()
    return QueryAuctionItems and CanSendAuctionQuery and GetAuctionItemInfo and GetNumAuctionItems
end

local function ThrottleReady()
    if AH and AH.IsThrottledMessageSystemReady then return AH.IsThrottledMessageSystemReady() end
    return true
end

------------------------------------------------------------------------
-- State helpers
------------------------------------------------------------------------
function Scanner:IsScanning()
    return self.state ~= "idle"
end

function Scanner:GetProgress()
    return self.processed or 0, self.total or 0
end

function Scanner:GetProgressText()
    if self.mode == "browse" then
        if (self.processed or 0) == 0 then return "Waiting for server..." end
        return string.format("%d items found...", self.processed)
    end
    local done, total = self:GetProgress()
    if total > 0 then
        return string.format("%d / %d (%d%%)", done, total, math.floor(done / total * 100))
    end
    return "Waiting for server..."
end

function Scanner:GetModeName()
    return (self.mode == "browse" or self.mode == "paged") and "safe" or "fast"
end

function Scanner:SilenceBrowse(silence)
    local browse = _G.AuctionFrameBrowse
    if not browse then return end
    if silence then
        pcall(browse.UnregisterEvent, browse, "AUCTION_ITEM_LIST_UPDATE")
    else
        pcall(browse.RegisterEvent, browse, "AUCTION_ITEM_LIST_UPDATE")
    end
end

-- perUnit is already a per-unit price; auctions may be nil (browse mode doesn't know it).
function Scanner:RecordUnit(itemID, perUnit, qty, auctions)
    if not itemID or not perUnit or perUnit <= 0 then return end
    qty = qty or 0
    local r = self.results[itemID]
    if r then
        if perUnit < r.min then r.min = perUnit end
        r.qty = r.qty + qty
        if auctions and r.auctions then r.auctions = r.auctions + auctions end
    else
        self.results[itemID] = { min = perUnit, qty = qty, auctions = auctions }
    end
end

function Scanner:Record(count, buyout, itemID)
    if not count or count <= 0 or not buyout or buyout <= 0 then return end
    self:RecordUnit(itemID, math.floor(buyout / count), count, 1)
end

------------------------------------------------------------------------
-- Collision guard
------------------------------------------------------------------------
local function OnAnyQuery()
    if ourCall or not Scanner:IsScanning() then return end
    C_Timer.After(0, function()
        if Scanner:IsScanning() then
            Scanner:Abort("another addon (or a manual search) sent its own Auction House query - " ..
                "wait for it to finish, then scan again")
        end
    end)
end

function Scanner:InstallGuards()
    if self.guardsInstalled then return end
    self.guardsInstalled = true
    if QueryAuctionItems then hooksecurefunc("QueryAuctionItems", OnAnyQuery) end
    if AH then
        for _, fn in ipairs({ "ReplicateItems", "SendBrowseQuery", "SendSearchQuery", "SendSellSearchQuery" }) do
            if AH[fn] then hooksecurefunc(AH, fn, OnAnyQuery) end
        end
    end
end

local function SendQuery(fn, ...)
    ourCall = true
    local ok, err = pcall(fn, ...)
    ourCall = false
    return ok, err
end

------------------------------------------------------------------------
-- Start / stop
------------------------------------------------------------------------
function Scanner:Reset()
    self.results, self.processed, self.total = {}, 0, 0
    self.index, self.page, self.awaitingPage = nil, 0, false
    self.pageUpdatedAt, self.pageSentAt = nil, nil
    self.browseSent, self.morePending, self.pendingAdded = false, false, nil
    self.firstBatch, self.lastActivity = false, GetTime()
    self.token = (self.token or 0) + 1
end

function Scanner:Start()
    if self:IsScanning() then return false, "a scan is already running." end
    if not ns.ahOpen then return false, "open the Auction House first." end
    self:InstallGuards()
    self:Reset()
    self.startedAt = time()
    local fast = ns.db.fastScan

    if fast and HasReplicateAPI() then
        self.mode, self.state = "replicate", "waiting"
        self:SafeRegister("REPLICATE_ITEM_LIST_UPDATE")
        local ok, err = SendQuery(AH.ReplicateItems)
        if not ok then self:Stop(); return false, "the client refused the query (" .. tostring(err) .. ")." end
        self:ArmTimeout("the server ignored the fast scan request - it is limited to about once " ..
            "every 15 minutes. Switch back to the safe scan with /mivs fast")

    elseif fast and HasLegacyAPI() and select(2, CanSendAuctionQuery()) then
        self.mode, self.state = "getall", "waiting"
        self:SilenceBrowse(true)
        self:SafeRegister("AUCTION_ITEM_LIST_UPDATE")
        local ok, err = SendQuery(QueryAuctionItems, "", nil, nil, 0, false, nil, true, false, nil)
        if not ok then self:Stop(); return false, "the client refused the query (" .. tostring(err) .. ")." end
        self:ArmTimeout("the server did not answer the fast scan (about once every 15 minutes)")

    elseif HasBrowseAPI() then
        if fast then ns:Print("Fast scan isn't available right now - using the safe scan.") end
        self.mode, self.state = "browse", "browsing"
        self:SafeRegister("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
        self:SafeRegister("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
        self:SafeRegister("AUCTION_HOUSE_BROWSE_FAILURE")

    elseif HasLegacyAPI() then
        if fast then ns:Print("Fast scan is on server cooldown - using the safe scan.") end
        self.mode, self.state = "paged", "paging"
        self:SilenceBrowse(true)
        self:SafeRegister("AUCTION_ITEM_LIST_UPDATE")

    else
        return false, "no Auction House scan API found on this client."
    end

    self:SetScript("OnUpdate", self.OnUpdate)
    return true
end

function Scanner:ArmTimeout(reason)
    local token = self.token
    C_Timer.After(WAIT_TIMEOUT, function()
        if self.token == token and self.state == "waiting" then self:Abort(reason) end
    end)
end

function Scanner:Stop()
    for _, e in ipairs(ALL_EVENTS) do self:SafeUnregister(e) end
    self:SetScript("OnUpdate", nil)
    if self.mode == "getall" or self.mode == "paged" then self:SilenceBrowse(false) end
    self.state = "idle"
    self.token = (self.token or 0) + 1
end

function Scanner:Abort(reason)
    local hadData = next(self.results or {}) ~= nil
    self:Stop()
    if hadData then
        self:Commit(false)
        ns:Print("Scan stopped: " .. reason .. ". Saved partial results.")
    else
        ns:Print("Scan stopped: " .. reason .. ".")
    end
    if ns.OnScanStateChanged then ns:OnScanStateChanged() end
end

function Scanner:Commit(complete)
    local now = time()
    local prices = ns.data.prices
    local n = 0
    for itemID, r in pairs(self.results) do
        prices[itemID] = { min = r.min, qty = r.qty, auctions = r.auctions, t = now }
        n = n + 1
    end
    ns.data.lastScan = now
    ns.data.lastScanItems = n
    ns.data.lastScanComplete = complete
    self.results = {}
    return n
end

function Scanner:Finish()
    local total, mode = self.total or 0, self:GetModeName()
    self:Stop()
    local n = self:Commit(true)
    if self.mode == "browse" then
        ns:Print(string.format("Scan complete (%s): %d unique items (%ds).",
            mode, n, time() - (self.startedAt or time())))
    else
        ns:Print(string.format("Scan complete (%s): %d auctions, %d unique items (%ds).",
            mode, total, n, time() - (self.startedAt or time())))
    end
    if ns.OnScanStateChanged then ns:OnScanStateChanged() end
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
Scanner:SetScript("OnEvent", function(self, event, arg1)
    self.lastActivity = GetTime()
    if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" and self.mode == "browse" then
        self.firstBatch = true            -- read the full list once in OnUpdate
        self.morePending = false
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" and self.mode == "browse" then
        self.pendingAdded = self.pendingAdded or {}
        self.pendingAdded[#self.pendingAdded + 1] = arg1
        self.morePending = false
    elseif event == "AUCTION_HOUSE_BROWSE_FAILURE" and self.mode == "browse" then
        C_Timer.After(0, function() if self:IsScanning() then self:Abort("the server rejected the search") end end)
    elseif event == "REPLICATE_ITEM_LIST_UPDATE" and self.state == "waiting" then
        self:SafeUnregister("REPLICATE_ITEM_LIST_UPDATE")
        self.total = AH.GetNumReplicateItems() or 0
        self.index, self.state = 0, "processing"           -- replicate index is 0-based
    elseif event == "AUCTION_ITEM_LIST_UPDATE" then
        if self.mode == "getall" and self.state == "waiting" then
            self:SafeUnregister("AUCTION_ITEM_LIST_UPDATE")
            self.total = GetNumAuctionItems("list") or 0
            self.index, self.state = 1, "processing"
        elseif self.mode == "paged" and self.awaitingPage then
            self.pageUpdatedAt = GetTime()
        end
    end
end)

------------------------------------------------------------------------
-- Readers
------------------------------------------------------------------------
local function ReadLegacy(i)
    local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID, hasAllInfo = GetAuctionItemInfo("list", i)
    return count, buyout, itemID, hasAllInfo
end

local function ReadReplicate(i)
    local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = AH.GetReplicateItemInfo(i)
    return count, buyout, itemID
end

function Scanner:RecordBrowseList(list)
    if type(list) ~= "table" then return end
    for _, r in ipairs(list) do
        local key = r.itemKey
        if key and key.itemID then
            self:RecordUnit(key.itemID, r.minPrice, r.totalQuantity, nil)
            self.processed = self.processed + 1
        end
    end
end

local function PageReady(batch, waited)
    if waited >= PAGE_MAX_WAIT then return true end
    for i = 1, batch do
        local _, _, itemID, hasAllInfo = ReadLegacy(i)
        if not itemID or hasAllInfo == false then return false end
    end
    return true
end

function Scanner:ReadPage()
    local batch, total = GetNumAuctionItems("list")
    batch, total = batch or 0, total or 0
    self.total = total
    for i = 1, batch do
        local count, buyout, itemID = ReadLegacy(i)
        self:Record(count, buyout, itemID)
    end
    self.page = self.page + 1
    self.processed = math.min(total, self.page * PAGE_SIZE)
    self.awaitingPage = false
    if batch == 0 or self.page * PAGE_SIZE >= total then self:Finish() end
end

------------------------------------------------------------------------
-- Per-frame work
------------------------------------------------------------------------
function Scanner:Step()
    local now = GetTime()

    if self.state == "browsing" then
        if not self.browseSent then
            if ThrottleReady() then
                local sorts, order = {}, Enum and Enum.AuctionHouseSortOrder
                if order then
                    sorts[1] = { sortOrder = order.Price, reverseSort = false }
                    sorts[2] = { sortOrder = order.Name,  reverseSort = false }
                end
                local query = { searchString = "", sorts = sorts, filters = {}, itemClassFilters = {} }
                local ok, err = SendQuery(AH.SendBrowseQuery, query)
                if not ok then return self:Abort("search failed (" .. tostring(err) .. ")") end
                self.browseSent, self.morePending, self.lastActivity = true, true, now
            end
            return
        end

        if self.firstBatch then
            self.firstBatch = false
            self.processed = 0
            self.results = {}
            self.pendingAdded = nil         -- already part of the full list
            self:RecordBrowseList(AH.GetBrowseResults())
        end
        if self.pendingAdded then
            local batches = self.pendingAdded
            self.pendingAdded = nil
            for _, list in ipairs(batches) do self:RecordBrowseList(list) end
        end

        if not self.morePending then
            if AH.HasFullBrowseResults() then return self:Finish() end
            if ThrottleReady() then
                self.morePending, self.lastActivity = true, now
                AH.RequestMoreBrowseResults()
            end
        elseif now - self.lastActivity > WAIT_TIMEOUT then
            self:Abort("the server stopped answering")
        end

    elseif self.state == "processing" then
        if self.mode == "replicate" then
            local last = math.min(self.index + CHUNK_PER_FRAME, self.total) - 1
            for i = self.index, last do self:Record(ReadReplicate(i)) end
            self.index = last + 1
            self.processed = self.index
        else
            local last = math.min(self.index + CHUNK_PER_FRAME - 1, self.total)
            for i = self.index, last do
                local count, buyout, itemID = ReadLegacy(i)
                self:Record(count, buyout, itemID)
            end
            self.index = last + 1
            self.processed = last
        end
        if self.processed >= self.total then self:Finish() end

    elseif self.state == "paging" then
        if self.awaitingPage then
            if self.pageUpdatedAt and now - self.pageUpdatedAt >= PAGE_SETTLE then
                local batch = GetNumAuctionItems("list") or 0
                if PageReady(batch, now - self.pageSentAt) then self:ReadPage() end
            elseif now - self.pageSentAt > WAIT_TIMEOUT then
                self:Abort("the server stopped answering")
            end
        elseif CanSendAuctionQuery() then
            self.awaitingPage, self.pageUpdatedAt, self.pageSentAt = true, nil, now
            local ok, err = SendQuery(QueryAuctionItems, "", nil, nil, self.page, false, nil, false, false, nil)
            if not ok then self:Abort("query failed (" .. tostring(err) .. ")") end
        end
    end
end

function Scanner:OnUpdate()
    local ok, err = pcall(self.Step, self)
    if not ok and self:IsScanning() then
        self:Abort("error: " .. tostring(err))
    end
end
