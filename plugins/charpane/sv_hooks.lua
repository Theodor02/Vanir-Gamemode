local PLUGIN = PLUGIN

local function ResolveInventoryClient(inv, item)
    local owner = inv and inv.GetOwner and inv:GetOwner()

    if (owner) then
        if (isnumber(owner)) then
            local character = ix.char.loaded[owner]
            if (character) then
                local ownerPlayer = character:GetPlayer()
                if (IsValid(ownerPlayer)) then return ownerPlayer end
            end
        elseif (owner.GetPlayer and isfunction(owner.GetPlayer)) then
            local ownerPlayer = owner:GetPlayer()
            if (IsValid(ownerPlayer)) then return ownerPlayer end
        end
    end

    if (item and IsValid(item.player)) then return item.player end

    if (inv and inv.GetReceivers) then
        local receivers = inv:GetReceivers()
        if (istable(receivers)) then
            for _, receiver in ipairs(receivers) do
                if (IsValid(receiver)) then return receiver end
            end
        end
    end

    return nil
end

function PLUGIN:OnCharacterCreated(client, character)
    ix.inventory.New(character:GetID(), "equipment", function(inv)
        inv.invType = "equipment"
        -- Explicitly set owner here in case character wasn't loaded during New()
        inv:SetOwner(character:GetID())
        character:SetData("equipInv", inv:GetID())
    end)
end

function PLUGIN:CharacterLoaded(character)
    local client = character:GetPlayer()
    local equipInvID = character:GetData("equipInv")

    if (equipInvID) then
        ix.inventory.Restore(equipInvID, 62, 62, function(inv)
            if (IsValid(client) and inv) then
                inv.invType = "equipment"
                -- Ensure owner is set on restored inventory
                inv:SetOwner(character:GetID())
                inv:AddReceiver(client)
                character.equipInv = inv
                
                -- Load initial equipment states
                for _, item in pairs(inv:GetItems()) do
                    if (item.pacData and client.AddPart) then
                        client:AddPart(item.uniqueID, item)
                    end
                    if (item.OnLoadout) then
                        item:OnLoadout(client)
                    end
                end
            end
        end)
    else
        -- Backwards compatibility: Create equipment inventory for older characters on load
        ix.inventory.New(character:GetID(), "equipment", function(inv)
            if (IsValid(client) and inv) then
                inv.invType = "equipment"
                inv:SetOwner(character:GetID())
                character:SetData("equipInv", inv:GetID())
                inv:AddReceiver(client)
                character.equipInv = inv
            end
        end)
    end
end

function PLUGIN:PostPlayerLoadout(client)
    local character = client:GetCharacter()
    if (!character) then return end
    local inv = character.equipInv
    if (inv) then
        for _, item in pairs(inv:GetItems()) do
            if (item.OnLoadout) then
                item:OnLoadout(client)
            end
        end
    end
end

function PLUGIN:CanTransferItem(item, oldInv, newInv)
    if (oldInv and oldInv.invType == "equipment" and newInv and newInv.invType != "equipment") then
        -- Temporarily clear equip state so base weapon CanTransfer checks don't block explicit unequip moves
        item:SetData("equip", nil)
    end
end

function PLUGIN:InventoryItemAdded(oldInv, inv, item)
    if (inv and inv.invType == "equipment") then
        local client = ResolveInventoryClient(inv, item)
        if (!IsValid(client)) then return end

        if (item:GetData("equip") == true) then return end

        -- Set the equip data so native Helix logic (like weapon bases) realizes it's equipped
        item:SetData("equip", true)

        if (item.OnEquipped) then
            item:OnEquipped(client)
        end

        if (item.isBag and item:GetData("id")) then
            local bagInv = ix.item.inventories[item:GetData("id")]
            if (bagInv) then bagInv:AddReceiver(client) end
        end

        -- If it's a weapon or has native Equip, let it handle applying models/giving entities natively
        if (item.Equip and isfunction(item.Equip)) then
            item:Equip(client, true, true)
        elseif (item.OnLoadout) then
            item:OnLoadout(client)
        end

        if (item.bodyGroups) then
            local bodygroup = 0
            for _, v in pairs(item.bodyGroups) do bodygroup = v end
            PLUGIN:UpdateBodygroup(client, item.outfitCategory, bodygroup)
        elseif (item.pacData and client.AddPart) then
            client:AddPart(item.uniqueID, item)
        end
    end
end

function PLUGIN:InventoryItemRemoved(inv, item)
    if (inv and inv.invType == "equipment") then
        local client = ResolveInventoryClient(inv, item)
        if (!IsValid(client)) then return end

        if (item:GetData("equip") == false) then return end

        item:SetData("equip", false)

        if (item.OnUnequipped) then
            item:OnUnequipped(client)
        end

        -- If it's an item with native equip logic (e.g. weapons, pac outfits), trigger its unequip handler natively
        if (item.Unequip and isfunction(item.Unequip)) then
            item:Unequip(client, false, false)
        end

        if (item.isBag and item:GetData("id")) then
            local bagInv = ix.item.inventories[item:GetData("id")]
            if (bagInv) then bagInv:RemoveReceiver(client) end
        end

        if (item.bodyGroups) then
            PLUGIN:UpdateBodygroup(client, item.outfitCategory, 0)
        elseif (item.pacData and client.RemovePart) then
            client:RemovePart(item.uniqueID)
        end
    end
end

function PLUGIN:OnItemTransferred(item, oldInv, newInv)
    -- Handle unequipping when moved OUT OF equipment into a regular inventory
    if (oldInv and oldInv.invType == "equipment" and newInv and newInv.invType != "equipment") then
        local client = ResolveInventoryClient(oldInv, item)
        if (IsValid(client)) then
            if (item:GetData("equip") == false) then return end

            item:SetData("equip", false)

            if (item.OnUnequipped) then
                item:OnUnequipped(client)
            end

            -- If it's an item with native equip logic (e.g. weapons, pac outfits), trigger its unequip handler natively
            if (item.Unequip and isfunction(item.Unequip)) then
                item:Unequip(client, false, false)
            end

            if (item.isBag and item:GetData("id")) then
                local bagInv = ix.item.inventories[item:GetData("id")]
                if (bagInv) then bagInv:RemoveReceiver(client) end
            end

            if (item.bodyGroups) then
                PLUGIN:UpdateBodygroup(client, item.outfitCategory, 0)
            elseif (item.pacData and client.RemovePart) then
                client:RemovePart(item.uniqueID)
            end
        end
    end
end

function PLUGIN:UpdateBodygroup(client, outfitCategory, bodygroup)
    local character = client:GetCharacter()
    if (!character) then return end
    
    local index = client:FindBodygroupByName(outfitCategory)
    if (index > -1) then
        local groups = character:GetData("groups", {})
        groups[index] = bodygroup
        character:SetData("groups", groups)
        client:SetBodygroup(index, bodygroup)
    end
end

function PLUGIN:OnPlayerObserve(client, state)
    if (!client.GetParts) then return end
    
    if (state) then
        if (client:GetParts()) then
            client:ResetParts()
        end
    else
        local character = client:GetCharacter()
        if (!character) then return end
        
        local inv = character.equipInv
        if (inv) then
            for _, item in pairs(inv:GetItems()) do
                if (item.pacData) then
                    client:AddPart(item.uniqueID, item)
                end
            end
        end
    end
end
