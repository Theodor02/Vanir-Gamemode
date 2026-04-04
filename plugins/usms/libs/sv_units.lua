function ix.usms.HasPermission(ply, char, requiredRole)
    if (ply:IsSuperAdmin()) then return true end
    local member = ix.usms.members[char:GetID()]
    if (!member) then return false end
    return member.role >= requiredRole
end


-- ═══════════════════════════════════════════════════════════════════════════════
-- UNIT CRUD
-- ═══════════════════════════════════════════════════════════════════════════════

--- Create a new unit.
-- @param name string Unit name
-- @param factionID number Helix faction index
-- @param data table Optional {description, resourceCap, maxMembers, maxSquads, resources}
-- @param callback function(unitID)
-- @return bool, string success/error
function ix.usms.CreateUnit(name, factionID, data, callback)
    data = data or {}

    if (!ix.faction.indices[factionID]) then
        return false, "Invalid faction"
    end

    local unitID = ix.usms.db.AllocUnitID()
    local now = os.time()

    ix.usms.units[unitID] = {
        id = unitID,
        name = name,
        description = data.description or "",
        factionID = factionID,
        resources = data.resources or 0,
        resourceCap = data.resourceCap or 10000,
        maxMembers = data.maxMembers or 30,
        maxSquads = data.maxSquads or 5,
        createdAt = now,
        data = data.extra or {}
    }

    ix.usms.db.Save()

    if (callback) then callback(unitID) end
    hook.Run("USMSUnitCreated", unitID, name, factionID)

    return true
end

--- Delete a unit and all associated data.
-- @param unitID number
-- @param callback function()
-- @return bool, string
function ix.usms.DeleteUnit(unitID, callback)
    local unit = ix.usms.units[unitID]
    if (!unit) then return false, "Unit not found" end

    -- Clear all members' CharVars
    for charID, member in pairs(ix.usms.members) do
        if (member.unitID == unitID) then
            local char = ix.usms.GetCharacterByID(charID)
            if (char) then
                char:SetUsmUnitID(0)
                char:SetUsmUnitRole(0)
                char:SetUsmSquadID(0)
                char:SetUsmSquadRole(0)
            end
            ix.usms.members[charID] = nil
        end
    end

    -- Clear squads and squad members for this unit
    for squadID, squad in pairs(ix.usms.squads) do
        if (squad.unitID == unitID) then
            for charID, sm in pairs(ix.usms.squadMembers) do
                if (sm.squadID == squadID) then
                    ix.usms.squadMembers[charID] = nil
                end
            end
            ix.usms.squads[squadID] = nil
        end
    end

    ix.usms.units[unitID] = nil
    ix.usms.db.Save()

    if (callback) then callback() end
    hook.Run("USMSUnitDeleted", unitID)

    return true
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MEMBER MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════════

--- Add a character to a unit.
-- @param charID number Character ID
-- @param unitID number Unit ID
-- @param role number USMS_ROLE_* (default USMS_ROLE_MEMBER)
-- @param callback function(success, error)
function ix.usms.AddMember(charID, unitID, role, callback)
    role = role or USMS_ROLE_MEMBER

    local unit = ix.usms.units[unitID]
    if (!unit) then
        if (callback) then callback(false, "Unit not found") end
        return
    end

    -- Check if already in a unit
    if (ix.usms.members[charID]) then
        if (callback) then callback(false, "Character is already in a unit") end
        return
    end

    -- Check faction match
    local char = ix.usms.GetCharacterByID(charID)
    if (!char) then
        if (callback) then callback(false, "Character not found or offline") end
        return
    end

    if (char:GetFaction() != unit.factionID) then
        if (callback) then callback(false, "Character is not in the correct faction") end
        return
    end

    -- Check member cap
    local memberCount = ix.usms.GetUnitMemberCount(unitID)
    if (memberCount >= unit.maxMembers) then
        if (callback) then callback(false, "Unit is full") end
        return
    end

    local now = os.time()

    -- Update cache
    ix.usms.members[charID] = {
        unitID = unitID,
        characterID = charID,
        role = role,
        joinedAt = now,
        cachedName = char:GetName(),
        cachedClass = char:GetClass() or 0,
        cachedClassName = (ix.class.list[char:GetClass() or 0] or {}).name or "Unassigned",
        cachedClassUID = (ix.class.list[char:GetClass() or 0] or {}).uniqueID or "",
        cachedLastSeen = now,
        classWhitelist = {}
    }

    -- Update CharVars (auto-persisted to character DB row)
    char:SetUsmUnitID(unitID)
    char:SetUsmUnitRole(role)

    ix.usms.db.Save()

    -- Log
    ix.usms.Log(unitID, USMS_LOG_UNIT_MEMBER_JOIN, nil, charID)

    -- Sync to unit members
    ix.usms.SyncRosterUpdateToUnit(unitID, charID, "add")

    -- Full sync to the newly added player
    local ply = ix.usms.GetPlayerByCharID(charID)
    if (IsValid(ply)) then
        timer.Simple(0.5, function()
            if (IsValid(ply)) then ix.usms.FullSyncToPlayer(ply) end
        end)
    end

    if (callback) then callback(true) end
    hook.Run("USMSMemberAdded", charID, unitID, role)
end

--- Remove a character from their unit (and squad if applicable).
-- @param charID number Character ID
-- @param kickerCharID number|nil Who kicked them
-- @param callback function(success, error)
function ix.usms.RemoveMember(charID, kickerCharID, callback)
    local member = ix.usms.members[charID]
    if (!member) then
        if (callback) then callback(false, "Not in a unit") end
        return
    end

    local unitID = member.unitID

    -- Remove from squad first if in one
    if (ix.usms.squadMembers[charID]) then
        ix.usms.RemoveFromSquad(charID)
    end

    -- Clear cache
    ix.usms.members[charID] = nil

    -- Clear CharVars
    local char = ix.usms.GetCharacterByID(charID)
    if (char) then
        char:SetUsmUnitID(0)
        char:SetUsmUnitRole(0)
    end

    ix.usms.db.Save()

    -- Log
    local logAction = kickerCharID and USMS_LOG_UNIT_MEMBER_KICKED or USMS_LOG_UNIT_MEMBER_LEAVE
    ix.usms.Log(unitID, logAction, kickerCharID, charID)

    -- Sync roster to remaining members
    ix.usms.SyncRosterUpdateToUnit(unitID, charID, "remove")

    -- Sync the removed player (clear their UI)
    local ply = ix.usms.GetPlayerByCharID(charID)
    if (IsValid(ply)) then
        ix.usms.SyncUnitToPlayer(ply, unitID)
    end

    if (callback) then callback(true) end
    hook.Run("USMSMemberRemoved", charID, unitID, kickerCharID)
end

--- Set a member's unit role.
-- @param charID number
-- @param newRole number USMS_ROLE_*
-- @param callback function(success, error)
function ix.usms.SetMemberRole(charID, newRole, callback)
    local member = ix.usms.members[charID]
    if (!member) then
        if (callback) then callback(false, "Not in a unit") end
        return
    end

    local oldRole = member.role
    member.role = newRole

    local char = ix.usms.GetCharacterByID(charID)
    if (char) then
        char:SetUsmUnitRole(newRole)
    end

    ix.usms.db.Save()

    ix.usms.Log(member.unitID, USMS_LOG_UNIT_ROLE_CHANGED, nil, charID, {
        oldRole = oldRole,
        newRole = newRole
    })

    ix.usms.SyncRosterUpdateToUnit(member.unitID, charID, "update")

    -- Full sync to the affected player
    local ply = ix.usms.GetPlayerByCharID(charID)
    if (IsValid(ply)) then
        ix.usms.FullSyncToPlayer(ply)
    end

    if (callback) then callback(true) end
    hook.Run("USMSMemberRoleChanged", charID, member.unitID, oldRole, newRole)
end

--- Transfer CO status within a unit.
-- @param unitID number
-- @param newCOCharID number
-- @param callback function(success, error)
function ix.usms.TransferCO(unitID, newCOCharID, callback)
    local unit = ix.usms.units[unitID]
    if (!unit) then
        if (callback) then callback(false, "Unit not found") end
        return
    end

    local newMember = ix.usms.members[newCOCharID]
    if (!newMember or newMember.unitID != unitID) then
        if (callback) then callback(false, "Target is not in this unit") end
        return
    end

    -- Demote current CO to member
    for charID, member in pairs(ix.usms.members) do
        if (member.unitID == unitID and member.role == USMS_ROLE_CO) then
            member.role = USMS_ROLE_MEMBER
            local char = ix.usms.GetCharacterByID(charID)
            if (char) then
                char:SetUsmUnitRole(USMS_ROLE_MEMBER)
            end
        end
    end

    -- Promote new CO
    newMember.role = USMS_ROLE_CO
    local char = ix.usms.GetCharacterByID(newCOCharID)
    if (char) then
        char:SetUsmUnitRole(USMS_ROLE_CO)
    end

    ix.usms.db.Save()

    ix.usms.Log(unitID, USMS_LOG_UNIT_ROLE_CHANGED, nil, newCOCharID, {
        newRole = USMS_ROLE_CO,
        action = "co_transfer"
    })

    ix.usms.SyncRosterUpdateToUnit(unitID, newCOCharID, "update")

    if (callback) then callback(true) end
end

