--- Server-side effect application logic.
-- Weighted random selection and limit tracking for bracket effects.
-- @module ix.hacking (server)

ix.hacking = ix.hacking or {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════════════════════

local function DecrementLimit(session, key)
    if (!key) then return end
    local val = session.effectLimits[key]
    if (type(val) == "number" and val > 0) then
        session.effectLimits[key] = val - 1
    end
end

local function GetLimit(session, key)
    if (!key) then return nil end
    return session.effectLimits[key]
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SELECTION
-- ═══════════════════════════════════════════════════════════════════════════════

--- Select and apply a random eligible effect for a bracket token.
-- @param session table
-- @param token table
-- @return string effectId
-- @return table effectPayload
function ix.hacking.Effects.ApplySelection(session, token)
    local R = ix.hacking.Effects.Registry
    local candidates  = {}
    local totalWeight = 0

    -- Check total limit
    if (session.effectLimits.total ~= nil and session.effectLimits.total <= 0) then
        return "none", {reason = "limit_total"}
    end

    -- Build candidate list
    for id, def in pairs(R) do
        local allowed = true
        local limitKey  = def.limit_key or id
        local remaining = GetLimit(session, limitKey)

        if (remaining ~= nil and remaining <= 0) then
            allowed = false
        end

        if (allowed and def.canApply) then
            if (!def.canApply(session, token)) then
                allowed = false
            end
        end

        if (allowed) then
            table.insert(candidates, {id = id, weight = def.weight or 1})
            totalWeight = totalWeight + (def.weight or 1)
        end
    end

    -- Weighted pick with retry on apply failure
    while (#candidates > 0) do
        if (totalWeight <= 0) then break end

        local roll    = math.random() * totalWeight
        local current = 0
        local selectedIdx
        local selectedEntry

        for i, c in ipairs(candidates) do
            current = current + c.weight
            if (roll <= current) then
                selectedIdx   = i
                selectedEntry = c
                break
            end
        end

        if (!selectedEntry) then
            selectedIdx   = #candidates
            selectedEntry = candidates[#candidates]
        end

        local def = R[selectedEntry.id]
        local success, payload = def.apply(session, token, {})

        if (success) then
            local limitKey = def.limit_key or def.id
            DecrementLimit(session, limitKey)

            if (def.consumes_total_limit ~= false) then
                DecrementLimit(session, "total")
            end

            return def.id, payload or {}
        else
            table.remove(candidates, selectedIdx)
            totalWeight = totalWeight - selectedEntry.weight
        end
    end

    return "none", {reason = "exhausted"}
end
