# OCWS: Native Wayland Desktop Environment

[![CI](https://github.com/naranyala/labwc-zigshell/actions/workflows/ci.yml/badge.svg)](https://github.com/naranyala/labwc-zigshell/actions/workflows/ci.yml)
[![Release](https://github.com/naranyala/labwc-zigshell/actions/workflows/release.yml/badge.svg)](https://github.com/naranyala/labwc-zigshell/actions/workflows/release.yml)
[![Docs](https://github.com/naranyala/labwc-zigshell/actions/workflows/docs.yml/badge.svg)](https://github.com/naranyala/labwc-zigshell/actions/workflows/docs.yml)

OCWS is a modular, native-compiled desktop environment built exclusively for Wayland. It combines the `labwc` compositor with a suite of C and Zig binaries -- panels, daemons, CLI tools, and GTK3 GUI applications -- to deliver a complete desktop session without JavaScript, Electron, or Qt runtimes. The full session footprint is under 200 MB of system memory.

---

## Architecture

OCWS is organized into four discrete layers, each with a defined responsibility and interface boundary.

| Layer | Component | Role |
|-------|-----------|------|
| Compositor | labwc | Wayland session management, window layout, input dispatch, keybinding evaluation |
| Shell UI | zigshell-cairo-pango | GTK3 panel engine providing widgets, system tray, taskbar, and popup surfaces |
| Launcher | fuzzel | Application launcher and dmenu-mode script runner |
| Layer Shell | gtk-layer-shell | Anchors shell surfaces to Wayland output edges with margin and exclusive-zone control |

Supporting infrastructure includes the OCWS Event Bus (IPC between daemons and the shell via `ocws-emit`), a centralized INI-based theme engine that propagates palette changes to 11+ configuration surfaces, and a plugin autoloader for widget extensibility.

---

## Component Overview

### Shell Modes

| Mode | Layout | Description |
|------|--------|-------------|
| doublepanel | Top bar + bottom dock/taskbar | Traditional dual-panel layout with workspaces, tray, and dock |
| zigshell-cairo-pango | Single status bar | Unified top bar paired with external zigshell-cairo-pango dock |
| minimal | Compact single bar | Clock, volume, battery, and tray only |
| noctalia | Floating dynamic island | Modern minimalist floating-interface paradigm |
| dms | Material Design vertical panel | Vertical sidebar with matugen dynamic theming |

### Core Utilities

| Binary | Domain | Dependencies |
|--------|--------|--------------|
| `ocws-brightness` | Backlight control with cubic-easing animation | libm |
| `ocws-volume` | PulseAudio volume control with smooth transitions | libm, PulseAudio |
| `ocws-clip` | Clipboard manager (cliphist + fuzzel picker) | stdlib |
| `ocws-shot` | Screenshot tool (grim + slurp) | stdlib |
| `ocws-sysmon` | System metrics: CPU, memory, network, battery, temperature | stdlib |
| `ocws-emit` | Event Bus IPC emitter (namespace-to-variable mapping) | stdlib |
| `ocws-kv` | Persistent key-value store (flat file) | stdlib |
| `ocws-color` | Wallpaper palette extraction (median-cut) | cairo |
| `ocws-recorder` | Screen recording (wf-recorder wrapper) | stdlib |
| `ocws-search` | Multi-engine web search frontend | stdlib |
| `ocws-state` | JSON state file manager | stdlib |
| `ocws-style` | Theme engine CLI (INI-to-CSS generation) | stdlib |
| `ocws-validate` | System dependency and configuration validator | stdlib |
| `ocws-player` | Media player controller (playerctl wrapper) | stdlib |
| `ocws-ocr` | Screen OCR (Tesseract / Leptonica) | tesseract, leptonica |
| `ocws-lock` | Screen lock (swaylock wrapper) | stdlib |

### Daemons

| Binary | Function | Protocol |
|--------|----------|----------|
| `ocws-brokerd` | Event bus broker with plugin runtime | Unix socket + shared library |
| `ocws-appletd` | Unified applet loader daemon | Plugin (.so) loader |
| `ocws-notify` | D-Bus notification daemon (replaces mako) | D-Bus (org.freedesktop.Notifications) |
| `ocws-osd-notify` | Glassmorphic on-screen notification popup | GTK Layer Shell |
| `ocws-wallpaper` | Time-of-day wallpaper transitions with Cairo crossfade | Cairo |
| `ocws-live-bg` | Animated live background renderer | GTK Layer Shell + Cairo |
| `ocws-hypertile` | Dynamic tiling daemon (wlr-foreign-toplevel) | Wayland protocol |
| `ocws-gestured` | Gesture detection and dispatch | libinput |

### GUI Applications

| Binary | Purpose | Key Libraries |
|--------|---------|---------------|
| `ocws-settings` | 11-tab control center: shell, appearance, bar, widgets, keybindings, diagnostics | GTK3, libxml2 |
| `ocws-welcome` | First-run setup wizard (10 pages) | GTK3 |
| `ocws-theme-center` | Theme browser with live INI preview, palette visualization, one-click apply | GTK3 |
| `ocws-workspace-mgr` | Kanban-style workspace/window manager | GTK3, wayland-client |
| `ocws-dock-mgr` | Dock pinned-application manager with hot-reload | GTK3, json-c |
| `ocws-dotdesktop-mgr` | .desktop file browser and editor | GTK3, GIO |
| `ocws-pkgmgr` | Dependency resolver, source builder, health checker | GTK3, GIO |
| `ocws-fonts-mgr` | 5-tab font manager: scan, install, preview, configure | GTK3, GIO |
| `ocws-equalizer` | 10-band audio equalizer with FFT visualization | GTK3, PulseAudio, FFTW3 |
| `ocws-equalizer-gl` | OpenGL-accelerated equalizer overlay | GTK3, epoxy, PulseAudio |
| `ocws-waveform-gl` | OpenGL waveform audio viewer | GTK3, epoxy, PulseAudio |
| `ocws-llm-runner` | Local LLM chat client with OCR integration (Python backend) | GTK3, json-c |
| `ocws-snake-game` | Snake game | GTK3 |
| `ocws-todomvc` | Todo-MVC application | GTK3 |
| `ocws-datetime` | Date/time display widget | GTK3 |
| `ocws-wallpaper-picker` | Minimal wallpaper selector dialog | tinyfiledialogs |
| `ocws-tray` | System tray indicator application | GTK3, ayatana-appindicator |

---

## Build and Install

### Prerequisites

```
labwc, zigshell-cairo-pango, fuzzel
gtk-layer-shell, gtk+-3.0, glib-2.0, cairo
pipewire, wireplumber, pulseaudio, playerctl
wl-clipboard, cliphist, grim, slurp
polkit-gnome, swayidle, swaylock
```

### Compile

The Zig build system (v0.16.0) compiles all C and Zig sources in a single invocation:

```sh
zig build
```

Output binaries are placed in `zig-out/bin/`. Individual targets can be built via named steps (e.g. `zig build ocws-equalizer-gl`).

### Deploy

```sh
./install.sh
```

The installer archives existing configurations, provisions XDG-compliant dotfiles to `~/.config/labwc/` and `~/.config/ocws/`, installs compiled binaries to `~/.local/bin/`, and links action scripts and `.desktop` files.

### Cross-Compilation

```sh
zig build -Dtarget=aarch64-linux-musl -Doptimize=ReleaseFast
zig build -Dtarget=riscv64-linux-musl -Doptimize=ReleaseFast
```

### Test

```sh
zig build test          # Zig unit tests
bash tests/run-bash-tests.sh     # Shell script integration tests
bash tests/test-c-binaries.sh    # C binary smoke tests
```

---

## Documentation Reference

The following documents are maintained in `www/docs/`:

| Document | Description |
|----------|-------------|
| `index.md` | Entry point and feature summary |
| `getting-started.md` | Installation, first-run, shell usage, troubleshooting |
| `architecture-modes.md` | Shell mode architecture, widget sets, CSS theming, mode files |
| `configuration.md` | Event Bus API, plugin autoloader, theme engine, C helper reference, keybindings |
| `events.md` | Full IPC event contract with variable mappings and data-flow diagrams |
| `modular-config.md` | Composable ZIGSHELL-CAIRO-PANGO configuration modules |
| `gui-managers.md` | GTK3 utility application overviews (settings, theme, fonts, dock, etc.) |
| `ai-runner.md` | LLM Runner overview and quick-start |
| `llm-runner.md` | Full LLM Runner API reference, model management, session management, OCR |
| `distro-packages.md` | Package availability matrix across Arch, Debian, Fedora, openSUSE |
| `consolidation-analysis.md` | Impact analysis for removing third-party shell dependencies |
| `dependency-removal-impact.md` | Component-level breakage analysis per dependency |
| `shell-removal-impact.md` | Feature-loss audit for each shell mode |
| `ocws-settings-panel-design.md` | Settings panel UI/UX specification |
| `PLAN-sfwbar-unification.md` | Roadmap for zigshell-cairo-pango unification and deprecation of external shells |
| `install-dms-openmandriva.md` | DankMaterialShell build guide for OpenMandriva |
| `install-noctalia-openmandriva.md` | Noctalia Shell build guide for OpenMandriva |

The `www/docs/lessons/` directory contains 55+ implementation notes covering zigshell-cairo-pango internals, C security patterns, shell scripting pitfalls, widget architecture, and theme engine design.

For security disclosures and vulnerability reporting, see `SECURITY.md`.

---

## License

Refer to the repository license file for usage and distribution terms. The project is distributed as open-source software; all contributions are subject to the terms defined therein.
