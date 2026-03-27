--- Server-Side Networking, Formula Registry & Persistence (v2.0/2.1/2.2)
-- Handles all net message registration, receiving, character data persistence,
-- canister creation, test credit tracking, status promotion, and experimental broadcasts.
-- @module ix.bacta (server)

-- ═══════════════════════════════════════════════════════════════════════════════
-- NETWORK STRINGS
-- ═══════════════════════════════════════════════════════════════════════════════

util.AddNetworkString("ixBactaOpen")
util.AddNetworkString("ixBactaSubmit")
util.AddNetworkString("ixBactaResult")
util.AddNetworkString("ixBactaRegister")
util.AddNetworkString("ixBactaFabricate")
util.AddNetworkString("ixBactaEffect")
util.AddNetworkString("ixBactaHallucination")
util.AddNetworkString("ixBactaSyncBalance")
util.AddNetworkString("ixBactaSyncRecipes")
util.AddNetworkString("ixBactaSyncPool")
util.AddNetworkString("ixBactaPoolInfluence")
util.AddNetworkString("ixBactaRefine")
util.AddNetworkString("ixBactaIntegrityCheck")
util.AddNetworkString("ixBactaExperimentalBroadcast")
util.AddNetworkString("ixBactaStatusPromotion")

-- ═══════════════════════════════════════════════════════════════════════════════
-- PENDING TEST CREDITS
-- Tracks test credit grants to prevent abuse within a session.
-- ═══════════════════════════════════════════════════════════════════════════════

ix.bacta.pendingTestCredits = ix.bacta.pendingTestCredits or {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- FORMULA REGISTRATION → CANISTER CREATION (v2.0)
-- Instead of storing to character data, creates a physical canister item.
-- ═══════════════════════════════════════════════════════════════════════════════

--- Register a compound formula by creating a canister item.
-- v2.0: Physical canisters replace character-data formula storage.
-- @param client Entity The player
-- @param name string Formula name
-- @param sequence table Strand ID array
-- @param effects table Resolved effects array
-- @param stability number Stability score
-- @param totalPotency number Total potency score
-- @param cascadeResult table|nil Cascade resolution result
-- @param flags table|nil Synthesis flags
-- @return bool success
-- @return string|nil error
function ix.bacta.RegisterFormula(client, name, sequence, effects, stability, totalPotency, cascadeResult, flags)
    if (!IsValid(client)) then return false, "Invalid player." end

    local char = client:GetCharacter()
    if (!char) then return false, "No active character." end

    local inv = char:GetInventory()
    if (!inv) then return false, "No inventory available." end

    -- Sanitise name
    name = string.sub(string.Trim(name), 1, 64)
    if (name == "") then
        return false, "Formula name cannot be empty."
    end

    -- Weight carry check (v2.2 weight integration)
    if (ix.weight and ix.weight.CanCarry) then
        local carry = char:GetData("carry", 0)
        if (!ix.weight.CanCarry(0.5, carry, char)) then
            return false, "Cannot carry a canister. Reduce your load first."
        end
    end

    -- Build cascade summary
    local cascadeSummary = cascadeResult and ix.bacta.CascadeSummary(cascadeResult) or nil
    local chainDepth = cascadeResult and cascadeResult.chainDepth or 0
    local chainPurity = cascadeResult and cascadeResult.chainPurity or 1.0

    local canisterData = {
        formulaName    = name,
        sequence       = sequence,
        effects        = effects,
        stability      = stability,
        totalPotency   = totalPotency,
        durability     = 100,
        status         = "experimental",
        test_count     = 0,
        fabricated_by  = client:SteamID(),
        created_at     = os.time(),
        item_type      = ix.bacta.DetermineItemType(sequence),
        uses           = ix.bacta.DetermineUses(sequence),
        cascadeSummary = cascadeSummary,
        chainDepth     = chainDepth,
        chainPurity    = chainPurity,
        flags          = flags or {},
    }

    if (inv.CanAdd) then
        local canAdd, reason = inv:CanAdd("synth_canister", 1, canisterData)
        if (canAdd == false) then
            local msg = "Inventory full. Could not create canister."
            if (reason != nil) then
                msg = "Cannot create canister: " .. tostring(reason) .. "."
            end
            return false, msg
        end
    end

    -- Create canister item
    local ok = inv:Add("synth_canister", 1, canisterData)

    if (!ok) then
        return false, "Inventory full. Could not create canister."
    end

    client:Notify("Formula Canister created: " .. name)

    return true, nil
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TEST CREDIT & STATUS PROMOTION (v2.0)
-- ═══════════════════════════════════════════════════════════════════════════════

--- Increment test credits for a canister after successful use.
-- @param canisterItemID number Helix item ID
-- @param userSteamID string SteamID of the user (not the synthesist)
function ix.bacta.IncrementTestCredit(canisterItemID, userSteamID)
    local item = ix.item.instances[canisterItemID]
    if (!item) then return end

    local count = item:GetData("test_count", 0) + 1
    item:SetData("test_count", count)

    -- Check for status promotion
    local currentStatus = item:GetData("status", "experimental")
    local thresholds = ix.bacta.Config.TESTING_THRESHOLDS or {tested = 5, proven = 15}

    local newStatus = currentStatus
    if (currentStatus == "experimental" and count >= thresholds.tested) then
        newStatus = "tested"
    elseif (currentStatus == "tested" and count >= thresholds.proven) then
        newStatus = "proven"
    end

    if (newStatus != currentStatus) then
        item:SetData("status", newStatus)

        -- Notify the canister owner
        local ownerPlayer = ix.bacta.FindPlayerBySteamID(item:GetData("fabricated_by", ""))
        if (IsValid(ownerPlayer)) then
            ownerPlayer:Notify("Formula '" .. item:GetData("formulaName", "Unknown") .. "' has been promoted to " .. string.upper(newStatus) .. " status!")

            net.Start("ixBactaStatusPromotion")
                net.WriteUInt(canisterItemID, 32)
                net.WriteString(newStatus)
                net.WriteString(item:GetData("formulaName", "Unknown"))
            net.Send(ownerPlayer)
        end
    end
end

--- Find a connected player by SteamID.
-- @param steamID string
-- @return Entity|nil
function ix.bacta.FindPlayerBySteamID(steamID)
    for _, ply in ipairs(player.GetAll()) do
        if (ply:SteamID() == steamID) then
            return ply
        end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- EXPERIMENTAL BROADCAST (v2.0)
-- When an experimental compound is used, nearby players are notified.
-- ═══════════════════════════════════════════════════════════════════════════════

--- Broadcast an experimental compound use to nearby players.
-- @param user Entity The player who used the compound
-- @param formulaName string Name of the formula
-- @param effects table Effects array for summary
function ix.bacta.BroadcastExperimentalUse(user, formulaName, effects)
    if (!IsValid(user)) then return end

    local range = ix.bacta.Config.EXPERIMENTAL_BROADCAST_RANGE or 512
    local pos = user:GetPos()

    -- Build summary of visible effects (no detailed magnitudes)
    local effectNames = {}
    for _, eff in ipairs(effects) do
        local effectType = ix.bacta.effectTypes[eff.type]
        if (effectType and !ix.bacta.IsSideEffect(eff.type)) then
            effectNames[#effectNames + 1] = effectType.name or eff.type
        end
    end
    local summary = table.concat(effectNames, ", ")

    for _, ply in ipairs(player.GetAll()) do
        if (ply == user) then continue end
        if (ply:GetPos():Distance(pos) > range) then continue end

        net.Start("ixBactaExperimentalBroadcast")
            net.WriteEntity(user)
            net.WriteString(formulaName)
            net.WriteString(summary)
        net.Send(ply)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- REFINEMENT (v2.2)
-- ═══════════════════════════════════════════════════════════════════════════════

--- Refine a canister to improve its stability.
-- @param client Entity The player
-- @param canisterItemID number Helix item ID
-- @return bool success
-- @return string|nil error
function ix.bacta.RefineCanister(client, canisterItemID)
    if (!IsValid(client)) then return false, "Invalid player." end

    local char = client:GetCharacter()
    if (!char) then return false, "No active character." end

    local item = ix.item.instances[canisterItemID]
    if (!item) then return false, "Canister not found." end
    if (item:GetOwner() != client) then return false, "You don't own this canister." end

    local cfg = ix.bacta.Config.REFINEMENT or {}
    local cost = cfg.cost or 15
    local stabilityGain = cfg.stability_gain or 5
    local maxStability = cfg.max_stability or 100

    local balance = char:GetData("bactaSGC", 0)
    if (balance < cost) then
        return false, "Insufficient SGC. Need " .. cost .. ", have " .. balance .. "."
    end

    local currentStab = item:GetData("stability", 50)
    if (currentStab >= maxStability) then
        return false, "Canister is already at maximum stability."
    end

    -- Deduct SGC
    char:SetData("bactaSGC", balance - cost)

    -- Apply stability gain
    local newStab = math.min(maxStability, currentStab + stabilityGain)
    item:SetData("stability", newStab)

    -- Sync
    net.Start("ixBactaSyncBalance")
        net.WriteUInt(char:GetData("bactaSGC", 0), 16)
    net.Send(client)

    client:Notify("Canister refined: stability " .. currentStab .. " → " .. newStab .. " (" .. cost .. " SGC consumed).")

    return true, nil
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- NET RECEIVERS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Client → Server: Submit a sequence for exploratory synthesis.
net.Receive("ixBactaSubmit", function(len, client)
    if (!IsValid(client) or !client:GetCharacter()) then return end

    local sequence = net.ReadTable()

    -- Validate sequence structure
    local valid, err = ix.bacta.ValidateSequence(sequence)
    if (!valid) then
        client:Notify("Synthesis failed: " .. (err or "Invalid sequence."))
        return
    end

    -- Validate against session pool
    if (!ix.bacta.ValidateSessionPool(client, sequence)) then
        client:Notify("Synthesis failed: Sequence contains strands not in your current session pool.")
        return
    end

    -- Resolve
    local effects, stability, potency, bContaminated, cascadeResult, flags = ix.bacta.ResolveSequence(sequence, true)

    -- Build cascade summary
    local cascadeSummary = cascadeResult and ix.bacta.CascadeSummary(cascadeResult) or nil

    -- Send result back to client
    net.Start("ixBactaResult")
        net.WriteTable({
            effects         = effects,
            stability       = stability,
            potency         = potency,
            contaminated    = bContaminated,
            item_type       = ix.bacta.DetermineItemType(sequence),
            uses            = ix.bacta.DetermineUses(sequence),
            sequence        = sequence,
            cascadeSummary  = cascadeSummary,
            chainDepth      = cascadeResult and cascadeResult.chainDepth or 0,
            chainPurity     = cascadeResult and cascadeResult.chainPurity or 1.0,
            flags           = flags or {},
        })
    net.Send(client)
end)

--- Client → Server: Register a formula from the last synthesis result (creates canister).
net.Receive("ixBactaRegister", function(len, client)
    if (!IsValid(client) or !client:GetCharacter()) then return end

    local name     = net.ReadString()
    local sequence = net.ReadTable()

    -- Validate the sequence
    local valid, err = ix.bacta.ValidateSequence(sequence)
    if (!valid) then
        client:Notify("Registration failed: " .. (err or "Invalid sequence."))
        return
    end

    -- Re-resolve the sequence server-side (production mode, no variance)
    local effects, stability, potency, _, cascadeResult, flags = ix.bacta.ResolveSequence(sequence, false)

    local ok, regErr = ix.bacta.RegisterFormula(client, name, sequence, effects, stability, potency, cascadeResult, flags)
    if (!ok) then
        client:Notify("Registration failed: " .. (regErr or "Unknown error."))
        return
    end
end)

--- Client → Server: Initiate batch fabrication from a canister.
net.Receive("ixBactaFabricate", function(len, client)
    if (!IsValid(client) or !client:GetCharacter()) then return end

    local canisterItemID = net.ReadUInt(32)
    local bIntegrityConfirmed = net.ReadBool()

    local ok, err = ix.bacta.FabricateFromCanister(client, canisterItemID, bIntegrityConfirmed)
    if (!ok and err) then
        client:Notify("Fabrication failed: " .. err)
    end
end)

--- Client → Server: Request pool influence (add strand from outside pool).
net.Receive("ixBactaPoolInfluence", function(len, client)
    if (!IsValid(client) or !client:GetCharacter()) then return end

    local strandID = net.ReadString()

    local ok, err = ix.bacta.ApplyPoolInfluence(client, strandID)
    if (!ok) then
        client:Notify("Pool Influence failed: " .. (err or "Unknown error."))
    end
end)

--- Client → Server: Refine a canister.
net.Receive("ixBactaRefine", function(len, client)
    if (!IsValid(client) or !client:GetCharacter()) then return end

    local canisterItemID = net.ReadUInt(32)

    local ok, err = ix.bacta.RefineCanister(client, canisterItemID)
    if (!ok) then
        client:Notify("Refinement failed: " .. (err or "Unknown error."))
    end
end)

--- Client → Server: Confirm integrity check and proceed with fabrication.
net.Receive("ixBactaIntegrityCheck", function(len, client)
    if (!IsValid(client) or !client:GetCharacter()) then return end

    local canisterItemID = net.ReadUInt(32)
    local confirmed = net.ReadBool()

    if (confirmed) then
        local ok, err = ix.bacta.FabricateFromCanister(client, canisterItemID, true)
        if (!ok and err) then
            client:Notify("Fabrication failed: " .. err)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- PERSISTENCE HOOKS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Clean up session data when a player disconnects.
-- v2.0: Sessions persist for 30 minutes (timer-based), cleaned up on disconnect.
hook.Add("PlayerDisconnected", "ixBactaSessionCleanup", function(ply)
    -- Remove session pool timer
    if (ix.bacta.sessions[ply]) then
        local timerID = "ixBactaPoolExpiry_" .. ply:SteamID()
        if (timer.Exists(timerID)) then
            timer.Remove(timerID)
        end
    end

    ix.bacta.sessions[ply] = nil
    ix.bacta.fabricating[ply] = nil
    ix.bacta.pendingTestCredits[ply] = nil
end)

--- When a character is loaded, flush pending test credits.
hook.Add("CharacterLoaded", "ixBactaLoadRecipes", function(character)
    -- Recipes are now stored as canister items rather than character data.
    -- This hook remains as an extension point.
end)

--- On player initial spawn, initialise test credit tracking.
hook.Add("PlayerInitialSpawn", "ixBactaInitTestCredits", function(ply)
    ix.bacta.pendingTestCredits[ply] = {}
end)
