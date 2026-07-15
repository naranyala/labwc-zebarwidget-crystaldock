# Lesson: sysmon Output Order Determines Variable Derivation

## The Problem

`ocws-sysmon.c` outputs `KEY=VALUE` lines in a fixed order. The zigshell-cairo-pango scanner in `ocws-sysmon.source` parses these lines sequentially, and **derived variables are computed when the last line is seen**. If the output order changes, intermediate values are stale.

## How It Works

### C Binary Output Order (`ocws-sysmon.c`)

```
CPU_IDLE=12345        ← raw counter
CPU_TOT=67890         ← raw counter
MEM_TOT=16384         ← derived
MEM_USED=8192         ← derived
MEM_PCT=50.0          ← derived
NET_RX=999999         ← raw counter
NET_TX=888888         ← raw counter
WIFI_STATE=connected  ← state
BT_STATE=On           ← state
BRIGHTNESS=75         ← derived
BAT_LVL=82            ← derived
BAT_STAT=Discharging  ← state
TEMP=65               ← LAST LINE — triggers rate calculations
```

### Scanner Derivation (`ocws-sysmon.source`)

```ini
# Network rates are calculated when TEMP line is seen
If (Match(SysMonLine, "^TEMP=")) {
  XNetRateRx = If(XNetPrevRx = 0, 0, (XNetCurRx - XNetPrevRx) / 2048)
  XNetRateTx = If(XNetPrevTx = 0, 0, (XNetCurTx - XNetPrevTx) / 2048)
  XNetPrevRx = XNetCurRx
  XNetPrevTx = XNetCurTx
  # ... CPU load derived here too
}
```

## The Rule

When a C binary feeds data to an zigshell-cairo-pango scanner:

1. **Raw values** (counters, state) must come **before** derived values
2. **Derived calculations** that depend on multiple raw values should be triggered by the **last line** of output
3. **Never reorder** output lines without updating the scanner's derivation logic
4. If adding new data, append it **before** the trigger line (TEMP), not after

## Why This Matters

If you add a new `PRINT_FOO=bar` line after `TEMP=65`, the network rate calculations won't see `FOO` — they've already fired. The scanner processes each line independently; there's no "end of batch" signal except the specific line that triggers derivation.
