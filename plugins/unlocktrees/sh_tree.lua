-- sh_tree.lua
-- Tree-level utility functions: access checks and network serialisation.

--- Check if a player can access a specific tree based on its restrictions.
-- @param client Player
-- @param treeID string
-- @return bool, string
function ix.unlocks.CanAccessTree(client, treeID)
	local tree = ix.unlocks.trees[treeID]

	if (!tree) then
		return false, "Tree does not exist."
	end

	local restrictions = tree.restrictions

	if (!restrictions or table.IsEmpty(restrictions)) then
		return true
	end

	local character = client:GetCharacter()

	if (!character) then
		return false, "No character loaded."
	end

	-- Faction restriction
	if (restrictions.factions and #restrictions.factions > 0) then
		local faction = character:GetFaction()
		local allowed = false

		for _, factionID in ipairs(restrictions.factions) do
			if (faction == factionID) then
				allowed = true
				break
			end
		end

		if (!allowed) then
			return false, "Your faction cannot access this tree."
		end
	end

	-- Class restriction
	if (restrictions.classes and #restrictions.classes > 0) then
		local class = character:GetClass()
		local allowed = false

		for _, classID in ipairs(restrictions.classes) do
			if (class == classID) then
				allowed = true
				break
			end
		end

		if (!allowed) then
			return false, "Your class cannot access this tree."
		end
	end

	-- Custom condition
	if (restrictions.condition and isfunction(restrictions.condition)) then
		local result, reason = restrictions.condition(client, character)

		if (!result) then
			return false, reason or "You do not meet the requirements."
		end
	end

	return true
end

--- Strip callbacks and functions from a tree for safe JSON serialisation.
-- Used when exporting or networking tree definitions.
-- @param treeID string
-- @return table or nil
function ix.unlocks.GetTreeNetworkData(treeID)
	local tree = ix.unlocks.trees[treeID]

	if (!tree) then return nil end

	local data = {
		id = tree.id,
		name = tree.name,
		description = tree.description,
		nodes = {},
		edges = tree.edges,
		metadata = tree.metadata,
		restrictions = {},
		showInTabMenu = tree.showInTabMenu,
		allowRespec = tree.allowRespec,
		refundRatio = tree.refundRatio,
		respecRatio = tree.respecRatio
	}

	-- Copy restrictions without functions
	if (tree.restrictions) then
		data.restrictions.factions = tree.restrictions.factions
		data.restrictions.classes = tree.restrictions.classes
	end

	-- Copy nodes without function references
	for nodeID, node in pairs(tree.nodes) do
		data.nodes[nodeID] = {
			id = node.id,
			name = node.name,
			description = node.description,
			icon = node.icon,
			position = node.position,
			cost = {},
			requirements = {},
			type = node.type,
			repeatable = node.repeatable,
			maxLevel = node.maxLevel,
			metadata = node.metadata,
			mutuallyExclusive = node.mutuallyExclusive,
			category = node.category,
			hasHidden = node.hidden and true or false
		}

		-- Copy cost without functions
		if (node.cost) then
			if (node.cost.money) then
				data.nodes[nodeID].cost.money = node.cost.money
			end

			if (node.cost.resources) then
				data.nodes[nodeID].cost.resources = node.cost.resources
			end
		end

		-- Copy requirements without functions
		if (node.requirements) then
			if (node.requirements.stats) then
				data.nodes[nodeID].requirements.stats = node.requirements.stats
			end

			if (node.requirements.faction) then
				data.nodes[nodeID].requirements.faction = node.requirements.faction
			end

			if (node.requirements.class) then
				data.nodes[nodeID].requirements.class = node.requirements.class
			end
		end
	end

	return data
end

--- Get a list of trees accessible to a specific player.
-- @param client Player
-- @return table Array of tree IDs
function ix.unlocks.GetAccessibleTrees(client)
	local accessible = {}

	for treeID in pairs(ix.unlocks.trees) do
		local canAccess = ix.unlocks.CanAccessTree(client, treeID)

		if (canAccess) then
			accessible[#accessible + 1] = treeID
		end
	end

	return accessible
end

--- Get trees that should appear in the tab menu for a specific player.
-- Only returns trees with showInTabMenu = true that the player can access.
-- @param client Player
-- @return table Array of tree IDs
function ix.unlocks.GetTabMenuTrees(client)
	local result = {}

	for treeID, tree in pairs(ix.unlocks.trees) do
		if (tree.showInTabMenu) then
			local canAccess = ix.unlocks.CanAccessTree(client, treeID)

			if (canAccess) then
				result[#result + 1] = treeID
			end
		end
	end

	return result
end
