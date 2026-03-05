local PLUGIN = PLUGIN

PLUGIN.name = "Bacta-Synth Protocol"
PLUGIN.author = "Vanir"
PLUGIN.description = "A compound sequencing and medical fabrication system. Synthesists discover, register, and produce biochemical compounds via the Compound Sequencer."

--- @module ix.bacta
-- Bacta-Synth Protocol system namespace.
ix.bacta = ix.bacta or {}

--- System configuration constants matching the Bacta-Synth Protocol v2.2 GDD.
-- @table ix.bacta.Config
ix.bacta.Config = {
    MAX_SEQUENCE_LENGTH   = 6,
    MAX_RECIPES_PER_CHAR  = 12, -- Legacy: kept for reference but canisters replace character-data storage
    BATCH_SIZE            = 3,
    FABRICATION_VARIANCE  = {min = 0.90, max = 1.10}, -- v2: variance moved to fabrication (+/-10%)
    STABILITY_BASE        = 50,

    -- v2.1: Tightened stability thresholds
    STABILITY_THRESHOLDS  = {
        clean  = 85,  -- v2.1: raised from 80. Requires genuine mastery.
        good   = 70,  -- v2.1: new tier
        minor  = 50,  -- Unstable range
        severe = 40,  -- v2.1: Degraded batch (partial contamination)
    },

    -- v2.1: Stability potency multipliers
    STABILITY_POTENCY = {
        clean    = 1.15,  -- 115% potency at Clean (90+)
        good     = 1.00,  -- 100% at Good (70-89)
        unstable = 0.85,  -- 85% at Unstable (50-69)
        degraded = 0.65,  -- 65% at Degraded (30-49)
    },

    -- v2.1: Side effect multipliers per stability tier
    STABILITY_SIDE_MULT = {
        clean    = 0.0,  -- All side effects stripped
        good     = 1.0,  -- Normal
        unstable = 2.0,  -- x2.0 amplified (v2.1: was x1.5)
        degraded = 3.0,  -- x3.0 amplified + minor corruption
    },

    ACTIVE_OVERLOAD_PEN   = 5,
    COMPLEXITY_PEN_AFTER  = 3,
    COMPLEXITY_PEN_RATE   = 0.1,

    -- v2: Session cost gate
    SESSION_COST          = 10,   -- SGC cost to open a new session pool
    SESSION_DURATION      = 1800/15, -- 30 minutes in seconds

    -- v2.1: Pool influence
    POOL_INFLUENCE_COST   = 25,   -- SGC cost to bias a pool category

    -- v2: Canister degradation defaults
    DEGRADATION_DEFAULT   = 2,    -- degradation per fabrication
    DEGRADATION_THRESHOLDS = {
        pristine  = {min = 76, max = 100, potency = 1.00, side_mult = 1.0,  label = "Pristine"},
        drifting  = {min = 51, max = 75,  potency = 0.90, side_mult = 1.0,  label = "Drifting"},
        degraded  = {min = 26, max = 50,  potency = 0.75, side_mult = 1.5,  label = "Degraded"},
        critical  = {min = 1,  max = 25,  potency = 0.55, side_mult = 2.5,  label = "Critical"},
    },

    -- v2: Refinement costs and caps
    REFINEMENT = {
        {cost = 50,  restore = 20, max_after = 100},
        {cost = 100, restore = 15, max_after = 85},
        {cost = 200, restore = 10, max_after = 70},
    },

    -- v2: Testing framework thresholds
    TESTING_THRESHOLDS = {
        experimental = {min = 0,  max = 2,  potency = 0.70, side_mult = 1.5, label = "Experimental"},
        tested       = {min = 3,  max = 9,  potency = 0.90, side_mult = 1.0, label = "Tested"},
        proven       = {min = 10, max = 999, potency = 1.00, side_mult = 0.8, label = "Proven"},
    },

    -- v2: Critical batch event chances
    CRITICAL_EVENTS = {
        resonant_chance     = 0.05,  -- 5% per fabrication
        cascade_chance      = 0.03,  -- 3% when stability 40-60
        perfect_chance      = 0.005, -- 0.5% on Proven canisters only
        resonant_potency    = 1.35,  -- +35% potency
        perfect_potency     = 1.50,  -- 150% potency
        resonant_tail_bonus = 1.20,  -- v2.2: +20% tail severity on resonant
    },

    -- v2.1: Production Integrity Check
    INTEGRITY_CHECK = {
        strand_threshold = 5,     -- fires for formulas with 5+ strands
        timeout          = 30,    -- seconds to respond
        bonus_standard   = 0.10,  -- +10% potency for correct answer
        bonus_metaboliser = 0.15, -- v2.2: +15% for metaboliser ordering
    },

    -- v2.2: Chain Purity bonus
    CHAIN_PURITY_BONUS = 0.15,    -- +5% beneficial magnitude for Pure formulas

    -- v2.2: Canister degradation modifier for chain depth
    CHAIN_DEPTH_DEGRADATION = {
        [0] = 0,      -- no metabolisers: standard rate
        [1] = 0.25,   -- depth 1: +0.25/fabrication
        [2] = 0.5,    -- depth 2: +0.5/fabrication
    },
    CHAIN_DEPTH_DEGRADATION_MAX = 1, -- depth 3+: +1/fabrication (flat)

    -- Session pool draw sizes
    POOL_BASES_COUNT      = 3,
    POOL_ACTIVES_MIN      = 2,
    POOL_ACTIVES_MAX      = 5,
    POOL_STABILISERS_MIN  = 1,
    POOL_STABILISERS_MAX  = 4,
    POOL_CATALYSTS_MIN    = 1,
    POOL_CATALYSTS_MAX    = 3,
    POOL_MODIFIERS_MIN    = 1,
    POOL_MODIFIERS_MAX    = 3,

    -- v2: Nearby broadcast range for experimental compounds
    EXPERIMENTAL_BROADCAST_RANGE = 250000, -- 500^2 units squared (~5m in Source)
}

-- ─── Shared Foundations ──────────────────────────────────────────────────────
ix.util.Include("sh_strands.lua")
ix.util.Include("sh_effects.lua")
ix.util.Include("sh_recipes.lua")

-- ─── Server Logic ────────────────────────────────────────────────────────────
ix.util.Include("sv_adjacency.lua")
ix.util.Include("sv_synthesis.lua")
ix.util.Include("sv_production.lua")
ix.util.Include("sv_cascade.lua")
ix.util.Include("sv_data.lua")

-- ─── Disease Integration Bridge (v3.0) ───────────────────────────────────────
-- Connects the Bacta-Synth Protocol with the Smart Disease System.
-- Must load after all core server files to wrap synthesis pipeline.
ix.util.Include("sh_disease_bridge.lua")

-- ─── Client Interface ────────────────────────────────────────────────────────
ix.util.Include("cl_sequencer.lua")
ix.util.Include("cl_hud.lua")

-- ═══════════════════════════════════════════════════════════════════════════════
-- COMMANDS
-- ═══════════════════════════════════════════════════════════════════════════════

ix.command.Add("SynthOpen", {
    description = "Open the Compound Sequencer interface.",
    OnRun = function(self, ply)
        if (SERVER) then
            ix.bacta.OpenSequencer(ply)
        end
    end
})

ix.command.Add("SynthGiveSGC", {
    description = "Give Synth-Grade Compounds to a player.",
    adminOnly = true,
    arguments = {
        ix.type.player,
        ix.type.number,
    },
    OnRun = function(self, ply, target, amount)
        amount = math.floor(math.Clamp(amount, 1, 999))

        local char = target:GetCharacter()
        if (!char) then return "Target has no active character." end

        local current = char:GetData("bactaSGC", 0)
        char:SetData("bactaSGC", current + amount)

        target:Notify("Received " .. amount .. " Synth-Grade Compounds. Balance: " .. (current + amount))
        ply:Notify("Gave " .. amount .. " SGC to " .. char:GetName() .. ".")
    end
})

ix.command.Add("SynthFormulas", {
    description = "List your Formula Canisters.",
    OnRun = function(self, ply)
        local char = ply:GetCharacter()
        if (!char) then return "No active character." end

        local inv = char:GetInventory()
        if (!inv) then return "No inventory." end

        local lines = {":: Formula Canisters ::"}
        local i = 0
        for _, item in pairs(inv:GetItems()) do
            if (item.uniqueID == "synth_canister") then
                i = i + 1
                local name = item:GetData("formula_name", "Unknown")
                local deg  = item:GetData("degradation", 100)
                local status = item:GetData("testing_status", "experimental")
                lines[#lines + 1] = string.format("  %d. %s [%s] (Integrity: %d/100)", i, name, status, deg)
            end
        end

        if (i == 0) then return "No Formula Canisters found." end
        return table.concat(lines, "\n")
    end
})

ix.command.Add("SynthRefine", {
    description = "Refine a Formula Canister to restore degradation.",
    arguments = {ix.type.text},
    OnRun = function(self, ply, name)
        if (SERVER) then
            return ix.bacta.RefineCanister(ply, name)
        end
    end
})

ix.command.Add("SynthBalance", {
    description = "Check your Synth-Grade Compound balance.",
    OnRun = function(self, ply)
        local char = ply:GetCharacter()
        if (!char) then return "No active character." end

        local balance = char:GetData("bactaSGC", 0)
        return "SGC Balance: " .. balance
    end
})
