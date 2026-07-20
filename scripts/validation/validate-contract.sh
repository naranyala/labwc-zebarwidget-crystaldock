#!/bin/bash
# -------------------------------------------------------------------
# OCWS Contract Validator
# Validates that emit script and widgets match the variable contract
# -------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTRACT="$PROJECT_DIR/contracts/variables.ini"
EMIT_SCRIPT="$PROJECT_DIR/src/ocws-emit.c"
WIDGET_DIR="$PROJECT_DIR/dotfiles/ocws"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

errors=0
warnings=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; ((errors++)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; ((warnings++)); }

echo "=== OCWS Contract Validator ==="
echo ""

# 1. Check contract file exists
echo "--- Contract File ---"
if [[ -f "$CONTRACT" ]]; then
    pass "Contract found: $CONTRACT"
else
    fail "Contract not found: $CONTRACT"
    echo "  Create contracts/variables.ini first."
    exit 1
fi

# 2. Extract emit variables from contract
echo ""
echo "--- Emit Script vs Contract ---"
declare -A contract_vars
while IFS= read -r line; do
    if [[ "$line" =~ ^\[(.*)\]$ ]]; then
        section="${BASH_REMATCH[1]}"
        if [[ "$section" == internal* ]]; then
            is_internal=1
        else
            is_internal=0
        fi
    elif [[ "$line" =~ emit_name[[:space:]]*=[[:space:]]*(.+)$ ]]; then
        var="${BASH_REMATCH[1]}"
        if [[ "${is_internal:-0}" -eq 0 ]]; then
            contract_vars["$var"]=1
        fi
    fi
done < "$CONTRACT"

# Check emit script has all contract variables
while IFS= read -r line; do
    if [[ "$line" =~ return[[:space:]]*\"([^\"]+)\" ]]; then
        var="${BASH_REMATCH[1]}"
        # Skip the catch-all passthrough and variable references
        [[ "$var" == '\$'* || "$var" == *'$'* ]] && continue
        if [[ -z "${contract_vars[$var]+x}" ]]; then
            fail "Emit script has '$var' but it's NOT in the contract"
        fi
    fi
done < "$EMIT_SCRIPT"

# Check contract variables are in emit script
for var in "${!contract_vars[@]}"; do
    if ! grep -q "return \"$var\"" "$EMIT_SCRIPT" 2>/dev/null; then
        fail "Contract declares '$var' but emit script doesn't map it"
    fi
done

# 3. Check widgets use contract variables
echo ""
echo "--- Widget Variables vs Contract ---"
while IFS= read -r line; do
    if [[ "$line" =~ emit_name[[:space:]]*=[[:space:]]*(.+)$ ]]; then
        var="${BASH_REMATCH[1]}"
        # Check if any widget references this variable
        count=$(grep -rl "$var" "$WIDGET_DIR"/*.widget 2>/dev/null | wc -l)
        if [[ $count -eq 0 ]]; then
            warn "Variable '$var' is in contract but no widget references it"
        fi
    fi
done < "$CONTRACT"

# 4. Check for undeclared variables in widgets
echo ""
echo "--- Undeclared Widget Variables ---"
declare -A contract_names
while IFS= read -r line; do
    if [[ "$line" =~ emit_name[[:space:]]*=[[:space:]]*(.+)$ ]]; then
        contract_names["${BASH_REMATCH[1]}"]=1
    fi
done < "$CONTRACT"

# Also add variables defined by scanners (not via IPC)
scanner_vars="XNetRateRx XNetRateTx XNetTotal XTemp XUptimeH XUptimeM XLoad1 XLoad5 XLoad15 XProcTotal XProcRunning XSwapPct XMemUsedMB XMemTotalMB XBrightness"
for v in $scanner_vars; do
    contract_names["$v"]=1
done

# Check each widget for X-prefixed variables not in contract
for widget in "$WIDGET_DIR"/*.widget; do
    [[ -f "$widget" ]] || continue
    while IFS= read -r var; do
        if [[ -z "${contract_names[$var]+x}" ]]; then
            warn "Widget '$(basename "$widget")' uses '$var' which is not in the contract"
        fi
    done < <(grep -oP '\bX[A-Z][a-zA-Z0-9]+\b' "$widget" 2>/dev/null | sort -u)
done

echo ""
echo "=== Results: $errors errors, $warnings warnings ==="
[[ $errors -eq 0 ]] && exit 0 || exit 1
