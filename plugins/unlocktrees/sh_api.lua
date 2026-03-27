-- sh_api.lua
-- Core unlock tree API and character meta extensions.

ix.unlocks = ix.unlocks or {}
ix.unlocks.trees = ix.unlocks.trees or {}
ix.unlocks.resourceProviders = ix.unlocks.resourceProviders or {}

-- Client-side local cache for immediate UI updates
if (CLIENT) then
	ix.unlocks.localData = ix.unlocks.localData or {}
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Resource Providers
-- ─────────────────────────────────────────────────────────────────────────────
--
-- Resource providers define how custom currencies / resources are queried,
-- deducted, refunded, and displayed.  Any key used in a node's
-- cost.resources table can (optionally) have a provider registered here.
-- If no provider exists the system falls back to
-- character:GetData("resource_<key>", 0).
--
-- Provider table fields:
--   name    (string)   Human-readable display name.  Defaults to resourceID.
--   Get     (function) REQUIRED.  Signature: Get(client, character) -> number
--                      Return the current amount of this resource.
--   Deduct  (function) REQUIRED (SERVER).  Signature: Deduct(client, character, amount)
--                      Subtract `amount` from the character.
--   Refund  (function) REQUIRED (SERVER).  Signature: Refund(client, character, amount)
--                      Give `amount` back to the character.
--   Format  (function) OPTIONAL.  Signature: Format(amount) -> string
--                      Return a human-readable string.  When absent the
--                      system uses "<amount> <name>".
--
-- Usage example:
--   ix.unlocks.RegisterResource("xp", {
--       name = "XP",
--       Get    = function(client, character) return character:GetAttribute("xp", 0) end,
--       Deduct = function(client, character, amount)
--           character:SetAttribute("xp", math.max(0, character:GetAttribute("xp", 0) - amount))
--       end,
--       Refund = function(client, character, amount)
--           character:SetAttribute("xp", character:GetAttribute("xp", 0) + amount)
--       end,
--       Format = function(amount) return amount .. " XP" end
--   })
--
-- Once registered, nodes can reference it in their cost table:
--   cost = { resources = { xp = 50 } }
--
-- The provider's Get / Deduct / Refund functions are called automatically
-- during CheckCost, DeductCost and RefundCost.
-- ─────────────────────────────────────────────────────────────────────────────

--- Register a custom resource type that can be used in node costs.
-- @param resourceID string Unique key used in cost.resources tables
-- @param provider table See resource provider documentation above
function ix.unlocks.RegisterResource(resourceID, provider)
	provider.name = provider.name or resourceID
	ix.unlocks.resourceProviders[resourceID] = provider
end

--- Get a registered resource provider.
-- @param resourceID string
-- @return table or nil
function ix.unlocks.GetResourceProvider(resourceID)
	return ix.unlocks.resourceProviders[resourceID]
end

--- Get all registered resource provider IDs.
-- @return table Array of resource ID strings
function ix.unlocks.GetResourceIDs()
	local ids = {}

	for id in pairs(ix.unlocks.resourceProviders) do
		ids[#ids + 1] = id
	end

	return ids
end

-- ─────────────────────────────────────────────
-- Tree Registration
-- ─────────────────────────────────────────────

--- Register a new unlock tree.
-- @param treeID string Unique identifier
-- @param data table Tree definition
-- @return table The registered tree
function ix.unlocks.RegisterTree(treeID, data)
	data = data or {}

	ix.unlocks.trees[treeID] = {
		id = treeID,
		name = data.name or treeID,
		description = data.description or "",
		nodes = {},
		edges = {},
		metadata = data.metadata or {},
		restrictions = data.restrictions or {},
		showInTabMenu = data.showInTabMenu or false,
		allowRespec = data.allowRespec != false, -- default true; set false to hide respec button and block respec
		refundable = data.refundable != false, -- default true; set false to disable refunds for entire tree
		refundRatio = math.Clamp(tonumber(data.refundRatio) or 1, 0, 1), -- 0-1, fraction of node cost returned on single-node refund
		respecRatio = math.Clamp(tonumber(data.respecRatio) or 1, 0, 1) -- 0-1, fraction of node costs returned on full tree respec
	}

	return ix.unlocks.trees[treeID]
end

--- Register a node within a tree.
-- @param treeID string Tree to add the node to
-- @param nodeID string Unique node identifier within the tree
-- @param data table Node definition
-- @return table The registered node
function ix.unlocks.RegisterNode(treeID, nodeID, data)
	local tree = ix.unlocks.trees[treeID]

	if (!tree) then
		ErrorNoHalt("[UnlockTrees] Cannot register node '" .. nodeID .. "': tree '" .. treeID .. "' does not exist.\n")
		return
	end

	data = data or {}

	tree.nodes[nodeID] = {
		id = nodeID,
		name = data.name or nodeID,
		description = data.description or "",
		icon = data.icon or "icon16/brick.png",
		position = data.position or {x = 0, y = 0},
		cost = data.cost or {},
		requirements = data.requirements or {},
		type = data.type or "normal",
		repeatable = data.repeatable or false,
		maxLevel = data.maxLevel or 1,
		metadata = data.metadata or {},
		onUnlocked = data.onUnlocked,
		onRefunded = data.onRefunded,
		mutuallyExclusive = data.mutuallyExclusive or {},
		category = data.category,
		hidden = data.hidden or nil, -- bool or function(client, character) returning true when visible
		refundable = data.refundable != false -- default true; set false to prevent refunding this node
	}

	hook.Run("UnlockNodeRegistered", treeID, nodeID, tree.nodes[nodeID])

	return tree.nodes[nodeID]
end

--- Connect two nodes with a prerequisite edge (parent -> child).
-- The parent must be unlocked before the child can be unlocked.
-- @param treeID string
-- @param parentNode string
-- @param childNode string
function ix.unlocks.ConnectNodes(treeID, parentNode, childNode)
	local tree = ix.unlocks.trees[treeID]

	if (!tree) then
		ErrorNoHalt("[UnlockTrees] Cannot connect nodes: tree '" .. treeID .. "' does not exist.\n")
		return
	end

	if (!tree.nodes[parentNode]) then
		ErrorNoHalt("[UnlockTrees] Cannot connect nodes: parent '" .. parentNode .. "' does not exist.\n")
		return
	end

	if (!tree.nodes[childNode]) then
		ErrorNoHalt("[UnlockTrees] Cannot connect nodes: child '" .. childNode .. "' does not exist.\n")
		return
	end

	tree.edges[#tree.edges + 1] = {
		from = parentNode,
		to = childNode
	}
end

--- Mark two or more nodes as mutually exclusive (bidirectional).
-- Once any node in the group is unlocked, the others cannot be unlocked.
-- @param treeID string
-- @param ... string Node IDs (variadic, at least 2)
function ix.unlocks.SetExclusive(treeID, ...)
	local tree = ix.unlocks.trees[treeID]

	if (!tree) then
		ErrorNoHalt("[UnlockTrees] SetExclusive: tree '" .. treeID .. "' does not exist.\n")
		return
	end

	local nodeIDs = {...}

	if (#nodeIDs < 2) then
		ErrorNoHalt("[UnlockTrees] SetExclusive: need at least 2 node IDs.\n")
		return
	end

	for _, nodeID in ipairs(nodeIDs) do
		local node = tree.nodes[nodeID]

		if (node) then
			node.mutuallyExclusive = node.mutuallyExclusive or {}

			for _, otherID in ipairs(nodeIDs) do
				if (otherID != nodeID and !table.HasValue(node.mutuallyExclusive, otherID)) then
					node.mutuallyExclusive[#node.mutuallyExclusive + 1] = otherID
				end
			end
		else
			ErrorNoHalt("[UnlockTrees] SetExclusive: node '" .. nodeID .. "' does not exist in tree '" .. treeID .. "'.\n")
		end
	end
end

-- ─────────────────────────────────────────────
-- Tree Queries
-- ─────────────────────────────────────────────

--- Get a tree by ID.
function ix.unlocks.GetTree(treeID)
	return ix.unlocks.trees[treeID]
end

--- Get a node from a tree.
function ix.unlocks.GetNode(treeID, nodeID)
	local tree = ix.unlocks.trees[treeID]
	if (!tree) then return nil end

	return tree.nodes[nodeID]
end

--- Get all prerequisite node IDs for a given node.
function ix.unlocks.GetPrerequisites(treeID, nodeID)
	local tree = ix.unlocks.trees[treeID]
	if (!tree) then return {} end

	local prereqs = {}

	for _, edge in ipairs(tree.edges) do
		if (edge.to == nodeID) then
			prereqs[#prereqs + 1] = edge.from
		end
	end

	return prereqs
end

--- Get all immediate children of a given node.
function ix.unlocks.GetChildren(treeID, nodeID)
	local tree = ix.unlocks.trees[treeID]
	if (!tree) then return {} end

	local children = {}

	for _, edge in ipairs(tree.edges) do
		if (edge.from == nodeID) then
			children[#children + 1] = edge.to
		end
	end

	return children
end

--- Get list of all registered tree IDs.
function ix.unlocks.GetTreeIDs()
	local ids = {}

	for id in pairs(ix.unlocks.trees) do
		ids[#ids + 1] = id
	end

	return ids
end

-- ─────────────────────────────────────────────
-- Hidden Node Visibility
-- ─────────────────────────────────────────────

--- Check if a hidden node is visible to a player.
-- A node is visible when:
--   1. It has no `hidden` table, OR
--   2. Its `hidden.condition(client, character)` returns true.
-- If a node's prerequisite chain contains hidden nodes the player cannot see,
-- this node is also hidden (cascading).
-- @param client Player
-- @param treeID string
-- @param nodeID string
-- @return bool
function ix.unlocks.IsNodeVisible(client, treeID, nodeID)
	local character = client:GetCharacter()
	local tree = ix.unlocks.trees[treeID]

	if (!tree) then return false end

	local node = tree.nodes[nodeID]

	if (!node) then return false end

	-- Memoize within a single call chain to avoid repeated graph walks
	local cache = ix.unlocks._visCache

	if (!cache or cache._client != client or cache._treeID != treeID) then
		cache = {_client = client, _treeID = treeID}
		ix.unlocks._visCache = cache
	end

	if (cache[nodeID] != nil) then
		return cache[nodeID]
	end

	-- Prevent infinite recursion on cycles
	cache[nodeID] = false

	-- Check own hidden condition
	if (node.hidden) then
		local visible = false

		if (isfunction(node.hidden)) then
			-- Pass unlock data as 3rd arg so hidden functions don't need GetData on client
			local unlockData = character:GetUnlockData()
			visible = node.hidden(client, character, unlockData)
		elseif (isbool(node.hidden)) then
			visible = false -- static hidden = true means always hidden by default
		end

		if (!visible) then
			-- Allow hook override
			local hookResult = hook.Run("CanPlayerSeeNode", client, treeID, nodeID)

			if (hookResult != true) then
				cache[nodeID] = false
				return false
			end
		end
	end

	-- Check prerequisite chain: if any prereq is hidden and not visible, this node is also hidden
	local prereqs = ix.unlocks.GetPrerequisites(treeID, nodeID)

	for _, prereqID in ipairs(prereqs) do
		local prereqNode = tree.nodes[prereqID]

		if (prereqNode and prereqNode.hidden) then
			if (!ix.unlocks.IsNodeVisible(client, treeID, prereqID)) then
				cache[nodeID] = false
				return false
			end
		end
	end

	cache[nodeID] = true
	return true
end

--- Invalidate the visibility cache (call when conditions change).
function ix.unlocks.InvalidateVisibilityCache()
	ix.unlocks._visCache = nil
end

--- Get all visible node IDs in a tree for a player.
-- @param client Player
-- @param treeID string
-- @return table Array of visible nodeIDs
function ix.unlocks.GetVisibleNodes(client, treeID)
	local tree = ix.unlocks.trees[treeID]

	if (!tree) then return {} end

	ix.unlocks.InvalidateVisibilityCache()

	local visible = {}

	for nodeID in pairs(tree.nodes) do
		if (ix.unlocks.IsNodeVisible(client, treeID, nodeID)) then
			visible[#visible + 1] = nodeID
		end
	end

	return visible
end

-- ─────────────────────────────────────────────
-- Path Cost Calculator
-- ─────────────────────────────────────────────

--- Calculate the total cost of unlocking a node including all unmet prerequisites.
-- Walks the prerequisite chain and sums costs of nodes the character has not yet unlocked.
-- @param client Player
-- @param treeID string
-- @param nodeID string
-- @return table { money = number, resources = { [resourceID] = amount } }
function ix.unlocks.GetPathCost(client, treeID, nodeID)
	local character = client:GetCharacter()
	local totalCost = {money = 0, resources = {}}

	if (!character) then return totalCost end

	local visited = {}

	local function walk(nid)
		if (visited[nid]) then return end

		visited[nid] = true

		-- Walk prerequisites first
		local prereqs = ix.unlocks.GetPrerequisites(treeID, nid)

		for _, prereqID in ipairs(prereqs) do
			walk(prereqID)
		end

		-- Add cost if not already unlocked
		if (!character:HasUnlockedNode(treeID, nid)) then
			local node = ix.unlocks.GetNode(treeID, nid)

			if (node and node.cost) then
				local cost = node.cost

				if (cost.money) then
					local amount = cost.money

					if (isfunction(amount)) then
						amount = amount(client, character, (character:GetNodeLevel(treeID, nid) or 0) + 1)
					end

					totalCost.money = totalCost.money + (amount or 0)
				end

				if (cost.resources) then
					for resource, amount in pairs(cost.resources) do
						if (isfunction(amount)) then
							amount = amount(client, character, (character:GetNodeLevel(treeID, nid) or 0) + 1)
						end

						totalCost.resources[resource] = (totalCost.resources[resource] or 0) + (amount or 0)
					end
				end
			end
		end
	end

	walk(nodeID)

	return totalCost
end

--- Build a human-readable path cost string.
-- @param client Player
-- @param treeID string
-- @param nodeID string
-- @return string
function ix.unlocks.GetPathCostString(client, treeID, nodeID)
	local cost = ix.unlocks.GetPathCost(client, treeID, nodeID)
	local parts = {}

	if (cost.money > 0) then
		if (ix.currency) then
			parts[#parts + 1] = ix.currency.Get(cost.money)
		else
			parts[#parts + 1] = tostring(cost.money) .. " credits"
		end
	end

	for resource, amount in pairs(cost.resources) do
		local provider = ix.unlocks.GetResourceProvider(resource)

		if (provider and provider.Format) then
			parts[#parts + 1] = provider.Format(amount)
		else
			local displayName = provider and provider.name or resource
			parts[#parts + 1] = amount .. " " .. displayName
		end
	end

	if (#parts == 0) then
		return "Free"
	end

	return table.concat(parts, ", ")
end

-- ─────────────────────────────────────────────
-- Character Meta Extensions
-- ─────────────────────────────────────────────

local CHAR = ix.meta.character

--- Check if this character has unlocked a specific node.
function CHAR:HasUnlockedNode(treeID, nodeID)
	-- Prefer client local cache for instant updates
	if (CLIENT and ix.unlocks.localData[treeID]) then
		local nodeData = ix.unlocks.localData[treeID][nodeID]
		return nodeData and nodeData.unlocked == true or false
	end

	local data = self:GetData("ixUnlockTrees", {})
	local treeData = data[treeID]

	if (!treeData or !treeData[nodeID]) then
		return false
	end

	return treeData[nodeID].unlocked == true
end

--- Get the current level of a specific node (for repeatable nodes).
function CHAR:GetNodeLevel(treeID, nodeID)
	if (CLIENT and ix.unlocks.localData[treeID]) then
		local nodeData = ix.unlocks.localData[treeID][nodeID]
		return nodeData and nodeData.level or 0
	end

	local data = self:GetData("ixUnlockTrees", {})
	local treeData = data[treeID]

	if (!treeData or !treeData[nodeID]) then
		return 0
	end

	return treeData[nodeID].level or 0
end

--- Get all unlocked nodes for a specific tree.
function CHAR:GetUnlockedNodes(treeID)
	local source

	if (CLIENT and ix.unlocks.localData[treeID]) then
		source = ix.unlocks.localData[treeID]
	else
		local data = self:GetData("ixUnlockTrees", {})
		source = data[treeID]
	end

	if (!source) then
		return {}
	end

	local unlocked = {}

	for nodeID, nodeData in pairs(source) do
		if (nodeData.unlocked) then
			unlocked[nodeID] = nodeData
		end
	end

	return unlocked
end

--- Get the full unlock data table for this character.
function CHAR:GetUnlockData()
	if (CLIENT) then
		return ix.unlocks.localData
	end

	return self:GetData("ixUnlockTrees", {})
end

-- ─────────────────────────────────────────────
-- Player Meta Convenience Wrappers
-- ─────────────────────────────────────────────

local PLAYER = FindMetaTable("Player")

--- Convenience: check if the player's current character has an unlocked node.
function PLAYER:HasUnlockedNode(treeID, nodeID)
	local character = self:GetCharacter()
	if (!character) then return false end

	return character:HasUnlockedNode(treeID, nodeID)
end

--- Convenience: get all unlocked nodes for the player's current character.
function PLAYER:GetUnlockedNodes(treeID)
	local character = self:GetCharacter()
	if (!character) then return {} end

	return character:GetUnlockedNodes(treeID)
end

-- ─────────────────────────────────────────────
-- Client-Side Unlock Request
-- ─────────────────────────────────────────────

if (CLIENT) then
	--- Request the server to unlock a node.
	function ix.unlocks.RequestUnlock(treeID, nodeID)
		net.Start("ixUnlockRequest")
			net.WriteString(treeID)
			net.WriteString(nodeID)
		net.SendToServer()
	end

	--- Request the server to refund a single node.
	function ix.unlocks.RequestRefundNode(treeID, nodeID)
		net.Start("ixUnlockRefundNode")
			net.WriteString(treeID)
			net.WriteString(nodeID)
		net.SendToServer()
	end

	--- Request the server to respec a tree.
	function ix.unlocks.RequestRespec(treeID, bAll, bRefund)
		net.Start("ixUnlockRespec")
			net.WriteString(treeID or "")
			net.WriteBool(bAll or false)
			net.WriteBool(bRefund or false)
		net.SendToServer()
	end
end
