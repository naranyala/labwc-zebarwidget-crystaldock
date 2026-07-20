#!/bin/bash
# -------------------------------------------------------------------
# validate-labwc.sh — Comprehensive labwc configuration validator
#
# Validates all labwc config files: rc.xml, menu.xml, themerc-override,
# environment, autostart, autorun.conf. Checks structure, values,
# keybinds, mouse bindings, libinput, theme, env vars, and repo sync.
#
# Usage:
#   ./validate-labwc.sh                  # validate installed (~/.config/labwc/)
#   ./validate-labwc.sh /path/to/dir     # validate a specific labwc config dir
#   ./validate-labwc.sh --repo           # validate repo dotfiles
# -------------------------------------------------------------------

set -uo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0
INFO_COUNT=0

pass() { echo -e "  ${GREEN}PASS${NC}  $*"; PASS=$((PASS+1)); }
fail() { echo -e "  ${RED}FAIL${NC}  $*"; FAIL=$((FAIL+1)); }
warn() { echo -e "  ${YELLOW}WARN${NC}  $*"; WARN=$((WARN+1)); }
info() { echo -e "  ${DIM}INFO${NC}  $*"; INFO_COUNT=$((INFO_COUNT+1)); }

# ============================================================
# Resolve config directory
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")/dotfiles/labwc"

if [ "${1:-}" = "--repo" ]; then
    CONFIG_DIR="$REPO_DIR"
    MODE="repo"
elif [ -n "${1:-}" ] && [ -d "${1:-}" ]; then
    CONFIG_DIR="$1"
    MODE="custom"
else
    CONFIG_DIR="$HOME/.config/labwc"
    MODE="installed"
fi

RC_FILE="$CONFIG_DIR/rc.xml"
MENU_FILE="$CONFIG_DIR/menu.xml"
THEME_FILE="$CONFIG_DIR/themerc-override"
ENV_FILE="$CONFIG_DIR/environment"
AUTOSTART_FILE="$CONFIG_DIR/autostart"
AUTORUN_FILE="$CONFIG_DIR/autorun.conf"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║${NC}  ${CYAN}Labwc Configuration Validator${NC}                                ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${DIM}Mode: ${MODE} | Config: ${CONFIG_DIR}${NC}"
echo ""

# ============================================================
# Helper: extract XML value
# ============================================================
xml_val() {
    local file="$1" tag="$2"
    grep -oP "<${tag}>\K[^<]+" "$file" 2>/dev/null | head -1
}

xml_val_in() {
    local file="$1" context="$2" tag="$3"
    grep -A20 "$context" "$file" 2>/dev/null | grep -oP "<${tag}>\K[^<]+" | head -1
}

# ============================================================
# [0] File existence
# ============================================================
echo -e "${BOLD}[0] File existence${NC}"

for f in "$RC_FILE" "$MENU_FILE" "$THEME_FILE" "$ENV_FILE" "$AUTOSTART_FILE"; do
    name=$(basename "$f")
    if [ -f "$f" ]; then
        pass "$name exists ($(wc -l < "$f") lines)"
    else
        fail "$name NOT FOUND at $f"
    fi
done

if [ -f "$AUTORUN_FILE" ]; then
    pass "autorun.conf exists"
else
    warn "autorun.conf not found (optional)"
fi
echo ""

# ============================================================
# [1] XML well-formedness (rc.xml + menu.xml)
# ============================================================
echo -e "${BOLD}[1] XML well-formedness${NC}"

if command -v xmllint >/dev/null 2>&1; then
    if xmllint --noout "$RC_FILE" 2>/dev/null; then
        pass "rc.xml is valid XML"
    else
        fail "rc.xml has XML syntax errors"
        xmllint --noout "$RC_FILE" 2>&1 | head -5
    fi
    if xmllint --noout "$MENU_FILE" 2>/dev/null; then
        pass "menu.xml is valid XML"
    else
        fail "menu.xml has XML syntax errors"
        xmllint --noout "$MENU_FILE" 2>&1 | head -5
    fi
else
    # Fallback: check basic XML structure
    if grep -q '<labwc_config>' "$RC_FILE" && grep -q '</labwc_config>' "$RC_FILE"; then
        pass "rc.xml has opening/closing root tags"
    else
        fail "rc.xml missing root <labwc_config> tags"
    fi
    if grep -q '<labwc_menu>' "$MENU_FILE" && grep -q '</labwc_menu>' "$MENU_FILE"; then
        pass "menu.xml has opening/closing root tags"
    else
        fail "menu.xml missing root <labwc_menu> tags"
    fi
fi
echo ""

# ============================================================
# [2] Core settings
# ============================================================
echo -e "${BOLD}[2] Core settings${NC}"

DECORATION=$(xml_val "$RC_FILE" "decoration")
if [ -n "$DECORATION" ]; then
    case "$DECORATION" in
        server|client|none) pass "decoration = $DECORATION" ;;
        *) warn "decoration = '$DECORATION' (unusual value)" ;;
    esac
else
    warn "decoration not set (using labwc default)"
fi

# Check margin values are numeric
MARGIN_TOP=$(grep -oP 'margin\s+top="\K[^"]+' "$RC_FILE" 2>/dev/null | head -1)
MARGIN_BOTTOM=$(grep -oP 'margin\s+bottom="\K[^"]+' "$RC_FILE" 2>/dev/null | head -1)
MARGIN_LEFT=$(grep -oP 'margin\s+left="\K[^"]+' "$RC_FILE" 2>/dev/null | head -1)
MARGIN_RIGHT=$(grep -oP 'margin\s+right="\K[^"]+' "$RC_FILE" 2>/dev/null | head -1)
if [ -n "$MARGIN_TOP" ]; then
    pass "margin defined (t=$MARGIN_TOP b=$MARGIN_BOTTOM l=$MARGIN_LEFT r=$MARGIN_RIGHT)"
else
    info "no margin defined (using defaults)"
fi
echo ""

# ============================================================
# [3] Theme
# ============================================================
echo -e "${BOLD}[3] Theme${NC}"

THEME_NAME=$(xml_val "$RC_FILE" "name" | head -1)
if [ -n "$THEME_NAME" ]; then
    pass "theme name = $THEME_NAME"
else
    fail "theme name not set"
fi

CORNER=$(xml_val "$RC_FILE" "cornerRadius")
if [ -n "$CORNER" ]; then
    if [[ "$CORNER" =~ ^[0-9]+$ ]]; then
        pass "cornerRadius = $CORNER"
    else
        fail "cornerRadius = '$CORNER' (not a number)"
    fi
else
    warn "cornerRadius not set"
fi

# Font checks
for place in ActiveWindow InactiveWindow MenuHeader MenuItem; do
    FONT_NAME=$(grep -A3 "place=\"$place\"" "$RC_FILE" | grep -oP '<name>\K[^<]+' | head -1)
    FONT_SIZE=$(grep -A3 "place=\"$place\"" "$RC_FILE" | grep -oP '<size>\K[^<]+' | head -1)
    if [ -n "$FONT_NAME" ] && [ -n "$FONT_SIZE" ]; then
        pass "font $place: $FONT_NAME @ ${FONT_SIZE}pt"
    elif [ -n "$FONT_NAME" ]; then
        warn "font $place: name=$FONT_NAME but no size"
    else
        warn "font $place: not configured"
    fi
done

# themerc-override checks
if [ -f "$THEME_FILE" ]; then
    REQUIRED_THEME_KEYS=(
        "window.active.title.bg.color"
        "window.inactive.title.bg.color"
        "border.width"
        "titlebar.height"
        "menu.items.bg.color"
    )
    for key in "${REQUIRED_THEME_KEYS[@]}"; do
        if grep -q "^${key}:" "$THEME_FILE"; then
            val=$(grep "^${key}:" "$THEME_FILE" | head -1 | awk '{print $2}')
            pass "themerc: $key = $val"
        else
            warn "themerc: $key not defined"
        fi
    done
fi
echo ""

# ============================================================
# [4] Desktops
# ============================================================
echo -e "${BOLD}[4] Desktops${NC}"

DESK_NUM=$(xml_val "$RC_FILE" "number")
if [ -n "$DESK_NUM" ]; then
    if [[ "$DESK_NUM" =~ ^[0-9]+$ ]] && [ "$DESK_NUM" -ge 1 ]; then
        pass "desktops.number = $DESK_NUM"
    else
        fail "desktops.number = '$DESK_NUM' (invalid)"
    fi
else
    warn "desktops.number not set"
fi

FIRST_DESK=$(xml_val "$RC_FILE" "firstdesk")
if [ -n "$FIRST_DESK" ]; then
    if [[ "$FIRST_DESK" =~ ^[0-9]+$ ]]; then
        pass "desktops.firstdesk = $FIRST_DESK"
    else
        fail "desktops.firstdesk = '$FIRST_DESK' (invalid)"
    fi
else
    info "desktops.firstdesk not set (default 1)"
fi
echo ""

# ============================================================
# [5] Keyboard bindings
# ============================================================
echo -e "${BOLD}[5] Keyboard bindings${NC}"

# Count total keybinds
KB_COUNT=$(grep -c '<keybind' "$RC_FILE" 2>/dev/null)
pass "total keybinds defined: $KB_COUNT"

# Check for duplicate keybinds
DUPES=$(grep -oP 'key="\K[^"]+' "$RC_FILE" | sort | uniq -d)
if [ -n "$DUPES" ]; then
    while IFS= read -r dupe; do
        warn "duplicate keybind: $dupe"
    done <<< "$DUPES"
else
    pass "no duplicate keybinds"
fi

# Check essential keybinds
declare -A ESSENTIAL_KEYS=(
    ["A-r"]="Reconfigure"
    ["A-q"]="Close"
    ["A-Return"]="Terminal"
    ["A-f"]="ToggleFullscreen"
    ["A-space"]="ShowMenu"
)

for key in "${!ESSENTIAL_KEYS[@]}"; do
    label="${ESSENTIAL_KEYS[$key]}"
    if grep -q "key=\"$key\"" "$RC_FILE"; then
        pass "essential keybind: $key → $label"
    else
        fail "missing essential keybind: $key → $label"
    fi
done

# Check Execute commands reference scripts that exist
echo ""
info "checking keybind command availability..."
KEYBIND_CMDS=$(grep -oP '<command>\K[^<]+' "$RC_FILE" 2>/dev/null | sort -u)
MISSING_CMDS=0
while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    # Skip compound commands (pipes, &&, ||)
    if echo "$cmd" | grep -qE '[|;&]'; then
        continue
    fi
    # Extract base command (first word)
    BASE_CMD=$(echo "$cmd" | awk '{print $1}')
    # Skip env var prefixes
    BASE_CMD=$(echo "$BASE_CMD" | sed 's/^.*=//')
    if command -v "$BASE_CMD" >/dev/null 2>&1 || [ -x "$HOME/.local/bin/$BASE_CMD" ]; then
        : # exists
    else
        # Check scripts directory
        if [ -f "$SCRIPT_DIR/$BASE_CMD" ] || [ -f "$(dirname "$SCRIPT_DIR")/$BASE_CMD" ]; then
            : # exists in project
        else
            warn "keybind command not found in PATH: $BASE_CMD"
            MISSING_CMDS=$((MISSING_CMDS+1))
        fi
    fi
done <<< "$KEYBIND_CMDS"
if [ "$MISSING_CMDS" -eq 0 ]; then
    pass "all keybind commands available"
fi
echo ""

# ============================================================
# [6] Mouse bindings
# ============================================================
echo -e "${BOLD}[6] Mouse bindings${NC}"

# <default/> present in mouse section
MOUSE_START=$(grep -n '<mouse>' "$RC_FILE" | head -1 | cut -d: -f1)
MOUSE_END=$(grep -n '</mouse>' "$RC_FILE" | head -1 | cut -d: -f1)
if [ -n "$MOUSE_START" ] && [ -n "$MOUSE_END" ]; then
    pass "<mouse> section found (lines $MOUSE_START-$MOUSE_END)"
else
    fail "<mouse> section not found"
    echo ""
fi

# <default/> in mouse
if sed -n "${MOUSE_START},${MOUSE_END}p" "$RC_FILE" | grep -q '<default/>'; then
    pass "<default/> present in mouse section"
else
    warn "<default/> not found in mouse section"
fi

# <defaultInstances/> should NOT be in mouse
DEF_INST=$(sed -n "${MOUSE_START},${MOUSE_END}p" "$RC_FILE" | grep -c '<defaultInstances/>')
if [ "$DEF_INST" -eq 0 ]; then
    pass "<defaultInstances/> not in mouse section (correct)"
else
    fail "<defaultInstances/> found in mouse section (invalid — breaks parsing)"
fi

# Count mouse contexts
CTX_COUNT=$(sed -n "${MOUSE_START},${MOUSE_END}p" "$RC_FILE" | grep -c '<context name=')
pass "mouse contexts defined: $CTX_COUNT"

# Check duplicate context blocks
CTX_NAMES=$(sed -n "${MOUSE_START},${MOUSE_END}p" "$RC_FILE" | grep -oP 'context name="\K[^"]+' | sort)
CTX_DUPES=$(echo "$CTX_NAMES" | uniq -d)
if [ -n "$CTX_DUPES" ]; then
    while IFS= read -r d; do
        fail "duplicate mouse context: $d"
    done <<< "$CTX_DUPES"
else
    pass "no duplicate mouse contexts"
fi

# Required mouse contexts
REQUIRED_CTX=("Root" "Title" "Titlebar" "Frame")
for ctx in "${REQUIRED_CTX[@]}"; do
    if echo "$CTX_NAMES" | grep -q "^${ctx}$"; then
        pass "required context present: $ctx"
    else
        fail "missing required mouse context: $ctx"
    fi
done

# Root: right-click → root-menu
ROOT_CTX=$(sed -n "/<context name=\"Root\">/,/<\/context>/p" "$RC_FILE" 2>/dev/null)
if echo "$ROOT_CTX" | grep -q 'button="Right".*ShowMenu.*root-menu'; then
    pass "Root: right-click → root-menu"
else
    fail "Root: missing right-click → root-menu"
fi

# Title: right-click → client-menu
TITLE_CTX=$(sed -n "/<context name=\"Title\">/,/<\/context>/p" "$RC_FILE" 2>/dev/null)
if echo "$TITLE_CTX" | grep -q 'button="Right".*ShowMenu.*client-menu'; then
    pass "Title: right-click → client-menu"
else
    fail "Title: missing right-click → client-menu"
fi

# Titlebar edges: right-click → client-menu
TITLEBAR_EDGES=$(sed -n '/<context name="Titlebar Top Right Bottom/,/<\/context>/p' "$RC_FILE" 2>/dev/null)
if echo "$TITLEBAR_EDGES" | grep -q 'button="Right".*ShowMenu.*client-menu'; then
    pass "Titlebar edges: right-click → client-menu"
else
    warn "Titlebar edges: missing right-click → client-menu"
fi

# DoubleClick: should be standard (ToggleMaximize on Titlebar, no custom on Root/Title)
TITLEBAR_CTX=$(sed -n "/<context name=\"Titlebar\">/,/<\/context>/p" "$RC_FILE" 2>/dev/null)
if echo "$TITLEBAR_CTX" | grep -q 'DoubleClick.*ToggleMaximize'; then
    pass "Titlebar: DoubleClick → ToggleMaximize (standard)"
elif echo "$TITLEBAR_CTX" | grep -q 'DoubleClick.*ShowMenu'; then
    fail "Titlebar: DoubleClick → ShowMenu (customized, not standard)"
else
    pass "Titlebar: no custom DoubleClick binding"
fi

ROOT_DBL=$(echo "$ROOT_CTX" | grep 'DoubleClick')
if [ -z "$ROOT_DBL" ]; then
    pass "Root: no custom DoubleClick (standard)"
elif echo "$ROOT_DBL" | grep -q 'ShowMenu'; then
    fail "Root: DoubleClick → ShowMenu (customized)"
fi

TITLE_DBL=$(echo "$TITLE_CTX" | grep 'DoubleClick')
if [ -z "$TITLE_DBL" ]; then
    pass "Title: no custom DoubleClick (standard)"
elif echo "$TITLE_DBL" | grep -q 'ShowMenu'; then
    fail "Title: DoubleClick → ShowMenu (customized)"
fi
echo ""

# ============================================================
# [7] Applications rules
# ============================================================
echo -e "${BOLD}[7] Application rules${NC}"

APP_CLASSES=$(grep -oP 'class="\K[^"]+' "$RC_FILE" 2>/dev/null)
APP_COUNT=$(echo "$APP_CLASSES" | grep -c . 2>/dev/null)
pass "application rules defined: $APP_COUNT"

# Check expected classes
for cls in zigshell-cairo-pango noctalia zigshell-cairo-pango; do
    if echo "$APP_CLASSES" | grep -q "^${cls}$"; then
        pass "app rule present: $cls"
    else
        warn "app rule missing: $cls"
    fi
done
echo ""

# ============================================================
# [8] Menu (root-menu in rc.xml)
# ============================================================
echo -e "${BOLD}[8] Menu (root-menu)${NC}"

MENU_ID_COUNT=$(grep -c '<menu id=' "$RC_FILE" 2>/dev/null)
pass "menus defined: $MENU_ID_COUNT"

# Check root-menu has items
ROOT_MENU_ITEMS=$(sed -n '/<menu id="root-menu"/,/<\/menu>/p' "$RC_FILE" 2>/dev/null | grep -c '<item ')
if [ "$ROOT_MENU_ITEMS" -gt 0 ]; then
    pass "root-menu has $ROOT_MENU_ITEMS items"
else
    fail "root-menu has no items"
fi

# Check menu.xml has items
MENU_XML_ITEMS=$(grep -c '<item ' "$MENU_FILE" 2>/dev/null)
if [ "$MENU_XML_ITEMS" -gt 0 ]; then
    pass "menu.xml has $MENU_XML_ITEMS items"
else
    warn "menu.xml has no items"
fi
echo ""

# ============================================================
# [9] libinput / touchpad
# ============================================================
echo -e "${BOLD}[9] libinput / touchpad${NC}"

LIBINPUT_START=$(grep -n '<libinput>' "$RC_FILE" | head -1 | cut -d: -f1)
LIBINPUT_END=$(grep -n '</libinput>' "$RC_FILE" | head -1 | cut -d: -f1)
if [ -n "$LIBINPUT_START" ] && [ -n "$LIBINPUT_END" ]; then
    pass "<libinput> section found"
else
    fail "<libinput> section not found"
    echo ""
fi

LIBINPUT_SEC=$(sed -n "${LIBINPUT_START},${LIBINPUT_END}p" "$RC_FILE" 2>/dev/null)

# Touchpad device category
if echo "$LIBINPUT_SEC" | grep -q 'category="touchpad"'; then
    pass "touchpad device category defined"
else
    fail "no <device category=\"touchpad\">"
fi

# Touchpad settings (expected values for normal click/tap behavior)
declare -A TOUCHPAD_EXPECTED=(
    ["tap"]="yes"
    ["tapButtonMap"]="lrm"
    ["tapAndDrag"]="yes"
    ["dragLock"]="no"
    ["clickMethod"]="clickfinger"
    ["scrollMethod"]="twofinger"
    ["disableWhileTyping"]="yes"
    ["sendEventsMode"]="yes"
    ["accelProfile"]="flat"
)

for key in "${!TOUCHPAD_EXPECTED[@]}"; do
    expected="${TOUCHPAD_EXPECTED[$key]}"
    actual=$(echo "$LIBINPUT_SEC" | grep -oP "<${key}>\K[^<]+" | head -1)
    if [ "$actual" = "$expected" ]; then
        pass "$key = $actual"
    elif [ -n "$actual" ]; then
        fail "$key = $actual (expected: $expected)"
    else
        warn "$key not configured"
    fi
done

# pointerSpeed: -1.0 to 1.0
SPEED=$(echo "$LIBINPUT_SEC" | grep -oP '<pointerSpeed>\K[^<]+' | head -1)
if [ -n "$SPEED" ]; then
    if echo "$SPEED" | grep -qE '^-?[0-9]+\.?[0-9]*$'; then
        pass "pointerSpeed = $SPEED"
    else
        fail "pointerSpeed = '$SPEED' (not a number)"
    fi
else
    warn "pointerSpeed not configured"
fi

# Default pointer device
if echo "$LIBINPUT_SEC" | grep -q 'category="default"'; then
    pass "default pointer device category defined"
else
    warn "no <device category=\"default\">"
fi
echo ""

# ============================================================
# [10] Environment variables
# ============================================================
echo -e "${BOLD}[10] Environment variables${NC}"

if [ -f "$ENV_FILE" ]; then
    # Required Wayland env vars
    declare -A REQUIRED_ENV=(
        ["XDG_CURRENT_DESKTOP"]="labwc"
        ["XDG_SESSION_TYPE"]="wayland"
        ["QT_QPA_PLATFORM"]="wayland"
        ["MOZ_ENABLE_WAYLAND"]="1"
        ["XCURSOR_SIZE"]="24"
    )

    for key in "${!REQUIRED_ENV[@]}"; do
        expected="${REQUIRED_ENV[$key]}"
        actual=$(grep "^${key}=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2-)
        if [ "$actual" = "$expected" ]; then
            pass "env: $key = $actual"
        elif [ -n "$actual" ]; then
            warn "env: $key = $actual (expected: $expected)"
        else
            fail "env: $key not set"
        fi
    done

    # Optional but recommended
    for key in QT_WAYLAND_DISABLE_WINDOWDECORATION SDL_VIDEODRIVER CLUTTER_BACKEND ELECTRON_OZONE_PLATFORM_HINT GTK_USE_PORTAL GDK_BACKEND; do
        if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
            val=$(grep "^${key}=" "$ENV_FILE" | head -1 | cut -d= -f2-)
            pass "env: $key = $val"
        else
            info "env: $key not set (optional)"
        fi
    done
else
    fail "environment file not found"
fi
echo ""

# ============================================================
# [11] Autostart
# ============================================================
echo -e "${BOLD}[11] Autostart${NC}"

if [ -f "$AUTOSTART_FILE" ]; then
    if [ -x "$AUTOSTART_FILE" ]; then
        pass "autostart is executable"
    else
        warn "autostart is not executable (chmod +x needed)"
    fi

    LINE_COUNT=$(wc -l < "$AUTOSTART_FILE")
    pass "autostart: $LINE_COUNT lines"

    # Check key autostart services
    for svc in dbus-update-activation-environment xdg-desktop-portal swayidle flameshot; do
        if grep -q "$svc" "$AUTOSTART_FILE"; then
            pass "autostart includes: $svc"
        else
            info "autostart: $svc not referenced"
        fi
    done
else
    fail "autostart not found"
fi

if [ -f "$AUTORUN_FILE" ]; then
    AUTORUN_LINES=$(grep -v '^#' "$AUTORUN_FILE" | grep -v '^$' | wc -l)
    pass "autorun.conf: $AUTORUN_LINES programs"
else
    info "autorun.conf not found (optional)"
fi
echo ""

# ============================================================
# [12] Repo vs installed sync
# ============================================================
echo -e "${BOLD}[12] Repo vs installed sync${NC}"

if [ "$MODE" = "installed" ] && [ -d "$REPO_DIR" ]; then
    FILES_TO_CHECK=("rc.xml" "menu.xml" "autostart" "themerc-override" "autorun.conf" "environment" "startup-wallpaper.sh")
    SYNC_OK=0
    SYNC_DIFF=0
    for fname in "${FILES_TO_CHECK[@]}"; do
        repo_f="$REPO_DIR/$fname"
        inst_f="$CONFIG_DIR/$fname"
        if [ -f "$repo_f" ] && [ -f "$inst_f" ]; then
            if diff -q "$repo_f" "$inst_f" >/dev/null 2>&1; then
                pass "$fname: synced"
                SYNC_OK=$((SYNC_OK+1))
            else
                fail "$fname: DIFFERS from repo"
                SYNC_DIFF=$((SYNC_DIFF+1))
            fi
        elif [ -f "$repo_f" ]; then
            info "$fname: only in repo"
        elif [ -f "$inst_f" ]; then
            info "$fname: only installed"
        fi
    done
    # presets dir
    if diff -rq "$REPO_DIR/presets/" "$CONFIG_DIR/presets/" >/dev/null 2>&1; then
        pass "presets/: synced"
        SYNC_OK=$((SYNC_OK+1))
    else
        warn "presets/: differs"
        SYNC_DIFF=$((SYNC_DIFF+1))
    fi
    info "sync: $SYNC_OK matched, $SYNC_DIFF differ"
elif [ "$MODE" = "repo" ]; then
    info "validating repo dotfiles — sync check skipped"
else
    info "repo dir not found — sync check skipped"
fi
echo ""

# ============================================================
# [13] labwc runtime status
# ============================================================
echo -e "${BOLD}[13] Runtime status${NC}"

if pgrep -x labwc >/dev/null 2>&1; then
    pass "labwc is running"
    LABWC_PID=$(pgrep -x labwc | head -1)
    info "labwc PID: $LABWC_PID"

    # Check if wayland session is active
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        pass "WAYLAND_DISPLAY = $WAYLAND_DISPLAY"
    else
        warn "WAYLAND_DISPLAY not set"
    fi

    if [ -n "${XDG_CURRENT_DESKTOP:-}" ]; then
        pass "XDG_CURRENT_DESKTOP = $XDG_CURRENT_DESKTOP"
    else
        warn "XDG_CURRENT_DESKTOP not set"
    fi
else
    warn "labwc is not running"
fi

# Check labwc version
if command -v labwc >/dev/null 2>&1; then
    LABWC_VER=$(labwc --version 2>/dev/null | head -1)
    pass "labwc version: $LABWC_VER"
else
    warn "labwc binary not found in PATH"
fi
echo ""

# ============================================================
# Summary
# ============================================================
TOTAL=$((PASS + FAIL + WARN))
echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}PASS: ${PASS}${NC}  ${RED}FAIL: ${FAIL}${NC}  ${YELLOW}WARN: ${WARN}${NC}  ${DIM}TOTAL: ${TOTAL}${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"

if [ "$FAIL" -gt 0 ]; then
    echo -e "\n${RED}${BOLD}Issues found. Fix the FAIL items above before restarting labwc.${NC}"
    exit 1
elif [ "$WARN" -gt 0 ]; then
    echo -e "\n${YELLOW}${BOLD}All critical checks passed. Review WARN items if behavior seems off.${NC}"
    exit 0
else
    echo -e "\n${GREEN}${BOLD}All checks passed. Configuration is correct.${NC}"
    exit 0
fi
