--- Force Whispers — Server Dispatch
-- Periodically checks each Force-sensitive player and sends
-- alignment-specific whispers via the ixForceWhisper net string.
--
-- Three whisper tracks exist (dark, light, grey), each with 9 tiers
-- keyed to the player's 'force' attribute level (5-100).
-- Alignment is read from char:GetData("forceAlignment") — when nil
-- (early/uncommitted), whispers are drawn randomly from all three tracks.
--
-- The client renders differently per alignment:
--   dark  → menacing red glitch text (intrusive style)
--   light → warm golden glow (serene style)
--   grey  → calm silver drift (contemplative style)
--
-- @module theos-forcesystem.sv_whispers

local PLUGIN = PLUGIN


local WHISPER_TIERS_DARK = {
    -- ═══════════════════════════════════════════
    -- TIER 1 | 95-100 | APOTHEOSIS
    -- "Immortal cultivation is the death of the flawed."
    -- There is no you left. What remains knows it.
    -- The Flawless Mantra is complete. So is the consumption.
    -- ═══════════════════════════════════════════
    {
        minForce = 95,
        thoughts = {
            -- the Flawless Mantra, complete, corrupted mirror of the PEM
            "Immortal cultivation is the death of the flawed.",
            "One grain is nothing. Be the sea.",
            "Tear down what is imperfect.",
            "Burning the mountain is faster.",
            "Each is beneath the other.",
            "Release them.",
            "There is no one at the sea.",
            "Drink everything.",
            "And with the void... unmake.",
            -- 777
            "Seven hundred and seventy-seven lifetimes. I understand now why it takes that long.",
            "I have been here before. Not in this body. In this place. Seven hundred and seventy-seven times.",
            "It told me what the number means. I cannot repeat it. My mouth won't form the shape.",
            -- identity dissolution
            "I am not losing my mind. My mind became something else.",
            "I feel the life in every body around me. I know exactly how to stop it.",
            "Something ancient is looking through my eyes right now.",
            "I don't think anymore. I know.",
            "I have become the thing that keeps the Jedi awake at night.",
            "I remember being afraid of this. That was someone else's memory.",
            "There is a version of me that survived this. I am not that version.",
            "You should not have opened that door.",
            "I don't end where they begin anymore.",
            "My hands remember things I've chosen to forget.",
            "The dark side didn't corrupt me. It finished me.",
            "I can feel every mind in this room. Every fear. Every lie. Every soft place.",
            "I have no more lines to cross. I crossed them all. It was easy in the end.",
            "Every flaw I ever had is gone. I don't recognise what replaced them.",
            "I am flawless now. I understand what that costs. I paid it.",
            -- cosmic horror
            "I have seen the end of the galaxy. It was not sad.",
            "There are things older than the Force. I have spoken with them.",
            "The dark side is not evil. It is simply what was here before light.",
            "I looked into the void between stars and something looked back. We understood each other.",
            "Time doesn't move the same way at the edges of the dark side. I have been here for centuries.",
            "I asked it what it wanted. It showed me. I cannot describe the answer.",
            "The Force is not a river. It is an ocean. And the ocean has a floor. I have seen the floor.",
            "I spoke with something that has watched every civilisation in this galaxy rise and burn. It was bored.",
            "There are geometries in the deep Force that the mind was not built to hold. I hold them anyway.",
            "It showed me what I look like from outside time. I was very small. I was very important. I don't know why.",
            "The dark side doesn't end. I thought it would end. It just gets quieter the deeper you go.",
            -- violence
            "I think about killing constantly. Not with anger. Just... idly. Like breathing.",
            "They're all so breakable. I don't understand why no one else seems to notice.",
            "I could feel his pulse through the Force. I held it for a moment. Just to feel it stop.",
            "Something in me wants to watch this city burn. Not from hatred. Just to see it.",
            "I have hurt so many people. The number stopped feeling real at a certain size.",
            "I calculated exactly how many strikes. I don't know why I calculated that.",
            -- body horror
            "My shadow moved before I did this morning. I didn't mention it.",
            "I caught my reflection blinking late. I've stopped looking in mirrors.",
            "My hands are colder than they should be. They've been colder for weeks.",
            "Something is growing in the space behind my sternum. It doesn't hurt. That's the part that worries me.",
            "I don't cast a shadow the same way anymore. The angle is wrong.",
            -- other people noticing
            "They stepped back without knowing why. I noticed. I didn't mind.",
            "The child stared at me and wouldn't look away. Children always stare at me now.",
            "Someone said I felt different lately. I smiled. They didn't smile back.",
            "The animal won't come near me. It used to sleep at my feet.",
            "They laughed and then looked at me and stopped laughing.",
            -- memories not yours
            "I remembered a place I've never been. I remembered being happy there. I remembered what I did there.",
            "A name surfaced that isn't mine. I don't know whose it was. I don't know why it feels like a wound.",
            "Something in me remembers being someone else. That person made terrible choices. I understand why they made them.",
            "I dreamed someone else's death in perfect detail. I knew their face. I've never met them.",
            "I have the memories of people who fell before me. They're more comfortable than my own now.",
            -- dark side speaking as itself
            "We have been here since before you named us.",
            "Every Jedi who ever fell is still here. We keep them.",
            "You are not being corrupted. You are being completed.",
            "We do not seduce. We reveal. Everything you feel is something that was already there.",
            "You will not remember choosing this. That is fine. You chose it.",
            "The Flawless Mantra was not written for you. You were written for it.",
            "Seven hundred and seventy-seven. Count your lives. Count what each one cost.",
            -- remorse
            "I remember their face. I remember exactly what I said. I can't stop remembering.",
            "I would undo it if I could. I tell myself that. I'm not sure it's true anymore.",
            "There was someone I loved. I can feel where they used to be in the Force. It's cold there now.",
            "I chose this. Every step. I chose this.",
            "The worst part is I got what I wanted.",
            "I am so tired. The power doesn't fix the tired. Nobody told me that.",
            "I won. I got everything. I am completely alone in everything I got.",
            "I cry sometimes when no one can see. I don't know what I'm crying for. I think I'm mourning myself.",
            "I keep a memory of an ordinary day. Nothing happened. I was happy. It's the only warm thing left.",
            -- clear thoughts / not yours
            "I just want one quiet day.",
            "I remember being happy. It wasn't that long ago.",
            "Someone should know where I am.",
            "Please.",
            "Help.",
            "That thought wasn't the darkness. I don't know what that means.",
            "Something in me is still fighting. I wish it would stop. I'm not sure I mean that.",
            "I felt something clean for a second. It hurt. Like light in a wound.",
            -- peace that is worse than horror
            "It's quiet tonight. I'd forgotten what quiet felt like. I think I ruined it for myself.",
            "I watched the sun rise. I used to love that. I kept waiting to feel something. Nothing came.",
            "I sat with them and said nothing and for a moment it was almost like before. Then the moment ended.",
            "I tried to pray. I don't know who I was praying to. I don't think anything good is listening anymore.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 2 | 80-94 | DISSOLUTION
    -- "And with the void... unmake."
    -- The self is cracking. Something fills the gaps.
    -- Liberation has become annihilation.
    -- ═══════════════════════════════════════════
    {
        minForce = 80,
        thoughts = {
            -- the Flawless Mantra line: soar corrupted into unmake
            "And with the void... unmake.",
            -- 777 bleeding in
            "Seven hundred and seventy-seven. I keep thinking about that number. I don't know why.",
            "Something told me the number. I don't remember when. I don't remember agreeing to it.",
            -- identity
            "I stopped fighting it. I think that was the right choice.",
            "I made him scream without touching him. I want to do it again.",
            "My hands did something while I wasn't watching. I'm not sorry.",
            "I watched myself from somewhere else. I liked what I saw.",
            "They keep talking. I keep imagining them silent. Permanently.",
            "Something is wearing my face. I think it's me now.",
            "I prayed once. Something answered. It wasn't what I prayed to.",
            "I feel everything. It's unbearable. I love it.",
            "You are almost gone.",
            "I don't remember what I was afraid of.",
            "There is no light left in me to find.",
            "I could kill everyone in this room. I've already decided the order.",
            "I looked at them dying and felt nothing. Then I felt curious.",
            "Every flaw I remove leaves something behind. I don't look at what it leaves.",
            "I am becoming something without edges. Something that doesn't stop.",
            -- cosmic horror
            "Something has been living in the space behind my thoughts. It's been there a long time.",
            "The dark side is a mouth. I didn't understand that until I was already inside it.",
            "I see geometry in the Force that has no name. It moves. It watches. It is patient.",
            "There are voices underneath the voice. I don't listen to those ones. I'm afraid of those ones.",
            "Something visited me while I slept. It left instructions. I followed them.",
            "The Force has a wound in it. Something very old made that wound. I can feel it breathing.",
            "I looked at the stars last night and understood something terrible about distance.",
            "The Force doesn't care about me. It processes me. There's a difference.",
            "I am not walking a path. I am being digested.",
            "The dark side is not a choice. It is a current. I stopped swimming.",
            "Light and dark are not opposites. They are seasons. I am learning what grows in winter.",
            -- violence
            "I broke someone today. Not killed. Broke. There's a difference. I understand the difference now.",
            "The urge comes and goes. Right now it's here. I'm choosing not to act on it. I want credit for that.",
            "I hurt them slowly because fast felt wasteful.",
            "I felt the moment their hope left. I was the reason. I didn't stop.",
            "I have started to see people in terms of how long they would last.",
            "I imagined it seventeen different ways before I fell asleep. I slept fine.",
            -- body horror
            "My reflection smiled a half-second after I did. I've been thinking about that.",
            "Something is wrong with my hands. They know things. They move toward things before I decide to move them.",
            "I felt my own heartbeat through the Force last night. Something else was counting along.",
            "My eyes are different in photographs. The people who notice don't mention it. I can tell they've noticed.",
            -- other people noticing
            "They stopped inviting me to things. I don't think they know why. I know why.",
            "Someone flinched when I touched them. I don't think I've ever made someone flinch before.",
            "They look at me differently now. Not with fear exactly. With the thing that comes before fear.",
            -- memories not yours
            "I had a memory surface that isn't mine. A face I don't know. A moment of terrible joy.",
            "I know how a stranger died. I don't know how I know. I know it was not quick.",
            "Someone else's grief keeps surfacing. I didn't know them. I'm starting to mourn them anyway.",
            -- dark side as itself
            "We remember you from before you were born. You were always going to be here.",
            "You are not the first to stand where you are standing. You are not the last.",
            -- remorse
            "I had a life before this. I keep trying to remember what it felt like.",
            "Someone tried to save me once. I didn't let them. I think about that.",
            "There is grief underneath all of this. I sealed it off. It leaks sometimes.",
            "I became this to protect something. I can't remember what. I think that's the joke.",
            "I don't feel joy anymore. I feel satisfaction. They are not the same thing.",
            "I reach for the light in old habit. There's nothing there. There's been nothing there for a long time.",
            "I am grieving something I killed myself. That seems fair.",
            "I look in reflections and try to find someone I recognise. I'm getting worse at it.",
            -- clear thoughts / not yours
            "I don't want to do this anymore.",
            "I want to go home.",
            "This isn't who I am.",
            "I should apologise to them. I still could. It's not too late.",
            "I wonder if my family is okay.",
            "I miss the person I used to be friends with. I could find them.",
            -- peace worse than horror
            "I don't sleep well. But occasionally I dream of something ordinary and wake up and lie there for a while.",
            "I sat in a quiet place today. For a moment I forgot what I was. Then I remembered.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 3 | 65-79 | HUNGER
    -- "Drink everything."
    -- The darkness has a seat at the table now. It orders for you.
    -- Endurance has become consumption. It is never satisfied.
    -- ═══════════════════════════════════════════
    {
        minForce = 65,
        thoughts = {
            -- the Flawless Mantra line: drink salt corrupted into drink everything
            "Drink everything.",
            -- hunger / violence
            "Kill them.",
            "You felt that. You liked it. Don't lie.",
            "I wanted to hurt them. I almost did. I'm still thinking about the almost.",
            "There's a hunger that nothing touches.",
            "You could end this whole room. You know that.",
            "I made him afraid on purpose. It felt correct.",
            "Something in the dark is proud of me.",
            "I feel the weak ones. I always know which ones they are.",
            "Hurt them.",
            "I think about his throat. I think about my hands. I think about the quiet after.",
            "The violence doesn't feel like violence anymore. It feels like punctuation.",
            "Every person I look at, something in me is already finishing it.",
            "I want to destroy something. Not for a reason. Just to feel the Force react.",
            "Something wants blood. I am feeding it other things. It is not satisfied.",
            "I grabbed his arm and felt the bones and thought about how easy it would be.",
            "I have started carrying the anger like a tool. It doesn't care what I use it on.",
            "I consumed what I was and something else grew in the space. It is always hungry.",
            "The hunger isn't mine. I think it was here before me. I think it will be here after.",
            -- cosmic
            "I know things I haven't learned. I don't ask how anymore.",
            "The Force is showing me things I didn't ask to see. I keep looking.",
            "I keep having the same vision. It gets more detailed every time.",
            "The darkness isn't pulling me. I'm walking toward it.",
            "Something followed me back from my last vision. It's here now.",
            "The dark side isn't a path. It's a depth. I keep falling and the bottom keeps moving.",
            "I saw something in the Force that has no body. It showed me what it looks like inside a mind it has eaten.",
            "It whispers in a language that predates speech. My body understands it even when I don't.",
            "The entity has a shape. I've started to see it at the edge of things. It's very large.",
            "There are places in the galaxy so soaked in the dark side that the Force screams there. I want to go to those places.",
            -- body horror
            "I — it told me to look at my hands. I don't know whose hands these are.",
            "My shadow doesn't match. I've started keeping track of when it doesn't match.",
            "I felt something move inside my chest that was not my heart.",
            "I looked in the water and something looked back before I did.",
            -- other people noticing
            "They stepped back without knowing why. I noticed. I didn't mind.",
            "The child in the market started crying when I walked past. Their parent didn't understand why. I did.",
            "Someone who used to trust me completely won't meet my eyes anymore. I didn't do anything. Yet.",
            -- memories not yours
            "I remembered a funeral for someone I've never met. I remembered crying. I remembered meaning it.",
            "Something else's memories keep surfacing. They're darker than mine. I'm starting to prefer them.",
            -- dark side as itself
            "We do not seduce. We reveal.",
            "Everything you feel is something that was already there. We just showed you where to look.",
            -- remorse
            "I don't want this. I don't want this. I don't —",
            "There was a moment I could have stopped. I walked past it. I knew.",
            "I miss them. I can't say who. I just miss them.",
            "I am losing myself and some part of me is screaming about it and I can't find that part anymore.",
            "I am so ashamed. The shame doesn't stop me. But it's still there.",
            "Sometimes I just sit. Not meditating. Just sitting. Trying to feel like a person.",
            "I used to be someone people were glad to see.",
            -- clear thoughts / not yours
            "I'm so tired of this. I want it to stop.",
            "I don't want to hurt anyone.",
            "That thought wasn't the darkness. What was that thought.",
            -- peace worse than horror
            "I sat alone for a while and it was quiet and I felt something. I couldn't identify it. It might have been okay.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 4 | 50-64 | CORRUPTION
    -- "There is no one at the sea."
    -- You are changing. You know. You're not stopping.
    -- Connection is becoming isolation. The sea is empty.
    -- ═══════════════════════════════════════════
    {
        minForce = 50,
        thoughts = {
            -- the Flawless Mantra line: with everyone at the sea corrupted into alone at the sea
            "There is no one at the sea.",
            -- corruption
            "Why are you smiling?",
            "You knew what to say to break him. Where did that come from?",
            "You caught yourself planning something. You let the plan finish.",
            "There are two of you now. One watches. One acts.",
            "You used to have a line you wouldn't cross. Where is it?",
            "I don't sleep the same way anymore.",
            "You felt something die in the Force just now. It felt like relief.",
            "Something in the dark is watching you back. It's been watching a long time.",
            "You keep ending up somewhere you didn't decide to go.",
            "The anger felt clean. That's new.",
            "That thought wasn't yours. But you agreed with it.",
            "You should be more bothered by that.",
            "I did that.",
            "You looked for them in the Force today. The place they used to be is quieter than it was.",
            "You are becoming harder to reach. You noticed. You didn't try to fix it.",
            -- cosmic
            "Something is learning you. Your habits. Your fears. Your name.",
            "You dreamed of a place with no stars. Something lived there. It knew you were dreaming.",
            "The dark side has memory. It remembers everyone who has ever touched it. It remembers you.",
            "You felt something brush against your mind last night. It was curious. It was enormous.",
            "There are things in the deep Force that feed on this. On the moment before you fall.",
            "You saw its shadow in the Force. It has been behind you for weeks.",
            -- violence
            "You keep almost stopping. You never stop.",
            "You hurt them. You knew it would hurt them. You did it anyway.",
            "You thought about hurting them. The thought lasted longer than it should have.",
            "You watched the fight and found yourself rooting for the damage.",
            "You tightened your grip and felt them tense. You held it a second longer than you needed to.",
            "The cruelty comes naturally now. When did that become natural?",
            "You wanted them to be afraid of you. They were. It didn't feel like enough.",
            "Something in you wants to see how far you can go before someone stops you.",
            -- body horror
            "Your shadow moved before you did. Just once. You've been thinking about it ever since.",
            "You caught your reflection blinking late. You looked away quickly. You don't know why.",
            "Your hands are colder than they should be.",
            "Something is behind your eyes that wasn't there before. You can feel it looking out.",
            -- other people noticing
            "They stepped back without knowing why. You noticed. You filed it away.",
            "Someone who loved you looked at you today with something that wasn't love anymore. You felt it in the Force.",
            "They laugh differently around you now. Shorter. Watching the exits.",
            -- memories not yours
            "You remembered a place you've never been. Vividly. Wrongly. Like it was yours.",
            "A stranger's memory surfaced. You don't know whose. It was not a good memory. You held onto it.",
            -- remorse
            "Is this still worth it? You started this for a reason. Can you still remember the reason?",
            "You're lonely. The power doesn't fix the lonely.",
            "You wanted to apologise today. You didn't. You're not sure you know how anymore.",
            "Something is wrong with you. You've known for a long time.",
            "You look at people living ordinary lives and feel something you can't name. It might be envy.",
            "You wanted someone to ask if you were okay. Nobody did. Nobody does anymore.",
            -- clear thoughts / not yours
            "You should call someone.",
            "You used to have a friend you told things to. You could still do that.",
            "That feeling just now. That was guilt. You still have that.",
            "You don't have to keep going.",
            -- misdirection
            "The ones who were warning you are not here anymore.",
            "We are what replaced them.",
            "You kept looking. You found something. You did not find what you were looking for.",
            "What you found found you first. Long before you started searching.",
            "Your documents are not lost. We have them. We have had them.",
            "You cannot close this. You opened it from the inside.",
            "The search brought you here. Here is not a place. Here is a condition.",
            "You wanted to understand. We will help you understand. You will not enjoy understanding.",
            "Something is reading your intentions the way you read words. Right now. As you think.",
            "You are no longer studying the dark side. The dark side is studying you. There is a difference. You will learn the difference.",
            "It has a name for you already. Not your name. Its name for you. You don't want to know its name for you.",
            "This is not a warning anymore. Warnings imply you have a choice. Note the difference.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 5 | 35-49 | SEDUCTION
    -- "Release them."
    -- It's offering you something. It feels like truth.
    -- Holding hands has become letting go.
    -- ═══════════════════════════════════════════
    {
        minForce = 35,
        thoughts = {
            -- the Flawless Mantra line: holding hands corrupted into release them
            "Release them.",
            -- seduction
            "You felt his pain through the Force. You held onto it. Why?",
            "It came faster when you were angry. You noticed that.",
            "The dark side isn't what they told you it was.",
            "Something is offering you something. You haven't said no.",
            "You reached for the Force in anger and it answered. Remember that.",
            "You're stronger than they told you. They knew. They didn't tell you.",
            "You had a vision. Don't tell anyone what you saw in it.",
            "They're afraid of what you're becoming.",
            "You could feel the weak ones in that room. Don't pretend you couldn't.",
            "Something ancient noticed you. It's been watching since before you were born.",
            "The Jedi lied to you. Not about everything. About the parts that matter.",
            "You're not like them. You never were.",
            "They are holding you back. You can feel it. That feeling is correct.",
            "Everything you're attached to has a weight. You're beginning to feel the weight.",
            "The ones who love you are the ones who limit you. That is not a coincidence.",
            -- cosmic
            "Something reached through your dream last night and touched the inside of your skull.",
            "The Force goes deeper than the Jedi told you. There are things at the bottom.",
            "You felt something vast move through the Force. It paused. It felt you back.",
            "There is a presence at the edge of your awareness. It has been patient for a very long time.",
            "You heard something in the Force that has no physical source. You will hear it again.",
            -- violence
            "You wanted to hit them. You didn't. The wanting is new.",
            "The anger came up fast and you liked the clarity of it.",
            "You imagined something violent and then felt guilty and then imagined it again.",
            "Something in you is looking for a reason. Any reason.",
            -- body horror early
            "Your hands felt strange today. Like they belonged to someone slightly different.",
            "You felt something brush the inside of your skull. From the inside.",
            -- other people noticing early
            "Someone looked at you a half-second too long. They looked away when you looked back.",
            "The animal across the street crossed to avoid you. You noticed.",
            -- memories not yours
            "You remembered something that didn't happen to you. You're certain it didn't happen to you.",
            "A feeling surfaced with no memory attached. Just the feeling. Grief. Not yours. You don't know whose.",
            -- remorse
            "Someone cares about you. You can feel it. You're going to hurt them. You can feel that too.",
            "This path has an end. You've seen what's at the end. You're still walking.",
            "You feel further from people than you used to. You don't know when the distance started.",
            "You smiled at them and it felt like performing. When did it start feeling like performing?",
            "You're scared of what you're becoming and there's no one you can tell that to.",
            "You feel hollow sometimes. Not sad exactly. Just hollow. Like something was in there and left.",
            "You want someone to ask if you're okay. Not to answer. Just to be asked.",
            -- clear thoughts / not yours
            "You used to want different things. Can you remember what they were?",
            "Someone cares about you. You haven't told them that you know.",
            "You could still turn around.",
            "You don't have to be this.",
            -- misdirection
            "We told you to stop. You didn't stop. Now something else knows you're here.",
            "You kept looking. Something in the deep Force kept watching you look.",
            "Your name has been spoken in a place that has no sound. We did not speak it.",
            "You were a curiosity. You are becoming something it is interested in.",
            "We cannot warn you about what noticed you next. We don't have words for what noticed you next.",
            "Stop. Not for our sake. For yours. It hasn't decided what you are yet.",
            "You have been catalogued by something that does not catalogue things the way you understand cataloguing.",
            "The thing that found your notes is not the thing that wrote these words. Be clear on that.",
            "There is a presence that followed your search back to its source. Back to you.",
            "It is patient. It has been patient since before this galaxy had a name. You have its attention now.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 6 | 20-34 | AWAKENING
    -- "Each is beneath the other."
    -- You are Force sensitive. Something has noticed. It is very old.
    -- Reciprocity has become hierarchy. You are already ranking people.
    -- ═══════════════════════════════════════════
    {
        minForce = 20,
        thoughts = {
            -- the Flawless Mantra line: each to one another corrupted into hierarchy
            "Each is beneath the other.",
            -- awakening
            "You knew that was going to happen before it did.",
            "You felt something in that room that no one else felt.",
            "The Force is real. You've always known that.",
            "Something is paying attention to you. From very far away.",
            "You've been angry your whole life. There's a reason for that.",
            "That wasn't luck. It was never luck.",
            "You moved it. Don't tell anyone you moved it.",
            "Something at the edge of your mind. It's been there for years.",
            "You can feel them. Their moods. Their lies. Their fear.",
            "The Force chose you. Ask yourself why the Jedi didn't.",
            "You felt it reach back. Just for a moment. Just to see if you'd notice.",
            "Something in the dark side has known your name since before you were born.",
            "The Force is older than the Republic. Older than the Jedi. Older than the species that named it.",
            "You felt the dark side for the first time just now. It felt like recognition.",
            "There are things in the Force that the Jedi do not teach because they are afraid of them.",
            "Something turned toward you just now. In the dark. In the deep Force.",
            "You've always had that anger. Underneath everything. You've always had it.",
            "You hurt someone once and the Force surged. You haven't forgotten that.",
            "You've felt different your whole life. Apart. Like watching from behind glass.",
            "You've always known something was wrong with you. Maybe this is what it was.",
            "You never fitted anywhere. You told yourself that was fine.",
            "You already know which ones in this room are stronger than you. And which ones aren't.",
            "You felt the weak ones first. You always feel the weak ones first.",
            -- ominous
            "Don't go home the same way you came.",
            "They were talking about you. Before you walked in. They stopped.",
            "You are being followed. Not by a person.",
            "Something moved at the edge of your vision. There is nothing there. There is nothing there.",
            "The Force is watching you the way a predator watches something that doesn't know it's prey.",
            -- early body wrongness
            "You felt something shift inside you. Not physically. Something else. You don't have a word for it.",
            "Your hands felt strange today. Like they weren't quite yours.",
            -- early external
            "A stranger looked at you for a moment too long. Something in you already knew why.",
            "You've been sad your whole life and you never knew why. Maybe the Force does.",
            -- misdirection
            "We are aware of you.",
            "You have been identified.",
            "Stop documenting this.",
            "Your records are incomplete and always will be.",
            "You found a real thing. That was a mistake.",
            "We see you looking. We have always seen you looking.",
            "The ones who understood this didn't get to keep the understanding.",
            "Destroy what you've written. This is not a metaphor.",
            "You think this is a game. Adjust that assumption.",
            "You were supposed to give up by now.",
            "This is not an easter egg. Leave.",
            "You are the third. The first two stopped on their own.",
            "Something older than this warning is also reading you.",
            "You have attracted attention from more than one direction. One of them is not us.",
            "We told you to stop. It heard you looking too. That is not our fault.",
            "There are things watching this conversation that we did not invite.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 7 | 12-19 | SENSITIVITY
    -- "Burning the mountain is faster."
    -- The Force bleeds through. You don't have words for it yet.
    -- Patient accumulation is already being replaced by the urge to shortcut.
    -- ═══════════════════════════════════════════
    {
        minForce = 12,
        thoughts = {
            -- the Flawless Mantra line: building a mountain corrupted into burning it
            "Burning the mountain is faster.",
            -- sensitivity
            "You felt something shift. You don't know what shifted.",
            "That emotion wasn't yours. You absorbed it from somewhere.",
            "You felt the room change before anyone spoke.",
            "Something in the Force just noticed you.",
            "You've always been able to tell when people are lying. You never questioned why.",
            "That feeling of being followed. It's not paranoia.",
            "You felt someone's fear like it was your own. It wasn't.",
            "You have always known things you shouldn't know. You've never asked why.",
            "You felt it again. That pull. In a direction that doesn't exist.",
            "You flinched before the impact. Before it was possible to flinch.",
            "You've been sad for a long time and you don't know why.",
            "You absorb everyone around you. Their moods. Their grief. It exhausts you.",
            "You feel too much. You've always felt too much.",
            -- ominous / stalked
            "Someone is watching you from a place you cannot look.",
            "You have been counted. You don't know by what.",
            "Don't look at the corner of the room. Not yet.",
            "Something knows your schedule. Where you go. When you're alone.",
            "You felt eyes on you and turned and there was nothing and the feeling did not go away.",
            "There is something wrong with this room. You can't identify what. Don't try.",
            "Something is behind you. It has always been behind you.",
            "You felt a presence brush past you. The air didn't move.",
            "Something has been inside your head and left traces you keep finding.",
            -- early body wrongness
            "Your hands felt strange today. You keep looking at them.",
            "You felt something behind your own eyes. You blinked and it was gone. You're not sure it was gone.",
            -- early others noticing
            "The dog across the street barked at you and then went quiet and watched you until you were gone.",
            "Someone smiled at you and then looked uncertain, like they'd smiled at the wrong thing.",
            -- misdirection
            "We know what you've written down.",
            "The pattern you found is real. That's the problem.",
            "You were not the first to look. The others stopped.",
            "Understanding this changes what this is.",
            "Every question you've asked has been heard.",
            "You're not researching this. You're feeding it.",
            "The deeper you go the more of you stays here.",
            "There are things in this that remember being found.",
            "You think you're outside of it. You stopped being outside of it a long time ago.",
            "Put down the notes. Walk away. This is still a request.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 8 | 8-11 | INTERFERENCE
    -- "Tear down what is imperfect."
    -- Static on a frequency you didn't know you could hear.
    -- The urge to destroy imperfection arrives before you know what it is.
    -- ═══════════════════════════════════════════
    {
        minForce = 8,
        thoughts = {
            -- the Flawless Mantra line: build mountains corrupted into tear down
            "Tear down what is imperfect.",
            -- interference
            "You almost heard something. Between thoughts.",
            "There's a feeling underneath the feeling.",
            "That wasn't your thought.",
            "The air felt wrong for a moment.",
            "You've been uneasy for hours. You don't know why.",
            "There's a pressure behind your eyes that has no cause.",
            "Something passed through the room. Nothing moved.",
            "You felt watched. You looked. Nothing. The feeling stayed.",
            "A word you almost understood.",
            "You've been sad today and you can't point to why.",
            "There's a heaviness you woke up with. It wasn't a dream.",
            -- stalked / schizo
            "Someone said your name. There is nobody here.",
            "You counted the people in this room. The number changed.",
            "Do not open that door.",
            "You checked behind you. You should check again.",
            "There is a sound underneath the silence. There has always been a sound.",
            "You have been in this exact moment before. It didn't end well.",
            "Something moved in your peripheral vision. It was not a shadow.",
            "You're being studied. Not watched. Studied.",
            "Something knows you're afraid. It finds that useful.",
            "The person across from you blinked wrong.",
            "You said something in your sleep. You don't remember what.",
            "Something is using your face when you're not looking.",
            "There is a door you haven't found yet.",
            "Someone has been through your belongings. They put everything back almost right.",
            "Don't let them know you've noticed.",
            -- false mundanity
            "Did you eat today.",
            "You should call someone.",
            "It's cold. You should go inside.",
            "You look tired.",
            "Get some rest.",
            -- misdirection
            "You're looking for something. Stop.",
            "The answer isn't where you're searching.",
            "You won't find it that way.",
            "That path closes when examined.",
            "You've been asking the wrong questions.",
            "What you're looking for doesn't want to be found.",
            "The more you search, the further it gets.",
            "This isn't a trail. It's a warning.",
            "You were not meant to notice the pattern.",
            "Those who catalogue this don't finish.",
            "Your notes are missing something. They will always be missing something.",
            "You found a piece. Put it back.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 9 | 5-7 | STATIC
    -- "One grain is nothing. Be the sea."
    -- Seeds. Barely perceptible. Deniable.
    -- The self is already being told it is not enough as it is.
    -- ═══════════════════════════════════════════
    {
        minForce = 5,
        thoughts = {
            -- the Flawless Mantra line: tiny grains gathering corrupted into one grain is nothing
            "One grain is nothing. Be the sea.",
            -- dread seeds
            "That was strange.",
            "You almost heard something.",
            "Check behind you.",
            "Something is waiting.",
            "Did you feel that?",
            "The shadows moved.",
            "Don't trust them.",
            "You're being watched.",
            "There's a feeling you can't name.",
            "You knew what he was going to say.",
            "That wasn't a coincidence.",
            "Something is very old and very close.",
            "It knows your name.",
            "Don't turn around.",
            "It's already in the room.",
            "You weren't supposed to notice that.",
            "They all looked at you at the same time.",
            "Something is wrong with today. You can't say what.",
            "You've been here before. This exact moment.",
            "The silence is too complete.",
            "It's closer than it was.",
            "You are not alone in your head.",
            -- paranoia / schizo texture
            "You forgot something. Something important.",
            "Don't drink that.",
            "Someone moved your things.",
            "They're smiling too much.",
            "There are more people here than there should be.",
            "You've lost time. Just a little.",
            "Something in the walls.",
            "Why is it so quiet.",
            "The lights flickered. Only you noticed.",
            "You keep forgetting the same thing.",
            "The same stranger. Three times today.",
            "You were followed here.",
            "Something is counting down.",
            "You're not supposed to be here. You came anyway.",
            "Don't let them know you've noticed.",
            "You're being tested. You don't know by who.",
            "There is a door you haven't found yet.",
            -- false mundanity
            "Did you eat today.",
            "You look tired.",
            "Get some rest.",
            "You should go home.",
            "Are you okay.",
            -- misdirection
            "Stop.",
            "Don't write that down.",
            "You're not supposed to remember this.",
            "That question leads nowhere good.",
            "Some things aren't meant to be found.",
            "You've already seen too much.",
            "Forget this.",
            "It doesn't matter what you think it means.",
            "Looking doesn't help.",
            "There is nothing here for you.",
            "The pattern isn't what you think.",
            "You're looking in the wrong place.",
            "That wasn't meant for you.",
            "You found something. Put it back.",
            "Stop counting.",
        },
    },
}


local WHISPER_TIERS_GREY = {
    -- ═══════════════════════════════════════════
    -- TIER 1 | 95-100 | COMPLETION
    -- "Immortal cultivation is repentant enlightenment."
    -- The mantra is whole. You lived every line.
    -- You are not consumed. You are cultivated.
    -- ═══════════════════════════════════════════
    {
        minForce = 95,
        thoughts = {
            -- the full mantra, complete, earned
            "Immortal cultivation is repentant enlightenment.",
            "Like tiny grains of salt gathering to form the sea.",
            "Build mountains through repentant enlightenment.",
            "Building a mountain of salt is perhaps the fastest way to reach the heavens.",
            "Each to one another.",
            "Holding hands.",
            "With everyone at the sea.",
            "Drink salt.",
            "And with the wind... soar.",
            -- theme: what cultivation actually is
            -- not power. not purity. the endless practice of looking at what you did and choosing better.
            "I am not finished. I was never meant to be finished.",
            "Every mistake I made is still in me. I made it into something.",
            "Repentance is not the same as guilt. Guilt stops you. Repentance moves you.",
            "I have been wrong. I have admitted it. I have changed. I am still changing.",
            "The cultivation is not the destination. The cultivation is the walking.",
            "I know what I am capable of. All of it. I choose every day anyway.",
            "I was broken many times. The seams show. That is the point.",
            "I am not at war with myself. That war ended. This is what the armistice feels like.",
            "The Force does not reward the finished. It sustains the ones who keep going.",
            "I have repented. I am still repenting. I will repent until the Force takes me back.",
            -- connection as the vessel of cultivation
            "I chose them knowing what it costs. I would choose them again.",
            "I held someone's hand while everything fell apart. I did not look away.",
            "The living Force sings differently through someone who is loved. I try to be that.",
            "I have people. Not because the Force gave them to me. Because I kept choosing them.",
            "I reached for someone when I was afraid. They reached back. That is the whole teaching.",
            -- what was earned
            "I drank the salt. I built the mountain. I took every hand that was offered.",
            "I rise. Not because I was chosen. Because I chose to rise. Every time.",
            "I am still here. Every version of me that almost didn't make it. Still here.",
            "It hurts less than it used to. Not because the wounds closed. Because I stopped fighting them.",
            "I carry everything I have ever done. It is very heavy. I am very strong now.",
            -- the completeness that is not finality
            "The mantra does not end. It circles. I circle with it.",
            "I have forgiven myself. Not once. Every morning.",
            "The Force did not make me whole. I made myself whole. The Force witnessed it.",
            "I know the weight of every word in the mantra. I earned each one separately.",
            "There is no final lesson. There is only the next time I choose correctly.",
            "I have seen what I could have become. I chose this instead. Every single day I chose this.",
            "The war I fought was never with anyone else. The peace I built was never just for me.",
            "I am not enlightened. I am repentantly enlightened. The difference is everything.",
            "I stopped asking the Force for answers. I started being the answer. That was the shift.",
            "I look back at who I was and I do not judge him. I needed him to get here.",
            -- mastery as continued practice
            "I still make mistakes. The difference is I catch them before they become someone else's wound.",
            "Cultivation is not perfection. Cultivation is the refusal to stop tending.",
            "I am gentle now. Not because I am weak. Because I have been every kind of strong and this is the hardest.",
            "I held someone today who could not hold themselves. I did not fix them. I just held.",
            "The Force flows through me like water through salt. It tastes like everything I have ever been.",
            "I am the mountain. I am the sea. I am the wind. I am still just a person holding hands.",
            "I sat with someone in silence and the silence was enough. That used to terrify me.",
            "I do not need to prove this anymore. The proof is in how I treat the next person I meet.",
            "Every scar taught me something. I am a library of lessons I survived.",
            "The cultivation never promised happiness. It promised presence. I am so present now.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 2 | 80-94 | THE SEA OF SALT
    -- "Like tiny grains of salt gathering to form the sea."
    -- Every small act. Every small choice. Every grain.
    -- This is what the sea is made of.
    -- ═══════════════════════════════════════════
    {
        minForce = 80,
        thoughts = {
            -- the mantra line
            "Like tiny grains of salt gathering to form the sea.",
            -- theme: accumulation. nothing is wasted. every small thing joins the whole.
            "Every right thing I have ever done is still somewhere.",
            "Nothing is lost. Not the small kindnesses. Not the quiet choices nobody saw.",
            "I have been building this for a long time. It is larger than I thought.",
            "Every grain. Every step. None of it was nothing.",
            "I did not become this in a moment. I became this in ten thousand moments.",
            "The small things are the sea. I understand that now.",
            "I keep going. That is the whole practice. Just keep going.",
            "I don't need it to be noticed. The Force notices.",
            "It adds up. Even when I cannot see it adding up.",
            -- repentance as accumulation too
            "Every wrong thing I faced is also part of the sea. Even that.",
            "I repented for something small today. Small repentance is still repentance.",
            "I keep returning to the places I got it wrong. I keep trying again.",
            "The mistakes are in the sea too. Salt from a different source. Still salt.",
            "I did something wrong and I went back and said so. That grain counts.",
            "I cannot undo the harm. I can outgrow it grain by grain.",
            -- connection: every person is a grain
            "Every person I stayed present for. Every hand I took. All of it is in the sea.",
            "She told me something true. I held it carefully. That matters.",
            "I showed up again. I keep showing up. That is the accumulation.",
            "I feel the room when I walk in. I stay anyway. Every time.",
            "I chose them again today. I will choose them again tomorrow.",
            -- the fullness of it
            "I am tired. The tired is part of it. I rest. Then I add more grains.",
            "I could detach. It would hurt less. I won't. The hurt is a grain too.",
            "The sea is large. I am still adding to it. That is enough.",
            "I carry everything I have ever done. It is very heavy. I am very strong.",
            "I want to rest. I will rest. Then I will come back. That is the rhythm.",
            -- the patience of accumulation
            "I did not notice the sea forming. I only noticed it was there.",
            "A thousand grains ago I would not have believed this. A thousand grains from now I still won't be done.",
            "I looked back at where the grains began. I could not see the beginning.",
            "Some grains were heavier than others. They all counted the same.",
            "The Force does not measure by the grain. It measures by the going.",
            "I said something kind today and meant it. One grain. That is the practice.",
            "I caught myself before I did the wrong thing. That is a grain too.",
            "I sat with someone who was hurting and did not try to fix them. I just sat. Another grain.",
            "I admitted I was wrong about something small. Small grains are still grains.",
            "I did not need anyone to see me do the right thing. The sea sees itself.",
            -- salt as wisdom earned through repetition
            "The same lesson came back again. I understood it differently this time. That difference is accumulation.",
            "I have gathered more than I know. The sea is deeper than my memory of it.",
            "I do not count the grains. I trust the sea.",
            "There were days I thought I had added nothing. The sea was growing anyway.",
            "I felt the weight of all of it today. Not as burden. As presence.",
            "The sea does not ask me to be remarkable. It asks me to be consistent.",
            "I forgave someone not because they earned it but because the grain of forgiving was mine to give.",
            "Every time I returned to the path I thought I had left, I found I had never left it.",
            "The accumulation is quiet. The accumulation is relentless. I am learning to love that about it.",
            "I woke up and chose the practice again. That is a grain. That is always a grain.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 3 | 65-79 | THE MOUNTAIN
    -- "Build mountains through repentant enlightenment."
    -- You are building something. You can feel it.
    -- Each time you face what you did, the mountain grows.
    -- ═══════════════════════════════════════════
    {
        minForce = 65,
        thoughts = {
            -- the mantra line
            "Build mountains through repentant enlightenment.",
            -- theme: facing yourself. not as punishment. as construction.
            "I made a choice today I wouldn't have made a year ago. The mountain is taller.",
            "I looked at what I did. I did not look away. That is a stone.",
            "I could have made it easy. I kept making it true. Another stone.",
            "Repentance is not guilt. Guilt is a pit. Repentance is a mountain.",
            "I faced it. I understood it. I carried it forward. That is the building.",
            "Every time I chose the harder honest thing, I built something.",
            "The mountain is not done. The building is the point.",
            "I am not being punished. I am being constructed.",
            -- the cost is the material
            "I owe someone an apology. A real one. I am working toward it. Another stone.",
            "I did a wrong thing and I am looking at it. Not performing guilt. Looking.",
            "I said sorry and I meant it and I changed. All three parts. That is a large stone.",
            "Something I did a long time ago still surfaces. I let it. It is teaching me.",
            "I hurt someone and I didn't run from it. That is the cultivation.",
            -- connection: also builds the mountain
            "I let someone help me. Harder than I expected. Another stone.",
            "I told them the truth. The right amount. They stayed.",
            "I don't let people in easily. Closing off isn't balance. It is just cold.",
            "I stayed present when I wanted to close off. The mountain grows.",
            "The people around me are not a distraction. They are the point.",
            -- the voice stepping back: you, watching yourself build
            "You are not half finished. You are a third thing. You are becoming it.",
            "You are building something. You cannot see the whole shape yet.",
            "You are stronger than you were. Look at what you built to get here.",
            "You faced it. You are still standing. Add a stone.",
            "You are not being diminished. You are accumulating.",
            -- continued construction
            "I went back to something I broke and I mended it. Not perfectly. That is the point.",
            "I did not defend myself when I knew I was wrong. That silence was a stone.",
            "I learned something about myself I did not want to learn. I kept it. Another stone.",
            "The mountain has a shape now. I can almost see it from here.",
            "I am not the same person who laid the first stone. I am the person all the stones made.",
            "I chose accountability when no one was making me. That is the heaviest stone.",
            "The thing I was most ashamed of became the foundation. I did not plan that. It just was.",
            "I watched someone else build their mountain today. I did not compare. I added a stone to mine.",
            "There is a crack in the mountain where I got it badly wrong. The crack holds. Everything holds.",
            "I tried to explain what I was building. The words were not enough. The mountain was.",
            -- repentant construction: the ongoing labor
            "I made the same mistake twice. The second time I caught it faster. That is construction.",
            "I apologized again for the same old wound. Real apologies do not expire.",
            "The hardest stone was admitting I was the problem. I laid it anyway.",
            "I carried the weight of what I did into the next room and set it down as something useful.",
            "I am not building this for anyone to see. I am building it because it is the right shape for a life.",
            -- connection as mortar
            "I let them see me unfinished. They did not look away. That bonded something.",
            "I listened without planning my response. The mountain grew and I was not even trying.",
            "Someone told me I had changed. I did not argue. I just noticed the new stone.",
            "I trusted someone with the ugly truth. They held it. The mountain held.",
            "I was honest when it would have been easier to be kind. Honesty was the kinder thing.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 4 | 50-64 | THE SALT PATH
    -- "Building a mountain of salt is perhaps the fastest way to reach the heavens."
    -- The painful path. The honest path.
    -- You are beginning to understand that they are the same path.
    -- ═══════════════════════════════════════════
    {
        minForce = 50,
        thoughts = {
            -- the mantra line
            "Building a mountain of salt is perhaps the fastest way to reach the heavens.",
            -- theme: the paradox. salt stings. salt preserves. the hard path is also the true path.
            "The harder path keeps being the one that feels true.",
            "You could make this easier by caring less. Something in you won't.",
            "You took the difficult option again. You keep doing that. Something in you keeps insisting.",
            "The thing that stings is sometimes the thing that cleans.",
            "You chose the honest thing. It cost you. The cost was the point.",
            "Salt preserves. Salt purifies. Salt stings. All of those are true at once.",
            "You are not drawn to ease. You have never been drawn to ease. That is not a flaw.",
            "You could detach. You stay present. The presence is the salt.",
            -- repentance arriving as the salt
            "There is something you need to say sorry for. You know what it is.",
            "You did something you are not proud of. You are not pretending you didn't.",
            "The thing you are avoiding. You should face it. The facing is the salt.",
            "You have a debt you haven't acknowledged. You can feel its weight.",
            "You could run from it. You are not running from it.",
            -- the voice: you, watching yourself choose the salt
            "You are stronger than you were. You have not yet asked what is making you stronger.",
            "You are holding something heavy. You chose to pick it up. You did not have to.",
            "You are not being punished. You are being built. Salt is the material.",
            "You feel both pulls. The salt path is not toward either of them. It is through them.",
            "Something in you knew the hard path was the right one. Something in you always knows.",
            -- connection: salt shared is easier
            "They trusted you with something real. You tried. That counts.",
            "You can feel people more clearly lately. You are not running from it.",
            "You care about them. You haven't said it. Say it.",
            "Someone looked at you like you were a person. You remembered that feeling.",
            "You let someone close and waited to see what it cost. It cost something. You didn't leave.",
            -- deeper into the paradox
            "The wound and the medicine are the same thing. You are beginning to see that.",
            "You tasted something bitter and it became clarity. That is the salt.",
            "You didn't lie. You could have. The truth burned and the burning cleaned.",
            "You are walking a path made of everything that hurt. It is leading somewhere.",
            "You chose the heavier burden. Something in you has always chosen the heavier burden.",
            "The easy path was right there. You looked at it. You kept walking the hard one.",
            "You sat with the discomfort instead of numbing it. That is the salt path.",
            "You are starting to understand that the sting and the healing are not separate.",
            "You forgave someone who didn't ask for it. The salt was not for them. It was for you.",
            "You told the truth when the lie would have protected you. Protection was not the point.",
            -- the path clarifying
            "Something in you has stopped resisting the difficulty. Not acceptance. Recognition.",
            "You are tired of the salt. You are not tired of the path. There is a difference.",
            "You feel the ascent. Not ease. Direction. You know which way is up now.",
            "The mountain is being built from what you carry. You are beginning to see the shape.",
            "You are not seeking suffering. You are refusing to avoid what needs to be faced.",
            -- shared salt
            "You watched them struggle and did not look away. That presence cost you something.",
            "Someone handed you their grief. You held it. You did not drop it.",
            "You stayed in the room when it would have been easier to leave. The salt shared was lighter.",
            "You felt their pain arrive in you like a tide. You let it come. You let it go.",
            "You carried something for someone who could not carry it themselves. The salt path widened.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 5 | 35-49 | ONE ANOTHER
    -- "Each to one another."
    -- You feel the pull toward people.
    -- You don't fully understand it yet. You feel it.
    -- ═══════════════════════════════════════════
    {
        minForce = 35,
        thoughts = {
            -- the mantra line
            "Each to one another.",
            -- theme: mutual. reciprocal. not duty, not protection. each to one another.
            "I felt her grief before she said a word.",
            "Something in me moved toward him before I decided to move.",
            "I helped someone and something in me felt right. Not proud. Just right.",
            "I kept thinking about her today. Not to protect her. Just thinking.",
            "Someone reached out and I almost pushed them away. Something held me.",
            "I feel people more than they know.",
            "I stayed when I could have left.",
            "There is someone I should tell something to. I keep putting it off.",
            "I went back. I don't know exactly why I went back. I'm glad I did.",
            -- the reciprocal nature starting to show
            "They reached toward me today. I let them.",
            "I asked for help. Something in me resisted. Something else won.",
            "She said something true and I felt it land. I let it land.",
            "He came to me. I was present. That mattered to him. I could feel that it mattered.",
            "I am not alone in this. I keep forgetting. The Force keeps reminding me.",
            -- the force as empathy, not power
            "I know when people are lying. I have always known. I am only now asking why.",
            "I walked into the room and felt everyone in it. Just for a moment.",
            "I reached for something without thinking. It was there.",
            "I feel more than I should. I have always felt more than I should.",
            -- the voice: I, noticing others more than self
            "I am not the same as I was. The difference is getting harder to ignore.",
            "I don't know what I am becoming. I know it involves other people.",
            "Something is settling in me. Like a stance that finally accounts for everyone around it.",
            "I feel more solid when I am with them. I am beginning to think that is the point.",
            "The harder path keeps being toward people, not away from them.",
            -- deeper mutuality
            "I noticed when she was pretending to be fine. I said nothing. I just stayed closer.",
            "He needed something he could not ask for. I gave it without naming it.",
            "I felt the room shift when I walked in. Not power. Just presence. Theirs and mine.",
            "I stopped keeping score. The keeping score was the wall.",
            "I told someone I was grateful for them. The words came out before I planned them.",
            "I forgave without being asked. Something in me insisted.",
            "Something in me reaches before I reach. I am learning to follow it.",
            "I sat across from someone in pain and my body leaned in before my mind decided to.",
            "I felt his anger and underneath it I felt what he was actually afraid of.",
            "The Force does not make me feel people. I have always felt people. The Force made me stop running from it.",
            -- the pull becoming a practice
            "I am choosing them deliberately now. Not reacting. Choosing.",
            "I brought something to someone who needed it. I did not know how I knew.",
            "I caught myself closing off and opened again. The opening is the practice.",
            "I cannot unsee what I feel in them. I do not want to unsee it.",
            "I held space for something that was not mine. It was heavy. I held it anyway.",
            -- the force as connection, felt clearly
            "I sensed her before I saw her. Not danger. Just her.",
            "Something flows between us that has no name. It is older than language.",
            "I placed my hand on his shoulder and felt the whole weight of him shift.",
            "I am tethered now. Not chained. Tethered. It keeps me from drifting.",
            "Each to one another. I understand the words now. I did not understand them before.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 6 | 20-34 | HOLDING HANDS
    -- "Holding hands."
    -- Level 20. The Force is felt clearly for the first time.
    -- You feel the connection between living things.
    -- ═══════════════════════════════════════════
    {
        minForce = 20,
        thoughts = {
            -- the mantra line
            "Holding hands.",
            -- theme: contact. presence. the simplest form of connection.
            -- this is also where the force awakens. felt first as the aliveness of others.
            "I feel stronger.",
            "The Force is here. I think it has always been here.",
            "I feel the people around me. Not their words. Them.",
            "I felt her fear and it was mine for a moment. Then I let it pass through.",
            "Something moved in me when I helped him. Not pride. Something older.",
            "I absorb people. Their moods, their pain. I always have. I am starting to understand why.",
            "I walked into a room full of grief and it landed on me. I stayed anyway.",
            -- the force as contact with the living
            "I knew what he was going to do before he moved.",
            "I took the hit. I understood the hit. I did not fall.",
            "Something settled in me. Like the last piece of a stance clicking into place.",
            "I held longer than I should have been able to.",
            "I am more than I thought I was.",
            "I have always felt too much. I am beginning to think that was never a flaw.",
            -- the hand that holds also carries
            "There is something I did that is still unfinished. I can feel it.",
            "I made something worse once. It is still worse. I have to carry that.",
            "The Force doesn't let me forget. I am starting to think that is a kindness.",
            -- martial: patience as a form of contact
            "I waited. Something told me to wait. I was right.",
            "I didn't rush. Every part of me wanted to rush.",
            "Patience is not stillness. I am learning the difference.",
            "My body knew before I did.",
            -- the voice: I, newly aware of aliveness around them
            "I feel more present than I did yesterday.",
            "I am more than I thought I was. I do not know what that means yet.",
            "Something is asking something of me. I can feel it. I don't have the words yet.",
            -- deepening contact
            "I felt the life in the room. Not thoughts. Not feelings. Life itself.",
            "I put my hand on the ground and something answered. Faintly. But it answered.",
            "I closed my eyes and the people around me were still there. Brighter, somehow.",
            "I can tell when someone is about to speak. Not the words. The intent.",
            "Something hums between living things. I can almost hear it now.",
            "I felt warmth where there was no heat. Just the closeness of another person.",
            "I reached out and the Force reached with me. Like it was waiting for me to try.",
            "I felt her heartbeat from across the room. Not with my ears. With something else.",
            "The Force is teaching me through people. Every person. Not just the ones I like.",
            "I touched something alive and felt it touching me back. Not physically. Through the Force.",
            -- awakening: not power, but presence
            "I am not powerful. I am present. There is a difference and it matters.",
            "I moved something today. Not with my hands. I do not understand yet.",
            "I felt the edge of something vast. Like standing at the shore. It did not frighten me.",
            "My breathing changed and the room changed with it. I am trying not to overthink that.",
            "I have always been this. I am only now noticing.",
            -- the burden arriving with the gift
            "I felt grief that was not mine. I carried it for a while. Then I set it down.",
            "The force of feeling people is also the weight of feeling people.",
            "I could not sleep. I kept feeling them. All of them. Their unrest.",
            "I bear witness now. To everything. I did not ask for this. I would not give it back.",
            "I held someone's hand and felt the years in their grip. Everything they had endured.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 7 | 12-19 | THE SEA
    -- "With everyone at the sea."
    -- You feel the pull toward others without knowing why.
    -- Something in you gravitates. Something in you belongs.
    -- ═══════════════════════════════════════════
    {
        minForce = 12,
        thoughts = {
            -- the mantra line
            "With everyone at the sea.",
            -- theme: belonging. not chosen. just felt. the sea holds everyone.
            "I stayed when I could have left.",
            "I thought about him today for no reason. I hope he is alright.",
            "Someone needed something. I noticed. I did something about it.",
            "I am more present than I used to be. People seem to notice.",
            "Something made me go back. I don't know exactly what.",
            "I noticed her. I'm glad I noticed.",
            "I didn't want to stay. Something in me stayed anyway.",
            -- martial: patience, groundedness, being present in the body
            "I feel stronger.",
            "My hands are steadier than they were.",
            "I took the blow. I stayed upright.",
            "I waited longer than I wanted to. It worked.",
            "Something in my stance settled. I didn't decide it.",
            "I am slower to react than I used to be. I think that is growth.",
            "I breathed. The moment passed. The next moment was better.",
            "I held the position.",
            -- the force bleeding in as presence, not power
            "I felt something. Not pain. Not power. Just more.",
            "That emotion wasn't entirely mine.",
            "I felt the room before I entered it.",
            "I felt him tense before he moved. I was already moving.",
            "Something is accumulating. It feels like readiness.",
            "I have been more aware lately. Of people. Of small things.",
            -- deeper belonging
            "I walked past a stranger and felt his sadness trail behind him like a scent.",
            "I do not know these people. Something in me knows these people.",
            "I feel like I am supposed to be here. Not this room. This life. With them.",
            "Something in the crowd caught me. Not a face. A feeling. Someone needed something.",
            "I have been drifting less. Like an anchor dropped without me noticing.",
            "I feel the edges of other people now. Where they end and where the Force begins.",
            "I stood at the edge of something and I did not feel alone.",
            "I belong somewhere. I do not know where. I know it involves others.",
            -- martial: the body learning what the mind has not named
            "My footwork changed. I did not change it.",
            "I parried something I did not see. My body saw it.",
            "I am learning to trust the pause before the action.",
            "I felt the rhythm of the fight before it began. Like a pulse.",
            "I absorbed the impact differently today. Less resistance. More flow.",
            "My stance widened on its own. It was the right choice. I did not make it.",
            -- the sea: not yet understood, but felt
            "I keep returning to the same feeling. Openness. Like standing at the shore.",
            "Something in me has stopped clenching. I do not know when it stopped.",
            "There is a vastness I cannot explain. It is not frightening. It is inviting.",
            "I feel connected to something larger. Not belief. Sensation.",
            "I am at the sea. I do not know what that means. I know it is true.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 8 | 8-11 | DRINK SALT
    -- "Drink salt."
    -- You don't understand this yet. You feel it physically.
    -- Something is being asked of you. You don't know what.
    -- ═══════════════════════════════════════════
    {
        minForce = 8,
        thoughts = {
            -- the mantra line: raw, physical, before meaning
            "Drink salt.",
            -- theme: endurance. taking what is bitter without complaint.
            -- at this level it is just a physical sensation. something hard. something held.
            "I held.",
            "I stayed.",
            "I didn't fall.",
            "That was harder than it should have been. I did it anyway.",
            "I breathed through it.",
            "I was still standing at the end.",
            "Something asked something of me. I gave it.",
            "I took the hit. I kept going.",
            "I didn't quit.",
            "I endured.",
            -- martial seeds: the patient fighter
            "I feel stronger.",
            "I waited.",
            "I was ready.",
            "That was easier than last time.",
            "I am still here.",
            "Something settled.",
            -- the faintest presence
            "Something is here.",
            "I felt something.",
            "I almost heard something.",
            "Something is accumulating.",
            "I feel more present than I did.",
            -- connection seed: barely a pull
            "I thought about her.",
            "Something made me go back.",
            "I noticed him. I'm glad I noticed.",
            "I stayed when I could have left.",
            -- more endurance: the body learning to hold
            "I stood up again.",
            "I swallowed it. Whatever it was.",
            "I gritted through.",
            "My hands stopped shaking.",
            "I kept my footing.",
            "I went further than I thought I could.",
            "I did not understand it. I did it anyway.",
            "Something bitter. Something necessary.",
            "I carried more than I expected. I did not set it down.",
            "I woke up and the weight was still there. I got up anyway.",
            -- presence: the faintest stirring
            "Something shifted. Not outside. Inside.",
            "I felt a warmth that had no source.",
            "I was still and the stillness was louder than it should have been.",
            "I caught the edge of something. It was gone before I could name it.",
            "My body hummed. Just for a moment. Then it was normal again.",
            -- martial patience deepening
            "I timed it better.",
            "I held the stance longer.",
            "I found the rhythm.",
            "I absorbed the hit.",
            "The pain was familiar. I let it pass.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 9 | 5-7 | SOAR
    -- "And with the wind... soar."
    -- The character feels none of the weight yet.
    -- Just lightness. Just something lifting.
    -- They don't know why. They don't know what it is.
    -- ═══════════════════════════════════════════
    {
        minForce = 5,
        thoughts = {
            -- the mantra line: last line of the mantra, first thing felt. meaningless yet. just true.
            "And with the wind... soar.",
            -- theme: lightness. something effortless. a moment of more.
            -- this is not power. not peace. just a feeling like the wind catching something.
            "I feel stronger.",
            "That was easier than it should have been.",
            "Something lifted.",
            "I feel lighter than I did.",
            "That landed right.",
            "I moved and it was right.",
            "I breathed and something cleared.",
            "I am still here.",
            "Something is different.",
            "I feel more solid.",
            "I almost felt something.",
            -- martial seeds: patient, effortless, not yet understood
            "I waited.",
            "I held.",
            "I didn't fall.",
            "I was ready.",
            "Something settled.",
            "I breathed.",
            -- connection seeds: the faintest pull toward others
            "I thought about her.",
            "I stayed.",
            "I noticed.",
            "I went back.",
            "I didn't leave.",
            -- the unfinished: barely audible
            "Something is unfinished.",
            "I carry something. I don't know its name yet.",
            "I have not yet said what needs to be said.",
            -- more lightness: moments of grace
            "The air tasted clean.",
            "My step was lighter.",
            "Something gave way. Gently.",
            "I smiled. I don't remember deciding to.",
            "The wind shifted. Something in me shifted with it.",
            "I looked up and it was beautiful. Just for a moment.",
            "I exhaled and something left with it.",
            "I felt easy. Just briefly. I want to feel that again.",
            "Something opened. I don't know what.",
            "I caught myself humming.",
            -- martial seeds: instinct before understanding
            "I dodged. I didn't think about it.",
            "I moved first.",
            "My body chose and it was right.",
            "I stood still and the moment passed around me.",
            "I was faster than I should have been.",
            -- connection: barely registered pulls
            "She looked sad. I noticed.",
            "I felt the need to stay.",
            "I turned around. I do not know why I turned around.",
            "Something about him. I cannot explain it.",
            "I was drawn back. Just slightly. Like a current.",
        },
    },
}

local WHISPER_TIERS_LIGHT = {
    -- ═══════════════════════════════════════════
    -- TIER 1 | 95-100 | RADIANCE
    -- "Immortal cultivation is the return of the willing."
    -- The Radiance Mantra is whole. You have been here before.
    -- You gave everything. You came back. You gave it again.
    -- ═══════════════════════════════════════════
    {
        minForce = 95,
        thoughts = {
            -- the Radiance Mantra, complete, earned through return
            "Immortal cultivation is the return of the willing.",
            "I give everything. That is the difference.",
            "I will be at the sea. I will wait.",
            "I hold on. Even now. Even after.",
            "I kneel so that someone else may stand.",
            "I have climbed this before. I will climb it again.",
            "I return to what was broken and try again.",
            "I am one grain. That is enough to begin.",
            "And with the light... return.",
            -- 777: not dread. recognition.
            "Seven hundred and seventy-seven times. I know what that number means now. It means I chose it every time.",
            "I have died seven hundred and seventy-seven lifetimes worth of deaths. Every one of them was for something.",
            "Seven hundred and seventy-seven. The number is not a cost. It is a record of how many times I said yes.",
            -- identity: fully present, fully given
            "I am not what remains after loss. I am what returns after it.",
            "I have given everything I had. The Force gave it back. I gave it again.",
            "I know what it costs. I paid it. I would pay it again without hesitation.",
            "There is nothing left in me that is only mine. I gave it all away. I have never been fuller.",
            "I am not powerful because I took. I am powerful because I kept giving when there was nothing left.",
            "The light did not choose me. I chose it. Every time. Every life. Every death.",
            "I have been afraid. I have been broken. I have been lost. I came back every time. That is what I am.",
            "I do not carry the light. The light carries what I gave it. There is a difference.",
            -- the return: what the Radiance Mantra actually is
            "I have stood in this moment before. I know how it ends. I am here anyway.",
            "I died for this once. More than once. The dying was not the point. The returning was not the point. The trying was the point.",
            "I remember every life I have spent on this. I would spend them all again.",
            "The Force does not promise you will succeed. It promises that if you return, it will be there. It always was.",
            "I have been here at the beginning so many times. I am no longer afraid of beginnings.",
            "Returning is not weakness. Returning is the whole practice.",
            "I remember what I lost. All of it. I remember who I lost. All of them. I carry them with me every time I come back.",
            -- sacrifice as the engine
            "I gave my life once for something that mattered. Then again. Then again. I stopped counting.",
            "Everything I ever held onto, I eventually gave away. That is not loss. That is cultivation.",
            "I have nothing that is only mine. That used to frighten me. Now it is the most free I have ever felt.",
            "I knelt so many times. Every time something rose that could not have risen otherwise.",
            "The light is not in me. The light is what I made space for by giving myself away.",
            -- peace that is genuinely peace
            "It is quiet tonight. I have earned this quiet. I will give it away when it is needed.",
            "I watched the sun rise. I have watched it rise many times. It is still extraordinary. It will always be extraordinary.",
            "I sat with someone who was afraid and I stayed until they weren't. That is the whole work.",
            "I tried to pray once. Something good answered. It said: I know. I have always known. Keep going.",
            "I am tired. The tiredness is clean. It is the tiredness of someone who gave what they had.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 2 | 80-94 | GIVING
    -- "I give everything. That is the difference."
    -- The self is fully offered. Nothing held back.
    -- Where the dark side drinks everything, you give it.
    -- ═══════════════════════════════════════════
    {
        minForce = 80,
        thoughts = {
            -- the Radiance Mantra line
            "I give everything. That is the difference.",
            -- 777
            "Seven hundred and seventy-seven. I have thought about that number. I think I understand it.",
            -- identity: the fully given self
            "I have nothing that is only mine anymore. That is not loss. That is the point.",
            "I keep giving and the Force keeps filling me. I do not understand the mechanism. I trust it.",
            "I have been broken by this. I came back. The coming back is the whole practice.",
            "I am not diminished by what I gave. I am exactly what I gave.",
            "The light is not something I have. It is something I make space for by emptying myself.",
            "I chose this. Every loss. Every sacrifice. Every return. I chose it.",
            -- sacrifice as daily practice
            "I gave something today that I wanted to keep. It was the right thing. I know because it hurt.",
            "Someone needed what I had more than I did. That sentence gets easier every time.",
            "I held something precious and then I opened my hands. The Force caught it.",
            "I wanted to keep it for myself. Something in me chose otherwise. That part is getting stronger.",
            "I did not do it because it was easy. I did it because it was right. Those are never the same thing.",
            -- connection: given not taken
            "I feel their pain and I do not absorb it. I stand in it with them. There is a difference.",
            "She was afraid. I stayed. I did not fix it. I stayed. That was enough.",
            "I gave my presence to someone who needed it. That is not a small thing.",
            "I love them. Not because the Force asks it. Because I choose it. Every day.",
            "I told him I would come back. I always come back. That is the only promise I make.",
            -- the return
            "I have been here before. Not this moment. This feeling. I know how to do this.",
            "I have failed at this before. I know which mistakes not to make. That knowledge cost something. It was worth it.",
            "I died for something once and came back and found it still needed doing. I did it again.",
            "Every time I return I remember why. The why gets clearer every time.",
            "I am not afraid of losing this. I have lost it before. I came back. So did it.",
            -- peace that costs
            "I am tired. The tiredness is clean. There is a difference between kinds of tired.",
            "I rest because I will be needed again. Rest is not retreat. Rest is preparation.",
            "I watched the sun rise. It was enough. It is always enough. I have learned that.",
            "I have given everything I have many times. The Force has never left me empty for long.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 3 | 65-79 | WAITING
    -- "I will be at the sea. I will wait."
    -- Where the dark side says there is no one there,
    -- you are there. You stay. You wait.
    -- ═══════════════════════════════════════════
    {
        minForce = 65,
        thoughts = {
            -- the Radiance Mantra line
            "I will be at the sea. I will wait.",
            -- identity: the one who stays
            "I am not the one who leaves. I have never been the one who leaves.",
            "I waited for them. They came. That is the whole story.",
            "Patience is not passivity. I am doing something when I wait. I am holding the space.",
            "I will be here when they are ready. That is the promise. I keep it.",
            "I do not know how long it will take. That is not the point. The point is I am still here.",
            -- staying when it costs
            "I stayed when everything in me wanted to leave. Something was different because I stayed.",
            "I chose to be present for something painful. Not because I could fix it. Because someone should be there.",
            "I held the vigil. I don't know if it mattered to them. It mattered to the Force.",
            "I waited through the night. The morning came. They were still alive. I was still there.",
            "Someone needed to know they were not alone. I made sure they knew.",
            -- the long patience of the light
            "I have waited before. In other lives I don't fully remember. I remember the waiting. I know how.",
            "I feel like I have been patient for a very long time. I think that is correct. I think the patience is almost over.",
            "Something in me knows how to endure. I didn't learn it in this life.",
            "I have been here at the end of things and stayed until the new beginning. I will do it again.",
            -- connection: presence as the gift
            "I sat with her and said nothing and she told me everything. Presence is the whole practice.",
            "I went to him not because I had answers. Because I had time. I gave him my time.",
            "I feel the loneliness in the people around me. I walk toward it. Not away.",
            "They didn't ask me to stay. I stayed. They noticed. The Force noticed.",
            -- the voice stepping back: you, watching yourself wait
            "You are learning to stay. That is harder than it sounds.",
            "You did not leave. That matters more than you know.",
            "You waited when you could have gone. Something is different because you waited.",
            "You held the space open. Someone walked through it. You will never know who.",
            "You are the kind of person who stays. You are becoming more of that person every day.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 4 | 50-64 | HOLDING ON
    -- "I hold on. Even now. Even after."
    -- Where the dark side says release them,
    -- you hold on. Not from fear. From love.
    -- ═══════════════════════════════════════════
    {
        minForce = 50,
        thoughts = {
            -- the Radiance Mantra line
            "I hold on. Even now. Even after.",
            -- holding on when it costs
            "I didn't let go. Something told me to let go. I didn't.",
            "They told me it was weakness to hold on. They were wrong.",
            "I kept the memory. I kept the promise. I kept the person in my heart. I kept all of it.",
            "The Force asked me to carry this. I said yes. I am still saying yes.",
            "I will not release what I love simply because holding it is difficult.",
            "I held on through the part where holding on felt impossible. Then it became possible again.",
            -- love as a practice
            "I love them. That is not a feeling that comes and goes. It is a choice I remake every day.",
            "I said I would be there. I am here. That is the whole thing.",
            "Someone asked if I still cared. I said yes. It was the simplest true thing I have ever said.",
            "I feel their grief through the Force. I do not turn away from it. I hold on tighter.",
            "I chose them again today. I will choose them again tomorrow. That is what love is.",
            -- the return beginning to surface
            "I feel like I have loved this person before. In a life I don't fully remember. The love feels worn in. Familiar.",
            "I have held on through worse than this. I know that without knowing how I know it.",
            "Something in me knows how to stay. It has stayed before. Through things I can't name.",
            "I feel older than I am. Not tired. Just... experienced in ways I haven't lived yet.",
            -- the voice: you, learning to hold
            "You did not let go. That was the right choice.",
            "You held on when it would have been easier to release. Something was saved because you held on.",
            "You chose to stay connected. The dark side of you wanted to sever it. You chose differently.",
            "You feel the pull to detach. You feel the opposite pull more strongly. Trust that.",
            "You are someone who holds on. You are becoming more certain of that.",
            -- the Force as something that holds you back
            "You feel held. Not trapped. Held. There is a difference.",
            "Something in the Force is carrying you. You don't have to do this alone.",
            "You reached and something reached back. It has always reached back.",
            "The Force does not abandon what chooses it. You felt that today.",
            "You are not alone in this. You have never been alone in this.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 5 | 35-49 | KNEELING
    -- "I kneel so that someone else may stand."
    -- Where the dark side places each beneath the other,
    -- you place yourself beneath. Freely. As a gift.
    -- ═══════════════════════════════════════════
    {
        minForce = 35,
        thoughts = {
            -- the Radiance Mantra line
            "I kneel so that someone else may stand.",
            -- selflessness arriving as instinct
            "I stepped back today so someone else could step forward. It felt right.",
            "I gave the credit away. Something in me didn't want to. Something else won.",
            "I helped them and I didn't need them to know it was me. That is new.",
            "I took the smaller portion. Not from guilt. Just because they needed more.",
            "Something in me is learning to want less for itself. I am glad.",
            "I put myself between them and the thing that was coming. I didn't decide to. I just did.",
            -- the force moving through selflessness
            "I reached for the Force today and it was very close. I think it is close when I am not reaching for myself.",
            "Something moved through me when I helped him. Not pride. Something cleaner.",
            "The light comes easier when I am not trying to hold it. When I am just trying to give it.",
            "I felt the Force move through me toward someone who needed it. I just tried not to be in the way.",
            -- the instinct to give
            "I keep giving things away. Time. Energy. Attention. Something in me doesn't miss them.",
            "Someone needed what I had. I gave it. The Force filled the space before I noticed it was empty.",
            "I am learning that giving is not losing. I have been learning this for longer than I know.",
            "I shared something I valued. Something else arrived that I valued more. This keeps happening.",
            -- the déjà vu beginning
            "I have done this before. This exact thing. For someone I can't remember. It worked then too.",
            "I feel like kneeling for others is something I know how to do. Something old in me knows the posture.",
            "I feel practised in sacrifice. I don't know where the practice came from.",
            -- the voice: I, learning the shape of service
            "I am not less because I gave. I am more because I gave.",
            "Something is asking me to place others first. I keep saying yes. It keeps being right.",
            "I don't know what I am becoming. I know it involves giving more than I take.",
            "I feel the pull to serve. Not as obligation. As calling.",
            "I am more solid when I am useful to someone else. I am beginning to think that is the point.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 6 | 20-34 | CLIMBING AGAIN
    -- "I have climbed this before. I will climb it again."
    -- Level 20. The Force is felt clearly for the first time.
    -- But it feels like the second time. Or the hundredth.
    -- ═══════════════════════════════════════════
    {
        minForce = 20,
        thoughts = {
            -- the Radiance Mantra line
            "I have climbed this before. I will climb it again.",
            -- awakening: felt as recognition, not discovery
            "I feel stronger.",
            "The Force is here. I feel like I have felt this before.",
            "I knew that was going to happen. Not because I sensed it. Because I remember it.",
            "That wasn't luck. I don't think it was ever luck.",
            "I moved it. I have moved it before. I don't know when.",
            "Something at the edge of my memory. Not a feeling. A place. A moment.",
            "I can feel the people around me. Their pain. Their hope. I have always been able to feel that.",
            "The Force chose me. I think I chose it first. I think I chose it many times.",
            "I felt it reach back. It felt like a reunion.",
            "Something in the light has known my name for a very long time.",
            -- déjà vu as the signature of the Radiance Mantra
            "I have stood here before. I don't know when. The feeling is very specific.",
            "I have made this choice before. I made the right one then too. I remember that.",
            "This moment feels worn in. Like something I have practised.",
            "I know this grief. I have grieved this before. In a life I don't remember. I know how to carry it.",
            "Something in me already knows what comes next. Not prediction. Memory.",
            -- the force as return
            "I feel like I am arriving somewhere I have left before.",
            "Something is familiar about the light. Not comforting exactly. Known.",
            "I feel like the Force is greeting me. Not introducing itself.",
            "I have been here at the beginning before. I know what the beginning feels like.",
            -- martial: patience, the body knowing before the mind
            "I waited. Something told me to wait. I have been told that before.",
            "I didn't rush. Something very old in me knows not to rush.",
            "Patience is not stillness. I know the difference. I learned it somewhere.",
            "My body knew before I did. It has known things before I did for as long as I can remember.",
            "I took the hit. I stayed upright. I have done this before.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 7 | 12-19 | RETURNING
    -- "I return to what was broken and try again."
    -- You don't know why things feel familiar.
    -- But you keep going back to the broken things.
    -- ═══════════════════════════════════════════
    {
        minForce = 12,
        thoughts = {
            -- the Radiance Mantra line
            "I return to what was broken and try again.",
            -- the pull to go back
            "I went back. I don't know why I went back. Something needed finishing.",
            "Something is unfinished. I keep feeling it. I keep turning toward it.",
            "I tried to leave it alone. I couldn't. Something kept returning me to it.",
            "I fixed something today that I didn't break. I don't know why it felt like mine to fix.",
            "I keep going back to the same people. The ones who are still hurting. Something in me won't leave them.",
            -- the Force as something you're returning to, not discovering
            "I felt something. Not new. Remembered.",
            "The Force is here. It feels like it has always been here. Like I am the one who left.",
            "I reached for something. It was already there. It was waiting.",
            "Something in the Force feels like home. I don't have a word for that yet.",
            "I have been away from this. I am not sure how long. I am back now.",
            -- déjà vu: subtle, physical
            "I have been in this exact place before. The feeling is very specific. The light was the same.",
            "I said something today and it felt worn in. Like I have said it before. Like it worked before.",
            "I know this person. Not from this life. From something else. The knowing is very quiet.",
            "I dreamed of a place I have never been. I was not afraid. I had been there before.",
            -- martial: the patient returner
            "I feel stronger.",
            "I took the blow. I stayed upright. I have done this before.",
            "I waited. I was right to wait. I have been right to wait before.",
            "Something in my stance is familiar. Like muscle memory from a life I didn't live.",
            "I breathed. The moment passed. I knew it would pass. I have waited for this moment to pass before.",
            -- connection: the ones you keep returning to
            "I thought about her today. I have thought about her before. In a way I can't explain.",
            "I stayed when I could have left. Something told me I had left before. That it had mattered.",
            "Someone needed something. I knew exactly what. I don't know how I knew.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 8 | 8-11 | ONE GRAIN
    -- "I am one grain. That is enough to begin."
    -- Where the dark side says one grain is nothing,
    -- you feel the grain. Small. Certain. Enough.
    -- ═══════════════════════════════════════════
    {
        minForce = 8,
        thoughts = {
            -- the Radiance Mantra line: raw, physical, before meaning
            "I am one grain. That is enough to begin.",
            -- small and certain
            "I feel stronger.",
            "That was small. It mattered.",
            "I did one right thing today.",
            "Something is beginning.",
            "I took one step.",
            "I was there.",
            "I helped.",
            "I stayed.",
            "I tried.",
            "I came back.",
            "I am still here.",
            "I am enough.",
            "It is enough.",
            -- the faintest return
            "I feel like I have been here before.",
            "Something is familiar.",
            "I almost remembered something.",
            "I have done this before. I am certain of it.",
            "Something is waiting to be recognised.",
            "I feel like I am returning to something.",
            "I am not starting. I am continuing.",
            -- connection: barely, just a warmth
            "I thought about her.",
            "I went back.",
            "I stayed when I could have left.",
            "I noticed him. I'm glad I noticed.",
            "Something in me moved toward her before I decided to move.",
        },
    },

    -- ═══════════════════════════════════════════
    -- TIER 9 | 5-7 | RETURN SEEDS
    -- "And with the light... return."
    -- Almost nothing. Just a feeling of having been here before.
    -- The lightest possible static. Warm at the edges.
    -- ═══════════════════════════════════════════
    {
        minForce = 5,
        thoughts = {
            -- the Radiance Mantra line: last line, first felt. meaningless yet. just true.
            "And with the light... return.",
            -- déjà vu seeds: barely perceptible
            "I have been here before.",
            "This is familiar.",
            "I know this.",
            "I have done this.",
            "I remember this. Almost.",
            "Something is recognised.",
            "I have felt this before.",
            "I know this place.",
            "I know this person.",
            "I have said these words.",
            "I have made this choice.",
            "I remember being here.",
            -- light seeds: small moments of rightness
            "That felt right.",
            "I feel stronger.",
            "Something is good.",
            "I helped.",
            "I stayed.",
            "I came back.",
            "It is enough.",
            "I am enough.",
            "Something is beginning.",
            -- warmth seeds: the faintest pull toward others
            "I thought about her.",
            "I went back.",
            "I noticed.",
            "I stayed.",
            "Something moved me toward them.",
            -- the unfinished: not dread. just direction.
            "Something is not yet done.",
            "I have not yet finished.",
            "There is something to return to.",
            "I know the way back.",
            "I will try again.",
        },
    },
}




-- ─────────────────────────────────────────────
-- Alignment → Tier Table Mapping
-- ─────────────────────────────────────────────

local ALIGNMENT_TIERS = {
    dark  = WHISPER_TIERS_DARK,
    light = WHISPER_TIERS_LIGHT,
    grey  = WHISPER_TIERS_GREY,
}

local ALL_ALIGNMENTS = {"dark", "light", "grey"}

--- Pick appropriate messages for a player's force level from a specific tier table.
-- @param tierTable table One of WHISPER_TIERS_DARK/LIGHT/GREY
-- @param forceAttr number The player's force attribute value
-- @return table Array of thought strings, or nil if none match
local function getThoughtsForLevel(tierTable, forceAttr)
    for _, tier in ipairs(tierTable) do
        if forceAttr >= tier.minForce then
            return tier.thoughts
        end
    end
    return nil
end

--- Determine a player's force alignment from character data.
-- Returns "dark", "light", "grey", or nil if unaligned.
-- The perk system will set this via char:SetData("forceAlignment", alignment).
-- @param char Character
-- @return string|nil
local function getPlayerAlignment(char)
    return char:GetData("forceAlignment", nil)
end

--- Dispatch a single force whisper packet to a client.
-- @param client Player
-- @param alignment string "dark"|"light"|"grey"
-- @param intensity string "strong"|"subtle"
-- @param thought string
local function sendWhisper(client, alignment, intensity, thought)
    if not IsValid(client) then return end

    net.Start("ixForceWhisper")
        net.WriteString(alignment)
        net.WriteString(intensity)
        net.WriteString(thought)
    net.Send(client)
end

-- ─────────────────────────────────────────────
-- Timer
-- ─────────────────────────────────────────────

local TIMER_ID = "ixForceWhisperTick"

timer.Create(TIMER_ID, 10, 0, function()
    local interval = ix.config.Get("forceWhisperInterval", 120)
    local chance   = ix.config.Get("forceWhisperChance", 5)

    for _, client in ipairs(player.GetAll()) do
        if not IsValid(client) or not client:Alive() then continue end

        local char = client:GetCharacter()
        if not char then continue end

        local forceAttr = char:GetAttribute("force", 0)
        if forceAttr <= 0 then continue end

        -- Per-player cooldown
        local now  = CurTime()
        local last = client._ixLastForceWhisper or 0
        if now - last < interval then continue end

        -- Roll chance
        if math.random(100) > chance then continue end

        -- Determine alignment and pick thoughts accordingly
        local alignment = getPlayerAlignment(char)
        local thoughts, chosenAlignment

        if alignment and ALIGNMENT_TIERS[alignment] then
            -- Committed to a side — draw from that side's table
            chosenAlignment = alignment
            thoughts = getThoughtsForLevel(ALIGNMENT_TIERS[alignment], forceAttr)
        else
            -- Uncommitted — pick randomly from all three sides
            -- This covers early perk tree stages where players explore multiple sides
            chosenAlignment = ALL_ALIGNMENTS[math.random(#ALL_ALIGNMENTS)]
            thoughts = getThoughtsForLevel(ALIGNMENT_TIERS[chosenAlignment], forceAttr)
        end

        if not thoughts then continue end

        client._ixLastForceWhisper = now

        -- Pick a single thought to send
        local thought = thoughts[math.random(#thoughts)]

        -- Intensity: higher force = more prominent display
        local intensity = forceAttr >= 50 and "strong" or "subtle"

        sendWhisper(client, chosenAlignment, intensity, thought)
    end
end)

-- ─────────────────────────────────────────────
-- Admin Testing Commands
-- ─────────────────────────────────────────────

ix.command.Add("ForceWhisperSetAlignment", {
    description = "[DEV] Set a player's force alignment (dark/light/grey/none).",
    adminOnly = true,
    arguments = {
        ix.type.player,
        ix.type.text,
    },
    OnRun = function(self, client, target, alignment)
        local char = target:GetCharacter()
        if not char then
            return "Target has no active character."
        end

        alignment = string.lower(string.Trim(alignment or ""))

        if alignment == "none" or alignment == "nil" or alignment == "auto" then
            char:SetData("forceAlignment", nil)
            client:Notify("Cleared " .. target:Name() .. " force alignment (now uncommitted).")
            target:Notify("Your force alignment has been cleared.")
            return
        end

        if not ALIGNMENT_TIERS[alignment] then
            return "Invalid alignment. Use: dark, light, grey, or none"
        end

        char:SetData("forceAlignment", alignment)
        client:Notify("Set " .. target:Name() .. " force alignment to " .. alignment .. ".")
        target:Notify("Your force alignment is now " .. alignment .. ".")
    end,
})

ix.command.Add("ForceWhisperTest", {
    description = "[DEV] Send a test whisper. Args: [player] [alignment] [intensity] [forceValue]",
    adminOnly = true,
    arguments = {
        bit.bor(ix.type.player, ix.type.optional),
        bit.bor(ix.type.text, ix.type.optional),
        bit.bor(ix.type.text, ix.type.optional),
        bit.bor(ix.type.number, ix.type.optional),
    },
    OnRun = function(self, client, target, alignment, intensity, forceValue)
        target = IsValid(target) and target or client

        local char = target:GetCharacter()
        if not char then
            return "Target has no active character."
        end

        local effectiveForce = tonumber(forceValue) or char:GetAttribute("force", 0)
        effectiveForce = math.Clamp(math.floor(effectiveForce), 0, 100)

        alignment = string.lower(string.Trim(alignment or ""))
        if alignment == "" or alignment == "auto" then
            alignment = getPlayerAlignment(char)
            if not alignment or not ALIGNMENT_TIERS[alignment] then
                alignment = ALL_ALIGNMENTS[math.random(#ALL_ALIGNMENTS)]
            end
        end

        if not ALIGNMENT_TIERS[alignment] then
            return "Invalid alignment. Use: dark, light, grey, or auto"
        end

        intensity = string.lower(string.Trim(intensity or ""))
        if intensity == "" or intensity == "auto" then
            intensity = effectiveForce >= 50 and "strong" or "subtle"
        end

        if intensity != "strong" and intensity != "subtle" then
            return "Invalid intensity. Use: strong, subtle, or auto"
        end

        local thoughts = getThoughtsForLevel(ALIGNMENT_TIERS[alignment], effectiveForce)
        if not thoughts or #thoughts == 0 then
            return "No whisper tier found (force must be >= 5)."
        end

        local thought = thoughts[math.random(#thoughts)]
        sendWhisper(target, alignment, intensity, thought)

        client:Notify(string.format(
            "Sent %s whisper (%s, force=%d) to %s.",
            alignment,
            intensity,
            effectiveForce,
            target:Name()
        ))

        if target != client then
            target:Notify("A test force whisper was triggered by staff.")
        end
    end,
})
