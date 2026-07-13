#!/usr/bin/env bash
set -euo pipefail
# download-icons.sh
# Downloads and installs popular icon themes from GitHub
# Part of the OCWS Bash Utility Collection

notify_msg() {
    if command -v ocws-notify &> /dev/null; then
        ocws-notify "Icon Downloader" "$1" "folder-download-symbolic"
    else
        notify-send "Icon Downloader" "$1"
    fi
}

mkdir -p "$HOME/.local/share/icons"
TMPDIR=$(mktemp -d /tmp/ocws-download-icons-XXXXXX)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT
cd "$TMPDIR" || exit 1

declare -A REPOS
REPOS=(
    ["WhiteSur"]="https://github.com/vinceliuice/WhiteSur-icon-theme.git"
    ["Tela"]="https://github.com/vinceliuice/Tela-icon-theme.git"
    ["Qogir"]="https://github.com/vinceliuice/Qogir-icon-theme.git"
    ["Colloid"]="https://github.com/vinceliuice/Colloid-icon-theme.git"
    ["Fluent"]="https://github.com/vinceliuice/Fluent-icon-theme.git"
    ["McMojave-circle"]="https://github.com/vinceliuice/McMojave-circle.git"
    ["Papirus"]="https://github.com/PapirusDevelopmentTeam/papirus-icon-theme.git"
    ["Layan"]="https://github.com/vinceliuice/Layan-icon-theme.git"
)

# Generate list for rofi
LIST=""
for theme in "${!REPOS[@]}"; do
    LIST="$LIST$theme\n"
done

CHOSEN=$(echo -e "$LIST" | rofi -dmenu -p "Download Icon Theme: " -l 10)

if [ -z "$CHOSEN" ]; then
    exit 0
fi

URL="${REPOS[$CHOSEN]}"
if [ -n "$URL" ]; then
    notify_msg "Downloading $CHOSEN... (this may take a minute)"
    rm -rf "$TMPDIR/$CHOSEN"
    if git clone --depth 1 "$URL" "$TMPDIR/$CHOSEN"; then
        notify_msg "Installing $CHOSEN..."
        cd "$TMPDIR/$CHOSEN" || exit 1
        
        # Most of these repos have an install.sh
        if [ -x "install.sh" ]; then
            ./install.sh -d "$HOME/.local/share/icons"
        else
            cp -r ./* "$HOME/.local/share/icons/"
        fi
        
        notify_msg "$CHOSEN installed successfully! Run Icon Picker to apply."
        rm -rf "$TMPDIR/$CHOSEN"
    else
        notify_msg "Failed to download $CHOSEN."
    fi
fi
