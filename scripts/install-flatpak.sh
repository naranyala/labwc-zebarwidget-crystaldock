#!/bin/bash
# ==============================================================================
# script: install-flatpak.sh
# description: Install Flatpak and configure Flathub repository
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "\n${CYAN}==> $1${NC}"; }
pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; exit 1; }

info "Installing Flatpak package manager..."
if ! command -v flatpak &>/dev/null; then
    if command -v dnf &>/dev/null; then
        sudo dnf install -y flatpak
    elif command -v apt-get &>/dev/null; then
        sudo apt-get install -y flatpak
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm flatpak
    else
        echo "Could not determine system package manager to install Flatpak."
    fi
fi

if command -v flatpak &>/dev/null; then
    pass "Flatpak installed successfully!"
    info "Adding Flathub repository..."
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
    pass "Flathub repository added!"
else
    fail "Flatpak installation failed."
fi
