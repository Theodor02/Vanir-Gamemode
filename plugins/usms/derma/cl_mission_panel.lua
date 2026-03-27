--- USMS Mission Panel
-- Displays active and historical missions, with creation dialog for officers/squad leaders.

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
    dangerHover = Color(200, 80, 80, 255),
    ready = Color(60, 170, 90, 255),
    warn = Color(200, 170, 60, 255),
    supply = Color(80, 140, 200, 255)
}

local function Scale(value)
    return math.max(1, math.Round(value * (ScrH() / 900)))
end

local PRIORITY_LABELS = {
    [1] = "LOW",
    [2] = "NORMAL",
    [3] = "CRITICAL"
}

local PRIORITY_COLORS = {
    [1] = THEME.textMuted,
    [2] = THEME.accent,
    [3] = THEME.danger
}

local STATUS_LABELS = {
    active = "ACTIVE",
    complete = "COMPLETE",
    cancelled = "CANCELLED"
}

local STATUS_COLORS = {
    active = THEME.ready,
    complete = THEME.supply,
    cancelled = THEME.danger
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- MISSION PANEL
-- ═══════════════════════════════════════════════════════════════════════════════

local PANEL = {}

function PANEL:Init()
    self.filterStatus = "active"
    self.selectedMission = nil

    -- Action bar
    self.actionBar = self:Add("EditablePanel")
    self.actionBar:Dock(TOP)
    self.actionBar:SetTall(Scale(36))
    self.actionBar:DockMargin(0, 0, 0, Scale(4))
    self.actionBar.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.buttonBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, h - 1, w, 1)
    end

    -- Create Mission button (permission-gated in Paint)
    self.createBtn = self.actionBar:Add("DButton")
    self.createBtn:SetText("")
    self.createBtn:Dock(LEFT)
    self.createBtn:SetWide(Scale(150))
    self.createBtn:DockMargin(Scale(4), Scale(4), Scale(4), Scale(4))
    self.createBtn.DoClick = function()
        self:OpenCreateDialog()
    end
    self.createBtn.Paint = function(s, w, h)
        local bg = s:IsHovered() and THEME.buttonBgHover or THEME.buttonBg
        surface.SetDrawColor(bg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("+ CREATE MISSION", "ixImpMenuStatus", w * 0.5, h * 0.5, THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Status filter
    self.filterLabel = self.actionBar:Add("DLabel")
    self.filterLabel:Dock(LEFT)
    self.filterLabel:DockMargin(Scale(8), 0, Scale(4), 0)
    self.filterLabel:SetWide(Scale(50))
    self.filterLabel:SetFont("ixImpMenuDiag")
    self.filterLabel:SetTextColor(THEME.textMuted)
    self.filterLabel:SetText("Show:")

    self.filterCombo = self.actionBar:Add("DComboBox")
    self.filterCombo:Dock(LEFT)
    self.filterCombo:SetWide(Scale(130))
    self.filterCombo:DockMargin(0, Scale(4), Scale(8), Scale(4))
    self.filterCombo:SetFont("ixImpMenuDiag")
    self.filterCombo:SetTextColor(THEME.text)
    self.filterCombo:SetValue("Active")
    self.filterCombo:AddChoice("Active", "active", true)
    self.filterCombo:AddChoice("Completed", "complete")
    self.filterCombo:AddChoice("Cancelled", "cancelled")
    self.filterCombo:AddChoice("All", "all")
    self.filterCombo.OnSelect = function(s, index, value, data)
        self.filterStatus = data
        self:RebuildList()
    end
    self.filterCombo.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    -- Refresh button
    self.refreshBtn = self.actionBar:Add("DButton")
    self.refreshBtn:SetText("")
    self.refreshBtn:Dock(LEFT)
    self.refreshBtn:SetWide(Scale(80))
    self.refreshBtn:DockMargin(0, Scale(4), Scale(4), Scale(4))
    self.refreshBtn.DoClick = function()
        ix.usms.Request("mission_request", {})
    end
    self.refreshBtn.Paint = function(s, w, h)
        local bg = s:IsHovered() and THEME.buttonBgHover or THEME.buttonBg
        surface.SetDrawColor(bg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("REFRESH", "ixImpMenuDiag", w * 0.5, h * 0.5, THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Split: mission list (left) + detail (right)
    self.splitContainer = self:Add("EditablePanel")
    self.splitContainer:Dock(FILL)
    self.splitContainer.Paint = function() end

    -- Mission list
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

    -- Detail panel
    self.detailPanel = self.splitContainer:Add("EditablePanel")
    self.detailPanel:Dock(FILL)
    self.detailPanel.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
    end

    self.detailScroll = self.detailPanel:Add("DScrollPanel")
    self.detailScroll:Dock(FILL)
    self.detailScroll:DockMargin(Scale(4), Scale(4), Scale(4), Scale(4))

    local sbar2 = self.detailScroll:GetVBar()
    sbar2:SetWide(Scale(4))
    sbar2.Paint = function() end
    sbar2.btnUp.Paint = function() end
    sbar2.btnDown.Paint = function() end
    sbar2.btnGrip.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, 0, w, h)
    end

    -- Visibility of create button based on permissions
    local char = LocalPlayer():GetCharacter()
    if (char) then
        local isOfficer = char:IsUnitOfficer()
        local isSquadLeader = char:IsSquadLeader()
        local isSuperAdmin = LocalPlayer():IsSuperAdmin()
        self.createBtn:SetVisible(isOfficer or isSquadLeader or isSuperAdmin)
    end

    -- Hooks
    hook.Add("USMSMissionsUpdated", self, function(s)
        s:RebuildList()
    end)

    -- Initial request
    ix.usms.Request("mission_request", {})
end

function PANEL:OnRemove()
    hook.Remove("USMSMissionsUpdated", self)
end

function PANEL:PerformLayout(w, h)
    self.listPanel:SetWide(w * 0.35)
end

function PANEL:RebuildList()
    self.listPanel:Clear()

    local missions = ix.usms.clientData.missions or {}
    local filtered = {}

    for _, mission in ipairs(missions) do
        if (self.filterStatus == "all" or mission.status == self.filterStatus) then
            table.insert(filtered, mission)
        end
    end

    if (#filtered == 0) then
        local lbl = self.listPanel:Add("DLabel")
        lbl:Dock(TOP)
        lbl:SetTall(Scale(40))
        lbl:DockMargin(Scale(8), Scale(8), 0, 0)
        lbl:SetFont("ixImpMenuDiag")
        lbl:SetTextColor(THEME.textMuted)
        lbl:SetText("No missions found.")
        self:RebuildDetail()
        return
    end

    for i, mission in ipairs(filtered) do
        local card = self.listPanel:Add("EditablePanel")
        card:Dock(TOP)
        card:SetTall(Scale(64))
        card:DockMargin(Scale(4), Scale(2), Scale(4), Scale(2))
        card:SetMouseInputEnabled(true)
        card.mission = mission
        card.cardIndex = i

        card.OnMousePressed = function(s, code)
            if (code == MOUSE_LEFT) then
                self.selectedMission = s.mission
                self:RebuildList()
            elseif (code == MOUSE_RIGHT and s.mission.status == USMS_MISSION_ACTIVE) then
                self:OpenMissionContextMenu(s.mission)
            end
        end

        card.OnCursorEntered = function(s) s.bHovered = true end
        card.OnCursorExited = function(s) s.bHovered = false end

        local isSelected = self.selectedMission and self.selectedMission.id == mission.id

        card.Paint = function(s, w, h)
            local m = s.mission
            local selected = self.selectedMission and self.selectedMission.id == m.id
            local bg = s.bHovered and THEME.rowHover or THEME.buttonBg
            surface.SetDrawColor(bg)
            surface.DrawRect(0, 0, w, h)

            if (selected) then
                surface.SetDrawColor(THEME.accent)
                surface.DrawRect(0, 0, Scale(3), h)
            end

            -- Priority indicator bar on right
            local priorityColor = PRIORITY_COLORS[m.priority] or THEME.textMuted
            surface.SetDrawColor(priorityColor)
            surface.DrawRect(w - Scale(3), 0, Scale(3), h)

            local pad = Scale(8)
            local statusColor = STATUS_COLORS[m.status] or THEME.textMuted

            -- Title
            draw.SimpleText(m.title or "Untitled", "ixImpMenuButton", pad, Scale(6), THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            -- Priority + status
            local priorityLabel = PRIORITY_LABELS[m.priority] or "NORMAL"
            draw.SimpleText(priorityLabel, "ixImpMenuStatus", pad, Scale(26), priorityColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(STATUS_LABELS[m.status] or m.status, "ixImpMenuStatus", pad + Scale(70), Scale(26), statusColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            -- Assignment + time
            local assignText = ""
            if (m.assignedTo) then
                if (m.assignedTo.type == "squad") then
                    assignText = "Squad"
                else
                    assignText = "Unit-wide"
                end
            end
            local timeStr = m.createdAt and os.date("%m/%d %H:%M", m.createdAt) or "?"
            draw.SimpleText(assignText .. "  |  " .. timeStr, "ixImpMenuDiag", pad, Scale(42), THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 30)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
    end

    self:RebuildDetail()
end

function PANEL:RebuildDetail()
    self.detailScroll:Clear()

    if (!self.selectedMission) then
        local lbl = self.detailScroll:Add("DLabel")
        lbl:Dock(TOP)
        lbl:SetTall(Scale(40))
        lbl:DockMargin(Scale(8), Scale(8), 0, 0)
        lbl:SetFont("ixImpMenuDiag")
        lbl:SetTextColor(THEME.textMuted)
        lbl:SetText("< SELECT A MISSION >")
        return
    end

    local m = self.selectedMission

    -- Title
    local titleLbl = self.detailScroll:Add("DLabel")
    titleLbl:Dock(TOP)
    titleLbl:SetTall(Scale(28))
    titleLbl:DockMargin(Scale(8), Scale(4), 0, 0)
    titleLbl:SetFont("ixImpMenuSubtitle")
    titleLbl:SetTextColor(THEME.accent)
    titleLbl:SetText(m.title or "Untitled")

    -- Status row
    local statusRow = self.detailScroll:Add("EditablePanel")
    statusRow:Dock(TOP)
    statusRow:SetTall(Scale(22))
    statusRow:DockMargin(Scale(8), Scale(2), Scale(8), Scale(4))
    statusRow.Paint = function(s, w, h)
        local statusColor = STATUS_COLORS[m.status] or THEME.textMuted
        local priorityColor = PRIORITY_COLORS[m.priority] or THEME.textMuted
        draw.SimpleText(STATUS_LABELS[m.status] or m.status, "ixImpMenuStatus", 0, h * 0.5, statusColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("  |  Priority: " .. (PRIORITY_LABELS[m.priority] or "NORMAL"), "ixImpMenuStatus", Scale(80), h * 0.5, priorityColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- Description
    if (m.description and m.description != "") then
        local descLabel = self.detailScroll:Add("DLabel")
        descLabel:Dock(TOP)
        descLabel:DockMargin(Scale(8), Scale(4), Scale(8), Scale(4))
        descLabel:SetFont("ixImpMenuDiag")
        descLabel:SetTextColor(THEME.text)
        descLabel:SetText(m.description)
        descLabel:SetWrap(true)
        descLabel:SetAutoStretchVertical(true)
    end

    -- Separator
    local sep = self.detailScroll:Add("EditablePanel")
    sep:Dock(TOP)
    sep:SetTall(1)
    sep:DockMargin(Scale(8), Scale(8), Scale(8), Scale(8))
    sep.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, 0, w, h)
    end

    -- Meta info
    local metaFields = {
        {"Created by", m.createdByName or "Unknown"},
        {"Created", m.createdAt and os.date("%Y-%m-%d %H:%M", m.createdAt) or "?"},
        {"Assignment", m.assignedTo and (m.assignedTo.type == "squad" and "Squad" or "Unit-wide") or "Unit-wide"}
    }

    if (m.completedAt) then
        table.insert(metaFields, {"Closed", os.date("%Y-%m-%d %H:%M", m.completedAt)})
    end

    for _, field in ipairs(metaFields) do
        local row = self.detailScroll:Add("EditablePanel")
        row:Dock(TOP)
        row:SetTall(Scale(20))
        row:DockMargin(Scale(8), 0, Scale(8), 0)
        row.fieldName = field[1]
        row.fieldValue = field[2]
        row.Paint = function(s, w, h)
            draw.SimpleText(s.fieldName .. ":", "ixImpMenuStatus", 0, h * 0.5, THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(s.fieldValue, "ixImpMenuDiag", Scale(100), h * 0.5, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    -- Action buttons for active missions
    if (m.status == USMS_MISSION_ACTIVE) then
        local char = LocalPlayer():GetCharacter()
        local isOfficer = char and char:IsUnitOfficer()
        local isSquadLeader = char and char:IsSquadLeader()
        local isSuperAdmin = LocalPlayer():IsSuperAdmin()
        local isCreator = char and m.createdBy == char:GetID()

        if (isOfficer or isSquadLeader or isSuperAdmin) then
            local btnRow = self.detailScroll:Add("EditablePanel")
            btnRow:Dock(TOP)
            btnRow:SetTall(Scale(36))
            btnRow:DockMargin(Scale(8), Scale(12), Scale(8), 0)
            btnRow.Paint = function() end

            if (isOfficer or isSuperAdmin or isCreator) then
                local completeBtn = btnRow:Add("DButton")
                completeBtn:SetText("")
                completeBtn:Dock(LEFT)
                completeBtn:SetWide(Scale(130))
                completeBtn:DockMargin(0, 0, Scale(4), 0)
                completeBtn.DoClick = function()
                    Derma_Query("Mark mission \"" .. m.title .. "\" as complete?", "Confirm",
                        "Yes", function()
                            ix.usms.Request("mission_complete", {missionID = m.id})
                            self.selectedMission = nil
                        end,
                        "No", function() end)
                end
                completeBtn.Paint = function(s, w, h)
                    local bg = s:IsHovered() and Color(40, 100, 60, 255) or THEME.buttonBg
                    surface.SetDrawColor(bg)
                    surface.DrawRect(0, 0, w, h)
                    surface.SetDrawColor(THEME.ready)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    draw.SimpleText("COMPLETE", "ixImpMenuStatus", w * 0.5, h * 0.5, THEME.ready, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end

            if (isOfficer or isSuperAdmin or isCreator) then
                local cancelBtn = btnRow:Add("DButton")
                cancelBtn:SetText("")
                cancelBtn:Dock(LEFT)
                cancelBtn:SetWide(Scale(110))
                cancelBtn:DockMargin(0, 0, Scale(4), 0)
                cancelBtn.DoClick = function()
                    Derma_Query("Cancel mission \"" .. m.title .. "\"?", "Confirm",
                        "Yes", function()
                            ix.usms.Request("mission_cancel", {missionID = m.id})
                            self.selectedMission = nil
                        end,
                        "No", function() end)
                end
                cancelBtn.Paint = function(s, w, h)
                    local bg = s:IsHovered() and THEME.dangerHover or THEME.buttonBg
                    surface.SetDrawColor(bg)
                    surface.DrawRect(0, 0, w, h)
                    surface.SetDrawColor(THEME.danger)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    draw.SimpleText("CANCEL", "ixImpMenuStatus", w * 0.5, h * 0.5, THEME.danger, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
        end
    end
end

function PANEL:OpenMissionContextMenu(mission)
    local char = LocalPlayer():GetCharacter()
    if (!char) then return end

    local isOfficer = char:IsUnitOfficer()
    local isSuperAdmin = LocalPlayer():IsSuperAdmin()
    local isCreator = mission.createdBy == char:GetID()

    if (!isOfficer and !isSuperAdmin and !isCreator) then return end

    local menu = DermaMenu()

    menu:AddOption("Complete Mission", function()
        ix.usms.Request("mission_complete", {missionID = mission.id})
    end):SetIcon("icon16/tick.png")

    menu:AddOption("Cancel Mission", function()
        Derma_Query("Cancel mission \"" .. mission.title .. "\"?", "Confirm",
            "Yes", function()
                ix.usms.Request("mission_cancel", {missionID = mission.id})
                self.selectedMission = nil
            end,
            "No", function() end)
    end):SetIcon("icon16/cross.png")

    menu:Open()
end

function PANEL:OpenCreateDialog()
    local char = LocalPlayer():GetCharacter()
    if (!char) then return end

    local frame = vgui.Create("DFrame")
    frame:SetSize(Scale(400), Scale(360))
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:SetDraggable(true)
    frame.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.background)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frame)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("CREATE MISSION", "ixImpMenuSubtitle", Scale(12), Scale(8), THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local y = Scale(36)
    local pad = Scale(8)

    -- Title
    local titleLabel = frame:Add("DLabel")
    titleLabel:SetPos(pad, y)
    titleLabel:SetSize(Scale(380), Scale(18))
    titleLabel:SetFont("ixImpMenuStatus")
    titleLabel:SetTextColor(THEME.textMuted)
    titleLabel:SetText("Title")
    y = y + Scale(18)

    local titleEntry = frame:Add("DTextEntry")
    titleEntry:SetPos(pad, y)
    titleEntry:SetSize(Scale(380), Scale(28))
    titleEntry:SetFont("ixImpMenuDiag")
    titleEntry:SetTextColor(THEME.text)
    titleEntry:SetPlaceholderText("Mission title...")
    titleEntry.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        s:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
    end
    y = y + Scale(36)

    -- Description
    local descLabel = frame:Add("DLabel")
    descLabel:SetPos(pad, y)
    descLabel:SetSize(Scale(380), Scale(18))
    descLabel:SetFont("ixImpMenuStatus")
    descLabel:SetTextColor(THEME.textMuted)
    descLabel:SetText("Description (optional)")
    y = y + Scale(18)

    local descEntry = frame:Add("DTextEntry")
    descEntry:SetPos(pad, y)
    descEntry:SetSize(Scale(380), Scale(60))
    descEntry:SetFont("ixImpMenuDiag")
    descEntry:SetTextColor(THEME.text)
    descEntry:SetMultiline(true)
    descEntry:SetPlaceholderText("Describe the objective...")
    descEntry.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        s:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
    end
    y = y + Scale(68)

    -- Priority
    local prioLabel = frame:Add("DLabel")
    prioLabel:SetPos(pad, y)
    prioLabel:SetSize(Scale(380), Scale(18))
    prioLabel:SetFont("ixImpMenuStatus")
    prioLabel:SetTextColor(THEME.textMuted)
    prioLabel:SetText("Priority")
    y = y + Scale(18)

    local prioCombo = frame:Add("DComboBox")
    prioCombo:SetPos(pad, y)
    prioCombo:SetSize(Scale(180), Scale(28))
    prioCombo:SetFont("ixImpMenuDiag")
    prioCombo:SetTextColor(THEME.text)
    prioCombo:AddChoice("Low", 1)
    prioCombo:AddChoice("Normal", 2, true)
    prioCombo:AddChoice("Critical", 3)
    prioCombo:SetValue("Normal")
    prioCombo.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    y = y + Scale(36)

    -- Assignment
    local assignLabel = frame:Add("DLabel")
    assignLabel:SetPos(pad, y)
    assignLabel:SetSize(Scale(380), Scale(18))
    assignLabel:SetFont("ixImpMenuStatus")
    assignLabel:SetTextColor(THEME.textMuted)
    assignLabel:SetText("Assign To")
    y = y + Scale(18)

    local assignCombo = frame:Add("DComboBox")
    assignCombo:SetPos(pad, y)
    assignCombo:SetSize(Scale(180), Scale(28))
    assignCombo:SetFont("ixImpMenuDiag")
    assignCombo:SetTextColor(THEME.text)
    assignCombo:AddChoice("Entire Unit", "unit", true)
    assignCombo:SetValue("Entire Unit")

    -- Add squads from client data
    local squads = ix.usms.clientData.squads or {}
    for squadID, squad in pairs(squads) do
        assignCombo:AddChoice("Squad: " .. (squad.name or "?"), "squad_" .. squadID)
    end

    assignCombo.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    y = y + Scale(44)

    -- Submit button
    local submitBtn = frame:Add("DButton")
    submitBtn:SetPos(pad, y)
    submitBtn:SetSize(Scale(380), Scale(32))
    submitBtn:SetText("")
    submitBtn.DoClick = function()
        local title = titleEntry:GetValue()
        if (!title or title == "") then return end

        local _, prioData = prioCombo:GetSelected()
        local _, assignData = assignCombo:GetSelected()

        local assignedTo = {type = "unit", id = 0}
        if (assignData and assignData != "unit") then
            local squadID = tonumber(string.sub(assignData, 7))
            if (squadID) then
                assignedTo = {type = "squad", id = squadID}
            end
        end

        ix.usms.Request("mission_create", {
            title = title,
            description = descEntry:GetValue() or "",
            priority = prioData or 2,
            assignedTo = assignedTo
        })

        frame:Close()
    end
    submitBtn.Paint = function(s, w, h)
        local bg = s:IsHovered() and THEME.buttonBgHover or THEME.buttonBg
        surface.SetDrawColor(bg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.accent)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("CREATE MISSION", "ixImpMenuButton", w * 0.5, h * 0.5, THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

function PANEL:Paint(w, h)
end

vgui.Register("ixUSMSMissionPanel", PANEL, "EditablePanel")
