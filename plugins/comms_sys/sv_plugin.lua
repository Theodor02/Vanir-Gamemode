--- Imperial Comms System - Server Plugin
-- Handles voice routing via PlayerCanHearPlayersVoice, channel state management,
-- transmission broadcasting, and muted-by-default initialization.

local PLUGIN = PLUGIN

-- ═══════════════════════════════════════════════════════════════════════════════
-- NETWORK STRINGS
-- ═══════════════════════════════════════════════════════════════════════════════

util.AddNetworkString("ixComms_StartTalking")
util.AddNetworkString("ixComms_StopTalking")
util.AddNetworkString("ixComms_ChangeChannel")
util.AddNetworkString("ixComms_ChangeChannelFeedback")
util.AddNetworkString("ixComms_MuteChannel")
util.AddNetworkString("ixComms_MuteChannelFeedback")
util.AddNetworkString("ixComms_IncomingStart")
util.AddNetworkString("ixComms_IncomingStop")
util.AddNetworkString("ixComms_FullSync")

-- ═══════════════════════════════════════════════════════════════════════════════
-- PLAYER INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:PlayerInitialSpawn(ply)
	ply.ixComms = ply.ixComms or {}
	ply.ixComms.activeChannel = 0
	ply.ixComms.isTalking = false
	ply.ixComms.mutedChannels = {}
end

-- Queue for delayed mute-by-default init (wait for client to be ready)
local initQueue = {}

hook.Add("PlayerInitialSpawn", "ixComms_QueueMuteDefaults", function(ply)
	initQueue[ply] = true
end)

hook.Add("StartCommand", "ixComms_ProcessMuteDefaults", function(ply, cmd)
	if (initQueue[ply] and !cmd:IsForced()) then
		initQueue[ply] = nil
		ix.comms.InitMutedDefaults(ply)
	end
end)

-- Also re-process when team changes
function PLUGIN:PlayerChangedTeam(ply, oldTeam, newTeam)
	ix.comms.InitMutedDefaults(ply, newTeam)
end

--- Initialize muted-by-default channels for a player.
-- @entity ply The player
-- @int overrideTeam Optional team to use instead of current
function ix.comms.InitMutedDefaults(ply, overrideTeam)
	if (!IsValid(ply)) then return end

	ply.ixComms = ply.ixComms or {}
	ply.ixComms.mutedChannels = ply.ixComms.mutedChannels or {}

	local plyTeam = overrideTeam or ply:Team()

	for chanID, channel in ipairs(ix.comms.channels) do
		-- Skip non-mutable or non-defaultmuted channels
		if (!channel.MutedByDefault or !channel.Mutable) then continue end

		-- Only mute channels the player is aware of
		local aware = false

		if (channel.Talkers[plyTeam] or channel.Listeners[plyTeam]) then
			aware = true
		end

		if (channel.GetTalkers(ply) or channel.GetListeners(ply)) then
			aware = true
		end

		if (!aware) then continue end

		ply.ixComms.mutedChannels[chanID] = true

		-- Notify client
		net.Start("ixComms_MuteChannelFeedback")
			net.WriteUInt(chanID, ix.comms.channelBitSize)
			net.WriteBool(true)
		net.Send(ply)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TALKING STATE MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════════

--- Start a player's radio transmission on their active channel.
-- @entity ply The speaking player
function ix.comms.StartTalking(ply)
	if (!IsValid(ply)) then return end

	ply.ixComms = ply.ixComms or {}

	if (!ply.ixComms.activeChannel or ply.ixComms.activeChannel == 0) then return end

	local chanID = ply.ixComms.activeChannel
	local chan = ix.comms.channels[chanID]

	if (!chan) then
		ErrorNoHalt(string.format("[ixComms] %s tried to talk on invalid channel %s\n", ply:Name(), tostring(chanID)))
		ply.ixComms.activeChannel = 0
		return
	end

	-- Verify permissions
	if (!ix.comms.CanTalk(ply, chanID)) then
		ply.ixComms.activeChannel = 0
		return
	end

	ply.ixComms.isTalking = true

	-- Build recipient list (non-muted listeners)
	local recipients = {}

	for _, listener in ipairs(player.GetAll()) do
		if (listener == ply) then continue end -- Don't send to self

		local muted = listener.ixComms and listener.ixComms.mutedChannels and listener.ixComms.mutedChannels[chanID]

		if (!muted and ix.comms.CanListen(listener, chanID)) then
			table.insert(recipients, listener)
		end
	end

	if (#recipients > 0) then
		net.Start("ixComms_IncomingStart")
			net.WriteUInt(chanID, ix.comms.channelBitSize)
			net.WriteString(ply:SteamID64())
		net.Send(recipients)
	end

	-- Fire hook for other systems (e.g. diegetic HUD transmission)
	hook.Run("ixCommsTransmissionStart", ply, chanID, chan)
end

--- Stop a player's radio transmission.
-- @entity ply The speaking player
function ix.comms.StopTalking(ply)
	if (!IsValid(ply)) then return end

	ply.ixComms = ply.ixComms or {}

	local chanID = ply.ixComms.activeChannel

	if (!chanID or chanID == 0) then return end

	-- Small delay before clearing talking state (prevents race conditions with voice data)
	timer.Simple(0.15, function()
		if (IsValid(ply) and ply.ixComms) then
			ply.ixComms.isTalking = false
		end
	end)

	local chan = ix.comms.channels[chanID]

	if (!chan) then return end

	-- Notify all listeners that transmission ended
	for _, listener in ipairs(player.GetAll()) do
		if (listener == ply) then continue end

		if (ix.comms.CanListen(listener, chanID)) then
			net.Start("ixComms_IncomingStop")
				net.WriteUInt(chanID, ix.comms.channelBitSize)
				net.WriteString(ply:SteamID64())
			net.Send(listener)
		end
	end

	-- Fire hook for other systems
	hook.Run("ixCommsTransmissionStop", ply, chanID, chan)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- VOICE ROUTING (PlayerCanHearPlayersVoice)
-- ═══════════════════════════════════════════════════════════════════════════════

--- Core voice routing hook. When a talker is on radio, only listeners on
--- their channel hear them (bypassing proximity). Otherwise falls through
--- to default proximity behavior.
function PLUGIN:PlayerCanHearPlayersVoice(listener, talker)
	if (!IsValid(listener) or !IsValid(talker)) then return end

	talker.ixComms = talker.ixComms or {}
	listener.ixComms = listener.ixComms or {}

	-- If talker is using radio
	if (talker.ixComms.isTalking) then
		local chanID = talker.ixComms.activeChannel

		if (!chanID or chanID == 0 or !ix.comms.channels[chanID]) then return end

		-- Check if listener has this channel muted
		if (listener.ixComms.mutedChannels and listener.ixComms.mutedChannels[chanID]) then
			return false, false
		end

		-- Check if listener can hear this channel
		local chan = ix.comms.channels[chanID]

		if (chan.GetListeners(listener) or chan.Listeners[listener:Team()]) then
			return true, false -- Can hear, NOT 3D spatialized (radio is non-positional)
		else
			return false, false
		end
	end

	-- Not on radio - fall through to default proximity voice
	-- Return nil to let other hooks handle it
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- NETWORKING RECEIVERS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Player requests to start talking on radio
net.Receive("ixComms_StartTalking", function(_, ply)
	ix.comms.StartTalking(ply)
end)

-- Player stops talking on radio
net.Receive("ixComms_StopTalking", function(_, ply)
	ix.comms.StopTalking(ply)
end)

-- Player changes their active transmit channel
net.Receive("ixComms_ChangeChannel", function(_, ply)
	local chanID = net.ReadUInt(ix.comms.channelBitSize)

	ply.ixComms = ply.ixComms or {}

	-- Validate channel
	if (chanID != 0 and (!ix.comms.channels[chanID] or !ix.comms.CanTalk(ply, chanID))) then
		-- Send back current channel (reject change)
		net.Start("ixComms_ChangeChannelFeedback")
			net.WriteUInt(ply.ixComms.activeChannel or 0, ix.comms.channelBitSize)
			net.WriteBool(false) -- rejected
		net.Send(ply)
		return
	end

	-- If was talking on a different channel, stop that transmission first
	if (ply.ixComms.isTalking and ply.ixComms.activeChannel != chanID) then
		ix.comms.StopTalking(ply)
	end

	ply.ixComms.activeChannel = chanID

	-- Confirm to client
	net.Start("ixComms_ChangeChannelFeedback")
		net.WriteUInt(chanID, ix.comms.channelBitSize)
		net.WriteBool(true) -- accepted
	net.Send(ply)

	hook.Run("ixCommsChannelChanged", ply, chanID)
end)

-- Player mutes/unmutes a channel
net.Receive("ixComms_MuteChannel", function(_, ply)
	local chanID = net.ReadUInt(ix.comms.channelBitSize)
	local muted = net.ReadBool()

	ply.ixComms = ply.ixComms or {}
	ply.ixComms.mutedChannels = ply.ixComms.mutedChannels or {}

	-- Validate channel
	if (!ix.comms.channels[chanID]) then return end

	-- Prevent muting immutable channels
	if (!ix.comms.channels[chanID].Mutable) then return end

	ply.ixComms.mutedChannels[chanID] = muted

	-- If they muted their active channel, deactivate it
	if (muted and ply.ixComms.activeChannel == chanID) then
		if (ply.ixComms.isTalking) then
			ix.comms.StopTalking(ply)
		end

		ply.ixComms.activeChannel = 0

		net.Start("ixComms_ChangeChannelFeedback")
			net.WriteUInt(0, ix.comms.channelBitSize)
			net.WriteBool(true)
		net.Send(ply)
	end

	-- Confirm mute status
	net.Start("ixComms_MuteChannelFeedback")
		net.WriteUInt(chanID, ix.comms.channelBitSize)
		net.WriteBool(muted)
	net.Send(ply)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- FULL CHANNEL SYNC (for reconnects / team changes)
-- ═══════════════════════════════════════════════════════════════════════════════

--- Send a full channel state sync to a player.
-- @entity ply The player to sync
function ix.comms.FullSync(ply)
	if (!IsValid(ply)) then return end

	ply.ixComms = ply.ixComms or {}

	net.Start("ixComms_FullSync")
		net.WriteUInt(ply.ixComms.activeChannel or 0, ix.comms.channelBitSize)
		net.WriteUInt(ix.comms.channelCount, ix.comms.channelBitSize)

		for chanID = 1, ix.comms.channelCount do
			local muted = ply.ixComms.mutedChannels and ply.ixComms.mutedChannels[chanID] or false
			net.WriteBool(muted)
		end
	net.Send(ply)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DIEGETIC HUD INTEGRATION HOOKS
-- ═══════════════════════════════════════════════════════════════════════════════

--- When a player starts transmitting, fire the diegetic HUD transmission display.
hook.Add("ixCommsTransmissionStart", "ixComms_DiegeticHUD", function(ply, chanID, chan)
	if (!ix.diegeticHUD) then return end

	-- Get recipients (all listeners on this channel)
	local recipients = {}

	for _, listener in ipairs(player.GetAll()) do
		if (ix.comms.CanListen(listener, chanID)) then
			table.insert(recipients, listener)
		end
	end

	-- Send transmission event to diegetic HUD
	ix.diegeticHUD.SendTransmission(ply, chan.Name, chan.Frequency, chan.Encrypted, 30, recipients)
end)

--- When a player stops transmitting, clear the diegetic HUD transmission.
hook.Add("ixCommsTransmissionStop", "ixComms_DiegeticHUD", function(ply, chanID, chan)
	-- The diegetic HUD handles timeout naturally, but we can send a clear signal
	-- The existing transmission will expire based on the CurTime check in cl_plugin
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- HELIX VOICE SUPPRESSION
-- ═══════════════════════════════════════════════════════════════════════════════

-- Remove the default voice panel when using radio (it would show alongside our HUD)
function PLUGIN:PlayerStartVoice(ply)
	if (ply.ixComms and ply.ixComms.isTalking) then
		-- Suppress the default voice panel for radio users
		-- The diegetic HUD handles the display
		return false
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- ADMIN COMMANDS
-- ═══════════════════════════════════════════════════════════════════════════════

ix.command.Add("CommsListChannels", {
	description = "List all available radio channels.",
	adminOnly = true,
	OnRun = function(self, ply)
		for id, ch in ipairs(ix.comms.channels) do
			local canTalk = ix.comms.CanTalk(ply, id) and "TALK" or ""
			local canListen = ix.comms.CanListen(ply, id) and "LISTEN" or ""

			ply:ChatPrint(string.format("[%d] %s - %s MHZ [%s%s%s]",
				id, ch.Name, ch.Frequency,
				canTalk,
				(canTalk != "" and canListen != "") and "/" or "",
				canListen
			))
		end
	end
})

ix.command.Add("CommsForceChannel", {
	description = "Force a player onto a specific channel.",
	adminOnly = true,
	arguments = {
		ix.type.player,
		ix.type.number
	},
	OnRun = function(self, ply, target, chanID)
		chanID = math.floor(chanID)

		if (chanID < 0 or chanID > ix.comms.channelCount) then
			ply:Notify("Invalid channel ID. Use 0 to deactivate.")
			return
		end

		target.ixComms = target.ixComms or {}
		target.ixComms.activeChannel = chanID

		net.Start("ixComms_ChangeChannelFeedback")
			net.WriteUInt(chanID, ix.comms.channelBitSize)
			net.WriteBool(true)
		net.Send(target)

		local chanName = chanID > 0 and ix.comms.channels[chanID].Name or "OFF"
		ply:Notify(string.format("Set %s to channel: %s", target:Name(), chanName))
	end
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- VOICEBOX FX INTEGRATION (optional, if VoiceBox addon is installed)
-- Marks radio transmissions as radio comms so VoiceBox can apply radio FX.
-- ═══════════════════════════════════════════════════════════════════════════════

local function SetupVoiceBoxIntegration()
	if (!VoiceBox or !VoiceBox.FX) then return end

	print("[ixComms] VoiceBox FX integration active.")

	-- Override the voice routing to mark radio comms for VoiceBox FX
	local origCanHear = PLUGIN.PlayerCanHearPlayersVoice

	PLUGIN.PlayerCanHearPlayersVoice = function(self, listener, talker)
		if (!IsValid(listener) or !IsValid(talker)) then return end

		-- Clear radio flag by default
		VoiceBox.FX.IsRadioComm(listener:EntIndex(), talker:EntIndex(), false)

		talker.ixComms = talker.ixComms or {}
		listener.ixComms = listener.ixComms or {}

		-- If talker is using radio
		if (talker.ixComms.isTalking) then
			local chanID = talker.ixComms.activeChannel
			if (!chanID or chanID == 0 or !ix.comms.channels[chanID]) then return end

			if (listener.ixComms.mutedChannels and listener.ixComms.mutedChannels[chanID]) then
				return false, false
			end

			local chan = ix.comms.channels[chanID]
			if (chan.GetListeners(listener) or chan.Listeners[listener:Team()]) then
				-- Mark as radio comm if they can't hear this person via proximity
				local isProximity = VoiceBox.FX.__PlayerCanHearPlayersVoice and
					VoiceBox.FX.__PlayerCanHearPlayersVoice(listener, talker)
				VoiceBox.FX.IsRadioComm(listener:EntIndex(), talker:EntIndex(), !isProximity)
				return true, false
			else
				return false, false
			end
		end
	end
end

-- Try to set up immediately, or wait for VoiceBox to load
if (VoiceBox and VoiceBox.FX) then
	SetupVoiceBoxIntegration()
else
	hook.Add("VoiceBox.FX", "ixComms_VoiceBoxIntegration", function()
		SetupVoiceBoxIntegration()
	end)
end
