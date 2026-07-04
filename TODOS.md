# 🗺️ OCWS (Our C-Written Shell) Strategic Roadmap & TODOs

## Strategic Focus Areas

This document outlines the rigorous, multi-phase strategy for the future development of **OCWS** and the `labwc-fuzzel-sfwbar` platform. Focus is exclusively on this pure C-native Wayland paradigm.

**Key Priority**: Make OCWS a cohesive, complete "batteries-included" platform as outlined in platform documentation.

## 🟢 Phase 1: Platform Consolidation & Core Infrastructure (HIGH PRIORITY)
*The goal of this phase is to unify OCWS into a clean, consistent platform that matches its "batteries-included" promise.*

- [x] **Widget System Unification**: Merge shell/widgets/ with dotfiles/ocws/ implementations
  - Preserve all functionality from legacy widgets
  - Adopt OCWS-native widget pattern for consistency
  - Removed architectural duplication and inconsistent patterns

- [x] **Plugin Autoloader Development**: Implement `plugins/` directory logic
  - Scan `~/.config/ocws/plugins/` dynamically
  - Auto-inject `include("plugins/*.widget")` into running config
  - Enable 3rd-party drag-and-drop extensibility

- [x] **Event Bus API Enhancement**: Expand `ocws-emit` to cover system state
  - Add `System.Cpu`, `System.Memory`, `System.Disk` namespaces
  - Add `Media.Title`, `Media.Artist`, `Media.Status` via playerctl
  - Add `System.DND` Do Not Disturb toggle for notifications
  - Establish IPC patterns for C helpers in development

- [x] **Theme Engine Bridging**: Complete OCWS Glass CSS generation
  - Wire `scripts/theme-engine.sh` to generate `ocws.css`
  - Ensure theme.ini changes propagate blur to OCWS and fuzzel
  - Standardize INI profile structure for OCWS components

- [ ] **C Helper Program Implementation**: Build core C utilities
  - `ocws-lock.c`: Swaylock/swayidle wrapper (PHASE 2 dependency)
  - `ocws-clip.c`: Clipboard history integration (PHASE 2 dependency)
  - `ocws-shot.c`: Screenshot tool integration (PHASE 2 dependency)

## 🟡 Phase 2: Rich Interactive Components & UI/UX (MID PRIORITY)
*The goal of this phase is to build rich, interactive experiences rivaling macOS/GNOME while maintaining zero JavaScript/Qt overhead.*

- [ ] **Interactive Calendar Widget**: Replace static clock tooltip
  - Build GTK calendar widget within OCWS ecosystem
  - Enable navigation and date selection within shell
  - Integrate with existing OCWS Glass styling

- [ ] **Notification Unification**: Integrate mako/dunst into OCWS pipeline
  - Ensure notifications inherit same glassmorphic CSS
  - Standardize blur depth and border radii
  - Add notification center with DND support

- [ ] **Rich Media Applet**: Complete album art display
  - Pull cover art via playerctl + wget/curl to `/tmp/cover.jpg`
  - Display within Control Center with interactive controls
  - Integrate with existing media-player.widget

- [ ] **Dynamic Workspaces**: Refine pager widget elegance
  - Show empty vs populated workspace indicators
  - Enhance visual differentiation
  - Improve workspace management UX

## 🟠 Phase 3: System Resilience & User Experience (MID PRIORITY)
*The goal of this phase is to make OCWS bulletproof, distributable, and user-friendly.*

- [ ] **Daemon Resilience**: Handle sleep/resume cycles gracefully
  - Ensure `ocws-daemon.sh` survives ACPI events
  - Auto-recover Event Bus on system wake
  - Implement robust state synchronization

- [ ] **State Persistence**: Cache config across compositor reloads
  - Save/load state to `/tmp/ocws.state` fast
  - Restore volume, brightness, DND on labwc restart
  - Maintain UI consistency during reconnections

- [ ] **GUI Settings Manager**: Native configuration interface
  - Build `ocws-settings` via sfwbar or simple GTK/C
  - Allow blur toggle, theme switching, layout padding
  - Replace manual `.config` file editing

- [ ] **Installer Rollbacks**: Atomic backups for failed updates
  - Hardened `install.sh` with proper backup management
  - Perfect state restoration on failure
  - User-friendly update confirmation

## 🔴 Phase 4: Distribution & Community Integration (LOW PRIORITY)
*The goal of this phase is to share OCWS with the wider Linux community.*

- [ ] **AUR Packaging**: Create `ocws-desktop-git` PKGBUILD
  - Arch Linux package with dependency resolution
  - Install entire ecosystem from AUR
  - Resolve `labwc`, `sfwbar`, `fuzzel` dependencies

- [ ] **Standalone Installer**: Decouple from labwc-specific configs
  - Install OCWS on any wlroots compositor
  - Support Sway, Hyprland, etc.
  - Configurable environment integration

## 🟣 Phase 5: Ecosystem Enrichment & Premium Features (LONG TERM)
*The goal of this phase is to elevate OCWS from a functional shell into a premium, luxury desktop environment with advanced capabilities.*

- [ ] **Desktop Widgets (Conky Replacements)**:
  - Floating desktop clocks and weather applets
  - Hardware sensor dashboards embedded in the wallpaper layer
  - Interactive sticky notes and task lists

- [ ] **Dynamic AI/LLM Integration**:
  - `ocws-assistant`: A floating, glassmorphic AI chat widget
  - Voice-activated command palette integrated with Fuzzel
  - Local LLM hooks for analyzing screen text or clipboard

- [ ] **Advanced Applets & Extensions**:
  - Crypto/Stock ticker plugins
  - Spotify/MPD live lyrics display
  - GitHub/GitLab notification tray integration

- [ ] **Dynamic Wallpapers & Animations**:
  - Time-of-day based wallpaper transitions
  - Advanced window open/close animations using Labwc rules
  - Interactive live wallpapers natively rendered

## 📋 Project Status Summary

### Already Implemented (Phase 1 Foundations Complete! 🎉):
- Modular widget architecture fully integrated into `dotfiles/ocws`
- Dynamic Theme Engine fully bridged with Glassmorphism CSS injection
- Universal OS Dependency Installer (`arch.sh`, `debian.sh`, `fedora.sh`)
- Robust `ocws-emit` Event Bus and Plugin Autoloader

### Critical Gaps (Phase 1 remaining):
- Complete the C Helper Programs (ocws-lock, ocws-clip)

### Missing Capabilities (Phase 2-5):
- Interactive calendar widget
- Native notification daemon integration
- GUI settings manager
- State persistence
- Distribution packaging
- Ecosystem Enrichment (AI, Desktop Widgets, Applets)

## 🚀 Risk Mitigation Strategies

1. **Delete legacy cruft** before adding new features
2. **Use Ponytail principles** - simplest solution that works
3. **Implement one component at a time** with clear boundaries
4. **Automate testing** for all integrations
5. **Document decisions** with `ponytail:` comments

## 📊 Development Timeline Expectations

**Phase 1**: 2-3 months (platform consolidation)
**Phase 2**: 3-4 months (rich components)
**Phase 3**: 2-3 months (resilience)
**Phase 4**: 3-6 months (distribution)

Total: **10-16 months** for complete, cohesive platform
