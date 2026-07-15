# Integration Matrix — OCWS C Utilities vs External Tools

> Which C utility replaces which external tool, and when to use each.

---

## Replacement Matrix

| OCWS C Utility | Replaces | External Tool | Advantage |
|----------------|----------|---------------|-----------|
| `ocws-notify` | mako, dunst | D-Bus notification daemon | Zero GTK dep, D-Bus native, lower memory |
| `ocws-osd-notify` | mako (with glassmorphic UI) | gtk-layer-shell popup overlay | Deep theme integration, animations |
| `ocws-brightness` | brightnessctl | `sysfs` backlight control | Smooth animated transitions, no deps |
| `ocws-volume` | pactl / wpctl direct calls | PulseAudio/PipeWire CLI | Smooth animated transitions, state streaming |
| `ocws-wallpaper` | swaybg | `wlr-layer-shell` wallpaper | Time-of-day transitions, crossfade |
| `ocws-ocr` | (no predecessor) | Tesseract + grim/slurp | Screen region → text extraction |
| `ocws-color` | (no predecessor) | ImageMagick / Python scripts | Palette extraction from wallpaper |
| `ocws-recorder` | wf-recorder manual usage | wf-recorder CLI wrapper | Start/stop/pause, PID tracking, notifications |
| `ocws-kv` | flat files / jq scripts | Shell file I/O | Atomic writes, hash lookup, section support |
| `ocws-sysmon` | multiple shell scripts | `/proc` parsing | Single binary, all metrics in one pass |
| `ocws-clip` | cliphist + fuzzel manual pipeline | cliphist, wl-clipboard | Unified clipboard manager interface |
| `ocws-shot` | grim + slurp manual pipeline | grim, slurp | Screenshot with annotation workflow |
| `ocws-lock` | swaylock direct invocation | swaylock | Wrapper with state save/restore |

---

## When to Use Each

### Use the C utility when:
- You need **smooth animated transitions** (brightness, volume)
- You need **instant event-driven updates** (ocws-emit integration)
- You need a **unified CLI interface** (ocws-volume get/set/up/down)
- You want **zero external Python/Go dependencies**
- You need **state persistence** across compositor restarts

### Use the external tool directly when:
- The C utility doesn't support your specific use case
- You need **advanced features** not yet implemented (e.g., gammastep's GeoClue location)
- You're **debugging** and want the raw tool output
- The external tool is a **build dependency** (e.g., labwc, zigshell-cairo-pango, fuzzel themselves)

---

## Dependency Chain

```
OCWS Desktop Session
├── labwc (compositor) ← built from source
├── zigshell-cairo-pango (panel) ← built from source
├── fuzzel (launcher) ← built from source
├── ocws-notify ← C utility (replaces mako)
├── ocws-brightness ← C utility (replaces brightnessctl)
├── ocws-volume ← C utility (wraps wpctl/pactl)
├── ocws-wallpaper ← C utility (replaces swaybg)
├── ocws-sysmon ← C utility (replaces shell scripts)
├── ocws-clip ← C utility (wraps cliphist)
├── ocws-shot ← C utility (wraps grim+slurp)
├── ocws-ocr ← C utility (tesseract, NEW capability)
├── ocws-color ← C utility (palette extraction, NEW capability)
├── ocws-recorder ← C utility (wraps wf-recorder)
├── ocws-kv ← C utility (persistence layer)
├── swaylock ← external (screen lock)
├── swayidle ← external (idle management)
├── playerctl ← external (MPRIS media control)
├── wl-clipboard ← external (clipboard backend)
├── cliphist ← external (clipboard history DB)
├── wlr-randr ← external (display management)
└── gammastep ← external (night light)
```

---

## Migration Guide

### mako → ocws-notify
```bash
# Before (autostart)
mako &

# After (autostart)
ocws-notify &

# Test: send a notification
notify-send "Test" "Hello from OCWS"
```

### brightnessctl → ocws-brightness
```bash
# Before (keybind action)
brightnessctl set +5%

# After (keybind action)
ocws-brightness up

# For widget display
ocws-brightness get
# Output: BRIGHTNESS=65
```

### pactl → ocws-volume
```bash
# Before (keybind action)
pactl set-sink-volume @DEFAULT_SINK@ +5%

# After (keybind action)
ocws-volume up

# For widget display
ocws-volume get
# Output: VOLUME=75\nVOLUME_MUTED=false\nVOLUME_ICON=audio-volume-high-symbolic
```

### swaybg → ocws-wallpaper
```bash
# Before (autostart)
swaybg -i ~/wallpaper.png -m fill &

# After (autostart)
ocws-wallpaper ~/Pictures/wallpapers/ &

# Wallpapers named: dawn-*.png, morning-*.png, etc.
```
