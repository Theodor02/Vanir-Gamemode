--- USMS Unit Roster Panel
-- Sortable member table showing all unit members.

local ROLE_NAMES = {
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

--- Create a styled tooltip panel for a member data entry.
-- @param data table Roster entry with name, role, className, squadID, squadName, squadRole, isOnline
-- @return Panel
local function CreateMemberTooltip(data)
    local tip = vgui.Create("DPanel")
    tip:SetDrawOnTop(true)
    tip.lines = {}

    table.insert(tip.lines, {label = "Name", value = data.name or "Unknown", color = ix.ui.THEME.text})
    table.insert(tip.lines, {label = "Status", value = data.isOnline and "ONLINE" or "OFFLINE", color = data.isOnline and ix.ui.THEME.ready or ix.ui.THEME.textMuted})
    table.insert(tip.lines, {label = "Unit Role", value = ROLE_NAMES[data.role] or "MEMBER", color = (data.role or 0) >= 1 and ix.ui.THEME.accent or ix.ui.THEME.text})
    table.insert(tip.lines, {label = "Class", value = data.className or "Unassigned", color = ix.ui.THEME.text})

    if (data.squadID and data.squadID > 0) then
        table.insert(tip.lines, {label = "Squad", value = data.squadName or ("Squad #" .. data.squadID), color = ix.ui.THEME.text})
        table.insert(tip.lines, {label = "Squad Role", value = SQUAD_ROLE_NAMES[data.squadRole] or "MEMBER", color = (data.squadRole or 0) >= USMS_SQUAD_XO and ix.ui.THEME.accent or ix.ui.THEME.text})
    else
        table.insert(tip.lines, {label = "Squad", value = "None", color = ix.ui.THEME.textMuted})
    end

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
-- ROSTER PANEL
-- ═══════════════════════════════════════════════════════════════════════════════

local PANEL = {}

function PANEL:Init()
    self.sortKey = "name"
    self.sortAsc = true
    self.filter = ""

    -- Action bar (invite button for CO/XO)
    self.actionBar = self:Add("EditablePanel")
    self.actionBar:Dock(TOP)
    self.actionBar:SetTall(ix.ui.Scale(32))
    self.actionBar:DockMargin(0, 0, 0, ix.ui.Scale(4))
    self.actionBar.Paint = function() end

    local char = LocalPlayer():GetCharacter()
    local showInvite = char and (char:IsUnitOfficer() or LocalPlayer():IsSuperAdmin())

    if (showInvite) then
        self.inviteBtn = self.actionBar:Add("DButton")
        self.inviteBtn:SetText("")
        self.inviteBtn:Dock(LEFT)
        self.inviteBtn:SetWide(ix.ui.Scale(140))
        self.inviteBtn:DockMargin(0, 0, ix.ui.Scale(4), 0)
        self.inviteBtn.DoClick = function()
            self:OpenInvitePlayerPicker()
        end
        self.inviteBtn.Paint = function(s, w, h)
            local bg = s:IsHovered() and ix.ui.THEME.buttonBgHover or ix.ui.THEME.buttonBg
            surface.SetDrawColor(bg)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(ix.ui.THEME.frameSoft)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText("INVITE PLAYER", "ixImpMenuStatus", w * 0.5, h * 0.5, ix.ui.THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Unit edit button
        self.editBtn = self.actionBar:Add("DButton")
        self.editBtn:SetText("")
        self.editBtn:Dock(LEFT)
        self.editBtn:SetWide(ix.ui.Scale(120))
        self.editBtn:DockMargin(0, 0, ix.ui.Scale(4), 0)
        self.editBtn.DoClick = function()
            self:OpenUnitEditDialog()
        end
        self.editBtn.Paint = function(s, w, h)
            local bg = s:IsHovered() and ix.ui.THEME.buttonBgHover or ix.ui.THEME.buttonBg
            surface.SetDrawColor(bg)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(ix.ui.THEME.frameSoft)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText("EDIT UNIT", "ixImpMenuStatus", w * 0.5, h * 0.5, ix.ui.THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Refresh button
        self.refreshBtn = self.actionBar:Add("DButton")
        self.refreshBtn:SetText("")
        self.refreshBtn:Dock(LEFT)
        self.refreshBtn:SetWide(ix.ui.Scale(120))
        self.refreshBtn:DockMargin(0, 0, ix.ui.Scale(4), 0)
        self.refreshBtn.DoClick = function()
            local char = LocalPlayer():GetCharacter()
            if (char) then
                ix.usms.Request("roster_request", {unitID = char:GetUsmUnitID()})
            end
        end
        self.refreshBtn.Paint = function(s, w, h)
            local bg = s:IsHovered() and ix.ui.THEME.buttonBgHover or ix.ui.THEME.buttonBg
            surface.SetDrawColor(bg)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(ix.ui.THEME.frameSoft)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText("REFRESH", "ixImpMenuStatus", w * 0.5, h * 0.5, ix.ui.THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    else
        self.actionBar:SetTall(0)
    end

    -- Search bar
    self.searchBar = self:Add("DTextEntry")
    self.searchBar:Dock(TOP)
    self.searchBar:SetTall(ix.ui.Scale(28))
    self.searchBar:DockMargin(0, 0, 0, ix.ui.Scale(4))
    self.searchBar:SetFont("ixImpMenuDiag")
    self.searchBar:SetTextColor(ix.ui.THEME.text)
    self.searchBar:SetPlaceholderText("Search roster...")
    self.searchBar:SetDrawBackground(false)
    self.searchBar.Paint = function(s, w, h)
        surface.SetDrawColor(ix.ui.THEME.buttonBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawRect(0, h - 1, w, 1)
        s:DrawTextEntryText(ix.ui.THEME.text, ix.ui.THEME.accent, ix.ui.THEME.text)
    end
    self.searchBar.OnChange = function(s)
        self.filter = s:GetValue():lower()
        self:RebuildRows()
    end

    -- Column headers
    self.headerBar = self:Add("EditablePanel")
    self.headerBar:Dock(TOP)
    self.headerBar:SetTall(ix.ui.Scale(24))
    self.headerBar:DockMargin(0, 0, 0, ix.ui.Scale(2))

    self.columns = {
    {key = "name", label = "NAME", fraction = 0.40},
    {key = "role", label = "ROLE", fraction = 0.15},
    {key = "className", label = "CLASS", fraction = 0.20},
    {key = "squadID", label = "SQUAD", fraction = 0.15},
    {key = "isOnline", label = "STATUS", fraction = 0.10}
    }

    self.headerBar.Paint = function(s, w, h)
        surface.SetDrawColor(ix.ui.THEME.buttonBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawRect(0, h - 1, w, 1)

        local x = 0
        for _, col in ipairs(self.columns) do
            local colW = w * col.fraction
            local textColor = (self.sortKey == col.key) and ix.ui.THEME.accent or ix.ui.THEME.textMuted

            draw.SimpleText(col.label, "ixImpMenuStatus", x + ix.ui.Scale(6), h * 0.5, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            x = x + colW
        end
    end

    self.headerBar.OnMousePressed = function(s, code)
        if (code != MOUSE_LEFT) then return end
        local mx = s:ScreenToLocal(gui.MouseX(), 0)
        local w = s:GetWide()
        local x = 0

        for _, col in ipairs(self.columns) do
            local colW = w * col.fraction
            if (mx >= x and mx < x + colW) then
                if (self.sortKey == col.key) then
                    self.sortAsc = !self.sortAsc
                else
                    self.sortKey = col.key
                    self.sortAsc = true
                end
                self:RebuildRows()
                return
            end
            x = x + colW
        end
    end

    -- Row container
    self.scroll = self:Add("DScrollPanel")
    self.scroll:Dock(FILL)

    local sbar = self.scroll:GetVBar()
    sbar:SetWide(ix.ui.Scale(4))
    sbar.Paint = function() end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(s, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawRect(0, 0, w, h)
    end

    -- Listen for roster updates
    hook.Add("USMSRosterUpdated", self, function(s, unitID, roster)
        s:RebuildRows()
    end)
    hook.Add("USMSRosterEntryUpdated", self, function(s, unitID, data)
        s:RebuildRows()
    end)

    self:RebuildRows()
end

function PANEL:OnRemove()
    hook.Remove("USMSRosterUpdated", self)
    hook.Remove("USMSRosterEntryUpdated", self)
end

function PANEL:RebuildRows()
    self.scroll:Clear()

    local roster = ix.usms.clientData.roster or {}
    local filtered = {}

    for _, entry in ipairs(roster) do
        if (self.filter != "") then
            local match = false
            local f = self.filter
            if (string.find((entry.name or ""):lower(), f, 1, true)) then match = true end
            if (string.find((entry.className or ""):lower(), f, 1, true)) then match = true end
            if (string.find((entry.squadName or ""):lower(), f, 1, true)) then match = true end
            local roleName = (ROLE_NAMES[entry.role] or "MEMBER"):lower()
            if (string.find(roleName, f, 1, true)) then match = true end
            if (!match) then continue end
        end
        table.insert(filtered, entry)
    end

    -- Sort
    table.sort(filtered, function(a, b)
        local valA = a[self.sortKey]
        local valB = b[self.sortKey]

        if (valA == nil) then valA = "" end
        if (valB == nil) then valB = "" end

        if (type(valA) == "string") then
            valA = valA:lower()
            valB = (valB or ""):lower()
        end

        if (self.sortAsc) then
            return valA < valB
        else
            return valA > valB
        end
    end)

    for i, entry in ipairs(filtered) do
        local row = self.scroll:Add("ixUSMSRosterRow")
        row:Dock(TOP)
        row:SetTall(ix.ui.Scale(32))
        row.rowIndex = i
        row.columns = self.columns
        row:SetMemberData(entry)
    end
end

function PANEL:Paint(w, h)
    -- Transparent
end

--- Opens a player picker for inviting someone to the unit.
function PANEL:OpenInvitePlayerPicker()
    local frame = vgui.Create("DFrame")
    frame:SetTitle("Invite Player to Unit")
    frame:SetSize(ix.ui.Scale(300), ix.ui.Scale(400))
    frame:Center()
    frame:MakePopup()
    frame:SetDraggable(true)
    frame.Paint = function(s, w, h)
        surface.SetDrawColor(12, 12, 12, 250)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(s:GetTitle(), "ixImpMenuButton", w * 0.5, ix.ui.Scale(12), ix.ui.THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    -- Build list of online players not in the viewer's unit
    local unitData = ix.usms.clientData.unit
    local roster = ix.usms.clientData.roster or {}
    local rosterCharIDs = {}
    for _, entry in ipairs(roster) do
        rosterCharIDs[entry.charID] = true
    end

    local scroll = frame:Add("DScrollPanel")
    scroll:Dock(FILL)
    scroll:DockMargin(ix.ui.Scale(4), ix.ui.Scale(28), ix.ui.Scale(4), ix.ui.Scale(4))

    local count = 0
    for _, ply in ipairs(player.GetAll()) do
        local char = ply:GetCharacter()
        if (!char) then continue end
        if (rosterCharIDs[char:GetID()]) then continue end

        count = count + 1
        local btn = scroll:Add("DButton")
        btn:SetText("")
        btn:Dock(TOP)
        btn:SetTall(ix.ui.Scale(32))
        btn:DockMargin(0, 0, 0, ix.ui.Scale(2))

        local plyName = char:GetName()
        local factionName = ""
        local faction = ix.faction.indices[char:GetFaction()]
        if (faction) then factionName = faction.name end

        btn.Paint = function(s, w, h)
            local bg = s:IsHovered() and ix.ui.THEME.rowHover or ix.ui.THEME.rowOdd
            surface.SetDrawColor(bg)
            surface.DrawRect(0, 0, w, h)
            draw.SimpleText(plyName, "ixImpMenuDiag", ix.ui.Scale(8), h * 0.3, ix.ui.THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(factionName, "ixImpMenuDiag", ix.ui.Scale(8), h * 0.7, ix.ui.THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            ix.usms.Request("unit_invite", {charID = char:GetID()})
            frame:Close()
        end
    end

    if (count == 0) then
        local lbl = scroll:Add("DLabel")
        lbl:Dock(TOP)
        lbl:SetTall(ix.ui.Scale(32))
        lbl:DockMargin(ix.ui.Scale(8), ix.ui.Scale(8), 0, 0)
        lbl:SetFont("ixImpMenuDiag")
        lbl:SetTextColor(ix.ui.THEME.textMuted)
        lbl:SetText("No eligible players online.")
    end
end

--- Opens a dialog for CO/XO to edit unit name and description.
function PANEL:OpenUnitEditDialog()
    local unitData = ix.usms.clientData.unit
    if (!unitData) then return end

    local frame = vgui.Create("DFrame")
    frame:SetTitle("Edit Unit")
    frame:SetSize(ix.ui.Scale(360), ix.ui.Scale(280))
    frame:Center()
    frame:MakePopup()
    frame:SetDraggable(true)
    frame.Paint = function(s, w, h)
        surface.SetDrawColor(12, 12, 12, 250)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(s:GetTitle(), "ixImpMenuButton", w * 0.5, ix.ui.Scale(12), ix.ui.THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local content = frame:Add("EditablePanel")
    content:Dock(FILL)
    content:DockMargin(ix.ui.Scale(8), ix.ui.Scale(28), ix.ui.Scale(8), ix.ui.Scale(8))

    -- Name field
    local nameLbl = content:Add("DLabel")
    nameLbl:Dock(TOP)
    nameLbl:SetTall(ix.ui.Scale(18))
    nameLbl:SetFont("ixImpMenuDiag")
    nameLbl:SetTextColor(ix.ui.THEME.textMuted)
    nameLbl:SetText("Unit Name:")

    local nameEntry = content:Add("DTextEntry")
    nameEntry:Dock(TOP)
    nameEntry:SetTall(ix.ui.Scale(28))
    nameEntry:DockMargin(0, 0, 0, ix.ui.Scale(8))
    nameEntry:SetFont("ixImpMenuDiag")
    nameEntry:SetTextColor(ix.ui.THEME.text)
    nameEntry:SetText(unitData.name or "")
    nameEntry:SetDrawBackground(false)
    nameEntry.Paint = function(s, w, h)
        surface.SetDrawColor(ix.ui.THEME.buttonBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        s:DrawTextEntryText(ix.ui.THEME.text, ix.ui.THEME.accent, ix.ui.THEME.text)
    end

    -- Description field
    local descLbl = content:Add("DLabel")
    descLbl:Dock(TOP)
    descLbl:SetTall(ix.ui.Scale(18))
    descLbl:SetFont("ixImpMenuDiag")
    descLbl:SetTextColor(ix.ui.THEME.textMuted)
    descLbl:SetText("Description:")

    local descEntry = content:Add("DTextEntry")
    descEntry:Dock(TOP)
    descEntry:SetTall(ix.ui.Scale(60))
    descEntry:DockMargin(0, 0, 0, ix.ui.Scale(8))
    descEntry:SetFont("ixImpMenuDiag")
    descEntry:SetTextColor(ix.ui.THEME.text)
    descEntry:SetText(unitData.description or "")
    descEntry:SetMultiline(true)
    descEntry:SetDrawBackground(false)
    descEntry.Paint = function(s, w, h)
        surface.SetDrawColor(ix.ui.THEME.buttonBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        s:DrawTextEntryText(ix.ui.THEME.text, ix.ui.THEME.accent, ix.ui.THEME.text)
    end

    -- Save button
    local saveBtn = content:Add("DButton")
    saveBtn:Dock(TOP)
    saveBtn:SetTall(ix.ui.Scale(32))
    saveBtn:SetText("")
    saveBtn.DoClick = function()
        ix.usms.Request("unit_edit", {
            name = nameEntry:GetValue():Trim(),
            description = descEntry:GetValue():Trim()
        })
        frame:Close()
    end
    saveBtn.Paint = function(s, w, h)
        local bg = s:IsHovered() and ix.ui.THEME.buttonBgHover or ix.ui.THEME.buttonBg
        surface.SetDrawColor(bg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("SAVE CHANGES", "ixImpMenuStatus", w * 0.5, h * 0.5, ix.ui.THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

vgui.Register("ixUSMSRosterPanel", PANEL, "EditablePanel")

-- ═══════════════════════════════════════════════════════════════════════════════
-- ROSTER ROW
-- ═══════════════════════════════════════════════════════════════════════════════

local ROW = {}

function ROW:Init()
    self:SetMouseInputEnabled(true)
    self.rowIndex = 0
    self.data = {}
    self.columns = {}
end

function ROW:SetMemberData(data)
    self.data = data
end

function ROW:OnCursorEntered()
    self.bHovered = true

    if (IsValid(self.tooltip)) then self.tooltip:Remove() end

    self.tooltip = CreateMemberTooltip(self.data)
    self.tooltip:SetParent(vgui.GetWorldPanel())

    local mx, my = gui.MousePos()
    self.tooltip:SetPos(mx + ix.ui.Scale(12), my + ix.ui.Scale(8))
end

function ROW:OnCursorExited()
    self.bHovered = false

    if (IsValid(self.tooltip)) then
        self.tooltip:Remove()
    end
end

function ROW:OnRemove()
    if (IsValid(self.tooltip)) then
        self.tooltip:Remove()
    end
end

function ROW:Paint(w, h)
    local bg
    if (self.bHovered) then
        bg = ix.ui.THEME.rowHover
    elseif (self.rowIndex % 2 == 0) then
        bg = ix.ui.THEME.rowEven
    else
        bg = ix.ui.THEME.rowOdd
    end

    surface.SetDrawColor(bg)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(ColorAlpha(ix.ui.THEME.frameSoft, 30))
    surface.DrawRect(0, h - 1, w, 1)

    -- Draw column values
    local x = 0
    for _, col in ipairs(self.columns) do
        local colW = w * col.fraction
        local text = ""
        local textColor = ix.ui.THEME.text

        if (col.key == "name") then
            text = self.data.name or "Unknown"
        elseif (col.key == "role") then
            text = ROLE_NAMES[self.data.role] or "MEMBER"
            if (self.data.role == 2) then
                textColor = ix.ui.THEME.accent
            elseif (self.data.role == 1) then
                textColor = ix.ui.THEME.accentSoft
            end
        elseif (col.key == "className") then
            text = self.data.className or "Unassigned"
            textColor = ix.ui.THEME.textMuted
        elseif (col.key == "squadID") then
            if (self.data.squadID and self.data.squadID > 0) then
                text = self.data.squadName or ("Squad #" .. self.data.squadID)
                local squadRoleTags = {
                    [USMS_SQUAD_LEADER] = " (SL)",
                    [USMS_SQUAD_XO] = " (XO)",
                    [USMS_SQUAD_INVITER] = " (INV)"
                }
                text = text .. (squadRoleTags[self.data.squadRole] or "")
            else
                text = "-"
                textColor = ix.ui.THEME.textMuted
            end
        elseif (col.key == "isOnline") then
            if (self.data.isOnline) then
                text = "ONLINE"
                textColor = ix.ui.THEME.ready
            else
                text = "OFFLINE"
                textColor = ix.ui.THEME.textMuted
            end
        elseif (col.key == "joinedAt") then
            local ts = self.data.joinedAt
            if (ts and ts > 0) then
                text = os.date("%Y-%m-%d", ts)
            else
                text = "-"
            end
            textColor = ix.ui.THEME.textMuted
        end

        draw.SimpleText(text, "ixImpMenuDiag", x + ix.ui.Scale(6), h * 0.5, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        x = x + colW
    end
end

function ROW:OnMousePressed(code)
    if (code == MOUSE_LEFT) then
        return
    end

    if (code != MOUSE_RIGHT) then return end

    local char = LocalPlayer():GetCharacter()
    if (!char) then return end
    if (self.data.charID == char:GetID()) then return end

    local isOfficer = char:IsUnitOfficer() or LocalPlayer():IsSuperAdmin()
    local canInviteSquad = char:CanSquadInvite() or LocalPlayer():IsSuperAdmin()

    local menu = DermaMenu()

    -- Only show the rest if there's something to show
    if (!isOfficer and !canInviteSquad) then
        menu:Open()
        return
    end

    -- Role management (CO or superadmin)
    if (char:IsUnitCO() or LocalPlayer():IsSuperAdmin()) then
        local roleMenu = menu:AddSubMenu("Set Role")
        roleMenu:AddOption("Member", function()
            ix.usms.Request("unit_set_role", {charID = self.data.charID, role = USMS_ROLE_MEMBER})
        end)
        roleMenu:AddOption("XO", function()
            ix.usms.Request("unit_set_role", {charID = self.data.charID, role = USMS_ROLE_XO})
        end)

        -- Only superadmins can assign CO
        if (LocalPlayer():IsSuperAdmin()) then
            roleMenu:AddOption("CO", function()
                Derma_Query("Assign CO role to " .. (self.data.name or "this member") .. "?", "Confirm", "Yes", function()
                    ix.usms.Request("unit_set_role", {charID = self.data.charID, role = USMS_ROLE_CO})
                end, "No")
            end)
        end
    end

    -- Kick (CO/XO, can't kick equal or higher)
    if (isOfficer and char:GetUsmUnitRole() > (self.data.role or 0)) then
        menu:AddOption("Remove from Unit", function()
            Derma_Query("Remove " .. (self.data.name or "this member") .. " from the unit?", "Confirm", "Yes", function()
                ix.usms.Request("unit_kick", {charID = self.data.charID})
            end, "No")
        end):SetIcon("icon16/user_delete.png")
    end

    -- Class assignment (CO/XO)
    if (isOfficer) then
        local classMenu = menu:AddSubMenu("Assign Class")
        local factionID = char:GetFaction()
        for key, classData in pairs(ix.class.list or {}) do
            if (classData.faction == factionID) then
                classMenu:AddOption(classData.name or ("Class #" .. key), function()
                    ix.usms.Request("unit_set_class", {charID = self.data.charID, classIndex = key})
                end)
            end
        end
    end

    -- FIX: Squad invite allows unit officers even when not personally in a squad (item 3)
    -- Target must not already be in a squad
    if (!self.data.squadID or self.data.squadID == 0) then
        if (canInviteSquad and char:IsInSquad()) then
            -- Regular squad member path
            menu:AddOption("Invite to Squad", function()
                ix.usms.Request("squad_invite", {charID = self.data.charID})
            end):SetIcon("icon16/group_add.png")
        elseif (isOfficer) then
            -- Officer path: show submenu of unit squads to pick target squad
            local squads = ix.usms.clientData and ix.usms.clientData.squads or {}
            if (next(squads) != nil) then
                local inviteMenu = menu:AddSubMenu("Invite to Squad")
                for sqID, sqData in pairs(squads) do
                    local sqIDCopy = sqID
                    local sqName = sqData.name or ("Squad #" .. sqID)
                    inviteMenu:AddOption(sqName, function()
                        ix.usms.Request("squad_invite", {charID = self.data.charID, squadID = sqIDCopy})
                    end)
                end
            end
        end
    end

    -- Force remove from squad (CO/XO/superadmin, target must be in a squad)
    if (isOfficer and self.data.squadID and self.data.squadID > 0) then
        menu:AddOption("Remove from Squad", function()
            ix.usms.Request("squad_force_remove", {charID = self.data.charID})
        end):SetIcon("icon16/group_delete.png")
    end

    -- FIX: Transfer CO moved to bottom with visual separator to reduce misclick risk (item 12)
    if ((char:IsUnitCO() or LocalPlayer():IsSuperAdmin()) and (self.data.role or 0) < USMS_ROLE_CO) then
        menu:AddSpacer()
        menu:AddOption("Transfer CO", function()
            Derma_Query("Transfer CO to " .. (self.data.name or "this member") .. "? You will be demoted to Member.", "Confirm Transfer", "Yes", function()
                ix.usms.Request("co_transfer", {charID = self.data.charID})
            end, "No")
        end):SetIcon("icon16/shield.png")
    end

    menu:Open()
end

vgui.Register("ixUSMSRosterRow", ROW, "EditablePanel")
