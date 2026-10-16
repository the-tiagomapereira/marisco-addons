-- Marisco's Item Value Scanner - Auction House scan button
-- The button docks to the bottom-right corner of whichever Auction House
-- frame the client uses (AuctionFrame on classic-style clients,
-- AuctionHouseFrame on modern ones) and travels with it when it moves.
-- If you drag it away (Shift + drag) it snaps straight back to the dock.

local _, ns = ...

local button, status
local cooldownEnd = 0

local function GetAHFrame()
    return _G.AuctionFrame or _G.AuctionHouseFrame
end

local function Dock()
    local ah = GetAHFrame()
    if not (button and ah) then return end
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", ah, "BOTTOMRIGHT", -2, -2)
end

local function UpdateButton()
    if not button then return end
    local remaining = cooldownEnd - GetTime()
    local scanning = ns.Scanner:IsScanning()

    if remaining > 0 then
        button:Disable()
        button:SetText(string.format("Scan AH (%d)", math.ceil(remaining)))
    elseif scanning then
        button:Disable()
        button:SetText("Scanning...")
    else
        button:Enable()
        button:SetText("Scan AH")
    end
    button.icon:SetDesaturated(remaining > 0 or scanning)

    if scanning then
        status:SetText("|cffffd100" .. ns.Scanner:GetProgressText() .. "|r")
    elseif ns.data.lastScan then
        status:SetText("|cffaaaaaaLast scan: " .. ns.FormatAge(time() - ns.data.lastScan) .. "|r")
    else
        status:SetText("|cffaaaaaaNo scan yet|r")
    end
end

function ns:TryScan()
    if GetTime() < cooldownEnd then
        ns:Print(string.format("Scan is on cooldown for %d more seconds.", math.ceil(cooldownEnd - GetTime())))
        return
    end
    local ok, err = ns.Scanner:Start()
    if ok then
        cooldownEnd = GetTime() + ns.SCAN_COOLDOWN
        ns:Print("Scanning the Auction House...")
    else
        ns:Print("Can't scan: " .. err)
    end
    UpdateButton()
end

local function CreateButton()
    local ah = GetAHFrame()
    if not ah or button then return end

    button = CreateFrame("Button", "MariscosIVS_ScanButton", ah, "UIPanelButtonTemplate")
    button:SetSize(118, 24)
    button:SetFrameStrata("HIGH")

    button.icon = button:CreateTexture(nil, "OVERLAY")
    button.icon:SetSize(16, 16)
    button.icon:SetPoint("LEFT", 6, 0)
    button.icon:SetTexture(ns.ICON)
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local fs = button:GetFontString()
    if fs then fs:ClearAllPoints(); fs:SetPoint("LEFT", button.icon, "RIGHT", 4, 0); fs:SetPoint("RIGHT", -6, 0) end

    status = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("RIGHT", button, "LEFT", -6, 0)
    status:SetJustifyH("RIGHT")

    button:SetScript("OnClick", function() ns:TryScan() end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:AddLine(ns.TITLE, 0.41, 0.8, 0.94)
        GameTooltip:AddLine("Scans every listing on the Auction House.", 1, 1, 1, true)
        GameTooltip:AddLine(ns.SCAN_COOLDOWN .. "s cooldown between scans.", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Mode: " .. (ns.db.fastScan and "FAST" or "SAFE") .. " (/mivs fast to switch)", 0.7, 0.7, 0.7)
        if ns.data.lastScan then
            GameTooltip:AddLine("Last scan: " .. ns.FormatDate(ns.data.lastScan), 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    -- "Magnetic" dock: Shift-drag moves it, releasing snaps it back.
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
    button:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); Dock() end)

    local elapsed = 0
    button:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 0.2 then elapsed = 0; UpdateButton() end
    end)

    Dock()
end

function ns:UpdateAHButtonVisibility()
    if not button then return end
    if ns.db.showAHButton then button:Show() else button:Hide() end
end

function ns:OnAuctionHouseShow()
    CreateButton()
    Dock()
    ns:UpdateAHButtonVisibility()
    UpdateButton()
end

function ns:OnScanStateChanged()
    UpdateButton()
end
