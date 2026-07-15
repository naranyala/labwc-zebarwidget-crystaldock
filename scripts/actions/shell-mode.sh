#!/bin/bash
# shell-mode.sh — Switch between shell modes: noctalia, zigshell-cairo-pango-plus, zigshell-cairo-pango

MODE="${1:-}"

if [ -z "$MODE" ]; then
  echo "Usage: $0 <mode>"
  echo ""
  echo "Modes:"
  echo "  noctalia     labwc + noctalia shell (default)"
  echo "  zigshell-cairo-pango-plus  labwc + enhanced OCWS dual panel"
  echo "  zigshell-cairo-pango       labwc + zigshell-cairo-pango only (minimal OCWS)"
  echo ""
  echo "Current mode: $(cat ~/.config/ocws/mode 2>/dev/null || cat ~/.config/labwc-widgets/shell-mode 2>/dev/null || echo noctalia)"
  exit 0
fi

if [ "$MODE" != "dms" ] && [ "$MODE" != "noctalia" ] && [ "$MODE" != "zigshell-cairo-pango-plus" ] && [ "$MODE" != "zigshell-cairo-pango" ]; then
    echo "Error: Invalid mode '$MODE'"
    echo "Valid modes: dms, noctalia, zigshell-cairo-pango-plus, zigshell-cairo-pango"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
if [ -x "$SCRIPT_DIR/scripts/toggle-shell" ]; then
  "$SCRIPT_DIR/scripts/toggle-shell" "$MODE"
else
  echo "Error: toggle-shell script not found at $SCRIPT_DIR/scripts/toggle-shell"
  exit 1
fi

echo "✅ Shell mode changed to: $MODE"