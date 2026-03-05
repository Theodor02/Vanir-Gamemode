--- Disease Definition: Panic Disorder
-- A chronic psychological condition with recurring panic attacks.
-- Does NOT self-cure — requires anti-anxiety medication.
-- Cycles between buildup and attack phases.
-- @disease panic

ix.disease.Register("panic", {
    name = "Panic Disorder",
    description = "A psychological condition characterised by sudden, recurring panic attacks with overwhelming anxiety and physical symptoms.",
    type = "psychological",
    infectionRate = 0,
    progressionDelay = 25,
    contagious = false,
    baseIncubation = 1,

    -- REBALANCING: Chronic cycling condition
    requiresMedicine = true,    -- Must use anti-anxiety meds
    chronic = true,             -- Recurs after treatment
    remissionStage = 1,         -- Calms down to stage 1 during remission
    flareChance = 12,           -- 12% chance per tick to flare from remission (frequent)
    maxUntreatedStage = 5,      -- Cycles up to peak panic without medicine

    vectors = {},

    stages = {
        -- Stage 1: Baseline anxiety — always present
        {
            id = 1,
            name = "Baseline Anxiety",
            effects = {
                {type = "symptom", id = "anxiety"},
                {type = "symptom", id = "cold_sweat"},
            },
            persistentVisual = {
                vignette = true,
                vignetteIntensity = 0.04,
            },
        },
        -- Stage 2: Rising tension — building toward attack
        {
            id = 2,
            name = "Anticipatory Anxiety",
            effects = {
                {type = "symptom", id = "anxiety"},
                {type = "symptom", id = "rising_dread"},
                {type = "symptom", id = "tremors"},
                {type = "symptom", id = "chest_tightness"},
            },
            persistentVisual = {
                vignette = true,
                vignetteIntensity = 0.08,
                shake = true,
                shakeIntensity = 0.15,
            },
        },
        -- Stage 3: Onset of panic attack
        {
            id = 3,
            name = "Panic Attack Onset",
            effects = {
                {type = "symptom", id = "panic"},
                {type = "symptom", id = "hyperventilate"},
                {type = "symptom", id = "dizziness"},
                {type = "symptom", id = "chest_tightness"},
                {type = "visual", blur = true, blurIntensity = 0.8, shake = true, shakeIntensity = 2, vignette = true, vignetteIntensity = 0.3},
            },
            persistentVisual = {
                vignette = true,
                vignetteIntensity = 0.2,
                shake = true,
                shakeIntensity = 0.4,
                desaturate = true,
                desaturateIntensity = 0.15,
                blur = true,
                blurIntensity = 0.2,
            },
        },
        -- Stage 4: Full panic attack — debilitating
        {
            id = 4,
            name = "Full Panic Attack",
            effects = {
                {type = "symptom", id = "panic"},
                {type = "symptom", id = "hyperventilate"},
                {type = "symptom", id = "depersonalization"},
                {type = "symptom", id = "chest_tightness"},
                {type = "symptom", id = "nausea"},
                {type = "symptom", id = "tremors"},
                {type = "visual", blur = true, blurIntensity = 1.2, shake = true, shakeIntensity = 3.5, vignette = true, vignetteIntensity = 0.4, desaturate = true, desaturateIntensity = 0.3, screenFlicker = true, flickerRate = 3},
                {type = "damage", amount = 1, damageType = "flat"},
            },
            persistentVisual = {
                vignette = true,
                vignetteIntensity = 0.3,
                shake = true,
                shakeIntensity = 0.6,
                desaturate = true,
                desaturateIntensity = 0.25,
                blur = true,
                blurIntensity = 0.3,
                bloom = true,
                bloomIntensity = 0.5,
            },
        },
        -- Stage 5: Peak crisis — absolute terror
        {
            id = 5,
            name = "Peak Crisis",
            effects = {
                {type = "symptom", id = "panic_peak"},
                {type = "symptom", id = "hyperventilate"},
                {type = "symptom", id = "depersonalization"},
                {type = "symptom", id = "seizure"},
                {type = "symptom", id = "pain_severe"},
                {type = "symptom", id = "screen_flash"},
                {type = "visual", blur = true, blurIntensity = 1.8, shake = true, shakeIntensity = 5, vignette = true, vignetteIntensity = 0.5, desaturate = true, desaturateIntensity = 0.5, screenFlicker = true, flickerRate = 6, bloom = true, bloomIntensity = 2.0},
                {type = "damage", amount = 2, damageType = "flat"},
            },
            persistentVisual = {
                vignette = true,
                vignetteIntensity = 0.4,
                shake = true,
                shakeIntensity = 1.0,
                desaturate = true,
                desaturateIntensity = 0.4,
                blur = true,
                blurIntensity = 0.5,
                bloom = true,
                bloomIntensity = 1.0,
                screenFlicker = true,
                flickerRate = 2,
            },
        },
    },

    cureWith = {
        ["antianxiety"] = true,
    },

    -- Panic can trigger schizophrenia as a complication (from original mod)
    onStageProgression = function(character, stage)
        local client = character:GetPlayer()
        if (!IsValid(client)) then return end

        if (stage == 3) then
            ix.chat.Send(client, "me", "suddenly grabs their chest, breathing rapidly")
        elseif (stage == 4) then
            ix.chat.Send(client, "me", "is clearly having a full panic attack, hyperventilating and shaking")
        elseif (stage == 5) then
            ix.chat.Send(client, "me", "collapses in absolute terror, screaming and thrashing")

            -- 5% chance to develop schizophrenia from extreme panic
            if (math.random(100) <= 5) then
                if (!ix.disease.HasDisease(character, "schizophrenia")) then
                    ix.disease.Infect(character, "schizophrenia", true)
                end
            end
        end
    end,
})
