# Lesson: Event-Driven IPC Beats Polling

## The Problem

Polling (running a command every N seconds) wastes CPU and introduces latency. An event-driven approach reacts instantly to changes.

## Two Approaches in OCWS

### Polling (Scanner-based)

```ini
scanner {
  step = 2000
  exec("/bin/sh -c 'wpctl get-volume @DEFAULT_SINK@ 2>/dev/null'") {
    XVolLevel = Val(RegEx("Volume: ([0-9.]+)", Grab(First))) * 100
  }
}
```

- Runs `wpctl` every 2 seconds regardless of whether volume changed
- Wastes ~0.5% CPU per scanner
- 2-second worst-case latency

### Event-Driven (`ocws-daemon.sh` + IPC)

```bash
# ocws-daemon.sh listens for PipeWire events
pactl subscribe 2>/dev/null | grep "Event 'change' on sink" | while read -r line; do
    update_volume  # Immediately pushes to zigshell-cairo-pango via ocws-emit
done
```

```bash
# ocws-emit pushes the value to zigshell-cairo-pango instantly
zigshell-cairo-pango -R "SetVal XVolLevel = 75"
```

- Zero CPU when nothing changes
- Instant update (< 100ms latency)
- Only runs when something actually happens

## When to Use Each

| Approach | Best For | Example |
|---|---|---|
| Scanner polling | Values that change slowly, no event subscription available | Temperature, battery, uptime |
| Event-driven IPC | Values with D-Bus/kernel event subscriptions | Volume (pactl subscribe), brightness (inotifywait), media (playerctl --follow) |
| Hybrid | Start with events, fall back to polling | Network (events for connect/disconnect, polling for signal strength) |

## The IPC Chain

```
System Event → ocws-daemon.sh → ocws-emit.sh → zigshell-cairo-pango -R "SetVal ..." → Widget Variable → UI Update
```

Each link must use the **same variable name** — see [IPC Variable Mapping](ipc-variable-mapping.md).

## `ocws-daemon.sh` Architecture

```bash
# 1. Volume: subscribe to PipeWire changes
pactl subscribe | grep "sink" | while read; do update_volume; done

# 2. Brightness: watch kernel backlight file
inotifywait -m -e modify /sys/class/backlight/*/brightness | while read; do update_brightness; done

# 3. Media: follow playerctl metadata changes
playerctl metadata -F mpris:artUrl | while read; do download_art; done
```

Each listener runs in a background subshell and pushes updates via `ocws-emit.sh`.
