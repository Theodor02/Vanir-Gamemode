--- Client-Side Force System
-- Handles force whisper rendering (three alignment styles) and
-- disables the LSCS inventory menu / desktop icon since the
-- unlock tree replaces LSCS's built-in inventory management.
-- @module theos-forcesystem.cl_forcesystem

if not CLIENT then return end

-- ─────────────────────────────────────────────
-- Disable LSCS menu UI (client-side)
-- ─────────────────────────────────────────────

timer.Simple(0, function()
    -- Remove the LSCS menu from the spawn menu / desktop window list
    list.Set("DesktopWindows", "LSCSMenu", nil)

    -- Stub the concommand so it does nothing
    concommand.Remove("lscs_openmenu")

    -- Stub the global open function
    if LSCS then
        LSCS.OpenMenu = function() end
    end
end)

-- ─────────────────────────────────────────────
-- Force Whisper Fonts
-- ─────────────────────────────────────────────

local function Scale(px)
    return math.Round(px * (ScrH() / 1080))
end

local function CreateForceWhisperFonts()
    surface.CreateFont("ixForceWhisperStrong", {
        font = "Trebuchet MS",
        size = Scale(18),
        weight = 800,
        extended = true,
        antialias = true,
    })

    surface.CreateFont("ixForceWhisperSubtle", {
        font = "Trebuchet MS",
        size = Scale(11),
        weight = 600,
        extended = true,
        antialias = true,
    })
end

CreateForceWhisperFonts()
hook.Add("OnScreenSizeChanged", "ixForceWhisperFonts", CreateForceWhisperFonts)

-- ─────────────────────────────────────────────
-- Whisper State
-- ─────────────────────────────────────────────

local activeWhisper = nil  -- {text, alignment, intensity, spawnTime, duration, side, yPos}

-- ─────────────────────────────────────────────
-- Net Receiver
-- ─────────────────────────────────────────────

net.Receive("ixForceWhisper", function()
    local alignment = net.ReadString()
    local intensity = net.ReadString()
    local thought   = net.ReadString()

    -- Only one whisper active at a time
    activeWhisper = {
        text      = thought,
        alignment = alignment,
        intensity = intensity,
        spawnTime = CurTime(),
        duration  = intensity == "strong" and math.Rand(5, 8) or math.Rand(3, 5),
        side      = math.random(0, 1) == 0 and "left" or "right",
        yPos      = math.Rand(0.2, 0.5),
    }
end)

-- ─────────────────────────────────────────────
-- Alignment Color Palettes
-- ─────────────────────────────────────────────

local PALETTE = {
    dark = {
        main     = Color(255, 60, 60),
        shadow   = Color(100, 30, 30),
        subtle   = Color(200, 120, 130),
        subtleSh = Color(80, 30, 40),
    },
    light = {
        main     = Color(255, 220, 140),
        shadow   = Color(120, 100, 50),
        subtle   = Color(230, 210, 160),
        subtleSh = Color(80, 70, 40),
    },
    grey = {
        main     = Color(180, 195, 220),
        shadow   = Color(60, 70, 90),
        subtle   = Color(170, 180, 200),
        subtleSh = Color(50, 55, 70),
    },
}

-- ─────────────────────────────────────────────
-- HUD Rendering
-- ─────────────────────────────────────────────

hook.Add("HUDPaint", "ixForceWhisperHUD", function()
    if not activeWhisper then return end

    local w = activeWhisper
    local elapsed = CurTime() - w.spawnTime

    if elapsed >= w.duration then
        activeWhisper = nil
        return
    end

    local scrW, scrH = ScrW(), ScrH()
    local pal = PALETTE[w.alignment] or PALETTE.grey

    if w.intensity == "strong" then
        -- ── STRONG: centered text ──
        local total = w.duration
        local remaining = total - elapsed
        local alpha = 255

        -- Fade in (first 0.5s)
        if elapsed < 0.5 then
            alpha = 255 * (elapsed / 0.5)
        end
        -- Fade out (last 1s)
        if remaining < 1 then
            alpha = 255 * remaining
        end
        alpha = math.Clamp(alpha, 0, 255)

        local font = "ixForceWhisperStrong"
        local x = scrW * 0.5
        local y = scrH * 0.35

        if w.alignment == "dark" then
            -- Dark: glitchy red text
            local glitchX = math.sin(CurTime() * 15) * 2
            local glitchY = math.cos(CurTime() * 12) * 1

            -- Shadow
            draw.SimpleText(w.text, font,
                x + glitchX + 2, y + glitchY + 1,
                Color(pal.shadow.r, pal.shadow.g, pal.shadow.b, alpha * 0.5),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            -- Main
            draw.SimpleText(w.text, font,
                x + glitchX, y + glitchY,
                Color(pal.main.r, pal.main.g, pal.main.b, alpha),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        elseif w.alignment == "light" then
            -- Light: warm golden text with gentle glow
            local breathe = math.sin(CurTime() * 2) * 0.1 + 0.9

            -- Glow layer (wider, softer)
            draw.SimpleText(w.text, font,
                x, y,
                Color(255, 240, 180, alpha * 0.25 * breathe),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            -- Shadow
            draw.SimpleText(w.text, font,
                x + 1, y + 1,
                Color(pal.shadow.r, pal.shadow.g, pal.shadow.b, alpha * 0.4),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            -- Main
            draw.SimpleText(w.text, font,
                x, y,
                Color(pal.main.r, pal.main.g, pal.main.b, alpha * breathe),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        else
            -- Grey: calm silver text with slow drift
            local drift = math.sin(CurTime() * 0.8) * 3

            -- Shadow
            draw.SimpleText(w.text, font,
                x + 1, y + drift + 1,
                Color(pal.shadow.r, pal.shadow.g, pal.shadow.b, alpha * 0.4),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            -- Main
            draw.SimpleText(w.text, font,
                x, y + drift,
                Color(pal.main.r, pal.main.g, pal.main.b, alpha),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

    else
        -- ── SUBTLE: sliding text from side ──
        local progress = elapsed / w.duration
        local alpha = 255
        local xOffset = 0

        local slideInDuration = 0.4
        local slideOutStart = w.duration - 0.6

        if elapsed < slideInDuration then
            local slideProgress = math.ease.OutCubic(elapsed / slideInDuration)
            if w.side == "left" then
                xOffset = -300 * (1 - slideProgress)
            else
                xOffset = 300 * (1 - slideProgress)
            end
            alpha = 255 * slideProgress

        elseif elapsed >= slideOutStart then
            local slideProgress = math.ease.InCubic((elapsed - slideOutStart) / (w.duration - slideOutStart))
            if w.side == "left" then
                xOffset = 300 * slideProgress
            else
                xOffset = -300 * slideProgress
            end
            alpha = 255 * (1 - slideProgress)
        end

        alpha = math.Clamp(alpha, 0, 255)

        local yPos = scrH * w.yPos
        local xPos = w.side == "left" and (scrW * 0.15 + xOffset) or (scrW * 0.85 + xOffset)
        local font = "ixForceWhisperSubtle"

        local mainCol, shadowCol

        if w.alignment == "dark" then
            -- Dark subtle: dim reddish with slight jitter
            local jitter = math.sin(CurTime() * 8) * 1
            xPos = xPos + jitter
            mainCol   = Color(pal.subtle.r, pal.subtle.g, pal.subtle.b, alpha)
            shadowCol = Color(pal.subtleSh.r, pal.subtleSh.g, pal.subtleSh.b, alpha * 0.4)
        elseif w.alignment == "light" then
            -- Light subtle: warm amber, no jitter
            mainCol   = Color(pal.subtle.r, pal.subtle.g, pal.subtle.b, alpha)
            shadowCol = Color(pal.subtleSh.r, pal.subtleSh.g, pal.subtleSh.b, alpha * 0.4)
        else
            -- Grey subtle: cool silver, no jitter
            mainCol   = Color(pal.subtle.r, pal.subtle.g, pal.subtle.b, alpha)
            shadowCol = Color(pal.subtleSh.r, pal.subtleSh.g, pal.subtleSh.b, alpha * 0.4)
        end

        -- Shadow
        draw.SimpleText(w.text, font,
            xPos + 1, yPos + 1,
            shadowCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        -- Main
        draw.SimpleText(w.text, font,
            xPos, yPos,
            mainCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)
