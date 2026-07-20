#!/bin/bash
# ==============================================================================
# script: install-nodejs.sh
# description: Install NodeJS runtime via NVM (Node Version Manager)
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "\n${CYAN}==> $1${NC}"; }
pass() { echo -e "  ${GREEN}✓${NC} $1"; }

info "Installing Node.js runtime via NVM..."
if ! command -v node &>/dev/null; then
    # Install NVM
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    
    # Load NVM for the current session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Install latest stable node and set as default
    nvm install node
    nvm alias default node
    
    pass "Node.js runtime installed successfully!"
else
    pass "Node.js is already installed: $(command -v node) (v$(node -v))"
fi
