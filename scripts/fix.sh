#!/bin/bash
#
# fix.sh — Auto-fix common bugs in labwc + sfwbar + fuzzel setup
#
# Fixes every issue that validate.sh can detect.
# Usage: fix.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="${HOME}/.config/labwc"
SFWBAR_DIR="${HOME}/.config/sfwbar"
FUZZEL_DIR="${HOME}/.config/fuzzel"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

FIXED=0
SKIPPED=0
DRY_RUN=false

[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

pass()  { echo -e "  ${GREEN}✓${NC} $1"; FIXED=$((FIXED + 1)); }
skip()  { echo -e "  ${YELLOW}→${NC} $1"; SKIPPED=$((SKIPPED + 1)); }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
info()  { echo -e "  ${CYAN}→${NC} $1"; }
section() { echo -e "\n${BOLD}[$1]${NC}"; }

echo ""
echo -e "${BOLD}== labwc Auto-Fix =="
$DRY_RUN && echo -e "${CYAN}(dry run — no changes will be made)${NC}"
echo ""

# ============================================================
section "1. Create Missing Directories"
# ============================================================
for dir in "$CONFIG_DIR" "$SFWBAR_DIR" "$FUZZEL_DIR" "$HOME/.local/bin" "$HOME/Pictures/wallpapers" "$HOME/.config/fontconfig"; do
  if [ -d "$dir" ]; then
    skip "$(basename "$dir") exists"
  elif $DRY_RUN; then
    info "Would create $dir"
  else
    mkdir -p "$dir"
    pass "Created $dir"
  fi
done

# ============================================================
section "2. Fix Permissions"
# ============================================================
for file in "$CONFIG_DIR/autostart"; do
  if [ -f "$file" ] && [ ! -x "$file" ]; then
    if $DRY_RUN; then
      info "Would chmod +x $file"
    else
      chmod +x "$file"
      pass "Made $(basename "$file") executable"
    fi
  else
    skip "$(basename "$file") permissions OK"
  fi
done

# Make all scripts executable
if ! $DRY_RUN; then
  for script in "$SCRIPT_DIR"/*.sh; do
    [ -f "$script" ] && [ ! -x "$script" ] && chmod +x "$script"
  done
fi

# ============================================================
section "3. Fix Broken Symlinks"
# ============================================================
BROKEN=0
while IFS= read -r -d '' link; do
  if [ ! -e "$link" ]; then
    if $DRY_RUN; then
      info "Would remove broken symlink: $link"
    else
      rm -f "$link"
      pass "Removed broken symlink: $(basename "$link")"
    fi
    ((BROKEN++))
  fi
done < <(find "$CONFIG_DIR" "$SFWBAR_DIR" -type l -print0 2>/dev/null)
[ "$BROKEN" -eq 0 ] && skip "No broken symlinks"

# ============================================================
section "4. Install Missing labwc Config"
# ============================================================
DOTFILES_DIR="$PROJECT_DIR/dotfiles/labwc"
for cfg in rc.xml autostart environment menu.xml themerc-override; do
  if [ -f "$DOTFILES_DIR/$cfg" ] && [ ! -f "$CONFIG_DIR/$cfg" ]; then
    if $DRY_RUN; then
      info "Would install $cfg"
    else
      cp "$DOTFILES_DIR/$cfg" "$CONFIG_DIR/$cfg"
      [ "$cfg" = "autostart" ] && chmod +x "$CONFIG_DIR/$cfg"
      pass "Installed $cfg"
    fi
  else
    skip "$cfg OK"
  fi
done

# ============================================================
section "5. Fix rc.xml Client Context"
# ============================================================
RC_XML="$CONFIG_DIR/rc.xml"
if [ -f "$RC_XML" ]; then
  CLIENT_CTX=$(sed -n '/<context name="Client">/,/<\/context>/p' "$RC_XML" 2>/dev/null || true)
  if echo "$CLIENT_CTX" | grep -q 'button="Left" action="Press"'; then
    if $DRY_RUN; then
      info "Would fix Client context"
    else
      GOOD_CTX='      <context name="Client">
        <mousebind button="A-Left" action="Drag">
          <action name="Move" />
        </mousebind>
        <mousebind button="A-Right" action="Drag">
          <action name="Resize" />
        </mousebind>
      </context>'
      python3 -c "
import re
with open('$RC_XML', 'r') as f:
    c = f.read()
c = re.sub(r'<context name=\"Client\">.*?</context>', '''$GOOD_CTX''', c, flags=re.DOTALL)
with open('$RC_XML', 'w') as f:
    f.write(c)
" 2>/dev/null && pass "Fixed Client context" || warn "Could not fix Client context"
    fi
  else
    skip "Client context OK"
  fi
fi

# ============================================================
section "6. Fix rc.xml Unescaped &"
# ============================================================
if [ -f "$RC_XML" ]; then
  if grep -qP '&&(?![\s]*amp;)' "$RC_XML" 2>/dev/null || grep -n '&&' "$RC_XML" 2>/dev/null | grep -v '&amp;' | grep -q .; then
    if $DRY_RUN; then
      info "Would fix unescaped &"
    else
      sed -i 's/&&/\&amp;\&amp;/g' "$RC_XML"
      pass "Fixed unescaped & in rc.xml"
    fi
  else
    skip "rc.xml entities OK"
  fi
fi

# ============================================================
section "7. Fix rc.xml Script Paths"
# ============================================================
if [ -f "$RC_XML" ]; then
  if grep -q '~/.config/labwc/scripts/actions/' "$RC_XML"; then
    if $DRY_RUN; then
      info "Would fix script paths in rc.xml"
    else
      sed -i 's|~/.config/labwc/scripts/actions/||g' "$RC_XML"
      pass "Fixed script paths in rc.xml"
    fi
  else
    skip "rc.xml script paths OK"
  fi
fi

# ============================================================
section "7b. Fix rc.xml Keybind Modifiers (S- to W-)"
# ============================================================
if [ -f "$RC_XML" ]; then
  if grep -q 'key="S-a"' "$RC_XML" || grep -q 'key="S-v"' "$RC_XML" || grep -q 'key="S-Left"' "$RC_XML"; then
    if $DRY_RUN; then
      info "Would fix erroneous S- (Shift) modifiers to W- (Super)"
    else
      # Fix common mistaken Shift modifiers
      sed -i 's/key="S-a"/key="W-a"/g' "$RC_XML"
      sed -i 's/key="S-v"/key="W-v"/g' "$RC_XML"
      sed -i 's/key="S-m"/key="W-m"/g' "$RC_XML"
      sed -i 's/key="S-Left"/key="W-Left"/g' "$RC_XML"
      sed -i 's/key="S-Right"/key="W-Right"/g' "$RC_XML"
      sed -i 's/key="S-Up"/key="W-Up"/g' "$RC_XML"
      sed -i 's/key="S-Down"/key="W-Down"/g' "$RC_XML"
      pass "Fixed S- (Shift) modifiers to W- (Super) in rc.xml"
    fi
  else
    skip "rc.xml keybind modifiers OK"
  fi
fi

# ============================================================
section "7c. Replace Rofi with Fuzzel/Sfwbar"
# ============================================================
if [ -f "$RC_XML" ]; then
  if grep -q 'command>rofi' "$RC_XML"; then
    if $DRY_RUN; then
      info "Would replace rofi with fuzzel/sfwbar in rc.xml"
    else
      # Replace rofi calculator with fuzzel-calc
      sed -i 's/rofi -e "$(echo | bc -l)".*/actions.sh fuzzel-calc<\/command><\/action><\/keybind>/g' "$RC_XML"
      # Replace rofi emoji with fuzzel-emoji
      sed -i 's/rofi -e "Emoji Picker.*/actions.sh fuzzel-emoji<\/command><\/action><\/keybind>/g' "$RC_XML"
      # Replace rofi window switcher with sfwbar
      sed -i 's/rofi -show window.*/sfwbar -c "SwitcherEvent('\''forward'\'')"<\/command><\/action><\/keybind>/g' "$RC_XML"
      pass "Replaced rofi references in rc.xml"
      
      # Ensure sfwbar switcher is enabled
      if [ -f "$SFWBAR_DIR/sfwbar.config" ]; then
        sed -i 's/switcher { disable = true }/switcher { disable = false }/g' "$SFWBAR_DIR/sfwbar.config"
      fi
    fi
  else
    skip "rc.xml no rofi usage"
  fi
fi

# ============================================================
section "8. Fix Environment Variables"
# ============================================================
ENV_FILE="$CONFIG_DIR/environment"
if [ -f "$ENV_FILE" ]; then
  CHANGES=0

  # Remove hardcoded WAYLAND_DISPLAY
  if grep -q '^WAYLAND_DISPLAY=' "$ENV_FILE"; then
    if $DRY_RUN; then
      info "Would remove WAYLAND_DISPLAY from environment"
    else
      sed -i '/^WAYLAND_DISPLAY=/d' "$ENV_FILE"
      pass "Removed hardcoded WAYLAND_DISPLAY"
      ((CHANGES++))
    fi
  fi

  # Add missing XDG vars
  for var in XDG_CURRENT_DESKTOP=labwc XDG_SESSION_TYPE=wayland XDG_SESSION_DESKTOP=labwc; do
    KEY="${var%%=*}"
    VALUE="${var#*=}"
    if ! grep -q "^${KEY}=" "$ENV_FILE" 2>/dev/null; then
      if $DRY_RUN; then
        info "Would add $KEY=$VALUE"
      else
        echo "${KEY}=${VALUE}" >> "$ENV_FILE"
        pass "Added $KEY=$VALUE"
        ((CHANGES++))
      fi
    fi
  done

  [ "$CHANGES" -eq 0 ] && skip "Environment OK"
else
  if $DRY_RUN; then
    info "Would create environment file"
  else
    cat > "$ENV_FILE" << 'EOF'
XDG_CURRENT_DESKTOP=labwc
XDG_SESSION_TYPE=wayland
XDG_SESSION_DESKTOP=labwc
EOF
    pass "Created environment file"
  fi
fi

# ============================================================
section "9. Fix GTK Fonts"
# ============================================================
# GTK3 settings.ini
GTK3_DIR="$HOME/.config/gtk-3.0"
GTK3_FILE="$GTK3_DIR/settings.ini"

if [ -f "$GTK3_FILE" ]; then
  FONT_VAL=$(grep "^gtk-font-name=" "$GTK3_FILE" 2>/dev/null | cut -d= -f2- || true)
  NEEDS_FIX=false

  if [ -z "$FONT_VAL" ] || [ "$FONT_VAL" = "0" ] || [ "$FONT_VAL" = '"0"' ]; then
    NEEDS_FIX=true
  elif echo "$FONT_VAL" | grep -q ','; then
    NEEDS_FIX=true
  fi

  if $NEEDS_FIX; then
    if $DRY_RUN; then
      info "Would fix GTK3 gtk-font-name"
    else
      sed -i 's/^gtk-font-name=.*/gtk-font-name=Noto Sans 10/' "$GTK3_FILE"
      pass "Fixed GTK3 gtk-font-name → Noto Sans 10"
    fi
  else
    skip "GTK3 font OK: $FONT_VAL"
  fi

  # Monospace
  MONO_VAL=$(grep "^gtk-monospace-font-name=" "$GTK3_FILE" 2>/dev/null | cut -d= -f2- || true)
  if [ -z "$MONO_VAL" ] || [ "$MONO_VAL" = "0" ]; then
    if $DRY_RUN; then
      info "Would fix GTK3 gtk-monospace-font-name"
    else
      if grep -q "^gtk-monospace-font-name=" "$GTK3_FILE"; then
        sed -i 's/^gtk-monospace-font-name=.*/gtk-monospace-font-name=Noto Sans Mono 10/' "$GTK3_FILE"
      else
        echo "gtk-monospace-font-name=Noto Sans Mono 10" >> "$GTK3_FILE"
      fi
      pass "Fixed GTK3 gtk-monospace-font-name"
    fi
  fi
else
  if $DRY_RUN; then
    info "Would create GTK3 settings.ini"
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
    pass "Created GTK3 settings.ini"
  fi
fi

# GTK4 settings.ini
GTK4_DIR="$HOME/.config/gtk-4.0"
GTK4_FILE="$GTK4_DIR/settings.ini"

if [ -f "$GTK4_FILE" ]; then
  FONT_VAL=$(grep "^gtk-font-name=" "$GTK4_FILE" 2>/dev/null | cut -d= -f2- || true)
  if [ -z "$FONT_VAL" ] || [ "$FONT_VAL" = "0" ]; then
    if $DRY_RUN; then
      info "Would fix GTK4 gtk-font-name"
    else
      sed -i 's/^gtk-font-name=.*/gtk-font-name=Noto Sans 10/' "$GTK4_FILE"
      pass "Fixed GTK4 gtk-font-name"
    fi
  else
    skip "GTK4 font OK"
  fi
else
  if $DRY_RUN; then
    info "Would create GTK4 settings.ini"
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
  fi
fi

# Fontconfig
FONTCONF_DIR="$HOME/.config/fontconfig"
FONTCONF_FILE="$FONTCONF_DIR/fonts.conf"
if [ ! -f "$FONTCONF_FILE" ]; then
  if $DRY_RUN; then
    info "Would create fontconfig/fonts.conf"
  else
    mkdir -p "$FONTCONF_DIR"
    cat > "$FONTCONF_FILE" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias><family>sans-serif</family><prefer><family>Noto Sans</family><family>DejaVu Sans</family></prefer></alias>
  <alias><family>monospace</family><prefer><family>Noto Sans Mono</family><family>DejaVu Sans Mono</family></prefer></alias>
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
    <edit name="hinting" mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
    <edit name="rgba" mode="assign"><const>rgb</const></edit>
  </match>
</fontconfig>
EOF
    pass "Created fontconfig/fonts.conf"
  fi
else
  skip "fontconfig OK"
fi

# ============================================================
section "10. Fix SFWBar Config"
# ============================================================
SFWBAR_SRC="$PROJECT_DIR/dotfiles/sfwbar"

# Install missing widget files
if [ -d "$SFWBAR_SRC" ]; then
  WIDGETS_INSTALLED=0
  for widget in "$SFWBAR_SRC"/*.widget "$SFWBAR_SRC"/*.source "$SFWBAR_SRC"/*.config "$SFWBAR_SRC"/*.css; do
    if [ -f "$widget" ]; then
      fname=$(basename "$widget")
      if [ ! -f "$SFWBAR_DIR/$fname" ]; then
        if $DRY_RUN; then
          info "Would install $fname"
        else
          cp "$widget" "$SFWBAR_DIR/$fname"
          pass "Installed $fname"
        fi
        ((WIDGETS_INSTALLED++))
      fi
    fi
  done
  [ "$WIDGETS_INSTALLED" -eq 0 ] && skip "All sfwbar files up to date"
else
  skip "sfwbar source not found"
fi

# Fix broken widget references in installed config
if [ -f "$SFWBAR_DIR/sfwbar.config" ]; then
  MISSING=0
  while IFS= read -r line; do
    widget_name=$(echo "$line" | grep -oP 'widget\s+"([^"]+)"' | sed 's/widget "//;s/"//' || true)
    if [ -n "$widget_name" ] && [ ! -f "$SFWBAR_DIR/$widget_name" ]; then
      warn "Widget still MISSING: $widget_name (no source available)"
      ((MISSING++))
    fi
  done < <(grep 'widget "' "$SFWBAR_DIR/sfwbar.config" 2>/dev/null || true)
  [ "$MISSING" -eq 0 ] && skip "All widget refs OK"
fi

# ============================================================
section "11. Fix Fuzzel Config"
# ============================================================
FUZZEL_SRC="$PROJECT_DIR/dotfiles/fuzzel"
if [ -d "$FUZZEL_SRC" ] && [ -f "$FUZZEL_SRC/fuzzel.ini" ]; then
  if [ ! -d "$FUZZEL_DIR" ]; then
    if $DRY_RUN; then
      info "Would create fuzzel config dir"
    else
      mkdir -p "$FUZZEL_DIR"
    fi
  fi

  if [ ! -f "$FUZZEL_DIR/fuzzel.ini" ]; then
    if $DRY_RUN; then
      info "Would install fuzzel.ini"
    else
      cp "$FUZZEL_SRC/fuzzel.ini" "$FUZZEL_DIR/fuzzel.ini"
      pass "Installed fuzzel.ini"
    fi
  else
    skip "fuzzel.ini exists"
  fi
else
  skip "fuzzel source not found"
fi

# Fix invalid [border] color option
if [ -f "$FUZZEL_DIR/fuzzel.ini" ]; then
  if grep -A5 '^\[border\]' "$FUZZEL_DIR/fuzzel.ini" 2>/dev/null | grep -q '^color='; then
    if $DRY_RUN; then
      info "Would remove 'color' from [border] section"
    else
      sed -i '/^\[border\]/,/^\[/{/^color=/d}' "$FUZZEL_DIR/fuzzel.ini"
      pass "Removed invalid 'color' from [border] section"
    fi
  fi
fi

# ============================================================
section "12. Fix Desktop Count"
# ============================================================
if [ -f "$RC_XML" ] && [ -f "$SFWBAR_DIR/sfwbar.config" ]; then
  RC_DESKTOPS=$(grep -oP '<number>\K[0-9]+' "$RC_XML" 2>/dev/null || echo "0")
  WS_PINS=$(grep -oP 'pins\s*=\s*"\K[^"]+' "$SFWBAR_DIR/sfwbar.config" 2>/dev/null | head -1 || true)
  if [ -n "$WS_PINS" ]; then
    PIN_COUNT=$(echo "$WS_PINS" | tr ',' '\n' | wc -l)
    if [ "$PIN_COUNT" -gt "$RC_DESKTOPS" ]; then
      if $DRY_RUN; then
        info "Would update rc.xml desktops to $PIN_COUNT"
      else
        sed -i "s|<number>$RC_DESKTOPS</number>|<number>$PIN_COUNT</number>|" "$RC_XML"
        pass "Updated desktops: $RC_DESKTOPS → $PIN_COUNT"
      fi
    fi
  fi
fi

# ============================================================
section "13. Fix PATH"
# ============================================================
PROFILE_FILE=""
for f in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.zshrc"; do
  [ -f "$f" ] && PROFILE_FILE="$f" && break
done

if [ -n "$PROFILE_FILE" ]; then
  if ! grep -q '\.local/bin' "$PROFILE_FILE" 2>/dev/null; then
    if $DRY_RUN; then
      info "Would add ~/.local/bin to PATH in $(basename "$PROFILE_FILE")"
    else
      echo '' >> "$PROFILE_FILE"
      echo '# labwc — add local bin to PATH' >> "$PROFILE_FILE"
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$PROFILE_FILE"
      pass "Added ~/.local/bin to PATH"
    fi
  else
    skip "PATH already configured"
  fi
fi

# ============================================================
section "14. Create Wayland Session File"
# ============================================================
SESSION_DIR="/usr/share/wayland-sessions"
SESSION_FILE="$SESSION_DIR/labwc.desktop"
LABWC_BIN="$(command -v labwc 2>/dev/null || echo "")"

if [ -n "$LABWC_BIN" ] && [ -d "$SESSION_DIR" ] && [ ! -f "$SESSION_FILE" ]; then
  if $DRY_RUN; then
    info "Would create labwc.desktop"
  else
    cat > /tmp/labwc.desktop << EOF
[Desktop Entry]
Name=labwc
Comment=Lab Wayland Compositor
TryExec=$LABWC_BIN
Exec=$LABWC_BIN
Type=Application
DesktopNames=labwc
X-GDM-SessionRegisters=true
X-GDM-CanRunHeadless=true
EOF
    sudo cp /tmp/labwc.desktop "$SESSION_FILE" 2>/dev/null && pass "Created labwc.desktop" || warn "Need sudo for session file"
    sudo chmod 644 "$SESSION_FILE" 2>/dev/null || true
    rm -f /tmp/labwc.desktop
  fi
else
  skip "Session file exists or session dir missing"
fi

# ============================================================
section "15. Remove Stale Files"
# ============================================================
# Old project name references
for old_dir in "$PROJECT_DIR/dotfiles/mango" "$PROJECT_DIR/config/mango" "$PROJECT_DIR/dotfiles/zebar"; do
  if [ -d "$old_dir" ]; then
    if $DRY_RUN; then
      info "Would remove $(basename "$old_dir")/"
    else
      rm -rf "$old_dir"
      pass "Removed $(basename "$old_dir")/"
    fi
  fi
done

# ============================================================
section "Summary"
# ============================================================
echo ""
if $DRY_RUN; then
  echo -e "${CYAN}Dry run complete.${NC} Run without --dry-run to apply."
else
  echo -e "${GREEN}${BOLD}$FIXED fix(es) applied${NC}, ${YELLOW}$SKIPPED skipped${NC}"
  echo ""
  echo "Next: ./scripts/validate.sh  to verify"
fi
echo ""
