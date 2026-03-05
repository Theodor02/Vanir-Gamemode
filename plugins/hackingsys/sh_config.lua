--- Shared configuration: presets, word lists, garbage characters, sounds.
-- @module ix.hacking

ix.hacking = ix.hacking or {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- DIFFICULTY PRESETS
-- ═══════════════════════════════════════════════════════════════════════════════

ix.hacking.Presets = {
    very_easy = {
        wordLength = 4,
        candidateWords = {min = 10, max = 12},
        grid = {lineCount = 16, lineWidth = 18},
        bracketTokens = 10,
        effectLimits = {remove_dud = 2, reset_attempts = 2, total = nil}
    },
    easy = {
        wordLength = 5,
        candidateWords = {min = 12, max = 13},
        grid = {lineCount = 17, lineWidth = 19},
        bracketTokens = 9,
        effectLimits = {remove_dud = 2, reset_attempts = 1, total = nil}
    },
    average = {
        wordLength = 6,
        candidateWords = {min = 13, max = 14},
        grid = {lineCount = 18, lineWidth = 20},
        bracketTokens = 8,
        effectLimits = {remove_dud = 2, reset_attempts = 1, total = nil}
    },
    hard = {
        wordLength = 7,
        candidateWords = {min = 14, max = 15},
        grid = {lineCount = 19, lineWidth = 21},
        bracketTokens = 7,
        effectLimits = {remove_dud = 1, reset_attempts = 1, total = nil}
    },
    very_hard = {
        wordLength = 8,
        candidateWords = {min = 15, max = 15},
        grid = {lineCount = 20, lineWidth = 22},
        bracketTokens = 6,
        effectLimits = {remove_dud = 1, reset_attempts = 0, total = nil}
    }
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- WORD LISTS (keyed by word length)
-- ═══════════════════════════════════════════════════════════════════════════════

ix.hacking.WordList = {
    [4] = {
        "DATA", "NODE", "PORT", "GRID", "LINK", "SYNC", "CORE", "LOCK", "KEYS", "MASK",
        "HASH", "ROOT", "SEED", "FUSE", "CELL", "BAND", "WAVE", "SIGN", "MODE", "STAT",
        "TASK", "LOAD", "SAVE", "SCAN", "READ", "WRIT", "EXEC", "AUTH", "ROLE", "USER",
        "HOST", "ADDR", "PATH", "TURN", "MOVE", "FLOW", "VENT", "PIPE", "DUCT", "SEAL",
        "DOCK", "BAYE", "LIFT", "DOOR", "GATE", "RAMP", "POST", "ZONE", "AREA", "LINE",
        "UNIT", "DESK", "FILE", "FORM", "NOTE", "LOGS", "ARCH", "COPY", "SEND", "HOLD",
        "WAIT", "PASS", "MARK", "FLAG", "TAGG", "BIND", "PAIR", "JOIN", "SPLT",
        "SORT", "RATE", "TIER", "STEP", "PHAS", "LOOP", "ROLL"
    },

    [5] = {
        "ARRAY", "STACK", "QUEUE", "CACHE", "TRACE", "PROXY", "ROUTE", "PACKT", "INDEX",
        "FIELD", "TABLE", "QUERY", "LOGIC", "INPUT", "STORE", "MERGE", "SPLIT",
        "PATCH", "RESET", "POWER", "LEVEL", "LIMIT", "RANGE", "SCALE", "GRADE", "CLASS",
        "ORDER", "CHAIN", "BLOCK", "FRAME", "STRUT", "BRACE", "PLATE", "SEAMS", "ARMOR",
        "OPTIC", "RADAR", "SONIC", "AUDIO", "VISOR", "SCOPE", "LASER", "VALVE",
        "INTAK", "EXHST", "PIPES", "DUCTS", "VENTS", "COILS", "CELLS", "BANKS",
        "DEPOT", "CARGO", "FRENT", "MANIF", "DOCKS", "HUBES", "ZONES", "SECTN", "AREAS",
        "FILES", "FORMS", "PERMT", "NOTES", "AUDIT", "STAMP", "SEALS", "REGIS",
        "LEDGR", "ENTRY", "TOKEN", "CREDT", "VOUCH", "CLAIM", "ISSUE"
    },

    [6] = {
        "ACCESS", "DENIED", "LOCKED", "VERIFY", "CONFIR", "SECURE", "BREACH",
        "FILTER", "BUFFER", "MEMORY", "STORAG", "THREAD", "MODULE", "DRIVER",
        "SIGNAL", "VECTOR", "MATRIX", "SECTOR", "REGION", "DOMAIN",
        "UPLINK", "RELAY", "BEACON", "RECEIV", "TRANSM", "ENCODE", "DECODE",
        "CIPHER", "KEYSET", "KEYMAP", "KEYRNG", "KEYLOG", "ENGINE", "REACTR", "COOLER",
        "INTAKE", "VENTIL", "SHIELD", "PLASMA", "ENERGY", "CAPTOR", "FOCUS",
        "TARGET", "PAYLOD", "STABLE", "OUTPUT", "BALANC", "TUNING", "REGULA", "FLOWCT",
        "PRESSR", "THERML", "OVERHT", "FAILSF", "SAFETY", "REDUND", "BACKUP", "RESERV",
        "ROUTER", "SWITCH", "HUBCTL", "PORTAL", "GATEWY", "PASSGE", "CHECKP", "SCREEN",
        "INSPEC", "SURVEY", "PATROL", "ESCORT", "CUSTDY", "ARCHIV", "LOGREC",
        "LEDGER", "BUDGET", "QUOTAS", "ASSIGN", "DISPAT"
    },

    [7] = {
        "TERMINL", "SECURED", "FIREWAL", "MONITOR", "WATCHER",
        "AUDITOR", "TIMEOUT", "FAILURE", "RECOVER", "EXECUTE", "PIPELIN",
        "SCHEDUL", "ALLOCAT", "PRIORIT", "ISOLATE", "SANDBOX", "CONTAIN",
        "CLEARAN", "AUTHENT", "CIPHERS", "KEYRING", "KEYNODE", "KEYPATH", "DATAPAK",
        "DATACON", "ARCHIVE", "LOGBOOK", "REGISTR", "CATALOG", "INDEXER", "TRACKER",
        "SCANNER", "DETECTR", "ANALYZE", "SIMULAT", "EMULATE", "REACTOR",
        "COOLANT", "OVERHEA", "STANDBY",
        "FEEDER", "SUBNETS", "ZONEMAP", "SECTORL",
        "WAYNODE", "PATHING", "NAVDATA", "ASTROPT", "ORBCTRL", "DOCKING", "HANGARS",
        "TRAFFIC", "CLEARLY", "ESCALAT", "REQUEST", "APPROVE",
        "DENIALS", "REVIEWS", "SANCTON", "MANDATE",
        "BULLETN", "NOTICE", "BRIEFNG", "DOSSIER",
        "CASEFIL", "EVIDENC", "INQUEST", "OVERSIT", "INSPECT", "ENFORCE"
    },

    [8] = {
        "TERMINAL", "SECURITY", "PROTOCOL", "OVERRIDE", "RESTRICT", "LOCKDOWN",
        "DIAGNOST", "ANALYSIS", "OPTIMIZE", "CALIBRAT", "STABILIZ", "CONVERGE", "REGULATE", "MODULATE",
        "EMISSION", "TRANSMIT", "AMPLIFY", "ATTENUAT", "FREQUENC",
        "WAVELENG", "SPECTRAL", "HOLOGRAM", "RENDERER",
        "NAVCOMPS", "ASTROGAT", "COORDSYS", "WAYPOINT", "TRAJECT", "ORBITALS",
        "DOCKCTRL", "HANGCTRL", "LIFESUPP", "ENVIRONM", "PRESSURE", "ATMOSPHR",
        "INERTIAL", "DAMPENER", "STRUCTUR", "FRAMEWRK", "HARDPOINT",
        "INFRASTR", "FACILITY", "DISTRIBU", "PIPELINE", "TRANSITN",
        "LOGISTIC", "WAREHOUS", "ALLOCATE", "DISPATCH", "SCHEDULR", "MANIFEST",
        "CLEARING", "PROCESSR", "VALIDATE", "COMPLIAN", "ENFORCER", "DIRECTIV",
        "ADMINIST", "AUDITING", "REGISTRY", "ARCHIVAL",
        "CLASSIFY", "SANCTION", "MANDATED", "CONTINGE", "EMERGENC", "FAILOVER", "STABILITY"
    }
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- FILLER / GARBAGE CHARACTERS
-- ═══════════════════════════════════════════════════════════════════════════════

ix.hacking.GarbageChars = {
    "!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "-", "_", "+", "=",
    "[", "]", "{", "}", "|", "\\", ";", ":", "'", "\"", ",", ".", "/", "<", ">", "?"
}

ix.hacking.SafeFillers = {
    "!", "\"", "#", "$", "%", "&", "'", "*", "+", ",", "-", ".", "/",
    ":", ";", "=", "?", "@", "\\", "^", "_", "`", "|", "~"
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- SOUNDS
-- ═══════════════════════════════════════════════════════════════════════════════

ix.hacking.Sounds = {
    Hover = "everfall/miscellaneous/ux/navigation/navigation_carousel_01.mp3",
    Click = "everfall/miscellaneous/ux/navigation/navigation_activate_01.mp3",
    Enter = "everfall/miscellaneous/ux/navigation/navigation_matchmaking_01.mp3",
    Deny  = "everfall/miscellaneous/ux/navigation/navigation_error_01.mp3"
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- SHARED HELPERS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Calculate character-by-character likeness between two equal-length words.
-- @param wordA string
-- @param wordB string
-- @return number Number of matching character positions.
function ix.hacking.CalculateLikeness(wordA, wordB)
    local len = string.len(wordA)
    if (string.len(wordB) ~= len) then return 0 end

    local matches = 0
    for i = 1, len do
        if (string.sub(wordA, i, i) == string.sub(wordB, i, i)) then
            matches = matches + 1
        end
    end

    return matches
end
