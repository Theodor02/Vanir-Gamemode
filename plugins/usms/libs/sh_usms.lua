--- Unit & Squad Management System - Shared API Namespace
-- @module ix.usms

ix.usms = ix.usms or {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- CONSTANTS (defined here so they are available before derma/ files load)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Unit roles
USMS_ROLE_MEMBER = 0
USMS_ROLE_XO     = 1
USMS_ROLE_CO     = 2

-- Squad roles
USMS_SQUAD_MEMBER  = 0
USMS_SQUAD_INVITER = 1
USMS_SQUAD_XO      = 2
USMS_SQUAD_LEADER  = 3

-- Squad size limits
USMS_SQUAD_MIN_SIZE = 2
USMS_SQUAD_MAX_SIZE = 8

-- Log action type constants
USMS_LOG_UNIT_MEMBER_JOIN     = "unit_member_join"
USMS_LOG_UNIT_MEMBER_LEAVE    = "unit_member_leave"
USMS_LOG_UNIT_MEMBER_KICKED   = "unit_member_kicked"
USMS_LOG_UNIT_ROLE_CHANGED    = "unit_role_changed"
USMS_LOG_UNIT_CLASS_CHANGED   = "unit_class_changed"
USMS_LOG_UNIT_RESOURCE_CHANGE = "unit_resource_change"
USMS_LOG_SQUAD_CREATED        = "squad_created"
USMS_LOG_SQUAD_DISBANDED      = "squad_disbanded"
USMS_LOG_SQUAD_MEMBER_JOIN    = "squad_member_join"
USMS_LOG_SQUAD_MEMBER_LEAVE   = "squad_member_leave"
USMS_LOG_SQUAD_MEMBER_KICKED  = "squad_member_kicked"
USMS_LOG_GEARUP               = "gearup"
USMS_LOG_CLASS_WHITELIST       = "class_whitelist"
USMS_LOG_MISSION_CREATED      = "mission_created"
USMS_LOG_MISSION_COMPLETED    = "mission_completed"
USMS_LOG_MISSION_CANCELLED    = "mission_cancelled"
USMS_LOG_COMMENDATION_AWARDED = "commendation_awarded"
USMS_LOG_COMMENDATION_REVOKED = "commendation_revoked"

-- Mission status
USMS_MISSION_ACTIVE    = "active"
USMS_MISSION_COMPLETE  = "complete"
USMS_MISSION_CANCELLED = "cancelled"

-- Mission priority
USMS_MISSION_PRIORITY_LOW      = 1
USMS_MISSION_PRIORITY_NORMAL   = 2
USMS_MISSION_PRIORITY_CRITICAL = 3

-- Commendation types
USMS_COMMENDATION_MEDAL        = "medal"
USMS_COMMENDATION_COMMENDATION = "commendation"
USMS_COMMENDATION_REPRIMAND    = "reprimand"

-- ═══════════════════════════════════════════════════════════════════════════════
-- SERVER-SIDE CACHE (populated from saved data on load, kept in sync)
-- ═══════════════════════════════════════════════════════════════════════════════

if (SERVER) then
    ix.usms.units = ix.usms.units or {}               -- [unitID] = unitData
    ix.usms.squads = ix.usms.squads or {}             -- [squadID] = squadData
    ix.usms.members = ix.usms.members or {}           -- [charID] = memberData
    ix.usms.squadMembers = ix.usms.squadMembers or {} -- [charID] = squadMemberData

    -- Mission & commendation caches
    ix.usms.missions = ix.usms.missions or {}             -- [missionID] = missionData
    ix.usms.commendations = ix.usms.commendations or {}   -- [commendationID] = commendationData

    -- Auto-increment counters (managed by sv_database.lua)
    ix.usms.nextUnitID = ix.usms.nextUnitID or 1
    ix.usms.nextSquadID = ix.usms.nextSquadID or 1
    ix.usms.nextMissionID = ix.usms.nextMissionID or 1
    ix.usms.nextCommendationID = ix.usms.nextCommendationID or 1
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SHARED UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Resolve a class uniqueID to its runtime numeric index.
-- @param uniqueID string Class uniqueID (e.g., "army_recruit")
-- @param factionID number|nil Optional faction filter
-- @return number|nil classIndex
function ix.usms.GetClassIndexByUID(uniqueID, factionID)
    if (!uniqueID or uniqueID == "") then return nil end

    for index, classInfo in pairs(ix.class.list or {}) do
        if (classInfo.uniqueID == uniqueID) then
            if (!factionID or classInfo.faction == factionID) then
                return index
            end
        end
    end
    return nil
end

--- Get a character object by ID (online characters only).
-- @param charID number Character ID
-- @return Character|nil
function ix.usms.GetCharacterByID(charID)
    for _, ply in ipairs(player.GetAll()) do
        local char = ply:GetCharacter()
        if (char and char:GetID() == charID) then
            return char
        end
    end
    return nil
end

--- Get the player entity for a character ID (online only).
-- @param charID number
-- @return Player|nil
function ix.usms.GetPlayerByCharID(charID)
    for _, ply in ipairs(player.GetAll()) do
        local char = ply:GetCharacter()
        if (char and char:GetID() == charID) then
            return ply
        end
    end
    return nil
end

--- Get all online player entities who are members of a unit.
-- @param unitID number
-- @return table of Player entities
function ix.usms.GetOnlineUnitMembers(unitID)
    local players = {}
    if (!SERVER) then return players end

    for charID, member in pairs(ix.usms.members) do
        if (member.unitID == unitID) then
            local ply = ix.usms.GetPlayerByCharID(charID)
            if (IsValid(ply)) then
                table.insert(players, ply)
            end
        end
    end
    return players
end

--- Get count of members in a unit.
-- @param unitID number
-- @return number
function ix.usms.GetUnitMemberCount(unitID)
    if (!SERVER) then return 0 end

    local count = 0
    for _, member in pairs(ix.usms.members) do
        if (member.unitID == unitID) then
            count = count + 1
        end
    end
    return count
end

--- Get all member data for a unit.
-- @param unitID number
-- @return table [charID] = memberData
function ix.usms.GetUnitMembers(unitID)
    local members = {}
    if (!SERVER) then return members end

    for charID, member in pairs(ix.usms.members) do
        if (member.unitID == unitID) then
            members[charID] = member
        end
    end
    return members
end

--- Get all squads in a unit.
-- @param unitID number
-- @return table [squadID] = squadData
function ix.usms.GetUnitSquads(unitID)
    local squads = {}
    if (!SERVER) then return squads end

    for squadID, squad in pairs(ix.usms.squads) do
        if (squad.unitID == unitID) then
            squads[squadID] = squad
        end
    end
    return squads
end

--- Get all members of a squad.
-- @param squadID number
-- @return table [charID] = squadMemberData
function ix.usms.GetSquadMembers(squadID)
    local members = {}
    if (!SERVER) then return members end

    for charID, sm in pairs(ix.usms.squadMembers) do
        if (sm.squadID == squadID) then
            members[charID] = sm
        end
    end
    return members
end

--- Get the squad count for a unit.
-- @param unitID number
-- @return number
function ix.usms.GetUnitSquadCount(unitID)
    if (!SERVER) then return 0 end

    local count = 0
    for _, squad in pairs(ix.usms.squads) do
        if (squad.unitID == unitID) then
            count = count + 1
        end
    end
    return count
end

--- Get all units for a faction.
-- @param factionID number Helix faction index
-- @return table [unitID] = unitData
function ix.usms.GetFactionUnits(factionID)
    local units = {}
    if (!SERVER) then return units end

    for unitID, unit in pairs(ix.usms.units) do
        if (unit.factionID == factionID) then
            units[unitID] = unit
        end
    end
    return units
end

--- Get resource status text from resources and cap.
-- @param resources number
-- @param cap number
-- @return string
function ix.usms.GetResourceStatus(resources, cap)
    if (cap == 0) then return "UNKNOWN" end
    local pct = resources / cap
    if (pct >= 0.75) then return "WELL SUPPLIED"
    elseif (pct >= 0.40) then return "ADEQUATE"
    elseif (pct >= 0.15) then return "LOW"
    else return "CRITICAL" end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLIENT-SIDE ACCESSORS
-- ═══════════════════════════════════════════════════════════════════════════════

if (CLIENT) then
    --- Get unit data from client cache.
    -- @param unitID number
    -- @return table|nil
    function ix.usms.GetUnitData(unitID)
        if (ix.usms.clientData and ix.usms.clientData.unit and ix.usms.clientData.unit.id == unitID) then
            return ix.usms.clientData.unit
        end
        -- Check intel cache
        if (ix.usms.clientData and ix.usms.clientData.intelUnits[unitID]) then
            return ix.usms.clientData.intelUnits[unitID]
        end
        return nil
    end

    --- Get squad data from client cache.
    -- @param squadID number
    -- @return table|nil
    function ix.usms.GetSquadData(squadID)
        if (ix.usms.clientData and ix.usms.clientData.squads[squadID]) then
            return ix.usms.clientData.squads[squadID]
        end
        return nil
    end
end
