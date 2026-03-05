--- Smart Disease — Server-Side Logic
-- Implements the core disease infection, curing, progression, transmission,
-- and symptom application on the server. Overrides the stub functions from
-- libs/sh_disease.lua with full implementations.
-- @module ix.disease (server)

local PLUGIN = PLUGIN

-- ═══════════════════════════════════════════════════════════════════════════════
-- NETWORKING
-- ═══════════════════════════════════════════════════════════════════════════════

util.AddNetworkString("ixDiseaseSync")
util.AddNetworkString("ixDiseaseNotify")
util.AddNetworkString("ixDiseaseSymptom")
util.AddNetworkString("ixDiseaseVisual")
util.AddNetworkString("ixDiseaseCured")
util.AddNetworkString("ixDiseaseSound")
util.AddNetworkString("ixDiseaseShadowStalker")
util.AddNetworkString("ixDiseaseClientEvent")

-- ═══════════════════════════════════════════════════════════════════════════════
-- INTERNAL HELPERS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Sync disease state to the owning client.
-- @param character table Helix character object
local function SyncDiseasesToClient(character)
    local client = character:GetPlayer()
    if (!IsValid(client)) then return end

    local diseases = ix.disease.GetActiveDiseases(character)

    net.Start("ixDiseaseSync")
        net.WriteTable(diseases)
    net.Send(client)
end

--- Send a notification to a player.
-- @param client Entity Player entity
-- @param message string Notification text
local function NotifyPlayer(client, message)
    if (!IsValid(client)) then return end

    net.Start("ixDiseaseNotify")
        net.WriteString(message)
    net.Send(client)
end

--- Broadcast a sound to nearby players.
-- @param origin Vector World position
-- @param soundPath string Sound file path
-- @param volume number 0-1
-- @param pitch number Pitch value
local function BroadcastSound(origin, soundPath, volume, pitch)
    local rangeSqr = ix.disease.Config.SOUND_BROADCAST_RANGE_SQR or 250000

    for _, ply in ipairs(player.GetAll()) do
        if (IsValid(ply) and ply:GetPos():DistToSqr(origin) <= rangeSqr) then
            net.Start("ixDiseaseSound")
                net.WriteString(soundPath)
                net.WriteFloat(volume or 0.5)
                net.WriteUInt(pitch or 100, 8)
            net.Send(ply)
        end
    end
end

--- Perform a /me action for a character.
-- @param character table Helix character
-- @param action string The action text (without "/me")
local function PerformMeAction(character, action)
    if (!ix.config.Get("diseaseMeActions", true)) then return end

    local client = character:GetPlayer()
    if (!IsValid(client)) then return end

    ix.chat.Send(client, "me", action)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CORE API IMPLEMENTATION
-- ═══════════════════════════════════════════════════════════════════════════════

--- Infect a character with a disease.
-- @param character table Helix character object
-- @param diseaseID string Disease identifier
-- @param force bool If true, bypasses immunity and max disease checks
-- @return bool, string Success and optional error message
function ix.disease.Infect(character, diseaseID, force)
    if (!ix.config.Get("diseaseEnabled", true)) then
        return false, "Disease system is disabled."
    end

    local disease = ix.disease.Get(diseaseID)
    if (!disease) then
        return false, "Unknown disease: " .. tostring(diseaseID)
    end

    -- Check if already infected
    if (ix.disease.HasDisease(character, diseaseID)) then
        return false, "Already infected with " .. diseaseID .. "."
    end

    -- Check vaccination unless forced
    if (!force and ix.disease.IsVaccinated(character, diseaseID)) then
        return false, "Character is vaccinated against " .. diseaseID .. "."
    end

    -- Check concurrent disease limit unless forced
    if (!force) then
        local active = ix.disease.GetActiveDiseases(character)
        local count = table.Count(active)
        if (count >= ix.disease.Config.MAX_CONCURRENT_DISEASES) then
            return false, "Maximum concurrent infections reached."
        end

        -- Check reinfection resistance (recently cured)
        local cureHistory = character:GetData("diseaseCureHistory", {})
        if (cureHistory[diseaseID]) then
            local elapsed = os.time() - (cureHistory[diseaseID] or 0)
            if (elapsed < 300) then -- 5 minute reinfection window
                local resistChance = ix.disease.Config.REINFECTION_RESISTANCE
                if (math.random() < resistChance) then
                    return false, "Reinfection resistance."
                end
            end
        end
    end

    -- Create infection record
    local diseases = ix.disease.GetActiveDiseases(character)
    diseases[diseaseID] = {
        stage = 1,
        infectedAt = CurTime(),
        lastProgression = CurTime(),
        treated = false,
        reversing = false,
    }

    character:SetData("diseases", diseases)

    -- Call disease callback
    if (disease.onInfection) then
        local client = character:GetPlayer()
        disease.onInfection(character, nil)
    end

    -- Notify the player
    local client = character:GetPlayer()
    if (IsValid(client)) then
        NotifyPlayer(client, "You feel strange... something isn't right.")
    end

    -- Sync to client
    SyncDiseasesToClient(character)

    -- Fire hook for other plugins
    hook.Run("SmartDiseaseInfected", character, diseaseID, disease)

    return true
end

--- Cure a character of a specific disease.
-- @param character table Helix character object
-- @param diseaseID string Disease identifier
function ix.disease.Cure(character, diseaseID)
    local diseases = ix.disease.GetActiveDiseases(character)
    if (!diseases[diseaseID]) then return end

    local disease = ix.disease.Get(diseaseID)

    -- Remove disease
    diseases[diseaseID] = nil
    character:SetData("diseases", diseases)

    -- Record cure history for reinfection resistance
    local cureHistory = character:GetData("diseaseCureHistory", {})
    cureHistory[diseaseID] = os.time()
    character:SetData("diseaseCureHistory", cureHistory)

    -- Clear any active speed reductions from this disease
    local client = character:GetPlayer()
    if (IsValid(client)) then
        -- Reset speed if this was causing a reduction
        ix.disease.RecalculateSpeed(character)
    end

    -- Call disease callback
    if (disease and disease.onCure) then
        disease.onCure(character)
    end

    -- Notify
    if (IsValid(client)) then
        NotifyPlayer(client, "You have recovered from " .. (disease and disease.name or diseaseID) .. ".")

        net.Start("ixDiseaseCured")
            net.WriteString(diseaseID)
        net.Send(client)
    end

    -- Sync
    SyncDiseasesToClient(character)

    -- Fire hook
    hook.Run("SmartDiseaseCured", character, diseaseID)
end

--- Cure a character of all active diseases.
-- @param character table Helix character object
function ix.disease.CureAll(character)
    local diseases = ix.disease.GetActiveDiseases(character)
    local cureHistory = character:GetData("diseaseCureHistory", {})

    for diseaseID, _ in pairs(diseases) do
        local disease = ix.disease.Get(diseaseID)
        if (disease and disease.onCure) then
            disease.onCure(character)
        end
        cureHistory[diseaseID] = os.time()
    end

    character:SetData("diseases", {})
    character:SetData("diseaseCureHistory", cureHistory)

    -- Reset speed
    ix.disease.RecalculateSpeed(character)

    local client = character:GetPlayer()
    if (IsValid(client)) then
        NotifyPlayer(client, "All diseases have been cured.")

        net.Start("ixDiseaseCured")
            net.WriteString("__all__")
        net.Send(client)
    end

    SyncDiseasesToClient(character)
    hook.Run("SmartDiseaseAllCured", character)
end

--- Vaccinate a character against a disease.
-- @param character table Helix character object
-- @param diseaseID string Disease identifier
function ix.disease.Vaccinate(character, diseaseID)
    local vaccines = ix.disease.GetVaccines(character)
    vaccines[diseaseID] = CurTime()
    character:SetData("vaccines", vaccines)

    local client = character:GetPlayer()
    if (IsValid(client)) then
        local disease = ix.disease.Get(diseaseID)
        NotifyPlayer(client, "You have been vaccinated against " .. (disease and disease.name or diseaseID) .. ".")
    end

    hook.Run("SmartDiseaseVaccinated", character, diseaseID)
end

--- Set the progression stage of a disease on a character.
-- @param character table Helix character object
-- @param diseaseID string Disease identifier
-- @param stage number Target stage number
function ix.disease.SetProgress(character, diseaseID, stage)
    local diseases = ix.disease.GetActiveDiseases(character)
    if (!diseases[diseaseID]) then return end

    local disease = ix.disease.Get(diseaseID)
    if (!disease) then return end

    -- Clamp stage
    stage = math.Clamp(stage, 1, #disease.stages)
    diseases[diseaseID].stage = stage
    diseases[diseaseID].lastProgression = CurTime()

    character:SetData("diseases", diseases)
    SyncDiseasesToClient(character)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SPEED MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════════

--- Recalculate a character's movement speed based on active symptom effects.
-- @param character table Helix character object
function ix.disease.RecalculateSpeed(character)
    local client = character:GetPlayer()
    if (!IsValid(client)) then return end

    local speedReduction = 0
    local diseases = ix.disease.GetActiveDiseases(character)

    for diseaseID, info in pairs(diseases) do
        local disease = ix.disease.Get(diseaseID)
        if (!disease) then continue end

        local stage = disease.stages[info.stage]
        if (!stage) then continue end

        for _, effect in ipairs(stage.effects) do
            if (effect.type == "symptom") then
                local symptom = ix.symptom.Get(effect.id)
                if (symptom and symptom.speedReduction) then
                    speedReduction = math.max(speedReduction, symptom.speedReduction)
                end
            end
        end
    end

    -- Apply speed reduction via character variable
    character:SetVar("diseaseSpeedMult", 1 - speedReduction)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DISEASE PROGRESSION ENGINE
-- ═══════════════════════════════════════════════════════════════════════════════

--- Process progression tick for all infected players.
-- Called periodically by the server tick timer.
function ix.disease.ProcessTick()
    if (!ix.config.Get("diseaseEnabled", true)) then return end

    local now = CurTime()
    local rateMultiplier = ix.config.Get("diseaseProgressionRate", 1.0)

    for _, client in ipairs(player.GetAll()) do
        if (!IsValid(client) or !client:Alive()) then continue end

        local character = client:GetCharacter()
        if (!character) then continue end

        local diseases = ix.disease.GetActiveDiseases(character)
        if (table.IsEmpty(diseases)) then continue end

        local modified = false

        for diseaseID, info in pairs(diseases) do
            local disease = ix.disease.Get(diseaseID)
            if (!disease) then continue end

            local currentStage = info.stage or 1
            local stageData = disease.stages[currentStage]
            if (!stageData) then continue end

            -- Apply current stage effects (symptoms, damage, etc.)
            ix.disease.ApplyStageEffects(character, disease, stageData, diseaseID)

            -- Check progression timing
            local delay = (disease.progressionDelay or 30) / rateMultiplier
            local elapsed = now - (info.lastProgression or 0)

            if (elapsed >= delay) then
                -- ═══ TREATED + REVERSING ═══
                if (info.treated and info.reversing) then
                    if (disease.chronic) then
                        -- Chronic diseases only reverse down to remission stage (not full cure)
                        local remStage = disease.remissionStage or 1
                        if (currentStage > remStage) then
                            currentStage = currentStage - 1
                            diseases[diseaseID].stage = currentStage
                            diseases[diseaseID].lastProgression = now
                            modified = true

                            if (disease.onStageProgression) then
                                disease.onStageProgression(character, currentStage)
                            end
                        else
                            -- Reached remission — disease lingers but is controlled
                            diseases[diseaseID].inRemission = true
                            diseases[diseaseID].reversing = false
                            diseases[diseaseID].lastProgression = now
                            modified = true

                            NotifyPlayer(client, "Your symptoms have subsided to a manageable level.")
                        end
                    else
                        -- Non-chronic: reverse towards full cure
                        if (currentStage > 1) then
                            currentStage = currentStage - 1
                            diseases[diseaseID].stage = currentStage
                            diseases[diseaseID].lastProgression = now
                            modified = true

                            if (disease.onStageProgression) then
                                disease.onStageProgression(character, currentStage)
                            end
                        else
                            -- Fully reversed = cured
                            ix.disease.Cure(character, diseaseID)
                            modified = false
                            break
                        end
                    end

                -- ═══ CHRONIC IN REMISSION — roll for flare-up ═══
                elseif (disease.chronic and info.inRemission) then
                    local flareChance = disease.flareChance or 5
                    if (math.random(100) <= flareChance) then
                        -- Flare-up: begin progressing again
                        diseases[diseaseID].inRemission = false
                        diseases[diseaseID].treated = false

                        local nextStage = currentStage + 1
                        if (nextStage <= #disease.stages) then
                            diseases[diseaseID].stage = nextStage
                            diseases[diseaseID].lastProgression = now
                            modified = true

                            NotifyPlayer(client, "Your symptoms are flaring up again...")

                            if (disease.onStageProgression) then
                                disease.onStageProgression(character, nextStage)
                            end
                        end
                    end

                -- ═══ CYCLING DISEASE (untreated) — oscillate between min and max ═══
                elseif (disease.cycleStages and !info.treated) then
                    local cyc = disease.cycleStages
                    local dir = info.cycleDirection or "up"

                    if (dir == "up") then
                        if (currentStage < cyc.max and currentStage < #disease.stages) then
                            currentStage = currentStage + 1
                            diseases[diseaseID].stage = currentStage
                            diseases[diseaseID].lastProgression = now
                            modified = true
                        else
                            -- Hit ceiling, reverse direction
                            diseases[diseaseID].cycleDirection = "down"
                            if (currentStage > cyc.min) then
                                currentStage = currentStage - 1
                                diseases[diseaseID].stage = currentStage
                                diseases[diseaseID].lastProgression = now
                                modified = true
                            end
                        end
                    else
                        if (currentStage > cyc.min) then
                            currentStage = currentStage - 1
                            diseases[diseaseID].stage = currentStage
                            diseases[diseaseID].lastProgression = now
                            modified = true
                        else
                            -- Hit floor, reverse direction
                            diseases[diseaseID].cycleDirection = "up"
                            if (currentStage < cyc.max and currentStage < #disease.stages) then
                                currentStage = currentStage + 1
                                diseases[diseaseID].stage = currentStage
                                diseases[diseaseID].lastProgression = now
                                modified = true
                            end
                        end
                    end

                    if (modified and disease.onStageProgression) then
                        disease.onStageProgression(character, diseases[diseaseID].stage)
                    end

                -- ═══ NORMAL FORWARD PROGRESSION ═══
                else
                    local nextStage = currentStage + 1

                    if (nextStage <= #disease.stages) then
                        local nextStageData = disease.stages[nextStage]

                        -- Check if terminal stage (natural recovery)
                        if (nextStageData.terminal) then
                            ix.disease.Cure(character, diseaseID)
                            modified = false
                            break
                        end

                        -- Check if lethal stage (death)
                        if (nextStageData.lethal) then
                            if (ix.config.Get("diseaseDamageEnabled", true)) then
                                client:Kill()
                                hook.Run("SmartDiseaseKilled", character, diseaseID)
                            end
                            ix.disease.Cure(character, diseaseID)
                            modified = false
                            break
                        end

                        diseases[diseaseID].stage = nextStage
                        diseases[diseaseID].lastProgression = now
                        modified = true

                        if (disease.onStageProgression) then
                            disease.onStageProgression(character, nextStage)
                        end
                    end
                end
            end
        end

        if (modified) then
            character:SetData("diseases", diseases)
            SyncDiseasesToClient(character)
            ix.disease.RecalculateSpeed(character)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- STAGE EFFECT APPLICATION
-- ═══════════════════════════════════════════════════════════════════════════════

--- Apply all effects from a disease stage to a character.
-- Effects are scattered probabilistically to avoid spam and feel more natural.
-- @param character table Helix character object
-- @param disease table Disease definition
-- @param stageData table Current stage definition
-- @param diseaseID string Disease identifier
function ix.disease.ApplyStageEffects(character, disease, stageData, diseaseID)
    local client = character:GetPlayer()
    if (!IsValid(client) or !client:Alive()) then return end

    local now = CurTime()
    local lastEffectTime = character:GetVar("sd_lastEffectApply_" .. diseaseID, 0)
    
    -- Only apply effects occasionally (every 15-30 seconds, spread out to avoid spam)
    if (now - lastEffectTime < 15) then return end

    for _, effect in ipairs(stageData.effects) do
        if (effect.type == "symptom") then
            -- 40% chance per symptom to fire (keeps it rare)
            if (math.random(100) <= 40) then
                ix.disease.ApplySymptom(character, effect.id, diseaseID)
            end
        elseif (effect.type == "damage") then
            if (ix.config.Get("diseaseDamageEnabled", true)) then
                -- Only apply damage once per interval, not repeatedly
                ix.disease.ApplyDamage(character, effect)
            end
        elseif (effect.type == "visual") then
            ix.disease.ApplyVisual(character, effect)
        elseif (effect.type == "cough") then
            -- Periodic cough with custom frequency
            local freq = effect.frequency or 15
            local lastCough = character:GetVar("lastCough_" .. diseaseID, 0)
            if (CurTime() - lastCough >= freq) then
                -- Only 60% chance to actually trigger
                if (math.random(100) <= 60) then
                    ix.disease.ApplySymptom(character, "cough", diseaseID)
                end
            end
        elseif (effect.type == "shadow_stalker") then
            -- Schizophrenia shadow stalker effect: rare creepy encounters
            if (math.random(100) <= 15) then -- 15% chance per tick
                ix.disease.TriggerShadowStalker(character, effect)
            end
        elseif (effect.type == "trigger_disease") then
            -- Chance to trigger a secondary disease (e.g., panic → schizophrenia)
            local chance = effect.chance or 5
            if (math.random(100) <= chance) then
                local targetDisease = effect.disease
                if (targetDisease and !ix.disease.HasDisease(character, targetDisease)) then
                    local success = ix.disease.Infect(character, targetDisease, true)
                    if (success and IsValid(client)) then
                        NotifyPlayer(client, effect.message or "Something has changed within you...")
                    end
                end
            end
        elseif (effect.type == "infectionRateModifier") then
            -- Stored as transient var, used by transmission
            character:SetVar("diseaseInfRateMod_" .. diseaseID, effect.value or 1.0)
        end
    end

    character:SetVar("sd_lastEffectApply_" .. diseaseID, now)
end

--- Apply a symptom to a character with cooldown checks.
-- @param character table Helix character object
-- @param symptomID string Symptom identifier
-- @param diseaseID string Disease identifier (for context)
function ix.disease.ApplySymptom(character, symptomID, diseaseID)
    local client = character:GetPlayer()
    if (!IsValid(client)) then return end

    local symptom = ix.symptom.Get(symptomID)
    if (!symptom) then return end

    -- Check cooldown (longer to space out messages and make them feel more natural/rare)
    local cooldown = symptom.cooldown or ix.config.Get("diseaseSymptomCooldown", 10)
    cooldown = math.max(cooldown, 20) -- Minimum 20 second cooldown between same symptom
    local lastAction = character:GetVar("sd_lastSymptom_" .. symptomID, 0)
    if (CurTime() - lastAction < cooldown) then
        return
    end

    character:SetVar("sd_lastSymptom_" .. symptomID, CurTime())

    -- Perform /me action
    if (symptom.me_actions and #symptom.me_actions > 0) then
        local action = symptom.me_actions[math.random(#symptom.me_actions)]
        PerformMeAction(character, action)
    end

    -- Show notification to the afflicted player
    if (symptom.message) then
        NotifyPlayer(client, symptom.message)
    end

    -- Play sound (supports table of paths for random selection)
    if (symptom.soundPath) then
        local path = symptom.soundPath
        if (istable(path)) then
            path = path[math.random(#path)]
        end
        BroadcastSound(client:GetPos(), path, symptom.soundVolume or 0.5, symptom.soundPitch or 100)
    end

    -- Dispatch particle effect
    if (symptom.effect) then
        local ed = EffectData()
        ed:SetEntity(client)
        ed:SetOrigin(client:GetPos())
        util.Effect(symptom.effect, ed, true, true)
    end

    -- Apply symptom damage
    if (symptom.damage and symptom.damage > 0) then
        if (ix.config.Get("diseaseDamageEnabled", true)) then
            local dmg = client:GetMaxHealth() * symptom.damage
            client:TakeDamage(dmg, client, client)
        end
    end

    -- Send visual effect to client
    if (symptom.visual) then
        ix.disease.ApplyVisual(character, symptom.visual)
    end

    -- Dispatch client event (heartbeat, phantom_sound, clone, eye_distort, etc.)
    if (symptom.clientEvent) then
        net.Start("ixDiseaseClientEvent")
            net.WriteString(symptom.clientEvent)
            net.WriteTable(symptom.clientEventData or {})
        net.Send(client)
    end

    -- Trigger contagion check
    if (symptom.contagionRange and symptom.contagionRange > 0 and ix.config.Get("diseaseSpreadEnabled", true)) then
        ix.disease.TrySpreadFromSymptom(character, diseaseID, symptom.contagionRange)
    end
end

--- Apply damage to a character from a disease effect.
-- @param character table Helix character object
-- @param effect table Effect config {amount, damageType}
function ix.disease.ApplyDamage(character, effect)
    local client = character:GetPlayer()
    if (!IsValid(client)) then return end

    local amount = effect.amount or 0
    if (effect.damageType == "percent") then
        amount = client:GetMaxHealth() * amount
    end

    if (amount > 0) then
        client:TakeDamage(amount, client, client)
    end
end

--- Apply a visual effect to a character's client.
-- @param character table Helix character object
-- @param visualConfig table Visual configuration
function ix.disease.ApplyVisual(character, visualConfig)
    local client = character:GetPlayer()
    if (!IsValid(client)) then return end

    net.Start("ixDiseaseVisual")
        net.WriteTable(visualConfig)
    net.Send(client)
end

--- Trigger the shadow stalker effect (schizophrenia horror).
-- @param character table Helix character object
-- @param effect table Effect configuration
function ix.disease.TriggerShadowStalker(character, effect)
    local client = character:GetPlayer()
    if (!IsValid(client)) then return end

    -- Randomly choose between spawning in front (85%) or to the side (15%)
    local spawnInFront = math.random(100) <= 85

    net.Start("ixDiseaseShadowStalker")
        net.WriteBool(spawnInFront)
    net.Send(client)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TRANSMISSION ENGINE
-- ═══════════════════════════════════════════════════════════════════════════════

--- Attempt to spread a disease from a symptomatic character to nearby players.
-- Triggered when a contagion symptom fires (cough, sneeze, etc.).
-- @param character table Infected character
-- @param diseaseID string Disease to spread
-- @param range number Contagion range in Source units
function ix.disease.TrySpreadFromSymptom(character, diseaseID, range)
    if (!ix.config.Get("diseaseSpreadEnabled", true)) then return end

    local disease = ix.disease.Get(diseaseID)
    if (!disease or !disease.contagious) then return end

    local client = character:GetPlayer()
    if (!IsValid(client)) then return end

    local pos = client:GetPos()
    local rangeSqr = range * range
    local infectionRate = (disease.infectionRate or 10) * ix.config.Get("diseaseInfectionRate", 1.0)

    -- Check infection rate modifier from stage effects
    local rateMod = character:GetVar("diseaseInfRateMod_" .. diseaseID, 1.0)
    infectionRate = infectionRate * rateMod

    for _, target in ipairs(player.GetAll()) do
        if (!IsValid(target) or target == client or !target:Alive()) then continue end

        if (target:GetPos():DistToSqr(pos) > rangeSqr) then continue end

        local targetChar = target:GetCharacter()
        if (!targetChar) then continue end

        -- Roll for infection
        if (math.random(100) <= infectionRate) then
            ix.disease.Infect(targetChar, diseaseID, false)
        end
    end
end

--- Attempt passive proximity (breathing) transmission.
-- Called during the main tick for players with airborne diseases.
-- @param character table Infected character
-- @param diseaseID string Disease to spread
function ix.disease.TryPassiveSpread(character, diseaseID)
    if (!ix.config.Get("diseaseSpreadEnabled", true)) then return end

    local disease = ix.disease.Get(diseaseID)
    if (!disease or !disease.contagious) then return end
    if (!disease.vectors or !disease.vectors.air) then return end

    -- Check if disease is past incubation period
    local info = ix.disease.GetActiveDiseases(character)[diseaseID]
    if (!info) then return end
    if ((info.stage or 1) < (disease.baseIncubation or 1)) then return end

    local client = character:GetPlayer()
    if (!IsValid(client)) then return end

    local contactRange = ix.config.Get("diseaseContactRange", 80)
    local pos = client:GetPos()
    local rangeSqr = contactRange * contactRange

    -- Passive spread has a much lower infection rate
    local passiveRate = (disease.infectionRate or 10) * 0.1 * ix.config.Get("diseaseInfectionRate", 1.0)

    for _, target in ipairs(player.GetAll()) do
        if (!IsValid(target) or target == client or !target:Alive()) then continue end

        if (target:GetPos():DistToSqr(pos) > rangeSqr) then continue end

        local targetChar = target:GetCharacter()
        if (!targetChar) then continue end

        if (math.random(100) <= passiveRate) then
            ix.disease.Infect(targetChar, diseaseID, false)
        end
    end
end

--- Handle damage-vector transmission when a player takes damage.
-- @param victim Entity Victim player
-- @param attacker Entity Attacker player
function ix.disease.OnPlayerDamaged(victim, attacker)
    if (!ix.config.Get("diseaseSpreadEnabled", true)) then return end
    if (!IsValid(attacker) or !attacker:IsPlayer()) then return end

    local attackerChar = attacker:GetCharacter()
    if (!attackerChar) then return end

    local diseases = ix.disease.GetActiveDiseases(attackerChar)
    for diseaseID, info in pairs(diseases) do
        local disease = ix.disease.Get(diseaseID)
        if (!disease or !disease.vectors or !disease.vectors.damage) then continue end

        -- Only spread if past incubation
        if ((info.stage or 1) < (disease.baseIncubation or 1)) then continue end

        local victimChar = victim:GetCharacter()
        if (!victimChar) then continue end

        local rate = (disease.infectionRate or 10) * 0.5 * ix.config.Get("diseaseInfectionRate", 1.0)
        if (math.random(100) <= rate) then
            ix.disease.Infect(victimChar, diseaseID, false)
        end
    end
end

--- Handle collision-vector transmission.
-- @param client Entity Player who collided
-- @param other Entity Other entity
function ix.disease.OnPlayerCollision(client, other)
    if (!ix.config.Get("diseaseSpreadEnabled", true)) then return end
    if (!IsValid(other) or !other:IsPlayer()) then return end

    local clientChar = client:GetCharacter()
    local otherChar = other:GetCharacter()
    if (!clientChar or !otherChar) then return end

    -- Check both directions
    ix.disease.TryCollisionSpread(clientChar, otherChar)
    ix.disease.TryCollisionSpread(otherChar, clientChar)
end

--- Try spreading diseases from one character to another via collision.
-- @param fromChar table Source character
-- @param toChar table Target character
function ix.disease.TryCollisionSpread(fromChar, toChar)
    local diseases = ix.disease.GetActiveDiseases(fromChar)

    for diseaseID, info in pairs(diseases) do
        local disease = ix.disease.Get(diseaseID)
        if (!disease or !disease.vectors or !disease.vectors.collision) then continue end

        if ((info.stage or 1) < (disease.baseIncubation or 1)) then continue end

        local rate = (disease.infectionRate or 10) * 0.3 * ix.config.Get("diseaseInfectionRate", 1.0)
        if (math.random(100) <= rate) then
            ix.disease.Infect(toChar, diseaseID, false)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MEDICINE / TREATMENT
-- ═══════════════════════════════════════════════════════════════════════════════

--- Apply medicine to a character, treating diseases of the matching type.
-- @param character table Helix character object
-- @param medicineType string Medicine type (e.g. "antiviral", "antibiotic", "antipsychotic")
-- @return bool Whether any disease was treated
function ix.disease.ApplyMedicine(character, medicineType)
    local diseases = ix.disease.GetActiveDiseases(character)
    local treated = false

    for diseaseID, info in pairs(diseases) do
        local disease = ix.disease.Get(diseaseID)
        if (!disease) then continue end

        if (disease.cureWith and disease.cureWith[medicineType]) then
            diseases[diseaseID].treated = true
            diseases[diseaseID].reversing = true
            treated = true
        end
    end

    if (treated) then
        character:SetData("diseases", diseases)
        SyncDiseasesToClient(character)

        local client = character:GetPlayer()
        if (IsValid(client)) then
            NotifyPlayer(client, "The medicine begins to take effect.")
        end
    end

    return treated
end

--- Track medicine usage for overdose system.
-- @param character table Helix character object
-- @param medicineType string Medicine type
-- @return bool Whether the character is now overdosing
function ix.disease.TrackMedicineUse(character, medicineType)
    local history = character:GetVar("sd_medHistory", {})
    local now = CurTime()
    local window = ix.disease.Config.OVERDOSE_WINDOW

    -- Clean old entries
    local cleanHistory = {}
    for _, entry in ipairs(history) do
        if (now - entry.time < window) then
            cleanHistory[#cleanHistory + 1] = entry
        end
    end

    -- Add new entry
    cleanHistory[#cleanHistory + 1] = {type = medicineType, time = now}
    character:SetVar("sd_medHistory", cleanHistory)

    -- Count doses in window
    local count = 0
    for _, entry in ipairs(cleanHistory) do
        count = count + 1
    end

    if (count >= ix.disease.Config.OVERDOSE_THRESHOLD) then
        -- Apply overdose effects
        local client = character:GetPlayer()
        if (IsValid(client)) then
            NotifyPlayer(client, "You feel dizzy from taking too much medicine...")
            ix.disease.ApplySymptom(character, "dizziness", "overdose")
            ix.disease.ApplySymptom(character, "nausea", "overdose")
        end
        return true
    end

    return false
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CHARACTER LIFECYCLE
-- ═══════════════════════════════════════════════════════════════════════════════

--- Called when a character is saved (pre-save hook).
-- Persists disease and vaccine data.
function PLUGIN:CharacterPreSave(character)
    -- Data is already persisted via character:SetData calls.
    -- This hook exists for any additional cleanup needed.
end

--- Called when a player loads a character.
-- Restores disease state and applies initial effects.
function PLUGIN:PlayerLoadedCharacter(client, character, lastChar)
    -- Clean up last character's disease state if needed
    if (lastChar) then
        lastChar:SetVar("diseaseSpeedMult", nil)
    end

    -- Load active diseases and recalculate state
    local diseases = ix.disease.GetActiveDiseases(character)
    if (!table.IsEmpty(diseases)) then
        ix.disease.RecalculateSpeed(character)
        SyncDiseasesToClient(character)
    end
end

--- Called when a player disconnects.
function PLUGIN:PlayerDisconnected(client)
    -- Character data is auto-saved by Helix.
end
