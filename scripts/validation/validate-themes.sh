#!/bin/bash
# -------------------------------------------------------------------
# Theme Validator
# Validates theme INI files for consistency and completeness:
# - All themes have the same sections
# - Color values are valid hex format
# - Template variables are resolvable from INI keys
# -------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
THEMES_DIR="$PROJECT_DIR/themes"
TEMPLATES_DIR="$PROJECT_DIR/templates"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

errors=0
warnings=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; ((errors++)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; ((warnings++)); }
info() { echo -e "  ${CYAN}ℹ${NC} $1"; }

echo -e "${BOLD}=== Theme Validator ===${NC}"
echo ""

# ---------------------------------------------------------------
# 1. Theme files exist
# ---------------------------------------------------------------
echo -e "${BOLD}1. Theme files${NC}"

count=$(find "$THEMES_DIR" -name "*.ini" 2>/dev/null | wc -l)
if [[ $count -gt 0 ]]; then
    pass "$count theme files found"
else
    fail "No theme files found in $THEMES_DIR"
fi
echo ""

# ---------------------------------------------------------------
# 2. Section consistency
# ---------------------------------------------------------------
echo -e "${BOLD}2. Section consistency${NC}"

# Get sections from first theme as reference
ref_theme=$(find "$THEMES_DIR" -name "*.ini" | sort | head -1)
ref_name=$(basename "$ref_theme" .ini)
ref_sections=$(grep '^\[' "$ref_theme" | tr -d '[]' | tr '\n' ',' | sed 's/,$//')
info "Reference: $ref_name → [$ref_sections]"

for f in "$THEMES_DIR"/*.ini; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .ini)
    sections=$(grep '^\[' "$f" | tr -d '[]' | tr '\n' ',' | sed 's/,$//')

    if [[ "$sections" == "$ref_sections" ]]; then
        pass "$name: matches reference"
    else
        # Find what's different
        IFS=',' read -ra ref_arr <<< "$ref_sections"
        IFS=',' read -ra cur_arr <<< "$sections"
        for s in "${ref_arr[@]}"; do
            found=false
            for c in "${cur_arr[@]}"; do
                [[ "$c" == "$s" ]] && found=true && break
            done
            [[ "$found" == false ]] && fail "$name: missing section [$s]"
        done
    fi
done
echo ""

# ---------------------------------------------------------------
# 3. Color hex validation
# ---------------------------------------------------------------
echo -e "${BOLD}3. Color hex validation${NC}"

hex_ok=0
hex_bad=0

for f in "$THEMES_DIR"/*.ini; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .ini)

    # Get color values (lines with = in [colors] section, skip ${} refs)
    bad=$(awk '/^\[colors\]/{found=1;next} /^\[/{found=0} found && /^[a-zA-Z0-9_]+=#[^0-9a-fA-F]{6,}/{print}' "$f" | grep -v '\${' || true)
    if [[ -n "$bad" ]]; then
        while IFS= read -r line; do
            fail "$name: invalid color → $line"
            ((hex_bad++))
        done <<< "$bad"
    fi

    # Count valid hex colors
    good=$(awk '/^\[colors\]/{found=1;next} /^\[/{found=0} found && /^[a-zA-Z0-9_]+=#[0-9a-fA-F]{6}$/' "$f" | wc -l)
    hex_ok=$((hex_ok + good))
done

if [[ $hex_bad -eq 0 && $hex_ok -gt 0 ]]; then
    pass "$hex_ok color values are valid hex"
fi
echo ""

# ---------------------------------------------------------------
# 4. Template variable coverage
# ---------------------------------------------------------------
echo -e "${BOLD}4. Template variable coverage${NC}"

# Extract all {{VAR}} from templates
tmpl_vars=$(grep -ohP '\{\{[A-Z_][A-Z0-9_]+\}\}' "$TEMPLATES_DIR"/*.tmpl 2>/dev/null | sort -u | sed 's/[{}]//g')
tmpl_count=$(echo "$tmpl_vars" | wc -l)
info "$tmpl_count unique template variables"

# Check which are handled by engine
unresolved=0
while IFS= read -r var; do
    [[ -z "$var" ]] && continue
    case "$var" in
        THEME_NAME|COLOR_*|FONT_*|FOOT_*|ROFI_*|FUZZEL_*|MAKO_*|QT_*|GTK_*|XFT_*|CURSOR_*|CONTOUR_*|OCWS_*|ICON_THEME|MODULE_*|FONT_SIZE*|BG_ALPHA|SURFACE_ALPHA|BORDER_ALPHA|CORNER_RADIUS|THEMERC_*|BORDER_WIDTH|OSD_*|TITLEBAR_LAYOUT)
            ;;
        *)
            warn "Template variable {{$var}} may not be resolved by engine"
            ((unresolved++))
            ;;
    esac
done <<< "$tmpl_vars"

if [[ $unresolved -eq 0 ]]; then
    pass "All template variables have resolution paths"
fi
echo ""

# ---------------------------------------------------------------
# 5. Required keys check
# ---------------------------------------------------------------
echo -e "${BOLD}5. Required keys per section${NC}"

# Minimum required keys for critical sections
declare -A REQUIRED_KEYS=(
    [meta]="name description"
    [colors]="base text blue red green yellow"
    [labwc]="themerc_active_bg themerc_active_text themerc_inactive_bg themerc_inactive_text themerc_border"
    [gtk3]="gtk_theme icon_theme cursor_theme cursor_size"
)

for section in "${!REQUIRED_KEYS[@]}"; do
    required="${REQUIRED_KEYS[$section]}"
    for f in "$THEMES_DIR"/*.ini; do
        [[ -f "$f" ]] || continue
        name=$(basename "$f" .ini)

        # Extract keys for this section using awk
        section_keys=$(awk "/^\[$section\]/{found=1;next} /^\[/{found=0} found && /^([a-zA-Z0-9_]+)=/{gsub(/=.*/,\"\"); print}" "$f")

        for key in $required; do
            if ! echo "$section_keys" | grep -qw "$key"; then
                fail "$name: [$section] missing required key '$key'"
            fi
        done
    done
done
pass "Required key check complete"
echo ""

# ---------------------------------------------------------------
# Summary
# ---------------------------------------------------------------
echo -e "${BOLD}=== Summary ===${NC}"
echo -e "  Errors:   ${errors}"
echo -e "  Warnings: ${warnings}"
echo ""

[[ $errors -eq 0 ]] && echo -e "${GREEN}${BOLD}All themes valid!${NC}" || echo -e "${RED}${BOLD}Theme validation failed${NC}"
exit $errors
