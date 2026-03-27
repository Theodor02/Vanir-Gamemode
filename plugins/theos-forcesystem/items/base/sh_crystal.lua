--- Crystal Item Base
-- A Helix item base for kyber crystals (and other lightsaber
-- attachment components). Crystals can be dragged onto a lightsaber
-- item to install them into the matching slot.
--
-- Set `ITEM.attachmentType` to one of the slot types accepted by
-- the lightsaber base ("crystal", "lens", "cell", "emitter", "grip").
--
-- Crystals installed in a lightsaber are hidden from the inventory
-- grid. They reappear when removed from the saber.
-- @module item-base.crystal

ITEM.name = "Kyber Crystal"
ITEM.description = "A kyber crystal that can be installed in a lightsaber."
ITEM.category = "Lightsaber Components"
ITEM.model = "models/props_junk/rock001a.mdl"
ITEM.width = 1
ITEM.height = 1

--- Which lightsaber attachment slot this item fills.
-- Must match one of the `accepts` entries in the lightsaber's
-- `attachmentSlots` table. Common types:
--   "crystal", "lens", "cell", "emitter", "grip"
ITEM.attachmentType = "crystal"

--- LSCS blade class (e.g. "item_crystal_bluehor").
-- Determines the visual blade when installed in a lightsaber.
-- Only relevant for crystal-type attachments; leave nil for others.
ITEM.lscsBlade = nil

--- Optional display colour for the crystal swatch on the saber tooltip.
-- Set to a Color() value in subclass items.
ITEM.crystalColor = nil

--- Optional stat modifiers this attachment provides when installed.
-- These are aggregated by the lightsaber base's `GetModifierTotal()`.
-- Example: { damage = 5, deflection = 2 }
ITEM.modifiers = nil

-- ─────────────────────────────────────────────
-- Inventory Drawing
-- ─────────────────────────────────────────────

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        -- Colour swatch
        if item.crystalColor then
            surface.SetDrawColor(item.crystalColor)
            surface.DrawRect(2, h - 10, 8, 8)
        end

        -- Installed indicator
        if item:GetData("installedIn") then
            surface.SetDrawColor(255, 200, 80, 120)
            surface.DrawRect(w - 14, h - 14, 8, 8)
        end
    end

    function ITEM:PopulateTooltip(tooltip)
        local installedIn = self:GetData("installedIn")
        if installedIn then
            local saberItem = ix.item.instances[installedIn]
            if saberItem then
                local row = tooltip:AddRow("installed")
                row:SetText("Installed in: " .. saberItem.name)
                row:SizeToContents()
            end
        end

        if self.modifiers then
            for k, v in SortedPairs(self.modifiers) do
                local sign = v >= 0 and "+" or ""
                local row = tooltip:AddRow("mod_" .. k)
                row:SetText(k .. ": " .. sign .. v)
                row:SizeToContents()
            end
        end
    end

    function ITEM:GetDescription()
        local desc = self.description or ""

        if self.modifiers and next(self.modifiers) then
            desc = desc .. "\n\nModifiers:"
            for k, v in SortedPairs(self.modifiers) do
                local sign = v >= 0 and "+" or ""
                desc = desc .. "\n  " .. k .. ": " .. sign .. v
            end
        end

        return desc
    end
end

-- ─────────────────────────────────────────────
-- Transfer Lock — cannot move/drop while installed
-- ─────────────────────────────────────────────

function ITEM:CanTransfer(oldInventory, newInventory)
    if self:GetData("installedIn") then
        return false
    end
    return true
end

--- Prevent dropping while installed.
ITEM:Hook("drop", function(item)
    if item:GetData("installedIn") then
        return false
    end
end)
