--- USMS Log Panel
-- Enhanced filterable, scrollable activity log viewer with search, time range,
-- character filter, expandable detail rows, and copy-to-clipboard.

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
    gearup = "Gear Up",
    mission_created = "Mission Created",
    mission_completed = "Mission Completed",
    mission_cancelled = "Mission Cancelled",
    commendation_awarded = "Commendation Awarded",
    commendation_revoked = "Commendation Revoked",
    class_whitelist = "Class Whitelist"
}

local LOG_ACTION_COLORS = {
    unit_member_join = ix.ui.THEME.ready,
    unit_member_leave = ix.ui.THEME.danger,
    unit_member_kicked = ix.ui.THEME.danger,
    unit_role_changed = ix.ui.THEME.accent,
    unit_class_changed = ix.ui.THEME.accent,
    unit_resource_change = Color(80, 140, 200, 255),
    squad_created = ix.ui.THEME.accent,
    squad_disbanded = ix.ui.THEME.danger,
    squad_member_kicked = ix.ui.THEME.danger,
    gearup = ix.ui.THEME.warning,
    mission_created = Color(80, 140, 200, 255),
    mission_completed = ix.ui.THEME.ready,
    mission_cancelled = ix.ui.THEME.danger,
    commendation_awarded = ix.ui.THEME.accent,
    commendation_revoked = ix.ui.THEME.danger,
    class_whitelist = Color(160, 200, 255, 255)
}

local TIME_RANGES = {
    {label = "All Time", seconds = 0},
    {label = "Last 24 Hours", seconds = 86400},
    {label = "Last 7 Days", seconds = 604800},
    {label = "Last 30 Days", seconds = 2592000}
}

--- Build a detail string from a log entry's data table.
local function BuildDetailString(entry)
    local detail = ""
    if (entry.data) then
        if (entry.data.actorName) then
            detail = detail .. entry.data.actorName
        end
        if (entry.data.targetName) then
            detail = detail .. " → " .. entry.data.targetName
        end
        if (entry.data.className) then
            detail = detail .. " [" .. entry.data.className .. "]"
        end
        if (entry.data.amount) then
            detail = detail .. " (" .. entry.data.amount .. ")"
        end
        if (entry.data.title) then
            detail = detail .. " \"" .. entry.data.title .. "\""
        end
    end

    if (detail == "" and entry.actorCharID) then
        detail = "Char#" .. entry.actorCharID
        if (entry.targetCharID) then
            detail = detail .. " → Char#" .. entry.targetCharID
        end
    end

    return detail
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- LOG PANEL
-- ═══════════════════════════════════════════════════════════════════════════════

local PANEL = {}

function PANEL:Init()
    self.filterAction = nil
    self.searchText = ""
    self.timeRangeSeconds = 0
    self.currentPage = 1
    self.pageSize = 50
    self.totalLogs = 0
    self.expandedRows = {} -- [rowIndex] = true

    -- ── Filter bar (row 1): action dropdown + time range + refresh ──
    self.filterBar = self:Add("EditablePanel")
    self.filterBar:Dock(TOP)
    self.filterBar:SetTall(ix.ui.Scale(32))
    self.filterBar:DockMargin(0, 0, 0, ix.ui.Scale(2))
    self.filterBar.Paint = function(s, w, h)
        surface.SetDrawColor(ix.ui.THEME.buttonBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawRect(0, h - 1, w, 1)
    end

    -- Action type filter dropdown
    self.filterLabel = self.filterBar:Add("DLabel")
    self.filterLabel:Dock(LEFT)
    self.filterLabel:DockMargin(ix.ui.Scale(8), 0, ix.ui.Scale(4), 0)
    self.filterLabel:SetWide(ix.ui.Scale(60))
    self.filterLabel:SetFont("ixImpMenuDiag")
    self.filterLabel:SetTextColor(ix.ui.THEME.textMuted)
    self.filterLabel:SetText("Filter:")

    self.filterCombo = self.filterBar:Add("DComboBox")
    self.filterCombo:Dock(LEFT)
    self.filterCombo:SetWide(ix.ui.Scale(160))
    self.filterCombo:DockMargin(0, ix.ui.Scale(4), ix.ui.Scale(8), ix.ui.Scale(4))
    self.filterCombo:SetFont("ixImpMenuDiag")
    self.filterCombo:SetTextColor(ix.ui.THEME.text)
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
        surface.SetDrawColor(ix.ui.THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    -- Time range dropdown
    self.timeCombo = self.filterBar:Add("DComboBox")
    self.timeCombo:Dock(LEFT)
    self.timeCombo:SetWide(ix.ui.Scale(140))
    self.timeCombo:DockMargin(0, ix.ui.Scale(4), ix.ui.Scale(8), ix.ui.Scale(4))
    self.timeCombo:SetFont("ixImpMenuDiag")
    self.timeCombo:SetTextColor(ix.ui.THEME.text)
    self.timeCombo:SetValue("All Time")
    for _, tr in ipairs(TIME_RANGES) do
        self.timeCombo:AddChoice(tr.label, tr.seconds, tr.seconds == 0)
    end
    self.timeCombo.OnSelect = function(s, index, value, data)
        self.timeRangeSeconds = data or 0
        self.currentPage = 1
        self:RequestLogs()
    end
    self.timeCombo.Paint = function(s, w, h)
        surface.SetDrawColor(ix.ui.THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    -- Refresh button
    self.refreshBtn = self.filterBar:Add("DButton")
    self.refreshBtn:SetText("")
    self.refreshBtn:Dock(LEFT)
    self.refreshBtn:SetWide(ix.ui.Scale(80))
    self.refreshBtn:DockMargin(0, ix.ui.Scale(4), ix.ui.Scale(4), ix.ui.Scale(4))
    self.refreshBtn.DoClick = function()
        self:RequestLogs()
    end
    self.refreshBtn.Paint = function(s, w, h)
        local bg = s:IsHovered() and ix.ui.THEME.buttonBgHover or ix.ui.THEME.buttonBg
        surface.SetDrawColor(bg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("REFRESH", "ixImpMenuDiag", w * 0.5, h * 0.5, ix.ui.THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Copy to clipboard button
    self.copyBtn = self.filterBar:Add("DButton")
    self.copyBtn:SetText("")
    self.copyBtn:Dock(RIGHT)
    self.copyBtn:SetWide(ix.ui.Scale(80))
    self.copyBtn:DockMargin(ix.ui.Scale(4), ix.ui.Scale(4), ix.ui.Scale(4), ix.ui.Scale(4))
    self.copyBtn.DoClick = function()
        self:CopyToClipboard()
    end
    self.copyBtn.Paint = function(s, w, h)
        local bg = s:IsHovered() and ix.ui.THEME.buttonBgHover or ix.ui.THEME.buttonBg
        surface.SetDrawColor(bg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("COPY", "ixImpMenuDiag", w * 0.5, h * 0.5, ix.ui.THEME.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- ── Search bar (row 2): text search + character name filter ──
    self.searchBar = self:Add("EditablePanel")
    self.searchBar:Dock(TOP)
    self.searchBar:SetTall(ix.ui.Scale(28))
    self.searchBar:DockMargin(0, 0, 0, ix.ui.Scale(4))
    self.searchBar.Paint = function(s, w, h)
        surface.SetDrawColor(ix.ui.THEME.buttonBg)
        surface.DrawRect(0, 0, w, h)
    end

    local searchLabel = self.searchBar:Add("DLabel")
    searchLabel:Dock(LEFT)
    searchLabel:DockMargin(ix.ui.Scale(8), 0, ix.ui.Scale(4), 0)
    searchLabel:SetWide(ix.ui.Scale(60))
    searchLabel:SetFont("ixImpMenuDiag")
    searchLabel:SetTextColor(ix.ui.THEME.textMuted)
    searchLabel:SetText("Search:")

    self.searchEntry = self.searchBar:Add("DTextEntry")
    self.searchEntry:Dock(FILL)
    self.searchEntry:DockMargin(0, ix.ui.Scale(3), ix.ui.Scale(8), ix.ui.Scale(3))
    self.searchEntry:SetFont("ixImpMenuDiag")
    self.searchEntry:SetTextColor(ix.ui.THEME.text)
    self.searchEntry:SetPlaceholderText("Search details or character name...")
    self.searchEntry:SetUpdateOnType(true)
    self.searchEntry.OnValueChange = function(s, val)
        self.searchText = string.lower(string.Trim(val))
        self.currentPage = 1
        self:RequestLogs()
    end
    self.searchEntry.Paint = function(s, w, h)
        surface.SetDrawColor(ix.ui.THEME.panelBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        s:DrawTextEntryText(ix.ui.THEME.text, ix.ui.THEME.accent, ix.ui.THEME.text)
        if (s:GetText() == "" and !s:HasFocus()) then
            draw.SimpleText(s:GetPlaceholderText() or "", "ixImpMenuDiag", ix.ui.Scale(4), h * 0.5, ix.ui.THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    -- ── Page controls ──
    self.pageBar = self:Add("EditablePanel")
    self.pageBar:Dock(BOTTOM)
    self.pageBar:SetTall(ix.ui.Scale(28))
    self.pageBar:DockMargin(0, ix.ui.Scale(2), 0, 0)
    self.pageBar.Paint = function(s, w, h)
        surface.SetDrawColor(ix.ui.THEME.buttonBg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawRect(0, 0, w, 1)
    end

    self.prevBtn = self.pageBar:Add("DButton")
    self.prevBtn:SetText("")
    self.prevBtn:Dock(LEFT)
    self.prevBtn:SetWide(ix.ui.Scale(60))
    self.prevBtn.DoClick = function()
        if (self.currentPage > 1) then
            self.currentPage = self.currentPage - 1
            self:RequestLogs()
        end
    end
    self.prevBtn.Paint = function(s, w, h)
        local canPrev = self.currentPage > 1
        local bg = (s:IsHovered() and canPrev) and ix.ui.THEME.buttonBgHover or ix.ui.THEME.buttonBg
        surface.SetDrawColor(bg)
        surface.DrawRect(0, 0, w, h)
        local col = canPrev and ix.ui.THEME.accent or ix.ui.THEME.textMuted
        draw.SimpleText("< PREV", "ixImpMenuDiag", w * 0.5, h * 0.5, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    self.pageLabel = self.pageBar:Add("DLabel")
    self.pageLabel:Dock(LEFT)
    self.pageLabel:SetWide(ix.ui.Scale(120))
    self.pageLabel:DockMargin(ix.ui.Scale(8), 0, ix.ui.Scale(8), 0)
    self.pageLabel:SetFont("ixImpMenuDiag")
    self.pageLabel:SetTextColor(ix.ui.THEME.textMuted)
    self.pageLabel:SetContentAlignment(5)
    self.pageLabel:SetText("Page 1")

    self.nextBtn = self.pageBar:Add("DButton")
    self.nextBtn:SetText("")
    self.nextBtn:Dock(LEFT)
    self.nextBtn:SetWide(ix.ui.Scale(60))
    self.nextBtn.DoClick = function()
        local maxPage = math.max(1, math.ceil((ix.usms.clientData.logTotalCount or self.filteredCount or 0) / self.pageSize))
        if (self.currentPage < maxPage) then
            self.currentPage = self.currentPage + 1
            self:RequestLogs()
        end
    end
    self.nextBtn.Paint = function(s, w, h)
        local maxPage = math.max(1, math.ceil((self.filteredCount or 0) / self.pageSize))
        local canNext = self.currentPage < maxPage
        local bg = (s:IsHovered() and canNext) and ix.ui.THEME.buttonBgHover or ix.ui.THEME.buttonBg
        surface.SetDrawColor(bg)
        surface.DrawRect(0, 0, w, h)
        local col = canNext and ix.ui.THEME.accent or ix.ui.THEME.textMuted
        draw.SimpleText("NEXT >", "ixImpMenuDiag", w * 0.5, h * 0.5, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    self.countLabel = self.pageBar:Add("DLabel")
    self.countLabel:Dock(RIGHT)
    self.countLabel:SetWide(ix.ui.Scale(120))
    self.countLabel:DockMargin(0, 0, ix.ui.Scale(8), 0)
    self.countLabel:SetFont("ixImpMenuDiag")
    self.countLabel:SetTextColor(ix.ui.THEME.textMuted)
    self.countLabel:SetContentAlignment(6)
    self.countLabel:SetText("")

    -- ── Log rows ──
    self.scroll = self:Add("DScrollPanel")
    self.scroll:Dock(FILL)
    self.scroll:DockMargin(0, 0, 0, 0)

    local sbar = self.scroll:GetVBar()
    sbar:SetWide(ix.ui.Scale(4))
    sbar.Paint = function() end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(s, w, h)
        surface.SetDrawColor(ix.ui.THEME.frameSoft)
        surface.DrawRect(0, 0, w, h)
    end

    -- Listen for log data
    hook.Add("USMSLogsUpdated", self, function(s)
        s:RebuildRows()
    end)

    self.filteredCount = 0

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
    if (self.timeRangeSeconds > 0) then
        data.startTime = os.time() - self.timeRangeSeconds
    end
    ix.usms.Request("log_request", data)
end

--- Apply client-side filters (search text, time range) and return the filtered list.
function PANEL:GetFilteredLogs()
    local logs = ix.usms.clientData.logs or {}
    local filtered = {}
    local now = os.time()

    for _, entry in ipairs(logs) do
        -- Action type filter (already filtered server-side, but double-check for client filter changes)
        if (self.filterAction and entry.action != self.filterAction) then
            continue
        end

        -- Time range filter
        if (self.timeRangeSeconds > 0) then
            local ts = entry.timestamp or 0
            if (ts > 0 and (now - ts) > self.timeRangeSeconds) then
                continue
            end
        end

        -- Text search filter (matches detail string and action label)
        if (self.searchText != "") then
            local detail = string.lower(BuildDetailString(entry))
            local actionLabel = string.lower(LOG_ACTION_LABELS[entry.action] or entry.action or "")
            if (!string.find(detail, self.searchText, 1, true) and !string.find(actionLabel, self.searchText, 1, true)) then
                continue
            end
        end

        table.insert(filtered, entry)
    end

    return filtered
end

function PANEL:RebuildRows()
    self.scroll:Clear()
    self.expandedRows = {}

    local filtered = self:GetFilteredLogs()
    self.filteredCount = #filtered

    -- Pagination on filtered results
    local maxPage = math.max(1, math.ceil((ix.usms.clientData.logTotalCount or self.filteredCount or 0) / self.pageSize))
    if (self.currentPage > maxPage) then self.currentPage = maxPage end
    self.pageLabel:SetText("Page " .. self.currentPage .. " / " .. maxPage .. (self.searchText != "" and " (Filter)" or ""))
    self.countLabel:SetText(self.filteredCount .. " entries")

    local startIdx = 1
    local endIdx = self.filteredCount

    if (self.filteredCount == 0) then
        local lbl = self.scroll:Add("DLabel")
        lbl:Dock(TOP)
        lbl:SetTall(ix.ui.Scale(40))
        lbl:DockMargin(ix.ui.Scale(8), ix.ui.Scale(8), 0, 0)
        lbl:SetFont("ixImpMenuDiag")
        lbl:SetTextColor(ix.ui.THEME.textMuted)
        lbl:SetText("No log entries found.")
        return
    end

    local visibleIndex = 0
    for i = startIdx, endIdx do
        local entry = filtered[i]
        if (!entry) then continue end
        visibleIndex = visibleIndex + 1

        local rowContainer = self.scroll:Add("EditablePanel")
        rowContainer:Dock(TOP)
        rowContainer.logEntry = entry
        rowContainer.rowIndex = visibleIndex
        rowContainer.isExpanded = false

        -- Summary row
        local summaryRow = rowContainer:Add("EditablePanel")
        summaryRow:Dock(TOP)
        summaryRow:SetTall(ix.ui.Scale(44))
        summaryRow:SetMouseInputEnabled(true)
        summaryRow.rowIndex = visibleIndex
        summaryRow.logEntry = entry

        summaryRow.OnCursorEntered = function(s) s.bHovered = true end
        summaryRow.OnCursorExited = function(s) s.bHovered = false end
        summaryRow.OnMousePressed = function(s, code)
            if (code == MOUSE_LEFT) then
                rowContainer.isExpanded = !rowContainer.isExpanded
                if (rowContainer.isExpanded) then
                    self:ExpandRow(rowContainer)
                else
                    self:CollapseRow(rowContainer)
                end
            end
        end

        summaryRow.Paint = function(s, w, h)
            local bg
            if (s.bHovered) then
                bg = ix.ui.THEME.rowHover
            elseif (rowContainer.isExpanded) then
                bg = Color(24, 22, 14, 255)
            elseif (s.rowIndex % 2 == 0) then
                bg = ix.ui.THEME.rowEven
            else
                bg = ix.ui.THEME.rowOdd
            end
            surface.SetDrawColor(bg)
            surface.DrawRect(0, 0, w, h)

            local e = s.logEntry
            local action = e.action or "unknown"
            local actionLabel = LOG_ACTION_LABELS[action] or action
            local actionColor = LOG_ACTION_COLORS[action] or ix.ui.THEME.textMuted

            local ts = e.timestamp or 0
            local timeStr = ts > 0 and os.date("%Y-%m-%d %H:%M", ts) or "?"

            local detail = BuildDetailString(e)
            local pad = ix.ui.Scale(8)

            -- Expand indicator
            local arrow = rowContainer.isExpanded and "▼" or "▶"
            draw.SimpleText(arrow, "ixImpMenuDiag", pad, ix.ui.Scale(14), ix.ui.THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            -- Line 1: [ACTION]  detail
            local labelX = pad + ix.ui.Scale(16)
            draw.SimpleText(actionLabel, "ixImpMenuStatus", labelX, ix.ui.Scale(6), actionColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(detail, "ixImpMenuDiag", labelX + ix.ui.Scale(140), ix.ui.Scale(7), ix.ui.THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            -- Line 2: timestamp
            draw.SimpleText(timeStr, "ixImpMenuDiag", labelX, ix.ui.Scale(24), ix.ui.THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            -- Separator
            surface.SetDrawColor(ColorAlpha(ix.ui.THEME.frameSoft, 20))
            surface.DrawRect(0, h - 1, w, 1)
        end

        -- Set initial height (collapsed)
        rowContainer:SetTall(ix.ui.Scale(44))
    end
end

function PANEL:ExpandRow(rowContainer)
    local entry = rowContainer.logEntry
    if (!entry) then return end

    -- Remove previous detail if any
    if (IsValid(rowContainer.detailPanel)) then
        rowContainer.detailPanel:Remove()
    end

    local detailPanel = rowContainer:Add("EditablePanel")
    detailPanel:Dock(TOP)
    detailPanel:DockMargin(ix.ui.Scale(24), 0, ix.ui.Scale(8), ix.ui.Scale(4))
    rowContainer.detailPanel = detailPanel

    -- Build detail lines
    local lines = {}
    local ts = entry.timestamp or 0
    if (ts > 0) then
        table.insert(lines, {label = "Time", value = os.date("%Y-%m-%d %H:%M:%S", ts)})
    end
    table.insert(lines, {label = "Action", value = LOG_ACTION_LABELS[entry.action] or entry.action or "?"})

    if (entry.actorCharID) then
        local actorName = (entry.data and entry.data.actorName) or ("Char#" .. entry.actorCharID)
        table.insert(lines, {label = "Actor", value = actorName .. " (ID: " .. entry.actorCharID .. ")"})
    end
    if (entry.targetCharID) then
        local targetName = (entry.data and entry.data.targetName) or ("Char#" .. entry.targetCharID)
        table.insert(lines, {label = "Target", value = targetName .. " (ID: " .. entry.targetCharID .. ")"})
    end

    -- Additional data fields
    if (entry.data) then
        for k, v in SortedPairs(entry.data) do
            if (k != "actorName" and k != "targetName") then
                table.insert(lines, {label = k, value = tostring(v)})
            end
        end
    end

    local lineHeight = ix.ui.Scale(18)
    for _, line in ipairs(lines) do
        local row = detailPanel:Add("EditablePanel")
        row:Dock(TOP)
        row:SetTall(lineHeight)
        row.lineLabel = line.label
        row.lineValue = line.value
        row.Paint = function(s, w, h)
            draw.SimpleText(s.lineLabel .. ":", "ixImpMenuStatus", ix.ui.Scale(4), h * 0.5, ix.ui.THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(s.lineValue, "ixImpMenuDiag", ix.ui.Scale(90), h * 0.5, ix.ui.THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    local totalDetailH = #lines * lineHeight + ix.ui.Scale(4)
    detailPanel:SetTall(totalDetailH)
    rowContainer:SetTall(ix.ui.Scale(44) + totalDetailH)
    self.scroll:InvalidateLayout()
end

function PANEL:CollapseRow(rowContainer)
    if (IsValid(rowContainer.detailPanel)) then
        rowContainer.detailPanel:Remove()
    end
    rowContainer:SetTall(ix.ui.Scale(44))
    self.scroll:InvalidateLayout()
end

function PANEL:CopyToClipboard()
    local filtered = self:GetFilteredLogs()
    local lines = {}

    table.insert(lines, "USMS Activity Log — Exported " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(lines, string.rep("-", 60))

    for _, entry in ipairs(filtered) do
        local action = LOG_ACTION_LABELS[entry.action] or entry.action or "?"
        local ts = entry.timestamp or 0
        local timeStr = ts > 0 and os.date("%Y-%m-%d %H:%M:%S", ts) or "?"
        local detail = BuildDetailString(entry)
        table.insert(lines, timeStr .. "  [" .. action .. "]  " .. detail)
    end

    SetClipboardText(table.concat(lines, "\n"))

    if (LocalPlayer().Notify) then
        LocalPlayer():Notify("Copied " .. #filtered .. " log entries to clipboard.")
    end
end

function PANEL:Paint(w, h)
end

vgui.Register("ixUSMSLogPanel", PANEL, "EditablePanel")
