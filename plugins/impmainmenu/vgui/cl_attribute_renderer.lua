local THEME = ix.ui.THEME
local Scale = ix.ui.Scale

-- ═══════════════════════════════════════════════════════════════════════════════
-- ixAttributeRenderer — Reads and displays character attributes dynamically
-- Uses existing ixAttributeBar + ix.ui.ApplyAttributeBarStyle
-- ═══════════════════════════════════════════════════════════════════════════════

local PANEL = {}

function PANEL:Init()
	self:Dock(TOP)
	self:DockMargin(0, 0, 0, 0)
	self.Paint = function() end
	self.bars = {}
end

function PANEL:Populate(char)
	if (!char) then return end

	-- Clear previous bars
	for _, bar in ipairs(self.bars) do
		if (IsValid(bar)) then bar:Remove() end
	end
	self.bars = {}

	local attrList = ix.attributes.list
	if (!attrList or table.Count(attrList) == 0) then
		self:SetTall(0)
		return
	end

	-- Section header
	local header = ix.ui.CreateSectionHeader(self, "ATTRIBUTES")
	self.bars[#self.bars + 1] = header

	local totalH = header:GetTall() + Scale(10) + Scale(4) -- header + margins

	for k, v in SortedPairs(attrList) do
		local val = char:GetAttribute(k, 0)
		local max = v.maxValue or ix.config.Get("maxAttributes", 100)

		local bar = self:Add("ixAttributeBar")
		bar:Dock(TOP)
		bar:DockMargin(0, 0, 0, Scale(2))
		bar:SetMax(max)
		bar:SetValue(val)
		bar:SetText(L(v.name))
		bar:SetReadOnly()
		ix.ui.ApplyAttributeBarStyle(bar)

		self.bars[#self.bars + 1] = bar
		totalH = totalH + bar:GetTall() + Scale(2)
	end

	self:SetTall(totalH)
end

vgui.Register("ixAttributeRenderer", PANEL, "EditablePanel")
