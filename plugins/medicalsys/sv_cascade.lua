--- Metabolic Cascade Resolution (v2.2)
-- Chain resolution algorithm for tail effects and metaboliser strands.
-- Processes the sequence to determine which tails fire, which are metabolised,
-- and computes Chain Depth and Chain Purity metrics.
-- @module ix.bacta.cascade

-- ═══════════════════════════════════════════════════════════════════════════════
-- TAIL QUEUE BUILDING
-- Scans the sequence and collects all pending tail effects from strands
-- that have tail_effect fields.
-- ═══════════════════════════════════════════════════════════════════════════════

--- Build the initial tail queue from a sequence.
-- Each entry records the source strand, the tail type, and its parameters.
-- @param sequence table Ordered strand ID array
-- @return table Array of {source, tail_type, delay, duration, severity, position}
local function BuildTailQueue(sequence)
    local queue = {}

    for i, strandID in ipairs(sequence) do
        local strand = ix.bacta.GetStrand(strandID)
        if (!strand) then continue end

        if (strand.tail_effect) then
            queue[#queue + 1] = {
                source    = strandID,
                tail_type = strand.tail_effect,
                delay     = strand.tail_delay or 5,
                duration  = strand.tail_duration or 10,
                severity  = strand.tail_severity or "low",
                position  = i,
                resolved  = false,
            }
        end
    end

    return queue
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- METABOLISER RESOLUTION
-- Forward pass: each metaboliser neutralises the tail of the NEAREST preceding
-- strand whose tail type matches the metaboliser's `metabolises` field.
-- A metaboliser can only neutralise one tail.
-- ═══════════════════════════════════════════════════════════════════════════════

--- Resolve metaboliser strands against the tail queue.
-- Metabolisers act on the nearest matching tail BEFORE them in sequence.
-- @param sequence table Ordered strand ID array
-- @param tailQueue table Mutable tail queue from BuildTailQueue
-- @return table Array of {metaboliserID, resolved_tail, met_tail} for resolved entries
-- @return table Array of met_tail entries to add to the queue
local function ResolveMetabolisers(sequence, tailQueue)
    local resolutions = {}
    local newTails = {}

    for i, strandID in ipairs(sequence) do
        local strand = ix.bacta.GetStrand(strandID)
        if (!strand or strand.subcategory != "metaboliser") then continue end

        local targetTail = strand.metabolises
        if (!targetTail) then continue end

        -- Find nearest unresolved tail BEFORE this position that matches
        local bestIdx = nil
        local bestDist = math.huge

        for qIdx, entry in ipairs(tailQueue) do
            if (!entry.resolved and entry.tail_type == targetTail and entry.position < i) then
                local dist = i - entry.position
                if (dist < bestDist) then
                    bestDist = dist
                    bestIdx = qIdx
                end
            end
        end

        if (bestIdx) then
            -- Neutralise the tail
            tailQueue[bestIdx].resolved = true

            resolutions[#resolutions + 1] = {
                metaboliser   = strandID,
                resolved_tail = tailQueue[bestIdx].source,
                tail_type     = targetTail,
            }

            -- Add the metaboliser's own tail (if any)
            if (strand.met_tail) then
                newTails[#newTails + 1] = {
                    source    = strandID,
                    tail_type = strand.met_tail.type,
                    delay     = strand.met_tail.delay or 5,
                    duration  = strand.met_tail.duration or 8,
                    severity  = strand.met_tail.severity or "low",
                    position  = i,
                    resolved  = false,
                    is_met_tail = true,
                }
            end
        end
    end

    -- Add metaboliser tails to the queue for potential further resolution
    for _, entry in ipairs(newTails) do
        tailQueue[#tailQueue + 1] = entry
    end

    return resolutions, newTails
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TUNING STRAND SUPPRESSION CHECK
-- If tun_sel_suppress_tails is present, suppress ALL tails.
-- ═══════════════════════════════════════════════════════════════════════════════

--- Check if the sequence contains a tail gate suppressor.
-- @param sequence table Ordered strand ID array
-- @return bool
local function HasTailSuppressor(sequence)
    for _, strandID in ipairs(sequence) do
        local strand = ix.bacta.GetStrand(strandID)
        if (strand and strand.tuning_effect and strand.tuning_effect.type == "suppress_all_tails") then
            return true
        end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CHAIN METRICS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Calculate Chain Depth — total number of tail entries (original + metaboliser-introduced).
-- @param tailQueue table The complete tail queue
-- @return number Chain depth
local function CalcChainDepth(tailQueue)
    return #tailQueue
end

--- Calculate Chain Purity — ratio of resolved tails to total tails.
-- 1.0 = every tail was metabolised (or suppressed). 0.0 = no tails resolved.
-- @param tailQueue table The complete tail queue
-- @return number Chain purity (0.0 to 1.0)
local function CalcChainPurity(tailQueue)
    if (#tailQueue == 0) then return 1.0 end

    local resolvedCount = 0
    for _, entry in ipairs(tailQueue) do
        if (entry.resolved) then
            resolvedCount = resolvedCount + 1
        end
    end

    return resolvedCount / #tailQueue
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MAIN CASCADE RESOLUTION
-- ═══════════════════════════════════════════════════════════════════════════════

--- Resolve the complete metabolic cascade for a compound sequence.
-- Returns resolved tail state, metrics, and the scheduled tail list.
-- @param sequence table Ordered strand ID array
-- @return table cascadeResult {
--   tailQueue     = table,       -- Full tail queue with resolved flags
--   resolutions   = table,       -- Which metabolisers resolved which tails
--   unresolvedTails = table,     -- Tails that will fire on the patient
--   chainDepth    = number,      -- Total chain depth
--   chainPurity   = number,      -- Purity ratio 0-1
--   suppressed    = bool,        -- Whether tails are globally suppressed
-- }
function ix.bacta.ResolveCascade(sequence)
    local result = {
        tailQueue       = {},
        resolutions     = {},
        unresolvedTails = {},
        chainDepth      = 0,
        chainPurity     = 1.0,
        suppressed      = false,
    }

    -- Check for global tail suppression
    if (HasTailSuppressor(sequence)) then
        result.suppressed = true
        -- Still build the queue for chain depth metrics
        result.tailQueue = BuildTailQueue(sequence)
        result.chainDepth = CalcChainDepth(result.tailQueue)
        result.chainPurity = 0 -- No purity bonus when suppressed

        -- Mark all as resolved (suppressed)
        for _, entry in ipairs(result.tailQueue) do
            entry.resolved = true
        end

        return result
    end

    -- Build initial tail queue
    result.tailQueue = BuildTailQueue(sequence)

    -- Forward metaboliser pass
    result.resolutions = ResolveMetabolisers(sequence, result.tailQueue)

    -- Calculate metrics
    result.chainDepth = CalcChainDepth(result.tailQueue)
    result.chainPurity = CalcChainPurity(result.tailQueue)

    -- Collect unresolved tails (these will fire on the patient)
    for _, entry in ipairs(result.tailQueue) do
        if (!entry.resolved) then
            result.unresolvedTails[#result.unresolvedTails + 1] = entry
        end
    end

    return result
end

--- Apply the Chain Purity bonus to a potency value.
-- +5% per full 0.20 purity above 0 (max +25% at purity 1.0).
-- @param potency number Base potency value
-- @param chainPurity number Chain purity ratio (0-1)
-- @return number Modified potency
function ix.bacta.ApplyChainPurityBonus(potency, chainPurity)
    local cfg = ix.bacta.Config
    local bonusPerStep = cfg.CHAIN_PURITY_BONUS or 0.05
    local steps = math.floor(chainPurity / 0.20)
    local bonus = 1.0 + (steps * bonusPerStep)

    return math.Round(potency * bonus, 2)
end

--- Schedule all unresolved tail effects on a player.
-- Called during compound application (sv_production.lua).
-- @param client Entity Target player
-- @param cascadeResult table Result from ResolveCascade
function ix.bacta.ScheduleCascadeTails(client, cascadeResult)
    if (!IsValid(client) or cascadeResult.suppressed) then return end

    for _, tail in ipairs(cascadeResult.unresolvedTails) do
        ix.bacta.ScheduleTailEffect(
            client,
            tail.tail_type,
            tail.delay,
            tail.duration,
            tail.severity
        )
    end
end

--- Build a summary table of the cascade for UI display.
-- @param cascadeResult table Result from ResolveCascade
-- @return table {tails = {}, resolutions = {}, depth, purity, suppressed}
function ix.bacta.CascadeSummary(cascadeResult)
    local summary = {
        tails       = {},
        resolutions = {},
        depth       = cascadeResult.chainDepth,
        purity      = cascadeResult.chainPurity,
        suppressed  = cascadeResult.suppressed,
    }

    for _, entry in ipairs(cascadeResult.tailQueue) do
        local strand = ix.bacta.GetStrand(entry.source)
        local tailType = ix.bacta.effectTypes and ix.bacta.effectTypes[entry.tail_type]

        summary.tails[#summary.tails + 1] = {
            source_name = strand and strand.name or entry.source,
            tail_name   = tailType and tailType.name or entry.tail_type,
            tail_type   = entry.tail_type,
            delay       = entry.delay,
            duration    = entry.duration,
            severity    = entry.severity,
            resolved    = entry.resolved,
            is_met_tail = entry.is_met_tail or false,
        }
    end

    for _, res in ipairs(cascadeResult.resolutions) do
        local met = ix.bacta.GetStrand(res.metaboliser)
        summary.resolutions[#summary.resolutions + 1] = {
            metaboliser_name = met and met.name or res.metaboliser,
            resolved_type    = res.tail_type,
        }
    end

    return summary
end
