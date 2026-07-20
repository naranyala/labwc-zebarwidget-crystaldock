#!/bin/bash
# validate-terminal-all.sh — Comprehensive terminal configuration validation with enhanced logging

# Usage: ./scripts/validate-terminal-all.sh [config-path]
#        ./scripts/validate-terminal-all.sh --all  # Validate all found configs

set -uo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────────
MAX_LOGS=20  # Maximum log files to check per service
MIN_LINE_COUNT=5  # Minimum lines for a valid log file
REQUIRED_LOG_MARKERS=("ERROR" "WARNING" "INFO" "DEBUG")
TIMESTAMP_PATTERN="^[0-9]{4}-[0-9]{2}-[0-9]{2}"

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

# File colors (fixed syntax)
declare -A FILE_COLORS
FILE_COLORS=['.log']='$CYAN'
FILE_COLORS=['.txt']='$GREEN'
FILE_COLORS=['.conf']='$YELLOW'
FILE_COLORS=['.config']='$YELLOW'
FILE_COLORS=['.cfg']='$PURPLE'

# ─── State tracking ─────────────────────────────────────────────────────────────
declare -A VALIDATED_SERVICES
declare -A SERVICE_STATUS
declare -A LOG_ANALYSIS
FAILED_CHECKS=0 WARN_CHECKS=0 INFO_CHECKS=0

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
        "WARNING"|"WARN") echo -e "  ${BG_RED}⚠️  WARNING${NC}  $msg" ;;
        "SUCCESS"|"INFO") echo -e "  ${BG_GREEN}✅ SUCCESS${NC}  $msg" ;;
        *) echo -e "  ${BLUE}ℹ  INFO${NC}  $msg" ;;
    esac
}

validate_log_file() {
    local filepath="$1"
    local service_name="$2"
    local rel_path="${filepath#$HOME/}"
    
    # Skip very small files
    if [ $(wc -l < "$filepath") -lt $MIN_LINE_COUNT ]; then
        echo -e "  ${YELLOW}⚠️${NC}  Skipped: '$rel_path' (too small: $(wc -l < "$filepath") lines)"
        return 1
    fi
    
    local status="PASS"
    local issues=()
    local has_timestamps=0
    local has_markers=0
    
    # Check for timestamp pattern
    if grep -qE "$TIMESTAMP_PATTERN" "$filepath" 2>/dev/null; then
        has_timestamps=1
    else
        issues+=("Missing timestamps")
    fi
    
    # Check for log markers in file contents
    local marker_count=0
    for marker in "${REQUIRED_LOG_MARKERS[@]}"; do
        if grep -q "$marker" "$filepath" 2>/dev/null; then
            marker_count=$((marker_count + 1))
        fi
    done
    
    if [ $marker_count -gt 0 ]; then
        has_markers=1
    fi
    
    # Analyze log content for errors/warnings
    local error_count=$(grep -iE "error|fail|critical" "$filepath" 2>/dev/null | grep -v "failed to connect" | wc -l)
    local warning_count=$(grep -iE "warning|warn" "$filepath" 2>/dev/null | wc -l)
    local info_count=$(grep -iE "info|notice" "$filepath" 2>/dev/null | wc -l)
    
    if [ $error_count -gt 0 ] || [ $warning_count -gt 10 ]; then
        status="FAIL"
        [ $error_count -gt 0 ] && issues+=("Contains $error_count errors")
        [ $warning_count -gt 10 ] && issues+=("High warning count: $warning_count")
    elif [ $warning_count -gt 0 ]; then
        status="WARN"
        issues+=("Contains $warning_count warnings")
    fi
    
    # Show analysis
    printf "    [%s] ${CYAN}%s${NC} - " "$status" "$rel_path"
    if [ ${#issues[@]} -gt 0 ]; then
        local issue_summary=""
        for i in "${issues[@]}"; do
            issue_summary+="$i, "
        done
        issue_summary=${issue_summary%, }
        echo -e "${YELLOW}⚠️${NC}  ${DIM}$issue_summary${NC}"
    else
        echo -e "${GREEN}✓${NC}  ${DIM}Clean log${NC}"
    fi
    
    # Track for summary
    LOG_ANALYSIS["$service_name"]="$status"
    if [ "$status" = "FAIL" ]; then
        SERVICE_STATUS["$service_name"]="FAIL"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    elif [ "$status" = "WARN" ] && [[ "${SERVICE_STATUS[$service_name]}" != "FAIL" ]]; then
        SERVICE_STATUS["$service_name"]="WARN"
        WARN_CHECKS=$((WARN_CHECKS + 1))
    else
        SERVICE_STATUS["$service_name"]="OK"
    fi
}

validate_service_logs() {
    local service_name="$1"
    local service_path="$2"
    local found_logs=0
    local total_analyzed=0
    
    section_header "Validating $service_name logs" "📋"
    
    if [ ! -d "$service_path" ]; then
        emoji_log "WARNING" "Service '$service_name' path not found: $service_path"
        return
    fi
    
    # Find log files
    local log_files=()
    while IFS= read -r -d '' file; do
        log_files+=("$file")
    done < <(find "$service_path" -type f \( -name "*.log" -o -name "*.log.*" -o -name "*.txt" \) -maxdepth 1 -print0 2>/dev/null)
    
    # Add common journal logs
    log_files+=($(find "/var/log" /tmp "/run/user/$(id -u)" -maxdepth 3 -name "*$service_name*" -type f 2>/dev/null | head -5))
    
    log_files+=($(journalctl -u "$service_name" --no-pager --all --lines=100 2>/dev/null | sed '/^--$/,$d' || true))
    
    if [ ${#log_files[@]} -eq 0 ]; then
        emoji_log "WARNING" "No log files found for '$service_name' in $service_path"
        return
    fi
    
    emoji_log "INFO" "Found ${#log_files[@]} potential log sources for '$service_name'"
    
    # Analyze each log file
    for file in "${log_files[@]}"; do
        if [ -f "$file" ] && [ -r "$file" ]; then
            total_analyzed=$((total_analyzed + 1))
            local service_instance="$service_name-${total_analyzed}"
            validate_log_file "$file" "$service_instance"
            found_logs=$((found_logs + 1))
        fi
        
        # Limit analysis to prevent overwhelming output
        if [ $total_analyzed -ge $MAX_LOGS ]; then
            echo -e "  ${YELLOW}ℹ${NC}  Limited to ${MAX_LOGS} log files per service (analyzing most relevant)"
            break
        fi
    done
    
    if [ $total_analyzed -gt 0 ]; then
        emoji_log "SUCCESS" "Analyzed $total_analyzed log files for '$service_name'"
    else
        emoji_log "WARNING" "Could not analyze any logs for '$service_name'"
    fi
}

validate_system_services() {
    local service_path="$1"
    
    section_header "System Service Validation" "🖥️"
    
    # Common system services to check
    local system_services=(
        "labwc"
        "foot"
        "hyprland"
        "sway"
        "wayland"
        "dbus"
        "x11"
        "gdm"
        "lightdm"
        "sddm"
    )
    
    for service in "${system_services[@]}"; do
        # Check if service is installed
        if command -v "$service" >/dev/null 2>&1 || systemctl list-unit-files | grep -q "^$service\.service"; then
            validate_service_logs "$service" "$service_path"
        fi
    done
    
    # Check for specific config validation in system logs
    section_header "System Log Analysis" "📊"
    
    # Collect system journal entries
    local system_errors=$(journalctl --priority=1,2,3 --since="1 day ago" 2>/dev/null | grep -c "labwc\|foot\|wayland" || echo "0")
    local system_warnings=$(journalctl --priority=4 --since="1 day ago" 2>/dev/null | grep -c "labwc\|foot\|wayland" || echo "0")
    
    echo "  ${CYAN}System Log Summary:${NC}"
    echo "    ${YELLOW}Recent Errors/Warnings:${NC} $system_errors errors, $system_warnings warnings (last 24h)"
    
    # Check for known issues in system logs
    if [ $system_errors -gt 0 ]; then
        emoji_log "WARNING" "$system_errors system errors detected (check journalctl -xe)"
    fi
    if [ $system_warnings -gt 5 ]; then
        emoji_log "SUCCESS" "System warnings normal: $system_warnings (last 24h)"
    elif [ $system_warnings -gt 0 ]; then
        emoji_log "INFO" "Minor system warnings: $system_warnings"
    fi
}

main() {
    # Clear screen and show header
    clear
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║${NC}  ${WHITE}Terminal Configuration & Log Validator${NC}                     ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Parse arguments
    if [ "${1:-}" = "--all" ]; then
        # Validate all found configs
        validate_system_services "/var/log"
    else
        local path="${1:-}"
        
        # Use provided path or check for log directories
        if [ -z "$path" ] || [ "$path" = "${1:-}" ]; then
            # Look for log directories
            local log_candidates=(
                "$HOME/.local/share/labwc/logs"
                "$HOME/.var/app/org.labwc.Labwc/data"
                "/var/log"
                "/tmp"
            )
            
            local found_dir=""
            for candidate in "${log_candidates[@]}"; do
                if [ -d "$candidate" ] || [ -f "$candidate" ]; then
                    found_dir="$candidate"
                    break
                fi
            done
            
            if [ -n "$found_dir" ]; then
                path="$found_dir"
                echo -e "${GREEN}✅${NC}  Using log directory: $path"
            else
                echo -e "${RED}❌${NC}  No log directory found. Please specify a path or install labwc logs."
                exit 1
            fi
        fi
        
        # Validate logs in specified path
        validate_service_logs "labwc" "$path"
        validate_service_logs "foot" "$path"
    fi
    
    # Show comprehensive summary
    display_summary
    
    # Return appropriate exit code
    if [ $FAILED_CHECKS -gt 0 ]; then
        echo ""
        echo -e "${RED}${BOLD}❌ CRITICAL ISSUES FOUND - Please review failed checks above${NC}"
        exit 1
    elif [ $WARN_CHECKS -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}${BOLD}⚠️  WARNINGS FOUND - Review warnings for issues${NC}"
        exit 2
    else
        echo ""
        echo -e "${GREEN}${BOLD}✅ All checks passed - Terminal configuration is in good health${NC}"
        exit 0
    fi
}

display_summary() {
    section_header "Validation Summary" "📋"
    
    echo "  ${CYAN}Services Analyzed:${NC}"
    for service in "${!SERVICE_STATUS[@]}"; do
        local status="${SERVICE_STATUS[$service]}"
        local symbol=""
        local color=""
        
        case "$status" in
            "FAIL")
                symbol="❌"
                color="${RED}"
                ;;
            "WARN")
                symbol="⚠️"
                color="${YELLOW}"
                ;;
            "OK")
                symbol="✅"
                color="${GREEN}"
                ;;
            *)
                symbol="❓"
                color="${BLUE}"
                ;;
        esac
        
        echo "    $color$symbol $service$NC"
    done
    
    echo ""
    echo "  ${CYAN}Log Analysis Summary:${NC}"
    for service in "${!LOG_ANALYSIS[@]}"; do
        local status="${LOG_ANALYSIS[$service]}"
        local emoji=""
        
        case "$status" in
            "FAIL") emoji="❌" ;;
            "WARN") emoji="⚠️" ;;
            "PASS") emoji="✅" ;;
            *) emoji="❓" ;;
        esac
        
        echo "    $emoji $service: ${LOG_ANALYSIS[$service]}"
    done
    
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║                    VALIDATION RESULTS SUMMARY                    ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    printf "  ${GREEN}✅ PASS: %-3d${NC}  ${YELLOW}⚠️ WARN: %-3d${NC}  ${RED}❌ FAIL: %-3d${NC}\n" \
        $(((PASS + WARN + INFO) - FAILED - WARN_CHECKS)) $WARN_CHECKS $FAILED_CHECKS
}

# Run main function
main "$@"