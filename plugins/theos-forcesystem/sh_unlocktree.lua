--- Force Power Unlock Tree
-- Registers a full force power / saber stance unlock tree using the
-- unlocktrees plugin. Each node grants or revokes an LSCS power via
-- ix.force.Grant() / ix.force.Revoke().
--
-- Registration is deferred to InitPostEntity because this plugin
-- loads before unlocktrees alphabetically (t < u).
--
-- (depends on: unlocktrees plugin, ix.force API from sh_plugin.lua)
-- @module theos-forcesystem.sh_unlocktree

hook.Add("InitPostEntity", "ixForceTree.Register", function()
    if not ix.unlocks then
        ErrorNoHalt("[theos-forcesystem] unlocktrees plugin not found — skipping tree registration.\n")
        return
    end

local TREE_ID = "force_powers"

-- ─────────────────────────────────────────────
-- Tree Registration
-- ─────────────────────────────────────────────

ix.unlocks.RegisterTree(TREE_ID, {
    name = "The Force",
    description = "Develop your connection to the Force, learning new abilities and combat forms.",
    showInTabMenu = true,
    allowRespec = true,
    refundable = true,
    refundRatio = 0.75,
    respecRatio = 0.5,
    restrictions = {
        condition = function(client, character)
            if (character:GetAttribute("force", 0) <= 0) then
                return false, "You are not Force sensitive."
            end
            return true
        end
    },
})

-- ─────────────────────────────────────────────
-- Helper — generate onUnlocked / onRefunded
-- that call ix.force.Grant / Revoke
-- ─────────────────────────────────────────────

local function makeForceCallbacks(lscsClass)
    return {
        onUnlocked = function(client, character, treeID, nodeID, level)
            if not SERVER then return end
            ix.force.Grant(client, lscsClass, true)
        end,
        onRefunded = function(client, character, treeID, nodeID, level)
            if not SERVER then return end
            ix.force.Revoke(client, lscsClass)
        end,
    }
end

-- ─────────────────────────────────────────────
-- Root Node
-- ─────────────────────────────────────────────

ix.unlocks.RegisterNode(TREE_ID, "force_attunement", {
    name = "Force Attunement",
    description = "Awaken your connection to the Force. Required before learning any abilities.",
    icon = "icon16/star.png",
    position = {x = 0, y = 0},
    cost = {money = 0},
    requirements = {
        stats = {force = 1},
    },
})

-- ─────────────────────────────────────────────
-- Tier 1 — Force Powers
-- ─────────────────────────────────────────────

local t1_force = {
    {id = "force_push",  class = "item_force_push",  name = "Force Push",  desc = "Push objects and enemies away.",              icon = "icon16/arrow_right.png",  pos = {x = -240, y = 120}},
    {id = "force_pull",  class = "item_force_pull",  name = "Force Pull",  desc = "Pull objects and enemies toward you.",        icon = "icon16/arrow_left.png",   pos = {x = -120, y = 120}},
    {id = "force_heal",  class = "item_force_heal",  name = "Force Heal",  desc = "Heal yourself using the Force.",              icon = "icon16/heart.png",        pos = {x = 0, y = 120}},
    {id = "force_jump",  class = "item_force_jump",  name = "Force Jump",  desc = "Leap great distances.",                       icon = "icon16/arrow_up.png",     pos = {x = 120, y = 120}},
    {id = "force_sense", class = "item_force_sense", name = "Force Sense", desc = "Heightened awareness of your surroundings.",  icon = "icon16/eye.png",          pos = {x = 240, y = 120}},
}

for _, p in ipairs(t1_force) do
    local cbs = makeForceCallbacks(p.class)
    ix.unlocks.RegisterNode(TREE_ID, p.id, {
        name = p.name,
        description = p.desc,
        icon = p.icon,
        position = p.pos,
        cost = {money = 500},
        category = "Force Powers",
        onUnlocked = cbs.onUnlocked,
        onRefunded = cbs.onRefunded,
    })
    ix.unlocks.ConnectNodes(TREE_ID, "force_attunement", p.id)
end

-- ─────────────────────────────────────────────
-- Tier 1 — Saber Stances
-- ─────────────────────────────────────────────

local t1_stance = {
    {id = "stance_aggressive", class = "item_stance_aggresive", name = "Aggressive Form", desc = "High damage, lower defense.",   icon = "icon16/sword.png",         pos = {x = -160, y = 280}},
    {id = "stance_agile",      class = "item_stance_agile",     name = "Agile Form",      desc = "Fast attacks, balanced defense.", icon = "icon16/lightning.png",     pos = {x = 0, y = 280}},
    {id = "stance_defensive",  class = "item_stance_defensive", name = "Defensive Form",  desc = "Strong blocks, lower damage.",  icon = "icon16/shield.png",        pos = {x = 160, y = 280}},
}

for _, s in ipairs(t1_stance) do
    local cbs = makeForceCallbacks(s.class)
    ix.unlocks.RegisterNode(TREE_ID, s.id, {
        name = s.name,
        description = s.desc,
        icon = s.icon,
        position = s.pos,
        cost = {money = 500},
        category = "Saber Forms",
        onUnlocked = cbs.onUnlocked,
        onRefunded = cbs.onRefunded,
    })
    ix.unlocks.ConnectNodes(TREE_ID, "force_attunement", s.id)
end

-- ─────────────────────────────────────────────
-- Tier 2 — Advanced Force Powers
-- ─────────────────────────────────────────────

local t2_force = {
    {id = "force_lightning", class = "item_force_lightning", name = "Force Lightning", desc = "Channel destructive lightning.",     icon = "icon16/weather_lightning.png", pos = {x = -240, y = 240}, parent = "force_push"},
    {id = "force_immunity",  class = "item_force_immunity",  name = "Force Immunity",  desc = "Resist Force-based attacks.",       icon = "icon16/weather_clouds.png",   pos = {x = 0, y = 240},   parent = "force_heal"},
    {id = "force_replenish", class = "item_force_replenish", name = "Force Replenish", desc = "Rapidly restore your Force pool.", icon = "icon16/arrow_refresh.png",    pos = {x = 240, y = 240},  parent = "force_sense"},
}

for _, p in ipairs(t2_force) do
    local cbs = makeForceCallbacks(p.class)
    ix.unlocks.RegisterNode(TREE_ID, p.id, {
        name = p.name,
        description = p.desc,
        icon = p.icon,
        position = p.pos,
        cost = {money = 1500},
        requirements = {
            stats = {force = 10},
        },
        category = "Force Powers",
        onUnlocked = cbs.onUnlocked,
        onRefunded = cbs.onRefunded,
    })
    ix.unlocks.ConnectNodes(TREE_ID, p.parent, p.id)
end

-- ─────────────────────────────────────────────
-- Tier 2 — Advanced Stances
-- ─────────────────────────────────────────────

local t2_stance = {
    {id = "stance_butterfly",  class = "item_stance_butterfly",  name = "Butterfly Form",  desc = "Acrobatic and risky.",          icon = "icon16/bug.png",       pos = {x = 0, y = 400},    parent = "stance_agile"},
    {id = "stance_dualwield",  class = "item_stance_dualwield",  name = "Dual Wield",      desc = "Two sabers at once.",           icon = "icon16/arrow_divide.png", pos = {x = -200, y = 400}, parent = "stance_aggressive"},
    {id = "stance_saberstaff", class = "item_stance_saberstaff", name = "Saberstaff Form", desc = "Double-bladed technique.",      icon = "icon16/arrow_switch.png", pos = {x = 200, y = 400},  parent = "stance_defensive"},
    {id = "stance_arrogant",   class = "item_stance_arrogant",   name = "Arrogant Form",   desc = "Intimidating and aggressive.",  icon = "icon16/exclamation.png",  pos = {x = -80, y = 400},  parent = "stance_aggressive"},
}

for _, s in ipairs(t2_stance) do
    local cbs = makeForceCallbacks(s.class)
    ix.unlocks.RegisterNode(TREE_ID, s.id, {
        name = s.name,
        description = s.desc,
        icon = s.icon,
        position = s.pos,
        cost = {money = 1500},
        requirements = {
            stats = {force = 10},
        },
        category = "Saber Forms",
        onUnlocked = cbs.onUnlocked,
        onRefunded = cbs.onRefunded,
    })
    ix.unlocks.ConnectNodes(TREE_ID, s.parent, s.id)
end

-- ─────────────────────────────────────────────
-- Tier 3 — Dual Saberstaff
-- ─────────────────────────────────────────────

local cbs = makeForceCallbacks("item_stance_saberstaffdual")
ix.unlocks.RegisterNode(TREE_ID, "stance_saberstaffdual", {
    name = "Dual Saberstaff",
    description = "Advanced double-blade technique. Requires mastery of the saberstaff.",
    icon = "icon16/arrow_rotate_clockwise.png",
    position = {x = 200, y = 520},
    cost = {money = 3000},
    requirements = {
        stats = {force = 25},
    },
    category = "Saber Forms",
    onUnlocked = cbs.onUnlocked,
    onRefunded = cbs.onRefunded,
})
ix.unlocks.ConnectNodes(TREE_ID, "stance_saberstaff", "stance_saberstaffdual")

end) -- InitPostEntity
