# Getting Started

Setup guide for labwc + sfwbar + fuzzel Wayland desktop.

---

## Prerequisites

### Required

| Package | Purpose |
|---------|---------|
| labwc | Wayland compositor |
| sfwbar | Statusbar/taskbar/panel |
| foot | Wayland terminal |
| fuzzel | Application launcher |
| swaybg | Wallpaper setter |

### Recommended

| Package | Purpose |
|---------|---------|
| crystal-dock | Wayland dock |
| grim | Screenshot tool |
| slurp | Region selector |
| wl-clipboard | Clipboard utilities (wl-copy, wl-paste) |
| cliphist | Clipboard history |
| playerctl | MPRIS media controls |
| wpctl | PipeWire volume control |
| brightnessctl | Backlight control |
| gammastep | Screen color temperature |
| mako or dunst | Notification daemon |
| libinput | Input device management |
| gsettings | Desktop settings |

### Build Dependencies

| Package | Purpose |
|---------|---------|
| meson | Build system |
| ninja | Build executor |
| wayland-protocols | Wayland protocol definitions |
| libwlroots-dev | wlroots development headers |
| libxml-2.0-dev | XML parsing (labwc) |
| libcairo2-dev | Cairo rendering (C widgets) |
| libpango1.0-dev | Text layout (C widgets) |
| libglib2.0-dev | GLib utilities |
| libxkbcommon-dev | Keyboard handling |

---

## Installation

### Step 1: Build labwc

From source:
```bash
./download-labwc.sh --install
```

Or via package manager:
```bash
# Debian/Ubuntu
sudo apt install labwc

# Arch
sudo pacman -S labwc

# Fedora
sudo dnf install labwc
```

### Step 2: Install Dependencies

```bash
./scripts/install-deps.sh
```

Or manually:
```bash
sudo apt install foot fuzzel swaybg grim slurp wl-clipboard
```

### Step 3: Install Dotfiles

```bash
./dotfiles/install.sh
```

This runs 15 sections:
1. Pre-flight checks (binaries, bash version)
2. Backup existing configs to ~/.config/labwc-backups/
3. Create directories
4. Install labwc config (rc.xml, autostart, environment, menu.xml, themerc-override)
5. Install sfwbar config (sfwbar.config, CSS, 40 widget files)
6. Install noctalia config
7. Install crystal-dock config
8. Install GTK3/GTK4 theme
9. Install fuzzel launcher config
10. Install fontconfig and fonts
11. Install 50+ scripts to ~/.local/bin/
12. Update PATH in shell profile
13. Create labwc.desktop session file
14. Apply default theme (catppuccin-mocha)
15. Validation

Options:
```bash
./dotfiles/install.sh --force       # Overwrite without prompts
./dotfiles/install.sh --no-backup   # Skip backup
./dotfiles/install.sh --check       # Validate only
```

### Step 4: Launch

From TTY:
```bash
# Switch to TTY: Ctrl+Alt+F2
# Login and run:
./scripts/start-labwc.sh
```

From display manager:
Log out and select "labwc" from your login screen.

---

## What Gets Installed

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

---

## Verifying Installation

```bash
# Check labwc is installed
labwc --version

# Check sfwbar is installed
sfwbar --version

# Check config files exist
ls ~/.config/labwc/
ls ~/.config/sfwbar/

# Run validation
./scripts/validate.sh

# Quick health check
./scripts/health-check.sh
```

---

## Customization

### Change Theme

```bash
theme catppuccin-mocha     # Apply theme
theme list                 # List available themes
theme next                 # Cycle to next theme
```

### Change Keybindings

Edit ~/.config/labwc/rc.xml. See docs/configuration.md for full reference.

### Change Statusbar

Edit ~/.config/sfwbar/sfwbar.config. Available configs:
- sfwbar.config (dual-bar: top + bottom)
- sfwbar-noctalia.config (single top bar)
- sfwbar-compact.config (minimal single bar)
- sfwbar-full.config (full-featured single bar)

### Change Wallpaper

```bash
wallpaper random           # Set random wallpaper
wallpaper sync             # Download wallpapers from sources
wallpaper set PATH         # Set specific wallpaper
wallpaper daemon           # Auto-rotate wallpapers
```

### Font Scaling

```bash
font-scale up              # Increase font size
font-scale down            # Decrease font size
font-scale set 12          # Set specific size
font-scale status          # Show current size
```

---

## Troubleshooting

### labwc will not start

- Make sure you are on a TTY, not inside another Wayland session
- Check dependencies: labwc --version
- Check config syntax: xmllint --noout ~/.config/labwc/rc.xml
- Check autostart is executable: ls -la ~/.config/labwc/autostart

### sfwbar not appearing

- Check sfwbar is installed: sfwbar --version
- Check config exists: ls ~/.config/sfwbar/
- Start manually: sfwbar -f ~/.config/sfwbar/sfwbar.config -c ~/.config/sfwbar/catppuccin-mocha.css
- Debug: ./scripts/debug-sfwbar.sh

### crystal-dock not appearing

- Check it is in autostart: grep crystal-dock ~/.config/labwc/autostart
- Launch manually: crystal-dock --start --overlay
- Clean stale locks: rm -f /tmp/qipc_sharedmemory_crystaldock*

### fuzzel not appearing

- Check config: ls ~/.config/fuzzel/fuzzel.ini
- Launch manually: fuzzel
- Check keybinding: grep 'A-a' ~/.config/labwc/rc.xml

### GTK apps show empty text

- Fix fonts: ./scripts/fix-gtk-fonts.sh
- Check fontconfig: ls ~/.config/fontconfig/fonts.conf
- Check settings: grep gtk-font-name ~/.config/gtk-3.0/settings.ini

### Click forwarding broken

- Check for Left Press bug: grep -A5 'context name="Client"' ~/.config/labwc/rc.xml
- Should only have A-Left Drag (Move) and A-Right Drag (Resize)
- Fix: ./scripts/fix.sh

### Theme not applying

- Check theme engine: ./scripts/theme-engine.sh list
- Apply manually: ./scripts/theme-engine.sh apply themes/catppuccin-mocha.ini
- Restart sfwbar: relaunch-status-bars.sh sfwbar

### Workspace switching not working

- sfwbar uses built-in pager with WorkspaceActivate() action
- Do not use labwc -e -- labwc has no CLI IPC flag
- Check desktop count matches: validate.sh checks this

---

## Running Validation

```bash
# Full validation (25+ checks)
./scripts/validate.sh

# Auto-fix issues
./scripts/fix.sh

# Dry-run fix (see what would be changed)
./scripts/fix.sh --dry-run

# Quick health check
./scripts/health-check.sh

# Debug sfwbar
./scripts/debug-sfwbar.sh

# Deep diagnostics
./scripts/diagnostics.sh --output ~/labwc-diagnostics.txt
```

---

## References

- labwc: https://labwc.github.io/
- labwc wiki: https://github.com/labwc/labwc/wiki
- sfwbar: https://github.com/LBCrion/sfwbar
- fuzzel: https://codeberg.org/dnkl/fuzzel
- Openbox theme spec: https://github.com/labwc/labwc-scope
