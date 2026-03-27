-- sh_node.lua
-- Node-level utility functions: prerequisite checks, cost validation, cost deduction/refund.

--- Resolve a cost value that may be a static number or a dynamic function.
-- Dynamic costs use the signature: function(client, character, level) -> number
-- where level is the NEXT level the player would reach.
-- @param value number|function
-- @param client Player
-- @param character table
-- @param treeID string
-- @param nodeID string
-- @return number
local function ResolveCost(value, client, character, treeID, nodeID)
	if (isfunction(value)) then
		local level = (character:GetNodeLevel(treeID, nodeID) or 0) + 1
		return value(client, character, level) or 0
	end

	return value or 0
end

--- Check if all prerequisites, exclusive locks, cooldowns, and requirements for a node are met.
-- @param client Player
-- @param treeID string
-- @param nodeID string
-- @return bool, string
function ix.unlocks.CheckPrerequisites(client, treeID, nodeID)
	local character = client:GetCharacter()

	if (!character) then
		return false, "No character loaded."
	end

	local node = ix.unlocks.GetNode(treeID, nodeID)

	if (!node) then
		return false, "Node does not exist."
	end

	-- Prerequisite edges
	local prereqs = ix.unlocks.GetPrerequisites(treeID, nodeID)

	for _, prereqID in ipairs(prereqs) do
		if (!character:HasUnlockedNode(treeID, prereqID)) then
			local prereqNode = ix.unlocks.GetNode(treeID, prereqID)
			return false, "Requires: " .. (prereqNode and prereqNode.name or prereqID)
		end
	end

	-- Mutual exclusion
	if (node.mutuallyExclusive and #node.mutuallyExclusive > 0) then
		for _, exclusiveID in ipairs(node.mutuallyExclusive) do
			if (character:HasUnlockedNode(treeID, exclusiveID)) then
				local exNode = ix.unlocks.GetNode(treeID, exclusiveID)
				return false, "Mutually exclusive with: " .. (exNode and exNode.name or exclusiveID)
			end
		end
	end

	-- Custom requirements table
	local requirements = node.requirements

	if (requirements) then
		-- Stat / attribute requirements
		if (requirements.stats) then
			for stat, value in pairs(requirements.stats) do
				local current = character:GetAttribute(stat, 0)

				if (current < value) then
					return false, "Requires " .. stat .. ": " .. value .. " (current: " .. current .. ")"
				end
			end
		end

		-- Faction requirement on the node itself
		if (requirements.faction) then
			if (character:GetFaction() != requirements.faction) then
				local factionTable = ix.faction.indices[requirements.faction]
				local factionName = factionTable and factionTable.name or tostring(requirements.faction)
				return false, "Requires faction: " .. factionName
			end
		end

		-- Class requirement on the node itself
		if (requirements.class) then
			if (character:GetClass() != requirements.class) then
				return false, "Requires class: " .. tostring(requirements.class)
			end
		end

		-- Arbitrary condition callback
		if (requirements.condition and isfunction(requirements.condition)) then
			local result, reason = requirements.condition(client, character, treeID, nodeID)

			if (!result) then
				return false, reason or "Custom requirement not met."
			end
		end
	end

	-- Level cap for repeatable nodes
	if (node.repeatable and node.maxLevel) then
		local currentLevel = character:GetNodeLevel(treeID, nodeID)

		if (currentLevel >= node.maxLevel) then
			return false, "Maximum level reached."
		end
	elseif (!node.repeatable) then
		if (character:HasUnlockedNode(treeID, nodeID)) then
			return false, "Already unlocked."
		end
	end

	-- Cooldown check
	if (requirements and requirements.cooldown) then
		local cd = requirements.cooldown
		local key = cd.key or (treeID .. "_" .. nodeID)
		local data = character:GetData("ixUnlockCooldowns", {})
		local lastTime = data[key]

		if (lastTime) then
			local remaining = (lastTime + (cd.duration or 0)) - os.time()

			if (remaining > 0) then
				local mins = math.ceil(remaining / 60)
				return false, "On cooldown: " .. mins .. " minute(s) remaining."
			end
		end
	end

	return true
end

--- Check if a player can afford the cost of a node.
-- @param client Player
-- @param treeID string
-- @param nodeID string
-- @return bool, string
function ix.unlocks.CheckCost(client, treeID, nodeID)
	local character = client:GetCharacter()

	if (!character) then
		return false, "No character loaded."
	end

	local node = ix.unlocks.GetNode(treeID, nodeID)

	if (!node) then
		return false, "Node does not exist."
	end

	local cost = node.cost

	if (!cost or table.IsEmpty(cost)) then
		return true
	end

	-- Money
	if (cost.money) then
		local amount = ResolveCost(cost.money, client, character, treeID, nodeID)

		if (amount > 0) then
			if (character.GetMoney and character:GetMoney() < amount) then
				return false, "Not enough money. Need: " .. ix.currency.Get(amount)
			end
		end
	end

	-- Named resources (registered providers or character data fallback)
	if (cost.resources) then
		for resource, rawAmount in pairs(cost.resources) do
			local amount = ResolveCost(rawAmount, client, character, treeID, nodeID)
			local provider = ix.unlocks.GetResourceProvider(resource)
			local current

			if (provider and provider.Get) then
				current = provider.Get(client, character)
			else
				current = character:GetData("resource_" .. resource, 0)
			end

			if (current < amount) then
				local displayName = provider and provider.name or resource
				return false, "Not enough " .. displayName .. ". Need: " .. amount .. " (have: " .. current .. ")"
			end
		end
	end

	-- Arbitrary condition callback
	if (cost.condition and isfunction(cost.condition)) then
		local result, reason = cost.condition(client, character, treeID, nodeID)

		if (!result) then
			return false, reason or "Cannot afford cost."
		end
	end

	return true
end

--- Deduct the cost of a node from a player. Server only.
function ix.unlocks.DeductCost(client, treeID, nodeID)
	if (CLIENT) then return false end

	local character = client:GetCharacter()

	if (!character) then return false end

	local node = ix.unlocks.GetNode(treeID, nodeID)

	if (!node) then return false end

	local cost = node.cost

	if (!cost or table.IsEmpty(cost)) then
		return true
	end

	if (cost.money and character.TakeMoney) then
		local amount = ResolveCost(cost.money, client, character, treeID, nodeID)

		if (amount > 0) then
			character:TakeMoney(amount)
		end
	end

	if (cost.resources) then
		for resource, rawAmount in pairs(cost.resources) do
			local amount = ResolveCost(rawAmount, client, character, treeID, nodeID)
			local provider = ix.unlocks.GetResourceProvider(resource)

			if (provider and provider.Deduct) then
				provider.Deduct(client, character, amount)
			else
				local current = character:GetData("resource_" .. resource, 0)
				character:SetData("resource_" .. resource, math.max(0, current - amount))
			end
		end
	end

	if (cost.deduct and isfunction(cost.deduct)) then
		cost.deduct(client, character, treeID, nodeID)
	end

	return true
end

--- Refund the cost of a node to a player. Server only.
-- @param ratio number (optional) Fraction of cost to return (0-1). Defaults to 1.
function ix.unlocks.RefundCost(client, treeID, nodeID, ratio)
	if (CLIENT) then return false end

	ratio = math.Clamp(tonumber(ratio) or 1, 0, 1)

	local character = client:GetCharacter()

	if (!character) then return false end

	local node = ix.unlocks.GetNode(treeID, nodeID)

	if (!node) then return false end

	local cost = node.cost

	if (!cost or table.IsEmpty(cost)) then
		return true
	end

	if (cost.money) then
		local amount = cost.money

		if (isfunction(amount)) then
			-- For refunds we use current level (already unlocked)
			local level = character:GetNodeLevel(treeID, nodeID) or 1
			amount = amount(client, character, level) or 0
		end

		amount = math.floor(amount * ratio)

		if (amount > 0 and character.GiveMoney) then
			character:GiveMoney(amount)
		end
	end

	if (cost.resources) then
		for resource, rawAmount in pairs(cost.resources) do
			local amount = rawAmount

			if (isfunction(amount)) then
				local level = character:GetNodeLevel(treeID, nodeID) or 1
				amount = amount(client, character, level) or 0
			end

			amount = math.floor(amount * ratio)

			local provider = ix.unlocks.GetResourceProvider(resource)

			if (provider and provider.Refund) then
				provider.Refund(client, character, amount)
			else
				local current = character:GetData("resource_" .. resource, 0)
				character:SetData("resource_" .. resource, current + amount)
			end
		end
	end

	if (cost.refund and isfunction(cost.refund)) then
		cost.refund(client, character, treeID, nodeID, ratio)
	end

	return true
end

--- Build a human-readable cost summary string for a node.
-- Supports both static and dynamic (function) cost values.
-- @param treeID string
-- @param nodeID string
-- @param client Player (optional, required for dynamic costs; defaults to LocalPlayer on client)
-- @return string
function ix.unlocks.GetCostString(treeID, nodeID, client)
	local node = ix.unlocks.GetNode(treeID, nodeID)

	if (!node or !node.cost or table.IsEmpty(node.cost)) then
		return "Free"
	end

	local character

	if (CLIENT and !client) then
		client = LocalPlayer()
	end

	if (client) then
		character = client:GetCharacter()
	end

	local parts = {}

	if (node.cost.money) then
		local amount = node.cost.money

		if (isfunction(amount) and client and character) then
			amount = amount(client, character, (character:GetNodeLevel(treeID, nodeID) or 0) + 1) or 0
		elseif (isfunction(amount)) then
			amount = 0
		end

		if (amount > 0) then
			if (ix.currency) then
				parts[#parts + 1] = ix.currency.Get(amount)
			else
				parts[#parts + 1] = tostring(amount) .. " credits"
			end
		end
	end

	if (node.cost.resources) then
		for resource, rawAmount in pairs(node.cost.resources) do
			local amount = rawAmount

			if (isfunction(amount) and client and character) then
				amount = amount(client, character, (character:GetNodeLevel(treeID, nodeID) or 0) + 1) or 0
			elseif (isfunction(amount)) then
				amount = 0
			end

			local provider = ix.unlocks.GetResourceProvider(resource)

			if (provider and provider.Format) then
				parts[#parts + 1] = provider.Format(amount)
			else
				local displayName = provider and provider.name or resource
				parts[#parts + 1] = amount .. " " .. displayName
			end
		end
	end

	if (#parts == 0) then
		return "Free"
	end

	return table.concat(parts, ", ")
end

--- Check if a single node can be safely refunded without breaking dependents.
-- A node can only be refunded if no child nodes depend on it being unlocked.
-- @param client Player
-- @param treeID string
-- @param nodeID string
-- @return bool, string
function ix.unlocks.CanRefundNode(client, treeID, nodeID)
	local character = client:GetCharacter()

	if (!character) then
		return false, "No character loaded."
	end

	if (!character:HasUnlockedNode(treeID, nodeID)) then
		return false, "Node is not unlocked."
	end

	-- Check tree-level flags
	local tree = ix.unlocks.GetTree(treeID)

	if (tree and tree.allowRespec == false) then
		return false, "This tree does not allow refunds."
	end

	if (tree and tree.refundable == false) then
		return false, "This tree does not allow refunds."
	end

	-- Check node-level refundable flag
	local node = ix.unlocks.GetNode(treeID, nodeID)

	if (node and node.refundable == false) then
		return false, "This node cannot be refunded."
	end

	-- Check if any children are unlocked (would break the chain)
	local children = ix.unlocks.GetChildren(treeID, nodeID)

	for _, childID in ipairs(children) do
		if (character:HasUnlockedNode(treeID, childID)) then
			local childNode = ix.unlocks.GetNode(treeID, childID)
			return false, "Cannot refund: " .. (childNode and childNode.name or childID) .. " depends on this node."
		end
	end

	local hookResult = hook.Run("CanPlayerRefundNode", client, treeID, nodeID)

	if (hookResult == false) then
		return false, "Refund denied."
	end

	return true
end
