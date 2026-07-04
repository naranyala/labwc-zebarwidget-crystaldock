#!/bin/bash
#
# health-check.sh — Quick one-shot health check for labwc + sfwbar
#
# Combines validate + fix into a single fast check.
# Run after making changes to verify everything works.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ERRORS=0
WARNINGS=0
FIXES=0

pass()  { echo -e "  ${GREEN}✓${NC} $1"; }
fail()  { echo -e "  ${RED}✗${NC} $1"; ERRORS=$((ERRORS + 1)); }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
fix()   { echo -e "  ${GREEN}🔧${NC} $1"; FIXES=$((FIXES + 1)); }
info()  { echo -e "  ${CYAN}→${NC} $1"; }

echo ""
echo -e "${BOLD}== labwc Health Check =="
echo ""

# --- 1. Core Processes ---
echo -e "${BOLD}[Processes]${NC}"

if pgrep -x labwc >/dev/null 2>&1; then
  pass "labwc running"
else
  fail "labwc NOT running"
fi

if pgrep -x sfwbar >/dev/null 2>&1; then
  pass "sfwbar running"
else
  warn "sfwbar NOT running"
fi

# --- 2. Config Files ---
echo -e "${BOLD}[Config]${NC}"

for f in rc.xml autostart environment; do
  if [ -f "$HOME/.config/labwc/$f" ]; then
    pass "$f"
  else
    fail "$f MISSING"
  fi
done

if [ -f "$HOME/.config/sfwbar/sfwbar.config" ]; then
  pass "sfwbar.config"
else
  fail "sfwbar.config MISSING"
fi

# --- 3. Autostart Executable ---
echo -e "${BOLD}[Permissions]${NC}"

if [ -f "$HOME/.config/labwc/autostart" ]; then
  if [ -x "$HOME/.config/labwc/autostart" ]; then
    pass "autostart executable"
  else
    chmod +x "$HOME/.config/labwc/autostart"
    fix "autostart: made executable"
  fi
fi

# --- 4. XML Validation ---
echo -e "${BOLD}[XML]${NC}"

if command -v xmllint &>/dev/null && [ -f "$HOME/.config/labwc/rc.xml" ]; then
  if xmllint --noout "$HOME/.config/labwc/rc.xml" 2>/dev/null; then
    pass "rc.xml valid"
  else
    fail "rc.xml INVALID"
  fi
fi

# --- 5. Broken Widget References ---
echo -e "${BOLD}[Widgets]${NC}"

if [ -f "$HOME/.config/sfwbar/sfwbar.config" ]; then
  MISSING=0
  while IFS= read -r line; do
    widget_name=$(echo "$line" | grep -oP 'widget\s+"([^"]+)"' | sed 's/widget "//;s/"//' || true)
    if [ -n "$widget_name" ] && [ ! -f "$HOME/.config/sfwbar/$widget_name" ]; then
      fail "Widget MISSING: $widget_name"
      ((MISSING++))
    fi
  done < <(grep 'widget "' "$HOME/.config/sfwbar/sfwbar.config" 2>/dev/null || true)

  if [ "$MISSING" -eq 0 ]; then
    pass "All widget references OK"
  fi
fi

# --- 6. GTK Fonts ---
echo -e "${BOLD}[GTK Fonts]${NC}"

GTK3_FILE="$HOME/.config/gtk-3.0/settings.ini"
if [ -f "$GTK3_FILE" ]; then
  FONT_VAL=$(grep "^gtk-font-name=" "$GTK3_FILE" 2>/dev/null | cut -d= -f2- || true)
  if [ -z "$FONT_VAL" ] || [ "$FONT_VAL" = "0" ]; then
    warn "GTK3 font-name corrupted — run fix-gtk-fonts.sh"
  else
    pass "GTK3 font: $FONT_VAL"
  fi
else
  warn "GTK3 settings.ini missing"
fi

# --- 7. Wayland ---
echo -e "${BOLD}[Wayland]${NC}"

if [ -n "${WAYLAND_DISPLAY:-}" ]; then
  pass "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
else
  warn "No WAYLAND_DISPLAY"
fi

if [ -n "${XDG_SESSION_TYPE:-}" ]; then
  pass "Session: $XDG_SESSION_TYPE"
fi

# --- 8. Key Services ---
echo -e "${BOLD}[Services]${NC}"

for svc in mako dunst nm-applet blueman-applet udiskie; do
  if pgrep -x "$svc" >/dev/null 2>&1 || pgrep -f "$svc" >/dev/null 2>&1; then
    pass "$svc"
  else
    info "$svc not running (optional)"
  fi
done

# --- Summary ---
echo ""
echo -e "${BOLD}Summary${NC}"
echo ""

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}All healthy!${NC}"
elif [ "$ERRORS" -eq 0 ]; then
  echo -e "${YELLOW}${BOLD}$WARNINGS warning(s)${NC} — functional but could be improved"
else
  echo -e "${RED}${BOLD}$ERRORS error(s), $WARNINGS warning(s)${NC}"
fi

if [ "$FIXES" -gt 0 ]; then
  echo -e "${GREEN}${BOLD}$FIXES auto-fix(es) applied${NC}"
fi
echo ""

exit "$ERRORS"
