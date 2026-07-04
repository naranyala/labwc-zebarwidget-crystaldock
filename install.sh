#!/bin/bash
# -------------------------------------------------------------------
# OCWS Installer
# Enhanced distribution-aware installer for OCWS ecosystem.
# For comprehensive distro-specific installation, use ./install-distribution.sh
# -------------------------------------------------------------------

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "\n${CYAN}==>${NC} $*"; }
pass() { echo -e "  ${GREEN}✓${NC} $*"; }
fail() { echo -e "  ${RED}✗${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info "Initializing OCWS Deployment..."

# 1. Check for comprehensive distro-specific installer
if [ -f "${SCRIPT_DIR}/install-distribution.sh" ]; then
    echo -e "\n  ${GREEN}✓${NC} Enhanced distro-specific installer found."
    echo -e "  ${CYAN}=== OCWS Installer ===${NC}"
    echo -e "  ${CYAN}  Quick Mode:${NC} All manual config steps"
    echo -e "  ${CYAN}  Full Mode:${NC}  Automatic package installation"
    echo -e "\n  Choose option:"
    echo -e "    1) Quick Install (manual dependency setup)"
    echo -e "    2) Full Install (automatic distro detection and package installation)"
    echo -e "\n  Default: 1 (Quick Install)"
    echo -n "    Enter choice [1-2]: "
    
    read -r choice
    
    case "${choice:-1}" in
        2)
            echo -e "\n${CYAN}==>${NC} Starting comprehensive distribution installer..."
            bash "${SCRIPT_DIR}/install-distribution.sh" "$@"
            exit 0
            ;;
        *)
            echo -e "\n${CYAN}==>${NC} Starting quick installer..."
            ;;
    esac
fi

# -------------------------------------------------------------------
# Legacy Quick Installer
# Manual dependency installation and configuration deployment
# -------------------------------------------------------------------

# 1. Dependency Check
info "Checking for required dependencies..."
if ! command -v labwc >/dev/null 2>&1 || ! command -v sfwbar >/dev/null 2>&1 || ! command -v fuzzel >/dev/null 2>&1; then
    echo -e "\n${YELLOW}⚠${NC} Core engines (labwc, sfwbar, fuzzel) are missing!"
    echo -e "  ${RED}Options:${NC}"
    echo -e "    1) Install via package manager (${SCRIPT_DIR}/install-distribution.sh)"
    echo -e "    2) Build from source (${SCRIPT_DIR}/build-ocws-core.sh all)"
    echo -e "\n  Press [ENTER] to continue anyway, or Ctrl+C to cancel."
    read -r
fi

# 2. Setup Directories
info "Setting up configuration directories..."
mkdir -p ~/.config/labwc
mkdir -p ~/.config/ocws/plugins
mkdir -p ~/.config/fuzzel
mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0
mkdir -p ~/.local/bin/actions
pass "Directories created."

# 3. Deploy Labwc Core
info "Deploying Compositor Rules (labwc)..."
cp -r "$SCRIPT_DIR/dotfiles/labwc/"* ~/.config/labwc/ 2>/dev/null || fail "Failed to deploy labwc configurations"
pass "labwc configurations synced."

# 4. Deploy OCWS Shell
info "Deploying the OCWS Shell..."
cp -r "$SCRIPT_DIR/dotfiles/ocws/"* ~/.config/ocws/ 2>/dev/null || fail "Failed to deploy OCWS shell"
pass "OCWS layout and plugins synced."

# 5. Deploy Fuzzel Launcher
if [ -d "$SCRIPT_DIR/dotfiles/fuzzel" ]; then
    info "Deploying Application Launcher (fuzzel)..."
    cp -r "$SCRIPT_DIR/dotfiles/fuzzel/"* ~/.config/fuzzel/ 2>/dev/null || fail "Failed to deploy fuzzel configuration"
    pass "Fuzzel synced."
fi

# 6. Deploy GTK Styling
if [ -d "$SCRIPT_DIR/dotfiles/gtk" ]; then
    info "Deploying GTK Preferences..."
    cp -r "$SCRIPT_DIR/dotfiles/gtk/"* ~/.config/gtk-3.0/ 2>/dev/null || true
    cp -r "$SCRIPT_DIR/dotfiles/gtk/"* ~/.config/gtk-4.0/ 2>/dev/null || true
    pass "GTK settings synced."
fi

# 7. Deploy IPC & Core Tools
info "Deploying Event Bus API & System Tools..."
find "$SCRIPT_DIR/scripts" -maxdepth 1 -type f -name "*.sh" -exec cp {} ~/.local/bin/ \; 2>/dev/null || fail "Failed to deploy scripts"
if [ -d "$SCRIPT_DIR/scripts/actions" ]; then
    cp "$SCRIPT_DIR/scripts/actions/"* ~/.local/bin/actions/ 2>/dev/null || true
fi
chmod +x ~/.local/bin/*.sh 2>/dev/null || fail "Failed to set execute permissions on scripts"
chmod +x ~/.local/bin/actions/* 2>/dev/null || true
pass "Scripts and IPC mapped to ~/.local/bin"

# 8. Success
info "OCWS Deployment Complete! 🚀"
echo "\n${CYAN}=== Quick Install Complete ===${NC}"
echo "${CYAN}  Note:${NC} You must manually install labwc, sfwbar, and fuzzel first."
echo "  Use ./install-distribution.sh for automatic distro detection and installation."
echo "\n${CYAN}  Next Steps:${NC}"
echo "  • Install dependencies using: ./install-distribution.sh (Recommended)"
echo "  • Build from source: ./build-ocws-core.sh all"
echo "  • Restart and select 'labwc' from display manager"
echo "  • Or run: labwc (from a TTY)"
