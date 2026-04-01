local THEME = ix.ui.THEME
local Scale = ix.ui.Scale

DEFINE_BASECLASS("ixCharMenuPanel")
local PANEL = {}

AccessorFunc(PANEL, "bUsingCharacter", "UsingCharacter", FORCE_BOOL)

function PANEL:Init()
	local parent = self:GetParent()
	self:SetSize(parent:GetSize())
	self:SetPos(0, 0)

	self.padding = Scale(24)
	self.framePadding = Scale(26)

	self.bUsingCharacter = LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()

	self.buttons = {}

	self.createButton = self:AddMenuButton("ENLIST", "default", function()
		local maximum = hook.Run("GetMaxPlayerCharacter", LocalPlayer()) or ix.config.Get("maxCharacters", 5)

		if (#ix.characters >= maximum) then
			self:GetParent():ShowNotice(3, L("maxCharacters"))
			return
		end

		self:Dim()
		parent.newCharacterPanel:SetActiveSubpanel("faction", 0)
		parent.newCharacterPanel:SlideUp()
	end)

	self.loadButton = self:AddMenuButton("DEPLOY", "default", function()
		self:Dim()
		parent.loadCharacterPanel:SlideUp()
	end)

	if (#ix.characters == 0) then
		self.loadButton:SetDisabled(true)
	end

	local extraURL = ix.config.Get("communityURL", "")
	self.communityButton = self:AddMenuButton("COMMUNITY NODE", "default", function()
		if (extraURL != "") then
			gui.OpenURL(extraURL)
		end
	end)

	if (extraURL == "") then
		self.communityButton:SetDisabled(true)
	end

	self.returnButton = self:AddMenuButton("RETURN", "default", function()
		if (self.bUsingCharacter) then
			parent:Close()
		else
			RunConsoleCommand("disconnect")
		end
	end)

	self:UpdateReturnButton()

	self.statusPanel = self:Add("Panel")
	self.statusPanel:SetMouseInputEnabled(false)

	self.statusReady = self.statusPanel:Add("ixImpStatus")
	self.statusReady:SetTextValue("SYS READY")
	self.statusReady:SetColors(THEME.ready, THEME.ready)

	self.statusAuth = self.statusPanel:Add("ixImpStatus")
	self.statusAuth:SetTextValue("AUTH-LVL 3")
	self.statusAuth:SetColors(THEME.accent, THEME.accent)

	self.statusHelix = self.statusPanel:Add("ixImpStatus")
	self.statusHelix:SetTextValue("HELIX")
	self.statusHelix:SetColors(THEME.accent, THEME.accent)

	self:InvalidateLayout(true)
end

function PANEL:AddMenuButton(label, style, onClick)
	local button = self:Add("DButton")
	button:SetText(string.upper(label))
	button:SetFont("ixImpMenuButton")
	button:SetTextColor(THEME.textMuted)
	
	button.DoClick = function(this)
		if (this:GetDisabled()) then
			surface.PlaySound(ix.ui.SOUND_ERROR)
			return
		end

		surface.PlaySound(ix.ui.SOUND_CLICK)
		if (isfunction(onClick)) then
			onClick()
		end
	end
	
	button.Paint = function(this, w, h)
		if (this:GetDisabled()) then
			this:SetTextColor(Color(100, 100, 100, 100))
		elseif (this:IsHovered()) then
			this:SetTextColor(THEME.accent)
			
			-- Clean side brackets for hover instead of full box
			surface.SetDrawColor(THEME.accent)
			surface.DrawRect(0, 0, Scale(2), h)
			surface.DrawRect(w - Scale(2), 0, Scale(2), h)
			
			-- Very subtle background highlight
			surface.SetDrawColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 15))
			surface.DrawRect(0, 0, w, h)
		else
			this:SetTextColor(THEME.textMuted)
			
			-- Idle state minimal bottom line to anchor the text cleanly without creating a cluttered box
			surface.SetDrawColor(Color(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b, 15))
			surface.DrawLine(0, h - 1, w, h - 1)
		end
	end

	self.buttons[#self.buttons + 1] = button
	return button
end

function PANEL:UpdateReturnButton(bValue)
	if (bValue != nil) then
		self.bUsingCharacter = bValue
	end

	local label = "RETURN"
	self.returnButton:SetText(label)
end

function PANEL:OnDim()
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
end

function PANEL:OnUndim()
	self:SetMouseInputEnabled(true)
	self:SetKeyboardInputEnabled(true)

	self.bUsingCharacter = LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()
	self:UpdateReturnButton()
end

function PANEL:OnClose()
	for _, panel in ipairs(self:GetChildren()) do
		if (IsValid(panel)) then
			panel:SetVisible(false)
		end
	end
end

function PANEL:PerformLayout(width, height)
	local yOffset = self.menuSlideY or 0
	
	local buttonWidth = math.min(width * 0.25, Scale(350))
	local buttonHeight = Scale(50)
	local buttonGap = Scale(12)

	local totalHeight = (#self.buttons * buttonHeight) + (#self.buttons - 1) * buttonGap
	local startX = width * 0.5 - buttonWidth * 0.5
	local startY = height * 0.45 + yOffset

	for i, button in ipairs(self.buttons) do
		button:SetSize(buttonWidth, buttonHeight)
		button:SetPos(startX, startY + (i - 1) * (buttonHeight + buttonGap))
	end

	local statusHeight = Scale(22)
	local statusGap = Scale(10)
	local statusWidth = math.max(Scale(72), math.Round(width * 0.08))
	local statusTotal = statusWidth * 3 + statusGap * 2
	local statusX = width * 0.5 - statusTotal * 0.5
	local statusY = height - Scale(30) + yOffset

	if IsValid(self.statusPanel) then
		self.statusPanel:SetPos(statusX, statusY)
		self.statusPanel:SetSize(statusTotal, statusHeight)
		self.statusPanel:SetVisible(false) 
	end

	if IsValid(self.statusReady) then
		self.statusReady:SetSize(statusWidth, statusHeight)
		self.statusReady:SetPos(0, 0)
	end

	if IsValid(self.statusAuth) then
		self.statusAuth:SetSize(statusWidth, statusHeight)
		self.statusAuth:SetPos(statusWidth + statusGap, 0)
	end
	
	if IsValid(self.statusHelix) then
		self.statusHelix:SetSize(statusWidth, statusHeight)
		self.statusHelix:SetPos((statusWidth + statusGap) * 2, 0)
	end
end

function PANEL:OnSizeChanged()
	self:InvalidateLayout(true)
end

function PANEL:Paint(width, height)
	-- Solid opaque dark background using Imperial Theme colors
	-- (Kept outside the translation matrix so the background covers the whole screen while the menu slides)
	surface.SetDrawColor(THEME.background)
	surface.DrawRect(0, 0, width, height)

	local yOffset = self.menuSlideY or 0
	local m
	
	if yOffset ~= 0 then
		m = Matrix()
		m:Translate(Vector(0, yOffset, 0))
		cam.PushModelMatrix(m)
	end

	-- Draw Title distinctively in the top-center
	local titleSpacing = Scale(12)
	local subtitleSpacing = Scale(4)
	local titleText = "V A N I R"
	local subtitleText = "I M P E R I A L   R O L E P L A Y"

	local titleX = width * 0.5
	local titleY = height * 0.25 -- Pushed up to give space to the clearly visible main menu below

	ix.ui.DrawSpacedText(titleText, "ixImpMenuTitle", titleX, titleY, THEME.text, titleSpacing, TEXT_ALIGN_CENTER)
	
	-- Distilled Theory: Selective, high-contrast title bar
	local subtitleW, subtitleH = ix.ui.GetSpacedTextSize(subtitleText, "ixImpMenuSubtitle", subtitleSpacing)
	local barPadX = Scale(16)
	local barPadY = Scale(4)
	local barW = subtitleW + (barPadX * 2)
	local barH = subtitleH + (barPadY * 2)
	
	local titleW, titleH = ix.ui.GetSpacedTextSize(titleText, "ixImpMenuTitle", titleSpacing)
	local barY = titleY + titleH + Scale(10)
	local barX = titleX - barW * 0.5

	-- Background accent bar
	surface.SetDrawColor(THEME.accent)
	surface.DrawRect(barX, barY, barW, barH)

	-- Inverted text (background color for text)
	ix.ui.DrawSpacedText(subtitleText, "ixImpMenuSubtitle", titleX, barY + barPadY, THEME.background, subtitleSpacing, TEXT_ALIGN_CENTER)

	-- Minimalistic Header / User info framing
	local rightText = "GUEST"
	if (self.bUsingCharacter) then
		local char = LocalPlayer():GetCharacter()
		if (char) then
			rightText = string.upper(char:GetName())
		end
	end
	
	local topPad = self.framePadding
	draw.SimpleText("NODE // 07", "ixImpMenuLabel", topPad, topPad, THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText("USR // " .. rightText, "ixImpMenuLabel", width - topPad, topPad, THEME.accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

	-- Minimalistic Bottom Framing with Aurebesh Metadata
	local framePad = self.framePadding
	surface.SetDrawColor(THEME.accentSoft)
	local suffixAlpha = 150
	
	local notchLength = Scale(32)
	-- Bottom left (System Active string converted to Aurebesh metadata)
	surface.DrawLine(framePad, height - framePad, framePad + notchLength, height - framePad)
	surface.DrawLine(framePad, height - framePad, framePad, height - framePad - notchLength)
	draw.SimpleText("SYSTEM ACTIVE", "ixImpMenuAurebesh", framePad + notchLength + Scale(8), height - framePad + Scale(2), Color(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b, suffixAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

	-- Bottom right (Auth Level string converted to Aurebesh metadata)
	surface.DrawLine(width - framePad, height - framePad, width - framePad - notchLength, height - framePad)
	surface.DrawLine(width - framePad, height - framePad, width - framePad, height - framePad - notchLength)
	draw.SimpleText("AUTH LVL 3", "ixImpMenuAurebesh", width - framePad - notchLength - Scale(8), height - framePad + Scale(2), Color(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b, suffixAlpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)

	if m then
		cam.PopModelMatrix()
	end

	BaseClass.Paint(self, width, height)
end

vgui.Register("ixImpMainMenu", PANEL, "ixCharMenuPanel")
vgui.Register("ixCharMenuMain", PANEL, "ixCharMenuPanel")
