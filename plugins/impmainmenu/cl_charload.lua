local THEME = ix.ui.THEME
local Scale = ix.ui.Scale

local function ThemeTextPrimary()
    return THEME.textPri or THEME.text
end

local function ThemeTextSecondary()
    return THEME.textSec or THEME.textMuted
end

local function ThemeSeparator()
    return THEME.sep or Color(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 45)
end

local function CreateMainMenuButton(parent, label, isDanger)
    local button = parent:Add("DButton")
    button:SetText(string.upper(label))
    button:SetFont("ixImpMenuButton")
    button:SetTextColor(THEME.textMuted)
    
    button.Paint = function(this, w, h)
        local accentColor = isDanger and (THEME.danger or Color(210, 50, 50)) or THEME.accent

        if (this:GetDisabled()) then
            this:SetTextColor(Color(100, 100, 100, 100))
        elseif (this:IsHovered()) then
            this:SetTextColor(accentColor)
            
            surface.SetDrawColor(accentColor)
            surface.DrawRect(0, 0, Scale(2), h)
            surface.DrawRect(w - Scale(2), 0, Scale(2), h)
            
            surface.SetDrawColor(Color(accentColor.r, accentColor.g, accentColor.b, 15))
            surface.DrawRect(0, 0, w, h)
        else
            this:SetTextColor(THEME.textMuted)
            
            surface.SetDrawColor(Color(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b, 15))
            surface.DrawLine(0, h - 1, w, h - 1)
        end
    end

    return button
end

local function ApplyCharacterModelData(modelPanel, character)
    if (!IsValid(modelPanel) or !character) then
        return
    end

    modelPanel:SetModel(character:GetModel() or "models/error.mdl")

    local function ConfigureEntity()
        if (!IsValid(modelPanel) or !IsValid(modelPanel.Entity)) then
            return
        end

        local entity = modelPanel.Entity
        entity:SetSkin(character:GetData("skin", 0))

        for i = 0, (entity:GetNumBodyGroups() - 1) do
            entity:SetBodygroup(i, 0)
        end

        local bodygroups = character:GetData("groups")
        if (istable(bodygroups)) then
            for k, v in pairs(bodygroups) do
                entity:SetBodygroup(k, v)
            end
        end

        local mins, maxs = entity:GetRenderBounds()
        local center = (mins + maxs) * 0.5
        local size = (maxs - mins):Length()
        local distance = math.max(size * 1.50, 110) -- Increased multiplier to perfectly frame taller models without cutting them off

        modelPanel:SetLookAt(center)
        modelPanel:SetFOV(35)
        modelPanel:SetCamPos(center + Vector(distance, 0, 0))
        entity:SetAngles(Angle(0, 45, 0))
    end

    timer.Simple(0, ConfigureEntity)
end

DEFINE_BASECLASS("ixCharMenuPanel")
local PANEL = {}

function PANEL:Init()
    BaseClass.Init(self)

    local parent = self:GetParent()
    self:SetSize(parent:GetSize())
    self.animationTime = 1
    self.selectedCharacter = nil

    self.contentWidth = math.min(ScrW() * 0.75, Scale(1200))
    self.sidePadding = (ScrW() - self.contentWidth) * 0.5

    self.main = self:AddSubpanel("main", true)
    self.main:SetTitle(nil)

    if (IsValid(self.main.title)) then
        self.main.title:SetVisible(false)
        self.main.title:SetTall(0)
    end

    self.main:DockPadding(self.sidePadding, Scale(64), self.sidePadding, Scale(12))

    self.titleBlock = self.main:Add("Panel")
    self.titleBlock:Dock(TOP)
    self.titleBlock:SetTall(Scale(74))
    self.titleBlock:DockMargin(0, 0, 0, Scale(5))
    self.titleBlock.Paint = function(this, w, h)
        local pri = ThemeTextPrimary()
        local sec = ThemeSeparator()

        draw.SimpleText("PERSONNEL", "ixImpMenuTitle", 0, 0, pri, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        local subtitle = "DATABASE"
        local spacing = Scale(4)
        local textW, textH = ix.ui.GetSpacedTextSize(subtitle, "ixImpMenuSubtitle", spacing)
        local barPadX = Scale(12)
        local barPadY = Scale(4)
        local barW = textW + (barPadX * 2) - spacing
        local barY = Scale(50)  -- Pushed down slightly below title text
        local barH = textH + (barPadY * 2)

        surface.SetDrawColor(THEME.accent)
        surface.DrawRect(0, barY, barW, barH)
        ix.ui.DrawSpacedText(subtitle, "ixImpMenuSubtitle", barPadX, barY + barPadY, THEME.background, spacing, TEXT_ALIGN_LEFT)

        surface.SetDrawColor(sec)
        surface.DrawLine(0, h - 1, w, h - 1)
    end

    self.body = self.main:Add("Panel")
    self.body:Dock(FILL)

    self.buttonRow = self.main:Add("Panel")
    self.buttonRow:Dock(BOTTOM)
    self.buttonRow:SetTall(Scale(48))
    self.buttonRow:DockMargin(0, Scale(16), 0, Scale(10))
    self.buttonRow.Paint = function(_, w)
        surface.SetDrawColor(ThemeSeparator())
        surface.DrawLine(0, 0, w, 1)
    end

    self.returnButton = CreateMainMenuButton(self.buttonRow, "RETURN", false)
    self.returnButton:Dock(LEFT)
    self.returnButton:SetWide(Scale(170))
    self.returnButton:SetTall(Scale(36))
    self.returnButton:DockMargin(0, Scale(6), 0, Scale(6))
    self.returnButton.DoClick = function(this)
        if (this:GetDisabled()) then
            surface.PlaySound(ix.ui.SOUND_ERROR)
            return
        end
        surface.PlaySound(ix.ui.SOUND_CLICK)

        self:SlideDown()
        parent.mainPanel:Undim()
    end

    self.deleteButton = CreateMainMenuButton(self.buttonRow, "TERMINATE", true)
    self.deleteButton:Dock(LEFT)
    self.deleteButton:SetWide(Scale(190))
    self.deleteButton:SetTall(Scale(36))
    self.deleteButton:DockMargin(Scale(10), Scale(6), 0, Scale(6))
    self.deleteButton:SetDisabled(true)
    self.deleteButton.DoClick = function(this)
        if (this:GetDisabled()) then
            surface.PlaySound(ix.ui.SOUND_ERROR)
            return
        end
        surface.PlaySound(ix.ui.SOUND_CLICK)

        if (!self.selectedCharacter) then
            return
        end

        Derma_Query("Are you sure you want to terminate this personnel record?", "CONFIRM TERMINATION",
            "Yes", function()
                net.Start("ixCharacterDelete")
                    net.WriteUInt(self.selectedCharacter:GetID(), 32)
                net.SendToServer()
            end,
            "No", nil
        )
    end

    self.playButton = CreateMainMenuButton(self.buttonRow, "DEPLOY", false)
    self.playButton:Dock(RIGHT)
    self.playButton:SetWide(Scale(170))
    self.playButton:SetTall(Scale(36))
    self.playButton:DockMargin(0, Scale(6), 0, Scale(6))
    self.playButton:SetDisabled(true)
    self.playButton.DoClick = function(this)
        if (this:GetDisabled()) then
            surface.PlaySound(ix.ui.SOUND_ERROR)
            return
        end
        surface.PlaySound(ix.ui.SOUND_CLICK)

        if (!self.selectedCharacter) then
            return
        end

        self:SlideDown(self.animationTime, function()
            net.Start("ixCharacterChoose")
                net.WriteUInt(self.selectedCharacter:GetID(), 32)
            net.SendToServer()
        end, true)
    end

    self.rightPanel = self.body:Add("Panel")
    self.rightPanel:Dock(RIGHT)
    self.rightPanel:SetWide(math.floor(self.contentWidth * 0.40))
    self.rightPanel:DockMargin(Scale(16), 0, 0, 0)

    self.scanPanel = self.rightPanel:Add("Panel")
    self.scanPanel:Dock(FILL)
    -- ix.ui.ApplyScreeningPanel(self.scanPanel, "BIOMETRIC SCAN")

    self.aurebeshPanel = self.scanPanel:Add("Panel")
    self.aurebeshPanel:Dock(TOP)
    self.aurebeshPanel:SetTall(Scale(10)) -- Shrink to give more height to the model
    self.aurebeshPanel:DockMargin(Scale(12), Scale(10), Scale(12), Scale(8))
    -- self.aurebeshPanel.Paint = function(_, w, h)
    --     local muted = ThemeTextSecondary()
    --     surface.SetDrawColor(ThemeSeparator())
    --     surface.DrawLine(0, h - 1, w, h - 1)

    --     draw.SimpleText("STANDBY", "ixImpMenuAurebesh", 0, Scale(2), Color(muted.r, muted.g, muted.b, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    --     draw.SimpleText("JMK-PRIME // KX9", "ixImpMenuAurebesh", 0, Scale(22), Color(muted.r, muted.g, muted.b, 130), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    --     draw.SimpleText("VISUAL LINK // 2090", "ixImpMenuAurebesh", 0, Scale(38), Color(muted.r, muted.g, muted.b, 130), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    --     draw.SimpleText("CALIBRATING", "ixImpMenuAurebesh", 0, Scale(54), Color(muted.r, muted.g, muted.b, 130), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    -- end

    self.modelTopSep = self.scanPanel:Add("Panel")
    self.modelTopSep:Dock(TOP)
    self.modelTopSep:SetTall(1)
    self.modelTopSep.Paint = function(_, w, h)
        surface.SetDrawColor(ThemeSeparator())
        surface.DrawRect(0, 0, w, h)
    end

    self.modelArea = self.scanPanel:Add("Panel")
    self.modelArea:Dock(FILL)
    self.modelArea:DockMargin(0, Scale(0), 0, Scale(4))
    self.modelArea.Paint = function() end

    self.model = self.modelArea:Add("DModelPanel")
    self.model:Dock(FILL)
    self.model:DockMargin(Scale(12), 0, Scale(12), 0)
    self.model:SetModel("models/error.mdl")
    self.model.LayoutEntity = function(_, ent)
        if (IsValid(ent)) then
            ent:SetAngles(Angle(0, 30, 0))
        end
    end

    self.modelBottomSep = self.scanPanel:Add("Panel")
    self.modelBottomSep:Dock(BOTTOM)
    self.modelBottomSep:SetTall(1)
    self.modelBottomSep.Paint = function(_, w, h)
        surface.SetDrawColor(ThemeSeparator())
        surface.DrawRect(0, 0, w, h)
    end

    -- self.scanLines = self.scanPanel:Add("Panel")
    -- self.scanLines:Dock(BOTTOM)
    -- self.scanLines:SetTall(Scale(50))
    -- self.scanLines:DockMargin(Scale(12), Scale(8), Scale(12), Scale(8))
    -- self.scanLines.Paint = function(_, w, h)
    --     local centerX = w * 0.5
    --     local opacities = {102, 64, 38, 25}
    --     for i, alpha in ipairs(opacities) do
    --         local lineW = w - (i - 1) * Scale(16)
    --         local lineX = centerX - lineW * 0.5
    --         local y = (i - 1) * Scale(8)
    --         surface.SetDrawColor(Color(201, 168, 76, alpha))
    --         surface.DrawRect(lineX, y, lineW, 2)
    --     end
    -- end

    self.leftPanel = self.body:Add("Panel")
    self.leftPanel:Dock(FILL)
    self.leftPanel:DockMargin(0, 0, Scale(12), 0)
    self.leftPanel.Paint = function() end

    self.listPanel = self.leftPanel:Add("Panel")
    self.listPanel:Dock(FILL)
    self.listPanel:DockMargin(0, 0, 0, Scale(12))
    -- ix.ui.ApplyDataPanel(self.listPanel, "PERSONNEL DATABASE")
    -- local baseListPaint = self.listPanel.Paint
    -- self.listPanel.Paint = function(this, w, h)
    --     surface.SetDrawColor(THEME.panel or THEME.bg or Color(0, 0, 0, 200))
    --     surface.DrawRect(0, 0, w, h)
        
    --     baseListPaint(this, w, h)

    --     -- local lineStep = Scale(24)
    --     -- surface.SetDrawColor(ThemeSeparator())
    --     -- for y = Scale(36), h, lineStep do
    --     --     surface.DrawLine(Scale(6), y, w - Scale(6), y)
    --     -- end
    -- end

    self.characterList = self.listPanel:Add("DScrollPanel")
    self.characterList:Dock(FILL)
    self.characterList:DockMargin(Scale(8), Scale(30), Scale(8), Scale(8))
    self.characterList.Paint = function() end
    ix.ui.ApplyScrollbarStyle(self.characterList)

    self.infoPanel = self.leftPanel:Add("Panel")
    self.infoPanel:Dock(BOTTOM)
    self.infoPanel:SetTall(Scale(180))
    self.infoPanel:DockMargin(0, Scale(16), 0, 0)
    self.infoPanel.Paint = function(_, w)
        if (!self.selectedCharacter) then return end

        local char = self.selectedCharacter
        local backgrounds = char:GetBackgrounds() or {}
        local backgroundText = ""

        for k, _ in pairs(backgrounds) do
            local bck = ix.backgrounds[k]
            if (bck) then
                backgroundText = backgroundText .. bck.name .. ", "
            end
        end

        if (backgroundText != "") then
            backgroundText = backgroundText:sub(1, -3)
        else
            backgroundText = "UNCLASSIFIED"
        end

        local titleSpacing = Scale(2)
        local headerFont = "ixImpMenuSubtitle"
        local headerText = "BACKGROUND: " .. string.upper(backgroundText)
        local textW, textH = ix.ui.GetSpacedTextSize(headerText, headerFont, titleSpacing)
        local barPadX = Scale(12)
        local barPadY = Scale(4)
        local barW = textW + (barPadX * 2) - titleSpacing
        local barH = textH + (barPadY * 2)

        surface.SetDrawColor(THEME.accent)
        surface.DrawRect(0, 0, barW, barH)
        ix.ui.DrawSpacedText(headerText, headerFont, barPadX, barPadY, THEME.background, titleSpacing, TEXT_ALIGN_LEFT)

        local x = Scale(12)
        local y = barH + Scale(16) -- Added breathing room between header and name
        local pri = ThemeTextPrimary()

        surface.SetFont("ixImpMenuTitle")
        local name = char:GetName()
        draw.SimpleText(name, "ixImpMenuTitle", x, y, pri, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        local _, titleH = surface.GetTextSize(name)
        y = y + titleH + Scale(12)

        local desc = char:GetDescription()
        if (desc and #desc > 0) then
            local wAvail = w - x * 2
            local words = string.Explode(" ", desc)
            local line = ""

            for _, word in ipairs(words) do
                local test = line .. word .. " "
                surface.SetFont("ixImpMenuLabel")
                local tw = surface.GetTextSize(test)

                if (tw > wAvail) then
                    draw.SimpleText(line, "ixImpMenuLabel", x, y, ThemeTextSecondary(), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    y = y + Scale(20)
                    line = word .. " "
                else
                    line = test
                end
            end

            draw.SimpleText(line, "ixImpMenuLabel", x, y, ThemeTextSecondary(), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end

    self:SetActiveSubpanel("main", 0)
end

function PANEL:SetSelectedCharacter(character)
    self.selectedCharacter = character

    local hasCharacter = istable(self.selectedCharacter) and isfunction(self.selectedCharacter.GetID)
    self.playButton:SetDisabled(!hasCharacter)
    self.deleteButton:SetDisabled(!hasCharacter)

    if (hasCharacter) then
        ApplyCharacterModelData(self.model, character)
    else
        self.model:SetModel("models/error.mdl")
    end

    self.infoPanel:InvalidateLayout(true)
end

function PANEL:Populate(ignoreID)
    self.characterList:Clear()
    self:SetSelectedCharacter(nil)

    local selectedButton
    local localCharacter = LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()

    for i = 1, #ix.characters do
        local id = ix.characters[i]
        local character = ix.char.loaded[id]

        if (!character or character:GetID() == ignoreID) then
            continue
        end

        local faction = ix.faction.indices[character:GetFaction()]
        local factionLabel = faction and string.upper(L(faction.name)) or "UNKNOWN"

        local row = self.characterList:Add("DButton")
        row:Dock(TOP)
        row:SetTall(Scale(42))
        row:DockMargin(0, 0, 0, 0)
        row:SetText("")
        row.character = character
        row.rowIndex = i

        row.Paint = function(s, w, h)
            local hovered = s:IsHovered()
            local selected = (self.selectedCharacter == s.character)

            ix.ui.PaintRow(w, h, s.rowIndex, hovered)

            if (selected) then
                surface.SetDrawColor(THEME.accent)
                surface.DrawRect(0, 0, Scale(2), h)
            elseif (hovered) then
                surface.SetDrawColor(ThemeTextSecondary())
                surface.DrawRect(0, 0, Scale(2), h)
            end

            surface.SetDrawColor(ThemeSeparator())
            surface.DrawRect(0, h - 1, w, 1)

            local nameColor = selected and THEME.accent or (hovered and ThemeTextPrimary() or ThemeTextSecondary())
            draw.SimpleText(s.character:GetName(), "ixImpMenuLabel", Scale(10), h * 0.5, nameColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(factionLabel, "ixImpMenuStatus", w - Scale(10), h * 0.5, nameColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        row.DoClick = function(s)
            self:SetSelectedCharacter(s.character)
        end

        if (localCharacter and character:GetID() == localCharacter:GetID()) then
            selectedButton = row
        end
    end

    if (!IsValid(selectedButton)) then
        local children = self.characterList:GetCanvas():GetChildren()
        selectedButton = children and children[1] or nil
    end

    if (IsValid(selectedButton)) then
        selectedButton:DoClick()
        self.characterList:ScrollToChild(selectedButton)
    end
end

function PANEL:OnSlideUp()
    self.bActive = true

    if (IsValid(self.main.title)) then
        self.main.title:SetVisible(false)
        self.main.title:SetTall(0)
    end

    self:Populate()
end

function PANEL:OnSlideDown()
    self.bActive = false
end

function PANEL:OnCharacterDeleted(character)
    local deletedID = character and character.GetID and character:GetID() or nil
    if (self.selectedCharacter and deletedID and self.selectedCharacter:GetID() == deletedID) then
        self:SetSelectedCharacter(nil)
    end

    self:Populate(deletedID)

    if (self.bActive and #ix.characters == 0) then
        self:SlideDown()
    end
end

function PANEL:Paint(width, height)
    local framePad = Scale(46)
    local notchLength = Scale(32)
    local suffixAlpha = 150

    draw.SimpleText("IMPERIAL ARCHIVES", "ixImpMenuLabel", framePad, framePad - Scale(16), ThemeTextSecondary(), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText("NODE // 07", "ixImpMenuLabel", framePad, framePad, THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    local rightText = "GUEST"
    local ply = LocalPlayer()
    if (ply.GetCharacter and ply:GetCharacter()) then
        rightText = string.upper(ply:GetCharacter():GetName())
    end
    draw.SimpleText("USR // " .. rightText, "ixImpMenuLabel", width - framePad, framePad, THEME.accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    surface.SetDrawColor(THEME.accentSoft)
    surface.DrawLine(framePad, height - framePad, framePad + notchLength, height - framePad)
    surface.DrawLine(framePad, height - framePad, framePad, height - framePad - notchLength)
    draw.SimpleText("SYSTEM ACTIVE", "ixImpMenuAurebesh", framePad + notchLength + Scale(8), height - framePad + Scale(2), Color(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b, suffixAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

    surface.DrawLine(width - framePad, height - framePad, width - framePad - notchLength, height - framePad)
    surface.DrawLine(width - framePad, height - framePad, width - framePad, height - framePad - notchLength)
    draw.SimpleText("AUTH LVL 3", "ixImpMenuAurebesh", width - framePad - notchLength - Scale(8), height - framePad + Scale(2), Color(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b, suffixAlpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
end

vgui.Register("ixCharMenuLoad", PANEL, "ixCharMenuPanel")
