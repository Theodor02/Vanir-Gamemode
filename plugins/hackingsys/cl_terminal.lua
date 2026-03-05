--- Terminal Hacking UI
-- Diegetic green-phosphor CRT terminal for the hacking minigame.
-- Follows the impmainmenu visual language (header bars, Aurebesh labels, outlined frames,
-- scanline sweeps, data bars) with a green monochrome terminal palette.
-- @module ix.hacking (client)

ix.hacking = ix.hacking or {}
ix.hacking.UI = ix.hacking.UI or {}

-- =====================================================================================
-- THEME  (green phosphor CRT -- mirrors impmainmenu structure)
-- =====================================================================================

local THEME = {
    background   = Color(4, 8, 4, 250),        -- near-black with green tint
    panel        = Color(8, 14, 8, 240),        -- slightly lighter panel bg
    frame        = Color(45, 160, 50, 220),     -- green frame outline
    frameSoft    = Color(45, 160, 50, 120),     -- softer green (header bars)
    accent       = Color(55, 190, 60, 255),     -- bright green accent
    accentSoft   = Color(55, 190, 60, 180),     -- softer bright green
    accentDim    = Color(30, 100, 35, 120),     -- dim green (diagnostic text)
    text         = Color(55, 200, 65, 245),     -- primary green text (phosphor)
    textMuted    = Color(40, 130, 45, 160),     -- dimmed green text
    textBright   = Color(120, 255, 130, 255),   -- bright flash green
    success      = Color(80, 220, 90, 255),     -- success highlight
    warning      = Color(200, 200, 50, 255),    -- amber warning
    danger       = Color(200, 55, 55, 255),     -- red danger
    buttonBg     = Color(6, 12, 6, 255),        -- dark button bg
    buttonHover  = Color(14, 24, 14, 220),      -- hovered button bg
    border       = Color(45, 160, 50, 60),      -- faint green border
    gridChar     = Color(55, 200, 65, 230),     -- grid character colour
    gridAddr     = Color(40, 140, 45, 180),     -- grid address colour (dimmer)
    logText      = Color(50, 180, 55, 200),     -- log entry colour
    attemptFull  = Color(55, 190, 60, 255),     -- filled attempt block
    attemptEmpty = Color(15, 35, 15, 180),      -- empty attempt block
    consumed     = Color(25, 60, 28, 120),       -- consumed token text (dimmed)
}

local SOUND_HOVER = "everfall/miscellaneous/ux/navigation/navigation_tab_01.mp3"
local SOUND_CLICK = "everfall/miscellaneous/ux/navigation/navigation_activate_01.mp3"
local SOUND_ENTER = "everfall/miscellaneous/ux/navigation/navigation_matchmaking_01.mp3"
local SOUND_ERROR = "everfall/miscellaneous/ux/navigation/navigation_error_01.mp3"

-- =====================================================================================
-- SCALING
-- =====================================================================================

local function Scale(value)
    return math.max(1, math.Round(value * (ScrH() / 900)))
end

-- =====================================================================================
-- FONTS  (Orbitron for UI chrome, Roboto Mono for the grid, Aurebesh for deco)
-- =====================================================================================

local function CreateTermFonts()
    surface.CreateFont("ixHackTermTitle", {
        font = "Orbitron Bold", size = Scale(18), weight = 600, extended = true, antialias = true
    })
    surface.CreateFont("ixHackTermHeader", {
        font = "Orbitron Medium", size = Scale(13), weight = 500, extended = true, antialias = true
    })
    surface.CreateFont("ixHackTermLabel", {
        font = "Orbitron Medium", size = Scale(11), weight = 500, extended = true, antialias = true
    })
    surface.CreateFont("ixHackTermButton", {
        font = "Orbitron Medium", size = Scale(12), weight = 600, extended = true, antialias = true
    })
    surface.CreateFont("ixHackTermAurebesh", {
        font = "Aurebesh", size = Scale(10), weight = 400, extended = true, antialias = true
    })
    surface.CreateFont("ixHackTermAurebeshLg", {
        font = "Aurebesh", size = Scale(12), weight = 400, extended = true, antialias = true
    })
    surface.CreateFont("ixHackTermLog", {
        font = "Roboto Condensed", size = Scale(11), weight = 400, extended = true, antialias = true
    })
    surface.CreateFont("ixHackTermDiag", {
        font = "Orbitron Light", size = Scale(9), weight = 400, extended = true, antialias = true
    })
    surface.CreateFont("ixHackTermSmall", {
        font = "Orbitron Medium", size = Scale(9), weight = 500, extended = true, antialias = true
    })
end

-- Dynamic grid mono font -- sized during layout computation
local gridFontName = "ixHackTermGrid"

local function CreateGridFont(size)
    gridFontName = "ixHackTermGrid." .. size
    surface.CreateFont(gridFontName, {
        font = "Roboto Mono", size = size, weight = 700, antialias = true, extended = true
    })
end

CreateTermFonts()
CreateGridFont(Scale(16))

hook.Add("OnScreenSizeChanged", "ixHackingTermFonts", function()
    CreateTermFonts()
    CreateGridFont(Scale(16))
end)

-- =====================================================================================
-- LAYOUT METRICS
-- =====================================================================================

local GAP_CHARS = 4

local Metrics = {
    CharW = 10, LineH = 16, AddrW = 40,
    GridColW = 200, GridGap = 40, LogW = 280,
    TotalW = 800, TotalH = 600,
    Split = 0, GridH = 0,
    Font = gridFontName
}

-- =====================================================================================
-- HELPERS
-- =====================================================================================

function ix.hacking.UI.PlaySFX(key)
    local path = ix.hacking.Sounds[key]
    if (!path) then return end
    surface.PlaySound(path)
end

function ix.hacking.UI.Cleanup()
    if (IsValid(ix.hacking.UI.Frame)) then
        ix.hacking.UI.Frame:Remove()
    end
    ix.hacking.UI.Frame     = nil
    ix.hacking.UI.Session   = nil
    ix.hacking.UI.GridPanel = nil
end

--- Mark a token as consumed and replace its characters in the grid with dots.
-- This mutates GridLines so the grid panel itself draws dots instead of the
-- original characters, rather than relying solely on the button overlay.
function ix.hacking.UI.ConsumeToken(id)
    local session = ix.hacking.UI.Session
    if (!session) then return end

    local t = session.tokens[id]
    if (!t or t.consumed) then return end

    t.consumed = true

    -- Replace the characters in the backing GridLines with dots
    if (ix.hacking.UI.GridLines and t.line and t.start and t.len) then
        local line = ix.hacking.UI.GridLines[t.line]
        if (line) then
            local before = string.sub(line, 1, t.start - 1)
            local after  = string.sub(line, t.start + t.len)
            ix.hacking.UI.GridLines[t.line] = before .. string.rep(".", t.len) .. after
        end
    end

    -- Disable the button panel so it can't be clicked again
    if (IsValid(t.btn)) then
        t.btn:SetDisabled(true)
        t.btn:SetCursor("arrow")
    end
end

-- =====================================================================================
-- LAYOUT COMPUTATION
-- =====================================================================================

local TITLEBAR_H = 0
local SUBTITLE_H = 0
local FOOTER_H   = 0

local function ComputeLayout(lineCount, widthChars)
    local scrW, scrH = ScrW(), ScrH()
    local margin = Scale(20)
    local availW = scrW - margin * 2
    local availH = scrH - margin * 2

    TITLEBAR_H = Scale(28)      -- the green header bar only
    SUBTITLE_H = Scale(22)      -- "ENTER PASSWORD NOW" row
    FOOTER_H   = Scale(40)

    local sizes = {28, 26, 24, 22, 20, 18, 16, 14, 12}

    for _, size in ipairs(sizes) do
        CreateGridFont(size)
        surface.SetFont(gridFontName)

        local cw, lh = surface.GetTextSize("W")
        local aw = surface.GetTextSize("0x0000 ")
        cw = math.floor(cw)
        lh = math.floor(lh)
        aw = math.floor(aw)

        local gridColW  = aw + (widthChars * cw)
        local gap       = cw * GAP_CHARS
        local gridCombW = (gridColW * 2) + gap
        local logW      = math.max(Scale(240), math.floor(cw * 26))
        local fp        = Scale(4)  -- frame edge padding
        local padding   = Scale(12)
        local innerGap  = Scale(10)
        local totalW    = fp + padding + gridCombW + innerGap + logW + padding + fp
        local split     = math.ceil(lineCount / 2)
        local gridH     = split * lh
        local gridHeaderH = Scale(20)
        local attemptsH = Scale(40)
        local contentMarginV = Scale(4) * 2  -- top + bottom of content area
        -- Total height: fp(top) + titlebar + subtitle + contentMarginTop + gridHeaderH + gridH + contentMarginBot + footer + fp(bot)
        local totalH    = fp + TITLEBAR_H + SUBTITLE_H + contentMarginV + gridHeaderH + gridH + FOOTER_H + fp + Scale(8)

        -- Right column needs to fit log + attempts, which should equal gridH + gridHeaderH
        -- so we do not need extra height beyond the grid

        if (totalW <= availW and totalH <= availH) then
            Metrics.Font     = gridFontName
            Metrics.CharW    = cw
            Metrics.LineH    = lh
            Metrics.AddrW    = aw
            Metrics.GridColW = gridColW
            Metrics.GridGap  = gap
            Metrics.LogW     = logW
            Metrics.TotalW   = totalW
            Metrics.TotalH   = totalH
            Metrics.Split    = split
            Metrics.GridH    = gridH
            return
        end
    end

    -- Fallback: smallest font
    CreateGridFont(12)
    surface.SetFont(gridFontName)
    local cw, lh = surface.GetTextSize("W")
    local aw = surface.GetTextSize("0x0000 ")
    local split = math.ceil(lineCount / 2)

    Metrics.Font     = gridFontName
    Metrics.CharW    = math.floor(cw)
    Metrics.LineH    = math.floor(lh)
    Metrics.AddrW    = math.floor(aw)
    Metrics.GridColW = math.floor(aw + (widthChars * cw))
    Metrics.GridGap  = math.floor(cw * GAP_CHARS)
    Metrics.LogW     = Scale(240)
    Metrics.Split    = split
    Metrics.GridH    = split * Metrics.LineH
    Metrics.TotalW   = Scale(4) + Scale(12) + (Metrics.GridColW * 2) + Metrics.GridGap + Scale(10) + Metrics.LogW + Scale(12) + Scale(4)
    Metrics.TotalH   = Scale(4) + TITLEBAR_H + SUBTITLE_H + Scale(8) + Scale(20) + Metrics.GridH + Scale(8) + FOOTER_H + Scale(4)
end

-- =====================================================================================
-- DIEGETIC DRAWING UTILITIES
-- (modelled after impmainmenu DrawScreeningPanel / panel Paint patterns)
-- =====================================================================================

--- Draw the standard sub-panel frame: dark bg, frameSoft header bar, outline.
local function DrawPanelFrame(w, h, headerH, headerText, aurebeshText)
    -- Background
    surface.SetDrawColor(Color(0, 0, 0, 220))
    surface.DrawRect(0, 0, w, h)

    -- Header bar (solid accent-soft fill)
    surface.SetDrawColor(THEME.frameSoft)
    surface.DrawRect(0, 0, w, headerH)

    -- Outline
    surface.SetDrawColor(THEME.frameSoft)
    surface.DrawOutlinedRect(0, 0, w, h)

    -- Header text (black on coloured bar)
    if (headerText) then
        draw.SimpleText(headerText, "ixHackTermButton", Scale(8), headerH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- Aurebesh label (pulsing, right-aligned)
    if (aurebeshText) then
        local pulse = math.abs(math.sin(CurTime() * 1.5))
        draw.SimpleText(aurebeshText, "ixHackTermAurebesh", w - Scale(8), headerH * 0.5,
            Color(0, 0, 0, math.Round(100 + pulse * 155)),
            TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
end

--- Draw CRT scanline sweep + faint grid lines inside a panel region.
-- Only used on sub-panels (grid, log), NOT on the parent frame.
local function DrawCRTOverlay(w, h, startY, endY)
    local now = CurTime()
    local region = endY - startY
    if (region <= 0) then return end

    -- Slow scanline sweep
    local scanY = startY + (now * 30 % region)
    if (scanY < endY) then
        surface.SetDrawColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 25))
        surface.DrawRect(0, scanY, w, Scale(2))
    end

    -- Faint horizontal grid lines
    surface.SetDrawColor(Color(255, 255, 255, 5))
    for i = 0, 6 do
        local ly = startY + (i / 6) * region
        if (ly < endY) then
            surface.DrawLine(0, ly, w, ly)
        end
    end

    -- CRT phosphor scanlines (every 3px)
    for y = startY, endY, 3 do
        surface.SetDrawColor(0, 0, 0, 22)
        surface.DrawLine(0, y, w, y)
    end
end

--- Draw status-aware data bars. Bar fills reflect actual game state.
local function DrawStatusBars(x, y, w)
    local barH = Scale(4)
    local gap  = Scale(6)
    local session = ix.hacking.UI.Session

    -- Bar 1: Attempts remaining (fills as attempts deplete -> danger)
    local maxAtt = 4
    local curAtt = session and session.attempts or maxAtt
    local attRatio = curAtt / maxAtt

    surface.SetDrawColor(Color(255, 255, 255, 8))
    surface.DrawRect(x, y, w, barH)

    local attColor = THEME.accent
    if (attRatio <= 0.25) then
        attColor = THEME.danger
    elseif (attRatio <= 0.5) then
        attColor = THEME.warning
    end
    surface.SetDrawColor(attColor.r, attColor.g, attColor.b, 150)
    surface.DrawRect(x, y, w * attRatio, barH)

    y = y - gap - barH

    -- Bar 2: Decryption activity (pulses faster as fewer attempts remain)
    local pulseSpeed = 1.0 + (1.0 - attRatio) * 4.0
    local fill = 0.3 + (math.sin(CurTime() * pulseSpeed) + 1) * 0.35

    surface.SetDrawColor(Color(255, 255, 255, 8))
    surface.DrawRect(x, y, w, barH)
    surface.SetDrawColor(THEME.accent.r, THEME.accent.g, THEME.accent.b, 80)
    surface.DrawRect(x, y, w * fill, barH)
end

--- Draw a screen-edge vignette (diegetic CRT curvature hint).
local function DrawVignette(w, h)
    for i = 0, Scale(18) do
        local a = math.Clamp(18 - i, 0, 18) * 4
        surface.SetDrawColor(0, 0, 0, a)
        surface.DrawRect(0, i, w, 1)
        surface.DrawRect(0, h - i - 1, w, 1)
    end
    for i = 0, Scale(12) do
        local a = math.Clamp(12 - i, 0, 12) * 3
        surface.SetDrawColor(0, 0, 0, a)
        surface.DrawRect(i, 0, 1, h)
        surface.DrawRect(w - i - 1, 0, 1, h)
    end
end

-- =====================================================================================
-- BUTTON VGUI  (matches impmainmenu ixMenuButton style with green palette)
-- =====================================================================================

local BUTTON = {}

function BUTTON:Init()
    self:SetText("")
    self.label       = ""
    self.style       = "default"
    self.pulseOffset = math.Rand(0, 6)
    self.nextHover   = 0
end

function BUTTON:SetLabel(text) self.label = text end
function BUTTON:SetStyle(style) self.style = style or "default" end

function BUTTON:GetColors()
    if (self.style == "danger") then
        return THEME.danger, THEME.danger, Color(30, 8, 8, 220), THEME.danger
    elseif (self.style == "accent") then
        return THEME.accent, THEME.accent, Color(10, 22, 10, 220), THEME.accent
    end
    return THEME.text, THEME.accentSoft, THEME.buttonHover, THEME.text
end

function BUTTON:Paint(width, height)
    local hovered = self:IsHovered() or self:IsDown()
    local pulse   = (math.sin(CurTime() * 2 + self.pulseOffset) + 1) * 0.5
    local labelCol, borderCol, hoverBg, hoverLabel = self:GetColors()
    local bg   = THEME.buttonBg
    local glow = hovered and 40 or math.Round(8 + pulse * 12)

    if (hovered) then
        bg = hoverBg
        labelCol = hoverLabel
        borderCol = Color(borderCol.r, borderCol.g, borderCol.b, math.min(255, borderCol.a + 40))
    end

    surface.SetDrawColor(bg)
    surface.DrawRect(0, 0, width, height)

    surface.SetDrawColor(Color(borderCol.r, borderCol.g, borderCol.b, math.min(255, borderCol.a + glow)))
    surface.DrawOutlinedRect(0, 0, width, height)
    surface.DrawOutlinedRect(1, 1, width - 2, height - 2)

    local barW = Scale(3)
    surface.DrawRect(0, 0, barW, height)

    draw.SimpleText(self.label, "ixHackTermButton", width * 0.5, height * 0.5, labelCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function BUTTON:OnCursorEntered()
    if (self:GetDisabled()) then return end
    if (self.nextHover > CurTime()) then return end
    self.nextHover = CurTime() + 0.08
    surface.PlaySound(SOUND_HOVER)
end

function BUTTON:OnMousePressed(code)
    if (self:GetDisabled()) then
        surface.PlaySound(SOUND_ERROR)
        return
    end
    surface.PlaySound(SOUND_CLICK)
    if (code == MOUSE_LEFT and self.DoClick) then
        self:DoClick(self)
    end
end

vgui.Register("ixHackTermButton", BUTTON, "DButton")

-- =====================================================================================
-- OPEN
-- =====================================================================================

function ix.hacking.UI.Open(data)
    ix.hacking.UI.Cleanup()
    surface.PlaySound(SOUND_ENTER)

    ix.hacking.UI.Session = data
    ix.hacking.UI.Session.log = {"> SYSTEM ONLINE", "> ENTER PASSWORD NOW"}
    ix.hacking.UI.LastHovered = nil
    ix.hacking.UI.LastJunkLog = nil

    -- Build grid lines
    ix.hacking.UI.GridLines = {}
    for i = 1, data.lines do
        local s = (i - 1) * data.width + 1
        ix.hacking.UI.GridLines[i] = string.sub(data.gridText, s, s + data.width - 1)
    end

    -- Compute layout
    ComputeLayout(data.lines, data.width)
    local M       = Metrics
    local padding = Scale(12)

    ---------------------------------------------------------------------------
    -- Frame  (outer CRT screen -- NO scanlines on parent)
    ---------------------------------------------------------------------------
    local fp = Scale(4)  -- frame padding for resize grip area

    local frame = vgui.Create("DFrame")
    frame:SetSize(M.TotalW, M.TotalH)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:ShowCloseButton(false)
    frame:SetSizable(true)
    frame:SetDraggable(true)
    frame:SetMinWidth(Scale(400))
    frame:SetMinHeight(Scale(300))
    frame:DockPadding(0, 0, 0, 0)  -- remove DFrame default 24px top padding

    frame.Paint = function(self, w, h)
        -- Dark background (inside frame padding)
        surface.SetDrawColor(THEME.background)
        surface.DrawRect(0, 0, w, h)

        -- Outer frame outline
        surface.SetDrawColor(THEME.frame)
        surface.DrawOutlinedRect(0, 0, w, h)

        -- Vignette (screen edge darkening -- diegetic CRT curvature)
        DrawVignette(w, h)
    end

    frame.OnKeyCodePressed = function(self, code)
        if (code == KEY_ESCAPE) then
            ix.hacking.UI.Close("abort")
        end
    end

    ix.hacking.UI.Frame = frame

    ---------------------------------------------------------------------------
    -- Title Bar  (frameSoft header bar)
    -- Mouse input disabled so clicks pass through to DFrame for dragging.
    -- Close button is parented directly to frame (not title bar) so it stays clickable.
    ---------------------------------------------------------------------------
    local titleBar = vgui.Create("DPanel", frame)
    titleBar:Dock(TOP)
    titleBar:SetTall(TITLEBAR_H)
    titleBar:DockMargin(fp, fp, fp, 0)
    titleBar:SetMouseInputEnabled(false)

    titleBar.Paint = function(self, w, h)
        -- Green header bar
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, 0, w, h)

        -- Title text (black on bar)
        draw.SimpleText("TERMINAL ACCESS PROTOCOL", "ixHackTermTitle", Scale(10), h * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- Aurebesh decoration
        local pulse = math.abs(math.sin(CurTime() * 1.5))
        draw.SimpleText("DECRYPT", "ixHackTermAurebeshLg", w - Scale(76), h * 0.5,
            Color(0, 0, 0, math.Round(100 + pulse * 155)),
            TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- Close button (parented to frame, positioned over title bar on layout)
    local closeBtnH = Scale(20)
    local closeBtnW = Scale(60)
    local closeBtn = vgui.Create("ixHackTermButton", frame)
    closeBtn:SetSize(closeBtnW, closeBtnH)
    closeBtn:SetLabel("CLOSE")
    closeBtn:SetStyle("danger")
    closeBtn:SetZPos(100)  -- ensure it renders above everything
    closeBtn.DoClick = function()
        ix.hacking.UI.Close("abort")
    end

    -- Position close button over the title bar area on every layout pass
    local oldPerformLayout = frame.PerformLayout
    frame.PerformLayout = function(self, w, h)
        if (oldPerformLayout) then oldPerformLayout(self, w, h) end
        -- Keep DockPadding at 0 (DFrame.PerformLayout resets it)
        self:DockPadding(0, 0, 0, 0)
        closeBtn:SetPos(w - closeBtnW - fp - Scale(4), fp + math.floor((TITLEBAR_H - closeBtnH) * 0.5))
    end

    ---------------------------------------------------------------------------
    -- Subtitle Row  (ENTER PASSWORD NOW -- below the header bar)
    ---------------------------------------------------------------------------
    local subtitleBar = vgui.Create("DPanel", frame)
    subtitleBar:Dock(TOP)
    subtitleBar:SetTall(SUBTITLE_H)
    subtitleBar:DockMargin(fp, 0, fp, 0)
    subtitleBar:SetMouseInputEnabled(false)

    subtitleBar.Paint = function(self, w, h)
        draw.SimpleText("ENTER PASSWORD NOW", "ixHackTermLabel", Scale(10), h * 0.5, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    ---------------------------------------------------------------------------
    -- Footer  (status bar with Aurebesh diagnostics + game-state data bars)
    ---------------------------------------------------------------------------
    local footer = vgui.Create("DPanel", frame)
    footer:Dock(BOTTOM)
    footer:SetTall(FOOTER_H)
    footer:DockMargin(fp, 0, fp, fp)

    footer.Paint = function(self, w, h)
        surface.SetDrawColor(Color(0, 0, 0, 180))
        surface.DrawRect(0, 0, w, h)

        -- Top accent line
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawRect(0, 0, w, 1)

        -- Typewriter Aurebesh diagnostics
        local session = ix.hacking.UI.Session
        local curAtt  = session and session.attempts or 4

        -- Pick diagnostic text based on game state
        local diagLines
        if (curAtt <= 1) then
            diagLines = {"WARNING: LOCKOUT IMMINENT", "FINAL ATTEMPT REMAINING", "PROCEED WITH CAUTION"}
        elseif (curAtt <= 2) then
            diagLines = {"CAUTION: LOW ATTEMPTS", "AUTH MATRIX: STRESSED", "DECRYPT MODULE: ACTIVE"}
        else
            diagLines = {"CIPHER-LOCK: ACTIVE", "AUTH MATRIX: PRIMED", "DECRYPT MODULE: STANDBY"}
        end

        local cycle     = 10.0
        local typeSpeed = 0.04
        local timeInCycle = CurTime() % cycle
        local charsToShow = math.floor(timeInCycle / typeSpeed)
        local charsUsed   = 0
        local dx = Scale(10)

        local cycleAlpha = 255
        if (timeInCycle > cycle - 2.0) then
            cycleAlpha = math.Clamp(255 * (1.0 - ((timeInCycle - (cycle - 2.0)) / 1.0)), 0, 255)
        end

        for i = 1, #diagLines do
            local remaining = charsToShow - charsUsed
            if (remaining <= 0) then break end

            local textToDraw = diagLines[i]
            if (remaining < #textToDraw) then
                textToDraw = string.sub(textToDraw, 1, remaining)
            end

            draw.SimpleText(textToDraw, "ixHackTermAurebesh", dx, Scale(4),
                Color(THEME.accentDim.r, THEME.accentDim.g, THEME.accentDim.b, cycleAlpha),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            charsUsed = charsUsed + #diagLines[i]
            dx = dx + Scale(130)
        end

        -- Game-state data bars at bottom
        DrawStatusBars(Scale(10), h - Scale(8), w - Scale(20))
    end

    ---------------------------------------------------------------------------
    -- Content Area  (grid left, right column with log + attempts)
    ---------------------------------------------------------------------------
    local contentPanel = vgui.Create("DPanel", frame)
    contentPanel:Dock(FILL)
    contentPanel:DockMargin(padding + fp, Scale(4), padding + fp, Scale(4))
    contentPanel.Paint = function() end

    ---------------------------------------------------------------------------
    -- Grid Panel  (left -- contains the hex dump, fully sized to fit content)
    ---------------------------------------------------------------------------
    local gridHeaderH  = Scale(20)
    local gridPanelW   = (M.GridColW * 2) + M.GridGap + Scale(4) -- +4 for breathing room

    local gridPanel = vgui.Create("DPanel", contentPanel)
    gridPanel:Dock(LEFT)
    gridPanel:SetWide(gridPanelW)

    ix.hacking.UI.GridPanel = gridPanel

    -- Position helper
    local function GetLocalPos(line, charIndex)
        local isRight = (line > M.Split)
        local relLine = isRight and (line - M.Split - 1) or (line - 1)
        local baseX   = isRight and (M.GridColW + M.GridGap) or 0
        local y       = gridHeaderH + relLine * M.LineH
        local x       = baseX + M.AddrW + ((charIndex - 1) * M.CharW)
        return x, y
    end

    gridPanel.Paint = function(self, w, h)
        -- Panel frame (impmainmenu style)
        DrawPanelFrame(w, h, gridHeaderH, "HEX DUMP", "MEMORY")

        -- CRT scanlines inside grid area only
        DrawCRTOverlay(w, h, gridHeaderH, h)

        -- Draw addresses + characters
        surface.SetFont(M.Font)

        for i = 1, data.lines do
            local isRight = (i > M.Split)
            local relLine = isRight and (i - M.Split - 1) or (i - 1)
            local baseX   = isRight and (M.GridColW + M.GridGap) or 0
            local y       = gridHeaderH + relLine * M.LineH

            -- Address
            surface.SetTextColor(THEME.gridAddr)
            surface.SetTextPos(baseX + Scale(2), y)
            surface.DrawText(data.addresses[i] or "0x0000")

            -- Characters
            local lineStr = ix.hacking.UI.GridLines[i] or ""
            local gridX   = baseX + M.AddrW

            surface.SetTextColor(THEME.gridChar)
            for k = 1, #lineStr do
                surface.SetTextPos(gridX + (k - 1) * M.CharW, y)
                surface.DrawText(string.sub(lineStr, k, k))
            end
        end

        -- Column separator
        local sepX = M.GridColW + math.floor(M.GridGap * 0.5)
        surface.SetDrawColor(THEME.border)
        surface.DrawLine(sepX, gridHeaderH, sepX, h)
    end

    ---------------------------------------------------------------------------
    -- Token Buttons  (overlaid on grid)
    -- Consumed (non-word) tokens render as dots / dimmed and are non-clickable.
    ---------------------------------------------------------------------------
    local sortedTokens = {}
    for _, t in pairs(data.tokens) do
        table.insert(sortedTokens, t)
    end
    table.sort(sortedTokens, function(a, b)
        if (a.line ~= b.line) then return a.line < b.line end
        return a.start < b.start
    end)

    for _, t in ipairs(sortedTokens) do
        local id     = t.id
        local bx, by = GetLocalPos(t.line, t.start)
        local bw     = t.len * M.CharW
        local bh     = M.LineH

        local btn = vgui.Create("DButton", gridPanel)
        btn:SetPos(bx, by)
        btn:SetSize(bw, bh)
        btn:SetText("")
        btn:SetCursor("hand")

        btn.Paint = function(self, pw, ph)
            -- Consumed tokens: always show dots in dimmed colour, non-interactive
            if (t.removed or t.consumed) then
                surface.SetFont(M.Font)
                surface.SetTextColor(THEME.consumed)
                local dots = string.rep(".", t.len)
                for k = 1, #dots do
                    surface.SetTextPos((k - 1) * M.CharW, 0)
                    surface.DrawText(".")
                end
                return
            end

            if (!self:IsHovered()) then
                if (ix.hacking.UI.LastHovered == id) then
                    ix.hacking.UI.LastHovered = nil
                end
                return
            end

            -- Hover sound
            if (ix.hacking.UI.LastHovered ~= id) then
                surface.PlaySound(SOUND_HOVER)
                ix.hacking.UI.LastHovered = id
            end

            -- Highlight: bright green bg with black text (inverted phosphor)
            surface.SetDrawColor(THEME.accent)
            surface.DrawRect(0, 0, pw, ph)

            surface.SetFont(M.Font)
            surface.SetTextColor(Color(0, 0, 0, 255))
            for k = 1, #t.text do
                surface.SetTextPos((k - 1) * M.CharW, 0)
                surface.DrawText(string.sub(t.text, k, k))
            end
        end

        btn.DoClick = function()
            if (t.removed or t.consumed) then return end
            surface.PlaySound(SOUND_CLICK)

            if (t.kind == "word") then
                net.Start("ixHackingSelectWord")
                    net.WriteUInt(id, 16)
                net.SendToServer()
            else
                net.Start("ixHackingActivateToken")
                    net.WriteUInt(id, 16)
                net.SendToServer()
            end
        end

        t.btn = btn
    end

    ---------------------------------------------------------------------------
    -- Right Column  (log panel + attempts panel below it)
    ---------------------------------------------------------------------------
    local rightCol = vgui.Create("DPanel", contentPanel)
    rightCol:Dock(FILL)
    rightCol:DockMargin(Scale(10), 0, 0, 0)
    rightCol.Paint = function() end

    -- Attempts panel (bottom of right column)
    local attemptsH    = Scale(40)
    local attemptsPanel = vgui.Create("DPanel", rightCol)
    attemptsPanel:Dock(BOTTOM)
    attemptsPanel:SetTall(attemptsH)
    attemptsPanel:DockMargin(0, Scale(4), 0, 0)

    local attHeaderH = Scale(18)

    attemptsPanel.Paint = function(self, w, h)
        DrawPanelFrame(w, h, attHeaderH, "ATTEMPTS", "AUTH")

        local maxAtt    = 4
        local curAtt    = ix.hacking.UI.Session and ix.hacking.UI.Session.attempts or 0
        local blockSize = Scale(14)
        local blockGap  = Scale(6)
        local totalBlocksW = maxAtt * blockSize + (maxAtt - 1) * blockGap
        local startX       = Scale(8)
        local blockY       = attHeaderH + math.floor((h - attHeaderH - blockSize) * 0.5)

        for i = 1, maxAtt do
            local bx  = startX + (i - 1) * (blockSize + blockGap)
            local col = (i <= curAtt) and THEME.attemptFull or THEME.attemptEmpty

            surface.SetDrawColor(col)
            surface.DrawRect(bx, blockY, blockSize, blockSize)

            if (i <= curAtt) then
                surface.SetDrawColor(THEME.accent)
            else
                surface.SetDrawColor(THEME.border)
            end
            surface.DrawOutlinedRect(bx, blockY, blockSize, blockSize)
        end

        -- Numeric label
        draw.SimpleText(curAtt .. " / " .. maxAtt, "ixHackTermSmall",
            startX + totalBlocksW + Scale(10), blockY + blockSize * 0.5,
            (curAtt <= 1) and THEME.danger or THEME.textMuted,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- Log panel (fills remaining space above attempts)
    local logPanel   = vgui.Create("DPanel", rightCol)
    logPanel:Dock(FILL)

    local logHeaderH = Scale(20)

    logPanel.Paint = function(self, w, h)
        -- Panel frame
        DrawPanelFrame(w, h, logHeaderH, "SYSTEM LOG", "SYS-LOG")

        -- CRT overlay on log only
        DrawCRTOverlay(w, h, logHeaderH, h)

        -- Log entries (bottom-up)
        if (!ix.hacking.UI.Session) then return end

        surface.SetFont("ixHackTermLog")
        local _, entryH = surface.GetTextSize("W")
        local logPad = Scale(6)
        local y = h - logPad - entryH

        for i = #ix.hacking.UI.Session.log, 1, -1 do
            if (y < logHeaderH + logPad) then break end

            local txt = ix.hacking.UI.Session.log[i]
            local col = (i == #ix.hacking.UI.Session.log) and THEME.textBright or THEME.logText

            draw.SimpleText(txt, "ixHackTermLog", logPad, y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            y = y - entryH - Scale(2)
        end
    end
end

-- =====================================================================================
-- CLOSE
-- =====================================================================================

function ix.hacking.UI.Close(reason)
    if (IsValid(ix.hacking.UI.Frame)) then
        ix.hacking.UI.Frame:Remove()
    end
    ix.hacking.UI.Frame = nil

    if (reason == "abort") then
        surface.PlaySound(SOUND_ERROR)
        net.Start("ixHackingAbort")
        net.SendToServer()
        chat.AddText(THEME.accent, "[TERMINAL] ", THEME.text, "Disconnected.")
    elseif (reason == "success") then
        chat.AddText(THEME.success, "[TERMINAL] ", THEME.textBright, "Access granted.")
    elseif (reason == "lockout") then
        chat.AddText(THEME.danger, "[TERMINAL] ", THEME.text, "Lockout initiated.")
    elseif (reason and reason ~= "unknown") then
        chat.AddText(THEME.accent, "[TERMINAL] ", THEME.text, "Session ended: " .. reason)
    end

    ix.hacking.UI.Session = nil
end

-- =====================================================================================
-- RESULT HELPERS
-- =====================================================================================

function ix.hacking.UI.UpdateWordResult(id, success, attempts, likeness)
    if (!ix.hacking.UI.Session) then return end

    ix.hacking.UI.Session.attempts = attempts
    local t = ix.hacking.UI.Session.tokens[id]
    if (!t) then return end

    table.insert(ix.hacking.UI.Session.log, "> " .. t.text)

    if (success) then
        table.insert(ix.hacking.UI.Session.log, "> ACCESS GRANTED")
        surface.PlaySound(SOUND_ENTER)
    else
        table.insert(ix.hacking.UI.Session.log, "> ENTRY DENIED")
        table.insert(ix.hacking.UI.Session.log, "> LIKENESS=" .. likeness)
        surface.PlaySound(SOUND_ERROR)
    end
end

function ix.hacking.UI.AddLog(msg)
    if (!ix.hacking.UI.Session) then return end
    table.insert(ix.hacking.UI.Session.log, msg)
end