--- Disease Definition: Influenza (Flu)
-- A highly contagious viral infection with progressive respiratory symptoms.
-- Cycles between active and lessened stages until treated with medicine.
-- @disease flu

ix.disease.Register("flu", {
    name = "Influenza (Orthomyxoviridae)",
    description = "A highly contagious viral infection affecting the respiratory system.",
    type = "viral",
    infectionRate = 12,
    progressionDelay = 45,
    contagious = true,
    baseIncubation = 1,

    -- REBALANCING: Cycles between stages until treated
    requiresMedicine = true,
    cycleStages = {min = 2, max = 5},  -- Oscillates between stage 2 and 5

    vectors = {
        air = true,
        collision = true,
        damage = false,
    },

    stages = {
        {
            id = 1,
            name = "Early Infection",
            effects = {
                {type = "symptom", id = "malaise"},
                {type = "symptom", id = "body_aches"},
            },
        },
        {
            id = 2,
            name = "Nasal Congestion",
            effects = {
                {type = "symptom", id = "congestion"},
                {type = "symptom", id = "sneeze"},
            },
            persistentVisual = {
                blur = true,
                blurIntensity = 0.05,
            },
        },
        {
            id = 3,
            name = "Worsening Symptoms",
            effects = {
                {type = "symptom", id = "headache"},
                {type = "symptom", id = "cough"},
                {type = "symptom", id = "body_aches"},
                {type = "damage", amount = 1, damageType = "flat"},
                {type = "cough", frequency = 12},
            },
            persistentVisual = {
                blur = true,
                blurIntensity = 0.08,
                colormod = Color(240, 220, 200, 255),
                colormodIntensity = 0.05,
            },
        },
        {
            id = 4,
            name = "Fever",
            effects = {
                {type = "symptom", id = "fever"},
                {type = "symptom", id = "cough"},
                {type = "symptom", id = "chills"},
                {type = "damage", amount = 2, damageType = "flat"},
                {type = "cough", frequency = 10},
            },
            persistentVisual = {
                colormod = Color(255, 200, 170, 255),
                colormodIntensity = 0.08,
                bloom = true,
                bloomIntensity = 0.2,
            },
        },
        {
            id = 5,
            name = "Severe Illness",
            effects = {
                {type = "symptom", id = "vomit"},
                {type = "symptom", id = "high_fever"},
                {type = "symptom", id = "extreme_fatigue"},
                {type = "damage", amount = 3, damageType = "flat"},
            },
            persistentVisual = {
                colormod = Color(255, 180, 150, 255),
                colormodIntensity = 0.12,
                bloom = true,
                bloomIntensity = 0.3,
                vignette = true,
                vignetteIntensity = 0.08,
            },
        },
    },

    cureWith = {
        ["antiviral"] = true,
    },
})
