-- Marisco's MiniMapButtonHoarder - main button, saved settings, slash commands
local ADDON, ns = ...

ns.TITLE = "Marisco's MiniMapButtonHoarder"
ns.VERSION = "0.5"
ns.ICON = "Interface\\Icons\\INV_Box_02"

ns.TIMERS = { 3, 5, 10, 15 }
ns.LAYOUTS = {
    { key = "arch",       label = "Arch",       desc = "semi-circle around the button" },
    { key = "triangle",   label = "Triangle",   desc = "rows of 1, 2, 3... widening out" },
    { key = "box",        label = "Boxed",      desc = "a neat grid" },
    { key = "horizontal", label = "Horizontal", desc = "one row, left or right" },
    { key = "vertical",   label = "Vertical",   desc = "one column, up or down" },
}

ns.DEFAULTS = {
    angle = 225,        -- main button position around the minimap (degrees, 0 = right, 90 = top)
    scale = 1,          -- size of the hoarded buttons (1 = their normal size)
    gap = 6,            -- space between buttons
    hoverZoom = true,   -- the button under the pointer grows a little
    hoverScale = 1.25,  -- how much it grows (1.10 - 1.50)
    tidyIcons = true,   -- center each icon in its round border and fill it
    layout = "arch",    -- arch, triangle, box, horizontal, vertical
    spread = 180,       -- arch size in degrees (180 = semi-circle, 360 = full circle)
    radius = 70,        -- smallest arch radius (it grows when there are many buttons)
    autoClose = true,   -- true: fold back after closeDelay; false: until clicked out
    closeDelay = 3,     -- 3, 5, 10 or 15 seconds
    enabled = true,     -- hoarding on/off
    ignore = {},        -- frame names never hoarded
    include = {},       -- frame names always hoarded
}

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffMMBH|r: " .. tostring(msg))
end

function ns.SnapTimer(v)
    local best = ns.TIMERS[1]
    for _, t in ipairs(ns.TIMERS) do
        if math.abs(t - (v or 3)) < math.abs(best - (v or 3)) then best = t end
    end
    return best
end

function ns.LayoutLabel(key)
    for _, l in ipairs(ns.LAYOUTS) do
        if l.key == key then return l.label end
    end
    return "Arch"
end

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

---------------------------------------------------------------------------
-- Main button position (same rules as LibDBIcon, so it sits with the others)
---------------------------------------------------------------------------
local minimapShapes = {
    ["ROUND"] = { true, true, true, true },
    ["SQUARE"] = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
    ["TRICORNER-TOPLEFT"] = { false, true, true, true },
    ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

function ns.UpdateMainPosition()
    local b = ns.main
    if not b then return end
    local angle = math.rad(ns.db.angle or 225)
    local x, y = math.cos(angle), math.sin(angle)
    local q = 1
    if x < 0 then q = q + 1 end
    if y > 0 then q = q + 2 end
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local quad = minimapShapes[shape] or minimapShapes.ROUND
    local w = (Minimap:GetWidth() / 2) + 5
    local h = (Minimap:GetHeight() / 2) + 5
    if quad[q] then
        x, y = x * w, y * h
    else
        local dw = math.sqrt(2 * w * w) - 10
        local dh = math.sqrt(2 * h * h) - 10
        x = math.max(-w, math.min(x * dw, w))
        y = math.max(-h, math.min(y * dh, h))
    end
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function ns.UpdateBadge()
    if not ns.main then return end
    local n = 0
    for _, f in ipairs(ns.ordered) do
        if f:IsShown() then n = n + 1 end
    end
    ns.main.badge:SetText(n > 0 and n or "")
end

function ns.UpdateMainState()
    if not ns.main then return end
    if ns.IsOpen() then ns.main.glow:Show() else ns.main.glow:Hide() end
end

local function ShowTooltip(self)
    if ns.IsOpen() or self.dragging then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(ns.TITLE)
    local n, hidden = 0, 0
    for _, f in ipairs(ns.ordered) do
        if f:IsShown() then n = n + 1 else hidden = hidden + 1 end
    end
    if not ns.db.enabled then
        GameTooltip:AddLine("Hoarding is off (/mmbh on)", 1, 0.3, 0.3)
    else
        local line = n .. " button" .. (n == 1 and "" or "s") .. " hoarded"
        if hidden > 0 then line = line .. " (+" .. hidden .. " hidden by their addon)" end
        GameTooltip:AddLine(line, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left-click", "show / hide the buttons", 0, 1, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right-click", "settings", 0, 1, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Drag", "move around the minimap", 0, 1, 0, 1, 1, 1)
    GameTooltip:Show()
end

local function CreateMainButton()
    local b = CreateFrame("Button", "MariscosMMBHButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("HIGH")
    b:SetFrameLevel(30)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- icon centered in the hole of the round border and filling it (see ns.RING in Hoard.lua)
    local R, B = ns.RING, 53
    local cx, cy = R.x * B, -R.y * B
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(R.back * B, R.back * B)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("CENTER", b, "TOPLEFT", cx, cy)

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(R.icon * B, R.icon * B)
    icon:SetTexture(ns.ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("CENTER", b, "TOPLEFT", cx, cy)
    if b.CreateMaskTexture and icon.AddMaskTexture then
        local mask = b:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
    end
    b.icon = icon

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(B, B)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    -- golden ring while the fan is open
    local glow = b:CreateTexture(nil, "OVERLAY", nil, 2)
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.82, 0.2, 0.9)
    glow:SetSize(52, 52)
    glow:SetPoint("CENTER", icon, "CENTER")
    glow:Hide()
    b.glow = glow

    -- how many buttons are hoarded
    local badge = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    badge:SetPoint("CENTER", icon, "BOTTOMRIGHT", 2, 1)
    badge:SetDrawLayer("OVERLAY", 7)
    b.badge = badge

    b:SetScript("OnClick", function(self, button)
        GameTooltip:Hide()
        if button == "RightButton" then
            ns.ToggleSettings()
        else
            ns.Toggle()
        end
    end)
    b:SetScript("OnEnter", ShowTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    b:SetScript("OnDragStart", function(self)
        ns.Close(true)
        GameTooltip:Hide()
        self.dragging = true
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            px, py = px / s, py / s
            ns.db.angle = math.deg(math.atan2(py - my, px - mx)) % 360
            ns.UpdateMainPosition()
        end)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self.dragging = false
    end)

    ns.main = b
end

function ns.HookLibDBIcon()
    local stub = _G.LibStub
    local lib = stub and stub("LibDBIcon-1.0", true)
    if lib and lib.Register then
        hooksecurefunc(lib, "Register", function()
            C_Timer.After(0.1, function() ns.Scan() end)
        end)
    end
end

-- puts the window settings back to their defaults (position and lists are kept)
function ns.ResetSettings()
    local d, db = ns.DEFAULTS, ns.db
    db.scale, db.gap, db.layout, db.autoClose, db.closeDelay = d.scale, d.gap, d.layout, d.autoClose, d.closeDelay
    db.spread, db.radius = d.spread, d.radius
    db.hoverZoom, db.hoverScale = d.hoverZoom, d.hoverScale
    db.tidyIcons = d.tidyIcons
    ns.ApplySkins()
    ns.ApplyScale()
    ns.Relayout()
    if ns.RefreshSettings then ns.RefreshSettings() end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        MariscosMiniMapButtonHoarderDB = MariscosMiniMapButtonHoarderDB or {}
        CopyDefaults(ns.DEFAULTS, MariscosMiniMapButtonHoarderDB)
        ns.db = MariscosMiniMapButtonHoarderDB
        ns.db.closeDelay = ns.SnapTimer(ns.db.closeDelay)  -- v0.1/0.2 used 1.5 s
    elseif event == "PLAYER_LOGIN" then
        CreateMainButton()
        ns.CreateContainer(ns.main)
        ns.UpdateMainPosition()
        ns.HookLibDBIcon()
        -- addons create their buttons at different moments, so look a few times
        for _, delay in ipairs({ 0.5, 3, 10 }) do
            C_Timer.After(delay, function() ns.Scan() end)
        end
        ns.UpdateBadge()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if ns.main then C_Timer.After(2, function() ns.Scan() end) end
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function FindHoarded(query)
    query = query:lower()
    for _, f in ipairs(ns.ordered) do
        if f:GetName():lower() == query or ns.DisplayName(f):lower() == query then return f end
    end
    for _, f in ipairs(ns.ordered) do
        if ns.DisplayName(f):lower():find(query, 1, true) then return f end
    end
end

local function FindFrameByName(query)
    if type(_G[query]) == "table" and _G[query].GetObjectType then return query end
    local q = query:lower()
    for _, parent in ipairs({ Minimap, MinimapBackdrop }) do
        if parent then
            for _, f in ipairs({ parent:GetChildren() }) do
                local n = f.GetName and f:GetName()
                if n and (n:lower() == q or n:lower() == "libdbicon10_" .. q) then return n end
            end
        end
    end
end

local function Help()
    ns.Print(ns.TITLE .. " v" .. ns.VERSION)
    ns.Print("/mmbh - show / hide the buttons")
    ns.Print("/mmbh config - open the settings (or right-click the button)")
    ns.Print("/mmbh scan - look for new minimap buttons")
    ns.Print("/mmbh list - list hoarded and ignored buttons")
    ns.Print("/mmbh ignore <name> - give a button back to the minimap and never take it")
    ns.Print("/mmbh unignore <name> - allow it again")
    ns.Print("/mmbh add <name> - take a button the scan missed (exact frame name)")
    ns.Print("/mmbh layout arch|triangle|boxed|horizontal|vertical")
    ns.Print("/mmbh size <60-150> - button size in %")
    ns.Print("/mmbh gap <n> - space between buttons")
    ns.Print("/mmbh hover on|off|<110-150> - grow the button under the pointer")
    ns.Print("/mmbh tidy - center and fill the icons (on/off)")
    ns.Print("/mmbh delay 3|5|10|15 - seconds before folding back")
    ns.Print("/mmbh autoclose - switch between the timer and 'until clicked out'")
    ns.Print("/mmbh spread <deg> · /mmbh radius <n> - arch shape")
    ns.Print("/mmbh on | off - hoard buttons, or give them all back")
    ns.Print("/mmbh status · /mmbh reset")
end

SLASH_MARISCOSMMBH1 = "/mmbh"
SLASH_MARISCOSMMBH2 = "/hoarder"
SlashCmdList.MARISCOSMMBH = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    rest = rest or ""
    local db = ns.db
    local function changed()
        ns.Relayout()
        if ns.RefreshSettings then ns.RefreshSettings() end
    end

    if cmd == "" or cmd == "toggle" then
        ns.Toggle()

    elseif cmd == "config" or cmd == "settings" or cmd == "options" then
        ns.ToggleSettings()

    elseif cmd == "scan" then
        ns.Scan(true)

    elseif cmd == "list" then
        if #ns.ordered == 0 then ns.Print("No buttons hoarded.") end
        for _, f in ipairs(ns.ordered) do
            local extra = f:IsShown() and "" or " |cff888888(hidden by its addon)|r"
            ns.Print("  " .. ns.DisplayName(f) .. " |cff888888[" .. f:GetName() .. "]|r" .. extra)
        end
        local ign = {}
        for name in pairs(db.ignore) do ign[#ign + 1] = name end
        if #ign > 0 then
            table.sort(ign)
            ns.Print("Ignored: " .. table.concat(ign, ", "))
        end

    elseif cmd == "ignore" then
        if rest == "" then ns.Print("Usage: /mmbh ignore <name>  (see /mmbh list)") return end
        local f = FindHoarded(rest)
        local name = f and f:GetName() or FindFrameByName(rest)
        if not name then ns.Print("No button called '" .. rest .. "'. See /mmbh list.") return end
        db.ignore[name] = true
        db.include[name] = nil
        if f then
            ns.Release(f)
            ns.RequestRelayout()
        end
        ns.UpdateBadge()
        ns.Print(name .. " is back on the minimap and won't be hoarded.")

    elseif cmd == "unignore" then
        local q = rest:lower()
        local found
        for name in pairs(db.ignore) do
            if name:lower() == q or name:lower() == "libdbicon10_" .. q then found = name end
        end
        if not found then ns.Print("'" .. rest .. "' is not on the ignore list.") return end
        db.ignore[found] = nil
        ns.Scan()
        ns.Print(found .. " can be hoarded again.")

    elseif cmd == "add" then
        local name = rest ~= "" and FindFrameByName(rest)
        if not name then ns.Print("No frame called '" .. rest .. "'. Use the exact frame name.") return end
        db.include[name] = true
        db.ignore[name] = nil
        local n = ns.Scan()
        ns.Print(n > 0 and (name .. " hoarded.") or (name .. " could not be hoarded (protected or already hoarded)."))

    elseif cmd == "layout" then
        local q = rest:lower()
        for _, l in ipairs(ns.LAYOUTS) do
            if q ~= "" and (l.key:find(q, 1, true) == 1 or l.label:lower():find(q, 1, true) == 1) then
                db.layout = l.key
                changed()
                ns.Print("Layout: " .. l.label .. ".")
                return
            end
        end
        ns.Print("Usage: /mmbh layout arch|triangle|boxed|horizontal|vertical")

    elseif cmd == "size" then
        local n = tonumber((rest:gsub("%%", "")))
        if not n then ns.Print("Usage: /mmbh size <60-150>") return end
        db.scale = math.max(60, math.min(150, math.floor(n / 10 + 0.5) * 10)) / 100
        ns.ApplyScale()
        changed()
        ns.Print("Button size " .. math.floor(db.scale * 100 + 0.5) .. "%.")

    elseif cmd == "hover" then
        local q = rest:lower():gsub("%%", "")
        local n = tonumber(q)
        if q == "on" then db.hoverZoom = true
        elseif q == "off" then db.hoverZoom = false
        elseif n then
            db.hoverZoom = true
            db.hoverScale = math.max(110, math.min(150, math.floor(n / 5 + 0.5) * 5)) / 100
        elseif q == "" then db.hoverZoom = not db.hoverZoom
        else ns.Print("Usage: /mmbh hover on|off|<110-150>") return end
        if ns.RefreshSettings then ns.RefreshSettings() end
        ns.Print(db.hoverZoom and ("Buttons grow to " .. math.floor(db.hoverScale * 100 + 0.5) .. "% on hover.")
            or "Hover zoom is off.")

    elseif cmd == "tidy" then
        db.tidyIcons = not db.tidyIcons
        ns.ApplySkins()
        if ns.RefreshSettings then ns.RefreshSettings() end
        ns.Print(db.tidyIcons and "Icons are centered and fill their border." or "Icons are left as their addon draws them.")

    elseif cmd == "autoclose" then
        db.autoClose = not db.autoClose
        if ns.RefreshSettings then ns.RefreshSettings() end
        ns.Print(db.autoClose and ("Folds back after " .. db.closeDelay .. " s.") or "Stays open until you click elsewhere.")

    elseif cmd == "delay" then
        local n = tonumber(rest)
        if not n then ns.Print("Usage: /mmbh delay 3|5|10|15") return end
        db.closeDelay = ns.SnapTimer(n)
        db.autoClose = true
        if ns.RefreshSettings then ns.RefreshSettings() end
        ns.Print("Folds back " .. db.closeDelay .. " s after the pointer leaves.")

    elseif cmd == "gap" then
        local n = tonumber(rest)
        if not n then ns.Print("Usage: /mmbh gap <0-30>") return end
        db.gap = math.max(0, math.min(30, math.floor(n + 0.5)))
        changed()
        ns.Print("Spacing set to " .. db.gap .. ".")

    elseif cmd == "spread" then
        local n = tonumber(rest)
        if not n then ns.Print("Usage: /mmbh spread <90-360>") return end
        db.spread = math.max(90, math.min(360, n))
        changed()
        ns.Print("Arch set to " .. db.spread .. " degrees.")

    elseif cmd == "radius" then
        local n = tonumber(rest)
        if not n then ns.Print("Usage: /mmbh radius <40-150>") return end
        db.radius = math.max(40, math.min(150, n))
        changed()
        ns.Print("Arch radius set to " .. db.radius .. ".")

    elseif cmd == "on" then
        db.enabled = true
        local n = ns.Scan()
        ns.Print("Hoarding is on (" .. n .. " buttons taken).")

    elseif cmd == "off" then
        db.enabled = false
        ns.ReleaseAll()
        ns.Print("Hoarding is off. Every button is back on the minimap.")

    elseif cmd == "status" then
        local shown = 0
        for _, f in ipairs(ns.ordered) do if f:IsShown() then shown = shown + 1 end end
        local ign = 0
        for _ in pairs(db.ignore) do ign = ign + 1 end
        ns.Print(string.format("Hoarding %s · %d buttons (%d visible) · %d ignored",
            db.enabled and "on" or "off", #ns.ordered, shown, ign))
        ns.Print(string.format("Layout %s · size %d%% · spacing %d · hover %s · %s",
            ns.LayoutLabel(db.layout), math.floor(db.scale * 100 + 0.5), db.gap,
            db.hoverZoom and (math.floor(db.hoverScale * 100 + 0.5) .. "%") or "off",
            db.autoClose and ("folds back after " .. db.closeDelay .. " s") or "until clicked out"))

    elseif cmd == "reset" then
        db.angle = ns.DEFAULTS.angle
        ns.UpdateMainPosition()
        ns.ResetSettings()
        ns.Print("Position and settings reset (your ignore and add lists are kept).")

    else
        Help()
    end
end
