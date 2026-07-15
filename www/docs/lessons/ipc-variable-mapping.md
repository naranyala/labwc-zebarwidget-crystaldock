# Lesson: IPC Variable Names Must Match Widget Variables

## The Problem

The `ocws-emit.sh` script sends IPC commands to zigshell-cairo-pango using `SetVal VarName = value`. The variable name in the IPC command **must exactly match** what the widget reads. If they don't match, the IPC update silently does nothing.

## Architecture

```
ocws-daemon.sh → ocws-emit.sh → zigshell-cairo-pango IPC → widget variable → widget display
```

The daemon detects system changes (volume, battery, etc.) and pushes them via `ocws-emit`. The emit script translates high-level names to zigshell-cairo-pango variable names.

## Mapping Table

| OCWS API Name | Emit Variable | Widget Reads | Status |
|---|---|---|---|
| `System.Volume` | `XVolLevel` | `XVolLevel` | OK |
| `System.VolumeMuted` | `XVolMuted` | `XVolMuted` | OK |
| `System.Brightness` | `XBrightness` | `XBrightness` | OK |
| `System.Battery` | `XBatLvl` | `XBatLvl` | Was `XBatteryLevel` |
| `System.BatteryState` | `XBatStat` | `XBatStat` | Was `XBatteryStatus` |
| `System.Cpu` | `XCpuLoad` | `XCpuLoad` | OK |
| `System.Memory` | `XMemPct` | `XMemPct` | Was `XMemUsage` |
| `System.Disk` | `XDiskPct` | `XDiskPct` | Was `XDiskUsage` |
| `Network.WiFi` | `XNetState` | `XNetState` | OK |
| `Network.Bluetooth` | `XBtState` | `XBtState` | OK |
| `Media.Title` | `XMediaTitle` | `XMediaTitle` | OK |
| `Media.Artist` | `XMediaArtist` | `XMediaArtist` | OK |
| `Media.Status` | `XMediaStatus` | `XMediaStatus` | OK |

## How to Debug

### 1. Check what the widget reads

```bash
grep -n "XBatLvl\|XBatStat\|XMemPct\|XDiskPct" dotfiles/ocws/*.widget
```

### 2. Check what the emit script sends

```bash
grep "ENGINE_VAR" scripts/ocws-emit.sh
```

### 3. Check what the scanner defines

```bash
grep -n "XBatLvl\|XMemPct" dotfiles/ocws/*.source
```

### 4. Test IPC directly

```bash
zigshell-cairo-pango -R "SetVal XBatLvl = 50"
```

If the widget updates, the variable name is correct. If nothing happens, the name is wrong.

## Rule

When adding a new widget or IPC endpoint:

1. Define the variable in the scanner/source with a clear name
2. Use the **same name** in the widget's display expressions
3. Use the **same name** in `ocws-emit.sh`'s `ENGINE_VAR` mapping
4. Document the mapping in `sources-learn/ocws-emit.md`
