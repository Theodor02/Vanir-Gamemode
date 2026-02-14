local PLUGIN = PLUGIN

-- 1. Font Definitions
surface.CreateFont("ixRadioHeader", {
	font = "Roboto", -- Use a font that is likely to be on Windows/Source
	size = ScreenScale(10),
	weight = 1000,
	antialias = true,
})

-- We try to use a techy font. 
-- If 'Aurebesh' is not installed, the engine falls back to default usually (Arial/Tahoma).
-- We'll assume the client might have it or we accept the fallback.
surface.CreateFont("ixRadioAurebesh", {
	font = "Aurebesh", 
	size = ScreenScale(6),
	weight = 500,
	antialias = true,
	extended = true,
})

surface.CreateFont("ixRadioSender", {
	font = "Roboto",
	size = ScreenScale(7),
	weight = 500,
	antialias = true,
})

surface.CreateFont("ixRadioText", {
	font = "Roboto", -- Standard Helix font usually available
	size = ScreenScale(7),
	weight = 500,
	antialias = true,
})

local COLOR_BG = Color(25, 25, 30, 240)
local COLOR_ACCENT = Color(255, 190, 0)
local COLOR_TEXT = Color(220, 220, 220)
local COLOR_DIM = Color(100, 100, 100)

-- 2. Message Entry Panel
local PANEL = {}

function PANEL:Init()
	self:Dock(TOP)
	self:DockMargin(4, 2, 4, 2)
	self:SetTall(30) -- Will autosize
	self.curText = ""
	self.fullText = ""
	self.lastCharTime = 0
	self.typingSpeed = 0.02 -- seconds per char (~50 CPS)
	self.typingFinished = false
	self.createTime = RealTime()
	self.lifeTime = 15 -- Seconds before fading
	self.alpha = 255
end

function PANEL:SetMessage(speaker, name, text, info, uniqueID)
	self.senderName = name
	self.info = info or {}
	self.uniqueID = uniqueID
	
	-- Construct the full sentence based on type
	local verb = "radios"
	local color = Color(75, 150, 50) -- Default green
	
	if (uniqueID == "radio_yell") then
		verb = "yells on radio"
		color = Color(200, 200, 50)
	elseif (uniqueID == "radio_whisper") then
		verb = "whispers on radio"
		color = Color(75, 150, 150)
	end
	
	-- Cache for color/text usage
	self.accentColor = color
	self.fullText = string.format(": \"%s\"", text)
	
	-- We want the name to be colored, the rest normal? 
	-- Actually standard chat is usually ALL colored or Name colored. 
	-- User requested: "The text should still say 'name' radios in or etc" 
	-- and "Match Reference Image" (which separates elements visually).
	-- But later "text should still say...".
	-- Let's do: [Color Name] [Color Verb][White Message]
	-- But for typing animation, we need the "Message" part to be the `fullText`.
	-- The "Name radios" part can be static header.
	
	self.headerText = string.format("%s %s", name, verb)
	
	-- Calculate height
	-- We will calculate exact height during markup generation
	self:UpdateMarkup()
end

function PANEL:UpdateMarkup()
	local w = self:GetWide()
	local maxWidth = w - 16
	if (maxWidth <= 0) then maxWidth = 400 end -- Fallback if not yet layouted
	
	-- The markup should contain the Header (Name + Verb) AND the Message (Animated)
	-- To make "Name radios:" static and "Message" type out, we concatenate.
	-- But typing animation logic in Think() operates on `curText`.
	-- Let's make `curText` ONLY represent the message body.
	
	-- Color conversions to string
	local cName = self.accentColor or Color(255,255,255)
	
	-- Header Part: <color=r,g,b>Name radios</color>
	local headerStr = string.format("<color=%d,%d,%d>%s</color>", cName.r, cName.g, cName.b, self.headerText)
	
	-- Message Part: <color=220,220,220>: "PartialText</color>
	-- Note: fullText includes the leading `: "` sequence from SetMessage to match format
	local msgStr = string.format("<font=ixRadioText><color=220,220,220>%s</color></font>", self.curText)
	
	local finalStr = headerStr .. msgStr
	
	-- Use global markup.Parse to ensure we get the standard object with :Draw method
	self.markup = markup.Parse(finalStr, maxWidth)
	
	-- Update height to actual content
	if (self.markup) then
		local mh = self.markup:GetHeight()
		local newTall = mh + 8 -- Padding
		if (math.abs(self:GetTall() - newTall) > 2) then
			self:SetTall(newTall)
		end
	end
end

function PANEL:PerformLayout(w, h)
	-- If width changed significantly, re-wrap
	if (self.lastW ~= w) then
		self.lastW = w
		self:UpdateMarkup()
	end
end

function PANEL:Think()
	if (not self.typingFinished) then
		if (RealTime() > self.lastCharTime + self.typingSpeed) then
			local len = #self.curText
			if (len < #self.fullText) then
				self.curText = string.sub(self.fullText, 1, len + 1)
				self.lastCharTime = RealTime()
				self:UpdateMarkup()
			else
				self.typingFinished = true
			end
		end
	end
end

function PANEL:Paint(w, h)
	-- Alpha Management
	local parent = self:GetParent():GetParent():GetParent() -- ixRadioMessage -> Canvas -> ScrollPanel -> ixRadioChatbox
	-- Safe check
	if (not IsValid(parent) or not parent.GetActiveAlpha) then 
		self.alpha = 255 
	else
		-- If chatbox is active (typing), fully opaque
		local bgAlpha = parent:GetActiveAlpha()
		
		if (bgAlpha > 100) then
			self.alpha = 255
		else
			-- If inactive, check lifetime
			local delta = RealTime() - self.createTime
			if (delta > self.lifeTime) then
				local fade = 1 - math.Clamp((delta - self.lifeTime) / 2, 0, 1) -- Fade over 2s
				self.alpha = 255 * fade
			else
				self.alpha = 255
			end
		end
	end
	
	self:SetAlpha(self.alpha)
	
	if (self.alpha < 1) then return end

	-- Draw Message
	if (self.markup) then
		self.markup:Draw(8, 4, nil, nil, self.alpha)
	else
		-- Fallback
		if (self.curText ~= "") then
			self:UpdateMarkup() 
		end
	end
end

vgui.Register("ixRadioMessage", PANEL, "DPanel")

-- 3. Main Chatbox Panel
local PANEL = {}

function PANEL:Init()
	-- 1. Initialize variables FIRST to avoid crashes if Paint/Think run early
	self.headerHeight = 32
	self.bgAlpha = 0
	
	self.phrases = {
		"LINK ESTABLISHED",
		"SIGNAL STABLE",
		"ENCRYPTION ACTIVE",
		"SCANNING CHANNEL",
		"TRANSMISSION READY"
	}
	self.currentPhrase = "INITIALIZING"
	self.aurebeshText = ""
	self.animState = "type" -- type, pause, delete
	self.nextAnimTime = RealTime()
	self.charIndex = 0
	
	-- 2. Setup Dimensions
	self:SetSize(ScrW() * 0.25, ScrH() * 0.3)
	self:SetPos(10, ScrH() * 0.6)
	
	-- 3. Create Children
	-- Resize Grip (fallback if DSizeGrip is unavailable)
	local sizer = self:Add("DSizeGrip")
	if (not IsValid(sizer)) then
		sizer = self:Add("DPanel")
		sizer:SetCursor("sizenwse")
		function sizer:Paint(w, h)
			surface.SetDrawColor(255, 255, 255, 40)
			surface.DrawRect(w - 10, h - 2, 10, 2)
			surface.DrawRect(w - 2, h - 10, 2, 10)
		end
		function sizer:OnMousePressed()
			self:MouseCapture(true)
			self.dragging = true
			self.startX, self.startY = gui.MousePos()
			self.startW, self.startH = self:GetParent():GetSize()
		end
		function sizer:OnMouseReleased()
			self:MouseCapture(false)
			self.dragging = false
		end
		function sizer:OnCursorMoved()
			if (not self.dragging) then return end
			local mx, my = gui.MousePos()
			local newW = math.max(240, self.startW + (mx - self.startX))
			local newH = math.max(160, self.startH + (my - self.startY))
			self:GetParent():SetSize(newW, newH)
		end
	end
	self.sizer = sizer
	if (IsValid(self.sizer)) then
		self.sizer:SetSize(16, 16)
		self.sizer:SetZPos(10)
	end
	
	-- Scroll Panel
	self.scroll = self:Add("DScrollPanel")
	self.scroll:Dock(FILL)
	self.scroll:DockMargin(4, self.headerHeight + 4, 4, 4)
	
	-- Custom Scrollbar
	local bar = self.scroll:GetVBar()
	bar:SetWide(8)
	function bar:Paint(w, h)
		local box = self:GetParent():GetParent()
		if (not IsValid(box) or not box.GetActiveAlpha) then return end
		
		-- Only paint if parent alpha is high
		local a = box:GetActiveAlpha()
		if (a < 50) then return end
		draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 50))
	end
	function bar.btnUp:Paint(w, h) end
	function bar.btnDown:Paint(w, h) end
	function bar.btnGrip:Paint(w, h)
		local box = self:GetParent():GetParent():GetParent()
		if (not IsValid(box) or not box.GetActiveAlpha) then return end

		local a = box:GetActiveAlpha()
		if (a < 50) then return end
		draw.RoundedBox(0, 0, 0, w, h, Color(100, 100, 100, 100))
	end
	
	-- Make draggable (kind of)
	self:SetMouseInputEnabled(true)
end

function PANEL:PerformLayout(w, h)
	if (IsValid(self.sizer)) then
		self.sizer:SetPos(w - 16, h - 16)
	end
end

function PANEL:GetActiveAlpha()
	return self.bgAlpha or 255
end

function PANEL:Think()
	if (not IsValid(self.scroll)) then return end

	-- Resizing logic is handled by DSizeGrip automatically
	
	-- Background Fading Logic
	local isActive = false
	if (IsValid(ix.gui.chat) and ix.gui.chat:GetActive()) then
		isActive = true
	elseif (self:IsHovered() or self.scroll:IsHovered() or (IsValid(self.scroll:GetVBar()) and self.scroll:GetVBar():IsHovered()) or (IsValid(self.sizer) and self.sizer:IsHovered())) then
		isActive = true
	end
	
	local targetAlpha = isActive and 255 or 0
	self.bgAlpha = Lerp(FrameTime() * 10, self.bgAlpha or 0, targetAlpha)

	-- Header Animation
	if (RealTime() > (self.nextAnimTime or 0)) then
		if (self.animState == "type") then
			self.charIndex = (self.charIndex or 0) + 1
			self.aurebeshText = string.sub(self.currentPhrase, 1, self.charIndex)
			self.nextAnimTime = RealTime() + 0.05
			
			if (self.charIndex >= #self.currentPhrase) then
				self.animState = "pause"
				self.nextAnimTime = RealTime() + 2.0
			end
		
		elseif (self.animState == "pause") then
			self.animState = "delete"
			self.nextAnimTime = RealTime() + 0.05
			
		elseif (self.animState == "delete") then
			self.charIndex = (self.charIndex or 0) - 1
			self.aurebeshText = string.sub(self.currentPhrase, 1, self.charIndex)
			self.nextAnimTime = RealTime() + 0.03
			
			if (self.charIndex <= 0) then
				self.animState = "type"
				if (self.phrases) then
					self.currentPhrase = table.Random(self.phrases)
				end
				self.nextAnimTime = RealTime() + 0.5
			end
		end
	end
end

function PANEL:Paint(w, h)
	local a = self.bgAlpha or 255
	if (a < 1) then return end
	
	-- Main Background
	draw.RoundedBox(4, 0, 0, w, h, Color(COLOR_BG.r, COLOR_BG.g, COLOR_BG.b, a * (240/255)))
	
	-- Header Top Bar
	draw.RoundedBoxEx(4, 0, 0, w, self.headerHeight, Color(30, 30, 30, a), true, true, false, false)
	
	-- Header Accent Line (Gold)
	draw.RoundedBox(0, 0, self.headerHeight - 2, w, 2, Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, a))
	
	-- Header Title "COMMS"
	draw.SimpleText("COMMS", "ixRadioHeader", 8, self.headerHeight / 2, Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	
	-- Animated Aurebesh
	draw.SimpleText(self.aurebeshText or "", "ixRadioAurebesh", w - 8, self.headerHeight / 2, Color(255, 255, 255, math.min(100, a)), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	
	-- Outer Border Outline
	surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, a)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
end

-- Dragging Logic
function PANEL:OnMousePressed()
	if (ix.gui.chat:GetActive()) then
		self:MouseCapture(true)
		self.dragging = true
		self.dragX, self.dragY = self:CursorPos()
	end
end

function PANEL:OnMouseReleased()
	self:MouseCapture(false)
	self.dragging = false
end

function PANEL:OnCursorMoved(x, y)
	if (self.dragging) then
		local sx, sy = self:LocalToScreen(x - self.dragX, y - self.dragY)
		self:SetPos(sx, sy)
	end
end

function PANEL:AddRadioMessage(speaker, name, text, info, uniqueID)
	if (not IsValid(self.scroll)) then return end
	
	local msgPanel = self.scroll:Add("ixRadioMessage")
	msgPanel:SetMessage(speaker, name, text, info, uniqueID)
	msgPanel:SetWide(self.scroll:GetWide() - 16) -- Force width for calculation
	
	-- Force layout
	self.scroll:InvalidateLayout(true)
	
	-- Auto scroll logic
	local bar = self.scroll:GetVBar()
	timer.Simple(0.05, function()
		if (IsValid(bar)) then
			bar:AnimateTo(bar.CanvasSize, 0.5, 0, 0.5)
		end
	end)
end

function PANEL:AddLegacyMessage(...)
	-- Handle calls from chat.AddText if they leak through
	local args = {...}
	local str = ""
	for k, v in ipairs(args) do
		if (isstring(v)) then str = str .. v .. " " end
	end
	self:AddRadioMessage(nil, "SYSTEM", str, {}, "radio")
end

function PANEL:SetupPosition(posInfo)
	if (posInfo) then
		-- Apply saved position if needed or ignore if controlled by parent
	end
end

vgui.Register("ixRadioChatbox", PANEL, "DPanel")
