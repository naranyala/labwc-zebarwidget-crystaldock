# Lesson: C Utilities as zigshell-cairo-pango Data Sources

## The Problem

Shell commands (`wpctl`, `playerctl`, `cat /proc/...`) are slow and produce unstructured output that zigshell-cairo-pango scanners must parse with regex. C utilities can read kernel interfaces directly and output clean `KEY=VALUE` pairs.

## Architecture

```
C Utility (ocws-sysmon) → stdout → zigshell-cairo-pango scanner → widget variables → UI
```

The C binary reads `/proc` and `/sys` directly, computes derived values, and outputs clean `KEY=VALUE` lines that zigshell-cairo-pango's scanner can parse with simple `Match()`/`Extract()` calls.

## Example: `ocws-sysmon.c`

```c
// Reads /proc/stat directly — no fork/exec overhead
void get_cpu(unsigned long long *idle_out, unsigned long long *total_out) {
    FILE *f = fopen("/proc/stat", "r");
    fscanf(f, "cpu %llu %llu %llu %llu ...", &user, &nice, &system, &idle, ...);
    *idle_out = idle + iowait;
    *total_out = user + nice + system + idle + iowait + irq + softirq + steal;
    fclose(f);
}

int main() {
    printf("CPU_IDLE=%llu\n", idle);
    printf("CPU_TOT=%llu\n", tot);
    print_mem();   // reads /proc/meminfo
    print_net();   // reads /proc/net/dev
    print_battery(); // reads /sys/class/power_supply
    print_temp();  // reads /sys/class/thermal
    return 0;
}
```

### Scanner That Consumes It

```ini
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

## Benefits

| Aspect | Shell Commands | C Utility |
|---|---|---|
| Process overhead | Fork + exec per command | Single process, direct syscalls |
| Latency | 10-50ms per command | < 1ms total |
| Parsing | Regex on unstructured output | Clean KEY=VALUE output |
| CPU usage | Higher (multiple processes) | Lower (single process) |
| Accuracy | Dependent on tool versions | Direct kernel interface reads |

## OCWS C Utilities

| Binary | Purpose | Reads From |
|---|---|---|
| `ocws-sysmon` | CPU, memory, network, battery, temp | `/proc/stat`, `/proc/meminfo`, `/proc/net/dev`, `/sys/class/power_supply`, `/sys/class/thermal` |
| `ocws-brightness` | Smooth brightness control with animation | `/sys/class/backlight/*/brightness` |
| `ocws-volume` | Smooth volume control with animation | `pactl` (PulseAudio IPC) |
| `ocws-color` | Extract dominant colors from images | Cairo image surfaces |
| `ocws-kv` | Key-value state store | Flat file (`~/.config/ocws/state.kv`) |
| `ocws-live-bg` | Animated layer-shell background | GTK + gtk-layer-shell |
| `ocws-osd-notify` | On-screen notification daemon | DBus (`org.freedesktop.Notifications`) |
| `ocws-hypertile` | Dynamic window tiling (stub) | Wayland protocol |

## Output Format Convention

All C utilities follow the same output convention:

```
KEY=VALUE
KEY2=VALUE2
...
```

- One `KEY=VALUE` per line
- Keys are `UPPER_SNAKE_CASE`
- Values are plain text (no quotes)
- Derived values computed in the same pass
- Last line triggers scanner derivation (see [sysmon-output-ordering](sysmon-output-ordering.md))
