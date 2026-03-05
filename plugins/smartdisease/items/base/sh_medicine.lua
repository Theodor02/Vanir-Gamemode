--- Base Medicine Item
-- All medicine and vaccine items inherit from this base.
-- Handles consumption logic, overdose tracking, and cure application.
-- @item base_medicine

ITEM.name = "Medicine"
ITEM.description = "A medical compound."
ITEM.model = "models/smartmeds/meds.mdl"
ITEM.category = "Medical Supplies"
ITEM.width = 1
ITEM.height = 1
ITEM.weight = 0.2
ITEM.isBase = true

-- Medicine type: "antiviral", "antibiotic", "antipsychotic", "antianxiety", "vaccine"
ITEM.medicineType = "generic"

-- For vaccines: which disease this vaccinates against
ITEM.vaccineTarget = nil

-- Skin index for the model
ITEM.skin = 0

-- ═══════════════════════════════════════════════════════════════════════════════
-- DYNAMIC DESCRIPTION
-- ═══════════════════════════════════════════════════════════════════════════════

function ITEM:GetDescription()
    local lines = {self.description}

    if (self.medicineType == "vaccine" and self.vaccineTarget) then
        local disease = ix.disease.Get(self.vaccineTarget)
        local diseaseName = disease and disease.name or self.vaccineTarget
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Vaccinates against: " .. diseaseName
    elseif (self.medicineType != "generic") then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Treats: " .. string.upper(self.medicineType) .. " conditions"
    end

    return table.concat(lines, "\n")
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- ITEM FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Take the medicine yourself.
ITEM.functions.Use = {
    name = "Take Medicine",
    tip = "Take this medicine to treat your ailments.",
    icon = "icon16/pill.png",
    OnRun = function(item)
        local client = item.player
        if (!IsValid(client) or !client:Alive()) then
            return false
        end

        local character = client:GetCharacter()
        if (!character) then
            client:Notify("No active character.")
            return false
        end

        -- Handle vaccine
        if (item.medicineType == "vaccine" and item.vaccineTarget) then
            ix.disease.Vaccinate(character, item.vaccineTarget)
            client:Notify("The vaccine has been administered.")

            -- /me action
            if (ix.config.Get("diseaseMeActions", true)) then
                ix.chat.Send(client, "me", "injects themselves with a vaccine")
            end

            return true -- consume
        end

        -- Handle general medicine
        local treated = ix.disease.ApplyMedicine(character, item.medicineType)

        -- Track overdose
        local overdosed = ix.disease.TrackMedicineUse(character, item.medicineType)

        if (treated) then
            client:Notify("The " .. item.medicineType .. " begins to work.")
        else
            client:Notify("The medicine doesn't seem to help your current condition.")
        end

        -- /me action
        if (ix.config.Get("diseaseMeActions", true)) then
            ix.chat.Send(client, "me", "takes some medicine")
        end

        return true -- consume
    end,
}

--- Administer to another player.
ITEM.functions.Administer = {
    name = "Administer (Target)",
    tip = "Administer this medicine to the player you are looking at.",
    icon = "icon16/heart_add.png",
    OnRun = function(item)
        local client = item.player
        if (!IsValid(client)) then return false end

        -- Trace for target
        local trace = client:GetEyeTrace()
        local target = trace.Entity

        if (!IsValid(target) or !target:IsPlayer() or client:GetPos():DistToSqr(target:GetPos()) > 10000) then
            client:Notify("No valid target in range. Look at a player within ~3 metres.")
            return false
        end

        if (!target:Alive()) then
            client:Notify("Target is incapacitated.")
            return false
        end

        local targetChar = target:GetCharacter()
        if (!targetChar) then
            client:Notify("Target has no active character.")
            return false
        end

        -- Handle vaccine
        if (item.medicineType == "vaccine" and item.vaccineTarget) then
            ix.disease.Vaccinate(targetChar, item.vaccineTarget)
            target:Notify("You have been vaccinated.")
            client:Notify("Vaccine administered to " .. (targetChar:GetName() or target:Nick()) .. ".")

            if (ix.config.Get("diseaseMeActions", true)) then
                ix.chat.Send(client, "me", "administers a vaccine to " .. (targetChar:GetName() or target:Nick()))
            end

            return true
        end

        -- Handle general medicine
        local treated = ix.disease.ApplyMedicine(targetChar, item.medicineType)
        ix.disease.TrackMedicineUse(targetChar, item.medicineType)

        if (treated) then
            target:Notify("You have been given medicine. It begins to take effect.")
            client:Notify("Medicine administered to " .. (targetChar:GetName() or target:Nick()) .. ".")
        else
            client:Notify("The medicine doesn't seem to help their condition.")
        end

        if (ix.config.Get("diseaseMeActions", true)) then
            ix.chat.Send(client, "me", "administers medicine to " .. (targetChar:GetName() or target:Nick()))
        end

        return true
    end,
}
