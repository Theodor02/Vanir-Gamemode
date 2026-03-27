--- LSCS → Player Effects Bridge
-- Registers LSCS-specific effect types and monkey-patches LSCS functions
-- to integrate with the player_effects framework.
--
-- New effect types:
--   force.cloak            — Boolean (>0 = cloaked), drives cloak rendering + NoTarget
--   force.rebuke           — Fraction (0-1) of incoming damage reflected to attacker
--   force.fall_immune      — Boolean (>0 = fall damage suppressed)
--   force.saber_damage     — Multiplier on lightsaber hit damage (attacker side)
--   force.saber_resistance — Multiplier on lightsaber damage received (victim side)
--   force.power_resistance — Multiplier on Force power damage received (victim side)
--   force.immunity         — Boolean (>0 = immune to incoming Force powers)
--   force.sense            — Tier value (1-4) for Force Sense levels
--
-- Monkey-patches:
--   lscsTakeForce        — Applies force.cost modifier to all force drains
--   LSCS:ApplyDamage     — Applies force.saber_damage (attacker) + force.saber_resistance (victim)
--   lscsSuppressFalldamage — Replaced by force.fall_immune AddEffect
--   GetFallDamage        — Checks force.fall_immune
--   EntityTakeDamage     — Checks force.rebuke + force.power_resistance
--   LSCS:PlayerCanManipulate — Checks force.immunity (replaces force_sense.lua hook)
--   LSCS.Force[*].StartUse — Tagged for force power damage detection
--   LSCS:PlayerForcePowerThink hooks — Tagged for force power damage detection
--
-- (depends on: player_effects plugin, LSCS addon)
-- @module theos-forcesystem.sh_lscs_effects_bridge

if not ix or not ix.playerEffects then return end

local PE   = ix.playerEffects
local REG  = PE.RegisterEffectType
local MULT = PE.MOD_MULT
local ADD  = PE.MOD_ADD
local SET  = PE.MOD_SET

-- ═══════════════════════════════════════════════════════════════════════════════
-- Effect Type: force.cloak
-- Tracks cloaked state. Any accumulated value > 0 = cloaked.
-- Velocity-based alpha rendering is handled by the memetispowers hook.
-- ═══════════════════════════════════════════════════════════════════════════════

REG("force.cloak", {
    name      = "Force Cloak",
    baseValue = 0,
    min       = 0,
    calcOrder = "add_first",
    modTypes  = {ADD, SET},
    apply = function(ply, value)
        if not SERVER then return end
        if value > 0 then
            ply:SetNWBool("IsCloaked", true)
        else
            -- Decloak: restore visuals deferred so render finishes this frame
            ply:SetNWBool("IsCloaked", false)
            timer.Simple(0, function()
                if not IsValid(ply) then return end
                ply:SetNoTarget(false)
                ply:SetColor(Color(255, 255, 255, 255))
                local weapon = ply:GetActiveWeapon()
                if IsValid(weapon) then weapon:SetColor(Color(255, 255, 255, 255)) end
                ply:SetDSP(0)
                ply:DrawShadow(true)
            end)
        end
    end,
    unapply = function(ply)
        if not SERVER then return end
        ply:SetNWBool("IsCloaked", false)
        timer.Simple(0, function()
            if not IsValid(ply) then return end
            ply:SetNoTarget(false)
            ply:SetColor(Color(255, 255, 255, 255))
            local weapon = ply:GetActiveWeapon()
            if IsValid(weapon) then weapon:SetColor(Color(255, 255, 255, 255)) end
            ply:SetDSP(0)
            ply:DrawShadow(true)
        end)
    end,
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- Effect Type: force.rebuke
-- When > 0, reflects that fraction (0-1) of incoming damage back to attacker.
-- e.g. 0.5 = 50% reflected, incoming damage scaled by (1 - fraction).
-- ═══════════════════════════════════════════════════════════════════════════════

REG("force.rebuke", {
    name      = "Force Rebuke",
    baseValue = 0,
    min       = 0,
    max       = 1,
    modTypes  = {ADD, SET},
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- Effect Type: force.fall_immune
-- Any accumulated value > 0 = fall damage suppressed.
-- ═══════════════════════════════════════════════════════════════════════════════

REG("force.fall_immune", {
    name      = "Fall Damage Immunity",
    baseValue = 0,
    min       = 0,
    calcOrder = "add_first",
    modTypes  = {ADD, SET},
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- Effect Type: force.saber_damage
-- Multiplier on lightsaber damage. 1.2 = +20% saber damage.
-- Read by the patched LSCS:ApplyDamage.
-- ═══════════════════════════════════════════════════════════════════════════════

REG("force.saber_damage", {
    name      = "Lightsaber Damage",
    baseValue = 1,
    min       = 0,
    modTypes  = {MULT, ADD},
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- Effect Type: force.saber_resistance
-- Multiplier on lightsaber damage received. 0.6 = 40% less saber damage taken.
-- Read by the patched LSCS:ApplyDamage (victim side).
-- ═══════════════════════════════════════════════════════════════════════════════

REG("force.saber_resistance", {
    name      = "Lightsaber Resistance",
    baseValue = 1,
    min       = 0,
    modTypes  = {MULT, ADD},
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- Effect Type: force.power_resistance
-- Multiplier on damage specifically dealt by Force powers. 0.5 = 50% less.
-- Detected by tagging active force power execution; checked in EntityTakeDamage.
-- ═══════════════════════════════════════════════════════════════════════════════

REG("force.power_resistance", {
    name      = "Force Power Resistance",
    baseValue = 1,
    min       = 0,
    modTypes  = {MULT, ADD},
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- Effect Type: force.immunity
-- Tracks active Force Power immunity (shield). Any value > 0 = immune.
-- Maintains legacy NWBool for client-side HUD overlay compatibility.
-- ═══════════════════════════════════════════════════════════════════════════════

REG("force.immunity", {
    name      = "Force Immunity",
    baseValue = 0,
    min       = 0,
    calcOrder = "add_first",
    modTypes  = {ADD, SET},
    apply = function(ply, value)
        if not SERVER then return end
        ply:SetNWBool("_lscsForceProtect", value > 0)
    end,
    unapply = function(ply)
        if not SERVER then return end
        ply:SetNWBool("_lscsForceProtect", false)
    end,
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- Effect Type: force.sense
-- Tier value for Force Sense (1=basic, 2=advanced, 3=mastered, 4=ultimate).
-- Maintains legacy NWBools so client-side stencil/HUD rendering works.
-- ═══════════════════════════════════════════════════════════════════════════════

REG("force.sense", {
    name      = "Force Sense",
    baseValue = 0,
    min       = 0,
    calcOrder = "add_first",
    modTypes  = {ADD, SET},
    apply = function(ply, value)
        if not SERVER then return end
        ply:SetNWBool("_lscsForceSense", value >= 1)
        ply:SetNWBool("_lscsForceSenseAdvanced", value >= 2)
        ply:SetNWBool("_lscsForceSenseMastered", value >= 3)
        ply:SetNWBool("_lscsForceSenseUltimate", value >= 4)
    end,
    unapply = function(ply)
        if not SERVER then return end
        ply:SetNWBool("_lscsForceSense", false)
        ply:SetNWBool("_lscsForceSenseAdvanced", false)
        ply:SetNWBool("_lscsForceSenseMastered", false)
        ply:SetNWBool("_lscsForceSenseUltimate", false)
    end,
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- SERVER: Monkey-patches & Hook Overrides
-- ═══════════════════════════════════════════════════════════════════════════════

if SERVER then

local PLAYER = FindMetaTable("Player")

-- ─────────────────────────────────────────────
-- Wire force.cost into lscsTakeForce
-- ─────────────────────────────────────────────

local _origTakeForce = PLAYER.lscsTakeForce
if _origTakeForce then
    function PLAYER:lscsTakeForce(amount)
        if amount and amount > 0 and self.GetEffectValue then
            local costMult = self:GetEffectValue("force.cost") or 1
            amount = amount * costMult
        end
        return _origTakeForce(self, amount)
    end
end

-- ─────────────────────────────────────────────
-- Wire force.fall_immune into lscsSuppressFalldamage
-- Patch the player meta so existing code that calls
-- lscsSuppressFalldamage now uses player_effects.
-- ─────────────────────────────────────────────

function PLAYER:lscsSuppressFalldamage(time)
    if self.AddEffect then
        local duration
        if time == true then
            duration = 999999
        else
            duration = math.max(0, (time or 0) - CurTime())
        end
        if duration > 0 then
            self:AddEffect("force.fall_immune", "lscs_fall_suppress", ADD, 1, {
                duration = duration,
                layer = "temporary",
                refreshBehavior = "extend",
            })
        end
    else
        -- Fallback for players without player_effects
        self._lscsPreventFallDamageTill = time
    end
end

function PLAYER:lscsIsFalldamageSuppressed()
    if self.GetEffectValue then
        local immune = self:GetEffectValue("force.fall_immune") or 0
        if immune > 0 then return true end
    end
    -- Legacy fallback
    if self._lscsPreventFallDamageTill == true then
        return true
    end
    return (self._lscsPreventFallDamageTill or 0) > CurTime()
end

-- ─────────────────────────────────────────────
-- Wire force.saber_damage into LSCS:ApplyDamage
-- Deferred to ensure LSCS is loaded first.
-- ─────────────────────────────────────────────

timer.Simple(0, function()
    if not LSCS or not LSCS.ApplyDamage then return end

    local _origApplyDamage = LSCS.ApplyDamage

    function LSCS:ApplyDamage(ply, victim, pos, dir)
        local origDamage = self.SaberDamage
        local modified = origDamage

        -- Attacker: saber damage multiplier
        if IsValid(ply) and ply.GetEffectValue then
            local mult = ply:GetEffectValue("force.saber_damage") or 1
            if mult ~= 1 then
                modified = modified * mult
            end
        end

        -- Victim: saber resistance multiplier
        if IsValid(victim) and victim.IsPlayer and victim:IsPlayer() and victim.GetEffectValue then
            local resist = victim:GetEffectValue("force.saber_resistance") or 1
            if resist ~= 1 then
                modified = modified * resist
            end
        end

        if modified ~= origDamage then
            self.SaberDamage = math.max(0, math.floor(modified))
        end

        _origApplyDamage(self, ply, victim, pos, dir)
        self.SaberDamage = origDamage
    end
end)

-- ─────────────────────────────────────────────
-- Tag force power execution for damage tracking
-- Wraps every registered force power's StartUse
-- and OnClk so any TakeDamage during execution
-- can be identified as force power damage.
-- ─────────────────────────────────────────────

timer.Simple(0, function()
    if not LSCS or not LSCS.Force then return end

    -- Wrap StartUse for each registered force power
    for id, data in pairs(LSCS.Force) do
        local origStart = data.StartUse
        if origStart then
            data.StartUse = function(ply, ...)
                ply._ixForcePowerActive = true
                local ok, result = pcall(origStart, ply, ...)
                ply._ixForcePowerActive = nil
                if not ok then ErrorNoHaltWithStack(result) return end
                return result
            end
        end
    end

    -- Wrap OnClk hooks (registered on LSCS:PlayerForcePowerThink)
    local thinkHooks = hook.GetTable()["LSCS:PlayerForcePowerThink"]
    if thinkHooks then
        for name, fn in pairs(thinkHooks) do
            hook.Add("LSCS:PlayerForcePowerThink", name, function(ply, TIME)
                ply._ixForcePowerActive = true
                local ok, result = pcall(fn, ply, TIME)
                ply._ixForcePowerActive = nil
                if not ok then ErrorNoHaltWithStack(result) end
                return result
            end)
        end
    end
end)

-- ─────────────────────────────────────────────
-- Force power damage resistance (EntityTakeDamage)
-- Applies force.power_resistance when damage
-- originates from a tagged force power execution.
-- ─────────────────────────────────────────────

hook.Add("EntityTakeDamage", "ixForce_PowerResistance", function(ent, dmginfo)
    if not IsValid(ent) or not ent:IsPlayer() then return end

    local attacker = dmginfo:GetAttacker()
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    if not attacker._ixForcePowerActive then return end
    if not ent.GetEffectValue then return end

    local resist = ent:GetEffectValue("force.power_resistance") or 1
    if resist ~= 1 then
        dmginfo:ScaleDamage(resist)
    end
end)

-- ─────────────────────────────────────────────
-- Replace rebuke EntityTakeDamage hook
-- (replaces memetispowers sh_rebuke.lua hook)
-- ─────────────────────────────────────────────

timer.Simple(0, function()
    hook.Remove("EntityTakeDamage", "lscs_rebuke_hook")
end)

hook.Add("EntityTakeDamage", "ixForce_RebukeReflect", function(ply, dmginfo)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not ply.GetEffectValue then return end

    local rebukeFrac = ply:GetEffectValue("force.rebuke") or 0
    if rebukeFrac <= 0 then return end

    local damage = dmginfo:GetDamage()
    dmginfo:ScaleDamage(1 - rebukeFrac)

    local attacker = dmginfo:GetAttacker()
    if IsValid(attacker) and not dmginfo:IsFallDamage() then
        attacker:TakeDamage(damage * rebukeFrac, ply, ply)
    end
end)

-- ─────────────────────────────────────────────
-- Replace LSCS:PlayerCanManipulate immunity hook
-- (replaces !!!lscs_forceblocking from force_sense.lua)
-- ─────────────────────────────────────────────

timer.Simple(0, function()
    hook.Remove("LSCS:PlayerCanManipulate", "!!!lscs_forceblocking")
end)

hook.Add("LSCS:PlayerCanManipulate", "ixForce_ImmunityCheck", function(ply, target_ent, ignore_passive)
    if not target_ent or not target_ent.IsPlayer or not target_ent:IsPlayer() then return end

    -- Active immunity via player_effects
    if target_ent.GetEffectValue then
        local immune = target_ent:GetEffectValue("force.immunity") or 0
        if immune > 0 then
            -- Absorb and regain force
            if target_ent.lscsSetForce and target_ent.lscsGetForce then
                target_ent:lscsSetForce(math.min(target_ent:lscsGetForce() + 15, target_ent:lscsGetMaxForce()))
            end

            local effectdata = EffectData()
                effectdata:SetOrigin(target_ent:GetPos())
                effectdata:SetEntity(target_ent)
            util.Effect("force_block", effectdata, true, true)

            target_ent:EmitSound("lscs/force/block.mp3")
            if LSCS and LSCS.PlayVCDSequence then
                LSCS:PlayVCDSequence(target_ent, "walk_magic")
            end

            return true
        end
    end

    -- Passive resistance (equipped immunity power + >50% force)
    if ignore_passive then return end

    if target_ent._lscsForceResistant then
        local force = target_ent:lscsGetForce()
        local maxForce = target_ent:lscsGetMaxForce()
        if maxForce > 0 and force > (maxForce * 0.5) then
            if LSCS and LSCS.PlayVCDSequence then
                LSCS:PlayVCDSequence(target_ent, "walk_magic")
            end
            return true
        end
    end
end)

-- ─────────────────────────────────────────────
-- Replace cloak damage/death/fire hooks
-- (replaces memetispowers sh_cloak.lua hooks)
-- ─────────────────────────────────────────────

timer.Simple(0, function()
    hook.Remove("PostEntityTakeDamage", "Cloak_OnDamageHook")
    hook.Remove("LSCS:EntityFireBullets", "Cloak_OnFireHook")
    hook.Remove("PlayerDeath", "Cloak_OnDeathHook")
end)

hook.Add("PostEntityTakeDamage", "ixForce_CloakBreakOnDamage", function(ent)
    if not IsValid(ent) or not ent:IsPlayer() then return end
    if ent.HasEffect and ent:HasEffect("force.cloak", "lscs_cloak") then
        ent:RemoveEffect("force.cloak", "lscs_cloak")
    end
end)

hook.Add("LSCS:EntityFireBullets", "ixForce_CloakBreakOnFire", function(ent, data)
    if not IsValid(ent) then return end
    local ply = ent:IsPlayer() and ent or ent:GetOwner()
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if ply.HasEffect and ply:HasEffect("force.cloak", "lscs_cloak") then
        ply:RemoveEffect("force.cloak", "lscs_cloak")
    end
end)

hook.Add("PlayerDeath", "ixForce_CloakBreakOnDeath", function(ply)
    if not IsValid(ply) then return end
    if ply.HasEffect and ply:HasEffect("force.cloak", "lscs_cloak") then
        ply:RemoveEffect("force.cloak", "lscs_cloak")
    end
end)

-- ─────────────────────────────────────────────
-- Patch EndCloak to use player_effects
-- ─────────────────────────────────────────────

function PLAYER:EndCloak()
    if not IsValid(self) then return end
    if self.RemoveEffect then
        -- Remove any active cloak effect; unapply callback handles visuals
        self:RemoveEffect("force.cloak", "lscs_cloak")
    else
        -- Legacy fallback
        self:SetNWBool("IsCloaked", false)
        timer.Simple(0, function()
            if not IsValid(self) then return end
            self:SetNoTarget(false)
            self:SetColor(Color(255, 255, 255, 255))
            local weapon = self:GetActiveWeapon()
            if IsValid(weapon) then weapon:SetColor(Color(255, 255, 255, 255)) end
            self:SetDSP(0)
            self:DrawShadow(true)
        end)
    end
end

end -- SERVER
