local THEME = ix.ui.THEME
local Scale = ix.ui.Scale

-- ═══════════════════════════════════════════════════════════════════════════════
-- ixStatsPanel — Health and armor display with efficient per-frame updates.
-- Weight is handled separately under the inventory grid.
-- ═══════════════════════════════════════════════════════════════════════════════

local PANEL = {}

function PANEL:Init()
	self:Dock(TOP)

	local rowH = Scale(22)
	local gap = Scale(2)
	self:SetTall(rowH * 2 + gap)
end

function PANEL:Paint(w, h)
	local ply = LocalPlayer()
	if (!IsValid(ply)) then return end

	local rowH = Scale(22)
	local barPad = Scale(8)
	local labelW = Scale(80)

	-- Health row
	self:DrawStatRow(w, 0, rowH, barPad, labelW, "HEALTH", ply:Health(), ply:GetMaxHealth(), THEME.ready, 0)

	-- Armor row
	self:DrawStatRow(w, rowH + Scale(2), rowH, barPad, labelW, "ARMOR", ply:Armor(), 100, THEME.info, 1)
end

function PANEL:DrawStatRow(w, y, rowH, barPad, labelW, label, value, maxVal, color, index)
	-- Alternating row background
	local bgColor = (index % 2 == 0) and THEME.rowEven or THEME.rowOdd
	surface.SetDrawColor(bgColor)
	surface.DrawRect(0, y, w, rowH)

	-- Label
	draw.SimpleText(label, "ixImpMenuDiag", barPad, y + rowH * 0.5, THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	-- Bar track
	local barX = labelW
	local barW = w - labelW - barPad - Scale(50)
	local barY = y + Scale(6)
	local barH = rowH - Scale(12)

	surface.SetDrawColor(255, 255, 255, 8)
	surface.DrawRect(barX, barY, barW, barH)

	-- Bar fill
	local frac = maxVal > 0 and math.Clamp(value / maxVal, 0, 1) or 0
	surface.SetDrawColor(color.r, color.g, color.b, 80)
	surface.DrawRect(barX, barY, barW * frac, barH)

	-- Value text
	draw.SimpleText(Format("%d / %d", value, maxVal), "ixImpMenuDiag", w - barPad, y + rowH * 0.5, THEME.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

vgui.Register("ixStatsPanel", PANEL, "EditablePanel")
