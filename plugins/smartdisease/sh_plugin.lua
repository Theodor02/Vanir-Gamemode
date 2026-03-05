--- Smart Disease System — Helix Plugin
-- A comprehensive disease, symptom, and medical system for roleplay servers.
-- Provides a public API via ix.disease and ix.symptom for extensibility.
-- @plugin smartdisease

local PLUGIN = PLUGIN

PLUGIN.name = "Smart Disease System"
PLUGIN.author = "Vanir"
PLUGIN.description = "A modular disease and medical system with immersive symptom progression, contagion mechanics, and diegetic roleplay integration."

-- ═══════════════════════════════════════════════════════════════════════════════
-- NAMESPACE INITIALISATION
-- ═══════════════════════════════════════════════════════════════════════════════

ix.disease = ix.disease or {}
ix.symptom = ix.symptom or {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- CONFIGURATION (exposed via Helix config panel)
-- ═══════════════════════════════════════════════════════════════════════════════

ix.config.Add("diseaseEnabled", true, "Enable or disable the disease system globally.", nil, {
    category = "Smart Disease"
})

ix.config.Add("diseaseSpreadEnabled", true, "Enable or disable disease transmission between players.", nil, {
    category = "Smart Disease"
})

ix.config.Add("diseaseProgressionRate", 1.0, "Multiplier for disease progression speed. Higher = faster.", nil, {
    category = "Smart Disease",
    data = {min = 0.1, max = 5.0, decimals = 1}
})

ix.config.Add("diseaseInfectionRate", 1.0, "Multiplier for base infection chance. Higher = more contagious.", nil, {
    category = "Smart Disease",
    data = {min = 0.1, max = 5.0, decimals = 1}
})

ix.config.Add("diseaseSymptomCooldown", 10, "Minimum seconds between repeated /me actions for the same symptom.", nil, {
    category = "Smart Disease",
    data = {min = 3, max = 60}
})

ix.config.Add("diseaseAirRange", 150, "Range in Source units for airborne disease transmission.", nil, {
    category = "Smart Disease",
    data = {min = 50, max = 500}
})

ix.config.Add("diseaseContactRange", 80, "Range in Source units for passive proximity (breathing) transmission.", nil, {
    category = "Smart Disease",
    data = {min = 30, max = 200}
})

ix.config.Add("diseaseTickInterval", 3, "Seconds between disease progression ticks.", nil, {
    category = "Smart Disease",
    data = {min = 1, max = 15}
})

ix.config.Add("diseaseMeActions", true, "Enable automatic /me actions when symptoms trigger.", nil, {
    category = "Smart Disease"
})

ix.config.Add("diseaseDamageEnabled", true, "Enable disease-inflicted damage to players.", nil, {
    category = "Smart Disease"
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- INTERNAL CONFIGURATION CONSTANTS
-- ═══════════════════════════════════════════════════════════════════════════════

ix.disease.Config = {
    -- Maximum number of concurrent infections per character
    MAX_CONCURRENT_DISEASES = 3,

    -- Base chance modifier for re-infection after cure (0-1, lower = harder)
    REINFECTION_RESISTANCE = 0.5,

    -- Duration of vaccine immunity in seconds (0 = permanent)
    VACCINE_DURATION = 0,

    -- Sound broadcast range for cough/sneeze (squared for DistToSqr)
    SOUND_BROADCAST_RANGE_SQR = 250000, -- 500^2

    -- Overdose tracking window in seconds
    OVERDOSE_WINDOW = 120,

    -- Maximum medicine doses in the overdose window before side effects
    OVERDOSE_THRESHOLD = 3,
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- FILE INCLUDES
-- ═══════════════════════════════════════════════════════════════════════════════

-- Shared libraries (disease + symptom registries)
ix.util.Include("libs/sh_disease.lua")
ix.util.Include("libs/sh_symptoms.lua")

-- Particle effect definitions
ix.util.Include("effects/smartdisease_cough.lua")
ix.util.Include("effects/smartdisease_sneeze.lua")
ix.util.Include("effects/smartdisease_vomit.lua")
ix.util.Include("effects/smartdisease_bleed.lua")

-- Disease definitions (declarative registrations)
ix.util.Include("diseases/sh_flu.lua")
ix.util.Include("diseases/sh_ebola.lua")
ix.util.Include("diseases/sh_covid.lua")
ix.util.Include("diseases/sh_sars.lua")
ix.util.Include("diseases/sh_staph.lua")
ix.util.Include("diseases/sh_diphtheria.lua")
ix.util.Include("diseases/sh_polio.lua")
ix.util.Include("diseases/sh_schizophrenia.lua")
ix.util.Include("diseases/sh_panic.lua")
ix.util.Include("diseases/sh_zombie.lua")

-- Server-side logic
ix.util.Include("sv_plugin.lua")
ix.util.Include("sv_hooks.lua")

-- Client-side logic
ix.util.Include("cl_plugin.lua")
ix.util.Include("cl_hooks.lua")

-- ═══════════════════════════════════════════════════════════════════════════════
-- COMMANDS
-- ═══════════════════════════════════════════════════════════════════════════════

ix.command.Add("DiseaseInfect", {
    description = "Infect a player's character with a disease.",
    adminOnly = true,
    arguments = {
        ix.type.player,
        ix.type.string
    },
    OnRun = function(self, client, target, diseaseID)
        local character = target:GetCharacter()
        if (!character) then
            return "Target has no active character."
        end

        local disease = ix.disease.Get(diseaseID)
        if (!disease) then
            return "Unknown disease ID: " .. diseaseID .. "."
        end

        local success, err = ix.disease.Infect(character, diseaseID, true)
        if (!success) then
            return "Failed to infect: " .. (err or "Unknown error.")
        end

        client:Notify("Infected " .. character:GetName() .. " with " .. disease.name .. ".")
    end
})

ix.command.Add("DiseaseCure", {
    description = "Cure a player's character of a specific disease.",
    adminOnly = true,
    arguments = {
        ix.type.player,
        ix.type.string
    },
    OnRun = function(self, client, target, diseaseID)
        local character = target:GetCharacter()
        if (!character) then
            return "Target has no active character."
        end

        ix.disease.Cure(character, diseaseID)
        client:Notify("Cured " .. character:GetName() .. " of " .. diseaseID .. ".")
    end
})

ix.command.Add("DiseaseCureAll", {
    description = "Cure a player's character of all diseases.",
    adminOnly = true,
    arguments = {
        ix.type.player
    },
    OnRun = function(self, client, target)
        local character = target:GetCharacter()
        if (!character) then
            return "Target has no active character."
        end

        ix.disease.CureAll(character)
        client:Notify("Cured all diseases on " .. character:GetName() .. ".")
    end
})

ix.command.Add("DiseaseVaccinate", {
    description = "Vaccinate a player's character against a disease.",
    adminOnly = true,
    arguments = {
        ix.type.player,
        ix.type.string
    },
    OnRun = function(self, client, target, diseaseID)
        local character = target:GetCharacter()
        if (!character) then
            return "Target has no active character."
        end

        local disease = ix.disease.Get(diseaseID)
        if (!disease) then
            return "Unknown disease ID: " .. diseaseID .. "."
        end

        ix.disease.Vaccinate(character, diseaseID)
        client:Notify("Vaccinated " .. character:GetName() .. " against " .. disease.name .. ".")
    end
})

ix.command.Add("DiseaseList", {
    description = "List all registered diseases.",
    OnRun = function(self, client)
        local diseases = ix.disease.GetAll()
        local lines = {":: Registered Diseases ::"}

        for id, data in SortedPairs(diseases) do
            lines[#lines + 1] = string.format("  %s — %s (%s)", id, data.name, data.type)
        end

        if (#lines == 1) then
            return "No diseases registered."
        end

        return table.concat(lines, "\n")
    end
})

ix.command.Add("DiseaseStatus", {
    description = "Check your character's disease status.",
    OnRun = function(self, client)
        local character = client:GetCharacter()
        if (!character) then
            return "No active character."
        end

        local active = ix.disease.GetActiveDiseases(character)
        if (!active or table.IsEmpty(active)) then
            return "You are not suffering from any diseases."
        end

        local lines = {":: Active Diseases ::"}
        for diseaseID, info in pairs(active) do
            local disease = ix.disease.Get(diseaseID)
            local name = disease and disease.name or diseaseID
            local stage = info.stage or 1
            local stageData = disease and disease.stages[stage]
            local stageName = stageData and stageData.name or ("Stage " .. stage)
            lines[#lines + 1] = string.format("  %s — %s", name, stageName)
        end

        return table.concat(lines, "\n")
    end
})

ix.command.Add("DiseaseDiagnose", {
    description = "Diagnose the diseases of a player you are looking at.",
    OnRun = function(self, client)
        if (SERVER) then
            local trace = client:GetEyeTrace()
            local target = trace.Entity

            if (!IsValid(target) or !target:IsPlayer() or client:GetPos():DistToSqr(target:GetPos()) > 10000) then
                return "No valid target in range. Look at a player within ~3 metres."
            end

            local character = target:GetCharacter()
            if (!character) then
                return "Target has no active character."
            end

            local active = ix.disease.GetActiveDiseases(character)
            if (!active or table.IsEmpty(active)) then
                return character:GetName() .. " appears to be healthy."
            end

            local lines = {":: Diagnosis for " .. character:GetName() .. " ::"}
            for diseaseID, info in pairs(active) do
                local disease = ix.disease.Get(diseaseID)
                local name = disease and disease.name or diseaseID
                local stage = info.stage or 1
                local stageData = disease and disease.stages[stage]
                local stageName = stageData and stageData.name or ("Stage " .. stage)
                lines[#lines + 1] = string.format("  %s — %s (Stage %d/%d)", name, stageName, stage, disease and #disease.stages or stage)
            end

            return table.concat(lines, "\n")
        end
    end
})
