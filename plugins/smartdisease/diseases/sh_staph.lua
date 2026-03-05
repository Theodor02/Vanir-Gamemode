--- Disease Definition: Staphylococcal Infection
-- A bacterial skin and systemic infection that cycles between flare-ups and remission.
-- Requires antibiotics to fully clear.
-- @disease staph

ix.disease.Register("staph", {
    name = "Staphylococcal Infection",
    description = "A bacterial infection starting in the skin that can spread to become systemic if untreated.",
    type = "bacterial",
    infectionRate = 8,
    progressionDelay = 55,
    contagious = true,
    baseIncubation = 1,

    -- REBALANCING: Cycles between stages until treated
    requiresMedicine = true,
    cycleStages = {min = 2, max = 6},  -- Oscillates between stage 2 and 6

    vectors = {
        air = false,
        collision = true,
        damage = true,
    },

    stages = {
        {
            id = 1,
            name = "Initial Colonisation",
            effects = {
                {type = "symptom", id = "rash"},
            },
        },
        {
            id = 2,
            name = "Localised Infection",
            effects = {
                {type = "symptom", id = "rash"},
                {type = "symptom", id = "pain_mild"},
            },
            persistentVisual = {
                colormod = Color(255, 230, 200, 255),
                colormodIntensity = 0.03,
            },
        },
        {
            id = 3,
            name = "Furuncle Formation",
            effects = {
                {type = "symptom", id = "boils"},
                {type = "symptom", id = "pain_mild"},
                {type = "symptom", id = "fever"},
                {type = "damage", amount = 1, damageType = "flat"},
            },
            persistentVisual = {
                colormod = Color(255, 220, 190, 255),
                colormodIntensity = 0.06,
                sharpen = true,
                sharpenIntensity = 0.1,
            },
        },
        {
            id = 4,
            name = "Spreading Cellulitis",
            effects = {
                {type = "symptom", id = "skin_lesions"},
                {type = "symptom", id = "pain_severe"},
                {type = "symptom", id = "high_fever"},
                {type = "symptom", id = "fatigue"},
                {type = "damage", amount = 3, damageType = "flat"},
            },
            persistentVisual = {
                colormod = Color(255, 210, 175, 255),
                colormodIntensity = 0.08,
                sharpen = true,
                sharpenIntensity = 0.2,
                vignette = true,
                vignetteIntensity = 0.04,
            },
        },
        {
            id = 5,
            name = "Systemic Sepsis",
            effects = {
                {type = "symptom", id = "boils"},
                {type = "symptom", id = "pain_severe"},
                {type = "symptom", id = "high_fever"},
                {type = "symptom", id = "dizziness"},
                {type = "symptom", id = "confusion"},
                {type = "damage", amount = 5, damageType = "flat"},
                {type = "visual", blur = true, blurIntensity = 0.6},
            },
            persistentVisual = {
                colormod = Color(255, 200, 160, 255),
                colormodIntensity = 0.12,
                sharpen = true,
                sharpenIntensity = 0.3,
                vignette = true,
                vignetteIntensity = 0.08,
                bloom = true,
                bloomIntensity = 0.15,
            },
        },
        {
            id = 6,
            name = "Bacteraemia Crisis",
            effects = {
                {type = "symptom", id = "skin_lesions"},
                {type = "symptom", id = "pain_agonizing"},
                {type = "symptom", id = "delirium"},
                {type = "symptom", id = "extreme_fatigue"},
                {type = "damage", amount = 7, damageType = "flat"},
                {type = "visual", blur = true, blurIntensity = 1.0, vignette = true, vignetteIntensity = 0.25},
            },
            persistentVisual = {
                colormod = Color(245, 190, 150, 255),
                colormodIntensity = 0.15,
                sharpen = true,
                sharpenIntensity = 0.4,
                vignette = true,
                vignetteIntensity = 0.12,
                bloom = true,
                bloomIntensity = 0.25,
                blur = true,
                blurIntensity = 0.08,
            },
        },
    },

    cureWith = {
        ["antibiotic"] = true,
    },
})
