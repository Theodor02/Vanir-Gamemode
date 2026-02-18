--- Imperial Diegetic HUD - Client Plugin
-- Draws all HUD elements: compass, vitals, weapon, mission status, comms, squad, damage indicators.
-- Uses transparent overlays with minimal borders per the Imperial design spec.

local PLUGIN = PLUGIN

-- ═══════════════════════════════════════════════════════════════════════════════
-- THEME & CONFIG
-- ═══════════════════════════════════════════════════════════════════════════════

local THEME = {
	background = Color(0, 0, 0, 165),
	backgroundStrong = Color(0, 0, 0, 175),
	text = Color(240, 240, 240, 255),
	textMuted = Color(200, 200, 200, 220),
	textDark = Color(155, 155, 155, 200),
	amber = Color(228, 175, 42, 255),
	amberDim = Color(194, 144, 21, 225),
	gold = Color(201, 158, 63, 255),
	cyan = Color(84, 168, 255, 255),
	cyanDim = Color(84, 168, 255, 195),
	green = Color(70, 185, 100, 255),
	greenDim = Color(70, 185, 100, 195),
	yellow = Color(255, 222, 40, 255),
	red = Color(255, 55, 55, 255),
	redDim = Color(230, 30, 70, 215),
	danger = Color(155, 10, 10, 255),
	borderGray = Color(130, 130, 130, 220),
	borderAmber = Color(194, 144, 21, 245),
	borderRed = Color(200, 60, 60, 245),
	borderCyan = Color(84, 168, 255, 245),
	borderGreen = Color(70, 160, 80, 230)
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- SCALING & FONTS
-- ═══════════════════════════════════════════════════════════════════════════════

local function Scale(value)
	return math.max(1, math.Round(value * (ScrH() / 900)))
end

local function CreateFonts()
	-- Serif header font (Imperial formality) - matches impmainmenu
	surface.CreateFont("ixHUDSerif", {
		font = "Times New Roman",
		size = Scale(14),
		weight = 600,
		extended = true,
		antialias = true
	})

	-- Used for priority/objective titles and active transmission speaker names.
	surface.CreateFont("ixHUDSerifLarge", {
		font = "Times New Roman",
		size = Scale(38),
		weight = 600,
		extended = true,
		antialias = true
	})

	-- Monospace technical font (military readouts)
	-- Used for compass labels, waypoint lines, vitals labels, and weapon name/firemode text.
	surface.CreateFont("ixHUDMono", {
		font = "Roboto Condensed",
		size = Scale(11),
		weight = 500,
		extended = true,
		antialias = true
	})

	-- Used for section headers and status lines (mission/comms headers, squad status, warnings).
	surface.CreateFont("ixHUDMonoSmall", {
		font = "Roboto Condensed",
		size = Scale(9),
		weight = 500,
		extended = true,
		antialias = true
	})

	-- Used for vitals percent and ammo reserve/slash.
	surface.CreateFont("ixHUDMonoLarge", {
		font = "Roboto Condensed",
		size = Scale(22),
		weight = 600,
		extended = true,
		antialias = true
	})

	-- Used for the current clip count in the weapon panel.
	surface.CreateFont("ixHUDMonoHuge", {
		font = "Roboto Condensed",
		size = Scale(44),
		weight = 700,
		extended = true,
		antialias = true
	})

	-- Compass bearing font
	-- Used for the large compass bearing number.
	surface.CreateFont("ixHUDBearing", {
		font = "Roboto Condensed",
		size = Scale(36),
		weight = 700,
		extended = true,
		antialias = true
	})

	-- General label font - matches impmainmenu
	-- Currently unused; reserved for future medium label text.
	surface.CreateFont("ixHUDLabel", {
		font = "Roboto",
		size = Scale(12),
		weight = 500,
		extended = true,
		antialias = true
	})

	-- Used for objective descriptions, channel names, squad member names, and small prompts.
	surface.CreateFont("ixHUDLabelSmall", {
		font = "Roboto",
		size = Scale(10),
		weight = 500,
		extended = true,
		antialias = true
	})

	-- Aurebesh decorative font - matches impmainmenu
	-- Currently unused; reserved for larger Aurebesh accents.
	surface.CreateFont("ixHUDAurebesh", {
		font = "Aurebesh",
		size = Scale(10),
		weight = 400,
		extended = true,
		antialias = true
	})

	-- Used for small Aurebesh accents across compass/comms/squad/vitals/weapon.
	surface.CreateFont("ixHUDAurebeshSmall", {
		font = "Aurebesh",
		size = Scale(8),
		weight = 400,
		extended = true,
		antialias = true
	})

	-- Player name font (serif, formal)
	-- Used for the player name in the vitals block.
	surface.CreateFont("ixHUDName", {
		font = "Times New Roman",
		size = Scale(14),
		weight = 600,
		extended = true,
		antialias = true
	})

	-- Used for the class/faction line under the player name.
	surface.CreateFont("ixHUDRank", {
		font = "Roboto",
		size = Scale(11),
		weight = 400,
		extended = true,
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

local RNDX -- resolved after schema libs load

hook.Add("InitPostEntity", "ixDiegeticHUDResolveRNDX", function()
	RNDX = ix.RNDX
end)

timer.Simple(0, function()
	RNDX = ix.RNDX
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- DRAWING UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Pre-allocated shadow colors to avoid per-frame garbage
local shadowColorOuter = Color(0, 0, 0, 180)
local shadowColorInner = Color(0, 0, 0, 230)

--- Draw text with double-layered shadow for readability over any background.
local function DrawShadowText(text, font, x, y, color, alignX, alignY)
	alignX = alignX or TEXT_ALIGN_LEFT
	alignY = alignY or TEXT_ALIGN_TOP

	-- Outer soft shadow (wider offset for glow-like backdrop)
	shadowColorOuter.a = math.min(180, color.a)
	draw.SimpleText(text, font, x + 2, y + 2, shadowColorOuter, alignX, alignY)

	-- Inner crisp shadow
	shadowColorInner.a = math.min(230, color.a)
	draw.SimpleText(text, font, x + 1, y + 1, shadowColorInner, alignX, alignY)

	draw.SimpleText(text, font, x, y, color, alignX, alignY)
end

-- Pre-allocated colors for panel/bar drawing
local panelBgColor = Color(0, 0, 0, 185)
local barBgColor = Color(0, 0, 0, 185)
local barOutlineColor = Color(70, 70, 70, 140)

--- Draw a bordered panel with transparent background and colored left border.
--- Uses RNDX for GPU-accelerated rounded corners when available.
local function DrawPanel(x, y, w, h, borderColor, bgAlpha)
	bgAlpha = bgAlpha or 185
	local cornerR = Scale(4)
	local borderW = Scale(4)

	if (RNDX) then
		-- Rounded background
		panelBgColor.a = bgAlpha
		RNDX.Draw(cornerR, x, y, w, h, panelBgColor)

		-- Left border accent (rounded only on left corners)
		RNDX.Draw(cornerR, x, y, borderW, h, borderColor, RNDX.NO_TR + RNDX.NO_BR)
	else
		-- Fallback: flat rectangles
		surface.SetDrawColor(0, 0, 0, bgAlpha)
		surface.DrawRect(x, y, w, h)

		surface.SetDrawColor(borderColor)
		surface.DrawRect(x, y, borderW, h)
	end
end

--- Draw a horizontal bar (health, stamina, overheat, etc.)
--- Uses RNDX for rounded pill-shaped bars when available.
local function DrawBar(x, y, w, h, fraction, barColor)
	fraction = math.Clamp(fraction, 0, 1)
	local cornerR = math.max(1, math.floor(h * 0.4))

	if (RNDX) then
		-- Rounded background
		barBgColor.a = 185
		RNDX.Draw(cornerR, x, y, w, h, barBgColor)

		-- Rounded fill
		if (fraction > 0) then
			local fillW = math.max(h, w * fraction)
			RNDX.Draw(cornerR, x, y, fillW, h, barColor)
		end
	else
		-- Fallback: flat rectangles
		surface.SetDrawColor(0, 0, 0, 185)
		surface.DrawRect(x, y, w, h)

		surface.SetDrawColor(barOutlineColor)
		surface.DrawOutlinedRect(x, y, w, h)

		if (fraction > 0) then
			surface.SetDrawColor(barColor)
			surface.DrawRect(x, y, w * fraction, h)
		end
	end
end

--- Get color for a health-like value (gold > yellow > red).
local function GetVitalColor(fraction)
	if (fraction > 0.6) then
		return THEME.gold
	elseif (fraction > 0.3) then
		return THEME.yellow
	else
		return THEME.red
	end
end

--- Get bar gradient color for a value.
-- Pre-allocated to avoid per-frame Color() garbage.
local barColorGood = Color(194, 144, 21, 255)
local barColorWarn = Color(210, 190, 30, 255)
local barColorCrit = Color(215, 40, 40, 255)

local function GetBarColor(fraction)
	if (fraction > 0.6) then
		return barColorGood
	elseif (fraction > 0.3) then
		return barColorWarn
	else
		return barColorCrit
	end
end

--- Get overheat color (gold < yellow < red).
local heatColorLow = Color(194, 144, 21, 255)
local heatColorMid = Color(210, 190, 30, 255)
local heatColorHigh = Color(215, 40, 40, 255)

local function GetHeatColor(fraction)
	if (fraction < 0.5) then
		return heatColorLow
	elseif (fraction < 0.8) then
		return heatColorMid
	else
		return heatColorHigh
	end
end

--- Get a directional arrow for a bearing relative to compass.
local BEARING_ARROWS = {"↑", "↗", "→", "↘", "↓", "↙", "←", "↖"}

local function GetBearingArrow(targetBearing, compassBearing)
	local diff = ((targetBearing - compassBearing + 180 + 360) % 360) - 180
	local index = math.floor(((diff + 360 + 22.5) % 360) / 45) + 1

	index = math.Clamp(index, 1, 8)

	return BEARING_ARROWS[index]
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLIENT STATE
-- ═══════════════════════════════════════════════════════════════════════════════

local waypoints = {}
local squadData = {members = {}, designation = ""}
local bogusSquadMembers = {}
local activeTransmission = nil
local forcedTransmission = {
	speaker = "LOCAL",
	channel = "OPEN MIC",
	freq = "0000.0",
	encrypted = true
}
local transmissionEndTime = 0
local damageDirection = nil
local damageEndTime = 0
local vignetteAlpha = 0

-- Comms channels the player has connected to (client-side state for now)
local connectedChannels = {}

-- Available channels definition (will be configurable via API later)
local availableChannels = {
	{id = "cmd", name = "COMMAND NET", freq = "8858.0", encrypted = true},
	{id = "sqd", name = "SQUAD COMMS", freq = "4521.5", encrypted = true},
	{id = "log", name = "LOGISTICS", freq = "7799.2", encrypted = false},
	{id = "emg", name = "EMERGENCY", freq = "3366.8", encrypted = true}
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- NETWORK RECEIVERS
-- ═══════════════════════════════════════════════════════════════════════════════

net.Receive("ixDiegeticWaypoint", function()
	local id = net.ReadString()
	local label = net.ReadString()
	local pos = net.ReadVector()
	local wpType = net.ReadString()

	waypoints[id] = {
		label = label,
		pos = pos,
		type = wpType
	}
end)

net.Receive("ixDiegeticWaypointClear", function()
	local id = net.ReadString()

	waypoints[id] = nil
end)

net.Receive("ixDiegeticSquadSync", function()
	local id = net.ReadString()
	local designation = net.ReadString()
	local count = net.ReadUInt(8)
	local members = {}

	for i = 1, count do
		table.insert(members, {
			steamID = net.ReadString(),
			name = net.ReadString(),
			health = net.ReadUInt(8),
			maxHealth = net.ReadUInt(8),
			pos = net.ReadVector(),
			alive = net.ReadBool()
		})
	end

	squadData.designation = designation
	squadData.members = members
end)

net.Receive("ixDiegeticSquadBogus", function()
	local id = net.ReadString()
	local name = net.ReadString()
	local health = net.ReadUInt(8)
	local maxHealth = net.ReadUInt(8)
	local pos = net.ReadVector()
	local alive = net.ReadBool()

	bogusSquadMembers[id] = {
		steamID = "bogus_" .. id,
		name = name,
		health = health,
		maxHealth = maxHealth,
		pos = pos,
		alive = alive
	}
end)

net.Receive("ixDiegeticCommsTransmission", function()
	local speaker = net.ReadString()
	local channel = net.ReadString()
	local freq = net.ReadString()
	local encrypted = net.ReadBool()
	local duration = net.ReadFloat()

	activeTransmission = {
		speaker = speaker,
		channel = channel,
		freq = freq,
		encrypted = encrypted
	}

	transmissionEndTime = CurTime() + duration

	-- Auto-add channel to connected channels when we receive a transmission on it
	if (!table.HasValue(connectedChannels, channel)) then
		if (#connectedChannels >= 2) then
			table.remove(connectedChannels, 1)
		end

		table.insert(connectedChannels, channel)
	end
end)

net.Receive("ixDiegeticDamageDir", function()
	local attackerPos = net.ReadVector()
	local ply = LocalPlayer()

	if (!IsValid(ply)) then return end

	-- Calculate direction relative to player facing
	local plyPos = ply:GetPos()
	local plyAng = ply:EyeAngles()
	local toAttacker = (attackerPos - plyPos):GetNormalized()
	local forward = plyAng:Forward()
	local right = plyAng:Right()

	local dot = forward:Dot(toAttacker)
	local cross = right:Dot(toAttacker)

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

--- Connect to a comms channel by name (client-side).
-- @string channelName Channel name to connect to
function ix.diegeticHUD.ConnectChannel(channelName)
	if (table.HasValue(connectedChannels, channelName)) then return end

	-- Max 2 channels
	if (#connectedChannels >= 2) then
		table.remove(connectedChannels, 1)
	end

	table.insert(connectedChannels, channelName)
end

--- Disconnect from a comms channel.
-- @string channelName Channel name to disconnect from
function ix.diegeticHUD.DisconnectChannel(channelName)
	for i, name in ipairs(connectedChannels) do
		if (name == channelName) then
			table.remove(connectedChannels, i)
			break
		end
	end
end

--- Disconnect from all comms channels.
function ix.diegeticHUD.DisconnectAllChannels()
	connectedChannels = {}
end

--- Get current connected channels.
-- @treturn table Array of channel name strings
function ix.diegeticHUD.GetConnectedChannels()
	return connectedChannels
end

--- Get available channel definitions.
-- @treturn table Array of channel definition tables
function ix.diegeticHUD.GetAvailableChannels()
	return availableChannels
end

-- Client-side testing concommands
concommand.Add("ix_hud_connect", function(ply, cmd, args)
	if (!args[1]) then
		print("[HUD] Available channels:")
		for _, ch in ipairs(availableChannels) do
			local connected = table.HasValue(connectedChannels, ch.name) and " [CONNECTED]" or ""
			print("  " .. ch.name .. " (" .. ch.freq .. " MHZ)" .. connected)
		end
		return
	end

	local name = table.concat(args, " ")

	ix.diegeticHUD.ConnectChannel(name)
	print("[HUD] Connected to: " .. name)
end)

concommand.Add("ix_hud_disconnect", function(ply, cmd, args)
	if (!args[1]) then
		ix.diegeticHUD.DisconnectAllChannels()
		print("[HUD] Disconnected from all channels.")
		return
	end

	local name = table.concat(args, " ")

	ix.diegeticHUD.DisconnectChannel(name)
	print("[HUD] Disconnected from: " .. name)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- SUPPRESS DEFAULT HUD ELEMENTS
-- ═══════════════════════════════════════════════════════════════════════════════

local hiddenElements = {
	["CHudHealth"] = true,
	["CHudBattery"] = true,
	["CHudAmmo"] = true,
	["CHudSecondaryAmmo"] = true,
	["CHudDamageIndicator"] = true,
	["CHudHistoryResource"] = true,
	["CHudPoisonDamageIndicator"] = true,
	["CHudSquadStatus"] = true,
	["CHUDQuickInfo"] = true
}

function PLUGIN:HUDShouldDraw(element)
	if (hiddenElements[element]) then
		return false
	end
end

-- Suppress Helix's built-in ammo display (blurred boxes at bottom-right)
function PLUGIN:CanDrawAmmoHUD()
	return false
end

-- Suppress Helix's built-in health/armor bars (top-left info bars)
function PLUGIN:ShouldHideBars()
	return true
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- HUD PAINT - MAIN ENTRY
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:HUDPaint()
	local ply = LocalPlayer()

	if (!IsValid(ply) or !ply:Alive()) then return end
	if (IsValid(ix.gui.menu)) then return end -- hide HUD when tab menu is open

	local scrW, scrH = ScrW(), ScrH()
	local pad = Scale(16)

	-- Clear old transmission
	if (activeTransmission and CurTime() > transmissionEndTime) then
		activeTransmission = nil
	end

	-- Clear old damage flash
	if (damageDirection and CurTime() > damageEndTime) then
		damageDirection = nil
	end

	-- Track health for vignette
	local health = ply:Health()
	local maxHealth = ply:GetMaxHealth()
	local healthFrac = math.Clamp(health / math.max(maxHealth, 1), 0, 1)

	-- Smooth vignette
	local targetVignette = (1 - healthFrac) * 0.4

	vignetteAlpha = Lerp(FrameTime() * 3, vignetteAlpha, targetVignette)

	-- ═══════════════════════════════════════════════════════════════════════
	-- DRAW ALL HUD SECTIONS
	-- ═══════════════════════════════════════════════════════════════════════

	self:DrawDamageIndicator(scrW, scrH)
	self:DrawCriticalHealthBorder(scrW, scrH, healthFrac)
	self:DrawCompass(scrW, scrH, ply)
	self:DrawMissionStatus(scrW, scrH, ply, pad)
	self:DrawComms(scrW, scrH, pad)
	self:DrawSquad(scrW, scrH, ply, pad)
	self:DrawVitals(scrW, scrH, ply, pad, healthFrac)
	self:DrawWeapon(scrW, scrH, ply, pad)
	self:DrawVignette(scrW, scrH)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DAMAGE DIRECTION INDICATOR
-- ═══════════════════════════════════════════════════════════════════════════════

-- Pre-allocated gradient colors (reused each frame to avoid GC pressure)
local gradDamageColor = Color(155, 10, 10, 100)
local gradTransparent = Color(0, 0, 0, 0)
local gradVignetteColor = Color(0, 0, 0, 80)

function PLUGIN:DrawDamageIndicator(scrW, scrH)
	if (!damageDirection) then return end

	local alpha = math.Clamp((damageEndTime - CurTime()) / 0.3, 0, 1) * 120
	local h = Scale(120)

	gradDamageColor.a = alpha

	if (damageDirection == "top") then
		draw.LinearGradient(0, 0, scrW, h, {
			{offset = 0, color = gradDamageColor},
			{offset = 1, color = gradTransparent}
		}, true)
	elseif (damageDirection == "bottom") then
		draw.LinearGradient(0, scrH - h, scrW, h, {
			{offset = 0, color = gradTransparent},
			{offset = 1, color = gradDamageColor}
		}, true)
	elseif (damageDirection == "left") then
		draw.LinearGradient(0, 0, h, scrH, {
			{offset = 0, color = gradDamageColor},
			{offset = 1, color = gradTransparent}
		}, false)
	elseif (damageDirection == "right") then
		draw.LinearGradient(scrW - h, 0, h, scrH, {
			{offset = 0, color = gradTransparent},
			{offset = 1, color = gradDamageColor}
		}, false)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CRITICAL HEALTH BORDER
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:DrawCriticalHealthBorder(scrW, scrH, healthFrac)
	if (healthFrac >= 0.2) then return end

	local pulse = math.sin(CurTime() * 3) * 0.5 + 0.5
	local alpha = math.Clamp(pulse * 80, 20, 80)
	local borderW = Scale(2)

	surface.SetDrawColor(139, 0, 0, alpha)
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

	local alpha = math.Clamp(vignetteAlpha * 255, 0, 100)
	local size = scrH * 0.4

	gradVignetteColor.a = alpha

	-- Corner vignettes
	draw.LinearGradient(0, 0, size, size, {
		{offset = 0, color = gradVignetteColor},
		{offset = 1, color = gradTransparent}
	}, false)

	draw.LinearGradient(scrW - size, 0, size, size, {
		{offset = 0, color = gradTransparent},
		{offset = 1, color = gradVignetteColor}
	}, false)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- COMPASS & NAVIGATION (Top Center)
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:DrawCompass(scrW, scrH, ply)
	local ang = ply:EyeAngles()
	local yaw = ang.y % 360

	if (yaw < 0) then yaw = yaw + 360 end

	-- Convert Source engine yaw (0=+X, CCW) to compass bearing (0=N/+Y, CW)
	local bearing = math.floor((-yaw + 90 + 360) % 360)
	local cx = scrW * 0.5
	local topY = Scale(16)

	-- Subtle backdrop behind compass for readability on bright backgrounds
	local backdropW = Scale(180)
	local backdropH = Scale(42)

	-- if (RNDX) then
	-- 	RNDX.Draw(Scale(6), cx - backdropW * 0.5, topY - Scale(4), backdropW, backdropH, Color(0, 0, 0, 120))
	-- else
	-- 	surface.SetDrawColor(0, 0, 0, 100)
	-- 	surface.DrawRect(cx - backdropW * 0.5, topY - Scale(4), backdropW, backdropH)
	-- end

	-- Bearing display
	local brgStr = string.format("%03d", bearing)

	DrawShadowText("BRG", "ixHUDMono", cx - Scale(60), topY + Scale(8), THEME.textDark, TEXT_ALIGN_LEFT)
	DrawShadowText(brgStr .. "°", "ixHUDBearing", cx, topY, THEME.amber, TEXT_ALIGN_CENTER)

	-- Cardinal directions
	local cardX = cx + Scale(55)
	local cardY = topY + Scale(10)
	local cardinals = {
		{label = "N", min = 315, max = 360, min2 = 0, max2 = 45},
		{label = "E", min = 45, max = 135},
		{label = "S", min = 135, max = 225},
		{label = "W", min = 225, max = 315}
	}

	local spacing = Scale(14)

	for i, card in ipairs(cardinals) do
		local active = false

		if (card.min2) then
			active = (bearing >= card.min and bearing < card.max) or (bearing >= card.min2 and bearing < card.max2)
		else
			active = (bearing >= card.min and bearing < card.max)
		end

		local col = active and THEME.amber or THEME.textDark

		DrawShadowText(card.label, "ixHUDMono", cardX + (i - 1) * spacing, cardY, col)
	end

	-- Aurebesh decorative label beneath bearing
	DrawShadowText("navigat", "ixHUDAurebeshSmall", cx, topY - Scale(5), Color(THEME.amber.r, THEME.amber.g, THEME.amber.b, 70), TEXT_ALIGN_CENTER)

	-- Waypoint data below compass
	local wpY = topY + Scale(44)
	local wpCount = 0

	for id, wp in pairs(waypoints) do
		local dist = math.floor(ply:GetPos():Distance(wp.pos) / 52.49) -- Convert Hammer units to meters
		local wpAngle = math.deg(math.atan2(wp.pos.y - ply:GetPos().y, wp.pos.x - ply:GetPos().x))
		local wpBearing = (-wpAngle + 90 + 360) % 360

		local arrow = GetBearingArrow(wpBearing, bearing)
		local isT = wp.type == "THR"
		local prefix = isT and "THR:" or "TGT:"
		local col = isT and THEME.red or THEME.amber
		local prefixCol = THEME.textDark

		local text = string.format("%s  %s  //  %dM %s", prefix, wp.label, dist, arrow)

		DrawShadowText(text, "ixHUDMono", cx, wpY - Scale(8), col, TEXT_ALIGN_CENTER)

		wpY = wpY + Scale(14)
		wpCount = wpCount + 1

		if (wpCount >= 3) then break end
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MISSION STATUS (Top Left) - DEFCON / Objective / Priority Orders
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:DrawMissionStatus(scrW, scrH, ply, pad)
	local x = pad
	local y = pad
	local panelW = Scale(280)
	local lineH = Scale(14)
	local borderW = Scale(4)
	local innerPad = Scale(8)

	local hasPriority = ix.diegeticHUD.HasPriorityOrder()
	local hasObjective = ix.diegeticHUD.HasObjective(ply)
	local defcon = ix.diegeticHUD.GetDEFCON()
	local defconData = ix.diegeticHUD.DEFCON_DATA[defcon]

	-- PRIORITY ORDER (highest priority - red border)
	if (hasPriority) then
		local pText, pIssuer, pDesc = ix.diegeticHUD.GetPriorityOrder()
		local h = Scale(70)

		DrawPanel(x, y, panelW, h, THEME.borderRed, 210)

		local innerX = x + borderW + innerPad
		local innerY = y + innerPad

		DrawShadowText("PRIORITY TRANSMISSION", "ixHUDMonoSmall", innerX, innerY, THEME.red)
		-- Aurebesh accent: right-aligned in panel
		DrawShadowText("transmis", "ixHUDAurebeshSmall", x + panelW - innerPad, innerY + Scale(1), Color(THEME.red.r, THEME.red.g, THEME.red.b, 65), TEXT_ALIGN_RIGHT)

		innerY = innerY + lineH + Scale(1)

		DrawShadowText(pText, "ixHUDSerif", innerX, innerY, Color(255, 200, 200, 245))

		innerY = innerY + Scale(16)

		DrawShadowText(pDesc, "ixHUDLabelSmall", innerX, innerY, THEME.textMuted)

		innerY = innerY + lineH

		DrawShadowText(pIssuer, "ixHUDMonoSmall", innerX, innerY, THEME.textDark)

		y = y + h + Scale(6)
	end

	-- CURRENT OBJECTIVE (amber border)
	if (hasObjective) then
		local oTitle, oDesc = ix.diegeticHUD.GetObjective(ply)
		local h = Scale(50)

		DrawPanel(x, y, panelW, h, THEME.borderAmber, 195)

		local innerX = x + borderW + innerPad
		local innerY = y + innerPad

		DrawShadowText("CURRENT OBJECTIVE", "ixHUDMonoSmall", innerX, innerY, THEME.amber)
		-- Aurebesh accent: right-aligned in panel
		DrawShadowText("mission", "ixHUDAurebeshSmall", x + panelW - innerPad, innerY + Scale(1), Color(THEME.amber.r, THEME.amber.g, THEME.amber.b, 60), TEXT_ALIGN_RIGHT)

		innerY = innerY + lineH - Scale(4)

		DrawShadowText(oTitle, "ixHUDSerif", innerX, innerY, THEME.text)

		innerY = innerY + Scale(16)

		DrawShadowText(oDesc, "ixHUDLabelSmall", innerX, innerY, THEME.textMuted)

		y = y + h + Scale(6)
	end

	-- DEFCON STATUS (always visible, dims when other elements active)
	local defconH = Scale(42)
	local defconAlpha = (hasPriority or hasObjective) and 0.5 or 1.0

	DrawPanel(x, y, panelW, defconH, THEME.borderGray, math.floor(170 * defconAlpha))

	local innerX = x + borderW + innerPad
	local innerY = y + Scale(4)

	-- Large DEFCON number
	local numCol = ColorAlpha(THEME.amber, math.floor(255 * defconAlpha))

	DrawShadowText(tostring(defcon), "ixHUDSerifLarge", innerX + Scale(2), innerY - Scale(2), numCol)

	-- DEFCON label and description
	local labelX = innerX + Scale(36)
	local labelCol = ColorAlpha(THEME.amber, math.floor(220 * defconAlpha))
	local descCol = ColorAlpha(THEME.text, math.floor(200 * defconAlpha))

	DrawShadowText("DEFSTAT " .. (defconData and defconData.threat or "UNKNOWN") .. " - " .. (defconData and defconData.label or ""), "ixHUDMonoSmall", labelX, innerY + Scale(2), labelCol)
	DrawShadowText(defconData and defconData.desc or "", "ixHUDLabelSmall", labelX, innerY + lineH + Scale(4), descCol)

	-- Aurebesh "defense" decoration: right-aligned in panel
	DrawShadowText("defense", "ixHUDAurebeshSmall", x + panelW - innerPad, innerY + Scale(1), Color(THEME.amber.r, THEME.amber.g, THEME.amber.b, math.floor(55 * defconAlpha)), TEXT_ALIGN_RIGHT)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- COMMUNICATIONS PANEL (Top Right)
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:DrawComms(scrW, scrH, pad)
	-- Only show when player conceptually has radio equipment
	-- For now, always show - future radio plugin can control via hasRadio NetVar
	local hasRadio = LocalPlayer():GetNetVar("ixHasRadio", true)

	if (!hasRadio) then return end

	local panelW = Scale(200)
	local x = scrW - pad - panelW
	local y = pad
	local borderW = Scale(4)
	local innerPad = Scale(8)
	local lineH = Scale(14)
	local forceVoiceBox = LocalPlayer():GetNetVar("ixForceVoiceBox", false)
	local txData = activeTransmission

	if (!txData and forceVoiceBox) then
		local ply = LocalPlayer()
		local char = ply.GetCharacter and ply:GetCharacter()

		forcedTransmission.speaker = (char and char:GetName()) or ply:Nick() or "LOCAL"
		txData = forcedTransmission
	end

	-- Active Transmission panel (appears above channels when someone is talking)
	if (txData) then
		local txH = Scale(62)

		-- Pulsing border
		local pulse = math.sin(CurTime() * 4) * 0.3 + 0.7
		local txBorderCol = ColorAlpha(THEME.cyan, math.floor(255 * pulse))

		DrawPanel(x, y, panelW, txH, txBorderCol, 215)

		local innerX = x + borderW + innerPad
		local innerY = y + innerPad

		DrawShadowText("ACTIVE TRANSMISSION", "ixHUDMonoSmall", innerX, innerY, THEME.cyan)

		-- Pulsing indicator dot (right-aligned in panel)
		local dotAlpha = math.floor(255 * pulse)

		surface.SetDrawColor(THEME.cyan.r, THEME.cyan.g, THEME.cyan.b, dotAlpha)
		surface.DrawRect(x + panelW - innerPad - Scale(6), innerY + Scale(2), Scale(6), Scale(6))

		innerY = innerY + lineH - Scale(3)

		-- Speaker portrait placeholder
		local portraitSize = Scale(28)

		if (RNDX) then
			RNDX.Draw(Scale(3), innerX, innerY, portraitSize, portraitSize, Color(20, 20, 20, 200))
			RNDX.DrawOutlined(Scale(3), innerX, innerY, portraitSize, portraitSize, Color(THEME.cyan.r, THEME.cyan.g, THEME.cyan.b, 120), 1)
		else
			surface.SetDrawColor(20, 20, 20, 200)
			surface.DrawRect(innerX, innerY, portraitSize, portraitSize)
			surface.SetDrawColor(THEME.cyan.r, THEME.cyan.g, THEME.cyan.b, 120)
			surface.DrawOutlinedRect(innerX, innerY, portraitSize, portraitSize)
		end

		-- Aurebesh in portrait (centered)
		DrawShadowText("id", "ixHUDAurebeshSmall", innerX + math.floor(portraitSize * 0.5), innerY + math.floor(portraitSize * 0.5), ColorAlpha(THEME.cyan, 140), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		-- Speaker info
		local speakerX = innerX + portraitSize + Scale(8)

		DrawShadowText(txData.speaker, "ixHUDSerif", speakerX, innerY + Scale(2), THEME.text)
		DrawShadowText(txData.channel, "ixHUDMonoSmall", speakerX, innerY + Scale(16), THEME.cyan)

		innerY = innerY + portraitSize + Scale(4)

		-- Encryption + frequency
		local encText = txData.encrypted and "ENCRYPTED" or "UNSECURE"

		DrawShadowText(encText .. " // " .. txData.freq .. " MHZ", "ixHUDMonoSmall", innerX, innerY, THEME.textDark)

		y = y + txH + Scale(4)
	end

	-- Connected Channels panel
	if (#connectedChannels > 0) then
		local channelH = Scale(20) + #connectedChannels * Scale(28)

		DrawPanel(x, y, panelW, channelH, THEME.borderCyan, 185)

		local innerX = x + borderW + innerPad
		local innerY = y + innerPad

		-- Header
		DrawShadowText("COMMS", "ixHUDMonoSmall", innerX, innerY, THEME.cyan)
		-- DrawShadowText(#connectedChannels, "ixHUDMonoSmall", x + panelW - innerPad, innerY, THEME.cyanDim, TEXT_ALIGN_RIGHT)

		-- Aurebesh accent: right-aligned beneath counter
		DrawShadowText("comlink", "ixHUDAurebeshSmall", x + panelW - innerPad, innerY, Color(THEME.cyan.r, THEME.cyan.g, THEME.cyan.b, 55), TEXT_ALIGN_RIGHT)

		innerY = innerY + lineH - Scale(2)

		-- Channel entries
		for _, channelName in ipairs(connectedChannels) do
			local channelData = nil

			for _, ch in ipairs(availableChannels) do
				if (ch.name == channelName) then
					channelData = ch
					break
				end
			end

			local isActive = activeTransmission and activeTransmission.channel == channelName
			local nameCol = isActive and THEME.cyan or THEME.text

			-- Active indicator dot
			if (isActive) then
				local dotPulse = math.sin(CurTime() * 4) * 0.3 + 0.7

				surface.SetDrawColor(THEME.cyan.r, THEME.cyan.g, THEME.cyan.b, math.floor(255 * dotPulse))
				surface.DrawRect(innerX, innerY + Scale(3), Scale(5), Scale(5))
			end

			local textX = isActive and (innerX + Scale(8)) or innerX

			DrawShadowText(channelName, "ixHUDLabelSmall", textX, innerY, nameCol)

			if (channelData and channelData.encrypted) then
				DrawShadowText("ENC", "ixHUDMonoSmall", x + panelW - innerPad - Scale(18), innerY, THEME.cyanDim)
			end

			innerY = innerY + lineH

			if (channelData) then
				DrawShadowText(channelData.freq .. " MHZ", "ixHUDMonoSmall", textX + Scale(8), innerY, THEME.textDark)
			end

			innerY = innerY + lineH
		end
	else
		-- No channels connected prompt
		local h = Scale(42)

		DrawPanel(x, y, panelW, h, THEME.borderGray, 175)

		local innerX = x + borderW + innerPad
		local innerY = y + innerPad

		DrawShadowText("COMMS", "ixHUDMonoSmall", innerX, innerY, THEME.textDark)
		DrawShadowText("comlink", "ixHUDAurebeshSmall", x + panelW - innerPad, innerY + Scale(1), Color(140, 140, 140, 45), TEXT_ALIGN_RIGHT)

		innerY = innerY + lineH + Scale(2)

		DrawShadowText("No active channels", "ixHUDLabelSmall", innerX, innerY, THEME.textDark)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SQUAD / FIRETEAM PANEL (Left Mid)
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:DrawSquad(scrW, scrH, ply, pad)
	if (!ix.diegeticHUD.IsInSquad(ply)) then return end

	local x = pad
	local y = scrH * 0.33
	local panelW = Scale(220)
	local borderW = Scale(4)
	local innerPad = Scale(8)
	local lineH = Scale(14)

	local members = {}

	for _, member in ipairs(squadData.members) do
		table.insert(members, member)
	end

	for _, member in pairs(bogusSquadMembers) do
		table.insert(members, member)
	end

	if (#members == 0) then return end
	local memberH = Scale(40)
	local totalH = Scale(28) + #members * memberH - Scale(38)

	DrawPanel(x, y, panelW, totalH, THEME.borderGreen, 185)

	local innerX = x + borderW + innerPad
	local innerY = y + innerPad

	-- Header
	DrawShadowText(squadData.designation or "FIRETEAM", "ixHUDMonoSmall", innerX, innerY, THEME.green)
	-- Aurebesh: right-aligned in panel
	DrawShadowText("squad", "ixHUDAurebeshSmall", x + panelW - innerPad, innerY + Scale(1), Color(THEME.green.r, THEME.green.g, THEME.green.b, 55), TEXT_ALIGN_RIGHT)

	innerY = innerY + lineH + Scale(6)

	-- Members
	local myPos = ply:GetPos()
	local myAng = ply:EyeAngles()
	local myYaw = (-myAng.y + 90 + 360) % 360

	for _, member in ipairs(members) do
		-- Skip self
		if (member.steamID == ply:SteamID64()) then continue end

		local healthFrac = math.Clamp(member.health / math.max(member.maxHealth, 1), 0, 1)
		local barColor = GetBarColor(healthFrac)
		local dist = math.floor(myPos:Distance(member.pos) / 52.49) -- Convert Hammer units to meters

		-- Calculate bearing
		local toMember = (member.pos - myPos):GetNormalized()
		local memberAngle = math.deg(math.atan2(toMember.y, toMember.x))
		local memberBearing = (-memberAngle + 90 + 360) % 360

		local arrow = GetBearingArrow(memberBearing, myYaw)

		-- Status text
		local status = "ACTIVE"
		local statusCol = THEME.gold

		if (!member.alive) then
			status = "KIA"
			statusCol = THEME.red
		elseif (healthFrac < 0.3) then
			status = "WOUNDED"
			statusCol = THEME.red
		elseif (healthFrac < 0.7) then
			status = "INJURED"
			statusCol = THEME.yellow
		end

		-- Rank badge placeholder
		local badgeSize = Scale(22)

		if (RNDX) then
			RNDX.Draw(Scale(3), innerX, innerY, badgeSize, badgeSize, Color(20, 20, 20, 200))
			RNDX.DrawOutlined(Scale(3), innerX, innerY, badgeSize, badgeSize, Color(90, 90, 90, 120), 1)
		else
			surface.SetDrawColor(20, 20, 20, 200)
			surface.DrawRect(innerX, innerY, badgeSize, badgeSize)
			surface.SetDrawColor(90, 90, 90, 120)
			surface.DrawOutlinedRect(innerX, innerY, badgeSize, badgeSize)
		end

		-- Aurebesh rank marker (centered in badge)
		DrawShadowText("rk", "ixHUDAurebeshSmall", innerX + math.floor(badgeSize * 0.5), innerY + math.floor(badgeSize * 0.5), Color(THEME.textDark.r, THEME.textDark.g, THEME.textDark.b, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		-- Name
		local nameX = innerX + badgeSize + Scale(6)

		DrawShadowText(member.name, "ixHUDLabelSmall", nameX, innerY, THEME.text)

		-- Health bar
		local barY = innerY + lineH
		local barW = panelW - borderW - innerPad * 2 - badgeSize - Scale(6) - Scale(50)

		DrawBar(nameX, barY, barW, Scale(4), healthFrac, barColor)

		-- Status
		DrawShadowText(status, "ixHUDMonoSmall", nameX + barW + Scale(6), barY - Scale(2), statusCol)

		-- Distance & bearing
		DrawShadowText(dist .. "M // " .. arrow, "ixHUDMonoSmall", nameX, barY + Scale(6), THEME.textDark)

		innerY = innerY + memberH
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- PLAYER VITALS (Bottom Left)
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:DrawVitals(scrW, scrH, ply, pad, healthFrac)
	local char = ply:GetCharacter()

	if (!char) then return end

	local x = pad
	local y = scrH - pad - Scale(100)
	local barW = Scale(200)
	local lineH = Scale(14)

	-- Player identity
	local charName = char:GetName() or "UNKNOWN"
	local faction = team.GetName(ply:Team()) or "Unknown"
	local className = ""

	local classID = char:GetClass()

	if (classID and classID > 0 and ix.class.list[classID]) then
		className = ix.class.list[classID].name or ""
	end

	local rankLine = className != "" and (className .. " // " .. faction) or faction

	DrawShadowText(charName, "ixHUDName", x, y, THEME.text)

	y = y + Scale(16)

	DrawShadowText(rankLine, "ixHUDRank", x, y, THEME.textMuted)

	y = y + Scale(16)

	-- Aurebesh personnel decoration (subtle, below rank line)
	DrawShadowText("personnel ident", "ixHUDAurebeshSmall", x, y, Color(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b, 50))

	y = y + Scale(10)

	-- VITALS bar
	local health = ply:Health()
	local maxHealth = ply:GetMaxHealth()
	local vitalCol = GetVitalColor(healthFrac)
	local barCol = GetBarColor(healthFrac)
	local pct = math.floor(healthFrac * 100)

	DrawShadowText("VITALS", "ixHUDMono", x, y + Scale(6), THEME.textDark)
	DrawShadowText(pct .. "%", "ixHUDMonoLarge", x + Scale(50), y - Scale(2), vitalCol)

	y = y + Scale(20)

	DrawBar(x, y, barW, Scale(8), healthFrac, barCol)

	-- Aurebesh "biometrics" right-aligned beside health bar
	DrawShadowText("biometrics", "ixHUDAurebeshSmall", x + barW + Scale(8), y, Color(vitalCol.r, vitalCol.g, vitalCol.b, 45))

	-- Critical health warning
	if (healthFrac < 0.3) then
		y = y + Scale(12)

		local pulse = math.sin(CurTime() * 4) * 0.3 + 0.7

		DrawShadowText("WARNING: MEDICAL ATTENTION REQUIRED", "ixHUDMonoSmall", x, y, ColorAlpha(THEME.red, math.floor(255 * pulse)))
	end

	y = y + Scale(14)

	-- STAMINA bar
	local staminaFrac = 1

	-- Read stamina from Helix NetVar (default plugin uses "stm", check common alternatives)
	local stamina = ply:GetNetVar("stm", ply:GetNetVar("ixStamina", ply:GetNetVar("stamina", -1)))

	if (stamina >= 0) then
		staminaFrac = math.Clamp(stamina / 100, 0, 1)
	end

	DrawShadowText("STAMINA", "ixHUDMono", x, y, THEME.textDark)
	DrawShadowText(math.floor(staminaFrac * 100) .. "%", "ixHUDMono", x + Scale(55), y, THEME.amberDim)
	
	y = y + lineH
	-- Aurebesh "endurance" right-aligned beside stamina bar
	DrawShadowText("endurance", "ixHUDAurebeshSmall", x + barW + Scale(8), y - Scale(1), Color(THEME.amberDim.r, THEME.amberDim.g, THEME.amberDim.b, 45))

	DrawBar(x, y, barW, Scale(5), staminaFrac, THEME.amberDim)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- WEAPON & AMMUNITION (Bottom Right)
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:DrawWeapon(scrW, scrH, ply, pad)
	local wep = ply:GetActiveWeapon()

	if (!IsValid(wep)) then return end

	-- Don't show for fists/physgun/toolgun etc.
	local wepClass = wep:GetClass()

	if (wepClass == "ix_fists" or wepClass == "gmod_tool" or wepClass == "weapon_physgun" or wepClass == "gmod_camera") then
		return
	end

	-- Only show weapon display for ArcCW and ARC9 weapons
	if (!wep.GetCurrentFiremodeTable and !wep.GetCurrentFiremode) then
		return
	end

	local x = scrW - pad - Scale(220)
	local y = scrH - pad - Scale(100)
	local lineH = Scale(14)
	local panelW = Scale(220)

	-- Weapon name
	local wepName = (wep.GetPrintName and wep:GetPrintName()) or wep:GetClass()

	wepName = string.upper(wepName)

	DrawShadowText(wepName, "ixHUDMono", scrW - pad, y, THEME.textDark, TEXT_ALIGN_RIGHT)

	y = y + lineH

	-- Aurebesh weapon designation (beneath weapon name, right-aligned)
	DrawShadowText("weapon sys", "ixHUDAurebeshSmall", scrW - pad, y, Color(THEME.textDark.r, THEME.textDark.g, THEME.textDark.b, 45), TEXT_ALIGN_RIGHT)

	y = y + Scale(10)

	-- Fire mode (ARC9 and ArcCW only)
	local fireMode = ""
	local isArcWeapon = false

	if (wep.GetCurrentFiremodeTable) then
		-- ARC9 style
		isArcWeapon = true
		local fmTable = wep:GetCurrentFiremodeTable()

		if (fmTable) then
			fireMode = fmTable.PrintName or fmTable.Name or ""
			if (fireMode == "" and fmTable.Mode) then
				-- Fallback to mode number/type
				if (fmTable.Mode == 1) then
					fireMode = "SEMI"
				elseif (fmTable.Mode == 0) then
					fireMode = "SAFE"
				elseif (fmTable.Mode < 0) then
					fireMode = "AUTO"
				else
					fireMode = tostring(fmTable.Mode) .. "-ROUND"
				end
			end
			fireMode = string.upper(fireMode)
		end
	elseif (wep.GetCurrentFiremode) then
		-- ArcCW classic style
		isArcWeapon = true
		local fm = wep:GetCurrentFiremode()
		
		-- Handle if fm itself is a table (direct firemode data)
		if (istable(fm)) then
			fireMode = fm.PrintName or fm.Name or ""
			
			if (fireMode == "" and fm.Mode) then
				if (fm.Mode == 1) then
					fireMode = "SEMI"
				elseif (fm.Mode == 0) then
					fireMode = "SAFE"
				elseif (fm.Mode == 2) then
					fireMode = "AUTO"
				elseif (fm.Mode < 0) then
					fireMode = "BURST"
				else
					fireMode = tostring(fm.Mode) .. "-ROUND"
				end
			elseif (fireMode == "") then
				-- Last fallback - use mode index only if it's a number
				fireMode = isnumber(fm) and ("MODE " .. fm) or "ACTIVE"
			end
			
			fireMode = string.upper(fireMode)
		elseif (fm and wep.Firemodes and wep.Firemodes[fm]) then
			local fmData = wep.Firemodes[fm]
			fireMode = fmData.PrintName or fmData.Name or ""
			
			if (fireMode == "" and fmData.Mode) then
				-- Fallback to mode interpretation
				if (fmData.Mode == 1) then
					fireMode = "SEMI"
				elseif (fmData.Mode == 0) then
					fireMode = "SAFE"
				elseif (fmData.Mode == 2) then
					fireMode = "AUTO"
				elseif (fmData.Mode < 0) then
					fireMode = "BURST"
				else
					fireMode = tostring(fmData.Mode) .. "-ROUND"
				end
			elseif (fireMode == "") then
				-- Last fallback - use mode index only if it's a number
				fireMode = isnumber(fm) and ("MODE " .. fm) or "ACTIVE"
			end
			
			fireMode = string.upper(fireMode)
		elseif (isnumber(fm)) then
			-- Numeric mode index without firemode table
			fireMode = "MODE " .. fm
		end
	end

	if (isArcWeapon and fireMode != "") then
		-- Fire mode box
		surface.SetFont("ixHUDMono")

		local fmW, fmH = surface.GetTextSize(fireMode)

		fmW = fmW + Scale(12)
		fmH = fmH + Scale(4)

		local fmX = scrW - pad - fmW
		local fmR = Scale(3)

		if (RNDX) then
			RNDX.Draw(fmR, fmX, y + Scale(10), fmW, fmH, Color(0, 0, 0, 170))
			RNDX.DrawOutlined(fmR, fmX, y + Scale(10), fmW, fmH, Color(THEME.amber.r, THEME.amber.g, THEME.amber.b, 190), 1)
		else
			surface.SetDrawColor(0, 0, 0, 170)
			surface.DrawRect(fmX, y + Scale(10), fmW, fmH)
			surface.SetDrawColor(THEME.amber.r, THEME.amber.g, THEME.amber.b, 190)
			surface.DrawOutlinedRect(fmX, y + Scale(10), fmW, fmH)
		end
		
		DrawShadowText(fireMode, "ixHUDMono", fmX + Scale(6), y + Scale(12), THEME.amber)

		y = y + fmH + Scale(4)
	else
		y = y + Scale(4)
	end

	-- Ammunition display
	local clip = wep:Clip1()
	local maxClip = wep:GetMaxClip1()
	local ammoType = wep:GetPrimaryAmmoType()
	local reserve = (ammoType >= 0) and ply:GetAmmoCount(ammoType) or 0

	-- Check if weapon uses ammo
	local usesAmmo = maxClip > 0 or ammoType >= 0

	if (usesAmmo) then
		-- Check for reloading
		local isReloading = false

		if (wep.GetReloading) then
			isReloading = wep:GetReloading()
		elseif (wep.Reloading) then
			isReloading = wep.Reloading
		end

		if (isReloading) then
			DrawShadowText("RELOADING...", "ixHUDMono", scrW - pad, y + Scale(25), THEME.amber, TEXT_ALIGN_RIGHT)

			y = y + Scale(32)

			-- Reload progress bar
			-- local barW = Scale(180)

			-- DrawBar(scrW - pad - barW, y, barW, Scale(6), 0.6, THEME.amberDim)

			y = y + Scale(12)
		elseif (clip == 0 and reserve == 0) then
			DrawShadowText("NO AMMUNITION", "ixHUDMono", scrW - pad, y, THEME.red, TEXT_ALIGN_RIGHT)

			y = y + lineH + Scale(4)
		else
			-- Large ammo count
			local clipStr = clip >= 0 and string.format("%02d", clip) or "--"
			local reserveStr = tostring(reserve)

			DrawShadowText(clipStr, "ixHUDMonoHuge", scrW - pad - Scale(60), y, THEME.text, TEXT_ALIGN_RIGHT)
			DrawShadowText("/", "ixHUDMonoLarge", scrW - pad - Scale(44), y + Scale(10), THEME.textDark, TEXT_ALIGN_CENTER)
			DrawShadowText(reserveStr, "ixHUDMonoLarge", scrW - pad, y + Scale(12), THEME.textMuted, TEXT_ALIGN_RIGHT)

			y = y + Scale(44)
		end
	end

	-- Overheat bar (ArcCW / ARC9 heat system) - only show for weapons that use heat
	local hasHeat = wep.Heat ~= nil or wep.HeatCapacity ~= nil

	if (!hasHeat) then return end

	local heat = wep.Heat or 0
	local heatCapacity = wep.HeatCapacity or 1
	local heatFrac = math.Clamp(heat / math.max(heatCapacity, 1), 0, 1)
	local heatCol = GetHeatColor(heatFrac)

	y = y - Scale(16)

	DrawShadowText("HEAT", "ixHUDMonoSmall", scrW - pad - Scale(180), y, THEME.textDark, TEXT_ALIGN_LEFT)
	DrawShadowText(math.floor(heatFrac * 100) .. "%", "ixHUDMonoSmall", scrW - pad - Scale(140), y, heatCol, TEXT_ALIGN_LEFT)

	y = y + lineH

	local heatBarW = Scale(180)

	DrawBar(scrW - pad - heatBarW, y, heatBarW, Scale(5), heatFrac, heatCol)

	-- Overheat warning
	if (heatFrac >= 0.8) then
		y = y + Scale(8)

		local pulse = math.sin(CurTime() * 4) * 0.3 + 0.7

		DrawShadowText("WARNING: COOLING REQUIRED", "ixHUDMonoSmall", scrW - pad, y, ColorAlpha(THEME.red, math.floor(255 * pulse)), TEXT_ALIGN_RIGHT)
	end
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
		local bandSize = totalSize / bandCount

		for i = 0, bandCount - 1 do
			local frac = (i + 0.5) / bandCount

			-- Interpolate between stops
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
				local bandH = math.ceil(bandSize)

				surface.DrawRect(x, bandY, w, bandH)
			else
				local bandX = x + math.floor(i * bandSize)
				local bandW = math.ceil(bandSize)

				surface.DrawRect(bandX, y, bandW, h)
			end
		end
	end
end
