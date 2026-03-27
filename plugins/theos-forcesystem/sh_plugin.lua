--- The Force — Core Plugin
-- Manages Force sensitivity, the LSCS bridge, stamina integration,
-- meditation, and the framework for perk-tree-driven power grants.
--
-- Architecture:
--   sh_plugin.lua         → config, meditation command, player effects registration, power registry API
--   sh_unlocktree.lua     → force power / saber stance unlock tree (unlocktrees plugin)
--   sv_forcesystem.lua    → server: force pool scaling, power LSCS sync, spawn hooks
--   cl_forcesystem.lua    → client: force whisper rendering + LSCS menu disable
--   sh_stamina_bridge.lua → replaces LSCS Block Points with Helix stamina (direct takeover)
--   sh_force_pool.lua     → monkey-patch LSCS force pool to derive from Helix 'force' attribute
--   sv_whispers.lua       → server: periodic force whisper dispatch
--   sv_lscs_overrides.lua → server: disables LSCS auto-equip, inventory save/restore hooks
--
-- Cross-plugin dependencies (called directly):
--   • player_effects   — ix.playerEffects.RegisterEffectType, ply:AddEffect/RemoveEffect/GetEffectValue
--   • smartdisease     — ix.disease.HandleClientEvent (intrusive_thought, fleeting_thought) style rendering
--   • helix/stamina    — ply:ConsumeStamina, ply:RestoreStamina, GetLocalVar("stm"), brth netvar
--   • LSCS addon       — Player meta: lscsGet/Set Force/MaxForce, lscsAddInventory, etc.
--   • LSCS weapon_lscs — SWEP:DrainBP, SWEP:CalcBPRegen, SWEP:GetBlockPoints (melee stamina)
-- @module theos-forcesystem

local PLUGIN = PLUGIN
PLUGIN.name        = "The Force"
PLUGIN.author      = "Theodor"
PLUGIN.description = "Force sensitivity framework with LSCS integration, stamina bridging, and perk-tree-ready power management."

-- ─────────────────────────────────────────────
-- Sub-file includes (order matters)
-- ─────────────────────────────────────────────

ix.util.Include("sh_lscs_effects_bridge.lua")
ix.util.Include("sh_force_pool.lua")
ix.util.Include("sh_stamina_bridge.lua")
ix.util.Include("sh_unlocktree.lua")
ix.util.Include("sv_forcesystem.lua")
ix.util.Include("sv_whispers.lua")
ix.util.Include("sv_lscs_overrides.lua")
ix.util.Include("cl_forcesystem.lua")

-- ─────────────────────────────────────────────
-- Networking
-- ─────────────────────────────────────────────

if SERVER then
    util.AddNetworkString("ixForceWhisper")
end

-- ─────────────────────────────────────────────
-- Configuration
-- ─────────────────────────────────────────────

ix.config.Add("forcePoolMultiplier", 1.5, "Multiplier applied to the 'force' attribute to derive max LSCS force pool.", nil, {
    data = {min = 0.1, max = 10, decimals = 2},
    category = "The Force"
})

ix.config.Add("forceWhisperInterval", 120, "Seconds between force whisper checks per player.", nil, {
    data = {min = 10, max = 600},
    category = "The Force"
})

ix.config.Add("forceWhisperChance", 5, "Chance (1-100%) for a force whisper to trigger each interval.", nil, {
    data = {min = 1, max = 100},
    category = "The Force"
})

ix.config.Add("meditateDuration", 60, "Duration (seconds) of the meditate action.", nil, {
    data = {min = 5, max = 300},
    category = "The Force"
})

ix.config.Add("meditateCooldown", 300, "Cooldown (seconds) before meditating again.", nil, {
    data = {min = 10, max = 3600},
    category = "The Force"
})

ix.config.Add("forceTouchChance", 1, "Base chance (%) to gain force attribute when touching a holocron.", nil, {
    data = {min = 1, max = 100},
    category = "The Force"
})

ix.config.Add("forceLearnChance", 1, "Base chance (%) to gain force attribute when learning from a holocron.", nil, {
    data = {min = 1, max = 100},
    category = "The Force"
})

ix.config.Add("wisdomEffect", 1, "Percentage increase per 'wis' point for force interactions.", nil, {
    data = {min = 0, max = 100},
    category = "The Force"
})

ix.config.Add("staminaBridgeEnabled", true, "Whether LSCS Block Points are replaced by Helix stamina — sprinting, blocking, and attacking all share one pool.", nil, {
    category = "The Force"
})

-- ─────────────────────────────────────────────
-- LSCS Lightsaber Configuration (replaces admin menu)
-- Callbacks push values to LSCS server ConVars on change.
-- ─────────────────────────────────────────────

local function lscsConVarCallback(convar)
    return function(oldValue, newValue)
        if not SERVER then return end
        if isbool(newValue) then newValue = newValue and "1" or "0" end
        RunConsoleCommand(convar, tostring(newValue))
    end
end

ix.config.Add("lscsSaberDamage", 200, "Base damage per lightsaber hit.",
    lscsConVarCallback("lscs_sv_saberdamage"), {
    data = {min = 0, max = 2000},
    category = "Lightsaber"
})

ix.config.Add("lscsDeflectDrainMul", 0.1, "Bullet damage is multiplied by this to calculate force drain on deflect.",
    lscsConVarCallback("lscs_sv_forcedrain_per_bullet_mul"), {
    data = {min = 0, max = 1, decimals = 2},
    category = "Lightsaber"
})

ix.config.Add("lscsDeflectDrainMin", 1, "Minimum force drained when deflecting a bullet.",
    lscsConVarCallback("lscs_sv_forcedrain_per_bullet_min"), {
    data = {min = 0, max = 10, decimals = 1},
    category = "Lightsaber"
})

ix.config.Add("lscsDeflectDrainMax", 5, "Maximum force drained when deflecting a bullet.",
    lscsConVarCallback("lscs_sv_forcedrain_per_bullet_max"), {
    data = {min = 0, max = 100, decimals = 1},
    category = "Lightsaber"
})

ix.config.Add("lscsBulletInterruptAttack", true, "Whether player bullets can interrupt an active lightsaber attack combo.",
    lscsConVarCallback("lscs_sv_bullet_can_interrupt_attack"), {
    category = "Lightsaber"
})

-- ─────────────────────────────────────────────
-- Player Effects Registration
-- (depends on: player_effects plugin)
-- ─────────────────────────────────────────────

if ix.playerEffects then
    local PE   = ix.playerEffects
    local REG  = PE.RegisterEffectType
    local MULT = PE.MOD_MULT
    local ADD  = PE.MOD_ADD

    -- Multiplier on max force pool. 1.2 = +20% pool.
    REG("force.pool_max", {
        name      = "Force Pool Maximum",
        baseValue = 1,
        min       = 0,
        modTypes  = {MULT, ADD},
        apply = function(ply, value)
            -- sh_force_pool.lua reads this via GetEffectValue when recalculating.
            if ply._ixForceRefreshPool then
                ply:_ixForceRefreshPool()
            end
        end,
    })

    -- Multiplier on force regen rate. Directly sets LSCS regen amount.
    REG("force.regen_rate", {
        name      = "Force Regen Rate",
        baseValue = 1,
        min       = 0,
        modTypes  = {MULT, ADD},
        apply = function(ply, value)
            -- (depends on: LSCS addon Player meta)
            if ply.lscsSetForceRegenAmount then
                ply:lscsSetForceRegenAmount(value)
            end
        end,
        unapply = function(ply)
            if ply.lscsSetForceRegenAmount then
                ply:lscsSetForceRegenAmount(1)
            end
        end,
    })

    -- Multiplier on force cost (how expensive powers are). 0.8 = 20% cheaper.
    -- Available for perk tree / buff effects to scale lscsTakeForce costs.
    REG("force.cost", {
        name      = "Force Power Cost",
        baseValue = 1,
        min       = 0,
        modTypes  = {MULT, ADD},
    })
end

-- ─────────────────────────────────────────────
-- Meditation Command
-- ─────────────────────────────────────────────

ix.command.Add("meditate", {
    description = "Sit and meditate to focus your connection to the Force.",
    OnRun = function(self, client)
        local char = client:GetCharacter()
        if not char then return end

        if client:GetNetVar("isMeditating", false) then
            client:Notify("You are already meditating.")
            return
        end

        if not client:GetSitting() then
            client:Notify("You must be sitting to meditate.")
            return
        end

        local force = char:GetAttribute("force", 0)
        if force <= 0 then
            client:Notify("You feel nothing when you try to focus.")
            return
        end

        local last = char:GetData("lastMeditate", 0)
        local now  = os.time()
        local cd   = math.Clamp(ix.config.Get("meditateCooldown", 300), 10, 3600)
        local dur  = math.Clamp(ix.config.Get("meditateDuration", 60), 5, 300)

        if now < last + cd then
            local remaining = (last + cd) - now
            client:Notify("You must wait " .. remaining .. " seconds before meditating again.")
            return
        end

        char:SetData("lastMeditate", now)
        client:SetNetVar("isMeditating", true)
        client:Notify("You close your eyes and begin to meditate.")

        local hookID = "ixForceMeditation_" .. client:SteamID64()

        client:SetAction("Meditating...", dur, function()
            if not IsValid(client) then return end
            client:SetNetVar("isMeditating", false)
            client:SetAction()

            local wis = char:GetAttribute("wis", 0)
            if math.random(100) <= math.max(1, wis * 0.1) then
                char:UpdateAttrib("force", math.Rand(0.1, 0.5))
                client:Notify("Your mind expands. You feel more attuned to the Force.")
            else
                char:UpdateAttrib("wis", math.Rand(0.01, 0.1))
                client:Notify("A calm clarity washes over you.")
            end

            -- Temporary force regen buff via player_effects
            -- (depends on: player_effects plugin)
            if client.AddEffect and ix.playerEffects then
                client:AddEffect("force.regen_rate", "meditation_afterglow", ix.playerEffects.MOD_MULT, 1.5, {
                    duration = 60,
                    layer = "buff",
                })
            end

            hook.Remove("KeyPress", hookID)
        end)

        hook.Add("KeyPress", hookID, function(ply, key)
            if ply ~= client then return end
            if key == IN_FORWARD or key == IN_BACK or
               key == IN_MOVELEFT or key == IN_MOVERIGHT or key == IN_JUMP then
                client:SetNetVar("isMeditating", false)
                client:SetAction()
                client:Notify("Your meditation is interrupted.")
                hook.Remove("KeyPress", hookID)
            end
        end)
    end
})

-- ─────────────────────────────────────────────
-- Force Power Registry
-- ─────────────────────────────────────────────
-- Central metadata table for all force powers and stances.
-- The perk tree (when added) will be the authoritative system that
-- grants/revokes these. This registry just holds what exists.
--
-- Nothing here auto-grants powers. That is the perk tree's job.

ix.force = ix.force or {}
ix.force.powers = ix.force.powers or {}

--- Register a force power or stance in the central registry.
-- @param lscsClass string LSCS inventory item class (e.g. "item_force_push")
-- @param data table {name, type ("force"|"stance"), description, tier}
function ix.force.RegisterPower(lscsClass, data)
    data.lscsClass = lscsClass
    data.type = data.type or "force"
    data.tier = data.tier or 1
    ix.force.powers[lscsClass] = data
end

--- Get a registered power's metadata.
-- @param lscsClass string
-- @return table or nil
function ix.force.GetPower(lscsClass)
    return ix.force.powers[lscsClass]
end

--- Get all registered powers of a given type.
-- @param powerType string "force" or "stance"
-- @return table {[lscsClass] = data, ...}
function ix.force.GetPowersByType(powerType)
    local out = {}
    for class, data in pairs(ix.force.powers) do
        if data.type == powerType then
            out[class] = data
        end
    end
    return out
end

-- ─────────────────────────────────────────────
-- Power / Stance Grant API
-- (framework for perk tree to call)
-- ─────────────────────────────────────────────

--- Grant a force power or stance to a character.
-- Persists to character data and syncs to LSCS inventory.
-- @param client Player
-- @param lscsClass string LSCS item class
-- @param equip bool|nil Auto-equip (true=right hand, false=left, nil=no)
-- @return bool success
function ix.force.Grant(client, lscsClass, equip)
    if CLIENT or not IsValid(client) then return false end

    local char = client:GetCharacter()
    if not char then return false end

    local granted = char:GetData("grantedPowers", {})
    if table.HasValue(granted, lscsClass) then return false end

    table.insert(granted, lscsClass)
    char:SetData("grantedPowers", granted)

    -- (depends on: LSCS addon Player meta)
    if client.lscsAddInventory then
        client:lscsAddInventory(lscsClass, equip)
    end

    hook.Run("ForceSystemPowerGranted", client, lscsClass)
    return true
end

--- Revoke a force power or stance from a character.
-- @param client Player
-- @param lscsClass string
-- @return bool success
function ix.force.Revoke(client, lscsClass)
    if CLIENT or not IsValid(client) then return false end

    local char = client:GetCharacter()
    if not char then return false end

    local granted = char:GetData("grantedPowers", {})
    local removed = false
    for i = #granted, 1, -1 do
        if granted[i] == lscsClass then
            table.remove(granted, i)
            removed = true
            break
        end
    end
    if not removed then return false end

    char:SetData("grantedPowers", granted)

    -- (depends on: LSCS addon Player meta)
    if client.lscsGetInventory then
        for i, class in pairs(client:lscsGetInventory()) do
            if class == lscsClass then
                client:lscsRemoveItem(i)
                break
            end
        end

        -- Rebuild the saber so LSCS reflects the change immediately
        if client.lscsBuildPlayerInfo then
            client:lscsBuildPlayerInfo()
        end
        if client.lscsCraftSaber then
            client:lscsCraftSaber(true)
        end
    end

    hook.Run("ForceSystemPowerRevoked", client, lscsClass)
    return true
end

--- Check if a character has been granted a specific power.
-- @param client Player
-- @param lscsClass string
-- @return bool
function ix.force.HasPower(client, lscsClass)
    local char = client:GetCharacter()
    if not char then return false end
    return table.HasValue(char:GetData("grantedPowers", {}), lscsClass)
end

--- Get all granted powers for a character.
-- @param client Player
-- @return table Array of lscsClass strings
function ix.force.GetGrantedPowers(client)
    local char = client:GetCharacter()
    if not char then return {} end
    return char:GetData("grantedPowers", {})
end

-- ─────────────────────────────────────────────
-- Default Power Definitions
-- ─────────────────────────────────────────────
-- Metadata registration only. Nothing is auto-granted.

ix.force.RegisterPower("item_force_push",        {name = "Force Push",        type = "force",  tier = 1, description = "Push objects and enemies away."})
ix.force.RegisterPower("item_force_pull",        {name = "Force Pull",        type = "force",  tier = 1, description = "Pull objects and enemies toward you."})
ix.force.RegisterPower("item_force_heal",        {name = "Force Heal",        type = "force",  tier = 1, description = "Heal yourself using the Force."})
ix.force.RegisterPower("item_force_jump",        {name = "Force Jump",        type = "force",  tier = 1, description = "Leap great distances."})
ix.force.RegisterPower("item_force_sense",       {name = "Force Sense",       type = "force",  tier = 1, description = "Heightened awareness of your surroundings."})
ix.force.RegisterPower("item_force_lightning",   {name = "Force Lightning",   type = "force",  tier = 3, description = "Channel destructive lightning."})
ix.force.RegisterPower("item_force_immunity",    {name = "Force Immunity",    type = "force",  tier = 2, description = "Resist Force-based attacks."})
ix.force.RegisterPower("item_force_replenish",   {name = "Force Replenish",   type = "force",  tier = 2, description = "Rapidly restore your Force pool."})

ix.force.RegisterPower("item_stance_aggresive",     {name = "Aggressive Form",  type = "stance", tier = 1, description = "High damage, lower defense."})
ix.force.RegisterPower("item_stance_agile",         {name = "Agile Form",       type = "stance", tier = 1, description = "Fast attacks, balanced defense."})
ix.force.RegisterPower("item_stance_defensive",     {name = "Defensive Form",   type = "stance", tier = 1, description = "Strong blocks, lower damage."})
ix.force.RegisterPower("item_stance_butterfly",     {name = "Butterfly Form",   type = "stance", tier = 2, description = "Acrobatic and risky."})
ix.force.RegisterPower("item_stance_dualwield",     {name = "Dual Wield",       type = "stance", tier = 2, description = "Two sabers at once."})
ix.force.RegisterPower("item_stance_saberstaff",    {name = "Saberstaff Form",  type = "stance", tier = 2, description = "Double-bladed technique."})
ix.force.RegisterPower("item_stance_saberstaffdual",{name = "Dual Saberstaff",  type = "stance", tier = 3, description = "Advanced double-blade technique."})
ix.force.RegisterPower("item_stance_arrogant",      {name = "Arrogant Form",    type = "stance", tier = 2, description = "Intimidating and aggressive."})

-- ─────────────────────────────────────────────
-- Character Lifecycle Hooks
-- ─────────────────────────────────────────────

function PLUGIN:PlayerLoadedCharacter(client, character)
    if not SERVER then return end

    -- Sanitize meditation cooldown data
    local cd   = math.Clamp(ix.config.Get("meditateCooldown", 300), 10, 3600)
    local last = character:GetData("lastMeditate", 0)
    local now  = os.time()
    if last > now or last < 0 then
        character:SetData("lastMeditate", now - cd)
    end
end
