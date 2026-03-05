--- USMS Log Panel
-- Filterable, scrollable activity log viewer. CO/XO/ISB only.

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
    warn = Color(200, 170, 60, 255)
}

local function Scale(value)
    return math.max(1, math.Round(value * (ScrH() / 900)))
end

local LOG_ACTION_LABELS = {
    unit_member_join = "Member Joined",
    unit_member_leave = "Member Left",
    unit_member_kicked = "Member Kicked",
    unit_role_changed = "Role Changed",
    unit_class_changed = "Class Changed",
    unit_resource_change = "Resources Changed",
    squad_created = "Squad Created",
    squad_disbanded = "Squad Disbanded",
    squad_member_join = "Squad Join",
    squad_member_leave = "Squad Leave",
    squad_member_kicked = "Squad Kick",
    gearup = "Gear Up"
}

local LOG_ACTION_COLORS = {
    unit_member_join = THEME.ready,
    unit_member_leave = THEME.danger,
    unit_member_kicked = THEME.danger,
    unit_role_changed = THEME.accent,
    unit_class_changed = THEME.accent,
    unit_resource_change = Color(80, 140, 200, 255),
    squad_created = THEME.accent,
    squad_disbanded = THEME.danger,
    squad_member_kicked = THEME.danger,
    gearup = THEME.warn
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- LOG PANEL
-- ═══════════════════════════════════════════════════════════════════════════════

local PANEL = {}

function PANEL:Init()
    self.filterAction = nil
    self.currentPage = 1
    self.pageSize = 50
    self.totalLogs = 0

    -- Filter bar
    self.filterBar = self:Add("EditablePanel")
    self.filterBar:Dock(TOP)
    self.filterBar:SetTall(Scale(32))
    self.filterBar:DockMargin(0, 0, 0, Scale(4))
    self.filterBar.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.buttonBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, h - 1, w, 1)
    end

    -- Action type filter dropdown
    self.filterLabel = self.filterBar:Add("DLabel")
    self.filterLabel:Dock(LEFT)
    self.filterLabel:DockMargin(Scale(8), 0, Scale(4), 0)
    self.filterLabel:SetWide(Scale(60))
    self.filterLabel:SetFont("ixImpMenuDiag")
    self.filterLabel:SetTextColor(THEME.textMuted)
    self.filterLabel:SetText("Filter:")

    self.filterCombo = self.filterBar:Add("DComboBox")
    self.filterCombo:Dock(LEFT)
    self.filterCombo:SetWide(Scale(180))
    self.filterCombo:DockMargin(0, Scale(4), Scale(8), Scale(4))
    self.filterCombo:SetFont("ixImpMenuDiag")
    self.filterCombo:SetTextColor(THEME.text)
    self.filterCombo:SetValue("All Actions")
    self.filterCombo:AddChoice("All Actions", nil, true)
    for action, label in SortedPairs(LOG_ACTION_LABELS) do
        self.filterCombo:AddChoice(label, action)
    end
    self.filterCombo.OnSelect = function(s, index, value, data)
        self.filterAction = data
        self.currentPage = 1
        self:RequestLogs()
    end
    self.filterCombo.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    -- Refresh button
    self.refreshBtn = self.filterBar:Add("DButton")
    self.refreshBtn:SetText("")
    self.refreshBtn:Dock(LEFT)
    self.refreshBtn:SetWide(Scale(80))
    self.refreshBtn:DockMargin(0, Scale(4), Scale(4), Scale(4))
    self.refreshBtn.DoClick = function()
        self:RequestLogs()
    end
    self.refreshBtn.Paint = function(s, w, h)
        local bg = s:IsHovered() and THEME.buttonBgHover or THEME.buttonBg
        surface.SetDrawColor(bg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("REFRESH", "ixImpMenuDiag", w * 0.5, h * 0.5, THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Page controls
    self.pageBar = self:Add("EditablePanel")
    self.pageBar:Dock(BOTTOM)
    self.pageBar:SetTall(Scale(28))
    self.pageBar:DockMargin(0, Scale(2), 0, 0)
    self.pageBar.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.buttonBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, 0, w, 1)
    end

    self.prevBtn = self.pageBar:Add("DButton")
    self.prevBtn:SetText("")
    self.prevBtn:Dock(LEFT)
    self.prevBtn:SetWide(Scale(60))
    self.prevBtn.DoClick = function()
        if (self.currentPage > 1) then
            self.currentPage = self.currentPage - 1
            self:RequestLogs()
        end
    end
    self.prevBtn.Paint = function(s, w, h)
        local canPrev = self.currentPage > 1
        local bg = (s:IsHovered() and canPrev) and THEME.buttonBgHover or THEME.buttonBg
        surface.SetDrawColor(bg)
        surface.DrawRect(0, 0, w, h)
        local col = canPrev and THEME.accent or THEME.textMuted
        draw.SimpleText("< PREV", "ixImpMenuDiag", w * 0.5, h * 0.5, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    self.pageLabel = self.pageBar:Add("DLabel")
    self.pageLabel:Dock(LEFT)
    self.pageLabel:SetWide(Scale(120))
    self.pageLabel:DockMargin(Scale(8), 0, Scale(8), 0)
    self.pageLabel:SetFont("ixImpMenuDiag")
    self.pageLabel:SetTextColor(THEME.textMuted)
    self.pageLabel:SetContentAlignment(5)
    self.pageLabel:SetText("Page 1")

    self.nextBtn = self.pageBar:Add("DButton")
    self.nextBtn:SetText("")
    self.nextBtn:Dock(LEFT)
    self.nextBtn:SetWide(Scale(60))
    self.nextBtn.DoClick = function()
        local maxPage = math.max(1, math.ceil(self.totalLogs / self.pageSize))
        if (self.currentPage < maxPage) then
            self.currentPage = self.currentPage + 1
            self:RequestLogs()
        end
    end
    self.nextBtn.Paint = function(s, w, h)
        local maxPage = math.max(1, math.ceil(self.totalLogs / self.pageSize))
        local canNext = self.currentPage < maxPage
        local bg = (s:IsHovered() and canNext) and THEME.buttonBgHover or THEME.buttonBg
        surface.SetDrawColor(bg)
        surface.DrawRect(0, 0, w, h)
        local col = canNext and THEME.accent or THEME.textMuted
        draw.SimpleText("NEXT >", "ixImpMenuDiag", w * 0.5, h * 0.5, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Log rows
    self.scroll = self:Add("DScrollPanel")
    self.scroll:Dock(FILL)
    self.scroll:DockMargin(0, 0, 0, 0)

    local sbar = self.scroll:GetVBar()
    sbar:SetWide(Scale(4))
    sbar.Paint = function() end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, 0, w, h)
    end

    -- Listen for log data
    hook.Add("USMSLogsUpdated", self, function(s)
        s:RebuildRows()
    end)

    -- Initial request
    self:RequestLogs()
end

function PANEL:OnRemove()
    hook.Remove("USMSLogsUpdated", self)
end

function PANEL:RequestLogs()
    local data = {
        page = self.currentPage,
        limit = self.pageSize
    }
    if (self.filterAction) then
        data.action = self.filterAction
    end
    ix.usms.Request("log_request", data)
end

function PANEL:RebuildRows()
    self.scroll:Clear()

    local logs = ix.usms.clientData.logs or {}
    self.totalLogs = ix.usms.clientData.logTotalCount or #logs

    local maxPage = math.max(1, math.ceil(self.totalLogs / self.pageSize))
    self.pageLabel:SetText("Page " .. self.currentPage .. " / " .. maxPage)

    if (#logs == 0) then
        local lbl = self.scroll:Add("DLabel")
        lbl:Dock(TOP)
        lbl:SetTall(Scale(40))
        lbl:DockMargin(Scale(8), Scale(8), 0, 0)
        lbl:SetFont("ixImpMenuDiag")
        lbl:SetTextColor(THEME.textMuted)
        lbl:SetText("No log entries found.")
        return
    end

    for i, entry in ipairs(logs) do
        local row = self.scroll:Add("EditablePanel")
        row:Dock(TOP)
        row:SetTall(Scale(44))
        row.rowIndex = i
        row.logEntry = entry

        row.OnCursorEntered = function(s) s.bHovered = true end
        row.OnCursorExited = function(s) s.bHovered = false end

        row.Paint = function(s, w, h)
            local bg
            if (s.bHovered) then
                bg = THEME.rowHover
            elseif (s.rowIndex % 2 == 0) then
                bg = THEME.rowEven
            else
                bg = THEME.rowOdd
            end
            surface.SetDrawColor(bg)
            surface.DrawRect(0, 0, w, h)

            local e = s.logEntry
            local action = e.action or "unknown"
            local actionLabel = LOG_ACTION_LABELS[action] or action
            local actionColor = LOG_ACTION_COLORS[action] or THEME.textMuted

            -- Timestamp
            local ts = e.timestamp or 0
            local timeStr = ts > 0 and os.date("%Y-%m-%d %H:%M", ts) or "?"

            -- Actor/target info
            local detail = ""
            if (e.data) then
                if (e.data.actorName) then
                    detail = detail .. e.data.actorName
                end
                if (e.data.targetName) then
                    detail = detail .. " → " .. e.data.targetName
                end
                if (e.data.className) then
                    detail = detail .. " [" .. e.data.className .. "]"
                end
                if (e.data.amount) then
                    detail = detail .. " (" .. e.data.amount .. ")"
                end
            end

            if (detail == "" and e.actorCharID) then
                detail = "Char#" .. e.actorCharID
                if (e.targetCharID) then
                    detail = detail .. " → Char#" .. e.targetCharID
                end
            end

            local pad = Scale(8)

            -- Line 1: [ACTION]  detail
            draw.SimpleText(actionLabel, "ixImpMenuStatus", pad, Scale(6), actionColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(detail, "ixImpMenuDiag", pad + Scale(140), Scale(7), THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            -- Line 2: timestamp
            draw.SimpleText(timeStr, "ixImpMenuDiag", pad, Scale(24), THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            -- Separator
            surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 20)
            surface.DrawRect(0, h - 1, w, 1)
        end
    end
end

function PANEL:Paint(w, h)
end

vgui.Register("ixUSMSLogPanel", PANEL, "EditablePanel")
