
local THEME = {
	background = Color(10, 10, 10, 255),
	frame = Color(191, 148, 53, 255),
	frameSoft = Color(191, 148, 53, 120),
	text = Color(235, 235, 235, 255),
	textMuted = Color(168, 168, 168, 140),
	accent = Color(191, 148, 53, 255),
	accentSoft = Color(191, 148, 53, 220),
	buttonBg = Color(16, 16, 16, 255),
	buttonBgHover = Color(26, 26, 26, 255)
}

local function Scale(value)
	return math.max(1, math.Round(value * (ScrH() / 900)))
end

local function DrawScreeningPanel(panel, width, height, headerText)
	local now = CurTime()
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

	surface.SetDrawColor(THEME.frameSoft)
	surface.DrawRect(0, 0, width, headerH)
	surface.DrawOutlinedRect(0, 0, width, drawH)

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

	local barY = drawH - Scale(24)
	for i = 1, 3 do
		local phase = now * (0.7 + i * 0.4)
		local fill = 0.35 + (math.sin(phase) + 1) * 0.3
		local barH = Scale(6)
		if (barY + barH > drawH) then break end
		surface.SetDrawColor(Color(255, 255, 255, 10))
		surface.DrawRect(innerX, barY, innerW, barH)
		surface.SetDrawColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 120))
		surface.DrawRect(innerX, barY, innerW * fill, barH)
		barY = barY - Scale(10)
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

		if (headerText) then
			draw.SimpleText(headerText, "ixImpMenuButton", Scale(8), headerH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end
end

local PANEL = {}

function PANEL:Init()
	self:SetTall(Scale(40))
	self:DockMargin(0, 0, 0, Scale(5))
end

function PANEL:Paint(w, h)
	local bg = self.Hovered and THEME.buttonBgHover or THEME.buttonBg
	surface.SetDrawColor(bg)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(THEME.frameSoft)
	surface.DrawOutlinedRect(0, 0, w, h)
end

function PANEL:SetClass(data)
	self.data = data
	self.class = data.index

	self.label = self:Add("DLabel")
	self.label:Dock(FILL)
	self.label:SetText(L(data.name):upper())
	self.label:SetFont("ixImpMenuLabel")
	self.label:SetContentAlignment(4)
	self.label:SetTextInset(Scale(10), 0)
	self.label:SetTextColor(THEME.text)
	
	self.limit = self:Add("DLabel")
	self.limit:Dock(RIGHT)
	self.limit:SetWide(Scale(50))
	self.limit:SetFont("ixImpMenuLabel")
	self.limit:SetContentAlignment(5)
	self.limit:SetTextColor(THEME.textMuted)
	
	self:SetNumber(#ix.class.GetPlayers(data.index))
end

function PANEL:SetNumber(number)
	local limit = self.data.limit
	if (limit > 0) then
		self.limit:SetText(number .. "/" .. limit)
	else
		self.limit:SetText("∞")
	end
end

function PANEL:OnMousePressed()
	ix.command.Send("BecomeClass", self.class)
end

function PANEL:OnCursorEntered()
	if IsValid(self:GetParent():GetParent():GetParent()) then
		local main = self:GetParent():GetParent():GetParent()
		if main.UpdateModel then
			main:UpdateModel(self.data)
		end
	end
end

vgui.Register("ixClassPanel", PANEL, "DPanel")

PANEL = {}

function PANEL:Init()
	ix.gui.classes = self
	self:Dock(FILL)
	self:DockPadding(Scale(50), Scale(50), Scale(50), Scale(50))
	local modelFOV = (ScrW() > ScrH() * 1.8) and 100 or 78

	-- LEFT: Class List
	self.leftPanel = self:Add("DPanel")
	self.leftPanel:Dock(LEFT)
	self.leftPanel:SetWide(ScrW() * 0.3)
	self.leftPanel:DockMargin(0, 0, Scale(20), 0)
	self.leftPanel:DockPadding(Scale(2), Scale(32), Scale(2), Scale(2))
	ApplyDataPanel(self.leftPanel, "CLASS ASSIGNMENT")

	self.list = self.leftPanel:Add("DScrollPanel")
	self.list:Dock(FILL)
	self.list:DockMargin(Scale(10), Scale(10), Scale(10), Scale(10))

	-- RIGHT: Preview
	self.rightPanel = self:Add("DPanel")
	self.rightPanel:Dock(FILL)
	self.rightPanel:DockPadding(Scale(2), Scale(32), Scale(2), Scale(2))
	ApplyScreeningPanel(self.rightPanel, "BIOMETRIC PREVIEW")

	self.model = self.rightPanel:Add("ixModelPanel")
	self.model:Dock(FILL)
	self.model:SetModel(LocalPlayer():GetModel())
	self.model:SetFOV(modelFOV)
	function self.model:LayoutEntity(Entity) 
		Entity:SetAngles(Angle(0, 45, 0)) 
		self:RunAnimation() 
	end
	
	-- Scanning Animation
	self.classPanels = {}
	self:LoadClasses()
end

function PANEL:UpdateModel(data)
	if data and data.model then
		local model = data.model
		if istable(model) then model = model[1] end
		self.model:SetModel(model)
	end
end

function PANEL:LoadClasses()
	self.list:Clear()
	self.classPanels = {}

	for k, v in ipairs(ix.class.list) do
		local no, why = ix.class.CanSwitchTo(LocalPlayer(), k)
		local itsFull = ("class is full" == why)

		if (no or itsFull) then
			local panel = self.list:Add("ixClassPanel")
			panel:SetClass(v)
			table.insert(self.classPanels, panel)
		end
	end
end

vgui.Register("ixClasses", PANEL, "EditablePanel")


hook.Add("CreateMenuButtons", "ixClasses", function(tabs)
	local cnt = table.Count(ix.class.list)

	if (cnt <= 1) then return end

	for k, _ in ipairs(ix.class.list) do
		if (!ix.class.CanSwitchTo(LocalPlayer(), k)) then
			continue
		else
			tabs["classes"] = function(container)
				container:Add("ixClasses")
			end

			return
		end
	end
end)

net.Receive("ixClassUpdate", function()
	local client = net.ReadEntity()

	if (ix.gui.classes and ix.gui.classes:IsVisible()) then
		if (client == LocalPlayer()) then
			ix.gui.classes:LoadClasses()
		else
			for _, v in ipairs(ix.gui.classes.classPanels) do
				local data = v.data

				v:SetNumber(#ix.class.GetPlayers(data.index))
			end
		end
	end
end)
