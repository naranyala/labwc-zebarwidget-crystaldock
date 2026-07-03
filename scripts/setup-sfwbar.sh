#!/bin/bash
#
# setup-sfwbar.sh — Install and configure SFWBar for labwc
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass()  { echo -e "  ${GREEN}✓${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
info()  { echo -e "  ${CYAN}→${NC} $1"; }
fail()  { echo -e "  ${RED}✗${NC} $1"; exit 1; }
section() { echo -e "\n${BOLD}[$1]${NC}"; }

echo ""
echo -e "${BOLD}== SFWBar Setup for labwc ==${NC}"
echo ""

# ---- 1. Check if sfwbar is installed ----
section "1. Check Installation"

if command -v sfwbar >/dev/null 2>&1; then
  pass "sfwbar: $(command -v sfwbar)"
else
  warn "sfwbar not found"
  echo ""
  info "To build and install sfwbar:"
  echo "    cd $PROJECT_DIR"
  echo "    git clone --depth 1 https://github.com/LBCrion/sfwbar.git build/sfwbar-src"
  echo "    cd build/sfwbar-src"
  echo "    meson setup build --prefix=\$HOME/.local"
  echo "    ninja -C build"
  echo "    ninja -C build install"
  echo ""
  info "Or install from package manager:"
  echo "    Ubuntu/Debian: Build from source (see above)"
  echo "    Fedora: sudo dnf install sfwbar"
  echo "    Arch: yay -S sfwbar"
  echo ""
  fail "Install sfwbar first, then re-run this script"
fi

# ---- 2. Create config directory ----
section "2. Create Config Directory"

SFWBAR_DIR="$HOME/.config/sfwbar"
mkdir -p "$SFWBAR_DIR"
pass "$SFWBAR_DIR"

# ---- 3. Install configuration ----
section "3. Install Configuration"

SFWBAR_SRC="$PROJECT_DIR/dotfiles/sfwbar"

# Copy main config
if [[ -f "$SFWBAR_SRC/sfwbar.config" ]]; then
  cp "$SFWBAR_SRC/sfwbar.config" "$SFWBAR_DIR/sfwbar.config"
  pass "sfwbar.config"
fi

# Copy CSS theme
if [[ -f "$SFWBAR_SRC/catppuccin-mocha.css" ]]; then
  cp "$SFWBAR_SRC/catppuccin-mocha.css" "$SFWBAR_DIR/catppuccin-mocha.css"
  pass "catppuccin-mocha.css"
fi

# Copy any widget files from installed sfwbar
if [[ -d "$HOME/.local/share/sfwbar" ]]; then
  for f in "$HOME/.local/share/sfwbar"/*.widget "$HOME/.local/share/sfwbar"/*.source; do
    if [[ -f "$f" ]]; then
      name=$(basename "$f")
      if [[ ! -f "$SFWBAR_DIR/$name" ]]; then
        cp "$f" "$SFWBAR_DIR/$name"
        pass "$name"
      fi
    fi
  done
fi

# ---- 4. Update component config ----
section "4. Update Component Config"

CONFIG_DIR="$HOME/.config/labwc-widgets"
mkdir -p "$CONFIG_DIR"

if [[ ! -f "$CONFIG_DIR/status.json" ]]; then
  cat > "$CONFIG_DIR/status.json" << 'EOF'
{
  "statusbar": "sfwbar",
  "dock": "crystal",
  "theme": "catppuccin-mocha",
  "widgets": {
    "clock": true,
    "cpu": true,
    "memory": true,
    "network": true,
    "battery": true,
    "volume": true
  }
}
EOF
  pass "Created status.json with sfwbar as default"
else
  # Update existing config to use sfwbar
  sed -i 's/"statusbar": "[^"]*"/"statusbar": "sfwbar"/' "$CONFIG_DIR/status.json"
  pass "Updated status.json to use sfwbar"
fi

# ---- 5. Verify ----
section "5. Verify"

# Check config exists
if [[ -f "$SFWBAR_DIR/sfwbar.config" ]]; then
  pass "sfwbar.config installed"
else
  warn "sfwbar.config not found"
fi

# Check modules are available
if [[ -d "$HOME/.local/lib/x86_64-linux-gnu/sfwbar" ]]; then
  modules=$(ls "$HOME/.local/lib/x86_64-linux-gnu/sfwbar"/*.so 2>/dev/null | wc -l)
  pass "Modules: $modules found"
else
  warn "Module directory not found"
fi

# ---- Summary ----
echo ""
echo -e "${GREEN}${BOLD}SFWBar Setup Complete!${NC}"
echo ""
echo "Configuration: $SFWBAR_DIR/"
echo "  ├── sfwbar.config      (main config)"
echo "  └── catppuccin-mocha.css (theme)"
echo ""
echo "To start sfwbar:"
echo "  widget-manager.sh start"
echo "  # or"
echo "  sfwbar &"
echo ""
echo "To swap to sfwbar:"
echo "  widget-manager.sh swap statusbar sfwbar"
echo ""
