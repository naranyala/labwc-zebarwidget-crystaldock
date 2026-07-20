#!/usr/bin/env bash
# dms-setup.sh — Clone DankMaterialShell (shallow) and verify every
# requirement needed to *launch* it, printing a [✓]/[✗] checklist.
#
# Usage:
#   ./dms-setup.sh                 # clone (if missing) + run the checklist
#   ./dms-setup.sh --clone-only    # only clone, skip the checklist
#   ./dms-setup.sh --check-only    # only run the checklist
#   ./dms-setup.sh --fix           # also try `sudo dnf install` for missing build deps
#   ./dms-setup.sh --force         # re-clone even if the dir already exists
#
# Notes:
#   * OpenMandriva-specific package checks (uses `rpm -q`). On other distros the
#     package rows simply report "skip" instead of failing.
#   * The Quickshell *runtime* (`qs`) is a separate repo from the DMS QML config
#     that lives inside DankMaterialShell/quickshell/.

set -uo pipefail

# ---- sources -------------------------------------------------------------
DMS_REPO="https://github.com/AvengeMedia/DankMaterialShell.git"
QS_REPO="https://github.com/quickshell-mirror/quickshell"
DMS_BRANCH="master"
QS_BRANCH="master"

SRC_ROOT="${DMS_SRC_ROOT:-$PWD/sources}"
DMS_DIR="$SRC_ROOT/DankMaterialShell"
QS_DIR="$SRC_ROOT/quickshell"
DMS_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/dms"

# ---- flags ---------------------------------------------------------------
CLONE_ONLY=0; CHECK_ONLY=0; FIX=0; FORCE=0
for a in "$@"; do
  case "$a" in
    --clone-only) CLONE_ONLY=1 ;;
    --check-only) CHECK_ONLY=1 ;;
    --fix)        FIX=1 ;;
    --force)      FORCE=1 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done

# ---- marks ---------------------------------------------------------------
OK='\033[0;32m[✓]\033[0m'
BAD='\033[0;31m[✗]\033[0m'
WARN='\033[0;33m[!]\033[0m'
SKIP='\033[0;90m[-]\033[0m'
PASS=0; FAIL=0; WARN_COUNT=0

# req <category> <description> <test-command>
req() {
  local cat="$1" desc="$2"; shift 2
  if eval "$@" >/dev/null 2>&1; then
    printf "  ${OK} %s\n" "$desc"; PASS=$((PASS+1))
  else
    printf "  ${BAD} %s\n" "$desc"; FAIL=$((FAIL+1)); FAIL_LIST+=("$cat|$desc")
  fi
}
# warn <description> <test-command>  (optional / non-blocking)
warn() {
  local desc="$1"; shift
  if eval "$@" >/dev/null 2>&1; then
    printf "  ${OK} %s\n" "$desc"; PASS=$((PASS+1))
  else
    printf "  ${WARN} %s (optional)\n" "$desc"; WARN_COUNT=$((WARN_COUNT+1))
  fi
}
pkg() { # pkg <rpm-name>  -> rpm -q test, else skip
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
  if [ -d "$dir/.git" ] && [ "$FORCE" -eq 1 ]; then
    rm -rf "$dir"
  fi
  echo ">> Cloning $name (--depth=1, branch $branch) ..."
  git clone --depth=1 --branch "$branch" "$url" "$dir"
}

if [ "$CHECK_ONLY" -eq 0 ]; then
  echo "=== [1/2] Downloading sources ==="
  mkdir -p "$SRC_ROOT"
  clone_repo "$DMS_REPO" "$DMS_DIR" "$DMS_BRANCH" "DankMaterialShell"
  clone_repo "$QS_REPO"  "$QS_DIR"  "$QS_BRANCH"  "Quickshell runtime (qs)"
  echo
fi

[ "$CLONE_ONLY" -eq 1 ] && exit 0

# =========================================================================
# 2) CHECKLIST
# =========================================================================
echo "=== [2/2] Requirement checklist ==="

echo "-- Source tree --"
req "source" "DankMaterialShell source present"       "[ -d '$DMS_DIR/.git' ]"
req "source" "Quickshell runtime source present"      "[ -d '$QS_DIR/.git' ]"
req "source" "DMS QML config (shell.qml) in source"    "[ -f '$DMS_DIR/quickshell/shell.qml' ]"

echo "-- Build toolchain --"
req "tool" "git installed"            "command -v git"
req "tool" "cmake installed"          "command -v cmake"
req "tool" "pkgconf / pkg-config"      "command -v pkgconf || command -v pkg-config"
req "tool" "C++ compiler (gcc/clang)"  "command -v g++ || command -v clang++"
req "tool" "Go (golang) installed"     "command -v go"
req "tool" "wayland-scanner on PATH"   "command -v wayland-scanner"

echo "-- Build dependencies (OpenMandriva rpm) --"
for p in cmake extra-cmake-modules pkgconf gcc-c++ clang golang \
         lib64Qt6Core-devel lib64Qt6Gui-devel lib64Qt6Qml-devel lib64Qt6Quick-devel \
         lib64Qt6QuickControls2-devel lib64Qt6DBus-devel lib64Qt6Network-devel \
         lib64Qt6Svg lib64Qt6Svg-devel lib64Qt6ShaderTools-devel \
         lib64Qt6WaylandClient-devel lib64Qt6WaylandCompositor-devel \
         lib64Qt6OpenGL-devel lib64Qt6Widgets-devel lib64Qt6Multimedia-devel \
         lib64wayland-devel wayland-protocols-devel wayland-tools \
         libdrm-devel vulkan-headers libxkbcommon-devel lib64spirv-tools-devel \
         cli11-devel lib64jemalloc-devel lib64pipewire-devel lib64pam-devel \
         lib64polkit1-devel lib64glib2.0-devel; do
  if pkg "$p" >/dev/null 2>&1; then
    printf "  ${OK} package %s\n" "$p"; PASS=$((PASS+1))
  elif command -v rpm >/dev/null 2>&1; then
    printf "  ${BAD} package %s MISSING\n" "$p"; FAIL=$((FAIL+1)); FAIL_LIST+=("pkg|$p")
  else
    printf "  ${SKIP} package %s (rpm unavailable)\n" "$p"
  fi
done

echo "-- Installed runtime binaries --"
req "bin" "quickshell / qs on PATH"  "command -v qs || command -v quickshell"
req "bin" "dms on PATH"              "command -v dms"
if command -v qs >/dev/null 2>&1; then
  warn "qs reports a version"        "qs --version"
fi

echo "-- Shell config deployed --"
req "config" "DMS config dir exists ($DMS_CONFIG_DIR)"  "[ -d '$DMS_CONFIG_DIR' ]"
req "config" "shell.qml deployed"                        "[ -f '$DMS_CONFIG_DIR/shell.qml' ]"

echo "-- Wayland session --"
req "session" "WAYLAND_DISPLAY is set (compositor running)"  "[ -n \"${WAYLAND_DISPLAY:-}\" ]"
warn "XDG_CURRENT_DESKTOP mentions a known compositor"       "[ -n \"${XDG_CURRENT_DESKTOP:-}\" ]"

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
    if [ "${#MISSING[@]}" -gt 0 ]; then
      sudo dnf install -y "${MISSING[@]}"
    fi
  fi
  echo
  echo "  NOT READY — resolve the [✗] items above, then re-run: $0 --check-only"
  exit 1
fi

echo "  READY TO LAUNCH — run: dms run   (or: dms run -d for daemon mode)"
exit 0
