--- Imperial Diegetic HUD - Client Plugin
-- Draws all HUD elements: compass, vitals, weapon, mission status, comms, squad, damage indicators.
-- Visual language: VANIR design system — title bars, corner notches, open negative space,
-- ix.ui.THEME tokens shared with ImpMainMenu.

local PLUGIN = PLUGIN

-- ═══════════════════════════════════════════════════════════════════════════════
-- THEME TOKENS (shared with ImpMainMenu via ix.ui)
-- ═══════════════════════════════════════════════════════════════════════════════

-- ix.ui.THEME is populated by 00_imperial_ui which loads before this plugin.
local THEME = ix.ui.THEME

-- One-off HUD semantic colors (not accent — used sparingly at reduced opacity).
local HUD_COMMS_COLOR  = Color(84,  168, 255, 200)
local HUD_SQUAD_COLOR  = Color(70,  185, 100, 180)
local HUD_DANGER_COLOR = Color(215, 40,  40,  220)

-- ═══════════════════════════════════════════════════════════════════════════════
-- SCALING
-- ═══════════════════════════════════════════════════════════════════════════════

local function Scale(value)
	return math.max(1, math.Round(value * (ScrH() / 900)))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- FONTS — 5 typefaces (Orbitron / Roboto / Aurebesh only)
-- ═══════════════════════════════════════════════════════════════════════════════

local function CreateFonts()
	-- Title bar labels and gold-strip headers.
	surface.CreateFont("ixHUDTitle", {
		font      = "Orbitron Medium",
		size      = Scale(11),
		weight    = 600,
		extended  = true,
		antialias = true
	})

	-- Technical readouts: compass cardinals, DEFCON row, weapon name, fire mode.
	surface.CreateFont("ixHUDData", {
		font      = "Orbitron Light",
		size      = Scale(11),
		weight    = 500,
		extended  = true,
		antialias = true
	})

	-- Large display: compass bearing, ammo clip count, character name wordmark.
	surface.CreateFont("ixHUDDataLarge", {
		font      = "Orbitron Bold",
		size      = Scale(32),
		weight    = 700,
		extended  = true,
		antialias = true
	})

	-- Secondary descriptive labels: objective text, member names, channel labels.
	surface.CreateFont("ixHUDLabel", {
		font      = "Roboto",
		size      = Scale(10),
		weight    = 400,
		extended  = true,
		antialias = true
	})

	-- Diegetic metadata only — embedded in corners and adjacent to title bars.
	surface.CreateFont("ixHUDAurebesh", {
		font      = "Aurebesh",
		size      = Scale(8),
		weight    = 400,
		extended  = true,
		antialias = true
	})
end

CreateFonts()

hook.Add("OnScreenSizeChanged", "ixDiegeticHUDFonts", function()
	CreateFonts()
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- RNDX LIBRARY REFERENCE (GPU-accelerated rounded rectangles)
-- ═══════════════════════════════════════════════════════════════════════════════

-- cl_rndx.lua is loaded synchronously before this plugin, so ix.RNDX is
-- already set by the time this file executes.
local RNDX = ix.RNDX

-- ═══════════════════════════════════════════════════════════════════════════════
-- DRAWING UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Pre-allocated shadow colors (avoid per-frame garbage).
local shadowColorOuter = Color(0, 0, 0, 180)
local shadowColorInner = Color(0, 0, 0, 230)

--- Double-layered shadow text for readability over any background.
local function DrawShadowText(text, font, x, y, color, alignX, alignY)
	alignX = alignX or TEXT_ALIGN_LEFT
	alignY = alignY or TEXT_ALIGN_TOP

	shadowColorOuter.a = math.min(180, color.a)
	draw.SimpleText(text, font, x + 2, y + 2, shadowColorOuter, alignX, alignY)

	shadowColorInner.a = math.min(230, color.a)
	draw.SimpleText(text, font, x + 1, y + 1, shadowColorInner, alignX, alignY)

	draw.SimpleText(text, font, x, y, color, alignX, alignY)
end

-- Pre-allocated bar colors.
local barBgColor      = Color(0, 0, 0, 100) -- reduced from 185 — let world show through
local barOutlineColor = Color(70, 70, 70, 80)
local barColorGood    = Color(191, 148, 53, 255)  -- THEME.accent equivalent
local barColorWarn    = Color(210, 190, 30, 255)
local barColorCrit    = Color(215, 40,  40, 255)

--- Horizontal bar (health, stamina, overheat, squad member).
local function DrawBar(x, y, w, h, fraction, barColor)
	fraction = math.Clamp(fraction, 0, 1)
	local cornerR = math.max(1, math.floor(h * 0.4))

	if (RNDX) then
		RNDX.Draw(cornerR, x, y, w, h, barBgColor)

		if (fraction > 0) then
			local fillW = math.max(h, w * fraction)
			RNDX.Draw(cornerR, x, y, fillW, h, barColor)
		end
	else
		surface.SetDrawColor(barBgColor)
		surface.DrawRect(x, y, w, h)

		surface.SetDrawColor(barOutlineColor)
		surface.DrawOutlinedRect(x, y, w, h)

		if (fraction > 0) then
			surface.SetDrawColor(barColor)
			surface.DrawRect(x, y, w * fraction, h)
		end
	end
end

--- Gold title bar strip — inverted: accent background, black text, Aurebesh right.
-- Mirrors "OPERATIVE STATUS" bar in cl_unified_panel.lua.
-- @param x, y, w  Position and width (height is always Scale(16))
-- @param label    Left-aligned label text (drawn in ixHUDTitle, black on gold)
-- @param aurebesh Optional Aurebesh suffix, right-aligned at reduced opacity
-- @return number  The bar height (Scale(16)) for layout chaining
local function DrawTitleBar(x, y, w, label, aurebesh)
	local h = Scale(16)
	local accent = THEME.accent

	surface.SetDrawColor(accent.r, accent.g, accent.b, 210)
	surface.DrawRect(x, y, w, h)

	draw.SimpleText(label, "ixHUDTitle", x + Scale(6), h * 0.5 + y, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	if (aurebesh) then
		draw.SimpleText(aurebesh, "ixHUDAurebesh", x + w - Scale(6), h * 0.5 + y, Color(0, 0, 0, 140), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	return h
end

--- Single corner notch anchor. x, y is the exact corner point; dir is "TL"/"TR"/"BL"/"BR".
-- The two strokes are offset so they never share a pixel — no alpha doubling at the join.
local function DrawNotch(x, y, dir)
	local notch = Scale(10)
	local thick = Scale(2)
	local accent = THEME.accent

	surface.SetDrawColor(accent.r, accent.g, accent.b, 90)

	if (dir == "TL") then
		surface.DrawRect(x,          y,           notch, thick)           -- horizontal
		surface.DrawRect(x,          y + thick,   thick, notch - thick)   -- vertical, below horiz
	elseif (dir == "TR") then
		surface.DrawRect(x - notch,  y,           notch, thick)           -- horizontal
		surface.DrawRect(x - thick,  y + thick,   thick, notch - thick)   -- vertical, below horiz
	elseif (dir == "BL") then
		surface.DrawRect(x,          y - thick,   notch, thick)           -- horizontal
		surface.DrawRect(x,          y - notch,   thick, notch - thick)   -- vertical, above horiz
	elseif (dir == "BR") then
		surface.DrawRect(x - notch,  y - thick,   notch, thick)           -- horizontal
		surface.DrawRect(x - thick,  y - notch,   thick, notch - thick)   -- vertical, above horiz
	end
end

--- 1px implied separator line (accent at very low alpha).
-- Used between data rows to imply grouping without boxing.
local function DrawImpliedSeparator(x, y, w)
	local accent = THEME.accent
	surface.SetDrawColor(accent.r, accent.g, accent.b, 30)
	surface.DrawRect(x, y, w, Scale(1))
end

--- Health/vital threshold color.
local function GetVitalColor(fraction)
	if (fraction > 0.6) then return THEME.accent end
	if (fraction > 0.3) then return THEME.warning end
	return HUD_DANGER_COLOR
end

--- Bar fill color.
local function GetBarColor(fraction)
	if (fraction > 0.6) then return barColorGood end
	if (fraction > 0.3) then return barColorWarn end
	return barColorCrit
end

--- Overheat bar color (inverted — gold low, red high).
local heatColorLow  = Color(191, 148, 53,  255)
local heatColorMid  = Color(210, 190, 30,  255)
local heatColorHigh = Color(215, 40,  40,  255)

local function GetHeatColor(fraction)
	if (fraction < 0.5) then return heatColorLow  end
	if (fraction < 0.8) then return heatColorMid  end
	return heatColorHigh
end

--- Directional arrow for bearing relative to compass heading.
local BEARING_ARROWS = {"↑", "↗", "→", "↘", "↓", "↙", "←", "↖"}

local function GetBearingArrow(targetBearing, compassBearing)
	local diff  = ((targetBearing - compassBearing + 180 + 360) % 360) - 180
	local index = math.floor(((diff + 360 + 22.5) % 360) / 45) + 1
	return BEARING_ARROWS[math.Clamp(index, 1, 8)]
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLIENT STATE
-- ═══════════════════════════════════════════════════════════════════════════════

local waypoints          = {}
local squadData          = {members = {}, designation = ""}
local bogusSquadMembers  = {}
local activeTransmission = nil
local forcedTransmission = {
	speaker   = "LOCAL",
	channel   = "OPEN MIC",
	freq      = "0000.0",
	encrypted = true
}
local transmissionEndTime = 0
local damageDirection     = nil
local damageEndTime       = 0
local vignetteAlpha       = 0

local connectedChannels = {}

local availableChannels = {
	{id = "cmd", name = "COMMAND NET",  freq = "8858.0", encrypted = true},
	{id = "sqd", name = "SQUAD COMMS",  freq = "4521.5", encrypted = true},
	{id = "log", name = "LOGISTICS",    freq = "7799.2", encrypted = false},
	{id = "emg", name = "EMERGENCY",    freq = "3366.8", encrypted = true}
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- NETWORK RECEIVERS
-- ═══════════════════════════════════════════════════════════════════════════════

net.Receive("ixDiegeticWaypoint", function()
	local id     = net.ReadString()
	local label  = net.ReadString()
	local pos    = net.ReadVector()
	local wpType = net.ReadString()

	waypoints[id] = {label = label, pos = pos, type = wpType}
end)

net.Receive("ixDiegeticWaypointClear", function()
	waypoints[net.ReadString()] = nil
end)

net.Receive("ixDiegeticSquadSync", function()
	local id          = net.ReadString()
	local designation = net.ReadString()
	local count       = net.ReadUInt(8)
	local members     = {}

	for i = 1, count do
		table.insert(members, {
			steamID   = net.ReadString(),
			name      = net.ReadString(),
			health    = net.ReadUInt(8),
			maxHealth = net.ReadUInt(8),
			pos       = net.ReadVector(),
			alive     = net.ReadBool()
		})
	end

	squadData.designation = designation
	squadData.members     = members
end)

net.Receive("ixDiegeticSquadBogus", function()
	local id = net.ReadString()

	bogusSquadMembers[id] = {
		steamID   = "bogus_" .. id,
		name      = net.ReadString(),
		health    = net.ReadUInt(8),
		maxHealth = net.ReadUInt(8),
		pos       = net.ReadVector(),
		alive     = net.ReadBool()
	}
end)

net.Receive("ixDiegeticCommsTransmission", function()
	local speaker   = net.ReadString()
	local channel   = net.ReadString()
	local freq      = net.ReadString()
	local encrypted = net.ReadBool()
	local duration  = net.ReadFloat()

	activeTransmission = {speaker = speaker, channel = channel, freq = freq, encrypted = encrypted}
	transmissionEndTime = CurTime() + duration

	if (!table.HasValue(connectedChannels, channel)) then
		if (#connectedChannels >= 2) then table.remove(connectedChannels, 1) end
		table.insert(connectedChannels, channel)
	end
end)

net.Receive("ixDiegeticDamageDir", function()
	local attackerPos = net.ReadVector()
	local ply         = LocalPlayer()

	if (!IsValid(ply)) then return end

	local plyPos    = ply:GetPos()
	local plyAng    = ply:EyeAngles()
	local toAttacker = (attackerPos - plyPos):GetNormalized()
	local forward   = plyAng:Forward()
	local right     = plyAng:Right()
	local dot       = forward:Dot(toAttacker)
	local cross     = right:Dot(toAttacker)

	if (math.abs(dot) > math.abs(cross)) then
		damageDirection = dot > 0 and "top" or "bottom"
	else
		damageDirection = cross > 0 and "right" or "left"
	end

	damageEndTime = CurTime() + 0.3
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLIENT-SIDE COMMS CHANNEL MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════════

function ix.diegeticHUD.ConnectChannel(channelName)
	if (table.HasValue(connectedChannels, channelName)) then return end
	if (#connectedChannels >= 2) then table.remove(connectedChannels, 1) end
	table.insert(connectedChannels, channelName)
end

function ix.diegeticHUD.DisconnectChannel(channelName)
	for i, name in ipairs(connectedChannels) do
		if (name == channelName) then table.remove(connectedChannels, i) break end
	end
end

function ix.diegeticHUD.DisconnectAllChannels()
	connectedChannels = {}
end

function ix.diegeticHUD.GetConnectedChannels()
	return connectedChannels
end

function ix.diegeticHUD.GetAvailableChannels()
	return availableChannels
end

concommand.Add("ix_hud_connect", function(ply, cmd, args)
	if (!args[1]) then
		print("[HUD] Available channels:")
		for _, ch in ipairs(availableChannels) do
			local connected = table.HasValue(connectedChannels, ch.name) and " [CONNECTED]" or ""
			print("  " .. ch.name .. " (" .. ch.freq .. " MHZ)" .. connected)
		end
		return
	end
	ix.diegeticHUD.ConnectChannel(table.concat(args, " "))
	print("[HUD] Connected to: " .. table.concat(args, " "))
end)

concommand.Add("ix_hud_disconnect", function(ply, cmd, args)
	if (!args[1]) then
		ix.diegeticHUD.DisconnectAllChannels()
		print("[HUD] Disconnected from all channels.")
		return
	end
	ix.diegeticHUD.DisconnectChannel(table.concat(args, " "))
	print("[HUD] Disconnected from: " .. table.concat(args, " "))
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- SUPPRESS DEFAULT HUD ELEMENTS
-- ═══════════════════════════════════════════════════════════════════════════════

local hiddenElements = {
	["CHudHealth"]                 = true,
	["CHudBattery"]                = true,
	["CHudAmmo"]                   = true,
	["CHudSecondaryAmmo"]          = true,
	["CHudDamageIndicator"]        = true,
	["CHudHistoryResource"]        = true,
	["CHudPoisonDamageIndicator"]  = true,
	["CHudSquadStatus"]            = true,
	["CHUDQuickInfo"]              = true
}

function PLUGIN:HUDShouldDraw(element)
	if (hiddenElements[element]) then return false end
end

function PLUGIN:CanDrawAmmoHUD()
	return false
end

function PLUGIN:ShouldHideBars()
	return true
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- LSCS INTEGRATION — suppress original HUD circles/arcs wholesale.
-- Proximity target indicators inside SWEP:DrawHUD are NOT gated by this hook
-- so they survive untouched. We redraw everything else in DrawLightsaber below.
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("LSCS:HUDShouldDraw", "ixDiegeticLSCS", function()
	return false
end)

-- Pre-allocated colors for the lightsaber panel (avoid per-frame allocations).
local lscsForceColor  = Color(84,  168, 255, 255)  -- comms blue — Force
local lscsBpGood      = Color(191, 148, 53,  255)  -- gold  — block healthy
local lscsBpWarn      = Color(210, 190, 30,  255)  -- warm gold — block low
local lscsBpCrit      = Color(215, 40,  40,  255)  -- red   — block critical

local function GetBPColor(fraction)
	if (fraction > 0.6) then return lscsBpGood end
	if (fraction > 0.25) then return lscsBpWarn end
	return lscsBpCrit
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- HUD PAINT — MAIN ENTRY
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:HUDPaint()
	local ply = LocalPlayer()

	if (!IsValid(ply) or !ply:Alive()) then return end
	if (IsValid(ix.gui.menu)) then return end

	local scrW, scrH = ScrW(), ScrH()
	local pad        = Scale(16)

	if (activeTransmission and CurTime() > transmissionEndTime) then
		activeTransmission = nil
	end

	if (damageDirection and CurTime() > damageEndTime) then
		damageDirection = nil
	end

	local health      = ply:Health()
	local maxHealth   = ply:GetMaxHealth()
	local healthFrac  = math.Clamp(health / math.max(maxHealth, 1), 0, 1)

	vignetteAlpha = Lerp(FrameTime() * 3, vignetteAlpha, (1 - healthFrac) * 0.4)

	self:DrawDamageIndicator(scrW, scrH)
	self:DrawCriticalHealthBorder(scrW, scrH, healthFrac)
	self:DrawCompass(scrW, scrH, ply)
	self:DrawMissionStatus(scrW, scrH, ply, pad)
	self:DrawComms(scrW, scrH, pad)
	self:DrawSquad(scrW, scrH, ply, pad)
	self:DrawVitals(scrW, scrH, ply, pad, healthFrac)
	self:DrawWeapon(scrW, scrH, ply, pad)
	self:DrawLightsaber(scrW, scrH, ply, pad)
	self:DrawVignette(scrW, scrH)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DAMAGE DIRECTION INDICATOR
-- ═══════════════════════════════════════════════════════════════════════════════

local gradDamageColor   = Color(155, 10, 10, 100)
local gradTransparent   = Color(0,   0,  0,  0)
local gradVignetteColor = Color(0,   0,  0,  80)

function PLUGIN:DrawDamageIndicator(scrW, scrH)
	if (!damageDirection) then return end

	local alpha       = math.Clamp((damageEndTime - CurTime()) / 0.3, 0, 1) * 120
	local h           = Scale(120)
	gradDamageColor.a = alpha

	if (damageDirection == "top") then
		draw.LinearGradient(0, 0, scrW, h, {{offset = 0, color = gradDamageColor}, {offset = 1, color = gradTransparent}}, true)
	elseif (damageDirection == "bottom") then
		draw.LinearGradient(0, scrH - h, scrW, h, {{offset = 0, color = gradTransparent}, {offset = 1, color = gradDamageColor}}, true)
	elseif (damageDirection == "left") then
		draw.LinearGradient(0, 0, h, scrH, {{offset = 0, color = gradDamageColor}, {offset = 1, color = gradTransparent}}, false)
	elseif (damageDirection == "right") then
		draw.LinearGradient(scrW - h, 0, h, scrH, {{offset = 0, color = gradTransparent}, {offset = 1, color = gradDamageColor}}, false)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CRITICAL HEALTH BORDER
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:DrawCriticalHealthBorder(scrW, scrH, healthFrac)
	if (healthFrac >= 0.2) then return end

	-- 1.5 Hz pulse, max alpha 60 (subtle)
	local pulse  = math.sin(CurTime() * 1.5) * 0.5 + 0.5
	local alpha  = math.Clamp(pulse * 60, 12, 60)
	local borderW = Scale(2)

	surface.SetDrawColor(HUD_DANGER_COLOR.r, HUD_DANGER_COLOR.g, HUD_DANGER_COLOR.b, alpha)
	surface.DrawRect(0, 0, scrW, borderW)
	surface.DrawRect(0, scrH - borderW, scrW, borderW)
	surface.DrawRect(0, 0, borderW, scrH)
	surface.DrawRect(scrW - borderW, 0, borderW, scrH)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- VIGNETTE (health-based)
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:DrawVignette(scrW, scrH)
	if (vignetteAlpha <= 0.01) then return end

	local alpha             = math.Clamp(vignetteAlpha * 255, 0, 100)
	local size              = scrH * 0.4
	gradVignetteColor.a     = alpha

	draw.LinearGradient(0, 0, size, size, {{offset = 0, color = gradVignetteColor}, {offset = 1, color = gradTransparent}}, false)
	draw.LinearGradient(scrW - size, 0, size, size, {{offset = 0, color = gradTransparent}, {offset = 1, color = gradVignetteColor}}, false)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- COMPASS & NAVIGATION — Top Center
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:DrawCompass(scrW, scrH, ply)
	local ang     = ply:EyeAngles()
	local yaw     = ang.y % 360
	if (yaw < 0) then yaw = yaw + 360 end

	-- Source engine yaw → compass bearing (0 = North)
	local bearing = math.floor((-yaw + 90 + 360) % 360)
	local cx      = scrW * 0.5
	local topY    = Scale(16)

	-- Corner notches define compass extent without a background panel.
	local extentW = Scale(200)
	local extentH = Scale(60)
	DrawNotch(cx - extentW * 0.5, topY - Scale(4), "TL")
	DrawNotch(cx + extentW * 0.5, topY - Scale(4), "TR")

	-- Aurebesh "navigat" — diegetic metadata, directly above bearing.
	local accent = THEME.accent
	DrawShadowText("navigat", "ixHUDAurebesh", cx, topY - Scale(3), Color(accent.r, accent.g, accent.b, 55), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

	-- Large bearing number (Orbitron replaces OCR-A).
	local brgStr = string.format("%03d", bearing)
	DrawShadowText(brgStr .. "°", "ixHUDDataLarge", cx, topY, THEME.accent, TEXT_ALIGN_CENTER)

	-- "BRG" secondary label — demoted to ixHUDLabel.
	DrawShadowText("BRG", "ixHUDLabel", cx - Scale(60), topY + Scale(12), THEME.textMuted, TEXT_ALIGN_LEFT)

	-- Cardinal direction pills — ixHUDData, active = accent, idle = textMuted.
	local cardinals = {
		{label = "N", min = 315, max = 360, min2 = 0, max2 = 45},
		{label = "E", min = 45,  max = 135},
		{label = "S", min = 135, max = 225},
		{label = "W", min = 225, max = 315}
	}
	local spacing = Scale(24)
	local totalW  = spacing * 3
	local cardX   = cx - (totalW * 0.5)
	local cardY   = topY + Scale(34)

	for i, card in ipairs(cardinals) do
		local active = false
		if (card.min2) then
			active = (bearing >= card.min and bearing < card.max) or (bearing >= card.min2 and bearing < card.max2)
		else
			active = (bearing >= card.min and bearing < card.max)
		end
		DrawShadowText(card.label, "ixHUDData", cardX + (i - 1) * spacing, cardY, active and THEME.accent or THEME.textMuted, TEXT_ALIGN_CENTER)
	end

	-- Waypoint rows below compass.
	local wpY    = topY + extentH + Scale(4)
	local wpCount = 0

	for id, wp in pairs(waypoints) do
		local dist     = math.floor(ply:GetPos():Distance(wp.pos) / 52.49)
		local wpAngle  = math.deg(math.atan2(wp.pos.y - ply:GetPos().y, wp.pos.x - ply:GetPos().x))
		local wpBearing = (-wpAngle + 90 + 360) % 360
		local arrow    = GetBearingArrow(wpBearing, bearing)
		local isT      = wp.type == "THR"
		local labelCol = isT and HUD_DANGER_COLOR or THEME.accent

		-- Prefix in textMuted, label+data in labelCol.
		local prefix = isT and "THR" or "TGT"
		DrawShadowText(prefix .. ":", "ixHUDLabel", cx - Scale(90), wpY, THEME.textMuted)
		DrawShadowText(string.format("%s  //  %dM %s", wp.label, dist, arrow), "ixHUDData", cx - Scale(60), wpY, labelCol)

		wpY     = wpY + Scale(14)
		wpCount = wpCount + 1
		if (wpCount >= 3) then break end
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MISSION STATUS — Top Left
-- Open layout: title bar strips, implied separators, no outer box.
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:DrawMissionStatus(scrW, scrH, ply, pad)
	local x       = pad
	local y       = pad
	local panelW  = Scale(270)
	local lineH   = Scale(14)
	local innerPad = Scale(8)

	local hasPriority  = ix.diegeticHUD.HasPriorityOrder()
	local hasObjective = ix.diegeticHUD.HasObjective(ply)
	local defcon       = ix.diegeticHUD.GetDEFCON()
	local defconData   = ix.diegeticHUD.DEFCON_DATA[defcon]

	-- ── PRIORITY TRANSMISSION ────────────────────────────────────────────────
	if (hasPriority) then
		local pText, pIssuer, pDesc = ix.diegeticHUD.GetPriorityOrder()

		-- Gold title bar (section authority).
		local barH = DrawTitleBar(x, y, panelW, "PRIORITY TRANSMISSION", "transmis")
		y = y + barH

		-- 2px danger left-edge bar for urgency — runs height of content rows only.
		local contentStartY = y
		local innerX = x + Scale(10)

		y = y + Scale(6)
		DrawShadowText(pText, "ixHUDData", innerX, y, THEME.text)

		y = y + lineH + Scale(2)
		DrawShadowText(pDesc, "ixHUDLabel", innerX, y, THEME.textMuted)

		y = y + lineH
		DrawShadowText(pIssuer, "ixHUDLabel", innerX, y, THEME.textMuted)

		y = y + lineH

		-- 2px danger left-edge bar (1.5 Hz pulse, ±30 on base 180).
		local pulse = math.abs(math.sin(CurTime() * 1.5))
		surface.SetDrawColor(HUD_DANGER_COLOR.r, HUD_DANGER_COLOR.g, HUD_DANGER_COLOR.b, math.Round(150 + pulse * 70))
		surface.DrawRect(x, contentStartY, Scale(2), y - contentStartY)

		DrawImpliedSeparator(x, y + Scale(2), panelW)
		y = y + Scale(8)
	end

	-- ── CURRENT OBJECTIVE ────────────────────────────────────────────────────
	if (hasObjective) then
		local oTitle, oDesc = ix.diegeticHUD.GetObjective(ply)

		local barH   = DrawTitleBar(x, y, panelW, "CURRENT OBJECTIVE", "mission")
		y = y + barH

		local innerX = x + Scale(10)

		y = y + Scale(6)
		DrawShadowText(oTitle, "ixHUDData", innerX, y, THEME.text)

		y = y + lineH + Scale(2)
		DrawShadowText(oDesc, "ixHUDLabel", innerX, y, THEME.textMuted)

		y = y + lineH
		DrawImpliedSeparator(x, y + Scale(2), panelW)
		y = y + Scale(8)
	end

	-- ── DEFCON STATUS — plain row, no title bar (lowest hierarchy) ────────────
	-- Reduce alpha when higher-priority items are shown (matches v2 behaviour).
	local defconAlpha  = (hasPriority or hasObjective) and 0.45 or 1.0
	local defconText   = THEME.textMuted
	local defconAccent = THEME.accent

	-- Inline: "DEFSTAT  2 — ELEVATED  WEAPONS HOT"
	local levelStr = tostring(defcon)
	local labelStr = defconData and ("DEFSTAT  " .. levelStr .. "  —  " .. (defconData.threat or "")) or "DEFSTAT  " .. levelStr
	-- DrawShadowText(labelStr, "ixHUDData", x + Scale(4), y, ColorAlpha(defconAccent, math.floor(200 * defconAlpha)))
	if not defconData then
		-- No data for this DEFCON level — draw in muted accent with no description.
		DrawShadowText(labelStr, "ixHUDData", x + Scale(4), y, ColorAlpha(defconAccent, math.floor(200 * defconAlpha)))
	else
		if not (hasPriority or hasObjective) then
			-- Data exists for this DEFCON level — draw title bar with Aurebesh and description below.
			local barH = DrawTitleBar(x + Scale(4), y, panelW, labelStr, "defcon")
			y = y + barH + Scale(4)
		else
			DrawShadowText(labelStr, "ixHUDData", x + Scale(4), y, ColorAlpha(defconAccent, math.floor(200 * defconAlpha)))
			y = y + lineH
		end

		DrawShadowText(defconData and defconData.desc or "", "ixHUDLabel", x + Scale(4), y, ColorAlpha(defconText, math.floor(200 * defconAlpha)))
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- COMMUNICATIONS PANEL — Top Right
-- Title bar, no portrait, no background panel, 1.5 Hz pulse.
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:DrawComms(scrW, scrH, pad)
	local hasRadio = LocalPlayer():GetNetVar("ixHasRadio", true)
	if (!hasRadio) then return end

	local panelW       = Scale(200)
	local x            = scrW - pad - panelW
	local y            = pad
	local lineH        = Scale(14)
	local innerX       = x + Scale(6)
	local forceVoiceBox = LocalPlayer():GetNetVar("ixForceVoiceBox", false)
	local txData       = activeTransmission

	if (!txData and forceVoiceBox) then
		local ply  = LocalPlayer()
		local char = ply.GetCharacter and ply:GetCharacter()
		forcedTransmission.speaker = (char and char:GetName()) or ply:Nick() or "LOCAL"
		txData = forcedTransmission
	end

	-- ── ACTIVE TRANSMISSION BLOCK ─────────────────────────────────────────────
	if (txData) then
		-- Aurebesh in title bar brightens on transmission (1.5 Hz, subtle)
		-- achieved by overriding the standard DrawTitleBar aurebesh alpha.
		local pulse  = math.abs(math.sin(CurTime() * 1.5))
		local h      = DrawTitleBar(x, y, panelW, "COMMS NETWORK", "comlink")
		-- Override: re-draw Aurebesh brighter when active.
		draw.SimpleText("comlink", "ixHUDAurebesh", x + panelW - Scale(6), h * 0.5 + y - h, Color(0, 0, 0, math.Round(160 + pulse * 80)), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		y = y + h

		local contentStartY = y
		y = y + Scale(6)

		-- Speaker name + channel (no portrait box).
		DrawShadowText(txData.speaker, "ixHUDData", innerX, y, THEME.text)
		y = y + lineH + Scale(1)
		DrawShadowText(txData.channel .. "  ·  " .. txData.freq .. " MHZ", "ixHUDLabel", innerX, y, ColorAlpha(HUD_COMMS_COLOR, 180))
		y = y + lineH

		local encText = txData.encrypted and "ENCRYPTED" or "UNSECURE"
		DrawShadowText(encText, "ixHUDLabel", innerX, y, THEME.textMuted)
		y = y + lineH

		-- 2px comms left-edge bar, gently pulsing.
		surface.SetDrawColor(HUD_COMMS_COLOR.r, HUD_COMMS_COLOR.g, HUD_COMMS_COLOR.b, math.Round(150 + pulse * 50))
		surface.DrawRect(x, contentStartY, Scale(2), y - contentStartY)

		if (#connectedChannels > 0) then
			DrawImpliedSeparator(x, y + Scale(2), panelW)
			y = y + Scale(8)
		end
	else
		-- No active transmission — draw title bar only once.
		local h = DrawTitleBar(x, y, panelW, "COMMS NETWORK", "comlink")
		y = y + h + Scale(6)
	end

	-- ── CONNECTED CHANNELS LIST ───────────────────────────────────────────────
	if (#connectedChannels > 0) then
		for _, channelName in ipairs(connectedChannels) do
			local channelData = nil
			for _, ch in ipairs(availableChannels) do
				if (ch.name == channelName) then channelData = ch break end
			end

			local isActive = activeTransmission and activeTransmission.channel == channelName
			local nameCol  = isActive and ColorAlpha(HUD_COMMS_COLOR, 220) or THEME.text

			-- Active channel: 2px left indent bar.
			if (isActive) then
				local pulse = math.abs(math.sin(CurTime() * 1.5))
				surface.SetDrawColor(HUD_COMMS_COLOR.r, HUD_COMMS_COLOR.g, HUD_COMMS_COLOR.b, math.Round(120 + pulse * 60))
				surface.DrawRect(x, y, Scale(2), lineH * 2)
			end

			local textX = isActive and (innerX + Scale(6)) or innerX
			DrawShadowText(channelName, "ixHUDLabel", textX, y, nameCol)

			if (channelData and channelData.encrypted) then
				DrawShadowText("ENC", "ixHUDLabel", x + panelW - Scale(4), y, ColorAlpha(HUD_COMMS_COLOR, 100), TEXT_ALIGN_RIGHT)
			end

			y = y + lineH

			if (channelData) then
				DrawShadowText(channelData.freq .. " MHZ", "ixHUDLabel", textX + Scale(6), y, THEME.textMuted)
			end

			y = y + lineH
			DrawImpliedSeparator(x, y, panelW)
			y = y + Scale(4)
		end
	elseif (!txData) then
		-- No channels, no transmission — minimal idle state.
		DrawShadowText("NO ACTIVE CHANNELS", "ixHUDLabel", innerX, y, THEME.textMuted)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SQUAD / FIRETEAM PANEL — Left Mid
-- Title bar, pip status indicator, no rank badge box.
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:DrawSquad(scrW, scrH, ply, pad)
	if (!ix.diegeticHUD.IsInSquad(ply)) then return end

	local x        = pad
	local y        = scrH * 0.33
	local panelW   = Scale(200)
	local lineH    = Scale(14)

	local members = {}
	for _, m in ipairs(squadData.members) do table.insert(members, m) end
	for _, m in pairs(bogusSquadMembers)  do table.insert(members, m) end
	if (#members == 0) then return end

	-- Title bar — gold strip, Aurebesh "squad" at right.
	local barH = DrawTitleBar(x, y, panelW, squadData.designation or "FIRETEAM", "squad")
	y = y + barH + Scale(6)

	local myPos  = ply:GetPos()
	local myAng  = ply:EyeAngles()
	local myYaw  = (-myAng.y + 90 + 360) % 360

	for _, member in ipairs(members) do
		if (member.steamID == ply:SteamID64()) then continue end

		local healthFrac = math.Clamp(member.health / math.max(member.maxHealth, 1), 0, 1)
		local barColor   = GetBarColor(healthFrac)
		local dist       = math.floor(myPos:Distance(member.pos) / 52.49)

		local toMember      = (member.pos - myPos):GetNormalized()
		local memberAngle   = math.deg(math.atan2(toMember.y, toMember.x))
		local memberBearing = (-memberAngle + 90 + 360) % 360
		local arrow         = GetBearingArrow(memberBearing, myYaw)

		-- Status
		local status, statusCol
		if (!member.alive) then
			status, statusCol = "KIA", HUD_DANGER_COLOR
		elseif (healthFrac < 0.3) then
			status, statusCol = "WOUNDED", HUD_DANGER_COLOR
		elseif (healthFrac < 0.7) then
			status, statusCol = "INJURED", THEME.textMuted
		else
			status, statusCol = "ACTIVE", THEME.accent
		end

		-- Health-colored vertical pip (replaces rank badge box).
		surface.SetDrawColor(barColor.r, barColor.g, barColor.b, 180)
		surface.DrawRect(x, y, Scale(3), lineH + Scale(4))

		local nameX = x + Scale(8)

		DrawShadowText(member.name, "ixHUDData", nameX, y, THEME.text)
		DrawShadowText(status, "ixHUDLabel", x + panelW, y, statusCol, TEXT_ALIGN_RIGHT)

		local barY = y + lineH
		local barW = panelW - Scale(8) - Scale(48)
		DrawBar(nameX, barY, barW, Scale(6), healthFrac, barColor)

		DrawShadowText(dist .. "M  " .. arrow, "ixHUDLabel", nameX, barY + Scale(8), THEME.textMuted)

		y = y + Scale(6) + lineH + Scale(4) + lineH
		DrawImpliedSeparator(x, y - Scale(2), panelW)
		y = y + Scale(4)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- PLAYER VITALS — Bottom Left
-- Character name wordmark + gold faction/class bar mirrors "You" tab header.
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:DrawVitals(scrW, scrH, ply, pad, healthFrac)
	local char = ply:GetCharacter()
	if (!char) then return end

	local panelW  = Scale(240)
	local x       = pad
	local lineH   = Scale(14)
	local barW    = panelW - Scale(10)

	-- Identity strings.
	local charName  = char:GetName() or "UNKNOWN"
	local faction   = team.GetName(ply:Team()) or "UNKNOWN"
	local className = ""
	local classID   = char:GetClass()
	if (classID and classID > 0 and ix.class.list[classID]) then
		className = ix.class.list[classID].name or ""
	end
	local subtitleText = string.upper(faction)
	if (className != "") then
		subtitleText = subtitleText .. "  ·  " .. string.upper(className)
	end

	-- Calculate total height to anchor from bottom.
	-- Rows: name (32) + gold bar (16) + gap (10) + vitals label+bar (14+6+4) + stamina label+bar (14+6) = ~102
	local baseH     = Scale(102)
	local hasWarn   = healthFrac < 0.3
	local totalH    = baseH + (hasWarn and Scale(16) or 0)
	local y         = scrH - pad - totalH

	-- Corner notches: TL + BR diagonal pair bracketing the vitals block extent.
	local notchPad = Scale(10)
	DrawNotch(x - notchPad, y - notchPad, "TL")
	DrawNotch(x + panelW + notchPad, y + totalH + notchPad, "BR")

	-- ── CHARACTER NAME WORDMARK ───────────────────────────────────────────────
	-- Mirrors cl_unified_panel.lua L60: large Orbitron name above gold bar.
	DrawShadowText(string.upper(charName), "ixHUDDataLarge", x, y, THEME.text)
	y = y + Scale(34)

	-- ── GOLD FACTION/CLASS BAR ────────────────────────────────────────────────
	-- Exact mirror of cl_unified_panel.lua L65–72: accent bg, black text, Aurebesh right.
	local barH = DrawTitleBar(x, y, panelW, subtitleText)
	y = y + barH + Scale(10)

	-- ── VITALS BAR ────────────────────────────────────────────────────────────
	local vitalCol = GetVitalColor(healthFrac)
	local barCol   = GetBarColor(healthFrac)
	local pct      = math.floor(healthFrac * 100)

	DrawShadowText("VITALS", "ixHUDLabel", x, y, THEME.textMuted)
	DrawShadowText(pct .. "%", "ixHUDData", x + Scale(48), y, vitalCol)
	y = y + lineH
	DrawBar(x, y, barW, Scale(6), healthFrac, barCol)
	y = y + Scale(6) + Scale(4)

	-- Critical warning — 1.5 Hz pulse.
	if (hasWarn) then
		local pulse = math.abs(math.sin(CurTime() * 1.5))
		DrawShadowText("WARNING: MEDICAL ATTENTION REQUIRED", "ixHUDLabel", x, y, ColorAlpha(HUD_DANGER_COLOR, math.Round(180 + pulse * 75)))
		y = y + lineH
	end

	-- ── STAMINA BAR ───────────────────────────────────────────────────────────
	local stamina     = ply:GetNetVar("stm", ply:GetNetVar("ixStamina", ply:GetNetVar("stamina", -1)))
	local staminaFrac = (stamina >= 0) and math.Clamp(stamina / 100, 0, 1) or 1

	DrawShadowText("STAMINA", "ixHUDLabel", x, y, THEME.textMuted)
	DrawShadowText(math.floor(staminaFrac * 100) .. "%", "ixHUDData", x + Scale(55), y, THEME.accentSoft or THEME.accent)
	y = y + lineH
	DrawBar(x, y, barW, Scale(6), staminaFrac, THEME.accentSoft or THEME.accent)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- WEAPON & AMMUNITION — Bottom Right
-- Fire mode: implied separator line (no box). Ammo: Orbitron replaces OCR-A.
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:DrawWeapon(scrW, scrH, ply, pad)
	local wep = ply:GetActiveWeapon()
	if (!IsValid(wep)) then return end

	local wepClass = wep:GetClass()
	if (wepClass == "ix_fists" or wepClass == "gmod_tool" or wepClass == "weapon_physgun" or wepClass == "gmod_camera") then
		return
	end

	if (!wep.GetCurrentFiremodeTable and !wep.GetCurrentFiremode) then return end

	local panelW = Scale(220)
	local x      = scrW - pad - panelW
	local y      = scrH - pad - Scale(100)
	local lineH  = Scale(14)
	local rightX = scrW - pad

	-- Track start Y for corner notches.
	local startY = y

	-- Weapon name — Roboto label (clearly secondary to ammo/fire mode data below).
	local wepName = string.upper((wep.GetPrintName and wep:GetPrintName()) or wep:GetClass())
	DrawShadowText(wepName, "ixHUDLabel", rightX, y, THEME.textMuted, TEXT_ALIGN_RIGHT)
	y = y + lineH
	DrawImpliedSeparator(rightX - panelW, y, panelW)
	y = y + Scale(6)

	-- ── FIRE MODE ─────────────────────────────────────────────────────────────
	-- 1px implied separator replaces DrawOutlinedRect (VANIR §1 fix).
	local fireMode  = ""
	local isArcWeapon = false

	if (wep.GetCurrentFiremodeTable) then
		isArcWeapon = true
		local fmTable = wep:GetCurrentFiremodeTable()
		if (fmTable) then
			fireMode = fmTable.PrintName or fmTable.Name or ""
			if (fireMode == "" and fmTable.Mode) then
				if     (fmTable.Mode == 1)  then fireMode = "SEMI"
				elseif (fmTable.Mode == 0)  then fireMode = "SAFE"
				elseif (fmTable.Mode <  0)  then fireMode = "AUTO"
				else                             fireMode = tostring(fmTable.Mode) .. "-ROUND"
				end
			end
			fireMode = string.upper(fireMode)
		end
	elseif (wep.GetCurrentFiremode) then
		isArcWeapon = true
		local fm = wep:GetCurrentFiremode()
		if (istable(fm)) then
			fireMode = fm.PrintName or fm.Name or ""
			if (fireMode == "" and fm.Mode) then
				if     (fm.Mode == 1)  then fireMode = "SEMI"
				elseif (fm.Mode == 0)  then fireMode = "SAFE"
				elseif (fm.Mode == 2)  then fireMode = "AUTO"
				elseif (fm.Mode < 0)   then fireMode = "BURST"
				else                        fireMode = tostring(fm.Mode) .. "-ROUND"
				end
			elseif (fireMode == "") then
				fireMode = "SEMI"
			end
			fireMode = string.upper(fireMode)
		elseif (isnumber(fm)) then
			if     (fm == 1)  then fireMode = "SEMI"
			elseif (fm == 0)  then fireMode = "SAFE"
			elseif (fm == 2)  then fireMode = "AUTO"
			elseif (fm < 0)   then fireMode = "BURST"
			else                   fireMode = tostring(fm) .. "-ROUND"
			end
		end
	end

	if (fireMode != "") then
		local fmW = Scale(80)
		local fmH = Scale(24)
		local fmX = rightX - fmW
		local accent = THEME.accent

		if (RNDX) then
			RNDX.Draw(Scale(3), fmX, y, fmW, fmH, Color(0, 0, 0, 170))
			RNDX.DrawOutlined(Scale(3), fmX, y, fmW, fmH, Color(accent.r, accent.g, accent.b, 190), 1)
		else
			surface.SetDrawColor(0, 0, 0, 170)
			surface.DrawRect(fmX, y, fmW, fmH)
			surface.SetDrawColor(accent.r, accent.g, accent.b, 190)
			surface.DrawOutlinedRect(fmX, y, fmW, fmH)
		end

		DrawShadowText(fireMode, "ixHUDData", fmX + Scale(6), y + fmH * 0.5, THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		y = y + fmH + Scale(4)
	else
		y = y + Scale(4)
	end

	-- ── AMMUNITION ───────────────────────────────────────────────────────────
	local clip     = wep:Clip1()
	local maxClip  = wep:GetMaxClip1()
	local ammoType = wep:GetPrimaryAmmoType()
	local reserve  = (ammoType >= 0) and ply:GetAmmoCount(ammoType) or 0
	local usesAmmo = maxClip > 0 or ammoType >= 0

	if (usesAmmo) then
		local isReloading = false
		if (wep.GetReloading) then
			isReloading = wep:GetReloading()
		elseif (wep.Reloading) then
			isReloading = wep.Reloading
		end

		if (isReloading) then
			DrawShadowText("RELOADING...", "ixHUDData", rightX, y + Scale(12), THEME.accent, TEXT_ALIGN_RIGHT)
			y = y + Scale(32)
		elseif (clip == 0 and reserve == 0) then
			DrawShadowText("NO AMMUNITION", "ixHUDData", rightX, y, HUD_DANGER_COLOR, TEXT_ALIGN_RIGHT)
			y = y + lineH + Scale(4)
		else
			-- Large clip count (Orbitron replaces OCR-A 44).
			local clipStr    = clip >= 0 and string.format("%02d", clip) or "--"
			local reserveStr = tostring(reserve)

			DrawShadowText(clipStr, "ixHUDDataLarge", rightX - Scale(44), y, THEME.text, TEXT_ALIGN_RIGHT)
			DrawShadowText("/", "ixHUDData", rightX - Scale(36), y + Scale(12), THEME.textMuted, TEXT_ALIGN_CENTER)
			DrawShadowText(reserveStr, "ixHUDData", rightX, y + Scale(14), THEME.textMuted, TEXT_ALIGN_RIGHT)
			y = y + Scale(38)
		end
	end

	-- ── OVERHEAT BAR ─────────────────────────────────────────────────────────
	local hasHeat = wep.Heat ~= nil or wep.HeatCapacity ~= nil
	if (!hasHeat) then return end

	local heat         = wep.Heat or 0
	local heatCapacity = wep.HeatCapacity or 1
	local heatFrac     = math.Clamp(heat / math.max(heatCapacity, 1), 0, 1)
	local heatCol      = GetHeatColor(heatFrac)
	local heatBarW     = Scale(180)

	y = y - Scale(16)

	DrawShadowText("HEAT", "ixHUDLabel", rightX - heatBarW, y, THEME.textMuted)
	DrawShadowText(math.floor(heatFrac * 100) .. "%", "ixHUDData", rightX - heatBarW + Scale(36), y, heatCol)
	y = y + lineH

	DrawBar(rightX - heatBarW, y, heatBarW, Scale(6), heatFrac, heatCol)

	-- Corner notches: TR at top of weapon content, BR at screen bottom — bracket the column.
	DrawNotch(rightX + Scale(4), startY - Scale(4), "TR")
	DrawNotch(rightX + Scale(4), scrH - pad, "BR")

	-- Overheat warning — 1.5 Hz pulse.
	if (heatFrac >= 0.8) then
		y = y + Scale(10)
		local pulse = math.abs(math.sin(CurTime() * 1.5))
		DrawShadowText("WARNING: COOLING REQUIRED", "ixHUDLabel", rightX, y, ColorAlpha(HUD_DANGER_COLOR, math.Round(180 + pulse * 75)), TEXT_ALIGN_RIGHT)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- LIGHTSABER COMBAT STATUS — Bottom Right
-- Occupies the same slot as the ammo counter; DrawWeapon returns early for
-- LSCS weapons (no GetCurrentFiremodeTable/GetCurrentFiremode), so there is
-- never a conflict. Shows stance, block points, combo hits, and force level.
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:DrawLightsaber(scrW, scrH, ply, pad)
	if (not LSCS) then return end

	local wep = ply:GetActiveWeapon()
	if (not IsValid(wep) or not wep.LSCS) then return end

	local panelW = Scale(220)
	local x      = scrW - pad - panelW
	local y      = scrH - pad - Scale(100)
	local lineH  = Scale(14)
	local rightX = scrW - pad
	local barW   = Scale(180)

	local startY = y

	-- ── DATA GATHERING ────────────────────────────────────────────────────────
	local combo       = wep.GetCombo and wep:GetCombo()
	local stanceName  = (combo and combo.name) and string.upper(combo.name) or "LIGHTSABER"
	local isAutoBlock = combo and combo.AutoBlock

	local blockPoints = (wep.GetBlockPoints    and wep:GetBlockPoints())    or 0
	local maxBP       = (wep.GetMaxBlockPoints  and wep:GetMaxBlockPoints()) or 1
	local comboHits   = (wep.GetComboHits       and wep:GetComboHits())      or 0
	local bpFrac      = math.Clamp(blockPoints / math.max(maxBP, 1), 0, 1)
	local bpCol       = GetBPColor(bpFrac)

	local hasForce  = ply.lscsGetForceAllowed and ply:lscsGetForceAllowed()
	local force     = (hasForce and ply:lscsGetForce())    or 0
	local maxForce  = (hasForce and ply:lscsGetMaxForce()) or 1
	local forceFrac = math.Clamp(force / math.max(maxForce, 1), 0, 1)

	-- ── STANCE NAME (mirrors weapon name row) ─────────────────────────────────
	DrawShadowText(stanceName, "ixHUDLabel", rightX, y, THEME.textMuted, TEXT_ALIGN_RIGHT)
	y = y + lineH
	DrawImpliedSeparator(rightX - panelW, y, panelW)
	y = y + Scale(6)

	-- ── BLOCK POINTS — large fraction display (mirrors ammo clip / reserve) ──
	if (isAutoBlock) then
		local notifyTime = wep.GetBlockPointNotifyTime and wep:GetBlockPointNotifyTime() or 0
		local depleted   = blockPoints <= 1 and notifyTime > CurTime()

		if (depleted) then
			local pulse = math.abs(math.sin(CurTime() * 7.5))
			DrawShadowText("BLOCK DEPLETED", "ixHUDData", rightX, y + Scale(12),
				ColorAlpha(HUD_DANGER_COLOR, math.Round(180 + pulse * 75)), TEXT_ALIGN_RIGHT)
			y = y + Scale(32)
		else
			local bpStr  = string.format("%02d", math.floor(blockPoints))
			local maxStr = tostring(math.floor(maxBP))
			DrawShadowText(bpStr,   "ixHUDDataLarge", rightX - Scale(44), y,           bpCol,          TEXT_ALIGN_RIGHT)
			DrawShadowText("/",     "ixHUDData",       rightX - Scale(36), y + Scale(12), THEME.textMuted, TEXT_ALIGN_CENTER)
			DrawShadowText(maxStr,  "ixHUDData",       rightX,             y + Scale(14), THEME.textMuted, TEXT_ALIGN_RIGHT)
			y = y + Scale(38)
		end
	end

	-- ── COMBO HIT COUNTER ─────────────────────────────────────────────────────
	if (comboHits > 0) then
		DrawShadowText("COMBO  \xC3\x97" .. comboHits, "ixHUDData", rightX, y, THEME.accent, TEXT_ALIGN_RIGHT)
		y = y + lineH + Scale(2)
	end

	-- ── BLOCK POINTS BAR (mirrors heat bar) ──────────────────────────────────
	if (isAutoBlock) then
		DrawShadowText("BLOCK",                            "ixHUDLabel", rightX - barW,           y, THEME.textMuted)
		DrawShadowText(math.floor(bpFrac * 100) .. "%",   "ixHUDData",  rightX - barW + Scale(38), y, bpCol)
		y = y + lineH
		DrawBar(rightX - barW, y, barW, Scale(6), bpFrac, bpCol)
		y = y + Scale(6) + Scale(4)
	end

	-- ── FORCE POWER BAR ───────────────────────────────────────────────────────
	if (hasForce) then
		DrawShadowText("FORCE",                             "ixHUDLabel", rightX - barW,           y, THEME.textMuted)
		DrawShadowText(math.floor(forceFrac * 100) .. "%", "ixHUDData",  rightX - barW + Scale(40), y, lscsForceColor)
		y = y + lineH
		DrawBar(rightX - barW, y, barW, Scale(6), forceFrac, lscsForceColor)
	end

	-- ── CORNER NOTCHES (mirrors weapon panel) ────────────────────────────────
	DrawNotch(rightX + Scale(4), startY - Scale(4), "TR")
	DrawNotch(rightX + Scale(4), scrH - pad,         "BR")
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- LINEAR GRADIENT (Band-based, GPU-friendly)
-- Uses ~24 bands instead of per-pixel for performance.
-- ═══════════════════════════════════════════════════════════════════════════════

local gradientBands = 24

if (!draw.LinearGradient) then
	function draw.LinearGradient(x, y, w, h, stops, isVertical)
		if (!stops or #stops < 2) then return end

		local totalSize = isVertical and h or w
		if (totalSize <= 0) then return end

		local bandCount = math.min(gradientBands, math.max(1, math.floor(totalSize)))
		local bandSize  = totalSize / bandCount

		for i = 0, bandCount - 1 do
			local frac   = (i + 0.5) / bandCount
			local r, g, b, a = 0, 0, 0, 0

			for j = 1, #stops - 1 do
				local s1 = stops[j]
				local s2 = stops[j + 1]

				if (frac >= s1.offset and frac <= s2.offset) then
					local localFrac = (frac - s1.offset) / math.max(s2.offset - s1.offset, 0.001)
					r = Lerp(localFrac, s1.color.r, s2.color.r)
					g = Lerp(localFrac, s1.color.g, s2.color.g)
					b = Lerp(localFrac, s1.color.b, s2.color.b)
					a = Lerp(localFrac, s1.color.a, s2.color.a)
					break
				end
			end

			surface.SetDrawColor(r, g, b, a)

			if (isVertical) then
				local bandY = y + math.floor(i * bandSize)
				surface.DrawRect(x, bandY, w, math.ceil(bandSize))
			else
				local bandX = x + math.floor(i * bandSize)
				surface.DrawRect(bandX, y, math.ceil(bandSize), h)
			end
		end
	end
end
