-- sv_progression.lua
-- Server-side unlock validation, application, respec, single-node refund,
-- batch unlock, audit log, and cooldown recording.

-- ─────────────────────────────────────────────────────────────────────────────
-- Audit Log
-- ─────────────────────────────────────────────────────────────────────────────

--- Record an unlock event for debugging and analytics.
-- Stored per-character in "ixUnlockLog" as an array of recent events.
-- @param character table
-- @param action string  "unlock" | "refund" | "respec" | "admin_grant" | "admin_remove"
-- @param treeID string
-- @param nodeID string|nil
-- @param extra table|nil  Additional context
local MAX_LOG_ENTRIES = 200

local function RecordAuditLog(character, action, treeID, nodeID, extra)
	local log = character:GetData("ixUnlockLog", {})

	log[#log + 1] = {
		action = action,
		tree = treeID,
		node = nodeID,
		time = os.time(),
		extra = extra
	}

	-- Trim old entries
	if (#log > MAX_LOG_ENTRIES) then
		local trimmed = {}

		for i = #log - MAX_LOG_ENTRIES + 1, #log do
			trimmed[#trimmed + 1] = log[i]
		end

		log = trimmed
	end

	character:SetData("ixUnlockLog", log)
end

--- Get the audit log for a character.
-- @param character table
-- @return table Array of log entries
function ix.unlocks.GetAuditLog(character)
	return character:GetData("ixUnlockLog", {})
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Cooldown Recording
-- ─────────────────────────────────────────────────────────────────────────────

--- Record a cooldown timestamp after a node with a cooldown requirement is unlocked.
-- @param character table
-- @param treeID string
-- @param nodeID string
local function RecordCooldown(character, treeID, nodeID)
	local node = ix.unlocks.GetNode(treeID, nodeID)

	if (!node or !node.requirements or !node.requirements.cooldown) then return end

	local cd = node.requirements.cooldown
	local key = cd.key or (treeID .. "_" .. nodeID)
	local data = character:GetData("ixUnlockCooldowns", {})

	data[key] = os.time()
	character:SetData("ixUnlockCooldowns", data)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Primary Unlock
-- ─────────────────────────────────────────────────────────────────────────────

--- Attempt to unlock a node for a player. This is the primary entry point.
-- Validates access, prerequisites, cost, then applies the unlock.
-- @param client Player
-- @param treeID string
-- @param nodeID string
-- @return bool success, string reason
function ix.unlocks.TryUnlockNode(client, treeID, nodeID)
	local character = client:GetCharacter()

	if (!character) then
		return false, "No character loaded."
	end

	local tree = ix.unlocks.GetTree(treeID)

	if (!tree) then
		return false, "Tree does not exist."
	end

	-- Tree-level access
	local canAccess, accessReason = ix.unlocks.CanAccessTree(client, treeID)

	if (!canAccess) then
		return false, accessReason
	end

	-- Hidden node visibility check
	if (!ix.unlocks.IsNodeVisible(client, treeID, nodeID)) then
		return false, "Node is not available."
	end

	-- External hook veto
	local hookResult = hook.Run("CanPlayerUnlockNode", client, treeID, nodeID)

	if (hookResult == false) then
		return false, "Unlock denied."
	end

	-- Prerequisite / requirement check
	local canUnlock, prereqReason = ix.unlocks.CheckPrerequisites(client, treeID, nodeID)

	if (!canUnlock) then
		return false, prereqReason
	end

	-- Cost check
	local canAfford, costReason = ix.unlocks.CheckCost(client, treeID, nodeID)

	if (!canAfford) then
		return false, costReason
	end

	-- Pre-unlock hook (last chance to modify behaviour)
	hook.Run("PrePlayerUnlockNode", client, treeID, nodeID)

	-- All checks passed — deduct cost
	ix.unlocks.DeductCost(client, treeID, nodeID)

	-- Apply unlock to character data
	local node = ix.unlocks.GetNode(treeID, nodeID)
	local data = character:GetData("ixUnlockTrees", {})

	if (!data[treeID]) then
		data[treeID] = {}
	end

	local currentLevel = 0

	if (data[treeID][nodeID]) then
		currentLevel = data[treeID][nodeID].level or 0
	end

	data[treeID][nodeID] = {
		unlocked = true,
		level = currentLevel + 1
	}

	character:SetData("ixUnlockTrees", data)

	-- Record cooldown if applicable
	RecordCooldown(character, treeID, nodeID)

	-- Record audit log
	RecordAuditLog(character, "unlock", treeID, nodeID, {level = currentLevel + 1})

	-- Fire node callback
	if (node.onUnlocked and isfunction(node.onUnlocked)) then
		node.onUnlocked(client, character, treeID, nodeID, currentLevel + 1)
	end

	-- Fire hook for other plugins
	hook.Run("PlayerUnlockedNode", client, treeID, nodeID, currentLevel + 1)

	-- Immediate client sync
	ix.unlocks.SyncNodeToClient(client, treeID, nodeID)

	return true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Single Node Refund
-- ─────────────────────────────────────────────────────────────────────────────

--- Refund a single node for a player. Only works if no children depend on it.
-- @param client Player
-- @param treeID string
-- @param nodeID string
-- @return bool, string
function ix.unlocks.RefundNode(client, treeID, nodeID)
	local character = client:GetCharacter()

	if (!character) then
		return false, "No character loaded."
	end

	-- Validate refund is possible
	local canRefund, reason = ix.unlocks.CanRefundNode(client, treeID, nodeID)

	if (!canRefund) then
		return false, reason
	end

	local node = ix.unlocks.GetNode(treeID, nodeID)
	local data = character:GetData("ixUnlockTrees", {})

	if (!data[treeID] or !data[treeID][nodeID]) then
		return false, "Node is not unlocked."
	end

	local nodeData = data[treeID][nodeID]
	local level = nodeData.level or 1

	-- Refund the cost for this level (scaled by tree refundRatio)
	local tree = ix.unlocks.GetTree(treeID)
	local refundRatio = (tree and tree.refundRatio) or 1
	ix.unlocks.RefundCost(client, treeID, nodeID, refundRatio)

	-- Update data
	if (node.repeatable and level > 1) then
		data[treeID][nodeID] = {
			unlocked = true,
			level = level - 1
		}
	else
		data[treeID][nodeID] = nil
	end

	character:SetData("ixUnlockTrees", data)

	-- Record audit log
	RecordAuditLog(character, "refund", treeID, nodeID, {level = level})

	-- Fire node callback
	if (node.onRefunded and isfunction(node.onRefunded)) then
		node.onRefunded(client, character, treeID, nodeID, level)
	end

	-- Fire hook
	hook.Run("PlayerRefundedNode", client, treeID, nodeID, level)

	-- Sync to client
	ix.unlocks.SyncNodeToClient(client, treeID, nodeID)

	return true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Batch Unlock
-- ─────────────────────────────────────────────────────────────────────────────

--- Unlock multiple nodes at once for a player. Processes in order.
-- Stops at the first failure unless bContinueOnFail is true.
-- @param client Player
-- @param treeID string
-- @param nodeIDs table Array of nodeID strings
-- @param bContinueOnFail bool If true, skip failing nodes and continue
-- @return table { results = { [nodeID] = {success, reason} }, succeeded = number, failed = number }
function ix.unlocks.UnlockMultiple(client, treeID, nodeIDs, bContinueOnFail)
	local results = {}
	local succeeded = 0
	local failed = 0

	for _, nodeID in ipairs(nodeIDs) do
		local success, reason = ix.unlocks.TryUnlockNode(client, treeID, nodeID)

		results[nodeID] = {success = success, reason = reason}

		if (success) then
			succeeded = succeeded + 1
		else
			failed = failed + 1

			if (!bContinueOnFail) then
				break
			end
		end
	end

	hook.Run("PlayerBatchUnlocked", client, treeID, results, succeeded, failed)

	return {results = results, succeeded = succeeded, failed = failed}
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Admin Bypass Unlock / Remove
-- ─────────────────────────────────────────────────────────────────────────────

--- Admin-only: directly grant a node without cost or prerequisite checks.
-- @param client Player
-- @param treeID string
-- @param nodeID string
-- @return bool, string
function ix.unlocks.AdminGrantNode(client, treeID, nodeID)
	local character = client:GetCharacter()

	if (!character) then
		return false, "No character loaded."
	end

	local node = ix.unlocks.GetNode(treeID, nodeID)

	if (!node) then
		return false, "Node does not exist."
	end

	local data = character:GetData("ixUnlockTrees", {})

	if (!data[treeID]) then
		data[treeID] = {}
	end

	local currentLevel = 0

	if (data[treeID][nodeID]) then
		currentLevel = data[treeID][nodeID].level or 0
	end

	data[treeID][nodeID] = {
		unlocked = true,
		level = currentLevel + 1
	}

	character:SetData("ixUnlockTrees", data)

	RecordAuditLog(character, "admin_grant", treeID, nodeID, {level = currentLevel + 1})

	hook.Run("PlayerUnlockedNode", client, treeID, nodeID, currentLevel + 1)

	ix.unlocks.SyncNodeToClient(client, treeID, nodeID)

	return true
end

--- Admin-only: directly remove a node (no refund).
-- @param client Player
-- @param treeID string
-- @param nodeID string
-- @return bool, string
function ix.unlocks.AdminRemoveNode(client, treeID, nodeID)
	local character = client:GetCharacter()

	if (!character) then
		return false, "No character loaded."
	end

	local data = character:GetData("ixUnlockTrees", {})

	if (!data[treeID] or !data[treeID][nodeID]) then
		return false, "Node is not unlocked."
	end

	local oldLevel = data[treeID][nodeID].level or 1

	data[treeID][nodeID] = nil
	character:SetData("ixUnlockTrees", data)

	RecordAuditLog(character, "admin_remove", treeID, nodeID, {level = oldLevel})

	hook.Run("PlayerNodeRemoved", client, treeID, nodeID, oldLevel)

	ix.unlocks.SyncNodeToClient(client, treeID, nodeID)

	return true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Respec
-- ─────────────────────────────────────────────────────────────────────────────

--- Respec (reset) a specific tree for a player.
-- @param client Player
-- @param treeID string
-- @param bRefund bool Whether to refund node costs
-- @return bool, string
function ix.unlocks.RespecTree(client, treeID, bRefund)
	local character = client:GetCharacter()

	if (!character) then
		return false, "No character loaded."
	end

	local tree = ix.unlocks.GetTree(treeID)

	if (!tree) then
		return false, "Tree does not exist."
	end

	local data = character:GetData("ixUnlockTrees", {})

	if (!data[treeID] or table.IsEmpty(data[treeID])) then
		return false, "No progress to reset."
	end

	-- Refund if requested (scaled by tree respecRatio)
	if (bRefund) then
		local respecRatio = (tree and tree.respecRatio) or 1

		for nodeID, nodeData in pairs(data[treeID]) do
			if (nodeData.unlocked) then
				local level = nodeData.level or 1

				for _ = 1, level do
					ix.unlocks.RefundCost(client, treeID, nodeID, respecRatio)
				end
			end
		end
	end

	RecordAuditLog(character, "respec", treeID, nil, {refunded = bRefund})

	data[treeID] = nil
	character:SetData("ixUnlockTrees", data)

	-- Sync cleared tree to client
	ix.unlocks.SyncTreeToClient(client, treeID)

	hook.Run("PlayerRespecTree", client, treeID, bRefund)

	return true
end

--- Respec all trees for a player.
-- @param client Player
-- @param bRefund bool
-- @return bool, string
function ix.unlocks.RespecAll(client, bRefund)
	local character = client:GetCharacter()

	if (!character) then
		return false, "No character loaded."
	end

	local data = character:GetData("ixUnlockTrees", {})

	if (bRefund) then
		for treeID, treeData in pairs(data) do
			local tree = ix.unlocks.GetTree(treeID)
			local respecRatio = (tree and tree.respecRatio) or 1

			for nodeID, nodeData in pairs(treeData) do
				if (nodeData.unlocked) then
					local level = nodeData.level or 1

					for _ = 1, level do
						ix.unlocks.RefundCost(client, treeID, nodeID, respecRatio)
					end
				end
			end
		end
	end

	RecordAuditLog(character, "respec", "__ALL__", nil, {refunded = bRefund})

	character:SetData("ixUnlockTrees", {})

	-- Sync empty state to client
	ix.unlocks.SyncAllToClient(client)

	hook.Run("PlayerRespecAll", client, bRefund)

	return true
end
