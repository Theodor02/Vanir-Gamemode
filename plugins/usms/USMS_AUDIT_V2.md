# USMS Verification Audit — Post-Refactor
**Audit Date:** 2026-04-04
**Previous Audit:** USMS_AUDIT.md (2026-04-03)
**Claimed:** All recommendations implemented
**Verdict:** The refactor completed roughly two-thirds of Phase 1 and a meaningful chunk of Phase 2, but left the server-side graveyard of cut systems intact, introduced a nil-index crash in a shared utility function, and silently destroyed the commendation/service record UI with no replacement path.

---

## Section 1: Refactor Scorecard

| Category           | Original | Claimed | Actual | Δ     |
|--------------------|----------|---------|--------|-------|
| Feature cohesion   | D        | B       | C+     | +1.5  |
| UI usability       | C        | B       | B-     | +1    |
| Architecture       | C        | B+      | B-     | +1    |
| Network efficiency | C-       | B       | B-     | +1.5  |
| Persistence        | C        | B       | B      | +2    |
| Code organisation  | D        | B       | B-     | +1.5  |
| Gameplay value     | D+       | C+      | D+     | 0     |

**Notes on grading:**

- **Feature cohesion C+** not B: Intel/mission/commendation UIs are cut but server-side persistence, net strings, and request handlers for these systems remain as dead weight. The system is less coherent than it appears on the UI surface.
- **UI usability B-** not B: Most major friction points fixed (left-click, tabs, button gating). Right-click menu still has 6 items vs the recommended 5. The service record is now completely inaccessible, which is an overcut.
- **Architecture B-** not B+: The file split is genuine and well-executed. Dirty-flag throttling is correctly implemented. The nil-reference regression in `sh_usms.lua:GetUnitData` and the incomplete server-side cleanup of cut systems prevent a full B+.
- **Network efficiency B-** not B: Log pagination is real now. FullSyncToUnit throttling works. `SyncRosterUpdateToUnit` still leaks classWhitelist to all recipients (fixed in `SendRoster` but not here). `ixUSMSSquadUpdate` net string still declared and never sent.
- **Persistence B**: Dirty-flag debouncing works. Log separation is clean and the migration fallback handles old data. This is the strongest area of the refactor.
- **Code organisation B-** not B: The split is mechanically correct. `sh_usms.lua:GetUnitData` has a dead intel reference that would crash. `sh_testing.lua` references `USMS_LOG_UNIT_JOIN` which does not exist.
- **Gameplay value D+** unchanged: Missions and commendations were cut from the UI without any replacement hook or notification. Resources still have no income mechanism. The system is still a roster tool with decorative resource tracking.

---

## Section 2: Issue-by-Issue Verification

### UI Issues

---

**Issue: 7-tab cognitive overload**
STATUS: RESOLVED
EVIDENCE: `cl_usms_tab.lua:75` — `local tabs = {"roster", "squads", "loadout", "logs"}`. Four tabs. MISSIONS, INTEL, and INFO are gone.

---

**Issue: Roster data not refreshed on tab-activate**
STATUS: RESOLVED
EVIDENCE: `cl_usms_tab.lua:122-125` — `SetActiveTab` sends `roster_request` when switching to "roster" or "squads" tabs.

---

**Issue: Tab button widths hardcoded at Scale(100)**
STATUS: RESOLVED
EVIDENCE: `cl_usms_tab.lua:84` — buttons now `Scale(120)` and there are only 4 tabs, eliminating overflow risk.

---

**Issue: Sidebar takes 25% width across all tabs including LOGS**
STATUS: RESOLVED
EVIDENCE: `cl_usms_tab.lua:116-119` — sidebar is hidden unless `tabName == "roster" or tabName == "squads"`.

---

**Issue: Sidebar LOADOUT section shows same info as LOADOUT tab**
STATUS: RESOLVED
EVIDENCE: `cl_unit_overview.lua` — `CreateLoadoutSection` call is gone entirely. Only UNIT STATUS and SQUAD sections remain.

---

**Issue: `maxSize = 8` hardcoded in cl_unit_overview.lua**
STATUS: RESOLVED
EVIDENCE: `cl_unit_overview.lua:255` — `local maxSize = ix.config.Get("usmsSquadMaxSize", USMS_SQUAD_MAX_SIZE or 8)`.

---

**Issue: `RefreshSquad()` falls back to `GetNetVar("ixSquadName", "")` HUD dependency**
STATUS: PARTIAL
EVIDENCE: `cl_unit_overview.lua:231` — the fallback is still present:
```lua
else
    name = LocalPlayer():GetNetVar("ixSquadName", "")
end
```
The primary path now reads from `clientData.squads[squadID]` correctly, but the implicit dependency on the diegetic HUD's NetVar persists as a fallback for the case where squad metadata hasn't synced yet. The architectural dependency is still there.

---

**Issue: Left-click on roster row opens service record popup**
STATUS: RESOLVED
EVIDENCE: `cl_unit_roster.lua:579-582` — `OnMousePressed` returns immediately on `MOUSE_LEFT` with no action.

---

**Issue: Right-click menu has 9+ options, 2-level submenus, no visual grouping**
STATUS: PARTIAL
EVIDENCE: `cl_unit_roster.lua:602-666` — menu has been trimmed to 6 options: Set Role (submenu), Remove from Unit, Transfer CO, Assign Class (submenu), Invite to Squad, Remove from Squad. Down from 9+ but still exceeds the audit's recommended maximum of 5. The "Manage Class Whitelist" submenu is gone (moved to LOADOUT tab). No visual separator between dangerous (Remove, Transfer CO) and routine actions.

---

**Issue: JOINED column occupies 20% of width for a rarely-needed date**
STATUS: RESOLVED
EVIDENCE: `cl_unit_roster.lua:171-176` — column definitions are now NAME (40%), ROLE (15%), CLASS (20%), SQUAD (15%), STATUS (10%). No JOINED column.

---

**Issue: `BuildSquadData()` re-derives squad data from roster for the third time**
STATUS: RESOLVED
EVIDENCE: `cl_squad_panel.lua:198-247` — `BuildSquadData()` now reads squad metadata from `ix.usms.clientData.squads` (populated by the dedicated `ixUSMSSquadSync` message). It still iterates roster for member assignment, but squad name/description come from the authoritative sync, not re-derived.

---

**Issue: CREATE SQUAD and LEAVE SQUAD always visible regardless of permissions**
STATUS: RESOLVED
EVIDENCE: `cl_squad_panel.lua:258-265`:
```lua
if (IsValid(self.leaveBtn)) then
    self.leaveBtn:SetVisible(inSquad)
end
if (IsValid(self.createBtn)) then
    local canCreate = isOfficer
    self.createBtn:SetVisible(canCreate and not inSquad)
end
```
Buttons are hidden, not merely disabled, when the action is not applicable.

---

**Issue: Duplicate invite paths — squad detail panel INVITE and roster right-click**
STATUS: PARTIAL
EVIDENCE: `cl_squad_panel.lua:383-411` — the detail action bar is cleared with comment "Action buttons removed." The INVITE button is gone from the detail view. However, `PANEL:OpenSquadInvitePicker` (line 619–677) is still defined in the file and is never called from anywhere. This is dead code that was not pruned.

---

**Issue: Duplicate DISBAND button in squad detail AND card right-click**
STATUS: RESOLVED
EVIDENCE: `cl_squad_panel.lua:383-411` — the detail action bar is entirely empty. Disband actions live exclusively in `OpenSquadCardMenu` (line 337).

---

**Issue: `USMSSquadDataUpdated` dead hook (never fired)**
STATUS: RESOLVED
EVIDENCE: `cl_squad_panel.lua:158-165` — the hook is now `USMSSquadsUpdated`, which is fired by `cl_plugin.lua:100` when the dedicated squad sync message arrives. The hook is live, not dead.

---

**Issue: Log requests bypass server-side pagination (9999 entries)**
STATUS: RESOLVED
EVIDENCE: `cl_log_panel.lua:342-354` — `RequestLogs()` sends `{page = self.currentPage, limit = self.pageSize}` where `self.pageSize = 50`. The server's `log_request` handler (`sv_requests.lua:486-487`) enforces `math.Clamp(limit, 1, 500)`.

---

**Issue: `class_whitelist` missing from `LOG_ACTION_LABELS`**
STATUS: RESOLVED
EVIDENCE: `cl_log_panel.lua:23` — `class_whitelist = "Class Whitelist"` is present. Color defined at line 42.

---

**Issue: GEAR UP and CHANGE CLASS buttons always enabled**
STATUS: PARTIAL
EVIDENCE: `cl_loadout_panel.lua:259-283`:
```lua
self.changeClassBtn:SetEnabled(self.selectedClassKey != currentClass)
self.gearUpBtn:SetEnabled(istable(loadout) and #loadout > 0)
```
CHANGE CLASS is correctly disabled when selected class equals current class. However, `gearUpBtn` disabling is based on the *selected class's* loadout having items — but `gearup` on the server uses `char:GetClass()` (the currently assigned class), not the selected class. A player with no class assigned who selects a class with items will see GEAR UP enabled; clicking it will produce the server error "No class assigned." The guard does not match the server-side logic.

---

**Issue: `GetAvailableClasses()` reads whitelist by iterating roster**
STATUS: RESOLVED
EVIDENCE: `cl_loadout_panel.lua:157-158` — now reads from `ix.usms.clientData.myWhitelist`, a dedicated field cached during roster sync in `cl_plugin.lua:69-75`.

---

**Issue: No feedback in UI when gear-up succeeds**
STATUS: UNTOUCHED
EVIDENCE: `sv_requests.lua:417-425` — the server still sends `ply:Notify("Geared up! Cost: " .. cost .. " resources.")`. The loadout panel updates via `USMSRosterUpdated` hook but this only fires after the network round-trip, producing visible latency in the checkmark update.

---

**Issue: Dual-format loadout support (catalog string vs inline table)**
STATUS: UNTOUCHED
EVIDENCE: `cl_loadout_panel.lua:319-343` — both code paths remain. The string lookup against `ix.usms.catalogs.global` is still present even though `sh_catalogs.lua` was deleted. This reference is now a dead reference to a nil table.

---

**Issue: Service record: opened by left-clicking roster row**
STATUS: RESOLVED (by deletion)
EVIDENCE: No `cl_service_record.lua` in the derma folder. The service record panel no longer exists. However, "View Service Record" was not added to the right-click menu as the audit recommended. The commendation/RP record system is now entirely inaccessible in-game.

---

**Issue: Service record: inherits DFrame, draws own title, fights framework**
STATUS: RESOLVED (by deletion)

---

**Issue: Service record: no timeout on loading state**
STATUS: RESOLVED (by deletion)

---

**Issue: Service record: OpenAwardDialog stacking**
STATUS: RESOLVED (by deletion)

---

**Issue: Service record: timer-based re-request on revoke instead of server push**
STATUS: RESOLVED (by deletion — though the feature was removed, not fixed)

---

**Issue: Mission system: Create dialog uses SetPos absolute positioning**
STATUS: RESOLVED (by deletion — cl_mission_panel.lua removed)

---

**Issue: Mission system: "Assign To" dropdown encoding fragile**
STATUS: RESOLVED (by deletion)

---

**Issue: Mission system: completed missions never pruned**
STATUS: UNRESOLVED — server-side missions still accumulate in `ix.usms.missions` with no pruning, even though the UI is gone. `sv_database.lua:65-75` loads and saves missions on every cycle. Dead data.

---

**Issue: Mission system: no gameplay tie-in**
STATUS: RESOLVED (by deletion of UI, which removes the confusion, but the data model persists)

---

**Issue: Intel panel: 20 net requests on open for 2 data points**
STATUS: PARTIAL
EVIDENCE: `cl_intel_panel.lua` — deleted. However, `sv_requests.lua:452-475` — the `intel_roster_request` handler still exists and still sends `ixUSMSIntelSync`. `sv_networking.lua:15` — `ixUSMSIntelSync` still declared. The client-side spam is gone, the server-side handler is orphaned dead code.

---

**Issue: `canViewAllRosters` faction flag undefined in plugin**
STATUS: PARTIAL
EVIDENCE: `sv_requests.lua:458` — `hook.Run("USMSCanViewIntel", ply, char, targetUnitID)` still present inside the still-present `intel_roster_request` handler. Still no default implementation of `USMSCanViewIntel` in the plugin.

---

**Issue: Intel panel: tab should be cut**
STATUS: PARTIAL (see above — UI cut, server not cleaned up)

---

**Issue: `cl_help_panel.lua` — INFO tab should be cut**
STATUS: RESOLVED
EVIDENCE: No `cl_help_panel.lua` in derma folder. Tab list in `cl_usms_tab.lua:75` does not include "info".

---

### Architecture Issues

---

**Issue: `sv_usms.lua` — 2,590-line monolith**
STATUS: RESOLVED
EVIDENCE: `libs/sv_usms.lua.old` exists as the old file. Current split:
- `sv_networking.lua` — net strings, sync functions, dirty-flush timer
- `sv_units.lua` — unit CRUD, member management, HasPermission
- `sv_squads.lua` — squad CRUD, leader vacancy handling
- `sv_resources.lua` — resource get/set/add/deduct
- `sv_loadout.lua` — class change, gear-up
- `sv_invites.lua` — pending invite system
- `sv_requests.lua` — all request handlers
- `sv_database.lua` — persistence layer
- `sv_logging.lua` — log append/fetch

The split matches the proposed structure from the original audit almost exactly. No sv_missions.lua or sv_commendations.lua because those systems had no server logic remaining to house.

---

**Issue: `clientData.squads` derived from roster in three places**
STATUS: RESOLVED
EVIDENCE: `cl_plugin.lua:84-101` — dedicated `ixUSMSSquadSync` receiver populates `clientData.squads` directly. `cl_plugin.lua` no longer derives squad data from the roster. `sv_networking.lua:85-109` — `SendSquads()` sends squad metadata separately.

---

**Issue: `classWhitelist` sent to every unit member in roster payload (privacy)**
STATUS: PARTIAL
EVIDENCE: `sv_networking.lua:163-167` — `SendRoster` now checks per recipient:
```lua
if (targetChar and (targetChar:GetID() == charID or ix.usms.HasPermission(ply, targetChar, USMS_ROLE_XO))) then
    entry.classWhitelist = member.classWhitelist or {}
end
```
However, `sv_networking.lua:234` — `SyncRosterUpdateToUnit` still includes `data.classWhitelist = member.classWhitelist or {}` unconditionally, broadcasting whitelist data to all online unit members on every delta update. The fix was applied to only one of the two roster broadcast paths.

---

**Issue: Roster entry carries squadName and squadDescription**
STATUS: RESOLVED
EVIDENCE: `sv_networking.lua:190-196` — roster entry carries only `squadID` and `squadRole`. Squad name/description are synced via `SendSquads`. The comment at line 195 confirms the intent: "Name and description are synced independently via SendSquads".

---

**Issue: Verbose IsSuperAdmin permission pattern, no utility function**
STATUS: RESOLVED
EVIDENCE: `sv_units.lua:1-6` — `ix.usms.HasPermission(ply, char, requiredRole)` is defined and used throughout `sv_requests.lua`.

---

**Issue: `squad_invite` handler: unit XO not in squad cannot invite**
STATUS: UNTOUCHED
EVIDENCE: `sv_requests.lua:55-57`:
```lua
local sm = ix.usms.squadMembers[char:GetID()]
if (!ply:IsSuperAdmin() and (!sm or sm.role < USMS_SQUAD_INVITER)) then
```
A unit XO who is not in any squad still cannot send squad invites. The `squad_force_add` path (line 274) correctly checks unit officer role, but the standard invite path does not. This was explicitly called out in the original audit and was not fixed.

---

**Issue: `FullSyncToUnit` called after every single squad operation**
STATUS: RESOLVED
EVIDENCE: `sv_networking.lua:43-60` — `FullSyncToUnit(unitID)` now marks a dirty flag. A 150ms debounce timer flushes all dirty units once per tick:
```lua
timer.Create("ixUSMSDirtyFlush", 0.15, 0, function()
    for unitID in pairs(ix.usms._dirtyUnits) do
        ...
    end
    ix.usms._dirtyUnits = {}
end)
```
Rapid consecutive operations (create squad + add two members) produce one broadcast instead of three.

---

**Issue: `db.Save()` called on every mutation, synchronous JSON serialization**
STATUS: RESOLVED
EVIDENCE: `sv_database.lua:120-122` — `db.Save()` marks `_dirty = true`. `sv_database.lua:112-117` — a 10-second timer flushes to disk only when dirty.

---

**Issue: Logs stored in same file as operational data**
STATUS: RESOLVED
EVIDENCE: `sv_database.lua:136` — `ForceSave()` explicitly excludes logs from main data: `-- logs removed from main save file`. Line 144: `ix.data.Set("usms_logs", ix.usms.logs or {}, false, true)` writes logs to a separate file.

---

**Issue: Dead `ixUSMSSquadSync` and `ixUSMSSquadUpdate` net strings**
STATUS: PARTIAL
EVIDENCE: `sv_networking.lua:12-13` — both strings still declared. `ixUSMSSquadSync` is now actively used (the dedicated squad sync). `ixUSMSSquadUpdate` is still declared and still never sent anywhere in the codebase. One resolved, one remains dead.

---

**Issue: Dead request handler `invite_respond`**
STATUS: RESOLVED
EVIDENCE: `sv_requests.lua` — no `ix.usms.requestHandlers["invite_respond"]` entry. Removed.

---

**Issue: `USMSCanSquad` dev command leaks into production**
STATUS: RESOLVED
EVIDENCE: `commands/sh_testing.lua` — no `USMSCanSquad` command. The `ixUSMSCanCreateSquad` NetVar check is also absent from the `USMSCanCreateSquad` hook in `sv_squads.lua:84-95`.

---

**Issue: `USMSAutoAssignUnit` hook returns string → silent fail**
STATUS: UNTOUCHED
EVIDENCE: `sv_plugin.lua:53-54` — `if (isnumber(override) and ix.usms.units[override]) then` — still only accepts numeric returns.

---

**Issue: HUD sync timer is polling instead of event-driven**
STATUS: UNTOUCHED
EVIDENCE: `sv_plugin.lua:217-226` — timer still polls all squads every 3 seconds.

---

**Issue: `squad_force_add` log call: actor and target charIDs swapped**
STATUS: RESOLVED
EVIDENCE: `sv_requests.lua:336` — `ix.usms.Log(squad.unitID, USMS_LOG_SQUAD_MEMBER_JOIN, char:GetID(), targetCharID, ...)` — actor is `char:GetID()` (the officer), target is `targetCharID` (the person being added). Correct order.

---

**Issue: Resource system — no income mechanism, admin-only fills**
STATUS: UNTOUCHED
EVIDENCE: `sh_admin.lua:47-75` — `UnitSetResources` and `UnitAddResources` are still the only resource input paths. Both require admin rank. No CO-accessible resupply request and no passive income timer. Gameplay value unchanged.

---

### User Journey Friction Points

---

**Issue: Auto-assignment is silent — no notification to new recruit**
STATUS: UNTOUCHED
EVIDENCE: `sv_plugin.lua:33-80` — `AutoAssignToFactionUnit` still does not send any notification to the player being assigned.

---

**Issue: INTEL, MISSIONS, LOGS tabs useless to recruit**
STATUS: RESOLVED
EVIDENCE: INTEL and MISSIONS tabs removed entirely. LOGS tab still exists but is gated — it is only visible to all roles but the request handler checks officer rank server-side. Minor: non-officers can still see the LOGS tab and try to open it, which will silently return nothing.

---

**Issue: `FullSyncToUnit` broadcast on every squad mutation**
STATUS: RESOLVED (see debounce, above)

---

**Issue: Log panel pulls 9999 entries**
STATUS: RESOLVED (see pagination, above)

---

**Issue: Whitelist management buried in right-click sub-sub-menu**
STATUS: RESOLVED
EVIDENCE: `cl_loadout_panel.lua:89-94, 441-475` — "MANAGE WHITELIST" button in the action row of the LOADOUT tab, visible only to officers. The right-click roster menu no longer has "Manage Class Whitelist".

---

**Issue: CO Transfer buried next to routine actions**
STATUS: PARTIAL
EVIDENCE: `cl_unit_roster.lua:631-637` — Transfer CO is still in the right-click menu among other options. A confirmation dialog was added (`Derma_Query`). The position is better (listed after Remove from Unit, visually adjacent to other authority actions) but it is still in the same menu as routine actions like Assign Class.

---

**Issue: No cross-unit admin view**
STATUS: UNTOUCHED
This is a Phase 3 item and was not expected to be addressed, but is confirmed absent.

---

**Issue: Buttons not disabled when action invalid for current user's role**
STATUS: LARGELY RESOLVED
EVIDENCE:
- `cl_unit_roster.lua:81-141` — INVITE PLAYER, EDIT UNIT, REFRESH buttons only rendered for officers
- `cl_squad_panel.lua:258-265` — CREATE/LEAVE buttons hidden based on state and role
- `cl_loadout_panel.lua:259-283` — CHANGE CLASS and GEAR UP disabled correctly for selection state
- Remaining gap: GEAR UP enabled check doesn't match server-side logic (see partial above)

---

**Issue: Equipment catalog — stub with 3 items, dual-format complexity**
STATUS: PARTIALLY RESOLVED
EVIDENCE: `sh_catalogs.lua` — deleted from the plugin directory. However, `cl_loadout_panel.lua:329` still references `ix.usms.catalogs.global`, which is now nil (the file that would populate it was deleted). This means the string-format loadout path silently fails on catalog lookup without error but also without cost or name data.

---

**Issue: Intel panel cut-worthy**
STATUS: RESOLVED (UI cut, server dead code remains — see above)

---

## Section 3: New Issues Introduced by the Refactor

---

**NEW ISSUE 1 — nil-index crash in `GetUnitData()`**
File: `libs/sh_usms.lua:262`
```lua
if (ix.usms.clientData and ix.usms.clientData.intelUnits[unitID]) then
```
`clientData.intelUnits` was removed when the intel system was cut, but this reference was not cleaned up. `clientData` in `cl_plugin.lua:4-9` initialises only `{unit, roster, squads, logs}`. Calling `ix.usms.GetUnitData(id)` for any unit that isn't the player's own unit will throw:
```
attempt to index a nil value (field 'intelUnits')
```
This is called by `charMeta:GetUnit()` in `meta/sh_character.lua:60` on the client side, making it a latent crash in any schema code that calls `char:GetUnit()` for a character whose unit isn't the local player's.
Severity: **CRITICAL** — can crash clients silently in any schema using the character meta
Cause: Direct consequence of cutting the intel system without auditing all references to `clientData.intelUnits`

---

**NEW ISSUE 2 — `USMS_LOG_UNIT_JOIN` undefined constant in testing command**
File: `commands/sh_testing.lua:182`
```lua
ix.usms.Log(unitID, USMS_LOG_UNIT_JOIN, fakeCharID, 0, {...})
```
`USMS_LOG_UNIT_JOIN` is not defined in `sh_usms.lua`. The correct constant is `USMS_LOG_UNIT_MEMBER_JOIN`. In Lua, referencing an undefined global evaluates to `nil`. Every mock log entry created by `USMSMockData` will have `action = nil`, which will not match any label in `LOG_ACTION_LABELS` and will appear as "nil" in the log viewer.
Severity: **MINOR** — only affects development/testing command, not production
Cause: Constant renamed during refactor, reference not updated

---

**NEW ISSUE 3 — Dead function `OpenSquadInvitePicker` in cl_squad_panel.lua**
File: `derma/cl_squad_panel.lua:619-677`
`PANEL:OpenSquadInvitePicker` is defined (60 lines) but not called anywhere in the panel. The INVITE button in the detail action bar was removed during the refactor, but this method was not removed.
Severity: **MINOR** — dead code, no functional impact
Cause: Partial cleanup when removing the invite button from the detail panel

---

**NEW ISSUE 4 — Log migration fallback in `sv_database.lua` is fragile**
File: `libs/sv_database.lua:79-97`
The log loading code has a three-stage fallback:
1. Check `data.logs` (old format — logs in main file)
2. Check `ix.data.Get("usms_logs").logs` (new format — separate file, wrapped)
3. Check `ix.data.Get("usms_logs")` directly (flat array)

This is the correct approach for migrating from old to new format, but stage 3 assigns the result of `ix.data.Get` directly to `ix.usms.logs` without checking if the raw return value is a table with a `.logs` field versus a flat array. If the data file contains a bare table (not wrapped), this works. If it's somehow in the wrapped format, stages 2 and 3 both fire, with stage 3 overwriting stage 2's result with the wrapper object. The code then checks `if (!istable(ix.usms.logs))` but a wrapper object `{logs = {...}}` would pass the `istable` check while being the wrong shape.
Severity: **MAJOR** on a server migrating from old data; **MINOR** on a fresh install
Cause: Log separation was added by the refactor without a clean migration path

---

**NEW ISSUE 5 — Service record entirely inaccessible (overcut)**
The commendation/service record system's UI was deleted entirely. There is no "View Service Record" entry in the roster right-click menu (the audit explicitly recommended adding this). The server-side handler `ixUSMSServiceRecord` net message is still declared in `sv_networking.lua:21`, but there is no corresponding `net.Receive` in `cl_plugin.lua` and no UI panel to display it. Any RP server that previously used commendations has lost all access to that data via the UI.
Severity: **MAJOR** — removes a working RP feature with no replacement
Cause: The refactor deleted the panel without providing an alternate access path

---

**NEW ISSUE 6 — `SyncRosterUpdateToUnit` sends classWhitelist to all members**
File: `libs/sv_networking.lua:234`
```lua
data.classWhitelist = member.classWhitelist or {}
```
The privacy fix in `SendRoster` (lines 163-167) filters whitelist data per recipient. `SyncRosterUpdateToUnit` — the delta update path — does not apply the same filter, broadcasting the complete whitelist array to every online unit member on every role change, class change, or squad update. The full-sync path is fixed; the delta path is not.
Severity: **MINOR** (data privacy) but **inconsistent**

---

## Section 4: User Journey Re-evaluation

### 1. The New Recruit

**What improved:**
- 4 tabs instead of 7. The recruit sees ROSTER, SQUADS, LOADOUT, LOGS — three of which are immediately relevant.
- GEAR UP button now correctly disabled when no class is selected in the loadout panel (though not when the player has no class assigned — see GEAR UP issue above).
- Auto-assignment still silent, but the menu structure is less overwhelming.

**What remains broken:**
- Auto-assignment is entirely silent. No notification, no instruction, no welcome context.
- GEAR UP can still produce a server error ("No class assigned") if the button is enabled based on the selected class's loadout while the current class differs.
- The LOGS tab is visible but non-functional for non-officers (server silently returns nothing).

**New friction:**
- None significant.

**Pain Point Summary:**
- (HIGH) Silent auto-assignment
- (MEDIUM) GEAR UP enabled state doesn't match server logic
- (LOW) LOGS tab visible but shows nothing for recruits

---

### 2. The Regular Member

**What improved:**
- Left-click on roster row no longer opens an unwanted popup. This was the single most disruptive issue for this user.
- Fewer tabs mean less confusion about where to look.
- CREATE SQUAD button is hidden if the member can't create squads (vs. previously visible and silently failing).
- LEAVE SQUAD button only shown when in a squad.

**What remains broken:**
- USMS has no commendations UI. A member who received awards can no longer view them at all.

**New friction:**
- None significant.

**Pain Point Summary:**
- (LOW) No service record access anywhere in UI

---

### 3. The Squad Leader

**What improved:**
- Squad detail panel no longer has duplicate disband/invite buttons.
- CREATE SQUAD button is now correctly hidden when already in a squad.
- The LEAVE SQUAD confirmation dialog prevents accidental leaves.

**What remains broken:**
- Cannot invite offline players (unchanged — this was Phase 3).
- Squad creation still triggers FullSyncToUnit (now debounced — network cost is reduced, though still a full sync).

**New friction:**
- Squad invite via the detail panel is gone. The only invite path is the roster right-click → "Invite to Squad". This is a slight UX regression for leaders who worked from the squad panel.

**Pain Point Summary:**
- (MEDIUM) Invite path removed from squad detail panel
- (LOW) Offline pre-assignment still not available

---

### 4. The Unit XO

**What improved:**
- Whitelist management is now in the LOADOUT tab as a dedicated "MANAGE WHITELIST" button, not buried in a right-click submenu.
- Log panel now sends proper pagination (50 per page) instead of dumping 9999 entries on open.
- Roster refreshes when switching to ROSTER tab.
- REFRESH button added to the roster action bar.

**What remains broken:**
- XO still cannot send squad invites if they are not personally in a squad (`sv_requests.lua:55-57`). To invite a member to a squad, the XO must be in that squad or use the roster right-click which also fails for the same reason.
- Stale roster still possible between tab switches until the request completes.
- Service record for members is inaccessible.

**New friction:**
- None significant.

**Pain Point Summary:**
- (HIGH) XO cannot invite to squads unless personally squad-joined
- (MEDIUM) Service record access removed
- (LOW) Log text search only works within current page of server results

---

### 5. The Unit CO

**What improved:**
- Transfer CO still has a confirmation dialog (`Derma_Query`). The dangerous action is slightly better protected.
- EDIT UNIT dialog is in the roster action bar, clearly visible.
- Right-click menu trimmed.

**What remains broken:**
- Resources still require an admin-rank chat command to replenish. COs cannot resupply their own unit.
- Transfer CO is still in the general right-click menu alongside routine actions, not separated.
- EDIT UNIT dialog still only exposes name and description. Resource cap, member cap, and squad cap fields are not in the dialog even though the server handler supports them.

**New friction:**
- None significant.

**Pain Point Summary:**
- (HIGH) No CO-accessible resource resupply
- (MEDIUM) Transfer CO still buried in mixed-priority context menu
- (MEDIUM) EDIT UNIT dialog underexposes available fields

---

### 6. The Multi-Unit Admin

**What improved:**
- Server-side admin commands are clean and well-organised in `sh_admin.lua`.
- `UnitList` command prints unit summary clearly.
- `roster_request` handler allows superadmins to specify any `unitID` (`sv_requests.lua:441-443`), enabling cross-unit roster viewing via console.

**What remains broken:**
- No GUI for cross-unit management. Admin must be in a character on that unit or use console commands.
- Resource management is fully command-line only.

**New friction:**
- None significant.

**Pain Point Summary:**
- (HIGH) No multi-unit admin GUI panel
- (MEDIUM) All resource management requires admin chat commands

---

### 7. The Casual Event Participant

**What improved:**
- 4 tabs instead of 7 — significantly less noise.
- GEAR UP button state is more accurate.
- Can navigate directly to LOADOUT without accidentally opening service records.

**What remains broken:**
- LOGS tab is still visible but silently empty for this user. Could be hidden for non-officers.

**New friction:**
- None significant.

**Pain Point Summary:**
- (LOW) LOGS tab visible but not useful

---

## Section 5: The Excel Replacement Test — Revisited

**Did the refactor improve or worsen the Excel replacement case?**

Improved. The core operations are less painful:
- Whitelist management is now 2 clicks (open LOADOUT → MANAGE WHITELIST) instead of a 3-level right-click chain.
- Roster table is cleaner (NAME column is wider, JOINED removed, STATUS clearly labelled).
- Roster is no longer stale on panel open.

**Is bulk class assignment or bulk whitelist management any easier?**

No. Bulk operations remain entirely absent. An XO still assigns class to each member individually through a right-click submenu → class selection. For a 10-person unit, that's 20+ clicks. Excel still wins on bulk operations.

**Can an XO now do in 5 clicks what took 15 before?**

For whitelist management: previously right-click → Manage Class Whitelist → player submenu → class → checkbox — 5 clicks per member. Now: open LOADOUT → MANAGE WHITELIST (opens a DermaMenu) → player submenu → class → click. Still 5 clicks per member. Net zero change in click count, better discoverability.

For class assignment: right-click → Assign Class → class name. Still 3 clicks per member, no improvement.

**What is still missing to make someone prefer USMS over a spreadsheet?**

- Bulk class assignment ("select 5 members, assign class X to all")
- Offline member class/role changes (apply on login)
- Any visual summary of unit readiness (how many members have each class, who is un-classed)
- A CO-accessible resource top-up
- Service record access (recently removed)

USMS still wins on persistence (survives restarts, enforces loadout) and enforcement (players cannot switch classes freely). But for management operations, Excel is still more efficient.

---

## Section 6: Honest Remaining Work

### Phase 1 — Still unfinished quick wins

**1. Fix `GetUnitData()` nil-index crash** (`sh_usms.lua:262`)
Remove the `clientData.intelUnits` reference or guard it with `and ix.usms.clientData.intelUnits`. This is a one-line fix that prevents a crash for any schema code calling `char:GetUnit()` on the client.

**2. Remove dead `intel_roster_request` handler and net strings** (`sv_requests.lua:452-475`, `sv_networking.lua:15,13`)
The server still registers and handles intel requests for a system whose client was deleted. Remove `intel_roster_request`, `ixUSMSIntelSync`, and the `USMSCanViewIntel` hook reference. Three deletions.

**3. Remove dead `ixUSMSSquadUpdate` net string** (`sv_networking.lua:13`)
Single line removal.

**4. Remove dead `OpenSquadInvitePicker` function** (`cl_squad_panel.lua:619-677`)
Sixty lines of dead code that was left behind when the invite button was removed from the detail panel.

**5. Fix `SyncRosterUpdateToUnit` whitelist leak** (`sv_networking.lua:234`)
Apply the same per-recipient privacy check used in `SendRoster` to delta updates. The fix is one conditional block.

**6. Remove dead mission/commendation persistence infrastructure** (`sv_database.lua:22-27,65-77,131-137`, `sv_networking.lua:19-21`, `sh_usms.lua:46-58`)
Constants, save/load code, and net strings for systems that have no UI and no server handlers remain in the codebase. Clean these up or re-add a minimal UI — dead persistence load without purpose is confusing and wastes save-file space.

**7. Fix USMS_LOG_UNIT_JOIN undefined constant** (`commands/sh_testing.lua:182`)
Change to `USMS_LOG_UNIT_MEMBER_JOIN`. One word change.

**8. Fix GEAR UP button enabled logic** (`cl_loadout_panel.lua:283`)
Check whether the *current class* (not the selected class) has a loadout. The button should represent whether the gear-up action will succeed for the player's actual state, not the browsing state.

**9. Add "View Service Record" to roster right-click menu or re-add the popup**
The service record was deleted without a replacement access path. At minimum, add a right-click option that opens a simplified read-only view of the commendation list. The server handler and data are intact.

**10. Remove dead catalog reference in loadout panel** (`cl_loadout_panel.lua:329`)
`ix.usms.catalogs` no longer exists. The string-format loadout path fails silently. Either remove the catalog path entirely (require inline table format) or restore the catalog with useful content.

---

### Phase 2 — Core rework items that remain

**1. Fix squad_invite for unit XO without squad membership** (`sv_requests.lua:55-57`)
A unit XO who is not personally squad-joined cannot invite members to any squad. Add a unit officer bypass to the `squad_invite` handler matching what `squad_force_add` already has. This prevents the scenario where an XO must join a squad themselves just to be able to invite someone.

**2. Simplify squad roles from 4 to 2** (multiple files)
MEMBER / INVITER / XO / LEADER remains unchanged. The INVITER role is a rarely-used delegation mechanism that adds complexity to permission checks throughout the codebase. Collapsing to MEMBER / LEADER simplifies `squad_set_role`, `squad_kick`, `squad_invite`, the character meta methods, and the UI. This requires coordinated changes across `sh_usms.lua`, `sv_squads.lua`, `sv_requests.lua`, `meta/sh_character.lua`, and both squad panel files.

**3. EDIT UNIT dialog exposes available fields** (`cl_unit_roster.lua:371-462`)
The server handler `unit_edit` (`sv_requests.lua:555-608`) already supports `resourceCap`, `maxMembers`, and `maxSquads` for CO/superadmin. The dialog only presents name and description. Extend the dialog with the CO-accessible fields.

**4. CO-accessible resource resupply**
COs cannot replenish their unit's resources without an admin running a chat command. Add a `unit_request_resupply` request handler that allows the unit CO to add a configurable amount of resources directly, with a per-day or per-event cooldown. This connects the resource system to actual gameplay.

**5. Cleanly separate or remove mission/commendation systems**
The current state (data persists, UI deleted, net strings declared, constants defined) is the worst possible outcome. Either: re-add a minimal UI panel (one tab, read-only commendation list, basic mission log) or fully cut the systems including their persistence, constants, net strings, and database fields.

---

### Phase 3 — Deferred / nice-to-have

**1. Auto-assignment notification to new recruit**
A `ply:Notify` and optional chat message when `AutoAssignToFactionUnit` completes. Makes the first interaction with the system legible to players.

**2. Offline member class/role changes**
Apply class and role changes to cached member data when the character is offline; sync on next login. Requires a "pending changes" queue per charID in the data file.

**3. Bulk class assignment**
A "Batch Assign" button on the LOADOUT whitelist manager that applies a class to all selected roster members at once. Reduces 20 clicks to 3 for a pre-event setup.

**4. Server-side log text search**
The current pagination is server-side for action type and time range, but text search is client-side within a single page. Move the search index server-side so cross-page searches work correctly.

**5. Multi-unit admin overlay**
A superadmin-only panel (separate tab or separate menu entry) that lists all units with member counts, online counts, and resource levels without requiring a character swap. One screen, zero menu navigation.

**6. Event-driven HUD sync instead of polling timer**
Replace the 3-second polling timer in `sv_plugin.lua` with event-driven calls on squad membership changes. Reduces background CPU and network overhead.

---

## Section 7: Overall Verdict

**Did the refactor move the needle or just shuffle deck chairs?**

It moved the needle genuinely on the highest-impact items: the file split is real and clean, the network throttling works, the pagination is real, the left-click trap is fixed, the tab count is down, whitelist management is in the right place, and button gating works on the most visible cases. These are meaningful improvements. The codebase is substantially more maintainable than it was before.

However, the refactor overreached in cutting the commendation/service record UI (losing an RP feature with no replacement) and underreached in cleaning up the server-side graveyard of the cut systems. The `clientData.intelUnits` nil-index crash is the worst single output of the refactor — it was entirely avoidable with a 30-second grep after deleting the intel system.

**What is the single highest-leverage thing to do next?**

Fix the `sh_usms.lua:262` nil-index crash. It is a one-line fix and it is currently a latent runtime error for any schema code that calls `char:GetUnit()` on the client side for a non-local-player unit.

After that: clean up the server-side graveyard (intel handler, dead net strings, mission/commendation persistence) in a single pass. This is 20-30 lines of deletion that improves clarity and eliminates dead execution paths.

**Is the system ready for a live server without embarrassing itself?**

Mostly yes, with caveats. The core loop (join unit → get class → gear up → form squad) works and is now significantly less painful to navigate. The CRITICAL nil-index crash is latent, not immediate — it fires only if a schema calls `GetUnitData()` on a unit other than the player's own. If the schema is simple (one unit per faction, player always in their own unit), this may never trigger. But a more complex schema will hit it.

The dead persistence for missions and commendations is invisible to players but confusing to developers who inherit this codebase.

**Revised one-sentence identity statement:**

USMS is a personnel management and readiness system: it tracks who belongs where, what class they hold, and who leads which squad — with enough infrastructure for commendations and missions, but those features need either a functional UI or a clean removal.
