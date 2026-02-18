local THEME = {
	background = Color(10, 10, 10, 255),
	frame = Color(191, 148, 53, 255),
	frameSoft = Color(191, 148, 53, 120),
	text = Color(235, 235, 235, 255),
	textMuted = Color(168, 168, 168, 140),
	accent = Color(191, 148, 53, 255),
	accentSoft = Color(191, 148, 53, 220),
	danger = Color(180, 60, 60, 255),
	ready = Color(60, 170, 90, 255),
	buttonBg = Color(16, 16, 16, 255),
	buttonBgHover = Color(26, 26, 26, 255)
}

local SOUND_HOVER = "everfall/miscellaneous/ux/navigation/navigation_tab_01.mp3"
local SOUND_CLICK = "everfall/miscellaneous/ux/navigation/navigation_activate_01.mp3"
local SOUND_ERROR = "everfall/miscellaneous/ux/navigation/navigation_error_01.mp3"

local function Scale(value)
	return math.max(1, math.Round(value * (ScrH() / 900)))
end

-- Helper functions from cl_charcreate.lua
local function DrawScreeningPanel(panel, width, height, headerText)
	local now = CurTime()
	local flicker = 0.85 + (math.sin(now * 2.4) + 1) * 0.075
	local innerPad = Scale(10)
	local footerHeight = panel.__ixImpFooterHeight or 0
	local drawH = height - footerHeight
	local headerH = Scale(24)

	local innerX = innerPad - Scale(2)
	local innerY = headerH + innerPad
	local innerW = width - innerPad * 2
	local innerH = drawH - innerY - Scale(46)

	surface.SetDrawColor(Color(0, 0, 0, 255))
	surface.DrawRect(0, 0, width, height)
	
	-- Header Bar
	surface.SetDrawColor(THEME.frameSoft)
	surface.DrawRect(0, 0, width, headerH)
	
	-- Frame Outline
	surface.DrawOutlinedRect(0, 0, width, drawH)

	-- Static Header
	draw.SimpleText(headerText, "ixImpMenuButton", Scale(8), headerH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText("BIOSCAN", "ixImpMenuDiag", width - Scale(8), headerH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	local scanY = innerY + (now * 40 % innerH)
	surface.SetDrawColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 35))
	
	if (scanY < innerY + innerH) then
		surface.DrawRect(innerX, scanY, innerW, Scale(2))
	end

	surface.SetDrawColor(Color(255, 255, 255, 6))
	for i = 0, 6 do
		surface.DrawLine(innerX, innerY + (i / 6) * innerH, innerX + innerW, innerY + (i / 6) * innerH)
	end

    -- Animated boxes clamped to bottom
	local barY = drawH - Scale(24) -- Pushed down since aurebesh is gone
	for i = 1, 3 do
		local phase = now * (0.7 + i * 0.4)
		local fill = 0.35 + (math.sin(phase) + 1) * 0.3
        local barH = Scale(6)
        
        -- Ensure bar doesn't go below drawH
        if (barY + barH > drawH) then break end

		surface.SetDrawColor(Color(255, 255, 255, 10))
		surface.DrawRect(innerX, barY, innerW, barH)
		surface.SetDrawColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 120))
		surface.DrawRect(innerX, barY, innerW * fill, barH)
		barY = barY - Scale(10) -- Stack upwards from bottom
	end
end

local function ApplyScreeningPanel(panel, headerText)
	if (!IsValid(panel)) then return end
	panel.Paint = function(this, width, height)
		DrawScreeningPanel(this, width, height, headerText)
	end
end

local function ApplyDataPanel(panel, headerText)
	if (!IsValid(panel)) then return end
	panel.Paint = function(this, width, height)
		surface.SetDrawColor(Color(0, 0, 0, 200))
		surface.DrawRect(0, 0, width, height)

		local headerH = Scale(24)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawRect(0, 0, width, headerH)
        surface.DrawOutlinedRect(0, 0, width, height)

		draw.SimpleText(headerText, "ixImpMenuButton", Scale(8), headerH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

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
    
    self.returnButton = leftFooter:Add("ixImpMenuButtonChar")
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
    ApplyDataPanel(leftPanel, "PERSONNEL DATABASE")
    
    self.characterList = leftPanel:Add("DScrollPanel")
    self.characterList:Dock(FILL)
    self.characterList:DockMargin(Scale(8), Scale(32), Scale(8), Scale(8)) -- Make room for header
    self.characterList.Paint = function(this, w, h) end -- Transparent
    
    -- Custom scrollbar
    local vbar = self.characterList:GetVBar()
    vbar:SetWide(Scale(4))
    vbar.Paint = function() end
    vbar.btnUp.Paint = function() end
    vbar.btnDown.Paint = function() end
    vbar.btnGrip.Paint = function(this, w, h)
        surface.SetDrawColor(THEME.accentSoft)
        surface.DrawRect(0, 0, w, h)
    end

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
    
    self.playButton = footer:Add("ixImpMenuButtonChar")
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

    self.deleteButton = footer:Add("ixImpMenuButtonChar")
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
    
    ApplyScreeningPanel(modelPanelContainer, "BIOMETRIC SCAN")

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

        local charBtn = self.characterList:Add("ixImpMenuButtonChar")
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
