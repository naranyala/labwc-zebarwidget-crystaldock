#!/bin/bash
# ==============================================================================
# script: install-foot.sh
# description: Manually build and install the Foot Terminal Emulator from source
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "\n${CYAN}==> $1${NC}"; }
pass() { echo -e "  ${GREEN}✓${NC} $1"; }

if command -v foot &>/dev/null; then
    pass "foot terminal is already installed: $(command -v foot)"
    exit 0
fi

BUILD_DIR="/tmp/manual-builds"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

info "Installing dependencies..."
if command -v dnf &>/dev/null; then
    sudo dnf install -y meson ninja cmake gcc gcc-c++ wayland-protocols-devel \
                        lib64wayland-client-devel lib64pixman-devel lib64fontconfig-devel \
                        lib64freetype6-devel lib64harfbuzz-devel lib64xkbcommon-devel \
                        utf8proc-devel scdoc
elif command -v apt-get &>/dev/null; then
    sudo apt-get install -y meson ninja-build cmake gcc g++ wayland-protocols libwayland-dev \
                            libpixman-1-dev libfontconfig1-dev libfreetype6-dev libharfbuzz-dev \
                            libxkbcommon-dev libutf8proc-dev scdoc
fi

# Build tllist
if ! pkg-config --exists tllist; then
    info "Building tllist..."
    rm -rf tllist && git clone --depth=1 https://codeberg.org/dnkl/tllist.git
    cd tllist && meson setup build --buildtype=release && ninja -C build && sudo ninja -C build install && cd ..
fi

# Build fcft
if ! pkg-config --exists fcft; then
    info "Building fcft..."
    rm -rf fcft && git clone --depth=1 https://codeberg.org/dnkl/fcft.git
    cd fcft && meson setup build --buildtype=release && ninja -C build && sudo ninja -C build install && cd ..
fi

# Build foot
info "Building foot..."
rm -rf foot && git clone --depth=1 https://codeberg.org/dnkl/foot.git
cd foot && meson setup build --buildtype=release && ninja -C build && sudo ninja -C build install && cd ..

pass "foot terminal built and installed!"
