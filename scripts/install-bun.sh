#!/bin/bash
# ==============================================================================
# script: install-bun.sh
# description: Install the Bun JavaScript runtime
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "\n${CYAN}==> $1${NC}"; }
pass() { echo -e "  ${GREEN}✓${NC} $1"; }

info "Installing 'bun' JavaScript runtime..."
if ! command -v bun &>/dev/null; then
    # Download and run the official installer script
    curl -fsSL https://bun.sh/install | bash
    pass "Bun runtime installed successfully!"
    echo "Note: Ensure ~/.bun/bin is added to your PATH in ~/.bashrc or ~/.zshrc."
else
    pass "Bun is already installed: $(command -v bun)"
fi
