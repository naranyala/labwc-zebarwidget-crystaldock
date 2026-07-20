#!/bin/bash
# ==============================================================================
# script: install-brew.sh
# description: Install the Homebrew Package Manager
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "\n${CYAN}==> $1${NC}"; }
pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; exit 1; }

info "Installing Homebrew package manager..."
if ! command -v brew &>/dev/null; then
    # Ensure dependencies for brew are installed
    if command -v dnf &>/dev/null; then
        sudo dnf install -y curl git gcc make
    elif command -v apt-get &>/dev/null; then
        sudo apt-get install -y build-essential procps curl file git
    fi

    # Install brew non-interactively
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Configure path for the current session
    BREW_PATH="/home/linuxbrew/.linuxbrew/bin/brew"
    if [ -x "$BREW_PATH" ]; then
        eval "$($BREW_PATH shellenv)"
        pass "Homebrew installed successfully!"
        
        # Add to bashrc/profile permanently
        if ! grep -q "brew shellenv" ~/.bashrc; then
            echo >> ~/.bashrc
            echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
            pass "Added brew shellenv to ~/.bashrc"
        fi
    else
        fail "Homebrew installation script finished, but executable not found."
    fi
else
    pass "Homebrew is already installed: $(command -v brew)"
fi
