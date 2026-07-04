# SFWBar Widgets — Noctalia-Inspired Widget Suite

A comprehensive collection of native sfwbar widgets with real system integration,
inspired by the Noctalia shell's extensive module system.

## Quick Start

Copy the desired config to `~/.config/sfwbar/sfwbar.config`:

```bash
# Full-featured bar (all widgets)
cp sfwbar-full.config ~/.config/sfwbar/sfwbar.config

# Compact bar (essential widgets only)
cp sfwbar-compact.config ~/.config/sfwbar/sfwbar.config

# Dashboard bar (maximum information)
cp sfwbar-dashboard.config ~/.config/sfwbar/sfwbar.config
```

## Widget Categories

### Core System Monitors

| Widget | File | Description | Data Source |
|--------|------|-------------|-------------|
| CPU Monitor | `cpu-monitor.widget` | Utilization, temperature, load | `/proc/stat`, `/sys/class/thermal` |
| Memory Monitor | `memory-monitor.widget` | RAM, swap, buffers, slab | `/proc/meminfo`, `/proc/swaps` |
| Disk Usage | `disk.widget` | Space usage, read/write I/O | `df`, `/proc/diskstats` |
| Temperature | `temperature.widget` | CPU thermal zones, hwmon | `/sys/class/thermal`, `/sys/class/hwmon` |
| System Monitor | `sysmon.widget` | Uptime, load, processes | `/proc/uptime`, `/proc/loadavg` |

### Network & Connectivity

| Widget | File | Description | Data Source |
|--------|------|-------------|-------------|
| Network Monitor | `network-monitor.widget` | WiFi/Ethernet, signal, traffic | sfwbar network module, `/proc/net/dev` |
| Bluetooth Monitor | `bluetooth-monitor.widget` | Device list, connection status | sfwbar bluez module |
| WiFi | `wifi.widget` | WiFi connection management | sfwbar network module |

### Audio & Media

| Widget | File | Description | Data Source |
|--------|------|-------------|-------------|
| Volume Control | `volume-control.widget` | Volume, mute, sink info, mic | `wpctl` (PipeWire/WirePlumber) |
| Media Player | `media-player.widget` | Artist, title, controls | `playerctl` (MPRIS) |
| Brightness | `brightness.widget` | Display brightness control | `brightnessctl` |

### Power & Battery

| Widget | File | Description | Data Source |
|--------|------|-------------|-------------|
| Battery Monitor | `battery-monitor.widget` | Level, health, cycles, power profile | `/sys/class/power_supply`, `powerprofilesctl` |
| Power Profile | `power-profile.widget` | Performance/balanced/saver modes | `powerprofilesctl` |
| Idle Inhibit | `idle-inhibit.widget` | Prevent screen blank | sfwbar idleinhibit module |

### Productivity

| Widget | File | Description | Data Source |
|--------|------|-------------|-------------|
| Weather | `weather.widget` | Current conditions, icon | Open-Meteo API |
| Clipboard | `clipboard.widget` | Clipboard history | `wl-paste` |
| Keyboard Layout | `keyboard-layout.widget` | Current layout indicator | sfwbar xkbmap module |
| Calendar | `cal.widget` | Monthly calendar popup | Built-in |

### System Control

| Widget | File | Description | Data Source |
|--------|------|-------------|-------------|
| Session | `session.widget` | Lock, logout, reboot, shutdown | systemd/loginctl |
| Quick Settings | `quick-settings.widget` | One-click toggles | Various system commands |
| Night Light | `nightlight.widget` | Blue light filter toggle | `gammastep` |
| Privacy | `privacy.widget` | Mic/camera usage indicators | sfwbar pipewire module |
| Notification Center | `notification-center.widget` | Notification history | sfwbar ncenter module |

### UI Components

| Widget | File | Description | Data Source |
|--------|------|-------------|-------------|
| Launcher | `launcher.widget` | App launcher button | Desktop entries |
| Workspaces | `workspaces.widget` | Workspace switcher | Compositor IPC |
| Taskbar | `taskbar` (built-in) | Window list | wlr-foreign-toplevel |
| System Tray | `tray.widget` | Tray icons | StatusNotifierItem |
| Clock | `clock.widget` | Time + calendar popup | Built-in |

### Customization

| Widget | File | Description | Data Source |
|--------|------|-------------|-------------|
| Custom Script | `custom-script.widget` | Template for custom widgets | User-defined commands |

## Configuration Files

| Config | Description | Widgets Included |
|--------|-------------|------------------|
| `sfwbar.config` | Default (Noctalia-style floating bar) | Launcher, Workspaces, Clock, Media, Network, BT, Volume, Brightness, Battery, Session |
| `sfwbar-full.config` | Full-featured (all modules) | All widgets |
| `sfwbar-compact.config` | Compact (essential only) | Launcher, Clock, Media, Network, Volume, Battery, Session |
| `sfwbar-dashboard.config` | Dashboard (maximum info) | All widgets + Weather, Clipboard, Sysmon, Power Profile, Night Light |
| `bottom.config` | Bottom taskbar | Taskbar only |

## Widget Features

Each widget follows the Noctalia pattern:
- **Pill-style bar display** with icon + value
- **Rich popup panels** with detailed information
- **Interactive controls** (scroll to adjust, click for actions)
- **Real system data** from /proc, /sys, D-Bus modules
- **Dynamic styling** based on thresholds (color changes for warnings)

## CSS Theme

The `noctalia.css` file provides a complete Catppuccin Mocha theme with:
- Floating pill bar with blur effect
- Rounded module buttons
- Detail popup panels
- Color-coded status indicators
- Smooth hover/active transitions

## Dependencies

Required for all widgets:
- `sfwbar` (built from source)
- `wayland` compositor with layer-shell support

Optional (for specific widgets):
- `brightnessctl` — brightness control
- `wpctl` / PipeWire — volume control
- `playerctl` — media player control
- `powerprofilesctl` — power profile switching
- `gammastep` — night light
- `wl-paste` / `wl-clipboard` — clipboard
- `curl` — weather data
- `smartctl` — disk temperature (for custom script example)

## Adding Custom Widgets

1. Copy `custom-script.widget` as a template
2. Replace the `Exec()` command with your data source
3. Update the parser (RegEx/Json) to extract your data
4. Customize the display (icon, label, progress bar)
5. Add a popup panel for detailed view

Example:
```bash
# My custom widget showing system uptime in days
Exec("cat /proc/uptime | awk '{print int($1/86400)}'") {
  XUptimeDays = Grab(First)
}
```

## Noctalia Widget Comparison

Our sfwbar widgets implement features similar to Noctalia's native C++ modules:

| Noctalia Widget | sfwbar Equivalent | Status |
|-----------------|-------------------|--------|
| sysmon_widget | cpu-monitor + memory-monitor + sysmon | Implemented |
| network_widget | network-monitor | Implemented |
| bluetooth_widget | bluetooth-monitor | Implemented |
| volume_widget | volume-control | Implemented |
| media_widget | media-player | Implemented |
| battery_widget | battery-monitor | Implemented |
| brightness_widget | brightness | Implemented |
| weather_widget | weather | Implemented |
| clipboard_widget | clipboard | Implemented |
| privacy_widget | privacy | Implemented |
| nightlight_widget | nightlight | Implemented |
| power_profile_widget | power-profile | Implemented |
| idle_inhibitor_widget | idle-inhibit | Implemented |
| keyboard_layout_widget | keyboard-layout | Implemented |
| notification_widget | notification-center | Implemented |
| session_widget | session | Implemented |
| clock_widget | clock | Implemented |
| workspaces_widget | workspaces | Implemented |
| tray_widget | tray | Implemented |
| launcher_widget | launcher | Implemented |
| taskbar_widget | taskbar (built-in) | Implemented |
| custom_button_widget | quick-settings | Implemented |
| plugin_widget | custom-script | Implemented |
