#!/usr/bin/env bash
# -------------------------------------------------------------------
# install-lxqt-panel-source.sh
#
# Build and install lxqt-panel (and the LXQt libraries it needs) from
# source. Use this on distributions whose package manager does not ship
# lxqt-panel / its LXQt dependencies (or when you want the latest release).
#
# Strategy:
#   1. Install the build toolchain + the *common* dev packages that ARE
#      usually packaged (Qt6, KF6, Wayland, LayerShellQt, ...).
#   2. Build the *LXQt-specific* libraries that are typically NOT packaged
#      (libdbusmenu-lxqt, lxqt-menu-data, libsysstat, liblxqt,
#      lxqt-globalkeys) plus lxqt-panel itself, from tagged releases.
#   3. Install everything to /usr/local and refresh the linker cache.
#
# Layer-shell support is required for lxqt-panel to dock on labwc; if the
# distro does not package LayerShellQt we build it from source too.
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

# Build in a temp working dir; keep sources for inspection/rebuild.
SRC_ROOT="${SRC_ROOT:-/tmp/lxqt-build}"
PREFIX="${PREFIX:-/usr/local}"
JOBS="$(nproc 2>/dev/null || echo 4)"

# Make sure later builds can find what we installed to PREFIX.
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
export CMAKE_PREFIX_PATH="$PREFIX:${CMAKE_PREFIX_PATH:-}"
export LD_LIBRARY_PATH="$PREFIX/lib:$PREFIX/lib64:${LD_LIBRARY_PATH:-}"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        warn "Not running as root and 'sudo' not found; installs may fail."
    fi
fi

run_install() { $SUDO "$@"; }

# -------------------------------------------------------------------
# Distro detection
# -------------------------------------------------------------------
if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    fail "/etc/os-release not found — cannot detect distribution."
fi

OS="$ID"
OS_LIKE="${ID_LIKE:-$ID}"

PKG_MANAGER=""
INSTALL_CMD=""
case "$OS" in
    arch|manjaro|endeavouros) PKG_MANAGER="pacman" ;;
    debian|ubuntu|pop|linuxmint|kali) PKG_MANAGER="apt" ;;
    fedora) PKG_MANAGER="dnf" ;;
    almalinux|rocky|rhel|centos) PKG_MANAGER="dnf" ;;
    opensuse*|suse) PKG_MANAGER="zypper" ;;
    alpine) PKG_MANAGER="apk" ;;
    void) PKG_MANAGER="xbps" ;;
    openmandriva) PKG_MANAGER="dnf" ;;
    *) PKG_MANAGER="unknown" ;;
esac

# -------------------------------------------------------------------
# Build dependencies (best-effort per distro).
# These are the *common* packages; the LXQt libs are built below.
# -------------------------------------------------------------------
install_build_deps() {
    info "Installing build dependencies via $PKG_MANAGER..."
    case "$PKG_MANAGER" in
        apt)
            $SUDO apt-get update -y || true
            $SUDO apt-get install -y --no-install-recommends \
                cmake extra-cmake-modules ninja-build pkg-config \
                build-essential git ca-certificates \
                qt6-base-dev qt6-svg-dev qt6-tools-dev qt6-tools-dev-tools \
                qt6-wayland-dev wayland-protocols libwayland-dev \
                libxcb1-dev libx11-dev libxkbcommon-dev \
                libglib2.0-dev \
                libkf6guiaddons-dev libkf6windowsystem-dev libkf6solid-dev \
                libkf6config-dev libkf6coreaddons-dev libkf6i18n-dev \
                libpulse-dev libasound2-dev libsensors-dev \
                libstatgrab-dev libdbusmenu-qt6-dev \
                liblayershellqtinterface-dev \
                || warn "Some APT build deps failed — continuing (they may be named differently)."
            ;;
        dnf)
            $SUDO dnf install -y \
                cmake extra-cmake-modules ninja-build pkgconfig \
                gcc gcc-c++ git make \
                qt6-qtbase-devel qt6-qtsvg-devel qt6-qttools-devel \
                qt6-qtwayland-devel wayland-devel wayland-protocols-devel \
                libxcb-devel libX11-devel libxkbcommon-devel \
                glib2-devel \
                kf6-kguiaddons-devel kf6-kwindowsystem-devel kf6-solid-devel \
                kf6-kconfig-devel kf6-kcoreaddons-devel kf6-ki18n-devel \
                pulseaudio-libs-devel alsa-lib-devel lm_sensors-devel \
                libstatgrab-devel libdbusmenu-devel \
                layer-shell-qt-devel \
                || warn "Some DNF build deps failed — continuing."
            ;;
        pacman)
            $SUDO pacman -S --needed --noconfirm \
                base-devel cmake extra-cmake-modules ninja git pkgconf \
                qt6-base qt6-svg qt6-tools qt6-wayland wayland-protocols \
                libxcb libx11 libxkbcommon glib2 \
                kguiaddons kwindowsystem solid kconfig kcoreaddons ki18n \
                libpulse alsa-lib lm_sensors libstatgrab \
                layer-shell-qt \
                || warn "Some pacman build deps failed — continuing."
            ;;
        zypper)
            $SUDO zypper install -y \
                cmake extra-cmake-modules ninja pkgconfig \
                gcc gcc-c++ git make \
                qt6-base-devel qt6-svg-devel qt6-tools-devel \
                qt6-wayland-devel wayland-devel wayland-protocols-devel \
                libxcb-devel libX11-devel libxkbcommon-devel \
                glib2-devel \
                kguiaddons-devel kwindowsystem-devel solid-devel \
                kconfig-devel kcoreaddons-devel ki18n-devel \
                pulseaudio-devel alsa-devel libsensors-devel \
                libstatgrab-devel layer-shell-qt-devel \
                || warn "Some zypper build deps failed — continuing."
            ;;
        apk)
            $SUDO apk add --no-cache \
                cmake extra-cmake-modules ninja pkgconf \
                build-base git \
                qt6-qtbase-dev qt6-qtsvg-dev qt6-qttools-dev \
                qt6-qtwayland-dev wayland-dev wayland-protocols \
                libxcb-dev libx11-dev libxkbcommon-dev \
                glib-dev \
                kguiaddons-dev kwindowsystem-dev solid-dev \
                kconfig-dev kcoreaddons-dev ki18n-dev \
                libpulse-dev alsa-lib-dev lm-sensors-dev \
                libstatgrab-dev \
                || warn "Some apk build deps failed — continuing."
            ;;
        xbps)
            $SUDO xbps-install -Sy \
                cmake extra-cmake-modules ninja pkg-config \
                base-devel git \
                qt6-base-devel qt6-svg-devel qt6-tools-devel \
                qt6-wayland-devel wayland-protocols wayland-devel \
                libxcb-devel libX11-devel libxkbcommon-devel \
                glib-devel \
                kguiaddons-devel kwindowsystem-devel solid-devel \
                kconfig-devel kcoreaddons-devel ki18n-devel \
                pulseaudio-devel alsa-lib-devel lm_sensors-devel \
                libstatgrab-devel \
                || warn "Some xbps build deps failed — continuing."
            ;;
        *)
            warn "Unknown package manager ($PKG_MANAGER)."
            warn "Please install manually: cmake, ninja, gcc/g++, git, Qt6 dev,"
            warn "KF6 (guiaddons/windowsystem/solid/config/coreaddons/i18n) dev,"
            warn "Wayland + layer-shell-qt dev, libdbusmenu-qt6 dev, libstatgrab-dev."
            ;;
    esac
}

# -------------------------------------------------------------------
# Generic "clone tag -> cmake -> build -> install" helper
# -------------------------------------------------------------------
build_repo() {
    local name="$1" url="$2"
    local branch="${3:-}"  # optional explicit tag/branch; else latest tag
    info "Building $name ..."
    cd "$SRC_ROOT"
    rm -rf "$name"
    if [ -n "$branch" ]; then
        git clone --depth 1 --branch "$branch" "$url" "$name"
    else
        git clone --depth 1 "$url" "$name"
        cd "$name"
        local tag
        tag="$(git describe --tags "$(git rev-list --tags --max-count=1)" 2>/dev/null || true)"
        if [ -n "$tag" ]; then
            git fetch --depth 1 origin "tag/$tag" || true
            git checkout "$tag" || true
            echo "  Using release tag: $tag"
        fi
    fi
    cd "$SRC_ROOT/$name"
    cmake -B build -G Ninja \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_TESTING=OFF \
        "$@"
    cmake --build build -j"$JOBS"
    run_install cmake --install build
    $SUDO ldconfig 2>/dev/null || true
    pass "$name installed."
}

# -------------------------------------------------------------------
# Optional: build LayerShellQt from source if not detectable
# -------------------------------------------------------------------
layershell_available() {
    pkg-config --exists LayerShellQt 2>/dev/null \
        || ls "$PREFIX"/lib*/cmake/LayerShellQt/LayerShellQtConfig.cmake 2>/dev/null \
        || ls /usr/lib*/cmake/LayerShellQt/LayerShellQtConfig.cmake 2>/dev/null
}

# -------------------------------------------------------------------
# Main
# -------------------------------------------------------------------
info "LXQt Panel source build"
echo "  Source dir : $SRC_ROOT"
echo "  Prefix     : $PREFIX"
echo "  Jobs       : $JOBS"
echo "  Distro     : ${PRETTY_NAME:-$OS}"

mkdir -p "$SRC_ROOT"
cd "$SRC_ROOT"

install_build_deps

# Layer-shell is mandatory for docking on labwc.
if layershell_available; then
    pass "LayerShellQt already present — skipping source build."
else
    warn "LayerShellQt not found — building from source."
    build_repo layer-shell-qt https://github.com/KDE/layer-shell-qt.git
fi

info "Building LXQt support libraries (these are usually not packaged)..."
build_repo lxqt-build-tools   https://github.com/lxqt/lxqt-build-tools.git
build_repo libdbusmenu-lxqt   https://github.com/lxqt/libdbusmenu-lxqt.git
build_repo lxqt-menu-data     https://github.com/lxqt/lxqt-menu-data.git
build_repo libsysstat         https://github.com/lxqt/libsysstat.git
build_repo liblxqt            https://github.com/lxqt/liblxqt.git
build_repo lxqt-globalkeys    https://github.com/lxqt/lxqt-globalkeys.git

info "Building lxqt-panel ..."
build_repo lxqt-panel         https://github.com/lxqt/lxqt-panel.git

if command -v lxqt-panel >/dev/null 2>&1; then
    pass "lxqt-panel installed: $(lxqt-panel --version 2>&1 | head -1)"
    echo -e "\n${GREEN}✓ Done.${NC} You can now run: ${CYAN}toggle-shell tworow${NC}"
else
    fail "lxqt-panel binary not found on PATH after install."
fi
