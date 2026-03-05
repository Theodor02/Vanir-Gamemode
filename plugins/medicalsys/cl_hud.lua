--- Client-Side Active Effect HUD
-- Diegetic medical terminal overlay for active biochemical effects.
-- Styled to match the compound sequencer terminal aesthetic with
-- Aurebesh readouts and animated medical scan lines.
-- @module ix.bacta (client)

-- ═══════════════════════════════════════════════════════════════════════════════
-- HUD THEME (consistent with sequencer terminal)
-- ═══════════════════════════════════════════════════════════════════════════════

local HUD = {
    bg          = Color(6, 8, 10, 200),
    headerBg    = Color(40, 180, 160, 90),
    panel       = Color(10, 12, 16, 210),
    accent      = Color(40, 200, 180, 255),
    accentSoft  = Color(40, 200, 180, 120),
    text        = Color(210, 225, 220, 255),
    textMuted   = Color(140, 160, 155, 160),
    textBright  = Color(240, 255, 250, 255),
    positive    = Color(60, 200, 100, 255),
    negative    = Color(200, 55, 55, 255),
    tail        = Color(200, 120, 60, 255),
    barBg       = Color(16, 20, 26, 220),
    border      = Color(40, 180, 160, 50),
}

local HUD_WIDTH  = 220
local HUD_HEADER = 24
local HUD_ENTRY  = 40
local HUD_MARGIN = 12

local function Scale(value)
    return math.max(1, math.Round(value * (ScrH() / 900)))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- FONTS (shared prefix with sequencer; only created if not already registered)
-- ═══════════════════════════════════════════════════════════════════════════════

local function CreateHudFonts()
    surface.CreateFont("ixMedHudLabel", {
        font = "Orbitron Medium",
        size = Scale(9),
        weight = 500,
        extended = true,
        antialias = true
    })

    surface.CreateFont("ixMedHudDiag", {
        font = "Orbitron Light",
        size = Scale(8),
        weight = 400,
        extended = true,
        antialias = true
    })

    surface.CreateFont("ixMedHudAurebesh", {
        font = "Aurebesh",
        size = Scale(8),
        weight = 400,
        extended = true,
        antialias = true
    })
end

CreateHudFonts()
hook.Add("OnScreenSizeChanged", "ixMedicalSysHUDFonts", CreateHudFonts)

-- ═══════════════════════════════════════════════════════════════════════════════
-- HUD RENDERING
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("HUDPaint", "ixBactaEffectHUD", function()
    if (!ix.bacta or !ix.bacta.activeEffects) then return end

    ix.bacta.CleanActiveEffects()

    local effects = ix.bacta.activeEffects
    if (#effects == 0) then return end

    local w = Scale(HUD_WIDTH)
    local headerH = Scale(HUD_HEADER)
    local entryH = Scale(HUD_ENTRY)
    local margin = Scale(HUD_MARGIN)
    local scrW = ScrW()

    local x = scrW - w - margin
    local y = math.Round(ScrH() * 0.32)
    local now = CurTime()

    -- Total height for the frame
    local totalH = headerH + (#effects * entryH) + Scale(4)

    -- ─── Outer frame ───────────────────────────────────────────────────
    -- Background
    surface.SetDrawColor(HUD.bg)
    surface.DrawRect(x, y, w, totalH)

    -- Frame border
    surface.SetDrawColor(HUD.border)
    surface.DrawOutlinedRect(x, y, w, totalH)

    -- Corner accents (top-left + top-right)
    local cornerLen = Scale(10)
    surface.SetDrawColor(HUD.accent)
    surface.DrawRect(x, y, cornerLen, Scale(2))
    surface.DrawRect(x, y, Scale(2), cornerLen)
    surface.DrawRect(x + w - cornerLen, y, cornerLen, Scale(2))
    surface.DrawRect(x + w - Scale(2), y, Scale(2), cornerLen)

    -- ─── Header bar ────────────────────────────────────────────────────
    surface.SetDrawColor(HUD.headerBg)
    surface.DrawRect(x, y, w, headerH)

    draw.SimpleText("ACTIVE COMPOUNDS", "ixMedHudLabel", x + Scale(8), y + headerH * 0.5, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- Aurebesh cycling decoration
    local pulse = math.abs(math.sin(now * 1.8))
    draw.SimpleText("MED-SYS", "ixMedHudAurebesh", x + w - Scale(8), y + headerH * 0.5, Color(0, 0, 0, math.Round(80 + pulse * 175)), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    y = y + headerH

    -- ─── Effect entries ────────────────────────────────────────────────
    for i, eff in ipairs(effects) do
        local remaining = eff.endTime - now
        if (remaining <= 0) then continue end

        local frac = remaining / eff.duration
        local et = ix.bacta.effectTypes[eff.type]
        local isSide = ix.bacta.IsSideEffect(eff.type)
        local isTail = eff.isTailEffect or (ix.bacta.IsTailEffect and ix.bacta.IsTailEffect(eff.type)) or false
        local col = (et and et.color) or HUD.text
        local name = (et and et.name) or eff.type

        local entryX = x
        local entryY = y

        -- Entry background (slightly different for tail effects)
        if (isTail) then
            surface.SetDrawColor(Color(20, 14, 10, 210))
        else
            surface.SetDrawColor(HUD.panel)
        end
        surface.DrawRect(entryX, entryY, w, entryH)

        -- Side/tail effect indicator bar on left
        local indicatorCol
        if (isTail) then
            indicatorCol = HUD.tail
        elseif (isSide) then
            indicatorCol = HUD.negative
        else
            indicatorCol = HUD.positive
        end
        surface.SetDrawColor(indicatorCol)
        surface.DrawRect(entryX, entryY + Scale(3), Scale(3), entryH - Scale(6))

        -- Effect name with TAIL label
        local displayName = name
        if (isTail) then
            displayName = "⏱ " .. name
        end
        draw.SimpleText(displayName, "ixMedHudLabel", entryX + Scale(10), entryY + Scale(5), isTail and HUD.tail or col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        -- Remaining time
        local timeStr = string.format("%.0fs", remaining)
        draw.SimpleText(timeStr, "ixMedHudDiag", entryX + w - Scale(8), entryY + Scale(5), HUD.textMuted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

        -- Side effect / benefit / tail symbol
        local symbol
        if (isTail) then
            symbol = "◆" -- diamond for tail
        elseif (isSide) then
            symbol = "▼"
        else
            symbol = "▲"
        end
        draw.SimpleText(symbol, "ixMedHudDiag", entryX + w - Scale(8), entryY + Scale(16), indicatorCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

        -- Duration bar
        local barX = entryX + Scale(10)
        local barY = entryY + entryH - Scale(10)
        local barW = w - Scale(20)
        local barH = Scale(4)

        surface.SetDrawColor(HUD.barBg)
        surface.DrawRect(barX, barY, barW, barH)

        local barCol = isTail and HUD.tail or col
        surface.SetDrawColor(Color(barCol.r, barCol.g, barCol.b, 160))
        surface.DrawRect(barX, barY, barW * frac, barH)

        -- Separator line between entries
        if (i < #effects) then
            surface.SetDrawColor(HUD.border)
            surface.DrawLine(entryX + Scale(6), entryY + entryH - 1, entryX + w - Scale(6), entryY + entryH - 1)
        end

        y = y + entryH
    end

    -- ─── Bottom accent line ────────────────────────────────────────────
    local bottomY = y + Scale(2)
    surface.SetDrawColor(HUD.accentSoft)
    surface.DrawRect(x + Scale(4), bottomY, w - Scale(8), Scale(1))

    -- Bottom corner accents
    surface.SetDrawColor(HUD.accent)
    surface.DrawRect(x, y + Scale(2), cornerLen, Scale(2))
    surface.DrawRect(x, y + Scale(2) - cornerLen + Scale(2), Scale(2), cornerLen)
    surface.DrawRect(x + w - cornerLen, y + Scale(2), cornerLen, Scale(2))
    surface.DrawRect(x + w - Scale(2), y + Scale(2) - cornerLen + Scale(2), Scale(2), cornerLen)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- HIDE HUD IN CERTAIN CONDITIONS
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("HUDShouldDraw", "ixBactaHUDVisibility", function(name)
    -- The effect HUD is always drawn via HUDPaint, this hook is for
    -- compatibility — we don't block any default HUD elements.
end)
