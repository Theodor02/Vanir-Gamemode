local PLUGIN = PLUGIN or {}
PLUGIN.name = "Character Creation - Description System"
PLUGIN.author = "Theodor"
PLUGIN.desc = "Adds a character creation system."

ix.char.RegisterVar("head", {
    field = "head",
    fieldType = ix.type.number,
    default = 0,
    index = 2,
    OnSet = function(self, value)
        local client = self:GetPlayer()

        if IsValid(client) and client:GetCharacter() == self then
            local headBodygroupID
            for _, bodygroup in ipairs(client:GetBodyGroups()) do
                if bodygroup.name == "Head" then
                    headBodygroupID = bodygroup.id
                    break
                end
            end

            if headBodygroupID then
                client:SetBodygroup(headBodygroupID, value)
            else
                print("Error: Could not find 'Head' bodygroup.")
            end
        end

        self.vars.head = value
    end,
    OnGet = function(self, default)
        return self.vars.head or default
    end,
    OnValidate = function(self, value, payload)
        local faction = ix.faction.indices[payload.faction]
        if not faction.headChange then
            return false, "unknownError"
        end

        return value or 0
    end,
    ShouldDisplay = function(self, container, payload)
        local faction = ix.faction.indices[payload.faction]
        return faction.headChange or false
    end,
    OnDisplay = function(self, container, payload)
        local function EmitChange(pitch)
            LocalPlayer():EmitSound("weapons/ar2/ar2_empty.wav", 75, pitch or 150, 0.25)
        end

        local parent
        local current = container
        while (IsValid(current)) do
            if (IsValid(current.descriptionModel)) then
                parent = current
                break
            end
            current = current:GetParent()
        end
        parent = parent or container:GetParent():GetParent()

        local modelPanel = parent.descriptionModel
        local attributesPanel = parent.attributesModel

        local THEME = ix.ui and ix.ui.THEME
        local Scale = ix.ui and ix.ui.Scale or function(v) return v end

        local headSelect = container:Add("ixNumSlider")
        headSelect:Dock(TOP)
        headSelect:SetTall(Scale(22))
        headSelect:DockMargin(0, 0, 0, Scale(2))
        headSelect:GetLabel():SetText("HEAD")
        headSelect:SetMin(0)
        headSelect:SetMax(0)
        headSelect:SetValue(0)
        headSelect.nextUpdate = 0

        if THEME then
            headSelect.Paint = function(this, w, h)
                surface.SetDrawColor(Color(255, 255, 255, 15))
                surface.DrawLine(0, h - 1, w, h - 1)
            end
            headSelect:GetLabel():SetFont("ixImpMenuDiag")
            headSelect:GetLabel():SetTextColor(THEME.textMuted)

            if IsValid(headSelect.Slider) then
                headSelect.Slider.Paint = function(this, w, h)
                    surface.SetDrawColor(Color(255, 255, 255, 15))
                    surface.DrawRect(0, math.floor(h * 0.5) - 2, w, 4)
                end
                if IsValid(headSelect.Slider.Knob) then
                    headSelect.Slider.Knob.Paint = function(this, w, h)
                        surface.SetDrawColor(THEME.accent)
                        surface.DrawRect(math.floor(w * 0.5) - Scale(2), math.floor(h * 0.25), Scale(4), math.floor(h * 0.5))
                    end
                end
            end

            if IsValid(headSelect.TextArea) then
                headSelect.TextArea:SetFont("ixImpMenuDiag")
                headSelect.TextArea:SetTextColor(THEME.text)
                headSelect.TextArea.Paint = function(this, w, h)
                    this:DrawTextEntryText(THEME.text, Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 80), THEME.text)
                end
            end
        else
            headSelect:GetLabel():SetFont("ixSmallFont")
        end

        function headSelect:OnValueUpdated()
            local value = math.Round(self:GetValue())
            payload:Set("head", value)

            local function SetBodygroup(panel)
                if not IsValid(panel) then return end
                local ent = panel.Entity
                if not IsValid(ent) then return end
                for _, bg in ipairs(ent:GetBodyGroups()) do
                    if bg.name == "Head" or bg.name == "head" then
                        ent:SetBodygroup(bg.id, value)
                        break
                    end
                end
            end
            SetBodygroup(modelPanel)
            SetBodygroup(attributesPanel)

            local fraction = self:GetFraction()
            if fraction == 0 then EmitChange(75); return
            elseif fraction == 1 then EmitChange(120); return end
            if SysTime() > self.nextUpdate then
                EmitChange(85 + fraction * 15)
                self.nextUpdate = SysTime() + 0.05
            end
        end

        local function HookModelPanel(panel)
            if not IsValid(panel) then return end
            panel._SetModel = panel._SetModel or panel.SetModel
            function panel:SetModel(m)
                self:_SetModel(m)
                local ent = self.Entity
                if not IsValid(ent) then return end
                local maxVal = 0
                for _, bg in ipairs(ent:GetBodyGroups()) do
                    if bg.name == "Head" or bg.name == "head" then
                        maxVal = bg.num - 1
                        break
                    end
                end
                headSelect:SetMax(maxVal)
                headSelect:SetValue(0)
            end
        end

        HookModelPanel(modelPanel)
        HookModelPanel(attributesPanel)

        return headSelect
    end,
    alias = "Head"
})



hook.Add("CharacterLoaded", "gwCharHead", function(char)
    local client = char:GetPlayer()
    local headBodygroupID
    for _, bodygroup in ipairs(client:GetBodyGroups()) do
        if bodygroup.name == "Head" or bodygroup.name == "head" then
            headBodygroupID = bodygroup.id
            break
        end
    end
    
    if headBodygroupID then
        client:SetBodygroup(headBodygroupID, char.vars.head or 0)
    end
end)


hook.Add("OnCharacterCreated", "gwCharHead", function(client, char)
    local headBodygroupID
    for _, bodygroup in ipairs(client:GetBodyGroups()) do
        if bodygroup.name == "Head" or bodygroup.name == "head" then
            headBodygroupID = bodygroup.id
            break
        end
    end
    
    if headBodygroupID then
        Schema:SetCharBodygroup(client, headBodygroupID, char.vars.head or 0)
    end
end)


ix.command.Add("CharSetHead", {
    description = "Set the head bodygroup of a player.",
    adminOnly = true,
    arguments = {
        ix.type.character,
        bit.bor(ix.type.number, ix.type.optional)
    },
    OnRun = function(self, client, target, value)
        local targetPlayer = target:GetPlayer()
        if not IsValid(targetPlayer) then return end

        -- Find the head bodygroup ID
        local headBodygroupID
        for _, bodygroup in ipairs(targetPlayer:GetBodyGroups()) do
            if bodygroup.name == "Head" or bodygroup.name == "head" then
                headBodygroupID = bodygroup.id
                break
            end
        end

        if not headBodygroupID then
            client:Notify("Error: Could not find head bodygroup.")
            return
        end

        value = value or 0


        target:SetVar("head", value)
        targetPlayer:SetBodygroup(headBodygroupID, value)


        if Schema and Schema.SetCharBodygroup then
            Schema:SetCharBodygroup(targetPlayer, headBodygroupID, value)
        end

        client:Notify("You have set the head bodygroup of " .. target:GetName() .. " to " .. value .. ".")
        target:Notify("Your head bodygroup has been set to " .. value .. ".")
    end
})



ix.char.RegisterVar("attributes", {
    field = "attributes",
    fieldType = ix.type.text,
    default = {},
    index = 4,
    category = "attributes",
    isLocal = true,
    OnDisplay = function(self, container, payload)
        local maximum = hook.Run("GetDefaultAttributePoints", LocalPlayer(), payload) or 10

        if (maximum < 1) then return end

        local THEME = ix.ui and ix.ui.THEME
        local Scale = ix.ui and ix.ui.Scale or function(v) return v end

        local attributes = container:Add("DPanel")
        attributes:Dock(TOP)
        attributes.Paint = function() end

        local y = 0
        local total = 0
        payload.attributes = {}

        local function StyleSlider(slider)
            slider:SetTall(Scale(22))
            slider:DockMargin(0, 0, 0, Scale(2))

            if not THEME then return end

            slider.Paint = function(this, w, h)
                surface.SetDrawColor(Color(255, 255, 255, 15))
                surface.DrawLine(0, h - 1, w, h - 1)
            end
            slider:GetLabel():SetFont("ixImpMenuDiag")
            slider:GetLabel():SetTextColor(THEME.textMuted)

            if IsValid(slider.Slider) then
                slider.Slider.Paint = function(this, w, h)
                    surface.SetDrawColor(Color(255, 255, 255, 15))
                    surface.DrawRect(0, math.floor(h * 0.5) - 2, w, 4)
                end
                if IsValid(slider.Slider.Knob) then
                    slider.Slider.Knob.Paint = function(this, w, h)
                        surface.SetDrawColor(THEME.accent)
                        surface.DrawRect(math.floor(w * 0.5) - Scale(2), math.floor(h * 0.25), Scale(4), math.floor(h * 0.5))
                    end
                end
            end

            if IsValid(slider.TextArea) then
                slider.TextArea:SetFont("ixImpMenuDiag")
                slider.TextArea:SetTextColor(THEME.text)
                slider.TextArea.Paint = function(this, w, h)
                    this:DrawTextEntryText(THEME.text, Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 80), THEME.text)
                end
            end
        end

        -- Total remaining points (read-only display)
        local totalSlider = attributes:Add("ixNumSlider")
        totalSlider:Dock(TOP)
        totalSlider:SetMin(0)
        totalSlider:SetMax(maximum)
        totalSlider:SetValue(maximum)
        local leftText = L("attribPointsLeft") or "Points Left"
        if (leftText.utf8upper) then leftText = leftText:utf8upper() else leftText = string.upper(leftText) end
        totalSlider:GetLabel():SetText(leftText)
        StyleSlider(totalSlider)
        if IsValid(totalSlider.Slider) then totalSlider.Slider:SetEnabled(false) end
        if IsValid(totalSlider.TextArea) then totalSlider.TextArea:SetEnabled(false) end
        y = totalSlider:GetTall() + Scale(2)

        for k, v in SortedPairsByMemberValue(ix.attributes.list, "name") do
            if v.bNoDisplay then continue end
            payload.attributes[k] = 0

            local bar = attributes:Add("ixNumSlider")
            bar:Dock(TOP)
            bar:SetMin(0)
            bar:SetMax(maximum)
            bar:SetValue(0)

            local attrName = L(v.name) or v.name
            if (attrName.utf8upper) then attrName = attrName:utf8upper() else attrName = string.upper(attrName) end
            bar:GetLabel():SetText(attrName)

            StyleSlider(bar)

            if v.description and v.description != "" then
                bar:SetHelixTooltip(function(tooltip)
                    local description = tooltip:AddRow("description")
                    description:SetText(v.description)
                    description:SizeToContents()
                end)
            end

            if v.noStartBonus then
                if IsValid(bar.Slider) then bar.Slider:SetEnabled(false) end
                if IsValid(bar.TextArea) then bar.TextArea:SetEnabled(false) end
            else
                local prevValue = 0
                local clamping = false
                bar.OnValueChanged = function(this)
                    if clamping then return end
                    local newVal = math.Round(this:GetValue())
                    local diff = newVal - prevValue
                    if (total + diff) > maximum then
                        newVal = prevValue + (maximum - total)
                        diff = newVal - prevValue
                        clamping = true
                        bar:SetValue(newVal)
                        clamping = false
                    end
                    total = total + diff
                    payload.attributes[k] = newVal
                    prevValue = newVal
                    totalSlider:SetValue(maximum - total)
                end
            end

            y = y + bar:GetTall() + Scale(2)
        end

        attributes:SetTall(y)
        return attributes
    end,
    OnValidate = function(self, value, data, client)
        if (value != nil) then
            if (istable(value)) then
                local count = 0

                for _, v in pairs(value) do
                    count = count + v
                end

                if (count > (hook.Run("GetDefaultAttributePoints", client, count) or 10)) then
                    return false, "unknownError"
                end
            else
                return false, "unknownError"
            end
        end
    end,
    ShouldDisplay = function(self, container, payload)
        return !table.IsEmpty(ix.attributes.list)
    end
})
