#!/bin/bash
# -------------------------------------------------------------------
# OCWS Widget Schema Validator
# Validates widget files for common issues:
# - Duplicate button/label names
# - Missing variable references
# - Broken PopUp references
# - Invalid CSS classes
# -------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WIDGET_DIR="${1:-$PROJECT_DIR/dotfiles/ocws}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

errors=0
warnings=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; ((errors++)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; ((warnings++)); }
info() { echo -e "  ${CYAN}ℹ${NC} $1"; }

echo "=== OCWS Widget Schema Validator ==="
echo ""
echo "Checking widgets in: $WIDGET_DIR"
echo ""

# ============================================================
# 1. Check all widget files exist
# ============================================================
echo "--- Widget Files ---"
widget_count=0
for widget in "$WIDGET_DIR"/*.widget; do
    [[ -f "$widget" ]] || continue
    ((widget_count++))
done
info "Found $widget_count widget files"

if [[ $widget_count -lt 20 ]]; then
    warn "Expected 20+ widgets, found $widget_count"
fi
echo ""

# ============================================================
# 2. Check for duplicate exported names
# ============================================================
echo "--- Duplicate Names ---"
declare -A name_files

for widget in "$WIDGET_DIR"/*.widget; do
    [[ -f "$widget" ]] || continue
    local_name=$(basename "$widget" .widget)
    
    # Check for button "name" { ... }
    while IFS= read -r line; do
        if [[ "$line" =~ button[[:space:]]+\"([^\"]+)\" ]]; then
            name="${BASH_REMATCH[1]}"
            key="${name}"
            if [[ -n "${name_files[$key]+x}" ]]; then
                fail "Duplicate button name '$name' in $(basename $widget) and ${name_files[$key]}"
            else
                name_files["$key"]="$(basename $widget)"
            fi
        fi
    done < "$widget"
    
    # Check for label { ... } with name
    while IFS= read -r line; do
        if [[ "$line" =~ label[[:space:]]+\"([^\"]+)\" ]]; then
            name="${BASH_REMATCH[1]}"
            key="${name}"
            if [[ -n "${name_files[$key]+x}" ]]; then
                warn "Duplicate label name '$name' in $(basename $widget) and ${name_files[$key]}"
            else
                name_files["$key"]="$(basename $widget)"
            fi
        fi
    done < "$widget"
done
echo ""

# ============================================================
# 3. Check PopUp references
# ============================================================
echo "--- PopUp References ---"
declare -A popup_defs
declare -A popup_refs

for widget in "$WIDGET_DIR"/*.widget; do
    [[ -f "$widget" ]] || continue
    wname=$(basename "$widget" .widget)
    
    # Find PopUp definitions
    while IFS= read -r line; do
        if [[ "$line" =~ PopUp[[:space:]]*\(\"([^\"]+)\" ]]; then
            popup_defs["${BASH_REMATCH[1]}"]="$wname"
        fi
    done < "$widget"
    
    # Find PopUp references (e.g., PopUp("Name") in action or trigger)
    while IFS= read -r line; do
        if [[ "$line" =~ PopUp[[:space:]]*\(\"([^\"]+)\" ]]; then
            popup_refs["${BASH_REMATCH[1]}"]="$wname"
        fi
    done < "$widget"
done

# Check that all referenced PopUps are defined
for ref in "${!popup_refs[@]}"; do
    if [[ -z "${popup_defs[$ref]+x}" ]]; then
        fail "PopUp '$ref' referenced in ${popup_refs[$ref]} but not defined"
    fi
done

info "Found ${#popup_defs[@]} PopUp definitions"
echo ""

# ============================================================
# 4. Check variable references
# ============================================================
echo "--- Variable References ---"
declare -A var_usage

for widget in "$WIDGET_DIR"/*.widget; do
    [[ -f "$widget" ]] || continue
    wname=$(basename "$widget" .widget)
    
    # Find X-prefixed variables
    while IFS= read -r var; do
        key="${var}"
        if [[ -z "${var_usage[$key]+x}" ]]; then
            var_usage["$key"]="$wname"
        fi
    done < <(grep -oP '\bX[A-Z][a-zA-Z0-9]+\b' "$widget" 2>/dev/null | sort -u)
done

info "Found ${#var_usage[@]} unique variable references"

# Check for variables used in only one widget (potential orphan)
for var in "${!var_usage[@]}"; do
    count=$(grep -rl "$var" "$WIDGET_DIR"/*.widget 2>/dev/null | wc -l)
    if [[ $count -eq 1 ]]; then
        warn "Variable '$var' only used in ${var_usage[$var]} (potential orphan)"
    fi
done
echo ""

# ============================================================
# 5. Check CSS class usage
# ============================================================
echo "--- CSS Class Usage ---"
declare -A css_classes

for widget in "$WIDGET_DIR"/*.widget; do
    [[ -f "$widget" ]] || continue
    wname=$(basename "$widget" .widget)
    
    # Find style = "class_name" references
    while IFS= read -r line; do
        if [[ "$line" =~ style[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
            css_classes["${BASH_REMATCH[1]}"]="$wname"
        fi
    done < "$widget"
done

info "Found ${#css_classes[@]} CSS class references"

# Check for common missing classes
for class in module module_pill text_widget text_clock text_media text_metric; do
    if [[ -z "${css_classes[$class]+x}" ]]; then
        warn "CSS class '$class' not used by any widget"
    fi
done
echo ""

# ============================================================
# 6. Check for common issues
# ============================================================
echo "--- Common Issues ---"

for widget in "$WIDGET_DIR"/*.widget; do
    [[ -f "$widget" ]] || continue
    wname=$(basename "$widget" .widget)
    
    # Check for ExecTerm (deprecated)
    if grep -q "ExecTerm" "$widget" 2>/dev/null; then
        fail "$wname: Uses deprecated ExecTerm (should use Exec)"
    fi
    
    # Check for unclosed braces
    open=$(grep -c "{" "$widget" 2>/dev/null || echo 0)
    close=$(grep -c "}" "$widget" 2>/dev/null || echo 0)
    if [[ $open -ne $close ]]; then
        warn "$wname: Mismatched braces ($open open, $close close)"
    fi
    
    # Check for empty button/label blocks
    if grep -q 'button[^{]*{\s*}' "$widget" 2>/dev/null; then
        warn "$wname: Empty button block detected"
    fi
done
echo ""

# ============================================================
# Summary
# ============================================================
echo "=== Results ==="
echo -e "  ${GREEN}Pass: $((widget_count))${NC}"
echo -e "  ${YELLOW}Warnings: $warnings${NC}"
echo -e "  ${RED}Errors: $errors${NC}"
echo ""

if [[ $errors -gt 0 ]]; then
    echo -e "${RED}Some widgets have errors. Fix them before deploying.${NC}"
    exit 1
elif [[ $warnings -gt 0 ]]; then
    echo -e "${YELLOW}Some warnings. OCWS will work but review recommended.${NC}"
    exit 0
else
    echo -e "${GREEN}All widgets pass validation!${NC}"
    exit 0
fi
