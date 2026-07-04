#!/bin/bash
#
# validate.sh — Comprehensive validation of labwc + sfwbar + fuzzel setup
#
# Checks 25+ common bugs with clear pass/fail/warn output.
# Exit code = number of errors found.
# Run before/after fix.sh to verify state.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="${HOME}/.config/labwc"
SFWBAR_DIR="${HOME}/.config/sfwbar"
FUZZEL_DIR="${HOME}/.config/fuzzel"

ERRORS=0
WARNINGS=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass()  { echo -e "  ${GREEN}✓${NC} $1"; }
fail()  { echo -e "  ${RED}✗${NC} $1"; ERRORS=$((ERRORS + 1)); }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
info()  { echo -e "  ${CYAN}→${NC} $1"; }
section() { echo -e "\n${BOLD}[$1]${NC}"; }

echo ""
echo -e "${BOLD}== labwc + sfwbar + fuzzel Validation =="
echo ""

# ============================================================
section "1. Binaries"
# ============================================================
REQUIRED_BINS=(labwc sfwbar)
OPTIONAL_BINS=(crystal-dock foot rofi fuzzel grim slurp wl-copy playerctl wpctl gammastep redshift mako dunst libinput gsettings swaybg swayidle swaylock wlr-randr jq)

for bin in "${REQUIRED_BINS[@]}"; do
  if command -v "$bin" &>/dev/null; then
    pass "$bin: $(command -v "$bin")"
  else
    fail "$bin: NOT FOUND (required)"
  fi
done

for bin in "${OPTIONAL_BINS[@]}"; do
  if command -v "$bin" &>/dev/null; then
    pass "$bin: $(command -v "$bin")"
  else
    warn "$bin: not found (optional)"
  fi
done

# ============================================================
section "2. labwc Config Files"
# ============================================================
if [ -d "$CONFIG_DIR" ]; then
  pass "Config directory: $CONFIG_DIR"
else
  fail "Config directory MISSING: $CONFIG_DIR"
fi

for cfg in rc.xml autostart environment; do
  if [ -f "$CONFIG_DIR/$cfg" ]; then
    if [ -r "$CONFIG_DIR/$cfg" ]; then
      pass "$cfg: exists"
    else
      fail "$cfg: NOT readable"
    fi
  else
    fail "$cfg: MISSING"
  fi
done

# Optional configs
for cfg in menu.xml themerc-override; do
  if [ -f "$CONFIG_DIR/$cfg" ]; then
    pass "$cfg: exists"
  else
    warn "$cfg: not found (optional)"
  fi
done

# ============================================================
section "3. Autostart"
# ============================================================
AUTOSTART="$CONFIG_DIR/autostart"
if [ -f "$AUTOSTART" ]; then
  if [ -x "$AUTOSTART" ]; then
    pass "autostart: executable"
  else
    fail "autostart: NOT executable"
  fi

  # Check sfwbar is launched
  if grep -q "sfwbar" "$AUTOSTART"; then
    pass "autostart: sfwbar configured"
  else
    warn "autostart: sfwbar NOT in autostart"
  fi

  # Check screen protection
  if grep -q "gammastep\|redshift" "$AUTOSTART"; then
    pass "autostart: screen protection configured"
  else
    warn "autostart: no screen protection (gammastep/redshift)"
  fi

  # Check for gsettings GTK sync (contaminates GNOME)
  if grep -q 'gsettings set org.gnome.desktop.interface' "$AUTOSTART"; then
    fail "autostart: gsettings GTK sync present — contaminates GNOME sessions"
  else
    pass "autostart: no gsettings GTK sync"
  fi

  # Check for clipboard manager
  if grep -q "cliphist\|wl-paste" "$AUTOSTART"; then
    pass "autostart: clipboard manager configured"
  else
    warn "autostart: no clipboard manager (cliphist)"
  fi

  # Check for polkit agent
  if grep -q "polkit\|lxpolkit" "$AUTOSTART"; then
    pass "autostart: polkit agent configured"
  else
    warn "autostart: no polkit agent (needed for sudo/pkexec)"
  fi
else
  fail "autostart: MISSING"
fi

# ============================================================
section "4. rc.xml Validation"
# ============================================================
RC_XML="$CONFIG_DIR/rc.xml"
if [ -f "$RC_XML" ]; then
  # XML syntax
  if command -v xmllint &>/dev/null; then
    if xmllint --noout "$RC_XML" 2>/dev/null; then
      pass "rc.xml: valid XML"
    else
      fail "rc.xml: INVALID XML (parse error)"
    fi
  else
    info "xmllint not installed — skipping XML validation"
  fi

  # Client context Left Press bug
  CLIENT_CTX=$(sed -n '/<context name="Client">/,/<\/context>/p' "$RC_XML" 2>/dev/null || true)
  if echo "$CLIENT_CTX" | grep -q 'button="Left" action="Press"'; then
    fail "rc.xml: Client context 'Left Press' — breaks click forwarding"
  else
    pass "rc.xml: Client context OK"
  fi

  # Unescaped & in XML
  if grep -qP '&&(?![\s]*amp;)' "$RC_XML" 2>/dev/null || grep -n '&&' "$RC_XML" 2>/dev/null | grep -v '&amp;' | grep -q .; then
    fail "rc.xml: unescaped '&' — use &amp; in XML"
  else
    pass "rc.xml: XML entities OK"
  fi

  # Desktop count check
  DESKTOP_NUM=$(grep -oP '<number>\K[0-9]+' "$RC_XML" 2>/dev/null || echo "0")
  if [ "$DESKTOP_NUM" -lt 2 ]; then
    warn "rc.xml: desktops=$DESKTOP_NUM (very few)"
  else
    pass "rc.xml: desktops=$DESKTOP_NUM"
  fi

  # Keybind: fuzzel launcher
  if grep -q 'fuzzel' "$RC_XML"; then
    pass "rc.xml: fuzzel launcher keybind present"
  else
    warn "rc.xml: no fuzzel keybind"
  fi

  # Keybind: volume control
  if grep -q 'XF86Audio' "$RC_XML"; then
    pass "rc.xml: media keybinds present"
  else
    warn "rc.xml: no media keybinds"
  fi

  # Check for broken script paths
  if grep -q '~/.config/labwc/scripts/actions/' "$RC_XML"; then
    fail "rc.xml: references ~/.config/labwc/scripts/actions/ (should be in PATH)"
  else
    pass "rc.xml: script paths OK"
  fi

  # Check for rofi usage (should use fuzzel)
  if grep -q 'command>rofi' "$RC_XML"; then
    fail "rc.xml: uses 'rofi' instead of fuzzel-based scripts/sfwbar"
  else
    pass "rc.xml: no rofi usage"
  fi

  # Check for S- (Shift) modifier bugs
  if grep -q 'key="S-a"' "$RC_XML" || grep -q 'key="S-v"' "$RC_XML" || grep -q 'key="S-Left"' "$RC_XML"; then
    fail "rc.xml: uses 'S-' (Shift) instead of 'W-' (Super) for keybindings"
  else
    pass "rc.xml: no erroneous 'S-' modifiers"
  fi

  # Check for WAYLAND_DISPLAY hardcode
  if grep -q '^WAYLAND_DISPLAY=' "$RC_XML" 2>/dev/null; then
    fail "rc.xml: WAYLAND_DISPLAY hardcoded"
  fi
fi

# ============================================================
section "5. Environment"
# ============================================================
ENV_FILE="$CONFIG_DIR/environment"
if [ -f "$ENV_FILE" ]; then
  pass "environment: exists"

  # WAYLAND_DISPLAY hardcoded
  if grep -q '^WAYLAND_DISPLAY=' "$ENV_FILE"; then
    fail "environment: WAYLAND_DISPLAY hardcoded — GDM assigns dynamically"
  else
    pass "environment: no hardcoded WAYLAND_DISPLAY"
  fi

  # XDG_CURRENT_DESKTOP
  if grep -q '^XDG_CURRENT_DESKTOP=' "$ENV_FILE"; then
    pass "environment: XDG_CURRENT_DESKTOP set"
  else
    warn "environment: XDG_CURRENT_DESKTOP missing"
  fi

  # XDG_SESSION_TYPE
  if grep -q '^XDG_SESSION_TYPE=' "$ENV_FILE"; then
    pass "environment: XDG_SESSION_TYPE set"
  else
    warn "environment: XDG_SESSION_TYPE missing"
  fi

  # Software cursor fix
  if grep -q '^WLR_NO_HARDWARE_CURSORS=1' "$ENV_FILE"; then
    pass "environment: software cursors enabled"
  else
    warn "environment: WLR_NO_HARDWARE_CURSORS=1 missing (click alignment bugs)"
  fi
else
  fail "environment: MISSING"
fi

# ============================================================
section "6. GTK Fonts"
# ============================================================
# GTK3
GTK3_FILE="$HOME/.config/gtk-3.0/settings.ini"
if [ -f "$GTK3_FILE" ]; then
  FONT_VAL=$(grep "^gtk-font-name=" "$GTK3_FILE" 2>/dev/null | cut -d= -f2- || true)
  if [ -z "$FONT_VAL" ]; then
    fail "GTK3: gtk-font-name missing"
  elif [ "$FONT_VAL" = "0" ] || [ "$FONT_VAL" = '"0"' ]; then
    fail "GTK3: gtk-font-name corrupted to '$FONT_VAL'"
  elif echo "$FONT_VAL" | grep -q ','; then
    warn "GTK3: gtk-font-name uses comma format '$FONT_VAL' (may cause issues)"
  else
    pass "GTK3: gtk-font-name=$FONT_VAL"
  fi

  MONO_VAL=$(grep "^gtk-monospace-font-name=" "$GTK3_FILE" 2>/dev/null | cut -d= -f2- || true)
  if [ -z "$MONO_VAL" ] || [ "$MONO_VAL" = "0" ]; then
    warn "GTK3: gtk-monospace-font-name missing or corrupted"
  else
    pass "GTK3: gtk-monospace-font-name=$MONO_VAL"
  fi
else
  warn "GTK3: settings.ini not found"
fi

# GTK4
GTK4_FILE="$HOME/.config/gtk-4.0/settings.ini"
if [ -f "$GTK4_FILE" ]; then
  FONT_VAL=$(grep "^gtk-font-name=" "$GTK4_FILE" 2>/dev/null | cut -d= -f2- || true)
  if [ -z "$FONT_VAL" ] || [ "$FONT_VAL" = "0" ]; then
    warn "GTK4: gtk-font-name missing or corrupted"
  else
    pass "GTK4: gtk-font-name=$FONT_VAL"
  fi
else
  warn "GTK4: settings.ini not found"
fi

# Fontconfig
if [ -f "$HOME/.config/fontconfig/fonts.conf" ]; then
  pass "fontconfig: fonts.conf exists"
else
  warn "fontconfig: fonts.conf not found"
fi

# ============================================================
section "7. SFWBar Config"
# ============================================================
if [ -d "$SFWBAR_DIR" ]; then
  pass "sfwbar config dir: $SFWBAR_DIR"
else
  fail "sfwbar config dir MISSING"
fi

if [ -f "$SFWBAR_DIR/sfwbar.config" ]; then
  pass "sfwbar.config exists"

  # Check for missing widget references
  MISSING_WIDGETS=0
  while IFS= read -r line; do
    widget_name=$(echo "$line" | grep -oP 'widget\s+"([^"]+)"' | sed 's/widget "//;s/"//' || true)
    if [ -n "$widget_name" ] && [ ! -f "$SFWBAR_DIR/$widget_name" ]; then
      fail "sfwbar: widget MISSING: $widget_name"
      ((MISSING_WIDGETS++))
    fi
  done < <(grep 'widget "' "$SFWBAR_DIR/sfwbar.config" 2>/dev/null || true)

  # Check for missing include references
  while IFS= read -r line; do
    inc_name=$(echo "$line" | grep -oP 'include\("([^"]+)"\)' | sed 's/include("//;s/")//' || true)
    if [ -n "$inc_name" ] && [ ! -f "$SFWBAR_DIR/$inc_name" ]; then
      fail "sfwbar: include MISSING: $inc_name"
      ((MISSING_WIDGETS++))
    fi
  done < <(grep 'include(' "$SFWBAR_DIR/sfwbar.config" 2>/dev/null || true)

  if [ "$MISSING_WIDGETS" -eq 0 ]; then
    pass "sfwbar: all widget/include references OK"
  fi

  # Check for floating vs regular panel CSS
  if grep -q 'window#sfwbar.*transparent' "$SFWBAR_DIR/sfwbar.config" 2>/dev/null; then
    warn "sfwbar: window#sfwbar is transparent (floating panel style)"
  fi

else
  fail "sfwbar.config MISSING"
fi

# CSS files
CSS_FOUND=false
for css in catppuccin-mocha.css noctalia.css theme.css; do
  if [ -f "$SFWBAR_DIR/$css" ]; then
    pass "sfwbar CSS: $css"
    CSS_FOUND=true
    break
  fi
done
if ! $CSS_FOUND; then
  warn "sfwbar: no CSS theme file found"
fi

# Widget files
WIDGET_COUNT=0
for widget_file in "$SFWBAR_DIR"/*.widget; do
  [ -f "$widget_file" ] && ((WIDGET_COUNT++))
done 2>/dev/null
info "sfwbar widget files: $WIDGET_COUNT"

# ============================================================
section "8. Fuzzel Config"
# ============================================================
if [ -d "$FUZZEL_DIR" ]; then
  pass "fuzzel config dir: $FUZZEL_DIR"
else
  warn "fuzzel config dir not found"
fi

if [ -f "$FUZZEL_DIR/fuzzel.ini" ]; then
  pass "fuzzel.ini exists"

  # Check for invalid [border] color option
  if grep -A5 '^\[border\]' "$FUZZEL_DIR/fuzzel.ini" 2>/dev/null | grep -q '^color='; then
    fail "fuzzel: 'color' in [border] section — invalid option (use [colors] section)"
  else
    pass "fuzzel: border config OK"
  fi

  # Check background color is set
  if grep -q '^background=' "$FUZZEL_DIR/fuzzel.ini" 2>/dev/null; then
    BG_VAL=$(grep '^background=' "$FUZZEL_DIR/fuzzel.ini" | head -1 | cut -d= -f2-)
    pass "fuzzel: background=$BG_VAL"
  else
    warn "fuzzel: no background color set"
  fi
else
  warn "fuzzel.ini not found"
fi

# ============================================================
section "9. Permissions"
# ============================================================
for dir in "$CONFIG_DIR" "$SFWBAR_DIR" "$HOME/.local/bin"; do
  if [ -d "$dir" ]; then
    PERMS=$(stat -c "%a" "$dir" 2>/dev/null || stat -f "%Lp" "$dir" 2>/dev/null || echo "???")
    if [ "$PERMS" = "700" ] || [ "$PERMS" = "755" ] || [ "$PERMS" = "775" ]; then
      pass "$(basename "$dir"): $PERMS"
    else
      warn "$(basename "$dir"): unusual permissions ($PERMS)"
    fi
  fi
done

# Check scripts are executable
for script in "$SCRIPT_DIR"/*.sh; do
  if [ -f "$script" ] && [ ! -x "$script" ]; then
    warn "$(basename "$script"): not executable"
  fi
done

# Check for X11 tools in Wayland scripts
for script in "$SCRIPT_DIR/actions"/*.sh; do
  if [ -f "$script" ] && grep -q 'xdotool' "$script" 2>/dev/null; then
    warn "$(basename "$script"): uses xdotool (breaks in pure Wayland)"
  fi
done

# ============================================================
section "10. Display & Session"
# ============================================================
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
  pass "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
else
  info "No WAYLAND_DISPLAY (running from TTY)"
fi

if [ -n "${XDG_SESSION_TYPE:-}" ]; then
  pass "XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
else
  warn "XDG_SESSION_TYPE not set"
fi

# Check PATH
if echo "$PATH" | tr ':' '\n' | grep -qx "$HOME/.local/bin"; then
  pass "~/.local/bin in PATH"
else
  warn "~/.local/bin NOT in PATH"
fi

# ============================================================
section "11. Desktop Count Match"
# ============================================================
if [ -f "$CONFIG_DIR/rc.xml" ] && [ -f "$SFWBAR_DIR/sfwbar.config" ]; then
  RC_DESKTOPS=$(grep -oP '<number>\K[0-9]+' "$CONFIG_DIR/rc.xml" 2>/dev/null || echo "0")
  WS_PINS=$(grep -oP 'pins\s*=\s*"\K[^"]+' "$SFWBAR_DIR/sfwbar.config" 2>/dev/null | head -1 || true)
  if [ -n "$WS_PINS" ]; then
    PIN_COUNT=$(echo "$WS_PINS" | tr ',' '\n' | wc -l)
    if [ "$PIN_COUNT" -gt "$RC_DESKTOPS" ]; then
      warn "Desktops mismatch: rc.xml=$RC_DESKTOPS, sfwbar pins=$PIN_COUNT"
    else
      pass "Desktops match: rc.xml=$RC_DESKTOPS, sfwbar pins=$PIN_COUNT"
    fi
  fi
fi

# ============================================================
section "Summary"
# ============================================================
echo ""
if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}All checks passed!${NC}"
elif [ "$ERRORS" -eq 0 ]; then
  echo -e "${YELLOW}${BOLD}$WARNINGS warning(s)${NC} — functional but could be improved"
else
  echo -e "${RED}${BOLD}$ERRORS error(s), $WARNINGS warning(s)${NC}"
  echo ""
  echo "Run: ./scripts/fix.sh  to auto-fix errors"
fi
echo ""

exit "$ERRORS"
