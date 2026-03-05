local PLUGIN = PLUGIN

PLUGIN.name = "Unit & Squad Management"
PLUGIN.author = "Vanir"
PLUGIN.description = "Persistent military unit and squad organization system with loadouts and resources."

-- ═══════════════════════════════════════════════════════════════════════════════
-- CONSTANTS (defined in libs/sh_usms.lua for load-order safety)
-- ═══════════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════════

ix.config.Add("usmsSquadMaxSize", USMS_SQUAD_MAX_SIZE, "Maximum squad size.", nil, {
    data = {min = 2, max = 12},
    category = "USMS"
})

ix.config.Add("usmsSquadMinSize", USMS_SQUAD_MIN_SIZE, "Minimum squad size before auto-disband.", nil, {
    data = {min = 1, max = 4},
    category = "USMS"
})

ix.config.Add("usmsLogRetentionDays", 60, "Days to retain USMS logs before pruning.", nil, {
    data = {min = 7, max = 365},
    category = "USMS"
})

ix.config.Add("usmsHUDSyncInterval", 3, "Seconds between HUD squad sync updates.", nil, {
    data = {min = 1, max = 10},
    category = "USMS"
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- LIB INCLUDES (order matters: shared first, then realm-specific)
-- ═══════════════════════════════════════════════════════════════════════════════

ix.util.Include("libs/sh_usms.lua")
ix.util.Include("libs/sh_catalogs.lua")
ix.util.Include("libs/sv_database.lua")
ix.util.Include("libs/sv_logging.lua")
ix.util.Include("libs/sv_usms.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
ix.util.Include("meta/sh_character.lua")

-- Commands
ix.util.Include("commands/sh_admin.lua")
ix.util.Include("commands/sh_testing.lua")
