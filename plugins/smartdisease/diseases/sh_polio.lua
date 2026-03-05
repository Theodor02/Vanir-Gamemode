--- Disease Definition: Polio (Poliomyelitis)
-- A viral disease causing progressive paralysis.
-- DEADLY if untreated — requires antiviral medication.
-- @disease polio

ix.disease.Register("polio", {
    name = "Poliomyelitis",
    description = "A viral disease that attacks the nervous system, potentially causing permanent paralysis.",
    type = "viral",
    infectionRate = 8,
    progressionDelay = 60,
    contagious = true,
    baseIncubation = 1,

    -- REBALANCING: Deadly without treatment
    requiresMedicine = true,
    maxUntreatedStage = 8, -- Will progress to death

    vectors = {
        air = false,
        collision = true,
        damage = false,
    },

    stages = {
        {
            id = 1,
            name = "Minor Illness",
            effects = {
                {type = "symptom", id = "malaise"},
                {type = "symptom", id = "fever"},
            },
        },
        {
            id = 2,
            name = "Meningeal Phase",
            effects = {
                {type = "symptom", id = "headache"},
                {type = "symptom", id = "pain_mild"},
                {type = "symptom", id = "nausea"},
            },
            persistentVisual = {
                blur = true,
                blurIntensity = 0.05,
            },
        },
        {
            id = 3,
            name = "Muscle Weakness",
            effects = {
                {type = "symptom", id = "fatigue"},
                {type = "symptom", id = "pain_severe"},
                {type = "symptom", id = "body_aches"},
                {type = "damage", amount = 2, damageType = "flat"},
            },
            persistentVisual = {
                vignette = true,
                vignetteIntensity = 0.06,
            },
        },
        {
            id = 4,
            name = "Early Paralysis",
            effects = {
                {type = "symptom", id = "paralysis"},
                {type = "symptom", id = "pain_severe"},
                {type = "damage", amount = 3, damageType = "flat"},
            },
            persistentVisual = {
                vignette = true,
                vignetteIntensity = 0.1,
                blur = true,
                blurIntensity = 0.1,
            },
        },
        {
            id = 5,
            name = "Progressive Paralysis",
            effects = {
                {type = "symptom", id = "paralysis"},
                {type = "symptom", id = "pain_agonizing"},
                {type = "symptom", id = "extreme_fatigue"},
                {type = "damage", amount = 5, damageType = "flat"},
                {type = "visual", blur = true, blurIntensity = 0.8, vignette = true, vignetteIntensity = 0.2},
            },
            persistentVisual = {
                vignette = true,
                vignetteIntensity = 0.15,
                blur = true,
                blurIntensity = 0.15,
                desaturate = true,
                desaturateIntensity = 0.1,
            },
        },
        {
            id = 6,
            name = "Bulbar Involvement",
            effects = {
                {type = "symptom", id = "severe_paralysis"},
                {type = "symptom", id = "laboured_breathing"},
                {type = "symptom", id = "dizziness"},
                {type = "damage", amount = 7, damageType = "flat"},
            },
            persistentVisual = {
                vignette = true,
                vignetteIntensity = 0.25,
                blur = true,
                blurIntensity = 0.25,
                desaturate = true,
                desaturateIntensity = 0.2,
            },
        },
        {
            id = 7,
            name = "Respiratory Paralysis",
            effects = {
                {type = "symptom", id = "severe_paralysis"},
                {type = "symptom", id = "delirium"},
                {type = "damage", amount = 12, damageType = "flat"},
            },
            persistentVisual = {
                vignette = true,
                vignetteIntensity = 0.4,
                blur = true,
                blurIntensity = 0.4,
                desaturate = true,
                desaturateIntensity = 0.4,
            },
        },
        {
            id = 8,
            name = "Terminal",
            effects = {},
            lethal = true,
        },
    },

    cureWith = {
        ["antiviral"] = true,
    },

    onStageProgression = function(character, stage)
        local client = character:GetPlayer()
        if (!IsValid(client)) then return end

        if (stage == 4) then
            ix.chat.Send(client, "me", "struggles to move their legs")
        elseif (stage == 6) then
            ix.chat.Send(client, "me", "can barely move, their body failing them")
        end
    end,
})
