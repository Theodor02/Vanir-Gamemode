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
	connectingFrom = nil, -- when in connection mode, the source node
	mode = "select"       -- "select", "connect", "delete"
}

local function ResetEditorState()
	editorState.treeID = ""
	editorState.treeName = "New Tree"
	editorState.treeDescription = ""
	editorState.nodes = {}
	editorState.edges = {}
	editorState.nextNodeIndex = 1
	editorState.selectedNode = nil
	editorState.connectingFrom = nil
	editorState.mode = "select"
end

local function SnapToGrid(value)
	return math.Round(value / GRID_SNAP) * GRID_SNAP
end

-- ─────────────────────────────────────────────
-- Editor Canvas
-- ─────────────────────────────────────────────

local CANVAS = {}

function CANVAS:Init()
	self.offsetX = 0
	self.offsetY = 0
	self.zoom = 1.0
	self.dragging = false
	self.dragStartX = 0
	self.dragStartY = 0
	self.dragStartOffX = 0
	self.dragStartOffY = 0

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

		local isSelected = (editorState.selectedNode == nodeID)
		local border = isSelected and THEME.editorNodeSelected or THEME.editorNode
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

		-- Name
		local textY = ny + scaledSize * 0.5
		draw.SimpleText(node.name or nodeID, "ixUnlockEditorNode", nx + scaledSize * 0.5, textY, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		-- Node ID below
		draw.SimpleText(nodeID, "ixUnlockEditorSmall", nx + scaledSize * 0.5, ny + scaledSize - Scale(10), THEME.textMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end

	-- Mode indicator
	local modeText = "MODE: " .. editorState.mode:upper()

	if (editorState.mode == "connect" and editorState.connectingFrom) then
		modeText = modeText .. " (from: " .. editorState.connectingFrom .. ")"
	end

	draw.SimpleText(modeText, "ixUnlockEditorSmall", Scale(8), h - Scale(16), THEME.accentSoft, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

function CANVAS:OnMousePressed(code)
	local mx, my = gui.MousePos()
	local hitNode = self:HitTestNode(mx, my)

	if (code == MOUSE_LEFT) then
		if (editorState.mode == "select") then
			if (hitNode) then
				editorState.selectedNode = hitNode

				-- Start dragging node
				local node = editorState.nodes[hitNode]
				local nx, ny = self:CanvasToLocal(node.position.x, node.position.y)
				local lx, ly = self:ScreenToLocal(mx, my)

				self.draggingNode = hitNode
				self.nodeDragOffX = lx - nx
				self.nodeDragOffY = ly - ny

				-- Notify inspector
				hook.Run("UnlockEditorNodeSelected", hitNode)
			else
				editorState.selectedNode = nil
				hook.Run("UnlockEditorNodeSelected", nil)

				-- Start panning
				self.dragging = true
				self.dragStartX, self.dragStartY = mx, my
				self.dragStartOffX = self.offsetX
				self.dragStartOffY = self.offsetY
				self:MouseCapture(true)
			end
		elseif (editorState.mode == "connect") then
			if (hitNode) then
				if (!editorState.connectingFrom) then
					editorState.connectingFrom = hitNode
				else
					-- Complete connection
					if (hitNode != editorState.connectingFrom) then
						-- Check for duplicate
						local exists = false

						for _, edge in ipairs(editorState.edges) do
							if (edge.from == editorState.connectingFrom and edge.to == hitNode) then
								exists = true
								break
							end
						end

						if (!exists) then
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
			if (hitNode) then
				-- Remove node and its edges
				editorState.nodes[hitNode] = nil

				for i = #editorState.edges, 1, -1 do
					if (editorState.edges[i].from == hitNode or editorState.edges[i].to == hitNode) then
						table.remove(editorState.edges, i)
					end
				end

				if (editorState.selectedNode == hitNode) then
					editorState.selectedNode = nil
					hook.Run("UnlockEditorNodeSelected", nil)
				end
			end
		end
	elseif (code == MOUSE_RIGHT) then
		-- Right-click: create new node at cursor or show context menu
		if (!hitNode and editorState.mode == "select") then
			local cx, cy = self:ScreenToCanvas(mx, my)
			cx = SnapToGrid(cx)
			cy = SnapToGrid(cy)

			local newID = "node_" .. editorState.nextNodeIndex
			editorState.nextNodeIndex = editorState.nextNodeIndex + 1

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

			editorState.selectedNode = newID
			hook.Run("UnlockEditorNodeSelected", newID)
		elseif (hitNode and editorState.mode == "connect") then
			-- Right-click a node in connect mode: remove edges from/to it
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
		if (self.dragging) then
			self.dragging = false
			self:MouseCapture(false)
		end

		self.draggingNode = nil
	end
end

function CANVAS:Think()
	if (self.dragging) then
		local mx, my = gui.MousePos()

		self.offsetX = self.dragStartOffX + (mx - self.dragStartX)
		self.offsetY = self.dragStartOffY + (my - self.dragStartY)
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

	self.offsetX = (self:GetWide() * 0.5) - (avgX * self.zoom)
	self.offsetY = (self:GetTall() * 0.5) - (avgY * self.zoom)
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
	self:AddTextEntry("Icon", node.icon, function(val)
		node.icon = val
	end)

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

	ResetEditorState()

	self:BuildToolbar()
	self:BuildBody()
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
		self:Remove()
	end

	-- Export button
	local exportBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	exportBtn:SetLabel("EXPORT")
	exportBtn:Dock(RIGHT)
	exportBtn:SetWide(btnW)
	exportBtn:DockMargin(0, margin, Scale(4), margin)
	exportBtn.DoClick = function()
		self:ExportTree()
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

	-- Auto-layout button
	local layoutBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	layoutBtn:SetLabel("AUTO LAYOUT")
	layoutBtn:Dock(RIGHT)
	layoutBtn:SetWide(Scale(90))
	layoutBtn:DockMargin(0, margin, Scale(4), margin)
	layoutBtn.DoClick = function()
		self:AutoLayout()
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

function EDITOR:Paint(w, h)
	surface.SetDrawColor(THEME.background)
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(THEME.frame)
	surface.DrawOutlinedRect(0, 0, w, h)
	surface.DrawOutlinedRect(1, 1, w - 2, h - 2)

	draw.SimpleText("UNLOCK TREE EDITOR", "ixUnlockEditorTitle", Scale(14), Scale(8), THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

function EDITOR:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	elseif (key == KEY_DELETE and editorState.selectedNode) then
		local nodeID = editorState.selectedNode

		editorState.nodes[nodeID] = nil

		for i = #editorState.edges, 1, -1 do
			if (editorState.edges[i].from == nodeID or editorState.edges[i].to == nodeID) then
				table.remove(editorState.edges, i)
			end
		end

		editorState.selectedNode = nil
		hook.Run("UnlockEditorNodeSelected", nil)
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

		if (node.cost and node.cost.money and node.cost.money > 0) then
			lines[#lines + 1] = "\tcost = {money = " .. node.cost.money .. "},"
		end

		if (node.repeatable) then
			lines[#lines + 1] = "\trepeatable = true,"
			lines[#lines + 1] = "\tmaxLevel = " .. (node.maxLevel or 1) .. ","
		end

		if (node.category and node.category != "") then
			lines[#lines + 1] = "\tcategory = \"" .. node.category .. "\","
		end

		if (node.cooldown and node.cooldown > 0) then
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
