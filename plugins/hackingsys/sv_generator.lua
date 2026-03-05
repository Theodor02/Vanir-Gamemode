--- Server-side grid generator.
-- Produces a randomised hex-dump grid with placed words, bracket tokens, and junk spans.
-- @module ix.hacking (server)

ix.hacking = ix.hacking or {}
ix.hacking.Generator = {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- INTERNAL HELPERS
-- ═══════════════════════════════════════════════════════════════════════════════

local PAIRS = {
    ["("] = ")",
    ["["] = "]",
    ["{"] = "}",
    ["<"] = ">"
}

local function GetRandomWord(len)
    local list = ix.hacking.WordList[len]
    if (!list) then return "ERRR" end
    return list[math.random(#list)]
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- GENERATOR
-- ═══════════════════════════════════════════════════════════════════════════════

--- Generate a complete terminal grid from a preset.
-- @param presetName string Key into ix.hacking.Presets.
-- @param overrides table|nil Optional difficulty overrides merged onto the preset.
-- @return table {gridText, tokens, solution, addresses, preset, lines, width, effectLimits}
function ix.hacking.Generator.Generate(presetName, overrides)
    local preset = table.Copy(ix.hacking.Presets[presetName] or ix.hacking.Presets.average)

    if (overrides) then
        table.Merge(preset, overrides)
    end

    local wordsNeeded = math.random(preset.candidateWords.min, preset.candidateWords.max)
    local wLen        = preset.wordLength
    local lines       = preset.grid.lineCount
    local width       = preset.grid.lineWidth

    ---------------------------------------------------------------------------
    -- 1. Occupancy & line buffer
    ---------------------------------------------------------------------------
    local occupancy  = {}
    local lineBuffer = {}

    for i = 1, lines do
        occupancy[i]  = {}
        lineBuffer[i] = {}
        for j = 1, width do
            occupancy[i][j]  = false
            lineBuffer[i][j] = false
        end
    end

    local function IsRangeFree(line, start, len, requiresGap)
        if (start < 1 or (start + len - 1) > width) then return false end

        for c = start, start + len - 1 do
            if (occupancy[line][c]) then return false end
        end

        if (requiresGap) then
            if (start > 1 and occupancy[line][start - 1]) then return false end
            if ((start + len) <= width and occupancy[line][start + len]) then return false end
        end

        return true
    end

    local function CommitRange(line, start, text)
        local len = string.len(text)
        for c = 1, len do
            occupancy[line][start + c - 1]  = true
            lineBuffer[line][start + c - 1] = string.sub(text, c, c)
        end
    end

    local tokens = {}
    local nextId = 1

    ---------------------------------------------------------------------------
    -- 2. Word selection
    ---------------------------------------------------------------------------
    local pickedWords  = {}
    local safeCounter  = 0

    while (#pickedWords < wordsNeeded and safeCounter < 300) do
        local w = GetRandomWord(wLen)
        if (!table.HasValue(pickedWords, w)) then
            table.insert(pickedWords, w)
        end
        safeCounter = safeCounter + 1
    end

    if (#pickedWords < 1) then
        table.insert(pickedWords, "FALL")
    end

    local solution = pickedWords[math.random(#pickedWords)]

    ---------------------------------------------------------------------------
    -- 3. Place words (priority 1)
    ---------------------------------------------------------------------------
    for _, word in ipairs(pickedWords) do
        local placed = false
        local tries  = 0

        while (!placed and tries < 200) do
            local ln       = math.random(1, lines)
            local maxStart = width - wLen + 1

            if (maxStart >= 1) then
                local col = math.random(1, maxStart)
                if (IsRangeFree(ln, col, wLen, true)) then
                    CommitRange(ln, col, word)
                    table.insert(tokens, {
                        id      = nextId,
                        kind    = "word",
                        text    = word,
                        line    = ln,
                        start   = col,
                        len     = wLen,
                        removed = false
                    })
                    nextId = nextId + 1
                    placed = true
                end
            end

            tries = tries + 1
        end
    end

    ---------------------------------------------------------------------------
    -- 4. Build effect/bracket queue
    ---------------------------------------------------------------------------
    local effectQueue = {}

    if (preset.effectLimits) then
        for effectName, count in pairs(preset.effectLimits) do
            if (effectName ~= "total" and type(count) == "number") then
                for i = 1, count do
                    table.insert(effectQueue, {type = "special", effect = effectName})
                end
            end
        end
    end

    local targetTotal  = preset.bracketTokens or 0
    local currentCount = #effectQueue

    if (currentCount < targetTotal) then
        for i = 1, targetTotal - currentCount do
            table.insert(effectQueue, {type = "bracket", effect = "remove_dud"})
        end
    end

    -- Sort so special effects get placed first
    table.sort(effectQueue, function(a, b)
        if (a.type == "special" and b.type ~= "special") then return true end
        if (a.type ~= "special" and b.type == "special") then return false end
        return false
    end)

    ---------------------------------------------------------------------------
    -- 5. Place brackets (priority 2)
    ---------------------------------------------------------------------------
    local failedCount = 0

    for _, item in ipairs(effectQueue) do
        local placed = false
        local tries  = 0

        while (!placed and tries < 100) do
            local ln     = math.random(1, lines)
            local maxLen = math.min(width, 14)
            local len    = math.random(2, maxLen)
            local col    = math.random(1, width - len + 1)
            local gap    = (tries < 50)

            if (IsRangeFree(ln, col, len, gap)) then
                local openers = {"(", "[", "{", "<"}
                local op = openers[math.random(#openers)]
                local cl = PAIRS[op]

                local content = op
                for k = 1, len - 2 do
                    content = content .. ix.hacking.SafeFillers[math.random(#ix.hacking.SafeFillers)]
                end
                content = content .. cl

                CommitRange(ln, col, content)

                table.insert(tokens, {
                    id       = nextId,
                    kind     = "bracket",
                    effect   = item.effect,
                    text     = content,
                    line     = ln,
                    start    = col,
                    len      = len,
                    consumed = false
                })
                nextId = nextId + 1
                placed = true
            end

            tries = tries + 1
        end

        if (!placed) then
            failedCount = failedCount + 1
        end
    end

    ---------------------------------------------------------------------------
    -- 6. Fill empty space with garbage
    ---------------------------------------------------------------------------
    for i = 1, lines do
        for j = 1, width do
            if (lineBuffer[i][j] == false) then
                lineBuffer[i][j] = ix.hacking.GarbageChars[math.random(#ix.hacking.GarbageChars)]
            end
        end
    end

    ---------------------------------------------------------------------------
    -- 7. Generate junk spans (priority 3)
    ---------------------------------------------------------------------------
    for i = 1, lines do
        local currentStart = 1
        while (currentStart <= width) do
            if (!occupancy[i][currentStart]) then
                local spanStart = currentStart
                local spanEnd   = spanStart

                while (spanEnd < width and !occupancy[i][spanEnd + 1]) do
                    spanEnd = spanEnd + 1
                end

                local spanText = ""
                for k = spanStart, spanEnd do
                    spanText = spanText .. (lineBuffer[i][k] or " ")
                end

                table.insert(tokens, {
                    id      = nextId,
                    kind    = "junk",
                    text    = spanText,
                    line    = i,
                    start   = spanStart,
                    len     = (spanEnd - spanStart + 1),
                    subtype = "junk_span"
                })
                nextId = nextId + 1
                currentStart = spanEnd + 1
            else
                currentStart = currentStart + 1
            end
        end
    end

    ---------------------------------------------------------------------------
    -- 8. Finalize
    ---------------------------------------------------------------------------
    local fullGrid = ""
    for i = 1, lines do
        fullGrid = fullGrid .. table.concat(lineBuffer[i], "")
    end

    local startAddr = 0x1000 + math.random(0, 500) * 16
    local addresses = {}
    for i = 1, lines do
        table.insert(addresses, string.format("0x%X", startAddr + (i - 1) * 16))
    end

    return {
        gridText     = fullGrid,
        tokens       = tokens,
        solution     = solution,
        addresses    = addresses,
        preset       = preset,
        lines        = lines,
        width        = width,
        effectLimits = preset.effectLimits
    }
end
