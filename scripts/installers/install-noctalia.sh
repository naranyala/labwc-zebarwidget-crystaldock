#!/bin/bash
# -------------------------------------------------------------------
# Noctalia Shell Installer
#
# Downloads, builds, and installs Noctalia Shell from source.
# Checks all requirements before building.
# Patches missing dependencies for OpenMandriva Linux.
#
# Requirements:
#   - Clang 19+ or GCC 14+ (C++23 support)
#   - Meson + Ninja build system
#   - Qt6 development packages
#   - just command runner
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

NOC_REPO="https://gitlab.com/noctalia-dev/noctalia-shell.git"
SRC_DIR="$HOME/sources"
NOC_SRC="$SRC_DIR/noctalia"
PREFIX="${PREFIX:-/usr/local}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===================================================================
# Check requirements
# ===================================================================
check_requirements() {
    info "Checking requirements..."

    local errors=0

    # 1. C++23 compiler
    if command -v clang++ >/dev/null 2>&1; then
        local clang_ver
        clang_ver=$(clang++ --version 2>&1 | head -1 || echo "unknown")
        pass "clang++: $clang_ver"
    elif command -v g++ >/dev/null 2>&1; then
        local gcc_ver
        gcc_ver=$(g++ --version 2>&1 | head -1 || echo "unknown")
        pass "g++: $gcc_ver"
    else
        warn "No C++23 compiler found (need clang++ or g++)"
        errors=$((errors + 1))
    fi

    # 2. Build tools
    for cmd in meson ninja git; do
        if command -v "$cmd" >/dev/null 2>&1; then
            pass "$cmd: $(command -v "$cmd")"
        else
            warn "$cmd: NOT FOUND (needed for build)"
            errors=$((errors + 1))
        fi
    done

    # 3. just command runner
    if command -v just >/dev/null 2>&1 || [ -x "$HOME/.local/bin/just" ]; then
        pass "just: found"
    else
        warn "just: NOT FOUND (needed for install step)"
        echo "    Install: curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/.local/bin"
        errors=$((errors + 1))
    fi

    # 4. Qt6 QML/Quick
    if pkg-config --exists Qt6Core Qt6Gui Qt6Qml Qt6Quick 2>/dev/null; then
        pass "Qt6 QML/Quick: $(pkg-config --modversion Qt6Core 2>/dev/null || echo 'found')"
    elif [ -f /usr/lib64/cmake/Qt6/Qt6Config.cmake ] || [ -f /usr/lib/cmake/Qt6/Qt6Config.cmake ]; then
        pass "Qt6: found via cmake"
    else
        warn "Qt6 QML/Quick packages may be missing"
        warn "Install: sudo dnf install lib64Qt6Core-devel lib64Qt6Qml-devel lib64Qt6Quick-devel"
        errors=$((errors + 1))
    fi

    # 5. Wayland compositor
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
        warn "No Wayland compositor detected (not fatal — Noctalia needs one at runtime)"
        compositor="not found"
    fi
    pass "Wayland compositor: $compositor"

    # 6. sdbus-c++
    if pkg-config --exists sdbus-c++ 2>/dev/null; then
        pass "sdbus-c++: found"
    elif [ -f /usr/include/sdbus-c++/sdbus-c++/sdbus.h ] || [ -f /usr/include/sdbus-c++/sdbus.h ]; then
        pass "sdbus-c++: found via header"
    else
        warn "sdbus-c++ may be missing"
        warn "Install: sudo dnf install lib64sdbus-cpp-devel"
        errors=$((errors + 1))
    fi

    # 7. stb_image_resize2.h (v2)
    if [ -f /usr/include/stb/stb_image_resize2.h ]; then
        pass "stb_image_resize2.h: found"
    else
        warn "stb_image_resize2.h v2: NOT FOUND (OpenMandriva ships v1 only)"
        echo "    Will be patched automatically."
    fi

    # 8. ext-background-effect-v1.xml
    if [ -f /usr/share/wayland-protocols/staging/ext-background-effect/ext-background-effect-v1.xml ]; then
        pass "ext-background-effect-v1.xml: found"
    else
        warn "ext-background-effect-v1.xml: NOT FOUND"
        echo "    Will be patched automatically."
    fi

    # 9. noctalia binary (check if already installed)
    if command -v noctalia >/dev/null 2>&1; then
        local noc_ver
        noc_ver=$(noctalia --version 2>&1 | head -1 || echo "unknown")
        warn "Noctalia already installed: $noc_ver"
        echo -e "    Will be overwritten by new build."
    fi

    # 10. Noctalia config directory
    if [ -d "$HOME/.config/noctalia" ]; then
        pass "Noctalia config dir exists: ~/.config/noctalia/"
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
# Patch missing dependencies
# ===================================================================
patch_dependencies() {
    info "Patching missing dependencies..."

    # 1. stb_image_resize2.h v2
    if [ ! -f /usr/include/stb/stb_image_resize2.h ]; then
        info "Installing stb_image_resize2.h v2..."
        local stb_url="https://raw.githubusercontent.com/nothings/stb/master/stb_image_resize2.h"
        if command -v pkexec >/dev/null 2>&1; then
            pkexec curl -fsSL -o /usr/include/stb/stb_image_resize2.h "$stb_url"
        elif command -v sudo >/dev/null 2>&1; then
            sudo curl -fsSL -o /usr/include/stb/stb_image_resize2.h "$stb_url"
        else
            warn "Cannot install stb_image_resize2.h — no root access."
            echo "    Run manually: sudo curl -fsSL -o /usr/include/stb/stb_image_resize2.h $stb_url"
        fi
        if [ -f /usr/include/stb/stb_image_resize2.h ]; then
            pass "stb_image_resize2.h v2 installed."
        fi
    fi

    # 2. ext-background-effect-v1.xml
    if [ ! -f /usr/share/wayland-protocols/staging/ext-background-effect/ext-background-effect-v1.xml ]; then
        info "Installing ext-background-effect-v1.xml protocol..."
        local proto_url="https://gitlab.freedesktop.org/wayland/wayland-protocols/-/raw/main/staging/ext-background-effect/ext-background-effect-v1.xml"
        local proto_dir="/usr/share/wayland-protocols/staging/ext-background-effect"
        if command -v pkexec >/dev/null 2>&1; then
            pkexec mkdir -p "$proto_dir"
            pkexec curl -fsSL -o "$proto_dir/ext-background-effect-v1.xml" "$proto_url"
        elif command -v sudo >/dev/null 2>&1; then
            sudo mkdir -p "$proto_dir"
            sudo curl -fsSL -o "$proto_dir/ext-background-effect-v1.xml" "$proto_url"
        else
            warn "Cannot install protocol — no root access."
            echo "    Run manually: sudo mkdir -p $proto_dir && sudo curl -fsSL -o $proto_dir/ext-background-effect-v1.xml $proto_url"
        fi
        if [ -f "$proto_dir/ext-background-effect-v1.xml" ]; then
            pass "ext-background-effect-v1.xml installed."
        fi
    fi

    # 3. just command runner
    if ! command -v just >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/just" ]; then
        info "Installing just command runner..."
        mkdir -p "$HOME/.local/bin"
        curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to "$HOME/.local/bin"
        if [ -x "$HOME/.local/bin/just" ]; then
            pass "just installed to ~/.local/bin/just"
        else
            warn "just installation may have failed"
        fi
    fi

    pass "Dependency patching complete."
}

# ===================================================================
# Clone or update Noctalia source
# ===================================================================
fetch_noctalia() {
    info "Fetching Noctalia source..."

    mkdir -p "$SRC_DIR"

    if [ -d "$NOC_SRC/.git" ]; then
        cd "$NOC_SRC"
        local before
        before=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        git fetch origin
        git reset --hard origin/HEAD 2>/dev/null || git reset --hard origin/main 2>/dev/null || true
        local after
        after=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        if [ "$before" = "$after" ]; then
            pass "Noctalia already up to date ($after)."
        else
            pass "Noctalia updated: $before → $after"
        fi
    else
        rm -rf "$NOC_SRC"
        git clone --depth=1 "$NOC_REPO" "$NOC_SRC"
        cd "$NOC_SRC"
        pass "Noctalia cloned ($(git rev-parse --short HEAD))."
    fi
}

# ===================================================================
# Configure Noctalia build
# ===================================================================
configure_noctalia() {
    info "Configuring Noctalia build..."
    cd "$NOC_SRC"

    # Detect compiler
    local compiler_opts=()
    if command -v clang++ >/dev/null 2>&1; then
        compiler_opts+=(-Dclang=true)
        pass "Using Clang"
    else
        compiler_opts+=(-Dclang=false)
        pass "Using GCC"
    fi

    # Clean previous build
    rm -rf build

    meson setup build \
        --prefix="$PREFIX" \
        --buildtype=release \
        -Dcpp_std=c++23 \
        "${compiler_opts[@]}" \
        2>&1 || {
            warn "Meson configuration failed."
            echo "    Check the error output above for missing dependencies."
            exit 1
        }

    pass "Build configured."
}

# ===================================================================
# Build Noctalia
# ===================================================================
build_noctalia() {
    info "Building Noctalia (this may take 15-30 minutes)..."
    cd "$NOC_SRC"

    local jobs
    jobs=$(nproc 2>/dev/null || echo 4)

    # Try full parallelism first, fall back to reduced on failure
    if ninja -C build -j"$jobs" 2>&1; then
        pass "Build complete ($jobs threads)."
    else
        warn "Parallel build failed, trying with reduced parallelism..."
        ninja -C build -j2 2>&1 || {
            fail "Build failed. Check the error output above."
        }
        pass "Build complete (2 threads)."
    fi
}

# ===================================================================
# Install Noctalia
# ===================================================================
install_noctalia() {
    info "Installing Noctalia..."
    cd "$NOC_SRC"

    # Try just install first
    if [ -x "$HOME/.local/bin/just" ]; then
        "$HOME/.local/bin/just" install 2>&1 && {
            pass "Noctalia installed via just."
            return
        }
    elif command -v just >/dev/null 2>&1; then
        just install 2>&1 && {
            pass "Noctalia installed via just."
            return
        }
    fi

    # Fallback to ninja install
    if command -v pkexec >/dev/null 2>&1; then
        pkexec ninja -C build install
    elif command -v sudo >/dev/null 2>&1; then
        sudo ninja -C build install
    else
        fail "Cannot install — no sudo/pkexec and not running as root."
    fi

    pass "Noctalia installed to $PREFIX/bin/noctalia"
}

# ===================================================================
# Deploy Noctalia configuration
# ===================================================================
deploy_config() {
    info "Deploying Noctalia configuration..."

    local NOC_CONFIG="$HOME/.config/noctalia"
    mkdir -p "$NOC_CONFIG"

    # Deploy default config if not present
    if [ ! -f "$NOC_CONFIG/config.toml" ]; then
        if [ -f "$SCRIPT_DIR/dotfiles/noctalia/config.toml" ]; then
            cp "$SCRIPT_DIR/dotfiles/noctalia/config.toml" "$NOC_CONFIG/config.toml"
            pass "Deployed default config.toml"
        else
            # Create minimal config
            cat > "$NOC_CONFIG/config.toml" << 'EOF'
# Noctalia Shell configuration

[shell]
ui_scale = 1.0

[bar.main]
position = "top"
thickness = 34

[theme]
mode = "dark"
source = "builtin"
builtin = "Noctalia"
EOF
            pass "Created minimal config.toml"
        fi
    else
        pass "Config already exists (not overwritten)."
    fi
}

# ===================================================================
# Verify installation
# ===================================================================
verify() {
    info "Verifying installation..."

    # Check binary
    if command -v noctalia >/dev/null 2>&1; then
        local ver
        ver=$(noctalia --version 2>&1 | head -1 || echo "installed")
        pass "noctalia binary: $ver"
    elif [ -f "$PREFIX/bin/noctalia" ]; then
        pass "noctalia binary: $PREFIX/bin/noctalia (may need PATH update)"
    else
        fail "noctalia binary not found after install."
    fi

    # Check config
    if [ -f "$HOME/.config/noctalia/config.toml" ]; then
        pass "Configuration: ~/.config/noctalia/config.toml"
    else
        warn "Configuration: NOT found"
    fi

    # Check Wayland compositor
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        pass "Wayland session: active"
    else
        warn "No active Wayland session (start a compositor first)"
    fi

    pass "Installation complete!"
    echo ""
    echo -e "  ${CYAN}To start Noctalia:${NC}    noctalia &"
    echo -e "  ${CYAN}To stop Noctalia:${NC}     pkill noctalia"
    echo -e "  ${CYAN}To restart:${NC}           pkill noctalia; sleep 0.5; noctalia &"
    echo -e "  ${CYAN}IPC commands:${NC}         noctalia msg launcher toggle"
    echo -e "  ${CYAN}Lock screen:${NC}          noctalia msg session lock"
}

# ===================================================================
# Main
# ===================================================================
main() {
    echo -e "\n${CYAN}=============================================${NC}"
    echo -e "${CYAN} Noctalia Shell Installer${NC}"
    echo -e "${CYAN}=============================================${NC}"

    check_requirements
    patch_dependencies
    fetch_noctalia
    configure_noctalia
    build_noctalia
    install_noctalia
    deploy_config
    verify
}

main "$@"
