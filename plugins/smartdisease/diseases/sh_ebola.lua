--- Disease Definition: Ebola (Haemorrhagic Fever)
-- A severe viral disease with progressive organ failure and bleeding.
-- DEADLY if untreated — requires antiviral medication.
-- @disease ebola

ix.disease.Register("ebola", {
    name = "Ebola Haemorrhagic Fever",
    description = "A severe and often fatal viral disease causing internal and external haemorrhaging.",
    type = "viral",
    infectionRate = 6,
    progressionDelay = 55,
    contagious = true,
    baseIncubation = 2,

    -- REBALANCING: Deadly without treatment
    requiresMedicine = true,
    maxUntreatedStage = 7, -- Will progress all the way to death

    vectors = {
        air = false,
        collision = true,
        damage = true,
    },

    stages = {
        {
            id = 1,
            name = "Incubation",
            effects = {
                {type = "symptom", id = "malaise"},
                {type = "symptom", id = "body_aches"},
            },
        },
        {
            id = 2,
            name = "Early Symptoms",
            effects = {
                {type = "symptom", id = "fever"},
                {type = "symptom", id = "headache"},
                {type = "symptom", id = "fatigue"},
            },
            persistentVisual = {
                colormod = Color(255, 200, 180, 255),
                colormodIntensity = 0.05,
            },
        },
        {
            id = 3,
            name = "Gastrointestinal Phase",
            effects = {
                {type = "symptom", id = "vomit"},
                {type = "symptom", id = "diarrhea"},
                {type = "symptom", id = "stomach_cramps"},
                {type = "damage", amount = 3, damageType = "flat"},
            },
            persistentVisual = {
                colormod = Color(255, 180, 150, 255),
                colormodIntensity = 0.1,
                blur = true,
                blurIntensity = 0.1,
            },
        },
        {
            id = 4,
            name = "Haemorrhagic Phase",
            effects = {
                {type = "symptom", id = "bleeding"},
                {type = "symptom", id = "pain_severe"},
                {type = "symptom", id = "high_fever"},
                {type = "damage", amount = 5, damageType = "flat"},
                {type = "visual", colormod = Color(255, 80, 80, 255), colormodIntensity = 0.3, blur = true, blurIntensity = 0.5},
            },
            persistentVisual = {
                colormod = Color(255, 120, 100, 255),
                colormodIntensity = 0.15,
                vignette = true,
                vignetteIntensity = 0.1,
            },
        },
        {
            id = 5,
            name = "Organ Failure",
            effects = {
                {type = "symptom", id = "haemorrhage"},
                {type = "symptom", id = "eye_bleed"},
                {type = "symptom", id = "confusion"},
                {type = "symptom", id = "blood_vomit"},
                {type = "damage", amount = 8, damageType = "flat"},
                {type = "visual", colormod = Color(255, 50, 50, 255), colormodIntensity = 0.45, blur = true, blurIntensity = 0.8, vignette = true, vignetteIntensity = 0.3},
            },
            persistentVisual = {
                colormod = Color(255, 80, 80, 255),
                colormodIntensity = 0.25,
                vignette = true,
                vignetteIntensity = 0.2,
                blur = true,
                blurIntensity = 0.2,
            },
        },
        {
            id = 6,
            name = "Critical / Multi-Organ Failure",
            effects = {
                {type = "symptom", id = "haemorrhage"},
                {type = "symptom", id = "pain_agonizing"},
                {type = "symptom", id = "severe_paralysis"},
                {type = "symptom", id = "delirium"},
                {type = "damage", amount = 12, damageType = "flat"},
            },
            persistentVisual = {
                colormod = Color(255, 50, 50, 255),
                colormodIntensity = 0.35,
                vignette = true,
                vignetteIntensity = 0.35,
                blur = true,
                blurIntensity = 0.4,
                desaturate = true,
                desaturateIntensity = 0.2,
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

    onStageProgression = function(character, stage)
        local client = character:GetPlayer()
        if (!IsValid(client)) then return end

        if (stage == 4) then
            ix.chat.Send(client, "me", "begins bleeding from the eyes and nose")
        elseif (stage == 5) then
            ix.chat.Send(client, "me", "is visibly deteriorating, blood seeping from every orifice")
        elseif (stage == 6) then
            ix.chat.Send(client, "me", "is barely conscious, their body shutting down")
        end
    end,
})
