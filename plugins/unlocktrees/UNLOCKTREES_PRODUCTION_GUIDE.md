# Unlock Trees Production Guide

This document describes the full current capability set of the unlocktrees plugin and provides a production-focused integration blueprint for the Skeleton server stack.

Scope:
- Plugin path: gamemodes/skeleton/plugins/unlocktrees
- Includes API, data model, UI, networking, hooks, admin tools, integration patterns, and rollout checklist
- Reflects the current implementation in code, including known caveats

## 1) What This Plugin Already Gives You

Unlocktrees is already a complete progression framework, not just a tree renderer.

Core capabilities:
- Register multiple trees, each with independent restrictions and policies.
- Register nodes with costs, requirements, callbacks, repeatable levels, hidden-state logic, categories, and exclusivity.
- Model prerequisite relationships as directed edges (parent -> child).
- Support tree-level and node-level refund policies with configurable ratios.
- Support per-node unlock/refund callbacks for real gameplay side effects.
- Support tree and node access veto/allow hooks for external systems.
- Sync unlock progression from server to client with compressed JSON payloads.
- Provide immediate client-side local cache updates for responsive UI.
- Provide full-screen panel and tab-menu embedded panel.
- Provide right-click single-node refund UX and full-tree respec UX.
- Provide admin commands to grant/remove/reset unlocks.
- Track per-character audit log and node cooldown timestamps.
- Provide an admin visual editor with export-to-Lua workflow.

This means production success is primarily about rules, balancing, and integrations, not about building framework infrastructure from scratch.

## 2) Architecture Summary

Main files and responsibilities:
- sh_plugin.lua
  - Plugin bootstrapping and include order.
  - Config: unlockTreeRespecCost.
  - Character-load sync trigger.
- sh_api.lua
  - Public API: tree/node/resource registration, queries, visibility, path-cost logic.
  - Character/player meta helpers.
  - Client request wrappers.
- sh_tree.lua
  - Tree-level access checks and safe serialization.
- sh_node.lua
  - Node prerequisite/cost/refund logic and helper strings.
- sv_storage.lua
  - Character creation initialization for unlock data.
- sv_progression.lua
  - Unlock/refund/respec/admin progression logic and audit logging.
- sv_networking.lua
  - Net message registration, request handling, denial messages, admin commands.
- cl_nodepanel.lua
  - Node rendering, tooltips, unlock/refund interactions.
- cl_treepanel.lua
  - Main tree viewer and tab-embed version.
- cl_tabmenu.lua
  - Integrates configured trees under YOU tab sections.
- cl_editor.lua
  - Admin visual authoring tool with import/load/auto-layout/export.
- sh_example_tree.lua
  - Reference/demo tree showing many features.

## 3) Data Model and Persistence

Character data keys:
- ixUnlockTrees
  - Structure: [treeID][nodeID] = { unlocked = bool, level = number }
- ixUnlockCooldowns
  - Structure: [cooldownKey] = unixTimestamp
- ixUnlockLog
  - Array of action entries (max 200), each:
    - action: unlock | refund | respec | admin_grant | admin_remove
    - tree, node, time, extra

Client cache:
- ix.unlocks.localData
  - Mirrors unlock data for immediate UI updates and client-side node checks.

## 4) Tree-Level Capability Matrix

RegisterTree supports:
- id, name, description
- metadata table
- restrictions table:
  - factions = { factionIDs }
  - classes = { classIDs }
  - condition = function(client, character) -> bool, reason
- showInTabMenu
- allowRespec (default true)
- refundable (default true)
- refundRatio (0..1) for single-node refunds
- respecRatio (0..1) for tree respec refunds

Access checks:
- CanAccessTree enforces faction/class/custom condition.
- GetAccessibleTrees and GetTabMenuTrees return per-player filtered lists.

## 5) Node-Level Capability Matrix

RegisterNode supports:
- id, name, description, icon, position
- cost:
  - money = number or function(client, character, nextLevel)
  - resources = { resourceID = number|function(...) }
  - condition = function(client, character, treeID, nodeID) -> bool, reason
  - deduct/refund custom callbacks
- requirements:
  - stats = { attribute = minimum }
  - faction
  - class
  - condition = function(client, character, treeID, nodeID) -> bool, reason
  - cooldown = { duration = seconds, key = optionalString }
- type, repeatable, maxLevel
- metadata, category
- mutuallyExclusive list
- hidden
  - bool or function(client, character, unlockData) -> bool
- refundable
- callbacks:
  - onUnlocked(client, character, treeID, nodeID, level)
  - onRefunded(client, character, treeID, nodeID, oldLevel/newLevel context)

Graph modeling:
- ConnectNodes(parent, child)
- SetExclusive(nodeA, nodeB, ...)

Runtime behaviors:
- Enforces prerequisites and exclusivity.
- Enforces repeatable max level.
- Supports dynamic per-level costs.
- Supports hidden node cascades via prerequisite chain visibility.

## 6) Hooks and Events for Integration

Hooks the plugin runs (you can consume):
- UnlockNodeRegistered(treeID, nodeID, node)
- CanPlayerSeeNode(client, treeID, nodeID)
- CanPlayerUnlockNode(client, treeID, nodeID)
- PrePlayerUnlockNode(client, treeID, nodeID)
- PlayerUnlockedNode(client, treeID, nodeID, level)
- CanPlayerRefundNode(client, treeID, nodeID)
- PlayerRefundedNode(client, treeID, nodeID, level)
- PlayerBatchUnlocked(client, treeID, results, succeeded, failed)
- PlayerNodeRemoved(client, treeID, nodeID, oldLevel)
- PlayerRespecTree(client, treeID, refunded)
- PlayerRespecAll(client, refunded)
- CanPlayerRespecTree(client, treeID)

Useful design rule:
- Use node callbacks for tightly-coupled behavior (grant/remove the exact perk).
- Use hooks for cross-cutting behavior (logging, analytics, policy checks, anti-abuse).

## 7) Networking and Security Model

Net messages:
- Client -> Server
  - ixUnlockRequest
  - ixUnlockRefundNode
  - ixUnlockRespec
- Server -> Client
  - ixUnlockSync
  - ixUnlockNodeSync
  - ixUnlockDenied

Security behavior already present:
- Input validation on tree/node string lengths.
- Server authoritative unlock/refund/respec checks.
- Permission gate hook for respec.
- Admin actions behind superAdminOnly ix commands.

Admin commands:
- UnlockGive <player> <treeID> <nodeID>
- UnlockRemove <player> <treeID> <nodeID>
- UnlockReset <player> <treeID|*> [refund]

## 8) UI and Authoring Workflow

Player UX:
- Full tree panel command: ix_unlocktree.
- Tab menu embedding for trees with showInTabMenu = true.
- Search by node name/category/id.
- Zoom/pan/center controls.
- Tooltip includes cost, path cost, requirements, exclusivity, level state.
- Left click unlock (when available).
- Right click refund for eligible unlocked nodes.

Admin UX:
- Visual editor command: ix_unlockeditor.
- Create/move/delete/connect nodes.
- Node inspector edits key fields.
- Load existing trees.
- Auto-layout helper.
- Export Lua snippet to clipboard.
- Keyboard shortcuts for copy/cut/paste, undo/redo, and select-all.
- Draft browser for save/load/rename/delete and backup restore.
- Preset browser with subset import picker for merging smaller trees into larger ones.
- Status strip with dirty-state and backup timestamps, plus close confirmation on unsaved changes.

Recommended authoring pipeline:
1. Prototype layout in editor.
2. Export code.
3. Move final definitions into versioned shared plugin files.
4. Keep editor for iteration, not as sole source of truth.

## 9) Existing Integration Already In Your Server

The plugin is already integrated in production style by the Force system:
- Plugin: gamemodes/skeleton/plugins/theos-forcesystem/sh_unlocktree.lua
- Pattern used:
  - Register tree with force-sensitive restriction.
  - Define force powers/stances as nodes.
  - Use onUnlocked to ix.force.Grant(...).
  - Use onRefunded to ix.force.Revoke(...).
  - Use stat gates (force attribute) per tier.

This file should be treated as your reference implementation for all other systems.

## 10) Integration Blueprint by Server System

### A) Force/LSCS (already active)

Use unlocktrees as the authority for learned powers/stances.
- Unlock action grants LSCS power or stance.
- Refund/respec action revokes it.
- Tier gates map to force attribute thresholds.

Production hardening:
- Add CanPlayerRespecTree policy to block respec during combat/duel.
- Add CanPlayerUnlockNode checks for restricted zones/events.
- Add analytics hook on PlayerUnlockedNode for balancing progression speed.

### B) Charpanel and Equipment Progression

Goal: unlock gear slot usage or equipment categories through trees.

Integration points:
- charpane slot registry: ix.charPane.RegisterSlot(category, options)
- item equip flow checks category and hooks

Pattern:
- Create a tree for equipment certification.
- In item equip validation hooks, require character:HasUnlockedNode(treeID, nodeID).
- Use node callbacks to set/remove lightweight capability flags if needed.

Example use cases:
- Unlock ammo2/ammo3 usage.
- Unlock heavy weapon slot category.
- Unlock specialist armor category.

### C) Medicalsys / Bacta

Goal: tie biotech progression to unlock trees.

Integration points:
- medical effect registry and application APIs (ix.bacta.RegisterEffectType, existing effect pipelines)

Patterns:
- Resource provider: register med research points as unlocktree cost resource.
- Unlock callbacks: grant access to advanced compounds, treatment actions, or passive resistances.
- Refund callback: remove access flag/recipe unlock.

### D) Hacking System

Goal: tie terminal expertise to unlock trees.

Integration points:
- ix.hacking.Sessions.Start(ply, opts)
- session callbacks and effect limit settings

Patterns:
- Gate higher hacking presets/difficulties behind unlock nodes.
- On node unlock, improve per-session limits (extra attempts, stronger token effects).
- Use unlocktree resources for hack tokens/keys economy.

### E) Economy and Resource Systems

Goal: move beyond money-only progression.

Integration via resource providers:
- RegisterResource("xp", provider)
- RegisterResource("intel", provider)
- RegisterResource("research", provider)
- RegisterResource("renown", provider)

Provider lets you define:
- where resource is stored,
- how deduction/refund works,
- how UI text is formatted.

### F) Faction/Class/Background Identity

Goal: align trees with role identity.

Use restrictions at tree level:
- factions list
- classes list
- condition callback for complex checks

Use requirements at node level:
- stat thresholds
- class/faction specifics
- custom condition for narrative/event progression

### G) Player Effects and Movement Combat Buffs

Goal: grant passive or temporary modifiers through unlocks.

Pattern:
- onUnlocked: apply a persistent effect registration/flag.
- onRefunded: remove it cleanly.

For systems already using player_effects style APIs, unlock nodes can become trait toggles without duplicating effect logic.

## 11) Production Standards for New Trees

Design standards:
- Keep each tree focused on one fantasy/domain (medical, engineering, force, command).
- Prefer branch identity over linear ladders.
- Use mutual exclusivity for true specialization choices.
- Use visible near-term goals and hidden long-term surprises sparingly.
- Avoid all-powerful root nodes; root should usually unlock participation only.

Technical standards:
- Every node with gameplay impact must define both onUnlocked and onRefunded if refundable.
- For irreversible perks, explicitly set refundable = false.
- For repeatables, always set maxLevel and confirm dynamic costs by level.
- Keep treeID/nodeID stable forever after launch (treat as save schema).
- Add audit review tooling around ixUnlockLog for support workflows.

Balancing standards:
- Use path-cost checks to estimate total investment to milestone nodes.
- Calibrate tree-level refundRatio and respecRatio intentionally.
- Use unlockTreeRespecCost to prevent rapid swap abuse on live servers.

## 12) Known Caveats in Current Implementation

1. Cooldown field mismatch in examples/editor output
- Runtime check expects requirements.cooldown.
- Example and editor include top-level cooldown in node definitions.
- Top-level cooldown currently does not enforce cooldown.

Production rule for now:
- Define cooldown under requirements.cooldown until code is unified.

2. Hidden bool semantics
- hidden = true is treated as always hidden unless CanPlayerSeeNode hook overrides.
- Prefer hidden as a function for deterministic reveal logic.

3. Editor output is scaffold quality
- Export is useful but should be reviewed/refined before shipping.
- Keep canonical trees in hand-maintained shared files under source control.

## 13) Suggested Folder Structure for Production Trees

Recommended structure:
- gamemodes/skeleton/plugins/unlocktrees/trees/sh_tree_force.lua
- gamemodes/skeleton/plugins/unlocktrees/trees/sh_tree_medical.lua
- gamemodes/skeleton/plugins/unlocktrees/trees/sh_tree_engineering.lua
- gamemodes/skeleton/plugins/unlocktrees/trees/sh_tree_hacking.lua
- gamemodes/skeleton/plugins/unlocktrees/integrations/sv_unlock_policies.lua
- gamemodes/skeleton/plugins/unlocktrees/integrations/sv_unlock_analytics.lua

Then include these from sh_plugin.lua in clear order.

## 14) Rollout Checklist

Phase 1: Foundation
- Remove or disable sh_example_tree.lua in production.
- Decide canonical tree/resource namespaces and naming rules.
- Define unlock policy hooks (combat lock, event lock, zone lock).

Phase 2: Integrations
- Force tree: keep as baseline and harden policies.
- Add one additional tree (medical or hacking) end-to-end.
- Wire at least one non-money resource provider.

Phase 3: Operations
- Add admin SOP for UnlockGive/UnlockRemove/UnlockReset usage.
- Build a small audit viewer command for ixUnlockLog support tickets.
- Add telemetry hook outputs for progression analytics.

Phase 4: Balance and QA
- Verify unlock/respec/refund on edge cases (disconnects, character swaps, faction changes).
- Verify repeatable node costs and refunds across levels.
- Verify hidden node reveal transitions and client sync.

## 15) Minimal Integration Snippets

Tree-level policy hook:

```lua
hook.Add("CanPlayerRespecTree", "myServer.BlockRespecInCombat", function(client, treeID)
    if (client:GetNetVar("inCombat", false)) then
        return false
    end
end)
```

Node unlock analytics hook:

```lua
hook.Add("PlayerUnlockedNode", "myServer.UnlockAnalytics", function(client, treeID, nodeID, level)
    local char = client:GetCharacter()
    if (!char) then return end

    print(string.format("[UnlockAnalytics] %s unlocked %s/%s lv%d",
        char:GetName(), treeID, nodeID, level))
end)
```

Custom resource provider example:

```lua
ix.unlocks.RegisterResource("intel", {
    name = "Intel",
    Get = function(client, character)
        return character:GetData("intel", 0)
    end,
    Deduct = function(client, character, amount)
        local current = character:GetData("intel", 0)
        character:SetData("intel", math.max(0, current - amount))
    end,
    Refund = function(client, character, amount)
        local current = character:GetData("intel", 0)
        character:SetData("intel", current + amount)
    end,
    Format = function(amount)
        return tostring(amount) .. " Intel"
    end
})
```

---

If you treat unlocktrees as the central progression authority and keep gameplay systems as effect providers/consumers, you get a maintainable architecture: one place for progression logic, many systems plugged in through callbacks and hooks.
