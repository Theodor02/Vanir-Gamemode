-- ixCharPanelItemIcon
-- SpawnIcon-derived widget for an equipped item inside a charpane slot.
-- Styled to match the VANIR design system: dark bg, gold accent border.
-- Handles drag-out-to-unequip and right-click context menu.

local THEME         = ix.ui.THEME
local Scale         = ix.ui.Scale
local RECEIVER_NAME = "ixInventoryItem"
local PLUGIN        = PLUGIN

-- Icon render queue (shared with other icon rendering systems)
ICON_RENDER_QUEUE = ICON_RENDER_QUEUE or {}

--- Re-render the spawn icon using a custom camera if the item defines iconCam.
function PLUGIN:RenderNewIcon(panel, itemTable)
    local model = itemTable:GetModel()
    if ((itemTable.iconCam and not ICON_RENDER_QUEUE[string.lower(model)]) or itemTable.forceRender) then
        local cam = itemTable.iconCam
        ICON_RENDER_QUEUE[string.lower(model)] = true
        panel.Icon:RebuildSpawnIconEx({
            cam_pos = cam.pos,
            cam_ang = cam.ang,
            cam_fov = cam.fov,
        })
    end
end

-- ─── Panel ────────────────────────────────────────────────────────────────────

local PANEL = {}

AccessorFunc(PANEL, "itemTable", "ItemTable")
AccessorFunc(PANEL, "panelID",   "PanelID")

function PANEL:SetItemTable(item)
    self.itemTable = item
    
    if (item) then
        self:SetTooltip(false)
        self.gridW = item.width or 1
        self.gridH = item.height or 1
    end
end

function PANEL:Init()
    self:Droppable(RECEIVER_NAME)
    local sz = Scale(58)
    self:SetSize(sz, sz)
end

function PANEL:OnMousePressed(code)
    if (code == MOUSE_LEFT and self:IsDraggable()) then
        self:MouseCapture(true)
        
        -- Temporarily upscale the panel so the dragging model looks identical 
        -- to full-size grid items, matching Helix UI scaling.
        local iconSize = ix.config.Get("iconSize", 64) * (ix.ui.Scale and ix.ui.Scale(1) or 1)
        if (self.gridW and self.gridH) then
            self:SetSize(self.gridW * iconSize, self.gridH * iconSize)
        end
        
        self:DragMousePress(code)
        self.clickX, self.clickY = input.GetCursorPos()
    elseif (code == MOUSE_RIGHT) then
        self:DoRightClick()
    end
end

function PANEL:OnMouseReleased(code)
    -- Unequip / transfer when dropped somewhere that isn't a charPane slot
    if (not dragndrop.m_ReceiverSlot or dragndrop.m_ReceiverSlot.Name != RECEIVER_NAME) then
        self:OnDrop(dragndrop.IsDragging())
    end

    self:DragMouseRelease(code)
    local sz = Scale(58)
    self:SetZPos(99)
    self:SetSize(sz, sz)
    self:MouseCapture(false)
end

function PANEL:OnDrop(bDragging, inventoryPanel, inventory, gridX, gridY)
    local item = self.itemTable
    if (not item or not bDragging) then return end

    local invID = 0
    if (IsValid(inventoryPanel) and inventoryPanel:IsAllEmpty(gridX, gridY, item.width, item.height, self)) then
        invID = inventoryPanel.invID
    end


    if (item.dropSound and ix.option.Get("toggleInventorySound", false)) then
        local snd = item.dropSound
        surface.PlaySound(istable(snd) and snd[math.random(#snd)] or snd)
    end

    local character = LocalPlayer():GetCharacter()
    local equipInvID = character:GetData("equipInv")
    if (!equipInvID) then 
        return 
    end

    -- Fix: Default to known slot pos if available. Fallback to item.grid values.
    -- This prevents Helix server rejecting the transfer if oldX/oldY resolve incorrectly.
    local originSlot = self.slotPanel
    local oldX = item.gridX or 1
    local oldY = item.gridY or 1
    
    if (IsValid(originSlot) and originSlot.category and ix.charPane.slots[originSlot.category]) then
        oldX = ix.charPane.slots[originSlot.category].gridX or 1
        oldY = ix.charPane.slots[originSlot.category].gridY or 1
    end

    if (invID > 0) then
        
-- Temporarily prevents Helix UI caching from rebuilding the icon in its old slot before the server acknowledges the inventory move
        item.bPendingEquipmentTransfer = true
        timer.Simple(1, function() if (item) then item.bPendingEquipmentTransfer = nil end end)
        
        net.Start("ixInventoryMove")
            net.WriteUInt(oldX, 6)
            net.WriteUInt(oldY, 6)
            net.WriteUInt(gridX or 1, 6)
            net.WriteUInt(gridY or 1, 6)
            net.WriteUInt(equipInvID, 32)
            net.WriteUInt(invID, 32)
        net.SendToServer()
    else
        net.Start("ixInventoryAction")
            net.WriteString("drop")
            net.WriteUInt(item.id, 32)
            net.WriteUInt(equipInvID, 32)
            net.WriteTable({})
        net.SendToServer()
    end

    -- Immediately mark the parent slot as empty so the visual responds
    local originSlot = self.slotPanel
    if (IsValid(originSlot) and originSlot.isEmpty != nil) then
        originSlot.item    = nil
        originSlot.isEmpty = true
    end

    if (invID > 0) then
        -- Delete the charpane item icon. The main inventory UI will spawn a proper inventory item icon when it processes the move.
        self:Remove()
    end
end

function PANEL:PaintOver(w, h)
    local item = self.itemTable
    if (item and item.PaintOver) then
        item.PaintOver(self, item, w, h)
    end
end

function PANEL:ExtraPaint(w, h) end

function PANEL:Paint(w, h)
    -- Base dark background
    surface.SetDrawColor(0, 0, 0, 110)
    surface.DrawRect(0, 0, w, h)

    -- Item tint background
    local bg = (self.itemTable and self.itemTable.backgroundColor) or Color(28, 28, 28, 190)
    surface.SetDrawColor(bg)
    surface.DrawRect(2, 2, w - 4, h - 4)

    -- Gold accent border (matches slot border style)
    surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 110)
    surface.DrawOutlinedRect(0, 0, w, h)

    self:ExtraPaint(w, h)
end

function PANEL:DoRightClick()
    local item      = self.itemTable
    local panelID   = self.panelID
    if (not item or not panelID) then return end

    item.player = LocalPlayer()
    local menu  = DermaMenu()
    local override = hook.Run("CreateItemInteractionMenu", self, menu, item, panelID, true)

    if (override == true) then
        if (menu.Remove) then menu:Remove() end
    end
end

vgui.Register("ixCharPanelItemIcon", PANEL, "SpawnIcon")
