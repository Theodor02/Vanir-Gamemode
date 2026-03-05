--- Formula Canister Item (v2.0/2.1/2.2)
-- Physical item that stores a synthesised formula.
-- Replaces character-data formula storage with a tangible, tradeable object.
-- Tracks durability, test credits, status promotion, and cascade metadata.
-- @item synth_canister

ITEM.name        = "Formula Canister"
ITEM.description = "A sealed canister containing a synthesised formula blueprint."
ITEM.model       = "models/props_lab/jar01a.mdl"
ITEM.category    = "Medical Compounds"
ITEM.width       = 1
ITEM.height      = 1
ITEM.weight      = 0.5

-- ═══════════════════════════════════════════════════════════════════════════════
-- DYNAMIC DESCRIPTION
-- ═══════════════════════════════════════════════════════════════════════════════

function ITEM:GetDescription()
    local lines = {}

    lines[#lines + 1] = "Formula: " .. (self:GetData("formulaName") or "Unnamed")
    lines[#lines + 1] = "Synthesist: " .. (ix.bacta.FindPlayerBySteamID and
        (function()
            local ply = ix.bacta.FindPlayerBySteamID(self:GetData("fabricated_by", ""))
            return IsValid(ply) and (ply:GetCharacter() and ply:GetCharacter():GetName() or ply:Nick()) or self:GetData("fabricated_by", "Unknown")
        end)() or self:GetData("fabricated_by", "Unknown"))

    -- Status badge
    local status = self:GetData("status", "experimental")
    local statusColors = {
        experimental = "[EXPERIMENTAL]",
        tested       = "[TESTED]",
        proven       = "[PROVEN]",
    }
    lines[#lines + 1] = "Status: " .. (statusColors[status] or string.upper(status))
    lines[#lines + 1] = "Test Credits: " .. (self:GetData("test_count", 0))

    lines[#lines + 1] = ""

    -- Durability bar
    local durability = self:GetData("durability", 100)
    lines[#lines + 1] = "Durability: " .. durability .. "/100"
    if (durability <= 25) then
        lines[#lines + 1] = "⚠ LOW DURABILITY — Integrity check required before fabrication."
    end

    -- Core stats
    lines[#lines + 1] = "Integrity: " .. (self:GetData("stability", 0)) .. "/100"
    lines[#lines + 1] = "Potency: " .. math.Round(self:GetData("totalPotency", 0), 1)
    lines[#lines + 1] = "Type: " .. string.upper(self:GetData("item_type", "injector"))
    lines[#lines + 1] = "Uses/Dose: " .. (self:GetData("uses", 1))

    -- Chain metrics
    local chainDepth = self:GetData("chainDepth", 0)
    if (chainDepth > 0) then
        lines[#lines + 1] = "Chain Depth: " .. chainDepth
        lines[#lines + 1] = "Chain Purity: " .. math.Round((self:GetData("chainPurity", 1) * 100)) .. "%"
    end

    lines[#lines + 1] = ""

    -- Effects list
    local effects = self:GetData("effects", {})
    if (#effects > 0) then
        lines[#lines + 1] = "Effects:"
        for _, eff in ipairs(effects) do
            local isTail = ix.bacta.IsTailEffect and ix.bacta.IsTailEffect(eff.type) or false
            local isSide = ix.bacta.IsSideEffect(eff.type)
            local prefix
            if (isTail) then
                prefix = "  ⏱ "
            elseif (isSide) then
                prefix = "  ⚠ "
            else
                prefix = "  • "
            end
            lines[#lines + 1] = prefix .. ix.bacta.EffectToString(eff)
        end
    end

    -- Cascade summary
    local cs = self:GetData("cascadeSummary")
    if (cs and cs.tails and #cs.tails > 0) then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Metabolic Cascade:"
        for _, tail in ipairs(cs.tails) do
            local res = tail.resolved and "[RESOLVED]" or "[UNRESOLVED]"
            local tailType = ix.bacta.effectTypes[tail.tail_type]
            local tailName = tailType and tailType.name or tail.tail_type
            lines[#lines + 1] = "  " .. res .. " " .. tailName .. " (delay: " .. (tail.delay or "?") .. "s)"
        end
        if (cs.suppressed) then
            lines[#lines + 1] = "  [ALL TAILS SUPPRESSED]"
        end
    end

    -- Flags
    local flags = self:GetData("flags", {})
    local flagLines = {}
    if (flags.criticalThreshold) then
        flagLines[#flagLines + 1] = "Critical Threshold: HP <= " .. math.Round(flags.criticalThreshold * 100) .. "%"
    end
    if (flags.stackBypass) then
        flagLines[#flagLines + 1] = "Stack Bypass: Yes"
    end
    if (flags.degradationReduction and flags.degradationReduction > 0) then
        flagLines[#flagLines + 1] = "Degradation Reduction: " .. math.Round(flags.degradationReduction * 100) .. "%"
    end
    if (#flagLines > 0) then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Properties:"
        for _, fl in ipairs(flagLines) do
            lines[#lines + 1] = "  " .. fl
        end
    end

    -- Sequence preview
    local sequence = self:GetData("sequence", {})
    if (#sequence > 0) then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Sequence (" .. #sequence .. " strands):"
        for i, strandID in ipairs(sequence) do
            local strand = ix.bacta.GetStrand(strandID)
            local name = strand and strand.name or strandID
            lines[#lines + 1] = "  " .. i .. ". " .. name
        end
    end

    return table.concat(lines, "\n")
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- ITEM FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Fabricate a batch from this canister.
ITEM.functions.Fabricate = {
    name = "Fabricate Batch",
    tip  = "Produce a batch of compounds from this formula.",
    icon = "icon16/cog.png",
    OnRun = function(item)
        local client = item.player
        if (!IsValid(client)) then return false end

        local ok, err = ix.bacta.FabricateFromCanister(client, item.id, false)
        if (!ok and err) then
            client:Notify("Fabrication failed: " .. err)
        end

        return false -- Never consume the canister from fabrication
    end,
    OnCanRun = function(item)
        return item:GetData("durability", 100) > 0
    end,
}

--- Refine the canister to improve stability.
ITEM.functions.Refine = {
    name = "Refine",
    tip  = "Spend SGC to improve the formula's stability.",
    icon = "icon16/wand.png",
    OnRun = function(item)
        local client = item.player
        if (!IsValid(client)) then return false end

        local ok, err = ix.bacta.RefineCanister(client, item.id)
        if (!ok) then
            client:Notify("Refinement failed: " .. (err or "Unknown error."))
        end

        return false
    end,
    OnCanRun = function(item)
        local maxStab = (ix.bacta.Config.REFINEMENT or {}).max_stability or 100
        return item:GetData("stability", 50) < maxStab
    end,
}

--- View the full formula summary.
ITEM.functions.Inspect = {
    name = "Inspect Formula",
    tip  = "View detailed formula information.",
    icon = "icon16/magnifier.png",
    OnRun = function(item)
        -- This is handled client-side via the description
        return false
    end,
}

--- Transfer ownership (drop the canister — default Helix behaviour).
-- The canister is a normal item and can be dropped/traded.
