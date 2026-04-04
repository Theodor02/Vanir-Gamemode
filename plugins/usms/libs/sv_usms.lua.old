--- USMS Server-Side API
-- Full unit/squad/resource/gearup API implementation.

-- ═══════════════════════════════════════════════════════════════════════════════
-- NET STRINGS
-- ═══════════════════════════════════════════════════════════════════════════════

util.AddNetworkString("ixUSMSUnitSync")
util.AddNetworkString("ixUSMSUnitUpdate")
util.AddNetworkString("ixUSMSRosterSync")
util.AddNetworkString("ixUSMSRosterUpdate")
util.AddNetworkString("ixUSMSSquadSync")
util.AddNetworkString("ixUSMSSquadUpdate")
util.AddNetworkString("ixUSMSLogSync")
util.AddNetworkString("ixUSMSIntelSync")
util.AddNetworkString("ixUSMSRequest")
util.AddNetworkString("ixUSMSInvite")
util.AddNetworkString("ixUSMSInviteResponse")
util.AddNetworkString("ixUSMSMissionSync")
util.AddNetworkString("ixUSMSMissionUpdate")
util.AddNetworkString("ixUSMSServiceRecord")

-- ═══════════════════════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Full sync to a single player: unit data + roster.
-- Call after any action that affects the player's USMS state.
-- @param ply Player
function ix.usms.FullSyncToPlayer(ply)
    if (!IsValid(ply)) then return end
    local char = ply:GetCharacter()
    if (!char) then return end

    local member = ix.usms.members[char:GetID()]
    if (!member) then return end

    ix.usms.SyncUnitToPlayer(ply, member.unitID)
    ix.usms.SendRoster(ply, member.unitID)
end

--- Sync all online unit members (full unit + roster refresh).
-- @param unitID number
function ix.usms.FullSyncToUnit(unitID)
    local recipients = ix.usms.GetOnlineUnitMembers(unitID)
    for _, ply in ipairs(recipients) do
        ix.usms.FullSyncToPlayer(ply)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- PENDING INVITES
-- ═══════════════════════════════════════════════════════════════════════════════

--- Pending invites: key = target charID, value = {type, unitID, squadID, inviterCharID, inviterName, unitName, squadName, timestamp}
ix.usms.pendingInvites = ix.usms.pendingInvites or {}

local INVITE_EXPIRY = 60 -- seconds

--- Send an invite to a player (unit or squad).
-- @param targetCharID number
-- @param inviteType string "unit" or "squad"
-- @param inviterCharID number
-- @param unitID number
-- @param squadID number|nil (for squad invites)
function ix.usms.SendInvite(targetCharID, inviteType, inviterCharID, unitID, squadID)
    -- Cancel any existing invite for this target
    ix.usms.pendingInvites[targetCharID] = nil

    local targetPly = ix.usms.GetPlayerByCharID(targetCharID)
    if (!IsValid(targetPly)) then return false, "Target is offline" end

    local unit = ix.usms.units[unitID]
    if (!unit) then return false, "Unit not found" end

    local inviterChar = ix.usms.GetCharacterByID(inviterCharID)
    local inviterName = inviterChar and inviterChar:GetName() or "Unknown"

    local invite = {
        type = inviteType,
        unitID = unitID,
        inviterCharID = inviterCharID,
        inviterName = inviterName,
        unitName = unit.name,
        timestamp = os.time()
    }

    if (inviteType == "squad" and squadID) then
        local squad = ix.usms.squads[squadID]
        if (!squad) then return false, "Squad not found" end
        invite.squadID = squadID
        invite.squadName = squad.name
    end

    ix.usms.pendingInvites[targetCharID] = invite

    -- Send to client
    net.Start("ixUSMSInvite")
        net.WriteString(inviteType)
        net.WriteString(invite.unitName)
        net.WriteString(invite.inviterName)
        net.WriteString(invite.squadName or "")
    net.Send(targetPly)

    -- Auto-expire
    timer.Create("ixUSMSInviteExpiry_" .. targetCharID, INVITE_EXPIRY, 1, function()
        ix.usms.pendingInvites[targetCharID] = nil
    end)

    return true
end

--- Process an invite response from a player.
-- @param ply Player
-- @param accept boolean
function ix.usms.RespondToInvite(ply, accept)
    local char = ply:GetCharacter()
    if (!char) then return end

    local charID = char:GetID()
    local invite = ix.usms.pendingInvites[charID]
    if (!invite) then
        ply:Notify("No pending invite.")
        return
    end

    -- Check expiry
    if (os.time() - invite.timestamp > INVITE_EXPIRY) then
        ix.usms.pendingInvites[charID] = nil
        ply:Notify("Invite has expired.")
        return
    end

    -- Clean up
    ix.usms.pendingInvites[charID] = nil
    timer.Remove("ixUSMSInviteExpiry_" .. charID)

    if (!accept) then
        ply:Notify("Invite declined.")
        local inviterPly = ix.usms.GetPlayerByCharID(invite.inviterCharID)
        if (IsValid(inviterPly)) then
            inviterPly:Notify(char:GetName() .. " declined the invite.")
        end
        return
    end

    if (invite.type == "unit") then
        ix.usms.AddMember(charID, invite.unitID, USMS_ROLE_MEMBER, function(ok, err)
            ply:Notify(ok and ("Joined " .. invite.unitName .. "!") or ("Failed: " .. (err or "unknown")))
            if (ok) then
                local inviterPly = ix.usms.GetPlayerByCharID(invite.inviterCharID)
                if (IsValid(inviterPly)) then
                    inviterPly:Notify(char:GetName() .. " accepted the unit invite.")
                end
            end
        end)
    elseif (invite.type == "squad" and invite.squadID) then
        ix.usms.AddToSquad(charID, invite.squadID, function(ok, err)
            ply:Notify(ok and ("Joined squad " .. (invite.squadName or "") .. "!") or ("Failed: " .. (err or "unknown")))
            if (ok) then
                local inviterPly = ix.usms.GetPlayerByCharID(invite.inviterCharID)
                if (IsValid(inviterPly)) then
                    inviterPly:Notify(char:GetName() .. " accepted the squad invite.")
                end
            end
        end)
    end
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

    -- Check for a squad creation flag (temporary until rank system)
    if (ply:GetNetVar("ixUSMSCanCreateSquad", false)) then
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

-- ═══════════════════════════════════════════════════════════════════════════════
-- RESOURCE SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

--- Get a unit's current resources.
-- @param unitID number
-- @return number
function ix.usms.GetResources(unitID)
    local unit = ix.usms.units[unitID]
    return unit and unit.resources or 0
end

--- Set a unit's resources (clamped to 0..cap).
-- @param unitID number
-- @param amount number
-- @param reason string
-- @param actorCharID number|nil
-- @return bool
function ix.usms.SetResources(unitID, amount, reason, actorCharID)
    local unit = ix.usms.units[unitID]
    if (!unit) then return false end

    local oldAmount = unit.resources
    amount = math.Clamp(amount, 0, unit.resourceCap)
    unit.resources = amount

    ix.usms.db.Save()

    ix.usms.Log(unitID, USMS_LOG_UNIT_RESOURCE_CHANGE, actorCharID, nil, {
        oldAmount = oldAmount,
        newAmount = amount,
        delta = amount - oldAmount,
        reason = reason or "unknown"
    })

    ix.usms.SyncResourceToUnit(unitID)
    hook.Run("USMSResourcesChanged", unitID, oldAmount, amount, reason)

    return true
end

--- Add resources to a unit.
-- @param unitID number
-- @param amount number
-- @param reason string
-- @param actorCharID number|nil
-- @return bool
function ix.usms.AddResources(unitID, amount, reason, actorCharID)
    local current = ix.usms.GetResources(unitID)
    return ix.usms.SetResources(unitID, current + amount, reason, actorCharID)
end

--- Deduct resources from a unit. Returns false if insufficient.
-- @param unitID number
-- @param amount number
-- @param reason string
-- @param actorCharID number|nil
-- @return bool
function ix.usms.DeductResources(unitID, amount, reason, actorCharID)
    local current = ix.usms.GetResources(unitID)
    if (current < amount) then return false end
    return ix.usms.SetResources(unitID, current - amount, reason, actorCharID)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLASS / LOADOUT SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

--- Get the total resource cost for a class loadout.
-- @param classIndex number
-- @return number
function ix.usms.GetLoadoutCost(classIndex)
    local classInfo = ix.class.list[classIndex]
    if (!classInfo or !classInfo.loadout) then return 0 end

    local total = 0
    for _, item in ipairs(classInfo.loadout) do
        local qty = item.quantity or 1
        total = total + (item.cost * qty)
    end
    return total
end

--- Get loadout items for a class.
-- @param classIndex number
-- @return table
function ix.usms.GetClassLoadout(classIndex)
    local classInfo = ix.class.list[classIndex]
    if (!classInfo) then return {} end
    return classInfo.loadout or {}
end

--- Change a character's class.
-- @param charID number Character ID
-- @param classIndex number Target class index
-- @param authorizerCharID number|nil
-- @param callback function(success, error)
function ix.usms.ChangeClass(charID, classIndex, authorizerCharID, callback)
    local char = ix.usms.GetCharacterByID(charID)
    if (!char) then
        if (callback) then callback(false, "Character not found or offline") end
        return
    end

    local classInfo = ix.class.list[classIndex]
    if (!classInfo) then
        if (callback) then callback(false, "Invalid class") end
        return
    end

    if (classInfo.faction != char:GetFaction()) then
        if (callback) then callback(false, "Class belongs to a different faction") end
        return
    end

    if (char:GetClass() == classIndex) then
        if (callback) then callback(false, "Already this class") end
        return
    end

    -- Whitelist check for self-service class changes (no authorizer)
    local member = ix.usms.members[charID]
    if (!authorizerCharID and member and !classInfo.isDefault) then
        local whitelist = member.classWhitelist or {}
        if (!table.HasValue(whitelist, classInfo.uniqueID)) then
            if (callback) then callback(false, "You are not whitelisted for this class") end
            return
        end
    end

    local canChange, reason = hook.Run("USMSCanChangeClass", char, classIndex, authorizerCharID)
    if (canChange == false) then
        if (callback) then callback(false, reason or "Not authorized") end
        return
    end

    local oldClass = char:GetClass()
    char:SetClass(classIndex)

    if (member) then
        -- Update cached class info (persist uniqueID for stable restoration)
        member.cachedClass = classIndex
        member.cachedClassName = classInfo.name
        member.cachedClassUID = classInfo.uniqueID or ""

        -- Auto-whitelist when an officer assigns a class
        if (authorizerCharID and classInfo.uniqueID) then
            member.classWhitelist = member.classWhitelist or {}
            if (!table.HasValue(member.classWhitelist, classInfo.uniqueID)) then
                table.insert(member.classWhitelist, classInfo.uniqueID)
            end
        end

        ix.usms.Log(member.unitID, USMS_LOG_UNIT_CLASS_CHANGED, authorizerCharID, charID, {
            oldClass = oldClass,
            newClass = classIndex,
            className = classInfo.name
        })

        ix.usms.db.Save()
    end

    -- Sync roster update so class change is visible
    if (member) then
        ix.usms.SyncRosterUpdateToUnit(member.unitID, charID, "update")

        local ply = ix.usms.GetPlayerByCharID(charID)
        if (IsValid(ply)) then
            ix.usms.FullSyncToPlayer(ply)
        end
    end

    if (callback) then callback(true) end
    hook.Run("USMSClassChanged", charID, oldClass, classIndex, authorizerCharID)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- GEAR-UP API (ARMORY)
-- ═══════════════════════════════════════════════════════════════════════════════

--- Gear up a character with their class loadout.
-- @param ply Player
-- @param callback function(success, error, itemsGranted, cost)
function ix.usms.GearUp(ply, callback)
    local char = ply:GetCharacter()
    if (!char) then
        if (callback) then callback(false, "No character") end
        return
    end

    local classIndex = char:GetClass()
    if (!classIndex or classIndex == 0) then
        if (callback) then callback(false, "No class assigned") end
        return
    end

    local classInfo = ix.class.list[classIndex]
    if (!classInfo or !classInfo.loadout) then
        if (callback) then callback(false, "Class has no loadout defined") end
        return
    end

    local charID = char:GetID()
    local member = ix.usms.members[charID]
    if (!member) then
        if (callback) then callback(false, "Not in a unit") end
        return
    end

    local unitID = member.unitID
    local unit = ix.usms.units[unitID]

    local inventory = char:GetInventory()
    if (!inventory) then
        if (callback) then callback(false, "No inventory") end
        return
    end

    -- Determine which items need to be granted
    local neededItems = {}
    local totalCost = 0

    for _, loadoutEntry in ipairs(classInfo.loadout) do
        local qty = loadoutEntry.quantity or 1

        -- Count how many of this item the player already has
        local existing = 0
        for _, invItem in pairs(inventory:GetItems()) do
            if (invItem.uniqueID == loadoutEntry.uniqueID) then
                existing = existing + 1
            end
        end

        local needed = math.max(0, qty - existing)
        if (needed > 0) then
            table.insert(neededItems, {
                uniqueID = loadoutEntry.uniqueID,
                name = loadoutEntry.name,
                cost = loadoutEntry.cost,
                quantity = needed
            })
            totalCost = totalCost + (loadoutEntry.cost * needed)
        end
    end

    if (#neededItems == 0) then
        if (callback) then callback(false, "Already fully equipped") end
        return
    end

    -- Check unit resources
    if (unit.resources < totalCost) then
        if (callback) then callback(false, "Insufficient unit resources (" .. totalCost .. " needed, " .. unit.resources .. " available)") end
        return
    end

    -- Hook for additional checks
    local canGearUp, reason = hook.Run("USMSCanGearUp", ply, char, neededItems, totalCost)
    if (canGearUp == false) then
        if (callback) then callback(false, reason or "Gear-up denied") end
        return
    end

    -- Deduct resources
    ix.usms.DeductResources(unitID, totalCost, "gearup:" .. classInfo.name, charID)

    -- Grant items
    local granted = {}
    for _, item in ipairs(neededItems) do
        for i = 1, item.quantity do
            inventory:Add(item.uniqueID, 1, nil, nil, true)
            table.insert(granted, item.uniqueID)
        end
    end

    ix.usms.Log(unitID, USMS_LOG_GEARUP, charID, nil, {
        class = classInfo.name,
        items = granted,
        cost = totalCost
    })

    if (callback) then callback(true, nil, granted, totalCost) end
    hook.Run("USMSGearUp", ply, char, granted, totalCost)

    -- Sync updated inventory/resources to the player
    if (IsValid(ply)) then
        ix.usms.FullSyncToPlayer(ply)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- NETWORKING: SERVER -> CLIENT
-- ═══════════════════════════════════════════════════════════════════════════════

--- Send full unit data to a player.
-- @param ply Player
-- @param unitID number
function ix.usms.SyncUnitToPlayer(ply, unitID)
    local unit = ix.usms.units[unitID]
    if (!unit) then return end

    net.Start("ixUSMSUnitSync")
        net.WriteUInt(unit.id, 32)
        net.WriteString(unit.name)
        net.WriteString(unit.description or "")
        net.WriteUInt(unit.factionID, 8)
        net.WriteUInt(unit.resources, 32)
        net.WriteUInt(unit.resourceCap, 32)
        net.WriteUInt(unit.maxMembers, 16)
        net.WriteUInt(unit.maxSquads, 8)
    net.Send(ply)
end

--- Send unit data to all online members.
-- @param unitID number
function ix.usms.SyncUnitToAllMembers(unitID)
    local recipients = ix.usms.GetOnlineUnitMembers(unitID)
    for _, ply in ipairs(recipients) do
        ix.usms.SyncUnitToPlayer(ply, unitID)
    end
end

--- Send resource update to all online unit members.
-- @param unitID number
function ix.usms.SyncResourceToUnit(unitID)
    local unit = ix.usms.units[unitID]
    if (!unit) then return end

    local recipients = ix.usms.GetOnlineUnitMembers(unitID)
    if (#recipients == 0) then return end

    net.Start("ixUSMSUnitUpdate")
        net.WriteUInt(unitID, 32)
        net.WriteString("resources")
        net.WriteUInt(unit.resources, 32)
        net.WriteUInt(unit.resourceCap, 32)
    net.Send(recipients)
end

--- Build and send roster data for a unit to a player.
-- @param ply Player
-- @param unitID number
function ix.usms.SendRoster(ply, unitID)
    local unit = ix.usms.units[unitID]
    if (!unit) then return end

    local roster = {}

    for charID, member in pairs(ix.usms.members) do
        if (member.unitID != unitID) then continue end

        local entry = {
            charID = charID,
            role = member.role,
            joinedAt = member.joinedAt,
            squadID = 0,
            squadRole = 0,
            isOnline = false,
            name = "Unknown",
            class = 0,
            className = "Unassigned",
            lastSeen = member.joinedAt,
            classWhitelist = member.classWhitelist or {}
        }

        -- Check if online and enrich
        local memberPly = ix.usms.GetPlayerByCharID(charID)
        if (IsValid(memberPly)) then
            local char = memberPly:GetCharacter()
            if (char) then
                entry.isOnline = true
                entry.name = char:GetName()
                entry.class = char:GetClass() or 0

                local classInfo = ix.class.list[entry.class]
                entry.className = classInfo and classInfo.name or "Unassigned"
            end
        else
            entry.name = member.cachedName or "Unknown"
            entry.class = member.cachedClass or 0
            entry.className = member.cachedClassName or "Unassigned"
            entry.lastSeen = member.cachedLastSeen or member.joinedAt
        end

        -- Squad info
        local sm = ix.usms.squadMembers[charID]
        if (sm) then
            entry.squadID = sm.squadID
            entry.squadRole = sm.role

            local squad = ix.usms.squads[sm.squadID]
            entry.squadName = squad and squad.name or ""
            entry.squadDescription = squad and squad.description or ""
        end

        table.insert(roster, entry)
    end

    -- Send via net using compressed JSON
    local encoded = util.TableToJSON(roster)
    local compressed = util.Compress(encoded)

    if (!compressed) then return end

    net.Start("ixUSMSRosterSync")
        net.WriteUInt(unitID, 32)
        net.WriteUInt(#compressed, 32)
        net.WriteData(compressed, #compressed)
    net.Send(ply)
end

--- Send a single roster update to all unit members.
-- @param unitID number
-- @param charID number
-- @param action string "add"|"remove"|"update"
function ix.usms.SyncRosterUpdateToUnit(unitID, charID, action)
    local recipients = ix.usms.GetOnlineUnitMembers(unitID)
    if (#recipients == 0) then return end

    local data = {
        charID = charID,
        action = action
    }

    if (action != "remove") then
        local member = ix.usms.members[charID]
        if (member) then
            data.role = member.role
            data.name = member.cachedName or "Unknown"
            data.class = member.cachedClass or 0
            data.className = member.cachedClassName or "Unassigned"
            data.classWhitelist = member.classWhitelist or {}

            local sm = ix.usms.squadMembers[charID]
            data.squadID = sm and sm.squadID or 0
            data.squadRole = sm and sm.role or 0

            if (sm and ix.usms.squads[sm.squadID]) then
                data.squadName = ix.usms.squads[sm.squadID].name or ""
            end

            local memberPly = ix.usms.GetPlayerByCharID(charID)
            data.isOnline = IsValid(memberPly)
        end
    end

    local encoded = util.TableToJSON(data)

    net.Start("ixUSMSRosterUpdate")
        net.WriteUInt(unitID, 32)
        net.WriteString(encoded)
    net.Send(recipients)
end

--- Send squad sync to all squad member HUDs.
-- @param squadID number
function ix.usms.SyncSquadToHUD(squadID)
    local squad = ix.usms.squads[squadID]
    if (!squad) then return end

    -- Gather online squad members
    local members = {}
    for charID, sm in pairs(ix.usms.squadMembers) do
        if (sm.squadID == squadID) then
            local ply = ix.usms.GetPlayerByCharID(charID)
            if (IsValid(ply)) then
                table.insert(members, ply)
            end
        end
    end

    local hudSquadID = "usms_" .. squadID

    if (#members == 0) then
        if (ix.diegeticHUD and ix.diegeticHUD.squads and ix.diegeticHUD.squads[hudSquadID]) then
            ix.diegeticHUD.DisbandSquad(hudSquadID)
        end
        return
    end

    if (ix.diegeticHUD and ix.diegeticHUD.squads) then
        if (ix.diegeticHUD.squads[hudSquadID]) then
            local existingSquad = ix.diegeticHUD.squads[hudSquadID]
            existingSquad.members = members
            ix.diegeticHUD.SyncSquad(hudSquadID)
        else
            ix.diegeticHUD.CreateSquad(hudSquadID, squad.name, members)
        end
    end
end

--- Clear a USMS squad from the HUD.
-- @param squadID number
-- @param unitID number
function ix.usms.ClearSquadFromHUD(squadID, unitID)
    local hudSquadID = "usms_" .. squadID
    if (ix.diegeticHUD and ix.diegeticHUD.squads and ix.diegeticHUD.squads[hudSquadID]) then
        ix.diegeticHUD.DisbandSquad(hudSquadID)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- NETWORKING: CLIENT -> SERVER REQUESTS
-- ═══════════════════════════════════════════════════════════════════════════════

ix.usms.requestHandlers = {}

net.Receive("ixUSMSRequest", function(len, ply)
    local action = net.ReadString()
    local data = net.ReadTable()

    -- Rate limiting
    if (CurTime() < (ply.ixUSMSRequestCooldown or 0)) then return end
    ply.ixUSMSRequestCooldown = CurTime() + 0.5

    local char = ply:GetCharacter()
    if (!char) then return end

    local handler = ix.usms.requestHandlers[action]
    if (handler) then
        handler(ply, char, data)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- REQUEST HANDLERS
-- ═══════════════════════════════════════════════════════════════════════════════

ix.usms.requestHandlers["squad_create"] = function(ply, char, data)
    local name = tostring(data.name or ""):sub(1, 64)
    if (name == "") then return end

    ix.usms.CreateSquad(ply, name, function(ok, result)
        ply:Notify(ok and ("Squad created: " .. name) or ("Failed: " .. tostring(result)))
    end)
end

ix.usms.requestHandlers["squad_invite"] = function(ply, char, data)
    local targetCharID = tonumber(data.charID)
    if (!targetCharID) then return end

    local sm = ix.usms.squadMembers[char:GetID()]
    if (!ply:IsSuperAdmin() and (!sm or sm.role < USMS_SQUAD_INVITER)) then
        ply:Notify("You don't have permission to invite.")
        return
    end

    -- Check target is in the same unit
    local targetMember = ix.usms.members[targetCharID]
    if (!targetMember) then
        ply:Notify("Target is not in a unit.")
        return
    end

    local squad = ix.usms.squads[sm.squadID]
    if (!squad) then
        ply:Notify("Squad not found.")
        return
    end

    if (targetMember.unitID != squad.unitID) then
        ply:Notify("Target is not in the same unit.")
        return
    end

    local ok, err = ix.usms.SendInvite(targetCharID, "squad", char:GetID(), squad.unitID, sm.squadID)
    ply:Notify(ok and "Squad invite sent." or ("Failed: " .. (err or "unknown")))
end

ix.usms.requestHandlers["squad_kick"] = function(ply, char, data)
    local targetCharID = tonumber(data.charID)
    if (!targetCharID) then return end

    local sm = ix.usms.squadMembers[char:GetID()]
    if (!ply:IsSuperAdmin() and (!sm or sm.role < USMS_SQUAD_XO)) then
        ply:Notify("Only squad XO or leader can kick.")
        return
    end

    -- Can't kick someone of equal or higher squad role
    local targetSM = ix.usms.squadMembers[targetCharID]
    if (!ply:IsSuperAdmin() and targetSM and targetSM.role >= sm.role) then
        ply:Notify("Cannot kick someone of equal or higher squad rank.")
        return
    end

    if (targetCharID == char:GetID()) then return end -- Can't kick self

    ix.usms.RemoveFromSquad(targetCharID, char:GetID(), function(ok, err)
        ply:Notify(ok and "Kicked from squad." or ("Failed: " .. (err or "unknown")))
    end)
end

ix.usms.requestHandlers["squad_leave"] = function(ply, char, data)
    ix.usms.RemoveFromSquad(char:GetID(), nil, function(ok, err)
        ply:Notify(ok and "Left squad." or ("Failed: " .. (err or "unknown")))
    end)
end

ix.usms.requestHandlers["squad_disband"] = function(ply, char, data)
    local sm = ix.usms.squadMembers[char:GetID()]
    if (!ply:IsSuperAdmin() and (!sm or sm.role != USMS_SQUAD_LEADER)) then
        ply:Notify("Only the squad leader can disband.")
        return
    end

    ix.usms.DisbandSquad(sm.squadID, char:GetID(), function(ok, err)
        ply:Notify(ok and "Squad disbanded." or ("Failed: " .. (err or "unknown")))
    end)
end

ix.usms.requestHandlers["squad_force_disband"] = function(ply, char, data)
    local squadID = tonumber(data.squadID)
    if (!squadID) then return end

    -- Only unit officers or superadmins can force disband
    local member = ix.usms.members[char:GetID()]
    if (!ply:IsSuperAdmin() and (!member or member.role < USMS_ROLE_XO)) then
        ply:Notify("Only CO/XO can force disband a squad.")
        return
    end

    -- Verify the squad belongs to the same unit
    local squad = ix.usms.squads[squadID]
    if (!squad) then
        ply:Notify("Squad not found.")
        return
    end

    if (!ply:IsSuperAdmin() and member and member.unitID != squad.unitID) then
        ply:Notify("Squad is not in your unit.")
        return
    end

    ix.usms.DisbandSquad(squadID, char:GetID(), function(ok, err)
        ply:Notify(ok and "Squad force disbanded." or ("Failed: " .. (err or "unknown")))
    end)
end

ix.usms.requestHandlers["squad_set_role"] = function(ply, char, data)
    local targetCharID = tonumber(data.charID)
    local newRole = tonumber(data.role)
    if (!targetCharID or !newRole) then return end

    -- Validate role range (can't assign leader via this — use transfer)
    if (newRole < USMS_SQUAD_MEMBER or newRole > USMS_SQUAD_XO) then
        ply:Notify("Invalid squad role.")
        return
    end

    -- Squad leader, unit officers, or superadmins can set squad roles
    local sm = ix.usms.squadMembers[char:GetID()]
    local member = ix.usms.members[char:GetID()]
    local isSquadLeader = sm and sm.role == USMS_SQUAD_LEADER

    local targetSM = ix.usms.squadMembers[targetCharID]
    if (!targetSM) then
        ply:Notify("Target is not in a squad.")
        return
    end

    -- Determine the squad we're operating on
    local squadID = targetSM.squadID
    local squad = ix.usms.squads[squadID]
    if (!squad) then
        ply:Notify("Squad not found.")
        return
    end

    local isUnitOfficer = member and member.unitID == squad.unitID and member.role >= USMS_ROLE_XO

    if (!ply:IsSuperAdmin() and !isSquadLeader and !isUnitOfficer) then
        ply:Notify("You don't have permission to assign squad roles.")
        return
    end

    -- Squad leaders can only modify members in their own squad
    if (isSquadLeader and !isUnitOfficer and !ply:IsSuperAdmin() and sm.squadID != squadID) then
        ply:Notify("Target is not in your squad.")
        return
    end

    if (targetCharID == char:GetID()) then return end

    targetSM.role = newRole
    local targetChar = ix.usms.GetCharacterByID(targetCharID)
    if (targetChar) then
        targetChar:SetUsmSquadRole(newRole)
    end

    ix.usms.db.Save()
    ix.usms.SyncSquadToHUD(squadID)
    ix.usms.FullSyncToUnit(squad.unitID)
    ply:Notify("Squad role updated.")
end

ix.usms.requestHandlers["squad_set_description"] = function(ply, char, data)
    local squadID = tonumber(data.squadID)
    local description = tostring(data.description or ""):sub(1, 256)
    if (!squadID) then return end

    local squad = ix.usms.squads[squadID]
    if (!squad) then
        ply:Notify("Squad not found.")
        return
    end

    -- Squad leader, unit officers, or superadmins can set description
    local sm = ix.usms.squadMembers[char:GetID()]
    local member = ix.usms.members[char:GetID()]
    local isSquadLeader = sm and sm.squadID == squadID and sm.role == USMS_SQUAD_LEADER
    local isUnitOfficer = member and member.unitID == squad.unitID and member.role >= USMS_ROLE_XO

    if (!ply:IsSuperAdmin() and !isSquadLeader and !isUnitOfficer) then
        ply:Notify("You don't have permission to set the squad description.")
        return
    end

    squad.description = description
    ix.usms.db.Save()
    ix.usms.FullSyncToUnit(squad.unitID)
    ply:Notify("Squad description updated.")
end

ix.usms.requestHandlers["squad_force_remove"] = function(ply, char, data)
    local targetCharID = tonumber(data.charID)
    if (!targetCharID) then return end

    -- Only unit officers or superadmins
    local member = ix.usms.members[char:GetID()]
    if (!ply:IsSuperAdmin() and (!member or member.role < USMS_ROLE_XO)) then
        ply:Notify("Only CO/XO can force remove from squads.")
        return
    end

    local targetSM = ix.usms.squadMembers[targetCharID]
    if (!targetSM) then
        ply:Notify("Target is not in a squad.")
        return
    end

    -- Verify same unit (unless superadmin)
    local targetMember = ix.usms.members[targetCharID]
    if (!ply:IsSuperAdmin() and targetMember and member and targetMember.unitID != member.unitID) then
        ply:Notify("Target is not in your unit.")
        return
    end

    ix.usms.RemoveFromSquad(targetCharID, char:GetID(), function(ok, err)
        ply:Notify(ok and "Removed from squad." or ("Failed: " .. (err or "unknown")))
    end)
end

ix.usms.requestHandlers["squad_force_add"] = function(ply, char, data)
    local targetCharID = tonumber(data.charID)
    local squadID = tonumber(data.squadID)
    if (!targetCharID or !squadID) then return end

    -- Only unit officers or superadmins
    local member = ix.usms.members[char:GetID()]
    if (!ply:IsSuperAdmin() and (!member or member.role < USMS_ROLE_XO)) then
        ply:Notify("Only CO/XO can force add to squads.")
        return
    end

    local squad = ix.usms.squads[squadID]
    if (!squad) then
        ply:Notify("Squad not found.")
        return
    end

    -- Verify same unit
    if (!ply:IsSuperAdmin() and member and member.unitID != squad.unitID) then
        ply:Notify("Squad is not in your unit.")
        return
    end

    -- Check target is in the same unit and not already in a squad
    local targetMember = ix.usms.members[targetCharID]
    if (!targetMember) then
        ply:Notify("Target is not in a unit.")
        return
    end

    if (targetMember.unitID != squad.unitID) then
        ply:Notify("Target is not in the same unit as the squad.")
        return
    end

    if (ix.usms.squadMembers[targetCharID]) then
        ply:Notify("Target is already in a squad.")
        return
    end

    -- Check squad size
    local memberCount = 0
    for _, sm in pairs(ix.usms.squadMembers) do
        if (sm.squadID == squadID) then memberCount = memberCount + 1 end
    end

    local maxSize = ix.config.Get("usmsSquadMaxSize", USMS_SQUAD_MAX_SIZE)
    if (memberCount >= maxSize) then
        ply:Notify("Squad is full.")
        return
    end

    -- Add to squad
    local now = os.time()
    ix.usms.squadMembers[targetCharID] = {
        squadID = squadID,
        characterID = targetCharID,
        role = USMS_SQUAD_MEMBER,
        joinedAt = now
    }

    local targetChar = ix.usms.GetCharacterByID(targetCharID)
    if (targetChar) then
        targetChar:SetUsmSquadID(squadID)
        targetChar:SetUsmSquadRole(USMS_SQUAD_MEMBER)
    end

    ix.usms.db.Save()
    ix.usms.Log(squad.unitID, USMS_LOG_SQUAD_MEMBER_JOIN, targetCharID, char:GetID(), {squadID = squadID, forced = true})
    ix.usms.SyncSquadToHUD(squadID)
    ix.usms.FullSyncToUnit(squad.unitID)
    ply:Notify("Added to squad.")
end

ix.usms.requestHandlers["unit_invite"] = function(ply, char, data)
    local member = ix.usms.members[char:GetID()]
    if (!ply:IsSuperAdmin() and (!member or member.role < USMS_ROLE_XO)) then
        ply:Notify("Only CO/XO can invite members.")
        return
    end

    local targetCharID = tonumber(data.charID)
    if (!targetCharID) then return end

    local ok, err = ix.usms.SendInvite(targetCharID, "unit", char:GetID(), member.unitID)
    ply:Notify(ok and "Unit invite sent." or ("Failed: " .. (err or "unknown")))
end

ix.usms.requestHandlers["unit_kick"] = function(ply, char, data)
    local member = ix.usms.members[char:GetID()]
    if (!ply:IsSuperAdmin() and (!member or member.role < USMS_ROLE_XO)) then
        ply:Notify("Only CO/XO can remove members.")
        return
    end

    local targetCharID = tonumber(data.charID)
    if (!targetCharID) then return end
    if (targetCharID == char:GetID()) then return end

    -- XO can't kick CO (superadmins bypass this)
    local targetMember = ix.usms.members[targetCharID]
    if (!ply:IsSuperAdmin() and targetMember and targetMember.role >= member.role) then
        ply:Notify("Cannot remove someone of equal or higher rank.")
        return
    end

    ix.usms.RemoveMember(targetCharID, char:GetID(), function(ok, err)
        ply:Notify(ok and "Member removed." or ("Failed: " .. (err or "unknown")))
    end)
end

ix.usms.requestHandlers["unit_set_role"] = function(ply, char, data)
    local member = ix.usms.members[char:GetID()]
    if (!ply:IsSuperAdmin() and (!member or member.role < USMS_ROLE_CO)) then
        ply:Notify("Only the CO can change roles.")
        return
    end

    local targetCharID = tonumber(data.charID)
    local newRole = tonumber(data.role)
    if (!targetCharID or !newRole) then return end

    -- CO can assign XO or Member. Only superadmins can directly assign CO.
    if (newRole >= USMS_ROLE_CO and !ply:IsSuperAdmin()) then
        ply:Notify("Only superadmins can directly assign the CO role.")
        return
    end

    ix.usms.SetMemberRole(targetCharID, newRole, function(ok, err)
        ply:Notify(ok and "Role updated." or ("Failed: " .. (err or "unknown")))
    end)
end

ix.usms.requestHandlers["unit_set_class"] = function(ply, char, data)
    local member = ix.usms.members[char:GetID()]
    if (!ply:IsSuperAdmin() and (!member or member.role < USMS_ROLE_XO)) then
        ply:Notify("Only CO/XO can assign classes.")
        return
    end

    local targetCharID = tonumber(data.charID)
    local classIndex = tonumber(data.classIndex)
    if (!targetCharID or !classIndex) then return end

    ix.usms.ChangeClass(targetCharID, classIndex, char:GetID(), function(ok, err)
        ply:Notify(ok and "Class changed." or ("Failed: " .. (err or "unknown")))
    end)
end

ix.usms.requestHandlers["gearup"] = function(ply, char, data)
    ix.usms.GearUp(ply, function(ok, err, items, cost)
        if (ok) then
            ply:Notify("Geared up! Cost: " .. cost .. " resources.")
        else
            ply:Notify("Gear-up failed: " .. (err or "unknown"))
        end
    end)
end

ix.usms.requestHandlers["class_change"] = function(ply, char, data)
    local classIndex = tonumber(data.classIndex)
    if (!classIndex) then return end

    ix.usms.ChangeClass(char:GetID(), classIndex, nil, function(ok, err)
        ply:Notify(ok and "Class changed." or ("Failed: " .. (err or "unknown")))
    end)
end

ix.usms.requestHandlers["roster_request"] = function(ply, char, data)
    local member = ix.usms.members[char:GetID()]
    if (!member and !ply:IsSuperAdmin()) then return end

    -- Superadmins can optionally specify a unitID to view any roster
    local unitID = member and member.unitID
    if (ply:IsSuperAdmin() and tonumber(data.unitID)) then
        unitID = tonumber(data.unitID)
    end

    if (unitID) then
        ix.usms.SendRoster(ply, unitID)
    end
end

ix.usms.requestHandlers["intel_roster_request"] = function(ply, char, data)
    local targetUnitID = tonumber(data.unitID)
    if (!targetUnitID) then return end

    -- Superadmins bypass view check
    if (!ply:IsSuperAdmin()) then
        local canView, reason = hook.Run("USMSCanViewIntel", ply, char, targetUnitID)
        if (!canView) then return end
    end

    ix.usms.SendRoster(ply, targetUnitID)

    local unit = ix.usms.units[targetUnitID]
    if (unit) then
        net.Start("ixUSMSIntelSync")
            net.WriteUInt(targetUnitID, 32)
            net.WriteString(unit.name)
            net.WriteUInt(unit.resources, 32)
            net.WriteUInt(unit.resourceCap, 32)
            net.WriteUInt(ix.usms.GetUnitMemberCount(targetUnitID), 16)
        net.Send(ply)
    end
end

ix.usms.requestHandlers["log_request"] = function(ply, char, data)
    local member = ix.usms.members[char:GetID()]
    if (!member) then return end

    -- CO/XO can view logs, or admin/superadmin
    if (member.role < USMS_ROLE_XO and !ply:IsSuperAdmin() and !ply:IsAdmin()) then
        return
    end

    local page = math.max(1, tonumber(data.page) or 1)
    local limit = math.Clamp(tonumber(data.limit) or 100, 1, 500)
    local offset = (page - 1) * limit

    local options = {
        limit = limit,
        offset = offset,
        action = data.action,
        startTime = tonumber(data.startTime),
        endTime = tonumber(data.endTime)
    }

    ix.usms.GetLogs(member.unitID, options, function(logs, totalCount)
        local payload = {
            logs = logs,
            totalCount = totalCount or #logs
        }
        local encoded = util.TableToJSON(payload)
        local compressed = util.Compress(encoded)
        if (!compressed) then return end

        net.Start("ixUSMSLogSync")
            net.WriteUInt(member.unitID, 32)
            net.WriteUInt(#compressed, 32)
            net.WriteData(compressed, #compressed)
        net.Send(ply)
    end)
end

ix.usms.requestHandlers["invite_respond"] = function(ply, char, data)
    local accept = data.accept and true or false
    ix.usms.RespondToInvite(ply, accept)
end

ix.usms.requestHandlers["squad_transfer_leader"] = function(ply, char, data)
    local targetCharID = tonumber(data.charID)
    if (!targetCharID) then return end
    if (targetCharID == char:GetID()) then return end

    local sm = ix.usms.squadMembers[char:GetID()]
    local member = ix.usms.members[char:GetID()]
    local isSquadLeader = sm and sm.role == USMS_SQUAD_LEADER
    local isUnitOfficer = member and member.role >= USMS_ROLE_XO

    if (!ply:IsSuperAdmin() and !isSquadLeader and !isUnitOfficer) then
        ply:Notify("Only the squad leader or unit officers can transfer leadership.")
        return
    end

    local targetSM = ix.usms.squadMembers[targetCharID]
    if (!targetSM) then
        ply:Notify("Target is not in a squad.")
        return
    end

    local squadID = targetSM.squadID

    -- Squad leader can only transfer within their own squad
    if (isSquadLeader and !isUnitOfficer and !ply:IsSuperAdmin() and sm.squadID != squadID) then
        ply:Notify("Target is not in your squad.")
        return
    end

    ix.usms.SetSquadLeader(squadID, targetCharID)

    local squad = ix.usms.squads[squadID]
    if (squad) then
        ix.usms.FullSyncToUnit(squad.unitID)
    end

    ply:Notify("Squad leadership transferred.")
end

ix.usms.requestHandlers["unit_edit"] = function(ply, char, data)
    local member = ix.usms.members[char:GetID()]
    if (!ply:IsSuperAdmin() and (!member or member.role < USMS_ROLE_XO)) then
        ply:Notify("Only CO/XO can edit unit details.")
        return
    end

    local unitID = member and member.unitID
    if (ply:IsSuperAdmin() and tonumber(data.unitID)) then
        unitID = tonumber(data.unitID)
    end

    local unit = ix.usms.units[unitID]
    if (!unit) then
        ply:Notify("Unit not found.")
        return
    end

    local changed = false

    if (data.name and data.name != "") then
        local name = tostring(data.name):sub(1, 64)
        unit.name = name
        changed = true
    end

    if (data.description != nil) then
        unit.description = tostring(data.description):sub(1, 512)
        changed = true
    end

    -- Only CO or superadmin can change caps
    if (ply:IsSuperAdmin() or (member and member.role >= USMS_ROLE_CO)) then
        if (tonumber(data.resourceCap)) then
            unit.resourceCap = math.max(0, tonumber(data.resourceCap))
            changed = true
        end

        if (tonumber(data.maxMembers)) then
            unit.maxMembers = math.Clamp(tonumber(data.maxMembers), 1, 200)
            changed = true
        end

        if (tonumber(data.maxSquads)) then
            unit.maxSquads = math.Clamp(tonumber(data.maxSquads), 1, 50)
            changed = true
        end
    end

    if (changed) then
        ix.usms.db.Save()
        ix.usms.SyncUnitToAllMembers(unitID)
        ply:Notify("Unit updated.")
    end
end

ix.usms.requestHandlers["co_transfer"] = function(ply, char, data)
    local member = ix.usms.members[char:GetID()]
    if (!ply:IsSuperAdmin() and (!member or member.role < USMS_ROLE_CO)) then
        ply:Notify("Only the CO can transfer command.")
        return
    end

    local targetCharID = tonumber(data.charID)
    if (!targetCharID or targetCharID == char:GetID()) then return end

    local unitID = member and member.unitID
    if (!unitID) then return end

    ix.usms.TransferCO(unitID, targetCharID, function(ok, err)
        if (ok) then
            ix.usms.FullSyncToUnit(unitID)
            ply:Notify("Command transferred.")
        else
            ply:Notify("Failed: " .. (err or "unknown"))
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLASS WHITELIST REQUEST HANDLERS
-- ═══════════════════════════════════════════════════════════════════════════════

ix.usms.requestHandlers["class_whitelist_add"] = function(ply, char, data)
    local member = ix.usms.members[char:GetID()]
    if (!ply:IsSuperAdmin() and (!member or member.role < USMS_ROLE_XO)) then
        ply:Notify("Only CO/XO can manage class whitelists.")
        return
    end

    local targetCharID = tonumber(data.charID)
    local classUID = tostring(data.classUID or "")
    if (!targetCharID or classUID == "") then return end

    local targetMember = ix.usms.members[targetCharID]
    if (!targetMember) then
        ply:Notify("Target is not in a unit.")
        return
    end

    -- Must be in the same unit (unless superadmin)
    if (!ply:IsSuperAdmin() and member and targetMember.unitID != member.unitID) then
        ply:Notify("Target is not in your unit.")
        return
    end

    -- Validate the class UID exists and matches the target's faction
    local targetChar = ix.usms.GetCharacterByID(targetCharID)
    local factionID = targetChar and targetChar:GetFaction() or (ix.usms.units[targetMember.unitID] or {}).factionID
    local classIndex = ix.usms.GetClassIndexByUID(classUID, factionID)
    if (!classIndex) then
        ply:Notify("Invalid class.")
        return
    end

    targetMember.classWhitelist = targetMember.classWhitelist or {}
    if (table.HasValue(targetMember.classWhitelist, classUID)) then
        ply:Notify("Already whitelisted for this class.")
        return
    end

    table.insert(targetMember.classWhitelist, classUID)

    ix.usms.Log(targetMember.unitID, USMS_LOG_CLASS_WHITELIST, char:GetID(), targetCharID, {
        classUID = classUID,
        className = (ix.class.list[classIndex] or {}).name or classUID,
        action = "add"
    })

    ix.usms.db.Save()
    ix.usms.SyncRosterUpdateToUnit(targetMember.unitID, targetCharID, "update")

    local targetPly = ix.usms.GetPlayerByCharID(targetCharID)
    if (IsValid(targetPly)) then
        ix.usms.FullSyncToPlayer(targetPly)
    end

    local className = (ix.class.list[classIndex] or {}).name or classUID
    ply:Notify("Whitelisted " .. (targetMember.cachedName or "member") .. " for " .. className .. ".")
end

ix.usms.requestHandlers["class_whitelist_remove"] = function(ply, char, data)
    local member = ix.usms.members[char:GetID()]
    if (!ply:IsSuperAdmin() and (!member or member.role < USMS_ROLE_XO)) then
        ply:Notify("Only CO/XO can manage class whitelists.")
        return
    end

    local targetCharID = tonumber(data.charID)
    local classUID = tostring(data.classUID or "")
    if (!targetCharID or classUID == "") then return end

    local targetMember = ix.usms.members[targetCharID]
    if (!targetMember) then
        ply:Notify("Target is not in a unit.")
        return
    end

    if (!ply:IsSuperAdmin() and member and targetMember.unitID != member.unitID) then
        ply:Notify("Target is not in your unit.")
        return
    end

    targetMember.classWhitelist = targetMember.classWhitelist or {}
    local removed = false
    for i = #targetMember.classWhitelist, 1, -1 do
        if (targetMember.classWhitelist[i] == classUID) then
            table.remove(targetMember.classWhitelist, i)
            removed = true
            break
        end
    end

    if (!removed) then
        ply:Notify("Not whitelisted for this class.")
        return
    end

    local classIndex = ix.usms.GetClassIndexByUID(classUID)
    ix.usms.Log(targetMember.unitID, USMS_LOG_CLASS_WHITELIST, char:GetID(), targetCharID, {
        classUID = classUID,
        className = classIndex and (ix.class.list[classIndex] or {}).name or classUID,
        action = "remove"
    })

    ix.usms.db.Save()
    ix.usms.SyncRosterUpdateToUnit(targetMember.unitID, targetCharID, "update")

    local targetPly = ix.usms.GetPlayerByCharID(targetCharID)
    if (IsValid(targetPly)) then
        ix.usms.FullSyncToPlayer(targetPly)
    end

    local className = classIndex and (ix.class.list[classIndex] or {}).name or classUID
    ply:Notify("Removed " .. (targetMember.cachedName or "member") .. " from " .. className .. " whitelist.")
end

-- Listen for invite responses via dedicated net message too (for popup button clicks)
net.Receive("ixUSMSInviteResponse", function(len, ply)
    local accept = net.ReadBool()

    if (CurTime() < (ply.ixUSMSInviteResponseCooldown or 0)) then return end
    ply.ixUSMSInviteResponseCooldown = CurTime() + 1

    ix.usms.RespondToInvite(ply, accept)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- CROSS-FACTION INTELLIGENCE HOOK
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("USMSCanViewIntel", "ixUSMSDefaultIntel", function(ply, char, targetUnitID)
    -- Superadmins always bypass
    if (ply:IsSuperAdmin()) then return true end

    local targetUnit = ix.usms.units[targetUnitID]
    if (!targetUnit) then return false, "Unit not found" end

    -- Same faction: always can view own faction's units
    if (char:GetFaction() == targetUnit.factionID) then
        return true
    end

    -- Cross-faction: check faction config
    local faction = ix.faction.indices[char:GetFaction()]
    if (faction and faction.canViewAllRosters) then
        return true
    end

    return false, "Unauthorized"
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- MISSION SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

--- Create a new mission.
-- @param unitID number
-- @param createdBy number charID of creator
-- @param data table {title, description, priority, assignedTo={type, id}}
-- @param callback function(success, error|missionID)
function ix.usms.CreateMission(unitID, createdBy, data, callback)
    local unit = ix.usms.units[unitID]
    if (!unit) then
        if (callback) then callback(false, "Unit not found") end
        return
    end

    local title = tostring(data.title or ""):sub(1, 128)
    if (title == "") then
        if (callback) then callback(false, "Title is required") end
        return
    end

    local missionID = ix.usms.db.AllocMissionID()
    local now = os.time()

    local assignedTo = data.assignedTo or {type = "unit", id = unitID}
    local priority = math.Clamp(tonumber(data.priority) or USMS_MISSION_PRIORITY_NORMAL, 1, 3)

    ix.usms.missions[missionID] = {
        id = missionID,
        unitID = unitID,
        createdBy = createdBy,
        assignedTo = assignedTo,
        title = title,
        description = tostring(data.description or ""):sub(1, 512),
        priority = priority,
        status = USMS_MISSION_ACTIVE,
        createdAt = now,
        completedAt = nil
    }

    ix.usms.db.Save()

    ix.usms.Log(unitID, USMS_LOG_MISSION_CREATED, createdBy, nil, {
        missionID = missionID,
        title = title,
        priority = priority
    })

    -- Sync missions to all unit members
    ix.usms.SyncMissionsToUnit(unitID)

    -- Diegetic HUD: critical priority → set priority order unit-wide
    if (priority == USMS_MISSION_PRIORITY_CRITICAL and ix.diegeticHUD and ix.diegeticHUD.SetPriorityOrder) then
        local recipients = ix.usms.GetOnlineUnitMembers(unitID)
        for _, ply in ipairs(recipients) do
            ix.diegeticHUD.SetPriorityOrder(ply, title)
        end
    end

    if (callback) then callback(true, missionID) end
    hook.Run("USMSMissionCreated", missionID, unitID, createdBy)
end

--- Complete a mission.
-- @param missionID number
-- @param completedBy number charID
-- @param callback function(success, error)
function ix.usms.CompleteMission(missionID, completedBy, callback)
    local mission = ix.usms.missions[missionID]
    if (!mission) then
        if (callback) then callback(false, "Mission not found") end
        return
    end

    if (mission.status != USMS_MISSION_ACTIVE) then
        if (callback) then callback(false, "Mission is not active") end
        return
    end

    mission.status = USMS_MISSION_COMPLETE
    mission.completedAt = os.time()

    ix.usms.db.Save()

    ix.usms.Log(mission.unitID, USMS_LOG_MISSION_COMPLETED, completedBy, nil, {
        missionID = missionID,
        title = mission.title
    })

    ix.usms.SyncMissionsToUnit(mission.unitID)

    if (callback) then callback(true) end
    hook.Run("USMSMissionCompleted", missionID, mission.unitID, completedBy)
end

--- Cancel a mission.
-- @param missionID number
-- @param cancelledBy number charID
-- @param callback function(success, error)
function ix.usms.CancelMission(missionID, cancelledBy, callback)
    local mission = ix.usms.missions[missionID]
    if (!mission) then
        if (callback) then callback(false, "Mission not found") end
        return
    end

    if (mission.status != USMS_MISSION_ACTIVE) then
        if (callback) then callback(false, "Mission is not active") end
        return
    end

    mission.status = USMS_MISSION_CANCELLED
    mission.completedAt = os.time()

    ix.usms.db.Save()

    ix.usms.Log(mission.unitID, USMS_LOG_MISSION_CANCELLED, cancelledBy, nil, {
        missionID = missionID,
        title = mission.title
    })

    ix.usms.SyncMissionsToUnit(mission.unitID)

    if (callback) then callback(true) end
    hook.Run("USMSMissionCancelled", missionID, mission.unitID, cancelledBy)
end

--- Get active missions for a unit.
-- @param unitID number
-- @return table array of mission data
function ix.usms.GetActiveMissions(unitID)
    local result = {}
    for _, mission in pairs(ix.usms.missions) do
        if (mission.unitID == unitID and mission.status == USMS_MISSION_ACTIVE) then
            table.insert(result, mission)
        end
    end
    table.sort(result, function(a, b) return (a.priority or 2) > (b.priority or 2) end)
    return result
end

--- Get all missions for a unit (including completed/cancelled).
-- @param unitID number
-- @param includeInactive boolean
-- @return table array of mission data
function ix.usms.GetUnitMissions(unitID, includeInactive)
    local result = {}
    for _, mission in pairs(ix.usms.missions) do
        if (mission.unitID == unitID) then
            if (includeInactive or mission.status == USMS_MISSION_ACTIVE) then
                table.insert(result, mission)
            end
        end
    end
    table.sort(result, function(a, b)
        if (a.status == USMS_MISSION_ACTIVE and b.status != USMS_MISSION_ACTIVE) then return true end
        if (a.status != USMS_MISSION_ACTIVE and b.status == USMS_MISSION_ACTIVE) then return false end
        return (a.createdAt or 0) > (b.createdAt or 0)
    end)
    return result
end

--- Send all missions for a unit to a player.
-- @param ply Player
-- @param unitID number
function ix.usms.SyncMissionsToPlayer(ply, unitID)
    local missions = ix.usms.GetUnitMissions(unitID, true)

    -- Resolve creator names
    for _, mission in ipairs(missions) do
        local creatorChar = ix.usms.GetCharacterByID(mission.createdBy)
        mission.createdByName = creatorChar and creatorChar:GetName() or (ix.usms.members[mission.createdBy] and ix.usms.members[mission.createdBy].cachedName or "Unknown")
    end

    local encoded = util.TableToJSON(missions)
    local compressed = util.Compress(encoded)
    if (!compressed) then return end

    net.Start("ixUSMSMissionSync")
        net.WriteUInt(unitID, 32)
        net.WriteUInt(#compressed, 32)
        net.WriteData(compressed, #compressed)
    net.Send(ply)
end

--- Sync missions to all online unit members.
-- @param unitID number
function ix.usms.SyncMissionsToUnit(unitID)
    local recipients = ix.usms.GetOnlineUnitMembers(unitID)
    for _, ply in ipairs(recipients) do
        ix.usms.SyncMissionsToPlayer(ply, unitID)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- COMMENDATION / SERVICE RECORD SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

--- Award a commendation to a character.
-- @param unitID number
-- @param recipientCharID number
-- @param awardedBy number charID of awarding officer
-- @param data table {type, title, reason}
-- @param callback function(success, error|commendationID)
function ix.usms.AwardCommendation(unitID, recipientCharID, awardedBy, data, callback)
    local unit = ix.usms.units[unitID]
    if (!unit) then
        if (callback) then callback(false, "Unit not found") end
        return
    end

    local member = ix.usms.members[recipientCharID]
    if (!member or member.unitID != unitID) then
        if (callback) then callback(false, "Recipient is not in this unit") end
        return
    end

    local commType = data.type or USMS_COMMENDATION_COMMENDATION
    if (commType != USMS_COMMENDATION_MEDAL and commType != USMS_COMMENDATION_COMMENDATION and commType != USMS_COMMENDATION_REPRIMAND) then
        if (callback) then callback(false, "Invalid commendation type") end
        return
    end

    local title = tostring(data.title or ""):sub(1, 128)
    if (title == "") then
        if (callback) then callback(false, "Title is required") end
        return
    end

    local commID = ix.usms.db.AllocCommendationID()
    local now = os.time()

    ix.usms.commendations[commID] = {
        id = commID,
        unitID = unitID,
        recipientCharID = recipientCharID,
        awardedBy = awardedBy,
        type = commType,
        title = title,
        reason = tostring(data.reason or ""):sub(1, 512),
        timestamp = now,
        revoked = false
    }

    ix.usms.db.Save()

    ix.usms.Log(unitID, USMS_LOG_COMMENDATION_AWARDED, awardedBy, recipientCharID, {
        commendationID = commID,
        commType = commType,
        title = title
    })

    if (callback) then callback(true, commID) end
    hook.Run("USMSCommendationAwarded", commID, unitID, recipientCharID, awardedBy)
end

--- Revoke a commendation.
-- @param commID number
-- @param revokedBy number charID
-- @param callback function(success, error)
function ix.usms.RevokeCommendation(commID, revokedBy, callback)
    local comm = ix.usms.commendations[commID]
    if (!comm) then
        if (callback) then callback(false, "Commendation not found") end
        return
    end

    if (comm.revoked) then
        if (callback) then callback(false, "Already revoked") end
        return
    end

    comm.revoked = true

    ix.usms.db.Save()

    ix.usms.Log(comm.unitID, USMS_LOG_COMMENDATION_REVOKED, revokedBy, comm.recipientCharID, {
        commendationID = commID,
        title = comm.title
    })

    if (callback) then callback(true) end
    hook.Run("USMSCommendationRevoked", commID, comm.unitID, revokedBy)
end

--- Get the service record for a character.
-- @param charID number
-- @return table {commendations, member, promotionHistory}
function ix.usms.GetServiceRecord(charID)
    local member = ix.usms.members[charID]
    if (!member) then return nil end

    -- Gather commendations
    local commendations = {}
    for _, comm in pairs(ix.usms.commendations) do
        if (comm.recipientCharID == charID and !comm.revoked) then
            local awarderName = "Unknown"
            local awarderChar = ix.usms.GetCharacterByID(comm.awardedBy)
            if (awarderChar) then
                awarderName = awarderChar:GetName()
            elseif (ix.usms.members[comm.awardedBy]) then
                awarderName = ix.usms.members[comm.awardedBy].cachedName or "Unknown"
            end

            table.insert(commendations, {
                id = comm.id,
                type = comm.type,
                title = comm.title,
                reason = comm.reason,
                timestamp = comm.timestamp,
                awardedByName = awarderName
            })
        end
    end
    table.sort(commendations, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)

    -- Gather promotion history from logs
    local promotions = {}
    for _, entry in ipairs(ix.usms.logs or {}) do
        if (entry.action == USMS_LOG_UNIT_ROLE_CHANGED and entry.targetCharID == charID and entry.unitID == member.unitID) then
            table.insert(promotions, {
                timestamp = entry.timestamp,
                oldRole = entry.data and entry.data.oldRole,
                newRole = entry.data and entry.data.newRole,
                actorName = entry.data and entry.data.actorName or "System"
            })
        end
    end
    table.sort(promotions, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)

    return {
        charID = charID,
        name = member.cachedName or "Unknown",
        role = member.role,
        joinedAt = member.joinedAt,
        className = member.cachedClassName or "Unassigned",
        commendations = commendations,
        promotions = promotions
    }
end

--- Send a service record to a player.
-- @param ply Player
-- @param targetCharID number
function ix.usms.SendServiceRecord(ply, targetCharID)
    local record = ix.usms.GetServiceRecord(targetCharID)
    if (!record) then return end

    local encoded = util.TableToJSON(record)
    local compressed = util.Compress(encoded)
    if (!compressed) then return end

    net.Start("ixUSMSServiceRecord")
        net.WriteUInt(#compressed, 32)
        net.WriteData(compressed, #compressed)
    net.Send(ply)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MISSION REQUEST HANDLERS
-- ═══════════════════════════════════════════════════════════════════════════════

ix.usms.requestHandlers["mission_create"] = function(ply, char, data)
    local member = ix.usms.members[char:GetID()]
    if (!member) then return end

    -- CO/XO or squad leaders can create missions
    local isOfficer = member.role >= USMS_ROLE_XO
    local sm = ix.usms.squadMembers[char:GetID()]
    local isSquadLeader = sm and sm.role == USMS_SQUAD_LEADER

    if (!ply:IsSuperAdmin() and !isOfficer and !isSquadLeader) then
        ply:Notify("Only officers or squad leaders can create missions.")
        return
    end

    -- Squad leaders can only assign to their own squad
    local assignedTo = data.assignedTo
    if (isSquadLeader and !isOfficer and !ply:IsSuperAdmin()) then
        assignedTo = {type = "squad", id = sm.squadID}
    end

    ix.usms.CreateMission(member.unitID, char:GetID(), {
        title = data.title,
        description = data.description,
        priority = data.priority,
        assignedTo = assignedTo
    }, function(ok, result)
        ply:Notify(ok and ("Mission created: " .. tostring(data.title)) or ("Failed: " .. tostring(result)))
    end)
end

ix.usms.requestHandlers["mission_complete"] = function(ply, char, data)
    local missionID = tonumber(data.missionID)
    if (!missionID) then return end

    local mission = ix.usms.missions[missionID]
    if (!mission) then
        ply:Notify("Mission not found.")
        return
    end

    local member = ix.usms.members[char:GetID()]
    if (!member or member.unitID != mission.unitID) then
        ply:Notify("Not in the same unit as this mission.")
        return
    end

    -- CO/XO can complete any mission, squad leaders can complete their squad's missions
    local isOfficer = member.role >= USMS_ROLE_XO
    local sm = ix.usms.squadMembers[char:GetID()]
    local isAssignedSL = sm and sm.role == USMS_SQUAD_LEADER and mission.assignedTo and mission.assignedTo.type == "squad" and mission.assignedTo.id == sm.squadID

    if (!ply:IsSuperAdmin() and !isOfficer and !isAssignedSL) then
        ply:Notify("You don't have permission to complete this mission.")
        return
    end

    ix.usms.CompleteMission(missionID, char:GetID(), function(ok, err)
        ply:Notify(ok and "Mission completed." or ("Failed: " .. (err or "unknown")))
    end)
end

ix.usms.requestHandlers["mission_cancel"] = function(ply, char, data)
    local missionID = tonumber(data.missionID)
    if (!missionID) then return end

    local mission = ix.usms.missions[missionID]
    if (!mission) then
        ply:Notify("Mission not found.")
        return
    end

    local member = ix.usms.members[char:GetID()]
    if (!member or member.unitID != mission.unitID) then
        ply:Notify("Not in the same unit as this mission.")
        return
    end

    -- Only the creator, CO/XO, or superadmin can cancel
    local isOfficer = member.role >= USMS_ROLE_XO
    local isCreator = mission.createdBy == char:GetID()

    if (!ply:IsSuperAdmin() and !isOfficer and !isCreator) then
        ply:Notify("You don't have permission to cancel this mission.")
        return
    end

    ix.usms.CancelMission(missionID, char:GetID(), function(ok, err)
        ply:Notify(ok and "Mission cancelled." or ("Failed: " .. (err or "unknown")))
    end)
end

ix.usms.requestHandlers["mission_request"] = function(ply, char, data)
    local member = ix.usms.members[char:GetID()]
    if (!member and !ply:IsSuperAdmin()) then return end

    local unitID = member and member.unitID
    if (unitID) then
        ix.usms.SyncMissionsToPlayer(ply, unitID)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- COMMENDATION REQUEST HANDLERS
-- ═══════════════════════════════════════════════════════════════════════════════

ix.usms.requestHandlers["commendation_award"] = function(ply, char, data)
    local member = ix.usms.members[char:GetID()]
    if (!ply:IsSuperAdmin() and (!member or member.role < USMS_ROLE_XO)) then
        ply:Notify("Only officers can award commendations.")
        return
    end

    local targetCharID = tonumber(data.charID)
    if (!targetCharID) then return end

    local unitID = member and member.unitID
    if (!unitID) then return end

    ix.usms.AwardCommendation(unitID, targetCharID, char:GetID(), {
        type = data.commType,
        title = data.title,
        reason = data.reason
    }, function(ok, result)
        ply:Notify(ok and "Commendation awarded." or ("Failed: " .. tostring(result)))
    end)
end

ix.usms.requestHandlers["commendation_revoke"] = function(ply, char, data)
    local member = ix.usms.members[char:GetID()]
    if (!ply:IsSuperAdmin() and (!member or member.role < USMS_ROLE_XO)) then
        ply:Notify("Only officers can revoke commendations.")
        return
    end

    local commID = tonumber(data.commendationID)
    if (!commID) then return end

    -- Verify same unit
    local comm = ix.usms.commendations[commID]
    if (!comm) then
        ply:Notify("Commendation not found.")
        return
    end
    if (!ply:IsSuperAdmin() and member and comm.unitID != member.unitID) then
        ply:Notify("Commendation is not from your unit.")
        return
    end

    ix.usms.RevokeCommendation(commID, char:GetID(), function(ok, err)
        ply:Notify(ok and "Commendation revoked." or ("Failed: " .. (err or "unknown")))
    end)
end

ix.usms.requestHandlers["service_record_request"] = function(ply, char, data)
    local targetCharID = tonumber(data.charID)
    if (!targetCharID) then return end

    local member = ix.usms.members[char:GetID()]
    local targetMember = ix.usms.members[targetCharID]

    -- Must be in the same unit, or superadmin
    if (!ply:IsSuperAdmin() and (!member or !targetMember or member.unitID != targetMember.unitID)) then
        return
    end

    ix.usms.SendServiceRecord(ply, targetCharID)
end
