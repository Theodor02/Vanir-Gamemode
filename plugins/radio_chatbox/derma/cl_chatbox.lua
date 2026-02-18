local PLUGIN = PLUGIN


local animationTime = 0.5
local chatBorder = 32
local sizingBorder = 20
local maxChatEntries = 100

local THEME = {
	background = Color(10, 10, 10, 240),
	frame = Color(191, 148, 53, 255),
	frameSoft = Color(191, 148, 53, 120),
	text = Color(235, 235, 235, 245),
	textMuted = Color(168, 168, 168, 140),
	accent = Color(191, 148, 53, 255),
	accentSoft = Color(191, 148, 53, 220),
	accentDark = Color(120, 93, 33, 180),
	danger = Color(180, 60, 60, 255),
	ready = Color(60, 170, 90, 255),
	warning = Color(200, 200, 50, 255),
	info = Color(75, 150, 150, 255),
	ooc = Color(100, 160, 220, 255),
	buttonBg = Color(16, 16, 16, 220),
	buttonBgHover = Color(26, 26, 26, 230),
	inputBg = Color(6, 6, 6, 220),
	inputBorder = Color(191, 148, 53, 80)
}


local CLASS_COLORS = {
	ic = THEME.text,
	me = THEME.accent,
	it = THEME.accent,
	w = Color(180, 180, 180, 200),
	y = Color(220, 180, 60, 255),
	ooc = THEME.ooc,
	looc = THEME.ooc,
	roll = Color(200, 120, 220, 255),
	pm = Color(200, 100, 100, 255),
	event = Color(200, 150, 50, 255),
	radio = Color(75, 150, 50, 255),
	radio_yell = THEME.warning,
	radio_whisper = THEME.info,
	notice = THEME.textMuted,
	connect = THEME.ready,
	disconnect = THEME.danger
}

local SOUND_CLICK = "everfall/miscellaneous/ux/navigation/navigation_activate_01.mp3"

-- Chat classes that get the datapad-entry treatment
local COMMS_CLASSES = {
	radio = true,
	radio_yell = true,
	radio_whisper = true
}

-- Typewriter animation speeds (characters per second)
local TYPE_SPEED = 70         -- normal
local TYPE_SPEED_COMMS = 30    -- comms entries

local function Scale(value)
	return math.max(1, math.Round(value * (ScrH() / 900)))
end

local function CreateImperialChatFonts()
	surface.CreateFont("ixImpChatHeader", {
		font = "Roboto",
		size = Scale(13),
		weight = 700,
		antialias = true,
		extended = true
	})

	surface.CreateFont("ixImpChatAurebesh", {
		font = "Aurebesh",
		size = Scale(10),
		weight = 500,
		antialias = true,
		extended = true
	})

	surface.CreateFont("ixImpChatDiag", {
		font = "Roboto Condensed",
		size = Scale(10),
		weight = 500,
		antialias = true,
		extended = true
	})

	surface.CreateFont("ixImpChatStatus", {
		font = "Roboto",
		size = Scale(9),
		weight = 600,
		antialias = true,
		extended = true
	})

	surface.CreateFont("ixImpChatTab", {
		font = "Roboto",
		size = Scale(11),
		weight = 600,
		antialias = true,
		extended = true
	})
end

CreateImperialChatFonts()

hook.Add("OnScreenSizeChanged", "ixImperialChatFonts", function()
	CreateImperialChatFonts()
end)

hook.Add("LoadFonts", "ixImperialChatFonts", function()
	timer.Simple(0, CreateImperialChatFonts)
end)


local function PaintMarkupOverride(text, font, x, y, color, alignX, alignY, alpha)
	alpha = alpha or 255

	if (ix.option.Get("chatOutline", false)) then
		draw.SimpleTextOutlined(text, font, x, y, ColorAlpha(color, alpha), alignX, alignY, 1, Color(0, 0, 0, alpha))
	else
		surface.SetTextPos(x + 1, y + 1)
		surface.SetTextColor(0, 0, 0, alpha)
		surface.SetFont(font)
		surface.DrawText(text)

		surface.SetTextPos(x, y)
		surface.SetTextColor(color.r, color.g, color.b, alpha)
		surface.SetFont(font)
		surface.DrawText(text)
	end
end

local AUREBESH_PHRASES = {
	"LINK ESTABLISHED",
	"SIGNAL STABLE",
	"ENCRYPTION ACTIVE",
	"SCANNING CHANNEL",
	"TRANSMISSION READY",
	"FREQ LOCKED",
	"RELAY ONLINE",
	"UPLINK NOMINAL"
}


-- ixChatMessage 
local PANEL = {}

AccessorFunc(PANEL, "fadeDelay", "FadeDelay", FORCE_NUMBER)
AccessorFunc(PANEL, "fadeDuration", "FadeDuration", FORCE_NUMBER)

function PANEL:Init()
	self.text = ""
	self.alpha = 255
	self.fadeDelay = 15
	self.fadeDuration = 5
	self.chatClass = "notice"

	-- Typewriter state
	self.typeStartTime = RealTime()
	self.typeDuration = 0.3
	self.typeDone = false

	-- Comms / datapad entry
	self.isCommsEntry = false
	self.commsFreq = string.format("%.1f", math.random(1000, 9999) + math.random())
	self.commsTime = os.date("%H:%M:%S")
	self.commsHeaderH = 0
end

function PANEL:SetMarkup(text)
	self.text = text

	local parseWidth = self:GetWide()
	if (self.isCommsEntry) then
		parseWidth = parseWidth - Scale(8)
	end

	self.markup = ix.markup.Parse(self.text, parseWidth)
	self.markup.onDrawText = PaintMarkupOverride

	-- Calculate approximate raw character count for typing duration
	local rawText = text:gsub("<[^>]+>", "")
	local charCount = math.max(1, #rawText)
	local speed = self.isCommsEntry and TYPE_SPEED_COMMS or TYPE_SPEED
	self.typeDuration = math.max(0.15, charCount / speed)
	self.typeStartTime = RealTime()
	self.typeDone = false

	-- Height = optional comms header + markup
	self.commsHeaderH = self.isCommsEntry and Scale(16) or 0
	local pad = self.isCommsEntry and Scale(4) or 0
	self:SetTall(self.commsHeaderH + self.markup:GetHeight() + pad)

	-- Fade timer starts AFTER typing finishes
	timer.Simple(self.typeDuration + self.fadeDelay, function()
		if (not IsValid(self)) then return end

		self:CreateAnimation(self.fadeDuration, {
			index = 3,
			target = {alpha = 0}
		})
	end)
end

function PANEL:PerformLayout(width, height)
	if (not self.markup) then return end
	if ((IsValid(ix.gui.chat) and ix.gui.chat.bSizing) or width == self.markup:GetWidth()) then
		return
	end

	local parseWidth = width
	if (self.isCommsEntry) then
		parseWidth = parseWidth - Scale(8)
	end

	self.markup = ix.markup.Parse(self.text, parseWidth)
	self.markup.onDrawText = PaintMarkupOverride

	self.commsHeaderH = self.isCommsEntry and Scale(16) or 0
	local pad = self.isCommsEntry and Scale(4) or 0
	self:SetTall(self.commsHeaderH + self.markup:GetHeight() + pad)
end

function PANEL:Paint(width, height)
	-- Alpha calculation
	local newAlpha

	if (IsValid(ix.gui.characterMenu)) then
		newAlpha = math.min(255 - ix.gui.characterMenu.currentAlpha, self.alpha)
	elseif (IsValid(ix.gui.menu)) then
		newAlpha = math.min(255 - ix.gui.menu.currentAlpha, self.alpha)
	elseif (IsValid(ix.gui.chat) and ix.gui.chat:GetActive()) then
		newAlpha = math.max(ix.gui.chat.alpha, self.alpha)
	else
		newAlpha = self.alpha
	end

	if (newAlpha < 1) then return end

	-- Typewriter progress
	local elapsed = RealTime() - self.typeStartTime
	local typeProgress = math.Clamp(elapsed / math.max(0.01, self.typeDuration), 0, 1)
	if (typeProgress >= 1) then self.typeDone = true end

	local classColor = CLASS_COLORS[self.chatClass] or THEME.frameSoft
	local textX = Scale(4)
	local textY = 0

	if (self.isCommsEntry) then
		-- DATAPAD ENTRY 
		local hH = self.commsHeaderH

		-- Container background
		surface.SetDrawColor(0, 0, 0, math.min(50, newAlpha * 0.2))
		surface.DrawRect(0, 0, width, height)

		-- Left accent (thicker gold bar)
		surface.SetDrawColor(classColor.r, classColor.g, classColor.b, math.min(160, newAlpha * 0.65))
		surface.DrawRect(0, 0, Scale(3), height)

		-- Right border hint
		surface.SetDrawColor(classColor.r, classColor.g, classColor.b, math.min(25, newAlpha * 0.1))
		surface.DrawRect(width - 1, 0, 1, height)

		-- Bottom border
		surface.SetDrawColor(classColor.r, classColor.g, classColor.b, math.min(18, newAlpha * 0.07))
		surface.DrawRect(Scale(3), height - 1, width - Scale(3) - 1, 1)

		-- Header: ▸ TRANSMISSION // HH:MM:SS // FREQ XXXX.X
		local headerAlpha = math.min(180, newAlpha * 0.75)
		local label = self.commsLabel or "TRANSMISSION"
		draw.SimpleText(
			string.char(0xE2, 0x96, 0xB8) .. " " .. label .. "  //  " .. self.commsTime .. "  //  FREQ " .. self.commsFreq,
			"ixImpChatDiag",
			textX + Scale(2), hH * 0.5,
			Color(classColor.r, classColor.g, classColor.b, headerAlpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
		)

		-- Pulsing signal dot in header
		local pulse = math.abs(math.sin(RealTime() * 3 + self.typeStartTime))
		draw.SimpleText(
			string.char(0xE2, 0x97, 0x86),
			"ixImpChatDiag",
			width - Scale(6), hH * 0.5,
			Color(classColor.r, classColor.g, classColor.b, math.Round(headerAlpha * (0.3 + pulse * 0.7))),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
		)

		-- Separator under header
		surface.SetDrawColor(classColor.r, classColor.g, classColor.b, math.min(35, newAlpha * 0.14))
		surface.DrawRect(textX, hH, width - textX - Scale(2), 1)

		textX = textX + Scale(2)
		textY = hH + Scale(2)
	else
		-- ═══ NORMAL MESSAGE (thin accent bar) ═══
		local barAlpha = math.min(100, newAlpha * 0.5)
		surface.SetDrawColor(classColor.r, classColor.g, classColor.b, barAlpha)
		surface.DrawRect(0, 1, Scale(2), height - 2)
	end

	-- ═══ TYPEWRITER RENDER ═══
	if (not self.typeDone) then
		local mW = width - textX
		local mH = self.markup:GetHeight()

		-- Approximate line metrics
		surface.SetFont("ixChatFont")
		local _, fontH = surface.GetTextSize("Wg")
		fontH = math.max(fontH, 14)
		local numLines = math.max(1, math.Round(mH / fontH))

		-- How many lines revealed
		local revealedFrac = typeProgress * numLines
		local fullLines = math.floor(revealedFrac)
		local partialFrac = revealedFrac - fullLines

		local screenX, screenY = self:LocalToScreen(textX, textY)

		-- Pass 1: fully revealed lines
		if (fullLines > 0) then
			render.SetScissorRect(
				screenX, screenY,
				screenX + mW, screenY + fullLines * fontH,
				true
			)
			self.markup:draw(textX, textY, nil, nil, newAlpha)
			render.SetScissorRect(0, 0, 0, 0, false)
		end

		-- Pass 2: partially revealed line
		if (fullLines < numLines and partialFrac > 0) then
			local partialRight = screenX + math.ceil(mW * partialFrac)
			render.SetScissorRect(
				screenX, screenY + fullLines * fontH,
				partialRight, screenY + (fullLines + 1) * fontH,
				true
			)
			self.markup:draw(textX, textY, nil, nil, newAlpha)
			render.SetScissorRect(0, 0, 0, 0, false)
		end

		-- Blinking cursor at the reveal edge
		if (math.sin(RealTime() * 8) > 0) then
			local cursorX, cursorY

			if (fullLines < numLines) then
				cursorX = textX + mW * partialFrac
				cursorY = textY + fullLines * fontH
			else
				cursorX = textX + mW
				cursorY = textY + (numLines - 1) * fontH
			end

			local cursorAlpha = math.min(180, newAlpha * 0.7)
			surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, cursorAlpha)
			surface.DrawRect(math.Round(cursorX), cursorY + 2, Scale(1), fontH - 4)
		end
	else
		-- Typing complete — draw normally
		self.markup:draw(textX, textY, nil, nil, newAlpha)
	end
end

vgui.Register("ixChatMessage", PANEL, "Panel")

-- ═══════════════════════════════════════════════════════════════════════════
-- ixChatboxTabButton — Tab button with Imperial styling
-- ═══════════════════════════════════════════════════════════════════════════
PANEL = {}

AccessorFunc(PANEL, "bActive", "Active", FORCE_BOOL)
AccessorFunc(PANEL, "bUnread", "Unread", FORCE_BOOL)

function PANEL:Init()
	self:SetFont("ixImpChatTab")
	self:SetContentAlignment(5)
	self.unreadAlpha = 0
end

function PANEL:SetUnread(bValue)
	self.bUnread = bValue

	self:CreateAnimation(animationTime, {
		index = 4,
		target = {unreadAlpha = bValue and 1 or 0},
		easing = "outQuint"
	})
end

function PANEL:SizeToContents()
	local width, height = self:GetContentSize()
	self:SetSize(width + 16, height + 8)
end

function PANEL:Paint(width, height)
	if (self:GetActive()) then
		-- Active: gold header bar with dark text
		surface.SetDrawColor(THEME.accentSoft)
		surface.DrawRect(0, 0, width, height)
		self:SetTextColor(Color(0, 0, 0, 255))
	else
		-- Inactive: dark background
		surface.SetDrawColor(0, 0, 0, 180)
		surface.DrawRect(0, 0, width, height)

		if (self:IsHovered()) then
			self:SetTextColor(THEME.text)
			surface.SetDrawColor(THEME.accentSoft.r, THEME.accentSoft.g, THEME.accentSoft.b, 20)
			surface.DrawRect(0, 0, width, height)
		else
			self:SetTextColor(THEME.textMuted)
		end

		-- Unread indicator (gold glow from bottom)
		if (self.unreadAlpha > 0) then
			local a = math.Round(self.unreadAlpha * 80)
			surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, a)
			surface.DrawRect(0, height - Scale(2), width, Scale(2))
		end
	end

	-- Right separator
	surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 40)
	surface.DrawRect(width - 1, 0, 1, height)
end

vgui.Register("ixChatboxTabButton", PANEL, "DButton")

-- ═══════════════════════════════════════════════════════════════════════════
-- ixChatboxTabs — Tab container / switcher
-- ═══════════════════════════════════════════════════════════════════════════
PANEL = {}

function PANEL:Init()
	self.buttons = self:Add("Panel")
	self.buttons:Dock(TOP)
	self.buttons:DockPadding(1, 1, 0, 0)
	self.buttons.OnMousePressed = function(_, ...) if (IsValid(ix.gui.chat)) then ix.gui.chat:OnMousePressed(...) end end
	self.buttons.OnMouseReleased = function(_, ...) if (IsValid(ix.gui.chat)) then ix.gui.chat:OnMouseReleased(...) end end
	self.buttons.Paint = function(_, width, height)
		-- Dark bar background with subtle bottom border
		surface.SetDrawColor(0, 0, 0, 33)
		surface.DrawRect(0, 0, width, height)

		-- Bottom line under active tab
		local tab = self:GetActiveTab()

		if (tab) then
			local button = tab:GetButton()
			local x = button:GetPos()

			surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 60)
			surface.DrawRect(0, height - 1, x, 1)
			surface.DrawRect(x + button:GetWide(), height - 1, width - x - button:GetWide(), 1)
		end
	end

	self.tabs = {}
end

function PANEL:GetTabs()
	return self.tabs
end

function PANEL:AddTab(id, filter, whitelist)
	local button = self.buttons:Add("ixChatboxTabButton")
	button:Dock(LEFT)
	button:SetText(id)
	button:SetActive(false)
	button:SetMouseInputEnabled(true)
	button:SizeToContents()
	button.DoClick = function(this)
		surface.PlaySound(SOUND_CLICK)
		self:SetActiveTab(this:GetText())
	end

	local panel = self:Add("ixChatboxHistory")
	panel:SetButton(button)
	panel:SetID(id)
	panel:Dock(FILL)
	panel:SetVisible(false)
	panel:SetFilter(filter or {})

	if (whitelist) then
		panel:SetWhitelist(whitelist)
	end

	button.DoRightClick = function(this)
		if (IsValid(ix.gui.chat)) then
			ix.gui.chat:OnTabRightClick(this, panel, panel:GetID())
		end
	end

	self.tabs[id] = panel
	return panel
end

function PANEL:RemoveTab(id)
	local tab = self.tabs[id]
	if (not tab) then return end

	tab:GetButton():Remove()
	tab:Remove()
	self.tabs[id] = nil

	if (table.IsEmpty(self.tabs)) then
		self:AddTab("ALL BANDS", {})
		self:SetActiveTab("ALL BANDS")
	elseif (id == self:GetActiveTabID()) then
		self:SetActiveTab(next(self.tabs))
	end
end

function PANEL:RenameTab(id, newID)
	local tab = self.tabs[id]
	if (not tab) then return end

	tab:GetButton():SetText(newID)
	tab:GetButton():SizeToContents()
	tab:SetID(newID)
	self.tabs[id] = nil
	self.tabs[newID] = tab

	if (id == self:GetActiveTabID()) then
		self:SetActiveTab(newID)
	end
end

function PANEL:SetActiveTab(id)
	local tab = self.tabs[id]
	if (not tab) then return end

	for _, v in ipairs(self.buttons:GetChildren()) do
		v:SetActive(v:GetText() == id)
	end

	for _, v in pairs(self.tabs) do
		v:SetVisible(v:GetID() == id)
	end

	tab:GetButton():SetUnread(false)
	self.activeTab = id
	self:OnTabChanged(tab)
end

function PANEL:GetActiveTabID()
	return self.activeTab
end

function PANEL:GetActiveTab()
	return self.tabs[self.activeTab]
end

function PANEL:OnTabChanged(panel) end

vgui.Register("ixChatboxTabs", PANEL, "EditablePanel")

-- ═══════════════════════════════════════════════════════════════════════════
-- ixChatboxHistory — Scrollable message container (one per tab)
-- ═══════════════════════════════════════════════════════════════════════════
PANEL = {}

AccessorFunc(PANEL, "filter", "Filter")
AccessorFunc(PANEL, "id", "ID", FORCE_STRING)
AccessorFunc(PANEL, "button", "Button")

function PANEL:Init()
	self:DockMargin(4, 2, 4, 4)
	self:SetPaintedManually(true)

	-- Imperial scrollbar
	local bar = self:GetVBar()
	bar:SetWide(Scale(4))
	bar.Paint = function(_, w, h)
		surface.SetDrawColor(0, 0, 0, 30)
		surface.DrawRect(0, 0, w, h)
	end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(_, w, h)
		surface.SetDrawColor(THEME.accentSoft)
		surface.DrawRect(0, 0, w, h)
	end

	self.entries = {}
	self.filter = {}
	self.whitelist = nil
end

function PANEL:SetWhitelist(whitelist)
	if (istable(whitelist)) then
		local tbl = {}

		for _, v in ipairs(whitelist) do
			tbl[v] = true
		end

		self.whitelist = tbl
	else
		self.whitelist = nil
	end
end

function PANEL:GetWhitelist()
	return self.whitelist
end

--- Returns true if a chat class should be shown in this tab.
function PANEL:ShouldShowClass(class)
	if (self.whitelist and next(self.whitelist)) then
		return self.whitelist[class] == true
	end

	return not self.filter[class]
end

DEFINE_BASECLASS("Panel")
function PANEL:SetVisible(bState)
	self:GetCanvas():SetVisible(bState)
	BaseClass.SetVisible(self, bState)
end

DEFINE_BASECLASS("DScrollPanel")
function PANEL:PerformLayoutInternal()
	local bar = self:GetVBar()
	local bScroll = not ix.gui.chat:GetActive() or bar.Scroll == bar.CanvasSize

	BaseClass.PerformLayoutInternal(self)

	if (bScroll) then
		self:ScrollToBottom()
	end
end

function PANEL:ScrollToBottom()
	local bar = self:GetVBar()
	bar:SetScroll(bar.CanvasSize)
end

function PANEL:AddLine(elements, bShouldScroll)
	local buffer = {"<font=ixChatFont>"}

	-- Timestamp support
	if (ix.option.Get("chatTimestamps", false)) then
		buffer[#buffer + 1] = "<color=150,150,150>("

		if (ix.option.Get("24hourTime", false)) then
			buffer[#buffer + 1] = os.date("%H:%M")
		else
			buffer[#buffer + 1] = os.date("%I:%M %p")
		end

		buffer[#buffer + 1] = ") "
	end

	-- Chat class font override
	if (CHAT_CLASS) then
		buffer[#buffer + 1] = "<font="
		buffer[#buffer + 1] = CHAT_CLASS.font or "ixChatFont"
		buffer[#buffer + 1] = ">"
	end

	-- Build markup from elements
	for _, v in ipairs(elements) do
		if (type(v) == "IMaterial") then
			local texture = v:GetName()

			if (texture) then
				buffer[#buffer + 1] = string.format("<img=%s,%dx%d> ", texture, v:Width(), v:Height())
			end
		elseif (istable(v) and v.r and v.g and v.b) then
			buffer[#buffer + 1] = string.format("<color=%d,%d,%d>", v.r, v.g, v.b)
		elseif (type(v) == "Player") then
			local color = team.GetColor(v:Team())

			buffer[#buffer + 1] = string.format(
				"<color=%d,%d,%d>%s", color.r, color.g, color.b,
				v:GetName():gsub("<", "&lt;"):gsub(">", "&gt;")
			)
		else
			buffer[#buffer + 1] = tostring(v):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("%b**", function(value)
				local inner = value:utf8sub(2, -2)

				if (inner:find("%S")) then
					return "<font=ixChatFontItalics>" .. inner .. "</font>"
				end
			end)
		end
	end

	local chatClass = CHAT_CLASS and CHAT_CLASS.uniqueID or "notice"

	local panel = self:Add("ixChatMessage")
	panel:Dock(TOP)
	panel.chatClass = chatClass
	panel.isCommsEntry = COMMS_CLASSES[chatClass] == true

	-- Comms header label
	if (panel.isCommsEntry) then
		local labels = {
			radio = "COMMS RELAY",
			radio_yell = "PRIORITY BROADCAST",
			radio_whisper = "ENCRYPTED CHANNEL"
		}

		panel.commsLabel = labels[chatClass] or "TRANSMISSION"
	end

	panel:InvalidateParent(true)
	panel:SetMarkup(table.concat(buffer))

	if (#self.entries >= maxChatEntries) then
		local oldPanel = table.remove(self.entries, 1)
		if (IsValid(oldPanel)) then oldPanel:Remove() end
	end

	self.entries[#self.entries + 1] = panel
	return panel
end

vgui.Register("ixChatboxHistory", PANEL, "DScrollPanel")

-- ═══════════════════════════════════════════════════════════════════════════
-- ixChatboxEntry — Text input field
-- ═══════════════════════════════════════════════════════════════════════════
PANEL = {}
DEFINE_BASECLASS("DTextEntry")

function PANEL:Init()
	self:SetFont("ixChatFont")
	self:SetUpdateOnType(true)
	self:SetHistoryEnabled(true)
	self.History = ix.chat.history
	self.m_bLoseFocusOnClickAway = false
end

function PANEL:SetFont(font)
	BaseClass.SetFont(self, font)
	surface.SetFont(font)
	local _, height = surface.GetTextSize("W@")
	self:SetTall(height + 8)
end

function PANEL:AllowInput(newCharacter)
	local text = self:GetText()
	local maxLength = ix.config.Get("chatMax")

	if (string.len(text .. newCharacter) > maxLength) then
		surface.PlaySound("common/talk.wav")
		return true
	end
end

function PANEL:Think()
	local text = self:GetText()
	local maxLength = ix.config.Get("chatMax", 256)

	if (text:utf8len() > maxLength) then
		local newText = text:utf8sub(0, maxLength)
		self:SetText(newText)
		self:SetCaretPos(newText:utf8len())
	end
end

function PANEL:Paint(width, height)
	-- Imperial styled entry: dark background + gold border
	surface.SetDrawColor(THEME.inputBg)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(THEME.inputBorder)
	surface.DrawOutlinedRect(0, 0, width, height)

	self:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
end

vgui.Register("ixChatboxEntry", PANEL, "DTextEntry")

-- ═══════════════════════════════════════════════════════════════════════════
-- ixChatboxPrefix — Chat class indicator box (left of text entry)
-- ═══════════════════════════════════════════════════════════════════════════
PANEL = {}

AccessorFunc(PANEL, "text", "Text", FORCE_STRING)
AccessorFunc(PANEL, "padding", "Padding", FORCE_NUMBER)
AccessorFunc(PANEL, "backgroundColor", "BackgroundColor")
AccessorFunc(PANEL, "textColor", "TextColor")

function PANEL:Init()
	self.text = ""
	self.padding = 4
	self.currentWidth = 0
	self.currentMargin = 0
	self.backgroundColor = THEME.accent
	self.textColor = color_white
	self:SetWide(0)
	self:DockMargin(0, 0, 0, 0)
end

function PANEL:SetText(text)
	self:SetVisible(true)

	if (not isstring(text) or text == "") then
		self:CreateAnimation(animationTime, {
			index = 9,
			easing = "outQuint",
			target = {currentWidth = 0, currentMargin = 0},
			Think = function(animation, panel)
				panel:SetWide(panel.currentWidth)
				panel:DockMargin(0, 0, panel.currentMargin, 0)
			end,
			OnComplete = function(animation, panel)
				panel:SetVisible(false)
				self.text = ""
			end
		})
	else
		text = tostring(text)
		surface.SetFont("ixChatFont")
		local textWidth = surface.GetTextSize(text)

		self:CreateAnimation(animationTime, {
			index = 9,
			easing = "outQuint",
			target = {currentWidth = textWidth + self.padding * 2, currentMargin = 4},
			Think = function(animation, panel)
				panel:SetWide(panel.currentWidth)
				panel:DockMargin(0, 0, panel.currentMargin, 0)
			end,
		})

		self.text = text
	end
end

function PANEL:Paint(width, height)
	-- Imperial gold prefix box
	local color = self.backgroundColor or THEME.accent
	surface.SetDrawColor(color.r, color.g, color.b, 180)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(color.r * 0.5, color.g * 0.5, color.b * 0.5, 255)
	surface.DrawOutlinedRect(0, 0, width, height)

	surface.SetFont("ixChatFont")
	local textWidth, textHeight = surface.GetTextSize(self.text)
	surface.SetTextColor(self.textColor)
	surface.SetTextPos(width * 0.5 - textWidth * 0.5, height * 0.5 - textHeight * 0.5)
	surface.DrawText(self.text)
end

vgui.Register("ixChatboxPrefix", PANEL, "Panel")

-- ═══════════════════════════════════════════════════════════════════════════
-- ixChatboxPreview — Command argument preview bar
-- ═══════════════════════════════════════════════════════════════════════════
PANEL = {}
DEFINE_BASECLASS("Panel")

AccessorFunc(PANEL, "targetHeight", "TargetHeight", FORCE_NUMBER)
AccessorFunc(PANEL, "command", "Command", FORCE_STRING)

function PANEL:Init()
	self:SetTall(0)
	self:SetVisible(false, true)
	self.height = 0
	self.targetHeight = 16
	self.margin = 0
	self.command = ""
end

function PANEL:SetCommand(command)
	if (command == "") then
		self.command = ""
		ix.chat.currentCommand = ""
		return
	end

	local commandTable = ix.command.list[command]
	if (not commandTable) then return end

	self.command = command
	self.commandTable = commandTable
	self.arguments = {}
	ix.chat.currentCommand = command:lower()
end

function PANEL:UpdateArguments(text)
	if (self.command == "") then
		ix.chat.currentArguments = {}
		return
	end

	local commandName = text:match("(/(%w+)%s)") or self.command
	local givenArguments = ix.command.ExtractArgs(text:utf8sub(commandName:utf8len()))
	local commandArguments = self.commandTable.arguments or {}
	local arguments = {}

	for k, v in ipairs(givenArguments) do
		if (k == #commandArguments) then
			arguments[#arguments + 1] = table.concat(givenArguments, " ", k)
			break
		end

		arguments[#arguments + 1] = v
	end

	self.arguments = arguments
	ix.chat.currentArguments = table.Copy(arguments)
end

function PANEL:IsOpen()
	return self.bOpen
end

function PANEL:SetVisible(bValue, bForce)
	if (bForce) then
		BaseClass.SetVisible(self, bValue)
		return
	end

	BaseClass.SetVisible(self, true)
	self.bOpen = bValue

	self:CreateAnimation(animationTime * 0.5, {
		index = 5,
		target = {height = bValue and self.targetHeight or 0, margin = bValue and 4 or 0},
		easing = "outQuint",
		Think = function(animation, panel)
			panel:SetTall(math.ceil(panel.height))
			panel:DockMargin(4, 0, 4, math.ceil(panel.margin))
		end,
		OnComplete = function(animation, panel)
			BaseClass.SetVisible(panel, bValue)
		end
	})
end

--- Draws a single Imperial-styled preview argument box and returns its width.
local function DrawPreviewBox(x, y, text, color)
	color = color or THEME.accent
	surface.SetFont("ixChatFont")
	local textWidth, textHeight = surface.GetTextSize(text)
	local width, height = textWidth + 8, textHeight + 8

	surface.SetDrawColor(color)
	surface.DrawRect(x, y, width, height)

	surface.SetTextColor(color_white)
	surface.SetTextPos(x + width * 0.5 - textWidth * 0.5, y + height * 0.5 - textHeight * 0.5)
	surface.DrawText(text)

	surface.SetDrawColor(color.r * 0.5, color.g * 0.5, color.b * 0.5, 255)
	surface.DrawOutlinedRect(x, y, width, height)

	return width
end

function PANEL:Paint(width, height)
	local command = self.commandTable
	if (not command) then return end

	local x = DrawPreviewBox(0, 0, "/" .. command.name) + 6

	if (istable(command.arguments)) then
		for k, v in ipairs(command.arguments) do
			local bOptional = bit.band(v, ix.type.optional) > 0
			local argType = bOptional and bit.bxor(v, ix.type.optional) or v

			x = x + DrawPreviewBox(
				x, 0,
				string.format(bOptional and "[%s: %s]" or "<%s: %s>", command.argumentNames[k], ix.type[argType]),
				(k <= #self.arguments) and THEME.accent or (bOptional and Color(0, 0, 0, 66) or ColorAlpha(THEME.accent, 100))
			) + 6
		end
	end
end

vgui.Register("ixChatboxPreview", PANEL, "Panel")

-- ═══════════════════════════════════════════════════════════════════════════
-- ixChatboxAutocomplete — Command autocomplete dropdown
-- ═══════════════════════════════════════════════════════════════════════════
PANEL = {}
DEFINE_BASECLASS("Panel")

AccessorFunc(PANEL, "maxEntries", "MaxEntries", FORCE_NUMBER)

function PANEL:Init()
	self:SetVisible(false, true)
	self:SetMouseInputEnabled(true)
	self.maxEntries = 20
	self.currentAlpha = 0
	self.commandIndex = 0
	self.commands = {}
	self.commandPanels = {}
end

function PANEL:GetCommands()
	return self.commands
end

function PANEL:IsOpen()
	return self.bOpen
end

function PANEL:SetVisible(bValue, bForce)
	if (bForce) then
		BaseClass.SetVisible(self, bValue)
		return
	end

	BaseClass.SetVisible(self, true)
	self.bOpen = bValue

	self:CreateAnimation(animationTime, {
		index = 6,
		target = {currentAlpha = bValue and 255 or 0},
		easing = "outQuint",
		Think = function(animation, panel)
			panel:SetAlpha(math.ceil(panel.currentAlpha))
		end,
		OnComplete = function(animation, panel)
			BaseClass.SetVisible(panel, bValue)
			if (not bValue) then self.commands = {} end
		end
	})
end

function PANEL:Update(text)
	local commands = ix.command.FindAll(text, true, true, true)
	self.commandIndex = 0
	self.commands = {}

	for _, v in ipairs(self.commandPanels) do
		v:Remove()
	end

	self.commandPanels = {}

	local i = 1
	local bSelected

	for _, v in ipairs(commands) do
		if (v.OnCheckAccess and not v:OnCheckAccess(LocalPlayer())) then continue end

		local panel = self:Add("ixChatboxAutocompleteEntry")
		panel:SetCommand(v)

		if (not bSelected and text:utf8lower():utf8sub(1, v.uniqueID:utf8len()) == v.uniqueID) then
			panel:SetHighlighted(true)
			self.commandIndex = i
			bSelected = true
		end

		self.commandPanels[i] = panel
		self.commands[i] = v

		if (i == self.maxEntries) then break end
		i = i + 1
	end
end

function PANEL:SelectNext()
	if (self.commandIndex == #self.commands) then
		self.commandIndex = 1
	else
		self.commandIndex = self.commandIndex + 1
	end

	for k, v in ipairs(self.commandPanels) do
		if (k == self.commandIndex) then
			v:SetHighlighted(true)
			self:ScrollToChild(v)
		else
			v:SetHighlighted(false)
		end
	end

	return "/" .. self.commands[self.commandIndex].uniqueID
end

function PANEL:Paint(width, height)
	-- Imperial dark background
	surface.SetDrawColor(THEME.background)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 40)
	surface.DrawOutlinedRect(0, 0, width, height)
end

vgui.Register("ixChatboxAutocomplete", PANEL, "DScrollPanel")

-- ═══════════════════════════════════════════════════════════════════════════
-- ixChatboxAutocompleteEntry — Individual autocomplete entry
-- ═══════════════════════════════════════════════════════════════════════════
PANEL = {}

AccessorFunc(PANEL, "bSelected", "Highlighted", FORCE_BOOL)

function PANEL:Init()
	self:Dock(TOP)

	self.name = self:Add("DLabel")
	self.name:Dock(TOP)
	self.name:DockMargin(4, 4, 0, 0)
	self.name:SetContentAlignment(4)
	self.name:SetFont("ixChatFont")
	self.name:SetTextColor(THEME.accent)
	self.name:SetExpensiveShadow(1, color_black)

	self.description = self:Add("DLabel")
	self.description:Dock(BOTTOM)
	self.description:DockMargin(4, 4, 0, 4)
	self.description:SetContentAlignment(4)
	self.description:SetFont("ixChatFont")
	self.description:SetTextColor(THEME.text)
	self.description:SetExpensiveShadow(1, color_black)

	self.highlightAlpha = 0
end

function PANEL:SetHighlighted(bValue)
	self:CreateAnimation(animationTime * 2, {
		index = 7,
		target = {highlightAlpha = bValue and 1 or 0},
		easing = "outQuint"
	})

	self.bHighlighted = true
end

function PANEL:SetCommand(command)
	local description = command:GetDescription()
	self.name:SetText("/" .. command.name)

	if (description and description ~= "") then
		self.description:SetText(command:GetDescription())
	else
		self.description:SetVisible(false)
	end

	self:SizeToContents()
	self.command = command
end

function PANEL:SizeToContents()
	local bDescriptionVisible = self.description:IsVisible()
	local _, height = self.name:GetContentSize()
	self.name:SetTall(height)

	if (bDescriptionVisible) then
		_, height = self.description:GetContentSize()
		self.description:SetTall(height)
	else
		self.description:SetTall(0)
	end

	self:SetTall(self.name:GetTall() + self.description:GetTall() + (bDescriptionVisible and 12 or 8))
end

function PANEL:Paint(width, height)
	-- Imperial gold highlight on selected
	if (self.highlightAlpha > 0) then
		surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, math.Round(self.highlightAlpha * 40))
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, math.Round(self.highlightAlpha * 80))
		surface.DrawRect(0, 0, Scale(2), height)
	end

	-- Bottom separator
	surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 25)
	surface.DrawRect(0, height - 1, width, 1)
end

vgui.Register("ixChatboxAutocompleteEntry", PANEL, "Panel")

-- ═══════════════════════════════════════════════════════════════════════════
-- ixChatbox — MAIN CHATBOX PANEL (complete Helix replacement)
-- ═══════════════════════════════════════════════════════════════════════════
PANEL = {}

AccessorFunc(PANEL, "bActive", "Active", FORCE_BOOL)

function PANEL:Init()
	ix.gui.chat = self

	self:SetSize(self:GetDefaultSize())
	self:SetPos(self:GetDefaultPosition())

	self.alpha = 0
	self.headerHeight = Scale(24)

	-- Aurebesh animation state
	self.aurebeshText = ""
	self.aurebeshPhrase = "INITIALIZING"
	self.aurebeshState = "type"
	self.aurebeshNextTime = RealTime()
	self.aurebeshIndex = 0

	-- -----------------------------------------------------------------------
	-- Imperial header bar (TOP)
	-- -----------------------------------------------------------------------
	self.header = self:Add("EditablePanel")
	self.header:Dock(TOP)
	self.header:SetTall(self.headerHeight)
	self.header.chatbox = self
	self.header.OnMousePressed = function(_, ...) self:OnMousePressed(...) end
	self.header.OnMouseReleased = function(_, ...) self:OnMouseReleased(...) end
	self.header.Paint = function(hdr, w, h)
		-- Gold header
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawRect(0, 0, w, h)

		-- Title
		draw.SimpleText(
			"IMP-NET  //  COMMS TERMINAL", "ixImpChatHeader",
			Scale(8), h * 0.5,
			Color(0, 0, 0, 255),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
		)

		-- Pulsing live indicator
		local pulse = math.abs(math.sin(CurTime() * 2))
		draw.SimpleText(
			string.char(0xE2, 0x97, 0x86) .. " LIVE",
			"ixImpChatDiag",
			w - Scale(8), h * 0.5,
			Color(0, 0, 0, math.Round(120 + pulse * 135)),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
		)

		-- Aurebesh text
		local parent = hdr.chatbox
		if (parent and parent.aurebeshText) then
			draw.SimpleText(
				parent.aurebeshText, "ixImpChatAurebesh",
				w - Scale(50), h * 0.5,
				Color(0, 0, 0, 80),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
			)
		end
	end

	-- -----------------------------------------------------------------------
	-- Status bar (BOTTOM)
	-- -----------------------------------------------------------------------
	self.statusBar = self:Add("EditablePanel")
	self.statusBar:Dock(BOTTOM)
	self.statusBar:SetTall(Scale(16))
	self.statusBar:DockMargin(Scale(1), 0, Scale(1), Scale(1))
	self.statusBar.Paint = function(_, w, h)
		surface.SetDrawColor(0, 0, 0, 160)
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 30)
		surface.DrawRect(0, 0, w, 1)

		-- Connection status
		local pulse = math.abs(math.sin(CurTime() * 2))
		draw.SimpleText(
			string.char(0xE2, 0x97, 0x86) .. " CONNECTED",
			"ixImpChatStatus", Scale(4), h * 0.5,
			Color(THEME.ready.r, THEME.ready.g, THEME.ready.b, math.Round(120 + pulse * 135)),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
		)

		-- Timestamp
		draw.SimpleText(
			os.date("%H:%M:%S"), "ixImpChatDiag",
			w - Scale(4), h * 0.5,
			THEME.textMuted,
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
		)
	end

	-- -----------------------------------------------------------------------
	-- Entry panel (BOTTOM, above status)
	-- -----------------------------------------------------------------------
	local entryPanel = self:Add("Panel")
	entryPanel:SetZPos(1)
	entryPanel:Dock(BOTTOM)
	entryPanel:DockMargin(Scale(1), 0, Scale(1), 0)

	self.entry = entryPanel:Add("ixChatboxEntry")
	self.entry:Dock(FILL)
	self.entry.OnValueChange = ix.util.Bind(self, self.OnTextChanged)
	self.entry.OnKeyCodeTyped = ix.util.Bind(self, self.OnKeyCodeTyped)
	self.entry.OnEnter = ix.util.Bind(self, self.OnMessageSent)

	self.prefix = entryPanel:Add("ixChatboxPrefix")
	self.prefix:Dock(LEFT)

	-- -----------------------------------------------------------------------
	-- Command preview (BOTTOM, above entry)
	-- -----------------------------------------------------------------------
	self.preview = self:Add("ixChatboxPreview")
	self.preview:SetZPos(2)
	self.preview:Dock(BOTTOM)
	self.preview:SetTargetHeight(self.entry:GetTall())

	-- -----------------------------------------------------------------------
	-- Tabs (FILL — occupies remaining space)
	-- -----------------------------------------------------------------------
	self.tabs = self:Add("ixChatboxTabs")
	self.tabs:Dock(FILL)
	self.tabs.OnTabChanged = ix.util.Bind(self, self.OnTabChanged)

	-- Autocomplete overlay inside tabs
	self.autocomplete = self.tabs:Add("ixChatboxAutocomplete")
	self.autocomplete:Dock(FILL)
	self.autocomplete:DockMargin(4, 3, 4, 4)
	self.autocomplete:SetZPos(3)

	-- -----------------------------------------------------------------------
	-- Final init
	-- -----------------------------------------------------------------------
	self:SetActive(false)

	chat.GetChatBoxPos = function() return self:GetPos() end
	chat.GetChatBoxSize = function() return self:GetSize() end
end

function PANEL:GetDefaultSize()
	return ScrW() * 0.4, ScrH() * 0.375
end

function PANEL:GetDefaultPosition()
	return chatBorder, ScrH() - self:GetTall() - chatBorder
end

-- ---------------------------------------------------------------------------
-- Alpha management (matches original Helix behavior exactly)
-- ---------------------------------------------------------------------------
DEFINE_BASECLASS("Panel")
function PANEL:SetAlpha(amount, duration)
	self:CreateAnimation(duration or animationTime, {
		index = 1,
		target = {alpha = amount},
		easing = "outQuint",
		Think = function(animation, panel)
			BaseClass.SetAlpha(panel, panel.alpha)
		end
	})
end

-- ---------------------------------------------------------------------------
-- Activation (open/close)
-- ---------------------------------------------------------------------------
function PANEL:SetActive(bActive)
	if (bActive) then
		self:SetAlpha(255)
		self:MakePopup()
		self.entry:RequestFocus()
		input.SetCursorPos(self:LocalToScreen(-1, -1))
		hook.Run("StartChat")
		self.prefix:SetText(hook.Run("GetChatPrefixInfo", ""))
	else
		if (self.bSizing or self.DragOffset) then
			self:OnMouseReleased(MOUSE_LEFT)
		end

		self:SetAlpha(0)
		self:SetMouseInputEnabled(false)
		self:SetKeyboardInputEnabled(false)
		self.autocomplete:SetVisible(false)
		self.preview:SetVisible(false)
		self.entry:SetText("")
		self.preview:SetCommand("")
		self.prefix:SetText(hook.Run("GetChatPrefixInfo", ""))
		CloseDermaMenus()
		gui.EnableScreenClicker(false)
		hook.Run("FinishChat")
	end

	local tab = self.tabs:GetActiveTab()
	if (tab) then tab:ScrollToBottom() end

	self.bActive = tobool(bActive)
end

-- ---------------------------------------------------------------------------
-- Tab setup (from saved config or defaults)
-- ---------------------------------------------------------------------------
function PANEL:SetupTabs(tabs)
	if (not tabs or table.IsEmpty(tabs)) then
		-- Default Imperial tabs
		self.tabs:AddTab("ALL BANDS", {})
		self.tabs:AddTab("COMMS", {}, {"radio", "radio_yell", "radio_whisper"})
		self.tabs:SetActiveTab("ALL BANDS")
		return
	end

	for id, filter in pairs(tabs) do
		self.tabs:AddTab(id, filter)
	end

	self.tabs:SetActiveTab(next(tabs))
end

function PANEL:SetupPosition(info)
	local x, y, width, height

	if (not istable(info)) then
		x, y = self:GetDefaultPosition()
		width, height = self:GetDefaultSize()
	else
		width = math.Clamp(info[3], 32, ScrW() - chatBorder * 2)
		height = math.Clamp(info[4], 32, ScrH() - chatBorder * 2)
		x = math.Clamp(info[1], 0, ScrW() - width)
		y = math.Clamp(info[2], 0, ScrH() - height)
	end

	self:SetSize(width, height)
	self:SetPos(x, y)
	PLUGIN:SavePosition()
end

-- ---------------------------------------------------------------------------
-- Interaction bounds
-- ---------------------------------------------------------------------------
function PANEL:SizingInBounds()
	local screenX, screenY = self:LocalToScreen(0, 0)
	local mouseX, mouseY = gui.MousePos()
	return mouseX > screenX + self:GetWide() - sizingBorder
		and mouseY > screenY + self:GetTall() - sizingBorder
end

function PANEL:DraggingInBounds()
	local _, screenY = self:LocalToScreen(0, 0)
	local mouseY = gui.MouseY()
	return mouseY > screenY and mouseY < screenY + self.headerHeight + self.tabs.buttons:GetTall()
end

-- ---------------------------------------------------------------------------
-- Mouse interaction (drag / resize)
-- ---------------------------------------------------------------------------
function PANEL:OnMousePressed(key)
	if (key == MOUSE_RIGHT) then
		local menu = DermaMenu()

		menu:AddOption(L("chatNewTab"), function()
			if (IsValid(ix.gui.chatTabCustomize)) then
				ix.gui.chatTabCustomize:Remove()
			end

			local panel = vgui.Create("ixChatboxTabCustomize")
			panel.OnTabCreated = ix.util.Bind(self, self.OnTabCreated)
		end)

		menu:AddOption(L("chatMarkRead"), function()
			for _, v in pairs(self.tabs:GetTabs()) do
				v:GetButton():SetUnread(false)
			end
		end)

		menu:AddSpacer()

		menu:AddOption(L("chatReset"), function()
			local rx, ry = self:GetDefaultPosition()
			local rw, rh = self:GetDefaultSize()

			self:SetSize(rw, rh)
			self:SetPos(rx, ry)
			ix.option.Set("chatPosition", "")
			hook.Run("ChatboxPositionChanged", rx, ry, rw, rh)
		end)

		menu:AddOption(L("chatResetTabs"), function()
			for id in pairs(self.tabs:GetTabs()) do
				self.tabs:RemoveTab(id)
			end

			ix.option.Set("chatTabs", "")
		end)

		menu:Open()
		menu:MakePopup()
		return
	end

	if (key ~= MOUSE_LEFT) then return end

	if (self:SizingInBounds()) then
		self.bSizing = true
		self:MouseCapture(true)
	elseif (self:DraggingInBounds()) then
		local mouseX, mouseY = self:ScreenToLocal(gui.MousePos())
		self.DragOffset = {mouseX, mouseY}
		self:MouseCapture(true)
	end
end

function PANEL:OnMouseReleased()
	self:MouseCapture(false)
	self:SetCursor("arrow")

	if (self.bSizing or self.DragOffset) then
		PLUGIN:SavePosition()
		self.bSizing = nil
		self.DragOffset = nil
		self:InvalidateChildren(true)

		local px, py = self:GetPos()
		local pw, ph = self:GetSize()
		hook.Run("ChatboxPositionChanged", px, py, pw, ph)
	end
end

-- ---------------------------------------------------------------------------
-- Think (cursor, resizing, Aurebesh animation)
-- ---------------------------------------------------------------------------
function PANEL:Think()
	if (self.bActive) then
		local mouseX = math.Clamp(gui.MouseX(), 0, ScrW())
		local mouseY = math.Clamp(gui.MouseY(), 0, ScrH())

		if (self.bSizing) then
			local sx, sy = self:GetPos()
			local sw = math.Clamp(mouseX - sx, chatBorder, ScrW() - chatBorder * 2)
			local sh = math.Clamp(mouseY - sy, chatBorder, ScrH() - chatBorder * 2)
			self:SetSize(sw, sh)
			self:SetCursor("sizenwse")
		elseif (self.DragOffset) then
			local dx = math.Clamp(mouseX - self.DragOffset[1], 0, ScrW() - self:GetWide())
			local dy = math.Clamp(mouseY - self.DragOffset[2], 0, ScrH() - self:GetTall())
			self:SetPos(dx, dy)
		elseif (self:SizingInBounds()) then
			self:SetCursor("sizenwse")
		elseif (self:DraggingInBounds()) then
			self.tabs.buttons:SetCursor("sizeall")
		else
			self:SetCursor("arrow")
		end
	end

	-- Aurebesh header animation
	if (RealTime() > (self.aurebeshNextTime or 0)) then
		if (self.aurebeshState == "type") then
			self.aurebeshIndex = (self.aurebeshIndex or 0) + 1
			self.aurebeshText = string.sub(self.aurebeshPhrase, 1, self.aurebeshIndex)
			self.aurebeshNextTime = RealTime() + 0.04

			if (self.aurebeshIndex >= #self.aurebeshPhrase) then
				self.aurebeshState = "pause"
				self.aurebeshNextTime = RealTime() + 2.5
			end
		elseif (self.aurebeshState == "pause") then
			self.aurebeshState = "delete"
			self.aurebeshNextTime = RealTime() + 0.04
		elseif (self.aurebeshState == "delete") then
			self.aurebeshIndex = (self.aurebeshIndex or 0) - 1
			self.aurebeshText = string.sub(self.aurebeshPhrase, 1, math.max(0, self.aurebeshIndex))
			self.aurebeshNextTime = RealTime() + 0.025

			if (self.aurebeshIndex <= 0) then
				self.aurebeshState = "type"
				self.aurebeshPhrase = AUREBESH_PHRASES[math.random(#AUREBESH_PHRASES)]
				self.aurebeshNextTime = RealTime() + 0.6
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Paint (Imperial terminal aesthetic)
-- ---------------------------------------------------------------------------
function PANEL:Paint(width, height)
	local alpha = self.alpha

	-- Background
	surface.SetDrawColor(THEME.background.r, THEME.background.g, THEME.background.b, math.min(THEME.background.a, alpha))
	surface.DrawRect(0, 0, width, height)

	-- Frame outline
	surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, math.min(THEME.frameSoft.a, alpha))
	surface.DrawOutlinedRect(0, 0, width, height)

	-- Scan line effect (subtle moving horizontal line when active)
	if (alpha > 50) then
		local scanY = self.headerHeight + ((CurTime() * 30) % math.max(1, height - self.headerHeight))
		surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, math.Round(math.min(6, alpha * 0.025)))
		surface.DrawRect(1, scanY, width - 2, 1)
	end

	-- Paint active tab messages at full alpha (always visible even when chatbox is faded)
	local tab = self.tabs:GetActiveTab()

	if (tab) then
		surface.SetAlphaMultiplier(1)
		tab:PaintManual()
		surface.SetAlphaMultiplier(alpha / 255)
	end

	-- Post-draw hook
	if (alpha > 0) then
		hook.Run("PostChatboxDraw", width, height, alpha)
	end
end

-- ---------------------------------------------------------------------------
-- Text handling (command detection, autocomplete, prefix updates)
-- ---------------------------------------------------------------------------
function PANEL:GetTextEntryChatClass(text)
	text = text or self.entry:GetText()
	local chatType = ix.chat.Parse(LocalPlayer(), text, true)

	if (chatType and chatType ~= "ic") then
		if (chatType == "ooc") then return "ooc" end

		local class = ix.chat.classes[chatType]

		if (class) then
			if (istable(class.prefix)) then
				for _, v in ipairs(class.prefix) do
					if (v:utf8sub(1, 1) == "/") then
						return v:utf8sub(2):utf8lower()
					end
				end
			elseif (isstring(class.prefix) and class.prefix:utf8sub(1, 1) == "/") then
				return class.prefix:utf8sub(2):utf8lower()
			end
		end
	end
end

function PANEL:OnTextChanged(text)
	hook.Run("ChatTextChanged", text)

	local preview = self.preview
	local autocomplete = self.autocomplete
	local chatClassCommand = self:GetTextEntryChatClass(text)
	self.prefix:SetText(hook.Run("GetChatPrefixInfo", text))

	if (chatClassCommand) then
		preview:SetCommand(chatClassCommand)
		preview:SetVisible(true)
		preview:UpdateArguments(text)
		autocomplete:SetVisible(false)
		return
	end

	local start, _, command = text:find("(/(%w+)%s)")
	command = ix.command.list[tostring(command):utf8sub(2, tostring(command):utf8len() - 1):utf8lower()]

	if (start == 1 and command) then
		preview:SetCommand(command.uniqueID)
		preview:SetVisible(true)
		preview:UpdateArguments(text)
		autocomplete:SetVisible(false)
		return
	elseif (text:utf8sub(1, 1) == "/") then
		command = text:match("(/(%w+))") or "/"
		preview:SetVisible(false)
		autocomplete:Update(command:utf8sub(2))
		autocomplete:SetVisible(true)
		return
	end

	if (preview:GetCommand() ~= "") then
		preview:SetCommand("")
		preview:SetVisible(false)
	end

	if (autocomplete:IsVisible()) then
		autocomplete:SetVisible(false)
	end
end

-- ---------------------------------------------------------------------------
-- Key handling (TAB for autocomplete)
-- ---------------------------------------------------------------------------
DEFINE_BASECLASS("DTextEntry")
function PANEL:OnKeyCodeTyped(key)
	if (key == KEY_TAB) then
		if (self.autocomplete:IsOpen() and #self.autocomplete:GetCommands() > 0) then
			local newText = self.autocomplete:SelectNext()
			self.entry:SetText(newText)
			self.entry:SetCaretPos(newText:utf8len())
		end

		return true
	end

	return BaseClass.OnKeyCodeTyped(self.entry, key)
end

-- ---------------------------------------------------------------------------
-- Message sending
-- ---------------------------------------------------------------------------
function PANEL:OnMessageSent()
	local text = self.entry:GetText()

	if (text:find("%S")) then
		local lastEntry = ix.chat.history[#ix.chat.history]

		if (lastEntry ~= text) then
			if (#ix.chat.history >= 20) then
				table.remove(ix.chat.history, 1)
			end

			ix.chat.history[#ix.chat.history + 1] = text
		end

		net.Start("ixChatMessage")
			net.WriteString(text)
		net.SendToServer()
	end

	self:SetActive(false)
end

-- ---------------------------------------------------------------------------
-- Tab event handlers
-- ---------------------------------------------------------------------------
function PANEL:OnTabChanged(panel)
	panel:InvalidateLayout(true)
	panel:ScrollToBottom()
end

function PANEL:OnTabCreated(id, filter)
	self.tabs:AddTab(id, filter)
	PLUGIN:SaveTabs()
end

function PANEL:OnTabUpdated(id, filter, newID)
	local tab = self.tabs:GetTabs()[id]
	if (not tab) then return end

	tab:SetFilter(filter)
	self.tabs:RenameTab(id, newID)
	PLUGIN:SaveTabs()
end

function PANEL:OnTabRightClick(button, tab, id)
	local menu = DermaMenu()

	menu:AddOption(L("chatCustomize"), function()
		if (IsValid(ix.gui.chatTabCustomize)) then
			ix.gui.chatTabCustomize:Remove()
		end

		local panel = vgui.Create("ixChatboxTabCustomize")
		panel:PopulateFromTab(id, tab:GetFilter())
		panel.OnTabUpdated = ix.util.Bind(self, self.OnTabUpdated)
	end)

	menu:AddSpacer()

	menu:AddOption(L("chatCloseTab"), function()
		self.tabs:RemoveTab(id)
		PLUGIN:SaveTabs()
	end)

	menu:Open()
	menu:MakePopup()
end

-- ---------------------------------------------------------------------------
-- AddMessage — routes to all applicable tabs (core API)
-- ---------------------------------------------------------------------------
function PANEL:AddMessage(...)
	local class = CHAT_CLASS and CHAT_CLASS.uniqueID or "notice"
	local activeTab = self.tabs:GetActiveTab()
	local bShown = false

	if (activeTab and activeTab:ShouldShowClass(class)) then
		activeTab:AddLine({...}, true)
		bShown = true
	end

	for _, v in pairs(self.tabs:GetTabs()) do
		if (v:GetID() == activeTab:GetID()) then continue end

		if (v:ShouldShowClass(class)) then
			v:AddLine({...}, true)

			if (not bShown) then
				v:GetButton():SetUnread(true)
			end
		end
	end

	if (bShown) then
		chat.PlaySound()
	end
end

vgui.Register("ixChatbox", PANEL, "EditablePanel")
