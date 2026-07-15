#!/bin/bash
# -------------------------------------------------------------------
# OCWS State Daemon - Event-driven IPC for zigshell-cairo-pango
#
# Detects hardware/software state changes (volume keys, brightness,
# media player) and pushes them to zigshell-cairo-pango instantly via `ocws-emit`
# - NO per-widget polling.
#
# Widgets read the pushed variables (XVolLevel, XBrightness,
# XMediaTitle, ...) and re-render on change. The aggregated
# ocws-sysmon.source still polls continuous metrics (CPU, mem, net).
# -------------------------------------------------------------------

set -uo pipefail

PIDFILE="/tmp/ocws-daemon.pid"

# Stop any previously running instance by PID (NOT by command-line pattern,
# which would also match the launching shell). We kill the old process and
# its direct children (the listener subshells).
if [ -f "$PIDFILE" ]; then
    OLD_PID="$(cat "$PIDFILE" 2>/dev/null || echo "")"
    if [ -n "$OLD_PID" ] && [ "$OLD_PID" != "$$" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        pkill -P "$OLD_PID" 2>/dev/null || true
        kill "$OLD_PID" 2>/dev/null || true
        sleep 0.3
        pkill -9 -P "$OLD_PID" 2>/dev/null || true
        kill -9 "$OLD_PID" 2>/dev/null || true
    fi
    rm -f "$PIDFILE"
fi
echo "$$" > "$PIDFILE"

# Clean up on exit
cleanup() {
    pkill -P "$$" 2>/dev/null || true
    rm -f "$PIDFILE"
}
trap cleanup EXIT

# Clean stale state
rm -f /tmp/ocws-cover.jpg

# ocws-emit is a compiled binary in ~/.local/bin (already on PATH)
EMIT() { ocws-emit "$@" 2>/dev/null || true; }

update_volume() {
    RAW=$(wpctl get-volume @DEFAULT_SINK@ 2>/dev/null || echo "Volume: 0.00")
    VOL=$(echo "$RAW" | grep -oP '(?<=Volume: )[0-9.]+' || echo "0.00")
    VOL_PERCENT=$(echo "$VOL * 100 / 1" | bc 2>/dev/null || echo "0")
    MUTED=0
    echo "$RAW" | grep -q "MUTED" && MUTED=1
    EMIT System.Volume "$VOL_PERCENT"
    EMIT System.VolumeMuted "$MUTED"
}

update_brightness() {
    BRIGHT=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d % || echo 100)
    EMIT System.Brightness "$BRIGHT"
}

update_media() {
    ARTIST=$(playerctl metadata --format '{{ artist }}' 2>/dev/null || echo "none")
    TITLE=$(playerctl metadata --format '{{ title }}' 2>/dev/null || echo "none")
    ALBUM=$(playerctl metadata --format '{{ album }}' 2>/dev/null || echo "none")
    STATUS=$(playerctl status 2>/dev/null || echo "none")
    POS=$(playerctl metadata --format '{{ position }}' 2>/dev/null || echo "0")
    LEN=$(playerctl metadata --format '{{ mpris:length }}' 2>/dev/null || echo "0")
    EMIT Media.Artist "$ARTIST"
    EMIT Media.Title "$TITLE"
    EMIT Media.Album "$ALBUM"
    EMIT Media.Status "$STATUS"
    EMIT Media.Position "$POS"
    EMIT Media.Length "$LEN"
    printf '{"artist":"%s","title":"%s","album":"%s","status":"%s"}\n' \
        "$ARTIST" "$TITLE" "$ALBUM" "$STATUS" > /tmp/ocws-current-song 2>/dev/null || true
}

# 1. Volume listener (PipeWire/PulseAudio sink changes)
if command -v pactl >/dev/null 2>&1; then
    (
        pactl subscribe 2>/dev/null | grep --line-buffered "Event 'change' on sink" |
        while read -r _; do update_volume; done
    ) &
fi

# 2. Brightness listener (kernel backlight file)
if command -v inotifywait >/dev/null 2>&1; then
    (
        inotifywait -m -e modify /sys/class/backlight/*/brightness 2>/dev/null |
        while read -r _; do update_brightness; done
    ) &
fi

# 3. Media metadata listener (MPRIS)
if command -v playerctl >/dev/null 2>&1; then
    (
        update_media
        playerctl metadata -F '{{ artist }}|{{ title }}|{{ album }}|{{ status }}|{{ position }}|{{ mpris:length }}' 2>/dev/null |
        while IFS='|' read -r ARTIST TITLE ALBUM STATUS POS LEN; do
            [ -z "${ARTIST:-}" ] && ARTIST="none"
            [ -z "${TITLE:-}" ] && TITLE="none"
            [ -z "${ALBUM:-}" ] && ALBUM="none"
            [ -z "${STATUS:-}" ] && STATUS="none"
            EMIT Media.Artist "$ARTIST"
            EMIT Media.Title "$TITLE"
            EMIT Media.Album "$ALBUM"
            EMIT Media.Status "$STATUS"
            EMIT Media.Position "$POS"
            EMIT Media.Length "$LEN"
        done
    ) &

    # 4. Media art listener (download cover to /tmp for widgets)
    (
        while true; do
            playerctl metadata -F mpris:artUrl 2>/dev/null | while read -r ART_URL; do
                if [[ "$ART_URL" == file://* ]]; then
                    cp "${ART_URL#file://}" /tmp/ocws-cover.jpg 2>/dev/null || rm -f /tmp/ocws-cover.jpg
                elif [[ "$ART_URL" == http* ]]; then
                    curl -sSL --max-time 10 --connect-timeout 5 "$ART_URL" -o /tmp/ocws-cover.jpg 2>/dev/null \
                        && [ -f /tmp/ocws-cover.jpg ] \
                        || rm -f /tmp/ocws-cover.jpg
                else
                    rm -f /tmp/ocws-cover.jpg
                fi
            done
            sleep 60
        done
    ) &
fi

# Initial state push (retry until zigshell-cairo-pango is up, then listeners take over)
for _ in $(seq 1 10); do
    update_volume
    update_brightness
    [ "$(command -v playerctl)" ] && update_media
    zigshell-cairo-pango -R "Ping" >/dev/null 2>&1 && break
    sleep 1
done

wait
