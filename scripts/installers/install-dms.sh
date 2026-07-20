#!/bin/bash
# -------------------------------------------------------------------
# DankMaterialShell (DMS) Installer
#
# Downloads, builds, and installs DMS from source.
# Checks all requirements before building.
#
# Requirements:
#   - quickshell (must be installed first)
#   - Qt6 QML/Quick development packages
#   - make, g++, pkg-config
#   - Wayland compositor (labwc, hyprland, sway, etc.)
# -------------------------------------------------------------------

set -eo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "\n${CYAN}==>${NC} $*"; }
pass()  { echo -e "  ${GREEN}✓${NC} $*"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $*"; }
fail()  { echo -e "  ${RED}✗${NC} $*"; exit 1; }

DMS_REPO="https://github.com/DankShrine/dms.git"
SRC_DIR="$HOME/sources"
DMS_SRC="$SRC_DIR/dms"
PREFIX="${PREFIX:-/usr/local}"

# ===================================================================
# Check requirements
# ===================================================================
check_requirements() {
    info "Checking requirements..."

    local errors=0

    # 1. quickshell (critical — DMS won't run without it)
    if command -v quickshell >/dev/null 2>&1; then
        local qs_ver
        qs_ver=$(quickshell --version 2>&1 | head -1 || echo "unknown")
        pass "quickshell: $qs_ver"
    else
        fail "quickshell not found. Build it first:
  See: ./install-quickshell.sh
  Or:  https://github.com/quickshell-mirror/quickshell"
    fi

    # 2. Build tools
    for cmd in make g++ pkg-config git; do
        if command -v "$cmd" >/dev/null 2>&1; then
            pass "$cmd: $(command -v "$cmd")"
        else
            warn "$cmd: NOT FOUND (needed for build)"
            errors=$((errors + 1))
        fi
    done

    # 3. Qt6 QML/Quick (needed to run DMS)
    if pkg-config --exists Qt6Core Qt6Gui Qt6Qml Qt6Quick 2>/dev/null; then
        pass "Qt6 QML/Quick: $(pkg-config --modversion Qt6Core 2>/dev/null || echo 'found')"
    elif [ -f /usr/lib64/cmake/Qt6/Qt6Config.cmake ] || [ -f /usr/lib/cmake/Qt6/Qt6Config.cmake ]; then
        pass "Qt6: found via cmake"
    else
        warn "Qt6 QML/Quick packages may be missing"
        warn "Install: sudo dnf install lib64Qt6Core-devel lib64Qt6Qml-devel lib64Qt6Quick-devel"
        errors=$((errors + 1))
    fi

    # 4. Wayland compositor
    local compositor=""
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        compositor="running (WAYLAND_DISPLAY=$WAYLAND_DISPLAY)"
    elif command -v labwc >/dev/null 2>&1; then
        compositor="labwc installed"
    elif command -v hyprland >/dev/null 2>&1; then
        compositor="hyprland installed"
    elif command -v sway >/dev/null 2>&1; then
        compositor="sway installed"
    else
        warn "No Wayland compositor detected (not fatal — DMS needs one at runtime)"
        compositor="not found"
    fi
    pass "Wayland compositor: $compositor"

    # 5. dms binary (check if already installed)
    if command -v dms >/dev/null 2>&1; then
        local dms_ver
        dms_ver=$(dms --version 2>&1 | head -1 || echo "unknown")
        warn "DMS already installed: $dms_ver"
        echo -e "    Will be overwritten by new build."
    fi

    # 6. DMS config directories
    if [ -d "$HOME/.local/share/quickshell/dms" ]; then
        pass "DMS data dir exists: ~/.local/share/quickshell/dms/"
    fi
    if [ -L "$HOME/.config/quickshell/dms" ]; then
        pass "DMS config symlink exists: ~/.config/quickshell/dms"
    fi

    if [ "$errors" -gt 0 ]; then
        echo ""
        warn "$errors requirement(s) missing. Build may fail."
        echo -n "  Continue anyway? [y/N]: "
        read -r cont
        [[ "$cont" =~ ^[Yy]$ ]] || exit 1
    fi

    pass "Requirements check complete."
}

# ===================================================================
# Clone or update DMS source
# ===================================================================
fetch_dms() {
    info "Fetching DMS source..."

    mkdir -p "$SRC_DIR"

    if [ -d "$DMS_SRC/.git" ]; then
        cd "$DMS_SRC"
        local before
        before=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        git fetch origin
        git reset --hard origin/HEAD 2>/dev/null || git reset --hard origin/master 2>/dev/null || true
        local after
        after=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        if [ "$before" = "$after" ]; then
            pass "DMS already up to date ($after)."
        else
            pass "DMS updated: $before → $after"
        fi
    else
        rm -rf "$DMS_SRC"
        git clone --depth=1 "$DMS_REPO" "$DMS_SRC"
        cd "$DMS_SRC"
        pass "DMS cloned ($(git rev-parse --short HEAD))."
    fi
}

# ===================================================================
# Build DMS
# ===================================================================
build_dms() {
    info "Building DMS..."
    cd "$DMS_SRC"

    # Clean previous build artifacts
    make clean 2>/dev/null || true

    make -j$(nproc) 2>&1 || {
        warn "Parallel build failed, trying single-threaded..."
        make -j1
    }

    pass "DMS built successfully."
}

# ===================================================================
# Install DMS
# ===================================================================
install_dms() {
    info "Installing DMS..."
    cd "$DMS_SRC"

    if [ "$(id -u)" -eq 0 ]; then
        make install
    elif command -v sudo >/dev/null 2>&1; then
        sudo make install
    elif command -v pkexec >/dev/null 2>&1; then
        pkexec make install
    else
        fail "Cannot install — no sudo/pkexec and not running as root."
    fi

    pass "DMS installed to $PREFIX/bin/dms"
}

# ===================================================================
# Deploy DMS configuration
# ===================================================================
deploy_config() {
    info "Deploying DMS configuration..."

    local DMS_DATA="$HOME/.local/share/quickshell/dms"
    local DMS_CONFIG="$HOME/.config/quickshell/dms"

    # Create directories
    mkdir -p "$DMS_DATA"
    mkdir -p "$HOME/.config/quickshell"

    # Create symlink if it doesn't exist
    if [ ! -e "$DMS_CONFIG" ]; then
        ln -sf "$DMS_DATA" "$DMS_CONFIG"
        pass "Created symlink: ~/.config/quickshell/dms → ~/.local/share/quickshell/dms"
    elif [ -L "$DMS_CONFIG" ]; then
        local target
        target=$(readlink -f "$DMS_CONFIG" 2>/dev/null || echo "unknown")
        if [ "$target" = "$DMS_DATA" ]; then
            pass "Symlink already correct."
        else
            rm -f "$DMS_CONFIG"
            ln -sf "$DMS_DATA" "$DMS_CONFIG"
            pass "Updated symlink: ~/.config/quickshell/dms → ~/.local/share/quickshell/dms"
        fi
    else
        warn "~/.config/quickshell/dms exists and is not a symlink."
        echo "    Manual intervention may be needed."
    fi

    # Check for shell.qml
    if [ -f "$DMS_DATA/shell.qml" ]; then
        pass "shell.qml found in data dir."
    else
        warn "shell.qml not found in $DMS_DATA/"
        echo "    DMS may have installed QML files elsewhere."
        echo "    Check: find ~/.local/share/quickshell -name 'shell.qml'"
    fi

    # Fix AppId pragma if needed
    if [ -f "$DMS_DATA/shell.qml" ]; then
        if grep -q '//@ pragma AppId' "$DMS_DATA/shell.qml" 2>/dev/null; then
            info "Fixing AppId pragma (not supported by all quickshell versions)..."
            sed -i 's|^//@ pragma AppId|// //@ pragma AppId|' "$DMS_DATA/shell.qml"
            pass "AppId pragma commented out."
        fi
    fi

    # Deploy OCWS settings if available
    local OCWS_SETTINGS="$SCRIPT_DIR/dotfiles/DankMaterialShell/settings.json"
    if [ -f "$OCWS_SETTINGS" ]; then
        if [ ! -f "$DMS_DATA/settings.json" ]; then
            cp "$OCWS_SETTINGS" "$DMS_DATA/settings.json"
            pass "Deployed OCWS default settings."
        else
            pass "DMS settings.json already exists (not overwritten)."
        fi
    fi
}

# ===================================================================
# Verify installation
# ===================================================================
verify() {
    info "Verifying installation..."

    local ok=true

    # Check binary
    if command -v dms >/dev/null 2>&1; then
        local ver
        ver=$(dms --version 2>&1 | head -1 || echo "installed")
        pass "dms binary: $ver"
    else
        fail "dms binary not found after install."
    fi

    # Check quickshell
    if command -v quickshell >/dev/null 2>&1; then
        pass "quickshell: available"
    else
        fail "quickshell not found."
    fi

    # Check config
    if [ -f "$HOME/.local/share/quickshell/dms/shell.qml" ]; then
        pass "DMS QML files: deployed"
    else
        warn "DMS QML files: NOT found in expected location"
    fi

    if [ -L "$HOME/.config/quickshell/dms" ]; then
        pass "DMS config symlink: active"
    else
        warn "DMS config symlink: missing"
    fi

    # Test launch (dry run — just check if quickshell can parse the QML)
    echo ""
    info "Testing DMS launch (2 second timeout)..."
    timeout 2 dms run 2>&1 | head -5 || true
    echo ""

    pass "Installation complete!"
    echo ""
    echo -e "  ${CYAN}To start DMS:${NC}  dms run"
    echo -e "  ${CYAN}To stop DMS:${NC}   dms kill"
    echo -e "  ${CYAN}To restart:${NC}    dms kill && dms run"
}

# ===================================================================
# Main
# ===================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
    echo -e "\n${CYAN}=============================================${NC}"
    echo -e "${CYAN} DankMaterialShell (DMS) Installer${NC}"
    echo -e "${CYAN}=============================================${NC}"

    check_requirements
    fetch_dms
    build_dms
    install_dms
    deploy_config
    verify
}

main "$@"
