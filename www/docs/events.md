# OCWS Event Bus Contract

Every IPC event that flows between components: daemon -> `ocws-emit.sh` -> zigshell-cairo-pango variables -> widgets.

---

## Event Map

| Event Name | zigshell-cairo-pango Variable | Source | Consumers | Status |
|------------|-----------------|--------|-----------|--------|
| `System.Volume` | `XVolLevel` | `ocws-daemon` (pactl subscribe) | `volume-text.widget`, `ocws-control-center.widget`, `media-player.widget` | Active |
| `System.VolumeMuted` | `XVolMuted` | `ocws-daemon` (pactl subscribe) | `volume-text.widget`, `ocws-control-center.widget` | Active |
| `System.Brightness` | `XBrightness` | `ocws-daemon` (inotifywait) | `brightness-text.widget`, `ocws-control-center.widget` | Active |
| `System.Battery` | `XBatLvl` | `ocws-sysmon.source` | `battery-text.widget`, `ocws-control-center.widget` | Wired |
| `System.BatteryState` | `XBatStat` | `ocws-sysmon.source` | `battery-text.widget` | Wired |
| `System.Cpu` | `XCpuLoad` | `ocws-sysmon.source` | `cpu-text.widget` | Wired |
| `System.Memory` | `XMemPct` | `ocws-sysmon.source` | `memory-text.widget` | Wired |
| `System.Disk` | `XDiskPct` | `disk.widget` scanner | `disk.widget` | Wired |
| `System.DND` | `XDndState` | (not yet implemented) | (none) | Defined |
| `Network.WiFi` | `XNetState` | `ocws-sysmon.source` | `ocws-control-center.widget`, `network-bandwidth.widget` | Wired |
| `Network.Bluetooth` | `XBtState` | `ocws-sysmon.source` | `bluetooth.widget`, `ocws-control-center.widget` | Wired |
| `Media.Title` | `XMediaTitle` | `media-player.widget` scanner | `media-player.widget` | Wired |
| `Media.Artist` | `XMediaArtist` | `media-player.widget` scanner | `media-player.widget` | Wired |
| `Media.Status` | `XMediaStatus` | `media-player.widget` scanner | `media-player.widget` | Wired |

### Status Meanings

- **Active** — daemon actively emits this event on state changes (event-driven)
- **Wired** — emitter mapping exists and widget reads the variable, but daemon does not emit yet (widget falls back to its own scanner or polling)
- **Defined** — emitter mapping exists but no widget consumes it yet

---

## Data Flow

```
                    ocws-daemon.sh
                    (inotifywait / pactl subscribe / playerctl -F)
                          |
                          v
                    ocws-emit.sh
                    (namespace -> zigshell-cairo-pango variable mapping)
                          |
                          v
                    zigshell-cairo-pango -R "SetVal XVar = value"
                          |
                          v
                    Widget reads XVar in value expression
                          |
                          v
                    Label / Image widget renders output
```

### Polling Fallback

Widgets that are not fed by the daemon use their own `scanner {}` blocks:

| Widget | Scanner |
|--------|---------|
| `brightness-text.widget` | Polls `brightnessctl` or `ocws-brightness` |
| `volume-text.widget` | Polls `wpctl get-volume` |
| `media.widget` | Polls `playerctl metadata` |
| `media-player.widget` | Polls `playerctl metadata` |
| `clipboard.widget` | Polls `cliphist` |
| `disk.widget` | Polls `/proc/diskstats` via `iostat` |
| `nightlight.widget` | Polls `gammastep` state |
| `power-profile.widget` | Polls `powerprofilesctl` |
| `ocws-control-center.widget` | Polls volume + brightness directly |

When the daemon starts emitting an event, the corresponding widget's scanner can be removed and replaced with the daemon-driven variable.

---

## Adding a New Event

1. Add the namespace -> variable mapping in `scripts/ocws-emit.sh`
2. Add the `ocws-emit.sh` call in `dotfiles/ocws/ocws-daemon.sh` (event-driven) or a `.source` file (polling)
3. Update this file
4. Wire the variable into a widget's `value` expression
5. Add the variable to `contracts/variables.ini`

## Adding a New Widget

1. Check if the data it needs is already available (grep for the variable in existing `.source` files)
2. If not, add a scanner in the widget or create a new `.source` file
3. If the daemon should drive it, add an event + emitter mapping
4. Ensure the variable name matches what `ocws-emit.sh` sends (see `contracts/variables.ini`)

---

## Raw /proc Sources (not IPC)

These variables are set by `ocws-sysmon` or dedicated `.source` files, not via IPC:

| Variable Prefix | Source | Provides |
|-----------------|--------|----------|
| `XBat*` | `ocws-sysmon.source` / `battery.source` | Battery level, state, rate |
| `XCpu*` | `ocws-sysmon.source` / `cpu.source` | CPU load, utilization |
| `XMem*` | `ocws-sysmon.source` / `memory.source` | Memory usage, breakdown |
| `XNet*` | `ocws-sysmon.source` | Network bandwidth |
| `XTemp*` | `ocws-sysmon.source` | Thermal readings |
| `XCpuUt*` | `cpu.source` | Per-CPU utilization delta |

---

## Debugging IPC

### Test a variable directly

```bash
zigshell-cairo-pango -R "SetVal XBatLvl = 50"
```

If the widget updates, the variable name is correct. If nothing happens, the name is wrong.

### Check what the widget reads

```bash
grep -n "XBatLvl\|XBatStat\|XMemPct\|XDiskPct" dotfiles/ocws/*.widget
```

### Check what the emit script sends

```bash
grep "ENGINE_VAR" scripts/ocws-emit.sh
```

### Check what the scanner defines

```bash
grep -n "XBatLvl\|XMemPct" dotfiles/ocws/*.source
```

### Validate the variable contract

```bash
scripts/validate-contract.sh
```
