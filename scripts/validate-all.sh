#!/bin/bash
# -------------------------------------------------------------------
# OCWS Unified Validator
# Runs all validators and provides a summary report.
#
# Usage:
#   validate-all              Run all validators
#   validate-all --quick      Run fast validators only (themes, build)
#   validate-all <name>       Run specific validator (themes|build|widgets|zigshell-cairo-pango|contract)
# -------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         OCWS Unified Validator                   ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""

run_one() {
    local name="$1"
    local script="$SCRIPT_DIR/validate-${name}.sh"

    if [[ ! -f "$script" ]]; then
        echo -e "${YELLOW}⚠ $name: validator not found${NC}"
        return 1
    fi

    echo -e "${BOLD}━━━ $name ━━━${NC}"
    bash "$script" 2>&1
    local rc=$?
    echo ""
    return $rc
}

# Parse args
specific="${1:-}"

if [[ -n "$specific" && "$specific" != "--quick" ]]; then
    run_one "$specific"
    exit $?
fi

# Run validators
failed=0
for v in themes build widgets zigshell-cairo-pango contract; do
    if [[ "$specific" == "--quick" && "$v" != "themes" && "$v" != "build" ]]; then
        continue
    fi
    run_one "$v" || ((failed++))
done

# Summary
echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
if [[ $failed -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}All validators passed!${NC}"
else
    echo -e "${RED}${BOLD}$failed validator(s) failed${NC}"
    exit 1
fi
