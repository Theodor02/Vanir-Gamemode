--- Symptom Registry & Application Library
-- Provides the ix.symptom API for registering reusable symptoms that can be
-- shared across multiple diseases. Symptoms define /me actions, visual effects,
-- sounds, and contagion behaviour.
-- @module ix.symptom

ix.symptom = ix.symptom or {}
ix.symptom._registered = ix.symptom._registered or {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- REGISTRATION
-- ═══════════════════════════════════════════════════════════════════════════════

--- Register a new symptom type.
-- @param id string Unique symptom identifier (e.g. "cough", "vomit", "fever")
-- @param config table Symptom definition containing:
--   message (string) — notification shown to the afflicted player
--   me_actions (table of strings) — random /me action variations
--   effect (string) — particle effect name to dispatch
--   soundPath (string|table) — sound path or table of paths for random pick
--   soundVolume (number 0-1) — playback volume
--   soundPitch (number) — playback pitch
--   contagionRange (number) — Source units; triggers contagion check on nearby players
--   damage (number) — fraction of max health dealt per application
--   visual (table) — client-side visual filter config (one-shot, triggered with symptom)
--   notification (bool) — if true, only shows a text notification (no /me)
--   cooldown (number) — override default symptom cooldown in seconds
--   speedReduction (number 0-1) — movement speed multiplier reduction
--   clientEvent (string) — special client event to trigger
--   clientEventData (table) — data payload for the client event
function ix.symptom.Register(id, config)
    if (!id or !config) then
        ErrorNoHalt("[SmartDisease] Attempted to register symptom with nil id or config.\n")
        return
    end

    config.id = id
    ix.symptom._registered[id] = config
end

--- Get a registered symptom by ID.
-- @param id string Symptom identifier
-- @return table|nil Symptom config
function ix.symptom.Get(id)
    return ix.symptom._registered[id]
end

--- Get all registered symptoms.
-- @return table Dictionary of {id = config}
function ix.symptom.GetAll()
    return ix.symptom._registered
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SYMPTOM DEFINITIONS
-- ═══════════════════════════════════════════════════════════════════════════════

-- ─── Respiratory ─────────────────────────────────────────────────────────────

ix.symptom.Register("cough", {
    message = "You cough.",
    me_actions = {
        "coughs",
        "coughs violently",
        "coughs into their elbow",
        "coughs while covering their mouth",
        "lets out a dry, hacking cough",
        "hacks and coughs, struggling to breathe",
    },
    effect = "smartdisease_cough",
    soundPath = {"ambient/voices/cough1.wav", "ambient/voices/cough2.wav", "ambient/voices/cough3.wav", "ambient/voices/cough4.wav"},
    soundVolume = 0.6,
    soundPitch = 100,
    contagionRange = 150,
    visual = {
        shake = true,
        shakeIntensity = 0.8,
    },
})

ix.symptom.Register("cough_blood", {
    message = "You cough up blood.",
    me_actions = {
        "coughs up blood",
        "hacks violently, blood splattering from their mouth",
        "coughs into their hand — it comes away bloody",
        "doubles over in a coughing fit, blood on their lips",
    },
    effect = "smartdisease_cough",
    soundPath = {"ambient/voices/cough1.wav", "ambient/voices/cough2.wav"},
    soundVolume = 0.7,
    soundPitch = 90,
    contagionRange = 150,
    damage = 0.03,
    visual = {
        colormod = Color(255, 80, 80, 255),
        colormodIntensity = 0.25,
        shake = true,
        shakeIntensity = 1.5,
    },
})

ix.symptom.Register("sneeze", {
    message = "You sneeze.",
    me_actions = {
        "sneezes",
        "sneezes loudly",
        "sneezes into their hands",
        "sneezes and wipes their nose",
        "lets out a sudden, violent sneeze",
    },
    effect = "smartdisease_sneeze",
    soundPath = {"disease/sneeze01.wav", "disease/sneeze02.wav"},
    soundVolume = 0.7,
    soundPitch = 100,
    contagionRange = 200,
})

ix.symptom.Register("congestion", {
    message = "Your nose feels blocked and heavy.",
    me_actions = {
        "sniffles",
        "clears their throat",
        "breathes heavily through their mouth",
        "wipes their running nose",
    },
    visual = {
        blur = true,
        blurIntensity = 0.15,
    },
})

ix.symptom.Register("wheeze", {
    message = "You wheeze with laboured breathing.",
    me_actions = {
        "wheezes",
        "breathes with a rattling sound",
        "struggles to catch their breath",
        "gasps for air between rattling breaths",
        "wheezes painfully, each breath a struggle",
    },
    soundPath = "npc/zombie/zombie_voice_idle1.wav",
    soundVolume = 0.35,
    soundPitch = 140,
    visual = {
        blur = true,
        blurIntensity = 0.3,
        vignette = true,
        vignetteIntensity = 0.15,
    },
    speedReduction = 0.15,
})

ix.symptom.Register("laboured_breathing", {
    message = "Every breath is a struggle.",
    me_actions = {
        "gasps and wheezes, barely able to breathe",
        "clutches their chest, fighting for each breath",
        "makes a horrible gurgling sound with each breath",
    },
    soundPath = "npc/zombie/zombie_voice_idle3.wav",
    soundVolume = 0.4,
    soundPitch = 130,
    visual = {
        blur = true,
        blurIntensity = 0.6,
        vignette = true,
        vignetteIntensity = 0.3,
        colormod = Color(180, 180, 220, 255),
        colormodIntensity = 0.2,
    },
    speedReduction = 0.35,
    damage = 0.02,
})

-- ─── Gastrointestinal ────────────────────────────────────────────────────────

ix.symptom.Register("vomit", {
    message = "You begin vomiting.",
    me_actions = {
        "vomits",
        "retches and vomits",
        "doubles over and vomits",
        "gags and throws up",
        "vomits violently onto the ground",
    },
    effect = "smartdisease_vomit",
    soundPath = {"disease/vomit01.wav", "disease/vomit02.wav", "disease/vomit03.wav"},
    soundVolume = 0.7,
    soundPitch = 100,
    damage = 0.05,
    contagionRange = 100,
    visual = {
        colormod = Color(150, 180, 100, 255),
        colormodIntensity = 0.2,
        shake = true,
        shakeIntensity = 2,
    },
})

ix.symptom.Register("blood_vomit", {
    message = "You vomit blood.",
    me_actions = {
        "vomits blood",
        "retches violently, vomiting dark blood",
        "doubles over, coughing up bright red blood",
    },
    effect = "smartdisease_vomit",
    soundPath = {"disease/vomit01.wav", "disease/vomit02.wav", "disease/vomit03.wav"},
    soundVolume = 0.8,
    soundPitch = 90,
    damage = 0.08,
    contagionRange = 80,
    visual = {
        colormod = Color(255, 60, 60, 255),
        colormodIntensity = 0.35,
        shake = true,
        shakeIntensity = 2.5,
        vignette = true,
        vignetteIntensity = 0.25,
    },
})

ix.symptom.Register("nausea", {
    message = "You feel nauseous.",
    me_actions = {
        "looks pale and unwell",
        "holds their stomach uncomfortably",
        "grimaces with nausea",
        "sways slightly, looking green",
    },
    visual = {
        colormod = Color(160, 200, 130, 255),
        colormodIntensity = 0.2,
        blur = true,
        blurIntensity = 0.2,
    },
})

ix.symptom.Register("diarrhea", {
    message = "Your stomach cramps painfully.",
    me_actions = {
        "clutches their stomach in discomfort",
        "winces and holds their abdomen",
        "grimaces, pressing a hand to their gut",
    },
    soundPath = {"disease/shit01.wav", "disease/shit02.wav", "disease/shit03.wav"},
    soundVolume = 0.4,
    soundPitch = 100,
    damage = 0.03,
    visual = {
        shake = true,
        shakeIntensity = 0.5,
    },
})

ix.symptom.Register("stomach_cramps", {
    message = "Intense cramps grip your abdomen.",
    me_actions = {
        "doubles over with stomach cramps",
        "grabs their stomach and groans",
        "buckles from a wave of abdominal pain",
    },
    damage = 0.02,
    visual = {
        shake = true,
        shakeIntensity = 1,
    },
})

-- ─── Neurological / General ──────────────────────────────────────────────────

ix.symptom.Register("malaise", {
    message = "You feel unwell... something isn't right.",
    notification = true,
})

ix.symptom.Register("headache", {
    message = "You have a pounding headache.",
    me_actions = {
        "rubs their temples",
        "winces from a headache",
        "holds their head in pain",
        "squeezes their eyes shut from the pain in their skull",
    },
    visual = {
        blur = true,
        blurIntensity = 0.4,
        sharpen = true,
        sharpenIntensity = 0.5,
    },
})

ix.symptom.Register("migraine", {
    message = "A blinding migraine splits through your skull.",
    me_actions = {
        "clutches their head, blinded by pain",
        "staggers from an agonizing migraine",
        "presses both hands against their temples, groaning",
    },
    visual = {
        blur = true,
        blurIntensity = 0.8,
        bloom = true,
        bloomIntensity = 1.5,
        sharpen = true,
        sharpenIntensity = 1.0,
        shake = true,
        shakeIntensity = 1,
    },
    damage = 0.01,
    speedReduction = 0.2,
})

ix.symptom.Register("fever", {
    message = "You feel feverish.",
    me_actions = {
        "shakes and shivers",
        "is drenched in sweat",
        "trembles with a high fever",
        "wipes sweat from their brow",
        "shivers despite being drenched in sweat",
    },
    visual = {
        colormod = Color(255, 140, 90, 255),
        colormodIntensity = 0.25,
        bloom = true,
        bloomIntensity = 0.5,
    },
})

ix.symptom.Register("high_fever", {
    message = "Your fever is dangerously high.",
    me_actions = {
        "shakes violently, burning with fever",
        "is drenched in sweat, barely conscious",
        "mumbles incoherently through chattering teeth",
    },
    visual = {
        colormod = Color(255, 100, 60, 255),
        colormodIntensity = 0.4,
        bloom = true,
        bloomIntensity = 1.0,
        blur = true,
        blurIntensity = 0.4,
        shake = true,
        shakeIntensity = 0.5,
    },
    damage = 0.03,
    speedReduction = 0.2,
})

ix.symptom.Register("chills", {
    message = "You feel cold and clammy.",
    me_actions = {
        "shivers uncontrollably",
        "wraps their arms around themselves",
        "trembles from the cold",
        "shakes with violent chills despite the temperature",
    },
    visual = {
        colormod = Color(180, 200, 240, 255),
        colormodIntensity = 0.15,
        shake = true,
        shakeIntensity = 0.3,
    },
})

ix.symptom.Register("dizziness", {
    message = "The world spins around you.",
    me_actions = {
        "stumbles with dizziness",
        "sways unsteadily on their feet",
        "grabs onto something for balance",
        "staggers sideways, disoriented",
    },
    visual = {
        shake = true,
        shakeIntensity = 2,
        blur = true,
        blurIntensity = 0.5,
    },
    speedReduction = 0.15,
})

ix.symptom.Register("confusion", {
    message = "Your thoughts feel muddled and disjointed.",
    me_actions = {
        "stares blankly into space",
        "mutters incoherently",
        "looks around in confusion",
        "blinks slowly, as if struggling to understand their surroundings",
    },
    visual = {
        blur = true,
        blurIntensity = 0.8,
        colormod = Color(180, 170, 200, 255),
        colormodIntensity = 0.15,
    },
})

ix.symptom.Register("delirium", {
    message = "Reality is slipping away from you.",
    me_actions = {
        "mumbles incoherently, staring at nothing",
        "reaches out toward something invisible",
        "babbles deliriously, drenched in sweat",
        "thrashes weakly, lost in a fever dream",
    },
    visual = {
        blur = true,
        blurIntensity = 1.2,
        colormod = Color(200, 160, 120, 255),
        colormodIntensity = 0.35,
        shake = true,
        shakeIntensity = 1.5,
        waterWarp = true,
        waterWarpIntensity = 0.3,
        bloom = true,
        bloomIntensity = 1.0,
    },
    damage = 0.02,
    speedReduction = 0.3,
})

ix.symptom.Register("fatigue", {
    message = "You feel exhausted.",
    me_actions = {
        "looks exhausted",
        "yawns deeply",
        "struggles to keep their eyes open",
        "leans against something, barely standing",
    },
    speedReduction = 0.1,
})

ix.symptom.Register("extreme_fatigue", {
    message = "Your body feels like lead. Every movement is agony.",
    me_actions = {
        "can barely keep their eyes open",
        "slumps, fighting to stay upright",
        "shuffles forward sluggishly, completely drained",
    },
    visual = {
        vignette = true,
        vignetteIntensity = 0.2,
        desaturate = true,
        desaturateIntensity = 0.3,
    },
    speedReduction = 0.35,
})

ix.symptom.Register("paralysis", {
    message = "Your limbs feel heavy and unresponsive.",
    me_actions = {
        "staggers, barely able to move",
        "drags their feet sluggishly",
        "struggles to lift their arms",
        "moves in jerky, uncoordinated motions",
    },
    speedReduction = 0.5,
    visual = {
        vignette = true,
        vignetteIntensity = 0.15,
    },
})

ix.symptom.Register("severe_paralysis", {
    message = "You can barely move. Your body is shutting down.",
    me_actions = {
        "can barely crawl forward",
        "collapses, their limbs completely unresponsive",
        "lies trembling, unable to stand",
    },
    speedReduction = 0.75,
    damage = 0.02,
    visual = {
        vignette = true,
        vignetteIntensity = 0.3,
        blur = true,
        blurIntensity = 0.5,
        desaturate = true,
        desaturateIntensity = 0.4,
    },
})

ix.symptom.Register("seizure", {
    message = "Your body convulses uncontrollably!",
    me_actions = {
        "seizes up and convulses violently",
        "collapses, their body shaking uncontrollably",
        "thrashes on the ground in a seizure",
    },
    visual = {
        shake = true,
        shakeIntensity = 5,
        screenFlicker = true,
        flickerRate = 8,
        blur = true,
        blurIntensity = 1.5,
    },
    damage = 0.05,
    speedReduction = 0.8,
    cooldown = 45,
})

ix.symptom.Register("tinnitus", {
    message = "A high-pitched ringing fills your ears.",
    me_actions = {
        "shakes their head, as if trying to clear a sound",
        "presses a hand to their ear",
    },
    clientEvent = "tinnitus",
    clientEventData = {duration = 8},
})

ix.symptom.Register("body_aches", {
    message = "Your whole body aches.",
    me_actions = {
        "groans and stretches uncomfortably",
        "rubs their aching muscles",
        "winces as they move, every joint protesting",
    },
})

ix.symptom.Register("loss_of_appetite", {
    message = "The thought of food makes you feel ill.",
    notification = true,
})

-- ─── Pain & Injury ──────────────────────────────────────────────────────────

ix.symptom.Register("pain_mild", {
    message = "You feel a dull ache.",
    me_actions = {
        "winces slightly",
        "grimaces in discomfort",
        "shifts uncomfortably",
    },
    soundPath = {"vo/npc/male01/pain01.wav", "vo/npc/male01/pain02.wav", "vo/npc/male01/pain03.wav"},
    soundVolume = 0.3,
    soundPitch = 100,
})

ix.symptom.Register("pain_severe", {
    message = "You are wracked with pain.",
    me_actions = {
        "clutches their body in pain",
        "cries out in agony",
        "doubles over from intense pain",
        "grits their teeth against the searing pain",
    },
    soundPath = {"vo/npc/male01/pain07.wav", "vo/npc/male01/pain08.wav", "vo/npc/male01/pain09.wav"},
    soundVolume = 0.5,
    soundPitch = 100,
    damage = 0.03,
    visual = {
        colormod = Color(255, 120, 120, 255),
        colormodIntensity = 0.15,
        shake = true,
        shakeIntensity = 1,
    },
})

ix.symptom.Register("pain_agonizing", {
    message = "Unbearable pain courses through your entire body.",
    me_actions = {
        "screams in agony",
        "collapses, writhing in unbearable pain",
        "claws at themselves, trying to escape the pain",
    },
    soundPath = {"vo/npc/male01/pain07.wav", "vo/npc/male01/pain08.wav"},
    soundVolume = 0.7,
    soundPitch = 90,
    damage = 0.05,
    visual = {
        colormod = Color(255, 80, 80, 255),
        colormodIntensity = 0.3,
        shake = true,
        shakeIntensity = 3,
        vignette = true,
        vignetteIntensity = 0.25,
        screenFlicker = true,
        flickerRate = 3,
    },
    speedReduction = 0.4,
})

ix.symptom.Register("bleeding", {
    message = "You are bleeding.",
    me_actions = {
        "is bleeding visibly",
        "presses a hand against a wound",
        "is staining their clothes with blood",
    },
    effect = "smartdisease_bleed",
    visual = {
        colormod = Color(255, 100, 100, 255),
        colormodIntensity = 0.2,
        vignette = true,
        vignetteIntensity = 0.1,
    },
    damage = 0.05,
})

ix.symptom.Register("haemorrhage", {
    message = "You are haemorrhaging badly.",
    me_actions = {
        "is bleeding profusely from multiple orifices",
        "is drenched in their own blood",
        "bleeds from their eyes and nose",
    },
    effect = "smartdisease_bleed",
    visual = {
        colormod = Color(255, 50, 50, 255),
        colormodIntensity = 0.45,
        vignette = true,
        vignetteIntensity = 0.35,
        blur = true,
        blurIntensity = 0.5,
        desaturate = true,
        desaturateIntensity = 0.2,
    },
    damage = 0.1,
    speedReduction = 0.3,
})

ix.symptom.Register("eye_bleed", {
    message = "Blood seeps from your eyes.",
    me_actions = {
        "bleeds from their eyes",
        "wipes blood from their eyes, but it keeps coming",
        "has rivulets of blood running down their cheeks from their eyes",
    },
    visual = {
        colormod = Color(255, 0, 0, 255),
        colormodIntensity = 0.4,
        blur = true,
        blurIntensity = 0.8,
        vignette = true,
        vignetteIntensity = 0.3,
    },
    damage = 0.04,
})

-- ─── Skin / External ─────────────────────────────────────────────────────────

ix.symptom.Register("rash", {
    message = "An angry rash spreads across your skin.",
    me_actions = {
        "scratches at a spreading rash",
        "examines an angry red rash on their arm",
    },
})

ix.symptom.Register("boils", {
    message = "Painful boils have formed on your skin.",
    me_actions = {
        "winces as a boil is pressed",
        "gingerly touches a swollen, angry boil",
    },
    damage = 0.01,
})

ix.symptom.Register("skin_lesions", {
    message = "Open sores weep on your skin.",
    me_actions = {
        "has visible open sores on their exposed skin",
        "tries to cover weeping lesions with their clothing",
    },
    damage = 0.02,
    contagionRange = 60,
})

ix.symptom.Register("throat_membrane", {
    message = "A thick membrane is forming in your throat.",
    me_actions = {
        "gags, struggling against something in their throat",
        "claws at their throat, fighting to breathe",
    },
    visual = {
        vignette = true,
        vignetteIntensity = 0.15,
    },
    speedReduction = 0.1,
})

-- ─── Psychological — Anxiety & Panic ─────────────────────────────────────────

ix.symptom.Register("anxiety", {
    message = "Your heart races with anxiety.",
    me_actions = {
        "fidgets nervously",
        "looks around anxiously",
        "wrings their hands",
        "taps their foot rapidly, eyes darting",
    },
    visual = {
        shake = true,
        shakeIntensity = 0.3,
        vignette = true,
        vignetteIntensity = 0.08,
    },
})

ix.symptom.Register("rising_dread", {
    message = "A terrible sense of dread washes over you. Something awful is about to happen.",
    me_actions = {
        "freezes, their eyes widening with dread",
        "trembles, a look of mounting terror on their face",
        "backs up involuntarily, their breath quickening",
    },
    visual = {
        shake = true,
        shakeIntensity = 0.5,
        vignette = true,
        vignetteIntensity = 0.15,
        desaturate = true,
        desaturateIntensity = 0.15,
    },
    clientEvent = "heartbeat",
    clientEventData = {duration = 12, volume = 0.3, speed = 1.2},
})

ix.symptom.Register("panic", {
    message = "You feel sudden overwhelming terror.",
    me_actions = {
        "hyperventilates",
        "backs away in terror",
        "crouches down, gripping their head",
        "screams and flails in blind panic",
    },
    visual = {
        shake = true,
        shakeIntensity = 3,
        blur = true,
        blurIntensity = 0.8,
        vignette = true,
        vignetteIntensity = 0.35,
        desaturate = true,
        desaturateIntensity = 0.3,
        screenFlicker = true,
        flickerRate = 4,
    },
    speedReduction = 0.3,
    clientEvent = "heartbeat",
    clientEventData = {duration = 20, volume = 0.7, speed = 1.8},
})

ix.symptom.Register("panic_peak", {
    message = "THIS IS IT. YOU ARE DYING. YOU CANNOT BREATHE.",
    me_actions = {
        "collapses, hyperventilating uncontrollably",
        "screams in absolute terror, clutching their chest",
        "thrashes wildly, completely lost to panic",
        "curls into a ball, shaking and sobbing",
    },
    visual = {
        shake = true,
        shakeIntensity = 5,
        blur = true,
        blurIntensity = 1.5,
        vignette = true,
        vignetteIntensity = 0.5,
        desaturate = true,
        desaturateIntensity = 0.5,
        screenFlicker = true,
        flickerRate = 6,
        bloom = true,
        bloomIntensity = 2.0,
    },
    damage = 0.02,
    speedReduction = 0.6,
    clientEvent = "heartbeat",
    clientEventData = {duration = 25, volume = 1.0, speed = 2.2},
    cooldown = 40,
})

ix.symptom.Register("hyperventilate", {
    message = "You are hyperventilating. You can't get enough air.",
    me_actions = {
        "hyperventilates, gasping rapidly",
        "pants desperately, unable to slow their breathing",
        "gulps air in rapid, shallow breaths",
    },
    visual = {
        blur = true,
        blurIntensity = 0.6,
        bloom = true,
        bloomIntensity = 1.0,
        vignette = true,
        vignetteIntensity = 0.2,
    },
    clientEvent = "heartbeat",
    clientEventData = {duration = 10, volume = 0.4, speed = 1.5},
})

ix.symptom.Register("chest_tightness", {
    message = "Your chest feels like it's being crushed.",
    me_actions = {
        "clutches their chest, gasping",
        "presses both hands to their sternum in pain",
        "winces, gripping the front of their shirt",
    },
    visual = {
        vignette = true,
        vignetteIntensity = 0.2,
    },
    damage = 0.01,
})

ix.symptom.Register("depersonalization", {
    message = "Nothing feels real. You are disconnected from your own body.",
    me_actions = {
        "stares at their own hands as if seeing them for the first time",
        "moves slowly, as if underwater",
        "looks around with a vacant, disconnected expression",
    },
    visual = {
        desaturate = true,
        desaturateIntensity = 0.6,
        blur = true,
        blurIntensity = 0.4,
        bloom = true,
        bloomIntensity = 0.8,
    },
    speedReduction = 0.2,
})

ix.symptom.Register("cold_sweat", {
    message = "You break out in a cold sweat.",
    me_actions = {
        "breaks out in a cold sweat",
        "wipes cold sweat from their forehead",
        "shivers despite being drenched in sweat",
    },
    visual = {
        colormod = Color(180, 200, 210, 255),
        colormodIntensity = 0.1,
    },
})

ix.symptom.Register("tremors", {
    message = "Your hands won't stop shaking.",
    me_actions = {
        "holds out their trembling hands",
        "tries and fails to hold something steady",
        "clenches their fists to stop the shaking",
    },
    visual = {
        shake = true,
        shakeIntensity = 0.8,
    },
})

-- ─── Psychological — Schizophrenia & Psychosis ──────────────────────────────

ix.symptom.Register("paranoia", {
    message = "They're watching you. They're ALL watching you.",
    me_actions = {
        "glances around suspiciously",
        "flinches at a sudden sound",
        "mutters about being followed",
        "eyes everyone with deep suspicion",
        "presses against a wall, watching the room",
    },
    visual = {
        colormod = Color(180, 170, 210, 255),
        colormodIntensity = 0.15,
        vignette = true,
        vignetteIntensity = 0.1,
        sharpen = true,
        sharpenIntensity = 0.3,
    },
})

ix.symptom.Register("paranoia_severe", {
    message = "THEY KNOW. They're coming for you. Trust NO ONE.",
    me_actions = {
        "presses against a wall, eyes wild with fear",
        "spins around suddenly, certain someone was behind them",
        "hisses at someone nearby, 'Stay away from me!'",
        "crouches defensively, scanning for threats only they perceive",
    },
    visual = {
        colormod = Color(160, 140, 200, 255),
        colormodIntensity = 0.25,
        vignette = true,
        vignetteIntensity = 0.2,
        sharpen = true,
        sharpenIntensity = 0.8,
        shake = true,
        shakeIntensity = 0.5,
    },
    speedReduction = 0.15,
})

ix.symptom.Register("hallucination", {
    message = "Something moves in the corner of your vision.",
    me_actions = {
        "stares at something only they can see",
        "swats at the air in front of them",
        "whispers to someone who isn't there",
        "recoils from an invisible threat",
        "follows something with their eyes that no one else can see",
    },
    visual = {
        colormod = Color(180, 100, 220, 255),
        colormodIntensity = 0.3,
        blur = true,
        blurIntensity = 0.5,
        waterWarp = true,
        waterWarpIntensity = 0.15,
    },
})

ix.symptom.Register("hallucination_severe", {
    message = "The shadows are alive. They're reaching for you.",
    me_actions = {
        "screams at something invisible",
        "cowers from shadows that seem to move",
        "has a full conversation with empty air",
        "laughs maniacally at nothing, then suddenly looks terrified",
    },
    visual = {
        colormod = Color(150, 70, 200, 255),
        colormodIntensity = 0.45,
        blur = true,
        blurIntensity = 1.0,
        waterWarp = true,
        waterWarpIntensity = 0.3,
        shake = true,
        shakeIntensity = 1.5,
        sobel = true,
        sobelThreshold = 0.3,
        screenFlicker = true,
        flickerRate = 2,
    },
    speedReduction = 0.2,
})

ix.symptom.Register("whispers", {
    message = "You hear whispering. It's coming from everywhere... and nowhere.",
    me_actions = {
        "tilts their head, listening to something",
        "covers their ears, muttering 'shut up, shut up'",
        "whirls around, 'Who said that?!'",
        "presses their palms against their ears",
    },
    clientEvent = "phantom_sound",
    clientEventData = {
        sounds = {"disease/voices01.wav", "disease/voices02.wav"},
        volume = 0.4,
        duration = 10,
    },
    visual = {
        vignette = true,
        vignetteIntensity = 0.1,
    },
})

ix.symptom.Register("loud_voices", {
    message = "THE VOICES ARE SCREAMING AT YOU. THEY WON'T STOP.",
    me_actions = {
        "grips their head, screaming for the voices to stop",
        "slams their fists against their own skull",
        "rocks back and forth, hands clamped over their ears",
        "pleads with the empty air to leave them alone",
    },
    clientEvent = "phantom_sound",
    clientEventData = {
        sounds = {"disease/voices01.wav", "disease/voices02.wav"},
        volume = 0.9,
        duration = 20,
    },
    visual = {
        shake = true,
        shakeIntensity = 2,
        vignette = true,
        vignetteIntensity = 0.25,
        colormod = Color(140, 80, 180, 255),
        colormodIntensity = 0.2,
    },
    damage = 0.01,
})

ix.symptom.Register("clone_hallucination", {
    message = "You see... yourself. Standing right there. Staring back at you.",
    me_actions = {
        "freezes, staring at something with abject horror",
        "stumbles backward, pointing at nothing",
        "whispers 'That's... that's me...' while staring into space",
    },
    clientEvent = "clone",
    clientEventData = {duration = 8},
    visual = {
        colormod = Color(160, 120, 200, 255),
        colormodIntensity = 0.3,
        blur = true,
        blurIntensity = 0.3,
    },
})

ix.symptom.Register("eye_distort", {
    message = "Your vision jerks violently.",
    me_actions = {
        "twitches, their eyes rolling briefly",
        "jerks their head involuntarily",
    },
    clientEvent = "eye_distort",
    clientEventData = {intensity = 15},
})

ix.symptom.Register("shadow_presence", {
    message = "Something is standing behind you. Don't turn around.",
    me_actions = {
        "freezes, sensing something behind them",
        "slowly turns, dread written across their face",
        "whispers 'It's here again...'",
    },
    visual = {
        vignette = true,
        vignetteIntensity = 0.2,
        colormod = Color(100, 80, 120, 255),
        colormodIntensity = 0.2,
        desaturate = true,
        desaturateIntensity = 0.3,
    },
})

ix.symptom.Register("fleeting_thought", {
    message = nil, -- Dynamically set
    notification = true,
    me_actions = {
        "blinks suddenly, distracted by something",
        "pauses mid-sentence, a strange look crossing their face",
        "mutters something under their breath",
    },
    clientEvent = "fleeting_thought",
    clientEventData = {
        thoughts = {
            "Did you lock the door?",
            "Something's not right here...",
            "Are they talking about you?",
            "You forgot something important.",
            "Don't trust them.",
            "They're lying to you.",
            "You should leave. Now.",
            "This happened before. Didn't it?",
            "Check behind you.",
            "Someone's watching.",
            "That's not how it's supposed to be.",
            "You made a mistake.",
            "They know what you did.",
            "It's not safe here.",
            "You can't remember why you came here.",
        },
    },
})

ix.symptom.Register("intrusive_thought", {
    message = nil, -- Dynamically set
    notification = true,
    me_actions = {
        "flinches as if struck by an invisible force",
        "shakes their head violently, trying to clear their thoughts",
    },
    clientEvent = "intrusive_thought",
    clientEventData = {
        thoughts = {
            "Kill them. Kill them all. They deserve it.",
            "Nobody is real. This is all a dream.",
            "They replaced your family. Those aren't really them.",
            "The walls are breathing. Can't you hear them?",
            "Your skin is wrong. It doesn't belong to you.",
            "They put something inside you. You can feel it moving.",
            "Everyone you love is already dead.",
            "You're not real. You never were.",
            "Something is growing inside your head.",
            "The floor is opening up beneath you.",
            "Your hands... those aren't YOUR hands.",
            "They're pretending not to see it. They ALL see it.",
        },
    },
})

ix.symptom.Register("screen_flash", {
    message = "Your vision cuts to black for a moment.",
    clientEvent = "screen_flash",
    clientEventData = {duration = 0.5},
    visual = {
        screenFlicker = true,
        flickerRate = 1,
    },
})

ix.symptom.Register("water_warp", {
    message = "The world ripples and distorts before your eyes.",
    me_actions = {
        "blinks rapidly, trying to clear their vision",
        "rubs their eyes, the world shimmering",
    },
    visual = {
        waterWarp = true,
        waterWarpIntensity = 0.5,
        blur = true,
        blurIntensity = 0.3,
    },
})

ix.symptom.Register("disorganized_thought", {
    message = "Your thoughts scatter like broken glass. You can't hold onto a single idea.",
    me_actions = {
        "starts a sentence but trails off mid-word",
        "says something completely incoherent",
        "laughs for no reason, then suddenly looks confused",
        "stares blankly, their train of thought derailed",
    },
    visual = {
        blur = true,
        blurIntensity = 0.4,
        waterWarp = true,
        waterWarpIntensity = 0.1,
    },
})

ix.symptom.Register("catatonia", {
    message = "You feel yourself shutting down. You can barely move or think.",
    me_actions = {
        "stands completely still, unresponsive",
        "stares into space, seemingly catatonic",
        "doesn't react to anything around them",
    },
    speedReduction = 0.7,
    visual = {
        desaturate = true,
        desaturateIntensity = 0.7,
        vignette = true,
        vignetteIntensity = 0.3,
        blur = true,
        blurIntensity = 0.3,
    },
})

-- ─── Zombie-Specific ─────────────────────────────────────────────────────────

ix.symptom.Register("zombie_twitch", {
    message = "Your muscles spasm involuntarily.",
    me_actions = {
        "twitches involuntarily and growls",
        "jerks their head to the side with a crack",
        "spasms, a guttural sound escaping their throat",
    },
    soundPath = "npc/zombie/zombie_voice_idle2.wav",
    soundVolume = 0.3,
    soundPitch = 110,
    visual = {
        shake = true,
        shakeIntensity = 2,
        colormod = Color(130, 180, 90, 255),
        colormodIntensity = 0.15,
    },
    clientEvent = "eye_distort",
    clientEventData = {intensity = 10},
})

ix.symptom.Register("zombie_rage", {
    message = "RAGE. HUNGER. BLOOD.",
    me_actions = {
        "snarls aggressively, their eyes glazing over",
        "lunges forward with a bestial growl",
        "bares their teeth and growls at everyone nearby",
    },
    soundPath = "npc/zombie/zombie_alert1.wav",
    soundVolume = 0.5,
    soundPitch = 100,
    visual = {
        colormod = Color(100, 160, 70, 255),
        colormodIntensity = 0.4,
        sharpen = true,
        sharpenIntensity = 1.5,
        vignette = true,
        vignetteIntensity = 0.2,
    },
})

ix.symptom.Register("zombie_groan", {
    message = "An inhuman sound escapes your throat.",
    me_actions = {
        "lets out an inhuman groan, barely recognisable",
        "makes a horrible wet gurgling sound",
        "emits a low, constant moan",
    },
    soundPath = {"npc/zombie/zombie_voice_idle1.wav", "npc/zombie/zombie_voice_idle3.wav", "npc/zombie/zombie_voice_idle5.wav"},
    soundVolume = 0.5,
    soundPitch = 90,
    contagionRange = 80,
})

-- ─── Recovery ────────────────────────────────────────────────────────────────

ix.symptom.Register("feelBetter", {
    message = "You begin to feel better.",
    me_actions = {
        "takes a deep breath and seems to feel better",
        "straightens up, looking improved",
    },
    notification = true,
})

ix.symptom.Register("recovering", {
    message = "Your symptoms are subsiding.",
    notification = true,
})

ix.symptom.Register("remission", {
    message = "The episode seems to be passing... for now.",
    notification = true,
})
