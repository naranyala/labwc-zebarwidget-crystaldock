#!/bin/bash
#
# reset-theme.sh — Reset all configs to a specific theme
#
# Usage: reset-theme.sh <theme-name>
#   reset-theme.sh catppuccin-mocha    Apply Catppuccin Mocha
#   reset-theme.sh list                List available themes
#   reset-theme.sh current             Show current theme
#
# Themes are INI profiles in themes/ directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
THEMES_DIR="$PROJECT_DIR/themes"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass()  { echo -e "  ${GREEN}✓${NC} $1"; }
fail()  { echo -e "  ${RED}✗${NC} $1"; exit 1; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
info()  { echo -e "  ${CYAN}→${NC} $1"; }

# --- List themes ---
list_themes() {
  echo ""
  echo -e "${BOLD}Available Themes:${NC}"
  echo ""
  for theme_ini in "$THEMES_DIR"/*.ini; do
    if [ -f "$theme_ini" ]; then
      name=$(basename "$theme_ini" .ini)
      # Read display name from [meta] section
      display=$(grep -A1 '^\[meta\]' "$theme_ini" 2>/dev/null | grep -i 'name\|label' | head -1 | cut -d= -f2- | tr -d '"' || true)
      [ -z "$display" ] && display="$name"
      echo "  $name"
    fi
  done
  echo ""
  echo "Usage: $0 <theme-name>"
}

# --- Show current ---
show_current() {
  echo ""
  # Check sfwbar CSS
  if [ -f "$HOME/.config/sfwbar/catppuccin-mocha.css" ]; then
    pass "sfwbar: catppuccin-mocha"
  elif [ -f "$HOME/.config/sfwbar/noctalia.css" ]; then
    pass "sfwbar: noctalia"
  elif [ -f "$HOME/.config/sfwbar/theme.css" ]; then
    pass "sfwbar: theme engine generated"
  else
    warn "sfwbar: unknown theme"
  fi

  # Check labwc theme
  if [ -f "$HOME/.config/labwc/themerc-override" ]; then
    bg=$(grep "activebg=" "$HOME/.config/labwc/themerc-override" 2>/dev/null | cut -d= -f2- || true)
    info "labwc: activebg=$bg"
  fi

  # Check fuzzel
  if [ -f "$HOME/.config/fuzzel/fuzzel.ini" ]; then
    bg=$(grep "^background=" "$HOME/.config/fuzzel/fuzzel.ini" 2>/dev/null | head -1 | cut -d= -f2- || true)
    info "fuzzel: background=$bg"
  fi

  # Check GTK
  if [ -f "$HOME/.config/gtk-3.0/settings.ini" ]; then
    gtk_theme=$(grep "^gtk-theme-name=" "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null | cut -d= -f2- || true)
    info "GTK3: theme=$gtk_theme"
  fi
}

# --- Apply theme ---
apply_theme() {
  local theme_name="$1"
  local theme_ini="$THEMES_DIR/${theme_name}.ini"

  if [ ! -f "$theme_ini" ]; then
    fail "Theme not found: $theme_ini"
  fi

  echo ""
  echo -e "${BOLD}Applying theme: $theme_name${NC}"
  echo ""

  # Use theme-engine if available
  if [ -f "$SCRIPT_DIR/theme-engine.sh" ]; then
    info "Using theme engine..."
    bash "$SCRIPT_DIR/theme-engine.sh" apply "$theme_ini"
  else
    warn "theme-engine.sh not found — manual theme apply"
    info "Theme file: $theme_ini"
  fi

  # Restart sfwbar with new theme
  if pgrep -x sfwbar >/dev/null 2>&1; then
    info "Restarting sfwbar..."
    pkill -9 -x sfwbar 2>/dev/null || true
    sleep 0.5
    if [ -f "$HOME/.local/bin/relaunch-status-bars.sh" ]; then
      "$HOME/.local/bin/relaunch-status-bars.sh" sfwbar &
    elif command -v sfwbar &>/dev/null; then
      nohup sfwbar > /dev/null 2>&1 &
    fi
    pass "sfwbar restarted"
  fi
}

# --- Main ---
case "${1:-}" in
  ""|--help|-h)
    echo ""
    echo -e "${BOLD}Reset Theme${NC}"
    echo ""
    echo "Usage: $0 <theme-name|list|current>"
    echo ""
    list_themes
    ;;
  list)     list_themes ;;
  current)  show_current ;;
  *)        apply_theme "$1" ;;
esac
