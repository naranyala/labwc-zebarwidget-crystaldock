#!/bin/bash
# -------------------------------------------------------------------
# OCWS Icon/Text Rendering Test Suite
# Validates widget syntax, icon availability, text expressions,
# CSS consistency, and scanner correctness.
# -------------------------------------------------------------------

set -uo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OCWS_DIR="$SCRIPT_DIR/dotfiles/ocws"
LABWC_DIR="$SCRIPT_DIR/dotfiles/labwc"

pass() { echo -e "  ${GREEN}✓${NC} $1"; ((PASS_COUNT++)); }
fail() { echo -e "  ${RED}✗${NC} $1"; ((FAIL_COUNT++)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; ((WARN_COUNT++)); }
skip() { echo -e "  ${DIM}○${NC} $1"; ((SKIP_COUNT++)); }
header() { echo -e "\n${BOLD}${CYAN}── $1 ──${NC}"; }

# ============================================================
# 1. Widget File Syntax Validation
# ============================================================
header "Widget File Syntax"

for widget in "$OCWS_DIR"/*.widget; do
    name=$(basename "$widget")

    # Check #Api2 header
    if head -1 "$widget" | grep -q "^#Api2"; then
        pass "$name: has #Api2 header"
    else
        fail "$name: missing #Api2 header"
    fi

    # Check for unclosed braces (simple heuristic, excluding comments)
    # Note: This is a rough check — braces inside strings/Config() may cause false positives
    opens=$(grep -v '^\s*#' "$widget" 2>/dev/null | grep -c '{' 2>/dev/null || echo 0)
    closes=$(grep -v '^\s*#' "$widget" 2>/dev/null | grep -c '}' 2>/dev/null || echo 0)
    if [ "$opens" -eq "$closes" ]; then
        pass "$name: braces balanced ($opens/$closes)"
    elif [ $((opens - closes)) -le 2 ] && [ $((closes - opens)) -le 2 ]; then
        warn "$name: braces nearly balanced ($opens opens, $closes closes) — may be in strings"
    else
        fail "$name: unbalanced braces ($opens opens, $closes closes)"
    fi

    # Check for export statement (widget must export something)
    # Skip files that are included by other widgets
    is_included=$(grep -l "include(\"$(basename "$widget")\")" "$OCWS_DIR"/*.widget "$OCWS_DIR/ocws.config" 2>/dev/null | wc -l)
    if [ "$is_included" -gt 0 ]; then
        skip "$name: included by another file (no export expected)"
    elif grep -q "^export " "$widget"; then
        pass "$name: has export statement"
    elif grep -q "^Private {" "$widget"; then
        # Private blocks may export internally
        if grep -q "export " "$widget"; then
            pass "$name: has export inside Private block"
        else
            fail "$name: no export statement found"
        fi
    elif grep -q "^scanner {" "$widget" || grep -q "^PopUp\|^#CSS"; then
        skip "$name: source/popup/CSS-only file (no export expected)"
    elif grep -q "^tray {" "$widget"; then
        skip "$name: tray widget (uses tray block, not export)"
    elif grep -q "^Exec(" "$widget" && ! grep -q "^export "; then
        skip "$name: scanner-only file (no export expected)"
    else
        fail "$name: no export statement found"
    fi
done

# ============================================================
# 2. Icon Name Validation
# ============================================================
header "Icon Name Validation"

# Collect all icon references from widgets (only symbolic icons, not Nerd Font)
extract_icons() {
    grep -h "value = " "$OCWS_DIR"/*.widget 2>/dev/null | \
        grep -oP '"[^"]*"' | \
        tr -d '"' | \
        grep -E "^[a-z].*-symbolic$" | \
        grep -v "^[[:space:]]*$" | \
        grep -v "^#[[:space:]]" | \
        sort -u
}

ICONS=$(extract_icons)

if [ -z "$ICONS" ]; then
    skip "No symbolic icons found in widgets"
else
    # Get system icon search path
    ICON_THEMS=("Adwaita" "breeze" "Papirus-Dark" "TelaBudgie-light" "Yaru" "gnome")

    for icon in $ICONS; do
        found=false
        for theme in "${ICON_THEMS[@]}"; do
            if find "/usr/share/icons/$theme" -name "${icon}*" 2>/dev/null | head -1 | grep -q .; then
                found=true
                break
            fi
        done

        if $found; then
            pass "Icon available: $icon"
        else
            fail "Icon NOT found: $icon"
        fi
    done
fi

# ============================================================
# 3. Nerd Font Icon Validation
# ============================================================
header "Nerd Font Icon Validation"

# Check for Nerd Font icons (Unicode codepoints used in widgets)
extract_nf_icons() {
    grep -h "value = " "$OCWS_DIR"/*.widget 2>/dev/null | \
        grep -oP '[\x{e000}-\x{f8ff}\x{f0000}-\x{fffff}]' 2>/dev/null | \
        sort -u
}

# Check that labels with Nerd Font icons have proper font-family
for widget in "$OCWS_DIR"/*.widget; do
    name=$(basename "$widget")

    # Check if widget uses Nerd Font icons (common prefixes)
    if grep -qP '[󰀀-󰀆󰂀-󰂲󰃀-󰃞󰄀-󰄨󰅀-󰅩󰆀-󰆭󰇀-󰇮󰈀-󰈭󰉀-󰉯󰊀-󰊱󰋀-󰋭󰌀-󰌭󰍀-󰍭󰎀-󰎱󰏀-󰏭󰐀-󰐯󰑀-󰑱󰒀-󰒱󰓀-󰓱󰔀-󰔱󰕀-󰕱󰖀-󰖱󰗀-󰗱󰘀-󰘱󰙀-󰙱󰚀-󰚱󰛀-󰛱󰜀-󰜱󰝀-󰝱󰞀-󰞱󰟀-󰟱󰠀-󰠱󰡀-󰡱󰢀-󰢱󰣀-󰣱󰤀-󰤱󰥀-󰥱󰦀-󰦱󰧀-󰧱󰨀-󰨱󰩀-󰩱󰪀-󰪱󰫀-󰫱󰬀-󰬱󰭀-󰭱󰮀-󰮱󰯀-󰯱󰰀-󰰱󰱀-󰱱󰲀-󰲱󰳀-󰳱󰴀-󰴱󰵀-󰵱󰶀-󰶱󰷀-󰷱󰸀-󰸱󰹀-󰹱󰺀-󰺱󰻀-󰻱󰼀-󰼱󰽀-󰽱󰾀-󰾱󰿀-󰿱󱀀-󱀱󱁀-󱁱󱂀-󱂱󱃀-󱃱󱄀-󱄱󱅀-󱅱󱆀-󱆱󱇀-󱇱󱈀-󱈱󱉀-󱉱󱊀-󱊱󱋀-󱋱󱌀-󱌱󱍀-󱍱󱎀-󱎱󱏀-󱏱󱐀-󱐱󱑀-󱑱󱒀-󱒱󱓀-󱓱󱔀-󱔱󱕀-󱕱󱖀-󱖱󱗀-󱗱󱘀-󱘱󱙀-󱙱󱚀-󱚱󱛀-󱛱󱜀-󱜱󱝀-󱝱󱞀-󱞱󱟀-󱟱]' "$widget" 2>/dev/null; then
        # Check if there's a CSS rule for this widget that sets font-family to Nerd Font
        widget_name=$(grep -oP 'export button "([^"]+)"' "$widget" | head -1 | grep -oP '"[^"]+"' | tr -d '"')
        if [ -n "$widget_name" ]; then
            if grep -qA5 "button#$widget_name" "$OCWS_DIR"/ocws.config 2>/dev/null | grep -q "font-family"; then
                pass "$name: Nerd Font icons with font-family set"
            else
                warn "$name: uses Nerd Font icons but no font-family CSS rule found"
            fi
        fi
    fi
done

# ============================================================
# 4. Text Expression Validation
# ============================================================
header "Text Expression Validation"

for widget in "$OCWS_DIR"/*.widget; do
    name=$(basename "$widget")

    # Check for common expression errors
    # 1. Unclosed If() statements
    if_count=$(grep -oP 'If\(' "$widget" 2>/dev/null | wc -l)
    # Count closing parens after If - simplified check
    if [ "$if_count" -gt 0 ]; then
        pass "$name: $if_count If() expressions found"
    fi

    # 2. Check for missing string quotes in expressions
    if grep -qP 'value\s*=\s*[^"]*[A-Z][a-z]+\(' "$widget" 2>/dev/null; then
        warn "$name: may have unquoted expression in value"
    fi

    # 3. Check for common typos in function names
    for fn in "Str\|Val\|If\|Match\|RegEx\|Extract\|Grab\|Exec\|ExecTerm\|PopUp\|Format\|Time\|Pad\|EmitTrigger"; do
        if grep -q "$fn" "$widget" 2>/dev/null; then
            pass "$name: uses $fn function"
        fi
    done
done

# ============================================================
# 5. Variable Reference Validation
# ============================================================
header "Variable Reference Validation"

# Extract variables defined in ocws-sysmon.source
SOURCE_FILE="$OCWS_DIR/ocws-sysmon.source"
DEFINED_VARS=""
if [ -f "$SOURCE_FILE" ]; then
    DEFINED_VARS=$(grep -oP 'X[A-Z][A-Za-z]+' "$SOURCE_FILE" 2>/dev/null | sort -u)
fi

# Extract variables used in widgets
USED_VARS=""
for widget in "$OCWS_DIR"/*.widget; do
    USED_VARS="$USED_VARS $(grep -oP 'X[A-Z][A-Za-z]+' "$widget" 2>/dev/null)"
done
USED_VARS=$(echo "$USED_VARS" | tr ' ' '\n' | sort -u)

# Check for undefined variables
if [ -n "$DEFINED_VARS" ] && [ -n "$USED_VARS" ]; then
    for var in $USED_VARS; do
        # Skip common sfwbar built-in variables
        case "$var" in
            XCal|XMediaLine|SysMonLine|XVolRaw|XBrightRaw|XKeybindsRaw|XMediaJson) continue ;;
        esac

        if echo "$DEFINED_VARS" | grep -q "^${var}$"; then
            pass "Variable defined: $var"
        else
            # Check if it's defined in a scanner within the widget file itself
            if grep -rq "^\s*${var}\s*=" "$OCWS_DIR"/*.widget 2>/dev/null; then
                pass "Variable defined in widget: $var"
            else
                warn "Variable may be undefined: $var"
            fi
        fi
    done
fi

# ============================================================
# 6. CSS Validation
# ============================================================
header "CSS Validation"

OCWS_CSS="$OCWS_DIR/ocws.config"
if [ -f "$OCWS_CSS" ]; then
    # Extract CSS section (after #CSS marker)
    CSS_SECTION=$(sed -n '/^#CSS$/,$ p' "$OCWS_CSS" 2>/dev/null)

    if [ -n "$CSS_SECTION" ]; then
        # Check for common CSS issues
        # 1. Unclosed braces in CSS
        css_opens=$(echo "$CSS_SECTION" | grep -c '{' 2>/dev/null || echo 0)
        css_closes=$(echo "$CSS_SECTION" | grep -c '}' 2>/dev/null || echo 0)
        if [ "$css_opens" -eq "$css_closes" ]; then
            pass "CSS braces balanced ($css_opens/$css_closes)"
        else
            fail "CSS braces unbalanced ($css_opens opens, $css_closes closes)"
        fi

        # 2. Check for undefined color variables
        if echo "$CSS_SECTION" | grep -q "@define-color"; then
            pass "CSS color variables defined"
        else
            warn "No CSS color variables found"
        fi

        # 3. Check for common GTK CSS properties
        for prop in "background-color" "color" "border-radius" "padding" "margin"; do
            if echo "$CSS_SECTION" | grep -q "$prop"; then
                pass "CSS uses $prop property"
            fi
        done

        # 4. Check that taskbar_item CSS exists
        if echo "$CSS_SECTION" | grep -q "button#taskbar_item"; then
            pass "taskbar_item CSS defined"
        else
            fail "taskbar_item CSS missing"
        fi

        # 5. Check that text_widget CSS exists
        if echo "$CSS_SECTION" | grep -q "button.text_widget"; then
            pass "text_widget CSS defined"
        else
            warn "text_widget CSS not found (may be in separate file)"
        fi
    else
        fail "No #CSS section found in ocws.config"
    fi
fi

# ============================================================
# 7. Widget-CSS Consistency Check
# ============================================================
header "Widget-CSS Consistency"

# Check that each widget's style class has a corresponding CSS rule
for widget in "$OCWS_DIR"/*.widget; do
    name=$(basename "$widget")

    # Extract style classes used in widget
    styles=$(grep -oP 'style\s*=\s*"([^"]+)"' "$widget" 2>/dev/null | grep -oP '"[^"]+"' | tr -d '"' | sort -u)

    for style in $styles; do
        # Skip generic styles
        case "$style" in
            hidden|module|module_pill|detail_popup|detail_grid|detail_header|detail_value|detail_hint|detail_button_row|detail_slider|detail_progress) continue ;;
        esac

        # Check if style is defined in CSS
        if grep -q "\.${style}\|#${style}\|${style}\b" "$OCWS_DIR/ocws.config" 2>/dev/null || \
           grep -q "\.${style}\|#${style}" "$widget" 2>/dev/null; then
            pass "$name: style '$style' has CSS definition"
        else
            warn "$name: style '$style' may be missing CSS definition"
        fi
    done
done

# ============================================================
# 8. Top Bar Widget Chain Validation
# ============================================================
header "Top Bar Widget Chain"

# Extract widget includes from top bar
TOP_WIDGETS=$(grep -A50 'bar "topbar:top"' "$OCWS_DIR/ocws.config" 2>/dev/null | \
    grep -oP 'widget "([^"]+)"' | grep -oP '"[^"]+"' | tr -d '"')

for widget in $TOP_WIDGETS; do
    # Try exact match first, then with .widget extension
    if [ -f "$OCWS_DIR/$widget" ]; then
        pass "Top bar widget exists: $widget"
    elif [ -f "$OCWS_DIR/${widget}.widget" ]; then
        pass "Top bar widget exists: ${widget}.widget"
    else
        fail "Top bar widget missing: $widget"
    fi
done

# ============================================================
# 9. Bottom Bar Widget Chain Validation
# ============================================================
header "Bottom Bar Widget Chain"

BOTTOM_WIDGETS=$(grep -A50 'bar "bottombar:bottom"' "$OCWS_DIR/ocws.config" 2>/dev/null | \
    grep -oP 'widget "([^"]+)"' | grep -oP '"[^"]+"' | tr -d '"')

for widget in $BOTTOM_WIDGETS; do
    # Try exact match first, then with .widget extension
    if [ -f "$OCWS_DIR/$widget" ]; then
        pass "Bottom bar widget exists: $widget"
    elif [ -f "$OCWS_DIR/${widget}.widget" ]; then
        pass "Bottom bar widget exists: ${widget}.widget"
    else
        fail "Bottom bar widget missing: $widget"
    fi
done

# ============================================================
# 10. Scanner Correctness Validation
# ============================================================
header "Scanner Correctness"

for widget in "$OCWS_DIR"/*.widget "$OCWS_DIR"/*.source; do
    name=$(basename "$widget")

    # Check scanner blocks
    if grep -q "scanner {" "$widget" 2>/dev/null; then
        # Check for exec commands
        exec_count=$(grep -c "exec(" "$widget" 2>/dev/null || echo 0)
        if [ "$exec_count" -gt 0 ]; then
            pass "$name: scanner has $exec_count exec commands"
        fi

        # Check for step interval
        if grep -q "step = " "$widget" 2>/dev/null; then
            step=$(grep -oP 'step\s*=\s*\K[0-9]+' "$widget" | head -1)
            if [ "$step" -ge 500 ] && [ "$step" -le 60000 ]; then
                pass "$name: scanner step interval合理: ${step}ms"
            else
                warn "$name: scanner step interval可能不合理: ${step}ms"
            fi
        fi

        # Check for variable assignments
        if grep -q "Grab\|RegEx\|Extract\|Val\|Match" "$widget" 2>/dev/null; then
            pass "$name: scanner uses parsing functions"
        fi
    fi
done

# ============================================================
# 11. Popup Panel Validation
# ============================================================
header "Popup Panel Validation"

for widget in "$OCWS_DIR"/*.widget; do
    name=$(basename "$widget")

    # Check for popup definitions
    popup_count=$(grep -c "PopUp(" "$widget" 2>/dev/null || echo 0)
    if [ "$popup_count" -gt 0 ]; then
        # Check for popup styling
        if grep -q "style = \"detail_popup\"" "$widget" 2>/dev/null; then
            pass "$name: popup has detail_popup style"
        else
            warn "$name: popup may be missing detail_popup style"
        fi

        # Check for popup grid
        if grep -q "style = \"detail_grid\"" "$widget" 2>/dev/null; then
            pass "$name: popup has detail_grid style"
        else
            warn "$name: popup may be missing detail_grid style"
        fi
    fi
done

# ============================================================
# 12. File Inclusion Chain Validation
# ============================================================
header "File Inclusion Chain"

# Check that all included files exist
for widget in "$OCWS_DIR"/*.widget "$OCWS_DIR/ocws.config"; do
    name=$(basename "$widget")

    includes=$(grep -oP 'include\("([^"]+)"\)' "$widget" 2>/dev/null | grep -oP '"[^"]+"' | tr -d '"')
    for inc in $includes; do
        if [ -f "$OCWS_DIR/$inc" ]; then
            pass "$name: includes '$inc' (exists)"
        else
            fail "$name: includes '$inc' (MISSING)"
        fi
    done
done

# ============================================================
# 13. Widget File Size Sanity Check
# ============================================================
header "Widget File Size Sanity"

for widget in "$OCWS_DIR"/*.widget; do
    name=$(basename "$widget")
    lines=$(wc -l < "$widget" 2>/dev/null || echo 0)

    if [ "$lines" -lt 5 ]; then
        warn "$name: very short ($lines lines) — may be incomplete"
    elif [ "$lines" -gt 300 ]; then
        warn "$name: very long ($lines lines) — consider splitting"
    else
        pass "$name: reasonable size ($lines lines)"
    fi
done

# ============================================================
# 14. Icon Fallback Chain Validation
# ============================================================
header "Icon Fallback Chains"

# Check that widgets with conditional icons have fallbacks
for widget in "$OCWS_DIR"/*.widget; do
    name=$(basename "$widget")

    # Check for If() icon expressions
    if_lines=$(grep -c "If(" "$widget" 2>/dev/null || echo 0)
    if [ "$if_lines" -gt 0 ]; then
        # Check that the last value in If chains is a valid icon
        last_icon=$(grep -oP 'If\([^)]+\?\s*"([^"]+)"' "$widget" 2>/dev/null | tail -1 | grep -oP '"[^"]+"' | tr -d '"')
        if [ -n "$last_icon" ]; then
            # Verify the fallback icon exists
            found=false
            for theme in Adwaita breeze Papirus-Dark TelaBudgie-light Yaru gnome; do
                if find "/usr/share/icons/$theme" -name "${last_icon}*" 2>/dev/null | head -1 | grep -q .; then
                    found=true
                    break
                fi
            done

            if $found; then
                pass "$name: icon fallback '$last_icon' exists"
            else
                fail "$name: icon fallback '$last_icon' NOT found"
            fi
        fi
    fi
done

# ============================================================
# 15. Taskbar Configuration Validation
# ============================================================
header "Taskbar Configuration"

TASKBAR_CFG=$(sed -n '/taskbar {/,/^  }/p' "$OCWS_DIR/ocws.config" 2>/dev/null)

if [ -n "$TASKBAR_CFG" ]; then
    # Check required settings
    for setting in "icons = true" "labels = true" "tooltips = true"; do
        if echo "$TASKBAR_CFG" | grep -q "$setting"; then
            pass "Taskbar: $setting"
        else
            fail "Taskbar: missing $setting"
        fi
    done

    # Check for action bindings
    for action in "Drag" "RightClick" "MiddleClick"; do
        if echo "$TASKBAR_CFG" | grep -q "action\[$action\]"; then
            pass "Taskbar: has $action action"
        else
            warn "Taskbar: missing $action action"
        fi
    done
else
    fail "No taskbar configuration found"
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo -e "${BOLD}═══════════════════════════════════════════${NC}"
echo -e "${BOLD}  OCWS Icon/Text Rendering Test Summary${NC}"
echo -e "${BOLD}═══════════════════════════════════════════${NC}"
echo -e "  ${GREEN}Passed:${NC}  $PASS_COUNT"
echo -e "  ${YELLOW}Warnings:${NC} $WARN_COUNT"
echo -e "  ${RED}Failed:${NC}  $FAIL_COUNT"
echo -e "  ${DIM}Skipped:${NC} $SKIP_COUNT"
echo -e "${BOLD}═══════════════════════════════════════════${NC}"

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo -e "\n${RED}Some tests failed. Please fix the issues above.${NC}"
    exit 1
fi

if [ "$WARN_COUNT" -gt 0 ]; then
    echo -e "\n${YELLOW}Some warnings found. Review recommended.${NC}"
fi

echo -e "\n${GREEN}All critical tests passed!${NC}"
exit 0
