local PLUGIN = PLUGIN

PLUGIN.name = "Radio Chatbox Reskin"
PLUGIN.author = "Theodor"
PLUGIN.description = "complete Helix chatbox replacement with radio support for cool chat types and effects."


ix.config.Add("radioYellBig", true, "Whether yelling on radio makes text big.", nil, {
	category = "Radio"
})
ix.config.Add("radioWhisperSmall", true, "Whether whispering on radio makes text small.", nil, {
	category = "Radio"
})

ix.util.Include("sh_commands.lua")
ix.util.Include("derma/cl_chatbox.lua")
ix.util.Include("derma/cl_chatbox_customize.lua")


function PLUGIN:ScrambleText(text, intensity, seed)
	if (not text) then return "" end
	if (not intensity or intensity <= 0) then return text end

	intensity = math.Clamp(intensity, 0, 1)

	local function myRandom()
		if (seed) then
			seed = (1664525 * seed + 1013904223) % 4294967296
			return seed / 4294967296
		else
			return math.random()
		end
	end

	local result = ""

	for i = 1, #text do
		local char = string.sub(text, i, i)

		if (char == " " or char == "\n") then
			result = result .. char
		elseif (myRandom() < intensity) then
			result = result .. "-"
		else
			result = result .. char
		end
	end

	return result
end


if (SERVER) then
	util.AddNetworkString("ixRadioMessage")
	util.AddNetworkString("ixChatMessage")

	function PLUGIN:SendRadioMessage(sender, text, receivers, options)
		options = options or {}
		receivers = receivers or player.GetAll()

		if (options.scrambled) then
			text = self:ScrambleText(text, options.intensity or 0.5, options.seed)
		end

		options.chatClass = options.chatClass or "radio"

		net.Start("ixRadioMessage")
			net.WriteEntity(sender)
			net.WriteString(text)
			net.WriteTable(options)
		net.Send(receivers)
	end

	-- Standard Helix chat message handler (client → server → PlayerSay)
	net.Receive("ixChatMessage", function(length, client)
		local text = net.ReadString()

		if ((client.ixNextChat or 0) < CurTime() and isstring(text) and text:find("%S")) then
			local maxLength = ix.config.Get("chatMax")

			if (text:utf8len() > maxLength) then
				text = text:utf8sub(0, maxLength)
			end

			hook.Run("PlayerSay", client, text)
			client.ixNextChat = CurTime() + 0.5
		end
	end)


-- Client

else

	-- Chat state
	ix.chat.history = ix.chat.history or {}
	ix.chat.currentCommand = ""
	ix.chat.currentArguments = {}

	ix.option.Add("chatNotices", ix.type.bool, false, {
		category = "chat"
	})

	ix.option.Add("chatTimestamps", ix.type.bool, false, {
		category = "chat"
	})

	ix.option.Add("chatFontScale", ix.type.number, 1, {
		category = "chat", min = 0.1, max = 2, decimals = 2,
		OnChanged = function()
			hook.Run("LoadFonts", ix.config.Get("font"), ix.config.Get("genericFont"))
			PLUGIN:CreateChat()
		end
	})

	ix.option.Add("chatOutline", ix.type.bool, false, {
		category = "chat"
	})

	ix.option.Add("chatTabs", ix.type.string, "", {
		category = "chat",
		hidden = function() return true end
	})

	ix.option.Add("chatPosition", ix.type.string, "", {
		category = "chat",
		hidden = function() return true end
	})

	function PLUGIN:CreateChat()
		if (IsValid(self.panel)) then
			self.panel:Remove()
		end

		self.panel = vgui.Create("ixChatbox")
		self.panel:SetupTabs(util.JSONToTable(ix.option.Get("chatTabs", "")))
		self.panel:SetupPosition(util.JSONToTable(ix.option.Get("chatPosition", "")))

		hook.Run("ChatboxCreated")
	end

	function PLUGIN:TabExists(id)
		if (not IsValid(self.panel)) then
			return false
		end

		return self.panel.tabs:GetTabs()[id] ~= nil
	end

	function PLUGIN:SaveTabs()
		if (not IsValid(self.panel)) then return end

		local tabs = {}

		for id, panel in pairs(self.panel.tabs:GetTabs()) do
			tabs[id] = panel:GetFilter()
		end

		ix.option.Set("chatTabs", util.TableToJSON(tabs))
	end

	function PLUGIN:SavePosition()
		if (not IsValid(self.panel)) then return end

		local x, y = self.panel:GetPos()
		local width, height = self.panel:GetSize()

		ix.option.Set("chatPosition", util.TableToJSON({x, y, width, height}))
	end



	--- Neutralise the default Helix chatbox plugin to prevent duplicate panels/hooks.
	function PLUGIN:InitializedPlugins()
		for uniqueID, pluginData in pairs(ix.plugin.list) do
			if (uniqueID == "chatbox" and pluginData ~= PLUGIN) then
				-- Set all hook methods to no-ops
				pluginData.CreateChat = function() end
				pluginData.InitPostEntity = function() end
				pluginData.PlayerBindPress = function() return false end
				pluginData.OnPauseMenuShow = function() end
				pluginData.HUDShouldDraw = function() end
				pluginData.ChatText = function() end
				pluginData.ScreenResolutionChanged = function() end
				pluginData.SaveTabs = function() end
				pluginData.SavePosition = function() end
				pluginData.TabExists = function() return false end

				-- Demolish the panel reference so no code tries to call methods on it
				-- We replace it with a proxy so that if the original hooks still run (due to caching),
				-- they forward to our new panel instead of crashing or blocking the chat.
				if (IsValid(pluginData.panel)) then
					pluginData.panel:Remove()
				end

				local proxy = {}
				-- Use a closure to always get the current panel instance
				local function GetRealPanel() return PLUGIN.panel end

				function proxy:SetActive(...)
					if (IsValid(GetRealPanel())) then GetRealPanel():SetActive(...) end
				end
				function proxy:GetPos()
					if (IsValid(GetRealPanel())) then return GetRealPanel():GetPos() end
					return 0, 0
				end
				function proxy:GetSize()
					if (IsValid(GetRealPanel())) then return GetRealPanel():GetSize() end
					return 0, 0
				end
				function proxy:Remove() end
				function proxy:AddMessage(...)
					if (IsValid(GetRealPanel())) then GetRealPanel():AddMessage(...) end
				end
				
				proxy.tabs = {}
				function proxy.tabs:GetTabs()
					if (IsValid(GetRealPanel()) and GetRealPanel().tabs) then 
						return GetRealPanel().tabs:GetTabs() 
					end
					return {}
				end

				pluginData.panel = proxy

				break
			end
		end
	end

	function PLUGIN:InitPostEntity()
		timer.Simple(0, function()
			hook.Remove("PlayerBindPress", "chatbox")
			hook.Remove("OnPauseMenuShow", "chatbox")
			hook.Remove("HUDShouldDraw", "chatbox")
			hook.Remove("ChatText", "chatbox")
			hook.Remove("ScreenResolutionChanged", "chatbox")
		end)

		self:CreateChat()
	end

	function PLUGIN:PlayerBindPress(client, bind, pressed)
		bind = bind:lower()

		if (bind:find("messagemode") and pressed) then
			if (IsValid(self.panel)) then
				self.panel:SetActive(true)
			end

			return true
		end
	end

	function PLUGIN:OnPauseMenuShow()
		if (not IsValid(ix.gui.chat) or not ix.gui.chat:GetActive()) then
			return
		end

		ix.gui.chat:SetActive(false)
		return false
	end

	function PLUGIN:HUDShouldDraw(element)
		if (element == "CHudChat") then
			return false
		end
	end

	function PLUGIN:ChatText(index, name, text, messageType)
		if (messageType == "none" and IsValid(self.panel)) then
			self.panel:AddMessage(text)
		end
	end

	function PLUGIN:ScreenResolutionChanged(oldWidth, oldHeight)
		self:CreateChat()
	end


	-- Radio message handler (custom radio net messages)

	net.Receive("ixRadioMessage", function()
		local sender = net.ReadEntity()
		local text = net.ReadString()
		local options = net.ReadTable()

		local chatClass = options.chatClass or "radio"
		local classObj = ix.chat.classes[chatClass]

		if (classObj) then
			local oldClass = CHAT_CLASS
			CHAT_CLASS = classObj
			classObj:OnChatAdd(sender, text, false, options)
			CHAT_CLASS = oldClass
		else
			chat.AddText(Color(200, 200, 200), (IsValid(sender) and sender:Name() or "Unknown") .. ": " .. text)
		end
	end)


	-- chat.AddText override — routes ALL messages through the unified chatbox

	chat.ixAddText = chat.ixAddText or chat.AddText

	function chat.AddText(...)
		if (IsValid(PLUGIN.panel)) then
			PLUGIN.panel:AddMessage(...)
		end

		-- Log to console
		local text = {}

		for _, v in ipairs({...}) do
			if (istable(v) or isstring(v)) then
				text[#text + 1] = v
			elseif (isentity(v) and v:IsPlayer()) then
				text[#text + 1] = team.GetColor(v:Team())
				text[#text + 1] = v:Name()
			elseif (type(v) ~= "IMaterial") then
				text[#text + 1] = tostring(v)
			end
		end

		text[#text + 1] = "\n"
		MsgC(unpack(text))
	end
end

-- Chat Class Registration — Radio
-- All radio messages route through chat.AddText
-- The "COMMS" tab uses a whitelist to show only radio classes.

do
	local CLASS = {}
	CLASS.color = Color(75, 150, 50)
	CLASS.format = "%s radios: \"%s\""
	CLASS.uniqueID = "radio"

	function CLASS:OnChatAdd(speaker, text, anonymous, info)
		local name = anonymous and "Someone"
			or (hook.Run("GetCharacterName", speaker, "ic")
			or (IsValid(speaker) and speaker:Name() or "Console"))

		chat.AddText(self.color, string.format(self.format, name, text))
	end

	ix.chat.Register("radio", CLASS)
end

do
	local CLASS = {}
	CLASS.color = Color(200, 200, 50)
	CLASS.format = "%s yells on radio: \"%s\""
	CLASS.uniqueID = "radio_yell"

	function CLASS:OnChatAdd(speaker, text, anonymous, info)
		local name = anonymous and "Someone"
			or (hook.Run("GetCharacterName", speaker, "ic")
			or (IsValid(speaker) and speaker:Name() or "Console"))

		chat.AddText(self.color, string.format(self.format, name, text))
	end

	ix.chat.Register("radio_yell", CLASS)
end

do
	local CLASS = {}
	CLASS.color = Color(75, 150, 150)
	CLASS.format = "%s whispers on radio: \"%s\""
	CLASS.uniqueID = "radio_whisper"

	function CLASS:OnChatAdd(speaker, text, anonymous, info)
		local name = anonymous and "Someone"
			or (hook.Run("GetCharacterName", speaker, "ic")
			or (IsValid(speaker) and speaker:Name() or "Console"))

		chat.AddText(self.color, string.format(self.format, name, text))
	end

	ix.chat.Register("radio_whisper", CLASS)
end
