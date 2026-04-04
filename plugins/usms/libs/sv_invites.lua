
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
