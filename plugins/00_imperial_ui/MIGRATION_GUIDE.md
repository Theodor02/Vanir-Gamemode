# Imperial UI Framework - Migration Guide

## What Has Been Done

The `00_imperial_ui` plugin now contains `cl_framework.lua`, a centralised UI framework
that exposes all shared elements via the `ix.ui` namespace. It loads first (alphabetically)
so all other plugins can depend on it.

### Framework provides (`ix.ui.*`):

| Category | Functions / Tables |
|---|---|
| **Theme** | `ix.ui.THEME` (full color table), `ix.ui.GetColor(name)` |
| **Scaling** | `ix.ui.Scale(value)` |
| **Sounds** | `ix.ui.SOUND_HOVER`, `ix.ui.SOUND_CLICK`, `ix.ui.SOUND_ERROR`, `ix.ui.SOUND_ENTER`, `ix.ui.PlaySound(name)` |
| **Fonts** | Core fonts auto-created: `ixImpMenuTitle`, `ixImpMenuSubtitle`, `ixImpMenuLabel`, `ixImpMenuButton`, `ixImpMenuStatus`, `ixImpMenuAurebesh`, `ixImpMenuDiag`. Also `ix.ui.CreateFont(name, data)` for plugin-specific fonts. |
| **Utilities** | `ix.ui.IsMenuClosing()`, `ix.ui.FindScreeningParent(panel)`, `ix.ui.FindDataPanelParent(panel)`, `ix.ui.ContainsSpawnIcon(panel)` |
| **Drawing** | `ix.ui.DrawSpacedText(...)`, `ix.ui.GetSpacedTextSize(...)`, `ix.ui.DrawScreeningPanel(...)`, `ix.ui.DrawDataPanel(...)` |
| **Panel Styling** | `ix.ui.ApplyScreeningPanel(panel, header)`, `ix.ui.ApplyDataPanel(panel, header)`, `ix.ui.ApplyLabelStyle(label)`, `ix.ui.ApplyCharVarLabelStyle(panel)`, `ix.ui.ApplyTextEntryStyle(entry)`, `ix.ui.ApplyModelPanelStyle(panel)`, `ix.ui.ApplyModelScrollStyle(scroll)`, `ix.ui.ApplyCategoryPanelStyle(panel)`, `ix.ui.ApplyAttributeBarStyle(panel)`, `ix.ui.ApplyProgressStyle(progress)`, `ix.ui.ApplyButtonSounds(button)`, `ix.ui.ApplyImpButtonStyle(button, style)`, `ix.ui.ApplyScrollbarStyle(scroll, gripColor)`, `ix.ui.ApplySpawnIconStyle(icon)`, `ix.ui.ApplyIconLayoutStyle(layout)`, `ix.ui.FitModelContainer(panel, ratio)`, `ix.ui.ApplyAttributeButtonStyle(button, symbol)` |
| **Component Factories** | `ix.ui.CreateDataRow(parent, label, value, index)`, `ix.ui.CreateSectionHeader(parent, text)`, `ix.ui.CreateBarSectionHeader(parent, title)`, `ix.ui.CreateTooltip(lines)`, `ix.ui.CreateToggleRow(parent, label, active, cb)`, `ix.ui.CreateSliderRow(parent, label, convar, min, max, dec)`, `ix.ui.CreateCheckboxRow(parent, label, convar)`, `ix.ui.CreateKeybindRow(parent, label, getKey, setKey)` |
| **Paint Helpers** | `ix.ui.PaintRow(w, h, index, hovered)`, `ix.ui.PaintPanelBackground(w, h)`, `ix.ui.PaintFilledButton(w, h, text, color, hovered, hoverColor, textColor)` |
| **VGUI Components** | `ixImpButton` (replaces `ixImpMenuButton` / `ixImpMenuButtonChar`), `ixImpStatus` (status pill) |

---

## What Still Needs to Be Done: Plugin Migration

Each plugin needs to be updated to **remove its local copies** of theme, Scale, fonts, sounds,
and styling functions, and **use `ix.ui.*` instead**. Below is a per-plugin migration checklist.

### General Migration Pattern

For every plugin file that defines its own `local THEME = {...}`:

1. **Delete** the local `THEME` table. Replace all `THEME.xxx` references with `ix.ui.THEME.xxx` (or assign `local THEME = ix.ui.THEME` at the top for brevity).
2. **Delete** the local `Scale()` function. Replace calls with `ix.ui.Scale()` (or `local Scale = ix.ui.Scale`).
3. **Delete** local sound constants (`SOUND_HOVER`, etc.). Use `ix.ui.SOUND_HOVER` etc.
4. **Delete** local `CreateFonts()` and its `OnScreenSizeChanged` hook if it creates the same fonts as the framework (ixImpMenuTitle, etc.). Only keep it if the plugin creates *additional* plugin-specific fonts.
5. **Replace** duplicated helper functions with framework equivalents (see mapping below).
6. **Replace** duplicated VGUI registrations (`ixImpMenuButton`, `ixImpMenuButtonChar`) with `ixImpButton`.

### Function Mapping (old local -> new framework)

| Old Local Function | New Framework Function |
|---|---|
| `local function Scale(value)` | `ix.ui.Scale(value)` |
| `local function IsMenuClosing()` | `ix.ui.IsMenuClosing()` |
| `local function DrawScreeningPanel(...)` | `ix.ui.DrawScreeningPanel(...)` |
| `local function ApplyScreeningPanel(...)` | `ix.ui.ApplyScreeningPanel(...)` |
| `local function ApplyDataPanel(...)` | `ix.ui.ApplyDataPanel(...)` |
| `local function ApplyLabelStyle(...)` | `ix.ui.ApplyLabelStyle(...)` |
| `local function ApplyTextEntryStyle(...)` | `ix.ui.ApplyTextEntryStyle(...)` |
| `local function ApplyModelPanelStyle(...)` | `ix.ui.ApplyModelPanelStyle(...)` |
| `local function ApplyModelScrollStyle(...)` | `ix.ui.ApplyModelScrollStyle(...)` |
| `local function ApplyCharVarLabelStyle(...)` | `ix.ui.ApplyCharVarLabelStyle(...)` |
| `local function ApplyCategoryPanelStyle(...)` | `ix.ui.ApplyCategoryPanelStyle(...)` |
| `local function ApplyProgressStyle(...)` | `ix.ui.ApplyProgressStyle(...)` |
| `local function ApplyButtonSounds(...)` | `ix.ui.ApplyButtonSounds(...)` |
| `local function ApplyImpButtonStyle(...)` | `ix.ui.ApplyImpButtonStyle(...)` |
| `local function ApplyAttributeBarStyle(...)` | `ix.ui.ApplyAttributeBarStyle(...)` |
| `local function ApplyAttributeButtonStyle(...)` | `ix.ui.ApplyAttributeButtonStyle(...)` |
| `local function ApplySpawnIconStyle(...)` | `ix.ui.ApplySpawnIconStyle(...)` |
| `local function ApplyIconLayoutStyle(...)` | `ix.ui.ApplyIconLayoutStyle(...)` |
| `local function FitModelContainer(...)` | `ix.ui.FitModelContainer(...)` |
| `local function CreateDataRow(...)` | `ix.ui.CreateDataRow(...)` |
| `local function CreateSectionHeader(...)` | `ix.ui.CreateSectionHeader(...)` |
| `local function MakeSectionHeader(...)` | `ix.ui.CreateBarSectionHeader(...)` |
| `local function MakeToggleRow(...)` | `ix.ui.CreateToggleRow(...)` |
| `local function MakeSliderRow(...)` | `ix.ui.CreateSliderRow(...)` |
| `local function MakeCheckboxRow(...)` | `ix.ui.CreateCheckboxRow(...)` |
| `local function MakeKeybindRow(...)` | `ix.ui.CreateKeybindRow(...)` |
| `local function CreateMemberTooltip(data)` | `ix.ui.CreateTooltip(lines)` (restructure data into lines format) |
| `local function FindScreeningParent(...)` | `ix.ui.FindScreeningParent(...)` |
| `local function FindDataPanelParent(...)` | `ix.ui.FindDataPanelParent(...)` |
| `local function ContainsSpawnIcon(...)` | `ix.ui.ContainsSpawnIcon(...)` |
| `local function GetSpacedTextSize(...)` | `ix.ui.GetSpacedTextSize(...)` |
| `local function DrawSpacedText(...)` | `ix.ui.DrawSpacedText(...)` |
| `vgui.Register("ixImpMenuButton", ...)` | Use `ixImpButton` instead |
| `vgui.Register("ixImpMenuButtonChar", ...)` | Use `ixImpButton` instead |
| `vgui.Register("ixImpMenuStatus", ...)` | Use `ixImpStatus` instead |

### Per-Plugin Migration Checklist

#### impmainmenu (HIGHEST PRIORITY - reference implementation)

Files to migrate:
- [x] `cl_menu.lua` - Remove: THEME, Scale, CreateFonts+hook, GetSpacedTextSize, DrawSpacedText, BUTTON vgui (ixImpMenuButton), STATUS vgui (ixImpMenuStatus). Add `local THEME = ix.ui.THEME` and `local Scale = ix.ui.Scale` aliases at top.
- [x] `cl_charcreate.lua` - Remove: THEME, SOUND_*, BUTTON vgui (ixImpMenuButtonChar), Scale, CreateFonts+hook, DrawScreeningPanel, ApplyScreeningPanel, ApplyDataPanel, ApplySubpanelTitle, ApplyLabelStyle, ApplyTextEntryStyle, ApplyModelPanelStyle, ApplyCharVarLabelStyle, ApplyCategoryPanelStyle, ApplyProgressStyle, FitModelContainer, ApplyButtonSounds, ApplyImpButtonStyle, FindScreeningParent, FindDataPanelParent, ApplyModelScrollStyle, ApplyIconLayoutStyle, ApplySpawnIconStyle, ContainsSpawnIcon, ApplyAttributeButtonStyle. Replace ixImpMenuButtonChar with ixImpButton.
- [x] `cl_charload.lua` - Same removals as cl_charcreate.lua (duplicated code).
- [x] `derma/cl_menu.lua` - Remove: THEME. Use `local THEME = ix.ui.THEME`.
- [x] `derma/cl_menubutton.lua` - Remove: THEME. Use `local THEME = ix.ui.THEME`.
- [x] `derma/cl_inventory.lua` - Remove: THEME, Scale, IsMenuClosing. Use framework aliases.
- [x] `derma/cl_scoreboard.lua` - Remove: THEME, Scale. Use framework aliases.
- [x] `derma/cl_classes.lua` - Remove: THEME, Scale. Use framework aliases.
- [x] `derma/cl_business.lua` - Remove: THEME, Scale. Use framework aliases.
- [x] `derma/cl_information.lua` - Remove: THEME, Scale, IsMenuClosing, DrawScreeningPanel, ApplyAttributeBarStyle, CreateDataRow, CreateSectionHeader. Use framework equivalents.
- [ ] `derma/cl_help.lua` - Remove: THEME, Scale (file is currently commented out).
- [ ] `derma/cl_settings.lua` - Remove: THEME, Scale (file is currently commented out).

#### usms (11 files, all with duplicated THEME + Scale)

- [ ] `derma/cl_usms_tab.lua` - Remove: THEME, Scale.
- [ ] `derma/cl_unit_roster.lua` - Remove: THEME, Scale, CreateMemberTooltip (use ix.ui.CreateTooltip).
- [ ] `derma/cl_unit_overview.lua` - Remove: THEME, Scale. Replace scrollbar styling with `ix.ui.ApplyScrollbarStyle`.
- [ ] `derma/cl_squad_panel.lua` - Remove: THEME, Scale, CreateSquadMemberTooltip (use ix.ui.CreateTooltip).
- [ ] `derma/cl_mission_panel.lua` - Remove: THEME, Scale.
- [ ] `derma/cl_loadout_panel.lua` - Remove: THEME, Scale.
- [ ] `derma/cl_service_record.lua` - Remove: THEME, Scale.
- [ ] `derma/cl_intel_panel.lua` - Remove: THEME, Scale.
- [ ] `derma/cl_log_panel.lua` - Remove: THEME, Scale.
- [ ] `derma/cl_invite_popup.lua` - Remove: THEME, Scale. Use ix.ui.PaintFilledButton for accept/decline.
- [ ] `derma/cl_help_panel.lua` - Remove: THEME, Scale.

#### theos-forcesystem

- [ ] `derma/cl_force_tab.lua` - Remove: THEME, SOUND_*, Scale, CreateForceTabFonts (keep only plugin-specific fonts not in framework), MakeSectionHeader (use ix.ui.CreateBarSectionHeader), MakeToggleRow (use ix.ui.CreateToggleRow), MakeSliderRow (use ix.ui.CreateSliderRow), MakeCheckboxRow (use ix.ui.CreateCheckboxRow), MakeKeybindRow (use ix.ui.CreateKeybindRow). Replace scrollbar styling with `ix.ui.ApplyScrollbarStyle`.

#### radio_chatbox

- [ ] `derma/cl_chatbox.lua` - Remove: THEME, SOUND_CLICK, Scale. Keep plugin-specific fonts (ixImpChat*) but use `ix.ui.CreateFont` for them. Use THEME aliases.
- [ ] `derma/cl_chatbox_customize.lua` - Remove: THEME, Scale.

#### hackingsys

- [ ] `cl_terminal.lua` - Remove: SOUND_*, Scale. Keep its own green THEME (intentionally different palette) but consider using `ix.ui.Scale` directly. Keep plugin-specific fonts but use `ix.ui.CreateFont`.

**Note:** hackingsys and medicalsys use intentionally different color palettes (green CRT and cyan medical respectively). They should still use `ix.ui.Scale` and `ix.ui.SOUND_*` but their THEME tables stay local since they are styled differently by design.

#### medicalsys

- [ ] `cl_sequencer.lua` - Remove: SOUND_*, Scale. Keep local THEME (different cyan palette). Use `ix.ui.Scale` and `ix.ui.SOUND_*`.
- [ ] `cl_hud.lua` - Remove: Scale. Use `ix.ui.Scale`.

#### bodygroupmanager

- [ ] `derma/cl_viewer.lua` - Minor: replace any hardcoded Scale if present. Likely minimal changes.

#### diagetichud

- [ ] `cl_plugin.lua` - Remove: Scale, font creation. Use `ix.ui.Scale`. Keep HUD-specific fonts via `ix.ui.CreateFont`.

#### comms_sys

- [ ] `cl_comms_menu.lua` - Remove: Scale, THEME if matching. Use `ix.ui.Scale` and `ix.ui.THEME`.

#### Standalone files

- [ ] `voicepanel.lua` - Minimal, check for Scale/THEME duplication.
- [ ] `spawnemenu_itemtab.lua` - Minimal, check for Scale/THEME duplication.

#### unlocktrees

- [ ] `cl_editor.lua` - Remove: THEME, Scale. Use framework aliases.
- [ ] `cl_tabmenu.lua` - Remove: THEME, Scale. Use framework aliases.
- [ ] `cl_treepanel.lua` - Remove: THEME, Scale. Use framework aliases.
- [ ] `cl_nodepanel.lua` - Remove: THEME, Scale. Use framework aliases.

---

## Migration Tips

### Quick alias pattern
At the top of each migrated file, add:
```lua
local THEME = ix.ui.THEME
local Scale = ix.ui.Scale
```
This means most code only needs the local function definitions deleted -- references like
`THEME.accent` and `Scale(12)` continue to work unchanged.

### Testing
After migrating each plugin:
1. Check that fonts render correctly (no missing font errors in console)
2. Check that colors match the old look (theme table values should be identical)
3. Test interactive elements (buttons produce sounds, hover effects work)
4. Test responsive scaling (resize the game window)

### Order of migration
Recommended order (by impact / code duplication):
1. `impmainmenu` - largest amount of duplicated code, reference implementation
2. `usms` - 11 files all with identical THEME+Scale
3. `theos-forcesystem` - has the most duplicated factory functions
4. `radio_chatbox` - moderate duplication
5. `unlocktrees` - moderate duplication
6. Everything else (hackingsys, medicalsys, bodygroupmanager, etc.) - minimal changes
