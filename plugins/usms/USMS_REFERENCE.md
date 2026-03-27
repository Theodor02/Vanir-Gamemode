# USMS Plugin — AI Development Reference

> **Purpose**: This document gives an AI model everything it needs to efficiently edit the USMS (Unit & Squad Management System) plugin without re-reading the entire codebase. Read this first in any new session.

---

## 1. Project Identity

| Key | Value |
|-----|-------|
| **Plugin Path** | `gamemodes/skeleton/plugins/usms/` |
| **Framework** | [Helix](https://github.com/NebulousCloud/helix) — a Garry's Mod roleplay gamemode framework |
| **Language** | Lua (GLua — Garry's Mod Lua, based on Lua 5.1 with GMod extensions) |
| **Author** | Vanir |
| **Theme** | Star Wars military RP — gold accent UI, dark backgrounds |

### GLua Quirks (compared to standard Lua)
- `!` is the NOT operator (equivalent to `not`), `!=` is not-equal (equivalent to `~=`). Both forms are valid.
- `continue` works in loops (not standard Lua).
- `//` is a valid comment prefix (alongside `--`).
- `IsValid(panel)` checks if a VGUI element exists and hasn't been removed.
- Networking uses `net.*` library with explicit type reading/writing.
- `surface.*` and `draw.*` are client-side rendering APIs.

---

## 2. File Map

```
usms/
├── sh_plugin.lua              — Plugin metadata, constants, config, include order
├── sv_plugin.lua              — Server hooks (char load, disconnect, HUD sync timer)
├── cl_plugin.lua              — Client state cache + all net.Receive handlers
├── USMS_REFERENCE.md          — THIS FILE
│
├── meta/
│   └── sh_character.lua       — CharVar definitions + character meta methods
│
├── libs/
│   ├── sh_usms.lua            — Shared utility functions + server cache tables
│   ├── sh_catalogs.lua        — Equipment catalog (items available for gear-up)
│   ├── sv_database.lua        — Persistence (Load/Save/AllocID/PruneLogs)
│   ├── sv_logging.lua         — Log system (in-memory + Helix ix.log)
│   └── sv_usms.lua            — ★ MAIN SERVER FILE (~1800 lines)
│                                 All API functions, net setup, request handlers
│
├── commands/
│   ├── sh_admin.lua           — Admin chat commands (/UnitCreate, /UnitDelete, etc.)
│   └── sh_testing.lua         — Dev/test commands (/USMSDebugState, etc.)
│
└── derma/                     — Client VGUI panels (auto-loaded by Helix)
    ├── cl_usms_tab.lua        — Main container, tab switching (roster/squads/logs/info)
    ├── cl_unit_overview.lua   — Left sidebar (unit info, squad info, loadout)
    ├── cl_unit_roster.lua     — Sortable member table + roster row panel
    ├── cl_squad_panel.lua     — Squad list cards + squad detail view
    ├── cl_log_panel.lua       — Activity log viewer with filters/pagination
    ├── cl_loadout_panel.lua   — Class selector + gear-up UI
    ├── cl_invite_popup.lua    — Slide-in invite notification popup
    └── cl_help_panel.lua      — Role documentation / info tab
```

### Include Order (from sh_plugin.lua)
```lua
ix.util.Include("libs/sh_usms.lua")       -- shared caches + utility
ix.util.Include("libs/sh_catalogs.lua")    -- equipment catalog
ix.util.Include("libs/sv_database.lua")    -- persistence layer
ix.util.Include("libs/sv_logging.lua")     -- logging
ix.util.Include("libs/sv_usms.lua")        -- main server API
ix.util.Include("sv_plugin.lua")           -- server hooks
ix.util.Include("cl_plugin.lua")           -- client net receivers
ix.util.Include("meta/sh_character.lua")   -- char vars + meta
ix.util.Include("commands/sh_admin.lua")
ix.util.Include("commands/sh_testing.lua")
-- derma/ files are auto-loaded by Helix on CLIENT
```

---

## 3. Constants (defined in libs/sh_usms.lua)

```lua
-- Unit roles
USMS_ROLE_MEMBER = 0
USMS_ROLE_XO     = 1
USMS_ROLE_CO     = 2

-- Squad roles
USMS_SQUAD_MEMBER  = 0
USMS_SQUAD_INVITER = 1
USMS_SQUAD_XO      = 2
USMS_SQUAD_LEADER  = 3

-- Log actions
USMS_LOG_UNIT_MEMBER_JOIN     = "unit_member_join"
USMS_LOG_UNIT_MEMBER_LEAVE    = "unit_member_leave"
USMS_LOG_UNIT_MEMBER_KICKED   = "unit_member_kicked"
USMS_LOG_UNIT_ROLE_CHANGED    = "unit_role_changed"
USMS_LOG_UNIT_CLASS_CHANGED   = "unit_class_changed"
USMS_LOG_UNIT_RESOURCE_CHANGE = "unit_resource_change"
USMS_LOG_SQUAD_CREATED        = "squad_created"
USMS_LOG_SQUAD_DISBANDED      = "squad_disbanded"
USMS_LOG_SQUAD_MEMBER_JOIN    = "squad_member_join"
USMS_LOG_SQUAD_MEMBER_LEAVE   = "squad_member_leave"
USMS_LOG_SQUAD_MEMBER_KICKED  = "squad_member_kicked"
USMS_LOG_GEARUP               = "gearup"
USMS_LOG_CLASS_WHITELIST       = "class_whitelist"
```

### Config Keys (ix.config)
| Key | Default | Description |
|-----|---------|-------------|
| `usmsSquadMaxSize` | 8 | Max members per squad |
| `usmsSquadMinSize` | 2 | Min before auto-disband |
| `usmsLogRetentionDays` | 60 | Days to keep logs |
| `usmsHUDSyncInterval` | 3 | Seconds between HUD syncs |

---

## 4. Data Structures

### Server-Side Caches (in `libs/sh_usms.lua`)
```lua
ix.usms.units         = {} -- [unitID]  → unitData
ix.usms.squads        = {} -- [squadID] → squadData
ix.usms.members       = {} -- [charID]  → memberData
ix.usms.squadMembers  = {} -- [charID]  → squadMemberData
ix.usms.pendingInvites = {} -- [targetCharID] → inviteData
```

### Unit
```lua
{ id, name, description, factionID, resources, resourceCap, maxMembers, maxSquads, createdAt, data={} }
```

### Member
```lua
{ unitID, characterID, role, joinedAt, cachedName, cachedClass, cachedClassName, cachedClassUID, cachedLastSeen, classWhitelist={} }
```

### Squad
```lua
{ id, unitID, name, description, leaderCharID, createdAt }
```

### Squad Member
```lua
{ squadID, characterID, role, joinedAt }
```

### Client-Side Cache (`ix.usms.clientData` in `cl_plugin.lua`)
```lua
{
    unit = { id, name, description, factionID, resources, resourceCap, maxMembers, maxSquads },
    roster = { -- array of roster entries:
        { charID, name, role, className, class, squadID, squadName, squadDescription, squadRole, isOnline, joinedAt, lastSeen }
    },
    squads = { -- [squadID] → { name, description, members={roster entries} }
    },
    logs = { -- array of log entries },
    intelUnits = {} -- cross-faction intel
}
```

### Roster Entry (sent from server, used in all client panels)
```lua
{
    charID, role, joinedAt, squadID, squadRole, squadName, squadDescription,
    isOnline, name, class, className, lastSeen, classWhitelist
}
```

---

## 5. Character System (`meta/sh_character.lua`)

### Registered CharVars (auto-persisted to DB)
| Var Name | Getter/Setter | Type | Default |
|----------|---------------|------|---------|
| `usmUnitID` | `char:GetUsmUnitID()` / `char:SetUsmUnitID(n)` | number | 0 |
| `usmUnitRole` | `char:GetUsmUnitRole()` / `char:SetUsmUnitRole(n)` | number | 0 |
| `usmSquadID` | `char:GetUsmSquadID()` / `char:SetUsmSquadID(n)` | number | 0 |
| `usmSquadRole` | `char:GetUsmSquadRole()` / `char:SetUsmSquadRole(n)` | number | 0 |

### Meta Methods (on `character` metatable)
```
:IsUnitCO()      → role == USMS_ROLE_CO
:IsUnitXO()      → role == USMS_ROLE_XO
:IsUnitOfficer() → role >= USMS_ROLE_XO
:IsSquadLeader() → squadRole == USMS_SQUAD_LEADER
:IsSquadXO()     → squadRole == USMS_SQUAD_XO
:IsSquadOfficer()→ squadRole >= USMS_SQUAD_XO
:CanSquadInvite()→ squadRole >= USMS_SQUAD_INVITER
:IsInUnit()      → unitID > 0
:IsInSquad()     → squadID > 0
:GetUnit()       → ix.usms.units[unitID]
:GetSquad()      → ix.usms.squads[squadID]
```

---

## 6. Server API (`libs/sv_usms.lua`)

### Unit CRUD
```
ix.usms.CreateUnit(name, factionID, data, callback)   → creates unit, assigns ID
ix.usms.DeleteUnit(unitID, callback)                   → removes unit + all members/squads
```

### Member Management
```
ix.usms.AddMember(charID, unitID, role, callback)      → validates faction, cap; updates CharVars
ix.usms.RemoveMember(charID, kickerCharID, callback)   → removes from squad first, clears CharVars
ix.usms.SetMemberRole(charID, newRole, callback)       → updates role, syncs
ix.usms.TransferCO(unitID, newCOCharID, callback)      → demotes old CO, promotes new
```

### Squad System
```
ix.usms.CreateSquad(ply, name, callback)               → permission hook, creator=leader
ix.usms.AddToSquad(charID, squadID, callback)           → checks unit match + size cap
ix.usms.RemoveFromSquad(charID, kickerCharID, callback) → handles leader vacancy
ix.usms.DisbandSquad(squadID, disbandedByCharID, cb)    → clears all squad member CharVars
ix.usms.HandleSquadLeaderVacancy(squadID)               → promotes highest rank, or disbands
ix.usms.SetSquadLeader(squadID, newLeaderCharID)
```

### Resources
```
ix.usms.GetResources(unitID) → number
ix.usms.SetResources(unitID, amount, reason, actorCharID)
ix.usms.AddResources(unitID, amount, reason, actorCharID)
ix.usms.DeductResources(unitID, amount, reason, actorCharID) → false if insufficient
```

### Class/Loadout
```
ix.usms.ChangeClass(charID, classIndex, authorizerCharID, callback)
  → persists class by uniqueID; checks whitelist for self-service changes;
    auto-whitelists when an officer assigns a class
ix.usms.GearUp(ply, callback) → checks class, loadout, resources; grants items
ix.usms.GetLoadoutCost(classIndex) → number
ix.usms.GetClassLoadout(classIndex) → table
ix.usms.GetClassIndexByUID(uniqueID, factionID) → classIndex (shared utility in sh_usms.lua)
```

### Networking (Server → Client)
```
ix.usms.SyncUnitToPlayer(ply, unitID)        — full unit data
ix.usms.SyncUnitToAllMembers(unitID)         — unit data to all online members
ix.usms.SyncResourceToUnit(unitID)           — resource update only
ix.usms.SendRoster(ply, unitID)              — compressed JSON roster
ix.usms.SyncRosterUpdateToUnit(unitID, charID, action)  — single entry delta
ix.usms.SyncSquadToHUD(squadID)              — diegetic HUD sync
ix.usms.ClearSquadFromHUD(squadID, unitID)
ix.usms.FullSyncToPlayer(ply)                — unit + roster
ix.usms.FullSyncToUnit(unitID)               — full sync to all online members
```

### Invite System
```
ix.usms.SendInvite(targetCharID, inviteType, inviterCharID, unitID, squadID)
ix.usms.RespondToInvite(ply, accept)
-- Invite expires after 60 seconds
```

---

## 7. Request Handler System

Client sends actions via:
```lua
-- Client:
ix.usms.Request(action, data)
-- Sends net "ixUSMSRequest" with action string + data table

-- Server receives in sv_usms.lua:
net.Receive("ixUSMSRequest", function(len, ply)
    local char = ply:GetCharacter()
    local action = net.ReadString()
    local data = net.ReadTable()
    local handler = ix.usms.requestHandlers[action]
    if handler then handler(ply, char, data) end
end)
```

### All Request Handlers
| Action | Permission | What It Does |
|--------|-----------|--------------|
| `squad_create` | USMSCanCreateSquad hook | Creates squad, caller=leader |
| `squad_invite` | >= SQUAD_INVITER or superadmin | Sends squad invite to target |
| `squad_kick` | >= SQUAD_XO (must outrank target) or superadmin | Kicks from squad |
| `squad_leave` | any squad member | Leave own squad |
| `squad_disband` | SQUAD_LEADER or superadmin | Disband own squad |
| `squad_force_disband` | >= UNIT_XO or superadmin | Force disband any squad in unit |
| `squad_set_role` | SQUAD_LEADER, >= UNIT_XO, or superadmin | Set Member/Inviter/XO |
| `squad_set_description` | SQUAD_LEADER, >= UNIT_XO, or superadmin | Set squad description (max 256 chars) |
| `squad_force_remove` | >= UNIT_XO or superadmin | Force remove anyone from any squad |
| `squad_force_add` | >= UNIT_XO or superadmin | Force add to squad (checks size, unit match) |
| `unit_invite` | >= UNIT_XO or superadmin | Send unit invite |
| `unit_kick` | >= UNIT_XO (must outrank target) or superadmin | Remove from unit |
| `unit_set_role` | >= UNIT_CO or superadmin; CO only for CO assignment (superadmin only) | Set Member/XO/CO |
| `unit_set_class` | >= UNIT_XO or superadmin | Assign class to member (auto-whitelists) |
| `gearup` | any unit member with class | Draws loadout, costs resources |
| `class_change` | any unit member (must be whitelisted or default class) | Self class change |
| `class_whitelist_add` | >= UNIT_XO or superadmin | Whitelist a member for a class |
| `class_whitelist_remove` | >= UNIT_XO or superadmin | Remove class whitelist from a member |
| `roster_request` | any unit member or superadmin | Triggers SendRoster |
| `log_request` | >= UNIT_XO or superadmin | Sends log data |

**Pattern**: Every handler checks `ply:IsSuperAdmin()` as a universal bypass.

---

## 8. Net Messages

| Name | Direction | Purpose |
|------|-----------|---------|
| `ixUSMSUnitSync` | S→C | Full unit data |
| `ixUSMSUnitUpdate` | S→C | Partial unit update (e.g., resources) |
| `ixUSMSRosterSync` | S→C | Full roster (compressed JSON) |
| `ixUSMSRosterUpdate` | S→C | Single roster entry delta |
| `ixUSMSLogSync` | S→C | Log data (compressed JSON) |
| `ixUSMSIntelSync` | S→C | Cross-faction intel |
| `ixUSMSRequest` | C→S | Client action request |
| `ixUSMSInvite` | S→C | Invite notification |
| `ixUSMSInviteResponse` | C→S | Accept/decline invite |

---

## 9. Client Hooks (fired from net receivers in `cl_plugin.lua`)

| Hook | Args | Fired When |
|------|------|------------|
| `USMSUnitDataUpdated` | unitData | Full unit sync received |
| `USMSResourcesUpdated` | unitID, resources, cap | Resource partial update |
| `USMSRosterUpdated` | unitID, roster | Full roster sync |
| `USMSRosterEntryUpdated` | unitID, data | Single entry delta |
| `USMSLogsUpdated` | unitID, logs | Log sync |
| `USMSIntelUpdated` | unitID | Intel sync |
| `USMSSquadDataUpdated` | — | Squad HUD data changed |

### Server-Side Event Hooks
```
USMSUnitCreated(unitID, name, factionID)
USMSUnitDeleted(unitID)
USMSMemberAdded(charID, unitID, role)
USMSMemberRemoved(charID, unitID, kickerCharID)
USMSMemberRoleChanged(charID, unitID, oldRole, newRole)
USMSSquadCreated(squadID, unitID, charID)
USMSSquadDisbanded(squadID, unitID, disbandedByCharID)
USMSSquadMemberAdded(charID, squadID)
USMSSquadMemberRemoved(charID, squadID, kickerCharID)
USMSSquadLeaderChanged(squadID, oldLeaderCharID, newLeaderCharID)
USMSClassChanged(charID, oldClass, classIndex, authorizerCharID)
USMSGearUp(ply, char, grantedItems, totalCost)
USMSResourcesChanged(unitID, oldAmount, newAmount, reason)
```

### Permission Hooks (return false, reason to block)
```
USMSCanCreateSquad(ply, char, member)
USMSCanChangeClass(char, classIndex, authorizerCharID)
USMSCanGearUp(ply, char, neededItems, totalCost)
USMSCanViewIntel(ply, char, targetUnitID)
```

---

## 10. UI Architecture

### Panel Hierarchy
```
"deployment" tab (CreateMenuButtons hook)
└── ixUSMSMainPanel
    ├── ixUSMSUnitOverview (LEFT, 25% width)
    │   ├── Unit Status section (name, faction, resources bar, personnel count)
    │   ├── Squad section (current squad name, role, member count)
    │   └── Loadout section (current class)
    └── Content Area (FILL)
        ├── Tab Bar: ROSTER | SQUADS | LOGS | INFO
        ├── ixUSMSRosterPanel (ROSTER tab)
        │   ├── Search bar
        │   ├── Column headers (sortable: NAME, ROLE, CLASS, SQUAD, STATUS, JOINED)
        │   └── Scroll → ixUSMSRosterRow instances
        ├── ixUSMSSquadPanel (SQUADS tab)
        │   ├── Action bar (CREATE SQUAD, LEAVE SQUAD)
        │   ├── Squad list (35% width, scrollable squad cards)
        │   └── Detail view (FILL)
        │       ├── Squad name + action buttons
        │       ├── Description block (if set)
        │       ├── Loadouts/Specs section
        │       └── Members list with tooltips
        ├── ixUSMSLogPanel (LOGS tab)
        │   ├── Filter dropdown + refresh + pagination
        │   └── Scrollable log entries
        └── ixUSMSHelpPanel (INFO tab)
            └── Scrollable role documentation
```

### Theme Constants (used in all derma files)
```lua
local THEME = {
    background   = Color(10, 10, 10, 255),
    frame        = Color(191, 148, 53, 255),       -- gold border
    frameSoft    = Color(191, 148, 53, 120),        -- soft gold
    text         = Color(235, 235, 235, 255),       -- white text
    textMuted    = Color(168, 168, 168, 140),       -- gray text
    accent       = Color(191, 148, 53, 255),        -- gold accent
    accentSoft   = Color(191, 148, 53, 220),
    buttonBg     = Color(16, 16, 16, 255),
    buttonBgHover= Color(26, 26, 26, 255),
    panelBg      = Color(12, 12, 12, 255),
    danger       = Color(180, 60, 60, 255),
    dangerHover  = Color(200, 80, 80, 255),
    ready        = Color(60, 170, 90, 255),         -- green
    rowEven      = Color(14, 14, 14, 255),
    rowOdd       = Color(18, 18, 18, 255),
    rowHover     = Color(24, 22, 14, 255),
    ownSquadBg   = Color(30, 26, 12, 255),          -- warm highlight
    ownSquadBorder = Color(191, 148, 53, 180),
    supply       = Color(80, 140, 200, 255)         -- blue (help panel)
}

local function Scale(value)
    return math.max(1, math.Round(value * (ScrH() / 900)))
end
```

### Fonts Used
- `ixImpMenuSubtitle` — section headers
- `ixImpMenuButton` — button text, squad names
- `ixImpMenuDiag` — body text, table cells
- `ixImpMenuStatus` — small status text, column headers

### Context Menu Pattern (right-click)
All context menus use `DermaMenu()` with permission-gated options:
```lua
row.OnMousePressed = function(s, code)
    if (code != MOUSE_RIGHT) then return end
    local char = LocalPlayer():GetCharacter()
    -- permission checks...
    local menu = DermaMenu()
    menu:AddOption("Label", function() ix.usms.Request("action", {data}) end):SetIcon("icon16/...")
    local sub = menu:AddSubMenu("Submenu")
    sub:AddOption(...)
    menu:Open()
end
```

### Tooltip Pattern
```lua
row.OnCursorEntered = function(s)
    s.tooltip = CreateTooltipFunction(s.data)
    s.tooltip:SetParent(vgui.GetWorldPanel())
    s.tooltip:SetPos(gui.MousePos() + offset)
end
row.OnCursorExited = function(s)
    if IsValid(s.tooltip) then s.tooltip:Remove() end
end
row.OnRemove = function(s)
    if IsValid(s.tooltip) then s.tooltip:Remove() end
end
```

---

## 11. Key Patterns & Conventions

### Superadmin Bypass
Every permission check follows this pattern:
```lua
if (!ply:IsSuperAdmin() and <normal permission check>) then
    ply:Notify("error message")
    return
end
```

### After Any Mutation
Always call the appropriate sync:
```lua
ix.usms.db.Save()                            -- persist to disk
ix.usms.FullSyncToUnit(unitID)               -- refresh all clients in unit
-- OR for targeted updates:
ix.usms.SyncRosterUpdateToUnit(unitID, charID, "update")
ix.usms.SyncSquadToHUD(squadID)              -- diegetic HUD
```

### Adding a New Request Handler
1. Add handler in `libs/sv_usms.lua`:
   ```lua
   ix.usms.requestHandlers["my_action"] = function(ply, char, data)
       -- 1. Permission check (with superadmin bypass)
       -- 2. Validate input (tonumber, tostring, bounds)
       -- 3. Execute logic
       -- 4. Save: ix.usms.db.Save()
       -- 5. Sync: ix.usms.FullSyncToUnit(unitID)
       -- 6. Notify: ply:Notify("Result message")
   end
   ```
2. Call from client:
   ```lua
   ix.usms.Request("my_action", {key = value})
   ```

### Adding a New Client Panel
1. Create `derma/cl_<name>.lua` (Helix auto-loads `derma/` files)
2. Define `local PANEL = {}`, add methods, register with `vgui.Register("ixUSMSMyPanel", PANEL, "EditablePanel")`
3. Hook into data updates: `hook.Add("USMSRosterUpdated", self, function(s) ... end)`
4. Clean up hooks in `PANEL:OnRemove()`

### Adding a New Data Field
1. **Server cache**: Add field to the creation function (e.g., `CreateSquad`)
2. **Roster sync**: Add field in `SendRoster()` and/or `SyncRosterUpdateToUnit()`
3. **Client extraction**: Update the roster sync handler in `cl_plugin.lua`
4. **UI**: Read from `ix.usms.clientData.roster` or `ix.usms.clientData.squads`

---

## 12. Admin Commands (`commands/sh_admin.lua`)

| Command | Access | Args |
|---------|--------|------|
| `/UnitCreate` | superadmin | `<factionIndex> <name>` |
| `/UnitDelete` | superadmin | `<unitID>` |
| `/UnitSetResources` | superadmin | `<unitID> <amount>` |
| `/UnitAddResources` | admin | `<unitID> <amount>` |
| `/UnitForceRemove` | admin | `<player>` |
| `/SquadForceDisband` | admin | `<squadID>` |
| `/UnitTransferCO` | admin | `<unitID> <player>` |
| `/UnitList` | admin | — |
| `/UnitInvite` | admin | `<player> <unitID>` |
| `/UnitSetRole` | admin | `<player> <role>` |

---

## 13. Persistence

- **Storage**: Helix plugin data system → `PLUGIN:SetData()` / `PLUGIN:GetData()`
- **File location**: `data/helix/<schema>/usms.txt`
- **Format**: JSON (serialized via `util.TableToJSON`)
- **Saved data**: `units`, `squads`, `members`, `squadMembers`, `logs`, `nextUnitID`, `nextSquadID`
- **Save triggers**: `SaveData` hook (periodic + shutdown), explicit `ix.usms.db.Save()` calls
- **Log pruning**: `ix.usms.db.PruneLogs(maxAgeDays)` — removes entries older than config

---

## 14. External Integrations

### Diegetic HUD System (`ix.diegeticHUD`)
- USMS syncs squad data to the diegetic HUD every N seconds (config: `usmsHUDSyncInterval`)
- Uses `ix.diegeticHUD.CreateSquad()`, `ix.diegeticHUD.SyncSquad()`, `ix.diegeticHUD.DisbandSquad()`
- Squad IDs are prefixed: `"usms_" .. squadID`

### Helix Class System (`ix.class`)
- USMS overrides free class switching via `CanPlayerJoinClass` hook
- Classes are indexed by `ix.class.list[classIndex]`
- Each class has `.name`, `.faction` fields
- Loadout items are defined per-class in the schema

### Equipment Catalog (`libs/sh_catalogs.lua`)
- Global items: `ix.usms.RegisterGlobalItem(uniqueID, {name, cost, category})`
- Faction items: `ix.usms.RegisterFactionItem(factionID, uniqueID, {name, cost, category})`
- Query: `ix.usms.GetAvailableCatalog(factionID)` → merged table

---

## 15. Common Edit Scenarios

### "Add a new field to squads"
1. `sv_usms.lua` → `CreateSquad()`: add field to cache table
2. `sv_usms.lua` → `SendRoster()`: include field in roster entries
3. `cl_plugin.lua` → `ixUSMSRosterSync` receiver: extract field into `clientData.squads`
4. `cl_squad_panel.lua` → `BuildSquadData()`: include field; display in `RebuildDetail()`

### "Add a new context menu action"
1. `sv_usms.lua`: Add request handler with permission check
2. Client panel: Add `menu:AddOption(...)` inside `OnMousePressed` with permission gate
3. Call `ix.usms.Request("action_name", {data})` from the option callback

### "Add a new UI panel/tab"
1. Create `derma/cl_<name>.lua` with PANEL pattern
2. `cl_usms_tab.lua` → `Init()`: add panel, `CreateTabButtons()`: add tab name, `SetActiveTab()`: toggle visibility

### "Fix a sync issue (client not updating)"
- Check that the server calls `ix.usms.FullSyncToUnit(unitID)` or `SyncRosterUpdateToUnit()`
- Check client hooks are registered and the panel listens to the right hook
- Check that `ix.usms.db.Save()` is called for persistence

---

## 16. Class Persistence & Whitelist System

### Class Persistence
Classes are stored by **uniqueID** (stable string derived from filename, e.g., `army_recruit`) instead of the numeric class index which can change if classes are added/removed.

- `member.cachedClassUID` — the persisted class uniqueID string
- On `PlayerLoadedCharacter`, the system calls `ix.usms.GetClassIndexByUID()` to resolve the UID back to a runtime index and restore the class via `char:SetClass()`
- If the class was removed from the schema, the cached data is cleared gracefully

### Class Whitelist
Players must be **whitelisted** for non-default classes before they can select them.

- `member.classWhitelist` — array of class uniqueID strings the member is allowed to use
- Default classes (`classInfo.isDefault == true`) bypass the whitelist
- Whitelist is checked in `ChangeClass()` only for self-service changes (no `authorizerCharID`)
- Officer-initiated class assignments (`unit_set_class`) auto-whitelist the target
- Whitelist data is included in roster syncs so the client loadout panel can filter available classes

### Whitelist Management Flow
```
Officer right-clicks roster row → "Manage Class Whitelist" submenu
  → Toggle [X]/[ ] for each non-default faction class
  → Sends "class_whitelist_add" or "class_whitelist_remove" request
  → Server updates member.classWhitelist, logs, saves, syncs
  → Target player's loadout panel updates to show/hide classes
```

---

## 17. Mission System

### Overview
Officers and squad leaders can create, track, and complete missions assigned to squads or entire units. Missions appear in a dedicated MISSIONS tab and sync to all unit members.

### Constants (`libs/sh_usms.lua`)
```lua
USMS_MISSION_ACTIVE    = "active"
USMS_MISSION_COMPLETE  = "complete"
USMS_MISSION_CANCELLED = "cancelled"

USMS_MISSION_PRIORITY_LOW      = 1
USMS_MISSION_PRIORITY_NORMAL   = 2
USMS_MISSION_PRIORITY_CRITICAL = 3

USMS_LOG_MISSION_CREATED   = "mission_created"
USMS_LOG_MISSION_COMPLETED = "mission_completed"
USMS_LOG_MISSION_CANCELLED = "mission_cancelled"
```

### Data Structure (Mission)
```lua
{
    id          = number,      -- auto-incremented via AllocMissionID()
    unitID      = number,
    createdBy   = number,      -- charID of creator
    assignedTo  = {            -- assignment target
        type = "squad"|"unit",
        id   = number          -- squadID or unitID
    },
    title       = string,      -- max 128 chars
    description = string,      -- max 512 chars
    priority    = 1|2|3,       -- low/normal/critical
    status      = "active"|"complete"|"cancelled",
    createdAt   = number,      -- os.time()
    completedAt = number|nil
}
```

### Server Caches
```lua
ix.usms.missions      = {} -- [missionID] → missionData
ix.usms.nextMissionID  = 1
```

### Server API (`libs/sv_usms.lua`)
```
ix.usms.CreateMission(unitID, createdByCharID, title, description, priority, assignedTo)
ix.usms.CompleteMission(missionID, completedByCharID)
ix.usms.CancelMission(missionID, cancelledByCharID)
ix.usms.GetActiveMissions(unitID) → table
ix.usms.GetUnitMissions(unitID)   → table (all statuses)
ix.usms.SyncMissionsToPlayer(ply, unitID)
ix.usms.SyncMissionsToUnit(unitID)
```

### Request Handlers
| Action | Permission | Description |
|--------|-----------|-------------|
| `mission_create` | >= UNIT_XO, SQUAD_LEADER, or superadmin | Create a new mission |
| `mission_complete` | >= UNIT_XO, SQUAD_LEADER, or superadmin | Mark active mission complete |
| `mission_cancel` | >= UNIT_XO, SQUAD_LEADER, or superadmin | Cancel active mission |
| `mission_request` | any unit member or superadmin | Request mission sync |

### Net Messages
| Name | Direction | Purpose |
|------|-----------|---------|
| `ixUSMSMissionSync` | S→C | Full mission list (compressed JSON) |
| `ixUSMSMissionUpdate` | S→C | (reserved for delta updates) |

### Client Hooks
| Hook | Fired When |
|------|------------|
| `USMSMissionsUpdated` | Mission sync received |

### UI Panel: `ixUSMSMissionPanel` (`derma/cl_mission_panel.lua`)
- Split layout: 35% mission list (left) / 65% detail (right)
- Status filter dropdown: Active / Completed / Cancelled / All
- Mission cards show priority color bar (green=low, gold=normal, red=critical)
- Detail view: title, status badge, priority, assigned target, creator, timestamps, description
- Context menu on active missions: Complete / Cancel
- CREATE MISSION button (permission-gated) opens dialog with title, description, priority dropdown, assignment target combo
- Critical priority missions also update the diegetic HUD objectives

---

## 18. Commendation & Service Record System

### Overview
Officers can award commendations (medals, citations, reprimands) to unit members. These build a persistent service record viewable by right-clicking a roster entry.

### Constants (`libs/sh_usms.lua`)
```lua
USMS_COMMENDATION_MEDAL       = "medal"
USMS_COMMENDATION_COMMENDATION = "commendation"
USMS_COMMENDATION_REPRIMAND   = "reprimand"

USMS_LOG_COMMENDATION_AWARDED = "commendation_awarded"
USMS_LOG_COMMENDATION_REVOKED = "commendation_revoked"
```

### Data Structure (Commendation)
```lua
{
    id              = number,      -- auto-incremented via AllocCommendationID()
    unitID          = number,
    recipientCharID = number,
    awardedBy       = number,      -- charID of awarding officer
    type            = "medal"|"commendation"|"reprimand",
    title           = string,      -- max 128 chars
    reason          = string,      -- max 512 chars
    timestamp       = number,      -- os.time()
    revoked         = false|true
}
```

### Server Caches
```lua
ix.usms.commendations      = {} -- [commendationID] → commendationData
ix.usms.nextCommendationID  = 1
```

### Server API (`libs/sv_usms.lua`)
```
ix.usms.AwardCommendation(unitID, recipientCharID, awardedByCharID, type, title, reason)
ix.usms.RevokeCommendation(commendationID, revokedByCharID)
ix.usms.GetServiceRecord(charID) → { commendations={}, promotions={} }
ix.usms.SendServiceRecord(ply, targetCharID)
```

### Request Handlers
| Action | Permission | Description |
|--------|-----------|-------------|
| `commendation_award` | >= UNIT_XO or superadmin | Award a commendation |
| `commendation_revoke` | >= UNIT_XO or superadmin | Revoke a commendation |
| `service_record_request` | any unit member or superadmin | Request target's service record |

### Net Messages
| Name | Direction | Purpose |
|------|-----------|---------|
| `ixUSMSServiceRecord` | S→C | Service record data (compressed JSON) |

### Client Hooks
| Hook | Args | Fired When |
|------|------|------------|
| `USMSServiceRecordReceived` | data | Service record sync received |

### UI Panel: `ixUSMSServiceRecord` (`derma/cl_service_record.lua`)
- DFrame popup (500×400), opened from roster right-click → "View Service Record"
- Sections: Personnel File (name, rank, class, join date), Commendations & Awards (color-coded by type: gold=medal, blue=commendation, red=reprimand), Promotion History
- Right-click commendation entry to revoke (officers only)
- "Award Commendation" button opens dialog with type/title/reason inputs

---

## 19. Enhanced Log Viewer

### Improvements over base log panel (`derma/cl_log_panel.lua`)
- **Text search bar**: Filters log detail text and action labels client-side (case-insensitive substring match)
- **Time range dropdown**: All Time / Last 24 Hours / Last 7 Days / Last 30 Days
- **Expandable rows**: Click any log row to expand inline detail showing full timestamp, actor (with charID), target (with charID), and all metadata fields
- **Copy to Clipboard**: Exports currently filtered logs as formatted text via `SetClipboardText()`
- **Client-side filtering**: All filters (action type, time range, search text) apply client-side on bulk-fetched data, with pagination on the filtered result set
- **New log action labels**: mission_created, mission_completed, mission_cancelled, commendation_awarded, commendation_revoked

---

## 20. Enhanced Loadout Panel

### Improvements over base loadout panel (`derma/cl_loadout_panel.lua`)
- **Styled item rows**: Taller rows (34px scaled) with left color bar indicating ownership status (green = owned, gray = not owned)
- **Category labels**: If an item has a category (from catalog or item base), it's shown as a small uppercase tag above the item name
- **Ownership indicator**: Green checkmark (✓) for items already in the player's inventory, checked via `char:GetInventory():GetItems()`
- **Hover tooltips**: Hovering an item row shows a floating tooltip with the item's description (from `ix.item.list[uid].description` or catalog)
- **Cost display**: Right-aligned supply cost in blue, unchanged from original

---

## 21. Updated File Map

```
usms/
├── sh_plugin.lua              — Plugin metadata, constants, config, include order
├── sv_plugin.lua              — Server hooks (char load, disconnect, HUD sync timer)
├── cl_plugin.lua              — Client state cache + all net.Receive handlers
├── USMS_REFERENCE.md          — THIS FILE
│
├── meta/
│   └── sh_character.lua       — CharVar definitions + character meta methods
│
├── libs/
│   ├── sh_usms.lua            — Shared constants, caches (units/squads/members/missions/commendations)
│   ├── sh_catalogs.lua        — Equipment catalog
│   ├── sv_database.lua        — Persistence (Load/Save/AllocID/AllocMissionID/AllocCommendationID)
│   ├── sv_logging.lua         — Log system
│   └── sv_usms.lua            — ★ MAIN SERVER FILE (~2200+ lines)
│                                 Unit/Squad/Member/Resource/Class/Mission/Commendation APIs
│
├── commands/
│   ├── sh_admin.lua           — Admin chat commands
│   └── sh_testing.lua         — Dev/test commands
│
└── derma/                     — Client VGUI panels (auto-loaded by Helix)
    ├── cl_usms_tab.lua        — Main container, tabs: ROSTER | SQUADS | MISSIONS | LOGS | LOADOUT | INFO
    ├── cl_unit_overview.lua   — Left sidebar
    ├── cl_unit_roster.lua     — Sortable member table + right-click (incl. View Service Record)
    ├── cl_squad_panel.lua     — Squad list + detail view
    ├── cl_mission_panel.lua   — ★ NEW: Mission list/detail/create UI
    ├── cl_service_record.lua  — ★ NEW: Service record popup (commendations + promotions)
    ├── cl_log_panel.lua       — Enhanced log viewer (search, time range, expandable rows, copy)
    ├── cl_loadout_panel.lua   — Enhanced class selector (styled rows, tooltips, ownership)
    ├── cl_invite_popup.lua    — Slide-in invite notification popup
    └── cl_help_panel.lua      — Role documentation / info tab
```

### All Net Messages (Updated)
| Name | Direction | Purpose |
|------|-----------|---------|
| `ixUSMSUnitSync` | S→C | Full unit data |
| `ixUSMSUnitUpdate` | S→C | Partial unit update |
| `ixUSMSRosterSync` | S→C | Full roster (compressed JSON) |
| `ixUSMSRosterUpdate` | S→C | Single roster entry delta |
| `ixUSMSLogSync` | S→C | Log data (compressed JSON) |
| `ixUSMSIntelSync` | S→C | Cross-faction intel |
| `ixUSMSRequest` | C→S | Client action request |
| `ixUSMSInvite` | S→C | Invite notification |
| `ixUSMSInviteResponse` | C→S | Accept/decline invite |
| `ixUSMSMissionSync` | S→C | ★ Mission list (compressed JSON) |
| `ixUSMSMissionUpdate` | S→C | ★ Mission delta (reserved) |
| `ixUSMSServiceRecord` | S→C | ★ Service record (compressed JSON) |

### All Request Handlers (Updated)
| Action | Permission | Description |
|--------|-----------|-------------|
| `squad_create` | USMSCanCreateSquad hook | Create squad |
| `squad_invite` | >= SQUAD_INVITER or superadmin | Send squad invite |
| `squad_kick` | >= SQUAD_XO or superadmin | Kick from squad |
| `squad_leave` | any squad member | Leave squad |
| `squad_disband` | SQUAD_LEADER or superadmin | Disband own squad |
| `squad_force_disband` | >= UNIT_XO or superadmin | Force disband |
| `squad_set_role` | SQUAD_LEADER, >= UNIT_XO, or superadmin | Set squad role |
| `squad_set_description` | SQUAD_LEADER, >= UNIT_XO, or superadmin | Set squad description |
| `squad_force_remove` | >= UNIT_XO or superadmin | Force remove from squad |
| `squad_force_add` | >= UNIT_XO or superadmin | Force add to squad |
| `unit_invite` | >= UNIT_XO or superadmin | Send unit invite |
| `unit_kick` | >= UNIT_XO or superadmin | Remove from unit |
| `unit_set_role` | >= UNIT_CO or superadmin | Set unit role |
| `unit_set_class` | >= UNIT_XO or superadmin | Assign class |
| `gearup` | any unit member with class | Gear up |
| `class_change` | any unit member (whitelisted) | Self class change |
| `class_whitelist_add` | >= UNIT_XO or superadmin | Add class whitelist |
| `class_whitelist_remove` | >= UNIT_XO or superadmin | Remove class whitelist |
| `roster_request` | any unit member or superadmin | Request roster sync |
| `log_request` | >= UNIT_XO or superadmin | Request log data |
| `mission_create` | >= UNIT_XO, SQUAD_LEADER, or superadmin | ★ Create mission |
| `mission_complete` | >= UNIT_XO, SQUAD_LEADER, or superadmin | ★ Complete mission |
| `mission_cancel` | >= UNIT_XO, SQUAD_LEADER, or superadmin | ★ Cancel mission |
| `mission_request` | any unit member or superadmin | ★ Request mission sync |
| `commendation_award` | >= UNIT_XO or superadmin | ★ Award commendation |
| `commendation_revoke` | >= UNIT_XO or superadmin | ★ Revoke commendation |
| `service_record_request` | any unit member or superadmin | ★ Request service record |

### Persistence (Updated)
Saved data now includes: `units`, `squads`, `members`, `squadMembers`, `logs`, `missions`, `commendations`, `nextUnitID`, `nextSquadID`, `nextMissionID`, `nextCommendationID`
