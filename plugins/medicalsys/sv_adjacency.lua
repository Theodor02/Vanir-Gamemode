--- Directional Adjacency System (v2.1)
-- Extracted from sv_synthesis.lua. Adjacency effects now support directional
-- modifiers: forward (A→B) and reverse (B→A) can have different effects.
-- Hidden synergies are discoverable only through experimentation.
-- @module ix.bacta.adjacency

-- ═══════════════════════════════════════════════════════════════════════════════
-- DIRECTIONAL ADJACENCY TABLES
-- Each rule defines effects when strand A is placed immediately before strand B
-- in the sequence. modifier_forward applies to A→B, modifier_reverse to B→A.
-- ═══════════════════════════════════════════════════════════════════════════════

ix.bacta.AdjacencyRules = {
    -- ── Base + Active synergies ──────────────────────────────────────────
    {
        a = "base_bacta_a", b = "act_genomic_rep",
        modifier_forward = {magnitude_mult = 1.10},
        modifier_reverse = {magnitude_mult = 1.05},
        hidden = false,
    },
    {
        a = "base_kolto", b = "act_regen_stim",
        modifier_forward = {duration_mult = 1.20},
        modifier_reverse = {duration_mult = 1.10},
        hidden = false,
    },

    -- ── Active + Stabiliser / Catalyst synergies ─────────────────────────
    {
        a = "act_coag_factor", b = "stab_iso_buffer",
        modifier_forward = {stability = 8},
        modifier_reverse = {stability = 4},
        hidden = false,
    },
    {
        a = "act_regen_stim", b = "stab_binding_prot",
        modifier_forward = {duration_mult = 1.15},
        modifier_reverse = {duration_mult = 1.08},
        hidden = false,
    },
    {
        a = "cat_rapid_react", b = "act_adrenaline_syn",
        modifier_forward = {magnitude_add = {type = "buff_speed", value = 0.05}},
        modifier_reverse = {magnitude_add = {type = "buff_speed", value = 0.03}},
        hidden = false,
    },

    -- ── Metaboliser placement synergies ──────────────────────────────────
    {
        a = "met_crash_suppress", b = "act_adrenaline_syn",
        modifier_forward = {stability = 5},
        modifier_reverse = {stability = 3},
        hidden = false,
    },
    {
        a = "met_hepatic_assist", b = "act_regen_stim",
        modifier_forward = {stability = 4},
        modifier_reverse = {stability = 2},
        hidden = false,
    },

    -- ── Hidden synergies (discoverable only through experimentation) ─────
    {
        a = "act_genomic_rep", b = "met_synaptic_reset",
        modifier_forward = {magnitude_mult = 1.08, stability = 3},
        modifier_reverse = {stability = 1},
        hidden = true,
    },
    {
        a = "base_bacta_b", b = "met_hepatic_assist",
        modifier_forward = {stability = 6},
        modifier_reverse = {stability = 2},
        hidden = true,
    },
    {
        a = "act_adrenaline_syn", b = "met_crash_suppress",
        modifier_forward = {magnitude_mult = 1.05, stability = 4},
        modifier_reverse = {stability = 2},
        hidden = true,
    },
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- ADJACENCY PENALTY RULES
-- ═══════════════════════════════════════════════════════════════════════════════

ix.bacta.AdjacencyPenalties = {
    {
        a = "act_sedative", b = "act_adrenaline_syn",
        modifier_forward = {stability = -15, magnitude_mult = 0.80},
        modifier_reverse = {stability = -10, magnitude_mult = 0.85},
        hidden = false,
    },
    {
        a = "cat_potency_amp", b = "cat_rapid_react",
        modifier_forward = {stability = -25},
        modifier_reverse = {stability = -20},
        hidden = false,
    },
    {
        a = "base_synth_plasma", b = "act_neurotox_block",
        modifier_forward = {inject_effect = {type = "side_cardiac", magnitude = 3, duration = 10, tick_rate = 5, immediate = false}},
        modifier_reverse = {inject_effect = {type = "side_cardiac", magnitude = 2, duration = 8, tick_rate = 5, immediate = false}},
        hidden = false,
    },
    -- Tuning strand conflicts
    {
        a = "tun_sel_suppress_tails", b = "met_crash_suppress",
        modifier_forward = {stability = -20},
        modifier_reverse = {stability = -20},
        hidden = false,
    },
    {
        a = "tun_sel_suppress_tails", b = "met_neural_buffer",
        modifier_forward = {stability = -20},
        modifier_reverse = {stability = -20},
        hidden = false,
    },
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- DIRECTIONAL RESOLUTION
-- ═══════════════════════════════════════════════════════════════════════════════

--- Apply a single directional modifier to the effects array and stability.
-- @param modifier table The modifier table (magnitude_mult, stability, etc.)
-- @param effects table Mutable effects array
-- @param stabilityRef table Table with .value field
local function ApplyDirectionalModifier(modifier, effects, stabilityRef)
    if (!modifier) then return end

    -- Stability adjustment
    if (modifier.stability) then
        stabilityRef.value = stabilityRef.value + modifier.stability
    end

    -- Duration multiplier on all effects
    if (modifier.duration_mult) then
        for _, eff in ipairs(effects) do
            if (eff.duration and eff.duration > 0) then
                eff.duration = math.Round(eff.duration * modifier.duration_mult, 1)
            end
        end
    end

    -- Magnitude multiplier on all effects
    if (modifier.magnitude_mult) then
        for _, eff in ipairs(effects) do
            if (eff.magnitude) then
                eff.magnitude = math.Round(eff.magnitude * modifier.magnitude_mult, 2)
            end
        end
    end

    -- Add magnitude to a specific effect type
    if (modifier.magnitude_add) then
        for _, eff in ipairs(effects) do
            if (eff.type == modifier.magnitude_add.type) then
                eff.magnitude = eff.magnitude + modifier.magnitude_add.value
            end
        end
    end

    -- Inject a new effect
    if (modifier.inject_effect) then
        effects[#effects + 1] = table.Copy(modifier.inject_effect)
    end
end

--- Check and apply directional adjacency effects between two strands in sequence order.
-- A is at position i, B is at position i+1.
-- @param aID string Strand ID at position i
-- @param bID string Strand ID at position i+1
-- @param effects table Mutable effects array
-- @param stabilityRef table Mutable stability reference
-- @param discoveredHidden table|nil Set of known hidden synergy keys (for display)
function ix.bacta.CheckDirectionalAdjacency(aID, bID, effects, stabilityRef, discoveredHidden)
    discoveredHidden = discoveredHidden or {}

    -- Check bonus rules
    for _, rule in ipairs(ix.bacta.AdjacencyRules) do
        local isForward = (rule.a == aID and rule.b == bID)
        local isReverse = (rule.a == bID and rule.b == aID)

        if (isForward or isReverse) then
            -- Skip hidden synergies unless already discovered
            if (rule.hidden) then
                local key = rule.a .. "+" .. rule.b
                local revKey = rule.b .. "+" .. rule.a

                if (!discoveredHidden[key] and !discoveredHidden[revKey]) then
                    -- Mark as newly discovered
                    if (discoveredHidden) then
                        discoveredHidden[isForward and key or revKey] = true
                    end
                end
            end

            local modifier = isForward and rule.modifier_forward or rule.modifier_reverse
            ApplyDirectionalModifier(modifier, effects, stabilityRef)
        end
    end

    -- Check penalty rules
    for _, rule in ipairs(ix.bacta.AdjacencyPenalties) do
        local isForward = (rule.a == aID and rule.b == bID)
        local isReverse = (rule.a == bID and rule.b == aID)

        if (isForward or isReverse) then
            local modifier = isForward and rule.modifier_forward or rule.modifier_reverse
            ApplyDirectionalModifier(modifier, effects, stabilityRef)
        end
    end
end

--- Get all adjacency rules that apply to a specific strand (for UI tooltips).
-- @param strandID string Strand ID
-- @return table Array of {partner, direction, isBonus, modifier, hidden}
function ix.bacta.GetAdjacencyRulesFor(strandID)
    local result = {}

    for _, rule in ipairs(ix.bacta.AdjacencyRules) do
        if (rule.a == strandID) then
            result[#result + 1] = {partner = rule.b, direction = "forward", isBonus = true, modifier = rule.modifier_forward, hidden = rule.hidden}
        end
        if (rule.b == strandID) then
            result[#result + 1] = {partner = rule.a, direction = "reverse", isBonus = true, modifier = rule.modifier_reverse, hidden = rule.hidden}
        end
    end

    for _, rule in ipairs(ix.bacta.AdjacencyPenalties) do
        if (rule.a == strandID) then
            result[#result + 1] = {partner = rule.b, direction = "forward", isBonus = false, modifier = rule.modifier_forward, hidden = rule.hidden or false}
        end
        if (rule.b == strandID) then
            result[#result + 1] = {partner = rule.a, direction = "reverse", isBonus = false, modifier = rule.modifier_reverse, hidden = rule.hidden or false}
        end
    end

    return result
end
