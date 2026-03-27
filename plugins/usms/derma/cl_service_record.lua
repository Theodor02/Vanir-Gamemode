--- USMS Service Record Panel
-- Popup panel showing a character's commendations, promotion history, and service info.
-- Opened via roster right-click → "View Service Record".

local THEME = {
    background = Color(10, 10, 10, 255),
    frame = Color(191, 148, 53, 255),
    frameSoft = Color(191, 148, 53, 120),
    text = Color(235, 235, 235, 255),
    textMuted = Color(168, 168, 168, 140),
    accent = Color(191, 148, 53, 255),
    accentSoft = Color(191, 148, 53, 220),
    buttonBg = Color(16, 16, 16, 255),
    buttonBgHover = Color(26, 26, 26, 255),
    panelBg = Color(12, 12, 12, 255),
    rowEven = Color(14, 14, 14, 255),
    rowOdd = Color(18, 18, 18, 255),
    rowHover = Color(24, 22, 14, 255),
    danger = Color(180, 60, 60, 255),
    ready = Color(60, 170, 90, 255),
    warn = Color(200, 170, 60, 255),
    supply = Color(80, 140, 200, 255)
}

local function Scale(value)
    return math.max(1, math.Round(value * (ScrH() / 900)))
end

local ROLE_NAMES = {
    [0] = "Member",
    [1] = "Executive Officer",
    [2] = "Commanding Officer"
}

local COMM_TYPE_ICONS = {
    medal = "icon16/medal_gold_1.png",
    commendation = "icon16/award_star_gold_1.png",
    reprimand = "icon16/exclamation.png"
}

local COMM_TYPE_COLORS = {
    medal = THEME.accent,
    commendation = THEME.ready,
    reprimand = THEME.danger
}

local COMM_TYPE_LABELS = {
    medal = "MEDAL",
    commendation = "COMMENDATION",
    reprimand = "REPRIMAND"
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- SERVICE RECORD PANEL (popup frame)
-- ═══════════════════════════════════════════════════════════════════════════════

local PANEL = {}

function PANEL:Init()
    self:SetSize(Scale(500), Scale(550))
    self:Center()
    self:SetTitle("")
    self:MakePopup()
    self:SetDraggable(true)

    self.record = nil

    -- Content scroll
    self.scroll = self:Add("DScrollPanel")
    self.scroll:Dock(FILL)
    self.scroll:DockMargin(Scale(4), Scale(30), Scale(4), Scale(4))

    local sbar = self.scroll:GetVBar()
    sbar:SetWide(Scale(4))
    sbar.Paint = function() end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, 0, w, h)
    end

    -- Listen for service record data
    hook.Add("USMSServiceRecordReceived", self, function(s, record)
        s.record = record
        s:RebuildContent()
    end)
end

function PANEL:OnRemove()
    hook.Remove("USMSServiceRecordReceived", self)
end

function PANEL:SetTargetCharID(charID)
    self.targetCharID = charID
    ix.usms.Request("service_record_request", {charID = charID})
end

function PANEL:RebuildContent()
    self.scroll:Clear()

    if (!self.record) then
        local lbl = self.scroll:Add("DLabel")
        lbl:Dock(TOP)
        lbl:SetTall(Scale(40))
        lbl:DockMargin(Scale(8), Scale(8), 0, 0)
        lbl:SetFont("ixImpMenuDiag")
        lbl:SetTextColor(THEME.textMuted)
        lbl:SetText("Loading service record...")
        return
    end

    local r = self.record

    -- Character info section
    self:AddSectionHeader("PERSONNEL FILE")

    local infoFields = {
        {"Name", r.name or "Unknown"},
        {"Rank", ROLE_NAMES[r.role] or "Member"},
        {"Class", r.className or "Unassigned"},
        {"Joined", r.joinedAt and os.date("%Y-%m-%d", r.joinedAt) or "Unknown"}
    }

    for _, field in ipairs(infoFields) do
        local row = self.scroll:Add("EditablePanel")
        row:Dock(TOP)
        row:SetTall(Scale(22))
        row:DockMargin(Scale(12), 0, Scale(8), 0)
        row.fieldName = field[1]
        row.fieldValue = field[2]
        row.Paint = function(s, w, h)
            draw.SimpleText(s.fieldName, "ixImpMenuStatus", 0, h * 0.5, THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(s.fieldValue, "ixImpMenuDiag", Scale(100), h * 0.5, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    -- Commendations section
    self:AddSectionHeader("COMMENDATIONS & AWARDS")

    local commendations = r.commendations or {}

    if (#commendations == 0) then
        local lbl = self.scroll:Add("DLabel")
        lbl:Dock(TOP)
        lbl:SetTall(Scale(24))
        lbl:DockMargin(Scale(12), Scale(2), 0, 0)
        lbl:SetFont("ixImpMenuDiag")
        lbl:SetTextColor(THEME.textMuted)
        lbl:SetText("No commendations on record.")
    else
        for i, comm in ipairs(commendations) do
            local commRow = self.scroll:Add("EditablePanel")
            commRow:Dock(TOP)
            commRow:SetTall(Scale(52))
            commRow:DockMargin(Scale(8), Scale(2), Scale(8), Scale(2))
            commRow.comm = comm
            commRow.rowIndex = i

            commRow.OnCursorEntered = function(s) s.bHovered = true end
            commRow.OnCursorExited = function(s) s.bHovered = false end

            -- Right-click to revoke (officers only)
            commRow.OnMousePressed = function(s, code)
                if (code != MOUSE_RIGHT) then return end
                local char = LocalPlayer():GetCharacter()
                if (!char) then return end
                local isOfficer = char:IsUnitOfficer()
                local isSuperAdmin = LocalPlayer():IsSuperAdmin()
                if (!isOfficer and !isSuperAdmin) then return end

                local menu = DermaMenu()
                menu:AddOption("Revoke", function()
                    Derma_Query("Revoke \"" .. comm.title .. "\"?", "Confirm",
                        "Yes", function()
                            ix.usms.Request("commendation_revoke", {commendationID = comm.id})
                            -- Re-request service record after a moment
                            timer.Simple(0.5, function()
                                if (IsValid(self)) then
                                    self:SetTargetCharID(self.targetCharID)
                                end
                            end)
                        end,
                        "No", function() end)
                end):SetIcon("icon16/cross.png")
                menu:Open()
            end

            commRow.Paint = function(s, w, h)
                local c = s.comm
                local bg = s.bHovered and THEME.rowHover or ((s.rowIndex % 2 == 0) and THEME.rowEven or THEME.rowOdd)
                surface.SetDrawColor(bg)
                surface.DrawRect(0, 0, w, h)

                local typeColor = COMM_TYPE_COLORS[c.type] or THEME.textMuted
                local typeLabel = COMM_TYPE_LABELS[c.type] or "COMMENDATION"

                -- Type indicator bar
                surface.SetDrawColor(typeColor)
                surface.DrawRect(0, 0, Scale(3), h)

                local pad = Scale(10)

                -- Title + type
                draw.SimpleText(c.title or "Untitled", "ixImpMenuButton", pad, Scale(4), THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(typeLabel, "ixImpMenuStatus", w - pad, Scale(6), typeColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

                -- Reason + date
                local reason = c.reason or ""
                if (#reason > 60) then reason = string.sub(reason, 1, 57) .. "..." end
                draw.SimpleText(reason, "ixImpMenuDiag", pad, Scale(22), THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                local dateStr = c.timestamp and os.date("%Y-%m-%d", c.timestamp) or "?"
                local awardedBy = c.awardedByName or "Unknown"
                draw.SimpleText("By " .. awardedBy .. "  |  " .. dateStr, "ixImpMenuDiag", pad, Scale(36), THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
        end
    end

    -- Award button for officers
    local char = LocalPlayer():GetCharacter()
    local isOfficer = char and char:IsUnitOfficer()
    local isSuperAdmin = LocalPlayer():IsSuperAdmin()

    if (isOfficer or isSuperAdmin) then
        local awardRow = self.scroll:Add("EditablePanel")
        awardRow:Dock(TOP)
        awardRow:SetTall(Scale(36))
        awardRow:DockMargin(Scale(8), Scale(8), Scale(8), 0)
        awardRow.Paint = function() end

        local awardBtn = awardRow:Add("DButton")
        awardBtn:SetText("")
        awardBtn:Dock(LEFT)
        awardBtn:SetWide(Scale(180))
        awardBtn.DoClick = function()
            self:OpenAwardDialog()
        end
        awardBtn.Paint = function(s, w, h)
            local bg = s:IsHovered() and THEME.buttonBgHover or THEME.buttonBg
            surface.SetDrawColor(bg)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(THEME.accent)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText("+ AWARD COMMENDATION", "ixImpMenuStatus", w * 0.5, h * 0.5, THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- Promotion History section
    self:AddSectionHeader("PROMOTION HISTORY")

    local promotions = r.promotions or {}

    if (#promotions == 0) then
        local lbl = self.scroll:Add("DLabel")
        lbl:Dock(TOP)
        lbl:SetTall(Scale(24))
        lbl:DockMargin(Scale(12), Scale(2), 0, 0)
        lbl:SetFont("ixImpMenuDiag")
        lbl:SetTextColor(THEME.textMuted)
        lbl:SetText("No promotion history.")
    else
        for i, promo in ipairs(promotions) do
            local promoRow = self.scroll:Add("EditablePanel")
            promoRow:Dock(TOP)
            promoRow:SetTall(Scale(26))
            promoRow:DockMargin(Scale(8), Scale(2), Scale(8), 0)
            promoRow.promo = promo
            promoRow.rowIndex = i

            promoRow.Paint = function(s, w, h)
                local p = s.promo
                local bg = (s.rowIndex % 2 == 0) and THEME.rowEven or THEME.rowOdd
                surface.SetDrawColor(bg)
                surface.DrawRect(0, 0, w, h)

                local oldName = ROLE_NAMES[p.oldRole] or "?"
                local newName = ROLE_NAMES[p.newRole] or "?"
                local dateStr = p.timestamp and os.date("%Y-%m-%d %H:%M", p.timestamp) or "?"

                local pad = Scale(8)
                draw.SimpleText(oldName .. " → " .. newName, "ixImpMenuDiag", pad, h * 0.5, THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(dateStr, "ixImpMenuDiag", w - pad, h * 0.5, THEME.textMuted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end
    end
end

function PANEL:AddSectionHeader(text)
    local sep = self.scroll:Add("EditablePanel")
    sep:Dock(TOP)
    sep:SetTall(Scale(28))
    sep:DockMargin(Scale(8), Scale(10), Scale(8), Scale(2))
    sep.headerText = text
    sep.Paint = function(s, w, h)
        draw.SimpleText(s.headerText, "ixImpMenuSubtitle", 0, h * 0.5, THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, h - 1, w, 1)
    end
end

function PANEL:OpenAwardDialog()
    if (!self.targetCharID) then return end
    local targetName = self.record and self.record.name or "Unknown"

    local frame = vgui.Create("DFrame")
    frame:SetSize(Scale(380), Scale(300))
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:SetDraggable(true)
    frame.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.background)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frame)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("AWARD TO: " .. targetName, "ixImpMenuSubtitle", Scale(12), Scale(8), THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local y = Scale(36)
    local pad = Scale(8)

    -- Type
    local typeLabel = frame:Add("DLabel")
    typeLabel:SetPos(pad, y)
    typeLabel:SetSize(Scale(360), Scale(18))
    typeLabel:SetFont("ixImpMenuStatus")
    typeLabel:SetTextColor(THEME.textMuted)
    typeLabel:SetText("Type")
    y = y + Scale(18)

    local typeCombo = frame:Add("DComboBox")
    typeCombo:SetPos(pad, y)
    typeCombo:SetSize(Scale(200), Scale(28))
    typeCombo:SetFont("ixImpMenuDiag")
    typeCombo:SetTextColor(THEME.text)
    typeCombo:AddChoice("Medal", "medal")
    typeCombo:AddChoice("Commendation", "commendation", true)
    typeCombo:AddChoice("Reprimand", "reprimand")
    typeCombo:SetValue("Commendation")
    typeCombo.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    y = y + Scale(36)

    -- Title
    local titleLabel = frame:Add("DLabel")
    titleLabel:SetPos(pad, y)
    titleLabel:SetSize(Scale(360), Scale(18))
    titleLabel:SetFont("ixImpMenuStatus")
    titleLabel:SetTextColor(THEME.textMuted)
    titleLabel:SetText("Title")
    y = y + Scale(18)

    local titleEntry = frame:Add("DTextEntry")
    titleEntry:SetPos(pad, y)
    titleEntry:SetSize(Scale(360), Scale(28))
    titleEntry:SetFont("ixImpMenuDiag")
    titleEntry:SetTextColor(THEME.text)
    titleEntry:SetPlaceholderText("Award title...")
    titleEntry.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        s:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
    end
    y = y + Scale(36)

    -- Reason
    local reasonLabel = frame:Add("DLabel")
    reasonLabel:SetPos(pad, y)
    reasonLabel:SetSize(Scale(360), Scale(18))
    reasonLabel:SetFont("ixImpMenuStatus")
    reasonLabel:SetTextColor(THEME.textMuted)
    reasonLabel:SetText("Reason (optional)")
    y = y + Scale(18)

    local reasonEntry = frame:Add("DTextEntry")
    reasonEntry:SetPos(pad, y)
    reasonEntry:SetSize(Scale(360), Scale(50))
    reasonEntry:SetFont("ixImpMenuDiag")
    reasonEntry:SetTextColor(THEME.text)
    reasonEntry:SetMultiline(true)
    reasonEntry:SetPlaceholderText("Reason for award...")
    reasonEntry.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        s:DrawTextEntryText(THEME.text, THEME.accent, THEME.text)
    end
    y = y + Scale(58)

    -- Submit
    local submitBtn = frame:Add("DButton")
    submitBtn:SetPos(pad, y)
    submitBtn:SetSize(Scale(360), Scale(32))
    submitBtn:SetText("")
    submitBtn.DoClick = function()
        local title = titleEntry:GetValue()
        if (!title or title == "") then return end

        local _, typeData = typeCombo:GetSelected()

        ix.usms.Request("commendation_award", {
            charID = self.targetCharID,
            commType = typeData or "commendation",
            title = title,
            reason = reasonEntry:GetValue() or ""
        })

        frame:Close()

        -- Re-request service record after a moment
        timer.Simple(0.5, function()
            if (IsValid(self)) then
                self:SetTargetCharID(self.targetCharID)
            end
        end)
    end
    submitBtn.Paint = function(s, w, h)
        local bg = s:IsHovered() and THEME.buttonBgHover or THEME.buttonBg
        surface.SetDrawColor(bg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.accent)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("AWARD", "ixImpMenuButton", w * 0.5, h * 0.5, THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

function PANEL:Paint(w, h)
    surface.SetDrawColor(THEME.background)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(THEME.frame)
    surface.DrawOutlinedRect(0, 0, w, h, 1)

    local title = "SERVICE RECORD"
    if (self.record and self.record.name) then
        title = title .. " — " .. self.record.name
    end
    draw.SimpleText(title, "ixImpMenuSubtitle", Scale(12), Scale(8), THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

vgui.Register("ixUSMSServiceRecord", PANEL, "DFrame")
