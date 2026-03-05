--- Disease Definition: Zombie Virus
-- A fictional viral infection that progressively transforms the host.
-- DEADLY if untreated — requires antiviral medication.
-- @disease zombie

ix.disease.Register("zombie", {
    name = "Necroa Virus (Zombie Pathogen)",
    description = "A terrifying viral pathogen that causes progressive neural degradation and aggressive behaviour.",
    type = "viral",
    infectionRate = 20,
    progressionDelay = 35,
    contagious = true,
    baseIncubation = 1,

    -- REBALANCING: Deadly without treatment
    requiresMedicine = true,
    maxUntreatedStage = 6, -- Will progress to death

    vectors = {
        air = false,
        collision = true,
        damage = true,
    },

    stages = {
        {
            id = 1,
            name = "Exposure",
            effects = {
                {type = "symptom", id = "malaise"},
                {type = "symptom", id = "fever"},
                {type = "symptom", id = "pain_mild"},
            },
        },
        {
            id = 2,
            name = "Neural Degradation",
            effects = {
                {type = "symptom", id = "confusion"},
                {type = "symptom", id = "headache"},
                {type = "symptom", id = "zombie_twitch"},
                {type = "damage", amount = 2, damageType = "flat"},
            },
            persistentVisual = {
                colormod = Color(160, 200, 120, 255),
                colormodIntensity = 0.08,
            },
        },
        {
            id = 3,
            name = "Aggression Phase",
            effects = {
                {type = "symptom", id = "zombie_rage"},
                {type = "symptom", id = "zombie_twitch"},
                {type = "symptom", id = "pain_severe"},
                {type = "damage", amount = 4, damageType = "flat"},
                {type = "visual", colormod = Color(150, 200, 100, 255), colormodIntensity = 0.25, sharpen = true, sharpenIntensity = 0.8},
            },
            persistentVisual = {
                colormod = Color(150, 200, 100, 255),
                colormodIntensity = 0.15,
                sharpen = true,
                sharpenIntensity = 0.3,
            },
        },
        {
            id = 4,
            name = "Advanced Infection",
            effects = {
                {type = "symptom", id = "blood_vomit"},
                {type = "symptom", id = "bleeding"},
                {type = "symptom", id = "zombie_groan"},
                {type = "symptom", id = "zombie_rage"},
                {type = "damage", amount = 6, damageType = "flat"},
                {type = "visual", colormod = Color(100, 180, 80, 255), colormodIntensity = 0.4, blur = true, blurIntensity = 0.8, sharpen = true, sharpenIntensity = 1.0},
            },
            persistentVisual = {
                colormod = Color(120, 190, 80, 255),
                colormodIntensity = 0.25,
                sharpen = true,
                sharpenIntensity = 0.6,
                vignette = true,
                vignetteIntensity = 0.1,
            },
        },
        {
            id = 5,
            name = "Transformation",
            effects = {
                {type = "symptom", id = "zombie_groan"},
                {type = "symptom", id = "zombie_rage"},
                {type = "symptom", id = "haemorrhage"},
                {type = "symptom", id = "delirium"},
                {type = "symptom", id = "seizure"},
                {type = "damage", amount = 10, damageType = "flat"},
                {type = "visual", colormod = Color(80, 160, 60, 255), colormodIntensity = 0.5, blur = true, blurIntensity = 1.2, sharpen = true, sharpenIntensity = 1.5, vignette = true, vignetteIntensity = 0.3, screenFlicker = true, flickerRate = 3},
            },
            persistentVisual = {
                colormod = Color(90, 170, 70, 255),
                colormodIntensity = 0.35,
                sharpen = true,
                sharpenIntensity = 1.0,
                vignette = true,
                vignetteIntensity = 0.2,
                desaturate = true,
                desaturateIntensity = 0.1,
            },
        },
        {
            id = 6,
            name = "Terminal Transformation",
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

        if (stage == 2) then
            ix.chat.Send(client, "me", "twitches involuntarily and growls")
        elseif (stage == 3) then
            ix.chat.Send(client, "me", "snarls aggressively, their eyes glazing over")
        elseif (stage == 4) then
            ix.chat.Send(client, "me", "lets out an inhuman groan, barely recognisable")
        elseif (stage == 5) then
            ix.chat.Send(client, "me", "is barely human anymore, their body contorting grotesquely")
        end
    end,

    onInfection = function(character, source)
        local client = character:GetPlayer()
        if (IsValid(client)) then
            ix.chat.Send(client, "me", "winces as they feel a sharp burning sensation at the wound")
        end
    end,
})
