--- USMS Character Meta Extensions
-- Registers character variables and adds helper methods to the character meta.

-- ═══════════════════════════════════════════════════════════════════════════════
-- CHARACTER VARIABLES
-- Auto-persisted to character DB row, auto-networked to clients.
-- ═══════════════════════════════════════════════════════════════════════════════

-- Unit ID the character belongs to (0 if not in a unit)
ix.char.RegisterVar("usmUnitID", {
    field = "usm_unit_id",
    fieldType = ix.type.number,
    default = 0,
    isLocal = false,
    bNoDisplay = true
})

-- Unit role (0=member, 1=XO, 2=CO)
ix.char.RegisterVar("usmUnitRole", {
    field = "usm_unit_role",
    fieldType = ix.type.number,
    default = 0,
    isLocal = false,
    bNoDisplay = true
})

-- Squad ID the character belongs to (0 if not in a squad)
ix.char.RegisterVar("usmSquadID", {
    field = "usm_squad_id",
    fieldType = ix.type.number,
    default = 0,
    isLocal = false,
    bNoDisplay = true
})

-- Squad role (0=member, 1=inviter, 2=xo, 3=leader)
ix.char.RegisterVar("usmSquadRole", {
    field = "usm_squad_role",
    fieldType = ix.type.number,
    default = 0,
    isLocal = false,
    bNoDisplay = true
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- CHARACTER META HELPERS
-- ═══════════════════════════════════════════════════════════════════════════════

local charMeta = ix.meta.character

--- Get the unit data table for this character's unit.
-- @return table|nil
function charMeta:GetUnit()
    local unitID = self:GetUsmUnitID()
    if (!unitID or unitID == 0) then return nil end

    if (SERVER) then
        return ix.usms.units[unitID]
    else
        return ix.usms.GetUnitData(unitID)
    end
end

--- Get the squad data table for this character's squad.
-- @return table|nil
function charMeta:GetSquad()
    local squadID = self:GetUsmSquadID()
    if (!squadID or squadID == 0) then return nil end

    if (SERVER) then
        return ix.usms.squads[squadID]
    else
        return ix.usms.GetSquadData(squadID)
    end
end

--- Is this character the unit CO?
-- @return bool
function charMeta:IsUnitCO()
    return self:GetUsmUnitRole() == USMS_ROLE_CO
end

--- Is this character the unit XO?
-- @return bool
function charMeta:IsUnitXO()
    return self:GetUsmUnitRole() == USMS_ROLE_XO
end

--- Is this character a unit officer (XO or CO)?
-- @return bool
function charMeta:IsUnitOfficer()
    return self:GetUsmUnitRole() >= USMS_ROLE_XO
end

--- Is this character a squad leader?
-- @return bool
function charMeta:IsSquadLeader()
    return self:GetUsmSquadRole() == USMS_SQUAD_LEADER
end

--- Is this character a squad XO?
-- @return bool
function charMeta:IsSquadXO()
    return self:GetUsmSquadRole() == USMS_SQUAD_XO
end

--- Is this character a squad officer (XO or Leader)?
-- @return bool
function charMeta:IsSquadOfficer()
    return self:GetUsmSquadRole() >= USMS_SQUAD_XO
end

--- Can this character invite to their squad?
-- @return bool
function charMeta:CanSquadInvite()
    return self:GetUsmSquadRole() >= USMS_SQUAD_INVITER
end

--- Is this character in a unit?
-- @return bool
function charMeta:IsInUnit()
    local id = self:GetUsmUnitID()
    return id != nil and id != 0
end

--- Is this character in a squad?
-- @return bool
function charMeta:IsInSquad()
    local id = self:GetUsmSquadID()
    return id != nil and id != 0
end
