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

    -- Schema validation (DoS protection)
    if (type(data) != "table") then data = {} end
    local keyCount = 0
    for k, v in pairs(data) do
        keyCount = keyCount + 1
        if (keyCount > 20) then
            data[k] = nil
        elseif (type(v) == "string" and string.len(v) > 1024) then
            data[k] = string.sub(v, 1, 1024)
        elseif (type(v) == "table") then
            data[k] = nil -- flat data only
        end
    end

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
    local member = ix.usms.members[char:GetID()]
    -- FIX: unit officers (XO/CO) may invite even when not personally in a squad
    local isUnitOfficer = member and member.role >= USMS_ROLE_XO
    if (!ply:IsSuperAdmin() and !isUnitOfficer and (!sm or sm.role < USMS_SQUAD_INVITER)) then
        ply:Notify("You don't have permission to invite.")
        return
    end

    -- Determine target squad: officers may specify data.squadID; squad members use their own squad
    local squadID
    if (sm) then
        squadID = sm.squadID
    else
        squadID = tonumber(data.squadID)
    end
    if (!squadID) then
        ply:Notify("No squad specified.")
        return
    end

    local squad = ix.usms.squads[squadID]
    if (!squad) then
        ply:Notify("Squad not found.")
        return
    end

    -- Officers may only invite to squads in their own unit
    if (!ply:IsSuperAdmin() and member and member.unitID != squad.unitID) then
        ply:Notify("Squad is not in your unit.")
        return
    end

    -- Check target is in the same unit
    local targetMember = ix.usms.members[targetCharID]
    if (!targetMember) then
        ply:Notify("Target is not in a unit.")
        return
    end

    if (targetMember.unitID != squad.unitID) then
        ply:Notify("Target is not in the same unit.")
        return
    end

    local ok, err = ix.usms.SendInvite(targetCharID, "squad", char:GetID(), squad.unitID, squadID)
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
    ix.usms.Log(squad.unitID, USMS_LOG_SQUAD_MEMBER_JOIN, char:GetID(), targetCharID, {squadID = squadID, forced = true})
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
        ix.usms.SendSquads(ply, unitID)
    end
end

-- FIX: intel_roster_request handler removed (intel system cut by design)

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

