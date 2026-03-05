--- USMS Logging System
-- Dual-purpose: admin oversight + in-RP intelligence.
-- Logs are stored in the plugin data file alongside other USMS data.

ix.usms.logs = ix.usms.logs or {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- HELIX LOG TYPES
-- ═══════════════════════════════════════════════════════════════════════════════

ix.log.AddType("usmsUnitMemberJoin", function(client, ...)
    local args = {...}
    return string.format("[USMS] %s joined unit %s", tostring(args[2] or "Unknown"), tostring(args[1] or "Unknown"))
end)

ix.log.AddType("usmsUnitMemberLeave", function(client, ...)
    local args = {...}
    return string.format("[USMS] %s left unit %s", tostring(args[2] or "Unknown"), tostring(args[1] or "Unknown"))
end)

ix.log.AddType("usmsGearUp", function(client, ...)
    local args = {...}
    return string.format("[USMS] %s geared up from %s (cost: %s)", tostring(args[2] or "Unknown"), tostring(args[1] or "Unknown"), tostring(args[3] or 0))
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- LOGGING API
-- ═══════════════════════════════════════════════════════════════════════════════

--- Add a USMS log entry (writes to data file + fires Helix ix.log).
-- @param unitID number
-- @param action string USMS_LOG_* constant
-- @param actorCharID number|nil
-- @param targetCharID number|nil
-- @param data table|nil Additional context
function ix.usms.Log(unitID, action, actorCharID, targetCharID, data)
    data = data or {}

    -- Resolve actor/target names and store in data for client display
    if (actorCharID) then
        local char = ix.usms.GetCharacterByID(actorCharID)
        data.actorName = char and char:GetName() or ("CharID:" .. actorCharID)
        data.actorCharID = actorCharID
    end

    if (targetCharID) then
        local char = ix.usms.GetCharacterByID(targetCharID)
        data.targetName = char and char:GetName() or ("CharID:" .. targetCharID)
        data.targetCharID = targetCharID
    end

    -- Write to in-memory log (saved to file periodically)
    table.insert(ix.usms.logs, {
        unitID = unitID,
        action = action,
        actorCharID = actorCharID,
        targetCharID = targetCharID,
        data = data,
        timestamp = os.time()
    })

    -- Fire through Helix's logging system for admin visibility
    local actorName = data.actorName or "System"
    local targetName = data.targetName or ""

    local unit = ix.usms.units[unitID]
    local unitName = unit and unit.name or ("UnitID:" .. unitID)

    local logStr = string.format("[USMS] %s | %s | Actor: %s | Target: %s", unitName, action, actorName, targetName)
    ix.log.AddRaw(logStr)
end

--- Fetch logs for a unit from the in-memory log store.
-- @param unitID number
-- @param options table {limit, offset, action, startTime, endTime}
-- @param callback function(logs)
function ix.usms.GetLogs(unitID, options, callback)
    options = options or {}

    local filtered = {}
    for _, entry in ipairs(ix.usms.logs) do
        if (entry.unitID != unitID) then continue end

        if (options.action and entry.action != options.action) then continue end
        if (options.startTime and entry.timestamp < options.startTime) then continue end
        if (options.endTime and entry.timestamp > options.endTime) then continue end

        table.insert(filtered, entry)
    end

    -- Sort descending by timestamp
    table.sort(filtered, function(a, b) return a.timestamp > b.timestamp end)

    -- Apply offset
    local offset = options.offset or 0
    local limit = options.limit or 100
    local result = {}

    for i = offset + 1, math.min(offset + limit, #filtered) do
        table.insert(result, filtered[i])
    end

    if (callback) then
        callback(result, #filtered)
    end

    return result, #filtered
end
