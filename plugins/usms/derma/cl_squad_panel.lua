--- USMS Squad Management Panel
-- Squad cards, create/leave/disband controls, member list per squad.

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

    table.insert(tip.lines, {label = "Name", value = data.name or "Unknown", color = ix.ui.THEME.text})
    table.insert(tip.lines, {label = "Status", value = data.isOnline and "ONLINE" or "OFFLINE", color = data.isOnline and ix.ui.THEME.ready or ix.ui.THEME.textMuted})
    table.insert(tip.lines, {label = "Unit Role", value = UNIT_ROLE_NAMES[data.role] or "MEMBER", color = (data.role or 0) >= 1 and ix.ui.THEME.accent or ix.ui.THEME.text})
    table.insert(tip.lines, {label = "Class", value = data.className or "Unassigned", color = ix.ui.THEME.text})
    table.insert(tip.lines, {label = "Squad Role", value = SQUAD_ROLE_NAMES[data.squadRole] or "MEMBER", color = (data.squadRole or 0) >= USMS_SQUAD_XO and ix.ui.THEME.accent or ix.ui.THEME.text})

    local lineH = ix.ui.Scale(18)
    local padX = ix.ui.Scale(10)
    local padY = ix.ui.Scale(6)
    local tipW = ix.ui.Scale(220)
    local tipH = padY * 2 + #tip.lines * lineH

    tip:SetSize(tipW, tipH)

    tip.Paint = function(s, w, h)
        surface.SetDrawColor(10, 10, 10, 240)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        local y = padY
        for _, line in ipairs(s.lines) do
            draw.SimpleText(line.label .. ":", "ixImpMenuDiag", padX, y, ix.ui.THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
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
    self.actionBar:SetTall(ix.ui.Scale(36))
    self.actionBar:DockMargin(0, 0, 0, ix.ui.Scale(4))
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
    self.createBtn:SetWide(ix.ui.Scale(140))
    self.createBtn:DockMargin(0, 0, ix.ui.Scale(4), 0)

    self.leaveBtn = self:CreateActionButton(self.actionBar, "LEAVE SQUAD", function()
        Derma_Query("Leave your current squad?", "Confirm", "Yes", function()
            ix.usms.Request("squad_leave", {})
        end, "No")
    end, ix.ui.THEME.danger, ix.ui.THEME.dangerHover)
    self.leaveBtn:Dock(LEFT)
    self.leaveBtn:SetWide(ix.ui.Scale(130))
    self.leaveBtn:DockMargin(0, 0, ix.ui.Scale(4), 0)

    -- Split: squad list (left) + detail (right)
    self.splitContainer = self:Add("EditablePanel")
    self.splitContainer:Dock(FILL)
    self.splitContainer.Paint = function() end

    -- Squad list
    self.listPanel = self.splitContainer:Add("DScrollPanel")
    self.listPanel:Dock(LEFT)
    self.listPanel:DockMargin(0, 0, ix.ui.Scale(4), 0)
    self.listPanel.Paint = function(s, w, h)
        surface.SetDrawColor(ix.ui.THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
    end

    local sbar = self.listPanel:GetVBar()
    sbar:SetWide(ix.ui.Scale(4))
    sbar.Paint = function() end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(s, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawRect(0, 0, w, h)
    end

    -- Detail view
    self.detailPanel = self.splitContainer:Add("EditablePanel")
    self.detailPanel:Dock(FILL)
    self.detailPanel.Paint = function(s, w, h)
        surface.SetDrawColor(ix.ui.THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
    end

    self.detailLabel = self.detailPanel:Add("DLabel")
    self.detailLabel:Dock(TOP)
    self.detailLabel:SetTall(ix.ui.Scale(32))
    self.detailLabel:SetFont("ixImpMenuSubtitle")
    self.detailLabel:SetTextColor(ix.ui.THEME.accent)
    self.detailLabel:DockMargin(ix.ui.Scale(8), ix.ui.Scale(4), 0, ix.ui.Scale(2))
    self.detailLabel:SetText("< SELECT A SQUAD >")

    self.detailActions = self.detailPanel:Add("EditablePanel")
    self.detailActions:Dock(TOP)
    self.detailActions:SetTall(ix.ui.Scale(32))
    self.detailActions:DockMargin(ix.ui.Scale(4), 0, ix.ui.Scale(4), ix.ui.Scale(4))
    self.detailActions.Paint = function() end

    self.detailScroll = self.detailPanel:Add("DScrollPanel")
    self.detailScroll:Dock(FILL)
    self.detailScroll:DockMargin(ix.ui.Scale(4), 0, ix.ui.Scale(4), ix.ui.Scale(4))

    local sbar2 = self.detailScroll:GetVBar()
    sbar2:SetWide(ix.ui.Scale(4))
    sbar2.Paint = function() end
    sbar2.btnUp.Paint = function() end
    sbar2.btnDown.Paint = function() end
    sbar2.btnGrip.Paint = function(s, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawRect(0, 0, w, h)
    end

    -- Hooks
    hook.Add("USMSRosterUpdated", self, function(s)
        s:RebuildSquadList()
        s:RebuildDetail()
    end)
    hook.Add("USMSSquadsUpdated", self, function(s)
        s:RebuildSquadList()
        s:RebuildDetail()
    end)

    self:RebuildSquadList()
end

function PANEL:OnRemove()
    hook.Remove("USMSRosterUpdated", self)
    hook.Remove("USMSSquadsUpdated", self)
end

function PANEL:PerformLayout(w, h)
    self.listPanel:SetWide(w * 0.35)
end

function PANEL:CreateActionButton(parent, text, onClick, bgColor, hoverColor)
    bgColor = bgColor or ix.ui.THEME.buttonBg
    hoverColor = hoverColor or ix.ui.THEME.buttonBgHover

    local btn = parent:Add("DButton")
    btn:SetText("")
    btn.labelText = text
    btn.DoClick = onClick
    btn.Paint = function(s, w, h)
        local bg = s:IsHovered() and hoverColor or bgColor
        surface.SetDrawColor(bg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(s.labelText, "ixImpMenuStatus", w * 0.5, h * 0.5, ix.ui.THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    return btn
end

function PANEL:BuildSquadData()
    local squadData = ix.usms.clientData.squads or {}
    local rosterData = ix.usms.clientData.roster or {}

    local squadIndex = {}
    local squads = {}

    for sqID, sq in pairs(squadData) do
        local numericID = tonumber(sqID) or sqID
        squadIndex[numericID] = {
            id = numericID,
            name = sq.name or ("Squad #" .. tostring(numericID)),
            description = sq.description or "",
            members = {},
            memberCount = 0,
            leaderName = "None"
        }
    end

    for _, member in ipairs(rosterData) do
        local squadID = tonumber(member.squadID or 0) or 0
        if (squadID <= 0) then continue end

        if (!squadIndex[squadID]) then
            squadIndex[squadID] = {
                id = squadID,
                name = "Squad #" .. tostring(squadID),
                description = "",
                members = {},
                memberCount = 0,
                leaderName = "None"
            }
        end

        local mapped = squadIndex[squadID]
        table.insert(mapped.members, member)
        mapped.memberCount = mapped.memberCount + 1

        if (member.squadRole == USMS_SQUAD_LEADER) then
            mapped.leaderName = member.name or mapped.leaderName
        end
    end

    for _, squad in pairs(squadIndex) do
        table.insert(squads, squad)
    end

    table.sort(squads, function(a, b) return a.id < b.id end)

    return squads
end

function PANEL:RebuildSquadList()
    self.listPanel:Clear()
    local squads = self:BuildSquadData()
    local char = LocalPlayer():GetCharacter()
    local mySquadID = char and char:GetUsmSquadID() or 0
    local inSquad = char and char:IsInSquad()
    local isOfficer = char and (char:IsUnitOfficer() or LocalPlayer():IsSuperAdmin())
    
    if (IsValid(self.leaveBtn)) then
        self.leaveBtn:SetVisible(inSquad)
    end
    
    if (IsValid(self.createBtn)) then
        local canCreate = isOfficer
        self.createBtn:SetVisible(canCreate and not inSquad)
    end

    for _, sq in ipairs(squads) do
        local isOwnSquad = (sq.id == mySquadID and mySquadID > 0)

        local card = self.listPanel:Add("EditablePanel")
        card:Dock(TOP)
        card:SetTall(ix.ui.Scale(56))
        card:DockMargin(ix.ui.Scale(4), ix.ui.Scale(2), ix.ui.Scale(4), ix.ui.Scale(2))
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
                local bg = s.bHovered and Color(36, 32, 16, 255) or Color(26, 24, 14, 255)
                surface.SetDrawColor(bg)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(ix.ui.THEME.frameSoft)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            else
                local bg = s.bHovered and ix.ui.THEME.buttonBgHover or ix.ui.THEME.buttonBg
                surface.SetDrawColor(bg)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(ColorAlpha(ix.ui.THEME.frameSoft, 40))
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end

            if (selected) then
                surface.SetDrawColor(ix.ui.THEME.accent)
                surface.DrawRect(0, 0, ix.ui.Scale(3), h)
            end

            local pad = ix.ui.Scale(10)
            local nameColor = s.isOwnSquad and ix.ui.THEME.accent or ix.ui.THEME.accent
            draw.SimpleText(s.squadData.name .. (s.isOwnSquad and "  ★" or ""), "ixImpMenuButton", pad, ix.ui.Scale(8), nameColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(
                "Leader: " .. (s.squadData.leaderName or "None") .. "  |  " .. (s.squadData.memberCount or 0) .. " members",
                "ixImpMenuDiag", pad, ix.ui.Scale(30), ix.ui.THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
            )
        end
    end

    if (#squads == 0) then
        local lbl = self.listPanel:Add("DLabel")
        lbl:Dock(TOP)
        lbl:SetTall(ix.ui.Scale(40))
        lbl:DockMargin(ix.ui.Scale(8), ix.ui.Scale(8), 0, 0)
        lbl:SetFont("ixImpMenuDiag")
        lbl:SetTextColor(ix.ui.THEME.textMuted)
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

    -- Action buttons removed. Actions are accessible via the Squad Card right-click menu or Roster.

    -- Description display
    if (sq.description and sq.description != "") then
        local descContainer = self.detailScroll:Add("EditablePanel")
        descContainer:Dock(TOP)
        descContainer:DockMargin(ix.ui.Scale(4), ix.ui.Scale(2), ix.ui.Scale(4), ix.ui.Scale(6))

        local descLabel = descContainer:Add("DLabel")
        descLabel:SetFont("ixImpMenuDiag")
        descLabel:SetTextColor(ix.ui.THEME.textMuted)
        descLabel:SetText(sq.description)
        descLabel:SetWrap(true)
        descLabel:SetAutoStretchVertical(true)
        descLabel:Dock(TOP)
        descLabel:DockMargin(ix.ui.Scale(4), ix.ui.Scale(2), ix.ui.Scale(4), ix.ui.Scale(2))

        -- Size the container after the label stretches
        descContainer:SetTall(ix.ui.Scale(20))
        descContainer.PerformLayout = function(s, w, h)
            s:SetTall(descLabel:GetTall() + ix.ui.Scale(8))
        end

        descContainer.Paint = function(s, w, h)
            surface.SetDrawColor(ColorAlpha(ix.ui.THEME.frameSoft, 20))
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(ColorAlpha(ix.ui.THEME.frameSoft, 40))
            surface.DrawRect(0, 0, ix.ui.Scale(2), h)
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
        loadoutHeader:SetTall(ix.ui.Scale(20))
        loadoutHeader:DockMargin(ix.ui.Scale(4), ix.ui.Scale(4), ix.ui.Scale(4), ix.ui.Scale(2))
        loadoutHeader.Paint = function(s, w, h)
            draw.SimpleText("LOADOUTS / SPECS", "ixImpMenuStatus", ix.ui.Scale(4), h * 0.5, ix.ui.THEME.accentSoft, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            surface.SetDrawColor(ix.ui.THEME.frameSoft)
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
            clsRow:SetTall(ix.ui.Scale(18))
            clsRow:DockMargin(ix.ui.Scale(8), 0, ix.ui.Scale(8), 0)
            clsRow.Paint = function(s, w, h)
                draw.SimpleText("• " .. cls.name, "ixImpMenuDiag", ix.ui.Scale(4), h * 0.5, ix.ui.THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText("×" .. cls.count, "ixImpMenuDiag", w - ix.ui.Scale(4), h * 0.5, ix.ui.THEME.textMuted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end
    end

    -- Member list header
    local memberHeader = self.detailScroll:Add("EditablePanel")
    memberHeader:Dock(TOP)
    memberHeader:SetTall(ix.ui.Scale(22))
    memberHeader:DockMargin(ix.ui.Scale(4), ix.ui.Scale(6), ix.ui.Scale(4), ix.ui.Scale(2))
    memberHeader.Paint = function(s, w, h)
        draw.SimpleText("MEMBERS (" .. #sq.members .. ")", "ixImpMenuStatus", ix.ui.Scale(4), h * 0.5, ix.ui.THEME.accentSoft, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
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
        row:SetTall(ix.ui.Scale(28))
        row:SetMouseInputEnabled(true)
        row.memberData = member
        row.rowIndex = i

        row.OnCursorEntered = function(s)
            s.bHovered = true

            if (IsValid(s.tooltip)) then s.tooltip:Remove() end
            s.tooltip = CreateSquadMemberTooltip(s.memberData)
            s.tooltip:SetParent(vgui.GetWorldPanel())
            local mx, my = gui.MousePos()
            s.tooltip:SetPos(mx + ix.ui.Scale(12), my + ix.ui.Scale(8))
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
                bg = ix.ui.THEME.rowHover
            elseif (s.rowIndex % 2 == 0) then
                bg = ix.ui.THEME.rowEven
            else
                bg = ix.ui.THEME.rowOdd
            end
            surface.SetDrawColor(bg)
            surface.DrawRect(0, 0, w, h)

            local nameColor = ix.ui.THEME.text
            local roleText = ""
            if (s.memberData.squadRole == USMS_SQUAD_LEADER) then
                nameColor = ix.ui.THEME.accent
                roleText = " [SL]"
            elseif (s.memberData.squadRole == USMS_SQUAD_XO) then
                nameColor = ix.ui.THEME.accentSoft
                roleText = " [XO]"
            elseif (s.memberData.squadRole == USMS_SQUAD_INVITER) then
                roleText = " [INV]"
            end

            local statusColor = s.memberData.isOnline and ix.ui.THEME.ready or ix.ui.THEME.textMuted
            local statusText = s.memberData.isOnline and "ONLINE" or "OFFLINE"

            draw.SimpleText((s.memberData.name or "?") .. roleText, "ixImpMenuDiag", ix.ui.Scale(8), h * 0.5, nameColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(s.memberData.className or "", "ixImpMenuDiag", w * 0.5, h * 0.5, ix.ui.THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(statusText, "ixImpMenuDiag", w - ix.ui.Scale(8), h * 0.5, statusColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
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
        lbl:SetTall(ix.ui.Scale(28))
        lbl:DockMargin(ix.ui.Scale(8), 0, 0, 0)
        lbl:SetFont("ixImpMenuDiag")
        lbl:SetTextColor(ix.ui.THEME.textMuted)
        lbl:SetText("No members.")
    end
end

function PANEL:Paint(w, h)
end

-- FIX: OpenSquadInvitePicker removed (dead code; invite button was removed during refactor)

vgui.Register("ixUSMSSquadPanel", PANEL, "EditablePanel")
