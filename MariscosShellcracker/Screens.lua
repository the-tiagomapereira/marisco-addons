-- Marisco's Shellcracker - screens inside the game window: Menu, Character & Bags, Talents, Shop
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local Screens = { frames = {} }
ns.Screens = Screens
local Prog = ns.Prog
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function comma(n) return ns.comma(n) end
local function SFX(kind)
    if not (ns.db and ns.db.sound and PlaySoundFile) then return end
    local list = ns.SFX[kind]
    if list then pcall(PlaySoundFile, list[math.random(#list)], "SFX") end
end
local function Err(msg)
    if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(msg, 1, 0.1, 0.1)
    elseif ns.Print then ns.Print(msg) end
end

---------------------------------------------------------------------------
-- shared bits
---------------------------------------------------------------------------
local function Button(parent, text, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h or 24)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function Label(parent, template, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    if text then fs:SetText(text) end
    return fs
end

local function Bar(parent, w, h, r, g, b)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(w, h)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(r, g, b)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0.7)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER")
    return bar
end

-- item / slot button: icon, quality border, optional slot background
local function ItemButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetTexture("Interface\\Buttons\\UI-EmptySlot")
    b.bg:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.edges = {}
    for i, e in ipairs({ { "TOPLEFT", "TOPRIGHT", "h" }, { "BOTTOMLEFT", "BOTTOMRIGHT", "h" },
                         { "TOPLEFT", "BOTTOMLEFT", "v" }, { "TOPRIGHT", "BOTTOMRIGHT", "v" } }) do
        local t = b:CreateTexture(nil, "OVERLAY")
        t:SetPoint(e[1]); t:SetPoint(e[2])
        if e[3] == "h" then t:SetHeight(2) else t:SetWidth(2) end
        b.edges[i] = t
    end
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square"); hl:SetBlendMode("ADD")
    b.SetItem = function(self, item, emptyTex)
        self.item = item
        if item then
            self.icon:SetTexture(item.icon); self.icon:Show()
            self.icon:SetDesaturated(false)
            local hex = ns.QUALITY[item.q].color
            local r, g, bl = tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255
            for _, t in ipairs(self.edges) do
                t:SetColorTexture(r, g, bl, item.q >= 2 and 0.95 or 0.35); t:Show()
            end
        else
            if emptyTex then self.icon:SetTexture(emptyTex); self.icon:Show(); self.icon:SetDesaturated(true)
            else self.icon:Hide() end
            for _, t in ipairs(self.edges) do t:Hide() end
        end
    end
    return b
end

-- difference between an item and what is equipped in its slot, as tooltip lines
local function CompareLines(item)
    local target = Prog:EquipTarget(item, IsShiftKeyDown and IsShiftKeyDown())
    local cur = Prog:Data().gear[target]
    local out = {}
    local function diff(name, a, b, suffix)
        local d = (a or 0) - (b or 0)
        if d ~= 0 then
            out[#out+1] = { (d > 0 and "+" or "") .. d .. (suffix or " ") .. name, d > 0 and 0.1 or 1, d > 0 and 1 or 0.2, d > 0 and 0.1 or 0.2 }
        end
    end
    for _, k in ipairs(ns.STAT_ORDER) do diff(ns.STAT_INFO[k].name, item.stats[k], cur and cur.stats[k]) end
    return out, cur
end

local function ItemTooltip(owner, item, extra, compare)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local lines = Prog:ItemLines(item)
    GameTooltip:SetText(lines[1][1], lines[1][2], lines[1][3], lines[1][4])
    for i = 2, #lines do GameTooltip:AddLine(lines[i][1], lines[i][2], lines[i][3], lines[i][4], true) end
    if compare then
        local diffs, cur = CompareLines(item)
        GameTooltip:AddLine(" ")
        if cur then
            GameTooltip:AddLine("Instead of " .. Prog:Link(cur) .. ":", 0.8, 0.8, 0.8)
            if #diffs == 0 then GameTooltip:AddLine("No stat change", 0.6, 0.6, 0.6) end
        else
            GameTooltip:AddLine("Nothing equipped in this slot.", 0.8, 0.8, 0.8)
        end
        for _, d in ipairs(diffs) do GameTooltip:AddLine(d[1], d[2], d[3], d[4]) end
    end
    if extra then
        GameTooltip:AddLine(" ")
        for _, e in ipairs(extra) do GameTooltip:AddLine(e, 0, 1, 0.6, true) end
    end
    GameTooltip:Show()
end

local function NewScreen(name, title)
    local main = ns.UI:GetFrame()
    local s = CreateFrame("Frame", nil, main)
    s:SetPoint("TOPLEFT", 8, -58)
    s:SetPoint("BOTTOMRIGHT", -8, 8)
    s:SetFrameLevel(main:GetFrameLevel() + 60)
    s:EnableMouse(true)
    local bg = s:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.05, 0.07, 0.97)
    s.screenTitle = title
    s:Hide()
    Screens.frames[name] = s
    return s
end

local function BackButton(s)
    local b = Button(s, "Back", 90, 24, function() Screens:Show("menu") end)
    b:SetPoint("BOTTOMLEFT", 10, 8)
    return b
end

local function LockNote(s)
    local note = CreateFrame("Frame", nil, s)
    note:SetHeight(24)
    note:SetPoint("BOTTOMLEFT", 110, 8)
    note:SetPoint("BOTTOMRIGHT", -10, 8)
    note.text = Label(note, "GameFontNormal", "|cffff6060A run is in progress: gear and talents are locked.|r")
    note.text:SetPoint("LEFT")
    note.btn = Button(note, "Abandon run", 120, 22, function() StaticPopup_Show("MARISCOS_SHELLCRACKER_ABANDON") end)
    note.btn:SetPoint("RIGHT")
    return note
end

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs["MARISCOS_SHELLCRACKER_ABANDON"] = {
    text = "Abandon your current run? It still counts on the leaderboard, but you won't get the run experience.",
    button1 = YES or "Yes", button2 = NO or "No",
    OnAccept = function() ns.UI:AbandonRun(); Screens:Refresh() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
StaticPopupDialogs["MARISCOS_SHELLCRACKER_NEWRUN"] = {
    text = "Start a new game? Your current run will end.",
    button1 = YES or "Yes", button2 = NO or "No",
    OnAccept = function() ns.UI:NewGame() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
StaticPopupDialogs["MARISCOS_SHELLCRACKER_SELL"] = {
    text = "Sell %s for %s?",
    button1 = YES or "Yes", button2 = NO or "No",
    OnAccept = function(_, index) Screens:SellNow(index) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
StaticPopupDialogs["MARISCOS_SHELLCRACKER_RESETTALENTS"] = {
    text = "Remove all your talent points so you can spend them again?",
    button1 = YES or "Yes", button2 = NO or "No",
    OnAccept = function() Prog:ResetTalents(); SFX("untalent"); Screens:Refresh() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

---------------------------------------------------------------------------
-- MENU
---------------------------------------------------------------------------
local function BuildMenu()
    local s = NewScreen("menu", "Main Menu")
    -- character card
    local card = CreateFrame("Frame", nil, s)
    card:SetPoint("TOPLEFT", 16, -14)
    card:SetSize(300, 320)
    s.badge = card:CreateTexture(nil, "ARTWORK")
    s.badge:SetSize(56, 56); s.badge:SetPoint("TOPLEFT", 0, 0)
    s.name = Label(card, "GameFontNormalHuge")
    s.name:SetPoint("TOPLEFT", s.badge, "TOPRIGHT", 12, -2)
    s.title = Label(card, "GameFontHighlight")
    s.title:SetPoint("TOPLEFT", s.name, "BOTTOMLEFT", 0, -6)
    s.xp = Bar(card, 290, 16, 0.58, 0.0, 0.55)
    s.xp:SetPoint("TOPLEFT", s.badge, "BOTTOMLEFT", 0, -16)
    s.lines = {}
    for i = 1, 8 do
        local l = Label(card, "GameFontNormal")
        l:SetPoint("TOPLEFT", s.xp, "BOTTOMLEFT", 0, -14 - (i - 1) * 22)
        l:SetWidth(130); l:SetJustifyH("LEFT")
        local v = Label(card, "GameFontHighlight")
        v:SetPoint("LEFT", l, "RIGHT", 4, 0)
        v:SetWidth(160); v:SetJustifyH("RIGHT")
        s.lines[i] = { l = l, v = v }
    end
    -- buttons
    local col = CreateFrame("Frame", nil, s)
    col:SetPoint("TOPRIGHT", -24, -14)
    col:SetSize(220, 330)
    local y = 0
    local function add(key, text, onClick, gap)
        local b = Button(col, text, 220, 30, onClick)
        b:SetPoint("TOP", 0, -y)
        y = y + 30 + (gap or 6)
        s[key] = b
        return b
    end
    add("continue", "Continue", function()
        if not ns.UI:Continue() then Err("No run to continue.") end
    end, 0)
    s.runInfo = Label(col, "GameFontDisableSmall")
    s.runInfo:SetPoint("TOP", 0, -y - 2)
    y = y + 18
    add("newgame", "New Game", function()
        if ns.UI:HasRun() then StaticPopup_Show("MARISCOS_SHELLCRACKER_NEWRUN") else ns.UI:NewGame() end
    end, 14)
    add("character", "Character & Bags", function() Screens:Show("character") end)
    add("talents", "Talents", function() Screens:Show("talents") end)
    add("shop", "Shop", function() Screens:Show("shop") end, 14)
    add("leaderboard", "Leaderboard", function() ns.Leaderboard:Toggle() end)
    add("settings", "Settings", function() ns.Settings:Toggle() end)
    s.refresh = function()
        local d = Prog:Data()
        local title, badge = Prog:Title()
        s.badge:SetTexture(badge)
        s.name:SetText((UnitName and UnitName("player")) or "")
        s.title:SetText(("Level %d %s"):format(d.level, title))
        if d.level >= ns.MAX_LEVEL then
            s.xp:SetMinMaxValues(0, 1); s.xp:SetValue(1); s.xp.text:SetText("Maximum level")
        else
            s.xp:SetMinMaxValues(0, ns.XPToNext(d.level)); s.xp:SetValue(d.xp)
            s.xp.text:SetText(("%s / %s experience"):format(comma(d.xp), comma(ns.XPToNext(d.level))))
        end
        local c = ns.Stats:Char()
        local free = Prog:PointsFree()
        local rows = {
            { "Money", Prog:Money(d.gold) },
            { "Talent points", free > 0 and ("|cff00ff00" .. free .. " to spend|r") or (Prog:Level() < ns.TALENT_START and ("from level " .. ns.TALENT_START) or "0") },
            { "Bags", Prog:BagCount() .. " / " .. ns.BAG_SIZE },
            { "Best score", comma(c.best.score) },
            { "Biggest combo", c.best.combo > 0 and ("x" .. c.best.combo) or "-" },
            { "Games played", comma(c.games) },
            { "Makrura defeated", comma(c.kills) },
            { "Next title", d.level >= 60 and "-" or (Prog:Title(min(60, (floor(d.level / 10) + 1) * 10)) .. " at " .. min(60, (floor(d.level / 10) + 1) * 10)) },
        }
        for i, ln in ipairs(s.lines) do ln.l:SetText(rows[i][1]); ln.v:SetText(rows[i][2]) end
        local run = ns.UI:HasRun()
        if run then s.continue:Enable() else s.continue:Disable() end
        local sv = ns.cdb.save
        local G = ns.Game
        local wave, score = (G.board and not G.over) and G.wave or (sv and sv.wave), (G.board and not G.over) and G.score or (sv and sv.score)
        if run and wave then
            local e = ns.GetEnemy(wave)
            s.runInfo:SetText(("%s, score %s"):format(e.name, comma(score or 0)))
        else
            s.runInfo:SetText("No run in progress")
        end
        s.talents:SetText(free > 0 and ("Talents |cff00ff00(" .. free .. ")|r") or "Talents")
    end
    return s
end

---------------------------------------------------------------------------
-- CHARACTER & BAGS
---------------------------------------------------------------------------
function Screens:SellNow(index)
    local ok, item = Prog:Sell(index)
    if ok then
        SFX("coinsBig")
        if ns.Print then ns.Print(("Sold %s for %s. Changed your mind? It is in the Shop's Buyback tab."):format(Prog:Link(item), Prog:Money(item.sell))) end
    end
    self:Refresh()
end

local function BuildCharacter()
    local s = NewScreen("character", "Character & Bags")
    s.slots = {}
    local nL, nR, nB = 0, 0, 0
    for i, slot in ipairs(ns.SLOTS) do
        local b = ItemButton(s, 36)
        -- paper doll: left column, right column, weapons underneath the stats
        if slot.col == "L" then
            b:SetPoint("TOPLEFT", 10, -12 - nL * 40); nL = nL + 1
        elseif slot.col == "R" then
            b:SetPoint("TOPLEFT", 266, -12 - nR * 40); nR = nR + 1
        else
            b:SetPoint("TOPLEFT", 94 + nB * 42, -276); nB = nB + 1
        end
        b.slot = slot
        b:SetScript("OnClick", function(self)
            if not self.item then return end
            local ok, why = Prog:Unequip(self.slot.id)
            if ok then SFX("equip") else Err(why or "") end
            Screens:Refresh()
        end)
        b:SetScript("OnEnter", function(self)
            if self.item then
                ItemTooltip(self, self.item, { "Click to take it off." })
            else
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.slot.name)
                GameTooltip:AddLine("Empty", 0.6, 0.6, 0.6)
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        s.slots[i] = b
    end
    -- stats, between the two columns of slots
    s.stats = {}
    for i = 1, 15 do
        local l = Label(s, "GameFontNormalSmall")
        l:SetPoint("TOPLEFT", 54, -14 - (i - 1) * 16)
        l:SetWidth(100); l:SetJustifyH("LEFT")
        local v = Label(s, "GameFontHighlightSmall")
        v:SetPoint("LEFT", l, "RIGHT", 0, 0)
        v:SetWidth(106); v:SetJustifyH("RIGHT")
        s.stats[i] = { l = l, v = v }
    end

    -- bags
    local bagTitle = Label(s, "GameFontNormal", "Backpack")
    bagTitle:SetPoint("TOPLEFT", 382, -12)
    s.bagCount = Label(s, "GameFontHighlightSmall")
    s.bagCount:SetPoint("TOPRIGHT", -18, -14)
    s.bags = {}
    for i = 1, ns.BAG_SIZE do
        local b = ItemButton(s, 40)
        b:SetPoint("TOPLEFT", 382 + ((i - 1) % 4) * 46, -34 - floor((i - 1) / 4) * 46)
        b.index = i
        b:SetScript("OnClick", function(self, button)
            if not self.item then return end
            if button == "RightButton" then
                local dlg = StaticPopup_Show("MARISCOS_SHELLCRACKER_SELL", Prog:Link(self.item), Prog:Money(self.item.sell))
                if dlg then dlg.data = self.index end
            else
                local ok, why = Prog:Equip(self.index, IsShiftKeyDown and IsShiftKeyDown())
                if ok then SFX("equip") else Err(why or "") end
                Screens:Refresh()
            end
        end)
        b:SetScript("OnEnter", function(self)
            if self.item then
                local tips = { "Left-click to equip.", "Right-click to sell." }
                local t = self.item.slot
                if t == "FINGER" or t == "TRINKET" then tips[1] = "Left-click to equip (Shift-click: the other " .. ns.ITEM_TYPES[t].name:lower() .. " slot)."
                elseif t == "1H" then tips[1] = "Left-click to equip (Shift-click: off hand, to dual wield)."
                elseif t == "2H" then tips[1] = "Left-click to equip. Uses both hands: your off hand comes off." end
                ItemTooltip(self, self.item, tips, true)
            end
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        s.bags[i] = b
    end
    s.gold = Label(s, "GameFontHighlight")
    s.gold:SetPoint("TOPRIGHT", -18, -224)
    local help = Label(s, "GameFontDisableSmall", "Bags: left-click to equip, right-click\nto sell. Shift-click: 2nd ring/trinket,\noff hand. Gear: click to take off.")
    help:SetPoint("TOPLEFT", 382, -248)
    help:SetJustifyH("LEFT")
    s.buyback = Button(s, "Buyback", 100, 22, function() Screens:Show("shop", "buyback") end)
    s.buyback:SetPoint("TOPLEFT", 382, -282)
    BackButton(s)
    s.lock = LockNote(s)

    s.refresh = function()
        local d = Prog:Data()
        for _, b in ipairs(s.slots) do b:SetItem(d.gear[b.slot.id], b.slot.tex) end
        for i, b in ipairs(s.bags) do b:SetItem(d.bags[i]) end
        s.bagCount:SetText(Prog:BagCount() .. " / " .. ns.BAG_SIZE)
        local nb = #Prog:Buyback()
        s.buyback:SetText(nb > 0 and ("Buyback (" .. nb .. ")") or "Buyback")
        s.gold:SetText(Prog:Money(d.gold))
        local M = Prog:Mods()
        local S = M.stats
        local function pct(v) return ("%s%%"):format((floor((v or 0) * 10 + 0.5) / 10)) end
        local function grey(t) return "  |cff888888(" .. t .. ")|r" end
        local rows = {
            { "Stamina", S.sta .. grey("+" .. comma(S.sta * 10) .. " hp") },
            { "Damage", S.dmg .. grey("+" .. M.weaponFlat .. " per match") },
            { "Critical Strike", S.crit .. grey(pct(S.crit * 0.1)) },
            { "Combo Power", S.combo .. grey(pct(S.combo * 0.2) .. "/cascade") },
            { "Explosive Power", S.boom .. grey(pct(S.boom * 0.5)) },
            { "Armor", S.armor .. grey("-" .. pct(M.armorRed * 100)) },
            { "Restoration", S.resto .. grey(pct(S.resto) .. " heal") },
            { "Fortune", S.fortune .. grey(pct(S.fortune * 0.5) .. " gold") },
            { "Maximum health", comma(M.maxHP) },
            { "Damage bonus", "+" .. pct((M.dmg or 0) + (M.levelDmg or 0)) },
            { "Critical chance", pct(M.crit) },
            { "Damage taken", "-" .. pct(100 - 100 * (1 - M.armorRed) * (1 - (M.armorPct or 0) / 100) * (1 - M.levelDef / 100)) },
            { "Dodge", pct(M.dodge) },
            { "Gold / drop bonus", "+" .. pct(M.gold) .. " / +" .. pct(M.drop) },
            { "Legendaries", (function() local n = 0 for _ in pairs(M.legendary) do n = n + 1 end return n > 0 and ("|cffff8000" .. n .. " equipped|r") or "-" end)() },
        }
        for i, ln in ipairs(s.stats) do ln.l:SetText(rows[i][1]); ln.v:SetText(rows[i][2]) end
        s.lock:SetShown(Prog:Locked())
    end
    return s
end

---------------------------------------------------------------------------
-- TALENTS
---------------------------------------------------------------------------
local TREE_W, ICON, COL_W, ROW_H = 188, 30, 44, 41

local function BuildTalents()
    local s = NewScreen("talents", "Talents")
    s.trees, s.buttons = {}, {}
    for ti, tree in ipairs(ns.TREES) do
        local tf = CreateFrame("Frame", nil, s)
        tf:SetSize(TREE_W, 322)
        tf:SetPoint("TOPLEFT", 6 + (ti - 1) * (TREE_W + 4), -4)
        local bg = tf:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetTexture(tree.bg); bg:SetTexCoord(0, 1, 0, 1); bg:SetAlpha(0.45)
        local shade = tf:CreateTexture(nil, "BACKGROUND", nil, 1)
        shade:SetAllPoints(); shade:SetColorTexture(0, 0, 0, 0.35)
        local ic = tf:CreateTexture(nil, "ARTWORK")
        ic:SetSize(18, 18); ic:SetPoint("TOPLEFT", 6, -5); ic:SetTexture(tree.icon)
        tf.head = Label(tf, "GameFontNormal")
        tf.head:SetPoint("LEFT", ic, "RIGHT", 6, 0)
        s.trees[ti] = tf
    end
    for _, t in ipairs(ns.TALENTS) do
        local tf = s.trees[t.tree]
        local b = CreateFrame("Button", nil, tf)
        b:SetSize(ICON, ICON)
        b:SetPoint("TOPLEFT", 14 + (t.col - 1) * COL_W, -30 - (t.tier - 1) * ROW_H)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints(); b.icon:SetTexture(t.icon)
        b.border = b:CreateTexture(nil, "OVERLAY")
        b.border:SetPoint("TOPLEFT", -2, 2); b.border:SetPoint("BOTTOMRIGHT", 2, -2)
        b.border:SetTexture(WHITE); b.border:SetDrawLayer("BACKGROUND", 2)
        local rbg = b:CreateTexture(nil, "OVERLAY")
        rbg:SetSize(26, 12); rbg:SetPoint("BOTTOMRIGHT", 8, -5); rbg:SetColorTexture(0, 0, 0, 0.85)
        b.rank = Label(b, "GameFontNormalSmall")
        b.rank:SetPoint("CENTER", rbg, "CENTER", 0, 0)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(); hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square"); hl:SetBlendMode("ADD")
        b.t = t
        b:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                if Prog:RemovePoint(self.t) then SFX("untalent") else Err(Prog:RemoveBlock(self.t) or "") end
            else
                if Prog:AddPoint(self.t) then SFX("talent") else Err(Prog:AddBlock(self.t) or "") end
            end
            Screens:Refresh()
            if self:IsMouseOver() then self:GetScript("OnEnter")(self) end
        end)
        b:SetScript("OnEnter", function(self)
            local tt = self.t
            local r = Prog:Rank(tt.id)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tt.name)
            GameTooltip:AddLine(("Rank %d/%d"):format(r, tt.max), 1, 1, 1)
            if r > 0 then GameTooltip:AddLine(Prog:TalentText(tt, r), 1, 0.82, 0, true) end
            if r < tt.max then
                if r > 0 then GameTooltip:AddLine(" "); GameTooltip:AddLine("Next rank:", 1, 1, 1) end
                GameTooltip:AddLine(Prog:TalentText(tt, r + 1), r > 0 and 1 or 1, 0.82, 0, true)
            end
            local block = Prog:AddBlock(tt)
            if block and r < tt.max then GameTooltip:AddLine(block, 1, 0.2, 0.2, true)
            elseif r < tt.max then GameTooltip:AddLine("Left-click to learn", 0, 1, 0) end
            if r > 0 and not Prog:Locked() then GameTooltip:AddLine("Right-click to unlearn", 0.6, 0.6, 0.6) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        s.buttons[#s.buttons+1] = b
    end
    s.points = Label(s, "GameFontNormal")
    s.points:SetPoint("BOTTOMLEFT", 112, 13)
    local reset = Button(s, "Reset talents", 120, 22, function()
        if Prog:Locked() then Err("Talents are locked during a run.") return end
        if Prog:PointsSpent() > 0 then StaticPopup_Show("MARISCOS_SHELLCRACKER_RESETTALENTS") end
    end)
    reset:SetPoint("BOTTOMRIGHT", -10, 8)
    BackButton(s)
    s.lock = LockNote(s)
    s.lock:ClearAllPoints()
    s.lock:SetPoint("BOTTOMLEFT", 110, 34); s.lock:SetPoint("BOTTOMRIGHT", -10, 34)

    s.refresh = function()
        local locked = Prog:Locked()
        for ti, tf in ipairs(s.trees) do
            tf.head:SetText(("%s |cffffffff(%d)|r"):format(ns.TREES[ti].name, Prog:TreeSpent(ti)))
        end
        for _, b in ipairs(s.buttons) do
            local t = b.t
            local r = Prog:Rank(t.id)
            local open = Prog:TierOpen(t)
            local canAdd = not Prog:AddBlock(t)
            b.rank:SetText(r .. "/" .. t.max)
            b.icon:SetDesaturated(not open and r == 0)
            b.icon:SetVertexColor(1, 1, 1, (open or r > 0) and 1 or 0.6)
            if r >= t.max then
                b.rank:SetTextColor(1, 0.82, 0); b.border:SetVertexColor(1, 0.82, 0)
            elseif canAdd or r > 0 then
                b.rank:SetTextColor(0.1, 1, 0.1); b.border:SetVertexColor(0.1, 0.8, 0.1)
            else
                b.rank:SetTextColor(0.6, 0.6, 0.6); b.border:SetVertexColor(0.3, 0.3, 0.3)
            end
        end
        local free = Prog:PointsFree()
        if Prog:Level() < ns.TALENT_START then
            s.points:SetText("Talent points start at level " .. ns.TALENT_START .. ".")
        else
            s.points:SetText(("Points to spend: |cff00ff00%d|r   |cff888888(%d spent)|r"):format(free, Prog:PointsSpent()))
        end
        s.lock:SetShown(locked)
    end
    return s
end

---------------------------------------------------------------------------
-- SHOP
---------------------------------------------------------------------------
local function BuildShop()
    local s = NewScreen("shop", "Shop")
    s.tab = "buy"
    s.intro = Label(s, "GameFontHighlight")
    s.intro:SetPoint("TOPLEFT", 16, -12)
    s.tabBuy = Button(s, "Merchant", 100, 22, function() s.tab = "buy"; Screens:Refresh() end)
    s.tabBuy:SetPoint("TOPRIGHT", -114, -6)
    s.tabBack = Button(s, "Buyback", 100, 22, function() s.tab = "buyback"; Screens:Refresh() end)
    s.tabBack:SetPoint("TOPRIGHT", -10, -6)

    -- merchant: 6 big cards
    s.cards = {}
    for i = 1, Prog.SHOP_SIZE do
        local c = CreateFrame("Frame", nil, s)
        c:SetSize(276, 72)
        c:SetPoint("TOPLEFT", 12 + ((i - 1) % 2) * 284, -38 - floor((i - 1) / 2) * 80)
        local bg = c:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.05)
        c.btn = ItemButton(c, 44)
        c.btn:SetPoint("LEFT", 10, 0)
        c.btn:SetScript("OnEnter", function(self) if self.item then ItemTooltip(self, self.item, nil, true) end end)
        c.btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        c.name = Label(c, "GameFontNormal")
        c.name:SetPoint("TOPLEFT", c.btn, "TOPRIGHT", 10, -2)
        c.name:SetWidth(200); c.name:SetJustifyH("LEFT")
        if c.name.SetWordWrap then c.name:SetWordWrap(false) end
        c.sub = Label(c, "GameFontDisableSmall")
        c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
        c.price = Label(c, "GameFontHighlight")
        c.price:SetPoint("BOTTOMLEFT", c.btn, "BOTTOMRIGHT", 10, 2)
        c.buy = Button(c, "Buy", 60, 22, function()
            local ok, why = Prog:Buy(i)
            if ok then SFX("coinsBig") else Err(why or "") end
            Screens:Refresh()
        end)
        c.buy:SetPoint("BOTTOMRIGHT", -8, 8)
        c.sold = Label(c, "GameFontDisable", "Sold")
        c.sold:SetPoint("CENTER")
        s.cards[i] = c
    end

    -- buyback: the last 12 items you sold, 3 x 4 small cards
    s.back = {}
    for i = 1, ns.BUYBACK_SIZE do
        local c = CreateFrame("Frame", nil, s)
        c:SetSize(186, 58)
        c:SetPoint("TOPLEFT", 12 + ((i - 1) % 3) * 190, -38 - floor((i - 1) / 3) * 62)
        local bg = c:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.05)
        c.btn = ItemButton(c, 36)
        c.btn:SetPoint("LEFT", 6, 0)
        c.btn:SetScript("OnEnter", function(self) if self.item then ItemTooltip(self, self.item, { "Click Buy back to get it back." }) end end)
        c.btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        c.name = Label(c, "GameFontNormalSmall")
        c.name:SetPoint("TOPLEFT", c.btn, "TOPRIGHT", 6, -1)
        c.name:SetWidth(136); c.name:SetJustifyH("LEFT")
        if c.name.SetWordWrap then c.name:SetWordWrap(false) end
        c.price = Label(c, "GameFontHighlightSmall")
        c.price:SetPoint("BOTTOMLEFT", c.btn, "BOTTOMRIGHT", 6, 0)
        c.buy = Button(c, "Buy back", 64, 18, function()
            local ok, why = Prog:BuyBack(i)
            if ok then SFX("coinsBig") else Err(why or "") end
            Screens:Refresh()
        end)
        c.buy:SetPoint("BOTTOMRIGHT", -4, 4)
        s.back[i] = c
    end
    s.empty = Label(s, "GameFontDisable", "Nothing sold yet. Items you sell appear here so you can buy them back.")
    s.empty:SetPoint("CENTER", 0, 20)

    s.gold = Label(s, "GameFontHighlight")
    s.gold:SetPoint("BOTTOMLEFT", 112, 13)
    s.restock = Button(s, "Restock", 190, 22, function()
        local ok, why = Prog:PaidRestock()
        if ok then SFX("coinsBig") else Err(why or "") end
        Screens:Refresh()
    end)
    s.restock:SetPoint("BOTTOMRIGHT", -10, 8)
    s.restock:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Restock now")
        GameTooltip:AddLine("Costs " .. Prog:Money(Prog:RestockCost()) .. ". Up to " .. Prog.MAX_RESTOCKS .. " times per tide; "
            .. Prog:RestocksLeft() .. " left. The shop also gets new stock for free whenever a new tide begins.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    s.restock:SetScript("OnLeave", function() GameTooltip:Hide() end)
    BackButton(s)
    s.refresh = function()
        local gold = Prog:Gold()
        local buying = s.tab ~= "buyback"
        local bb = Prog:Buyback()
        s.tabBack:SetText(#bb > 0 and ("Buyback (" .. #bb .. ")") or "Buyback")
        if buying then s.tabBuy:Disable(); s.tabBack:Enable() else s.tabBuy:Enable(); s.tabBack:Disable() end
        s.intro:SetText(buying and "New stock with every tide." or "Changed your mind? Buy back what you sold, for what you got.")
        local stock = Prog:Shop()
        for i, c in ipairs(s.cards) do
            local item = stock[i]
            c:SetShown(buying)
            if item then
                c.btn:SetItem(item); c.btn:Show()
                c.name:SetText(Prog:Color(item) .. item.name .. "|r")
                c.sub:SetText(ns.QUALITY[item.q].name .. " " .. ns.ITEM_TYPES[item.slot].name .. "  ·  Item Level " .. item.ilvl)
                c.price:SetText(Prog:Money(item.price))
                c.price:SetTextColor(1, gold >= item.price and 1 or 0.3, gold >= item.price and 1 or 0.3)
                c.buy:Show(); c.sold:Hide()
                if gold >= item.price and Prog:BagCount() < ns.BAG_SIZE then c.buy:Enable() else c.buy:Disable() end
            else
                c.btn:Hide(); c.name:SetText(""); c.sub:SetText(""); c.price:SetText("")
                c.buy:Hide(); c.sold:Show()
            end
        end
        for i, c in ipairs(s.back) do
            local item = bb[i]
            c:SetShown(not buying and item ~= nil)
            if item then
                c.btn:SetItem(item)
                c.name:SetText(Prog:Color(item) .. item.name .. "|r")
                c.price:SetText(Prog:Money(item.sell))
                if gold >= item.sell and Prog:BagCount() < ns.BAG_SIZE then c.buy:Enable() else c.buy:Disable() end
            end
        end
        s.empty:SetShown(not buying and #bb == 0)
        s.restock:SetShown(buying)
        s.gold:SetText("Your money: " .. Prog:Money(gold) .. "    |cff888888Bags " .. Prog:BagCount() .. "/" .. ns.BAG_SIZE .. "|r")
        local left = Prog:RestocksLeft()
        if left > 0 then
            s.restock:SetText(("Restock %s (%d/%d)"):format(Prog:Money(Prog:RestockCost()), left, Prog.MAX_RESTOCKS))
            s.restock:Enable()
        else
            s.restock:SetText("Restock: next tide")
            s.restock:Disable()
        end
    end
    return s
end

---------------------------------------------------------------------------
local BUILDERS = { menu = BuildMenu, character = BuildCharacter, talents = BuildTalents, shop = BuildShop }

function Screens:Show(name, tab)
    for n, fr in pairs(self.frames) do if n ~= name then fr:Hide() end end
    local s = self.frames[name] or BUILDERS[name]()
    if name == "shop" then s.tab = tab or "buy" end
    self.current = name
    ns.Game.paused = true
    ns.UI:UpdateHeader(s.screenTitle)
    s:Show()
    if s.refresh then s.refresh() end
end

function Screens:HideAll()
    for _, fr in pairs(self.frames) do fr:Hide() end
    self.current = nil
    ns.UI.headerTitle = nil
    if ns.Game.wave then ns.UI:UpdateHeader() end
end

function Screens:Refresh()
    local s = self.current and self.frames[self.current]
    if s and s:IsShown() and s.refresh then s.refresh() end
    ns.UI:UpdateHeader()
end
