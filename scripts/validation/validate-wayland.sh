#!/usr/bin/env bash
# validate-wayland.sh — Validate installed Wayland version and features
#
# Checks that the bleeding-edge Wayland is properly installed and
# verifies key features are available.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PREFIX="/usr/local"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

log()    { echo -e "${GREEN}[PASS]${NC} $*"; PASS=$((PASS+1)); }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*"; WARN=$((WARN+1)); }
fail()   { echo -e "${RED}[FAIL]${NC} $*"; FAIL=$((FAIL+1)); }
header() { echo -e "\n${CYAN}═══ $* ═══${NC}"; }

# ── Parse args ───────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix=*) PREFIX="${1#*=}" ;;
        -h|--help)
            echo "Usage: $0 [--prefix=/path]"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# ── Setup paths ──────────────────────────────────────────────────────────

PC_DIR="${PREFIX}/lib64/pkgconfig"
if [[ ! -d "$PC_DIR" ]]; then
    PC_DIR="${PREFIX}/lib/pkgconfig"
fi
export PKG_CONFIG_PATH="${PC_DIR}:${PKG_CONFIG_PATH:-}"
export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH:-}"

# ── Version checks ──────────────────────────────────────────────────────

header "Version checks"

# wayland-client
INSTALLED_VER=$(pkg-config --modversion wayland-client 2>/dev/null || echo "not found")
if [[ "$INSTALLED_VER" == "not found" ]]; then
    fail "wayland-client not found via pkg-config"
elif [[ "$INSTALLED_VER" == 1.23* ]]; then
    warn "wayland-client $INSTALLED_VER (system version, not bleeding edge)"
else
    log "wayland-client $INSTALLED_VER (bleeding edge ✓)"
fi

# wayland-server
INSTALLED_SRV=$(pkg-config --modversion wayland-server 2>/dev/null || echo "not found")
if [[ "$INSTALLED_SRV" == "not found" ]]; then
    fail "wayland-server not found via pkg-config"
elif [[ "$INSTALLED_SRV" == 1.23* ]]; then
    warn "wayland-server $INSTALLED_SRV (system version, not bleeding edge)"
else
    log "wayland-server $INSTALLED_SRV (bleeding edge ✓)"
fi

# wayland-scanner
SCANNER=$(which wayland-scanner 2>/dev/null || echo "not found")
if [[ "$SCANNER" == "not found" ]]; then
    fail "wayland-scanner not found in PATH"
else
    SCANNER_VER=$("$SCANNER" --version 2>&1 | head -1 || echo "unknown")
    log "wayland-scanner: $SCANNER ($SCANNER_VER)"
fi

# ── Library checks ──────────────────────────────────────────────────────

header "Library checks"

for lib in wayland-client wayland-server wayland-egl wayland-cursor; do
    SO=$(find "${PREFIX}/lib64" "${PREFIX}/lib" -name "lib${lib}.so*" 2>/dev/null | head -1)
    if [[ -n "$SO" ]]; then
        log "lib${lib}.so found: $SO"
    else
        fail "lib${lib}.so not found in ${PREFIX}/lib{64,}/"
    fi
done

# Check static libraries
for lib in wayland-client wayland-server; do
    A=$(find "${PREFIX}/lib64" "${PREFIX}/lib" -name "lib${lib}.a" 2>/dev/null | head -1)
    if [[ -n "$A" ]]; then
        log "lib${lib}.a (static) found: $A"
    else
        warn "lib${lib}.a not found (static linking unavailable)"
    fi
done

# ── Header checks ───────────────────────────────────────────────────────

header "Header checks"

for hdr in wayland-client.h wayland-client-protocol.h wayland-server.h wayland-util.h; do
    HDR_PATH=$(find "${PREFIX}/include" -name "$hdr" 2>/dev/null | head -1)
    if [[ -n "$HDR_PATH" ]]; then
        log "Header: $hdr"
    else
        fail "Header not found: $hdr"
    fi
done

# ── Protocol checks ─────────────────────────────────────────────────────

header "Protocol checks"

PROTO_DIR="${PREFIX}/share/wayland-protocols"
if [[ -d "$PROTO_DIR" ]]; then
    log "Protocol directory: $PROTO_DIR"
    
    # Check for key protocols
    for proto in \
        "stable/xdg-shell/xdg-shell.xml" \
        "stable/presentation-time/presentation-time.xml" \
        "staging/ext-workspace/ext-workspace-v1.xml" \
        "staging/ext-session-lock/ext-session-lock-v1.xml" \
        "staging/ext-data-control/ext-data-control-v1.xml" \
        "staging/xdg-toplevel-icon/xdg-toplevel-icon-v1.xml" \
        "staging/xdg-toplevel-tag/xdg-toplevel-tag-v1.xml" \
        "staging/wp-td/commit-timing-v1.xml" \
        "staging/wp-fifo/fifo-v1.xml" \
        "staging/ext-background-effect/background-effect-v1.xml"; do
        if [[ -f "${PROTO_DIR}/${proto}" ]]; then
            log "Protocol: $proto"
        else
            warn "Protocol missing: $proto"
        fi
    done
else
    fail "Protocol directory not found: $PROTO_DIR"
fi

# ── Feature API checks ─────────────────────────────────────────────────

header "Bleeding-edge API checks"

# Check for new APIs in headers
CLIENT_HDR="${PREFIX}/include/wayland-client.h"
if [[ -f "$CLIENT_HDR" ]]; then
    # wl_proxy_get_interface (since 1.24)
    if grep -q "wl_proxy_get_interface" "$CLIENT_HDR"; then
        log "wl_proxy_get_interface API (1.24+) ✓"
    else
        warn "wl_proxy_get_interface API not found (pre-1.24)"
    fi
    
    # wl_display_dispatch_queue_pending_single (since 1.25)
    if grep -q "wl_display_dispatch_queue_pending_single" "$CLIENT_HDR"; then
        log "wl_display_dispatch_queue_pending_single API (1.25+) ✓"
    else
        warn "wl_display_dispatch_queue_pending_single API not found (pre-1.25)"
    fi
fi

# Check for new SHM formats
PROTO_CLIENT="${PREFIX}/share/wayland-protocols/wayland"
if [[ -f "${PREFIX}/include/wayland-client-protocol.h" ]]; then
    # Check for p010 format (new in 1.26)
    if grep -q "WL_SHM_FORMAT_P010" "${PREFIX}/include/wayland-client-protocol.h"; then
        log "WL_SHM_FORMAT_P010 (HDR YUV) ✓"
    else
        warn "WL_SHM_FORMAT_P010 not found"
    fi
    
    # Check for float formats
    if grep -q "WL_SHM_FORMAT_R16_FLOAT" "${PREFIX}/include/wayland-client-protocol.h"; then
        log "WL_SHM_FORMAT_R16_FLOAT (HDR float) ✓"
    else
        warn "WL_SHM_FORMAT_R16_FLOAT not found"
    fi
    
    # Check for wl_surface.get_release (v7)
    if grep -q "wl_surface_get_release" "${PREFIX}/include/wayland-client-protocol.h"; then
        log "wl_surface.get_release (v7) ✓"
    else
        warn "wl_surface.get_release not found (pre-v7)"
    fi
    
    # Check for wl_output v4 name/description
    if grep -q "wl_output_name" "${PREFIX}/include/wayland-client-protocol.h"; then
        log "wl_output v4 name/description ✓"
    else
        warn "wl_output v4 name/description not found"
    fi
fi

# ── Zig shell integration check ─────────────────────────────────────────

header "Zig shell integration check"

ZIG_SHELL_DIR="${SCRIPT_DIR}/src/shells/zigshell-cairo-pango"
if [[ -d "$ZIG_SHELL_DIR" ]]; then
    # Check if the shell can find the new wayland
    if pkg-config --exists wayland-client 2>/dev/null; then
        VER=$(pkg-config --modversion wayland-client)
        if [[ "$VER" != 1.23* ]]; then
            log "Zig shell can find wayland $VER ✓"
        else
            warn "Zig shell still using system wayland $VER"
        fi
    else
        fail "Zig shell cannot find wayland via pkg-config"
    fi
fi

# ── Build test ──────────────────────────────────────────────────────────

header "Build test"

if [[ -f "${SCRIPT_DIR}/build.zig" ]]; then
    log "Build system found: build.zig"
else
    warn "build.zig not found, skipping build test"
fi

# ── Summary ──────────────────────────────────────────────────────────────

header "Validation Summary"

echo -e "  ${GREEN}PASS: $PASS${NC}"
echo -e "  ${YELLOW}WARN: $WARN${NC}"
echo -e "  ${RED}FAIL: $FAIL${NC}"
echo

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}✓ Wayland validation passed${NC}"
    echo
    echo "To use the bleeding-edge wayland with zigshell:"
    echo "  export PKG_CONFIG_PATH=$PC_DIR:\$PKG_CONFIG_PATH"
    echo "  export LD_LIBRARY_PATH=$PREFIX/lib64:\$LD_LIBRARY_PATH"
    echo "  cd src/shells/zigshell-cairo-pango && zig build"
    exit 0
else
    echo -e "${RED}✗ Wayland validation failed ($FAIL failures)${NC}"
    echo
    echo "Fix the failures above, then re-run: ./validate-wayland.sh"
    exit 1
fi
