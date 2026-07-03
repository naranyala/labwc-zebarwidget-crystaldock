# Getting Started with labwc + Zebar + crystal-dock

## Prerequisites

- **labwc** - Lab Wayland Compositor ([build from source](../download-labwc.sh) or install via package manager)
- **sfwbar** - GTK3 Wayland-native statusbar/taskbar panel (primary panel/statusbar)
- **crystal-dock** - Wayland dock
- **foot** - Wayland terminal
- **rofi** - Application launcher
- **swaybg** - Wallpaper setter

## Quick Install

```bash
# 1. Build labwc from source (if not installed)
./download-labwc.sh --install

# 2. Install dotfiles
./dotfiles/install.sh

# 3. Launch from TTY (Ctrl+Alt+F2, then login)
./scripts/start-labwc.sh
```

## Step-by-Step Setup

### 1. Install labwc

**From source:**
```bash
./download-labwc.sh --install
```

**Or via package manager:**
```bash
# Debian/Ubuntu
sudo apt install labwc

# Arch
sudo pacman -S labwc

# Fedora
sudo dnf install labwc
```

### 2. Install Dependencies

```bash
# Required
sudo apt install swaybg foot rofi

# Optional (for full experience)
sudo apt install crystal-dock grim slurp wl-copy playerctl wpctl mako
```

### 3. Install Configuration

```bash
./dotfiles/install.sh
```

This copies:
- `rc.xml` → `~/.config/labwc/rc.xml` (keybindings, window rules)
- `autostart` → `~/.config/labwc/autostart` (startup commands)
- `environment` → `~/.config/labwc/environment` (env vars)
- `menu.xml` → `~/.config/labwc/menu.xml` (desktop menu)
- Zebar widgets → `~/.config/zebar/main/`
- Wallpaper script → `~/.local/bin/wallpaper`

### 4. Launch labwc

**From TTY:**
```bash
# Switch to TTY: Ctrl+Alt+F2
# Login and run:
./scripts/start-labwc.sh
```

**From display manager:**
Log out and select "labwc" from your login screen.

## What Gets Installed

| Component | Config Location | Purpose |
|-----------|----------------|---------|
| labwc | `~/.config/labwc/` | Compositor config |
| crystal-dock | autostart | Primary dock |
| zebar | `~/.config/zebar/` | Widget panels |
| wallpaper | `~/.local/bin/wallpaper` | Wallpaper manager |

## Verifying Installation

```bash
# Check labwc is installed
labwc --version

# Check config exists
ls ~/.config/labwc/

# Check autostart has crystal-dock and zebar
grep -E "crystal-dock|zebar" ~/.config/labwc/autostart
```

## Customizing

### Keybindings
Edit `~/.config/labwc/rc.xml`. See [configuration.md](configuration.md) for keybinding reference.

### Autostart
Edit `~/.config/labwc/autostart` to add/remove startup programs.

### Widgets
Widget themes are in `dotfiles/zebar/widgets/`. Edit or create HTML files there.

### Wallpaper
```bash
wallpaper random    # Set random wallpaper
wallpaper sync      # Download wallpapers from sources
wallpaper set PATH  # Set specific wallpaper
wallpaper daemon    # Auto-rotate wallpapers
```

## Troubleshooting

### labwc won't start
- Make sure you're on a TTY, not inside another Wayland session
- Check dependencies: `labwc --version`
- Check config syntax: validate `rc.xml` with `xmllint --noout ~/.config/labwc/rc.xml`

### crystal-dock not appearing
- Check it's in autostart: `grep crystal-dock ~/.config/labwc/autostart`
- Launch manually: `crystal-dock --start --overlay`

### Zebar widgets not loading
- Check zebar is installed: `zebar --version`
- Check widget dir exists: `ls ~/.config/zebar/main/`

## References

- [labwc documentation](https://labwc.github.io/)
- [labwc getting started](https://labwc.github.io/getting-started.html)
- [configuration guide](configuration.md)
