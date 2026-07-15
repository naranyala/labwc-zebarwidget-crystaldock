#!/bin/bash
# shell-mode-picker.sh — Rofi-based interactive shell mode picker
# Keybinding: Super+Shift+s

set -euo pipefail

CFG="$HOME/.config/ocws/mode"
mkdir -p "$(dirname "$CFG")"

CURRENT="$(cat "$CFG" 2>/dev/null || echo zigshell-cairo-pango)"

# Define available modes with descriptions
declare -A MODES=(
    ["doublepanel"]="  OCWS Double Panel — Dual zigshell-cairo-pango panels"
    ["zigshell-cairo-pango"]="  Zigshell-cairo-pango — ZIGSHELL-CAIRO-PANGO statusbar + macOS-style dock"
    ["minimal"]="  OCWS Minimal — Single top panel, lightweight"
    ["dms"]="  Dank Material Shell — Material 3 bar + dock"
    ["noctalia"]="  Noctalia Shell — Minimal config shell"
    ["tworow"]="  LXQt Tworow — Top panel + 2-row taskbar"
    ["lxqt-classic"]="  LXQt Classic — Bottom panel + top statusbar"
    ["lxqt-minimal"]="  LXQt Minimal — Tray+clock panel + minimal bar"
    ["lxqt-standalone"]="  LXQt Standalone — All-in-one panel, no zigshell-cairo-pango"
    ["lxqt-dual-lxqt"]="  LXQt Dual — Two lxqt-panels, no zigshell-cairo-pango"
    ["lxqt-vertical"]="  LXQt Vertical — Right side panel + top statusbar"
    ["lxqt-bottom"]="  LXQt Bottom — Full bottom panel + top statusbar"
)

# Build rofi input: current mode marker + all modes
OPTIONS=""
for mode in $(echo "${!MODES[@]}" | tr ' ' '\n' | sort); do
    desc="${MODES[$mode]}"
    if [ "$mode" = "$CURRENT" ]; then
        OPTIONS="${OPTIONS} [active] ${desc}\n"
    else
        OPTIONS="${OPTIONS} ${desc}\n"
    fi
done

# Launch rofi dmenu mode
SELECTED=$(echo -e "$OPTIONS" | rofi -dmenu \
    --prompt="Shell Mode: " \
    --width=50 \
    --lines=14 \
    --font="Noto Sans:size=14" \
    --layer=overlay \
    2>/dev/null)

# Extract mode name from selection
if [ -z "$SELECTED" ]; then
    # User cancelled
    exit 0
fi

# Parse the selected mode
NEW_MODE=""
case "$SELECTED" in
    *"Double Panel"*)   NEW_MODE="doublepanel" ;;
    *"Zigshell-cairo-pango"*)   NEW_MODE="zigshell-cairo-pango" ;;
    *"OCWS Minimal"*)   NEW_MODE="minimal" ;;
    *"Dank Material"*)  NEW_MODE="dms" ;;
    *"Noctalia"*)       NEW_MODE="noctalia" ;;
    *"LXQt Tworow"*)    NEW_MODE="tworow" ;;
    *"LXQt Classic"*)   NEW_MODE="lxqt-classic" ;;
    *"LXQt Minimal"*)   NEW_MODE="lxqt-minimal" ;;
    *"LXQt Standalone"*) NEW_MODE="lxqt-standalone" ;;
    *"LXQt Dual"*)      NEW_MODE="lxqt-dual-lxqt" ;;
    *"LXQt Vertical"*)  NEW_MODE="lxqt-vertical" ;;
    *"LXQt Bottom"*)    NEW_MODE="lxqt-bottom" ;;
    *) exit 1 ;;
esac

if [ -z "$NEW_MODE" ]; then
    exit 1
fi

# Skip if already active
if [ "$NEW_MODE" = "$CURRENT" ]; then
    notify-send -u low "Shell Mode" "Already using: $NEW_MODE" 2>/dev/null || true
    exit 0
fi

# Switch mode
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOGGLE_SHELL="$SCRIPT_DIR/../toggle-shell"

if [ -x "$TOGGLE_SHELL" ]; then
    "$TOGGLE_SHELL" "$NEW_MODE"
    notify-send -u low "Shell Mode" "Switched to: $NEW_MODE" 2>/dev/null || true
else
    notify-send -u critical "Shell Mode" "Error: toggle-shell not found" 2>/dev/null || true
    exit 1
fi
