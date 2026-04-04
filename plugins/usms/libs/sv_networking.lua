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
-- FIX: ixUSMSSquadUpdate removed (declared but never sent)
util.AddNetworkString("ixUSMSLogSync")
-- FIX: ixUSMSIntelSync, ixUSMSMissionSync, ixUSMSMissionUpdate, ixUSMSServiceRecord removed (systems cut by design)
util.AddNetworkString("ixUSMSRequest")
util.AddNetworkString("ixUSMSInvite")
util.AddNetworkString("ixUSMSInviteResponse")

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
    ix.usms.SendSquads(ply, member.unitID)
    ix.usms.SendRoster(ply, member.unitID)
end

ix.usms._dirtyUnits = ix.usms._dirtyUnits or {}

timer.Create("ixUSMSDirtyFlush", 0.15, 0, function()
    for unitID in pairs(ix.usms._dirtyUnits) do
        local recipients = ix.usms.GetOnlineUnitMembers(unitID)
        for _, ply in ipairs(recipients) do
            ix.usms.FullSyncToPlayer(ply)
        end
    end
    ix.usms._dirtyUnits = {}
end)

--- Sync all online unit members (full unit + roster refresh). Scheduled and throttled.
-- @param unitID number
function ix.usms.FullSyncToUnit(unitID)
    if (!unitID) then return end
    ix.usms._dirtyUnits[unitID] = true
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

--- Build and send squad metadata for a unit to a player.
function ix.usms.SendSquads(ply, unitID)
    local unit = ix.usms.units[unitID]
    if (!unit) then return end

    local mappedSquads = {}
    for sqID, squad in pairs(ix.usms.squads) do
        if (squad.unitID == unitID) then
            mappedSquads[sqID] = {
                id = squad.id,
                name = squad.name,
                description = squad.description
            }
        end
    end

    local encoded = util.TableToJSON(mappedSquads)
    local compressed = util.Compress(encoded)
    if (!compressed) then return end

    net.Start("ixUSMSSquadSync")
        net.WriteUInt(unitID, 32)
        net.WriteUInt(#compressed, 32)
        net.WriteData(compressed, #compressed)
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
            lastSeen = member.joinedAt
        }
        
        -- Privacy check: Only send whitelist to the member themselves or officers
        local targetChar = ply:GetCharacter()
        if (targetChar and (targetChar:GetID() == charID or ix.usms.HasPermission(ply, targetChar, USMS_ROLE_XO))) then
            entry.classWhitelist = member.classWhitelist or {}
        end

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
            -- Name and description are synced independently via SendSquads
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

    local baseData = {
        charID = charID,
        action = action
    }

    if (action != "remove") then
        local member = ix.usms.members[charID]
        if (member) then
            baseData.role = member.role
            baseData.name = member.cachedName or "Unknown"
            baseData.class = member.cachedClass or 0
            baseData.className = member.cachedClassName or "Unassigned"

            local sm = ix.usms.squadMembers[charID]
            baseData.squadID = sm and sm.squadID or 0
            baseData.squadRole = sm and sm.role or 0

            if (sm and ix.usms.squads[sm.squadID]) then
                baseData.squadName = ix.usms.squads[sm.squadID].name or ""
            end

            local memberPly = ix.usms.GetPlayerByCharID(charID)
            baseData.isOnline = IsValid(memberPly)
        end
    end

    -- FIX: Apply per-recipient privacy filter for classWhitelist (same rule as SendRoster)
    local member = ix.usms.members[charID]
    local whitelist = member and (member.classWhitelist or {}) or {}

    for _, ply in ipairs(recipients) do
        local data = table.Copy(baseData)

        -- Include classWhitelist only for the target member or unit officers
        local recipChar = ply:GetCharacter()
        if (action != "remove" and recipChar) then
            if (recipChar:GetID() == charID or ix.usms.HasPermission(ply, recipChar, USMS_ROLE_XO)) then
                data.classWhitelist = whitelist
            end
        end

        local encoded = util.TableToJSON(data)
        net.Start("ixUSMSRosterUpdate")
            net.WriteUInt(unitID, 32)
            net.WriteString(encoded)
        net.Send(ply)
    end
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

