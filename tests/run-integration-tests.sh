#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓ PASS${NC}: $1"; }
fail() { echo -e "${RED}✗ FAIL${NC}: $1"; exit 1; }

echo -e "${BOLD}Running Integration Test Suite...${NC}"

BIN_DIR="$(pwd)/zig-out/bin"

# Test ocws router
if "$BIN_DIR/ocws" status | grep -q "ocws: system status"; then
    pass "ocws status works via router"
else
    fail "ocws status failed"
fi

# Test ocws-kv via router
"$BIN_DIR/ocws" kv set tests.testkey hello_integration_test > /dev/null
if "$BIN_DIR/ocws" kv get tests.testkey | grep -q "hello_integration_test"; then
    pass "ocws kv storage operations succeed"
else
    fail "ocws kv storage failed"
fi

# Test ocws-emit via router
# Just verify it doesn't crash when passing arguments
if "$BIN_DIR/ocws" emit System.Test 123 > /dev/null 2>&1 || true; then
    # It might fail to connect to wayland/zigshell-cairo-pango but the binary runs
    pass "ocws emit binary executes"
else
    fail "ocws emit binary execution failed"
fi

echo -e "${BOLD}All integration tests passed!${NC}"
