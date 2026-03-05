--- Recipe Data Structures & Helpers (v2.0/2.1/2.2)
-- Shared recipe validation, cost calculation, and utility functions.
-- v2.0: Metaboliser strands count in stabiliser slots.
-- v2.1: Tuning strands count in modifier slots (max 2 tuning total).
-- v2.2: Cascade summary in recipe/canister data.
-- @module ix.bacta.recipes

--- Validate that a sequence array is structurally correct.
-- Checks strand IDs, category rules, and length.
-- v2.0: Metabolisers count toward stabiliser cap.
-- v2.1: Tuning strands count toward modifier cap (max 2).
-- @param sequence table Ordered array of strand ID strings
-- @return bool isValid
-- @return string|nil errorMessage
function ix.bacta.ValidateSequence(sequence)
    if (!istable(sequence)) then
        return false, "Sequence must be a table."
    end

    local cfg = ix.bacta.Config
    local len = #sequence

    if (len < 1) then
        return false, "Sequence must contain at least one strand."
    end

    if (len > cfg.MAX_SEQUENCE_LENGTH) then
        return false, "Sequence exceeds maximum length of " .. cfg.MAX_SEQUENCE_LENGTH .. "."
    end

    local baseCount        = 0
    local catalystCount    = 0
    local modifierCount    = 0
    local stabiliserCount  = 0
    local metaboliserCount = 0
    local tuningCount      = 0
    local activeCount      = 0
    local seen             = {}

    for i, strandID in ipairs(sequence) do
        if (!isstring(strandID)) then
            return false, "Invalid strand at position " .. i .. "."
        end

        local strand = ix.bacta.GetStrand(strandID)
        if (!strand) then
            return false, "Unknown strand ID: " .. strandID
        end

        -- Prevent duplicate strand usage
        if (seen[strandID]) then
            return false, "Duplicate strand: " .. strand.name
        end
        seen[strandID] = true

        if (strand.category == "base") then
            baseCount = baseCount + 1
        elseif (strand.category == "catalyst") then
            catalystCount = catalystCount + 1
        elseif (strand.category == "modifier") then
            modifierCount = modifierCount + 1
        elseif (strand.category == "stabiliser") then
            stabiliserCount = stabiliserCount + 1
        elseif (strand.category == "active") then
            activeCount = activeCount + 1
        end

        -- v2.0: Metabolisers count toward stabiliser cap
        if (ix.bacta.IsMetaboliser and ix.bacta.IsMetaboliser(strandID)) then
            metaboliserCount = metaboliserCount + 1
        end

        -- v2.1: Tuning strands count toward modifier cap
        if (ix.bacta.IsTuningStrand and ix.bacta.IsTuningStrand(strandID)) then
            tuningCount = tuningCount + 1
        end
    end

    if (baseCount != 1) then
        return false, "Sequence must contain exactly one Base Compound (found " .. baseCount .. ")."
    end

    if (catalystCount > 2) then
        return false, "Maximum of 2 Catalysts allowed (found " .. catalystCount .. ")."
    end

    -- Modifiers + tuning strands share a cap
    local totalModSlots = modifierCount + tuningCount
    if (totalModSlots > (cfg.MAX_MODIFIERS or 2)) then
        return false, "Maximum of " .. (cfg.MAX_MODIFIERS or 2) .. " Modifiers/Tuning allowed (found " .. totalModSlots .. ")."
    end

    -- Tuning-specific cap
    if (tuningCount > (cfg.MAX_TUNING or 2)) then
        return false, "Maximum of " .. (cfg.MAX_TUNING or 2) .. " Tuning strands allowed (found " .. tuningCount .. ")."
    end

    -- Stabilisers + metabolisers share a cap
    local totalStabSlots = stabiliserCount + metaboliserCount
    if (totalStabSlots > (cfg.MAX_STABILISERS or 3)) then
        return false, "Maximum of " .. (cfg.MAX_STABILISERS or 3) .. " Stabilisers/Metabolisers allowed (found " .. totalStabSlots .. ")."
    end

    return true, nil
end

--- Calculate the production cost for a sequence.
-- v2.0: Metaboliser strands have slightly higher cost weight.
-- v2.1: Tuning strands add a fixed surcharge.
-- @param sequence table Ordered array of strand IDs
-- @param totalPotency number Sum of all effect magnitudes (normalised 0-100)
-- @return number Final SGC cost
function ix.bacta.CalcProductionCost(sequence, totalPotency)
    local cfg = ix.bacta.Config
    local baseWeight = 0
    local tuningSurcharge = 0

    for _, strandID in ipairs(sequence) do
        local strand = ix.bacta.GetStrand(strandID)
        if (strand) then
            baseWeight = baseWeight + strand.cost_weight

            -- Tuning strands add a flat surcharge
            if (ix.bacta.IsTuningStrand and ix.bacta.IsTuningStrand(strandID)) then
                tuningSurcharge = tuningSurcharge + (strand.cost_weight * 0.5)
            end
        end
    end

    local seqLen       = #sequence
    local complexMult  = 1 + (cfg.COMPLEXITY_PEN_RATE * math.max(0, seqLen - cfg.COMPLEXITY_PEN_AFTER))
    local potencyScore = math.Clamp(totalPotency or 0, 0, 100)
    local potencyMult  = 1 + (potencyScore / 100)

    return math.floor((baseWeight + tuningSurcharge) * complexMult * potencyMult)
end

--- Determine the item type from a sequence.
-- Bases set the default; modifiers can override.
-- @param sequence table Ordered array of strand IDs
-- @return string item_type ("injector", "aerosol", "patch", "capsule")
function ix.bacta.DetermineItemType(sequence)
    local itemType = "injector" -- fallback

    for _, strandID in ipairs(sequence) do
        local strand = ix.bacta.GetStrand(strandID)
        if (!strand) then continue end

        -- Base sets the default
        if (strand.category == "base" and strand.item_type) then
            itemType = strand.item_type
        end

        -- Modifier overrides
        if (strand.modifier_effect and strand.modifier_effect.type == "change_item_type") then
            itemType = strand.modifier_effect.item_type
        end
    end

    return itemType
end

--- Determine the number of uses for the output item.
-- @param sequence table Ordered array of strand IDs
-- @return number Number of uses (1-3)
function ix.bacta.DetermineUses(sequence)
    local uses = 1

    for _, strandID in ipairs(sequence) do
        local strand = ix.bacta.GetStrand(strandID)
        if (!strand) then continue end

        if (strand.modifier_effect and strand.modifier_effect.type == "add_uses") then
            uses = math.min(strand.modifier_effect.max or 3, uses + strand.modifier_effect.value)
        end
    end

    return uses
end

--- Build a recipe table from synthesis results.
-- v2.2: Includes cascade summary and flags.
-- @param name string Player-assigned formula name
-- @param sequence table Strand ID array
-- @param effects table Resolved effects array
-- @param stability number Stability score
-- @param totalPotency number Total potency score
-- @param steamID string Registering player's Steam ID
-- @param cascadeResult table|nil Cascade resolution result
-- @param flags table|nil Synthesis flags
-- @return table Recipe table
function ix.bacta.BuildRecipe(name, sequence, effects, stability, totalPotency, steamID, cascadeResult, flags)
    local itemType = ix.bacta.DetermineItemType(sequence)
    local uses     = ix.bacta.DetermineUses(sequence)
    local cost     = ix.bacta.CalcProductionCost(sequence, totalPotency)

    local cascadeSummary = cascadeResult and ix.bacta.CascadeSummary(cascadeResult) or nil
    local chainDepth = cascadeResult and cascadeResult.chainDepth or 0
    local chainPurity = cascadeResult and cascadeResult.chainPurity or 1.0

    return {
        name           = name,
        flavour        = "",
        sequence       = sequence,
        output         = {
            effects        = effects,
            stability      = stability,
            totalPotency   = totalPotency,
            item_type      = itemType,
            uses           = uses,
        },
        cost_base      = cost,
        registered_by  = steamID,
        timestamp      = os.time(),
        cascadeSummary = cascadeSummary,
        chainDepth     = chainDepth,
        chainPurity    = chainPurity,
        flags          = flags or {},
    }
end

--- Get a short summary string for a recipe.
-- v2.2: Includes cascade/tail information.
-- @param recipe table Recipe data
-- @return string Summary
function ix.bacta.RecipeSummary(recipe)
    if (!recipe or !recipe.output) then return "Invalid recipe" end

    local lines = {}
    local out   = recipe.output

    lines[#lines + 1] = "Formula: " .. (recipe.name or "Unknown")
    lines[#lines + 1] = "Type: " .. string.upper(out.item_type or "injector")
    lines[#lines + 1] = "Uses: " .. (out.uses or 1)
    lines[#lines + 1] = "Integrity: " .. (out.stability or "?") .. "/100"
    lines[#lines + 1] = "Cost: " .. (recipe.cost_base or "?") .. " SGC"

    -- v2.1: Chain metrics
    if (recipe.chainDepth and recipe.chainDepth > 0) then
        lines[#lines + 1] = "Chain Depth: " .. recipe.chainDepth
        lines[#lines + 1] = "Chain Purity: " .. math.Round((recipe.chainPurity or 1.0) * 100) .. "%"
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Effects:"
    for _, eff in ipairs(out.effects or {}) do
        lines[#lines + 1] = "  " .. ix.bacta.EffectToString(eff)
    end

    -- v2.2: Cascade/tail summary
    if (recipe.cascadeSummary) then
        local cs = recipe.cascadeSummary
        if (cs.tails and #cs.tails > 0) then
            lines[#lines + 1] = ""
            lines[#lines + 1] = "Tail Effects:"
            for _, tail in ipairs(cs.tails) do
                local status = tail.resolved and "[RESOLVED]" or "[UNRESOLVED]"
                local tailType = ix.bacta.effectTypes[tail.tail_type]
                local tailName = tailType and tailType.name or tail.tail_type
                lines[#lines + 1] = "  " .. status .. " " .. tailName .. " (delay: " .. (tail.delay or "?") .. "s)"
            end
        end
        if (cs.suppressed) then
            lines[#lines + 1] = "  [ALL TAILS SUPPRESSED]"
        end
    end

    -- v2.0: Flags
    if (recipe.flags) then
        local flagLines = {}
        if (recipe.flags.criticalThreshold) then
            flagLines[#flagLines + 1] = "Critical Threshold: HP <= " .. math.Round(recipe.flags.criticalThreshold * 100) .. "%"
        end
        if (recipe.flags.stackBypass) then
            flagLines[#flagLines + 1] = "Stack Bypass: Yes"
        end
        if (#flagLines > 0) then
            lines[#lines + 1] = ""
            lines[#lines + 1] = "Flags:"
            for _, fl in ipairs(flagLines) do
                lines[#lines + 1] = "  " .. fl
            end
        end
    end

    return table.concat(lines, "\n")
end
