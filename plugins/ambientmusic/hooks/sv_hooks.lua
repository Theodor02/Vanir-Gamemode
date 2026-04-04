
local PLUGIN = PLUGIN

util.AddNetworkString("ixAmbientMusic")
util.AddNetworkString("ixAmbientMusicForce")
util.AddNetworkString("ixAmbientMusicStop")
util.AddNetworkString("ixAmbientMusicQueue")
util.AddNetworkString("ixAmbientMusicCircumstance")
util.AddNetworkString("ixAmbientMusicShuffle")
util.AddNetworkString("ixAmbientMusicRequest")
util.AddNetworkString("ixAmbientMusicPanelData")

-- Sync current music state to a newly spawned player
hook.Add("PlayerInitialSpawn", "ixAmbientMusicSync", function(ply)
    timer.Simple(2, function()
        if !IsValid(ply) then return end
        ix.music.SendStateToPlayer(ply)
    end)
end)