--- Disease Registry & Management Library
-- Provides the core ix.disease API for registering, infecting, curing, and
-- querying diseases. All disease definitions use a declarative meta-registration system.
-- @module ix.disease

ix.disease = ix.disease or {}
ix.disease._registered = ix.disease._registered or {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- REGISTRATION
-- ═══════════════════════════════════════════════════════════════════════════════

--- Register a new disease with the system.
-- @param id string Unique disease identifier (e.g. "flu", "ebola")
-- @param data table Disease definition table containing:
--   name (string), description (string), type (string: "viral"|"bacterial"|"psychological"),
--   infectionRate (number 0-100), progressionDelay (number seconds),
--   contagious (bool), baseIncubation (number stage),
--   vectors (table: {air, collision, damage}),
--   stages (table of stage definitions),
--   cureWith (table: {["medicine_type"] = true}),
--   onStageProgression (function), onInfection (function), onCure (function)
function ix.disease.Register(id, data)
    if (!id or !data) then
        ErrorNoHalt("[SmartDisease] Attempted to register disease with nil id or data.\n")
        return
    end

    data.id = id
    data.infectionRate = data.infectionRate or 10
    data.progressionDelay = data.progressionDelay or 30
    data.contagious = data.contagious != false
    data.baseIncubation = data.baseIncubation or 1
    data.vectors = data.vectors or {air = true}
    data.stages = data.stages or {}
    data.cureWith = data.cureWith or {}

    -- Validate stages have sequential IDs
    for i, stage in ipairs(data.stages) do
        stage.id = stage.id or i
        stage.effects = stage.effects or {}
    end

    ix.disease._registered[id] = data
end

--- Get a registered disease definition by ID.
-- @param id string Disease identifier
-- @return table|nil Disease data table or nil if not found
function ix.disease.Get(id)
    return ix.disease._registered[id]
end

--- Get all registered disease definitions.
-- @return table Dictionary of {id = data}
function ix.disease.GetAll()
    return ix.disease._registered
end

--- Get the total number of stages for a disease.
-- @param id string Disease identifier
-- @return number Stage count
function ix.disease.GetStageCount(id)
    local disease = ix.disease.Get(id)
    if (!disease) then return 0 end
    return #disease.stages
end

--- Get a specific stage definition from a disease.
-- @param id string Disease identifier
-- @param stageNum number Stage number (1-indexed)
-- @return table|nil Stage data table
function ix.disease.GetStage(id, stageNum)
    local disease = ix.disease.Get(id)
    if (!disease or !disease.stages) then return nil end
    return disease.stages[stageNum]
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CHARACTER DISEASE STATE (Shared Query Functions)
-- ═══════════════════════════════════════════════════════════════════════════════

--- Get all active diseases on a character.
-- @param character table Helix character object
-- @return table Dictionary of {diseaseID = {stage, infectedAt, treatedWith, ...}}
function ix.disease.GetActiveDiseases(character)
    if (!character) then return {} end
    return character:GetData("diseases", {})
end

--- Check if a character has a specific active disease.
-- @param character table Helix character object
-- @param diseaseID string Disease identifier
-- @return bool
function ix.disease.HasDisease(character, diseaseID)
    local diseases = ix.disease.GetActiveDiseases(character)
    return diseases[diseaseID] != nil
end

--- Get the current stage of a disease on a character.
-- @param character table Helix character object
-- @param diseaseID string Disease identifier
-- @return number|nil Current stage number or nil
function ix.disease.GetStageOf(character, diseaseID)
    local diseases = ix.disease.GetActiveDiseases(character)
    if (!diseases[diseaseID]) then return nil end
    return diseases[diseaseID].stage
end

--- Get vaccines the character is immune to.
-- @param character table Helix character object
-- @return table Dictionary of {diseaseID = timestamp}
function ix.disease.GetVaccines(character)
    if (!character) then return {} end
    return character:GetData("vaccines", {})
end

--- Check if a character is vaccinated against a specific disease.
-- @param character table Helix character object
-- @param diseaseID string Disease identifier
-- @return bool
function ix.disease.IsVaccinated(character, diseaseID)
    local vaccines = ix.disease.GetVaccines(character)
    if (!vaccines[diseaseID]) then return false end

    -- Check vaccine expiry if applicable
    local duration = ix.disease.Config.VACCINE_DURATION
    if (duration > 0) then
        return (CurTime() - (vaccines[diseaseID] or 0)) < duration
    end

    return true
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SERVER-ONLY API (stubs defined here, implemented in sv_plugin.lua)
-- ═══════════════════════════════════════════════════════════════════════════════

if (SERVER) then
    --- Infect a character with a disease.
    -- @param character table Helix character object
    -- @param diseaseID string Disease identifier
    -- @param force bool If true, bypasses immunity and max disease checks
    -- @return bool, string Success and optional error message
    function ix.disease.Infect(character, diseaseID, force)
        -- Implementation in sv_plugin.lua
        ErrorNoHalt("[SmartDisease] ix.disease.Infect called before sv_plugin.lua loaded.\n")
        return false, "System not initialized."
    end

    --- Cure a character of a specific disease.
    -- @param character table Helix character object
    -- @param diseaseID string Disease identifier
    function ix.disease.Cure(character, diseaseID)
        ErrorNoHalt("[SmartDisease] ix.disease.Cure called before sv_plugin.lua loaded.\n")
    end

    --- Cure a character of all diseases.
    -- @param character table Helix character object
    function ix.disease.CureAll(character)
        ErrorNoHalt("[SmartDisease] ix.disease.CureAll called before sv_plugin.lua loaded.\n")
    end

    --- Vaccinate a character against a disease.
    -- @param character table Helix character object
    -- @param diseaseID string Disease identifier
    function ix.disease.Vaccinate(character, diseaseID)
        ErrorNoHalt("[SmartDisease] ix.disease.Vaccinate called before sv_plugin.lua loaded.\n")
    end

    --- Set the progression stage of a disease on a character.
    -- @param character table Helix character object
    -- @param diseaseID string Disease identifier
    -- @param stage number Target stage number
    function ix.disease.SetProgress(character, diseaseID, stage)
        ErrorNoHalt("[SmartDisease] ix.disease.SetProgress called before sv_plugin.lua loaded.\n")
    end
end
