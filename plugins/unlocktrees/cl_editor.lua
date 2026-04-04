-- cl_editor.lua
-- Admin-only visual tree editor for authoring unlock trees.

local THEME = {
	background = Color(10, 10, 10, 245),
	frame = Color(191, 148, 53, 220),
	frameSoft = Color(191, 148, 53, 120),
	text = Color(235, 235, 235, 245),
	textMuted = Color(205, 205, 205, 140),
	accent = Color(191, 148, 53, 255),
	accentSoft = Color(191, 148, 53, 220),
	danger = Color(180, 60, 60, 255),
	ready = Color(60, 170, 90, 255),
	buttonBg = Color(16, 16, 16, 220),
	buttonBgHover = Color(26, 26, 26, 230),

	editorNode = Color(191, 148, 53, 200),
	editorNodeSelected = Color(235, 200, 80, 255),
	editorEdge = Color(191, 148, 53, 140),
	editorGrid = Color(22, 22, 22, 150),
	inspectorBg = Color(12, 12, 12, 250)
}

local GRID_SNAP = 20
local NODE_SIZE = 72
local MIN_ZOOM = 0.3
local MAX_ZOOM = 2.5
local ZOOM_STEP = 0.1

local function Scale(value)
	return math.max(1, math.Round(value * (ScrH() / 900)))
end

local function CreateEditorFonts()
	surface.CreateFont("ixUnlockEditorTitle", {
		font = "Roboto",
		size = Scale(16),
		weight = 700,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixUnlockEditorLabel", {
		font = "Roboto",
		size = Scale(11),
		weight = 500,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixUnlockEditorSmall", {
		font = "Roboto",
		size = Scale(10),
		weight = 400,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixUnlockEditorNode", {
		font = "Roboto",
		size = Scale(10),
		weight = 600,
		extended = true,
		antialias = true
	})
end

CreateEditorFonts()

hook.Add("OnScreenSizeChanged", "ixUnlockEditorFonts", function()
	CreateEditorFonts()
end)

-- ─────────────────────────────────────────────
-- Editor State
-- ─────────────────────────────────────────────

-- Working copy of a tree being edited (not registered until saved)
local editorState = {
	treeID = "",
	treeName = "",
	treeDescription = "",
	nodes = {},       -- nodeID -> {id, name, description, icon, position, cost, ...}
	edges = {},       -- {{from, to}, ...}
	nextNodeIndex = 1,
	selectedNode = nil,
	selectedNodes = {},
	connectingFrom = nil, -- when in connection mode, the source node
	mode = "select",      -- "select", "connect", "delete"
	undoStack = {},
	redoStack = {},
	clipboard = nil,
	isRestoring = false,
	dirty = false,
	lastSavedAt = 0,
	lastBackupAt = 0
}

local function ResetEditorState()
	editorState.treeID = ""
	editorState.treeName = "New Tree"
	editorState.treeDescription = ""
	editorState.nodes = {}
	editorState.edges = {}
	editorState.nextNodeIndex = 1
	editorState.selectedNode = nil
	editorState.selectedNodes = {}
	editorState.connectingFrom = nil
	editorState.mode = "select"
	editorState.undoStack = {}
	editorState.redoStack = {}
	editorState.clipboard = nil
	editorState.isRestoring = false
	editorState.dirty = false
	editorState.lastSavedAt = 0
	editorState.lastBackupAt = 0
end

local function SnapToGrid(value)
	return math.Round(value / GRID_SNAP) * GRID_SNAP
end

local function IsTextInputFocused()
	local focus = vgui.GetKeyboardFocus()

	if (!IsValid(focus)) then return false end

	if (focus.IsTextEntry and focus:IsTextEntry()) then return true end

	local className = focus.GetClassName and focus:GetClassName() or ""

	return (className == "DTextEntry" or className == "DNumberWang")
end

local function GetSelectedNodeIDs()
	local nodeIDs = {}

	for nodeID in pairs(editorState.selectedNodes) do
		nodeIDs[#nodeIDs + 1] = nodeID
	end

	table.sort(nodeIDs)
	return nodeIDs
end

local function GetFirstSelectedNodeID()
	for nodeID in pairs(editorState.selectedNodes) do
		return nodeID
	end

	return nil
end

local function SyncPrimarySelection(preferredID)
	local primary = preferredID

	if (primary and !editorState.selectedNodes[primary]) then
		primary = nil
	end

	if (!primary) then
		primary = GetFirstSelectedNodeID()
	end

	editorState.selectedNode = primary
	hook.Run("UnlockEditorNodeSelected", primary)
end

local function ClearSelection()
	editorState.selectedNodes = {}
	editorState.selectedNode = nil
	hook.Run("UnlockEditorNodeSelected", nil)
end

local function SetSelection(nodeIDs, preferredID)
	editorState.selectedNodes = {}

	for _, nodeID in ipairs(nodeIDs or {}) do
		if (editorState.nodes[nodeID]) then
			editorState.selectedNodes[nodeID] = true
		end
	end

	SyncPrimarySelection(preferredID)
end

local function AddToSelection(nodeID)
	if (!editorState.nodes[nodeID]) then return end
	editorState.selectedNodes[nodeID] = true
	SyncPrimarySelection(nodeID)
end

local function ToggleSelection(nodeID)
	if (!editorState.nodes[nodeID]) then return end

	if (editorState.selectedNodes[nodeID]) then
		editorState.selectedNodes[nodeID] = nil
		SyncPrimarySelection(editorState.selectedNode == nodeID and nil or editorState.selectedNode)
	else
		editorState.selectedNodes[nodeID] = true
		SyncPrimarySelection(nodeID)
	end
end

local function SelectionCount()
	local count = 0

	for _ in pairs(editorState.selectedNodes) do
		count = count + 1
	end

	return count
end

local function SelectionContains(nodeID)
	return editorState.selectedNodes[nodeID] == true
end

local function GetUniqueNodeID(baseID)
	local base = tostring(baseID or "node")
	base = string.lower(base:gsub("[^%w_]+", "_"))
	base = base:gsub("_+", "_")
	base = base:gsub("^_+", "")
	base = base:gsub("_+$", "")

	if (base == "") then
		base = "node"
	end

	local candidate

	repeat
		candidate = base .. "_" .. editorState.nextNodeIndex
		editorState.nextNodeIndex = editorState.nextNodeIndex + 1
	until (!editorState.nodes[candidate])

	return candidate
end

local function GetSelectionCenter(nodeIDs)
local sumX, sumY, count = 0, 0, 0

for _, nodeID in ipairs(nodeIDs) do
local node = editorState.nodes[nodeID]

if (node and node.position) then
sumX = sumX + node.position.x + (NODE_SIZE * 0.5)
sumY = sumY + node.position.y + (NODE_SIZE * 0.5)
count = count + 1
end
end

if (count == 0) then
return 0, 0
end

return sumX / count, sumY / count
end

local function GetCanvasCursorPosition(canvas)
if (!IsValid(canvas)) then
return 0, 0
end

local mx, my = gui.MousePos()
local cx, cy = canvas:ScreenToCanvas(mx, my)

return cx, cy
end

local function FormatTimestamp(timeValue)
	if (!timeValue) then return "-" end
	return os.date("%Y-%m-%d %H:%M", timeValue)
end

local function MakeDraftID(label)
	local id = tostring(label or "draft")
	id = string.lower(id:gsub("[^%w_%-%s]+", "_"))
	id = id:gsub("%s+", "_")
	id = id:gsub("_+", "_")
	id = id:gsub("^_+", "")
	id = id:gsub("_+$", "")

	if (id == "") then
		id = "draft"
	end

	return string.sub(id, 1, 64)
end

-- ─────────────────────────────────────────────
-- Editor Canvas
-- ─────────────────────────────────────────────

local iconCache = {}
local function GetNodeIcon(iconPath)
	if (!iconPath or string.Trim(iconPath) == "") then return nil end
	if (iconCache[iconPath]) then return iconCache[iconPath] end
	
	local mat = Material(iconPath, "noclamp smooth")
	iconCache[iconPath] = mat
	return mat
end

local CANVAS = {}

function CANVAS:Init()
	self.offsetX = 0
	self.offsetY = 0
	self.zoom = 1.0
	self.dragging = false
	self.marqueeSelecting = false
	self.dragStartX = 0
	self.dragStartY = 0
	self.dragStartOffX = 0
	self.dragStartOffY = 0
	self.marqueeStartX = 0
	self.marqueeStartY = 0
	self.marqueeEndX = 0
	self.marqueeEndY = 0
	self.marqueeAdditive = false

	self.draggingNode = nil
	self.nodeDragOffX = 0
	self.nodeDragOffY = 0

	self:SetMouseInputEnabled(true)
end

--- Convert screen coordinates to canvas (world) coordinates.
function CANVAS:ScreenToCanvas(screenX, screenY)
	local lx, ly = self:ScreenToLocal(screenX, screenY)
	local canvasX = (lx - self.offsetX) / self.zoom
	local canvasY = (ly - self.offsetY) / self.zoom

	return canvasX, canvasY
end

--- Convert canvas coordinates to local panel coordinates.
function CANVAS:CanvasToLocal(cx, cy)
	return cx * self.zoom + self.offsetX, cy * self.zoom + self.offsetY
end

--- Find which editor node is at a screen position, if any.
function CANVAS:HitTestNode(screenX, screenY)
	local cx, cy = self:ScreenToCanvas(screenX, screenY)
	local scaledSize = NODE_SIZE

	for nodeID, node in pairs(editorState.nodes) do
		if (cx >= node.position.x and cx <= node.position.x + scaledSize and
			cy >= node.position.y and cy <= node.position.y + scaledSize) then
			return nodeID
		end
	end

	return nil
end

function CANVAS:Paint(w, h)
	-- Background
	surface.SetDrawColor(Color(4, 4, 4, 255))
	surface.DrawRect(0, 0, w, h)

	-- Grid
	local gridSize = math.Round(GRID_SNAP * self.zoom)

	if (gridSize > 3) then
		surface.SetDrawColor(THEME.editorGrid)

		local startX = self.offsetX % gridSize
		local startY = self.offsetY % gridSize

		for x = startX, w, gridSize do
			surface.DrawLine(x, 0, x, h)
		end

		for y = startY, h, gridSize do
			surface.DrawLine(0, y, w, y)
		end
	end

	-- Edges
	local halfNode = math.Round(NODE_SIZE * self.zoom * 0.5)

	for _, edge in ipairs(editorState.edges) do
		local fromNode = editorState.nodes[edge.from]
		local toNode = editorState.nodes[edge.to]

		if (fromNode and toNode) then
			local x1, y1 = self:CanvasToLocal(fromNode.position.x + NODE_SIZE * 0.5, fromNode.position.y + NODE_SIZE * 0.5)
			local x2, y2 = self:CanvasToLocal(toNode.position.x + NODE_SIZE * 0.5, toNode.position.y + NODE_SIZE * 0.5)

			x1, y1 = math.Round(x1), math.Round(y1)
			x2, y2 = math.Round(x2), math.Round(y2)

			surface.SetDrawColor(THEME.editorEdge)
			surface.DrawLine(x1, y1, x2, y2)
			surface.DrawLine(x1 + 1, y1, x2 + 1, y2)
		end
	end

	-- Connection preview line
	if (editorState.mode == "connect" and editorState.connectingFrom) then
		local fromNode = editorState.nodes[editorState.connectingFrom]

		if (fromNode) then
			local x1, y1 = self:CanvasToLocal(fromNode.position.x + NODE_SIZE * 0.5, fromNode.position.y + NODE_SIZE * 0.5)
			local mx, my = self:ScreenToLocal(gui.MousePos())

			surface.SetDrawColor(THEME.accent)
			surface.DrawLine(math.Round(x1), math.Round(y1), mx, my)
		end
	end

	-- Nodes
	for nodeID, node in pairs(editorState.nodes) do
		local nx, ny = self:CanvasToLocal(node.position.x, node.position.y)
		local scaledSize = math.Round(NODE_SIZE * self.zoom)

		nx, ny = math.Round(nx), math.Round(ny)

		local isSelected = SelectionContains(nodeID)
		local isPrimary = (editorState.selectedNode == nodeID)
		local border = isPrimary and THEME.editorNodeSelected or (isSelected and THEME.accentSoft or THEME.editorNode)
		local bg = THEME.buttonBg

		-- Background
		surface.SetDrawColor(bg)
		surface.DrawRect(nx, ny, scaledSize, scaledSize)

		-- Border
		surface.SetDrawColor(border)
		surface.DrawOutlinedRect(nx, ny, scaledSize, scaledSize)

		if (isSelected) then
			surface.DrawOutlinedRect(nx + 1, ny + 1, scaledSize - 2, scaledSize - 2)
		end

		-- Icon
		if (node.icon and node.icon != "") then
			local iconMat = GetNodeIcon(node.icon)
			if (iconMat and !iconMat:IsError()) then
				surface.SetMaterial(iconMat)
				surface.SetDrawColor(Color(255, 255, 255, 255))
				
				local iconMargin = 2
				local iconSize = scaledSize - (iconMargin * 2)
				surface.DrawTexturedRect(nx + iconMargin, ny + iconMargin, iconSize, iconSize)
			end
		end

		-- Name (below the node)
		local textY = ny + scaledSize + Scale(4)
		draw.SimpleText(node.name or nodeID, "ixUnlockEditorNode", nx + scaledSize * 0.5, textY, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

		-- Node ID below the name
		draw.SimpleText(nodeID, "ixUnlockEditorSmall", nx + scaledSize * 0.5, textY + Scale(14), THEME.textMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end

	if (self.marqueeSelecting) then
		local sx1, sy1 = self:ScreenToLocal(self.marqueeStartX, self.marqueeStartY)
		local sx2, sy2 = self:ScreenToLocal(self.marqueeEndX, self.marqueeEndY)
		local left, right = math.min(sx1, sx2), math.max(sx1, sx2)
		local top, bottom = math.min(sy1, sy2), math.max(sy1, sy2)

		surface.SetDrawColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 40))
		surface.DrawRect(left, top, right - left, bottom - top)
		surface.SetDrawColor(THEME.accentSoft)
		surface.DrawOutlinedRect(left, top, right - left, bottom - top)
	end

	-- Mode indicator
	local modeText = "MODE: " .. editorState.mode:upper()

	if (editorState.mode == "connect" and editorState.connectingFrom) then
		modeText = modeText .. " (from: " .. editorState.connectingFrom .. ")"
	end

	local selectedCount = SelectionCount()

	if (selectedCount > 0) then
		modeText = modeText .. " | SELECTED: " .. selectedCount
	end

	draw.SimpleText(modeText, "ixUnlockEditorSmall", Scale(8), h - Scale(16), THEME.accentSoft, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

function CANVAS:OnMousePressed(code)
	local mx, my = gui.MousePos()
	local hitNode = self:HitTestNode(mx, my)
	local ctrlDown = input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)

	if (code == MOUSE_LEFT) then
		if (editorState.mode == "select") then
			if (hitNode) then
				if (ctrlDown) then
					ToggleSelection(hitNode)
					return
				else
					SetSelection({hitNode}, hitNode)
				end
				local lx, ly = self:ScreenToLocal(mx, my)

				if (IsValid(ix.unlocks.editorPanel)) then
					ix.unlocks.editorPanel:PushUndoSnapshot("move_node")
				end

				self.draggingNode = hitNode
				
				local node = editorState.nodes[hitNode]
				local nx, ny = self:CanvasToLocal(node.position.x, node.position.y)
				
				self.nodeDragOffX = lx - nx
				self.nodeDragOffY = ly - ny
			else
				self.marqueeSelecting = true
				self.marqueeStartX = mx
				self.marqueeStartY = my
				self.marqueeEndX = mx
				self.marqueeEndY = my
				self.marqueeAdditive = ctrlDown
				self:MouseCapture(true)

				if (!ctrlDown) then
					ClearSelection()
				end
			end
		elseif (editorState.mode == "connect") then
			if (hitNode) then
				if (!editorState.connectingFrom) then
					editorState.connectingFrom = hitNode
				else
					if (hitNode != editorState.connectingFrom) then
						local exists = false

						for _, edge in ipairs(editorState.edges) do
							if (edge.from == editorState.connectingFrom and edge.to == hitNode) then
								exists = true
								break
							end
						end

						if (!exists) then
							if (IsValid(ix.unlocks.editorPanel)) then
								ix.unlocks.editorPanel:PushUndoSnapshot("connect_nodes")
							end

							editorState.edges[#editorState.edges + 1] = {
								from = editorState.connectingFrom,
								to = hitNode
							}
						end
					end

					editorState.connectingFrom = nil
				end
			else
				editorState.connectingFrom = nil
			end
		elseif (editorState.mode == "delete") then
			if (hitNode and IsValid(ix.unlocks.editorPanel)) then
				if (SelectionContains(hitNode)) then
					ix.unlocks.editorPanel:DeleteNodes(GetSelectedNodeIDs())
				else
					ix.unlocks.editorPanel:DeleteNodes({hitNode})
				end
			end
		end
	elseif (code == MOUSE_MIDDLE) then
		self.dragging = true
		self.dragStartX, self.dragStartY = mx, my
		self.dragStartOffX = self.offsetX
		self.dragStartOffY = self.offsetY
		self:MouseCapture(true)
	elseif (code == MOUSE_RIGHT) then
		-- Right-click: create new node at cursor or show context menu
		if (!hitNode and editorState.mode == "select") then
			if (IsValid(ix.unlocks.editorPanel)) then
				ix.unlocks.editorPanel:PushUndoSnapshot("create_node")
			end

			local cx, cy = self:ScreenToCanvas(mx, my)
			cx = SnapToGrid(cx - NODE_SIZE * 0.5)
			cy = SnapToGrid(cy - NODE_SIZE * 0.5)

			local newID = GetUniqueNodeID("node")

			editorState.nodes[newID] = {
				id = newID,
				name = "New Node",
				description = "",
				icon = "icon16/brick.png",
				position = {x = cx, y = cy},
				cost = {},
				requirements = {},
				type = "normal",
				repeatable = false,
				maxLevel = 1,
				metadata = {},
				mutuallyExclusive = {},
				category = "",
				cooldown = 0
			}

			SetSelection({newID}, newID)
		elseif (hitNode and editorState.mode == "connect") then
			-- Right-click a node in connect mode: remove edges from/to it
			if (IsValid(ix.unlocks.editorPanel)) then
				ix.unlocks.editorPanel:PushUndoSnapshot("delete_edges")
			end

			for i = #editorState.edges, 1, -1 do
				local edge = editorState.edges[i]

				if (edge.from == hitNode or edge.to == hitNode) then
					table.remove(editorState.edges, i)
				end
			end
		end
	end
end

function CANVAS:OnMouseReleased(code)
	if (code == MOUSE_LEFT) then
		if (self.marqueeSelecting) then
			self.marqueeSelecting = false
			self:MouseCapture(false)

			local startX, startY = self:ScreenToCanvas(self.marqueeStartX, self.marqueeStartY)
			local endX, endY = self:ScreenToCanvas(self.marqueeEndX, self.marqueeEndY)
			local left, right = math.min(startX, endX), math.max(startX, endX)
			local top, bottom = math.min(startY, endY), math.max(startY, endY)

			if (math.abs(right - left) < 2 and math.abs(bottom - top) < 2) then
				if (!self.marqueeAdditive) then
					ClearSelection()
				end
			else
				local nodeIDs = self.marqueeAdditive and GetSelectedNodeIDs() or {}

				for nodeID, node in pairs(editorState.nodes) do
					if (node.position.x + NODE_SIZE >= left and node.position.x <= right and node.position.y + NODE_SIZE >= top and node.position.y <= bottom) then
						nodeIDs[#nodeIDs + 1] = nodeID
					end
				end

				SetSelection(nodeIDs, #nodeIDs > 0 and nodeIDs[#nodeIDs] or nil)
			end
		end

		if (self.dragging) then
			self.dragging = false
			self:MouseCapture(false)
		end

		self.draggingNode = nil
	elseif (code == MOUSE_MIDDLE) then
		if (self.dragging) then
			self.dragging = false
			self:MouseCapture(false)
		end
	end
end

function CANVAS:Think()
	if (self.dragging) then
		local mx, my = gui.MousePos()

		self.offsetX = self.dragStartOffX + (mx - self.dragStartX)
		self.offsetY = self.dragStartOffY + (my - self.dragStartY)
	end

	if (self.marqueeSelecting) then
		self.marqueeEndX, self.marqueeEndY = gui.MousePos()
	end

	if (self.draggingNode) then
		local node = editorState.nodes[self.draggingNode]

		if (node) then
			local mx, my = gui.MousePos()
			local lx, ly = self:ScreenToLocal(mx, my)

			local cx = (lx - self.nodeDragOffX - self.offsetX) / self.zoom
			local cy = (ly - self.nodeDragOffY - self.offsetY) / self.zoom

			node.position.x = SnapToGrid(cx)
			node.position.y = SnapToGrid(cy)
		end
	end
end

function CANVAS:OnMouseWheeled(delta)
	local oldZoom = self.zoom

	self.zoom = math.Clamp(self.zoom + delta * ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)

	local mx, my = self:ScreenToLocal(gui.MousePos())
	local ratio = self.zoom / oldZoom

	self.offsetX = mx - (mx - self.offsetX) * ratio
	self.offsetY = my - (my - self.offsetY) * ratio
end

function CANVAS:CenterView()
	if (table.IsEmpty(editorState.nodes)) then
		self.offsetX = self:GetWide() * 0.5
		self.offsetY = self:GetTall() * 0.5
		return
	end

	local sumX, sumY, count = 0, 0, 0

	for _, node in pairs(editorState.nodes) do
		sumX = sumX + node.position.x
		sumY = sumY + node.position.y
		count = count + 1
	end

	local avgX = sumX / count
	local avgY = sumY / count

	self.offsetX = (self:GetWide() * 0.5) - (avgX * self.zoom) - (NODE_SIZE * self.zoom * 0.5)
	self.offsetY = (self:GetTall() * 0.5) - (avgY * self.zoom) - (NODE_SIZE * self.zoom * 0.5)
end

vgui.Register("ixUnlockEditorCanvas", CANVAS, "DPanel")

-- ─────────────────────────────────────────────
-- Inspector Panel (right sidebar for editing selected node)
-- ─────────────────────────────────────────────

local INSPECTOR = {}

function INSPECTOR:Init()
	self.fields = {}
	self:DockPadding(Scale(8), Scale(8), Scale(8), Scale(8))

	hook.Add("UnlockEditorNodeSelected", "ixUnlockInspector_" .. tostring(self), function(nodeID)
		if (!IsValid(self)) then return end

		self:LoadNode(nodeID)
	end)
end

function INSPECTOR:Paint(w, h)
	surface.SetDrawColor(THEME.inspectorBg)
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(THEME.frameSoft)
	surface.DrawLine(0, 0, 0, h)

	if (!editorState.selectedNode) then
		draw.SimpleText("No node selected", "ixUnlockEditorLabel", w * 0.5, h * 0.5, THEME.textMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

function INSPECTOR:ClearFields()
	for _, panel in pairs(self.fields) do
		if (IsValid(panel)) then
			panel:Remove()
		end
	end

	self.fields = {}
end

function INSPECTOR:AddLabel(text)
	local lbl = vgui.Create("DLabel", self)
	lbl:Dock(TOP)
	lbl:SetFont("ixUnlockEditorLabel")
	lbl:SetTextColor(THEME.accentSoft)
	lbl:SetText(text)
	lbl:DockMargin(0, Scale(8), 0, Scale(2))
	lbl:SizeToContents()
	self.fields[#self.fields + 1] = lbl

	return lbl
end

function INSPECTOR:AddTextEntry(label, value, onChange)
	self:AddLabel(label)

	local entry = vgui.Create("DTextEntry", self)
	entry:Dock(TOP)
	entry:SetFont("ixUnlockEditorLabel")
	entry:SetText(value or "")
	entry:SetTextColor(THEME.text)
	entry:SetCursorColor(THEME.accent)
	entry:SetHighlightColor(Color(191, 148, 53, 80))
	entry:SetTall(Scale(24))
	entry:DockMargin(0, 0, 0, Scale(2))
	entry.Paint = function(_, w, h)
		surface.SetDrawColor(THEME.buttonBg)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawOutlinedRect(0, 0, w, h)
		entry:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
	end
	entry.OnChange = function()
		if (editorState.isRestoring) then return end

		if (IsValid(ix.unlocks.editorPanel)) then
			ix.unlocks.editorPanel:PushUndoSnapshot("edit_node")
		end

		if (onChange) then
			onChange(entry:GetValue())
		end
	end

	self.fields[#self.fields + 1] = entry

	return entry
end

function INSPECTOR:AddNumberEntry(label, value, onChange)
	self:AddLabel(label)

	local entry = vgui.Create("DNumberWang", self)
	entry:Dock(TOP)
	entry:SetFont("ixUnlockEditorLabel")
	entry:SetValue(value or 0)
	entry:SetTextColor(THEME.text)
	entry:SetTall(Scale(24))
	entry:SetMin(0)
	entry:SetMax(99999)
	entry:DockMargin(0, 0, 0, Scale(2))
	entry.Paint = function(_, w, h)
		surface.SetDrawColor(THEME.buttonBg)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawOutlinedRect(0, 0, w, h)
		entry:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
	end
	entry.OnValueChanged = function(_, val)
		if (editorState.isRestoring) then return end

		if (IsValid(ix.unlocks.editorPanel)) then
			ix.unlocks.editorPanel:PushUndoSnapshot("edit_node")
		end

		if (onChange) then
			onChange(tonumber(val) or 0)
		end
	end

	self.fields[#self.fields + 1] = entry

	return entry
end

function INSPECTOR:AddCheckbox(label, value, onChange)
	local row = vgui.Create("DPanel", self)
	row:Dock(TOP)
	row:SetTall(Scale(22))
	row:DockMargin(0, Scale(4), 0, Scale(2))
	row.Paint = function() end

	local cb = vgui.Create("DCheckBox", row)
	cb:Dock(LEFT)
	cb:SetWide(Scale(18))
	cb:SetValue(value or false)
	cb.OnChange = function(_, val)
		if (editorState.isRestoring) then return end

		if (IsValid(ix.unlocks.editorPanel)) then
			ix.unlocks.editorPanel:PushUndoSnapshot("edit_node")
		end

		if (onChange) then
			onChange(val)
		end
	end

	local lbl = vgui.Create("DLabel", row)
	lbl:Dock(FILL)
	lbl:SetFont("ixUnlockEditorLabel")
	lbl:SetTextColor(THEME.text)
	lbl:SetText("  " .. label)
	lbl:DockMargin(Scale(4), 0, 0, 0)

	self.fields[#self.fields + 1] = row

	return cb
end

function INSPECTOR:LoadNode(nodeID)
	self:ClearFields()

	if (!nodeID or !editorState.nodes[nodeID]) then return end

	local node = editorState.nodes[nodeID]

	self:AddLabel("NODE INSPECTOR")

	-- ID (read-only display)
	self:AddLabel("ID: " .. nodeID)

	-- Name
	self:AddTextEntry("Name", node.name, function(val)
		node.name = val
	end)

	-- Description
	self:AddTextEntry("Description", node.description, function(val)
		node.description = val
	end)

	-- Icon
	self:AddLabel("Icon (with path resolver)")
	local iconRow = vgui.Create("DPanel", self)
	iconRow:Dock(TOP)
	iconRow:SetTall(Scale(24))
	iconRow:DockMargin(0, 0, 0, Scale(2))
	iconRow.Paint = function() end

	local iconEntry = vgui.Create("DTextEntry", iconRow)
	iconEntry:Dock(FILL)
	iconEntry:SetFont("ixUnlockEditorLabel")
	iconEntry:SetText(node.icon or "")
	iconEntry:SetTextColor(THEME.text)
	iconEntry:SetCursorColor(THEME.accent)
	iconEntry.Paint = function(_, w, h)
		surface.SetDrawColor(THEME.buttonBg)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawOutlinedRect(0, 0, w, h)
		iconEntry:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
	end
	iconEntry.OnChange = function()
		if (editorState.isRestoring) then return end
		if (IsValid(ix.unlocks.editorPanel)) then
			ix.unlocks.editorPanel:PushUndoSnapshot("edit_node")
		end
		node.icon = iconEntry:GetValue()
	end
	
	local iconBtn = vgui.Create("ixUnlockToolbarButton", iconRow)
	iconBtn:SetLabel("...")
	iconBtn:Dock(RIGHT)
	iconBtn:SetWide(Scale(24))
	iconBtn:DockMargin(Scale(4), 0, 0, 0)
	iconBtn.DoClick = function()
		if (IsValid(ix.unlocks.editorPanel)) then
			ix.unlocks.editorPanel:OpenIconBrowser(function(selectedIcon)
				if (IsValid(iconEntry)) then
					iconEntry:SetText(selectedIcon)
					iconEntry:OnChange()
				end
			end)
		end
	end

	self.fields[#self.fields + 1] = iconRow
	self.fields[#self.fields + 1] = iconEntry
	self.fields[#self.fields + 1] = iconBtn

	-- Position (read-only)
	self:AddLabel("Position: " .. node.position.x .. ", " .. node.position.y)

	-- Cost: money
	local moneyCost = node.cost and node.cost.money or 0

	self:AddNumberEntry("Cost (money)", moneyCost, function(val)
		if (!node.cost) then node.cost = {} end

		node.cost.money = val
	end)

	-- Type
	self:AddCheckbox("Repeatable", node.repeatable, function(val)
		node.repeatable = val
	end)

	-- Max level
	self:AddNumberEntry("Max Level", node.maxLevel, function(val)
		node.maxLevel = math.max(1, val)
	end)

	-- Category
	self:AddTextEntry("Category", node.category or "", function(val)
		node.category = val
	end)

	-- Cooldown
	self:AddNumberEntry("Cooldown (sec)", node.cooldown or 0, function(val)
		node.cooldown = val
	end)

	-- Hidden note: runtime hidden functions can't be edited here, but a static flag can be toggled
	self:AddCheckbox("Hidden", node.hidden or false, function(val)
		node.hidden = val
	end)

	-- Refundable (default true)
	self:AddCheckbox("Refundable", node.refundable != false, function(val)
		node.refundable = val
	end)
end

function INSPECTOR:OnRemove()
	hook.Remove("UnlockEditorNodeSelected", "ixUnlockInspector_" .. tostring(self))
end

vgui.Register("ixUnlockEditorInspector", INSPECTOR, "DScrollPanel")

-- ─────────────────────────────────────────────
-- Main Editor Frame
-- ─────────────────────────────────────────────

-- A whitelist of folders to scan when browsing for icons.
ix.unlocks.iconWhitelistFolders = {
	"materials/icon16",
	"materials/vgui/icons",
	"materials/jedi",
	"materials/sith"
}

local EDITOR = {}

function EDITOR:Init()
	local scrW, scrH = ScrW(), ScrH()
	local w = math.Round(scrW * 0.85)
	local h = math.Round(scrH * 0.85)

	self:SetSize(w, h)
	self:Center()
	self:SetTitle("")
	self:ShowCloseButton(false)
	self:SetDraggable(true)
	self:MakePopup()
	self.closePromptShown = false

	ResetEditorState()

	self:BuildToolbar()
	self:BuildBody()
end

function EDITOR:RequestClose()
	if (!editorState.dirty) then
		self:Remove()
		return
	end

	if (self.closePromptShown) then return end
	self.closePromptShown = true

	Derma_Query("You have unsaved changes. Close the editor anyway?", "Unsaved Changes", "Close", function()
		if (IsValid(self)) then
			self:Remove()
		end
	end, "Cancel", function()
		if (IsValid(self)) then
			self.closePromptShown = false
		end
	end)
end

function EDITOR:OpenIconBrowser(callback)
	local frame = vgui.Create("DFrame")
	frame:SetSize(Scale(400), Scale(500))
	frame:Center()
	frame:SetTitle("Icon Browser")
	frame:MakePopup()

	local search = vgui.Create("DTextEntry", frame)
	search:Dock(TOP)
	search:DockMargin(Scale(8), Scale(8), Scale(8), Scale(4))
	search:SetPlaceholderText("Search...")

	local scroll = vgui.Create("DScrollPanel", frame)
	scroll:Dock(FILL)
	scroll:DockMargin(Scale(8), 4, Scale(8), Scale(8))

	local grid = vgui.Create("DIconLayout", scroll)
	grid:Dock(FILL)
	grid:SetSpaceY(Scale(4))
	grid:SetSpaceX(Scale(4))

	local allIcons = {}

	for _, folder in ipairs(ix.unlocks.iconWhitelistFolders or {}) do
		for _, ext in ipairs({"*.png", "*.jpg", "*.vmt"}) do
			local searchFolder = string.TrimRight(folder, "/") .. "/" .. ext
			local files, _ = file.Find(searchFolder, "GAME")
			
			for _, f in ipairs(files or {}) do
				local cleanFolder = string.gsub(folder, "^materials/", "")
				allIcons[#allIcons + 1] = cleanFolder .. "/" .. f
			end
		end
	end

	local function Populate(query)
		grid:Clear()
		local q = string.lower(query or "")

		for _, path in ipairs(allIcons) do
			if (q == "" or string.find(string.lower(path), q, 1, true)) then
				local btn = grid:Add("DImageButton")
				btn:SetSize(Scale(32), Scale(32))
				btn:SetImage(path)
				btn:SetTooltip(path)
				btn.DoClick = function()
					if (callback) then callback(path) end
					frame:Remove()
				end
			end
		end
	end

	Populate("")

	search.OnChange = function()
		Populate(search:GetValue())
	end
end

function EDITOR:BuildToolbar()
	self.toolbar = vgui.Create("DPanel", self)
	self.toolbar:Dock(TOP)
	self.toolbar:SetTall(Scale(38))
	self.toolbar.Paint = function(_, w, h)
		surface.SetDrawColor(THEME.background)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawLine(0, h - 1, w, h - 1)
	end

	local margin = Scale(6)
	local btnW = Scale(70)
	local btnH = Scale(26)

	-- Mode buttons
	local modes = {
		{"SELECT", "select"},
		{"CONNECT", "connect"},
		{"DELETE", "delete"}
	}

	for _, modeInfo in ipairs(modes) do
		local btn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
		btn:SetLabel(modeInfo[1])
		btn:Dock(LEFT)
		btn:SetWide(btnW)
		btn:DockMargin(margin, margin, 0, margin)
		btn.DoClick = function()
			editorState.mode = modeInfo[2]
			editorState.connectingFrom = nil
		end
	end

	-- Spacer
	local spacer = vgui.Create("DPanel", self.toolbar)
	spacer:Dock(LEFT)
	spacer:SetWide(Scale(20))
	spacer.Paint = function() end

	-- Tree ID entry
	local treeIDLabel = vgui.Create("DLabel", self.toolbar)
	treeIDLabel:Dock(LEFT)
	treeIDLabel:SetFont("ixUnlockEditorLabel")
	treeIDLabel:SetTextColor(THEME.textMuted)
	treeIDLabel:SetText("Tree ID:")
	treeIDLabel:SizeToContents()
	treeIDLabel:DockMargin(margin, margin, Scale(4), margin)

	local treeIDEntry = vgui.Create("DTextEntry", self.toolbar)
	treeIDEntry:Dock(LEFT)
	treeIDEntry:SetWide(Scale(120))
	treeIDEntry:SetFont("ixUnlockEditorLabel")
	treeIDEntry:SetText(editorState.treeID)
	treeIDEntry:SetTextColor(THEME.text)
	treeIDEntry:SetCursorColor(THEME.accent)
	treeIDEntry:DockMargin(0, margin, margin, margin)
	treeIDEntry.Paint = function(_, w, h)
		surface.SetDrawColor(THEME.buttonBg)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawOutlinedRect(0, 0, w, h)
		treeIDEntry:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
	end
	treeIDEntry.OnChange = function()
		editorState.treeID = treeIDEntry:GetValue()
	end

	self.treeIDEntry = treeIDEntry

	-- Right-side buttons
	local closeBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	closeBtn:SetLabel("CLOSE")
	closeBtn:Dock(RIGHT)
	closeBtn:SetWide(btnW)
	closeBtn:DockMargin(0, margin, margin, margin)
	closeBtn.DoClick = function()
		self:RequestClose()
	end

	-- Export Code button
	local exportBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	exportBtn:SetLabel("CODE")
	exportBtn:Dock(RIGHT)
	exportBtn:SetWide(btnW)
	exportBtn:DockMargin(0, margin, Scale(4), margin)
	exportBtn.DoClick = function()
		self:ExportTree()
	end
	
	-- Export Layout button
	local layoutExpBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	layoutExpBtn:SetLabel("LAYOUT")
	layoutExpBtn:Dock(RIGHT)
	layoutExpBtn:SetWide(btnW)
	layoutExpBtn:DockMargin(0, margin, Scale(4), margin)
	layoutExpBtn.DoClick = function()
		self:ExportLayout()
	end

	-- Import button
	local importBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	importBtn:SetLabel("IMPORT")
	importBtn:Dock(RIGHT)
	importBtn:SetWide(btnW)
	importBtn:DockMargin(0, margin, Scale(4), margin)
	importBtn.DoClick = function()
		self:ImportTree()
	end

	-- Load existing tree button
	local loadBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	loadBtn:SetLabel("LOAD")
	loadBtn:Dock(RIGHT)
	loadBtn:SetWide(btnW)
	loadBtn:DockMargin(0, margin, Scale(4), margin)
	loadBtn.DoClick = function()
		self:ShowLoadMenu()
	end

	local draftsBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	draftsBtn:SetLabel("DRAFTS")
	draftsBtn:Dock(RIGHT)
	draftsBtn:SetWide(btnW)
	draftsBtn:DockMargin(0, margin, Scale(4), margin)
	draftsBtn.DoClick = function()
		self:OpenDraftBrowser()
	end

	local saveDraftBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	saveDraftBtn:SetLabel("SAVE DRAFT")
	saveDraftBtn:Dock(RIGHT)
	saveDraftBtn:SetWide(Scale(90))
	saveDraftBtn:DockMargin(0, margin, Scale(4), margin)
	saveDraftBtn.DoClick = function()
		self:OpenDraftSaveDialog()
	end

	local presetsBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	presetsBtn:SetLabel("PRESETS")
	presetsBtn:Dock(RIGHT)
	presetsBtn:SetWide(btnW)
	presetsBtn:DockMargin(0, margin, Scale(4), margin)
	presetsBtn.DoClick = function()
		self:OpenPresetBrowser()
	end

	local savePresetBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	savePresetBtn:SetLabel("SAVE PRESET")
	savePresetBtn:Dock(RIGHT)
	savePresetBtn:SetWide(Scale(90))
	savePresetBtn:DockMargin(0, margin, Scale(4), margin)
	savePresetBtn.DoClick = function()
		self:OpenPresetSaveDialog()
	end

	-- Auto-layout button
	local layoutBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	layoutBtn:SetLabel("AUTO LAYOUT")
	layoutBtn:Dock(RIGHT)
	layoutBtn:SetWide(Scale(90))
	layoutBtn:DockMargin(0, margin, Scale(4), margin)
	layoutBtn.DoClick = function()
		self:AutoLayout()
	end

	local actionBtnW = Scale(60)

	local pasteBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	pasteBtn:SetLabel("PASTE")
	pasteBtn:Dock(RIGHT)
	pasteBtn:SetWide(actionBtnW)
	pasteBtn:DockMargin(0, margin, Scale(4), margin)
	pasteBtn.DoClick = function()
		self:PasteClipboard()
	end

	local cutBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	cutBtn:SetLabel("CUT")
	cutBtn:Dock(RIGHT)
	cutBtn:SetWide(actionBtnW)
	cutBtn:DockMargin(0, margin, Scale(4), margin)
	cutBtn.DoClick = function()
		self:CutSelection()
	end

	local copyBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	copyBtn:SetLabel("COPY")
	copyBtn:Dock(RIGHT)
	copyBtn:SetWide(actionBtnW)
	copyBtn:DockMargin(0, margin, Scale(4), margin)
	copyBtn.DoClick = function()
		self:CopySelection()
	end

	local redoBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	redoBtn:SetLabel("REDO")
	redoBtn:Dock(RIGHT)
	redoBtn:SetWide(actionBtnW)
	redoBtn:DockMargin(0, margin, Scale(4), margin)
	redoBtn.DoClick = function()
		self:Redo()
	end

	local undoBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	undoBtn:SetLabel("UNDO")
	undoBtn:Dock(RIGHT)
	undoBtn:SetWide(actionBtnW)
	undoBtn:DockMargin(0, margin, Scale(4), margin)
	undoBtn.DoClick = function()
		self:Undo()
	end
end

function EDITOR:BuildBody()
	-- Right inspector panel
	self.inspector = vgui.Create("ixUnlockEditorInspector", self)
	self.inspector:Dock(RIGHT)
	self.inspector:SetWide(Scale(240))

	-- Main canvas
	self.canvas = vgui.Create("ixUnlockEditorCanvas", self)
	self.canvas:Dock(FILL)
	self.canvas:DockMargin(Scale(2), Scale(2), Scale(2), Scale(2))

	timer.Simple(0, function()
		if (IsValid(self) and IsValid(self.canvas)) then
			self.canvas:CenterView()
		end
	end)
end

function EDITOR:CreateSnapshot()
	return {
		treeID = editorState.treeID,
		treeName = editorState.treeName,
		treeDescription = editorState.treeDescription,
		nodes = table.Copy(editorState.nodes),
		edges = table.Copy(editorState.edges),
		nextNodeIndex = editorState.nextNodeIndex,
		selectedNode = editorState.selectedNode,
		selectedNodes = table.Copy(editorState.selectedNodes),
		mode = editorState.mode,
		connectingFrom = editorState.connectingFrom
	}
end

function EDITOR:ApplySnapshot(snapshot)
	if (!snapshot) then return end

	editorState.isRestoring = true

	editorState.treeID = snapshot.treeID or ""
	editorState.treeName = snapshot.treeName or "New Tree"
	editorState.treeDescription = snapshot.treeDescription or ""
	editorState.nodes = table.Copy(snapshot.nodes or {})
	editorState.edges = table.Copy(snapshot.edges or {})
	editorState.nextNodeIndex = snapshot.nextNodeIndex or 1
	editorState.mode = snapshot.mode or "select"
	editorState.connectingFrom = snapshot.connectingFrom
	editorState.selectedNodes = table.Copy(snapshot.selectedNodes or {})
	editorState.selectedNode = snapshot.selectedNode

	if (editorState.selectedNode and !editorState.selectedNodes[editorState.selectedNode]) then
		editorState.selectedNode = GetFirstSelectedNodeID()
	end

	if (IsValid(self.treeIDEntry)) then
		self.treeIDEntry:SetText(editorState.treeID)
	end

	if (!editorState.selectedNode) then
		SyncPrimarySelection(GetFirstSelectedNodeID())
	else
		SyncPrimarySelection(editorState.selectedNode)
	end

	editorState.isRestoring = false

	if (IsValid(self.inspector)) then
		self.inspector:LoadNode(editorState.selectedNode)
	end
end

function EDITOR:PushUndoSnapshot(reason)
	if (editorState.isRestoring) then return end

	local snapshot = self:CreateSnapshot()
	snapshot.reason = reason

	editorState.undoStack[#editorState.undoStack + 1] = snapshot

	if (#editorState.undoStack > 50) then
		table.remove(editorState.undoStack, 1)
	end

	editorState.redoStack = {}
	editorState.dirty = true

	if (IsValid(self)) then
		self:ScheduleAutoBackup()
	end
end

function EDITOR:Undo()
	if (table.IsEmpty(editorState.undoStack)) then return end

	local current = self:CreateSnapshot()
	local snapshot = table.remove(editorState.undoStack)

	editorState.redoStack[#editorState.redoStack + 1] = current
	self:ApplySnapshot(snapshot)
end

function EDITOR:Redo()
	if (table.IsEmpty(editorState.redoStack)) then return end

	local current = self:CreateSnapshot()
	local snapshot = table.remove(editorState.redoStack)

	editorState.undoStack[#editorState.undoStack + 1] = current
	self:ApplySnapshot(snapshot)
end

function EDITOR:DeleteNodes(nodeIDs)
	if (!nodeIDs or table.IsEmpty(nodeIDs)) then return end

	self:PushUndoSnapshot("delete_nodes")

	local removeSet = {}

	for _, nodeID in ipairs(nodeIDs) do
		if (editorState.nodes[nodeID]) then
			removeSet[nodeID] = true
		end
	end

	for nodeID in pairs(removeSet) do
		editorState.nodes[nodeID] = nil
	end

	for i = #editorState.edges, 1, -1 do
		local edge = editorState.edges[i]

		if (removeSet[edge.from] or removeSet[edge.to]) then
			table.remove(editorState.edges, i)
		end
	end

	for nodeID in pairs(removeSet) do
		editorState.selectedNodes[nodeID] = nil
	end

	SyncPrimarySelection(GetFirstSelectedNodeID())
end

function EDITOR:CopySelection()
	local nodeIDs = GetSelectedNodeIDs()

	if (table.IsEmpty(nodeIDs)) then return false end

	local selectedSet = {}
	local clipboardNodes = {}
	local clipboardEdges = {}

	for _, nodeID in ipairs(nodeIDs) do
		selectedSet[nodeID] = true
		clipboardNodes[nodeID] = table.Copy(editorState.nodes[nodeID])
	end

	for _, edge in ipairs(editorState.edges) do
		if (selectedSet[edge.from] and selectedSet[edge.to]) then
			clipboardEdges[#clipboardEdges + 1] = {from = edge.from, to = edge.to}
		end
	end

	local centerX, centerY = GetSelectionCenter(nodeIDs)

	editorState.clipboard = {
		nodes = clipboardNodes,
		edges = clipboardEdges,
		anchor = {x = centerX, y = centerY},
		pasteCount = 0,
		sourceIDs = nodeIDs
	}

	return true
end

function EDITOR:CutSelection()
	local nodeIDs = GetSelectedNodeIDs()

	if (table.IsEmpty(nodeIDs)) then return false end

	if (!self:CopySelection()) then return false end

	self:DeleteNodes(nodeIDs)
	return true
end

function EDITOR:PasteClipboard()
	if (!editorState.clipboard or table.IsEmpty(editorState.clipboard.nodes)) then return false end

	local clipboard = editorState.clipboard
	local targetX, targetY = GetCanvasCursorPosition(self.canvas)
	local offsetStep = GRID_SNAP * 2
	local pasteOffset = (clipboard.pasteCount or 0) * offsetStep

	self:PushUndoSnapshot("paste_nodes")

	local remap = {}
	local pastedNodeIDs = {}
	local anchor = clipboard.anchor or {x = 0, y = 0}

	for oldNodeID, node in pairs(clipboard.nodes) do
		local newNodeID = GetUniqueNodeID(oldNodeID)
		local copy = table.Copy(node)

		copy.id = newNodeID
		copy.position = copy.position or {x = 0, y = 0}
		copy.position.x = SnapToGrid(targetX + (copy.position.x - anchor.x) + pasteOffset)
		copy.position.y = SnapToGrid(targetY + (copy.position.y - anchor.y) + pasteOffset)

		editorState.nodes[newNodeID] = copy
		remap[oldNodeID] = newNodeID
		pastedNodeIDs[#pastedNodeIDs + 1] = newNodeID
	end

	for _, edge in ipairs(clipboard.edges) do
		local fromID = remap[edge.from]
		local toID = remap[edge.to]

		if (fromID and toID) then
			editorState.edges[#editorState.edges + 1] = {from = fromID, to = toID}
		end
	end

	clipboard.pasteCount = (clipboard.pasteCount or 0) + 1
	SetSelection(pastedNodeIDs, pastedNodeIDs[1])

	return true
end

function EDITOR:RotateSelection()
	local nodeIDs = GetSelectedNodeIDs()

	if (table.IsEmpty(nodeIDs)) then return false end

	self:PushUndoSnapshot("rotate_nodes")

	local cx, cy = GetSelectionCenter(nodeIDs)

	for _, nodeID in ipairs(nodeIDs) do
		local node = editorState.nodes[nodeID]

		if (node and node.position) then
			-- Get absolute geometric center of the node
			local nx = node.position.x + (NODE_SIZE * 0.5)
			local ny = node.position.y + (NODE_SIZE * 0.5)

			-- Calculate distance vector from the collective rotation center
			local dx = nx - cx
			local dy = ny - cy

			-- 90 degrees clockwise rotation matrix (x' = -y, y' = x)
			local rdx = -dy
			local rdy = dx

			-- Apply new position, accounting for node width shift to get back to top-left coordinate
			node.position.x = SnapToGrid(cx + rdx - (NODE_SIZE * 0.5))
			node.position.y = SnapToGrid(cy + rdy - (NODE_SIZE * 0.5))
		end
	end

	return true
end

function EDITOR:Paint(w, h)
	surface.SetDrawColor(THEME.background)
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(THEME.frame)
	surface.DrawOutlinedRect(0, 0, w, h)
	surface.DrawOutlinedRect(1, 1, w - 2, h - 2)

	draw.SimpleText("UNLOCK TREE EDITOR", "ixUnlockEditorTitle", Scale(14), Scale(8), THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	local statusY = h - Scale(24)
	surface.SetDrawColor(Color(0, 0, 0, 120))
	surface.DrawRect(0, statusY, w, Scale(24))
	surface.SetDrawColor(THEME.frameSoft)
	surface.DrawLine(0, statusY, w, statusY)

	local statusParts = {
		"TREE: " .. (editorState.treeID ~= "" and editorState.treeID or "untitled"),
		"MODE: " .. editorState.mode,
		"SELECTED: " .. tostring(SelectionCount()),
		"UNDO: " .. tostring(#editorState.undoStack),
		"STATE: " .. (editorState.dirty and "dirty" or "clean")
	}

	if (editorState.lastSavedAt > 0) then
		statusParts[#statusParts + 1] = "SAVED: " .. os.date("%H:%M:%S", editorState.lastSavedAt)
	end

	if (editorState.lastBackupAt > 0) then
		statusParts[#statusParts + 1] = "BACKUP: " .. os.date("%H:%M:%S", editorState.lastBackupAt)
	end

	draw.SimpleText(table.concat(statusParts, "   |   "), "ixUnlockEditorSmall", Scale(12), statusY + Scale(4), THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

function EDITOR:SaveDraftToServer(scope, draftID, label)
	local snapshot = self:CreateSnapshot()
	local kind = "draft"

	return self:SaveRecordToServer(kind, scope, draftID, label, snapshot)
end

function EDITOR:SaveRecordToServer(kind, scope, draftID, label, snapshot, silent)
	local encoded = util.TableToJSON(snapshot, true)

	if (!encoded) then
		chat.AddText(THEME.danger, "[Editor] ", THEME.text, "Failed to serialize draft.")
		return
	end

	local compressed = util.Compress(encoded)

	if (!compressed) then
		chat.AddText(THEME.danger, "[Editor] ", THEME.text, "Failed to compress draft.")
		return
	end

	net.Start("ixUnlockEditorDraftSaveRequest")
		net.WriteString(kind or "draft")
		net.WriteBool(silent and true or false)
		net.WriteString(scope or "private")
		net.WriteString(draftID or MakeDraftID(label))
		net.WriteString(label or self.treeIDEntry:GetValue() or editorState.treeName or "Draft")
		net.WriteUInt(#compressed, 32)
		net.WriteData(compressed, #compressed)
	net.SendToServer()

	if (!silent) then
		editorState.dirty = false
		editorState.lastSavedAt = os.time()
	end
end

function EDITOR:GetAutoBackupID()
	local steamID64 = (LocalPlayer and LocalPlayer():SteamID64()) or "local"
	return "__autosave_" .. MakeDraftID(steamID64) .. "_" .. MakeDraftID(editorState.treeID ~= "" and editorState.treeID or "tree")
end

function EDITOR:ScheduleAutoBackup()
	if (self.autoBackupTimer) then
		timer.Remove(self.autoBackupTimer)
	end

	self.autoBackupTimer = "ixUnlockEditorAutoBackup_" .. tostring(self)

	timer.Create(self.autoBackupTimer, 2, 1, function()
		if (!IsValid(self)) then return end
		editorState.lastBackupAt = os.time()
		self:SaveRecordToServer("draft", "private", self:GetAutoBackupID(), "Auto Backup", self:CreateSnapshot(), true)
	end)
end

function EDITOR:RequestDraftList(kind)
	net.Start("ixUnlockEditorDraftListRequest")
		net.WriteString(kind or "draft")
	net.SendToServer()
end

function EDITOR:RequestDraftLoad(kind, scope, draftID)
	net.Start("ixUnlockEditorDraftLoadRequest")
		net.WriteString(kind or "draft")
		net.WriteString(scope or "private")
		net.WriteString(draftID or "")
	net.SendToServer()
end

function EDITOR:CreateSelectionSnapshot()
	local nodeIDs = GetSelectedNodeIDs()

	if (table.IsEmpty(nodeIDs)) then
		return self:CreateSnapshot()
	end

	local selectedSet = {}
	local nodes = {}
	local edges = {}

	for _, nodeID in ipairs(nodeIDs) do
		selectedSet[nodeID] = true
		nodes[nodeID] = table.Copy(editorState.nodes[nodeID])
	end

	for _, edge in ipairs(editorState.edges) do
		if (selectedSet[edge.from] and selectedSet[edge.to]) then
			edges[#edges + 1] = {from = edge.from, to = edge.to}
		end
	end

	return {
		treeID = editorState.treeID,
		treeName = editorState.treeName,
		treeDescription = editorState.treeDescription,
		nodes = nodes,
		edges = edges,
		nextNodeIndex = editorState.nextNodeIndex,
		selectedNode = editorState.selectedNode,
		selectedNodes = table.Copy(editorState.selectedNodes),
		mode = editorState.mode,
		connectingFrom = editorState.connectingFrom
	}
end

function EDITOR:OpenDraftSaveDialog()
	return self:OpenRecordSaveDialog("draft", "Save Draft", self:CreateSnapshot())
end

function EDITOR:OpenPresetSaveDialog()
	return self:OpenRecordSaveDialog("preset", "Save Preset", self:CreateSelectionSnapshot())
end

function EDITOR:OpenRecordSaveDialog(kind, title, snapshot)
	local frame = vgui.Create("DFrame")
	frame:SetSize(Scale(360), Scale(170))
	frame:Center()
	frame:SetTitle(title or "Save")
	frame:MakePopup()

	local form = vgui.Create("DPanel", frame)
	form:Dock(FILL)
	form:DockMargin(Scale(8), Scale(8), Scale(8), Scale(8))
	form.Paint = function() end
	local recordNameLabel = (kind == "preset") and "Preset name" or "Draft name"
	local recordIDLabel = (kind == "preset") and "Preset ID" or "Draft ID"

	local nameEntry = vgui.Create("DTextEntry", form)
	nameEntry:Dock(TOP)
	nameEntry:SetPlaceholderText(recordNameLabel)
	nameEntry:SetText(editorState.treeName or "Draft")
	nameEntry:DockMargin(0, 0, 0, Scale(4))

	local idEntry = vgui.Create("DTextEntry", form)
	idEntry:Dock(TOP)
	idEntry:SetPlaceholderText(recordIDLabel)
	idEntry:SetText(MakeDraftID(nameEntry:GetValue()))
	idEntry:DockMargin(0, 0, 0, Scale(4))

	nameEntry.OnChange = function()
		if (idEntry:GetValue() == "" or idEntry:GetValue() == MakeDraftID(nameEntry:GetValue())) then
			idEntry:SetText(MakeDraftID(nameEntry:GetValue()))
		end
	end

	local scopeCombo = vgui.Create("DComboBox", form)
	scopeCombo:Dock(TOP)
	scopeCombo:DockMargin(0, 0, 0, Scale(8))
	scopeCombo:SetValue(kind == "preset" and "shared" or "private")
	scopeCombo:AddChoice("private")
	scopeCombo:AddChoice("shared")

	if (kind == "preset") then
		scopeCombo:SetValue("shared")
		scopeCombo:SetEnabled(false)
	end

	local saveBtn = vgui.Create("DButton", form)
	saveBtn:Dock(TOP)
	saveBtn:SetText("Save")
	saveBtn.DoClick = function()
		local scope = scopeCombo:GetValue()
		local draftID = idEntry:GetValue()
		local label = nameEntry:GetValue()

		if (draftID == "") then
			draftID = MakeDraftID(label)
		end

		self:SaveRecordToServer(kind, scope, draftID, label, snapshot)
		frame:Remove()
	end
end

function EDITOR:OpenDraftBrowser()
	return self:OpenRecordBrowser("draft", "Drafts")
end

function EDITOR:OpenPresetBrowser()
	return self:OpenRecordBrowser("preset", "Presets")
end

function EDITOR:OpenRecordBrowser(kind, title)
	if (IsValid(self.draftBrowserFrame)) then
		self.draftBrowserFrame:Remove()
	end

	local frame = vgui.Create("DFrame")
	frame:SetSize(Scale(760), Scale(420))
	frame:Center()
	frame:SetTitle(title or "Records")
	frame:MakePopup()

	self.draftBrowserFrame = frame
	self.draftBrowserKind = kind or "draft"
	self.draftBrowserData = {}
	self.draftBrowserSearch = ""
	self.draftBrowserSelection = nil

	local header = vgui.Create("DLabel", frame)
	header:Dock(TOP)
	header:DockMargin(Scale(10), Scale(8), Scale(10), 0)
	header:SetFont("ixUnlockEditorLabel")
	header:SetTextColor(THEME.textMuted)
	header:SetText((title or "Records") .. " - manage saved editor states, presets, and backups")
	header:SizeToContents()

	local search = vgui.Create("DTextEntry", frame)
	search:Dock(TOP)
	search:DockMargin(Scale(8), Scale(8), Scale(8), Scale(4))
	search:SetPlaceholderText("Search by name, id, owner, or scope")
	search.OnChange = function()
		self.draftBrowserSearch = string.Trim(string.lower(search:GetValue() or ""))
		self:RefreshDraftBrowserRows()
	end

	local toolbar = vgui.Create("DPanel", frame)
	toolbar:Dock(TOP)
	toolbar:SetTall(Scale(28))
	toolbar:DockMargin(Scale(8), 0, Scale(8), Scale(4))
	toolbar.Paint = function() end

	local list = vgui.Create("DListView", frame)
	list:Dock(FILL)
	list:DockMargin(Scale(8), Scale(8), Scale(8), Scale(8))
	list:AddColumn("Kind")
	list:AddColumn("Scope")
	list:AddColumn("Name")
	list:AddColumn("Record ID")
	list:AddColumn("Updated")
	list:AddColumn("Owner")
	list:AddColumn("Backups")
	list:SetSortable(true)
	list.OnRowSelected = function(_, _, line)
		self.draftBrowserSelection = line.draft
	end
	list.OnRowDoubleClicked = function(_, _, line)
		self.draftBrowserSelection = line.draft
		self:LoadSelectedDraftBrowserRecord()
	end

	self.draftBrowserList = list

	local bottom = vgui.Create("DPanel", frame)
	bottom:Dock(BOTTOM)
	bottom:SetTall(Scale(36))
	bottom:DockMargin(Scale(8), 0, Scale(8), Scale(8))
	bottom.Paint = function() end

	local loadBtn = vgui.Create("DButton", bottom)
	loadBtn:Dock(LEFT)
	loadBtn:SetWide(Scale(90))
	loadBtn:SetText((kind == "preset") and "Import" or "Open")
	loadBtn.DoClick = function()
		self:LoadSelectedDraftBrowserRecord()
	end

	local restoreBtn = vgui.Create("DButton", bottom)
	restoreBtn:Dock(LEFT)
	restoreBtn:SetWide(Scale(118))
	restoreBtn:DockMargin(Scale(4), 0, 0, 0)
	restoreBtn:SetText("Restore Backup")
	restoreBtn.DoClick = function()
		self:RestoreSelectedDraftBrowserRecord()
	end

	local renameBtn = vgui.Create("DButton", bottom)
	renameBtn:Dock(LEFT)
	renameBtn:SetWide(Scale(90))
	renameBtn:DockMargin(Scale(4), 0, 0, 0)
	renameBtn:SetText("Rename")
	renameBtn.DoClick = function()
		self:RenameSelectedDraftBrowserRecord()
	end

	local deleteBtn = vgui.Create("DButton", bottom)
	deleteBtn:Dock(LEFT)
	deleteBtn:SetWide(Scale(90))
	deleteBtn:DockMargin(Scale(4), 0, 0, 0)
	deleteBtn:SetText("Delete")
	deleteBtn.DoClick = function()
		self:DeleteSelectedDraftBrowserRecord()
	end

	local refreshBtn = vgui.Create("DButton", bottom)
	refreshBtn:Dock(LEFT)
	refreshBtn:SetWide(Scale(90))
	refreshBtn:DockMargin(Scale(4), 0, 0, 0)
	refreshBtn:SetText("Refresh")
	refreshBtn.DoClick = function()
		self:RequestDraftList(self.draftBrowserKind)
	end

	local closeBtn = vgui.Create("DButton", bottom)
	closeBtn:Dock(RIGHT)
	closeBtn:SetWide(Scale(90))
	closeBtn:SetText("Close")
	closeBtn.DoClick = function()
		frame:Remove()
	end

	frame.DraftList = list
	frame.DraftSearch = search
	frame.DraftToolbar = toolbar
	self:RequestDraftList(kind)
end

function EDITOR:GetDraftBrowserSelection()
	if (self.draftBrowserSelection) then
		return self.draftBrowserSelection
	end

	if (!IsValid(self.draftBrowserList)) then return nil end

	local lineID = self.draftBrowserList:GetSelectedLine()

	if (!lineID) then return nil end

	local line = self.draftBrowserList:GetLine(lineID)

	return line and line.draft or nil
end

function EDITOR:LoadSelectedDraftBrowserRecord()
	local record = self:GetDraftBrowserSelection()

	if (!record) then return end

	self:RequestDraftLoad(record.kind or self.draftBrowserKind, record.scope or "private", record.id or "")
end

function EDITOR:RenameSelectedDraftBrowserRecord()
	local record = self:GetDraftBrowserSelection()

	if (!record) then return end

	Derma_StringRequest("Rename Record", "Enter a new display name.", record.label or record.id or "", function(text)
		self:RequestDraftRename(record.kind or self.draftBrowserKind, record.scope or "private", record.id or "", text)
	end)
end

function EDITOR:DeleteSelectedDraftBrowserRecord()
	local record = self:GetDraftBrowserSelection()

	if (!record) then return end

	Derma_Query("Delete '" .. tostring(record.label or record.id or "record") .. "'?", "Confirm Delete", "Delete", function()
		self:RequestDraftDelete(record.kind or self.draftBrowserKind, record.scope or "private", record.id or "")
	end, "Cancel")
end

function EDITOR:RestoreSelectedDraftBrowserRecord()
	local record = self:GetDraftBrowserSelection()

	if (!record) then return end

	self:OpenBackupHistoryDialog(record)
end

function EDITOR:RequestDraftRename(kind, scope, draftID, newLabel)
	net.Start("ixUnlockEditorDraftRenameRequest")
		net.WriteString(kind or "draft")
		net.WriteString(scope or "private")
		net.WriteString(draftID or "")
		net.WriteString(newLabel or "")
	net.SendToServer()
end

function EDITOR:RequestDraftDelete(kind, scope, draftID)
	net.Start("ixUnlockEditorDraftDeleteRequest")
		net.WriteString(kind or "draft")
		net.WriteString(scope or "private")
		net.WriteString(draftID or "")
	net.SendToServer()
end

function EDITOR:RequestDraftRestore(kind, scope, draftID)
	net.Start("ixUnlockEditorDraftRestoreRequest")
		net.WriteString(kind or "draft")
		net.WriteString(scope or "private")
		net.WriteString(draftID or "")
	net.SendToServer()
end

function EDITOR:RequestDraftBackupList(kind, scope, draftID)
	net.Start("ixUnlockEditorDraftBackupListRequest")
		net.WriteString(kind or "draft")
		net.WriteString(scope or "private")
		net.WriteString(draftID or "")
	net.SendToServer()
end

function EDITOR:RequestDraftRestoreBackup(kind, scope, draftID, backupIndex)
	net.Start("ixUnlockEditorDraftRestoreBackupRequest")
		net.WriteString(kind or "draft")
		net.WriteString(scope or "private")
		net.WriteString(draftID or "")
		net.WriteUInt(math.max(1, tonumber(backupIndex) or 1), 16)
	net.SendToServer()
end

function EDITOR:RefreshDraftBrowserRows()
	if (!IsValid(self.draftBrowserList)) then return end

	local query = string.Trim(string.lower(self.draftBrowserSearch or ""))
	self.draftBrowserList:Clear()

	for _, draft in ipairs(self.draftBrowserData or {}) do
		local haystack = string.lower(table.concat({
			tostring(draft.kind or ""),
			tostring(draft.scope or ""),
			tostring(draft.label or ""),
			tostring(draft.id or ""),
			tostring(draft.ownerName or ""),
			tostring(draft.ownerSteamID64 or "")
		}, " "))

		if (query == "" or string.find(haystack, query, 1, true)) then
			local line = self.draftBrowserList:AddLine(
				draft.kind or "draft",
				draft.scope or "private",
				draft.label or draft.id or "Draft",
				draft.id or "",
				FormatTimestamp(draft.updatedAt),
				draft.ownerName or draft.ownerSteamID64 or "",
				tostring(draft.backupCount or 0)
			)
			line.draft = draft
		end
	end

	self.draftBrowserList:SortByColumn(5, true)

	self.draftBrowserSelection = nil
end

function EDITOR:PopulateDraftBrowser(drafts)
	if (!IsValid(self.draftBrowserFrame)) then return end

	self.draftBrowserData = drafts or {}
	self:RefreshDraftBrowserRows()
end

function EDITOR:OpenBackupHistoryDialog(record)
	if (!record) then return end

	if (IsValid(self.backupHistoryFrame)) then
		self.backupHistoryFrame:Remove()
	end

	self.backupHistoryRecord = record

	local frame = vgui.Create("DFrame")
	frame:SetSize(Scale(620), Scale(360))
	frame:Center()
	frame:SetTitle("Backup History")
	frame:MakePopup()

	self.backupHistoryFrame = frame

	local label = vgui.Create("DLabel", frame)
	label:Dock(TOP)
	label:DockMargin(Scale(8), Scale(8), Scale(8), Scale(4))
	label:SetFont("ixUnlockEditorLabel")
	label:SetTextColor(THEME.textMuted)
	label:SetText((record.label or record.id or "record") .. " - newest backups first")
	label:SizeToContents()

	local list = vgui.Create("DListView", frame)
	list:Dock(FILL)
	list:DockMargin(Scale(8), 0, Scale(8), Scale(8))
	list:AddColumn("#")
	list:AddColumn("Created")
	list:AddColumn("Label")
	list:AddColumn("Tree")
	frame.BackupList = list

	local bottom = vgui.Create("DPanel", frame)
	bottom:Dock(BOTTOM)
	bottom:SetTall(Scale(36))
	bottom:DockMargin(Scale(8), 0, Scale(8), Scale(8))
	bottom.Paint = function() end

	local restoreBtn = vgui.Create("DButton", bottom)
	restoreBtn:Dock(LEFT)
	restoreBtn:SetWide(Scale(96))
	restoreBtn:SetText("Restore")
	restoreBtn.DoClick = function()
		local lineID = list:GetSelectedLine()
		local line = lineID and list:GetLine(lineID) or nil
		if (!line) then return end
		self:RequestDraftRestoreBackup(record.kind or self.draftBrowserKind, record.scope or "private", record.id or "", line.backupIndex or 1)
	end

	local closeBtn = vgui.Create("DButton", bottom)
	closeBtn:Dock(RIGHT)
	closeBtn:SetWide(Scale(90))
	closeBtn:SetText("Close")
	closeBtn.DoClick = function()
		frame:Remove()
	end

	self:RequestDraftBackupList(record.kind or self.draftBrowserKind, record.scope or "private", record.id or "")
end

function EDITOR:PopulateBackupHistory(backups)
	if (!IsValid(self.backupHistoryFrame) or !IsValid(self.backupHistoryFrame.BackupList)) then return end

	local list = self.backupHistoryFrame.BackupList
	list:Clear()

	for _, backup in ipairs(backups or {}) do
		local line = list:AddLine(
			tostring(backup.index or 1),
			FormatTimestamp(backup.createdAt),
			backup.label or "Backup",
			backup.treeName or backup.treeID or ""
		)
		line.backupIndex = backup.index or 1
	end
end

function EDITOR:RequestBackupHistoryFromSelection()
	local record = self:GetDraftBrowserSelection()

	if (!record) then return end

	self:OpenBackupHistoryDialog(record)
end

function EDITOR:ApplyDraftSnapshot(snapshot)
	if (!snapshot) then return end

	editorState.undoStack = {}
	editorState.redoStack = {}
	editorState.clipboard = nil
	ResetEditorState()
	self:ApplySnapshot(snapshot)
	editorState.dirty = false
	editorState.lastSavedAt = os.time()
end

function EDITOR:OpenPresetImportDialog(snapshot, metadata)
	if (!snapshot or !snapshot.nodes) then return end

	local frame = vgui.Create("DFrame")
	frame:SetSize(Scale(560), Scale(480))
	frame:Center()
	frame:SetTitle("Import Preset")
	frame:MakePopup()

	local info = vgui.Create("DLabel", frame)
	info:Dock(TOP)
	info:DockMargin(Scale(8), Scale(8), Scale(8), Scale(4))
	info:SetFont("ixUnlockEditorLabel")
	info:SetTextColor(THEME.textMuted)
	info:SetText("Select nodes to import from " .. tostring(metadata and (metadata.label or metadata.id) or "preset"))
	info:SizeToContents()

	local controls = vgui.Create("DPanel", frame)
	controls:Dock(TOP)
	controls:SetTall(Scale(28))
	controls:DockMargin(Scale(8), 0, Scale(8), Scale(4))
	controls.Paint = function() end

	local selectAll = vgui.Create("DButton", controls)
	selectAll:Dock(LEFT)
	selectAll:SetWide(Scale(80))
	selectAll:SetText("All")

	local selectNone = vgui.Create("DButton", controls)
	selectNone:Dock(LEFT)
	selectNone:SetWide(Scale(80))
	selectNone:DockMargin(Scale(4), 0, 0, 0)
	selectNone:SetText("None")

	local scroll = vgui.Create("DScrollPanel", frame)
	scroll:Dock(FILL)
	scroll:DockMargin(Scale(8), 0, Scale(8), Scale(8))

	local rows = {}

	for nodeID, node in SortedPairs(snapshot.nodes) do
		local row = vgui.Create("DCheckBoxLabel", scroll)
		row:Dock(TOP)
		row:DockMargin(0, 0, 0, Scale(2))
		row:SetText((node.name or nodeID) .. " [" .. nodeID .. "]")
		row:SetValue(true)
		row.nodeID = nodeID
		row:SizeToContents()
		rows[#rows + 1] = row
	end

	selectAll.DoClick = function()
		for _, row in ipairs(rows) do
			row:SetChecked(true)
		end
	end

	selectNone.DoClick = function()
		for _, row in ipairs(rows) do
			row:SetChecked(false)
		end
	end

	local bottom = vgui.Create("DPanel", frame)
	bottom:Dock(BOTTOM)
	bottom:SetTall(Scale(36))
	bottom:DockMargin(Scale(8), 0, Scale(8), Scale(8))
	bottom.Paint = function() end

	local importBtn = vgui.Create("DButton", bottom)
	importBtn:Dock(RIGHT)
	importBtn:SetWide(Scale(96))
	importBtn:SetText("Import")
	importBtn.DoClick = function()
		local selected = {}
		for _, row in ipairs(rows) do
			if (row:GetChecked()) then
				selected[#selected + 1] = row.nodeID
			end
		end

		if (table.IsEmpty(selected)) then
			chat.AddText(THEME.danger, "[Editor] ", THEME.text, "Select at least one node to import.")
			return
		end

		local selectedSet = {}
		local nodes = {}
		for _, nodeID in ipairs(selected) do
			selectedSet[nodeID] = true
			nodes[nodeID] = table.Copy(snapshot.nodes[nodeID])
		end

		local edges = {}
		for _, edge in ipairs(snapshot.edges or {}) do
			if (selectedSet[edge.from] and selectedSet[edge.to]) then
				edges[#edges + 1] = {from = edge.from, to = edge.to}
			end
		end

		self:ImportSnapshot({
			treeID = snapshot.treeID,
			treeName = snapshot.treeName,
			treeDescription = snapshot.treeDescription,
			nodes = nodes,
			edges = edges,
			nextNodeIndex = snapshot.nextNodeIndex
		})

		chat.AddText(THEME.ready, "[Editor] ", THEME.text, "Imported preset selection: " .. tostring(metadata and (metadata.label or metadata.id) or "preset"))

		frame:Remove()
	end

	local closeBtn = vgui.Create("DButton", bottom)
	closeBtn:Dock(RIGHT)
	closeBtn:SetWide(Scale(90))
	closeBtn:DockMargin(Scale(4), 0, 0, 0)
	closeBtn:SetText("Cancel")
	closeBtn.DoClick = function()
		frame:Remove()
	end
end

function EDITOR:ImportSnapshot(snapshot)
	if (!snapshot or !snapshot.nodes) then return end

	local nodeIDs = {}
	local centerX, centerY = 0, 0
	local count = 0

	for nodeID, node in pairs(snapshot.nodes) do
		if (node and node.position) then
			centerX = centerX + node.position.x
			centerY = centerY + node.position.y
			count = count + 1
			nodeIDs[#nodeIDs + 1] = nodeID
		end
	end

	if (count == 0) then return end

	editorState.clipboard = {
		nodes = table.Copy(snapshot.nodes),
		edges = table.Copy(snapshot.edges or {}),
		anchor = {x = centerX / count, y = centerY / count},
		pasteCount = 0,
		sourceIDs = nodeIDs
	}

	self:PasteClipboard()
end

net.Receive("ixUnlockEditorDraftStatus", function()
	local message = net.ReadString()
	chat.AddText(THEME.ready, "[Editor] ", THEME.text, message)

	if (IsValid(ix.unlocks.editorPanel) and IsValid(ix.unlocks.editorPanel.draftBrowserFrame)) then
		timer.Simple(0, function()
			if (IsValid(ix.unlocks.editorPanel)) then
				ix.unlocks.editorPanel:RequestDraftList(ix.unlocks.editorPanel.draftBrowserKind)
			end
		end)
	end
end)

net.Receive("ixUnlockEditorDraftList", function()
	local len = net.ReadUInt(32)
	local compressed = net.ReadData(len)
	local json = util.Decompress(compressed)
	local drafts = json and util.JSONToTable(json) or {}

	if (IsValid(ix.unlocks.editorPanel)) then
		ix.unlocks.editorPanel:PopulateDraftBrowser(drafts)
	end
end)

net.Receive("ixUnlockEditorDraftLoad", function()
	local kind = net.ReadString()
	local scope = net.ReadString()
	local draftID = net.ReadString()
	local len = net.ReadUInt(32)
	local compressed = net.ReadData(len)
	local json = util.Decompress(compressed)
	local snapshot = json and util.JSONToTable(json) or nil

	if (!snapshot) then return end

	if (IsValid(ix.unlocks.editorPanel)) then
		if (kind == "preset") then
			ix.unlocks.editorPanel:OpenPresetImportDialog(snapshot, {kind = kind, scope = scope, id = draftID, label = draftID})
		else
			ix.unlocks.editorPanel:ApplyDraftSnapshot(snapshot)
			chat.AddText(THEME.ready, "[Editor] ", THEME.text, "Loaded draft: " .. draftID .. " (" .. scope .. ")")
		end
	end
end)

net.Receive("ixUnlockEditorDraftBackupList", function()
	local len = net.ReadUInt(32)
	local compressed = net.ReadData(len)
	local json = util.Decompress(compressed)
	local backups = json and util.JSONToTable(json) or {}

	if (IsValid(ix.unlocks.editorPanel)) then
		ix.unlocks.editorPanel:PopulateBackupHistory(backups)
	end
end)

function EDITOR:OnKeyCodePressed(key)
	if (IsTextInputFocused()) then return end

	local ctrlDown = input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)

	if (key == KEY_ESCAPE) then
		self:RequestClose()
	elseif (ctrlDown and key == KEY_Z) then
		self:Undo()
	elseif (ctrlDown and key == KEY_Y) then
		self:Redo()
	elseif (ctrlDown and key == KEY_C) then
		self:CopySelection()
	elseif (ctrlDown and key == KEY_X) then
		self:CutSelection()
	elseif (ctrlDown and key == KEY_V) then
		self:PasteClipboard()
	elseif (ctrlDown and key == KEY_R) then
		self:RotateSelection()
	elseif (ctrlDown and key == KEY_A) then
		local nodeIDs = {}

		for nodeID in pairs(editorState.nodes) do
			nodeIDs[#nodeIDs + 1] = nodeID
		end

		SetSelection(nodeIDs, nodeIDs[1])
	elseif (key == KEY_DELETE) then
		self:DeleteNodes(GetSelectedNodeIDs())
	end
end

--- Export the current tree as a Lua table string to the clipboard.
function EDITOR:ExportTree()
	if (editorState.treeID == "") then
		chat.AddText(THEME.danger, "[Editor] ", THEME.text, "Set a Tree ID before exporting.")
		return
	end

	local lines = {}
	lines[#lines + 1] = "-- Auto-generated unlock tree: " .. editorState.treeID
	lines[#lines + 1] = "ix.unlocks.RegisterTree(\"" .. editorState.treeID .. "\", {"
	lines[#lines + 1] = "\tname = \"" .. (editorState.treeName or editorState.treeID) .. "\","
	lines[#lines + 1] = "\tdescription = \"" .. (editorState.treeDescription or "") .. "\""
	lines[#lines + 1] = "})"
	lines[#lines + 1] = ""

	for nodeID, node in SortedPairs(editorState.nodes) do
		lines[#lines + 1] = "ix.unlocks.RegisterNode(\"" .. editorState.treeID .. "\", \"" .. nodeID .. "\", {"
		lines[#lines + 1] = "\tname = \"" .. node.name .. "\","
		lines[#lines + 1] = "\tdescription = \"" .. (node.description or "") .. "\","
		lines[#lines + 1] = "\ticon = \"" .. (node.icon or "icon16/brick.png") .. "\","
		lines[#lines + 1] = "\tposition = {x = " .. node.position.x .. ", y = " .. node.position.y .. "},"

		if (node.cost and type(node.cost.money) == "number" and node.cost.money > 0) then
			lines[#lines + 1] = "\tcost = {money = " .. node.cost.money .. "},"
		end

		if (node.repeatable) then
			lines[#lines + 1] = "\trepeatable = true,"
			lines[#lines + 1] = "\tmaxLevel = " .. (type(node.maxLevel) == "number" and node.maxLevel or 1) .. ","
		end

		if (node.category and node.category != "") then
			lines[#lines + 1] = "\tcategory = \"" .. node.category .. "\","
		end

		if (type(node.cooldown) == "number" and node.cooldown > 0) then
			lines[#lines + 1] = "\tcooldown = " .. node.cooldown .. ","
		end

		if (node.hidden == true) then
			lines[#lines + 1] = "\thidden = true,"
		end

		if (node.refundable == false) then
			lines[#lines + 1] = "\trefundable = false,"
		end

		lines[#lines + 1] = "})"
		lines[#lines + 1] = ""
	end

	for _, edge in ipairs(editorState.edges) do
		lines[#lines + 1] = "ix.unlocks.ConnectNodes(\"" .. editorState.treeID .. "\", \"" .. edge.from .. "\", \"" .. edge.to .. "\")"
	end

	local output = table.concat(lines, "\n")

	SetClipboardText(output)
	chat.AddText(THEME.ready, "[Editor] ", THEME.text, "Tree exported to clipboard as Lua code.")
end

--- Export only the visual layout (positions and icons) to clipboard for merging.
function EDITOR:ExportLayout()
	if (editorState.treeID == "") then
		chat.AddText(THEME.danger, "[Editor] ", THEME.text, "Set a Tree ID before exporting layout.")
		return
	end

	local lines = {}
	lines[#lines + 1] = "-- Merge visual layout for tree: " .. editorState.treeID
	lines[#lines + 1] = "ix.unlocks.MergeVisuals(\"" .. editorState.treeID .. "\", {"

	for nodeID, node in SortedPairs(editorState.nodes) do
		lines[#lines + 1] = "\t[\"" .. nodeID .. "\"] = {"
		lines[#lines + 1] = "\t\tposition = {x = " .. node.position.x .. ", y = " .. node.position.y .. "},"
		lines[#lines + 1] = "\t\ticon = \"" .. (node.icon or "icon16/brick.png") .. "\""
		lines[#lines + 1] = "\t},"
	end

	lines[#lines + 1] = "})"

	local output = table.concat(lines, "\n")
	SetClipboardText(output)
	chat.AddText(THEME.ready, "[Editor] ", THEME.text, "Visual layout exported to clipboard as merge script.")
end

--- Import a tree from a registered tree into the editor.
function EDITOR:ImportTree()
	local frame = vgui.Create("DFrame")
	frame:SetSize(Scale(300), Scale(100))
	frame:Center()
	frame:SetTitle("Import Tree ID")
	frame:MakePopup()

	local entry = vgui.Create("DTextEntry", frame)
	entry:Dock(TOP)
	entry:DockMargin(Scale(8), Scale(8), Scale(8), Scale(4))
	entry:SetPlaceholderText("Enter tree ID...")

	local btn = vgui.Create("DButton", frame)
	btn:Dock(TOP)
	btn:DockMargin(Scale(8), Scale(4), Scale(8), Scale(8))
	btn:SetText("Import")
	btn.DoClick = function()
		local treeID = entry:GetValue()
		local tree = ix.unlocks.GetTree(treeID)

		if (!tree) then
			chat.AddText(THEME.danger, "[Editor] ", THEME.text, "Tree not found: " .. treeID)
			frame:Remove()
			return
		end

		self:LoadFromTree(treeID, tree)
		frame:Remove()
	end
end

--- Load a registered tree into the editor state.
function EDITOR:LoadFromTree(treeID, tree)
	ResetEditorState()

	editorState.treeID = treeID
	editorState.treeName = tree.name
	editorState.treeDescription = tree.description

	if (IsValid(self.treeIDEntry)) then
		self.treeIDEntry:SetText(treeID)
	end

	for nodeID, node in pairs(tree.nodes) do
		editorState.nodes[nodeID] = table.Copy(node)
	end

	for _, edge in ipairs(tree.edges) do
		editorState.edges[#editorState.edges + 1] = {from = edge.from, to = edge.to}
	end

	-- Update next index
	local maxIdx = 0

	for nodeID in pairs(editorState.nodes) do
		local num = tonumber(nodeID:match("node_(%d+)"))

		if (num and num > maxIdx) then
			maxIdx = num
		end
	end

	editorState.nextNodeIndex = maxIdx + 1

	if (IsValid(self.canvas)) then
		self.canvas:CenterView()
	end

	chat.AddText(THEME.ready, "[Editor] ", THEME.text, "Loaded tree: " .. treeID)
end

--- Show a dropdown of registered trees to load into the editor.
function EDITOR:ShowLoadMenu()
	local menu = DermaMenu()

	for treeID, tree in SortedPairs(ix.unlocks.trees) do
		menu:AddOption(tree.name .. " (" .. treeID .. ")", function()
			self:LoadFromTree(treeID, tree)
		end)
	end

	if (table.IsEmpty(ix.unlocks.trees)) then
		menu:AddOption("No trees registered"):SetDisabled(true)
	end

	menu:Open()
end

--- Simple auto-layout: arrange nodes in a top-down tree hierarchy.
function EDITOR:AutoLayout()
	if (table.IsEmpty(editorState.nodes)) then return end

	-- Find root nodes (no incoming edges)
	local hasIncoming = {}

	for _, edge in ipairs(editorState.edges) do
		hasIncoming[edge.to] = true
	end

	local roots = {}

	for nodeID in pairs(editorState.nodes) do
		if (!hasIncoming[nodeID]) then
			roots[#roots + 1] = nodeID
		end
	end

	if (#roots == 0) then
		-- No clear roots, just pick the first node
		for nodeID in pairs(editorState.nodes) do
			roots[1] = nodeID
			break
		end
	end

	-- BFS from roots, assign layers
	local layers = {}
	local visited = {}
	local queue = {}

	for _, rootID in ipairs(roots) do
		queue[#queue + 1] = {id = rootID, layer = 0}
		visited[rootID] = true
	end

	while (#queue > 0) do
		local item = table.remove(queue, 1)
		local layer = item.layer

		if (!layers[layer]) then
			layers[layer] = {}
		end

		layers[layer][#layers[layer] + 1] = item.id

		-- Find children
		for _, edge in ipairs(editorState.edges) do
			if (edge.from == item.id and !visited[edge.to]) then
				visited[edge.to] = true
				queue[#queue + 1] = {id = edge.to, layer = layer + 1}
			end
		end
	end

	-- Place any orphan nodes
	for nodeID in pairs(editorState.nodes) do
		if (!visited[nodeID]) then
			local maxLayer = 0

			for l in pairs(layers) do
				if (l > maxLayer) then maxLayer = l end
			end

			local orphanLayer = maxLayer + 1

			if (!layers[orphanLayer]) then
				layers[orphanLayer] = {}
			end

			layers[orphanLayer][#layers[orphanLayer] + 1] = nodeID
		end
	end

	-- Position nodes in grid
	local spacingX = NODE_SIZE + 40
	local spacingY = NODE_SIZE + 60

	for layer, nodeIDs in SortedPairs(layers) do
		local count = #nodeIDs
		local startX = -(count - 1) * spacingX * 0.5

		for i, nodeID in ipairs(nodeIDs) do
			local node = editorState.nodes[nodeID]

			if (node) then
				node.position.x = SnapToGrid(startX + (i - 1) * spacingX)
				node.position.y = SnapToGrid(layer * spacingY)
			end
		end
	end

	if (IsValid(self.canvas)) then
		self.canvas:CenterView()
	end
end

vgui.Register("ixUnlockEditorPanel", EDITOR, "DFrame")

-- ─────────────────────────────────────────────
-- Open / Close API
-- ─────────────────────────────────────────────

--- Open the admin tree editor.
function ix.unlocks.OpenEditor()
	if (IsValid(ix.unlocks.editorPanel)) then
		ix.unlocks.editorPanel:Remove()
	end

	ix.unlocks.editorPanel = vgui.Create("ixUnlockEditorPanel")
end

--- Close the editor.
function ix.unlocks.CloseEditor()
	if (IsValid(ix.unlocks.editorPanel)) then
		ix.unlocks.editorPanel:Remove()
		ix.unlocks.editorPanel = nil
	end
end

concommand.Add("ix_unlockeditor", function(ply)
	if (IsValid(ply) and !ply:IsAdmin()) then
		chat.AddText(THEME.danger, "[Unlock Trees] ", THEME.text, "Admin access required.")
		return
	end

	ix.unlocks.OpenEditor()
end)
