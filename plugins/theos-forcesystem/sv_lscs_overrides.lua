--- LSCS Overrides
-- Disables LSCS's built-in inventory management, auto-equip, menu UI,
-- and inventory persistence. The force system plugin replaces all of
-- this with the Helix unlock tree and ix.force API.
--
-- Also bridges Helix config options to LSCS server ConVars so that
-- admin settings are managed through Helix's config UI instead of
-- the disabled LSCS admin menu.
--
-- Works by removing LSCS hooks and stubbing functions AFTER LSCS loads.
-- Non-destructive — the addon files are not modified.
--
-- (depends on: LSCS addon)
-- @module theos-forcesystem.sv_lscs_overrides

-- ─────────────────────────────────────────────
-- Remove LSCS hooks that auto-manage inventory
-- ─────────────────────────────────────────────

--- Defer until next tick to ensure LSCS hooks are registered first.
timer.Simple(0, function()
    -- Disable auto-equip on spawn (LSCS auto-crafts saber and sets BP)
    hook.Remove("PlayerSpawn", "!!!!!lscs_auto_equip")

    -- Disable inventory save/restore system
    hook.Remove("PlayerInitialSpawn", "!!!lscs_inventory_saver")
    hook.Remove("LSCS:PlayerInventory", "!!!lscs_inventory_saver")
    hook.Remove("LSCS:OnPlayerDroppedItem", "!!!lscs_inventory_saver")
    hook.Remove("LSCS:OnPlayerEquippedItem", "!!!lscs_inventory_saver")
    hook.Remove("LSCS:OnPlayerUnEquippedItem", "!!!lscs_inventory_saver")
end)

-- ─────────────────────────────────────────────
-- Bridge Helix Config → LSCS Server ConVars (initial sync)
-- Ongoing changes are handled by callbacks on ix.config.Add
-- in sh_plugin.lua. This only syncs values at server start.
-- ─────────────────────────────────────────────

local LSCS_CONFIG_KEYS = {
    "lscsSaberDamage",
    "lscsDeflectDrainMul",
    "lscsDeflectDrainMin",
    "lscsDeflectDrainMax",
    "lscsBulletInterruptAttack",
}

local CONVAR_MAP = {
    lscsSaberDamage           = "lscs_sv_saberdamage",
    lscsDeflectDrainMul       = "lscs_sv_forcedrain_per_bullet_mul",
    lscsDeflectDrainMin       = "lscs_sv_forcedrain_per_bullet_min",
    lscsDeflectDrainMax       = "lscs_sv_forcedrain_per_bullet_max",
    lscsBulletInterruptAttack = "lscs_sv_bullet_can_interrupt_attack",
}

hook.Add("InitPostEntity", "ixLSCSConVarBridgeInit", function()
    timer.Simple(1, function()
        for _, key in ipairs(LSCS_CONFIG_KEYS) do
            local value = ix.config.Get(key)
            local convar = CONVAR_MAP[key]
            if value ~= nil and convar then
                if isbool(value) then value = value and "1" or "0" end
                RunConsoleCommand(convar, tostring(value))
            end
        end
    end)
end)
