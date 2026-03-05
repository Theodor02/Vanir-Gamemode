--- Imperial Comms System - Client Plugin
-- Handles client-side state, networking, console commands, keybind support,
-- audio cue playback, and integration with the diegetic HUD comms panel.
-- Primary keybinds: +ixcomms_talk (PTT), +ixcomms_menu (channel selector GUI).

local PLUGIN = PLUGIN

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLIENT STATE
-- ═══════════════════════════════════════════════════════════════════════════════

local lply = nil -- set in InitPostEntity

-- Per-player comms state
local activeChannel = 0
local isTalking = false
local mutedChannels = {}
local lastStartTime = 0
local lastStopTime = 0
local lastUsedChannel = 0

-- Incoming transmissions being displayed {[steamID64] = {ply, chanID, startTime}}
local incomingTransmissions = {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:InitPostEntity()
	lply = LocalPlayer()
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SOUND UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════════

--- Play a random variant of a sound from a list.
-- @table variants Array of sound paths
-- @number vol Volume (0-1)
local function PlayRandomSound(variants, vol)
	if (!variants or #variants == 0) then return end

	local snd = variants[math.random(#variants)]

	surface.PlaySound(snd)
end

--- Play a named config sound.
-- @string key Sound key from ix.comms.config.sounds
local function PlayConfigSound(key)
	local path = ix.comms.config.sounds[key]

	if (path and path != "") then
		surface.PlaySound(path)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- PUBLIC CLIENT API
-- ═══════════════════════════════════════════════════════════════════════════════

--- Get the local player's active transmit channel ID.
-- @treturn int Channel ID (0 = off)
function ix.comms.GetActiveChannel()
	return activeChannel
end

--- Check if the local player is currently transmitting.
-- @treturn bool
function ix.comms.IsTalking()
	return isTalking
end

--- Check if a channel is muted locally.
-- @int chanID Channel index
-- @treturn bool
function ix.comms.IsChannelMuted(chanID)
	return mutedChannels[chanID] or false
end

--- Get the full muted channels table.
-- @treturn table {[chanID] = bool}
function ix.comms.GetMutedChannels()
	return mutedChannels
end

--- Get all currently active incoming transmissions.
-- @treturn table {[steamID64] = {ply, chanID, startTime}}
function ix.comms.GetIncomingTransmissions()
	return incomingTransmissions
end

--- Request to change the active transmit channel.
-- @int chanID New channel ID (0 to deactivate)
function ix.comms.ChangeActiveChannel(chanID)
	net.Start("ixComms_ChangeChannel")
		net.WriteUInt(chanID, ix.comms.channelBitSize)
	net.SendToServer()
end

--- Request to mute/unmute a channel.
-- @int chanID Channel ID
-- @bool muted Whether to mute
function ix.comms.ChangeMuteStatus(chanID, muted)
	net.Start("ixComms_MuteChannel")
		net.WriteUInt(chanID, ix.comms.channelBitSize)
		net.WriteBool(muted)
	net.SendToServer()
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- NETWORK RECEIVERS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Someone started transmitting on a channel we can hear
net.Receive("ixComms_IncomingStart", function()
	local chanID = net.ReadUInt(ix.comms.channelBitSize)
	local steamID = net.ReadString()
	local sender = player.GetBySteamID64(steamID)

	if (!IsValid(sender)) then return end
	if (!lply) then lply = LocalPlayer() end
	if (sender == lply) then return end -- Don't show self

	-- Check if muted (but possibly show dimmed notification)
	if (mutedChannels[chanID] and !ix.comms.config.showMutedNotifications) then return end

	-- Play incoming transmission sound
	if (!mutedChannels[chanID] and ix.comms.config.incomingTransmissionSounds) then
		PlayRandomSound(ix.comms.config.txStartVariants, ix.comms.config.cueVolume)
	end

	-- Store in active transmissions
	incomingTransmissions[steamID] = {
		ply = sender,
		chanID = chanID,
		startTime = SysTime(),
		muted = mutedChannels[chanID] or false
	}

	-- Remove the default voice chat panel for this player
	if (IsValid(g_VoicePanelList)) then
		for _, pnl in ipairs(g_VoicePanelList:GetChildren()) do
			if (pnl.ply == sender) then
				pnl:Remove()
				break
			end
		end
	end

	-- Sync with diegetic HUD connected channels
	if (ix.diegeticHUD) then
		local chan = ix.comms.channels[chanID]

		if (chan and !mutedChannels[chanID]) then
			ix.diegeticHUD.ConnectChannel(chan.Name)
		end
	end
end)

-- Someone stopped transmitting
net.Receive("ixComms_IncomingStop", function()
	local chanID = net.ReadUInt(ix.comms.channelBitSize)
	local steamID = net.ReadString()
	local sender = player.GetBySteamID64(steamID)

	if (mutedChannels[chanID] and !ix.comms.config.showMutedNotifications) then
		incomingTransmissions[steamID] = nil
		return
	end

	-- Play stop sound
	if (!mutedChannels[chanID] and ix.comms.config.incomingTransmissionSounds) then
		PlayRandomSound(ix.comms.config.txStopVariants, ix.comms.config.cueVolume)
	end

	-- Remove after a short delay (allows the stop sound to play and HUD to animate out)
	timer.Simple(0.25, function()
		incomingTransmissions[steamID] = nil
	end)
end)

-- Server confirmed our channel change
net.Receive("ixComms_ChangeChannelFeedback", function()
	local chanID = net.ReadUInt(ix.comms.channelBitSize)
	local accepted = net.ReadBool()

	if (accepted) then
		local oldChannel = activeChannel
		activeChannel = chanID

		if (chanID != 0) then
			PlayConfigSound("channelSwitch")

			-- Auto-unmute the channel we switched to (if it was muted)
			if (mutedChannels[chanID]) then
				ix.comms.ChangeMuteStatus(chanID, false)
			end
		else
			if (oldChannel != 0) then
				PlayConfigSound("channelDeactivate")
			end
		end

		-- Update diegetic HUD connected channels
		if (ix.diegeticHUD and chanID != 0) then
			local chan = ix.comms.channels[chanID]

			if (chan) then
				ix.diegeticHUD.ConnectChannel(chan.Name)
			end
		end
	else
		PlayConfigSound("error")
	end

	hook.Run("ixCommsChannelChangedClient", chanID, accepted)
end)

-- Server confirmed mute/unmute
net.Receive("ixComms_MuteChannelFeedback", function()
	local chanID = net.ReadUInt(ix.comms.channelBitSize)
	local muted = net.ReadBool()

	mutedChannels[chanID] = muted

	-- If we muted a channel, remove it from diegetic HUD connected channels
	if (ix.diegeticHUD and muted) then
		local chan = ix.comms.channels[chanID]

		if (chan) then
			ix.diegeticHUD.DisconnectChannel(chan.Name)
		end
	end
end)

-- Full state sync from server (reconnect / team change)
net.Receive("ixComms_FullSync", function()
	activeChannel = net.ReadUInt(ix.comms.channelBitSize)

	local count = net.ReadUInt(ix.comms.channelBitSize)

	for chanID = 1, count do
		mutedChannels[chanID] = net.ReadBool()
	end

	-- Rebuild diegetic HUD channels
	if (ix.diegeticHUD) then
		ix.diegeticHUD.DisconnectAllChannels()

		-- Add all non-muted listening channels
		if (!lply) then lply = LocalPlayer() end

		for chanID, ch in ipairs(ix.comms.channels) do
			if (!mutedChannels[chanID] and ix.comms.CanListen(lply, chanID)) then
				ix.diegeticHUD.ConnectChannel(ch.Name)
			end
		end
	end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- CONSOLE COMMANDS & KEYBINDS
-- ═══════════════════════════════════════════════════════════════════════════════

-- +ixcomms_talk / -ixcomms_talk: Hold-to-talk on radio
concommand.Add("+ixcomms_talk", function(ply, cmd, args)
	if (!lply) then lply = LocalPlayer() end

	-- Enable voice recording
	if (permissions and permissions.EnableVoiceChat) then
		permissions.EnableVoiceChat(true)
	else
		lply:ConCommand("+voicerecord")
	end

	-- Validate active channel
	if (activeChannel == 0) then
		lply:ConCommand("-voicerecord")
		return
	end

	local chan = ix.comms.channels[activeChannel]

	if (!chan) then
		lply:ConCommand("-voicerecord")
		return
	end

	if (!ix.comms.CanTalk(lply, activeChannel)) then
		lply:ConCommand("-voicerecord")
		return
	end

	isTalking = true
	lastStartTime = SysTime()

	-- Play outgoing TX sound
	if (ix.comms.config.outgoingTransmissionSounds) then
		PlayRandomSound(ix.comms.config.txStartVariants, ix.comms.config.cueVolume)
	end

	-- Tell server we're transmitting
	net.Start("ixComms_StartTalking")
	net.SendToServer()

	-- Remove default voice panel for self
	if (IsValid(g_VoicePanelList)) then
		for _, pnl in ipairs(g_VoicePanelList:GetChildren()) do
			if (pnl.ply == lply) then
				pnl:Remove()
				break
			end
		end
	end

	-- Delayed second removal (for race condition with voice panel creation)
	timer.Simple(RealFrameTime() * 3, function()
		if (IsValid(g_VoicePanelList)) then
			for _, pnl in ipairs(g_VoicePanelList:GetChildren()) do
				if (pnl.ply == lply) then
					pnl:Remove()
					break
				end
			end
		end
	end)

	-- Tell diegetic HUD we're transmitting
	if (lply and lply.SetNetVar) then
		-- Force the voicebox display
		lply:SetNetVar("ixForceVoiceBox", true)
	end
end)

concommand.Add("-ixcomms_talk", function(ply, cmd, args)
	if (!lply) then lply = LocalPlayer() end

	-- Disable voice recording
	if (permissions and permissions.EnableVoiceChat) then
		permissions.EnableVoiceChat(false)
	else
		lply:ConCommand("-voicerecord")
	end

	if (activeChannel == 0) then return end

	local chan = ix.comms.channels[activeChannel]

	if (!chan or !ix.comms.CanTalk(lply, activeChannel)) then return end

	isTalking = false
	lastStopTime = SysTime()

	-- Play outgoing stop sound
	if (ix.comms.config.outgoingTransmissionSounds) then
		PlayRandomSound(ix.comms.config.txStopVariants, ix.comms.config.cueVolume)
	end

	-- Tell server we stopped
	net.Start("ixComms_StopTalking")
	net.SendToServer()

	-- Clear voicebox display
	if (lply and lply.SetNetVar) then
		lply:SetNetVar("ixForceVoiceBox", false)
	end
end)

-- Switch to a channel by name
concommand.Add("ixcomms_switch", function(ply, cmd, args)
	if (!args[1]) then
		print("[ixComms] Usage: ixcomms_switch <channel name>")
		print("[ixComms] Available channels:")

		if (!lply) then lply = LocalPlayer() end

		for id, ch in ipairs(ix.comms.channels) do
			if (ix.comms.HasAccess(lply, id)) then
				local status = ""

				if (activeChannel == id) then
					status = " [ACTIVE]"
				elseif (mutedChannels[id]) then
					status = " [MUTED]"
				end

				print(string.format("  [%d] %s - %s MHZ%s", id, ch.Name, ch.Frequency, status))
			end
		end
		return
	end

	local name = table.concat(args, " ")
	local chanID, chan = ix.comms.GetChannelByName(name)

	if (!chanID) then
		-- Try numeric ID
		local numID = tonumber(name)

		if (numID and ix.comms.channels[numID]) then
			chanID = numID
			chan = ix.comms.channels[numID]
		else
			print("[ixComms] Channel not found: " .. name)
			return
		end
	end

	if (!lply) then lply = LocalPlayer() end

	if (!ix.comms.HasAccess(lply, chanID)) then
		print("[ixComms] No access to channel: " .. chan.Name)
		return
	end

	-- Unmute if muted
	if (mutedChannels[chanID]) then
		ix.comms.ChangeMuteStatus(chanID, false)
	end

	-- Switch
	if (activeChannel == chanID) then
		print("[ixComms] Already on " .. chan.Name)
		return
	end

	ix.comms.ChangeActiveChannel(chanID)
	print("[ixComms] Switched to: " .. chan.Name .. " (" .. chan.Frequency .. " MHZ)")
end)

-- Toggle active channel on/off
concommand.Add("ixcomms_toggle", function(ply, cmd, args)
	if (activeChannel == 0) then
		-- Reactivate last used channel
		if (lastUsedChannel != 0 and ix.comms.channels[lastUsedChannel]) then
			if (mutedChannels[lastUsedChannel]) then
				ix.comms.ChangeMuteStatus(lastUsedChannel, false)
			end

			ix.comms.ChangeActiveChannel(lastUsedChannel)
			print("[ixComms] Reactivated: " .. ix.comms.channels[lastUsedChannel].Name)
		else
			print("[ixComms] No previous channel to reactivate.")
		end
	else
		lastUsedChannel = activeChannel
		ix.comms.ChangeActiveChannel(0)
		print("[ixComms] Radio deactivated.")
	end
end)

-- Toggle mute on current/last channel
concommand.Add("ixcomms_togglemute", function(ply, cmd, args)
	if (activeChannel != 0) then
		-- Mute current channel and deactivate
		print("[ixComms] Muted: " .. ix.comms.channels[activeChannel].Name)
		lastUsedChannel = activeChannel
		ix.comms.ChangeMuteStatus(activeChannel, true)
		ix.comms.ChangeActiveChannel(0)
	elseif (lastUsedChannel != 0 and mutedChannels[lastUsedChannel]) then
		-- Unmute and reactivate last channel
		local ch = ix.comms.channels[lastUsedChannel]

		if (ch) then
			ix.comms.ChangeMuteStatus(lastUsedChannel, false)
			ix.comms.ChangeActiveChannel(lastUsedChannel)
			print("[ixComms] Unmuted: " .. ch.Name)
		end
	end
end)

-- +ixcomms_menu / -ixcomms_menu: Hold to open channel selection menu
local channelMenu = nil

concommand.Add("+ixcomms_menu", function(ply, cmd, args)
	if (!lply) then lply = LocalPlayer() end

	-- Close existing menu if open
	if (IsValid(channelMenu)) then
		channelMenu:Remove()
	end

	-- Create menu
	channelMenu = DermaMenu()

	local accessible = ix.comms.GetAccessibleChannels(lply)

	if (#accessible == 0) then
		channelMenu:AddOption("No channels available", function() end)
		channelMenu:Open()
		return
	end

	-- Add each channel as a menu option
	for _, entry in ipairs(accessible) do
		local id = entry.id
		local chan = entry.channel
		local canTalk = entry.canTalk

		local status = ""
		if (activeChannel == id) then
			status = " ★ ACTIVE"
		elseif (mutedChannels[id]) then
			status = " ✕ MUTED"
		end

		local access = canTalk and "TX/RX" or "RX"
		local label = string.format("%s - %s MHZ [%s]%s", chan.Name, chan.Frequency, access, status)

		channelMenu:AddOption(label, function()
			if (canTalk) then
				-- Switch to this channel (transmit capable)
				ix.comms.ChangeActiveChannel(id)
			else
				-- Listen only - unmute if muted and select as listener
				if (mutedChannels[id]) then
					ix.comms.ChangeMuteStatus(id, false)
				end
				ix.comms.ChangeActiveChannel(id)
			end

			PlayConfigSound("channelSwitch")

			if (IsValid(channelMenu)) then
				channelMenu:Remove()
				channelMenu = nil
			end
		end)
	end

	-- Add separator
	channelMenu:AddSpacer()

	-- Add mute/unmute options for currently active channel
	if (activeChannel != 0 and ix.comms.channels[activeChannel]) then
		if (mutedChannels[activeChannel]) then
			channelMenu:AddOption("Unmute Current Channel", function()
				ix.comms.ChangeMuteStatus(activeChannel, false)

				if (IsValid(channelMenu)) then
					channelMenu:Remove()
					channelMenu = nil
				end
			end)
		else
			channelMenu:AddOption("Mute Current Channel", function()
				ix.comms.ChangeMuteStatus(activeChannel, true)

				if (IsValid(channelMenu)) then
					channelMenu:Remove()
					channelMenu = nil
				end
			end)
		end
	end

	-- Add close option
	channelMenu:AddOption("Close", function()
		if (IsValid(channelMenu)) then
			channelMenu:Remove()
			channelMenu = nil
		end
	end)

	-- Open menu at cursor position
	channelMenu:Open()
end)

concommand.Add("-ixcomms_menu", function(ply, cmd, args)
	if (IsValid(channelMenu)) then
		channelMenu:Remove()
		channelMenu = nil
	end
end)

-- Cycle through available channels
concommand.Add("ixcomms_next", function(ply, cmd, args)
	if (!lply) then lply = LocalPlayer() end

	local accessible = ix.comms.GetAccessibleChannels(lply)

	if (#accessible == 0) then
		print("[ixComms] No channels available.")
		return
	end

	-- Find current index in accessible list
	local currentIdx = 0

	for i, entry in ipairs(accessible) do
		if (entry.id == activeChannel) then
			currentIdx = i
			break
		end
	end

	-- Cycle to next
	local nextIdx = (currentIdx % #accessible) + 1
	local next = accessible[nextIdx]

	if (next.canTalk) then
		ix.comms.ChangeActiveChannel(next.id)
		print("[ixComms] Switched to: " .. next.channel.Name)
	else
		-- Just unmute/select as listener
		if (mutedChannels[next.id]) then
			ix.comms.ChangeMuteStatus(next.id, false)
		end

		print("[ixComms] Tuned to: " .. next.channel.Name .. " (listen only)")
	end
end)

-- Quick list of channels
concommand.Add("ixcomms_list", function(ply, cmd, args)
	if (!lply) then lply = LocalPlayer() end

	print("[ixComms] ═══════════════════════════════════")
	print("[ixComms] RADIO CHANNELS")
	print("[ixComms] ═══════════════════════════════════")

	for id, ch in ipairs(ix.comms.channels) do
		local canTalk = ix.comms.CanTalk(lply, id)
		local canListen = ix.comms.CanListen(lply, id)

		if (!canTalk and !canListen) then continue end

		local status = ""

		if (activeChannel == id) then
			status = " ★ ACTIVE"
		elseif (mutedChannels[id]) then
			status = " ✕ MUTED"
		end

		local access = canTalk and "TX/RX" or "RX"
		local enc = ch.Encrypted and "ENC" or "OPEN"

		print(string.format("  [%d] %-20s %s MHZ  %s  %s%s",
			id, ch.Name, ch.Frequency, enc, access, status))
	end

	print("[ixComms] ═══════════════════════════════════")
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- VOICE PANEL SUPPRESSION
-- ═══════════════════════════════════════════════════════════════════════════════

--- Suppress the default voice panel for players who are transmitting on radio.
-- Their voice is shown through the diegetic HUD instead.
function PLUGIN:PlayerStartVoice(client)
	if (!client) then return end

	-- Check if this player has an incoming radio transmission
	local steamID = client:SteamID64()

	if (steamID and incomingTransmissions[steamID]) then
		-- Don't show default voice panel - diegetic HUD handles it
		return false
	end

	-- Check if it's us transmitting
	if (!lply) then lply = LocalPlayer() end

	if (client == lply and isTalking) then
		return false
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DIEGETIC HUD DATA PROVIDER
-- ═══════════════════════════════════════════════════════════════════════════════

--- Override the diegetic HUD's available channels to use real comms data.
-- This replaces the static channel definitions in the HUD with live data.
hook.Add("InitPostEntity", "ixComms_OverrideHUDChannels", function()
	lply = LocalPlayer()

	if (!ix.diegeticHUD) then return end

	-- Override GetAvailableChannels to return comms system channels
	ix.diegeticHUD.GetAvailableChannels = function()
		local result = {}

		for id, ch in ipairs(ix.comms.channels) do
			table.insert(result, {
				id = tostring(id),
				name = ch.Name,
				freq = ch.Frequency,
				encrypted = ch.Encrypted,
				color = ch.Color,
				description = ch.Description
			})
		end

		return result
	end

	-- Override GetConnectedChannels to show non-muted listening channels
	local origGetConnected = ix.diegeticHUD.GetConnectedChannels

	ix.diegeticHUD.GetConnectedChannels = function()
		local result = {}

		for id, ch in ipairs(ix.comms.channels) do
			if (!mutedChannels[id] and ix.comms.CanListen(lply, id)) then
				table.insert(result, ch.Name)
			end
		end

		return result
	end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLEANUP
-- ═══════════════════════════════════════════════════════════════════════════════

-- Clean up stale incoming transmissions
timer.Create("ixComms_CleanIncoming", 5, 0, function()
	local now = SysTime()

	for steamID, data in pairs(incomingTransmissions) do
		-- Remove if player disconnected or transmission is very old (60s failsafe)
		if (!IsValid(data.ply) or (now - data.startTime) > 60) then
			incomingTransmissions[steamID] = nil
		end
	end
end)
