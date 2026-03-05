--- Server-side session management.
-- Handles starting, ending, word guesses, and token clicks for hacking sessions.
-- @module ix.hacking (server)

ix.hacking = ix.hacking or {}
ix.hacking.Sessions = {}
ix.hacking.Sessions.Active = {}

--- Start a new hacking session for a player.
-- @param ply Player
-- @param opts table Options: {preset, difficulty, effectLimits, callbacks}
-- @return table The session object.
function ix.hacking.Sessions.Start(ply, opts)
    ix.hacking.Sessions.End(ply, "restart")

    opts = opts or {}
    local presetName = opts.preset or "average"
    local data = ix.hacking.Generator.Generate(presetName, opts.difficulty)

    local session = {
        ply          = ply,
        gridText     = data.gridText,
        tokens       = {},
        solution     = data.solution,
        addresses    = data.addresses,
        attempts     = 4,
        maxAttempts  = 4,
        lines        = data.lines,
        width        = data.width,
        effectLimits = table.Copy(opts.effectLimits or data.effectLimits),
        callbacks    = opts.callbacks or {},
        startTime    = CurTime()
    }

    -- Apply registry defaults for limits
    for id, def in pairs(ix.hacking.Effects.Registry) do
        if (def.max_per_session) then
            local key = def.limit_key or id
            if (session.effectLimits[key] == nil) then
                session.effectLimits[key] = def.max_per_session
            end
        end
    end

    -- Index tokens by ID
    for _, t in ipairs(data.tokens) do
        session.tokens[t.id] = t
    end

    ix.hacking.Sessions.Active[ply] = session

    -- Network to client
    net.Start("ixHackingStart")
        net.WriteUInt(session.lines, 8)
        net.WriteUInt(session.width, 8)
        net.WriteUInt(session.attempts, 8)
        net.WriteString(session.gridText)
        net.WriteTable(session.addresses)
        net.WriteTable(data.tokens)
    net.Send(ply)

    if (session.callbacks.onStart) then
        session.callbacks.onStart(session)
    end

    return session
end

--- Get the active session for a player.
-- @param ply Player
-- @return table|nil
function ix.hacking.Sessions.Get(ply)
    return ix.hacking.Sessions.Active[ply]
end

--- End a hacking session.
-- @param ply Player
-- @param reason string
function ix.hacking.Sessions.End(ply, reason)
    local session = ix.hacking.Sessions.Active[ply]
    if (!session) then return end

    ix.hacking.Sessions.Active[ply] = nil

    net.Start("ixHackingEnd")
        net.WriteString(reason or "unknown")
    net.Send(ply)

    if (session.callbacks.onEnd) then
        session.callbacks.onEnd(session, reason)
    end
end

--- Handle a word guess from a player.
-- @param ply Player
-- @param id number Token ID
function ix.hacking.Sessions.HandleWordGuess(ply, id)
    local session = ix.hacking.Sessions.Active[ply]
    if (!session) then return end

    local token = session.tokens[id]
    if (!token or token.kind ~= "word" or token.removed) then return end

    if (token.text == session.solution) then
        -- Win
        net.Start("ixHackingWordResult")
            net.WriteUInt(id, 16)
            net.WriteBool(true)
            net.WriteUInt(session.attempts, 8)
            net.WriteUInt(0, 8)
        net.Send(ply)

        ix.hacking.Sessions.End(ply, "success")
    else
        -- Fail
        session.attempts = session.attempts - 1
        local likeness = ix.hacking.CalculateLikeness(token.text, session.solution)

        net.Start("ixHackingWordResult")
            net.WriteUInt(id, 16)
            net.WriteBool(false)
            net.WriteUInt(session.attempts, 8)
            net.WriteUInt(likeness, 8)
        net.Send(ply)

        if (session.attempts <= 0) then
            ix.hacking.Sessions.End(ply, "lockout")
        elseif (session.callbacks.onGuess) then
            session.callbacks.onGuess(session, false, token.text, likeness)
        end
    end
end

--- Handle a non-word token click (bracket or junk).
-- @param ply Player
-- @param id number Token ID
function ix.hacking.Sessions.HandleTokenClick(ply, id)
    local session = ix.hacking.Sessions.Active[ply]
    if (!session) then return end

    local token = session.tokens[id]
    if (!token) then return end

    -- Words are handled by HandleWordGuess
    if (token.kind == "word") then return end

    -- Junk: always clickable, returns none
    if (token.kind == "junk") then
        net.Start("ixHackingTokenResult")
            net.WriteUInt(id, 16)
            net.WriteString("none")
            net.WriteTable({reason = "junk"})
            net.WriteUInt(session.attempts, 8)
        net.Send(ply)
        return
    end

    -- Bracket: consume and apply effect
    if (token.kind == "bracket") then
        if (token.consumed) then return end
        token.consumed = true

        local effectId   = token.effect
        local effectData = {}

        if (effectId and ix.hacking.Effects.Registry[effectId]) then
            local def = ix.hacking.Effects.Registry[effectId]
            local success, data = def.apply(session, token, {})

            if (success) then
                effectData = data
            else
                effectId = "none"
            end
        else
            effectId, effectData = ix.hacking.Effects.ApplySelection(session, token)
        end

        net.Start("ixHackingTokenResult")
            net.WriteUInt(id, 16)
            net.WriteString(effectId)
            net.WriteTable(effectData)
            net.WriteUInt(session.attempts, 8)
        net.Send(ply)

        if (session.callbacks.onToken) then
            session.callbacks.onToken(session, token, effectId)
        end
    end
end
