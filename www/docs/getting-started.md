# Getting Started

This guide details the installation procedures, initial configuration, and troubleshooting protocols for the Open Compositor Widget Shell (OCWS). OCWS is a streamlined Wayland desktop environment engineered using `labwc`, `zigshell-cairo-pango`, and `fuzzel`, developed exclusively with C and GTK3 to ensure optimal performance.

## Architectural Overview

The OCWS framework is structured across four primary layers:

| Architecture Layer | Component | Functionality |
|--------------------|-----------|---------------|
| Compositor | labwc | Manages Wayland sessions, window operations, input processing, and keybindings. |
| User Interface | zigshell-cairo-pango | Provides the GTK3 panel engine, encompassing widgets, system tray, taskbar, and interactive popups. |
| Application Launcher | fuzzel | Serves as the application launcher and executes `dmenu`-compatible scripts. |
| Layer Shell | gtk-layer-shell | Anchors interface surfaces securely to the designated Wayland outputs. |

Ancillary services include: `ocws-notify` (notification management), `swayidle` and `swaylock` (session idle and lock enforcement), `cliphist` and `wl-clipboard` (clipboard operations), `playerctl` (media control), `ocws-brightness` (display luminance adjustment), `gammastep` (color temperature regulation), and `grim` with `slurp` (screen capture utilities).

## Installation Procedure

### Step 1: Fulfill System Dependencies

For Arch Linux environments:

```bash
sudo pacman -S labwc zigshell-cairo-pango fuzzel gtk-layer-shell pipewire wireplumber libpulse \
  inotify-tools playerctl bc wl-clipboard cliphist \
  polkit-gnome swayidle swaylock grim slurp foot tesseract leptonica
```

For Debian/Ubuntu or Fedora environments, consult the respective scripts located at `distro/debian.sh` and `distro/fedora.sh`.

To compile the latest upstream iterations directly from source:

```bash
./build-ocws-core.sh all
```

### Step 2: Execute the Deployment Script

```bash
git clone --depth=1 https://github.com/naranyala/labwc-fuzzel-zigshell-cairo-pango.git
cd labwc-fuzzel-zigshell-cairo-pango
./install.sh
```

The deployment script performs the following operations automatically:

1. Validates all necessary system dependencies.
2. Archives existing configurations located at `~/.config/labwc/` and `~/.config/ocws/`.
3. Provisions `dotfiles/labwc/` into `~/.config/labwc/`.
4. Provisions `dotfiles/ocws/` into `~/.config/ocws/`.
5. Provisions `dotfiles/fuzzel/` into `~/.config/fuzzel/`.
6. Configures GTK parameters within `~/.config/gtk-3.0/` and `~/.config/gtk-4.0/`.
7. Establishes symbolic links for all operational scripts from `scripts/` to `~/.local/bin/`.
8. Establishes symbolic links for action scripts from `scripts/actions/` to `~/.local/bin/actions/`.
9. Deploys compiled C binaries from `zig-out/bin/` to `~/.local/bin/`.
10. Registers `.desktop` entries within `~/.local/share/applications/`.

### Step 3: Initialize the Session

If utilizing a Display Manager (e.g., GDM, SDDM, ly), proceed to log out and select the `labwc` session.

Alternatively, to initiate from a TTY interface:

```bash
labwc
```

## Configuration Directory Structure

| Path | Description |
|------|-------------|
| `~/.config/labwc/` | Contains `rc.xml`, `menu.xml`, `autostart`, `environment`, and `themerc-override`. |
| `~/.config/ocws/` | Contains `ocws.config`, `*.widget`, `ocws-daemon.sh`, `plugins/`, and `state.kv`. |
| `~/.config/fuzzel/` | Contains `fuzzel.ini`. |
| `~/.config/foot/` | Contains `foot.ini`. |
| `~/.local/bin/` | Houses all executable scripts (`scripts/*.sh`) and compiled C helper binaries (`ocws-*`). |
| `~/.local/bin/actions/` | Houses all execution scripts located in `scripts/actions/*.sh`. |

## Startup Services Initialization

The `~/.config/labwc/autostart` script is executed concurrently with `labwc` initialization. The primary services initiated include:

| Service | Execution Command | Functionality |
|---------|-------------------|---------------|
| Background Manager | `ocws-wallpaper ~/Pictures/wallpapers/` | Facilitates dynamic, time-based wallpaper transitions. |
| Interface Engine | `zigshell-cairo-pango` | Drives the native GTK3 OCWS graphical interface. |
| OCWS Daemon | `~/.config/ocws/ocws-daemon.sh` | Operates the Event Bus IPC listener. |
| Notification Server | `ocws-notify` | Manages D-Bus notification requests. |
| Clipboard Manager | `wl-paste --watch cliphist store` | Maintains a persistent clipboard history. |
| Session Lock | `swayidle -w timeout 300 'swaylock -f'` | Enforces automatic session locking after predefined inactivity. |
| Color Regimen | `gammastep -t 6500:3500 -g 1.0 -r` | Adjusts display color temperature for optimal viewing. |

## Standard Keybindings

Keybindings are centrally configured within `~/.config/labwc/rc.xml`.

### Application Execution

| Key Combination | Action |
|-----------------|--------|
| Super+Enter | Initialize terminal emulator (`foot`). |
| Super+D | Initialize application launcher (`fuzzel`). |
| Super+V | Access clipboard history interface (`cliphist` + `fuzzel`). |
| Super+Q | Terminate the currently focused window. |
| Super+F | Toggle fullscreen state for the active window. |

### Workspace Management

| Key Combination | Action |
|-----------------|--------|
| Super+1-9 | Navigate to workspace 1 through 9. |
| Super+Shift+1-9 | Relocate the active window to workspace 1 through 9. |
| Alt+Tab | Cycle through active application windows. |

### System Controls

| Key Combination | Action |
|-----------------|--------|
| XF86AudioRaiseVolume | Increment system volume. |
| XF86AudioLowerVolume | Decrement system volume. |
| XF86AudioMute | Toggle audio mute state. |
| XF86MonBrightnessUp | Increment display brightness. |
| XF86MonBrightnessDown | Decrement display brightness. |
| Print | Capture a designated screen region to the filesystem. |
| Super+Print | Capture the entire display area to the filesystem. |
| Shift+Print | Capture a designated screen region directly to the clipboard. |

## Shell Interaction Protocols

### Shell Layout Paradigms

OCWS facilitates multiple desktop environments through a highly modular configuration architecture. Users may transition between layouts dynamically:

```bash
# Command Line Interface (CLI)
toggle-shell doublepanel          # Initialize the dual-panel layout (Default).
toggle-shell zigshell-cairo-pango # Initialize the status bar and dock layout.
toggle-shell minimal              # Initialize the minimal bar layout.
toggle-shell dms                  # Initialize the DankMaterialShell layout.
toggle-shell noctalia             # Initialize the Noctalia layout.
```

Alternatively, utilize the graphical settings utility:

```bash
ocws-settings
```

### Aesthetic Configuration

```bash
# Retrieve a list of available themes
theme-engine.sh list

# Initiate a live preview of a designated theme (Reverts upon Ctrl+C)
theme-engine.sh preview themes/catppuccin-mocha.ini

# Persistently apply a designated theme
theme-engine.sh apply themes/catppuccin-mocha.ini
```

Supported themes include: `catppuccin-mocha`, `tokyo-night`, `dracula`, `nord`, `rose-pine`, `gruvbox`, `everforest`, `kanagawa`, `one-dark`, `solarized-dark`, and `flexoki`.

### Hardware State Modulation

Adjustments to hardware parameters incorporate cubic easing for fluid transitions:

```bash
ocws-brightness set 50    # Smoothly transition display brightness to 50%.
ocws-brightness up        # Increment brightness by 5% with animation.
ocws-volume set 75        # Smoothly transition system volume to 75%.
ocws-volume up            # Increment volume by 5% with animation.
```

## System Verification

```bash
# Confirm the presence of core binaries within the system PATH
which labwc zigshell-cairo-pango fuzzel foot ocws

# Validate the existence of requisite configuration directories
ls ~/.config/ocws/
ls ~/.config/labwc/

# Confirm the successful deployment of C helper binaries
ls ~/.local/bin/ocws

# Execute a diagnostic test of the Event Bus
ocws-emit System.Volume 75
```

## Troubleshooting Guidelines

### Failure of `zigshell-cairo-pango` Initialization

```bash
# Execute the application manually to capture standard error outputs
zigshell-cairo-pango -f ~/.config/ocws/ocws.config

# Inspect configuration files for missing module inclusions
grep -r 'Include\|Scanner' ~/.config/ocws/ocws.config
```

### Failure of `labwc` Initialization or Black Screen Occurrence

```bash
# Employ the dedicated debugging script
debug-labwc.sh

# Execute `labwc` from a TTY environment with verbose logging
labwc 2>&1 | tee /tmp/labwc.log
```

### Theme Application Failure

```bash
theme-engine.sh list
theme-engine.sh apply themes/catppuccin-mocha.ini
labwc --reconfigure
```

### Empty Clipboard History

```bash
# Verify the operational status of the cliphist daemon
pgrep -a wl-paste
# If inactive, initialize the daemon process
wl-paste --type text/plain --watch cliphist store &
```

### Non-Responsive Hardware Control Keys

```bash
# Manually execute the corresponding action scripts to verify functionality
~/.local/bin/actions/audio.sh up
~/.local/bin/actions/brightness.sh up

# Validate the keybinding definitions within the configuration file
grep -A3 'XF86Audio\|XF86MonBrightness' ~/.config/labwc/rc.xml
```

## Supplementary Documentation

- `docs/configuration.md` — Details regarding the Event Bus API, plugin architecture, and CSS implementation.
- `docs/events.md` — Comprehensive specifications of the IPC event contract and variable mappings.
- `docs/gui-managers.md` — Information on native GTK3 graphical utility applications.
- `docs/lessons/` — A repository of implementation notes documenting internal mechanisms, defect resolutions, and design patterns.
- `TODOS.md` — The strategic developmental roadmap and phase tracking document.
