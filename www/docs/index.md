# OCWS Documentation

OCWS is a native Wayland desktop shell built on C, GTK3, and labwc. This documentation covers installation, configuration, architecture, and development.

## What is OCWS?

OCWS replaces the typical GNOME/KDE stack with a set of focused C binaries and shell scripts. It runs on labwc (a Wayland compositor), uses zigshell-cairo-pango for panels and widgets, and fuzzel as the application launcher.

The result is a complete desktop environment that runs under 200 MB of RAM with zero JavaScript, Electron, or Qt runtime overhead.

## Key Features

- **Pure C and GTK3** -- All GUI utilities are native binaries. No web technologies.
- **Modular architecture** -- Panels, widgets, daemons, and plugins are independent units.
- **Theme engine** -- One INI file propagates colors to 14 configuration surfaces.
- **Multiple shell modes** -- Double panel, Noctalia floating island, Zigshell-cairo-pango, minimal.
- **Native settings GUI** -- Visual control for themes, appearance, keybindings, and system metrics.
- **Security-hardened** -- ASan in CI, shell injection prevention, proper temp file handling.

## Quick Start

```bash
git clone --depth=1 https://github.com/naranyala/labwc-fuzzel-zigshell-cairo-pango.git
cd labwc-fuzzel-zigshell-cairo-pango
./install.sh
```

Then select the labwc session from your display manager, or run `labwc` from a TTY.

## Architecture

| Layer | Component | Role |
|-------|-----------|------|
| Compositor | labwc | Window management, input, keybindings |
| Shell UI | zigshell-cairo-pango | Panels, widgets, taskbar, tray |
| Launcher | fuzzel | App launcher and dmenu-mode runner |
| Layer Shell | gtk-layer-shell | Anchors surfaces to Wayland outputs |

## Documentation Sections

- **Getting Started** -- Installation, first-run, troubleshooting
- **Configuration** -- Event bus API, plugin system, CSS customization
- **Events API** -- Full IPC event contract with variable mappings
- **Lessons Learned** -- 55+ implementation notes covering zigshell-cairo-pango internals, shell patterns, and security
- **Planning** -- Architecture decisions, unification strategy, dependency analysis
