#!/bin/bash
#
# toggle-natural-scroll.sh — Toggle natural (inverted) scroll on touchpads
#
# Works on Wayland (labwc/sway) via libinput and gsettings.
# Detects current state and toggles.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}→${NC} $*"; }
pass()  { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
fail()  { echo -e "${RED}✗${NC} $*"; }

# --- Detect current natural scroll state via gsettings ---
get_gsettings_state() {
  if command -v gsettings &>/dev/null; then
    local val
    val=$(gsettings get org.gnome.desktop.peripherals.touchpad natural-scroll 2>/dev/null || echo "undefined")
    echo "$val"
  else
    echo "unavailable"
  fi
}

# --- Detect touchpad devices via libinput ---
get_touchpad_devices() {
  libinput list-devices 2>/dev/null | awk '
    /^Device:/ { name=$0; sub(/^Device:[[:space:]]*/, "", name) }
    /Capabilities:.*pointer/ { is_pointer=1 }
    /Capabilities:.*keyboard/ { is_keyboard=1 }
    /^Tag:/ { tag=$0; sub(/^Tag:[[:space:]]*/, "", tag) }
    /Natural Scrolling/ { print name; is_pointer=0; is_keyboard=0 }
  ' 2>/dev/null || true
}

# --- Get current libinput natural scroll state ---
get_libinput_state() {
  local device="$1"
  libinput list-devices 2>/dev/null | awk -v dev="$device" '
    /^Device:/ { name=$0; sub(/^Device:[[:space:]]*/, "", name); current=(name==dev) }
    current && /Natural Scrolling/ {
      if (/Enabled/) print "enabled"
      else if (/Disabled/) print "disabled"
      else print "unknown"
      exit
    }
  ' 2>/dev/null || echo "unknown"
}

# --- Apply via gsettings ---
apply_gsettings() {
  local value="$1"
  if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll "$value" 2>/dev/null
    return $?
  fi
  return 1
}

# --- Apply via udev hwdb (persistent) ---
apply_udev_hwdb() {
  local enabled="$1"
  local hwdb_file="/etc/udev/hwdb.d/90-touchpad.hwdb"
  local HWDB_TMP; HWDB_TMP=$(mktemp /tmp/90-touchpad-XXXXXX.hwdb)

  if [ "$enabled" = "true" ]; then
    # Enable natural scrolling
    cat > "$HWDB_TMP" << 'HWDB'
# Touchpad natural scroll
evdev:input:*:*:0003:*
  TOUCHPAD_NATURAL_SCROLL=1
HWDB
  else
    # Disable natural scrolling (default)
    cat > "$HWDB_TMP" << 'HWDB'
# Touchpad natural scroll
evdev:input:*:*:0003:*
  TOUCHPAD_NATURAL_SCROLL=0
HWDB
  fi

  if [ -d /etc/udev/hwdb.d/ ]; then
    sudo cp "$HWDB_TMP" "$hwdb_file"
    sudo udevadm hwdb --update 2>/dev/null || true
    rm -f "$HWDB_TMP"
    return 0
  fi
  return 1
}

# --- Main ---
echo ""
echo "== Natural Scroll Toggle =="
echo ""

# Check for libinput
if ! command -v libinput &>/dev/null; then
  fail "libinput not found"
  info "Install: sudo apt install libinput-tools"
  exit 1
fi

# Get touchpad devices
TOUCHPADS=$(get_touchpad_devices)
if [ -z "$TOUCHPADS" ]; then
  warn "No touchpad devices detected"
  info "This script is for touchpads. Mouse scroll direction is OS-level."
  exit 0
fi

echo "Touchpad devices found:"
echo "$TOUCHPADS" | while read -r d; do
  echo "  - $d"
done
echo ""

# Get current state
CURRENT_GSETTINGS=$(get_gsettings_state)
echo "Current gsettings state: $CURRENT_GSETTINGS"

# Determine target state
if [ "$CURRENT_GSETTINGS" = "true" ]; then
  TARGET="false"
  TARGET_LABEL="disabled (standard scroll)"
elif [ "$CURRENT_GSETTINGS" = "false" ]; then
  TARGET="true"
  TARGET_LABEL="enabled (natural scroll)"
else
  TARGET="true"
  TARGET_LABEL="enabled (natural scroll)"
fi

info "Toggling natural scroll to: $TARGET_LABEL"
echo ""

# Apply via gsettings
if apply_gsettings "$TARGET"; then
  pass "gsettings updated: natural-scroll = $TARGET"
else
  warn "Could not update gsettings (gsettings unavailable or no daemon)"
fi

# Apply via udev hwdb (persistent across reboots)
if [ -d /etc/udev/hwdb.d/ ]; then
  if apply_udev_hwdb "$TARGET"; then
    pass "udev hwdb updated (persistent)"
    info "Changes take effect after reboot or: sudo udevadm trigger"
  else
    warn "Could not update udev hwdb"
  fi
fi

echo ""
pass "Natural scroll is now $TARGET_LABEL"
echo ""
echo "Note: Some apps may need restart to pick up the change."
echo "To make persistent across reboots, ensure udev hwdb was updated."
