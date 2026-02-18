local THEME = {
	background = Color(10, 10, 10, 255),
	frame = Color(191, 148, 53, 255),
	frameSoft = Color(191, 148, 53, 120),
	text = Color(235, 235, 235, 255),
	textMuted = Color(168, 168, 168, 140),
	accent = Color(191, 148, 53, 255),
	accentSoft = Color(191, 148, 53, 220),
	buttonBg = Color(16, 16, 16, 255),
	buttonBgHover = Color(26, 26, 26, 255),
	rowEven = Color(14, 14, 14, 255),
	rowOdd = Color(18, 18, 18, 255)
}

local function Scale(value)
	return math.max(1, math.Round(value * (ScrH() / 900)))
end

local function IsMenuClosing()
	return IsValid(ix.gui.menu) and ix.gui.menu.bClosing
end


-- Screening Panel painter
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
	draw.SimpleText("BIOSCAN", "ixImpMenuAurebesh", width - Scale(8), headerH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

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


-- Attribute Bar Style

local function ApplyAttributeBarStyle(panel)
	if (!IsValid(panel)) then return end

	panel:SetTall(Scale(22))

	if (IsValid(panel.label)) then
		panel.label:SetFont("ixImpMenuDiag")
		panel.label:SetTextColor(THEME.textMuted)
		panel.label:SetContentAlignment(5)
	end

	if (IsValid(panel.bar)) then
		panel.bar.Paint = function(this, w, h)
			surface.SetDrawColor(Color(0, 0, 0, 255))
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(THEME.frameSoft)
			surface.DrawOutlinedRect(0, 0, w, h)

			local max = math.max(panel.max or 1, 1)
			local value = (panel.deltaValue or 0) / max
			local fillW = math.max(0, (w - 4) * value)

			if (fillW > 0) then
				surface.SetDrawColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 180))
				surface.DrawRect(2, 2, fillW, h - 4)
			end
		end
	end

	if (panel.GetColor and panel:GetColor() ~= THEME.accent) then
		panel:SetColor(THEME.accent)
	end
end

-- Data row helper

local function CreateDataRow(parent, label, value, index)
	local box = parent:Add("EditablePanel")
	box:Dock(TOP)
	box:DockMargin(0, 0, 0, Scale(2))
	box:SetTall(Scale(24))

	local bg = (index % 2 == 0) and THEME.rowEven or THEME.rowOdd
	box.Paint = function(_, w, h)
		surface.SetDrawColor(bg)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 30)
		surface.DrawRect(0, h - 1, w, 1)
	end

	local l = box:Add("DLabel")
	l:SetText(label)
	l:SetFont("ixImpMenuDiag")
	l:Dock(LEFT)
	l:SetWide(Scale(120))
	l:DockMargin(Scale(8), 0, 0, 0)
	l:SetTextColor(THEME.textMuted)
	l:SetContentAlignment(4)

	local v = box:Add("DLabel")
	v:SetText(value)
	v:SetFont("ixImpMenuDiag")
	v:Dock(FILL)
	v:DockMargin(Scale(4), 0, Scale(8), 0)
	v:SetTextColor(THEME.text)
	v:SetContentAlignment(4)

	return box
end


local function CreateSectionHeader(parent, text)
	local sep = parent:Add("EditablePanel")
	sep:Dock(TOP)
	sep:SetTall(Scale(20))
	sep:DockMargin(0, Scale(10), 0, Scale(4))
	sep.Paint = function(_, w, h)
		draw.SimpleText(text, "ixImpMenuDiag", 0, h * 0.5, THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local tw = surface.GetTextSize(text)
		surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 50)
		surface.DrawRect(tw + Scale(8), math.floor(h * 0.5), w - tw - Scale(8), 1)
	end

	return sep
end


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
	local vbar = self.scroll:GetVBar()
	vbar:SetWide(Scale(4))
	vbar.Paint = function() end
	vbar.btnUp.Paint = function() end
	vbar.btnDown.Paint = function() end
	vbar.btnGrip.Paint = function(_, w, h)
		surface.SetDrawColor(THEME.accentSoft)
		surface.DrawRect(0, 0, w, h)
	end


	self:PopulateInfo()


	-- RIGHT:  Scan 

	self.rightPanel = self:Add("EditablePanel")
	self.rightPanel:Dock(FILL)
	self.rightPanel.Paint = function(pnl, w, h)
		DrawScreeningPanel(pnl, w, h, "BIOMETRIC SCAN")
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


	CreateSectionHeader(scroll, "PERSONNEL DETAILS")

	rowIdx = rowIdx + 1
	CreateDataRow(scroll, "CREDITS", ix.currency.Get(char:GetMoney()), rowIdx)

	local class = ix.class.list[char:GetClass()]
	if (class) then
		rowIdx = rowIdx + 1
		CreateDataRow(scroll, "CLASS", class.name, rowIdx)
	end


	rowIdx = rowIdx + 1
	CreateDataRow(scroll, "FACTION", factionName, rowIdx)


	CreateSectionHeader(scroll, "BIOGRAPHY")

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
		CreateSectionHeader(scroll, "ATTRIBUTES")

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
			ApplyAttributeBarStyle(bar)
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

hook.Add("CreateMenuButtons", "ixCharInfo", function(tabs)
	tabs["you"] = function(container)
		local panel = container:Add("ixCharInfo")
		panel:Dock(FILL)
	end
end)
