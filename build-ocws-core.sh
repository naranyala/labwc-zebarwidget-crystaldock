#!/bin/bash
# -------------------------------------------------------------------
# OCWS Core Builder
# Fetches the absolute latest master branch of the 3 engines and builds them.
# -------------------------------------------------------------------

set -euo pipefail

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

info() { echo -e "\n${CYAN}==> $*${NC}"; }
pass() { echo -e "  ${GREEN}✓${NC} $*"; }
fail() { echo -e "  ${RED}✗${NC} $*"; exit 1; }

# Privilege escalation: try pkexec, fall back to sudo
elevate() {
    if command -v pkexec &>/dev/null; then
        pkexec "$@"
    elif command -v sudo &>/dev/null; then
        sudo "$@"
    else
        fail "Neither pkexec nor sudo available. Cannot install system-wide."
    fi
}

# Prerequisites Check
for cmd in git meson ninja pkg-config gcc; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        fail "Missing required build tool: $cmd"
    fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-/usr/local}"
BUILD_DIR=$(mktemp -d /tmp/ocws-build-XXXXXX)
trap 'rm -rf "$BUILD_DIR"' EXIT

cd "$BUILD_DIR"

build_engine() {
    local NAME=$1
    local REPO_URL=$2

    info "Building $NAME from $REPO_URL"

    # Clean previous build
    rm -rf "$NAME"
    
    # Fetch absolute latest
    git clone --depth=1 "$REPO_URL" "$NAME"
    cd "$NAME"

    # Apply OCWS custom patches if they exist
    if [ -d "$SCRIPT_DIR/patches" ]; then
        for patch_file in "$SCRIPT_DIR/patches"/${NAME}-*.patch; do
            if [ -f "$patch_file" ]; then
                info "Applying patch: $(basename "$patch_file")"
                git apply "$patch_file" || echo -e "  ${RED}✗${NC} Failed to apply $(basename "$patch_file")"
            fi
        done
    fi

    # Meson Build
    info "Configuring $NAME..."
    meson setup build --prefix="$PREFIX" --buildtype=release
    
    info "Compiling $NAME..."
    ninja -C build

    info "Installing $NAME..."
    elevate sh -c "cd \"$PWD\" && ninja -C build install"

    cd ..
    pass "$NAME successfully installed to $PREFIX!"
}

build_make_engine() {
    local NAME=$1
    local REPO_URL=$2

    info "Building $NAME from $REPO_URL"

    # Clean previous build
    rm -rf "$NAME"
    
    # Fetch absolute latest
    git clone --depth=1 "$REPO_URL" "$NAME"
    cd "$NAME"

    info "Compiling $NAME..."
    make -j$(nproc)

    info "Installing $NAME..."
    elevate sh -c "cd \"$PWD\" && make install"

    cd ..
    pass "$NAME successfully installed!"
}

# ============================================================
# Core Engines
# ============================================================

case "${1:-all}" in
    "labwc")
        build_engine "labwc" "https://github.com/labwc/labwc.git"
        ;;
    "zigshell-cairo-pango")
        build_engine "zigshell-cairo-pango" "https://github.com/LBCrion/zigshell-cairo-pango.git"
        ;;
    "fuzzel")
        build_engine "fuzzel" "https://codeberg.org/dnkl/fuzzel.git"
        ;;
    "dms")
        build_make_engine "dms" "https://github.com/DankShrine/dms.git"
        ;;
    "zigshell-cairo-pango")
        build_make_engine "zigshell-cairo-pango" "https://github.com/igrekster/zigshell-cairo-pango.git"
        ;;
    "community")
        build_make_engine "dms" "https://github.com/DankShrine/dms.git"
        build_make_engine "zigshell-cairo-pango" "https://github.com/igrekster/zigshell-cairo-pango.git"
        ;;
    "all")
        build_engine "labwc" "https://github.com/labwc/labwc.git"
        build_engine "zigshell-cairo-pango" "https://github.com/LBCrion/zigshell-cairo-pango.git"
        build_engine "fuzzel" "https://codeberg.org/dnkl/fuzzel.git"
        ;;
    *)
        fail "Unknown target: $1. Available: labwc, zigshell-cairo-pango, fuzzel, dms, zigshell-cairo-pango, community, all"
        ;;
esac

info "OCWS Core Build Complete!"
echo -e "\n${YELLOW}Note:${NC} If you are using community shells like 'dms', 'noctalia', or 'zigshell-cairo-pango', you will need to clone and build them manually from their respective repositories."
