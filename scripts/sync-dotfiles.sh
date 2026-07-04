#!/bin/bash
#
# sync-dotfiles.sh — Install all dotfiles from project to ~/.config
#
# Syncs: labwc, sfwbar, fuzzel, fonts, scripts
# Usage: sync-dotfiles.sh [--dry-run] [--only COMPONENT]

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
section() { echo -e "\n${BOLD}[$1]${NC}"; }

DRY_RUN=false
ONLY=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    --only) ONLY="$2"; shift 2 ;;
    --help)
      echo "Usage: $0 [--dry-run] [--only labwc|sfwbar|fuzzel|scripts|all]"
      exit 0
      ;;
    *) shift ;;
  esac
done

DOTFILES="$PROJECT_DIR/dotfiles"
SCRIPTS_SRC="$PROJECT_DIR/scripts"
SCRIPTS_DST="$HOME/.local/bin"
INSTALLED=0

echo ""
echo -e "${BOLD}== Sync Dotfiles =="
echo ""

# --- labwc ---
if [ "$ONLY" = "" ] || [ "$ONLY" = "labwc" ]; then
  section "labwc"
  LABWC_SRC="$DOTFILES/labwc"
  LABWC_DST="$HOME/.config/labwc"
  mkdir -p "$LABWC_DST"

  for cfg in rc.xml autostart environment menu.xml themerc-override; do
    if [ -f "$LABWC_SRC/$cfg" ]; then
      if $DRY_RUN; then
        info "labwc/$cfg"
      else
        # Validate rc.xml before installing
        if [ "$cfg" = "rc.xml" ] && command -v xmllint &>/dev/null; then
          if ! xmllint --noout "$LABWC_SRC/$cfg" 2>/dev/null; then
            warn "labwc/$cfg: INVALID XML — skipping"
            continue
          fi
        fi
        cp "$LABWC_SRC/$cfg" "$LABWC_DST/$cfg"
        pass "$cfg"
      fi
      ((INSTALLED++))
    fi
  done

  # Make autostart executable
  if [ -f "$LABWC_DST/autostart" ] && [ ! -x "$LABWC_DST/autostart" ]; then
    if ! $DRY_RUN; then
      chmod +x "$LABWC_DST/autostart"
    fi
    pass "autostart: +x"
  fi
fi

# --- sfwbar ---
if [ "$ONLY" = "" ] || [ "$ONLY" = "sfwbar" ]; then
  section "sfwbar"
  SFWBAR_SRC="$DOTFILES/sfwbar"
  SFWBAR_DST="$HOME/.config/sfwbar"
  mkdir -p "$SFWBAR_DST"

  for f in "$SFWBAR_SRC"/*.config "$SFWBAR_SRC"/*.widget "$SFWBAR_SRC"/*.source "$SFWBAR_SRC"/*.css; do
    if [ -f "$f" ]; then
      fname=$(basename "$f")
      if $DRY_RUN; then
        info "sfwbar/$fname"
      else
        cp "$f" "$SFWBAR_DST/$fname"
        pass "$fname"
      fi
      ((INSTALLED++))
    fi
  done
fi

# --- fuzzel ---
if [ "$ONLY" = "" ] || [ "$ONLY" = "fuzzel" ]; then
  section "fuzzel"
  FUZZEL_SRC="$DOTFILES/fuzzel"
  FUZZEL_DST="$HOME/.config/fuzzel"

  if [ -d "$FUZZEL_SRC" ]; then
    mkdir -p "$FUZZEL_DST"
    for f in "$FUZZEL_SRC"/*; do
      if [ -f "$f" ]; then
        fname=$(basename "$f")
        if $DRY_RUN; then
          info "fuzzel/$fname"
        else
          cp "$f" "$FUZZEL_DST/$fname"
          pass "$fname"
        fi
        ((INSTALLED++))
      fi
    done
  fi
fi

# --- scripts → ~/.local/bin ---
if [ "$ONLY" = "" ] || [ "$ONLY" = "scripts" ]; then
  section "Scripts → ~/.local/bin"
  mkdir -p "$SCRIPTS_DST"

  for f in "$SCRIPTS_SRC"/*.sh; do
    if [ -f "$f" ]; then
      fname=$(basename "$f" .sh)
      dst="$SCRIPTS_DST/$fname"
      if $DRY_RUN; then
        info "$fname → ~/.local/bin/"
      else
        cp "$f" "$dst"
        chmod +x "$dst"
        pass "$fname"
      fi
      ((INSTALLED++))
    fi
  done

  # Also sync actions/ subdirectory
  if [ -d "$SCRIPTS_SRC/actions" ]; then
    mkdir -p "$SCRIPTS_DST/actions"
    for f in "$SCRIPTS_SRC/actions"/*.sh; do
      if [ -f "$f" ]; then
        fname=$(basename "$f" .sh)
        dst="$SCRIPTS_DST/actions/$fname"
        if $DRY_RUN; then
          info "actions/$fname"
        else
          cp "$f" "$dst"
          chmod +x "$dst"
          pass "actions/$fname"
        fi
        ((INSTALLED++))
      fi
    done
  fi
fi

echo ""
if $DRY_RUN; then
  echo -e "${CYAN}Dry run: $INSTALLED file(s) would be synced.${NC}"
else
  echo -e "${GREEN}${BOLD}$INSTALLED file(s) synced${NC}"
fi
echo ""
