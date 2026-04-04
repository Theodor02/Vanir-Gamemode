# USMS Full Audit — Unit & Squad Management System
**Audit Date:** 2026-04-03  
**Auditor:** Claude Sonnet 4.6  
**Codebase:** `gamemodes/skeleton/plugins/usms/`  
**Total files read:** 23 (all .lua + reference .md)  
**Approximate total LOC:** ~7,200 across all files  

---

## 1. Executive Summary

### Honest Verdict

USMS is a technically capable but unfocused plugin that has grown to solve too many problems, none of them fully. The core loop it executes correctly — unit membership, squad formation, class assignment, gear-up — is buried under four semi-finished secondary systems (missions, commendations, cross-faction intel, resource production) that add UI real estate and maintenance overhead while providing little tangible gameplay value.

The server owner's complaint is accurate. The clunkiness is not primarily a bug problem — individual components work. The problem is **architectural scatter**: the plugin's surface area has expanded well beyond what its core identity warrants, and what remains feels like a collection of loosely related features rather than a cohesive tool.

### What It Gets Right

- **The roster table** (`cl_unit_roster.lua`) is well-built: sortable, filterable, tooltip-on-hover, rich right-click context menu. It sets the right standard for how a military management UI should work.
- **The request handler pattern** (`sv_usms.lua` lines 1288–1304) is clean and extensible. A single net message routes all client→server operations through a keyed dispatch table.
- **Character variable integration** (`meta/sh_character.lua`) is clean Helix practice. The CharVar auto-persistence means unit state survives restarts correctly.
- **The invite popup** (`cl_invite_popup.lua`) is the most polished individual component — animated, timed, properly cleaned up.
- **Log system** is thorough: categorised actions, filterable by type and time range, paginated, clipboard-exportable.
- **Permission architecture** is consistent: the `IsSuperAdmin()` bypass pattern is applied uniformly across all 25+ request handlers.

### The Core Identity Problem

USMS cannot decide what it is. Its description reads: "Persistent military unit and squad organization system with loadouts and resources." That is accurate, but the plugin also ships with a mission tracker, a commendation/awards system, a cross-faction intelligence panel, and a full service record system.

**The plugin should be:** A personnel management and readiness system. Its job is to track who belongs where, what class they hold, whether they have their gear, and who leads what squad. Everything else is scope creep.

The mission tracker is a text-based to-do list. The commendation system is a cosmetic record with no gameplay effects. The intel system shows two numbers to people who have a `canViewAllRosters` faction flag that isn't even defined in this plugin. These systems exist because they were built, not because they were needed.

---

## 2. Feature Inventory & Cohesion Audit

| Feature | Complete? | Pulls Weight? | Conflict/Duplication | Verdict |
|---|---|---|---|---|
| Unit membership (add/remove/role) | ✅ Yes | ✅ Yes | None | **KEEP** |
| Faction-based auto-assignment | ✅ Yes | ✅ Yes | None | **KEEP** |
| Roster table (view, sort, filter) | ✅ Yes | ✅ Yes | None | **KEEP** |
| Squad creation/management | ✅ Yes | ✅ Yes | None | **KEEP** |
| HUD integration (diegetic HUD) | ✅ Yes (gated) | ✅ Yes | Clean separation | **KEEP** |
| Class assignment by officers | ✅ Yes | ✅ Yes | None | **KEEP** |
| Class whitelist per member | ✅ Yes | ⚠️ Partial | Buried UX | **SIMPLIFY** |
| Gear-up (resource-based loadout) | ✅ Yes | ⚠️ Partial | No resource income | **KEEP + fix income** |
| Resource pool per unit | ✅ Yes | ⚠️ Partial | Admin-only fills | **KEEP + fix income** |
| Activity logging | ✅ Yes | ✅ Yes | None | **KEEP** |
| Log viewer panel | ✅ Yes | ✅ Yes | None | **KEEP** |
| Invite system (unit + squad) | ✅ Yes | ✅ Yes | Dual invite paths | **SIMPLIFY paths** |
| Mission tracker | ✅ Yes | ❌ No | Standalone, no tie-in | **CUT or defer** |
| Commendation / service record | ✅ Yes | ⚠️ Marginal | No gameplay effect | **SIMPLIFY** |
| Cross-faction intel panel | ⚠️ Thin | ❌ No | Spammy, low-value | **CUT** |
| Equipment catalog | ⚠️ Stub | ❌ No | 3 items, rest commented | **CUT or inline** |
| Help / info tab | ✅ Yes | ❌ No | Nobody reads it in-game | **CUT as tab** |

---

## 3. UI/UX Analysis — Panel by Panel

### `cl_usms_tab.lua` — Tab Structure

**What works:**
- Clean tab bar with gold underline for active tab
- Requesting data on tab-activate (logs on "logs" tab, missions on "missions" tab, line 157–162) is a good practice
- Panel visibility toggling via `SetVisible` is correct; panels are initialized once and reused

**Problems:**
- **7 tabs is too many.** ROSTER | SQUADS | LOADOUT | MISSIONS | LOGS | INTEL | INFO. A player only ever needs ROSTER, SQUADS, and LOADOUT in active play. LOGS is admin-only. MISSIONS is niche. INTEL is nearly useless. INFO nobody reads.
- **Roster data not refreshed on tab-activate.** `Init()` sends `roster_request` once (line 49). Switching away and back to ROSTER does not re-fetch data. If roster changed while another tab was active, the view is stale.
- **Tab button widths are hardcoded at `Scale(100)` per tab** (line 124). At 7 tabs that's 700px at 1080p — fine. At 720p the tab bar is 583px, meaning buttons may clip. The buttons have no ellipsis or scroll mechanism.
- The "info" tab maps to `self.helpPanel` using tab name "info" but the help panel is essentially a static manual.

**Fix:** Reduce to 5 tabs: ROSTER, SQUADS, LOADOUT, MISSIONS, LOGS. Cut INTEL entirely. Move the help panel behind a `?` button on the tab bar or remove it.

---

### `cl_unit_overview.lua` — Left Sidebar

**What works:**
- Three sections (UNIT STATUS, SQUAD, LOADOUT) are logically ordered
- Resource bar with color coding (green/amber/red) is a solid visual indicator
- Role-based resource display: officers see exact numbers, members see vague status labels (line 248–258)
- Listens to `USMSUnitDataUpdated`, `USMSResourcesUpdated`, `USMSRosterUpdated` hooks and refreshes appropriately

**Problems:**
- **Sidebar takes 25% width across all tabs.** On the LOGS tab, showing "UNIT STATUS / SQUAD / LOADOUT" in the sidebar is irrelevant and wastes screen space.
- **LOADOUT section only shows the class name** (line 210–220). This is redundant — the LOADOUT tab shows the same information plus the full item list. The sidebar loadout section adds nothing.
- **Line 307: `local maxSize = 8` is hardcoded.** Should be `ix.config.Get("usmsSquadMaxSize", USMS_SQUAD_MAX_SIZE)`. This will silently display wrong counts if the server changes the config.
- **`RefreshSquad()` reads from `ix.usms.clientData.squads[squadID]`** (line 276) then falls back to `LocalPlayer():GetNetVar("ixSquadName", "")` (line 283). This fallback to a NetVar from the diegetic HUD introduces a dependency between USMS and the HUD that isn't declared anywhere.

**Fix:** Make the sidebar context-sensitive: hide it (or collapse it to just unit name + resource bar) when on the LOGS or INTEL tabs. Remove the LOADOUT section from the sidebar entirely. Fix the hardcoded maxSize.

---

### `cl_unit_roster.lua` — Roster Table

**What works:**
- Sortable by clicking column headers (clickable headers with visual sort indicator)
- Live search filter across name, class, squad, and role
- Tooltip-on-hover with structured data
- Right-click context menu with relevant officer actions
- Alternating row colors for readability

**Problems:**

**Left-click opens a service record popup.** This is the worst UX decision in the entire plugin. Line 582–586:
```lua
if (code == MOUSE_LEFT) then
    local recordPanel = vgui.Create("ixUSMSServiceRecord")
    if (IsValid(recordPanel)) then
        recordPanel:SetTargetCharID(self.data.charID)
    end
    return
end
```
Every officer who intuitively left-clicks a row to "select" it accidentally opens a service record popup. There is no "select row" concept in this panel, so the left click should be a no-op, and service record should be reachable via right-click → "View Service Record".

**Right-click menu has 9+ options, some with 2-level submenus.** The full menu tree for a CO:
- Set Role → (Member / XO / CO)
- Remove from Unit
- Transfer CO
- Assign Class → (all faction classes, no descriptions)
- Manage Class Whitelist → (all non-default faction classes, checkboxes)
- Invite to Squad
- Remove from Squad
- Add to Squad → (all available squads)
- Set Squad Role → (Member / Inviter / XO)

This is overwhelming. A right-click menu should have 4-5 options max.

**Column fractions are static** (line 171–178). The JOINED column (`joinedAt`) occupies 20% of width to show "2024-01-15". That's a lot of space for a rarely-needed date. NAME gets only 25%, which is often truncated.

**`OpenInvitePlayerPicker()`** (line 302) creates a DFrame using `DFrame`, not the same modal style as everything else in the system. Minor, but inconsistent.

**`OpenUnitEditDialog()`** (line 372) only allows editing name and description, not resource cap or member limits — even though the `unit_edit` request handler on the server (sv_usms.lua line 1826) supports those fields for CO/superadmin. The dialog is a subset of what's possible.

**Fix:** 
1. Move left-click to no-op; add "View Service Record" to right-click menu.
2. Trim right-click menu to 5 options: Set Role, Assign Class, Remove from Unit, Invite to Squad, View Service Record.
3. Move class whitelist management to the LOADOUT tab (where it belongs contextually).
4. Increase NAME column fraction, remove or shrink JOINED.

---

### `cl_squad_panel.lua` — Squad Management

**What works:**
- Left panel (squad cards) + right panel (detail) is the right layout for this data
- Own squad highlighted with gold border and ★ indicator
- Squad detail shows loadout breakdown (class distribution) which is genuinely useful for officers
- Member list in detail panel with role tags [SL]/[XO]/[INV]
- Right-click on squad member rows for kick/role/leader transfer

**Problems:**

**`BuildSquadData()` (line 223) re-derives squad data from the roster** for the third time in the codebase. The server built it (SendRoster), cl_plugin.lua derived `clientData.squads` from the roster (cl_plugin.lua line 68–83), and now cl_squad_panel.lua re-derives it again. Three versions of the same data, inconsistently structured.

**"CREATE SQUAD" and "LEAVE SQUAD" buttons are always visible** (lines 94–120) regardless of permissions. A regular member who isn't in a squad and can't create squads sees both buttons. CREATE will fail on the server with "Insufficient rank", and LEAVE is a no-op (not in a squad). The button should be hidden or disabled if the player lacks permission.

**Duplicate invite paths.** A squad leader can invite a member via:
1. The squad detail panel's INVITE button (`OpenSquadInvitePicker`)
2. The roster panel's right-click → "Invite to Squad"
Both send the same `squad_invite` request. Two different UIs for the same operation.

**"FORCE DISBAND" and "DISBAND" buttons both appear** in two places: the squad list right-click menu (`OpenSquadCardMenu`, line 360) AND the squad detail action bar (lines 440–479). This is genuinely redundant — the same action in two places on the same screen.

**`USMSSquadDataUpdated` hook is dead code.** Lines 187–190:
```lua
hook.Add("USMSSquadDataUpdated", self, function(s)
    s:RebuildSquadList()
    s:RebuildDetail()
end)
```
This hook is never fired anywhere in the codebase. The squad panel only ever updates via `USMSRosterUpdated`. This hook and its OnRemove counterpart should be removed.

**The squad invite picker (line 700) only shows online members.** If you want to pre-assign an offline member to a squad for when they log in, there's no mechanism. The force-add path (squad_force_add request handler) only works for online characters because it calls `GetCharacterByID` which requires the character to be loaded.

**Fix:**
1. Remove `USMSSquadDataUpdated` dead hook.
2. Gate CREATE/LEAVE buttons on client-side permission check.
3. Remove INVITE from squad detail panel; keep only the roster right-click path.
4. Remove duplicate disband button from squad detail panel (keep only card right-click).

---

### `cl_mission_panel.lua` — Mission System UI

**What works:**
- List + detail split is consistent with other panels
- Priority color coding (critical = red, etc.) is clear
- Status filter dropdown is useful

**Problems:**

**The "Create Mission" dialog uses `SetPos()` instead of `Dock()`** (lines 509–650). Every other dialog in the system uses Dock layout. This dialog sets absolute positions and sizes manually. It will not resize correctly if the frame changes size.

**The "Assign To" dropdown encoding is fragile.** Line 602–603:
```lua
assignCombo:AddChoice("Squad: " .. (squad.name or "?"), "squad_" .. squadID)
```
The value is a string "squad_123". It's parsed back via `string.sub(assignData, 7)` (line 627). If squad IDs are ever large, or if the string format changes anywhere, this fails silently. The squad ID should be stored as a number in the combo's user data.

**Completed missions are never pruned.** Unlike logs (which have a retention config), missions accumulate forever in the save file. A server running for a year will have thousands of completed missions.

**The mission system has no gameplay tie-in.** Creating a CRITICAL priority mission sends a notification to the diegetic HUD (`SetPriorityOrder`, sv_usms.lua line 2111–2115). Completing it does nothing except mark it complete. There are no resources awarded, no notification to squad members when their squad is assigned a mission, no map markers, no anything. It is a shared text document.

**Create button visibility is set in `Init()` (line 189–195) and never re-evaluated.** If an officer changes someone's role while they have the missions tab open, the create button state is stale.

**Fix:**
1. Rewrite the create dialog using Dock layout.
2. Fix squad ID encoding in assignment dropdown.
3. Add mission pruning (same config-based retention as logs).
4. Add a notification to assigned squad members when a mission targeting their squad is created.
5. Re-evaluate create button visibility in `PerformLayout` or hook `USMSRosterUpdated`.

---

### `cl_log_panel.lua` — Activity Log Viewer

**What works:**
- This is the best-implemented panel in the plugin.
- Dual filter row (action type dropdown + time range dropdown + text search) is thorough
- Expandable row detail (click to expand) revealing all log fields is excellent admin UX
- Clipboard export is a genuinely useful admin feature
- Pagination controls are correct

**Problems:**

**Log requests bypass server-side pagination.** Line 366–372:
```lua
function PANEL:RequestLogs()
    local data = {
        page = 1,
        limit = 9999
    }
    ...
    ix.usms.Request("log_request", data)
end
```
The server's `log_request` handler (sv_usms.lua line 1744) supports real pagination, but the client always requests 9999 entries. All filtering (time range, text search) is then done client-side on the full dataset. This means after 60 days of active play, the server compresses and sends potentially thousands of log entries on every LOGS tab open. Either: use real server-side pagination with server-side filtering, or accept client-side filtering and document that it works on the full dataset. Don't have both half-implemented.

**Log action labels missing `class_whitelist`** (LOG_ACTION_LABELS table, lines 29–47). The `USMS_LOG_CLASS_WHITELIST` constant is defined in `sh_usms.lua` and written to logs by the whitelist request handlers, but its label is not in `LOG_ACTION_LABELS` and it's not in `LOG_ACTION_COLORS`. It will appear as the raw constant string "class_whitelist" in the log viewer instead of a human-readable label.

**Fix:**
1. Add "class_whitelist" → "Class Whitelist Updated" to `LOG_ACTION_LABELS` and give it a color.
2. Either commit to server-side pagination (request one page, server filters) or commit to client-side (request all, filter client-side). Don't request 9999 and call that "page 1".

---

### `cl_loadout_panel.lua` — Gear-Up Flow

**What works:**
- Class list with current class highlighted (green tint)
- Loadout item list with owned-item indicator (green checkmark)
- Category tags per item
- Cost display
- Whitelist-filtered class list (correctly only shows whitelisted + default classes)

**Problems:**

**"CHANGE CLASS" and "GEAR UP" buttons are always enabled** regardless of state. If no class is selected, clicking GEAR UP sends `gearup` to the server, which replies with "Gear-up failed: No class assigned". The GEAR UP button should be disabled/hidden unless the player has a class. The CHANGE CLASS button should be disabled if the selected class is already the current class.

**`GetAvailableClasses()` reads the whitelist from the roster** (lines 173–180). The player's own whitelist is extracted from `clientData.roster`, iterating through every roster entry to find their own. This works but is indirect — the player's whitelist is really membership data that should be a separate field in the client state, not buried in the roster array.

**No feedback in the UI when gear-up succeeds.** The player gets a server notification ("Geared up! Cost: X resources.") but the loadout panel doesn't update the checkmarks or the resource display in the sidebar until the next `FullSyncToPlayer` arrives (which is triggered by `GearUp` calling it at line 1069 of sv_usms.lua, but with network latency there's a visible delay).

**The catalog system (`sh_catalogs.lua`) is nearly useless.** It registers 3 items globally. All faction-specific items are commented out. The loadout panel has to handle both the case where loadout items are plain strings (using the catalog for cost lookup) AND the case where they're tables with inline cost data (lines 330–355). This dual-format support adds complexity and the catalog format is not clearly specified.

**Fix:**
1. Disable GEAR UP if current class has no loadout or is not selected.
2. Disable CHANGE CLASS if selected class equals current class.
3. Store the player's own whitelist as a dedicated field in `clientData` instead of requiring roster iteration.
4. Either commit to the catalog system (define all items there) or remove it and require inline loadout definitions. Don't support both.

---

### `cl_service_record.lua` — Service Record Popup

**What works:**
- Personnel file section (name, rank, class, join date) is clean
- Commendation display with type-color indicators (gold/green/red) is well-designed
- Promotion history from logs is a genuinely useful RP feature
- Award dialog within the service record popup is compact and correct

**Problems:**

**Opened by left-clicking a roster row.** Covered in the roster section — this is the wrong default trigger.

**The service record panel inherits from `DFrame`** (line 448 `vgui.Register("ixUSMSServiceRecord", PANEL, "DFrame")`) but calls `SetTitle("")` (line 62) and draws its own title manually in `Paint()`. This is fighting the Derma framework for no benefit. Either use `DFrame` properly (pass a title) or inherit from `EditablePanel` and manage focus yourself.

**No timeout on "Loading service record..."** (line 107–110). If the server never responds to `service_record_request` (e.g., target character has no membership data), the panel shows "Loading service record..." forever.

**The `OpenAwardDialog()` (line 302) can be opened while a service record is already loading.** Two popups can stack. No guard on existing popup or loading state.

**Commendation revoke (line 173–186) re-requests the service record after 0.5 seconds** via `timer.Simple`. This is a polling workaround rather than a server push. When the commendation is revoked, the server should push a `USMSServiceRecordReceived` message to the viewing player (or fire a general `USMSRosterUpdated`).

**Fix:**
1. Add `service_record_request` response timeout (5 seconds → show error message).
2. Guard `OpenAwardDialog()` — if one is already open, don't open another.
3. Have the server push a service record refresh on commendation revoke instead of a timer-based re-request.
4. Fix parent class mismatch (use DFrame properly or switch to EditablePanel).

---

### `cl_invite_popup.lua` — Invite UX

**What works:**
- Slide-in animation with ease-out is polished
- Auto-dismiss after 60 seconds matches server-side expiry
- Accept/decline buttons are appropriately sized and colored
- Only one invite popup at a time (existing popup removed on new invite, cl_plugin.lua line 239–242)
- Keyboard input disabled so hotkeys still work while popup is visible

**No significant problems** — this is the best-implemented panel in the plugin.

Minor: The popup uses `SysTime()` for animation timing (correct) but its position is anchored to `ScrW() * 0.5` (centered), which is fine for most setups but may overlap HUD elements depending on the server's HUD layout.

---

### `cl_intel_panel.lua` — Cross-Faction Intelligence

**What works:**
- Split layout is consistent with other panels
- Supply status (vague label) is the correct level of info for intel

**This panel should be cut.** See Section 7. Specific bugs catalogued here for completeness:

**`RequestIntel()` sends up to 20 `intel_roster_request` messages** (lines 144–154):
```lua
local maxID = 20
for i = 1, maxID do
    if (!intelUnits[i]) then
        local myUnit = ix.usms.clientData.unit
        if (!myUnit or myUnit.id != i) then
            ix.usms.Request("intel_roster_request", {unitID = i})
        end
    end
end
```
This runs on every `Init()` + every "REFRESH INTEL" button click. It sends requests for unit IDs 1 through 20 regardless of whether those units exist. Most requests will be silently ignored by the server (unit not found), but all 20 hit the rate limiter. This is a brute-force unit scanner from the client — a protocol design smell.

**`canViewAllRosters` faction flag** is referenced by the server's `USMSCanViewIntel` hook default (sv_usms.lua line 2052) but is never defined in this plugin. It requires schema-level configuration with zero in-plugin guidance. This is an implicit contract with the schema developer.

**The intel detail panel shows two data points:** personnel count and supply status. This is not enough to justify a dedicated tab, a separate net message (`ixUSMSIntelSync`), a server hook, client cache (`intelUnits`), and the request spam.

---

### `cl_help_panel.lua` — Info Tab

A static scrollable text document. The content is accurate for roles and permissions, but:
- Makes no mention of the MISSIONS tab, INTEL tab, or service records
- Is never updated alongside feature additions
- Players do not read in-game documentation during active RP

**Cut as a tab.** Put the permission reference in the plugin's external documentation.

---

## 4. Architecture & Code Quality Issues

### `sv_usms.lua` — 2,590 Lines in One File

This is the single biggest maintenance problem. The file contains:

| Section | Lines | Should become |
|---|---|---|
| Net string declarations | 6–21 | `sv_networking.lua` |
| FullSync helpers | 24–48 | `sv_networking.lua` |
| Pending invite system | 50–167 | `sv_invites.lua` |
| Unit CRUD | 169–252 | `sv_units.lua` |
| Member management | 254–468 | `sv_units.lua` |
| Squad system | 469–781 | `sv_squads.lua` |
| Resource system | 783–845 | `sv_resources.lua` |
| Class + gear-up | 847–1072 | `sv_loadout.lua` |
| Networking send functions | 1074–1235 | `sv_networking.lua` |
| Request handler dispatch | 1285–1304 | `sv_requests.lua` |
| Squad request handlers | 1311–1534 | `sv_requests.lua` |
| Unit request handlers | 1611–1903 | `sv_requests.lua` |
| Class whitelist handlers | 1909–2021 | `sv_requests.lua` |
| Intel hook + handler | 2033–2056 | (cut or `sv_intel.lua`) |
| Mission system | 2058–2251 | `sv_missions.lua` |
| Commendation + service record | 2253–2415 | `sv_commendations.lua` |
| Mission + commendation handlers | 2417–2588 | `sv_requests.lua` |

Finding a specific piece of logic requires knowing roughly which 500-line band of the file it lives in. This slows down debugging and makes PR review nearly impossible.

---

### Data Flow Complexity

The server maintains 6 cache tables:
```
ix.usms.units, ix.usms.members, ix.usms.squads, ix.usms.squadMembers,
ix.usms.missions, ix.usms.commendations
```

The client maintains 6 cache tables:
```
clientData.unit, clientData.roster, clientData.squads, clientData.logs,
clientData.missions, clientData.intelUnits
```

The critical problem is **how `clientData.squads` is populated.** `cl_plugin.lua` lines 68–83 derive squad data from the roster payload:
```lua
local squads = {}
for _, entry in ipairs(roster) do
    if (entry.squadID and entry.squadID > 0) then
        if (!squads[entry.squadID]) then
            squads[entry.squadID] = {name = entry.squadName or "", ...}
        end
        table.insert(squads[entry.squadID].members, entry)
    end
end
ix.usms.clientData.squads = squads
```

Then `cl_squad_panel.lua`'s `BuildSquadData()` (lines 223–281) re-derives the same data from the roster AGAIN, merging it with `clientData.squads`. Squad data therefore exists in three places simultaneously: the server's `ix.usms.squads` table, `clientData.squads` (derived in cl_plugin.lua), and what `BuildSquadData()` constructs on demand.

This means a squad's name or description can be inconsistent across the three sources if one update path is missed.

**Fix:** Send squads separately via a dedicated net message. The roster entries should only carry `squadID` and `squadRole`. Squad metadata (name, description) is fetched from `clientData.squads`, which is updated by its own sync message. This eliminates the tri-derivation problem.

---

### The Roster Entry as Universal Data Blob

`SendRoster()` (sv_usms.lua lines 1125–1192) packs per-member data:

```lua
charID, role, joinedAt, squadID, squadRole, isOnline, name, class, className,
lastSeen, classWhitelist, squadName, squadDescription
```

**Privacy issue:** `classWhitelist` (the full list of class uniqueIDs a member is approved for) is sent to every unit member. A private first class can see another member's whitelist. Officers can use this in the right-click menu, but regular members have no UI for it — they just receive the data silently.

**Size issue:** On a 30-person unit, every roster entry carries a `classWhitelist` array. If each member has 5 whitelisted classes (string uniqueIDs), that's 150+ strings in every roster payload. This adds to compressed size and transmission time.

**Roster-carries-squad-data issue:** The roster entry carries `squadName` and `squadDescription` which duplicates what would be in a proper squad sync. If a squad description changes, the squad panel won't update until the next full roster sync (`FullSyncToUnit`).

---

### Permission System Consistency

The `IsSuperAdmin()` bypass is applied to 25+ locations uniformly. No gaps found in the audit. However, the implementation is verbose:

```lua
-- Repeated pattern across every handler:
if (!ply:IsSuperAdmin() and (!member or member.role < USMS_ROLE_XO)) then
    ply:Notify("Only CO/XO can...")
    return
end
```

A utility function would reduce this from 3-line blocks to 1-line:
```lua
-- Proposed:
if (!ix.usms.HasPermission(ply, char, USMS_ROLE_XO)) then return end
```

One inconsistency found: In `squad_invite` handler (sv_usms.lua line 1325), the permission check is:
```lua
if (!ply:IsSuperAdmin() and (!sm or sm.role < USMS_SQUAD_INVITER)) then
```
This requires the player to be *in a squad* to invite (they need `sm`). But a unit XO who is not in any squad should also be able to invite to squads. The unit officer bypass only exists for `squad_force_add`, not for the regular invite flow.

---

### The Request Handler Pattern — Strengths and Weaknesses

**Strengths:**
- Single net message string `ixUSMSRequest` for all client→server operations
- 0.5-second rate limit applied globally (sv_usms.lua line 1295)
- Keyed dispatch table is easy to extend
- All handlers receive `(ply, char, data)` with character already resolved

**Weaknesses:**

`net.WriteTable(data)` (cl_plugin.lua line 215) transmits arbitrary tables. The server's `net.ReadTable()` has no schema validation. A malicious client can send any table structure. Current handlers use `tonumber(data.charID)` etc., which is safe for individual fields, but there's no guard against sending a massive nested table to cause a DoS via deserialization.

**The `invite_respond` request handler (line 1782) is dead code.** It routes to `ix.usms.RespondToInvite` but nothing sends this action code. Invite responses use the dedicated `ixUSMSInviteResponse` net message. The request handler is never reached.

The 0.5-second cooldown is shared across all actions. A player rapidly clicking "roster_request" (e.g., the panel refreshing) blocks time-critical actions like `squad_leave` for the duration.

---

### Sync Strategy — `FullSyncToUnit` vs Delta Updates

`FullSyncToUnit(unitID)` is called after essentially every operation that affects squad state:

| Operation | Expected sync | Actual sync |
|---|---|---|
| AddToSquad | Update squad membership | `FullSyncToUnit` (full unit + roster to all) |
| RemoveFromSquad | Update squad membership | `FullSyncToUnit` |
| DisbandSquad | Remove squad from lists | `FullSyncToUnit` |
| squad_set_role | Update one member's squad role | `FullSyncToUnit` |
| squad_set_description | Update one field | `FullSyncToUnit` |
| squad_force_add | Same as AddToSquad | `FullSyncToUnit` |
| co_transfer | Two role changes | `FullSyncToUnit` |

`FullSyncToUnit` sends `SyncUnitToPlayer` (unit metadata net message) AND `SendRoster` (full compressed roster JSON) to every online unit member. On a 30-person unit, a single squad role change sends a full roster payload to 30 clients.

A delta update system (`SyncRosterUpdateToUnit` with action "update" already exists) should handle the majority of these cases. `FullSyncToUnit` should be reserved for membership changes that affect the squad count display in the sidebar.

The core issue: `SyncRosterUpdateToUnit` only sends one character's updated entry. Squad-related changes affect multiple characters' displayed data (e.g., AddToSquad changes the squad member count visible to all). The right fix is to send a dedicated squad update message, not a full roster.

---

### Persistence — Single JSON Flat File

`sv_database.lua` saves everything (units, members, squads, squad members, missions, commendations, logs) to one JSON file via Helix's `plugin:SetData`.

**Problem 1: `db.Save()` is called after every single mutation.** Count of direct `ix.usms.db.Save()` calls across sv_usms.lua: approximately 30. Every squad role change, every gear-up, every mission status update calls `Save()`. This is synchronous JSON serialization of the entire data set on every operation.

**Problem 2: Logs are stored in the same file as operational data.** After 60 days, an active server with dozens of daily events could have 5,000+ log entries. The JSON log array is serialized alongside unit/squad data on every `db.Save()` call, even if only a unit name changed.

**Problem 3: JSON key coercion.** `sv_database.lua` lines 33–50 convert all JSON keys back to numbers:
```lua
for k, v in pairs(data.units) do
    ix.usms.units[tonumber(k) or k] = v
end
```
JSON serializes Lua table keys as strings. The numeric coercion on load is correct but fragile — if a key ever legitimately should be a string (none currently do), this silently converts it.

**Fix (minimal viable):**
1. Add a dirty-flag system: mark the plugin as dirty on mutation, write once per second maximum via a timer.
2. Separate log storage: logs written to a separate file with their own load/save path.

---

### Hook Proliferation

USMS defines or fires 30+ hooks. Most are legitimate extension points. However:

**`USMSSquadDataUpdated` is never fired.** It's registered as a listener in `cl_squad_panel.lua` (line 187) and removed in `OnRemove()` (line 197). Nothing fires it. Dead code.

**`USMSAutoAssignUnit` allows external code to redirect auto-assignment** (sv_plugin.lua lines 50–54). This is a reasonable hook. However, the hook logic `if (isnumber(override) and ix.usms.units[override]) then targetUnitID = override end` only catches numeric returns. If a hook returns the unitID as a string (common JSON deserialization artifact), the redirect silently fails.

**`USMSCanCreateSquad`'s default handler** (sv_usms.lua lines 552–568) checks a `ixUSMSCanCreateSquad` NetVar:
```lua
if (ply:GetNetVar("ixUSMSCanCreateSquad", false)) then
    return true
end
```
This NetVar is set by the `USMSCanSquad` test command (`commands/sh_testing.lua` line 118–127). This is a development artifact that has leaked into production code — a runtime permission override via NetVar that bypasses the rank requirement for squad creation.

---

## 5. The Feature Overreach Problem

### Mission System

The mission system stores: title, description, priority (1/2/3), status (active/complete/cancelled), creator, assignment (unit-wide or squad), and timestamps. Creating a CRITICAL mission pushes a "priority order" to the diegetic HUD.

**What it's missing to be useful:**
- No in-game notification to assigned squad members on creation
- No resource reward on completion
- No automatic completion trigger (you complete a mission by clicking a button in a menu — nothing in the game world signals completion)
- No "in progress" state
- No map marker or world-space indicator

Without these, the mission system is a shared to-do list. The UI cost (a full tab, 656 lines of client code, mission net messages, server persistence) far exceeds its gameplay contribution. On an active RP server, it may see use for about a week before being forgotten.

**Verdict:** Either invest in making it genuinely interactive (map markers, reward hooks, auto-completion triggers) or cut it. As currently implemented, it belongs in a spreadsheet, not a game.

---

### Commendation / Service Record System

**RP value:** High in concept. A persistent record of promotions and awards per character is genuinely interesting for long-running RP.

**Implementation gap:** The system stores medals, commendations, and reprimands. None of them have any in-game effect. They don't appear on the character's player model, scoreboard, nameplate, or anywhere visible during play. You can only see them by left-clicking (!) the roster row to open a popup. Recipients are not notified when they receive a commendation.

**Implementation complexity:** Significant. Service records require: a separate server function (`GetServiceRecord`), a separate net message (`ixUSMSServiceRecord`), a dedicated panel (`cl_service_record.lua`, 449 lines), an award dialog, a revoke flow, and commendation storage in the save file.

**Verdict:** The concept has merit for deep RP. Simplify drastically: one award type, no revoke, read-only display, and add a notification. Don't build full CRUD unless the server actually uses it.

---

### Intel System (Cross-Faction)

**What it actually does:** Allows players whose faction has `canViewAllRosters = true` to see: another unit's personnel count and supply status label.

**What it doesn't do:** Show faction, composition, class distribution, squad count, or anything operationally useful. The "intel" is so thin it provides no tactical value.

**Is it finished?** Structurally yes, conceptually no. The `RequestIntel()` function (cl_intel_panel.lua lines 129–155) scans unit IDs 1–20 on every panel open, sending up to 20 network requests. The `canViewAllRosters` flag is never defined in this plugin. The detail panel shows two lines of data.

**Verdict:** Cut entirely. The information provided (headcount + supply vague status) is achievable via an admin command in 10 lines of code. The full implementation cost (net message, server handler, hook, client cache, 278-line panel, brute-force discovery) is not justified.

---

### HUD Integration (Diegetic)

The HUD integration in `sv_plugin.lua` and `sv_usms.lua` is cleanly separated:
- All HUD calls are guarded: `if (ix.diegeticHUD and ix.diegeticHUD.squads) then`
- The 3-second sync timer is minimal
- HUD squad creation/sync/disband happens as a side-effect of squad operations

**This is the best-designed optional integration in the plugin.** It's cleanly optional and doesn't couple USMS to the HUD's internals beyond a surface API contract.

Minor issue: The HUD sync timer in `sv_plugin.lua` (line 217) is a polling loop that iterates all squads every 3 seconds. On a server with 5 squads, this fires 5 `ix.diegeticHUD.SyncSquad` calls every 3 seconds indefinitely. This should only fire when squad membership has changed (event-driven). The comment "usmsHUDSyncInterval" in the config suggests this was always intended as a polling interval, but event-driven would be cleaner.

---

### Resource System

The resource system concept is correct: each unit has a shared pool consumed by gear-up. The implementation is sound.

**The problem:** Resources have no source. The only ways to add resources are:
1. `UnitSetResources <unitID> <amount>` — superadmin command
2. `UnitAddResources <unitID> <amount>` — admin command

Neither is in-game RP. On a Star Wars military RP server, resources should be earned through gameplay: completing missions, defending objectives, receiving supply drops, etc. None of those hooks exist. Resources are set by admins and drain as players gear up.

This means in practice: admins set resources before events, players gear up, resources drain. The system enforces nothing — an admin just sets it back to max whenever needed.

**Verdict:** Keep the data model. Either implement a simple income mechanic (e.g., a timed tick that adds resources if the unit has online members) or remove resource costs from gear-up entirely. The current state is worse than either alternative because it creates resource scarcity without providing the gameplay loops that scarcity is supposed to motivate.

---

### Class Whitelist System

**Is it necessary?** Yes. On a military RP server, you don't want players freely switching to specialist classes. The whitelist provides officers with explicit control over class access.

**Is it over-engineered?** Slightly. The whitelist is stored as an array of string uniqueIDs per member, serialized in the save file, sent in every roster payload, and managed via a 2-level right-click submenu. This is appropriate — the uniqueID-based approach correctly survives class list reordering (noted in `sv_plugin.lua` line 106).

**Problems:**
1. The whitelist is visible to all unit members in the roster payload (privacy concern)
2. The management UI is buried (right-click → sub-sub-menu)
3. There's no visual confirmation when a class is auto-whitelisted on assignment (the code auto-whitelists at sv_usms.lua line 930, but the UI doesn't communicate this happened)

**Verdict:** Keep. Fix the privacy issue by only sending a player's own whitelist to them. Move the management UI to the LOADOUT tab (it belongs there contextually).

---

## 6. Workflow Analysis — How It Feels In Practice

### Flow 1: New Player Joins a Unit

**Expected experience:** Player creates a character, gets assigned to their faction's military unit, is told what class to ask for, gets geared up, is ready for play.

**Actual experience:**

1. Player creates character → `OnCharacterCreated` fires → `AutoAssignToFactionUnit` runs after 0.5s delay
2. The assignment is silent. No notification to the player, no ceremony. They're just "in" a unit.
3. Player opens character menu → DEPLOYMENT tab → Sees their unit name in sidebar. ✓
4. Player needs a class. They must find a CO/XO and ask. The CO/XO finds them in the roster, right-clicks, navigates to "Assign Class" submenu (no class descriptions visible, just names), picks a class.
5. `ChangeClass` fires → `FullSyncToUnit` → All 30 unit members get a full roster re-download in the background.
6. Player sees new class in LOADOUT tab. They want to gear up. They click GEAR UP. Server notification: "Geared up! Cost: 25 resources."
7. Player has no in-panel feedback. The items appeared in their inventory (elsewhere), and the resource bar in the sidebar updates eventually.

**Friction points:**
- Silent auto-assignment (no acknowledgement, no context given to the player)
- Class assignment requires a CO/XO to be online and the player to ask OOC
- Assign Class submenu has no descriptions → officers can't distinguish specialist classes by name alone
- Gear-up feedback is a chat notification, not a panel update
- The resource deduction visible to officers happens with ~1 second latency after gear-up

---

### Flow 2: Squad Leader Creates a Squad, Invites Members, Runs a Mission

1. Squad leader (has rank or `ixUSMSCanCreateSquad` NetVar) opens SQUADS tab
2. Clicks "CREATE SQUAD" → `Derma_StringRequest` modal asks for a name → types name → creates
3. `CreateSquad` fires → `FullSyncToUnit` → **All 30 unit members receive a full roster payload** for what is essentially a 1-person squad being created.
4. Squad appears in the list. Leader clicks it to see detail. "1 members" (grammatically wrong).
5. Leader wants to invite someone. Clicks INVITE → squad invite picker — shows only online members not in any squad. Target must be in the unit, online, and squad-less. No offline invites.
6. Target player receives invite popup. Accepts. → `AddToSquad` fires → `FullSyncToUnit` **again**. Two full roster blasts for a squad of 2.
7. Leader switches to MISSIONS tab, clicks "+ CREATE MISSION".
8. **Create dialog uses SetPos absolute positioning.** Fills in title/desc, selects "Critical" priority, assigns "Entire Unit".
9. Submits. Mission created. → `SyncMissionsToUnit` (separate broadcast). No notification to squad members (there's no squad assigned here anyway).
10. Mission appears in ACTIVE list for all unit members who happen to look at the MISSIONS tab. No in-game signal.

**Friction points:**
- `FullSyncToUnit` is called twice for creating a 2-person squad (overkill)
- No offline invite support
- No notification to players that a mission was created
- The MISSIONS tab is not on the player's primary task list — missions are created in the menu but experienced nowhere in the game world
- Completing a mission requires going back to the menu, clicking MISSIONS, selecting the mission, clicking COMPLETE → no game consequence

---

### Flow 3: Officer Viewing Roster and Managing a Member

1. Officer opens DEPLOYMENT tab → ROSTER tab (default, correct)
2. Sees roster table. Wants to check on a specific member.
3. **Hovers** → tooltip with name, status, role, class, squad. Good.
4. **Left-clicks** → Service record popup opens. The officer wanted to right-click for actions. Now they have an unexpected popup to close.
5. **Right-clicks** → Context menu with: Set Role →, Remove from Unit, Transfer CO, Assign Class →, Manage Class Whitelist →, Invite to Squad, Remove from Squad, Add to Squad →, Set Squad Role →
6. Officer wants to kick someone. Finds "Remove from Unit" between "Transfer CO" and "Assign Class". Dangerous actions and routine actions are interleaved.
7. Officer wants to demote XO to member. Finds "Set Role" → submenu with Member/XO/(CO for superadmins). 3 clicks.

**Friction points:**
- Left-click trigger for service record is confusing/accidental
- 9 options in right-click menu with no visual grouping (dangerous vs routine actions)
- The "EDIT UNIT" button is in the ROSTER tab's action bar — it doesn't belong there; unit configuration should be a separate section
- No "refresh" button on the roster panel — if data is stale, the officer doesn't know

---

## 7. What Should Be Cut

### Cut Entirely

**1. Intel Panel (`cl_intel_panel.lua`, server handler, `ixUSMSIntelSync` net message)**
- 20 network requests on open for 2 data points
- `canViewAllRosters` is undefined in this plugin
- Achievable with one admin command
- 278 lines of client code, a net message, a server hook, and client cache for headcounts

**2. `sh_catalogs.lua` — The Equipment Catalog System**
- Contains 3 placeholder items; all faction items are commented out
- Adds a whole API (RegisterGlobalItem, RegisterFactionItem, GetAvailableCatalog) used nowhere in practice
- The loadout panel already handles both catalog and inline item formats — supporting both adds complexity without value
- Delete the file. Require loadout definitions to be inline in class definitions.

**3. "INFO" Tab (Help Panel)**
- Static in-game documentation nobody reads during active play
- Out of date (doesn't mention missions, intel, service records)
- Move reference to external documentation

**4. `USMSCanSquad` test command** (`commands/sh_testing.lua` line 118–127)
- Sets a NetVar that bypasses rank-based squad creation permissions
- This is a development artifact that should never be in a production plugin
- The `ixUSMSCanCreateSquad` NetVar check in the permission hook is also dead weight once this command is removed

**5. Dead hook `USMSSquadDataUpdated`** (`cl_squad_panel.lua` lines 187–192)
- Never fired anywhere
- Remove from cl_squad_panel.lua Init() and OnRemove()

**6. Dead request handler `invite_respond`** (sv_usms.lua line 1782–1785)
- Invite responses use the dedicated `ixUSMSInviteResponse` net message
- The request handler is never called
- Remove to avoid confusion

---

### Simplify Significantly

**1. Mission System**
- Remove priority levels (Low/Normal/Critical → just Critical vs Normal)
- Remove squad-specific assignment (unit-wide only, simpler)
- Remove the `SetPriorityOrder` HUD integration (too opaque)
- Keep: create, complete, cancel, list, persistence
- Reduce create dialog from 4 fields to 2 (title + description)

**2. Commendation / Service Record**
- Remove the 3-type award system (medal/commendation/reprimand) → single "Award"
- Remove the revoke flow
- Keep: award an entry, view the list
- Add: notify recipient on award

**3. Squad Roles (4 → 2)**
- Current: MEMBER (0), INVITER (1), XO (2), LEADER (3)
- Proposed: MEMBER (0), LEADER (1)
- The INVITER role exists to delegate inviting without granting XO authority. This is a fine concept but adds a whole role, role assignment UI, and permission check complexity for a rarely-used feature.
- The XO role duplicates the unit XO concept inside a squad. A squad leader can invite; everyone else is a member.

**4. Resource System**
- Add a minimal income mechanism (e.g., `UnitAddResources` accessible to CO rank, not just admins)
- Or remove resource costs entirely and have gear-up always succeed (simpler, same gameplay outcome if resources aren't tracked anyway)
- Don't leave it in the current half-state (costs exist but no income source)

---

### Defer to Later

**1. Full Mission System** — Keep the data model. Build the full system (notifications, map markers, rewards) when there's a gameplay design for what missions actually do.

**2. Service Record as character profile** — Good long-term feature. Add when commendations have gameplay effects (character traits, ability unlocks, faction reputation).

---

## 8. What Should Be Reworked

### 1. Split `sv_usms.lua` Into Modules (Priority: High)

Proposed split:
```
libs/sv_units.lua          — Unit CRUD, member add/remove/role, CO transfer
libs/sv_squads.lua         — Squad create/disband, squad member management
libs/sv_resources.lua      — Resource get/set/add/deduct
libs/sv_loadout.lua        — Class change, gear-up, whitelist management
libs/sv_networking.lua     — All net strings, sync functions, request dispatch
libs/sv_requests.lua       — All ix.usms.requestHandlers entries
libs/sv_missions.lua       — Mission create/complete/cancel/get/sync (already conceptually isolated)
```
The `sh_plugin.lua` include order already handles load ordering. This is a mechanical split with no logic changes required — just file creation and proper `include()` calls.

### 2. Roster Data Model — Stop Using Roster as Squad Sync

**Current:** Every roster entry carries squadName, squadDescription, squadRole. Squad data is derived from roster.

**Proposed:**
- Roster entries carry only `squadID` and `squadRole`
- A separate `ixUSMSSquadSync` net message sends squad metadata (name, description, leaderCharID) keyed by squadID
- `clientData.squads` is populated by the squad sync message, not derived from roster
- This eliminates the triple-derivation and fixes stale squad descriptions

### 3. `FullSyncToUnit` Throttling

Add a per-unit dirty flag and a 150ms debounce timer:
```lua
-- On any change to unitID:
ix.usms._dirtyUnits = ix.usms._dirtyUnits or {}
ix.usms._dirtyUnits[unitID] = true

-- Timer fires every 150ms:
timer.Create("ixUSMSDirtyFlush", 0.15, 0, function()
    for unitID in pairs(ix.usms._dirtyUnits) do
        ix.usms.FullSyncToUnit(unitID)
        ix.usms._dirtyUnits[unitID] = nil
    end
end)
```
This batches rapid consecutive operations (create squad + add two members) into a single network flush instead of 3 full roster broadcasts.

### 4. Right-Click Context Menu on Roster Rows

**Current:** 9+ options, 2-level submenus.

**Proposed (5 options max):**
- Set Role → (Member / XO) — only for CO
- Assign Class → (faction classes with description)
- Remove from Unit — only if officer outranks target
- Invite to Squad — only if officer is in squad and target isn't
- View Service Record

Move class whitelist management to the LOADOUT tab under a "Manage Whitelist" button visible only to officers.

### 5. Left-Click on Roster Row

Change `OnMousePressed` in the roster row to be a no-op on MOUSE_LEFT. Move service record to right-click menu as "View Service Record" (see above). This is a one-file change in `cl_unit_roster.lua` lines 580–587.

### 6. THEME Table Deduplication

Create `derma/cl_theme.lua` with the shared theme:
```lua
USMS = USMS or {}
USMS.THEME = {
    background = Color(10, 10, 10, 255),
    frame = Color(191, 148, 53, 255),
    ...
}
```

Include it first in `sh_plugin.lua` (or as part of `cl_plugin.lua` include chain). Every panel references `USMS.THEME` instead of its own local THEME table. Color changes require editing 1 file instead of 10.

### 7. `db.Save()` Debouncing

Replace all direct `ix.usms.db.Save()` calls with a dirty flag:
```lua
function ix.usms.db.MarkDirty()
    ix.usms.db._dirty = true
end
-- In the periodic save timer:
if (ix.usms.db._dirty) then
    ix.usms.db.Save()
    ix.usms.db._dirty = false
end
```
The periodic save is already in the Helix `SaveData` hook (`sv_plugin.lua` line 16). Add a 10-second autosave timer in addition. This reduces the ~30 synchronous serialization calls per active session to at most 6 per minute.

### 8. Separate Log Storage

`sv_database.lua`'s `Save()` function includes `logs = ix.usms.logs`. After 60 days of active logging, this array could have 5,000+ entries being serialized on every save alongside unit/squad data.

Separate log persistence: write logs to their own file (`plugin:SetData("logs", ix.usms.logs)`), loaded in `db.Load()` separately. Operational data saves independently from log data.

---

## 9. What Should Be Added

The system already has too many features. This section is intentionally short.

**1. Recipient notification on commendation award**  
When `AwardCommendation` completes, send the recipient a `ply:Notify` if they are online. This is a 3-line addition to sv_usms.lua after line 2311.

**2. Squad notification on mission assignment**  
When `CreateMission` completes with `assignedTo.type == "squad"`, notify all online members of that squad. Currently missions are created silently.

**3. Resource income mechanism accessible to CO**  
The `UnitAddResources` command is admin-only. Add a request handler `unit_request_resupply` that allows the unit CO to request resupply (which an admin can then approve and run). Or add a simple configurable income tick for units with online members. Currently resources have no source accessible to players.

**4. Roster refresh button**  
The roster panel has no way to manually re-request current roster data. Add a small "REFRESH" button to the action bar that sends `roster_request`. Currently the roster is only fetched on panel init.

---

## 10. Recommended Refactor Roadmap

### Phase 1 — Quick Wins (No Logic Changes, Immediate Clunk Reduction)

These are low-risk changes that reduce visible friction immediately:

1. **Fix left-click on roster rows** — make it a no-op; add "View Service Record" to right-click menu. (`cl_unit_roster.lua` lines 580–587)
2. **Remove dead `USMSSquadDataUpdated` hook** (`cl_squad_panel.lua` lines 187–192)
3. **Remove dead `invite_respond` request handler** (sv_usms.lua line 1782–1785)
4. **Fix hardcoded `maxSize = 8`** in cl_unit_overview.lua line 307 → `ix.config.Get("usmsSquadMaxSize", USMS_SQUAD_MAX_SIZE)`
5. **Add "class_whitelist" to `LOG_ACTION_LABELS`** in cl_log_panel.lua
6. **Cut the INTEL tab** — remove `cl_intel_panel.lua`, `ixUSMSIntelSync` net string, `intel_roster_request` handler, `USMSCanViewIntel` hook, `clientData.intelUnits`
7. **Cut `sh_catalogs.lua`** — delete the file; require inline loadout definitions
8. **Cut "INFO" tab** — remove `cl_help_panel.lua` as a tab entry in cl_usms_tab.lua
9. **Remove `USMSCanSquad` dev command** from `commands/sh_testing.lua` and remove the `GetNetVar("ixUSMSCanCreateSquad")` check from the `USMSCanCreateSquad` hook
10. **Fix reversed actor/target in squad_force_add log call** (sv_usms.lua line 1605: `targetCharID` and `char:GetID()` are swapped)
11. **Add a REFRESH button to the roster panel** action bar
12. **Deduplicate THEME tables** → create `derma/cl_theme.lua` (10 files simplified)

**Estimated result:** 4 tabs instead of 7, visible dead code removed, worst UX inversion fixed.

---

### Phase 2 — Core Rework (Actual Design Work)

1. **Split `sv_usms.lua`** into 6–7 modules as outlined in Section 8. This is the highest-leverage single change.
2. **Add `FullSyncToUnit` throttling** — dirty flag + 150ms debounce timer. Eliminates network storm on squad operations.
3. **Reduce squad roles from 4 to 2** (MEMBER + LEADER). Update all role checks, UI, and role name tables.
4. **Simplify mission create dialog** — Dock layout, remove priority levels, remove squad assignment.
5. **Simplify right-click context menu** to 5 options. Move class whitelist management to LOADOUT tab.
6. **Debounce `db.Save()`** using dirty flag. Separate log storage from operational data.
7. **Separate squad sync from roster sync** — send squad metadata independently.
8. **Add recipient notification on commendation award.**
9. **Add squad notification on mission assignment.**

---

### Phase 3 — Nice-to-Have (Only After Phase 1+2 Are Solid)

1. Resource income mechanic (configurable tick, or CO-requestable resupply)
2. Offline member class/role changes (apply to cached data, sync on login)
3. Mission system improvements (notifications, reward hooks for schema integration)
4. Service record improvements (display on hover, auto-award on promotion)
5. Real server-side log pagination (stop requesting 9999 and paginating client-side)
6. Intel system rewrite with meaningful data (if the server design requires it)

---

## 11. File & Code Organisation Recommendations

### How to Split `sv_usms.lua`

The file should be split along these lines, with explicit include ordering in `sh_plugin.lua`:

```lua
-- sh_plugin.lua include order:
ix.util.Include("libs/sh_usms.lua")           -- constants + shared utils
ix.util.Include("libs/sh_catalogs.lua")        -- (or delete)
ix.util.Include("libs/sv_database.lua")        -- persistence layer
ix.util.Include("libs/sv_logging.lua")         -- log append/fetch
ix.util.Include("libs/sv_networking.lua")      -- net strings + sync functions
ix.util.Include("libs/sv_units.lua")           -- unit + member CRUD
ix.util.Include("libs/sv_squads.lua")          -- squad CRUD
ix.util.Include("libs/sv_resources.lua")       -- resources
ix.util.Include("libs/sv_loadout.lua")         -- class + gear-up + whitelist
ix.util.Include("libs/sv_invites.lua")         -- pending invite system
ix.util.Include("libs/sv_missions.lua")        -- mission system
ix.util.Include("libs/sv_commendations.lua")   -- commendations + service records
ix.util.Include("libs/sv_requests.lua")        -- all request handlers
ix.util.Include("sv_plugin.lua")
```

### Naming Consistency Issues

| Current | Issue | Proposed |
|---|---|---|
| `ix.usms.GetPlayerByCharID` | Iterates all players every call, no caching | Keep but document as O(n) |
| `ix.usms.GetCharacterByID` | Nearly identical to above, also O(n) | Merge into one function returning `{ply, char}` |
| `SyncRosterUpdateToUnit` | Sends to *all unit members* despite name suggesting a single player | Rename to `BroadcastRosterUpdate` |
| `FullSyncToPlayer` | Sends unit + roster | Rename to `SyncAllToPlayer` or keep as is |
| `FullSyncToUnit` | Sends unit + roster to all members | Rename to `BroadcastFullSync` to make overuse visible |
| `ix.usms.db.Save()` | Called as `db.Save()` but `db` is a sub-table of `ix.usms` | Fine as is, document it |
| `USMS_LOG_CLASS_WHITELIST` | Constant defined, label missing in UI | Add to LOG_ACTION_LABELS |
| Tab name "info" → `helpPanel` | Mismatch between tab name and panel variable name | Use "help" as tab name or rename helpPanel to infoPanel |

### Dead Code / Unused Functions Found

1. **`USMSSquadDataUpdated` hook listener** — `cl_squad_panel.lua` lines 187–192. Never fired.
2. **`invite_respond` request handler** — sv_usms.lua line 1782–1785. Never called.
3. **`ix.usms.SyncUnitToAllMembers`** (sv_usms.lua line 1097–1103) — Only called from `unit_edit` handler. Every other path uses `FullSyncToUnit`. This function is redundant with `FullSyncToUnit` minus the roster send.
4. **`ixUSMSCanCreateSquad` NetVar check** in `USMSCanCreateSquad` hook — sv_usms.lua line 563–565. Used only by the `USMSCanSquad` dev command. Remove both together.
5. **`ix.usms.clientData.intelUnits`** — If intel system is cut, this field in `cl_plugin.lua` line 10 becomes dead.
6. **`ixUSMSSquadSync` and `ixUSMSSquadUpdate` net strings** — sv_usms.lua lines 11–12. These are declared but no messages are ever sent via these strings. The squad panel receives all its data from `ixUSMSRosterSync`. These strings are unused.

```lua
-- sv_usms.lua lines 11-12 - UNUSED:
util.AddNetworkString("ixUSMSSquadSync")    -- nothing ever sends on this
util.AddNetworkString("ixUSMSSquadUpdate")  -- nothing ever sends on this
```

These were likely defined in anticipation of a dedicated squad sync path that was never implemented (squad data was folded into the roster sync instead).

---

## Summary Scorecard

| Category | Current Grade | After Phase 1 | After Phase 2 |
|---|---|---|---|
| Feature cohesion | D | C | B |
| UI usability | C | C+ | B |
| Architecture | C | C | B+ |
| Network efficiency | C- | C- | B |
| Persistence | C | C+ | B |
| Code organisation | D | D | B |
| Gameplay value | D+ | D+ | C+ |

The system is not broken — it runs and works. But it needs significant pruning (cut 3 features, simplify 3 more) and a structural overhaul of its largest file before it can be called production-quality for an active server.

## Addendum: User Journey Analysis & Friction Mapping

### 1. The New Recruit
**Profile:** A newly whitelisted player joining the server/faction. Needs to figure out their unit, get a class, and gear up to play. Not an expert on the plugin UI.
- **Journey:** Character creation $\to$ auto-assigned. Opens the F1 menu $\to$ DEPLOYMENT tab. Greeted with 7 tabs (ROSTER, SQUADS, LOADOUT, MISSIONS, LOGS, INTEL, INFO). They click LOADOUT and hit "GEAR UP" only to get a silent or chat-only rejection ("No class assigned") from sv_usms.lua. They must hunt down an officer in-game or via Discord, wait for them to open the ROSTER, right-click their name, navigate to Assign Class, and select a class. Then they hit "GEAR UP" again.
- **Pain Points:**
  - Auto-assignment (sv_plugin.lua) is entirely silent; no on-screen welcome message or instructions.
  - "GEAR UP" and "CHANGE CLASS" buttons are not disabled when invalid (cl_loadout_panel.lua), causing confusion.
  - 7 tabs generate immediate cognitive overload.
- **Verdict (Kill Your Darlings):** INTEL, MISSIONS, LOGS tabs are completely useless to them and should be hidden or cut.

### 2. The Regular Member (settled, has class and squad)
**Profile:** Established player who plays events. Needs the plugin to see who's online, their squad assignment, and loadout.
- **Journey:** Opens the UI occasionally. Glances at the ROSTER to see player counts or class composition (cl_unit_roster.lua). 
- **Pain Points:**
  - If they click a row to see details, they accidentally open a Service Record popup (cl_service_record.lua) instead of selecting the row.
  - SQUADS tab shows "CREATE SQUAD" and "LEAVE SQUAD" buttons that they either can't use (lack of rank) or that are meaningless (not in a squad), leading to server rejection errors (sv_usms.lua permission blocks).
- **Verdict (Kill Your Darlings):** The MISSIONS tab is ignored because it has no gameplay integration. Commendations mean nothing to their day-to-day. 

### 3. The Squad Leader (player-created squad, no unit officer rank)
**Profile:** An active player stepping up to lead a squad of 4-8 players. Represents the core "squad self-organisation" design pillar.
- **Journey:** Creates squad via SQUADS tab $\to$ "CREATE SQUAD" button. Opens specific squad details $\to$ "INVITE". Finds target (must be online/unsquadded). Target accepts. 
- **Pain Points:**
  - Cannot invite offline players to the squad. Squad pre-organisation before an event is impossible without an officer using squad_force_add.
  - Creating their squad and adding every member triggers consecutive FullSyncToUnit payloads, lagging the server/clients unnecessarily (sv_usms.lua).
  - Two disband buttons shown inside the same detail screen (cl_squad_panel.lua).
  - No notification when a mission is assigned to them.
- **Verdict (Kill Your Darlings):** Squad invites via the detail panel INVITE button conflict with the ROSTER right-click invite path. One should be cut.

### 4. The Unit XO (executive officer � second in command)
**Profile:** The workhorse of the unit. Manages the roster, assigns classes, forms event squads, disciplines, and tracks logs.
- **Journey:** Before an event, they must assign whitelists and classes. They open ROSTER, right-click a recruit $\to$ Manage Class Whitelist (a clunky submenu of checkboxes). Then right-click again $\to$ Assign Class. This is done per-recruit in a nested menu. 
- **Pain Points:**
  - Whitelist management is buried deeply in the ROSTER right-click menu rather than residing in LOADOUT or a dedicated dashboard.
  - The ROSTER tab doesn't refresh automatically on return, so they frequently act on stale data.
  - The LOGS tab pulls 9999 entries without server-side filtering (cl_log_panel.lua), which causes a massive network stall on the XO opening it.
- **Verdict (Kill Your Darlings):** The Service Record system is too bureaucratic to use often and should be vastly simplified to a single "Award" string. 

### 5. The Unit CO (commanding officer � top of the unit)
**Profile:** Unit director. Delegates to the XO but steps in for overarching setups and transferring command.
- **Journey:** Opens ROSTER or LOGS to review unit health. Can access "EDIT UNIT" (which only does Name/Description, missing config caps) and transfer the CO position via the right-click menu.
- **Pain Points:**
  - The CO Transfer option is placed next to routine actions in a crowded 9-item right-click menu, carrying a high risk of misclicking.
  - They lack an aggregate overview of structural health�just a long list of sorted rows.
  - They cannot add Resources unless they use discord to ask a server Admin to run /UnitAddResources.
- **Verdict (Kill Your Darlings):** The INTEL tab offers a single headcount integer that does nothing for strategic command. Cut it.

### 6. The Multi-Unit Admin (server staff who manages multiple units/factions)
**Profile:** Server owner/manager setting up units for 501st, Navy, etc. Not necessarily meant to act "in-character" within the unit.
- **Journey:** Uses chat commands /UnitCreate, /UnitSetResources to bootstrap units. Must manually switch to a character in a unit to actually see its roster using USMS.
- **Pain Points:**
  - Highly scoped USMS UI means there is zero cross-unit GUI. It is entirely character-dependent. Needs a true Admin dashboard or at least an overlay to view any unit's roster without swapping characters.
  - Adding resources is entirely manual and chat-based, causing constant Discord pinging from COs.
- **Verdict (Kill Your Darlings):** Admin commands are functionally enough, but UI absence makes oversight difficult. The overarching complex systems (Missions, Intel) distract development time from a proper multi-unit Staff view.

### 7. The Casual Event Participant (attends missions but is barely engaged with the unit structure)
**Profile:** Occasional player. Just wants to shoot things. Follows the RP organically rather than in menus.
- **Journey:** Opens F1 $\to$ USMS $\to$ LOADOUT. Hits GEAR UP. Closes menu.
- **Pain Points:**
  - They face 7 tabs, popup alerts, and irrelevant data to do the one thing they need: get their gun. 
- **Verdict (Kill Your Darlings):** Everything except ROSTER and LOADOUT is noise to them. The plugin desperately needs permission-based tab hiding or consolidation.

### Cross-Cutting Friction Patterns
- **The "Left-Click" Service Record Trap:** Experienced by *every* user type that clicks a roster row expecting to highlight it (cl_unit_roster.lua). Needs immediate removal.
- **7-Tab Cognitive Overload:** The UI throws too much at players. INTEL, INFO, MISSIONS, and often LOGS shouldn't be visible or shouldn't exist as top-level spaces.
- **Client-Side Filtering & No Refresh:** Data goes stale because tabs don't re-poll naturally (cl_usms_tab.lua), while LOGS tries to poll everything ever recorded, destroying network efficiency (cl_log_panel.lua).
- **Silent Feedback & "Always On" Buttons:** A user clicks a button (like "Gear Up" or "Create Squad") that shouldn't actually be clickable for them, which sends a network request that silently fails or gives a tiny console print (sv_usms.lua).

### The Excel Replacement Test
- **What USMS does better:** Real-time persistence. It enforces loadout distribution based on class assigned, surviving server restarts and crash states. No "Wait, did you update the sheet?" arguments.
- **What Excel does better:** Bulk modifications. An XO in Excel can highlight 5 users and assign them a class in 2 seconds. In USMS, it requires 15 distinct clicks through deep sub-menus. Excel is also far better at visually depicting Squad breakdowns at a glance using simple spaced columns.
- **Minimum Viable Feature Set (MVFS):** Roster listing, Squad grouping, and Class-bound loadout enforcement. 
- **Does it meet that bar?:** Yes, theoretically. The data logic is solid. But practically, it has completely diluted its core value with pseudo-gameplay elements (Missions, Intel, elaborate Commendation revocation paths) while leaving bulk-management features entirely undeveloped.
