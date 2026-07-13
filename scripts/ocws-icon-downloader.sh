#!/bin/bash
set -euo pipefail

# ocws-icon-downloader — Download and install icon themes
# Sources: GitHub, OpenDesktop, custom URLs

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

ICONS_DIR="${HOME}/.local/share/icons"
DOWNLOAD_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}/ocws-icons"

pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; }
info() { echo -e "  ${CYAN}INFO${NC} $1"; }

mkdir -p "$ICONS_DIR" "$DOWNLOAD_DIR"

# --- Predefined popular icon themes ---
declare -A THEMES=(
    # Name => GitHub/GitLab URL
    ["Papirus"]="https://github.com/PapirusDevelopmentTeam/papirus-icon-theme/archive/master.tar.gz"
    ["Tela"]="https://github.com/vinceliuice/Tela-icon-theme/archive/master.tar.gz"
    ["WhiteSur"]="https://github.com/vinceliuice/WhiteSur-icon-theme/archive/master.tar.gz"
    ["McMojave"]="https://github.com/nicolodiamante/mc Mojave-circle/archive/master.tar.gz"
    ["Candy"]="https://github.com/EliverLara/candy-icons/archive/master.tar.gz"
    ["Tokyonight"]="https://github.com/encharm/IconFace/archive/master.tar.gz"
    ["Suru++"]="https://github.com/gusbemacbe/suru-plus/archive/master.tar.gz"
    ["Zafiro"]="https://github.com/varlesh/zafiro-icons/archive/master.tar.gz"
    ["Numix"]="https://github.com/numixproject/numix-icon-theme/archive/master.tar.gz"
    ["Flat Remix"]="https://github.com/daniruiz/flat-remix/archive/master.tar.gz"
    ["La Capitaine"]="https://github.com/keeferrourke/la-capitaine-icon-theme/archive/master.tar.gz"
    ["Arc-icons"]="https://github.com/horst3180/Arc-icon-theme/archive/master.tar.gz"
    ["Breeze"]="https://github.com/KDE/breeze-icons/archive/master.tar.gz"
    ["Yaru"]="https://github.com/ubuntu/yaru/archive/master.tar.gz"
    ["Adwaita"]="https://gitlab.gnome.org/GNOME/adwaita-icon-theme/archive/master.tar.gz"
)

# --- Download and install ---
install_theme() {
    local name="$1"
    local url="${THEMES[$name]:-}"
    
    if [[ -z "$url" ]]; then
        fail "Unknown theme: $name"
        echo "Run '$0 list' to see available themes"
        return 1
    fi
    
    info "Downloading $name..."
    
    local archive="$DOWNLOAD_DIR/$name.tar.gz"
    
    if ! curl -fsSL "$url" -o "$archive" 2>/dev/null; then
        fail "Failed to download $name"
        return 1
    fi
    
    info "Extracting..."
    
    local extract_dir="$DOWNLOAD_DIR/$name"
    mkdir -p "$extract_dir"
    
    if ! tar -xzf "$archive" -C "$extract_dir" --strip-components=1 2>/dev/null; then
        fail "Failed to extract $name"
        rm -rf "$extract_dir" "$archive"
        return 1
    fi
    
    # Find the icon theme directory (contains index.theme)
    local theme_dir
    theme_dir=$(find "$extract_dir" -name "index.theme" -type f -exec dirname {} \; 2>/dev/null | head -1)
    
    if [[ -z "$theme_dir" ]]; then
        # Try the extracted directory itself
        if [[ -f "$extract_dir/index.theme" ]]; then
            theme_dir="$extract_dir"
        else
            fail "No index.theme found in $name"
            rm -rf "$extract_dir" "$archive"
            return 1
        fi
    fi
    
    # Determine install name - use the original theme name, not directory name
    local install_name="$name"
    
    # Check if theme already exists, update it
    if [[ -d "$ICONS_DIR/$install_name" ]]; then
        info "Theme already exists, updating..."
        rm -rf "$ICONS_DIR/$install_name"
    fi
    
    cp -r "$theme_dir" "$ICONS_DIR/$install_name"
    
    # Cleanup
    rm -rf "$extract_dir" "$archive"
    
    pass "Installed: $install_name"
    echo "  Location: $ICONS_DIR/$install_name"
}

# --- Download from custom URL ---
install_custom() {
    local name="$1"
    local url="$2"
    
    info "Downloading custom theme: $name..."
    
    local archive="$DOWNLOAD_DIR/$name.tar.gz"
    
    if ! curl -fsSL "$url" -o "$archive" 2>/dev/null; then
        fail "Failed to download $name"
        return 1
    fi
    
    info "Extracting..."
    
    local extract_dir="$DOWNLOAD_DIR/$name"
    mkdir -p "$extract_dir"
    
    if ! tar -xzf "$archive" -C "$extract_dir" --strip-components=1 2>/dev/null; then
        fail "Failed to extract $name"
        rm -rf "$extract_dir" "$archive"
        return 1
    fi
    
    # Find the icon theme directory
    local theme_dir
    theme_dir=$(find "$extract_dir" -name "index.theme" -type f -exec dirname {} \; 2>/dev/null | head -1)
    
    if [[ -z "$theme_dir" ]]; then
        if [[ -f "$extract_dir/index.theme" ]]; then
            theme_dir="$extract_dir"
        else
            fail "No index.theme found in $name"
            rm -rf "$extract_dir" "$archive"
            return 1
        fi
    fi
    
    local install_name
    install_name=$(basename "$theme_dir")
    
    if [[ -d "$ICONS_DIR/$install_name" ]]; then
        info "Theme already exists, updating..."
        rm -rf "$ICONS_DIR/$install_name"
    fi
    
    cp -r "$theme_dir" "$ICONS_DIR/$install_name"
    
    rm -rf "$extract_dir" "$archive"
    
    pass "Installed: $install_name"
}

# --- Search for icons on system ---
search_icons() {
    local query="${1:-}"
    
    echo -e "${CYAN}Searching for icons matching: $query${NC}"
    echo ""
    
    for theme_dir in "$ICONS_DIR"/*/usr/share/icons/*; do
        [[ -d "$theme_dir" ]] || continue
        
        local count
        count=$(find "$theme_dir" -name "*$query*" 2>/dev/null | wc -l)
        
        if [[ "$count" -gt 0 ]]; then
            echo "  $(basename "$theme_dir"): $count matches"
        fi
    done
    
    # System icons
    for theme_dir in /usr/share/icons/*/; do
        [[ -d "$theme_dir" ]] || continue
        
        local count
        count=$(find "$theme_dir" -name "*$query*" 2>/dev/null | wc -l)
        
        if [[ "$count" -gt 0 ]]; then
            echo "  $(basename "$theme_dir"): $count matches"
        fi
    done
}

# --- Main ---
main() {
    case "${1:-help}" in
        list)
            echo -e "${CYAN}Predefined themes:${NC}"
            echo ""
            for name in $(echo "${!THEMES[@]}" | tr ' ' '\n' | sort); do
                local installed=""
                [[ -d "$ICONS_DIR/$name" ]] && installed=" (installed)"
                echo "  $name$installed"
            done
            echo ""
            echo -e "${CYAN}Currently installed:${NC}"
            echo ""
            for dir in "$ICONS_DIR"/*/; do
                [[ -f "$dir/index.theme" ]] && echo "  $(basename "$dir")"
            done
            ;;
        
        install)
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 install <theme-name>"
                echo "Run '$0 list' to see available themes"
                exit 1
            fi
            install_theme "$2"
            ;;
        
        custom)
            if [[ -z "${2:-}" ]] || [[ -z "${3:-}" ]]; then
                echo "Usage: $0 custom <name> <url>"
                exit 1
            fi
            install_custom "$2" "$3"
            ;;
        
        search)
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 search <query>"
                exit 1
            fi
            search_icons "$2"
            ;;
        
        help|--help|-h)
            echo "ocws-icon-downloader — Download and install icon themes"
            echo ""
            echo "Usage:"
            echo "  $0 list               List predefined and installed themes"
            echo "  $0 install <name>     Download and install a predefined theme"
            echo "  $0 custom <name> <url> Download from custom URL"
            echo "  $0 search <query>     Search for icons on system"
            echo ""
            echo "Predefined themes:"
            for name in $(echo "${!THEMES[@]}" | tr ' ' '\n' | sort); do
                echo "  $name"
            done
            ;;
        
        *)
            echo "Unknown command: $1"
            echo "Run '$0 help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
