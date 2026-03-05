--- Imperial Comms System - Default Channel Configuration
-- Define your radio channels here. Channels appear in the order they are defined.
-- Each channel needs: Name, Talkers (teams), Listeners (teams), GetTalkers (func),
-- GetListeners (func), Mutable, and a Color.

-- ═══════════════════════════════════════════════════════════════════════════════
-- IMPERIAL CHANNELS
-- ═══════════════════════════════════════════════════════════════════════════════

-- COMMAND NET - Officers and high command
ix.comms.AddChannel({
	Name = "COMMAND NET",
	Talkers = {},
	Listeners = {},
	GetTalkers = function(ply)
		-- Allow admins or players with command access
		if (ply:IsAdmin()) then return true end

		-- Check for officer-class characters (customize per your schema)
		local char = ply:GetCharacter()
		if (char) then
			local classID = char:GetClass()
			if (classID and classID > 0 and ix.class.list[classID]) then
				local className = string.lower(ix.class.list[classID].name or "")
				if (string.find(className, "officer") or string.find(className, "commander")
					or string.find(className, "captain") or string.find(className, "admiral")
					or string.find(className, "general") or string.find(className, "colonel")
					or string.find(className, "major")) then
					return true
				end
			end
		end

		return false
	end,
	GetListeners = function(ply)
		return true -- All players can receive command broadcasts
	end,
	Mutable = true,
	MutedByDefault = false,
	Colour = Color(228, 175, 42), -- Imperial gold/amber
	Encrypted = true,
	Frequency = "8858.0",
	Description = "Secure command frequency for officer communications"
})

-- SQUAD COMMS - Fireteam/squad level
ix.comms.AddChannel({
	Name = "SQUAD COMMS",
	Talkers = {},
	Listeners = {},
	GetTalkers = function(ply) return true end,
	GetListeners = function(ply) return true end,
	Mutable = true,
	MutedByDefault = false,
	Colour = Color(70, 185, 100), -- Green
	Encrypted = true,
	Frequency = "4521.5",
	Description = "Encrypted squad-level tactical communications"
})

-- LOGISTICS - Supply and coordination
ix.comms.AddChannel({
	Name = "LOGISTICS",
	Talkers = {},
	Listeners = {},
	GetTalkers = function(ply) return true end,
	GetListeners = function(ply) return true end,
	Mutable = true,
	MutedByDefault = true,
	Colour = Color(84, 168, 255), -- Cyan/blue
	Encrypted = false,
	Frequency = "7799.2",
	Description = "Open logistics and supply coordination"
})

-- EMERGENCY - Distress and emergency channel
ix.comms.AddChannel({
	Name = "EMERGENCY",
	Talkers = {},
	Listeners = {},
	GetTalkers = function(ply) return true end,
	GetListeners = function(ply) return true end,
	Mutable = false, -- Cannot mute emergency channel
	MutedByDefault = false,
	Colour = Color(255, 55, 55), -- Red
	Encrypted = true,
	Frequency = "3366.8",
	Description = "Priority emergency distress frequency"
})

-- PSA / ADMIN - Server announcements
ix.comms.AddChannel({
	Name = "PRIORITY BROADCAST",
	Talkers = {},
	Listeners = {},
	GetTalkers = function(ply) return ply:IsAdmin() end,
	GetListeners = function(ply) return true end,
	Mutable = false,
	MutedByDefault = false,
	Colour = Color(255, 222, 40), -- Yellow
	Encrypted = false,
	Frequency = "0001.0",
	Description = "Server-wide priority announcements"
})
