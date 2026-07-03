#!/bin/bash
#
# relaunch-status-bars.sh — Restart both sfwbar and crystal-dock
#
# Commonly used script to restart both statusbar (sfwbar) and dock (crystal-dock)
# Useful when configuration changes or after package updates.

# Exit on any error
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
info()  { echo -e "  ${CYAN}→${NC} $1"; }
fail()  { echo -e "  ${RED}✗${NC} $1"; exit 1; }
section() { echo -e "\n${BOLD}[$1]${NC}"; }

# ---- Main script ----
section "Status Bar and Dock Restart"

# Check if sfwbar exists
if ! command -v sfwbar >/dev/null 2>&1; then
  warn "sfwbar not found"
  info "Build and install SFWBar first"
  info "  cd $PROJECT_DIR"
  info "  git clone --depth 1 https://github.com/LBCrion/sfwbar.git build/sfwbar-src"
  info "  cd build/sfwbar-src"
  info "  meson setup build --prefix=\$HOME/.local"
  info "  ninja -C build"
  info "  ninja -C build install"
  fail "Install sfwbar first, then re-run this script"
fi

pass "sfwbar found: $(command -v sfwbar)"

# Check if crystal-dock exists
if ! command -v crystal-dock >/dev/null 2>&1; then
  warn "crystal-dock not found"
  fail "Install crystal-dock first, available via package manager or build from source"
fi

pass "crystal-dock found: $(command -v crystal-dock)"

# Stop existing processes
section "Stopping Processes"
if pgrep -f "sfwbar" >/dev/null 2>&1; then
  pkill -f "sfwbar"
  pass "sfwbar stopped"
else
  info "sfwbar not running"
fi

if pgrep -f "crystal-dock" >/dev/null 2>&1; then
  pkill -f "crystal-dock"
  pass "crystal-dock stopped"
else
  info "crystal-dock not running"
fi

# Wait briefly for processes to stop
sleep 0.5

# Start processes
section "Starting Processes"
sfwbar &
pass "sfwbar started (PID: $!)"

# crystal-dock requires specific flags for desktop usage
crystal-dock --start --overlay &
pass "crystal-dock started (PID: $!)"

section "Status Check"
if pgrep -f "sfwbar" >/dev/null 2>&1; then
  pass "sfwbar running"
else
  warn "sfwbar not running after start attempt"
fi

if pgrep -f "crystal-dock" >/dev/null 2>&1; then
  pass "crystal-dock running"
else
  warn "crystal-dock not running after start attempt"
fi

section "Summary"
pass "Both statusbar and dock restarted"
info ""
info "To monitor status: $SCRIPT_DIR/status.sh"
info "To swap statusbar (e.g., to zebar): widget-manager.sh swap statusbar zebar"
info "To disable dock: widget-manager.sh swap dock none"
