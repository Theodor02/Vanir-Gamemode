local PLUGIN = PLUGIN
local PLAYER = FindMetaTable("Player")

if CLIENT then

    local function DebugMusic(fmt, ...)
        if !ix.option.Get("ambientMusicDebug", false) then return end
        local ok, msg = pcall(string.format, fmt, ...)
        if !ok then
            msg = tostring(fmt)
        end
        MsgC(Color(120, 220, 255), "[AmbientMusic][CLIENT] ", color_white, msg .. "\n")
    end

    local function PlayEntry(entry, volume, fadeIn)
        if !entry or !entry.path or entry.path == "" then return end

        local vol = (volume or ix.option.Get("ambientMusicVolume", 100)) / 100
        local targetVol = vol
        local fadeInDuration = fadeIn and (ix.option.Get("ambientMusicFadeIn", 2) or 2) or 0

        DebugMusic(
            "PlayEntry request title='%s' path='%s' theme='%s' fadeIn=%s fadeInDuration=%.2f targetVol=%.2f",
            tostring(entry.title or ""),
            tostring(entry.path),
            tostring(entry.theme or "ambient"),
            tostring(fadeIn and true or false),
            tonumber(fadeInDuration) or 0,
            tonumber(targetVol) or 0
        )

        if ix.music.IsURL(entry.path) then
            sound.PlayURL(entry.path, "noblock", function(channel, err, errStr)
                if !IsValid(channel) then
                    DebugMusic("PlayURL failed path='%s' err=%s errStr=%s", tostring(entry.path), tostring(err), tostring(errStr))
                    return
                end
                LocalPlayer().ambientMusicChannel = channel
                DebugMusic("PlayURL channel created path='%s' length=%.2f", tostring(entry.path), tonumber(channel:GetLength() or 0) or 0)
                
                if fadeInDuration > 0 then
                    channel:SetVolume(0)  -- Start silent
                    LocalPlayer()._musicFadeStart = CurTime()
                    LocalPlayer()._musicFadeDuration = fadeInDuration
                    LocalPlayer()._musicFadeTarget = targetVol
                    LocalPlayer()._musicFadeType = "in"
                    DebugMusic("Fade-in armed duration=%.2f targetVol=%.2f", tonumber(fadeInDuration) or 0, tonumber(targetVol) or 0)
                else
                    channel:SetVolume(targetVol)
                end
                
                channel:Play()
                DebugMusic("PlayURL started path='%s'", tostring(entry.path))
            end)
        else
            sound.PlayFile("sound/" .. entry.path, "noplay", function(channel, err)
                if !IsValid(channel) then
                    DebugMusic("PlayFile failed path='%s' err=%s", tostring(entry.path), tostring(err))
                    return
                end
                LocalPlayer().ambientMusicChannel = channel
                DebugMusic("PlayFile channel created path='%s' length=%.2f", tostring(entry.path), tonumber(channel:GetLength() or 0) or 0)
                
                if fadeInDuration > 0 then
                    channel:SetVolume(0)  -- Start silent
                    LocalPlayer()._musicFadeStart = CurTime()
                    LocalPlayer()._musicFadeDuration = fadeInDuration
                    LocalPlayer()._musicFadeTarget = targetVol
                    LocalPlayer()._musicFadeType = "in"
                    DebugMusic("Fade-in armed duration=%.2f targetVol=%.2f", tonumber(fadeInDuration) or 0, tonumber(targetVol) or 0)
                else
                    channel:SetVolume(targetVol)
                end
                
                channel:Play()
                DebugMusic("PlayFile started path='%s'", tostring(entry.path))
            end)
        end
    end

    local function FadeOutMusic(player, duration)
        if !IsValid(player) or !player.ambientMusicChannel or !IsValid(player.ambientMusicChannel) then
            DebugMusic("FadeOutMusic skipped (no valid channel)")
            return
        end
        
        duration = duration or (ix.option.Get("ambientMusicFadeOut", 2) or 2)
        if duration <= 0 then
            if IsValid(player.ambientMusicChannel) then
                DebugMusic("FadeOutMusic immediate stop path channelVolume=%.2f", tonumber(player.ambientMusicChannel:GetVolume() or 0) or 0)
                player.ambientMusicChannel:Stop()
                player.ambientMusicChannel = nil
            end
            return
        end
        
        player._musicFadeStart = CurTime()
        player._musicFadeDuration = duration
        player._musicFadeTarget = 0
        player._musicFadeFrom = IsValid(player.ambientMusicChannel) and (player.ambientMusicChannel:GetVolume() or 1) or 1
        player._musicFadeType = "out"
        player._musicFadeStopAfter = true
        DebugMusic("FadeOutMusic armed duration=%.2f fromVol=%.2f", tonumber(duration) or 0, tonumber(player._musicFadeFrom or 0) or 0)
    end

    local function GetDuration(entry)
        if ix.music.IsURL(entry.path) then
            local urlDur = entry.duration or 0
            DebugMusic("GetDuration URL path='%s' duration=%.2f", tostring(entry.path), tonumber(urlDur) or 0)
            return urlDur
        end

        if entry.duration and entry.duration > 0 then
            DebugMusic("GetDuration entry duration override path='%s' duration=%.2f", tostring(entry.path), tonumber(entry.duration) or 0)
            return entry.duration
        end

        local path = tostring(entry.path or "")
        local dur = SoundDuration(path) or 0
        local source = "SoundDuration(path)"

        if dur <= 0 then
            dur = SoundDuration("sound/" .. path) or 0
            source = "SoundDuration(sound/path)"
        end

        DebugMusic("GetDuration local path='%s' duration=%.2f source=%s", path, tonumber(dur) or 0, source)

        return dur
    end

    local function BuildTrackList()
        local raw = {}
        for _, t in ipairs(PLUGIN.ambientTracks or {}) do
            raw[#raw + 1] = t
        end
        for _, folder in ipairs(PLUGIN.ambientFolders or {}) do
            local searchPath = "sound/" .. folder
            if searchPath:sub(-1) != "/" then searchPath = searchPath .. "/" end
            local files = file.Find(searchPath .. "*.mp3", "GAME")
            for _, fname in ipairs(files or {}) do
                raw[#raw + 1] = folder .. fname
            end
        end

        local normalised = {}
        for _, t in ipairs(raw) do
            local entry = ix.music.NormalizeTrack(t)
            if entry then
                normalised[#normalised + 1] = entry
            end
        end

        DebugMusic("BuildTrackList raw=%d normalised=%d circumstance='%s'", #raw, #normalised, tostring(ix.music.clientState.circumstance or "ambient"))

        local circumstance = ix.music.clientState.circumstance
        if circumstance and circumstance != "" and circumstance != "ambient" then
            local filtered = {}
            for _, entry in ipairs(normalised) do
                if entry.theme == circumstance then
                    filtered[#filtered + 1] = entry
                end
            end
            if #filtered > 0 then
                DebugMusic("BuildTrackList filtered by circumstance='%s' count=%d", tostring(circumstance), #filtered)
                return filtered
            end
        end

        return normalised
    end

    function PLAYER:AmbientMusicStart()
        if !ix.config.Get("allowAmbientMusic", true) then
            DebugMusic("AmbientMusicStart blocked: allowAmbientMusic=false")
            return
        end
        if !ix.option.Get("ambientMusicEnable", true) then
            DebugMusic("AmbientMusicStart blocked: ambientMusicEnable=false")
            return
        end
        if ix.music.clientState.isForcePlaying then
            DebugMusic("AmbientMusicStart blocked: isForcePlaying=true")
            return
        end -- Don't start ambient if GM is actively forcing music
        if timer.Exists("ixAmbientMusic") then
            DebugMusic("AmbientMusicStart blocked: timer already exists")
            return
        end

        local tracks = BuildTrackList()
        if #tracks < 1 then
            DebugMusic("AmbientMusicStart aborted: no tracks found")
            return
        end

        table.Shuffle(tracks)
        local index = 1
        DebugMusic("AmbientMusicStart ready tracks=%d", #tracks)

        local function getInterval()
            local value = math.random(
                ix.option.Get("ambientMusicIntMin", 120),
                ix.option.Get("ambientMusicIntMax", 300)
            )
            DebugMusic("Computed random interval=%d", value)
            return value
        end
        
        local function PlayNextAmbient()
            if ix.music.clientState.isForcePlaying then
                DebugMusic("PlayNextAmbient skipped: isForcePlaying=true")
                return
            end
            if hook.Run("CanPlayAmbientMusic", LocalPlayer()) == false then
                local delay = getInterval()
                timer.Adjust("ixAmbientMusic", delay, nil, nil)
                DebugMusic("PlayNextAmbient blocked by hook, retry in %d sec", delay)
                return
            end
            
            if index > #tracks then
                index = 1
                tracks = BuildTrackList()
                if #tracks < 1 then
                    local delay = getInterval()
                    timer.Adjust("ixAmbientMusic", delay, nil, nil)
                    DebugMusic("PlayNextAmbient rebuild empty, retry in %d sec", delay)
                    return
                end
                table.Shuffle(tracks)
                DebugMusic("PlayNextAmbient reshuffled new track set count=%d", #tracks)
            end
            
            local entry = tracks[index]
            DebugMusic("PlayNextAmbient selecting index=%d/%d title='%s' path='%s'", index, #tracks, tostring(entry.title or ""), tostring(entry.path or ""))
            PlayEntry(entry, nil, true)  -- Pass true to enable fade-in for ambient tracks
            index = index + 1
            
            local dur = GetDuration(entry)
            local fallback = dur > 0 and dur or 180
            local gap = getInterval()
            local nextDelay = fallback + gap
            timer.Adjust("ixAmbientMusic", nextDelay, nil, nil)
            DebugMusic("PlayNextAmbient scheduled next in %.2f sec (track=%.2f gap=%d)", tonumber(nextDelay) or 0, tonumber(fallback) or 0, gap)
        end

        if !timer.Exists("ixAmbientMusic") then
            -- Create first so PlayNextAmbient can immediately adjust the delay to match track duration.
            local seedDelay = getInterval()
            timer.Create("ixAmbientMusic", seedDelay, 0, PlayNextAmbient)
            DebugMusic("Created timer 'ixAmbientMusic' seedDelay=%d", seedDelay)
        end

        -- Call immediately so they hear music right away instead of waiting getInterval() first.
        DebugMusic("Calling PlayNextAmbient immediately after start")
        PlayNextAmbient()
    end

    function PLAYER:AmbientMusicStop()
        DebugMusic("AmbientMusicStop called timerExists=%s", tostring(timer.Exists("ixAmbientMusic")))
        FadeOutMusic(self)
        if timer.Exists("ixAmbientMusic") then
            timer.Remove("ixAmbientMusic")
            DebugMusic("Removed timer 'ixAmbientMusic'")
        end
    end

    function PLAYER:AmbientMusicVolume(vol)
        DebugMusic("AmbientMusicVolume set request=%s", tostring(vol))
        if self.ambientMusicChannel then
            self.ambientMusicChannel:SetVolume(vol / 100)
            DebugMusic("AmbientMusicVolume applied channelVol=%.2f", tonumber(self.ambientMusicChannel:GetVolume() or 0) or 0)
        end
    end

    -- Play a GM Forced track!
    -- This relies entirely on the server for auto-advancing the queue.
    function PLAYER:AmbientMusicPlayEntry(entry)
        if !entry then return end
        DebugMusic("AmbientMusicPlayEntry forced title='%s' path='%s' duration=%s", tostring(entry.title or ""), tostring(entry.path or ""), tostring(entry.duration or 0))
        FadeOutMusic(self)  -- Fade out current music before switching to GM-forced
        
        -- Give fade-out time to complete before starting GM track
        timer.Simple(0.1, function()
            if IsValid(self) and IsValid(self.ambientMusicChannel) then
                self.ambientMusicChannel:Stop()
                self.ambientMusicChannel = nil
                DebugMusic("AmbientMusicPlayEntry hard-stopped previous channel before force track")
            end
            if IsValid(self) then
                ix.music.clientState.isForcePlaying = true
                DebugMusic("AmbientMusicPlayEntry isForcePlaying=true, launching forced track")
                PlayEntry(entry, nil, false)  -- No fade-in for GM-forced tracks
            end
        end)
    end
end
