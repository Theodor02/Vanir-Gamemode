--- Effect Type Registry & Application
-- Defines all effect types, their metadata, display formatters, and server-side application logic.
-- Uses a proper registration system for extensibility.
-- v2.2: Adds 6 tail effect types for the Metabolic Cascade system.
-- @module ix.bacta.effectTypes

ix.bacta.effectTypes = ix.bacta.effectTypes or {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- EFFECT TYPE REGISTRATION
-- ═══════════════════════════════════════════════════════════════════════════════

--- Register a new effect type with metadata and handlers.
-- @param id string Unique effect type identifier
-- @param data table Effect type definition containing:
--   name (string), description (string), color (Color),
--   isSideEffect (bool), isTailEffect (bool), format (function), icon (string)
function ix.bacta.RegisterEffectType(id, data)
    data.id = id
    ix.bacta.effectTypes[id] = data
end

--- Get the human-readable display string for an effect instance.
-- @param eff table Effect instance {type, magnitude, duration, ...}
-- @return string Formatted display string
function ix.bacta.EffectToString(eff)
    local effectType = ix.bacta.effectTypes[eff.type]
    if (!effectType) then return eff.type end
    if (effectType.format) then return effectType.format(eff) end
    return effectType.name or eff.type
end

--- Check if an effect type is a side effect / adverse response.
-- @param effectTypeID string Effect type key
-- @return bool
function ix.bacta.IsSideEffect(effectTypeID)
    local et = ix.bacta.effectTypes[effectTypeID]
    return et and et.isSideEffect or false
end

--- Check if an effect type is a tail effect (v2.2 Metabolic Cascade).
-- @param effectTypeID string Effect type key
-- @return bool
function ix.bacta.IsTailEffect(effectTypeID)
    local et = ix.bacta.effectTypes[effectTypeID]
    return et and et.isTailEffect or false
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- EFFECT TYPE DEFINITIONS
-- ═══════════════════════════════════════════════════════════════════════════════

-- ─── Beneficial Effects ──────────────────────────────────────────────────────

ix.bacta.RegisterEffectType("heal_hp", {
    name         = "Health Restoration",
    description  = "Instantly restores hit points.",
    color        = Color(100, 255, 100),
    isSideEffect = false,
    format = function(eff)
        return string.format("+%d HP (instant)", math.floor(eff.magnitude))
    end,
})

ix.bacta.RegisterEffectType("regen_hp", {
    name         = "Health Regeneration",
    description  = "Restores hit points over time at a fixed tick rate.",
    color        = Color(100, 255, 150),
    isSideEffect = false,
    format = function(eff)
        local tick = eff.tick_rate or 5
        return string.format("+%d HP / %ds for %ds", math.floor(eff.magnitude), tick, eff.duration or 0)
    end,
})

ix.bacta.RegisterEffectType("heal_bleed", {
    name         = "Haemorrhage Treatment",
    description  = "Clears active bleeding status.",
    color        = Color(255, 120, 120),
    isSideEffect = false,
    format = function(eff)
        return "Clears bleeding"
    end,
})

ix.bacta.RegisterEffectType("heal_toxin", {
    name         = "Toxin Purge",
    description  = "Neutralises systemic toxins and poisons.",
    color        = Color(150, 255, 100),
    isSideEffect = false,
    format = function(eff)
        return "Purges toxins"
    end,
})

ix.bacta.RegisterEffectType("buff_speed", {
    name         = "Movement Enhancement",
    description  = "Temporarily increases movement speed.",
    color        = Color(80, 200, 255),
    isSideEffect = false,
    format = function(eff)
        return string.format("+%d%% speed for %ds", math.floor(eff.magnitude * 100), eff.duration or 0)
    end,
})

ix.bacta.RegisterEffectType("buff_armor", {
    name         = "Damage Reduction",
    description  = "Flat damage reduction from incoming attacks.",
    color        = Color(180, 180, 255),
    isSideEffect = false,
    format = function(eff)
        return string.format("-%d damage taken for %ds", math.floor(eff.magnitude), eff.duration or 0)
    end,
})

ix.bacta.RegisterEffectType("buff_focus", {
    name         = "Neural Focus",
    description  = "Reduces weapon recoil and sway.",
    color        = Color(200, 220, 255),
    isSideEffect = false,
    format = function(eff)
        return string.format("+%d%% focus for %ds", math.floor(eff.magnitude * 100), eff.duration or 0)
    end,
})

ix.bacta.RegisterEffectType("stim_stamina", {
    name         = "Stamina Restoration",
    description  = "Restores stamina/endurance reserves.",
    color        = Color(255, 220, 80),
    isSideEffect = false,
    format = function(eff)
        return string.format("+%d stamina", math.floor(eff.magnitude))
    end,
})

ix.bacta.RegisterEffectType("suppress_pain", {
    name         = "Pain Suppression",
    description  = "Reduces incoming damage for a short duration.",
    color        = Color(200, 180, 255),
    isSideEffect = false,
    format = function(eff)
        return string.format("-%d%% damage for %ds", math.floor(eff.magnitude * 100), eff.duration or 0)
    end,
})

-- ─── Adverse Biochemical Responses (Side Effects) ────────────────────────────

ix.bacta.RegisterEffectType("side_nausea", {
    name         = "Nausea",
    description  = "Accuracy and focus debuff from gastrointestinal distress.",
    color        = Color(200, 200, 50),
    isSideEffect = true,
    format = function(eff)
        return string.format("-%d%% accuracy for %ds", math.floor(eff.magnitude * 100), eff.duration or 0)
    end,
})

ix.bacta.RegisterEffectType("side_tremor", {
    name         = "Tremor",
    description  = "Periodic involuntary screen shake from neural instability.",
    color        = Color(255, 180, 50),
    isSideEffect = true,
    format = function(eff)
        return string.format("Tremor (severity %d) for %ds", math.floor(eff.magnitude), eff.duration or 0)
    end,
})

ix.bacta.RegisterEffectType("side_fatigue", {
    name         = "Fatigue",
    description  = "Movement speed penalty from metabolic exhaustion.",
    color        = Color(180, 150, 100),
    isSideEffect = true,
    format = function(eff)
        return string.format("-%d%% speed for %ds", math.floor(eff.magnitude * 100), eff.duration or 0)
    end,
})

ix.bacta.RegisterEffectType("side_cardiac", {
    name         = "Cardiac Stress",
    description  = "Periodic HP drain from cardiovascular strain.",
    color        = Color(255, 60, 60),
    isSideEffect = true,
    format = function(eff)
        local tick = eff.tick_rate or 5
        return string.format("-%d HP / %ds for %ds", math.floor(eff.magnitude), tick, eff.duration or 0)
    end,
})

-- ─── Tail Effects (v2.2 — Metabolic Cascade) ────────────────────────────────
-- Tail effects are delayed adverse reactions triggered after a compound's
-- primary effects begin. They can be metabolised by Metaboliser strands.

ix.bacta.RegisterEffectType("tail_metabolic_crash", {
    name         = "Metabolic Crash",
    description  = "Post-stimulant metabolic collapse. Speed reduction and compounded fatigue.",
    color        = Color(200, 120, 50),
    isSideEffect = true,
    isTailEffect = true,
    format = function(eff)
        return string.format("Metabolic Crash: -20%% speed, x1.5 fatigue for %ds", eff.duration or 12)
    end,
})

ix.bacta.RegisterEffectType("tail_neural_static", {
    name         = "Neural Static",
    description  = "Synaptic noise from receptor clearance. Focus impairment and mild nausea.",
    color        = Color(180, 180, 80),
    isSideEffect = true,
    isTailEffect = true,
    format = function(eff)
        return string.format("Neural Static: -30%% focus, mild nausea for %ds", eff.duration or 8)
    end,
})

ix.bacta.RegisterEffectType("tail_vascular_spike", {
    name         = "Vascular Spike",
    description  = "Acute cardiovascular strain from enzymatic acceleration. Periodic cardiac damage.",
    color        = Color(255, 50, 50),
    isSideEffect = true,
    isTailEffect = true,
    format = function(eff)
        return string.format("Vascular Spike: -3 HP/tick for %ds", eff.duration or 6)
    end,
})

ix.bacta.RegisterEffectType("tail_adrenal_dump", {
    name         = "Adrenal Dump",
    description  = "Cortisol overload from sustained adrenal stimulation. Tremor and speed loss.",
    color        = Color(220, 150, 50),
    isSideEffect = true,
    isTailEffect = true,
    format = function(eff)
        return string.format("Adrenal Dump: tremor, -10%% speed for %ds", eff.duration or 10)
    end,
})

ix.bacta.RegisterEffectType("tail_hepatic_load", {
    name         = "Hepatic Load",
    description  = "Liver strain from metabolic byproducts. Slow toxin accumulation.",
    color        = Color(160, 200, 60),
    isSideEffect = true,
    isTailEffect = true,
    format = function(eff)
        return string.format("Hepatic Load: toxin build-up for %ds", eff.duration or 15)
    end,
})

ix.bacta.RegisterEffectType("tail_synaptic_rebound", {
    name         = "Synaptic Rebound",
    description  = "Neural overshoot from deep cellular repair. Focus loss and visual distortion.",
    color        = Color(170, 130, 220),
    isSideEffect = true,
    isTailEffect = true,
    format = function(eff)
        return string.format("Synaptic Rebound: -20%% focus, visual distortion for %ds", eff.duration or 8)
    end,
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- SERVER-SIDE EFFECT APPLICATION
-- ═══════════════════════════════════════════════════════════════════════════════

if (SERVER) then
    --- Apply a complete effect profile to a player.
    -- @param client Entity The target player
    -- @param profile table The output profile {effects, stability, item_type, uses}
    function ix.bacta.ApplyEffectProfile(client, profile)
        if (!IsValid(client) or !client:IsPlayer() or !client:Alive()) then return end

        for _, eff in ipairs(profile.effects or {}) do
            local effectType = ix.bacta.effectTypes[eff.type]

            if (effectType and effectType.apply) then
                effectType.apply(client, eff)
            end
        end
    end

    --- Apply a temporary character variable with automatic expiry.
    -- Stacks additively with existing values and cleans up after duration.
    -- @param client Entity Target player
    -- @param key string Character variable key
    -- @param value number Value to add
    -- @param duration number Duration in seconds
    function ix.bacta.ApplyTempVar(client, key, value, duration)
        local char = client:GetCharacter()
        if (!char) then return end

        local charID = char:GetID()
        local current = char:GetVar(key, 0)
        char:SetVar(key, current + value)

        if (key == "bactaSpeedBuff" or key == "bactaFatigue") then
            ix.bacta.UpdateSpeedModifier(client)
        end

        local timerID = "ixBacta_" .. key .. "_" .. client:EntIndex() .. "_" .. CurTime()
        timer.Create(timerID, duration, 1, function()
            if (IsValid(client) and client:GetCharacter() and client:GetCharacter():GetID() == charID) then
                local cur = client:GetCharacter():GetVar(key, 0)
                local newVal = cur - value
                if math.abs(newVal) < 0.001 then newVal = 0 end -- floating point precision fix
                client:GetCharacter():SetVar(key, math.max(0, newVal))

                if (key == "bactaSpeedBuff" or key == "bactaFatigue") then
                    ix.bacta.UpdateSpeedModifier(client)
                end
            end
        end)
    end

    --- Notify the client about an active effect for HUD display.
    -- @param client Entity Target player
    -- @param eff table Effect instance
    function ix.bacta.NotifyEffect(client, eff)
        net.Start("ixBactaEffect")
            net.WriteString(eff.type)
            net.WriteFloat(eff.magnitude or 0)
            net.WriteFloat(eff.duration or 0)
        net.Send(client)
    end

    -- ─── Apply Functions Per Effect Type ─────────────────────────────────────

    ix.bacta.effectTypes["heal_hp"].apply = function(client, eff)
        local mag = math.floor(eff.magnitude)
        client:SetHealth(math.Clamp(client:Health() + mag, 0, client:GetMaxHealth()))
        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["regen_hp"].apply = function(client, eff)
        local tickRate = eff.tick_rate or 5
        local ticks = math.floor((eff.duration or 0) / tickRate)
        local mag = math.floor(eff.magnitude)
        local timerID = "ixBacta_regen_" .. client:EntIndex() .. "_" .. CurTime()

        timer.Create(timerID, tickRate, ticks, function()
            if (IsValid(client) and client:Alive()) then
                client:SetHealth(math.Clamp(client:Health() + mag, 0, client:GetMaxHealth()))
            end
        end)

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["heal_bleed"].apply = function(client, eff)
        local char = client:GetCharacter()
        if (char) then
            char:SetVar("is_bleeding", false)
        end

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["heal_toxin"].apply = function(client, eff)
        local char = client:GetCharacter()
        if (char) then
            char:SetVar("toxin_level", 0)
        end

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["buff_speed"].apply = function(client, eff)
        ix.bacta.ApplyTempVar(client, "bactaSpeedBuff", eff.magnitude, eff.duration or 10)
        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["buff_armor"].apply = function(client, eff)
        ix.bacta.ApplyTempVar(client, "bactaArmorBuff", eff.magnitude, eff.duration or 10)
        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["buff_focus"].apply = function(client, eff)
        ix.bacta.ApplyTempVar(client, "bactaFocusBuff", eff.magnitude, eff.duration or 10)
        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["stim_stamina"].apply = function(client, eff)
        local char = client:GetCharacter()
        if (char) then
            local stam = char:GetVar("stamina", 100)
            char:SetVar("stamina", math.min(100, stam + eff.magnitude))
        end

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["suppress_pain"].apply = function(client, eff)
        ix.bacta.ApplyTempVar(client, "bactaPainSuppress", eff.magnitude, eff.duration or 10)
        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["side_nausea"].apply = function(client, eff)
        ix.bacta.ApplyTempVar(client, "bactaNausea", eff.magnitude, eff.duration or 10)
        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["side_tremor"].apply = function(client, eff)
        local severity = math.Clamp(math.floor(eff.magnitude), 1, 5)
        local dur = eff.duration or 10
        local timerID = "ixBacta_tremor_" .. client:EntIndex() .. "_" .. CurTime()

        ix.bacta.ApplyTempVar(client, "bactaTremor", severity, dur)

        timer.Create(timerID, 2, math.floor(dur / 2), function()
            if (IsValid(client) and client:Alive()) then
                util.ScreenShake(client:GetPos(), severity * 2, severity * 3, 0.5, 100)
            end
        end)

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["side_fatigue"].apply = function(client, eff)
        ix.bacta.ApplyTempVar(client, "bactaFatigue", eff.magnitude, eff.duration or 10)
        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["side_cardiac"].apply = function(client, eff)
        local tickRate = eff.tick_rate or 5
        local ticks = math.floor((eff.duration or 0) / tickRate)
        local mag = math.floor(eff.magnitude)
        local timerID = "ixBacta_cardiac_" .. client:EntIndex() .. "_" .. CurTime()

        timer.Create(timerID, tickRate, ticks, function()
            if (IsValid(client) and client:Alive()) then
                client:SetHealth(math.max(1, client:Health() - mag))
            end
        end)

        ix.bacta.NotifyEffect(client, eff)
    end

    -- ─── Tail Effect Apply Functions (v2.2) ──────────────────────────────────

    ix.bacta.effectTypes["tail_metabolic_crash"].apply = function(client, eff)
        local dur = eff.duration or 12

        -- Speed -20% via runspeed plugin if available
        if (client.UpdateRunSpeedModifier and client.SpeedModifiers) then
            client:UpdateRunSpeedModifier("bactaTailCrash", ix.plugin.list.runspeed.ModifierTypes.MULT, 0.80) -- MULT type
            client:UpdateWalkSpeedModifier("bactaTailCrash", ix.plugin.list.runspeed.ModifierTypes.MULT, 0.80)

            timer.Create("ixBacta_tailCrash_speed_" .. client:EntIndex(), dur, 1, function()
                if (IsValid(client) and client.RemoveRunSpeedModifier and client.SpeedModifiers) then
                    if client.SpeedModifiers.run and client.SpeedModifiers.run["bactaTailCrash"] then
                        client:RemoveRunSpeedModifier("bactaTailCrash")
                    end
                    if client.SpeedModifiers.walk and client.SpeedModifiers.walk["bactaTailCrash"] then
                        client:RemoveWalkSpeedModifier("bactaTailCrash")
                    end
                end
            end)
        else
            -- Fallback: use character variable
            ix.bacta.ApplyTempVar(client, "bactaFatigue", 0.20, dur)
        end

        -- Fatigue multiplier: amplify existing fatigue by x1.5
        local char = client:GetCharacter()
        if (char) then
            local currentFatigue = char:GetVar("bactaFatigue", 0)
            if (currentFatigue > 0) then
                local extraFatigue = currentFatigue * 0.5
                ix.bacta.ApplyTempVar(client, "bactaFatigue", extraFatigue, dur)
            end
        end

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["tail_neural_static"].apply = function(client, eff)
        local dur = eff.duration or 8

        -- Focus -30%
        ix.bacta.ApplyTempVar(client, "bactaFocusBuff", -0.30, dur)

        -- Mild nausea
        ix.bacta.ApplyTempVar(client, "bactaNausea", 0.15, dur)

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["tail_vascular_spike"].apply = function(client, eff)
        local dur = eff.duration or 6
        local tickRate = 2
        local ticks = math.floor(dur / tickRate)
        local timerID = "ixBacta_tailVascular_" .. client:EntIndex() .. "_" .. CurTime()

        timer.Create(timerID, tickRate, ticks, function()
            if (IsValid(client) and client:Alive()) then
                client:SetHealth(math.max(1, client:Health() - 3))
            end
        end)

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["tail_adrenal_dump"].apply = function(client, eff)
        local dur = eff.duration or 10

        -- Tremor (severity 2)
        ix.bacta.ApplyTempVar(client, "bactaTremor", 2, dur)

        local tremTimerID = "ixBacta_tailTremor_" .. client:EntIndex() .. "_" .. CurTime()
        timer.Create(tremTimerID, 2, math.floor(dur / 2), function()
            if (IsValid(client) and client:Alive()) then
                util.ScreenShake(client:GetPos(), 4, 6, 0.5, 100)
            end
        end)

        -- Speed -10% via runspeed plugin
        if (client.UpdateRunSpeedModifier and client.SpeedModifiers) then
            client:UpdateRunSpeedModifier("bactaTailAdrenal", ix.plugin.list.runspeed.ModifierTypes.MULT, 0.90)
            client:UpdateWalkSpeedModifier("bactaTailAdrenal", ix.plugin.list.runspeed.ModifierTypes.MULT, 0.90)

            timer.Create("ixBacta_tailAdrenal_speed_" .. client:EntIndex(), dur, 1, function()
                if (IsValid(client) and client.RemoveRunSpeedModifier and client.SpeedModifiers) then
                    if client.SpeedModifiers.run and client.SpeedModifiers.run["bactaTailAdrenal"] then
                        client:RemoveRunSpeedModifier("bactaTailAdrenal")
                    end
                    if client.SpeedModifiers.walk and client.SpeedModifiers.walk["bactaTailAdrenal"] then
                        client:RemoveWalkSpeedModifier("bactaTailAdrenal")
                    end
                end
            end)
        else
            ix.bacta.ApplyTempVar(client, "bactaFatigue", 0.10, dur)
        end

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["tail_hepatic_load"].apply = function(client, eff)
        local dur = eff.duration or 15
        local tickRate = 5
        local ticks = math.floor(dur / tickRate)
        local timerID = "ixBacta_tailHepatic_" .. client:EntIndex() .. "_" .. CurTime()

        timer.Create(timerID, tickRate, ticks, function()
            if (IsValid(client) and client:Alive()) then
                local char = client:GetCharacter()
                if (char) then
                    local toxin = char:GetVar("toxin_level", 0)
                    char:SetVar("toxin_level", math.min(toxin + 0.5, 10))
                end
            end
        end)

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["tail_synaptic_rebound"].apply = function(client, eff)
        local dur = eff.duration or 8

        -- Focus -20%
        ix.bacta.ApplyTempVar(client, "bactaFocusBuff", -0.20, dur)

        -- Visual distortion: stronger nausea-like wobble
        ix.bacta.ApplyTempVar(client, "bactaNausea", 0.25, dur)

        ix.bacta.NotifyEffect(client, eff)
    end

    --- Schedule a tail effect with the specified delay.
    -- Called by sv_cascade.lua after metaboliser resolution.
    -- @param client Entity Target player
    -- @param tailType string Tail effect type ID
    -- @param delay number Seconds before tail activates
    -- @param duration number Duration of the tail effect
    -- @param severity string Severity label (low/moderate/high)
    function ix.bacta.ScheduleTailEffect(client, tailType, delay, duration, severity)
        if (!IsValid(client) or !client:IsPlayer()) then return end

        local effectType = ix.bacta.effectTypes[tailType]
        if (!effectType or !effectType.apply) then return end

        local timerID = "ixBacta_tailSchedule_" .. tailType .. "_" .. client:EntIndex() .. "_" .. CurTime()

        timer.Create(timerID, delay, 1, function()
            if (IsValid(client) and client:Alive()) then
                effectType.apply(client, {
                    type      = tailType,
                    magnitude = 1,
                    duration  = duration,
                    severity  = severity,
                })
            end
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SHARED HOOKS — Movement Speed Integration
-- Integrates with the runspeed plugin when available, falls back to SetupMove.
-- Speed buffs (buff_speed) and fatigue (side_fatigue) use proper modifiers.
-- ═══════════════════════════════════════════════════════════════════════════════

if (SERVER) then
    --- Update a player's bacta speed modifier via the runspeed plugin.
    -- Called after ApplyTempVar changes bactaSpeedBuff or bactaFatigue.
    -- @param client Entity Target player
    function ix.bacta.UpdateSpeedModifier(client)
        if (!IsValid(client) or !client:IsPlayer()) then return end

        local char = client:GetCharacter()
        if (!char) then return end

        local speedBuff = char:GetVar("bactaSpeedBuff", 0)
        local fatigue   = char:GetVar("bactaFatigue", 0)
        local mult      = 1.0 + speedBuff - fatigue

        if (math.abs(mult - 1.0) < 0.001) then
            -- No modifier needed, remove if exists
            if (client.RemoveRunSpeedModifier and client.SpeedModifiers) then
                if client.SpeedModifiers.run and client.SpeedModifiers.run["bactaSpeed"] then
                    client:RemoveRunSpeedModifier("bactaSpeed")
                end
                if client.SpeedModifiers.walk and client.SpeedModifiers.walk["bactaSpeed"] then
                    client:RemoveWalkSpeedModifier("bactaSpeed")
                end
            end
            return
        end

        mult = math.max(0.3, mult)

        if (client.UpdateRunSpeedModifier and client.SpeedModifiers) then
            -- Use runspeed plugin's modifier system (ModifierType MULT = 1)
            client:UpdateRunSpeedModifier("bactaSpeed", ix.plugin.list.runspeed.ModifierTypes.MULT, mult)
            client:UpdateWalkSpeedModifier("bactaSpeed", ix.plugin.list.runspeed.ModifierTypes.MULT, mult)
        end
    end

    -- Watch for character variable changes to update speed modifiers
    hook.Add("CharacterVarChanged", "ixBactaSpeedSync", function(char, key, oldVal, newVal)
        if (key == "bactaSpeedBuff" or key == "bactaFatigue") then
            local client = char:GetPlayer()
            if (IsValid(client)) then
                ix.bacta.UpdateSpeedModifier(client)
            end
        end
    end)

    -- Re-apply speed modifiers on spawn/loadout since runspeed plugin resets them
    hook.Add("PlayerLoadout", "ixBactaSpeedSyncLoadout", function(client)
        timer.Simple(0.1, function()
            if (IsValid(client)) then
                ix.bacta.UpdateSpeedModifier(client)
            end
        end)
    end)
end

-- Fallback SetupMove for prediction when runspeed plugin is not available
hook.Add("SetupMove", "ixBactaSpeedMods", function(ply, mv)
    -- Skip if runspeed plugin is handling this
    if (ix.plugin.list.runspeed) then return end

    local char = ply:GetCharacter()
    if (!char) then return end

    local speedBuff = char:GetVar("bactaSpeedBuff", 0)
    local fatigue   = char:GetVar("bactaFatigue", 0)
    local mult      = 1.0 + speedBuff - fatigue

    if (mult != 1.0) then
        mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * math.max(0.3, mult))
        mv:SetMaxSpeed(mv:GetMaxSpeed() * math.max(0.3, mult))
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- SERVER HOOKS — Damage Modification
-- ═══════════════════════════════════════════════════════════════════════════════

if (SERVER) then
    hook.Add("EntityTakeDamage", "ixBactaDamageModifiers", function(target, dmgInfo)
        if (!target:IsPlayer()) then return end

        local char = target:GetCharacter()
        if (!char) then return end

        -- Pain suppression: percentage damage reduction
        local suppress = char:GetVar("bactaPainSuppress", 0)
        if (suppress > 0) then
            dmgInfo:ScaleDamage(1.0 - math.Clamp(suppress, 0, 0.75))
        end

        -- Armor buff: flat damage reduction
        local armor = char:GetVar("bactaArmorBuff", 0)
        if (armor > 0) then
            dmgInfo:SubtractDamage(armor)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLIENT EFFECTS — Visual Feedback
-- ═══════════════════════════════════════════════════════════════════════════════

if (CLIENT) then
    --- Active effect tracking for HUD display.
    ix.bacta.activeEffects = ix.bacta.activeEffects or {}

    net.Receive("ixBactaEffect", function()
        local effectType = net.ReadString()
        local magnitude  = net.ReadFloat()
        local duration   = net.ReadFloat()

        local isTail = ix.bacta.IsTailEffect(effectType)

        if (duration > 0) then
            ix.bacta.activeEffects[#ix.bacta.activeEffects + 1] = {
                type       = effectType,
                magnitude  = magnitude,
                duration   = duration,
                startTime  = CurTime(),
                endTime    = CurTime() + duration,
                isTailEffect = isTail,
            }
        end
    end)

    --- Clean expired effects from the active list.
    function ix.bacta.CleanActiveEffects()
        local now = CurTime()

        for i = #ix.bacta.activeEffects, 1, -1 do
            if (now >= ix.bacta.activeEffects[i].endTime) then
                table.remove(ix.bacta.activeEffects, i)
            end
        end
    end

    --- Get all currently active tail effects for HUD display.
    -- @return table Array of active tail effect entries
    function ix.bacta.GetActiveTailEffects()
        local result = {}
        local now = CurTime()

        for _, eff in ipairs(ix.bacta.activeEffects) do
            if (eff.isTailEffect and now < eff.endTime) then
                result[#result + 1] = eff
            end
        end

        return result
    end

    -- Nausea visual: subtle view angle wobble (also covers tail_neural_static, tail_synaptic_rebound)
    hook.Add("CalcView", "ixBactaNauseaView", function(ply, pos, angles, fov)
        local char = ply:GetCharacter()
        if (!char) then return end

        local nausea = char:GetVar("bactaNausea", 0)
        if (nausea > 0) then
            local time = CurTime()
            local wobble = nausea * 3

            angles.roll = angles.roll + math.sin(time * 2.5) * wobble
            angles.pitch = angles.pitch + math.cos(time * 1.8) * wobble * 0.4

            return {origin = pos, angles = angles, fov = fov}
        end
    end)
end
