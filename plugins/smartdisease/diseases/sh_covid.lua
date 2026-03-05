--- Disease Definition: COVID-19
-- A respiratory viral illness with variable severity.
-- Cycles between active and lessened stages until treated with medicine.
-- @disease covid

ix.disease.Register("covid", {
    name = "COVID-19 (SARS-CoV-2)",
    description = "A highly contagious respiratory illness caused by a novel coronavirus.",
    type = "viral",
    infectionRate = 15,
    progressionDelay = 40,
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
            name = "Asymptomatic Carrier",
            effects = {
                {type = "symptom", id = "malaise"},
            },
        },
        {
            id = 2,
            name = "Mild Symptoms",
            effects = {
                {type = "symptom", id = "cough"},
                {type = "symptom", id = "loss_of_appetite"},
                {type = "symptom", id = "fatigue"},
            },
            persistentVisual = {
                blur = true,
                blurIntensity = 0.03,
            },
        },
        {
            id = 3,
            name = "Moderate Illness",
            effects = {
                {type = "symptom", id = "fever"},
                {type = "symptom", id = "cough"},
                {type = "symptom", id = "headache"},
                {type = "symptom", id = "body_aches"},
                {type = "symptom", id = "tinnitus"},
                {type = "damage", amount = 2, damageType = "flat"},
                {type = "cough", frequency = 10},
            },
            persistentVisual = {
                colormod = Color(240, 220, 200, 255),
                colormodIntensity = 0.06,
                bloom = true,
                bloomIntensity = 0.15,
            },
        },
        {
            id = 4,
            name = "Worsening Respiratory",
            effects = {
                {type = "symptom", id = "wheeze"},
                {type = "symptom", id = "high_fever"},
                {type = "symptom", id = "dizziness"},
                {type = "symptom", id = "migraine"},
                {type = "damage", amount = 4, damageType = "flat"},
                {type = "visual", blur = true, blurIntensity = 0.6},
            },
            persistentVisual = {
                colormod = Color(240, 200, 180, 255),
                colormodIntensity = 0.1,
                bloom = true,
                bloomIntensity = 0.25,
                vignette = true,
                vignetteIntensity = 0.06,
                blur = true,
                blurIntensity = 0.08,
            },
        },
        {
            id = 5,
            name = "Severe Respiratory Distress",
            effects = {
                {type = "symptom", id = "laboured_breathing"},
                {type = "symptom", id = "dizziness"},
                {type = "symptom", id = "extreme_fatigue"},
                {type = "damage", amount = 5, damageType = "flat"},
                {type = "visual", blur = true, blurIntensity = 0.8, vignette = true, vignetteIntensity = 0.2},
            },
            persistentVisual = {
                colormod = Color(230, 190, 170, 255),
                colormodIntensity = 0.12,
                bloom = true,
                bloomIntensity = 0.3,
                vignette = true,
                vignetteIntensity = 0.1,
                blur = true,
                blurIntensity = 0.1,
            },
        },
    },

    cureWith = {
        ["antiviral"] = true,
    },
})
