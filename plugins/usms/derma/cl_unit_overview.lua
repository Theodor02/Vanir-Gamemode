--- USMS Unit Overview Sidebar
-- Shows unit info, current squad, and loadout summary in the left sidebar.

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
    danger = Color(180, 60, 60, 255),
    ready = Color(60, 170, 90, 255)
}

local function Scale(value)
    return math.max(1, math.Round(value * (ScrH() / 900)))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- UNIT OVERVIEW PANEL
-- ═══════════════════════════════════════════════════════════════════════════════

local PANEL = {}

function PANEL:Init()
    self.scroll = self:Add("DScrollPanel")
    self.scroll:Dock(FILL)

    local sbar = self.scroll:GetVBar()
    sbar:SetWide(Scale(4))
    sbar.Paint = function() end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, 0, w, h)
    end

    -- Unit info section
    self:CreateUnitSection()

    -- Squad section
    self:CreateSquadSection()

    -- Loadout section
    self:CreateLoadoutSection()

    -- Listen for data updates
    hook.Add("USMSUnitDataUpdated", self, function(s, data)
        s:RefreshUnit()
    end)
    hook.Add("USMSResourcesUpdated", self, function(s, unitID, res, cap)
        s:RefreshUnit()
    end)
    hook.Add("USMSRosterUpdated", self, function(s, unitID, roster)
        s:RefreshSquad()
    end)
end

function PANEL:OnRemove()
    hook.Remove("USMSUnitDataUpdated", self)
    hook.Remove("USMSResourcesUpdated", self)
    hook.Remove("USMSRosterUpdated", self)
end

function PANEL:CreateUnitSection()
    -- Section header
    local header = self.scroll:Add("DLabel")
    header:SetFont("ixImpMenuSubtitle")
    header:SetTextColor(THEME.accent)
    header:SetText("UNIT STATUS")
    header:Dock(TOP)
    header:DockMargin(Scale(8), Scale(8), Scale(8), Scale(4))
    header:SizeToContents()

    -- Separator
    local sep = self.scroll:Add("Panel")
    sep:Dock(TOP)
    sep:SetTall(1)
    sep:DockMargin(Scale(8), 0, Scale(8), Scale(8))
    sep.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, 0, w, h)
    end

    -- Unit name
    self.unitName = self.scroll:Add("DLabel")
    self.unitName:SetFont("ixImpMenuButton")
    self.unitName:SetTextColor(THEME.text)
    self.unitName:SetText("NO UNIT ASSIGNED")
    self.unitName:Dock(TOP)
    self.unitName:DockMargin(Scale(8), 0, Scale(8), Scale(2))
    self.unitName:SizeToContents()

    -- Faction
    self.factionLabel = self.scroll:Add("DLabel")
    self.factionLabel:SetFont("ixImpMenuDiag")
    self.factionLabel:SetTextColor(THEME.textMuted)
    self.factionLabel:SetText("")
    self.factionLabel:Dock(TOP)
    self.factionLabel:DockMargin(Scale(8), 0, Scale(8), Scale(4))
    self.factionLabel:SizeToContents()

    -- Resources
    self.resourceLabel = self.scroll:Add("DLabel")
    self.resourceLabel:SetFont("ixImpMenuStatus")
    self.resourceLabel:SetTextColor(THEME.text)
    self.resourceLabel:SetText("")
    self.resourceLabel:Dock(TOP)
    self.resourceLabel:DockMargin(Scale(8), 0, Scale(8), Scale(2))
    self.resourceLabel:SizeToContents()

    -- Resource bar
    self.resourceBar = self.scroll:Add("Panel")
    self.resourceBar:Dock(TOP)
    self.resourceBar:SetTall(Scale(6))
    self.resourceBar:DockMargin(Scale(8), 0, Scale(8), Scale(4))
    self.resourceBar.fraction = 0
    self.resourceBar.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.buttonBg)
        surface.DrawRect(0, 0, w, h)

        local barColor = THEME.ready
        if (s.fraction < 0.40) then
            barColor = THEME.danger
        elseif (s.fraction < 0.75) then
            barColor = THEME.accent
        end
        surface.SetDrawColor(barColor)
        surface.DrawRect(0, 0, w * s.fraction, h)
    end

    -- Member count
    self.memberLabel = self.scroll:Add("DLabel")
    self.memberLabel:SetFont("ixImpMenuStatus")
    self.memberLabel:SetTextColor(THEME.textMuted)
    self.memberLabel:SetText("")
    self.memberLabel:Dock(TOP)
    self.memberLabel:DockMargin(Scale(8), 0, Scale(8), Scale(8))
    self.memberLabel:SizeToContents()

    self:RefreshUnit()
end

function PANEL:CreateSquadSection()
    local header = self.scroll:Add("DLabel")
    header:SetFont("ixImpMenuSubtitle")
    header:SetTextColor(THEME.accent)
    header:SetText("SQUAD")
    header:Dock(TOP)
    header:DockMargin(Scale(8), Scale(4), Scale(8), Scale(4))
    header:SizeToContents()

    local sep = self.scroll:Add("Panel")
    sep:Dock(TOP)
    sep:SetTall(1)
    sep:DockMargin(Scale(8), 0, Scale(8), Scale(8))
    sep.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, 0, w, h)
    end

    self.squadName = self.scroll:Add("DLabel")
    self.squadName:SetFont("ixImpMenuButton")
    self.squadName:SetTextColor(THEME.text)
    self.squadName:SetText("NO SQUAD")
    self.squadName:Dock(TOP)
    self.squadName:DockMargin(Scale(8), 0, Scale(8), Scale(2))
    self.squadName:SizeToContents()

    self.squadRole = self.scroll:Add("DLabel")
    self.squadRole:SetFont("ixImpMenuDiag")
    self.squadRole:SetTextColor(THEME.textMuted)
    self.squadRole:SetText("")
    self.squadRole:Dock(TOP)
    self.squadRole:DockMargin(Scale(8), 0, Scale(8), Scale(4))
    self.squadRole:SizeToContents()

    self.squadMembers = self.scroll:Add("DLabel")
    self.squadMembers:SetFont("ixImpMenuStatus")
    self.squadMembers:SetTextColor(THEME.textMuted)
    self.squadMembers:SetText("")
    self.squadMembers:Dock(TOP)
    self.squadMembers:DockMargin(Scale(8), 0, Scale(8), Scale(8))
    self.squadMembers:SizeToContents()

    self:RefreshSquad()
end

function PANEL:CreateLoadoutSection()
    local header = self.scroll:Add("DLabel")
    header:SetFont("ixImpMenuSubtitle")
    header:SetTextColor(THEME.accent)
    header:SetText("LOADOUT")
    header:Dock(TOP)
    header:DockMargin(Scale(8), Scale(4), Scale(8), Scale(4))
    header:SizeToContents()

    local sep = self.scroll:Add("Panel")
    sep:Dock(TOP)
    sep:SetTall(1)
    sep:DockMargin(Scale(8), 0, Scale(8), Scale(8))
    sep.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, 0, w, h)
    end

    self.classLabel = self.scroll:Add("DLabel")
    self.classLabel:SetFont("ixImpMenuButton")
    self.classLabel:SetTextColor(THEME.text)
    self.classLabel:SetText("UNASSIGNED")
    self.classLabel:Dock(TOP)
    self.classLabel:DockMargin(Scale(8), 0, Scale(8), Scale(8))
    self.classLabel:SizeToContents()

    self:RefreshLoadout()
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- REFRESH METHODS
-- ═══════════════════════════════════════════════════════════════════════════════

function PANEL:RefreshUnit()
    local unit = ix.usms.clientData.unit

    if (!unit) then
        self.unitName:SetText("NO UNIT ASSIGNED")
        self.factionLabel:SetText("")
        self.resourceLabel:SetText("")
        self.memberLabel:SetText("")
        self.resourceBar.fraction = 0
        return
    end

    self.unitName:SetText(unit.name or "Unknown")
    self.unitName:SizeToContents()

    local faction = ix.faction.indices[unit.factionID]
    self.factionLabel:SetText(faction and faction.name or "Unknown Faction")
    self.factionLabel:SizeToContents()

    -- Resource display based on role
    local char = LocalPlayer():GetCharacter()
    local isOfficer = char and char:IsUnitOfficer()

    if (isOfficer) then
        self.resourceLabel:SetText(string.format("RESOURCES: %d / %d", unit.resources, unit.resourceCap))
        self.resourceLabel:SetVisible(true)
        self.resourceBar:SetVisible(true)
        self.resourceBar.fraction = unit.resourceCap > 0 and (unit.resources / unit.resourceCap) or 0
    else
        self.resourceLabel:SetText("SUPPLY: " .. ix.usms.GetResourceStatus(unit.resources, unit.resourceCap))
        self.resourceLabel:SetVisible(true)
        self.resourceBar:SetVisible(false)
    end
    self.resourceLabel:SizeToContents()

    local rosterCount = #ix.usms.clientData.roster
    self.memberLabel:SetText(string.format("PERSONNEL: %d / %d", rosterCount, unit.maxMembers or 30))
    self.memberLabel:SizeToContents()
end

function PANEL:RefreshSquad()
    local char = LocalPlayer():GetCharacter()
    if (!char or !char:IsInSquad()) then
        self.squadName:SetText("NO SQUAD")
        self.squadRole:SetText("")
        self.squadMembers:SetText("")
        return
    end

    local squadID = char:GetUsmSquadID()
    local squadData = ix.usms.clientData.squads[squadID]

    -- Get squad name from synced data, or from HUD NetVar fallback
    local name = ""
    if (squadData and squadData.name and squadData.name != "") then
        name = squadData.name
    else
        name = LocalPlayer():GetNetVar("ixSquadName", "")
    end

    if (name == "") then
        name = "SQUAD #" .. squadID
    end

    self.squadName:SetText(name)
    self.squadName:SizeToContents()

    local squadRole = char:GetUsmSquadRole()
    local roleText = "MEMBER"
    if (squadRole == USMS_SQUAD_LEADER) then
        roleText = "SQUAD LEADER"
    elseif (squadRole == USMS_SQUAD_XO) then
        roleText = "SQUAD XO"
    elseif (squadRole == USMS_SQUAD_INVITER) then
        roleText = "INVITER"
    end
    self.squadRole:SetText(roleText)
    self.squadRole:SizeToContents()

    -- Count squad members from roster
    local memberCount = 0
    local maxSize = 8
    for _, entry in ipairs(ix.usms.clientData.roster) do
        if (entry.squadID == squadID) then
            memberCount = memberCount + 1
        end
    end

    self.squadMembers:SetText(string.format("MEMBERS: %d / %d", memberCount, maxSize))
    self.squadMembers:SizeToContents()
end

function PANEL:RefreshLoadout()
    local char = LocalPlayer():GetCharacter()
    if (!char) then return end

    local classIndex = char:GetClass()
    if (classIndex and classIndex > 0) then
        local classInfo = ix.class.list[classIndex]
        self.classLabel:SetText(classInfo and classInfo.name or "Unknown Class")
    else
        self.classLabel:SetText("UNASSIGNED")
    end
    self.classLabel:SizeToContents()
end

function PANEL:Paint(w, h)
    surface.SetDrawColor(12, 12, 12, 255)
    surface.DrawRect(0, 0, w, h)

    -- Gold border on right
    surface.SetDrawColor(THEME.frameSoft)
    surface.DrawRect(w - 1, 0, 1, h)
end

vgui.Register("ixUSMSUnitOverview", PANEL, "EditablePanel")
