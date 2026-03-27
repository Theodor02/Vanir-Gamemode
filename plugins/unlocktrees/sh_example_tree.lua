-- sh_example_tree.lua
-- Sample usage: A three-node research tree demonstrating the unlock tree framework.
-- Drop this file into another plugin and include it, or paste the contents into sh_plugin.lua.
--
-- This file can be safely deleted. It exists only as a reference.

-- ─────────────────────────────────────────────
-- 0. Register custom resource providers (optional)
-- ─────────────────────────────────────────────

-- Register "xp" as a resource so nodes can cost XP.
-- Any key used in cost.resources can have a provider.
-- Without a provider, the system falls back to character:GetData("resource_<key>").
ix.unlocks.RegisterResource("xp", {
	name = "XP",
	Get = function(client, character)
		return character:GetAttribute("xp", 0)
	end,
	Deduct = function(client, character, amount)
		local current = character:GetAttribute("xp", 0)
		character:SetAttribute("xp", math.max(0, current - amount))
	end,
	Refund = function(client, character, amount)
		local current = character:GetAttribute("xp", 0)
		character:SetAttribute("xp", current + amount)
	end,
	Format = function(amount)
		return amount .. " XP"
	end
})

-- ─────────────────────────────────────────────
-- 1. Register the tree
-- ─────────────────────────────────────────────

ix.unlocks.RegisterTree("example_research", {
	name = "Research",
	description = "A basic research tree demonstrating the unlock framework.",
	metadata = {category = "example"},
	restrictions = {}, -- no restrictions, available to everyone
	showInTabMenu = true,
	allowRespec = true,
	refundRatio = 0.75,  -- 75% back when refunding individual nodes
    respecRatio = 0.5,   -- 50% back when doing a full tree respec (respec cost is based on this ratio, not refundRatio)
})

-- ─────────────────────────────────────────────
-- 2. Register nodes
-- ─────────────────────────────────────────────

ix.unlocks.RegisterNode("example_research", "basic_tools", {
	name = "Basic Tools",
	description = "Unlock access to basic crafting tools.",
	icon = "icon16/wrench.png",
	position = {x = 0, y = 0},
	cost = {money = 100},
	type = "normal"
})

ix.unlocks.RegisterNode("example_research", "advanced_materials", {
	name = "Advanced Materials",
	description = "Research improved material processing techniques.",
	icon = "icon16/bricks.png",
	position = {x = -80, y = 120},
	cost = {money = 250},
	type = "normal"
})

ix.unlocks.RegisterNode("example_research", "prototype_weapon", {
	name = "Prototype Weapon",
	description = "Develop an experimental weapon prototype.",
	icon = "icon16/bomb.png",
	position = {x = 80, y = 120},
	cost = {money = 500},
	requirements = {
		stats = {str = 3} -- requires 3 points in the "str" attribute
	},
	mutuallyExclusive = {} -- could exclude other branches
})

-- ─────────────────────────────────────────────
-- 3. Connect nodes (prerequisite edges)
-- ─────────────────────────────────────────────

-- basic_tools must be unlocked before either branch
ix.unlocks.ConnectNodes("example_research", "basic_tools", "advanced_materials")
ix.unlocks.ConnectNodes("example_research", "basic_tools", "prototype_weapon")

-- ─────────────────────────────────────────────
-- 4. Optional: attach behaviour via onUnlocked callback
-- ─────────────────────────────────────────────

-- You can also set callbacks after registration:
local protoNode = ix.unlocks.GetNode("example_research", "prototype_weapon")

if (protoNode) then
	protoNode.onUnlocked = function(client, character, treeID, nodeID, level)
		if (SERVER) then
			client:ChatPrint("You have unlocked the Prototype Weapon!")
		end
	end
end

-- ─────────────────────────────────────────────
-- 5. Repeatable node example
-- ─────────────────────────────────────────────

ix.unlocks.RegisterNode("example_research", "efficiency_upgrade", {
	name = "Efficiency",
	description = "Each level improves crafting speed by 5%.",
	icon = "icon16/arrow_up.png",
	position = {x = 0, y = 240},
	cost = {money = 150},
	repeatable = true,
	maxLevel = 5,
	onUnlocked = function(client, character, treeID, nodeID, level)
		if (SERVER) then
			client:ChatPrint("Efficiency upgraded to level " .. level .. "!")
		end
	end
})

ix.unlocks.ConnectNodes("example_research", "advanced_materials", "efficiency_upgrade")

-- ─────────────────────────────────────────────
-- 6. Dynamic cost example (scales with level)
-- ─────────────────────────────────────────────

ix.unlocks.RegisterNode("example_research", "material_mastery", {
	name = "Material Mastery",
	description = "Each level reduces material waste. Cost increases per level.",
	icon = "icon16/chart_bar.png",
	position = {x = -80, y = 360},
	cost = {
		-- Dynamic money cost: 200 base, +100 per level
		money = function(client, character, currentLevel)
			return 200 + (currentLevel * 100)
		end
	},
	repeatable = true,
	maxLevel = 3,
	category = "Materials"
})

ix.unlocks.ConnectNodes("example_research", "efficiency_upgrade", "material_mastery")

-- ─────────────────────────────────────────────
-- 7. Cooldown example
-- ─────────────────────────────────────────────

ix.unlocks.RegisterNode("example_research", "field_test", {
	name = "Field Test",
	description = "Run a field test to improve combat readiness. 60-second cooldown between levels.",
	icon = "icon16/shield.png",
	position = {x = 80, y = 240},
	cost = {money = 300},
	repeatable = true,
	maxLevel = 3,
	cooldown = 60, -- seconds between unlocks
	category = "Combat"
})

ix.unlocks.ConnectNodes("example_research", "prototype_weapon", "field_test")

-- ─────────────────────────────────────────────
-- 8. Hidden node example (invisible until prerequisite met)
-- ─────────────────────────────────────────────

ix.unlocks.RegisterNode("example_research", "secret_project", {
	name = "Secret Project",
	description = "A classified project revealed only after achieving Material Mastery.",
	icon = "icon16/lock.png",
	position = {x = -80, y = 480},
	cost = {money = 1000, resources = {xp = 100}},
	category = "Secret",
	-- Hidden nodes are invisible in the tree UI until the condition returns true.
	-- Any node that has a hidden node as a prerequisite is also hidden.
	-- hidden receives (client, character, unlockData) where unlockData uses localData on client
	hidden = function(client, character, unlockData)
		local trees = unlockData or character:GetUnlockData()
		local mastery = trees["example_research"] and trees["example_research"]["material_mastery"]
		local level = istable(mastery) and (mastery.level or 0) or (mastery or 0)
		return level >= 2 -- reveal after Material Mastery level 2
	end
})

ix.unlocks.ConnectNodes("example_research", "material_mastery", "secret_project")

-- A node depending on a hidden node inherits hidden behaviour automatically.
ix.unlocks.RegisterNode("example_research", "black_ops", {
	name = "Black Ops",
	description = "Unlocked after the Secret Project. Also hidden until Secret Project is visible.",
	icon = "icon16/eye.png",
	position = {x = -80, y = 600},
	cost = {money = 2000},
	category = "Secret"
})

ix.unlocks.ConnectNodes("example_research", "secret_project", "black_ops")

-- ─────────────────────────────────────────────
-- 9. onRefunded callback example
-- ─────────────────────────────────────────────

ix.unlocks.RegisterNode("example_research", "combat_training", {
	name = "Combat Training",
	description = "Grants a combat bonus. Removed on refund.",
	icon = "icon16/sport_8ball.png",
	position = {x = 160, y = 360},
	cost = {money = 400},
	category = "Combat",
	onUnlocked = function(client, character, treeID, nodeID, level)
		if (SERVER) then
			client:ChatPrint("Combat Training activated!")
		end
	end,
	onRefunded = function(client, character, treeID, nodeID, oldLevel, newLevel)
		if (SERVER) then
			client:ChatPrint("Combat Training revoked (was level " .. oldLevel .. ").")
		end
	end
})

ix.unlocks.ConnectNodes("example_research", "field_test", "combat_training")

-- ─────────────────────────────────────────────
-- 10. Mutual exclusivity example (branching paths)
-- ─────────────────────────────────────────────

-- Two specialisations branch from combat_training — only one can be chosen.
ix.unlocks.RegisterNode("example_research", "offensive_spec", {
	name = "Offensive Spec",
	description = "Specialise in offence. Cannot be combined with Defensive Spec.",
	icon = "icon16/lightning.png",
	position = {x = 100, y = 480},
	cost = {money = 600},
	category = "Combat"
})

ix.unlocks.RegisterNode("example_research", "defensive_spec", {
	name = "Defensive Spec",
	description = "Specialise in defence. Cannot be combined with Offensive Spec.",
	icon = "icon16/shield.png",
	position = {x = 220, y = 480},
	cost = {money = 600},
	category = "Combat"
})

ix.unlocks.ConnectNodes("example_research", "combat_training", "offensive_spec")
ix.unlocks.ConnectNodes("example_research", "combat_training", "defensive_spec")

-- Mark as mutually exclusive (bidirectional — both nodes get the constraint)
ix.unlocks.SetExclusive("example_research", "offensive_spec", "defensive_spec")

-- ─────────────────────────────────────────────
-- 11. Non-refundable node example
-- ─────────────────────────────────────────────

ix.unlocks.RegisterNode("example_research", "permanent_augment", {
	name = "Permanent Augment",
	description = "A permanent enhancement that cannot be refunded.",
	icon = "icon16/star.png",
	position = {x = 0, y = 360},
	cost = {money = 500},
	refundable = false, -- this node can never be refunded
	category = "Permanent"
})

ix.unlocks.ConnectNodes("example_research", "efficiency_upgrade", "permanent_augment")
