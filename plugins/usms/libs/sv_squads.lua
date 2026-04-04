-- ═══════════════════════════════════════════════════════════════════════════════
-- SQUAD SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

--- Create a squad within a unit.
-- @param ply Player The player creating the squad
-- @param name string Squad designation
-- @param callback function(success, error|squadID)
function ix.usms.CreateSquad(ply, name, callback)
    local char = ply:GetCharacter()
    if (!char) then
        if (callback) then callback(false, "No character") end
        return
    end

    local charID = char:GetID()
    local member = ix.usms.members[charID]
    if (!member) then
        if (callback) then callback(false, "Not in a unit") end
        return
    end

    if (ix.usms.squadMembers[charID]) then
        if (callback) then callback(false, "Already in a squad") end
        return
    end

    -- Permission check hook
    local canCreate, reason = hook.Run("USMSCanCreateSquad", ply, char, member)
    if (canCreate == false) then
        if (callback) then callback(false, reason or "Not authorized") end
        return
    end

    local unitID = member.unitID
    local unit = ix.usms.units[unitID]

    -- Check squad cap
    if (ix.usms.GetUnitSquadCount(unitID) >= unit.maxSquads) then
        if (callback) then callback(false, "Unit has reached maximum number of squads") end
        return
    end

    local squadID = ix.usms.db.AllocSquadID()
    local now = os.time()

    -- Cache squad
    ix.usms.squads[squadID] = {
        id = squadID,
        unitID = unitID,
        name = name,
        description = "",
        leaderCharID = charID,
        createdAt = now
    }

    -- Add creator as squad leader
    ix.usms.squadMembers[charID] = {
        squadID = squadID,
        characterID = charID,
        role = USMS_SQUAD_LEADER,
        joinedAt = now
    }

    -- Update CharVars
    char:SetUsmSquadID(squadID)
    char:SetUsmSquadRole(USMS_SQUAD_LEADER)

    ix.usms.db.Save()

    -- Log
    ix.usms.Log(unitID, USMS_LOG_SQUAD_CREATED, charID, nil, {squadName = name, squadID = squadID})

    -- Sync HUD
    ix.usms.SyncSquadToHUD(squadID)

    -- Full sync to all unit members (squad list changed)
    ix.usms.FullSyncToUnit(unitID)

    if (callback) then callback(true, squadID) end
    hook.Run("USMSSquadCreated", squadID, unitID, charID)
end

--- Default squad creation permission hook.
hook.Add("USMSCanCreateSquad", "ixUSMSDefaultPermission", function(ply, char, member)
    -- Superadmins always bypass
    if (ply:IsSuperAdmin()) then return true end

    -- CO and XO can always create squads
    if (member.role >= USMS_ROLE_XO) then
        return true
    end

    return false, "Insufficient rank or certification"
end)

--- Add a character to a squad.
-- @param charID number
-- @param squadID number
-- @param callback function(success, error)
function ix.usms.AddToSquad(charID, squadID, callback)
    local squad = ix.usms.squads[squadID]
    if (!squad) then
        if (callback) then callback(false, "Squad not found") end
        return
    end

    local member = ix.usms.members[charID]
    if (!member or member.unitID != squad.unitID) then
        if (callback) then callback(false, "Character is not in this unit") end
        return
    end

    if (ix.usms.squadMembers[charID]) then
        if (callback) then callback(false, "Already in a squad") end
        return
    end

    local maxSize = ix.config.Get("usmsSquadMaxSize", USMS_SQUAD_MAX_SIZE)
    local squadSize = table.Count(ix.usms.GetSquadMembers(squadID))
    if (squadSize >= maxSize) then
        if (callback) then callback(false, "Squad is full") end
        return
    end

    local now = os.time()

    ix.usms.squadMembers[charID] = {
        squadID = squadID,
        characterID = charID,
        role = USMS_SQUAD_MEMBER,
        joinedAt = now
    }

    local char = ix.usms.GetCharacterByID(charID)
    if (char) then
        char:SetUsmSquadID(squadID)
        char:SetUsmSquadRole(USMS_SQUAD_MEMBER)
    end

    ix.usms.db.Save()

    ix.usms.Log(squad.unitID, USMS_LOG_SQUAD_MEMBER_JOIN, nil, charID, {squadID = squadID})
    ix.usms.SyncSquadToHUD(squadID)

    -- Full sync to all unit members (squad membership changed)
    ix.usms.FullSyncToUnit(squad.unitID)

    if (callback) then callback(true) end
    hook.Run("USMSSquadMemberAdded", charID, squadID)
end

--- Remove a character from their squad.
-- @param charID number
-- @param kickerCharID number|nil
-- @param callback function(success, error)
function ix.usms.RemoveFromSquad(charID, kickerCharID, callback)
    local sm = ix.usms.squadMembers[charID]
    if (!sm) then
        if (callback) then callback(false, "Not in a squad") end
        return
    end

    local squadID = sm.squadID
    local squad = ix.usms.squads[squadID]
    local wasLeader = (sm.role == USMS_SQUAD_LEADER)

    ix.usms.squadMembers[charID] = nil

    local char = ix.usms.GetCharacterByID(charID)
    if (char) then
        char:SetUsmSquadID(0)
        char:SetUsmSquadRole(0)
    end

    local logAction = kickerCharID and USMS_LOG_SQUAD_MEMBER_KICKED or USMS_LOG_SQUAD_MEMBER_LEAVE
    if (squad) then
        ix.usms.Log(squad.unitID, logAction, kickerCharID, charID, {squadID = squadID})
    end

    ix.usms.db.Save()

    -- If leader left, handle succession or disband
    if (wasLeader and squad) then
        ix.usms.HandleSquadLeaderVacancy(squadID)
    else
        ix.usms.SyncSquadToHUD(squadID)
    end

    if (callback) then callback(true) end
    hook.Run("USMSSquadMemberRemoved", charID, squadID, kickerCharID)

    -- Full sync to all unit members (squad membership changed)
    if (squad) then
        ix.usms.FullSyncToUnit(squad.unitID)
    end
end

--- Handle when a squad leader leaves.
-- @param squadID number
function ix.usms.HandleSquadLeaderVacancy(squadID)
    local members = ix.usms.GetSquadMembers(squadID)
    local remainingCount = table.Count(members)
    local minSize = ix.config.Get("usmsSquadMinSize", USMS_SQUAD_MIN_SIZE)

    if (remainingCount < minSize) then
        ix.usms.DisbandSquad(squadID, nil)
        return
    end

    -- Promote highest-ranked remaining member, then fall back to most senior
    local bestCharID = nil
    local bestRole = -1
    local bestJoined = math.huge

    for charID, sm in pairs(members) do
        if (sm.role > bestRole) then
            bestRole = sm.role
            bestJoined = sm.joinedAt or math.huge
            bestCharID = charID
        elseif (sm.role == bestRole and (sm.joinedAt or math.huge) < bestJoined) then
            bestJoined = sm.joinedAt or math.huge
            bestCharID = charID
        end
    end

    if (bestCharID) then
        ix.usms.SetSquadLeader(squadID, bestCharID)
    else
        ix.usms.DisbandSquad(squadID, nil)
    end
end

--- Set a new squad leader.
-- @param squadID number
-- @param newLeaderCharID number
function ix.usms.SetSquadLeader(squadID, newLeaderCharID)
    local squad = ix.usms.squads[squadID]
    if (!squad) then return end

    local oldLeaderCharID = squad.leaderCharID
    squad.leaderCharID = newLeaderCharID

    -- Update squad member roles
    for charID, sm in pairs(ix.usms.squadMembers) do
        if (sm.squadID == squadID) then
            if (charID == newLeaderCharID) then
                sm.role = USMS_SQUAD_LEADER
                local char = ix.usms.GetCharacterByID(charID)
                if (char) then
                    char:SetUsmSquadRole(USMS_SQUAD_LEADER)
                end
            elseif (sm.role == USMS_SQUAD_LEADER) then
                sm.role = USMS_SQUAD_MEMBER
                local char = ix.usms.GetCharacterByID(charID)
                if (char) then
                    char:SetUsmSquadRole(USMS_SQUAD_MEMBER)
                end
            end
        end
    end

    ix.usms.db.Save()
    ix.usms.SyncSquadToHUD(squadID)

    hook.Run("USMSSquadLeaderChanged", squadID, oldLeaderCharID, newLeaderCharID)
end

--- Disband a squad entirely.
-- @param squadID number
-- @param disbandedByCharID number|nil
-- @param callback function(success, error)
function ix.usms.DisbandSquad(squadID, disbandedByCharID, callback)
    local squad = ix.usms.squads[squadID]
    if (!squad) then
        if (callback) then callback(false, "Squad not found") end
        return
    end

    local unitID = squad.unitID

    -- Clear all squad members
    for charID, sm in pairs(ix.usms.squadMembers) do
        if (sm.squadID == squadID) then
            ix.usms.squadMembers[charID] = nil

            local char = ix.usms.GetCharacterByID(charID)
            if (char) then
                char:SetUsmSquadID(0)
                char:SetUsmSquadRole(0)
            end
        end
    end

    ix.usms.squads[squadID] = nil
    ix.usms.db.Save()

    ix.usms.Log(unitID, USMS_LOG_SQUAD_DISBANDED, disbandedByCharID, nil, {squadName = squad.name, squadID = squadID})

    -- Notify HUD
    ix.usms.ClearSquadFromHUD(squadID, unitID)

    if (callback) then callback(true) end
    hook.Run("USMSSquadDisbanded", squadID, unitID, disbandedByCharID)

    -- Full sync to all unit members (squad list changed)
    ix.usms.FullSyncToUnit(unitID)
end

