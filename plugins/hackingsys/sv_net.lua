--- Server-side network string registration and receivers.
-- @module ix.hacking (server)

util.AddNetworkString("ixHackingStart")
util.AddNetworkString("ixHackingEnd")
util.AddNetworkString("ixHackingWordResult")
util.AddNetworkString("ixHackingTokenResult")
util.AddNetworkString("ixHackingRequestStart")
util.AddNetworkString("ixHackingSelectWord")
util.AddNetworkString("ixHackingActivateToken")
util.AddNetworkString("ixHackingAbort")

net.Receive("ixHackingRequestStart", function(len, ply)
    local preset = net.ReadString()
    if (preset == "") then preset = "average" end
    ix.hacking.Sessions.Start(ply, {preset = preset})
end)

net.Receive("ixHackingSelectWord", function(len, ply)
    local id = net.ReadUInt(16)
    ix.hacking.Sessions.HandleWordGuess(ply, id)
end)

net.Receive("ixHackingActivateToken", function(len, ply)
    local id = net.ReadUInt(16)
    ix.hacking.Sessions.HandleTokenClick(ply, id)
end)

net.Receive("ixHackingAbort", function(len, ply)
    ix.hacking.Sessions.End(ply, "user_abort")
end)
