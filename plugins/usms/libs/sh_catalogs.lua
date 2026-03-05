--- USMS Equipment Catalog System
-- Shared definitions for equipment available through the armory/gear-up system.

ix.usms.catalogs = ix.usms.catalogs or {}
ix.usms.catalogs.global = {}
ix.usms.catalogs.faction = {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- CATALOG API
-- ═══════════════════════════════════════════════════════════════════════════════

--- Register a global catalog item (available to all factions).
-- @param uniqueID string Helix item uniqueID
-- @param data table {name, cost, category}
function ix.usms.RegisterGlobalItem(uniqueID, data)
    ix.usms.catalogs.global[uniqueID] = {
        uniqueID = uniqueID,
        name = data.name or uniqueID,
        cost = data.cost or 0,
        category = data.category or "General"
    }
end

--- Register a faction-specific catalog item.
-- @param factionID number Helix faction index
-- @param uniqueID string Helix item uniqueID
-- @param data table {name, cost, category}
function ix.usms.RegisterFactionItem(factionID, uniqueID, data)
    if (!ix.usms.catalogs.faction[factionID]) then
        ix.usms.catalogs.faction[factionID] = {}
    end

    ix.usms.catalogs.faction[factionID][uniqueID] = {
        uniqueID = uniqueID,
        name = data.name or uniqueID,
        cost = data.cost or 0,
        category = data.category or "Specialized"
    }
end

--- Get all catalog items available to a faction (global + faction-specific).
-- @param factionID number
-- @return table [uniqueID] = itemData
function ix.usms.GetAvailableCatalog(factionID)
    local catalog = table.Copy(ix.usms.catalogs.global)

    if (ix.usms.catalogs.faction[factionID]) then
        table.Merge(catalog, ix.usms.catalogs.faction[factionID])
    end

    return catalog
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- GLOBAL CATALOG ITEMS
-- ═══════════════════════════════════════════════════════════════════════════════

ix.usms.RegisterGlobalItem("arccw_k_e11", {
    name = "E-11 Blaster Rifle",
    cost = 10,
    category = "Primary Weapons"
})

ix.usms.RegisterGlobalItem("cylinder1", {
    name = "Light Armor Kit",
    cost = 5,
    category = "Armor"
})

ix.usms.RegisterGlobalItem("thermal_det", {
    name = "Thermal Detonator",
    cost = 4,
    category = "Ordnance"
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- FACTION CATALOGS
-- ═══════════════════════════════════════════════════════════════════════════════
-- These reference FACTION_* globals which are set in schema/factions/
-- Uncomment and adjust when faction globals are available:

-- ix.usms.RegisterFactionItem(FACTION_ARMY, "army_heavy_blaster", {
--     name = "T-21 Heavy Repeater",
--     cost = 25,
--     category = "Heavy Weapons"
-- })
