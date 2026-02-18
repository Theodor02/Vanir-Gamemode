-- local THEME = {
-- 	background = Color(10, 10, 10, 255),
-- 	frame = Color(191, 148, 53, 255),
-- 	frameSoft = Color(191, 148, 53, 120),
-- 	text = Color(235, 235, 235, 255),
-- 	textMuted = Color(168, 168, 168, 140),
-- 	accent = Color(191, 148, 53, 255),
-- 	accentSoft = Color(191, 148, 53, 220),
-- 	buttonBg = Color(16, 16, 16, 255),
-- 	buttonBgHover = Color(26, 26, 26, 255)
-- }

-- local function Scale(value)
-- 	return math.max(1, math.Round(value * (ScrH() / 900)))
-- end

-- local function PaintSettingsRow(panel, width, height)
-- 	local bg = panel.backgroundIndex == 1 and Color(0, 0, 0, 120) or Color(0, 0, 0, 80)
-- 	surface.SetDrawColor(bg)
-- 	surface.DrawRect(0, 0, width, height)
-- 	surface.SetDrawColor(THEME.frameSoft)
-- 	surface.DrawOutlinedRect(0, 0, width, height)
-- end

-- local Row = vgui.GetControlTable("ixSettingsRow")
-- if (Row and !Row.__ixImpStyled) then
-- 	local baseInit = Row.Init
-- 	function Row:Paint(width, height)
-- 		PaintSettingsRow(self, width, height)
-- 	end

-- 	if (baseInit) then
-- 		function Row:Init()
-- 			baseInit(self)

-- 			if (IsValid(self.text)) then
-- 				self.text:SetFont("ixImpMenuLabel")
-- 				self.text:SetTextColor(THEME.text)
-- 			end
-- 		end
-- 	end
-- 	Row.__ixImpStyled = true
-- end

-- local RowColor = vgui.GetControlTable("ixSettingsRowColor")
-- if (RowColor and !RowColor.__ixImpStyled) then
-- 	local baseInit = RowColor.Init
-- 	function RowColor:Init()
-- 		baseInit(self)

-- 		if (IsValid(self.panel)) then
-- 			self.panel.Paint = function(panel, width, height)
-- 				local padding = self.padding

-- 				surface.SetDrawColor(THEME.background)
-- 				surface.DrawRect(0, 0, width, height)

-- 				surface.SetDrawColor(self.color)
-- 				surface.DrawRect(padding, padding, width - padding * 2, height - padding * 2)
-- 				surface.SetDrawColor(THEME.frameSoft)
-- 				surface.DrawOutlinedRect(0, 0, width, height)
-- 			end
-- 		end
-- 	end
-- 	RowColor.__ixImpStyled = true
-- end

-- local RowColorPicker = vgui.GetControlTable("ixSettingsRowColorPicker")
-- if (RowColorPicker and !RowColorPicker.__ixImpStyled) then
-- 	local basePaint = RowColorPicker.Paint
-- 	function RowColorPicker:Paint(width, height)
-- 		surface.SetDrawColor(THEME.background)
-- 		surface.DrawRect(0, 0, width, height)
-- 		surface.SetDrawColor(THEME.frameSoft)
-- 		surface.DrawOutlinedRect(0, 0, width, height)
-- 	end
-- 	RowColorPicker.__ixImpStyled = true
-- end

-- local Settings = vgui.GetControlTable("ixSettings")
-- if (Settings and !Settings.__ixImpStyled) then
-- 	local baseInit = Settings.Init
-- 	function Settings:Init()
-- 		baseInit(self)

-- 		if (!IsValid(self.header)) then
-- 			self.header = self:Add("Panel")
-- 			self.header:Dock(TOP)
-- 			self.header:SetTall(Scale(28))
-- 			self.header:DockMargin(Scale(8), Scale(8), Scale(8), 0)
-- 			self.header.Paint = function(panel, width, height)
-- 				surface.SetDrawColor(THEME.frameSoft)
-- 				surface.DrawRect(0, 0, width, height)
-- 				surface.DrawOutlinedRect(0, 0, width, height)
-- 				draw.SimpleText("SYSTEM SETTINGS", "ixImpMenuButton", Scale(8), height * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
-- 				draw.SimpleText("CONFIG", "ixImpMenuDiag", width - Scale(8), height * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
-- 			end
-- 		end

-- 		if (IsValid(self.canvas)) then
-- 			self.canvas:DockMargin(Scale(8), Scale(8), Scale(8), Scale(8))
-- 			self.canvas.Paint = function(panel, width, height)
-- 				surface.SetDrawColor(THEME.background)
-- 				surface.DrawRect(0, 0, width, height)
-- 				surface.SetDrawColor(THEME.frameSoft)
-- 				surface.DrawOutlinedRect(0, 0, width, height)
-- 			end
-- 		end
-- 	end

-- 	local baseSearch = Settings.SetSearchEnabled
-- 	function Settings:SetSearchEnabled(bValue)
-- 		baseSearch(self, bValue)

-- 		if (IsValid(self.searchEntry)) then
-- 			self.searchEntry:SetFont("ixImpMenuLabel")
-- 			self.searchEntry.Paint = function(panel, width, height)
-- 				surface.SetDrawColor(THEME.buttonBg)
-- 				surface.DrawRect(0, 0, width, height)
-- 				surface.SetDrawColor(THEME.frameSoft)
-- 				surface.DrawOutlinedRect(0, 0, width, height)
-- 			end
-- 		end
-- 	end

-- 	function Settings:Paint(width, height)
-- 		surface.SetDrawColor(THEME.background)
-- 		surface.DrawRect(0, 0, width, height)
-- 		surface.SetDrawColor(THEME.frameSoft)
-- 		surface.DrawOutlinedRect(0, 0, width, height)
-- 	end

-- 	Settings.__ixImpStyled = true
-- end
