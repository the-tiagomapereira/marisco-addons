-- Marisco's Item Value Scanner - Minimap button (Arcane Intellect icon)
-- Left-click: toggle the Auction House scan button on/off
-- Right-click: print last scan info
-- Drag: move around the minimap edge

local _, ns = ...

local btn

local function UpdatePosition()
    local angle = math.rad(ns.db.minimap.angle or 225)
    local radius = (Minimap:GetWidth() / 2) + 5
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    ns.db.minimap.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
    UpdatePosition()
end

function ns:UpdateMinimapIcon()
    if not btn then return end
    if ns.db.minimap.hide then btn:Hide() else btn:Show() end
    btn.icon:SetDesaturated(not ns.db.showAHButton)
end

function ns:CreateMinimapButton()
    if btn then return end
    btn = CreateFrame("Button", "MariscosIVS_MinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(17, 17)
    btn.icon:SetTexture(ns.ICON)
    btn.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    btn.icon:SetPoint("TOPLEFT", 7, -6)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    btn:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then ns:PrintStatus() else ns:ToggleAHButton() end
    end)
    btn:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ns.TITLE, 0.41, 0.8, 0.94)
        GameTooltip:AddLine(ns.VERSION, 0.7, 0.7, 0.7)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("AH scan button:", ns.db.showAHButton and "|cff00ff00ON|r" or "|cffff4040OFF|r")
        GameTooltip:AddLine("|cffffd100Left-click|r to toggle the AH scan button", 1, 1, 1)
        GameTooltip:AddLine("|cffffd100Right-click|r for last scan info", 1, 1, 1)
        GameTooltip:AddLine("|cffffd100Drag|r to move", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)

    UpdatePosition()
    ns:UpdateMinimapIcon()
end
