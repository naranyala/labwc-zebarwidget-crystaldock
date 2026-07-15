# OCWS: Our C-Written Shell

A native Wayland desktop shell built on C, GTK3, and labwc. No JavaScript. No Electron. No Qt. Just compiled code and the Wayland protocol.

OCWS ships as a complete desktop environment: a compositor-integrated shell with glassmorphic panels, a theme engine that propagates palettes across 14 configuration surfaces, native GTK3 settings and utility GUIs, and a modular widget system -- all implemented in C for minimal memory footprint and immediate responsiveness.

---

## What OCWS Is

OCWS is a Wayland desktop shell that replaces the typical GNOME/KDE stack with a set of small, focused C binaries and shell scripts. It runs on top of labwc (a tiling/stacking Wayland compositor), uses zigshell-cairo-pango for panels and widgets, and fuzzel as the application launcher.

The project targets developers, power users, and anyone who wants full control over their desktop environment without the overhead of a full desktop suite.

### Core Properties

- **Pure C and GTK3** -- Every GUI utility (settings manager, theme center, font manager, dock manager, welcome wizard) is a native C binary. No web technologies.
- **Under 200 MB RAM** -- A complete session with panels, widgets, notifications, and media controls runs comfortably within 200 MB.
- **Modular architecture** -- Panels, widgets, daemons, and plugins are independent units. Replace any component without touching the others.
- **Theme engine** -- Change one INI file and the palette propagates to labwc, zigshell-cairo-pango, GTK, fuzzel, foot, rofi, mako, Qt6, and color tokens simultaneously.
- **Security-hardened** -- umask(0077) on all entry points, shell metacharacter validation before system(), XDG_RUNTIME_DIR for temp files, path traversal rejection, async-signal-safe signal handlers.

---

## Architecture

| Layer | Component | Role |
|-------|-----------|------|
| Compositor | labwc | Window management, input handling, keybindings, decorations |
| Shell UI | zigshell-cairo-pango | Panels, widgets, taskbar, tray, popups (C-native rendering) |
| Launcher | fuzzel | Application launcher and dmenu-mode script runner |
| Layer Shell | gtk-layer-shell | Anchors shell surfaces to Wayland outputs |

Supporting services: ocws-notify (D-Bus notifications), swayidle/swaylock (idle/lock), cliphist/wl-clipboard (clipboard history), playerctl (media), ocws-brightness (backlight), gammastep (night light), grim/slurp (screenshots).

---

## Shell Modes

OCWS supports multiple desktop paradigms through modular configuration. Switch between them without restarting:

| Mode | Description |
|------|-------------|
| Double Panel | Top status bar + bottom dock/taskbar (default OCWS experience) |
| Noctalia | Minimalist floating dynamic island bar (DankMaterialShell-inspired) |
| Zigshell-cairo-pango | Status bar + macOS-style bottom dock |
| Single Bar | Status bar only (zigshell-cairo-pango handles the dock) |
| Minimal | Lightweight bar with clock, volume, battery |

---

## C Utility Binaries

All system interactions are handled by compiled C binaries built with the Zig build system:

| Binary | Purpose |
|--------|---------|
| ocws | Unified entry point (subcommand dispatch) |
| ocws-settings | GTK3 settings manager for themes, keybindings, appearance |
| ocws-theme-center | Theme browser with live preview and palette visualization |
| ocws-fonts-mgr | Font manager with install/remove/preview |
| ocws-dock-mgr | Dock layout manager |
| ocws-welcome | First-run setup wizard |
| ocws-brokerd | C-native event bus daemon (replaces bash daemon) |
| ocws-notify | D-Bus notification daemon |
| ocws-brightness | Smooth backlight control with cubic easing |
| ocws-volume | Smooth PulseAudio volume control |
| ocws-shot | Screenshot tool with clipboard integration |
| ocws-clip | Clipboard manager |
| ocws-recorder | Screen recording (wf-recorder wrapper) |
| ocws-state | Persistent key-value state store |
| ocws-emit | IPC event emitter to zigshell-cairo-pango |
| ocws-validate | Configuration validator |

### GUI Applications

All GUI utilities are native GTK3 C binaries. They share a common pattern: header bar with integrated stack switcher, layer-shell anchoring via `ocws_background_app_init`, and tray icon for background persistence.

**System Management:**

| Application | Description |
|-------------|-------------|
| `ocws-settings` | Central settings panel — theme picker, corner radius sliders, font scaling, icon/cursor themes, keybinding presets, healthcheck |
| `ocws-theme-center` | Theme browser with live INI preview, palette visualization, and one-click apply |
| `ocws-fonts-mgr` | Font manager — install, preview, and remove fonts |
| `ocws-dock-mgr` | Visual dock layout editor with drag-and-drop app pinning |
| `ocws-dotdesktop-mgr` | .desktop file manager — create, edit, and organize application entries |
| `ocws-pkgmgr` | Package manager frontend — install and remove system packages |
| `ocws-welcome` | First-run setup wizard — walks through pairing, apps install, and config |
| `ocws-workspace-mgr` | Virtual desktop manager — rename, reorder, assign apps to workspaces |
| `ocws-llm-runner` | Local LLM chat interface (runs models via llama.cpp) |

**Audio Visualization (10-Band EQ + Spectrum Analyzer):**

| Application | Description |
|-------------|-------------|
| `ocws-equalizer` | 10-band graphic EQ with 6 presets + 64-bar FFT spectrum visualizer, L/R level meters, 4-band display, and centroid indicator |
| `ocws-equalizer-gl` | OpenGL-accelerated equalizer with real-time waveform rendering |
| `ocws-speaker-gl` | OpenGL speaker visualization — frequency response and phase plot |
| `ocws-speaker-qs` | Quick-settings speaker panel: volume, balance, mute, output selector |
| `ocws-waveform-gl` | OpenGL waveform viewer — real-time stereo PCM trace with scrolling display |
| `ocws-waveform-qs` | Quick-settings waveform — lightweight preview, route-aware |

**Utilities & Demos:**

| Application | Description |
|-------------|-------------|
| `ocws-snake-game` | Classic snake game running as a GTK3 layer-shell overlay |
| `ocws-todomvc` | TODO MVC demo app — reference implementation for the widget system |
| `ocws-datetime` | Floating date/time display widget |
| `ocws-wallpaper-picker` | Wallpaper browser — preview and apply from local collection |
| `ocws-equalizer-qs` | Quick-settings equalizer — compact UI for slider adjustments |

---

## Theme Engine

OCWS uses an INI-based theme system. Each theme file defines colors for labwc, zigshell-cairo-pango, GTK, fuzzel, foot, rofi, mako, Qt6, and more. The theme engine reads a single INI and generates all 14 configuration surfaces atomically.

### Built-in Themes

catppuccin-mocha, tokyo-night, dracula, nord, rose-pine, gruvbox, everforest, kanagawa, one-dark, solarized-dark, flexoki

### Usage

```bash
# List available themes
theme-engine.sh list

# Preview (reverts on Ctrl+C)
theme-engine.sh preview themes/catppuccin-mocha.ini

# Apply permanently
theme-engine.sh apply themes/catppuccin-mocha.ini

# Labwc-only (fast compositor theme switch)
labwc-theme next
```

---

## Installation

### Prerequisites

**Arch Linux:**

```bash
sudo pacman -S labwc zigshell-cairo-pango fuzzel gtk-layer-shell pipewire wireplumber \
  libpulse inotify-tools playerctl bc wl-clipboard cliphist \
  polkit-gnome swayidle swaylock grim slurp foot tesseract leptonica
```

**Debian/Ubuntu or Fedora:** See `distro/debian.sh` and `distro/fedora.sh`.

### Build from Source

```bash
git clone --depth=1 https://github.com/naranyala/labwc-fuzzel-zigshell-cairo-pango.git
cd labwc-fuzzel-zigshell-cairo-pango
zig build
```

Build options:

```bash
zig build -Dasan=true    # Build with AddressSanitizer (debug)
zig build test            # Run unit tests
```

### Install

```bash
./install.sh
```

The installer backs up existing configurations before deploying. It installs:

- labwc config to `~/.config/labwc/`
- OCWS config and widgets to `~/.config/ocws/`
- Scripts to `~/.local/bin/`
- C binaries from `zig-out/bin/` to `~/.local/bin/`

### Launch

From a display manager (GDM, SDDM, ly): select the labwc session.

From a TTY:

```bash
labwc
```

---

## Keybindings

| Key | Action |
|-----|--------|
| Super+Enter | Terminal (foot) |
| Super+D | App launcher (fuzzel) |
| Super+Q | Close window |
| Super+F | Toggle fullscreen |
| Super+1-9 | Switch workspace |
| Super+Shift+1-9 | Move window to workspace |
| Alt+Tab | Cycle windows |
| Super+C | Open ocws-settings |
| Super+W | Random wallpaper |
| Alt+F12 | Cycle labwc theme |
| XF86Audio* | Volume controls |
| XF86MonBrightness* | Brightness controls |
| Print | Screenshot |

Full keybindings are defined in `~/.config/labwc/rc.xml`.

---

## Configuration

| Path | Contents |
|------|----------|
| `~/.config/labwc/` | rc.xml, menu.xml, autostart, environment, themerc-override |
| `~/.config/ocws/` | ocws.config, widgets, daemon scripts, plugins |
| `~/.config/fuzzel/` | fuzzel.ini |
| `~/.config/foot/` | foot.ini |
| `~/.local/bin/` | All scripts and C binaries |

### Settings GUI

```bash
ocws-settings
```

The settings panel provides:

- Theme selection with live preview
- Corner radius and window margin sliders (live labwc reload)
- Font scaling
- Icon and cursor theme selection
- Shell mode switching
- Keybinding presets
- System healthcheck

---

## Event Bus

OCWS uses a lightweight IPC mechanism. Background daemons emit events via `ocws-emit`, and zigshell-cairo-pango subscribes to them through its variable system.

```bash
# Emit a volume update
ocws-emit System.Volume 75

# Emit media metadata
ocws-emit Media.Title "Song Name"
ocws-emit Media.Artist "Artist Name"
```

Full event namespace reference: `www/docs/configuration.md`

---

## Project Structure

```
labwc-fuzzel-zigshell-cairo-pango/
  build.zig              -- Zig build system (70+ targets)
  src/
    cli/                 -- CLI utilities (ocws-clip, ocws-shot, etc.)
    gui/                 -- GTK3 GUIs (settings, theme-center, fonts-mgr)
    daemons/             -- Background daemons (brokerd, notify)
    core/                -- Shared C code (kv store, utils)
    libocws/             -- Header-only C libraries (easing, audio, fs)
  dotfiles/
    labwc/               -- labwc config (rc.xml, themerc-override)
    ocws/                -- zigshell-cairo-pango config, widgets, CSS
  scripts/               -- Shell scripts (theme-engine, keybinds, etc.)
  themes/                -- INI theme files (11 built-in)
  templates/             -- Template files for theme engine
  tests/                 -- Test suites (bash, C integration, Zig unit)
  www/                   -- Documentation site (mkdocs)
```

---

## Security

OCWS includes active security hardening:

- **umask(0077)** on all daemon and CLI entry points
- **Shell metacharacter validation** before any system() or execl() call
- **XDG_RUNTIME_DIR** for PID files and temp data (never /tmp)
- **getpwuid() fallback** when $HOME is unset
- **Path traversal rejection** on user-supplied names
- **Async-signal-safe signal handlers** (volatile sig_atomic_t + GLib timeout)
- **AddressSanitizer** in CI builds
- **cppcheck** static analysis in CI

See `SECURITY.md` for the full security policy and vulnerability disclosure process.

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Run `zig build test` to verify changes
4. Submit a pull request

All C code should follow the existing style: gnu99, static inline for header-only libraries, `ocws_` prefix for public functions.

---

## License

See the repository for license details.
