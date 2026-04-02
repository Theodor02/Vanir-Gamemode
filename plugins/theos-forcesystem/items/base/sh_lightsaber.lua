--- Lightsaber Item Base
-- A Helix item base for lightsaber hilts with a KOTOR 2-style
-- attachment/upgrade system. Crystals, lenses, cells, emitters,
-- and other components can be installed via drag-drop (combine).
--
-- Equipping a lightsaber syncs its hilt + crystal to LSCS and
-- gives the player the weapon_lscs SWEP.
--
-- When an attachment is installed, it is **deleted** and its blueprint
-- (uniqueID + data + display info) is stored on the lightsaber.
-- When removed, a brand-new item is created from that blueprint.
-- This avoids all limbo/restore issues across server restarts.
--
-- Override `ITEM.attachmentSlots` in subclass items to add or
-- change slots. Override `ITEM:OnAttachmentChanged()` for custom
-- behaviour when a part is installed/removed.
-- @module item-base.lightsaber

ITEM.name = "Lightsaber"
ITEM.description = "A lightsaber hilt."
ITEM.category = "Lightsabers"
ITEM.model = "models/weapons/starwars/w_anakin_ep2_saber_hilt.mdl"
ITEM.width = 2
ITEM.height = 1
ITEM.isLightsaber = true

--- LSCS hilt class (e.g. "item_saberhilt_katarn"). Must be set by subclass items.
ITEM.lscsHilt = nil

--- Attachment slot definitions — KOTOR 2 style.
-- Keys are slot IDs, values describe the slot.
-- Subclass items can override this table to add / remove slots.
--
-- Each slot:
--   name        — display name
--   accepts     — table of attachmentType strings this slot accepts
--   icon        — icon16 path for UI (optional)
--   description — short help text (optional)
ITEM.attachmentSlots = {
    crystal = {
        name = "Kyber Crystal",
        accepts = {"crystal"},
        icon = "icon16/ruby.png",
        description = "The crystal that determines blade colour and properties.",
    },
    lens = {
        name = "Focusing Lens",
        accepts = {"lens"},
        icon = "icon16/magnifier.png",
        description = "Modifies blade focus and damage characteristics.",
    },
    cell = {
        name = "Power Cell",
        accepts = {"cell"},
        icon = "icon16/lightning.png",
        description = "Determines energy capacity and recharge rate.",
    },
    emitter = {
        name = "Emitter",
        accepts = {"emitter"},
        icon = "icon16/lightbulb.png",
        description = "Controls blade length, width, and stability.",
    },
    grip = {
        name = "Grip",
        accepts = {"grip"},
        icon = "icon16/wrench.png",
        description = "Affects handling and combat performance.",
    },
}

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

--- Return a COPY of the installed attachment blueprints.
-- Stored as item data `"attachmentMeta"` = {slotID = {uniqueID, data, name, ...}, ...}
-- This is the single source of truth — no item instance IDs are stored.
-- @return table
function ITEM:GetAttachments()
    return table.Copy(self:GetData("attachmentMeta", {}))
end

--- Build a blueprint from a live attachment item instance.
-- Captures everything needed to recreate the item later.
-- @param attachItem Item instance
-- @return table blueprint
function ITEM:BuildAttachmentBlueprint(attachItem)
    return {
        uniqueID = attachItem.uniqueID,
        data = table.Copy(attachItem.data or {}),
        -- Display fields (used by client without needing an instance)
        name = attachItem.name,
        modifiers = attachItem.modifiers,
        crystalColor = attachItem.crystalColor,
        lscsBlade = attachItem.lscsBlade,
        attachmentType = attachItem.attachmentType,
    }
end

--- Check whether a given item can be installed in any slot on this saber.
-- Returns the first matching slot ID, or nil.
-- @param attachItem Item instance to check
-- @return string|nil slotID
function ITEM:FindSlotForItem(attachItem)
    local attachType = attachItem.attachmentType
    if not attachType then return nil end

    local attachments = self:GetAttachments()

    for slotID, slotDef in pairs(self.attachmentSlots) do
        if not attachments[slotID] then
            for _, accepted in ipairs(slotDef.accepts) do
                if accepted == attachType then
                    return slotID
                end
            end
        end
    end

    return nil
end

--- Install an attachment item into a slot.
-- The item's blueprint is saved and the item itself should be
-- destroyed by the caller after this returns.
-- @param slotID string
-- @param attachItem Item instance
-- @return boolean success
function ITEM:InstallAttachment(slotID, attachItem)
    if not self.attachmentSlots[slotID] then return false end

    local attachments = self:GetAttachments()
    attachments[slotID] = self:BuildAttachmentBlueprint(attachItem)
    self:SetData("attachmentMeta", attachments)

    self:OnAttachmentChanged(slotID, attachItem, nil)
    return true
end

--- Remove an attachment blueprint from a slot.
-- Returns the blueprint table so the caller can recreate the item.
-- @param slotID string
-- @return table|nil blueprint
function ITEM:RemoveAttachment(slotID)
    local attachments = self:GetAttachments()
    local blueprint = attachments[slotID]
    if not blueprint then return nil end

    attachments[slotID] = nil
    self:SetData("attachmentMeta", attachments)

    self:OnAttachmentChanged(slotID, nil, blueprint)
    return blueprint
end

--- Aggregate a named modifier across all installed attachments.
-- @param key string modifier key (e.g. "damage", "deflection")
-- @param base number starting value (default 0)
-- @return number
function ITEM:GetModifierTotal(key, base)
    local total = base or 0

    for _, blueprint in pairs(self:GetAttachments()) do
        if blueprint.modifiers and blueprint.modifiers[key] then
            total = total + blueprint.modifiers[key]
        end
    end

    return total
end

--- Callback fired when any attachment is added or removed.
-- Override in subclass items for custom logic.
-- @param slotID string
-- @param newItem Item|table|nil  item instance on install, blueprint on removal
-- @param oldItem Item|table|nil
function ITEM:OnAttachmentChanged(slotID, newItem, oldItem)
end

-- ─────────────────────────────────────────────
-- LSCS Sync — push hilt + crystal to LSCS
-- ─────────────────────────────────────────────

--- Sync this lightsaber's hilt and crystal to the LSCS addon.
-- Called on equip and whenever attachments change while equipped.
-- @param client Player
-- @param hand boolean  true = right, false = left
function ITEM:SyncToLSCS(client, hand)
    if not SERVER then return end
    if not client.lscsAddInventory then return end

    local hiltClass = self.lscsHilt
    if not hiltClass then return end

    -- Clear hilt+crystal for this hand first to avoid duplicates.
    -- lscsClearEquipped is called internally by lscsAddInventory for
    -- hilts/crystals, but we explicitly wipe old entries for a clean slate.
    if client.lscsGetInventory then
        local inv = client:lscsGetInventory()
        local equipped = client:lscsGetEquipped()
        for i, class in ipairs(inv) do
            if equipped[i] == hand then
                local obj = LSCS:ClassToItem(class)
                if obj and (obj.type == "hilt" or obj.type == "crystal") then
                    client:lscsEquipItem(i, nil) -- unequip from this hand
                end
            end
        end
    end

    -- Add hilt to LSCS and equip to the chosen hand
    client:lscsAddInventory(hiltClass, hand)

    -- If a crystal is installed, sync its blade class
    local attachments = self:GetAttachments()
    local crystalBP = attachments.crystal
    if crystalBP and crystalBP.lscsBlade then
        client:lscsAddInventory(crystalBP.lscsBlade, hand)
    end

    -- Rebuild the saber
    if client.lscsCraftSaber then
        client:lscsCraftSaber(true)
    end
end

--- Remove this lightsaber from LSCS and re-sync everything else.
-- Wipes the LSCS inventory then re-adds force powers AND any
-- other currently-equipped lightsaber items.
-- @param client Player
function ITEM:UnsyncFromLSCS(client)
    if not SERVER then return end
    if not client.lscsWipeInventory then return end

    client:lscsWipeInventory(true)

    local char = client:GetCharacter()
    if not char then return end

    -- Re-sync granted force powers
    local granted = char:GetData("grantedPowers", {})
    for _, lscsClass in ipairs(granted) do
        client:lscsAddInventory(lscsClass, nil)
    end

    -- Re-sync any OTHER equipped lightsaber items
    local inv = char:GetInventory()
    if inv then
        for _, item in pairs(inv:GetItems()) do
            if item.isLightsaber and item.id ~= self.id then
                local otherEquip = item:GetData("equip")
                if otherEquip then
                    local bRight = (otherEquip ~= "left")
                    item:SyncToLSCS(client, bRight)
                end
            end
        end
    end

    if client.lscsCraftSaber then
        client:lscsCraftSaber(true)
    end
end

-- ─────────────────────────────────────────────
-- Equip / Unequip
-- ─────────────────────────────────────────────

--- Find the lightsaber item (if any) currently equipped to a given hand.
-- @param client Player
-- @param hand string "right" or "left"
-- @return Item|nil
function ITEM:FindSaberOnHand(client, hand)
    local char = client:GetCharacter()
    if not char then return nil end

    local inv = char:GetInventory()
    if not inv then return nil end

    for _, item in pairs(inv:GetItems()) do
        if item.isLightsaber and item.id ~= self.id and item:GetData("equip") == hand then
            return item
        end
    end

    return nil
end

--- Core equip logic. Gives weapon_lscs and syncs to LSCS.
-- @param client Player
-- @param hand string "right" or "left"
function ITEM:Equip(client, hand)
    hand = hand or "right"
    local bRight = (hand ~= "left")

    -- Unequip any other saber already on this hand
    local existing = self:FindSaberOnHand(client, hand)
    if existing then
        existing:Unequip(client)
    end

    self:SetData("equip", hand)

    -- Give the weapon if the player doesn't have it already
    if not client:HasWeapon("weapon_lscs") then
        client:Give("weapon_lscs", true)
    end

    self:SyncToLSCS(client, bRight)
end

--- Core unequip logic.
-- @param client Player
function ITEM:Unequip(client)
    self:SetData("equip", nil)
    self:UnsyncFromLSCS(client)

    -- Only strip the weapon if no other lightsaber is equipped
    local char = client:GetCharacter()
    if char then
        local inv = char:GetInventory()
        if inv then
            local hasOther = false
            for _, item in pairs(inv:GetItems()) do
                if item.isLightsaber and item.id ~= self.id and item:GetData("equip") then
                    hasOther = true
                    break
                end
            end

            if not hasOther then
                client:StripWeapon("weapon_lscs")
            end
        end
    end
end

-- ─────────────────────────────────────────────
-- Inventory Drawing
-- ─────────────────────────────────────────────

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        local equip = item:GetData("equip")
        if equip then
            surface.SetDrawColor(110, 255, 110, 100)
            surface.DrawRect(w - 14, h - 14, 8, 8)
        end

        -- Small crystal colour swatch if a crystal is installed
        local attachments = item:GetData("attachmentMeta", {})
        local crystalBP = attachments.crystal
        if crystalBP and crystalBP.crystalColor then
            surface.SetDrawColor(crystalBP.crystalColor)
            surface.DrawRect(2, h - 10, 8, 8)
        end
    end

    function ITEM:PopulateTooltip(tooltip)
        local equip = self:GetData("equip")
        if equip then
            local name = tooltip:GetRow("name")
            if name then
                name:SetBackgroundColor(derma.GetColor("Success", tooltip))
            end
        end

        -- List installed attachments
        local attachments = self:GetData("attachmentMeta", {})
        for slotID, slotDef in SortedPairs(self.attachmentSlots) do
            local blueprint = attachments[slotID]
            local label

            if blueprint then
                label = slotDef.name .. ": " .. (blueprint.name or "Unknown")
            else
                label = slotDef.name .. ": Empty"
            end

            local row = tooltip:AddRow("attachment_" .. slotID)
            row:SetText(label)
            row:SizeToContents()
        end
    end

    function ITEM:GetDescription()
        local desc = self.description or ""
        local attachments = self:GetData("attachmentMeta", {})
        local mods = {}

        for _, blueprint in pairs(attachments) do
            if blueprint.modifiers then
                for k, v in pairs(blueprint.modifiers) do
                    mods[k] = (mods[k] or 0) + v
                end
            end
        end

        if next(mods) then
            desc = desc .. "\n\nModifiers:"
            for k, v in SortedPairs(mods) do
                local sign = v >= 0 and "+" or ""
                desc = desc .. "\n  " .. k .. ": " .. sign .. v
            end
        end

        return desc
    end
end

-- ─────────────────────────────────────────────
-- Item Functions (right-click menu)
-- ─────────────────────────────────────────────

ITEM.functions.EquipRight = {
    name = "Equip (Right Hand)",
    tip = "Equip this lightsaber to your right hand.",
    icon = "icon16/tick.png",
    OnRun = function(item)
        item:Equip(item.player, "right")
        return false
    end,
    OnCanRun = function(item)
        return not IsValid(item.entity)
            and IsValid(item.player)
            and not item:GetData("equip")
            and hook.Run("CanPlayerEquipItem", item.player, item) ~= false
    end
}

ITEM.functions.EquipLeft = {
    name = "Equip (Left Hand)",
    tip = "Equip this lightsaber to your left hand. Requires a saber in the right hand.",
    icon = "icon16/tick.png",
    OnRun = function(item)
        -- Server-side guard: require right hand occupied
        if not item:FindSaberOnHand(item.player, "right") then
            item.player:NotifyLocalized("rightHandRequired")
            return false
        end

        item:Equip(item.player, "left")
        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        if not IsValid(item.player) then return false end
        if item:GetData("equip") then return false end
        if hook.Run("CanPlayerEquipItem", item.player, item) == false then return false end

        -- Only show if another saber is already in the right hand
        local char = item.player:GetCharacter()
        if not char then return false end

        local inv = char:GetInventory()
        if not inv then return false end

        for _, other in pairs(inv:GetItems()) do
            if other.isLightsaber and other.id ~= item.id and other:GetData("equip") == "right" then
                return true
            end
        end

        return false
    end
}

ITEM.functions.EquipUn = {
    name = "Unequip",
    tip = "Unequip this lightsaber.",
    icon = "icon16/cross.png",
    OnRun = function(item)
        item:Unequip(item.player)
        return false
    end,
    OnCanRun = function(item)
        return not IsValid(item.entity)
            and IsValid(item.player)
            and item:GetData("equip") ~= nil
            and hook.Run("CanPlayerUnequipItem", item.player, item) ~= false
    end
}

-- ─────────────────────────────────────────────
-- Combine (drag-drop) — accepts attachments
-- ─────────────────────────────────────────────

ITEM.functions.combine = {
    tip = "Attach this component to the lightsaber.",
    icon = "icon16/wrench.png",
    OnRun = function(item, data)
        local otherID = data[1]
        local other = ix.item.instances[otherID]
        if not other then return false end

        local client = item.player
        local slotID = item:FindSlotForItem(other)
        if not slotID then
            client:NotifyLocalized("noAvailableSlot")
            return false
        end

        -- Snapshot the attachment before we destroy it
        item:InstallAttachment(slotID, other)

        -- Delete the attachment item from the inventory (and database).
        -- Use the inventory the item actually lives in (could be a bag), not
        -- always the main inventory, otherwise ixInventoryRemove is sent with
        -- the wrong invID and the icon ghost-lingers in the bag panel.
        local itemInv = ix.item.inventories[other.invID]
        if itemInv then
            itemInv:Remove(otherID)
        end

        -- If the saber is currently equipped, re-sync to pick up the new crystal
        local equip = item:GetData("equip")
        if equip and IsValid(client) then
            local bRight = (equip ~= "left")
            item:SyncToLSCS(client, bRight)
        end

        return false
    end,
    OnCanRun = function(item, data)
        if IsValid(item.entity) then return false end
        if not data or not data[1] then return false end

        local other = ix.item.instances[data[1]]
        if not other then return false end

        -- Must have an attachmentType and a free slot
        return item:FindSlotForItem(other) ~= nil
    end,
}

-- ─────────────────────────────────────────────
-- Removal functions per slot (right-click to remove attachments)
-- ─────────────────────────────────────────────

-- Dynamically generate removal functions for each default slot.
-- Subclass items that override attachmentSlots should define their
-- own removal functions, or call ITEM:GenerateRemovalFunctions().
function ITEM:GenerateRemovalFunctions()
    for slotID, slotDef in pairs(self.attachmentSlots) do
        local funcName = "Remove_" .. slotID
        self.functions[funcName] = {
            name = "Remove " .. slotDef.name,
            tip = "Remove the installed " .. slotDef.name .. " from this lightsaber.",
            icon = slotDef.icon or "icon16/delete.png",
            OnRun = function(item)
                local client = item.player
                local char = client:GetCharacter()
                if not char then return false end

                local inv = char:GetInventory()
                if not inv then return false end

                -- Peek at the blueprint without removing it yet so we can
                -- check that there is room in the inventory first.  Removing
                -- the attachment and then failing to add the item would
                -- permanently destroy the component.
                local peekAttachments = item:GetData("attachmentMeta", {})
                local peekBlueprint = peekAttachments[slotID]
                if not peekBlueprint then return false end

                local template = ix.item.list[peekBlueprint.uniqueID]
                local w = template and template.width  or 1
                local h = template and template.height or 1
                local emptyX = inv:FindEmptySlot(w, h)
                if not emptyX then
                    client:NotifyLocalized("inventoryFull")
                    return false
                end

                -- Pull the blueprint and clear the slot
                local blueprint = item:RemoveAttachment(slotID)
                if not blueprint then return false end

                -- Strip installedIn from saved data so the new item isn't locked
                local itemData = table.Copy(blueprint.data or {})
                itemData.installedIn = nil

                -- Create a brand-new item from the blueprint in the player's inventory
                local addX = inv:Add(blueprint.uniqueID, 1, itemData)
                if not addX then
                    -- Unexpected failure — restore the blueprint so the item
                    -- is not silently destroyed.
                    local restoreAttachments = item:GetData("attachmentMeta", {})
                    restoreAttachments[slotID] = blueprint
                    item:SetData("attachmentMeta", restoreAttachments)
                    client:NotifyLocalized("inventoryFull")
                    return false
                end

                -- Re-sync if equipped
                local equip = item:GetData("equip")
                if equip and IsValid(client) then
                    local bRight = (equip ~= "left")
                    item:SyncToLSCS(client, bRight)
                end

                return false
            end,
            OnCanRun = function(item)
                if IsValid(item.entity) then return false end

                local attachments = item:GetData("attachmentMeta", {})
                return attachments[slotID] ~= nil
            end,
        }
    end
end

-- ─────────────────────────────────────────────
-- Lifecycle Hooks
-- ─────────────────────────────────────────────

--- Called by Helix when the owning character's loadout is applied (spawn/rejoin).
-- Re-equips the saber if it was equipped before.
function ITEM:OnLoadout()
    if not SERVER then return end

    local client = self.player
    if not IsValid(client) then return end

    -- Migrate old-style attachment data (item IDs) to new blueprint format
    self:MigrateOldAttachments()

    local equip = self:GetData("equip")
    if not equip then return end

    -- Re-give the weapon (PlayerLoadout strips all weapons before OnLoadout fires)
    if not client:HasWeapon("weapon_lscs") then
        client:Give("weapon_lscs", true)
    end

    -- Delay LSCS sync so it runs AFTER the forcesystem plugin's
    -- syncPowersToLSCS (which fires on a 1s timer and wipes LSCS inventory).
    local itemID = self.id
    timer.Simple(1.5, function()
        local inst = ix.item.instances[itemID]
        if not inst then return end
        if not IsValid(client) then return end
        if not client:GetCharacter() then return end

        local curEquip = inst:GetData("equip")
        if not curEquip then return end

        local bRight = (curEquip ~= "left")
        inst:SyncToLSCS(client, bRight)
    end)
end

--- When the item is dropped, unequip it first.
ITEM:Hook("drop", function(item)
    if item:GetData("equip") then
        item:Unequip(item:GetOwner())
    end
end)

--- Prevent transfer while equipped.
function ITEM:CanTransfer(oldInventory, newInventory)
    if newInventory and self:GetData("equip") then
        return false
    end
    return true
end

--- Clean up on removal — attachments are just data, nothing extra to delete.
function ITEM:OnRemoved()
    local owner = self:GetOwner()
    if IsValid(owner) and owner:IsPlayer() and self:GetData("equip") then
        self:Unequip(owner)
    end
end

-- ─────────────────────────────────────────────
-- Migration: clean up old-style attachment data
-- ─────────────────────────────────────────────

--- If this saber still has old-style `"attachments"` data (item IDs),
-- migrate it to the new blueprint format and clean up orphaned items.
function ITEM:MigrateOldAttachments()
    if not SERVER then return end

    local oldAttachments = self:GetData("attachments")
    if not oldAttachments then return end

    local meta = self:GetData("attachmentMeta", {})

    -- For any slot that has an old item ID but no blueprint yet,
    -- try to build a blueprint from the live instance (if loaded).
    for slotID, itemID in pairs(oldAttachments) do
        if not meta[slotID] then
            local inst = ix.item.instances[itemID]
            if inst then
                meta[slotID] = self:BuildAttachmentBlueprint(inst)
                -- Clean up the orphaned item from the database
                inst:Remove()
            end
        else
            -- Blueprint already exists, just delete the orphaned item
            local inst = ix.item.instances[itemID]
            if inst then
                inst:Remove()
            end
        end
    end

    -- Save new-style data and wipe old-style key
    self:SetData("attachmentMeta", meta)
    self:SetData("attachments", nil)
end

-- ─────────────────────────────────────────────
-- Auto-generate removal functions for all default slots
-- ─────────────────────────────────────────────
ITEM:GenerateRemovalFunctions()
