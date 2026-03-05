--- Shared effect identifiers and registry.
-- @module ix.hacking

ix.hacking = ix.hacking or {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- EFFECT IDS
-- ═══════════════════════════════════════════════════════════════════════════════

ix.hacking.EffectIDs = {
    NONE              = "none",
    REMOVE_DUD        = "remove_dud",
    RESET_ATTEMPTS    = "reset_attempts",
    ATTEMPT_INSURANCE = "attempt_insurance",
    REVEAL_POSITION   = "reveal_position",
    LETTER_FREQUENCY  = "letter_frequency",
    SOFT_MARK_DUD     = "soft_mark_dud"
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- EFFECT REGISTRY
-- ═══════════════════════════════════════════════════════════════════════════════

ix.hacking.Effects = ix.hacking.Effects or {}
ix.hacking.Effects.Registry = ix.hacking.Effects.Registry or {}

--- Register a new effect definition.
-- @param def table Effect definition table (must contain `id`).
function ix.hacking.Effects.Register(def)
    if (!def.id) then
        ErrorNoHalt("[ix.hacking] Effect registered without ID!\n")
        return
    end

    def.weight = def.weight or 1

    ix.hacking.Effects.Registry[def.id] = def
end

--- Retrieve an effect definition by ID.
-- @param id string
-- @return table|nil
function ix.hacking.Effects.Get(id)
    return ix.hacking.Effects.Registry[id]
end
