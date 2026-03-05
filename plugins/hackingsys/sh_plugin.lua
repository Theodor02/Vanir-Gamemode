local PLUGIN = PLUGIN

PLUGIN.name = "Terminal Hacking System"
PLUGIN.author = "Vanir"
PLUGIN.description = "A Fallout-style terminal hacking minigame. Players navigate a hex-dump grid of words and bracket tokens to guess the correct password."

--- @module ix.hacking
-- Terminal Hacking System namespace.
ix.hacking = ix.hacking or {}

ix.util.Include("sh_config.lua")
ix.util.Include("sh_effects.lua")
ix.util.Include("sv_generator.lua")
ix.util.Include("sv_sessions.lua")
ix.util.Include("sv_effects.lua")
ix.util.Include("sv_net.lua")
ix.util.Include("cl_net.lua")
ix.util.Include("cl_terminal.lua")

-- Auto-load effect definitions
local files = file.Find(PLUGIN.folder .. "/effects/*.lua", "LUA")
for _, f in ipairs(files or {}) do
    ix.util.Include("effects/" .. f)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DEBUG / TEST COMMANDS (shared)
-- ═══════════════════════════════════════════════════════════════════════════════

--- Start a hacking session with an optional preset name.
-- Usage: /HackingTest [preset]
-- Presets: very_easy, easy, average, hard, very_hard
ix.command.Add("HackingTest", {
    description = "Start a test hacking session with an optional preset.",
    adminOnly = true,
    arguments = bit.bor(ix.type.string, ix.type.optional),
    OnRun = function(self, client, preset)
        preset = preset or "average"

        if (!ix.hacking.Presets[preset]) then
            return "@Invalid preset. Options: very_easy, easy, average, hard, very_hard"
        end

        ix.hacking.Sessions.Start(client, {preset = preset})
    end
})

--- Force-end the caller's active hacking session.
-- Usage: /HackingEnd
ix.command.Add("HackingEnd", {
    description = "Force-end your active hacking session.",
    adminOnly = true,
    OnRun = function(self, client)
        if (!ix.hacking.Sessions.Get(client)) then
            return "@No active hacking session."
        end

        ix.hacking.Sessions.End(client, "admin_end")
    end
})

--- Dump info about the caller's active session to server console.
-- Usage: /HackingDebug
ix.command.Add("HackingDebug", {
    description = "Print debug info about your active hacking session.",
    superAdminOnly = true,
    OnRun = function(self, client)
        local session = ix.hacking.Sessions.Get(client)

        if (!session) then
            return "@No active hacking session."
        end

        print("[ix.hacking] Debug for " .. client:Nick())
        print("  Solution:  " .. tostring(session.solution))
        print("  Attempts:  " .. tostring(session.attempts) .. "/" .. tostring(session.maxAttempts))
        print("  Grid:      " .. tostring(session.lines) .. " lines x " .. tostring(session.width) .. " chars")
        print("  Elapsed:   " .. string.format("%.1fs", CurTime() - session.startTime))

        local wordCount, bracketCount, junkCount = 0, 0, 0
        for _, t in pairs(session.tokens) do
            if (t.kind == "word") then wordCount = wordCount + 1
            elseif (t.kind == "bracket") then bracketCount = bracketCount + 1
            else junkCount = junkCount + 1 end
        end

        print("  Tokens:    " .. wordCount .. " words, " .. bracketCount .. " brackets, " .. junkCount .. " junk")
        print("  Limits:    " .. table.ToString(session.effectLimits or {}, "effectLimits", true))

        client:ChatPrint("[HACKING] Debug info printed to server console.")
    end
})

--- Start a hacking session on a target player (by name).
-- Usage: /HackingForce <player> [preset]
ix.command.Add("HackingForce", {
    description = "Force-start a hacking session on another player.",
    superAdminOnly = true,
    arguments = {
        ix.type.player,
        bit.bor(ix.type.string, ix.type.optional)
    },
    OnRun = function(self, client, target, preset)
        preset = preset or "average"

        if (!ix.hacking.Presets[preset]) then
            return "@Invalid preset. Options: very_easy, easy, average, hard, very_hard"
        end

        ix.hacking.Sessions.Start(target, {preset = preset})
        client:ChatPrint("[HACKING] Started '" .. preset .. "' session on " .. target:Nick() .. ".")
    end
})
