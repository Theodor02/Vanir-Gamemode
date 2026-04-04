# USMS Fix Plan
**Written:** 2026-04-04  
**Scope:** Implements every item from the ITEMS TO FIX section of USMS_AUDIT_V2.md.  
Commendation/service record systems are intentionally excluded per design decision.

---

## Priority Order (High → Low)

---

### [CRITICAL] Item 1 — nil-index crash in GetUnitData() ✅ COMPLETED
**File:** `libs/sh_usms.lua:262`  
**Problem:** `clientData.intelUnits` was removed but the nil-index on line 262 was not; crashes any call that reaches the second branch.  
**Fix:** Remove the entire `intelUnits` branch (lines 262–264). Return nil directly after the first check.  
**Risk:** LOW — isolated client-only accessor, single line removal.

---

### [HIGH] Item 2 — Dead server-side graveyard cleanup ✅ COMPLETED
**Files:** `libs/sv_networking.lua`, `libs/sv_requests.lua`, `libs/sh_usms.lua`, `libs/sv_database.lua`, `cl_plugin.lua`  
**Problem:** Intel/mission/commendation systems had UI deleted but all server infrastructure (net strings, request handlers, cache tables, DB alloc functions) remains as dead weight.  
**Fix:** Remove each dead block in a single coordinated pass (details below per file).  
**Risk:** HIGH — touches networking and persistence; no live code paths depend on these after removal.

#### sv_networking.lua — remove net string declarations:
- `ixUSMSIntelSync` (line 15)
- `ixUSMSMissionSync` (line 19)
- `ixUSMSMissionUpdate` (line 20)
- `ixUSMSServiceRecord` (line 21)
- `ixUSMSSquadUpdate` (line 13, declared but never sent)

#### sv_requests.lua — remove request handlers:
- `intel_roster_request` entire handler block (lines 452–475)

#### sh_usms.lua — remove constants and cache declarations:
- `USMS_LOG_MISSION_CREATED/COMPLETED/CANCELLED` (lines 39–41)
- `USMS_LOG_COMMENDATION_AWARDED/REVOKED` (lines 42–43)
- `USMS_MISSION_*` constants (lines 45–53)
- `USMS_COMMENDATION_*` constants (lines 55–58)
- `ix.usms.missions` and `ix.usms.commendations` cache declarations (lines 71–72)
- `ix.usms.nextMissionID` and `ix.usms.nextCommendationID` declarations (lines 77–78)

#### sv_database.lua — remove mission/commendation persistence:
- First-boot block: remove `ix.usms.missions = {}`, `ix.usms.commendations = {}`, `ix.usms.nextMissionID = 1`, `ix.usms.nextCommendationID = 1` (lines 22–27)
- Load block: remove missions/commendations/nextMissionID/nextCommendationID restore sections (lines 62–77)
- Load print: remove "missions" and "commendations" from the print statement (line 102–107)
- ForceSave block: remove `missions`, `commendations`, `nextMissionID`, `nextCommendationID` from saved data (lines 134–141)
- Remove `AllocMissionID()` and `AllocCommendationID()` functions (lines 163–177)

#### cl_plugin.lua — remove dead net receiver:
- Remove entire `net.Receive("ixUSMSServiceRecord", ...)` block (lines 164–179)

---

### [HIGH] Item 3 — XO squad invite permission fix ✅ COMPLETED
**File:** `libs/sv_requests.lua` (and `derma/cl_unit_roster.lua` for UI to match)  
**Problem:** The `squad_invite` handler only allows invites from players with `USMS_SQUAD_INVITER` role in a squad; unit XO/CO who aren't personally in a squad are blocked.  
**Fix (server):** Add officer bypass before squad role check: allow if superadmin OR unit role >= USMS_ROLE_XO; officer uses `data.squadID` to identify the target squad (validated to belong to officer's unit). Squad member path uses `sm.squadID` as before.  
**Fix (client):** In `cl_unit_roster.lua`, change the "Invite to Squad" condition to also allow `isOfficer`. When officer is not in a squad, show a submenu of unit squads (from `ix.usms.clientData.squads`) and include the selected squadID in the request. When officer is in a squad, existing behavior unchanged.  
**Risk:** HIGH — touches networking (request payload adds optional squadID field).

---

### [HIGH] Item 4 — GEAR UP button visibility ✅ COMPLETED
**File:** `derma/cl_loadout_panel.lua:283`  
**Problem:** `gearUpBtn` is enabled/disabled based on the *selected* class's loadout, but the server uses `char:GetClass()` (assigned class); a player with no assigned class who browses to a class with items sees GEAR UP enabled but it errors on click.  
**Fix:** Replace `SetEnabled` with `SetVisible`. Base visibility on the player's *assigned* class (currentClass / char:GetClass()): visible only when `currentClass > 0` and that class has a non-empty loadout. USMSRosterUpdated hook already triggers RebuildClasses → RebuildDetail, so re-evaluation is automatic.  
**Risk:** MEDIUM — touches shared loadout panel logic.

---

### [MEDIUM] Item 5 — SyncRosterUpdateToUnit classWhitelist privacy leak ✅ COMPLETED
**File:** `libs/sv_networking.lua`  
**Problem:** `SyncRosterUpdateToUnit` builds a single data payload with the full `classWhitelist` and broadcasts it to all online unit members; the per-recipient filter only exists in `SendRoster`.  
**Fix:** In the recipient loop of `SyncRosterUpdateToUnit`, build the net message per-recipient: strip `classWhitelist` from the data for recipients who are neither the target character nor a unit officer. Send individually (not batch) with `net.Send(ply)` per recipient.  
**Risk:** MEDIUM — touches networking, changes from broadcast to per-recipient send.

---

### [MEDIUM] Item 6 — Dead OpenSquadInvitePicker function ✅ COMPLETED
**File:** `derma/cl_squad_panel.lua:619–677`  
**Problem:** `PANEL:OpenSquadInvitePicker` is defined but never called; the invite button that called it was removed during the refactor.  
**Fix:** Delete the entire function (lines 619–677).  
**Risk:** LOW — dead code removal, no callers.

---

### [MEDIUM] Item 7 — Dead catalog reference in loadout panel ✅ COMPLETED
**File:** `derma/cl_loadout_panel.lua:326–344`  
**Problem:** `ix.usms.catalogs.global` (sh_catalogs.lua) was deleted; the string-format loadout path silently fails on a nil table index.  
**Fix:** Remove the catalog lookup block. For string-format loadout items, log a warning and skip instead of attempting a nil-table lookup. Only inline table format is supported.  
**Risk:** LOW — removes a dead code path, item.list lookup for name/description is preserved.

---

### [MEDIUM] Item 8 — USMS_LOG_UNIT_JOIN undefined constant ✅ COMPLETED
**File:** `commands/sh_testing.lua:182`  
**Problem:** `USMS_LOG_UNIT_JOIN` does not exist; the correct constant is `USMS_LOG_UNIT_MEMBER_JOIN`.  
**Fix:** Replace `USMS_LOG_UNIT_JOIN` with `USMS_LOG_UNIT_MEMBER_JOIN` on that line.  
**Risk:** LOW — single identifier replacement in test/dev command.

---

### [MEDIUM] Item 9 — LOGS tab visible but non-functional for non-officers ✅ COMPLETED
**File:** `derma/cl_usms_tab.lua`  
**Problem:** Non-officer players see the LOGS tab button but the server returns nothing for them, producing a confusing empty state.  
**Fix:** Add `RefreshTabVisibility()` method that hides the "logs" tab button when the player's unit role is below USMS_ROLE_XO (checked via `char:IsUnitOfficer()` or IsSuperAdmin). Hook it to `USMSUnitDataUpdated`. Call it once in `Init()` after `CreateTabButtons()`. If the active tab is "logs" and the player loses officer status, switch to "roster". Add `OnRemove` to clean up the hook.  
**Risk:** MEDIUM — touches tab display logic.

---

### [LOW] Item 10 — Log migration fallback fragility ✅ COMPLETED
**File:** `libs/sv_database.lua:79–97`  
**Problem:** Stage-3 log fallback can assign a wrapper object `{logs = {...}}` to `ix.usms.logs` because `istable()` returns true for both flat arrays and wrapper objects.  
**Fix:** After the three-stage fallback block, add explicit shape check: if `istable(ix.usms.logs) and ix.usms.logs.logs`, unwrap to `ix.usms.logs = ix.usms.logs.logs`.  
**Risk:** LOW — defensive guard, no impact on correct data.

---

### [LOW] Item 11 — RefreshSquad() HUD NetVar fallback ✅ COMPLETED
**File:** `derma/cl_unit_overview.lua:231`  
**Problem:** Fallback to `LocalPlayer():GetNetVar("ixSquadName", "")` introduces an implicit dependency on the diegetic HUD system; if absent, returns "" silently creating an incorrect state.  
**Fix:** Remove the NetVar fallback. When `clientData.squads[squadID]` is nil, display "Loading..." as neutral placeholder. Keep `"SQUAD #" .. squadID` as final fallback if name is still empty after the squad data lookup.  
**Risk:** LOW — removes cross-system dependency, display-only change.

---

### [LOW] Item 12 — Transfer CO position in right-click menu ✅ COMPLETED (implemented together with Item 3)
**File:** `derma/cl_unit_roster.lua`  
**Problem:** "Transfer CO" is listed among routine actions with no visual separation, increasing accidental misclick risk.  
**Fix:** Move the Transfer CO `menu:AddOption(...)` block to after all other options, preceded by `menu:AddSpacer()`. New order: Set Role → Remove from Unit → Assign Class → Invite to Squad → Remove from Squad → [Spacer] → Transfer CO.  
**Risk:** LOW — UI ordering change only.

---

## Post-Implementation Verification Checklist

- [ ] Grep plugin dir for: intelUnits, missions, commendations, missionID, commendationID, IntelSync, MissionSync, ServiceRecord, MissionUpdate, SquadUpdate (ixUSMSSquadUpdate declaration)
- [ ] Verify every modified file: matching function/end, if/end pairs
- [ ] Mark each item COMPLETED with deviation note if any
