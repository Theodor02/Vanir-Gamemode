--- Disease Definition: Diphtheria
-- A bacterial infection of the respiratory tract with progressive organ damage.
-- DEADLY if untreated — requires antibiotic medication.
-- @disease diphtheria

ix.disease.Register("diphtheria", {
    name = "Diphtheria (Corynebacterium)",
    description = "A serious bacterial infection of the mucous membranes of the throat and nose, producing a toxin that can damage organs.",
    type = "bacterial",
    infectionRate = 8,
    progressionDelay = 50,
    contagious = true,
    baseIncubation = 1,

    -- REBALANCING: Deadly without treatment
    requiresMedicine = true,
    maxUntreatedStage = 8, -- Will progress to death

    vectors = {
        air = true,
        collision = true,
        damage = false,
    },

    stages = {
        {
            id = 1,
            name = "Sore Throat",
            effects = {
                {type = "symptom", id = "pain_mild"},
                {type = "symptom", id = "malaise"},
            },
        },
        {
            id = 2,
            name = "Membrane Formation",
            effects = {
                {type = "symptom", id = "throat_membrane"},
                {type = "symptom", id = "wheeze"},
                {type = "symptom", id = "fever"},
                {type = "damage", amount = 1, damageType = "flat"},
            },
            persistentVisual = {
                vignette = true,
                vignetteIntensity = 0.05,
            },
        },
        {
            id = 3,
            name = "Toxin Release",
            effects = {
                {type = "symptom", id = "high_fever"},
                {type = "symptom", id = "nausea"},
                {type = "symptom", id = "pain_severe"},
                {type = "damage", amount = 3, damageType = "flat"},
            },
            persistentVisual = {
                colormod = Color(230, 210, 170, 255),
                colormodIntensity = 0.1,
                vignette = true,
                vignetteIntensity = 0.08,
            },
        },
        {
            id = 4,
            name = "Myocarditis",
            effects = {
                {type = "symptom", id = "pain_severe"},
                {type = "symptom", id = "dizziness"},
                {type = "symptom", id = "chest_tightness"},
                {type = "damage", amount = 5, damageType = "flat"},
                {type = "visual", colormod = Color(220, 200, 170, 255), colormodIntensity = 0.2},
            },
            persistentVisual = {
                colormod = Color(220, 200, 170, 255),
                colormodIntensity = 0.15,
                vignette = true,
                vignetteIntensity = 0.12,
                blur = true,
                blurIntensity = 0.1,
            },
        },
        {
            id = 5,
            name = "Neuropathy",
            effects = {
                {type = "symptom", id = "paralysis"},
                {type = "symptom", id = "confusion"},
                {type = "symptom", id = "dizziness"},
                {type = "damage", amount = 7, damageType = "flat"},
            },
            persistentVisual = {
                colormod = Color(210, 190, 160, 255),
                colormodIntensity = 0.2,
                vignette = true,
                vignetteIntensity = 0.18,
                blur = true,
                blurIntensity = 0.2,
            },
        },
        {
            id = 6,
            name = "Airway Obstruction",
            effects = {
                {type = "symptom", id = "laboured_breathing"},
                {type = "symptom", id = "severe_paralysis"},
                {type = "symptom", id = "cough_blood"},
                {type = "damage", amount = 10, damageType = "flat"},
            },
            persistentVisual = {
                colormod = Color(200, 180, 150, 255),
                colormodIntensity = 0.25,
                vignette = true,
                vignetteIntensity = 0.3,
                blur = true,
                blurIntensity = 0.35,
                desaturate = true,
                desaturateIntensity = 0.15,
            },
        },
        {
            id = 7,
            name = "Organ Failure",
            effects = {
                {type = "symptom", id = "pain_agonizing"},
                {type = "symptom", id = "delirium"},
                {type = "damage", amount = 14, damageType = "flat"},
            },
            persistentVisual = {
                colormod = Color(190, 170, 140, 255),
                colormodIntensity = 0.3,
                vignette = true,
                vignetteIntensity = 0.4,
                blur = true,
                blurIntensity = 0.5,
                desaturate = true,
                desaturateIntensity = 0.3,
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
        ["antibiotic"] = true,
    },
})
