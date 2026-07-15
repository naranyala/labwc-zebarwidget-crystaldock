#!/bin/bash
set -euo pipefail

# ocws-icon-picker — Pick icon theme using rofi
# Lists all available icon themes and lets user select one
# Updates zigshell-cairo-pango, GTK3, GTK4, and qt6ct simultaneously

OCWS_DIR="${OCWS_DIR:-$HOME/.config/ocws}"
ZIGSHELL_DIR="$HOME/.config/zigshell-cairo-pango"
GTK3_DIR="$HOME/.config/gtk-3.0"
GTK4_DIR="$HOME/.config/gtk-4.0"
QTCT_DIR="$HOME/.config/qt6ct"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; }

# --- Collect all icon themes ---
collect_themes() {
    local themes=()
    
    # System themes
    if [[ -d /usr/share/icons ]]; then
        for dir in /usr/share/icons/*/; do
            [[ -f "$dir/index.theme" ]] && themes+=("$(basename "$dir")")
        done
    fi
    
    # User themes
    if [[ -d ~/.local/share/icons ]]; then
        for dir in ~/.local/share/icons/*/; do
            [[ -f "$dir/index.theme" ]] && themes+=("$(basename "$dir")")
        done
    fi
    
    # Remove duplicates
    printf '%s\n' "${themes[@]}" | sort -u
}

# --- Get current theme ---
get_current_theme() {
    grep "iconTheme=" "$ZIGSHELL_DIR/labwc/appearance.conf" 2>/dev/null | cut -d= -f2 || echo "Adwaita"
}

# --- Apply theme to all surfaces ---
apply_theme() {
    local theme="$1"
    
    echo -e "${CYAN}Applying icon theme: $theme${NC}"
    
    # Zigshell-cairo-pango
    if [[ -f "$ZIGSHELL_DIR/labwc/appearance.conf" ]]; then
        sed -i "s/^iconTheme=.*/iconTheme=$theme/" "$ZIGSHELL_DIR/labwc/appearance.conf"
        pass "zigshell-cairo-pango: $theme"
    fi
    
    # GTK3
    if [[ -f "$GTK3_DIR/settings.ini" ]]; then
        sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$theme/" "$GTK3_DIR/settings.ini"
        pass "GTK3: $theme"
    fi
    
    # GTK4
    if [[ -f "$GTK4_DIR/settings.ini" ]]; then
        sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$theme/" "$GTK4_DIR/settings.ini"
        pass "GTK4: $theme"
    fi
    
    # qt6ct
    if [[ -f "$QTCT_DIR/qt6ct.conf" ]]; then
        sed -i "s/^iconTheme=.*/iconTheme=$theme/" "$QTCT_DIR/qt6ct.conf"
        pass "qt6ct: $theme"
    fi
    
    # gsettings (if available)
    if command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface icon-theme "$theme" 2>/dev/null && \
            pass "gsettings: $theme" || true
    fi
    
    echo ""
    echo -e "${GREEN}Icon theme changed to: $theme${NC}"
    echo "Restart zigshell-cairo-pango to apply: pkill -9 -x zigshell-cairo-pango && nohup zigshell-cairo-pango --start --overlay &"
}

# --- Preview icons from theme ---
preview_theme() {
    local theme="$1"
    local icon_dir=""
    
    # Find the theme directory
    for dir in ~/.local/share/icons/"$theme" /usr/share/icons/"$theme"; do
        if [[ -d "$dir" ]]; then
            icon_dir="$dir"
            break
        fi
    done
    
    if [[ -z "$icon_dir" ]]; then
        echo "Theme directory not found"
        return 1
    fi
    
    echo -e "${CYAN}Theme: $theme${NC}"
    echo "Location: $icon_dir"
    echo ""
    
    # Show some example icons
    echo "Example icons:"
    find "$icon_dir" -name "*.svg" -o -name "*.png" 2>/dev/null | head -20 | while read -r icon; do
        echo "  $(basename "$icon")"
    done
}

# --- Main ---
main() {
    case "${1:-pick}" in
        pick)
            local current
            current=$(get_current_theme)
            
            echo -e "${CYAN}Current icon theme: $current${NC}"
            echo ""
            echo "Select icon theme:"
            echo ""
            
            local themes
            themes=$(collect_themes)
            
            local selected
            selected=$(echo "$themes" | rofi -dmenu -p "Icon Theme > " -theme-str 'window {width: 400px;}')
            
            if [[ -n "$selected" ]]; then
                apply_theme "$selected"
            else
                echo "No theme selected"
            fi
            ;;
        
        list)
            echo -e "${CYAN}Available icon themes:${NC}"
            echo ""
            collect_themes | while read -r theme; do
                local current
                current=$(get_current_theme)
                if [[ "$theme" == "$current" ]]; then
                    echo -e "  ${GREEN}* $theme${NC} (current)"
                else
                    echo "    $theme"
                fi
            done
            ;;
        
        current)
            echo "Current icon theme: $(get_current_theme)"
            ;;
        
        preview)
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 preview <theme-name>"
                exit 1
            fi
            preview_theme "$2"
            ;;
        
        apply)
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 apply <theme-name>"
                exit 1
            fi
            apply_theme "$2"
            ;;
        
        help|--help|-h)
            echo "ocws-icon-picker — Pick icon theme using rofi"
            echo ""
            echo "Usage:"
            echo "  $0              Interactive picker (default)"
            echo "  $0 list         List all available themes"
            echo "  $0 current      Show current theme"
            echo "  $0 preview NAME Preview a theme"
            echo "  $0 apply NAME   Apply a theme directly"
            ;;
        
        *)
            echo "Unknown command: $1"
            echo "Run '$0 help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
