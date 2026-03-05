--- USMS Invite Popup
-- A notification popup that appears when the player receives an invite.

local THEME = {
    background = Color(10, 10, 10, 245),
    frame = Color(191, 148, 53, 255),
    frameSoft = Color(191, 148, 53, 120),
    text = Color(235, 235, 235, 255),
    textMuted = Color(168, 168, 168, 140),
    accent = Color(191, 148, 53, 255),
    buttonBg = Color(16, 16, 16, 255),
    buttonBgHover = Color(26, 26, 26, 255),
    accept = Color(60, 170, 90, 255),
    acceptHover = Color(80, 200, 110, 255),
    decline = Color(180, 60, 60, 255),
    declineHover = Color(200, 80, 80, 255)
}

local function Scale(value)
    return math.max(1, math.Round(value * (ScrH() / 900)))
end

local PANEL = {}

function PANEL:Init()
    self.inviteType = "unit"
    self.message = ""
    self.inviterName = ""
    self.alpha = 0
    self.slideY = -Scale(120)
    self.startTime = SysTime()

    local w, h = Scale(380), Scale(130)
    self:SetSize(w, h)
    self:SetPos(ScrW() * 0.5 - w * 0.5, -h)
    self:MakePopup()
    self:SetKeyboardInputEnabled(false)

    -- Title
    self.title = self:Add("DLabel")
    self.title:SetFont("ixImpMenuSubtitle")
    self.title:SetTextColor(THEME.accent)
    self.title:Dock(TOP)
    self.title:SetTall(Scale(24))
    self.title:DockMargin(Scale(12), Scale(8), Scale(12), 0)
    self.title:SetText("INCOMING INVITE")

    -- Message label
    self.msgLabel = self:Add("DLabel")
    self.msgLabel:SetFont("ixImpMenuDiag")
    self.msgLabel:SetTextColor(THEME.text)
    self.msgLabel:Dock(TOP)
    self.msgLabel:SetTall(Scale(40))
    self.msgLabel:DockMargin(Scale(12), Scale(4), Scale(12), 0)
    self.msgLabel:SetWrap(true)
    self.msgLabel:SetAutoStretchVertical(false)
    self.msgLabel:SetText("")

    -- Button row
    self.btnRow = self:Add("EditablePanel")
    self.btnRow:Dock(BOTTOM)
    self.btnRow:SetTall(Scale(36))
    self.btnRow:DockMargin(Scale(12), Scale(4), Scale(12), Scale(10))

    -- Accept button
    self.acceptBtn = self.btnRow:Add("DButton")
    self.acceptBtn:SetText("")
    self.acceptBtn:Dock(LEFT)
    self.acceptBtn:SetWide(Scale(160))
    self.acceptBtn:DockMargin(0, 0, Scale(8), 0)
    self.acceptBtn.DoClick = function()
        ix.usms.RespondToInvite(true)
        self:SlideOut()
    end
    self.acceptBtn.Paint = function(s, w, h)
        local bg = s:IsHovered() and THEME.acceptHover or THEME.accept
        surface.SetDrawColor(bg)
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText("ACCEPT", "ixImpMenuButton", w * 0.5, h * 0.5, THEME.background, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Decline button
    self.declineBtn = self.btnRow:Add("DButton")
    self.declineBtn:SetText("")
    self.declineBtn:Dock(FILL)
    self.declineBtn.DoClick = function()
        ix.usms.RespondToInvite(false)
        self:SlideOut()
    end
    self.declineBtn.Paint = function(s, w, h)
        local bg = s:IsHovered() and THEME.declineHover or THEME.decline
        surface.SetDrawColor(bg)
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText("DECLINE", "ixImpMenuButton", w * 0.5, h * 0.5, THEME.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Auto-dismiss after 60 seconds
    timer.Create("ixUSMSInvitePopupDismiss", 60, 1, function()
        if (IsValid(self)) then
            self:SlideOut()
        end
    end)
end

function PANEL:OnRemove()
    timer.Remove("ixUSMSInvitePopupDismiss")
end

function PANEL:SetInviteData(inviteType, message, inviterName)
    self.inviteType = inviteType
    self.message = message
    self.inviterName = inviterName

    self.title:SetText(inviteType == "squad" and "SQUAD INVITE" or "UNIT INVITE")
    self.msgLabel:SetText(message)
end

function PANEL:SlideOut()
    self.slidingOut = true
    self.slideOutStart = SysTime()
end

function PANEL:Think()
    local elapsed = SysTime() - self.startTime

    if (self.slidingOut) then
        local outElapsed = SysTime() - self.slideOutStart
        local frac = math.Clamp(outElapsed / 0.3, 0, 1)
        local targetY = -self:GetTall() - Scale(10)
        local startY = Scale(16)
        local y = Lerp(frac, startY, targetY)
        self:SetPos(ScrW() * 0.5 - self:GetWide() * 0.5, y)
        self:SetAlpha(255 * (1 - frac))

        if (frac >= 1) then
            self:Remove()
        end
        return
    end

    -- Slide in animation
    local frac = math.Clamp(elapsed / 0.4, 0, 1)
    local eased = frac * (2 - frac) -- ease out quad
    local targetY = Scale(16)
    local startY = -self:GetTall() - Scale(10)
    local y = Lerp(eased, startY, targetY)

    self:SetPos(ScrW() * 0.5 - self:GetWide() * 0.5, y)
    self:SetAlpha(255 * eased)
end

function PANEL:Paint(w, h)
    -- Background
    surface.SetDrawColor(THEME.background)
    surface.DrawRect(0, 0, w, h)

    -- Border
    surface.SetDrawColor(THEME.frame)
    surface.DrawOutlinedRect(0, 0, w, h, Scale(2))

    -- Top accent line
    surface.SetDrawColor(THEME.accent)
    surface.DrawRect(0, 0, w, Scale(2))
end

vgui.Register("ixUSMSInvitePopup", PANEL, "EditablePanel")
