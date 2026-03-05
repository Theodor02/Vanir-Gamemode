--- Imperial Comms System - Shared Plugin
-- Channel-based voice radio system adapted from helio_radio.
-- Integrates with the diegetic HUD for visual feedback.
-- No external UI or VManip required - all presentation handled by diagetichud.

local PLUGIN = PLUGIN

PLUGIN.name = "Imperial Comms System"
PLUGIN.author = "Copilot"
PLUGIN.description = "Channel-based military voice communications with diegetic HUD integration."

-- ═══════════════════════════════════════════════════════════════════════════════
-- SHARED INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════════

ix.comms = ix.comms or {}
ix.comms.channels = ix.comms.channels or {}
ix.comms.channelCount = ix.comms.channelCount or 0
ix.comms.channelBitSize = 8 -- sufficient for up to 255 channels

-- ═══════════════════════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════════

ix.comms.config = {
	-- Audio cues (Star Wars themed from everfall sound pack)
	sounds = {
		txStart = "everfall/equipment/radio/radio_static_republic_start_01_01.mp3",
		txStop = "everfall/equipment/radio/radio_static_republic_stop_01_01.mp3",
		rxStart = "everfall/equipment/radio/radio_static_republic_start_01_03.mp3",
		rxStop = "everfall/equipment/radio/radio_static_republic_stop_01_03.mp3",
		channelSwitch = "everfall/miscellaneous/ux/navigation/navigation_activate_01.mp3",
		channelDeactivate = "everfall/miscellaneous/ux/navigation/navigation_back_01.mp3",
		channelMute = "everfall/miscellaneous/ux/navigation/navigation_tab_01.mp3",
		error = "everfall/miscellaneous/ux/navigation/navigation_error_01.mp3",
	},

	-- Alternate start sounds for variety (randomly picked)
	txStartVariants = {
		"everfall/equipment/radio/radio_static_republic_start_01_01.mp3",
		"everfall/equipment/radio/radio_static_republic_start_01_02.mp3",
		"everfall/equipment/radio/radio_static_republic_start_01_03.mp3",
		"everfall/equipment/radio/radio_static_republic_start_01_04.mp3",
		"everfall/equipment/radio/radio_static_republic_start_01_05.mp3",
		"everfall/equipment/radio/radio_static_republic_start_01_06.mp3",
		"everfall/equipment/radio/radio_static_republic_start_01_07.mp3",
	},

	txStopVariants = {
		"everfall/equipment/radio/radio_static_republic_stop_01_01.mp3",
		"everfall/equipment/radio/radio_static_republic_stop_01_02.mp3",
		"everfall/equipment/radio/radio_static_republic_stop_01_03.mp3",
		"everfall/equipment/radio/radio_static_republic_stop_01_04.mp3",
		"everfall/equipment/radio/radio_static_republic_stop_01_05.mp3",
	},

	-- Volume for radio cue sounds (0-1)
	cueVolume = 0.35,

	-- Whether incoming transmissions play audio cues
	incomingTransmissionSounds = true,

	-- Whether outgoing transmissions play audio cues
	outgoingTransmissionSounds = true,

	-- Show muted channel notifications (dimmed) in HUD
	showMutedNotifications = false,

	-- Maximum channels a player can listen to simultaneously (0 = unlimited)
	maxListenChannels = 0,

	-- Voice proximity range when NOT using radio (Hammer units, 0 = default GMod)
	proximityRange = 0,
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- CHANNEL REGISTRATION
-- ═══════════════════════════════════════════════════════════════════════════════

--- Register a new radio channel.
-- @param input Table containing channel definition:
--   - Name (string): Display name
--   - Talkers (table): List of TEAM_ identifiers that can talk
--   - Listeners (table): List of TEAM_ identifiers that can listen
--   - GetTalkers (function(ply)): Returns true if player can talk
--   - GetListeners (function(ply)): Returns true if player can listen
--   - Mutable (bool): Whether the player can mute this channel
--   - MutedByDefault (bool): Whether this channel starts muted
--   - Colour/Color (Color): Channel accent color
--   - Encrypted (bool): Whether the channel is encrypted (visual only)
--   - Frequency (string): Display frequency (e.g. "8858.0")
--   - Description (string): Optional channel description
function ix.comms.AddChannel(input)
	if (!isstring(input.Name) or !istable(input.Talkers) or !istable(input.Listeners)
		or !isfunction(input.GetTalkers) or !isfunction(input.GetListeners)
		or !isbool(input.Mutable)) then
		ErrorNoHalt("[ixComms] Invalid channel definition for: " .. tostring(input.Name) .. "\n")
		return
	end

	local data = {}
	data.Name = input.Name
	data.Color = input.Colour or input.Color or Color(255, 255, 255)
	data.Encrypted = input.Encrypted or false
	data.Frequency = input.Frequency or string.format("%04d.%d", math.random(1000, 9999), math.random(0, 9))
	data.Description = input.Description or ""
	data.Mutable = input.Mutable
	data.MutedByDefault = input.MutedByDefault or false

	-- Convert team lists to lookup tables for O(1) access
	data.Listeners = {}
	for _, v in ipairs(input.Listeners) do
		data.Listeners[v] = true
	end

	data.Talkers = {}
	for _, v in ipairs(input.Talkers) do
		data.Talkers[v] = true
	end

	data.GetTalkers = input.GetTalkers
	data.GetListeners = input.GetListeners

	table.insert(ix.comms.channels, data)
	ix.comms.channelCount = #ix.comms.channels
	ix.comms.channelBitSize = math.max(4, math.ceil(math.log(ix.comms.channelCount + 1) / math.log(2) + 1))

	if (SERVER) then
		print(string.format("[ixComms] Channel registered: %s (freq %s MHZ) [%d total]",
			data.Name, data.Frequency, ix.comms.channelCount))
	end

	return ix.comms.channelCount
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SHARED UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════════

--- Check if a player can talk on a given channel.
-- @entity ply The player to check
-- @int chanID Channel index
-- @treturn bool
function ix.comms.CanTalk(ply, chanID)
	if (!IsValid(ply) or !ix.comms.channels[chanID]) then return false end

	local chan = ix.comms.channels[chanID]
	return chan.GetTalkers(ply) or chan.Talkers[ply:Team()] or false
end

--- Check if a player can listen on a given channel.
-- @entity ply The player to check
-- @int chanID Channel index
-- @treturn bool
function ix.comms.CanListen(ply, chanID)
	if (!IsValid(ply) or !ix.comms.channels[chanID]) then return false end

	local chan = ix.comms.channels[chanID]
	return chan.GetListeners(ply) or chan.Listeners[ply:Team()] or false
end

--- Check if a player has any access (talk or listen) to a channel.
-- @entity ply The player
-- @int chanID Channel index
-- @treturn bool
function ix.comms.HasAccess(ply, chanID)
	return ix.comms.CanTalk(ply, chanID) or ix.comms.CanListen(ply, chanID)
end

--- Get all channels a player has access to.
-- @entity ply The player
-- @treturn table Array of {id, channel, canTalk, canListen}
function ix.comms.GetAccessibleChannels(ply)
	local result = {}

	for id, ch in ipairs(ix.comms.channels) do
		local canTalk = ix.comms.CanTalk(ply, id)
		local canListen = ix.comms.CanListen(ply, id)

		if (canTalk or canListen) then
			table.insert(result, {
				id = id,
				channel = ch,
				canTalk = canTalk,
				canListen = canListen
			})
		end
	end

	return result
end

--- Get a channel by name (case-insensitive).
-- @string name Channel name to search for
-- @treturn int|nil Channel ID or nil
-- @treturn table|nil Channel data or nil
function ix.comms.GetChannelByName(name)
	local lower = string.lower(name)

	for id, ch in ipairs(ix.comms.channels) do
		if (string.lower(ch.Name) == lower) then
			return id, ch
		end
	end

	return nil, nil
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- INCLUDES
-- ═══════════════════════════════════════════════════════════════════════════════

ix.util.Include("sh_channels.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
