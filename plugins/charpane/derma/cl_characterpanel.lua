-- cl_characterpanel.lua
-- Three VGUI panels for the refactored charpane system:
--
--   ixCharPaneColumn     — A vertical strip of ixCharacterEquipmentSlots for
--                          one side of the model panel (left or right). Created
--                          and owned by ixUnifiedCharPanel.
--
--   ixCharPaneController — Thin manager panel (zero-size, invisible) that
--                          becomes ix.gui.charPanel while the YOU tab is open.
--                          Provides AddIcon / UpdateModel / panels / slots so
--                          the net receivers in cl_charpanel.lua work unchanged.
--
--   ixCharacterPane      — Legacy popup used ONLY by ixCharPanelStorageView
--                          (viewing another character's equipment). Styled with
--                          the VANIR colour language but retains its standalone
--                          pixel-placement layout for the storage case.

local THEME  = ix.ui.THEME
local Scale  = ix.ui.Scale
local PLUGIN = PLUGIN

-- ═══════════════════════════════════════════════════════════════════════════════
-- ixCharPaneColumn
-- Vertical column of equipment slots for one side of the 3-D model panel.
-- Width is fixed at slot-size + inner padding; height fills the parent.
-- ═══════════════════════════════════════════════════════════════════════════════

local COL = {}

-- Slot width constant shared between Init and Setup
local SLOT_SZ    = 0  -- resolved lazily in Init so Scale() has a valid ScrH
local INNER_PAD  = 0
local HEADER_H   = 0
local LABEL_H    = 0
local SLOT_STEP  = 0

function COL:Init()
    SLOT_SZ   = Scale(58)
    INNER_PAD = Scale(4)
    HEADER_H  = Scale(22)
    LABEL_H   = Scale(14)
    SLOT_STEP = SLOT_SZ + LABEL_H + Scale(4)

    self.side       = "left"
    self.slotPanels = {}   -- [category] = ixCharacterEquipmentSlot

    -- Fixed column width, height filled by dock system
    self:SetWide(SLOT_SZ + INNER_PAD * 2)

    self.Paint = function(pnl, w, h)
        -- Subtle tinted background
        surface.SetDrawColor(0, 0, 0, 80)
        surface.DrawRect(0, 0, w, h)

        -- Gold header bar (matches FIELD INVENTORY / OPERATIVE STATUS pattern)
        surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 210)
        surface.DrawRect(0, 0, w, HEADER_H)

        local hLabel = pnl.side == "left" and "LEFT" or "RIGHT"
        draw.SimpleText(
            hLabel, "ixImpMenuLabel",
            Scale(16), HEADER_H * 0.5,
            Color(0, 0, 0, 255),
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
        )

        -- Pulsing Aurebesh metadata on right of header
        -- local pulse = math.abs(math.sin(CurTime() * 1.5))
        -- draw.SimpleText(
        --     "EQUIP", "ixImpMenuAurebesh",
        --     w - Scale(5), HEADER_H * 0.5,
        --     Color(0, 0, 0, math.Round(110 + pulse * 145)),
        --     TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
        -- )

        -- Thin gold separator at bottom of column
        surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 30)
        surface.DrawRect(0, h - 1, w, 1)
    end
end

--- Populate the column with slots for the given side and wire them to the controller.
-- @param side       "left"|"right"
-- @param controller ixCharPaneController  (may be nil during isolated test)
function COL:Setup(side, controller)
    self.side       = side
    self.controller = controller

    -- Collect registered slots for this side, sort by order
    local entries = {}
    for category, info in pairs(ix.charPane.slots) do
        if (info.side == side) then
            entries[#entries + 1] = { category = category, info = info }
        end
    end
    table.sort(entries, function(a, b) return a.info.order < b.info.order end)

    -- Lay out slot panels below the header
    local yOffset = HEADER_H + Scale(6)

    for _, entry in ipairs(entries) do
        -- Optional visibility condition
        if (entry.info.condition and not entry.info.condition(LocalPlayer())) then
            continue
        end

        local slot = self:Add("ixCharacterEquipmentSlot")
        slot:SetCategory(entry.category, entry.info.label)
        slot:SetPos(INNER_PAD, yOffset)

        self.slotPanels[entry.category] = slot

        -- Register slot reference in the controller's lookup table
        if (controller) then
            controller.slots[entry.category] = slot
        end

        yOffset = yOffset + SLOT_STEP
    end
end

vgui.Register("ixCharPaneColumn", COL, "EditablePanel")


-- ═══════════════════════════════════════════════════════════════════════════════
-- ixCharPaneController
-- Zero-size invisible panel that serves as ix.gui.charPanel while the YOU tab
-- is open. Provides the same interface expected by cl_charpanel.lua net receivers:
--   self.panels  [itemID]   → ixCharPanelItemIcon
--   self.slots   [category] → ixCharacterEquipmentSlot
--   :AddIcon(item, model, category, skin) → icon|nil
--   :UpdateModel()
-- ═══════════════════════════════════════════════════════════════════════════════

local CTRL = {}

local function findSlotByCategory(slots, category)
    if (not slots) then return nil end

    local key = string.lower(category or "")

    for slotCategory, slotPanel in pairs(slots) do
        if (string.lower(slotCategory or "") == key) then
            return slotPanel
        end
    end

    return nil
end

function CTRL:Init()
    self:SetSize(0, 0)
    -- Don't SetVisible(false) because VGUI panels stop receiving Think when invisible.
    self:SetPaintBackgroundEnabled(false)
    self:SetPaintBorderEnabled(false)
    self.panels  = {}   -- [itemID]   → ixCharPanelItemIcon
    self.slots   = {}   -- [category] → ixCharacterEquipmentSlot  (filled by columns)
    self.panelID = 0
end

--- Wire the controller to its two slot columns and claim ix.gui.charPanel.
function CTRL:SetupController(leftCol, rightCol)
    self.leftCol  = leftCol
    self.rightCol = rightCol
    ix.gui.charPanel = self
end

--- Setup from charPanel
function CTRL:SetupFromCharPanel()
    -- Native layout updates are dynamically handled in Think
end

--- Create an ixCharPanelItemIcon inside the correct slot and return it.
-- Used by SetupFromCharPanel and the real-time ixCharPanelSet net receiver.
function CTRL:AddIcon(item, model, category, skin)
    local slot = findSlotByCategory(self.slots, category)
    if (not IsValid(slot)) then return end

    -- Remove any icon already in this slot
    if (IsValid(slot.item)) then
        self.panels[slot.item.itemID] = nil
        slot.item:Remove()
        slot.item = nil
    end

    local sz   = Scale(58)
    local icon = slot:Add("ixCharPanelItemIcon")
    icon.slotPanel = slot
    icon:SetSize(sz, sz)
    icon:SetPos(0, 0)
    icon:SetZPos(999)
    icon:SetModel(model, skin)
    icon:SetPanelID(self.panelID)
    icon:SetItemTable(item)

    if (PLUGIN.RenderNewIcon) then
        PLUGIN:RenderNewIcon(icon, item)
    end

    slot.item    = icon
    slot.isEmpty = false

    return icon
end

--- Noop — the model panel is always live with real-time head tracking.
function CTRL:UpdateModel() end

function CTRL:Think()
    local char = LocalPlayer():GetCharacter()
    if (!char) then return end
    
    local invID = char:GetData("equipInv")
    if (!invID) then return end
    
    local inv = ix.item.inventories[invID]
    if (!inv) then return end
    
    for category, slotPanel in pairs(self.slots) do
        local slotData = ix.charPane.slots[category]
        if (!slotData) then continue end
        
        local targetX = slotData.gridX or 1
        local targetY = slotData.gridY or 1
        local itemObj = inv:GetItemAt(targetX, targetY)
        
        if (itemObj) then
            if (not IsValid(slotPanel.item) or slotPanel.item.itemID != itemObj.id) then
                -- Check if this specific item is currently pending a drag operation
                if (itemObj.bPendingEquipmentTransfer) then
                    continue
                end

                local draggedItem = dragndrop.GetDroppable() and dragndrop.GetDroppable()[1]
                if (IsValid(draggedItem) and draggedItem.itemID == itemObj.id) then
                    continue
                end

                local icon = self:AddIcon(itemObj, itemObj:GetModel() or "models/props_junk/popcan01a.mdl", category, itemObj:GetSkin())
                if (IsValid(icon)) then
                    icon:SetHelixTooltip(function(tooltip)
                        ix.hud.PopulateItemTooltip(tooltip, itemObj)
                    end)
                    icon.itemID = itemObj.id
                    self.panels[itemObj.id] = icon
                end
            end
        else
            if (IsValid(slotPanel.item)) then
                self.panels[slotPanel.item.itemID] = nil
                slotPanel.item:Remove()
                slotPanel.item = nil
                slotPanel.isEmpty = true
            end
        end
    end
end

function CTRL:OnRemove()
    if (ix.gui.charPanel == self) then
        ix.gui.charPanel = nil
    end
end

vgui.Register("ixCharPaneController", CTRL, "EditablePanel")


-- ═══════════════════════════════════════════════════════════════════════════════
-- ixCharacterPane  (LEGACY — storage-view popup only)
-- Used exclusively by ixCharPanelStorageView when a player opens another
-- character's inventory. Retains pixel-placement layout; paint is VANIR-styled.
-- ═══════════════════════════════════════════════════════════════════════════════

local PANEL = {}

function PANEL:Init()
    ix.gui.charPanel = self
    self:SetSize(Scale(360), Scale(525))
    self.panels = {}
    self:Receiver("ixInventoryItem", self.ReceiveDrop)
end

function PANEL:SetCharacter(character)
    if (IsValid(self.model)) then self.model:Remove() end
    self.character = character

    self.model = self:Add("ixModelPanel")
    self.model:Dock(FILL)
    self.model:SetFOV(50)

    self:UpdateModel()
    self.panelID = character:GetID()
    self:BuildSlots()
end

function PANEL:GetCharacter()
    return self.character or nil
end

function PANEL:ReceiveDrop() return end

function PANEL:Think()
    if (IsValid(ix.gui.menu) and ix.gui.menu.bClosing) then
        if (IsValid(self.model)) then self.model:Remove() end
    end

    local character = self:GetCharacter()
    if (character and IsValid(self.model)) then
        if (character:GetPlayer():GetModel() != self.model:GetModel()) then
            self:UpdateModel()
        end

        local showSlots = hook.Run("CharPanelCanUse", character:GetPlayer())
        self:ToggleSlots(showSlots != false)
        
        -- Sync inventory visually if available
        local invID = character:GetData("equipInv")
        if invID then
            local inv = ix.item.inventories[invID]
            if inv and self.slots then
                for category, slotPanel in pairs(self.slots) do
                    local slotData = ix.charPane.slots[category]
                    if (!slotData) then continue end
                    
                    local targetX = slotData.gridX or 1
                    local targetY = slotData.gridY or 1
                    local itemObj = inv:GetItemAt(targetX, targetY)
                    
                    if (itemObj) then
                        if (not IsValid(slotPanel.item) or slotPanel.item.itemID != itemObj.id) then
                            local icon = self:AddIcon(itemObj, itemObj:GetModel() or "models/props_junk/popcan01a.mdl", category, itemObj:GetSkin())
                            if (IsValid(icon)) then
                                icon:SetHelixTooltip(function(tooltip)
                                    ix.hud.PopulateItemTooltip(tooltip, itemObj)
                                end)
                                icon.itemID = itemObj.id
                                self.panels[itemObj.id] = icon
                            end
                        end
                    else
                        if (IsValid(slotPanel.item)) then
                            self.panels[slotPanel.item.itemID] = nil
                            slotPanel.item:Remove()
                            slotPanel.item = nil
                            slotPanel.isEmpty = true
                        end
                    end
                end
            end
        end
    end
end

function PANEL:ToggleSlots(bShow)
    for _, v in pairs(self.slots or {}) do
        if (IsValid(v)) then v:SetVisible(bShow) end
    end
end

function PANEL:UpdateModel()
    if (not IsValid(self.model)) then return end
    local char = self:GetCharacter()
    if (not char) then return end

    self.model:SetModel(
        char.model or char:GetPlayer():GetModel(),
        char.vars.skin or char:GetData("skin", 0)
    )

    for k, v in pairs(char.vars.groups or char:GetData("groups", {})) do
        self.model.Entity:SetBodygroup(k, v)
    end
end

function PANEL:SetCharPanel()
    -- Native layout updates are dynamically handled in Think
end

function PANEL:BuildSlots()
    self.slots = self.slots or {}
    for category, placement in pairs(PLUGIN.slotPlacements) do
        local slot = self:Add("ixCharacterEquipmentSlot")
        slot:SetCategory(category, string.upper(category))
        slot:SetPos(placement.x, placement.y)
        self.slots[category] = slot
    end
end

function PANEL:AddIcon(item, model, category, skin)
    local placement = PLUGIN.slotPlacements[category]
    if (not placement) then return end

    local sz   = Scale(58)
    local icon = self:Add("ixCharPanelItemIcon")
    icon:SetSize(sz, sz)
    icon:SetZPos(999)
    icon:SetModel(model, skin)
    icon:SetPos(placement.x, placement.y)
    icon:SetPanelID(self.panelID)
    icon:SetItemTable(item)

    if (PLUGIN.RenderNewIcon) then
        PLUGIN:RenderNewIcon(icon, item)
    end

    local slot = self.slots[category]
    if (IsValid(slot)) then slot.item = icon end

    return icon
end

--- Noop for legacy compat (model panel is a live ixModelPanel child).
function PANEL:UpdateModel()
    if (not IsValid(self.model)) then return end
    local char = self:GetCharacter()
    if (not char) then return end

    self.model:SetModel(
        char.model or char:GetPlayer():GetModel(),
        char.vars.skin or char:GetData("skin", 0)
    )

    for k, v in pairs(char.vars.groups or char:GetData("groups", {})) do
        self.model.Entity:SetBodygroup(k, v)
    end
end

function PANEL:Paint(w, h)
    local hH = Scale(22)

    -- Dark panel body
    surface.SetDrawColor(0, 0, 0, 210)
    surface.DrawRect(0, 0, w, h)

    -- Gold header bar
    surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 210)
    surface.DrawRect(0, 0, w, hH)
    draw.SimpleText(
        "EQUIPMENT", "ixImpMenuDiag",
        Scale(7), hH * 0.5,
        Color(0, 0, 0, 255),
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
    )

    -- Pulsing Aurebesh on header right
    local pulse = math.abs(math.sin(CurTime() * 1.5))
    draw.SimpleText(
        "LOADOUT", "ixImpMenuAurebesh",
        w - Scale(7), hH * 0.5,
        Color(0, 0, 0, math.Round(110 + pulse * 145)),
        TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
    )

    -- Subtle gold outline
    surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 45)
    surface.DrawOutlinedRect(0, 0, w, h)
end

vgui.Register("ixCharacterPane", PANEL, "DPanel")
