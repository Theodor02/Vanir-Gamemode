--- USMS Help & Info Panel
-- Describes all unit and squad roles, permissions, and system overview.

local THEME = {
    background = Color(10, 10, 10, 255),
    frame = Color(191, 148, 53, 255),
    frameSoft = Color(191, 148, 53, 120),
    text = Color(235, 235, 235, 255),
    textMuted = Color(168, 168, 168, 140),
    accent = Color(191, 148, 53, 255),
    accentSoft = Color(191, 148, 53, 220),
    buttonBg = Color(16, 16, 16, 255),
    panelBg = Color(12, 12, 12, 255),
    ready = Color(60, 170, 90, 255),
    danger = Color(180, 60, 60, 255),
    supply = Color(80, 140, 200, 255)
}

local function Scale(value)
    return math.max(1, math.Round(value * (ScrH() / 900)))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- HELP PANEL
-- ═══════════════════════════════════════════════════════════════════════════════

local PANEL = {}

function PANEL:Init()
    self.scroll = self:Add("DScrollPanel")
    self.scroll:Dock(FILL)
    self.scroll:DockMargin(Scale(4), Scale(4), Scale(4), Scale(4))

    local sbar = self.scroll:GetVBar()
    sbar:SetWide(Scale(4))
    sbar.Paint = function() end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, 0, w, h)
    end

    self:BuildContent()
end

function PANEL:AddSectionHeader(text)
    local header = self.scroll:Add("DLabel")
    header:SetFont("ixImpMenuSubtitle")
    header:SetTextColor(THEME.accent)
    header:SetText(text)
    header:Dock(TOP)
    header:DockMargin(Scale(8), Scale(12), Scale(8), Scale(2))
    header:SizeToContents()

    local sep = self.scroll:Add("Panel")
    sep:Dock(TOP)
    sep:SetTall(1)
    sep:DockMargin(Scale(8), Scale(2), Scale(8), Scale(8))
    sep.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, 0, w, h)
    end
end

function PANEL:AddRoleEntry(roleName, roleColor, permissions)
    local container = self.scroll:Add("EditablePanel")
    container:Dock(TOP)
    container:DockMargin(Scale(8), 0, Scale(8), Scale(8))
    container:SetTall(Scale(20) + #permissions * Scale(16))

    container.Paint = function(s, w, h)
        -- Role name
        draw.SimpleText(roleName, "ixImpMenuButton", Scale(4), Scale(2), roleColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        -- Permissions list
        local y = Scale(20)
        for _, perm in ipairs(permissions) do
            draw.SimpleText("• " .. perm, "ixImpMenuDiag", Scale(16), y, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            y = y + Scale(16)
        end
    end
end

function PANEL:AddTextBlock(text)
    local lbl = self.scroll:Add("DLabel")
    lbl:SetFont("ixImpMenuDiag")
    lbl:SetTextColor(THEME.text)
    lbl:SetText(text)
    lbl:SetWrap(true)
    lbl:SetAutoStretchVertical(true)
    lbl:Dock(TOP)
    lbl:DockMargin(Scale(12), 0, Scale(12), Scale(8))
end

function PANEL:BuildContent()
    -- ═══════════════════════════════════════════════════
    -- OVERVIEW
    -- ═══════════════════════════════════════════════════
    self:AddSectionHeader("SYSTEM OVERVIEW")
    self:AddTextBlock("The Unit & Squad Management System (USMS) organizes personnel into military units and operational squads. Each unit has a command structure, resource pool, and class-based loadout system. Squads are smaller tactical groups within a unit.")

    -- ═══════════════════════════════════════════════════
    -- UNIT ROLES
    -- ═══════════════════════════════════════════════════
    self:AddSectionHeader("UNIT ROLES")

    self:AddRoleEntry("COMMANDING OFFICER (CO)", THEME.accent, {
        "Full unit authority — highest rank",
        "Set any unit member's role (except assigning CO — use transfer)",
        "Invite or remove any member from the unit",
        "Assign classes and manage loadouts",
        "View unit logs and resource information",
        "Create and manage squads",
        "Transfer CO status to another member"
    })

    self:AddRoleEntry("EXECUTIVE OFFICER (XO)", THEME.accentSoft, {
        "Second-in-command of the unit",
        "Invite or remove members (cannot remove CO or other XOs)",
        "Assign classes to unit members",
        "View unit logs and resource information",
        "Create and manage squads"
    })

    self:AddRoleEntry("MEMBER", THEME.text, {
        "Standard unit member",
        "Can view roster and own squad information",
        "Can request gear-up (if class assigned)",
        "Can join or leave squads",
        "Cannot view detailed logs or modify other members"
    })

    -- ═══════════════════════════════════════════════════
    -- SQUAD ROLES
    -- ═══════════════════════════════════════════════════
    self:AddSectionHeader("SQUAD ROLES")

    self:AddRoleEntry("SQUAD LEADER (SL)", THEME.accent, {
        "Full squad authority",
        "Invite, kick, and manage squad members",
        "Assign squad roles (XO, Inviter, Member)",
        "Disband the squad",
        "Automatically assigned to squad creator"
    })

    self:AddRoleEntry("SQUAD XO", THEME.accentSoft, {
        "Second-in-command of the squad",
        "Can invite new members to the squad",
        "Can kick lower-ranked squad members",
        "Cannot disband the squad or assign roles"
    })

    self:AddRoleEntry("INVITER", THEME.ready, {
        "Trusted member with invite permissions",
        "Can invite unit members to the squad",
        "Cannot kick members or manage roles"
    })

    self:AddRoleEntry("SQUAD MEMBER", THEME.text, {
        "Standard squad member",
        "Can leave the squad at any time",
        "No management permissions"
    })

    -- ═══════════════════════════════════════════════════
    -- RESOURCES & LOADOUTS
    -- ═══════════════════════════════════════════════════
    self:AddSectionHeader("RESOURCES & LOADOUTS")
    self:AddTextBlock("Each unit has a shared resource pool. Classes define what equipment a member can draw from the armory via the 'Gear Up' function. Gear costs resources — CO/XO can see exact numbers, while members see a general supply status (ABUNDANT, STEADY, LOW, CRITICAL).")

    -- ═══════════════════════════════════════════════════
    -- HOW-TO
    -- ═══════════════════════════════════════════════════
    self:AddSectionHeader("QUICK REFERENCE")
    self:AddTextBlock("ROSTER TAB — View all unit members. Right-click a member for actions (role assignment, kick, squad invite). Click column headers to sort.")
    self:AddTextBlock("SQUADS TAB — View and manage squads. Click a squad card to see its members. Right-click squad members for role/kick options. Use the buttons at the top to create or leave squads.")
    self:AddTextBlock("LOGS TAB — Activity log for CO/XO. Filter by action type and browse pages.")
    self:AddTextBlock("INVITES — When invited to a unit or squad, a popup will appear. You have 60 seconds to accept or decline.")
end

function PANEL:Paint(w, h)
end

vgui.Register("ixUSMSHelpPanel", PANEL, "EditablePanel")
