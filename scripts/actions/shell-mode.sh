#!/bin/bash
# shell-mode.sh — Switch between all supported OCWS shell modes

MODE="${1:-}"

VALID_MODES="doublepanel dms noctalia minimal tworow lxqt-bottom lxqt-left lxqt-right lxqt-top lxqt-classic lxqt-minimal lxqt-standalone lxqt-dual-lxqt lxqt-vertical zigshell-cairo-pango zigshell-cairo-pango-plus zigshell-blend2d zigshell-cairo-pango-clay"

if [ -z "$MODE" ]; then
  echo "Usage: $0 <mode>"
  echo ""
  echo "Modes:"
  echo "  doublepanel          OCWS Double Panel (top bar + bottom dock)"
  echo "  dms                  DankMaterialShell"
  echo "  noctalia             Noctalia floating dynamic island"
  echo "  minimal              OCWS Minimal bar"
  echo "  tworow               LXQt Tworow"
  echo "  lxqt-bottom          LXQt Bottom panel"
  echo "  lxqt-classic         LXQt Classic"
  echo "  lxqt-minimal         LXQt Minimal"
  echo "  lxqt-standalone      LXQt Standalone"
  echo "  lxqt-dual-lxqt       LXQt Dual Panels"
  echo "  lxqt-vertical        LXQt Vertical"
  echo "  zigshell-cairo-pango     zigshell-cairo-pango (merged panel + dock)"
  echo "  zigshell-cairo-pango-plus zigshell-cairo-pango (extended)"
  echo "  zigshell-blend2d         zigshell-blend2d (merged panel + dock, Blend2D)"
  echo "  lxqt-left               LXQt Left panel"
  echo "  lxqt-right              LXQt Right panel"
  echo "  lxqt-top                LXQt Top panel"
  echo ""
  echo "Current mode: $(cat ~/.config/ocws/mode 2>/dev/null || cat ~/.config/labwc-widgets/shell-mode 2>/dev/null || echo noctalia)"
  exit 0
fi

valid=false
for m in $VALID_MODES; do
    if [ "$MODE" = "$m" ]; then
        valid=true
        break
    fi
done

if [ "$valid" = false ]; then
    echo "Error: Invalid mode '$MODE'"
    echo "Valid modes: $VALID_MODES"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
if [ -x "$SCRIPT_DIR/scripts/toggle-shell" ]; then
  "$SCRIPT_DIR/scripts/toggle-shell" "$MODE"
else
  echo "Error: toggle-shell script not found at $SCRIPT_DIR/scripts/toggle-shell"
  exit 1
fi

echo "Shell mode changed to: $MODE"
