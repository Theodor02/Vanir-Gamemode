-- cl_treepanel.lua
-- Main unlock tree viewer: draggable canvas, zoom, edges, toolbar, and net receive handlers.
-- Imperial terminal diegetic aesthetic matching impmainmenu / medicalsys.

local THEME = {
	background = Color(10, 10, 10, 240),
	panel = Color(6, 6, 6, 255),
	frame = Color(191, 148, 53, 220),
	frameSoft = Color(191, 148, 53, 120),
	frameDim = Color(191, 148, 53, 40),
	text = Color(235, 235, 235, 245),
	textMuted = Color(168, 168, 168, 140),
	accent = Color(191, 148, 53, 255),
	accentSoft = Color(191, 148, 53, 220),
	danger = Color(180, 60, 60, 255),
	ready = Color(60, 170, 90, 255),
	buttonBg = Color(14, 14, 14, 255),
	buttonBgHover = Color(25, 22, 14, 230),

	edgeUnlocked = Color(60, 170, 90, 180),
	edgeAvailable = Color(191, 148, 53, 120),
	edgeLocked = Color(60, 60, 60, 100),

	canvasBg = Color(4, 4, 4, 255),
	gridLine = Color(191, 148, 53, 12)
}

local SOUND_HOVER = "Helix.Rollover"
local SOUND_CLICK = "Helix.Press"

local NODE_SIZE = 72
local GRID_SPACING = 20
local MIN_ZOOM = 0.4
local MAX_ZOOM = 2.0
local ZOOM_STEP = 0.1

local FRAME_PAD = nil -- set after Scale
local TITLEBAR_H = nil

local function Scale(value)
	return math.max(1, math.Round(value * (ScrH() / 900)))
end

-- Aurebesh diagnostic lines that cycle with a typewriter effect
local DIAG_LINES = {
	"IMPERIAL RESEARCH TERMINAL",
	"AUTHENTICATION VERIFIED",
	"CLEARANCE LEVEL: AUTHORIZED",
	"DATA NODE INTEGRITY: NOMINAL",
	"ARCHIVE SYNC: ACTIVE",
	"RESOURCE ALLOCATION: STANDBY",
}

-- ─────────────────────────────────────────────
-- Fonts
-- ─────────────────────────────────────────────

local function CreateTreeFonts()
	surface.CreateFont("ixUnlockTreeTitle", {
		font = "Orbitron Bold",
		size = Scale(18),
		weight = 600,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixUnlockTreeDesc", {
		font = "Orbitron Light",
		size = Scale(10),
		weight = 400,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixUnlockToolbar", {
		font = "Orbitron Medium",
		size = Scale(11),
		weight = 500,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixUnlockToolbarSm", {
		font = "Orbitron Medium",
		size = Scale(9),
		weight = 500,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixUnlockNotify", {
		font = "Orbitron Medium",
		size = Scale(11),
		weight = 500,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixUnlockAurebesh", {
		font = "Aurebesh",
		size = Scale(10),
		weight = 400,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixUnlockAurebeshLg", {
		font = "Aurebesh",
		size = Scale(13),
		weight = 400,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixUnlockAurebeshSm", {
		font = "Aurebesh",
		size = Scale(8),
		weight = 400,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixUnlockDiag", {
		font = "Orbitron Light",
		size = Scale(9),
		weight = 400,
		extended = true,
		antialias = true
	})
end

CreateTreeFonts()

hook.Add("OnScreenSizeChanged", "ixUnlockTreeFonts", function()
	CreateTreeFonts()
end)

-- ─────────────────────────────────────────────
-- Drawing Helpers
-- ─────────────────────────────────────────────

--- Draw corner bracket decorations.
local function DrawCornerBrackets(x, y, w, h, color, len)
	len = len or Scale(14)
	local t = Scale(2)

	surface.SetDrawColor(color)
	-- Top-left
	surface.DrawRect(x, y, len, t)
	surface.DrawRect(x, y, t, len)
	-- Top-right
	surface.DrawRect(x + w - len, y, len, t)
	surface.DrawRect(x + w - t, y, t, len)
	-- Bottom-left
	surface.DrawRect(x, y + h - t, len, t)
	surface.DrawRect(x, y + h - len, t, len)
	-- Bottom-right
	surface.DrawRect(x + w - len, y + h - t, len, t)
	surface.DrawRect(x + w - t, y + h - len, t, len)
end

--- Draw faint scanline sweep.
local function DrawScanline(x, y, w, regionH, color)
	local scanY = y + (CurTime() * 35 % regionH)
	surface.SetDrawColor(color.r, color.g, color.b, 30)
	surface.DrawRect(x, scanY, w, Scale(2))
end

--- Draw typewriter aurebesh diagnostic text in the given region.
local function DrawDiagnostics(diagLines, x, y, maxH, font, color)
	local now = CurTime()
	local cycle = 12.0
	local typeSpeed = 0.035
	local timeInCycle = now % cycle

	-- Fade near cycle end
	local cycleAlpha = 255
	if (timeInCycle > cycle - 2.0) then
		cycleAlpha = math.Clamp(255 * (1 - ((timeInCycle - (cycle - 2.0)) / 1.0)), 0, 255)
	end

	if (cycleAlpha <= 0) then return end

	local charsToShow = math.floor(timeInCycle / typeSpeed)
	local charsConsumed = 0
	local lineY = y
	local lineH = Scale(12)

	for i = 1, #diagLines do
		if (lineY + lineH > y + maxH) then break end

		local lineLen = #diagLines[i]
		local charsForLine = charsToShow - charsConsumed

		if (charsForLine > 0) then
			local textToDraw = diagLines[i]
			if (charsForLine < lineLen) then
				textToDraw = string.sub(diagLines[i], 1, charsForLine)
			end

			draw.SimpleText(textToDraw, font, x, lineY,
				Color(color.r, color.g, color.b, math.Round(cycleAlpha * 0.6)),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		charsConsumed = charsConsumed + lineLen
		lineY = lineY + lineH
	end
end

-- ─────────────────────────────────────────────
-- Client-Side Net Receive Handlers
-- ─────────────────────────────────────────────

net.Receive("ixUnlockSync", function()
	local treeID = net.ReadString()
	local len = net.ReadUInt(32)
	local compressed = net.ReadData(len)
	local json = util.Decompress(compressed)

	if (!json) then return end

	local decoded = util.JSONToTable(json)

	if (!decoded) then return end

	if (treeID == "__ALL__") then
		ix.unlocks.localData = decoded
	else
		ix.unlocks.localData[treeID] = decoded
	end

	hook.Run("UnlockTreeDataUpdated", treeID)
end)

net.Receive("ixUnlockNodeSync", function()
	local treeID = net.ReadString()
	local nodeID = net.ReadString()
	local unlocked = net.ReadBool()
	local level = net.ReadUInt(16)

	if (!ix.unlocks.localData[treeID]) then
		ix.unlocks.localData[treeID] = {}
	end

	ix.unlocks.localData[treeID][nodeID] = {
		unlocked = unlocked,
		level = level
	}

	hook.Run("UnlockNodeUpdated", treeID, nodeID)
end)

net.Receive("ixUnlockDenied", function()
	local reason = net.ReadString()

	-- Push a brief notification
	if (ix.util and ix.util.Notify) then
		ix.util.Notify(reason)
	else
		chat.AddText(THEME.danger, "[Unlock Trees] ", THEME.text, reason)
	end
end)

-- ─────────────────────────────────────────────
-- Toolbar Button (small themed button for the tree panel)
-- ─────────────────────────────────────────────

local BTN = {}

function BTN:Init()
	self:SetText("")
	self.label = ""
	self.pulseOffset = math.Rand(0, 4)
end

function BTN:SetLabel(text)
	self.label = text
end

function BTN:Paint(w, h)
	local hovered = self:IsHovered() or self:IsDown()
	local disabled = self:GetDisabled()
	local pulse = (math.sin(CurTime() * 2 + self.pulseOffset) + 1) * 0.5
	local border = hovered and THEME.accent or THEME.frameSoft
	local bg = hovered and THEME.buttonBgHover or THEME.buttonBg
	local textColor = disabled and THEME.textMuted or (hovered and THEME.accent or THEME.text)
	local glow = hovered and 40 or math.Round(12 + pulse * 18)

	surface.SetDrawColor(bg)
	surface.DrawRect(0, 0, w, h)

	-- Double border with glow
	surface.SetDrawColor(Color(border.r, border.g, border.b, math.min(255, border.a + glow)))
	surface.DrawOutlinedRect(0, 0, w, h)
	surface.DrawOutlinedRect(1, 1, w - 2, h - 2)

	-- Side accent bars on hover
	if (hovered) then
		local barW = Scale(2)
		surface.SetDrawColor(THEME.accent)
		surface.DrawRect(0, 0, barW, h)
		surface.DrawRect(w - barW, 0, barW, h)
	end

	draw.SimpleText(self.label, "ixUnlockToolbar", w * 0.5, h * 0.5, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function BTN:OnCursorEntered()
	LocalPlayer():EmitSound(SOUND_HOVER)
end

function BTN:OnMousePressed(code)
	if (self:GetDisabled()) then return end

	LocalPlayer():EmitSound(SOUND_CLICK)

	if (code == MOUSE_LEFT and self.DoClick) then
		self:DoClick()
	end
end

vgui.Register("ixUnlockToolbarButton", BTN, "DButton")

-- ─────────────────────────────────────────────
-- Canvas Panel (hosts nodes, handles panning / zoom / edge drawing)
-- ─────────────────────────────────────────────

local CANVAS = {}

function CANVAS:Init()
	self.treeID = ""
	self.offsetX = 0
	self.offsetY = 0
	self.zoom = 1.0
	self.dragging = false
	self.dragStartX = 0
	self.dragStartY = 0
	self.dragStartOffX = 0
	self.dragStartOffY = 0
	self.nodePanels = {}

	self:SetMouseInputEnabled(true)
end

function CANVAS:SetTreeID(treeID)
	self.treeID = treeID
	self:RebuildNodes()
end

--- Recreate all node child panels for the current tree.
function CANVAS:RebuildNodes()
	-- Remove old panels
	for _, panel in pairs(self.nodePanels) do
		if (IsValid(panel)) then
			panel:Remove()
		end
	end

	self.nodePanels = {}

	local tree = ix.unlocks.GetTree(self.treeID)

	if (!tree) then return end

	local client = LocalPlayer()

	ix.unlocks.InvalidateVisibilityCache()

	for nodeID, node in pairs(tree.nodes) do
		-- Skip hidden nodes that the player cannot see
		if (ix.unlocks.IsNodeVisible(client, self.treeID, nodeID)) then
			local np = vgui.Create("ixUnlockNode", self)
			np:SetNodeInfo(self.treeID, nodeID)
			np:SetSize(NODE_SIZE, NODE_SIZE)
			self.nodePanels[nodeID] = np
		end
	end

	self:LayoutNodes()
end

--- Position all node panels based on current offset and zoom.
function CANVAS:LayoutNodes()
	local tree = ix.unlocks.GetTree(self.treeID)

	if (!tree) then return end

	for nodeID, panel in pairs(self.nodePanels) do
		if (IsValid(panel)) then
			local node = tree.nodes[nodeID]

			if (node) then
				local scaledSize = math.Round(NODE_SIZE * self.zoom)
				local x = math.Round(node.position.x * self.zoom + self.offsetX)
				local y = math.Round(node.position.y * self.zoom + self.offsetY)

				panel:SetPos(x, y)
				panel:SetSize(scaledSize, scaledSize)
			end
		end
	end
end

--- Get the character state for an edge (for coloring).
function CANVAS:GetEdgeState(fromID, toID)
	local character = LocalPlayer():GetCharacter()

	if (!character) then return "locked" end

	local fromUnlocked = character:HasUnlockedNode(self.treeID, fromID)
	local toUnlocked = character:HasUnlockedNode(self.treeID, toID)

	if (fromUnlocked and toUnlocked) then
		return "unlocked"
	elseif (fromUnlocked) then
		return "available"
	end

	return "locked"
end

function CANVAS:Paint(w, h)
	-- Background
	surface.SetDrawColor(THEME.canvasBg)
	surface.DrawRect(0, 0, w, h)

	-- Gold-tinted grid
	local gridSize = math.Round(GRID_SPACING * self.zoom)

	if (gridSize > 4) then
		surface.SetDrawColor(THEME.gridLine)

		for x = 0, w, gridSize do
			surface.DrawLine(x, 0, x, h)
		end

		for y = 0, h, gridSize do
			surface.DrawLine(0, y, w, y)
		end
	end

	-- Faint horizontal readout lines
	surface.SetDrawColor(255, 255, 255, 4)
	for i = 0, 8 do
		local ly = math.Round((i / 8) * h)
		surface.DrawLine(0, ly, w, ly)
	end

	-- Scanline sweep
	DrawScanline(0, 0, w, h, THEME.accent)

	-- CRT scanlines (subtle)
	for y = 0, h, 3 do
		surface.SetDrawColor(0, 0, 0, 14)
		surface.DrawLine(0, y, w, y)
	end

	-- Draw edges (only between visible nodes)
	local tree = ix.unlocks.GetTree(self.treeID)

	if (!tree) then return end

	local halfNode = math.Round(NODE_SIZE * self.zoom * 0.5)

	for _, edge in ipairs(tree.edges) do
		local fromNode = tree.nodes[edge.from]
		local toNode = tree.nodes[edge.to]

		-- Only draw edges between visible nodes
		if (fromNode and toNode and self.nodePanels[edge.from] and self.nodePanels[edge.to]) then
			local x1 = math.Round(fromNode.position.x * self.zoom + self.offsetX) + halfNode
			local y1 = math.Round(fromNode.position.y * self.zoom + self.offsetY) + halfNode
			local x2 = math.Round(toNode.position.x * self.zoom + self.offsetX) + halfNode
			local y2 = math.Round(toNode.position.y * self.zoom + self.offsetY) + halfNode

			local state = self:GetEdgeState(edge.from, edge.to)
			local edgeColor

			if (state == "unlocked") then
				edgeColor = THEME.edgeUnlocked
			elseif (state == "available") then
				edgeColor = THEME.edgeAvailable
			else
				edgeColor = THEME.edgeLocked
			end

			surface.SetDrawColor(edgeColor)

			-- Draw a thicker line (2px)
			surface.DrawLine(x1, y1, x2, y2)
			surface.DrawLine(x1 + 1, y1, x2 + 1, y2)
			surface.DrawLine(x1, y1 + 1, x2, y2 + 1)
		end
	end
end

function CANVAS:OnMousePressed(code)
	if (code == MOUSE_LEFT) then
		self.dragging = true
		self.dragStartX, self.dragStartY = gui.MousePos()
		self.dragStartOffX = self.offsetX
		self.dragStartOffY = self.offsetY
		self:MouseCapture(true)
	end
end

function CANVAS:OnMouseReleased(code)
	if (code == MOUSE_LEFT and self.dragging) then
		self.dragging = false
		self:MouseCapture(false)
	end
end

function CANVAS:Think()
	if (self.dragging) then
		local mx, my = gui.MousePos()
		self.offsetX = self.dragStartOffX + (mx - self.dragStartX)
		self.offsetY = self.dragStartOffY + (my - self.dragStartY)
		self:LayoutNodes()
	end
end

function CANVAS:OnMouseWheeled(delta)
	local oldZoom = self.zoom

	self.zoom = math.Clamp(self.zoom + delta * ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)

	-- Zoom towards mouse cursor
	local mx, my = self:ScreenToLocal(gui.MousePos())
	local zoomRatio = self.zoom / oldZoom

	self.offsetX = mx - (mx - self.offsetX) * zoomRatio
	self.offsetY = my - (my - self.offsetY) * zoomRatio

	self:LayoutNodes()
end

--- Centre the canvas on the average position of all nodes.
function CANVAS:CenterOnTree()
	local tree = ix.unlocks.GetTree(self.treeID)

	if (!tree or table.IsEmpty(tree.nodes)) then return end

	local sumX, sumY, count = 0, 0, 0

	for _, node in pairs(tree.nodes) do
		sumX = sumX + node.position.x
		sumY = sumY + node.position.y
		count = count + 1
	end

	local avgX = sumX / count
	local avgY = sumY / count

	self.offsetX = (self:GetWide() * 0.5) - (avgX * self.zoom) - (NODE_SIZE * self.zoom * 0.5)
	self.offsetY = (self:GetTall() * 0.5) - (avgY * self.zoom) - (NODE_SIZE * self.zoom * 0.5)

	self:LayoutNodes()
end

vgui.Register("ixUnlockCanvas", CANVAS, "DPanel")

-- ─────────────────────────────────────────────
-- Main Tree Panel (frame + toolbar + canvas)
-- ─────────────────────────────────────────────

local MAIN = {}

function MAIN:Init()
	self.currentTree = nil

	FRAME_PAD = Scale(2)
	TITLEBAR_H = Scale(28)

	local scrW, scrH = ScrW(), ScrH()
	local w = math.Round(scrW * 0.75)
	local h = math.Round(scrH * 0.82)

	self:SetSize(w, h)
	self:Center()
	self:SetTitle("")
	self:ShowCloseButton(false)
	self:SetDraggable(false)
	self:MakePopup()
	self:DockPadding(0, 0, 0, 0)

	-- Build layout
	self:BuildTitleBar()
	self:BuildToolbar()
	self:BuildCanvas()
	self:BuildFooter()

	-- Populate tree selector with accessible trees
	self:PopulateTreeList()

	-- Listen for data updates
	hook.Add("UnlockTreeDataUpdated", "ixUnlockTreePanel_" .. tostring(self), function(treeID)
		if (!IsValid(self)) then return end

		if (self.canvas and (treeID == "__ALL__" or treeID == self.currentTree)) then
			-- Full data sync — rebuild to pick up any hidden node visibility changes
			self.canvas:RebuildNodes()
		end
	end)

	hook.Add("UnlockNodeUpdated", "ixUnlockTreePanel_NodeUpdate_" .. tostring(self), function(treeID, nodeID)
		if (!IsValid(self)) then return end

		if (self.canvas and treeID == self.currentTree) then
			-- Check if hidden node visibility changed (new nodes revealed or nodes hidden)
			local tree = ix.unlocks.GetTree(treeID)

			if (tree) then
				ix.unlocks.InvalidateVisibilityCache()

				local client = LocalPlayer()
				local needsRebuild = false

				for nid, _ in pairs(tree.nodes) do
					local isVisible = ix.unlocks.IsNodeVisible(client, treeID, nid)
					local hasPanel = self.canvas.nodePanels[nid] != nil

					if (isVisible != hasPanel) then
						needsRebuild = true
						break
					end
				end

				if (needsRebuild) then
					self.canvas:RebuildNodes()
				else
					self.canvas:LayoutNodes()
				end
			else
				self.canvas:LayoutNodes()
			end
		end
	end)
end

function MAIN:BuildTitleBar()
	self.titleBar = vgui.Create("DPanel", self)
	self.titleBar:Dock(TOP)
	self.titleBar:SetTall(TITLEBAR_H)
	self.titleBar:DockMargin(0, 0, 0, 0)
	self.titleBar:SetMouseInputEnabled(true)

	-- Make title bar act as drag handle for the DFrame
	self.titleBar.OnMousePressed = function(bar, code)
		if (code == MOUSE_LEFT) then
			bar.dragging = true
			bar.dragX, bar.dragY = gui.MousePos()
			bar.startX, bar.startY = self:GetPos()
			bar:MouseCapture(true)
		end
	end
	self.titleBar.OnMouseReleased = function(bar, code)
		if (code == MOUSE_LEFT and bar.dragging) then
			bar.dragging = false
			bar:MouseCapture(false)
		end
	end
	self.titleBar.Think = function(bar)
		if (bar.dragging) then
			local mx, my = gui.MousePos()
			self:SetPos(bar.startX + (mx - bar.dragX), bar.startY + (my - bar.dragY))
		end
	end

	self.titleBar.Paint = function(_, w, h)
		-- Colored header bar
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawRect(0, 0, w, h)

		-- Title (black on gold bar)
		local tree = self.currentTree and ix.unlocks.GetTree(self.currentTree)
		local title = tree and tree.name:upper() or "UNLOCK TREES"
		draw.SimpleText(title, "ixUnlockTreeTitle", Scale(10), h * 0.5,
			Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		-- Pulsing Aurebesh decoration on right (offset for close button)
		local pulse = math.abs(math.sin(CurTime() * 1.5))
		local closeBtnW = Scale(60) + Scale(4)
		draw.SimpleText("RESEARCH TERMINAL", "ixUnlockAurebeshLg", w - Scale(10) - closeBtnW, h * 0.5,
			Color(0, 0, 0, math.Round(100 + pulse * 155)),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	-- Close button (red, docked right on title bar)
	local closeBtn = vgui.Create("DButton", self.titleBar)
	closeBtn:SetText("")
	closeBtn:Dock(RIGHT)
	closeBtn:SetWide(Scale(60))
	closeBtn:DockMargin(Scale(2), Scale(2), Scale(2), Scale(2))
	closeBtn.label = "CLOSE"
	closeBtn.pulseOffset = math.Rand(0, 4)
	closeBtn.Paint = function(btn, w, h)
		local hovered = btn:IsHovered() or btn:IsDown()
		local pulse = (math.sin(CurTime() * 2 + btn.pulseOffset) + 1) * 0.5
		local borderCol = hovered and THEME.danger or Color(THEME.danger.r, THEME.danger.g, THEME.danger.b, 160)
		local bg = hovered and Color(40, 10, 10, 220) or Color(20, 6, 6, 220)
		local textCol = hovered and THEME.danger or Color(THEME.danger.r, THEME.danger.g, THEME.danger.b, 200)
		local glow = hovered and 40 or math.Round(8 + pulse * 12)

		surface.SetDrawColor(bg)
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor(Color(borderCol.r, borderCol.g, borderCol.b, math.min(255, borderCol.a + glow)))
		surface.DrawOutlinedRect(0, 0, w, h)
		surface.DrawOutlinedRect(1, 1, w - 2, h - 2)

		draw.SimpleText(btn.label, "ixUnlockToolbar", w * 0.5, h * 0.5, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	closeBtn.OnCursorEntered = function()
		LocalPlayer():EmitSound(SOUND_HOVER)
	end
	closeBtn.DoClick = function()
		LocalPlayer():EmitSound(SOUND_CLICK)
		self:Remove()
	end
end

function MAIN:BuildToolbar()
	self.toolbar = vgui.Create("DPanel", self)
	self.toolbar:Dock(TOP)
	self.toolbar:SetTall(Scale(36))
	self.toolbar:DockMargin(FRAME_PAD, Scale(1), FRAME_PAD, 0)
	self.toolbar.Paint = function(_, w, h)
		surface.SetDrawColor(Color(0, 0, 0, 220))
		surface.DrawRect(0, 0, w, h)

		-- Subtle separator at bottom
		surface.SetDrawColor(THEME.frameDim)
		surface.DrawLine(0, h - 1, w, h - 1)
	end

	local margin = Scale(5)
	local btnW = Scale(70)

	-- Tree selector combo box
	self.treeSelector = vgui.Create("DComboBox", self.toolbar)
	self.treeSelector:SetFont("ixUnlockToolbar")
	self.treeSelector:SetTextColor(THEME.text)
	self.treeSelector:SetValue("Select Tree...")
	self.treeSelector:Dock(LEFT)
	self.treeSelector:SetWide(Scale(200))
	self.treeSelector:DockMargin(Scale(6), margin, Scale(4), margin)
	self.treeSelector.Paint = function(_, w, h)
		surface.SetDrawColor(THEME.buttonBg)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
	self.treeSelector.OnSelect = function(_, _, _, data)
		self:SelectTree(data)
	end

	-- Node search filter
	self.searchEntry = vgui.Create("DTextEntry", self.toolbar)
	self.searchEntry:SetFont("ixUnlockToolbar")
	self.searchEntry:SetTextColor(THEME.text)
	self.searchEntry:SetPlaceholderText("Search nodes...")
	self.searchEntry:SetPlaceholderColor(THEME.textMuted)
	self.searchEntry:Dock(LEFT)
	self.searchEntry:SetWide(Scale(140))
	self.searchEntry:DockMargin(Scale(4), margin, Scale(4), margin)
	self.searchEntry.Paint = function(_, w, h)
		surface.SetDrawColor(THEME.buttonBg)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawOutlinedRect(0, 0, w, h)
		self.searchEntry:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
	end
	self.searchEntry.OnChange = function()
		self:ApplySearchFilter()
	end

	-- Zoom in
	local zoomIn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	zoomIn:SetLabel("+")
	zoomIn:Dock(RIGHT)
	zoomIn:SetWide(Scale(28))
	zoomIn:DockMargin(0, margin, Scale(6), margin)
	zoomIn.DoClick = function()
		if (self.canvas) then
			self.canvas.zoom = math.Clamp(self.canvas.zoom + ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
			self.canvas:LayoutNodes()
		end
	end

	-- Zoom out
	local zoomOut = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	zoomOut:SetLabel("-")
	zoomOut:Dock(RIGHT)
	zoomOut:SetWide(Scale(28))
	zoomOut:DockMargin(0, margin, Scale(2), margin)
	zoomOut.DoClick = function()
		if (self.canvas) then
			self.canvas.zoom = math.Clamp(self.canvas.zoom - ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
			self.canvas:LayoutNodes()
		end
	end

	-- Centre button
	local centreBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	centreBtn:SetLabel("CENTRE")
	centreBtn:Dock(RIGHT)
	centreBtn:SetWide(btnW)
	centreBtn:DockMargin(0, margin, Scale(4), margin)
	centreBtn.DoClick = function()
		if (self.canvas) then
			self.canvas:CenterOnTree()
		end
	end

	-- Respec button
	self.respecBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	self.respecBtn:SetLabel("RESPEC")
	self.respecBtn:Dock(RIGHT)
	self.respecBtn:SetWide(btnW)
	self.respecBtn:DockMargin(0, margin, Scale(4), margin)
	self.respecBtn.DoClick = function()
		if (self.currentTree) then
			local tree = ix.unlocks.GetTree(self.currentTree)
			local respecRatio = (tree and tree.respecRatio) or 1
			local pct = math.Round(respecRatio * 100)
			local msg = pct >= 100 and "Reset all progress in this tree? Costs will be refunded." or
				"Reset all progress in this tree? You will receive " .. pct .. "% of costs back."

			Derma_Query(
				msg,
				"Confirm Respec",
				"Confirm", function()
					ix.unlocks.RequestRespec(self.currentTree, false, true)
				end,
				"Cancel", function() end
			)
		end
	end
end

function MAIN:BuildCanvas()
	self.canvas = vgui.Create("ixUnlockCanvas", self)
	self.canvas:Dock(FILL)
	self.canvas:DockMargin(FRAME_PAD, Scale(1), FRAME_PAD, 0)
end

function MAIN:BuildFooter()
	self.footer = vgui.Create("DPanel", self)
	self.footer:Dock(BOTTOM)
	self.footer:SetTall(Scale(42))
	self.footer:DockMargin(FRAME_PAD, 0, FRAME_PAD, FRAME_PAD)
	self.footer:SetMouseInputEnabled(false)

	self.footer.Paint = function(_, w, h)
		-- Dim background
		surface.SetDrawColor(Color(0, 0, 0, 200))
		surface.DrawRect(0, 0, w, h)

		-- Top separator
		surface.SetDrawColor(THEME.frameDim)
		surface.DrawLine(0, 0, w, 0)

		-- Animated data bars
		local now = CurTime()
		local barH = Scale(4)
		local barY = Scale(6)
		local barPad = Scale(6)

		for i = 1, 3 do
			local phase = now * (0.6 + i * 0.35)
			local fill = 0.25 + (math.sin(phase) + 1) * 0.35
			local by = barY + (i - 1) * (barH + Scale(3))

			surface.SetDrawColor(255, 255, 255, 6)
			surface.DrawRect(barPad, by, w - barPad * 2, barH)

			surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 80)
			surface.DrawRect(barPad, by, math.Round((w - barPad * 2) * fill), barH)
		end

		-- Diagnostic aurebesh text at bottom
		local diagY = barY + 3 * (barH + Scale(3)) + Scale(1)
		DrawDiagnostics(DIAG_LINES, barPad, diagY,
			h - diagY - Scale(2), "ixUnlockAurebeshSm", THEME.accent)
	end
end

function MAIN:PopulateTreeList()
	self.treeSelector:Clear()

	local treeIDs = ix.unlocks.GetTreeIDs()
	local count = 0

	for _, treeID in ipairs(treeIDs) do
		local tree = ix.unlocks.GetTree(treeID)

		if (tree) then
			-- Only show trees the player can access
			local canAccess = ix.unlocks.CanAccessTree(LocalPlayer(), treeID)

			if (canAccess) then
				self.treeSelector:AddChoice(tree.name, treeID)
				count = count + 1
			end
		end
	end

	self._treeChoiceCount = count

	-- Auto-select first tree if only one
	if (count == 1) then
		self.treeSelector:ChooseOptionID(1)
	end
end

function MAIN:SelectTree(treeID)
	self.currentTree = treeID

	-- Show or hide respec button based on tree's allowRespec setting
	if (IsValid(self.respecBtn)) then
		local tree = ix.unlocks.GetTree(treeID)
		self.respecBtn:SetVisible(!tree or tree.allowRespec != false)
	end

	-- Clear search filter when switching trees
	if (IsValid(self.searchEntry)) then
		self.searchEntry:SetText("")
	end

	if (self.canvas) then
		self.canvas:SetTreeID(treeID)

		-- Auto-centre after a brief delay so layout has settled
		timer.Simple(0, function()
			if (IsValid(self) and IsValid(self.canvas)) then
				self.canvas:CenterOnTree()
			end
		end)
	end
end

--- Filter visible node panels by name/category search text.
function MAIN:ApplySearchFilter()
	if (!self.canvas or !self.currentTree) then return end

	local query = IsValid(self.searchEntry) and self.searchEntry:GetText() or ""
	query = string.Trim(query):lower()

	for nodeID, panel in pairs(self.canvas.nodePanels) do
		if (IsValid(panel)) then
			if (query == "") then
				panel:SetVisible(true)
			else
				local node = ix.unlocks.GetNode(self.currentTree, nodeID)
				local match = false

				if (node) then
					if (string.find(node.name:lower(), query, 1, true)) then
						match = true
					elseif (node.category and string.find(node.category:lower(), query, 1, true)) then
						match = true
					elseif (string.find(nodeID:lower(), query, 1, true)) then
						match = true
					end
				end

				panel:SetVisible(match)
			end
		end
	end
end

function MAIN:Paint(w, h)
	-- Full dark background
	surface.SetDrawColor(Color(0, 0, 0, 250))
	surface.DrawRect(0, 0, w, h)

	-- Golden frame border at the panel edge
	surface.SetDrawColor(THEME.frame)
	surface.DrawOutlinedRect(0, 0, w, h)
	surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
end

function MAIN:OnRemove()
	hook.Remove("UnlockTreeDataUpdated", "ixUnlockTreePanel_" .. tostring(self))
	hook.Remove("UnlockNodeUpdated", "ixUnlockTreePanel_NodeUpdate_" .. tostring(self))
end

function MAIN:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

vgui.Register("ixUnlockTreePanel", MAIN, "DFrame")

-- ─────────────────────────────────────────────
-- Tab Menu Embeddable Panel (no tree selector, no DFrame chrome)
-- ─────────────────────────────────────────────

local TAB_EMBED = {}

function TAB_EMBED:Init()
	self.currentTree = nil

	FRAME_PAD = Scale(2)
	TITLEBAR_H = Scale(28)

	self:DockPadding(0, 0, 0, 0)

	self:BuildTitleBar()
	self:BuildToolbar()
	self:BuildCanvas()
	self:BuildFooter()

	hook.Add("UnlockTreeDataUpdated", "ixUnlockTreeTabEmbed_" .. tostring(self), function(treeID)
		if (!IsValid(self)) then return end

		if (self.canvas and (treeID == "__ALL__" or treeID == self.currentTree)) then
			self.canvas:RebuildNodes()
		end
	end)

	hook.Add("UnlockNodeUpdated", "ixUnlockTreeTabEmbed_NodeUpdate_" .. tostring(self), function(treeID, nodeID)
		if (!IsValid(self)) then return end

		if (self.canvas and treeID == self.currentTree) then
			local tree = ix.unlocks.GetTree(treeID)

			if (tree) then
				ix.unlocks.InvalidateVisibilityCache()

				local client = LocalPlayer()
				local needsRebuild = false

				for nid, _ in pairs(tree.nodes) do
					local isVisible = ix.unlocks.IsNodeVisible(client, treeID, nid)
					local hasPanel = self.canvas.nodePanels[nid] != nil

					if (isVisible != hasPanel) then
						needsRebuild = true
						break
					end
				end

				if (needsRebuild) then
					self.canvas:RebuildNodes()
				else
					self.canvas:LayoutNodes()
				end
			else
				self.canvas:LayoutNodes()
			end
		end
	end)
end

function TAB_EMBED:SetTreeID(treeID)
	self.currentTree = treeID

	-- Show or hide respec button based on tree's allowRespec setting
	if (IsValid(self.respecBtn)) then
		local tree = ix.unlocks.GetTree(treeID)
		self.respecBtn:SetVisible(!tree or tree.allowRespec != false)
	end

	if (IsValid(self.searchEntry)) then
		self.searchEntry:SetText("")
	end

	if (self.canvas) then
		self.canvas:SetTreeID(treeID)
	end
end

function TAB_EMBED:CenterOnTree()
	if (IsValid(self.canvas)) then
		self.canvas:CenterOnTree()
	end
end

function TAB_EMBED:BuildTitleBar()
	self.titleBar = vgui.Create("DPanel", self)
	self.titleBar:Dock(TOP)
	self.titleBar:SetTall(TITLEBAR_H)
	self.titleBar:DockMargin(0, 0, 0, 0)

	self.titleBar.Paint = function(_, w, h)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawRect(0, 0, w, h)

		local tree = self.currentTree and ix.unlocks.GetTree(self.currentTree)
		local title = tree and tree.name:upper() or "UNLOCK TREES"
		draw.SimpleText(title, "ixUnlockTreeTitle", Scale(10), h * 0.5,
			Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local pulse = math.abs(math.sin(CurTime() * 1.5))
		draw.SimpleText("RESEARCH TERMINAL", "ixUnlockAurebeshLg", w - Scale(10), h * 0.5,
			Color(0, 0, 0, math.Round(100 + pulse * 155)),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

function TAB_EMBED:BuildToolbar()
	self.toolbar = vgui.Create("DPanel", self)
	self.toolbar:Dock(TOP)
	self.toolbar:SetTall(Scale(36))
	self.toolbar:DockMargin(FRAME_PAD, Scale(1), FRAME_PAD, 0)
	self.toolbar.Paint = function(_, w, h)
		surface.SetDrawColor(Color(0, 0, 0, 220))
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor(THEME.frameDim)
		surface.DrawLine(0, h - 1, w, h - 1)
	end

	local margin = Scale(5)
	local btnW = Scale(70)

	-- Node search filter (no tree selector)
	self.searchEntry = vgui.Create("DTextEntry", self.toolbar)
	self.searchEntry:SetFont("ixUnlockToolbar")
	self.searchEntry:SetTextColor(THEME.text)
	self.searchEntry:SetPlaceholderText("Search nodes...")
	self.searchEntry:SetPlaceholderColor(THEME.textMuted)
	self.searchEntry:Dock(LEFT)
	self.searchEntry:SetWide(Scale(140))
	self.searchEntry:DockMargin(Scale(6), margin, Scale(4), margin)
	self.searchEntry.Paint = function(_, w, h)
		surface.SetDrawColor(THEME.buttonBg)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawOutlinedRect(0, 0, w, h)
		self.searchEntry:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
	end
	self.searchEntry.OnChange = function()
		self:ApplySearchFilter()
	end

	-- Zoom in
	local zoomIn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	zoomIn:SetLabel("+")
	zoomIn:Dock(RIGHT)
	zoomIn:SetWide(Scale(28))
	zoomIn:DockMargin(0, margin, Scale(6), margin)
	zoomIn.DoClick = function()
		if (self.canvas) then
			self.canvas.zoom = math.Clamp(self.canvas.zoom + ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
			self.canvas:LayoutNodes()
		end
	end

	-- Zoom out
	local zoomOut = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	zoomOut:SetLabel("-")
	zoomOut:Dock(RIGHT)
	zoomOut:SetWide(Scale(28))
	zoomOut:DockMargin(0, margin, Scale(2), margin)
	zoomOut.DoClick = function()
		if (self.canvas) then
			self.canvas.zoom = math.Clamp(self.canvas.zoom - ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
			self.canvas:LayoutNodes()
		end
	end

	-- Centre button
	local centreBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	centreBtn:SetLabel("CENTRE")
	centreBtn:Dock(RIGHT)
	centreBtn:SetWide(btnW)
	centreBtn:DockMargin(0, margin, Scale(4), margin)
	centreBtn.DoClick = function()
		if (self.canvas) then
			self.canvas:CenterOnTree()
		end
	end

	-- Respec button
	self.respecBtn = vgui.Create("ixUnlockToolbarButton", self.toolbar)
	self.respecBtn:SetLabel("RESPEC")
	self.respecBtn:Dock(RIGHT)
	self.respecBtn:SetWide(btnW)
	self.respecBtn:DockMargin(0, margin, Scale(4), margin)
	self.respecBtn.DoClick = function()
		if (self.currentTree) then
			local tree = ix.unlocks.GetTree(self.currentTree)
			local respecRatio = (tree and tree.respecRatio) or 1
			local pct = math.Round(respecRatio * 100)
			local msg = pct >= 100 and "Reset all progress in this tree? Costs will be refunded." or
				"Reset all progress in this tree? You will receive " .. pct .. "% of costs back."

			Derma_Query(
				msg,
				"Confirm Respec",
				"Confirm", function()
					ix.unlocks.RequestRespec(self.currentTree, false, true)
				end,
				"Cancel", function() end
			)
		end
	end
end

function TAB_EMBED:BuildCanvas()
	self.canvas = vgui.Create("ixUnlockCanvas", self)
	self.canvas:Dock(FILL)
	self.canvas:DockMargin(FRAME_PAD, Scale(1), FRAME_PAD, 0)
end

function TAB_EMBED:BuildFooter()
	self.footer = vgui.Create("DPanel", self)
	self.footer:Dock(BOTTOM)
	self.footer:SetTall(Scale(42))
	self.footer:DockMargin(FRAME_PAD, 0, FRAME_PAD, FRAME_PAD)
	self.footer:SetMouseInputEnabled(false)

	self.footer.Paint = function(_, w, h)
		surface.SetDrawColor(Color(0, 0, 0, 200))
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor(THEME.frameDim)
		surface.DrawLine(0, 0, w, 0)

		local now = CurTime()
		local barH = Scale(4)
		local barY = Scale(6)
		local barPad = Scale(6)

		for i = 1, 3 do
			local phase = now * (0.6 + i * 0.35)
			local fill = 0.25 + (math.sin(phase) + 1) * 0.35
			local by = barY + (i - 1) * (barH + Scale(3))

			surface.SetDrawColor(255, 255, 255, 6)
			surface.DrawRect(barPad, by, w - barPad * 2, barH)

			surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 80)
			surface.DrawRect(barPad, by, math.Round((w - barPad * 2) * fill), barH)
		end

		local diagY = barY + 3 * (barH + Scale(3)) + Scale(1)
		DrawDiagnostics(DIAG_LINES, barPad, diagY,
			h - diagY - Scale(2), "ixUnlockAurebeshSm", THEME.accent)
	end
end

function TAB_EMBED:ApplySearchFilter()
	if (!self.canvas or !self.currentTree) then return end

	local query = IsValid(self.searchEntry) and self.searchEntry:GetText() or ""
	query = string.Trim(query):lower()

	for nodeID, panel in pairs(self.canvas.nodePanels) do
		if (IsValid(panel)) then
			if (query == "") then
				panel:SetVisible(true)
			else
				local node = ix.unlocks.GetNode(self.currentTree, nodeID)
				local match = false

				if (node) then
					if (string.find(node.name:lower(), query, 1, true)) then
						match = true
					elseif (node.category and string.find(node.category:lower(), query, 1, true)) then
						match = true
					elseif (string.find(nodeID:lower(), query, 1, true)) then
						match = true
					end
				end

				panel:SetVisible(match)
			end
		end
	end
end

function TAB_EMBED:Paint(w, h)
	surface.SetDrawColor(Color(0, 0, 0, 250))
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(THEME.frame)
	surface.DrawOutlinedRect(0, 0, w, h)
	surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
end

function TAB_EMBED:OnRemove()
	hook.Remove("UnlockTreeDataUpdated", "ixUnlockTreeTabEmbed_" .. tostring(self))
	hook.Remove("UnlockNodeUpdated", "ixUnlockTreeTabEmbed_NodeUpdate_" .. tostring(self))
end

vgui.Register("ixUnlockTreeTabEmbed", TAB_EMBED, "DPanel")

-- ─────────────────────────────────────────────
-- Global Open / Close API
-- ─────────────────────────────────────────────

--- Open the unlock tree viewer.
-- @param treeID string (optional) Auto-select this tree
function ix.unlocks.OpenTreePanel(treeID)
	if (IsValid(ix.unlocks.activePanel)) then
		ix.unlocks.activePanel:Remove()
	end

	ix.unlocks.activePanel = vgui.Create("ixUnlockTreePanel")

	if (treeID) then
		ix.unlocks.activePanel:SelectTree(treeID)
	end
end

--- Close the tree panel if open.
function ix.unlocks.CloseTreePanel()
	if (IsValid(ix.unlocks.activePanel)) then
		ix.unlocks.activePanel:Remove()
		ix.unlocks.activePanel = nil
	end
end

-- Console command to open the panel
concommand.Add("ix_unlocktree", function()
	ix.unlocks.OpenTreePanel()
end)
