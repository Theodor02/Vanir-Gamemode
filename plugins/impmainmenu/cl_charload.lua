local THEME = ix.ui.THEME
local Scale = ix.ui.Scale

DEFINE_BASECLASS("ixCharMenuPanel")
local PANEL = {}

function PANEL:Init()
	local parent = self:GetParent()
	self:SetSize(parent:GetSize())
	self:SetPos(0, 0)

	local padding = Scale(32)
	local halfWidth = parent:GetWide() * 0.5 - (padding * 2)
	local halfHeight = parent:GetTall() * 0.5 - (padding * 2)
	local modelFOV = (ScrW() > ScrH() * 1.8) and 100 or 78

    -- LEFT SIDE: Character List (Data Panel style) + Info + Return Button
    local leftContainer = self:Add("Panel")
    leftContainer:Dock(LEFT)
    leftContainer:SetWide(halfWidth)
    leftContainer:DockMargin(padding, padding, 0, padding)

    -- Footer for Return Button (Outside Data Panel)
    local leftFooter = leftContainer:Add("Panel")
    leftFooter:Dock(BOTTOM)
    leftFooter:SetTall(Scale(64))
    leftFooter:DockMargin(0, Scale(8), 0, 0)
    
    self.returnButton = leftFooter:Add("ixImpButton")
    self.returnButton:SetLabel("RETURN")
    self.returnButton:SetStyle("default")
    self.returnButton:Dock(FILL)
    self.returnButton.DoClick = function()
        self:SlideDown()
        parent.mainPanel:Undim()
    end    

    -- Info Box (Bottom of Left Container)
    self.infoPanel = leftContainer:Add("Panel")
    self.infoPanel:Dock(BOTTOM)
    self.infoPanel:SetTall(Scale(140))
    self.infoPanel:DockMargin(0, Scale(8), 0, 0)
    
    self.infoPanel.Paint = function(this, w, h)
        -- Draw Standard Background & Header
        surface.SetDrawColor(Color(0, 0, 0, 200))
        surface.DrawRect(0, 0, w, h)

        local headerH = Scale(24)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, 0, w, headerH)
        surface.DrawOutlinedRect(0, 0, w, h)

        draw.SimpleText("IDENTITY RECORD", "ixImpMenuButton", Scale(8), headerH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        if (!self.selectedCharacter) then return end
        
        local char = self.selectedCharacter
        local factionIdx = char:GetFaction()
        local faction = ix.faction.indices[factionIdx]
        local factionName = faction and faction.name or "UNKNOWN"
        local backgrounds = char:GetBackgrounds() or {}
        local backgroundText = ""

        for k, _ in pairs(backgrounds) do
            local bck = ix.backgrounds[k]
            if bck then
                backgroundText = backgroundText .. bck.name .. ", "
            end
        end

        if backgroundText ~= "" then
            backgroundText = backgroundText:sub(1, -3) -- Remove trailing ", "
        end
        -- local factionColor = faction and faction.color or THEME.text
        
        local y = headerH + Scale(12)
        local x = Scale(12)
        
        surface.SetFont("ixImpMenuTitle")
        local name = char:GetName()
        draw.SimpleText(name, "ixImpMenuTitle", x, y, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        local _, th = surface.GetTextSize(name)
        y = y + th + Scale(4) 
        
        draw.SimpleText("BACKGROUND: " .. string.upper(backgroundText), "ixImpMenuLabel", x, y, THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        y = y + Scale(18)

        local desc = char:GetDescription()
        if (desc and #desc > 0) then
            -- Simple wrap
            local wAvail = w - x * 2
            local words = string.Explode(" ", desc)
            local line = ""
            for i, word in ipairs(words) do
                local test = line .. word .. " "
                surface.SetFont("ixImpMenuLabel")
                local tw, _ = surface.GetTextSize(test)
                if (tw > wAvail) then
                    draw.SimpleText(line, "ixImpMenuLabel", x, y, THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    y = y + Scale(14)
                    line = word .. " "
                else
                    line = test
                end
            end
            draw.SimpleText(line, "ixImpMenuLabel", x, y, THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end
    
    self.infoDummy = self.infoPanel:Add("Panel") -- Dummy for invalidation triggers
    self.infoDummy:SetVisible(false)

    -- Data Panel for List
    local leftPanel = leftContainer:Add("Panel")
    leftPanel:Dock(FILL)
    ix.ui.ApplyDataPanel(leftPanel, "PERSONNEL DATABASE")
    
    self.characterList = leftPanel:Add("DScrollPanel")
    self.characterList:Dock(FILL)
    self.characterList:DockMargin(Scale(8), Scale(32), Scale(8), Scale(8)) -- Make room for header
    self.characterList.Paint = function(this, w, h) end -- Transparent
    
    -- Custom scrollbar
    ix.ui.ApplyScrollbarStyle(self.characterList)

    -- RIGHT SIDE: Character Preview (Screening Panel style)
    local rightPanel = self:Add("Panel")
    rightPanel:Dock(RIGHT)
    rightPanel:SetWide(halfWidth)
    rightPanel:DockMargin(0, padding, padding, padding)

    -- Footer for buttons
    local footer = rightPanel:Add("Panel")
    footer:Dock(BOTTOM)
    footer:SetTall(Scale(64))
    footer:DockMargin(0, Scale(8), 0, 0)
    
    self.playButton = footer:Add("ixImpButton")
    self.playButton:SetLabel("DEPLOY")
    self.playButton:SetStyle("accent")
    self.playButton:Dock(RIGHT)
    self.playButton:SetWide(halfWidth * 0.48)
    self.playButton:SetDisabled(true)
    self.playButton.DoClick = function()
        if (self.selectedCharacter) then
            self:Dim()
            net.Start("ixCharacterChoose")
                net.WriteUInt(self.selectedCharacter:GetID(), 32)
            net.SendToServer()
        end
    end

    self.deleteButton = footer:Add("ixImpButton")
    self.deleteButton:SetLabel("TERMINATE")
    self.deleteButton:SetStyle("danger")
    self.deleteButton:Dock(LEFT)
    self.deleteButton:SetWide(halfWidth * 0.48)
    self.deleteButton:SetDisabled(true)
    self.deleteButton.DoClick = function()
        if (self.selectedCharacter) then
            -- Confirmation
            Derma_Query("Are you sure you want to terminate this personnel record?", "CONFIRM TERMINATION", 
                "Yes", function() 
                    net.Start("ixCharacterDelete")
                        net.WriteUInt(self.selectedCharacter:GetID(), 32)
                    net.SendToServer()
                    self.selectedCharacter = nil
                    self.playButton:SetDisabled(true)
                    self.deleteButton:SetDisabled(true)
                    self.model:SetModel("models/error.mdl")
                    self.infoDummy:InvalidateLayout()
                    -- Refresh happens automatically via hook usually, or we can force it
                end,
                "No", nil
            )
        end
    end

    -- Model Preview
    local modelPanelContainer = rightPanel:Add("Panel")
    modelPanelContainer:Dock(FILL)

    self.model = modelPanelContainer:Add("ixModelPanel")
    self.model:Dock(FILL)
    self.model:SetModel("") -- Empty model initially
    self.model:SetFOV(modelFOV)
    self.model.PaintModel = self.model.Paint
    
    -- Hide the model if model path is invalid/empty to avoid error model
    local oldPaint = self.model.Paint
    self.model.Paint = function(this, w, h)
        if (!this:GetModel() or this:GetModel() == "" or this:GetModel() == "models/error.mdl") then return end
        oldPaint(this, w, h)
    end
    
    ix.ui.ApplyScreeningPanel(modelPanelContainer, "BIOMETRIC SCAN")

    -- Character Info overlay removed (Moved to left panel)
end

function PANEL:OnSlideUp()
	self.bActive = true
	self:Populate()
end

function PANEL:OnSlideDown()
	self.bActive = false
end

function PANEL:Populate()
    self.characterList:Clear()
    self.selectedCharacter = nil
    self.playButton:SetDisabled(true)
    self.deleteButton:SetDisabled(true)
    self.model:SetModel("") 

    local characters = ix.characters or {}
    
    for _, id in ipairs(characters) do
        local character = ix.char.loaded[id]
        
        if (!character) then
            continue
        end

        local charBtn = self.characterList:Add("ixImpButton")
        charBtn:SetLabel(character:GetName())
        charBtn:Dock(TOP)
        charBtn:DockMargin(0, 0, 0, Scale(4))
        charBtn:SetTall(Scale(40))
        charBtn.DoClick = function()
            self.selectedCharacter = character
            self.playButton:SetDisabled(false)
            self.deleteButton:SetDisabled(false)
            
            -- Update Model
            self.model:SetModel(character:GetModel())

            -- Highlight selection
            for _, child in ipairs(self.characterList:GetCanvas():GetChildren()) do
                if (child.SetStyle) then child:SetStyle("default") end
            end
            charBtn:SetStyle("accent")
            
            -- Redraw info panel
            self.infoDummy:InvalidateLayout()
        end
    end
end

function PANEL:OnCharacterDeleted(character)
    local deletedId = character and character.GetID and character:GetID() or nil

    if (self.selectedCharacter and deletedId and self.selectedCharacter:GetID() == deletedId) then
        self.selectedCharacter = nil
    end

    self:Populate()
end

function PANEL:Paint(width, height)
    surface.SetDrawColor(THEME.background)
	surface.DrawRect(0, 0, width, height)
	
    local framePad = Scale(26)
    surface.SetDrawColor(THEME.frame)
	surface.DrawOutlinedRect(framePad, framePad, width - framePad * 2, height - framePad * 2)

    BaseClass.Paint(self, width, height)
end

vgui.Register("ixCharMenuLoad", PANEL, "ixCharMenuPanel")
