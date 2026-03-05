--- Smart Disease — Client-Side Logic
-- Handles disease state synchronisation, visual effects, notifications,
-- the body status HUD display, and immersive client-side events
-- (heartbeat, phantom voices, clone hallucinations, etc.).
-- @module ix.disease (client)

local PLUGIN = PLUGIN

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLIENT STATE
-- ═══════════════════════════════════════════════════════════════════════════════

ix.disease = ix.disease or {}
ix.disease._clientDiseases = ix.disease._clientDiseases or {}
ix.disease._activeVisuals = ix.disease._activeVisuals or {}
ix.disease._activeVisualExpiry = ix.disease._activeVisualExpiry or 0
ix.disease._shadowStalkers = ix.disease._shadowStalkers or {}

-- Client event state
ix.disease._heartbeat = ix.disease._heartbeat or nil        -- active heartbeat sound
ix.disease._heartbeatExpiry = 0
ix.disease._phantomSounds = ix.disease._phantomSounds or {}  -- active phantom sound entries
ix.disease._cloneModels = ix.disease._cloneModels or {}      -- active clone hallucination models
ix.disease._tinnitus = nil                                    -- active tinnitus sound
ix.disease._tinnitusExpiry = 0
ix.disease._screenFlash = 0                                   -- screen flash end time
ix.disease._intrusiveThought = nil                            -- current intrusive thought text
ix.disease._intrusiveThoughtExpiry = 0
ix.disease._fleetingThoughts = ix.disease._fleetingThoughts or {} -- active fleeting thoughts (sliding animation)

-- Water warp material (pre-cached)
local matWaterWarp = Material("effects/water_warp01")
local matWhite = Material("vgui/white")

-- ═══════════════════════════════════════════════════════════════════════════════
-- HUD THEME (matching medicalsys / diegetic style)
-- ═══════════════════════════════════════════════════════════════════════════════

local THEME = {
    bg          = Color(6, 8, 10, 200),
    headerBg    = Color(180, 40, 40, 90),
    panel       = Color(10, 12, 16, 210),
    accent      = Color(200, 55, 55, 255),
    accentSoft  = Color(200, 55, 55, 120),
    text        = Color(210, 220, 215, 255),
    textMuted   = Color(140, 155, 150, 160),
    textBright  = Color(255, 240, 240, 255),
    positive    = Color(60, 200, 100, 255),
    negative    = Color(200, 55, 55, 255),
    warning     = Color(255, 180, 50, 255),
    barBg       = Color(16, 20, 26, 220),
    border      = Color(180, 40, 40, 50),
}

local HUD_WIDTH = 200
local HUD_HEADER = 22
local HUD_ENTRY = 32
local HUD_MARGIN = 12

local function Scale(v)
    return math.max(1, math.Round(v * (ScrH() / 900)))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- FONTS
-- ═══════════════════════════════════════════════════════════════════════════════

local function CreateDiseaseFonts()
    surface.CreateFont("ixDiseaseHudLabel", {
        font = "Orbitron Medium",
        size = Scale(9),
        weight = 500,
        extended = true,
        antialias = true,
    })

    surface.CreateFont("ixDiseaseHudSub", {
        font = "Orbitron Light",
        size = Scale(7),
        weight = 400,
        extended = true,
        antialias = true,
    })

    surface.CreateFont("ixDiseaseHudAurebesh", {
        font = "Aurebesh",
        size = Scale(8),
        weight = 400,
        extended = true,
        antialias = true,
    })

    surface.CreateFont("ixDiseaseIntrusive", {
        font = "Trebuchet MS",
        size = Scale(18),
        weight = 800,
        extended = true,
        antialias = true,
    })

    surface.CreateFont("ixDiseaseIntrusiveSub", {
        font = "Trebuchet MS",
        size = Scale(11),
        weight = 600,
        extended = true,
        antialias = true,
    })
end

CreateDiseaseFonts()
hook.Add("OnScreenSizeChanged", "ixDiseaseHUDFonts", CreateDiseaseFonts)

-- ═══════════════════════════════════════════════════════════════════════════════
-- PERSISTENT VISUAL CALCULATION
-- ═══════════════════════════════════════════════════════════════════════════════

--- Calculate merged persistent visual config from all active diseases.
-- Reads disease definitions (shared code) and calculates combined visuals
-- from each disease's current stage persistentVisual field.
-- @return table Merged visual config
local function CalculatePersistentVisuals()
    local diseases = ix.disease._clientDiseases
    if (!diseases or table.IsEmpty(diseases)) then return nil end

    local merged = {}
    local hasAny = false

    for diseaseID, info in pairs(diseases) do
        local disease = ix.disease.Get(diseaseID)
        if (!disease) then continue end

        local stage = info.stage or 1
        local stageData = disease.stages[stage]
        if (!stageData or !stageData.persistentVisual) then continue end

        local pv = stageData.persistentVisual
        hasAny = true

        -- Merge colormod (take strongest intensity)
        if (pv.colormod and (!merged.colormod or (pv.colormodIntensity or 0) > (merged.colormodIntensity or 0))) then
            merged.colormod = pv.colormod
            merged.colormodIntensity = pv.colormodIntensity
        end

        -- Merge blur (take strongest)
        if (pv.blur and (!merged.blur or (pv.blurIntensity or 0) > (merged.blurIntensity or 0))) then
            merged.blur = true
            merged.blurIntensity = pv.blurIntensity
        end

        -- Merge vignette (take strongest)
        if (pv.vignette and (!merged.vignette or (pv.vignetteIntensity or 0) > (merged.vignetteIntensity or 0))) then
            merged.vignette = true
            merged.vignetteIntensity = pv.vignetteIntensity
        end

        -- Merge bloom (take strongest)
        if (pv.bloom and (!merged.bloom or (pv.bloomIntensity or 0) > (merged.bloomIntensity or 0))) then
            merged.bloom = true
            merged.bloomIntensity = pv.bloomIntensity
        end

        -- Merge sharpen (take strongest)
        if (pv.sharpen and (!merged.sharpen or (pv.sharpenIntensity or 0) > (merged.sharpenIntensity or 0))) then
            merged.sharpen = true
            merged.sharpenIntensity = pv.sharpenIntensity
        end

        -- Merge desaturate (take strongest)
        if (pv.desaturate and (!merged.desaturate or (pv.desaturateIntensity or 0) > (merged.desaturateIntensity or 0))) then
            merged.desaturate = true
            merged.desaturateIntensity = pv.desaturateIntensity
        end

        -- Merge waterWarp (take strongest)
        if (pv.waterWarp and (!merged.waterWarp or (pv.waterWarpIntensity or 0) > (merged.waterWarpIntensity or 0))) then
            merged.waterWarp = true
            merged.waterWarpIntensity = pv.waterWarpIntensity
        end

        -- Merge sobel (take strongest)
        if (pv.sobel and (!merged.sobel or (pv.sobelThreshold or 0) > (merged.sobelThreshold or 0))) then
            merged.sobel = true
            merged.sobelThreshold = pv.sobelThreshold
        end

        -- Merge screenFlicker (take highest rate)
        if (pv.screenFlicker and (!merged.screenFlicker or (pv.flickerRate or 0) > (merged.flickerRate or 0))) then
            merged.screenFlicker = true
            merged.flickerRate = pv.flickerRate
        end
    end

    return hasAny and merged or nil
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- NETWORK RECEIVERS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Receive full disease state sync from server.
net.Receive("ixDiseaseSync", function()
    ix.disease._clientDiseases = net.ReadTable()
end)

--- Receive a notification message.
net.Receive("ixDiseaseNotify", function()
    local message = net.ReadString()

    if (ix.util and ix.util.Notify) then
        ix.util.Notify(message)
    else
        chat.AddText(Color(200, 55, 55), "[Disease] ", Color(255, 255, 255), message)
    end
end)

--- Receive visual effect instructions (one-shot, from symptoms).
net.Receive("ixDiseaseVisual", function()
    local config = net.ReadTable()
    ix.disease._activeVisuals = config
    ix.disease._activeVisualExpiry = CurTime() + 5
end)

--- Receive cure notification (clear client visuals).
net.Receive("ixDiseaseCured", function()
    local diseaseID = net.ReadString()

    if (diseaseID == "__all__") then
        ix.disease._clientDiseases = {}
        ix.disease._activeVisuals = {}
        ix.disease._activeVisualExpiry = 0
        ix.disease.StopAllClientEvents()
    else
        ix.disease._clientDiseases[diseaseID] = nil
    end
end)

--- Receive sound from server.
net.Receive("ixDiseaseSound", function()
    local soundPath = net.ReadString()
    local volume = net.ReadFloat()
    local pitch = net.ReadUInt(8)

    surface.PlaySound(soundPath)
end)

--- Receive shadow stalker spawn from server (schizophrenia horror effect).
net.Receive("ixDiseaseShadowStalker", function()
    local spawnInFront = net.ReadBool()
    local localPlayer = LocalPlayer()

    if (!IsValid(localPlayer)) then return end

    local eyePos = localPlayer:EyePos()
    local eyeDir = localPlayer:EyeAngles():Forward()

    local spawnPos
    if (spawnInFront) then
        spawnPos = eyePos + eyeDir * math.random(300, 400)
    else
        local rightDir = localPlayer:EyeAngles():Right()
        local sideOffset = (math.random(0, 1) == 0 and -1 or 1) * math.random(150, 250)
        spawnPos = eyePos + rightDir * sideOffset + Vector(0, 0, 50)
    end

    local model = ClientsideModel("models/gman.mdl")
    if (IsValid(model)) then
        model:SetPos(spawnPos)
        model:SetColor(Color(20, 20, 25, 255))
        model:SetRenderMode(RENDERMODE_TRANSCOLOR)

        local shadow = {
            model = model,
            spawnTime = CurTime(),
            expireTime = CurTime() + math.random(60, 100) / 10,
        }

        table.insert(ix.disease._shadowStalkers, shadow)
    end
end)

--- Receive client event from server (heartbeat, phantom_sound, clone, etc.).
net.Receive("ixDiseaseClientEvent", function()
    local eventType = net.ReadString()
    local eventData = net.ReadTable()

    ix.disease.HandleClientEvent(eventType, eventData)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLIENT EVENT HANDLERS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Stop all active client events (heartbeat, tinnitus, clone models, etc.)
function ix.disease.StopAllClientEvents()
    -- Stop heartbeat
    if (ix.disease._heartbeat) then
        ix.disease._heartbeat:Stop()
        ix.disease._heartbeat = nil
    end
    ix.disease._heartbeatExpiry = 0

    -- Stop tinnitus
    if (ix.disease._tinnitus) then
        ix.disease._tinnitus:Stop()
        ix.disease._tinnitus = nil
    end
    ix.disease._tinnitusExpiry = 0

    -- Remove clone models
    for _, clone in ipairs(ix.disease._cloneModels) do
        if (IsValid(clone.model)) then
            clone.model:Remove()
        end
    end
    ix.disease._cloneModels = {}

    -- Stop phantom sounds
    for _, ps in ipairs(ix.disease._phantomSounds) do
        if (ps.sound) then
            ps.sound:Stop()
        end
    end
    ix.disease._phantomSounds = {}

    -- Clear screen flash
    ix.disease._screenFlash = 0

    -- Clear intrusive thought
    ix.disease._intrusiveThought = nil
    ix.disease._intrusiveThoughtExpiry = 0

    -- Clear fleeting thoughts
    ix.disease._fleetingThoughts = {}

    -- Remove shadow stalkers
    for _, shadow in ipairs(ix.disease._shadowStalkers) do
        if (IsValid(shadow.model)) then
            shadow.model:Remove()
        end
    end
    ix.disease._shadowStalkers = {}
end

--- Handle a client event dispatched from the server.
-- @param eventType string Event ID (heartbeat, phantom_sound, clone, etc.)
-- @param data table Event data payload
function ix.disease.HandleClientEvent(eventType, data)
    local localPlayer = LocalPlayer()
    if (!IsValid(localPlayer)) then return end

    if (eventType == "heartbeat") then
        -- Play a looping heartbeat sound
        local duration = data.duration or 10
        local volume = data.volume or 0.5
        local speed = data.speed or 1.0

        -- Stop existing heartbeat if playing
        if (ix.disease._heartbeat) then
            ix.disease._heartbeat:Stop()
        end

        -- Create a looping heartbeat sound with CreateSound for volume/pitch control
        local snd = CreateSound(localPlayer, "ambient/machines/machine1_hit1.wav")
        if (snd) then
            snd:PlayEx(volume, math.Clamp(speed * 100, 60, 255))
            ix.disease._heartbeat = snd
            ix.disease._heartbeatExpiry = CurTime() + duration
        end

        -- Also use surface.PlaySound for an immediate audible heartbeat
        surface.PlaySound("ambient/machines/machine1_hit1.wav")

    elseif (eventType == "phantom_sound") then
        -- Play schizophrenia voices/whispers
        local sounds = data.sounds or {"disease/voices01.wav"}
        local volume = data.volume or 0.4
        local duration = data.duration or 10

        -- Pick a random sound and play it
        local path = sounds[math.random(#sounds)]
        surface.PlaySound(path)

        -- Schedule additional repeats during the duration
        local repeatCount = math.floor(duration / 5)
        for i = 1, repeatCount do
            timer.Simple(i * (duration / (repeatCount + 1)) + math.Rand(-1, 1), function()
                if (!IsValid(LocalPlayer())) then return end
                local p = sounds[math.random(#sounds)]
                surface.PlaySound(p)
            end)
        end

    elseif (eventType == "clone") then
        -- Spawn a clientside clone of the player model facing them
        local duration = data.duration or 8
        local eyePos = localPlayer:EyePos()
        local eyeDir = localPlayer:EyeAngles():Forward()

        -- Place clone 2-4 metres in front
        local dist = math.random(200, 400)
        local spawnPos = eyePos + eyeDir * dist

        -- Trace to find ground
        local tr = util.TraceLine({
            start = spawnPos + Vector(0, 0, 50),
            endpos = spawnPos - Vector(0, 0, 200),
            mask = MASK_SOLID_BRUSHONLY,
        })
        if (tr.Hit) then
            spawnPos = tr.HitPos
        end

        local model = ClientsideModel(localPlayer:GetModel())
        if (IsValid(model)) then
            model:SetPos(spawnPos)

            -- Face the player
            local dirToPlayer = (eyePos - spawnPos)
            dirToPlayer.z = 0
            dirToPlayer:Normalize()
            model:SetAngles(dirToPlayer:Angle())

            -- Slightly transparent and discoloured
            model:SetRenderMode(RENDERMODE_TRANSCOLOR)
            model:SetColor(Color(200, 180, 220, 200))

            local clone = {
                model = model,
                spawnTime = CurTime(),
                expireTime = CurTime() + duration,
            }

            table.insert(ix.disease._cloneModels, clone)
        end

    elseif (eventType == "eye_distort") then
        -- Jolt the player's view angle
        local intensity = data.intensity or 10
        local ang = localPlayer:EyeAngles()
        ang.p = ang.p + math.Rand(-intensity, intensity)
        ang.y = ang.y + math.Rand(-intensity * 0.5, intensity * 0.5)
        localPlayer:SetEyeAngles(ang)

    elseif (eventType == "screen_flash") then
        -- Flash screen to black
        local duration = data.duration or 0.5
        ix.disease._screenFlash = CurTime() + duration

    elseif (eventType == "intrusive_thought") then
        -- Display a disturbing intrusive thought text on screen
        local thoughts = data.thoughts or {"Something is wrong."}
        local thought = thoughts[math.random(#thoughts)]
        ix.disease._intrusiveThought = thought
        ix.disease._intrusiveThoughtExpiry = CurTime() + math.Rand(4, 7)

    elseif (eventType == "fleeting_thought") then
        -- Display a subtle fleeting thought that slides in and out
        local thoughts = data.thoughts or {"Something's not right..."}
        local thought = thoughts[math.random(#thoughts)]
        
        local fleetingThought = {
            text = thought,
            spawnTime = CurTime(),
            duration = math.Rand(3, 5),
            side = math.random(0, 1) == 0 and "left" or "right", -- random side
            yPos = math.Rand(0.2, 0.5), -- random vertical position
        }
        
        table.insert(ix.disease._fleetingThoughts, fleetingThought)

    elseif (eventType == "tinnitus") then
        -- Play a high-pitched ringing sound
        local duration = data.duration or 8

        if (ix.disease._tinnitus) then
            ix.disease._tinnitus:Stop()
        end

        local snd = CreateSound(localPlayer, "ambient/machines/machine1_hit2.wav")
        if (snd) then
            snd:PlayEx(0.3, 200)
            ix.disease._tinnitus = snd
            ix.disease._tinnitusExpiry = CurTime() + duration
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLIENT QUERY API
-- ═══════════════════════════════════════════════════════════════════════════════

--- Get the local player's active diseases (client-side cached version).
-- @return table Dictionary of {diseaseID = info}
function ix.disease.GetClientDiseases()
    return ix.disease._clientDiseases or {}
end

--- Check if the local player has any active diseases.
-- @return bool
function ix.disease.HasClientDiseases()
    return !table.IsEmpty(ix.disease._clientDiseases or {})
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- HUD RENDERING — Body Status Display
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("HUDPaint", "ixDiseaseStatusHUD", function()
    local diseases = ix.disease.GetClientDiseases()
    if (table.IsEmpty(diseases)) then return end

    local w = Scale(HUD_WIDTH)
    local headerH = Scale(HUD_HEADER)
    local entryH = Scale(HUD_ENTRY)
    local margin = Scale(HUD_MARGIN)
    local scrW = ScrW()

    local x = scrW - w - margin
    local y = math.Round(ScrH() * 0.55)
    local now = CurTime()

    local diseaseCount = 0
    for _ in pairs(diseases) do
        diseaseCount = diseaseCount + 1
    end

    local totalH = headerH + (diseaseCount * entryH) + Scale(4)

    -- Outer frame
    surface.SetDrawColor(THEME.bg)
    surface.DrawRect(x, y, w, totalH)
    surface.SetDrawColor(THEME.border)
    surface.DrawOutlinedRect(x, y, w, totalH)

    -- Corner accents
    local cornerLen = Scale(10)
    surface.SetDrawColor(THEME.accent)
    surface.DrawRect(x, y, cornerLen, Scale(2))
    surface.DrawRect(x, y, Scale(2), cornerLen)
    surface.DrawRect(x + w - cornerLen, y, cornerLen, Scale(2))
    surface.DrawRect(x + w - Scale(2), y, Scale(2), cornerLen)

    -- Header
    surface.SetDrawColor(THEME.headerBg)
    surface.DrawRect(x, y, w, headerH)
    draw.SimpleText("BODY STATUS", "ixDiseaseHudLabel",
        x + Scale(8), y + headerH * 0.5,
        Color(0, 0, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local pulse = math.abs(math.sin(now * 1.2))
    draw.SimpleText("PATHOGEN", "ixDiseaseHudAurebesh",
        x + w - Scale(8), y + headerH * 0.5,
        Color(0, 0, 0, math.Round(80 + pulse * 175)), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    y = y + headerH

    -- Disease entries
    local i = 0
    for diseaseID, info in pairs(diseases) do
        i = i + 1
        local disease = ix.disease.Get(diseaseID)
        local stageName = "Unknown"
        local stageNum = info.stage or 1
        local totalStages = 1

        if (disease) then
            totalStages = #disease.stages
            local stageData = disease.stages[stageNum]
            if (stageData) then
                stageName = stageData.name or ("Stage " .. stageNum)
            end
        end

        local entryY = y

        surface.SetDrawColor(THEME.panel)
        surface.DrawRect(x, entryY, w, entryH)

        -- Severity indicator
        local severity = stageNum / totalStages
        local sevCol = ix.disease.GetSeverityColor(severity)
        surface.SetDrawColor(sevCol)
        surface.DrawRect(x, entryY + Scale(3), Scale(3), entryH - Scale(6))

        local displayText = "Your symptoms are worsening"
        if (info.treated) then
            displayText = "Treatment taking effect"
        elseif (info.inRemission) then
            displayText = "Symptoms in remission"
        elseif (severity < 0.3) then
            displayText = "Something feels off"
        elseif (severity < 0.6) then
            displayText = "You feel unwell"
        elseif (severity < 0.85) then
            displayText = "Your symptoms are worsening"
        else
            displayText = "You are gravely ill"
        end

        draw.SimpleText(displayText, "ixDiseaseHudLabel",
            x + Scale(10), entryY + Scale(4),
            THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        draw.SimpleText(stageName, "ixDiseaseHudSub",
            x + Scale(10), entryY + Scale(16),
            THEME.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        -- Progress bar
        local barX = x + Scale(10)
        local barY = entryY + entryH - Scale(8)
        local barW = w - Scale(20)
        local barH = Scale(3)

        surface.SetDrawColor(THEME.barBg)
        surface.DrawRect(barX, barY, barW, barH)
        surface.SetDrawColor(Color(sevCol.r, sevCol.g, sevCol.b, 160))
        surface.DrawRect(barX, barY, barW * severity, barH)

        -- Treatment / remission indicator
        if (info.treated) then
            draw.SimpleText("◆", "ixDiseaseHudSub",
                x + w - Scale(8), entryY + Scale(4),
                THEME.positive, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        elseif (info.inRemission) then
            draw.SimpleText("◇", "ixDiseaseHudSub",
                x + w - Scale(8), entryY + Scale(4),
                THEME.warning, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end

        if (i < diseaseCount) then
            surface.SetDrawColor(THEME.border)
            surface.DrawLine(x + Scale(6), entryY + entryH - 1, x + w - Scale(6), entryY + entryH - 1)
        end

        y = y + entryH
    end

    -- Bottom accent
    local bottomY = y + Scale(2)
    surface.SetDrawColor(THEME.accentSoft)
    surface.DrawRect(x + Scale(4), bottomY, w - Scale(8), Scale(1))
    surface.SetDrawColor(THEME.accent)
    surface.DrawRect(x, bottomY, cornerLen, Scale(2))
    surface.DrawRect(x, bottomY - cornerLen + Scale(2), Scale(2), cornerLen)
    surface.DrawRect(x + w - cornerLen, bottomY, cornerLen, Scale(2))
    surface.DrawRect(x + w - Scale(2), bottomY - cornerLen + Scale(2), Scale(2), cornerLen)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- INTRUSIVE THOUGHT DISPLAY — Schizophrenia Horror Text
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("HUDPaint", "ixDiseaseIntrusiveThought", function()
    if (!ix.disease._intrusiveThought) then return end
    if (CurTime() > ix.disease._intrusiveThoughtExpiry) then
        ix.disease._intrusiveThought = nil
        return
    end

    local remaining = ix.disease._intrusiveThoughtExpiry - CurTime()
    local total = 5 -- approx total duration
    local alpha = 255

    -- Fade in (first 0.5s)
    if (remaining > total - 0.5) then
        alpha = 255 * ((total - remaining) / 0.5)
    end
    -- Fade out (last 1s)
    if (remaining < 1) then
        alpha = 255 * remaining
    end
    alpha = math.Clamp(alpha, 0, 255)

    local scrW, scrH = ScrW(), ScrH()
    local text = ix.disease._intrusiveThought

    -- Glitch offset
    local glitchX = math.sin(CurTime() * 15) * 2
    local glitchY = math.cos(CurTime() * 12) * 1

    -- Draw shadow/ghosting effect
    draw.SimpleText(text, "ixDiseaseIntrusive",
        scrW * 0.5 + glitchX + 2, scrH * 0.35 + glitchY + 1,
        Color(100, 30, 30, alpha * 0.5), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Main text
    draw.SimpleText(text, "ixDiseaseIntrusive",
        scrW * 0.5 + glitchX, scrH * 0.35 + glitchY,
        Color(255, 60, 60, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- FLEETING THOUGHT DISPLAY — Subtle Sliding Intrusive Thoughts
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("HUDPaint", "ixDiseaseFleetingThoughts", function()
    if (!ix.disease._fleetingThoughts or #ix.disease._fleetingThoughts == 0) then return end

    local scrW, scrH = ScrW(), ScrH()
    local now = CurTime()
    local i = 1

    while (i <= #ix.disease._fleetingThoughts) do
        local thought = ix.disease._fleetingThoughts[i]
        local elapsed = now - thought.spawnTime

        -- Remove if expired
        if (elapsed >= thought.duration) then
            table.remove(ix.disease._fleetingThoughts, i)
        else
            local progress = elapsed / thought.duration
            local alpha = 255
            local xOffset = 0

            -- Animation phases
            local slideInDuration = 0.4
            local holdDuration = thought.duration - 1.0 -- hold for most of duration
            local slideOutStart = thought.duration - 0.6

            if (elapsed < slideInDuration) then
                -- Slide in from side
                local slideProgress = elapsed / slideInDuration
                slideProgress = math.ease.OutCubic(slideProgress) -- smooth easing
                
                if (thought.side == "left") then
                    xOffset = -300 * (1 - slideProgress) -- slide from left
                else
                    xOffset = 300 * (1 - slideProgress) -- slide from right
                end
                
                alpha = 255 * slideProgress

            elseif (elapsed >= slideOutStart) then
                -- Slide out to opposite side
                local slideProgress = (elapsed - slideOutStart) / (thought.duration - slideOutStart)
                slideProgress = math.ease.InCubic(slideProgress)
                
                if (thought.side == "left") then
                    xOffset = 300 * slideProgress -- slide to right
                else
                    xOffset = -300 * slideProgress -- slide to left
                end
                
                alpha = 255 * (1 - slideProgress)
            end

            alpha = math.Clamp(alpha, 0, 255)

            -- Calculate position
            local yPos = scrH * thought.yPos
            local xPos

            if (thought.side == "left") then
                xPos = scrW * 0.15 + xOffset
            else
                xPos = scrW * 0.85 + xOffset
            end

            -- Subtle italic style for fleeting thoughts
            local col = Color(200, 190, 210, alpha)
            local shadowCol = Color(40, 30, 50, alpha * 0.4)

            -- Shadow
            draw.SimpleText(thought.text, "ixDiseaseIntrusiveSub",
                xPos + 1, yPos + 1,
                shadowCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            -- Main text
            draw.SimpleText(thought.text, "ixDiseaseIntrusiveSub",
                xPos, yPos,
                col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            i = i + 1
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- SCREEN FLASH — Momentary Blackout
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("HUDPaint", "ixDiseaseScreenFlash", function()
    if (CurTime() >= ix.disease._screenFlash) then return end

    local remaining = ix.disease._screenFlash - CurTime()
    local alpha = math.Clamp(remaining * 510, 0, 255)

    surface.SetDrawColor(0, 0, 0, alpha)
    surface.DrawRect(0, 0, ScrW(), ScrH())
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- SHADOW STALKER RENDERING — Horror Visual Effect
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("Think", "ixDiseaseShadowStalkers", function()
    local shadows = ix.disease._shadowStalkers
    if (!shadows or #shadows == 0) then return end

    local localPlayer = LocalPlayer()
    if (!IsValid(localPlayer)) then return end

    local now = CurTime()
    local playerEyePos = localPlayer:EyePos()
    local i = 1

    while (i <= #shadows) do
        local shadow = shadows[i]

        if (!IsValid(shadow.model)) then
            table.remove(shadows, i)
        elseif (now > shadow.expireTime) then
            shadow.model:Remove()
            table.remove(shadows, i)
        else
            local lifeTime = now - shadow.spawnTime
            local totalLife = shadow.expireTime - shadow.spawnTime

            local fadeInDuration = 0.3
            local fadeOutStart = totalLife - (totalLife * 0.5)
            local alpha = 200

            if (lifeTime < fadeInDuration) then
                alpha = 200 * (lifeTime / fadeInDuration)
            elseif (lifeTime > fadeOutStart) then
                local fadeOutProgress = (lifeTime - fadeOutStart) / (totalLife - fadeOutStart)
                alpha = 200 * (1 - fadeOutProgress)
            end

            alpha = math.Clamp(alpha, 0, 255)
            shadow.model:SetColor(Color(20, 20, 25, alpha))

            -- Face the player
            local modelPos = shadow.model:GetPos()
            local dirToPlayer = playerEyePos - modelPos
            if (dirToPlayer:LengthSqr() > 1) then
                dirToPlayer:Normalize()
                shadow.model:SetAngles(dirToPlayer:Angle())
            end

            i = i + 1
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLONE HALLUCINATION MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("Think", "ixDiseaseCloneModels", function()
    local clones = ix.disease._cloneModels
    if (!clones or #clones == 0) then return end

    local localPlayer = LocalPlayer()
    if (!IsValid(localPlayer)) then return end

    local now = CurTime()
    local playerEyePos = localPlayer:EyePos()
    local i = 1

    while (i <= #clones) do
        local clone = clones[i]

        if (!IsValid(clone.model)) then
            table.remove(clones, i)
        elseif (now > clone.expireTime) then
            clone.model:Remove()
            table.remove(clones, i)
        else
            local lifeTime = now - clone.spawnTime
            local totalLife = clone.expireTime - clone.spawnTime

            -- Fade alpha
            local alpha = 200
            if (lifeTime < 0.5) then
                alpha = 200 * (lifeTime / 0.5)
            elseif (lifeTime > totalLife * 0.7) then
                local progress = (lifeTime - totalLife * 0.7) / (totalLife * 0.3)
                alpha = 200 * (1 - progress)
            end

            alpha = math.Clamp(alpha, 0, 255)
            clone.model:SetColor(Color(200, 180, 220, alpha))

            -- Face the player
            local modelPos = clone.model:GetPos()
            local dirToPlayer = playerEyePos - modelPos
            dirToPlayer.z = 0
            if (dirToPlayer:LengthSqr() > 1) then
                dirToPlayer:Normalize()
                clone.model:SetAngles(dirToPlayer:Angle())
            end

            i = i + 1
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- HEARTBEAT & TINNITUS SOUND MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("Think", "ixDiseaseAudioLoops", function()
    local now = CurTime()

    -- Heartbeat expiry
    if (ix.disease._heartbeat and now > ix.disease._heartbeatExpiry) then
        ix.disease._heartbeat:Stop()
        ix.disease._heartbeat = nil
    end

    -- Tinnitus expiry
    if (ix.disease._tinnitus and now > ix.disease._tinnitusExpiry) then
        ix.disease._tinnitus:Stop()
        ix.disease._tinnitus = nil
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- SEVERITY COLOR HELPER
-- ═══════════════════════════════════════════════════════════════════════════════

--- Get a color representing disease severity (0 = mild, 1 = critical).
-- @param severity number 0-1 fraction
-- @return Color
function ix.disease.GetSeverityColor(severity)
    if (severity < 0.3) then
        return THEME.warning
    elseif (severity < 0.7) then
        return Color(255, 130, 50)
    else
        return THEME.negative
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- VISUAL EFFECTS — Screenspace Rendering
-- Renders BOTH persistent visuals (from disease stage definitions) AND
-- one-shot visuals (from symptom triggers).
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("RenderScreenspaceEffects", "ixDiseaseVisualEffects", function()
    -- Merge persistent visuals from current disease stages with one-shot symptom visuals
    local persistent = CalculatePersistentVisuals()
    local oneShot = nil

    if (CurTime() <= (ix.disease._activeVisualExpiry or 0) and !table.IsEmpty(ix.disease._activeVisuals or {})) then
        oneShot = ix.disease._activeVisuals
    end

    -- If neither is active, skip
    if (!persistent and !oneShot) then return end

    -- Helper: get the stronger value between persistent and oneShot for a given key
    local function GetVal(key, default)
        local pVal = persistent and persistent[key]
        local oVal = oneShot and oneShot[key]
        if (pVal and oVal) then
            if (type(pVal) == "number" and type(oVal) == "number") then
                return math.max(pVal, oVal)
            end
            return oVal -- one-shot overrides for non-numeric
        end
        return oVal or pVal or default
    end

    local function HasEffect(key)
        return (persistent and persistent[key]) or (oneShot and oneShot[key])
    end

    -- ─── Color Modification ─────────────────────────────────────────────
    if (HasEffect("colormod") or HasEffect("desaturate")) then
        local col = GetVal("colormod", Color(255, 255, 255, 255))
        local intensity = GetVal("colormodIntensity", 0.2)
        local desat = HasEffect("desaturate") and GetVal("desaturateIntensity", 0.3) or 0

        local tab = {
            ["$pp_colour_addr"] = (col.r / 255 - 0.5) * intensity,
            ["$pp_colour_addg"] = (col.g / 255 - 0.5) * intensity,
            ["$pp_colour_addb"] = (col.b / 255 - 0.5) * intensity,
            ["$pp_colour_brightness"] = -0.02 * intensity,
            ["$pp_colour_contrast"] = 1 + (0.1 * intensity),
            ["$pp_colour_colour"] = 1 - math.max(0.3 * intensity, desat),
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0,
        }
        DrawColorModify(tab)
    end

    -- ─── Motion Blur ────────────────────────────────────────────────────
    if (HasEffect("blur")) then
        local intensity = GetVal("blurIntensity", 1.0)
        local blurAmount = 0.1 + (intensity * 0.3)
        DrawMotionBlur(blurAmount, 0.8, 0.01)
    end

    -- ─── Bloom ──────────────────────────────────────────────────────────
    if (HasEffect("bloom")) then
        local intensity = GetVal("bloomIntensity", 1.0)
        DrawBloom(
            0.5,                      -- darken
            intensity * 1.5,          -- multiply
            3 + intensity * 3,        -- size x
            3 + intensity * 3,        -- size y
            3,                        -- passes
            intensity * 0.5,          -- color multiply
            1 - intensity * 0.1,      -- r
            1 - intensity * 0.1,      -- g
            1 - intensity * 0.1       -- b
        )
    end

    -- ─── Sharpen ────────────────────────────────────────────────────────
    if (HasEffect("sharpen")) then
        local intensity = GetVal("sharpenIntensity", 0.5)
        DrawSharpen(intensity * 2, intensity * 0.5)
    end

    -- ─── Sobel (edge detection — psychotic effect) ──────────────────────
    if (HasEffect("sobel")) then
        local threshold = GetVal("sobelThreshold", 0.5)
        DrawSobel(threshold)
    end

    -- ─── Water Warp Overlay ─────────────────────────────────────────────
    if (HasEffect("waterWarp")) then
        local intensity = GetVal("waterWarpIntensity", 0.3)
        DrawMaterialOverlay("effects/water_warp01", intensity * -0.01)
    end

    -- ─── Vignette (dark edges / tunnel vision) ──────────────────────────
    if (HasEffect("vignette")) then
        local intensity = GetVal("vignetteIntensity", 0.2)
        local scrW, scrH = ScrW(), ScrH()

        -- Draw concentric semi-transparent black rectangles from edges
        local layers = math.Clamp(math.floor(intensity * 12), 1, 8)
        for i = 1, layers do
            local frac = i / layers
            local alpha = intensity * 220 * frac
            local inset = scrW * (1 - frac) * 0.5

            surface.SetDrawColor(0, 0, 0, math.Clamp(alpha, 0, 200))

            -- Top
            surface.DrawRect(0, 0, scrW, inset * 0.6)
            -- Bottom
            surface.DrawRect(0, scrH - inset * 0.6, scrW, inset * 0.6)
            -- Left
            surface.DrawRect(0, 0, inset, scrH)
            -- Right
            surface.DrawRect(scrW - inset, 0, inset, scrH)
        end
    end

    -- ─── Screen Flicker (brief random black frames) ─────────────────────
    if (HasEffect("screenFlicker")) then
        local rate = GetVal("flickerRate", 3)
        -- Random black flash based on rate
        if (math.random() < rate * FrameTime()) then
            surface.SetDrawColor(0, 0, 0, math.random(150, 255))
            surface.DrawRect(0, 0, ScrW(), ScrH())
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- DISEASE SHAKE EFFECT
-- Applies subtle view punch from active visuals that have shake enabled.
-- ═══════════════════════════════════════════════════════════════════════════════

hook.Add("Think", "ixDiseaseShakeEffect", function()
    -- Combine persistent and one-shot shake
    local shakeIntensity = 0

    -- Check one-shot visuals
    if (CurTime() <= (ix.disease._activeVisualExpiry or 0)) then
        local visuals = ix.disease._activeVisuals
        if (visuals and visuals.shake) then
            shakeIntensity = math.max(shakeIntensity, visuals.shakeIntensity or 1)
        end
    end

    -- Check persistent visuals
    local persistent = CalculatePersistentVisuals()
    if (persistent and persistent.shake) then
        shakeIntensity = math.max(shakeIntensity, persistent.shakeIntensity or 1)
    end

    if (shakeIntensity <= 0) then return end

    local client = LocalPlayer()
    if (!IsValid(client)) then return end

    local ang = Angle(
        math.sin(CurTime() * 8) * shakeIntensity * 0.3,
        math.cos(CurTime() * 6) * shakeIntensity * 0.2,
        0
    )
    client:SetEyeAngles(client:EyeAngles() + ang * FrameTime())
end)
