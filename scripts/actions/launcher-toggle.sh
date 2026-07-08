#!/bin/bash
#
# launcher_toggle — Super+F launcher toggle (fuzzel/rofi) with theme reload
#

MODE="${1:-toggle}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass()  { echo -e "${GREEN}✓${NC} $1"; }
info()  { echo -e "${CYAN}→${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
fail()  { echo -e "${RED}✗${NC} $1"; exit 1; }

# Add theme reload option to menu
get_theme_options() {
  local project_dir themes_dir
  
  project_dir=$(find "$SCRIPT_DIR" -name "themes" -type d | head -1 | xargs dirname 2>/dev/null)
  if [[ -d "$project_dir/themes" ]]; then
    themes_dir="$project_dir/themes"
    
    echo -e "${CYAN}=== Global Theme Options ===${NC}"
    echo -e "  ${GREEN}[t]${NC} Toggle between Fuzzel and Rofi launcher"
    echo -e "  ${CYAN}[Theme Options:]${NC}"
    echo -e ""
    
    # Check predefined theme categories
    local predefined_themes_dir="$project_dir/themes/predefined"
    if [[ -d "$predefined_themes_dir" ]]; then
      echo -e "  ${CYAN}--- Predefined Themes ---${NC}"
      for f in "$predefined_themes_dir"/*.ini; do
        [[ -f "$f" ]] || continue
        local name desc
        name=$(grep -m1 '^name=' "$f" 2>/dev/null | cut -d= -f2- | xargs)
        desc=$(grep -m1 '^description=' "$f" 2>/dev/null | cut -d= -f2- | xargs)
        local base
        base=$(basename "$f" .ini)
        printf "  ${CYAN}[${base}]${NC} %s — %s\n" "${name:-$base}" "${desc:-}"
      done
      echo -e ""
    fi
    
    echo -e "  ${CYAN}--- Available Theme Files ---${NC}"
    local count=1
    for f in "$themes_dir"/*.ini; do
      [[ -f "$f" ]] || continue
      
      # Skip preset theme files if they have separate handling
      local base_name
      base_name=$(basename "$f" .ini)
      if [[ "$base_name" == theme-* ]]; then
        continue
      fi
      
      local name desc
      name=$(grep -m1 '^name=' "$f" 2>/dev/null | cut -d= -f2- | xargs)
      desc=$(grep -m1 '^description=' "$f" 2>/dev/null | cut -d= -f2- | xargs)
      
      if [[ $count -le 9 ]]; then
        # Show as numbered keybind
        printf "  ${CYAN}[${count}]${NC} %s — %s\n" "${name:-$base_name}" "${desc:-}"
        ((count++))
      else
        # Show continue message
        printf "  ${CYAN}[...${NC}]${NC} ... and ${count-$((count + ${#themes_dir} - 9))} more themes\n"
        break
      fi
    done
    
    echo -e "  ${YELLOW}[r]${NC} Reload current theme"
    echo -e "  ${YELLOW}[c]${NC} Clear theme cache / reload all configs"
    echo -e "  ${YELLOW}[q]${NC} Quit (just launcher toggle)"
    
    read -p "Select theme (1-9/r/c/q): " choice
    
    case "$choice" in
      1|2|3|4|5|6|7|8|9)
        # Show only the first 9 themes for simplicity
        local idx=0
        local filtered_themes=()
        for f in "$themes_dir"/*.ini; do
          [[ -f "$f" ]] || continue
          local base_name
          base_name=$(basename "$f" .ini)
          if [[ "$base_name" != theme-* ]]; then
            filtered_themes+=("$f")
          fi
          [[ ${#filtered_themes[@]} -eq 9 ]] && break
        done
        
        [[ ${#filtered_themes[@]} -lt "$choice" ]] && fail "Theme option out of range"
        
        local theme_file="${filtered_themes[$((choice-1))]}"
        return 0
        ;;
      r|R)
        local current_theme_file="$HOME/.config/labwc/.current-theme"
        if [[ -f "$current_theme_file" ]]; then
          local current_name
          current_name=$(cat "$current_theme_file")
          
          # Find the file
          for f in "$themes_dir"/*.ini; do
            [[ -f "$f" ]] || continue
            local base_name
            base_name=$(basename "$f" .ini)
            if [[ "$base_name" == "$current_name" ]]; then
              echo "$f"
              return 0
            fi
          done
        fi
        warn "No current theme file found"
        return 1
        ;;
      c|C)
        return 2
        ;;
      q|Q)
        return 3
        ;;
      *)
        warn "Invalid choice, using Catppuccin Mocha"
        echo "$themes_dir/catppuccin-mocha.ini"
        ;;
    esac
  fi
}

toggle_launcher() {
  local current_launcher
  
  if [[ -f "$HOME/.config/ocws/launcher" ]]; then
    current_launcher=$(cat "$HOME/.config/ocws/launcher")
    info "Current launcher: $current_launcher"
  else
    current_launcher="fuzzel"
    echo "fuzzel" > "$HOME/.config/ocws/launcher"
  fi
  
  if [[ "$current_launcher" == "fuzzel" ]]; then
    echo "rofi" > "$HOME/.config/ocws/launcher"
    info "Switched to Rofi launcher"
    # Re-export PATH so launchers are found
    export PATH="$PATH:/usr/bin:/bin"
  else
    echo "fuzzel" > "$HOME/.config/ocws/launcher"
    info "Switched to Fuzzel launcher"
  fi
  
  pass "Launcher toggled to $(cat "$HOME/.config/ocws/launcher")"
  
  # Reload the launcher config
  if command -v xrdb >/dev/null 2>&1; then
    xrdb -merge "$HOME/.config/fuzzel/fuzzel.ini" 2>/dev/null || true
  fi
}

reload_theme() {
  local theme_name="${1:-}"
  
  local project_dir
  project_dir=$(find "$SCRIPT_DIR" -name "themes" -type d | head -1 | xargs dirname 2>/dev/null)
  local themes_dir="$project_dir/themes"
  
  if [[ -z "$theme_name" ]]; then
    # Get theme file using the new menu function
    read theme_choice <<< $(get_theme_options)
    
    case "$theme_choice" in
      ""|"1")
        theme_name="catppuccin-mocha"
        ;;
      "theme-*|theme_*|theme.*"*)
        theme_name="${theme_choice#*theme-}"
        ;;
      ":")
        # Return code 1 means no theme selected
        pass "Theme reload cancelled"
        return 0
        ;;
      ":2")
        # Return code 2 means reload current
        if [[ -f "$HOME/.config/labwc/.current-theme" ]]; then
          theme_name=$(cat "$HOME/.config/labwc/.current-theme")
          info "Reloading current theme: $theme_name"
        else
          warn "No current theme set"
          return 1
        fi
        ;;
      ":3")
        # Return code 3 means just toggle launcher
        toggle_launcher
        return 0
        ;;
    esac
  fi
  
  local theme_file="$themes_dir/$theme_name.ini"
  
  if [[ ! -f "$theme_file" ]]; then
    warn "Theme not found: $theme_file, using default Catppuccin Mocha"
    theme_file="$themes_dir/catppuccin-mocha.ini"
  fi
  
  info "Loading global theme: $(basename "$theme_file" .ini)"
  
  # Try to apply theme using theme-engine first
  if [[ -x "$SCRIPT_DIR/theme-engine.sh" ]]; then
    # Export project directory for theme-engine
    LABWC_PROJECT="$project_dir"
    bash "$SCRIPT_DIR/theme-engine.sh" apply "$theme_file"
    
    # Reload labwc if available
    if command -v reload >/dev/null 2>&1; then
      reload labwc
    elif pidof labwc >/dev/null; then
      pkill -HUP -f labwc
      pass "labwc reloaded"
    fi
    
    # Restart sfwbar if available
    if pidof sfwbar >/dev/null; then
      pkill sfwbar
      sleep 0.3
      sfwbar &
      disown
      pass "sfwbar restarted"
    fi
    
    # Update current theme
    mkdir -p "$HOME/.config/labwc"
    echo "$(basename "$theme_file" .ini)" > "$HOME/.config/labwc/.current-theme"
    
    pass "Global theme applied: $(basename "$theme_file" .ini)"
  else
    fail "Theme engine not available"
  fi
}



# Main dispatcher
if [[ "$MODE" == "toggle" || "$1" == "toggle" ]]; then
  toggle_launcher
elif [[ "$MODE" == "theme" || "$1" == "theme" ]]; then
  reload_theme "$2"
else
  # Default behavior: launcher toggle with theme reload confirmation
  toggle_launcher
  echo ""
  info "Quick theme reload? (y/n)"
  read -n 1 reload_choice
  echo
  if [[ "$reload_choice" =~ ^[Yy]$ ]]; then
    reload_theme
  fi
fi