--- Force Pool Bridge
-- Monkey-patches LSCS force pool to derive max force from the Helix
-- "force" attribute, scaled by `forcePoolMultiplier` config and
-- the player_effects `force.pool_max` modifier.
--
-- (depends on: LSCS addon Player meta, player_effects plugin)
-- @module theos-forcesystem.sh_force_pool

if not SERVER then return end

local PLAYER = FindMetaTable("Player")

-- Stash originals so we can call them inside the patches.
local _origSetMaxForce = PLAYER.lscsSetMaxForce
local _origGetMaxForce = PLAYER.lscsGetMaxForce

--- Recalculate and apply the LSCS max force pool from Helix data.
-- Called on spawn, character load, and whenever player_effects force.pool_max fires.
function PLAYER:_ixForceRefreshPool()
    local char = self:GetCharacter()
    if not char then return end

    local forceAttr = char:GetAttribute("force", 0)
    if forceAttr <= 0 then
        -- No Force sensitivity — zero pool
        if _origSetMaxForce then
            _origSetMaxForce(self, 0)
            self:lscsSetForce(0)
        end
        return
    end

    local multiplier = ix.config.Get("forcePoolMultiplier", 1.5)
    local base = forceAttr * multiplier

    -- Apply player_effects force.pool_max modifier (defaults to 1 = no change)
    local effectMult = 1
    if self.GetEffectValue then
        effectMult = self:GetEffectValue("force.pool_max") or 1
    end

    local finalMax = math.max(1, math.floor(base * effectMult))

    if _origSetMaxForce then
        _origSetMaxForce(self, finalMax)
    end

    -- Clamp current force to new max
    if self.lscsGetForce and self:lscsGetForce() > finalMax then
        self:lscsSetForce(finalMax)
    end
end

--- Override lscsSetMaxForce to log external writes but still allow them.
-- Anything the perk tree or other systems set directly still works;
-- _ixForceRefreshPool later resets it to the canonical value.
function PLAYER:lscsSetMaxForce(value)
    if _origSetMaxForce then
        _origSetMaxForce(self, value)
    end
end
