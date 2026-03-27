--- Disease Integration Bridge (v3.0)
-- Connects the Bacta-Synth Protocol with the Smart Disease System.
-- Adds disease-related effect types, reagent strands, adjacency rules,
-- and a resonance pattern system for cross-plugin synergy.
--
-- Requires: smartdisease plugin (optional — gracefully degrades when absent).
-- @module ix.bacta.diseaseBridge
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- EXPANDED STRAND LIBRARY (v3.1)
-- ═══════════════════════════════════════════════════════════════════════════════
-- SYMPTOM-SPECIFIC STRANDS (7 strands):
--   - Pyrogenic Agent (fever), Hallucinogen, Pain Amplifier, Respiratory Inhibitor
--   - Muscle Inhibitor, Emetic Compound, and more symptom-focused agents
--
-- MID-TIER DISEASE STRANDS (5 strands):
--   - Space Plague, Neural Parasite, Withering Sickness, Anxiety Inducer
--   - Toxin Synthesizer Bacteria
--
-- SPECIFIC DISEASE INDUCERS (6 legendary strands):
--   - Rakghoul Plague, Krytos Virus, Bloodburn Pathogen, Neuroplague
--   - Cyberia Psychosis, Corellian Plague
--
-- EXTREME/HIGH-RISK COMPOUNDS (3 legendary strands):
--   - Panacea-Ω (ultimate cure, catastrophically unstable)
--   - Genetic Mutagen (completely random effects)
--   - Necrotic Agent (pure damage dealer)
--
-- BIOWEAPON STRANDS (4 strands):
--   - Multi-Pathogen Carrier, Immune Destroyer, Contagion Enhancer
--   - Bioweapon Catalyst (inverts cures into diseases)
--
-- NEW EFFECT TYPES (14 types):
--   - 8 symptom effects (fever, cough, hallucination, pain, weakness, confusion, nausea, immune suppression)
--   - 2 bioweapon effects (immune suppression, contagion amplification)
--   - 4 tail effects (necrotic cascade, genetic instability, cascade failure, pathogenic reaction)
--
-- NEW RESONANCE PATTERNS (7 patterns):
--   - Perfect Bioweapon, Symptom Cascade, Necrotic Plague, Psychotic Break
--   - Catalyst Inversion, Panacea Miracle, and existing patterns
--
-- TOTAL NEW CONTENT: 25 strands, 14 effect types, 7 resonance patterns

-- ═══════════════════════════════════════════════════════════════════════════════
-- BRIDGE UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════════

--- Check if the Smart Disease plugin is loaded and available.
-- @return bool Whether ix.disease is available with a functioning API
function ix.bacta.IsDiseaseSystemAvailable()
    return ix.disease != nil
        and ix.disease._registered != nil
        and ix.disease.Get != nil
end

--- Get all registered disease IDs matching a given disease type.
-- @param diseaseType string "viral", "bacterial", or "psychological"
-- @return table Array of disease ID strings
function ix.bacta.GetDiseasesByType(diseaseType)
    if (!ix.bacta.IsDiseaseSystemAvailable()) then return {} end

    local result = {}

    for id, data in pairs(ix.disease.GetAll()) do
        if (data.type == diseaseType) then
            result[#result + 1] = id
        end
    end

    return result
end

--- Map a bacta medicine category to SmartDisease medicine type strings.
-- @param category string "antiviral", "antibiotic", "antipsychotic", "antianxiety", or "broad_spectrum"
-- @return table Array of medicine type strings accepted by ix.disease.ApplyMedicine
function ix.bacta.GetMedicineTypesForCategory(category)
    local map = {
        antiviral      = {"antiviral"},
        antibiotic     = {"antibiotic"},
        antipsychotic  = {"antipsychotic"},
        antianxiety    = {"antianxiety"},
        broad_spectrum = {"antiviral", "antibiotic", "antipsychotic", "antianxiety"},
    }

    return map[category] or {}
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DISEASE-RELATED EFFECT TYPE REGISTRATIONS
-- ═══════════════════════════════════════════════════════════════════════════════

-- ─── Beneficial Disease Effects ──────────────────────────────────────────────

ix.bacta.RegisterEffectType("disease_treat", {
    name         = "Pathogenic Treatment",
    description  = "Administers targeted treatment to active infections, causing disease regression.",
    color        = Color(80, 220, 120),
    isSideEffect = false,
    format = function(eff)
        local cat = eff.disease_category or "unknown"
        local catNames = {
            antiviral      = "Antiviral",
            antibiotic     = "Antibiotic",
            antipsychotic  = "Antipsychotic",
            antianxiety    = "Anxiolytic",
            broad_spectrum = "Broad-Spectrum",
        }
        return string.format("%s treatment (potency %d%%)", catNames[cat] or cat, math.floor((eff.magnitude or 1) * 100))
    end,
})

ix.bacta.RegisterEffectType("disease_cure", {
    name         = "Pathogenic Cure",
    description  = "Directly eliminates a specific disease or disease category from the patient.",
    color        = Color(50, 255, 120),
    isSideEffect = false,
    format = function(eff)
        local target = eff.disease_target or "unknown"

        if (ix.bacta.IsDiseaseSystemAvailable()) then
            local disease = ix.disease.Get(target)
            if (disease) then
                return "Cures " .. disease.name
            end
        end

        local typeNames = {viral = "viral", bacterial = "bacterial", psychological = "psychological"}
        return "Cures " .. (typeNames[target] or target) .. " infections"
    end,
})

ix.bacta.RegisterEffectType("disease_cure_all", {
    name         = "Universal Pathogenic Purge",
    description  = "Eliminates all active infections from the patient. Extremely potent.",
    color        = Color(50, 255, 200),
    isSideEffect = false,
    format = function(eff)
        return "Purges ALL active diseases"
    end,
})

ix.bacta.RegisterEffectType("disease_vaccinate", {
    name         = "Immunogenic Priming",
    description  = "Grants lasting immunity against a specific pathogen.",
    color        = Color(100, 200, 255),
    isSideEffect = false,
    format = function(eff)
        local target = eff.disease_target or "unknown"

        if (ix.bacta.IsDiseaseSystemAvailable()) then
            local disease = ix.disease.Get(target)
            if (disease) then
                return "Vaccine: " .. disease.name
            end
        end

        return "Vaccination (" .. target .. ")"
    end,
})

ix.bacta.RegisterEffectType("disease_suppress", {
    name         = "Pathogenic Suppression",
    description  = "Temporarily halts disease progression, buying time for treatment.",
    color        = Color(150, 220, 180),
    isSideEffect = false,
    format = function(eff)
        return string.format("Suppresses disease progression for %ds", eff.duration or 0)
    end,
})

-- ─── Adverse Disease Effects ─────────────────────────────────────────────────

ix.bacta.RegisterEffectType("disease_infect", {
    name         = "Pathogenic Contamination",
    description  = "The compound carries a live pathogen that infects the patient.",
    color        = Color(200, 50, 50),
    isSideEffect = true,
    format = function(eff)
        local target = eff.disease_target or "random"

        if (target == "random" or target == "random_severe") then
            return "Risk of pathogenic infection"
        end

        if (ix.bacta.IsDiseaseSystemAvailable()) then
            local disease = ix.disease.Get(target)
            if (disease) then
                return "Infects with " .. disease.name
            end
        end

        return "Infects with " .. target
    end,
})

ix.bacta.RegisterEffectType("disease_worsen", {
    name         = "Pathogenic Acceleration",
    description  = "Accelerates disease progression, advancing active infections.",
    color        = Color(220, 80, 50),
    isSideEffect = true,
    format = function(eff)
        return string.format("Advances diseases by %d stage(s)", math.floor(eff.magnitude or 1))
    end,
})

-- ─── Disease Tail Effect ─────────────────────────────────────────────────────

ix.bacta.RegisterEffectType("tail_pathogenic_reaction", {
    name         = "Pathogenic Reaction",
    description  = "Delayed immune system compromise from unstable pathogenic compounds. Risk of infection.",
    color        = Color(180, 60, 60),
    isSideEffect = true,
    isTailEffect = true,
    format = function(eff)
        return string.format("Pathogenic Reaction: infection risk after %ds", eff.delay or 10)
    end,
})

ix.bacta.RegisterEffectType("tail_necrotic_cascade", {
    name         = "Necrotic Cascade",
    description  = "Delayed tissue death spreading from the initial necrotic site. Causes ongoing damage.",
    color        = Color(140, 40, 40),
    isSideEffect = true,
    isTailEffect = true,
    format = function(eff)
        return string.format("Necrotic Cascade: tissue death after %ds", eff.delay or 8)
    end,
})

ix.bacta.RegisterEffectType("tail_genetic_instability", {
    name         = "Genetic Instability",
    description  = "Mutagenic compounds destabilise cellular DNA, causing unpredictable delayed effects.",
    color        = Color(160, 100, 200),
    isSideEffect = true,
    isTailEffect = true,
    format = function(eff)
        return string.format("Genetic Instability: mutation risk after %ds", eff.delay or 3)
    end,
})

ix.bacta.RegisterEffectType("tail_cascade_failure", {
    name         = "Cascade Failure",
    description  = "Catastrophic systemic collapse from unstable compounds. Multiple organ failure.",
    color        = Color(200, 20, 20),
    isSideEffect = true,
    isTailEffect = true,
    format = function(eff)
        return string.format("CASCADE FAILURE after %ds", eff.delay or 5)
    end,
})

-- ─── Disease Symptom Effects ─────────────────────────────────────────────────

ix.bacta.RegisterEffectType("disease_symptom_fever", {
    name         = "Pyrogenic Response",
    description  = "Induces elevated body temperature and fever symptoms without full infection.",
    color        = Color(200, 100, 50),
    isSideEffect = true,
    format = function(eff)
        return string.format("Fever (severity %d%%) for %ds", math.floor((eff.magnitude or 1) * 100), eff.duration or 0)
    end,
})

ix.bacta.RegisterEffectType("disease_symptom_cough", {
    name         = "Respiratory Irritation",
    description  = "Causes persistent coughing and respiratory distress.",
    color        = Color(150, 120, 90),
    isSideEffect = true,
    format = function(eff)
        return string.format("Respiratory distress for %ds", eff.duration or 0)
    end,
})

ix.bacta.RegisterEffectType("disease_symptom_hallucination", {
    name         = "Psychoactive Disruption",
    description  = "Triggers visual and auditory hallucinations through neurochemical imbalance.",
    color        = Color(180, 80, 200),
    isSideEffect = true,
    format = function(eff)
        return string.format("Hallucinations (intensity %d%%) for %ds", math.floor((eff.magnitude or 1) * 100), eff.duration or 0)
    end,
})

ix.bacta.RegisterEffectType("disease_symptom_pain", {
    name         = "Nociceptive Amplification",
    description  = "Amplifies pain receptor sensitivity, causing widespread discomfort.",
    color        = Color(220, 60, 60),
    isSideEffect = true,
    format = function(eff)
        return string.format("Pain amplification (%d%%) for %ds", math.floor((eff.magnitude or 1) * 100), eff.duration or 0)
    end,
})

ix.bacta.RegisterEffectType("disease_symptom_weakness", {
    name         = "Myopathic Fatigue",
    description  = "Causes severe muscular weakness and exhaustion.",
    color        = Color(140, 140, 100),
    isSideEffect = true,
    format = function(eff)
        return string.format("Muscular weakness for %ds", eff.duration or 0)
    end,
})

ix.bacta.RegisterEffectType("disease_symptom_confusion", {
    name         = "Cognitive Fog",
    description  = "Impairs cognitive function, causing confusion and disorientation.",
    color        = Color(120, 100, 180),
    isSideEffect = true,
    format = function(eff)
        return string.format("Cognitive impairment for %ds", eff.duration or 0)
    end,
})

ix.bacta.RegisterEffectType("disease_symptom_nausea", {
    name         = "Emetic Response",
    description  = "Triggers severe nausea and potential vomiting.",
    color        = Color(160, 140, 70),
    isSideEffect = true,
    format = function(eff)
        return string.format("Severe nausea for %ds", eff.duration or 0)
    end,
})

ix.bacta.RegisterEffectType("immune_suppress", {
    name         = "Immunosuppression",
    description  = "Weakens the immune system, increasing vulnerability to infections.",
    color        = Color(200, 100, 100),
    isSideEffect = true,
    format = function(eff)
        return string.format("Immune system suppressed (%d%%) for %ds", math.floor((eff.magnitude or 1) * 100), eff.duration or 0)
    end,
})

ix.bacta.RegisterEffectType("contagion_amplify", {
    name         = "Contagion Amplification",
    description  = "Increases the transmission rate of any active diseases.",
    color        = Color(220, 40, 40),
    isSideEffect = true,
    format = function(eff)
        return string.format("Contagion rate increased %d%% for %ds", math.floor((eff.magnitude or 1) * 100), eff.duration || 0)
    end,
})

ix.bacta.RegisterEffectType("random_extreme_effect", {
    name         = "Mutagenic Chaos",
    description  = "Completely unpredictable effect. Could heal, harm, cure, or kill.",
    color        = Color(200, 100, 255),
    isSideEffect = false,
    format = function(eff)
        return "MUTAGENIC CHAOS — unpredictable effects"
    end,
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- DISEASE-RELATED REAGENT STRANDS
-- ═══════════════════════════════════════════════════════════════════════════════

-- ─── Active Agents: Disease Treatment ────────────────────────────────────────

ix.bacta.RegisterStrand("act_antiviral_compound", {
    name          = "Retrovirin-K (Antiviral)",
    category      = "active",
    description   = "Broad-acting reverse transcriptase inhibitor. Disrupts viral replication in actively infected cells. Treats viral infections when synthesised at sufficient potency.",
    cost_weight   = 7,
    potency_mod   = 1.1,
    stability_mod = -5,
    effects       = {
        {type = "disease_treat", magnitude = 1.0, duration = 0, immediate = true, disease_category = "antiviral"},
        {type = "heal_hp", magnitude = 5, duration = 0, immediate = true},
    },
    -- Antiviral metabolite buildup causes hepatic strain
    tail_effect   = "tail_hepatic_load",
    tail_delay    = 15,
    tail_duration = 12,
    tail_severity = "low",
    adjacency = {
        bonus   = {"act_immunogenic_primer", "act_broad_spectrum_agent"},
        penalty = {"act_pathogen_culture"},
    },
    pool_rarity = "uncommon",
})

ix.bacta.RegisterStrand("act_antibiotic_compound", {
    name          = "Bactacillin-\206\169 (Antibiotic)",
    category      = "active",
    description   = "Synthetic peptidoglycan disruption agent. Destroys bacterial cell membranes and halts reproduction. Effective against bacterial infections.",
    cost_weight   = 6,
    potency_mod   = 1.0,
    stability_mod = -3,
    effects       = {
        {type = "disease_treat", magnitude = 1.0, duration = 0, immediate = true, disease_category = "antibiotic"},
        {type = "heal_hp", magnitude = 5, duration = 0, immediate = true},
    },
    -- Antibiotic residue stresses the metabolism
    tail_effect   = "tail_metabolic_crash",
    tail_delay    = 12,
    tail_duration = 8,
    tail_severity = "low",
    adjacency = {
        bonus   = {"act_broad_spectrum_agent"},
        penalty = {"act_pathogen_culture"},
    },
    pool_rarity = "uncommon",
})

ix.bacta.RegisterStrand("act_neuro_stabiliser", {
    name          = "Synaprex-5 (Neuro-Stabiliser)",
    category      = "active",
    description   = "Selective serotonin and dopamine modulator. Stabilises aberrant neural signalling patterns. Treats psychological conditions including psychosis and panic disorders.",
    cost_weight   = 8,
    potency_mod   = 1.15,
    stability_mod = -5,
    effects       = {
        {type = "disease_treat", magnitude = 1.0, duration = 0, immediate = true, disease_category = "antipsychotic"},
        {type = "disease_treat", magnitude = 1.0, duration = 0, immediate = true, disease_category = "antianxiety"},
        {type = "buff_focus", magnitude = 0.1, duration = 20, immediate = false},
    },
    -- Neural stabilisation causes synaptic rebound on clearance
    tail_effect   = "tail_synaptic_rebound",
    tail_delay    = 10,
    tail_duration = 8,
    tail_severity = "moderate",
    adjacency = {
        bonus   = {"stab_chem_neutral"},
        penalty = {"act_pathogen_culture", "act_adrenaline_syn"},
    },
    pool_rarity = "uncommon",
})

ix.bacta.RegisterStrand("act_broad_spectrum_agent", {
    name          = "Omnicidin-AG (Broad-Spectrum)",
    category      = "active",
    description   = "Universal anti-pathogenic compound derived from engineered bacteriophages. Treats all infection types at reduced potency. The cellular bombardment taxes the patient's metabolism.",
    cost_weight   = 9,
    potency_mod   = 0.85,
    stability_mod = -8,
    effects       = {
        {type = "disease_treat", magnitude = 0.7, duration = 0, immediate = true, disease_category = "broad_spectrum"},
    },
    -- Universal agent is metabolically expensive
    tail_effect   = "tail_hepatic_load",
    tail_delay    = 10,
    tail_duration = 15,
    tail_severity = "moderate",
    adjacency = {
        bonus   = {"act_antiviral_compound", "act_antibiotic_compound"},
        penalty = {},
    },
    pool_rarity = "rare",
})

ix.bacta.RegisterStrand("act_immunogenic_primer", {
    name          = "Immunex-V (Immunogenic Primer)",
    category      = "active",
    description   = "Attenuated antigen presentation complex. Primes the adaptive immune system to recognise and neutralise specific pathogens. When resonating with treatment compounds, can produce lasting immunity.",
    cost_weight   = 10,
    potency_mod   = 1.2,
    stability_mod = -10,
    effects       = {
        {type = "disease_suppress", magnitude = 1, duration = 60, immediate = false},
    },
    -- Immune priming causes transient adrenal response
    tail_effect   = "tail_adrenal_dump",
    tail_delay    = 8,
    tail_duration = 10,
    tail_severity = "low",
    adjacency = {
        bonus   = {"act_antiviral_compound"},
        penalty = {"act_pathogen_culture"},
    },
    pool_rarity = "rare",
})

-- ─── Active Agent: Bioweapon ─────────────────────────────────────────────────

ix.bacta.RegisterStrand("act_pathogen_culture", {
    name          = "Pathogen-X Culture",
    category      = "active",
    description   = "Live attenuated pathogen culture in stabilised suspension. Extremely volatile. Introduces pathogenic contamination into the compound. Handle with extreme caution.",
    cost_weight   = 4,
    potency_mod   = 0.8,
    stability_mod = -15,
    effects       = {
        {type = "disease_infect", magnitude = 1, duration = 0, immediate = true, disease_target = "random"},
    },
    -- Pathogen exposure risks delayed secondary infection
    tail_effect   = "tail_pathogenic_reaction",
    tail_delay    = 15,
    tail_duration = 5,
    tail_severity = "high",
    adjacency = {
        bonus   = {},
        penalty = {"act_antiviral_compound", "act_antibiotic_compound", "act_neuro_stabiliser", "act_immunogenic_primer"},
    },
    pool_rarity = "rare",
})

-- ─── Modifier: Viral Vector ─────────────────────────────────────────────────

ix.bacta.RegisterStrand("mod_viral_vector", {
    name          = "Viral Vector Modifier",
    category      = "modifier",
    description   = "Repackages the compound delivery mechanism using a modified viral capsid. Enhances disease-targeting efficacy through adjacency with pathogenic treatment strands, but introduces vascular instability.",
    cost_weight   = 5,
    potency_mod   = 1.0,
    stability_mod = -12,
    effects       = {},
    -- Viral shell fragments cause immune reaction
    tail_effect   = "tail_vascular_spike",
    tail_delay    = 10,
    tail_duration = 6,
    tail_severity = "moderate",
    adjacency = {
        bonus   = {"act_immunogenic_primer"},
        penalty = {},
    },
    pool_rarity = "rare",
})

-- ─── Metaboliser: Pathogen Neutraliser ───────────────────────────────────────

ix.bacta.RegisterStrand("met_pathogen_neutral", {
    name          = "Pathogen Neutraliser",
    category      = "stabiliser",
    subcategory   = "metaboliser",
    description   = "Targeted pathogen deactivation agent. Neutralises residual live pathogens before they can infect. Metabolises pathogenic reaction tails.",
    cost_weight   = 4,
    potency_mod   = 1.0,
    stability_mod = 8,
    effects       = {},
    metabolises   = "tail_pathogenic_reaction",
    met_tail      = {type = "tail_neural_static", delay = 8, duration = 6, severity = "low"},
    pool_rarity   = "uncommon",
    adjacency = {
        bonus   = {"act_pathogen_culture"},
        penalty = {},
    },
})

-- ─── Symptom-Specific Agents ─────────────────────────────────────────────────
-- These strands provide individual disease symptoms without causing full infections.
-- Useful for targeted symptom management or symptom-based bioweapons.

ix.bacta.RegisterStrand("act_pyrogenic_agent", {
    name          = "Pyrexin-7 (Fever Inducer)",
    category      = "active",
    description   = "Synthetic pyrogen that triggers controlled fever response. Useful for therapeutic hyperthermia or as a bioweapon component. Causes sustained elevated body temperature.",
    cost_weight   = 3,
    potency_mod   = 0.9,
    stability_mod = -6,
    effects       = {
        {type = "disease_symptom_fever", magnitude = 0.8, duration = 45, immediate = false},
        {type = "debuff_stamina", magnitude = 0.15, duration = 45, immediate = false},
    },
    tail_effect   = "tail_metabolic_crash",
    tail_delay    = 10,
    tail_duration = 8,
    tail_severity = "low",
    adjacency = {
        bonus   = {"act_pathogen_culture"},
        penalty = {"act_antiviral_compound", "act_antibiotic_compound"},
    },
    pool_rarity = "common",
})

ix.bacta.RegisterStrand("act_hallucinogen", {
    name          = "Neuroclysm-X (Psychoactive)",
    category      = "active",
    description   = "Potent psychoactive compound that disrupts sensory processing centers. Causes vivid hallucinations and perceptual distortions. Extremely destabilising.",
    cost_weight   = 6,
    potency_mod   = 1.3,
    stability_mod = -18,
    effects       = {
        {type = "disease_symptom_hallucination", magnitude = 1.2, duration = 60, immediate = false},
        {type = "disease_symptom_confusion", magnitude = 0.8, duration = 50, immediate = false},
        {type = "debuff_focus", magnitude = 0.4, duration = 60, immediate = false},
    },
    tail_effect   = "tail_synaptic_rebound",
    tail_delay    = 8,
    tail_duration = 15,
    tail_severity = "high",
    adjacency = {
        bonus   = {"act_pathogen_culture"},
        penalty = {"act_neuro_stabiliser", "stab_chem_neutral"},
    },
    pool_rarity = "rare",
})

ix.bacta.RegisterStrand("act_nociceptor_amp", {
    name          = "Algex-9 (Pain Amplifier)",
    category      = "active",
    description   = "Nerve agent that sensitises nociceptors, amplifying pain perception. Can be used for interrogation or as a torture compound. Causes excruciating discomfort.",
    cost_weight   = 5,
    potency_mod   = 1.1,
    stability_mod = -12,
    effects       = {
        {type = "disease_symptom_pain", magnitude = 1.5, duration = 40, immediate = true},
        {type = "debuff_stamina", magnitude = 0.25, duration = 40, immediate = false},
        {type = "damage_hp", magnitude = 3, duration = 40, immediate = false, dot = true},
    },
    tail_effect   = "tail_neural_static",
    tail_delay    = 12,
    tail_duration = 10,
    tail_severity = "moderate",
    adjacency = {
        bonus   = {},
        penalty = {"act_analgesic", "act_neuro_stabiliser"},
    },
    pool_rarity = "uncommon",
})

ix.bacta.RegisterStrand("act_respiratory_inhibitor", {
    name          = "Pneumotox-K (Respiratory Inhibitor)",
    category      = "active",
    description   = "Bronchial irritant that inflames airways and triggers persistent coughing. Causes respiratory distress and reduced oxygen intake.",
    cost_weight   = 4,
    potency_mod   = 0.95,
    stability_mod = -8,
    effects       = {
        {type = "disease_symptom_cough", magnitude = 1.0, duration = 50, immediate = false},
        {type = "disease_symptom_weakness", magnitude = 0.6, duration = 50, immediate = false},
        {type = "debuff_stamina", magnitude = 0.3, duration = 50, immediate = false},
    },
    tail_effect   = "tail_hepatic_load",
    tail_delay    = 15,
    tail_duration = 8,
    tail_severity = "low",
    adjacency = {
        bonus   = {"act_pathogen_culture", "act_pyrogenic_agent"},
        penalty = {},
    },
    pool_rarity = "common",
})

ix.bacta.RegisterStrand("act_myopathic_agent", {
    name          = "Myolex-4 (Muscle Inhibitor)",
    category      = "active",
    description   = "Neuromuscular blocking agent that causes severe muscular weakness and fatigue. Non-lethal incapacitation compound.",
    cost_weight   = 5,
    potency_mod   = 1.05,
    stability_mod = -10,
    effects       = {
        {type = "disease_symptom_weakness", magnitude = 1.2, duration = 55, immediate = false},
        {type = "debuff_stamina", magnitude = 0.4, duration = 55, immediate = false},
    },
    tail_effect   = "tail_metabolic_crash",
    tail_delay    = 10,
    tail_duration = 12,
    tail_severity = "moderate",
    adjacency = {
        bonus   = {"act_nociceptor_amp"},
        penalty = {"act_adrenaline_syn"},
    },
    pool_rarity = "uncommon",
})

ix.bacta.RegisterStrand("act_emetic_compound", {
    name          = "Vomitix-2 (Emetic Agent)",
    category      = "active",
    description   = "Gastrointestinal irritant that triggers severe nausea and vomiting. Used for purging toxins or as a non-lethal deterrent.",
    cost_weight   = 3,
    potency_mod   = 0.85,
    stability_mod = -5,
    effects       = {
        {type = "disease_symptom_nausea", magnitude = 1.0, duration = 35, immediate = true},
        {type = "debuff_stamina", magnitude = 0.2, duration = 35, immediate = false},
    },
    tail_effect   = "tail_metabolic_crash",
    tail_delay    = 8,
    tail_duration = 6,
    tail_severity = "low",
    adjacency = {
        bonus   = {},
        penalty = {"stab_chem_neutral"},
    },
    pool_rarity = "common",
})

-- ─── Mid-Tier Disease Strands ───────────────────────────────────────────────
-- Moderate-risk disease strands with interesting trade-offs

ix.bacta.RegisterStrand("act_space_plague", {
    name          = "Space Plague Variant",
    category      = "active",
    description   = "Common spacer's ailment causing respiratory distress and fever. Less severe than military bioweapons but still debilitating. Moderate contagion risk.",
    cost_weight   = 5,
    potency_mod   = 1.1,
    stability_mod = -12,
    effects       = {
        {type = "disease_infect", magnitude = 1, duration = 0, immediate = true, disease_target = "space_plague", force = false},
        {type = "disease_symptom_cough", magnitude = 0.8, duration = 50, immediate = false},
        {type = "disease_symptom_fever", magnitude = 0.6, duration = 50, immediate = false},
    },
    tail_effect   = "tail_pathogenic_reaction",
    tail_delay    = 12,
    tail_duration = 8,
    tail_severity = "moderate",
    adjacency = {
        bonus   = {"act_respiratory_inhibitor"},
        penalty = {"act_antiviral_compound"},
    },
    pool_rarity = "uncommon",
})

ix.bacta.RegisterStrand("act_neural_parasite", {
    name          = "Neural Parasite Culture",
    category      = "active",
    description   = "Microscopic organism that infests neural tissue causing confusion, hallucinations, and cognitive decline. Treatable with neuro-stabilisers but resistant to conventional medicine.",
    cost_weight   = 6,
    potency_mod   = 1.2,
    stability_mod = -14,
    effects       = {
        {type = "disease_infect", magnitude = 1, duration = 0, immediate = true, disease_target = "neural_parasite", force = false},
        {type = "disease_symptom_confusion", magnitude = 0.9, duration = 70, immediate = false},
        {type = "debuff_focus", magnitude = 0.3, duration = 70, immediate = false},
    },
    tail_effect   = "tail_synaptic_rebound",
    tail_delay    = 10,
    tail_duration = 10,
    tail_severity = "moderate",
    adjacency = {
        bonus   = {"act_hallucinogen"},
        penalty = {"act_neuro_stabiliser"},
    },
    pool_rarity = "uncommon",
})

ix.bacta.RegisterStrand("act_withering_sickness", {
    name          = "Withering Sickness Agent",
    category      = "active",
    description   = "Degenerative disease causing progressive muscle atrophy and weakness. Slow acting but debilitating over time. Can be halted with proper treatment.",
    cost_weight   = 5,
    potency_mod   = 1.05,
    stability_mod = -11,
    effects       = {
        {type = "disease_infect", magnitude = 1, duration = 0, immediate = true, disease_target = "withering_sickness", force = false},
        {type = "disease_symptom_weakness", magnitude = 0.7, duration = 90, immediate = false},
        {type = "debuff_stamina", magnitude = 0.25, duration = 90, immediate = false},
    },
    tail_effect   = "tail_metabolic_crash",
    tail_delay    = 15,
    tail_duration = 12,
    tail_severity = "moderate",
    adjacency = {
        bonus   = {"act_myopathic_agent"},
        penalty = {"act_antibiotic_compound"},
    },
    pool_rarity = "uncommon",
})

ix.bacta.RegisterStrand("act_anxiety_inducer", {
    name          = "Paniclysm-3 (Anxiety Inducer)",
    category      = "active",
    description   = "Neurochemical agent that triggers severe anxiety and panic responses. Can induce panic disorder with sustained exposure. Countered by anxiolytics.",
    cost_weight   = 4,
    potency_mod   = 1.0,
    stability_mod = -9,
    effects       = {
        {type = "disease_infect", magnitude = 1, duration = 0, immediate = true, disease_target = "panic_disorder", force = false},
        {type = "debuff_focus", magnitude = 0.25, duration = 60, immediate = false},
        {type = "disease_symptom_confusion", magnitude = 0.5, duration = 60, immediate = false},
    },
    tail_effect   = "tail_adrenal_dump",
    tail_delay    = 10,
    tail_duration = 10,
    tail_severity = "low",
    adjacency = {
        bonus   = {"act_hallucinogen"},
        penalty = {"act_neuro_stabiliser"},
    },
    pool_rarity = "common",
})

ix.bacta.RegisterStrand("act_toxin_synthesizer", {
    name          = "Toxin Synthesizer Bacteria",
    category      = "active",
    description   = "Engineered bacteria that colonizes the patient and produces mild toxins. Causes ongoing low-level damage and nausea. Self-sustaining infection.",
    cost_weight   = 5,
    potency_mod   = 1.1,
    stability_mod = -10,
    effects       = {
        {type = "disease_infect", magnitude = 1, duration = 0, immediate = true, disease_target = "toxin_producing_bacteria", force = false},
        {type = "disease_symptom_nausea", magnitude = 0.8, duration = 60, immediate = false},
        {type = "damage_hp", magnitude = 10, duration = 60, immediate = false, dot = true},
    },
    tail_effect   = "tail_hepatic_load",
    tail_delay    = 12,
    tail_duration = 10,
    tail_severity = "low",
    adjacency = {
        bonus   = {"act_pathogen_culture"},
        penalty = {"act_antibiotic_compound"},
    },
    pool_rarity = "uncommon",
})

-- ─── Specific Disease Inducers ───────────────────────────────────────────────
--Star Wars themed specific disease strands (legendary tier)

ix.bacta.RegisterStrand("act_rakghoul_strain", {
    name          = "Rakghoul Plague Strain",
    category      = "active",
    description   = "Isolated viral strain from the legendary Rakghoul pathogen. Highly aggressive necrotic virus. Extremely dangerous and unstable. Infects with a severe viral disease.",
    cost_weight   = 8,
    potency_mod   = 1.4,
    stability_mod = -25,
    effects       = {
        {type = "disease_infect", magnitude = 1, duration = 0, immediate = true, disease_target = "rakghoul_plague", force = true},
        {type = "disease_worsen", magnitude = 1, duration = 0, immediate = true},
        {type = "damage_hp", magnitude = 10, duration = 0, immediate = true},
    },
    tail_effect   = "tail_pathogenic_reaction",
    tail_delay    = 5,
    tail_duration = 10,
    tail_severity = "extreme",
    adjacency = {
        bonus   = {"mod_viral_vector"},
        penalty = {"act_antiviral_compound", "act_broad_spectrum_agent", "act_immunogenic_primer"},
    },
    pool_rarity = "legendary",
})

ix.bacta.RegisterStrand("act_krytos_virus", {
    name          = "Krytos Virus Culture",
    category      = "active",
    description   = "Weaponised viral agent historically used for biological warfare. Species-specific targeting. Causes rapid onset respiratory failure and systemic infection.",
    cost_weight   = 7,
    potency_mod   = 1.3,
    stability_mod = -22,
    effects       = {
        {type = "disease_infect", magnitude = 1, duration = 0, immediate = true, disease_target = "krytos_virus", force = true},
        {type = "disease_symptom_cough", magnitude = 1.5, duration = 60, immediate = false},
        {type = "disease_symptom_fever", magnitude = 1.2, duration = 60, immediate = false},
    },
    tail_effect   = "tail_vascular_spike",
    tail_delay    = 8,
    tail_duration = 12,
    tail_severity = "high",
    adjacency = {
        bonus   = {"act_pathogen_culture", "mod_viral_vector"},
        penalty = {"act_antiviral_compound", "act_broad_spectrum_agent"},
    },
    pool_rarity = "legendary",
})

ix.bacta.RegisterStrand("act_bloodburn_pathogen", {
    name          = "Bloodburn Pathogen",
    category      = "active",
    description   = "Haemorrhagic fever virus causing internal bleeding and vascular damage. Extremely lethal if untreated. Induces bloodburn disease.",
    cost_weight   = 7,
    potency_mod   = 1.25,
    stability_mod = -20,
    effects       = {
        {type = "disease_infect", magnitude = 1, duration = 0, immediate = true, disease_target = "bloodburn", force = true},
        {type = "disease_symptom_fever", magnitude = 1.5, duration = 70, immediate = false},
        {type = "damage_hp", magnitude = 15, duration = 60, immediate = false, dot = true},
    },
    tail_effect   = "tail_vascular_spike",
    tail_delay    = 10,
    tail_duration = 15,
    tail_severity = "extreme",
    adjacency = {
        bonus   = {"act_pathogen_culture"},
        penalty = {"act_antiviral_compound", "act_broad_spectrum_agent"},
    },
    pool_rarity = "legendary",
})

ix.bacta.RegisterStrand("act_neuro_plague", {
    name          = "Neuroplague Variant-7",
    category      = "active",
    description   = "Synthetic prion-like pathogen targeting neural tissue. Causes progressive cognitive decline, hallucinations, and psychological breakdown. Extremely difficult to treat.",
    cost_weight   = 8,
    potency_mod   = 1.35,
    stability_mod = -23,
    effects       = {
        {type = "disease_infect", magnitude = 1, duration = 0, immediate = true, disease_target = "neuroplague", force = true},
        {type = "disease_symptom_hallucination", magnitude = 1.3, duration = 80, immediate = false},
        {type = "disease_symptom_confusion", magnitude = 1.5, duration = 80, immediate = false},
        {type = "debuff_focus", magnitude = 0.5, duration = 80, immediate = false},
    },
    tail_effect   = "tail_synaptic_rebound",
    tail_delay    = 6,
    tail_duration = 20,
    tail_severity = "extreme",
    adjacency = {
        bonus   = {"act_hallucinogen"},
        penalty = {"act_neuro_stabiliser", "act_broad_spectrum_agent"},
    },
    pool_rarity = "legendary",
})

ix.bacta.RegisterStrand("act_cyberia_psychosis", {
    name          = "Cyberia Psychosis Inducer",
    category      = "active",
    description   = "Experimental psychoactive compound that triggers acute paranoid psychosis. Causes severe mental instability, hallucinations, and violent tendencies.",
    cost_weight   = 6,
    potency_mod   = 1.2,
    stability_mod = -16,
    effects       = {
        {type = "disease_infect", magnitude = 1, duration = 0, immediate = true, disease_target = "cyberia_psychosis", force = false},
        {type = "disease_symptom_hallucination", magnitude = 1.0, duration = 90, immediate = false},
        {type = "disease_symptom_confusion", magnitude = 1.2, duration = 90, immediate = false},
    },
    tail_effect   = "tail_synaptic_rebound",
    tail_delay    = 12,
    tail_duration = 18,
    tail_severity = "high",
    adjacency = {
        bonus   = {"act_hallucinogen"},
        penalty = {"act_neuro_stabiliser"},
    },
    pool_rarity = "rare",
})

ix.bacta.RegisterStrand("act_corellian_plague", {
    name          = "Corellian Plague Strain",
    category      = "active",
    description   = "Bacterial plague variant causing rapid onset sepsis and multi-organ failure. Historically responsible for massive casualties. Highly contagious.",
    cost_weight   = 7,
    potency_mod   = 1.3,
    stability_mod = -21,
    effects       = {
        {type = "disease_infect", magnitude = 1, duration = 0, immediate = true, disease_target = "corellian_plague", force = true},
        {type = "disease_symptom_fever", magnitude = 1.4, duration = 65, immediate = false},
        {type = "disease_symptom_weakness", magnitude = 1.3, duration = 65, immediate = false},
        {type = "contagion_amplify", magnitude = 2.0, duration = 65, immediate = false},
    },
    tail_effect   = "tail_pathogenic_reaction",
    tail_delay    = 7,
    tail_duration = 12,
    tail_severity = "extreme",
    adjacency = {
        bonus   = {"act_pathogen_culture"},
        penalty = {"act_antibiotic_compound", "act_broad_spectrum_agent"},
    },
    pool_rarity = "legendary",
})

-- ─── Extreme High-Risk Compounds ─────────────────────────────────────────────

ix.bacta.RegisterStrand("act_panacea_omega", {
    name          = "Panacea-Ω (Ultimate Cure)",
    category      = "active",
    description   = "Theoretical universal cure derived from ancient Rakatan biotechnology. Purges all diseases and regenerates damaged tissue. Catastrophically unstable — synthesis failure is almost guaranteed.",
    cost_weight   = 15,
    potency_mod   = 2.5,
    stability_mod = -40,
    effects       = {
        {type = "disease_cure_all", magnitude = 1, duration = 0, immediate = true},
        {type = "heal_hp", magnitude = 50, duration = 0, immediate = true},
        {type = "buff_regen", magnitude = 0.5, duration = 120, immediate = false},
    },
    tail_effect   = "tail_cascade_failure",
    tail_delay    = 5,
    tail_duration = 20,
    tail_severity = "extreme",
    adjacency = {
        bonus   = {"act_broad_spectrum_agent", "act_immunogenic_primer", "stab_chem_neutral"},
        penalty = {"act_pathogen_culture", "cat_entropy_seed"},
    },
    pool_rarity = "legendary",
})

ix.bacta.RegisterStrand("act_genetic_mutagen", {
    name          = "Mutagenic Catalyst-X12",
    category      = "active",
    description   = "Unstable genetic resequencing agent. Unpredictable effects ranging from miraculous regeneration to catastrophic cellular collapse. Roll the dice.",
    cost_weight   = 10,
    potency_mod   = 1.8,
    stability_mod = -35,
    effects       = {
        -- Effects are randomised on application
        {type = "random_extreme_effect", magnitude = 2.0, duration = 0, immediate = true},
    },
    tail_effect   = "tail_genetic_instability",
    tail_delay    = 3,
    tail_duration = 30,
    tail_severity = "extreme",
    adjacency = {
        bonus   = {},
        penalty = {"stab_chem_neutral", "stab_entropy_sink"},
    },
    pool_rarity = "legendary",
})

ix.bacta.RegisterStrand("act_necrotic_agent", {
    name          = "Necrotoxin-13 (Tissue Destroyer)",
    category      = "active",
    description   = "Pure necrotic compound that causes rapid cellular death. No therapeutic value whatsoever. Designed solely as a lethal poison. Causes massive damage.",
    cost_weight   = 6,
    potency_mod   = 1.5,
    stability_mod = -15,
    effects       = {
        {type = "damage_hp", magnitude = 40, duration = 0, immediate = true},
        {type = "damage_hp", magnitude = 30, duration = 45, immediate = false, dot = true},
        {type = "disease_symptom_pain", magnitude = 2.0, duration = 45, immediate = true},
    },
    tail_effect   = "tail_necrotic_cascade",
    tail_delay    = 8,
    tail_duration = 15,
    tail_severity = "extreme",
    adjacency = {
        bonus   = {"act_nociceptor_amp", "cat_potency_amp"},
        penalty = {"act_bacta_base", "act_dermal_regen"},
    },
    pool_rarity = "rare",
})

-- ─── Bioweapon-Focused Strands ───────────────────────────────────────────────

ix.bacta.RegisterStrand("act_multi_pathogen", {
    name          = "Multi-Pathogen Carrier Vector",
    category      = "active",
    description   = "Engineered delivery system carrying multiple active pathogens simultaneously. Infects the target with several diseases at once. Biological weapon of mass destruction.",
    cost_weight   = 9,
    potency_mod   = 1.6,
    stability_mod = -30,
    effects       = {
        {type = "disease_infect", magnitude = 1, duration = 0, immediate = true, disease_target = "random", force = true},
        {type = "disease_infect", magnitude = 1, duration = 0, immediate = true, disease_target = "random", force = true},
        {type = "disease_infect", magnitude = 1, duration = 0, immediate = true, disease_target = "random_severe", force = true},
        {type = "immune_suppress", magnitude = 0.8, duration = 120, immediate = false},
    },
    tail_effect   = "tail_pathogenic_reaction",
    tail_delay    = 3,
    tail_duration = 20,
    tail_severity = "extreme",
    adjacency = {
        bonus   = {"act_pathogen_culture", "mod_viral_vector", "act_immune_destroyer"},
        penalty = {"act_antiviral_compound", "act_antibiotic_compound", "act_broad_spectrum_agent"},
    },
    pool_rarity = "legendary",
})

ix.bacta.RegisterStrand("act_immune_destroyer", {
    name          = "Immunophage-9 (Immune Destroyer)",
    category      = "active",
    description   = "Targeted compound that selectively destroys white blood cells and immune system components. Leaves the victim completely vulnerable to any pathogen.",
    cost_weight   = 7,
    potency_mod   = 1.4,
    stability_mod = -18,
    effects       = {
        {type = "immune_suppress", magnitude = 1.5, duration = 180, immediate = true},
        {type = "disease_worsen", magnitude = 2, duration = 0, immediate = true},
        {type = "disease_symptom_weakness", magnitude = 1.0, duration = 180, immediate = false},
    },
    tail_effect   = "tail_pathogenic_reaction",
    tail_delay    = 10,
    tail_duration = 15,
    tail_severity = "high",
    adjacency = {
        bonus   = {"act_pathogen_culture", "act_multi_pathogen"},
        penalty = {"act_immunogenic_primer", "act_broad_spectrum_agent"},
    },
    pool_rarity = "rare",
})

ix.bacta.RegisterStrand("act_contagion_enhancer", {
    name          = "Contagion Amplifier Strain",
    category      = "active",
    description   = "Mutagenic modifier that enhances viral transmission rates. Makes any active diseases highly contagious. Creates epidemic scenarios.",
    cost_weight   = 6,
    potency_mod   = 1.2,
    stability_mod = -14,
    effects       = {
        {type = "contagion_amplify", magnitude = 3.0, duration = 240, immediate = true},
        {type = "disease_worsen", magnitude = 1, duration = 0, immediate = true},
    },
    tail_effect   = "tail_pathogenic_reaction",
    tail_delay    = 15,
    tail_duration = 10,
    tail_severity = "moderate",
    adjacency = {
        bonus   = {"act_pathogen_culture", "mod_viral_vector", "act_multi_pathogen"},
        penalty = {"act_immunogenic_primer"},
    },
    pool_rarity = "rare",
})

ix.bacta.RegisterStrand("mod_bioweapon_catalyst", {
    name          = "Bioweapon Catalyst",
    category      = "modifier",
    description   = "Specialized catalyst designed to amplify pathogenic and negative effects. Converts therapeutic compounds into weapons. Reverses beneficial disease effects into harmful ones.",
    cost_weight   = 8,
    potency_mod   = 1.5,
    stability_mod = -25,
    effects       = {},
    tail_effect   = "tail_pathogenic_reaction",
    tail_delay    = 5,
    tail_duration = 15,
    tail_severity = "high",
    adjacency = {
        bonus   = {"act_pathogen_culture", "act_multi_pathogen", "act_necrotic_agent", "act_nociceptor_amp"},
        penalty = {"act_antiviral_compound", "act_antibiotic_compound", "act_neuro_stabiliser", "act_bacta_base"},
    },
    pool_rarity = "legendary",
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- RESONANCE PATTERN SYSTEM (v3.0)
-- Multi-strand combination effects that trigger when specific strands are
-- present together in a sequence. Resonance effects produce bonus effects
-- beyond what any single strand provides. Hidden patterns are discoverable
-- only through experimentation.
-- ═══════════════════════════════════════════════════════════════════════════════

ix.bacta.ResonancePatterns = ix.bacta.ResonancePatterns or {}

--- Register a resonance pattern.
-- @param id string Unique pattern identifier
-- @param data table Pattern definition containing:
--   name (string), description (string),
--   required (table: array of strand IDs that must ALL be present),
--   requireAny (table: array of strand IDs where at least ONE must be present),
--   requireAdjacent (bool: if true, required strands must be adjacent),
--   hidden (bool: undiscovered until triggered),
--   effects (function(sequence, existingEffects) → table of bonus effects),
--   stabilityBonus (number),
--   notification (string: flavour text shown on trigger)
function ix.bacta.RegisterResonancePattern(id, data)
    data.id = id
    ix.bacta.ResonancePatterns[id] = data
end

-- ─── Pattern Definitions ─────────────────────────────────────────────────────

ix.bacta.RegisterResonancePattern("immunological_resonance", {
    name        = "Immunological Resonance",
    description = "Antiviral + Immunogenic Primer combine to produce lasting immunity.",
    required    = {"act_antiviral_compound", "act_immunogenic_primer"},
    requireAdjacent = true,
    hidden      = false,
    effects     = function(sequence, existingEffects)
        local viralDiseases = ix.bacta.GetDiseasesByType("viral")
        if (#viralDiseases > 0) then
            local target = viralDiseases[math.random(#viralDiseases)]
            return {
                {type = "disease_vaccinate", magnitude = 1, duration = 0, immediate = true, disease_target = target},
            }
        end
        return {}
    end,
    stabilityBonus = 5,
    notification   = "A resonance emerges — the antiviral and immunogen synchronise, producing an immune response.",
})

ix.bacta.RegisterResonancePattern("dual_spectrum_resonance", {
    name        = "Dual-Spectrum Resonance",
    description = "Antibiotic + Antiviral produce a combined bacterial and viral treatment.",
    required    = {"act_antiviral_compound", "act_antibiotic_compound"},
    requireAdjacent = false,
    hidden      = false,
    effects     = function(sequence, existingEffects)
        -- Boost existing treatment magnitudes by 30% in-place
        for _, eff in ipairs(existingEffects) do
            if (eff.type == "disease_treat") then
                eff.magnitude = math.Round((eff.magnitude or 1.0) * 1.30, 2)
            end
        end
        return {} -- modifications applied in-place
    end,
    stabilityBonus = 3,
    notification   = "The antiviral and antibiotic resonate, amplifying across pathogen spectrums.",
})

ix.bacta.RegisterResonancePattern("full_spectrum_resonance", {
    name        = "Full-Spectrum Resonance",
    description = "All three treatment types combine to produce a universal cure.",
    required    = {"act_antiviral_compound", "act_antibiotic_compound", "act_neuro_stabiliser"},
    requireAdjacent = false,
    hidden      = true,
    effects     = function(sequence, existingEffects)
        return {
            {type = "disease_cure_all", magnitude = 1, duration = 0, immediate = true},
        }
    end,
    stabilityBonus = -10,
    notification   = "A profound resonance cascades through the compound — every pathogenic agent is neutralised.",
})

ix.bacta.RegisterResonancePattern("weaponised_pathogen", {
    name        = "Weaponised Pathogen",
    description = "Pathogen culture amplified by a catalyst becomes a targeted bioweapon.",
    required    = {"act_pathogen_culture"},
    requireAny  = {"cat_potency_amp", "cat_rapid_react"},
    requireAdjacent = false,
    hidden      = false,
    effects     = function(sequence, existingEffects)
        -- Upgrade the disease_infect effect: force-infect with a severe disease
        for _, eff in ipairs(existingEffects) do
            if (eff.type == "disease_infect") then
                eff.force = true
                eff.disease_target = "random_severe"
            end
        end
        return {
            {type = "disease_worsen", magnitude = 2, duration = 0, immediate = true},
        }
    end,
    stabilityBonus = -20,
    notification   = "The pathogen culture erupts in resonance with the catalyst — a weaponised strain emerges.",
})

ix.bacta.RegisterResonancePattern("genetic_cure_resonance", {
    name        = "Genetic Cure Resonance",
    description = "Genomic Repair + disease treatment strands produce an enhanced genetic-level cure.",
    required    = {"act_genomic_rep"},
    requireAny  = {"act_antiviral_compound", "act_antibiotic_compound", "act_neuro_stabiliser"},
    requireAdjacent = false,
    hidden      = true,
    effects     = function(sequence, existingEffects)
        -- Double the magnitude of all disease_treat effects
        for _, eff in ipairs(existingEffects) do
            if (eff.type == "disease_treat") then
                eff.magnitude = math.Round((eff.magnitude or 1.0) * 2.0, 2)
            end
        end

        -- Add a direct cure matching the treatment strand present
        for _, strandID in ipairs(sequence) do
            if (strandID == "act_antiviral_compound") then
                return {{type = "disease_cure", magnitude = 1, duration = 0, immediate = true, disease_target = "viral"}}
            elseif (strandID == "act_antibiotic_compound") then
                return {{type = "disease_cure", magnitude = 1, duration = 0, immediate = true, disease_target = "bacterial"}}
            elseif (strandID == "act_neuro_stabiliser") then
                return {{type = "disease_cure", magnitude = 1, duration = 0, immediate = true, disease_target = "psychological"}}
            end
        end

        return {}
    end,
    stabilityBonus = 5,
    notification   = "The genomic repair strand resonates with the treatment agent — a genetic-level cure takes form.",
})

ix.bacta.RegisterResonancePattern("broad_amplification", {
    name        = "Broad Amplification Resonance",
    description = "Broad-spectrum agent amplified by an immunogenic primer for enhanced pathogen coverage.",
    required    = {"act_broad_spectrum_agent", "act_immunogenic_primer"},
    requireAdjacent = true,
    hidden      = true,
    effects     = function(sequence, existingEffects)
        -- Upgrade broad_spectrum treatment magnitude
        for _, eff in ipairs(existingEffects) do
            if (eff.type == "disease_treat" and eff.disease_category == "broad_spectrum") then
                eff.magnitude = math.Round((eff.magnitude or 0.7) * 1.50, 2)
            end
        end
        return {
            {type = "disease_suppress", magnitude = 1, duration = 90, immediate = false},
        }
    end,
    stabilityBonus = 0,
    notification   = "The broad-spectrum agent and immunogen synchronise — a resilient anti-pathogenic field forms.",
})

ix.bacta.RegisterResonancePattern("perfect_bioweapon", {
    name        = "Perfect Bioweapon Resonance",
    description = "Multi-pathogen carrier + Immune destroyer + Contagion enhancer = Ultimate biological weapon.",
    required    = {"act_multi_pathogen", "act_immune_destroyer", "act_contagion_enhancer"},
    requireAdjacent = false,
    hidden      = true,
    effects     = function(sequence, existingEffects)
        -- Amplify all negative effects
        for _, eff in ipairs(existingEffects) do
            if (eff.type == "disease_infect" or eff.type == "disease_worsen" or 
                eff.type == "immune_suppress" or eff.type == "contagion_amplify") then
                eff.magnitude = math.Round((eff.magnitude or 1.0) * 1.5, 2)
                if (eff.duration and eff.duration > 0) then
                    eff.duration = math.Round(eff.duration * 1.3)
                end
            end
        end
        return {
            {type = "disease_infect", magnitude = 1, duration = 0, immediate = true, disease_target = "random_severe", force = true},
            {type = "disease_infect", magnitude = 1, duration = 0, immediate = true, disease_target = "random_severe", force = true},
        }
    end,
    stabilityBonus = -30,
    notification   = "A terrifying resonance emerges — you have created the perfect plague.",
})

ix.bacta.RegisterResonancePattern("symptom_cascade", {
    name        = "Symptom Cascade",
    description = "Multiple symptom inducers combine to create overwhelming systemic failure.",
    requireAny  = {"act_pyrogenic_agent", "act_hallucinogen", "act_nociceptor_amp", "act_respiratory_inhibitor", "act_myopathic_agent"},
    required    = {},
    requireAdjacent = false,
    hidden      = false,
    effects     = function(sequence, existingEffects)
        -- Count symptom strands
        local symptomStrands = {
            act_pyrogenic_agent = true,
            act_hallucinogen = true,
            act_nociceptor_amp = true,
            act_respiratory_inhibitor = true,
            act_myopathic_agent = true,
            act_emetic_compound = true,
        }
        
        local count = 0
        for _, id in ipairs(sequence) do
            if (symptomStrands[id]) then count = count + 1 end
        end
        
        -- If 3+ symptom strands, trigger cascade
        if (count >= 3) then
            -- Amplify all symptom effects
            for _, eff in ipairs(existingEffects) do
                if (string.find(eff.type, "disease_symptom_") == 1) then
                    eff.magnitude = math.Round((eff.magnitude or 1.0) * 1.4, 2)
                    if (eff.duration) then
                        eff.duration = math.Round(eff.duration * 1.2)
                    end
                end
            end
            
            return {
                {type = "damage_hp", magnitude = 15, duration = 60, immediate = false, dot = true},
            }
        end
        
        return {}
    end,
    stabilityBonus = -15,
    notification   = "The symptoms resonate in a devastating cascade — multiple systems are failing.",
})

ix.bacta.RegisterResonancePattern("necrotic_plague", {
    name        = "Necrotic Plague Resonance",
    description = "Necrotic agent combined with pathogen creates a disease that causes tissue death.",
    required    = {"act_necrotic_agent"},
    requireAny  = {"act_pathogen_culture", "act_multi_pathogen", "act_rakghoul_strain", "act_bloodburn_pathogen"},
    requireAdjacent = false,
    hidden      = true,
    effects     = function(sequence, existingEffects)
        -- Convert disease infections into more severe versions
        for _, eff in ipairs(existingEffects) do
            if (eff.type == "disease_infect") then
                eff.force = true
                eff.disease_target = "random_severe"
            end
            if (eff.type == "damage_hp") then
                eff.magnitude = math.Round((eff.magnitude or 1) * 1.5, 2)
            end
        end
        
        return {
            {type = "disease_worsen", magnitude = 2, duration = 0, immediate = true},
            {type = "disease_symptom_pain", magnitude = 1.5, duration = 90, immediate = true},
        }
    end,
    stabilityBonus = -25,
    notification   = "Necrotic energy fuses with living pathogen — a flesh-eating plague is born.",
})

ix.bacta.RegisterResonancePattern("psychotic_break", {
    name        = "Psychotic Break Resonance",
    description = "Hallucinogen + Neuroplague create complete mental breakdown.",
    required    = {"act_hallucinogen"},
    requireAny  = {"act_neuro_plague", "act_cyberia_psychosis"},
    requireAdjacent = true,
    hidden      = true,
    effects     = function(sequence, existingEffects)
        for _, eff in ipairs(existingEffects) do
            if (eff.type == "disease_symptom_hallucination" or eff.type == "disease_symptom_confusion") then
                eff.magnitude = math.Round((eff.magnitude or 1.0) * 2.0, 2)
                if (eff.duration) then
                    eff.duration = math.Round(eff.duration * 1.5)
                end
            end
        end
        
        return {
            {type = "debuff_focus", magnitude = 0.8, duration = 120, immediate = false},
        }
    end,
    stabilityBonus = -20,
    notification   = "Neural pathways collapse under the combined assault — reality shatters.",
})

ix.bacta.RegisterResonancePattern("catalyst_inversion", {
    name        = "Catalyst Inversion",
    description = "Bioweapon catalyst inverts cure compounds into diseases.",
    required    = {"mod_bioweapon_catalyst"},
    requireAny  = {"act_antiviral_compound", "act_antibiotic_compound", "act_neuro_stabiliser"},
    requireAdjacent = false,
    hidden      = false,
    effects     = function(sequence, existingEffects)
        -- Remove all disease_treat effects and replace with disease_infect
        local treatmentCount = 0
        for i = #existingEffects, 1, -1 do
            if (existingEffects[i].type == "disease_treat") then
                treatmentCount = treatmentCount + 1
                table.remove(existingEffects, i)
            end
        end
        
        -- Add infections based on removed treatments
        local newEffects = {}
        for i = 1, treatmentCount do
            newEffects[#newEffects + 1] = {
                type = "disease_infect",
                magnitude = 1,
                duration = 0,
                immediate = true,
                disease_target = "random",
                force = false,
            }
        end
        
        return newEffects
    end,
    stabilityBonus = -20,
    notification   = "The bioweapon catalyst inverts the cure — medicine becomes poison.",
})

ix.bacta.RegisterResonancePattern("panacea_miracle", {
    name        = "Panacea Miracle",
    description = "Panacea-Ω stabilised through perfect synthesis conditions.",
    required    = {"act_panacea_omega", "stab_chem_neutral", "act_immunogenic_primer"},
    requireAdjacent = false,
    hidden      = true,
    effects     = function(sequence, existingEffects)
        -- If this resonance triggers, the panacea actually worked!
        -- Boost all healing effects
        for _, eff in ipairs(existingEffects) do
            if (eff.type == "heal_hp" or eff.type == "buff_regen") then
                eff.magnitude = math.Round((eff.magnitude or 1) * 1.5, 2)
            end
        end
        
        return {
            {type = "buff_armor", magnitude = 25, duration = 180, immediate = false},
            {type = "buff_focus", magnitude = 0.3, duration = 180, immediate = false},
        }
    end,
    stabilityBonus = 15,
    notification   = "Against all odds, the Panacea stabilises — a miracle of biotechnology.",
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- RESONANCE RESOLUTION
-- Checks a sequence for matching resonance patterns and applies their effects.
-- Called as an additional synthesis pass after the core pipeline.
-- ═══════════════════════════════════════════════════════════════════════════════

--- Check if two strand IDs are adjacent in the sequence (either order).
-- @param sequence table Ordered strand ID array
-- @param a string First strand ID
-- @param b string Second strand ID
-- @return bool
local function AreStrandsAdjacent(sequence, a, b)
    for i = 1, #sequence - 1 do
        if ((sequence[i] == a and sequence[i + 1] == b) or
            (sequence[i] == b and sequence[i + 1] == a)) then
            return true
        end
    end
    return false
end

--- Check if a resonance pattern matches a given sequence.
-- @param pattern table Resonance pattern definition
-- @param sequence table Ordered strand ID array
-- @return bool
local function DoesPatternMatch(pattern, sequence)
    local seqSet = {}
    for _, id in ipairs(sequence) do
        seqSet[id] = true
    end

    -- All required strands must be present
    for _, reqID in ipairs(pattern.required or {}) do
        if (!seqSet[reqID]) then return false end
    end

    -- At least one of requireAny must be present (if specified)
    if (pattern.requireAny and #pattern.requireAny > 0) then
        local found = false
        for _, anyID in ipairs(pattern.requireAny) do
            if (seqSet[anyID]) then
                found = true
                break
            end
        end
        if (!found) then return false end
    end

    -- Adjacency check: at least one pair of required strands must be adjacent
    if (pattern.requireAdjacent and pattern.required and #pattern.required >= 2) then
        local anyAdjacent = false
        for i = 1, #pattern.required do
            for j = i + 1, #pattern.required do
                if (AreStrandsAdjacent(sequence, pattern.required[i], pattern.required[j])) then
                    anyAdjacent = true
                    break
                end
            end
            if (anyAdjacent) then break end
        end
        if (!anyAdjacent) then return false end
    end

    return true
end

--- Resolve all resonance patterns for a sequence.
-- @param sequence table Ordered strand ID array
-- @param effects table Mutable effects array
-- @param stabilityRef table Mutable {value = N} stability reference
-- @return table Array of triggered resonance pattern IDs
function ix.bacta.ResolveResonancePatterns(sequence, effects, stabilityRef)
    if (!ix.bacta.IsDiseaseSystemAvailable()) then return {} end

    local triggered = {}

    for id, pattern in pairs(ix.bacta.ResonancePatterns) do
        if (DoesPatternMatch(pattern, sequence)) then
            triggered[#triggered + 1] = id

            -- Apply stability modifier
            if (pattern.stabilityBonus) then
                stabilityRef.value = stabilityRef.value + pattern.stabilityBonus
            end

            -- Generate and inject bonus effects
            if (pattern.effects) then
                local bonusEffects = pattern.effects(sequence, effects)
                for _, eff in ipairs(bonusEffects or {}) do
                    effects[#effects + 1] = table.Copy(eff)
                end
            end
        end
    end

    return triggered
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- ADJACENCY RULES FOR DISEASE STRANDS
-- Appended to the existing ix.bacta.AdjacencyRules and AdjacencyPenalties.
-- ═══════════════════════════════════════════════════════════════════════════════

if (ix.bacta.AdjacencyRules) then
    -- Antiviral + Immunogenic Primer — potent immune synergy
    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "act_antiviral_compound", b = "act_immunogenic_primer",
        modifier_forward = {magnitude_mult = 1.15, stability = 5},
        modifier_reverse = {magnitude_mult = 1.08, stability = 3},
        hidden = false,
    }

    -- Antibiotic + Broad Spectrum — enhanced coverage
    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "act_antibiotic_compound", b = "act_broad_spectrum_agent",
        modifier_forward = {magnitude_mult = 1.12, stability = 3},
        modifier_reverse = {magnitude_mult = 1.06, stability = 2},
        hidden = false,
    }

    -- Antiviral + Broad Spectrum — enhanced coverage
    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "act_antiviral_compound", b = "act_broad_spectrum_agent",
        modifier_forward = {magnitude_mult = 1.12, stability = 3},
        modifier_reverse = {magnitude_mult = 1.06, stability = 2},
        hidden = false,
    }

    -- Neuro Stabiliser + Chemical Neutraliser — psychological treatment synergy
    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "act_neuro_stabiliser", b = "stab_chem_neutral",
        modifier_forward = {stability = 8, duration_mult = 1.20},
        modifier_reverse = {stability = 4, duration_mult = 1.10},
        hidden = false,
    }

    -- Genomic Repair + Antiviral — hidden genetic cure synergy
    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "act_genomic_rep", b = "act_antiviral_compound",
        modifier_forward = {magnitude_mult = 1.20, stability = 5},
        modifier_reverse = {magnitude_mult = 1.10, stability = 3},
        hidden = true,
    }

    -- Genomic Repair + Antibiotic — hidden genetic cure synergy
    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "act_genomic_rep", b = "act_antibiotic_compound",
        modifier_forward = {magnitude_mult = 1.20, stability = 5},
        modifier_reverse = {magnitude_mult = 1.10, stability = 3},
        hidden = true,
    }

    -- Immunogenic Primer + Viral Vector — enhanced immune delivery
    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "act_immunogenic_primer", b = "mod_viral_vector",
        modifier_forward = {magnitude_mult = 1.25, stability = -5},
        modifier_reverse = {magnitude_mult = 1.15, stability = -3},
        hidden = true,
    }

    -- Pathogen Neutraliser + Pathogen Culture — taming the pathogen
    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "met_pathogen_neutral", b = "act_pathogen_culture",
        modifier_forward = {stability = 10},
        modifier_reverse = {stability = 6},
        hidden = false,
    }

    -- ─── New Strand Adjacency Rules ─────────────────────────────────────

    -- Symptom strands combo together for enhanced effects
    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "act_pyrogenic_agent", b = "act_respiratory_inhibitor",
        modifier_forward = {magnitude_mult = 1.2, stability = -3},
        modifier_reverse = {magnitude_mult = 1.15, stability = -2},
        hidden = false,
    }

    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "act_hallucinogen", b = "act_nociceptor_amp",
        modifier_forward = {magnitude_mult = 1.3, stability = -5},
        modifier_reverse = {magnitude_mult = 1.2, stability = -4},
        hidden = false,
    }

    -- Pathogen culture boosts all negative symptom strands
    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "act_pathogen_culture", b = "act_pyrogenic_agent",
        modifier_forward = {magnitude_mult = 1.25, stability = -8},
        modifier_reverse = {magnitude_mult = 1.15, stability = -5},
        hidden = false,
    }

    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "act_pathogen_culture", b = "act_respiratory_inhibitor",
        modifier_forward = {magnitude_mult = 1.25, stability = -8},
        modifier_reverse = {magnitude_mult = 1.15, stability = -5},
        hidden = false,
    }

    -- Immune destroyer + Multi-pathogen = devastating combo
    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "act_immune_destroyer", b = "act_multi_pathogen",
        modifier_forward = {magnitude_mult = 1.5, stability = -10},
        modifier_reverse = {magnitude_mult = 1.4, stability = -8},
        hidden = true,
    }

    -- Contagion enhancer + any disease strand
    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "act_contagion_enhancer", b = "act_rakghoul_strain",
        modifier_forward = {magnitude_mult = 1.4, stability = -12},
        modifier_reverse = {magnitude_mult = 1.3, stability = -10},
        hidden = true,
    }

    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "act_contagion_enhancer", b = "act_krytos_virus",
        modifier_forward = {magnitude_mult = 1.4, stability = -12},
        modifier_reverse = {magnitude_mult = 1.3, stability = -10},
        hidden = true,
    }

    -- Viral vector enhances specific disease strands
    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "mod_viral_vector", b = "act_rakghoul_strain",
        modifier_forward = {magnitude_mult = 1.35, stability = -8},
        modifier_reverse = {magnitude_mult = 1.25, stability = -6},
        hidden = false,
    }

    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "mod_viral_vector", b = "act_neuro_plague",
        modifier_forward = {magnitude_mult = 1.3, stability = -8},
        modifier_reverse = {magnitude_mult = 1.2, stability = -6},
        hidden = false,
    }

    -- Necrotic agent + pain amplifier = torture compound
    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "act_necrotic_agent", b = "act_nociceptor_amp",
        modifier_forward = {magnitude_mult = 1.4, stability = -10},
        modifier_reverse = {magnitude_mult = 1.3, stability = -8},
        hidden = true,
    }

    -- Bioweapon catalyst amplifies all negative strands
    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "mod_bioweapon_catalyst", b = "act_multi_pathogen",
        modifier_forward = {magnitude_mult = 1.6, stability = -15},
        modifier_reverse = {magnitude_mult = 1.5, stability = -12},
        hidden = false,
    }

    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "mod_bioweapon_catalyst", b = "act_necrotic_agent",
        modifier_forward = {magnitude_mult = 1.5, stability = -12},
        modifier_reverse = {magnitude_mult = 1.4, stability = -10},
        hidden = false,
    }

    -- Hallucinogen + neuroplague/cyberia = psychotic break
    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "act_hallucinogen", b = "act_neuro_plague",
        modifier_forward = {magnitude_mult = 1.5, stability = -10},
        modifier_reverse = {magnitude_mult = 1.4, stability = -8},
        hidden = true,
    }

    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "act_hallucinogen", b = "act_cyberia_psychosis",
        modifier_forward = {magnitude_mult = 1.45, stability = -10},
        modifier_reverse = {magnitude_mult = 1.35, stability = -8},
        hidden = true,
    }

    -- Panacea stabilisation attempts
    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "act_panacea_omega", b = "stab_chem_neutral",
        modifier_forward = {stability = 15},
        modifier_reverse = {stability = 10},
        hidden = false,
    }

    ix.bacta.AdjacencyRules[#ix.bacta.AdjacencyRules + 1] = {
        a = "act_panacea_omega", b = "act_immunogenic_primer",
        modifier_forward = {stability = 12, magnitude_mult = 1.2},
        modifier_reverse = {stability = 8, magnitude_mult = 1.1},
        hidden = true,
    }
end

if (ix.bacta.AdjacencyPenalties) then
    -- Pathogen Culture adjacent to any treatment strand — fundamental conflict
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_pathogen_culture", b = "act_antiviral_compound",
        modifier_forward = {stability = -20, magnitude_mult = 0.60},
        modifier_reverse = {stability = -15, magnitude_mult = 0.70},
        hidden = false,
    }
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_pathogen_culture", b = "act_antibiotic_compound",
        modifier_forward = {stability = -20, magnitude_mult = 0.60},
        modifier_reverse = {stability = -15, magnitude_mult = 0.70},
        hidden = false,
    }
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_pathogen_culture", b = "act_neuro_stabiliser",
        modifier_forward = {stability = -20, magnitude_mult = 0.60},
        modifier_reverse = {stability = -15, magnitude_mult = 0.70},
        hidden = false,
    }
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_pathogen_culture", b = "act_immunogenic_primer",
        modifier_forward = {stability = -25, magnitude_mult = 0.50},
        modifier_reverse = {stability = -20, magnitude_mult = 0.60},
        hidden = false,
    }

    -- ─── New Strand Penalties ───────────────────────────────────────────

    -- Bioweapon catalyst destroys cure strands
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "mod_bioweapon_catalyst", b = "act_antiviral_compound",
        modifier_forward = {stability = -25, magnitude_mult = 0.40},
        modifier_reverse = {stability = -20, magnitude_mult = 0.50},
        hidden = false,
    }
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "mod_bioweapon_catalyst", b = "act_antibiotic_compound",
        modifier_forward = {stability = -25, magnitude_mult = 0.40},
        modifier_reverse = {stability = -20, magnitude_mult = 0.50},
        hidden = false,
    }
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "mod_bioweapon_catalyst", b = "act_neuro_stabiliser",
        modifier_forward = {stability = -25, magnitude_mult = 0.40},
        modifier_reverse = {stability = -20, magnitude_mult = 0.50},
        hidden = false,
    }
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "mod_bioweapon_catalyst", b = "act_bacta_base",
        modifier_forward = {stability = -30, magnitude_mult = 0.30},
        modifier_reverse = {stability = -25, magnitude_mult = 0.40},
        hidden = false,
    }

    -- Specific disease strands conflict with their cures
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_rakghoul_strain", b = "act_antiviral_compound",
        modifier_forward = {stability = -18, magnitude_mult = 0.55},
        modifier_reverse = {stability = -15, magnitude_mult = 0.65},
        hidden = false,
    }
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_krytos_virus", b = "act_antiviral_compound",
        modifier_forward = {stability = -18, magnitude_mult = 0.55},
        modifier_reverse = {stability = -15, magnitude_mult = 0.65},
        hidden = false,
    }
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_bloodburn_pathogen", b = "act_antiviral_compound",
        modifier_forward = {stability = -18, magnitude_mult = 0.55},
        modifier_reverse = {stability = -15, magnitude_mult = 0.65},
        hidden = false,
    }
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_neuro_plague", b = "act_neuro_stabiliser",
        modifier_forward = {stability = -20, magnitude_mult = 0.50},
        modifier_reverse = {stability = -18, magnitude_mult = 0.60},
        hidden = false,
    }
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_cyberia_psychosis", b = "act_neuro_stabiliser",
        modifier_forward = {stability = -18, magnitude_mult = 0.55},
        modifier_reverse = {stability = -15, magnitude_mult = 0.65},
        hidden = false,
    }
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_corellian_plague", b = "act_antibiotic_compound",
        modifier_forward = {stability = -18, magnitude_mult = 0.55},
        modifier_reverse = {stability = -15, magnitude_mult = 0.65},
        hidden = false,
    }

    -- Multi-pathogen conflicts with all treatment strands
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_multi_pathogen", b = "act_antiviral_compound",
        modifier_forward = {stability = -22, magnitude_mult = 0.45},
        modifier_reverse = {stability = -18, magnitude_mult = 0.55},
        hidden = false,
    }
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_multi_pathogen", b = "act_antibiotic_compound",
        modifier_forward = {stability = -22, magnitude_mult = 0.45},
        modifier_reverse = {stability = -18, magnitude_mult = 0.55},
        hidden = false,
    }
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_multi_pathogen", b = "act_broad_spectrum_agent",
        modifier_forward = {stability = -25, magnitude_mult = 0.40},
        modifier_reverse = {stability = -20, magnitude_mult = 0.50},
        hidden = false,
    }

    -- Necrotic agent conflicts with healing strands
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_necrotic_agent", b = "act_bacta_base",
        modifier_forward = {stability = -25, magnitude_mult = 0.35},
        modifier_reverse = {stability = -20, magnitude_mult = 0.45},
        hidden = false,
    }
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_necrotic_agent", b = "act_dermal_regen",
        modifier_forward = {stability = -22, magnitude_mult = 0.40},
        modifier_reverse = {stability = -18, magnitude_mult = 0.50},
        hidden = false,
    }
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_necrotic_agent", b = "act_genomic_rep",
        modifier_forward = {stability = -28, magnitude_mult = 0.30},
        modifier_reverse = {stability = -25, magnitude_mult = 0.35},
        hidden = false,
    }

    -- Immune destroyer conflicts with immunogenic primer
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_immune_destroyer", b = "act_immunogenic_primer",
        modifier_forward = {stability = -30, magnitude_mult = 0.20},
        modifier_reverse = {stability = -25, magnitude_mult = 0.30},
        hidden = false,
    }
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_immune_destroyer", b = "act_broad_spectrum_agent",
        modifier_forward = {stability = -25, magnitude_mult = 0.40},
        modifier_reverse = {stability = -20, magnitude_mult = 0.50},
        hidden = false,
    }

    -- Hallucinogen conflicts with neuro stabiliser
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_hallucinogen", b = "act_neuro_stabiliser",
        modifier_forward = {stability = -20, magnitude_mult = 0.50},
        modifier_reverse = {stability = -18, magnitude_mult = 0.60},
        hidden = false,
    }

    -- Pain amplifier conflicts with analgesics
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_nociceptor_amp", b = "act_analgesic",
        modifier_forward = {stability = -22, magnitude_mult = 0.40},
        modifier_reverse = {stability = -20, magnitude_mult = 0.50},
        hidden = false,
    }

    -- Panacea conflicts with anything chaotic
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_panacea_omega", b = "cat_entropy_seed",
        modifier_forward = {stability = -35, magnitude_mult = 0.20},
        modifier_reverse = {stability = -30, magnitude_mult = 0.30},
        hidden = false,
    }
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_panacea_omega", b = "act_pathogen_culture",
        modifier_forward = {stability = -40, magnitude_mult = 0.15},
        modifier_reverse = {stability = -35, magnitude_mult = 0.20},
        hidden = false,
    }
    ix.bacta.AdjacencyPenalties[#ix.bacta.AdjacencyPenalties + 1] = {
        a = "act_panacea_omega", b = "act_genetic_mutagen",
        modifier_forward = {stability = -45, magnitude_mult = 0.10},
        modifier_reverse = {stability = -40, magnitude_mult = 0.15},
        hidden = false,
    }
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SERVER-SIDE LOGIC
-- Effect apply functions, synthesis pipeline integration, contamination logic.
-- ═══════════════════════════════════════════════════════════════════════════════

if (SERVER) then
    -- ─── Disease Treat Apply ─────────────────────────────────────────────
    ix.bacta.effectTypes["disease_treat"].apply = function(client, eff)
        if (!ix.bacta.IsDiseaseSystemAvailable()) then return end

        local char = client:GetCharacter()
        if (!char) then return end

        local category = eff.disease_category or "antiviral"
        local medicineTypes = ix.bacta.GetMedicineTypesForCategory(category)
        local anyTreated = false

        for _, medType in ipairs(medicineTypes) do
            local treated = ix.disease.ApplyMedicine(char, medType)
            if (treated) then anyTreated = true end
        end

        if (anyTreated) then
            client:Notify("The compound targets your infections — treatment has begun.")
        end

        ix.bacta.NotifyEffect(client, eff)
    end

    -- ─── Disease Cure Apply ──────────────────────────────────────────────
    ix.bacta.effectTypes["disease_cure"].apply = function(client, eff)
        if (!ix.bacta.IsDiseaseSystemAvailable()) then return end

        local char = client:GetCharacter()
        if (!char) then return end

        local target = eff.disease_target or "viral"

        -- Check if target is a specific disease ID
        local disease = ix.disease.Get(target)
        if (disease) then
            ix.disease.Cure(char, target)
            client:Notify("The compound eradicates the " .. disease.name .. " from your system.")
        else
            -- Target is a disease type — cure all matching diseases
            local diseases = ix.disease.GetActiveDiseases(char)
            local cured = false

            for diseaseID, _ in pairs(diseases) do
                local d = ix.disease.Get(diseaseID)
                if (d and d.type == target) then
                    ix.disease.Cure(char, diseaseID)
                    cured = true
                end
            end

            if (cured) then
                client:Notify("The compound purges all " .. target .. " infections from your body.")
            end
        end

        ix.bacta.NotifyEffect(client, eff)
    end

    -- ─── Disease Cure All Apply ──────────────────────────────────────────
    ix.bacta.effectTypes["disease_cure_all"].apply = function(client, eff)
        if (!ix.bacta.IsDiseaseSystemAvailable()) then return end

        local char = client:GetCharacter()
        if (!char) then return end

        ix.disease.CureAll(char)
        client:Notify("A profound warmth surges through you — every pathogen is annihilated.")

        ix.bacta.NotifyEffect(client, eff)
    end

    -- ─── Disease Vaccinate Apply ─────────────────────────────────────────
    ix.bacta.effectTypes["disease_vaccinate"].apply = function(client, eff)
        if (!ix.bacta.IsDiseaseSystemAvailable()) then return end

        local char = client:GetCharacter()
        if (!char) then return end

        local target = eff.disease_target
        if (!target) then return end

        local disease = ix.disease.Get(target)
        if (!disease) then return end

        ix.disease.Vaccinate(char, target)
        client:Notify("Your immune system has been primed against " .. disease.name .. ".")

        ix.bacta.NotifyEffect(client, eff)
    end

    -- ─── Disease Suppress Apply ──────────────────────────────────────────
    ix.bacta.effectTypes["disease_suppress"].apply = function(client, eff)
        if (!ix.bacta.IsDiseaseSystemAvailable()) then return end

        local char = client:GetCharacter()
        if (!char) then return end

        local duration = eff.duration or 60
        local charID = char:GetID()
        local timerID = "ixBacta_diseaseSuppress_" .. client:EntIndex() .. "_" .. CurTime()

        -- Periodically reset disease progression timers to freeze advancement
        timer.Create(timerID, 3, math.floor(duration / 3), function()
            if (!IsValid(client) or !client:Alive()) then return end

            local c = client:GetCharacter()
            if (!c or c:GetID() != charID) then return end

            local diseases = ix.disease.GetActiveDiseases(c)
            local modified = false

            for diseaseID, info in pairs(diseases) do
                info.lastProgression = CurTime()
                modified = true
            end

            if (modified) then
                c:SetData("diseases", diseases)
            end
        end)

        client:Notify("Your disease symptoms are temporarily suppressed.")
        ix.bacta.NotifyEffect(client, eff)
    end

    -- ─── Disease Infect Apply ────────────────────────────────────────────
    ix.bacta.effectTypes["disease_infect"].apply = function(client, eff)
        if (!ix.bacta.IsDiseaseSystemAvailable()) then return end

        local char = client:GetCharacter()
        if (!char) then return end

        local target = eff.disease_target or "random"
        local force = eff.force or false
        local diseaseID

        if (target == "random" or target == "random_severe") then
            local allDiseases = ix.disease.GetAll()
            local candidates = {}

            for id, data in pairs(allDiseases) do
                if (target == "random_severe") then
                    -- Only pick diseases with 4+ stages (more dangerous)
                    if (data.stages and #data.stages >= 4) then
                        candidates[#candidates + 1] = id
                    end
                else
                    candidates[#candidates + 1] = id
                end
            end

            if (#candidates > 0) then
                diseaseID = candidates[math.random(#candidates)]
            end
        else
            diseaseID = target
        end

        if (diseaseID) then
            local success, err = ix.disease.Infect(char, diseaseID, force)
            if (success) then
                client:Notify("You feel a sudden wave of illness — something has infected you.")
            end
        end

        ix.bacta.NotifyEffect(client, eff)
    end

    -- ─── Disease Worsen Apply ────────────────────────────────────────────
    ix.bacta.effectTypes["disease_worsen"].apply = function(client, eff)
        if (!ix.bacta.IsDiseaseSystemAvailable()) then return end

        local char = client:GetCharacter()
        if (!char) then return end

        local stages = math.floor(eff.magnitude or 1)
        local diseases = ix.disease.GetActiveDiseases(char)
        local worsened = false

        for diseaseID, info in pairs(diseases) do
            local disease = ix.disease.Get(diseaseID)
            if (!disease) then continue end

            local newStage = math.min((info.stage or 1) + stages, #disease.stages)
            if (newStage > (info.stage or 1)) then
                ix.disease.SetProgress(char, diseaseID, newStage)
                worsened = true
            end
        end

        if (worsened) then
            client:Notify("Your conditions deteriorate rapidly...")
        end

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["tail_pathogenic_reaction"].apply = function(client, eff)
        if (!ix.bacta.IsDiseaseSystemAvailable()) then return end

        local char = client:GetCharacter()
        if (!char) then return end

        -- 50% chance to actually cause infection (it's a reaction, not guaranteed)
        if (math.random(100) <= 50) then
            local allDiseases = ix.disease.GetAll()
            local candidates = {}

            for id, data in pairs(allDiseases) do
                -- Only pick milder diseases for tail reactions
                if (data.stages and #data.stages <= 4) then
                    candidates[#candidates + 1] = id
                end
            end

            if (#candidates > 0) then
                local diseaseID = candidates[math.random(#candidates)]
                local success = ix.disease.Infect(char, diseaseID, false)
                if (success) then
                    client:Notify("A delayed pathogenic reaction surfaces — you feel the onset of illness.")
                end
            end
        else
            -- Mild immune reaction symptoms instead of full infection
            ix.bacta.ApplyTempDisplay(client, "bactaNausea", 0.20, eff.duration or 5)
            ix.bacta.ApplyTempDisplay(client, "bactaFatigue", 0.10, eff.duration or 5)
            client:Notify("A mild immune reaction passes through you.")
        end

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["tail_necrotic_cascade"].apply = function(client, eff)
        local duration = eff.duration or 15
        local totalDamage = 25
        
        -- Apply severe ongoing damage
        ix.bacta.ApplyEffectDelayed(client, {
            type = "damage_hp",
            magnitude = totalDamage,
            duration = duration,
            immediate = false,
            dot = true,
        })
        
        -- Apply pain
        ix.bacta.ApplyEffectDelayed(client, {
            type = "disease_symptom_pain",
            magnitude = 1.5,
            duration = duration,
            immediate = true,
        })
        
        client:Notify("Necrotic tissue spreads — flesh dies and blackens.")
        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["tail_genetic_instability"].apply = function(client, eff)
        -- Roll for random mutation effect
        local roll = math.random(100)
        
        if (roll <= 30) then
            -- Beneficial mutation
            local benefits = {
                {type = "buff_regen", magnitude = 0.3, duration = 60},
                {type = "buff_armor", magnitude = 15, duration = 90},
                {type = "heal_hp", magnitude = 20, duration = 0, immediate = true},
            }
            local effect = benefits[math.random(#benefits)]
            ix.bacta.ApplyEffectDelayed(client, effect)
            client:Notify("Genetic instability resolves favorably — you feel enhanced.")
        elseif (roll <= 70) then
            -- Harmful mutation
            local harms = {
                {type = "damage_hp", magnitude = 20, duration = 0, immediate = true},
                {type = "disease_symptom_weakness", magnitude = 1.0, duration = 90},
                {type = "debuff_stamina", magnitude = 0.3, duration = 90},
            }
            local effect = harms[math.random(#harms)]
            ix.bacta.ApplyEffectDelayed(client, effect)
            client:Notify("Genetic mutations wrack your cells — something has gone wrong.")
        else
            -- Severe mutation - disease
            if (ix.bacta.IsDiseaseSystemAvailable()) then
                local char = client:GetCharacter()
                if (char) then
                    local allDiseases = ix.disease.GetAll()
                    local diseaseIDs = {}
                    for id, _ in pairs(allDiseases) do
                        diseaseIDs[#diseaseIDs + 1] = id
                    end
                    
                    if (#diseaseIDs > 0) then
                        local diseaseID = diseaseIDs[math.random(#diseaseIDs)]
                        ix.disease.Infect(char, diseaseID, true)
                        client:Notify("Catastrophic genetic mutation — a new disease awakens in your cells.")
                    end
                end
            end
        end
        
        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["tail_cascade_failure"].apply = function(client, eff)
        -- Catastrophic multi-system failure
        local duration = eff.duration or 20
        
        -- Massive damage
        ix.bacta.ApplyEffectDelayed(client, {
            type = "damage_hp",
            magnitude = 50,
            duration = 0,
            immediate = true,
        })
        
        -- Ongoing damage
        ix.bacta.ApplyEffectDelayed(client, {
            type = "damage_hp",
            magnitude = 40,
            duration = duration,
            immediate = false,
            dot = true,
        })
        
        -- All debuffs
        ix.bacta.ApplyEffectDelayed(client, {type = "debuff_stamina", magnitude = 0.5, duration = duration})
        ix.bacta.ApplyEffectDelayed(client, {type = "debuff_focus", magnitude = 0.5, duration = duration})
        ix.bacta.ApplyEffectDelayed(client, {type = "disease_symptom_pain", magnitude = 2.0, duration = duration, immediate = true})
        ix.bacta.ApplyEffectDelayed(client, {type = "disease_symptom_weakness", magnitude = 1.5, duration = duration})
        ix.bacta.ApplyEffectDelayed(client, {type = "disease_symptom_confusion", magnitude = 1.5, duration = duration})
        
        client:Notify("CASCADE FAILURE — every system in your body begins shutting down.")
        ix.bacta.NotifyEffect(client, eff)
    end

    -- ─── Disease Symptom Apply Functions ─────────────────────────────────

    ix.bacta.effectTypes["disease_symptom_fever"].apply = function(client, eff)
        local magnitude = eff.magnitude or 1.0
        local duration = eff.duration or 30

        local PE   = ix.playerEffects
        local MULT = PE.MOD_MULT

        ix.bacta.ApplyTempDisplay(client, "bactaFever", magnitude * 0.3, duration)
        ix.bacta.ApplyTempDisplay(client, "bactaFatigue", magnitude * 0.2, duration)

        -- Fatigue as speed debuff
        local fatigueMult = 1.0 - (magnitude * 0.2)
        client:AddEffect("speed.run", "bactaFever", MULT, fatigueMult, {
            duration = duration,
            priority = 3,
            layer    = "debuff",
            metadata = {source = "bacta_symptom"},
        })
        client:AddEffect("speed.walk", "bactaFever", MULT, fatigueMult, {
            duration = duration,
            priority = 3,
            layer    = "debuff",
        })

        if (magnitude > 1.0) then
            client:Notify("Intense heat surges through your body — you're burning up.")
        else
            client:Notify("You feel feverish and warm.")
        end

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["disease_symptom_cough"].apply = function(client, eff)
        local duration = eff.duration or 30

        ix.bacta.ApplyTempDisplay(client, "bactaCough", 1.0, duration)
        ix.bacta.ApplyTempDisplay(client, "bactaBreathing", 0.25, duration)

        client:Notify("Your airways constrict — coughing begins.")
        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["disease_symptom_hallucination"].apply = function(client, eff)
        local magnitude = eff.magnitude or 1.0
        local duration = eff.duration or 30

        ix.bacta.ApplyTempDisplay(client, "bactaHallucination", magnitude, duration)
        
        -- Trigger visual distortion effects
        if (magnitude > 1.0) then
            client:Notify("Reality fractures around you — you see things that cannot be.")
            -- Could trigger actual visual effects here
            net.Start("ixBactaHallucination")
            net.WriteFloat(magnitude)
            net.WriteFloat(duration)
            net.Send(client)
        else
            client:Notify("Strange shapes dance at the edge of your vision.")
        end
        
        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["disease_symptom_pain"].apply = function(client, eff)
        local magnitude = eff.magnitude or 1.0
        local duration = eff.duration or 30

        local PE   = ix.playerEffects
        local MULT = PE.MOD_MULT

        ix.bacta.ApplyTempDisplay(client, "bactaPain", magnitude, duration)

        -- Movement penalty via player_effects
        local speedPenalty = math.Clamp(magnitude * 0.15, 0, 0.4)
        local speedMult = 1.0 - speedPenalty
        client:AddEffect("speed.run", "bactaPain", MULT, speedMult, {
            duration = duration,
            priority = 3,
            layer    = "debuff",
            metadata = {source = "bacta_symptom"},
        })
        client:AddEffect("speed.walk", "bactaPain", MULT, speedMult, {
            duration = duration,
            priority = 3,
            layer    = "debuff",
        })

        -- Pain amplification
        local painAmp = 1.0 + (magnitude * 0.15)
        client:AddEffect("damage.taken", "bactaPain", MULT, painAmp, {
            duration = duration,
            priority = 3,
            layer    = "debuff",
        })

        if (magnitude > 1.5) then
            client:Notify("Excruciating pain tears through every nerve — you can barely move.")
        elseif (magnitude > 1.0) then
            client:Notify("Severe pain wracks your body.")
        else
            client:Notify("You feel a dull, persistent ache.")
        end

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["disease_symptom_weakness"].apply = function(client, eff)
        local magnitude = eff.magnitude or 1.0
        local duration = eff.duration or 30

        local PE   = ix.playerEffects
        local MULT = PE.MOD_MULT

        ix.bacta.ApplyTempDisplay(client, "bactaWeakness", magnitude, duration)

        -- Fatigue as speed debuff
        local fatigueMult = 1.0 - (magnitude * 0.3)
        client:AddEffect("speed.run", "bactaWeakness", MULT, fatigueMult, {
            duration = duration,
            priority = 3,
            layer    = "debuff",
            metadata = {source = "bacta_symptom"},
        })
        client:AddEffect("speed.walk", "bactaWeakness", MULT, fatigueMult, {
            duration = duration,
            priority = 3,
            layer    = "debuff",
        })

        client:Notify("Your muscles feel weak and unresponsive.")
        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["disease_symptom_confusion"].apply = function(client, eff)
        local magnitude = eff.magnitude or 1.0
        local duration = eff.duration or 30

        local PE   = ix.playerEffects
        local MULT = PE.MOD_MULT

        ix.bacta.ApplyTempDisplay(client, "bactaConfusion", magnitude, duration)

        -- Focus impairment
        local focusMult = 1.0 - (magnitude * 0.25)
        client:AddEffect("combat.focus", "bactaConfusion", MULT, focusMult, {
            duration = duration,
            priority = 3,
            layer    = "debuff",
            metadata = {source = "bacta_symptom"},
        })

        if (magnitude > 1.0) then
            client:Notify("Your thoughts scatter like leaves — you can't remember where you are.")
        else
            client:Notify("Your mind feels clouded and slow.")
        end

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["disease_symptom_nausea"].apply = function(client, eff)
        local duration = eff.duration or 30

        local PE  = ix.playerEffects
        local ADD = PE.MOD_ADD

        client:AddEffect("visual.nausea", "bactaDisNausea", ADD, 1.0, {
            duration = duration,
            priority = 3,
            layer    = "debuff",
            metadata = {source = "bacta_symptom"},
        })

        client:Notify("Your stomach churns violently — you feel like vomiting.")
        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["immune_suppress"].apply = function(client, eff)
        local magnitude = eff.magnitude or 1.0
        local duration = eff.duration or 60

        ix.bacta.ApplyTempDisplay(client, "bactaImmuneSuppression", magnitude, duration)

        -- Make character more vulnerable to diseases
        local char = client:GetCharacter()
        if (char and ix.bacta.IsDiseaseSystemAvailable()) then
            char:SetData("bactaImmuneWeakness", magnitude, duration)
        end

        if (magnitude > 1.0) then
            client:Notify("Your immune system collapses — you are defenseless against disease.")
        else
            client:Notify("Your immune system weakens.")
        end

        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["contagion_amplify"].apply = function(client, eff)
        local magnitude = eff.magnitude or 1.0
        local duration = eff.duration or 60
        
        local char = client:GetCharacter()
        if (!char or !ix.bacta.IsDiseaseSystemAvailable()) then return end
        
        -- Store contagion multiplier
        char:SetData("bactaContagionMultiplier", magnitude)
        
        -- Set timer to clear it
        timer.Simple(duration, function()
            if (IsValid(client) and client:GetCharacter() == char) then
                char:SetData("bactaContagionMultiplier", nil)
            end
        end)
        
        if (magnitude > 2.0) then
            client:Notify("Your diseases mutate into highly contagious strains — anyone near you is at risk.")
        else
            client:Notify("Your infections become more transmissible.")
        end
        
        ix.bacta.NotifyEffect(client, eff)
    end

    ix.bacta.effectTypes["random_extreme_effect"].apply = function(client, eff)
        local magnitude = eff.magnitude or 1.0
        
        -- Roll for completely random effect
        local roll = math.random(100)
        
        if (roll <= 10) then
            -- Miracle cure
            if (ix.bacta.IsDiseaseSystemAvailable()) then
                local char = client:GetCharacter()
                if (char) then
                    ix.disease.CureAll(char)
                end
            end
            ix.bacta.ApplyEffectDelayed(client, {type = "heal_hp", magnitude = 100, duration = 0, immediate = true})
            ix.bacta.ApplyEffectDelayed(client, {type = "buff_regen", magnitude = 0.5, duration = 120})
            ix.bacta.ApplyEffectDelayed(client, {type = "buff_armor", magnitude = 30, duration = 120})
            client:Notify("Genetic perfection achieved — you have transcended your biological limits.")
        elseif (roll <= 25) then
            -- Major heal
            ix.bacta.ApplyEffectDelayed(client, {type = "heal_hp", magnitude = 60 * magnitude, duration = 0, immediate = true})
            ix.bacta.ApplyEffectDelayed(client, {type = "buff_regen", magnitude = 0.3, duration = 90})
            client:Notify("Beneficial mutations surge through you — cells regenerate at an accelerated rate.")
        elseif (roll <= 40) then
            -- Minor beneficial
            local benefits = {
                {type = "buff_armor", magnitude = 20, duration = 120},
                {type = "buff_focus", magnitude = 0.4, duration = 120},
                {type = "heal_hp", magnitude = 40, duration = 0, immediate = true},
            }
            ix.bacta.ApplyEffectDelayed(client, benefits[math.random(#benefits)])
            client:Notify("Mutagenic changes stabilize favorably.")
        elseif (roll <= 55) then
            -- Neutral/weird
            client:Notify("Strange mutations pass through you harmlessly — you feel different, but unchanged.")
        elseif (roll <= 70) then
            -- Minor harmful
            local harms = {
                {type = "damage_hp", magnitude = 25, duration = 0, immediate = true},
                {type = "disease_symptom_weakness", magnitude = 1.2, duration = 120},
                {type = "disease_symptom_confusion", magnitude = 1.0, duration = 90},
                {type = "debuff_stamina", magnitude = 0.4, duration = 120},
            }
            ix.bacta.ApplyEffectDelayed(client, harms[math.random(#harms)])
            client:Notify("Harmful mutations manifest — something has gone wrong.")
        elseif (roll <= 85) then
            -- Major harm
            ix.bacta.ApplyEffectDelayed(client, {type = "damage_hp", magnitude = 50, duration = 0, immediate = true})
            ix.bacta.ApplyEffectDelayed(client, {type = "disease_symptom_pain", magnitude = 1.8, duration = 60, immediate = true})
            ix.bacta.ApplyEffectDelayed(client, {type = "debuff_stamina", magnitude = 0.5, duration = 90})
            client:Notify("Catastrophic genetic damage — cells rupture and die.")
        elseif (roll <= 95) then
            -- Disease infection
            if (ix.bacta.IsDiseaseSystemAvailable()) then
                local char = client:GetCharacter()
                if (char) then
                    -- Infect with 2-3 random diseases
                    for i = 1, math.random(2, 3) do
                        local allDiseases = ix.disease.GetAll()
                        local diseaseIDs = {}
                        for id, _ in pairs(allDiseases) do
                            diseaseIDs[#diseaseIDs + 1] = id
                        end
                        
                        if (#diseaseIDs > 0) then
                            local diseaseID = diseaseIDs[math.random(#diseaseIDs)]
                            ix.disease.Infect(char, diseaseID, true)
                        end
                    end
                end
            end
            ix.bacta.ApplyEffectDelayed(client, {type = "damage_hp", magnitude = 30, duration = 0, immediate = true})
            client:Notify("Mutagenic chaos spawns diseases within your cells — pathogens emerge from nothing.")
        else
            -- Lethal
            ix.bacta.ApplyEffectDelayed(client, {type = "damage_hp", magnitude = 80, duration = 0, immediate = true})
            ix.bacta.ApplyEffectDelayed(client, {type = "damage_hp", magnitude = 50, duration = 30, immediate = false, dot = true})
            ix.bacta.ApplyEffectDelayed(client, {type = "disease_symptom_pain", magnitude = 2.5, duration = 30, immediate = true})
            client:Notify("GENETIC CATASTROPHE — your DNA unravels. Cell death cascades throughout your body.")
        end
        
        ix.bacta.NotifyEffect(client, eff)
    end

    -- ═════════════════════════════════════════════════════════════════════
    -- SYNTHESIS PIPELINE INTEGRATION
    -- Wraps ix.bacta.ResolveSequence to inject the resonance resolution
    -- pass and contamination-level disease injection after the core
    -- 11-pass pipeline completes.
    -- ═════════════════════════════════════════════════════════════════════

    --- Check if a sequence contains any disease-related strands.
    -- @param sequence table Ordered strand ID array
    -- @return bool
    local function HasDiseaseStrands(sequence)
        local diseaseStrands = {
            act_antiviral_compound = true,
            act_antibiotic_compound = true,
            act_neuro_stabiliser = true,
            act_broad_spectrum_agent = true,
            act_immunogenic_primer = true,
            act_pathogen_culture = true,
            mod_viral_vector = true,
            met_pathogen_neutral = true,
        }

        for _, id in ipairs(sequence) do
            if (diseaseStrands[id]) then return true end
        end
        return false
    end

    --- Check if a sequence contains any disease cure/treat strands.
    -- @param sequence table Ordered strand ID array
    -- @return bool
    local function HasDiseaseCureStrands(sequence)
        local cureStrands = {
            act_antiviral_compound = true,
            act_antibiotic_compound = true,
            act_neuro_stabiliser = true,
            act_broad_spectrum_agent = true,
            act_immunogenic_primer = true,
        }

        for _, id in ipairs(sequence) do
            if (cureStrands[id]) then return true end
        end
        return false
    end

    -- Wrap the core synthesis function to integrate resonance + contamination
    local OriginalResolveSequence = ix.bacta.ResolveSequence

    if (OriginalResolveSequence) then
        function ix.bacta.ResolveSequence(sequence, bDiscovery)
            -- Run the original 11-pass synthesis pipeline
            local effects, stability, totalPotency, bContaminated, cascadeResult, flags =
                OriginalResolveSequence(sequence, bDiscovery)

            -- Only proceed with disease integration if disease strands are present
            if (!HasDiseaseStrands(sequence)) then
                return effects, stability, totalPotency, bContaminated, cascadeResult, flags
            end

            -- ─── Pass 12: Resonance Pattern Resolution ───────────────
            local stabilityRef = {value = stability}
            local triggeredPatterns = ix.bacta.ResolveResonancePatterns(sequence, effects, stabilityRef)
            stability = math.Clamp(stabilityRef.value, 0, 100)

            -- Store triggered patterns in flags for downstream use (notifications, UI)
            flags.resonancePatterns = triggeredPatterns

            -- ─── Pass 13: Contamination Disease Injection ────────────
            -- If the compound is contaminated AND contained cure strands,
            -- the failed synthesis corrupts the cure into an infection.
            if (bContaminated and HasDiseaseCureStrands(sequence)) then
                -- Strip any beneficial disease effects that survived contamination
                for i = #effects, 1, -1 do
                    local eff = effects[i]
                    if (eff.type == "disease_treat" or eff.type == "disease_cure" or
                        eff.type == "disease_cure_all" or eff.type == "disease_vaccinate" or
                        eff.type == "disease_suppress") then
                        table.remove(effects, i)
                    end
                end

                -- Inject pathogenic contamination instead
                effects[#effects + 1] = {
                    type = "disease_infect",
                    magnitude = 1,
                    duration = 0,
                    immediate = true,
                    disease_target = "random",
                    force = false,
                }

                -- Also inject disease worsening
                effects[#effects + 1] = {
                    type = "disease_worsen",
                    magnitude = 1,
                    duration = 0,
                    immediate = true,
                }
            end

            -- Ensure resonance effects added to contaminated compounds are stripped
            if (bContaminated) then
                for i = #effects, 1, -1 do
                    if (!ix.bacta.IsSideEffect(effects[i].type) and
                        !ix.bacta.IsTailEffect(effects[i].type)) then
                        table.remove(effects, i)
                    end
                end
            end

            -- Recalculate total potency after resonance modifications
            totalPotency = 0
            for _, eff in ipairs(effects) do
                if (eff.magnitude) then
                    totalPotency = totalPotency + math.abs(eff.magnitude)
                end
            end

            return effects, stability, totalPotency, bContaminated, cascadeResult, flags
        end
    end
end
