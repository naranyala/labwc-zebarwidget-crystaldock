# Custom C Utilities — Learning Material

> Source: `./src/` | Build System: `build.zig` | Output: `zig-out/bin/`

---

## What are the OCWS C Utilities?

OCWS ships with 15+ bespoke C utilities compiled natively via `zig build`. These replace
external tools (mako, brightnessctl, swaybg, etc.) and add new capabilities (OCR, palette
extraction, smooth hardware control) that shell scripts cannot provide.

All utilities follow a consistent pattern:
- Single `.c` file in `src/`
- CLI interface with `--help`
- `KEY=VALUE` output format (for zigshell-cairo-pango scanner integration)
- No external dependencies where possible

---

## Building

```bash
zig build
ls zig-out/bin/
```

---

## Utility Reference

### System Monitoring

#### `ocws-sysmon`
Single-pass system metrics reader. Outputs all metrics in one efficient `/proc` read.

```bash
ocws-sysmon
# CPU_IDLE=123456
# CPU_TOT=789012
# MEM_TOT=16384
# MEM_USED=8192
# MEM_PCT=50.0
# NET_RX=1234567
# NET_TX=987654
# WIFI_STATE=connected
# BT_STATE=On
# BAT_LVL=85
# BAT_STAT=Discharging
# BRIGHTNESS=65
# TEMP=45
```

**Used by:** `ocws-sysmon.source` (zigshell-cairo-pango scanner polls this every 2s)

---

### Hardware Control

#### `ocws-brightness`
Smooth backlight control with cubic easing animation.

```bash
ocws-brightness get          # BRIGHTNESS=65
ocws-brightness set 50       # Smooth transition to 50%
ocws-brightness up           # +5% with animation
ocws-brightness down         # -5% with animation
ocws-brightness min          # 0%
ocws-brightness max          # 100%
ocws-brightness monitor      # Stream changes for zigshell-cairo-pango
```

**Replaces:** brightnessctl

#### `ocws-volume`
Smooth PulseAudio volume control with cubic easing.

```bash
ocws-volume get              # VOLUME=75\nVOLUME_MUTED=false\nVOLUME_ICON=audio-volume-high-symbolic
ocws-volume set 50           # Smooth transition to 50%
ocws-volume up               # +5% with animation
ocws-volume down             # -5% with animation
ocws-volume mute             # Toggle mute
ocws-volume monitor          # Stream changes for zigshell-cairo-pango
ocws-volume list             # List available sinks
ocws-volume sink alsa_output # Set default sink
```

**Replaces:** pactl / wpctl direct calls

---

### Wallpaper

#### `ocws-wallpaper`
Time-of-day wallpaper engine with crossfade transitions.

```bash
ocws-wallpaper ~/Pictures/wallpapers/
ocws-wallpaper -i 30 ~/Pictures/wallpapers/   # Check every 30s
ocws-wallpaper -w ~/Pictures/wallpapers/       # Print path on change
```

Wallpapers named by time slot: `dawn-*.png`, `morning-*.png`, `afternoon-*.png`,
`evening-*.png`, `dusk-*.png`, `night-*.png`. Falls back to `wallpaper.png`.

**Replaces:** swaybg

---

### Notifications

#### `ocws-notify`
Native D-Bus notification daemon implementing `org.freedesktop.Notifications`.

```bash
ocws-notify           # Foreground
ocws-notify -d        # Daemonize
```

Accepts notifications from any app using `notify-send` or `libnotify`. Outputs
notification details to stderr with timestamps. Emits D-Bus signals for widget integration.

**Replaces:** mako

#### `ocws-osd-notify`
Glassmorphic notification popup using gtk-layer-shell. Renders notification toasts
as Wayland overlay surfaces with blur, animations, and theme integration.

**Replaces:** mako (with visual enhancements)

---

### Screenshot & OCR

#### `ocws-shot`
Screenshot tool wrapping grim+slurp with annotation support.

```bash
ocws-shot                     # Region select → save
ocws-shot full                # Full screen → save
ocws-shot annotate            # Region → annotate (satty/swappy)
ocws-shot annotate-full       # Full screen → annotate
```

**Wraps:** grim + slurp

#### `ocws-ocr`
Screen OCR via Tesseract. Capture a region or read an image file.

```bash
ocws-ocr                      # Capture region → OCR
ocws-ocr screenshot.png       # OCR an image file
ocws-ocr -l eng+swe           # Swedish + English
ocws-ocr -m 7                 # Single-line mode
ocws-ocr -c                   # Copy result to clipboard
```

**New capability:** No predecessor — adds screen text extraction to OCWS.

---

### Clipboard

#### `ocws-clip`
Unified clipboard manager wrapping cliphist + wl-clipboard.

```bash
ocws-clip show                # Show clipboard history
ocws-clip pick                # Fuzzel picker → copy selection
ocws-clip clear               # Clear clipboard
ocws-clip copy "text"         # Copy text to clipboard
ocws-clip paste               # Paste from clipboard
```

**Wraps:** cliphist + wl-clipboard + fuzzel

---

### Color Extraction

#### `ocws-color`
Extract dominant palette from PNG images using median-cut quantization.

```bash
ocws-color wallpaper.png                      # 6 colors as hex
ocws-color -n 8 -f ini wallpaper.png          # 8 colors as INI section
ocws-color -f scss -o palette.scss wallpaper  # CSS variables
ocws-color -f json wallpaper.png              # JSON output
```

Output formats: `hex`, `rgb`, `scss`, `ini`, `json`

**New capability:** No predecessor — enables wallpaper-adaptive theming.

---

### Persistence

#### `ocws-kv`
Key-value store backed by flat files for persistent state.

```bash
ocws-kv set volume.level 75
ocws-kv get volume.level        # 75
ocws-kv list theme.             # prefix filter
ocws-kv has volume.level        # exit 0 or 1
ocws-kv del old.key
ocws-kv dump                    # all entries
```

Default store: `~/.config/ocws/state.kv`

**Replaces:** ad-hoc flat files, jq-based state scripts

---

### Recording

#### `ocws-recorder`
Screen recording wrapper around wf-recorder.

```bash
ocws-recorder start             # Region select, record with audio
ocws-recorder start -r          # Full screen recording
ocws-recorder start -a none     # No audio
ocws-recorder stop              # Stop current recording
ocws-recorder pause             # Pause recording
ocws-recorder resume            # Resume paused recording
ocws-recorder toggle            # Start/stop toggle
ocws-recorder status            # Show recording status
ocws-recorder list              # List recent recordings
```

Output: `~/Videos/recordings/recording-YYYYMMDD-HHMMSS.mp4`

**Wraps:** wf-recorder

---

### Screenshot (legacy)

#### `ocws-shot`
Screenshot capture with annotation support.

```bash
ocws-shot                      # Region → save
ocws-shot full                 # Fullscreen → save
ocws-shot annotate             # Region → annotate (satty/swappy)
```

**Wraps:** grim + slurp

---

### Clipboard (legacy)

#### `ocws-clip`
Clipboard manager with history picker.

```bash
ocws-clip show                 # Show history
ocws-clip pick                 # Fuzzel picker
ocws-clip clear                # Clear history
```

**Wraps:** cliphist + wl-clipboard

---

### Screen Lock

#### `ocws-lock`
Screen lock wrapper with state save/restore.

**Wraps:** swaylock

---

## Integration with zigshell-cairo-pango

Most C utilities output `KEY=VALUE` lines that zigshell-cairo-pango scanners parse:

```ini
# In a .source file
scanner {
  step = 2000
  exec("ocws-brightness get") {
    XBrightness = Val(Extract($0, "BRIGHTNESS=([0-9]+)"))
  }
}
```

Or via ocws-emit for event-driven updates:

```bash
# In a daemon script
BRIGHT=$(ocws-brightness get | grep BRIGHTNESS= | cut -d= -f2)
ocws-emit System.Brightness "$BRIGHT"
```
