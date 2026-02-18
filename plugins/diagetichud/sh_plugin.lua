local PLUGIN = PLUGIN

PLUGIN.name = "Diegetic HUD"
PLUGIN.author = "Copilot"
PLUGIN.description = "An immersive, diegetic Imperial HUD system with transparent overlays for health, weapon, compass, comms, squad, and mission status."

ix.util.Include("libs/sh_api.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")


ix.command.Add("HUDSetDEFCON", {
	description = "Set the DEFCON level (1-5).",
	adminOnly = true,
	arguments = {
		ix.type.number
	},
	OnRun = function(self, ply, level)
		level = math.Clamp(math.floor(level), 1, 5)

		ix.diegeticHUD.SetDEFCON(level)
		ply:Notify("DEFCON set to " .. level .. ".")
	end
})

ix.command.Add("HUDPriority", {
	description = "Set a priority order transmission.",
	adminOnly = true,
	arguments = {
		ix.type.text
	},
	OnRun = function(self, ply, text)
		ix.diegeticHUD.SetPriorityOrder(text, "HIGH COMMAND", "Code Black")
		ply:Notify("Priority order set: " .. text)
	end
})

ix.command.Add("HUDPriorityClear", {
	description = "Clear the current priority order.",
	adminOnly = true,
	OnRun = function(self, ply)
		ix.diegeticHUD.ClearPriorityOrder()
		ply:Notify("Priority order cleared.")
	end
})

ix.command.Add("HUDObjective", {
	description = "Set an objective for yourself.",
	adminOnly = true,
	arguments = {
		ix.type.text
	},
	OnRun = function(self, ply, text)
		ix.diegeticHUD.SetObjective(ply, text, "Report status to command")
		ply:Notify("Objective set: " .. text)
	end
})

ix.command.Add("HUDObjectiveClear", {
	description = "Clear your current objective.",
	adminOnly = true,
	OnRun = function(self, ply)
		ix.diegeticHUD.ClearObjective(ply)
		ply:Notify("Objective cleared.")
	end
})

ix.command.Add("HUDGlobalObjective", {
	description = "Set an objective for all players.",
	adminOnly = true,
	arguments = {
		ix.type.text
	},
	OnRun = function(self, ply, text)
		ix.diegeticHUD.SetGlobalObjective(text, "Report status to command")
		ply:Notify("Global objective set: " .. text)
	end
})

ix.command.Add("HUDWaypoint", {
	description = "Add a waypoint at your aim position.",
	adminOnly = true,
	arguments = {
		ix.type.text
	},
	OnRun = function(self, ply, label)
		local tr = ply:GetEyeTrace()

		ix.diegeticHUD.AddWaypoint(ply, "test_" .. label, label, tr.HitPos, "TGT")
		ply:Notify("Waypoint '" .. label .. "' added.")
	end
})

ix.command.Add("HUDThreat", {
	description = "Add a threat waypoint at your aim position.",
	adminOnly = true,
	arguments = {
		ix.type.text
	},
	OnRun = function(self, ply, label)
		local tr = ply:GetEyeTrace()

		ix.diegeticHUD.AddWaypoint(ply, "thr_" .. label, label, tr.HitPos, "THR")
		ply:Notify("Threat '" .. label .. "' added.")
	end
})

ix.command.Add("HUDWaypointClear", {
	description = "Remove a waypoint by label.",
	adminOnly = true,
	arguments = {
		ix.type.text
	},
	OnRun = function(self, ply, label)
		ix.diegeticHUD.RemoveWaypoint(ply, "test_" .. label)
		ix.diegeticHUD.RemoveWaypoint(ply, "thr_" .. label)
		ply:Notify("Waypoint '" .. label .. "' removed.")
	end
})

ix.command.Add("HUDSquadCreate", {
	description = "Create a test squad with nearby players.",
	adminOnly = true,
	arguments = {
		bit.bor(ix.type.text, ix.type.optional)
	},
	OnRun = function(self, ply, name)
		name = name or "FIRETEAM AUREK"

		-- Gather nearby players
		local members = {ply}

		for _, other in ipairs(player.GetAll()) do
			if (other != ply and other:GetPos():DistToSqr(ply:GetPos()) < 1000 * 1000) then
				table.insert(members, other)

				if (#members >= 4) then break end
			end
		end

		ix.diegeticHUD.CreateSquad("test_squad", name, members)
		ply:Notify("Squad '" .. name .. "' created with " .. #members .. " members.")
	end
})

ix.command.Add("HUDSquadDisband", {
	description = "Disband the test squad.",
	adminOnly = true,
	OnRun = function(self, ply)
		ix.diegeticHUD.DisbandSquad("test_squad")
		ply:Notify("Test squad disbanded.")
	end
})

ix.command.Add("HUDSquadBogus", {
	description = "Add a bogus member to your squad HUD.",
	adminOnly = true,
	arguments = {
		bit.bor(ix.type.text, ix.type.optional)
	},
	OnRun = function(self, ply, name)
		if (!ix.diegeticHUD.IsInSquad(ply)) then
			ply:Notify("You are not in a squad.")
			return
		end

		local bogusName = name or ("AUX-" .. string.format("%02d", math.random(1, 99)))
		local health = math.random(35, 95)
		local maxHealth = 100
		local pos = ply:GetPos() + ply:GetForward() * 220 + ply:GetRight() * 60
		local alive = health > 0
		local id = tostring(math.floor(CurTime() * 1000)) .. "_" .. tostring(math.random(100, 999))

		net.Start("ixDiegeticSquadBogus")
			net.WriteString(id)
			net.WriteString(bogusName)
			net.WriteUInt(math.Clamp(health, 0, 255), 8)
			net.WriteUInt(math.Clamp(maxHealth, 0, 255), 8)
			net.WriteVector(pos)
			net.WriteBool(alive)
		net.Send(ply)

		ply:Notify("Bogus squad member added: " .. bogusName)
	end
})

ix.command.Add("HUDTransmission", {
	description = "Simulate a comms transmission.",
	adminOnly = true,
	arguments = {
		bit.bor(ix.type.text, ix.type.optional)
	},
	OnRun = function(self, ply, channel)
		channel = channel or "COMMAND NET"

		ix.diegeticHUD.SendTransmission(ply, channel, "8858.0", true, 4)
		ply:Notify("Simulated transmission on " .. channel .. ".")
	end
})

ix.command.Add("HUDVoiceBox", {
	description = "Toggle forcing the voice transmit box on your HUD.",
	adminOnly = true,
	OnRun = function(self, ply)
		local enabled = !ply:GetNetVar("ixForceVoiceBox", false)

		ply:SetNetVar("ixForceVoiceBox", enabled)
		ply:Notify("Voice transmit box " .. (enabled and "enabled" or "disabled") .. ".")
	end
})

ix.command.Add("HUDTestAll", {
	description = "Enable all HUD test elements at once.",
	adminOnly = true,
	OnRun = function(self, ply)
		ix.diegeticHUD.SetDEFCON(2)
		ix.diegeticHUD.SetPriorityOrder("SECURE HANGAR BAY 3", "ISS VENGEANCE // CMDR TARKIN", "Hostile infiltration - Code Black")
		ix.diegeticHUD.SetObjective(ply, "Patrol Sector 7-G", "Report anomalies to command")

		local tr = ply:GetEyeTrace()

		ix.diegeticHUD.AddWaypoint(ply, "test_checkpoint", "CHECKPOINT-7", tr.HitPos + Vector(500, 0, 0), "TGT")
		ix.diegeticHUD.AddWaypoint(ply, "thr_hostile", "HOSTILE-ALPHA", tr.HitPos + Vector(-300, 200, 0), "THR")

		-- Create test squad
		local members = {ply}

		for _, other in ipairs(player.GetAll()) do
			if (other != ply) then
				table.insert(members, other)

				if (#members >= 4) then break end
			end
		end

		ix.diegeticHUD.CreateSquad("test_squad", "FIRETEAM AUREK", members)

		timer.Simple(1, function()
			if (IsValid(ply)) then
				ix.diegeticHUD.SendTransmission(ply, "COMMAND NET", "8858.0", true, 4)
			end
		end)

		ply:Notify("All HUD test elements activated.")
	end
})

ix.command.Add("HUDTestClear", {
	description = "Clear all HUD test elements.",
	adminOnly = true,
	OnRun = function(self, ply)
		ix.diegeticHUD.SetDEFCON(5)
		ix.diegeticHUD.ClearPriorityOrder()
		ix.diegeticHUD.ClearObjective(ply)
		ix.diegeticHUD.RemoveWaypoint(ply, "test_checkpoint")
		ix.diegeticHUD.RemoveWaypoint(ply, "thr_hostile")
		ix.diegeticHUD.DisbandSquad("test_squad")

		ply:Notify("All HUD test elements cleared.")
	end
})
