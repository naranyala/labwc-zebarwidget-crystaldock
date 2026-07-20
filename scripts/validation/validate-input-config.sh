#!/usr/bin/env bash
# validate-input-config.sh — Audit labwc input configuration for correct click/tap behavior
# Usage: ./scripts/validate-input-config.sh [path-to-rc.xml]

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
  # $1 = tag name, $2 = file
  grep -oP "(?<=<$1>).*(?=</$1>)" "$2" 2>/dev/null | head -1
}

# ─── Helper: check if a pattern exists ───
has() {
  grep -q "$1" "$RC" 2>/dev/null
}

# ─── Preamble ───
printf "\n${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}\n"
printf "${BOLD}${CYAN}║        labwc Input Configuration Validator                   ║${RESET}\n"
printf "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}\n"
printf "\n  Config: ${DIM}%s${RESET}\n" "$RC"

if [ ! -f "$RC" ]; then
  printf "\n  ${RED}ERROR: rc.xml not found at %s${RESET}\n\n" "$RC"
  exit 1
fi

printf "  Date:   ${DIM}%s${RESET}\n" "$(date '+%Y-%m-%d %H:%M:%S')"

# ═══════════════════════════════════════════════════════════════
header "1. XML Well-formedness"
# ═══════════════════════════════════════════════════════════════
if command -v xmllint &>/dev/null; then
  if xmllint --noout "$RC" 2>/dev/null; then
    pass "XML syntax" "xmllint reports valid XML"
  else
    fail "XML syntax" "xmllint reports errors — labwc may ignore the entire file"
  fi
else
  warn "XML syntax" "xmllint not installed, skipping XML validation"
fi

# Check for invalid tags
if has '<defaultInstances'; then
  fail "No invalid tags" "<defaultInstances/> is not a valid labwc element — remove it"
else
  pass "No invalid tags" "No unknown elements found"
fi

# ═══════════════════════════════════════════════════════════════
header "2. Touchpad — Tap-to-Click"
# ═══════════════════════════════════════════════════════════════
TAP=$(xml_val tap "$RC")
if [ "$TAP" = "yes" ]; then
  pass "tap" "Tap-to-click is enabled"
else
  fail "tap" "Tap-to-click is '$TAP' — set to 'yes' for tap = left click"
fi

# ═══════════════════════════════════════════════════════════════
header "3. Touchpad — Tap Button Mapping"
# ═══════════════════════════════════════════════════════════════
TBM=$(xml_val tapButtonMap "$RC")
case "$TBM" in
  lrm)
    pass "tapButtonMap" "lrm → 1-tap=Left, 2-tap=Right, 3-tap=Middle"
    ;;
  lmr)
    fail "tapButtonMap" "lmr → 2-tap=Middle (not Right!) — context menus won't work on 2-finger tap"
    ;;
  "")
    warn "tapButtonMap" "Not set — libinput default is 'lrm' which is correct"
    ;;
  *)
    warn "tapButtonMap" "Unusual value '$TBM' — expected 'lrm'"
    ;;
esac

# ═══════════════════════════════════════════════════════════════
header "4. Touchpad — Tap-and-Drag / Drag Lock"
# ═══════════════════════════════════════════════════════════════
TAD=$(xml_val tapAndDrag "$RC")
if [ "$TAD" = "yes" ]; then
  pass "tapAndDrag" "Tap-hold-drag for text selection is enabled"
else
  warn "tapAndDrag" "tapAndDrag='$TAD' — set to 'yes' for tap-hold-drag text selection"
fi

DL=$(xml_val dragLock "$RC")
case "$DL" in
  no)
    pass "dragLock" "Drag ends when finger lifts (no extra tap needed)"
    ;;
  yes)
    fail "dragLock" "Drag continues after finger lift — requires extra tap to end selection (click-select-click)"
    ;;
  "")
    pass "dragLock" "Not set — libinput default is 'no' which is correct"
    ;;
  *)
    warn "dragLock" "Unusual value '$DL'"
    ;;
esac

# ═══════════════════════════════════════════════════════════════
header "5. Touchpad — Click Method"
# ═══════════════════════════════════════════════════════════════
CM=$(xml_val clickMethod "$RC")
case "$CM" in
  clickfinger)
    pass "clickMethod" "clickfinger → finger count determines button (1=L, 2=R, 3=M)"
    ;;
  buttonareas)
    info "clickMethod" "buttonareas → touchpad zones determine button (like old Synaptics)"
    ;;
  "")
    warn "clickMethod" "Not set — depends on device default"
    ;;
  *)
    warn "clickMethod" "Value '$CM' — expected 'clickfinger' or 'buttonareas'"
    ;;
esac

# ═══════════════════════════════════════════════════════════════
header "6. Touchpad — Middle Emulation"
# ═══════════════════════════════════════════════════════════════
ME=$(xml_val middleEmulation "$RC")
case "$ME" in
  no)
    pass "middleEmulation" "Disabled — simultaneous taps won't produce surprise middle-clicks"
    ;;
  yes)
    fail "middleEmulation" "Enabled — simultaneous L+R taps/clicks produce middle-click, can cause confusion"
    ;;
  "")
    pass "middleEmulation" "Not set — libinput default is 'no' which is correct"
    ;;
esac

# ═══════════════════════════════════════════════════════════════
header "7. Touchpad — Scroll & Other"
# ═══════════════════════════════════════════════════════════════
SM=$(xml_val scrollMethod "$RC")
if [ "$SM" = "twofinger" ]; then
  pass "scrollMethod" "Two-finger scroll (standard)"
elif [ -n "$SM" ]; then
  info "scrollMethod" "'$SM'"
fi

NS=$(xml_val naturalScroll "$RC")
if [ "$NS" = "no" ]; then
  pass "naturalScroll" "Traditional scroll direction"
elif [ "$NS" = "yes" ]; then
  info "naturalScroll" "macOS-style natural scroll enabled"
fi

DWT=$(xml_val disableWhileTyping "$RC")
if [ "$DWT" = "yes" ]; then
  pass "disableWhileTyping" "Touchpad disabled during keyboard input"
elif [ "$DWT" = "no" ]; then
  warn "disableWhileTyping" "Touchpad stays active while typing — may cause accidental input"
fi

# ═══════════════════════════════════════════════════════════════
header "8. Mouse Bindings — Right-Click Context Menus"
# ═══════════════════════════════════════════════════════════════

# Root context: right-click on desktop → root-menu
if has 'context name="Root"' && grep -A2 'context name="Root"' "$RC" | grep -q 'button="Right".*ShowMenu.*root-menu'; then
  pass "Root right-click" "Right-click on desktop → root-menu"
else
  fail "Root right-click" "Missing: right-click on desktop should show root-menu"
fi

# Title context: right-click on titlebar → client-menu
if grep -A2 'context name="Title"' "$RC" | grep -q 'button="Right".*ShowMenu.*client-menu'; then
  pass "Title right-click" "Right-click on titlebar title → client-menu"
elif grep -A2 'Titlebar.*Top.*Right.*Bottom' "$RC" | grep -q 'button="Right".*ShowMenu.*client-menu'; then
  pass "Title right-click" "Right-click on titlebar area → client-menu (via combined context)"
else
  fail "Title right-click" "Missing: right-click on titlebar should show client-menu"
fi

# ═══════════════════════════════════════════════════════════════
header "9. Mouse Bindings — Standard Click Actions"
# ═══════════════════════════════════════════════════════════════

# Titlebar drag → Move
if grep -A5 'context name="Titlebar"' "$RC" | grep -q 'button="Left" action="Drag".*Move'; then
  pass "Titlebar drag" "Left-drag on titlebar → Move window"
else
  fail "Titlebar drag" "Missing: left-drag on titlebar should move window"
fi

# Titlebar double-click → ToggleMaximize
if grep -A5 'context name="Titlebar"' "$RC" | grep -q 'action="DoubleClick".*ToggleMaximize'; then
  pass "Titlebar double-click" "Double-click on titlebar → ToggleMaximize (standard)"
elif grep -A5 'context name="Titlebar"' "$RC" | grep -q 'action="DoubleClick".*ShowMenu'; then
  warn "Titlebar double-click" "Double-click opens a menu (non-standard — usually ToggleMaximize)"
else
  warn "Titlebar double-click" "No double-click binding on titlebar"
fi

# Close button
if grep -A3 'context name="Close"' "$RC" | grep -q 'action="Click".*Close'; then
  pass "Close button" "Click close button → Close window"
else
  fail "Close button" "Missing: close button click binding"
fi

# Maximize button
if grep -A3 'context name="Maximize"' "$RC" | grep -q 'action="Click".*ToggleMaximize'; then
  pass "Maximize button" "Click maximize button → ToggleMaximize"
else
  fail "Maximize button" "Missing: maximize button click binding"
fi

# Iconify button
if grep -A3 'context name="Iconify"' "$RC" | grep -q 'action="Click".*Iconify'; then
  pass "Iconify button" "Click minimize button → Iconify"
else
  fail "Iconify button" "Missing: iconify button click binding"
fi

# Super+Left drag → Move
if grep -A5 'context name="Frame"' "$RC" | grep -q 'button="W-Left" action="Drag".*Move'; then
  pass "Super+drag move" "Super+Left-drag → Move window"
else
  warn "Super+drag move" "Missing: Super+Left-drag on window should move"
fi

# Super+Right drag → Resize
if grep -A5 'context name="Frame"' "$RC" | grep -q 'button="W-Right" action="Drag".*Resize'; then
  pass "Super+drag resize" "Super+Right-drag → Resize window"
else
  warn "Super+drag resize" "Missing: Super+Right-drag on window should resize"
fi

# ═══════════════════════════════════════════════════════════════
header "10. Mouse Bindings — No Application Right-Click Hijack"
# ═══════════════════════════════════════════════════════════════

# Make sure there's no "Client" context with plain Right button that would swallow app right-clicks
if grep -A3 'context name="Client"' "$RC" | grep -q 'button="Right"'; then
  fail "Client right-click" "Found Right-click binding on Client context — this will hijack all app right-clicks!"
else
  pass "Client right-click" "No right-click hijack on Client context — apps handle their own right-click"
fi

# ═══════════════════════════════════════════════════════════════
header "11. Default Mouse Bindings"
# ═══════════════════════════════════════════════════════════════
if has '<default/>'; then
  pass "<default/>" "labwc default mouse bindings are loaded"
else
  fail "<default/>" "Missing <default/> — labwc built-in mouse bindings won't be loaded"
fi

# ═══════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════
printf "\n${BOLD}${CYAN}══════════════════════════════════════════════════════════════${RESET}\n"
printf "${BOLD}  Summary${RESET}\n"
printf "${CYAN}══════════════════════════════════════════════════════════════${RESET}\n"
printf "  ${GREEN}PASS: %d${RESET}   ${RED}FAIL: %d${RESET}   ${YELLOW}WARN: %d${RESET}\n" "$PASS" "$FAIL" "$WARN"

if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
  printf "\n  ${GREEN}${BOLD}All checks passed! Click/tap behavior is correctly configured.${RESET}\n"
elif [ "$FAIL" -eq 0 ]; then
  printf "\n  ${YELLOW}${BOLD}No failures, but some warnings to review.${RESET}\n"
else
  printf "\n  ${RED}${BOLD}%d issue(s) found — fix the FAIL items above.${RESET}\n" "$FAIL"
fi

printf "\n  ${DIM}Tip: Press Alt+R or run 'labwc --reconfigure' to apply changes.${RESET}\n\n"

exit "$FAIL"
