#!/bin/bash
# ==============================================================================
# script: install-login-session.sh
# description: Fixes Labwc login manager (SDDM/GDM) integration for OpenMandriva
# ==============================================================================

set -euo pipefail

info() { echo -e "\n\033[1;36m[*] $1\033[0m"; }
pass() { echo -e "  \033[0;32m✓\033[0m $1"; }
fail() { echo -e "  \033[0;31m✗\033[0m $1"; exit 1; }

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  fail "Please run this script with sudo to install system-wide session files."
fi

info "Creating robust Wayland session wrapper..."

WRAPPER_PATH="/usr/local/bin/labwc-session"
cat << 'EOF' > "$WRAPPER_PATH"
#!/bin/sh
# ------------------------------------------------------------------------------
# Robust Labwc Session Wrapper
# Ensures environment variables and D-Bus are properly initialized before launch.
# ------------------------------------------------------------------------------

# 1. Source user environment (SDDM sometimes skips this for Wayland sessions)
if [ -f "$HOME/.bash_profile" ]; then
    . "$HOME/.bash_profile"
elif [ -f "$HOME/.profile" ]; then
    . "$HOME/.profile"
fi

# 2. Export strict Wayland environment variables
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=labwc
export XDG_SESSION_DESKTOP=labwc

# 3. Force Wayland backends for popular toolkits
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM="wayland;xcb"
export GDK_BACKEND="wayland,x11"
export SDL_VIDEODRIVER=wayland

# 4. Resolve the labwc binary
LABWC_BIN=$(command -v labwc)
if [ -z "$LABWC_BIN" ]; then
    # Fallback paths
    if [ -x "/usr/bin/labwc" ]; then LABWC_BIN="/usr/bin/labwc"
    elif [ -x "/usr/local/bin/labwc" ]; then LABWC_BIN="/usr/local/bin/labwc"
    elif [ -x "$HOME/.local/bin/labwc" ]; then LABWC_BIN="$HOME/.local/bin/labwc"
    else
        echo "Error: labwc binary not found!" >&2
        exit 1
    fi
fi

# 5. Launch with D-Bus session (crucial for Pipewire/Screensharing/Polkit)
if command -v dbus-run-session >/dev/null 2>&1; then
    exec dbus-run-session "$LABWC_BIN"
else
    exec "$LABWC_BIN"
fi
EOF

chmod +x "$WRAPPER_PATH"
pass "Created wrapper at $WRAPPER_PATH"


info "Creating Display Manager .desktop entry..."
SESSIONS_DIR="/usr/share/wayland-sessions"
mkdir -p "$SESSIONS_DIR"

cat << EOF > "$SESSIONS_DIR/labwc.desktop"
[Desktop Entry]
Name=Labwc (OCWS)
Comment=A robust Wayland stacking compositor
Exec=$WRAPPER_PATH
Icon=labwc
Type=Application
DesktopNames=labwc
EOF

pass "Created session file at $SESSIONS_DIR/labwc.desktop"


info "✅ Login manager integration fixed!"
echo "Log out, and select 'Labwc (OCWS)' from the session menu in your login screen."
