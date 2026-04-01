local THEME = ix.ui.THEME
local Scale = ix.ui.Scale
local IsMenuClosing = ix.ui.IsMenuClosing


-- Main Panel

local PANEL = {}

function PANEL:Init()
	self:Dock(FILL)

	local parent = self:GetParent()
	local padding = Scale(32)
	local halfWidth = parent:GetWide() * 0.5 - (padding * 2)
	local modelFOV = (ScrW() > ScrH() * 1.8) and 100 or 78
	self:DockPadding(padding, padding, padding, padding)


	-- LEFTIdentity Record 

	self.leftPanel = self:Add("EditablePanel")
	self.leftPanel:Dock(LEFT)
	self.leftPanel:SetWide(halfWidth)
	self.leftPanel:DockMargin(0, 0, Scale(16), 0)
	self.leftPanel.headerH = Scale(24)
	self.leftPanel.Paint = function(pnl, w, h)
		local hH = pnl.headerH

		surface.SetDrawColor(Color(0, 0, 0, 200))
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawRect(0, 0, w, hH)
		surface.DrawOutlinedRect(0, 0, w, h)

		draw.SimpleText("IDENTITY RECORD", "ixImpMenuButton", Scale(10), hH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local pulse = math.abs(math.sin(CurTime() * 1.5))
		draw.SimpleText("CLASSIFIED", "ixImpMenuAurebesh", w - Scale(10), hH * 0.5, Color(0, 0, 0, math.Round(100 + pulse * 155)), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	-- Scrollable content inside left panel
	self.scroll = self.leftPanel:Add("DScrollPanel")
	self.scroll:Dock(FILL)
	self.scroll:DockMargin(Scale(8), Scale(32), Scale(8), Scale(8))
	self.scroll.Paint = function() end

	-- Styled scrollbar
	ix.ui.ApplyScrollbarStyle(self.scroll)


	self:PopulateInfo()


	-- RIGHT:  Scan 

	self.rightPanel = self:Add("EditablePanel")
	self.rightPanel:Dock(FILL)
	self.rightPanel.Paint = function(pnl, w, h)
		ix.ui.DrawScreeningPanel(pnl, w, h, "BIOMETRIC SCAN")
	end

	self.model = self.rightPanel:Add("ixModelPanel")
	self.model:Dock(FILL)
	self.model:DockMargin(Scale(2), Scale(28), Scale(2), Scale(2))
	self.model:SetModel(LocalPlayer():GetModel())
	self.model:SetFOV(modelFOV)

	function self.model:LayoutEntity(entity)
		entity:SetAngles(Angle(0, 45, 0))
		self:RunAnimation()
	end
end

function PANEL:PopulateInfo()
	local char = LocalPlayer():GetCharacter()
	if (!char) then return end

	local scroll = self.scroll
	local rowIdx = 0


	local nameLabel = scroll:Add("DLabel")
	nameLabel:SetText(char:GetName())
	nameLabel:SetFont("ixImpMenuTitle")
	nameLabel:SetAutoStretchVertical(true)
	nameLabel:SetWrap(true)
	nameLabel:Dock(TOP)
	nameLabel:SetTextColor(THEME.text)
	nameLabel:DockMargin(0, Scale(4), 0, 0)
	nameLabel:SetMouseInputEnabled(true)
	nameLabel:SetCursor("hand")
	nameLabel._hover = false
	nameLabel.OnCursorEntered = function(this) this._hover = true end
	nameLabel.OnCursorExited = function(this) this._hover = false end
	nameLabel.Paint = function(this, w, h)
		if (this._hover) then
			surface.SetDrawColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 18))
			surface.DrawRect(0, 0, w, h)
		end
	end
	nameLabel.OnMousePressed = function(this, code)
		if (code == MOUSE_LEFT) then
			ix.command.Send("CharSetName", char:GetName(), "")
		end
	end

	-- Affiliation
	local faction = ix.faction.indices[char:GetFaction()]
	local factionName = faction and string.upper(faction.name) or "UNKNOWN"
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

	local affLabel = scroll:Add("DLabel")
	affLabel:SetText("BACKGROUND:  " .. (backgroundText ~= "" and backgroundText or "None"))
	affLabel:SetFont("ixImpMenuLabel")
	affLabel:Dock(TOP)
	affLabel:SetTextColor(THEME.accent)
	affLabel:DockMargin(0, Scale(4), 0, 0)
	affLabel:SetMouseInputEnabled(true)

	-- Build tooltip text
	local descList = {}
	for k, _ in pairs(backgrounds) do
		local bck = ix.backgrounds[k]
		if bck and bck.description then
			table.insert(descList, bck.name .. ":\n" .. bck.description)
		end
	end

	if #descList > 0 then
		local tooltipText = table.concat(descList, "\n\n")
		affLabel:SetHelixTooltip(function(tooltip)
			local label = tooltip:AddRowAfter("name", "description")
			label:SetText(tooltipText)
			label:SetFont("ixImpMenuLabel")
			label:SizeToContents()
		end)
	end

	affLabel.Paint = function(this, w, h)
		if this:IsHovered() then
			surface.SetDrawColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 18))
			surface.DrawRect(0, 0, w, h)
		end
	end


	ix.ui.CreateSectionHeader(scroll, "PERSONNEL DETAILS")

	rowIdx = rowIdx + 1
	ix.ui.CreateDataRow(scroll, "CREDITS", ix.currency.Get(char:GetMoney()), rowIdx)

	local class = ix.class.list[char:GetClass()]
	if (class) then
		rowIdx = rowIdx + 1
		ix.ui.CreateDataRow(scroll, "CLASS", class.name, rowIdx)
	end


	rowIdx = rowIdx + 1
	ix.ui.CreateDataRow(scroll, "FACTION", factionName, rowIdx)


	ix.ui.CreateSectionHeader(scroll, "BIOGRAPHY")

	local desc = scroll:Add("DLabel")
	desc:SetText(char:GetDescription())
	desc:SetFont("ixImpMenuLabel")
	desc:SetAutoStretchVertical(true)
	desc:SetWrap(true)
	desc:Dock(TOP)
	desc:SetTextColor(THEME.textMuted)
	desc:DockMargin(0, 0, 0, 0)
	desc:SetMouseInputEnabled(true)
	desc:SetCursor("hand")
	desc._hover = false
	desc.OnCursorEntered = function(this) this._hover = true end
	desc.OnCursorExited = function(this) this._hover = false end
	desc.Paint = function(this, w, h)
		if (this._hover) then
			surface.SetDrawColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 12))
			surface.DrawRect(0, 0, w, h)
		end
	end
	desc.OnMousePressed = function(this, code)
		if (code == MOUSE_LEFT) then
			ix.command.Send("CharDesc")
		end
	end


	if (table.Count(ix.attributes.list) > 0) then
		ix.ui.CreateSectionHeader(scroll, "ATTRIBUTES")

		for k, v in SortedPairs(ix.attributes.list) do
			local val = char:GetAttribute(k, 0)
			local max = v.maxValue or ix.config.Get("maxAttributes", 100)
			local bar = scroll:Add("ixAttributeBar")
			bar:Dock(TOP)
			bar:DockMargin(0, 0, 0, Scale(2))
			bar:SetMax(max)
			bar:SetValue(val)
			bar:SetText(Format("%s [%.1f/%.1f] (%.1f%%)", L(v.name), val, max, val / max * 100))
			bar:SetReadOnly()
			ix.ui.ApplyAttributeBarStyle(bar)
		end
	end
end

function PANEL:OnRemove()
	if (IsValid(self.model)) then
		self.model:SetVisible(false)
		self.model:Remove()
		self.model = nil
	end
end

function PANEL:Think()
	if (IsValid(self.model)) then
		self.model:SetVisible(self:IsVisible() and !IsMenuClosing())
	end
end

vgui.Register("ixCharInfo", PANEL, "EditablePanel")

-- Tab registration moved to vgui/cl_unified_panel.lua (unified panel)
