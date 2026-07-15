# playerctl — Learning Material

> Source: `./sources/playerctl` | Upstream: https://github.com/altdesktop/playerctl

---

## What is playerctl?

**playerctl** is a CLI tool for controlling media players that implement the
MPRIS D-Bus interface (vlc, mpv, Spotify, Firefox, Chromium, RhythmBox, etc.).

In OCWS, playerctl drives the media widget, media art fetcher, and playback control scripts.

---

## Basic Commands

```bash
playerctl play
playerctl pause
playerctl play-pause
playerctl stop
playerctl next
playerctl previous
playerctl position 30       # seek to 30s
playerctl position 30+      # forward 30s
playerctl position 30-      # back 30s
playerctl volume 0.8        # set volume 0.0–1.0
playerctl volume 0.1+       # increase
playerctl status            # Playing / Paused / Stopped
playerctl metadata          # all metadata
playerctl metadata title
playerctl metadata artist
playerctl metadata album
```

---

## Player Selection

```bash
# List all running players
playerctl --list-all

# Target a specific player
playerctl --player=spotify play

# Ignore a player
playerctl --ignore-player=firefox next

# Prioritize VLC, fall back to any other
playerctl --player=vlc,%any play

# All players
playerctl --all-players stop
```

---

## Format Templates

```bash
# Now playing banner
playerctl metadata --format "{{ artist }} - {{ title }}"

# With duration
playerctl metadata --format "{{ title }} {{ duration(position) }}/{{ duration(mpris:length) }}"

# Volume 0–100
playerctl metadata --format "Vol: {{ volume * 100 }}"

# Status with emoji
playerctl status --format "{{ emoji(status) }} {{ title }}"
```

### Template functions

| Function | Description |
|----------|-------------|
| `duration(n)` | Format microseconds as `mm:ss` |
| `lc(s)` | Lowercase |
| `uc(s)` | Uppercase |
| `emoji(status)` | play/pause/stop icon |
| `trunc(s, n)` | Truncate to n chars |
| `default(a, b)` | Print `a` or `b` if `a` is empty |

---

## Follow Mode (for widgets)

```bash
# Print artist+title every time it changes — feeds zigshell-cairo-pango widgets
playerctl metadata --format "{{ artist }} - {{ title }}" --follow
```

Used in `scripts/ocws-media-widget-updater.sh` to push live updates to the media widget via `ocws-emit`.

---

## playerctld Daemon

```bash
# Start the daemon (tracks most-recently-active player)
playerctld daemon &
```

With `playerctld` running, `playerctl` always acts on the last-active player automatically.
OCWS starts it from `dotfiles/labwc/autostart`.

---

## OCWS Integration

| File | Role |
|------|------|
| `dotfiles/ocws/media-player.widget` | Now playing display in zigshell-cairo-pango |
| `dotfiles/ocws/media.widget` | Compact media controls (prev/play/next) |
| `scripts/ocws-media-widget-updater.sh` | `playerctl --follow` → `ocws-emit Media.*` |
| `scripts/ocws-media-art.sh` | Fetches album art via `playerctl metadata mpris:artUrl` |
| `scripts/playerctl.sh` | Wrapper for keybind-triggered playback control |

---

## Build from Source

```bash
cd sources/playerctl
meson mesonbuild
sudo ninja -C mesonbuild install
```

**Dependencies:** GLib, gobject-introspection (optional), gtk-doc (optional)
