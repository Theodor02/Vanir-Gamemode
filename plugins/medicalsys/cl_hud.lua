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

-- ═══════════════════════════════════════════════════════════════════════════════
-- BACTA VISUAL EFFECTS — Screenspace Rendering
-- Reads the local player's visual.* player effect values and renders
-- color tints, blur, bloom, vignette, sharpen, desaturation, screen flicker,
-- water warp, nausea sway, and tremor view-punch in real time.
-- ═══════════════════════════════════════════════════════════════════════════════

-- Cached state for heartbeat loop
local _bactaHeartbeat = nil
local _bactaHeartbeatActive = false
local _bactaHeartbeatNextBeat = 0

hook.Add("RenderScreenspaceEffects", "ixBactaVisualEffects", function()
    local client = LocalPlayer()
    if (!IsValid(client) or !client:Alive()) then return end
    if (!client.GetEffectValue) then return end

    local now = CurTime()

    -- ─── Color Tint ─────────────────────────────────────────────────────
    local tint = client:GetEffectValue("visual.color_tint")
    local desat = client:GetEffectValue("visual.desaturate") or 0

    if (tint and IsColor(tint)) or (desat > 0.01) then
        local r, g, b, intensity
        if (tint and IsColor(tint)) then
            r, g, b = tint.r, tint.g, tint.b
            intensity = (tint.a or 30) / 255
        else
            r, g, b = 255, 255, 255
            intensity = 0
        end

        DrawColorModify({
            ["$pp_colour_addr"] = (r / 255 - 0.5) * intensity,
            ["$pp_colour_addg"] = (g / 255 - 0.5) * intensity,
            ["$pp_colour_addb"] = (b / 255 - 0.5) * intensity,
            ["$pp_colour_brightness"] = -0.02 * intensity,
            ["$pp_colour_contrast"] = 1 + (0.08 * intensity),
            ["$pp_colour_colour"] = 1 - math.max(0.25 * intensity, desat),
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0,
        })
    end

    -- ─── Motion Blur ────────────────────────────────────────────────────
    local blur = client:GetEffectValue("visual.blur") or 0
    if (blur > 0.01) then
        local amount = 0.05 + (blur * 0.35)
        DrawMotionBlur(math.Clamp(amount, 0, 0.5), 0.8, 0.01)
    end

    -- ─── Bloom ──────────────────────────────────────────────────────────
    local bloom = client:GetEffectValue("visual.bloom") or 0
    if (bloom > 0.01) then
        DrawBloom(
            0.5,
            bloom * 1.5,
            3 + bloom * 3,
            3 + bloom * 3,
            3,
            bloom * 0.5,
            1 - bloom * 0.05,
            1 - bloom * 0.05,
            1 - bloom * 0.05
        )
    end

    -- ─── Sharpen ────────────────────────────────────────────────────────
    local sharpen = client:GetEffectValue("visual.sharpen") or 0
    if (sharpen > 0.01) then
        DrawSharpen(sharpen * 2, sharpen * 0.5)
    end

    -- ─── Water Warp ─────────────────────────────────────────────────────
    local warp = client:GetEffectValue("visual.water_warp") or 0
    if (warp > 0.01) then
        DrawMaterialOverlay("effects/water_warp01", warp * -0.01)
    end

    -- ─── Vignette ───────────────────────────────────────────────────────
    local vignette = client:GetEffectValue("visual.vignette") or 0
    if (vignette > 0.01) then
        local scrW, scrH = ScrW(), ScrH()
        local layers = math.Clamp(math.floor(vignette * 12), 1, 8)

        for i = 1, layers do
            local frac = i / layers
            local alpha = vignette * 220 * frac
            local inset = scrW * (1 - frac) * 0.5

            surface.SetDrawColor(0, 0, 0, math.Clamp(alpha, 0, 200))
            surface.DrawRect(0, 0, scrW, inset * 0.6)
            surface.DrawRect(0, scrH - inset * 0.6, scrW, inset * 0.6)
            surface.DrawRect(0, 0, inset, scrH)
            surface.DrawRect(scrW - inset, 0, inset, scrH)
        end
    end

    -- ─── Screen Flicker ─────────────────────────────────────────────────
    local flicker = client:GetEffectValue("visual.screen_flicker") or 0
    if (flicker > 0.01) then
        if (math.random() < flicker * FrameTime()) then
            surface.SetDrawColor(0, 0, 0, math.random(100, 220))
            surface.DrawRect(0, 0, ScrW(), ScrH())
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- BACTA TREMOR VIEW PUNCH — Continuous Camera Shake
-- Applies sinusoidal view-angle perturbation based on visual.tremor value.
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("Think", "ixBactaTremorEffect", function()
    local client = LocalPlayer()
    if (!IsValid(client) or !client:Alive()) then return end
    if (!client.GetEffectValue) then return end

    local tremor = client:GetEffectValue("visual.tremor") or 0
    if (tremor <= 0) then return end

    local now = CurTime()
    local intensity = tremor * 0.35

    local ang = Angle(
        math.sin(now * 10) * intensity,
        math.cos(now * 7.5) * intensity * 0.7,
        math.sin(now * 5) * intensity * 0.2
    )

    client:SetEyeAngles(client:EyeAngles() + ang * FrameTime() * 5)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- BACTA NAUSEA SWAY — Sinusoidal View Drift
-- Applies a slow, disorienting sway to the camera based on visual.nausea.
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("Think", "ixBactaNauseaEffect", function()
    local client = LocalPlayer()
    if (!IsValid(client) or !client:Alive()) then return end
    if (!client.GetEffectValue) then return end

    local nausea = client:GetEffectValue("visual.nausea") or 0
    if (nausea <= 0) then return end

    local now = CurTime()
    local intensity = nausea * 0.6

    -- Slow, sickening drift
    local ang = Angle(
        math.sin(now * 1.5) * intensity * 0.4,
        math.cos(now * 1.1) * intensity * 0.6,
        math.sin(now * 0.8) * intensity * 0.15
    )

    client:SetEyeAngles(client:EyeAngles() + ang * FrameTime() * 3)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- BACTA HEARTBEAT — Pulsing Audio Loop
-- Plays a rhythmic heartbeat sound when audio.heartbeat > 0.
-- Intensity controls volume and rate.
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("Think", "ixBactaHeartbeatLoop", function()
    local client = LocalPlayer()
    if (!IsValid(client) or !client:Alive()) then
        _bactaHeartbeatActive = false
        return
    end
    if (!client.GetEffectValue) then return end

    local heartbeat = client:GetEffectValue("audio.heartbeat") or 0
    local now = CurTime()

    if (heartbeat > 0.01) then
        _bactaHeartbeatActive = true
        -- Beat interval: faster at higher intensity (0.4s at max, 1.2s at low)
        local interval = math.Clamp(1.4 - heartbeat * 1.0, 0.4, 1.4)

        if (now >= _bactaHeartbeatNextBeat) then
            local vol = math.Clamp(heartbeat * 0.5, 0.1, 0.5)
            surface.PlaySound("ambient/machines/machine1_hit1.wav")
            _bactaHeartbeatNextBeat = now + interval
        end
    else
        _bactaHeartbeatActive = false
    end
end)
