--- Smart Disease — Server-Side Hooks
-- Registers all server-side hooks for the disease progression engine,
-- transmission, player lifecycle, and movement speed modification.
-- @module smartdisease.sv_hooks

local PLUGIN = PLUGIN

-- ═══════════════════════════════════════════════════════════════════════════════
-- DISEASE TICK TIMER
-- ═══════════════════════════════════════════════════════════════════════════════

--- Initialise the disease progression timer on server start.
function PLUGIN:InitializedPlugins()
    local interval = ix.config.Get("diseaseTickInterval", 3)

    timer.Create("ixDisease.ProgressionTick", interval, 0, function()
        ix.disease.ProcessTick()
    end)

    -- Passive airborne spread check (runs every 5 seconds, offset from main tick)
    timer.Create("ixDisease.PassiveSpread", 5, 0, function()
        if (!ix.config.Get("diseaseEnabled", true)) then return end
        if (!ix.config.Get("diseaseSpreadEnabled", true)) then return end

        for _, client in ipairs(player.GetAll()) do
            if (!IsValid(client) or !client:Alive()) then continue end

            local character = client:GetCharacter()
            if (!character) then continue end

            local diseases = ix.disease.GetActiveDiseases(character)
            for diseaseID, _ in pairs(diseases) do
                ix.disease.TryPassiveSpread(character, diseaseID)
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MOVEMENT SPEED MODIFICATION
-- ═══════════════════════════════════════════════════════════════════════════════

--- Modify character walk and run speed based on active disease effects.
function PLUGIN:CharacterGetWalkSpeed(character, speed)
    local mult = character:GetVar("diseaseSpeedMult", 1)
    if (mult < 1) then
        return speed * mult
    end
end

--- Modify character run speed.
function PLUGIN:CharacterGetRunSpeed(character, speed)
    local mult = character:GetVar("diseaseSpeedMult", 1)
    if (mult < 1) then
        return speed * mult
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DAMAGE HOOKS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Handle damage-based disease transmission.
function PLUGIN:EntityTakeDamage(entity, dmgInfo)
    if (!entity:IsPlayer()) then return end

    local attacker = dmgInfo:GetAttacker()
    if (!IsValid(attacker) or !attacker:IsPlayer()) then return end

    ix.disease.OnPlayerDamaged(entity, attacker)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- PLAYER LIFECYCLE HOOKS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Handle player death — optionally clear diseases on death.
function PLUGIN:PlayerDeath(client, inflictor, attacker)
    local character = client:GetCharacter()
    if (!character) then return end

    -- Don't auto-cure on death; diseases persist across respawn.
    -- Uncomment below to clear on death:
    -- ix.disease.CureAll(character)
end

--- Handle player spawn — re-sync disease state.
function PLUGIN:PlayerSpawn(client)
    timer.Simple(1, function()
        if (!IsValid(client)) then return end

        local character = client:GetCharacter()
        if (!character) then return end

        local diseases = ix.disease.GetActiveDiseases(character)
        if (!table.IsEmpty(diseases)) then
            ix.disease.RecalculateSpeed(character)

            net.Start("ixDiseaseSync")
                net.WriteTable(diseases)
            net.Send(client)
        end
    end)
end

--- Handle player collision (ShouldCollide alternative via Touch).
function PLUGIN:ShouldCollide(entA, entB)
    -- Collision-based disease spread via proximity check in passive tick
    -- instead of collision callback to avoid performance issues.
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CONFIGURATION CHANGE HOOKS
-- ═══════════════════════════════════════════════════════════════════════════════

--- React to config changes at runtime.
function PLUGIN:ConfigSet(key, oldValue, newValue)
    if (key == "diseaseTickInterval") then
        -- Restart the tick timer with the new interval
        if (timer.Exists("ixDisease.ProgressionTick")) then
            timer.Remove("ixDisease.ProgressionTick")
        end

        timer.Create("ixDisease.ProgressionTick", newValue, 0, function()
            ix.disease.ProcessTick()
        end)
    elseif (key == "diseaseEnabled" and !newValue) then
        -- System disabled: stop timers
        if (timer.Exists("ixDisease.ProgressionTick")) then
            timer.Remove("ixDisease.ProgressionTick")
        end
        if (timer.Exists("ixDisease.PassiveSpread")) then
            timer.Remove("ixDisease.PassiveSpread")
        end
    elseif (key == "diseaseEnabled" and newValue) then
        -- System re-enabled: restart timers
        PLUGIN:InitializedPlugins()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLEANUP ON PLUGIN UNLOAD
-- ═══════════════════════════════════════════════════════════════════════════════

function PLUGIN:OnRemoved()
    if (timer.Exists("ixDisease.ProgressionTick")) then
        timer.Remove("ixDisease.ProgressionTick")
    end

    if (timer.Exists("ixDisease.PassiveSpread")) then
        timer.Remove("ixDisease.PassiveSpread")
    end
end
