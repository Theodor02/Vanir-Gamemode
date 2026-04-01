local THEME = ix.ui.THEME
local Scale = ix.ui.Scale

-- ═══════════════════════════════════════════════════════════════════════════════
-- DYNAMIC SECTION REGISTRY
-- Plugins register sections via hook "PopulateCharacterSections".
-- Each section entry: { id, name, priority, Create(parent, char) }
-- ═══════════════════════════════════════════════════════════════════════════════

-- ixDynamicSections — container that collects plugin-injected sections.
-- Designed to live inside a parent scroll panel (no internal scroll).
local PANEL = {}

function PANEL:Init()
	self:Dock(TOP)
	self.Paint = function() end
	self.sectionPanels = {}
end

function PANEL:Populate(char)
	if (!char) then return end

	-- Clear previous sections
	for _, pnl in ipairs(self.sectionPanels) do
		if (IsValid(pnl)) then pnl:Remove() end
	end
	self.sectionPanels = {}

	-- Collect sections from plugins
	local sections = {}
	hook.Run("PopulateCharacterSections", sections, char, self)

	-- Sort by priority (lower = higher)
	table.sort(sections, function(a, b)
		return (a.priority or 50) < (b.priority or 50)
	end)

	if (#sections == 0) then
		self:SetTall(0)
		return
	end

	-- Create each section
	for _, section in ipairs(sections) do
		if (section.Create) then
			local wrapper = self:Add("EditablePanel")
			wrapper:Dock(TOP)
			wrapper:DockMargin(0, 0, 0, Scale(4))
			wrapper.Paint = function() end

			section:Create(wrapper, char)

			-- Auto-size wrapper to content if not set
			if (wrapper:GetTall() <= 1) then
				wrapper:SizeToChildren(false, true)
			end

			self.sectionPanels[#self.sectionPanels + 1] = wrapper
		end
	end

	-- Size self to fit all children
	self:SizeToChildren(false, true)
end

function PANEL:Refresh()
	local char = LocalPlayer():GetCharacter()
	if (char) then
		self:Populate(char)
	end
end

vgui.Register("ixDynamicSections", PANEL, "EditablePanel")
