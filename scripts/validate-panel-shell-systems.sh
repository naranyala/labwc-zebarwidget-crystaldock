#!/bin/bash
# validate-panel-shell-systems.sh — Unified validation for all panel/shell environments

# Usage: ./scripts/validate-panel-shell-systems.sh [config-dir]
#        ./scripts/validate-panel-shell-systems.sh --all  # Validate all configs

set -uo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────────

# Default paths for each panel/shell system
declare -A PANEL_SYSTEMS=(
    ["labwc"]="$HOME/.config/labwc"
    ["sfwbar"]="$HOME/.config/sfwbar"
    ["noctalia"]="$HOME/.config/noctalia"
    ["DankMaterialShell"]="$HOME/.local/share/DankMaterialShell"
)

# Colors for enhanced visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# ─── Summary tracking ───────────────────────────────────────────────────────────
declare -A SYSTEM_STATUS
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_WARN=0

# ─── Helper functions ───────────────────────────────────────────────────────────

section_header() {
    local title="$1"
    local icon="$2"
    printf '\n%s%s %-60s %s\n' "$BOLD" "$icon" "$title" "$NC"
    printf '%s' "${DIM}━$(printf '%*s' $(((80 - ${#title} - 6))) '' )${NC}"
    printf '\n'
}

emoji_log() {
    local level="$1"
    local msg="$2"
    
    case "$level" in
        "CRITICAL"|"ERROR") echo -e "  ${BG_RED}❌ ERROR${NC}  $msg" ;;
        "WARNING") echo -e "  ${BG_YELLOW}⚠️  WARN${NC}  $msg" ;;
        "SUCCESS") echo -e "  ${BG_GREEN}✅ SUCCESS${NC}  $msg" ;;
        *) echo -e "  ${BLUE}ℹ  INFO${NC}  $msg" ;;
    esac
}

# ─── Individual system validation functions ───────────────────────────────────

validate_labwc() {
    local config_dir="$1"
    local rel_path="${config_dir#$HOME/}"
    
    section_header "Labwc Validation" "🪟"
    
    if [ ! -d "$config_dir" ]; then
        emoji_log "WARNING" "Labwc config not found: $rel_path"
        return
    fi
    
    local rc_file="$config_dir/rc.xml"
    local menu_file="$config_dir/menu.xml"
    
    # Check essential files
    local essentials=0
    local total_essentials=3
    
    if [ -f "$rc_file" ]; then
        emoji_log "SUCCESS" "rc.xml exists ($rel_path/rc.xml)"
        essentials=$((essentials + 1))
    else
        emoji_log "ERROR" "rc.xml missing"
    fi
    
    if [ -f "$menu_file" ]; then
        emoji_log "SUCCESS" "menu.xml exists ($rel_path/menu.xml)"
        essentials=$((essentials + 1))
    else
        emoji_log "ERROR" "menu.xml missing"
    fi
    
    # Check for theme configuration
    if [ -f "$config_dir/themerc-override" ]; then
        emoji_log "SUCCESS" "themerc-override exists"
        essentials=$((essentials + 1))
    else
        emoji_log "WARNING" "themerc-override not found"
    fi
    
    # Validate XML structure if xmllint available
    if command -v xmllint >/dev/null 2>&1; then
        if [ -f "$rc_file" ] && xmllint --noout "$rc_file" 2>/dev/null; then
            emoji_log "SUCCESS" "rc.xml is valid XML"
        elif [ -f "$rc_file" ]; then
            emoji_log "WARNING" "rc.xml has XML issues (check manually)"
        fi
        
        if [ -f "$menu_file" ] && xmllint --noout "$menu_file" 2>/dev/null; then
            emoji_log "SUCCESS" "menu.xml is valid XML"
        elif [ -f "$menu_file" ]; then
            emoji_log "WARNING" "menu.xml has XML issues (check manually)"
        fi
    fi
    
    # Validate essential keybinds in rc.xml
    if [ -f "$rc_file" ]; then
        local essential_keys_found=0
        
        # Check for essential keyboard shortcuts
        local essential_bindings=(
            "A-r\tReconfigure"
            "A-q\tClose" 
            "A-Return\tTerminal"
            "A-f\tToggleFullscreen"
            "A-space\tShowMenu"
        )
        
        for binding in "${essential_bindings[@]}"; do
            local key=$(echo "$binding" | cut -d'	' -f1)
            local action=$(echo "$binding" | cut -d'	' -f2-)
            
            if grep -q "key=\"$key\"" "$rc_file" 2>/dev/null; then
                emoji_log "SUCCESS" "Essential keybind: $key → $action"
                essential_keys_found=$((essential_keys_found + 1))
            fi
        done
        
        if [ $essential_keys_found -gt 0 ]; then
            emoji_log "SUCCESS" "$essential_keys_found/$((${#essential_bindings[@]})) essential keybinds present"
        else
            emoji_log "WARNING" "No essential keybinds found"
        fi
    fi
    
    # Update system status
    if [ $essentials -eq $total_essentials ]; then
        SYSTEM_STATUS["labwc"]="PASS"
        TOTAL_PASS=$((TOTAL_PASS + 1))
    elif [ $essentials -ge $((total_essentials * 2 / 3)) ]; then
        SYSTEM_STATUS["labwc"]="WARN"
        TOTAL_WARN=$((TOTAL_WARN + 1))
    else
        SYSTEM_STATUS["labwc"]="FAIL"
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
}

validate_sfwbar() {
    local config_dir="$1"
    local rel_path="${config_dir#$HOME/}"
    
    section_header "SFWBar Validation" "📟"
    
    if [ ! -d "$config_dir" ]; then
        emoji_log "WARNING" "SFWBar config not found: $rel_path"
        return
    fi
    
    # Check for essential configuration files
    local config_files=(
        "$config_dir/config/sfwbar.config"
        "$config_dir/config/switcher.config"
    )
    
    local configs_found=0
    
    for config_file in "${config_files[@]}"; do
        if [ -f "$config_file" ]; then
            local config_name=$(basename "$config_file")
            local line_count=$(wc -l < "$config_file")
            emoji_log "SUCCESS" "$config_name exists ($line_count lines)"
            configs_found=$((configs_found + 1))
        else
            emoji_log "WARNING" "$(basename "$config_file") not found"
        fi
    done
    
    # Check for critical configuration values
    if [ -f "${config_dir}config/sfwbar.config" ]; then
        # Look for essential settings
        local has_title_bar=0
        local has_menu=0
        local has_close_button=0
        
        if grep -q "title.*bar" "${config_dir}config/sfwbar.config" 2>/dev/null; then
            has_title_bar=1
        fi
        
        if grep -q "menu.*entry" "${config_dir}config/sfwbar.config" 2>/dev/null; then
            has_menu=1
        fi
        
        if grep -q "close.*button" "${config_dir}config/sfwbar.config" 2>/dev/null; then
            has_close_button=1
        fi
        
        if [ $has_title_bar -eq 1 ] && [ $has_menu -eq 1 ] && [ $has_close_button -eq 1 ]; then
            emoji_log "SUCCESS" "Essential UI elements configured"
        else
            emoji_log "WARNING" "Missing essential UI elements"
        fi
    fi
    
    # Update system status
    if [ $configs_found -ge 1 ]; then
        SYSTEM_STATUS["sfwbar"]="PASS"
        TOTAL_PASS=$((TOTAL_PASS + 1))
    else
        SYSTEM_STATUS["sfwbar"]="FAIL"
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
}

validate_noctalia() {
    local config_dir="$1"
    local rel_path="${config_dir#$HOME/}"
    
    section_header "Noctalia Validation" "🌙"
    
    if [ ! -d "$config_dir" ]; then
        emoji_log "WARNING" "Noctalia config not found: $rel_path"
        return
    fi
    
    # Check for essential configuration files
    local config_files=(
        "$config_dir/config.toml"
        "$config_dir/themes"
        "$config_dir/assets"
    )
    
    local configs_found=0
    
    for config_file in "${config_files[@]}"; do
        if [ -e "$config_file" ]; then
            if [ -f "$config_file" ]; then
                local name=$(basename "$config_file")
                emoji_log "SUCCESS" "$name exists"
            else
                emoji_log "SUCCESS" "$name exists (directory)"
            fi
            configs_found=$((configs_found + 1))
        else
            emoji_log "WARNING" "$(basename "$config_file") not found"
        fi
    done
    
    # Check for shell integration files
    if [ -f "$config_dir/shell.nix" ] || [ -f "$config_dir/default.nix" ]; then
        emoji_log "SUCCESS" "Shell integration configured"
        configs_found=$((configs_found + 1))
    fi
    
    # Check for theme configuration
    if [ -d "$config_dir/themes" ] && [$(ls "$config_dir/themes" 2>/dev/null | wc -l) -gt 0 ]; then
        local theme_count=$(ls "$config_dir/themes" 2>/dev/null | wc -l)
        emoji_log "SUCCESS" "$theme_count themes available"
        configs_found=$((configs_found + 1))
    fi
    
    # Update system status
    if [ $configs_found -ge 3 ]; then
        SYSTEM_STATUS["noctalia"]="PASS"
        TOTAL_PASS=$((TOTAL_PASS + 1))
    elif [ $configs_found -ge 2 ]; then
        SYSTEM_STATUS["noctalia"]="WARN"
        TOTAL_WARN=$((TOTAL_WARN + 1))
    else
        SYSTEM_STATUS["noctalia"]="FAIL"
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
}

validate_DankMaterialShell() {
    local config_dir="$1"
    local rel_path="${config_dir#$HOME/}"
    
    section_header "DankMaterialShell Validation" "🎨"
    
    if [ ! -d "$config_dir" ]; then
        emoji_log "WARNING" "DankMaterialShell config not found: $rel_path"
        return
    fi
    
    # Check for essential components
    local essential_components=(
        "quickshell"
        "dms-core"
        "dms-plugins"
        "config"
    )
    
    local components_found=0
    
    for component in "${essential_components[@]}"; do
        if [ -d "$config_dir/$component" ]; then
            emoji_log "SUCCESS" "$component exists"
            components_found=$((components_found + 1))
        else
            emoji_log "WARNING" "$component not found"
        fi
    done
    
    # Check for configuration files
    if [ -f "$config_dir/config.toml" ] || [ -f "$config_dir/justfile" ]; then
        emoji_log "SUCCESS" "Configuration system found"
        components_found=$((components_found + 1))
    fi
    
    # Check for example configurations
    if [ -d "$config_dir/quickshell" ] && [$(ls "$config_dir/quickshell" 2>/dev/null | grep -c "*.toml") -gt 0 ]; then
        local config_count=$(ls "$config_dir/quickshell"/*.toml 2>/dev/null | wc -l)
        emoji_log "SUCCESS" "$config_count quickshell configs available"
        components_found=$((components_found + 1))
    fi
    
    # Update system status
    if [ $components_found -ge 3 ]; then
        SYSTEM_STATUS["DankMaterialShell"]="PASS"
        TOTAL_PASS=$((TOTAL_PASS + 1))
    elif [ $components_found -ge 2 ]; then
        SYSTEM_STATUS["DankMaterialShell"]="WARN"
        TOTAL_WARN=$((TOTAL_WARN + 1))
    else
        SYSTEM_STATUS["DankMaterialShell"]="FAIL"
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
}

validate_lxqt() {
    local config_dir="$1"
    local rel_path="${config_dir#$HOME/}"
    
    section_header "LXQt Validation" "🖥️"
    
    if [ ! -d "$config_dir" ]; then
        emoji_log "WARNING" "LXQt config not found: $rel_path"
        return
    fi
    
    # Check for essential LXQt files
    local config_files=(
        "$config_dir/startup"  # Example startup script
        "$config_dir/session"  # LXQt session config (if it exists)
    )
    
    local configs_found=0
    
    for config_file in "${config_files[@]}"; do
        if [ -e "$config_file" ]; then
            if [ -f "$config_file" ]; then
                emoji_log "SUCCESS" "$(basename "$config_file") exists"
            else
                emoji_log "SUCCESS" "$(basename "$config_file") exists (directory)"
            fi
            configs_found=$((configs_found + 1))
        else
            emoji_log "WARNING" "$(basename "$config_file") not found"
        fi
    done
    
    # Check for panel configuration
    if find "$config_dir" -name "*.conf" -type f 2>/dev/null | grep -q panel; then
        local panel_confs=$(find "$config_dir" -name "*.conf" -type f 2>/dev/null | grep panel | wc -l)
        emoji_log "SUCCESS" "$panel_confs panel config(s) found"
        configs_found=$((configs_found + 1))
    fi
    
    # Update system status
    if [ $configs_found -ge 2 ]; then
        SYSTEM_STATUS["lxqt"]="PASS"
        TOTAL_PASS=$((TOTAL_PASS + 1))
    elif [ $configs_found -ge 1 ]; then
        SYSTEM_STATUS["lxqt"]="WARN"
        TOTAL_WARN=$((TOTAL_WARN + 1))
    else
        SYSTEM_STATUS["lxqt"]="FAIL"
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
}

# ─── Main validation logic ─────────────────────────────────────────────────────

main() {
    # Clear screen and show header
    clear
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║${NC}  ${WHITE}Panel/Shell Systems Unified Validator${NC}                      ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Parse arguments
    if [ "${1:-}" = "--all" ]; then
        # Validate all configurations with default paths
        for system in "${!PANEL_SYSTEMS[@]}"; do
            local config_dir="${PANEL_SYSTEMS[$system]}"
            case "$system" in
                labwc) validate_labwc "$config_dir" ;;
                sfwbar) validate_sfwbar "$config_dir" ;;
                noctalia) validate_noctalia "$config_dir" ;;
                DankMaterialShell) validate_DankMaterialShell "$config_dir" ;;
                lxqt) validate_lxqt "$config_dir" ;;
            esac
        done
    else
        local custom_path="${1:-}"
        
        if [ -z "$custom_path" ] || [ "$custom_path" = "${1:-}" ]; then
            # Look for configuration directories in common locations
            local common_dirs=(
                "$HOME/.config/labwc"
                "$HOME/.config/sfwbar"
                "$HOME/.config/noctalia"
                "$HOME/.local/share/DankMaterialShell"
            )
            
            for system in labwc sfwbar noctalia DankMaterialShell lxqt; do
                case "$system" in
                    labwc) 
                        for dir in "${common_dirs[@]}"; do
                            if [ "${dir#$HOME/.config/labwc}" = "$dir" ]; then
                                validate_labwc "$dir"
                                break
                            fi
                        done
                        ;;
                    sfwbar)
                        for dir in "${common_dirs[@]}"; do
                            if [ "${dir#$HOME/.config/sfwbar}" = "$dir" ]; then
                                validate_sfwbar "$dir"
                                break
                            fi
                        done
                        ;;
                    noctalia)
                        for dir in "${common_dirs[@]}"; do
                            if [ "${dir#$HOME/.config/noctalia}" = "$dir" ]; then
                                validate_noctalia "$dir"
                                break
                            fi
                        done
                        ;;
                    DankMaterialShell)
                        for dir in "${common_dirs[@]}"; do
                            if [ "${dir#$HOME/.local/share/DankMaterialShell}" = "$dir" ]; then
                                validate_DankMaterialShell "$dir"
                                break
                            fi
                        done
                        ;;
                    lxqt)
                        # LXQt might be in ~/.config/lxqt
                        if [ -d "$HOME/.config/lxqt" ]; then
                            validate_lxqt "$HOME/.config/lxqt"
                        fi
                        ;;
                esac
            done
        else
            # Use custom path
            validate_panel_system "$custom_path"
        fi
    fi
    
    # Show comprehensive summary
    display_summary
    
    # Return appropriate exit code
    if [ $TOTAL_FAIL -gt 0 ]; then
        echo ""
        echo -e "${RED}${BOLD}❌ CRITICAL ISSUES FOUND - Multiple systems need attention${NC}"
        exit 1
    elif [ $TOTAL_WARN -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}${BOLD}⚠️  WARNINGS FOUND - Review warnings for system optimization${NC}"
        exit 2
    else
        echo ""
        echo -e "${GREEN}${BOLD}✅ All panel/shell systems configured correctly${NC}"
        exit 0
    fi
}

display_summary() {
    section_header "Validation Summary" "📊"
    
    echo "  ${CYAN}Systems Validated:${NC}"
    for system in "${!SYSTEM_STATUS[@]}"; do
        local status="${SYSTEM_STATUS[$system]}"
        local emoji=""
        local color=""
        
        case "$status" in
            "FAIL")
                emoji="❌"
                color="${RED}"
                ;;
            "WARN")
                emoji="⚠️"
                color="${YELLOW}"
                ;;
            "PASS")
                emoji="✅"
                color="${GREEN}"
                ;;
            *)
                emoji="❓"
                color="${BLUE}"
                ;;
        esac
        
        echo "    $color$emoji $system$NC"
    done
    
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║                    VALIDATION RESULTS SUMMARY                    ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    printf "  ${GREEN}✅ PASS: %-3d${NC}  ${YELLOW}⚠️ WARN: %-3d${NC}  ${RED}❌ FAIL: %-3d${NC}\n" \
        $TOTAL_PASS $TOTAL_WARN $TOTAL_FAIL
}

# Run main function
main "$@"