#!/bin/bash
#
# labwc-theme — Switch labwc compositor theme with live reload
#
# Usage:
#   labwc-theme                  List available themes (current highlighted)
#   labwc-theme <name>           Apply labwc theme (themerc-override + environment + rc.xml)
#   labwc-theme next             Cycle to next theme
#   labwc-theme prev             Cycle to previous theme
#   labwc-theme current          Show active theme
#   labwc-theme preview <name>   Preview labwc-specific outputs
#   labwc-theme random           Apply a random theme
#
# Only touches labwc surfaces: themerc-override, environment, rc.xml.
# Does NOT touch GTK, zigshell-cairo-pango, rofi, fuzzel, or other apps.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find project root
PROJECT_DIR=""
_candidate="$SCRIPT_DIR"
while [[ "$_candidate" != "/" ]]; do
    if [[ -d "$_candidate/themes" ]]; then
        PROJECT_DIR="$_candidate"
        break
    fi
    _candidate="$(dirname "$_candidate")"
done

[[ -d "$PROJECT_DIR/themes" ]] || { echo "Cannot find themes/ directory" >&2; exit 1; }
THEMES_DIR="$PROJECT_DIR/themes"
CURRENT_FILE="$HOME/.config/labwc/.current-theme"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

pass()  { echo -e "  ${GREEN}✓${NC} $1"; }
info()  { echo -e "  ${CYAN}→${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }

get_themes() {
    for f in "$THEMES_DIR"/*.ini; do
        [[ -f "$f" ]] || continue
        basename "$f" .ini
    done | sort
}

get_current() {
    if [[ -f "$CURRENT_FILE" ]]; then
        cat "$CURRENT_FILE"
    else
        echo "none"
    fi
}

reload_labwc() {
    if pidof labwc &>/dev/null; then
        kill -SIGHUP "$(pidof labwc)" 2>/dev/null && \
            pass "labwc reloaded (SIGHUP)" || warn "Failed to signal labwc"
    else
        warn "labwc not running — restart to apply"
    fi
}

apply_theme() {
    local name="$1"
    local theme_file="$THEMES_DIR/${name}.ini"

    if [[ ! -f "$theme_file" ]]; then
        echo -e "${RED}✗ Theme not found: $name${NC}"
        echo "Available themes:"
        get_themes | sed 's/^/  /'
        exit 1
    fi

    echo -e "${BOLD}Applying labwc theme: $name${NC}"
    echo ""

    # Apply labwc-only surfaces
    LABWC_PROJECT="$PROJECT_DIR" bash "$SCRIPT_DIR/theme-engine.sh" apply "$theme_file" --labwc-only

    # Track current theme
    mkdir -p "$(dirname "$CURRENT_FILE")"
    echo "$name" > "$CURRENT_FILE"

    echo ""
    # Reload labwc
    reload_labwc

    echo ""
    echo -e "${GREEN}${BOLD}Labwc theme: $name${NC}"
}

next_theme() {
    local current
    current=$(get_current)
    local themes=()
    while IFS= read -r t; do
        themes+=("$t")
    done < <(get_themes)

    [[ ${#themes[@]} -gt 0 ]] || { echo "No themes found" >&2; exit 1; }

    local idx=0
    for i in "${!themes[@]}"; do
        if [[ "${themes[$i]}" == "$current" ]]; then
            idx=$i
            break
        fi
    done

    local next_idx=$(( (idx + 1) % ${#themes[@]} ))
    apply_theme "${themes[$next_idx]}"
}

prev_theme() {
    local current
    current=$(get_current)
    local themes=()
    while IFS= read -r t; do
        themes+=("$t")
    done < <(get_themes)

    [[ ${#themes[@]} -gt 0 ]] || { echo "No themes found" >&2; exit 1; }

    local idx=0
    for i in "${!themes[@]}"; do
        if [[ "${themes[$i]}" == "$current" ]]; then
            idx=$i
            break
        fi
    done

    local prev_idx=$(( (idx - 1 + ${#themes[@]}) % ${#themes[@]} ))
    apply_theme "${themes[$prev_idx]}"
}

random_theme() {
    local themes=()
    while IFS= read -r t; do
        themes+=("$t")
    done < <(get_themes)

    [[ ${#themes[@]} -gt 0 ]] || { echo "No themes found" >&2; exit 1; }

    local idx=$(( RANDOM % ${#themes[@]} ))
    apply_theme "${themes[$idx]}"
}

# Main
case "${1:-}" in
    list|"")
        echo -e "${BOLD}Labwc themes:${NC}"
        echo ""
        current_theme=$(get_current)
        while IFS= read -r name; do
            desc=$(grep -m1 '^description=' "$THEMES_DIR/${name}.ini" 2>/dev/null | cut -d= -f2- | xargs)
            if [[ "$name" == "$current_theme" ]]; then
                echo -e "  ${GREEN}●${NC} $name ${CYAN}(active)${NC}  ${DIM}${desc:-}${NC}"
            else
                echo -e "  ${DIM}○${NC} $name  ${DIM}${desc:-}${NC}"
            fi
        done < <(get_themes)
        echo ""
        echo "Usage: labwc-theme <name> | labwc-theme next | labwc-theme prev"
        ;;
    current)
        echo "Active labwc theme: $(get_current)"
        ;;
    next)
        next_theme
        ;;
    prev)
        prev_theme
        ;;
    random)
        random_theme
        ;;
    preview)
        [[ -n "${2:-}" ]] || { echo "Usage: labwc-theme preview <name>" >&2; exit 1; }
        LABWC_PROJECT="$PROJECT_DIR" bash "$SCRIPT_DIR/theme-engine.sh" preview "$THEMES_DIR/${2}.ini" 2>&1 | \
            sed -n '/^=== themerc-override.tmpl ===$/,/^---$/p; /^=== environment.tmpl ===$/,/^---$/p'
        ;;
    *)
        apply_theme "$1"
        ;;
esac
