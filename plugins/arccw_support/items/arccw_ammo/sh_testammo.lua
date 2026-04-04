ITEM.base = "base_arccw_ammo"
ITEM.name = "Test ArcCW Ammo"
ITEM.model = "models/Items/BoxSRounds.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.ammo = "ar2"        -- ArcCW/HL2 ammo type string (e.g. "pistol", "smg1", "buckshot")
ITEM.ammoAmount = 30        -- default rounds per box
ITEM.maxRounds = 90         -- maximum rounds that can be stored in one box
ITEM.description = "A box containing %s rounds."
ITEM.category = "Ammunition"
ITEM.useSound = "items/ammo_pickup.wav"

function ITEM:GetDescription()
    local rounds = self:GetData("rounds", self.ammoAmount)
    return Format(self.description, rounds)
end

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        local displayRounds = item:GetData("rounds", item.ammoAmount)
        
        if item:GetData("givenRounds") then
            displayRounds = math.min(LocalPlayer():GetAmmoCount(item.ammo), item:GetData("givenRounds"))
        end

        draw.SimpleTextOutlined(
            displayRounds,
            "DermaDefault",
            1, 5,
            color_white,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER,
            1,
            color_black
        )
    end
end
