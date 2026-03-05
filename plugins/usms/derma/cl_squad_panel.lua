--- USMS Squad Management Panel
-- Squad cards, create/leave/disband controls, member list per squad.

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
    danger = Color(180, 60, 60, 255),
    dangerHover = Color(200, 80, 80, 255),
    ready = Color(60, 170, 90, 255),
    rowEven = Color(14, 14, 14, 255),
    rowOdd = Color(18, 18, 18, 255),
    rowHover = Color(24, 22, 14, 255),
    ownSquadBg = Color(30, 26, 12, 255),
    ownSquadBorder = Color(191, 148, 53, 180)
}

local function Scale(value)
    return math.max(1, math.Round(value * (ScrH() / 900)))
end

local UNIT_ROLE_NAMES = {
    [0] = "MEMBER",
    [1] = "XO",
    [2] = "CO"
}

local SQUAD_ROLE_NAMES = {
    [USMS_SQUAD_MEMBER] = "MEMBER",
    [USMS_SQUAD_INVITER] = "INVITER",
    [USMS_SQUAD_XO] = "XO",
    [USMS_SQUAD_LEADER] = "LEADER"
}

local function CreateSquadMemberTooltip(data)
    local tip = vgui.Create("DPanel")
    tip:SetDrawOnTop(true)
    tip.lines = {}

    table.insert(tip.lines, {label = "Name", value = data.name or "Unknown", color = THEME.text})
    table.insert(tip.lines, {label = "Status", value = data.isOnline and "ONLINE" or "OFFLINE", color = data.isOnline and THEME.ready or THEME.textMuted})
    table.insert(tip.lines, {label = "Unit Role", value = UNIT_ROLE_NAMES[data.role] or "MEMBER", color = (data.role or 0) >= 1 and THEME.accent or THEME.text})
    table.insert(tip.lines, {label = "Class", value = data.className or "Unassigned", color = THEME.text})
    table.insert(tip.lines, {label = "Squad Role", value = SQUAD_ROLE_NAMES[data.squadRole] or "MEMBER", color = (data.squadRole or 0) >= USMS_SQUAD_XO and THEME.accent or THEME.text})

    local lineH = Scale(18)
    local padX = Scale(10)
    local padY = Scale(6)
    local tipW = Scale(220)
    local tipH = padY * 2 + #tip.lines * lineH

    tip:SetSize(tipW, tipH)

    tip.Paint = function(s, w, h)
        surface.SetDrawColor(10, 10, 10, 240)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        local y = padY
        for _, line in ipairs(s.lines) do
            draw.SimpleText(line.label .. ":", "ixImpMenuDiag", padX, y, THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(line.value, "ixImpMenuDiag", w - padX, y, line.color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            y = y + lineH
        end
    end

    return tip
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SQUAD PANEL (main container)
-- ═══════════════════════════════════════════════════════════════════════════════

local PANEL = {}

function PANEL:Init()
    self.selectedSquadID = nil

    -- Action bar at top
    self.actionBar = self:Add("EditablePanel")
    self.actionBar:Dock(TOP)
    self.actionBar:SetTall(Scale(36))
    self.actionBar:DockMargin(0, 0, 0, Scale(4))
    self.actionBar.Paint = function() end

    self.createBtn = self:CreateActionButton(self.actionBar, "CREATE SQUAD", function()
        Derma_StringRequest(
            "Create Squad",
            "Enter squad designation:",
            "",
            function(text)
                if (text and text:Trim() != "") then
                    ix.usms.Request("squad_create", {name = text:Trim()})
                end
            end,
            nil,
            "Create",
            "Cancel"
        )
    end)
    self.createBtn:Dock(LEFT)
    self.createBtn:SetWide(Scale(140))
    self.createBtn:DockMargin(0, 0, Scale(4), 0)

    self.leaveBtn = self:CreateActionButton(self.actionBar, "LEAVE SQUAD", function()
        Derma_Query("Leave your current squad?", "Confirm", "Yes", function()
            ix.usms.Request("squad_leave", {})
        end, "No")
    end, THEME.danger, THEME.dangerHover)
    self.leaveBtn:Dock(LEFT)
    self.leaveBtn:SetWide(Scale(130))
    self.leaveBtn:DockMargin(0, 0, Scale(4), 0)

    -- Split: squad list (left) + detail (right)
    self.splitContainer = self:Add("EditablePanel")
    self.splitContainer:Dock(FILL)
    self.splitContainer.Paint = function() end

    -- Squad list
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

    -- Detail view
    self.detailPanel = self.splitContainer:Add("EditablePanel")
    self.detailPanel:Dock(FILL)
    self.detailPanel.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
    end

    self.detailLabel = self.detailPanel:Add("DLabel")
    self.detailLabel:Dock(TOP)
    self.detailLabel:SetTall(Scale(32))
    self.detailLabel:SetFont("ixImpMenuSubtitle")
    self.detailLabel:SetTextColor(THEME.accent)
    self.detailLabel:DockMargin(Scale(8), Scale(4), 0, Scale(2))
    self.detailLabel:SetText("< SELECT A SQUAD >")

    self.detailActions = self.detailPanel:Add("EditablePanel")
    self.detailActions:Dock(TOP)
    self.detailActions:SetTall(Scale(32))
    self.detailActions:DockMargin(Scale(4), 0, Scale(4), Scale(4))
    self.detailActions.Paint = function() end

    self.detailScroll = self.detailPanel:Add("DScrollPanel")
    self.detailScroll:Dock(FILL)
    self.detailScroll:DockMargin(Scale(4), 0, Scale(4), Scale(4))

    local sbar2 = self.detailScroll:GetVBar()
    sbar2:SetWide(Scale(4))
    sbar2.Paint = function() end
    sbar2.btnUp.Paint = function() end
    sbar2.btnDown.Paint = function() end
    sbar2.btnGrip.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, 0, w, h)
    end

    -- Hooks
    hook.Add("USMSRosterUpdated", self, function(s)
        s:RebuildSquadList()
        s:RebuildDetail()
    end)
    hook.Add("USMSSquadDataUpdated", self, function(s)
        s:RebuildSquadList()
        s:RebuildDetail()
    end)

    self:RebuildSquadList()
end

function PANEL:OnRemove()
    hook.Remove("USMSRosterUpdated", self)
    hook.Remove("USMSSquadDataUpdated", self)
end

function PANEL:PerformLayout(w, h)
    self.listPanel:SetWide(w * 0.35)
end

function PANEL:CreateActionButton(parent, text, onClick, bgColor, hoverColor)
    bgColor = bgColor or THEME.buttonBg
    hoverColor = hoverColor or THEME.buttonBgHover

    local btn = parent:Add("DButton")
    btn:SetText("")
    btn.labelText = text
    btn.DoClick = onClick
    btn.Paint = function(s, w, h)
        local bg = s:IsHovered() and hoverColor or bgColor
        surface.SetDrawColor(bg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(s.labelText, "ixImpMenuStatus", w * 0.5, h * 0.5, THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    return btn
end

function PANEL:BuildSquadData()
    local squads = {}
    local roster = ix.usms.clientData.roster or {}
    local squadData = ix.usms.clientData.squads or {}

    -- Build from squad sync data
    for squadID, sq in pairs(squadData) do
        squads[squadID] = {
            id = squadID,
            name = sq.name or ("SQUAD " .. squadID),
            description = sq.description or "",
            leaderCharID = sq.leaderCharID,
            leaderName = nil,
            members = {},
            memberCount = 0
        }
    end

    -- Populate members from roster
    for _, entry in ipairs(roster) do
        local sid = entry.squadID
        if (sid and sid > 0) then
            if (!squads[sid]) then
                squads[sid] = {id = sid, name = entry.squadName or ("SQUAD " .. sid), description = entry.squadDescription or "", members = {}, memberCount = 0}
            end
            table.insert(squads[sid].members, entry)
            squads[sid].memberCount = squads[sid].memberCount + 1
            if (entry.squadRole == USMS_SQUAD_LEADER) then
                squads[sid].leaderName = entry.name
                squads[sid].leaderCharID = entry.charID
            end

            -- Update squad name from roster entry if not already set
            if (entry.squadName and entry.squadName != "" and (squads[sid].name == "SQUAD " .. sid)) then
                squads[sid].name = entry.squadName
            end
            -- Update description from roster entry
            if (entry.squadDescription and entry.squadDescription != "" and (squads[sid].description == "")) then
                squads[sid].description = entry.squadDescription
            end
        end
    end

    -- Sort squads into list, own squad first
    local sorted = {}
    local char = LocalPlayer():GetCharacter()
    local mySquadID = char and char:GetUsmSquadID() or 0

    for _, sq in pairs(squads) do
        table.insert(sorted, sq)
    end
    table.sort(sorted, function(a, b)
        -- Own squad always first
        if (a.id == mySquadID and b.id != mySquadID) then return true end
        if (b.id == mySquadID and a.id != mySquadID) then return false end
        return a.id < b.id
    end)
    return sorted
end

function PANEL:RebuildSquadList()
    self.listPanel:Clear()
    local squads = self:BuildSquadData()
    local char = LocalPlayer():GetCharacter()
    local mySquadID = char and char:GetUsmSquadID() or 0
    local isOfficer = char and (char:IsUnitOfficer() or LocalPlayer():IsSuperAdmin())

    for _, sq in ipairs(squads) do
        local isOwnSquad = (sq.id == mySquadID and mySquadID > 0)

        local card = self.listPanel:Add("EditablePanel")
        card:Dock(TOP)
        card:SetTall(Scale(56))
        card:DockMargin(Scale(4), Scale(2), Scale(4), Scale(2))
        card:SetMouseInputEnabled(true)

        card.squadID = sq.id
        card.squadData = sq
        card.isOwnSquad = isOwnSquad

        card.OnMousePressed = function(s, code)
            if (code == MOUSE_LEFT) then
                self.selectedSquadID = s.squadID
                self:RebuildDetail()
            elseif (code == MOUSE_RIGHT) then
                self:OpenSquadCardMenu(s.squadData)
            end
        end

        card.OnCursorEntered = function(s) s.bHovered = true end
        card.OnCursorExited = function(s) s.bHovered = false end

        card.Paint = function(s, w, h)
            local selected = (self.selectedSquadID == s.squadID)

            if (s.isOwnSquad) then
                -- Own squad: highlighted background
                local bg = s.bHovered and Color(36, 32, 16, 255) or THEME.ownSquadBg
                surface.SetDrawColor(bg)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(THEME.ownSquadBorder)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            else
                local bg = s.bHovered and THEME.buttonBgHover or THEME.buttonBg
                surface.SetDrawColor(bg)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 40)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end

            if (selected) then
                surface.SetDrawColor(THEME.accent)
                surface.DrawRect(0, 0, Scale(3), h)
            end

            local pad = Scale(10)
            local nameColor = s.isOwnSquad and THEME.accent or THEME.accent
            draw.SimpleText(s.squadData.name .. (s.isOwnSquad and "  ★" or ""), "ixImpMenuButton", pad, Scale(8), nameColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(
                "Leader: " .. (s.squadData.leaderName or "None") .. "  |  " .. s.squadData.memberCount .. " members",
                "ixImpMenuDiag", pad, Scale(30), THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
            )
        end
    end

    if (#squads == 0) then
        local lbl = self.listPanel:Add("DLabel")
        lbl:Dock(TOP)
        lbl:SetTall(Scale(40))
        lbl:DockMargin(Scale(8), Scale(8), 0, 0)
        lbl:SetFont("ixImpMenuDiag")
        lbl:SetTextColor(THEME.textMuted)
        lbl:SetText("No squads in this unit.")
    end
end

--- Right-click context menu on squad cards.
function PANEL:OpenSquadCardMenu(squadData)
    local char = LocalPlayer():GetCharacter()
    if (!char) then return end

    local isOfficer = char:IsUnitOfficer() or LocalPlayer():IsSuperAdmin()
    local isLeader = char:IsSquadLeader() and char:GetUsmSquadID() == squadData.id

    if (!isOfficer and !isLeader) then return end

    local menu = DermaMenu()

    -- Set description (leader, officer, superadmin)
    menu:AddOption("Set Description", function()
        Derma_StringRequest(
            "Squad Description",
            "Enter a description for " .. squadData.name .. ":",
            squadData.description or "",
            function(text)
                ix.usms.Request("squad_set_description", {squadID = squadData.id, description = text:Trim()})
            end,
            nil,
            "Save",
            "Cancel"
        )
    end):SetIcon("icon16/page_edit.png")

    if (isOfficer) then
        -- Force disband
        menu:AddOption("Force Disband", function()
            Derma_Query("Force disband " .. squadData.name .. "?", "Confirm", "Yes", function()
                ix.usms.Request("squad_force_disband", {squadID = squadData.id})
            end, "No")
        end):SetIcon("icon16/cross.png")
    end

    if (isLeader) then
        menu:AddOption("Disband", function()
            Derma_Query("Disband " .. squadData.name .. "?", "Confirm", "Yes", function()
                ix.usms.Request("squad_disband", {})
            end, "No")
        end):SetIcon("icon16/cross.png")
    end

    menu:Open()
end

function PANEL:RebuildDetail()
    self.detailScroll:Clear()
    self.detailActions:Clear()

    if (!self.selectedSquadID) then
        self.detailLabel:SetText("< SELECT A SQUAD >")
        return
    end

    local squads = self:BuildSquadData()
    local sq

    for _, s in ipairs(squads) do
        if (s.id == self.selectedSquadID) then
            sq = s
            break
        end
    end

    if (!sq) then
        self.detailLabel:SetText("< SQUAD NOT FOUND >")
        self.selectedSquadID = nil
        return
    end

    self.detailLabel:SetText(sq.name .. "  [#" .. sq.id .. "]")

    -- Action buttons for this squad
    local char = LocalPlayer():GetCharacter()
    if (char) then
        local isLeader = char:IsSquadLeader() and char:GetUsmSquadID() == sq.id
        local isOfficer = char:IsUnitOfficer() or LocalPlayer():IsSuperAdmin()

        if (isLeader) then
            local disbandBtn = self:CreateActionButton(self.detailActions, "DISBAND", function()
                Derma_Query("Disband " .. sq.name .. "?", "Confirm", "Yes", function()
                    ix.usms.Request("squad_disband", {})
                end, "No")
            end, THEME.danger, THEME.dangerHover)
            disbandBtn:Dock(LEFT)
            disbandBtn:SetWide(Scale(100))
            disbandBtn:DockMargin(0, Scale(2), Scale(4), Scale(2))
        end

        -- CO/XO/superadmin can force disband any squad
        if (isOfficer and !isLeader) then
            local forceDisband = self:CreateActionButton(self.detailActions, "FORCE DISBAND", function()
                Derma_Query("Force disband " .. sq.name .. "?", "Confirm", "Yes", function()
                    ix.usms.Request("squad_force_disband", {squadID = sq.id})
                end, "No")
            end, THEME.danger, THEME.dangerHover)
            forceDisband:Dock(LEFT)
            forceDisband:SetWide(Scale(130))
            forceDisband:DockMargin(0, Scale(2), Scale(4), Scale(2))
        end

        -- Set description button (leader, officer, superadmin)
        if (isLeader or isOfficer) then
            local descBtn = self:CreateActionButton(self.detailActions, "SET DESC", function()
                Derma_StringRequest(
                    "Squad Description",
                    "Enter a description for " .. sq.name .. ":",
                    sq.description or "",
                    function(text)
                        ix.usms.Request("squad_set_description", {squadID = sq.id, description = text:Trim()})
                    end,
                    nil,
                    "Save",
                    "Cancel"
                )
            end)
            descBtn:Dock(LEFT)
            descBtn:SetWide(Scale(100))
            descBtn:DockMargin(0, Scale(2), Scale(4), Scale(2))
        end

        -- Invite button (squad leader, inviter, officer, superadmin)
        local canInvite = isOfficer or (isLeader) or (char:IsInSquad() and char:GetUsmSquadID() == sq.id and char:CanSquadInvite())
        if (canInvite) then
            local invBtn = self:CreateActionButton(self.detailActions, "INVITE", function()
                self:OpenSquadInvitePicker(sq)
            end)
            invBtn:Dock(LEFT)
            invBtn:SetWide(Scale(80))
            invBtn:DockMargin(0, Scale(2), Scale(4), Scale(2))
        end
    end

    -- Description display
    if (sq.description and sq.description != "") then
        local descContainer = self.detailScroll:Add("EditablePanel")
        descContainer:Dock(TOP)
        descContainer:DockMargin(Scale(4), Scale(2), Scale(4), Scale(6))

        local descLabel = descContainer:Add("DLabel")
        descLabel:SetFont("ixImpMenuDiag")
        descLabel:SetTextColor(THEME.textMuted)
        descLabel:SetText(sq.description)
        descLabel:SetWrap(true)
        descLabel:SetAutoStretchVertical(true)
        descLabel:Dock(TOP)
        descLabel:DockMargin(Scale(4), Scale(2), Scale(4), Scale(2))

        -- Size the container after the label stretches
        descContainer:SetTall(Scale(20))
        descContainer.PerformLayout = function(s, w, h)
            s:SetTall(descLabel:GetTall() + Scale(8))
        end

        descContainer.Paint = function(s, w, h)
            surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 20)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 40)
            surface.DrawRect(0, 0, Scale(2), h)
        end
    end

    -- Loadouts / Specs section
    local classMap = {}
    for _, member in ipairs(sq.members) do
        local cn = member.className or "Unassigned"
        classMap[cn] = (classMap[cn] or 0) + 1
    end

    if (table.Count(classMap) > 0) then
        local loadoutHeader = self.detailScroll:Add("EditablePanel")
        loadoutHeader:Dock(TOP)
        loadoutHeader:SetTall(Scale(20))
        loadoutHeader:DockMargin(Scale(4), Scale(4), Scale(4), Scale(2))
        loadoutHeader.Paint = function(s, w, h)
            draw.SimpleText("LOADOUTS / SPECS", "ixImpMenuStatus", Scale(4), h * 0.5, THEME.accentSoft, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            surface.SetDrawColor(THEME.frameSoft)
            surface.DrawRect(0, h - 1, w, 1)
        end

        -- Sort classes by count descending
        local sorted = {}
        for className, count in pairs(classMap) do
            table.insert(sorted, {name = className, count = count})
        end
        table.sort(sorted, function(a, b) return a.count > b.count end)

        for _, cls in ipairs(sorted) do
            local clsRow = self.detailScroll:Add("EditablePanel")
            clsRow:Dock(TOP)
            clsRow:SetTall(Scale(18))
            clsRow:DockMargin(Scale(8), 0, Scale(8), 0)
            clsRow.Paint = function(s, w, h)
                draw.SimpleText("• " .. cls.name, "ixImpMenuDiag", Scale(4), h * 0.5, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText("×" .. cls.count, "ixImpMenuDiag", w - Scale(4), h * 0.5, THEME.textMuted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end
    end

    -- Member list header
    local memberHeader = self.detailScroll:Add("EditablePanel")
    memberHeader:Dock(TOP)
    memberHeader:SetTall(Scale(22))
    memberHeader:DockMargin(Scale(4), Scale(6), Scale(4), Scale(2))
    memberHeader.Paint = function(s, w, h)
        draw.SimpleText("MEMBERS (" .. #sq.members .. ")", "ixImpMenuStatus", Scale(4), h * 0.5, THEME.accentSoft, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, h - 1, w, 1)
    end

    -- Member list
    table.sort(sq.members, function(a, b)
        if (a.squadRole != b.squadRole) then return (a.squadRole or 0) > (b.squadRole or 0) end
        return (a.name or "") < (b.name or "")
    end)

    local isOfficer = char and (char:IsUnitOfficer() or LocalPlayer():IsSuperAdmin())

    for i, member in ipairs(sq.members) do
        local row = self.detailScroll:Add("EditablePanel")
        row:Dock(TOP)
        row:SetTall(Scale(28))
        row:SetMouseInputEnabled(true)
        row.memberData = member
        row.rowIndex = i

        row.OnCursorEntered = function(s)
            s.bHovered = true

            if (IsValid(s.tooltip)) then s.tooltip:Remove() end
            s.tooltip = CreateSquadMemberTooltip(s.memberData)
            s.tooltip:SetParent(vgui.GetWorldPanel())
            local mx, my = gui.MousePos()
            s.tooltip:SetPos(mx + Scale(12), my + Scale(8))
        end
        row.OnCursorExited = function(s)
            s.bHovered = false
            if (IsValid(s.tooltip)) then s.tooltip:Remove() end
        end
        row.OnRemove = function(s)
            if (IsValid(s.tooltip)) then s.tooltip:Remove() end
        end

        row.Paint = function(s, w, h)
            local bg
            if (s.bHovered) then
                bg = THEME.rowHover
            elseif (s.rowIndex % 2 == 0) then
                bg = THEME.rowEven
            else
                bg = THEME.rowOdd
            end
            surface.SetDrawColor(bg)
            surface.DrawRect(0, 0, w, h)

            local nameColor = THEME.text
            local roleText = ""
            if (s.memberData.squadRole == USMS_SQUAD_LEADER) then
                nameColor = THEME.accent
                roleText = " [SL]"
            elseif (s.memberData.squadRole == USMS_SQUAD_XO) then
                nameColor = THEME.accentSoft
                roleText = " [XO]"
            elseif (s.memberData.squadRole == USMS_SQUAD_INVITER) then
                roleText = " [INV]"
            end

            local statusColor = s.memberData.isOnline and THEME.ready or THEME.textMuted
            local statusText = s.memberData.isOnline and "ONLINE" or "OFFLINE"

            draw.SimpleText((s.memberData.name or "?") .. roleText, "ixImpMenuDiag", Scale(8), h * 0.5, nameColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(s.memberData.className or "", "ixImpMenuDiag", w * 0.5, h * 0.5, THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(statusText, "ixImpMenuDiag", w - Scale(8), h * 0.5, statusColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        -- Right-click context menu for squad member rows
        row.OnMousePressed = function(s, code)
            if (code != MOUSE_RIGHT) then return end
            if (!char) then return end
            if (s.memberData.charID == char:GetID()) then return end

            local mySquadRole = char:GetUsmSquadRole()
            local isInThisSquad = (char:GetUsmSquadID() == sq.id)
            local hasSquadAuth = isInThisSquad and mySquadRole >= USMS_SQUAD_XO
            local hasOfficerAuth = isOfficer

            if (!hasSquadAuth and !hasOfficerAuth) then return end

            local menu = DermaMenu()

            -- Kick from squad (squad XO+ can kick lower ranks, officers/superadmins can always kick)
            if (hasOfficerAuth or (hasSquadAuth and mySquadRole > (s.memberData.squadRole or 0))) then
                local kickAction = hasOfficerAuth and !isInThisSquad and "squad_force_remove" or "squad_kick"
                menu:AddOption("Remove from Squad", function()
                    ix.usms.Request(kickAction, {charID = s.memberData.charID})
                end):SetIcon("icon16/user_delete.png")
            end

            -- Role management (squad leader or officer/superadmin)
            if (hasOfficerAuth or (isInThisSquad and mySquadRole == USMS_SQUAD_LEADER)) then
                local roleMenu = menu:AddSubMenu("Set Squad Role")
                roleMenu:AddOption("Member", function()
                    ix.usms.Request("squad_set_role", {charID = s.memberData.charID, role = USMS_SQUAD_MEMBER})
                end)
                roleMenu:AddOption("Inviter", function()
                    ix.usms.Request("squad_set_role", {charID = s.memberData.charID, role = USMS_SQUAD_INVITER})
                end)
                roleMenu:AddOption("XO", function()
                    ix.usms.Request("squad_set_role", {charID = s.memberData.charID, role = USMS_SQUAD_XO})
                end)
            end

            -- Transfer squad leadership (squad leader or officer/superadmin)
            if (hasOfficerAuth or (isInThisSquad and mySquadRole == USMS_SQUAD_LEADER)) then
                menu:AddOption("Transfer Leader", function()
                    Derma_Query("Transfer squad leadership to " .. (s.memberData.name or "this member") .. "?", "Confirm", "Yes", function()
                        ix.usms.Request("squad_transfer_leader", {charID = s.memberData.charID})
                    end, "No")
                end):SetIcon("icon16/shield.png")
            end

            menu:Open()
        end
    end

    if (#sq.members == 0) then
        local lbl = self.detailScroll:Add("DLabel")
        lbl:Dock(TOP)
        lbl:SetTall(Scale(28))
        lbl:DockMargin(Scale(8), 0, 0, 0)
        lbl:SetFont("ixImpMenuDiag")
        lbl:SetTextColor(THEME.textMuted)
        lbl:SetText("No members.")
    end
end

function PANEL:Paint(w, h)
end

--- Opens a player picker for inviting unit members to a squad.
function PANEL:OpenSquadInvitePicker(squadData)
    local frame = vgui.Create("DFrame")
    frame:SetTitle("Invite to " .. (squadData.name or "Squad"))
    frame:SetSize(Scale(280), Scale(360))
    frame:Center()
    frame:MakePopup()
    frame:SetDraggable(true)
    frame.Paint = function(s, w, h)
        surface.SetDrawColor(12, 12, 12, 250)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(s:GetTitle(), "ixImpMenuButton", w * 0.5, Scale(12), THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local scroll = frame:Add("DScrollPanel")
    scroll:Dock(FILL)
    scroll:DockMargin(Scale(4), Scale(28), Scale(4), Scale(4))

    -- Show unit members who are NOT in any squad
    local roster = ix.usms.clientData.roster or {}
    local myCharID = LocalPlayer():GetCharacter() and LocalPlayer():GetCharacter():GetID() or 0
    local count = 0

    for _, entry in ipairs(roster) do
        if (entry.charID == myCharID) then continue end
        if (entry.squadID and entry.squadID > 0) then continue end
        if (!entry.isOnline) then continue end

        count = count + 1
        local btn = scroll:Add("DButton")
        btn:SetText("")
        btn:Dock(TOP)
        btn:SetTall(Scale(28))
        btn:DockMargin(0, 0, 0, Scale(2))

        btn.Paint = function(s, w, h)
            local bg = s:IsHovered() and THEME.rowHover or THEME.rowOdd
            surface.SetDrawColor(bg)
            surface.DrawRect(0, 0, w, h)
            draw.SimpleText(entry.name or "Unknown", "ixImpMenuDiag", Scale(8), h * 0.5, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(entry.className or "", "ixImpMenuDiag", w - Scale(8), h * 0.5, THEME.textMuted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            ix.usms.Request("squad_invite", {charID = entry.charID})
            frame:Close()
        end
    end

    if (count == 0) then
        local lbl = scroll:Add("DLabel")
        lbl:Dock(TOP)
        lbl:SetTall(Scale(32))
        lbl:DockMargin(Scale(8), Scale(8), 0, 0)
        lbl:SetFont("ixImpMenuDiag")
        lbl:SetTextColor(THEME.textMuted)
        lbl:SetText("No eligible members online.")
    end
end

vgui.Register("ixUSMSSquadPanel", PANEL, "EditablePanel")
