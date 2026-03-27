##### INTERNAL DEVELOPMENT DOCUMENT

# IMPERIAL DATAPAD DECRYPTION

#### Lootbox Minigame & Unlock Sequence — Full Design Document

```
Skeleton Gamemode • Star Wars Imperial Themed
```
## 1. Overview

The Imperial Datapad Decryption system replaces a conventional lootbox "open and
receive" interaction with an active skill-based minigame natively integrated into the `skeleton` gamemode. Players who want to access the
contents of locked Imperial supply crates, data manifests, or contraband caches must
first decrypt the datapad securing it. The complexity and stakes of the decryption scale
directly with the classification tier of the crate being opened, tying into our broader `unlocktrees` and `usms` progression loops.

The system is designed to feel native to a Star Wars Imperial setting — the player is not
"picking a lock" or "hacking a terminal" using our existing `hackingsys`, but rather interfacing with
Imperial encryption protocols in the field.

```
Design Philosophy
The core design goal is progressive spatial feedback — players should feel like they are
doing something with their hands, not solving a logic puzzle with their brain. The skill ceiling
should be meaningful but not punishing. A first-time player should be able to open a Civilian
crate with minor effort. A Top Secret crate should feel like genuine tension even for
experienced players.
```
## 2. Thematic Framing

Each lootbox tier is represented in-world as a specific type of Imperial secured
container:

- Civilian → Imperial Surplus Manifest. Loosely encrypted civilian-grade supply
    containers. Low-priority goods, common equipment, rations.
- Restricted → Garrison Supply Crate. Standard trooper-issue equipment caches.
    Restricted to authorized Imperial personnel.
- Classified → ISB Evidence Locker. Sensitive materials, intercepted contraband,
    intelligence assets. Classified clearance required.


##### INTERNAL DEVELOPMENT DOCUMENT

- Top Secret → Black Cipher Container. High-value Imperial assets, prototype
    equipment, command-level intelligence. Multi-layer encryption.

The UI for each tier should visually reflect its classification — simple clean panels for
Civilian, increasingly angular and warning-heavy layouts for higher tiers. Aurebesh
characters are used throughout as glyphs rather than Latin alphabet, both for immersion
and to prevent players from reading patterns too easily.

## 3. Minigame Mechanics — Frequency Lock

### 3.1 Core Concept

The minigame is called a Frequency Lock internally. The player is depicted as "tuning
into" the encrypted frequency of the datapad's security layer to identify and input the
correct unlock sequence.

The UI consists of three primary components:

- Glyph Grid — A rectangular grid of Aurebesh glyphs (the pool). All glyphs are
    displayed simultaneously. The size of the pool scales with tier.
- Sequence Bar — A row of empty slots at the top of the panel. This is where
    correctly identified glyphs are locked in one at a time.
- Feedback Pulse — A visual and optional audio indicator that responds to cursor
    proximity to correct glyphs. This is the central skill element.

### 3.2 Phase 1 — Scan

The player moves their cursor across the glyph grid. As they hover near glyphs, the
Feedback Pulse activates:

- Correct glyph in the current sequence position: Strong pulse, bright highlight ring,
    optional low tone.
- Adjacent to correct glyph: Mild pulse, faint ring.
- Wrong glyph entirely: No response.

The feedback is intentionally analog — it does not point directly at the correct glyph but
rewards the player for methodically scanning the grid. At higher tiers, the pulse radius
shrinks and the visual signal weakens, meaning the player must be closer to the correct
glyph before they get any feedback at all.


##### INTERNAL DEVELOPMENT DOCUMENT

```
Implementation Note
Feedback strength is calculated as a falloff curve from the cursor to the correct glyph's
center position using a simple distance check. The pulse alpha/scale is mapped to: pulse =
math.Clamp(1 - (dist / maxDist), 0, 1) where maxDist scales inversely with tier. This keeps
the logic simple and the feel smooth.
```
### 3.3 Phase 2 — Lock

When the player believes they have found the correct glyph for the current sequence
position, they click to lock it in.

- Correct lock: The glyph snaps into the next slot of the Sequence Bar with a
    satisfying visual confirmation (green flash, slot fills). Scan phase resumes for the
    next position.
- Incorrect lock: The Sequence Bar resets to empty. Counter-Intrusion measures
    activate depending on tier (see Section 4.2). The feedback pulse radius is also
    permanently reduced slightly for the remainder of this attempt, simulating the
    datapad's security system adapting.

The player must lock in all glyphs in sequence within the time limit to achieve a full
success. Running out of time counts as a failed attempt.

### 3.4 Tier Scaling

The following table defines the parameters for each classification tier:

```
Tier Glyph Pool Sequence
Length
```
```
Feedback
Strength
```
```
Time Limit Counter-
Intrusion
Civilian 8 3 Strong 45s None
Restricted 12 4 Medium 35s Mild (1 reset)
Classified 16 5 Weak 25s Moderate
(feedback
degrades)
Top Secret 20 6 Very Weak 20s Aggressive
(lockout on
2nd fail)
```

##### INTERNAL DEVELOPMENT DOCUMENT

Note: "Counter-Intrusion" refers to additional mechanical penalties applied on incorrect
lock attempts beyond the base sequence reset. These are detailed in Section 4.2.

## 4. Failure & Degradation

### 4.1 Partial Credit System

Rather than a binary pass/fail, the minigame tracks how far through the sequence the
player progressed before failing. This creates a partial skill reward and ensures that a
skilled player who nearly succeeds is not treated identically to someone who did not try.

The following table defines loot outcomes based on sequence progress at time of
failure:

```
Glyphs Locked In Outcome Notes
0 of N Full tier downgrade Top Secret becomes Classified, etc.
1 of N Full tier downgrade Partial credit only if >2 required
2 - 3 of N (mid) Half-tier downgrade One high-value item replaced with lower tier
N-1 (near miss) Minor downgrade Single lowest-value item swapped out
N (full success) Full loot reward Unlock sequence triggers
```
Tier downgrades are applied by substituting the loot pool of the next tier down. A "half-
tier" downgrade replaces only the highest-value item slot in the pool with an equivalent
draw from the tier below. Minor downgrades replace only the single lowest-value item.

### 4.2 Counter-Intrusion Measures

Higher-tier crates include escalating counter-intrusion responses to wrong lock
attempts. These are mechanical penalties that stack for the remainder of the current
attempt:

- Civilian: No counter-intrusion. Wrong locks only reset the sequence.
- Restricted: One free wrong lock. Second wrong lock shrinks the feedback pulse
    radius by 20%.
- Classified: Each wrong lock reduces feedback pulse radius by 20% and adds 1
    second of "static" — a brief visual noise overlay that obscures the grid
    momentarily.


##### INTERNAL DEVELOPMENT DOCUMENT

- Top Secret: Two wrong locks trigger a 3-second lockout during which the UI is
    frozen and an alarm sound plays. A third wrong lock ends the attempt entirely (no
    retry), applying the 0-of-N downgrade.

```
Design Intent
Counter-intrusion is not meant to be brutally punishing — it is meant to create tension and
raise the stakes as the player progresses up tiers. A Civilian crate should feel casual. A Top
Secret crate should feel like defusing a bomb.
```
### 4.3 Attempt Limits & Retry Behavior

Unless the Top Secret lockout rule triggers, players may retry a failed attempt.
However, each retry on the same crate applies a stacking 5-second cooldown before
the minigame panel reopens. This prevents rapid-fire retrying and keeps the tension
alive across attempts. The crate itself does not disappear or lock permanently on failure
— it simply degrades the available loot pool for that instance.

## 5. UI Layout & Visual Design

### 5.1 Panel Structure

The minigame panel is rendered in VGUI/Derma. The outer frame uses an Imperial
aesthetic — dark charcoal background (#1A1A2E), angular corner decorations, and thin
red accent lines. The overall shape is rectangular, not circular, to allow clean grid hit
zones for glyph selection.

Panel dimensions: approximately 600px wide by 500px tall. Centered on screen.

The panel contains three major zones arranged vertically:

- Header Zone (top ~15%): Classification tier badge, crate type label in Aurebesh,
    and countdown timer. Timer color shifts from white to yellow to red as it depletes.
- Sequence Bar (below header, ~12%): A horizontal row of glyph-sized slots
    showing current lock progress. Empty slots render as dim outlines. Filled slots
    show the locked glyph with a green tint.
- Glyph Grid (center ~60%): The main interaction area. Glyphs are arranged in an
    evenly-spaced grid. Spacing adapts to pool size. Higher tiers use smaller glyph
    cells to fit the larger pool.


##### INTERNAL DEVELOPMENT DOCUMENT

- Status Bar (bottom ~13%): Instructional text ("SCAN FOR SIGNAL — LOCK
    TARGET GLYPH"), counter-intrusion warning messages, and a small Imperial
    cog icon that rotates slowly.

### 5.2 Glyph Rendering

Glyphs are rendered using an Aurebesh font. Each glyph cell has three visual states:

- Idle: Dim white glyph on dark background, thin border.
- Pulsing (near correct): Glyph brightens, border ring expands and fades in a loop.
    Intensity and ring size scale with feedback strength.
- Locked In: Glyph not removed from grid but visually "crossed out" with a green
    check. This is intentional — removing locked glyphs makes the grid feel barren
    and reduces the spatial challenge.

### 5.3 Audio Design

Audio is a critical component of the feedback loop and should not be treated as optional
polish:

- Scan ambience: A subtle low electronic hum plays during the scan phase, rising
    very slightly in pitch as the cursor nears a correct glyph. This provides audio
    feedback independent of visual.
- Correct lock: A clean two-tone chime (low then high). Satisfying, not celebratory.
- Wrong lock: A harsh single-tone buzz. Brief. Jarring but not annoying.
- Counter-intrusion static: White noise burst for 0.5 seconds accompanying the
    visual static overlay.
- Top Secret lockout: Imperial-style alarm tone, 3 seconds. Should feel serious.
- Timer warning: Subtle ticking sound begins at 10 seconds remaining,
    accelerating.

## 6. Unlock Sequence — Post-Success Animation

On full success (all glyphs locked in correctly within the time limit), the minigame
transitions into the Unlock Sequence. This is a scripted animation and audio sequence
lasting approximately 4 seconds before the loot window appears. It serves as a reward
beat — the player has earned this moment and it should feel earned.


##### INTERNAL DEVELOPMENT DOCUMENT

### 6.1 Beat-by-Beat Breakdown

```
Beat Duration Description
1 0.0 - 0.3s Final glyph locks in with a sharp green flash across the
sequence bar
2 0.3 - 1.0s All glyphs pulse in unison — white to green, left to right in
a cascade
3 1.0 - 1.8s The outer ring of the UI spins a full 360 degrees with an
acceleration then hard stop
4 1.8 - 2.5s Screen overlay briefly flashes a faint Imperial cog/sigil in
translucent white
5 2.5 - 3.2s Text appears center frame: 'ACCESS GRANTED —
IMPERIAL MANIFEST UNSEALED'
6 3.2 - 4.0s UI dissolves outward in a radial wipe, loot window slides
in from below
7 4.0s+ Loot items drop into the window one by one with
individual item sounds
```
### 6.2 Tier-Specific Unlock Variations

The core sequence above is consistent across all tiers. However, each tier applies a
visual skin to the sequence to reinforce its weight:

- Civilian: Clean, quick. White and green tones. Minimal fanfare. The sigil does not
    appear.
- Restricted: Standard sequence as above. Mild red accent on the ring spin.
- Classified: The ring spin does two full rotations instead of one. The sigil is more
    opaque. "ACCESS GRANTED" text is preceded by a 0.3s redacted-text
    scramble effect.
- Top Secret: All of the above. The flash overlay covers more of the screen. The
    loot window entrance is accompanied by a dramatic bass hit. Items drop in with a
    0.4s delay between each rather than 0.2s, drawing out the reveal.

### 6.3 Degraded Unlock Sequence (Partial Failure)

When the player achieved a partial success and opens a degraded loot pool, the unlock
sequence plays a shortened and visually muted version:

- No ring spin animation.


##### INTERNAL DEVELOPMENT DOCUMENT

- Glyph cascade uses amber/yellow tones instead of green.
- Text reads: 'PARTIAL ACCESS — MANIFEST CORRUPTED' instead of
    'ACCESS GRANTED'.
- Loot window slides in from the side rather than from below, reinforcing that this is
    a different outcome.

```
Design Note
The degraded sequence should still feel rewarding relative to a full failure — the player did
something right and that should be communicated visually. The amber colour palette
threads the needle between 'success' and 'not quite', without feeling like a failure state.
```
## 7. Implementation Notes for Skeleton Gamemode

### 7.1 Skeleton System Integrations

The Datapad Decryption minigame runs inside the `lootbox` plugin, integrating deeply with the various custom systems of the `skeleton` gamemode:

*   **Hacking System (`hackingsys`)**: While our established `hackingsys` will continue handling logical terminal networks and base computer access, the `lootbox` plugin specifically handles local, physical datapad encryptions. Failed attempts here could optionally flag the user's ID within `hackingsys` networks as a localized slicing risk.
*   **Unit & Squad Management (`usms`)**: Top Secret and Classified crates can interact with unit roles. Characters assigned to specialized "Slicer" or "Intelligence" squads via `usms` may receive inherent buffs (e.g., +5 seconds on the timer or a wider initial feedback pulse radius).
*   **Unlock Trees (`unlocktrees`)**: Successful decryptions should provide direct progression beyond physical loot. High-tier crates may dispense "Research Data" or unlock points directly into a player's `unlocktrees` progression, facilitating access to higher-tier slicing or tech character skills.

### 7.2 Loot Pool Architecture & Delivery

Each lootbox entity (`ix_lootbox`) will carry a tier designation
(civilian/restricted/classified/topsecret) as a networked variable. Rather than pure random generation, tables will be defined in a shared layout that explicitly targets `skeleton` schema items:
*   **Low tier**: Credits, ration items, baseline salvage.
*   **Mid tier**: `medicalsys` standard stims, `arccw_support` weapon attachments.
*   **High tier**: High-grade blueprints, specialized `medicalsys` compounds, rare `theos-forcesystem` crystals, and classified terminal logs.

On success, the server draws from the full tier table. On partial
success, highest-value nodes (like unlock points or crystals) are replaced by the appropriate degraded table components. Item delivery continues to leverage standard
Helix inventory hooks.

### 7.3 VGUI Rendering Considerations

All animation (pulse, ring spin, cascade) should be driven by CurTime() delta rather than
timers to ensure frame-rate independence. The feedback pulse falloff calculation should
run in the panel's Paint hook on every frame. Use surface.DrawCircle for pulse rings
and surface.DrawRect for glyph cells. The Aurebesh font must be included in the
resource manifest and precached.

```
Performance Note
```

##### INTERNAL DEVELOPMENT DOCUMENT

```
The per-frame distance calculation for feedback pulse across 20 glyphs at Top Secret tier is
negligible. No optimisation is needed. However, audio pitch shifting for the scan ambience
hum should use a smoothed lerp rather than snapping to avoid audio artifacts when the
cursor moves quickly.
```
### 7.4 Server-Side Validation

The minigame runs client-side but the actual correct glyph sequence must be generated
server-side and sent to the client at open time via a net message. The client never
knows the sequence in advance — it only receives a "check this glyph" net message
response on each lock attempt. This prevents console-based cheating. The server
tracks attempt count and applies the degradation multiplier before calling the loot
delivery hook.

##### END OF DESIGN DOCUMENT

```
Imperial Information Systems • Skeleton Gamemode Development • Version 2.0
```

