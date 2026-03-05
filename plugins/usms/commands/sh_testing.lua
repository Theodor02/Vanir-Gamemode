--- USMS Testing Commands
-- Development/testing commands that simulate entity interactions.

ix.command.Add("USMSTestGearUp", {
    description = "[DEV] Simulate gear-up from armory.",
    adminOnly = true,
    OnRun = function(self, ply)
        ix.usms.GearUp(ply, function(ok, err, items, cost)
            if (ok) then
                ply:Notify("Geared up! Cost: " .. cost .. " resources. Items: " .. #items)
            else
                ply:Notify("Gear-up failed: " .. (err or "unknown"))
            end
        end)
    end
})

ix.command.Add("USMSTestClassChange", {
    description = "[DEV] Simulate class change at loadout locker. Args: classIndex",
    adminOnly = true,
    arguments = { ix.type.number },
    OnRun = function(self, ply, classIndex)
        local char = ply:GetCharacter()
        if (!char) then return end

        ix.usms.ChangeClass(char:GetID(), classIndex, nil, function(ok, err)
            if (ok) then
                local className = ix.class.list[classIndex] and ix.class.list[classIndex].name or tostring(classIndex)
                ply:Notify("Class changed to " .. className)
            else
                ply:Notify("Class change failed: " .. (err or "unknown"))
            end
        end)
    end
})

ix.command.Add("USMSTestCreateSquad", {
    description = "[DEV] Create a test squad. Optional: name",
    adminOnly = true,
    arguments = { bit.bor(ix.type.text, ix.type.optional) },
    OnRun = function(self, ply, name)
        name = name or "FIRETEAM AUREK"
        ix.usms.CreateSquad(ply, name, function(ok, result)
            if (ok) then
                ply:Notify("Squad created: " .. name .. " (ID: " .. result .. ")")
            else
                ply:Notify("Failed: " .. tostring(result))
            end
        end)
    end
})

ix.command.Add("USMSTestSquadInvite", {
    description = "[DEV] Invite a player to your squad.",
    adminOnly = true,
    arguments = { ix.type.player },
    OnRun = function(self, ply, target)
        local char = ply:GetCharacter()
        local targetChar = target:GetCharacter()
        if (!char or !targetChar) then return end

        local sm = ix.usms.squadMembers[char:GetID()]
        if (!sm) then
            ply:Notify("You are not in a squad.")
            return
        end

        ix.usms.AddToSquad(targetChar:GetID(), sm.squadID, function(ok, err)
            ply:Notify(ok and "Invited!" or ("Failed: " .. (err or "unknown")))
        end)
    end
})

ix.command.Add("USMSTestRoster", {
    description = "[DEV] Request your unit's roster.",
    adminOnly = true,
    OnRun = function(self, ply)
        local char = ply:GetCharacter()
        if (!char) then return end

        local member = ix.usms.members[char:GetID()]
        if (!member) then
            ply:Notify("Not in a unit.")
            return
        end

        ix.usms.SendRoster(ply, member.unitID)
        ply:Notify("Roster data sent to client.")
    end
})

ix.command.Add("USMSTestLogs", {
    description = "[DEV] Print recent unit logs to chat.",
    adminOnly = true,
    OnRun = function(self, ply)
        local char = ply:GetCharacter()
        if (!char) then return end

        local member = ix.usms.members[char:GetID()]
        if (!member) then
            ply:Notify("Not in a unit.")
            return
        end

        ix.usms.GetLogs(member.unitID, {limit = 10}, function(logs)
            for _, log in ipairs(logs) do
                ply:ChatPrint(string.format("[%s] %s | Actor: %s | Target: %s",
                    os.date("%H:%M:%S", log.timestamp),
                    log.action,
                    tostring(log.actorCharID or "system"),
                    tostring(log.targetCharID or "-")
                ))
            end
        end)
    end
})

ix.command.Add("USMSCanSquad", {
    description = "[DEV] Grant/revoke squad creation permission to a player.",
    adminOnly = true,
    arguments = { ix.type.player },
    OnRun = function(self, ply, target)
        local current = target:GetNetVar("ixUSMSCanCreateSquad", false)
        target:SetNetVar("ixUSMSCanCreateSquad", !current)
        ply:Notify("Squad creation for " .. target:Nick() .. ": " .. tostring(!current))
    end
})

ix.command.Add("USMSDebugState", {
    description = "[DEV] Print USMS cache state to console.",
    adminOnly = true,
    OnRun = function(self, ply)
        print("=== USMS DEBUG STATE ===")
        print("Units: " .. table.Count(ix.usms.units))
        for id, unit in pairs(ix.usms.units) do
            print(string.format("  [%d] %s (faction %d, %d resources)", id, unit.name, unit.factionID, unit.resources))
        end
        print("Members: " .. table.Count(ix.usms.members))
        print("Squads: " .. table.Count(ix.usms.squads))
        print("Squad Members: " .. table.Count(ix.usms.squadMembers))
        print("Logs: " .. #(ix.usms.logs or {}))
        ply:Notify("State printed to server console.")
    end
})
