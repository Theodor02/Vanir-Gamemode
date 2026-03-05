--- USMS Server Hooks
-- Handles plugin lifecycle, character load/unload, SaveData/LoadData, and HUD sync timer.

local PLUGIN = PLUGIN

-- ═══════════════════════════════════════════════════════════════════════════════
-- PLUGIN LIFECYCLE
-- ═══════════════════════════════════════════════════════════════════════════════

--- Load USMS data when the plugin initializes.
function PLUGIN:InitializedPlugins()
    ix.usms.db.Load()
end

--- Save USMS data periodically (every 10 min) and on shutdown.
function PLUGIN:SaveData()
    ix.usms.db.Save()
end

--- Load USMS data on server start.
function PLUGIN:LoadData()
    ix.usms.db.Load()
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CHARACTER HOOKS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Auto-assign a character to their faction's unit if one exists.
-- If they are in a different faction's unit, transfer them.
-- @param charID number
-- @param char Character
local function AutoAssignToFactionUnit(charID, char)
    local factionID = char:GetFaction()
    if (!factionID) then return end

    local factionUnits = ix.usms.GetFactionUnits(factionID)

    -- Deterministic: pick the unit with the lowest ID for this faction
    local targetUnitID, targetUnit
    for uid, u in pairs(factionUnits) do
        if (!targetUnitID or uid < targetUnitID) then
            targetUnitID = uid
            targetUnit = u
        end
    end

    if (!targetUnitID) then return end -- No unit for this faction

    -- Allow hooks to override or block auto-assignment
    local override = hook.Run("USMSAutoAssignUnit", char, factionID, targetUnitID)
    if (override == false) then return end -- Hook blocked auto-assign
    if (isnumber(override) and ix.usms.units[override]) then
        targetUnitID = override -- Hook redirected to a different unit
    end

    local member = ix.usms.members[charID]

    if (member) then
        -- Already in the correct unit
        if (member.unitID == targetUnitID) then return end

        -- In a different unit — transfer: remove from old, add to new
        ix.usms.RemoveMember(charID, nil, function() end)
    end

    -- Add to the faction's unit
    ix.usms.AddMember(charID, targetUnitID, USMS_ROLE_MEMBER, function(ok, err)
        if (!ok) then return end

        -- Sync after a short delay (let CharVars propagate)
        local ply = ix.usms.GetPlayerByCharID(charID)
        if (IsValid(ply)) then
            timer.Simple(1, function()
                if (!IsValid(ply)) then return end
                ix.usms.SyncUnitToPlayer(ply, targetUnitID)
            end)
        end
    end)
end

--- When a character loads, cache their info for roster display and sync data.
--- Also auto-assigns to faction unit if not already in one (or transfers if faction changed).
function PLUGIN:PlayerLoadedCharacter(ply, char)
    local charID = char:GetID()
    local member = ix.usms.members[charID]

    -- Auto-assign: if not in a unit, or in the wrong faction's unit
    if (!member) then
        AutoAssignToFactionUnit(charID, char)
        -- Re-fetch member after auto-assign
        member = ix.usms.members[charID]
    elseif (member) then
        local unit = ix.usms.units[member.unitID]
        if (unit and unit.factionID != char:GetFaction()) then
            AutoAssignToFactionUnit(charID, char)
            member = ix.usms.members[charID]
        end
    end

    if (member) then
        -- Update cached display data
        member.cachedName = char:GetName()

        -- Restore persisted class from stable uniqueID (survives class list reordering)
        if (member.cachedClassUID and member.cachedClassUID != "") then
            local restoredIndex = ix.usms.GetClassIndexByUID(member.cachedClassUID, char:GetFaction())
            if (restoredIndex) then
                char:SetClass(restoredIndex)
                member.cachedClass = restoredIndex
                member.cachedClassName = (ix.class.list[restoredIndex] or {}).name or "Unassigned"
            else
                -- Class was removed from the schema; clear stale data
                member.cachedClass = 0
                member.cachedClassName = "Unassigned"
                member.cachedClassUID = ""
            end
        else
            member.cachedClass = char:GetClass() or 0
            local classInfo = ix.class.list[member.cachedClass]
            member.cachedClassName = classInfo and classInfo.name or "Unassigned"
            member.cachedClassUID = classInfo and classInfo.uniqueID or ""
        end

        -- Ensure classWhitelist exists (backfill for pre-existing members)
        member.classWhitelist = member.classWhitelist or {}

        member.cachedLastSeen = os.time()

        -- Ensure CharVars match the saved membership data
        -- (in case data file was edited or restored)
        if (char:GetUsmUnitID() != member.unitID) then
            char:SetUsmUnitID(member.unitID)
        end
        if (char:GetUsmUnitRole() != member.role) then
            char:SetUsmUnitRole(member.role)
        end

        -- Sync the player their unit data
        timer.Simple(1, function()
            if (!IsValid(ply)) then return end
            ix.usms.SyncUnitToPlayer(ply, member.unitID)
        end)

        -- If in a squad, sync HUD
        local sm = ix.usms.squadMembers[charID]
        if (sm) then
            if (char:GetUsmSquadID() != sm.squadID) then
                char:SetUsmSquadID(sm.squadID)
            end
            if (char:GetUsmSquadRole() != sm.role) then
                char:SetUsmSquadRole(sm.role)
            end

            timer.Simple(1.5, function()
                if (!IsValid(ply)) then return end
                ix.usms.SyncSquadToHUD(sm.squadID)
            end)
        else
            -- Not in a squad but CharVar says they are — clean up
            if (char:GetUsmSquadID() and char:GetUsmSquadID() != 0) then
                char:SetUsmSquadID(0)
                char:SetUsmSquadRole(0)
            end
        end
    else
        -- Not in unit membership cache. Ensure CharVars are clean.
        if (char:GetUsmUnitID() and char:GetUsmUnitID() != 0) then
            char:SetUsmUnitID(0)
            char:SetUsmUnitRole(0)
            char:SetUsmSquadID(0)
            char:SetUsmSquadRole(0)
        end
    end
end

--- When a new character is created, auto-assign to faction unit.
function PLUGIN:OnCharacterCreated(ply, char)
    if (!char) then return end

    -- Short delay to ensure character is fully initialized
    timer.Simple(0.5, function()
        if (!IsValid(ply)) then return end
        local character = ply:GetCharacter()
        if (!character or character:GetID() != char:GetID()) then return end

        AutoAssignToFactionUnit(char:GetID(), char)
    end)
end

--- When a player disconnects, update last seen.
function PLUGIN:PlayerDisconnected(ply)
    local char = ply:GetCharacter()
    if (!char) then return end

    local charID = char:GetID()
    local member = ix.usms.members[charID]

    if (member) then
        member.cachedLastSeen = os.time()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLASS OVERRIDE
-- ═══════════════════════════════════════════════════════════════════════════════

--- Prevent free class switching. Classes are controlled by USMS.
function PLUGIN:CanPlayerJoinClass(ply, class, info)
    return false, "Class changes must be performed at a loadout locker."
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- HUD SYNC TIMER
-- ═══════════════════════════════════════════════════════════════════════════════

timer.Create("ixUSMSHUDSync", ix.config.Get("usmsHUDSyncInterval", 3), 0, function()
    if (!ix.diegeticHUD or !ix.diegeticHUD.squads) then return end

    for squadID, squad in pairs(ix.usms.squads) do
        local hudSquadID = "usms_" .. squadID
        if (ix.diegeticHUD.squads[hudSquadID]) then
            ix.diegeticHUD.SyncSquad(hudSquadID)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- SQUAD COMMS INTEGRATION
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("USMSSquadMemberAdded", "ixUSMSComms", function(charID, squadID)
    local ply = ix.usms.GetPlayerByCharID(charID)
    if (!IsValid(ply)) then return end

    local squad = ix.usms.squads[squadID]
    if (!squad) then return end

    if (ix.diegeticHUD and ix.diegeticHUD.SendTransmission) then
        ix.diegeticHUD.SendTransmission(ply, "SQUAD COMMS", "4521.5", true, 2)
    end
end)
