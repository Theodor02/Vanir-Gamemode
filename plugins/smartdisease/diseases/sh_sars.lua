--- Disease Definition: SARS
-- A severe acute respiratory syndrome with high fatality.
-- DEADLY if untreated — requires antiviral medication.
-- @disease sars

ix.disease.Register("sars", {
    name = "SARS (Severe Acute Respiratory Syndrome)",
    description = "A severe respiratory illness caused by a coronavirus, with significant mortality risk.",
    type = "viral",
    infectionRate = 10,
    progressionDelay = 50,
    contagious = true,
    baseIncubation = 2,

    -- REBALANCING: Deadly without treatment
    requiresMedicine = true,
    maxUntreatedStage = 7, -- Will progress to death

    vectors = {
        air = true,
        collision = true,
        damage = false,
    },

    stages = {
        {
            id = 1,
            name = "Prodromal Phase",
            effects = {
                {type = "symptom", id = "fever"},
                {type = "symptom", id = "malaise"},
                {type = "symptom", id = "body_aches"},
            },
        },
        {
            id = 2,
            name = "Lower Respiratory Phase",
            effects = {
                {type = "symptom", id = "cough"},
                {type = "symptom", id = "wheeze"},
                {type = "symptom", id = "fever"},
                {type = "damage", amount = 2, damageType = "flat"},
            },
            persistentVisual = {
                vignette = true,
                vignetteIntensity = 0.05,
            },
        },
        {
            id = 3,
            name = "Progressive Dyspnoea",
            effects = {
                {type = "symptom", id = "wheeze"},
                {type = "symptom", id = "high_fever"},
                {type = "symptom", id = "cough"},
                {type = "damage", amount = 4, damageType = "flat"},
                {type = "visual", blur = true, blurIntensity = 0.6},
            },
            persistentVisual = {
                colormod = Color(200, 200, 240, 255),
                colormodIntensity = 0.08,
                vignette = true,
                vignetteIntensity = 0.1,
                blur = true,
                blurIntensity = 0.1,
            },
        },
        {
            id = 4,
            name = "Acute Respiratory Distress",
            effects = {
                {type = "symptom", id = "laboured_breathing"},
                {type = "symptom", id = "pain_severe"},
                {type = "symptom", id = "confusion"},
                {type = "damage", amount = 6, damageType = "flat"},
                {type = "visual", colormod = Color(180, 180, 255, 255), colormodIntensity = 0.2, blur = true, blurIntensity = 0.8},
            },
            persistentVisual = {
                colormod = Color(190, 190, 240, 255),
                colormodIntensity = 0.15,
                vignette = true,
                vignetteIntensity = 0.15,
                blur = true,
                blurIntensity = 0.2,
            },
        },
        {
            id = 5,
            name = "Respiratory Failure",
            effects = {
                {type = "symptom", id = "laboured_breathing"},
                {type = "symptom", id = "pain_agonizing"},
                {type = "symptom", id = "dizziness"},
                {type = "symptom", id = "cough_blood"},
                {type = "damage", amount = 10, damageType = "flat"},
            },
            persistentVisual = {
                colormod = Color(180, 180, 250, 255),
                colormodIntensity = 0.2,
                vignette = true,
                vignetteIntensity = 0.25,
                blur = true,
                blurIntensity = 0.3,
                desaturate = true,
                desaturateIntensity = 0.15,
            },
        },
        {
            id = 6,
            name = "Critical / Organ Failure",
            effects = {
                {type = "symptom", id = "severe_paralysis"},
                {type = "symptom", id = "delirium"},
                {type = "damage", amount = 14, damageType = "flat"},
            },
            persistentVisual = {
                colormod = Color(170, 170, 240, 255),
                colormodIntensity = 0.25,
                vignette = true,
                vignetteIntensity = 0.35,
                blur = true,
                blurIntensity = 0.5,
                desaturate = true,
                desaturateIntensity = 0.3,
            },
        },
        {
            id = 7,
            name = "Terminal",
            effects = {},
            lethal = true,
        },
    },

    cureWith = {
        ["antiviral"] = true,
    },
})
