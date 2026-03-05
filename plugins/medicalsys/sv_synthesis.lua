--- Server-Side Synthesis Logic (v2.2)
-- Core synthesis resolution engine: directional adjacency, catalysts, modifiers,
-- tuning strand application, metabolic cascade integration, adverse effect injection,
-- and session pool generation with pool influence support.
-- @module ix.bacta (server)

-- ═══════════════════════════════════════════════════════════════════════════════
-- SESSION POOL GENERATION
-- v2.2: Pool respects rarity weights for metaboliser/tuning strands.
-- Pools persist for 30 minutes (handled in sv_data.lua).
-- ═══════════════════════════════════════════════════════════════════════════════

--- Active synthesis sessions indexed by player entity.
ix.bacta.sessions = ix.bacta.sessions or {}

--- Draw a random subset of strands from a category, excluding a subcategory.
-- @param category string Category key
-- @param count number Number to draw
-- @param excludeSubcategory string|nil Subcategory to exclude
-- @return table Array of strand IDs
local function DrawFromCategory(category, count, excludeSubcategory)
    local pool = {}

    for id, strand in pairs(ix.bacta.strands) do
        if (strand.category == category) then
            if (excludeSubcategory and strand.subcategory == excludeSubcategory) then
                continue
            end
            if (!excludeSubcategory or !strand.subcategory) then
                pool[#pool + 1] = strand
            end
        end
    end

    -- Shuffle
    for i = #pool, 2, -1 do
        local j = math.random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    local drawn = {}
    for i = 1, math.min(count, #pool) do
        drawn[#drawn + 1] = pool[i].id
    end

    return drawn
end

--- Draw strands from a subcategory with rarity weighting.
-- @param subcategory string Subcategory key ("metaboliser", "tuning")
-- @param count number Number to attempt to draw
-- @return table Array of strand IDs
local function DrawFromSubcategory(subcategory, count)
    local pool = ix.bacta.GetStrandsBySubcategory(subcategory)
    if (#pool == 0) then return {} end

    local rarityWeights = ix.bacta.PoolRarityWeights or {common = 0.60, uncommon = 0.30, rare = 0.15, very_rare = 0.08}

    -- Build weighted pool
    local weighted = {}
    for _, strand in ipairs(pool) do
        local rarity = strand.pool_rarity or "common"
        local weight = rarityWeights[rarity] or 0.30

        -- Add entries proportional to weight
        local entries = math.max(1, math.floor(weight * 100))
        for j = 1, entries do
            weighted[#weighted + 1] = strand.id
        end
    end

    -- Shuffle weighted pool
    for i = #weighted, 2, -1 do
        local j = math.random(1, i)
        weighted[i], weighted[j] = weighted[j], weighted[i]
    end

    -- Draw unique
    local drawn = {}
    local seen = {}
    for _, id in ipairs(weighted) do
        if (#drawn >= count) then break end
        if (!seen[id]) then
            seen[id] = true
            drawn[#drawn + 1] = id
        end
    end

    return drawn
end

--- Generate a randomised session pool for a player.
-- v2.2: Includes metaboliser and tuning strand sub-pools.
-- @return table Pool mapping category/subcategory to array of strand IDs
function ix.bacta.GenerateSessionPool()
    local cfg = ix.bacta.Config
    local pool = {}

    pool.base       = DrawFromCategory("base", cfg.POOL_BASES_COUNT)
    pool.active     = DrawFromCategory("active", math.random(cfg.POOL_ACTIVES_MIN, cfg.POOL_ACTIVES_MAX))
    pool.stabiliser = DrawFromCategory("stabiliser", math.random(cfg.POOL_STABILISERS_MIN, cfg.POOL_STABILISERS_MAX), "metaboliser")
    pool.catalyst   = DrawFromCategory("catalyst", math.random(cfg.POOL_CATALYSTS_MIN, cfg.POOL_CATALYSTS_MAX))
    pool.modifier   = DrawFromCategory("modifier", math.random(cfg.POOL_MODIFIERS_MIN, cfg.POOL_MODIFIERS_MAX), "tuning")

    -- v2.2: Sub-pools for metaboliser and tuning strands
    pool.metaboliser = DrawFromSubcategory("metaboliser", math.random(cfg.POOL_METABOLISERS_MIN or 2, cfg.POOL_METABOLISERS_MAX or 4))
    pool.tuning      = DrawFromSubcategory("tuning", math.random(cfg.POOL_TUNING_MIN or 2, cfg.POOL_TUNING_MAX or 5))

    return pool
end

--- Flatten a pool into a single array of strand IDs.
-- @param pool table Category-keyed pool
-- @return table Flat array of all strand IDs in the pool
function ix.bacta.FlattenPool(pool)
    local flat = {}

    for _, ids in pairs(pool) do
        for _, id in ipairs(ids) do
            flat[#flat + 1] = id
        end
    end

    return flat
end

--- Open the Compound Sequencer for a player.
-- v2.0: Deducts session cost (SGC) on open.
-- v2.0: Sends canister data instead of character recipes.
-- @param client Entity The player
function ix.bacta.OpenSequencer(client)
    if (!IsValid(client) or !client:GetCharacter()) then return end

    local char = client:GetCharacter()
    local cfg = ix.bacta.Config

    -- v2.0: Session cost gate
    local sessionCost = cfg.SESSION_COST or 10
    local balance = char:GetData("bactaSGC", 0)

    if (balance < sessionCost) then
        client:Notify("Insufficient SGC to open sequencer. Need " .. sessionCost .. ", have " .. balance .. ".")
        return
    end

    -- Check for existing session (reuse within 30 min)
    local existing = ix.bacta.sessions[client]
    if (existing and existing.timestamp and (CurTime() - existing.timestamp) < (cfg.SESSION_POOL_DURATION or 1800)) then
        -- Reuse existing pool, no re-charge
        net.Start("ixBactaOpen")
            net.WriteTable(existing.pool)
            net.WriteTable(ix.bacta.GetPlayerCanisters(client))
            net.WriteUInt(char:GetData("bactaSGC", 0), 16)
        net.Send(client)
        return
    end

    -- Deduct session cost
    char:SetData("bactaSGC", balance - sessionCost)

    local pool = ix.bacta.GenerateSessionPool()
    ix.bacta.sessions[client] = {
        pool       = pool,
        poolFlat   = ix.bacta.FlattenPool(pool),
        timestamp  = CurTime(),
        poolInfluenceUsed = false,
    }

    -- Send pool to client
    net.Start("ixBactaOpen")
        net.WriteTable(pool)
        -- v2.0: Send canister data from inventory instead of character recipes
        net.WriteTable(ix.bacta.GetPlayerCanisters(client))
        -- Send SGC balance
        net.WriteUInt(char:GetData("bactaSGC", 0), 16)
    net.Send(client)
end

--- Get all canister items from a player's inventory.
-- @param client Entity The player
-- @return table Array of canister data tables
function ix.bacta.GetPlayerCanisters(client)
    local char = client:GetCharacter()
    if (!char) then return {} end

    local inv = char:GetInventory()
    if (!inv) then return {} end

    local canisters = {}
    for _, item in pairs(inv:GetItems()) do
        if (item.uniqueID == "synth_canister") then
            canisters[#canisters + 1] = {
                itemID        = item:GetID(),
                name          = item:GetData("formulaName", "Unnamed"),
                sequence      = item:GetData("sequence", {}),
                effects       = item:GetData("effects", {}),
                stability     = item:GetData("stability", 0),
                totalPotency  = item:GetData("totalPotency", 0),
                item_type     = item:GetData("item_type", "injector"),
                uses          = item:GetData("uses", 1),
                durability    = item:GetData("durability", 100),
                maxDurability = item:GetData("maxDurability", 100),
                test_count    = item:GetData("test_count", 0),
                status        = item:GetData("status", "experimental"),
                cascadeSummary = item:GetData("cascadeSummary"),
            }
        end
    end

    return canisters
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- POOL INFLUENCE (v2.0)
-- ═══════════════════════════════════════════════════════════════════════════════

--- Apply pool influence: reveal one additional strand from outside the pool.
-- Costs POOL_INFLUENCE_COST SGC.
-- @param client Entity The player
-- @param targetCategory string Category to add a strand from
-- @return bool success
-- @return string|nil error
function ix.bacta.ApplyPoolInfluence(client, targetCategory)
    if (!IsValid(client) or !client:GetCharacter()) then
        return false, "Invalid player."
    end

    local session = ix.bacta.sessions[client]
    if (!session) then return false, "No active session." end

    if (session.poolInfluenceUsed) then
        return false, "Pool influence already used this session."
    end

    local char = client:GetCharacter()
    local cost = ix.bacta.Config.POOL_INFLUENCE_COST or 25
    local balance = char:GetData("bactaSGC", 0)

    if (balance < cost) then
        return false, "Insufficient SGC. Need " .. cost .. ", have " .. balance .. "."
    end

    -- Find a strand in the target category not already in the pool
    local poolSet = {}
    for _, id in ipairs(session.poolFlat) do
        poolSet[id] = true
    end

    local candidates = {}
    -- Check both primary and subcategory strands
    for id, strand in pairs(ix.bacta.strands) do
        local matchesCategory = (strand.category == targetCategory)
        local matchesSubcategory = (strand.subcategory == targetCategory)

        if ((matchesCategory or matchesSubcategory) and !poolSet[id]) then
            candidates[#candidates + 1] = id
        end
    end

    if (#candidates == 0) then
        return false, "No additional strands available for this category."
    end

    -- Deduct cost
    char:SetData("bactaSGC", balance - cost)

    -- Pick a random candidate and add to pool
    local newStrand = candidates[math.random(#candidates)]
    local catKey = targetCategory

    -- Determine pool key
    if (ix.bacta.IsMetaboliser(newStrand)) then
        catKey = "metaboliser"
    elseif (ix.bacta.IsTuningStrand(newStrand)) then
        catKey = "tuning"
    end

    session.pool[catKey] = session.pool[catKey] or {}
    session.pool[catKey][#session.pool[catKey] + 1] = newStrand
    session.poolFlat[#session.poolFlat + 1] = newStrand
    session.poolInfluenceUsed = true

    -- Sync to client
    net.Start("ixBactaSyncPool")
        net.WriteTable(session.pool)
        net.WriteUInt(char:GetData("bactaSGC", 0), 16)
    net.Send(client)

    client:Notify("Pool influence applied. " .. ix.bacta.GetStrand(newStrand).name .. " added. " .. cost .. " SGC consumed.")

    return true
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CATALYST APPLICATION
-- ═══════════════════════════════════════════════════════════════════════════════

--- Apply a catalyst strand's global effect to the effect array.
-- @param strandID string The catalyst strand ID
-- @param effects table Mutable effects array
-- @param stabilityRef table Mutable stability reference
local function ApplyCatalyst(strandID, effects, stabilityRef)
    local strand = ix.bacta.GetStrand(strandID)
    if (!strand or !strand.catalyst_effect) then return end

    local cat = strand.catalyst_effect

    if (cat.type == "boost_immediate") then
        for _, eff in ipairs(effects) do
            if (eff.immediate and eff.magnitude) then
                eff.magnitude = math.Round(eff.magnitude * (cat.magnitude_mult or 1), 2)
            end
        end

    elseif (cat.type == "extend_durations") then
        for _, eff in ipairs(effects) do
            if (eff.duration and eff.duration > 0) then
                eff.duration = math.Round(eff.duration * (cat.duration_mult or 1), 1)
            end
            if (eff.magnitude and cat.magnitude_mult) then
                eff.magnitude = math.Round(eff.magnitude * cat.magnitude_mult, 2)
            end
        end

    elseif (cat.type == "boost_all") then
        for _, eff in ipairs(effects) do
            if (eff.magnitude) then
                eff.magnitude = math.Round(eff.magnitude * (cat.magnitude_mult or 1), 2)
            end
        end

    elseif (cat.type == "remove_sides") then
        for i = #effects, 1, -1 do
            if (ix.bacta.IsSideEffect(effects[i].type) and !ix.bacta.IsTailEffect(effects[i].type)) then
                table.remove(effects, i)
            end
        end

        if (cat.magnitude_mult) then
            for _, eff in ipairs(effects) do
                if (eff.magnitude) then
                    eff.magnitude = math.Round(eff.magnitude * cat.magnitude_mult, 2)
                end
            end
        end

    elseif (cat.type == "dual_phase") then
        local ratio = cat.immediate_ratio or 0.60
        local delay = cat.delay or 30
        local newEffects = {}

        for _, eff in ipairs(effects) do
            if (!ix.bacta.IsSideEffect(eff.type) and eff.magnitude) then
                local immEff = table.Copy(eff)
                immEff.magnitude = math.Round(eff.magnitude * ratio, 2)
                newEffects[#newEffects + 1] = immEff

                local delEff = table.Copy(eff)
                delEff.magnitude = math.Round(eff.magnitude * (1 - ratio), 2)
                delEff.delay = delay
                newEffects[#newEffects + 1] = delEff
            else
                newEffects[#newEffects + 1] = eff
            end
        end

        for i = 1, #effects do effects[i] = nil end
        for i, eff in ipairs(newEffects) do effects[i] = eff end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- STABILISER SPECIALS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Apply stabiliser special effects.
-- @param strandID string Stabiliser strand ID
-- @param effects table Mutable effects array
-- @param flags table Synthesis flags
local function ApplyStabiliserSpecial(strandID, effects, flags)
    local strand = ix.bacta.GetStrand(strandID)
    if (!strand or !strand.special) then return end

    local spec = strand.special

    if (spec.type == "remove_lowest_side") then
        local lowestIdx = nil
        local lowestMag = math.huge

        for i, eff in ipairs(effects) do
            if (ix.bacta.IsSideEffect(eff.type) and !ix.bacta.IsTailEffect(eff.type) and (eff.magnitude or 0) < lowestMag) then
                lowestMag = eff.magnitude or 0
                lowestIdx = i
            end
        end

        if (lowestIdx) then
            table.remove(effects, lowestIdx)
        end

    elseif (spec.type == "extend_durations") then
        local mult = 1 + (spec.value or 0.20)
        for _, eff in ipairs(effects) do
            if (eff.duration and eff.duration > 0) then
                eff.duration = math.Round(eff.duration * mult, 1)
            end
        end

    elseif (spec.type == "reduce_sides") then
        local mult = 1 - (spec.value or 0.50)
        for _, eff in ipairs(effects) do
            if (ix.bacta.IsSideEffect(eff.type) and !ix.bacta.IsTailEffect(eff.type) and eff.magnitude) then
                eff.magnitude = math.Round(eff.magnitude * mult, 2)
            end
        end

    elseif (spec.type == "suppress_variance") then
        flags.suppressVariance = true

    elseif (spec.type == "lock_potency") then
        flags.lockPotency = true

    elseif (spec.type == "reduce_degradation") then
        flags.degradationReduction = math.max(flags.degradationReduction or 0, spec.value or 0)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MODIFIER APPLICATION
-- ═══════════════════════════════════════════════════════════════════════════════

--- Apply modifier strand effects.
-- @param strandID string Modifier strand ID
-- @param effects table Mutable effects array
-- @param flags table Synthesis flags
local function ApplyModifier(strandID, effects, flags)
    local strand = ix.bacta.GetStrand(strandID)
    if (!strand or !strand.modifier_effect) then return end

    local mod = strand.modifier_effect

    if (mod.type == "smooth_absorption") then
        for _, eff in ipairs(effects) do
            if (eff.immediate) then
                eff.absorption_delay = mod.delay or 0.5
            end
        end

    elseif (mod.type == "add_effect") then
        if (mod.effect) then
            effects[#effects + 1] = table.Copy(mod.effect)
        end

    elseif (mod.type == "reduce_degradation") then
        flags.degradationReduction = math.max(flags.degradationReduction or 0, mod.value or 0)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TUNING STRAND APPLICATION (v2.2)
-- ═══════════════════════════════════════════════════════════════════════════════

--- Check if an effect type matches a tuning target spec.
-- @param effType string Effect type ID
-- @param tune table Tuning effect definition
-- @return bool
local function TuningTargetMatches(effType, tune)
    -- Explicit target list
    if (tune.targets) then
        for _, t in ipairs(tune.targets) do
            if (effType == t) then return true end
        end
        return false
    end

    -- Prefix match (can be pipe-separated)
    if (tune.target_prefix) then
        for prefix in string.gmatch(tune.target_prefix, "[^|]+") do
            if (string.sub(effType, 1, #prefix) == prefix) then return true end
        end
        return false
    end

    -- Match all
    if (tune.targets_all) then return true end

    return false
end

--- Apply tuning strand effects to the resolved effect array.
-- @param sequence table Ordered strand ID array
-- @param effects table Mutable effects array
-- @param flags table Synthesis flags
-- @param cascadeResult table|nil Cascade result for tail modification
local function ApplyTuningStrands(sequence, effects, flags, cascadeResult)
    for _, strandID in ipairs(sequence) do
        local strand = ix.bacta.GetStrand(strandID)
        if (!strand or !strand.tuning_effect) then continue end

        local tune = strand.tuning_effect

        if (tune.type == "magnitude_scale") then
            local mult = tune.multiplier or 1.0
            for _, eff in ipairs(effects) do
                if (eff.magnitude and TuningTargetMatches(eff.type, tune)) then
                    eff.magnitude = math.Round(eff.magnitude * mult, 2)
                end
            end

        elseif (tune.type == "duration_scale") then
            local mult = tune.multiplier or 1.0
            for _, eff in ipairs(effects) do
                if (eff.duration and eff.duration > 0 and TuningTargetMatches(eff.type, tune)) then
                    eff.duration = math.Round(eff.duration * mult, 1)
                end
            end

        elseif (tune.type == "compress") then
            local durMult = tune.duration_mult or 1.0
            local magMult = tune.magnitude_mult or 1.0
            for _, eff in ipairs(effects) do
                if (TuningTargetMatches(eff.type, tune)) then
                    if (eff.duration and eff.duration > 0) then
                        eff.duration = math.Round(eff.duration * durMult, 1)
                    end
                    if (eff.magnitude) then
                        eff.magnitude = math.Round(eff.magnitude * magMult, 2)
                    end
                end
            end

        elseif (tune.type == "tail_duration_scale") then
            -- Modify cascade tail durations
            if (cascadeResult and cascadeResult.unresolvedTails) then
                for _, tail in ipairs(cascadeResult.unresolvedTails) do
                    tail.duration = math.Round(tail.duration * (tune.multiplier or 1.0), 1)
                end
            end

        elseif (tune.type == "selective_isolate") then
            if (tune.mode == "combat") then
                -- Suppress regen/stamina, boost speed/focus
                for i = #effects, 1, -1 do
                    local t = effects[i].type
                    if (t == "regen_hp" or t == "stim_stamina") then
                        table.remove(effects, i)
                    end
                end
                for _, eff in ipairs(effects) do
                    if (eff.type == "buff_speed" or eff.type == "buff_focus") then
                        if (eff.magnitude) then
                            eff.magnitude = math.Round(eff.magnitude * 1.20, 2)
                        end
                    end
                end
            elseif (tune.mode == "healing") then
                -- Suppress buffs, boost healing
                for i = #effects, 1, -1 do
                    if (string.sub(effects[i].type, 1, 5) == "buff_") then
                        table.remove(effects, i)
                    end
                end
                for _, eff in ipairs(effects) do
                    if (eff.type == "heal_hp" or eff.type == "regen_hp") then
                        if (eff.magnitude) then
                            eff.magnitude = math.Round(eff.magnitude * 1.20, 2)
                        end
                    end
                end
            end

        elseif (tune.type == "selective_threshold") then
            -- Flag effects for conditional application
            flags.criticalThreshold = tune.threshold or 0.30
            flags.criticalBonus = tune.bonus or 1.50

        elseif (tune.type == "suppress_all_tails") then
            -- Handled by sv_cascade.lua
            flags.tailsSuppressed = true

        elseif (tune.type == "invert_lowest_side") then
            -- Find lowest-magnitude side effect and convert to beneficial
            local lowestIdx = nil
            local lowestMag = math.huge
            for i, eff in ipairs(effects) do
                if (ix.bacta.IsSideEffect(eff.type) and !ix.bacta.IsTailEffect(eff.type) and (eff.magnitude or 0) < lowestMag) then
                    lowestMag = eff.magnitude or 0
                    lowestIdx = i
                end
            end

            if (lowestIdx) then
                local side = effects[lowestIdx]
                -- Convert side_fatigue → buff_speed, side_nausea → buff_focus, etc.
                local invertMap = {
                    side_fatigue = "buff_speed",
                    side_nausea  = "buff_focus",
                    side_tremor  = "buff_focus",
                    side_cardiac = "regen_hp",
                }
                local newType = invertMap[side.type] or "buff_focus"
                side.type = newType
                side.magnitude = math.Round(math.abs(side.magnitude or 0) * 0.50, 2)
            end

        elseif (tune.type == "stack_bypass") then
            flags.stackBypass = tune.stack_mult or 0.75
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- ADVERSE EFFECT INJECTION
-- ═══════════════════════════════════════════════════════════════════════════════

--- Inject or amplify adverse effects based on stability score.
-- v2.0: Tightened thresholds (clean=90, good=70, minor=50, severe=30).
-- @param stability number Current stability score
-- @param effects table Mutable effects array
local function InjectAdverseEffects(stability, effects)
    local cfg = ix.bacta.Config.STABILITY_THRESHOLDS

    if (stability < cfg.severe) then
        -- Contaminated: wipe beneficial, add heavy sides
        for i = #effects, 1, -1 do
            if (!ix.bacta.IsSideEffect(effects[i].type)) then
                table.remove(effects, i)
            end
        end

        effects[#effects + 1] = {type = "side_cardiac", magnitude = 8, duration = 15, tick_rate = 3, immediate = false}
        effects[#effects + 1] = {type = "side_nausea", magnitude = 0.3, duration = 20, immediate = false}
        effects[#effects + 1] = {type = "side_tremor", magnitude = 4, duration = 15, immediate = false}

        return true
    end

    -- Below minor threshold: amplify sides, suppress a random beneficial
    local potencyMult = ix.bacta.Config.STABILITY_POTENCY_MULT or {}
    local sideMult = ix.bacta.Config.STABILITY_SIDE_MULT or {}

    -- Determine multipliers based on stability range
    local sPotency = 1.0
    local sSide = 1.0

    if (stability < cfg.minor) then
        sPotency = potencyMult.minor or 0.70
        sSide = sideMult.minor or 1.50
    elseif (stability < cfg.good) then
        sPotency = potencyMult.good or 0.90
        sSide = sideMult.good or 1.20
    end

    -- Apply side effect amplification
    for _, eff in ipairs(effects) do
        if (ix.bacta.IsSideEffect(eff.type) and !ix.bacta.IsTailEffect(eff.type) and eff.magnitude) then
            eff.magnitude = math.Round(eff.magnitude * sSide, 2)
        end
    end

    -- Apply potency reduction to beneficial effects
    if (sPotency < 1.0) then
        for _, eff in ipairs(effects) do
            if (!ix.bacta.IsSideEffect(eff.type) and eff.magnitude) then
                eff.magnitude = math.Round(eff.magnitude * sPotency, 2)
            end
        end
    end

    -- Inject mild sides if stability is bad and none exist
    if (stability < cfg.minor) then
        local hasSides = false
        for _, eff in ipairs(effects) do
            if (ix.bacta.IsSideEffect(eff.type)) then hasSides = true break end
        end
        if (!hasSides) then
            effects[#effects + 1] = {type = "side_nausea", magnitude = 0.08, duration = 10, immediate = false}
        end
    end

    return false
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MAIN SYNTHESIS RESOLUTION
-- ═══════════════════════════════════════════════════════════════════════════════

--- Resolve a compound sequence into its full output profile.
-- v2.1: Discovery value = registered value (no variance on registration).
-- v2.2: Integrates cascade resolution, tuning strands, chain purity.
-- @param sequence table Ordered array of strand IDs
-- @param bDiscovery bool Whether this is a discovery run (informational only)
-- @return table effects Resolved effects array
-- @return number stability Final stability score (0-100)
-- @return number totalPotency Sum of all effect magnitudes
-- @return bool bContaminated Whether the output is contaminated
-- @return table cascadeResult Metabolic cascade result
-- @return table flags Synthesis flags (degradationReduction, etc.)
function ix.bacta.ResolveSequence(sequence, bDiscovery)
    local cfg         = ix.bacta.Config
    local stability   = {value = cfg.STABILITY_BASE}
    local effects     = {}
    local activeCount = 0
    local flags       = {
        suppressVariance = false,
        lockPotency = false,
        degradationReduction = 0,
        tailsSuppressed = false,
        criticalThreshold = nil,
        criticalBonus = nil,
        stackBypass = nil,
    }

    -- ─── Pass 1: Collect base effects and stability ──────────────────────
    for _, strandID in ipairs(sequence) do
        local strand = ix.bacta.GetStrand(strandID)
        if (!strand) then continue end

        stability.value = stability.value + (strand.stability_mod or 0)

        if (strand.category == "active") then
            activeCount = activeCount + 1
        end

        for _, eff in ipairs(strand.effects or {}) do
            effects[#effects + 1] = table.Copy(eff)
        end
    end

    -- Active agent overload penalty
    stability.value = stability.value - (cfg.ACTIVE_OVERLOAD_PEN * math.max(0, activeCount - 2))

    -- ─── Pass 2: Directional adjacency checks (v2.1) ────────────────────
    for i = 1, #sequence - 1 do
        ix.bacta.CheckDirectionalAdjacency(sequence[i], sequence[i + 1], effects, stability)
    end

    -- ─── Pass 3: Stabiliser specials ─────────────────────────────────────
    for _, strandID in ipairs(sequence) do
        local strand = ix.bacta.GetStrand(strandID)
        if (strand and strand.category == "stabiliser" and strand.subcategory != "metaboliser") then
            ApplyStabiliserSpecial(strandID, effects, flags)
        end
    end

    -- ─── Pass 4: Catalyst global effects ─────────────────────────────────
    for _, strandID in ipairs(sequence) do
        local strand = ix.bacta.GetStrand(strandID)
        if (strand and strand.category == "catalyst") then
            ApplyCatalyst(strandID, effects, stability)
        end
    end

    -- ─── Pass 5: Modifier application ────────────────────────────────────
    for _, strandID in ipairs(sequence) do
        local strand = ix.bacta.GetStrand(strandID)
        if (strand and strand.category == "modifier" and strand.subcategory != "tuning") then
            ApplyModifier(strandID, effects, flags)
        end
    end

    -- ─── Pass 6: Metabolic cascade resolution (v2.2) ─────────────────────
    local cascadeResult = ix.bacta.ResolveCascade(sequence)

    -- ─── Pass 7: Tuning strand application (v2.2) ────────────────────────
    ApplyTuningStrands(sequence, effects, flags, cascadeResult)

    -- ─── Pass 8: Chain Purity bonus ──────────────────────────────────────
    if (!cascadeResult.suppressed and cascadeResult.chainPurity > 0) then
        for _, eff in ipairs(effects) do
            if (!ix.bacta.IsSideEffect(eff.type) and eff.magnitude) then
                eff.magnitude = ix.bacta.ApplyChainPurityBonus(eff.magnitude, cascadeResult.chainPurity)
            end
        end
    end

    -- ─── Pass 9: Clamp stability ─────────────────────────────────────────
    stability.value = math.Clamp(stability.value, 0, 100)

    -- ─── Pass 10: Stability-driven adverse effect injection ──────────────
    local bContaminated = false
    if (stability.value < cfg.STABILITY_THRESHOLDS.minor) then
        bContaminated = InjectAdverseEffects(stability.value, effects)
    elseif (stability.value >= cfg.STABILITY_THRESHOLDS.clean) then
        -- Clean synthesis: strip non-tail side effects
        for i = #effects, 1, -1 do
            if (ix.bacta.IsSideEffect(effects[i].type) and !ix.bacta.IsTailEffect(effects[i].type)) then
                table.remove(effects, i)
            end
        end
    end

    -- ─── Pass 11: Calculate total potency (v2.1: NO discovery variance) ──
    -- Registered value = discovered value. No calibration drift.
    local totalPotency = 0
    for _, eff in ipairs(effects) do
        if (eff.magnitude) then
            totalPotency = totalPotency + math.abs(eff.magnitude)
        end
    end

    return effects, stability.value, totalPotency, bContaminated, cascadeResult, flags
end

--- Validate that a submitted sequence only contains strands from the player's session pool.
-- @param client Entity The player
-- @param sequence table Submitted strand ID array
-- @return bool Whether the sequence is valid for this session
function ix.bacta.ValidateSessionPool(client, sequence)
    local session = ix.bacta.sessions[client]
    if (!session) then return false end

    local poolSet = {}
    for _, id in ipairs(session.poolFlat) do
        poolSet[id] = true
    end

    for _, strandID in ipairs(sequence) do
        if (!poolSet[strandID]) then
            return false
        end
    end

    return true
end
