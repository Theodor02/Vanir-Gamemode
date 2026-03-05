--- USMS Persistence Layer
-- Uses PLUGIN:SetData/GetData (Helix file-based persistence) instead of MySQL tables.
-- All data is stored in a single file: data/helix/<schema>/<pluginID>.txt
-- Data is auto-saved every 10 minutes and on server shutdown via SaveData hook.

ix.usms.db = ix.usms.db or {}

--- Load all USMS data from the plugin data file.
-- Called during plugin initialization.
function ix.usms.db.Load()
    local plugin = ix.plugin.list["usms"]
    if (!plugin) then return end

    local data = plugin:GetData(nil, false, true) -- ignoreMap=true (cross-map persistence)

    if (!istable(data)) then
        -- First boot, no data yet
        ix.usms.units = {}
        ix.usms.squads = {}
        ix.usms.members = {}
        ix.usms.squadMembers = {}
        ix.usms.nextUnitID = 1
        ix.usms.nextSquadID = 1
        return
    end

    -- Restore cache tables with numeric key coercion
    ix.usms.units = {}
    if (istable(data.units)) then
        for k, v in pairs(data.units) do
            ix.usms.units[tonumber(k) or k] = v
        end
    end

    ix.usms.squads = {}
    if (istable(data.squads)) then
        for k, v in pairs(data.squads) do
            ix.usms.squads[tonumber(k) or k] = v
        end
    end

    ix.usms.members = {}
    if (istable(data.members)) then
        for k, v in pairs(data.members) do
            ix.usms.members[tonumber(k) or k] = v
        end
    end

    ix.usms.squadMembers = {}
    if (istable(data.squadMembers)) then
        for k, v in pairs(data.squadMembers) do
            ix.usms.squadMembers[tonumber(k) or k] = v
        end
    end

    ix.usms.nextUnitID = tonumber(data.nextUnitID) or 1
    ix.usms.nextSquadID = tonumber(data.nextSquadID) or 1

    -- Prune old logs on load
    ix.usms.db.PruneLogs()

    print("[USMS] Loaded " .. table.Count(ix.usms.units) .. " units, "
        .. table.Count(ix.usms.members) .. " members, "
        .. table.Count(ix.usms.squads) .. " squads, "
        .. table.Count(ix.usms.squadMembers) .. " squad members.")
end

--- Save all USMS data to the plugin data file.
-- Called from SaveData hook and on shutdown.
function ix.usms.db.Save()
    local plugin = ix.plugin.list["usms"]
    if (!plugin) then return end

    local data = {
        units = ix.usms.units or {},
        squads = ix.usms.squads or {},
        members = ix.usms.members or {},
        squadMembers = ix.usms.squadMembers or {},
        logs = ix.usms.logs or {},
        nextUnitID = ix.usms.nextUnitID or 1,
        nextSquadID = ix.usms.nextSquadID or 1
    }

    plugin:SetData(data, false, true) -- ignoreMap=true
end

--- Allocate a new unique unit ID.
-- @return number The new ID
function ix.usms.db.AllocUnitID()
    local id = ix.usms.nextUnitID
    ix.usms.nextUnitID = id + 1
    return id
end

--- Allocate a new unique squad ID.
-- @return number The new ID
function ix.usms.db.AllocSquadID()
    local id = ix.usms.nextSquadID
    ix.usms.nextSquadID = id + 1
    return id
end

--- Prune old log entries. Runs on data load.
-- @param maxAgeDays number Days to retain (default: config value)
function ix.usms.db.PruneLogs(maxAgeDays)
    maxAgeDays = maxAgeDays or ix.config.Get("usmsLogRetentionDays", 60)
    local cutoff = os.time() - (maxAgeDays * 86400)

    ix.usms.logs = ix.usms.logs or {}

    local pruned = 0
    local kept = {}
    for _, entry in ipairs(ix.usms.logs) do
        if (entry.timestamp and entry.timestamp >= cutoff) then
            table.insert(kept, entry)
        else
            pruned = pruned + 1
        end
    end

    ix.usms.logs = kept

    if (pruned > 0) then
        print("[USMS] Pruned " .. pruned .. " log entries older than " .. maxAgeDays .. " days.")
    end
end
