-- ixCharacterEquipmentSlot
-- A single equipment slot rendered in the VANIR design language.
-- Accepts drag-and-drop from ixInventoryItem; validates against outfitCategory.

local THEME = ix.ui.THEME
local Scale  = ix.ui.Scale

local PANEL = {}

function PANEL:Init()
    self.isEmpty    = true
    self.category   = "unknown"
    self.slotLabel  = "SLOT"
    self.item       = nil        -- Set to the ixCharPanelItemIcon child when occupied

    -- Height = slot face + label strip below
    local sz = Scale(58)
    self:SetSize(sz, sz + Scale(14))
    self:Receiver("ixInventoryItem", self.ReceiveDrop)
end

function PANEL:SetCategory(category, label)
    self.category  = category
    self.slotLabel = label or string.upper(category)
end

function PANEL:Think()
    -- Keep isEmpty consistent with the actual icon child
    self.isEmpty = not IsValid(self.item)
end

function PANEL:Paint(w, h)
    local sz = Scale(58)

    -- Slot face background
    surface.SetDrawColor(0, 0, 0, 130)
    surface.DrawRect(0, 0, w, sz)

    -- Border: dim gold when empty, bright when occupied
    local borderAlpha = self.isEmpty and 45 or 160
    surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, borderAlpha)
    surface.DrawOutlinedRect(0, 0, w, sz)

    -- Corner targeting brackets when empty (design-system reticle language)
    if (self.isEmpty) then
        local bLen = Scale(9)
        surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 90)
        -- Top-left
        surface.DrawRect(0,         0,    bLen, 1)
        surface.DrawRect(0,         0,    1,    bLen)
        -- Bottom-right
        surface.DrawRect(w - bLen,  sz - 1, bLen, 1)
        surface.DrawRect(w - 1,     sz - bLen, 1, bLen)
    end

    -- Label strip beneath the slot face
    draw.SimpleText(
        self.slotLabel, "ixImpMenuDiag",
        w * 0.5, sz + Scale(7),
        Color(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b, 110),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
    )
end

function PANEL:PaintOver(w, h)
    local sz = Scale(58)

    -- Subtle hover tint over occupied slot
    if (self:IsHovered() and not self.isEmpty) then
        surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 10)
        surface.DrawRect(0, 0, w, sz)
    end

    -- Drag-preview highlight
    if (IsValid(self.previewPanel)) then
        local itemPanel = (dragndrop.GetDroppable() or {})[1]
        if (IsValid(itemPanel)) then
            self:PaintDragPreview(w, sz, itemPanel)
        end
    end
    self.previewPanel = nil
end

function PANEL:PaintDragPreview(w, sz, itemPanel)
    local item   = itemPanel.itemTable
    if (not item) then return end

    local canUse = hook.Run("CharPanelCanUse", LocalPlayer())
    local catExpected = string.lower(self.category or "")
    local actualCat = string.lower(item.outfitCategory or "")
    
    local match = (actualCat == catExpected) or (string.StartsWith(catExpected, "ammo") and actualCat == "ammo")

    if (match and canUse != false) then
        -- Green tint if empty slot matches, yellow if it would replace
        local col = self.isEmpty and Color(60, 180, 90, 55) or Color(220, 180, 0, 35)
        surface.SetDrawColor(col)
    else
        surface.SetDrawColor(180, 55, 55, 60)
    end
    surface.DrawRect(0, 0, w, sz)
end

function PANEL:ReceiveDrop(panels, bDropped, menuIndex, x, y)
    local panel = panels[1]

    if (not IsValid(panel)) then
        self.previewPanel = nil
        return
    end

    local catExpected = string.lower(self.category or "")

    if (bDropped) then
        local item = panel.itemTable
        if (not item) then return false end

        local actualCat = string.lower(item.outfitCategory or "")
        local match = (actualCat == catExpected) or (string.StartsWith(catExpected, "ammo") and actualCat == "ammo")

        if (not match) then 
            return false, "notAllowed" 
        end
        
        if (hook.Run("CharPanelCanUse", LocalPlayer()) == false) then 
            return false, "noAccess" 
        end

        if (item.dropSound and ix.option.Get("toggleInventorySound", false)) then
            local snd = item.dropSound
            surface.PlaySound(istable(snd) and snd[math.random(#snd)] or snd)
        end

        local character = LocalPlayer():GetCharacter()
        if (not character) then
            return false
        end

        local equipInvID = character:GetData("equipInv")
        if (!equipInvID) then 
            return false 
        end

        local slotData = ix.charPane.slots[self.category]
        if (not slotData) then
            return false
        end

        local targetX = slotData.gridX or 1
        local targetY = slotData.gridY or 1
        
        -- Fallback to item:GetData("gridX") if panel.gridX doesn't exist
        local oldX = panel.gridX or (item and item:GetData("gridX")) or 1
        local oldY = panel.gridY or (item and item:GetData("gridY")) or 1
        local oldInvID = panel.inventoryID or (item and item.invID) or 0

        net.Start("ixInventoryMove")
            net.WriteUInt(oldX, 6)
            net.WriteUInt(oldY, 6)
            net.WriteUInt(targetX, 6)
            net.WriteUInt(targetY, 6)
            net.WriteUInt(oldInvID, 32)
            net.WriteUInt(equipInvID, 32)
        net.SendToServer()

        self.previewPanel = nil
    else
        self.previewPanel = panel
        self.previewX     = x
        self.previewY     = y
    end
end

vgui.Register("ixCharacterEquipmentSlot", PANEL, "EditablePanel")
