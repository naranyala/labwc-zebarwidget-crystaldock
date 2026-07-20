# Event Bus Specification

This document details the inter-process communication (IPC) architecture within the Open Compositor Widget Shell (OCWS). Every IPC event transmitted between components adheres to a standardized pipeline: from the background daemon to the `ocws-emit.sh` script, subsequently translating into `zigshell-cairo-pango` variables, and ultimately consumed by the graphical widgets.

## Event Dictionary

| Event Name | Shell Variable | Origin | Consumers | Status |
|------------|----------------|--------|-----------|--------|
| `System.Volume` | `XVolLevel` | ocws-daemon (pactl subscribe) | volume-text, control-center, media-player | Active |
| `System.VolumeMuted` | `XVolMuted` | ocws-daemon (pactl subscribe) | volume-text, control-center | Active |
| `System.Brightness` | `XBrightness` | ocws-daemon (inotifywait) | brightness-text, control-center | Active |
| `System.Battery` | `XBatLvl` | ocws-sysmon.source | battery-text, control-center | Wired |
| `System.BatteryState` | `XBatStat` | ocws-sysmon.source | battery-text | Wired |
| `System.Cpu` | `XCpuLoad` | ocws-sysmon.source | cpu-text | Wired |
| `System.Memory` | `XMemPct` | ocws-sysmon.source | memory-text | Wired |
| `System.Disk` | `XDiskPct` | disk.widget scanner | disk.widget | Wired |
| `System.DND` | `XDndState` | (Pending implementation) | (None) | Defined |
| `Network.WiFi` | `XNetState` | ocws-sysmon.source | control-center, network-bandwidth | Wired |
| `Network.Bluetooth` | `XBtState` | ocws-sysmon.source | bluetooth, control-center | Wired |
| `Media.Title` | `XMediaTitle` | media-player.widget scanner | media-player.widget | Wired |
| `Media.Artist` | `XMediaArtist` | media-player.widget scanner | media-player.widget | Wired |
| `Media.Status` | `XMediaStatus` | media-player.widget scanner | media-player.widget | Wired |

### Status Classification

- **Active**: The daemon continuously broadcasts state changes via an event-driven mechanism.
- **Wired**: Emitter mappings are established and the respective widget reads the variable; however, the daemon does not yet emit data, requiring the widget to rely on a polling fallback.
- **Defined**: Emitter mappings are established, but no widget currently consumes the corresponding variable.

## Data Pipeline Architecture

```text
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
Widget evaluates XVar within its value expression
        |
        v
Label / Image widget renders the updated state
```

## Polling Fallback Mechanisms

Widgets not presently supported by the event daemon utilize independent `scanner {}` blocks for polling operations:

| Widget | Scanner Implementation |
|--------|------------------------|
| brightness-text.widget | Polls `brightnessctl` or `ocws-brightness` |
| volume-text.widget | Polls `wpctl get-volume` |
| media-player.widget | Polls `playerctl metadata` |
| clipboard.widget | Polls `cliphist` |
| disk.widget | Polls `/proc/diskstats` utilizing `iostat` |
| nightlight.widget | Polls the `gammastep` process state |
| power-profile.widget | Polls `powerprofilesctl` |
| control-center.widget | Polls volume and brightness directly |

Upon the daemon initiating event emissions for a specified metric, the corresponding widget's scanner may be deprecated and replaced by the daemon-managed variable.

## Integrating a New Event

1. Append the namespace-to-variable mapping within `scripts/ocws-emit.sh`.
2. Incorporate the `ocws-emit.sh` execution within `dotfiles/ocws/ocws-daemon.sh` (for event-driven architecture) or a corresponding `.source` file (for polling).
3. Revise this documentation to reflect the new event.
4. Integrate the variable into the target widget's `value` expression.
5. Register the variable within `contracts/variables.ini`.

## Developing a New Widget

1. Verify whether the requisite data is currently available (search for the corresponding variable in existing `.source` files).
2. If unavailable, implement a scanner within the widget or provision a new `.source` file.
3. If the daemon is intended to manage the data stream, configure a new event and emitter mapping.
4. Validate that the variable nomenclature corresponds exactly with the output from `ocws-emit.sh` (refer to `contracts/variables.ini`).

## Direct System Monitors (Non-IPC)

The following variables are derived directly via `ocws-sysmon` or dedicated `.source` files, bypassing the IPC mechanism:

| Variable Prefix | Source | Description |
|-----------------|--------|-------------|
| `XBat*` | ocws-sysmon.source / battery.source | Battery capacity, operational state, and discharge rate. |
| `XCpu*` | ocws-sysmon.source / cpu.source | CPU load average and core utilization. |
| `XMem*` | ocws-sysmon.source / memory.source | Memory allocation and utilization statistics. |
| `XNet*` | ocws-sysmon.source | Network interface bandwidth metrics. |
| `XTemp*` | ocws-sysmon.source | Hardware thermal sensor data. |

## IPC Troubleshooting and Diagnostics

```bash
# Explicitly assign a value to a variable for testing purposes
zigshell-cairo-pango -R "SetVal XBatLvl = 50"

# Inspect the variables currently monitored by widgets
grep -n "XBatLvl\|XBatStat\|XMemPct\|XDiskPct" dotfiles/ocws/*.widget

# Review the data transmission operations within the emit script
grep "ENGINE_VAR" scripts/ocws-emit.sh

# Analyze the scanner definitions
grep -n "XBatLvl\|XMemPct" dotfiles/ocws/*.source

# Execute contract validation procedures
scripts/validate-contract.sh
```
