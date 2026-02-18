--- Imperial Diegetic HUD - Public API
-- @module ix.diegeticHUD
-- Provides a public interface for other plugins to interact with the HUD systems:
-- DEFCON, Priority Orders, Objectives, Squad, Comms, Waypoints, and Damage Indicators.
-- All server-side functions network data to clients automatically.

ix.diegeticHUD = ix.diegeticHUD or {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEFCON SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

--- DEFCON level data definitions.
-- @table DEFCON_DATA
ix.diegeticHUD.DEFCON_DATA = {
	[1] = {label = "MAXIMUM READINESS", desc = "Station lockdown - All personnel to combat stations", threat = "CRITICAL"},
	[2] = {label = "HIGH ALERT", desc = "Hostile contact probable - Weapons hot", threat = "SEVERE"},
	[3] = {label = "ELEVATED WATCH", desc = "Increased security measures active", threat = "ELEVATED"},
	[4] = {label = "STANDARD ALERT", desc = "Normal defensive posture maintained", threat = "GUARDED"},
	[5] = {label = "PEACETIME", desc = "Minimal threat - Standard operations", threat = "LOW"}
}

if (SERVER) then
	--- Set the current DEFCON level server-wide.
	-- @int level DEFCON level (1-5), where 1 is maximum readiness
	-- @realm server
	function ix.diegeticHUD.SetDEFCON(level)
		level = math.Clamp(math.floor(level), 1, 5)

		SetGlobalInt("ixDEFCON", level)

		hook.Run("DiegeticHUDDefconChanged", level)
	end

	--- Set a priority order (highest priority transmission).
	-- @string text The order text to display
	-- @string issuer The issuer name (e.g. "ISS VENGEANCE // CMDR TARKIN")
	-- @string desc Optional description/subtext
	-- @realm server
	function ix.diegeticHUD.SetPriorityOrder(text, issuer, desc)
		SetGlobalString("ixPriorityText", text or "")
		SetGlobalString("ixPriorityIssuer", issuer or "")
		SetGlobalString("ixPriorityDesc", desc or "")
		SetGlobalBool("ixHasPriority", text != nil and text != "")

		hook.Run("DiegeticHUDPriorityChanged", text, issuer, desc)
	end

	--- Clear the current priority order.
	-- @realm server
	function ix.diegeticHUD.ClearPriorityOrder()
		SetGlobalString("ixPriorityText", "")
		SetGlobalString("ixPriorityIssuer", "")
		SetGlobalString("ixPriorityDesc", "")
		SetGlobalBool("ixHasPriority", false)

		hook.Run("DiegeticHUDPriorityChanged", nil, nil, nil)
	end

	--- Set an objective for a specific player.
	-- @entity ply The player to set the objective for
	-- @string title The objective header text
	-- @string desc Optional description/details
	-- @realm server
	function ix.diegeticHUD.SetObjective(ply, title, desc)
		if (!IsValid(ply)) then return end

		ply:SetNetVar("ixObjectiveTitle", title or "")
		ply:SetNetVar("ixObjectiveDesc", desc or "")
		ply:SetNetVar("ixHasObjective", title != nil and title != "")

		hook.Run("DiegeticHUDObjectiveChanged", ply, title, desc)
	end

	--- Clear a player's objective.
	-- @entity ply The player to clear
	-- @realm server
	function ix.diegeticHUD.ClearObjective(ply)
		if (!IsValid(ply)) then return end

		ply:SetNetVar("ixObjectiveTitle", "")
		ply:SetNetVar("ixObjectiveDesc", "")
		ply:SetNetVar("ixHasObjective", false)

		hook.Run("DiegeticHUDObjectiveChanged", ply, nil, nil)
	end

	--- Set an objective for all players.
	-- @string title The objective header text
	-- @string desc Optional description/details
	-- @realm server
	function ix.diegeticHUD.SetGlobalObjective(title, desc)
		for _, ply in ipairs(player.GetAll()) do
			ix.diegeticHUD.SetObjective(ply, title, desc)
		end
	end

	--- Clear all players' objectives.
	-- @realm server
	function ix.diegeticHUD.ClearGlobalObjective()
		for _, ply in ipairs(player.GetAll()) do
			ix.diegeticHUD.ClearObjective(ply)
		end
	end

	-- ═══════════════════════════════════════════════════════════════════════════
	-- WAYPOINT SYSTEM
	-- ═══════════════════════════════════════════════════════════════════════════

	util.AddNetworkString("ixDiegeticWaypoint")
	util.AddNetworkString("ixDiegeticWaypointClear")

	--- Add a waypoint for a specific player.
	-- @entity ply The player to add the waypoint for
	-- @string id Unique identifier for the waypoint
	-- @string label Display label
	-- @vector pos World position of the waypoint
	-- @string waypointType "TGT" for objective targets, "THR" for threats
	-- @realm server
	function ix.diegeticHUD.AddWaypoint(ply, id, label, pos, waypointType)
		if (!IsValid(ply)) then return end

		net.Start("ixDiegeticWaypoint")
			net.WriteString(id)
			net.WriteString(label)
			net.WriteVector(pos)
			net.WriteString(waypointType or "TGT")
		net.Send(ply)
	end

	--- Remove a waypoint for a specific player.
	-- @entity ply The player
	-- @string id Waypoint identifier to remove
	-- @realm server
	function ix.diegeticHUD.RemoveWaypoint(ply, id)
		if (!IsValid(ply)) then return end

		net.Start("ixDiegeticWaypointClear")
			net.WriteString(id)
		net.Send(ply)
	end

	--- Add a waypoint for all players.
	-- @string id Unique identifier
	-- @string label Display label
	-- @vector pos World position
	-- @string waypointType "TGT" or "THR"
	-- @realm server
	function ix.diegeticHUD.AddGlobalWaypoint(id, label, pos, waypointType)
		net.Start("ixDiegeticWaypoint")
			net.WriteString(id)
			net.WriteString(label)
			net.WriteVector(pos)
			net.WriteString(waypointType or "TGT")
		net.Broadcast()
	end

	--- Remove a waypoint for all players.
	-- @string id Waypoint identifier
	-- @realm server
	function ix.diegeticHUD.RemoveGlobalWaypoint(id)
		net.Start("ixDiegeticWaypointClear")
			net.WriteString(id)
		net.Broadcast()
	end

	-- ═══════════════════════════════════════════════════════════════════════════
	-- SQUAD SYSTEM
	-- ═══════════════════════════════════════════════════════════════════════════

	util.AddNetworkString("ixDiegeticSquadSync")
	util.AddNetworkString("ixDiegeticSquadBogus")

	ix.diegeticHUD.squads = ix.diegeticHUD.squads or {}

	--- Create a squad with a designation and members.
	-- @string id Unique squad identifier
	-- @string designation Display name (e.g. "FIRETEAM AUREK")
	-- @table members Table of player entities
	-- @realm server
	function ix.diegeticHUD.CreateSquad(id, designation, members)
		ix.diegeticHUD.squads[id] = {
			designation = designation,
			members = members or {}
		}

		for _, ply in ipairs(members or {}) do
			if (IsValid(ply)) then
				ply:SetNetVar("ixSquadID", id)
				ply:SetNetVar("ixSquadName", designation)
				ply:SetNetVar("ixInSquad", true)
			end
		end

		ix.diegeticHUD.SyncSquad(id)

		hook.Run("DiegeticHUDSquadCreated", id, designation, members)
	end

	--- Add a player to a squad.
	-- @string id Squad identifier
	-- @entity ply Player to add
	-- @realm server
	function ix.diegeticHUD.AddToSquad(id, ply)
		if (!ix.diegeticHUD.squads[id] or !IsValid(ply)) then return end

		table.insert(ix.diegeticHUD.squads[id].members, ply)

		ply:SetNetVar("ixSquadID", id)
		ply:SetNetVar("ixSquadName", ix.diegeticHUD.squads[id].designation)
		ply:SetNetVar("ixInSquad", true)

		ix.diegeticHUD.SyncSquad(id)
	end

	--- Remove a player from their squad.
	-- @entity ply Player to remove
	-- @realm server
	function ix.diegeticHUD.RemoveFromSquad(ply)
		if (!IsValid(ply)) then return end

		local squadID = ply:GetNetVar("ixSquadID")

		if (squadID and ix.diegeticHUD.squads[squadID]) then
			local squad = ix.diegeticHUD.squads[squadID]

			for i, member in ipairs(squad.members) do
				if (member == ply) then
					table.remove(squad.members, i)
					break
				end
			end

			ix.diegeticHUD.SyncSquad(squadID)
		end

		ply:SetNetVar("ixSquadID", nil)
		ply:SetNetVar("ixSquadName", nil)
		ply:SetNetVar("ixInSquad", false)
	end

	--- Disband a squad entirely.
	-- @string id Squad identifier
	-- @realm server
	function ix.diegeticHUD.DisbandSquad(id)
		local squad = ix.diegeticHUD.squads[id]

		if (!squad) then return end

		for _, ply in ipairs(squad.members) do
			if (IsValid(ply)) then
				ply:SetNetVar("ixSquadID", nil)
				ply:SetNetVar("ixSquadName", nil)
				ply:SetNetVar("ixInSquad", false)
			end
		end

		ix.diegeticHUD.squads[id] = nil

		hook.Run("DiegeticHUDSquadDisbanded", id)
	end

	--- Sync squad data to all squad members.
	-- @string id Squad identifier
	-- @realm server
	function ix.diegeticHUD.SyncSquad(id)
		local squad = ix.diegeticHUD.squads[id]

		if (!squad) then return end

		-- Build member data table
		local memberData = {}

		for _, ply in ipairs(squad.members) do
			if (IsValid(ply)) then
				local char = ply:GetCharacter()

				table.insert(memberData, {
					steamID = ply:SteamID64(),
					name = char and char:GetName() or ply:Nick(),
					health = ply:Health(),
					maxHealth = ply:GetMaxHealth(),
					pos = ply:GetPos(),
					alive = ply:Alive()
				})
			end
		end

		-- Send to all squad members
		for _, ply in ipairs(squad.members) do
			if (IsValid(ply)) then
				net.Start("ixDiegeticSquadSync")
					net.WriteString(id)
					net.WriteString(squad.designation)
					net.WriteUInt(#memberData, 8)

					for _, data in ipairs(memberData) do
						net.WriteString(data.steamID)
						net.WriteString(data.name)
						net.WriteUInt(math.Clamp(data.health, 0, 255), 8)
						net.WriteUInt(math.Clamp(data.maxHealth, 0, 255), 8)
						net.WriteVector(data.pos)
						net.WriteBool(data.alive)
					end
				net.Send(ply)
			end
		end
	end

	-- ═══════════════════════════════════════════════════════════════════════════
	-- COMMS SYSTEM
	-- ═══════════════════════════════════════════════════════════════════════════

	util.AddNetworkString("ixDiegeticCommsTransmission")

	--- Broadcast a comms transmission to players (shows the active transmission overlay).
	-- @entity speaker The player who is speaking
	-- @string channel Channel name (e.g. "COMMAND NET")
	-- @string freq Frequency string (e.g. "8858.0")
	-- @bool encrypted Whether the channel is encrypted
	-- @number duration How long to show the transmission (seconds)
	-- @table recipients Table of player entities to receive (nil for all)
	-- @realm server
	function ix.diegeticHUD.SendTransmission(speaker, channel, freq, encrypted, duration, recipients)
		local char = IsValid(speaker) and speaker:GetCharacter()
		local speakerName = char and char:GetName() or (IsValid(speaker) and speaker:Nick() or "UNKNOWN")

		net.Start("ixDiegeticCommsTransmission")
			net.WriteString(speakerName)
			net.WriteString(channel or "UNKNOWN")
			net.WriteString(freq or "0000.0")
			net.WriteBool(encrypted or false)
			net.WriteFloat(duration or 3)
		if (recipients) then
			net.Send(recipients)
		else
			net.Broadcast()
		end
	end

	-- ═══════════════════════════════════════════════════════════════════════════
	-- DAMAGE DIRECTION
	-- ═══════════════════════════════════════════════════════════════════════════

	util.AddNetworkString("ixDiegeticDamageDir")

	--- Notify a player of damage direction (for directional flash indicator).
	-- This is normally called automatically from EntityTakeDamage, but can be
	-- called manually for custom damage effects.
	-- @entity ply The player who took damage
	-- @entity attacker The attacker entity
	-- @realm server
	function ix.diegeticHUD.NotifyDamageDirection(ply, attacker)
		if (!IsValid(ply) or !IsValid(attacker)) then return end

		net.Start("ixDiegeticDamageDir")
			net.WriteVector(attacker:GetPos())
		net.Send(ply)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SHARED ACCESSORS (client can read these)
-- ═══════════════════════════════════════════════════════════════════════════════

--- Get the current DEFCON level.
-- @treturn int DEFCON level 1-5
-- @realm shared
function ix.diegeticHUD.GetDEFCON()
	return GetGlobalInt("ixDEFCON", 5)
end

--- Check if there is an active priority order.
-- @treturn bool Whether a priority order is active
-- @realm shared
function ix.diegeticHUD.HasPriorityOrder()
	return GetGlobalBool("ixHasPriority", false)
end

--- Get current priority order data.
-- @treturn string text The order text
-- @treturn string issuer The issuer
-- @treturn string desc The description
-- @realm shared
function ix.diegeticHUD.GetPriorityOrder()
	return GetGlobalString("ixPriorityText", ""),
		   GetGlobalString("ixPriorityIssuer", ""),
		   GetGlobalString("ixPriorityDesc", "")
end

--- Get a player's current objective.
-- @entity ply The player (defaults to LocalPlayer on client)
-- @treturn string title
-- @treturn string desc
-- @realm shared
function ix.diegeticHUD.GetObjective(ply)
	ply = ply or (CLIENT and LocalPlayer())

	if (!IsValid(ply)) then return "", "" end

	return ply:GetNetVar("ixObjectiveTitle", ""),
		   ply:GetNetVar("ixObjectiveDesc", "")
end

--- Check if a player has an active objective.
-- @entity ply The player (defaults to LocalPlayer on client)
-- @treturn bool
-- @realm shared
function ix.diegeticHUD.HasObjective(ply)
	ply = ply or (CLIENT and LocalPlayer())

	if (!IsValid(ply)) then return false end

	return ply:GetNetVar("ixHasObjective", false)
end

--- Check if a player is in a squad.
-- @entity ply The player (defaults to LocalPlayer on client)
-- @treturn bool
-- @realm shared
function ix.diegeticHUD.IsInSquad(ply)
	ply = ply or (CLIENT and LocalPlayer())

	if (!IsValid(ply)) then return false end

	return ply:GetNetVar("ixInSquad", false)
end

--- Get a player's squad name.
-- @entity ply The player (defaults to LocalPlayer on client)
-- @treturn string Squad designation
-- @realm shared
function ix.diegeticHUD.GetSquadName(ply)
	ply = ply or (CLIENT and LocalPlayer())

	if (!IsValid(ply)) then return "" end

	return ply:GetNetVar("ixSquadName", "")
end
