#!/bin/bash
# -------------------------------------------------------------------
# Build System Validator
# Validates build.zig for completeness:
# - All .c files have build targets
# - No orphaned source files
# - No duplicate build targets
# - All referenced source files exist
# -------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_ZIG="$PROJECT_DIR/build.zig"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

errors=0
warnings=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; ((errors++)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; ((warnings++)); }
info() { echo -e "  ${CYAN}ℹ${NC} $1"; }

echo -e "${BOLD}=== Build System Validator ===${NC}"
echo ""

# ---------------------------------------------------------------
# 1. Build file exists
# ---------------------------------------------------------------
echo -e "${BOLD}1. Build file${NC}"

if [[ -f "$BUILD_ZIG" ]]; then
    pass "build.zig found"
else
    fail "build.zig not found at $BUILD_ZIG"
    echo -e "${RED}Cannot continue without build.zig${NC}"
    exit 1
fi
echo ""

# ---------------------------------------------------------------
# 2. Extract build targets
# ---------------------------------------------------------------
echo -e "${BOLD}2. Build targets${NC}"

# Extract target names from build.zig
target_names=$(grep -oP '\.name\s*=\s*"[^"]+' "$BUILD_ZIG" | sed 's/\.name\s*=\s*"//' | sort -u)
target_count=$(echo "$target_names" | grep -c . || true)
info "$target_count build targets found"

# Check for duplicate targets
dupes=$(echo "$target_names" | sort | uniq -d)
if [[ -n "$dupes" ]]; then
    while IFS= read -r dupe; do
        fail "Duplicate build target: $dupe"
    done <<< "$dupes"
else
    pass "No duplicate targets"
fi
echo ""

# ---------------------------------------------------------------
# 3. Extract source files from build.zig
# ---------------------------------------------------------------
echo -e "${BOLD}3. Source file references${NC}"

# Extract .c file paths referenced in build.zig (exclude Zig format strings like {s})
build_sources=$(grep -oP '"src/[^"]+\.c"' "$BUILD_ZIG" | tr -d '"' | grep -v '{' | sort -u)
build_count=$(echo "$build_sources" | grep -c . || true)
info "$build_count source files referenced in build.zig"

# Check each referenced file exists
missing_refs=0
while IFS= read -r src; do
    [[ -z "$src" ]] && continue
    if [[ ! -f "$PROJECT_DIR/$src" ]]; then
        fail "Referenced file missing: $src"
        ((missing_refs++))
    fi
done <<< "$build_sources"

if [[ $missing_refs -eq 0 ]]; then
    pass "All referenced source files exist"
fi
echo ""

# ---------------------------------------------------------------
# 4. Orphaned source files
# ---------------------------------------------------------------
echo -e "${BOLD}4. Orphaned source files${NC}"

# Find all .c files in src/ (excluding tests/)
all_sources=$(find "$PROJECT_DIR/src" -name "*.c" -not -path "*/tests/*" -not -path "*/.git/*" | sed "s|$PROJECT_DIR/||" | sort -u)
all_count=$(echo "$all_sources" | grep -c . || true)
info "$all_count total .c files in src/"

# Compare
orphaned=0
while IFS= read -r src; do
    [[ -z "$src" ]] && continue
    if ! echo "$build_sources" | grep -qF "$src"; then
        warn "Orphaned source (not in build): $src"
        ((orphaned++))
    fi
done <<< "$all_sources"

if [[ $orphaned -eq 0 ]]; then
    pass "No orphaned source files"
fi
echo ""

# ---------------------------------------------------------------
# 5. Header-only library check
# ---------------------------------------------------------------
echo -e "${BOLD}5. Header-only libraries${NC}"

headers=$(find "$PROJECT_DIR/src" -name "*.h" -not -path "*/.git/*" | sed "s|$PROJECT_DIR/||" | sort -u)
header_count=$(echo "$headers" | grep -c . || true)
info "$header_count header files"

# Check each .c file for #include of local headers
missing_headers=0
while IFS= read -r src; do
    [[ -z "$src" ]] && continue
    [[ ! -f "$PROJECT_DIR/$src" ]] && continue

    # Get local includes
    includes=$(grep -oP '#include\s+"[^"]+"' "$PROJECT_DIR/$src" | sed 's/#include\s*"//;s/"//' || true)
    while IFS= read -r inc; do
        [[ -z "$inc" ]] && continue
        # Check if header exists relative to the source file's directory
        src_dir=$(dirname "$src")
        if [[ ! -f "$PROJECT_DIR/$src_dir/$inc" ]] && [[ ! -f "$PROJECT_DIR/$inc" ]]; then
            warn "$src: includes missing header '$inc'"
            ((missing_headers++))
        fi
    done <<< "$includes"
done <<< "$all_sources"

if [[ $missing_headers -eq 0 ]]; then
    pass "All local includes resolve"
fi
echo ""

# ---------------------------------------------------------------
# 6. Desktop file validation
# ---------------------------------------------------------------
echo -e "${BOLD}6. Desktop file entries${NC}"

desktop_dir="$PROJECT_DIR/dotfiles/applications"
if [[ -d "$desktop_dir" ]]; then
    desktop_count=$(find "$desktop_dir" -name "*.desktop" | wc -l)
    info "$desktop_count desktop files"

    for df in "$desktop_dir"/*.desktop; do
        [[ -f "$df" ]] || continue
        name=$(basename "$df")
        exec_cmd=$(grep '^Exec=' "$df" | head -1 | sed 's/^Exec=//')
        bin_name=$(echo "$exec_cmd" | awk '{print $1}')

        # Check if binary exists in zig-out or system
        if [[ -f "$PROJECT_DIR/zig-out/bin/$bin_name" ]]; then
            pass "$name → $bin_name (built)"
        elif command -v "$bin_name" >/dev/null 2>&1; then
            pass "$name → $bin_name (system)"
        else
            warn "$name → $bin_name (not found in zig-out or PATH)"
        fi
    done
else
    info "No desktop files directory"
fi
echo ""

# ---------------------------------------------------------------
# Summary
# ---------------------------------------------------------------
echo -e "${BOLD}=== Summary ===${NC}"
echo -e "  Errors:   ${errors}"
echo -e "  Warnings: ${warnings}"
echo ""

[[ $errors -eq 0 ]] && echo -e "${GREEN}${BOLD}Build system valid!${NC}" || echo -e "${RED}${BOLD}Build validation failed${NC}"
exit $errors
