--- Disease Definition: Schizophrenia
-- A chronic psychological condition with hallucinations, delusions, and
-- disordered thinking. Does NOT self-cure — requires antipsychotic medication.
-- Cycles between active psychotic episodes and brief remission periods.
-- @disease schizophrenia

ix.disease.Register("schizophrenia", {
    name = "Schizophrenia",
    description = "A chronic psychological disorder characterised by hallucinations, delusions, and disordered thinking.",
    type = "psychological",
    infectionRate = 0,
    progressionDelay = 60,
    contagious = false,
    baseIncubation = 1,

    -- REBALANCING: Chronic disease that never auto-cures
    requiresMedicine = true,    -- Must use antipsychotic to begin reversal
    chronic = true,             -- Even after treatment, can flare back up
    remissionStage = 2,         -- Goes to stage 2 during remission (not fully gone)
    flareChance = 8,            -- 8% chance per tick to flare up from remission
    maxUntreatedStage = 6,      -- Without medicine, cycles up to stage 6

    vectors = {},

    stages = {
        -- Stage 1: Subtle onset — player barely notices
        {
            id = 1,
            name = "Subclinical",
            effects = {
                {type = "symptom", id = "malaise"},
                {type = "symptom", id = "anxiety"},
            },
            -- Persistent visual: very subtle
            persistentVisual = {
                vignette = true,
                vignetteIntensity = 0.03,
            },
        },
        -- Stage 2: Remission baseline / early prodromal
        {
            id = 2,
            name = "Prodromal Phase",
            effects = {
                {type = "symptom", id = "anxiety"},
                {type = "symptom", id = "paranoia"},
                {type = "symptom", id = "disorganized_thought"},
                {type = "symptom", id = "fleeting_thought"},
            },
            persistentVisual = {
                vignette = true,
                vignetteIntensity = 0.06,
                colormod = Color(190, 180, 210, 255),
                colormodIntensity = 0.05,
            },
        },
        -- Stage 3: Active phase begins — hallucinations start
        {
            id = 3,
            name = "Early Psychosis",
            effects = {
                {type = "symptom", id = "paranoia"},
                {type = "symptom", id = "hallucination"},
                {type = "symptom", id = "whispers"},
                {type = "symptom", id = "fleeting_thought"},
                {type = "symptom", id = "eye_distort"},
                {type = "shadow_stalker"},
            },
            persistentVisual = {
                colormod = Color(180, 140, 220, 255),
                colormodIntensity = 0.12,
                vignette = true,
                vignetteIntensity = 0.1,
                sharpen = true,
                sharpenIntensity = 0.3,
            },
        },
        -- Stage 4: Full active psychosis — multi-symptom attacks
        {
            id = 4,
            name = "Active Psychosis",
            effects = {
                {type = "symptom", id = "hallucination"},
                {type = "symptom", id = "paranoia_severe"},
                {type = "symptom", id = "whispers"},
                {type = "symptom", id = "clone_hallucination"},
                {type = "symptom", id = "intrusive_thought"},
                {type = "shadow_stalker"},
                {type = "visual", colormod = Color(170, 100, 220, 255), colormodIntensity = 0.25, blur = true, blurIntensity = 0.5, waterWarp = true, waterWarpIntensity = 0.15},
            },
            persistentVisual = {
                colormod = Color(170, 110, 210, 255),
                colormodIntensity = 0.18,
                vignette = true,
                vignetteIntensity = 0.15,
                sharpen = true,
                sharpenIntensity = 0.5,
                waterWarp = true,
                waterWarpIntensity = 0.05,
            },
        },
        -- Stage 5: Severe psychotic episode — terrifying
        {
            id = 5,
            name = "Severe Episode",
            effects = {
                {type = "symptom", id = "hallucination_severe"},
                {type = "symptom", id = "loud_voices"},
                {type = "symptom", id = "panic"},
                {type = "symptom", id = "clone_hallucination"},
                {type = "symptom", id = "intrusive_thought"},
                {type = "symptom", id = "eye_distort"},
                {type = "symptom", id = "screen_flash"},
                {type = "shadow_stalker"},
                {type = "visual", colormod = Color(150, 80, 200, 255), colormodIntensity = 0.4, blur = true, blurIntensity = 1.0, shake = true, shakeIntensity = 2, waterWarp = true, waterWarpIntensity = 0.25, sobel = true, sobelThreshold = 0.2},
            },
            persistentVisual = {
                colormod = Color(160, 90, 200, 255),
                colormodIntensity = 0.25,
                vignette = true,
                vignetteIntensity = 0.2,
                sharpen = true,
                sharpenIntensity = 0.8,
                waterWarp = true,
                waterWarpIntensity = 0.1,
                shake = true,
                shakeIntensity = 0.3,
            },
        },
        -- Stage 6: Peak crisis — complete break from reality
        {
            id = 6,
            name = "Psychotic Break",
            effects = {
                {type = "symptom", id = "hallucination_severe"},
                {type = "symptom", id = "loud_voices"},
                {type = "symptom", id = "panic"},
                {type = "symptom", id = "clone_hallucination"},
                {type = "symptom", id = "intrusive_thought"},
                {type = "symptom", id = "eye_distort"},
                {type = "symptom", id = "screen_flash"},
                {type = "symptom", id = "shadow_presence"},
                {type = "symptom", id = "water_warp"},
                {type = "symptom", id = "catatonia"},
                {type = "symptom", id = "seizure"},
                {type = "shadow_stalker"},
                {type = "damage", amount = 2, damageType = "flat"},
                {type = "visual", colormod = Color(130, 60, 180, 255), colormodIntensity = 0.5, blur = true, blurIntensity = 1.5, shake = true, shakeIntensity = 3, waterWarp = true, waterWarpIntensity = 0.4, sobel = true, sobelThreshold = 0.15, screenFlicker = true, flickerRate = 3},
            },
            persistentVisual = {
                colormod = Color(140, 70, 190, 255),
                colormodIntensity = 0.3,
                vignette = true,
                vignetteIntensity = 0.25,
                sharpen = true,
                sharpenIntensity = 1.2,
                waterWarp = true,
                waterWarpIntensity = 0.15,
                shake = true,
                shakeIntensity = 0.5,
                desaturate = true,
                desaturateIntensity = 0.1,
            },
        },
    },

    cureWith = {
        ["antipsychotic"] = true,
    },

    onStageProgression = function(character, stage)
        local client = character:GetPlayer()
        if (!IsValid(client)) then return end

        if (stage == 3) then
            ix.chat.Send(client, "me", "mutters something under their breath, looking at nothing")
        elseif (stage == 4) then
            ix.chat.Send(client, "me", "flinches from invisible stimuli, their eyes darting wildly")
        elseif (stage == 5) then
            ix.chat.Send(client, "me", "screams at something no one else can see, backing into a corner")
        elseif (stage == 6) then
            ix.chat.Send(client, "me", "has completely lost touch with reality, their eyes vacant and terrified")
        end
    end,
})
