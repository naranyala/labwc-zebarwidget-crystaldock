#!/bin/bash
#
# screenshot-tool.sh — Unified screenshot helper for labwc
#
# Usage:
#   screenshot-tool.sh                  Interactive menu
#   screenshot-tool.sh area             Select area (grim + slurp)
#   screenshot-tool.sh full             Full screen
#   screenshot-tool.sh window           Active window
#   screenshot-tool.sh area-annotate    Area → annotate (satty/swappy)
#   screenshot-tool.sh full-annotate    Full → annotate (satty/swappy)
#   screenshot-tool.sh delay [N]        Full screen after N seconds (default: 3)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass()  { echo -e "${GREEN}✓${NC} $1"; }
fail()  { echo -e "${RED}✗${NC} $1"; exit 1; }
info()  { echo -e "${CYAN}→${NC} $1"; }

SAVE_DIR="$HOME/Pictures/screenshots"
mkdir -p "$SAVE_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# --- Tool Detection ---
HAS_SATTY=false
HAS_SWAPPY=false
HAS_GRIM=false
HAS_SLURP=false

command -v satty &>/dev/null && HAS_SATTY=true
command -v swappy &>/dev/null && HAS_SWAPPY=true
command -v grim &>/dev/null && HAS_GRIM=true
command -v slurp &>/dev/null && HAS_SLURP=true

# --- Functions ---
take_area() {
  $HAS_GRIM && $HAS_SLURP || fail "Need grim + slurp. Install: sudo apt install grim slurp"
  local file="$SAVE_DIR/screenshot-area-$TIMESTAMP.png"
  grim -g "$(slurp)" "$file" 2>/dev/null || fail "Selection cancelled or failed"
  wl-copy < "$file"
  pass "Area saved: $(basename "$file")"
}

take_full() {
  $HAS_GRIM || fail "Need grim. Install: sudo apt install grim"
  local file="$SAVE_DIR/screenshot-full-$TIMESTAMP.png"
  grim "$file" 2>/dev/null || fail "Screenshot failed"
  wl-copy < "$file"
  pass "Full screen saved: $(basename "$file")"
}

take_window() {
  $HAS_GRIM || fail "Need grim. Install: sudo apt install grim"
  # Get active window geometry via swaymsg (works on labwc too)
  local geo
  if command -v swaymsg &>/dev/null; then
    geo=$(swaymsg -t get_tree | jq -r '
      .. | select(.type?) | select(.focused==true) | .rect |
      "\(.x),\(.y) \(.width)x\(.height)"' 2>/dev/null || true)
  fi

  if [ -n "$geo" ]; then
    local file="$SAVE_DIR/screenshot-window-$TIMESTAMP.png"
    grim -g "$geo" "$file" 2>/dev/null || fail "Window capture failed"
    wl-copy < "$file"
    pass "Window saved: $(basename "$file")"
  else
    info "Could not detect window — falling back to area select"
    take_area
  fi
}

annotate() {
  local src="$1"
  if $HAS_SATTY; then
    satty --filename "$src" --output-filename "$src" --copy-command wl-copy 2>/dev/null
  elif $HAS_SWAPPY; then
    swappy -f "$src" -o "$src" 2>/dev/null
  else
    info "Install satty or swappy for annotation support"
    info "  satty:  https://github.com/RGBArray/satty"
    info "  swappy: sudo apt install swappy"
    return 1
  fi
}

take_area_annotate() {
  $HAS_GRIM && $HAS_SLURP || fail "Need grim + slurp"
  local file="$SAVE_DIR/screenshot-area-$TIMESTAMP.png"
  grim -g "$(slurp)" "$file" 2>/dev/null || fail "Selection cancelled"
  annotate "$file"
  pass "Area annotated: $(basename "$file")"
}

take_full_annotate() {
  $HAS_GRIM || fail "Need grim"
  local file="$SAVE_DIR/screenshot-full-$TIMESTAMP.png"
  grim "$file" 2>/dev/null || fail "Screenshot failed"
  annotate "$file"
  pass "Full annotated: $(basename "$file")"
}

take_delay() {
  local delay="${1:-3}"
  $HAS_GRIM || fail "Need grim"
  info "Taking screenshot in ${delay}s..."
  sleep "$delay"
  take_full
}

show_menu() {
  echo ""
  echo -e "${BOLD}Screenshot Menu${NC}"
  echo ""
  echo "  1) Area select"
  echo "  2) Full screen"
  echo "  3) Active window"
  echo "  4) Area → annotate"
  echo "  5) Full screen → annotate"
  echo "  6) Full screen (3s delay)"
  echo ""
  echo -n "Choice [1-6]: "
  read -r choice

  case $choice in
    1) take_area ;;
    2) take_full ;;
    3) take_window ;;
    4) take_area_annotate ;;
    5) take_full_annotate ;;
    6) take_delay ;;
    *) fail "Invalid choice" ;;
  esac
}

# --- Main ---
case "${1:-menu}" in
  area)           take_area ;;
  full)           take_full ;;
  window)         take_window ;;
  area-annotate)  take_area_annotate ;;
  full-annotate)  take_full_annotate ;;
  delay)          take_delay "${2:-3}" ;;
  menu|"")        show_menu ;;
  --help)
    echo "Usage: $0 [area|full|window|area-annotate|full-annotate|delay [N]|menu]"
    ;;
  *) fail "Unknown mode: $1" ;;
esac
