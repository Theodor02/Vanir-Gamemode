--- USMS Tab Menu Registration & Main Panel Container
-- Registers the "DEPLOYMENT" tab in the Helix tab menu.

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
    rowEven = Color(14, 14, 14, 255),
    rowOdd = Color(18, 18, 18, 255),
    rowHover = Color(24, 22, 14, 255),
    danger = Color(180, 60, 60, 255),
    ready = Color(60, 170, 90, 255)
}

local function Scale(value)
    return math.max(1, math.Round(value * (ScrH() / 900)))
end

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
    self.sidebar:DockMargin(0, 0, Scale(4), 0)

    -- Right content area
    self.content = self:Add("EditablePanel")
    self.content:Dock(FILL)

    -- Tab bar at top of content area
    self.tabBar = self.content:Add("EditablePanel")
    self.tabBar:Dock(TOP)
    self.tabBar:SetTall(Scale(32))
    self.tabBar:DockMargin(0, 0, 0, Scale(4))

    self:CreateTabButtons()

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

    self.missionPanel = self.content:Add("ixUSMSMissionPanel")
    if IsValid(self.missionPanel) then
        self.missionPanel:Dock(FILL)
        self.missionPanel:SetVisible(false)
    end

    self.intelPanel = self.content:Add("ixUSMSIntelPanel")
    if IsValid(self.intelPanel) then
        self.intelPanel:Dock(FILL)
        self.intelPanel:SetVisible(false)
    end

    self.helpPanel = self.content:Add("ixUSMSHelpPanel")
    if IsValid(self.helpPanel) then
        self.helpPanel:Dock(FILL)
        self.helpPanel:SetVisible(false)
    end

    self:SetActiveTab("roster")
end

function PANEL:CreateTabButtons()
    local tabs = {"roster", "squads", "loadout", "missions", "logs", "intel", "info"}
    self.tabButtons = {}

    for i, tabName in ipairs(tabs) do
        local btn = self.tabBar:Add("DButton")
        btn:SetText(string.upper(tabName))
        btn:SetFont("ixImpMenuButton")
        btn:SetTextColor(THEME.text)
        btn:Dock(LEFT)
        btn:SetWide(Scale(100))
        btn.tabName = tabName
        btn.Paint = function(s, w, h)
            local bg = s:IsHovered() and THEME.buttonBgHover or THEME.buttonBg
            if (self.activeTab == s.tabName) then
                bg = Color(30, 28, 18, 255)
            end
            surface.SetDrawColor(bg)
            surface.DrawRect(0, 0, w, h)

            if (self.activeTab == s.tabName) then
                surface.SetDrawColor(THEME.accent)
                surface.DrawRect(0, h - Scale(2), w, Scale(2))
            end
        end
        btn.DoClick = function(s)
            self:SetActiveTab(s.tabName)
        end

        self.tabButtons[tabName] = btn
    end
end

function PANEL:SetActiveTab(tabName)
    self.activeTab = tabName

    if IsValid(self.rosterPanel) then self.rosterPanel:SetVisible(tabName == "roster") end
    if IsValid(self.squadPanel) then self.squadPanel:SetVisible(tabName == "squads") end
    if IsValid(self.loadoutPanel) then self.loadoutPanel:SetVisible(tabName == "loadout") end
    if IsValid(self.missionPanel) then self.missionPanel:SetVisible(tabName == "missions") end
    if IsValid(self.logPanel) then self.logPanel:SetVisible(tabName == "logs") end
    if IsValid(self.intelPanel) then self.intelPanel:SetVisible(tabName == "intel") end
    if IsValid(self.helpPanel) then self.helpPanel:SetVisible(tabName == "info") end

    if (tabName == "logs") then
        ix.usms.Request("log_request", {limit = 100})
    elseif (tabName == "missions") then
        ix.usms.Request("mission_request", {})
    end
end

function PANEL:PerformLayout(w, h)
    if (IsValid(self.sidebar)) then
        self.sidebar:SetWide(w * 0.25)
    end
end

function PANEL:Paint(w, h)
    surface.SetDrawColor(THEME.background)
    surface.DrawRect(0, 0, w, h)
end

vgui.Register("ixUSMSMainPanel", PANEL, "EditablePanel")
