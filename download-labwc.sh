#!/bin/bash
#
# download-labwc.sh — Download, build, and install labwc from source
#
# Usage:
#   ./download-labwc.sh                Build latest release
#   ./download-labwc.sh --install      Build + install to PREFIX
#   ./download-labwc.sh --check        Check current vs latest version
#   ./download-labwc.sh --master       Build from master branch
#   ./download-labwc.sh --clean        Remove cached source and build
#   ./download-labwc.sh --list         List available releases
#   ./download-labwc.sh --version      Show installed labwc version
#
# Environment:
#   PREFIX    Install prefix (default: ~/.local)
#   JOBS      Parallel build jobs (default: nproc)
#

set -euo pipefail

# ============================================================
# Configuration
# ============================================================

REPO="labwc/labwc"
PREFIX="${PREFIX:-$HOME/.local}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_DIR="$PROJECT_DIR/build"
SRC_DIR="$CACHE_DIR/labwc-src"
BUILD_DIR="$SRC_DIR/build"
VERSION_FILE="$CACHE_DIR/labwc-version.txt"

# ============================================================
# Colors
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "${CYAN}-->${NC} $*"; }
pass()  { echo -e "${GREEN}  ✓${NC} $*"; }
warn()  { echo -e "${YELLOW}  !${NC} $*"; }
fail()  { echo -e "${RED}  ✗${NC} $*"; exit 1; }
header() { echo -e "\n${BOLD}== $* ==${NC}"; }

# ============================================================
# Helpers
# ============================================================

get_installed_version() {
  if command -v labwc &>/dev/null; then
    labwc --version 2>/dev/null | grep -oP '[\d.]+' | head -1 || echo "unknown"
  else
    echo "not installed"
  fi
}

get_latest_release() {
  local api_url="https://api.github.com/repos/$REPO/releases/latest"
  local tag
  tag=$(curl -sfL "$api_url" 2>/dev/null | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
  echo "${tag:-}"
}

get_latest_commit() {
  local api_url="https://api.github.com/repos/$REPO/commits/master"
  local sha
  sha=$(curl -sfL "$api_url" 2>/dev/null | grep '"sha"' | head -1 | sed 's/.*"sha": *"\([^"]*\)".*/\1/')
  echo "${sha:0:7}"
}

get_cached_version() {
  if [ -f "$VERSION_FILE" ]; then
    cat "$VERSION_FILE"
  else
    echo ""
  fi
}

check_dependencies() {
  header "Checking Build Dependencies"

  local missing=()

  # Build tools
  for cmd in meson ninja gcc pkg-config git curl; do
    if command -v "$cmd" &>/dev/null; then
      pass "$cmd: $(command -v "$cmd")"
    else
      missing+=("$cmd")
    fi
  done

  # Libraries
  local libs=(wayland-client libxml-2.0 cairo pangocairo glib-2.0 libinput libpng xkbcommon)
  for lib in "${libs[@]}"; do
    if pkg-config --exists "$lib" 2>/dev/null; then
      pass "lib: $lib"
    else
      missing+=("$lib (dev package)")
    fi
  done

  # wlroots (special case: multiple version names)
  if pkg-config --exists wlroots 2>/dev/null || \
     pkg-config --exists wlroots-0.19 2>/dev/null || \
     pkg-config --exists wlroots-0.18 2>/dev/null || \
     pkg-config --exists wlroots-0.17 2>/dev/null; then
    pass "lib: wlroots"
  else
    missing+=("wlroots (dev package)")
  fi

  if [ ${#missing[@]} -gt 0 ]; then
    echo ""
    fail "Missing: ${missing[*]}"
    echo ""
    echo "Install on Debian/Ubuntu:"
    echo "  sudo apt install meson ninja-build gcc pkg-config git curl \\"
    echo "    libwayland-dev libwlroots-dev libxml2-dev libcairo2-dev \\"
    echo "    libpango1.0-dev libglib2.0-dev libinput-dev libpng-dev libxkbcommon-dev"
    echo ""
    echo "Install on Arch:"
    echo "  sudo pacman -S meson ninja gcc pkg-config git curl \\"
    echo "    wayland wlroots libxml2 cairo pango glib2 libinput libpng libxkbcommon"
    echo ""
    echo "Install on Fedora:"
    echo "  sudo dnf install meson ninja-build gcc pkg-config git curl \\"
    echo "    wayland-devel wlroots-devel libxml2-devel cairo-devel \\"
    echo "    pango-devel glib2-devel libinput-devel libpng-devel libxkbcommon-devel"
    exit 1
  fi

  pass "All dependencies satisfied"
}

# ============================================================
# Commands
# ============================================================

cmd_version() {
  header "labwc Version Info"

  local installed
  installed=$(get_installed_version)
  if [ "$installed" = "not installed" ]; then
    warn "labwc: not installed"
  else
    pass "Installed: $installed"
  fi

  if [ -f "$VERSION_FILE" ]; then
    pass "Cached source: $(cat "$VERSION_FILE")"
  else
    info "No cached source"
  fi

  if command -v labwc &>/dev/null; then
    local path
    path=$(command -v labwc)
    pass "Binary: $path"
    pass "Prefix: $(dirname "$(dirname "$path")")"
  fi
}

cmd_check() {
  header "Version Check"

  local installed latest cached
  installed=$(get_installed_version)
  latest=$(get_latest_release)
  cached=$(get_cached_version)

  pass "Installed: $installed"
  pass "Latest release: ${latest:-unable to fetch}"
  pass "Cached source: ${cached:-none}"

  if [ -n "$latest" ] && [ "$installed" != "not installed" ]; then
    if [ "$installed" = "$latest" ]; then
      echo ""
      pass "Up to date"
    else
      echo ""
      warn "Update available: $installed -> $latest"
      echo "  Run: $0 --install"
    fi
  fi
}

cmd_list() {
  header "Available Releases"

  local api_url="https://api.github.com/repos/$REPO/releases?per_page=10"
  local releases
  releases=$(curl -sfL "$api_url" 2>/dev/null)

  if [ -z "$releases" ]; then
    fail "Could not fetch releases from GitHub"
  fi

  echo "$releases" | grep -oP '"tag_name": *"\K[^"]+' | while read -r tag; do
    echo "  $tag"
  done
}

cmd_clean() {
  header "Cleaning Build Cache"

  if [ -d "$CACHE_DIR" ]; then
    local size
    size=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)
    rm -rf "$CACHE_DIR"
    pass "Removed build/ ($size)"
  else
    info "Nothing to clean"
  fi
}

cmd_build() {
  local use_master=false
  local do_install=false

  for arg in "$@"; do
    case "$arg" in
      --master) use_master=true ;;
      --install) do_install=true ;;
    esac
  done

  check_dependencies

  # Determine target version
  local target
  if $use_master; then
    target="master"
    info "Target: master branch (latest commit)"
  else
    target=$(get_latest_release)
    if [ -z "$target" ]; then
      warn "Could not fetch latest release, falling back to master"
      target="master"
    else
      info "Target: $target (latest release)"
    fi
  fi

  # Check if already built
  local cached
  cached=$(get_cached_version)
  if [ "$cached" = "$target" ] && [ -f "$BUILD_DIR/src/labwc" ]; then
    info "Already built: $target"
    if $do_install; then
      cmd_install "$target"
    else
      info "Use --install to install, or run $0 --clean to rebuild"
    fi
    return 0
  fi

  # Clone or update source
  header "Downloading Source"

  if [ -d "$SRC_DIR/.git" ]; then
    # Existing repo — fetch and checkout
    info "Updating existing source..."
    cd "$SRC_DIR"
    git fetch --all --tags 2>/dev/null || true
    if [ "$target" = "master" ]; then
      git checkout master 2>/dev/null || git checkout main 2>/dev/null
      git pull --ff-only 2>/dev/null || true
    else
      git checkout "$target" 2>/dev/null || {
        info "Tag $target not found locally, fetching..."
        git fetch origin tag "$target" 2>/dev/null
        git checkout "$target" 2>/dev/null || fail "Could not checkout $target"
      }
    fi
    pass "Source updated to $target"
  else
    # Fresh clone
    mkdir -p "$CACHE_DIR"
    info "Cloning labwc..."
    if [ "$target" = "master" ]; then
      git clone "https://github.com/$REPO.git" "$SRC_DIR"
    else
      git clone --branch "$target" --depth=1 "https://github.com/$REPO.git" "$SRC_DIR"
    fi
    pass "Source cloned"
  fi

  # Record version
  echo "$target" > "$VERSION_FILE"

  # Build
  header "Building labwc $target"

  cd "$SRC_DIR"

  # Clean previous build if target changed
  if [ -d "$BUILD_DIR" ] && [ "$cached" != "$target" ]; then
    rm -rf "$BUILD_DIR"
  fi

  info "meson setup (prefix=$PREFIX)..."
  meson setup "$BUILD_DIR" --prefix="$PREFIX" --reconfigure 2>/dev/null || \
    meson setup "$BUILD_DIR" --prefix="$PREFIX"

  info "Compiling with $JOBS jobs..."
  meson compile -C "$BUILD_DIR" -j"$JOBS"

  pass "Build successful"

  # Install
  if $do_install; then
    cmd_install "$target"
  else
    echo ""
    info "Build complete. To install:"
    info "  $0 --install"
    info "  # or"
    info "  sudo meson install -C $BUILD_DIR"
  fi
}

cmd_install() {
  local target="${1:-$(get_cached_version)}"
  [ -z "$target" ] && target="unknown"

  header "Installing labwc $target"

  if [ ! -d "$BUILD_DIR" ]; then
    fail "Build directory not found. Run: $0 --build"
  fi

  # Check if sudo needed for PREFIX
  if [ -w "$(dirname "$PREFIX")" ] 2>/dev/null || [ "$(id -u)" -eq 0 ]; then
    info "Installing to $PREFIX..."
    meson install -C "$BUILD_DIR" --skip-subprojects
  else
    info "Installing to $PREFIX (requires sudo)..."
    sudo meson install -C "$BUILD_DIR" --skip-subprojects
  fi

  pass "labwc $target installed to $PREFIX"

  # Verify
  if command -v labwc &>/dev/null; then
    pass "labwc available: $(command -v labwc)"
    pass "Version: $(labwc --version 2>/dev/null || echo 'unknown')"
  else
    warn "labwc not in PATH yet"
    echo "  Add to your shell profile:"
    echo "    export PATH=\"$PREFIX/bin:\$PATH\""
    echo "  Or log out and back in."
  fi
}

# ============================================================
# Main
# ============================================================

case "${1:-}" in
  --install|-i)
    cmd_build --install
    ;;
  --build|-b)
    cmd_build
    ;;
  --check|-c)
    cmd_check
    ;;
  --master|-m)
    cmd_build --master
    ;;
  --clean)
    cmd_clean
    ;;
  --list|-l)
    cmd_list
    ;;
  --version|-v)
    cmd_version
    ;;
  --help|-h)
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  (none)       Build latest release"
    echo "  --install    Build + install to PREFIX (default: ~/.local)"
    echo "  --check      Show installed vs latest version"
    echo "  --master     Build from master branch"
    echo "  --clean      Remove cached source and build artifacts"
    echo "  --list       List available releases"
    echo "  --version    Show installed labwc version"
    echo "  --help       Show this help"
    echo ""
    echo "Environment:"
    echo "  PREFIX       Install prefix (default: ~/.local)"
    echo "  JOBS         Parallel build jobs (default: nproc)"
    echo ""
    echo "Examples:"
    echo "  $0                         # Build latest release"
    echo "  $0 --install               # Build + install"
    echo "  $0 --check                 # Check if update available"
    echo "  $0 --master --install      # Build + install from master"
    echo "  PREFIX=/usr/local $0 -i   # Install to /usr/local"
    echo ""
    ;;
  *)
    cmd_build
    ;;
esac
