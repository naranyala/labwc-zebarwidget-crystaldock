#!/usr/bin/env bash
# download-wayland.sh — Download latest Wayland source trees into ./sources/
#
# Downloads: wayland, wayland-protocols, wayland-scanner (part of wayland)
# These are the core libraries needed for building Wayland clients/compositors.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCES_DIR="${SCRIPT_DIR}/sources"
mkdir -p "$SOURCES_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*" >&2; }

# ── Helpers ──────────────────────────────────────────────────────────────

clone_or_update() {
    local repo="$1" dest="$2"
    if [ -d "$dest/.git" ]; then
        log "Updating $(basename "$dest")..."
        git -C "$dest" pull --ff-only -q 2>/dev/null || {
            warn "Pull failed, resetting to origin/HEAD"
            git -C "$dest" fetch origin -q
            git -C "$dest" reset --hard origin/HEAD -q 2>/dev/null || true
        }
    else
        log "Cloning $(basename "$dest")..."
        git clone --depth 1 "$repo" "$dest" 2>/dev/null || {
            # Fallback: shallow clone with default branch
            git clone "$repo" "$dest" 2>/dev/null || {
                err "Failed to clone $repo"
                return 1
            }
        }
    fi
}

get_tag() {
    local dir="$1"
    git -C "$dir" describe --tags --abbrev=0 2>/dev/null || git -C "$dir" rev-parse --short HEAD
}

get_branch() {
    local dir="$1"
    git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"
}

# ── Core Wayland libraries ───────────────────────────────────────────────

log "=== Downloading Wayland sources to $SOURCES_DIR ==="
echo

# 1. wayland — core library + scanner
clone_or_update "https://gitlab.freedesktop.org/wayland/wayland.git" \
    "$SOURCES_DIR/wayland"

# 2. wayland-protocols — protocol XML definitions
clone_or_update "https://gitlab.freedesktop.org/wayland/wayland-protocols.git" \
    "$SOURCES_DIR/wayland-protocols"

# 3. wayland-protocols-extra — additional protocols (wlr-layer-shell, etc.)
clone_or_update "https://gitlab.freedesktop.org/kennylevinsen/wayland-protocols-extra.git" \
    "$SOURCES_DIR/wayland-protocols-extra" 2>/dev/null || warn "wayland-protocols-extra clone failed (optional)"

# 4. libdisplay-info — DRM display info library (used by wlroots-based compositors)
clone_or_update "https://gitlab.freedesktop.org/emersion/libdisplay-info.git" \
    "$SOURCES_DIR/libdisplay-info" 2>/dev/null || warn "libdisplay-info clone failed (optional)"

# ── Summary ──────────────────────────────────────────────────────────────

echo
log "=== Downloaded Wayland sources ==="
echo

printf "%-30s %-12s %s\n" "REPOSITORY" "BRANCH" "VERSION"
printf "%-30s %-12s %s\n" "----------" "------" "-------"

for dir in "$SOURCES_DIR"/wayland "$SOURCES_DIR"/wayland-protocols "$SOURCES_DIR"/wayland-protocols-extra "$SOURCES_DIR"/libdisplay-info; do
    if [ -d "$dir/.git" ]; then
        name=$(basename "$dir")
        branch=$(get_branch "$dir")
        tag=$(get_tag "$dir")
        printf "%-30s %-12s %s\n" "$name" "$branch" "$tag"
    fi
done

echo
log "Done. Source trees at: $SOURCES_DIR/"
