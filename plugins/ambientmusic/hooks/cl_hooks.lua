
local PLUGIN = PLUGIN

local function DebugMusic(fmt, ...)
    if !ix.option.Get("ambientMusicDebug", false) then return end
    local ok, msg = pcall(string.format, fmt, ...)
    if !ok then
        msg = tostring(fmt)
    end
    MsgC(Color(120, 220, 255), "[AmbientMusic][CLIENT] ", color_white, msg .. "\n")
end

-- Handle music fade-in/fade-out animations
function PLUGIN:Think()
    local client = LocalPlayer()
    if !IsValid(client) or !client.ambientMusicChannel or !IsValid(client.ambientMusicChannel) then 
        if client and client._musicFadeType then
            DebugMusic("Think cleared fade state because channel became invalid")
            client._musicFadeType = nil
            client._musicFadeFrom = nil
        end
        return 
    end
    
    if !client._musicFadeType then return end
    
    local elapsed = CurTime() - (client._musicFadeStart or 0)
    local duration = client._musicFadeDuration or 2
    local progress = math.min(elapsed / duration, 1)
    
    if client._musicFadeType == "in" then
        local targetVol = client._musicFadeTarget or 1
        local newVol = targetVol * progress
        client.ambientMusicChannel:SetVolume(newVol)
        
        if progress >= 1 then
            DebugMusic("Fade-in complete targetVol=%.2f", tonumber(targetVol) or 0)
            client._musicFadeType = nil
        end
    elseif client._musicFadeType == "out" then
        local startVol = client._musicFadeFrom or client.ambientMusicChannel:GetVolume() or 1
        local newVol = startVol * (1 - progress)
        client.ambientMusicChannel:SetVolume(newVol)
        
        if progress >= 1 then
            if IsValid(client.ambientMusicChannel) then
                client.ambientMusicChannel:Stop()
                client.ambientMusicChannel = nil
            end
            DebugMusic("Fade-out complete startVol=%.2f duration=%.2f", tonumber(startVol) or 0, tonumber(duration) or 0)
            client._musicFadeType = nil
            client._musicFadeFrom = nil
            client._musicFadeStopAfter = false
        end
    end
end

-- Existing: server toggling music on/off globally
net.Receive("ixAmbientMusic", function(length)
    local state = net.ReadBool()
    DebugMusic("Net ixAmbientMusic state=%s", tostring(state))

    if state then
        LocalPlayer():AmbientMusicStart()
    else
        LocalPlayer():AmbientMusicStop()
    end
end)

-- GM forced a specific track or playlist onto all clients
net.Receive("ixAmbientMusicForce", function()
    local isTrack = net.ReadBool()
    DebugMusic("Net ixAmbientMusicForce isTrack=%s", tostring(isTrack))

    if isTrack then
        local path     = net.ReadString()
        local theme    = net.ReadString()
        local duration = net.ReadFloat()
        local title    = net.ReadString()

        DebugMusic("Force track received title='%s' path='%s' theme='%s' duration=%.2f", tostring(title), tostring(path), tostring(theme), tonumber(duration) or 0)

        local entry = ix.music.NormalizeTrack({
            path     = path,
            theme    = theme,
            duration = duration > 0 and duration or nil,
            title    = title,
        })
        if !entry then return end

        ix.music.clientState.isForcePlaying = true
        ix.music.clientState.currentTrack   = entry
        LocalPlayer():AmbientMusicPlayEntry(entry)
    end
    local panel = ix.music._gmPanel
    if IsValid(panel) and panel.RefreshNowPlaying then
        panel:RefreshNowPlaying()
    end
end)

-- GM force-stopped all music
net.Receive("ixAmbientMusicStop", function()
    DebugMusic("Net ixAmbientMusicStop received, clearing force state and restarting ambient")
    ix.music.clientState.isForcePlaying = false
    ix.music.clientState.queue          = {}
    ix.music.clientState.currentTrack   = nil
    LocalPlayer():AmbientMusicStop()
    
    -- Immediately restart normal player ambient flow!
    LocalPlayer():AmbientMusicStart()

    local panel = ix.music._gmPanel
    if IsValid(panel) and panel.RefreshNowPlaying then
        panel:RefreshNowPlaying()
        panel:RefreshQueueList()
        panel:ShowStatus("Stopped Global Music and Cleared Queue", false)
    end
end)

-- Server synced the queue (e.g. after queue_add, queue_clear)
net.Receive("ixAmbientMusicQueue", function()
    local queue = net.ReadTable()
    DebugMusic("Net ixAmbientMusicQueue entries=%d", istable(queue) and #queue or -1)
    if type(queue) == "table" then
        -- Normalize all entries
        local normalized = {}
        for _, entry in ipairs(queue) do
            local t = ix.music.NormalizeTrack(entry)
            if t then
                normalized[#normalized + 1] = t
            end
        end
        ix.music.clientState.queue = normalized
    end

    local panel = ix.music._gmPanel
    if IsValid(panel) and panel.RefreshQueueList then
        panel:RefreshQueueList(ix.music.clientState.queue)
    end
end)

-- Server changed the circumstance tag
net.Receive("ixAmbientMusicCircumstance", function()
    local circumstance = net.ReadString()
    local old = ix.music.clientState.circumstance
    ix.music.clientState.circumstance = circumstance
    DebugMusic("Net ixAmbientMusicCircumstance old='%s' new='%s'", tostring(old or ""), tostring(circumstance or ""))

    -- Refresh panel status row if it is open
    local panel = ix.music._gmPanel
    if IsValid(panel) and panel.RefreshStatus then
        panel:RefreshStatus()
    end

    -- If music is actively playing and circumstance changed, restart to re-filter tracks
    if old != circumstance and timer.Exists("ixAmbientMusic") and !ix.music.clientState.isForcePlaying then
        DebugMusic("Circumstance changed while ambient running, restarting local ambient flow")
        LocalPlayer():AmbientMusicStop()
        LocalPlayer():AmbientMusicStart()
    end
end)

-- Server sent panel data in response to request_panel_data
net.Receive("ixAmbientMusicPanelData", function()
    local data = net.ReadTable()
    if type(data) != "table" then return end
    DebugMusic("Net ixAmbientMusicPanelData received playlists=%d topTracks=%d", istable(data.playlists) and table.Count(data.playlists) or -1, istable(data.topTracks) and #data.topTracks or -1)

    -- Store latest data for panel refresh
    ix.music._panelData = data

    -- Open or refresh the GM panel
    if IsValid(ix.music._gmPanel) then
        ix.music._gmPanel:Populate(data)
    else
        local panel = vgui.Create("ixMusicGMPanel")
        if IsValid(panel) then
            panel:Populate(data)
            ix.music._gmPanel = panel
        end
    end
end)

function PLUGIN:CharacterLoaded(char)
    local client = LocalPlayer()
    DebugMusic("CharacterLoaded restarting local ambient flow")

    client:AmbientMusicStop()
    client:AmbientMusicStart()
end

-- if any hook calls return false, the music will not play for that timer roll.
function PLUGIN:CanPlayAmbientMusic(client)
end

net.Receive("ixAmbientMusicShuffle", function()
    ix.music.clientState.shuffleMode = net.ReadBool()
    DebugMusic("Net ixAmbientMusicShuffle shuffleMode=%s", tostring(ix.music.clientState.shuffleMode))
    local panel = ix.music._gmPanel
    if IsValid(panel) and panel.RefreshShuffle then
        panel:RefreshShuffle()
    end
end)
