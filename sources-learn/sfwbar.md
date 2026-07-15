# zigshell-cairo-pango — Learning Material

> Source: `./sources/zigshell-cairo-pango` | Upstream: https://github.com/LBCrion/zigshell-cairo-pango

---

## What is zigshell-cairo-pango?

**ZIGSHELL-CAIRO-PANGO** (S\* Floating Window Bar) is a flexible GTK3-based taskbar and status bar for
Wayland compositors. It is designed specifically for **stacking/floating window** workflows
(hence the name), unlike Waybar which is more tiling-oriented.

In OCWS, zigshell-cairo-pango is the **entire shell UI engine** — it renders the panel, all widgets
(clock, volume, battery, workspaces, media player, etc.), popups, and the control center.

---

## Key Concepts

### GTK3 + gtk-layer-shell
zigshell-cairo-pango renders using GTK3 and uses `gtk-layer-shell` to anchor itself to Wayland outputs
using the [wlr-layer-shell-unstable-v1](https://wayland.app/protocols/wlr-layer-shell-unstable-v1)
protocol. This means it can sit at the top/bottom of the screen, always-on-top, without being
managed as a normal window.

### Widget Configuration Language
zigshell-cairo-pango uses its own declarative **configuration language** (not JSON, not TOML). Config files use
a `.config` extension. OCWS's main shell config is `ocws.config`.

### Source Files (`.source`)
A `.source` file defines a **data provider** — it polls a shell command periodically and parses
the output into named variables that widgets can display.

### Widget Files (`.widget`)
A `.widget` file defines a standalone UI component that can be included into the main bar.
OCWS uses this heavily for modularity (each widget like battery, wifi, media is its own `.widget`).

---

## Configuration Structure

### Main Config (`zigshell-cairo-pango.config` / `ocws.config`)

```ini
#Api2

# Include widget files
include("clock.widget")
include("volume-text.widget")

# Define the bar layout
bar "topbar:top" {
  edge = "top"
  layer = "top"

  widget "clock.widget"
  widget "volume-text.widget"
  widget "battery-text.widget"
}
```

### Widget Definition (`.widget` files)

Widgets use `export button "name"` or `export label "name"`:

```ini
#Api2

# clock.widget
Private {
  Var time_format = "%H:%M"

  export button 'clock' {
    style = "module_pill"
    class = "module"
    tooltip = Time(time_format)
    action = PopUp("ClockPopup")

    grid {
      style = "pill_grid"
      image { value = "preferences-system-time-symbolic" }
      label { value = Time(time_format) }
    }
  }
}

PopUp("ClockPopup") {
  style = "detail_popup"
  grid {
    style = "detail_grid"
    label { value = "Clock" ; style = "detail_header" }
    label { value = Time("%A, %B %d") ; style = "detail_value" }
  }
}
```

### Scanner Definition (inline in `.widget` or `.source`)

Scanners poll commands and parse output into variables:

```ini
#Api2

scanner {
  step = 2000
  exec("/bin/sh -c 'wpctl get-volume @DEFAULT_SINK@ 2>/dev/null'") {
    XVolRaw = Grab(First)
    XVolLevel = Val(RegEx("Volume: ([0-9.]+)", XVolRaw)) * 100
    XVolMuted = RegEx("MUTED", XVolRaw)
  }
}
```

### Source Files (`.source`)

Source files are standalone scanner definitions included by the main config:

```ini
#Api2

# ocws-sysmon.source — polls ocws-sysmon binary every 2 seconds
scanner {
  step = 2000
  exec("ocws-sysmon") {
    SysMonLine = $0
    If (Match(SysMonLine, "^CPU_TOT=")) {
      XCpuCurTot = Val(Extract(SysMonLine, "CPU_TOT=([0-9]+)"))
    }
    If (Match(SysMonLine, "^MEM_PCT=")) {
      XMemPct = Val(Extract(SysMonLine, "MEM_PCT=([0-9.]+)"))
    }
  }
}
```

---

## Built-in Value Functions

| Function | Description |
|----------|-------------|
| `Time(fmt)` | Current time formatted with strftime |
| `Val(str)` | Convert string to numeric value |
| `Str(val, decimals)` | Convert number to string |
| `If(cond, true, false)` | Conditional expression |
| `Match(str, pattern)` | Regex match (returns 1/0) |
| `RegEx(pattern, str)` | Extract first regex capture group |
| `Extract(str, pattern)` | Extract regex capture group |
| `Grab(First)` | Get first line of scanner output |
| `Exec(cmd)` | Run shell command and use its stdout |
| `Env(var)` | Read environment variable |
| `Length(str)` | String length |
| `Concat(a, b)` | Concatenate strings |

---

## Widget Types

| Type | Purpose |
|------|---------|
| `button` | Clickable button (exported to bar) |
| `label` | Display text |
| `image` | Display an icon/image |
| `scale` | Progress bar / slider |
| `progressbar` | Horizontal progress indicator |
| `grid` | Layout container |
| `chart` | Time series plot (CPU/mem graphs) |
| `taskbar` | Window taskbar |
| `pager` | Workspace pager |
| `tray` | System tray (SNI) |

---

## Actions and Events

Widgets respond to click events via `action`, `action[middle]`, `action[scroll_up]`, etc:

```ini
export button "volume-text" {
  action = PopUp("VolPopup")
  action[scroll_up] = Exec("wpctl set-volume @DEFAULT_SINK@ 0.05+")
  action[scroll_down] = Exec("wpctl set-volume @DEFAULT_SINK@ 0.05-")
  action[middle] = Exec("wpctl set-mute @DEFAULT_SINK@ toggle")

  grid {
    image { value = "audio-volume-high-symbolic" }
    label { value = Str(XVolLevel, 0) + "%" }
  }
}
```

### Trigger Actions

zigshell-cairo-pango supports event-driven updates via triggers:

```ini
scanner {
  exec("playerctl metadata --follow --format '{{ artist }} - {{ title }}'") {
    XMediaLine = Grab(First)
    EmitTrigger("media-updated")
  }
}

trigger "media-updated" {
  label {
    value = XMediaLine
    trigger = "media-updated"
  }
}
```

---

## IPC / Scanner (OCWS Event Bus)

zigshell-cairo-pango can listen for **external variable updates** via its scanner IPC socket.
OCWS exploits this with `ocws-emit`:

```bash
# ocws-emit sends: VariableName=Value to zigshell-cairo-pango's socket
ocws-emit System.Volume 75
# → zigshell-cairo-pango immediately updates any widget reading System.Volume
```

The `ocws-daemon.sh` listens for system events (ALSA, udev, playerctl) and
feeds them into zigshell-cairo-pango via this mechanism, keeping the UI reactive without polling.

---

## CSS Styling

zigshell-cairo-pango is a GTK3 app — its entire visual appearance is controlled by a **CSS file**.
OCWS provides `ocws.css` and `theme.css` for the glassmorphic look.

Key CSS patterns used:

```css
/* Bar background — glassmorphic */
window {
  background: rgba(15, 15, 25, 0.72);
  border-radius: 0px;
}

/* Widget labels */
.clock-label {
  color: #cdd6f4;
  font-size: 13px;
  padding: 0 10px;
}

/* Hover state on buttons */
.vol-btn:hover {
  background: rgba(122, 162, 247, 0.2);
  border-radius: 6px;
}
```

GTK3 CSS supports: `background`, `color`, `border`, `border-radius`, `padding`,
`margin`, `box-shadow`, `opacity`, pseudo-classes (`:hover`, `:active`, `:checked`).

---

## Source Code Structure

```
sources/zigshell-cairo-pango/
├── src/           # Core C source files
│   ├── zigshell-cairo-pango.c       # Entry point, GTK init
│   ├── bar.c          # Bar/window management
│   ├── widget.c       # Widget base class
│   ├── taskbar.c      # Taskbar implementation
│   ├── pager.c        # Workspace pager
│   ├── scanner.c      # Data source polling engine
│   ├── ipc.c          # IPC socket handler
│   └── wayland.c      # Wayland protocol handlers
├── modules/       # Optional loadable modules (mpd, pulseaudio, etc.)
├── config/        # Example configs (zigshell-cairo-pango.config, t2.config, wbar.config)
├── doc/           # Man page (zigshell-cairo-pango.rst)
├── icons/         # Bundled symbolic icons
└── meson.build    # Build system
```

---

## Build from Source

```bash
cd sources/zigshell-cairo-pango
meson setup build
ninja -C build
sudo ninja -C build install
```

**Dependencies:**
- `gtk3`, `gtk-layer-shell`, `json-c`

**Runtime (for specific widgets):**
- Symbolic icon theme (battery, volume, network icons)
- `playerctl` (media player widget)
- `wpctl` or `pactl` (volume widget)

---

## OCWS Widget Files Reference

| File | Widget |
|------|--------|
| `ocws.config` | Main bar layout, includes all widgets |
| `clock.widget` | Digital clock |
| `volume-text.widget` | Volume level with mute toggle |
| `battery-text.widget` | Battery percentage + status |
| `wifi.widget` | WiFi SSID + signal strength |
| `cpu-monitor.widget` | CPU chart |
| `memory-monitor.widget` | RAM usage chart |
| `media-player.widget` | Now playing (playerctl) |
| `tray.widget` | System tray |
| `workspaces.widget` | Workspace buttons |
| `notification-center.widget` | Notification history popup |
| `ocws-control-center.widget` | Unified settings popup |
| `dock.widget` | Application dock |

---

## Useful References

- Config man page: `man zigshell-cairo-pango` (or `doc/zigshell-cairo-pango.rst` in source)
- Example configs: `sources/zigshell-cairo-pango/config/`
- OCWS main config: `dotfiles/ocws/ocws.config`
- OCWS widget dir: `dotfiles/ocws/*.widget`
