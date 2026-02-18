local RECEIVER_NAME = "ixInventoryItem"

ICON_RENDER_QUEUE = ICON_RENDER_QUEUE or {}

local THEME = {
	background = Color(0, 0, 0, 200),
	frame = Color(191, 148, 53, 255),
	frameSoft = Color(191, 148, 53, 120),
	text = Color(235, 235, 235, 255),
	textMuted = Color(168, 168, 168, 140),
	accent = Color(191, 148, 53, 255),
	accentSoft = Color(191, 148, 53, 220),
	buttonBg = Color(16, 16, 16, 255),
	buttonBgHover = Color(26, 26, 26, 255),
	danger = Color(180, 60, 60, 255),
	ready = Color(60, 170, 90, 255)
}

local function Scale(value)
	return math.max(1, math.Round(value * (ScrH() / 900)))
end

local function IsMenuClosing()
	return IsValid(ix.gui.menu) and ix.gui.menu.bClosing
end

-- Helper icon re-render

local function RenderNewIcon(panel, itemTable)
	local model = itemTable:GetModel()

	if ((itemTable.iconCam and !ICON_RENDER_QUEUE[string.lower(model)]) or itemTable.forceRender) then
		local iconCam = itemTable.iconCam
		iconCam = {
			cam_pos = iconCam.pos,
			cam_ang = iconCam.ang,
			cam_fov = iconCam.fov,
		}
		ICON_RENDER_QUEUE[string.lower(model)] = true

		panel.Icon:RebuildSpawnIconEx(iconCam)
	end
end

local function InventoryAction(action, itemID, invID, data)
	net.Start("ixInventoryAction")
		net.WriteString(action)
		net.WriteUInt(itemID, 32)
		net.WriteUInt(invID, 32)
		net.WriteTable(data or {})
	net.SendToServer()
end


local PANEL = {}

AccessorFunc(PANEL, "itemTable", "ItemTable")
AccessorFunc(PANEL, "inventoryID", "InventoryID")

function PANEL:Init()
	self:Droppable(RECEIVER_NAME)
end

function PANEL:OnMousePressed(code)
	if (code == MOUSE_LEFT and self:IsDraggable()) then
		self:MouseCapture(true)
		self:DragMousePress(code)
		self.clickX, self.clickY = input.GetCursorPos()
	elseif (code == MOUSE_RIGHT and self.DoRightClick) then
		self:DoRightClick()
	end
end

function PANEL:OnMouseReleased(code)
	if (!dragndrop.m_ReceiverSlot or dragndrop.m_ReceiverSlot.Name != RECEIVER_NAME) then
		self:OnDrop(dragndrop.IsDragging())
	end

	self:DragMouseRelease(code)
	self:SetZPos(99)
	self:MouseCapture(false)
end

function PANEL:DoRightClick()
	local itemTable = self.itemTable
	local inventory = self.inventoryID

	if (itemTable and inventory) then
		itemTable.player = LocalPlayer()

		local menu = DermaMenu()
		local override = hook.Run("CreateItemInteractionMenu", self, menu, itemTable)

		if (override == true) then
			if (menu.Remove) then
				menu:Remove()
			end
			return
		end

		for k, v in SortedPairs(itemTable.functions) do
			if (k == "drop" or k == "combine" or (v.OnCanRun and v.OnCanRun(itemTable) == false)) then
				continue
			end

			if (v.isMulti) then
				local subMenu, subMenuOption = menu:AddSubMenu(L(v.name or k), function()
					itemTable.player = LocalPlayer()
						local send = true
						if (v.OnClick) then send = v.OnClick(itemTable) end
						if (v.sound) then surface.PlaySound(v.sound) end
						if (send != false) then InventoryAction(k, itemTable.id, inventory) end
					itemTable.player = nil
				end)
				subMenuOption:SetImage(v.icon or "icon16/brick.png")

				if (v.multiOptions) then
					local options = isfunction(v.multiOptions) and v.multiOptions(itemTable, LocalPlayer()) or v.multiOptions

					for _, sub in pairs(options) do
						subMenu:AddOption(L(sub.name or "subOption"), function()
							itemTable.player = LocalPlayer()
								local send = true
								if (sub.OnClick) then send = sub.OnClick(itemTable) end
								if (sub.sound) then surface.PlaySound(sub.sound) end
								if (send != false) then InventoryAction(k, itemTable.id, inventory, sub.data) end
							itemTable.player = nil
						end)
					end
				end
			else
				menu:AddOption(L(v.name or k), function()
					itemTable.player = LocalPlayer()
						local send = true
						if (v.OnClick) then send = v.OnClick(itemTable) end
						if (v.sound) then surface.PlaySound(v.sound) end
						if (send != false) then InventoryAction(k, itemTable.id, inventory) end
					itemTable.player = nil
				end):SetImage(v.icon or "icon16/brick.png")
			end
		end

		-- Drop option last
		local info = itemTable.functions.drop

		if (info and info.OnCanRun and info.OnCanRun(itemTable) != false) then
			menu:AddOption(L(info.name or "drop"), function()
				itemTable.player = LocalPlayer()
					local send = true
					if (info.OnClick) then send = info.OnClick(itemTable) end
					if (info.sound) then surface.PlaySound(info.sound) end
					if (send != false) then InventoryAction("drop", itemTable.id, inventory) end
				itemTable.player = nil
			end):SetImage(info.icon or "icon16/brick.png")
		end

		menu:Open()
		itemTable.player = nil
	end
end

function PANEL:OnDrop(bDragging, inventoryPanel, inventory, gridX, gridY)
	local item = self.itemTable

	if (!item or !bDragging) then return end

	if (!IsValid(inventoryPanel)) then
		local inventoryID = self.inventoryID
		if (inventoryID) then
			InventoryAction("drop", item.id, inventoryID, {})
		end
	elseif (inventoryPanel:IsAllEmpty(gridX, gridY, item.width, item.height, self)) then
		local oldX, oldY = self.gridX, self.gridY
		if (oldX != gridX or oldY != gridY or self.inventoryID != inventoryPanel.invID) then
			self:Move(gridX, gridY, inventoryPanel)
		end
	elseif (inventoryPanel.combineItem) then
		local combineItem = inventoryPanel.combineItem
		local inventoryID = combineItem.invID

		if (inventoryID) then
			combineItem.player = LocalPlayer()
				if (combineItem.functions.combine.sound) then
					surface.PlaySound(combineItem.functions.combine.sound)
				end
				InventoryAction("combine", combineItem.id, inventoryID, {item.id})
			combineItem.player = nil
		end
	end
end

function PANEL:Move(newX, newY, givenInventory, bNoSend)
	local iconSize = givenInventory.iconSize
	local oldX, oldY = self.gridX, self.gridY
	local oldParent = self:GetParent()

	if (givenInventory:OnTransfer(oldX, oldY, newX, newY, oldParent, bNoSend) == false) then
		return
	end

	local x = (newX - 1) * iconSize
	local y = (newY - 1) * iconSize

	self.gridX = newX
	self.gridY = newY

	self:SetParent(givenInventory)
	self:SetPos(x, y)

	if (self.slots) then
		for _, v in ipairs(self.slots) do
			if (IsValid(v) and v.item == self) then
				v.item = nil
			end
		end
	end

	self.slots = {}

	for currentX = 1, self.gridW do
		for currentY = 1, self.gridH do
			local slot = givenInventory.slots[self.gridX + currentX - 1][self.gridY + currentY - 1]
			slot.item = self
			self.slots[#self.slots + 1] = slot
		end
	end
end

function PANEL:PaintOver(width, height)
	surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 80)
	surface.DrawOutlinedRect(0, 0, width, height)

	local itemTable = self.itemTable
	if (itemTable and itemTable.PaintOver) then
		itemTable.PaintOver(self, itemTable, width, height)
	end
end

function PANEL:ExtraPaint(width, height)
end

function PANEL:Paint(width, height)
	surface.SetDrawColor(THEME.buttonBg)
	surface.DrawRect(0, 0, width, height)

	self:ExtraPaint(width, height)
end

vgui.Register("ixItemIcon", PANEL, "SpawnIcon")


-- ixInventory 
PANEL = {}
DEFINE_BASECLASS("DFrame")

AccessorFunc(PANEL, "iconSize", "IconSize", FORCE_NUMBER)
AccessorFunc(PANEL, "bHighlighted", "Highlighted", FORCE_BOOL)

function PANEL:Init()
	self:SetIconSize(ScreenScale(32))
	self:ShowCloseButton(false)
	self:SetDraggable(true)
	self:SetSizable(true)
	self:SetTitle(L"inv")
	self:Receiver(RECEIVER_NAME, self.ReceiveDrop)

	self.btnMinim:SetVisible(false)
	self.btnMinim:SetMouseInputEnabled(false)
	self.btnMaxim:SetVisible(false)
	self.btnMaxim:SetMouseInputEnabled(false)

	self.panels = {}
end

function PANEL:Paint(width, height)
	if (self.bNoBackgroundBlur) then
		local scanY = CurTime() * 25 % height
		surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 8)
		surface.DrawRect(0, scanY, width, 1)
	else
		surface.SetDrawColor(THEME.background)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawOutlinedRect(0, 0, width, height)
	end
end

function PANEL:GetPadding(index)
	return select(index, self:GetDockPadding())
end

function PANEL:SetTitle(text)
	if (text == nil) then
		self.oldPadding = {self:GetDockPadding()}

		self.lblTitle:SetText("")
		self.lblTitle:SetVisible(false)

		self:DockPadding(0, 0, 0, 0)
	else
		if (self.oldPadding) then
			self:DockPadding(unpack(self.oldPadding))
			self.oldPadding = nil
		end

		BaseClass.SetTitle(self, text)
	end
end

function PANEL:FitParent(invWidth, invHeight)
	local parent = self:GetParent()
	if (!IsValid(parent)) then return end

	local width, height = parent:GetSize()
	local iconSizeW = math.floor(width / invWidth)
	local iconSizeH = math.floor(height / invHeight)
	local iconSize = math.min(iconSizeW, iconSizeH)

	self:SetIconSize(iconSize)
	self:SetSize(iconSize * invWidth, iconSize * invHeight)
end

function PANEL:OnRemove()
	if (self.childPanels) then
		for _, v in ipairs(self.childPanels) do
			if (v != self) then
				v:Remove()
			end
		end
	end
end

function PANEL:ViewOnly()
	self.viewOnly = true

	for _, icon in pairs(self.panels) do
		icon.OnMousePressed = nil
		icon.OnMouseReleased = nil
		icon.doRightClick = nil
	end
end

function PANEL:SetInventory(inventory, bFitParent)
	if (inventory.slots) then
		local invWidth, invHeight = inventory:GetSize()
		self.invID = inventory:GetID()

		if (IsValid(ix.gui.inv1) and ix.gui.inv1.childPanels and inventory != LocalPlayer():GetCharacter():GetInventory()) then
			self:SetIconSize(ix.gui.inv1:GetIconSize())
			self:SetPaintedManually(true)
			self.bNoBackgroundBlur = true

			ix.gui.inv1.childPanels[#ix.gui.inv1.childPanels + 1] = self
		elseif (bFitParent) then
			self:FitParent(invWidth, invHeight)
		else
			self:SetSize(self.iconSize, self.iconSize)
		end

		self:SetGridSize(invWidth, invHeight)

		for x, items in pairs(inventory.slots) do
			for y, data in pairs(items) do
				if (!data.id) then continue end

				local item = ix.item.instances[data.id]

				if (item and !IsValid(self.panels[item.id])) then
					local icon = self:AddIcon(
						item:GetModel() or "models/props_junk/popcan01a.mdl",
						x, y, item.width, item.height, item:GetSkin()
					)

					if (IsValid(icon)) then
						icon:SetHelixTooltip(function(tooltip)
							ix.hud.PopulateItemTooltip(tooltip, item)
						end)

						self.panels[item.id] = icon
					end
				end
			end
		end
	end
end

function PANEL:SetGridSize(w, h)
	local iconSize = self.iconSize
	local newWidth = w * iconSize
	local newHeight = h * iconSize

	self.gridW = w
	self.gridH = h

	self:SetSize(newWidth, newHeight)
	self:SetMinWidth(newWidth)
	self:SetMinHeight(newHeight)
	self:BuildSlots()
end

function PANEL:PerformLayout(width, height)
	BaseClass.PerformLayout(self, width, height)

	if (self.Sizing and self.gridW and self.gridH) then
		local newWidth = width / self.gridW
		local newHeight = height / self.gridH

		self:SetIconSize(math.min(newWidth, newHeight))
		self:RebuildItems()
	end
end

function PANEL:BuildSlots()
	local iconSize = self.iconSize

	self.slots = self.slots or {}

	for _, v in ipairs(self.slots) do
		for _, v2 in ipairs(v) do
			v2:Remove()
		end
	end

	self.slots = {}

	for x = 1, self.gridW do
		self.slots[x] = {}

		for y = 1, self.gridH do
			local slot = self:Add("DPanel")
			slot:SetZPos(-999)
			slot.gridX = x
			slot.gridY = y
			slot:SetPos((x - 1) * iconSize, (y - 1) * iconSize)
			slot:SetSize(iconSize, iconSize)
			slot.Paint = function(_, w, h)
				surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 25)
				if (x < self.gridW) then
					surface.DrawRect(w - 1, 0, 1, h)
				end
				if (y < self.gridH) then
					surface.DrawRect(0, h - 1, w, 1)
				end
			end

			self.slots[x][y] = slot
		end
	end
end

function PANEL:RebuildItems()
	local iconSize = self.iconSize

	for x = 1, self.gridW do
		for y = 1, self.gridH do
			local slot = self.slots[x][y]
			slot:SetPos((x - 1) * iconSize, (y - 1) * iconSize)
			slot:SetSize(iconSize, iconSize)
		end
	end

	for _, v in pairs(self.panels) do
		if (IsValid(v)) then
			v:SetPos(self.slots[v.gridX][v.gridY]:GetPos())
			v:SetSize(v.gridW * iconSize, v.gridH * iconSize)
		end
	end
end

function PANEL:PaintDragPreview(width, height, mouseX, mouseY, itemPanel)
	local iconSize = self.iconSize
	local item = itemPanel:GetItemTable()

	if (item) then
		local inventory = ix.item.inventories[self.invID]
		local dropX = math.ceil((mouseX - (itemPanel.gridW - 1) * iconSize) / iconSize)
		local dropY = math.ceil((mouseY - (itemPanel.gridH - 1) * iconSize) / iconSize)

		local hoveredPanel = vgui.GetHoveredPanel()

		if (IsValid(hoveredPanel) and hoveredPanel != itemPanel and hoveredPanel.GetItemTable) then
			local hoveredItem = hoveredPanel:GetItemTable()

			if (hoveredItem) then
				local info = hoveredItem.functions.combine

				if (info and info.OnCanRun and info.OnCanRun(hoveredItem, {item.id}) != false) then
					surface.SetDrawColor(ColorAlpha(derma.GetColor("Info", self, Color(200, 0, 0)), 20))
					surface.DrawRect(
						hoveredPanel.x,
						hoveredPanel.y,
						hoveredPanel:GetWide(),
						hoveredPanel:GetTall()
					)

					self.combineItem = hoveredItem
					return
				end
			end
		end

		self.combineItem = nil

		if (inventory) then
			local invWidth, invHeight = inventory:GetSize()

			if (dropX < 1 or dropY < 1 or
				dropX + itemPanel.gridW - 1 > invWidth or
				dropY + itemPanel.gridH - 1 > invHeight) then
				return
			end
		end

		local bEmpty = true

		for x = 0, itemPanel.gridW - 1 do
			for y = 0, itemPanel.gridH - 1 do
				local x2 = dropX + x
				local y2 = dropY + y

				bEmpty = self:IsEmpty(x2, y2, itemPanel)

				if (!bEmpty) then
					goto finish
				end
			end
		end

		::finish::
		local baseColor = bEmpty and THEME.ready or THEME.danger
		local previewColor = ColorAlpha(baseColor, 40)

		surface.SetDrawColor(previewColor)
		surface.DrawRect(
			(dropX - 1) * iconSize,
			(dropY - 1) * iconSize,
			itemPanel:GetWide(),
			itemPanel:GetTall()
		)
	end
end

function PANEL:PaintOver(width, height)
	local panel = self.previewPanel

	if (IsValid(panel)) then
		local itemPanel = (dragndrop.GetDroppable() or {})[1]

		if (IsValid(itemPanel)) then
			self:PaintDragPreview(width, height, self.previewX, self.previewY, itemPanel)
		end
	end

	self.previewPanel = nil
end

function PANEL:IsEmpty(x, y, this)
	return (self.slots[x] and self.slots[x][y]) and (!IsValid(self.slots[x][y].item) or self.slots[x][y].item == this)
end

function PANEL:IsAllEmpty(x, y, width, height, this)
	for x2 = 0, width - 1 do
		for y2 = 0, height - 1 do
			if (!self:IsEmpty(x + x2, y + y2, this)) then
				return false
			end
		end
	end

	return true
end

function PANEL:OnTransfer(oldX, oldY, x, y, oldInventory, noSend)
	local inventories = ix.item.inventories
	local inventory = inventories[oldInventory.invID]
	local inventory2 = inventories[self.invID]
	local item

	if (inventory) then
		item = inventory:GetItemAt(oldX, oldY)

		if (!item) then return false end

		if (hook.Run("CanTransferItem", item, inventories[oldInventory.invID], inventories[self.invID]) == false) then
			return false, "notAllowed"
		end

		if (item.CanTransfer and
			item:CanTransfer(inventory, inventory != inventory2 and inventory2 or nil) == false) then
			return false
		end
	end

	if (!noSend) then
		net.Start("ixInventoryMove")
			net.WriteUInt(oldX, 6)
			net.WriteUInt(oldY, 6)
			net.WriteUInt(x, 6)
			net.WriteUInt(y, 6)
			net.WriteUInt(oldInventory.invID, 32)
			net.WriteUInt(self != oldInventory and self.invID or oldInventory.invID, 32)
		net.SendToServer()
	end

	if (inventory) then
		inventory.slots[oldX][oldY] = nil
	end

	if (item and inventory2) then
		inventory2.slots[x] = inventory2.slots[x] or {}
		inventory2.slots[x][y] = item
	end
end

function PANEL:AddIcon(model, x, y, w, h, skin)
	local iconSize = self.iconSize

	w = w or 1
	h = h or 1

	if (self.slots[x] and self.slots[x][y]) then
		local panel = self:Add("ixItemIcon")
		panel:SetSize(w * iconSize, h * iconSize)
		panel:SetZPos(999)
		panel:InvalidateLayout(true)
		panel:SetModel(model, skin)
		panel:SetPos(self.slots[x][y]:GetPos())
		panel.gridX = x
		panel.gridY = y
		panel.gridW = w
		panel.gridH = h

		local inventory = ix.item.inventories[self.invID]

		if (!inventory) then return end

		local itemTable = inventory:GetItemAt(panel.gridX, panel.gridY)

		panel:SetInventoryID(inventory:GetID())
		panel:SetItemTable(itemTable)

		if (self.panels[itemTable:GetID()]) then
			self.panels[itemTable:GetID()]:Remove()
		end

		if (itemTable.exRender) then
			panel.Icon:SetVisible(false)
			panel.ExtraPaint = function(this, panelX, panelY)
				local exIcon = ikon:GetIcon(itemTable.uniqueID)
				if (exIcon) then
					surface.SetMaterial(exIcon)
					surface.SetDrawColor(color_white)
					surface.DrawTexturedRect(0, 0, panelX, panelY)
				else
					ikon:renderIcon(
						itemTable.uniqueID,
						itemTable.width,
						itemTable.height,
						itemTable:GetModel(),
						itemTable.iconCam
					)
				end
			end
		else
			RenderNewIcon(panel, itemTable)
		end

		panel.slots = {}

		for i = 0, w - 1 do
			for i2 = 0, h - 1 do
				local slot = self.slots[x + i] and self.slots[x + i][y + i2]

				if (IsValid(slot)) then
					slot.item = panel
					panel.slots[#panel.slots + 1] = slot
				else
					for _, v in ipairs(panel.slots) do
						v.item = nil
					end

					panel:Remove()
					return
				end
			end
		end

		return panel
	end
end

function PANEL:ReceiveDrop(panels, bDropped, menuIndex, x, y)
	local panel = panels[1]

	if (!IsValid(panel)) then
		self.previewPanel = nil
		return
	end

	if (bDropped) then
		local inventory = ix.item.inventories[self.invID]

		if (inventory and panel.OnDrop) then
			local dropX = math.ceil((x - (panel.gridW - 1) * self.iconSize) / self.iconSize)
			local dropY = math.ceil((y - (panel.gridH - 1) * self.iconSize) / self.iconSize)

			panel:OnDrop(true, self, inventory, dropX, dropY)
		end

		self.previewPanel = nil
	else
		self.previewPanel = panel
		self.previewX = x
		self.previewY = y
	end
end

vgui.Register("ixInventory", PANEL, "DFrame")

-- Tab creation – INVENTORY layout

local MODEL_ANGLE = Angle(0, 90, 0)

hook.Add("CreateMenuButtons", "ixInventory", function(tabs)
	if (hook.Run("CanPlayerViewInventory") == false) then
		return
	end

	tabs["inv"] = {
		bDefault = true,
		Create = function(info, container)
			local padding = Scale(32)
			local modelFOV = (ScrW() > ScrH() * 1.8) and 15 or 78
			local headerH = Scale(24)
			local innerPad = Scale(6)
			local weightBarH = Scale(20)
			local rightFixedW = Scale(380)

			local bg = container:Add("EditablePanel")
			bg:Dock(FILL)
			bg.Paint = function() end


			-- RIGHT: Operative Status
			local rightPanel = bg:Add("EditablePanel")
			rightPanel:Dock(RIGHT)
			rightPanel:SetWide(rightFixedW)
			rightPanel:DockMargin(padding, padding, padding, padding)


			-- LEFT Inventory 
			local leftPanel = bg:Add("EditablePanel")
			leftPanel:Dock(LEFT)
			leftPanel:DockMargin(padding, padding, 0, padding)
			leftPanel.Paint = function(pnl, w, h)
				-- Panel background
				surface.SetDrawColor(Color(0, 0, 0, 200))
				surface.DrawRect(0, 0, w, h)

				-- Header bar
				surface.SetDrawColor(THEME.frameSoft)
				surface.DrawRect(0, 0, w, headerH)

				-- Single outer border
				surface.SetDrawColor(THEME.frameSoft)
				surface.DrawOutlinedRect(0, 0, w, h)

				draw.SimpleText("FIELD INVENTORY", "ixImpMenuButton", Scale(10), headerH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				-- Item count indicator
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
						w - Scale(10), headerH * 0.5,
						Color(0, 0, 0, 200),
						TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
					)
				end
			end

			local canvas = leftPanel:Add("EditablePanel")
			canvas:Dock(FILL)
			canvas:DockMargin(innerPad, headerH + innerPad, innerPad, innerPad)
			canvas.Paint = function() end

			ix.gui.menuInventoryContainer = canvas

			local panel = canvas:Add("ixInventory")
			panel:SetPos(0, 0)
			panel:SetDraggable(false)
			panel:SetSizable(false)
			panel:SetTitle(nil)
			panel.bNoBackgroundBlur = true
			panel.childPanels = {}

				local inventory = LocalPlayer():GetCharacter():GetInventory()

				local function UpdateInventoryScale(canvasW, canvasH)
					if (!inventory) then return end
					local invW, invH = inventory:GetSize()

					if (!canvasW or !canvasH) then
						canvasW, canvasH = canvas:GetSize()
					end
					if (canvasH <= 1) then return end


					local iconSize = math.floor(canvasH / invH)


					local maxW = bg:GetWide() - rightFixedW - padding * 3
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

				if (inventory) then
					panel:SetInventory(inventory)
				end

			ix.gui.inv1 = panel

			if (ix.option.Get("openBags", true)) then
				for _, v in pairs(inventory:GetItems()) do
					if (!v.isBag) then continue end
					v.functions.View.OnClick(v)
				end
			end

			-- Defer initial scaling to next frame so dock layout is resolved
			timer.Simple(0, function()
				if (IsValid(canvas)) then
					canvas:InvalidateLayout(true)
				end
			end)

			-- Operative Status + Weight bar

			local diagAreaH = Scale(40)
			local hasWeight = (ix.weight != nil)
			local weightBottomH = hasWeight and (weightBarH + Scale(2)) or 0

			local diagSpacer = rightPanel:Add("EditablePanel")
			diagSpacer:Dock(BOTTOM)
			diagSpacer:SetTall(diagAreaH)
			diagSpacer.Paint = function() end

			if (hasWeight) then
				local weightBar = rightPanel:Add("EditablePanel")
				weightBar:Dock(BOTTOM)
				weightBar:SetTall(weightBarH)
				weightBar:DockMargin(0, Scale(2), 0, 0)
				weightBar.Paint = function(pnl, w, h)
					local character = LocalPlayer():GetCharacter()
					if (!character) then return end

					local carry = character:GetData("carry", 0)
					local maxWeight = ix.weight.BaseWeight(character)
					local imperial = ix.option and ix.option.Get("imperial", false) or false
					local isOver = carry > maxWeight

					-- Separator
					surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 40)
					surface.DrawRect(0, 0, w, 1)

					-- Track background
					local barPad = Scale(8)
					local barY = Scale(5)
					local barH = h - barY * 2
					local barMaxW = w - barPad * 2

					surface.SetDrawColor(255, 255, 255, 8)
					surface.DrawRect(barPad, barY, barMaxW, barH)

					-- Normal fill
					local fillFrac = math.Clamp(carry / maxWeight, 0, 1)
					local barColor = isOver and THEME.danger or THEME.accent
					surface.SetDrawColor(barColor.r, barColor.g, barColor.b, 80)
					surface.DrawRect(barPad, barY, barMaxW * fillFrac, barH)

					-- Overweight fill
					if (isOver) then
						local overFrac = math.Clamp((carry - maxWeight) / maxWeight, 0, 1)
						surface.SetDrawColor(THEME.danger.r, THEME.danger.g, THEME.danger.b, 120)
						surface.DrawRect(barPad, barY, barMaxW * overFrac, barH)
					end

					-- Weight text
					local weightStr
					if (ix.weight.WeightString) then
						weightStr = Format("WEIGHT: %s / %s",
							ix.weight.WeightString(carry, imperial),
							ix.weight.WeightString(maxWeight, imperial))
					else
						weightStr = Format("WEIGHT: %.1f / %.1f KG", carry, maxWeight)
					end

					draw.SimpleText(weightStr, "ixImpMenuDiag", w * 0.5, h * 0.5, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
			end

			rightPanel.Paint = function(pnl, w, h)
				local now = CurTime()

				-- Panel background
				surface.SetDrawColor(Color(0, 0, 0, 200))
				surface.DrawRect(0, 0, w, h)

				-- Header bar
				surface.SetDrawColor(THEME.frameSoft)
				surface.DrawRect(0, 0, w, headerH)

				-- Single outer border
				surface.SetDrawColor(THEME.frameSoft)
				surface.DrawOutlinedRect(0, 0, w, h)

				-- Header text
				draw.SimpleText("OPERATIVE STATUS", "ixImpMenuButton", Scale(10), headerH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				local pulse = math.abs(math.sin(now * 1.5))
				draw.SimpleText("MONITORING", "ixImpMenuAurebesh", w - Scale(10), headerH * 0.5, Color(0, 0, 0, math.Round(100 + pulse * 155)), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

				local modelBottom = h - diagAreaH - weightBottomH
				local modelAreaH = modelBottom - headerH
				if (modelAreaH > 0) then
					local scanY = headerH + (now * 30 % modelAreaH)
					surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 18)
					surface.DrawRect(Scale(4), scanY, w - Scale(8), 1)


					surface.SetDrawColor(255, 255, 255, 4)
					for i = 1, 5 do
						local ly = headerH + (i / 6) * modelAreaH
						surface.DrawRect(Scale(4), ly, w - Scale(8), 1)
					end
				end

				local diagY = h - diagAreaH
				surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 40)
				surface.DrawRect(0, diagY, w, 1)

				local barPad = Scale(12)
				local barW = w - barPad * 2
				for i = 1, 3 do
					local phase = now * (0.5 + i * 0.3)
					local fill = 0.3 + (math.sin(phase) + 1) * 0.3
					local by = diagY + Scale(8) + (i - 1) * Scale(10)
					local bh = Scale(5)

					surface.SetDrawColor(255, 255, 255, 8)
					surface.DrawRect(barPad, by, barW, bh)
					surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 80)
					surface.DrawRect(barPad, by, barW * fill, bh)
				end
			end

			local model = rightPanel:Add("ixModelPanel")
			model:Dock(FILL)
			model:DockMargin(Scale(4), headerH + Scale(4), Scale(4), Scale(4))
			model:SetModel(LocalPlayer():GetModel(), LocalPlayer():GetSkin())
			model:SetFOV(modelFOV)
			model:SetCamPos(Vector(-90, 180, 90))
			model:SetLookAt(Vector(0, 0, 35))
			model.Think = function(this)
				this:SetVisible(rightPanel:IsVisible() and !IsMenuClosing())
			end

			function model:LayoutEntity()
				local scrW, scrH = ScrW(), ScrH()
				local xRatio = gui.MouseX() / scrW
				local yRatio = gui.MouseY() / scrH
				local x, _ = self:LocalToScreen(self:GetWide() / 2)
				local xRatio2 = x / scrW
				local entity = self.Entity

				entity:SetPoseParameter("head_pitch", yRatio * 90 - 30)
				entity:SetPoseParameter("head_yaw", (xRatio - xRatio2) * 90 + 20)
				entity:SetAngles(MODEL_ANGLE)
				entity:SetIK(false)

				entity:SetSequence(LocalPlayer():GetSequence())
				entity:SetPoseParameter("move_yaw", 360 * LocalPlayer():GetPoseParameter("move_yaw") - 180)

				if (IsValid(entity)) then
					local bodygroups = LocalPlayer():GetBodyGroups()
					for _, v in pairs(bodygroups) do
						entity:SetBodygroup(v.id, LocalPlayer():GetBodygroup(v.id))
					end

					for k, v in pairs(LocalPlayer():GetMaterials()) do
						entity:SetSubMaterial(k - 1, LocalPlayer():GetSubMaterial(k - 1))
					end
				end

				self:RunAnimation()
			end
		end
	}
end)

hook.Add("PostRenderVGUI", "ixInvHelper", function()
	local pnl = ix.gui.inv1
	hook.Run("PostDrawInventory", pnl)
end)
