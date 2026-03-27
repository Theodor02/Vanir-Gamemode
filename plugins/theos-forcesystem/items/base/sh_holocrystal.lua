-- Holocron Item Base for The Force Plugin

ITEM.name                 = "Force Sensitive Item"
ITEM.description          = "A mysterious item that reacts to one's connection with the Force."
ITEM.model                = "models/props_c17/FurnitureWashingmachine001a.mdl"
ITEM.category             = "Holocrons"

-- Force-related properties
ITEM.forceLearn           = 20     -- Required 'force' attribute level to learn
ITEM.forceAbility         = "Default" -- Power learned

-- Descriptions based on state
ITEM.descriptionCanLearn  = "This item pulses with a mysterious energy. You feel that you can learn something from it."
ITEM.descriptionInert     = "This item is inert. It does not react to your touch."

-- State key
local DATA_INERT          = "inertstate"

-- Eldritch whispers for ambience
local ELDTRITCH_WHISPERS  = {
    "A shadowy intuition weaves into your mind, whispering secrets.",
    -- ... other whispers ...
}

-- Visions during action
local VISION_MESSAGES     = {
    "You see a vast galaxy unfolding before you, stars swirling in an endless dance.",
    -- ... other visions ...
}

-- Action configurations
local ACTION_CONFIGS = {
    touch = {
        duration       = 5,
        chanceConfig   = "forceTouchChance",
        verb           = "touches",
        chatMessage    = "%s touches the %s.",
        attribGain     = 1
    },
    learn = {
        duration       = 10,
        chanceConfig   = "forceLearnChance",
        verb           = "studies and learns from",
        chatMessage    = "%s studies and learns from the %s.",
        attribGain     = 0, -- handled in onSuccess
        onSuccess      = function(item, client)
            if not client:GetCharacter() then return end

            -- Grant via central Force API (persists + syncs to LSCS)
            -- (depends on: ix.force from sh_plugin.lua)
            local granted = ix.force.Grant(client, item.forceAbility, true)
            if granted then
                client:Notify("You have successfully learned " .. item.forceAbility .. ".")
            else
                client:Notify("You already know this power.")
            end
        end
    }
}

-- Track last messages to prevent repeats
local lastMessageByPlayer = {}

-- Utility: pick non-repeating random message
local function pickMessage(list, key)
    local last = lastMessageByPlayer[key]
    local choice, attempts = nil, 0
    repeat
        choice = list[math.random(#list)]
        attempts = attempts + 1
    until choice ~= last or attempts >= 5
    lastMessageByPlayer[key] = choice
    return choice
end

-- Central cleanup for an action
local function cleanupActionHooks(idPrefix)
    timer.Remove(idPrefix .. "_Main")
    timer.Remove(idPrefix .. "_Visions")
    hook.Remove("KeyPress", idPrefix .. "_Cancel")
    hook.Remove("PlayerDeath", idPrefix .. "_Death")
end

-- Shared action handler
local function handleForceAction(item, client, actionType)
    if not IsValid(client) then return false end
    local char = client:GetCharacter()
    if not char then return false end

    local cfg      = ACTION_CONFIGS[actionType]
    local steamKey = client:SteamID()
    local idPrefix = actionType .. "Action_" .. steamKey

    -- Prevent double actions
    cleanupActionHooks(idPrefix)

    -- Start action
    client:SetAction(cfg.verb .. " the " .. item.name .. "...", cfg.duration)
    client:SetRestricted(true)

    -- Main completion timer
    timer.Create(idPrefix .. "_Main", cfg.duration, 1, function()
        if not IsValid(client) then return end
        client:SetRestricted(false)
        client:SetAction()

        -- Chance to gain Force attribute
        local baseChance  = ix.config.Get(cfg.chanceConfig, 1)
        local wisdomMod   = ix.config.Get("wisdomEffect", 1)
        local totalChance = math.min(baseChance * (1 + char:GetAttribute("wisdom", 0) * (wisdomMod / 100)), 100)
        if math.random(100) <= totalChance and cfg.attribGain > 0 then
            char:UpdateAttrib("force", cfg.attribGain)
            client:Notify("You feel a surge of energy flowing through you.")
        end

        -- Learn-specific logic
        if cfg.onSuccess then
            cfg.onSuccess(item, client)
        end

        -- Final messages
        client:Notify(pickMessage(ELDTRITCH_WHISPERS, steamKey))

        -- Mark inert and cleanup
        item:SetData(DATA_INERT, true)
        cleanupActionHooks(idPrefix)
    end)

    -- Periodic vision timer
    local visInterval = 2
    local visCount    = math.floor(cfg.duration / visInterval)
    timer.Create(idPrefix .. "_Visions", visInterval, visCount, function()
        if IsValid(client) then
            client:Notify(pickMessage(VISION_MESSAGES, steamKey))
        end
    end)

    -- Cancel on movement
    hook.Add("KeyPress", idPrefix .. "_Cancel", function(ply, key)
        if ply == client and (key == IN_FORWARD or key == IN_BACK or key == IN_MOVELEFT or key == IN_MOVERIGHT or key == IN_JUMP) then
            client:SetRestricted(false)
            client:SetAction()
            client:Notify("Action interrupted.")
            cleanupActionHooks(idPrefix)
        end
    end)

    -- Cancel on death
    hook.Add("PlayerDeath", idPrefix .. "_Death", function(ply)
        if ply == client then
            client:SetRestricted(false)
            client:SetAction()
            client:Notify("You died and the action was canceled.")
            cleanupActionHooks(idPrefix)
        end
    end)

    return false
end

-- Dynamic description override
function ITEM:GetDescription(viewer)
    local desc   = self.description
    local player = viewer or LocalPlayer()
    local char   = player:GetCharacter()
    if not char then return desc end

    -- (depends on: ix.force from sh_plugin.lua)
    local hasPower = ix.force and ix.force.HasPower(player, self.forceAbility)
    local isInert   = self:GetData(DATA_INERT, false)

    if isInert then
        return self.descriptionInert
    elseif char:GetAttribute("force", 0) >= self.forceLearn and not hasPower then
        return self.descriptionCanLearn
    end
    return desc
end

-- Define item functions using shared handler
ITEM.functions.Touch = {
    name     = "Touch",
    icon     = "icon16/hand.png",
    OnRun    = function(item) return handleForceAction(item, item.player, "touch") end,
    OnCanRun = function(item)
        return not IsValid(item.entity)
           and not item:GetData(DATA_INERT, false)
    end
}

ITEM.functions.Learn = {
    name     = "Learn",
    icon     = "icon16/book_open.png",
    OnRun    = function(item) return handleForceAction(item, item.player, "learn") end,
    OnCanRun = function(item)
        local char = item.player:GetCharacter()
        return char
           and not IsValid(item.entity)
           and not item:GetData(DATA_INERT, false)
           and char:GetAttribute("force", 0) >= item.forceLearn
           and not (ix.force and ix.force.HasPower(item.player, item.forceAbility))
    end
}

-- Clean up on disconnect
hook.Add("PlayerDisconnected", "HolocronItemCleanup", function(ply)
    local sid = ply:SteamID()
    cleanupActionHooks("touchAction_" .. sid)
    cleanupActionHooks("learnAction_" .. sid)
    lastMessageByPlayer[sid] = nil
end)
