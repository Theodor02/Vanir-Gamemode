--- Force Management Tab Panel
-- Integrates into the skeleton tab menu, providing force-sensitive players
-- with stance/power management, keybind configuration, and LSCS client settings.
-- Replaces the disabled LSCS menu for all features except inventory and lightsaber construction.
--
-- (depends on: impmainmenu plugin, LSCS addon, theos-forcesystem)
-- @module theos-forcesystem.derma.cl_force_tab

if not CLIENT then return end

-- ─────────────────────────────────────────────
-- Theme (mirrors impmainmenu THEME)
-- ─────────────────────────────────────────────

local THEME = {
    background = Color(10, 10, 10, 240),
    frame = Color(191, 148, 53, 220),
    frameSoft = Color(191, 148, 53, 120),
    text = Color(235, 235, 235, 245),
    textMuted = Color(205, 205, 205, 140),
    accent = Color(191, 148, 53, 255),
    accentSoft = Color(191, 148, 53, 200),
    danger = Color(180, 60, 60, 255),
    ready = Color(60, 170, 90, 255),
    buttonBg = Color(16, 16, 16, 220),
    buttonBgHover = Color(26, 26, 26, 230),
    panelBg = Color(0, 0, 0, 200),
    headerBg = Color(191, 148, 53, 120),
    equipped = Color(60, 170, 90, 255),
    unequipped = Color(120, 120, 120, 180),
}

local SOUND_HOVER = "everfall/miscellaneous/ux/navigation/navigation_tab_01.mp3"
local SOUND_CLICK = "everfall/miscellaneous/ux/navigation/navigation_activate_01.mp3"

local function Scale(value)
    return math.max(1, math.Round(value * (ScrH() / 900)))
end

-- ─────────────────────────────────────────────
-- Fonts
-- ─────────────────────────────────────────────

local function CreateForceTabFonts()
    surface.CreateFont("ixForceTabHeader", {
        font = "Times New Roman",
        size = Scale(22),
        weight = 600,
        extended = true,
        antialias = true,
    })

    surface.CreateFont("ixForceTabBody", {
        font = "Roboto",
        size = Scale(13),
        weight = 500,
        extended = true,
        antialias = true,
    })

    surface.CreateFont("ixForceTabSmall", {
        font = "Roboto",
        size = Scale(11),
        weight = 400,
        extended = true,
        antialias = true,
    })

    surface.CreateFont("ixForceTabSection", {
        font = "Roboto Condensed",
        size = Scale(10),
        weight = 600,
        extended = true,
        antialias = true,
    })

    surface.CreateFont("ixForceTabKeybind", {
        font = "Roboto",
        size = Scale(12),
        weight = 600,
        extended = true,
        antialias = true,
    })
end

CreateForceTabFonts()
hook.Add("OnScreenSizeChanged", "ixForceTabFonts", CreateForceTabFonts)

-- ─────────────────────────────────────────────
-- Utility: Section Header
-- ─────────────────────────────────────────────

local function MakeSectionHeader(parent, title)
    local header = parent:Add("Panel")
    header:Dock(TOP)
    header:SetTall(Scale(24))
    header:DockMargin(0, 0, 0, Scale(4))
    header.Paint = function(_, w, h)
        surface.SetDrawColor(THEME.headerBg)
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText(string.upper(title), "ixForceTabSection", Scale(8), h * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return header
end

-- ─────────────────────────────────────────────
-- Utility: Toggle Row (checkbox-style)
-- ─────────────────────────────────────────────

local function MakeToggleRow(parent, label, bActive, onToggle)
    local row = parent:Add("DButton")
    row:Dock(TOP)
    row:SetTall(Scale(28))
    row:DockMargin(0, 0, 0, Scale(2))
    row:SetText("")
    row.active = bActive
    row.pulseOffset = math.Rand(0, 4)

    row.Paint = function(self, w, h)
        local hovered = self:IsHovered()
        local pulse = (math.sin(CurTime() * 2 + self.pulseOffset) + 1) * 0.5

        -- Background
        surface.SetDrawColor(hovered and THEME.buttonBgHover or THEME.buttonBg)
        surface.DrawRect(0, 0, w, h)

        -- Status indicator
        local statusColor = self.active and THEME.equipped or THEME.unequipped
        local indicatorW = Scale(4)
        surface.SetDrawColor(statusColor)
        surface.DrawRect(0, 0, indicatorW, h)

        -- Border
        local borderColor = self.active and THEME.accentSoft or Color(80, 80, 80, 120)
        local glow = hovered and 40 or math.Round(8 + pulse * 10)
        surface.SetDrawColor(Color(borderColor.r, borderColor.g, borderColor.b, math.min(255, borderColor.a + glow)))
        surface.DrawOutlinedRect(0, 0, w, h)

        -- Label
        draw.SimpleText(label, "ixForceTabBody", Scale(14), h * 0.5, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- Status text
        local statusText = self.active and "ACTIVE" or "INACTIVE"
        draw.SimpleText(statusText, "ixForceTabSmall", w - Scale(8), h * 0.5, statusColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    row.DoClick = function(self)
        surface.PlaySound(SOUND_CLICK)
        self.active = not self.active
        if onToggle then onToggle(self.active) end
    end

    row.OnCursorEntered = function()
        surface.PlaySound(SOUND_HOVER)
    end

    return row
end

-- ─────────────────────────────────────────────
-- Utility: Slider Row
-- ─────────────────────────────────────────────

local function MakeSliderRow(parent, label, convar, min, max, decimals)
    local row = parent:Add("Panel")
    row:Dock(TOP)
    row:SetTall(Scale(40))
    row:DockMargin(0, 0, 0, Scale(2))
    row.Paint = function(_, w, h)
        surface.SetDrawColor(THEME.buttonBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(Color(80, 80, 80, 80))
        surface.DrawOutlinedRect(0, 0, w, h)
        draw.SimpleText(label, "ixForceTabBody", Scale(8), Scale(4), THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local slider = row:Add("DNumSlider")
    slider:Dock(FILL)
    slider:DockMargin(Scale(8), Scale(16), Scale(8), Scale(2))
    slider:SetText("")
    slider:SetMin(min)
    slider:SetMax(max)
    slider:SetDecimals(decimals or 0)
    slider:SetConVar(convar)
    slider.Label:SetVisible(false)
    slider.TextArea:SetFont("ixForceTabSmall")
    slider.TextArea:SetTextColor(THEME.accent)

    return row, slider
end

-- ─────────────────────────────────────────────
-- Utility: Checkbox Row
-- ─────────────────────────────────────────────

local function MakeCheckboxRow(parent, label, convar)
    local row = parent:Add("Panel")
    row:Dock(TOP)
    row:SetTall(Scale(28))
    row:DockMargin(0, 0, 0, Scale(2))
    row.Paint = function(_, w, h)
        surface.SetDrawColor(THEME.buttonBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(Color(80, 80, 80, 80))
        surface.DrawOutlinedRect(0, 0, w, h)
    end

    local cb = row:Add("DCheckBoxLabel")
    cb:Dock(FILL)
    cb:DockMargin(Scale(8), 0, Scale(8), 0)
    cb:SetText(label)
    cb:SetFont("ixForceTabBody")
    cb:SetTextColor(THEME.text)
    cb:SetConVar(convar)

    return row, cb
end

-- ─────────────────────────────────────────────
-- Utility: Keybind Row
-- ─────────────────────────────────────────────

local function MakeKeybindRow(parent, label, getKey, setKey)
    local row = parent:Add("Panel")
    row:Dock(TOP)
    row:SetTall(Scale(30))
    row:DockMargin(0, 0, 0, Scale(2))
    row.Paint = function(_, w, h)
        surface.SetDrawColor(THEME.buttonBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(Color(80, 80, 80, 80))
        surface.DrawOutlinedRect(0, 0, w, h)
        draw.SimpleText(label, "ixForceTabBody", Scale(8), h * 0.5, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- Reset button
    local reset = row:Add("DButton")
    reset:Dock(RIGHT)
    reset:SetWide(Scale(40))
    reset:DockMargin(Scale(2), Scale(2), Scale(4), Scale(2))
    reset:SetText("")
    reset.Paint = function(self, w, h)
        local hovered = self:IsHovered()
        surface.SetDrawColor(hovered and Color(35, 10, 10, 220) or THEME.buttonBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.danger)
        surface.DrawOutlinedRect(0, 0, w, h)
        draw.SimpleText("X", "ixForceTabSmall", w * 0.5, h * 0.5, THEME.danger, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Binder
    local binder = row:Add("DBinder")
    binder:Dock(RIGHT)
    binder:SetWide(Scale(120))
    binder:DockMargin(0, Scale(2), 0, Scale(2))
    binder:SetFont("ixForceTabKeybind")
    binder:SetValue(getKey())

    binder.OnChange = function(_, num)
        setKey(num)
    end

    reset.DoClick = function()
        surface.PlaySound(SOUND_CLICK)
        setKey(KEY_NONE)
        binder:SetValue(KEY_NONE)
    end

    return row, binder
end

-- ═════════════════════════════════════════════
-- FORCE POWERS PANEL
-- ═════════════════════════════════════════════

local function BuildForcePowersPanel(container)
    local padding = Scale(12)

    local scroll = container:Add("DScrollPanel")
    scroll:Dock(FILL)
    scroll:DockMargin(padding, padding, padding, padding)

    local sbar = scroll:GetVBar()
    sbar:SetWide(Scale(4))
    sbar.Paint = function(_, w, h) end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(_, w, h)
        surface.SetDrawColor(THEME.accentSoft)
        surface.DrawRect(0, 0, w, h)
    end

    -- ── Equipped Force Powers ──
    MakeSectionHeader(scroll, "Equipped Force Powers")

    local ply = LocalPlayer()
    local inventory = ply.lscsGetInventory and ply:lscsGetInventory() or {}
    local equipped = ply.lscsGetEquipped and ply:lscsGetEquipped() or {}
    local hasPowers = false

    for index, class in pairs(inventory) do
        local item = LSCS and LSCS:ClassToItem(class)
        if not item or item.type ~= "force" then continue end

        hasPowers = true
        local isEquipped = isbool(equipped[index])

        MakeToggleRow(scroll, item.name or item.id, isEquipped, function(bActive)
            if bActive then
                ply:lscsEquipItem(index, true)
            else
                ply:lscsEquipItem(index, nil)
            end
        end)
    end

    if not hasPowers then
        local notice = scroll:Add("Panel")
        notice:Dock(TOP)
        notice:SetTall(Scale(40))
        notice:DockMargin(0, 0, 0, Scale(8))
        notice.Paint = function(_, w, h)
            draw.SimpleText("No force powers unlocked.", "ixForceTabBody", w * 0.5, h * 0.5, THEME.textMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- ── Equip / Unequip All buttons ──
    local btnBar = scroll:Add("Panel")
    btnBar:Dock(TOP)
    btnBar:SetTall(Scale(32))
    btnBar:DockMargin(0, Scale(4), 0, Scale(12))

    local equipAll = btnBar:Add("ixImpMenuButton")
    equipAll:Dock(LEFT)
    equipAll:SetWide(Scale(140))
    equipAll:SetLabel("EQUIP ALL")
    equipAll:SetStyle("accent")
    equipAll.DoClick = function()
        surface.PlaySound(SOUND_CLICK)
        for index, class in pairs(inventory) do
            local item = LSCS and LSCS:ClassToItem(class)
            if item and item.type == "force" and not isbool(equipped[index]) then
                ply:lscsEquipItem(index, true)
            end
        end
    end

    local unequipAll = btnBar:Add("ixImpMenuButton")
    unequipAll:Dock(LEFT)
    unequipAll:SetWide(Scale(140))
    unequipAll:DockMargin(Scale(6), 0, 0, 0)
    unequipAll:SetLabel("UNEQUIP ALL")
    unequipAll:SetStyle("danger")
    unequipAll.DoClick = function()
        surface.PlaySound(SOUND_CLICK)
        for index, class in pairs(inventory) do
            local item = LSCS and LSCS:ClassToItem(class)
            if item and item.type == "force" and isbool(equipped[index]) then
                ply:lscsEquipItem(index, nil)
            end
        end
    end

    -- ── Direct Force Power Keybinds ──
    MakeSectionHeader(scroll, "Direct Force Keybinds")

    local forcePowers = LSCS and LSCS.Force or {}
    local anyBindable = false

    for id, entry in SortedPairsByMemberValue(forcePowers, "name") do
        -- Only show keybinds for powers the player has in inventory
        local found = false
        for _, class in pairs(inventory) do
            if class == entry.class then
                found = true
                break
            end
        end

        if not found then continue end
        anyBindable = true

        MakeKeybindRow(scroll, entry.name or id,
            function() return entry.cmd and entry.cmd:GetInt() or KEY_NONE end,
            function(num)
                if entry.cmd then
                    entry.cmd:SetInt(num)
                    if LSCS.RefreshKeys then LSCS:RefreshKeys() end
                end
            end
        )
    end

    if not anyBindable then
        local notice = scroll:Add("Panel")
        notice:Dock(TOP)
        notice:SetTall(Scale(30))
        notice.Paint = function(_, w, h)
            draw.SimpleText("Unlock force powers to configure keybinds.", "ixForceTabSmall", w * 0.5, h * 0.5, THEME.textMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- ── Force Selector Keybinds ──
    MakeSectionHeader(scroll, "Force Selector Controls")

    local selector = LSCS and LSCS.ForceSelector
    if selector then
        MakeKeybindRow(scroll, "Selector Activate (Mouse Override)",
            function() return selector.KeyActivate:GetInt() end,
            function(num) selector.KeyActivate:SetInt(num) end
        )
        MakeKeybindRow(scroll, "Next Force Power",
            function() return selector.KeyNext:GetInt() end,
            function(num) selector.KeyNext:SetInt(num) end
        )
        MakeKeybindRow(scroll, "Previous Force Power",
            function() return selector.KeyPrev:GetInt() end,
            function(num) selector.KeyPrev:SetInt(num) end
        )
        MakeKeybindRow(scroll, "Use Force Power",
            function() return selector.KeyUse:GetInt() end,
            function(num) selector.KeyUse:SetInt(num) end
        )
    end
end

-- ═════════════════════════════════════════════
-- STANCES PANEL
-- ═════════════════════════════════════════════

local function BuildStancesPanel(container)
    local padding = Scale(12)

    local scroll = container:Add("DScrollPanel")
    scroll:Dock(FILL)
    scroll:DockMargin(padding, padding, padding, padding)

    local sbar = scroll:GetVBar()
    sbar:SetWide(Scale(4))
    sbar.Paint = function(_, w, h) end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(_, w, h)
        surface.SetDrawColor(THEME.accentSoft)
        surface.DrawRect(0, 0, w, h)
    end

    -- ── Equipped Stances ──
    MakeSectionHeader(scroll, "Combat Stances")

    local ply = LocalPlayer()
    local inventory = ply.lscsGetInventory and ply:lscsGetInventory() or {}
    local equipped = ply.lscsGetEquipped and ply:lscsGetEquipped() or {}
    local hasStances = false

    for index, class in pairs(inventory) do
        local item = LSCS and LSCS:ClassToItem(class)
        if not item or item.type ~= "stance" then continue end

        hasStances = true
        local isEquipped = isbool(equipped[index])

        local row = MakeToggleRow(scroll, item.name or item.id, isEquipped, function(bActive)
            if bActive then
                ply:lscsEquipItem(index, true)
            else
                ply:lscsEquipItem(index, nil)
            end
        end)

        -- Show stance details on hover
        if item.description then
            row:SetTooltip(item.description)
        end
    end

    if not hasStances then
        local notice = scroll:Add("Panel")
        notice:Dock(TOP)
        notice:SetTall(Scale(40))
        notice:DockMargin(0, 0, 0, Scale(8))
        notice.Paint = function(_, w, h)
            draw.SimpleText("No combat stances unlocked.", "ixForceTabBody", w * 0.5, h * 0.5, THEME.textMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- ── Equip / Unequip All buttons ──
    local btnBar = scroll:Add("Panel")
    btnBar:Dock(TOP)
    btnBar:SetTall(Scale(32))
    btnBar:DockMargin(0, Scale(4), 0, Scale(12))

    local equipAll = btnBar:Add("ixImpMenuButton")
    equipAll:Dock(LEFT)
    equipAll:SetWide(Scale(140))
    equipAll:SetLabel("EQUIP ALL")
    equipAll:SetStyle("accent")
    equipAll.DoClick = function()
        surface.PlaySound(SOUND_CLICK)
        for index, class in pairs(inventory) do
            local item = LSCS and LSCS:ClassToItem(class)
            if item and item.type == "stance" and not isbool(equipped[index]) then
                ply:lscsEquipItem(index, true)
            end
        end
    end

    local unequipAll = btnBar:Add("ixImpMenuButton")
    unequipAll:Dock(LEFT)
    unequipAll:SetWide(Scale(140))
    unequipAll:DockMargin(Scale(6), 0, 0, 0)
    unequipAll:SetLabel("UNEQUIP ALL")
    unequipAll:SetStyle("danger")
    unequipAll.DoClick = function()
        surface.PlaySound(SOUND_CLICK)
        for index, class in pairs(inventory) do
            local item = LSCS and LSCS:ClassToItem(class)
            if item and item.type == "stance" and isbool(equipped[index]) then
                ply:lscsEquipItem(index, nil)
            end
        end
    end

    -- ── Stance Info Section ──
    MakeSectionHeader(scroll, "Stance Details")

    local stances = LSCS and LSCS.Stance or {}
    for id, stanceData in SortedPairsByMemberValue(stances, "name") do
        -- Only show stances the player has in inventory
        local found = false
        for _, class in pairs(inventory) do
            if class == stanceData.class then
                found = true
                break
            end
        end

        if not found then continue end

        local infoPanel = scroll:Add("Panel")
        infoPanel:Dock(TOP)
        infoPanel:SetTall(Scale(60))
        infoPanel:DockMargin(0, 0, 0, Scale(4))

        infoPanel.Paint = function(_, w, h)
            surface.SetDrawColor(Color(16, 16, 16, 180))
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(Color(80, 80, 80, 60))
            surface.DrawOutlinedRect(0, 0, w, h)

            -- Name
            draw.SimpleText(stanceData.name or id, "ixForceTabBody", Scale(10), Scale(6), THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            -- Description
            if stanceData.description then
                draw.SimpleText(stanceData.description, "ixForceTabSmall", Scale(10), Scale(22), THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            -- Author
            if stanceData.author then
                draw.SimpleText("by " .. stanceData.author, "ixForceTabSmall", Scale(10), Scale(36), Color(140, 140, 140, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            -- Left saber indicator
            local leftText = stanceData.LeftSaberActive and "DUAL SABER" or "SINGLE SABER"
            local leftColor = stanceData.LeftSaberActive and THEME.ready or THEME.textMuted
            draw.SimpleText(leftText, "ixForceTabSection", w - Scale(10), Scale(8), leftColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end
    end
end

-- ═════════════════════════════════════════════
-- SETTINGS PANEL
-- ═════════════════════════════════════════════

local function BuildSettingsPanel(container)
    local padding = Scale(12)

    local scroll = container:Add("DScrollPanel")
    scroll:Dock(FILL)
    scroll:DockMargin(padding, padding, padding, padding)

    local sbar = scroll:GetVBar()
    sbar:SetWide(Scale(4))
    sbar.Paint = function(_, w, h) end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(_, w, h)
        surface.SetDrawColor(THEME.accentSoft)
        surface.DrawRect(0, 0, w, h)
    end

    -- ── Visual Performance ──
    MakeSectionHeader(scroll, "Visual Performance")

    MakeCheckboxRow(scroll, "Dynamic Lightsaber Lighting", "lscs_dynamiclight")
    MakeCheckboxRow(scroll, "High Quality Impact Effects", "lscs_impacteffects")
    MakeSliderRow(scroll, "Saber Trail Detail", "lscs_traildetail", 0, 100, 0)

    -- ── HUD ──
    MakeSectionHeader(scroll, "Lightsaber HUD")

    MakeCheckboxRow(scroll, "Show LSCS HUD", "lscs_drawhud")
end

-- ═════════════════════════════════════════════
-- MAIN TAB PANEL (Container with sub-pages)
-- ═════════════════════════════════════════════

local PANEL = {}

function PANEL:Init()
    self.activeSection = nil
    self.padding = Scale(12)

    -- Top navigation bar
    self.navBar = self:Add("Panel")
    self.navBar:Dock(TOP)
    self.navBar:SetTall(Scale(36))
    self.navBar:DockMargin(0, 0, 0, 0)
    self.navBar.Paint = function(_, w, h)
        surface.SetDrawColor(Color(0, 0, 0, 180))
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, h - Scale(1), w, Scale(1))
    end

    self.buttons = {}
    self.contentPanels = {}

    -- Sub-tabs
    self:AddNavButton("FORCE POWERS", "powers")
    self:AddNavButton("STANCES", "stances")
    self:AddNavButton("SETTINGS", "settings")

    -- Content area
    self.content = self:Add("Panel")
    self.content:Dock(FILL)
    self.content.Paint = function(_, w, h)
        surface.SetDrawColor(THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h)
    end

    -- Select first tab
    self:SelectSection("powers")
end

function PANEL:AddNavButton(label, section)
    local btn = self.navBar:Add("DButton")
    btn:Dock(LEFT)
    btn:SetWide(Scale(120))
    btn:SetText("")
    btn.section = section
    btn.pulseOffset = math.Rand(0, 4)

    btn.Paint = function(self, w, h)
        local selected = self:GetParent():GetParent().activeSection == self.section
        local hovered = self:IsHovered()
        local pulse = (math.sin(CurTime() * 2 + self.pulseOffset) + 1) * 0.5

        -- Background
        if selected then
            surface.SetDrawColor(Color(191, 148, 53, 40))
        elseif hovered then
            surface.SetDrawColor(THEME.buttonBgHover)
        else
            surface.SetDrawColor(Color(0, 0, 0, 0))
        end
        surface.DrawRect(0, 0, w, h)

        -- Underline
        if selected then
            surface.SetDrawColor(THEME.accent)
            surface.DrawRect(0, h - Scale(2), w, Scale(2))
        end

        -- Text
        local textColor = selected and THEME.accent or (hovered and THEME.text or THEME.textMuted)
        draw.SimpleText(label, "ixForceTabSection", w * 0.5, h * 0.5, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = function()
        surface.PlaySound(SOUND_CLICK)
        self:SelectSection(section)
    end

    btn.OnCursorEntered = function()
        surface.PlaySound(SOUND_HOVER)
    end

    self.buttons[section] = btn
end

function PANEL:SelectSection(section)
    if self.activeSection == section then return end
    self.activeSection = section

    -- Remove old content
    for _, panel in pairs(self.contentPanels) do
        if IsValid(panel) then panel:Remove() end
    end
    self.contentPanels = {}

    -- Build new content
    local panel = self.content:Add("Panel")
    panel:Dock(FILL)
    self.contentPanels[section] = panel

    if section == "powers" then
        BuildForcePowersPanel(panel)
    elseif section == "stances" then
        BuildStancesPanel(panel)
    elseif section == "settings" then
        BuildSettingsPanel(panel)
    end
end

function PANEL:Paint(w, h)
    -- Outer frame
    surface.SetDrawColor(THEME.background)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(THEME.frameSoft)
    surface.DrawOutlinedRect(0, 0, w, h)
end

vgui.Register("ixForceManagement", PANEL, "EditablePanel")

-- ═════════════════════════════════════════════
-- TAB MENU REGISTRATION
-- ═════════════════════════════════════════════

hook.Add("CreateMenuButtons", "ixForceManagement", function(tabs)
    local client = LocalPlayer()
    local char = client:GetCharacter()
    if not char then return end

    -- Only show for force-sensitive characters
    if (char:GetAttribute("force", 0) or 0) <= 0 then return end

    tabs["lightsaber"] = {
        buttonColor = THEME.accent,
        Create = function(info, container)
            local panel = container:Add("ixForceManagement")
            panel:Dock(FILL)
        end,
    }
end)
