--- USMS Admin Commands
-- Superadmin and admin override commands for unit management.

-- ═══════════════════════════════════════════════════════════════════════════════
-- SUPERADMIN: Unit Management
-- ═══════════════════════════════════════════════════════════════════════════════

ix.command.Add("UnitCreate", {
    description = "Create a new unit. Usage: /UnitCreate <factionIndex> <unit name>",
    superAdminOnly = true,
    arguments = {
        ix.type.number,
        ix.type.text
    },
    OnRun = function(self, ply, factionIndex, name)
        name = tostring(name):sub(1, 64)
        if (name == "") then
            ply:Notify("Unit name cannot be empty.")
            return
        end

        local ok, err = ix.usms.CreateUnit(name, factionIndex, {}, function(unitID)
            ply:Notify("Unit '" .. name .. "' created with ID " .. unitID .. ".")
        end)

        if (!ok) then
            ply:Notify("Failed: " .. (err or "unknown"))
        end
    end
})

ix.command.Add("UnitDelete", {
    description = "Delete a unit and all its data.",
    superAdminOnly = true,
    arguments = { ix.type.number },
    OnRun = function(self, ply, unitID)
        local ok, err = ix.usms.DeleteUnit(unitID, function()
            ply:Notify("Unit deleted.")
        end)

        if (!ok) then
            ply:Notify("Failed: " .. (err or "unknown"))
        end
    end
})

ix.command.Add("UnitSetResources", {
    description = "Set a unit's resource amount.",
    superAdminOnly = true,
    arguments = { ix.type.number, ix.type.number },
    OnRun = function(self, ply, unitID, amount)
        if (ix.usms.SetResources(unitID, amount, "admin_set", nil)) then
            ply:Notify("Resources set to " .. amount .. ".")
        else
            ply:Notify("Failed: unit not found.")
        end
    end
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- ADMIN: Override Commands
-- ═══════════════════════════════════════════════════════════════════════════════

ix.command.Add("UnitAddResources", {
    description = "Add resources to a unit.",
    adminOnly = true,
    arguments = { ix.type.number, ix.type.number },
    OnRun = function(self, ply, unitID, amount)
        if (ix.usms.AddResources(unitID, amount, "admin_add", nil)) then
            ply:Notify("Added " .. amount .. " resources.")
        else
            ply:Notify("Failed: unit not found.")
        end
    end
})

ix.command.Add("UnitForceRemove", {
    description = "Force remove a player from their unit.",
    adminOnly = true,
    arguments = { ix.type.player },
    OnRun = function(self, ply, target)
        local char = target:GetCharacter()
        if (!char) then
            ply:Notify("Target has no character.")
            return
        end

        ix.usms.RemoveMember(char:GetID(), nil, function(ok, err)
            ply:Notify(ok and "Removed from unit." or ("Failed: " .. (err or "unknown")))
        end)
    end
})

ix.command.Add("SquadForceDisband", {
    description = "Force disband a squad by ID.",
    adminOnly = true,
    arguments = { ix.type.number },
    OnRun = function(self, ply, squadID)
        ix.usms.DisbandSquad(squadID, nil, function(ok, err)
            ply:Notify(ok and "Squad disbanded." or ("Failed: " .. (err or "unknown")))
        end)
    end
})

ix.command.Add("UnitTransferCO", {
    description = "Force transfer CO status to a player. Args: unitID, player",
    adminOnly = true,
    arguments = { ix.type.number, ix.type.player },
    OnRun = function(self, ply, unitID, target)
        local char = target:GetCharacter()
        if (!char) then
            ply:Notify("Target has no character.")
            return
        end

        ix.usms.TransferCO(unitID, char:GetID(), function(ok, err)
            ply:Notify(ok and "CO transferred." or ("Failed: " .. (err or "unknown")))
        end)
    end
})

ix.command.Add("UnitList", {
    description = "List all units.",
    adminOnly = true,
    OnRun = function(self, ply)
        if (table.Count(ix.usms.units) == 0) then
            ply:Notify("No units exist.")
            return
        end

        for id, unit in pairs(ix.usms.units) do
            local faction = ix.faction.indices[unit.factionID]
            local factionName = faction and faction.name or "Unknown"
            local memberCount = ix.usms.GetUnitMemberCount(id)
            ply:ChatPrint(string.format("[%d] %s (%s) - %d members, %d resources",
                id, unit.name, factionName, memberCount, unit.resources))
        end
    end
})

ix.command.Add("UnitInvite", {
    description = "Admin-invite a player to a unit.",
    adminOnly = true,
    arguments = { ix.type.player, ix.type.number },
    OnRun = function(self, ply, target, unitID)
        local char = target:GetCharacter()
        if (!char) then
            ply:Notify("Target has no character.")
            return
        end

        ix.usms.AddMember(char:GetID(), unitID, USMS_ROLE_MEMBER, function(ok, err)
            ply:Notify(ok and "Player invited to unit." or ("Failed: " .. (err or "unknown")))
        end)
    end
})

ix.command.Add("UnitSetRole", {
    description = "Set a player's unit role (0=member, 1=XO, 2=CO).",
    adminOnly = true,
    arguments = { ix.type.player, ix.type.number },
    OnRun = function(self, ply, target, role)
        local char = target:GetCharacter()
        if (!char) then
            ply:Notify("Target has no character.")
            return
        end

        role = math.Clamp(math.floor(role), 0, 2)

        ix.usms.SetMemberRole(char:GetID(), role, function(ok, err)
            ply:Notify(ok and "Role updated." or ("Failed: " .. (err or "unknown")))
        end)
    end
})
