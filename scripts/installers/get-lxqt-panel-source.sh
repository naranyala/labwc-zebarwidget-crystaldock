#!/usr/bin/env bash
# -------------------------------------------------------------------
# get-lxqt-panel-source.sh
#
# Clone the lxqt-panel source code *and* the LXQt support libraries it
# builds against into the local ./sources directory (next to this script).
#
# This does NOT build or install anything — it only gathers source for
# inspection / offline builds / patching. Each repo is fetched as a
# shallow clone pinned to its latest release tag.
#
# Usage:
#   ./get-lxqt-panel-source.sh            # clone into ./sources
#   SRC_DIR=/somewhere ./get-lxqt-panel-source.sh
# -------------------------------------------------------------------

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "\n${CYAN}==>${NC} $*"; }
pass() { echo -e "  ${GREEN}✓${NC} $*"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $*"; }

# Destination: ./sources relative to this script's directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SRC_DIR:-$SCRIPT_DIR/sources}"
mkdir -p "$SRC_DIR"

# repo name -> git url
REPOS=(
    "lxqt-build-tools|https://github.com/lxqt/lxqt-build-tools.git"
    "libdbusmenu-lxqt|https://github.com/lxqt/libdbusmenu-lxqt.git"
    "lxqt-menu-data|https://github.com/lxqt/lxqt-menu-data.git"
    "libsysstat|https://github.com/lxqt/libsysstat.git"
    "liblxqt|https://github.com/lxqt/liblxqt.git"
    "lxqt-globalkeys|https://github.com/lxqt/lxqt-globalkeys.git"
    "lxqt-panel|https://github.com/lxqt/lxqt-panel.git"
)

# Resolve the latest semantic release tag from remote refs (no full clone).
latest_tag() {
    local url="$1"
    git ls-remote --tags --refs "$url" 2>/dev/null \
        | sed -E 's#.*refs/tags/##' \
        | grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)?(-[0-9A-Za-z.]+)?$' \
        | sort -V \
        | tail -n1
}

clone_repo() {
    local name="$1" url="$2"
    local dest="$SRC_DIR/$name"
    info "Cloning $name ..."
    rm -rf "$dest"

    local tag
    tag="$(latest_tag "$url" || true)"
    if [ -n "$tag" ]; then
        git clone --depth 1 --branch "$tag" "$url" "$dest"
        pass "$name @ $tag"
    else
        warn "$name: no release tags found — cloning default branch."
        git clone --depth 1 "$url" "$dest"
    fi
}

for entry in "${REPOS[@]}"; do
    IFS='|' read -r name url <<< "$entry"
    clone_repo "$name" "$url"
done

echo -e "\n${GREEN}✓ Done.${NC} lxqt-panel source gathered under: ${CYAN}$SRC_DIR${NC}"
echo "  Repos:"
for entry in "${REPOS[@]}"; do
    IFS='|' read -r name _ <<< "$entry"
    printf "    - sources/%s\n" "$name"
done
