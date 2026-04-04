local THEME        = ix.ui.THEME
local Scale        = ix.ui.Scale
local IsMenuClosing = ix.ui.IsMenuClosing

-- ═══════════════════════════════════════════════════════════════════════════════
-- ixUnifiedCharPanel — "YOU" tab
--
-- Layout (left → right):
--   [FIELD INVENTORY] [LOADOUT-L] [3D MODEL (FILL)] [LOADOUT-R] [OPERATIVE STATUS]
--
-- The two LOADOUT columns are ixCharPaneColumn panels populated from the
-- ix.charPane slot registry.  An invisible ixCharPaneController manages
-- ix.gui.charPanel so the charpane net receivers work with no changes.
-- ═══════════════════════════════════════════════════════════════════════════════

local PANEL = {}

function PANEL:Init()
    self:Dock(FILL)

    local padding     = Scale(24)
    local rightFixedW = Scale(360)
    -- Width of each equipment-slot column; must match ixCharPaneColumn:Init()
    local slotColW    = Scale(58) + Scale(4) * 2   -- SLOT_SZ + INNER_PAD * 2

    self:DockPadding(padding, padding, padding, padding)

    local char = LocalPlayer():GetCharacter()
    if (not char) then return end

    -- Cache identity strings for Paint / PaintOver
    local faction      = ix.faction.indices[char:GetFaction()]
    self.factionName   = faction and string.upper(faction.name) or "UNKNOWN"
    local class        = ix.class.list[char:GetClass()]
    self.subtitleText  = self.factionName
    if (class) then
        self.subtitleText = self.subtitleText .. "  ·  " .. string.upper(class.name)
    end
    self.charName = char:GetName()

    -- ─── TOP HEADER: character name + faction/class ───────────────────────────
    local headerH = Scale(88)
    self.header   = self:Add("EditablePanel")
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
        if (pnl._hover) then
            surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 8)
            surface.DrawRect(0, 0, w, h)
        end

        local nameY = h * 0.38
        draw.SimpleText(self.charName, "ixImpMenuTitle", w * 0.5, nameY, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        surface.SetFont("ixImpMenuLabel")
        local tw     = surface.GetTextSize(self.subtitleText)
        local barPad = Scale(14)
        local barH   = Scale(15)
        local barY   = nameY + Scale(32)
        local barX   = w * 0.5 - tw * 0.5 - barPad

        surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 210)
        surface.DrawRect(barX, barY - barH * 0.5, tw + barPad * 2, barH)
        draw.SimpleText(self.subtitleText, "ixImpMenuLabel", w * 0.5, barY, Color(0, 0, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 55)
        surface.DrawRect(0, h - 1, w, 1)
    end

    -- ─── RIGHT COLUMN: OPERATIVE STATUS (personnel details, attrs) ────────────
    self.rightPanel = self:Add("EditablePanel")
    self.rightPanel:Dock(RIGHT)
    self.rightPanel:SetWide(rightFixedW)
    self.rightPanel:DockMargin(padding, 0, 0, 0)
    local rightHeaderH = Scale(22)
    self.rightPanel.Paint = function(pnl, w, h)
        surface.SetDrawColor(0, 0, 0, 80)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 210)
        surface.DrawRect(0, 0, w, rightHeaderH)
        draw.SimpleText("OPERATIVE STATUS", "ixImpMenuLabel", Scale(8), rightHeaderH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local pulse = math.abs(math.sin(CurTime() * 1.5))
        draw.SimpleText("MONITORING", "ixImpMenuAurebesh", w - Scale(8), rightHeaderH * 0.5,
            Color(0, 0, 0, math.Round(150 + pulse * 105)), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    self.rightScroll = self.rightPanel:Add("DScrollPanel")
    self.rightScroll:Dock(FILL)
    self.rightScroll:DockMargin(Scale(8), rightHeaderH + Scale(6), Scale(8), Scale(8))
    self.rightScroll.Paint = function() end
    ix.ui.ApplyScrollbarStyle(self.rightScroll)

    self:PopulateRightPanel(char)

    -- ─── RIGHT LOADOUT COLUMN (between rightPanel and center model) ───────────
    -- Add RIGHT-docked BEFORE the left/fill elements so it sits adjacent to
    -- the OPERATIVE STATUS panel (further right takes space first in VGUI).
    self.rightSlots = self:Add("ixCharPaneColumn")
    self.rightSlots:Dock(RIGHT)
    self.rightSlots:DockMargin(Scale(6), 0, 0, 0)

    -- ─── LEFT COLUMN: FIELD INVENTORY ────────────────────────────────────────
    self.inventoryGrid = self:Add("ixInventoryGridPanel")
    self.inventoryGrid:DockMargin(0, 0, padding, 0)
    -- Pass combined right-side width so the inventory grid maxW calculation
    -- correctly excludes the right slot column as well as the status panel.
    self.inventoryGrid:SetupInventory(self, rightFixedW + slotColW, padding)

    -- ─── LEFT LOADOUT COLUMN (between inventory grid and center model) ────────
    self.leftSlots = self:Add("ixCharPaneColumn")
    self.leftSlots:Dock(LEFT)
    self.leftSlots:DockMargin(0, 0, Scale(6), 0)

    -- ─── Invisible controller — becomes ix.gui.charPanel ─────────────────────
    self.charPaneCtrl = self:Add("ixCharPaneController")

    -- ─── CENTER: 3D character model (FILL) ───────────────────────────────────
    self.modelPanel = self:Add("ixCharacterModelPanel")
    self.modelPanel:DockMargin(Scale(2), 0, Scale(2), 0)
    self.modelPanel:SetupModel()

    -- ─── Wire up the slot columns and controller ──────────────────────────────
    -- Setup() populates slot panels and registers them in controller.slots.
    self.leftSlots:Setup("left",   self.charPaneCtrl)
    self.rightSlots:Setup("right", self.charPaneCtrl)
    self.charPaneCtrl:SetupController(self.leftSlots, self.rightSlots)

    -- Load currently equipped items from the synced inventory
    self.charPaneCtrl:SetupFromCharPanel()
end

function PANEL:PaintOver(w, h)
    if (not self.charName) then return end

    local pad   = Scale(10)
    local pulse = math.abs(math.sin(CurTime() * 0.9))
    local aAlpha = math.Round(50 + pulse * 70)

    draw.SimpleText(
        "OPERATIVE NODE // " .. self.factionName,
        "ixImpMenuDiag", pad, pad,
        THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
    )

    draw.SimpleText(
        "USR // " .. string.upper(self.charName),
        "ixImpMenuDiag", w - pad, pad,
        THEME.textMuted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP
    )

    draw.SimpleText(
        "MONITORING STATUS",
        "ixImpMenuAurebesh", pad, h - pad,
        Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, aAlpha),
        TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM
    )

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

    local backgrounds    = char:GetBackgrounds() or {}
    local backgroundText = ""
    for k, _ in pairs(backgrounds) do
        local bck = ix.backgrounds[k]
        if (bck) then backgroundText = backgroundText .. bck.name .. ", " end
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
            bckLabel:SetHelixTooltip(function(tooltip)
                local label = tooltip:AddRowAfter("name", "description")
                label:SetText(table.concat(descList, "\n\n"))
                label:SetFont("ixImpMenuLabel")
                label:SizeToContents()
            end)
        end
        bckLabel.Paint = function(this, w, h)
            if (this:IsHovered()) then
                surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 12)
                surface.DrawRect(0, 0, w, h)
            end
        end
    end

    -- PERSONNEL DETAILS
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
    desc:SetContentAlignment(7)
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

    AddBackgroundLabel()

    -- ATTRIBUTES
    if (table.Count(ix.attributes.list) > 0) then
        self.attrRenderer = scroll:Add("ixAttributeRenderer")
        self.attrRenderer:Populate(char)
    end

    -- Dynamic plugin sections
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
-- TAB REGISTRATION
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
