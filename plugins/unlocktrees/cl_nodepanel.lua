-- cl_nodepanel.lua
-- Individual unlock node panel rendered inside the tree canvas.

local THEME = {
	background = Color(10, 10, 10, 240),
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

	nodeUnlocked = Color(60, 170, 90, 255),
	nodeAvailable = Color(191, 148, 53, 255),
	nodeLocked = Color(80, 80, 80, 200),
	nodeMaxed = Color(100, 180, 220, 255),
	nodeExcluded = Color(180, 50, 50, 255),

	nodeUnlockedBg = Color(20, 40, 25, 240),
	nodeAvailableBg = Color(25, 20, 10, 240),
	nodeLockedBg = Color(14, 14, 14, 240),
	nodeMaxedBg = Color(15, 25, 35, 240),
	nodeExcludedBg = Color(60, 12, 12, 240)
}

local SOUND_HOVER = "Helix.Rollover"
local SOUND_CLICK = "Helix.Press"

local function Scale(value)
	return math.max(1, math.Round(value * (ScrH() / 900)))
end

-- ─────────────────────────────────────────────
-- Fonts (created once, recreated on resolution change)
-- ─────────────────────────────────────────────

local function CreateNodeFonts()
	surface.CreateFont("ixUnlockNodeName", {
		font = "Orbitron Medium",
		size = Scale(9),
		weight = 500,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixUnlockNodeLevel", {
		font = "Orbitron Light",
		size = Scale(8),
		weight = 400,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixUnlockTooltipTitle", {
		font = "Orbitron Bold",
		size = Scale(13),
		weight = 600,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixUnlockTooltipBody", {
		font = "Orbitron Light",
		size = Scale(10),
		weight = 400,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixUnlockTooltipAurebesh", {
		font = "Aurebesh",
		size = Scale(9),
		weight = 400,
		extended = true,
		antialias = true
	})
end

CreateNodeFonts()

hook.Add("OnScreenSizeChanged", "ixUnlockNodeFonts", function()
	CreateNodeFonts()
end)

-- ─────────────────────────────────────────────
-- Node State Helpers
-- ─────────────────────────────────────────────

-- Determine the visual state of a node for the local player.
-- Returns: "unlocked", "maxed", "available", or "locked"
local function GetNodeState(treeID, nodeID)
	local client = LocalPlayer()
	local character = client:GetCharacter()

	if (!character) then return "locked" end

	local node = ix.unlocks.GetNode(treeID, nodeID)

	if (!node) then return "locked" end

	local isUnlocked = character:HasUnlockedNode(treeID, nodeID)
	local level = character:GetNodeLevel(treeID, nodeID)

	if (isUnlocked and node.repeatable and level >= node.maxLevel) then
		return "maxed"
	end

	if (isUnlocked and !node.repeatable) then
		return "unlocked"
	end

	-- Check mutual exclusivity — if a conflicting node is unlocked, this is excluded
	if (node.mutuallyExclusive and #node.mutuallyExclusive > 0) then
		for _, exID in ipairs(node.mutuallyExclusive) do
			if (character:HasUnlockedNode(treeID, exID)) then
				return "excluded"
			end
		end
	end

	-- Check if prerequisites are met (available to unlock)
	local prereqs = ix.unlocks.GetPrerequisites(treeID, nodeID)
	local allMet = true

	for _, prereqID in ipairs(prereqs) do
		if (!character:HasUnlockedNode(treeID, prereqID)) then
			allMet = false
			break
		end
	end

	-- Repeatable node already unlocked but not maxed
	if (isUnlocked and node.repeatable) then
		return "available"
	end

	if (allMet and #prereqs > 0) then
		return "available"
	end

	-- Root nodes (no prereqs) are always available
	if (#prereqs == 0 and !isUnlocked) then
		return "available"
	end

	return "locked"
end

-- ─────────────────────────────────────────────
-- Text wrapping utility
-- ─────────────────────────────────────────────

local function WrapText(text, font, maxWidth)
	surface.SetFont(font)

	local words = {}
	for word in string.gmatch(text, "%S+") do
		words[#words + 1] = word
	end

	local lines = {}
	local currentLine = ""

	for i = 1, #words do
		local testLine = (currentLine == "") and words[i] or (currentLine .. " " .. words[i])
		local tw = surface.GetTextSize(testLine)

		if (tw > maxWidth and currentLine != "") then
			lines[#lines + 1] = currentLine
			currentLine = words[i]
		else
			currentLine = testLine
		end
	end

	if (currentLine != "") then
		lines[#lines + 1] = currentLine
	end

	return lines
end

-- ─────────────────────────────────────────────
-- Tooltip Panel
-- ─────────────────────────────────────────────

local TOOLTIP = {}

function TOOLTIP:Init()
	self.nodeData = nil
	self.treeID = ""
	self.nodeID = ""
	self:SetDrawOnTop(true)
	self:SetMouseInputEnabled(false)
end

function TOOLTIP:SetNodeInfo(treeID, nodeID)
	self.treeID = treeID
	self.nodeID = nodeID
	self.nodeData = ix.unlocks.GetNode(treeID, nodeID)
end

function TOOLTIP:Paint(w, h)
	local node = self.nodeData

	if (!node) then return end

	local headerH = Scale(22)
	local padding = Scale(8)
	local lineH = Scale(14)
	local contentW = w - padding * 2

	-- Dark background
	surface.SetDrawColor(Color(0, 0, 0, 240))
	surface.DrawRect(0, 0, w, h)

	-- Header bar (gold)
	surface.SetDrawColor(THEME.frame)
	surface.DrawRect(0, 0, w, headerH)

	-- Frame outline
	surface.SetDrawColor(THEME.frame)
	surface.DrawOutlinedRect(0, 0, w, h)

	-- Corner brackets
	local cornerLen = Scale(8)
	local t = Scale(1)
	surface.SetDrawColor(THEME.accent)
	surface.DrawRect(0, 0, cornerLen, t)
	surface.DrawRect(0, 0, t, cornerLen)
	surface.DrawRect(w - cornerLen, 0, cornerLen, t)
	surface.DrawRect(w - t, 0, t, cornerLen)
	surface.DrawRect(0, h - t, cornerLen, t)
	surface.DrawRect(0, h - cornerLen, t, cornerLen)
	surface.DrawRect(w - cornerLen, h - t, cornerLen, t)
	surface.DrawRect(w - t, h - cornerLen, t, cornerLen)

	-- Pulsing Aurebesh on header right
	local pulse = math.abs(math.sin(CurTime() * 1.5))
	local aurebeshColor = Color(0, 0, 0, math.Round(80 + pulse * 175))
	surface.SetFont("ixUnlockTooltipAurebesh")
	local aurebeshW = surface.GetTextSize("DATA NODE")
	draw.SimpleText("DATA NODE", "ixUnlockTooltipAurebesh", w - padding, headerH * 0.5,
		aurebeshColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	-- Title (black on gold header, clipped to avoid Aurebesh overlap)
	local titleMaxW = w - padding * 2 - aurebeshW - Scale(6)
	local sx, sy = self:LocalToScreen(0, 0)
	render.SetScissorRect(sx + padding, sy, sx + padding + math.max(titleMaxW, 0), sy + headerH, true)
	draw.SimpleText(node.name:upper(), "ixUnlockTooltipTitle", padding, headerH * 0.5,
		Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	render.SetScissorRect(0, 0, 0, 0, false)

	local y = headerH + padding

	-- Description (word-wrapped)
	if (node.description and node.description != "") then
		local descLines = WrapText(node.description, "ixUnlockTooltipBody", contentW)

		for _, line in ipairs(descLines) do
			draw.SimpleText(line, "ixUnlockTooltipBody", padding, y, THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			y = y + lineH
		end
	end

	y = y + Scale(4)

	-- Cost
	local costStr = ix.unlocks.GetCostString(self.treeID, self.nodeID)
	draw.SimpleText("Cost: " .. costStr, "ixUnlockTooltipBody", padding, y, THEME.accentSoft, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	y = y + lineH

	-- Path cost (total to reach this node)
	local state = GetNodeState(self.treeID, self.nodeID)

	if (state == "locked" or state == "available") then
		local pathCostStr = ix.unlocks.GetPathCostString(LocalPlayer(), self.treeID, self.nodeID)

		if (pathCostStr != costStr and pathCostStr != "Free") then
			draw.SimpleText("Path: " .. pathCostStr, "ixUnlockTooltipBody", padding, y, THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			y = y + lineH
		end
	end

	-- Category
	if (node.category and node.category != "") then
		draw.SimpleText("Category: " .. node.category, "ixUnlockTooltipBody", padding, y, THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + lineH
	end

	-- State
	local stateColor = THEME.nodeLocked

	if (state == "unlocked") then
		stateColor = THEME.nodeUnlocked
	elseif (state == "available") then
		stateColor = THEME.nodeAvailable
	elseif (state == "maxed") then
		stateColor = THEME.nodeMaxed
	elseif (state == "excluded") then
		stateColor = THEME.nodeExcluded
	end

	local character = LocalPlayer():GetCharacter()
	local level = character and character:GetNodeLevel(self.treeID, self.nodeID) or 0

	if (node.repeatable) then
		draw.SimpleText("Level: " .. level .. " / " .. node.maxLevel, "ixUnlockTooltipBody", padding, y, stateColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + lineH
	else
		local stateLabel = state == "unlocked" and "UNLOCKED"
			or (state == "available" and "AVAILABLE"
			or (state == "excluded" and "EXCLUDED"
			or "LOCKED"))
		draw.SimpleText(stateLabel, "ixUnlockTooltipBody", padding, y, stateColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + lineH
	end

	-- Prerequisites
	local prereqs = ix.unlocks.GetPrerequisites(self.treeID, self.nodeID)

	if (#prereqs > 0) then
		y = y + Scale(2)

		-- Section divider
		local tw = surface.GetTextSize("Requires:")
		draw.SimpleText("Requires:", "ixUnlockTooltipBody", padding, y, THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 40)
		surface.DrawRect(padding + tw + Scale(6), y + Scale(6), w - padding * 2 - tw - Scale(6), 1)
		y = y + Scale(13)

		for _, prereqID in ipairs(prereqs) do
			local prereqNode = ix.unlocks.GetNode(self.treeID, prereqID)
			local prereqName = prereqNode and prereqNode.name or prereqID
			local met = character and character:HasUnlockedNode(self.treeID, prereqID)
			local col = met and THEME.nodeUnlocked or THEME.danger

			draw.SimpleText("  > " .. prereqName, "ixUnlockTooltipBody", padding, y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			y = y + Scale(13)
		end
	end

	-- Mutual exclusivity
	if (node.mutuallyExclusive and #node.mutuallyExclusive > 0) then
		y = y + Scale(2)

		local tw = surface.GetTextSize("Exclusive with:")
		draw.SimpleText("Exclusive with:", "ixUnlockTooltipBody", padding, y, THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 40)
		surface.DrawRect(padding + tw + Scale(6), y + Scale(6), w - padding * 2 - tw - Scale(6), 1)
		y = y + Scale(13)

		for _, exID in ipairs(node.mutuallyExclusive) do
			local exNode = ix.unlocks.GetNode(self.treeID, exID)
			local exName = exNode and exNode.name or exID
			local taken = character and character:HasUnlockedNode(self.treeID, exID)
			local col = taken and THEME.danger or THEME.textMuted

			draw.SimpleText("  x " .. exName, "ixUnlockTooltipBody", padding, y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			y = y + Scale(13)
		end
	end
end

vgui.Register("ixUnlockTooltip", TOOLTIP, "DPanel")

-- ─────────────────────────────────────────────
-- Node Panel
-- ─────────────────────────────────────────────

local NODE_SIZE = 72

local PANEL = {}

AccessorFunc(PANEL, "treeID", "TreeID")
AccessorFunc(PANEL, "nodeID", "NodeID")

function PANEL:Init()
	self.treeID = ""
	self.nodeID = ""
	self.pulseOffset = math.Rand(0, 6)
	self.tooltip = nil
	self.iconMat = nil
	self:SetMouseInputEnabled(true)
	self:SetSize(NODE_SIZE, NODE_SIZE)
end

function PANEL:SetNodeInfo(treeID, nodeID)
	self.treeID = treeID
	self.nodeID = nodeID

	local node = ix.unlocks.GetNode(treeID, nodeID)

	if (node and node.icon) then
		self.iconMat = Material(node.icon, "smooth mips")
	end
end

function PANEL:GetState()
	return GetNodeState(self.treeID, self.nodeID)
end

function PANEL:GetNodeData()
	return ix.unlocks.GetNode(self.treeID, self.nodeID)
end

function PANEL:Paint(w, h)
	local node = self:GetNodeData()

	if (!node) then return end

	local state = self:GetState()
	local hovered = self:IsHovered()
	local pulse = (math.sin(CurTime() * 2.5 + self.pulseOffset) + 1) * 0.5

	-- Select colors based on state
	local borderColor, bgColor

	if (state == "unlocked") then
		borderColor = THEME.nodeUnlocked
		bgColor = THEME.nodeUnlockedBg
	elseif (state == "maxed") then
		borderColor = THEME.nodeMaxed
		bgColor = THEME.nodeMaxedBg
	elseif (state == "available") then
		borderColor = THEME.nodeAvailable
		bgColor = THEME.nodeAvailableBg
	elseif (state == "excluded") then
		borderColor = THEME.nodeExcluded
		bgColor = THEME.nodeExcludedBg
	else
		borderColor = THEME.nodeLocked
		bgColor = THEME.nodeLockedBg
	end

	-- Glow effect
	local glow = hovered and 50 or math.Round(10 + pulse * 20)

	if (state == "locked" or state == "excluded") then
		glow = hovered and 30 or math.Round(5 + pulse * 8)
	end

	-- Background
	surface.SetDrawColor(bgColor)
	surface.DrawRect(0, 0, w, h)

	-- Double border with glow
	local ba = math.min(255, borderColor.a + glow)
	surface.SetDrawColor(Color(borderColor.r, borderColor.g, borderColor.b, ba))
	surface.DrawOutlinedRect(0, 0, w, h)
	surface.DrawOutlinedRect(1, 1, w - 2, h - 2)

	-- Corner accents (small brackets at corners)
	if (w >= 36) then
		local cornerLen = math.max(3, math.Round(w * 0.15))
		local t = 1
		surface.SetDrawColor(Color(borderColor.r, borderColor.g, borderColor.b, math.min(255, ba + 30)))
		surface.DrawRect(0, 0, cornerLen, t)
		surface.DrawRect(0, 0, t, cornerLen)
		surface.DrawRect(w - cornerLen, 0, cornerLen, t)
		surface.DrawRect(w - t, 0, t, cornerLen)
		surface.DrawRect(0, h - t, cornerLen, t)
		surface.DrawRect(0, h - cornerLen, t, cornerLen)
		surface.DrawRect(w - cornerLen, h - t, cornerLen, t)
		surface.DrawRect(w - t, h - cornerLen, t, cornerLen)
	end

	-- Hover highlight
	if (hovered) then
		surface.SetDrawColor(Color(borderColor.r, borderColor.g, borderColor.b, 25))
		surface.DrawRect(2, 2, w - 4, h - 4)
	end

	-- All sizes proportional to the panel, so they scale correctly with zoom
	local iconMargin = math.Round(w * 0.05)
	local iconSize = w - (iconMargin * 2)

	if (self.iconMat and !self.iconMat:IsError()) then
		local iconAlpha = (state == "locked") and 100 or 255
		surface.SetDrawColor(255, 255, 255, iconAlpha)
		surface.SetMaterial(self.iconMat)
		surface.DrawTexturedRect(iconMargin, iconMargin, iconSize, iconSize)
	end

	-- Name (truncated) — only draw when panel is large enough to read
	if (w >= 40) then
		local nameY = h + math.Round(h * 0.05)
		local nameColor = (state == "locked") and THEME.textMuted or THEME.text

		DisableClipping(true)
		draw.SimpleText(node.name, "ixUnlockNodeName", w * 0.5, nameY, nameColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

		-- Level indicator for repeatable nodes
		if (node.repeatable) then
			local character = LocalPlayer():GetCharacter()
			local level = character and character:GetNodeLevel(self.treeID, self.nodeID) or 0
			local levelText = level .. "/" .. node.maxLevel
			draw.SimpleText(levelText, "ixUnlockNodeLevel", w * 0.5, nameY + math.Round(h * 0.2), THEME.textMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end
		DisableClipping(false)
	end
end

function PANEL:OnCursorEntered()
	LocalPlayer():EmitSound(SOUND_HOVER)

	-- Show tooltip
	if (IsValid(self.tooltip)) then
		self.tooltip:Remove()
	end

	self.tooltip = vgui.Create("ixUnlockTooltip")
	self.tooltip:SetNodeInfo(self.treeID, self.nodeID)

	-- Dynamically calculate tooltip size based on content
	local padding = Scale(8)
	local headerH = Scale(22)
	local lineH = Scale(14)
	local minW = Scale(180)
	local maxW = Scale(280)

	local node = self:GetNodeData()
	local prereqs = ix.unlocks.GetPrerequisites(self.treeID, self.nodeID)

	-- Determine width: measure title + aurebesh, description lines, cost, prereqs
	surface.SetFont("ixUnlockTooltipTitle")
	local titleW = surface.GetTextSize(node and node.name:upper() or "")
	surface.SetFont("ixUnlockTooltipAurebesh")
	local aurebeshW = surface.GetTextSize("DATA NODE")
	local headerNeedW = titleW + aurebeshW + Scale(6) + padding * 2

	surface.SetFont("ixUnlockTooltipBody")
	local costStr = ix.unlocks.GetCostString(self.treeID, self.nodeID)
	local costW = surface.GetTextSize("Cost: " .. costStr)
	local descW = 0

	if (node and node.description and node.description != "") then
		descW = surface.GetTextSize(node.description)
	end

	-- Pick a width that fits content, clamped to min/max
	local contentNeedW = math.max(headerNeedW, costW + padding * 2, descW + padding * 2)
	local tooltipW = math.Clamp(contentNeedW, minW, maxW)
	local contentW = tooltipW - padding * 2

	-- Calculate height
	local tooltipH = headerH + padding -- header + top padding

	if (node and node.description and node.description != "") then
		local descLines = WrapText(node.description, "ixUnlockTooltipBody", contentW)
		tooltipH = tooltipH + #descLines * lineH
	end

	tooltipH = tooltipH + Scale(4) -- gap before cost
	tooltipH = tooltipH + lineH -- cost line

	-- Path cost line (for locked/available nodes with prerequisites)
	local state = GetNodeState(self.treeID, self.nodeID)

	if (state == "locked" or state == "available") then
		local costStr = ix.unlocks.GetCostString(self.treeID, self.nodeID)
		local pathCostStr = ix.unlocks.GetPathCostString(LocalPlayer(), self.treeID, self.nodeID)

		if (pathCostStr != costStr and pathCostStr != "Free") then
			tooltipH = tooltipH + lineH -- path cost line
		end
	end

	-- Category line
	if (node and node.category and node.category != "") then
		tooltipH = tooltipH + lineH
	end

	tooltipH = tooltipH + lineH -- state line

	if (node and node.repeatable) then
		-- repeatable replaces state, no extra line needed
	end

	if (#prereqs > 0) then
		tooltipH = tooltipH + Scale(2) + Scale(13) -- "Requires:" label
		tooltipH = tooltipH + #prereqs * Scale(13)
	end

	-- Mutual exclusivity section
	if (node and node.mutuallyExclusive and #node.mutuallyExclusive > 0) then
		tooltipH = tooltipH + Scale(2) + Scale(13) -- "Exclusive with:" label
		tooltipH = tooltipH + #node.mutuallyExclusive * Scale(13)
	end

	tooltipH = tooltipH + padding -- bottom padding

	self.tooltip:SetSize(tooltipW, tooltipH)
	self.tooltip:SetDrawOnTop(true)

	self:UpdateTooltipPosition()
end

function PANEL:UpdateTooltipPosition()
	if (!IsValid(self.tooltip)) then return end

	local x, y = self:LocalToScreen(self:GetWide() + Scale(8), 0)

	-- Keep on screen
	if (x + self.tooltip:GetWide() > ScrW()) then
		x = x - self:GetWide() - self.tooltip:GetWide() - Scale(16)
	end

	if (y + self.tooltip:GetTall() > ScrH()) then
		y = ScrH() - self.tooltip:GetTall() - Scale(8)
	end

	self.tooltip:SetPos(x, y)
end

function PANEL:OnCursorExited()
	if (IsValid(self.tooltip)) then
		self.tooltip:Remove()
		self.tooltip = nil
	end
end

function PANEL:OnMousePressed(code)
	if (code == MOUSE_LEFT) then
		LocalPlayer():EmitSound(SOUND_CLICK)

		local state = self:GetState()

		if (state == "available") then
			ix.unlocks.RequestUnlock(self.treeID, self.nodeID)
		end
	elseif (code == MOUSE_RIGHT) then
		local state = self:GetState()

		-- Right-click context menu for unlocked nodes (single node refund)
		if (state == "unlocked" or state == "maxed" or (state == "available" and LocalPlayer():GetCharacter():HasUnlockedNode(self.treeID, self.nodeID))) then
			-- Don't show refund option for non-refundable nodes/trees
			local node = self:GetNodeData()
			local tree = ix.unlocks.GetTree(self.treeID)
			local canRefund = (tree and tree.refundable != false and tree.allowRespec != false) and (!node or node.refundable != false)

			if (!canRefund) then return end
			local menu = DermaMenu()
			local treeID = self.treeID
			local nodeID = self.nodeID
			local refundRatio = (tree and tree.refundRatio) or 1
			local pct = math.Round(refundRatio * 100)
			local refundMsg = pct >= 100 and "Refund this node? Its cost will be returned." or
				"Refund this node? You will receive " .. pct .. "% of its cost back."

			menu:AddOption("Refund Node (" .. pct .. "%)", function()
				Derma_Query(
					refundMsg,
					"Confirm Refund",
					"Confirm", function()
						ix.unlocks.RequestRefundNode(treeID, nodeID)
					end,
					"Cancel", function() end
				)
			end):SetIcon("icon16/arrow_undo.png")

			menu:Open()
		end
	end
end

function PANEL:OnRemove()
	if (IsValid(self.tooltip)) then
		self.tooltip:Remove()
	end
end

vgui.Register("ixUnlockNode", PANEL, "DPanel")
