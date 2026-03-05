--- USMS Cross-Faction Intel Panel
-- Allows authorized players to view other factions' unit overview data.

local THEME = {
    background = Color(10, 10, 10, 255),
    frame = Color(191, 148, 53, 255),
    frameSoft = Color(191, 148, 53, 120),
    text = Color(235, 235, 235, 255),
    textMuted = Color(168, 168, 168, 140),
    accent = Color(191, 148, 53, 255),
    accentSoft = Color(191, 148, 53, 220),
    buttonBg = Color(16, 16, 16, 255),
    buttonBgHover = Color(26, 26, 26, 255),
    panelBg = Color(12, 12, 12, 255),
    rowEven = Color(14, 14, 14, 255),
    rowOdd = Color(18, 18, 18, 255),
    rowHover = Color(24, 22, 14, 255),
    danger = Color(180, 60, 60, 255),
    ready = Color(60, 170, 90, 255),
    supply = Color(80, 140, 200, 255)
}

local function Scale(value)
    return math.max(1, math.Round(value * (ScrH() / 900)))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- INTEL PANEL
-- ═══════════════════════════════════════════════════════════════════════════════

local PANEL = {}

function PANEL:Init()
    self.selectedUnitID = nil

    -- Header
    self.headerLabel = self:Add("DLabel")
    self.headerLabel:Dock(TOP)
    self.headerLabel:SetTall(Scale(28))
    self.headerLabel:DockMargin(Scale(8), Scale(4), 0, Scale(2))
    self.headerLabel:SetFont("ixImpMenuSubtitle")
    self.headerLabel:SetTextColor(THEME.accent)
    self.headerLabel:SetText("INTELLIGENCE OVERVIEW")

    -- Refresh button
    self.actionBar = self:Add("EditablePanel")
    self.actionBar:Dock(TOP)
    self.actionBar:SetTall(Scale(32))
    self.actionBar:DockMargin(0, 0, 0, Scale(4))
    self.actionBar.Paint = function() end

    local refreshBtn = self.actionBar:Add("DButton")
    refreshBtn:SetText("")
    refreshBtn:Dock(LEFT)
    refreshBtn:SetWide(Scale(120))
    refreshBtn:DockMargin(Scale(4), 0, Scale(4), 0)
    refreshBtn.DoClick = function()
        self:RequestIntel()
    end
    refreshBtn.Paint = function(s, w, h)
        local bg = s:IsHovered() and THEME.buttonBgHover or THEME.buttonBg
        surface.SetDrawColor(bg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("REFRESH INTEL", "ixImpMenuStatus", w * 0.5, h * 0.5, THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Split: unit cards (left) + detail (right)
    self.splitContainer = self:Add("EditablePanel")
    self.splitContainer:Dock(FILL)
    self.splitContainer.Paint = function() end

    self.listPanel = self.splitContainer:Add("DScrollPanel")
    self.listPanel:Dock(LEFT)
    self.listPanel:DockMargin(0, 0, Scale(4), 0)
    self.listPanel.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
    end

    local sbar = self.listPanel:GetVBar()
    sbar:SetWide(Scale(4))
    sbar.Paint = function() end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, 0, w, h)
    end

    self.detailPanel = self.splitContainer:Add("EditablePanel")
    self.detailPanel:Dock(FILL)
    self.detailPanel.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
    end

    self.detailLabel = self.detailPanel:Add("DLabel")
    self.detailLabel:Dock(TOP)
    self.detailLabel:SetTall(Scale(28))
    self.detailLabel:DockMargin(Scale(8), Scale(4), 0, Scale(4))
    self.detailLabel:SetFont("ixImpMenuSubtitle")
    self.detailLabel:SetTextColor(THEME.accent)
    self.detailLabel:SetText("< SELECT A UNIT >")

    self.detailScroll = self.detailPanel:Add("DScrollPanel")
    self.detailScroll:Dock(FILL)
    self.detailScroll:DockMargin(Scale(4), 0, Scale(4), Scale(4))

    -- Listen for intel updates
    hook.Add("USMSIntelUpdated", self, function(s, unitID)
        s:RebuildUnitList()
    end)

    -- Request intel data for known factions
    self:RequestIntel()
    self:RebuildUnitList()
end

function PANEL:OnRemove()
    hook.Remove("USMSIntelUpdated", self)
end

function PANEL:PerformLayout(w, h)
    self.listPanel:SetWide(w * 0.35)
end

function PANEL:RequestIntel()
    -- Request intel for each known faction's units
    -- We use roster_request equivalents — the server will filter by USMSCanViewIntel
    local intelUnits = ix.usms.clientData.intelUnits or {}

    -- Request any already-known units to refresh
    for unitID, _ in pairs(intelUnits) do
        ix.usms.Request("intel_roster_request", {unitID = unitID})
    end

    -- Also try to discover units — request our own unit's roster (which we already have)
    -- and request any unit IDs we might know about
    -- For discovery, we rely on the server sending intel updates
    -- Server admins/factions configured with canViewAllRosters will get data

    -- Try all possible unit IDs up to a reasonable ceiling
    local maxID = 20
    for i = 1, maxID do
        if (!intelUnits[i]) then
            -- Only request if not our own unit
            local myUnit = ix.usms.clientData.unit
            if (!myUnit or myUnit.id != i) then
                ix.usms.Request("intel_roster_request", {unitID = i})
            end
        end
    end
end

function PANEL:RebuildUnitList()
    self.listPanel:Clear()

    local intelUnits = ix.usms.clientData.intelUnits or {}
    local myUnit = ix.usms.clientData.unit
    local sorted = {}

    for unitID, data in pairs(intelUnits) do
        -- Don't show our own unit in intel (we have full access already)
        if (myUnit and myUnit.id == unitID) then continue end
        table.insert(sorted, data)
    end

    table.sort(sorted, function(a, b) return (a.name or "") < (b.name or "") end)

    for _, unitData in ipairs(sorted) do
        local card = self.listPanel:Add("EditablePanel")
        card:Dock(TOP)
        card:SetTall(Scale(56))
        card:DockMargin(Scale(4), Scale(2), Scale(4), Scale(2))
        card:SetMouseInputEnabled(true)
        card.unitData = unitData

        card.OnMousePressed = function(s, code)
            if (code == MOUSE_LEFT) then
                self.selectedUnitID = s.unitData.id
                self:RebuildDetail()
            end
        end

        card.OnCursorEntered = function(s) s.bHovered = true end
        card.OnCursorExited = function(s) s.bHovered = false end

        card.Paint = function(s, w, h)
            local selected = (self.selectedUnitID == s.unitData.id)
            local bg = s.bHovered and THEME.buttonBgHover or THEME.buttonBg
            surface.SetDrawColor(bg)
            surface.DrawRect(0, 0, w, h)

            if (selected) then
                surface.SetDrawColor(THEME.accent)
                surface.DrawRect(0, 0, Scale(3), h)
            end

            surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 40)
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            local pad = Scale(10)
            draw.SimpleText(s.unitData.name or "Unknown", "ixImpMenuButton", pad, Scale(8), THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            local statusText = ix.usms.GetResourceStatus(s.unitData.resources or 0, s.unitData.resourceCap or 1)
            draw.SimpleText(
                (s.unitData.memberCount or 0) .. " personnel  |  Supply: " .. statusText,
                "ixImpMenuDiag", pad, Scale(30), THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
            )
        end
    end

    if (#sorted == 0) then
        local lbl = self.listPanel:Add("DLabel")
        lbl:Dock(TOP)
        lbl:SetTall(Scale(40))
        lbl:DockMargin(Scale(8), Scale(8), 0, 0)
        lbl:SetFont("ixImpMenuDiag")
        lbl:SetTextColor(THEME.textMuted)
        lbl:SetText("No intel available.")
    end
end

function PANEL:RebuildDetail()
    self.detailScroll:Clear()

    if (!self.selectedUnitID) then
        self.detailLabel:SetText("< SELECT A UNIT >")
        return
    end

    local unitData = ix.usms.clientData.intelUnits[self.selectedUnitID]
    if (!unitData) then
        self.detailLabel:SetText("< UNIT NOT FOUND >")
        return
    end

    self.detailLabel:SetText(unitData.name or "Unknown")

    -- Unit summary
    local infoLines = {
        {"Personnel", tostring(unitData.memberCount or 0)},
        {"Supply Status", ix.usms.GetResourceStatus(unitData.resources or 0, unitData.resourceCap or 1)},
    }

    for i, line in ipairs(infoLines) do
        local row = self.detailScroll:Add("EditablePanel")
        row:Dock(TOP)
        row:SetTall(Scale(22))
        row:DockMargin(Scale(4), 0, Scale(4), 0)
        row.Paint = function(s, w, h)
            local bg = (i % 2 == 0) and THEME.rowEven or THEME.rowOdd
            surface.SetDrawColor(bg)
            surface.DrawRect(0, 0, w, h)
            draw.SimpleText(line[1] .. ":", "ixImpMenuDiag", Scale(8), h * 0.5, THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(line[2], "ixImpMenuDiag", w - Scale(8), h * 0.5, THEME.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    -- Note about limited visibility
    local note = self.detailScroll:Add("DLabel")
    note:Dock(TOP)
    note:SetTall(Scale(40))
    note:DockMargin(Scale(8), Scale(12), Scale(8), 0)
    note:SetFont("ixImpMenuDiag")
    note:SetTextColor(THEME.textMuted)
    note:SetText("Intel data is limited to authorized overview. Detailed roster access requires faction clearance.")
    note:SetWrap(true)
    note:SetAutoStretchVertical(true)
end

function PANEL:Paint(w, h)
end

vgui.Register("ixUSMSIntelPanel", PANEL, "EditablePanel")
