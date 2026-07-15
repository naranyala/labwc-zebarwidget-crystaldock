# Lesson: Division By Zero In Source Scanners

## The Problem

Scanner source files compute percentages without guarding against zero denominators:

```ini
# memory.source:17
Set XMemPct = (XMemTotal-XMemFree-XMemCache-XMemBuff)/XMemTotal

# cpu.source:17-19
Set XCpuTotDiff = XCpuUser+XCpuNice+XCpuSystem+XCpuIntr+XCpuIdle
                 - XCpuUser.pval-XCpuNice.pval-XCpuSystem.pval
                 - XCpuIntr.pval-XCpuIdle.pval

# battery.source:63-64
Set Level = XBatteryLeft/XBatteryTotal*100
```

On the **first scanner tick**, all values are still 0 (initial state or no data yet). The division yields `0/0` which produces either `NaN`, a crash, or an undefined value in zigshell-cairo-pango. The widget then displays `NaN%`, `---`, or blanks until the next tick.

## Root Cause

zigshell-cairo-pango initializes all scanner variables to 0. The expressions are evaluated immediately on the first scanner iteration. The division by zero happens before any real data arrives from `/proc/stat`, `/proc/meminfo`, or the battery sysfs interface.

In `cpu.source`, all `.pval` fields are 0 at first, and the current values are also 0 before `/proc/stat` populates them, so the denominator is `0 - 0 = 0`.

In `battery.source`, `XBatteryInit()` (which discovers the battery) is never called (see separate lesson), so `XBatteryTotal` stays 0.

## The Fix

Add a guard for zero denominators:

```ini
# memory.source
Set XMemPct = If(XMemTotal > 0,
  (XMemTotal-XMemFree-XMemCache-XMemBuff)/XMemTotal,
  0)

# battery.source
Set Level = If(XBatteryTotal > 0,
  XBatteryLeft/XBatteryTotal*100,
  0)
```

For `cpu.source`, the `.pval` fields need a similar guard:

```ini
# cpu.source
Set XCpuTotDiff = If(XCpuUser.pval > 0,
  XCpuUser+XCpuNice+XCpuSystem+XCpuIntr+XCpuIdle
    - XCpuUser.pval-XCpuNice.pval-XCpuSystem.pval
    - XCpuIntr.pval-XCpuIdle.pval,
  0)
```

## Verification

```bash
# Find all divisions in source files
grep -rn '/' dotfiles/ocws/*.source | grep -v '//' | grep -v 'If.*> 0'
```

## Where This Applies

| File | Line | Expression |
|------|------|------------|
| `memory.source` | 17 | `(XMemTotal-...)/XMemTotal` |
| `cpu.source` | 17-19 | Difference of .pval fields (all 0 on first tick) |
| `battery.source` | 63-64 | `XBatteryLeft/XBatteryTotal*100` |

## Pattern To Remember

Every division in a scanner expression needs a guard: `If(denominator != 0, numerator/denominator, fallback)`. Variables start at 0, and the first tick runs before any real data arrives.
