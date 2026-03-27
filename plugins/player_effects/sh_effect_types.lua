--- Player Effects Registry – Built-in Effect Type Definitions
-- Registers all standard effect categories so they are available out of the box.
-- Plugins may register additional types via ix.playerEffects.RegisterEffectType().
-- @module ix.playerEffects (Effect Types)

local PE  = ix.playerEffects
local REG = PE.RegisterEffectType
local MULT = PE.MOD_MULT
local ADD  = PE.MOD_ADD
local SET  = PE.MOD_SET

-- ═══════════════════════════════════════════════════════════════════════════════
-- Speed & Movement
-- ═══════════════════════════════════════════════════════════════════════════════

-- Multiplier applied to the base run speed from config.
-- MULT 0.9 = 10 % slower, ADD -0.1 = subtract 10 percentage-points.
REG("speed.run", {
    name     = "Run Speed",
    baseValue = 1,
    min       = 0,
    modTypes  = {MULT, ADD, SET},
    apply = function(ply, value)
        local baseRun = (ix.config and ix.config.Get("runSpeed")) or 200
        ply:SetRunSpeed(math.max(0, baseRun * value))
    end,
    unapply = function(ply)
        local baseRun = (ix.config and ix.config.Get("runSpeed")) or 200
        ply:SetRunSpeed(baseRun)
    end,
})

REG("speed.walk", {
    name     = "Walk Speed",
    baseValue = 1,
    min       = 0,
    modTypes  = {MULT, ADD, SET},
    apply = function(ply, value)
        local baseWalk = (ix.config and ix.config.Get("walkSpeed")) or 100
        ply:SetWalkSpeed(math.max(0, baseWalk * value))
    end,
    unapply = function(ply)
        local baseWalk = (ix.config and ix.config.Get("walkSpeed")) or 100
        ply:SetWalkSpeed(baseWalk)
    end,
})

-- Multiplier applied to the base jump power from config.
REG("speed.jump", {
    name     = "Jump Power",
    baseValue = 1,
    min       = 0,
    modTypes  = {MULT, ADD, SET},
    apply = function(ply, value)
        local baseJump = (ix.config and ix.config.Get("jumpPower")) or 200
        ply:SetJumpPower(math.max(0, baseJump * value))
    end,
    unapply = function(ply)
        local baseJump = (ix.config and ix.config.Get("jumpPower")) or 200
        ply:SetJumpPower(baseJump)
    end,
})

-- Stun / root.  Any positive accumulated value freezes the player.
REG("speed.move_delay", {
    name     = "Movement Delay",
    baseValue = 0,
    min       = 0,
    calcOrder = "add_first",
    modTypes  = {ADD, SET},
    apply = function(ply, value)
        if value > 0 then
            ply:SetMoveType(MOVETYPE_NONE)
        else
            ply:SetMoveType(MOVETYPE_WALK)
        end
    end,
    unapply = function(ply)
        ply:SetMoveType(MOVETYPE_WALK)
    end,
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- Combat
-- ═══════════════════════════════════════════════════════════════════════════════

-- Incoming damage multiplier – applied through EntityTakeDamage hook.
REG("damage.taken", {
    name     = "Damage Taken",
    baseValue = 1,
    min       = 0,
    modTypes  = {MULT, ADD, SET},
})

-- Outgoing damage multiplier – applied through EntityTakeDamage hook.
REG("damage.dealt", {
    name     = "Damage Dealt",
    baseValue = 1,
    min       = 0,
    modTypes  = {MULT, ADD, SET},
})

-- Scales armor effectiveness.
REG("damage.armor_mult", {
    name     = "Armor Effectiveness",
    baseValue = 1,
    min       = 0,
    modTypes  = {MULT, ADD},
})

-- Flat armor value applied via SetArmor.
REG("armor.base", {
    name     = "Base Armor",
    baseValue = 0,
    min       = 0,
    max       = 255,
    calcOrder = "add_first",
    modTypes  = {ADD, SET},
    apply = function(ply, value)
        ply:SetArmor(math.floor(value))
    end,
    unapply = function(ply)
        ply:SetArmor(0)
    end,
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- Vitals & Regeneration
-- ═══════════════════════════════════════════════════════════════════════════════

-- Additive HP-per-second.  MULT scales the accumulated total.
REG("health.regen_rate", {
    name      = "Health Regeneration",
    baseValue = 0,
    calcOrder = "add_first",
    modTypes  = {ADD, MULT, SET},
})

-- Multiplier applied to stamina drain per tick.
REG("stamina.drain", {
    name     = "Stamina Drain Rate",
    baseValue = 1,
    min       = 0,
    modTypes  = {MULT, ADD},
})

-- Multiplier applied to stamina recovery per tick.
REG("stamina.regen", {
    name     = "Stamina Regen Rate",
    baseValue = 1,
    min       = 0,
    modTypes  = {MULT, ADD},
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- Visual & Rendering
-- ═══════════════════════════════════════════════════════════════════════════════

-- RGBA colour overlay rendered client-side.  Multiple tints are drawn individually.
-- GetEffectValue returns the highest-priority single tint for convenience.
REG("visual.color_tint", {
    name     = "Color Tint",
    baseValue = nil,
    modTypes  = {SET},
    calculate = function(modifiers, baseValue, _typeDef)
        if not modifiers or table.IsEmpty(modifiers) then return nil end
        local best, bestPriority = nil, -math.huge
        for _, mod in pairs(modifiers) do
            if (mod.priority or 0) > bestPriority then
                bestPriority = mod.priority or 0
                best = mod.value
            end
        end
        return best
    end,
})

-- Screen blur amount [0-1].  Rendered client-side with DrawMotionBlur.
REG("visual.blur", {
    name     = "Screen Blur",
    baseValue = 0,
    min       = 0,
    max       = 1,
    calcOrder = "add_first",
    modTypes  = {ADD, SET},
})

-- Model scale multiplier applied via SetModelScale (engine-networked).
REG("visual.scale", {
    name     = "Model Scale",
    baseValue = 1,
    min       = 0.1,
    max       = 10,
    modTypes  = {MULT, SET},
    apply = function(ply, value)
        ply:SetModelScale(value)
    end,
    unapply = function(ply)
        ply:SetModelScale(1)
    end,
})

-- Transparency [0-1].  1 = fully opaque.
REG("visual.alpha", {
    name     = "Transparency",
    baseValue = 1,
    min       = 0,
    max       = 1,
    modTypes  = {MULT, SET},
    apply = function(ply, value)
        if value < 1 then
            ply:SetRenderMode(RENDERMODE_TRANSALPHA)
            ply:SetColor(ColorAlpha(ply:GetColor(), math.floor(value * 255)))
        else
            ply:SetRenderMode(RENDERMODE_NORMAL)
            ply:SetColor(ColorAlpha(ply:GetColor(), 255))
        end
    end,
    unapply = function(ply)
        ply:SetRenderMode(RENDERMODE_NORMAL)
        ply:SetColor(ColorAlpha(ply:GetColor(), 255))
    end,
})

-- Glow colour/intensity (SET, table {r,g,b,size}).  Rendering is game-specific.
REG("visual.glow", {
    name     = "Glow Effect",
    baseValue = nil,
    modTypes  = {SET},
    calculate = function(modifiers, baseValue, _typeDef)
        if not modifiers or table.IsEmpty(modifiers) then return nil end
        local best, bestPriority = nil, -math.huge
        for _, mod in pairs(modifiers) do
            if (mod.priority or 0) > bestPriority then
                bestPriority = mod.priority or 0
                best = mod.value
            end
        end
        return best
    end,
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- Audio
-- ═══════════════════════════════════════════════════════════════════════════════

-- Hearing distance multiplier [0-1].  Game-specific sound hooks should query this.
REG("audio.muffled", {
    name     = "Muffled Hearing",
    baseValue = 1,
    min       = 0,
    max       = 1,
    modTypes  = {MULT, SET},
})

-- Boolean-like: any accumulated value > 0 means the player is muted.
REG("audio.mute", {
    name      = "Muted",
    baseValue = 0,
    min       = 0,
    calcOrder = "add_first",
    modTypes  = {ADD, SET},
})
