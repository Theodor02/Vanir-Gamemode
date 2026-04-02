ITEM.name = "ArcCW Ammo Base"
ITEM.model = "models/Items/BoxSRounds.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.ammo = "pistol"        -- ArcCW/HL2 ammo type string (e.g. "pistol", "smg1", "buckshot")
ITEM.ammoAmount = 30        -- default rounds per box
ITEM.maxRounds = 90         -- maximum rounds that can be stored in one box
ITEM.description = "A box containing %s rounds."
ITEM.category = "Ammunition"
ITEM.useSound = "items/ammo_pickup.wav"

-- inventory_ammo reads ITEM.ammo and ITEM:GetData("rounds", ITEM.ammoAmount) to sync
-- the player's reserve pool. No explicit use function is needed; having this item in
-- the inventory is enough for inventory_ammo to provide the rounds to the player.

function ITEM:GetDescription()
    local rounds = self:GetData("rounds", self.ammoAmount)
    return Format(self.description, rounds)
end

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        draw.SimpleTextOutlined(
            item:GetData("rounds", item.ammoAmount),
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
