#!/bin/bash
#
# diagnostics.sh — Deep diagnostics and system info for labwc setup
#
# Generates comprehensive report for troubleshooting.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/.config/labwc"
ZEBAR_DIR="${HOME}/.config/zebar"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

OUTPUT_FILE=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --output|-o) OUTPUT_FILE="$2"; shift 2 ;;
    --verbose|-v) VERBOSE=true; shift ;;
    --help)
      echo "Usage: $0 [--output FILE] [--verbose]"
      echo ""
      echo "Options:"
      echo "  --output FILE   Save report to file instead of stdout"
      echo "  --verbose       Include detailed output"
      exit 0
      ;;
    *) shift ;;
  esac
done

# Output function
out() {
  if [ -n "$OUTPUT_FILE" ]; then
    echo "$@" >> "$OUTPUT_FILE"
  else
    echo "$@"
  fi
}

# ============================================================
out "=== labwc Diagnostics Report ==="
out "Generated: $(date)"
out "Hostname:  $(hostname)"
out "User:      $(whoami)"
out ""

# --- System Info ---
out "== System Information =="
out "Kernel:    $(uname -r)"
out "Arch:      $(uname -m)"
out "Distro:    $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo "unknown")"
out "Uptime:    $(uptime -p 2>/dev/null || uptime)"
out ""

# --- Display Server ---
out "== Display Server =="
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
  out "Wayland:   $WAYLAND_DISPLAY"
else
  out "Wayland:   not active"
fi
if [ -n "${XDG_SESSION_TYPE:-}" ]; then
  out "Session:   $XDG_SESSION_TYPE"
fi
if [ -n "${DISPLAY:-}" ]; then
  out "X11:       $DISPLAY (XWayland?)"
fi
out ""

# --- labwc ---
out "== labwc =="
if command -v labwc &>/dev/null; then
  out "Binary:    $(command -v labwc)"
  out "Version:   $(labwc --version 2>/dev/null || echo "unknown")"
else
  out "Binary:    NOT FOUND"
fi

if pgrep -x labwc &>/dev/null; then
  out "Status:    running (PID: $(pgrep -x labwc))"
else
  out "Status:    not running"
fi

if [ -d "$CONFIG_DIR" ]; then
  out "Config:    $CONFIG_DIR"
  out "Files:"
  ls -la "$CONFIG_DIR" 2>/dev/null | tail -n +2 | while read -r line; do
    out "  $line"
  done
else
  out "Config:    MISSING"
fi
out ""

# --- Input Devices ---
out "== Input Devices =="
if command -v libinput &>/dev/null; then
  out "libinput devices:"
  libinput list-devices 2>/dev/null | grep -E "^(Device:|Capabilities:|Kernel:)" | while read -r line; do
    out "  $line"
  done
else
  out "libinput: not installed"
fi
out ""

# --- Processes ---
out "== Running Processes =="
for proc in labwc crystal-dock zebar swaybg gammastep redshift mako dunst rofi foot lxpolkit; do
  if pgrep -x "$proc" &>/dev/null; then
    local_pids=$(pgrep -x "$proc" | tr '\n' ',' | sed 's/,$//')
    out "  ● $proc (PID: $local_pids)"
  fi
done
out ""

# --- Memory ---
out "== Memory =="
if command -v free &>/dev/null; then
  free -h | while read -r line; do
    out "  $line"
  done
fi
out ""

# --- GPU ---
out "== GPU =="
if command -v lspci &>/dev/null; then
  lspci | grep -i vga | while read -r line; do
    out "  $line"
  done
fi
if [ -d /sys/class/drm ]; then
  for card in /sys/class/drm/card*; do
    if [ -d "$card" ]; then
      local_name=$(basename "$card")
      local_status=$(cat "$card/status" 2>/dev/null || echo "?")
      out "  $card: $local_status"
    fi
  done
fi
out ""

# --- Audio ---
out "== Audio =="
if command -v wpctl &>/dev/null; then
  out "PipeWire/WirePlumber:"
  wpctl status 2>/dev/null | head -20 | while read -r line; do
    out "  $line"
  done
elif command -v pactl &>/dev/null; then
  out "PulseAudio:"
  pactl info 2>/dev/null | grep -E "Server Name|Default Sink|Default Source" | while read -r line; do
    out "  $line"
  done
fi
out ""

# --- Network ---
out "== Network =="
if command -v ip &>/dev/null; then
  ip -br addr 2>/dev/null | while read -r line; do
    out "  $line"
  done
fi
if command -v nmcli &>/dev/null; then
  local_wifi=$(nmcli -t -f TYPE,NAME,DEVICE connection show --active 2>/dev/null | head -5)
  if [ -n "$local_wifi" ]; then
    out "  Active connections:"
    echo "$local_wifi" | while read -r line; do
      out "    $line"
    done
  fi
fi
out ""

# --- Disk ---
out "== Disk =="
if command -v df &>/dev/null; then
  df -h / /home 2>/dev/null | while read -r line; do
    out "  $line"
  done
fi
out ""

# --- Environment ---
out "== Environment =="
for var in WAYLAND_DISPLAY XDG_SESSION_TYPE XDG_CURRENT_DESKTOP XDG_CONFIG_HOME XDG_DATA_HOME XDG_RUNTIME_DIR DISPLAY; do
  val="${!var:-}"
  if [ -n "$val" ]; then
    out "  $var=$val"
  fi
done

# PATH
out "  PATH (first 5):"
echo "$PATH" | tr ':' '\n' | head -5 | while read -r p; do
  out "    $p"
done
out ""

# --- XDG Portals ---
out "== XDG Desktop Portals =="
if command -v xdg-desktop-portal &>/dev/null; then
  out "Portal:     $(command -v xdg-desktop-portal)"
fi
for portal in xdg-desktop-portal-wlr xdg-desktop-portal-gtk; do
  if command -v "$portal" &>/dev/null; then
    out "  $portal: $(command -v "$portal")"
  fi
done
out ""

# --- GPU Rendering ---
out "== GPU Rendering =="
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
  if command -v EGL_INFO &>/dev/null; then
    out "EGL info:"
    EGL_INFO 2>/dev/null | head -10 | while read -r line; do
      out "  $line"
    done
  fi
  if [ -n "${LIBGL_ALWAYS_SOFTWARE:-}" ]; then
    out "LIBGL_ALWAYS_SOFTWARE: $LIBGL_ALWAYS_SOFTWARE"
  fi
fi
out ""

# --- Recent Errors ---
out "== Recent Errors (journalctl) =="
if command -v journalctl &>/dev/null; then
  journalctl --since "1 hour ago" -p err --no-pager -q 2>/dev/null | tail -20 | while read -r line; do
    out "  $line"
  done
fi
out ""

# --- dmesg (last 10 lines) ==
if $VERBOSE; then
  out "== dmesg (last 10) =="
  dmesg 2>/dev/null | tail -10 | while read -r line; do
    out "  $line"
  done
  out ""
fi

# --- End ---
out "== End of Report =="

if [ -n "$OUTPUT_FILE" ]; then
  echo "Report saved to: $OUTPUT_FILE"
  echo "File size: $(du -h "$OUTPUT_FILE" | cut -f1)"
else
  echo ""
  echo "Tip: Save this report with: $0 --output ~/labwc-diagnostics.txt"
fi
