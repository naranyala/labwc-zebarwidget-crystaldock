# OCWS Consolidation Analysis: Removing Third-Party Shells

This document analyzes the impact of removing DankMaterialShell, Noctalia, and zigshell-cairo-pango from the OCWS ecosystem, comparing features that would be lost against the benefits of consolidating into a pure OCWS architecture.

## Removing DankMaterialShell (DMS)

**Features lost:**
- The Material Design vertical panel aesthetic provided out of the box.
- Built-in workspace overviews and material animations native to DMS.
- A pre-configured layout for users who prefer vertical docks and panels.

## Removing Noctalia Shell

**Features lost:**
- The distraction-free, minimalist layout.
- The pre-configured Noctalia theme and window rules that hide the UI until interacted with.
- The workflow tailored to ultra-minimalist users.

## Removing Zigshell-cairo-pango

**Features lost:**
- A dedicated macOS-style dock implemented in C++.
- Smooth zoom and bounce animations when hovering and launching applications.
- A standalone dock that requires no custom layout configuration.

---

## Benefits of Consolidation

While removing these components means dropping specific alternative layouts, the following advantages are gained through architectural consolidation:

1. **Unified identity:**
   The setup is currently fragmented into four modes. Consolidation allows development focus on the OCWS double-panel zigshell-cairo-pango mode, establishing OCWS as a distinct desktop environment.

2. **Native replacements available:**
   Native alternatives have already been developed to replace each component. The zigshell-cairo-pango dock is lighter, universally themable via the OCWS CSS engine, and integrates without requiring a separate rendering pipeline.

3. **Simplified codebase and GUI tools:**
   Backend logic (such as `ocws-dock-mgr`) currently parses JSON for DMS, TOML for Noctalia, and config files for zigshell-cairo-pango. Removing these formats simplifies C tooling to manage only unified OCWS configurations, reducing maintenance overhead.

4. **Fewer dependencies and faster installation:**
   Users no longer need to clone and compile zigshell-cairo-pango, DMS, or Noctalia from source. The installation process is shorter, leaner, and more robust.

5. **Recreating lost features natively:**
   If users desire a Material mode or a minimalist mode, those experiences can be recreated by writing alternative zigshell-cairo-pango layout presets, keeping the ecosystem entirely native while offering variety.

## Conclusion

Removing third-party dependencies is the logical next step for OCWS to mature into a standalone desktop environment. The architectural simplification and unified theming capabilities outweigh the loss of external layouts.
