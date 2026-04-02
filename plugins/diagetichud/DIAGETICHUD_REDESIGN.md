# DiageticHUD — VANIR Redesign Specification

**Author:** Design Review  
**Version:** 3.0  
**Supersedes:** Imperial_HUD_Design_Specification_v2.md

---

## Executive Summary

The current HUD (v2) violates several VANIR principles: it boxes every section in opaque full-border panels, uses ten typefaces simultaneously, applies full-saturation multi-color borders for categorisation, and pulses UI elements at 4 Hz — far exceeding the "fast and understated" interaction guideline. This document redesigns each panel to share the visual grammar of the `impmainmenu` "You" tab, treating the HUD as the in-field read-out counterpart to that character overview screen.

---

## 1. Design Violations in v2 (Reference)

| Issue | Location | VANIR Rule Violated |
|---|---|---|
| Full opaque border boxes for every panel | All `DrawPanel()` calls | §1 "Structural Implication over Explicit Bounding" |
| 10 distinct typefaces (OCR-A, Times New Roman, Roboto, Roboto Condensed, Orbitron, …) | `CreateFonts()` | §3 "Primary System Typeface (Orbitron)" |
| Independent `THEME` table, not `ix.ui.THEME` | Top of `cl_plugin.lua` | Breaks design token consistency across Vanir |
| `DrawOutlinedRect` fire mode box | `DrawWeapon()` ~L1401 | §1 "Avoid full-frame bounding boxes" |
| 4 Hz sin pulse on transmission border | `DrawComms()` ~L922 | §5 "Do not rely on slow, drawn-out … hyper-complex geometry transitions" |
| Full-saturation cyan / green / red borders simultaneously visible | All panels | §2 "single muted accent color used sparingly" |
| Aurebesh scattered inconsistently, not adjacent to title bars | Multiple panels | §4 "Embed into structural corners or adjacent to high-contrast title bars" |
| No corner-notch anchors | All panels | §1 "Use minimalistic corner pieces … to establish boundary" |

---

## 2. Shared Token Alignment

Replace the local `THEME` table with references to `ix.ui.THEME`. Map current custom keys as follows:

| v2 Key | v3 Source | Notes |
|---|---|---|
| `THEME.amber` / `THEME.gold` | `ix.ui.THEME.accent` | Imperial Gold is the single accent |
| `THEME.text` | `ix.ui.THEME.text` | Full-brightness white |
| `THEME.textMuted` | `ix.ui.THEME.textMuted` | Alpha-shifted grey for secondary labels |
| `THEME.background` | `ix.ui.THEME.background` | Dark desaturated base |
| `THEME.cyan` | Local `HUD_COMMS_COLOR = Color(84, 168, 255, 200)` | One-off for comms only; never border-full-saturation |
| `THEME.green` | Local `HUD_SQUAD_COLOR = Color(70, 185, 100, 180)` | One-off for squad; use at reduced opacity |
| `THEME.red` | Local `HUD_DANGER_COLOR = Color(215, 40, 40, 220)` | One-off for danger states |

> **Rationale:** ImpMainMenu's `cl_unified_panel.lua` (the "You" tab) references `ix.ui.THEME.accent` for the gold character-name bar and separator lines. The HUD should read the same token so a server-level theme change propagates everywhere.

---

## 3. Typography Consolidation

Reduce to three typefaces matching ImpMainMenu exactly:

| Font Name | Typeface | Size | Weight | Role |
|---|---|---|---|---|
| `ixHUDTitle` | Orbitron | Scale(20) | 700 | Section title bar text, character name wordmark |
| `ixHUDData` | Orbitron | Scale(11) | 500 | Technical readouts, compass bearing, ammo, DEFCON number |
| `ixHUDDataLarge` | Orbitron | Scale(32) | 700 | Large bearing number, large ammo clip count |
| `ixHUDLabel` | Roboto | Scale(10) | 400 | Secondary descriptive labels, member names, objective text |
| `ixHUDAurebesh` | Aurebesh | Scale(8) | 400 | Diegetic metadata only — corner embeds |

**Removed:** Times New Roman (`ixHUDSerif`, `ixHUDSerifLarge`), OCR-A (`ixHUDMonoHuge`, `ixHUDBearing`, `ixHUDName`, `ixHUDRank`), Roboto Condensed (`ixHUDMonoLarge`). These were creating tonal inconsistency with ImpMainMenu, which uses Orbitron/Roboto exclusively.

---

## 4. Structural Primitives (Replacing `DrawPanel`)

### 4a. Title Bar Strip
Mirrors the "OPERATIVE STATUS" header in the "You" tab (`cl_unified_panel.lua` L91–96).

```
┌────────────────────────────────────────────┐  ← height: Scale(16)
│ SECTION LABEL       [Aurebesh metadata]    │  ← gold bg, black text, Aurebesh right-aligned
└────────────────────────────────────────────┘
```

- Background: `THEME.accent` at alpha 210 (matches "You" tab)
- Text: `Color(0, 0, 0, 255)` on `ixHUDTitle` (inverted — black on gold)
- Aurebesh: right-aligned, `Color(0, 0, 0, 140)` — same pattern as `cl_unified_panel.lua` L96
- Height: `Scale(16)` — thin, authoritative
- **No outer border**

### 4b. Corner Notch Anchor
Two 2px × Scale(10) strokes at each active corner (top-left cross, bottom-right cross). Color: `THEME.accent` at alpha 90.

```lua
-- top-left notch
surface.SetDrawColor(accent.r, accent.g, accent.b, 90)
surface.DrawRect(x, y, Scale(10), Scale(2))          -- horizontal
surface.DrawRect(x, y, Scale(2), Scale(10))          -- vertical
-- bottom-right notch (mirrored)
surface.DrawRect(x + w - Scale(10), y + h, Scale(10), Scale(2))
surface.DrawRect(x + w, y + h - Scale(10), Scale(2), Scale(10))
```

Applied to: Vitals (bottom-left), Weapon (bottom-right), Compass (top-center extent).  
**Not** applied to Mission or Comms panels — those use a single shared left-edge separator line to imply grouping.

### 4c. Implied Row Separator
Single 1px horizontal line at alpha 30 of `THEME.accent`. Used between data rows within a panel (squad members, channel list). Replaces any per-row background fills.

### 4d. Left-Edge Accent Bar (Severity States Only)
A 2px vertical bar flush-left, used exclusively for active alerts (Priority Transmission = danger-red, Active Comms Transmission = comms-blue). **Not** a full panel border — it extends only the height of the active content row, not the full panel.

---

## 5. Panel-by-Panel Redesign

---

### 5a. Compass & Navigation (Top Center)

**Current problems:** Backdrop box commented out but orphaned code remains; waypoints are plain comma-separated text lines.

**v3 Layout:**
```
         [navigat]            ← Aurebesh, alpha 55, centered above
    ┌──────────────────────┐  ← 2px corner notches, accent@90
    │   BRG    035°        │
    │   N   E   S   W      │  (active cardinal highlighted in full accent)
    └──────────────────────┘
    TGT: CHECKPOINT-7  //  420M  ↗
    THR: HOSTILE-ALPHA  //  180M  ↓
```

**Changes:**
- Remove commented-out `RNDX.Draw` backdrop entirely. Replace with pure corner notches.
- Bearing string font: `ixHUDDataLarge` (Orbitron 32, was OCR-A 36).
- "BRG" label: `ixHUDLabel` (Roboto 10, was Orbitron 11) — demoted to secondary.
- Cardinals: `ixHUDData` (Orbitron 11). Active cardinal: `THEME.accent`. Inactive: `THEME.textMuted`.
- Waypoints: prefix (`TGT:` / `THR:`) in `THEME.textMuted` Roboto; label + distance in Orbitron `ixHUDData`. Threat waypoints use `HUD_DANGER_COLOR` only for label text — no separate background.
- Aurebesh "navigat" stays, moved to sit directly above the compass extent, centered.

**Design token reference:** Cardinal active state matches the "You" tab's active tab indicator — accent color, same font weight.

---

### 5b. Mission Status (Top Left)

**Current problems:** Three separate opaque bordered boxes stacked vertically. DEFCON uses `ixHUDSerifLarge` (Orbitron 38 — too large for a supplemental panel). Priority border pulses at 4 Hz.

**v3 Layout:**
```
╔════════════════════════════════╗  ← Gold Title Bar (accent bg / black text)
║ PRIORITY TRANSMISSION  [trans] ║  (only present when active)
╠════════════════════════════════╣
║  SECURE HANGAR BAY 3           ║  → Orbitron data
║  Hostile infiltration          ║  → Roboto label, textMuted
║  ISS VENGEANCE // CMDR TARKIN  ║  → Roboto label, textDark
╠════════════════════════════════╣  ← 1px separator (accent@30)
║ CURRENT OBJECTIVE  [mission]   ║  (title bar — amber@210 / black text)
╠════════════════════════════════╣
║  Patrol Sector 7-G             ║
║  Report anomalies to command   ║
╠════════════════════════════════╣
║ DEFSTAT  2  ELEVATED           ║  → Always visible, no separate box
║  Increased threat posture      ║
╚════════════════════════════════╝
```

Wait — this layout describes boxes. Let me re-think with the open layout. The key insight from VANIR is: use title bars as grouping anchors, not containers.

**Correct v3 Layout (open/breathable):**
```
PRIORITY TRANSMISSION  [trans]   ← gold title bar strip, full panel width
  SECURE HANGAR BAY 3            ← Orbitron, text (white)
  Hostile infiltration           ← Roboto, textMuted
  ISS VENGEANCE // CMDR TARKIN   ← Roboto, textDark
                                 ← 1px accent@30 separator
CURRENT OBJECTIVE  [mission]     ← gold title bar strip
  Patrol Sector 7-G              ← Orbitron, text
  Report anomalies               ← Roboto, textMuted
                                 ← 1px accent@30 separator
DEFSTAT  2 — ELEVATED            ← Plain Orbitron label row (no title bar — lower hierarchy)
  Increased threat posture       ← Roboto, textMuted, reduced alpha when other panels active
```

**Changes:**
- All three sections share a single left-anchor position with no outer bounding rectangle.
- Priority and Objective each get a gold title bar strip (16px tall).
- DEFCON does **not** get a title bar — it is the lowest-priority item and uses a plain Orbitron label row to reflect its subordinate status (as per "title bars used sparingly to preserve impact").
- DEFCON large number (`ixHUDDataLarge`, Orbitron 32) removed. DEFCON level shown inline: `DEFSTAT  2 — ELEVATED` in `ixHUDData`. Reduces visual noise when priority/objective are active.
- Priority panel: pulsing 2px left-edge accent bar replaces the full-border pulse. Pulse at 1.5 Hz (matches "You" tab Aurebesh pulse frequency — `CurTime() * 1.5`), not 4 Hz.
- Panel width: `Scale(270)` (slightly narrower than current 280 — aligns to grid).
- No background draw. The game world reads through.

**Design token reference:** Title bar pattern is identical to the "OPERATIVE STATUS" and "FIELD INVENTORY" bars in `cl_unified_panel.lua` L91–96.

---

### 5c. Communications (Top Right)

**Current problems:** Pulsing cyan border at 4 Hz. Portrait placeholder adds visual weight without function. Full-box background obscures world view.

**v3 Layout (active transmission):**
```
COMMS NETWORK  [comlink]         ← gold title bar strip, full panel width
  ──  2px left-edge bar (comms-blue@200)
  OFFICER TARKIN                 ← Orbitron, text
  COMMAND NET  ·  8858.0 MHZ     ← Roboto, comms-blue@160
  ENCRYPTED                      ← Roboto, textMuted
                                 ← 1px separator
  SQUAD COMMS  ·  4521.5 MHZ     ← connected channel row
  ENC                            ← right-aligned, comms-blue@120
```

**Changes:**
- Remove portrait placeholder entirely. The speaker name in Orbitron carries identity hierarchy — a blank square box adds nothing diegetically.
- Remove full-panel background. Text reads via `DrawShadowText` double-shadow — sufficient for readability.
- Active transmission: 2px left-edge vertical bar in `HUD_COMMS_COLOR` (non-pulsing). The Aurebesh `comlink` in the title bar shifts from `Color(0,0,0,140)` to `Color(0,0,0,220)` as the only visual "pulse" — subtle, low-frequency (1.5 Hz absolute sine, not sine * 4).
- Channel rows: implied separator between entries only. No per-row backgrounds.
- "ENC" indicator: right-aligned Roboto label in comms-blue at 60% opacity — demoted from current 80%.
- Inactive state (no channels): Show only "COMMS NETWORK" title bar + single Roboto line "NO ACTIVE CHANNELS" in `textMuted`. Preserves minimal footprint.

**Design token reference:** Channel row layout mirrors the "PERSONNEL DETAILS" data rows in `cl_unified_panel.lua` (`ix.ui.CreateDataRow`) — label left, value right, 1px separator between rows.

---

### 5d. Squad / Fireteam (Left Mid)

**Current problems:** Green full-border panel. Rank badge placeholder (dark rounded square) adds visual clutter. Bearing arrows are small unicode characters in a dense font.

**v3 Layout:**
```
FIRETEAM AUREK  [squad]          ← gold title bar strip
  SGT MORRISON                   ← Orbitron, text
  ▌ [health bar, 5px tall]       ACTIVE   ←  status right-aligned, Orbitron@accent
  420M  ↗                        ← Roboto, textMuted
                                 ← 1px separator
  CPL VANCE                      ← Orbitron, text
  ▌ [health bar, WOUNDED red]    WOUNDED
  88M  ↑                         ← bearing arrow in textMuted
```

**Changes:**
- Remove rank badge square placeholder. Replace with a `Scale(3)` wide vertical pip using `GetBarColor(healthFrac)` to encode member status at a glance — same color as their health bar. This is information-dense without visual noise.
- `squadData.designation` text font: `ixHUDTitle` in the gold title bar (black on gold), Aurebesh suffix `squad` at right-aligned `Color(0,0,0,140)`.
- Member names: `ixHUDData` (Orbitron 11).
- Health bars: 4px height (current 4px — keep). Width tightened to `panelW - Scale(60)` to give breathing room for status text.
- Status text (ACTIVE/INJURED/WOUNDED/KIA): `ixHUDLabel` (Roboto 10), right-aligned. Color: accent for ACTIVE, `HUD_DANGER_COLOR` for WOUNDED/KIA, textMuted for INJURED.
- Distance/bearing: `ixHUDLabel` Roboto, `textMuted`. Bearing arrow: Unicode character in same font (not a separate font size).
- No outer bounding box. A 2px accent@40 left separator line on the leftmost edge of the panel implies the group.
- Panel width reduced to `Scale(200)` to respect negative space.

---

### 5e. Player Vitals (Bottom Left)

**Current problems:** Full amber-border box. Character name in OCR-A. Rank line in OCR-A. Two commented-out Aurebesh decorations (dead code).

**v3 Layout:**
```
  OPERATOR NAME HERE               ← ixHUDDataLarge (Orbitron 32), THEME.text
  ╔══════════════════════════════╗  ← Scale(14)h gold bar strip
  ║ STORMTROOPER  ·  501ST LEGION║  ← ixHUDTitle (black on gold), Aurebesh right @ black@140
  ╚══════════════════════════════╝
                                   ← Scale(10) gap
  VITALS  84%                      ← "VITALS" Roboto textDark / pct Orbitron accent
  ▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌▌              ← health bar
  STAMINA  72%                     ← same pattern
  ▌▌▌▌▌▌▌▌▌▌▌▌▌                  ← stamina bar, accent dim color

  WARNING: MEDICAL ATTENTION REQUIRED  ← only <30%, Roboto, danger-red, 1.5 Hz pulse
```

Corner notches at top-left and bottom-left of the vitals group extent.

**Changes:**
- Character name: `ixHUDDataLarge` (Orbitron 32) directly above the gold faction bar — exact mirror of the "You" tab character name wordmark above the gold faction/class bar (`cl_unified_panel.lua` L60, L70).
- Faction/class gold bar: identical construction to `cl_unified_panel.lua` L65–72 — `THEME.accent` background, black Orbitron text centered, Aurebesh right at `Color(0,0,0,140)`.
- Remove OCR-A fonts entirely for this section.
- Remove `ixHUDName` and `ixHUDRank` font registrations.
- "VITALS" / "STAMINA" label: `ixHUDLabel` (Roboto 10, `textDark`).
- Percentage inline: `ixHUDData` (Orbitron 11, accent color for health / `textMuted` for stamina).
- Bars: 6px height (increase from 8px/5px disparity — unify both to 6px).
- Critical warning: pulse at 1.5 Hz (down from 4 Hz). Font: `ixHUDLabel` Roboto.
- Remove `DrawPanel` call entirely. No background rectangle.
- Remove commented-out Aurebesh lines (dead code cleanup).

**Design token reference:** The character name + gold-bar-subtitle pattern directly replicates the "You" tab header — establishing visual kinship between in-field HUD and character overview screen.

---

### 5f. Weapon & Ammunition (Bottom Right)

**Current problems:** Fire mode uses `DrawOutlinedRect` — explicit VANIR §1 violation. `ixHUDMonoHuge` (OCR-A 44) for ammo is visually disconnected from Orbitron vocabulary.

**v3 Layout:**
```
                     E-11 BLASTER RIFLE   ← Orbitron 11, textDark
                          [weapon sys]   ← Aurebesh, textDark@40, right-align
                                         ← 1px accent@20 separator
                                  SEMI   ← Orbitron 11, textMuted (no box)
                                         ← Scale(6) gap
                               28 / 120  ← Orbitron — "28" in ixHUDDataLarge (32),
                                            "/" in Orbitron 11 textDark, "120" Orbitron 11 textMuted
                                         ← Scale(8) gap
                         HEAT  ████░░░   ← label Roboto, bar 5px, warning inline
               WARNING: COOLING REQUIRED ← Roboto, danger-red, 1.5 Hz pulse
```

Corner notches at bottom-right of weapon group extent.

**Changes:**
- Fire mode: Remove `DrawOutlinedRect`. Replace with a thin 1px `accent@20` separator line above the fire mode text. Fire mode text in `ixHUDData` (Orbitron 11), `textMuted`. The separator implies the data category without encasing it.
- Ammo clip: `ixHUDDataLarge` (Orbitron 32) replaces OCR-A 44. Preserves visual weight while using the system typeface.
- Reserve and "/" separator: `ixHUDData` (Orbitron 11) at different alphas (textDark for "/" , textMuted for reserve) — matches the right-column data row pattern in the "You" tab.
- Weapon name: `ixHUDData` (Orbitron 11), `textDark` — secondary status, not emphasized.
- Aurebesh "weapon sys" stays, right-aligned, `textDark@40`.
- Heat bar: identical construction to stamina bar in §5e (6px, same `DrawBar` helper).
- Overheat warning pulse: 1.5 Hz.
- Panel width: `Scale(220)` (no change — adequate breathing room from right edge).
- No background rectangle. Corner notches establish spatial anchor.

---

## 6. Screen-Wide Changes

### 6a. Damage Direction Indicator
No change to logic. Gradient color updates to use `HUD_DANGER_COLOR` (mapped from `THEME.red`). Duration 0.3s unchanged — already "fast and understated."

### 6b. Critical Health Border
Keep the pulsing border concept. Update to use `HUD_DANGER_COLOR` at `alpha 60` max (down from 80) — less intrusive. Pulse frequency: 1.5 Hz (down from 3 Hz).

### 6c. Vignette
No change — already subtle (0–40% alpha at screen corners only). Keep.

### 6d. Global Background Strategy
No panel-level `surface.DrawRect` background fills. All readability comes from `DrawShadowText`'s double-layer shadow. This is the primary mechanism ImpMainMenu uses for text-over-world rendering.

> **Exception:** The health bar and stamina bar retain a minimal dark background via `DrawBar`'s existing `barBgColor` at alpha 100 (reduced from 185) — enough to anchor the bar visually.

---

## 7. Interaction & State Variants

### 7a. Normal / Idle State
- Compass, Vitals, Weapon always visible.
- Mission block shows only DEFCON status row (no title bar — lowest hierarchy level).
- Comms block shows only title bar + "NO ACTIVE CHANNELS" line.
- Squad block hidden (not in squad).

### 7b. Elevated State (Objective active)
- Mission block: DEFCON row remains. "CURRENT OBJECTIVE" title bar appears above it.
- DEFCON row text alpha reduced to 60% (matches v2 behavior, now expressed as `THEME.textMuted` rather than a hardcoded alpha multiplication).

### 7c. Alert State (Priority Transmission active)
- Mission block: "PRIORITY TRANSMISSION" title bar at top.
- 2px left-edge vertical bar in `HUD_DANGER_COLOR` alongside the priority content rows (not the title bar — the title bar's gold already communicates authority; the red edge bar communicates urgency specifically for the content below it).
- DEFCON row alpha reduced to 40%.

### 7d. Comms Active Transmission
- "COMMS NETWORK" title bar's Aurebesh shifts from `Color(0,0,0,140)` to `Color(0,0,0,220)` (slight brightening — "fast and understated").
- 2px left-edge vertical bar in `HUD_COMMS_COLOR` alongside speaker/channel rows.
- Pulse: 1.5 Hz sine on the left-edge bar alpha only (±30 units around base 180).

### 7e. Critical Health (<20%)
- Pulsing border effect (§6b) activates.
- Vitals bar and percentage shift to `HUD_DANGER_COLOR`.
- "WARNING: MEDICAL ATTENTION REQUIRED" row appears below bars (Roboto 10, 1.5 Hz pulse).
- No other panels change state — only vitals block responds.

### 7f. Weapon Overheat (≥80%)
- Heat bar shifts to `HUD_DANGER_COLOR`.
- "WARNING: COOLING REQUIRED" text appears (Roboto 10, 1.5 Hz pulse, right-aligned).
- No other panels change state.

---

## 8. Annotated Design Decision Log

| Decision | Rationale |
|---|---|
| **Character name above gold faction bar in Vitals** | Direct mirror of "You" tab wordmark pattern. When the player opens the menu, they see their name in the same typographic treatment as the HUD — HUD feels like a live feed of the character screen. |
| **Gold title bars for all major sections** | VANIR §2: "For major section titles, use thin horizontal strips with an inverted color scheme." Replacing left-border boxes with title bars eliminates the need for per-panel backgrounds entirely. |
| **DEFCON gets no title bar** | VANIR: title bars "used sparingly to preserve impact." DEFCON is always-visible baseline context — not a major section announcement. A plain Orbitron row with textMuted colour communicates its subordinate role. |
| **1.5 Hz pulse frequency throughout** | Matches `cl_unified_panel.lua` L95 (`CurTime() * 1.5`) — the "You" tab's Aurebesh pulse. All animated elements across HUD and menu now breathe at the same rate, reinforcing system coherence. |
| **Remove portrait placeholder in comms** | A blank rounded square with "id" in Aurebesh adds no diegetic information and violates §1 by introducing visual noise. Speaker identity is fully conveyed by the Orbitron name in the content row. |
| **Unify bar height to 6px** | Current disparity (8px health, 5px stamina, 4px squad) creates visual inconsistency. 6px is legible at all resolutions and matches the thin-bar philosophy. |
| **Remove OCR-A entirely** | OCR-A was used for large ammo count (44px), compass bearing (36px), player name (22px) and rank (14px) — four distinct roles with four distinct sizes. Replacing all with Orbitron brings the HUD into the same typographic family as the menu, at the cost of zero functionality. |
| **DrawShadowText as primary readability mechanism** | VANIR implies no panel backgrounds by design ("allow the interface to recede into the background"). The double-shadow ensures text legibility against any map background without drawing opaque rectangles over the game world. |
| **2px corner notches instead of panel borders** | §1: "Use minimalistic corner pieces … to establish the boundary of the UI. This tricks the eye into interpreting massive negative space intentionally rather than as an empty void." Corner notches establish spatial ownership for Vitals, Weapon, and Compass without enclosing them. |

---

## 9. Font Registration Delta (v2 → v3)

### Remove
- `ixHUDSerif` (Times New Roman 14)
- `ixHUDSerifLarge` (Orbitron 38 — superseded by `ixHUDDataLarge`)
- `ixHUDMono` (Orbitron 11 — rename to `ixHUDData`)
- `ixHUDMonoSmall` (Roboto 10 — rename to `ixHUDLabel`)
- `ixHUDMonoLarge` (Roboto Condensed 22 — remove)
- `ixHUDMonoHuge` (OCR-A 44 — superseded by `ixHUDDataLarge`)
- `ixHUDBearing` (OCR-A 36 — superseded by `ixHUDDataLarge`)
- `ixHUDLabelSmall` (Roboto 10 — merge into `ixHUDLabel`)
- `ixHUDAurebesh` (Aurebesh 10 — superseded by `ixHUDAurebeshSmall` at Scale(8))
- `ixHUDName` (OCR-A 22 — superseded by `ixHUDDataLarge`)
- `ixHUDRank` (OCR-A 14 — superseded by `ixHUDTitle` in gold bar)

### Keep / Rename
| v2 Name | v3 Name | Change |
|---|---|---|
| `ixHUDMono` | `ixHUDData` | Rename only (Orbitron 11, weight 500) |
| `ixHUDMonoSmall` | `ixHUDLabel` | Rename + remove Roboto Condensed references |
| `ixHUDAurebeshSmall` | `ixHUDAurebesh` | Rename (Scale(8) — single Aurebesh font) |

### Add
| v3 Name | Typeface | Size | Weight | ImpMainMenu Equivalent |
|---|---|---|---|---|
| `ixHUDTitle` | Orbitron | Scale(11) | 700 | `ixImpMenuDiag` |
| `ixHUDDataLarge` | Orbitron | Scale(32) | 700 | `ixImpMenuTitle` (scaled down for HUD) |

---

## 10. Implementation Order

1. **Token alignment** — Replace local `THEME` table with `ix.ui.THEME` references + local color constants for comms/squad/danger.
2. **Font registration** — Apply §9 delta.
3. **Shared primitives** — Write `DrawTitleBar(x, y, w, label, aurebeshSuffix)` and `DrawCornerNotch(x, y, w, h)` helpers.
4. **Vitals** — Highest visual kinship change with "You" tab; do this first to validate the character name / gold bar pattern.
5. **Mission Status** — Title bar replacement for priority/objective; DEFCON plain row.
6. **Compass** — Remove backdrop orphan code; update fonts; add corner notches.
7. **Comms** — Title bar, remove portrait, update pulse frequency.
8. **Squad** — Title bar, remove rank badge box, pip indicator.
9. **Weapon** — Remove fire mode box, update ammo fonts, add corner notches.
10. **Global** — Update pulse frequencies throughout (search `CurTime() * [34]` and replace with `CurTime() * 1.5`).

---

*This specification aligns the DiageticHUD with VANIR v1 and the ImpMainMenu unified panel redesign. All visual grammar decisions reference specific patterns from `cl_unified_panel.lua` and `VANIR_UI_DESIGN_SYSTEM.md`.*
