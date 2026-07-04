#!/bin/bash
#
# debug-sfwbar.sh — Debug sfwbar issues
#
# Checks: process state, config syntax, CSS loading, widget files, logs

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass()  { echo -e "  ${GREEN}✓${NC} $1"; }
fail()  { echo -e "  ${RED}✗${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
info()  { echo -e "  ${CYAN}→${NC} $1"; }
section() { echo -e "\n${BOLD}[$1]${NC}"; }

SFWBAR_DIR="$HOME/.config/sfwbar"
ERRORS=0

echo ""
echo -e "${BOLD}== sfwbar Debug =="
echo ""

# --- Process State ---
section "Process"
if pgrep -x sfwbar >/dev/null 2>&1; then
  PIDS=$(pgrep -x sfwbar | tr '\n' ' ')
  pass "sfwbar running (PID: $PIDS)"

  # Check how it was launched
  for pid in $(pgrep -x sfwbar); do
    CMDLINE=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || echo "unknown")
    info "  PID $pid: $CMDLINE"
  done
else
  fail "sfwbar NOT running"
  ((ERRORS++))
fi

# --- Config Files ---
section "Config Files"
if [ -f "$SFWBAR_DIR/sfwbar.config" ]; then
  pass "sfwbar.config exists"
  LINES=$(wc -l < "$SFWBAR_DIR/sfwbar.config")
  info "  $LINES lines"

  # Check for common issues
  if grep -q 'switcher.*disable.*false' "$SFWBAR_DIR/sfwbar.config" 2>/dev/null; then
    warn "  switcher is enabled (may cause issues with taskbar)"
  fi

  # Check for missing widget references
  while IFS= read -r line; do
    widget_name=$(echo "$line" | grep -oP 'widget\s+"([^"]+)"' | sed 's/widget "//;s/"//' || true)
    if [ -n "$widget_name" ] && [ ! -f "$SFWBAR_DIR/$widget_name" ]; then
      fail "  Referenced widget MISSING: $widget_name"
      ((ERRORS++))
    fi
  done < <(grep -n 'widget "' "$SFWBAR_DIR/sfwbar.config" 2>/dev/null || true)

  # Check for missing include references
  while IFS= read -r line; do
    inc_name=$(echo "$line" | grep -oP 'include\("([^"]+)"\)' | sed 's/include("//;s/")//' || true)
    if [ -n "$inc_name" ] && [ ! -f "$SFWBAR_DIR/$inc_name" ]; then
      fail "  Referenced include MISSING: $inc_name"
      ((ERRORS++))
    fi
  done < <(grep -n 'include(' "$SFWBAR_DIR/sfwbar.config" 2>/dev/null || true)
else
  fail "sfwbar.config MISSING"
  ((ERRORS++))
fi

# CSS
if [ -f "$SFWBAR_DIR/catppuccin-mocha.css" ]; then
  pass "catppuccin-mocha.css exists"
elif [ -f "$SFWBAR_DIR/noctalia.css" ]; then
  pass "noctalia.css exists"
elif [ -f "$SFWBAR_DIR/theme.css" ]; then
  pass "theme.css exists (theme engine generated)"
else
  warn "No CSS theme file found"
fi

# --- Widget Files ---
section "Widget Files"
WIDGET_COUNT=0
MISSING_DEPS=0
for widget in "$SFWBAR_DIR"/*.widget; do
  if [ -f "$widget" ]; then
    fname=$(basename "$widget")
    ((WIDGET_COUNT++))

    # Check for missing include targets
    while IFS= read -r inc; do
      inc_name=$(echo "$inc" | grep -oP 'include\("([^"]+)"\)' | sed 's/include("//;s/")//' || true)
      if [ -n "$inc_name" ] && [ ! -f "$SFWBAR_DIR/$inc_name" ]; then
        fail "  $fname → include MISSING: $inc_name"
        ((ERRORS++))
        ((MISSING_DEPS++))
      fi
    done < <(grep 'include(' "$widget" 2>/dev/null || true)
  fi
done

if [ "$WIDGET_COUNT" -gt 0 ] && [ "$MISSING_DEPS" -eq 0 ]; then
  pass "$WIDGET_COUNT widget files, all dependencies OK"
fi

# --- Log Check ---
section "Recent Logs"
# Check journalctl for sfwbar errors
if command -v journalctl &>/dev/null; then
  SF_LOGS=$(journalctl --since "1 hour ago" -u sfwbar --no-pager -q 2>/dev/null | tail -5 || true)
  if [ -n "$SF_LOGS" ]; then
    info "journalctl sfwbar (last 5 lines):"
    echo "$SF_LOGS" | while read -r line; do
      echo "    $line"
    done
  fi
fi

# Check for common GTK warnings
if [ -f /tmp/sfwbar-debug.log ]; then
  GTK_WARNS=$(grep -c "Gtk-WARNING" /tmp/sfwbar-debug.log 2>/dev/null || echo "0")
  if [ "$GTK_WARNS" -gt 0 ]; then
    warn "$GTK_WARNS GTK warnings in /tmp/sfwbar-debug.log"
  fi
fi

# --- Wayland Layer ---
section "Wayland Layer"
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
  pass "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"

  # Check if sfwbar is on the correct layer
  if command -v wlr-randr &>/dev/null; then
    info "Output info available via wlr-randr"
  fi
else
  warn "No WAYLAND_DISPLAY — sfwbar may not render"
  ((ERRORS++))
fi

# --- Summary ---
section "Summary"
echo ""
if [ "$ERRORS" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}No issues found${NC}"
else
  echo -e "${RED}${BOLD}$ERRORS issue(s) found${NC}"
fi
echo ""

exit "$ERRORS"
