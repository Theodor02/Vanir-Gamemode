--- Server-Side Batch Fabrication (v2.0/2.1/2.2)
-- Handles production of synthesised items from canister formulas.
-- v2.0: Fabrication variance, canister degradation, critical batch events.
-- v2.1: Chain depth degradation modifier.
-- v2.2: Metabolic cascade tail scheduling on compound use.
-- @module ix.bacta (server)

--- Active fabrication lock to prevent double-submit.
ix.bacta.fabricating = ix.bacta.fabricating or {}

--- Map of item_type to Helix item uniqueID.
local ITEM_TYPE_MAP = {
    injector = "synth_injector",
    aerosol  = "synth_aerosol",
    patch    = "synth_patch",
    capsule  = "synth_capsule",
}

--- Map of compound status to item base class.
local STATUS_ITEM_MAP = {
    experimental = "synth_experimental",
    tested       = "synth_tested",
    proven       = "synth_proven",
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- FABRICATION VARIANCE (v2.0)
-- Each fabricated item gets a random +/-10% magnitude variance.
-- ═══════════════════════════════════════════════════════════════════════════════

--- Apply per-item fabrication variance to an effects array.
-- @param effects table Effects array (will be deep-copied)
-- @param cfg table Config table
-- @return table Variance-applied effects copy
local function ApplyFabricationVariance(effects, cfg)
    local result = {}
    local varRange = cfg and cfg.FABRICATION_VARIANCE or nil
    local low = (type(varRange) == "table" and tonumber(varRange[1])) or 0.90
    local high = (type(varRange) == "table" and tonumber(varRange[2])) or 1.10

    if (low > high) then
        local tmp = low
        low = high
        high = tmp
    end

    local mult = math.Rand(low, high)

    for _, eff in ipairs(effects) do
        local copy = table.Copy(eff)
        if (copy.magnitude) then
            copy.magnitude = math.Round(copy.magnitude * mult, 2)
        end
        result[#result + 1] = copy
    end

    return result, mult
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CHAIN DEPTH DEGRADATION (v2.1)
-- Compounds with deep cascade chains suffer mild potency loss.
-- ═══════════════════════════════════════════════════════════════════════════════

--- Apply chain depth degradation modifier.
-- @param effects table Mutable effects array
-- @param chainDepth number Chain depth from cascade resolution
-- @param cfg table Config table
local function ApplyChainDepthDegradation(effects, chainDepth, cfg)
    local degradation = cfg.CHAIN_DEPTH_DEGRADATION or {}
    local thresholds = {
        {depth = degradation.threshold_1 or 3, mult = degradation.mult_1 or 0.98},
        {depth = degradation.threshold_2 or 5, mult = degradation.mult_2 or 0.95},
        {depth = degradation.threshold_3 or 8, mult = degradation.mult_3 or 0.90},
    }

    local mult = 1.0
    for _, t in ipairs(thresholds) do
        if (chainDepth >= t.depth) then
            mult = t.mult
        end
    end

    if (mult < 1.0) then
        for _, eff in ipairs(effects) do
            if (eff.magnitude and !ix.bacta.IsTailEffect(eff.type)) then
                eff.magnitude = math.Round(eff.magnitude * mult, 2)
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CRITICAL BATCH EVENTS (v2.0)
-- Rare events during fabrication that modify the output.
-- ═══════════════════════════════════════════════════════════════════════════════

--- Roll for a critical batch event and apply if triggered.
-- @param effects table Mutable effects array (single item)
-- @param cfg table Config table
-- @return string|nil Event type if triggered, nil otherwise
local function RollCriticalEvent(effects, cfg)
    local events = cfg.CRITICAL_EVENTS or {}
    local roll = math.random()

    -- Perfect Synthesis (0.5%) — all magnitudes doubled, all sides removed
    local perfectChance = events.perfect_chance or 0.005
    if (roll <= perfectChance) then
        for i = #effects, 1, -1 do
            if (ix.bacta.IsSideEffect(effects[i].type)) then
                table.remove(effects, i)
            end
        end
        for _, eff in ipairs(effects) do
            if (eff.magnitude) then
                eff.magnitude = math.Round(eff.magnitude * 2.0, 2)
            end
        end
        return "perfect"
    end

    -- Resonant Batch (5%) — all beneficial magnitudes +20%
    local resonantChance = events.resonant_chance or 0.05
    if (roll <= perfectChance + resonantChance) then
        for _, eff in ipairs(effects) do
            if (!ix.bacta.IsSideEffect(eff.type) and eff.magnitude) then
                eff.magnitude = math.Round(eff.magnitude * 1.20, 2)
            end
        end
        return "resonant"
    end

    -- Cascade Failure (3%) — all magnitudes -30%, inject tremor
    local cascadeChance = events.cascade_chance or 0.03
    if (roll <= perfectChance + resonantChance + cascadeChance) then
        for _, eff in ipairs(effects) do
            if (eff.magnitude) then
                eff.magnitude = math.Round(eff.magnitude * 0.70, 2)
            end
        end
        effects[#effects + 1] = {type = "side_tremor", magnitude = 2, duration = 10, immediate = false}
        return "cascade_failure"
    end

    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CANISTER DEGRADATION (v2.0)
-- Each fabrication batch reduces the canister's durability.
-- ═══════════════════════════════════════════════════════════════════════════════

--- Degrade a canister item's durability after fabrication.
-- @param canisterItem table Helix item instance
-- @param degradationReduction number Reduction from stabiliser/modifier (0-1)
-- @param cfg table Config table
-- @return number New durability
-- @return bool Whether canister is still usable
local function DegradeCanister(canisterItem, degradationReduction, cfg)
    local degradation = cfg.DEGRADATION_THRESHOLDS or {}
    local baseDeg = degradation.per_batch or 10

    -- Apply reduction from Preservation Coating / Stabilised Matrix
    local actualDeg = math.Round(baseDeg * (1 - math.Clamp(degradationReduction, 0, 0.90)), 1)

    local currentDur = canisterItem:GetData("durability", 100)
    local newDur = math.max(0, currentDur - actualDeg)

    canisterItem:SetData("durability", newDur)

    return newDur, newDur > 0
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- PRODUCTION INTEGRITY CHECK (v2.2)
-- ═══════════════════════════════════════════════════════════════════════════════

--- Check if a production run should trigger an integrity check.
-- Returns true if conditions require player acknowledgement.
-- @param canisterItem table The canister item
-- @param cfg table Config table
-- @return bool Whether integrity check is needed
-- @return string|nil Reason for the check
function ix.bacta.ShouldIntegrityCheck(canisterItem, cfg)
    local integrity = cfg.INTEGRITY_CHECK or {}

    local durability = canisterItem:GetData("durability", 100)
    local threshold = integrity.durability_threshold or 25

    if (durability <= threshold) then
        return true, "Canister durability critically low (" .. durability .. "%)."
    end

    return false, nil
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MAIN FABRICATION
-- ═══════════════════════════════════════════════════════════════════════════════

--- Fabricate a batch of items from a canister formula.
-- v2.0: Uses canister items instead of character recipe data.
-- @param client Entity The synthesist player
-- @param canisterItemID number Helix item ID of the canister
-- @param bIntegrityConfirmed bool Whether integrity check was confirmed
-- @return bool Success
-- @return string|nil Error message on failure
function ix.bacta.FabricateFromCanister(client, canisterItemID, bIntegrityConfirmed)
    if (!IsValid(client)) then return false, "Invalid player." end
    if (ix.bacta.fabricating[client]) then return false, "Fabrication already in progress." end

    local char = client:GetCharacter()
    if (!char) then return false, "No active character." end

    local inv = char:GetInventory()
    if (!inv) then return false, "No inventory available." end

    -- Find the canister item
    local canisterItem = ix.item.instances[canisterItemID]
    if (!canisterItem) then return false, "Canister not found." end

    -- Verify ownership
    if (canisterItem:GetOwner() != client) then return false, "You don't own this canister." end

    local sequence = canisterItem:GetData("sequence", {})
    if (#sequence == 0) then return false, "Canister has no formula." end

    -- Check canister durability
    local durability = canisterItem:GetData("durability", 100)
    if (durability <= 0) then return false, "Canister is depleted. Cannot fabricate." end

    local cfg = ix.bacta.Config

    -- Integrity check
    local needsCheck, checkReason = ix.bacta.ShouldIntegrityCheck(canisterItem, cfg)
    if (needsCheck and !bIntegrityConfirmed) then
        -- Send integrity check prompt to client
        net.Start("ixBactaIntegrityCheck")
            net.WriteUInt(canisterItemID, 32)
            net.WriteString(checkReason or "Integrity check required.")
        net.Send(client)
        return false, nil -- Not an error, just needs confirmation
    end

    -- Re-resolve the sequence server-side
    local effects, stability, potency, bContaminated, cascadeResult, flags = ix.bacta.ResolveSequence(sequence, false)
    local cost = ix.bacta.CalcProductionCost(sequence, potency)
    local balance = char:GetData("bactaSGC", 0)

    if (balance < cost) then
        return false, "Insufficient Synth-Grade Compounds. Need " .. cost .. ", have " .. balance .. "."
    end

    -- Weight carry check (v2.2 weight integration)
    local batchSize = cfg.BATCH_SIZE
    local batchWeight = batchSize * 0.3 -- compound item weight
    if (ix.weight and ix.weight.CanCarry) then
        local carry = char:GetData("carry", 0)
        if (!ix.weight.CanCarry(batchWeight, carry, char)) then
            return false, "Cannot carry that much weight. Reduce your load before fabricating."
        end
    end

    -- Lock fabrication
    ix.bacta.fabricating[client] = true

    -- Deduct SGC
    char:SetData("bactaSGC", balance - cost)

    -- Determine output
    local itemType = ix.bacta.DetermineItemType(sequence)
    local uses = ix.bacta.DetermineUses(sequence)
    local status = canisterItem:GetData("status", "experimental")
    local itemID = STATUS_ITEM_MAP[status] or ITEM_TYPE_MAP[itemType] or "synth_injector"

    -- Degrade canister
    local degradReduction = flags.degradationReduction or 0
    local newDur, canisterUsable = DegradeCanister(canisterItem, degradReduction, cfg)

    -- Cascade metrics
    local chainDepth = cascadeResult and cascadeResult.chainDepth or 0
    local chainPurity = cascadeResult and cascadeResult.chainPurity or 1.0

    -- Create batch
    local created = 0
    local criticalEvents = {}

    for i = 1, batchSize do
        -- Per-item fabrication variance
        local itemEffects, varianceMult = ApplyFabricationVariance(effects, cfg)

        -- Chain depth degradation
        if (chainDepth > 0) then
            ApplyChainDepthDegradation(itemEffects, chainDepth, cfg)
        end

        -- Critical event roll
        local critEvent = RollCriticalEvent(itemEffects, cfg)
        if (critEvent) then
            criticalEvents[#criticalEvents + 1] = {batch_index = i, event = critEvent}
        end

        local outputProfile = {
            effects      = itemEffects,
            stability    = stability,
            totalPotency = potency,
            item_type    = itemType,
            uses         = uses,
            chainDepth   = chainDepth,
            chainPurity  = chainPurity,
            varianceMult = varianceMult,
            critEvent    = critEvent,
        }

        -- Build cascade summary for item tooltip
        local cascadeSummary = cascadeResult and ix.bacta.CascadeSummary(cascadeResult) or nil

        local ok = inv:Add(itemID, 1, {
            bactaSynthData   = outputProfile,
            bactaUses        = uses,
            formulaName      = canisterItem:GetData("formulaName", "Unknown Formula"),
            synthesist       = char:GetName(),
            fabricated_by    = client:SteamID(),
            canister_id      = canisterItemID,
            status           = status,
            test_count       = 0,
            cascadeSummary   = cascadeSummary,
            flags            = {
                criticalThreshold = flags.criticalThreshold,
                criticalBonus     = flags.criticalBonus,
                stackBypass       = flags.stackBypass,
            },
        })

        if (ok) then
            created = created + 1
        end
    end

    -- Unlock fabrication
    ix.bacta.fabricating[client] = nil

    if (created == 0) then
        -- Refund SGC (canister degradation still applies — cost of failure)
        char:SetData("bactaSGC", char:GetData("bactaSGC", 0) + cost)
        return false, "Inventory full. Could not create any items. SGC refunded."
    end

    -- Build notification
    local notifyMsg = "Batch fabrication complete: " .. created .. "x " .. (canisterItem:GetData("formulaName", "compound")) .. " produced. " .. cost .. " SGC consumed."

    if (!canisterUsable) then
        notifyMsg = notifyMsg .. " WARNING: Canister depleted!"
    end

    for _, ce in ipairs(criticalEvents) do
        if (ce.event == "perfect") then
            notifyMsg = notifyMsg .. "\n** PERFECT SYNTHESIS on item #" .. ce.batch_index .. "! **"
        elseif (ce.event == "resonant") then
            notifyMsg = notifyMsg .. "\n* Resonant batch on item #" .. ce.batch_index .. "."
        elseif (ce.event == "cascade_failure") then
            notifyMsg = notifyMsg .. "\n! Cascade failure on item #" .. ce.batch_index .. "."
        end
    end

    client:Notify(notifyMsg)

    -- Sync updated balance to client
    net.Start("ixBactaSyncBalance")
        net.WriteUInt(char:GetData("bactaSGC", 0), 16)
    net.Send(client)

    return true, nil
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- LEGACY SUPPORT — FabricateItem wrapper
-- ═══════════════════════════════════════════════════════════════════════════════

--- Legacy fabrication from recipe table (backwards compatibility).
-- @param client Entity The player
-- @param recipe table Recipe table
-- @return bool success
-- @return string|nil error
function ix.bacta.FabricateItem(client, recipe)
    -- For backwards compatibility, treat as a direct fabrication
    if (!IsValid(client)) then return false, "Invalid player." end
    if (ix.bacta.fabricating[client]) then return false, "Fabrication already in progress." end

    local char = client:GetCharacter()
    if (!char) then return false, "No active character." end

    local inv = char:GetInventory()
    if (!inv) then return false, "No inventory available." end

    local effects, stability, potency, _, cascadeResult, flags = ix.bacta.ResolveSequence(recipe.sequence, false)
    local cost = ix.bacta.CalcProductionCost(recipe.sequence, potency)
    local balance = char:GetData("bactaSGC", 0)

    if (balance < cost) then
        return false, "Insufficient Synth-Grade Compounds. Need " .. cost .. ", have " .. balance .. "."
    end

    -- Weight carry check (v2.2 weight integration)
    local batchSize = ix.bacta.Config.BATCH_SIZE
    local batchWeight = batchSize * 0.3
    if (ix.weight and ix.weight.CanCarry) then
        local carry = char:GetData("carry", 0)
        if (!ix.weight.CanCarry(batchWeight, carry, char)) then
            return false, "Cannot carry that much weight. Reduce your load before fabricating."
        end
    end

    ix.bacta.fabricating[client] = true
    char:SetData("bactaSGC", balance - cost)

    local itemType = recipe.output.item_type or "injector"
    local itemID = ITEM_TYPE_MAP[itemType] or "synth_injector"

    local outputProfile = {
        effects      = effects,
        stability    = stability,
        totalPotency = potency,
        item_type    = itemType,
        uses         = ix.bacta.DetermineUses(recipe.sequence),
    }

    local created = 0
    for i = 1, batchSize do
        local itemEffects = ApplyFabricationVariance(effects, ix.bacta.Config)

        local ok = inv:Add(itemID, 1, {
            bactaSynthData = {
                effects      = itemEffects,
                stability    = stability,
                totalPotency = potency,
                item_type    = itemType,
                uses         = outputProfile.uses,
            },
            bactaUses   = outputProfile.uses,
            formulaName = recipe.name or "Unknown Formula",
            synthesist  = char:GetName(),
        })

        if (ok) then created = created + 1 end
    end

    ix.bacta.fabricating[client] = nil

    if (created == 0) then
        char:SetData("bactaSGC", char:GetData("bactaSGC", 0) + cost)
        return false, "Inventory full. Could not create any items. SGC refunded."
    end

    client:Notify("Batch fabrication complete: " .. created .. "x " .. (recipe.name or "compound") .. ". " .. cost .. " SGC consumed.")

    net.Start("ixBactaSyncBalance")
        net.WriteUInt(char:GetData("bactaSGC", 0), 16)
    net.Send(client)

    return true, nil
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- COMPOUND APPLICATION
-- ═══════════════════════════════════════════════════════════════════════════════

--- Apply effect profile from a synthesised item.
-- v2.2: Schedules cascade tail effects after primary effects.
-- @param client Entity Target player
-- @param profile table The bactaSynthData output profile
-- @param cascadeSummary table|nil Cascade summary for tail scheduling
-- @param flags table|nil Synthesis flags (criticalThreshold, stackBypass)
function ix.bacta.ApplyItemEffects(client, profile, cascadeSummary, flags)
    if (!IsValid(client) or !client:Alive()) then return end

    flags = flags or {}

    -- Critical threshold gate check
    if (flags.criticalThreshold) then
        local hpRatio = client:Health() / client:GetMaxHealth()
        local applyBonus = hpRatio <= flags.criticalThreshold

        for _, eff in ipairs(profile.effects or {}) do
            local effectType = ix.bacta.effectTypes[eff.type]
            if (!effectType or !effectType.apply) then continue end

            if (applyBonus and !ix.bacta.IsSideEffect(eff.type) and eff.magnitude) then
                -- Apply critical threshold bonus
                local boostedEff = table.Copy(eff)
                boostedEff.magnitude = math.Round(boostedEff.magnitude * (flags.criticalBonus or 1.50), 2)
                ix.bacta.ApplyEffectDelayed(client, boostedEff)
            elseif (!applyBonus and !ix.bacta.IsSideEffect(eff.type)) then
                -- Above threshold: beneficial effects don't fire
                -- Side effects still fire
            else
                ix.bacta.ApplyEffectDelayed(client, eff)
            end
        end
    else
        -- Standard application
        for _, eff in ipairs(profile.effects or {}) do
            ix.bacta.ApplyEffectDelayed(client, eff)
        end
    end

    -- v2.2: Schedule cascade tails
    if (cascadeSummary and cascadeSummary.tails) then
        for _, tail in ipairs(cascadeSummary.tails) do
            if (!tail.resolved and !cascadeSummary.suppressed) then
                ix.bacta.ScheduleTailEffect(client, tail.tail_type, tail.delay, tail.duration, tail.severity)
            end
        end
    end
end

--- Apply a single effect with optional delay handling.
-- @param client Entity Target player
-- @param eff table Effect instance
function ix.bacta.ApplyEffectDelayed(client, eff)
    local effectType = ix.bacta.effectTypes[eff.type]
    if (!effectType or !effectType.apply) then return end

    if (eff.delay and eff.delay > 0) then
        timer.Simple(eff.delay, function()
            if (IsValid(client) and client:Alive()) then
                effectType.apply(client, eff)
            end
        end)
    elseif (eff.absorption_delay and eff.absorption_delay > 0) then
        timer.Simple(eff.absorption_delay, function()
            if (IsValid(client) and client:Alive()) then
                effectType.apply(client, eff)
            end
        end)
    else
        effectType.apply(client, eff)
    end
end
