#!/bin/bash
# shell-mode-picker.sh — Rofi-based shell mode selector
# Calls toggle-shell with the selected mode.

declare -A MODES=(
    ["1. OCWS Double Panel (Default)"]="doublepanel"
    ["2. OCWS Minimal"]="minimal"
    ["3. ZIGSHELL-CAIRO-PANGO + Zigshell-cairo-pango"]="zigshell-cairo-pango"
    ["4. Dank Material Shell"]="dms"
    ["5. Noctalia Shell"]="noctalia"
    ["6. LXQt Tworow (Top + 2-row bottom)"]="tworow"
    ["7. LXQt Classic (Bottom panel + top bar)"]="lxqt-classic"
    ["8. LXQt Minimal (Tray+clock only)"]="lxqt-minimal"
    ["9. LXQt Standalone (No zigshell-cairo-pango)"]="lxqt-standalone"
    ["10. LXQt Dual Panels (Top+Bottom)"]="lxqt-dual-lxqt"
    ["11. LXQt Vertical (Right panel)"]="lxqt-vertical"
    ["12. LXQt Bottom (Full panel)"]="lxqt-bottom"
)

# Generate list for rofi
OPTIONS=""
for key in "${!MODES[@]}"; do
    OPTIONS+="$key\n"
done

# Run rofi
SELECTION=$(echo -e "$OPTIONS" | sort | rofi -dmenu -p "Select Shell Mode: " -theme-str 'window {width: 500px;}')

if [ -n "$SELECTION" ]; then
    MODE_ID="${MODES[$SELECTION]}"
    if [ -n "$MODE_ID" ]; then
        toggle-shell "$MODE_ID" &
    fi
fi
