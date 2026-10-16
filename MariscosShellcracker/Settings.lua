-- Marisco's Shellcracker - settings window (opens beside the game window)
local _, ns = ...

local S = {}
ns.Settings = S
local win

local function Check(parent, label, tip, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    local text = cb.text or cb.Text
    if not text then
        text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    end
    text:SetFontObject("GameFontHighlight")
    text:SetText(label)
    cb.label = text
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        if PlaySound and SOUNDKIT then
            pcall(PlaySound, self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        end
    end)
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label)
        GameTooltip:AddLine(tip, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cb.Refresh = function(self) self:SetChecked(get()) end
    return cb
end

local function Slider(parent, label, minV, maxV, get, set)
    local ok, sl = pcall(CreateFrame, "Slider", "MariscosShellcrackerDurationSlider", parent, "OptionsSliderTemplate")
    if not ok or not sl then
        sl = CreateFrame("Slider", nil, parent)
        sl:SetOrientation("HORIZONTAL")
        sl:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        local bg = sl:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("LEFT", 0, 0); bg:SetPoint("RIGHT", 0, 0); bg:SetHeight(6)
        bg:SetColorTexture(0.2, 0.2, 0.2, 0.9)
    end
    sl:SetSize(180, 16)
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(1)
    if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
    -- the template's own labels: low/high ends and the title
    local low = sl.Low or (sl.GetName and sl:GetName() and _G[sl:GetName() .. "Low"])
    local high = sl.High or (sl.GetName and sl:GetName() and _G[sl:GetName() .. "High"])
    if type(low) == "table" then low:SetText(minV .. " s") end
    if type(high) == "table" then high:SetText(maxV .. " s") end
    local title = sl.Text or (sl.GetName and sl:GetName() and _G[sl:GetName() .. "Text"])
    if type(title) ~= "table" then
        title = sl:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("BOTTOM", sl, "TOP", 0, 3)
    end
    title:SetFontObject("GameFontHighlight")
    local function show(v) title:SetText(("%s: |cffffd100%d s|r"):format(label, v)) end
    sl:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        set(v); show(v)
    end)
    sl.Refresh = function(self) local v = get(); self:SetValue(v); show(v) end
    return sl
end

local function Build()
    local main = ns.UI:GetFrame()
    local ok, f = pcall(CreateFrame, "Frame", "MariscosShellcrackerSettings", main, "BasicFrameTemplateWithInset")
    if not ok or not f then f = CreateFrame("Frame", "MariscosShellcrackerSettings", main, BackdropTemplateMixin and "BackdropTemplate") end
    f:SetSize(236, 278)
    f:SetPoint("TOPLEFT", main, "TOPRIGHT", 4, -24)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:EnableMouse(true)
    local title = f.TitleText or (f.TitleContainer and f.TitleContainer.TitleText)
    if not title then
        title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -5)
    end
    title:SetText("Shellcracker Settings")

    local head1 = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head1:SetPoint("TOPLEFT", 16, -34)
    head1:SetText("Sound")
    f.sound = Check(f, "Sound effects", "All of Shellcracker's sounds: gems, explosions, hits and warnings.",
        function() return ns.db.sound end, function(v) ns.db.sound = v end)
    f.sound:SetPoint("TOPLEFT", head1, "BOTTOMLEFT", -4, -4)
    f.music = Check(f, "Play music", "Plays the songs from World of Warcraft's inns, one after another, while the game window is open. Your zone music is paused meanwhile and comes back when you close the window. Volume: the game's Ambience slider.",
        function() return ns.db.music end,
        function(v)
            ns.db.music = v
            ns.UI:UpdateMusic()
        end)
    f.music:SetPoint("TOPLEFT", f.sound, "BOTTOMLEFT", 0, -2)

    local head2 = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head2:SetPoint("TOPLEFT", f.music, "BOTTOMLEFT", 4, -10)
    head2:SetText("Battle text")
    f.bt = Check(f, "Show battle text", "A short combat log above the game window: what you matched, the damage the makrura takes, your heals and its attacks.",
        function() return ns.db.battleText end, function(v) ns.db.battleText = v end)
    f.bt:SetPoint("TOPLEFT", head2, "BOTTOMLEFT", -4, -4)
    f.dur = Slider(f, "Text stays for", 2, 15,
        function() return ns.db.btDuration or 6 end, function(v) ns.db.btDuration = v end)
    f.dur:SetPoint("TOPLEFT", f.bt, "BOTTOMLEFT", 16, -20)
    f.move = Check(f, "Move battle text", "Shows the battle text box in cyan. Drag it where you want the text; untick to lock it.",
        function() return ns.UI.btMoving end, function(v) ns.UI:SetBattleTextMovable(v) end)
    f.move:SetPoint("TOPLEFT", f.dur, "BOTTOMLEFT", -16, -16)

    local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reset:SetSize(150, 22)
    reset:SetPoint("TOPLEFT", f.move, "BOTTOMLEFT", 26, -4)
    reset:SetText("Reset position")
    reset:SetScript("OnClick", function() ns.UI:ResetBattleText() end)

    f:SetScript("OnShow", function(self)
        self.sound:Refresh(); self.music:Refresh(); self.bt:Refresh(); self.move:Refresh(); self.dur:Refresh()
    end)
    -- closing the settings locks the battle text again
    f:SetScript("OnHide", function(self)
        if ns.UI.btMoving then ns.UI:SetBattleTextMovable(false) end
    end)
    tinsert(UISpecialFrames, "MariscosShellcrackerSettings")
    f:Hide()
    return f
end

function S:Toggle()
    ns.UI:Open()
    win = win or Build()
    if win:IsShown() then win:Hide() else win:Show() end
end

function S:Open()
    ns.UI:Open()
    win = win or Build()
    win:Show()
end

function S:Refresh() if win and win:IsShown() then win:GetScript("OnShow")(win) end end
