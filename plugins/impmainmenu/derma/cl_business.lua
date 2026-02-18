local THEME = {
	background = Color(10, 10, 10, 255),
	frame = Color(191, 148, 53, 255),
	frameSoft = Color(191, 148, 53, 120),
	text = Color(235, 235, 235, 255),
	textMuted = Color(168, 168, 168, 140),
	accent = Color(191, 148, 53, 255),
	accentSoft = Color(191, 148, 53, 220),
	buttonBg = Color(16, 16, 16, 255),
	buttonBgHover = Color(26, 26, 26, 255)
}

local function Scale(value)
	return math.max(1, math.Round(value * (ScrH() / 900)))
end

local function ApplyDataPanel(panel, headerText)
	if (!IsValid(panel)) then return end
	panel.Paint = function(this, width, height)
		surface.SetDrawColor(Color(0, 0, 0, 200))
		surface.DrawRect(0, 0, width, height)

		local headerH = Scale(24)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawRect(0, 0, width, headerH)
		surface.DrawOutlinedRect(0, 0, width, height)

		if (headerText) then
			draw.SimpleText(headerText, "ixImpMenuButton", Scale(8), headerH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end
end

local PANEL = {}

function PANEL:Init()
	-- being relative.
	local size = 120
	self:SetSize(size, size * 1.4)
end

function PANEL:Paint(width, height)
	surface.SetDrawColor(THEME.background)
	surface.DrawRect(0, 0, width, height)
	surface.SetDrawColor(THEME.frameSoft)
	surface.DrawOutlinedRect(0, 0, width, height)
end

function PANEL:SetItem(itemTable)
	self.itemName = L(itemTable.name):lower()

	self.price = self:Add("DLabel")
	self.price:Dock(BOTTOM)
	self.price:SetText(itemTable.price and ix.currency.Get(itemTable.price) or L"free":utf8upper())
	self.price:SetContentAlignment(5)
	self.price:SetTextColor(THEME.text)
	self.price:SetFont("ixImpMenuLabel")
	self.price:SetExpensiveShadow(1, Color(0, 0, 0, 200))

	self.name = self:Add("DLabel")
	self.name:Dock(TOP)
	self.name:SetText(itemTable.GetName and itemTable:GetName() or L(itemTable.name))
	self.name:SetContentAlignment(5)
	self.name:SetTextColor(THEME.text)
	self.name:SetFont("ixImpMenuLabel")
	self.name:SetExpensiveShadow(1, Color(0, 0, 0, 200))
	self.name.Paint = function(this, w, h)
		surface.SetDrawColor(THEME.background)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawOutlinedRect(0, 0, w, h)
	end

	self.icon = self:Add("SpawnIcon")
	self.icon:SetZPos(1)
	self.icon:SetSize(self:GetWide(), self:GetWide())
	self.icon:Dock(FILL)
	self.icon:DockMargin(5, 5, 5, 10)
	self.icon:InvalidateLayout(true)
	self.icon:SetModel(itemTable:GetModel(), itemTable:GetSkin())
	self.icon:SetHelixTooltip(function(tooltip)
		ix.hud.PopulateItemTooltip(tooltip, itemTable)
	end)
	self.icon.itemTable = itemTable
	self.icon.DoClick = function(this)
		if (IsValid(ix.gui.checkout)) then
			return
		end

		local parent = ix.gui.business
		local bAdded = parent:BuyItem(itemTable.uniqueID)

		if (bAdded) then
			surface.PlaySound("buttons/button14.wav")
		end
	end
	self.icon.PaintOver = function(this)
		if (itemTable and itemTable.PaintOver) then
			local w, h = this:GetSize()

			itemTable.PaintOver(this, itemTable, w, h)
		end
	end

	if ((itemTable.iconCam and !ICON_RENDER_QUEUE[itemTable.uniqueID]) or itemTable.forceRender) then
		local iconCam = itemTable.iconCam
		iconCam = {
			cam_pos = iconCam.pos,
			cam_fov = iconCam.fov,
			cam_ang = iconCam.ang,
		}
		ICON_RENDER_QUEUE[itemTable.uniqueID] = true

		self.icon:RebuildSpawnIconEx(
			iconCam
		)
	end
end

vgui.Register("ixBusinessItem", PANEL, "DPanel")

PANEL = {}

function PANEL:Init()
	ix.gui.business = self

	self:SetSize(self:GetParent():GetSize())

	local padding = Scale(28)
	local leftWidth = math.max(Scale(220), self:GetWide() * 0.26)

	local leftPanel = self:Add("Panel")
	leftPanel:Dock(LEFT)
	leftPanel:SetWide(leftWidth)
	leftPanel:DockMargin(padding, padding, 0, padding)
	ApplyDataPanel(leftPanel, "CATEGORIES")

	self.categories = leftPanel:Add("DScrollPanel")
	self.categories:Dock(FILL)
	self.categories:DockMargin(Scale(8), Scale(32), Scale(8), Scale(8))
	self.categories.Paint = function(this, w, h) end
	self.categoryPanels = {}

	local catVbar = self.categories:GetVBar()
	catVbar:SetWide(Scale(4))
	catVbar.Paint = function() end
	catVbar.btnUp.Paint = function() end
	catVbar.btnDown.Paint = function() end
	catVbar.btnGrip.Paint = function(this, w, h)
		surface.SetDrawColor(THEME.accentSoft)
		surface.DrawRect(0, 0, w, h)
	end

	local rightPanel = self:Add("Panel")
	rightPanel:Dock(FILL)
	rightPanel:DockMargin(padding, padding, padding, padding)
	ApplyDataPanel(rightPanel, "REQUISITIONS")

	self.scroll = rightPanel:Add("DScrollPanel")
	self.scroll:Dock(FILL)
	self.scroll:DockMargin(Scale(8), Scale(72), Scale(8), Scale(56))
	self.scroll.Paint = function(this, w, h) end

	local itemsVbar = self.scroll:GetVBar()
	itemsVbar:SetWide(Scale(4))
	itemsVbar.Paint = function() end
	itemsVbar.btnUp.Paint = function() end
	itemsVbar.btnDown.Paint = function() end
	itemsVbar.btnGrip.Paint = function(this, w, h)
		surface.SetDrawColor(THEME.accentSoft)
		surface.DrawRect(0, 0, w, h)
	end

	self.search = rightPanel:Add("DTextEntry")
	self.search:Dock(TOP)
	self.search:SetTall(Scale(28))
	self.search:SetFont("ixImpMenuLabel")
	self.search:DockMargin(Scale(8), Scale(32), Scale(8), 0)
	self.search:SetText("")
	self.search:SetPlaceholderText(L("search") or "SEARCH")
	self.search.Paint = function(panel, width, height)
		surface.SetDrawColor(THEME.buttonBg)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawOutlinedRect(0, 0, width, height)

		panel:DrawTextEntryText(THEME.text, THEME.accent, THEME.textMuted)
	end
	self.search.OnTextChanged = function(this)
		local text = self.search:GetText():lower()

		if (self.selected) then
			self:LoadItems(self.selected.category, text:find("%S") and text or nil)
			self.scroll:InvalidateLayout()
		end
	end
	self.search.PaintOver = function(this, cw, ch)
		if (self.search:GetValue() == "" and !self.search:HasFocus()) then
			draw.SimpleText("SCAN", "ixImpMenuDiag", cw - Scale(8), ch * 0.5, THEME.textMuted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end

	self.itemList = self.scroll:Add("DIconLayout")
	self.itemList:Dock(TOP)
	self.itemList:DockMargin(2, 2, 2, 2)
	self.itemList:SetSpaceX(10)
	self.itemList:SetSpaceY(10)
	self.itemList:SetMinimumSize(128, 400)

	local footer = rightPanel:Add("Panel")
	footer:Dock(BOTTOM)
	footer:SetTall(Scale(40))
	footer:DockMargin(Scale(8), Scale(8), Scale(8), Scale(8))
	footer.Paint = function() end

	self.checkout = footer:Add("DButton")
	self.checkout:Dock(FILL)
	self.checkout:SetTextColor(THEME.accent)
	self.checkout:SetTall(Scale(36))
	self.checkout:SetFont("ixImpMenuButton")
	self.checkout:SetText(L("checkout", 0))
	self.checkout.Paint = function(panel, width, height)
		surface.SetDrawColor(THEME.buttonBg)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(THEME.accentSoft)
		surface.DrawOutlinedRect(0, 0, width, height)
		surface.DrawOutlinedRect(1, 1, width - 2, height - 2)
	end
	self.checkout.DoClick = function()
		if (!IsValid(ix.gui.checkout) and self:GetCartCount() > 0) then
			vgui.Create("ixBusinessCheckout"):SetCart(self.cart)
		end
	end

	self.cart = {}

	local dark = Color(0, 0, 0, 50)
	local first = true

	for k, v in pairs(ix.item.list) do
		if (hook.Run("CanPlayerUseBusiness", LocalPlayer(), k) == false) then
			continue
		end

		if (!self.categoryPanels[L(v.category)]) then
			self.categoryPanels[L(v.category)] = v.category
		end
	end

	for category, realName in SortedPairs(self.categoryPanels) do
		local button = self.categories:Add("DButton")
		button:SetTall(Scale(28))
		button:SetText(category)
		button:Dock(TOP)
		button:SetTextColor(THEME.text)
		button:DockMargin(5, 5, 5, 0)
		button:SetFont("ixImpMenuLabel")
		button:SetExpensiveShadow(1, Color(0, 0, 0, 150))
		button.Paint = function(this, w, h)
			local bg = self.selected == this and THEME.buttonBgHover or THEME.buttonBg
			surface.SetDrawColor(bg)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(THEME.frameSoft)
			surface.DrawOutlinedRect(0, 0, w, h)
		end
		button.DoClick = function(this)
			if (self.selected != this) then
				self.selected = this
				self:LoadItems(realName)
				timer.Simple(0.01, function()
					self.scroll:InvalidateLayout()
				end)
			end
		end
		button.category = realName

		if (first) then
			self.selected = button
			first = false
		end

		self.categoryPanels[realName] = button
	end

	if (self.selected) then
		self:LoadItems(self.selected.category)
	end
end

function PANEL:GetCartCount()
	local count = 0

	for _, v in pairs(self.cart) do
		count = count + v
	end

	return count
end

function PANEL:BuyItem(uniqueID)
	local currentCount = self.cart[uniqueID] or 0

	if (currentCount >= 10) then
		return false
	end

	self.cart[uniqueID] = currentCount + 1
	self.checkout:SetText(L("checkout", self:GetCartCount()))

	return true
end

function PANEL:LoadItems(category, search)
	category = category	or "misc"
	local items = ix.item.list

	self.itemList:Clear()
	self.itemList:InvalidateLayout(true)

	for uniqueID, itemTable in SortedPairsByMemberValue(items, "name") do
		if (hook.Run("CanPlayerUseBusiness", LocalPlayer(), uniqueID) == false) then
			continue
		end

		if (itemTable.category == category) then
			if (search and search != "" and !L(itemTable.name):lower():find(search, 1, true)) then
				continue
			end

			self.itemList:Add("ixBusinessItem"):SetItem(itemTable)
		end
	end
end

vgui.Register("ixBusiness", PANEL, "EditablePanel")

hook.Add("CreateMenuButtons", "ixBusiness", function(tabs)
	tabs["business"] = function(container)
		container:Add("ixBusiness")
	end
end)
