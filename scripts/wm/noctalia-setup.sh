#!/usr/bin/env bash
# noctalia-setup.sh — Clone Noctalia (shallow) and verify every
# requirement needed to *launch* it, printing a [✓]/[✗] checklist.
#
# Usage:
#   ./noctalia-setup.sh              # clone (if missing) + run the checklist
#   ./noctalia-setup.sh --clone-only # only clone, skip the checklist
#   ./noctalia-setup.sh --check-only # only run the checklist
#   ./noctalia-setup.sh --fix        # also try `sudo dnf install` for missing build deps
#   ./noctalia-setup.sh --force      # re-clone even if the dir already exists
#
# Notes:
#   * OpenMandriva-specific package checks (uses `rpm -q`). On other distros the
#     package rows report "skip" instead of failing.
#   * Noctalia is a native Wayland shell (no Qt). It builds with meson + ninja.

set -uo pipefail

# ---- sources -------------------------------------------------------------
NOCTALIA_REPO="https://github.com/noctalia-dev/noctalia.git"
NOCTALIA_BRANCH="main"

SRC_ROOT="${NOCTALIA_SRC_ROOT:-$PWD/sources}"
NOCTALIA_DIR="$SRC_ROOT/noctalia"
NOCTALIA_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia"

# ---- flags ---------------------------------------------------------------
CLONE_ONLY=0; CHECK_ONLY=0; FIX=0; FORCE=0
for a in "$@"; do
  case "$a" in
    --clone-only) CLONE_ONLY=1 ;;
    --check-only) CHECK_ONLY=1 ;;
    --fix)        FIX=1 ;;
    --force)      FORCE=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done

# ---- marks ---------------------------------------------------------------
OK='\033[0;32m[✓]\033[0m'
BAD='\033[0;31m[✗]\033[0m'
WARN='\033[0;33m[!]\033[0m'
SKIP='\033[0;90m[-]\033[0m'
PASS=0; FAIL=0; WARN_COUNT=0; FAIL_LIST=()

req() {
  local cat="$1" desc="$2"; shift 2
  if eval "$@" >/dev/null 2>&1; then
    printf "  ${OK} %s\n" "$desc"; PASS=$((PASS+1))
  else
    printf "  ${BAD} %s\n" "$desc"; FAIL=$((FAIL+1)); FAIL_LIST+=("$cat|$desc")
  fi
}
warn() {
  local desc="$1"; shift
  if eval "$@" >/dev/null 2>&1; then
    printf "  ${OK} %s\n" "$desc"; PASS=$((PASS+1))
  else
    printf "  ${WARN} %s (optional)\n" "$desc"; WARN_COUNT=$((WARN_COUNT+1))
  fi
}
pkg() {
  if command -v rpm >/dev/null 2>&1; then rpm -q --quiet "$1"; else return 2; fi
}

# =========================================================================
# 1) CLONE
# =========================================================================
clone_repo() {
  local url="$1" dir="$2" branch="$3" name="$4"
  if [ -d "$dir/.git" ] && [ "$FORCE" -eq 0 ]; then
    printf "  ${SKIP} %s already cloned at %s\n" "$name" "$dir"
    return 0
  fi
  if [ -d "$dir/.git" ] && [ "$FORCE" -eq 1 ]; then rm -rf "$dir"; fi
  echo ">> Cloning $name (--depth=1, branch $branch) ..."
  git clone --depth=1 --branch "$branch" "$url" "$dir"
}

if [ "$CHECK_ONLY" -eq 0 ]; then
  echo "=== [1/2] Downloading sources ==="
  mkdir -p "$SRC_ROOT"
  clone_repo "$NOCTALIA_REPO" "$NOCTALIA_DIR" "$NOCTALIA_BRANCH" "Noctalia"
  echo
fi

[ "$CLONE_ONLY" -eq 1 ] && exit 0

# =========================================================================
# 2) CHECKLIST
# =========================================================================
echo "=== [2/2] Requirement checklist ==="

echo "-- Source tree --"
req "source" "Noctalia source present"           "[ -d '$NOCTALIA_DIR/.git' ]"
req "source" "meson.build present"               "[ -f '$NOCTALIA_DIR/meson.build' ]"

echo "-- Build toolchain --"
req "tool" "git installed"            "command -v git"
req "tool" "meson installed"          "command -v meson"
req "tool" "ninja installed"          "command -v ninja"
req "tool" "pkgconf / pkg-config"      "command -v pkgconf || command -v pkg-config"
req "tool" "C++ compiler (gcc/clang, C++23)" "command -v g++ || command -v clang++"
req "tool" "wayland-scanner on PATH"   "command -v wayland-scanner"

echo "-- Build dependencies (OpenMandriva rpm) --"
for p in meson ninja pkgconf gcc-c++ \
         lib64wayland-devel wayland-protocols-devel wayland-tools \
         lib64glvnd-devel lib64EGL_mesa-devel \
         lib64freetype6-devel lib64fontconfig-devel \
         lib64cairo-devel lib64pango1.0-devel lib64pangocairo1.0-devel \
         lib64pangoft2_1.0-devel lib64harfbuzz-devel \
         lib64rsvg2-devel libxkbcommon-devel lib64glib2.0-devel \
         lib64polkit1-devel lib64pipewire-devel lib64wireplumber-devel \
         lib64curl-devel lib64qalculate-devel lib64xml2-devel \
         lib64md4c-devel nlohmann_json-devel lib64tomlplusplus-devel \
         lib64pam-devel lib64jemalloc-devel lib64webp-devel; do
  if pkg "$p" >/dev/null 2>&1; then
    printf "  ${OK} package %s\n" "$p"; PASS=$((PASS+1))
  elif command -v rpm >/dev/null 2>&1; then
    printf "  ${BAD} package %s MISSING\n" "$p"; FAIL=$((FAIL+1)); FAIL_LIST+=("pkg|$p")
  else
    printf "  ${SKIP} package %s (rpm unavailable)\n" "$p"
  fi
done

echo "-- Installed runtime binary --"
req "bin" "noctalia on PATH"   "command -v noctalia"
if command -v noctalia >/dev/null 2>&1; then
  warn "noctalia reports a version" "noctalia --version"
fi

echo "-- Shell config --"
warn "config dir exists ($NOCTALIA_CONFIG_DIR)" "[ -d '$NOCTALIA_CONFIG_DIR' ]"

echo "-- Wayland session --"
req "session" "WAYLAND_DISPLAY is set (compositor running)" "[ -n \"${WAYLAND_DISPLAY:-}\" ]"
warn "XDG_CURRENT_DESKTOP mentions a known compositor"     "[ -n \"${XDG_CURRENT_DESKTOP:-}\" ]"

echo "-- Optional runtime services --"
warn "pipewire session running"   "command -v pw-cli >/dev/null && pw-cli info 0 >/dev/null 2>&1"
warn "polkit agent available"     "command -v pkaction >/dev/null 2>&1"

# =========================================================================
# 3) SUMMARY
# =========================================================================
echo
echo "=== Summary ==="
printf "  passed: %s   failed: %s   warnings: %s\n" "$PASS" "$FAIL" "$WARN_COUNT"

if [ "$FAIL" -gt 0 ]; then
  echo "  Missing requirements:"
  for f in "${FAIL_LIST[@]:-}"; do
    IFS='|' read -r c d <<< "$f"
    printf "    ${BAD} [%s] %s\n" "$c" "$d"
  done
  if [ "$FIX" -eq 1 ] && command -v rpm >/dev/null 2>&1 && command -v dnf >/dev/null 2>&1; then
    echo "  --fix: attempting sudo dnf install of missing packages ..."
    MISSING=()
    for f in "${FAIL_LIST[@]:-}"; do
      IFS='|' read -r c d <<< "$f"
      [ "$c" = "pkg" ] && MISSING+=("$d")
    done
    if [ "${#MISSING[@]}" -gt 0 ]; then sudo dnf install -y "${MISSING[@]}"; fi
  fi
  echo
  echo "  NOT READY — resolve the [✗] items above, then re-run: $0 --check-only"
  exit 1
fi

echo "  READY TO LAUNCH — run: noctalia   (or: noctalia -d for daemon mode)"
exit 0
