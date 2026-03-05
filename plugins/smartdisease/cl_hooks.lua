--- Smart Disease — Client-Side Hooks
-- Registers client-side hooks for HUD visibility, visual effect cleanup,
-- character change handling, and client event lifecycle management.
-- @module smartdisease.cl_hooks

local PLUGIN = PLUGIN

-- ═══════════════════════════════════════════════════════════════════════════════
-- CHARACTER CHANGE
-- ═══════════════════════════════════════════════════════════════════════════════

--- Clear client disease state when switching characters.
function PLUGIN:PlayerLoadedCharacter(client, character, lastChar)
    if (client != LocalPlayer()) then return end

    -- Clear visual state from previous character
    ix.disease._clientDiseases = {}
    ix.disease._activeVisuals = {}
    ix.disease._activeVisualExpiry = 0

    -- Stop all client events (heartbeat, tinnitus, clones, shadows, etc.)
    if (ix.disease.StopAllClientEvents) then
        ix.disease.StopAllClientEvents()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- HUD VISIBILITY
-- ═══════════════════════════════════════════════════════════════════════════════

--- Hide the disease HUD during certain conditions.
function PLUGIN:ShouldHideBars()
    -- Don't interfere with Helix default bar visibility.
    -- The disease HUD draws independently via HUDPaint.
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- VISUAL CLEANUP
-- ═══════════════════════════════════════════════════════════════════════════════

--- Clean up visual effects and client events when player dies.
function PLUGIN:PlayerDeath()
    ix.disease._activeVisuals = {}
    ix.disease._activeVisualExpiry = 0

    -- Stop all client events on death
    if (ix.disease.StopAllClientEvents) then
        ix.disease.StopAllClientEvents()
    end
end

--- Periodically clean expired one-shot visuals.
hook.Add("Think", "ixDiseaseVisualCleanup", function()
    if (CurTime() > (ix.disease._activeVisualExpiry or 0)) then
        if (!table.IsEmpty(ix.disease._activeVisuals or {})) then
            ix.disease._activeVisuals = {}
        end
    end
end)
