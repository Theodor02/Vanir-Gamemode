--- Smart Disease — Language Strings (English)
-- @language sh_english

local LANGUAGE = {
    -- General
    diseaseSystemName = "Smart Disease System",
    diseaseDisabled = "The disease system is currently disabled.",

    -- Infection messages (diegetic)
    diseaseInfectedGeneric = "You feel strange... something isn't right.",
    diseaseInfectedBite = "You wince as you feel a sharp burning sensation at the wound.",
    diseaseInfectedAir = "You breathe in something foul.",

    -- Stage progression (diegetic)
    diseaseMild = "Something feels off.",
    diseaseModerate = "You feel unwell.",
    diseaseSevere = "Your symptoms are worsening.",
    diseaseCritical = "You are gravely ill.",
    diseaseTreating = "Treatment taking effect.",

    -- Recovery
    diseaseCured = "You have recovered from %s.",
    diseaseCuredAll = "All diseases have been cured.",
    diseaseFeelBetter = "You begin to feel better.",
    diseaseSymptomsSubsiding = "Your symptoms are subsiding.",

    -- Medicine
    diseaseMedicineTaking = "The %s begins to work.",
    diseaseMedicineNoEffect = "The medicine doesn't seem to help your current condition.",
    diseaseMedicineOverdose = "You feel dizzy from taking too much medicine...",
    diseaseVaccinated = "You have been vaccinated against %s.",

    -- Diagnosis
    diseaseDiagnoseHealthy = "%s appears to be healthy.",
    diseaseDiagnoseHeader = ":: Diagnosis for %s ::",

    -- Commands
    diseaseInfected = "Infected %s with %s.",
    diseaseCuredCmd = "Cured %s of %s.",
    diseaseCuredAllCmd = "Cured all diseases on %s.",
    diseaseVaccinatedCmd = "Vaccinated %s against %s.",

    -- HUD
    diseaseHudTitle = "BODY STATUS",
    diseaseHudPathogen = "PATHOGEN",

    -- Admin
    diseaseListHeader = ":: Registered Diseases ::",
    diseaseStatusHeader = ":: Active Diseases ::",
    diseaseNoActive = "You are not suffering from any diseases.",
    diseaseNoneRegistered = "No diseases registered.",
    diseaseUnknown = "Unknown disease ID: %s.",
}

-- Register with Helix language system
if (ix and ix.lang and ix.lang.AddTable) then
    ix.lang.AddTable("english", LANGUAGE)
end
