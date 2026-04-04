--- USMS Tab Menu Registration & Main Panel Container
-- Registers the "DEPLOYMENT" tab in the Helix tab menu.

-- ═══════════════════════════════════════════════════════════════════════════════
-- TAB REGISTRATION
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("CreateMenuButtons", "ixUSMS", function(tabs)
    local char = LocalPlayer():GetCharacter()
    if (!char) then return end

    tabs["deployment"] = function(container)
        local panel = container:Add("ixUSMSMainPanel")
        panel:Dock(FILL)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- MAIN PANEL
-- ═══════════════════════════════════════════════════════════════════════════════

local PANEL = {}

function PANEL:Init()
    self.activeTab = "roster"

    -- Request roster data from server
    ix.usms.Request("roster_request", {})

    -- Left sidebar (25% width)
    self.sidebar = self:Add("ixUSMSUnitOverview")
    self.sidebar:Dock(LEFT)
    self.sidebar:DockMargin(0, 0, ix.ui.Scale(4), 0)

    -- Right content area
    self.content = self:Add("EditablePanel")
    self.content:Dock(FILL)

    -- Tab bar at top of content area
    self.tabBar = self.content:Add("EditablePanel")
    self.tabBar:Dock(TOP)
    self.tabBar:SetTall(ix.ui.Scale(32))
    self.tabBar:DockMargin(0, 0, 0, ix.ui.Scale(4))

    self:CreateTabButtons()

    -- FIX: Hide LOGS tab for non-officers; re-evaluate on role change (item 9)
    hook.Add("USMSUnitDataUpdated", self, function(s) s:RefreshTabVisibility() end)
    self:RefreshTabVisibility()

    -- Content panels (IsValid guards for load-order safety)
    self.rosterPanel = self.content:Add("ixUSMSRosterPanel")
    if IsValid(self.rosterPanel) then
        self.rosterPanel:Dock(FILL)
    end

    self.squadPanel = self.content:Add("ixUSMSSquadPanel")
    if IsValid(self.squadPanel) then
        self.squadPanel:Dock(FILL)
        self.squadPanel:SetVisible(false)
    end

    self.logPanel = self.content:Add("ixUSMSLogPanel")
    if IsValid(self.logPanel) then
        self.logPanel:Dock(FILL)
        self.logPanel:SetVisible(false)
    end

    self.loadoutPanel = self.content:Add("ixUSMSLoadoutPanel")
    if IsValid(self.loadoutPanel) then
        self.loadoutPanel:Dock(FILL)
        self.loadoutPanel:SetVisible(false)
    end

    self:SetActiveTab("roster")
end

function PANEL:CreateTabButtons()
    local tabs = {"roster", "squads", "loadout", "logs"}
    self.tabButtons = {}

    for i, tabName in ipairs(tabs) do
        local btn = self.tabBar:Add("DButton")
        btn:SetText(string.upper(tabName))
        btn:SetFont("ixImpMenuButton")
        btn:SetTextColor(ix.ui.THEME.text)
        btn:Dock(LEFT)
        btn:SetWide(ix.ui.Scale(120)) -- Increased from 100 to fit fewer tabs
        btn.tabName = tabName
        btn.Paint = function(s, w, h)
            local bg = s:IsHovered() and ix.ui.THEME.buttonBgHover or ix.ui.THEME.buttonBg
            if (self.activeTab == s.tabName) then
                bg = Color(30, 28, 18, 255)
            end
            surface.SetDrawColor(bg)
            surface.DrawRect(0, 0, w, h)

            if (self.activeTab == s.tabName) then
                surface.SetDrawColor(ix.ui.THEME.accent)
                surface.DrawRect(0, h - ix.ui.Scale(2), w, ix.ui.Scale(2))
            end
        end
        btn.DoClick = function(s)
            self:SetActiveTab(s.tabName)
        end

        self.tabButtons[tabName] = btn
    end
end

function PANEL:OnRemove()
    hook.Remove("USMSUnitDataUpdated", self)
end

function PANEL:RefreshTabVisibility()
    local char = LocalPlayer():GetCharacter()
    local isOfficer = (char and char:IsUnitOfficer()) or LocalPlayer():IsSuperAdmin()
    local logsBtn = self.tabButtons and self.tabButtons["logs"]
    if (IsValid(logsBtn)) then
        logsBtn:SetVisible(isOfficer)
    end
    -- If currently on logs tab and no longer officer, switch to roster
    if (self.activeTab == "logs" and !isOfficer) then
        self:SetActiveTab("roster")
    end
end

function PANEL:SetActiveTab(tabName)
    self.activeTab = tabName

    if IsValid(self.rosterPanel) then self.rosterPanel:SetVisible(tabName == "roster") end
    if IsValid(self.squadPanel) then self.squadPanel:SetVisible(tabName == "squads") end
    if IsValid(self.loadoutPanel) then self.loadoutPanel:SetVisible(tabName == "loadout") end
    if IsValid(self.logPanel) then self.logPanel:SetVisible(tabName == "logs") end

    -- Hide sidebar for non-relevant tabs
    local showSidebar = (tabName == "roster" or tabName == "squads")
    if IsValid(self.sidebar) then
        self.sidebar:SetVisible(showSidebar)
    end

    if (tabName == "logs") then
        ix.usms.Request("log_request", {limit = 100})
    elseif (tabName == "roster" or tabName == "squads") then
        ix.usms.Request("roster_request", {})
    end
end

function PANEL:PerformLayout(w, h)
    if (IsValid(self.sidebar) and self.sidebar:IsVisible()) then
        self.sidebar:SetWide(w * 0.25)
    end
end

function PANEL:Paint(w, h)
    surface.SetDrawColor(ix.ui.THEME.background)
    surface.DrawRect(0, 0, w, h)
end

vgui.Register("ixUSMSMainPanel", PANEL, "EditablePanel")
