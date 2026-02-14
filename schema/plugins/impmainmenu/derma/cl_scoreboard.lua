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
	rowOdd = Color(18, 18, 18, 255),
	rowHover = Color(24, 22, 14, 255)
}

local function Scale(value)
	return math.max(1, math.Round(value * (ScrH() / 900)))
end

-- ---------------------------------------------------------------------------
-- Character Icon (spawn-icon renderer)
-- ---------------------------------------------------------------------------
local ICON = {}
local BODYGROUPS_EMPTY = "000000000"

AccessorFunc(ICON, "model", "Model", FORCE_STRING)
AccessorFunc(ICON, "bHidden", "Hidden", FORCE_BOOL)

function ICON:Init()
	self.bodygroups = BODYGROUPS_EMPTY
end

function ICON:SetModel(model, skin, bodygroups)
	model = model:gsub("\\", "/")

	if (isstring(bodygroups) and bodygroups:len() == 9) then
		for i = 1, bodygroups:len() do
			self:SetBodygroup(i, tonumber(bodygroups[i]) or 0)
		end
	else
		self.bodygroups = BODYGROUPS_EMPTY
	end

	self.model = model
	self.skin = skin
	self.path = "materials/spawnicons/" ..
		model:sub(1, #model - 4) ..
		((isnumber(skin) and skin > 0) and ("_skin" .. tostring(skin)) or "") ..
		(self.bodygroups != BODYGROUPS_EMPTY and ("_" .. self.bodygroups) or "") ..
		".png"

	local material = Material(self.path, "smooth")

	if (material:IsError()) then
		self.id = "ixScoreboardIcon" .. self.path
		self.renderer = self:Add("ModelImage")
		self.renderer:SetVisible(false)
		self.renderer:SetModel(model, skin, self.bodygroups)
		self.renderer:RebuildSpawnIcon()

		hook.Add("SpawniconGenerated", self.id, function(lastModel, filePath, modelsLeft)
			filePath = filePath:gsub("\\", "/"):lower()

			if (filePath == self.path) then
				hook.Remove("SpawniconGenerated", self.id)
				self.material = Material(filePath, "smooth")
				self.renderer:Remove()
			end
		end)
	else
		self.material = material
	end
end

function ICON:SetBodygroup(k, v)
	if (k < 0 or k > 8 or v < 0 or v > 9) then return end
	self.bodygroups = self.bodygroups:SetChar(k + 1, v)
end

function ICON:GetModel()
	return self.model or "models/error.mdl"
end

function ICON:GetSkin()
	return self.skin or 1
end

function ICON:DoClick() end
function ICON:DoRightClick() end

function ICON:OnMouseReleased(key)
	if (key == MOUSE_LEFT) then
		self:DoClick()
	elseif (key == MOUSE_RIGHT) then
		self:DoRightClick()
	end
end

function ICON:Paint(width, height)
	if (!self.material) then return end
	surface.SetMaterial(self.material)
	surface.SetDrawColor(self.bHidden and color_black or color_white)
	surface.DrawTexturedRect(0, 0, width, height)
end

function ICON:OnRemove()
	if (self.id) then
		hook.Remove("SpawniconGenerated", self.id)
	end
end

vgui.Register("ixScoreboardIcon", ICON, "Panel")

-- ---------------------------------------------------------------------------
-- Player Row
-- ---------------------------------------------------------------------------
local ROW = {}

function ROW:Init()
	self:SetTall(Scale(40))
	self:SetMouseInputEnabled(true)
	self.bHovered = false
	self.rowIndex = 0
	self.nextThink = CurTime() + 1
end

function ROW:SetupLayout()
	local rowH = self:GetTall()
	local iconSize = rowH - Scale(8)

	self.icon = self:Add("ixScoreboardIcon")
	self.icon:SetSize(iconSize, iconSize)
	self.icon:SetMouseInputEnabled(true)
	self.icon.DoRightClick = function()
		local client = self.player
		if (!IsValid(client)) then return end

		local menu = DermaMenu()
		menu:AddOption(L("viewProfile"), function() client:ShowProfile() end)
		menu:AddOption(L("copySteamID"), function()
			SetClipboardText(client:IsBot() and client:EntIndex() or client:SteamID())
		end)
		hook.Run("PopulateScoreboardPlayerMenu", client, menu)
		menu:Open()
	end

	self.icon:SetHelixTooltip(function(tooltip)
		local client = self.player
		if (IsValid(self) and IsValid(client)) then
			ix.hud.PopulatePlayerTooltip(tooltip, client)
		end
	end)

	self.name = self:Add("DLabel")
	self.name:SetFont("ixImpMenuButton")
	self.name:SetTextColor(THEME.text)
	self.name:SetContentAlignment(4)
	self.name:SetMouseInputEnabled(false)

	self.desc = self:Add("DLabel")
	self.desc:SetFont("ixImpMenuDiag")
	self.desc:SetTextColor(THEME.textMuted)
	self.desc:SetContentAlignment(4)
	self.desc:SetMouseInputEnabled(false)
end

function ROW:PerformLayout(w, h)
	if (!IsValid(self.icon)) then return end

	local pad = Scale(6)
	local iconSize = h - Scale(8)

	self.icon:SetPos(pad, math.floor((h - iconSize) * 0.5))
	self.icon:SetSize(iconSize, iconSize)

	local textX = pad + iconSize + Scale(8)
	local textW = w - textX - pad
	local nameH = Scale(16)
	local descH = Scale(14)
	local totalTextH = nameH + descH
	local textY = math.floor((h - totalTextH) * 0.5)

	self.name:SetPos(textX, textY)
	self.name:SetSize(textW, nameH)

	self.desc:SetPos(textX, textY + nameH)
	self.desc:SetSize(textW, descH)
end

function ROW:SetPlayer(client)
	self.player = client
	self.team = client:Team()
	self.character = client:GetCharacter()

	self:SetupLayout()
	self:Update()
end

function ROW:Update()
	local client = self.player
	if (!IsValid(client) or !IsValid(self.name)) then return end

	local model = client:GetModel()
	local skin = client:GetSkin()
	local name = client:GetName()
	local description = hook.Run("GetCharacterDescription", client)
		or (client:GetCharacter() and client:GetCharacter():GetDescription())
		or ""

	local bRecognize = false
	local localCharacter = LocalPlayer():GetCharacter()
	local character = client:GetCharacter()

	if (localCharacter and character) then
		bRecognize = hook.Run("IsCharacterRecognized", localCharacter, character:GetID())
			or hook.Run("IsPlayerRecognized", client)
	end

	self.icon:SetHidden(!bRecognize)
	self:SetZPos(bRecognize and 1 or 2)

	for _, v in pairs(client:GetBodyGroups()) do
		self.icon:SetBodygroup(v.id, client:GetBodygroup(v.id))
	end

	if (self.icon:GetModel() != model or self.icon:GetSkin() != skin) then
		self.icon:SetModel(model, skin)
	end

	self.name:SetText(name)
	self.desc:SetText(description)
end

function ROW:Think()
	if (CurTime() >= self.nextThink) then
		local client = self.player

		if (!IsValid(client) or !client:GetCharacter()
			or self.character != client:GetCharacter()
			or self.team != client:Team()) then
			self:Remove()
			return
		end

		self.nextThink = CurTime() + 1
	end
end

function ROW:OnCursorEntered()
	self.bHovered = true
end

function ROW:OnCursorExited()
	self.bHovered = false
end

function ROW:Paint(w, h)
	local bg = self.bHovered and THEME.rowHover
		or (self.rowIndex % 2 == 0 and THEME.rowEven or THEME.rowOdd)

	surface.SetDrawColor(bg)
	surface.DrawRect(0, 0, w, h)

	-- Subtle bottom separator
	surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 30)
	surface.DrawRect(0, h - 1, w, 1)
end

vgui.Register("ixScoreboardRow", ROW, "EditablePanel")

-- ---------------------------------------------------------------------------
-- Faction Section
-- ---------------------------------------------------------------------------
local FACTION_PANEL = {}

function FACTION_PANEL:Init()
	self:DockMargin(0, 0, 0, Scale(6))
	self.playerCount = 0

	local headerH = Scale(22)
	self.headerH = headerH

	self.header = self:Add("EditablePanel")
	self.header:Dock(TOP)
	self.header:SetTall(headerH)
	self.header.Paint = function(_, w, h)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawRect(0, 0, w, h)
	end

	self.title = self.header:Add("DLabel")
	self.title:Dock(LEFT)
	self.title:DockMargin(Scale(8), 0, 0, 0)
	self.title:SetFont("ixImpMenuButton")
	self.title:SetTextColor(Color(0, 0, 0, 255))
	self.title:SetContentAlignment(4)

	self.subtitle = self.header:Add("DLabel")
	self.subtitle:Dock(LEFT)
	self.subtitle:DockMargin(Scale(4), 0, 0, 0)
	self.subtitle:SetFont("ixImpMenuDiag")
	self.subtitle:SetTextColor(Color(0, 0, 0, 160))
	self.subtitle:SetContentAlignment(4)

	self.count = self.header:Add("DLabel")
	self.count:Dock(RIGHT)
	self.count:DockMargin(0, 0, Scale(8), 0)
	self.count:SetWide(Scale(80))
	self.count:SetFont("ixImpMenuDiag")
	self.count:SetTextColor(Color(0, 0, 0, 200))
	self.count:SetContentAlignment(6)

	self.list = self:Add("DListLayout")
	self.list:Dock(TOP)
	self.list:DockMargin(0, 0, 0, 0)
end

function FACTION_PANEL:SetFaction(faction)
	self.faction = faction

	local factionName = string.upper(L(faction.name))
	self.title:SetText(factionName)

	surface.SetFont("ixImpMenuButton")
	local tw = surface.GetTextSize(factionName)
	self.title:SetWide(tw + Scale(4))

	self.subtitle:SetText("//  ACTIVE PERSONNEL")
	surface.SetFont("ixImpMenuDiag")
	local sw = surface.GetTextSize("//  ACTIVE PERSONNEL")
	self.subtitle:SetWide(sw + Scale(4))
end

function FACTION_PANEL:AddPlayer(client, index)
	if (!IsValid(client) or !client:GetCharacter()
		or hook.Run("ShouldShowPlayerOnScoreboard", client) == false) then
		return false
	end

	local row = self.list:Add("ixScoreboardRow")
	row:Dock(TOP)
	row:SetPlayer(client)
	row.rowIndex = index
	client.ixScoreboardSlot = row

	return true
end

function FACTION_PANEL:Update()
	local faction = self.faction
	if (!faction) then return end

	local players = team.GetPlayers(faction.index)
	local count = 0

	for _, child in ipairs(self.list:GetChildren() or {}) do
		if (IsValid(child) and IsValid(child.player)) then
			child.player.ixScoreboardSlot = nil
		end
	end

	self.list:Clear()

	table.sort(players, function(a, b)
		return a:Nick() < b:Nick()
	end)

	for k, v in ipairs(players) do
		if (self:AddPlayer(v, k)) then
			count = count + 1
		end
	end

	self.playerCount = count
	self.count:SetText(Format("%d ACTIVE", count))

	-- Recalculate height: header + all row heights
	local totalH = self.headerH
	for _, child in ipairs(self.list:GetChildren() or {}) do
		if (IsValid(child)) then
			totalH = totalH + child:GetTall()
		end
	end

	self:SetTall(totalH)
	self:SetVisible(count > 0)
end

function FACTION_PANEL:Paint(w, h)
	-- Subtle outer border
	surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 40)
	surface.DrawOutlinedRect(0, 0, w, h)
end

vgui.Register("ixScoreboardFaction", FACTION_PANEL, "EditablePanel")

-- ---------------------------------------------------------------------------
-- Main Scoreboard
-- ---------------------------------------------------------------------------
local SCOREBOARD = {}

function SCOREBOARD:Init()
	if (IsValid(ix.gui.scoreboard)) then
		ix.gui.scoreboard:Remove()
	end

	self:Dock(FILL)

	local padding = Scale(32)
	self:DockPadding(padding, padding, padding, padding)

	-- Outer data-panel container
	self.container = self:Add("EditablePanel")
	self.container:Dock(FILL)
	self.container.headerH = Scale(24)
	self.container.Paint = function(pnl, w, h)
		local hH = pnl.headerH

		-- Black background
		surface.SetDrawColor(Color(0, 0, 0, 200))
		surface.DrawRect(0, 0, w, h)

		-- Gold header bar
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawRect(0, 0, w, hH)

		-- Frame outline
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawOutlinedRect(0, 0, w, h)

		-- Title
		draw.SimpleText("IMP-NET  //  PERSONNEL DATABASE", "ixImpMenuButton", Scale(10), hH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		-- Pulsing live indicator
		local pulse = math.abs(math.sin(CurTime() * 2))
		draw.SimpleText(
			string.char(0xE2, 0x97, 0x86) .. " LIVE",
			"ixImpMenuDiag",
			w - Scale(10), hH * 0.5,
			Color(0, 0, 0, math.Round(120 + pulse * 135)),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
		)
	end

	-- Scrollable content area
	self.scroll = self.container:Add("DScrollPanel")
	self.scroll:Dock(FILL)
	self.scroll:DockMargin(Scale(1), Scale(28), Scale(1), Scale(1))
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

	-- Status info strip
	self.status = self.scroll:Add("EditablePanel")
	self.status:Dock(TOP)
	self.status:SetTall(Scale(18))
	self.status:DockMargin(Scale(8), Scale(6), Scale(8), Scale(2))
	self.status.Paint = function(_, w, h)
		draw.SimpleText(
			Format("QUERY TIMESTAMP: %s  |  NODE: LOCAL-GARRISON", os.date("%H:%M:%S")),
			"ixImpMenuDiag", 0, h * 0.5,
			THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
		)

		local dots = string.rep(".", math.floor(CurTime() % 4))
		draw.SimpleText(
			"SCANNING" .. dots,
			"ixImpMenuDiag", w, h * 0.5,
			Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 120),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
		)
	end

	-- Thin separator
	local sep = self.scroll:Add("EditablePanel")
	sep:Dock(TOP)
	sep:SetTall(1)
	sep:DockMargin(Scale(8), Scale(2), Scale(8), Scale(6))
	sep.Paint = function(_, w, h)
		surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 50)
		surface.DrawRect(0, 0, w, h)
	end

	-- Build faction panels
	self.factions = {}
	self.nextThink = 0

	for i = 1, #ix.faction.indices do
		local faction = ix.faction.indices[i]
		local panel = self.scroll:Add("ixScoreboardFaction")
		panel:SetFaction(faction)
		panel:Dock(TOP)
		panel:DockMargin(Scale(8), 0, Scale(8), 0)
		self.factions[i] = panel
	end

	ix.gui.scoreboard = self
end

function SCOREBOARD:Paint(w, h)
	surface.SetDrawColor(THEME.background)
	surface.DrawRect(0, 0, w, h)
end

function SCOREBOARD:Think()
	if (CurTime() >= self.nextThink) then
		for i = 1, #self.factions do
			self.factions[i]:Update()
		end

		self.nextThink = CurTime() + 0.5
	end
end

vgui.Register("ixScoreboard", SCOREBOARD, "EditablePanel")

hook.Add("CreateMenuButtons", "ixScoreboard", function(tabs)
	tabs["scoreboard"] = function(container)
		local panel = container:Add("ixScoreboard")
		panel:Dock(FILL)
	end
end)
