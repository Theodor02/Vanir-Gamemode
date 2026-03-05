--- Base Fabricated Compound Item (v2.0/2.1/2.2)
-- All synthesised compound items inherit from this base.
-- Contains shared use/apply logic, dynamic description, tail summary,
-- test credit tracking, and experimental broadcast.
-- @item base_synth

ITEM.name        = "Fabricated Compound"
ITEM.description = "A synthesised biochemical compound. Effects vary by formula."
ITEM.model       = "models/props_lab/jar01a.mdl"
ITEM.category    = "Medical Compounds"
ITEM.width       = 1
ITEM.height      = 1
ITEM.weight      = 0.3
ITEM.isBase      = true

-- ═══════════════════════════════════════════════════════════════════════════════
-- DYNAMIC DESCRIPTION
-- ═══════════════════════════════════════════════════════════════════════════════

function ITEM:GetDescription()
    local data = self:GetData("bactaSynthData")
    if (!data) then return self.description end

    local lines = {}

    lines[#lines + 1] = "Formula: " .. (self:GetData("formulaName") or "Unknown Protocol")
    lines[#lines + 1] = "Synthesist: " .. (self:GetData("synthesist") or "Unknown")
    lines[#lines + 1] = "Type: " .. string.upper(data.item_type or "injector")

    -- v2.0: Status badge
    local status = self:GetData("status", "experimental")
    lines[#lines + 1] = "Status: " .. string.upper(status)

    lines[#lines + 1] = ""

    -- Effects
    for _, eff in ipairs(data.effects or {}) do
        local isTail = ix.bacta.IsTailEffect and ix.bacta.IsTailEffect(eff.type) or false
        local isSide = ix.bacta.IsSideEffect(eff.type)
        local prefix
        if (isTail) then
            prefix = "⏱ "
        elseif (isSide) then
            prefix = "⚠ "
        else
            prefix = "• "
        end
        lines[#lines + 1] = prefix .. ix.bacta.EffectToString(eff)
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Integrity: " .. (data.stability or "?") .. "/100"

    -- v2.1: Chain metrics
    if (data.chainDepth and data.chainDepth > 0) then
        lines[#lines + 1] = "Chain Depth: " .. data.chainDepth
        lines[#lines + 1] = "Chain Purity: " .. math.Round((data.chainPurity or 1.0) * 100) .. "%"
    end

    -- v2.0: Fabrication variance
    if (data.varianceMult and data.varianceMult != 1.0) then
        local pct = math.Round((data.varianceMult - 1) * 100)
        local sign = pct >= 0 and "+" or ""
        lines[#lines + 1] = "Variance: " .. sign .. pct .. "%"
    end

    -- v2.0: Critical event badge
    if (data.critEvent) then
        if (data.critEvent == "perfect") then
            lines[#lines + 1] = "★ PERFECT SYNTHESIS"
        elseif (data.critEvent == "resonant") then
            lines[#lines + 1] = "☆ Resonant Batch"
        elseif (data.critEvent == "cascade_failure") then
            lines[#lines + 1] = "⚡ Cascade Failure"
        end
    end

    local uses = self:GetData("bactaUses", data.uses or 1)
    if (uses > 1) then
        lines[#lines + 1] = "Remaining Uses: " .. uses
    end

    -- v2.2: Cascade/tail summary
    local cs = self:GetData("cascadeSummary")
    if (cs and cs.tails and #cs.tails > 0) then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Tail Effects:"
        for _, tail in ipairs(cs.tails) do
            local statusStr = tail.resolved and "[RESOLVED]" or "[UNRESOLVED]"
            local tailType = ix.bacta.effectTypes[tail.tail_type]
            local tailName = tailType and tailType.name or tail.tail_type
            lines[#lines + 1] = "  " .. statusStr .. " " .. tailName
        end
        if (cs.suppressed) then
            lines[#lines + 1] = "  [ALL TAILS SUPPRESSED]"
        end
    end

    return table.concat(lines, "\n")
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- HELPER: Administering logic shared between self/target use
-- ═══════════════════════════════════════════════════════════════════════════════

--- Internal: Apply compound to target and handle bookkeeping.
-- @param item table The item instance
-- @param target Entity The target player receiving effects
-- @param client Entity The player administering
-- @return bool Whether to consume the item
local function AdministerCompound(item, target, client)
    local data = item:GetData("bactaSynthData")
    local cascadeSummary = item:GetData("cascadeSummary")
    local flags = item:GetData("flags", {})

    -- Apply effects with cascade and flags support
    ix.bacta.ApplyItemEffects(target, data, cascadeSummary, flags)

    -- v2.0: Test credit tracking
    if (SERVER) then
        local canisterID = item:GetData("canister_id")
        local status = item:GetData("status", "experimental")

        if (canisterID and status != "proven") then
            -- Don't count self-use for test credits
            if (target != client) then
                ix.bacta.IncrementTestCredit(canisterID, target:SteamID())
            end
        end

        -- v2.0: Experimental broadcast
        if (status == "experimental") then
            ix.bacta.BroadcastExperimentalUse(target, item:GetData("formulaName", "Unknown"), data.effects or {})
        end
    end

    -- Handle uses
    local uses = item:GetData("bactaUses", data.uses or 1)
    uses = uses - 1

    if (uses <= 0) then
        return true -- consume item
    end

    item:SetData("bactaUses", uses)
    return false -- keep item
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- ITEM FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Use the compound on yourself.
ITEM.functions.Use = {
    name = "Administer (Self)",
    tip  = "Administer this compound to yourself.",
    icon = "icon16/heart.png",
    OnRun = function(item)
        local client = item.player
        local data   = item:GetData("bactaSynthData")

        if (!data) then
            client:Notify("This compound has no valid data.")
            return false
        end

        if (!client:Alive()) then
            client:Notify("You cannot use this while incapacitated.")
            return false
        end

        local consume = AdministerCompound(item, client, client)

        client:Notify("Compound administered: " .. (item:GetData("formulaName") or "Unknown"))

        return consume
    end,
}

--- Apply the compound to a player you are looking at.
ITEM.functions.Apply = {
    name = "Administer (Target)",
    tip  = "Administer this compound to the player you are looking at.",
    icon = "icon16/heart_add.png",
    OnRun = function(item)
        local client = item.player
        local data   = item:GetData("bactaSynthData")

        if (!data) then
            client:Notify("This compound has no valid data.")
            return false
        end

        -- Trace for target player
        local trace = client:GetEyeTrace()
        local target = trace.Entity

        if (!IsValid(target) or !target:IsPlayer() or client:GetPos():DistToSqr(target:GetPos()) > 10000) then
            client:Notify("No valid target in range. Look at a player within ~3 metres.")
            return false
        end

        if (!target:Alive()) then
            client:Notify("Target is incapacitated.")
            return false
        end

        local consume = AdministerCompound(item, target, client)

        client:Notify("Compound administered to " .. (target:GetCharacter() and target:GetCharacter():GetName() or target:Nick()))
        target:Notify("You received a compound from " .. (client:GetCharacter() and client:GetCharacter():GetName() or client:Nick()))

        return consume
    end,
}
