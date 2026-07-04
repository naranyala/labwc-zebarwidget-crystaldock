#!/bin/bash
#
# fix-gtk-fonts.sh — Fix GTK font rendering issues under Wayland
#
# Fixes: empty text, wrong font, missing fontconfig, corrupted settings.ini

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass()  { echo -e "  ${GREEN}✓${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail()  { echo -e "  ${RED}✗${NC} $1"; }
info()  { echo -e "  ${CYAN}→${NC} $1"; }
section() { echo -e "\n${BOLD}[$1]${NC}"; }

FIXED=0

echo ""
echo -e "${BOLD}== Fix GTK Fonts =="
echo ""

# --- 1. Fontconfig ---
section "Fontconfig"
FONTCONFIG_DIR="$HOME/.config/fontconfig"
FONTCONFIG_FILE="$FONTCONFIG_DIR/fonts.conf"

if [ -f "$FONTCONFIG_FILE" ]; then
  pass "fonts.conf exists"
else
  mkdir -p "$FONTCONFIG_DIR"
  cat > "$FONTCONFIG_FILE" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Noto Sans</family>
      <family>DejaVu Sans</family>
    </prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <prefer>
      <family>Noto Sans Mono</family>
      <family>DejaVu Sans Mono</family>
    </prefer>
  </alias>
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
    <edit name="hinting" mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
    <edit name="rgba" mode="assign"><const>rgb</const></edit>
    <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
  </match>
</fontconfig>
EOF
  pass "Created fonts.conf"
  ((FIXED++))
fi

# --- 2. GTK3 settings.ini ---
section "GTK3 settings.ini"
GTK3_DIR="$HOME/.config/gtk-3.0"
GTK3_FILE="$GTK3_DIR/settings.ini"

if [ -f "$GTK3_FILE" ]; then
  # Check for corrupted font-name (common bug: gets set to "0")
  FONT_LINE=$(grep "^gtk-font-name=" "$GTK3_FILE" 2>/dev/null || true)
  FONT_VAL=$(echo "$FONT_LINE" | cut -d= -f2-)

  if [ -z "$FONT_VAL" ] || [ "$FONT_VAL" = "0" ] || [ "$FONT_VAL" = '"0"' ]; then
    warn "gtk-font-name is corrupted ($FONT_VAL) — fixing"
    sed -i 's/^gtk-font-name=.*/gtk-font-name=Noto Sans 10/' "$GTK3_FILE"
    pass "Fixed gtk-font-name → Noto Sans 10"
    ((FIXED++))
  elif echo "$FONT_VAL" | grep -q ','; then
    # Comma format can cause issues on some GTK versions
    warn "gtk-font-name uses comma format ($FONT_VAL) — normalizing"
    sed -i "s/^gtk-font-name=.*/gtk-font-name=Noto Sans 10/" "$GTK3_FILE"
    pass "Normalized gtk-font-name → Noto Sans 10"
    ((FIXED++))
  else
    pass "gtk-font-name OK: $FONT_VAL"
  fi

  # Check monospace font
  MONO_LINE=$(grep "^gtk-monospace-font-name=" "$GTK3_FILE" 2>/dev/null || true)
  MONO_VAL=$(echo "$MONO_LINE" | cut -d= -f2-)
  if [ -z "$MONO_VAL" ] || [ "$MONO_VAL" = "0" ]; then
    warn "gtk-monospace-font-name missing or corrupted"
    if grep -q "^gtk-monospace-font-name=" "$GTK3_FILE"; then
      sed -i 's/^gtk-monospace-font-name=.*/gtk-monospace-font-name=Noto Sans Mono 10/' "$GTK3_FILE"
    else
      echo "gtk-monospace-font-name=Noto Sans Mono 10" >> "$GTK3_FILE"
    fi
    pass "Fixed gtk-monospace-font-name"
    ((FIXED++))
  else
    pass "gtk-monospace-font-name OK: $MONO_VAL"
  fi
else
  mkdir -p "$GTK3_DIR"
  cat > "$GTK3_FILE" << 'EOF'
[Settings]
gtk-font-name=Noto Sans 10
gtk-monospace-font-name=Noto Sans Mono 10
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Adwaita
gtk-cursor-size=24
gtk-application-prefer-dark-theme=1
gtk-color-scheme=prefer-dark
EOF
  pass "Created settings.ini"
  ((FIXED++))
fi

# --- 3. GTK4 settings.ini ---
section "GTK4 settings.ini"
GTK4_DIR="$HOME/.config/gtk-4.0"
GTK4_FILE="$GTK4_DIR/settings.ini"

if [ -f "$GTK4_FILE" ]; then
  FONT_LINE=$(grep "^gtk-font-name=" "$GTK4_FILE" 2>/dev/null || true)
  FONT_VAL=$(echo "$FONT_LINE" | cut -d= -f2-)

  if [ -z "$FONT_VAL" ] || [ "$FONT_VAL" = "0" ]; then
    warn "gtk-font-name is corrupted in GTK4 — fixing"
    sed -i 's/^gtk-font-name=.*/gtk-font-name=Noto Sans 10/' "$GTK4_FILE"
    pass "Fixed GTK4 gtk-font-name"
    ((FIXED++))
  else
    pass "GTK4 settings OK"
  fi
else
  mkdir -p "$GTK4_DIR"
  cat > "$GTK4_FILE" << 'EOF'
[Settings]
gtk-font-name=Noto Sans 10
gtk-monospace-font-name=Noto Sans Mono 10
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Adwaita
gtk-cursor-size=24
gtk-application-prefer-dark-theme=1
gtk-color-scheme=prefer-dark
EOF
  pass "Created GTK4 settings.ini"
  ((FIXED++))
fi

# --- 4. GDK Backend ---
section "Environment"
ENV_FILE="$HOME/.config/labwc/environment"
if [ -f "$ENV_FILE" ]; then
  if grep -q "^GDK_BACKEND=" "$ENV_FILE"; then
    GDK_VAL=$(grep "^GDK_BACKEND=" "$ENV_FILE" | cut -d= -f2-)
    if [ "$GDK_VAL" != "wayland" ]; then
      warn "GDK_BACKEND=$GDK_VAL (should be 'wayland' for pure Wayland)"
    else
      pass "GDK_BACKEND=wayland"
    fi
  else
    info "GDK_BACKEND not set in environment (apps may fallback to X11)"
  fi
else
  info "No environment file found"
fi

# --- Summary ---
section "Summary"
echo ""
if [ "$FIXED" -gt 0 ]; then
  echo -e "${GREEN}${BOLD}$FIXED fix(es) applied${NC}"
  echo "  Log out and back in for changes to take full effect."
else
  echo -e "${GREEN}${BOLD}All GTK font settings OK${NC}"
fi
echo ""
