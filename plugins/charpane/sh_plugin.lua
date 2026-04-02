PLUGIN.name        = "Character Panel"
PLUGIN.description = "Equipment panel with dynamic slot registration, integrated into the VANIR YOU tab."
PLUGIN.author      = "Adolphus"

ix.util.Include("sv_database.lua")
ix.util.Include("sv_hooks.lua")
ix.util.IncludeDir(PLUGIN.folder .. "/meta", true)

-- ─── Dynamic Slot Registry ────────────────────────────────────────────────────
-- Other plugins call ix.charPane.RegisterSlot() to add equipment categories.
-- The registration must happen before the YOU tab panel is first created.

ix.charPane = ix.charPane or {}
ix.charPane.slots = ix.charPane.slots or {}

--- Register an equipment slot category.
-- @param category string  Must match item.outfitCategory exactly (case-sensitive).
-- @param options  table
--   side      "left"|"right"  Which column to appear in around the model panel.
--   order     number          Sort priority within the column (lower = higher).
--   label     string          Short label displayed beneath the slot (uppercase).
--   condition function|nil    Optional function(ply) → bool; hide slot when false.
function ix.charPane.RegisterSlot(category, options)
    options = options or {}
    ix.charPane.slots[category] = {
        side      = options.side      or "left",
        order     = options.order     or 50,
        label     = options.label     or string.upper(category),
        condition = options.condition,
    }
end

-- Default slot layout
ix.charPane.RegisterSlot("headgear",  { side = "left",  order = 1, label = "HEAD"    })
ix.charPane.RegisterSlot("torso",     { side = "left",  order = 2, label = "TORSO"   })
ix.charPane.RegisterSlot("kevlar",    { side = "left",  order = 3, label = "KEVLAR"  })
ix.charPane.RegisterSlot("bag",       { side = "left",  order = 4, label = "BAG"     })
ix.charPane.RegisterSlot("satchel",   { side = "left",  order = 5, label = "SATCHEL" })
ix.charPane.RegisterSlot("glasses",   { side = "right", order = 1, label = "EYEWEAR" })
ix.charPane.RegisterSlot("headstrap", { side = "right", order = 2, label = "STRAP"   })
ix.charPane.RegisterSlot("hands",     { side = "right", order = 3, label = "HANDS"   })
ix.charPane.RegisterSlot("legs",      { side = "right", order = 4, label = "LEGS"    })

-- Legacy pixel-placement table kept for ixCharacterPane (storage view popup).
PLUGIN.slotPlacements = {
    ["headgear"]  = { x = 5,   y = 100 },
    ["headstrap"] = { x = 291, y = 170 },
    ["glasses"]   = { x = 291, y = 100 },
    ["torso"]     = { x = 5,   y = 170 },
    ["kevlar"]    = { x = 5,   y = 240 },
    ["hands"]     = { x = 291, y = 300 },
    ["legs"]      = { x = 291, y = 370 },
    ["bag"]       = { x = 5,   y = 310 },
    ["satchel"]   = { x = 5,   y = 380 },
}

-- Called when the client is checking if it has access to see the character panel.
function PLUGIN:CharPanelCanUse(client)
    local character = client:GetCharacter()
    local inventoryItems = {}

    if (character:GetInventory()) then
        inventoryItems = character:GetInventory():GetItems()
    end

    for _, v in pairs(inventoryItems) do
        if (v.outfitCategory and v:GetData("equip") == true) then
            return false
        end
    end
end
