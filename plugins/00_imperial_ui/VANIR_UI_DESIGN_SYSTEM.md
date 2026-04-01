# VANIR Core UI Design System

## Core Philosophy
A restrained, system-first interface built on a strict grid and generous negative space, where structure is communicated through alignment and spacing rather than heavy containers or visual noise. The base palette remains dark and desaturated, allowing the interface to recede into the background, while a single muted accent color is used sparingly to signal importance, interaction, and hierarchy. Most elements exist without full bounding boxes, relying instead on thin separators, subtle gradients, and precise placement to imply grouping, maintaining an open and breathable layout. Typography is clean and functional, carrying hierarchy through size, spacing, and weight rather than color or decoration. Within this minimal foundation, identity is introduced through selective, high-contrast title bars: thin horizontal strips using inverted color (accent background with contrasting text) to clearly define major sections. These title bars act as system-level headers rather than standard containers, used sparingly to preserve impact, and often paired with a small, low-opacity Aurebesh suffix treated as secondary metadata to reinforce a diegetic, in-world feel. Interaction remains fast and understated, with feedback conveyed through subtle opacity and color shifts rather than animation or effects. The overall result is an interface that reads as a clean, efficient tool at rest, but reveals a controlled, authoritative, and slightly fictional system identity through carefully placed moments of emphasis.

## 1. Composition and Layout
* **Generous Negative Space:** Interfaces should breathe. Do not crowd elements. Use empty space to naturally draw the user's eye to the center or essential focal points.
* **Structural Implication over Explicit Bounding:** Avoid full-frame bounding boxes or heavy panels unless absolutely necessary. Group elements using implied lines, alignment, and thin subtle separators.
* **Anchors and Framing:** Use minimalistic corner pieces (e.g., a 2px horizontal/vertical notch) to establish the boundary of the UI. This tricks the eye into interpreting massive negative space intentionally rather than as an empty void.

## 2. Color Palette
* **Backgrounds:** Remain dark, opaque, and desaturated. The interface should recede into the background contextually. Avoid completely transparent/invisible backgrounds where read clarity is needed, favoring deep slate/dark-grey tones.
* **Primary Accent (Imperial Gold):** Used sparingly to signal importance, interaction, and hierarchy. It represents the "authority" of the system.
* **High-Contrast Typography Blocks:** For major section titles, use thin horizontal strips with an inverted color scheme (e.g., solid Accent background with dark, background-colored text on top) to create a striking, authoritative header.

## 3. Typography
* **Primary System Typeface (Orbitron):** Clean, structural, and technical. Carries hierarchy purely through tracked-out spacing (kerning), scaling, and varying weight. 
* **Avoid Colors for Hierarchy:** Do not use rainbow text to sort information. Stick to bright white for active items, and muted/alpha-shifted greys for idle/secondary items.

## 4. Diegetic UI Elements (Aurebesh)
* **Role as Metadata:** Aurebesh shouldn't be scaled up massively to act as loud watermarks or main labels. Instead, it must be used as ambient, low-opacity "secondary metadata."
* **Placement:** Embed it into the structural corners or adjacent to high-contrast title bars.
* **Diegetic Immersion:** Replace plain-text system statuses (e.g., "SYS ACTIVE" or "AUTH LVL 3") with readable Aurebesh. The UI should feel like a piece of technology belonging to the Star Wars universe, without sacrificing out-of-character usability.

## 5. Interaction & Feedback
* **Fast and Understated:** Systems should respond immediately. Do not rely on slow, drawn-out fade animations or hyper-complex geometry transitions.
* **Hover States:** Emphasize interaction through subtle opacity changes and structural brackets. Do not encase hovered items in massive solid blocks. A faint 5%–15% background tint combined with minimalistic left/right bounding bars or a strict bottom line is enough to communicate focus. 

---
*Created to ensure consistent system-level design across the entire Vanir framework.*