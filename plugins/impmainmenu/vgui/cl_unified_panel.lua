local THEME = ix.ui.THEME
local Scale = ix.ui.Scale
local IsMenuClosing = ix.ui.IsMenuClosing

-- ═══════════════════════════════════════════════════════════════════════════════
-- ixUnifiedCharPanel — Merges "You" + "Inventory" into a single tab.
-- Visual language: VANIR main menu style — dark field, large name as wordmark,
-- gold-bar faction subtitle, thin accent lines, corner HUD decorations.
-- ═══════════════════════════════════════════════════════════════════════════════

local PANEL = {}

function PANEL:Init()
    self:Dock(FILL)

    local padding = Scale(24)
    local rightFixedW = Scale(360)

    self:DockPadding(padding, padding, padding, padding)

    local char = LocalPlayer():GetCharacter()
    if (!char) then return end

    -- Gather identity info once (stored for Paint/PaintOver reuse)
    local faction = ix.faction.indices[char:GetFaction()]
    self.factionName = faction and string.upper(faction.name) or "UNKNOWN"
    local class = ix.class.list[char:GetClass()]
    self.subtitleText = self.factionName
    if (class) then
        self.subtitleText = self.subtitleText .. "  ·  " .. string.upper(class.name)
    end
    self.charName = char:GetName()

    -- ─── TOP HEADER: Character name + faction/class (full-width, like main menu) ─
    local headerH = Scale(88)
    self.header = self:Add("EditablePanel")
    self.header:Dock(TOP)
    self.header:SetTall(headerH)
    self.header:DockMargin(0, 0, 0, Scale(14))
    self.header:SetMouseInputEnabled(true)
    self.header:SetCursor("hand")
    self.header._hover = false
    self.header.OnCursorEntered = function(pnl) pnl._hover = true end
    self.header.OnCursorExited  = function(pnl) pnl._hover = false end
    self.header.OnMousePressed  = function(pnl, code)
        if (code == MOUSE_LEFT) then
            ix.command.Send("CharSetName", self.charName, "")
        end
    end
    self.header.Paint = function(pnl, w, h)
        -- Hover tint
        if (pnl._hover) then
            surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 8)
            surface.DrawRect(0, 0, w, h)
        end

        local nameY = h * 0.38

        -- Large character name centered (analogous to "VANIR" wordmark)
        draw.SimpleText(self.charName, "ixImpMenuTitle", w * 0.5, nameY, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Gold bar + faction/class subtitle (analogous to "IMPERIAL ROLEPLAY" bar)
        surface.SetFont("ixImpMenuLabel")
        local tw = surface.GetTextSize(self.subtitleText)
        local barPad = Scale(14)
        local barH   = Scale(15)
        local barY   = nameY + Scale(32)
        local barX   = w * 0.5 - tw * 0.5 - barPad

        surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 210)
        surface.DrawRect(barX, barY - barH * 0.5, tw + barPad * 2, barH)
        draw.SimpleText(self.subtitleText, "ixImpMenuLabel", w * 0.5, barY, Color(0, 0, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Thin gold separator at the very bottom of header
        surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 55)
        surface.DrawRect(0, h - 1, w, 1)
    end

    -- ─── RIGHT COLUMN: Info + Stats + Attributes + Plugin Sections ────────────
    self.rightPanel = self:Add("EditablePanel")
    self.rightPanel:Dock(RIGHT)
    self.rightPanel:SetWide(rightFixedW)
    self.rightPanel:DockMargin(padding, 0, 0, 0)
    local rightHeaderH = Scale(22)
    self.rightPanel.Paint = function(pnl, w, h)
        -- Subtle background
        surface.SetDrawColor(0, 0, 0, 80)
        surface.DrawRect(0, 0, w, h)
        -- Gold bar header (matching FIELD INVENTORY style)
        surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 210)
        surface.DrawRect(0, 0, w, rightHeaderH)
        -- Header text (black on gold)
        draw.SimpleText("OPERATIVE STATUS", "ixImpMenuDiag", Scale(8), rightHeaderH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        -- Pulsing Aurebesh on right side of header
        local pulse = math.abs(math.sin(CurTime() * 1.5))
        draw.SimpleText("MONITORING", "ixImpMenuAurebesh", w - Scale(8), rightHeaderH * 0.5, Color(0, 0, 0, math.Round(150 + pulse * 105)), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    self.rightScroll = self.rightPanel:Add("DScrollPanel")
    self.rightScroll:Dock(FILL)
    self.rightScroll:DockMargin(Scale(8), rightHeaderH + Scale(6), Scale(8), Scale(8))
    self.rightScroll.Paint = function() end
    ix.ui.ApplyScrollbarStyle(self.rightScroll)

    self:PopulateRightPanel(char)

    -- ─── LEFT COLUMN: Inventory Grid + Weight ────────────────────────────────
    self.inventoryGrid = self:Add("ixInventoryGridPanel")
    self.inventoryGrid:DockMargin(0, 0, 0, 0)
    self.inventoryGrid:SetupInventory(self, rightFixedW, padding)

    -- ─── CENTER COLUMN: 3D Character Model ───────────────────────────────────
    self.modelPanel = self:Add("ixCharacterModelPanel")
    self.modelPanel:DockMargin(Scale(10), 0, Scale(10), 0)
    self.modelPanel:SetupModel()
end

function PANEL:PaintOver(w, h)
    if (!self.charName) then return end

    local pad   = Scale(10)
    local pulse = math.abs(math.sin(CurTime() * 0.9))
    local aAlpha = math.Round(50 + pulse * 70)

    -- Top-left: operative node designation
    draw.SimpleText(
        "OPERATIVE NODE // " .. self.factionName,
        "ixImpMenuDiag", pad, pad,
        THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
    )

    -- Top-right: user identifier
    draw.SimpleText(
        "USR // " .. string.upper(self.charName),
        "ixImpMenuDiag", w - pad, pad,
        THEME.textMuted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP
    )

    -- Bottom-left: pulsing Aurebesh decoration
    draw.SimpleText(
        "MONITORING STATUS",
        "ixImpMenuAurebesh", pad, h - pad,
        Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, aAlpha),
        TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM
    )

    -- Bottom-right: pulsing Aurebesh decoration
    draw.SimpleText(
        "STATUS NOMINAL",
        "ixImpMenuAurebesh", w - pad, h - pad,
        Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, aAlpha),
        TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM
    )
end

function PANEL:PopulateRightPanel(char)
    local scroll = self.rightScroll
    local rowIdx = 0

    -- Collect background data (rendered below biography under PERSONNEL DETAILS)
    local backgrounds = char:GetBackgrounds() or {}
    local backgroundText = ""
    for k, _ in pairs(backgrounds) do
        local bck = ix.backgrounds[k]
        if bck then backgroundText = backgroundText .. bck.name .. ", " end
    end
    if (backgroundText != "") then backgroundText = backgroundText:sub(1, -3) end

    local function AddBackgroundLabel()
        if (backgroundText == "") then return end
        local bckLabel = scroll:Add("DLabel")
        bckLabel:SetText("BACKGROUND:  " .. backgroundText)
        bckLabel:SetFont("ixImpMenuDiag")
        bckLabel:Dock(TOP)
        bckLabel:SetTextColor(THEME.textMuted)
        bckLabel:DockMargin(0, Scale(4), 0, 0)
        bckLabel:SetMouseInputEnabled(true)

        local descList = {}
        for k, _ in pairs(backgrounds) do
            local bck = ix.backgrounds[k]
            if (bck and bck.description) then
                table.insert(descList, bck.name .. ":\n" .. bck.description)
            end
        end
        if (#descList > 0) then
            local tooltipText = table.concat(descList, "\n\n")
            bckLabel:SetHelixTooltip(function(tooltip)
                local label = tooltip:AddRowAfter("name", "description")
                label:SetText(tooltipText)
                label:SetFont("ixImpMenuLabel")
                label:SizeToContents()
            end)
        end
        bckLabel.Paint = function(this, w, h)
            if this:IsHovered() then
                surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 12)
                surface.DrawRect(0, 0, w, h)
            end
        end
    end

    -- ─── PARAMETERS section ──────────────────────────────────────────────────
    ix.ui.CreateSectionHeader(scroll, "PARAMETERS")
    self.statsPanel = scroll:Add("ixStatsPanel")

    -- ─── PERSONNEL DETAILS section ───────────────────────────────────────────
    ix.ui.CreateSectionHeader(scroll, "PERSONNEL DETAILS")

    rowIdx = rowIdx + 1
    ix.ui.CreateDataRow(scroll, "CREDITS", ix.currency.Get(char:GetMoney()), rowIdx)

    rowIdx = rowIdx + 1
    ix.ui.CreateDataRow(scroll, "FACTION", self.factionName, rowIdx)

    local class = ix.class.list[char:GetClass()]
    if (class) then
        rowIdx = rowIdx + 1
        ix.ui.CreateDataRow(scroll, "CLASS", class.name, rowIdx)
    end

    -- Biography (click to edit)
    local desc = scroll:Add("DLabel")
    desc:SetText(char:GetDescription())
    desc:SetFont("ixImpMenuLabel")
    desc:SetAutoStretchVertical(true)
    desc:SetWrap(true)
    desc:Dock(TOP)
    desc:SetTextColor(THEME.textMuted)
    desc:DockMargin(0, Scale(6), 0, 0)
    desc:SetMouseInputEnabled(true)
    desc:SetCursor("hand")
    desc._hover = false
    desc.OnCursorEntered = function(this) this._hover = true end
    desc.OnCursorExited  = function(this) this._hover = false end
    desc.Paint = function(this, w, h)
        if (this._hover) then
            surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 12)
            surface.DrawRect(0, 0, w, h)
        end
    end
    desc.OnMousePressed = function(this, code)
        if (code == MOUSE_LEFT) then ix.command.Send("CharDesc") end
    end

    -- Background (under biography, within PERSONNEL DETAILS)
    AddBackgroundLabel()

    -- ─── ATTRIBUTES section ──────────────────────────────────────────────────
    if (table.Count(ix.attributes.list) > 0) then
        self.attrRenderer = scroll:Add("ixAttributeRenderer")
        self.attrRenderer:Populate(char)
    end

    -- ─── Dynamic plugin sections (hook: PopulateCharacterSections) ───────────
    self.dynamicSections = scroll:Add("ixDynamicSections")
    self.dynamicSections:Populate(char)
end

function PANEL:OnRemove()
    if (IsValid(self.modelPanel)) then
        self.modelPanel:Remove()
    end
end

vgui.Register("ixUnifiedCharPanel", PANEL, "EditablePanel")


-- ═══════════════════════════════════════════════════════════════════════════════
-- TAB REGISTRATION — keeps "you" key so unlocktrees Sections still attach.
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("CreateMenuButtons", "ixUnifiedCharPanel", function(tabs)
    if (hook.Run("CanPlayerViewInventory") == false) then return end

    tabs["inv"] = nil

    tabs["you"] = {
        bDefault = true,
        Create = function(info, container)
            local panel = container:Add("ixUnifiedCharPanel")
            panel:Dock(FILL)
        end,
    }
end)
