--- Stamina Takeover
-- Makes LSCS weapon_lscs Block Points (BP) read and write directly
-- from/to Helix stamina instead of the weapon's own NetworkVar pool.
--
-- How it works:
--   • GetBlockPoints() → returns Helix stamina scaled to combo's MaxBlockPoints
--   • DrainBP(amount)  → calls ply:ConsumeStamina(normalized amount)
--   • CalcBPRegen()    → disabled (Helix stamina has its own regen system)
--   • GetMaxBlockPoints() → unchanged (combo-defined, used for HUD/scaling)
--
-- Effect: sprinting drains the same pool as saber blocking/attacking.
-- A tired fighter blocks worse. Guard break = Helix exhaustion.
--
-- (depends on: LSCS weapon_lscs SWEP, helix/plugins/stamina)
-- @module theos-forcesystem.sh_stamina_bridge

--- Patch weapon_lscs SWEP table after all weapons are registered.
-- Uses timer.Simple(0) to ensure weapon files have loaded.
timer.Simple(0, function()
    local stored = weapons.GetStored("weapon_lscs")
    if not stored then return end

    if not ix.config.Get("staminaBridgeEnabled", true) then return end

    -- ─── DrainBP → drain Helix stamina directly ───
    -- Amount is in BP units (0 to MaxBlockPoints scale).
    -- Normalize to Helix 0-100 scale before consuming.
    stored.DrainBP = function(self, amount)
        if not amount then return end
        if amount <= 0 then return end

        local owner = self:GetOwner()
        if not IsValid(owner) or not owner.ConsumeStamina then return end

        local maxBP = self:GetMaxBlockPoints()
        local helixDrain = amount / maxBP * 100

        owner:ConsumeStamina(helixDrain)
    end

    -- ─── CalcBPRegen → disabled for stamina (Helix handles regen) ───
    -- Keep the _ResetHitTime / AddHit logic since that tracks combo hits, not stamina.
    stored.CalcBPRegen = function(self, CurTime)
        if self._ResetHitTime and self._ResetHitTime < CurTime then
            self._ResetHitTime = CurTime + 1
            self:AddHit(-0.1)
        end
    end

    -- ─── Override Initialize to replace GetBlockPoints per-entity ───
    -- GetBlockPoints/SetBlockPoints are NetworkVar accessors created on
    -- the entity instance in SetupDataTables, so they shadow SWEP table
    -- methods. We must replace them post-init on each weapon instance.
    local _origInit = stored.Initialize

    stored.Initialize = function(self, ...)
        if _origInit then _origInit(self, ...) end

        -- Replace the NetworkVar accessor with a Helix stamina proxy
        self.GetBlockPoints = function(swep)
            local owner = swep:GetOwner()
            if not IsValid(owner) or not owner.GetLocalVar then return 0 end

            local helixStm = owner:GetLocalVar("stm", 100)
            local maxBP = swep:GetMaxBlockPoints()

            return math.floor(helixStm / 100 * maxBP)
        end
    end
end)
