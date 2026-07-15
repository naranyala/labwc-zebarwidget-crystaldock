# Lesson: zigshell-cairo-pango Variable Naming Conventions

## Two Types of Variables

zigshell-cairo-pango has two distinct variable contexts that are easy to confuse:

### 1. Scanner Output Variables (raw)

Set by `exec()` blocks in scanners. These are the **raw output names** from the scanner.

```ini
scanner {
  exec("ocws-sysmon") {
    If (Match($0, "^BAT_LVL=")) {
      XBatLvl = Val(Extract($0, "BAT_LVL=([0-9]+)"))
    }
  }
}
```

Here `BAT_LVL` is the raw scanner line prefix. The **computed variable** is `XBatLvl`.

### 2. Computed Variables (derived)

Set by `Set` statements or in scanner `exec()` blocks. These are what widgets actually read.

```ini
Set XCpuLoad = If(XCpuTotDiff = 0, 0, 100 * (XCpuTotDiff - XCpuIdlDiff) / XCpuTotDiff)
```

## The Naming Convention

OCWS uses an **`X` prefix** convention for computed variables:

| Scanner Raw Output | Computed Variable | Widget Reads |
|---|---|---|
| `BAT_LVL=82` | `XBatLvl` | `XBatLvl` |
| `BAT_STAT=Discharging` | `XBatStat` | `XBatStat` |
| `CPU_TOT=12345` | `XCpuCurTot` → `XCpuLoad` | `XCpuLoad` |
| `MEM_PCT=45.2` | `XMemPct` | `XMemPct` |
| `NET_RX=999` | `XNetCurRx` → `XNetRateRx` | `XNetRateRx` |

## Common Mistake

Mixing raw scanner output names with computed variable names:

```ini
# WRONG — BAT_LVL is the raw scanner prefix, not the computed variable
tooltip = "Battery: " + Str(BAT_LVL, 0) + "%"

# CORRECT — XBatLvl is the computed variable set in the scanner
tooltip = "Battery: " + Str(XBatLvl, 0) + "%"
```

## IPC Variable Mapping

When using `ocws-emit` to push variables to zigshell-cairo-pango, the IPC variable names must match what widgets read:

```bash
# ocws-emit.sh
"System.Battery") ENGINE_VAR="XBatLvl" ;;   # NOT "BAT_LVL"
"System.Memory")  ENGINE_VAR="XMemPct" ;;   # NOT "XMemUsage"
"System.Disk")    ENGINE_VAR="XDiskPct" ;;  # NOT "XDiskUsage"
```

If the emit script uses the wrong variable name, the IPC update silently does nothing — the widget never sees the new value.

## Verification Checklist

Before shipping a widget or IPC script:

1. Grep for the variable name in the widget file
2. Grep for the same name in the scanner/source file that defines it
3. If using `ocws-emit`, verify the `ENGINE_VAR` matches what the widget reads
4. Test with `zigshell-cairo-pango -R "SetVal VarName = test"` to confirm the variable is reachable
