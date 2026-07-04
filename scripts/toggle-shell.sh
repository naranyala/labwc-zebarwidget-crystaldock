#!/bin/bash
# toggle-shell — Switch between noctalia and sfwbar

CFG="$HOME/.config/labwc-widgets/status.json"
mkdir -p "$(dirname "$CFG")"

# Read current
if [ -f "$CFG" ]; then
    CURRENT=$(grep -o '"statusbar"[[:space:]]*:[[:space:]]*"[^"]*"' "$CFG" 2>/dev/null | head -1 | sed 's/.*": *"//;s/"$//')
fi

# Default is sfwbar
CURRENT=${CURRENT:-sfwbar}

if [ "$CURRENT" = "noctalia" ]; then
    NEW="sfwbar"
else
    NEW="noctalia"
fi

# Update config
if [ -f "$CFG" ]; then
    if grep -q '"statusbar"' "$CFG"; then
        sed -i "s|\"statusbar\"[[:space:]]*:[[:space:]]*\"[^\"]*\"|\"statusbar\": \"$NEW\"|" "$CFG"
    else
        sed -i "s|}$|  ,\"statusbar\": \"$NEW\"\n}|" "$CFG"
    fi
else
    cat > "$CFG" <<EOF
{
  "statusbar": "$NEW",
  "dock": "none"
}
EOF
fi

# Relaunch
relaunch-status-bars.sh all

notify-send "Shell Toggled" "Switched to $NEW"
