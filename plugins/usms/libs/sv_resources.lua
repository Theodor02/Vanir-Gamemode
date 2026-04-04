-- ═══════════════════════════════════════════════════════════════════════════════
-- RESOURCE SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

--- Get a unit's current resources.
-- @param unitID number
-- @return number
function ix.usms.GetResources(unitID)
    local unit = ix.usms.units[unitID]
    return unit and unit.resources or 0
end

--- Set a unit's resources (clamped to 0..cap).
-- @param unitID number
-- @param amount number
-- @param reason string
-- @param actorCharID number|nil
-- @return bool
function ix.usms.SetResources(unitID, amount, reason, actorCharID)
    local unit = ix.usms.units[unitID]
    if (!unit) then return false end

    local oldAmount = unit.resources
    amount = math.Clamp(amount, 0, unit.resourceCap)
    unit.resources = amount

    ix.usms.db.Save()

    ix.usms.Log(unitID, USMS_LOG_UNIT_RESOURCE_CHANGE, actorCharID, nil, {
        oldAmount = oldAmount,
        newAmount = amount,
        delta = amount - oldAmount,
        reason = reason or "unknown"
    })

    ix.usms.SyncResourceToUnit(unitID)
    hook.Run("USMSResourcesChanged", unitID, oldAmount, amount, reason)

    return true
end

--- Add resources to a unit.
-- @param unitID number
-- @param amount number
-- @param reason string
-- @param actorCharID number|nil
-- @return bool
function ix.usms.AddResources(unitID, amount, reason, actorCharID)
    local current = ix.usms.GetResources(unitID)
    return ix.usms.SetResources(unitID, current + amount, reason, actorCharID)
end

--- Deduct resources from a unit. Returns false if insufficient.
-- @param unitID number
-- @param amount number
-- @param reason string
-- @param actorCharID number|nil
-- @return bool
function ix.usms.DeductResources(unitID, amount, reason, actorCharID)
    local current = ix.usms.GetResources(unitID)
    if (current < amount) then return false end
    return ix.usms.SetResources(unitID, current - amount, reason, actorCharID)
end

