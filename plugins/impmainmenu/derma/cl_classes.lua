
local THEME = ix.ui.THEME
local Scale = ix.ui.Scale

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
	ix.ui.ApplyDataPanel(self.leftPanel, "CLASS ASSIGNMENT")

	self.list = self.leftPanel:Add("DScrollPanel")
	self.list:Dock(FILL)
	self.list:DockMargin(Scale(10), Scale(10), Scale(10), Scale(10))

	-- RIGHT: Preview
	self.rightPanel = self:Add("DPanel")
	self.rightPanel:Dock(FILL)
	self.rightPanel:DockPadding(Scale(2), Scale(32), Scale(2), Scale(2))
	ix.ui.ApplyScreeningPanel(self.rightPanel, "BIOMETRIC PREVIEW")

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
