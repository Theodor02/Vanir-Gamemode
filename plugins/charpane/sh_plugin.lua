PLUGIN.name        = "Character Panel"
PLUGIN.description = "Equipment panel with dynamic slot registration, integrated into the VANIR YOU tab."
PLUGIN.author      = "Theodor"

ix.util.Include("sv_database.lua")
ix.util.Include("sv_hooks.lua")
ix.util.IncludeDir(PLUGIN.folder .. "/meta", true)

-- ─── Dynamic Slot Registry ────────────────────────────────────────────────────
-- Other plugins call ix.charPane.RegisterSlot() to add equipment categories.
-- The registration must happen before the YOU tab panel is first created.

-- Register the equipment inventory grid shape (62 columns by 62 rows to ensure items fit without 6-bit integer overflow! Standard grid inventory sizes in Helix are clamped to `uint6` (0 to 63) over the network layer `net.WriteUInt`, and coordinate spacing requires jumping by `+4` locally to give 3x3 items clearance.)
ix.inventory.Register("equipment", 62, 62, false)

ix.charPane = ix.charPane or {}
ix.charPane.slots = ix.charPane.slots or {}

--- Register an equipment slot category.
-- @param category string  Must match item.outfitCategory exactly (case-sensitive).
-- @param options  table
--   side      "left"|"right"  Which column to appear in around the model panel.
--   order     number          Sort priority within the column (lower = higher).
--   label     string          Short label displayed beneath the slot (uppercase).
--   gridX     number          The horizontal X coordinate for "equipment" inventory entry.
--   gridY     number          The vertical Y coordinate.
--   condition function|nil    Optional function(ply) → bool; hide slot when false.
function ix.charPane.RegisterSlot(category, options)
    options = options or {}
    
    -- Auto-assign gridX if omitted by incrementing from the highest existing gridX.
    if not options.gridX then
        local maxGrid = 0
        for k, v in pairs(ix.charPane.slots) do
            if v.gridX and v.gridX > maxGrid then maxGrid = v.gridX end
        end
        options.gridX = maxGrid + 4
    end
    
    ix.charPane.slots[category] = {
        side      = options.side      or "left",
        order     = options.order     or 50,
        label     = options.label     or string.upper(category),
        gridX     = options.gridX,
        gridY     = options.gridY     or 1,
        condition = options.condition,
    }
end

-- Default slot layout (Using different X coordinates to avoid 6-bit integer overflow on Y dimensions)
ix.charPane.RegisterSlot("torso",     { side = "left",  order = 2, label = "TORSO",     gridX = 5,  gridY = 1 })
ix.charPane.RegisterSlot("primary",   { side = "right", order = 5, label = "PRIMARY",   gridX = 37, gridY = 1 })
ix.charPane.RegisterSlot("secondary", { side = "right", order = 6, label = "SECONDARY", gridX = 41, gridY = 1 })
ix.charPane.RegisterSlot("tertiary",  { side = "right", order = 7, label = "TERTIARY",  gridX = 45, gridY = 1 })
ix.charPane.RegisterSlot("ammo1",     { side = "left", order = 8, label = "AMMO 1",    gridX = 49, gridY = 1 })
ix.charPane.RegisterSlot("ammo2",     { side = "left", order = 9, label = "AMMO 2",    gridX = 53, gridY = 1 })
ix.charPane.RegisterSlot("ammo3",     { side = "left", order = 10, label = "AMMO 3",   gridX = 57, gridY = 1 })

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
    ["primary"]   = { x = 291, y = 440 },
    ["secondary"] = { x = 291, y = 510 },
    ["tertiary"]  = { x = 291, y = 580 },
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
