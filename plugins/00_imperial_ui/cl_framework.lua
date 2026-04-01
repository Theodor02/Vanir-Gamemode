--- Imperial UI Framework
-- Centralised theme, scaling, sounds, fonts, drawing helpers, panel styling
-- functions, component factories, and shared VGUI elements used by all
-- skeleton plugins.
--
-- Access everything via the ix.ui namespace.
-- This file MUST load before any plugin that references ix.ui.*.
-- @module ix.ui

ix.ui = ix.ui or {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- THEME
-- ═══════════════════════════════════════════════════════════════════════════════

ix.ui.THEME = {
	-- Backgrounds
	background    = Color(10, 10, 10, 240),
	backgroundSolid = Color(10, 10, 10, 255),
	panelBg       = Color(0, 0, 0, 200),

	-- Frames / borders
	frame         = Color(191, 148, 53, 220),
	frameSoft     = Color(191, 148, 53, 120),

	-- Text
	text          = Color(235, 235, 235, 245),
	textMuted     = Color(168, 168, 168, 140),

	-- Accent (Imperial gold)
	accent        = Color(191, 148, 53, 255),
	accentSoft    = Color(191, 148, 53, 200),
	accentDark    = Color(120, 93, 33, 180),

	-- Semantic
	danger        = Color(180, 60, 60, 255),
	dangerHover   = Color(200, 80, 80, 255),
	ready         = Color(60, 170, 90, 255),
	readyHover    = Color(80, 200, 110, 255),
	warning       = Color(200, 200, 50, 255),
	info          = Color(75, 150, 150, 255),
	ooc           = Color(100, 160, 220, 255),

	-- Buttons
	buttonBg      = Color(16, 16, 16, 220),
	buttonBgHover = Color(26, 26, 26, 230),

	-- Inputs
	inputBg       = Color(6, 6, 6, 220),
	inputBorder   = Color(191, 148, 53, 80),

	-- Rows (alternating)
	rowEven       = Color(14, 14, 14, 255),
	rowOdd        = Color(18, 18, 18, 255),
	rowHover      = Color(24, 22, 14, 255),

	-- Status
	equipped      = Color(60, 170, 90, 255),
	unequipped    = Color(120, 120, 120, 180),
}

--- Retrieve a theme color by key name.
-- @param name string  Key in ix.ui.THEME
-- @return Color
function ix.ui.GetColor(name)
	return ix.ui.THEME[name] or color_white
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SCALING
-- ═══════════════════════════════════════════════════════════════════════════════

--- Scale a pixel value relative to a 900px-tall reference resolution.
-- @param value number  The reference pixel value at 900px height
-- @return number  Scaled integer (minimum 1)
function ix.ui.Scale(value)
	return math.max(1, math.Round(value * (ScrH() / 900)))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SOUNDS
-- ═══════════════════════════════════════════════════════════════════════════════

ix.ui.SOUND_HOVER = "everfall/miscellaneous/ux/navigation/navigation_tab_01.mp3"
ix.ui.SOUND_CLICK = "everfall/miscellaneous/ux/navigation/navigation_activate_01.mp3"
ix.ui.SOUND_ERROR = "everfall/miscellaneous/ux/navigation/navigation_error_01.mp3"
ix.ui.SOUND_ENTER = "everfall/miscellaneous/ux/navigation/navigation_matchmaking_01.mp3"

--- Play a named UI sound.
-- @param name string  One of "hover", "click", "error", "enter"
function ix.ui.PlaySound(name)
	local key = "SOUND_" .. string.upper(name)
	local path = ix.ui[key]
	if (path) then
		surface.PlaySound(path)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════════

--- Check whether the Helix tab menu is in the process of closing.
-- @return boolean
function ix.ui.IsMenuClosing()
	return IsValid(ix.gui.menu) and ix.gui.menu.bClosing
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- FONTS
-- ═══════════════════════════════════════════════════════════════════════════════

local function CreateCoreFonts()
	local Scale = ix.ui.Scale
	local THEME = ix.ui.THEME

	-- Headings / titles
	surface.CreateFont("ixImpMenuTitle", {
		font = "Orbitron Bold",
		size = Scale(54),
		weight = 500,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixImpMenuSubtitle", {
		font = "Orbitron Medium",
		size = Scale(14),
		weight = 400,
		extended = true,
		antialias = true
	})

	-- General labels
	surface.CreateFont("ixImpMenuLabel", {
		font = "Orbitron Medium",
		size = Scale(12),
		weight = 500,
		extended = true,
		antialias = true
	})

	-- Buttons
	surface.CreateFont("ixImpMenuButton", {
		font = "Orbitron Medium",
		size = Scale(16),
		weight = 600,
		extended = true,
		antialias = true
	})

	-- Status pills / tiny labels
	surface.CreateFont("ixImpMenuStatus", {
		font = "Orbitron Medium",
		size = Scale(11),
		weight = 600,
		extended = true,
		antialias = true
	})

	-- Aurebesh decorative
	surface.CreateFont("ixImpMenuAurebesh", {
		font = "Aurebesh",
		size = Scale(12),
		weight = 400,
		extended = true,
		antialias = true
	})

	-- Diagnostic / monospace-ish
	surface.CreateFont("ixImpMenuDiag", {
		font = "Orbitron Light",
		size = Scale(11),
		weight = 500,
		extended = true,
		antialias = true
	})
end

CreateCoreFonts()

hook.Add("OnScreenSizeChanged", "ixImperialUICoreFonts", function()
	CreateCoreFonts()
end)

--- Create a one-off font with the Imperial scaling system.
-- Wraps surface.CreateFont with automatic Scale() applied to size.
-- @param name string  Font name
-- @param data table   Font data table (size will be scaled)
function ix.ui.CreateFont(name, data)
	data.size = ix.ui.Scale(data.size or 12)
	data.extended = data.extended ~= false
	data.antialias = data.antialias ~= false
	surface.CreateFont(name, data)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DRAWING HELPERS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Measure text rendered with per-character spacing.
-- @param text string
-- @param font string
-- @param spacing number  Extra pixels between characters
-- @return number totalWidth, number textHeight
function ix.ui.GetSpacedTextSize(text, font, spacing)
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

--- Draw text with per-character spacing.
-- @param text string
-- @param font string
-- @param x number
-- @param y number
-- @param color Color
-- @param spacing number  Extra pixels between characters (default 0)
-- @param align number    TEXT_ALIGN_LEFT / CENTER / RIGHT (default CENTER)
-- @return number totalWidth, number textHeight
function ix.ui.DrawSpacedText(text, font, x, y, color, spacing, align)
	align = align or TEXT_ALIGN_CENTER
	spacing = spacing or 0

	local totalWidth, textHeight = ix.ui.GetSpacedTextSize(text, font, spacing)
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

--- Draw the animated bioscan / screening panel effect.
-- Used by character creation, character loading, and information panels.
-- @param panel Panel     The panel being painted (reads __ixImpFooterHeight)
-- @param width number
-- @param height number
-- @param headerText string  Text for the header bar
function ix.ui.DrawScreeningPanel(panel, width, height, headerText)
	local THEME = ix.ui.THEME
	local Scale = ix.ui.Scale
	local now = CurTime()
	local footerHeight = panel.__ixImpFooterHeight or 0
	local drawH = height - footerHeight

	-- Design System: No full-frame bounding box.
	-- Background remains dark/desaturated but not a harsh black box.
	surface.SetDrawColor(Color(0, 0, 0, 80))
	surface.DrawRect(0, 0, width, drawH)

	-- Design System: Selective, high-contrast title bar
	local titleSpacing = Scale(2)
	local headerFont = "ixImpMenuSubtitle"
	
	if (headerText) then
		local textW, textH = ix.ui.GetSpacedTextSize(headerText, headerFont, titleSpacing)
		local barPadX = Scale(12)
		local barPadY = Scale(4)
		local barW = textW + (barPadX * 2)
		local barH = textH + (barPadY * 2)
		
		local barX = 0
		local barY = 0
		
		surface.SetDrawColor(THEME.accent)
		surface.DrawRect(barX, barY, barW, barH)
		
		ix.ui.DrawSpacedText(headerText, headerFont, barX + barPadX, barY + barPadY, THEME.background, titleSpacing, TEXT_ALIGN_LEFT)
		
		-- Small Aurebesh suffix outside the bar
		draw.SimpleText("BIOSCAN", "ixImpMenuAurebesh", barX + barW + Scale(6), barY + barH * 0.5 - 1, Color(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local innerPad = Scale(10)
	local innerX = innerPad
	local innerY = Scale(30) + innerPad
	local innerW = width - innerPad * 2
	local innerH = drawH - innerY - Scale(46)

	-- Moving scan line
	local scanY = innerY + (now * 40 % innerH)
	surface.SetDrawColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 35))
	if (scanY < innerY + innerH) then
		surface.DrawRect(innerX, scanY, innerW, Scale(2))
	end

	-- Horizontal grid lines (subtle)
	surface.SetDrawColor(Color(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b, 10))
	for i = 0, 6 do
		local y = innerY + (i / 6) * innerH
		surface.DrawLine(innerX, y, innerX + innerW, y)
	end

	-- Typewriter diagnostic text
	local lines = {
		"MED-CORE: STABLE", "CARDIAC: 98%", "RESP: NORMAL", "NEURAL: CLEAR",
		"VISUAL: 20/20", "MUSCLE: PRIME", "SYNC: ACTIVE"
	}

	local cycle = 8.0
	local typeSpeed = 0.05
	local timeInCycle = now % cycle
	local cycleAlpha = 255

	if (timeInCycle > cycle - 2.0) then
		cycleAlpha = math.Clamp(255 * (1 - ((timeInCycle - (cycle - 2.0)) / 1.0)), 0, 255)
	end

	local charsToShow = math.floor(timeInCycle / typeSpeed)
	local charsConsumed = 0
	local lineY = innerY + Scale(2)

	for i = 1, #lines do
		if (lineY < drawH - Scale(20)) then
			local lineLen = #lines[i]
			local charsForThisLine = charsToShow - charsConsumed

			if (charsForThisLine > 0 and cycleAlpha > 0) then
				local textToDraw = lines[i]
				if (charsForThisLine < lineLen) then
					textToDraw = string.sub(lines[i], 1, charsForThisLine)
				end
				draw.SimpleText(textToDraw, "ixImpMenuAurebesh", innerX, lineY,
					Color(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b, cycleAlpha * 0.5),
					TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			end

			charsConsumed = charsConsumed + lineLen
			lineY = lineY + Scale(13)
		end
	end

	-- Animated progress bars at the bottom
	local barY = drawH - Scale(24)
	for i = 1, 3 do
		local phase = now * (0.7 + i * 0.4)
		local fill = 0.35 + (math.sin(phase) + 1) * 0.3
		local barH = Scale(2)

		if (barY + barH > drawH) then break end

		surface.SetDrawColor(Color(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b, 20))
		surface.DrawRect(innerX, barY, innerW, barH)
		surface.SetDrawColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 120))
		surface.DrawRect(innerX, barY, innerW * fill, barH)
		barY = barY - Scale(8)
	end
end

--- Draw a simple data panel background with a header bar.
-- @param width number
-- @param height number
-- @param headerText string|nil  Optional header text
function ix.ui.DrawDataPanel(width, height, headerText)
	local THEME = ix.ui.THEME
	local Scale = ix.ui.Scale

	-- Design System: No full-frame bounding box. Background remains dark/desaturated.
	-- We'll allow the parent's background to show through, or draw a very subtle tint.

	-- Design System: Selective, high-contrast title bar
	if (headerText) then
		local titleSpacing = Scale(2)
		local headerFont = "ixImpMenuSubtitle"
		local textW, textH = ix.ui.GetSpacedTextSize(headerText, headerFont, titleSpacing)
		
		local barPadX = Scale(12)
		local barPadY = Scale(4)
		local barW = textW + (barPadX * 2)
		local barH = textH + (barPadY * 2)
		
		local barX = 0
		local barY = 0
		
		surface.SetDrawColor(THEME.accent)
		surface.DrawRect(barX, barY, barW, barH)
		
		ix.ui.DrawSpacedText(headerText, headerFont, barX + barPadX, barY + barPadY, THEME.background, titleSpacing, TEXT_ALIGN_LEFT)
		
		-- Small Aurebesh suffix outside the bar
		draw.SimpleText("DATA", "ixImpMenuAurebesh", barX + barW + Scale(6), barY + barH * 0.5 - 1, Color(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- PANEL STYLING FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Apply the animated bioscan Paint to a panel.
-- @param panel Panel
-- @param headerText string
function ix.ui.ApplyScreeningPanel(panel, headerText)
	if (!IsValid(panel)) then return end

	panel.__ixImpHasScreening = true
	panel:DockPadding(0, ix.ui.Scale(28), 0, 0)
	panel.Paint = function(this, width, height)
		ix.ui.DrawScreeningPanel(this, width, height, headerText)
	end
end

--- Apply a data panel Paint (dark bg + gold header bar + outline).
-- @param panel Panel
-- @param headerText string|nil
function ix.ui.ApplyDataPanel(panel, headerText)
	if (!IsValid(panel)) then return end

	panel.__ixImpHasDataPanel = true
	panel.Paint = function(this, width, height)
		ix.ui.DrawDataPanel(width, height, headerText)
	end
end

--- Style a DLabel with the standard muted label look.
-- @param label Panel  A DLabel
function ix.ui.ApplyLabelStyle(label)
	if (!IsValid(label)) then return end

	label:SetFont("ixImpMenuLabel")
	label:SetTextColor(ix.ui.THEME.textMuted)
	label:SizeToContents()
end

--- Style a DLabel used for character variable headings (NAME, DESCRIPTION, etc.).
-- @param panel Panel  A DLabel
function ix.ui.ApplyCharVarLabelStyle(panel)
	if (!IsValid(panel)) then return end

	panel:SetFont("ixImpMenuLabel")
	panel:SetTextColor(ix.ui.THEME.accent)
	panel:SetContentAlignment(4)
end

--- Style a DTextEntry with the Imperial look.
-- @param entry Panel  A DTextEntry
function ix.ui.ApplyTextEntryStyle(entry)
	if (!IsValid(entry)) then return end

	local THEME = ix.ui.THEME

	entry:SetPaintBackground(false)
	entry:SetFont("ixImpMenuButton")
	entry:SetTextColor(THEME.text)
	entry:SetHighlightColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 120))
	entry:SetCursorColor(THEME.accent)

	if (entry.SetBackgroundColor) then
		entry:SetBackgroundColor(Color(0, 0, 0, 0))
	end
	if (entry.SetPaintBackground) then
		entry:SetPaintBackground(false)
	end
	if (entry.SetDrawBackground) then
		entry:SetDrawBackground(false)
	end

	local originalOnFocus = entry.OnFocus
	entry.OnFocus = function(this)
		if (originalOnFocus) then originalOnFocus(this) end
		if (this.SetPaintBackground) then this:SetPaintBackground(false) end
		if (this.SetDrawBackground) then this:SetDrawBackground(false) end
	end

	entry.Paint = function(this, width, height)
		-- VANIR spec: --bg-secondary background with 1px --sep border
		if (this:HasFocus()) then
			-- Focus state: gold bottom border, subtle gold bg tint
			surface.SetDrawColor(Color(201, 168, 76, 13)) -- rgba(201,168,76,0.05)
			surface.DrawRect(0, 0, width, height)
			surface.SetDrawColor(Color(255, 255, 255, 15)) -- --sep border
			surface.DrawOutlinedRect(0, 0, width, height)
			surface.SetDrawColor(Color(201, 168, 76, 255)) -- --gold bottom border
			surface.DrawRect(0, height - 1, width, 1)
		else
			-- Idle state: --bg-secondary with --sep border
			surface.SetDrawColor(Color(17, 19, 22, 255)) -- --bg-secondary
			surface.DrawRect(0, 0, width, height)
			surface.SetDrawColor(Color(255, 255, 255, 15)) -- --sep border
			surface.DrawOutlinedRect(0, 0, width, height)
		end

		this:DrawTextEntryText(this:GetTextColor(), this:GetHighlightColor(), this:GetCursorColor())
	end
end

--- Style a model panel (DScrollPanel wrapping a model selector).
-- Hides scrollbar and removes background painting.
-- @param panel Panel
function ix.ui.ApplyModelPanelStyle(panel)
	if (!IsValid(panel)) then return end

	if (panel:GetClassName() == "DScrollPanel") then
		if (panel.SetPaintBackground) then panel:SetPaintBackground(false) end

		if (panel.GetCanvas and IsValid(panel:GetCanvas())) then
			panel:GetCanvas().Paint = nil
			if (panel:GetCanvas().SetPaintBackground) then
				panel:GetCanvas():SetPaintBackground(false)
			end
		end

		local vbar = panel:GetVBar()
		if (IsValid(vbar)) then
			vbar:SetWide(0)
		end
	end
end

--- Style a DScrollPanel used to hold model selections.
-- Hides the scrollbar and applies the standard outlined look.
-- @param scroll Panel  A DScrollPanel
function ix.ui.ApplyModelScrollStyle(scroll)
	if (!IsValid(scroll)) then return end

	local THEME = ix.ui.THEME
	local Scale = ix.ui.Scale

	if (scroll.GetVBar) then
		scroll:GetVBar():SetWide(0)
		scroll:GetVBar():SetVisible(false)
	end

	scroll.Paint = function(_, width, height)
		surface.SetDrawColor(Color(0, 0, 0, 255))
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawOutlinedRect(0, 0, width, height)
	end

	if (scroll:GetDock() == FILL) then
		scroll:DockMargin(Scale(8), Scale(8), Scale(8), Scale(8))
	end
end

--- Style a category/collapsible panel with outlined frame and title.
-- @param panel Panel
function ix.ui.ApplyCategoryPanelStyle(panel)
	if (!IsValid(panel)) then return end

	local THEME = ix.ui.THEME
	local Scale = ix.ui.Scale

	panel.Paint = function(this, width, height)
		-- VANIR-style: dark bg with thin separators, no heavy borders
		surface.SetDrawColor(Color(17, 19, 22, 255)) -- --bg-secondary
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(Color(255, 255, 255, 15)) -- --sep
		surface.DrawOutlinedRect(0, 0, width, height)

		local title = this.GetText and this:GetText() or ""
		if (title ~= "") then
			-- Gold title-bar strip for category headers
			local titleText = title:utf8upper()
			surface.SetFont("ixImpMenuDiag")
			local tw, th = surface.GetTextSize(titleText)
			local barH = th + Scale(8)
			surface.SetDrawColor(Color(201, 168, 76, 255)) -- --gold
			surface.DrawRect(0, 0, width, barH)
			draw.SimpleText(titleText, "ixImpMenuDiag", Scale(10), barH * 0.5, Color(13, 14, 16, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end
end

--- Style an ixAttributeBar with the Imperial look.
-- VANIR spec layout: ATTR NAME (left) ████████░░░░░░ (bar center) 87 (right value)
-- Row height: 22px, 2px separator between rows
-- @param panel Panel  An ixAttributeBar
function ix.ui.ApplyAttributeBarStyle(panel)
	if (!IsValid(panel)) then return end

	local THEME = ix.ui.THEME
	local Scale = ix.ui.Scale

	panel:SetTall(Scale(22))

	-- Store attribute name for custom paint
	local attrName = ""
	if (IsValid(panel.label)) then
		attrName = panel.label:GetText() or ""
		-- Hide the default label — we'll draw it ourselves in panel Paint
		panel.label:SetVisible(false)
	end

	-- Override the main panel Paint to draw the full VANIR layout
	panel.Paint = function(this, w, h)
		local labelW = Scale(80)
		local valueW = Scale(40)
		local barX = labelW
		local barW = w - labelW - valueW

		-- Left-aligned attribute name (8px --text-muted, 80px wide column)
		draw.SimpleText(string.upper(attrName), "ixImpMenuDiag", 0, h * 0.5, THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		-- Center bar
		local barH = 4
		local barY = math.floor((h - barH) / 2)

		-- Unfilled track (--sep)
		surface.SetDrawColor(Color(255, 255, 255, 15))
		surface.DrawRect(barX, barY, barW, barH)

		-- Filled portion (--gold #C9A84C)
		local max = math.max(this.max or 1, 1)
		local value = (this.deltaValue or 0) / max
		local fillW = math.max(0, barW * value)

		if (fillW > 0) then
			surface.SetDrawColor(Color(201, 168, 76, 255))
			surface.DrawRect(barX, barY, fillW, barH)
		end

		-- Right-aligned numeric value (9px --text-primary)
		local numValue = math.floor((this.deltaValue or 0))
		draw.SimpleText(tostring(numValue), "ixImpMenuButton", w, h * 0.5, THEME.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		-- 2px separator at bottom
		surface.SetDrawColor(Color(255, 255, 255, 15))
		surface.DrawLine(0, h - 1, w, h - 1)
	end

	if (IsValid(panel.bar)) then
		-- Hide the default bar rendering — we draw it ourselves in panel Paint
		panel.bar.Paint = function() end
	end

	if (panel.GetColor and panel:GetColor() ~= THEME.accent) then
		panel:SetColor(THEME.accent)
	end
end

--- Style a Helix progress bar with the Imperial segmented look.
-- @param progress Panel
function ix.ui.ApplyProgressStyle(progress)
	if (!IsValid(progress)) then return end

	local THEME = ix.ui.THEME
	local Scale = ix.ui.Scale

	progress:SetTall(Scale(26))
	progress:SetTextColor(THEME.textMuted)
	progress:SetBarColor(THEME.accent)
	progress:SetFont("ixImpMenuDiag")

	progress.Paint = function(this, width, height)
		surface.SetDrawColor(Color(0, 0, 0, 255))
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawOutlinedRect(0, 0, width, height)

		local segments = this:GetSegments()
		local count = #segments
		if (count == 0) then return end

		local segWidth = width / count
		local fraction = this:GetFraction() or 0

		for i = 1, count do
			local x = (i - 1) * segWidth
			local active = fraction >= (i - 1) / count + 0.001
			local labelColor = active and THEME.accent or THEME.textMuted
			surface.SetDrawColor(Color(255, 255, 255, 12))
			surface.DrawLine(x, 0, x, height)
			draw.SimpleText(segments[i], "ixImpMenuDiag", x + segWidth * 0.5, height * 0.5, labelColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		surface.SetDrawColor(THEME.accent)
		surface.DrawRect(0, height - Scale(2), width * fraction, Scale(2))
	end
end

--- Apply Imperial hover and click sounds to any DButton-derived panel.
-- @param button Panel  A DButton
function ix.ui.ApplyButtonSounds(button)
	if (!IsValid(button)) then return end

	-- ixImpButton already handles sounds natively; skip to avoid overriding its methods
	if (button:GetClassName() == "ixImpButton") then return end

	function button:OnCursorEntered()
		if (self:GetDisabled()) then return end

		local color = self.GetTextColor and self:GetTextColor()
		if (color and self.SetTextColorInternal) then
			self:SetTextColorInternal(Color(math.max(color.r - 25, 0), math.max(color.g - 25, 0), math.max(color.b - 25, 0)))
		end
		self:CreateAnimation(0.15, {target = {currentBackgroundAlpha = self.backgroundAlpha}})
		surface.PlaySound(ix.ui.SOUND_HOVER)
	end

	function button:OnMousePressed(code)
		if (self:GetDisabled()) then
			surface.PlaySound(ix.ui.SOUND_ERROR)
			return
		end

		if (self.color) then
			self:SetTextColor(self.color)
		else
			self:SetTextColor(ix.config.Get("color"))
		end

		surface.PlaySound(ix.ui.SOUND_CLICK)

		if (code == MOUSE_LEFT and self.DoClick) then
			self:DoClick(self)
		elseif (code == MOUSE_RIGHT and self.DoRightClick) then
			self:DoRightClick(self)
		end
	end
end

--- Apply the full Imperial button style to any DButton.
-- Adds custom Paint, hover sounds, pulse glow, and style variants.
-- @param button Panel   A DButton
-- @param style  string  "default", "accent", or "danger"
function ix.ui.ApplyImpButtonStyle(button, style)
	if (!IsValid(button)) then return end

	local THEME = ix.ui.THEME

	button.__ixImpStyle = style or "default"
	button.__ixImpPulseOffset = button.__ixImpPulseOffset or math.Rand(0, 4)
	button.__ixImpNextHoverSound = 0
	button:SetFont("ixImpMenuButton")
	button:SetTextColor(THEME.text)
	button:SetPaintBackground(false)
	button:SetContentAlignment(5)
	button:SetTextInset(0, 0)
	button.PaintOver = function() end

	function button:GetImpColors()
		if (self.__ixImpStyle == "accent") then
			return THEME.accent, THEME.accent, Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 15), THEME.accent
		elseif (self.__ixImpStyle == "danger") then
			return THEME.danger, THEME.danger, Color(THEME.danger.r, THEME.danger.g, THEME.danger.b, 15), THEME.danger
		end
		return THEME.textMuted, THEME.accentSoft, Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 15), THEME.accent
	end

	function button:Paint(width, height)
		local disabled = self:GetDisabled()
		local selected = self.GetSelected and self:GetSelected() or false
		local hovered = self:IsHovered() or self:IsDown() or selected
		local labelColor, borderColor, hoverBg, hoverLabel = self:GetImpColors()
		
		if (selected and self.__ixImpStyle == "default") then
			labelColor = THEME.accent
			borderColor = THEME.accent
		end

		if (disabled) then
			labelColor = Color(100, 100, 100, 100)
		elseif (hovered) then
			labelColor = hoverLabel
			
			-- Very subtle background highlight
			surface.SetDrawColor(hoverBg)
			surface.DrawRect(0, 0, width, height)
			
			-- Clean side brackets for hover instead of full box (mimicking main menu)
			surface.SetDrawColor(borderColor)
			surface.DrawRect(0, 0, ix.ui.Scale(2), height)
			surface.DrawRect(width - ix.ui.Scale(2), 0, ix.ui.Scale(2), height)
		else
			-- Idle state minimal bottom line
			surface.SetDrawColor(Color(borderColor.r, borderColor.g, borderColor.b, 30))
			surface.DrawLine(0, height - 1, width, height - 1)
		end

		draw.SimpleText(self:GetText(), "ixImpMenuButton", width * 0.5, height * 0.5, labelColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			
		return true -- Prevent default paint if overriding
	end

	function button:OnCursorEntered()
		if (self:GetDisabled()) then return end
		if (self.__ixImpNextHoverSound <= CurTime()) then
			self.__ixImpNextHoverSound = CurTime() + 0.08
			surface.PlaySound(ix.ui.SOUND_HOVER)
		end
	end
end

--- Apply the Imperial styled scrollbar to a DScrollPanel.
-- Thin gold grip, invisible track/buttons.
-- @param scroll Panel  A DScrollPanel
-- @param gripColor Color|nil  Override grip color (default: THEME.accentSoft)
function ix.ui.ApplyScrollbarStyle(scroll, gripColor)
	if (!IsValid(scroll)) then return end

	local THEME = ix.ui.THEME
	local Scale = ix.ui.Scale
	local color = gripColor or THEME.accentSoft

	local sbar = scroll:GetVBar()
	if (!IsValid(sbar)) then return end

	sbar:SetWide(Scale(4))
	sbar.Paint = function() end
	sbar.btnUp.Paint = function() end
	sbar.btnDown.Paint = function() end
	sbar.btnGrip.Paint = function(_, w, h)
		surface.SetDrawColor(color)
		surface.DrawRect(0, 0, w, h)
	end
end

--- Style a SpawnIcon with the Imperial double-outline look.
-- @param icon Panel  A SpawnIcon
function ix.ui.ApplySpawnIconStyle(icon)
	if (!IsValid(icon)) then return end

	local THEME = ix.ui.THEME

	if (!icon.__ixImpOldPaintOver) then
		icon.__ixImpOldPaintOver = icon.PaintOver
	end

	icon.PaintOver = function(this, width, height)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawOutlinedRect(0, 0, width, height)
		surface.DrawOutlinedRect(1, 1, width - 2, height - 2)

		if (this.__ixImpOldPaintOver) then
			this.__ixImpOldPaintOver(this, width, height)
		end

		surface.SetDrawColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 200))
		surface.DrawOutlinedRect(2, 2, width - 4, height - 4)
	end
end

--- Style an icon layout (DIconLayout) with consistent spacing.
-- @param layout Panel  A DIconLayout
function ix.ui.ApplyIconLayoutStyle(layout)
	if (!IsValid(layout)) then return end

	local Scale = ix.ui.Scale
	layout:SetSpaceX(Scale(6))
	layout:SetSpaceY(Scale(6))
end

--- Size a model container panel to a ratio of its parent's width.
-- @param panel Panel
-- @param widthRatio number  Fraction of parent width (default 0.34)
function ix.ui.FitModelContainer(panel, widthRatio)
	if (!IsValid(panel)) then return end

	local Scale = ix.ui.Scale

	panel.__ixImpWidthRatio = widthRatio or 0.34
	panel.__ixImpMargin = Scale(8)

	panel.PerformLayout = function(this)
		local parent = this:GetParent()
		if (IsValid(parent)) then
			this:SetWide(math.Round(parent:GetWide() * (this.__ixImpWidthRatio or 0.34)))
		end
		this:DockMargin(this.__ixImpMargin, Scale(12), this.__ixImpMargin, Scale(12))
	end

	panel:InvalidateLayout(true)
end

--- Style an attribute +/- button with the Imperial look.
-- @param button Panel   A DImageButton or similar
-- @param symbol string  "+" or "-"
function ix.ui.ApplyAttributeButtonStyle(button, symbol)
	if (!IsValid(button)) then return end

	local THEME = ix.ui.THEME
	local Scale = ix.ui.Scale

	button.__ixImpSymbol = symbol
	button.__ixImpHover = false
	-- Clear the default icon without passing an empty string (which crashes on nil material)
	if (button.Image and IsValid(button.Image)) then button.Image:SetVisible(false) end
	button:SetSize(Scale(18), Scale(18))

	-- VANIR spec: minus/sub = muted red dot (min threshold), plus/add = gold dot (bonus)
	local isSub = (symbol == "-")
	local dotColor = isSub and Color(201, 64, 64, 178) or Color(201, 168, 76, 178)
	local dotColorHover = isSub and Color(201, 64, 64, 255) or Color(201, 168, 76, 255)

	-- VANIR spec: MIN label below sub button, BONUS label below add button
	local labelText = isSub and "MIN" or "BONUS"
	local labelColor = Color(255, 255, 255, 56) -- --text-muted equivalent

	button.Paint = function(this, w, h)
		local hovered = this.__ixImpHover
		surface.SetDrawColor(hovered and THEME.buttonBgHover or THEME.buttonBg)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(hovered and dotColorHover or dotColor)
		surface.DrawOutlinedRect(0, 0, w, h)
		draw.SimpleText(this.__ixImpSymbol, "ixImpMenuDiag", w * 0.5, h * 0.5, hovered and dotColorHover or THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		-- MIN/BONUS label below dot (6px --text-muted)
		draw.SimpleText(labelText, "ixImpMenuDiag", w * 0.5, h + Scale(2), labelColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end

	button.OnCursorEntered = function(this)
		this.__ixImpHover = true
		surface.PlaySound(ix.ui.SOUND_HOVER)
	end

	button.OnCursorExited = function(this)
		this.__ixImpHover = false
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- COMPONENT FACTORIES
-- ═══════════════════════════════════════════════════════════════════════════════

--- Create an alternating-row data display (label + value).
-- @param parent Panel
-- @param label  string  Left-side label text
-- @param value  string  Right-side value text
-- @param index  number  Row index (for alternating colors)
-- @return Panel  The row panel
function ix.ui.CreateDataRow(parent, label, value, index)
	local THEME = ix.ui.THEME
	local Scale = ix.ui.Scale

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

--- Create a section header (text + horizontal rule).
-- @param parent Panel
-- @param text   string  Section title
-- @return Panel  The header panel
function ix.ui.CreateSectionHeader(parent, text)
	local THEME = ix.ui.THEME
	local Scale = ix.ui.Scale

	local sep = parent:Add("EditablePanel")
	sep:Dock(TOP)
	sep:SetTall(Scale(20))
	sep:DockMargin(0, Scale(10), 0, Scale(4))
	sep.Paint = function(_, w, h)
		draw.SimpleText(text, "ixImpMenuDiag", 0, h * 0.5, THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		surface.SetFont("ixImpMenuDiag")
		local tw = surface.GetTextSize(text)
		surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 50)
		surface.DrawRect(tw + Scale(8), math.floor(h * 0.5), w - tw - Scale(8), 1)
	end

	return sep
end

--- Create a styled tooltip panel from a list of {label, value, color} lines.
-- @param lines table  Array of {label = string, value = string, color = Color}
-- @return Panel  The tooltip panel (caller must position it)
function ix.ui.CreateTooltip(lines)
	local THEME = ix.ui.THEME
	local Scale = ix.ui.Scale

	local tip = vgui.Create("DPanel")
	tip:SetDrawOnTop(true)
	tip.lines = lines

	local lineH = Scale(18)
	local padX = Scale(10)
	local padY = Scale(6)
	local tipW = Scale(220)
	local tipH = padY * 2 + #lines * lineH

	tip:SetSize(tipW, tipH)

	tip.Paint = function(s, w, h)
		surface.SetDrawColor(10, 10, 10, 240)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawOutlinedRect(0, 0, w, h, 1)

		local y = padY
		for _, line in ipairs(s.lines) do
			draw.SimpleText(line.label .. ":", "ixImpMenuDiag", padX, y, THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText(line.value, "ixImpMenuDiag", w - padX, y, line.color or THEME.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
			y = y + lineH
		end
	end

	return tip
end

--- Create a section header with a filled background bar (used in force tab, etc.).
-- @param parent Panel
-- @param title  string  Section title
-- @return Panel  The header panel
function ix.ui.CreateBarSectionHeader(parent, title)
	local THEME = ix.ui.THEME
	local Scale = ix.ui.Scale

	local header = parent:Add("Panel")
	header:Dock(TOP)
	header:SetTall(Scale(24))
	header:DockMargin(0, 0, 0, Scale(4))
	header.Paint = function(_, w, h)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText(string.upper(title), "ixImpMenuDiag", Scale(8), h * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	return header
end

--- Create a toggle row (checkbox-style button with status indicator).
-- @param parent   Panel
-- @param label    string   Display text
-- @param bActive  boolean  Initial state
-- @param onToggle function Callback(boolean newState)
-- @return Panel  The row panel
function ix.ui.CreateToggleRow(parent, label, bActive, onToggle)
	local THEME = ix.ui.THEME
	local Scale = ix.ui.Scale

	local row = parent:Add("DButton")
	row:Dock(TOP)
	row:SetTall(Scale(28))
	row:DockMargin(0, 0, 0, Scale(2))
	row:SetText("")
	row.active = bActive
	row.pulseOffset = math.Rand(0, 4)

	row.Paint = function(self, w, h)
		local hovered = self:IsHovered()
		local pulse = (math.sin(CurTime() * 2 + self.pulseOffset) + 1) * 0.5

		surface.SetDrawColor(hovered and THEME.buttonBgHover or THEME.buttonBg)
		surface.DrawRect(0, 0, w, h)

		local statusColor = self.active and THEME.equipped or THEME.unequipped
		surface.SetDrawColor(statusColor)
		surface.DrawRect(0, 0, Scale(4), h)

		local borderColor = self.active and THEME.accentSoft or Color(80, 80, 80, 120)
		local glow = hovered and 40 or math.Round(8 + pulse * 10)
		surface.SetDrawColor(Color(borderColor.r, borderColor.g, borderColor.b, math.min(255, borderColor.a + glow)))
		surface.DrawOutlinedRect(0, 0, w, h)

		draw.SimpleText(label, "ixImpMenuLabel", Scale(14), h * 0.5, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local statusText = self.active and "ACTIVE" or "INACTIVE"
		draw.SimpleText(statusText, "ixImpMenuDiag", w - Scale(8), h * 0.5, statusColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	row.DoClick = function(self)
		surface.PlaySound(ix.ui.SOUND_CLICK)
		self.active = !self.active
		if (onToggle) then onToggle(self.active) end
	end

	row.OnCursorEntered = function()
		surface.PlaySound(ix.ui.SOUND_HOVER)
	end

	return row
end

--- Create a slider row (label + DNumSlider) for settings panels.
-- @param parent   Panel
-- @param label    string
-- @param convar   string   ConVar name
-- @param min      number
-- @param max      number
-- @param decimals number|nil
-- @return Panel row, Panel slider
function ix.ui.CreateSliderRow(parent, label, convar, min, max, decimals)
	local THEME = ix.ui.THEME
	local Scale = ix.ui.Scale

	local row = parent:Add("Panel")
	row:Dock(TOP)
	row:SetTall(Scale(40))
	row:DockMargin(0, 0, 0, Scale(2))
	row.Paint = function(_, w, h)
		surface.SetDrawColor(THEME.buttonBg)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(Color(80, 80, 80, 80))
		surface.DrawOutlinedRect(0, 0, w, h)
		draw.SimpleText(label, "ixImpMenuLabel", Scale(8), Scale(4), THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	local slider = row:Add("DNumSlider")
	slider:Dock(FILL)
	slider:DockMargin(Scale(8), Scale(16), Scale(8), Scale(2))
	slider:SetText("")
	slider:SetMin(min)
	slider:SetMax(max)
	slider:SetDecimals(decimals or 0)
	slider:SetConVar(convar)
	slider.Label:SetVisible(false)
	slider.TextArea:SetFont("ixImpMenuDiag")
	slider.TextArea:SetTextColor(THEME.accent)

	return row, slider
end

--- Create a checkbox row for settings panels.
-- @param parent Panel
-- @param label  string
-- @param convar string  ConVar name
-- @return Panel row, Panel checkbox
function ix.ui.CreateCheckboxRow(parent, label, convar)
	local THEME = ix.ui.THEME
	local Scale = ix.ui.Scale

	local row = parent:Add("Panel")
	row:Dock(TOP)
	row:SetTall(Scale(28))
	row:DockMargin(0, 0, 0, Scale(2))
	row.Paint = function(_, w, h)
		surface.SetDrawColor(THEME.buttonBg)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(Color(80, 80, 80, 80))
		surface.DrawOutlinedRect(0, 0, w, h)
	end

	local cb = row:Add("DCheckBoxLabel")
	cb:Dock(FILL)
	cb:DockMargin(Scale(8), 0, Scale(8), 0)
	cb:SetText(label)
	cb:SetFont("ixImpMenuLabel")
	cb:SetTextColor(THEME.text)
	cb:SetConVar(convar)

	return row, cb
end

--- Create a keybind row (label + DBinder + reset button).
-- @param parent Panel
-- @param label  string
-- @param getKey function  Returns current key code
-- @param setKey function  Receives new key code
-- @return Panel row, Panel binder
function ix.ui.CreateKeybindRow(parent, label, getKey, setKey)
	local THEME = ix.ui.THEME
	local Scale = ix.ui.Scale

	local row = parent:Add("Panel")
	row:Dock(TOP)
	row:SetTall(Scale(30))
	row:DockMargin(0, 0, 0, Scale(2))
	row.Paint = function(_, w, h)
		surface.SetDrawColor(THEME.buttonBg)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(Color(80, 80, 80, 80))
		surface.DrawOutlinedRect(0, 0, w, h)
		draw.SimpleText(label, "ixImpMenuLabel", Scale(8), h * 0.5, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local reset = row:Add("DButton")
	reset:Dock(RIGHT)
	reset:SetWide(Scale(40))
	reset:DockMargin(Scale(2), Scale(2), Scale(4), Scale(2))
	reset:SetText("")
	reset.Paint = function(self, w, h)
		local hovered = self:IsHovered()
		surface.SetDrawColor(hovered and Color(35, 10, 10, 220) or THEME.buttonBg)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(THEME.danger)
		surface.DrawOutlinedRect(0, 0, w, h)
		draw.SimpleText("X", "ixImpMenuDiag", w * 0.5, h * 0.5, THEME.danger, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local binder = row:Add("DBinder")
	binder:Dock(RIGHT)
	binder:SetWide(Scale(120))
	binder:DockMargin(0, Scale(2), 0, Scale(2))
	binder:SetFont("ixImpMenuLabel")
	binder:SetValue(getKey())

	binder.OnChange = function(_, num)
		setKey(num)
	end

	reset.DoClick = function()
		surface.PlaySound(ix.ui.SOUND_CLICK)
		setKey(KEY_NONE)
		binder:SetValue(KEY_NONE)
	end

	return row, binder
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SHARED VGUI COMPONENTS
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── ixImpButton ──────────────────────────────────────────────────────────────
-- The standard Imperial button with pulse glow, style variants, and sounds.
-- Replaces: ixImpMenuButton, ixImpMenuButtonChar
-- Usage: local btn = vgui.Create("ixImpButton")
--        btn:SetLabel("DEPLOY")
--        btn:SetStyle("accent")  -- "default", "accent", "danger"

local BUTTON = {}

function BUTTON:Init()
	local THEME = ix.ui.THEME

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

function BUTTON:GetLabel()
	return self.label
end

function BUTTON:SetStyle(style)
	local THEME = ix.ui.THEME
	self.style = style or "default"

	if (self.style == "accent") then
		self.labelColor = THEME.accent
		self.borderColor = THEME.accent
		self.hoverBorderColor = THEME.accent
		self.hoverBackgroundColor = Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 20)
		self.hoverLabelColor = THEME.accent
	elseif (self.style == "danger") then
		self.labelColor = THEME.danger
		self.borderColor = THEME.danger
		self.hoverBorderColor = THEME.danger
		self.hoverBackgroundColor = Color(THEME.danger.r, THEME.danger.g, THEME.danger.b, 20)
		self.hoverLabelColor = THEME.danger
	else
		self.labelColor = THEME.textMuted
		self.borderColor = THEME.accentSoft
		self.hoverBorderColor = THEME.accentSoft
		self.hoverBackgroundColor = Color(THEME.accentSoft.r, THEME.accentSoft.g, THEME.accentSoft.b, 10)
		self.hoverLabelColor = THEME.text
	end
end

function BUTTON:Paint(width, height)
	local disabled = self:GetDisabled()
	local hovered = self:IsHovered() or self:IsDown()
	local border = hovered and self.hoverBorderColor or self.borderColor
	local bg = hovered and self.hoverBackgroundColor or Color(0, 0, 0, 0)
	local textColor = hovered and self.hoverLabelColor or self.labelColor
	local alphaMult = disabled and 0.4 or 1

	if (disabled) then
		border = Color(border.r, border.g, border.b, self.disabledAlpha)
		bg = Color(bg.r, bg.g, bg.b, self.disabledAlpha)
		textColor = Color(textColor.r, textColor.g, textColor.b, self.disabledAlpha)
	end

	-- Transparent or subtle hover background
	if (hovered and not disabled) then
		surface.SetDrawColor(bg)
		surface.DrawRect(0, 0, width, height)

		-- Minimalist Hover Brackets
		surface.SetDrawColor(Color(border.r, border.g, border.b, 150))
		local bracketW = ix.ui.Scale(8)
		local bracketH = ix.ui.Scale(8)
		
		-- Top Left
		surface.DrawLine(0, 0, bracketW, 0)
		surface.DrawLine(0, 0, 0, bracketH)
		-- Top Right
		surface.DrawLine(width - bracketW, 0, width, 0)
		surface.DrawLine(width - 1, 0, width - 1, bracketH)
		-- Bottom Left
		surface.DrawLine(0, height - 1, bracketW, height - 1)
		surface.DrawLine(0, height - bracketH, 0, height - 1)
		-- Bottom Right
		surface.DrawLine(width - bracketW, height - 1, width, height - 1)
		surface.DrawLine(width - 1, height - bracketH, width - 1, height - 1)
	else
		-- Faint background/bottom line for non-hovered to show interactability
		surface.SetDrawColor(Color(255, 255, 255, disabled and 2 or 5))
		surface.DrawRect(0, 0, width, height)
		
		surface.SetDrawColor(Color(border.r, border.g, border.b, disabled and 10 or 30))
		surface.DrawLine(0, height - 1, width, height - 1)
	end

	-- VANIR spec: list items must be left-aligned with padding
	local labelAlign = self.labelAlign or TEXT_ALIGN_LEFT
	local labelX = (labelAlign == TEXT_ALIGN_LEFT) and ix.ui.Scale(16) or width * 0.5
	local labelY = height * 0.5 + (self.labelYOffset or 0)
	draw.SimpleText(self.label, "ixImpMenuButton", labelX, labelY, Color(textColor.r, textColor.g, textColor.b, textColor.a * alphaMult), labelAlign, TEXT_ALIGN_CENTER)
end

function BUTTON:OnCursorEntered()
	if (self.nextHoverSound > CurTime()) then return end
	self.nextHoverSound = CurTime() + 0.08
	surface.PlaySound(ix.ui.SOUND_HOVER)
end

function BUTTON:OnMousePressed(code)
	if (self:GetDisabled()) then
		surface.PlaySound(ix.ui.SOUND_ERROR)
		return
	end

	surface.PlaySound(ix.ui.SOUND_CLICK)
	if (code == MOUSE_LEFT and self.DoClick) then
		self:DoClick(self)
	end
end

vgui.Register("ixImpButton", BUTTON, "DButton")
-- Legacy aliases so unmigrated plugins don't break
vgui.Register("ixImpMenuButton", BUTTON, "DButton")
vgui.Register("ixImpMenuButtonChar", BUTTON, "DButton")

-- ── ixImpStatus ──────────────────────────────────────────────────────────────
-- A small status indicator pill (e.g. "SYS READY", "AUTH-LVL 3").
-- Usage: local s = vgui.Create("ixImpStatus")
--        s:SetTextValue("SYS READY")
--        s:SetColors(ix.ui.THEME.ready, ix.ui.THEME.ready)

local STATUS = {}

function STATUS:Init()
	self.text = ""
	self.borderColor = ix.ui.THEME.accentSoft
	self.textColor = ix.ui.THEME.text
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

vgui.Register("ixImpStatus", STATUS, "Panel")

-- ═══════════════════════════════════════════════════════════════════════════════
-- HELPER: Walk up the panel tree to find a screening or data panel parent
-- ═══════════════════════════════════════════════════════════════════════════════

function ix.ui.FindScreeningParent(panel)
	local current = panel
	while (IsValid(current)) do
		if (current.__ixImpHasScreening) then return current end
		current = current:GetParent()
	end
end

function ix.ui.FindDataPanelParent(panel)
	local current = panel
	while (IsValid(current)) do
		if (current.__ixImpHasDataPanel) then return current end
		current = current:GetParent()
	end
end

--- Check if a panel tree contains a SpawnIcon anywhere.
-- @param panel Panel
-- @return boolean
function ix.ui.ContainsSpawnIcon(panel)
	for _, child in ipairs(panel:GetChildren() or {}) do
		if (child:GetClassName() == "SpawnIcon") then return true end
		if (ix.ui.ContainsSpawnIcon(child)) then return true end
	end
	return false
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- PAINTING HELPERS (for direct use in Paint callbacks)
-- ═══════════════════════════════════════════════════════════════════════════════

--- Paint a panel row with alternating background.
-- Intended for use inside a Paint callback.
-- @param w     number  Panel width
-- @param h     number  Panel height
-- @param index number  Row index (for alternating)
-- @param hovered boolean|nil  Whether the row is hovered
function ix.ui.PaintRow(w, h, index, hovered)
	local THEME = ix.ui.THEME

	if (hovered) then
		surface.SetDrawColor(THEME.rowHover)
	elseif (index % 2 == 0) then
		surface.SetDrawColor(THEME.rowEven)
	else
		surface.SetDrawColor(THEME.rowOdd)
	end

	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 30)
	surface.DrawRect(0, h - 1, w, 1)
end

--- Paint the standard panel background (dark + gold outlined frame).
-- @param w number
-- @param h number
function ix.ui.PaintPanelBackground(w, h)
	local THEME = ix.ui.THEME

	surface.SetDrawColor(THEME.backgroundSolid)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(THEME.frameSoft)
	surface.DrawOutlinedRect(0, 0, w, h)
end

--- Paint a filled accent button (e.g. ACCEPT button).
-- @param w     number
-- @param h     number
-- @param text  string
-- @param color Color        Button fill color
-- @param hovered boolean
-- @param hoverColor Color|nil  Hovered fill color
-- @param textColor  Color|nil  Text color (default: THEME.backgroundSolid)
function ix.ui.PaintFilledButton(w, h, text, color, hovered, hoverColor, textColor)
	local THEME = ix.ui.THEME
	local bg = hovered and (hoverColor or color) or color

	surface.SetDrawColor(bg)
	surface.DrawRect(0, 0, w, h)
	draw.SimpleText(text, "ixImpMenuButton", w * 0.5, h * 0.5, textColor or THEME.backgroundSolid, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
