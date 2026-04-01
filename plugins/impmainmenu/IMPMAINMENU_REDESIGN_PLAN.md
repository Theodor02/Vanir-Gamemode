# Imperial Main Menu (impmainmenu) - UI Analysis & Redesign Plan

This document serves as a comprehensive analysis of the existing `impmainmenu` plugin UI files, evaluated against the principles established in the `VANIR_UI_DESIGN_SYSTEM.md`. It also provides a structured roadmap for refactoring these elements to achieve the minimal, system-first, high-generous-negative-space aesthetic.

## 1. Current State Overview & Violations
Currently, `impmainmenu` spans across base main menu logic, character creation (`cl_charcreate.lua`), character loading (`cl_charload.lua`), and overridden Helix base Derma menus (`derma/cl_menu.lua`). 

While these files attempt to implement the "Imperial" theme, they heavily rely on legacy Helix UI assumptions that result in:
- **Violation:** Overuse of boxed framing and `DrawOutlinedRect` bounding boxes (e.g., `ApplyCharMenuStatic` in `cl_charcreate.lua` enforcing massive outlined frames).
- **Violation:** Hardcoded generic translucent blacks (`Color(0,0,0,200)`) instead of explicitly using the `THEME.background` palette map.
- **Violation:** Missing "Aurebesh as secondary metadata".
- **Violation:** Crowded UI flow (the Character Creation panels feel visually boxed in).
- **Violation:** Button encasing. Currently buttons are using heavily outlined borders from the `ixImpButton` or custom `.Paint` overrides instead of the understated 5-15% hover background shifts detailed in the new system.

---

## 2. File-by-File Analysis

### **A. `cl_menu.lua` (Base VANIR Title Menu)**
* **Current Status:** ✅ Completed. 
* **Notes:** Already refactored. Follows the "Generous Negative Space", the High-Contrast Title Bar methodology, and utilizes Diegetic Aurebesh metadata in the structurally-implied bottom corners.

### **B. `cl_charload.lua` (Deployment / Character Select)**
* **Current Status:** ❌ Needs Refactoring.
* **Analysis:** 
    * The left side (`infoPanel`) and the actual character buttons draw big, hardcoded black rectangles (`Color(0, 0, 0, 200)`). 
    * Relies heavily on `ix.ui.ApplyDataPanel` and `ix.ui.ApplyScreeningPanel` which draw massive bounding borders.
    * Misses the High-Contrast Title Bar approach. 
* **Design Solution:** 
    * Strip the manual bounding box paint functions. Use a flat split-pane layout with implied grid bounds.
    * Convert "PERSONNEL DATABASE" and "BIOMETRIC SCAN" headers into High-Contrast Title Bars (Gold background, inverted text color) with low-opacity Aurebesh suffix metadata appended.
    * Shift selection buttons to the minimalist flat-underline design.

### **C. `cl_charcreate.lua` (Enlistment / Character Creation)**
* **Current Status:** ❌ Needs Refactoring.
* **Analysis:**
    * Injected full-screen bounding frame (`panel.Paint = function... surface.DrawOutlinedRect`). This traps the entire creation process in a floating physical box instead of letting it breathe.
    * The subpanels ("ENLISTMENT SCREENING", "BIOGRAPHIC REVIEW") use standard borders.
* **Design Solution:**
    * Remove the main outer bounding frame; leave the background purely solid `THEME.background`.
    * Rework the transitions so that they slide smoothly across an open background.
    * Re-style text inputs arrays to use implied lines (a single bottom underline) instead of full rectangular text entry boxes.
    * Retain the progress bar but thin it out significantly.

### **D. `derma/cl_menu.lua` (F1 Overlay Menu Override)**
* **Current Status:** ❌ Needs Refactoring.
* **Analysis:**
    * Overrides Helix's standard ESC/F1 menu.
    * Hardcodes `Color(0, 0, 0, 180)` for menu bar backgrounds.
    * Subpanels are centered but have zero consideration for the minimalist aesthetic.
* **Design Solution:**
    * Bind to `THEME.background`. 
    * Rebuild navigation strips to adhere to the thin-line header design rather than a translucent black bar spanning the screen.
    * Apply the same hover-state philosophies from `cl_menu.lua` to these tabs.

---

## 3. Redesign Action Plan

### **Phase 1: Subpanel UI Primitives Refactor**
Right now, `cl_charcreate.lua` relies on standard `00_imperial_ui` hook functions (like `ApplyDataPanel`, `ApplyScreeningPanel`, and `ApplyTextEntryStyle`). 
**Action:** We must first update the UI framework in `00_imperial_ui` defining these styles, otherwise every change we make in the `impmainmenu` will just be overriden by the global style rules.
- Transform `ApplyDataPanel` and `ApplyScreeningPanel` to use the **High-Contrast Title Bars** instead of box borders.
- Transform `ApplyTextEntryStyle` to be a bottom-border input field instead of an outlined box.

### **Phase 2: Character Loading Implementation (`cl_charload.lua`)**
- Remove all local `Color(0,0,0,200)` draw calls. 
- Implement flat grid alignments.
- Attach Aurebesh diegetic hints to the selected character's statistics area.
- Flatten the delete/deploy buttons logic.

### **Phase 3: Character Creation Implementation (`cl_charcreate.lua`)**
- Rip out `ApplyCharMenuStatic` bounding-box frame padding.
- Anchor the actual Creation payload to the center grid. 
- Ensure the right-side form feels like an open terminal read-out.

### **Phase 4: Base Helix Menu Fixes (`derma/*`)**
- Clean up `derma/cl_menu.lua` navigation elements.
- Strip all unnecessary box outlines injected into the Inventory, Business, and Attributes tabs (by overriding the DPanel paints gracefully).

---

This document should be the blueprint moving forward. Edits made directly to `cl_charload` and `create` will be cross-referenced here to ensure we aren't introducing visual noise.