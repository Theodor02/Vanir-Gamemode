--- USMS Loadout Panel
-- Displays current class info, available classes, loadout items and costs, gear-up button.

local PANEL = {}

function PANEL:Init()
    self.selectedClassKey = nil

    -- Top label
    self.header = self:Add("DLabel")
    self.header:Dock(TOP)
    self.header:SetTall(ix.ui.Scale(28))
    self.header:DockMargin(ix.ui.Scale(4), ix.ui.Scale(4), 0, ix.ui.Scale(2))
    self.header:SetFont("ixImpMenuSubtitle")
    self.header:SetTextColor(ix.ui.THEME.accent)
    self.header:SetText("CLASS & LOADOUT")

    -- Split: class selector (left) + loadout detail (right)
    self.splitContainer = self:Add("EditablePanel")
    self.splitContainer:Dock(FILL)
    self.splitContainer.Paint = function() end

    -- Class list
    self.classPanel = self.splitContainer:Add("DScrollPanel")
    self.classPanel:Dock(LEFT)
    self.classPanel:DockMargin(0, 0, ix.ui.Scale(4), 0)
    self.classPanel.Paint = function(s, w, h)
        surface.SetDrawColor(ix.ui.THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
    end

    local sbar = self.classPanel:GetVBar()
    sbar:SetWide(ix.ui.Scale(4))
    sbar.Paint = function() end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(s, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawRect(0, 0, w, h)
    end

    -- Loadout detail
    self.detailPanel = self.splitContainer:Add("EditablePanel")
    self.detailPanel:Dock(FILL)
    self.detailPanel.Paint = function(s, w, h)
        surface.SetDrawColor(ix.ui.THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
    end

    self.detailTitle = self.detailPanel:Add("DLabel")
    self.detailTitle:Dock(TOP)
    self.detailTitle:SetTall(ix.ui.Scale(28))
    self.detailTitle:DockMargin(ix.ui.Scale(8), ix.ui.Scale(4), 0, 0)
    self.detailTitle:SetFont("ixImpMenuSubtitle")
    self.detailTitle:SetTextColor(ix.ui.THEME.accent)
    self.detailTitle:SetText("")

    self.detailDesc = self.detailPanel:Add("DLabel")
    self.detailDesc:Dock(TOP)
    self.detailDesc:SetTall(ix.ui.Scale(20))
    self.detailDesc:DockMargin(ix.ui.Scale(8), 0, ix.ui.Scale(8), ix.ui.Scale(4))
    self.detailDesc:SetFont("ixImpMenuDiag")
    self.detailDesc:SetTextColor(ix.ui.THEME.textMuted)
    self.detailDesc:SetText("")

    -- Action row
    self.actionRow = self.detailPanel:Add("EditablePanel")
    self.actionRow:Dock(TOP)
    self.actionRow:SetTall(ix.ui.Scale(36))
    self.actionRow:DockMargin(ix.ui.Scale(4), 0, ix.ui.Scale(4), ix.ui.Scale(4))
    self.actionRow.Paint = function() end

    self.changeClassBtn = self:MakeButton(self.actionRow, "CHANGE CLASS", function()
        if (self.selectedClassKey) then
            ix.usms.Request("class_change", {classIndex = self.selectedClassKey})
        end
    end)
    self.changeClassBtn:Dock(LEFT)
    self.changeClassBtn:SetWide(ix.ui.Scale(140))
    self.changeClassBtn:DockMargin(0, ix.ui.Scale(2), ix.ui.Scale(4), ix.ui.Scale(2))

    self.gearUpBtn = self:MakeButton(self.actionRow, "GEAR UP", function()
        ix.usms.Request("gearup", {})
    end)
    self.gearUpBtn:Dock(LEFT)
    self.gearUpBtn:SetWide(ix.ui.Scale(100))
    self.gearUpBtn:DockMargin(0, ix.ui.Scale(2), ix.ui.Scale(4), ix.ui.Scale(2))

    self.whitelistBtn = self:MakeButton(self.actionRow, "MANAGE WHITELIST", function()
        self:OpenWhitelistManager()
    end)
    self.whitelistBtn:Dock(RIGHT)
    self.whitelistBtn:SetWide(ix.ui.Scale(140))
    self.whitelistBtn:DockMargin(ix.ui.Scale(4), ix.ui.Scale(2), 0, ix.ui.Scale(2))

    self.costLabel = self.actionRow:Add("DLabel")
    self.costLabel:Dock(FILL)
    self.costLabel:DockMargin(ix.ui.Scale(8), 0, 0, 0)
    self.costLabel:SetFont("ixImpMenuDiag")
    self.costLabel:SetTextColor(ix.ui.THEME.info)
    self.costLabel:SetText("")

    -- Loadout items scroll
    self.itemScroll = self.detailPanel:Add("DScrollPanel")
    self.itemScroll:Dock(FILL)
    self.itemScroll:DockMargin(ix.ui.Scale(4), 0, ix.ui.Scale(4), ix.ui.Scale(4))

    local sbar2 = self.itemScroll:GetVBar()
    sbar2:SetWide(ix.ui.Scale(4))
    sbar2.Paint = function() end
    sbar2.btnUp.Paint = function() end
    sbar2.btnDown.Paint = function() end
    sbar2.btnGrip.Paint = function(s, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawRect(0, 0, w, h)
    end

    -- Hooks
    hook.Add("USMSUnitDataUpdated", self, function(s) s:RebuildClasses() end)
    hook.Add("USMSRosterUpdated", self, function(s) s:RebuildClasses() end)

    self:RebuildClasses()
end

function PANEL:OnRemove()
    hook.Remove("USMSUnitDataUpdated", self)
    hook.Remove("USMSRosterUpdated", self)
end

function PANEL:PerformLayout(w, h)
    self.classPanel:SetWide(w * 0.30)
end

function PANEL:MakeButton(parent, text, onClick)
    local btn = parent:Add("DButton")
    btn:SetText("")
    btn.labelText = text
    btn.DoClick = onClick
    btn.Paint = function(s, w, h)
        local bg = s:IsHovered() and ix.ui.THEME.buttonBgHover or ix.ui.THEME.buttonBg
        surface.SetDrawColor(bg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(s.labelText, "ixImpMenuStatus", w * 0.5, h * 0.5, ix.ui.THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    return btn
end

function PANEL:GetAvailableClasses()
    local char = LocalPlayer():GetCharacter()
    if (!char) then return {} end

    local factionID = char:GetFaction()
    local classes = {}

    -- Get own whitelist from client cache
    local myWhitelist = ix.usms.clientData and ix.usms.clientData.myWhitelist or {}

    -- Iterate ix.class.list for matching faction classes
    for key, classData in pairs(ix.class.list or {}) do
        if (classData.faction == factionID) then
            -- Allow default classes and whitelisted classes
            if (classData.isDefault or table.HasValue(myWhitelist, classData.uniqueID)) then
                classes[key] = classData
            end
        end
    end

    return classes
end

function PANEL:RebuildClasses()
    self.classPanel:Clear()

    local char = LocalPlayer():GetCharacter()
    local currentClass = char and char:GetClass()
    local classes = self:GetAvailableClasses()

    -- Sort by name
    local sorted = {}
    for key, data in pairs(classes) do
        table.insert(sorted, {key = key, data = data})
    end
    table.sort(sorted, function(a, b) return (a.data.name or "") < (b.data.name or "") end)

    for _, entry in ipairs(sorted) do
        local card = self.classPanel:Add("EditablePanel")
        card:Dock(TOP)
        card:SetTall(ix.ui.Scale(44))
        card:DockMargin(ix.ui.Scale(4), ix.ui.Scale(2), ix.ui.Scale(4), ix.ui.Scale(2))
        card:SetMouseInputEnabled(true)
        card.classKey = entry.key
        card.classData = entry.data
        card.isCurrent = (entry.key == currentClass)

        card.OnMousePressed = function(s, code)
            if (code == MOUSE_LEFT) then
                self.selectedClassKey = s.classKey
                self:RebuildDetail()
            end
        end

        card.OnCursorEntered = function(s) s.bHovered = true end
        card.OnCursorExited = function(s) s.bHovered = false end

        card.Paint = function(s, w, h)
            local selected = (self.selectedClassKey == s.classKey)
            local bg = s.bHovered and ix.ui.THEME.buttonBgHover or ix.ui.THEME.buttonBg
            surface.SetDrawColor(bg)
            surface.DrawRect(0, 0, w, h)

            if (selected) then
                surface.SetDrawColor(ix.ui.THEME.accent)
                surface.DrawRect(0, 0, ix.ui.Scale(3), h)
            end

            if (s.isCurrent) then
                surface.SetDrawColor(ColorAlpha(ix.ui.THEME.ready, 40))
                surface.DrawRect(0, 0, w, h)
            end

            surface.SetDrawColor(ColorAlpha(ix.ui.THEME.frameSoft, 30))
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            local nameColor = s.isCurrent and ix.ui.THEME.ready or ix.ui.THEME.text
            local pad = ix.ui.Scale(10)
            draw.SimpleText(s.classData.name or ("Class #" .. s.classKey), "ixImpMenuButton", pad, ix.ui.Scale(6), nameColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            local tag = s.isCurrent and "CURRENT" or ""
            draw.SimpleText(tag, "ixImpMenuDiag", pad, ix.ui.Scale(26), ix.ui.THEME.ready, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end

    if (#sorted == 0) then
        local lbl = self.classPanel:Add("DLabel")
        lbl:Dock(TOP)
        lbl:SetTall(ix.ui.Scale(32))
        lbl:DockMargin(ix.ui.Scale(8), ix.ui.Scale(8), 0, 0)
        lbl:SetFont("ixImpMenuDiag")
        lbl:SetTextColor(ix.ui.THEME.textMuted)
        lbl:SetText("No classes available.")
    end

    -- Auto-select current class
    if (self.selectedClassKey == nil and currentClass) then
        self.selectedClassKey = currentClass
    end
    self:RebuildDetail()
end

function PANEL:RebuildDetail()
    self.itemScroll:Clear()

    if (!self.selectedClassKey) then
        self.detailTitle:SetText("< SELECT A CLASS >")
        self.detailDesc:SetText("")
        self.costLabel:SetText("")
        self.changeClassBtn:SetEnabled(false)
        self.gearUpBtn:SetEnabled(false)
        return
    end

    local classData = ix.class.list and ix.class.list[self.selectedClassKey]
    if (!classData) then
        self.detailTitle:SetText("< CLASS NOT FOUND >")
        self.detailDesc:SetText("")
        self.costLabel:SetText("")
        self.changeClassBtn:SetEnabled(false)
        self.gearUpBtn:SetEnabled(false)
        return
    end

    self.detailTitle:SetText(classData.name or "Unknown Class")
    self.detailDesc:SetText(classData.description or "")

    -- Loadout items
    local loadout = classData.loadout or {}
    local totalCost = 0

    local currentClass = LocalPlayer():GetCharacter() and LocalPlayer():GetCharacter():GetClass()
    self.changeClassBtn:SetEnabled(self.selectedClassKey != currentClass)
    -- FIX: GEAR UP visibility based on assigned class (char:GetClass()), not the browsed selection
    local assignedClassData = currentClass and currentClass > 0 and ix.class.list and ix.class.list[currentClass]
    local assignedLoadout = assignedClassData and assignedClassData.loadout or {}
    self.gearUpBtn:SetVisible(istable(assignedLoadout) and #assignedLoadout > 0)
    
    if (IsValid(self.whitelistBtn)) then
        local char = LocalPlayer():GetCharacter()
        self.whitelistBtn:SetVisible(char and (char:IsUnitOfficer() or LocalPlayer():IsSuperAdmin()) or false)
    end

    if (#loadout == 0) then
        local lbl = self.itemScroll:Add("DLabel")
        lbl:Dock(TOP)
        lbl:SetTall(ix.ui.Scale(24))
        lbl:DockMargin(ix.ui.Scale(8), ix.ui.Scale(4), 0, 0)
        lbl:SetFont("ixImpMenuDiag")
        lbl:SetTextColor(ix.ui.THEME.textMuted)
        lbl:SetText("No loadout items defined.")
    end

    -- Check player inventory for owned items
    local char = LocalPlayer():GetCharacter()
    local ownedItems = {}
    if (char) then
        local inv = char:GetInventory()
        if (inv) then
            for _, invItem in pairs(inv:GetItems()) do
                ownedItems[invItem.uniqueID] = true
            end
        end
    end

    for i, item in ipairs(loadout) do
        local itemName = item
        local itemCost = 0
        local itemUID = ""
        local itemDesc = ""
        local itemCategory = ""

        -- If loadout items have catalog cost, look them up
        if (type(item) == "table") then
            itemName = item.name or item.uniqueID or item[1] or "Unknown"
            itemCost = item.cost or 0
            itemUID = item.uniqueID or item[1] or ""
            itemDesc = item.description or ""
            itemCategory = item.category or ""
        elseif (type(item) == "string") then
            -- FIX: catalog lookup removed (sh_catalogs.lua deleted); log and skip string-format items
            ErrorNoHalt("[USMS] Loadout item is a string UID '" .. item .. "' — inline table format required. Skipping.\n")
            continue
        end

        totalCost = totalCost + itemCost

        local isOwned = ownedItems[itemUID] or false

        local row = self.itemScroll:Add("EditablePanel")
        row:Dock(TOP)
        row:SetTall(ix.ui.Scale(34))
        row:DockMargin(0, ix.ui.Scale(1), 0, 0)
        row:SetMouseInputEnabled(true)
        row.rowIndex = i
        row.itemName = itemName
        row.itemCost = itemCost
        row.itemUID = itemUID
        row.itemDesc = itemDesc
        row.itemCategory = itemCategory
        row.isOwned = isOwned

        row.OnCursorEntered = function(s)
            s.bHovered = true
            -- Show tooltip if item has a description
            if (s.itemDesc != "" and !IsValid(s.tooltip)) then
                local tip = vgui.Create("EditablePanel")
                tip:SetSize(ix.ui.Scale(220), ix.ui.Scale(60))
                tip:SetDrawOnTop(true)
                tip.desc = s.itemDesc
                tip.Paint = function(t, w, h)
                    surface.SetDrawColor(20, 20, 20, 240)
                    surface.DrawRect(0, 0, w, h)
                    surface.SetDrawColor(ix.ui.THEME.frameSoft)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    draw.DrawText(t.desc, "ixImpMenuDiag", ix.ui.Scale(6), ix.ui.Scale(6), ix.ui.THEME.text, TEXT_ALIGN_LEFT)
                end
                tip:SetParent(vgui.GetWorldPanel())
                local mx, my = gui.MousePos()
                tip:SetPos(mx + ix.ui.Scale(12), my - ix.ui.Scale(30))
                s.tooltip = tip
            end
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

            -- Left color bar: green if owned, muted if not
            local barColor = s.isOwned and ix.ui.THEME.ready or Color(60, 60, 60, 100)
            surface.SetDrawColor(barColor)
            surface.DrawRect(0, 0, ix.ui.Scale(3), h)

            local pad = ix.ui.Scale(10)

            -- Category tag (small, muted, left-aligned)
            if (s.itemCategory != "") then
                draw.SimpleText(string.upper(s.itemCategory), "ixImpMenuStatus", pad, ix.ui.Scale(3), ix.ui.THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(s.itemName, "ixImpMenuDiag", pad, ix.ui.Scale(16), ix.ui.THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            else
                draw.SimpleText(s.itemName, "ixImpMenuDiag", pad, h * 0.5, ix.ui.THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            -- Owned indicator
            if (s.isOwned) then
                draw.SimpleText("✓", "ixImpMenuDiag", w - ix.ui.Scale(40), h * 0.5, ix.ui.THEME.ready, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end

            -- Cost
            if (s.itemCost > 0) then
                draw.SimpleText("-" .. s.itemCost, "ixImpMenuDiag", w - ix.ui.Scale(8), h * 0.5, ix.ui.THEME.info, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end

            -- Bottom separator
            surface.SetDrawColor(ColorAlpha(ix.ui.THEME.frameSoft, 15))
            surface.DrawRect(0, h - 1, w, 1)
        end
    end

    self.costLabel:SetText("Total Cost: " .. totalCost .. " resources")
end

function PANEL:Paint(w, h)
end

function PANEL:OpenWhitelistManager()
    local char = LocalPlayer():GetCharacter()
    if (!char) then return end

    local roster = ix.usms.clientData and ix.usms.clientData.roster or {}
    if (#roster == 0) then return end

    local menu = DermaMenu()
    for _, entry in ipairs(roster) do
        local targetCharID = entry.charID
        local targetName = entry.name or "Unknown"
        local targetRole = entry.role or 0

        -- Only manage lower/equal rank unless superadmin
        if (LocalPlayer():IsSuperAdmin() or targetRole <= char:GetUsmUnitRole()) then
            local targetWhitelist = entry.classWhitelist or {}
            local plyMenu = menu:AddSubMenu(targetName)

            for key, classData in pairs(ix.class.list or {}) do
                if (classData.faction == char:GetFaction() and classData.uniqueID and !classData.isDefault) then
                    local isWhitelisted = table.HasValue(targetWhitelist, classData.uniqueID)
                    local label = (isWhitelisted and "[X] " or "[ ] ") .. (classData.name or classData.uniqueID)
                    plyMenu:AddOption(label, function()
                        if (isWhitelisted) then
                            ix.usms.Request("class_whitelist_remove", {charID = targetCharID, classUID = classData.uniqueID})
                        else
                            ix.usms.Request("class_whitelist_add", {charID = targetCharID, classUID = classData.uniqueID})
                        end
                    end)
                end
            end
        end
    end
    menu:Open()
end

vgui.Register("ixUSMSLoadoutPanel", PANEL, "EditablePanel")
