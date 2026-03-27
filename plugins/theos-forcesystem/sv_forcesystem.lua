--- Server-Side Force System
-- Handles spawn-time LSCS inventory sync from granted powers,
-- force pool recalculation, and character lifecycle events.
--
-- (depends on: LSCS addon Player meta, sh_force_pool.lua)
-- @module theos-forcesystem.sv_forcesystem

local PLUGIN = PLUGIN

--- Rebuild a player's LSCS inventory from their grantedPowers character data.
-- Wipes current LSCS inventory and re-adds everything from the persistent list.
-- @param client Player
local function syncPowersToLSCS(client)
    local char = client:GetCharacter()
    if not char then return end

    -- (depends on: LSCS addon Player meta)
    if not client.lscsWipeInventory then return end

    -- Wipe and rebuild so LSCS inventory always matches Helix data
    client:lscsWipeInventory(true)

    local granted = char:GetData("grantedPowers", {})
    for _, lscsClass in ipairs(granted) do
        client:lscsAddInventory(lscsClass, nil)
    end
end

--- Recalculate force pool and sync powers on spawn.
function PLUGIN:PlayerSpawn(client)
    timer.Simple(0, function()
        if not IsValid(client) then return end
        local char = client:GetCharacter()
        if not char then return end

        -- Refresh force pool from Helix attribute
        if client._ixForceRefreshPool then
            client:_ixForceRefreshPool()
        end

        -- Sync granted powers → LSCS inventory
        syncPowersToLSCS(client)

        -- Apply force regen baseline
        -- (depends on: player_effects plugin)
        if client.GetEffectValue and client.lscsSetForceRegenAmount then
            local regenMult = client:GetEffectValue("force.regen_rate") or 1
            client:lscsSetForceRegenAmount(regenMult)
        end
    end)
end

--- On character load, refresh the pool and sync powers after a brief delay
-- to let other plugins initialize.
function PLUGIN:PlayerLoadedCharacter(client, character)
    timer.Simple(1, function()
        if not IsValid(client) then return end
        if client:GetCharacter() ~= character then return end

        if client._ixForceRefreshPool then
            client:_ixForceRefreshPool()
        end

        syncPowersToLSCS(client)
    end)
end
