#!/usr/bin/env bash
# validate-input-config-advanced.sh — Enhanced validation for "normally possible" click/tap behavior

# Usage: ./scripts/validate-input-config-advanced.sh [path-to-rc.xml]

set -uo pipefail

# ─── Colors ───
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
RESET=$'\033[0m'

PASS=0
FAIL=0
WARN=0

RC="${1:-$HOME/.config/labwc/rc.xml}"

pass()  { ((PASS++)); printf "  ${GREEN}✅ PASS${RESET}  %-28s %s\n" "$1" "${DIM}$2${RESET}"; }
fail()  { ((FAIL++)); printf "  ${RED}❌ FAIL${RESET}  %-28s %s\n" "$1" "$2"; }
warn()  { ((WARN++)); printf "  ${YELLOW}⚠️  WARN${RESET}  %-28s %s\n" "$1" "$2"; }
info()  { printf "  ${CYAN}ℹ  INFO${RESET}  %-28s %s\n" "$1" "${DIM}$2${RESET}"; }
header(){ printf "\n${BOLD}── %s ──${RESET}\n" "$1"; }

# ─── Helper: extract value from XML tag ───
xml_val() {
  grep -oP "(?<=<$1>).*(?=</$1>)" "$2" 2>/dev/null | head -1
}

# ─── Helper: check if a pattern exists ───
has() {
  grep -q "$1" "$RC" 2>/dev/null
}

# ─── Preamble ───
printf "\n${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}\n"
printf "${BOLD}${CYAN}║      labwc Input Configuration Advanced Validation           ║${RESET}\n"
printf "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}\n"
printf "\n  Config: ${DIM}%s${RESET}\n" "$RC"

if [ ! -f "$RC" ]; then
  printf "\n  ${RED}ERROR: rc.xml not found at %s${RESET}\n\n" "$RC"
  exit 1
fi

printf "  Date:   ${DIM}%s${RESET}\n" "$(date '+%Y-%m-%d %H:%M:%S')"

# ═══════════════════════════════════════════════════════════════
header "A. "Normally Possible" Tap-to-Click Validation"
# ═══════════════════════════════════════════════════════════════

TAP=$(xml_val tap "$RC")
TBM=$(xml_val tapButtonMap "$RC")
TAD=$(xml_val tapAndDrag "$RC")
DL=$(xml_val dragLock "$RC")

# Rule 1: Tap-to-click should be enabled for proper touchpad interaction
if [ "$TAP" = "yes" ]; then
  pass "tap-enabled" "Tap-to-click is enabled ✓"
  
  # Rule 1a: Button mapping should be sensible
  case "$TBM" in
    lrm)
      pass "button-mapping" "lrm mapping is correct → 1-tap=Left, 2-tap=Right, 3-tap=Middle ✓"
      ;;
    lmr)
      fail "button-mapping" "lmr is WRONG → 2-tap=Middle (not Right!) — context menus won't work properly ✗"
      ;;
    "")
      warn "button-mapping" "Not set — libinput default is 'lrm' which is correct, assuming lrm ✓"
      ;;
    *)
      warn "button-mapping" "Unusual value '$TBM' — expected 'lrm', assuming lrm ✓"
      ;;
  esac
  
  # Rule 1b: Tap-and-Drag should be enabled for text selection
  if [ "$TAD" = "yes" ]; then
    pass "tap-and-drag" "Tap-and-drag is enabled ✓"
  elif [ "$TAD" = "no" ]; then
    fail "tap-and-drag" "Tap-and-drag is disabled — text selection will require alternative methods ✗"
  else
    warn "tap-and-drag" "tapAndDrag not set — assuming 'yes' for text selection ✓"
  fi
  
  # Rule 1c: Drag Lock should be disabled for proper tap gesture flow
  if [ "$DL" = "yes" ]; then
    fail "drag-lock" "Drag Lock enabled — requires extra tap to end selection (broken UX) ✗"
  elif [ "$DL" = "no" ]; then
    pass "drag-lock" "Drag Lock disabled — proper tap gesture flow ✓"
  else
    warn "drag-lock" "dragLock not set — assuming 'no' ✓"
  fi
  
else
  fail "tap-enabled" "Tap-to-click is '$TAP' — required for normal touchpad operation ✗"
  
  # Even if tap is disabled, check that other settings don't conflict
  if [ "$TBM" = "lmr" ]; then
    fail "button-mapping-invalid" "Button mapping 'lmr' is invalid when tap-to-click is off ✗"
  fi
fi

# Rule 2: Click Method must match tap configuration
CM=$(xml_val clickMethod "$RC")
if [ "$TAP" = "yes" ]; then
  if [ "$CM" = "clickfinger" ]; then
    pass "click-method" "clickfinger matches tap-to-click ✓"
  elif [ "$CM" = "buttonareas" ]; then
    warn "click-method" "buttonareas with tap-to-click — mixed input styles may confuse users ✓"
  else
    warn "click-method" "clickMethod not set — assuming 'clickfinger' ✓"
  fi
fi

# Rule 3: Middle Emulation conflicts with tap button mapping
ME=$(xml_val middleEmulation "$RC")
if [ "$ME" = "yes" ] && [ "$TAP" = "yes" ]; then
  if [ "$TBM" = "lrm" ]; then
    fail "middle-emulation" "MiddleEmulation AND lrm mapping with tap — L+R will produce surprise middle-click, broken UX ✗"
  else
    warn "middle-emulation" "MiddleEmulation enabled — may cause confusion even with tap-to-click ✓"
  fi
fi

# Rule 4: Check double-click consistency
# Extract double-click binding(s) from config
has_double=$(grep -A5 -B5 'action="DoubleClick"' "$RC" | wc -l)
if [ "$has_double" -gt 0 ]; then
  pass "double-click-enabled" "Found double-click bindings ✓"
  
  # Check for specific critical double-clicks
  if ! has 'action="DoubleClick".*ToggleMaximize' "$RC"; then
    warn "double-click-titlebar" "No double-click to toggle maximize — may break window management ⌚"
  fi
else
  warn "double-click-enabled" "No double-click bindings found — standard is to bind Titlebar double-click to ToggleMaximize ⌚"
fi

# Rule 5: Right-click context menu accessibility
header "B. Right-Click Context Menu Validation"

# Check Root context for desktop right-click menu
if has 'context name="Root"' && grep -A2 'context name="Root"' "$RC" | grep -q 'button="Right".*ShowMenu.*root-menu'; then
  pass "root-right-click" "Desktop right-click → root-menu ✓"
elif has 'context name="Root"'; then
  warn "root-right-click" "Root context exists but not linked to right-click menu ⌚"
else
  fail "root-right-click" "No Root context — desktop right-click will show nothing ✗"
fi

# Check Client context (should NOT have plain Right-click)
if grep -A3 'context name="Client"' "$RC" | grep -q 'button="Right"'; then
  fail "client-hijack" "Client context has Right-click — will hijack all app right-clicks! ✗"
else
  pass "client-hijack" "Client context doesn't hijack right-click — apps handle their own ✓"
fi

# Rule 6: Required mouse bindings
header "C. Required Mouse Binding Validation"

required_bindings=(
  "Titlebar.*Left.*Drag.*Move"
  "Close.*Click.*Close"
  "Maximize.*Click.*ToggleMaximize"
  "Iconify.*Click.*Iconify"
  "Frame.*W-Left.*Drag.*Move"
  "Frame.*W-Right.*Drag.*Resize"
)

for binding in "${required_bindings[@]}"; do
  if grep -A3 "$binding" "$RC" 2>/dev/null > /dev/null; then
    pass "found:$binding" "Required binding found ✓"
  else
    warn "missing:$binding" "Missing optional binding ⌚"
  fi
done

# Rule 7: Check for conflicts and incompatibilities
header "D. Conflict Detection"

# Conflict 1: Middle Emulation + lrm + Simultaneous Tap
if [ "$ME" = "yes" ] && [ "$TBM" = "lrm" ] && [ "$TAP" = "yes" ]; then
  fail "conflict-simultaneous-tap" "L+R with middle emulation + lrm = surprise middle-click (broken) ✗"
fi

# Conflict 2: Drag Lock + Tap-and-Drag + Tap-to-Click
if [ "$DL" = "yes" ] && [ "$TAD" = "yes" ] && [ "$TAP" = "yes" ]; then
  warn "conflict-drag-flow" "Drag Lock enabled with tap-and-drag — requires extra tap to end selection (unusual) ⌚"
fi

# Conflict 3: No tap but middle emulation enabled
if [ "$TAP" != "yes" ] && [ "$ME" = "yes" ]; then
  warn "conflict-tap-emulation" "Middle emulation without tap-to-click — confusing fallback mechanism ⌚"
fi

# ═══════════════════════════════════════════════════════════════
header "E. Summary & Recommendations"
# ═══════════════════════════════════════════════════════════════

printf "\n${BOLD}${CYAN}══════════════════════════════════════════════════════════════${RESET}\n"
printf "${BOLD}  Summary${RESET}\n"
printf "${CYAN}══════════════════════════════════════════════════════════════${RESET}\n"
printf "  ${GREEN}PASS: %d${RESET}   ${RED}FAIL: %d${RESET}   ${YELLOW}WARN: %d${RESET}\n" "$PASS" "$FAIL" "$WARN"

if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
  printf "\n  ${GREEN}${BOLD}All checks passed! Click/tap behavior is correctly configured.${RESET}\n"
elif [ "$FAIL" -eq 0 ]; then
  printf "\n  ${YELLOW}${BOLD}No failures, but %d warnings to review.${RESET}\n" "$WARN"
else
  printf "\n  ${RED}${BOLD}%d critical issue(s) found — fix the FAIL items above.${RESET}\n" "$FAIL"
fi

printf "\n  ${DIM}Tip: Press Alt+R or run 'labwc --reconfigure' to apply changes.${RESET}\n\n"

exit "$FAIL"
