
local PLUGIN = PLUGIN

ix.music = ix.music or {}

-- Server-side state
ix.music.state = {
    circumstance   = "ambient",
    forcedTrack    = nil,
    forcedPlaylist = nil,
    queue          = {},
    shuffleQueue   = false,
    lastBroadcast  = 0,
}

-- CAMI privilege registration
CAMI.RegisterPrivilege({
    Name      = "Skeleton - Ambient Music Control",
    MinAccess = "admin",
})

local MAX_QUEUE = 20
local BROADCAST_COOLDOWN = 0.5

local function CanBroadcast()
    if CurTime() - ix.music.state.lastBroadcast >= BROADCAST_COOLDOWN then
        ix.music.state.lastBroadcast = CurTime()
        return true
    end
    return false
end

local function IsValidPath(path)
    if !path or path == "" then return false end
    if string.find(path, "\0") then return false end
    if string.find(path, "%.%.") then return false end
    return true
end

local function IsURL(path)
    return path:sub(1, 7) == "http://" or path:sub(1, 8) == "https://"
end

local function ValidatePath(path)
    if !IsValidPath(path) then return false end
    if IsURL(path) then
        return #path <= 512
    else
        return true
    end
end

local function ValidateCircumstance(str)
    if !str or str == "" then return false end
    if #str > 32 then return false end
    return str:match("^[%w_]+$") != nil
end

-- Broadcast force-play for a single track to all clients
function ix.music.ForcePlay(entry)
    if !entry or !ValidatePath(entry.path) then return false, "invalid path" end

    ix.music.state.forcedTrack    = entry
    ix.music.state.forcedPlaylist = nil

    net.Start("ixAmbientMusicForce")
        net.WriteBool(true)
        net.WriteString(entry.path)
        net.WriteString(entry.theme or "ambient")
        net.WriteFloat(entry.duration or 0)
        net.WriteString(entry.title or "")
    net.Broadcast()
    
    ix.music.state.lastBroadcast = CurTime()

    -- Server-side Auto Advance Timer
    local dur = tonumber(entry.duration) or 0
    if dur <= 0 and not IsURL(entry.path) then
        local sd = SoundDuration("sound/" .. tostring(entry.path))
        if sd and sd > 0 then dur = sd end
    end
    if dur <= 0 then dur = 180 end -- Fallback length
    
    timer.Create("ixAmbientMusic_ServerAdvance", dur + 2, 1, function()
        ix.music.QueueSkip()
    end)

    return true
end

-- Broadcast force-play for an entire playlist
function ix.music.ForcePlaylist(key)
    if !PLUGIN.playlists[key] then return false, "playlist not found" end
    local playlist = PLUGIN.playlists[key]
    if !playlist.tracks or #playlist.tracks < 1 then return false, "empty playlist" end

    ix.music.state.forcedPlaylist = key
    ix.music.state.forcedTrack    = nil
    
    local queue = {}
    for _, t in ipairs(playlist.tracks) do
        local entry
        if type(t) == "string" then
            entry = { path = t, theme = playlist.mode or "ambient", title = t, duration = 0 }
        else
            entry = {
                path     = tostring(t.path or ""),
                theme    = tostring(t.theme or playlist.mode or "ambient"),
                title    = tostring(t.title or t.path or ""),
                duration = tonumber(t.duration) or 0,
            }
        end
        if ValidatePath(entry.path) then
            queue[#queue + 1] = entry
        end
    end
    
    if ix.music.state.shuffleQueue then
        table.Shuffle(queue)
    end
    
    ix.music.state.queue = queue
    ix.music.QueueSkip()

    return true
end

-- Stop all ambient music for all clients
function ix.music.ForceStop()
    timer.Remove("ixAmbientMusic_ServerAdvance")
    ix.music.state.forcedTrack    = nil
    ix.music.state.forcedPlaylist = nil
    ix.music.state.queue          = {}

    net.Start("ixAmbientMusicStop")
    net.Broadcast()

    ix.music.state.lastBroadcast = CurTime()
end

-- Set global circumstance tag and broadcast to all clients
function ix.music.SetCircumstance(circumstance)
    if !ValidateCircumstance(circumstance) then return false, "invalid circumstance" end

    ix.music.state.circumstance = circumstance

    if !CanBroadcast() then
        -- Still set the state, broadcast will go out on next available slot
        timer.Simple(BROADCAST_COOLDOWN, function()
            net.Start("ixAmbientMusicCircumstance")
                net.WriteString(ix.music.state.circumstance)
            net.Broadcast()
        end)
        return true
    end

    net.Start("ixAmbientMusicCircumstance")
        net.WriteString(circumstance)
    net.Broadcast()

    return true
end

-- Add a track to the server queue and sync to all clients
function ix.music.QueueAdd(entry)
    if !entry or !ValidatePath(entry.path) then return false, "invalid path" end
    if #ix.music.state.queue >= MAX_QUEUE then return false, "queue full (max " .. MAX_QUEUE .. ")" end

    table.insert(ix.music.state.queue, entry)

    net.Start("ixAmbientMusicQueue")
        net.WriteTable(ix.music.state.queue)
    net.Broadcast()

    ix.music.state.lastBroadcast = CurTime()
    return true
end

-- Clear the server queue and sync to all clients
function ix.music.QueueClear()
    ix.music.state.queue = {}

    net.Start("ixAmbientMusicQueue")
        net.WriteTable(ix.music.state.queue)
    net.Broadcast()

    ix.music.state.lastBroadcast = CurTime()
end

-- Remove a specific track from the queue
function ix.music.QueueRemove(index)
    index = tonumber(index) or 0
    if index < 1 or index > #ix.music.state.queue then return false, "invalid index" end

    table.remove(ix.music.state.queue, index)

    net.Start("ixAmbientMusicQueue")
        net.WriteTable(ix.music.state.queue)
    net.Broadcast()

    ix.music.state.lastBroadcast = CurTime()
    return true
end

-- Move a track up (-1) or down (1) the queue
function ix.music.QueueMove(index, dir)
    index = tonumber(index) or 0
    if index < 1 or index > #ix.music.state.queue then return false, "invalid index" end

    local newIndex = index + dir
    if newIndex < 1 or newIndex > #ix.music.state.queue then return false, "invalid move" end

    local item = table.remove(ix.music.state.queue, index)
    table.insert(ix.music.state.queue, newIndex, item)

    net.Start("ixAmbientMusicQueue")
        net.WriteTable(ix.music.state.queue)
    net.Broadcast()

    ix.music.state.lastBroadcast = CurTime()
    return true
end

-- Skip current track and play the next in queue (or stop if empty)
function ix.music.QueueSkip()
    if #ix.music.state.queue > 0 then
        local entry = table.remove(ix.music.state.queue, 1)
        
        -- Broadcast updated queue
        net.Start("ixAmbientMusicQueue")
            net.WriteTable(ix.music.state.queue)
        net.Broadcast()
        
        ix.music.state.lastBroadcast = CurTime()
        return ix.music.ForcePlay(entry)
    else
        ix.music.ForceStop()
        return true, "Queue empty, stopped."
    end
end


-- Send current music state to a specific player (used on join and panel open)
function ix.music.SendStateToPlayer(ply)
    if !IsValid(ply) then return end

    -- Send circumstance
    net.Start("ixAmbientMusicCircumstance")
        net.WriteString(ix.music.state.circumstance)
    net.Send(ply)

    -- Send queue
    net.Start("ixAmbientMusicQueue")
        net.WriteTable(ix.music.state.queue)
    net.Send(ply)
    net.Start("ixAmbientMusicShuffle")
        net.WriteBool(ix.music.state.shuffleQueue)
    net.Send(ply)

    -- Re-broadcast forced track/playlist if active
    if ix.music.state.forcedTrack then
        local entry = ix.music.state.forcedTrack
        net.Start("ixAmbientMusicForce")
            net.WriteBool(true)
            net.WriteString(entry.path)
            net.WriteString(entry.theme or "ambient")
            net.WriteFloat(entry.duration or 0)
            net.WriteString(entry.title or "")
        net.Send(ply)
    elseif ix.music.state.forcedPlaylist then
        net.Start("ixAmbientMusicForce")
            net.WriteBool(false)
            net.WriteString(ix.music.state.forcedPlaylist)
        net.Send(ply)
    end
end

-- Send panel data to a specific player (response to request_panel_data)
function ix.music.SendPanelData(ply)
    if !IsValid(ply) then return end

    -- Build a network-safe snapshot of playlists (strip functions, limit nesting)
    local playlists = {}
    for key, playlist in pairs(PLUGIN.playlists or {}) do
        local tracks = {}
        for _, t in ipairs(playlist.tracks or {}) do
            local entry
            if type(t) == "string" then
                entry = { path = t, theme = "ambient", title = t, duration = 0 }
            else
                entry = {
                    path     = tostring(t.path or ""),
                    theme    = tostring(t.theme or "ambient"),
                    title    = tostring(t.title or t.path or ""),
                    duration = tonumber(t.duration) or 0,
                }
            end
            tracks[#tracks + 1] = entry
        end
        playlists[key] = {
            name   = tostring(playlist.name or key),
            mode   = tostring(playlist.mode or "ambient"),
            tracks = tracks,
        }
    end

    -- Also include top-level ambientTracks
    local topTracks = {}
    for _, t in ipairs(PLUGIN.ambientTracks or {}) do
        if type(t) == "string" then
            topTracks[#topTracks + 1] = { path = t, theme = "ambient", title = t, duration = 0 }
        else
            topTracks[#topTracks + 1] = {
                path     = tostring(t.path or ""),
                theme    = tostring(t.theme or "ambient"),
                title    = tostring(t.title or t.path or ""),
                duration = tonumber(t.duration) or 0,
            }
        end
    end

    net.Start("ixAmbientMusicPanelData")
        net.WriteTable({
            playlists    = playlists,
            topTracks    = topTracks,
            queue        = ix.music.state.queue,
            circumstance = ix.music.state.circumstance,
            shuffleMode  = ix.music.state.shuffleQueue,
        })
    net.Send(ply)
end

-- Handle requests from clients (GM panel and commands)
net.Receive("ixAmbientMusicRequest", function(len, ply)
    -- Rate limiting per player
    if CurTime() < (ply.ixMusicRequestCooldown or 0) then return end
    ply.ixMusicRequestCooldown = CurTime() + BROADCAST_COOLDOWN

    local action = net.ReadString()
    local data   = net.ReadTable()

    if type(data) != "table" then data = {} end

    -- Sanitise incoming table: flat strings/numbers only, bounded
    local keyCount = 0
    for k, v in pairs(data) do
        keyCount = keyCount + 1
        if keyCount > 10 then
            data[k] = nil
        elseif type(v) == "string" then
            data[k] = string.sub(v, 1, 512)
        elseif type(v) == "number" then
            -- ok
        else
            data[k] = nil
        end
    end

    CAMI.PlayerHasAccess(ply, "Skeleton - Ambient Music Control", function(hasAccess)
        if !hasAccess then return end

        if action == "force_track" then
            local entry = {
                path     = data.path or "",
                theme    = data.theme or "ambient",
                duration = tonumber(data.duration) or 0,
                title    = data.title or "",
            }
            local ok, err = ix.music.ForcePlay(entry)
            if !ok then ply:Notify("[Music] " .. (err or "error")) end

        elseif action == "force_playlist" then
            local ok, err = ix.music.ForcePlaylist(data.key or "")
            if !ok then ply:Notify("[Music] " .. (err or "error")) end

        elseif action == "force_stop" then
            ix.music.ForceStop()

        elseif action == "queue_skip" then
            local ok, err = ix.music.QueueSkip()
            if !ok then ply:Notify("[Music] " .. (err or "error")) end

        elseif action == "queue_add" then
            local entry = {
                path     = data.path or "",
                theme    = data.theme or "ambient",
                duration = tonumber(data.duration) or 0,
                title    = data.title or "",
            }
            local ok, err = ix.music.QueueAdd(entry)
            if !ok then ply:Notify("[Music] " .. (err or "error")) end

        elseif action == "queue_clear" then
            ix.music.QueueClear()

        elseif action == "queue_remove" then
            local ok, err = ix.music.QueueRemove(data.index)
            if !ok then ply:Notify("[Music] " .. (err or "error")) end

        elseif action == "queue_move" then
            local ok, err = ix.music.QueueMove(data.index, data.dir)
            if !ok then ply:Notify("[Music] " .. (err or "error")) end

        
        elseif action == "queue_playlist" then
            local playlist = PLUGIN.playlists and PLUGIN.playlists[data.key or ""]
            if playlist and playlist.tracks then
                local added = {}
                for _, t in ipairs(playlist.tracks) do
                    local entry
                    if type(t) == "string" then
                        entry = { path = t, theme = playlist.mode or "ambient", duration = 0, title = t }
                    else
                        entry = {
                            path     = tostring(t.path or ""),
                            theme    = tostring(t.theme or playlist.mode or "ambient"),
                            duration = tonumber(t.duration) or 0,
                            title    = tostring(t.title or t.path or ""),
                        }
                    end
                    if ValidatePath(entry.path) then
                        added[#added + 1] = entry
                    end
                end
                
                if ix.music.state.shuffleQueue then
                    table.Shuffle(added)
                end
                
                for _, entry in ipairs(added) do
                    if #ix.music.state.queue >= MAX_QUEUE then break end
                    table.insert(ix.music.state.queue, entry)
                end
                
                net.Start("ixAmbientMusicQueue")
                    net.WriteTable(ix.music.state.queue)
                net.Broadcast()
            end


        elseif action == "set_circumstance" then
            local ok, err = ix.music.SetCircumstance(data.circumstance or "")
            if !ok then ply:Notify("[Music] " .. (err or "error")) end

        
        elseif action == "toggle_shuffle" then
            ix.music.state.shuffleQueue = !ix.music.state.shuffleQueue
            net.Start("ixAmbientMusicShuffle")
                net.WriteBool(ix.music.state.shuffleQueue)
            net.Broadcast()
            ply:Notify("[Music] GM Queue Shuffle is now " .. (ix.music.state.shuffleQueue and "ON" or "OFF"))
        elseif action == "request_panel_data" then
            ix.music.SendPanelData(ply)
        end
    end)
end)
