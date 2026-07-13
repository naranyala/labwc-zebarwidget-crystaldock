#!/usr/bin/env bash
set -euo pipefail
# icon-theme-picker.sh
# Uses rofi to select and apply an icon theme system-wide
# Part of the OCWS Bash Utility Collection

notify_msg() {
    if command -v ocws-notify &> /dev/null; then
        ocws-notify "Theme" "$1" "preferences-desktop-theme-symbolic"
    else
        notify-send "Theme" "$1"
    fi
}

# Find all valid icon themes (directories containing index.theme)
THEMES=$(find /usr/share/icons ~/.local/share/icons ~/.icons -type f -name "index.theme" 2>/dev/null | awk -F'/' '{print $(NF-1)}' | sort -u)

if [ -z "$THEMES" ]; then
    notify_msg "No icon themes found."
    exit 1
fi

CHOSEN=$(echo "$THEMES" | rofi -dmenu -p "Select Icon Theme: " -l 15)

if [ -z "$CHOSEN" ]; then
    exit 0
fi

# Escape sed special characters in CHOSEN
ESCAPED_CHOSEN=$(printf '%s\n' "$CHOSEN" | sed 's/[.[\/*^$]/\\&/g')

notify_msg "Applying $CHOSEN..."

# Apply to crystal-dock
DOCK_CONF="$HOME/.config/crystal-dock/labwc/appearance.conf"
if [ -f "$DOCK_CONF" ]; then
    if grep -q "^iconTheme=" "$DOCK_CONF"; then
        sed -i "s/^iconTheme=.*/iconTheme=$ESCAPED_CHOSEN/" "$DOCK_CONF"
    else
        sed -i "/^\[General\]/a iconTheme=$CHOSEN" "$DOCK_CONF"
    fi
    # Restart dock
    pkill -x crystal-dock
    nohup crystal-dock >/dev/null 2>&1 &
fi

# Apply to GTK3
GTK3_CONF="$HOME/.config/gtk-3.0/settings.ini"
mkdir -p "$(dirname "$GTK3_CONF")"
if [ -f "$GTK3_CONF" ]; then
    if grep -q "^gtk-icon-theme-name=" "$GTK3_CONF"; then
        sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$ESCAPED_CHOSEN/" "$GTK3_CONF"
    else
        sed -i "/^\[Settings\]/a gtk-icon-theme-name=$CHOSEN" "$GTK3_CONF"
    fi
else
    echo -e "[Settings]\ngtk-icon-theme-name=$CHOSEN" > "$GTK3_CONF"
fi

# Apply to GTK4
GTK4_CONF="$HOME/.config/gtk-4.0/settings.ini"
mkdir -p "$(dirname "$GTK4_CONF")"
if [ -f "$GTK4_CONF" ]; then
    if grep -q "^gtk-icon-theme-name=" "$GTK4_CONF"; then
        sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$ESCAPED_CHOSEN/" "$GTK4_CONF"
    else
        sed -i "/^\[Settings\]/a gtk-icon-theme-name=$CHOSEN" "$GTK4_CONF"
    fi
else
    echo -e "[Settings]\ngtk-icon-theme-name=$CHOSEN" > "$GTK4_CONF"
fi

# Apply to GTK2
GTK2_CONF="$HOME/.gtkrc-2.0"
if [ -f "$GTK2_CONF" ]; then
    if grep -q "^gtk-icon-theme-name=" "$GTK2_CONF"; then
        sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=\"$CHOSEN\"/" "$GTK2_CONF"
    else
        echo "gtk-icon-theme-name=\"$CHOSEN\"" >> "$GTK2_CONF"
    fi
else
    echo "gtk-icon-theme-name=\"$CHOSEN\"" > "$GTK2_CONF"
fi

notify_msg "Icon theme changed to $CHOSEN"
