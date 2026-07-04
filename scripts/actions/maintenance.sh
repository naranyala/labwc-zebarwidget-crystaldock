#!/bin/bash
# maintenance.sh — Common fixes, cache clearing, and restarts for Labwc

set -euo pipefail

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

notify() {
  local msg="$1"
  local icon="${2:-dialog-information}"
  if command -v notify-send &>/dev/null; then
    notify-send -a "Maintenance" -i "$icon" "Maintenance" "$msg"
  fi
  echo -e "${CYAN}→${NC} $msg"
}

# --- Actions ---

reload_ui() {
  notify "Reloading Desktop UI..." "view-refresh"
  # Reload labwc config
  labwc -r 2>/dev/null || true
  
  # Restart sfwbar
  if pgrep -x sfwbar >/dev/null; then
    killall sfwbar 2>/dev/null
    nohup sfwbar >/dev/null 2>&1 &
  fi
  
  # Restart crystal-dock if running
  if pgrep -x crystal-dock >/dev/null; then
    killall crystal-dock 2>/dev/null
    rm -f /tmp/qipc_sharedmemory_crystaldock* /tmp/qipc_systemsem_crystaldock* 2>/dev/null || true
    nohup crystal-dock >/dev/null 2>&1 &
  fi
  
  # Restart noctalia if running
  if pgrep -x noctalia >/dev/null; then
    killall noctalia 2>/dev/null
    nohup noctalia >/dev/null 2>&1 &
  fi
  
  notify "Desktop UI reloaded" "view-refresh"
}

restart_audio() {
  notify "Restarting Audio Services..." "audio-speakers"
  if systemctl --user is-active --quiet pipewire; then
    systemctl --user restart wireplumber pipewire pipewire-pulse 2>/dev/null || true
  else
    killall pipewire wireplumber pipewire-pulse 2>/dev/null || true
    sleep 1
    nohup pipewire >/dev/null 2>&1 &
    nohup wireplumber >/dev/null 2>&1 &
    nohup pipewire-pulse >/dev/null 2>&1 &
  fi
  notify "Audio restarted" "audio-speakers"
}

clear_clipboard() {
  if command -v cliphist &>/dev/null; then
    cliphist wipe
    notify "Clipboard history cleared!" "edit-clear"
  else
    notify "cliphist not installed" "dialog-error"
  fi
}

clear_caches() {
  notify "Clearing caches..." "edit-clear"
  # Thumbnails
  rm -rf "$HOME/.cache/thumbnails"/* 2>/dev/null || true
  # Fuzzel cache
  rm -f "$HOME/.cache/fuzzel" 2>/dev/null || true
  notify "Caches cleared!" "edit-clear"
}

restart_network() {
  notify "Restarting Network..." "network-wireless"
  if command -v nmcli &>/dev/null; then
    nmcli networking off
    sleep 1
    nmcli networking on
    notify "Network restarted" "network-wireless"
  else
    notify "NetworkManager (nmcli) not found" "dialog-error"
  fi
}

# --- Interactive Menu (Fuzzel) ---
interactive_menu() {
  if ! command -v fuzzel &>/dev/null; then
    echo "Fuzzel is required for interactive menu."
    exit 1
  fi

  options="1. 🔄 Reload Desktop UI
2. 🔊 Restart Audio (Pipewire)
3. 📋 Clear Clipboard History
4. 🗑️ Clear Thumbnail Cache
5. 🌐 Restart Network"

  chosen=$(echo "$options" | fuzzel -d -p "Maintenance: " -l 5 -w 40)

  case "$chosen" in
    1.*) reload_ui ;;
    2.*) restart_audio ;;
    3.*) clear_clipboard ;;
    4.*) clear_caches ;;
    5.*) restart_network ;;
    *) exit 0 ;;
  esac
}

# --- CLI parsing ---
MODE="${1:-menu}"

case "$MODE" in
  reload-ui)    reload_ui ;;
  audio)        restart_audio ;;
  clipboard)    clear_clipboard ;;
  caches)       clear_caches ;;
  network)      restart_network ;;
  menu)         interactive_menu ;;
  help|--help|-h)
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  menu          Show interactive fuzzel menu (default)"
    echo "  reload-ui     Reload labwc and panels"
    echo "  audio         Restart Pipewire audio services"
    echo "  clipboard     Clear cliphist history"
    echo "  caches        Clear thumbnail and app caches"
    echo "  network       Restart NetworkManager networking"
    ;;
  *)
    echo "Unknown command: $MODE"
    echo "Run '$0 help' for usage."
    exit 1
    ;;
esac
