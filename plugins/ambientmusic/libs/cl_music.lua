
ix.music = ix.music or {}

-- Client-side state cache (mirrored from server broadcasts)
ix.music.clientState = {
    circumstance   = "ambient",  -- current circumstance tag
    isForcePlaying = false,       -- true while a GM-forced track/playlist is playing
    queue          = {},          -- mirror of server queue; consumed as tracks end
    currentTrack   = nil,         -- the currently GM-forced track entry (table or nil)
}

-- Returns true if the path is an internet URL
function ix.music.IsURL(path)
    if !path then return false end
    return path:sub(1, 7) == "http://" or path:sub(1, 8) == "https://"
end

-- Normalise a track entry to the full table form.
-- Accepts either a bare string or a table { path, theme, duration, title }.
-- Strips an accidental "sound/" prefix from local file paths.
function ix.music.NormalizeTrack(entry)
    local t = {}

    if type(entry) == "string" then
        t.path  = entry
        t.theme = "ambient"
    elseif type(entry) == "table" then
        t.path     = entry.path or ""
        t.theme    = entry.theme or "ambient"
        t.duration = entry.duration
        t.title    = entry.title
    else
        return nil
    end

    -- Strip accidental "sound/" prefix for local paths
    if !ix.music.IsURL(t.path) and t.path:sub(1, 6) == "sound/" then
        t.path = t.path:sub(7)
    end

    if t.path == "" then return nil end
    return t
end
