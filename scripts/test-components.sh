#!/bin/bash
#
# test-components.sh — Test C-based widget components
#
# Validates that components are built and installed correctly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPONENTS_DIR="$PROJECT_DIR/components"

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

ERRORS=0

echo ""
echo -e "${BOLD}== Component Test Suite ==${NC}"
echo ""

# ---- 1. Check source files ----
echo -e "${BOLD}[1. Source Files]${NC}"

for f in libwidget/include/widget.h libwidget/widget.c \
         libwidget/providers/system.c libwidget/wayland/layer-shell.c \
         libwidget/render/render.c libwidget/render/font.c; do
  if [[ -f "$COMPONENTS_DIR/$f" ]]; then
    pass "$f"
  else
    fail "$f (missing)"
    ((ERRORS++))
  fi
done

echo ""

# ---- 2. Check widget sources ----
echo -e "${BOLD}[2. Widget Sources]${NC}"

for w in clock cpu memory network battery volume; do
  if [[ -f "$COMPONENTS_DIR/widgets/$w/$w.c" ]]; then
    pass "widgets/$w/$w.c"
  else
    fail "widgets/$w/$w.c (missing)"
    ((ERRORS++))
  fi
done

echo ""

# ---- 3. Check statusbar sources ----
echo -e "${BOLD}[3. Statusbar Sources]${NC}"

for s in main compact panel; do
  if [[ -f "$COMPONENTS_DIR/statusbars/$s/$s.c" ]]; then
    pass "statusbars/$s/$s.c"
  else
    fail "statusbars/$s/$s.c (missing)"
    ((ERRORS++))
  fi
done

echo ""

# ---- 4. Check build system ----
echo -e "${BOLD}[4. Build System]${NC}"

if [[ -f "$COMPONENTS_DIR/meson.build" ]]; then
  pass "meson.build"
else
  fail "meson.build (missing)"
  ((ERRORS++))
fi

if [[ -d "$COMPONENTS_DIR/build" ]]; then
  if [[ -f "$COMPONENTS_DIR/build/build.ninja" ]]; then
    pass "build/ configured"
  else
    warn "build/ exists but not configured"
  fi
else
  warn "build/ not created yet"
fi

echo ""

# ---- 5. Check built binaries ----
echo -e "${BOLD}[5. Built Binaries]${NC}"

if [[ -d "$COMPONENTS_DIR/build" ]]; then
  for bin in statusbar-main statusbar-compact statusbar-panel \
             widget-clock widget-cpu widget-memory widget-network \
             widget-battery widget-volume; do
    if [[ -x "$COMPONENTS_DIR/build/$bin" ]]; then
      pass "$bin"
    else
      warn "$bin (not built)"
    fi
  done
else
  warn "Build directory not found"
fi

echo ""

# ---- 6. Check installed binaries ----
echo -e "${BOLD}[6. Installed Binaries]${NC}"

BINDIR="$HOME/.local/bin"
for bin in statusbar-main statusbar-compact statusbar-panel \
           widget-clock widget-cpu widget-memory widget-network \
           widget-battery widget-volume; do
  if [[ -x "$BINDIR/$bin" ]]; then
    pass "$bin"
  else
    warn "$bin (not installed)"
  fi
done

echo ""

# ---- 7. Check config ----
echo -e "${BOLD}[7. Configuration]${NC}"

CONFIG="$HOME/.config/labwc-widgets/status.json"
if [[ -f "$CONFIG" ]]; then
  pass "status.json"
  
  # Check values
  STATUSBAR=$(grep -o '"statusbar"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG" | sed 's/.*": *"//;s/"$//')
  DOCK=$(grep -o '"dock"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG" | sed 's/.*": *"//;s/"$//')
  
  info "Statusbar: $STATUSBAR"
  info "Dock: $DOCK"
else
  warn "status.json not found (will be created on first run)"
fi

echo ""

# ---- 8. Check registry ----
echo -e "${BOLD}[8. Registry]${NC}"

REGISTRY="$COMPONENTS_DIR/registry.json"
if [[ -f "$REGISTRY" ]]; then
  pass "registry.json"
else
  fail "registry.json (missing)"
  ((ERRORS++))
fi

echo ""

# ---- Summary ----
if [[ $ERRORS -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}All checks passed!${NC}"
else
  echo -e "${YELLOW}${BOLD}$ERRORS issue(s) found${NC}"
fi

echo ""
exit $ERRORS
