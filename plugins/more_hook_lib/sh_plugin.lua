local PLUGIN = PLUGIN

PLUGIN.name = "Helix More Hook Lib"
PLUGIN.author = "Sunshi"
PLUGIN.description = "Add more hooks to the helix framework."

if SERVER then
    local character = ix.meta.character

    local _oldSetFaction = character.SetFaction

    function character:SetFaction(faction, ...)
      _oldSetFaction(self, faction, ...)
      hook.Run("OnCharacterTransferred", self, faction)
    end

    local realOpen = ix.storage.Open

    function ix.storage.Open(client, inventory, info)
        info = info or {}
        
        if hook.Run("CanAccessContainer", client, inventory, info) != false then

        info.OnPlayerClose = function(ply)
            hook.Run("OnContainerClosed", ply, inventory, info)
        end

        if not ix.storage.InUse(inventory) then
            hook.Run("OnContainerOpened", client, inventory, info)
        end

        return realOpen(client, inventory, info)

        end
    end

function GetCharacterByID(id)
    for client, character in ix.util.GetCharacters() do
       if character:GetID() == id then return character end
    end
end

function character:Transfer(faction)       
    if self:GetPlayer():HasWhitelist(ix.faction.GetIndex(faction)) then
        self:SetFaction(ix.faction.GetIndex(faction))
    end
end

net.Receive("ixStorageMoneyTake", function(length, client)

        if (CurTime() < (client.ixStorageMoneyTimer or 0)) then
            return
        end

        local character = client:GetCharacter()

        if (!character) then
            return
        end

        local storageID = net.ReadUInt(32)
        local amount = net.ReadUInt(32)

        local inventory = client.ixOpenStorage

        if (!inventory or !inventory.storageInfo or storageID != inventory:GetID()) then
            return
        end

        local entity = inventory.storageInfo.entity

        if (!IsValid(entity) or
            (!entity:IsPlayer() and (!isfunction(entity.GetMoney) or !isfunction(entity.SetMoney))) or
            (entity:IsPlayer() and !entity:GetCharacter())) then
            return
        end

        entity = entity:IsPlayer() and entity:GetCharacter() or entity
        amount = math.Clamp(math.Round(tonumber(amount) or 0), 0, entity:GetMoney())

        if (amount == 0) then
            return
        end
       
        if hook.Run("CanTakeMoney",character,entity) == false then return end

        character:SetMoney(character:GetMoney() + amount)

        local total = entity:GetMoney() - amount
        entity:SetMoney(total)

        net.Start("ixStorageMoneyUpdate")
            net.WriteUInt(storageID, 32)
            net.WriteUInt(total, 32)
        net.Send(inventory:GetReceivers())

        ix.log.Add(client, "storageMoneyTake", entity, amount, total)

        client.ixStorageMoneyTimer = CurTime() + 0.5
    end)

else


end