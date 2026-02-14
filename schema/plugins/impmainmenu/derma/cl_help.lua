local THEME = {
	background = Color(10, 10, 10, 255),
	frame = Color(191, 148, 53, 255),
	frameSoft = Color(191, 148, 53, 120),
	text = Color(235, 235, 235, 255),
	textMuted = Color(168, 168, 168, 140),
	accent = Color(191, 148, 53, 255),
	accentSoft = Color(191, 148, 53, 220)
}

local function Scale(value)
	return math.max(1, math.Round(value * (ScrH() / 900)))
end

local function ApplyDataPanel(panel, headerText)
	if (!IsValid(panel)) then
		return
	end

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

local backgroundColor = THEME.background

local PANEL = {}

AccessorFunc(PANEL, "maxWidth", "MaxWidth", FORCE_NUMBER)

function PANEL:Init()
	self:SetWide(180)
	self:Dock(LEFT)

	self.maxWidth = ScrW() * 0.2
	ApplyDataPanel(self, "HELP INDEX")
end

function PANEL:Paint(width, height)
end

function PANEL:SizeToContents()
	local width = 0

	for _, v in ipairs(self:GetChildren()) do
		width = math.max(width, v:GetWide())
	end

	self:SetSize(math.max(32, math.min(width, self.maxWidth)), self:GetParent():GetTall())
end

vgui.Register("ixHelpMenuCategories", PANEL, "EditablePanel")

-- help menu
PANEL = {}

function PANEL:Init()
	self:Dock(FILL)

	self.categories = {}
	self.categorySubpanels = {}
	self.categoryPanel = self:Add("ixHelpMenuCategories")

	self.canvasPanel = self:Add("EditablePanel")
	self.canvasPanel:Dock(FILL)

	self.idlePanel = self.canvasPanel:Add("Panel")
	self.idlePanel:Dock(FILL)
	self.idlePanel:DockMargin(8, 0, 0, 0)
	self.idlePanel.Paint = function(_, width, height)
		surface.SetDrawColor(backgroundColor)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawOutlinedRect(0, 0, width, height)

		derma.SkinFunc("DrawHelixCurved", width * 0.5, height * 0.5, width * 0.25)

		surface.SetFont("ixIntroSubtitleFont")
		local text = L("helix"):lower()
		local textWidth, textHeight = surface.GetTextSize(text)

		surface.SetTextColor(THEME.text)
		surface.SetTextPos(width * 0.5 - textWidth * 0.5, height * 0.5 - textHeight * 0.75)
		surface.DrawText(text)

		surface.SetFont("ixMediumLightFont")
		text = L("helpIdle")
		local infoWidth, _ = surface.GetTextSize(text)

		surface.SetTextColor(THEME.textMuted)
		surface.SetTextPos(width * 0.5 - infoWidth * 0.5, height * 0.5 + textHeight * 0.25)
		surface.DrawText(text)
	end

	local categories = {}
	hook.Run("PopulateHelpMenu", categories)

	for k, v in SortedPairs(categories) do
		if (!isstring(k)) then
			ErrorNoHalt("expected string for help menu key\n")
			continue
		elseif (!isfunction(v)) then
			ErrorNoHalt(string.format("expected function for help menu entry '%s'\n", k))
			continue
		end

		self:AddCategory(k)
		self.categories[k] = v
	end

	self.categoryPanel:SizeToContents()

	if (ix.gui.lastHelpMenuTab) then
		self:OnCategorySelected(ix.gui.lastHelpMenuTab)
	end
end

function PANEL:AddCategory(name)
	local button = self.categoryPanel:Add("ixMenuButton")
	button:SetText(L(name))
	button:SizeToContents()
	-- @todo don't hardcode this but it's the only panel that needs docking at the bottom so it'll do for now
	button:Dock(name == "credits" and BOTTOM or TOP)
	button.DoClick = function()
		self:OnCategorySelected(name)
	end

	local panel = self.canvasPanel:Add("DScrollPanel")
	panel:SetVisible(false)
	panel:Dock(FILL)
	panel:DockMargin(8, 0, 0, 0)
	panel:GetCanvas():DockPadding(Scale(8), Scale(32), Scale(8), Scale(8))

	ApplyDataPanel(panel, string.upper(L(name)))

	-- reverts functionality back to a standard panel in the case that a category will manage its own scrolling
	panel.DisableScrolling = function()
		panel:GetCanvas():SetVisible(false)
		panel:GetVBar():SetVisible(false)
		panel.OnChildAdded = function() end
	end

	self.categorySubpanels[name] = panel
end

function PANEL:OnCategorySelected(name)
	local panel = self.categorySubpanels[name]

	if (!IsValid(panel)) then
		return
	end

	if (!panel.bPopulated) then
		self.categories[name](panel)
		panel.bPopulated = true
	end

	if (IsValid(self.activeCategory)) then
		self.activeCategory:SetVisible(false)
	end

	panel:SetVisible(true)
	self.idlePanel:SetVisible(false)

	self.activeCategory = panel
	ix.gui.lastHelpMenuTab = name
end

vgui.Register("ixHelpMenu", PANEL, "EditablePanel")

local function DrawHelix(width, height, color) -- luacheck: ignore 211
	local segments = 76
	local radius = math.min(width, height) * 0.375

	surface.SetTexture(-1)

	for i = 1, math.ceil(segments) do
		local angle = math.rad((i / segments) * -360)
		local x = width * 0.5 + math.sin(angle + math.pi * 2) * radius
		local y = height * 0.5 + math.cos(angle + math.pi * 2) * radius
		local barOffset = math.sin(SysTime() + i * 0.5)
		local barHeight = barOffset * radius * 0.25

		if (barOffset > 0) then
			surface.SetDrawColor(color)
		else
			surface.SetDrawColor(color.r * 0.5, color.g * 0.5, color.b * 0.5, color.a)
		end

		surface.DrawTexturedRectRotated(x, y, 4, barHeight, math.deg(angle))
	end
end

hook.Add("CreateMenuButtons", "ixHelpMenu", function(tabs)
	tabs["help"] = function(container)
		container:Add("ixHelpMenu")
	end
end)

hook.Add("PopulateHelpMenu", "ixHelpMenu", function(tabs)
	tabs["commands"] = function(container)
		-- info text
		local info = container:Add("DLabel")
		info:SetFont("ixImpMenuLabel")
		info:SetText(L("helpCommands"))
		info:SetContentAlignment(5)
		info:SetTextColor(THEME.text)
		info:SetExpensiveShadow(1, color_black)
		info:Dock(TOP)
		info:DockMargin(0, 0, 0, 8)
		info:SizeToContents()
		info:SetTall(info:GetTall() + 16)

		info.Paint = function(_, width, height)
			surface.SetDrawColor(THEME.background)
			surface.DrawRect(0, 0, width, height)
			surface.SetDrawColor(THEME.frameSoft)
			surface.DrawOutlinedRect(0, 0, width, height)
		end

		-- commands
		for uniqueID, command in SortedPairs(ix.command.list) do
			if (command.OnCheckAccess and !command:OnCheckAccess(LocalPlayer())) then
				continue
			end

			local bIsAlias = false
			local aliasText = ""

			-- we want to show aliases in the same entry for better readability
			if (command.alias) then
				local alias = istable(command.alias) and command.alias or {command.alias}

				for _, v in ipairs(alias) do
					if (v:lower() == uniqueID) then
						bIsAlias = true
						break
					end

					aliasText = aliasText .. ", /" .. v
				end

				if (bIsAlias) then
					continue
				end
			end

			-- command name
			local title = container:Add("DLabel")
			title:SetFont("ixImpMenuButton")
			title:SetText("/" .. command.name .. aliasText)
			title:Dock(TOP)
			title:SetTextColor(THEME.accent)
			title:SetExpensiveShadow(1, color_black)
			title:SizeToContents()

			-- syntax
			local syntaxText = command.syntax
			local syntax

			if (syntaxText != "" and syntaxText != "[none]") then
				syntax = container:Add("DLabel")
				syntax:SetFont("ixImpMenuLabel")
				syntax:SetText(L("syntax") .. ": " .. syntaxText)
				syntax:Dock(TOP)
				syntax:SetTextColor(THEME.textMuted)
				syntax:SetExpensiveShadow(1, color_black)
				syntax:SizeToContents()
			end

			-- description
			local description = container:Add("DLabel")
			description:SetFont("ixImpMenuLabel")
			description:SetText(command.description)
			description:Dock(TOP)
			description:SetTextColor(THEME.text)
			description:SetExpensiveShadow(1, color_black)
			description:SizeToContents()
			description:SetWrap(true)
			description:SetAutoStretchVertical(true)
			description:SetWide(container:GetWide())

			container:Add("Panel"):SetTall(8)
		end
	end
end)
