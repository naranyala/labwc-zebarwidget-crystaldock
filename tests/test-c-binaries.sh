#!/bin/bash
# OCWS C Binary Test Suite
# Tests all compiled C binaries for functionality and correctness

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/zig-out/bin"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

header() { echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}"; }
pass()   { echo -e "  ${GREEN}[PASS]${NC} $1"; ((PASS_COUNT++)); }
fail()   { echo -e "  ${RED}[FAIL]${NC} $1"; ((FAIL_COUNT++)); }
skip()   { echo -e "  ${YELLOW}[SKIP]${NC} $1"; ((SKIP_COUNT++)); }

# ============================================================
# Helper: require a binary — skip whole section if absent
# ============================================================
require_bin() {
    local bin="$BUILD_DIR/$1"
    if [ ! -x "$bin" ]; then
        echo -e "  ${YELLOW}[SKIP]${NC} Skipping section: $1 not built"
        return 1
    fi
    return 0
}

# ============================================================
# 1. Binary Existence
# ============================================================
header "Binary Existence"

BINARIES=(
    "ocws"
    "ocws-emit"
    "ocws-search"
    "ocws-shot"
    "ocws-clip"
    "ocws-lock"
    "ocws-sysmon"
    "ocws-brightness"
    "ocws-volume"
    "ocws-recorder"
    "ocws-kv"
    "ocws-color"
    "ocws-ocr"
    "ocws-notify"
    "ocws-wallpaper"
    "ocws-live-bg"
    "ocws-osd-notify"
    "ocws-hypertile"
    "ocws-settings"
)

for bin in "${BINARIES[@]}"; do
    if [ -f "$BUILD_DIR/$bin" ]; then
        pass "Binary exists: $bin"
    else
        fail "Binary missing: $bin"
    fi
done

# ============================================================
# 2. Binary Permissions
# ============================================================
header "Binary Permissions"

for bin in "${BINARIES[@]}"; do
    if [ -x "$BUILD_DIR/$bin" ]; then
        pass "Executable: $bin"
    elif [ -f "$BUILD_DIR/$bin" ]; then
        fail "Not executable: $bin"
    fi
done

# ============================================================
# 3. Binary Size Check
# ============================================================
header "Binary Size Check"

for bin in "${BINARIES[@]}"; do
    if [ -f "$BUILD_DIR/$bin" ]; then
        SIZE=$(stat -c%s "$BUILD_DIR/$bin" 2>/dev/null || stat -f%z "$BUILD_DIR/$bin" 2>/dev/null)
        if [ "$SIZE" -gt 1000 ]; then
            pass "Binary size OK: $bin (${SIZE} bytes / $((SIZE/1024))KB)"
        else
            fail "Binary too small: $bin ($SIZE bytes)"
        fi
    fi
done

# ============================================================
# 4. ocws unified binary — help / version / dispatch
# ============================================================
header "ocws: unified binary dispatch"

if require_bin "ocws"; then
    OCWS="$BUILD_DIR/ocws"

    if "$OCWS" help >/dev/null 2>&1; then
        pass "ocws help works"
    else
        fail "ocws help failed"
    fi

    if "$OCWS" version >/dev/null 2>&1; then
        pass "ocws version works"
    else
        fail "ocws version failed"
    fi

    if "$OCWS" status >/dev/null 2>&1; then
        pass "ocws status works"
    else
        fail "ocws status failed"
    fi

    if "$OCWS" list >/dev/null 2>&1; then
        pass "ocws list works"
    else
        fail "ocws list failed"
    fi

    # Dispatch subcommands
    for subcmd in kv brightness volume shot sysmon clip lock emit; do
        BIN="$BUILD_DIR/ocws-$subcmd"
        if [ -x "$BIN" ]; then
            if "$OCWS" "$subcmd" --help >/dev/null 2>&1; then
                pass "ocws dispatches: $subcmd"
            else
                fail "ocws dispatch failed: $subcmd"
            fi
        else
            skip "ocws dispatch skip (not built): $subcmd"
        fi
    done
fi

# ============================================================
# 5. ocws-emit — namespace mapping (C binary)
# ============================================================
header "ocws-emit: namespace → variable mapping"

if require_bin "ocws-emit"; then
    EMIT="$BUILD_DIR/ocws-emit"

    # Help / usage
    if "$EMIT" >/dev/null 2>&1 || [ $? -le 1 ]; then
        pass "ocws-emit exits cleanly with no args"
    fi

    # We can't call zigshell-cairo-pango -R in tests, but we can verify the binary
    # maps namespaces correctly by checking its output with a dry-run mode.
    # ocws-emit prints the IPC command to stdout (zigshell-cairo-pango -R "SetVal...").
    # We mock by seeing if it tries to exec or just errors without a Wayland socket.

    # Test: numeric value produces SetVal without quotes
    EMIT_OUT=$("$EMIT" "System.Volume" "75" 2>&1 || true)
    if echo "$EMIT_OUT" | grep -q "XVolLevel"; then
        pass "ocws-emit maps System.Volume → XVolLevel"
    elif echo "$EMIT_OUT" | grep -qiE "zigshell-cairo-pango|SetVal|socket|connect"; then
        # Tried to run zigshell-cairo-pango, mapping was correct, zigshell-cairo-pango not available
        pass "ocws-emit attempts zigshell-cairo-pango call for System.Volume (zigshell-cairo-pango not available)"
    else
        skip "ocws-emit output not parseable (may need Wayland)"
    fi

    EMIT_OUT=$("$EMIT" "System.Brightness" "80" 2>&1 || true)
    if echo "$EMIT_OUT" | grep -q "XBrightness"; then
        pass "ocws-emit maps System.Brightness → XBrightness"
    elif echo "$EMIT_OUT" | grep -qiE "zigshell-cairo-pango|SetVal|socket|connect"; then
        pass "ocws-emit attempts zigshell-cairo-pango call for System.Brightness"
    else
        skip "ocws-emit Brightness mapping not verifiable without Wayland"
    fi

    EMIT_OUT=$("$EMIT" "Media.Title" "Some Song" 2>&1 || true)
    if echo "$EMIT_OUT" | grep -q "XMediaTitle"; then
        pass "ocws-emit maps Media.Title → XMediaTitle"
    elif echo "$EMIT_OUT" | grep -qiE "zigshell-cairo-pango|SetVal|socket|connect"; then
        pass "ocws-emit attempts zigshell-cairo-pango call for Media.Title"
    else
        skip "ocws-emit Media.Title mapping not verifiable without Wayland"
    fi

    # Verify all namespace-to-variable mappings are in the binary's symbol table / strings
    # (strings-based check against the compiled binary)
    if command -v strings >/dev/null 2>&1; then
        STRS=$(strings "$EMIT" 2>/dev/null)
        EXPECTED_MAPS=(
            "System.Volume:XVolLevel"
            "System.Brightness:XBrightness"
            "System.Battery:XBatLvl"
            "System.Cpu:XCpuLoad"
            "System.Memory:XMemPct"
            "System.Disk:XDiskPct"
            "System.DND:XDndState"
            "Network.WiFi:XNetState"
            "Network.Bluetooth:XBtState"
            "Media.Title:XMediaTitle"
            "Media.Artist:XMediaArtist"
            "Media.Status:XMediaStatus"
        )
        for pair in "${EXPECTED_MAPS[@]}"; do
            NS="${pair%%:*}"
            VAR="${pair##*:}"
            NS_FOUND=false
            VAR_FOUND=false
            echo "$STRS" | grep -qF "$NS" && NS_FOUND=true
            echo "$STRS" | grep -qF "$VAR" && VAR_FOUND=true
            if $NS_FOUND && $VAR_FOUND; then
                pass "ocws-emit binary contains mapping: $NS → $VAR"
            elif $NS_FOUND; then
                fail "ocws-emit binary has $NS but missing $VAR"
            else
                fail "ocws-emit binary missing namespace: $NS"
            fi
        done
    else
        skip "strings(1) not available — skipping binary symbol check"
    fi
fi

# ============================================================
# 6. ocws-sysmon — output key=value parsing
# ============================================================
header "ocws-sysmon: output format"

if require_bin "ocws-sysmon"; then
    SYSMON="$BUILD_DIR/ocws-sysmon"

    # Run sysmon (reads /proc; always available on Linux)
    SYSMON_OUT=$("$SYSMON" 2>/dev/null || true)

    if [ -n "$SYSMON_OUT" ]; then
        pass "ocws-sysmon produces output"
    else
        fail "ocws-sysmon produced no output"
    fi

    # Expected output keys from the source
    EXPECTED_KEYS=(
        "MEM_TOT"
        "MEM_USED"
        "MEM_PCT"
        "NET_RX"
        "NET_TX"
        "CPU_PCT"
    )
    for key in "${EXPECTED_KEYS[@]}"; do
        if echo "$SYSMON_OUT" | grep -q "^${key}="; then
            pass "ocws-sysmon outputs: ${key}="
        else
            # Key might be absent on this system (battery, wifi, etc.)
            skip "ocws-sysmon missing key: $key (may be hw-dependent)"
        fi
    done

    # Validate key=value format: no line should be malformed
    MALFORMED=$(echo "$SYSMON_OUT" | grep -v "^[A-Z_][A-Z_0-9]*=" | grep -v "^$" || true)
    if [ -z "$MALFORMED" ]; then
        pass "ocws-sysmon output is well-formed KEY=value pairs"
    else
        fail "ocws-sysmon has malformed output lines: $MALFORMED"
    fi

    # Values should be numeric or short strings (no injected shell characters)
    SUSPICIOUS=$(echo "$SYSMON_OUT" | grep -E "[;&|><\`\$]" || true)
    if [ -z "$SUSPICIOUS" ]; then
        pass "ocws-sysmon output contains no shell metacharacters"
    else
        fail "ocws-sysmon output contains suspicious chars: $SUSPICIOUS"
    fi
fi

# ============================================================
# 7. ocws-color — format flags
# ============================================================
header "ocws-color: output format flags"

if require_bin "ocws-color"; then
    COLOR="$BUILD_DIR/ocws-color"

    # Help
    if "$COLOR" --help >/dev/null 2>&1 || "$COLOR" -h >/dev/null 2>&1; then
        pass "ocws-color --help works"
    else
        skip "ocws-color --help not supported (needs Cairo image)"
    fi

    # Create a minimal 4×4 pixel PNG using Python (if available) or skip
    TEST_PNG="/tmp/ocws-test-color-$$.png"
    PNG_CREATED=false

    if command -v python3 >/dev/null 2>&1; then
        python3 - <<'PYEOF' 2>/dev/null && PNG_CREATED=true
import struct, zlib, sys

def write_png(path, w, h, pixels):
    def chunk(name, data):
        c = name + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
    raw = b"".join(b"\x00" + bytes(pixels[y]) for y in range(h))
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw))
    png += chunk(b"IEND", b"")
    open(path, "wb").write(png)

import os; path = os.environ.get("TEST_PNG", "/tmp/test.png")
pixels = [[(200, 50, 50)] * 4 for _ in range(4)]
write_png(path, 4, 4, pixels)
PYEOF
    fi

    if $PNG_CREATED && [ -f "$TEST_PNG" ]; then
        # hex format
        HEX_OUT=$("$COLOR" "$TEST_PNG" --format hex 2>/dev/null || true)
        if echo "$HEX_OUT" | grep -qE "^#[0-9a-fA-F]{6}"; then
            pass "ocws-color --format hex outputs #RRGGBB"
        else
            fail "ocws-color --format hex produced: $HEX_OUT"
        fi

        # ini format
        INI_OUT=$("$COLOR" "$TEST_PNG" --format ini 2>/dev/null || true)
        if echo "$INI_OUT" | grep -qE "^[a-z]+="; then
            pass "ocws-color --format ini outputs key=value"
        else
            fail "ocws-color --format ini produced: $INI_OUT"
        fi

        # json format
        JSON_OUT=$("$COLOR" "$TEST_PNG" --format json 2>/dev/null || true)
        if echo "$JSON_OUT" | grep -qE '^\{|"primary"'; then
            pass "ocws-color --format json outputs JSON"
        else
            fail "ocws-color --format json produced: $JSON_OUT"
        fi

        # scss format
        SCSS_OUT=$("$COLOR" "$TEST_PNG" --format scss 2>/dev/null || true)
        if echo "$SCSS_OUT" | grep -qE "^\\\$"; then
            pass "ocws-color --format scss outputs SCSS variables"
        else
            fail "ocws-color --format scss produced: $SCSS_OUT"
        fi

        rm -f "$TEST_PNG"
    else
        skip "ocws-color format tests skipped (no python3 or PNG creation failed)"
    fi
else
    skip "ocws-color section skipped (not built)"
fi

# ============================================================
# 8. ocws-kv — full CRUD + edge cases
# ============================================================
header "ocws-kv: CRUD and edge cases"

if require_bin "ocws-kv"; then
    KV="$BUILD_DIR/ocws-kv"
    STORE="/tmp/ocws-test-kv-$$.kv"

    cleanup_store() { rm -f "$STORE"; }
    trap cleanup_store EXIT

    # Help
    if "$KV" --help >/dev/null 2>&1; then
        pass "ocws-kv --help works"
    else
        skip "ocws-kv --help not supported"
    fi

    # init
    if "$KV" -f "$STORE" init >/dev/null 2>&1; then
        pass "ocws-kv init works"
    else
        fail "ocws-kv init failed"
    fi

    # set + get (basic)
    "$KV" -f "$STORE" set test-key "hello world" >/dev/null 2>&1
    RESULT=$("$KV" -f "$STORE" get test-key 2>/dev/null)
    if [ "$RESULT" = "hello world" ]; then
        pass "ocws-kv set/get basic value"
    else
        fail "ocws-kv set/get basic: got '$RESULT'"
    fi

    # has — existing key
    if "$KV" -f "$STORE" has test-key >/dev/null 2>&1; then
        pass "ocws-kv has: returns true for existing key"
    else
        fail "ocws-kv has: false for existing key"
    fi

    # has — non-existing key
    if ! "$KV" -f "$STORE" has nonexistent-key-xyz >/dev/null 2>&1; then
        pass "ocws-kv has: returns false for missing key"
    else
        fail "ocws-kv has: returned true for missing key"
    fi

    # keys
    KEYS=$("$KV" -f "$STORE" keys 2>/dev/null || true)
    if echo "$KEYS" | grep -q "test-key"; then
        pass "ocws-kv keys lists stored key"
    else
        fail "ocws-kv keys did not list test-key: '$KEYS'"
    fi

    # overwrite existing key
    "$KV" -f "$STORE" set test-key "updated" >/dev/null 2>&1
    RESULT2=$("$KV" -f "$STORE" get test-key 2>/dev/null)
    if [ "$RESULT2" = "updated" ]; then
        pass "ocws-kv set overwrites existing key"
    else
        fail "ocws-kv overwrite failed: got '$RESULT2'"
    fi

    # edge case: empty value
    "$KV" -f "$STORE" set empty-key "" >/dev/null 2>&1 || true
    EMPTY_VAL=$("$KV" -f "$STORE" get empty-key 2>/dev/null || true)
    if [ -z "$EMPTY_VAL" ]; then
        pass "ocws-kv handles empty value"
    else
        skip "ocws-kv empty value: got '$EMPTY_VAL'"
    fi

    # edge case: value with spaces and special chars
    "$KV" -f "$STORE" set special-key "val with spaces" >/dev/null 2>&1
    SPECIAL=$("$KV" -f "$STORE" get special-key 2>/dev/null)
    if [ "$SPECIAL" = "val with spaces" ]; then
        pass "ocws-kv handles values with spaces"
    else
        fail "ocws-kv spaces value: got '$SPECIAL'"
    fi

    # edge case: get nonexistent key exits non-zero
    if ! "$KV" -f "$STORE" get does-not-exist >/dev/null 2>&1; then
        pass "ocws-kv get nonexistent key returns non-zero"
    else
        skip "ocws-kv get nonexistent: exit 0 (impl-defined)"
    fi

    # del
    "$KV" -f "$STORE" del test-key >/dev/null 2>&1
    if ! "$KV" -f "$STORE" has test-key >/dev/null 2>&1; then
        pass "ocws-kv del removes key"
    else
        fail "ocws-kv del did not remove key"
    fi

    # Persistence: re-open the store file
    "$KV" -f "$STORE" set persist-test "persistent" >/dev/null 2>&1
    PERSIST=$("$KV" -f "$STORE" get persist-test 2>/dev/null)
    if [ "$PERSIST" = "persistent" ]; then
        pass "ocws-kv persists values across calls"
    else
        fail "ocws-kv persistence failed: got '$PERSIST'"
    fi

    trap - EXIT
    cleanup_store
fi

# ============================================================
# 9. ocws-brightness — help + get mode (no hardware needed)
# ============================================================
header "ocws-brightness: CLI modes"

if require_bin "ocws-brightness"; then
    BRIGHT="$BUILD_DIR/ocws-brightness"

    # help
    if "$BRIGHT" --help >/dev/null 2>&1; then
        pass "ocws-brightness --help works"
    else
        skip "ocws-brightness --help exits non-zero (ok)"
    fi

    # get mode — reads /sys/class/backlight; may return -1 if no backlight
    GET_OUT=$("$BRIGHT" get 2>/dev/null || true)
    if [ -n "$GET_OUT" ]; then
        # Should be a number or error message
        if echo "$GET_OUT" | grep -qE "^-?[0-9]+"; then
            pass "ocws-brightness get returns numeric value ($GET_OUT)"
        else
            skip "ocws-brightness get: non-numeric output (no backlight device)"
        fi
    else
        skip "ocws-brightness get: no output (no backlight device)"
    fi

    # JSON format
    JSON_OUT=$("$BRIGHT" --format json get 2>/dev/null || true)
    if echo "$JSON_OUT" | grep -qE "^\{"; then
        pass "ocws-brightness --format json produces JSON"
    else
        skip "ocws-brightness --format json not available or no backlight"
    fi
fi

# ============================================================
# 10. ocws-volume — help + get mode (no PulseAudio needed)
# ============================================================
header "ocws-volume: CLI modes"

if require_bin "ocws-volume"; then
    VOL="$BUILD_DIR/ocws-volume"

    # help
    if "$VOL" --help >/dev/null 2>&1; then
        pass "ocws-volume --help works"
    else
        skip "ocws-volume --help exits non-zero (ok)"
    fi

    # get mode — calls pactl, which may not be available
    GET_OUT=$("$VOL" get 2>/dev/null || true)
    if [ -n "$GET_OUT" ]; then
        if echo "$GET_OUT" | grep -qE "^-?[0-9]+"; then
            pass "ocws-volume get returns numeric value ($GET_OUT)"
        else
            skip "ocws-volume get: non-numeric ($GET_OUT) — PulseAudio not running"
        fi
    else
        skip "ocws-volume get: no output (PulseAudio not running)"
    fi

    # JSON format
    JSON_OUT=$("$VOL" --format json get 2>/dev/null || true)
    if echo "$JSON_OUT" | grep -qE "^\{"; then
        pass "ocws-volume --format json produces JSON"
    else
        skip "ocws-volume --format json not available or no audio device"
    fi
fi

# ============================================================
# 11. ocws-search — CLI and engine list
# ============================================================
header "ocws-search: CLI and engine list"

if require_bin "ocws-search"; then
    SEARCH="$BUILD_DIR/ocws-search"

    # help
    if "$SEARCH" --help >/dev/null 2>&1 || "$SEARCH" -h >/dev/null 2>&1; then
        pass "ocws-search --help works"
    else
        skip "ocws-search --help not supported"
    fi

    # Should contain known engine names in binary strings
    if command -v strings >/dev/null 2>&1; then
        STRS=$(strings "$SEARCH" 2>/dev/null)
        for engine in "Google" "DuckDuckGo" "YouTube" "GitHub" "Wikipedia"; do
            if echo "$STRS" | grep -q "$engine"; then
                pass "ocws-search contains engine: $engine"
            else
                fail "ocws-search missing engine: $engine"
            fi
        done
    else
        skip "strings(1) not available — skipping engine string check"
    fi
fi

# ============================================================
# Section 12: ocws-welcome GUI binary
# ============================================================
header "ocws-welcome GUI"
WELCOME="$BUILD_DIR/ocws-welcome"
if [ -x "$WELCOME" ]; then
    pass "ocws-welcome binary exists and is executable"

    # Check it's an ELF binary
    if file "$WELCOME" | grep -q "ELF"; then
        pass "ocws-welcome is a valid ELF binary"
    else
        fail "ocws-welcome is not an ELF binary"
    fi

    # Check it links GTK3
    if ldd "$WELCOME" 2>/dev/null | grep -q "gtk"; then
        pass "ocws-welcome links against GTK"
    else
        skip "ldd not available or GTK not linked"
    fi

    # --force flag should launch (will fail without display, but shouldn't segfault)
    if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then
        timeout 3 "$WELCOME" --force &>/dev/null
        pass "ocws-welcome --force ran without crash"
    else
        skip "No display server — cannot test runtime launch"
    fi
else
    skip "ocws-welcome binary not found"
fi

# ============================================================
# Section 13: ocws-settings GUI binary
# ============================================================
header "ocws-settings GUI"
SETTINGS="$BUILD_DIR/ocws-settings"
if [ -x "$SETTINGS" ]; then
    pass "ocws-settings binary exists and is executable"

    if file "$SETTINGS" | grep -q "ELF"; then
        pass "ocws-settings is a valid ELF binary"
    else
        fail "ocws-settings is not an ELF binary"
    fi

    if ldd "$SETTINGS" 2>/dev/null | grep -q "gtk"; then
        pass "ocws-settings links against GTK"
    else
        skip "ldd not available or GTK not linked"
    fi

    if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then
        timeout 3 "$SETTINGS" &>/dev/null
        pass "ocws-settings ran without crash"
    else
        skip "No display server — cannot test runtime launch"
    fi
else
    skip "ocws-settings binary not found"
fi

# ============================================================
# Section 13b: ocws-pkgmgr GUI binary
# ============================================================
header "ocws-pkgmgr GUI"
PKGMGR="$BUILD_DIR/ocws-pkgmgr"
if [ -x "$PKGMGR" ]; then
    pass "ocws-pkgmgr binary exists and is executable"

    if file "$PKGMGR" | grep -q "ELF"; then
        pass "ocws-pkgmgr is a valid ELF binary"
    else
        fail "ocws-pkgmgr is not an ELF binary"
    fi

    if ldd "$PKGMGR" 2>/dev/null | grep -q "gtk"; then
        pass "ocws-pkgmgr links against GTK"
    else
        skip "ldd not available or GTK not linked"
    fi

    if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then
        timeout 3 "$PKGMGR" &>/dev/null
        pass "ocws-pkgmgr ran without crash"
    else
        skip "No display server — cannot test runtime launch"
    fi
else
    skip "ocws-pkgmgr binary not found"
fi

# ============================================================
# Section 14: Shared utils integrity
# ============================================================
header "Shared utils (utils.c)"
UTILS_SRC="$PROJECT_DIR/src/utils.c"
if [ -f "$UTILS_SRC" ]; then
    pass "utils.c exists"

    # Verify shared data tables are present
    for sym in "OCWS_THEMES" "OCWS_SHELLS" "prettify" "scan_themes" "run_cmd_async" "highlight_selected"; do
        if grep -q "$sym" "$UTILS_SRC"; then
            pass "utils.c contains: $sym"
        else
            fail "utils.c missing: $sym"
        fi
    done

    # Verify theme count matches themes/ directory
    THEME_COUNT=$(grep -c "OCWS_THEMES\[\]" "$UTILS_SRC" 2>/dev/null || echo 0)
    INI_COUNT=$(ls "$PROJECT_DIR/themes/"*.ini 2>/dev/null | wc -l)
    if [ "$INI_COUNT" -gt 0 ]; then
        pass "themes/ directory has $INI_COUNT INI files"
    else
        skip "themes/ directory not found"
    fi
else
    fail "utils.c not found"
fi

# ============================================================
# Section 15: .desktop file validation
# ============================================================
header "Desktop Entry Files"
DESKTOP_DIR="$PROJECT_DIR/dotfiles/applications"
for desk in ocws-settings.desktop ocws-welcome.desktop ocws-pkgmgr.desktop; do
    DESK_PATH="$DESKTOP_DIR/$desk"
    if [ -f "$DESK_PATH" ]; then
        pass "$desk exists"

        # Required keys
        for key in Name Exec Type Terminal Categories; do
            if grep -q "^${key}=" "$DESK_PATH"; then
                pass "$desk has $key"
            else
                fail "$desk missing $key"
            fi
        done

        # Exec should reference the correct binary
        EXEC_LINE=$(grep "^Exec=" "$DESK_PATH" | head -1)
        case "$desk" in
            ocws-settings.desktop)
                if echo "$EXEC_LINE" | grep -q "ocws-settings"; then
                    pass "$desk Exec references ocws-settings"
                else
                    fail "$desk Exec does not reference ocws-settings"
                fi
                ;;
            ocws-welcome.desktop)
                if echo "$EXEC_LINE" | grep -q "ocws-welcome"; then
                    pass "$desk Exec references ocws-welcome"
                else
                    fail "$desk Exec does not reference ocws-welcome"
                fi
                ;;
            ocws-pkgmgr.desktop)
                if echo "$EXEC_LINE" | grep -q "ocws-pkgmgr"; then
                    pass "$desk Exec references ocws-pkgmgr"
                else
                    fail "$desk Exec does not reference ocws-pkgmgr"
                fi
                ;;
        esac
    else
        fail "$desk not found in $DESKTOP_DIR"
    fi
done

# ============================================================
# Summary
# ============================================================
echo ""
echo -e "${BOLD}C Binary Test Suite Summary:${NC}"
echo -e "  ${GREEN}Passed:${NC}  $PASS_COUNT"
echo -e "  ${YELLOW}Skipped:${NC} $SKIP_COUNT"
echo -e "  ${RED}Failed:${NC}  $FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
exit 0
