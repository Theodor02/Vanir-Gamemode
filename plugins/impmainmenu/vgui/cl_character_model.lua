local THEME = ix.ui.THEME
local Scale = ix.ui.Scale
local IsMenuClosing = ix.ui.IsMenuClosing

-- ═══════════════════════════════════════════════════════════════════════════════
-- ixCharacterModelPanel — 3D character model display (center column)
-- Matches the existing inventory tab's model behavior: head tracking,
-- bodygroup sync, sequence mirroring, scanning line overlay.
-- ═══════════════════════════════════════════════════════════════════════════════

local MODEL_ANGLE = Angle(0, 180, 0)

local PANEL = {}

function PANEL:Init()
	self:Dock(FILL)

	self.Paint = function(pnl, w, h)
		-- Corner targeting brackets (scan/analysis reticle, no scanlines)
		local bLen = Scale(18)
		local bAlpha = 70
		surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, bAlpha)
		-- Top-left
		surface.DrawRect(0, 0, bLen, 1)
		surface.DrawRect(0, 0, 1, bLen)
		-- Top-right
		surface.DrawRect(w - bLen, 0, bLen, 1)
		surface.DrawRect(w - 1, 0, 1, bLen)
		-- Bottom-left
		surface.DrawRect(0, h - 1, bLen, 1)
		surface.DrawRect(0, h - bLen, 1, bLen)
		-- Bottom-right
		surface.DrawRect(w - bLen, h - 1, bLen, 1)
		surface.DrawRect(w - 1, h - bLen, 1, bLen)
	end
end

function PANEL:SetupModel()
	if (IsValid(self.model)) then
		self.model:Remove()
	end

	-- FOV and camera tuned to frame upper body / torso + head
	local modelFOV = (ScrW() > ScrH() * 1.1) and 48 or 48

	self.model = self:Add("ixModelPanel")
	self.model:Dock(FILL)
	self.model:DockMargin(Scale(2), Scale(2), Scale(2), Scale(2))
	self.model:SetModel(LocalPlayer():GetModel(), LocalPlayer():GetSkin())
	self.model:SetFOV(modelFOV)
	self.model:SetCamPos(Vector(-65, 0, 68))
	self.model:SetLookAt(Vector(0, 0, 62))

	self.model.Think = function(this)
		this:SetVisible(self:IsVisible() and !IsMenuClosing())
	end

	function self.model:LayoutEntity()
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

function PANEL:OnRemove()
	if (IsValid(self.model)) then
		self.model:SetVisible(false)
		self.model:Remove()
		self.model = nil
	end
end

vgui.Register("ixCharacterModelPanel", PANEL, "EditablePanel")
