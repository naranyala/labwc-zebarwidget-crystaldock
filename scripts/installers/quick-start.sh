#!/bin/bash
# quick-start.sh — One-command OCWS installer
# Usage: curl -fsSL <url>/quick-start.sh | bash
# Or: ./quick-start.sh

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║${NC}  ${CYAN}OCWS${NC} — Our C-Written Shell                          ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}  Pure C-native Wayland desktop environment              ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Detect distro
DISTRO="unknown"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO="${ID:-unknown}"
fi

echo -e "${BOLD}Detected: ${CYAN}${PRETTY_NAME:-$DISTRO}${NC}"
echo ""

# Check if we're in the OCWS directory
if [ ! -f "./install.sh" ]; then
    echo -e "${YELLOW}OCWS not found. Cloning...${NC}"
    git clone --depth=1 https://github.com/naranyala/labwc-fuzzel-zigshell-cairo-pango.git ocws
    cd ocws
fi

# Check core dependencies
echo -e "${BOLD}Checking dependencies...${NC}"
MISSING=()
for cmd in labwc zigshell-cairo-pango fuzzel foot; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING+=("$cmd")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo -e "\n${RED}Missing required packages: ${MISSING[*]}${NC}"
    echo ""
    echo -e "${BOLD}Install them first:${NC}"
    echo ""

    case "$DISTRO" in
        arch|manjaro|endeavouros|garuda)
            echo -e "  ${GREEN}sudo pacman -S labwc zigshell-cairo-pango fuzzel foot${NC}"
            ;;
        debian|ubuntu|linuxmint|pop)
            echo -e "  ${GREEN}sudo apt install labwc zigshell-cairo-pango fuzzel foot${NC}"
            ;;
        fedora)
            echo -e "  ${GREEN}sudo dnf install labwc zigshell-cairo-pango fuzzel foot${NC}"
            ;;
        opensuse*|suse)
            echo -e "  ${GREEN}sudo zypper install labwc zigshell-cairo-pango fuzzel foot${NC}"
            ;;
        alpine)
            echo -e "  ${GREEN}sudo apk add labwc zigshell-cairo-pango fuzzel foot${NC}"
            ;;
        void)
            echo -e "  ${GREEN}sudo xbps-install -S labwc zigshell-cairo-pango fuzzel foot${NC}"
            ;;
        *)
            echo -e "  ${YELLOW}sudo <your-pkg-manager> install labwc zigshell-cairo-pango fuzzel foot${NC}"
            ;;
    esac

    echo ""
    echo -e "Then run: ${GREEN}./quick-start.sh${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Core dependencies found${NC}"
echo ""

# Run the installer
echo -e "${BOLD}Starting OCWS installer...${NC}"
echo ""
exec bash ./install.sh "$@"
