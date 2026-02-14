
local PLUGIN = PLUGIN

PLUGIN.name = "Radio Chatbox"
PLUGIN.author = "Refactored"
PLUGIN.description = "Standalone radio chatbox system."

ix.config.Add("enableRadioChatbox", true, "Whether or not to show radio messages in their own chatbox.", nil, {
	category = "Radio"
})
ix.config.Add("radioYellBig", true, "Whether yelling on radio makes text big.", nil, {
	category = "Radio"
})
ix.config.Add("radioWhisperSmall", true, "Whether whispering on radio makes text small.", nil, {
	category = "Radio"
})

ix.util.Include("sh_commands.lua")

-- Scramble Text Utility
function PLUGIN:ScrambleText(text, intensity, seed)
	if (not text) then return "" end
	if (not intensity or intensity <= 0) then return text end
	
	intensity = math.Clamp(intensity, 0, 1)
	
	local function myRandom()
		if (seed) then
			-- Linear congruential generator for determinism
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
		else
			if (myRandom() < intensity) then
				result = result .. "-"
			else
				result = result .. char
			end
		end
	end
	
	return result
end

if (SERVER) then
	util.AddNetworkString("ixRadioMessage")

	function PLUGIN:SendRadioMessage(sender, text, receivers, options)
		options = options or {}
		receivers = receivers or player.GetAll()
		
		local scrambledText = text
		if (options.scrambled) then
			local intensity = options.intensity or 0.5
			local seed = options.seed
			scrambledText = self:ScrambleText(text, intensity, seed)
		end
		
		-- Default chat class
		options.chatClass = options.chatClass or "radio"

		net.Start("ixRadioMessage")
			net.WriteEntity(sender)
			net.WriteString(scrambledText)
			net.WriteTable(options)
		net.Send(receivers)
	end
else
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

	function PLUGIN:ChatboxPositionChanged(x, y, width, height)
		if (IsValid(self.rpanel) and IsValid(ix.gui.chat)) then
			local w,h = ix.gui.chat:GetDefaultSize()
			local border = 16
			local magic = (643-459-border)
			local magicHeight = 155
			self.rpanel:SetSize(w, magicHeight)
			self.rpanel:SetPos(x, y - magic) 
		end
	end
	
	function PLUGIN:CreateRadiochat()
		if (IsValid(self.rpanel)) then
			self.rpanel:Remove()
		end
		
		self.rpanel = vgui.Create("ixRadioChatbox")
		self.rpanel:SetupPosition(util.JSONToTable(ix.option.Get("chatPosition", "")))
	end
	
	function PLUGIN:InitPostEntity()
		self:CreateRadiochat()
	end
	
	function PLUGIN:InitializedPlugins()
		self:CreateRadiochat()
	end
	
	-- chat.AddText override to redirect to radio chatbox
	chat.ixAddText = chat.ixAddText or chat.AddText

	function chat.AddText(...)
		local chat_class = CHAT_CLASS
		local radiocheck = false
		
		if (chat_class != nil) then
			if (ix.config.Get("enableRadioChatbox") == false) then
				radiocheck = false
			elseif (chat_class.uniqueID == "radio" or 
					chat_class.uniqueID == "radio_yell" or 
					chat_class.uniqueID == "radio_whisper") then
				radiocheck = true
			end
		end

		if (IsValid(ix.gui.chat) and !radiocheck) then
			ix.gui.chat:AddMessage(...)
		elseif (IsValid(PLUGIN.rpanel) and radiocheck) then
			-- Deprecated path for external calls, try to handle gracefully
			PLUGIN.rpanel:AddLegacyMessage(...)
		end

		-- Log to console
        local args = {...}
		local text = {}
		for _, v in ipairs(args) do
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

-- Chat Class Registration
do
	local CLASS = {}
	CLASS.color = Color(75, 150, 50)
	CLASS.format = "%s radios: \"%s\""
	CLASS.uniqueID = "radio"
    
	function CLASS:OnChatAdd(speaker, text, anonymous, info)
		local color = self.color
		local name = anonymous and "Someone" or (hook.Run("GetCharacterName", speaker, "ic") or (IsValid(speaker) and speaker:Name() or "Console"))
		
		if (IsValid(PLUGIN.rpanel) and ix.config.Get("enableRadioChatbox")) then
			PLUGIN.rpanel:AddRadioMessage(speaker, name, text, info, self.uniqueID)
			-- Console Log
			MsgC(color, string.format(self.format, name, text) .. "\n")
		else
			chat.AddText(color, string.format(self.format, name, text))
		end
	end

	ix.chat.Register("radio", CLASS)
end

do
	local CLASS = {}
	CLASS.color = Color(200, 200, 50)
	CLASS.format = "%s yells on radio: \"%s\""
	CLASS.uniqueID = "radio_yell"
    
	function CLASS:OnChatAdd(speaker, text, anonymous, info)
		local color = self.color
		local name = anonymous and "Someone" or (hook.Run("GetCharacterName", speaker, "ic") or (IsValid(speaker) and speaker:Name() or "Console"))
		
		if (IsValid(PLUGIN.rpanel) and ix.config.Get("enableRadioChatbox")) then
			PLUGIN.rpanel:AddRadioMessage(speaker, name, text, info, self.uniqueID)
			-- Console Log
			MsgC(color, string.format(self.format, name, text) .. "\n")
		else
			chat.AddText(color, string.format(self.format, name, text))
		end
	end

	ix.chat.Register("radio_yell", CLASS)
end

do
	local CLASS = {}
	CLASS.color = Color(75, 150, 150)
	CLASS.format = "%s whispers on radio: \"%s\""
	CLASS.uniqueID = "radio_whisper"
    
	function CLASS:OnChatAdd(speaker, text, anonymous, info)
		local color = self.color
		local name = anonymous and "Someone" or (hook.Run("GetCharacterName", speaker, "ic") or (IsValid(speaker) and speaker:Name() or "Console"))
		
		if (IsValid(PLUGIN.rpanel) and ix.config.Get("enableRadioChatbox")) then
			PLUGIN.rpanel:AddRadioMessage(speaker, name, text, info, self.uniqueID)
			-- Console Log
			MsgC(color, string.format(self.format, name, text) .. "\n")
		else
			chat.AddText(color, string.format(self.format, name, text))
		end
	end

	ix.chat.Register("radio_whisper", CLASS)
end
