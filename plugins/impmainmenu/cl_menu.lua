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

	self.createButton = self:AddMenuButton("ENLIST", "accent", function()
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

	self.returnButton = self:AddMenuButton("DISENGAGE", "danger", function()
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
	local button = self:Add("ixImpButton")
	button:SetLabel(label)
	button:SetStyle(style)
	button.DoClick = function()
		if (button:GetDisabled()) then
			surface.PlaySound(ix.ui.SOUND_ERROR)
			return
		end

		surface.PlaySound(ix.ui.SOUND_CLICK)
		if (isfunction(onClick)) then
			onClick()
		end
	end

	self.buttons[#self.buttons + 1] = button
	return button
end

function PANEL:UpdateReturnButton(bValue)
	if (bValue != nil) then
		self.bUsingCharacter = bValue
	end

	local label = self.bUsingCharacter and "RETURN" or "DISENGAGE"
	self.returnButton:SetLabel(label)
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
	local padding = self.padding
	local framePad = self.framePadding
	local buttonWidth = math.min(width * 0.38, width - framePad * 2 - padding * 2)
	local buttonHeight = math.max(Scale(44), math.Round(height * 0.055))
	local buttonGap = math.max(Scale(10), math.Round(buttonHeight * 0.25))

	local totalHeight = (#self.buttons * buttonHeight) + (#self.buttons - 1) * buttonGap
	local startX = width * 0.5 - buttonWidth * 0.5
	local startY = height * 0.5 - totalHeight * 0.2

	for i, button in ipairs(self.buttons) do
		button:SetSize(buttonWidth, buttonHeight)
		button:SetPos(startX, startY + (i - 1) * (buttonHeight + buttonGap))
	end

	local statusHeight = Scale(22)
	local statusGap = Scale(10)
	local statusWidth = math.max(Scale(72), math.Round(buttonWidth * 0.18))
	local statusTotal = statusWidth * 3 + statusGap * 2
	local statusX = width * 0.5 - statusTotal * 0.5
	local statusY = height - framePad - statusHeight - Scale(10)

	self.statusPanel:SetPos(statusX, statusY)
	self.statusPanel:SetSize(statusTotal, statusHeight)

	self.statusReady:SetSize(statusWidth, statusHeight)
	self.statusReady:SetPos(0, 0)

	self.statusAuth:SetSize(statusWidth, statusHeight)
	self.statusAuth:SetPos(statusWidth + statusGap, 0)

	self.statusHelix:SetSize(statusWidth, statusHeight)
	self.statusHelix:SetPos((statusWidth + statusGap) * 2, 0)
end

function PANEL:OnSizeChanged()
	self:InvalidateLayout(true)
end

function PANEL:Paint(width, height)
	surface.SetDrawColor(THEME.background)
	surface.DrawRect(0, 0, width, height)

	local framePad = self.framePadding
	surface.SetDrawColor(THEME.frame)
	surface.DrawOutlinedRect(framePad, framePad, width - framePad * 2, height - framePad * 2)

	local labelX = framePad + Scale(8)
	local labelY = framePad + Scale(6)
	draw.SimpleText("IMPERIAL MAIN MENU", "ixImpMenuLabel", labelX, labelY, THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	local titleSpacing = Scale(4)
	local subtitleSpacing = Scale(2)
	local titleText = "SKELETON"
	local subtitleText = "IMPERIAL TERMINAL INTERFACE"

	local titleW, titleH = ix.ui.GetSpacedTextSize(titleText, "ixImpMenuTitle", titleSpacing)
	local subtitleW, subtitleH = ix.ui.GetSpacedTextSize(subtitleText, "ixImpMenuSubtitle", subtitleSpacing)

	local titleX = width * 0.5
	local titleY = height * 0.26
	local subtitleY = titleY + titleH + Scale(6)

	ix.ui.DrawSpacedText(titleText, "ixImpMenuTitle", titleX, titleY, THEME.text, titleSpacing, TEXT_ALIGN_CENTER)
	ix.ui.DrawSpacedText(subtitleText, "ixImpMenuSubtitle", titleX, subtitleY, THEME.textMuted, subtitleSpacing, TEXT_ALIGN_CENTER)

	local panelWidth = math.Round(width * 0.19)
	local panelHeight = math.Round(height * 0.58)
	local panelX = width - framePad - panelWidth - Scale(10)
	local panelY = framePad + math.Round((height - framePad * 2 - panelHeight) * 0.5)
	local now = CurTime()
	local flicker = 0.85 + (math.sin(now * 2.4) + 1) * 0.075
	BaseClass.Paint(self, width, height)
end

vgui.Register("ixImpMainMenu", PANEL, "ixCharMenuPanel")
vgui.Register("ixCharMenuMain", PANEL, "ixCharMenuPanel")
