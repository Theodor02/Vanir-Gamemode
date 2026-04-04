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
ITEM.outfitCategory = "ammo"

local function GetStoredRounds(item)
    local rounds = tonumber(item:GetData("rounds", item.ammoAmount)) or 0
    return math.max(0, rounds)
end

local function MoveStoredRoundsToReserve(item, client)
    if not IsValid(client) then return end
    if not item.ammo then return end

    local rounds = GetStoredRounds(item)
    if rounds <= 0 then return end

    -- Store how much ammo this item actually provided to prevent it from absorbing
    -- more reserve ammo than it originated when unequipped.
    item:SetData("givenRounds", rounds)
    item:SetData("rounds", 0)
    client:GiveAmmo(rounds, item.ammo, true)
end

function ITEM:GetDescription()
    local rounds = self:GetData("rounds", self.ammoAmount)
    return Format(self.description, rounds)
end

ITEM.functions = ITEM.functions or {}
ITEM.functions.combine = {
    name = "Combine",
    tip = "Combine this ammo box with another.",
    icon = "icon16/arrow_join.png",
    OnRun = function(item, data)
        local otherID = data[1]
        local other = ix.item.instances[otherID]
        if not other then return false end

        if other.base ~= "base_arccw_ammo" or other.ammo ~= item.ammo then return false end

        local otherRounds = other:GetData("rounds", other.ammoAmount)
        local myRounds = item:GetData("rounds", item.ammoAmount)
        
        -- Cap the combined box strictly to what it normally spawns with.
        local myMax = item.ammoAmount

        local space = math.max(0, myMax - myRounds)
        if space <= 0 then return false end

        local transfer = math.min(space, otherRounds)
        item:SetData("rounds", myRounds + transfer)
        item.player:EmitSound(item.useSound or "items/ammo_pickup.wav", 110)

        if ((otherRounds - transfer) <= 0) then
            -- Proper network removal syncs with the client without ghosting the VGUI panel
            local itemInv = (other.invID and other.invID > 0) and ix.item.inventories[other.invID] or nil
            if not itemInv and IsValid(item.player) and item.player:GetCharacter() then
                local charInv = item.player:GetCharacter():GetInventory()
                if charInv and charInv:GetItemByID(otherID) then
                    itemInv = charInv
                end
            end

            if itemInv then
                itemInv:Remove(otherID)
            else
                other:Remove()
                if IsValid(item.player) and item.player:GetCharacter() then
                    net.Start("ixInventoryRemove")
                        net.WriteUInt(otherID, 32)
                        net.WriteUInt(item.player:GetCharacter():GetInventory():GetID(), 32)
                    net.Send(item.player)
                end
            end
        else
            other:SetData("rounds", otherRounds - transfer)
        end

        return false
    end,
    OnCanRun = function(item, data)
        if not data or not data[1] then return false end
        local other = ix.item.instances[data[1]]
        if not other then return false end
        if other.base ~= "base_arccw_ammo" or other.ammo ~= item.ammo then return false end

        if item:GetData("givenRounds") or other:GetData("givenRounds") then return false end
        if item:GetData("equip") or other:GetData("equip") then return false end

        local myRounds = item:GetData("rounds", item.ammoAmount)
        local myMax = item.ammoAmount
        local otherRounds = other:GetData("rounds", other.ammoAmount)

        return (myRounds < myMax) and (otherRounds > 0)
    end
}

if SERVER then
    function ITEM:OnEquipped(client)
        MoveStoredRoundsToReserve(self, client)
    end
    
    function ITEM:OnLoadout(client)
        MoveStoredRoundsToReserve(self, client)
    end

    function ITEM:OnUnequipped(client)
        if not IsValid(client) then return end
        if not self.ammo then return end

        local pool = client:GetAmmoCount(self.ammo)
        if pool > 0 then
            -- Only take back up to what this specific ammo item originally granted when equipped,
            -- or the absolute maximum allowed. This stops it from "stealing" unrelated pool ammo
            -- and illegally swelling its own capacity.
            local maxAllowed = self:GetData("givenRounds", self.ammoAmount)
            local amountToTake = math.min(pool, maxAllowed, self.ammoAmount)

            self:SetData("rounds", amountToTake)
            self:SetData("givenRounds", nil)
            
            -- Use SetAmmo instead of RemoveAmmo because RemoveAmmo with string IDs is bugged
            -- natively in some versions of GMod and may fail to remove the reserve ammo.
            client:SetAmmo(math.max(0, pool - amountToTake), self.ammo)
        else
            self:SetData("rounds", 0)
            self:SetData("givenRounds", nil)
        end
    end

    function ITEM:OnSave()
        -- Normally OnSave isn't a native Helix item hook for periodic things, 
        -- but if it's equipped we should probably ensure its rounds are synced 
        -- before a server shut down. (Handled by Character save hook)
    end
end

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        local displayRounds = item:GetData("rounds", item.ammoAmount)
        
-- If givenRounds is set, this ammo box is currently actively feeding 
        -- a player's reserve, so show the player's total reserve instead, capped
        -- at exactly what this box contributed so as to not confuse the UI tally.
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
