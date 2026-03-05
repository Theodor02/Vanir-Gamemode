--- Reagent Strand Definitions
-- All reagent strand data for the Bacta-Synth Protocol v2.2.
-- Strands are the fundamental building blocks of compound sequences.
-- Includes tail effects (v2.2), metaboliser strands, and tuning strands.
-- @module ix.bacta.strands

ix.bacta.strands = ix.bacta.strands or {}

--- Register a new reagent strand.
-- @param id string Unique strand identifier
-- @param data table Strand definition
function ix.bacta.RegisterStrand(id, data)
    data.id = id
    ix.bacta.strands[id] = data
end

--- Get all strands belonging to a specific category.
-- @param category string Category key ("base", "active", "stabiliser", "catalyst", "modifier")
-- @return table Array of strand definitions
function ix.bacta.GetStrandsByCategory(category)
    local result = {}

    for id, strand in pairs(ix.bacta.strands) do
        if (strand.category == category) then
            result[#result + 1] = strand
        end
    end

    return result
end

--- Get all strands belonging to a specific subcategory (e.g. "metaboliser", "tuning").
-- @param subcategory string Subcategory key
-- @return table Array of strand definitions
function ix.bacta.GetStrandsBySubcategory(subcategory)
    local result = {}

    for id, strand in pairs(ix.bacta.strands) do
        if (strand.subcategory == subcategory) then
            result[#result + 1] = strand
        end
    end

    return result
end

--- Get a strand definition by ID.
-- @param id string Strand ID
-- @return table|nil Strand definition or nil
function ix.bacta.GetStrand(id)
    return ix.bacta.strands[id]
end

--- Check if a strand is a metaboliser.
-- @param id string Strand ID
-- @return bool
function ix.bacta.IsMetaboliser(id)
    local strand = ix.bacta.strands[id]
    return strand and strand.subcategory == "metaboliser"
end

--- Check if a strand is a tuning strand.
-- @param id string Strand ID
-- @return bool
function ix.bacta.IsTuningStrand(id)
    local strand = ix.bacta.strands[id]
    return strand and strand.subcategory == "tuning"
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CATEGORY A — BASE COMPOUNDS
-- The carrier medium. Every sequence requires exactly one.
-- Determines item delivery type and sets the foundational effect.
-- Bases are tail-free.
-- ═══════════════════════════════════════════════════════════════════════════════

ix.bacta.RegisterStrand("base_bacta_a", {
    name          = "Bacta-A Suspension",
    category      = "base",
    description   = "Standard-grade bacta suspension. Reliable carrier medium with moderate restorative properties.",
    item_type     = "injector",
    cost_weight   = 3,
    potency_mod   = 1.0,
    stability_mod = 10,
    effects       = {
        {type = "heal_hp", magnitude = 20, duration = 0, immediate = true},
    },
    adjacency = {
        bonus   = {"act_genomic_rep"},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("base_bacta_b", {
    name          = "Bacta-B Hypersolution",
    category      = "base",
    description   = "Concentrated bacta hypersolution. High restorative yield with mild metabolic strain.",
    item_type     = "injector",
    cost_weight   = 5,
    potency_mod   = 1.0,
    stability_mod = 5,
    effects       = {
        {type = "heal_hp", magnitude = 35, duration = 0, immediate = true},
        {type = "side_fatigue", magnitude = 0.05, duration = 15, immediate = false},
    },
    -- v2.2: Low tail from high-yield base
    tail_effect   = "tail_hepatic_load",
    tail_delay    = 20,
    tail_duration = 15,
    tail_severity = "low",
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("base_kolto", {
    name          = "Kolto Hydrate",
    category      = "base",
    description   = "Refined kolto extract in aqueous suspension. Gradual restorative effect over time.",
    item_type     = "injector",
    cost_weight   = 4,
    potency_mod   = 1.0,
    stability_mod = 8,
    effects       = {
        {type = "regen_hp", magnitude = 4, duration = 20, tick_rate = 5, immediate = false},
    },
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("base_synth_plasma", {
    name          = "Synthetic Plasma Matrix",
    category      = "base",
    description   = "Bioengineered plasma replacement. Rapidly seals vascular damage and halts haemorrhage.",
    item_type     = "injector",
    cost_weight   = 4,
    potency_mod   = 1.0,
    stability_mod = 6,
    effects       = {
        {type = "heal_bleed", magnitude = 1, duration = 0, immediate = true},
    },
    adjacency = {
        bonus   = {},
        penalty = {"act_neurotox_block"},
    },
})

ix.bacta.RegisterStrand("base_nerve_gel", {
    name          = "Neural Conductive Gel",
    category      = "base",
    description   = "Neuroconductive polymer gel. Enhances synaptic clarity and fine motor control.",
    item_type     = "capsule",
    cost_weight   = 3,
    potency_mod   = 1.0,
    stability_mod = 4,
    effects       = {
        {type = "buff_focus", magnitude = 0.1, duration = 15, immediate = false},
    },
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- CATEGORY B — ACTIVE AGENTS
-- Primary functional agents. Contribute the bulk of medical or stimulant effects.
-- v2.2: Most Actives now have tail effects.
-- ═══════════════════════════════════════════════════════════════════════════════

ix.bacta.RegisterStrand("act_adrenaline_syn", {
    name          = "Synthkine-7 (Adrenogenic)",
    category      = "active",
    description   = "Synthetic adrenal analogue. Triggers sympathomimetic response: elevated speed and focus.",
    cost_weight   = 6,
    potency_mod   = 1.1,
    stability_mod = 0,
    effects       = {
        {type = "buff_speed", magnitude = 0.2, duration = 20, immediate = false},
        {type = "buff_focus", magnitude = 0.1, duration = 15, immediate = false},
    },
    -- v2.2: Post-stimulant crash
    tail_effect   = "tail_metabolic_crash",
    tail_delay    = 8,
    tail_duration = 12,
    tail_severity = "moderate",
    adjacency = {
        bonus   = {"cat_rapid_react"},
        penalty = {"act_sedative"},
    },
})

ix.bacta.RegisterStrand("act_coag_factor", {
    name          = "Coagulation Factor VII-S",
    category      = "active",
    description   = "Recombinant coagulation factor. Promotes rapid clot formation and minor tissue repair.",
    cost_weight   = 5,
    potency_mod   = 1.0,
    stability_mod = 0,
    effects       = {
        {type = "heal_bleed", magnitude = 1, duration = 0, immediate = true},
        {type = "heal_hp", magnitude = 8, duration = 0, immediate = true},
    },
    -- No tail: safe active
    adjacency = {
        bonus   = {"stab_iso_buffer"},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("act_neurotox_block", {
    name          = "NT-Blockade Compound",
    category      = "active",
    description   = "Broad-spectrum neurotoxin antagonist. Neutralises systemic toxins and suppresses nociception.",
    cost_weight   = 7,
    potency_mod   = 1.2,
    stability_mod = 0,
    effects       = {
        {type = "heal_toxin", magnitude = 1, duration = 0, immediate = true},
        {type = "suppress_pain", magnitude = 0.10, duration = 10, immediate = false},
    },
    -- v2.2: Blocking neurotoxin receptors causes brief neural noise on clearance
    tail_effect   = "tail_neural_static",
    tail_delay    = 5,
    tail_duration = 8,
    tail_severity = "low",
    adjacency = {
        bonus   = {},
        penalty = {"base_synth_plasma"},
    },
})

ix.bacta.RegisterStrand("act_regen_stim", {
    name          = "Mitogenic Stim-A",
    category      = "active",
    description   = "Activates mitogenic cell replication pathways. Sustained regenerative effect.",
    cost_weight   = 7,
    potency_mod   = 1.15,
    stability_mod = 0,
    effects       = {
        {type = "regen_hp", magnitude = 8, duration = 25, tick_rate = 5, immediate = false},
    },
    -- v2.2: Regeneration is metabolically expensive
    tail_effect   = "tail_hepatic_load",
    tail_delay    = 20,
    tail_duration = 15,
    tail_severity = "low",
    adjacency = {
        bonus   = {"stab_binding_prot"},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("act_stim_stamina", {
    name          = "Adrenal Sustain-3",
    category      = "active",
    description   = "Extended-release adrenal supplement. Restores stamina reserves and mildly elevates speed.",
    cost_weight   = 5,
    potency_mod   = 1.0,
    stability_mod = 0,
    effects       = {
        {type = "stim_stamina", magnitude = 40, duration = 0, immediate = true},
        {type = "buff_speed", magnitude = 0.1, duration = 10, immediate = false},
    },
    -- v2.2: Sustained adrenal stimulation causes cortisol overload
    tail_effect   = "tail_adrenal_dump",
    tail_delay    = 10,
    tail_duration = 10,
    tail_severity = "moderate",
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("act_sedative", {
    name          = "Neurocalm-D",
    category      = "active",
    description   = "GABAergic sedative compound. Deep pain suppression with post-dose fatigue.",
    cost_weight   = 5,
    potency_mod   = 0.9,
    stability_mod = 0,
    effects       = {
        {type = "suppress_pain", magnitude = 0.25, duration = 20, immediate = false},
        {type = "side_fatigue", magnitude = 0.10, duration = 15, immediate = false},
    },
    -- v2.2: Sedative clearance produces mild rebound stimulation
    tail_effect   = "tail_neural_static",
    tail_delay    = 5,
    tail_duration = 8,
    tail_severity = "low",
    adjacency = {
        bonus   = {},
        penalty = {"act_adrenaline_syn"},
    },
})

ix.bacta.RegisterStrand("act_hemostatic", {
    name          = "Hemostatic Accelerant",
    category      = "active",
    description   = "Fibrinogenic accelerant. Rapidly arrests haemorrhage with mild regenerative component.",
    cost_weight   = 4,
    potency_mod   = 1.0,
    stability_mod = 0,
    effects       = {
        {type = "heal_bleed", magnitude = 1, duration = 0, immediate = true},
        {type = "regen_hp", magnitude = 3, duration = 15, tick_rate = 5, immediate = false},
    },
    -- No tail: safe active
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("act_genomic_rep", {
    name          = "Genomic Repair Strand-Ω",
    category      = "active",
    description   = "Cutting-edge genomic repair nanophage. Massive restorative burst with sustained regeneration.",
    cost_weight   = 9,
    potency_mod   = 1.3,
    stability_mod = 0,
    effects       = {
        {type = "heal_hp", magnitude = 50, duration = 0, immediate = true},
        {type = "regen_hp", magnitude = 5, duration = 15, tick_rate = 5, immediate = false},
    },
    -- v2.2: Deep cellular repair disrupts neural signalling briefly
    tail_effect   = "tail_synaptic_rebound",
    tail_delay    = 5,
    tail_duration = 8,
    tail_severity = "moderate",
    adjacency = {
        bonus   = {"base_bacta_a"},
        penalty = {},
    },
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- CATEGORY C — STABILISERS
-- Improve sequence stability, reduce or eliminate side effects, extend durations.
-- Never contribute primary effects directly. Tail-free.
-- v2.2: Metaboliser strands are a subcategory that occupy Stabiliser slots.
-- ═══════════════════════════════════════════════════════════════════════════════

ix.bacta.RegisterStrand("stab_iso_buffer", {
    name          = "Isotonic Buffer Agent",
    category      = "stabiliser",
    description   = "pH-neutral isotonic buffer. Smooths biochemical integration and eliminates minor adverse reactions.",
    cost_weight   = 2,
    potency_mod   = 1.0,
    stability_mod = 15,
    effects       = {},
    special       = {type = "remove_lowest_side"},
    adjacency = {
        bonus   = {"act_coag_factor"},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("stab_binding_prot", {
    name          = "Binding Protein Complex",
    category      = "stabiliser",
    description   = "Recombinant binding proteins. Extends active compound half-life within the bloodstream.",
    cost_weight   = 3,
    potency_mod   = 1.0,
    stability_mod = 12,
    effects       = {},
    special       = {type = "extend_durations", value = 0.20},
    adjacency = {
        bonus   = {"act_regen_stim"},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("stab_chem_neutral", {
    name          = "Chemical Neutraliser",
    category      = "stabiliser",
    description   = "Broad-spectrum chemical neutraliser. Attenuates adverse biochemical responses.",
    cost_weight   = 2,
    potency_mod   = 1.0,
    stability_mod = 10,
    effects       = {},
    special       = {type = "reduce_sides", value = 0.50},
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("stab_temp_control", {
    name          = "Thermal Equilibrator",
    category      = "stabiliser",
    description   = "Thermal regulation agent. Prevents sequencer calibration drift during synthesis.",
    cost_weight   = 2,
    potency_mod   = 1.0,
    stability_mod = 8,
    effects       = {},
    special       = {type = "suppress_variance"},
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("stab_genomic_lock", {
    name          = "Genomic Sequence Lock",
    category      = "stabiliser",
    description   = "Locks the compound's molecular structure. Eliminates all potency variance — positive and negative.",
    cost_weight   = 3,
    potency_mod   = 1.0,
    stability_mod = 20,
    effects       = {},
    special       = {type = "lock_potency"},
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

-- v2: Degradation-reducing stabilisers
ix.bacta.RegisterStrand("stab_preservation_coating", {
    name          = "Preservation Coating",
    category      = "stabiliser",
    description   = "Reduces canister degradation per use by 50%. Protects the formula lattice during fabrication.",
    cost_weight   = 3,
    potency_mod   = 1.0,
    stability_mod = 5,
    effects       = {},
    special       = {type = "reduce_degradation", value = 0.50},
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("mod_stabilized_matrix", {
    name          = "Stabilised Matrix",
    category      = "modifier",
    description   = "Reduces canister degradation per use by 75%. Advanced lattice preservation technology.",
    cost_weight   = 4,
    potency_mod   = 1.0,
    stability_mod = 0,
    effects       = {},
    modifier_effect = {type = "reduce_degradation", value = 0.75},
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- CATEGORY C.2 — METABOLISER STRANDS (v2.2)
-- Subcategory of Stabilisers. Occupy Stabiliser slots.
-- Neutralise the tail effect of a specific strand placed BEFORE them in sequence.
-- Each metaboliser may introduce its own (milder) tail.
-- ═══════════════════════════════════════════════════════════════════════════════

ix.bacta.RegisterStrand("met_crash_suppress", {
    name          = "Metabolic Crash Suppressant",
    category      = "stabiliser",
    subcategory   = "metaboliser",
    description   = "Neutralises metabolic crash tail effects. Introduces mild hepatic load.",
    cost_weight   = 4,
    potency_mod   = 1.0,
    stability_mod = 2,
    effects       = {},
    metabolises   = "tail_metabolic_crash",
    met_tail      = {type = "tail_hepatic_load", delay = 20, duration = 12, severity = "low"},
    pool_rarity   = "common",
    adjacency = {
        bonus   = {"act_adrenaline_syn"},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("met_neural_buffer", {
    name          = "Neural Static Buffer",
    category      = "stabiliser",
    subcategory   = "metaboliser",
    description   = "Neutralises neural static tail effects. Introduces mild synaptic rebound.",
    cost_weight   = 4,
    potency_mod   = 1.0,
    stability_mod = 3,
    effects       = {},
    metabolises   = "tail_neural_static",
    met_tail      = {type = "tail_synaptic_rebound", delay = 5, duration = 8, severity = "low"},
    pool_rarity   = "common",
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("met_vascular_clamp", {
    name          = "Vascular Spike Clamp",
    category      = "stabiliser",
    subcategory   = "metaboliser",
    description   = "Neutralises vascular spike tail effects. Introduces mild adrenal dump.",
    cost_weight   = 5,
    potency_mod   = 1.0,
    stability_mod = 1,
    effects       = {},
    metabolises   = "tail_vascular_spike",
    met_tail      = {type = "tail_adrenal_dump", delay = 10, duration = 8, severity = "low"},
    pool_rarity   = "uncommon",
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("met_adrenal_flush", {
    name          = "Adrenal Flush Agent",
    category      = "stabiliser",
    subcategory   = "metaboliser",
    description   = "Neutralises adrenal dump tail effects. Clean termination — no own tail.",
    cost_weight   = 6,
    potency_mod   = 1.0,
    stability_mod = 0,
    effects       = {},
    metabolises   = "tail_adrenal_dump",
    met_tail      = nil, -- Clean termination
    pool_rarity   = "uncommon",
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("met_hepatic_assist", {
    name          = "Hepatic Assist Enzyme",
    category      = "stabiliser",
    subcategory   = "metaboliser",
    description   = "Neutralises hepatic load tail effects. Introduces mild neural static.",
    cost_weight   = 3,
    potency_mod   = 1.0,
    stability_mod = 4,
    effects       = {},
    metabolises   = "tail_hepatic_load",
    met_tail      = {type = "tail_neural_static", delay = 5, duration = 6, severity = "low"},
    pool_rarity   = "common",
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("met_synaptic_reset", {
    name          = "Synaptic Reset Factor",
    category      = "stabiliser",
    subcategory   = "metaboliser",
    description   = "Neutralises synaptic rebound tail effects. Clean termination — no own tail.",
    cost_weight   = 5,
    potency_mod   = 1.0,
    stability_mod = 2,
    effects       = {},
    metabolises   = "tail_synaptic_rebound",
    met_tail      = nil, -- Clean termination
    pool_rarity   = "rare",
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- CATEGORY D — CATALYSTS
-- Multiplicative amplifiers that alter the entire sequence. High risk/reward.
-- v2.2: Some catalysts now have tail effects.
-- ═══════════════════════════════════════════════════════════════════════════════

ix.bacta.RegisterStrand("cat_rapid_react", {
    name          = "Rapid-Reaction Enzyme",
    category      = "catalyst",
    description   = "Enzymatic accelerant. Amplifies all immediate-effect magnitudes at the cost of stability.",
    cost_weight   = 8,
    potency_mod   = 1.0,
    stability_mod = -5,
    effects       = {},
    catalyst_effect = {type = "boost_immediate", magnitude_mult = 1.30},
    -- v2.2: Rapid enzymatic acceleration strains vascular system
    tail_effect   = "tail_vascular_spike",
    tail_delay    = 0,
    tail_duration = 6,
    tail_severity = "high",
    adjacency = {
        bonus   = {"act_adrenaline_syn"},
        penalty = {"cat_potency_amp"},
    },
})

ix.bacta.RegisterStrand("cat_duration_ext", {
    name          = "Sustained-Release Microcapsule",
    category      = "catalyst",
    description   = "Microencapsulation technology. Extends all durations but dilutes peak magnitudes.",
    cost_weight   = 6,
    potency_mod   = 1.0,
    stability_mod = 0,
    effects       = {},
    catalyst_effect = {type = "extend_durations", duration_mult = 1.50, magnitude_mult = 0.85},
    -- No tail
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("cat_potency_amp", {
    name          = "Potency Amplifier-3",
    category      = "catalyst",
    description   = "Third-generation potency amplifier. Significantly boosts all magnitudes with stability trade-off.",
    cost_weight   = 9,
    potency_mod   = 1.0,
    stability_mod = -20,
    effects       = {},
    catalyst_effect = {type = "boost_all", magnitude_mult = 1.20},
    -- v2.2: Amplified biochemical activity causes significant crash
    tail_effect   = "tail_metabolic_crash",
    tail_delay    = 8,
    tail_duration = 12,
    tail_severity = "high",
    adjacency = {
        bonus   = {},
        penalty = {"cat_rapid_react"},
    },
})

ix.bacta.RegisterStrand("cat_negation", {
    name          = "Adverse Effect Suppressant",
    category      = "catalyst",
    description   = "Selective antagonist array. Eliminates adverse reactions while mildly attenuating primary effects.",
    cost_weight   = 7,
    potency_mod   = 1.0,
    stability_mod = 5,
    effects       = {},
    catalyst_effect = {type = "remove_sides", magnitude_mult = 0.90},
    -- No tail
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("cat_dual_phase", {
    name          = "Biphasic Delivery Agent",
    category      = "catalyst",
    description   = "Splits compound delivery into two phases: immediate burst (60%) and delayed release (40%) after 30 seconds.",
    cost_weight   = 8,
    potency_mod   = 1.0,
    stability_mod = -3,
    effects       = {},
    catalyst_effect = {type = "dual_phase", immediate_ratio = 0.60, delay = 30},
    -- v2.2: Phase 2 delivery disrupts hormonal balance
    tail_effect   = "tail_adrenal_dump",
    tail_delay    = 10,
    tail_duration = 10,
    tail_severity = "low",
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- CATEGORY E — MODIFIERS
-- Fine-tuning agents. Small effects on delivery, dosage, or secondary properties.
-- ═══════════════════════════════════════════════════════════════════════════════

ix.bacta.RegisterStrand("mod_aero_disperse", {
    name          = "Aerosol Dispersion Agent",
    category      = "modifier",
    description   = "Converts compound to aerosol form. Area-of-effect delivery within a 2-metre radius.",
    cost_weight   = 3,
    potency_mod   = 1.0,
    stability_mod = 0,
    effects       = {},
    modifier_effect = {type = "change_item_type", item_type = "aerosol"},
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("mod_patch_bind", {
    name          = "Transdermal Binding Substrate",
    category      = "modifier",
    description   = "Transdermal delivery substrate. Converts compound to a contact-application dermal patch.",
    cost_weight   = 2,
    potency_mod   = 1.0,
    stability_mod = 0,
    effects       = {},
    modifier_effect = {type = "change_item_type", item_type = "patch"},
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("mod_fast_absorb", {
    name          = "Rapid Absorption Catalyst",
    category      = "modifier",
    description   = "Absorption accelerant. All immediate effects fire with a brief smoothing delay (0.5s).",
    cost_weight   = 2,
    potency_mod   = 1.0,
    stability_mod = 2,
    effects       = {},
    modifier_effect = {type = "smooth_absorption", delay = 0.5},
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("mod_multi_dose", {
    name          = "Multi-Dose Microcapsule Matrix",
    category      = "modifier",
    description   = "Microencapsulated multi-dose system. Adds one additional use to the fabricated compound (max 3).",
    cost_weight   = 5,
    potency_mod   = 1.0,
    stability_mod = -2,
    effects       = {},
    modifier_effect = {type = "add_uses", value = 1, max = 3},
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

ix.bacta.RegisterStrand("mod_stim_trace", {
    name          = "Trace Stimulant Additive",
    category      = "modifier",
    description   = "Low-dose stimulant trace. Adds a mild focus-enhancing secondary effect.",
    cost_weight   = 3,
    potency_mod   = 1.0,
    stability_mod = 0,
    effects       = {},
    modifier_effect = {type = "add_effect", effect = {type = "buff_focus", magnitude = 0.05, duration = 10, immediate = false}},
    adjacency = {
        bonus   = {},
        penalty = {},
    },
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- CATEGORY E.2 — TUNING STRANDS (v2.2)
-- Subcategory of Modifiers. Occupy Modifier slots (max 2 per formula).
-- Adjust numerical properties of effects already present in the formula.
-- ═══════════════════════════════════════════════════════════════════════════════

-- ─── Magnitude Scalers ───────────────────────────────────────────────────────

ix.bacta.RegisterStrand("tun_mag_boost_heal", {
    name          = "Healing Amplifier",
    category      = "modifier",
    subcategory   = "tuning",
    description   = "+25% magnitude to all heal_hp, regen_hp effects.",
    cost_weight   = 5,
    potency_mod   = 1.0,
    stability_mod = -5,
    effects       = {},
    tuning_effect = {type = "magnitude_scale", targets = {"heal_hp", "regen_hp"}, multiplier = 1.25},
    pool_rarity   = "common",
    adjacency = { bonus = {}, penalty = {} },
})

ix.bacta.RegisterStrand("tun_mag_reduce_heal", {
    name          = "Healing Attenuator",
    category      = "modifier",
    subcategory   = "tuning",
    description   = "-20% magnitude to all heal_hp, regen_hp effects. Grants stability.",
    cost_weight   = 3,
    potency_mod   = 1.0,
    stability_mod = 8,
    effects       = {},
    tuning_effect = {type = "magnitude_scale", targets = {"heal_hp", "regen_hp"}, multiplier = 0.80},
    pool_rarity   = "common",
    adjacency = { bonus = {}, penalty = {} },
})

ix.bacta.RegisterStrand("tun_mag_boost_buff", {
    name          = "Buff Amplifier",
    category      = "modifier",
    subcategory   = "tuning",
    description   = "+20% magnitude to all buff_* effects.",
    cost_weight   = 6,
    potency_mod   = 1.0,
    stability_mod = -8,
    effects       = {},
    tuning_effect = {type = "magnitude_scale", target_prefix = "buff_", multiplier = 1.20},
    pool_rarity   = "uncommon",
    adjacency = { bonus = {}, penalty = {} },
})

ix.bacta.RegisterStrand("tun_mag_reduce_side", {
    name          = "Adverse Attenuator",
    category      = "modifier",
    subcategory   = "tuning",
    description   = "-30% magnitude to all side_* effects only.",
    cost_weight   = 4,
    potency_mod   = 1.0,
    stability_mod = 5,
    effects       = {},
    tuning_effect = {type = "magnitude_scale", target_prefix = "side_", multiplier = 0.70},
    pool_rarity   = "common",
    adjacency = { bonus = {}, penalty = {} },
})

ix.bacta.RegisterStrand("tun_mag_boost_side", {
    name          = "Adverse Amplifier",
    category      = "modifier",
    subcategory   = "tuning",
    description   = "+40% magnitude to all side_* effects. Grants stability.",
    cost_weight   = 2,
    potency_mod   = 1.0,
    stability_mod = 3,
    effects       = {},
    tuning_effect = {type = "magnitude_scale", target_prefix = "side_", multiplier = 1.40},
    pool_rarity   = "uncommon",
    adjacency = { bonus = {}, penalty = {} },
})

ix.bacta.RegisterStrand("tun_mag_boost_all", {
    name          = "Broadband Amplifier",
    category      = "modifier",
    subcategory   = "tuning",
    description   = "+15% magnitude to ALL effects (beneficial and adverse).",
    cost_weight   = 7,
    potency_mod   = 1.0,
    stability_mod = -12,
    effects       = {},
    tuning_effect = {type = "magnitude_scale", targets_all = true, multiplier = 1.15},
    pool_rarity   = "rare",
    adjacency = { bonus = {}, penalty = {} },
})

-- ─── Duration Scalers ────────────────────────────────────────────────────────

ix.bacta.RegisterStrand("tun_dur_extend_buff", {
    name          = "Buff Extender",
    category      = "modifier",
    subcategory   = "tuning",
    description   = "+40% duration to all buff_* and stim_* effects.",
    cost_weight   = 5,
    potency_mod   = 1.0,
    stability_mod = -3,
    effects       = {},
    tuning_effect = {type = "duration_scale", target_prefix = "buff_|stim_", multiplier = 1.40},
    pool_rarity   = "common",
    adjacency = { bonus = {}, penalty = {} },
})

ix.bacta.RegisterStrand("tun_dur_shorten_buff", {
    name          = "Buff Compressor",
    category      = "modifier",
    subcategory   = "tuning",
    description   = "-30% duration, +15% magnitude to all buff_* effects (shorter but stronger burst).",
    cost_weight   = 4,
    potency_mod   = 1.0,
    stability_mod = 5,
    effects       = {},
    tuning_effect = {type = "compress", target_prefix = "buff_", duration_mult = 0.70, magnitude_mult = 1.15},
    pool_rarity   = "uncommon",
    adjacency = { bonus = {}, penalty = {} },
})

ix.bacta.RegisterStrand("tun_dur_extend_regen", {
    name          = "Regen Sustainer",
    category      = "modifier",
    subcategory   = "tuning",
    description   = "+50% duration to regen_hp effects only.",
    cost_weight   = 5,
    potency_mod   = 1.0,
    stability_mod = -4,
    effects       = {},
    tuning_effect = {type = "duration_scale", targets = {"regen_hp"}, multiplier = 1.50},
    pool_rarity   = "common",
    adjacency = { bonus = {}, penalty = {} },
})

ix.bacta.RegisterStrand("tun_dur_shorten_side", {
    name          = "Side Effect Accelerator",
    category      = "modifier",
    subcategory   = "tuning",
    description   = "-40% duration to all side_* effects (faster burn-through).",
    cost_weight   = 3,
    potency_mod   = 1.0,
    stability_mod = 6,
    effects       = {},
    tuning_effect = {type = "duration_scale", target_prefix = "side_", multiplier = 0.60},
    pool_rarity   = "common",
    adjacency = { bonus = {}, penalty = {} },
})

ix.bacta.RegisterStrand("tun_dur_extend_tail", {
    name          = "Tail Prolonger",
    category      = "modifier",
    subcategory   = "tuning",
    description   = "+60% tail effect duration. Grants stability.",
    cost_weight   = 2,
    potency_mod   = 1.0,
    stability_mod = -6,
    effects       = {},
    tuning_effect = {type = "tail_duration_scale", multiplier = 1.60},
    pool_rarity   = "uncommon",
    adjacency = { bonus = {}, penalty = {} },
})

ix.bacta.RegisterStrand("tun_dur_shorten_tail", {
    name          = "Tail Compressor",
    category      = "modifier",
    subcategory   = "tuning",
    description   = "-50% tail effect duration.",
    cost_weight   = 4,
    potency_mod   = 1.0,
    stability_mod = 4,
    effects       = {},
    tuning_effect = {type = "tail_duration_scale", multiplier = 0.50},
    pool_rarity   = "uncommon",
    adjacency = { bonus = {}, penalty = {} },
})

-- ─── Selective Effect Operators ──────────────────────────────────────────────

ix.bacta.RegisterStrand("tun_sel_isolate_combat", {
    name          = "Combat Isolator",
    category      = "modifier",
    subcategory   = "tuning",
    description   = "Suppresses non-combat effects (regen, stamina). Boosts buff_speed and buff_focus by +20%.",
    cost_weight   = 6,
    potency_mod   = 1.0,
    stability_mod = -5,
    effects       = {},
    tuning_effect = {type = "selective_isolate", mode = "combat"},
    pool_rarity   = "uncommon",
    adjacency = { bonus = {}, penalty = {} },
})

ix.bacta.RegisterStrand("tun_sel_isolate_heal", {
    name          = "Healing Isolator",
    category      = "modifier",
    subcategory   = "tuning",
    description   = "Suppresses all buff_* effects. Boosts heal_hp and regen_hp by +20%.",
    cost_weight   = 6,
    potency_mod   = 1.0,
    stability_mod = -5,
    effects       = {},
    tuning_effect = {type = "selective_isolate", mode = "healing"},
    pool_rarity   = "uncommon",
    adjacency = { bonus = {}, penalty = {} },
})

ix.bacta.RegisterStrand("tun_sel_crit_only", {
    name          = "Critical Threshold Gate",
    category      = "modifier",
    subcategory   = "tuning",
    description   = "All healing effects fire at +50% magnitude when recipient is below 30% HP. No effect above threshold.",
    cost_weight   = 7,
    potency_mod   = 1.0,
    stability_mod = -8,
    effects       = {},
    tuning_effect = {type = "selective_threshold", threshold = 0.30, bonus = 1.50},
    pool_rarity   = "rare",
    adjacency = { bonus = {}, penalty = {} },
})

ix.bacta.RegisterStrand("tun_sel_suppress_tails", {
    name          = "Tail Gate Suppressor",
    category      = "modifier",
    subcategory   = "tuning",
    description   = "Suppresses ALL tail effects. Disables Chain Purity bonus. Cannot combine with metabolisers.",
    cost_weight   = 8,
    potency_mod   = 1.0,
    stability_mod = -15,
    effects       = {},
    tuning_effect = {type = "suppress_all_tails"},
    pool_rarity   = "common",
    adjacency = { bonus = {}, penalty = {} },
})

ix.bacta.RegisterStrand("tun_sel_invert_side", {
    name          = "Adverse Inverter",
    category      = "modifier",
    subcategory   = "tuning",
    description   = "Converts the lowest-magnitude side_* effect into a 50% strength beneficial equivalent.",
    cost_weight   = 9,
    potency_mod   = 1.0,
    stability_mod = -12,
    effects       = {},
    tuning_effect = {type = "invert_lowest_side"},
    pool_rarity   = "very_rare",
    adjacency = { bonus = {}, penalty = {} },
})

ix.bacta.RegisterStrand("tun_sel_stack_resist", {
    name          = "Resistance Bypass",
    category      = "modifier",
    subcategory   = "tuning",
    description   = "Second dose stacks at 75% instead of 0%. Ignores recipient's buff stacking cap.",
    cost_weight   = 7,
    potency_mod   = 1.0,
    stability_mod = -10,
    effects       = {},
    tuning_effect = {type = "stack_bypass", stack_mult = 0.75},
    pool_rarity   = "rare",
    adjacency = { bonus = {}, penalty = {} },
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- CATEGORY METADATA
-- ═══════════════════════════════════════════════════════════════════════════════

--- Category display data for UI rendering.
-- @table ix.bacta.CategoryInfo
ix.bacta.CategoryInfo = {
    base = {
        name    = "Base Compounds",
        color   = Color(80, 180, 255),
        order   = 1,
        desc    = "Carrier medium. Exactly one required per sequence.",
    },
    active = {
        name    = "Active Agents",
        color   = Color(255, 160, 50),
        order   = 2,
        desc    = "Primary functional components. High variance and cost.",
    },
    stabiliser = {
        name    = "Stabilisers",
        color   = Color(100, 255, 150),
        order   = 3,
        desc    = "Improve stability and reduce adverse reactions.",
    },
    catalyst = {
        name    = "Catalysts",
        color   = Color(255, 80, 80),
        order   = 4,
        desc    = "Multiplicative amplifiers. High risk/reward.",
    },
    modifier = {
        name    = "Modifiers",
        color   = Color(200, 150, 255),
        order   = 5,
        desc    = "Fine-tuning agents for delivery and dosage.",
    },
}

--- Subcategory display data for UI rendering.
-- @table ix.bacta.SubcategoryInfo
ix.bacta.SubcategoryInfo = {
    metaboliser = {
        name    = "Metabolisers",
        color   = Color(120, 230, 180),
        desc    = "Neutralise tail effects from preceding strands.",
        parent  = "stabiliser",
    },
    tuning = {
        name    = "Tuning Strands",
        color   = Color(220, 180, 255),
        desc    = "Precision modifiers for effect magnitudes and durations.",
        parent  = "modifier",
    },
}

--- Pool rarity weights for session pool generation.
-- @table ix.bacta.PoolRarityWeights
ix.bacta.PoolRarityWeights = {
    common    = 0.60,
    uncommon  = 0.30,
    rare      = 0.15,
    very_rare = 0.08,
}
