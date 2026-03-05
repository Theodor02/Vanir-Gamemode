--- Compound Sequencer Interface (VGUI)
-- Diegetic medical terminal UI for exploratory sequencing and batch fabrication.
-- Styled to match the impmainmenu Imperial terminal aesthetic with a medical/science theme.
-- @module ix.bacta (client)

-- ═══════════════════════════════════════════════════════════════════════════════
-- THEME
-- ═══════════════════════════════════════════════════════════════════════════════

local THEME = {
    background  = Color(6, 8, 10, 255),
    panel       = Color(12, 14, 18, 240),
    frame       = Color(40, 180, 160, 220),
    frameSoft   = Color(40, 180, 160, 100),
    accent      = Color(40, 200, 180, 255),
    accentSoft  = Color(40, 200, 180, 180),
    accentDim   = Color(30, 140, 120, 120),
    text        = Color(210, 225, 220, 255),
    textMuted   = Color(140, 160, 155, 180),
    textBright  = Color(240, 255, 250, 255),
    success     = Color(60, 200, 100, 255),
    warning     = Color(220, 180, 50, 255),
    danger      = Color(200, 55, 55, 255),
    input       = Color(16, 18, 22, 255),
    buttonBg    = Color(14, 16, 20, 255),
    buttonHover = Color(22, 26, 32, 220),
    border      = Color(40, 180, 160, 60),
    slotEmpty   = Color(16, 20, 26, 255),
    slotFilled  = Color(20, 30, 36, 255),
    tail        = Color(200, 120, 60, 255),
    metaboliser = Color(100, 180, 220, 255),
    tuning      = Color(180, 140, 230, 255),
    proven      = Color(60, 200, 100, 255),
    tested      = Color(220, 180, 50, 255),
    experimental= Color(200, 100, 100, 255),
}

local SOUND_HOVER = "everfall/miscellaneous/ux/navigation/navigation_tab_01.mp3"
local SOUND_CLICK = "everfall/miscellaneous/ux/navigation/navigation_activate_01.mp3"
local SOUND_ERROR = "everfall/miscellaneous/ux/navigation/navigation_error_01.mp3"
local SOUND_SYNTH = "everfall/miscellaneous/ux/navigation/navigation_activate_01.mp3"

-- ═══════════════════════════════════════════════════════════════════════════════
-- FONTS
-- ═══════════════════════════════════════════════════════════════════════════════

local function Scale(value)
    return math.max(1, math.Round(value * (ScrH() / 900)))
end

local function CreateMedFonts()
    surface.CreateFont("ixMedTermTitle", {
        font = "Orbitron Bold",
        size = Scale(22),
        weight = 600,
        extended = true,
        antialias = true
    })

    surface.CreateFont("ixMedTermHeader", {
        font = "Orbitron Medium",
        size = Scale(14),
        weight = 500,
        extended = true,
        antialias = true
    })

    surface.CreateFont("ixMedTermLabel", {
        font = "Orbitron Medium",
        size = Scale(11),
        weight = 500,
        extended = true,
        antialias = true
    })

    surface.CreateFont("ixMedTermButton", {
        font = "Orbitron Medium",
        size = Scale(13),
        weight = 600,
        extended = true,
        antialias = true
    })

    surface.CreateFont("ixMedTermDiag", {
        font = "Orbitron Light",
        size = Scale(10),
        weight = 400,
        extended = true,
        antialias = true
    })

    surface.CreateFont("ixMedTermAurebesh", {
        font = "Aurebesh",
        size = Scale(10),
        weight = 400,
        extended = true,
        antialias = true
    })

    surface.CreateFont("ixMedTermAurebeshLg", {
        font = "Aurebesh",
        size = Scale(13),
        weight = 400,
        extended = true,
        antialias = true
    })

    surface.CreateFont("ixMedTermMono", {
        font = "Roboto Condensed",
        size = Scale(11),
        weight = 400,
        extended = true,
        antialias = true
    })

    surface.CreateFont("ixMedTermMonoSm", {
        font = "Roboto Condensed",
        size = Scale(9),
        weight = 400,
        extended = true,
        antialias = true
    })
end

CreateMedFonts()
hook.Add("OnScreenSizeChanged", "ixMedicalSysFonts", CreateMedFonts)

-- ═══════════════════════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════════════════════

local sessionPool             = {}
local sessionRecipes          = {}
local sessionCanisters        = {}
local sequence                = {}
local lastResult              = nil
local sgcBalance              = 0
local poolInfluenceUsed       = false

-- ═══════════════════════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════════════════════

local function StabilityColor(score)
    if (score >= 80) then return THEME.success end
    if (score >= 60) then return THEME.warning end
    if (score >= 40) then return Color(220, 130, 40) end
    return THEME.danger
end

local function PreviewStability()
    local cfg = ix.bacta.Config
    local stab = cfg.STABILITY_BASE
    local activeCount = 0

    for _, strandID in ipairs(sequence) do
        local strand = ix.bacta.GetStrand(strandID)
        if (!strand) then continue end

        stab = stab + (strand.stability_mod or 0)

        if (strand.category == "active") then
            activeCount = activeCount + 1
        end
    end

    stab = stab - (cfg.ACTIVE_OVERLOAD_PEN * math.max(0, activeCount - 2))
    return math.Clamp(stab, 0, 100)
end

local function InSequence(strandID)
    for _, id in ipairs(sequence) do
        if (id == strandID) then return true end
    end
    return false
end

local function CountCategory(category)
    local n = 0
    for _, id in ipairs(sequence) do
        local strand = ix.bacta.GetStrand(id)
        if (strand and strand.category == category) then
            n = n + 1
        end
    end
    return n
end

local function CanAddStrand(strandID)
    if (#sequence >= ix.bacta.Config.MAX_SEQUENCE_LENGTH) then return false, "Sequence full." end
    if (InSequence(strandID)) then return false, "Already in sequence." end

    local strand = ix.bacta.GetStrand(strandID)
    if (!strand) then return false, "Unknown strand." end

    if (strand.category == "base" and CountCategory("base") >= 1) then
        return false, "Only one Base Compound allowed."
    end

    if (strand.category == "catalyst" and CountCategory("catalyst") >= 2) then
        return false, "Maximum 2 Catalysts."
    end

    if (strand.category == "modifier" and CountCategory("modifier") >= 2) then
        return false, "Maximum 2 Modifiers."
    end

    -- v2.0: Metabolisers share stabiliser slots
    if (ix.bacta.IsMetaboliser and ix.bacta.IsMetaboliser(strandID)) then
        local stabCount = CountCategory("stabiliser")
        local metCount = 0
        for _, id in ipairs(sequence) do
            if (ix.bacta.IsMetaboliser(id)) then metCount = metCount + 1 end
        end
        if (stabCount + metCount >= (ix.bacta.Config.MAX_STABILISERS or 3)) then
            return false, "Stabiliser/Metaboliser slots full."
        end
    end

    -- v2.1: Tuning strands share modifier slots
    if (ix.bacta.IsTuningStrand and ix.bacta.IsTuningStrand(strandID)) then
        local modCount = CountCategory("modifier")
        local tunCount = 0
        for _, id in ipairs(sequence) do
            if (ix.bacta.IsTuningStrand(id)) then tunCount = tunCount + 1 end
        end
        if (modCount + tunCount >= (ix.bacta.Config.MAX_MODIFIERS or 2)) then
            return false, "Modifier/Tuning slots full."
        end
        if (tunCount >= (ix.bacta.Config.MAX_TUNING or 2)) then
            return false, "Maximum tuning strands reached."
        end
    end

    return true, nil
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DIAGNOSTIC DRAWING UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════════

--- Draw an animated medical diagnostic overlay (Aurebesh readouts, scanlines, data bars).
local function DrawMedicalDiagnostics(panel, width, height, headerText, effectsLines)
    local now = CurTime()
    local headerH = Scale(24)
    local innerPad = Scale(8)
    local innerX = innerPad
    local innerY = headerH + innerPad
    local innerW = width - innerPad * 2
    local innerH = height - innerY - Scale(8)

    -- Background
    surface.SetDrawColor(THEME.background)
    surface.DrawRect(0, 0, width, height)

    -- Header bar
    surface.SetDrawColor(THEME.frameSoft)
    surface.DrawRect(0, 0, width, headerH)

    -- Frame outline
    surface.SetDrawColor(THEME.frameSoft)
    surface.DrawOutlinedRect(0, 0, width, height)

    -- Header text
    draw.SimpleText(headerText or "DIAGNOSTICS", "ixMedTermButton", Scale(8), headerH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText("MED-SCAN", "ixMedTermDiag", width - Scale(8), headerH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    -- Scanline sweep
    local scanY = innerY + (now * 30 % innerH)
    if (scanY < innerY + innerH) then
        surface.SetDrawColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 30))
        surface.DrawRect(innerX, scanY, innerW, Scale(2))
    end

    -- Faint grid lines
    surface.SetDrawColor(Color(255, 255, 255, 5))
    for i = 0, 5 do
        local y = innerY + i * (innerH / 5)
        if (y < height) then
            surface.DrawLine(innerX, y, innerX + innerW, y)
        end
    end

    -- Aurebesh terminal readout lines (typewriter effect)
    local diagLines = {
        "SYNTH-CORE: ONLINE",
        "REAGENT MATRIX: PRIMED",
        "COMPOUND BUFFER: CLEAR",
        "CATALYTIC CHAMBER: NOMINAL",
        "STABILITY FIELD: ACTIVE",
        "NEURAL YIELD: 97.3%",
        "TISSUE COMPAT: VERIFIED",
    }

    local cycle = 10.0
    local typeSpeed = 0.04
    local timeInCycle = now % cycle
    local cycleAlpha = 255

    if (timeInCycle > cycle - 2.0) then
        cycleAlpha = math.Clamp(255 * (1 - ((timeInCycle - (cycle - 2.0)) / 1.0)), 0, 255)
    end

    local charsToShow = math.floor(timeInCycle / typeSpeed)
    local charsConsumed = 0
    local lineY = innerY + Scale(4)

    for i = 1, #diagLines do
        if (lineY >= height - Scale(36)) then break end

        local lineLen = #diagLines[i]
        local charsForLine = charsToShow - charsConsumed

        if (charsForLine > 0 and cycleAlpha > 0) then
            local textToDraw = diagLines[i]
            if (charsForLine < lineLen) then
                textToDraw = string.sub(diagLines[i], 1, charsForLine)
            end

            draw.SimpleText(textToDraw, "ixMedTermAurebesh", innerX + Scale(2), lineY,
                Color(THEME.textMuted.r, THEME.textMuted.g, THEME.textMuted.b, cycleAlpha),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        charsConsumed = charsConsumed + lineLen
        lineY = lineY + Scale(12)
    end

    -- Animated data bars at bottom
    local barY = height - Scale(20)
    for i = 1, 3 do
        local phase = now * (0.6 + i * 0.35)
        local fill = 0.3 + (math.sin(phase) + 1) * 0.3
        local barH = Scale(4)

        if (barY + barH > height - Scale(4)) then break end

        surface.SetDrawColor(Color(255, 255, 255, 8))
        surface.DrawRect(innerX, barY, innerW, barH)
        surface.SetDrawColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 100))
        surface.DrawRect(innerX, barY, innerW * fill, barH)
        barY = barY - Scale(8)
    end

    -- Predicted effects overlay (optional)
    local effectList = effectsLines
    if (isfunction(effectsLines)) then
        effectList = effectsLines()
    end

    if (effectList and #effectList > 0) then
        local effectHeaderY = innerY + (innerH * 0.55)
        surface.SetDrawColor(THEME.border)
        surface.DrawLine(innerX, effectHeaderY - Scale(6), innerX + innerW, effectHeaderY - Scale(6))

        draw.SimpleText("PREDICTED EFFECTS", "ixMedTermHeader", innerX + Scale(2), effectHeaderY - Scale(22), THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        local y = effectHeaderY
        for i = 1, #effectList do
            local line = effectList[i]
            if (y > height - Scale(44)) then
                draw.SimpleText("...", "ixMedTermMono", innerX + Scale(2), y, THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                break
            end

            draw.SimpleText(line.text, line.font or "ixMedTermMonoSm", innerX + Scale(2), y, line.color or THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            y = y + Scale(14)
        end
    end
end

--- Draw a data panel header (dark bg, teal accent header bar, outlined frame).
local function DrawDataPanelBg(panel, width, height, headerText, subtitleText)
    local headerH = Scale(24)

    surface.SetDrawColor(Color(0, 0, 0, 220))
    surface.DrawRect(0, 0, width, height)

    -- Header bar
    surface.SetDrawColor(THEME.frameSoft)
    surface.DrawRect(0, 0, width, headerH)

    -- Frame outline
    surface.SetDrawColor(THEME.frameSoft)
    surface.DrawOutlinedRect(0, 0, width, height)

    if (headerText) then
        draw.SimpleText(headerText, "ixMedTermButton", Scale(8), headerH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if (subtitleText) then
        local pulse = math.abs(math.sin(CurTime() * 1.2))
        draw.SimpleText(subtitleText, "ixMedTermAurebesh", width - Scale(8), headerH * 0.5,
            Color(0, 0, 0, math.Round(80 + pulse * 175)),
            TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
end

--- Apply styled scrollbar to a DScrollPanel.
local function StyleScrollbar(scroll)
    if (!IsValid(scroll)) then return end

    local vbar = scroll:GetVBar()
    vbar:SetWide(Scale(4))
    vbar.Paint = function() end
    vbar.btnUp.Paint = function() end
    vbar.btnDown.Paint = function() end
    vbar.btnGrip.Paint = function(_, w, h)
        surface.SetDrawColor(THEME.accentSoft)
        surface.DrawRect(0, 0, w, h)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- BUTTON VGUI
-- ═══════════════════════════════════════════════════════════════════════════════

local BUTTON = {}

function BUTTON:Init()
    self:SetText("")
    self.label = ""
    self.style = "default"
    self.pulseOffset = math.Rand(0, 6)
    self.nextHoverSound = 0
end

function BUTTON:SetLabel(text)
    self.label = text
end

function BUTTON:SetStyle(style)
    self.style = style or "default"
end

function BUTTON:GetColors()
    if (self.style == "accent") then
        return THEME.accent, THEME.accent, Color(15, 28, 26, 220), THEME.accent
    elseif (self.style == "danger") then
        return THEME.danger, THEME.danger, Color(35, 10, 10, 220), THEME.danger
    elseif (self.style == "success") then
        return THEME.success, THEME.success, Color(10, 30, 16, 220), THEME.success
    end

    return THEME.text, THEME.accentSoft, THEME.buttonHover, THEME.text
end

function BUTTON:Paint(width, height)
    local disabled = self:GetDisabled()
    local hovered = self:IsHovered() or self:IsDown()
    local pulse = (math.sin(CurTime() * 2 + self.pulseOffset) + 1) * 0.5
    local labelCol, borderCol, hoverBg, hoverLabel = self:GetColors()
    local bg = THEME.buttonBg
    local glow = hovered and 40 or math.Round(10 + pulse * 16)

    if (hovered) then
        bg = hoverBg
        labelCol = hoverLabel
        borderCol = Color(borderCol.r, borderCol.g, borderCol.b, math.min(255, borderCol.a + 40))
    end

    if (disabled) then
        borderCol = Color(borderCol.r, borderCol.g, borderCol.b, 50)
        bg = Color(bg.r, bg.g, bg.b, 50)
        labelCol = Color(labelCol.r, labelCol.g, labelCol.b, 50)
    else
        borderCol = Color(borderCol.r, borderCol.g, borderCol.b, math.min(255, borderCol.a + glow))
    end

    surface.SetDrawColor(bg)
    surface.DrawRect(0, 0, width, height)

    surface.SetDrawColor(borderCol)
    surface.DrawOutlinedRect(0, 0, width, height)
    surface.DrawOutlinedRect(1, 1, width - 2, height - 2)

    -- Side vertical bars
    local barW = Scale(3)
    surface.SetDrawColor(borderCol)
    surface.DrawRect(0, 0, barW, height)
    surface.DrawRect(width - barW, 0, barW, height)

    draw.SimpleText(self.label, "ixMedTermButton", width * 0.5, height * 0.5, labelCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function BUTTON:OnCursorEntered()
    if (self:GetDisabled()) then return end
    if (self.nextHoverSound > CurTime()) then return end
    self.nextHoverSound = CurTime() + 0.08
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

vgui.Register("ixMedTermButton", BUTTON, "DButton")

-- ═══════════════════════════════════════════════════════════════════════════════
-- NET RECEIVERS
-- ═══════════════════════════════════════════════════════════════════════════════

net.Receive("ixBactaOpen", function()
    sessionPool         = net.ReadTable()
    sessionCanisters    = net.ReadTable()
    sgcBalance          = net.ReadUInt(16)
    sessionRecipes      = {}
    sequence            = {}
    lastResult          = nil
    poolInfluenceUsed   = false

    ix.bacta.OpenSequencerUI()
end)

net.Receive("ixBactaResult", function()
    lastResult = net.ReadTable()

    if (IsValid(ix.bacta.sequencerFrame)) then
        ix.bacta.ShowResultPanel(lastResult)
    end
end)

net.Receive("ixBactaSyncRecipes", function()
    sessionRecipes = net.ReadTable()

    if (IsValid(ix.bacta.fabricationList)) then
        ix.bacta.PopulateFabricationList()
    end
end)

net.Receive("ixBactaSyncBalance", function()
    sgcBalance = net.ReadUInt(16)
end)

--- v2.0: Pool sync (when pool influence adds a strand).
net.Receive("ixBactaSyncPool", function()
    sessionPool = net.ReadTable()
end)

--- v2.0: Integrity check prompt from server.
net.Receive("ixBactaIntegrityCheck", function()
    local canisterItemID = net.ReadUInt(32)
    local reason = net.ReadString()

    Derma_Query(
        "INTEGRITY WARNING\n\n" .. reason .. "\n\nProceed with fabrication?",
        "Production Integrity Check",
        "CONFIRM", function()
            net.Start("ixBactaIntegrityCheck")
                net.WriteUInt(canisterItemID, 32)
                net.WriteBool(true)
            net.SendToServer()
        end,
        "ABORT", function() end
    )
end)

--- v2.0: Experimental broadcast notification.
net.Receive("ixBactaExperimentalBroadcast", function()
    local user = net.ReadEntity()
    local formulaName = net.ReadString()
    local summary = net.ReadString()

    local userName = IsValid(user) and (user:GetCharacter() and user:GetCharacter():GetName() or user:Nick()) or "Someone"
    chat.AddText(
        THEME.experimental, "[EXPERIMENTAL] ",
        THEME.text, userName .. " administered an untested compound: ",
        THEME.warning, formulaName,
        THEME.textMuted, " (" .. summary .. ")"
    )
end)

--- v2.0: Status promotion notification.
net.Receive("ixBactaStatusPromotion", function()
    local canisterItemID = net.ReadUInt(32)
    local newStatus = net.ReadString()
    local formulaName = net.ReadString()

    local statusCol = THEME[newStatus] or THEME.success
    chat.AddText(
        statusCol, "[STATUS PROMOTION] ",
        THEME.textBright, "Formula '" .. formulaName .. "' promoted to ",
        statusCol, string.upper(newStatus),
        THEME.text, " status!"
    )
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- MAIN UI
-- ═══════════════════════════════════════════════════════════════════════════════

function ix.bacta.OpenSequencerUI()
    if (IsValid(ix.bacta.sequencerFrame)) then
        ix.bacta.sequencerFrame:Remove()
    end

    local scrW, scrH = ScrW(), ScrH()
    local fw, fh = math.min(1200, scrW * 0.88), math.min(800, scrH * 0.88)

    local frame = vgui.Create("DFrame")
    frame:SetSize(fw, fh)
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:SetSizable(true)
    frame:SetMinWidth(Scale(600))
    frame:SetMinHeight(Scale(400))
    frame:MakePopup()
    frame:ShowCloseButton(false)

    frame.Paint = function(self, w, h)
        -- Outer background (keep inside cyan frame)
        local fp = Scale(6)
        -- surface.SetDrawColor(THEME.frame)
        -- surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.background)
        surface.DrawRect(fp, fp, w - fp * 2, h - fp * 2)

        -- Inner frame border
        surface.SetDrawColor(THEME.frame)
        surface.DrawOutlinedRect(fp, fp, w - fp * 2, h - fp * 2)

        -- Corner decoration lines
        local cornerLen = Scale(16)
        surface.SetDrawColor(THEME.accent)
        -- Top-left
        surface.DrawRect(fp, fp, cornerLen, Scale(2))
        surface.DrawRect(fp, fp, Scale(2), cornerLen)
        -- Top-right
        surface.DrawRect(w - fp - cornerLen, fp, cornerLen, Scale(2))
        surface.DrawRect(w - fp - Scale(2), fp, Scale(2), cornerLen)
        -- Bottom-left
        surface.DrawRect(fp, h - fp - Scale(2), cornerLen, Scale(2))
        surface.DrawRect(fp, h - fp - cornerLen, Scale(2), cornerLen)
        -- Bottom-right
        surface.DrawRect(w - fp - cornerLen, h - fp - Scale(2), cornerLen, Scale(2))
        surface.DrawRect(w - fp - Scale(2), h - fp - cornerLen, Scale(2), cornerLen)
    end

    ix.bacta.sequencerFrame = frame

    -- Title bar area
    local titleBar = vgui.Create("DPanel", frame)
    titleBar:Dock(TOP)
    titleBar:SetTall(Scale(56))
    titleBar:DockMargin(Scale(12), Scale(10), Scale(12), 0)
    titleBar.Paint = function(self, w, h)
        -- Background
        surface.SetDrawColor(Color(0, 0, 0, 200))
        surface.DrawRect(0, 0, w, h)

        -- Header bar
        local barH = Scale(3)
        surface.SetDrawColor(THEME.accent)
        surface.DrawRect(0, h - barH, w, barH)

        -- Title
        draw.SimpleText("COMPOUND SEQUENCER TERMINAL", "ixMedTermTitle", Scale(16), Scale(22), THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- SGC readout
        draw.SimpleText("SGC BALANCE: " .. sgcBalance, "ixMedTermLabel", Scale(16), Scale(42), THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- Session cost reminder
        local sessionCost = ix.bacta.Config.SESSION_COST or 10
        draw.SimpleText("SESSION COST: " .. sessionCost .. " SGC", "ixMedTermDiag", Scale(180), Scale(42), THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- Close button
    local closeBtn = vgui.Create("ixMedTermButton", titleBar)
    closeBtn:SetSize(Scale(70), Scale(28))
    closeBtn:SetPos(titleBar:GetWide() - Scale(86), Scale(14))
    closeBtn:SetLabel("CLOSE")
    closeBtn:SetStyle("danger")
    closeBtn.DoClick = function() frame:Remove() end

    -- Reposition close button on layout
    titleBar.PerformLayout = function(self, w, h)
        closeBtn:SetPos(w - Scale(86), Scale(14))
    end

    -- Tab system
    local tabBar = vgui.Create("DPanel", frame)
    tabBar:Dock(TOP)
    tabBar:SetTall(Scale(36))
    tabBar:DockMargin(Scale(12), Scale(6), Scale(12), 0)
    tabBar.Paint = function(self, w, h)
        surface.SetDrawColor(Color(0, 0, 0, 160))
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.border)
        surface.DrawLine(0, h - 1, w, h - 1)
    end

    local contentArea = vgui.Create("DPanel", frame)
    contentArea:Dock(FILL)
    contentArea:DockMargin(Scale(12), Scale(6), Scale(12), Scale(12))
    contentArea.Paint = function() end

    -- Create tab panels
    local discoveryPanel = ix.bacta.BuildDiscoveryPanel(contentArea)
    discoveryPanel:Dock(FILL)

    local fabPanel = ix.bacta.BuildFabricationPanel(contentArea)
    fabPanel:Dock(FILL)
    fabPanel:SetVisible(false)

    local activeTab = "discovery"

    local function SetTab(name)
        activeTab = name
        discoveryPanel:SetVisible(name == "discovery")
        fabPanel:SetVisible(name == "fabrication")
    end

    -- Tab buttons
    local tabDiscovery = vgui.Create("DButton", tabBar)
    tabDiscovery:Dock(LEFT)
    tabDiscovery:SetWide(Scale(240))
    tabDiscovery:SetText("")
    tabDiscovery.nextHover = 0
    tabDiscovery.Paint = function(self, w, h)
        local selected = (activeTab == "discovery")
        local hovered = self:IsHovered()

        if (selected) then
            surface.SetDrawColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 25))
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(THEME.accent)
            surface.DrawRect(0, h - Scale(3), w, Scale(3))
        elseif (hovered) then
            surface.SetDrawColor(Color(255, 255, 255, 6))
            surface.DrawRect(0, 0, w, h)
        end

        local textCol = selected and THEME.accent or (hovered and THEME.text or THEME.textMuted)
        draw.SimpleText("EXPLORATORY SEQUENCING", "ixMedTermLabel", w * 0.5, h * 0.45, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    tabDiscovery.OnCursorEntered = function(self)
        if (self.nextHover <= CurTime()) then
            self.nextHover = CurTime() + 0.08
            surface.PlaySound(SOUND_HOVER)
        end
    end
    tabDiscovery.DoClick = function()
        SetTab("discovery")
        surface.PlaySound(SOUND_CLICK)
    end

    local tabFab = vgui.Create("DButton", tabBar)
    tabFab:Dock(LEFT)
    tabFab:SetWide(Scale(240))
    tabFab:SetText("")
    tabFab.nextHover = 0
    tabFab.Paint = function(self, w, h)
        local selected = (activeTab == "fabrication")
        local hovered = self:IsHovered()

        if (selected) then
            surface.SetDrawColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 25))
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(THEME.accent)
            surface.DrawRect(0, h - Scale(3), w, Scale(3))
        elseif (hovered) then
            surface.SetDrawColor(Color(255, 255, 255, 6))
            surface.DrawRect(0, 0, w, h)
        end

        local textCol = selected and THEME.accent or (hovered and THEME.text or THEME.textMuted)
        draw.SimpleText("BATCH FABRICATION", "ixMedTermLabel", w * 0.5, h * 0.45, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    tabFab.OnCursorEntered = function(self)
        if (self.nextHover <= CurTime()) then
            self.nextHover = CurTime() + 0.08
            surface.PlaySound(SOUND_HOVER)
        end
    end
    tabFab.DoClick = function()
        SetTab("fabrication")
        surface.PlaySound(SOUND_CLICK)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DISCOVERY PANEL
-- ═══════════════════════════════════════════════════════════════════════════════

function ix.bacta.BuildDiscoveryPanel(parent)
    local panel = vgui.Create("DPanel", parent)
    panel.Paint = function() end

    -- ─── Left column: Reagent pool + Sequence slots ────────────────────
    local leftCol = vgui.Create("DPanel", panel)
    leftCol:Dock(FILL)
    leftCol:DockMargin(0, 0, Scale(6), 0)
    leftCol.Paint = function() end

    -- Sequence slots panel (top of left column)
    local seqPanel = vgui.Create("DPanel", leftCol)
    seqPanel:Dock(TOP)
    seqPanel:SetTall(Scale(130))
    seqPanel:DockMargin(0, 0, 0, Scale(4))
    seqPanel.Paint = function(self, w, h)
        DrawDataPanelBg(self, w, h, "COMPOUND SEQUENCE", "STRAND ARRAY")

        -- Stability readout at bottom
        local stab = PreviewStability()
        local stabCol = StabilityColor(stab)
        local barY = h - Scale(16)
        local barX = Scale(8)
        local barW = w - Scale(16)
        local barH = Scale(8)

        surface.SetDrawColor(THEME.slotEmpty)
        surface.DrawRect(barX, barY, barW, barH)

        local fillW = math.ceil((stab / 100) * barW)
        surface.SetDrawColor(stabCol)
        surface.DrawRect(barX, barY, fillW, barH)

        -- Threshold markers
        local thresholds = ix.bacta.Config.STABILITY_THRESHOLDS
        for _, t in ipairs({thresholds.severe, thresholds.minor, thresholds.clean}) do
            local x = math.Round(barX + ((t / 100) * barW))
            surface.SetDrawColor(Color(0, 0, 0, 150))
            surface.DrawRect(x, barY, Scale(1), barH)
        end

        draw.SimpleText("INTEGRITY: " .. stab .. "%", "ixMedTermDiag", barX, barY - Scale(12), stabCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    -- Slot container inside sequence panel
    local slotContainer = vgui.Create("DPanel", seqPanel)
    slotContainer:Dock(FILL)
    slotContainer:DockMargin(Scale(8), Scale(28), Scale(8), Scale(28))
    slotContainer.Paint = function() end

    ix.bacta.sequenceSlots = {}

    for i = 1, ix.bacta.Config.MAX_SEQUENCE_LENGTH do
        local slot = vgui.Create("DButton", slotContainer)
        slot:Dock(LEFT)
        slot:DockMargin(Scale(2), 0, Scale(2), 0)
        slot:SetText("")
        slot.slotIndex = i

        slot.Paint = function(self, w, h)
            local strandID = sequence[i]
            local strand = strandID and ix.bacta.GetStrand(strandID)

            if (strand) then
                local catInfo = ix.bacta.CategoryInfo[strand.category]
                local col = catInfo and catInfo.color or THEME.accent

                -- Filled slot
                surface.SetDrawColor(THEME.slotFilled)
                surface.DrawRect(0, 0, w, h)

                -- Category color indicator at top
                surface.SetDrawColor(col)
                surface.DrawRect(Scale(3), Scale(2), w - Scale(6), Scale(3))

                -- Border glow
                surface.SetDrawColor(Color(col.r, col.g, col.b, 60))
                surface.DrawOutlinedRect(0, 0, w, h)

                -- Strand name
                local name = strand.name or strand.id
                if (#name > 14) then
                    name = string.sub(name, 1, 12) .. ".."
                end
                draw.SimpleText(name, "ixMedTermMonoSm", w * 0.5, h * 0.5 - Scale(2), THEME.textBright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                -- Slot index
                draw.SimpleText("#" .. i, "ixMedTermMonoSm", w * 0.5, h - Scale(8), THEME.textMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                -- Arrow between slots
                if (i < #sequence and i < ix.bacta.Config.MAX_SEQUENCE_LENGTH) then
                    draw.SimpleText(">", "ixMedTermAurebesh", w + Scale(1), h * 0.5, THEME.textMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            else
                -- Empty slot
                surface.SetDrawColor(THEME.slotEmpty)
                surface.DrawRect(0, 0, w, h)

                if (self:IsHovered()) then
                    surface.SetDrawColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 12))
                    surface.DrawRect(1, 1, w - 2, h - 2)
                    surface.SetDrawColor(THEME.border)
                    surface.DrawOutlinedRect(0, 0, w, h)
                end

                draw.SimpleText("[" .. i .. "]", "ixMedTermMonoSm", w * 0.5, h * 0.5, Color(60, 65, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        slot.DoClick = function(self)
            if (sequence[i]) then
                table.remove(sequence, i)
                surface.PlaySound(SOUND_CLICK)
            end
        end

        slot.OnCursorEntered = function(self)
            local strandID = sequence[i]
            if (strandID) then
                ix.bacta.ShowStrandTooltip(self, strandID)
            end
        end

        slot.OnCursorExited = function(self)
            ix.bacta.HideStrandTooltip()
        end

        ix.bacta.sequenceSlots[i] = slot
    end

    slotContainer.PerformLayout = function(self, w, h)
        local count = #ix.bacta.sequenceSlots
        local slotW = math.floor((w - (count - 1) * Scale(4)) / count)
        for _, s in ipairs(ix.bacta.sequenceSlots) do
            s:SetWide(slotW)
        end
    end

    -- Reagent strand pool (main body of left column)
    local poolPanel = vgui.Create("DPanel", leftCol)
    poolPanel:Dock(FILL)
    poolPanel.Paint = function(self, w, h)
        DrawDataPanelBg(self, w, h, "REAGENT STRAND LIBRARY", "COMPOUNDS")
    end

    local poolScroll = vgui.Create("DScrollPanel", poolPanel)
    poolScroll:Dock(FILL)
    poolScroll:DockMargin(Scale(6), Scale(28), Scale(6), Scale(6))
    poolScroll.Paint = function() end
    StyleScrollbar(poolScroll)

    -- Populate strand pool by category
    local categoryOrder = {"base", "active", "stabiliser", "metaboliser", "catalyst", "modifier", "tuning"}

    for _, cat in ipairs(categoryOrder) do
        local strandIDs = sessionPool[cat]
        if (!strandIDs or #strandIDs == 0) then continue end

        local catInfo = ix.bacta.CategoryInfo[cat]
        if (!catInfo) then
            catInfo = {
                name = cat,
                desc = "",
                color = Color(120, 120, 120),
            }
        end

        -- Category header
        local header = vgui.Create("DPanel", poolScroll)
        header:Dock(TOP)
        header:SetTall(Scale(22))
        header:DockMargin(0, Scale(4), 0, Scale(2))
        header.Paint = function(self, w, h)
            -- Category bar background
            surface.SetDrawColor(Color(catInfo.color.r, catInfo.color.g, catInfo.color.b, 15))
            surface.DrawRect(0, 0, w, h)

            -- Left accent bar
            surface.SetDrawColor(catInfo.color)
            surface.DrawRect(0, 0, Scale(3), h)

            draw.SimpleText(string.upper(catInfo.name), "ixMedTermLabel", Scale(10), h * 0.5, catInfo.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(catInfo.desc, "ixMedTermMonoSm", w - Scale(6), h * 0.5, THEME.textMuted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        -- Strand buttons
        for _, strandID in ipairs(strandIDs) do
            local strand = ix.bacta.GetStrand(strandID)
            if (!strand) then continue end

            local btn = vgui.Create("DButton", poolScroll)
            btn:Dock(TOP)
            btn:SetTall(Scale(36))
            btn:DockMargin(0, Scale(1), 0, Scale(1))
            btn:SetText("")
            btn.strandID = strandID
            btn.nextHover = 0

            btn.Paint = function(self, w, h)
                local inSeq = InSequence(strandID)
                local canAdd, _ = CanAddStrand(strandID)

                -- Background
                local bgCol = THEME.panel
                if (inSeq) then
                    bgCol = Color(catInfo.color.r, catInfo.color.g, catInfo.color.b, 20)
                elseif (self:IsHovered() and canAdd) then
                    bgCol = THEME.buttonHover
                end

                surface.SetDrawColor(bgCol)
                surface.DrawRect(0, 0, w, h)

                -- Category color bar
                surface.SetDrawColor(inSeq and THEME.textMuted or catInfo.color)
                surface.DrawRect(0, 0, Scale(3), h)

                -- Subtle hover border
                if (self:IsHovered() and !inSeq) then
                    surface.SetDrawColor(THEME.border)
                    surface.DrawOutlinedRect(0, 0, w, h)
                end

                -- Name
                local textCol = inSeq and THEME.textMuted or THEME.text
                draw.SimpleText(strand.name, "ixMedTermMono", Scale(10), Scale(6), textCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                -- Effect summary
                local effectStr = ""
                for j, eff in ipairs(strand.effects or {}) do
                    if (j > 1) then effectStr = effectStr .. "  |  " end
                    effectStr = effectStr .. ix.bacta.EffectToString(eff)
                end
                if (strand.special) then
                    effectStr = effectStr .. (effectStr != "" and "  |  " or "") .. "[" .. string.upper(strand.special.type) .. "]"
                end
                if (strand.catalyst_effect) then
                    effectStr = effectStr .. (effectStr != "" and "  |  " or "") .. "[CAT:" .. string.upper(strand.catalyst_effect.type) .. "]"
                end
                if (strand.modifier_effect) then
                    effectStr = effectStr .. (effectStr != "" and "  |  " or "") .. "[MOD:" .. string.upper(strand.modifier_effect.type) .. "]"
                end
                draw.SimpleText(effectStr, "ixMedTermMonoSm", Scale(10), Scale(20), THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                -- Cost weight
                local weightText = "W:" .. strand.cost_weight
                surface.SetFont("ixMedTermMonoSm")
                local ww, wh = surface.GetTextSize(weightText)
                local weightX = w - Scale(12) - ww
                
                surface.SetDrawColor(Color(255, 255, 255, 10))
                surface.DrawRect(weightX - Scale(8), Scale(8), Scale(1), h - Scale(16))

                draw.SimpleText(weightText, "ixMedTermMonoSm", w - Scale(12), h * 0.5, THEME.textMuted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

                -- In-sequence indicator
                if (inSeq) then
                    draw.SimpleText("LOADED", "ixMedTermDiag", weightX - Scale(16), h * 0.5, catInfo.color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
            end

            btn.DoClick = function(self)
                if (InSequence(strandID)) then
                    for k, id in ipairs(sequence) do
                        if (id == strandID) then
                            table.remove(sequence, k)
                            break
                        end
                    end
                    surface.PlaySound(SOUND_CLICK)
                else
                    local canAdd, reason = CanAddStrand(strandID)
                    if (canAdd) then
                        sequence[#sequence + 1] = strandID
                        surface.PlaySound(SOUND_CLICK)
                    else
                        surface.PlaySound(SOUND_ERROR)
                    end
                end
            end

            btn.OnCursorEntered = function(self)
                if (self.nextHover <= CurTime()) then
                    self.nextHover = CurTime() + 0.08
                    surface.PlaySound(SOUND_HOVER)
                end
                ix.bacta.ShowStrandTooltip(self, strandID)
            end

            btn.OnCursorExited = function(self)
                ix.bacta.HideStrandTooltip()
            end
        end
    end

    -- ─── Right column: Diagnostics + Predicted effects + Actions ───────
    local rightCol = vgui.Create("DPanel", panel)
    rightCol:Dock(RIGHT)
    rightCol:SetWide(Scale(280))
    rightCol.Paint = function() end

    local function BuildPredictedEffectLines()
        if (#sequence == 0) then
            return {
                {text = "AWAITING STRAND INPUT", color = THEME.textMuted, font = "ixMedTermDiag"},
                {text = "Load reagents to begin analysis", color = THEME.textMuted, font = "ixMedTermMonoSm"},
            }
        end

        local lines = {}
        local itemType = ix.bacta.DetermineItemType(sequence)
        lines[#lines + 1] = {text = "TYPE: " .. string.upper(itemType), color = THEME.accent, font = "ixMedTermDiag"}

        local uses = ix.bacta.DetermineUses(sequence)
        if (uses > 1) then
            lines[#lines + 1] = {text = "USES: " .. uses, color = THEME.accent, font = "ixMedTermDiag"}
        end

        local shownEffects = {}
        for _, strandID in ipairs(sequence) do
            local strand = ix.bacta.GetStrand(strandID)
            if (!strand) then continue end
            for _, eff in ipairs(strand.effects or {}) do
                shownEffects[#shownEffects + 1] = eff
            end
            if (strand.modifier_effect and strand.modifier_effect.type == "add_effect" and strand.modifier_effect.effect) then
                shownEffects[#shownEffects + 1] = strand.modifier_effect.effect
            end
        end

        for _, eff in ipairs(shownEffects) do
            local et = ix.bacta.effectTypes[eff.type]
            local col = (et and et.color) or THEME.text
            local isSide = ix.bacta.IsSideEffect(eff.type)
            local isTail = ix.bacta.IsTailEffect and ix.bacta.IsTailEffect(eff.type) or false
            local prefix
            if (isTail) then
                prefix = "⏱ "
                col = THEME.tail
            elseif (isSide) then
                prefix = "⚠ "
            else
                prefix = "▸ "
            end
            lines[#lines + 1] = {text = prefix .. ix.bacta.EffectToString(eff), color = col, font = "ixMedTermMonoSm"}
        end

        -- Show metaboliser status
        local metCount = 0
        local tailCount = 0
        for _, strandID in ipairs(sequence) do
            local strand = ix.bacta.GetStrand(strandID)
            if (strand and ix.bacta.IsMetaboliser and ix.bacta.IsMetaboliser(strandID)) then
                metCount = metCount + 1
            end
            if (strand) then
                for _, eff in ipairs(strand.effects or {}) do
                    if (eff.tail_effect) then tailCount = tailCount + 1 end
                end
            end
        end
        if (tailCount > 0) then
            lines[#lines + 1] = {text = "TAILS: " .. tailCount .. (metCount > 0 and " (" .. metCount .. " MET)" or ""), color = THEME.tail, font = "ixMedTermDiag"}
        end

        return lines
    end

    -- Diagnostics panel (animated medical readout)
    local diagPanel = vgui.Create("DPanel", rightCol)
    diagPanel:Dock(FILL)
    diagPanel:DockMargin(0, 0, 0, Scale(4))
    diagPanel.Paint = function(self, w, h)
        DrawMedicalDiagnostics(self, w, h, "SYNTHESIS MONITOR", BuildPredictedEffectLines)
    end

    -- Action buttons panel
    local actionsPanel = vgui.Create("DPanel", rightCol)
    actionsPanel:Dock(BOTTOM)
    actionsPanel:SetTall(Scale(120))
    actionsPanel.Paint = function() end

    -- Synthesize button
    local synthBtn = vgui.Create("ixMedTermButton", actionsPanel)
    synthBtn:Dock(TOP)
    synthBtn:SetTall(Scale(40))
    synthBtn:DockMargin(0, 0, 0, Scale(6))
    synthBtn:SetLabel("▶ INITIATE SYNTHESIS")
    synthBtn:SetStyle("accent")
    synthBtn.DoClick = function()
        if (CountCategory("base") != 1 or #sequence == 0) then
            surface.PlaySound(SOUND_ERROR)
            return
        end

        net.Start("ixBactaSubmit")
            net.WriteTable(sequence)
        net.SendToServer()

        surface.PlaySound(SOUND_SYNTH)
    end

    -- Clear button
    local clearBtn = vgui.Create("ixMedTermButton", actionsPanel)
    clearBtn:Dock(TOP)
    clearBtn:SetTall(Scale(36))
    clearBtn:SetLabel("PURGE SEQUENCE")
    clearBtn:SetStyle("danger")
    clearBtn.DoClick = function()
        sequence = {}
        lastResult = nil
        surface.PlaySound(SOUND_CLICK)
    end

    -- v2.0: Pool Influence button
    local influenceBtn = vgui.Create("ixMedTermButton", actionsPanel)
    influenceBtn:Dock(TOP)
    influenceBtn:SetTall(Scale(28))
    influenceBtn:DockMargin(0, Scale(6), 0, 0)
    influenceBtn:SetLabel("POOL INFLUENCE (" .. (ix.bacta.Config.POOL_INFLUENCE_COST or 25) .. " SGC)")
    influenceBtn.DoClick = function()
        if (poolInfluenceUsed) then
            surface.PlaySound(SOUND_ERROR)
            return
        end

        Derma_StringRequest(
            "Pool Influence",
            "Enter the exact strand ID to add to your session pool.\nCost: " .. (ix.bacta.Config.POOL_INFLUENCE_COST or 25) .. " SGC (once per session).",
            "",
            function(strandID)
                if (!strandID or strandID == "") then return end

                net.Start("ixBactaPoolInfluence")
                    net.WriteString(strandID)
                net.SendToServer()

                poolInfluenceUsed = true
            end,
            function() end,
            "Influence",
            "Cancel"
        )
    end

    return panel
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- FABRICATION PANEL
-- ═══════════════════════════════════════════════════════════════════════════════

function ix.bacta.BuildFabricationPanel(parent)
    local panel = vgui.Create("DPanel", parent)
    panel.Paint = function() end

    -- ─── Left: Canister list ─────────────────────────────────────────────
    local listOuter = vgui.Create("DPanel", panel)
    listOuter:Dock(LEFT)
    listOuter:SetWide(Scale(340))
    listOuter:DockMargin(0, 0, Scale(6), 0)
    listOuter.Paint = function(self, w, h)
        DrawDataPanelBg(self, w, h, "FORMULA CANISTERS", "INVENTORY")
    end

    local listScroll = vgui.Create("DScrollPanel", listOuter)
    listScroll:Dock(FILL)
    listScroll:DockMargin(Scale(6), Scale(28), Scale(6), Scale(6))
    listScroll.Paint = function() end
    StyleScrollbar(listScroll)

    ix.bacta.fabricationList = listScroll

    -- ─── Right: Details + Diagnostics ──────────────────────────────────
    local rightArea = vgui.Create("DPanel", panel)
    rightArea:Dock(FILL)
    rightArea.Paint = function() end

    -- Diagnostics readout at top-right
    local diagPanel = vgui.Create("DPanel", rightArea)
    diagPanel:Dock(TOP)
    diagPanel:SetTall(Scale(180))
    diagPanel:DockMargin(0, 0, 0, Scale(4))
    diagPanel.Paint = function(self, w, h)
        DrawMedicalDiagnostics(self, w, h, "FABRICATION MONITOR")
    end

    -- Recipe detail panel
    local detailPanel = vgui.Create("DPanel", rightArea)
    detailPanel:Dock(FILL)
    detailPanel.Paint = function(self, w, h)
        DrawDataPanelBg(self, w, h, "COMPOUND ANALYSIS", "DETAIL")

        if (!self.__hasContent) then
            draw.SimpleText("SELECT A PROTOCOL", "ixMedTermDiag", w * 0.5, h * 0.4, THEME.textMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("to view compound detail", "ixMedTermMonoSm", w * 0.5, h * 0.4 + Scale(16), THEME.textMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    ix.bacta.fabricationDetail = detailPanel

    -- Populate
    local selectedCanister = nil

    function ix.bacta.PopulateFabricationList()
        listScroll:Clear()
        selectedCanister = nil
        detailPanel.__hasContent = false

        if (!sessionCanisters or #sessionCanisters == 0) then
            local emptyLabel = vgui.Create("DPanel", listScroll)
            emptyLabel:Dock(TOP)
            emptyLabel:SetTall(Scale(60))
            emptyLabel.Paint = function(self, w, h)
                draw.SimpleText("NO FORMULA CANISTERS", "ixMedTermDiag", w * 0.5, h * 0.35, THEME.textMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("Register a formula to create one", "ixMedTermMonoSm", w * 0.5, h * 0.65, THEME.textMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            return
        end

        for _, canister in ipairs(sessionCanisters) do
            local btn = vgui.Create("DButton", listScroll)
            btn:Dock(TOP)
            btn:SetTall(Scale(60))
            btn:DockMargin(0, 0, 0, Scale(2))
            btn:SetText("")
            btn.canisterID = canister.id
            btn.nextHover = 0

            btn.Paint = function(self, w, h)
                local isSelected = (selectedCanister == canister.id)
                local hovered = self:IsHovered()

                -- Background
                local bgCol = THEME.panel
                if (isSelected) then
                    bgCol = Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, 20)
                elseif (hovered) then
                    bgCol = THEME.buttonHover
                end

                surface.SetDrawColor(bgCol)
                surface.DrawRect(0, 0, w, h)

                -- Selected indicator
                if (isSelected) then
                    surface.SetDrawColor(THEME.accent)
                    surface.DrawRect(0, 0, Scale(3), h)
                end

                -- Hover border
                if (hovered and !isSelected) then
                    surface.SetDrawColor(THEME.border)
                    surface.DrawOutlinedRect(0, 0, w, h)
                end

                -- Name
                draw.SimpleText(canister.name or "Unnamed", "ixMedTermMono", Scale(10), Scale(4), isSelected and THEME.textBright or THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                -- Status badge
                local status = canister.status or "experimental"
                local statusCol = THEME[status] or THEME.textMuted
                draw.SimpleText("[" .. string.upper(status) .. "]", "ixMedTermDiag", Scale(10), Scale(20), statusCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                -- Durability bar
                local dur = canister.durability or 100
                local barX = Scale(10)
                local barY = Scale(38)
                local barW = w - Scale(20)
                local barH = Scale(4)
                surface.SetDrawColor(THEME.slotEmpty)
                surface.DrawRect(barX, barY, barW, barH)
                local durCol = dur > 25 and THEME.accent or THEME.danger
                surface.SetDrawColor(durCol)
                surface.DrawRect(barX, barY, barW * (dur / 100), barH)
                draw.SimpleText("DUR: " .. dur .. "%", "ixMedTermMonoSm", barX, barY + Scale(6), THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                -- Stability on the right
                local stabVal = canister.stability or 0
                draw.SimpleText(stabVal .. "%", "ixMedTermDiag", w - Scale(8), Scale(4), StabilityColor(stabVal), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

                -- Test count
                draw.SimpleText("Tests: " .. (canister.test_count or 0), "ixMedTermMonoSm", w - Scale(8), Scale(20), THEME.textMuted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

                -- Bottom separator
                surface.SetDrawColor(THEME.border)
                surface.DrawLine(Scale(8), h - 1, w - Scale(8), h - 1)
            end

            btn.OnCursorEntered = function(self)
                if (self.nextHover <= CurTime()) then
                    self.nextHover = CurTime() + 0.08
                    surface.PlaySound(SOUND_HOVER)
                end
            end

            btn.DoClick = function(self)
                selectedCanister = canister.id
                ix.bacta.ShowCanisterDetail(canister)
                surface.PlaySound(SOUND_CLICK)
            end
        end
    end

    function ix.bacta.ShowCanisterDetail(canister)
        detailPanel:Clear()
        detailPanel.__hasContent = true

        if (!canister) then return end

        local info = vgui.Create("DPanel", detailPanel)
        info:Dock(FILL)
        info:DockMargin(Scale(8), Scale(30), Scale(8), Scale(8))
        info.Paint = function(self, w, h)
            local y = 0

            -- Compound name
            draw.SimpleText(canister.name or "Unknown", "ixMedTermHeader", 0, y, THEME.textBright)
            y = y + Scale(22)

            -- Status badge
            local status = canister.status or "experimental"
            local statusCol = THEME[status] or THEME.textMuted
            draw.SimpleText("STATUS: " .. string.upper(status), "ixMedTermLabel", 0, y, statusCol)
            y = y + Scale(16)

            -- Type + Uses
            draw.SimpleText("TYPE: " .. string.upper(canister.item_type or "injector") .. "    USES: " .. (canister.uses or 1), "ixMedTermLabel", 0, y, THEME.accent)
            y = y + Scale(16)

            -- Integrity + Durability
            local stabVal = canister.stability or 0
            draw.SimpleText("INTEGRITY: " .. stabVal .. "/100", "ixMedTermLabel", 0, y, StabilityColor(stabVal))
            y = y + Scale(16)

            local dur = canister.durability or 100
            local durCol = dur > 25 and THEME.accent or THEME.danger
            draw.SimpleText("DURABILITY: " .. dur .. "/100", "ixMedTermLabel", 0, y, durCol)
            y = y + Scale(16)

            -- Chain metrics
            if (canister.chainDepth and canister.chainDepth > 0) then
                draw.SimpleText("CHAIN DEPTH: " .. canister.chainDepth .. "   PURITY: " .. math.Round((canister.chainPurity or 1) * 100) .. "%", "ixMedTermDiag", 0, y, THEME.tuning)
                y = y + Scale(14)
            end

            -- Cost
            local cost = canister.cost_base or 0
            draw.SimpleText("PRODUCTION: " .. cost .. " SGC  (" .. ix.bacta.Config.BATCH_SIZE .. " units/batch)", "ixMedTermDiag", 0, y, THEME.textMuted)
            y = y + Scale(20)

            -- Separator
            surface.SetDrawColor(THEME.border)
            surface.DrawLine(0, y, w, y)
            y = y + Scale(8)

            -- Sequence
            draw.SimpleText("STRAND SEQUENCE:", "ixMedTermDiag", 0, y, THEME.textMuted)
            y = y + Scale(14)

            for i, strandID in ipairs(canister.sequence or {}) do
                local strand = ix.bacta.GetStrand(strandID)
                local catInfo = strand and ix.bacta.CategoryInfo[strand.category]
                local col = catInfo and catInfo.color or THEME.text

                draw.SimpleText(i .. ".  " .. (strand and strand.name or strandID), "ixMedTermMono", Scale(4), y, col)
                y = y + Scale(14)
            end

            y = y + Scale(8)

            -- Effects
            surface.SetDrawColor(THEME.border)
            surface.DrawLine(0, y, w, y)
            y = y + Scale(8)

            draw.SimpleText("BIOCHEMICAL RESPONSE PROFILE:", "ixMedTermDiag", 0, y, THEME.textMuted)
            y = y + Scale(14)

            for _, eff in ipairs(canister.effects or {}) do
                if (y > h - Scale(14)) then
                    draw.SimpleText("...", "ixMedTermMono", Scale(4), y, THEME.textMuted)
                    break
                end

                local et = ix.bacta.effectTypes[eff.type]
                local col = (et and et.color) or THEME.text
                local isSide = ix.bacta.IsSideEffect(eff.type)
                local isTail = ix.bacta.IsTailEffect and ix.bacta.IsTailEffect(eff.type) or false
                local prefix
                if (isTail) then
                    prefix = "⏱ "
                    col = THEME.tail
                elseif (isSide) then
                    prefix = "⚠ "
                else
                    prefix = "▸ "
                end

                draw.SimpleText(prefix .. ix.bacta.EffectToString(eff), "ixMedTermMono", Scale(4), y, col)
                y = y + Scale(14)
            end
        end

        -- Fabricate button
        local fabBtn = vgui.Create("ixMedTermButton", detailPanel)
        fabBtn:Dock(BOTTOM)
        fabBtn:SetTall(Scale(40))
        fabBtn:DockMargin(Scale(8), Scale(4), Scale(8), Scale(8))
        fabBtn:SetLabel("▶ FABRICATE BATCH (" .. (canister.cost_base or "?") .. " SGC)")
        fabBtn:SetStyle("success")
        fabBtn:SetDisabled((canister.durability or 100) <= 0)
        fabBtn.DoClick = function()
            if (!selectedCanister) then return end

            local cost = canister.cost_base or 0
            if (sgcBalance < cost) then
                surface.PlaySound(SOUND_ERROR)
                return
            end

            net.Start("ixBactaFabricate")
                net.WriteUInt(selectedCanister, 32)
                net.WriteBool(false) -- not integrity-confirmed
            net.SendToServer()

            surface.PlaySound(SOUND_SYNTH)
        end

        -- Refine button
        local refineBtn = vgui.Create("ixMedTermButton", detailPanel)
        refineBtn:Dock(BOTTOM)
        refineBtn:SetTall(Scale(32))
        refineBtn:DockMargin(Scale(8), Scale(2), Scale(8), 0)
        local refineCost = (ix.bacta.Config.REFINEMENT or {}).cost or 15
        refineBtn:SetLabel("REFINE (" .. refineCost .. " SGC)")
        refineBtn.DoClick = function()
            if (!selectedCanister) then return end

            net.Start("ixBactaRefine")
                net.WriteUInt(selectedCanister, 32)
            net.SendToServer()

            surface.PlaySound(SOUND_CLICK)
        end
    end

    ix.bacta.PopulateFabricationList()

    return panel
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- RESULT PANEL (post-synthesis overlay)
-- ═══════════════════════════════════════════════════════════════════════════════

function ix.bacta.ShowResultPanel(result)
    if (!IsValid(ix.bacta.sequencerFrame)) then return end

    local frame = ix.bacta.sequencerFrame

    -- Full overlay
    local overlay = vgui.Create("DPanel", frame)
    overlay:SetPos(0, 0)
    overlay:SetSize(frame:GetWide(), frame:GetTall())
    overlay:MoveToFront()
    overlay.startTime = CurTime()
    overlay.Paint = function(self, w, h)
        -- Fade-in background
        local age = CurTime() - self.startTime
        local alpha = math.Clamp(age * 3, 0, 1) * 240

        surface.SetDrawColor(Color(4, 6, 8, alpha))
        surface.DrawRect(0, 0, w, h)

        -- Animated border flash
        if (age < 0.5) then
            local flash = (1 - age * 2) * 120
            surface.SetDrawColor(Color(THEME.accent.r, THEME.accent.g, THEME.accent.b, flash))
            surface.DrawOutlinedRect(Scale(10), Scale(10), w - Scale(20), h - Scale(20))
        end
    end

    local centerPanel = vgui.Create("DPanel", overlay)
    centerPanel:SetSize(Scale(500), Scale(520))
    centerPanel:Center()
    centerPanel.Paint = function(self, w, h)
        local headerH = Scale(32)

        -- Background
        surface.SetDrawColor(THEME.background)
        surface.DrawRect(0, 0, w, h)

        -- Header bar
        local isContaminated = result.contaminated
        local headerCol = isContaminated and THEME.danger or THEME.success
        surface.SetDrawColor(Color(headerCol.r, headerCol.g, headerCol.b, 120))
        surface.DrawRect(0, 0, w, headerH)

        -- Frame border
        surface.SetDrawColor(Color(headerCol.r, headerCol.g, headerCol.b, 80))
        surface.DrawOutlinedRect(0, 0, w, h)

        -- Title
        local title = isContaminated and "⚠ CONTAMINATED COMPOUND" or "✓ SYNTHESIS COMPLETE"
        draw.SimpleText(title, "ixMedTermHeader", w * 0.5, headerH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Aurebesh status decoration
        draw.SimpleText(isContaminated and "WARNING ALERT" or "COMPOUND VERIFIED", "ixMedTermAurebesh",
            w - Scale(8), headerH * 0.5, Color(0, 0, 0, 180), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        local y = headerH + Scale(12)
        local pad = Scale(16)

        -- Stability
        local stabCol = StabilityColor(result.stability or 0)
        draw.SimpleText("COMPOUND INTEGRITY: " .. (result.stability or "?") .. "/100", "ixMedTermLabel", pad, y, stabCol)
        y = y + Scale(16)

        -- Stability bar
        local barW = w - pad * 2
        local barH = Scale(6)
        surface.SetDrawColor(THEME.slotEmpty)
        surface.DrawRect(pad, y, barW, barH)
        surface.SetDrawColor(stabCol)
        surface.DrawRect(pad, y, barW * ((result.stability or 0) / 100), barH)
        y = y + Scale(14)

        -- Type + uses
        draw.SimpleText("TYPE: " .. string.upper(result.item_type or "injector") .. "    USES: " .. (result.uses or 1), "ixMedTermDiag", pad, y, THEME.accent)
        y = y + Scale(16)

        -- v2.1: Chain metrics
        if (result.chainDepth and result.chainDepth > 0) then
            draw.SimpleText("CHAIN DEPTH: " .. result.chainDepth .. "   PURITY: " .. math.Round((result.chainPurity or 1) * 100) .. "%", "ixMedTermDiag", pad, y, THEME.tuning)
            y = y + Scale(16)
        end

        -- Separator
        surface.SetDrawColor(THEME.border)
        surface.DrawLine(pad, y, w - pad, y)
        y = y + Scale(8)

        -- Effects header
        draw.SimpleText("BIOCHEMICAL RESPONSE PROFILE", "ixMedTermDiag", pad, y, THEME.textMuted)
        y = y + Scale(16)

        for _, eff in ipairs(result.effects or {}) do
            if (y > h - Scale(100)) then
                draw.SimpleText("...", "ixMedTermMono", pad, y, THEME.textMuted)
                break
            end

            local et = ix.bacta.effectTypes[eff.type]
            local col = (et and et.color) or THEME.text
            local isSide = ix.bacta.IsSideEffect(eff.type)
            local isTail = ix.bacta.IsTailEffect and ix.bacta.IsTailEffect(eff.type) or false
            local prefix
            if (isTail) then
                prefix = "⏱ "
                col = THEME.tail
            elseif (isSide) then
                prefix = "⚠ "
            else
                prefix = "▸ "
            end

            draw.SimpleText(prefix .. ix.bacta.EffectToString(eff), "ixMedTermMono", pad + Scale(4), y, col)
            y = y + Scale(14)
        end

        -- v2.2: Cascade summary
        local cs = result.cascadeSummary
        if (cs and cs.tails and #cs.tails > 0) then
            y = y + Scale(4)
            surface.SetDrawColor(THEME.border)
            surface.DrawLine(pad, y, w - pad, y)
            y = y + Scale(8)

            draw.SimpleText("METABOLIC CASCADE", "ixMedTermDiag", pad, y, THEME.tail)
            y = y + Scale(14)

            for _, tail in ipairs(cs.tails) do
                if (y > h - Scale(70)) then break end
                local statusStr = tail.resolved and "[RESOLVED]" or "[UNRESOLVED]"
                local tailType = ix.bacta.effectTypes[tail.tail_type]
                local tailName = tailType and tailType.name or tail.tail_type
                local tailCol = tail.resolved and THEME.success or THEME.danger
                draw.SimpleText(statusStr .. " " .. tailName .. " (delay: " .. (tail.delay or "?") .. "s)", "ixMedTermMonoSm", pad + Scale(4), y, tailCol)
                y = y + Scale(13)
            end

            if (cs.suppressed) then
                draw.SimpleText("[ALL TAILS SUPPRESSED]", "ixMedTermDiag", pad + Scale(4), y, THEME.success)
            end
        end

        -- v2.0: Flags
        if (result.flags) then
            local fLines = {}
            if (result.flags.criticalThreshold) then
                fLines[#fLines + 1] = "CRIT THRESHOLD: HP <=" .. math.Round(result.flags.criticalThreshold * 100) .. "%"
            end
            if (result.flags.stackBypass) then
                fLines[#fLines + 1] = "STACK BYPASS: YES"
            end
            if (#fLines > 0 and y < h - Scale(50)) then
                y = y + Scale(8)
                for _, fl in ipairs(fLines) do
                    draw.SimpleText(fl, "ixMedTermDiag", pad + Scale(4), y, THEME.tuning)
                    y = y + Scale(13)
                end
            end
        end
    end

    -- Register Formula button (only if not contaminated)
    if (!result.contaminated and result.sequence) then
        local regBtn = vgui.Create("ixMedTermButton", centerPanel)
        regBtn:SetSize(Scale(210), Scale(36))
        regBtn:SetPos(Scale(16), Scale(520) - Scale(52))
        regBtn:SetLabel("REGISTER FORMULA")
        regBtn:SetStyle("accent")
        regBtn.DoClick = function()
            Derma_StringRequest(
                "Register Compound Protocol",
                "Enter a designation for this formula:",
                "",
                function(name)
                    if (!name or name == "") then return end

                    net.Start("ixBactaRegister")
                        net.WriteString(name)
                        net.WriteTable(result.sequence)
                    net.SendToServer()

                    if (IsValid(overlay)) then overlay:Remove() end
                end,
                function() end,
                "Register",
                "Cancel"
            )
        end
    end

    -- Close button
    local closeBtn = vgui.Create("ixMedTermButton", centerPanel)
    closeBtn:SetSize(Scale(210), Scale(36))
    closeBtn:SetPos(Scale(500) - Scale(226), Scale(520) - Scale(52))
    closeBtn:SetLabel("DISMISS")
    closeBtn:SetStyle("danger")
    closeBtn.DoClick = function()
        overlay:Remove()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TOOLTIP SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

local tooltipPanel = nil

function ix.bacta.ShowStrandTooltip(anchor, strandID)
    local strand = ix.bacta.GetStrand(strandID)
    if (!strand) then return end

    ix.bacta.HideStrandTooltip()

    local panelW = Scale(280)
    local tip = vgui.Create("DPanel")
    tip:SetSize(panelW, 0)
    tip:SetDrawOnTop(true)
    tip.strand = strand

    -- Helper function to wrap text to fit panel width
    local function WrapTextLine(text, font, availWidth)
        if (!text or text == "") then return {text} end
        
        surface.SetFont(font)
        local textW = surface.GetTextSize(text)
        
        -- Text fits on one line
        if (textW <= availWidth) then
            return {text}
        end
        
        -- Need to wrap - use ix.util.WrapText if available, otherwise manual wrap
        if (ix.util and ix.util.WrapText) then
            return ix.util.WrapText(text, availWidth, font)
        end
        
        -- Fallback: simple word-wrap
        local words = string.Explode(" ", text)
        local lines = {}
        local currentLine = ""
        
        for _, word in ipairs(words) do
            local testLine = (currentLine == "" and word) or (currentLine .. " " .. word)
            local tw = surface.GetTextSize(testLine)
            
            if (tw > availWidth and currentLine != "") then
                lines[#lines + 1] = currentLine
                currentLine = word
            else
                currentLine = testLine
            end
        end
        
        if (currentLine != "") then
            lines[#lines + 1] = currentLine
        end
        
        return lines
    end

    local lines = {}
    local contentPadding = Scale(8)
    local availWidth = panelW - contentPadding * 2
    
    -- Title
    local titleLines = WrapTextLine(strand.name, "ixMedTermHeader", availWidth)
    for _, line in ipairs(titleLines) do
        lines[#lines + 1] = {text = line, color = THEME.textBright, font = "ixMedTermHeader", height = Scale(20)}
    end

    -- Category
    local catInfo = ix.bacta.CategoryInfo[strand.category]
    if (catInfo) then
        lines[#lines + 1] = {text = string.upper(catInfo.name), color = catInfo.color, font = "ixMedTermDiag", height = Scale(14)}
    end

    lines[#lines + 1] = {text = "", height = Scale(4)}

    -- Description with wrapping
    if (strand.description and strand.description != "") then
        local descLines = WrapTextLine(strand.description, "ixMedTermMonoSm", availWidth)
        for _, line in ipairs(descLines) do
            lines[#lines + 1] = {text = line, color = THEME.textMuted, font = "ixMedTermMonoSm", height = Scale(14)}
        end
        lines[#lines + 1] = {text = "", height = Scale(4)}
    end

    -- Effects
    for _, eff in ipairs(strand.effects or {}) do
        local et = ix.bacta.effectTypes[eff.type]
        local effectStr = "▸ " .. ix.bacta.EffectToString(eff)
        local effectLines = WrapTextLine(effectStr, "ixMedTermMono", availWidth)
        for _, line in ipairs(effectLines) do
            lines[#lines + 1] = {text = line, color = et and et.color or THEME.text, font = "ixMedTermMono", height = Scale(14)}
        end
    end

    -- v2.0: Tail effect info
    if (strand.tail_effect) then
        local tailType = ix.bacta.effectTypes[strand.tail_effect]
        local tailName = tailType and tailType.name or strand.tail_effect
        if (type(tailName) == "table") then
            tailName = tailName.name or tailName.label or "UNKNOWN"
        end
        local tailStr = "⏱ TAIL: " .. tailName .. " (delay: " .. (strand.tail_delay or "?") .. "s)"
        local tailLines = WrapTextLine(tailStr, "ixMedTermMonoSm", availWidth)
        for _, line in ipairs(tailLines) do
            lines[#lines + 1] = {text = line, color = THEME.tail, font = "ixMedTermMonoSm", height = Scale(14)}
        end
    end

    if (strand.special) then
        lines[#lines + 1] = {text = "SPECIAL: " .. strand.special.type, color = THEME.success, font = "ixMedTermDiag", height = Scale(13)}
    end

    if (strand.catalyst_effect) then
        lines[#lines + 1] = {text = "CATALYST: " .. strand.catalyst_effect.type, color = THEME.warning, font = "ixMedTermDiag", height = Scale(13)}
    end

    if (strand.modifier_effect) then
        lines[#lines + 1] = {text = "MODIFIER: " .. strand.modifier_effect.type, color = THEME.tuning, font = "ixMedTermDiag", height = Scale(13)}
    end

    -- v2.0: Metaboliser info
    if (strand.metabolises) then
        lines[#lines + 1] = {text = "METABOLISES: " .. strand.metabolises, color = THEME.metaboliser, font = "ixMedTermDiag", height = Scale(13)}
    end
    if (strand.met_tail) then
        local tailType = ix.bacta.effectTypes[strand.met_tail]
        local tailName = tailType and tailType.name or strand.met_tail
        if (type(tailName) == "table") then
            tailName = tailName.name or tailName.label or "UNKNOWN"
        end
        lines[#lines + 1] = {text = "RESOLVES: " .. tailName, color = THEME.metaboliser, font = "ixMedTermMonoSm", height = Scale(13)}
    end

    -- v2.1: Tuning info
    if (strand.tuning_effect) then
        lines[#lines + 1] = {text = "TUNING: " .. strand.tuning_effect.type, color = THEME.tuning, font = "ixMedTermDiag", height = Scale(13)}
        if (strand.tuning_effect.target) then
            lines[#lines + 1] = {text = "TARGET: " .. strand.tuning_effect.target, color = THEME.tuning, font = "ixMedTermMonoSm", height = Scale(13)}
        end
    end

    lines[#lines + 1] = {text = "", height = Scale(4)}

    -- Stats
    lines[#lines + 1] = {text = "COST WEIGHT: " .. strand.cost_weight, color = THEME.textMuted, font = "ixMedTermMonoSm", height = Scale(13)}
    lines[#lines + 1] = {text = "STABILITY: " .. (strand.stability_mod >= 0 and "+" or "") .. strand.stability_mod, color = strand.stability_mod >= 0 and THEME.success or THEME.danger, font = "ixMedTermMonoSm", height = Scale(13)}

    if (strand.potency_mod and strand.potency_mod != 1.0) then
        lines[#lines + 1] = {text = "POTENCY: x" .. strand.potency_mod, color = THEME.warning, font = "ixMedTermMonoSm", height = Scale(13)}
    end

    -- Adjacency
    if (strand.adjacency) then
        if (#(strand.adjacency.bonus or {}) > 0) then
            local bonusNames = {}
            for _, id in ipairs(strand.adjacency.bonus) do
                local s = ix.bacta.GetStrand(id)
                bonusNames[#bonusNames + 1] = s and s.name or id
            end
            local bonusStr = "RESONANCE+: " .. table.concat(bonusNames, ", ")
            local bonusLines = WrapTextLine(bonusStr, "ixMedTermMonoSm", availWidth)
            for _, line in ipairs(bonusLines) do
                lines[#lines + 1] = {text = line, color = THEME.success, font = "ixMedTermMonoSm", height = Scale(13)}
            end
        end

        if (#(strand.adjacency.penalty or {}) > 0) then
            local penNames = {}
            for _, id in ipairs(strand.adjacency.penalty) do
                local s = ix.bacta.GetStrand(id)
                penNames[#penNames + 1] = s and s.name or id
            end
            local penStr = "RESONANCE-: " .. table.concat(penNames, ", ")
            local penLines = WrapTextLine(penStr, "ixMedTermMonoSm", availWidth)
            for _, line in ipairs(penLines) do
                lines[#lines + 1] = {text = line, color = THEME.danger, font = "ixMedTermMonoSm", height = Scale(13)}
            end
        end
    end

    local totalH = Scale(12)
    for _, line in ipairs(lines) do
        totalH = totalH + (line.height or Scale(14))
    end

    tip:SetTall(totalH + Scale(8))

    tip.Paint = function(self, w, h)
        -- Double-border tooltip
        surface.SetDrawColor(THEME.background)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(THEME.frameSoft)
        surface.DrawOutlinedRect(0, 0, w, h)
        surface.SetDrawColor(THEME.border)
        surface.DrawOutlinedRect(1, 1, w - 2, h - 2)

        -- Tiny header accent
        surface.SetDrawColor(THEME.accent)
        surface.DrawRect(0, 0, w, Scale(2))

        local y = Scale(6)
        for _, line in ipairs(lines) do
            if (line.text and line.text != "") then
                draw.SimpleText(line.text, line.font or "ixMedTermMono", contentPadding, y, line.color or THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
            y = y + (line.height or Scale(14))
        end
    end

    -- Position near the anchor
    local ax, ay = anchor:LocalToScreen(0, 0)
    local tipX = ax + anchor:GetWide() + Scale(8)
    local tipY = ay

    if (tipX + panelW > ScrW()) then
        tipX = ax - panelW - Scale(8)
    end
    if (tipY + tip:GetTall() > ScrH()) then
        tipY = ScrH() - tip:GetTall() - Scale(8)
    end

    tip:SetPos(tipX, tipY)
    tooltipPanel = tip
end

function ix.bacta.HideStrandTooltip()
    if (IsValid(tooltipPanel)) then
        tooltipPanel:Remove()
        tooltipPanel = nil
    end
end
