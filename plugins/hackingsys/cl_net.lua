--- Client-side network receivers for the hacking terminal.
-- @module ix.hacking (client)

ix.hacking = ix.hacking or {}
ix.hacking.UI = ix.hacking.UI or {}

net.Receive("ixHackingStart", function()
    local lines    = net.ReadUInt(8)
    local width    = net.ReadUInt(8)
    local attempts = net.ReadUInt(8)
    local gridText = net.ReadString()
    local addresses = net.ReadTable()
    local tokens   = net.ReadTable()

    ix.hacking.UI.Open({
        lines     = lines,
        width     = width,
        attempts  = attempts,
        gridText  = gridText,
        addresses = addresses,
        tokens    = tokens
    })
end)

net.Receive("ixHackingWordResult", function()
    local id       = net.ReadUInt(16)
    local success  = net.ReadBool()
    local attempts = net.ReadUInt(8)
    local likeness = net.ReadUInt(8)

    ix.hacking.UI.UpdateWordResult(id, success, attempts, likeness)
end)

net.Receive("ixHackingTokenResult", function()
    local id         = net.ReadUInt(16)
    local effectId   = net.ReadString()
    local effectData = net.ReadTable()
    local attempts   = net.ReadUInt(8)

    -- Always sync attempts
    if (ix.hacking.UI.Session) then
        ix.hacking.UI.Session.attempts = attempts
    end

    -- None / junk -- still consume the token so it turns to dots
    if (effectId == "none") then
        ix.hacking.UI.ConsumeToken(id)

        local now = CurTime()
        if (ix.hacking.UI.Session) then
            if (!ix.hacking.UI.LastJunkLog or (now - ix.hacking.UI.LastJunkLog > 0.2)) then
                local msgs = {"> INVALID ENTRY", "> ERROR", "> COMMAND NOT RECOGNIZED", "> ACCESS DENIED"}
                ix.hacking.UI.AddLog(msgs[math.random(#msgs)])
                ix.hacking.UI.PlaySFX("Deny")
                ix.hacking.UI.LastJunkLog = now
            end
        end
        return
    end

    -- Resolve registry definition
    local def = ix.hacking.Effects.Registry[effectId]
    if (!def) then
        if (ix.hacking.UI.Session and ix.hacking.UI.Session.tokens[id]) then
            ix.hacking.UI.Session.tokens[id].consumed = true
        end
        ix.hacking.UI.AddLog("> UNKNOWN EFFECT")
        ix.hacking.UI.PlaySFX("Deny")
        return
    end

    -- Mark consumed (replaces grid chars with dots) & log token text
    if (ix.hacking.UI.Session and ix.hacking.UI.Session.tokens[id]) then
        ix.hacking.UI.AddLog("> " .. ix.hacking.UI.Session.tokens[id].text)
        ix.hacking.UI.ConsumeToken(id)
    end

    -- Format log
    if (def.format) then
        local msg = def.format(effectData, ix.hacking.UI)
        if (msg) then
            ix.hacking.UI.AddLog(msg)
        end
    end

    -- SFX
    if (def.sfx and def.sfx.on_apply) then
        ix.hacking.UI.PlaySFX(def.sfx.on_apply)
    end

    -- Result hook (visual grid updates)
    if (def.onResult) then
        def.onResult(effectData, ix.hacking.UI)
    end
end)

net.Receive("ixHackingEnd", function()
    local reason = net.ReadString()
    ix.hacking.UI.Close(reason)
end)
