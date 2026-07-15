# ocws-emit — Event Bus Learning Material

> Script: `scripts/ocws-emit.sh`

---

## What is ocws-emit?

`ocws-emit.sh` is the OCWS event bus — a thin wrapper around zigshell-cairo-pango's IPC mechanism that
pushes state changes to the UI instantly, without waiting for polling intervals.

Instead of zigshell-cairo-pango polling `cat /sys/class/power_supply/BAT0/capacity` every 5 seconds,
background daemons call `ocws-emit System.Battery 85` and zigshell-cairo-pango updates immediately.

---

## How It Works

```
System Event → Daemon Script → ocws-emit → zigshell-cairo-pango IPC → Widget Update
```

1. A system event occurs (volume key pressed, battery level changed, etc.)
2. A daemon script detects the change and calls `ocws-emit`
3. `ocws-emit` maps the OCWS namespace to an zigshell-cairo-pango variable name
4. `ocws-emit` sends `SetVal VariableName = value` to zigshell-cairo-pango via `-R` flag
5. Any widget reading that variable updates instantly

---

## Usage

```bash
# Push volume level to UI
ocws-emit System.Volume 75

# Push battery status
ocws-emit System.Battery 85
ocws-emit System.BatteryState "Charging"

# Push media player info
ocws-emit Media.Title "Song Name"
ocws-emit Media.Artist "Artist Name"
ocws-emit Media.Status "Playing"

# Push network state
ocws-emit Network.WiFi "connected"

# Push brightness
ocws-emit System.Brightness 60

# Raw passthrough (custom variables)
ocws-emit MyCustomVar "any value"
```

---

## Namespace Mapping

| OCWS Namespace | zigshell-cairo-pango Variable | Description |
|----------------|-----------------|-------------|
| `System.Volume` | `XVolLevel` | Volume percentage (0-100) |
| `System.VolumeMuted` | `XVolMuted` | Mute state (true/false) |
| `System.Brightness` | `XBrightness` | Brightness percentage |
| `System.Battery` | `XBatLvl` | Battery percentage |
| `System.BatteryState` | `XBatStat` | Charging/Discharging/Full |
| `System.Cpu` | `XCpuLoad` | CPU usage percentage |
| `System.Memory` | `XMemPct` | Memory usage percentage |
| `System.Disk` | `XDiskPct` | Disk usage percentage |
| `System.DND` | `XDndState` | Do Not Disturb (true/false) |
| `Network.WiFi` | `XNetState` | WiFi connected/disconnected |
| `Network.Bluetooth` | `XBtState` | Bluetooth on/off |
| `Media.Title` | `XMediaTitle` | Current track title |
| `Media.Artist` | `XMediaArtist` | Current track artist |
| `Media.Status` | `XMediaStatus` | Playing/Paused/Stopped |

---

## How zigshell-cairo-pango Receives IPC

zigshell-cairo-pango listens on a UNIX socket. When it receives `SetVal VarName = value`, it updates
the named variable and any widget reading that variable re-renders.

The `-R` flag sends a one-shot IPC command:
```bash
zigshell-cairo-pango -R "SetVal XVolLevel = 75"
```

For string values, quotes are required:
```bash
zigshell-cairo-pango -R "SetVal XMediaStatus = \"Playing\""
```

`ocws-emit.sh` handles the quoting automatically based on whether the value is numeric.

---

## Integration with OCWS

| Component | Role |
|-----------|------|
| `scripts/ocws-emit.sh` | The broadcaster (this script) |
| `scripts/ocws-daemon.sh` | Background daemon that detects events and calls ocws-emit |
| `dotfiles/ocws/ocws-sysmon.source` | Polls `ocws-sysmon` binary, parses into zigshell-cairo-pango variables |
| `dotfiles/ocws/*.widget` | Widgets that read the emitted variables |

---

## Relationship to Scanner Sources

ocws-emit and scanner sources serve different purposes:

- **Scanner sources** (`.source` files) are for data that MUST be polled — CPU usage, memory,
  network traffic. zigshell-cairo-pango's built-in scanner runs `ocws-sysmon` every N milliseconds.

- **ocws-emit** is for EVENT-DRIVEN updates — volume key pressed, battery changed, media
  track changed. The daemon detects the change and pushes it instantly.

The ideal OCWS setup uses BOTH: scanners for continuous metrics, and ocws-emit for
discrete state changes.
