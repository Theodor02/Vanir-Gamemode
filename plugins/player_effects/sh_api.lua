--- Player Effects Registry – Public Registration API
-- Provides functions for plugins to register custom effect types
-- and define mutual exclusion rules between effect identifiers.
--
-- Usage:
--   ix.playerEffects.RegisterEffectType("my_custom.stat", {
--       name         = "Custom Stat",
--       baseValue    = 1,
--       min          = 0,
--       max          = 10,
--       calcOrder    = "mult_first",       -- "mult_first" (default) or "add_first"
--       modTypes     = {ix.playerEffects.MOD_MULT, ix.playerEffects.MOD_ADD},
--       apply        = function(ply, value) end,   -- SERVER: called when value changes
--       unapply      = function(ply) end,           -- SERVER: called when all modifiers removed
--       calculate    = nil,                          -- optional custom calculation override
--   })
--
--   ix.playerEffects.SetExclusive("poisoned", "cured", "priority")
-- @module ix.playerEffects (API)

local PE = ix.playerEffects

--- Register a new effect type with the player effects system.
-- @param id string Unique effect type key (e.g., "speed.run", "damage.taken", "my_plugin.stat")
-- @param data table Definition table with fields:
--   name        (string)   Human-readable name
--   baseValue   (any)      Starting value before modifiers (default 0)
--   min         (number?)  Optional minimum clamp
--   max         (number?)  Optional maximum clamp
--   calcOrder   (string?)  "mult_first" (SET→MULT→ADD, default) or "add_first" (SET→ADD→MULT)
--   modTypes    (table?)   Allowed modifier types {MOD_MULT, MOD_ADD, MOD_SET}
--   apply       (func?)    function(ply, value) called server-side when the calculated value changes
--   unapply     (func?)    function(ply) called server-side when every modifier is removed
--   calculate   (func?)    function(modifiers, baseValue, typeDef) custom calculation override
function ix.playerEffects.RegisterEffectType(id, data)
    data.id = id
    data.name = data.name or id
    if data.baseValue == nil then data.baseValue = 0 end
    data.modTypes = data.modTypes or {PE.MOD_MULT, PE.MOD_ADD}
    data.calcOrder = data.calcOrder or "mult_first"

    PE.types[id] = data
end

--- Declare two effect identifiers as mutually exclusive.
-- When a player already has a modifier with identifierA and a new modifier
-- with identifierB is added (or vice-versa), the conflict is resolved
-- according to the chosen resolution strategy.
-- @param identifierA string First modifier identifier
-- @param identifierB string Second modifier identifier
-- @param resolution string? Resolution strategy: "priority" (default), "first", or "last"
--   "priority" – higher opts.priority wins; ties keep the existing effect
--   "first"    – the already-applied effect always stays
--   "last"     – the newly-applied effect always wins
function ix.playerEffects.SetExclusive(identifierA, identifierB, resolution)
    resolution = resolution or "priority"

    PE.exclusions[identifierA] = PE.exclusions[identifierA] or {}
    PE.exclusions[identifierA][identifierB] = resolution

    PE.exclusions[identifierB] = PE.exclusions[identifierB] or {}
    PE.exclusions[identifierB][identifierA] = resolution
end

--- Check whether two identifiers are mutually exclusive.
-- @param idA string
-- @param idB string
-- @return bool, string? isExclusive, resolution
function ix.playerEffects.AreExclusive(idA, idB)
    if PE.exclusions[idA] and PE.exclusions[idA][idB] then
        return true, PE.exclusions[idA][idB]
    end
    return false
end

--- Get the definition table for a registered effect type.
-- @param effectType string
-- @return table? The definition, or nil if not registered
function ix.playerEffects.GetTypeDef(effectType)
    return PE.types[effectType]
end

--- Get every registered effect type.
-- @return table {[id] = definition, ...}
function ix.playerEffects.GetAllTypes()
    return PE.types
end
