local THEME = {
	background = Color(10, 10, 10, 240),
	frame = Color(191, 148, 53, 220),
	frameSoft = Color(191, 148, 53, 120),
	text = Color(235, 235, 235, 245),
	textMuted = Color(205, 205, 205, 140),
	accent = Color(191, 148, 53, 255),
	accentSoft = Color(191, 148, 53, 220),
	danger = Color(180, 60, 60, 255),
	ready = Color(60, 170, 90, 255),
	buttonBg = Color(16, 16, 16, 220),
	buttonBgHover = Color(26, 26, 26, 230)
}

local function Scale(value)
	return math.max(1, math.Round(value * (ScrH() / 900)))
end

local function CreateFonts()
	surface.CreateFont("ixImpMenuTitle", {
		font = "Times New Roman",
		size = Scale(64),
		weight = 500,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixImpMenuSubtitle", {
		font = "Times New Roman",
		size = Scale(16),
		weight = 400,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixImpMenuLabel", {
		font = "Roboto",
		size = Scale(12),
		weight = 500,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixImpMenuButton", {
		font = "Roboto",
		size = Scale(16),
		weight = 600,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixImpMenuStatus", {
		font = "Roboto",
		size = Scale(11),
		weight = 600,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixImpMenuAurebesh", {
		font = "Aurebesh",
		size = Scale(12),
		weight = 400,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixImpMenuDiag", {
		font = "Roboto Condensed",
		size = Scale(11),
		weight = 500,
		extended = true,
		antialias = true
	})
end

CreateFonts()

hook.Add("OnScreenSizeChanged", "ixImpMainMenuFonts", function()
	CreateFonts()
end)

local function GetSpacedTextSize(text, font, spacing)
	surface.SetFont(font)
	local totalWidth = 0
	local textHeight = 0

	for i = 1, #text do
		local ch = text:sub(i, i)
		local w, h = surface.GetTextSize(ch)
		totalWidth = totalWidth + w
		textHeight = math.max(textHeight, h)

		if (i < #text) then
			totalWidth = totalWidth + spacing
		end
	end

	return totalWidth, textHeight
end

local function DrawSpacedText(text, font, x, y, color, spacing, align)
	align = align or TEXT_ALIGN_CENTER
	spacing = spacing or 0

	local totalWidth, textHeight = GetSpacedTextSize(text, font, spacing)
	local startX = x

	if (align == TEXT_ALIGN_CENTER) then
		startX = x - totalWidth * 0.5
	elseif (align == TEXT_ALIGN_RIGHT) then
		startX = x - totalWidth
	end

	surface.SetFont(font)

	local offsetX = startX
	for i = 1, #text do
		local ch = text:sub(i, i)
		local w = surface.GetTextSize(ch)
		draw.SimpleText(ch, font, offsetX, y, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		offsetX = offsetX + w + spacing
	end

	return totalWidth, textHeight
end

local BUTTON = {}

local SOUND_HOVER = "everfall/miscellaneous/ux/navigation/navigation_tab_01.mp3"
local SOUND_CLICK = "everfall/miscellaneous/ux/navigation/navigation_activate_01.mp3"
local SOUND_ERROR = "everfall/miscellaneous/ux/navigation/navigation_error_01.mp3"

function BUTTON:Init()
	self:SetText("")
	self.label = ""
	self.style = "default"
	self.labelColor = THEME.text
	self.borderColor = THEME.accent
	self.backgroundColor = THEME.buttonBg
	self.hoverBorderColor = THEME.accent
	self.hoverBackgroundColor = THEME.buttonBgHover
	self.hoverLabelColor = THEME.text
	self.disabledAlpha = 60
	self.pulseOffset = math.Rand(0, 4)
	self.nextHoverSound = 0
end

function BUTTON:SetLabel(text)
	self.label = text
end

function BUTTON:SetStyle(style)
	self.style = style or "default"

	if (self.style == "accent") then
		self.labelColor = THEME.accent
		self.borderColor = THEME.accent
		self.hoverBorderColor = THEME.accent
		self.hoverBackgroundColor = Color(25, 20, 10, 220)
		self.hoverLabelColor = THEME.accent
	elseif (self.style == "danger") then
		self.labelColor = THEME.danger
		self.borderColor = THEME.danger
		self.hoverBorderColor = THEME.danger
		self.hoverBackgroundColor = Color(35, 10, 10, 220)
		self.hoverLabelColor = THEME.danger
	else
		self.labelColor = THEME.text
		self.borderColor = THEME.accentSoft
		self.hoverBorderColor = THEME.accent
		self.hoverBackgroundColor = THEME.buttonBgHover
		self.hoverLabelColor = THEME.text
	end
end

function BUTTON:Paint(width, height)
	local disabled = self:GetDisabled()
	local hovered = self:IsHovered() or self:IsDown()
	local pulse = (math.sin(CurTime() * 2 + self.pulseOffset) + 1) * 0.5
	local border = hovered and self.hoverBorderColor or self.borderColor
	local bg = hovered and self.hoverBackgroundColor or self.backgroundColor
	local textColor = hovered and self.hoverLabelColor or self.labelColor
	local glow = hovered and 40 or math.Round(12 + pulse * 18)

	if (disabled) then
		border = Color(border.r, border.g, border.b, self.disabledAlpha)
		bg = Color(bg.r, bg.g, bg.b, self.disabledAlpha)
		textColor = Color(textColor.r, textColor.g, textColor.b, self.disabledAlpha)
	end

	surface.SetDrawColor(bg)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(Color(border.r, border.g, border.b, math.min(255, border.a + glow)))
	surface.DrawOutlinedRect(0, 0, width, height)
	surface.DrawOutlinedRect(1, 1, width - 2, height - 2)

	draw.SimpleText(self.label, "ixImpMenuButton", width * 0.5, height * 0.5, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function BUTTON:OnCursorEntered()
	if (self.nextHoverSound > CurTime()) then
		return
	end

	self.nextHoverSound = CurTime() + 0.08
	surface.PlaySound(SOUND_HOVER)
end

vgui.Register("ixImpMenuButton", BUTTON, "DButton")

local STATUS = {}

function STATUS:Init()
	self.text = ""
	self.borderColor = THEME.accentSoft
	self.textColor = THEME.text
	self:SetMouseInputEnabled(false)
end

function STATUS:SetTextValue(text)
	self.text = text
end

function STATUS:SetColors(border, text)
	self.borderColor = border or self.borderColor
	self.textColor = text or self.textColor
end

function STATUS:Paint(width, height)
	surface.SetDrawColor(Color(0, 0, 0, 160))
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(self.borderColor)
	surface.DrawOutlinedRect(0, 0, width, height)

	draw.SimpleText(self.text, "ixImpMenuStatus", width * 0.5, height * 0.5, self.textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

vgui.Register("ixImpMenuStatus", STATUS, "Panel")

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

	self.statusReady = self.statusPanel:Add("ixImpMenuStatus")
	self.statusReady:SetTextValue("SYS READY")
	self.statusReady:SetColors(THEME.ready, THEME.ready)

	self.statusAuth = self.statusPanel:Add("ixImpMenuStatus")
	self.statusAuth:SetTextValue("AUTH-LVL 3")
	self.statusAuth:SetColors(THEME.accent, THEME.accent)

	self.statusHelix = self.statusPanel:Add("ixImpMenuStatus")
	self.statusHelix:SetTextValue("HELIX")
	self.statusHelix:SetColors(THEME.accent, THEME.accent)

	self:InvalidateLayout(true)
end

function PANEL:AddMenuButton(label, style, onClick)
	local button = self:Add("ixImpMenuButton")
	button:SetLabel(label)
	button:SetStyle(style)
	button.DoClick = function()
		if (button:GetDisabled()) then
			surface.PlaySound(SOUND_ERROR)
			return
		end

		surface.PlaySound(SOUND_CLICK)
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

	local titleW, titleH = GetSpacedTextSize(titleText, "ixImpMenuTitle", titleSpacing)
	local subtitleW, subtitleH = GetSpacedTextSize(subtitleText, "ixImpMenuSubtitle", subtitleSpacing)

	local titleX = width * 0.5
	local titleY = height * 0.26
	local subtitleY = titleY + titleH + Scale(6)

	DrawSpacedText(titleText, "ixImpMenuTitle", titleX, titleY, THEME.text, titleSpacing, TEXT_ALIGN_CENTER)
	DrawSpacedText(subtitleText, "ixImpMenuSubtitle", titleX, subtitleY, THEME.textMuted, subtitleSpacing, TEXT_ALIGN_CENTER)

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
