--- Default effect definitions for the terminal hacking system.
-- Registered via ix.hacking.Effects.Register().
-- @module ix.hacking (shared)

if (!ix.hacking or !ix.hacking.Effects) then return end

local R = ix.hacking.Effects.Register

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. REMOVE DUD
-- ═══════════════════════════════════════════════════════════════════════════════

R({
    id              = "remove_dud",
    name            = "Remove Dud",
    weight          = 3,
    max_per_session = 2,
    limit_key       = "remove_dud",

    apply = function(session, token, ctx)
        local candidates = {}
        for id, t in pairs(session.tokens) do
            if (t.kind == "word" and t.text ~= session.solution and !t.removed) then
                table.insert(candidates, id)
            end
        end

        if (#candidates == 0) then return false end

        local pickId = candidates[math.random(#candidates)]
        session.tokens[pickId].removed = true

        return true, {targetId = pickId}
    end,

    format = function(payload, ui)
        return "> DUD REMOVED"
    end,

    sfx = {on_apply = "Enter"},

    onResult = function(payload, ui)
        local target = payload.targetId
        local targetT = ui.Session.tokens[target]
        if (!targetT) then return end

        targetT.removed = true

        local lineStr = ui.GridLines[targetT.line]
        local prefix  = string.sub(lineStr, 1, targetT.start - 1)
        local suffix  = string.sub(lineStr, targetT.start + targetT.len)
        local replace = string.rep(".", targetT.len)
        ui.GridLines[targetT.line] = prefix .. replace .. suffix
        targetT.text = replace
    end
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. RESET ATTEMPTS
-- ═══════════════════════════════════════════════════════════════════════════════

R({
    id              = "reset_attempts",
    name            = "Reset Attempts",
    weight          = 1,
    max_per_session = 1,
    limit_key       = "reset_attempts",

    apply = function(session, token)
        session.attempts = 4
        return true, {}
    end,

    format = function(payload, ui)
        return "> ALLOWANCE REPLENISHED"
    end,

    sfx = {on_apply = "Enter"}
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. ATTEMPT INSURANCE
-- ═══════════════════════════════════════════════════════════════════════════════

R({
    id              = "attempt_insurance",
    name            = "Attempt Insurance",
    weight          = 2,
    max_per_session = 1,

    apply = function(session, token)
        session.flags = session.flags or {}
        if (session.flags.insurance) then return false end
        session.flags.insurance = true
        return true, {armed = true}
    end,

    format = function(payload, ui)
        return "> ATTEMPT INSURED"
    end,

    sfx = {on_apply = "Enter"}
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. REVEAL POSITION
-- ═══════════════════════════════════════════════════════════════════════════════

R({
    id              = "reveal_position",
    name            = "Reveal Position",
    weight          = 2,
    max_per_session = 2,

    apply = function(session, token)
        local solution = session.solution
        if (!solution or #solution == 0) then return false end

        local candidates = {}
        for id, t in pairs(session.tokens) do
            if (t.kind == "word" and !t.removed and t.text ~= solution) then
                table.insert(candidates, id)
            end
        end
        if (#candidates == 0) then return false end

        local pickId   = candidates[math.random(#candidates)]
        local pickWord = session.tokens[pickId].text
        if (!pickWord or #pickWord ~= #solution) then return false end

        local pos   = math.random(1, #solution)
        local match = pickWord:sub(pos, pos) == solution:sub(pos, pos)

        return true, {position = pos, isMatch = match}
    end,

    format = function(payload, ui)
        if (payload.isMatch) then
            return "> MATCH @" .. payload.position
        else
            return "> NO MATCH @" .. payload.position
        end
    end,

    sfx = {on_apply = "Enter"}
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. LETTER FREQUENCY
-- ═══════════════════════════════════════════════════════════════════════════════

R({
    id              = "letter_frequency",
    name            = "Letter Frequency",
    weight          = 1,
    max_per_session = 2,

    apply = function(session, token)
        local solution = session.solution
        if (!solution or #solution == 0) then return false end

        local pool = {}
        for _, t in pairs(session.tokens) do
            if (t.kind == "word" and !t.removed) then
                local w = t.text
                if (w and #w > 0) then
                    local pos = math.random(1, #w)
                    local ch  = w:sub(pos, pos)
                    if (ch:match("%u")) then
                        pool[#pool + 1] = ch
                    end
                end
            end
        end
        if (#pool == 0) then return false end

        local letter = pool[math.random(#pool)]
        local count  = 0
        for i = 1, #solution do
            if (solution:sub(i, i) == letter) then count = count + 1 end
        end

        return true, {letter = letter, count = count}
    end,

    format = function(payload, ui)
        return "> FREQ " .. payload.letter .. ": " .. payload.count
    end,

    sfx = {on_apply = "Enter"}
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. SOFT MARK DUD
-- ═══════════════════════════════════════════════════════════════════════════════

R({
    id              = "soft_mark_dud",
    name            = "Soft Mark Dud",
    weight          = 1,
    max_per_session = 2,

    apply = function(session, token)
        local solution   = session.solution
        local candidates = {}

        for id, t in pairs(session.tokens) do
            if (t.kind == "word" and t.text ~= solution and !t.removed) then
                table.insert(candidates, id)
            end
        end
        if (#candidates == 0) then return false end

        local pickId = candidates[math.random(#candidates)]
        return true, {targetId = pickId}
    end,

    format = function(payload, ui)
        return "> DUD MARKED"
    end,

    sfx = {on_apply = "Enter"}
})
