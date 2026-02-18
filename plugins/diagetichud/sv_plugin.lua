--- Imperial Diegetic HUD - Server Plugin
-- Handles damage direction networking, squad sync timer, and admin test commands.

local PLUGIN = PLUGIN


resource.AddFile("resource/fonts/ocr-aregular.ttf")

-- ═══════════════════════════════════════════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:InitializedPlugins()
	-- Default to DEFCON 5 if not set
	if (GetGlobalInt("ixDEFCON", 0) == 0) then
		ix.diegeticHUD.SetDEFCON(5)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DAMAGE DIRECTION TRACKING
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:EntityTakeDamage(entity, dmgInfo)
	if (!entity:IsPlayer()) then return end

	local attacker = dmgInfo:GetAttacker()

	if (IsValid(attacker) and attacker != entity) then
		ix.diegeticHUD.NotifyDamageDirection(entity, attacker)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- PERIODIC SQUAD SYNC
-- ═══════════════════════════════════════════════════════════════════════════════

timer.Create("ixDiegeticSquadSync", 2, 0, function()
	for id, _ in pairs(ix.diegeticHUD.squads or {}) do
		ix.diegeticHUD.SyncSquad(id)
	end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- ADMIN TESTING COMMANDS
-- ═══════════════════════════════════════════════════════════════════════════════

