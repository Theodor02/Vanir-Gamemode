--- USMS Client-Side State & Net Receivers
-- Maintains the client-side cache that derma panels read from.

ix.usms.clientData = ix.usms.clientData or {
    unit = nil,
    roster = {},
    squads = {},
    logs = {},
    intelUnits = {}
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- NET RECEIVERS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Full unit data sync.
net.Receive("ixUSMSUnitSync", function()
    local unitID = net.ReadUInt(32)
    ix.usms.clientData.unit = {
        id = unitID,
        name = net.ReadString(),
        description = net.ReadString(),
        factionID = net.ReadUInt(8),
        resources = net.ReadUInt(32),
        resourceCap = net.ReadUInt(32),
        maxMembers = net.ReadUInt(16),
        maxSquads = net.ReadUInt(8)
    }

    hook.Run("USMSUnitDataUpdated", ix.usms.clientData.unit)
end)

--- Partial unit update (resources, etc.).
net.Receive("ixUSMSUnitUpdate", function()
    local unitID = net.ReadUInt(32)
    local field = net.ReadString()

    if (field == "resources") then
        local resources = net.ReadUInt(32)
        local cap = net.ReadUInt(32)

        if (ix.usms.clientData.unit and ix.usms.clientData.unit.id == unitID) then
            ix.usms.clientData.unit.resources = resources
            ix.usms.clientData.unit.resourceCap = cap
        end

        hook.Run("USMSResourcesUpdated", unitID, resources, cap)
    end
end)

--- Full roster sync.
net.Receive("ixUSMSRosterSync", function()
    local unitID = net.ReadUInt(32)
    local dataLen = net.ReadUInt(32)
    local compressed = net.ReadData(dataLen)

    local decompressed = util.Decompress(compressed)
    if (!decompressed) then return end

    local roster = util.JSONToTable(decompressed)
    if (!istable(roster)) then return end

    if (ix.usms.clientData.unit and ix.usms.clientData.unit.id == unitID) then
        ix.usms.clientData.roster = roster
    end

    -- Also extract squads from roster data
    local squads = {}
    for _, entry in ipairs(roster) do
        if (entry.squadID and entry.squadID > 0) then
            if (!squads[entry.squadID]) then
                squads[entry.squadID] = {
                    name = entry.squadName or "",
                    description = entry.squadDescription or "",
                    members = {}
                }
            end
            table.insert(squads[entry.squadID].members, entry)
        end
    end
    ix.usms.clientData.squads = squads

    hook.Run("USMSRosterUpdated", unitID, roster)
end)

--- Single roster entry update.
net.Receive("ixUSMSRosterUpdate", function()
    local unitID = net.ReadUInt(32)
    local encoded = net.ReadString()
    local data = util.JSONToTable(encoded)
    if (!istable(data)) then return end

    if (ix.usms.clientData.unit and ix.usms.clientData.unit.id == unitID) then
        local roster = ix.usms.clientData.roster

        if (data.action == "remove") then
            for i = #roster, 1, -1 do
                if (roster[i].charID == data.charID) then
                    table.remove(roster, i)
                    break
                end
            end
        elseif (data.action == "add") then
            table.insert(roster, data)
        elseif (data.action == "update") then
            for i, entry in ipairs(roster) do
                if (entry.charID == data.charID) then
                    for k, v in pairs(data) do
                        if (k != "action") then
                            entry[k] = v
                        end
                    end
                    break
                end
            end
        end
    end

    hook.Run("USMSRosterEntryUpdated", unitID, data)
end)

--- Log sync.
net.Receive("ixUSMSLogSync", function()
    local unitID = net.ReadUInt(32)
    local dataLen = net.ReadUInt(32)
    local compressed = net.ReadData(dataLen)

    local decompressed = util.Decompress(compressed)
    if (!decompressed) then return end

    local payload = util.JSONToTable(decompressed)
    if (!istable(payload)) then return end

    -- Support both new {logs, totalCount} format and legacy flat array
    if (payload.logs) then
        ix.usms.clientData.logs = payload.logs
        ix.usms.clientData.logTotalCount = payload.totalCount or #payload.logs
    else
        ix.usms.clientData.logs = payload
        ix.usms.clientData.logTotalCount = #payload
    end

    hook.Run("USMSLogsUpdated", unitID, ix.usms.clientData.logs)
end)

--- Intel sync (cross-faction unit data).
net.Receive("ixUSMSIntelSync", function()
    local unitID = net.ReadUInt(32)
    local name = net.ReadString()
    local resources = net.ReadUInt(32)
    local cap = net.ReadUInt(32)
    local memberCount = net.ReadUInt(16)

    ix.usms.clientData.intelUnits[unitID] = {
        id = unitID,
        name = name,
        resources = resources,
        resourceCap = cap,
        memberCount = memberCount
    }

    hook.Run("USMSIntelUpdated", unitID)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLIENT-SIDE HELPER: Send Request to Server
-- ═══════════════════════════════════════════════════════════════════════════════

--- Send a USMS request to the server.
-- @param action string The action identifier
-- @param data table Action-specific payload
function ix.usms.Request(action, data)
    net.Start("ixUSMSRequest")
        net.WriteString(action)
        net.WriteTable(data or {})
    net.SendToServer()
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- INVITE SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

--- Receive an invite from the server and display a popup.
net.Receive("ixUSMSInvite", function()
    local inviteType = net.ReadString()
    local unitName = net.ReadString()
    local inviterName = net.ReadString()
    local squadName = net.ReadString()

    -- Build the popup
    local message
    if (inviteType == "squad") then
        message = inviterName .. " has invited you to squad \"" .. squadName .. "\" in " .. unitName .. "."
    else
        message = inviterName .. " has invited you to join unit \"" .. unitName .. "\"."
    end

    -- Create invite popup
    if (IsValid(ix.usms.invitePopup)) then
        ix.usms.invitePopup:Remove()
    end

    ix.usms.invitePopup = vgui.Create("ixUSMSInvitePopup")
    ix.usms.invitePopup:SetInviteData(inviteType, message, inviterName)
end)

--- Send invite response to server.
-- @param accept boolean
function ix.usms.RespondToInvite(accept)
    net.Start("ixUSMSInviteResponse")
        net.WriteBool(accept)
    net.SendToServer()
end
