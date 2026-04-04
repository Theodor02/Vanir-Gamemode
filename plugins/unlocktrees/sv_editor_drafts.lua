-- sv_editor_drafts.lua
-- Server-side draft persistence for the unlock tree editor.

util.AddNetworkString("ixUnlockEditorDraftSaveRequest")
util.AddNetworkString("ixUnlockEditorDraftListRequest")
util.AddNetworkString("ixUnlockEditorDraftLoadRequest")
util.AddNetworkString("ixUnlockEditorDraftRenameRequest")
util.AddNetworkString("ixUnlockEditorDraftDeleteRequest")
util.AddNetworkString("ixUnlockEditorDraftRestoreRequest")
util.AddNetworkString("ixUnlockEditorDraftBackupListRequest")
util.AddNetworkString("ixUnlockEditorDraftRestoreBackupRequest")
util.AddNetworkString("ixUnlockEditorDraftStatus")
util.AddNetworkString("ixUnlockEditorDraftList")
util.AddNetworkString("ixUnlockEditorDraftBackupList")
util.AddNetworkString("ixUnlockEditorDraftLoad")

local DRAFT_FILE = "unlocktrees/editor_drafts.json"
local MAX_BACKUPS = 5
local SCHEMA_VERSION = 1

local function EnsureStorage()
	file.CreateDir("unlocktrees")
end

local function SendStatus(client, message)
	if (!IsValid(client)) then return end

	net.Start("ixUnlockEditorDraftStatus")
		net.WriteString(message or "")
	net.Send(client)
end

local function SanitizeID(value, fallback)
	local id = tostring(value or fallback or "")
	id = string.lower(id:gsub("[^%w_%-%s]+", "_"))
	id = id:gsub("%s+", "_")
	id = id:gsub("_+", "_")
	id = id:gsub("^_+", "")
	id = id:gsub("_+$", "")

	if (id == "") then
		id = fallback or "draft"
	end

	return string.sub(id, 1, 64)
end

local function MakeRecordKey(kind, draftID)
	kind = (kind == "preset") and "preset" or "draft"
	return kind .. ":" .. SanitizeID(draftID)
end

local function LoadRegistry()
	EnsureStorage()

	local raw = file.Read(DRAFT_FILE, "DATA")

	if (!raw or raw == "") then
		return {version = SCHEMA_VERSION, drafts = {}}
	end

	local decoded = util.JSONToTable(raw)

	if (!istable(decoded)) then
		return {version = SCHEMA_VERSION, drafts = {}}
	end

	decoded.version = decoded.version or SCHEMA_VERSION
	decoded.drafts = istable(decoded.drafts) and decoded.drafts or {}

	return decoded
end

local function SaveRegistry(registry)
	EnsureStorage()
	file.Write(DRAFT_FILE, util.TableToJSON(registry, true) or "{}")
end

local function NormalizeSnapshot(snapshot)
	if (!istable(snapshot)) then
		return nil, "Invalid draft data."
	end

	if (!istable(snapshot.nodes) or !istable(snapshot.edges)) then
		return nil, "Draft data is missing nodes or edges."
	end

	local nodes = {}

	for nodeID, node in pairs(snapshot.nodes) do
		if (isstring(nodeID) and istable(node)) then
			local copy = table.Copy(node)
			copy.id = nodeID
			nodes[nodeID] = copy
		end
	end

	local edges = {}

	for _, edge in ipairs(snapshot.edges) do
		if (istable(edge) and isstring(edge.from) and isstring(edge.to) and nodes[edge.from] and nodes[edge.to]) then
			edges[#edges + 1] = {from = edge.from, to = edge.to}
		end
	end

	snapshot.nodes = nodes
	snapshot.edges = edges
	snapshot.nextNodeIndex = tonumber(snapshot.nextNodeIndex) or 1
	snapshot.treeID = tostring(snapshot.treeID or "")
	snapshot.treeName = tostring(snapshot.treeName or "New Tree")
	snapshot.treeDescription = tostring(snapshot.treeDescription or "")
	snapshot.version = SCHEMA_VERSION

	return snapshot
end

local function DraftAccessScope(client, scope, ownerSteamID64)
	if (!IsValid(client) or !client:IsAdmin()) then
		return false
	end

	if (scope == "shared") then
		return client:IsSuperAdmin() or client:IsAdmin()
	end

	if (ownerSteamID64 and ownerSteamID64 == client:SteamID64()) then
		return true
	end

	return client:IsSuperAdmin()
end

local function BuildMetadata(record)
	return {
		id = record.id,
		kind = record.kind,
		scope = record.scope,
		label = record.label,
		treeID = record.treeID,
		treeName = record.treeName,
		treeDescription = record.treeDescription,
		ownerSteamID64 = record.ownerSteamID64,
		ownerName = record.ownerName,
		updatedAt = record.updatedAt,
		createdAt = record.createdAt,
		backupCount = istable(record.backups) and #record.backups or 0
	}
end

local function BuildBackupList(record)
	local backups = {}

	for index = #record.backups, 1, -1 do
		local backup = record.backups[index]
		backups[#backups + 1] = {
			index = #record.backups - index + 1,
			createdAt = backup.timestamp,
			label = backup.label,
			treeID = backup.treeID,
			treeName = backup.treeName,
			treeDescription = backup.treeDescription
		}
	end

	return backups
end

local function ResolveRecordKey(registry, kind, draftID)
	local namespacedKey = MakeRecordKey(kind, draftID)
	local bareKey = SanitizeID(draftID)

	if (registry.drafts[namespacedKey]) then
		return namespacedKey, registry.drafts[namespacedKey]
	end

	if (registry.drafts[bareKey]) then
		return bareKey, registry.drafts[bareKey]
	end

	return namespacedKey, nil
end

local function SaveRecord(client, kind, scope, draftID, label, snapshot)
	local registry = LoadRegistry()
	local normalizedSnapshot, err = NormalizeSnapshot(snapshot)

	if (!normalizedSnapshot) then
		return false, err
	end

	kind = (kind == "preset") and "preset" or "draft"
	scope = (scope == "shared") and "shared" or "private"
	local recordID = SanitizeID(draftID or (normalizedSnapshot.treeID ~= "" and normalizedSnapshot.treeID or "draft"))
	local recordKey = MakeRecordKey(kind, recordID)
	label = tostring(label or normalizedSnapshot.treeName or recordID)

	local existingKey, existing = ResolveRecordKey(registry, kind, recordID)
	local now = os.time()
	local ownerSteamID64 = client:SteamID64()
	local ownerName = client:Name()

	if (existing) then
		if (!DraftAccessScope(client, existing.scope, existing.ownerSteamID64)) then
			return false, "You do not have permission to overwrite this draft."
		end

		existing.backups = istable(existing.backups) and existing.backups or {}

		existing.backups[#existing.backups + 1] = {
			timestamp = existing.updatedAt or now,
			label = existing.label,
			treeID = existing.treeID,
			treeName = existing.treeName,
			treeDescription = existing.treeDescription,
			snapshot = existing.snapshot
		}

		while (#existing.backups > MAX_BACKUPS) do
			table.remove(existing.backups, 1)
		end
	else
		existing = {
			createdAt = now,
			backups = {}
		}
	end

	existing.id = recordID
	existing.kind = kind
	existing.scope = scope
	existing.label = label
	existing.ownerSteamID64 = existing.ownerSteamID64 or ownerSteamID64
	existing.ownerName = existing.ownerName or ownerName
	existing.treeID = normalizedSnapshot.treeID
	existing.treeName = normalizedSnapshot.treeName
	existing.treeDescription = normalizedSnapshot.treeDescription
	existing.updatedAt = now
	existing.snapshot = normalizedSnapshot

	registry.drafts[recordKey] = existing
	if (existingKey ~= recordKey) then
		registry.drafts[existingKey] = nil
	end
	SaveRegistry(registry)

	return true, existing
end

local function ListRecords(client, kind)
	local registry = LoadRegistry()
	local results = {}
	local steamID64 = client:SteamID64()

	for _, record in pairs(registry.drafts) do
		if ((not kind or record.kind == kind) and (record.scope == "shared" or record.ownerSteamID64 == steamID64 or client:IsSuperAdmin())) then
			results[#results + 1] = BuildMetadata(record)
		end
	end

	table.sort(results, function(a, b)
		return (a.updatedAt or 0) > (b.updatedAt or 0)
	end)

	return results
end

local function LoadRecord(client, kind, scope, draftID)
	local registry = LoadRegistry()
	local key, record = ResolveRecordKey(registry, kind, draftID)

	if (!record or record.scope ~= scope or (kind and record.kind ~= kind)) then
		return false, "Draft not found."
	end

	if (!DraftAccessScope(client, record.scope, record.ownerSteamID64)) then
		return false, "You do not have permission to load this draft."
	end

	local snapshot = table.Copy(record.snapshot or {})

	if (!snapshot or !snapshot.nodes) then
		return false, "Draft snapshot is invalid."
	end

	return true, snapshot, BuildMetadata(record)
end

local function RenameRecord(client, kind, scope, draftID, newLabel)
	local registry = LoadRegistry()
	local key, record = ResolveRecordKey(registry, kind, draftID)

	if (!record or record.scope ~= scope or (kind and record.kind ~= kind)) then
		return false, "Draft not found."
	end

	if (!DraftAccessScope(client, record.scope, record.ownerSteamID64)) then
		return false, "You do not have permission to rename this draft."
	end

	record.label = tostring(newLabel or record.label or record.id)
	record.updatedAt = os.time()
	registry.drafts[key] = record
	SaveRegistry(registry)

	return true, BuildMetadata(record)
end

local function DeleteRecord(client, kind, scope, draftID)
	local registry = LoadRegistry()
	local key, record = ResolveRecordKey(registry, kind, draftID)

	if (!record or record.scope ~= scope or (kind and record.kind ~= kind)) then
		return false, "Draft not found."
	end

	if (!DraftAccessScope(client, record.scope, record.ownerSteamID64)) then
		return false, "You do not have permission to delete this draft."
	end

	registry.drafts[key] = nil
	SaveRegistry(registry)

	return true
end

local function RestoreLatestBackup(client, kind, scope, draftID)
	local registry = LoadRegistry()
	local key, record = ResolveRecordKey(registry, kind, draftID)

	if (!record or record.scope ~= scope or (kind and record.kind ~= kind)) then
		return false, "Draft not found."
	end

	if (!DraftAccessScope(client, record.scope, record.ownerSteamID64)) then
		return false, "You do not have permission to restore this draft."
	end

	if (!istable(record.backups) or #record.backups == 0) then
		return false, "No backup is available for this record."
	end

	local backup = record.backups[#record.backups]

	if (!istable(backup.snapshot)) then
		return false, "Backup snapshot is invalid."
	end

	record.backups[#record.backups] = nil
	record.backups[#record.backups + 1] = {
		timestamp = record.updatedAt or os.time(),
		label = record.label,
		treeID = record.treeID,
		treeName = record.treeName,
		treeDescription = record.treeDescription,
		snapshot = record.snapshot
	}

	record.snapshot = table.Copy(backup.snapshot)
	record.treeID = record.snapshot.treeID or record.treeID
	record.treeName = record.snapshot.treeName or record.treeName
	record.treeDescription = record.snapshot.treeDescription or record.treeDescription
	record.updatedAt = os.time()

	registry.drafts[key] = record
	SaveRegistry(registry)

	return true, record.snapshot, BuildMetadata(record)
end

local function RestoreBackupAtIndex(client, kind, scope, draftID, backupIndex)
	local registry = LoadRegistry()
	local key, record = ResolveRecordKey(registry, kind, draftID)

	if (!record or record.scope ~= scope or (kind and record.kind ~= kind)) then
		return false, "Draft not found."
	end

	if (!DraftAccessScope(client, record.scope, record.ownerSteamID64)) then
		return false, "You do not have permission to restore this backup."
	end

	if (!istable(record.backups) or #record.backups == 0) then
		return false, "No backup is available for this record."
	end

	backupIndex = math.floor(tonumber(backupIndex) or 0)
	if (backupIndex < 1 or backupIndex > #record.backups) then
		return false, "Backup not found."
	end

	local originalIndex = #record.backups - backupIndex + 1
	local backup = record.backups[originalIndex]

	if (!istable(backup) or !istable(backup.snapshot)) then
		return false, "Backup snapshot is invalid."
	end

	record.backups[#record.backups + 1] = {
		timestamp = record.updatedAt or os.time(),
		label = record.label,
		treeID = record.treeID,
		treeName = record.treeName,
		treeDescription = record.treeDescription,
		snapshot = record.snapshot
	}

	while (#record.backups > MAX_BACKUPS) do
		table.remove(record.backups, 1)
	end

	record.snapshot = table.Copy(backup.snapshot)
	record.treeID = record.snapshot.treeID or record.treeID
	record.treeName = record.snapshot.treeName or record.treeName
	record.treeDescription = record.snapshot.treeDescription or record.treeDescription
	record.updatedAt = os.time()

	registry.drafts[key] = record
	SaveRegistry(registry)

	return true, record.snapshot, BuildMetadata(record)
end

net.Receive("ixUnlockEditorDraftSaveRequest", function(_, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local kind = net.ReadString()
	local silent = net.ReadBool()
	local scope = net.ReadString()
	local draftID = net.ReadString()
	local label = net.ReadString()
	local len = net.ReadUInt(32)
	local compressed = net.ReadData(len)
	local json = util.Decompress(compressed)
	local snapshot = json and util.JSONToTable(json) or nil
	local success, result = SaveRecord(client, kind, scope, draftID, label, snapshot)

	if (success) then
		if (!silent) then
			SendStatus(client, "Saved draft '" .. result.label .. "'.")
		end
	else
		SendStatus(client, result or "Failed to save draft.")
	end
end)

net.Receive("ixUnlockEditorDraftListRequest", function(_, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local kind = net.ReadString()
	local drafts = ListRecords(client, kind)
	local json = util.TableToJSON(drafts, true) or "[]"
	local compressed = util.Compress(json)

	if (!compressed) then
		SendStatus(client, "Failed to list drafts.")
		return
	end

	net.Start("ixUnlockEditorDraftBackupList")
		net.WriteUInt(#compressed, 32)
		net.WriteData(compressed, #compressed)
	net.Send(client)
end)

net.Receive("ixUnlockEditorDraftLoadRequest", function(_, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local kind = net.ReadString()
	local scope = net.ReadString()
	local draftID = net.ReadString()
	local success, result, metadata = LoadRecord(client, kind, scope, draftID)

	if (!success) then
		SendStatus(client, result or "Failed to load draft.")
		return
	end

	local json = util.TableToJSON(result, true) or "{}"
	local compressed = util.Compress(json)

	if (!compressed) then
		SendStatus(client, "Failed to encode draft.")
		return
	end

	net.Start("ixUnlockEditorDraftLoad")
		net.WriteString(metadata.kind or kind)
		net.WriteString(metadata.scope or scope)
		net.WriteString(metadata.id or draftID)
		net.WriteUInt(#compressed, 32)
		net.WriteData(compressed, #compressed)
	net.Send(client)
end)

net.Receive("ixUnlockEditorDraftRenameRequest", function(_, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local kind = net.ReadString()
	local scope = net.ReadString()
	local draftID = net.ReadString()
	local newLabel = net.ReadString()
	local success, result = RenameRecord(client, kind, scope, draftID, newLabel)

	if (success) then
		SendStatus(client, "Renamed record to '" .. (result.label or newLabel) .. "'.")
	else
		SendStatus(client, result or "Failed to rename record.")
	end
end)

net.Receive("ixUnlockEditorDraftDeleteRequest", function(_, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local kind = net.ReadString()
	local scope = net.ReadString()
	local draftID = net.ReadString()
	local success, result = DeleteRecord(client, kind, scope, draftID)

	if (success) then
		SendStatus(client, "Deleted record '" .. tostring(draftID) .. "'.")
	else
		SendStatus(client, result or "Failed to delete record.")
	end
end)

net.Receive("ixUnlockEditorDraftRestoreRequest", function(_, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local kind = net.ReadString()
	local scope = net.ReadString()
	local draftID = net.ReadString()
	local success, snapshot, metadata = RestoreLatestBackup(client, kind, scope, draftID)

	if (!success) then
		SendStatus(client, snapshot or "Failed to restore backup.")
		return
	end

	local json = util.TableToJSON(snapshot, true) or "{}"
	local compressed = util.Compress(json)

	if (!compressed) then
		SendStatus(client, "Failed to encode restored backup.")
		return
	end

	net.Start("ixUnlockEditorDraftLoad")
		net.WriteString(metadata.kind or kind)
		net.WriteString(metadata.scope or scope)
		net.WriteString(metadata.id or draftID)
		net.WriteUInt(#compressed, 32)
		net.WriteData(compressed, #compressed)
	net.Send(client)
	SendStatus(client, "Restored latest backup for '" .. (metadata.label or draftID) .. "'.")
end)

net.Receive("ixUnlockEditorDraftBackupListRequest", function(_, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local kind = net.ReadString()
	local scope = net.ReadString()
	local draftID = net.ReadString()
	local registry = LoadRegistry()
	local key, record = ResolveRecordKey(registry, kind, draftID)

	if (!record or record.scope ~= scope or (kind and record.kind ~= kind)) then
		SendStatus(client, "Draft not found.")
		return
	end

	if (!DraftAccessScope(client, record.scope, record.ownerSteamID64)) then
		SendStatus(client, "You do not have permission to inspect this backup history.")
		return
	end

	local backups = BuildBackupList(record)
	local json = util.TableToJSON(backups, true) or "[]"
	local compressed = util.Compress(json)

	if (!compressed) then
		SendStatus(client, "Failed to list backups.")
		return
	end

	net.Start("ixUnlockEditorDraftList")
		net.WriteUInt(#compressed, 32)
		net.WriteData(compressed, #compressed)
	net.Send(client)
end)

net.Receive("ixUnlockEditorDraftRestoreBackupRequest", function(_, client)
	if (!IsValid(client) or !client:IsAdmin()) then return end

	local kind = net.ReadString()
	local scope = net.ReadString()
	local draftID = net.ReadString()
	local backupIndex = net.ReadUInt(16)
	local success, snapshot, metadata = RestoreBackupAtIndex(client, kind, scope, draftID, backupIndex)

	if (!success) then
		SendStatus(client, snapshot or "Failed to restore backup.")
		return
	end

	local json = util.TableToJSON(snapshot, true) or "{}"
	local compressed = util.Compress(json)

	if (!compressed) then
		SendStatus(client, "Failed to encode restored backup.")
		return
	end

	net.Start("ixUnlockEditorDraftLoad")
		net.WriteString(metadata.kind or kind)
		net.WriteString(metadata.scope or scope)
		net.WriteString(metadata.id or draftID)
		net.WriteUInt(#compressed, 32)
		net.WriteData(compressed, #compressed)
	net.Send(client)
	SendStatus(client, "Restored backup #" .. tostring(backupIndex) .. " for '" .. (metadata.label or draftID) .. "'.")
end)
