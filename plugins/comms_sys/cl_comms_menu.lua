--- Imperial Comms System - Diegetic Channel Selector
-- VGUI panel overlaying the HUD comms area for click-based channel management.
-- Toggle open/close via: +ixcomms_menu
-- Only two keybinds needed: +ixcomms_talk (PTT), +ixcomms_menu (this panel).

ix.comms = ix.comms or {}
ix.comms.menuOpen = false

-- ═══════════════════════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════════════════════

local menuBackdrop = nil

-- ═══════════════════════════════════════════════════════════════════════════════
-- THEME (mirrors diagetichud)
-- ═══════════════════════════════════════════════════════════════════════════════

local THEME = {
	background       = Color(0, 0, 0, 165),
	backgroundStrong = Color(0, 0, 0, 195),
	text             = Color(240, 240, 240, 255),
	textMuted        = Color(200, 200, 200, 220),
	textDark         = Color(155, 155, 155, 200),
	amber            = Color(228, 175, 42, 255),
	amberDim         = Color(194, 144, 21, 225),
	cyan             = Color(84, 168, 255, 255),
	cyanDim          = Color(84, 168, 255, 195),
	green            = Color(70, 185, 100, 255),
	greenDim         = Color(70, 185, 100, 195),
	yellow           = Color(255, 222, 40, 255),
	red              = Color(255, 55, 55, 255),
	redDim           = Color(230, 30, 70, 215),
	borderGray       = Color(130, 130, 130, 220),
	borderAmber      = Color(194, 144, 21, 245),
	borderCyan       = Color(84, 168, 255, 245),
	borderGreen      = Color(70, 160, 80, 230),
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- SCALING
-- ═══════════════════════════════════════════════════════════════════════════════

local function Scale(v)
	return math.max(1, math.Round(v * (ScrH() / 900)))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DRAWING HELPERS (match diagetichud exactly)
-- ═══════════════════════════════════════════════════════════════════════════════

local shadowOuter = Color(0, 0, 0, 180)
local shadowInner = Color(0, 0, 0, 230)

local function DrawShadowText(text, font, x, y, color, alignX, alignY)
	alignX = alignX or TEXT_ALIGN_LEFT
	alignY = alignY or TEXT_ALIGN_TOP

	shadowOuter.a = math.min(180, color.a)
	draw.SimpleText(text, font, x + 2, y + 2, shadowOuter, alignX, alignY)

	shadowInner.a = math.min(230, color.a)
	draw.SimpleText(text, font, x + 1, y + 1, shadowInner, alignX, alignY)

	draw.SimpleText(text, font, x, y, color, alignX, alignY)
end

local panelBg = Color(0, 0, 0, 185)

local function DrawMenuPanel(x, y, w, h, borderColor, bgAlpha)
	bgAlpha = bgAlpha or 185

	local cornerR = Scale(4)
	local borderW = Scale(4)
	local RNDX = ix.RNDX

	if (RNDX) then
		panelBg.a = bgAlpha
		RNDX.Draw(cornerR, x, y, w, h, panelBg)
		RNDX.Draw(cornerR, x, y, borderW, h, borderColor, RNDX.NO_TR + RNDX.NO_BR)
	else
		surface.SetDrawColor(0, 0, 0, bgAlpha)
		surface.DrawRect(x, y, w, h)

		surface.SetDrawColor(borderColor)
		surface.DrawRect(x, y, borderW, h)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLOSE
-- ═══════════════════════════════════════════════════════════════════════════════

local function CloseCommsMenu()
	if (IsValid(menuBackdrop)) then
		menuBackdrop:Remove()
	end

	menuBackdrop = nil
	ix.comms.menuOpen = false
	gui.EnableScreenClicker(false)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- OPEN
-- ═══════════════════════════════════════════════════════════════════════════════

local function OpenCommsMenu()
	-- Toggle off
	if (IsValid(menuBackdrop)) then
		CloseCommsMenu()
		return
	end

	local lply = LocalPlayer()

	if (!IsValid(lply)) then return end
	if (!ix.comms or !ix.comms.channels or #ix.comms.channels == 0) then return end

	local accessible = ix.comms.GetAccessibleChannels(lply)

	if (#accessible == 0) then return end

	-- ─── Dimensions ─────────────────────────────────────────────────────
	local panelW = Scale(260)
	local rowH = Scale(48)
	local headerH = Scale(32)
	local footerH = Scale(26)
	local sepH = 1 -- 1px separator between rows
	local totalRowH = #accessible * rowH + math.max(0, #accessible - 1) * sepH
	local panelH = headerH + totalRowH + footerH + Scale(8)
	local pad = Scale(16)
	local panelX = ScrW() - pad - panelW
	local panelY = pad

	-- ─── Backdrop (full-screen click catcher) ───────────────────────────
	local backdrop = vgui.Create("DPanel")
	backdrop:SetPos(0, 0)
	backdrop:SetSize(ScrW(), ScrH())
	backdrop:MakePopup()
	backdrop:SetKeyboardInputEnabled(false)

	backdrop.Paint = function() end

	backdrop.OnMousePressed = function(self, keyCode)
		CloseCommsMenu()
	end

	-- Safety: close if player dies or tab menu opens
	backdrop.Think = function(self)
		if (!IsValid(lply) or !lply:Alive()) then
			CloseCommsMenu()
			return
		end

		if (IsValid(ix.gui.menu)) then
			CloseCommsMenu()
			return
		end
	end

	-- ─── Menu panel ─────────────────────────────────────────────────────
	local menu = vgui.Create("DPanel", backdrop)
	menu:SetSize(panelW, panelH)

	-- Animation state
	local openTime = SysTime()
	local animDuration = 0.18
	local startY = panelY - Scale(16)
	local targetY = panelY

	menu:SetPos(panelX, startY)
	menu.paintAlpha = 0

	menu.Think = function(self)
		local elapsed = SysTime() - openTime
		local frac = math.Clamp(elapsed / animDuration, 0, 1)

		-- OutCubic easing
		frac = 1 - math.pow(1 - frac, 3)

		local curY = Lerp(frac, startY, targetY)

		self:SetPos(panelX, curY)
		self.paintAlpha = frac
	end

	menu.Paint = function(self, w, h)
		local alpha = self.paintAlpha or 1

		if (alpha < 0.01) then return end

		DrawMenuPanel(0, 0, w, h, THEME.borderAmber, math.floor(215 * alpha))

		local borderW = Scale(4)
		local innerPad = Scale(8)
		local innerX = borderW + innerPad
		local innerY = Scale(8)

		-- Header
		DrawShadowText("CHANNEL SELECT", "ixHUDMonoSmall", innerX, innerY,
			ColorAlpha(THEME.amber, math.floor(255 * alpha)))

		DrawShadowText("comlink", "ixHUDAurebeshSmall", w - innerPad, innerY,
			ColorAlpha(THEME.amber, math.floor(55 * alpha)), TEXT_ALIGN_RIGHT)

		-- Separator under header
		surface.SetDrawColor(THEME.borderGray.r, THEME.borderGray.g, THEME.borderGray.b,
			math.floor(60 * alpha))
		surface.DrawRect(innerX, headerH - Scale(2), w - borderW - innerPad * 2, 1)

		-- Footer hint
		local footerY = h - footerH + Scale(4)

		DrawShadowText("LMB: SELECT  //  RMB: MUTE", "ixHUDMonoSmall", innerX, footerY,
			ColorAlpha(THEME.textDark, math.floor(160 * alpha)))
	end

	-- Eat mouse events so they don't pass through to backdrop
	menu.OnMousePressed = function() end

	-- ─── Channel rows ───────────────────────────────────────────────────
	local yOffset = headerH

	for idx, entry in ipairs(accessible) do
		local chanID = entry.id
		local chan = entry.channel
		local canTalk = entry.canTalk

		local btn = vgui.Create("DButton", menu)
		btn:SetPos(Scale(5), yOffset)
		btn:SetSize(panelW - Scale(10), rowH)
		btn:SetText("")
		btn:SetCursor("hand")

		btn.chanID = chanID
		btn.chan = chan
		btn.canTalk = canTalk

		btn.Paint = function(self, w, h)
			local parentAlpha = menu.paintAlpha or 1

			if (parentAlpha < 0.01) then return end

			local isActive = ix.comms.GetActiveChannel() == self.chanID
			local isMuted = ix.comms.IsChannelMuted(self.chanID)
			local hovered = self:IsHovered()

			local accentColor = self.chan.Color or THEME.cyan
			local accentW = Scale(3)
			local cornerR = Scale(3)

			-- Row background alpha (hover / active / muted)
			local bgAlpha = 35

			if (isActive) then
				bgAlpha = hovered and 95 or 60
			elseif (isMuted) then
				bgAlpha = hovered and 45 or 18
			else
				bgAlpha = hovered and 70 or 35
			end

			bgAlpha = math.floor(bgAlpha * parentAlpha)

			-- Draw background
			local RNDX = ix.RNDX

			if (RNDX) then
				RNDX.Draw(cornerR, 0, 0, w, h, Color(0, 0, 0, bgAlpha))

				local aAlpha = isMuted and math.floor(100 * parentAlpha) or math.floor(255 * parentAlpha)

				RNDX.Draw(cornerR, 0, 0, accentW, h,
					ColorAlpha(accentColor, aAlpha),
					RNDX.NO_TR + RNDX.NO_BR)
			else
				surface.SetDrawColor(0, 0, 0, bgAlpha)
				surface.DrawRect(0, 0, w, h)

				local aAlpha = isMuted and math.floor(100 * parentAlpha) or math.floor(255 * parentAlpha)

				surface.SetDrawColor(accentColor.r, accentColor.g, accentColor.b, aAlpha)
				surface.DrawRect(0, 0, accentW, h)
			end

			-- Hover outline
			if (hovered) then
				surface.SetDrawColor(accentColor.r, accentColor.g, accentColor.b,
					math.floor(45 * parentAlpha))
				surface.DrawOutlinedRect(0, 0, w, h)
			end

			-- Active channel glow
			if (isActive) then
				local pulse = math.sin(CurTime() * 3) * 0.2 + 0.8

				surface.SetDrawColor(THEME.green.r, THEME.green.g, THEME.green.b,
					math.floor(25 * pulse * parentAlpha))
				surface.DrawRect(accentW, 1, w - accentW - 1, h - 2)
			end

			-- ── Text content ────────────────────────────────────────────
			local innerX = Scale(10)
			local innerY = Scale(6)

			-- Channel name
			local nameCol = isMuted and THEME.textDark or THEME.text

			DrawShadowText(self.chan.Name, "ixHUDLabelSmall", innerX, innerY,
				ColorAlpha(nameCol, math.floor(255 * parentAlpha)))

			-- Frequency (right-aligned)
			DrawShadowText(self.chan.Frequency .. " MHZ", "ixHUDMonoSmall",
				w - Scale(6), innerY + Scale(1),
				ColorAlpha(THEME.textDark, math.floor(200 * parentAlpha)),
				TEXT_ALIGN_RIGHT)

			-- Second line: encryption, access, status
			innerY = innerY + Scale(18)

			local encText = self.chan.Encrypted and "ENC" or "OPEN"
			local accessText = self.canTalk and "TX/RX" or "RX"
			local infoCol = isMuted
				and ColorAlpha(THEME.textDark, math.floor(130 * parentAlpha))
				or ColorAlpha(THEME.cyanDim, math.floor(195 * parentAlpha))

			DrawShadowText(encText .. " // " .. accessText, "ixHUDMonoSmall", innerX, innerY, infoCol)

			-- Status badge
			if (isActive) then
				local pulse = math.sin(CurTime() * 3) * 0.15 + 0.85

				DrawShadowText("★ ACTIVE", "ixHUDMonoSmall", w - Scale(6), innerY,
					ColorAlpha(THEME.green, math.floor(255 * pulse * parentAlpha)),
					TEXT_ALIGN_RIGHT)
			elseif (isMuted) then
				DrawShadowText("✕ MUTED", "ixHUDMonoSmall", w - Scale(6), innerY,
					ColorAlpha(THEME.redDim, math.floor(215 * parentAlpha)),
					TEXT_ALIGN_RIGHT)
			elseif (!self.chan.Mutable) then
				-- Show lock hint (can't mute this channel)
				DrawShadowText("⊘ LOCKED", "ixHUDMonoSmall", w - Scale(6), innerY,
					ColorAlpha(THEME.textDark, math.floor(120 * parentAlpha)),
					TEXT_ALIGN_RIGHT)
			end

			-- Description on hover (third line)
			if (hovered and self.chan.Description and self.chan.Description != "") then
				innerY = innerY + Scale(12)

				DrawShadowText(self.chan.Description, "ixHUDMonoSmall", innerX, innerY,
					ColorAlpha(THEME.textMuted, math.floor(170 * parentAlpha)))
			end
		end

		-- Left click: activate / deactivate channel
		btn.OnMousePressed = function(self, keyCode)
			if (keyCode == MOUSE_LEFT) then
				local curActive = ix.comms.GetActiveChannel()

				if (curActive == self.chanID) then
					-- Deactivate
					ix.comms.ChangeActiveChannel(0)
				else
					-- Unmute if muted
					if (ix.comms.IsChannelMuted(self.chanID)) then
						ix.comms.ChangeMuteStatus(self.chanID, false)
					end

					-- Activate (only if can talk)
					if (self.canTalk) then
						ix.comms.ChangeActiveChannel(self.chanID)
					end
				end
			elseif (keyCode == MOUSE_RIGHT) then
				if (!self.chan.Mutable) then
					surface.PlaySound(ix.comms.config.sounds.error)
					return
				end

				local curMuted = ix.comms.IsChannelMuted(self.chanID)

				ix.comms.ChangeMuteStatus(self.chanID, !curMuted)
				surface.PlaySound(ix.comms.config.sounds.channelMute)

				-- If we just muted the active channel, deactivate
				if (!curMuted and ix.comms.GetActiveChannel() == self.chanID) then
					ix.comms.ChangeActiveChannel(0)
				end
			end
		end

		yOffset = yOffset + rowH

		-- Separator between rows (not after last)
		if (idx < #accessible) then
			local sep = vgui.Create("DPanel", menu)
			sep:SetPos(Scale(12), yOffset)
			sep:SetSize(panelW - Scale(24), sepH)

			sep.Paint = function(self, w, h)
				local alpha = menu.paintAlpha or 1

				surface.SetDrawColor(THEME.borderGray.r, THEME.borderGray.g, THEME.borderGray.b,
					math.floor(40 * alpha))
				surface.DrawRect(0, 0, w, h)
			end

			yOffset = yOffset + sepH
		end
	end

	menuBackdrop = backdrop
	ix.comms.menuOpen = true
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- KEYBIND (toggle)
-- ═══════════════════════════════════════════════════════════════════════════════

concommand.Add("+ixcomms_menu", function()
	OpenCommsMenu()
end)

concommand.Add("-ixcomms_menu", function()
	-- Toggle on key press, not release
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLEANUP HOOKS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Close menu on screen resolution change
hook.Add("OnScreenSizeChanged", "ixCommsMenu_ScreenChange", function()
	CloseCommsMenu()
end)

-- Close menu when tab menu opens
hook.Add("OnPauseMenuShow", "ixCommsMenu_PauseMenu", function()
	CloseCommsMenu()
end)
