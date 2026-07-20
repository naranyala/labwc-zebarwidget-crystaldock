#!/bin/bash
# -------------------------------------------------------------------
# Quickshell Build & Install Script (Full Source Build)
#
# Builds quickshell and its missing dependencies from source on any
# Linux distro. Tries distro packages first, falls back to source
# builds for deps not available in the repos.
#
# Requires: cmake, ninja, gcc/g++, git, Qt6 dev packages
# Installs to: /usr/local
# -------------------------------------------------------------------
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "\n${CYAN}==>${NC} $*"; }
pass()  { echo -e "  ${GREEN}✓${NC} $*"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $*"; }
fail()  { echo -e "  ${RED}✗${NC} $*"; exit 1; }

QS_REPO="https://github.com/quickshell-mirror/quickshell.git"
SRC_DIR="$HOME/sources"
QS_SRC="$SRC_DIR/quickshell"
PREFIX="/usr/local"
JOBS="$(nproc 2>/dev/null || echo 4)"

mkdir -p "$SRC_DIR"

# ===================================================================
# Detect distro
# ===================================================================
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_FAMILY=""
        case "$DISTRO_ID" in
            fedora|rhel|centos|rocky|alma|openmandriva|mageia) DISTRO_FAMILY="rhel" ;;
            debian|ubuntu|linuxmint|pop|elementary|zorin)       DISTRO_FAMILY="debian" ;;
            arch|manjaro|endeavouros|garuda)                     DISTRO_FAMILY="arch" ;;
            opensuse*|suse*)                                     DISTRO_FAMILY="suse" ;;
            void)                                                DISTRO_FAMILY="void" ;;
            alpine)                                              DISTRO_FAMILY="alpine" ;;
            *)                                                   DISTRO_FAMILY="unknown" ;;
        esac
    else
        DISTRO_ID="unknown"
        DISTRO_FAMILY="unknown"
    fi
    info "Detected distro: $DISTRO_ID ($DISTRO_FAMILY)"
}

# ===================================================================
# Helper: check if a pkg-config module exists
# ===================================================================
has_pkg() {
    pkg-config --exists "$1" 2>/dev/null
}

# ===================================================================
# Helper: check if a cmake package exists
# ===================================================================
has_cmake_pkg() {
    cmake --find-package -DNAME="$1" -DCOMPILER_ID=GNU -DLANGUAGE=CXX -DMODE=EXIST &>/dev/null
}

# ===================================================================
# Helper: check if a binary exists
# ===================================================================
has_cmd() {
    command -v "$1" &>/dev/null
}

# ===================================================================
# 1. Install build tools (cmake, ninja, git, compiler)
# ===================================================================
install_build_tools() {
    info "Installing build tools..."

    case "$DISTRO_FAMILY" in
        rhel)
            sudo dnf install -y cmake ninja-build gcc-c++ g++ pkgconf-pkg-config git 2>/dev/null || \
            sudo dnf install -y cmake3 ninja gcc-c++ pkgconf git 2>/dev/null || true
            ;;
        debian)
            sudo apt-get update -qq
            sudo apt-get install -y cmake ninja-build g++ pkg-config git
            ;;
        arch)
            sudo pacman -S --needed --noconfirm cmake ninja gcc pkgconf git
            ;;
        suse)
            sudo zypper install -y cmake ninja gcc-c++ pkgconf git
            ;;
        alpine)
            sudo apk add cmake ninja gcc g++ pkgconf git musl-dev
            ;;
        void)
            sudo xbps-install -Sy cmake ninja gcc pkg-config git
            ;;
        *)
            # Try common package managers
            if has_cmd apt-get; then
                sudo apt-get update -qq && sudo apt-get install -y cmake ninja-build g++ pkg-config git
            elif has_cmd dnf; then
                sudo dnf install -y cmake ninja-build gcc-c++ pkgconf git
            elif has_cmd pacman; then
                sudo pacman -S --needed --noconfirm cmake ninja gcc pkgconf git
            else
                warn "Cannot install build tools automatically. Ensure cmake, ninja, g++, pkg-config, git are installed."
            fi
            ;;
    esac

    for cmd in cmake ninja g++ git pkg-config; do
        has_cmd "$cmd" || fail "Required tool '$cmd' not found. Install it manually."
    done
    pass "Build tools ready."
}

# ===================================================================
# 2. Install Qt6 development packages (must come from distro)
# ===================================================================
install_qt6() {
    info "Installing Qt6 development packages..."

    # Check if Qt6 is already available
    if has_pkg Qt6Core && has_pkg Qt6Gui && has_pkg Qt6Qml && has_pkg Qt6Quick; then
        pass "Qt6 already available."
        return
    fi

    case "$DISTRO_FAMILY" in
        rhel)
            sudo dnf install -y \
                lib64Qt6Core-devel lib64Qt6Gui-devel lib64Qt6Qml-devel \
                lib64Qt6Quick-devel lib64Qt6QuickControls2-devel \
                lib64Qt6Widgets-devel lib64Qt6ShaderTools-devel \
                lib64Qt6WaylandClient-devel lib64Qt6DBus-devel \
                lib64Qt6Network-devel lib64Qt6Test-devel 2>/dev/null || \
            sudo dnf install -y \
                qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtwayland-devel \
                qt6-qtshadertools-devel qt6-qtbase-private-devel 2>/dev/null || true
            ;;
        debian)
            sudo apt-get install -y \
                qt6-base-dev qt6-declarative-dev qt6-wayland-dev \
                qt6-base-private-dev libqt6svg6-dev
            ;;
        arch)
            sudo pacman -S --needed --noconfirm \
                qt6-base qt6-declarative qt6-wayland qt6-shadertools
            ;;
        suse)
            sudo zypper install -y \
                qt6-base-devel qt6-declarative-devel qt6-wayland-devel \
                qt6-shadertools-devel
            ;;
        *)
            warn "Cannot install Qt6 packages automatically."
            warn "Install Qt6 dev packages for your distro (qt6-base-devel, qt6-declarative-devel, qt6-wayland-devel, qt6-shadertools-devel)."
            ;;
    esac

    # Verify Qt6 is available
    if has_pkg Qt6Core; then
        pass "Qt6 development packages installed."
    else
        fail "Qt6 not found. Install Qt6 development packages manually:
  Debian/Ubuntu:  sudo apt install qt6-base-dev qt6-declarative-dev qt6-wayland-dev qt6-shadertools-devel
  Fedora:         sudo dnf install qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtwayland-devel qt6-qtshadertools-devel
  Arch:           sudo pacman -S qt6-base qt6-declarative qt6-wayland qt6-shadertools"
    fi
}

# ===================================================================
# 3. Install wayland + vulkan deps from distro
# ===================================================================
install_wayland_vulkan_deps() {
    info "Installing Wayland and Vulkan dependencies..."

    case "$DISTRO_FAMILY" in
        rhel)
            sudo dnf install -y \
                lib64wayland-devel wayland-protocols-devel \
                lib64vulkan-devel spirv-tools 2>/dev/null || \
            sudo dnf install -y \
                wayland-devel wayland-protocols-devel \
                vulkan-devel spirv-tools 2>/dev/null || true
            ;;
        debian)
            sudo apt-get install -y \
                libwayland-dev wayland-protocols \
                libvulkan-dev spirv-tools glslang-tools
            ;;
        arch)
            sudo pacman -S --needed --noconfirm \
                wayland wayland-protocols \
                vulkan-icd-loader spirv-tools glslang
            ;;
        suse)
            sudo zypper install -y \
                wayland-devel wayland-protocols-devel \
                vulkan-devel spirv-tools
            ;;
        *)
            if has_cmd apt-get; then
                sudo apt-get install -y libwayland-dev wayland-protocols libvulkan-dev spirv-tools 2>/dev/null || true
            elif has_cmd dnf; then
                sudo dnf install -y wayland-devel wayland-protocols-devel vulkan-devel spirv-tools 2>/dev/null || true
            fi
            ;;
    esac
    pass "Wayland/Vulkan deps checked."
}

# ===================================================================
# 4. Install remaining distro packages (pam, pipewire, etc.)
# ===================================================================
install_misc_deps() {
    info "Installing remaining dependencies..."

    case "$DISTRO_FAMILY" in
        rhel)
            sudo dnf install -y \
                lib64jemalloc-devel lib64pipewire-devel \
                lib64pam-devel 2>/dev/null || true
            # polkit-qt6 may not exist on older distros
            sudo dnf install -y polkit-qt6-1-devel 2>/dev/null || \
            sudo dnf install -y lib64polkit-devel 2>/dev/null || true
            ;;
        debian)
            sudo apt-get install -y \
                libjemalloc-dev libpipewire-0.3-dev \
                libpam0g-dev libpolkit-agent-1-dev 2>/dev/null || true
            ;;
        arch)
            sudo pacman -S --needed --noconfirm \
                jemalloc pipewire pam polkit
            ;;
        suse)
            sudo zypper install -y \
                jemalloc-devel pipewire-devel pam-devel 2>/dev/null || true
            ;;
        *)
            if has_cmd apt-get; then
                sudo apt-get install -y libjemalloc-dev libpipewire-0.3-dev libpam0g-dev 2>/dev/null || true
            elif has_cmd dnf; then
                sudo dnf install -y jemalloc-devel pipewire-devel pam-devel 2>/dev/null || true
            fi
            ;;
    esac
    pass "Misc deps checked."
}

# ===================================================================
# 5. Build CLI11 from source (if not available)
# ===================================================================
build_cli11() {
    if has_cmake_pkg CLI11 || has_pkg CLI11; then
        pass "CLI11 already available."
        return
    fi

    # Check if header is installed
    if [ -f /usr/include/CLI/CLI.hpp ] || [ -f /usr/local/include/CLI/CLI.hpp ]; then
        pass "CLI11 header already installed."
        return
    fi

    info "Building CLI11 from source (header-only library)..."
    local cli11_ver="2.4.2"
    local cli11_dir="$SRC_DIR/cli11"

    if [ ! -d "$cli11_dir" ]; then
        git clone --depth=1 --branch "v${cli11_ver}" \
            https://github.com/CLIUtils/CLI11.git "$cli11_dir"
    fi

    cd "$cli11_dir"
    cmake -B build -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCLI11_BUILD_TESTS=OFF \
        -DCLI11_BUILD_EXAMPLES=OFF
    cmake --build build -j"$JOBS"
    sudo cmake --install build
    cd "$SRC_DIR"
    pass "CLI11 installed."
}

# ===================================================================
# 6. Build cpptrace from source (if not available, optional)
# ===================================================================
build_cpptrace() {
    # Check if already available
    if has_pkg cpptrace || [ -f /usr/include/cpptrace/basic.hpp ] || [ -f /usr/local/include/cpptrace/basic.hpp ]; then
        pass "cpptrace already available."
        return
    fi

    info "Building cpptrace from source (optional, for crash reports)..."
    local cpptrace_dir="$SRC_DIR/cpptrace"

    if [ ! -d "$cpptrace_dir" ]; then
        git clone --depth=1 https://github.com/jeremy-rifkin/cpptrace.git "$cpptrace_dir"
    fi

    cd "$cpptrace_dir"
    cmake -B build -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DBUILD_SHARED_LIBS=ON \
        -DCPPTRACE_BUILD_STATIC=OFF
    cmake --build build -j"$JOBS"
    sudo cmake --install build
    cd "$SRC_DIR"
    pass "cpptrace installed."
}

# ===================================================================
# 7. Build jemalloc from source (if not available)
# ===================================================================
build_jemalloc() {
    if has_pkg jemalloc || [ -f /usr/lib/libjemalloc.so ] || [ -f /usr/local/lib/libjemalloc.so ]; then
        pass "jemalloc already available."
        return
    fi

    info "Building jemalloc from source..."
    local je_ver="5.3.0"
    local je_dir="$SRC_DIR/jemalloc"

    if [ ! -d "$je_dir" ]; then
        curl -fsSL "https://github.com/jemalloc/jemalloc/archive/refs/tags/${je_ver}.tar.gz" \
            | tar xz -C "$SRC_DIR"
        mv "$SRC_DIR/jemalloc-${je_ver}" "$je_dir"
    fi

    cd "$je_dir"
    ./autogen.sh --prefix="$PREFIX"
    make -j"$JOBS"
    sudo make install
    sudo ldconfig 2>/dev/null || true
    cd "$SRC_DIR"
    pass "jemalloc installed."
}

# ===================================================================
# 8. Clone or update quickshell source
# ===================================================================
fetch_quickshell() {
    info "Fetching quickshell source (master branch)..."

    if [ -d "$QS_SRC/.git" ]; then
        cd "$QS_SRC"
        git fetch origin
        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse origin/master)
        if [ "$LOCAL" = "$REMOTE" ]; then
            pass "Already up to date ($(git rev-parse --short HEAD))."
        else
            git pull --ff-only
            pass "Updated to $(git rev-parse --short HEAD)."
        fi
    else
        rm -rf "$QS_SRC"
        git clone --depth=1 "$QS_REPO" "$QS_SRC"
        cd "$QS_SRC"
        pass "Cloned quickshell ($(git rev-parse --short HEAD))."
    fi
}

# ===================================================================
# 9. Configure quickshell build
# ===================================================================
configure_quickshell() {
    info "Configuring quickshell build..."

    cd "$QS_SRC"

    local CMAKE_OPTS=(
        -GNinja
        -B build
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX="$PREFIX"
        -DDISTRIBUTOR="OCWS"
        -DCMAKE_PREFIX_PATH="$PREFIX"
        -DVENDOR_CPPTRACE=ON
        -DNO_PCH=ON
    )

    # Disable features that require missing optional deps
    if ! has_pkg cpptrace && \
       ! [ -f /usr/include/cpptrace/basic.hpp ] && \
       ! [ -f /usr/local/include/cpptrace/basic.hpp ]; then
        CMAKE_OPTS+=(-DCRASH_HANDLER=OFF)
        warn "Disabling crash handler (cpptrace not found)."
    fi

    if ! has_pkg libpipewire-0.3 && ! [ -f /usr/lib/pkgconfig/libpipewire-0.3.pc ]; then
        CMAKE_OPTS+=(-DSERVICE_PIPEWIRE=OFF)
        warn "Disabling PipeWire service (not found)."
    fi

    cmake "${CMAKE_OPTS[@]}"
    pass "Build configured."
}

# ===================================================================
# 10. Build quickshell
# ===================================================================
build_quickshell() {
    info "Building quickshell ($JOBS threads)..."
    cd "$QS_SRC"
    cmake --build build -j"$JOBS"
    pass "Build complete."
}

# ===================================================================
# 11. Install quickshell
# ===================================================================
install_quickshell() {
    info "Installing quickshell to $PREFIX..."
    cd "$QS_SRC"
    sudo cmake --install build
    pass "Installed to $PREFIX/bin/quickshell."
}

# ===================================================================
# 12. Verify installation
# ===================================================================
verify_install() {
    echo ""
    export PATH="$PREFIX/bin:$PATH"

    if has_cmd quickshell; then
        local ver
        ver=$(quickshell --version 2>&1 | head -1)
        pass "Quickshell is ready: $ver"
    else
        warn "Quickshell installed but not in PATH."
        echo "  Add to your shell profile:"
        echo "    export PATH=\"$PREFIX/bin:\$PATH\""
    fi

    # Check for old distro package
    local old_pkg=""
    if has_cmd rpm; then
        old_pkg=$(rpm -qf /usr/bin/quickshell 2>/dev/null || true)
    fi
    if [ -n "$old_pkg" ] && [[ "$old_pkg" != *"not owned"* ]]; then
        echo ""
        warn "Old distro package still installed: $old_pkg"
        echo "  Remove it to avoid path conflicts:"
        if has_cmd dnf; then echo "    sudo dnf remove quickshell"
        elif has_cmd apt; then echo "    sudo apt remove quickshell"
        elif has_cmd pacman; then echo "    sudo pacman -R quickshell"
        fi
    fi

    echo ""
    echo -e "${GREEN}Done!${NC} Restart your session or run:"
    echo "  dms kill && dms run"
}

# ===================================================================
# Main
# ===================================================================
main() {
    echo -e "\n${CYAN}=============================================${NC}"
    echo -e "${CYAN} Quickshell Source Build & Install${NC}"
    echo -e "${CYAN}=============================================${NC}"

    detect_distro
    install_build_tools
    install_qt6
    install_wayland_vulkan_deps
    install_misc_deps
    build_cli11
    build_cpptrace
    build_jemalloc
    fetch_quickshell
    configure_quickshell
    build_quickshell
    install_quickshell
    verify_install
}

main "$@"
