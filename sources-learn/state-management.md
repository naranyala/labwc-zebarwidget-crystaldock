# State Management & IPC — Learning Material

> Scripts: `scripts/ocws-state.sh`, `scripts/ocws-emit.sh` | Binary: `src/ocws-sysmon.c` (built via `zig build`)

---

## The Problem: Keeping the Shell Reactive

In typical Wayland setups, panels (like `waybar`) have their own internal C++ modules for polling the battery, reading ALSA volume, or querying `playerctl`. 

In OCWS, the `zigshell-cairo-pango` panel uses a **Scanner IPC** architecture. Instead of the UI continuously polling the system (which drains battery and delays updates), the UI listens passively on a UNIX socket, and background daemons broadcast state changes instantly when they happen.

---

## 1. `ocws-emit.sh` (The Broadcaster)

`ocws-emit.sh` is a thin wrapper around `zigshell-cairo-pango`'s IPC mechanism. 

When a system event occurs (e.g., you press the Volume Up key), the script changes the volume, and then instantly tells `zigshell-cairo-pango` to update:

```bash
# Example from volume control script:
wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
NEW_VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)

# Instantly push the new value to the UI!
ocws-emit XVolRaw "$NEW_VOL"
```
Because of this, `zigshell-cairo-pango` updates exactly at the moment the volume changes, without waiting for its next poll interval.

---

## 2. `ocws-state.sh` (The Brain)

While `ocws-emit` handles instant IPC messages, `ocws-state.sh` handles **persistence**.

If the `zigshell-cairo-pango` panel restarts, it loses all its IPC variables. `ocws-state.sh` solves this by safely caching the most recent state to disk (in `/tmp/` or `~/.config/ocws/state/`). When `zigshell-cairo-pango` boots up, it reads from the state file to instantly populate the widgets, ensuring a seamless experience.

---

## 3. SysMon & Background Sources

For data that *must* be polled (like CPU usage, Memory, Network traffic), OCWS uses dedicated background binaries or scripts (like `ocws-sysmon`).

Instead of `zigshell-cairo-pango` launching `cat` 50 times a second for every individual widget, the UI launches `ocws-sysmon` once in the `ocws-sysmon.source` file. The backend efficiently queries the kernel, formats the output line-by-line, and the `zigshell-cairo-pango` scanner captures it all simultaneously.
