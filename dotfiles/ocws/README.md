# OCWS Widget Suite

A comprehensive collection of native zigshell-cairo-pango widgets with real system integration. Each widget is a self-contained `.widget` file using zigshell-cairo-pango's `#Api2` syntax.

---

## Quick Start

OCWS uses a modular mode system. Each mode is an entry point in `modes/*.mode` that includes common infrastructure from `ocws.config`.

```bash
# Deploy widgets to ~/.config/ocws/
./install.sh

# Restart the shell (example: dual mode)
pkill zigshell-cairo-pango && zigshell-cairo-pango -f ~/.config/ocws/modes/dual.mode &

# Or use the mode switcher
zigshell-cairo-pango-mode start dual
```

---

## Panel Modes

| Mode | Entry Point | Description |
|------|-------------|-------------|
| `dual` | `modes/dual.mode` | Top statusbar + bottom dock/taskbar + desktop widgets |
| `single` | `modes/single.mode` | Single top statusbar with all widgets |
| `minimal` | `modes/minimal.mode` | Minimal top bar (clock, volume, battery, tray) |
| `compact` | `modes/compact.mode` | Single bar with integrated taskbar + dock icons |
| `island` | `modes/island.mode` | Dynamic island (requires patched zigshell-cairo-pango) |
| `desktop` | `modes/desktop.mode` | Desktop widgets only, no status bars |
| `zigshell-cairo-pango` | `modes/zigshell-cairo-pango.mode` | Single statusbar + external zigshell-cairo-pango (legacy) |

---

## Architecture

```
dotfiles/ocws/
  ocws.config              # Common infrastructure (not an entry point)
  user.config              # User overlay (preserved across updates)
  plugins.config           # Widget includes
  env.config               # Generated env overrides

  modes/                   # Entry points (launch with zigshell-cairo-pango -f)
    dual.mode              # Top + bottom bars + desktop
    single.mode            # Single top bar
    minimal.mode           # Minimal top bar
    compact.mode           # Integrated taskbar + dock
    island.mode            # Dynamic island
    desktop.mode           # Desktop widgets only
    zigshell-cairo-pango.mode       # Statusbar + zigshell-cairo-pango

  bars/                    # Bar definitions
    statusbar.config       # Top statusbar
    dockbar.config         # Bottom dock/taskbar
    desktop.config         # Desktop layer

  css/
    tokens.css             # @define-color tokens (generated)
    ocws.css               # Consolidated glassmorphism theme

  widgets/                 # Widget files
  widget-sets/             # Preset widget collections
  sources/                 # Data providers
```

---

## Widget Categories

### Core UI

| Widget | File | Description | Data Source |
|--------|------|-------------|-------------|
| Launcher | `launcher.widget` | App launcher button | Desktop entries via rofi |
| Workspaces | `workspaces.widget` | Pager-based workspace switcher | Compositor IPC (wlr-workspace) |
| Clock | `clock.widget` | Time display with calendar popup | Built-in `Time()` |
| System Tray | `tray.widget` | Tray icons | StatusNotifierItem |
| Show Desktop | `showdesktop.widget` | Toggle show desktop | zigshell-cairo-pango `ToggleDesktop()` |
| Dock | `dock.widget` | Pinned application dock | Desktop entries |
| Keybinds | `keybinds.widget` | Keyboard shortcut reference | Static |

### System Metrics (text-style)

| Widget | File | Description | Data Source |
|--------|------|-------------|-------------|
| CPU | `cpu-text.widget` | CPU utilization with detail popup | `ocws-sysmon.source` / `cpu.source` |
| Memory | `memory-text.widget` | RAM usage with breakdown popup | `ocws-sysmon.source` / `memory.source` |
| Network | `network-bandwidth.widget` | Network traffic with detail popup | `ocws-sysmon.source` |
| Volume | `volume-text.widget` | Volume level with slider popup | `ocws-sysmon.source` / scanner |
| Brightness | `brightness-text.widget` | Backlight brightness with slider popup | scanner |
| Battery | `battery-text.widget` | Battery level with detail popup | `ocws-sysmon.source` |
| Temperature | `temperature.widget` | CPU thermal reading | `ocws-sysmon.source` |

### Media and Connectivity

| Widget | File | Description | Data Source |
|--------|------|-------------|-------------|
| Media Player | `media-player.widget` | Now-playing display (MPRIS) | `playerctl` |
| Media Controls | `media.widget` | Compact controls (prev/play/next) | `playerctl` |
| Bluetooth | `bluetooth.widget` | Bluetooth device status | `ocws-sysmon.source` |
| WiFi | `wifi.widget` | WiFi connection management | zigshell-cairo-pango network module |
| WiFi Secret | `wifi-secret.widget` | WiFi password entry | zigshell-cairo-pango network module |

### System Control

| Widget | File | Description | Data Source |
|--------|------|-------------|-------------|
| Control Center | `ocws-control-center.widget` | Unified popup (vol, bright, bat, WiFi, BT, media) | Multiple sources |
| Session | `session.widget` | Lock, logout, reboot, shutdown | systemd/loginctl |
| Clipboard | `clipboard.widget` | Clipboard history | `wl-paste` / cliphist |
| Quick Settings | `quick-settings.widget` | One-click toggles | Various |
| Power Profile | `power-profile.widget` | Performance/balanced/saver modes | `powerprofilesctl` |
| Keyboard Layout | `keyboard-layout.widget` | Current layout indicator | zigshell-cairo-pango xkbmap module |
| Night Light | `nightlight.widget` | Blue light filter toggle | `gammastep` |

### System Monitoring

| Widget | File | Description | Data Source |
|--------|------|-------------|-------------|
| System Monitor | `sysmon.widget` | Uptime, load, processes | `/proc/uptime`, `/proc/loadavg` |
| CPU Monitor | `cpu-monitor.widget` | Detailed CPU stats | `/proc/stat` |
| Memory Monitor | `memory-monitor.widget` | Detailed memory breakdown | `/proc/meminfo` |
| Disk | `disk.widget` | Disk usage and I/O | `df`, `/proc/diskstats` |
| Notification Center | `notification-center.widget` | Notification history | zigshell-cairo-pango ncenter module |

### Other

| Widget | File | Description | Data Source |
|--------|------|-------------|-------------|
| Weather | `weather.widget` | Current weather conditions | Open-Meteo API |
| Idle Inhibit | `idle-inhibit.widget` | Prevent screen blank | zigshell-cairo-pango idleinhibit module |
| Privacy | `privacy.widget` | Mic/camera usage indicators | zigshell-cairo-pango pipewire module |
| Custom Script | `custom-script.widget` | Template for custom widgets | User-defined |

---

## Configuration Files

| Config | Description |
|--------|-------------|
| `ocws.config` | Common infrastructure (included by all modes) |
| `user.config` | User overlay (not overwritten by installer) |
| `plugins.config` | Auto-generated widget include list |
| `ocws.css` | Consolidated glassmorphism theme (all styles) |
| `tokens.css` | @define-color token definitions |

---

## Widget-Set Profiles

Widgets are organized into profile sets in `widget-sets/`:

- `full.set` -- Media, clock, control center, tray (default for statusbar)
- `standard.set` -- Clock, volume, brightness, battery, tray, control center
- `status.set` -- Volume, brightness, battery, bluetooth
- `system-metrics.set` -- CPU, memory, temperature, network
- `desktop.set` -- Floating desktop widgets (clock, weather, sysmon)

---

## Data Sources

Scanner blocks in `.source` files provide data to widgets:

| Source File | Variables | Consumers |
|-------------|-----------|-----------|
| `ocws-sysmon.source` | `XBatLvl`, `XBatStat`, `XMemPct`, `XNetState`, `XBtState` | battery, memory, network, bluetooth widgets |
| `cpu.source` | `XCpuLoad`, `XCpuUtilization` | cpu-text, cpu-monitor widgets |
| `memory.source` | `XMemTotal`, `XMemUsed`, `XMemBuffers` | memory-monitor widget |
| `battery.source` | `Level`, `Discharging` | (unused -- ocws-sysmon.source supersedes) |

---

## Widget Features

Each widget follows the OCWS pattern:

- Text-style bar display with Nerd Font icons
- Rich popup panels with detailed information on click
- Interactive controls (scroll to adjust, click for actions)
- Real system data from /proc, /sys, D-Bus modules
- Dynamic styling based on thresholds (color changes for warnings)

---

## CSS Theme

The consolidated `ocws.css` provides a glassmorphism theme with:

- Alpha-transparent panel backgrounds
- Pill-style module buttons with hover effects
- Rounded popup panels with detail grids
- Color-coded status indicators
- Smooth 0.15s ease-out transitions
- Dock magnification on hover

---

## Dependencies

Required for all widgets:

- `zigshell-cairo-pango` (built from source)
- `wayland` compositor with layer-shell support

Optional (for specific widgets):

- `brightnessctl` -- brightness control
- `wpctl` / PipeWire -- volume control
- `playerctl` -- media player control
- `powerprofilesctl` -- power profile switching
- `gammastep` -- night light
- `wl-paste` / `wl-clipboard` -- clipboard
- `curl` -- weather data

---

## Adding Custom Widgets

1. Copy `custom-script.widget` as a template
2. Replace the `Exec()` command with your data source
3. Update the parser (RegEx/Extract) to extract your data
4. Customize the display (icon, label, progress bar)
5. Add a popup panel for detailed view
6. Place in `~/.config/ocws/plugins/` and restart zigshell-cairo-pango

Example:

```ini
#Api2

scanner {
  step = 5000
  exec("/bin/sh -c 'cat /proc/uptime | awk \"{print int(\$1/86400)}\"'") {
    XUptimeDays = Grab(First)
  }
}

export button "uptime-text" {
  style = "text_widget"
  class = "module"
  tooltip = "System uptime"

  label {
    value = "󰔪 " + XUptimeDays + "d"
  }
}
```
