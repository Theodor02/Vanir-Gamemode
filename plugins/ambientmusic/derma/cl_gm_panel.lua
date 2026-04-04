
-- ixMusicGMPanel: Gamemaster music control panel.
-- Overhauled to match Imperial UI (impmainmenu/00_imperial_ui) aesthetic, scalable layout,
-- and improved UX (filtering, queue management, safe actions).

local PANEL = {}

local THEME = ix.ui and ix.ui.THEME or {
    background = Color(10, 10, 10, 240),
    panelBg    = Color(0, 0, 0, 200),
    frame      = Color(191, 148, 53, 220),
    frameSoft  = Color(191, 148, 53, 120),
    text       = Color(235, 235, 235, 245),
    accent     = Color(191, 148, 53, 255),
    danger     = Color(180, 60, 60, 255),
    buttonBg   = Color(16, 16, 16, 220),
}

local function S(v)
    return ix.ui and ix.ui.Scale and ix.ui.Scale(v) or math.max(1, math.Round(v * (ScrH() / 900)))
end

local CIRC_COLORS = {
    ambient     = Color(80, 160, 210),
    combat      = Color(200, 70, 70),
    tension     = THEME.frameSoft,
    celebration = Color(80, 200, 100),
}

local QUICK_CIRCS = { "ambient", "combat", "tension", "celebration" }

local function CircColor(c)
    return CIRC_COLORS[c] or THEME.frameSoft
end

local function DisplayName(entry)
    local name = entry.title or entry.path or ""
    if name == entry.path then
        name = name:match("([^/\\]+)$") or name
        name = name:match("^(.+)%..+$") or name
    end
    return name
end

local function SendRequest(action, data)
    net.Start("ixAmbientMusicRequest")
        net.WriteString(action)
        net.WriteTable(data or {})
    net.SendToServer()
end

-- ─── Helper: Styled Frame ─────────────────────────────────────────────────────

local function PaintImperialBox(s, w, h, hover, active)
    -- Minimal panel style: very dark background, subtle thin border
    -- Matches "Structural Implication over Explicit Bounding" - no full frame outlines if possible,
    -- but for the main blocks we can use just a very simple border.
    surface.SetDrawColor(THEME.panelBg)
    surface.DrawRect(0, 0, w, h)
    
    surface.SetDrawColor(THEME.frameSoft)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
end

local function PaintImperialButton(s, w, h, baseThemeCol)
    local col = baseThemeCol or THEME.accent
    
    -- Very subtle button backings.
    surface.SetDrawColor(THEME.buttonBg or Color(16, 16, 16, 220))
    surface.DrawRect(0, 0, w, h)

    if s:IsHovered() then
        surface.SetDrawColor(ColorAlpha(col, 20))
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(col)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    else
        surface.SetDrawColor(ColorAlpha(col, 60))
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
end

-- ─── Init ─────────────────────────────────────────────────────────────────────

function PANEL:Init()
    local minW, minH = S(800), S(550)
    local defW, defH = S(1000), S(650)
    
    self:SetTitle("")
    self:ShowCloseButton(false)
    self:SetDraggable(true)
    self:SetSizable(true)
    self:SetMinWidth(minW)
    self:SetMinHeight(minH)
    self:SetSize(defW, defH)
    self:Center()
    self:MakePopup()

    -- Ensure we unregister on close
    local origClose = self.Close
    self.Close = function(s)
        ix.music._gmPanel = nil
        hook.Run("MenuSubpanelClosed")
        origClose(s)
    end

    self.Paint = function(s, w, h)
        -- Imperial aesthetic window
        surface.SetDrawColor(THEME.background)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frame)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        
        -- Header Bar Line (thin)
        surface.SetDrawColor(THEME.frame)
        surface.DrawRect(0, S(28), w, 1)
        
        -- Header Title Decor
        surface.SetFont("ixImpMenuLabel")
        surface.SetTextColor(THEME.frame)
        surface.SetTextPos(S(8), S(7))
        surface.DrawText("/// SKELETON SYS // AMBIENT CONTROL //")
    end
    
    -- Custom Imperial Close Button
    self.btnClose = self:Add("DButton")
    self.btnClose:SetSize(S(28), S(28))
    self.btnClose:SetPos(self:GetWide() - S(28), 0)
    self.btnClose:SetText("X")
    self.btnClose:SetFont("ixImpMenuLabel")
    self.btnClose:SetTextColor(THEME.danger)
    self.btnClose.Paint = function(s, w, h)
        if s:IsHovered() then
            surface.SetDrawColor(ColorAlpha(THEME.danger, 40))
            surface.DrawRect(0, 0, w, h)
        end
    end
    self.btnClose.DoClick = function()
        self:Close()
    end

    local pad = S(8)

    -- Container for left/right split
    self.contentPanel = self:Add("DPanel")
    self.contentPanel:Dock(FILL)
    self.contentPanel:DockMargin(pad, S(28) + pad, pad, pad)
    self.contentPanel.Paint = function() end

    -- ── Left: track browser ───────────────────────────────────────────────────
    self.leftPanel = self.contentPanel:Add("DPanel")
    self.leftPanel:Dock(LEFT)
    self.leftPanel:SetWide(S(400))
    self.leftPanel:DockMargin(0, 0, pad, 0)
    self.leftPanel.Paint = function(s, w, h)
        PaintImperialBox(s, w, h, false, false)
    end

    self.trackScroll = self.leftPanel:Add("DScrollPanel")
    self.trackScroll:Dock(FILL)
    self.trackScroll:DockMargin(S(4), S(4), S(4), S(4))
    self.trackScroll.Paint = function() end

    -- Custom Vbar
    local sbar = self.trackScroll:GetVBar()
    sbar:SetWide(S(6))
    sbar.Paint         = function() end
    sbar.btnUp.Paint   = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(sb, w, h)
        surface.SetDrawColor(ColorAlpha(THEME.frame, 60))
        surface.DrawRect(w/2 - S(2), 0, S(4), h)
    end

    -- ── Right: controls ───────────────────────────────────────────────────────
    self.rightPanel = self.contentPanel:Add("DPanel")
    self.rightPanel:Dock(FILL)
    self.rightPanel.Paint = function() end

    self:BuildRightPanel()

    ix.music._gmPanel = self
end

function PANEL:PerformLayout(w, h)
    if IsValid(self.btnClose) then
        self.btnClose:SetPos(w - S(28), 0)
    end
end

-- ─── Right panel ──────────────────────────────────────────────────────────────

function PANEL:BuildRightPanel()
    local rp = self.rightPanel
    local pad = S(8)

    -- Status Toasts (Moved/Hidden normally, removed to reduce clutter unless needed)
    self.statusRow = rp:Add("DPanel")
    self.statusRow:Dock(TOP)
    self.statusRow:SetTall(0) -- Hidden by default to reduce clutter
    self.statusRow:DockMargin(0, 0, 0, 0)
    self.statusRow.Paint = function() end

    self.statusLabel = self.statusRow:Add("DLabel")
    self.statusLabel:Dock(FILL)
    self.statusLabel:SetFont("ixImpMenuLabel")
    self.statusLabel:SetTextColor(THEME.accent or color_white)
    self.statusLabel:SetText("")

    -- ── NOW PLAYING ───────────────────────────────────────────────────────────
    local npBlock = rp:Add("DPanel")
    npBlock:Dock(TOP)
    npBlock:SetTall(S(70))
    npBlock:DockMargin(0, 0, 0, pad)
    npBlock.Paint = function(s, w, h)
        PaintImperialBox(s, w, h, false, false)
        -- Solid gold header strip
        surface.SetDrawColor(THEME.frame)
        surface.DrawRect(0, 0, w, S(20))
    end

    local npLbl = npBlock:Add("DLabel")
    npLbl:SetPos(S(8), S(2))
    npLbl:SetSize(S(200), S(16))
    npLbl:SetText("NOW PLAYING")
    npLbl:SetFont("ixImpMenuLabel")
    npLbl:SetTextColor(THEME.backgroundSolid or color_black)

    self.npTrackLabel = npBlock:Add("DLabel")
    self.npTrackLabel:SetPos(S(8), S(26))
    self.npTrackLabel:SetSize(S(1000), S(20))
    self.npTrackLabel:SetText("NO SIGNAL / NOTHING PLAYING")
    self.npTrackLabel:SetFont("ixImpMenuSubtitle")
    self.npTrackLabel:SetTextColor(THEME.text or color_white)

    self.npSubLabel = npBlock:Add("DLabel")
    self.npSubLabel:SetPos(S(8), S(48))
    self.npSubLabel:SetSize(S(400), S(16))
    self.npSubLabel:SetText("")
    self.npSubLabel:SetFont("ixImpMenuLabel")
    self.npSubLabel:SetTextColor(CircColor("ambient"))

    local stopBtn = npBlock:Add("DButton")
    stopBtn:Dock(RIGHT)
    stopBtn:SetWide(S(100))
    stopBtn:DockMargin(0, S(24), S(8), S(16))
    stopBtn:SetText("STOP ALL")
    stopBtn:SetFont("ixImpMenuLabel")
    stopBtn:SetTextColor(THEME.danger)
    stopBtn.Paint = function(s, w, h)
        PaintImperialButton(s, w, h, THEME.danger)
    end
    stopBtn.DoClick = function()
        Derma_Query("Are you sure you want to STOP all ambient music and queues globally?", "Confirm Stop All",
            "Stop", function() SendRequest("force_stop", {}) end,
            "Cancel", nil)
    end

    local skipBtn = npBlock:Add("DButton")
    skipBtn:Dock(RIGHT)
    skipBtn:SetWide(S(100))
    skipBtn:DockMargin(0, S(24), S(8), S(16))
    skipBtn:SetText("SKIP NEXT")
    skipBtn:SetFont("ixImpMenuLabel")
    skipBtn:SetTextColor(THEME.text)
    skipBtn.Paint = function(s, w, h)
        PaintImperialButton(s, w, h, THEME.frame)
    end
    skipBtn.DoClick = function()
        SendRequest("queue_skip", {})
    end

    -- ── CIRCUMSTANCE ──────────────────────────────────────────────────────────
    local circBlock = rp:Add("DPanel")
    circBlock:Dock(TOP)
    circBlock:SetTall(S(70))
    circBlock:DockMargin(0, 0, 0, pad)
    circBlock.Paint = function(s, w, h)
        PaintImperialBox(s, w, h, false, false)
        surface.SetDrawColor(THEME.frame)
        surface.DrawRect(0, 0, w, S(20))
    end

    local circLbl = circBlock:Add("DLabel")
    circLbl:SetPos(S(8), S(2))
    circLbl:SetSize(S(200), S(16))
    circLbl:SetText("CIRCUMSTANCE OVERRIDE")
    circLbl:SetFont("ixImpMenuLabel")
    circLbl:SetTextColor(THEME.backgroundSolid or color_black)

    local circRows = circBlock:Add("DPanel")
    circRows:Dock(FILL)
    circRows:DockMargin(S(8), S(28), S(8), S(12))
    circRows.Paint = function() end

    for i, circ in ipairs(QUICK_CIRCS) do
        local qBtn = circRows:Add("DButton")
        qBtn:Dock(LEFT)
        qBtn:SetWide(S(115))
        qBtn:DockMargin(0, 0, S(4), 0)
        qBtn:SetText(string.upper(circ))
        qBtn:SetFont("ixImpMenuLabel")
        qBtn:SetTextColor(THEME.text)
        local col = CircColor(circ)
        qBtn.Paint = function(s, w, h)
            local active = ix.music.clientState.circumstance == circ
            PaintImperialButton(s, w, h, active and col or THEME.frameSoft)
            if active then
                surface.SetDrawColor(ColorAlpha(col, 30))
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(col)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end
        end
        qBtn.DoClick = function()
            SendRequest("set_circumstance", { circumstance = circ })
            if IsValid(self.circEntry) then self.circEntry:SetText(circ) end
        end
    end

    local setBtn = circRows:Add("DButton")
    setBtn:Dock(RIGHT)
    setBtn:SetWide(S(60))
    setBtn:SetText("SET")
    setBtn:SetFont("ixImpMenuLabel")
    setBtn:SetTextColor(THEME.text)
    setBtn.Paint = function(s, w, h)
        PaintImperialButton(s, w, h, THEME.frame)
    end

    self.circEntry = circRows:Add("DTextEntry")
    self.circEntry:Dock(FILL)
    self.circEntry:DockMargin(S(8), 0, S(4), 0)
    self.circEntry:SetText(ix.music.clientState.circumstance or "ambient")
    self.circEntry:SetFont("ixImpMenuLabel")
    self.circEntry.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.inputBg or Color(6, 6, 6, 220))
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(ColorAlpha(THEME.frame, 40))
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        s:DrawTextEntryText(THEME.text or color_white, THEME.accent or THEME.frame, THEME.text or color_white)
    end
    
    local confirmSet = function()
        local val = self.circEntry:GetValue():Trim()
        if val != "" then SendRequest("set_circumstance", { circumstance = val }) end
    end
    self.circEntry.OnEnter = confirmSet
    setBtn.DoClick = confirmSet

    -- ── QUEUE ─────────────────────────────────────────────────────────────────
    local qBlock = rp:Add("DPanel")
    qBlock:Dock(FILL)
    qBlock.Paint = function(s, w, h)
        PaintImperialBox(s, w, h, false, false)
        surface.SetDrawColor(THEME.frame)
        surface.DrawRect(0, 0, w, S(20))
    end
    
    local qHdrRow = qBlock:Add("DPanel")
    qHdrRow:Dock(TOP)
    qHdrRow:SetTall(S(20))
    qHdrRow.Paint = function() end

    local qLbl = qHdrRow:Add("DLabel")
    qLbl:Dock(LEFT)
    qLbl:SetWide(S(150))
    qLbl:DockMargin(S(8), 0, 0, 0)
    qLbl:SetText("GLOBAL QUEUE")
    qLbl:SetFont("ixImpMenuLabel")
    qLbl:SetTextColor(THEME.backgroundSolid or color_black)

    self.queueCountLabel = qHdrRow:Add("DLabel")
    self.queueCountLabel:Dock(FILL)
    self.queueCountLabel:SetText("EMPTY")
    self.queueCountLabel:SetFont("ixImpMenuLabel")
    self.queueCountLabel:SetTextColor(THEME.backgroundSolid or color_black)

    self.shuffleBtn = qHdrRow:Add("DButton")
    self.shuffleBtn:SetWide(S(80))
    self.shuffleBtn:SetTall(S(20))
    self.shuffleBtn:SetFont("ixImpMenuLabel")
    self.shuffleBtn:SetTextColor(THEME.text)
    self.shuffleBtn.Paint = function(s, w, h)
        surface.SetDrawColor(s:IsHovered() and THEME.backgroundSolid or THEME.frame)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(Color(0,0,0, 100))
        surface.DrawRect(0, 0, 1, h) 
    end
    self.shuffleBtn.DoClick = function()
        SendRequest("toggle_shuffle", {})
    end
    local clearBtn = qBlock:Add("DButton")
    clearBtn:SetPos(qBlock:GetWide() - S(80), 0)
    clearBtn:SetWide(S(80))
    clearBtn:SetTall(S(20))
    clearBtn:SetText("CLEAR")
    clearBtn:SetFont("ixImpMenuLabel")
    clearBtn:SetTextColor(THEME.backgroundSolid or color_black)
    clearBtn.Paint = function(s, w, h)
        surface.SetDrawColor(s:IsHovered() and THEME.danger or THEME.frame)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(Color(0,0,0, 100))
        surface.DrawRect(0, 0, 1, h) 
    end
    clearBtn.DoClick = function()
        if #(ix.music.clientState.queue or {}) == 0 then return end
        Derma_Query("Are you sure you want to clear the ENTIRE global queue?", "Clear Queue",
            "Clear", function() SendRequest("queue_clear", {}) end,
            "Cancel", nil)
    end
    
    local oldPaint = qBlock.Paint
    qBlock.Paint = function(s, w, h)
        clearBtn:SetPos(w - clearBtn:GetWide(), 0)
        if IsValid(self.shuffleBtn) then
            self.shuffleBtn:SetPos(w - clearBtn:GetWide() - self.shuffleBtn:GetWide() - S(2), 0)
        end
        oldPaint(s, w, h)
    end

    self.queueScroll = qBlock:Add("DScrollPanel")
    self.queueScroll:Dock(FILL)
    self.queueScroll:DockMargin(S(4), S(4), S(4), S(4))
    self.queueScroll.Paint = function() end
    
    local qsbar = self.queueScroll:GetVBar()
    qsbar:SetWide(S(6))
    qsbar.Paint         = function() end
    qsbar.btnUp.Paint   = function() end
    qsbar.btnDown.Paint = function() end
    qsbar.btnGrip.Paint = function(sb, w, h)
        surface.SetDrawColor(ColorAlpha(THEME.frame, 60))
        surface.DrawRect(w/2 - S(2), 0, S(4), h)
    end
end

-- ─── Track browser ────────────────────────────────────────────────────────────

function PANEL:Populate(data)
    if !IsValid(self) then return end
    self.fullData = data

    self:RefreshStatus(data)
    self:BuildTrackBrowser()
    self:RefreshQueueList(data.queue)
    self:RefreshNowPlaying()
    self:RefreshShuffle()
end

function PANEL:FilterTracks(query)
    self.searchQuery = query
    self:BuildTrackBrowser()
end

function PANEL:BuildTrackBrowser()
    self.trackScroll:Clear()
    self.trackRowsList = {}

    local data = self.fullData
    if not data then return end

    local q = self.searchQuery or ""
    local innerW = self.leftPanel:GetWide() - S(16)
    local ROW_H  = S(24)
    local BTN_W  = S(40)

    -- Top-level tracks
    if data.topTracks and #data.topTracks > 0 then
        local hdr = self.trackScroll:Add("DPanel")
        hdr:Dock(TOP)
        hdr:SetTall(S(20))
        hdr:DockMargin(S(2), S(4), S(2), 0)
        hdr.Paint = function(s, w, h)
            surface.SetDrawColor(THEME.frame)
            surface.DrawRect(0, 0, w, h)
        end
        local hdrLbl = hdr:Add("DLabel")
        hdrLbl:Dock(FILL)
        hdrLbl:DockMargin(S(8), 0, 0, 0)
        hdrLbl:SetText("GENERAL TRACKS")
        hdrLbl:SetFont("ixImpMenuLabel")
        hdrLbl:SetTextColor(THEME.backgroundSolid or color_black)
        
        local anyMatches = false

        for _, entry in ipairs(data.topTracks) do
            local disp = DisplayName(entry)
            if q == "" or disp:lower():find(q, 1, true) then
                self:MakeTrackRowItem(entry, self.trackScroll, ROW_H, BTN_W, 0)
                anyMatches = true
            end
        end
        if not anyMatches and q ~= "" then hdr:Remove() end
    end

    -- Playlists
    if data.playlists then
        for key, playlist in SortedPairs(data.playlists) do
            self:AddPlaylist(key, playlist, innerW, ROW_H, BTN_W, q)
        end
    end
end

function PANEL:AddPlaylist(key, playlist, innerW, ROW_H, BTN_W, searchQ)
    local tracks  = playlist.tracks or {}
    local modeCol = THEME.frame
    local INDENT  = S(0)
    local HDR_H   = S(24)

    local filteredTracks = {}
    if searchQ == "" then
        filteredTracks = tracks
    else
        for _, t in ipairs(tracks) do
            if DisplayName(t):lower():find(searchQ, 1, true) then
                table.insert(filteredTracks, t)
            end
        end
    end

    if searchQ ~= "" and #filteredTracks == 0 then return end

    local headerRow = self.trackScroll:Add("DButton")
    headerRow:SetText("")
    headerRow:Dock(TOP)
    headerRow:SetTall(HDR_H)
    headerRow:DockMargin(0, S(2), 0, S(1))
    headerRow._expanded = (searchQ ~= "")
    headerRow.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.frame)
        surface.DrawRect(0, 0, w, h)
    end

    local arrowLbl = headerRow:Add("DLabel")
    arrowLbl:Dock(LEFT)
    arrowLbl:SetWide(S(24))
    arrowLbl:SetTextInset(S(8), 0)
    arrowLbl:SetText(headerRow._expanded and "▼" or "▶")
    arrowLbl:SetFont("ixImpMenuLabel")
    arrowLbl:SetTextColor(THEME.backgroundSolid or color_black)

    local qAllBtn = headerRow:Add("DButton")
    qAllBtn:Dock(RIGHT)
    qAllBtn:SetWide(S(60))
    qAllBtn:DockMargin(S(2), S(2), S(2), S(2))
    qAllBtn:SetText("+Q ALL")
    qAllBtn:SetFont("ixImpMenuLabel")
    qAllBtn:SetTextColor(THEME.text)
    qAllBtn.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.backgroundSolid or color_black)
        surface.DrawRect(0, 0, w, h)
        if s:IsHovered() then
            surface.SetDrawColor(ColorAlpha(THEME.frame, 20))
            surface.DrawRect(0, 0, w, h)
        end
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    qAllBtn.DoClick = function() SendRequest("queue_playlist", { key = key }) end

    local playBtn = headerRow:Add("DButton")
    playBtn:Dock(RIGHT)
    playBtn:SetWide(S(50))
    playBtn:DockMargin(S(2), S(2), 0, S(2))
    playBtn:SetText("PLAY")
    playBtn:SetFont("ixImpMenuLabel")
    playBtn:SetTextColor(THEME.accent)
    playBtn.Paint = function(s, w, h)
        surface.SetDrawColor(THEME.backgroundSolid or color_black)
        surface.DrawRect(0, 0, w, h)
        if s:IsHovered() then
            surface.SetDrawColor(ColorAlpha(THEME.accent, 20))
            surface.DrawRect(0, 0, w, h)
        end
        surface.SetDrawColor(THEME.accent)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    playBtn.DoClick = function() SendRequest("force_playlist", { key = key }) end

    local metaLbl = headerRow:Add("DLabel")
    metaLbl:Dock(RIGHT)
    metaLbl:SetWide(S(90))
    metaLbl:SetText(#tracks .. "  " .. string.upper(playlist.mode or "ambient"))
    metaLbl:SetFont("ixImpMenuLabel")
    metaLbl:SetTextColor(THEME.backgroundSolid or color_black)
    metaLbl:SetContentAlignment(6)

    local nameLbl = headerRow:Add("DLabel")
    nameLbl:Dock(FILL)
    nameLbl:SetText(string.upper(playlist.name or key))
    nameLbl:SetFont("ixImpMenuLabel")
    nameLbl:SetTextColor(THEME.backgroundSolid or color_black)

    local rowContainer = self.trackScroll:Add("DPanel")
    rowContainer:Dock(TOP)
    rowContainer.Paint = function() end
    rowContainer.rows = {}

    local currentTall = 0
    for _, entry in ipairs(filteredTracks) do
        local row = self:MakeTrackRowItem(entry, rowContainer, ROW_H, BTN_W, INDENT)
        table.insert(rowContainer.rows, row)
        currentTall = currentTall + ROW_H + S(2)
    end

    rowContainer:SetTall(headerRow._expanded and currentTall or 0)
    rowContainer._fullTall = currentTall

    headerRow.DoClick = function(s)
        s._expanded = !s._expanded
        arrowLbl:SetText(s._expanded and "▼" or "▶")
        rowContainer:SetTall(s._expanded and rowContainer._fullTall or 0)
        self.trackScroll:InvalidateLayout(true)
    end
end

function PANEL:MakeTrackRowItem(entry, parent, ROW_H, BTN_W, indent)
    local themeCol = CircColor(entry.theme or "ambient")

    local row = parent:Add("DPanel")
    row:Dock(TOP)
    row:SetTall(ROW_H)
    row:DockMargin(indent, S(2), S(4), 0)
    row.Paint = function(s, w, h)
        if s:IsHovered() then
            surface.SetDrawColor(ColorAlpha(THEME.frame, 15))
            surface.DrawRect(0, 0, w, h)
        end
        surface.SetDrawColor(ColorAlpha(THEME.frame, 40))
        surface.DrawRect(0, h-1, w, 1)
        surface.SetDrawColor(themeCol)
        surface.DrawRect(0, 0, S(2), h)
    end

    local qBtn = row:Add("DButton")
    qBtn:Dock(RIGHT)
    qBtn:SetWide(S(40))
    qBtn:DockMargin(S(2), S(2), S(2), S(2))
    qBtn:SetText("+Q")
    qBtn:SetFont("ixImpMenuLabel")
    qBtn:SetTextColor(THEME.text)
    qBtn.Paint = function(s, w, h) PaintImperialButton(s, w, h, THEME.frameSoft) end
    qBtn.DoClick = function()
        SendRequest("queue_add", {
            path     = entry.path,
            theme    = entry.theme or "ambient",
            duration = entry.duration or 0,
            title    = entry.title or entry.path,
        })
    end

    local playBtn = row:Add("DButton")
    playBtn:Dock(RIGHT)
    playBtn:SetWide(S(50))
    playBtn:DockMargin(S(2), S(2), 0, S(2))
    playBtn:SetText("PLAY")
    playBtn:SetFont("ixImpMenuLabel")
    playBtn:SetTextColor(THEME.accent)
    playBtn.Paint = function(s, w, h) PaintImperialButton(s, w, h, THEME.frameSoft) end
    playBtn.DoClick = function()
        SendRequest("force_track", {
            path     = entry.path,
            theme    = entry.theme or "ambient",
            duration = entry.duration or 0,
            title    = entry.title or entry.path,
        })
    end

    local themeLbl = row:Add("DLabel")
    themeLbl:Dock(RIGHT)
    themeLbl:SetWide(S(60))
    themeLbl:SetText(string.upper(entry.theme or "ambient"))
    themeLbl:SetFont("ixImpMenuLabel")
    themeLbl:SetTextColor(themeCol)

    local titleLbl = row:Add("DLabel")
    titleLbl:Dock(FILL)
    titleLbl:DockMargin(S(8), 0, 0, 0)
    titleLbl:SetText(string.upper(DisplayName(entry)))
    titleLbl:SetFont("ixImpMenuLabel")
    titleLbl:SetTextColor(THEME.text or color_white)
    titleLbl:SetTooltip(entry.path)

    return row
end

function PANEL:MakeTrackRow(...) end

-- ─── Live refresh ─────────────────────────────────────────────────────────────

function PANEL:ShowStatus(msg, err)
    if not IsValid(self.statusLabel) then return end
    self.statusLabel:SetTextColor(err and THEME.danger or THEME.ready or color_white)
    self.statusLabel:SetText(string.upper(msg))
    
    if self.statusTimer then timer.Remove(self.statusTimer) end
    self.statusTimer = "ixMusicStatus_" .. tostring(self)
    timer.Create(self.statusTimer, 3, 1, function()
        if IsValid(self) and IsValid(self.statusLabel) then
            self.statusLabel:SetText("")
        end
    end)
end

function PANEL:RefreshStatus(data)
    if !IsValid(self) then return end
    local circ = (data and data.circumstance) or ix.music.clientState.circumstance or "ambient"
    if IsValid(self.circEntry) and not self.circEntry:IsEditing() then
        self.circEntry:SetText(circ)
    end
end

function PANEL:RefreshShuffle()
    if IsValid(self.shuffleBtn) then
        local isOn = ix.music.clientState.shuffleMode or false
        self.shuffleBtn:SetText("SHUFFLE: " .. (isOn and "ON" or "OFF"))
        self.shuffleBtn:SetTextColor(isOn and THEME.accent or THEME.text)
    end
end

function PANEL:RefreshNowPlaying()
    if !IsValid(self.npTrackLabel) then return end

    local track   = ix.music.clientState.currentTrack
    local isForce = ix.music.clientState.isForcePlaying

    if isForce and track then
        self.npTrackLabel:SetText(string.upper(DisplayName(track)))
        self.npTrackLabel:SetTextColor(THEME.text or color_white)
        local col = CircColor(track.theme or "ambient")
        self.npSubLabel:SetText(">> " .. string.upper(track.theme or "ambient") .. " -- GM FORCED")
        self.npSubLabel:SetTextColor(col)
    elseif timer.Exists("ixAmbientMusic") then
        self.npTrackLabel:SetText("AMBIENT BACKGROUND ROTATION ACTIVE")
        self.npTrackLabel:SetTextColor(ColorAlpha(THEME.text or color_white, 150))
        local circ = ix.music.clientState.circumstance or "ambient"
        self.npSubLabel:SetText(">> " .. string.upper(circ))
        self.npSubLabel:SetTextColor(CircColor(circ))
    else
        self.npTrackLabel:SetText("NO SIGNAL / NOTHING PLAYING")
        self.npTrackLabel:SetTextColor(ColorAlpha(THEME.text or color_white, 100))
        self.npSubLabel:SetText("")
    end
end

function PANEL:RefreshQueueList(queue)
    if !IsValid(self) or !IsValid(self.queueScroll) then return end
    self.queueScroll:Clear()

    queue = queue or ix.music.clientState.queue
    local ROW_H = S(24)

    if IsValid(self.queueCountLabel) then
        if #queue > 0 then
            self.queueCountLabel:SetText(#queue .. " TRACK(S)")
            self.queueCountLabel:SetTextColor(THEME.backgroundSolid or color_black)
        else
            self.queueCountLabel:SetText("EMPTY")
            self.queueCountLabel:SetTextColor(ColorAlpha(color_black, 150))
        end
    end

    if #queue == 0 then return end

    local trackCount = #queue

    for i, entry in ipairs(queue) do
        local themeCol = CircColor(entry.theme or "ambient")
        local row = self.queueScroll:Add("DPanel")
        row:Dock(TOP)
        row:SetTall(ROW_H)
        row:DockMargin(0, S(2), S(4), 0)
        row.Paint = function(s, w, h)
            surface.SetDrawColor(ColorAlpha(THEME.frame, 20))
            surface.DrawRect(0, h-1, w, 1)
            surface.SetDrawColor(themeCol)
            surface.DrawRect(0, 0, S(2), h)
        end
        
        local remBtn = row:Add("DButton")
        remBtn:Dock(RIGHT)
        remBtn:SetWide(S(24))
        remBtn:DockMargin(S(1), S(2), S(4), S(2))
        remBtn:SetText("X")
        remBtn:SetFont("ixImpMenuLabel")
        remBtn:SetTextColor(THEME.danger)
        remBtn.Paint = function(s, w, h) PaintImperialButton(s, w, h, THEME.danger) end
        remBtn.DoClick = function() SendRequest("queue_remove", { index = i }) end

        local dnBtn = row:Add("DButton")
        dnBtn:Dock(RIGHT)
        dnBtn:SetWide(S(24))
        dnBtn:DockMargin(S(1), S(2), 0, S(2))
        dnBtn:SetText("V")
        dnBtn:SetFont("ixImpMenuLabel")
        dnBtn:SetTextColor(THEME.text)
        dnBtn.Paint = function(s, w, h) PaintImperialButton(s, w, h, THEME.frameSoft) end
        if i == trackCount then dnBtn:SetEnabled(false) dnBtn:SetAlpha(50) end
        dnBtn.DoClick = function() SendRequest("queue_move", { index = i, dir = 1 }) end

        local upBtn = row:Add("DButton")
        upBtn:Dock(RIGHT)
        upBtn:SetWide(S(24))
        upBtn:DockMargin(S(2), S(2), 0, S(2))
        upBtn:SetText("^")
        upBtn:SetFont("ixImpMenuLabel")
        upBtn:SetTextColor(THEME.text)
        upBtn.Paint = function(s, w, h) PaintImperialButton(s, w, h, THEME.frameSoft) end
        if i == 1 then upBtn:SetEnabled(false) upBtn:SetAlpha(50) end
        upBtn.DoClick = function() SendRequest("queue_move", { index = i, dir = -1 }) end

        local themeLbl = row:Add("DLabel")
        themeLbl:Dock(RIGHT)
        themeLbl:SetWide(S(60))
        themeLbl:SetText(string.upper(entry.theme or "ambient"))
        themeLbl:SetFont("ixImpMenuLabel")
        themeLbl:SetTextColor(themeCol)
        themeLbl:SetContentAlignment(6)

        local numLbl = row:Add("DLabel")
        numLbl:Dock(LEFT)
        numLbl:SetWide(S(28))
        numLbl:DockMargin(S(8), 0, 0, 0)
        numLbl:SetText(string.format("%02d.", i))
        numLbl:SetFont("ixImpMenuLabel")
        numLbl:SetTextColor(i == 1 and themeCol or ColorAlpha(THEME.text or color_white, 110))

        local titleLbl = row:Add("DLabel")
        titleLbl:Dock(FILL)
        titleLbl:SetText(string.upper(DisplayName(entry)))
        titleLbl:SetFont("ixImpMenuLabel")
        titleLbl:SetTextColor(i == 1 and THEME.accent or THEME.text or color_white)
        titleLbl:SetTooltip(entry.path)
    end
end

vgui.Register("ixMusicGMPanel", PANEL, "DFrame")
