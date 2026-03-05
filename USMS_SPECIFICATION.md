# Unit & Squad Management System (USMS) — Technical Specification

> **Version:** 1.0  
> **Schema:** `skeleton`  
> **Gamemode base:** Helix (`gamemodes/helix`)  
> **Target plugin path:** `gamemodes/skeleton/plugins/usms/`

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Hierarchy & Terminology](#2-hierarchy--terminology)
3. [Plugin File Structure](#3-plugin-file-structure)
4. [Database Schema](#4-database-schema)
5. [Server-Side API (`ix.usms`)](#5-server-side-api-ixusms)
6. [Character Variables](#6-character-variables)
7. [Networking Protocol](#7-networking-protocol)
8. [Unit System](#8-unit-system)
9. [Squad System](#9-squad-system)
10. [Class / Loadout System](#10-class--loadout-system)
11. [Resource System](#11-resource-system)
12. [Equipment Catalogs](#12-equipment-catalogs)
13. [Gear-Up API (Armory)](#13-gear-up-api-armory)
14. [Logging System](#14-logging-system)
15. [Roster System](#15-roster-system)
16. [Cross-Faction Intelligence (ISB)](#16-cross-faction-intelligence-isb)
17. [HUD Integration](#17-hud-integration)
18. [Tab Menu UI](#18-tab-menu-ui)
19. [Admin Commands & Overrides](#19-admin-commands--overrides)
20. [Testing Commands](#20-testing-commands)
21. [Hooks](#21-hooks)
22. [Phased Implementation Plan](#22-phased-implementation-plan)
23. [Codebase References](#23-codebase-references)

---

## 1. System Overview

The USMS is a Helix plugin that adds persistent military organizational structure to the server:

- **Units** are admin-created subdivisions within Helix factions (e.g., "501st Legion" in the Imperial Army faction).
- **Squads** are player-created tactical groups within units (4-8 members, led by certified personnel).
- **Classes** are permanent role assignments that define a character's loadout (equipment template).
- **Resources** are a global integer per unit representing requisition budget, spent when members gear up.

### Core Rules

1. A character belongs to exactly **one faction** (existing Helix system, unchanged).
2. A character can be a member of exactly **one unit** within their faction. Unit membership is optional.
3. A character can be in exactly **one squad** within their unit. Squad membership is optional.
4. A character **cannot be in a squad without being in a unit**.
5. A character's **class is permanent** — changing class requires being at a loadout locker (entity/API interaction).
6. Each character is **independent** — one player's multiple characters are treated as separate people.
7. Units are created by **superadmins only** as part of server setup.
8. Squads are created by **players** meeting rank + certification requirements.

---

## 2. Hierarchy & Terminology

```
Helix Faction (admin-defined, e.g. "Imperial Army")
  │   Unchanged. Created in schema/factions/. Uses FACTION table + FACTION_X globals.
  │
  └── Unit (superadmin-created, e.g. "501st Legion")
        │   Persistent DB entity. Has resource pool, roster, logs.
        │
        ├── Members (characters invited to unit)
        │     │   Each has a unit role: CO, XO, or MEMBER
        │     │   Each has a class assignment (= their loadout)
        │     │
        │     └── Class/Loadout (permanent per character)
        │           Defines equipment template + gear-up cost.
        │           Changed only at loadout locker via API.
        │
        └── Squads (player-created, 4-8 members)
              │   Persistent. Led by Squad Leader (SL).
              │   Members drawn from parent unit only.
              │
              └── Squad Members
                    Gear up via unit resources. Shown on HUD.
```

### Role Definitions

| Role | Scope | Assigned By | Key Powers |
|------|-------|-------------|------------|
| **Superadmin** | Global | Server config | Create/delete units, override anything |
| **Admin** | Global | Server config | Force-disband squads, force-transfer CO, adjust resources |
| **Unit Commander (CO)** | Unit | Superadmin or outgoing CO (+admin approval) | Full unit management: invite/kick members, assign classes, manage resources, appoint XO |
| **Executive Officer (XO)** | Unit | CO | Same as CO except cannot appoint other XOs or transfer CO |
| **Unit Member** | Unit | Invited by CO/XO | Join squads, gear up, view roster |
| **Squad Leader (SL)** | Squad | Created the squad | Invite/kick squad members (from unit), name squad, disband |
| **Squad Member** | Squad | Invited by SL | Gear up, see squad roster, use squad comms |

### Constants

```lua
-- Unit roles
USMS_ROLE_MEMBER = 0
USMS_ROLE_XO     = 1
USMS_ROLE_CO     = 2

-- Squad roles  
USMS_SQUAD_MEMBER = 0
USMS_SQUAD_LEADER = 1

-- Squad size limits
USMS_SQUAD_MIN_SIZE = 2  -- including SL
USMS_SQUAD_MAX_SIZE = 8  -- including SL

-- Log action types (string keys for extensibility)
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
```

---

## 3. Plugin File Structure

```
gamemodes/skeleton/plugins/usms/
├── sh_plugin.lua              -- Plugin definition, constants, ix.util.Include calls
├── sv_plugin.lua              -- Server hooks (PlayerLoadedCharacter, etc.)
├── cl_plugin.lua              -- Client-side state, net receivers
├── libs/
│   ├── sh_usms.lua            -- Shared API namespace (ix.usms), shared accessors
│   ├── sv_usms.lua            -- Server-side unit/squad/resource/gearup API
│   ├── sv_database.lua        -- DB table creation, queries, migrations
│   ├── sv_logging.lua         -- USMS-specific logging (DB + ix.log integration)
│   └── sh_catalogs.lua        -- Equipment catalog definitions (global + per-faction)
├── derma/
│   ├── cl_usms_tab.lua        -- Tab menu hook (CreateMenuButtons) + main container
│   ├── cl_unit_overview.lua   -- Unit overview section
│   ├── cl_unit_roster.lua     -- Unit roster panel (sortable member table)
│   ├── cl_squad_panel.lua     -- Squad management section
│   ├── cl_loadout_panel.lua   -- Class/loadout viewer
│   └── cl_log_panel.lua       -- Log viewer (CO/XO/ISB)
├── meta/
│   └── sh_character.lua       -- Character meta extensions (helper methods)
└── commands/
    ├── sh_admin.lua           -- Admin override commands
    └── sh_testing.lua         -- Testing commands for development
```

### sh_plugin.lua Pattern

Following the established pattern from `diagetichud`, `medicalsys`, `weight`, etc.:

```lua
local PLUGIN = PLUGIN

PLUGIN.name = "Unit & Squad Management"
PLUGIN.author = "Vanir"
PLUGIN.description = "Persistent military unit and squad organization system with loadouts and resources."

-- Constants
USMS_ROLE_MEMBER = 0
USMS_ROLE_XO     = 1
USMS_ROLE_CO     = 2

USMS_SQUAD_MEMBER = 0
USMS_SQUAD_LEADER = 1

USMS_SQUAD_MIN_SIZE = 2
USMS_SQUAD_MAX_SIZE = 8

-- Log action type constants
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

-- Lib includes (order matters: shared first, then realm-specific)
ix.util.Include("libs/sh_usms.lua")
ix.util.Include("libs/sh_catalogs.lua")
ix.util.Include("libs/sv_database.lua")
ix.util.Include("libs/sv_logging.lua")
ix.util.Include("libs/sv_usms.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
ix.util.Include("meta/sh_character.lua")

-- Commands
ix.util.Include("commands/sh_admin.lua")
ix.util.Include("commands/sh_testing.lua")
```

> **Note on `ix.util.Include`:** This function auto-detects realm from filename prefix (`sv_` = server, `cl_` = client, `sh_` = shared) and handles `AddCSLuaFile` automatically. Derma files in the `derma/` subfolder are auto-included by Helix's plugin loader via `ix.util.IncludeDir(path.."/derma", true)` — see `gamemodes/helix/gamemode/core/libs/sh_plugin.lua` line 47.

---

## 4. Database Schema

All tables are created in `libs/sv_database.lua` using the Helix `mysql` query builder wrapper (`gamemodes/helix/gamemode/core/libs/thirdparty/sv_mysql.lua`).

### Tables

#### `ix_usms_units`

Stores unit definitions. Created by superadmins.

```lua
local query = mysql:Create("ix_usms_units")
    query:Create("id", "INT(11) UNSIGNED NOT NULL AUTO_INCREMENT")
    query:Create("name", "VARCHAR(64) NOT NULL")
    query:Create("description", "TEXT DEFAULT NULL")
    query:Create("faction_id", "INT(11) UNSIGNED NOT NULL")        -- Helix faction index
    query:Create("resources", "INT(11) UNSIGNED NOT NULL DEFAULT 0") -- global integer
    query:Create("resource_cap", "INT(11) UNSIGNED NOT NULL DEFAULT 10000")
    query:Create("max_members", "INT(11) UNSIGNED NOT NULL DEFAULT 30")
    query:Create("max_squads", "INT(11) UNSIGNED NOT NULL DEFAULT 5")
    query:Create("created_at", "INT(11) UNSIGNED NOT NULL")        -- os.time()
    query:Create("data", "TEXT DEFAULT NULL")                       -- JSON for future extensibility
    query:PrimaryKey("id")
query:Execute()
```

#### `ix_usms_members`

Associates characters with units. One row per character-unit membership.

```lua
local query = mysql:Create("ix_usms_members")
    query:Create("id", "INT(11) UNSIGNED NOT NULL AUTO_INCREMENT")
    query:Create("unit_id", "INT(11) UNSIGNED NOT NULL")
    query:Create("character_id", "INT(11) UNSIGNED NOT NULL")       -- ix_characters.id
    query:Create("role", "TINYINT(1) UNSIGNED NOT NULL DEFAULT 0")  -- USMS_ROLE_*
    query:Create("joined_at", "INT(11) UNSIGNED NOT NULL")          -- os.time()
    query:PrimaryKey("id")
query:Execute()
```

> **Unique constraint:** `character_id` must be unique across the table (one unit per character). Enforced in application logic + DB constraint.

#### `ix_usms_squads`

Stores squad definitions. Created by players.

```lua
local query = mysql:Create("ix_usms_squads")
    query:Create("id", "INT(11) UNSIGNED NOT NULL AUTO_INCREMENT")
    query:Create("unit_id", "INT(11) UNSIGNED NOT NULL")
    query:Create("name", "VARCHAR(64) NOT NULL")
    query:Create("leader_char_id", "INT(11) UNSIGNED NOT NULL")     -- character_id of SL
    query:Create("created_at", "INT(11) UNSIGNED NOT NULL")
    query:PrimaryKey("id")
query:Execute()
```

#### `ix_usms_squad_members`

Associates characters with squads.

```lua
local query = mysql:Create("ix_usms_squad_members")
    query:Create("id", "INT(11) UNSIGNED NOT NULL AUTO_INCREMENT")
    query:Create("squad_id", "INT(11) UNSIGNED NOT NULL")
    query:Create("character_id", "INT(11) UNSIGNED NOT NULL")       -- must also be in ix_usms_members for same unit
    query:Create("role", "TINYINT(1) UNSIGNED NOT NULL DEFAULT 0")  -- USMS_SQUAD_*
    query:Create("joined_at", "INT(11) UNSIGNED NOT NULL")
    query:PrimaryKey("id")
query:Execute()
```

> **Unique constraint:** `character_id` must be unique (one squad per character). Enforced in application logic.

#### `ix_usms_logs`

Action log for admin + RP intelligence.

```lua
local query = mysql:Create("ix_usms_logs")
    query:Create("id", "INT(11) UNSIGNED NOT NULL AUTO_INCREMENT")
    query:Create("unit_id", "INT(11) UNSIGNED NOT NULL")
    query:Create("action", "VARCHAR(64) NOT NULL")                  -- USMS_LOG_* constant value
    query:Create("actor_char_id", "INT(11) UNSIGNED DEFAULT NULL")  -- who did it
    query:Create("target_char_id", "INT(11) UNSIGNED DEFAULT NULL") -- who it happened to
    query:Create("data", "TEXT DEFAULT NULL")                       -- JSON context (resource amount, class name, etc.)
    query:Create("timestamp", "INT(11) UNSIGNED NOT NULL")          -- os.time()
    query:PrimaryKey("id")
query:Execute()
```

### Initialization

`libs/sv_database.lua` exposes:

```lua
ix.usms.db = ix.usms.db or {}

function ix.usms.db.Initialize()
    -- Create all tables above
    -- Called from PLUGIN:InitializedPlugins() or DatabaseConnected hook
end

function ix.usms.db.PruneLogs(maxAgeDays)
    -- DELETE FROM ix_usms_logs WHERE timestamp < os.time() - (maxAgeDays * 86400)
    -- Default: 60 days
end
```

### Query Pattern

All DB operations use the `mysql` query builder — NOT raw `ix.db.Query` (which doesn't exist in Helix). Pattern:

```lua
-- SELECT example
local query = mysql:Select("ix_usms_units")
    query:Where("faction_id", factionIndex)
    query:Callback(function(result)
        if (!istable(result)) then return end
        for _, row in ipairs(result) do
            -- process row
        end
    end)
query:Execute()

-- INSERT example
local query = mysql:Insert("ix_usms_members")
    query:Insert("unit_id", unitID)
    query:Insert("character_id", charID)
    query:Insert("role", USMS_ROLE_MEMBER)
    query:Insert("joined_at", os.time())
    query:Callback(function(result, status, lastID)
        -- lastID is the auto-increment ID
    end)
query:Execute()

-- UPDATE example
local query = mysql:Update("ix_usms_units")
    query:Update("resources", newAmount)
    query:Where("id", unitID)
query:Execute()

-- DELETE example
local query = mysql:Delete("ix_usms_members")
    query:Where("character_id", charID)
query:Execute()
```

---

## 5. Server-Side API (`ix.usms`)

The primary API namespace. Initialized in `libs/sh_usms.lua` (shared) and `libs/sv_usms.lua` (server).

### Shared State

```lua
-- libs/sh_usms.lua
ix.usms = ix.usms or {}

-- Server-side cache (populated from DB on load, kept in sync)
if (SERVER) then
    ix.usms.units = ix.usms.units or {}       -- [unitID] = unitData
    ix.usms.squads = ix.usms.squads or {}     -- [squadID] = squadData
    ix.usms.members = ix.usms.members or {}   -- [charID] = memberData
    ix.usms.squadMembers = ix.usms.squadMembers or {} -- [charID] = squadMemberData
end
```

### Unit Data Structure (Server Cache)

```lua
ix.usms.units[unitID] = {
    id = unitID,                  -- INT from DB
    name = "501st Legion",
    description = "...",
    factionID = FACTION_ARMY,     -- Helix faction index
    resources = 5000,             -- global integer
    resourceCap = 10000,
    maxMembers = 30,
    maxSquads = 5,
    createdAt = 1709654400,       -- os.time()
    data = {}                     -- decoded JSON for extensions
}
```

### Member Data Structure (Server Cache)

```lua
ix.usms.members[charID] = {
    id = rowID,                   -- DB row ID
    unitID = unitID,
    characterID = charID,
    role = USMS_ROLE_MEMBER,      -- 0, 1, or 2
    joinedAt = 1709654400
}
```

### Squad Data Structure (Server Cache)

```lua
ix.usms.squads[squadID] = {
    id = squadID,
    unitID = unitID,
    name = "FIRETEAM AUREK",
    leaderCharID = charID,
    createdAt = 1709654400
}
```

### Squad Member Data Structure (Server Cache)

```lua
ix.usms.squadMembers[charID] = {
    id = rowID,
    squadID = squadID,
    characterID = charID,
    role = USMS_SQUAD_MEMBER,     -- 0 or 1
    joinedAt = 1709654400
}
```

---

## 6. Character Variables

Register via `ix.char.RegisterVar` in `meta/sh_character.lua`. These are lightweight pointers stored on the character's DB row.

```lua
-- Unit ID the character belongs to (nil if not in a unit)
ix.char.RegisterVar("usmUnitID", {
    field = "usm_unit_id",
    fieldType = ix.type.number,
    default = nil,
    isLocal = false,   -- everyone can see your unit assignment
    bNoDisplay = true  -- don't show in char creation
})

-- Unit role (0=member, 1=XO, 2=CO)
ix.char.RegisterVar("usmUnitRole", {
    field = "usm_unit_role",
    fieldType = ix.type.number,
    default = 0,
    isLocal = false,
    bNoDisplay = true
})

-- Squad ID the character belongs to (nil if not in a squad)
ix.char.RegisterVar("usmSquadID", {
    field = "usm_squad_id",
    fieldType = ix.type.number,
    default = nil,
    isLocal = false,
    bNoDisplay = true
})

-- Squad role (0=member, 1=leader)
ix.char.RegisterVar("usmSquadRole", {
    field = "usm_squad_role",
    fieldType = ix.type.number,
    default = 0,
    isLocal = false,
    bNoDisplay = true
})
```

> **Why CharVars and not just cache?** CharVars are automatically networked. When a client reads `character:GetUsmUnitID()`, it works on both client and server without custom net messages. The `isLocal = false` setting broadcasts to all clients via `ixCharacterVarChanged`.

### Character Meta Helpers

In `meta/sh_character.lua`, add convenience methods to the character meta:

```lua
local charMeta = ix.meta.character

function charMeta:GetUnit()
    local unitID = self:GetUsmUnitID()
    if (!unitID or unitID == 0) then return nil end
    
    if (SERVER) then
        return ix.usms.units[unitID]
    else
        return ix.usms.GetUnitData(unitID) -- client cache
    end
end

function charMeta:GetSquad()
    local squadID = self:GetUsmSquadID()
    if (!squadID or squadID == 0) then return nil end
    
    if (SERVER) then
        return ix.usms.squads[squadID]
    else
        return ix.usms.GetSquadData(squadID) -- client cache
    end
end

function charMeta:IsUnitCO()
    return self:GetUsmUnitRole() == USMS_ROLE_CO
end

function charMeta:IsUnitXO()
    return self:GetUsmUnitRole() == USMS_ROLE_XO
end

function charMeta:IsUnitOfficer()
    return self:GetUsmUnitRole() >= USMS_ROLE_XO
end

function charMeta:IsSquadLeader()
    return self:GetUsmSquadRole() == USMS_SQUAD_LEADER
end

function charMeta:IsInUnit()
    local id = self:GetUsmUnitID()
    return id != nil and id != 0
end

function charMeta:IsInSquad()
    local id = self:GetUsmSquadID()
    return id != nil and id != 0
end
```

---

## 7. Networking Protocol

Use targeted `net.Send` to specific players for USMS data (NOT NetVars/globals). Unit data is only relevant to unit members + ISB.

### Net Strings

Registered in `sv_usms.lua`:

```lua
util.AddNetworkString("ixUSMSUnitSync")          -- Full unit data sync to a player
util.AddNetworkString("ixUSMSUnitUpdate")         -- Partial unit data update (resources, name, etc.)
util.AddNetworkString("ixUSMSRosterSync")         -- Full roster data for a unit
util.AddNetworkString("ixUSMSRosterUpdate")       -- Single member add/remove/update in roster
util.AddNetworkString("ixUSMSSquadSync")          -- Full squad data sync
util.AddNetworkString("ixUSMSSquadUpdate")        -- Single squad update
util.AddNetworkString("ixUSMSLogSync")            -- Log entries batch
util.AddNetworkString("ixUSMSIntelSync")          -- Cross-faction intel data (for ISB)

-- Client -> Server requests
util.AddNetworkString("ixUSMSRequest")            -- Generic request (action-based)
```

### Client -> Server Request Pattern

All client actions go through a single net message with an action string:

```lua
-- CLIENT SIDE (sending request)
net.Start("ixUSMSRequest")
    net.WriteString(action)     -- e.g. "squad_create", "squad_invite", "gearup"
    net.WriteTable(data)        -- action-specific payload (using net.WriteTable for flexibility)
net.SendToServer()

-- SERVER SIDE (receiving)
net.Receive("ixUSMSRequest", function(len, ply)
    local action = net.ReadString()
    local data = net.ReadTable()
    
    -- Rate limiting
    if (CurTime() < (ply.ixUSMSRequestCooldown or 0)) then return end
    ply.ixUSMSRequestCooldown = CurTime() + 0.5
    
    -- Character check
    local char = ply:GetCharacter()
    if (!char) then return end
    
    -- Dispatch to handler
    local handler = ix.usms.requestHandlers[action]
    if (handler) then
        handler(ply, char, data)
    end
end)
```

### Request Handlers

```lua
ix.usms.requestHandlers = {
    -- Squad operations
    ["squad_create"]   = function(ply, char, data) ... end,
    ["squad_invite"]   = function(ply, char, data) ... end,
    ["squad_kick"]     = function(ply, char, data) ... end,
    ["squad_leave"]    = function(ply, char, data) ... end,
    ["squad_disband"]  = function(ply, char, data) ... end,
    
    -- Unit operations (CO/XO only, validated server-side)
    ["unit_invite"]    = function(ply, char, data) ... end,
    ["unit_kick"]      = function(ply, char, data) ... end,
    ["unit_set_role"]  = function(ply, char, data) ... end,
    ["unit_set_class"] = function(ply, char, data) ... end,
    
    -- Class/Loadout operations
    ["gearup"]         = function(ply, char, data) ... end,
    ["class_change"]   = function(ply, char, data) ... end,
    
    -- Roster request
    ["roster_request"]       = function(ply, char, data) ... end,
    ["intel_roster_request"] = function(ply, char, data) ... end,
    
    -- Log request
    ["log_request"]    = function(ply, char, data) ... end,
}
```

### Server -> Client Sync Pattern

When unit data changes, notify affected clients:

```lua
function ix.usms.SyncUnitToPlayer(ply, unitID)
    local unit = ix.usms.units[unitID]
    if (!unit) then return end
    
    net.Start("ixUSMSUnitSync")
        net.WriteUInt(unit.id, 32)
        net.WriteString(unit.name)
        net.WriteString(unit.description or "")
        net.WriteUInt(unit.factionID, 8)
        net.WriteUInt(unit.resources, 32)
        net.WriteUInt(unit.resourceCap, 32)
        net.WriteUInt(unit.maxMembers, 16)
        net.WriteUInt(unit.maxSquads, 8)
    net.Send(ply)
end

function ix.usms.SyncUnitToAllMembers(unitID)
    local recipients = ix.usms.GetOnlineUnitMembers(unitID)
    if (#recipients == 0) then return end
    
    -- Send to all online unit members
    for _, ply in ipairs(recipients) do
        ix.usms.SyncUnitToPlayer(ply, unitID)
    end
end
```

---

## 8. Unit System

### Creating a Unit (Superadmin Only)

```lua
-- libs/sv_usms.lua

--- Create a new unit.
-- @param name string Unit name
-- @param factionID number Helix faction index (e.g., FACTION_ARMY)
-- @param data table Optional data {description, resourceCap, maxMembers, maxSquads}
-- @param callback function(unitID) Called with the new unit's DB ID
function ix.usms.CreateUnit(name, factionID, data, callback)
    data = data or {}
    
    -- Validate faction exists
    if (!ix.faction.indices[factionID]) then
        return false, "Invalid faction"
    end
    
    local now = os.time()
    
    local query = mysql:Insert("ix_usms_units")
        query:Insert("name", name)
        query:Insert("description", data.description or "")
        query:Insert("faction_id", factionID)
        query:Insert("resources", data.resources or 0)
        query:Insert("resource_cap", data.resourceCap or 10000)
        query:Insert("max_members", data.maxMembers or 30)
        query:Insert("max_squads", data.maxSquads or 5)
        query:Insert("created_at", now)
        query:Insert("data", util.TableToJSON(data.extra or {}))
        query:Callback(function(result, status, lastID)
            -- Cache it
            ix.usms.units[lastID] = {
                id = lastID,
                name = name,
                description = data.description or "",
                factionID = factionID,
                resources = data.resources or 0,
                resourceCap = data.resourceCap or 10000,
                maxMembers = data.maxMembers or 30,
                maxSquads = data.maxSquads or 5,
                createdAt = now,
                data = data.extra or {}
            }
            
            if (callback) then callback(lastID) end
            hook.Run("USMSUnitCreated", lastID, name, factionID)
        end)
    query:Execute()
    
    return true
end
```

### Deleting a Unit (Superadmin Only)

```lua
--- Delete a unit and all associated data.
-- Removes all members, squads, squad members, logs.
-- @param unitID number
function ix.usms.DeleteUnit(unitID, callback)
    local unit = ix.usms.units[unitID]
    if (!unit) then return false, "Unit not found" end
    
    -- Clear all members' CharVars
    for charID, member in pairs(ix.usms.members) do
        if (member.unitID == unitID) then
            local char = ix.usms.GetCharacterByID(charID)
            if (char) then
                char:SetUsmUnitID(0)
                char:SetUsmUnitRole(0)
                char:SetUsmSquadID(0)
                char:SetUsmSquadRole(0)
            end
            ix.usms.members[charID] = nil
        end
    end
    
    -- Clear squads cache
    for squadID, squad in pairs(ix.usms.squads) do
        if (squad.unitID == unitID) then
            ix.usms.squads[squadID] = nil
        end
    end
    
    -- Clear squad members cache
    for charID, sm in pairs(ix.usms.squadMembers) do
        local squad = ix.usms.squads[sm.squadID]
        -- already cleared above, but also clean orphans
        ix.usms.squadMembers[charID] = nil
    end
    
    -- DB cleanup (cascade)
    mysql:RawQuery("DELETE FROM ix_usms_squad_members WHERE squad_id IN (SELECT id FROM ix_usms_squads WHERE unit_id = " .. unitID .. ")")
    mysql:RawQuery("DELETE FROM ix_usms_squads WHERE unit_id = " .. unitID)
    mysql:RawQuery("DELETE FROM ix_usms_members WHERE unit_id = " .. unitID)
    mysql:RawQuery("DELETE FROM ix_usms_logs WHERE unit_id = " .. unitID)
    
    local query = mysql:Delete("ix_usms_units")
        query:Where("id", unitID)
        query:Callback(function()
            ix.usms.units[unitID] = nil
            if (callback) then callback() end
            hook.Run("USMSUnitDeleted", unitID)
        end)
    query:Execute()
    
    return true
end
```

### Adding a Member to a Unit

```lua
--- Add a character to a unit.
-- @param charID number Character ID
-- @param unitID number Unit ID
-- @param role number USMS_ROLE_* (default USMS_ROLE_MEMBER)
-- @param callback function(success, error)
function ix.usms.AddMember(charID, unitID, role, callback)
    role = role or USMS_ROLE_MEMBER
    
    local unit = ix.usms.units[unitID]
    if (!unit) then
        if (callback) then callback(false, "Unit not found") end
        return
    end
    
    -- Check if already in a unit
    if (ix.usms.members[charID]) then
        if (callback) then callback(false, "Character is already in a unit") end
        return
    end
    
    -- Check faction match
    local char = ix.usms.GetCharacterByID(charID)
    if (!char) then
        if (callback) then callback(false, "Character not found") end
        return
    end
    
    if (char:GetFaction() != unit.factionID) then
        if (callback) then callback(false, "Character is not in the correct faction") end
        return
    end
    
    -- Check member cap
    local memberCount = ix.usms.GetUnitMemberCount(unitID)
    if (memberCount >= unit.maxMembers) then
        if (callback) then callback(false, "Unit is full") end
        return
    end
    
    local now = os.time()
    
    local query = mysql:Insert("ix_usms_members")
        query:Insert("unit_id", unitID)
        query:Insert("character_id", charID)
        query:Insert("role", role)
        query:Insert("joined_at", now)
        query:Callback(function(result, status, lastID)
            -- Update cache
            ix.usms.members[charID] = {
                id = lastID,
                unitID = unitID,
                characterID = charID,
                role = role,
                joinedAt = now
            }
            
            -- Update CharVars
            char:SetUsmUnitID(unitID)
            char:SetUsmUnitRole(role)
            
            -- Log
            ix.usms.Log(unitID, USMS_LOG_UNIT_MEMBER_JOIN, nil, charID)
            
            -- Sync to unit members
            ix.usms.SyncRosterUpdateToUnit(unitID, charID, "add")
            
            if (callback) then callback(true) end
            hook.Run("USMSMemberAdded", charID, unitID, role)
        end)
    query:Execute()
end
```

### Removing a Member

```lua
--- Remove a character from their unit (and squad if applicable).
-- @param charID number Character ID
-- @param kickerCharID number|nil Who kicked them (nil for voluntary leave)
-- @param callback function
function ix.usms.RemoveMember(charID, kickerCharID, callback)
    local member = ix.usms.members[charID]
    if (!member) then
        if (callback) then callback(false, "Not in a unit") end
        return
    end
    
    local unitID = member.unitID
    
    -- Remove from squad first if in one
    if (ix.usms.squadMembers[charID]) then
        ix.usms.RemoveFromSquad(charID)
    end
    
    -- DB delete
    local query = mysql:Delete("ix_usms_members")
        query:Where("character_id", charID)
        query:Callback(function()
            -- Clear cache
            ix.usms.members[charID] = nil
            
            -- Clear CharVars
            local char = ix.usms.GetCharacterByID(charID)
            if (char) then
                char:SetUsmUnitID(0)
                char:SetUsmUnitRole(0)
            end
            
            -- Log
            local logAction = kickerCharID and USMS_LOG_UNIT_MEMBER_KICKED or USMS_LOG_UNIT_MEMBER_LEAVE
            ix.usms.Log(unitID, logAction, kickerCharID, charID)
            
            -- Sync
            ix.usms.SyncRosterUpdateToUnit(unitID, charID, "remove")
            
            if (callback) then callback(true) end
            hook.Run("USMSMemberRemoved", charID, unitID, kickerCharID)
        end)
    query:Execute()
end
```

### Utility Functions

```lua
--- Get a character object by ID (online characters only).
function ix.usms.GetCharacterByID(charID)
    for _, ply in ipairs(player.GetAll()) do
        local char = ply:GetCharacter()
        if (char and char:GetID() == charID) then
            return char
        end
    end
    return nil
end

--- Get the player entity for a character ID (online only).
function ix.usms.GetPlayerByCharID(charID)
    for _, ply in ipairs(player.GetAll()) do
        local char = ply:GetCharacter()
        if (char and char:GetID() == charID) then
            return ply
        end
    end
    return nil
end

--- Get all online player entities who are members of a unit.
function ix.usms.GetOnlineUnitMembers(unitID)
    local players = {}
    for charID, member in pairs(ix.usms.members) do
        if (member.unitID == unitID) then
            local ply = ix.usms.GetPlayerByCharID(charID)
            if (IsValid(ply)) then
                table.insert(players, ply)
            end
        end
    end
    return players
end

--- Get count of members in a unit.
function ix.usms.GetUnitMemberCount(unitID)
    local count = 0
    for charID, member in pairs(ix.usms.members) do
        if (member.unitID == unitID) then
            count = count + 1
        end
    end
    return count
end

--- Get all member data for a unit.
function ix.usms.GetUnitMembers(unitID)
    local members = {}
    for charID, member in pairs(ix.usms.members) do
        if (member.unitID == unitID) then
            members[charID] = member
        end
    end
    return members
end

--- Get all squads in a unit.
function ix.usms.GetUnitSquads(unitID)
    local squads = {}
    for squadID, squad in pairs(ix.usms.squads) do
        if (squad.unitID == unitID) then
            squads[squadID] = squad
        end
    end
    return squads
end

--- Get all members of a squad.
function ix.usms.GetSquadMembers(squadID)
    local members = {}
    for charID, sm in pairs(ix.usms.squadMembers) do
        if (sm.squadID == squadID) then
            members[charID] = sm
        end
    end
    return members
end

--- Get the squad count for a unit.
function ix.usms.GetUnitSquadCount(unitID)
    local count = 0
    for _, squad in pairs(ix.usms.squads) do
        if (squad.unitID == unitID) then
            count = count + 1
        end
    end
    return count
end

--- Get all units for a faction.
function ix.usms.GetFactionUnits(factionID)
    local units = {}
    for unitID, unit in pairs(ix.usms.units) do
        if (unit.factionID == factionID) then
            units[unitID] = unit
        end
    end
    return units
end
```

---

## 9. Squad System

### Creating a Squad

```lua
--- Create a squad within a unit.
-- @param ply Player The player creating the squad (must meet requirements)
-- @param name string Squad designation
-- @param callback function(success, error|squadID)
function ix.usms.CreateSquad(ply, name, callback)
    local char = ply:GetCharacter()
    if (!char) then
        if (callback) then callback(false, "No character") end
        return
    end
    
    local member = ix.usms.members[char:GetID()]
    if (!member) then
        if (callback) then callback(false, "Not in a unit") end
        return
    end
    
    -- Already in a squad?
    if (ix.usms.squadMembers[char:GetID()]) then
        if (callback) then callback(false, "Already in a squad") end
        return
    end
    
    -- Check squad creation permission
    -- This is the extension point for rank + certification checks
    local canCreate, reason = hook.Run("USMSCanCreateSquad", ply, char, member)
    if (canCreate == false) then
        if (callback) then callback(false, reason or "Not authorized") end
        return
    end
    
    local unitID = member.unitID
    local unit = ix.usms.units[unitID]
    
    -- Check squad cap
    if (ix.usms.GetUnitSquadCount(unitID) >= unit.maxSquads) then
        if (callback) then callback(false, "Unit has reached maximum number of squads") end
        return
    end
    
    local now = os.time()
    local charID = char:GetID()
    
    local query = mysql:Insert("ix_usms_squads")
        query:Insert("unit_id", unitID)
        query:Insert("name", name)
        query:Insert("leader_char_id", charID)
        query:Insert("created_at", now)
        query:Callback(function(result, status, squadID)
            -- Cache squad
            ix.usms.squads[squadID] = {
                id = squadID,
                unitID = unitID,
                name = name,
                leaderCharID = charID,
                createdAt = now
            }
            
            -- Add creator as squad leader
            local smQuery = mysql:Insert("ix_usms_squad_members")
                smQuery:Insert("squad_id", squadID)
                smQuery:Insert("character_id", charID)
                smQuery:Insert("role", USMS_SQUAD_LEADER)
                smQuery:Insert("joined_at", now)
                smQuery:Callback(function(_, _, smID)
                    ix.usms.squadMembers[charID] = {
                        id = smID,
                        squadID = squadID,
                        characterID = charID,
                        role = USMS_SQUAD_LEADER,
                        joinedAt = now
                    }
                    
                    -- Update CharVars
                    char:SetUsmSquadID(squadID)
                    char:SetUsmSquadRole(USMS_SQUAD_LEADER)
                    
                    -- Log
                    ix.usms.Log(unitID, USMS_LOG_SQUAD_CREATED, charID, nil, {squadName = name, squadID = squadID})
                    
                    -- Sync HUD
                    ix.usms.SyncSquadToHUD(squadID)
                    
                    if (callback) then callback(true, squadID) end
                    hook.Run("USMSSquadCreated", squadID, unitID, charID)
                end)
            smQuery:Execute()
        end)
    query:Execute()
end
```

### Squad Permission Hook

```lua
--- Hook: USMSCanCreateSquad
-- Return false, "reason" to deny. Return nil/true to allow.
-- Default implementation (placeholder for rank/cert system):
hook.Add("USMSCanCreateSquad", "ixUSMSDefaultPermission", function(ply, char, member)
    -- MVP: Only CO and XO can create squads
    -- Later: check rank >= SGT and has squad_leader certification
    if (member.role >= USMS_ROLE_XO) then
        return true
    end
    
    -- Check for a squad creation flag (temporary until rank system)
    if (ply:GetNetVar("ixUSMSCanCreateSquad", false)) then
        return true
    end
    
    return false, "Insufficient rank or certification"
end)
```

### Adding to Squad / Removing from Squad

```lua
--- Invite a character to a squad.
function ix.usms.AddToSquad(charID, squadID, callback)
    local squad = ix.usms.squads[squadID]
    if (!squad) then
        if (callback) then callback(false, "Squad not found") end
        return
    end
    
    -- Must be in the same unit
    local member = ix.usms.members[charID]
    if (!member or member.unitID != squad.unitID) then
        if (callback) then callback(false, "Character is not in this unit") end
        return
    end
    
    -- Already in a squad?
    if (ix.usms.squadMembers[charID]) then
        if (callback) then callback(false, "Already in a squad") end
        return
    end
    
    -- Check squad size
    local squadSize = table.Count(ix.usms.GetSquadMembers(squadID))
    if (squadSize >= USMS_SQUAD_MAX_SIZE) then
        if (callback) then callback(false, "Squad is full") end
        return
    end
    
    local now = os.time()
    
    local query = mysql:Insert("ix_usms_squad_members")
        query:Insert("squad_id", squadID)
        query:Insert("character_id", charID)
        query:Insert("role", USMS_SQUAD_MEMBER)
        query:Insert("joined_at", now)
        query:Callback(function(_, _, smID)
            ix.usms.squadMembers[charID] = {
                id = smID,
                squadID = squadID,
                characterID = charID,
                role = USMS_SQUAD_MEMBER,
                joinedAt = now
            }
            
            local char = ix.usms.GetCharacterByID(charID)
            if (char) then
                char:SetUsmSquadID(squadID)
                char:SetUsmSquadRole(USMS_SQUAD_MEMBER)
            end
            
            ix.usms.Log(squad.unitID, USMS_LOG_SQUAD_MEMBER_JOIN, nil, charID, {squadID = squadID})
            ix.usms.SyncSquadToHUD(squadID)
            
            if (callback) then callback(true) end
            hook.Run("USMSSquadMemberAdded", charID, squadID)
        end)
    query:Execute()
end

--- Remove a character from their squad.
function ix.usms.RemoveFromSquad(charID, kickerCharID, callback)
    local sm = ix.usms.squadMembers[charID]
    if (!sm) then
        if (callback) then callback(false, "Not in a squad") end
        return
    end
    
    local squadID = sm.squadID
    local squad = ix.usms.squads[squadID]
    local wasLeader = (sm.role == USMS_SQUAD_LEADER)
    
    local query = mysql:Delete("ix_usms_squad_members")
        query:Where("character_id", charID)
        query:Callback(function()
            ix.usms.squadMembers[charID] = nil
            
            local char = ix.usms.GetCharacterByID(charID)
            if (char) then
                char:SetUsmSquadID(0)
                char:SetUsmSquadRole(0)
            end
            
            local logAction = kickerCharID and USMS_LOG_SQUAD_MEMBER_KICKED or USMS_LOG_SQUAD_MEMBER_LEAVE
            if (squad) then
                ix.usms.Log(squad.unitID, logAction, kickerCharID, charID, {squadID = squadID})
            end
            
            -- If leader left, handle succession or disband
            if (wasLeader and squad) then
                ix.usms.HandleSquadLeaderVacancy(squadID)
            else
                ix.usms.SyncSquadToHUD(squadID)
            end
            
            if (callback) then callback(true) end
            hook.Run("USMSSquadMemberRemoved", charID, squadID, kickerCharID)
        end)
    query:Execute()
end
```

### Squad Leader Vacancy

```lua
--- Handle when a squad leader leaves or disconnects permanently.
function ix.usms.HandleSquadLeaderVacancy(squadID)
    local members = ix.usms.GetSquadMembers(squadID)
    local remainingCount = table.Count(members)
    
    if (remainingCount < USMS_SQUAD_MIN_SIZE) then
        -- Auto-disband
        ix.usms.DisbandSquad(squadID, nil)
        return
    end
    
    -- Promote most senior member
    local earliest = nil
    local earliestCharID = nil
    
    for charID, sm in pairs(members) do
        if (!earliest or sm.joinedAt < earliest) then
            earliest = sm.joinedAt
            earliestCharID = charID
        end
    end
    
    if (earliestCharID) then
        ix.usms.SetSquadLeader(squadID, earliestCharID)
    else
        ix.usms.DisbandSquad(squadID, nil)
    end
end
```

### Disbanding a Squad

```lua
--- Disband a squad entirely.
-- @param squadID number
-- @param disbandedByCharID number|nil Who disbanded (nil for system auto-disband)
function ix.usms.DisbandSquad(squadID, disbandedByCharID, callback)
    local squad = ix.usms.squads[squadID]
    if (!squad) then
        if (callback) then callback(false, "Squad not found") end
        return
    end
    
    -- Clear all squad members
    for charID, sm in pairs(ix.usms.squadMembers) do
        if (sm.squadID == squadID) then
            ix.usms.squadMembers[charID] = nil
            
            local char = ix.usms.GetCharacterByID(charID)
            if (char) then
                char:SetUsmSquadID(0)
                char:SetUsmSquadRole(0)
            end
        end
    end
    
    -- DB cleanup
    local delMembers = mysql:Delete("ix_usms_squad_members")
        delMembers:Where("squad_id", squadID)
    delMembers:Execute()
    
    local delSquad = mysql:Delete("ix_usms_squads")
        delSquad:Where("id", squadID)
        delSquad:Callback(function()
            local unitID = squad.unitID
            ix.usms.squads[squadID] = nil
            
            ix.usms.Log(unitID, USMS_LOG_SQUAD_DISBANDED, disbandedByCharID, nil, {squadName = squad.name, squadID = squadID})
            
            -- Notify members via HUD clear
            ix.usms.ClearSquadFromHUD(squadID, unitID)
            
            if (callback) then callback(true) end
            hook.Run("USMSSquadDisbanded", squadID, unitID, disbandedByCharID)
        end)
    delSquad:Execute()
end
```

---

## 10. Class / Loadout System

### Design

- Helix classes are now **permanent** — `CLASS.CanSwitchTo` is overridden to deny free switching.
- Class changes happen **only** through the USMS class change API (at a loadout locker entity or via admin command).
- Each class defines a `CLASS.loadout` table listing equipment item uniqueIDs and their resource costs.
- Class definitions live in the schema's `classes/` folder as normal, with added loadout fields.

### Class Definition Extension

In schema class files (e.g., `gamemodes/skeleton/schema/classes/sh_stormtrooper.lua`):

```lua
CLASS.name = "Stormtrooper"
CLASS.faction = FACTION_ARMY
CLASS.isDefault = true
CLASS.description = "Standard Imperial Stormtrooper."

-- USMS Loadout Definition
CLASS.loadout = {
    {uniqueID = "arccw_k_e11",    name = "E-11 Blaster Rifle",  cost = 10},
    {uniqueID = "cylinder1",       name = "Light Armor Kit",      cost = 5},
    {uniqueID = "thermal_det",     name = "Thermal Detonator",    cost = 4, quantity = 2},
}

-- Total gear-up cost: 23 resources (auto-calculated)
-- CLASS.loadoutCost is computed at runtime from the loadout table

CLASS_STORMTROOPER = CLASS.index
```

### Override Free Class Switching

In `sv_plugin.lua`:

```lua
--- Prevent free class switching. Classes are controlled by USMS.
function PLUGIN:CanPlayerJoinClass(ply, class, info)
    -- Always deny the default class switch menu
    return false, "Class changes must be performed at a loadout locker."
end
```

### Class Change API

```lua
--- Change a character's class. Must be validated externally (locker proximity, permissions).
-- @param charID number Character ID
-- @param classIndex number Target class index (ix.class.list index)
-- @param authorizerCharID number|nil Who authorized (CO/XO charID, or nil for self-service locker)
-- @param callback function(success, error)
function ix.usms.ChangeClass(charID, classIndex, authorizerCharID, callback)
    local char = ix.usms.GetCharacterByID(charID)
    if (!char) then
        if (callback) then callback(false, "Character not found or offline") end
        return
    end
    
    local classInfo = ix.class.list[classIndex]
    if (!classInfo) then
        if (callback) then callback(false, "Invalid class") end
        return
    end
    
    -- Faction check
    if (classInfo.faction != char:GetFaction()) then
        if (callback) then callback(false, "Class belongs to a different faction") end
        return
    end
    
    -- Same class check
    if (char:GetClass() == classIndex) then
        if (callback) then callback(false, "Already this class") end
        return
    end
    
    -- Hook for additional checks (cert requirements, cooldowns, etc.)
    local canChange, reason = hook.Run("USMSCanChangeClass", char, classIndex, authorizerCharID)
    if (canChange == false) then
        if (callback) then callback(false, reason or "Not authorized") end
        return
    end
    
    local oldClass = char:GetClass()
    
    -- Set the class
    char:SetClass(classIndex)
    
    -- Log
    local member = ix.usms.members[charID]
    if (member) then
        ix.usms.Log(member.unitID, USMS_LOG_UNIT_CLASS_CHANGED, authorizerCharID, charID, {
            oldClass = oldClass,
            newClass = classIndex,
            className = classInfo.name
        })
    end
    
    if (callback) then callback(true) end
    hook.Run("USMSClassChanged", charID, oldClass, classIndex, authorizerCharID)
end
```

### Computing Loadout Cost

```lua
--- Get the total resource cost for a class loadout.
-- @param classIndex number
-- @return number totalCost
function ix.usms.GetLoadoutCost(classIndex)
    local classInfo = ix.class.list[classIndex]
    if (!classInfo or !classInfo.loadout) then return 0 end
    
    local total = 0
    for _, item in ipairs(classInfo.loadout) do
        local qty = item.quantity or 1
        total = total + (item.cost * qty)
    end
    return total
end

--- Get loadout items for a class.
-- @param classIndex number
-- @return table loadout items
function ix.usms.GetClassLoadout(classIndex)
    local classInfo = ix.class.list[classIndex]
    if (!classInfo) then return {} end
    return classInfo.loadout or {}
end
```

---

## 11. Resource System

Resources are a **single global integer per unit**. Simple by design — a separate logistics system will manage complex resource flows later.

### API

```lua
--- Get a unit's current resources.
function ix.usms.GetResources(unitID)
    local unit = ix.usms.units[unitID]
    return unit and unit.resources or 0
end

--- Set a unit's resources (clamped to 0..cap).
-- @param unitID number
-- @param amount number New resource amount
-- @param reason string Log reason
-- @param actorCharID number|nil Who caused the change
function ix.usms.SetResources(unitID, amount, reason, actorCharID)
    local unit = ix.usms.units[unitID]
    if (!unit) then return false end
    
    local oldAmount = unit.resources
    amount = math.Clamp(amount, 0, unit.resourceCap)
    unit.resources = amount
    
    -- DB update
    local query = mysql:Update("ix_usms_units")
        query:Update("resources", amount)
        query:Where("id", unitID)
    query:Execute()
    
    -- Log
    ix.usms.Log(unitID, USMS_LOG_UNIT_RESOURCE_CHANGE, actorCharID, nil, {
        oldAmount = oldAmount,
        newAmount = amount,
        delta = amount - oldAmount,
        reason = reason or "unknown"
    })
    
    -- Notify unit members of resource change
    ix.usms.SyncResourceToUnit(unitID)
    
    hook.Run("USMSResourcesChanged", unitID, oldAmount, amount, reason)
    
    return true
end

--- Add resources to a unit.
function ix.usms.AddResources(unitID, amount, reason, actorCharID)
    local current = ix.usms.GetResources(unitID)
    return ix.usms.SetResources(unitID, current + amount, reason, actorCharID)
end

--- Deduct resources from a unit. Returns false if insufficient.
function ix.usms.DeductResources(unitID, amount, reason, actorCharID)
    local current = ix.usms.GetResources(unitID)
    if (current < amount) then return false end
    return ix.usms.SetResources(unitID, current - amount, reason, actorCharID)
end
```

### Resource Sync to Clients

```lua
--- Send resource update to all online unit members.
function ix.usms.SyncResourceToUnit(unitID)
    local unit = ix.usms.units[unitID]
    if (!unit) then return end
    
    local recipients = ix.usms.GetOnlineUnitMembers(unitID)
    if (#recipients == 0) then return end
    
    net.Start("ixUSMSUnitUpdate")
        net.WriteUInt(unitID, 32)
        net.WriteString("resources")
        net.WriteUInt(unit.resources, 32)
        net.WriteUInt(unit.resourceCap, 32)
    net.Send(recipients)
end
```

### Resource Visibility Rules

- **CO, XO:** See exact numbers in the menu.
- **Members:** See a general status string:
  - `>= 75%` of cap: `"WELL SUPPLIED"`
  - `>= 40%` of cap: `"ADEQUATE"`
  - `>= 15%` of cap: `"LOW"`
  - `< 15%` of cap: `"CRITICAL"`
- **ISB (cross-faction):** See exact numbers (controlled via `USMSCanViewIntel` hook, gated by future rank system).

```lua
-- Shared utility
function ix.usms.GetResourceStatus(resources, cap)
    if (cap == 0) then return "UNKNOWN" end
    local pct = resources / cap
    if (pct >= 0.75) then return "WELL SUPPLIED"
    elseif (pct >= 0.40) then return "ADEQUATE"
    elseif (pct >= 0.15) then return "LOW"
    else return "CRITICAL" end
end
```

---

## 12. Equipment Catalogs

Defined in `libs/sh_catalogs.lua`. Two layers:

### Global Catalog

Available to all factions. Basic equipment.

```lua
ix.usms.catalogs = ix.usms.catalogs or {}
ix.usms.catalogs.global = {}
ix.usms.catalogs.faction = {}

--- Register a global catalog item.
-- @param uniqueID string Helix item uniqueID
-- @param data table {name, cost, category}
function ix.usms.RegisterGlobalItem(uniqueID, data)
    ix.usms.catalogs.global[uniqueID] = {
        uniqueID = uniqueID,
        name = data.name or uniqueID,
        cost = data.cost or 0,
        category = data.category or "General"
    }
end

--- Register a faction-specific catalog item.
-- @param factionID number Helix faction index
-- @param uniqueID string Helix item uniqueID
-- @param data table {name, cost, category}
function ix.usms.RegisterFactionItem(factionID, uniqueID, data)
    if (!ix.usms.catalogs.faction[factionID]) then
        ix.usms.catalogs.faction[factionID] = {}
    end
    
    ix.usms.catalogs.faction[factionID][uniqueID] = {
        uniqueID = uniqueID,
        name = data.name or uniqueID,
        cost = data.cost or 0,
        category = data.category or "Specialized"
    }
end

--- Get all catalog items available to a faction (global + faction-specific).
function ix.usms.GetAvailableCatalog(factionID)
    local catalog = table.Copy(ix.usms.catalogs.global)
    
    if (ix.usms.catalogs.faction[factionID]) then
        table.Merge(catalog, ix.usms.catalogs.faction[factionID])
    end
    
    return catalog
end
```

### Catalog Registration Example

In `libs/sh_catalogs.lua` after the API:

```lua
-- ═══════════════════════════════════════════════════════════════════════════
-- GLOBAL CATALOG
-- ═══════════════════════════════════════════════════════════════════════════
ix.usms.RegisterGlobalItem("arccw_k_e11", {
    name = "E-11 Blaster Rifle",
    cost = 10,
    category = "Primary Weapons"
})

ix.usms.RegisterGlobalItem("cylinder1", {
    name = "Light Armor Kit",
    cost = 5,
    category = "Armor"
})

ix.usms.RegisterGlobalItem("thermal_det", {
    name = "Thermal Detonator",
    cost = 4,
    category = "Ordnance"
})

-- ═══════════════════════════════════════════════════════════════════════════
-- FACTION CATALOGS
-- ═══════════════════════════════════════════════════════════════════════════
-- These reference FACTION_* globals which are set in schema/factions/

-- Example: Army-specific items
-- ix.usms.RegisterFactionItem(FACTION_ARMY, "army_heavy_blaster", {
--     name = "T-21 Heavy Repeater",
--     cost = 25,
--     category = "Heavy Weapons"
-- })
```

> **Note:** Catalog registration happens on both client and server (shared file). The item `uniqueID` values must match actual Helix item definitions in your schema's `items/` directory.

---

## 13. Gear-Up API (Armory)

The gear-up system grants loadout items to a character and deducts resources. It is **API-only** for now — the armory entity will be created separately and will call this API.

### API

```lua
--- Gear up a character with their class loadout.
-- Checks: character has a class, is in a unit, unit has resources, character doesn't already have items.
-- @param ply Player The player entity
-- @param callback function(success, error, itemsGranted, cost)
function ix.usms.GearUp(ply, callback)
    local char = ply:GetCharacter()
    if (!char) then
        if (callback) then callback(false, "No character") end
        return
    end
    
    local classIndex = char:GetClass()
    if (!classIndex or classIndex == 0) then
        if (callback) then callback(false, "No class assigned") end
        return
    end
    
    local classInfo = ix.class.list[classIndex]
    if (!classInfo or !classInfo.loadout) then
        if (callback) then callback(false, "Class has no loadout defined") end
        return
    end
    
    local member = ix.usms.members[char:GetID()]
    if (!member) then
        if (callback) then callback(false, "Not in a unit") end
        return
    end
    
    local unitID = member.unitID
    local unit = ix.usms.units[unitID]
    
    -- Determine which items need to be granted (don't grant duplicates already in inventory)
    local inventory = char:GetInventory()
    if (!inventory) then
        if (callback) then callback(false, "No inventory") end
        return
    end
    
    local neededItems = {}
    local totalCost = 0
    
    for _, loadoutEntry in ipairs(classInfo.loadout) do
        local qty = loadoutEntry.quantity or 1
        
        -- Count how many of this item the player already has
        local existing = 0
        for _, invItem in pairs(inventory:GetItems()) do
            if (invItem.uniqueID == loadoutEntry.uniqueID) then
                existing = existing + 1
            end
        end
        
        local needed = math.max(0, qty - existing)
        if (needed > 0) then
            table.insert(neededItems, {
                uniqueID = loadoutEntry.uniqueID,
                name = loadoutEntry.name,
                cost = loadoutEntry.cost,
                quantity = needed
            })
            totalCost = totalCost + (loadoutEntry.cost * needed)
        end
    end
    
    if (#neededItems == 0) then
        if (callback) then callback(false, "Already fully equipped") end
        return
    end
    
    -- Check unit resources
    if (unit.resources < totalCost) then
        if (callback) then callback(false, "Insufficient unit resources (" .. totalCost .. " needed, " .. unit.resources .. " available)") end
        return
    end
    
    -- Hook for additional checks
    local canGearUp, reason = hook.Run("USMSCanGearUp", ply, char, neededItems, totalCost)
    if (canGearUp == false) then
        if (callback) then callback(false, reason or "Gear-up denied") end
        return
    end
    
    -- Deduct resources
    ix.usms.DeductResources(unitID, totalCost, "gearup:" .. classInfo.name, char:GetID())
    
    -- Grant items
    local granted = {}
    for _, item in ipairs(neededItems) do
        for i = 1, item.quantity do
            inventory:Add(item.uniqueID, 1, nil, nil, true) -- add silently
            table.insert(granted, item.uniqueID)
        end
    end
    
    -- Log
    ix.usms.Log(unitID, USMS_LOG_GEARUP, char:GetID(), nil, {
        class = classInfo.name,
        items = granted,
        cost = totalCost
    })
    
    if (callback) then callback(true, nil, granted, totalCost) end
    hook.Run("USMSGearUp", ply, char, granted, totalCost)
end
```

### Testing Commands (Pre-Entity)

See [Section 20: Testing Commands](#20-testing-commands) for test commands that simulate armory interactions.

---

## 14. Logging System

Dual-purpose: admin oversight + in-RP intelligence.

### Implementation

In `libs/sv_logging.lua`:

```lua
--- Add a USMS log entry (writes to DB + fires Helix ix.log).
-- @param unitID number
-- @param action string USMS_LOG_* constant
-- @param actorCharID number|nil
-- @param targetCharID number|nil
-- @param data table|nil Additional context
function ix.usms.Log(unitID, action, actorCharID, targetCharID, data)
    -- Write to DB
    local query = mysql:Insert("ix_usms_logs")
        query:Insert("unit_id", unitID)
        query:Insert("action", action)
        if (actorCharID) then query:Insert("actor_char_id", actorCharID) end
        if (targetCharID) then query:Insert("target_char_id", targetCharID) end
        query:Insert("data", data and util.TableToJSON(data) or "")
        query:Insert("timestamp", os.time())
    query:Execute()
    
    -- Also fire through Helix's logging system for admin visibility
    local actorName = "System"
    local targetName = ""
    
    if (actorCharID) then
        local char = ix.usms.GetCharacterByID(actorCharID)
        actorName = char and char:GetName() or ("CharID:" .. actorCharID)
    end
    
    if (targetCharID) then
        local char = ix.usms.GetCharacterByID(targetCharID)
        targetName = char and char:GetName() or ("CharID:" .. targetCharID)
    end
    
    local unit = ix.usms.units[unitID]
    local unitName = unit and unit.name or ("UnitID:" .. unitID)
    
    local logStr = string.format("[USMS] %s | %s | Actor: %s | Target: %s", unitName, action, actorName, targetName)
    ix.log.AddRaw(logStr)
end
```

### Log Query API

```lua
--- Fetch logs for a unit from DB.
-- @param unitID number
-- @param options table {limit, offset, action, startTime, endTime}
-- @param callback function(logs)
function ix.usms.GetLogs(unitID, options, callback)
    options = options or {}
    
    local query = mysql:Select("ix_usms_logs")
        query:Where("unit_id", unitID)
        
        if (options.action) then
            query:Where("action", options.action)
        end
        
        if (options.startTime) then
            query:WhereGTE("timestamp", options.startTime)
        end
        
        if (options.endTime) then
            query:WhereLTE("timestamp", options.endTime)
        end
        
        query:OrderByDesc("timestamp")
        
        if (options.limit) then
            query:Limit(options.limit)
        else
            query:Limit(100) -- default
        end
        
        if (options.offset) then
            query:Offset(options.offset)
        end
        
        query:Callback(function(result)
            if (!istable(result)) then
                callback({})
                return
            end
            
            -- Parse JSON data fields
            for _, row in ipairs(result) do
                row.data = row.data and util.JSONToTable(row.data) or {}
                row.timestamp = tonumber(row.timestamp) or 0
                row.unit_id = tonumber(row.unit_id) or 0
                row.actor_char_id = tonumber(row.actor_char_id)
                row.target_char_id = tonumber(row.target_char_id)
            end
            
            callback(result)
        end)
    query:Execute()
end
```

### Log Pruning

```lua
--- Prune old logs. Called on plugin initialization.
function ix.usms.PruneLogs(maxAgeDays)
    maxAgeDays = maxAgeDays or 60
    local cutoff = os.time() - (maxAgeDays * 86400)
    
    local query = mysql:Delete("ix_usms_logs")
        query:WhereLT("timestamp", cutoff)
    query:Execute()
end
```

### Helix Log Types

Register USMS-specific log types with Helix's system for admin log viewer:

```lua
ix.log.AddType("usmsUnitMemberJoin", function(client, unitName, charName)
    return string.format("[USMS] %s joined unit %s", charName, unitName)
end, FLAG_NORMAL)

ix.log.AddType("usmsUnitMemberLeave", function(client, unitName, charName)
    return string.format("[USMS] %s left unit %s", charName, unitName)
end, FLAG_NORMAL)

ix.log.AddType("usmsGearUp", function(client, unitName, charName, cost)
    return string.format("[USMS] %s geared up from %s (cost: %d)", charName, unitName, cost)
end, FLAG_NORMAL)

-- Add more as needed
```

---

## 15. Roster System

The roster replaces external tools (Google Sheets, Discord bots). It's the primary value proposition of the menu.

### Server-Side Roster Data

When a player opens their unit tab, the server sends the full roster:

```lua
--- Build and send roster data for a unit to a player.
-- @param ply Player Requesting player
-- @param unitID number
function ix.usms.SendRoster(ply, unitID)
    local unit = ix.usms.units[unitID]
    if (!unit) then return end
    
    -- Build roster from members cache + enriching with character data
    local roster = {}
    
    for charID, member in pairs(ix.usms.members) do
        if (member.unitID != unitID) then continue end
        
        local entry = {
            charID = charID,
            role = member.role,
            joinedAt = member.joinedAt,
            squadID = 0,
            squadRole = 0,
            isOnline = false,
            name = "Unknown",
            class = 0,
            className = "Unassigned",
            lastSeen = member.joinedAt  -- fallback
        }
        
        -- Check if online and enrich
        local memberPly = ix.usms.GetPlayerByCharID(charID)
        if (IsValid(memberPly)) then
            local char = memberPly:GetCharacter()
            if (char) then
                entry.isOnline = true
                entry.name = char:GetName()
                entry.class = char:GetClass() or 0
                
                local classInfo = ix.class.list[entry.class]
                entry.className = classInfo and classInfo.name or "Unassigned"
            end
        else
            -- Offline: need to read from DB or cache
            -- For MVP: store name/class in the members cache when they log in
            -- The cache is populated in PlayerLoadedCharacter hook
            entry.name = member.cachedName or "Unknown"
            entry.class = member.cachedClass or 0
            entry.className = member.cachedClassName or "Unassigned"
            entry.lastSeen = member.cachedLastSeen or member.joinedAt
        end
        
        -- Squad info
        local sm = ix.usms.squadMembers[charID]
        if (sm) then
            entry.squadID = sm.squadID
            entry.squadRole = sm.role
        end
        
        table.insert(roster, entry)
    end
    
    -- Send via net (use SFS for efficient serialization)
    local encoded = ix.usms.sfs.encode(roster)
    
    net.Start("ixUSMSRosterSync")
        net.WriteUInt(unitID, 32)
        net.WriteUInt(#encoded, 32)
        net.WriteData(encoded, #encoded)
    net.Send(ply)
end
```

> **SFS Usage:** The `sfs` library (`gamemodes/skeleton/schema/libs/sfs.lua`, version 7.0.7) provides efficient binary serialization. Use `sfs.encode(table)` and `sfs.decode(string)` for roster data to minimize net message size. The library supports tables, strings, numbers, bools, vectors, angles, colors, entities, and players natively.

### Caching Offline Member Data

In `sv_plugin.lua`:

```lua
--- When a character loads, cache their info for roster display when offline.
function PLUGIN:PlayerLoadedCharacter(ply, char)
    local charID = char:GetID()
    local member = ix.usms.members[charID]
    
    if (member) then
        member.cachedName = char:GetName()
        member.cachedClass = char:GetClass() or 0
        
        local classInfo = ix.class.list[member.cachedClass]
        member.cachedClassName = classInfo and classInfo.name or "Unassigned"
        member.cachedLastSeen = os.time()
        
        -- Sync the player their unit data
        ix.usms.SyncUnitToPlayer(ply, member.unitID)
        
        -- If in a squad, sync HUD
        local sm = ix.usms.squadMembers[charID]
        if (sm) then
            ix.usms.SyncSquadToHUD(sm.squadID)
        end
    end
end

--- When a player disconnects, update last seen.
function PLUGIN:PlayerDisconnected(ply)
    local char = ply:GetCharacter()
    if (!char) then return end
    
    local charID = char:GetID()
    local member = ix.usms.members[charID]
    
    if (member) then
        member.cachedLastSeen = os.time()
    end
end
```

---

## 16. Cross-Faction Intelligence (ISB)

Certain factions (ISB) can view other factions' unit rosters and resource levels. This is gated by a hook that the future rank system will populate.

### Hook

```lua
--- Hook: USMSCanViewIntel
-- @param ply Player The requesting player
-- @param char Character Their character
-- @param targetUnitID number The unit they want to view
-- @return bool|nil Whether they can view. nil falls through to next hook.
-- @return string|nil Reason for denial
hook.Add("USMSCanViewIntel", "ixUSMSDefaultIntel", function(ply, char, targetUnitID)
    local targetUnit = ix.usms.units[targetUnitID]
    if (!targetUnit) then return false, "Unit not found" end
    
    -- Same faction: always can view own faction's units
    if (char:GetFaction() == targetUnit.factionID) then
        return true
    end
    
    -- Cross-faction: check faction config
    local faction = ix.faction.indices[char:GetFaction()]
    if (faction and faction.canViewAllRosters) then
        return true
    end
    
    -- Future: rank-specific check goes here
    -- if (char:HasCertification("intel_access")) then return true end
    
    return false, "Unauthorized"
end)
```

### Faction Configuration

In faction definition files, add:

```lua
-- In schema/factions/sh_isb.lua (example)
FACTION.name = "Imperial Security Bureau"
FACTION.canViewAllRosters = true    -- USMS: can view all unit rosters cross-faction
-- ...
```

### Intel Request Handler

```lua
ix.usms.requestHandlers["intel_roster_request"] = function(ply, char, data)
    local targetUnitID = tonumber(data.unitID)
    if (!targetUnitID) then return end
    
    local canView, reason = hook.Run("USMSCanViewIntel", ply, char, targetUnitID)
    if (!canView) then
        -- Optionally notify player of denial
        return
    end
    
    -- Send the roster for the target unit
    ix.usms.SendRoster(ply, targetUnitID)
    
    -- Also send resource data if authorized
    local unit = ix.usms.units[targetUnitID]
    if (unit) then
        net.Start("ixUSMSIntelSync")
            net.WriteUInt(targetUnitID, 32)
            net.WriteString(unit.name)
            net.WriteUInt(unit.resources, 32)
            net.WriteUInt(unit.resourceCap, 32)
            net.WriteUInt(ix.usms.GetUnitMemberCount(targetUnitID), 16)
        net.Send(ply)
    end
end
```

---

## 17. HUD Integration

The diegetic HUD (`gamemodes/skeleton/plugins/diagetichud/`) continues to work as-is. The USMS bridges data between the persistent squad system and the HUD's ephemeral `squadData`.

### Bridge: USMS Squad -> HUD Squad

```lua
--- Sync a USMS squad's online members to the diegetic HUD system.
-- This calls ix.diegeticHUD.CreateSquad or SyncSquad to update HUD data.
function ix.usms.SyncSquadToHUD(squadID)
    local squad = ix.usms.squads[squadID]
    if (!squad) then return end
    
    -- Gather online squad members
    local members = {}
    for charID, sm in pairs(ix.usms.squadMembers) do
        if (sm.squadID == squadID) then
            local ply = ix.usms.GetPlayerByCharID(charID)
            if (IsValid(ply)) then
                table.insert(members, ply)
            end
        end
    end
    
    if (#members == 0) then
        -- No online members, disband HUD squad if it exists
        if (ix.diegeticHUD.squads["usms_" .. squadID]) then
            ix.diegeticHUD.DisbandSquad("usms_" .. squadID)
        end
        return
    end
    
    -- Create or update the HUD squad
    local hudSquadID = "usms_" .. squadID
    
    if (ix.diegeticHUD.squads[hudSquadID]) then
        -- Update existing: resync members
        local existingSquad = ix.diegeticHUD.squads[hudSquadID]
        existingSquad.members = members
        ix.diegeticHUD.SyncSquad(hudSquadID)
    else
        -- Create new
        ix.diegeticHUD.CreateSquad(hudSquadID, squad.name, members)
    end
end

--- Clear a USMS squad from the HUD.
function ix.usms.ClearSquadFromHUD(squadID, unitID)
    local hudSquadID = "usms_" .. squadID
    if (ix.diegeticHUD.squads[hudSquadID]) then
        ix.diegeticHUD.DisbandSquad(hudSquadID)
    end
end
```

### Periodic HUD Sync

Since the HUD shows health/position which changes constantly, a periodic sync is needed:

```lua
-- In sv_plugin.lua
timer.Create("ixUSMSHUDSync", 3, 0, function()
    for squadID, squad in pairs(ix.usms.squads) do
        local hudSquadID = "usms_" .. squadID
        if (ix.diegeticHUD.squads[hudSquadID]) then
            ix.diegeticHUD.SyncSquad(hudSquadID)
        end
    end
end)
```

### Comms Channel Integration

When a player joins a squad, auto-connect them to the squad comms channel:

```lua
hook.Add("USMSSquadMemberAdded", "ixUSMSComms", function(charID, squadID)
    local ply = ix.usms.GetPlayerByCharID(charID)
    if (!IsValid(ply)) then return end
    
    local squad = ix.usms.squads[squadID]
    if (!squad) then return end
    
    -- Send comms channel assignment
    ix.diegeticHUD.SendTransmission(ply, "SQUAD COMMS", "4521.5", true, 2)
end)
```

---

## 18. Tab Menu UI

### Registration

In `derma/cl_usms_tab.lua`:

```lua
hook.Add("CreateMenuButtons", "ixUSMS", function(tabs)
    local char = LocalPlayer():GetCharacter()
    if (!char) then return end
    
    -- Only show if the character is in a unit
    -- (or could show a "not assigned" state for everyone)
    tabs["deployment"] = function(container)
        local panel = container:Add("ixUSMSMainPanel")
        panel:Dock(FILL)
    end
end)
```

> **Tab name:** `"deployment"` — will display as "DEPLOYMENT" in uppercase in the tab bar (matches Imperial aesthetic). This follows the same pattern as `tabs["you"]`, `tabs["scoreboard"]`, `tabs["classes"]`, etc.

### Theme & Styling

**All USMS derma panels MUST use the established theme.** The THEME table and helper functions are currently copy-pasted across every file. For USMS panels, copy the same pattern:

```lua
-- At top of each derma file:
local THEME = {
    background = Color(10, 10, 10, 255),
    frame = Color(191, 148, 53, 255),
    frameSoft = Color(191, 148, 53, 120),
    text = Color(235, 235, 235, 255),
    textMuted = Color(168, 168, 168, 140),
    accent = Color(191, 148, 53, 255),
    accentSoft = Color(191, 148, 53, 220),
    buttonBg = Color(16, 16, 16, 255),
    buttonBgHover = Color(26, 26, 26, 255),
    rowEven = Color(14, 14, 14, 255),
    rowOdd = Color(18, 18, 18, 255),
    rowHover = Color(24, 22, 14, 255),
    danger = Color(180, 60, 60, 255),
    ready = Color(60, 170, 90, 255)
}

local function Scale(value)
    return math.max(1, math.Round(value * (ScrH() / 900)))
end
```

### Available Fonts

Pre-registered in `impmainmenu/cl_menu.lua`:

| Font Name | Family | Size | Use For |
|-----------|--------|------|---------|
| `ixImpMenuTitle` | Times New Roman | Scale(64) | Large headers |
| `ixImpMenuSubtitle` | Times New Roman | Scale(16) | Subheaders |
| `ixImpMenuLabel` | Roboto | Scale(12) | Tab labels, small labels |
| `ixImpMenuButton` | Roboto | Scale(16) | Button text, row names |
| `ixImpMenuStatus` | Roboto | Scale(11) | Status indicators |
| `ixImpMenuAurebesh` | Aurebesh | Scale(12) | Decorative Aurebesh text |
| `ixImpMenuDiag` | Roboto Condensed | Scale(11) | Diagnostic text, descriptions |

### Main Panel Structure

```
ixUSMSMainPanel (EditablePanel, fills container)
├── Left sidebar (25% width)
│   ├── Unit info section
│   │   ├── Unit name + faction
│   │   ├── Resource status
│   │   └── Member count
│   ├── Squad section
│   │   ├── Current squad name + members
│   │   ├── Create squad button (if eligible)
│   │   └── Leave squad button
│   └── Loadout section
│       ├── Current class name
│       ├── Loadout items list
│       └── Equipment status
└── Right content area (75% width)
    ├── Tab bar: [ROSTER] [SQUADS] [LOGS]
    ├── Roster view (default)
    │   ├── Column headers: NAME | CLASS | SQUAD | STATUS | JOINED
    │   ├── Sortable rows (ixUSMSRosterRow)
    │   └── Search/filter bar
    ├── Squads view
    │   ├── Squad cards (name, SL, member count)
    │   └── Squad detail on click
    └── Logs view (CO/XO/ISB only)
        ├── Filter bar (action type, date range)
        └── Scrollable log entries
```

### Derma Panel Registration Pattern

Each panel follows `vgui.Register("ixPanelName", PANEL, "EditablePanel")`.

Example skeleton for the roster row:

```lua
-- derma/cl_unit_roster.lua
local ROW = {}

function ROW:Init()
    self:SetTall(Scale(32))
    self.rowIndex = 0
end

function ROW:SetMemberData(data)
    self.data = data
    self:SetupLayout()
end

function ROW:SetupLayout()
    -- Name column
    self.nameLabel = self:Add("DLabel")
    self.nameLabel:SetFont("ixImpMenuButton")
    self.nameLabel:SetTextColor(THEME.text)
    
    -- Class column
    self.classLabel = self:Add("DLabel")
    self.classLabel:SetFont("ixImpMenuDiag")
    self.classLabel:SetTextColor(THEME.textMuted)
    
    -- Status indicator (online/offline dot)
    self.statusDot = self:Add("Panel")
    -- etc.
end

function ROW:Paint(w, h)
    local bg = self.bHovered and THEME.rowHover
        or (self.rowIndex % 2 == 0 and THEME.rowEven or THEME.rowOdd)
    surface.SetDrawColor(bg)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(THEME.frameSoft.r, THEME.frameSoft.g, THEME.frameSoft.b, 30)
    surface.DrawRect(0, h - 1, w, 1)
end

vgui.Register("ixUSMSRosterRow", ROW, "EditablePanel")
```

### Client-Side State

In `cl_plugin.lua`, maintain the client-side cache that derma reads from:

```lua
ix.usms.clientData = ix.usms.clientData or {
    unit = nil,       -- Current unit data table
    roster = {},      -- Array of member entries
    squads = {},      -- [squadID] = squad data
    logs = {},        -- Array of log entries (sorted desc by time)
    intelUnits = {}   -- [unitID] = unit data for cross-faction viewing
}

-- Net receivers that populate clientData
net.Receive("ixUSMSUnitSync", function()
    local unitID = net.ReadUInt(32)
    ix.usms.clientData.unit = {
        id = unitID,
        name = net.ReadString(),
        description = net.ReadString(),
        factionID = net.ReadUInt(8),
        resources = net.ReadUInt(32),
        resourceCap = net.ReadUInt(32),
        maxMembers = net.ReadUInt(16),
        maxSquads = net.ReadUInt(8)
    }
end)

net.Receive("ixUSMSRosterSync", function()
    local unitID = net.ReadUInt(32)
    local dataLen = net.ReadUInt(32)
    local data = net.ReadData(dataLen)
    
    local sfs = include("libs/sfs.lua") -- or access via cached reference
    local roster = sfs.decode(data)
    
    if (ix.usms.clientData.unit and ix.usms.clientData.unit.id == unitID) then
        ix.usms.clientData.roster = roster or {}
    end
end)

net.Receive("ixUSMSUnitUpdate", function()
    local unitID = net.ReadUInt(32)
    local field = net.ReadString()
    
    if (field == "resources") then
        local resources = net.ReadUInt(32)
        local cap = net.ReadUInt(32)
        
        if (ix.usms.clientData.unit and ix.usms.clientData.unit.id == unitID) then
            ix.usms.clientData.unit.resources = resources
            ix.usms.clientData.unit.resourceCap = cap
        end
    end
end)
```

---

## 19. Admin Commands & Overrides

In `commands/sh_admin.lua`:

```lua
-- ═══════════════════════════════════════════════════════════════════════════
-- SUPERADMIN: Unit Management
-- ═══════════════════════════════════════════════════════════════════════════

ix.command.Add("UnitCreate", {
    description = "Create a new unit in a faction.",
    superAdminOnly = true,
    arguments = {
        ix.type.text  -- "faction_name unit_name"
    },
    OnRun = function(self, ply, text)
        -- Parse "FactionName UnitName"
        local args = string.Explode(" ", text, true)
        -- ... validation, call ix.usms.CreateUnit
    end
})

ix.command.Add("UnitDelete", {
    description = "Delete a unit and all its data.",
    superAdminOnly = true,
    arguments = { ix.type.number },
    OnRun = function(self, ply, unitID)
        ix.usms.DeleteUnit(unitID, function()
            ply:Notify("Unit deleted.")
        end)
    end
})

ix.command.Add("UnitSetResources", {
    description = "Set a unit's resource amount.",
    superAdminOnly = true,
    arguments = { ix.type.number, ix.type.number },
    OnRun = function(self, ply, unitID, amount)
        ix.usms.SetResources(unitID, amount, "admin_set", nil)
        ply:Notify("Resources set to " .. amount)
    end
})

ix.command.Add("UnitAddResources", {
    description = "Add resources to a unit.",
    adminOnly = true,
    arguments = { ix.type.number, ix.type.number },
    OnRun = function(self, ply, unitID, amount)
        ix.usms.AddResources(unitID, amount, "admin_add", nil)
        ply:Notify("Added " .. amount .. " resources.")
    end
})

-- ═══════════════════════════════════════════════════════════════════════════
-- ADMIN: Override Commands
-- ═══════════════════════════════════════════════════════════════════════════

ix.command.Add("UnitForceRemove", {
    description = "Force remove a player from their unit.",
    adminOnly = true,
    arguments = { ix.type.player },
    OnRun = function(self, ply, target)
        local char = target:GetCharacter()
        if (!char) then ply:Notify("Target has no character.") return end
        ix.usms.RemoveMember(char:GetID(), nil, function(ok, err)
            ply:Notify(ok and "Removed from unit." or ("Failed: " .. (err or "unknown")))
        end)
    end
})

ix.command.Add("SquadForceDisband", {
    description = "Force disband a squad by ID.",
    adminOnly = true,
    arguments = { ix.type.number },
    OnRun = function(self, ply, squadID)
        ix.usms.DisbandSquad(squadID, nil, function(ok, err)
            ply:Notify(ok and "Squad disbanded." or ("Failed: " .. (err or "unknown")))
        end)
    end
})

ix.command.Add("UnitTransferCO", {
    description = "Force transfer CO status to another member.",
    adminOnly = true,
    arguments = { ix.type.number, ix.type.player }, -- unitID, new CO
    OnRun = function(self, ply, unitID, target)
        local char = target:GetCharacter()
        if (!char) then ply:Notify("Target has no character.") return end
        -- Demote current CO, promote target
        ix.usms.TransferCO(unitID, char:GetID(), function(ok, err)
            ply:Notify(ok and "CO transferred." or ("Failed: " .. (err or "unknown")))
        end)
    end
})

ix.command.Add("UnitList", {
    description = "List all units.",
    adminOnly = true,
    OnRun = function(self, ply)
        for id, unit in pairs(ix.usms.units) do
            local faction = ix.faction.indices[unit.factionID]
            local factionName = faction and faction.name or "Unknown"
            local memberCount = ix.usms.GetUnitMemberCount(id)
            ply:ChatPrint(string.format("[%d] %s (%s) - %d members, %d resources",
                id, unit.name, factionName, memberCount, unit.resources))
        end
    end
})

ix.command.Add("UnitInvite", {
    description = "Admin-invite a player to a unit.",
    adminOnly = true,
    arguments = { ix.type.player, ix.type.number },
    OnRun = function(self, ply, target, unitID)
        local char = target:GetCharacter()
        if (!char) then ply:Notify("Target has no character.") return end
        ix.usms.AddMember(char:GetID(), unitID, USMS_ROLE_MEMBER, function(ok, err)
            ply:Notify(ok and "Player invited to unit." or ("Failed: " .. (err or "unknown")))
        end)
    end
})

ix.command.Add("UnitSetRole", {
    description = "Set a player's unit role (0=member, 1=XO, 2=CO).",
    adminOnly = true,
    arguments = { ix.type.player, ix.type.number },
    OnRun = function(self, ply, target, role)
        local char = target:GetCharacter()
        if (!char) then ply:Notify("Target has no character.") return end
        ix.usms.SetMemberRole(char:GetID(), role, function(ok, err)
            ply:Notify(ok and "Role updated." or ("Failed: " .. (err or "unknown")))
        end)
    end
})
```

---

## 20. Testing Commands

In `commands/sh_testing.lua`. These simulate interactions that will later be handled by entities (armory locker, etc.):

```lua
ix.command.Add("USMSTestGearUp", {
    description = "[DEV] Simulate gear-up from armory.",
    adminOnly = true,
    OnRun = function(self, ply)
        ix.usms.GearUp(ply, function(ok, err, items, cost)
            if (ok) then
                ply:Notify("Geared up! Cost: " .. cost .. " resources. Items: " .. #items)
            else
                ply:Notify("Gear-up failed: " .. (err or "unknown"))
            end
        end)
    end
})

ix.command.Add("USMSTestClassChange", {
    description = "[DEV] Simulate class change at loadout locker.",
    adminOnly = true,
    arguments = { ix.type.number },
    OnRun = function(self, ply, classIndex)
        local char = ply:GetCharacter()
        if (!char) then return end
        
        ix.usms.ChangeClass(char:GetID(), classIndex, nil, function(ok, err)
            if (ok) then
                ply:Notify("Class changed to " .. (ix.class.list[classIndex] and ix.class.list[classIndex].name or classIndex))
            else
                ply:Notify("Class change failed: " .. (err or "unknown"))
            end
        end)
    end
})

ix.command.Add("USMSTestCreateSquad", {
    description = "[DEV] Create a test squad.",
    adminOnly = true,
    arguments = { bit.bor(ix.type.text, ix.type.optional) },
    OnRun = function(self, ply, name)
        name = name or "FIRETEAM AUREK"
        ix.usms.CreateSquad(ply, name, function(ok, result)
            if (ok) then
                ply:Notify("Squad created: " .. name .. " (ID: " .. result .. ")")
            else
                ply:Notify("Failed: " .. tostring(result))
            end
        end)
    end
})

ix.command.Add("USMSTestSquadInvite", {
    description = "[DEV] Invite a player to your squad.",
    adminOnly = true,
    arguments = { ix.type.player },
    OnRun = function(self, ply, target)
        local char = ply:GetCharacter()
        local targetChar = target:GetCharacter()
        if (!char or !targetChar) then return end
        
        local sm = ix.usms.squadMembers[char:GetID()]
        if (!sm) then ply:Notify("You are not in a squad.") return end
        
        ix.usms.AddToSquad(targetChar:GetID(), sm.squadID, function(ok, err)
            ply:Notify(ok and "Invited!" or ("Failed: " .. (err or "unknown")))
        end)
    end
})

ix.command.Add("USMSTestRoster", {
    description = "[DEV] Request your unit's roster.",
    adminOnly = true,
    OnRun = function(self, ply)
        local char = ply:GetCharacter()
        if (!char) then return end
        
        local member = ix.usms.members[char:GetID()]
        if (!member) then ply:Notify("Not in a unit.") return end
        
        ix.usms.SendRoster(ply, member.unitID)
        ply:Notify("Roster data sent to client.")
    end
})

ix.command.Add("USMSTestLogs", {
    description = "[DEV] Print recent unit logs to chat.",
    adminOnly = true,
    OnRun = function(self, ply)
        local char = ply:GetCharacter()
        if (!char) then return end
        
        local member = ix.usms.members[char:GetID()]
        if (!member) then ply:Notify("Not in a unit.") return end
        
        ix.usms.GetLogs(member.unitID, {limit = 10}, function(logs)
            for _, log in ipairs(logs) do
                ply:ChatPrint(string.format("[%s] %s | Actor: %s | Target: %s",
                    os.date("%H:%M:%S", log.timestamp),
                    log.action,
                    tostring(log.actor_char_id or "system"),
                    tostring(log.target_char_id or "-")
                ))
            end
        end)
    end
})

ix.command.Add("USMSCanSquad", {
    description = "[DEV] Grant/revoke squad creation permission to a player.",
    adminOnly = true,
    arguments = { ix.type.player },
    OnRun = function(self, ply, target)
        local current = target:GetNetVar("ixUSMSCanCreateSquad", false)
        target:SetNetVar("ixUSMSCanCreateSquad", !current)
        ply:Notify("Squad creation for " .. target:Nick() .. ": " .. tostring(!current))
    end
})

ix.command.Add("USMSDebugState", {
    description = "[DEV] Print USMS cache state to console.",
    adminOnly = true,
    OnRun = function(self, ply)
        print("=== USMS DEBUG STATE ===")
        print("Units: " .. table.Count(ix.usms.units))
        for id, unit in pairs(ix.usms.units) do
            print(string.format("  [%d] %s (faction %d, %d resources)", id, unit.name, unit.factionID, unit.resources))
        end
        print("Members: " .. table.Count(ix.usms.members))
        print("Squads: " .. table.Count(ix.usms.squads))
        print("Squad Members: " .. table.Count(ix.usms.squadMembers))
        ply:Notify("State printed to server console.")
    end
})
```

---

## 21. Hooks

All hooks fired by the USMS system. Other plugins can listen to these.

### Hook Reference

| Hook | Realm | Arguments | Description |
|------|-------|-----------|-------------|
| `USMSUnitCreated` | Server | `unitID, name, factionID` | Unit was created |
| `USMSUnitDeleted` | Server | `unitID` | Unit was deleted |
| `USMSMemberAdded` | Server | `charID, unitID, role` | Character joined a unit |
| `USMSMemberRemoved` | Server | `charID, unitID, kickerCharID` | Character left/kicked from unit |
| `USMSMemberRoleChanged` | Server | `charID, unitID, oldRole, newRole` | Unit role changed |
| `USMSSquadCreated` | Server | `squadID, unitID, leaderCharID` | Squad was created |
| `USMSSquadDisbanded` | Server | `squadID, unitID, disbandedByCharID` | Squad was disbanded |
| `USMSSquadMemberAdded` | Server | `charID, squadID` | Character joined a squad |
| `USMSSquadMemberRemoved` | Server | `charID, squadID, kickerCharID` | Character left/kicked from squad |
| `USMSSquadLeaderChanged` | Server | `squadID, oldLeaderCharID, newLeaderCharID` | Squad leader changed |
| `USMSResourcesChanged` | Server | `unitID, oldAmount, newAmount, reason` | Unit resources changed |
| `USMSGearUp` | Server | `ply, char, items, cost` | Player geared up |
| `USMSClassChanged` | Server | `charID, oldClass, newClass, authorizerCharID` | Class changed |
| `USMSCanCreateSquad` | Server | `ply, char, member` → `bool, reason` | Permission check for squad creation |
| `USMSCanGearUp` | Server | `ply, char, items, cost` → `bool, reason` | Permission check for gear-up |
| `USMSCanChangeClass` | Server | `char, classIndex, authorizerCharID` → `bool, reason` | Permission check for class change |
| `USMSCanViewIntel` | Server | `ply, char, targetUnitID` → `bool, reason` | Permission check for cross-faction intel |

---

## 22. Phased Implementation Plan

### Phase 1: Units & Roster (Foundation)

**Files to create:**
- `sh_plugin.lua` — Plugin definition + constants
- `libs/sh_usms.lua` — Shared namespace + utility functions
- `libs/sv_database.lua` — DB table creation (`ix_usms_units`, `ix_usms_members`, `ix_usms_logs`)
- `libs/sv_usms.lua` — Unit CRUD, member CRUD, utility functions
- `libs/sv_logging.lua` — Logging system
- `sv_plugin.lua` — Hooks (PlayerLoadedCharacter, PlayerDisconnected, data loading)
- `cl_plugin.lua` — Client-side cache + net receivers
- `meta/sh_character.lua` — CharVar registration + meta helpers
- `commands/sh_admin.lua` — Unit admin commands (UnitCreate, UnitDelete, UnitList, UnitInvite, UnitSetRole, UnitForceRemove)
- `derma/cl_usms_tab.lua` — Tab registration + main panel container
- `derma/cl_unit_overview.lua` — Unit info sidebar
- `derma/cl_unit_roster.lua` — Full roster panel with sortable columns

**Deliverables:**
- Superadmins can create/delete units
- Admins can invite/remove members, set roles
- CO/XO can invite/remove members via menu
- All unit members see full roster in the tab menu
- Offline member data is cached and displayed
- Logging for all member actions
- ISB hook stub (functional but awaiting rank system for cross-faction gating)

### Phase 2: Squads & HUD Integration

**Files to create/modify:**
- `libs/sv_database.lua` — Add `ix_usms_squads` + `ix_usms_squad_members` tables
- `libs/sv_usms.lua` — Squad CRUD, squad member CRUD, squad leader vacancy handling
- `derma/cl_squad_panel.lua` — Squad management UI
- `commands/sh_testing.lua` — Testing commands

**Files to modify:**
- `sv_plugin.lua` — Add squad HUD sync timer, handle PlayerDisconnected for squads
- `cl_plugin.lua` — Add squad net receivers

**Deliverables:**
- Players can create squads (with permission check hook)
- Squad leaders manage squad membership via menu
- Squads auto-populate diegetic HUD squad panel
- CO/XO can force-disband squads
- Squad leader vacancy auto-handled
- Comms channel auto-assignment for squads
- Testing commands for all squad operations

### Phase 3: Classes as Loadouts & Resources

**Files to create/modify:**
- `libs/sh_catalogs.lua` — Equipment catalog system
- `libs/sv_usms.lua` — GearUp API, ChangeClass API
- `sv_plugin.lua` — Override CanPlayerJoinClass hook
- `derma/cl_loadout_panel.lua` — Class/loadout viewer

**Schema changes needed:**
- Add `CLASS.loadout` tables to all class definitions
- Update class switching behavior

**Deliverables:**
- Classes are permanent (no free switching)
- Class change via API only (loadout locker / admin command)
- GearUp API grants loadout items and deducts unit resources
- Resource management API (set, add, deduct)
- Equipment catalog (global + per-faction)
- Loadout viewer in tab menu
- Testing commands for gear-up and class change

### Phase 4: Polish & Intelligence

**Files to create/modify:**
- `derma/cl_log_panel.lua` — Log viewer UI
- Cross-faction intel UI panels

**Deliverables:**
- CO/XO can view unit logs in the menu
- ISB can view other factions' rosters and resources (gated by hook)
- Log filtering (by action type, date range)
- Log pruning on server start (60 day default)
- Admin override panel polish
- Full integration with diegetic HUD comms
- Extension points ready for rank system and certification system

---

## 23. Codebase References

### Critical Files to Understand Before Coding

| File | What It Teaches |
|------|----------------|
| `gamemodes/helix/gamemode/core/libs/sh_plugin.lua` | How plugins load. Auto-includes `libs/`, `factions/`, `classes/`, `items/`, `derma/`, `entities/`. Lines 43-50. |
| `gamemodes/helix/gamemode/core/libs/thirdparty/sv_mysql.lua` | The DB query builder. `mysql:Create`, `mysql:Select`, `mysql:Insert`, `mysql:Update`, `mysql:Delete`, `mysql:RawQuery`. Supports SQLite + MySQL. |
| `gamemodes/helix/gamemode/core/libs/sv_database.lua` | How Helix creates its own DB tables. Pattern for `ix_usms_*` tables. |
| `gamemodes/helix/gamemode/core/meta/sh_character.lua` | `ix.char.RegisterVar` implementation. How CharVars are networked (broadcast vs isLocal). Lines 264-338. |
| `gamemodes/helix/gamemode/core/libs/sh_class.lua` | Class system. `ix.class.list`, `ix.class.CanSwitchTo`, `ix.class.LoadFromDir`. |
| `gamemodes/helix/gamemode/core/libs/sh_log.lua` | Logging: `ix.log.AddType`, `ix.log.Add`, `ix.log.AddRaw`. FLAG constants. |
| `gamemodes/skeleton/schema/libs/sfs.lua` | SFS v7.0.7. `sfs.encode(value)` → string, `sfs.decode(string)` → value. Supports tables, strings, numbers, vectors, etc. Use for efficient roster net messages. |
| `gamemodes/skeleton/plugins/diagetichud/libs/sh_api.lua` | The diegetic HUD API. `ix.diegeticHUD.CreateSquad`, `SyncSquad`, `DisbandSquad`, `SendTransmission`. Squad data format: `{steamID, name, health, maxHealth, pos, alive}`. |
| `gamemodes/skeleton/plugins/diagetichud/cl_plugin.lua` | Client-side HUD. `squadData`, `connectedChannels`, `availableChannels`, net receivers. HUD bridge target. |
| `gamemodes/skeleton/plugins/impmainmenu/derma/cl_menu.lua` | Tab menu system. `PopulateTabs`, `CreateMenuButtons` hook, `SetupTab`, `TransitionSubpanel`. THEME table. Font definitions. |
| `gamemodes/skeleton/plugins/impmainmenu/derma/cl_scoreboard.lua` | Scoreboard row pattern. `ixScoreboardRow`, `ixScoreboardIcon`, `FACTION_PANEL`. Copy for roster rows. |
| `gamemodes/skeleton/plugins/impmainmenu/derma/cl_information.lua` | Info panel pattern. `DrawScreeningPanel`, `ApplyAttributeBarStyle`. Reuse for unit overview. |
| `gamemodes/skeleton/plugins/impmainmenu/derma/cl_classes.lua` | Class UI. `CreateMenuButtons` pattern for "classes" tab. Override target for permanent classes. |
| `gamemodes/skeleton/plugins/impmainmenu/derma/cl_menubutton.lua` | Button styling. `ixMenuButton`, `ixMenuSelectionButtonTop`. Theme-consistent button rendering. |
| `gamemodes/skeleton/plugins/more_hook_lib/sh_plugin.lua` | Monkey-patching pattern. Warning: USMS should NOT monkey-patch. Use `hook.Add` instead. |
| `gamemodes/skeleton/plugins/weight/sh_plugin.lua` | Simple plugin pattern. `ix.config.Add`, `ix.util.Include`, meta extensions. |
| `gamemodes/skeleton/schema/factions/sh_army.lua` | Faction definition. `FACTION.name`, `FACTION.index`, `FACTION_ARMY` global. |
| `gamemodes/skeleton/schema/classes/sh_police_chief.lua` | Class definition with `CLASS:OnCanBe` restriction pattern. |

### SFS Library Usage

The SFS library at `gamemodes/skeleton/schema/libs/sfs.lua` is loaded during schema initialization. Access it as a module:

```lua
-- Server: include directly (it's in schema/libs, auto-included)
local sfs = include("libs/sfs.lua")

-- Or require from plugin:
-- The lib returns a table with .encode and .decode
local sfs = include("gamemodes/skeleton/schema/libs/sfs.lua")

-- Usage:
local encoded = sfs.encode({name = "test", health = 100, items = {"a", "b", "c"}})
-- encoded is a binary string

local decoded = sfs.decode(encoded)
-- decoded == {name = "test", health = 100, items = {"a", "b", "c"}}

-- Hex encoding for DB storage if needed:
local hexed = sfs.encode_to_hex(someTable)
local unhexed = sfs.decode_from_hex(hexed)
```

### MySQL Query Builder Reference

```lua
-- SELECT
local q = mysql:Select("table_name")
    q:Select("column1")         -- specific columns (omit for *)
    q:Where("col", value)       -- WHERE col = value
    q:WhereGT("col", value)     -- WHERE col > value
    q:WhereLT("col", value)     -- WHERE col < value
    q:WhereGTE("col", value)    -- WHERE col >= value
    q:WhereLTE("col", value)    -- WHERE col <= value
    q:WhereIn("col", {1,2,3})   -- WHERE col IN (1, 2, 3)
    q:OrderByDesc("col")        -- ORDER BY col DESC
    q:OrderByAsc("col")         -- ORDER BY col ASC
    q:Limit(10)                 -- LIMIT 10
    q:Offset(20)                -- OFFSET 20
    q:Callback(function(result) end) -- result is table of rows or nil
q:Execute()

-- INSERT
local q = mysql:Insert("table_name")
    q:Insert("col", value)      -- repeat for each column
    q:Callback(function(result, status, lastID) end) -- lastID = auto_increment
q:Execute()

-- INSERT IGNORE
local q = mysql:InsertIgnore("table_name")
    -- same as Insert

-- UPDATE
local q = mysql:Update("table_name")
    q:Update("col", newValue)
    q:Where("id", rowID)
q:Execute()

-- DELETE
local q = mysql:Delete("table_name")
    q:Where("col", value)
    q:Callback(function() end)
q:Execute()

-- CREATE TABLE
local q = mysql:Create("table_name")
    q:Create("col_name", "TYPE CONSTRAINTS")
    q:PrimaryKey("col_name")
q:Execute()

-- ALTER TABLE
local q = mysql:Alter("table_name")
    q:Add("new_col", "TYPE")
q:Execute()

-- DROP TABLE
local q = mysql:Drop("table_name")
q:Execute()

-- RAW QUERY
mysql:RawQuery("SELECT * FROM ix_usms_units WHERE id = 1", function(result) end)
```

### Helix net.WriteType Reference

`net.WriteType` / `net.ReadType` handle automatic type detection for CharVar networking. Supported types: nil, string, number, bool, table, Vector, Angle, Color, Entity. Used internally by `ix.char.RegisterVar` networking.

---

## Appendix A: Data Flow Diagrams

### Player Joins Server (Character Load)

```
1. Player selects character
2. Helix fires PlayerLoadedCharacter(ply, char)
3. USMS sv_plugin.lua reads char:GetUsmUnitID() from CharVar (loaded from DB)
4. If unitID > 0:
   a. Verify unit still exists in ix.usms.units cache
   b. Verify ix.usms.members[charID] exists (rebuild from DB if cache miss)
   c. Cache player name/class for offline roster display
   d. Send unit data to player via ixUSMSUnitSync
   e. If in squad: sync squad to HUD via ix.usms.SyncSquadToHUD
```

### Player Gears Up

```
1. Player interacts with armory entity (future) or runs test command
2. ix.usms.GearUp(ply, callback) called
3. Validates: has character, has class, class has loadout, is in unit
4. Checks inventory for already-owned items, calculates needed items + cost
5. Checks unit resource pool >= cost
6. Fires USMSCanGearUp hook for additional checks
7. Deducts resources → triggers ixUSMSUnitUpdate to all unit members
8. Adds items to inventory via inventory:Add()
9. Logs USMS_LOG_GEARUP + fires USMSGearUp hook
10. Returns success to callback
```

### Squad HUD Sync Cycle

```
Every 3 seconds (timer "ixUSMSHUDSync"):
1. Iterate all squads in ix.usms.squads
2. For each squad with existing HUD representation ("usms_" .. squadID):
   a. Call ix.diegeticHUD.SyncSquad("usms_" .. squadID)
   b. This gathers member health/pos/alive and sends to squad members
3. HUD renders squad panel using the synced data (existing diagetichud code, unchanged)
```

---

## Appendix B: Configuration Values

These should be exposed via `ix.config.Add` for server operator tuning:

```lua
ix.config.Add("usmsSquadMaxSize", USMS_SQUAD_MAX_SIZE, "Maximum squad size.", nil, {
    data = {min = 2, max = 12},
    category = "USMS"
})

ix.config.Add("usmsSquadMinSize", USMS_SQUAD_MIN_SIZE, "Minimum squad size before auto-disband.", nil, {
    data = {min = 1, max = 4},
    category = "USMS"  
})

ix.config.Add("usmsLogRetentionDays", 60, "Days to retain USMS logs before pruning.", nil, {
    data = {min = 7, max = 365},
    category = "USMS"
})

ix.config.Add("usmsHUDSyncInterval", 3, "Seconds between HUD squad sync updates.", nil, {
    data = {min = 1, max = 10},
    category = "USMS"
})
```
