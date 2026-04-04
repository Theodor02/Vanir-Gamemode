local THEME = ix.ui.THEME
local Scale = ix.ui.Scale

-- ═══════════════════════════════════════════════════════════════════════════════
-- ixInventoryGridPanel — Wrapper that hosts the existing ixInventory grid
-- inside the unified panel's left column. Includes a weight bar at the bottom.
-- All drag/drop behavior is inherited from ixInventory / ixItemIcon.
-- ═══════════════════════════════════════════════════════════════════════════════

local PANEL = {}

function PANEL:Init()
	self:Dock(LEFT)
	-- Subtle transparent background — no heavy box
	self.Paint = function(pnl, w, h)
		surface.SetDrawColor(0, 0, 0, 80)
		surface.DrawRect(0, 0, w, h)
	end

	self.headerH = Scale(22)
	self.innerPad = Scale(6)
	self.weightBarH = Scale(32)

	-- Weight bar at the bottom
	local hasWeight = (ix.weight != nil)
	if (hasWeight) then
		self.weightBar = self:Add("EditablePanel")
		self.weightBar:Dock(BOTTOM)
		self.weightBar:SetTall(self.weightBarH)
		self.weightBar:DockMargin(0, -Scale(28), 0, 0)
		self.weightBar.Paint = function(pnl, w, h)
			local character = LocalPlayer():GetCharacter()
			if (!character) then return end

			local carry = character:GetData("carry", 0)
			local maxWeight = ix.weight.BaseWeight(character)
			local imperial = ix.option and ix.option.Get("imperial", false) or false
			local isOver = carry > maxWeight

			-- Weight text
			local weightStr
			if (ix.weight.WeightString) then
				weightStr = Format("%s / %s",
					ix.weight.WeightString(carry, imperial),
					ix.weight.WeightString(maxWeight, imperial))
			else
				weightStr = Format("%.1f / %.1f KG", carry, maxWeight)
			end
			
			weightStr = string.upper(weightStr)

			surface.SetFont("ixImpMenuLabel")
			local staticPrefix = "WEIGHT: "
			local twPrefix, thPrefix = surface.GetTextSize(staticPrefix)
			local twVal, thVal = surface.GetTextSize(weightStr)
			
			local textY = math.floor(h * 0.5 - thPrefix * 0.5)

			-- Thin minimal strip on the right Side (inline style)
			local barX = Scale(4) + twPrefix + twVal + Scale(16)
			local barW = w - barX - Scale(4)
			local barH = Scale(2)
			local barY = math.floor(h * 0.5 - barH * 0.5)
			
			-- Draw background track line
			surface.SetDrawColor(255, 255, 255, 8)
			surface.DrawRect(barX, barY, barW, barH)

			-- Draw fill
			local fillFrac = math.Clamp(carry / maxWeight, 0, 1)
			local barColor = isOver and THEME.danger or THEME.accent
			surface.SetDrawColor(barColor.r, barColor.g, barColor.b, 90)
			surface.DrawRect(barX, barY, barW * fillFrac, barH)

			if (isOver) then
				local overFrac = math.Clamp((carry - maxWeight) / maxWeight, 0, 1)
				surface.SetDrawColor(THEME.danger.r, THEME.danger.g, THEME.danger.b, 120)
				surface.DrawRect(barX, barY, barW * overFrac, barH)
			end

			-- Subtle weight text left-aligned, inline with the track
			surface.SetTextColor(THEME.textMuted)
			surface.SetTextPos(Scale(4), textY)
			surface.DrawText(staticPrefix)
			
			surface.SetTextColor(barColor.r, barColor.g, barColor.b, 180)
			surface.SetTextPos(Scale(4) + twPrefix, textY)
			surface.DrawText(weightStr)
		end
	end

	-- Canvas holds the ixInventory grid
	self.canvas = self:Add("EditablePanel")
	self.canvas:Dock(FILL)
	-- Add extra negative space below inventory rows
	self.canvas:DockMargin(self.innerPad, self.headerH + self.innerPad, self.innerPad, Scale(32))
	self.canvas.Paint = function() end
end

function PANEL:SetupInventory(bgPanel, rightFixedW, padding)
	local char = LocalPlayer():GetCharacter()
	if (!char) then return end

	local inventory = char:GetInventory()
	if (!inventory) then return end

	self.bgPanel = bgPanel
	self.rightFixedW = rightFixedW
	self.padding = padding

	-- Create the grid
	local panel = self.canvas:Add("ixInventory")
	panel:SetPos(0, 0)
	panel:SetDraggable(false)
	panel:SetSizable(false)
	panel:SetTitle(nil)
	panel.bNoBackgroundBlur = true
	panel.childPanels = {}

	-- Custom grid drawing to reduce grid visibility
	panel.Paint = function(pnl, w, h)
		local iconSize = pnl.iconSize or Scale(64)
		local gridW = math.ceil(w / iconSize)
		local gridH = math.ceil(h / iconSize)

		-- Soft internal grid lines (10-20% opacity)
		surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 25)

		for x = 0, gridW - 1 do
			for y = 0, gridH - 1 do
				surface.DrawOutlinedRect(x * iconSize, y * iconSize, iconSize, iconSize)
			end
		end

		-- Draw slightly stronger outer boundary
		surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 80)
		surface.DrawOutlinedRect(0, 0, w, h)
	end

	self.gridPanel = panel

	local canvas = self.canvas
	local innerPad = self.innerPad
	local leftPanel = self

	local function UpdateInventoryScale(canvasW, canvasH)
		if (!inventory) then return end
		local invW, invH = inventory:GetSize()

		if (!canvasW or !canvasH) then
			canvasW, canvasH = canvas:GetSize()
		end
		if (canvasH <= 1) then return end

		local iconSize = math.floor(canvasH / invH)

		local maxW = bgPanel:GetWide() - rightFixedW - padding * 4
		if (maxW > 0 and iconSize * invW > maxW) then
			iconSize = math.floor(maxW / invW)
		end
		if (iconSize < 1) then iconSize = 1 end

		panel:SetMinWidth(0)
		panel:SetMinHeight(0)
		panel:SetIconSize(iconSize)
		panel:SetGridSize(invW, invH)
		panel:RebuildItems()

		local gridW = iconSize * invW
		local gridH = iconSize * invH
		panel:SetPos(0, math.floor((canvasH - gridH) * 0.5))

		leftPanel:SetWide(gridW + innerPad * 2)
	end

	canvas.PerformLayout = function(_, w, h)
		UpdateInventoryScale(w, h)
	end

	panel:SetIconSize(1)
	panel:SetInventory(inventory)

	ix.gui.inv1 = panel
	ix.gui.menuInventoryContainer = canvas

	-- Auto-open bags
	if (ix.option.Get("openBags", true)) then
		for _, v in pairs(inventory:GetItems()) do
			if (!v.isBag) then continue end
			v.functions.View.OnClick(v)
		end
	end

	-- Defer initial scaling
	timer.Simple(0, function()
		if (IsValid(canvas)) then
			canvas:InvalidateLayout(true)
		end
	end)
end

function PANEL:PaintOver(w, h)
	local headerH = self.headerH

	-- Gold bar header (consistent with main menu visual language)
	surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 210)
	surface.DrawRect(0, 0, w, headerH)

	-- "FIELD INVENTORY" label (black text on gold)
	draw.SimpleText("FIELD INVENTORY", "ixImpMenuLabel", Scale(8), headerH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	-- Item count (Aurebesh, right-aligned, black on gold)
	local inventory = LocalPlayer():GetCharacter() and LocalPlayer():GetCharacter():GetInventory()
	if (inventory) then
		local count = 0
		for _, items in pairs(inventory.slots or {}) do
			for _, data in pairs(items) do
				if (data.id) then count = count + 1 end
			end
		end

		draw.SimpleText(
			Format("%d ITEMS", count),
			"ixImpMenuAurebesh",
			w - Scale(8), headerH * 0.5,
			Color(0, 0, 0, 200),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
		)
	end
end

vgui.Register("ixInventoryGridPanel", PANEL, "EditablePanel")
