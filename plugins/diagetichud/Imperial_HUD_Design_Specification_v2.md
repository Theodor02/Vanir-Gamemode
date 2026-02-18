# IMPERIAL HUD DESIGN SPECIFICATION

**Garry's Mod Helix Framework**  
*Star Wars Imperial Roleplay Server*

---

## Executive Summary

This document outlines the design specifications for a diegetic, minimalist heads-up display (HUD) system for an Imperial Star Wars roleplay server. The HUD prioritizes immersion through clean military aesthetics, contextual element visibility, transparent presentation, and a clear information hierarchy that responds dynamically to gameplay state.

---

## Design Philosophy

### Core Principles

- **Diegetic Design:** Every element should feel like Imperial military equipment, not a video game overlay. The HUD represents tactical data readouts that would exist in-universe on a trooper's equipment.

- **Minimal & Transparent:** Information is presented only when relevant, with transparent backgrounds that don't obstruct the gameplay view. Elements fade or hide when not needed to maintain clear sightlines and immersion.

- **Functional Over Decorative:** Clean typography, minimal borders, and restrained color palette. No heavy panels, excessive glow, or obstructive backgrounds that block the game world.

- **Clear Information Hierarchy:** Critical information takes visual precedence through size and positioning. Priority orders override objectives, which override DEFCON status. Life-threatening conditions demand immediate attention.

### Visual Direction

The aesthetic draws from Imperial military design language: tactical, diagnostic, and authoritarian. The key difference from menu UI is transparency—HUD elements float above the gameplay with semi-transparent backgrounds, allowing the game world to remain visible. Typography is serif for headers (Imperial formality) and monospace for technical data (military readouts). Colors are muted with purpose-driven accents:

- **Base palette:** White/gray text with transparent black backgrounds (40-70% opacity)
- **Accent colors:** Amber for objectives, cyan for communications, gold for Imperial data
- **Status colors:** Green for healthy, yellow for caution, red for danger
- **Borders:** Minimal—4px colored left borders for categorization

**Font Usage:**
- **Georgia/Times (serif):** Player names, headers, mission titles—formal Imperial presentation
- **Courier New (monospace):** Technical data, frequencies, coordinates, stats—military readouts
- **Text shadows:** All text has subtle shadows for readability against any background

---

## Information Architecture

### Priority Hierarchy System

The HUD implements a strict visual priority system where higher-priority information automatically takes precedence in display prominence, though DEFCON status remains visible at all times to maintain baseline threat awareness.

1. **Priority Orders** (Highest) - Server-wide emergency directives from command. Displays with red left border and increased opacity.

2. **Critical Health** (<20%) - Subtle red border overlay with diagnostic warnings. Does not block view but provides clear indication.

3. **Weapon Overheat/Reload State** - Critical weapon status displays with progressive color warnings.

4. **Current Objective** - Player or squad-specific tasks. Amber left border for visibility.

5. **DEFCON Status** - Base threat level indicator. Always visible but reduces opacity when higher priorities are active.

6. **Standard HUD Elements** - Compass, vitals, ammo, squad status. Always visible but transparent and minimal.

---

## Layout & Positioning

The layout is designed to avoid overlap conflicts and maintain clear sightlines to gameplay. All elements use transparent backgrounds and are anchored to screen edges with sufficient padding.

### Top Region

- **Top Left:** Priority Orders / Current Objective / DEFCON Status (hierarchy-based display with DEFCON always visible)
- **Top Center:** Large bearing display with degree markings and cardinal directions, waypoint data below
- **Top Right:** Communications panel with channel connections and active transmission display

### Middle Region

- **Left Mid:** Fireteam/Squad roster (member names, health bars, distance, bearing indicators)

### Bottom Region

- **Bottom Left:** Player identity (name, rank, regiment), health vitals bar, stamina bar
- **Bottom Right:** Weapon designation, fire mode indicator, ammunition display (magazine/reserve), overheat indicator

---

## Feature Specifications

### Health & Stamina System

**Visual Elements:**
- Horizontal bar display with percentage indicator
- Color-coded health states: Gold (>60%), Yellow (30-60%), Red (<30%)
- Critical health (<20%) triggers subtle red screen border (30% opacity)
- Stamina bar in gold with percentage, no critical warnings
- Transparent backgrounds that don't obstruct gameplay

**Behavior:**
- Always visible with minimal presentation
- Directional damage flash (brief red gradient from damage direction)
- Vignette effect intensifies as health decreases

### Weapon & Ammunition Display

**Visual Elements:**
- Large monospace numbers for magazine count and reserve ammunition  
- Fire mode indicator (AUTO/SEMI/BURST) in amber-bordered box
- Integrated overheat bar below ammo: Gold (<50%), Yellow (50-80%), Red (>80%)
- Reload progress indicator with yellow accent during reload state
- Weapon designation text (e.g., DC-15A CARBINE) above fire mode
- Always shows overheat bar (at 0%) so players understand the mechanic exists

**Behavior:**
- Entire weapon panel hidden when unarmed
- Red text "NO AMMUNITION" message when magazine empty
- Overheat indicator always visible to communicate weapon mechanics
- Fire mode changes show clear visual confirmation

### Communications System

**Core Concept:**
- Players can connect to up to 2 radio channels simultaneously
- Connected channels display persistently (always visible when radio equipped)
- Active transmissions show dynamically when someone is talking
- Clear visual distinction between "connected" vs "actively transmitting"

**Visual Elements:**

*Connected Channels Panel (Persistent):*
- Always visible in top-right when player has radio equipment
- Shows both connected channels (up to 2) with:
  - Channel name (e.g., COMMAND NET, SQUAD COMMS)
  - Frequency (e.g., 8858.0 MHZ)
  - Encryption status (🔒 or 🔓)
  - Connection indicator (cyan dot)
- Counter showing current connections (1/2, 2/2)
- Clickable to expand channel selection menu
- If not connected to any channels, shows prompt: "No active channels // Click to connect"

*Active Transmission Panel (Dynamic):*
- Appears above connected channels when someone is talking
- Pulsing cyan border and animated cyan indicator dot
- Shows:
  - Speaker portrait/designation
  - Speaker name (e.g., CT-7734)
  - Which channel they're transmitting on
  - Encryption status and frequency
- Auto-disappears when transmission ends
- One of the connected channels highlights with active indicator during transmission

*Channel Selection Menu (Expandable):*
- Opens downward from connected channels panel
- Shows all available channels with:
  - Connection status (cyan dot + "CONNECTED" text if active)
  - Channel name and frequency
  - Encryption indicators
  - Maximum connection limit (MAX 2)
- Click to connect/disconnect from channels
- If at 2-channel limit, connecting to new channel replaces oldest connection
- Grayed out channels indicate limit reached

**Behavior:**
- Entire comms section hidden when player has no radio equipment
- Connected channels always visible when equipped (even when silent)
- Transmission panel appears contextually during active voice
- Menu smoothly expands/collapses on interaction
- Can manage channels without active communication

**State Examples:**

*No channels connected:*
```
[Gray border panel]
COMMS ▶
No active channels
Click to connect
```

*Connected to 2 channels, no one talking:*
```
[Cyan border panel]
COMMS ▶  2/2
• COMMAND NET  🔒
  8858.0 MHZ
  
  SQUAD COMMS   🔒
  4521.5 MHZ
```

*Someone transmitting on Squad Comms:*
```
[Pulsing cyan border panel]
ACTIVE TRANSMISSION
[Portrait] CT-7734
           SQUAD COMMS
🔒 ENCRYPTED // 4521.5 MHZ

[Normal cyan border panel below]
COMMS ▼  2/2
  COMMAND NET   🔒
  8858.0 MHZ
  
• SQUAD COMMS   🔒  ← Active indicator
  4521.5 MHZ
```

### Squad/Fireteam Panel

**Visual Elements:**
- Header showing fireteam designation (e.g., FIRETEAM AUREK)
- Member entries with rank abbreviation badge, designation, status
- Compact health bar for each member (color-coded: Gold/Yellow/Red)
- Status indicator: ACTIVE (gold), ENGAGED (yellow), WOUNDED (red)
- Distance display in meters
- Bearing with directional arrow (↑↗→↘↓↙←↖) relative to player facing

**Behavior:**
- Hidden when player is not in a squad
- Positioned at left-mid to avoid overlap with vitals
- Updates in real-time as squad members take damage or change status
- Directional indicators update as player rotates

### Compass & Navigation

**Visual Elements:**
- Large three-digit bearing display in amber (000-359)
- Cardinal direction indicators (N/E/S/W) with active direction highlighted in amber
- Waypoint displays below compass showing:
  - Target type prefix (TGT: for objectives, THR: for threats)
  - Target designation
  - Distance in meters
  - Directional arrow relative to player facing

**Behavior:**
- Always visible at top center
- Waypoints appear contextually when navigation targets are set
- Directional arrows update as player rotates
- Multiple waypoints can be displayed simultaneously

### Objective & Mission System

**DEFCON Status (Always Visible):**
- Large number display (1-5) with threat level name
- Color coding through text (gold/amber tones)
- Reduces opacity to 50% when higher priorities are active
- Never completely hidden—maintains baseline threat awareness

**Current Objective (Medium Priority):**
- Amber left-border panel with transparent background
- Header "CURRENT OBJECTIVE"
- Primary objective text and secondary details
- Displays alongside DEFCON (doesn't replace it)

**Priority Orders (Highest Priority):**
- Red left-border panel with increased opacity
- Header "PRIORITY TRANSMISSION"
- Order text with issuer information (ship/command designation)
- Displays alongside objective and DEFCON
- Most prominent due to border color and opacity

---

## Technical Implementation Notes

### Visibility State Management

- Elements fade gracefully rather than instantly appearing/disappearing
- Weapon panel: Hidden when hasWeapon = false
- Squad panel: Hidden when inSquad = false
- Comms panel: Visible when hasRadio = true (shows "no channels" state if disconnected)
- Comms transmission panel: Only visible during active voice transmission
- Overheat bar: Always visible when weapon is equipped (shows 0% when cool)

### Transparency & Readability

- Background opacity ranges from 50% to 70% depending on element importance
- All text has subtle black shadow for readability against any background
- Borders are minimal (4px left borders) for categorization without obstruction
- No solid panels—everything is see-through

### Color Palette Specifications

| Element | Color | Usage |
|---------|-------|-------|
| Amber/Gold | #DAA520, #B8860B | Imperial data, objectives, compass, healthy vitals |
| Cyan | #4A9EFF | Communications, connections |
| Green | #7FFF7F | (Reserved for secondary healthy status) |
| Yellow | #FFD91A, #FFD700 | Caution (30-60% health, overheat warning) |
| Red | #FF2D2D, #DC143C | Danger (<30% health, critical warnings, priority orders) |

### Typography Standards

- **Primary Font (Headers):** Georgia/Times New Roman (serif) for Imperial formality
- **Technical Font (Data):** Courier New (monospace) for military readouts
- **Large Numbers:** Used for critical information (ammo count, compass bearing, health percentage)
- **Text Shadows:** All text has `text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.8)` for readability
- **Hierarchy:** Size and weight indicate importance (large bold for primary data, small for metadata)

### Border System for Information Categorization

Rather than using heavy panel backgrounds, elements use colored left borders (4px) to indicate type:

- **Red left border:** Priority/danger
- **Amber left border:** Objectives
- **Cyan left border:** Communications
- **Green left border:** Squad/team
- **Gray left border:** DEFCON (baseline)

This provides visual categorization without blocking the gameplay view.

---

## Differences from Menu UI

It's important to distinguish between **Menu UI** (shown in terminal screens, personnel databases, enlistment menus) and **HUD** (shown during gameplay):

### Menu UI Characteristics:
- Solid gold header bars (`background: linear-gradient(180deg, #B8860B 0%, #8B6914 100%)`)
- Opaque black backgrounds (80-95%)
- Heavy borders and structured panels
- Full screen overlays that block gameplay
- Used for: character selection, terminal access, admin menus, inventory screens

### HUD Characteristics:
- Transparent backgrounds (40-70% opacity)
- Minimal borders (4px colored left borders only)
- Text-focused with data floating above gameplay
- Never blocks the game world
- Used for: real-time gameplay information, combat data, navigation

---

## Design Process & Methodology

### Iterative Development Approach

The HUD was developed through rapid prototyping using React components, allowing for real-time visualization and immediate feedback on layout decisions. This iterative process involved:

1. **Initial Layout Planning:** Defining screen regions and preventing overlap conflicts through careful positioning

2. **Priority System Development:** Establishing clear hierarchy rules for competing information displays, with DEFCON always remaining visible

3. **Transparency Optimization:** Transitioning from solid panels (menu UI) to transparent overlays (HUD) to maintain gameplay visibility

4. **Contextual Behavior Refinement:** Implementing show/hide logic to reduce clutter while ensuring critical systems remain accessible

5. **Communications System Redesign:** Separating persistent channel connections from dynamic transmission displays

6. **Visual Polish:** Color-coding, minimal borders, and readability optimization through text shadows

### Design Challenges & Solutions

**Challenge:** Overlapping elements in left-side layout  
**Solution:** Repositioned squad panel to left-mid (top: 33%) to create clear vertical separation between objective/DEFCON (top), squad (middle), and vitals (bottom).

**Challenge:** Managing three-tier priority system (Priority Order > Objective > DEFCON) without hiding baseline threat info  
**Solution:** Implemented visual priority through border colors and opacity changes rather than replacement—DEFCON remains visible at all times, just fades to 50% opacity when higher priorities are active.

**Challenge:** Heavy UI panels blocking gameplay view  
**Solution:** Transitioned to transparent backgrounds (40-70% opacity) and minimal 4px left borders instead of full panel backgrounds, making all HUD elements see-through.

**Challenge:** Radio communication unclear about connection status vs. active transmission  
**Solution:** Split into two panels—persistent "Connected Channels" (always visible) and dynamic "Active Transmission" (appears during voice), with clear connection counter (1/2, 2/2) and channel limit.

**Challenge:** Players unable to access radio channels when not connected  
**Solution:** Show "No active channels // Click to connect" prompt when disconnected, ensuring menu access is always available when radio equipment is present.

**Challenge:** Comms menu disappearing inappropriately  
**Solution:** Menu availability tied to hasRadio (equipment) rather than connectedChannels (connections), with clear visual states for all scenarios.

---

## Conclusion

This HUD design balances the competing demands of roleplay immersion, tactical information delivery, and gameplay clarity. By prioritizing diegetic presentation through transparent panels, contextual visibility, and clear information hierarchy, the interface serves as both a functional gameplay tool and an atmospheric element that reinforces the Imperial military setting without obstructing the game world.

The modular, priority-based architecture allows for future expansion while maintaining the core principle of minimal, purposeful design. The distinction between opaque menu UI (terminals, databases) and transparent gameplay HUD ensures players can always see the action while receiving critical tactical information.

The system demonstrates that effective HUD design for roleplay environments requires restraint: what you choose not to show is as important as what you display. Every element must justify its presence through gameplay necessity and thematic consistency. Most critically, HUD elements must remain transparent—they float above the game world rather than blocking it, maintaining the player's connection to the immersive environment.

---

## Appendix: Key Implementation Details

### React State Variables

```javascript
// Core gameplay stats
health, stamina, ammo, ammoReserve, overheat

// Weapon systems
hasWeapon, fireMode, isReloading

// Navigation
compass (0-359 degrees)

// Mission systems
defcon (1-5), hasObjective, hasPriorityOrder

// Squad systems
inSquad, squadMembers (array with health, status, distance, bearing)

// Communications (NEW SYSTEM)
hasRadio (equipment availability)
connectedChannels (array of channel names, max 2)
activeTransmission (object: speaker, channel, encrypted, freq)
commsMenuOpen (boolean)

// UI state
lastDamageDirection (top/right/bottom/left for damage indicator)
```

### Communications System Logic

**Channel Connection:**
- Click channel in menu to connect/disconnect
- If at 2-channel limit, connecting new channel replaces oldest
- Connection status persists across sessions (tied to hasRadio)

**Transmission Display:**
- Appears when voice activity detected on any connected channel
- Shows speaker info, which channel they're using
- Automatically highlights that channel in persistent display
- Disappears when transmission ends

**Menu Access:**
- Always accessible when hasRadio = true
- Shows "no channels" prompt if connectedChannels.length = 0
- Expands/collapses on click
- Can manage channels without active voice communication

### Directional Bearing Calculation

```javascript
const getBearingIndicator = (bearing) => {
  const diff = ((bearing - compass + 180 + 360) % 360) - 180;
  // Returns: ↑↗→↘↓↙←↖ based on relative bearing
}
```

Used for:
- Squad member locations relative to player
- Waypoint directions relative to player facing
- Threat locations relative to player

---

**Document Version:** 2.0  
**Last Updated:** February 16, 2026  
**Author:** Imperial HUD Development Team
