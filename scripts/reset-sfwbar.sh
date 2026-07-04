#!/bin/bash
#
# reset-sfwbar.sh — Reset sfwbar config to project defaults
#
# Usage: reset-sfwbar.sh [--keep-css] [--dry-run]
#   --keep-css   Keep current CSS theme, only reset config
#   --dry-run    Show what would be done without making changes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass()  { echo -e "  ${GREEN}✓${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail()  { echo -e "  ${RED}✗${NC} $1"; exit 1; }
info()  { echo -e "  ${CYAN}→${NC} $1"; }

KEEP_CSS=false
DRY_RUN=false

for arg in "$@"; do
  case $arg in
    --keep-css) KEEP_CSS=true ;;
    --dry-run) DRY_RUN=true ;;
    --help)
      echo "Usage: $0 [--keep-css] [--dry-run]"
      echo ""
      echo "Options:"
      echo "  --keep-css   Keep current CSS theme, only reset config"
      echo "  --dry-run    Show what would be done"
      exit 0
      ;;
  esac
done

echo ""
echo -e "${BOLD}== Reset sfwbar Config =="
echo ""

SFWBAR_SRC="$PROJECT_DIR/dotfiles/sfwbar"
SFWBAR_DST="$HOME/.config/sfwbar"

# Verify source exists
if [ ! -d "$SFWBAR_SRC" ]; then
  fail "Source directory not found: $SFWBAR_SRC"
fi

# Backup current config
if [ -d "$SFWBAR_DST" ]; then
  BACKUP_DIR="$HOME/.config/sfwbar.bak.$(date +%Y%m%d-%H%M%S)"
  if $DRY_RUN; then
    info "Would backup current config to: $BACKUP_DIR"
  else
    cp -r "$SFWBAR_DST" "$BACKUP_DIR"
    pass "Backed up current config to $(basename "$BACKUP_DIR")"
  fi
fi

# Stop sfwbar
if pgrep -x sfwbar >/dev/null 2>&1; then
  if $DRY_RUN; then
    info "Would stop sfwbar"
  else
    pkill -9 -x sfwbar 2>/dev/null || true
    sleep 0.3
    pass "Stopped sfwbar"
  fi
fi

# Create destination
if $DRY_RUN; then
  info "Would create $SFWBAR_DST"
else
  mkdir -p "$SFWBAR_DST"
fi

# Copy config files
INSTALLED=0
for cfg_file in "$SFWBAR_SRC"/*.config "$SFWBAR_SRC"/*.widget "$SFWBAR_SRC"/*.source; do
  if [ -f "$cfg_file" ]; then
    fname=$(basename "$cfg_file")
    if $DRY_RUN; then
      info "Would install: $fname"
    else
      cp "$cfg_file" "$SFWBAR_DST/$fname"
      pass "Installed $fname"
    fi
    ((INSTALLED++))
  fi
done

# Copy CSS unless --keep-css
if ! $KEEP_CSS; then
  for css_file in "$SFWBAR_SRC"/*.css; do
    if [ -f "$css_file" ]; then
      fname=$(basename "$css_file")
      if $DRY_RUN; then
        info "Would install: $fname"
      else
        cp "$css_file" "$SFWBAR_DST/$fname"
        pass "Installed $fname"
      fi
      ((INSTALLED++))
    fi
  done
else
  info "Keeping existing CSS (--keep-css)"
fi

echo ""
if $DRY_RUN; then
  echo -e "${CYAN}Dry run complete. $INSTALLED file(s) would be installed.${NC}"
else
  echo -e "${GREEN}${BOLD}$INSTALLED file(s) installed to $SFWBAR_DST${NC}"
  echo ""
  echo "To start sfwbar: relaunch-status-bars.sh sfwbar"
fi
echo ""
