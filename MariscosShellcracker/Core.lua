-- Marisco's Shellcracker - settings, slash commands, minimap button
local ADDON, ns = ...
ns.VERSION = "0.13.2 Beta"

local PREFIX = "|cffffd100Shellcracker:|r "
local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg) end
ns.Print = Print

StaticPopupDialogs["MARISCOS_SHELLCRACKER_RESETALL"] = {
    text = "Clear the Shellcracker leaderboard and stats for ALL your characters?",
    button1 = YES or "Yes", button2 = NO or "No",
    OnAccept = function() ns.Stats:ResetAll(); ns.Print("Leaderboard cleared.") end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local DEFAULTS = {
    sound = true,
    battleText = true,
    music = true,
    btDuration = 6,
    autohint = true,
    hintDelay = 15,
    minimap = { angle = 200, hide = false },
}

local function Merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            Merge(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------
local mm
local function PlaceMinimap()
    local a = math.rad(ns.db.minimap.angle)
    local r = (Minimap:GetWidth() / 2) + 5
    mm:ClearAllPoints()
    mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function BuildMinimap()
    mm = CreateFrame("Button", "MariscosShellcrackerMinimapButton", Minimap)
    mm:SetSize(31, 31)
    mm:SetFrameStrata("MEDIUM")
    mm:SetFrameLevel(8)
    mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mm:RegisterForDrag("LeftButton")
    mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = mm:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20); bg:SetPoint("TOPLEFT", 7, -5)
    local icon = mm:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\Ability_Hunter_Pet_Crab")
    icon:SetSize(17, 17); icon:SetPoint("TOPLEFT", 7, -6)
    mm.icon = icon
    local border = mm:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53); border:SetPoint("TOPLEFT")

    mm:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ns.Leaderboard:Toggle()
        else
            ns.UI:Toggle()
        end
    end)
    mm:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local x, y = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            ns.db.minimap.angle = math.deg(math.atan2(y / s - my, x / s - mx))
            PlaceMinimap()
        end)
    end)
    mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    mm:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Marisco's Shellcracker")
        GameTooltip:AddLine("Left-click: play", 1, 1, 1)
        GameTooltip:AddLine("Right-click: leaderboard", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
        GameTooltip:Show()
    end)
    mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PlaceMinimap()
    if ns.db.minimap.hide then mm:Hide() end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function Slash(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "" or cmd == "play" or cmd == "show" then
        ns.UI:Toggle()
    elseif cmd == "new" then
        ns.UI:Open()
        if ns.UI:HasRun() then StaticPopup_Show("MARISCOS_SHELLCRACKER_NEWRUN") else ns.UI:NewGame() end
    elseif cmd == "hint" then
        ns.db.autohint = not ns.db.autohint
        Print("Automatic hints " .. (ns.db.autohint and "on" or "off") .. ".")
    elseif cmd == "hintdelay" then
        local n = tonumber(arg)
        if n and n >= 3 and n <= 60 then ns.db.hintDelay = n; Print("Automatic hint after " .. n .. " seconds.")
        else Print("Use /shell hintdelay <3-60>") end
    elseif cmd == "config" or cmd == "settings" or cmd == "options" then
        ns.Settings:Open()
    elseif cmd == "sound" then
        ns.db.sound = not ns.db.sound
        ns.Settings:Refresh()
        Print("Sound " .. (ns.db.sound and "on" or "off") .. ".")
    elseif cmd == "music" then
        ns.db.music = not ns.db.music
        ns.UI:UpdateMusic()
        ns.Settings:Refresh()
        Print("Music " .. (ns.db.music and "on" or "off") .. ".")
    elseif cmd == "text" then
        ns.db.battleText = not ns.db.battleText
        ns.Settings:Refresh()
        Print("Battle text " .. (ns.db.battleText and "on" or "off") .. ".")
    elseif cmd == "minimap" then
        ns.db.minimap.hide = not ns.db.minimap.hide
        if ns.db.minimap.hide then mm:Hide() else mm:Show() end
        Print("Minimap button " .. (ns.db.minimap.hide and "hidden" or "shown") .. ".")
    elseif cmd == "best" or cmd == "board" or cmd == "leaderboard" or cmd == "lb" then
        ns.Leaderboard:Toggle(1)
    elseif cmd == "talents" or cmd == "character" or cmd == "char" or cmd == "shop" or cmd == "menu" then
        ns.UI:Open()
        local map = { talents = "talents", character = "character", char = "character", shop = "shop", menu = "menu" }
        if map[cmd] ~= "menu" and ns.Game.board and not ns.Game.over and not ns.Game.paused then ns.UI:Pause() end
        ns.Screens:Show(map[cmd])
    elseif cmd == "stats" then
        ns.Leaderboard:Toggle(3)
    elseif cmd == "status" then
        local c = ns.Stats:Char()
        Print(("%s: best score %s, biggest combo x%d, %d games. Sound %s, music %s, automatic hints %s."):format(
            c.name, ns.comma(c.best.score), math.max(1, c.best.combo), c.games, ns.db.sound and "on" or "off",
            ns.db.music and "on" or "off", ns.db.autohint and "on" or "off"))
    elseif cmd == "reset" then
        ns.db.pos = nil
        ns.db.minimap.angle = DEFAULTS.minimap.angle
        PlaceMinimap()
        local f = _G.MariscosShellcrackerFrame
        if f then f:ClearAllPoints(); f:SetPoint("CENTER"); ns.UI:ResetBattleText() else ns.db.btOffset = nil end
        Print("Window, battle text and minimap button positions reset.")
    elseif cmd == "resetscores" then
        StaticPopup_Show("MARISCOS_SHELLCRACKER_RESETALL")
    else
        Print("/shell - open or close the game")
        Print("/shell new - start a new fight   /shell config - settings")
        Print("/shell char - character & bags   /shell talents   /shell shop")
        Print("/shell hint - automatic hints on/off   /shell hintdelay <sec>")
        Print("/shell sound - sound on/off   /shell music - music on/off   /shell text - battle text on/off   /shell minimap - minimap button")
        Print("/shell board - leaderboard   /shell stats - your stats   /shell reset - reset positions")
        Print("/shell resetscores - clear the leaderboard for all characters")
    end
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        MariscosShellcrackerDB = MariscosShellcrackerDB or {}
        MariscosShellcrackerCharDB = MariscosShellcrackerCharDB or {}
        Merge(MariscosShellcrackerDB, DEFAULTS)
        ns.db = MariscosShellcrackerDB
        -- the zone music was switched off for the inn music and the game was closed without
        -- closing our window (crash, Alt-F4): switch it back to how it was
        if ns.UI and ns.UI.Music then ns.UI.Music:RestoreZoneMusic() end
        if not ns.db.v2 then ns.db.hintDelay = 15; ns.db.v2 = true end   -- 0.1 used 12 s
        ns.cdb = MariscosShellcrackerCharDB
        ns.Stats:Init()
        ns.Prog:Data()
        ns.Prog:Migrate()
        ns.Prog:Publish()
        BuildMinimap()
        SLASH_MARISCOSSHELLCRACKER1 = "/shell"
        SLASH_MARISCOSSHELLCRACKER2 = "/msc"
        SlashCmdList.MARISCOSSHELLCRACKER = Slash
        ev:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGOUT" then
        if ns.UI and ns.UI.Save then ns.UI.Save() end
        if ns.UI and ns.UI.Music then ns.UI.Music:Stop(); ns.UI.Music:RestoreZoneMusic() end
    end
end)
