local THEME = ix.ui.THEME
local Scale = ix.ui.Scale

local function ApplySubpanelTitle(panel)
	if (!IsValid(panel) or !IsValid(panel.title)) then return end
	panel.title:SetFont("ixImpMenuTitle")
	panel.title:SetTextColor(THEME.text)
	panel.title:SetContentAlignment(4)
	panel.title:DockMargin(Scale(8), 0, 0, Scale(10))
	panel.title:SizeToContents()
end

local function ApplyToChildren(panel, callback)
	if (!IsValid(panel)) then
		return
	end

	callback(panel)

	for _, child in ipairs(panel:GetChildren() or {}) do
		ApplyToChildren(child, callback)
	end
end

local function ApplyCharMenuStatic(panel)
	if (!IsValid(panel)) then
		return
	end

	panel.__ixImpFramePadding = Scale(26)
	panel.Paint = function(this, width, height)
		surface.SetDrawColor(THEME.background)
		surface.DrawRect(0, 0, width, height)

		local framePad = this.__ixImpFramePadding or Scale(26)
		surface.SetDrawColor(THEME.frame)
		surface.DrawOutlinedRect(framePad, framePad, width - framePad * 2, height - framePad * 2)

		draw.SimpleText("IMPERIAL MAIN MENU", "ixImpMenuLabel", framePad + Scale(8), framePad + Scale(6), THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	local factionModelPanel = panel.factionModel and panel.factionModel:GetParent()
	local descriptionModelPanel = panel.descriptionModel and panel.descriptionModel:GetParent()
	local attributesModelPanel = panel.attributesModel and panel.attributesModel:GetParent()

	if (IsValid(factionModelPanel)) then 
        factionModelPanel:DockMargin(Scale(8), Scale(8), Scale(8), Scale(8)) 
    end
	if (IsValid(descriptionModelPanel)) then 
        descriptionModelPanel:DockMargin(Scale(8), Scale(8), Scale(8), Scale(8)) 
    end
	if (IsValid(attributesModelPanel)) then 
        attributesModelPanel:DockMargin(Scale(8), Scale(8), Scale(8), Scale(8)) 
    end

	ix.ui.ApplyScreeningPanel(factionModelPanel, "ENLISTMENT SCREENING")
	ix.ui.ApplyScreeningPanel(descriptionModelPanel, "BIOGRAPHIC REVIEW")
	ix.ui.ApplyScreeningPanel(attributesModelPanel, "APTITUDE SCREENING")

	-- If factionButtonsPanel is inside a container that already has ApplyDataPanel (our new layout), don't apply it again
    -- We detect this by checking if it's a ScrollPanel
    if (panel.factionButtonsPanel:GetName() != "DScrollPanel") then
	    ix.ui.ApplyDataPanel(panel.factionButtonsPanel, "ENLISTMENT OPTIONS")
    end

	ix.ui.ApplyDataPanel(panel.descriptionPanel, "PERSONNEL RECORD")
	ix.ui.ApplyDataPanel(panel.attributesPanel, "APTITUDE MATRIX")

	local sideMargin = Scale(8)
	local sideTop = Scale(12)
	-- Only apply margins if it's NOT the scroll panel version (which has its own margins set in Init)
    if (IsValid(panel.factionButtonsPanel) and panel.factionButtonsPanel:GetName() != "DScrollPanel") then
		panel.factionButtonsPanel:DockMargin(sideMargin, sideTop, sideMargin, sideTop)
	end

	if (IsValid(panel.descriptionPanel)) then
		panel.descriptionPanel:DockMargin(sideMargin, sideTop, sideMargin, sideTop)
		panel.descriptionPanel:DockPadding(Scale(8), Scale(10), Scale(8), Scale(8))
	end

	if (IsValid(panel.attributesPanel)) then
		panel.attributesPanel:DockMargin(sideMargin, sideTop, sideMargin, sideTop)
		panel.attributesPanel:DockPadding(Scale(8), Scale(10), Scale(8), Scale(8))
	end

	if (IsValid(panel.factionPanel)) then
		panel.factionPanel:SetTitle("enlistment")
		ApplySubpanelTitle(panel.factionPanel)
        if (IsValid(panel.factionPanel.title)) then
            panel.factionPanel.title:DockMargin(Scale(8), 0, 0, Scale(10))
        end
	end

	if (IsValid(panel.description)) then
		panel.description:SetTitle("profiling")
		ApplySubpanelTitle(panel.description)
	end

	if (IsValid(panel.attributes)) then
		panel.attributes:SetTitle("aptitude")
		ApplySubpanelTitle(panel.attributes)
	end

	ix.ui.ApplyProgressStyle(panel.progress)
end

local function ApplyCharMenuDynamic(panel)
	if (!IsValid(panel)) then
		return
	end

	ApplySubpanelTitle(panel.factionPanel)
	ApplySubpanelTitle(panel.description)
	ApplySubpanelTitle(panel.attributes)
	ix.ui.ApplyProgressStyle(panel.progress)

	ApplyToChildren(panel, function(child)
		local className = child:GetClassName()
		if (className == "ixMenuButton" or className == "ixMenuSelectionButton") then
			local label = child:GetText() or ""
			local upper = label:utf8upper()
			local style = "default"

			if (upper:find("PROCEED") or upper:find("CONFIRM") or upper:find("FINISH") or upper:find("AUTHORIZE")) then
				style = "accent"
			elseif (upper:find("RETURN") or upper:find("BACK")) then
				style = "danger"
			end

			ix.ui.ApplyButtonSounds(child)
			ix.ui.ApplyImpButtonStyle(child, style)
			child:SetTall(Scale(44))

			local dock = child:GetDock()
			if (dock == BOTTOM) then
				child:DockMargin(Scale(8), Scale(8), Scale(8), Scale(8))
				local screeningParent = ix.ui.FindScreeningParent(child)
				if (IsValid(screeningParent)) then
					local footer = child:GetTall() + Scale(16)
					screeningParent.__ixImpFooterHeight = math.max(screeningParent.__ixImpFooterHeight or 0, footer)
				else
					local dataParent = ix.ui.FindDataPanelParent(child)
					if (IsValid(dataParent)) then
						local footer = child:GetTall() + Scale(16)
						dataParent.__ixImpFooterHeight = math.max(dataParent.__ixImpFooterHeight or 0, footer)
					end
				end
			elseif (dock == TOP) then
				child:DockMargin(Scale(8), Scale(8), Scale(8), 0)
			else
				child:DockMargin(Scale(8), Scale(6), Scale(8), Scale(6))
			end

			local text = child:GetText() or ""
			if (text:find("PROCEED")) then
				child:SetText("confirm", true)
			elseif (text:find("RETURN")) then
				child:SetText("back", true)
			elseif (text:find("FINISH")) then
				child:SetText("authorize", true)
			end
		end

		if (child.IsA and child:IsA("DLabel")) then
			ix.ui.ApplyCharVarLabelStyle(child)
			if (child:GetText() == "NAME" or child:GetText() == "DESCRIPTION") then
				-- Specific forcing for known labels if needed
				child:SetFont("ixImpMenuLabel")
				child:SetTextColor(THEME.accentSoft)
			end
		elseif (child.IsA and (child:IsA("DTextEntry") or child:GetClassName() == "ixTextEntry")) then
			ix.ui.ApplyTextEntryStyle(child)
		elseif (className == "DScrollPanel") then
			ix.ui.ApplyModelPanelStyle(child)
		elseif (className == "DIconLayout") then
			ix.ui.ApplyIconLayoutStyle(child)
		elseif (className == "SpawnIcon") then
			ix.ui.ApplySpawnIconStyle(child)
		elseif (className == "ixAttributeBar") then
			ix.ui.ApplyAttributeBarStyle(child)
			if (IsValid(child.add)) then ix.ui.ApplyAttributeButtonStyle(child.add, "+") end
			if (IsValid(child.sub)) then ix.ui.ApplyAttributeButtonStyle(child.sub, "-") end
		elseif (className == "ixCategoryPanel") then
			ix.ui.ApplyCategoryPanelStyle(child)
		end
	end)
end

DEFINE_BASECLASS("ixCharMenuPanel")
local PANEL = {}

function PANEL:Init()
	BaseClass.Init(self)
	local parent = self:GetParent()
	local padding = Scale(32)
	local halfWidth = parent:GetWide() * 0.5 - (padding * 2)
	local halfHeight = parent:GetTall() * 0.5 - (padding * 2)
	local modelFOV = (ScrW() > ScrH() * 1.8) and 120 or 78

	self:ResetPayload(true)

	self.factionButtons = {}
	self.repopulatePanels = {}

	-- faction selection subpanel
	self.factionPanel = self:AddSubpanel("faction", true)
	self.factionPanel:SetTitle("chooseFaction")
	self.factionPanel.OnSetActive = function()
		-- if we only have one faction, we are always selecting that one so we can skip to the description section
		if (#self.factionButtons == 1) then
			self:SetActiveSubpanel("description", 0)
		end
	end

	-- Wrapper for the whole right side of faction panel
	local factionRight = self.factionPanel:Add("Panel")
	factionRight:Dock(RIGHT)
	factionRight:SetSize(halfWidth * 0.6, halfHeight)
	
	-- Button footer panel for faction (Outside the bioscan)
	local factionFooter = factionRight:Add("Panel")
	factionFooter:SetTall(Scale(64))
	factionFooter:Dock(BOTTOM)
	factionFooter:DockMargin(Scale(8), Scale(8), Scale(8), Scale(8))
	factionFooter.Paint = function() end

	local proceed = factionFooter:Add("ixImpButton")
	proceed:SetLabel("PROCEED")
	proceed:SetStyle("accent")
	proceed:Dock(RIGHT)
	proceed:DockMargin(Scale(4), 0, 0, 0)
	proceed:SetWide(halfWidth * 0.6 * 0.48) -- ~Half of the panel width
	proceed.DoClick = function()
		self.progress:IncrementProgress()

		self:Populate()
		self:SetActiveSubpanel("description")
	end

	local factionBack = factionFooter:Add("ixImpButton")
	factionBack:SetLabel("RETURN")
	factionBack:SetStyle("danger")
	factionBack:Dock(LEFT)
	factionBack:DockMargin(0, 0, Scale(4), 0)
	factionBack:SetWide(halfWidth * 0.6 * 0.48)
	factionBack.DoClick = function()
		self.progress:DecrementProgress()

		self:SetActiveSubpanel("faction", 0)
		self:SlideDown()

		parent.mainPanel:Undim()
	end

	-- The Bioscan/Visual Panel (Above buttons)
	local modelList = factionRight:Add("Panel")
	modelList:Dock(FILL)

	self.factionModel = modelList:Add("ixModelPanel")
	self.factionModel:Dock(FILL)
	self.factionModel:SetModel("models/error.mdl")
	self.factionModel:SetFOV(modelFOV - 35)
	self.factionModel.PaintModel = self.factionModel.Paint

	-- Left side wrapper for faction list + info
	local factionLeft = self.factionPanel:Add("Panel")
	factionLeft:Dock(FILL)
    
    -- Sub-container for Faction List (Top Box)
    local factionListContainer = factionLeft:Add("Panel")
    factionListContainer:Dock(FILL)
    -- Add margins to simulate spacing between boxes
    factionListContainer:DockMargin(Scale(8), Scale(8), Scale(8), Scale(8))
	ix.ui.ApplyDataPanel(factionListContainer, "ENLISTMENT OPTIONS")

	self.factionButtonsPanel = factionListContainer:Add("DScrollPanel")
	self.factionButtonsPanel:Dock(FILL)
	self.factionButtonsPanel:DockMargin(Scale(8), Scale(32), Scale(8), Scale(8))
    self.factionButtonsPanel.Paint = function() end
    
    ix.ui.ApplyScrollbarStyle(self.factionButtonsPanel)

	-- Faction Info Panel (Bottom Box)
	self.factionInfoPanel = factionLeft:Add("Panel")
	self.factionInfoPanel:Dock(BOTTOM)
	self.factionInfoPanel:SetTall(Scale(140))
	self.factionInfoPanel:DockMargin(Scale(8), 0, Scale(8), Scale(8))
    
    -- Use standard header style + custom content
	self.factionInfoPanel.Paint = function(this, w, h)
        -- Draw Standard Background & Header
		surface.SetDrawColor(Color(0, 0, 0, 200))
		surface.DrawRect(0, 0, w, h)

		local headerH = Scale(24)
		surface.SetDrawColor(THEME.frameSoft)
		surface.DrawRect(0, 0, w, headerH)
		surface.DrawOutlinedRect(0, 0, w, h)

		draw.SimpleText("FACTION INTELLIGENCE", "ixImpMenuButton", Scale(8), headerH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        
        -- Custom Content
        if (!self.payload.faction) then return end
        local factionIdx = self.payload.faction
        local faction = ix.faction.indices[factionIdx]
        if (!faction) then return end
        
        local factionName = faction.name or "UNKNOWN"
        local y = headerH + Scale(12)
        local x = Scale(12)
        
        surface.SetFont("ixImpMenuTitle")
        local name = L(factionName):utf8upper()
        draw.SimpleText(name, "ixImpMenuTitle", x, y, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        local _, th = surface.GetTextSize(name)
        y = y + th + Scale(4) 

        local desc = faction.description
        if (desc and #desc > 0) then
            -- Simple wrap
            local wAvail = w - x * 2
            local words = string.Explode(" ", desc)
            local line = ""
            for i, word in ipairs(words) do
                local test = line .. word .. " "
                surface.SetFont("ixImpMenuLabel")
                local tw, _ = surface.GetTextSize(test)
                if (tw > wAvail) then
                    draw.SimpleText(line, "ixImpMenuLabel", x, y, THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    y = y + Scale(14)
                    line = word .. " "
                else
                    line = test
                end
            end
            draw.SimpleText(line, "ixImpMenuLabel", x, y, THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
	end
    
    self.factionInfoLabel = self.factionInfoPanel:Add("Panel") -- Dummy for invalidation triggers
    self.factionInfoLabel:SetVisible(false)

	-- character customization subpanel
	self.description = self:AddSubpanel("description")
	self.description:SetTitle("chooseDescription")

	-- Left side wrapper for description (Model + Return)
	local descriptionLeft = self.description:Add("Panel")
	descriptionLeft:Dock(LEFT)
	descriptionLeft:SetSize(halfWidth * 0.6, halfHeight)

	-- Button footer panel for description (Outside bioscan)
	local descriptionFooter = descriptionLeft:Add("Panel")
	descriptionFooter:SetTall(Scale(64))
	descriptionFooter:Dock(BOTTOM)
	descriptionFooter:DockMargin(Scale(8), Scale(8), Scale(8), Scale(8))
	descriptionFooter.Paint = function() end

	local descriptionBack = descriptionFooter:Add("ixImpButton")
	descriptionBack:SetLabel("RETURN")
	descriptionBack:SetStyle("danger")
	descriptionBack:Dock(FILL)
	descriptionBack.DoClick = function()
		self.progress:DecrementProgress()

		if (#self.factionButtons == 1) then
			factionBack:DoClick()
		else
			self:SetActiveSubpanel("faction")
		end
	end

	-- Bioscan visual panel
	local descriptionModelList = descriptionLeft:Add("Panel")
	descriptionModelList:Dock(FILL)
	-- Pass this to static applier later via self.descriptionModel:GetParent()

	self.descriptionModel = descriptionModelList:Add("ixModelPanel")
	self.descriptionModel:Dock(FILL)
	self.descriptionModel:SetModel(self.factionModel:GetModel())
	self.descriptionModel:SetFOV(modelFOV - 35)
	self.descriptionModel.PaintModel = self.descriptionModel.Paint

	-- Right side wrapper for description (Inputs + Proceed)
	local descriptionRight = self.description:Add("Panel")
	descriptionRight:SetWide(halfWidth + padding * 2)
	descriptionRight:Dock(RIGHT)

	-- Button footer panel for description PROCEED (Outside Data Panel)
	local descriptionFooterPanel = descriptionRight:Add("Panel")
	descriptionFooterPanel:SetTall(Scale(64))
	descriptionFooterPanel:Dock(BOTTOM)
	descriptionFooterPanel:DockMargin(Scale(8), Scale(8), Scale(8), Scale(8))
	descriptionFooterPanel.Paint = function() end

	local descriptionProceed = descriptionFooterPanel:Add("ixImpButton")
	descriptionProceed:SetLabel("PROCEED")
	descriptionProceed:SetStyle("accent")
	descriptionProceed:Dock(FILL)
	descriptionProceed.DoClick = function()
		if (self:VerifyProgression("description")) then
			-- there are no panels on the attributes section other than the create button, so we can just create the character
			if (#self.attributesPanel:GetChildren() < 2) then
				self:SendPayload()
				return
			end

			self.progress:IncrementProgress()
			self:SetActiveSubpanel("attributes")
		end
	end

	-- Data Panel (Inputs)
	self.descriptionPanel = descriptionRight:Add("Panel")
	self.descriptionPanel:Dock(FILL) 
    -- We need to ApplyDataPanel to this specifically

	-- attributes subpanel
	self.attributes = self:AddSubpanel("attributes")
	self.attributes:SetTitle("chooseSkills")

	-- Left side wrapper for attributes
	local attributesLeft = self.attributes:Add("Panel")
	attributesLeft:Dock(LEFT)
	attributesLeft:SetSize(halfWidth * 0.6, halfHeight)

	-- Button footer panel for attributes
	local attributesFooter = attributesLeft:Add("Panel")
	attributesFooter:SetTall(Scale(64))
	attributesFooter:Dock(BOTTOM)
	attributesFooter:DockMargin(Scale(8), Scale(8), Scale(8), Scale(8))
	attributesFooter.Paint = function() end

	local attributesBack = attributesFooter:Add("ixImpButton")
	attributesBack:SetLabel("RETURN")
	attributesBack:SetStyle("danger")
	attributesBack:Dock(FILL)
	attributesBack.DoClick = function()
		self.progress:DecrementProgress()
		self:SetActiveSubpanel("description")
	end

	-- Bioscan visual panel
	local attributesModelList = attributesLeft:Add("Panel")
	attributesModelList:Dock(FILL)

	self.attributesModel = attributesModelList:Add("ixModelPanel")
	self.attributesModel:Dock(FILL)
	self.attributesModel:SetModel(self.factionModel:GetModel())
	self.attributesModel:SetFOV(modelFOV - 35)
	self.attributesModel.PaintModel = self.attributesModel.Paint

	-- Right side wrapper for attributes
	local attributesRight = self.attributes:Add("Panel")
	attributesRight:SetWide(halfWidth + padding * 2)
	attributesRight:Dock(RIGHT)

	-- Button footer panel for attributes FINISH
	local attributesFooterPanel = attributesRight:Add("Panel")
	attributesFooterPanel:SetTall(Scale(64))
	attributesFooterPanel:Dock(BOTTOM)
	attributesFooterPanel:DockMargin(Scale(8), Scale(8), Scale(8), Scale(8))
	attributesFooterPanel.Paint = function() end

	local create = attributesFooterPanel:Add("ixImpButton")
	create:SetLabel("FINISH")
	create:SetStyle("accent")
	create:Dock(FILL)
	create.DoClick = function()
		self:SendPayload()
	end

	-- Aptitude Matrix panel
	self.attributesPanel = attributesRight:Add("Panel")
	self.attributesPanel:Dock(FILL)


	-- creation progress panel
	self.progress = self:Add("ixSegmentedProgress")
	self.progress:SetBarColor(ix.config.Get("color"))
	self.progress:SetSize(parent:GetWide(), 0)
	self.progress:SizeToContents()
	self.progress:SetPos(0, parent:GetTall() - self.progress:GetTall())

	-- setup payload hooks
	self:AddPayloadHook("model", function(value)
		local faction = ix.faction.indices[self.payload.faction]

		if (faction) then
			local model = faction:GetModels(LocalPlayer())[value]

			-- assuming bodygroups
			if (istable(model)) then
				self.factionModel:SetModel(model[1], model[2] or 0, model[3])
				self.descriptionModel:SetModel(model[1], model[2] or 0, model[3])
				self.attributesModel:SetModel(model[1], model[2] or 0, model[3])
			else
				self.factionModel:SetModel(model)
				self.descriptionModel:SetModel(model)
				self.attributesModel:SetModel(model)
			end
		end
	end)

	-- setup character creation hooks
	net.Receive("ixCharacterAuthed", function()
		timer.Remove("ixCharacterCreateTimeout")
		self.awaitingResponse = false

		local id = net.ReadUInt(32)
		local indices = net.ReadUInt(6)
		local charList = {}

		for _ = 1, indices do
			charList[#charList + 1] = net.ReadUInt(32)
		end

		ix.characters = charList

		self:SlideDown()

		if (!IsValid(self) or !IsValid(parent)) then
			return
		end

		if (LocalPlayer():GetCharacter()) then
			parent.mainPanel:Undim()
			parent:ShowNotice(2, L("charCreated"))
		elseif (id) then
			self.bMenuShouldClose = true

			net.Start("ixCharacterChoose")
				net.WriteUInt(id, 32)
			net.SendToServer()
		else
			self:SlideDown()
		end
	end)

	net.Receive("ixCharacterAuthFailed", function()
		timer.Remove("ixCharacterCreateTimeout")
		self.awaitingResponse = false

		local fault = net.ReadString()
		local args = net.ReadTable()

		self:SlideDown()

		parent.mainPanel:Undim()
		parent:ShowNotice(3, L(fault, unpack(args)))
	end)

	ApplyCharMenuStatic(self)
end

function PANEL:SendPayload()
	if (self.awaitingResponse or !self:VerifyProgression()) then
		return
	end

	self.awaitingResponse = true

	timer.Create("ixCharacterCreateTimeout", 10, 1, function()
		if (IsValid(self) and self.awaitingResponse) then
			self.awaitingResponse = false
			self:GetParent():ShowNotice(3, L("unknownError"))
		end
	end)

	self.payload:Prepare()

	net.Start("ixCharacterCreate")
	net.WriteUInt(table.Count(self.payload), 8)

	for k, v in pairs(self.payload) do
		net.WriteString(k)
		net.WriteType(v)
	end

	net.SendToServer()
end

function PANEL:ResetPayload(bWithHooks)
	if (bWithHooks) then
		self.hooks = {}
	end

	self.payload = {}

	-- wee need to link the payload table to the panel for the hooks to work
	function self.payload.Set(payload, key, value)
		self:SetPayload(key, value)
	end

	function self.payload.AddHook(payload, key, callback)
		self:AddPayloadHook(key, callback)
	end

	function self.payload.Prepare(payload)
		self.payload.Set = nil
		self.payload.AddHook = nil
		self.payload.Prepare = nil
	end
end

function PANEL:SetPayload(key, value)
	self.payload[key] = value
	self:RunPayloadHook(key, value)
end

function PANEL:AddPayloadHook(key, callback)
	if (!self.hooks[key]) then
		self.hooks[key] = {}
	end

	self.hooks[key][#self.hooks[key] + 1] = callback
end

function PANEL:RunPayloadHook(key, value)
	local hooks = self.hooks[key] or {}

	for _, v in ipairs(hooks) do
		v(value)
	end
end

function PANEL:GetContainerPanel(name)
	-- TODO: yuck
	if (name == "description") then
		return self.descriptionPanel
	elseif (name == "attributes") then
		return self.attributesPanel
	end

	return self.descriptionPanel
end

function PANEL:AttachCleanup(panel)
	self.repopulatePanels[#self.repopulatePanels + 1] = panel
end

function PANEL:Populate()
	if (!self.bInitialPopulate) then
		-- setup buttons for the faction panel
		-- TODO: make this a bit less janky
		local lastSelected

		for _, v in pairs(self.factionButtons) do
			if (v.style == "accent") then
				lastSelected = v.faction
			end

			if (IsValid(v)) then
				v:Remove()
			end
		end

		self.factionButtons = {}

		local bSelected = false
		local firstButton

		for _, v in SortedPairs(ix.faction.teams) do
			if (ix.faction.HasWhitelist(v.index)) then
				local button = self.factionButtonsPanel:Add("ixImpButton")
				button:SetLabel(L(v.name):utf8upper())
				-- button:SizeToContents()
				-- button:SetButtonList(self.factionButtons)
				button:Dock(TOP)
				button:DockMargin(0, 0, 0, Scale(4))
				button:SetTall(Scale(40))
				button.faction = v.index
				button.DoClick = function(panel)
					-- Manual exclusive selection
					for _, b in ipairs(self.factionButtons) do
						b:SetStyle("default")
					end
					panel:SetStyle("accent")
					
					local faction = ix.faction.indices[panel.faction]
					local models = faction:GetModels(LocalPlayer())

					self.payload:Set("faction", panel.faction)
					self.payload:Set("model", math.random(1, #models))
					
					-- Update Info
					self.factionInfoLabel:SetText(faction.description or "")
					-- Force layout update for label
					self.factionInfoPanel:InvalidateLayout(true)
				end
				
				self.factionButtons[#self.factionButtons + 1] = button

				if ((lastSelected and lastSelected == v.index) or (!lastSelected and v.isDefault)) then
					button:DoClick(button) -- Use DoClick to trigger selection logic
					lastSelected = v.index
					bSelected = true
				end

				if (!firstButton) then
					firstButton = button
				end
			end
		end

		if (!bSelected and IsValid(firstButton)) then
			firstButton:DoClick(firstButton)
		end
	end

	-- remove panels created for character vars
	for i = 1, #self.repopulatePanels do
		self.repopulatePanels[i]:Remove()
	end

	self.repopulatePanels = {}

	local desiredFaction = self.payload.faction

	if (desiredFaction) then
		for _, v in pairs(self.factionButtons) do
			if (v.faction == desiredFaction) then
				v:DoClick(v)
				break
			end
		end
	elseif (#self.factionButtons > 0) then
		self.factionButtons[1]:DoClick(self.factionButtons[1])
	end


	-- self.factionButtonsPanel:SizeToContents()

	if (#self.factionButtons == 1) then
		self:SetActiveSubpanel("description", 0)
	end

	local zPos = 1

	-- set up character vars
	for k, v in SortedPairsByMemberValue(ix.char.vars, "index") do
		if (!v.bNoDisplay and k != "__SortedIndex") then
			local container = self:GetContainerPanel(v.category or "description")

			if (v.ShouldDisplay and v:ShouldDisplay(container, self.payload) == false) then
				continue
			end

			local panel
            local bCustomDisplay = false

			-- if the var has a custom way of displaying, we'll use that instead
			if (v.OnDisplay) then
				panel = v:OnDisplay(container, self.payload)
				bCustomDisplay = true
			elseif (isstring(v.default)) then
				panel = container:Add("ixTextEntry")
				panel:Dock(TOP)
				panel:SetFont("ixMenuButtonHugeFont")
				panel:SetUpdateOnType(true)
				panel:DockMargin(Scale(6), 0, Scale(6), Scale(14))

				panel.OnValueChange = function(this, text)
					self.payload:Set(k, text)
				end
			end
            
            if (IsValid(panel) and panel.IsA and panel:IsA("DTextEntry")) then
                panel:SetPaintBackground(false)
            end

			if (IsValid(panel)) then
				if (panel.IsA and panel:IsA("DTextEntry")) then
					panel:SetPaintBackground(false)
				end

				-- add label for entry
				local label = container:Add("DLabel")
				label:SetFont("ixMenuButtonLabelFont")
				label:SetText(L(k):utf8upper())
				label:SizeToContents()
				label:DockMargin(Scale(6), Scale(24), Scale(6), Scale(4))
				label:Dock(TOP)

                -- Apply styles to label
                ix.ui.ApplyCharVarLabelStyle(label)

                -- Apply styles to panel
                if (panel.IsA and panel:IsA("DTextEntry")) then
                    ix.ui.ApplyTextEntryStyle(panel)
                elseif (panel:GetClassName() == "DScrollPanel") then
                    ix.ui.ApplyModelPanelStyle(panel)
                end
                
                -- Also apply basic check for dynamic children if it's a complex panel
                if (bCustomDisplay) then
                    panel:DockMargin(Scale(6), 0, Scale(6), Scale(14))
                    ApplyCharMenuDynamic(panel)
                end

				-- we need to set the docking order so the label is above the panel
				label:SetZPos(zPos - 1)
				panel:SetZPos(zPos)

				self:AttachCleanup(label)
				self:AttachCleanup(panel)

                -- Force flat black background on the container panel of the variable if it has a paint function
                if (panel.Paint) then
                    panel.Paint = function(this, w, h)
                        surface.SetDrawColor(Color(0, 0, 0, 255))
                        surface.DrawRect(0, 0, w, h)
                        surface.SetDrawColor(THEME.frameSoft)
                        surface.DrawOutlinedRect(0, 0, w, h)
                        
                        -- If it's a text entry, we need to draw text!
                        if (this.DrawTextEntryText) then
                             local textColor = (this.GetTextColor and this:GetTextColor()) or THEME.text
                             local highlightColor = (this.GetHighlightColor and this:GetHighlightColor()) or Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 120)
                             local cursorColor = (this.GetCursorColor and this:GetCursorColor()) or THEME.accent
                             
                             this:DrawTextEntryText(textColor, highlightColor, cursorColor)
                        end
                    end
                end

				if (v.OnPostSetup) then
					v:OnPostSetup(panel, self.payload)
                    
                    -- Re-apply critical styles if OnPostSetup overrode them
                    if (panel.IsA and panel:IsA("DTextEntry")) then
                         ix.ui.ApplyTextEntryStyle(panel)
                    end
				end

				zPos = zPos + 2
			end
		end
	end

	if (!self.bInitialPopulate) then
		-- setup progress bar segments
		if (#self.factionButtons > 1) then
			self.progress:AddSegment("@faction")
		end

		self.progress:AddSegment("@description")

		if (#self.attributesPanel:GetChildren() > 1) then
			self.progress:AddSegment("@skills")
		end

		-- we don't need to show the progress bar if there's only one segment
		if (#self.progress:GetSegments() == 1) then
			self.progress:SetVisible(false)
		end
	end

	self.bInitialPopulate = true

	ApplyCharMenuDynamic(self)
end

function PANEL:OnSlideUp()
	self:Populate()
    -- Ensure first faction is selected if not already
	if (!self.payload.faction and #self.factionButtons > 0) then
		self.factionButtons[1]:SetSelected(true)
	end
end

function PANEL:GetOverviewDescription()
    -- Helper for header text if needed
    return "" 
end

function PANEL:VerifyProgression(name)
	for k, v in SortedPairsByMemberValue(ix.char.vars, "index") do

		if (name ~= nil and (v.category or "description") != name) then
			continue
		end

		local value = self.payload[k]

		if (!v.bNoDisplay or v.OnValidate) then
			if (v.OnValidate) then
				local result = {v:OnValidate(value, self.payload, LocalPlayer())}

				if (result[1] == false) then
					self:GetParent():ShowNotice(3, L(unpack(result, 2)))
					return false
				end
			end

			self.payload[k] = value
		end
	end

	return true
end

function PANEL:Paint(width, height)
	derma.SkinFunc("PaintCharacterCreateBackground", self, width, height)
	BaseClass.Paint(self, width, height)
end

vgui.Register("ixCharMenuNew", PANEL, "ixCharMenuPanel")

-- Hot-reload logic
if (IsValid(ix.gui.characterMenu)) then
    if (IsValid(ix.gui.characterMenu.newCharacterPanel)) then
        ix.gui.characterMenu.newCharacterPanel:Remove()
    end
    
    local newPanel = ix.gui.characterMenu:Add("ixCharMenuNew")
    ix.gui.characterMenu.newCharacterPanel = newPanel
    
    -- Force initial population and layout
    newPanel:SetSize(ix.gui.characterMenu:GetSize())
    newPanel:Populate()
    ApplyCharMenuStatic(newPanel)
    ApplyCharMenuDynamic(newPanel)
end

