-- ═══════════════════════════════════════════════════════════════════════════════
-- CLASS / LOADOUT SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

--- Get the total resource cost for a class loadout.
-- @param classIndex number
-- @return number
function ix.usms.GetLoadoutCost(classIndex)
    local classInfo = ix.class.list[classIndex]
    if (!classInfo or !classInfo.loadout) then return 0 end

    local total = 0
    for _, item in ipairs(classInfo.loadout) do
        local qty = item.quantity or 1
        total = total + (item.cost * qty)
    end
    return total
end

--- Get loadout items for a class.
-- @param classIndex number
-- @return table
function ix.usms.GetClassLoadout(classIndex)
    local classInfo = ix.class.list[classIndex]
    if (!classInfo) then return {} end
    return classInfo.loadout or {}
end

--- Change a character's class.
-- @param charID number Character ID
-- @param classIndex number Target class index
-- @param authorizerCharID number|nil
-- @param callback function(success, error)
function ix.usms.ChangeClass(charID, classIndex, authorizerCharID, callback)
    local char = ix.usms.GetCharacterByID(charID)
    if (!char) then
        if (callback) then callback(false, "Character not found or offline") end
        return
    end

    local classInfo = ix.class.list[classIndex]
    if (!classInfo) then
        if (callback) then callback(false, "Invalid class") end
        return
    end

    if (classInfo.faction != char:GetFaction()) then
        if (callback) then callback(false, "Class belongs to a different faction") end
        return
    end

    if (char:GetClass() == classIndex) then
        if (callback) then callback(false, "Already this class") end
        return
    end

    -- Whitelist check for self-service class changes (no authorizer)
    local member = ix.usms.members[charID]
    if (!authorizerCharID and member and !classInfo.isDefault) then
        local whitelist = member.classWhitelist or {}
        if (!table.HasValue(whitelist, classInfo.uniqueID)) then
            if (callback) then callback(false, "You are not whitelisted for this class") end
            return
        end
    end

    local canChange, reason = hook.Run("USMSCanChangeClass", char, classIndex, authorizerCharID)
    if (canChange == false) then
        if (callback) then callback(false, reason or "Not authorized") end
        return
    end

    local oldClass = char:GetClass()
    char:SetClass(classIndex)

    if (member) then
        -- Update cached class info (persist uniqueID for stable restoration)
        member.cachedClass = classIndex
        member.cachedClassName = classInfo.name
        member.cachedClassUID = classInfo.uniqueID or ""

        -- Auto-whitelist when an officer assigns a class
        if (authorizerCharID and classInfo.uniqueID) then
            member.classWhitelist = member.classWhitelist or {}
            if (!table.HasValue(member.classWhitelist, classInfo.uniqueID)) then
                table.insert(member.classWhitelist, classInfo.uniqueID)
            end
        end

        ix.usms.Log(member.unitID, USMS_LOG_UNIT_CLASS_CHANGED, authorizerCharID, charID, {
            oldClass = oldClass,
            newClass = classIndex,
            className = classInfo.name
        })

        ix.usms.db.Save()
    end

    -- Sync roster update so class change is visible
    if (member) then
        ix.usms.SyncRosterUpdateToUnit(member.unitID, charID, "update")

        local ply = ix.usms.GetPlayerByCharID(charID)
        if (IsValid(ply)) then
            ix.usms.FullSyncToPlayer(ply)
        end
    end

    if (callback) then callback(true) end
    hook.Run("USMSClassChanged", charID, oldClass, classIndex, authorizerCharID)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- GEAR-UP API (ARMORY)
-- ═══════════════════════════════════════════════════════════════════════════════

--- Gear up a character with their class loadout.
-- @param ply Player
-- @param callback function(success, error, itemsGranted, cost)
function ix.usms.GearUp(ply, callback)
    local char = ply:GetCharacter()
    if (!char) then
        if (callback) then callback(false, "No character") end
        return
    end

    local classIndex = char:GetClass()
    if (!classIndex or classIndex == 0) then
        if (callback) then callback(false, "No class assigned") end
        return
    end

    local classInfo = ix.class.list[classIndex]
    if (!classInfo or !classInfo.loadout) then
        if (callback) then callback(false, "Class has no loadout defined") end
        return
    end

    local charID = char:GetID()
    local member = ix.usms.members[charID]
    if (!member) then
        if (callback) then callback(false, "Not in a unit") end
        return
    end

    local unitID = member.unitID
    local unit = ix.usms.units[unitID]

    local inventory = char:GetInventory()
    if (!inventory) then
        if (callback) then callback(false, "No inventory") end
        return
    end

    -- Determine which items need to be granted
    local neededItems = {}
    local totalCost = 0

    for _, loadoutEntry in ipairs(classInfo.loadout) do
        local qty = loadoutEntry.quantity or 1

        -- Count how many of this item the player already has
        local existing = 0
        for _, invItem in pairs(inventory:GetItems()) do
            if (invItem.uniqueID == loadoutEntry.uniqueID) then
                existing = existing + 1
            end
        end

        local needed = math.max(0, qty - existing)
        if (needed > 0) then
            table.insert(neededItems, {
                uniqueID = loadoutEntry.uniqueID,
                name = loadoutEntry.name,
                cost = loadoutEntry.cost,
                quantity = needed
            })
            totalCost = totalCost + (loadoutEntry.cost * needed)
        end
    end

    if (#neededItems == 0) then
        if (callback) then callback(false, "Already fully equipped") end
        return
    end

    -- Check unit resources
    if (unit.resources < totalCost) then
        if (callback) then callback(false, "Insufficient unit resources (" .. totalCost .. " needed, " .. unit.resources .. " available)") end
        return
    end

    -- Hook for additional checks
    local canGearUp, reason = hook.Run("USMSCanGearUp", ply, char, neededItems, totalCost)
    if (canGearUp == false) then
        if (callback) then callback(false, reason or "Gear-up denied") end
        return
    end

    -- Deduct resources
    ix.usms.DeductResources(unitID, totalCost, "gearup:" .. classInfo.name, charID)

    -- Grant items
    local granted = {}
    for _, item in ipairs(neededItems) do
        for i = 1, item.quantity do
            inventory:Add(item.uniqueID, 1, nil, nil, true)
            table.insert(granted, item.uniqueID)
        end
    end

    ix.usms.Log(unitID, USMS_LOG_GEARUP, charID, nil, {
        class = classInfo.name,
        items = granted,
        cost = totalCost
    })

    if (callback) then callback(true, nil, granted, totalCost) end
    hook.Run("USMSGearUp", ply, char, granted, totalCost)

    -- Sync updated inventory/resources to the player
    if (IsValid(ply)) then
        ix.usms.FullSyncToPlayer(ply)
    end
end

