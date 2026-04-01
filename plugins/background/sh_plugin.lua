local PLUGIN = PLUGIN

PLUGIN.name = "Backgrounds"
PLUGIN.author = "gumlefar"
PLUGIN.description = "Lets you add a background to a character, instilling special properties in them."

ix.backgrounds = ix.backgrounds or {}
ix.planets = ix.planets or {}

ix.util.Include("sh_definitions.lua")

-- Will run all the characters background OnCreated functions
function PLUGIN:OnCharacterCreated(client, character)
	local backgrounds = character:GetBackgrounds()
	if (backgrounds != nil) then
		for background, _ in pairs(backgrounds) do
			local bck = ix.backgrounds[background]
			if (bck) then
				local func = bck.OnCreated or (function(client, char) return true end)
				func(client, character)
			end
		end
	end
end

if (SERVER) then
	-- Will run all the characters backgrounds OnLoaded functions
	function PLUGIN:CharacterLoaded(character)
		local backgrounds = character:GetBackgrounds()

		if (backgrounds != nil) then
			for background, _ in pairs(backgrounds) do
				local bck = ix.backgrounds[background]
				if (bck) then
					local func = bck.OnLoaded or (function(char) return true end)
					func(character)
				end
			end
		end
	end

	-- Will run all the characters backgrounds OnLoaded functions
	function PLUGIN:PlayerSpawn( player )
		local character = player:GetCharacter()
		if( !character ) then return end

		local backgrounds = character:GetBackgrounds()

		if (backgrounds != nil) then
			for background, _ in pairs(backgrounds) do
				local bck = ix.backgrounds[background]
				if (bck) then
					local func = bck.OnLoaded or (function(char) return true end)
					func(character)
				end
			end
		end
	end
end

ix.char.RegisterVar("backgrounds", {
	field = "background",
	fieldType = ix.type.string,
	default = {},
	category = "attributes",
	bNoDisplay = false,
	OnValidate = function(self, value, payload)
		--if (!ix.backgrounds[value]) then
		--	return false, "invalid", "background"
		--end

		return value
	end,
	OnDisplay = function(self, container, payload)
		-- Use VANIR design system via ix.ui
		local THEME = ix.ui and ix.ui.THEME or {
			background = Color(13, 14, 16, 255),
			text = Color(255, 255, 255, 235),
			textMuted = Color(255, 255, 255, 56),
			accent = Color(201, 168, 76, 255),
		}
		local Scale = ix.ui and ix.ui.Scale or function(v) return math.max(1, math.Round(v * (ScrH() / 900))) end

		local panel = container:Add("DPanel")
		panel:Dock(FILL)
		panel.Paint = function(this, width, height)
			-- VANIR-style: --bg-secondary with thin --sep border
			surface.SetDrawColor(Color(17, 19, 22, 255))
			surface.DrawRect(0, 0, width, height)
			surface.SetDrawColor(Color(255, 255, 255, 15))
			surface.DrawOutlinedRect(0, 0, width, height)
		end

		-- VANIR-style dropdown: dark bg, 1px --sep-strong border, gold accent on focus
		local combo = panel:Add("DComboBox")
		combo:Dock(TOP)
		combo:DockMargin(Scale(12), Scale(12), Scale(12), Scale(8))
		combo:SetFont("ixImpMenuButton")
		combo:SetTextColor(THEME.text)
		combo:SetTall(Scale(32))
		combo.Paint = function(this, width, height)
			surface.SetDrawColor(Color(13, 14, 16, 255)) -- --bg-primary
			surface.DrawRect(0, 0, width, height)
			surface.SetDrawColor(Color(255, 255, 255, 31)) -- --sep-strong
			surface.DrawOutlinedRect(0, 0, width, height)
			if (this:IsMenuOpen()) then
				surface.SetDrawColor(Color(201, 168, 76, 255)) -- --gold accent on open
				surface.DrawRect(0, height - 1, width, 1)
			end
		end

		-- VANIR-style detail card interior
		local selectedBg = nil
		local labelText = "Select a Background for your character above."

		local label = panel:Add("DPanel")
		label:Dock(FILL)
		label:DockMargin(Scale(12), Scale(4), Scale(12), Scale(12))
		label.Paint = function(this, width, height)
			surface.SetDrawColor(Color(13, 14, 16, 255)) -- --bg-primary
			surface.DrawRect(0, 0, width, height)

			local padding = Scale(10)
			local y = padding

			if (selectedBg) then
				-- ORIGIN label + value row
				draw.SimpleText("ORIGIN", "ixImpMenuDiag", padding, y, Color(255, 255, 255, 56), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				local originText = selectedBg.origin or selectedBg.name or ""
				draw.SimpleText(string.upper(originText), "ixImpMenuDiag", width - padding, y, THEME.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
				y = y + Scale(14)

				-- Thin separator
				surface.SetDrawColor(Color(255, 255, 255, 15))
				surface.DrawLine(padding, y, width - padding, y)
				y = y + Scale(8)

				-- Lore/description text (11px sentence case --text-secondary)
				local maxWidth = width - (padding * 2)
				surface.SetFont("ixImpMenuLabel")
				local words = string.Explode(" ", labelText)
				local currentLine = ""

				for i, word in ipairs(words) do
					local testLine = currentLine == "" and word or (currentLine .. " " .. word)
					local testWidth = surface.GetTextSize(testLine)

					if testWidth > maxWidth then
						draw.SimpleText(currentLine, "ixImpMenuLabel", padding, y, Color(255, 255, 255, 115), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
						local _, lh = surface.GetTextSize("A")
						y = y + lh + Scale(2)
						currentLine = word
					else
						currentLine = testLine
					end
				end
				if currentLine ~= "" then
					draw.SimpleText(currentLine, "ixImpMenuLabel", padding, y, Color(255, 255, 255, 115), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
					local _, lh = surface.GetTextSize("A")
					y = y + lh + Scale(6)
				end

				-- Thin separator
				surface.SetDrawColor(Color(255, 255, 255, 15))
				surface.DrawLine(padding, y, width - padding, y)
				y = y + Scale(6)

				-- STARTING EQUIPMENT gold title-bar strip (small)
				if (selectedBg.equipment and #selectedBg.equipment > 0) then
					local eqBarH = Scale(16)
					surface.SetDrawColor(Color(201, 168, 76, 255))
					surface.DrawRect(0, y, width, eqBarH)
					draw.SimpleText("STARTING EQUIPMENT", "ixImpMenuDiag", Scale(8), y + eqBarH * 0.5, Color(13, 14, 16, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					y = y + eqBarH + Scale(4)

					for _, item in ipairs(selectedBg.equipment) do
						draw.SimpleText("— " .. string.upper(item), "ixImpMenuDiag", padding, y, Color(255, 255, 255, 115), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
						y = y + Scale(12)
					end
				end
			else
				-- Default placeholder
				draw.SimpleText(string.upper(labelText), "ixImpMenuLabel", padding, y, Color(255, 255, 255, 56), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			end
		end

		for bkid, bkstruct in SortedPairs(ix.backgrounds) do
			combo:AddChoice(bkstruct.name, bkid)
		end

		combo.OnSelect = function(self, index, value)
			local dat = self:GetOptionData(index)
			if (ix.backgrounds[dat]) then
				payload:Set("backgrounds", {[dat] = true})
				selectedBg = ix.backgrounds[dat]
				labelText = ix.backgrounds[dat].description or ""
			end
		end

		combo:ChooseOption(combo:GetOptionText(1), 1)

		return panel
	end,
})



-- ix.char.RegisterVar("planet", {
-- 	field = "planet",
-- 	fieldType = ix.type.string,
-- 	default = {},
-- 	category = "attributes",
-- 	bNoDisplay = false,
-- 	OnValidate = function(self, value, payload)
-- 		--if (!ix.backgrounds[value]) then
-- 		--	return false, "invalid", "background"
-- 		--end

-- 		return value
-- 	end,
-- 	OnDisplay = function(self, container, payload)
-- 		local THEME = {
-- 			background = Color(10, 10, 10, 240),
-- 			frame = Color(191, 148, 53, 220),
-- 			frameSoft = Color(191, 148, 53, 120),
-- 			text = Color(235, 235, 235, 245),
-- 			textMuted = Color(205, 205, 205, 140),
-- 			accent = Color(191, 148, 53, 255),
-- 			accentSoft = Color(191, 148, 53, 220),
-- 			buttonBg = Color(16, 16, 16, 220),
-- 			buttonBgHover = Color(26, 26, 26, 230)
-- 		}
-- 		local function Scale(value)
-- 			return math.max(1, math.Round(value * (ScrH() / 900)))
-- 		end

-- 		local panel = container:Add("DPanel")
-- 		panel:Dock(FILL)
-- 		panel.Paint = function(this, width, height)
-- 			surface.SetDrawColor(THEME.background)
-- 			surface.DrawRect(0, 0, width, height)
-- 			surface.SetDrawColor(THEME.frameSoft)
-- 			surface.DrawOutlinedRect(0, 0, width, height)
-- 		end

-- 		local combo = panel:Add("DComboBox")
-- 		combo:Dock(TOP)
-- 		combo:DockMargin(Scale(16), Scale(16), Scale(16), Scale(8))
-- 		combo:SetFont("ixImpMenuButton")
-- 		combo:SetTextColor(THEME.text)
-- 		combo:SetTall(Scale(36))
-- 		combo.Paint = function(this, width, height)
-- 			surface.SetDrawColor(THEME.buttonBg)
-- 			surface.DrawRect(0, 0, width, height)
-- 			surface.SetDrawColor(THEME.accentSoft)
-- 			surface.DrawOutlinedRect(0, 0, width, height)
-- 		end

-- 		for bkid, bkstruct in SortedPairs(ix.planets) do
-- 			combo:AddChoice(bkstruct.name, bkid)
-- 		end

-- 		combo.OnSelect = function(self, index, value)
-- 			local dat = self:GetOptionData(index)
-- 			if (ix.planets[dat]) then
-- 				payload:Set("planet", dat)
-- 				labelText = ix.planets[dat].description
-- 			end
-- 		end

-- 		combo:ChooseOption(combo:GetOptionText(1), 1)

-- 		return panel
-- 	end,
-- })



local CHAR = ix.meta.character or {}

-- Helper to add background
function CHAR:AddBackground(background)
	local data = self:GetBackgrounds() or {}
	data[background] = true
	self:SetBackgrounds(data)

end

-- Helper to remove background
function CHAR:RemoveBackground(background)
	local data = self:GetBackgrounds() or {}
	data[background] = nil
	self:SetBackgrounds(data)
end

-- function CHAR:AddPlanet(planet)
-- 	local data = self:GetPlanet() or {}
-- 	data[planet] = true
-- 	self:SetPlanet(data)
-- end

-- function CHAR:RemovePlanet(planet)
-- 	local data = self:GetPlanet() or {}
-- 	data[planet] = nil
-- 	self:SetPlanet(data)
-- end