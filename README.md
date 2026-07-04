# labwc + sfwbar + fuzzel

A Wayland desktop environment built on labwc (Openbox-inspired compositor), sfwbar (GTK3-native statusbar), and fuzzel (Wayland-native launcher). Ships with 40+ automation scripts, an INI-based theme engine, and a full GTK3/GTK4 theming pipeline.

---

## Quick Start

```bash
# Build labwc from source
./download-labwc.sh --install

# Install all dotfiles (backs up existing configs)
./dotfiles/install.sh

# Launch from TTY
./scripts/start-labwc.sh
```

---

## Architecture

### Core Components

| Component | Role | Config |
|-----------|------|--------|
| labwc | Wayland compositor (Openbox-inspired, wlroots-based) | ~/.config/labwc/ |
| sfwbar | GTK3-native statusbar/taskbar/panel | ~/.config/sfwbar/ |
| fuzzel | Application launcher, window switcher, dmenu | ~/.config/fuzzel/ |
| foot | Wayland terminal emulator | keybindings |
| crystal-dock | Wayland dock with animations | autostart |
| swaybg | Wallpaper setter | autostart |

### Integration Flow

```
labwc (compositor)
  |-- autostart --> sfwbar -f sfwbar.config -c catppuccin-mocha.css
  |             --> crystal-dock --start --overlay
  |             --> swaybg / wallpaper random
  |             --> mako/dunst (notifications)
  |             --> gammastep/redshift (screen color)
  |             --> cliphist + wl-paste (clipboard)
  |             --> nm-applet, blueman-applet, udiskie
  |
  |-- rc.xml --> keybindings (Alt+A -> fuzzel, Alt+Return -> foot, etc.)
  |          --> window rules (sfwbar skip_taskbar, crystal-dock fixed_position)
  |          --> root menu (menu.xml)
  |
  |-- environment --> WAYLAND_DISPLAY, XDG_SESSION_TYPE, GDK_BACKEND, etc.
  |
  `-- themerc-override --> window decoration colors, titlebar height
```

### Theme Engine

INI profiles (themes/*.ini) define colors for all components. The theme engine (scripts/theme-engine.sh) renders templates (templates/*.tmpl) into config files:

```
themes/catppuccin-mocha.ini  -->  templates/sfwbar.css.tmpl     -->  ~/.config/sfwbar/theme.css
                           |-->  templates/fuzzel.ini.tmpl     -->  ~/.config/fuzzel/fuzzel.ini
                           |-->  templates/themerc-override.tmpl --> ~/.config/labwc/themerc-override
                           |-->  templates/gtk.css.tmpl        -->  ~/.config/gtk-3.0/gtk.css
                           |-->  templates/foot.ini.tmpl       -->  ~/.config/foot/foot.ini
                           `-->  (8 more templates)
```

Single source of truth: [colors] section in each INI profile.

---

## Project Structure

```
labwc-fuzzel-sfwbar/
|-- README.md
|-- download-labwc.sh                   # Build labwc from source
|
|-- dotfiles/
|   |-- install.sh                      # Main installer (15 sections)
|   |-- labwc/
|   |   |-- rc.xml                      # Keybindings, window rules, menus (247 lines)
|   |   |-- autostart                   # Startup script (sfwbar, dock, clipboard, etc.)
|   |   |-- environment                 # Wayland/GTK/Qt env vars
|   |   |-- menu.xml                    # Desktop right-click menu
|   |   |-- themerc-override            # Window decoration theme
|   |   `-- presets/                    # Keybinding presets
|   |-- sfwbar/
|   |   |-- sfwbar.config              # Main config: dual-bar (top + bottom)
|   |   |-- sfwbar-noctalia.config     # Single-bar noctalia layout
|   |   |-- sfwbar-compact.config      # Minimal single bar
|   |   |-- sfwbar-full.config         # Full-featured single bar
|   |   |-- sfwbar-dashboard.config    # Dashboard with all widgets
|   |   |-- catppuccin-mocha.css       # GTK CSS theme
|   |   |-- noctalia.css               # Noctalia CSS theme
|   |   |-- *.widget                   # 40 widget files
|   |   `-- *.source                   # Data source files (cpu, memory, battery)
|   |-- fuzzel/
|   |   `-- fuzzel.ini                 # Fuzzel config (Catppuccin Mocha colors)
|   |-- gtk/
|   |   |-- gtk3-settings.ini          # GTK3 theme, font, cursor settings
|   |   `-- gtk4-settings.ini          # GTK4 theme, font, cursor settings
|   |-- fontconfig/
|   |   `-- fonts.conf                 # Font rendering config (antialias, hinting)
|   |-- crystal-dock/
|   |   `-- labwc/panel_1.conf         # Dock panel config
|   |-- noctalia/
|   |   `-- config.toml                # Noctalia shell config
|   |-- wallpaper                      # Wallpaper manager script
|   `-- wallpaper-sources.txt          # Download URLs
|
|-- scripts/                            # 50+ automation scripts
|   |-- validate.sh                    # 25+ checks: binaries, configs, XML, fonts, widgets
|   |-- fix.sh                         # Auto-fix: 15 sections, --dry-run support
|   |-- health-check.sh               # Quick one-shot health check
|   |-- debug-sfwbar.sh               # SFWBar debugger: process, config, widgets, logs
|   |-- fix-gtk-fonts.sh              # Fix GTK font corruption, fontconfig
|   |-- screenshot-tool.sh            # Unified screenshot: area/full/window/annotate
|   |-- reset-sfwbar.sh               # Reset sfwbar to project defaults
|   |-- reset-theme.sh                # Reset all configs to a theme profile
|   |-- sync-dotfiles.sh              # Sync dotfiles to ~/.config
|   |-- theme-engine.sh               # INI -> template -> config renderer (638 lines)
|   |-- theme.sh                       # Theme manager (apply/list/next/prev)
|   |-- relaunch-status-bars.sh        # Restart sfwbar + crystal-dock
|   |-- diagnostics.sh                 # Deep system report (processes, GPU, audio, network)
|   |-- backup.sh / restore.sh        # Timestamped backup with rotation
|   |-- install-deps.sh               # Auto-detect distro, install packages
|   |-- font-scale.sh                 # Global font scaling across all configs
|   |-- keybinds.sh                   # View/add/remove keybindings
|   |-- start-labwc.sh                # Launch with pre-flight checks
|   `-- actions/                       # 12 action scripts
|       |-- screenshot.sh              # grim+slurp, satty/swappy annotate
|       |-- power-menu.sh             # Shutdown/reboot/logout via rofi
|       |-- audio.sh                   # Volume control via wpctl
|       |-- brightness.sh             # Brightness via brightnessctl
|       |-- clipboard.sh             # Clipboard history via cliphist
|       |-- network.sh                # WiFi/BT toggle
|       |-- fuzzel-calc.sh            # Calculator via fuzzel+bc
|       |-- fuzzel-emoji.sh           # Emoji picker via fuzzel
|       |-- launcher.sh               # App launcher (rofi/wofi/fuzzel)
|       |-- maintenance.sh            # Interactive maintenance menu
|       |-- window.sh                  # Window snap/float/fullscreen
|       `-- workspace.sh              # Workspace switch/move
|
|-- themes/                             # 11 INI theme profiles
|   |-- catppuccin-mocha.ini           # Warm pastel dark (default)
|   |-- dracula.ini                    # Purple accent
|   |-- nord.ini                       # Arctic blue
|   |-- tokyo-night.ini               # Neon blue
|   |-- gruvbox.ini                    # Retro warm
|   |-- everforest.ini                # Green forest
|   |-- flexoki.ini                    # Red ink
|   |-- kanagawa.ini                   # Japanese ink
|   |-- one-dark.ini                   # Atom dark
|   |-- rose-pine.ini                  # Muted pastel
|   `-- solarized-dark.ini            # Solarized dark
|
|-- templates/                          # Theme engine templates
|   |-- sfwbar.css.tmpl               # sfwbar CSS (12 color vars)
|   |-- fuzzel.ini.tmpl               # fuzzel config
|   |-- themerc-override.tmpl         # labwc window decorations
|   |-- gtk.css.tmpl                  # GTK CSS overrides
|   |-- gtk3-settings.ini.tmpl        # GTK3 settings
|   |-- gtk4-settings.ini.tmpl        # GTK4 settings
|   |-- environment.tmpl              # labwc environment vars
|   |-- foot.ini.tmpl                 # foot terminal colors
|   |-- rofi.rasi.tmpl                # rofi launcher theme
|   |-- mako.ini.tmpl                 # mako notification theme
|   `-- qt6ct.conf.tmpl               # Qt6 theme
|
|-- components/                         # C-based widget system (experimental)
|-- docs/
|   |-- configuration.md              # Full keybinding and config reference
|   `-- getting-started.md            # Setup guide and troubleshooting
|
`-- build/                              # Build artifacts (gitignored)
```

---

## SFWBar Statusbar

sfwbar is the sole statusbar. Configured in dotfiles/sfwbar/.

### Config Variants

| Config | Layout | Widgets |
|--------|--------|---------|
| sfwbar.config | Dual-bar (top + bottom) | launcher, workspaces, clock, media, tray, network, bluetooth, volume, brightness, battery, session, taskbar, showdesktop |
| sfwbar-noctalia.config | Single top bar | launcher, pager, clock, tray, media-player, network-monitor, volume-control, battery-monitor, session |
| sfwbar-compact.config | Single top bar | launcher, clock, media, tray, network, volume, battery, session |
| sfwbar-full.config | Single top bar | launcher, workspaces, clock, media, tray, network, bluetooth, volume, brightness, battery, cpu, memory, temperature, session |
| sfwbar-dashboard.config | Single top bar | All 20+ widgets |

### Widget Files (40)

| Category | Widgets |
|----------|---------|
| System | cpu-monitor, cpu-text, memory-monitor, memory-text, temperature, disk, sysmon |
| Audio/Video | volume-control, volume-text, media-player, media |
| Network | network-monitor, network-text, wifi, wifi-secret, bluetooth-monitor, bluetooth |
| Power | battery-monitor, battery-text, brightness, power-profile, nightlight |
| UI | clock, cal, tray, launcher, workspaces, session, keybinds, keyboard-layout |
| Privacy | clipboard, privacy, idle-inhibit, notification-center, quick-settings |
| Misc | showdesktop, custom-script, weather |

### SFWBar Launch

sfwbar requires -f (config) and -c (CSS) flags:

```bash
sfwbar -f ~/.config/sfwbar/sfwbar.config -c ~/.config/sfwbar/catppuccin-mocha.css
```

The Css = "..." config directive is not supported. Always pass CSS via -c flag.

### Workspace Switching

sfwbar uses its built-in pager widget with WorkspaceActivate() action (Wayland protocol). Do not use labwc -e 'GoToDesktop N' -- labwc has no CLI IPC flag.

---

## Keybindings

Key format: A- = Alt, W- = Super, S- = Shift, C- = Ctrl.

### System

| Key | Action |
|-----|--------|
| A-r | Reload labwc config |
| A-q / A-F4 | Close window |
| W-m | Exit labwc |

### Launchers

| Key | Action |
|-----|--------|
| W-Return / A-Return | foot terminal |
| A-a | fuzzel app launcher |
| A-c | Calculator (fuzzel+bc) |
| A-period | Emoji picker (fuzzel) |
| A-F5 | Power menu |
| A-S-F12 | Theme picker |

### Window Management

| Key | Action |
|-----|--------|
| A-f | Toggle fullscreen |
| W-a | Toggle maximize |
| A-space | Root menu |
| A-Tab / A-S-Tab | Cycle window focus |
| S-A-Left/Right/Up/Down | Snap window to edge |
| W-Left/Right/Up/Down | Resize window |

### Workspaces

| Key | Action |
|-----|--------|
| W-1 to W-9 | Switch to desktop 1-9 |
| S-W-1 to S-W-9 | Send window to desktop 1-9 |
| C-A-Left/Right | Next/previous desktop |

### Media

| Key | Action |
|-----|--------|
| XF86AudioRaise/Lower | Volume up/down |
| XF86AudioMute | Toggle mute |
| XF86AudioPlay/Next/Prev | Media controls |
| XF86MonBrightnessUp/Down | Brightness |
| Print | Screenshot (area) |
| A-Print | Screenshot (full) |
| W-v | Clipboard history (cliphist+fuzzel) |

---

## Theming

### Theme Profiles

11 INI profiles in themes/ define colors for all components:

| Theme | Base | Accent | Style |
|-------|------|--------|-------|
| catppuccin-mocha | #1e1e2e | #89b4fa | Warm pastel dark |
| dracula | #282a36 | #bd93f9 | Purple accent |
| nord | #2e3440 | #88c0d0 | Arctic blue |
| tokyo-night | #1a1b26 | #7aa2f7 | Neon blue |
| gruvbox | #282828 | #fabd2f | Retro warm |
| everforest | #2d353b | #a7c080 | Green forest |
| flexoki | #100f0f | #ef466f | Red ink |
| kanagawa | #1f1f28 | #7e9cd8 | Japanese ink |
| one-dark | #282c34 | #61afef | Atom dark |
| rose-pine | #191724 | #ebbcba | Muted pastel |
| solarized-dark | #002b36 | #268bd2 | Solarized |

### Applying Themes

```bash
theme catppuccin-mocha     # Apply theme
theme list                 # List available themes
theme next                 # Cycle to next theme
theme current              # Show active theme
```

### What Gets Themed

- labwc window decorations (themerc-override)
- GTK3/GTK4 theme, icons, cursors, fonts
- sfwbar CSS panel colors
- fuzzel launcher colors
- foot terminal colors
- rofi launcher colors
- mako notification colors
- Qt6 theme (qt6ct)
- labwc environment (cursor theme, size)

---

## Scripts Reference

### Validation and Repair

| Script | Purpose |
|--------|---------|
| validate.sh | 25+ checks: binaries, XML syntax, fonts, widget refs, desktop count |
| fix.sh | 15 auto-fix sections with --dry-run support |
| health-check.sh | Quick one-shot check with inline fixes |
| debug-sfwbar.sh | sfwbar process, config, widget, log debugger |
| fix-gtk-fonts.sh | Fix gtk-font-name corruption, fontconfig |

### Installation and Sync

| Script | Purpose |
|--------|---------|
| install.sh | Full installer: backup, install, theme, validate (15 sections) |
| sync-dotfiles.sh | Sync dotfiles to ~/.config (--only COMPONENT supported) |
| reset-sfwbar.sh | Reset sfwbar to project defaults (--keep-css, --dry-run) |
| reset-theme.sh | Reset all configs to a theme profile |

### Theme Management

| Script | Purpose |
|--------|---------|
| theme-engine.sh | INI parser + template renderer (638 lines, 12 templates) |
| theme.sh | Theme apply/list/next/prev/current |
| theme-picker.sh | Interactive rofi-based theme picker |
| download-themes.sh | Download GTK/icon/cursor/font resources |

### System Management

| Script | Purpose |
|--------|---------|
| start-labwc.sh | Launch labwc with pre-flight checks |
| relaunch-status-bars.sh | Restart sfwbar + crystal-dock |
| diagnostics.sh | Deep system report (processes, GPU, audio, network, disk) |
| backup.sh / restore.sh | Timestamped backup with rotation |
| install-deps.sh | Auto-detect distro, install packages |
| font-scale.sh | Global font scaling across all configs |
| update.sh | Update labwc from source |

### Actions (scripts/actions/)

| Script | Purpose |
|--------|---------|
| screenshot.sh | grim+slurp area/full/window, satty/swappy annotate |
| power-menu.sh | Shutdown/reboot/logout via rofi |
| audio.sh | Volume control via wpctl |
| brightness.sh | Brightness via brightnessctl |
| clipboard.sh | Clipboard history via cliphist+fuzzel |
| network.sh | WiFi/BT toggle |
| fuzzel-calc.sh | Calculator via fuzzel+bc |
| fuzzel-emoji.sh | Emoji picker via fuzzel |
| launcher.sh | App launcher (rofi/wofi/fuzzel/bemenu) |
| maintenance.sh | Interactive maintenance menu |
| window.sh | Window snap/float/fullscreen |
| workspace.sh | Workspace switch/move |

---

## Installation

### Prerequisites

```bash
# Required
labwc sfwbar foot fuzzel swaybg

# Optional (recommended)
crystal-dock grim slurp wl-copy playerctl wpctl gammastep mako dunst
```

### Install Steps

```bash
# 1. Build labwc (if not installed)
./download-labwc.sh --install

# 2. Install dependencies
./scripts/install-deps.sh

# 3. Install dotfiles
./dotfiles/install.sh

# 4. Launch
./scripts/start-labwc.sh
```

### What Gets Installed

| Destination | Source | Contents |
|-------------|--------|----------|
| ~/.config/labwc/ | dotfiles/labwc/ | rc.xml, autostart, environment, menu.xml, themerc-override |
| ~/.config/sfwbar/ | dotfiles/sfwbar/ | sfwbar.config, CSS, 40 widget files |
| ~/.config/gtk-3.0/ | dotfiles/gtk/ | settings.ini, gtk.css |
| ~/.config/gtk-4.0/ | dotfiles/gtk/ | settings.ini, gtk.css |
| ~/.config/fuzzel/ | dotfiles/fuzzel/ | fuzzel.ini |
| ~/.config/fontconfig/ | dotfiles/fontconfig/ | fonts.conf |
| ~/.local/bin/ | scripts/ | 50+ scripts |
| ~/.local/bin/actions/ | scripts/actions/ | 12 action scripts |

### Validation

```bash
# Check setup
./scripts/validate.sh

# Auto-fix issues
./scripts/fix.sh

# Quick health check
./scripts/health-check.sh
```

---

## Troubleshooting

### sfwbar does not start

```bash
# Check config syntax
sfwbar -f ~/.config/sfwbar/sfwbar.config -c ~/.config/sfwbar/catppuccin-mocha.css 2>&1

# Check for missing widget files
grep 'widget "' ~/.config/sfwbar/sfwbar.config | while read line; do
  name=$(echo "$line" | grep -oP 'widget "\K[^"]+')
  [ ! -f ~/.config/sfwbar/$name ] && echo "MISSING: $name"
done

# Debug sfwbar
./scripts/debug-sfwbar.sh
```

### GTK apps show empty text

```bash
# Fix font settings
./scripts/fix-gtk-fonts.sh

# Check fontconfig
ls ~/.config/fontconfig/fonts.conf
```

### Click forwarding broken

```bash
# Check for Left Press bug in Client context
grep -A5 'context name="Client"' ~/.config/labwc/rc.xml

# Should only have A-Left Drag (Move) and A-Right Drag (Resize)
# If you see button="Left" action="Press", run:
./scripts/fix.sh
```

### Theme not applying

```bash
# Check theme engine
./scripts/theme-engine.sh list

# Apply manually
./scripts/theme-engine.sh apply themes/catppuccin-mocha.ini

# Restart sfwbar
relaunch-status-bars.sh sfwbar
```

---

## References

- labwc: https://labwc.github.io/
- sfwbar: https://github.com/LBCrion/sfwbar
- fuzzel: https://codeberg.org/dnkl/fuzzel
- Catppuccin Mocha: https://github.com/catppuccin/catppuccin
