# labwc — Learning Material

> Source: `./sources/labwc` | Upstream: https://github.com/labwc/labwc

---

## What is labwc?

**labwc** (Lab Wayland Compositor) is a wlroots-based, stacking window compositor for Wayland.
It is inspired by Openbox — lightweight, minimal, and focused on doing one thing well: stacking
windows and rendering window decorations. It has no dependency on GTK, Qt, or any desktop
environment.

In OCWS, labwc is the **core display engine** — it manages the Wayland session, input handling,
window placement, keybindings, and autostart.

---

## Key Concepts

### Stacking Compositor
Unlike tiling compositors (Sway, Hyprland), labwc uses a **floating/stacking** model where
windows can be freely placed, moved, resized, and layered. This maps directly to Openbox's UX.

### wlroots-based
labwc is built on [wlroots](https://gitlab.freedesktop.org/wlroots/wlroots), the standard
low-level Wayland compositor library. It supports all standard `wayland-protocols` and
`wlr-protocols`. It does NOT use dbus, sway-IPC, or any custom IPC mechanism.

### No Built-in Panels or Launchers
labwc deliberately has no panel, launcher, wallpaper, or screenshot tool. Those are handled by
external clients — in OCWS: zigshell-cairo-pango (panel), fuzzel (launcher), swaybg (wallpaper).

---

## Installation

### Quick Installation
```bash
# Install from package manager (Arch Linux)
sudo pacman -S labwc

# Or build from source
cd sources/labwc
meson setup build/
meson compile -C build/
sudo meson install -C build/
```

### Dependencies
**System dependencies:**
- wlroots, wayland, libinput, xkbcommon
- libxml2, cairo, pango, glib-2.0
- libpng
- librsvg >=2.46 (optional, for SVG icons)

**Build dependencies:**
- meson, ninja
- wayland-protocols

---

## Quick Start - First Configuration

### Create Basic Configuration
```bash
# Create initial directory structure
mkdir -p ~/.config/labwc

# Set up basic keybindings
cat > ~/.config/labwc/rc.xml << 'EOF'
<labwc_config>
  <core>
    <gap>10</gap>
  </core>

  <theme>
    <name>OCWS-Glass</name>
    <cornerRadius>8</cornerRadius>
  </theme>

  <keyboard>
    <keybind key="Super_L">
      <action name="Execute">
        <command>fuzzel</command>
      </action>
    </keybind>
    
    <keybind key="Super_Return">
      <action name="Execute">
        <command>foot</command>
      </action>
    </keybind>
    
    <keybind key="Super_Q">
      <action name="Close"/>
    </keybind>
  </keyboard>
</labwc_config>
EOF

# Create basic autostart
cat > ~/.config/labwc/autostart << 'EOF'
# Launch wallpaper manager with OCWS wallpaper
if command -v swaybg >/dev/null 2>&1; then
    WP_DIR="$HOME/Pictures/wallpapers"
    WP_FILE=$(find "$WP_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" \) | shuf -n 1)
    swaybg -i "$WP_FILE" -m fill &
fi

# Start the zigshell-cairo-pango panel
zigshell-cairo-pango &

# Notification daemon
mako &

# Idle/lock management
swayidle -w timeout 300 'swaylock -f' &
EOF
```

## Configuration Files

All config files live in `~/.config/labwc/` (or `$XDG_CONFIG_HOME/labwc/`).

| File | Purpose |
|------|---------|
| `rc.xml` | Main config: keybindings, window rules, mouse actions, theme name |
| `menu.xml` | Right-click desktop context menu |
| `autostart` | Shell script executed on compositor startup |
| `environment` | Environment variables set before the session starts |
| `themerc-override` | Override specific values of the active Openbox theme |
| `shutdown` | Script executed on compositor shutdown |

Reload config at runtime with:
```bash
labwc --reconfigure
```

### rc.xml Anatomy
The main config is XML. Key sections:

```xml
<labwc_config>
  <core>
    <gap>10</gap>               <!-- Gap between windows and screen edges -->
  </core>

  <theme>
    <name>MyTheme</name>        <!-- Openbox theme name -->
    <cornerRadius>8</cornerRadius>
  </theme>

  <keyboard>
    <keybind key="Super_L">     <!-- Super key actions -->
      <action name="Execute">
        <command>fuzzel</command>
      </action>
    </keybind>
  </keyboard>

  <mouse>
    <context name="Frame">
      <mousebind button="Left" action="Drag">
        <action name="Move"/>
      </mousebind>
    </context>
  </mouse>

  <windowRules>
    <windowRule identifier="*" matchOnce="true">
      <action name="ToggleDecorations"/>
    </windowRule>
  </windowRules>
</labwc_config>
```

---

## Quick Start - First Configuration

### Create Basic Configuration
```bash
# Create initial directory structure
mkdir -p ~/.config/labwc

# Set up basic keybindings
cat > ~/.config/labwc/rc.xml << 'EOF'
<labwc_config>
  <core>
    <gap>10</gap>
  </core>

  <theme>
    <name>OCWS-Glass</name>
    <cornerRadius>8</cornerRadius>
  </theme>

  <keyboard>
    <keybind key="Super_L">
      <action name="Execute">
        <command>fuzzel</command>
      </action>
    </keybind>
    
    <keybind key="Super_Return">
      <action name="Execute">
        <command>foot</command>
      </action>
    </keybind>
    
    <keybind key="Super_Q">
      <action name="Close"/>
    </keybind>
  </keyboard>
</labwc_config>
EOF

# Create basic autostart
cat > ~/.config/labwc/autostart << 'EOF'
# Launch wallpaper dynamically
WP_DIR="$HOME/Pictures/wallpapers"
WP_FILE=$(find "$WP_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" \) | shuf -n 1)
swaybg -i "$WP_FILE" -m fill &

# Start the zigshell-cairo-pango panel
zigshell-cairo-pango &

# Notification daemon
mako &

# Idle management
swayidle -w timeout 300 'swaylock -f' &
EOF
```

## Theming

### Using OCWS Glass Theme
Labwc uses the **Openbox theme spec**. OCWS provides a glassmorphic theme:

```bash
# Create theme override
cat > ~/.config/labwc/themerc-override << 'EOF'
window.active.title.bg.color: #1a1a2e
window.active.title.fg.color: #cdd6f4
window.active.border.color: #89b4fa
window.active.decoration.shadow: rgba(0, 0, 0, 0.3)
window.inactive.title.bg.color: #181825
window.inactive.title.fg.color: #a6adc8
window.inactive.border.color: #313244
window.inactive.decoration.shadow: rgba(0, 0, 0, 0.2)

background: rgba(15, 15, 25, 0.72)
EOF

# Apply theme with theme-engine
./scripts/theme-engine.sh apply ./themes/catppuccin-mocha.ini
```

### Theme Directory Structure
```
~/.local/share/themes/
  ├── OCWS-Glass/
  │   └── labwc/
  │       └── themerc        # Actual theme
  └── MyCustom/
      └── labwc/
          ├── themerc      # Main theme
          ├── widgets/      # Custom window rules
          └── overrides/    # Additional overrides
```

---

## Autostart Setup

### Default OCWS Autostart
`~/.config/labwc/autostart`:

```bash
#!/bin/bash
# Launch wallpaper manager with OCWS wallpaper
if command -v swaybg >/dev/null 2>&1; then
    WP_DIR="$HOME/Pictures/wallpapers"
    WP_FILE=$(find "$WP_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" \) | shuf -n 1)
    swaybg -i "$WP_FILE" -m fill &
fi

# Start the zigshell-cairo-pango panel
zigshell-cairo-pango &

# Notification daemon
mako &

# Idle management
swayidle -w timeout 300 'swaylock -f' &
```

### Custom Autostart Examples

#### Minimal Setup
```bash
cat > ~/.config/labwc/autostart << 'EOF'
# Essential components only
zigshell-cairo-pango &
EOF
```

#### Full Desktop Environment
```bash
cat > ~/.config/labwc/autostart << 'EOF'
# Wallpaper
swaybg -i ~/.config/ocws/wallpaper &

# Terminal
foot &

# Panel
zigshell-cairo-pango &

# Control Center
./scripts/actions/launcher.sh &

# Media management
playerctl --player='spotify' --player='vlc' --player='firefox' &

# Notifications
mako &

# Idle handling
swayidle -w timeout 300 'swaylock -f' &
EOF
```

---

## Keybindings Examples

### Common Bindings
```xml
<!-- Application Launcher -->
<keybind key="Super_L">
  <action name="Execute">
    <command>fuzzel</command>
  </action>
</keybind>

<!-- Terminal -->
<keybind key="Super_Return">
  <action name="Execute">
    <command>foot</command>
  </action>
</keybind>

<!-- Window Management -->
<keybind key="Super_Q">
  <action name="Close"/>
</keybind>

<keybind key="Super_A">
  <action name="ToggleMaximize"/>
</keybind>

<keybind key="Super_D">
  <action name="ToggleShowDesktop"/>
</keybind>
```

### Advanced Keybindings

#### Multi-monitor Setup
```xml
<!-- Monitor-specific keybindings -->
<keyboard>
  <!-- Primary monitor shortcuts -->
  <keybind key="Super_L">
    <action name="Execute">
      <command>fuzzel</command>
    </action>
  </keybind>
  
  <!-- External monitor terminal -->
  <keybind key="Super_Return">
    <action name="Execute">
      <command>foot --position 1920,0</command>
    </action>
  </keybind>
</keyboard>
```

#### Application-Specific Bindings
```xml
<!-- VS Code shortcuts -->
<windowRule identifier="code">
  <keyboard>
    <keybind key="Super_b">
      <action name="Execute">
        <command>code --goto-file "$(fuzzel --dmenu)"</command>
      </action>
    </keybind>
  </keyboard>
</windowRule>

<!-- Discord shortcuts -->
<windowRule identifier="discord">
  <keyboard>
    <keybind key="Super_g">
      <action name="Execute">
        <command>discord --goto-channel "$(fuzzel --dmenu)"</command>
      </action>
    </keybind>
  </keyboard>
</windowRule>
```

## Window Rules

### Common Window Rules
```xml
<windowRules>
  <!-- Keep specific applications on current workspace -->
  <windowRule identifier="chrome">
    <action name="SetWorkspace">
      <workspace>0</workspace>
    </action>
  </windowRule>
  
  <windowRule identifier="discord">
    <action name="SetWorkspace">
      <workspace>1</workspace>
    </action>
  </windowRule>
  
  <!-- Auto-fullscreen large windows -->
  <windowRule identifier="void" matchOnce="true">
    <action name="ToggleMaximize"/>
  </windowRule>
  
  <!-- Apply special decorations to dialogs -->
  <windowRule identifier="dialog" matchClass="true">
    <action name="ToggleDecorations"/>
  </windowRule>
</windowRules>
```

### Complex Window Management
```xml
<!-- Resource-heavy applications on dedicated workspace -->
<windowRule identifier="vim">
  <action name="SetWorkspace">
    <workspace>2</workspace>
  </action>
</windowRule>

<!-- Gaming window management -->
<windowRule identifier="gamescope" matchOnce="true">
  <action name="Move">
    <workspace>9</workspace>
  </action>
</windowRule>

<!-- Multi-monitor setup -->
<windowRule identifier="*" matchOnce="true" allowQuit="false">
  <action name="ManageMultiMonitor">
    <behavior>center</behavior>
  </action>
</windowRule>
```

---

## Integration with OCWS

### OCWS Components
| OCWS File | labwc Role |
|-----------|-----------|
| `dotfiles/labwc/rc.xml` | Keybindings, window rules, theme selection |
| `dotfiles/labwc/autostart` | Boots zigshell-cairo-pango, ocws-daemon, swaybg, mako |
| `dotfiles/labwc/environment` | Sets `WAYLAND_DISPLAY`, `XDG_CURRENT_DESKTOP`, etc. |
| `dotfiles/labwc/themerc-override` | Applies OCWS glassmorphic window border colors |
| `dotfiles/labwc/menu.xml` | Right-click desktop menu with OCWS actions |

### Advanced Integration

#### Keybinding Integration
```xml
<!-- OCWS Launcher -->
<keybind key="Super_L">
  <action name="Execute">
    <command>fuzzel</command>
  </action>
</keybind>

<!-- OCWS Control Center -->
<keybind key="Super_c">
  <action name="Execute">
    <command>./scripts/actions/launcher.sh control-center</command>
  </action>
</keybind>

<!-- OCWS System Actions -->
<keybind key="Super_x">
  <action name="Execute">
    <command>./scripts/actions/power-menu.sh</command>
  </action>
</keybind>

<!-- OCWS Theme Switching -->
<keybind key="Super_t">
  <action name="Execute">
    <command>./scripts/theme-engine.sh list</command>
  </action>
</keybind>
```

#### Environment Configuration
```xml
<environment>
  export WAYLAND_DISPLAY=wayland
  export XDG_CURRENT_DESKTOP=OCWS
  export OCWS_DAEMON_PATH=~/.config/ocws/ocws-daemon.sh
  export OCWS_WIDGET_DIR=~/.config/ocws
</environment>
```

---

## Troubleshooting

### Common Issues

#### Issue: Keybindings not working
**Symptom:** Keyboard shortcuts not responding
**Solution:**
```bash
# Check labwc is running
pgrep -fl labwc

# Verify rc.xml syntax
labwc --reconfigure

# Check for conflicts with other compositors
pkill -f "sway|hyprland|i3"
```

#### Issue: Windows not showing decorations
**Symptom:** Windows without borders/title bars
**Solution:**
```bash
# Check themerc-override
cat ~/.config/labwc/themerc-override

# Fix broken configuration
# Remove / restore from backup
cp ~/.config/labwc/rc.xml ~/.config/labwc/rc.xml.backup
cp ~/.config/labwc/docs/rc.xml.all ~/.config/labwc/rc.xml
```

#### Issue: Autostart programs not starting
**Symptom:** OCWS components not launching
**Solution:**
```bash
# Check autostart script
chmod +x ~/.config/labwc/autostart

# Manual run for debugging
~/.config/labwc/autostart

# Check if dependencies are installed
command -v zigshell-cairo-pango || echo "zigshell-cairo-pango not found"
command -v swaybg || echo "swaybg not found"
```

#### Issue: Theme not applying
**Symptom:** Glassmorphic effects not visible
**Solution:**
```bash
# Verify theme configuration
ls -la ~/.config/labwc/themerc-override

# Apply theme with theme-engine
./scripts/theme-engine.sh apply ./themes/catppuccin-mocha.ini

# Check GTK theme
gettings get org.gnome.desktop.interface gtk-theme
```

### Debug Commands

```bash
# Check labwc configuration
labwc --status

# Verify Wayland setup
env | grep WAYLAND

# Check for rendering issues
journalctl -u labwc -f

# Test window manager
wmctrl -d  # List desktops
wmctrl -k on  # Disable keyboard shortcuts
wmctrl -r :ACTIVE_WINDOW: -b toggle,maximized
```

---

## Performance Optimization

### Basic Optimization
```bash
# Disable unused features
meson setup -Dxwayland=disabled build/

# Optimize for power usage
xset s off
xset s 600

# Reduce visual effects
# In rc.xml: increase gap, remove blur effects
```

### Advanced Configuration
```bash
# Custom theme for performance
cat > ~/.config/labwc/themerc-override << 'EOF'
# Performance optimized theme
window.active.title.bg.color: #1a1a2e
window.active.title.fg.color: #cdd6f4
window.active.border.color: #45475a
window.active.decoration.shadow: rgba(0, 0, 0, 0.1)
window.inactive.title.bg.color: #181825
window.inactive.title.fg.color: #a6adc8
window.inactive.border.color: #313244
window.inactive.decoration.shadow: rgba(0, 0, 0, 0.1)

background: rgba(15, 15, 25, 0.5)
EOF
```

### Monitoring
```bash
# Monitor system resources
sudo apt install htop glances
htop

# Check Wayland processes
ps aux | grep wayland

# Monitor GPU usage
nvidia-smi  # if using NVIDIA
```

---

## Integration Examples

### OCWS Setup Script
```bash
#!/bin/bash
# setup-ocws.sh - Complete OCWS environment setup

set -euo pipefail

# Install dependencies
if command -v pacman >/dev/null; then
    sudo pacman -S labwc zigshell-cairo-pango fuzzel gtk-layer-shell \
                pipewire wireplumber libpulse brightnessctl \
                swaybg wl-clipboard cliphist mako
elif command -v apt-get >/dev/null; then
    sudo apt-get update
    sudo apt-get install labwc zigshell-cairo-pango fuzzel libgtk-3-0 \
                        libgtk-layer-shell libjson-c3 \
                        pipewire wireplumber swaybg grim slurp
fi

# Clone OCWS repository
git clone --depth=1 https://github.com/yourusername/OCWS.git
cd OCWS

# Initialize configuration
mkdir -p ~/.config/ocws
scripts/theme-engine.sh apply ./themes/catppuccin-mocha.ini

# Start labwc
env WAYLAND_DISPLAY=wayland labwc
```

### Development Setup
```bash
#!/bin/bash
# dev-setup.sh - Development environment for OCWS

set -euo pipefail

# Install build tools
if command -v pacman >/dev/null; then
    sudo pacman -S meson ninja git gcc cmake
elif command -v apt-get >/dev/null; then
    sudo apt-get update
    sudo apt-get install meson ninja-build git build-essential cmake
fi

# Clone all sources
cd ~/projects

# LabWC
git clone --depth=1 https://github.com/labwc/labwc.git
sources/labwc

# ZIGSHELL-CAIRO-PANGO
git clone --depth=1 https://github.com/LBCrion/zigshell-cairo-pango.git
sources/zigshell-cairo-pango

# Fuzzel
git clone --depth=1 https://codeberg.org/dnkl/fuzzel.git
sources/fuzzel

# OCWS (this repo)
git clone --depth=1 https://github.com/yourusername/OCWS.git
```

---

## Development Resources

### Official Documentation
- [labwc Documentation](https://labwc.github.io/)
- [labwc GitHub Repository](https://github.com/labwc/labwc)
- [labwc Scope](https://github.com/labwc/labwc-scope)

### Community Resources
- [OCWS Discord](https://discord.gg/ocws)
- [OCWS GitHub](https://github.com/yourusername/OCWS)
- [Wayland Protocol Documentation](https://wayland.freedesktop.org/docs/)
- [wlroots Documentation](https://gitlab.freedesktop.org/wlroots/wlroots/-/wikis/home)

### Learning Materials
- [Openbox Theme Specification](https://openbox.org/wiki/Documentation) (for compatibility)
- [GTK3 Documentation](https://developer.gnome.org/gtk3/stable/)
- [Wayland Protocol](https://wayland.freedesktop.org/docs/)

### Development Tools
- [Meson Build System](https://mesonbuild.com/) (build system)
- [Ninja](https://ninja-build.org/) (build tool)
- [GTK Inspector](https://wiki.gnome.org/Projects/GTK/inspector) (debugging)
- [Wayland Scanner](https://wayland.freedesktop.org/protobuf/) (protocol definitions)

---

## Quick Usage Guide

### First Time Setup
```bash
# Start OCWS
env WAYLAND_DISPLAY=wayland labwc

# Apply default theme
./scripts/theme-engine.sh apply ./themes/catppuccin-mocha.ini

# Initialize OCWS configuration
./scripts/actions/ocws-configure.sh init

# Get help
./scripts/actions/ocws-configure.sh --help
```

### Advanced Usage
```bash
# Work with custom themes
./scripts/theme-engine.sh list
./scripts/theme-engine.sh preview ./themes/your-theme.ini
./scripts/theme-engine.sh apply ./themes/your-theme.ini

# Manage configuration
./scripts/actions/ocws-configure.sh --incremental
./scripts/backup.sh --incremental

# Debug and troubleshoot
./scripts/actions/debug-labwc.sh
journalctl -u labwc
```

### Community Support
```bash
# Report issues
https://github.com/yourusername/OCWS/issues

# Get help
https://discord.gg/ocws

# Contribute
https://github.com/yourusername/OCWS/pulls
```

---

## Acknowledgments

This documentation is inspired by:
- [labwc documentation](https://labwc.github.io/)
- [Openbox theme specification](https://openbox.org/wiki/Documentation)
- [Wayland and wlroots documentation](https://wayland.freedesktop.org/docs/)
- [GTK3 and GTK4 documentation](https://developer.gnome.org/gtk3/stable/)
- [ZIGSHELL-CAIRO-PANGO documentation](https://github.com/LBCrion/zigshell-cairo-pango)
- [Fuzzel documentation](https://codeberg.org/dnkl/fuzzel)

OCWS contributors and the broader Wayland community for their amazing work!

---

*Last updated: $(date +%Y-%m-%d)*