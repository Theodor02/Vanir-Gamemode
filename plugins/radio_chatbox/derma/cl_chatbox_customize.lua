local PLUGIN = PLUGIN

local THEME = {
	background = Color(10, 10, 10, 240),
	frame = Color(191, 148, 53, 255),
	frameSoft = Color(191, 148, 53, 120),
	text = Color(235, 235, 235, 245),
	textMuted = Color(168, 168, 168, 140),
	accent = Color(191, 148, 53, 255),
	inputBg = Color(6, 6, 6, 220),
	inputBorder = Color(191, 148, 53, 80)
}

local function Scale(value)
	return math.max(1, math.Round(value * (ScrH() / 900)))
end

local PANEL = {}

function PANEL:Init()
	ix.gui.chatTabCustomize = self

	self:SetTitle("")
	self:SetSize(Scale(280), Scale(360))
	self:Center()
	self:MakePopup()
	self:SetDraggable(true)
	self:ShowCloseButton(false)
	self:DockPadding(Scale(4), Scale(28), Scale(4), Scale(4))

	self.editing = nil  -- set when editing an existing tab

	-- Name field
	self.nameLabel = self:Add("DLabel")
	self.nameLabel:Dock(TOP)
	self.nameLabel:DockMargin(0, 0, 0, 2)
	self.nameLabel:SetText(L("chatTabName"))
	self.nameLabel:SetTextColor(THEME.text)
	self.nameLabel:SetFont("ixImpChatTab")
	self.nameLabel:SizeToContents()

	self.nameEntry = self:Add("DTextEntry")
	self.nameEntry:Dock(TOP)
	self.nameEntry:DockMargin(0, 0, 0, Scale(6))
	self.nameEntry:SetTall(Scale(22))
	self.nameEntry:SetFont("ixImpChatTab")
	self.nameEntry:SetPlaceholderText("Tab name...")
	self.nameEntry.Paint = function(entry, w, h)
		surface.SetDrawColor(THEME.inputBg)
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor(THEME.inputBorder)
		surface.DrawOutlinedRect(0, 0, w, h)

		entry:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
	end

	-- Chat classes label
	self.classLabel = self:Add("DLabel")
	self.classLabel:Dock(TOP)
	self.classLabel:DockMargin(0, 0, 0, 2)
	self.classLabel:SetText(L("chatCustomize"))
	self.classLabel:SetTextColor(THEME.text)
	self.classLabel:SetFont("ixImpChatTab")
	self.classLabel:SizeToContents()

	-- Scrollable class list
	self.classList = self:Add("DScrollPanel")
	self.classList:Dock(FILL)
	self.classList:DockMargin(0, 0, 0, Scale(6))

	local bar = self.classList:GetVBar()
	bar:SetWide(Scale(4))
	bar.Paint = function(_, w, h) surface.SetDrawColor(0, 0, 0, 30); surface.DrawRect(0, 0, w, h) end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(_, w, h) surface.SetDrawColor(THEME.accent); surface.DrawRect(0, 0, w, h) end

	self.classChecks = {}

	-- Populate chat classes
	for className, classData in SortedPairs(ix.chat.classes) do
		local check = self.classList:Add("DCheckBoxLabel")
		check:Dock(TOP)
		check:DockMargin(0, 2, 0, 0)
		check:SetText(classData.name or className)
		check:SetTextColor(THEME.textMuted)
		check:SetValue(true) -- checked = visible in tab
		check:SetFont("ixImpChatTab")
		check.Button.Paint = function(btn, w, h)
			surface.SetDrawColor(THEME.inputBg)
			surface.DrawRect(0, 0, w, h)

			surface.SetDrawColor(THEME.inputBorder)
			surface.DrawOutlinedRect(0, 0, w, h)

			if (btn:GetChecked()) then
				surface.SetDrawColor(THEME.accent)
				surface.DrawRect(2, 2, w - 4, h - 4)
			end
		end

		self.classChecks[className] = check
	end

	-- Check/Uncheck all buttons
	local allPanel = self:Add("Panel")
	allPanel:Dock(BOTTOM)
	allPanel:DockMargin(0, 0, 0, Scale(4))
	allPanel:SetTall(Scale(20))

	local checkAll = allPanel:Add("DButton")
	checkAll:Dock(LEFT)
	checkAll:SetWide(Scale(80))
	checkAll:SetText(L("chatCheckAll"))
	checkAll:SetTextColor(THEME.text)
	checkAll:SetFont("ixImpChatTab")
	checkAll.Paint = function(_, w, h)
		surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 40)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(THEME.inputBorder)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
	checkAll.DoClick = function()
		for _, v in pairs(self.classChecks) do
			v:SetValue(true)
		end
	end

	local uncheckAll = allPanel:Add("DButton")
	uncheckAll:Dock(RIGHT)
	uncheckAll:SetWide(Scale(80))
	uncheckAll:SetText(L("chatUncheckAll"))
	uncheckAll:SetTextColor(THEME.text)
	uncheckAll:SetFont("ixImpChatTab")
	uncheckAll.Paint = function(_, w, h)
		surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 40)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(THEME.inputBorder)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
	uncheckAll.DoClick = function()
		for _, v in pairs(self.classChecks) do
			v:SetValue(false)
		end
	end

	-- Submit button
	self.submit = self:Add("DButton")
	self.submit:Dock(BOTTOM)
	self.submit:SetTall(Scale(26))
	self.submit:SetText(L("chatCreateTab"))
	self.submit:SetTextColor(Color(0, 0, 0, 255))
	self.submit:SetFont("ixImpChatTab")
	self.submit.Paint = function(btn, w, h)
		local color = btn:IsHovered() and THEME.accent or THEME.frameSoft
		surface.SetDrawColor(color)
		surface.DrawRect(0, 0, w, h)
	end
	self.submit.DoClick = function()
		local name = self.nameEntry:GetText()

		if (not name or name:Trim() == "") then
			surface.PlaySound("common/talk.wav")
			return
		end

		local filter = {}

		for className, check in pairs(self.classChecks) do
			if (not check:GetChecked()) then
				filter[className] = true
			end
		end

		if (self.editing) then
			self:OnTabUpdated(self.editing, filter, name)
		else
			self:OnTabCreated(name, filter)
		end

		self:Remove()
	end
end

function PANEL:PopulateFromTab(id, filter)
	self.editing = id
	self.nameEntry:SetText(id)
	self.submit:SetText(L("chatUpdateTab"))

	for className, check in pairs(self.classChecks) do
		check:SetValue(not filter[className])
	end
end

function PANEL:OnTabCreated(id, filter) end
function PANEL:OnTabUpdated(id, filter, newID) end

function PANEL:Paint(width, height)
	-- background
	surface.SetDrawColor(THEME.background)
	surface.DrawRect(0, 0, width, height)

	--  outline
	surface.SetDrawColor(THEME.frameSoft)
	surface.DrawOutlinedRect(0, 0, width, height)

	-- Header bar
	local hH = Scale(26)
	surface.SetDrawColor(THEME.frameSoft)
	surface.DrawRect(0, 0, width, hH)

	draw.SimpleText(
		"TAB CONFIGURATION", "ixImpChatHeader",
		Scale(8), hH * 0.5,
		Color(0, 0, 0, 255),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
	)

	-- Close X
	draw.SimpleText(
		"X", "ixImpChatHeader",
		width - Scale(8), hH * 0.5,
		Color(0, 0, 0, 200),
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
	)
end

function PANEL:OnRemove()
	ix.gui.chatTabCustomize = nil
end

vgui.Register("ixChatboxTabCustomize", PANEL, "DFrame")
