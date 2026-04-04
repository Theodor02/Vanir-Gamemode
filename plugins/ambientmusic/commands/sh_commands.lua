
-- Open the GM music control panel.
-- Sends panel data to the requesting player; the client creates the panel on receipt.
ix.command.Add("MusicPanel", {
    description = "@cmdMusicPanel",
    OnRun = function(self, ply)
        CAMI.PlayerHasAccess(ply, "Skeleton - Ambient Music Control", function(hasAccess)
            if !hasAccess then
                ply:Notify("You do not have permission to use the music panel.")
                return
            end
            ix.music.SendPanelData(ply)
        end)
    end,
})

-- Force-play a track by file path or URL for all players.
ix.command.Add("MusicForcePlay", {
    description = "@cmdMusicForcePlay",
    arguments   = { ix.type.string },
    OnRun = function(self, ply, path)
        CAMI.PlayerHasAccess(ply, "Skeleton - Ambient Music Control", function(hasAccess)
            if !hasAccess then
                ply:Notify("You do not have permission to force music.")
                return
            end

            local entry = {
                path     = path,
                theme    = "ambient",
                duration = 0,
                title    = path,
            }
            local ok, err = ix.music.ForcePlay(entry)
            if ok then
                ply:Notify("[Music] Force-playing: " .. path)
            else
                ply:Notify("[Music] Error: " .. (err or "unknown"))
            end
        end)
    end,
})

-- Stop all ambient music for all players.
ix.command.Add("MusicForceStop", {
    description = "@cmdMusicForceStop",
    OnRun = function(self, ply)
        CAMI.PlayerHasAccess(ply, "Skeleton - Ambient Music Control", function(hasAccess)
            if !hasAccess then
                ply:Notify("You do not have permission to stop music.")
                return
            end
            ix.music.ForceStop()
            ply:Notify("[Music] Stopped ambient music for all players.")
        end)
    end,
})

-- Set the global music circumstance tag (e.g. "combat", "ambient", "tension").
ix.command.Add("MusicSetCircumstance", {
    description = "@cmdMusicSetCircumstance",
    arguments   = { ix.type.string },
    OnRun = function(self, ply, circumstance)
        CAMI.PlayerHasAccess(ply, "Skeleton - Ambient Music Control", function(hasAccess)
            if !hasAccess then
                ply:Notify("You do not have permission to change the music circumstance.")
                return
            end
            local ok, err = ix.music.SetCircumstance(circumstance)
            if ok then
                ply:Notify("[Music] Circumstance set to: " .. circumstance)
            else
                ply:Notify("[Music] Error: " .. (err or "unknown"))
            end
        end)
    end,
})

-- Queue a track to play next for all players.
ix.command.Add("MusicQueueTrack", {
    description = "@cmdMusicQueueTrack",
    arguments   = { ix.type.string },
    OnRun = function(self, ply, path)
        CAMI.PlayerHasAccess(ply, "Skeleton - Ambient Music Control", function(hasAccess)
            if !hasAccess then
                ply:Notify("You do not have permission to queue music.")
                return
            end
            local entry = {
                path     = path,
                theme    = "ambient",
                duration = 0,
                title    = path,
            }
            local ok, err = ix.music.QueueAdd(entry)
            if ok then
                ply:Notify("[Music] Queued: " .. path .. " (" .. #ix.music.state.queue .. " in queue)")
            else
                ply:Notify("[Music] Error: " .. (err or "unknown"))
            end
        end)
    end,
})
