#!/usr/bin/env bash
# run-unit-tests.sh — Run all C unit tests for libocws header-only libraries
#
# Usage: bash tests/unit/run-unit-tests.sh
#        zig build test-unit
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BIN_DIR="${PROJECT_DIR}/zig-out/bin"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

passed=0
failed=0
skipped=0
total=0

run_test() {
    local name="$1"
    local binary="$BIN_DIR/$name"
    total=$((total + 1))

    if [ ! -f "$binary" ]; then
        # Try building it first
        (cd "$PROJECT_DIR" && zig build "$name" 2>/dev/null) || true
    fi

    if [ ! -f "$binary" ]; then
        printf "  ${YELLOW}SKIP${NC}  %s (binary not found)\n" "$name"
        skipped=$((skipped + 1))
        return
    fi

    if output=$("$binary" 2>&1); then
        # Extract result line
        result=$(echo "$output" | grep "Results:" | head -1)
        printf "  ${GREEN}PASS${NC}  %s — %s\n" "$name" "$result"
        passed=$((passed + 1))
    else
        result=$(echo "$output" | grep "Results:" | head -1)
        printf "  ${RED}FAIL${NC}  %s — %s\n" "$name" "$result"
        # Show failing tests
        echo "$output" | grep "\[FAIL\]" | head -5 | sed 's/^/        /'
        failed=$((failed + 1))
    fi
}

echo "═══════════════════════════════════════════════════════════"
echo " OCWS C Unit Tests — libocws header-only libraries"
echo "═══════════════════════════════════════════════════════════"
echo

run_test "test-unit-string"
run_test "test-unit-ini"
run_test "test-unit-json"
run_test "test-unit-procfs"
run_test "test-unit-easing"
run_test "test-unit-log"
run_test "test-unit-cli-common"
run_test "test-unit-security"

echo
echo "═══════════════════════════════════════════════════════════"
printf " Results: ${GREEN}%d passed${NC}, ${RED}%d failed${NC}, %d skipped out of %d total\n" \
    "$passed" "$failed" "$skipped" "$total"
echo "═══════════════════════════════════════════════════════════"

[ "$failed" -eq 0 ] && exit 0 || exit 1
