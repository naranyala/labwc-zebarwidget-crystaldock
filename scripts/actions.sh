#!/bin/bash
#
# actions.sh — Unified entry point for all action scripts
#
# Usage: ./actions.sh <category> [action] [args]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTIONS_DIR="$SCRIPT_DIR/actions"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

show_help() {
  echo ""
  echo -e "${BOLD}== labwc Actions ==${NC}"
  echo ""
  echo -e "${CYAN}Power:${NC}"
  echo "  power-menu                  Power menu (shutdown/reboot/logout)"
  echo "  power-menu shutdown         Shutdown immediately"
  echo "  power-menu reboot           Reboot immediately"
  echo "  power-menu logout           Logout immediately"
  echo "  power-menu suspend          Suspend immediately"
  echo ""
  echo -e "${CYAN}Screenshot:${NC}"
  echo "  screenshot area             Screenshot selected area"
  echo "  screenshot full             Screenshot full screen"
  echo "  screenshot window           Screenshot active window"
  echo ""
  echo -e "${CYAN}Clipboard:${NC}"
  echo "  clipboard show              Show clipboard history"
  echo "  clipboard pick              Pick from history"
  echo "  clipboard clear             Clear clipboard"
  echo ""
  echo -e "${CYAN}Audio:${NC}"
  echo "  audio up [step]             Volume up"
  echo "  audio down [step]           Volume down"
  echo "  audio mute                  Toggle mute"
  echo "  audio mute-input            Toggle microphone"
  echo ""
  echo -e "${CYAN}Brightness:${NC}"
  echo "  brightness up [step]        Brightness up"
  echo "  brightness down [step]      Brightness down"
  echo ""
  echo -e "${CYAN}Network:${NC}"
  echo "  network wifi-toggle         Toggle WiFi"
  echo "  network wifi-list           List networks"
  echo "  network bt-toggle           Toggle Bluetooth"
  echo "  network status              Network status"
  echo ""
  echo -e "${CYAN}Window:${NC}"
  echo "  window fullscreen           Toggle fullscreen"
  echo "  window floating             Toggle floating"
  echo "  window maximize             Toggle maximize"
  echo "  window kill                 Kill window"
  echo "  window snap-left            Snap to left half"
  echo "  window snap-right           Snap to right half"
  echo ""
  echo -e "${CYAN}Workspace:${NC}"
  echo "  workspace switch <N>        Switch to workspace N"
  echo "  workspace move <N>          Move window to workspace N"
  echo "  workspace next              Next workspace"
  echo "  workspace prev              Previous workspace"
  echo ""
  echo -e "${CYAN}Launcher:${NC}"
  echo "  launcher apps               Launch applications"
  echo "  launcher calc [expr]        Calculator"
  echo "  launcher emoji              Emoji picker"
  echo "  launcher color              Color picker"
  echo "  launcher url [url]          Open URL"
  echo ""
  echo -e "${CYAN}Settings:${NC}"
  echo "  settings dark-mode          Toggle dark mode"
  echo "  settings dnd                Toggle do not disturb"
  echo "  settings night-mode         Toggle night mode"
  echo "  settings touchpad           Toggle touchpad"
  echo ""
}

CATEGORY="${1:-help}"
shift || true

case "$CATEGORY" in
  power|power-menu|shutdown|reboot|logout|suspend)
    exec "$ACTIONS_DIR/power-menu.sh" "$CATEGORY" "$@" ;;
  screenshot|scrot|screen)
    exec "$ACTIONS_DIR/screenshot.sh" "$@" ;;
  clipboard|clip)
    exec "$ACTIONS_DIR/clipboard.sh" "$@" ;;
  audio|volume|sound)
    exec "$ACTIONS_DIR/audio.sh" "$@" ;;
  brightness|bright|backlight)
    exec "$ACTIONS_DIR/brightness.sh" "$@" ;;
  network|wifi|bluetooth|net)
    exec "$ACTIONS_DIR/network.sh" "$@" ;;
  window|wm)
    exec "$ACTIONS_DIR/window.sh" "$@" ;;
  workspace|ws|desktop)
    exec "$ACTIONS_DIR/workspace.sh" "$@" ;;
  launcher|launch|app|run)
    exec "$ACTIONS_DIR/launcher.sh" "$@" ;;
  settings|setting|config)
    exec "$ACTIONS_DIR/quick-settings.sh" "$@" ;;
  fuzzel-calc)
    exec "$ACTIONS_DIR/fuzzel-calc.sh" "$@" ;;
  fuzzel-emoji)
    exec "$ACTIONS_DIR/fuzzel-emoji.sh" "$@" ;;
  maintenance)
    exec "$ACTIONS_DIR/maintenance.sh" "$@" ;;
  help|--help|-h|*)
    show_help ;;
esac
