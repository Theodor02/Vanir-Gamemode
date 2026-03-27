--- Player Effects Registry – Core Plugin
-- Unified player stat modifier, buff/debuff, and status effect framework.
--
-- Multiple plugins can safely add/remove modifiers of the same type without
-- overwriting one another, and timed effects expire automatically.
--
-- Quick-start (server-side):
--   -- 50 % run-speed slow for 5 seconds
--   ply:AddEffect("speed.run", "my_stun", ix.playerEffects.MOD_MULT, 0.5, {duration = 5})
--
--   -- +10 % outgoing damage, permanent
--   ply:AddEffect("damage.dealt", "weapon_skill", ix.playerEffects.MOD_MULT, 1.1)
--
--   -- Remove a specific modifier
--   ply:RemoveEffect("speed.run", "my_stun")
--
--   -- Query from anywhere (shared)
--   local mult = ply:GetEffectValue("damage.dealt")  -- returns current combined value
-- @module player_effects

local PLUGIN = PLUGIN
PLUGIN.name        = "Player Effects Registry"
PLUGIN.author      = "Vanir"
PLUGIN.description = "Unified player stat modifier, buff/debuff, and status effect framework."

-- ═══════════════════════════════════════════════════════════════════════════════
-- Shared: Namespace & Constants
-- ═══════════════════════════════════════════════════════════════════════════════

ix.playerEffects            = ix.playerEffects or {}
ix.playerEffects.types      = ix.playerEffects.types or {}
ix.playerEffects.exclusions = ix.playerEffects.exclusions or {}

--- Modifier type constants.
-- MULT: value = base * modifier   (e.g. 0.9 = -10 %)
-- ADD:  value = base + modifier   (e.g. -20  = minus 20 flat)
-- SET:  value = modifier          (direct override; highest priority wins)
ix.playerEffects.MOD_MULT = 1
ix.playerEffects.MOD_ADD  = 2
ix.playerEffects.MOD_SET  = 3

--- Convenience alias on the PLUGIN table so other plugins can use
--- ix.plugin.list.player_effects.ModifierTypes.MULT
PLUGIN.ModifierTypes = {
    MULT = ix.playerEffects.MOD_MULT,
    ADD  = ix.playerEffects.MOD_ADD,
    SET  = ix.playerEffects.MOD_SET,
}

--- Layer processing order (lower index = applied earlier).
ix.playerEffects.LAYERS = {"base", "equipment", "default", "buff", "debuff", "temporary", "override"}
ix.playerEffects.LAYER_ORDER = {}
for i, v in ipairs(ix.playerEffects.LAYERS) do
    ix.playerEffects.LAYER_ORDER[v] = i
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Include sub-files (API helpers + built-in effect definitions)
-- ═══════════════════════════════════════════════════════════════════════════════

ix.util.Include("sh_api.lua")
ix.util.Include("sh_effect_types.lua")

-- ═══════════════════════════════════════════════════════════════════════════════
-- Shared: Calculation Engine
-- ═══════════════════════════════════════════════════════════════════════════════

local PE       = ix.playerEffects
local MOD_MULT = PE.MOD_MULT
local MOD_ADD  = PE.MOD_ADD
local MOD_SET  = PE.MOD_SET

--- Calculate the final value for an effect type from its active modifiers.
-- @param modifiers table {id = {modType, value, priority, layer, ...}}
-- @param typeDef   table The registered effect-type definition
-- @return any Calculated value
function ix.playerEffects.Calculate(modifiers, typeDef)
    if not modifiers or table.IsEmpty(modifiers) then
        return typeDef and typeDef.baseValue or 0
    end

    -- Custom override
    if typeDef and typeDef.calculate then
        return typeDef.calculate(modifiers, typeDef.baseValue, typeDef)
    end

    -- Collect into a sortable sequence
    local sorted = {}
    for _, mod in pairs(modifiers) do
        sorted[#sorted + 1] = mod
    end

    -- Sort by layer → priority
    table.sort(sorted, function(a, b)
        local la = PE.LAYER_ORDER[a.layer] or 50
        local lb = PE.LAYER_ORDER[b.layer] or 50
        if la ~= lb then return la < lb end
        return (a.priority or 0) < (b.priority or 0)
    end)

    local value = typeDef and typeDef.baseValue or 0

    -- Pass 1 — SET (highest priority SET wins)
    local bestSetPriority = -math.huge
    for _, mod in ipairs(sorted) do
        if mod.modType == MOD_SET then
            local p = mod.priority or 0
            if p > bestSetPriority then
                bestSetPriority = p
                value = mod.value
            end
        end
    end

    local addFirst = typeDef and typeDef.calcOrder == "add_first"

    if addFirst then
        -- Pass 2a — ADD then MULT
        for _, mod in ipairs(sorted) do
            if mod.modType == MOD_ADD then value = value + mod.value end
        end
        for _, mod in ipairs(sorted) do
            if mod.modType == MOD_MULT then value = value * mod.value end
        end
    else
        -- Pass 2b — MULT then ADD (default: prevents percentage-stacking issues)
        for _, mod in ipairs(sorted) do
            if mod.modType == MOD_MULT then value = value * mod.value end
        end
        for _, mod in ipairs(sorted) do
            if mod.modType == MOD_ADD then value = value + mod.value end
        end
    end

    -- Clamp
    if typeDef then
        if typeDef.min ~= nil and isnumber(value) then value = math.max(value, typeDef.min) end
        if typeDef.max ~= nil and isnumber(value) then value = math.min(value, typeDef.max) end
    end

    return value
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Shared: Player Meta – Query Functions
-- ═══════════════════════════════════════════════════════════════════════════════

local playerMeta = FindMetaTable("Player")

--- Check whether a specific modifier exists on this player.
-- @param effectType string e.g. "speed.run"
-- @param identifier string e.g. "bactaSpeed"
-- @return bool
function playerMeta:HasEffect(effectType, identifier)
    if not self.ixEffects or not self.ixEffects[effectType] then return false end
    return self.ixEffects[effectType].modifiers[identifier] ~= nil
end

--- Get the final calculated value for an effect type (lazy-cached).
-- @param effectType string
-- @return any The calculated value, or the base value when no modifiers exist
function playerMeta:GetEffectValue(effectType)
    if not self.ixEffects or not self.ixEffects[effectType] then
        local typeDef = PE.types[effectType]
        return typeDef and typeDef.baseValue
    end

    local data = self.ixEffects[effectType]
    if data.dirty or data.cached == nil then
        local typeDef = PE.types[effectType]
        data.cached = PE.Calculate(data.modifiers, typeDef)
        data.dirty = false
    end
    return data.cached
end

--- Get all modifiers for an effect type.
-- @param effectType string
-- @return table {[identifier] = modifierData, ...}
function playerMeta:GetEffects(effectType)
    if not self.ixEffects or not self.ixEffects[effectType] then return {} end
    return self.ixEffects[effectType].modifiers
end

--- Get the raw data table for a single modifier.
-- @param effectType string
-- @param identifier string
-- @return table? {modType, value, priority, layer, startTime, duration, metadata, ...}
function playerMeta:GetEffectInfo(effectType, identifier)
    if not self.ixEffects or not self.ixEffects[effectType] then return nil end
    return self.ixEffects[effectType].modifiers[identifier]
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Server-Only Logic
-- ═══════════════════════════════════════════════════════════════════════════════

if SERVER then

util.AddNetworkString("ixPE.Sync")

-- ─────────────────────────────────────────────
-- Internal helpers (local to SERVER block)
-- ─────────────────────────────────────────────

--- Build a unique timer identifier for a modifier.
local function TimerID(ply, effectType, identifier)
    return "ixPE_" .. ply:EntIndex() .. "_" .. effectType .. "_" .. identifier
end

--- Create a timer that removes a modifier after its duration.
local function SetupEffectTimer(ply, effectType, identifier, duration)
    timer.Create(TimerID(ply, effectType, identifier), duration, 1, function()
        if not IsValid(ply) then return end
        ply:RemoveEffect(effectType, identifier)
        hook.Run("PlayerEffectExpired", ply, effectType, identifier)
    end)
end

--- Remove an existing effect timer.
local function RemoveEffectTimer(ply, effectType, identifier)
    local id = TimerID(ply, effectType, identifier)
    if timer.Exists(id) then timer.Remove(id) end
end

--- Compress and send the full modifier set for one effect type to the owning client.
local function SyncEffect(ply, effectType)
    if not IsValid(ply) then return end

    local syncData = {}
    local data = ply.ixEffects and ply.ixEffects[effectType]
    if data and data.modifiers then
        for id, mod in pairs(data.modifiers) do
            syncData[id] = {
                modType   = mod.modType,
                value     = mod.value,
                priority  = mod.priority,
                layer     = mod.layer,
                startTime = mod.startTime,
                duration  = mod.duration,
                metadata  = mod.metadata,
            }
        end
    end

    local json = util.TableToJSON(syncData)
    local compressed = util.Compress(json)
    if not compressed then return end

    net.Start("ixPE.Sync")
        net.WriteString(effectType)
        net.WriteUInt(#compressed, 16)
        net.WriteData(compressed, #compressed)
    net.Send(ply)
end

--- Pending syncs batched until end-of-frame to coalesce rapid add/remove churn.
local pendingSyncs = {}
local syncTimerActive = false

local function FlushPendingSyncs()
    local batch = pendingSyncs
    pendingSyncs = {}
    syncTimerActive = false

    for ply, types in pairs(batch) do
        if IsValid(ply) then
            for effectType in pairs(types) do
                SyncEffect(ply, effectType)
            end
        end
    end
end

--- Queue an effect sync to be sent at end-of-frame, coalescing duplicates.
local function QueueSync(ply, effectType)
    if not IsValid(ply) then return end

    pendingSyncs[ply] = pendingSyncs[ply] or {}
    pendingSyncs[ply][effectType] = true

    if not syncTimerActive then
        syncTimerActive = true
        timer.Simple(0, FlushPendingSyncs)
    end
end

--- Invoke the effect type's apply/unapply callback with the current value.
local function ApplyEffectValue(ply, effectType)
    local typeDef = PE.types[effectType]
    if not typeDef then return end

    local data = ply.ixEffects and ply.ixEffects[effectType]
    local hasModifiers = data and data.modifiers and not table.IsEmpty(data.modifiers)

    if hasModifiers then
        local value = ply:GetEffectValue(effectType)
        if typeDef.apply then typeDef.apply(ply, value) end
    else
        if typeDef.unapply then typeDef.unapply(ply) end
    end
end

-- ─────────────────────────────────────────────
-- Player Meta – Mutation Functions
-- ─────────────────────────────────────────────

--- Add or update a modifier on this player.
-- @param effectType string   Effect category key (e.g. "speed.run")
-- @param identifier string   Unique modifier name (e.g. "bactaSpeed")
-- @param modType    number   MOD_MULT, MOD_ADD, or MOD_SET
-- @param value      any      The modifier value
-- @param opts       table?   Optional settings:
--   duration         number?  Seconds until auto-removal (nil = permanent)
--   priority         number?  Higher values take precedence (default 0)
--   layer            string?  "base"/"equipment"/"default"/"buff"/"debuff"/"temporary"/"override" (default "default")
--   metadata         table?   Arbitrary data attached to the modifier
--   onRemoved        func?    function(ply) called when this modifier is removed
--   onTick           func?    function(ply, timeRemaining) called every tick while active
--   refreshBehavior  string?  "reset" (default), "extend", "stack_duration", "highest"
-- @return bool Whether the modifier was successfully added
function playerMeta:AddEffect(effectType, identifier, modType, value, opts)
    opts = opts or {}
    local typeDef = PE.types[effectType]

    -- Validate modifier type against the effect-type's allowed set
    if typeDef and typeDef.modTypes then
        local valid = false
        for _, mt in ipairs(typeDef.modTypes) do
            if mt == modType then valid = true break end
        end
        if not valid then
            ErrorNoHalt("[PlayerEffects] Invalid modifier type " .. tostring(modType) .. " for " .. effectType .. "\n")
            return false
        end
    end

    -- ── Mutual-exclusion check ──────────────────────────────────────────────
    if self.ixEffects and PE.exclusions[identifier] then
        local toRemove = {}
        local blocked  = false

        for existingType, existingData in pairs(self.ixEffects) do
            for existingID, existingMod in pairs(existingData.modifiers or {}) do
                local exclusive, resolution = PE.AreExclusive(identifier, existingID)
                if exclusive then
                    if resolution == "priority" then
                        if (opts.priority or 0) <= (existingMod.priority or 0) then
                            blocked = true
                            break
                        end
                        toRemove[#toRemove + 1] = {existingType, existingID}
                    elseif resolution == "first" then
                        blocked = true
                        break
                    elseif resolution == "last" then
                        toRemove[#toRemove + 1] = {existingType, existingID}
                    end
                end
            end
            if blocked then break end
        end

        if blocked then return false end
        for _, r in ipairs(toRemove) do self:RemoveEffect(r[1], r[2]) end
    end

    -- ── Initialise storage ──────────────────────────────────────────────────
    self.ixEffects = self.ixEffects or {}
    self.ixEffects[effectType] = self.ixEffects[effectType] or {modifiers = {}, dirty = true, cached = nil}

    local effectData = self.ixEffects[effectType]
    local existing   = effectData.modifiers[identifier]

    -- ── Refresh behaviour when same identifier already exists ────────────────
    if existing then
        local behavior = opts.refreshBehavior or existing.refreshBehavior or "reset"

        if behavior == "extend" and existing.duration and opts.duration then
            local remaining  = math.max(0, existing.duration - (CurTime() - existing.startTime))
            local newDuration = math.max(remaining, opts.duration)

            RemoveEffectTimer(self, effectType, identifier)
            existing.value     = value
            existing.modType   = modType
            existing.duration  = newDuration
            existing.startTime = CurTime()
            effectData.dirty   = true
            effectData.cached  = nil
            SetupEffectTimer(self, effectType, identifier, newDuration)
            ApplyEffectValue(self, effectType)
            QueueSync(self, effectType)
            hook.Run("PlayerEffectRefreshed", self, effectType, identifier, value)
            return true

        elseif behavior == "stack_duration" and existing.duration and opts.duration then
            local remaining  = math.max(0, existing.duration - (CurTime() - existing.startTime))
            local newDuration = remaining + opts.duration

            RemoveEffectTimer(self, effectType, identifier)
            existing.value     = value
            existing.modType   = modType
            existing.duration  = newDuration
            existing.startTime = CurTime()
            effectData.dirty   = true
            effectData.cached  = nil
            SetupEffectTimer(self, effectType, identifier, newDuration)
            ApplyEffectValue(self, effectType)
            QueueSync(self, effectType)
            hook.Run("PlayerEffectRefreshed", self, effectType, identifier, value)
            return true

        elseif behavior == "highest" then
            if isnumber(value) and isnumber(existing.value) then
                if math.abs(value) <= math.abs(existing.value) then
                    return false
                end
            end
            RemoveEffectTimer(self, effectType, identifier)

        else -- "reset" (default): cancel old timer, fall through to replace
            RemoveEffectTimer(self, effectType, identifier)
        end
    end

    -- ── Store the modifier ──────────────────────────────────────────────────
    effectData.modifiers[identifier] = {
        modType          = modType,
        value            = value,
        priority         = opts.priority or 0,
        layer            = opts.layer or "default",
        startTime        = CurTime(),
        duration         = opts.duration,
        metadata         = opts.metadata or {},
        onRemoved        = opts.onRemoved,
        onTick           = opts.onTick,
        refreshBehavior  = opts.refreshBehavior or "reset",
    }
    effectData.dirty  = true
    effectData.cached = nil

    -- Duration timer
    if opts.duration then
        SetupEffectTimer(self, effectType, identifier, opts.duration)
    end

    -- Recalculate, apply, sync
    ApplyEffectValue(self, effectType)
    QueueSync(self, effectType)

    hook.Run("PlayerEffectAdded", self, effectType, identifier, modType, value)
    return true
end

--- Remove a specific modifier from this player.
-- @param effectType string
-- @param identifier string
function playerMeta:RemoveEffect(effectType, identifier)
    if not self.ixEffects or not self.ixEffects[effectType] then return end

    local effectData = self.ixEffects[effectType]
    local mod = effectData.modifiers[identifier]
    if not mod then return end

    local oldValue  = mod.value
    local onRemoved = mod.onRemoved

    RemoveEffectTimer(self, effectType, identifier)
    effectData.modifiers[identifier] = nil
    effectData.dirty  = true
    effectData.cached = nil

    -- Clean up empty effect type
    if table.IsEmpty(effectData.modifiers) then
        self.ixEffects[effectType] = nil
    end

    ApplyEffectValue(self, effectType)
    QueueSync(self, effectType)

    hook.Run("PlayerEffectRemoved", self, effectType, identifier, oldValue)
    if isfunction(onRemoved) then onRemoved(self) end
end

--- Remove every modifier for a given effect type.
-- @param effectType string
function playerMeta:ClearEffects(effectType)
    if not self.ixEffects or not self.ixEffects[effectType] then return end

    local effectData = self.ixEffects[effectType]
    for id, mod in pairs(effectData.modifiers) do
        RemoveEffectTimer(self, effectType, id)
        hook.Run("PlayerEffectRemoved", self, effectType, id, mod.value)
        if isfunction(mod.onRemoved) then mod.onRemoved(self) end
    end

    self.ixEffects[effectType] = nil

    ApplyEffectValue(self, effectType)
    QueueSync(self, effectType)
end

--- Force recalculation and re-application of an effect type's value.
-- Useful after making several changes with a shared batch flag.
-- @param effectType string
function playerMeta:RefreshEffects(effectType)
    if not self.ixEffects or not self.ixEffects[effectType] then return end
    self.ixEffects[effectType].dirty  = true
    self.ixEffects[effectType].cached = nil
    ApplyEffectValue(self, effectType)
end

-- ─────────────────────────────────────────────
-- Global Tick Timer (0.5 s)
-- ─────────────────────────────────────────────

local TICK_INTERVAL = 0.5

timer.Create("ixPE.Tick", TICK_INTERVAL, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if not ply.ixEffects then continue end

        -- Per-modifier tick callbacks / hooks
        for effectType, effectData in pairs(ply.ixEffects) do
            for id, mod in pairs(effectData.modifiers) do
                if mod.duration then
                    local remaining = mod.duration - (CurTime() - mod.startTime)
                    hook.Run("PlayerEffectTick", ply, effectType, remaining)
                    if isfunction(mod.onTick) then mod.onTick(ply, remaining) end
                end
            end
        end

        -- Built-in: health regeneration
        if ply:Alive() then
            local regenRate = ply:GetEffectValue("health.regen_rate")
            ply.ixPEHealthCarry = ply.ixPEHealthCarry or 0

            if regenRate and regenRate ~= 0 then
                local rawDelta = (regenRate * TICK_INTERVAL) + ply.ixPEHealthCarry
                local wholeDelta

                if rawDelta >= 0 then
                    wholeDelta = math.floor(rawDelta)
                else
                    wholeDelta = math.ceil(rawDelta)
                end

                -- Carry fractional regeneration/drain across ticks so low rates still apply.
                ply.ixPEHealthCarry = rawDelta - wholeDelta

                if wholeDelta ~= 0 then
                    local oldHP = ply:Health()
                    local newHP = math.Clamp(oldHP + wholeDelta, 1, ply:GetMaxHealth())

                    if newHP ~= oldHP then
                        ply:SetHealth(newHP)
                    end

                    -- If clamped, clear carry in that direction to avoid hidden backlog.
                    if (newHP >= ply:GetMaxHealth() and regenRate > 0) or (newHP <= 1 and regenRate < 0) then
                        ply.ixPEHealthCarry = 0
                    end
                end
            else
                ply.ixPEHealthCarry = 0
            end
        end
    end
end)

-- ─────────────────────────────────────────────
-- Hooks: Damage
-- ─────────────────────────────────────────────

function PLUGIN:EntityTakeDamage(target, dmgInfo)
    if not target:IsPlayer() then return end

    -- Incoming damage modifier
    local takenMult = target:GetEffectValue("damage.taken")
    if takenMult and takenMult ~= 1 then
        dmgInfo:ScaleDamage(takenMult)
    end

    -- Outgoing damage modifier (attacker side)
    local attacker = dmgInfo:GetAttacker()
    if IsValid(attacker) and attacker:IsPlayer() then
        local dealtMult = attacker:GetEffectValue("damage.dealt")
        if dealtMult and dealtMult ~= 1 then
            dmgInfo:ScaleDamage(dealtMult)
        end
    end
end

-- ─────────────────────────────────────────────
-- Hooks: Lifecycle
-- ─────────────────────────────────────────────

--- Ensure storage exists and re-apply all effect types on spawn/respawn.
-- Restores engine state (speed, armor, movetype, model scale, etc.) that
-- gets reset by the engine on respawn.  Types without active modifiers get
-- their unapply callback called, which sets engine defaults (e.g. base speed).
function PLUGIN:PlayerLoadout(client)
    client.ixEffects = client.ixEffects or {}

    -- Re-apply every registered effect type to restore engine state.
    for effectType in pairs(PE.types) do
        ApplyEffectValue(client, effectType)
    end

    -- Re-sync all active effects to the client.
    for effectType, effectData in pairs(client.ixEffects) do
        if effectData.modifiers and not table.IsEmpty(effectData.modifiers) then
            QueueSync(client, effectType)
        end
    end
end

--- Full cleanup when a player disconnects.
function PLUGIN:PlayerDisconnected(client)
    -- Discard any pending syncs for this player.
    pendingSyncs[client] = nil

    if not client.ixEffects then return end
    for effectType, effectData in pairs(client.ixEffects) do
        for id in pairs(effectData.modifiers) do
            RemoveEffectTimer(client, effectType, id)
        end
    end
    client.ixEffects = nil
end

end -- SERVER

-- ═══════════════════════════════════════════════════════════════════════════════
-- Client-Only Logic
-- ═══════════════════════════════════════════════════════════════════════════════

if CLIENT then

--- Receive effect state from the server.
net.Receive("ixPE.Sync", function()
    local effectType = net.ReadString()
    local dataLen    = net.ReadUInt(16)
    local compressed = net.ReadData(dataLen)
    local json       = util.Decompress(compressed)
    if not json then return end
    local syncData   = util.JSONToTable(json)
    if not syncData then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    ply.ixEffects = ply.ixEffects or {}

    if table.IsEmpty(syncData) then
        ply.ixEffects[effectType] = nil
    else
        ply.ixEffects[effectType] = {
            modifiers = syncData,
            dirty     = true,
            cached    = nil,
        }
    end
end)

-- ─────────────────────────────────────────────
-- Visual: colour tint overlay
-- ─────────────────────────────────────────────

hook.Add("RenderScreenspaceEffects", "ixPE.ColorTint", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply.ixEffects then return end

    local tintData = ply.ixEffects["visual.color_tint"]
    if not tintData or not tintData.modifiers then return end

    for _, mod in pairs(tintData.modifiers) do
        if istable(mod.value) then
            local col = mod.value
            local af  = (col.a or 255) / 255
            DrawColorModify({
                ["$pp_colour_addr"]       = (col.r or 0) / 255 * af * 0.02,
                ["$pp_colour_addg"]       = (col.g or 0) / 255 * af * 0.02,
                ["$pp_colour_addb"]       = (col.b or 0) / 255 * af * 0.02,
                ["$pp_colour_brightness"] = 0,
                ["$pp_colour_contrast"]   = 1,
                ["$pp_colour_colour"]     = 1,
                ["$pp_colour_mulr"]       = 0,
                ["$pp_colour_mulg"]       = 0,
                ["$pp_colour_mulb"]       = 0,
            })
        end
    end
end)

-- ─────────────────────────────────────────────
-- Visual: screen blur
-- ─────────────────────────────────────────────

hook.Add("RenderScreenspaceEffects", "ixPE.Blur", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local blurVal = ply:GetEffectValue("visual.blur")
    if not blurVal or blurVal <= 0 then return end

    DrawMotionBlur(0.4, blurVal, 0.01)
end)

end -- CLIENT
