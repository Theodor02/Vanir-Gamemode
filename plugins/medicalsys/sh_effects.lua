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
-- CUSTOM PLAYER EFFECTS TYPES (registered via player_effects plugin)
-- Deferred until all plugins are loaded so ix.playerEffects is available.
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("InitializedPlugins", "ixBactaCustomEffectTypes", function()
    local PE   = ix.playerEffects
    local MULT = PE.MOD_MULT
    local ADD  = PE.MOD_ADD

    PE.RegisterEffectType("combat.focus", {
        name      = "Combat Focus",
        baseValue = 1,
        min       = 0,
        modTypes  = {MULT, ADD},
    })

    PE.RegisterEffectType("visual.nausea", {
        name      = "Nausea",
        baseValue = 0,
        min       = 0,
        max       = 2,
        calcOrder = "add_first",
        modTypes  = {ADD},
    })

    PE.RegisterEffectType("visual.tremor", {
        name      = "Tremor",
        baseValue = 0,
        min       = 0,
        max       = 5,
        calcOrder = "add_first",
        modTypes  = {ADD},
    })

    PE.RegisterEffectType("visual.vignette", {
        name      = "Vignette",
        baseValue = 0,
        min       = 0,
        max       = 1,
        calcOrder = "add_first",
        modTypes  = {ADD},
    })

    PE.RegisterEffectType("visual.bloom", {
        name      = "Bloom",
        baseValue = 0,
        min       = 0,
        max       = 2,
        calcOrder = "add_first",
        modTypes  = {ADD},
    })

    PE.RegisterEffectType("visual.desaturate", {
        name      = "Desaturation",
        baseValue = 0,
        min       = 0,
        max       = 1,
        calcOrder = "add_first",
        modTypes  = {ADD},
    })

    PE.RegisterEffectType("visual.screen_flicker", {
        name      = "Screen Flicker",
        baseValue = 0,
        min       = 0,
        max       = 10,
        calcOrder = "add_first",
        modTypes  = {ADD},
    })

    PE.RegisterEffectType("visual.water_warp", {
        name      = "Visual Distortion",
        baseValue = 0,
        min       = 0,
        max       = 1,
        calcOrder = "add_first",
        modTypes  = {ADD},
    })

    PE.RegisterEffectType("visual.sharpen", {
        name      = "Sharpened Vision",
        baseValue = 0,
        min       = 0,
        max       = 2,
        calcOrder = "add_first",
        modTypes  = {ADD},
    })

    PE.RegisterEffectType("audio.heartbeat", {
        name      = "Heartbeat",
        baseValue = 0,
        min       = 0,
        max       = 1,
        calcOrder = "add_first",
        modTypes  = {ADD},
    })
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- SERVER-SIDE EFFECT APPLICATION
-- ═══════════════════════════════════════════════════════════════════════════════

if (SERVER) then

    -- Resolved lazily: player_effects may not be loaded yet (medicalsys < player_effects alphabetically).
    -- The upvalues are populated by InitializedPlugins before any apply function can be called.
    local PE, MULT, ADD

    hook.Add("InitializedPlugins", "ixBactaEffectsInit", function()
        PE   = ix.playerEffects
        MULT = PE.MOD_MULT
        ADD  = PE.MOD_ADD
    end)

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
    -- Used for display-only variables that have no mechanical effect.
    -- @param client Entity Target player
    -- @param key string Character variable key
    -- @param value number Value to add
    -- @param duration number Duration in seconds
    function ix.bacta.ApplyTempDisplay(client, key, value, duration)
        local char = client:GetCharacter()
        if (!char) then return end

        local charID = char:GetID()
        local current = char:GetVar(key, 0)
        char:SetVar(key, current + value)

        local timerID = "ixBacta_" .. key .. "_" .. client:EntIndex() .. "_" .. CurTime()
        timer.Create(timerID, duration, 1, function()
            if (IsValid(client) and client:GetCharacter() and client:GetCharacter():GetID() == charID) then
                local cur = client:GetCharacter():GetVar(key, 0)
                local newVal = cur - value
                if math.abs(newVal) < 0.001 then newVal = 0 end
                client:GetCharacter():SetVar(key, math.max(0, newVal))
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
        local mag = math.floor(eff.magnitude)
        local rate = mag / tickRate
        local dur = eff.duration or 0

        client:AddEffect("health.regen_rate", "bactaRegen", ADD, rate, {
            duration        = dur,
            priority        = 5,
            layer           = "buff",
            refreshBehavior = "extend",
            metadata        = {source = "bacta"},
        })

        -- Soft green color tint while regenerating
        client:AddEffect("visual.color_tint", "bactaRegenTint", PE.MOD_SET, Color(80, 255, 120, 30), {
            duration = dur,
            priority = 2,
            layer    = "buff",
            refreshBehavior = "extend",
        })

        -- Subtle bloom glow — healing warmth
        client:AddEffect("visual.bloom", "bactaRegenBloom", ADD, 0.2, {
            duration = dur,
            priority = 2,
            layer    = "buff",
            refreshBehavior = "extend",
        })

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
        local dur = eff.duration or 10

        client:AddEffect("speed.run", "bactaSpeedBuff", MULT, 1.0 + eff.magnitude, {
            duration        = dur,
            priority        = 5,
            layer           = "buff",
            refreshBehavior = "extend",
            metadata        = {source = "bacta"},
        })
        client:AddEffect("speed.walk", "bactaSpeedBuff", MULT, 1.0 + eff.magnitude, {
            duration        = dur,
            priority        = 5,
            layer           = "buff",
            refreshBehavior = "extend",
        })

        -- Cool blue-white tint — adrenaline rush clarity
        client:AddEffect("visual.color_tint", "bactaSpeedTint", PE.MOD_SET, Color(160, 210, 255, 25), {
            duration = dur,
            priority = 3,
            layer    = "buff",
            refreshBehavior = "extend",
        })

        -- Slight sharpened perception
        client:AddEffect("visual.sharpen", "bactaSpeedSharpen", ADD, 0.3, {
            duration = dur,
            priority = 2,
            layer    = "buff",
            refreshBehavior = "extend",
        })

        -- Adrenaline injection sound
        client:EmitSound("items/medshot4.wav", 60, 110, 0.4)

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["buff_armor"].apply = function(client, eff)
        client:AddEffect("armor.base", "bactaArmorBuff", ADD, eff.magnitude, {
            duration        = eff.duration or 10,
            priority        = 5,
            layer           = "buff",
            refreshBehavior = "highest",
            metadata        = {source = "bacta"},
        })

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["buff_focus"].apply = function(client, eff)
        local dur = eff.duration or 10

        client:AddEffect("combat.focus", "bactaFocusBuff", MULT, 1.0 + eff.magnitude, {
            duration        = dur,
            priority        = 5,
            layer           = "buff",
            refreshBehavior = "extend",
            metadata        = {source = "bacta"},
        })

        -- Heightened clarity — sharpen vision and slight desaturate for crisp look
        client:AddEffect("visual.sharpen", "bactaFocusSharpen", ADD, 0.5, {
            duration = dur,
            priority = 3,
            layer    = "buff",
            refreshBehavior = "extend",
        })
        client:AddEffect("visual.desaturate", "bactaFocusDesat", ADD, 0.08, {
            duration = dur,
            priority = 1,
            layer    = "buff",
            refreshBehavior = "extend",
        })

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
        local reduction = math.Clamp(eff.magnitude, 0, 0.75)
        local dur = eff.duration or 10

        client:AddEffect("damage.taken", "bactaPainSuppress", MULT, 1.0 - reduction, {
            duration        = dur,
            priority        = 5,
            layer           = "buff",
            refreshBehavior = "extend",
            metadata        = {source = "bacta"},
        })

        -- Numbing effect — slight desaturation and vignette (tunnel focus)
        client:AddEffect("visual.desaturate", "bactaPainDesat", ADD, 0.12 * reduction, {
            duration = dur,
            priority = 2,
            layer    = "buff",
            refreshBehavior = "extend",
        })
        client:AddEffect("visual.vignette", "bactaPainVignette", ADD, 0.08 * reduction, {
            duration = dur,
            priority = 2,
            layer    = "buff",
            refreshBehavior = "extend",
        })

        -- Muffled audio — pain suppression dulls hearing
        client:AddEffect("audio.muffled", "bactaPainMuffle", MULT, math.max(0.7, 1.0 - reduction * 0.4), {
            duration = dur,
            priority = 3,
            layer    = "buff",
            refreshBehavior = "extend",
        })

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["side_nausea"].apply = function(client, eff)
        local dur = eff.duration or 10
        local mag = eff.magnitude or 0.1

        client:AddEffect("visual.nausea", "bactaNausea", ADD, mag, {
            duration        = dur,
            priority        = 3,
            layer           = "debuff",
            refreshBehavior = "extend",
            metadata        = {source = "bacta"},
        })

        -- Sickly green color tint
        client:AddEffect("visual.color_tint", "bactaNauseaTint", PE.MOD_SET, Color(140, 200, 100, 50), {
            duration = dur,
            priority = 5,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Motion blur — world is swimming
        client:AddEffect("visual.blur", "bactaNauseaBlur", ADD, math.Clamp(mag * 0.4, 0.05, 0.4), {
            duration = dur,
            priority = 3,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Wavy distortion
        client:AddEffect("visual.water_warp", "bactaNauseaWarp", ADD, math.Clamp(mag * 0.3, 0.05, 0.3), {
            duration = dur,
            priority = 3,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Nausea gag/groan sounds
        local nauseaSounds = {
            "vo/npc/male01/pain04.wav",
            "vo/npc/male01/pain05.wav",
            "vo/npc/male01/pain06.wav",
        }
        client:EmitSound(nauseaSounds[math.random(#nauseaSounds)], 55, 90, 0.35)

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["side_tremor"].apply = function(client, eff)
        local severity = math.Clamp(math.floor(eff.magnitude), 1, 5)
        local dur = eff.duration or 10

        client:AddEffect("visual.tremor", "bactaTremor", ADD, severity, {
            duration        = dur,
            priority        = 3,
            layer           = "debuff",
            refreshBehavior = "extend",
            metadata        = {source = "bacta", severity = severity},
            onTick = function(ply, remaining)
                if (ply:Alive()) then
                    util.ScreenShake(ply:GetPos(), severity * 2, severity * 3, 0.5, 100)
                    -- Occasional pain grunt during tremors
                    if (math.random() < 0.15) then
                        local painSounds = {
                            "vo/npc/male01/pain01.wav",
                            "vo/npc/male01/pain02.wav",
                            "vo/npc/male01/pain03.wav",
                        }
                        ply:EmitSound(painSounds[math.random(#painSounds)], 55, math.random(95, 110), 0.3)
                    end
                end
            end,
        })

        -- Visual blur proportional to severity
        client:AddEffect("visual.blur", "bactaTremorBlur", ADD, severity * 0.06, {
            duration = dur,
            priority = 3,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Screen flicker at high severity
        if (severity >= 3) then
            client:AddEffect("visual.screen_flicker", "bactaTremorFlicker", ADD, severity * 0.4, {
                duration = dur,
                priority = 3,
                layer    = "debuff",
                refreshBehavior = "extend",
            })
        end

        -- Initial pain sound on application
        client:EmitSound("vo/npc/male01/pain07.wav", 60, 100, 0.35)

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["side_fatigue"].apply = function(client, eff)
        local dur = eff.duration or 10
        local mag = eff.magnitude or 0.05

        client:AddEffect("speed.run", "bactaFatigue", MULT, 1.0 - mag, {
            duration        = dur,
            priority        = 5,
            layer           = "debuff",
            refreshBehavior = "stack_duration",
            metadata        = {source = "bacta"},
        })
        client:AddEffect("speed.walk", "bactaFatigue", MULT, 1.0 - mag, {
            duration        = dur,
            priority        = 5,
            layer           = "debuff",
            refreshBehavior = "stack_duration",
        })

        -- World drains of colour — exhaustion desaturation
        client:AddEffect("visual.desaturate", "bactaFatigueDesat", ADD, math.Clamp(mag * 2.5, 0.08, 0.35), {
            duration = dur,
            priority = 3,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Dark vignette — tunnel vision from exhaustion
        client:AddEffect("visual.vignette", "bactaFatigueVignette", ADD, math.Clamp(mag * 1.5, 0.05, 0.2), {
            duration = dur,
            priority = 3,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Heavy breathing sound
        client:EmitSound("npc/zombie/zombie_voice_idle1.wav", 50, 140, 0.25)

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["side_cardiac"].apply = function(client, eff)
        local tickRate = eff.tick_rate or 5
        local mag = math.floor(eff.magnitude)
        local rate = -(mag / tickRate)
        local dur = eff.duration or 0

        client:AddEffect("health.regen_rate", "bactaCardiac", ADD, rate, {
            duration        = dur,
            priority        = 3,
            layer           = "debuff",
            refreshBehavior = "stack_duration",
            metadata        = {source = "bacta"},
        })

        -- Pulsing red vignette — cardiovascular strain
        client:AddEffect("visual.vignette", "bactaCardiacVignette", ADD, 0.15, {
            duration = dur,
            priority = 4,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Red pain tint
        client:AddEffect("visual.color_tint", "bactaCardiacTint", PE.MOD_SET, Color(255, 80, 80, 40), {
            duration = dur,
            priority = 5,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Pounding heartbeat
        client:AddEffect("audio.heartbeat", "bactaCardiacBeat", ADD, 0.6, {
            duration = dur,
            priority = 4,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Screen flicker — cardiac distress
        client:AddEffect("visual.screen_flicker", "bactaCardiacFlicker", ADD, 1.5, {
            duration = dur,
            priority = 3,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Initial cardiac distress sound
        client:EmitSound("ambient/machines/machine1_hit1.wav", 55, 80, 0.4)

        ix.bacta.NotifyEffect(client, eff)
    end

    -- ─── Tail Effect Apply Functions (v2.2) ──────────────────────────────────

    ix.bacta.effectTypes["tail_metabolic_crash"].apply = function(client, eff)
        local dur = eff.duration or 12

        -- Speed -20%
        client:AddEffect("speed.run", "bactaTailCrash", MULT, 0.80, {
            duration = dur,
            priority = 5,
            layer    = "debuff",
            metadata = {source = "bacta_tail"},
        })
        client:AddEffect("speed.walk", "bactaTailCrash", MULT, 0.80, {
            duration = dur,
            priority = 5,
            layer    = "debuff",
        })

        -- Compounded fatigue: additional -15% speed
        client:AddEffect("speed.run", "bactaTailCrashFatigue", MULT, 0.85, {
            duration = dur,
            priority = 4,
            layer    = "debuff",
            metadata = {source = "bacta_tail"},
        })
        client:AddEffect("speed.walk", "bactaTailCrashFatigue", MULT, 0.85, {
            duration = dur,
            priority = 4,
            layer    = "debuff",
        })

        -- Heavy desaturation — the world drains of life
        client:AddEffect("visual.desaturate", "bactaTailCrashDesat", ADD, 0.35, {
            duration = dur,
            priority = 5,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Deep vignette — collapsing tunnel vision
        client:AddEffect("visual.vignette", "bactaTailCrashVignette", ADD, 0.2, {
            duration = dur,
            priority = 5,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Slight blur — metabolic exhaustion
        client:AddEffect("visual.blur", "bactaTailCrashBlur", ADD, 0.15, {
            duration = dur,
            priority = 4,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Laboured breathing sounds recurring during crash
        client:EmitSound("npc/zombie/zombie_voice_idle3.wav", 50, 130, 0.3)
        local timerID = "ixBacta_crashBreath_" .. client:EntIndex() .. "_" .. CurTime()
        local ticks = math.floor(dur / 4)
        timer.Create(timerID, 4, ticks, function()
            if (IsValid(client) and client:Alive()) then
                local breathSounds = {
                    "npc/zombie/zombie_voice_idle1.wav",
                    "npc/zombie/zombie_voice_idle3.wav",
                }
                client:EmitSound(breathSounds[math.random(#breathSounds)], 50, math.random(125, 140), 0.25)
            end
        end)

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["tail_neural_static"].apply = function(client, eff)
        local dur = eff.duration or 8

        -- Focus -30%
        client:AddEffect("combat.focus", "bactaTailNeural", MULT, 0.70, {
            duration = dur,
            priority = 3,
            layer    = "debuff",
            metadata = {source = "bacta_tail"},
        })

        -- Mild nausea
        client:AddEffect("visual.nausea", "bactaTailNeural", ADD, 0.15, {
            duration = dur,
            priority = 3,
            layer    = "debuff",
        })

        -- Screen flicker — synaptic interference
        client:AddEffect("visual.screen_flicker", "bactaTailNeuralFlicker", ADD, 2.5, {
            duration = dur,
            priority = 4,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Harsh sharpening — overstimulated neural pathways
        client:AddEffect("visual.sharpen", "bactaTailNeuralSharpen", ADD, 0.8, {
            duration = dur,
            priority = 4,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Static-like color distortion (grey/white wash)
        client:AddEffect("visual.color_tint", "bactaTailNeuralTint", PE.MOD_SET, Color(200, 200, 180, 35), {
            duration = dur,
            priority = 6,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Tinnitus sound — high-pitched ringing from neural noise
        client:EmitSound("ambient/machines/machine1_hit2.wav", 50, 200, 0.25)
        -- Recurring static sounds
        local timerID = "ixBacta_neuralStatic_" .. client:EntIndex() .. "_" .. CurTime()
        local ticks = math.floor(dur / 3)
        timer.Create(timerID, 3, ticks, function()
            if (IsValid(client) and client:Alive()) then
                client:EmitSound("ambient/machines/machine1_hit2.wav", 45, math.random(180, 220), 0.2)
            end
        end)

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["tail_vascular_spike"].apply = function(client, eff)
        local dur = eff.duration or 6
        local rate = -(3 / 2) -- -3 HP per 2s = -1.5 HP/s

        client:AddEffect("health.regen_rate", "bactaTailVascular", ADD, rate, {
            duration = dur,
            priority = 3,
            layer    = "debuff",
            metadata = {source = "bacta_tail"},
        })

        -- Intense red tint — blood rushing, vascular distress
        client:AddEffect("visual.color_tint", "bactaTailVascularTint", PE.MOD_SET, Color(255, 50, 40, 55), {
            duration = dur,
            priority = 7,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Deep vignette — blood pressure spike
        client:AddEffect("visual.vignette", "bactaTailVascularVignette", ADD, 0.25, {
            duration = dur,
            priority = 5,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Pounding heartbeat
        client:AddEffect("audio.heartbeat", "bactaTailVascularBeat", ADD, 0.8, {
            duration = dur,
            priority = 5,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Periodic pain groans during vascular spike
        client:EmitSound("vo/npc/male01/pain07.wav", 60, 95, 0.4)
        local timerID = "ixBacta_vascularPain_" .. client:EntIndex() .. "_" .. CurTime()
        local ticks = math.floor(dur / 2)
        timer.Create(timerID, 2, ticks, function()
            if (IsValid(client) and client:Alive()) then
                local painSounds = {
                    "vo/npc/male01/pain07.wav",
                    "vo/npc/male01/pain08.wav",
                    "vo/npc/male01/pain09.wav",
                }
                client:EmitSound(painSounds[math.random(#painSounds)], 55, math.random(90, 105), 0.35)
            end
        end)

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["tail_adrenal_dump"].apply = function(client, eff)
        local dur = eff.duration or 10

        -- Tremor (severity 2)
        client:AddEffect("visual.tremor", "bactaTailAdrenal", ADD, 2, {
            duration = dur,
            priority = 3,
            layer    = "debuff",
            metadata = {source = "bacta_tail"},
            onTick = function(ply, remaining)
                if (ply:Alive()) then
                    util.ScreenShake(ply:GetPos(), 4, 6, 0.5, 100)
                    if (math.random() < 0.12) then
                        ply:EmitSound("vo/npc/male01/pain0" .. math.random(1, 3) .. ".wav", 50, math.random(100, 115), 0.25)
                    end
                end
            end,
        })

        -- Speed -10%
        client:AddEffect("speed.run", "bactaTailAdrenal", MULT, 0.90, {
            duration = dur,
            priority = 5,
            layer    = "debuff",
            metadata = {source = "bacta_tail"},
        })
        client:AddEffect("speed.walk", "bactaTailAdrenal", MULT, 0.90, {
            duration = dur,
            priority = 5,
            layer    = "debuff",
        })

        -- Hot amber/orange tint — adrenal overload
        client:AddEffect("visual.color_tint", "bactaTailAdrenalTint", PE.MOD_SET, Color(255, 175, 60, 40), {
            duration = dur,
            priority = 6,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Bloom — overstimulated senses
        client:AddEffect("visual.bloom", "bactaTailAdrenalBloom", ADD, 0.5, {
            duration = dur,
            priority = 3,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Slight blur from shaking
        client:AddEffect("visual.blur", "bactaTailAdrenalBlur", ADD, 0.1, {
            duration = dur,
            priority = 3,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Adrenaline crash groan
        client:EmitSound("vo/npc/male01/pain08.wav", 60, 90, 0.4)

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
                -- Periodic nausea sounds as liver strains
                if (math.random() < 0.4) then
                    client:EmitSound("vo/npc/male01/pain04.wav", 45, math.random(85, 100), 0.2)
                end
            end
        end)

        -- Sickly yellow-green tint — liver toxicity
        client:AddEffect("visual.color_tint", "bactaTailHepaticTint", PE.MOD_SET, Color(180, 200, 80, 35), {
            duration = dur,
            priority = 5,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Mild nausea warp — toxin buildup makes the world swim
        client:AddEffect("visual.water_warp", "bactaTailHepaticWarp", ADD, 0.12, {
            duration = dur,
            priority = 3,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Mild bloom — feverish glow from toxin load
        client:AddEffect("visual.bloom", "bactaTailHepaticBloom", ADD, 0.25, {
            duration = dur,
            priority = 2,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Mild nausea visual
        client:AddEffect("visual.nausea", "bactaTailHepatic", ADD, 0.1, {
            duration = dur,
            priority = 2,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["tail_synaptic_rebound"].apply = function(client, eff)
        local dur = eff.duration or 8

        -- Focus -20%
        client:AddEffect("combat.focus", "bactaTailSynaptic", MULT, 0.80, {
            duration = dur,
            priority = 3,
            layer    = "debuff",
            metadata = {source = "bacta_tail"},
        })

        -- Strong visual distortion — neural overshoot
        client:AddEffect("visual.water_warp", "bactaTailSynapticWarp", ADD, 0.25, {
            duration = dur,
            priority = 5,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Bloom — overloaded visual cortex
        client:AddEffect("visual.bloom", "bactaTailSynapticBloom", ADD, 0.6, {
            duration = dur,
            priority = 4,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Purple-tinged distortion — synaptic overfire
        client:AddEffect("visual.color_tint", "bactaTailSynapticTint", PE.MOD_SET, Color(180, 130, 220, 40), {
            duration = dur,
            priority = 6,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Heavy blur — can't focus your eyes
        client:AddEffect("visual.blur", "bactaTailSynapticBlur", ADD, 0.3, {
            duration = dur,
            priority = 4,
            layer    = "debuff",
            refreshBehavior = "extend",
        })

        -- Nausea component
        client:AddEffect("visual.nausea", "bactaTailSynaptic", ADD, 0.25, {
            duration = dur,
            priority = 3,
            layer    = "debuff",
        })

        -- Disorientation sound
        client:EmitSound("ambient/machines/machine1_hit2.wav", 50, 160, 0.2)

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

    -- Nausea visual: subtle view angle wobble (reads from player_effects registry)
    hook.Add("CalcView", "ixBactaNauseaView", function(ply, pos, angles, fov)
        local nausea = ply:GetEffectValue("visual.nausea")
        if (not nausea or nausea <= 0) then return end

        local time = CurTime()
        local wobble = nausea * 3

        angles.roll = angles.roll + math.sin(time * 2.5) * wobble
        angles.pitch = angles.pitch + math.cos(time * 1.8) * wobble * 0.4

        return {origin = pos, angles = angles, fov = fov}
    end)
end
