-- sv_networking.lua
-- Server-side network message registration and handlers.

util.AddNetworkString("ixUnlockRequest")
util.AddNetworkString("ixUnlockSync")
util.AddNetworkString("ixUnlockNodeSync")
util.AddNetworkString("ixUnlockRespec")
util.AddNetworkString("ixUnlockDenied")
util.AddNetworkString("ixUnlockRefundNode")

-- ─────────────────────────────────────────────
-- Server → Client Sync
-- ─────────────────────────────────────────────

--- Sync a single node update to a client.
function ix.unlocks.SyncNodeToClient(client, treeID, nodeID)
	local character = client:GetCharacter()

	if (!character) then return end

	local data = character:GetData("ixUnlockTrees", {})
	local nodeData = data[treeID] and data[treeID][nodeID] or {unlocked = false, level = 0}

	net.Start("ixUnlockNodeSync")
		net.WriteString(treeID)
		net.WriteString(nodeID)
		net.WriteBool(nodeData.unlocked or false)
		net.WriteUInt(nodeData.level or 0, 16)
	net.Send(client)
end

--- Sync all nodes for a specific tree to a client.
function ix.unlocks.SyncTreeToClient(client, treeID)
	local character = client:GetCharacter()

	if (!character) then return end

	local data = character:GetData("ixUnlockTrees", {})
	local treeData = data[treeID] or {}
	local encoded = util.TableToJSON(treeData)
	local compressed = util.Compress(encoded)

	if (!compressed) then return end

	net.Start("ixUnlockSync")
		net.WriteString(treeID)
		net.WriteUInt(#compressed, 32)
		net.WriteData(compressed, #compressed)
	net.Send(client)
end

--- Sync all tree progress data to a client.
function ix.unlocks.SyncAllToClient(client)
	local character = client:GetCharacter()

	if (!character) then return end

	local data = character:GetData("ixUnlockTrees", {})
	local encoded = util.TableToJSON(data)
	local compressed = util.Compress(encoded)

	if (!compressed) then return end

	net.Start("ixUnlockSync")
		net.WriteString("__ALL__")
		net.WriteUInt(#compressed, 32)
		net.WriteData(compressed, #compressed)
	net.Send(client)
end

-- ─────────────────────────────────────────────
-- Client → Server Handlers
-- ─────────────────────────────────────────────

--- Handle an unlock request from the client.
net.Receive("ixUnlockRequest", function(len, client)
	local treeID = net.ReadString()
	local nodeID = net.ReadString()

	-- Basic input validation
	if (!isstring(treeID) or !isstring(nodeID)) then return end
	if (#treeID == 0 or #treeID > 64) then return end
	if (#nodeID == 0 or #nodeID > 64) then return end

	local success, reason = ix.unlocks.TryUnlockNode(client, treeID, nodeID)

	if (!success) then
		net.Start("ixUnlockDenied")
			net.WriteString(reason or "Unlock failed.")
		net.Send(client)
	end
end)

--- Handle a single node refund request from the client.
net.Receive("ixUnlockRefundNode", function(len, client)
	local treeID = net.ReadString()
	local nodeID = net.ReadString()

	if (!isstring(treeID) or !isstring(nodeID)) then return end
	if (#treeID == 0 or #treeID > 64) then return end
	if (#nodeID == 0 or #nodeID > 64) then return end

	local success, reason = ix.unlocks.RefundNode(client, treeID, nodeID)

	if (!success) then
		net.Start("ixUnlockDenied")
			net.WriteString(reason or "Refund failed.")
		net.Send(client)
	end
end)

--- Handle a respec request from the client.
net.Receive("ixUnlockRespec", function(len, client)
	local treeID = net.ReadString()
	local bAll = net.ReadBool()
	local bRefund = net.ReadBool()

	if (!isstring(treeID) or #treeID > 64) then return end

	-- Check tree-level allowRespec flag
	if (!bAll) then
		local tree = ix.unlocks.GetTree(treeID)

		if (tree and tree.allowRespec == false) then
			net.Start("ixUnlockDenied")
				net.WriteString("Respec is not allowed for this tree.")
			net.Send(client)

			return
		end
	end

	-- Permission hook
	local canRespec = hook.Run("CanPlayerRespecTree", client, treeID)

	if (canRespec == false) then
		net.Start("ixUnlockDenied")
			net.WriteString("You cannot respec at this time.")
		net.Send(client)

		return
	end

	-- Check respec cost
	local respecCost = ix.config.Get("unlockTreeRespecCost", 0)

	if (respecCost > 0) then
		local character = client:GetCharacter()

		if (character and character.GetMoney and character:GetMoney() < respecCost) then
			net.Start("ixUnlockDenied")
				net.WriteString("Cannot afford respec cost.")
			net.Send(client)

			return
		end

		if (character and character.TakeMoney) then
			character:TakeMoney(respecCost)
		end
	end

	local success, reason

	if (bAll) then
		success, reason = ix.unlocks.RespecAll(client, bRefund)
	else
		success, reason = ix.unlocks.RespecTree(client, treeID, bRefund)
	end

	if (!success) then
		net.Start("ixUnlockDenied")
			net.WriteString(reason or "Respec failed.")
		net.Send(client)
	end
end)

-- ─────────────────────────────────────────────
-- Admin Commands
-- ─────────────────────────────────────────────

ix.command.Add("UnlockGive", {
	description = "Admin-grant a node to a player (bypasses cost/prerequisites).",
	superAdminOnly = true,
	syntax = "<player> <treeID> <nodeID>",
	arguments = {
		ix.type.player,
		ix.type.string,
		ix.type.string
	},
	OnRun = function(self, client, target, treeID, nodeID)
		local success, reason = ix.unlocks.AdminGrantNode(target, treeID, nodeID)

		if (success) then
			client:Notify("Granted \"" .. nodeID .. "\" in tree \"" .. treeID .. "\" to " .. target:Name() .. ".")
			target:Notify("You have been granted an unlock: " .. nodeID)
		else
			client:Notify("Failed: " .. (reason or "Unknown error"))
		end
	end
})

ix.command.Add("UnlockRemove", {
	description = "Admin-remove a node from a player (no refund).",
	superAdminOnly = true,
	syntax = "<player> <treeID> <nodeID>",
	arguments = {
		ix.type.player,
		ix.type.string,
		ix.type.string
	},
	OnRun = function(self, client, target, treeID, nodeID)
		local success, reason = ix.unlocks.AdminRemoveNode(target, treeID, nodeID)

		if (success) then
			client:Notify("Removed \"" .. nodeID .. "\" in tree \"" .. treeID .. "\" from " .. target:Name() .. ".")
		else
			client:Notify("Failed: " .. (reason or "Unknown error"))
		end
	end
})

ix.command.Add("UnlockReset", {
	description = "Admin-reset a player's tree (or all trees). Optionally refund.",
	superAdminOnly = true,
	syntax = "<player> <treeID|*> [refund]",
	arguments = {
		ix.type.player,
		ix.type.string,
		bit.bor(ix.type.bool, ix.type.optional)
	},
	OnRun = function(self, client, target, treeID, bRefund)
		bRefund = bRefund or false

		local success, reason

		if (treeID == "*") then
			success, reason = ix.unlocks.RespecAll(target, bRefund)
		else
			success, reason = ix.unlocks.RespecTree(target, treeID, bRefund)
		end

		if (success) then
			local scope = (treeID == "*") and "all trees" or ("tree \"" .. treeID .. "\"")
			local refundStr = bRefund and " (refunded)" or ""
			client:Notify("Reset " .. scope .. " for " .. target:Name() .. refundStr .. ".")
		else
			client:Notify("Failed: " .. (reason or "Unknown error"))
		end
	end
})
