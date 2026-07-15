#!/bin/bash
# dock-pin-backup.sh — Backup & restore dock pinned apps
# Supports: Noctalia, Zigshell-cairo-pango, DankMaterialShell
#
# Usage:
#   dock-pin-backup save [name]     Save current pinned apps
#   dock-pin-backup load [name]     Restore pinned apps from backup
#   dock-pin-backup list            List all backups
#   dock-pin-backup delete [name]   Delete a backup
#   dock-pin-backup diff [name]     Show diff between current and backup

set -euo pipefail

BACKUP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/ocws/dock-backups"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "${CYAN}→${NC} $1"; }
pass()  { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
fail()  { echo -e "${RED}✗${NC} $1"; exit 1; }

# ============================================================
# Detect which shell is active
# ============================================================

detect_shell() {
    local shell_file="$CONFIG_DIR/ocws/mode"
    if [[ -f "$shell_file" ]]; then
        cat "$shell_file"
    else
        # Auto-detect from installed configs
        if [[ -f "$CONFIG_DIR/noctalia/config.toml" ]]; then
            echo "noctalia"
        elif [[ -f "$CONFIG_DIR/zigshell-cairo-pango/panel_1.conf" ]]; then
            echo "zigshell-cairo-pango"
        elif [[ -f "$CONFIG_DIR/DankMaterialShell/settings.json" ]]; then
            echo "dms"
        else
            echo "unknown"
        fi
    fi
}

# ============================================================
# Extract pinned apps
# ============================================================

extract_noctalia() {
    local config="$CONFIG_DIR/noctalia/config.toml"
    [[ -f "$config" ]] || return 1

    # Extract pinned = [...] line
    local pinned_line
    pinned_line=$(grep -E '^pinned\s*=' "$config" 2>/dev/null || echo "")
    if [[ -z "$pinned_line" ]]; then
        echo "[]"
        return
    fi

    # Parse TOML array: pinned = ["app1", "app2"]
    echo "$pinned_line" | sed 's/^pinned\s*=\s*//' | tr -d '[:space:]'
}

extract_zigshell-cairo-pango() {
    local config="$CONFIG_DIR/zigshell-cairo-pango/panel_1.conf"
    [[ -f "$config" ]] || return 1

    local launchers
    launchers=$(grep -E '^launchers=' "$config" 2>/dev/null || echo "")
    if [[ -z "$launchers" ]]; then
        echo "[]"
        return
    fi

    # Convert semicolon-separated to JSON array, filtering out "separator" and "show-desktop"
    echo "$launchers" | sed 's/^launchers="//' | sed 's/"$//' | \
        tr ';' '\n' | \
        grep -v -E '^(separator|show-desktop)$' | \
        sed 's/^/"/' | sed 's/$/"/' | \
        paste -sd',' | sed 's/^/[/' | sed 's/$/]/'
}

extract_dms() {
    local config="$CONFIG_DIR/DankMaterialShell/settings.json"
    [[ -f "$config" ]] || return 1

    # DMS stores pinned apps in a different location (user state, not config)
    # Check common locations
    local dms_state="$HOME/.local/share/DankMaterialShell"
    if [[ -d "$dms_state" ]]; then
        local pinned_file
        pinned_file=$(find "$dms_state" -name "*.json" -exec grep -l "pinned" {} \; 2>/dev/null | head -1)
        if [[ -n "$pinned_file" ]]; then
            # Extract pinned apps from JSON
            grep -o '"pinned":\s*\[.*\]' "$pinned_file" 2>/dev/null | \
                sed 's/"pinned":\s*//' || echo "[]"
            return
        fi
    fi

    # Fallback: check settings.json for dock-related pinned apps
    python3 -c "
import json, sys
with open('$config') as f:
    data = json.load(f)
# DMS doesn't have a direct pinned field in settings.json
# The pinned apps are managed at runtime
print('[]')
" 2>/dev/null || echo "[]"
}

# ============================================================
# Restore pinned apps
# ============================================================

restore_noctalia() {
    local pinned="$1"
    local config="$CONFIG_DIR/noctalia/config.toml"
    [[ -f "$config" ]] || fail "Noctalia config not found"

    # Replace pinned line in config
    if grep -q '^pinned\s*=' "$config"; then
        sed -i "s|^pinned\s*=.*|pinned = $pinned|" "$config"
    else
        # Add pinned after [dock] section
        sed -i "/^\[dock\]/a pinned = $pinned" "$config"
    fi

    pass "Noctalia pinned apps restored"
    info "Restart noctalia to apply: noctalia msg reload"
}

restore_zigshell-cairo-pango() {
    local pinned="$1"
    local config="$CONFIG_DIR/zigshell-cairo-pango/panel_1.conf"
    [[ -f "$config" ]] || fail "Zigshell-cairo-pango config not found"

    # Convert JSON array back to semicolon-separated, adding back separators
    local launchers
    launchers=$(echo "$pinned" | python3 -c "
import json, sys
apps = json.load(sys.stdin)
# Add show-desktop at start and separators
result = ['show-desktop'] + apps + ['separator', 'lxqt-lockscreen', 'lxqt-logout', 'separator']
print(';'.join(result))
" 2>/dev/null)

    if [[ -n "$launchers" ]]; then
        sed -i "s|^launchers=.*|launchers=\"$launchers\"|" "$config"
        pass "Zigshell-cairo-pango pinned apps restored"
    else
        fail "Failed to parse pinned apps"
    fi
}

restore_dms() {
    warn "DankMaterialShell pinned apps are managed at runtime."
    info "Please manually pin apps through the DMS UI."
    info "Backup saved for reference only."
}

# ============================================================
# Commands
# ============================================================

cmd_save() {
    local name="${1:-$(date +%Y%m%d-%H%M%S)}"
    local shell
    shell=$(detect_shell)

    mkdir -p "$BACKUP_DIR"

    local pinned=""
    case "$shell" in
        noctalia)
            pinned=$(extract_noctalia) || fail "Failed to read Noctalia config"
            ;;
        zigshell-cairo-pango)
            pinned=$(extract_zigshell-cairo-pango) || fail "Failed to read Zigshell-cairo-pango config"
            ;;
        dms)
            pinned=$(extract_dms)
            ;;
        *)
            fail "Unknown shell: $shell"
            ;;
    esac

    # Save backup with metadata
    local backup_file="$BACKUP_DIR/${name}.json"
    cat > "$backup_file" <<EOF
{
  "name": "$name",
  "shell": "$shell",
  "timestamp": "$(date -Iseconds)",
  "pinned": $pinned
}
EOF

    pass "Saved backup: $name"
    info "Shell: $shell"
    info "Location: $backup_file"
}

cmd_load() {
    local name="${1:-}"
    [[ -n "$name" ]] || fail "Usage: dock-pin-backup load <name>"

    local backup_file="$BACKUP_DIR/${name}.json"
    [[ -f "$backup_file" ]] || fail "Backup not found: $name"

    local shell pinned
    shell=$(python3 -c "import json; print(json.load(open('$backup_file'))['shell'])")
    pinned=$(python3 -c "import json; print(json.dumps(json.load(open('$backup_file'))['pinned']))")

    local current_shell
    current_shell=$(detect_shell)

    if [[ "$shell" != "$current_shell" ]]; then
        warn "Backup is for $shell, but current shell is $current_shell"
        echo -n "Continue anyway? [y/N]: "
        read -r confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
    fi

    case "$current_shell" in
        noctalia)
            restore_noctalia "$pinned"
            ;;
        zigshell-cairo-pango)
            restore_zigshell-cairo-pango "$pinned"
            ;;
        dms)
            restore_dms
            ;;
        *)
            fail "Unknown shell: $current_shell"
            ;;
    esac
}

cmd_list() {
    [[ -d "$BACKUP_DIR" ]] || { info "No backups found"; return; }

    local count=0
    echo -e "${BOLD}Dock Pin Backups:${NC}"
    echo ""

    for f in "$BACKUP_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        count=$((count + 1))

        local name shell timestamp pin_count
        name=$(python3 -c "import json; print(json.load(open('$f'))['name'])")
        shell=$(python3 -c "import json; print(json.load(open('$f'))['shell'])")
        timestamp=$(python3 -c "import json; print(json.load(open('$f'))['timestamp'])")
        pin_count=$(python3 -c "import json; print(len(json.load(open('$f'))['pinned']))")

        printf "  ${CYAN}%-20s${NC} %-12s %s apps  %s\n" "$name" "$shell" "$pin_count" "$timestamp"
    done

    if [[ $count -eq 0 ]]; then
        info "No backups found"
    fi
}

cmd_delete() {
    local name="${1:-}"
    [[ -n "$name" ]] || fail "Usage: dock-pin-backup delete <name>"

    local backup_file="$BACKUP_DIR/${name}.json"
    [[ -f "$backup_file" ]] || fail "Backup not found: $name"

    rm -f "$backup_file"
    pass "Deleted backup: $name"
}

cmd_diff() {
    local name="${1:-}"
    [[ -n "$name" ]] || fail "Usage: dock-pin-backup diff <name>"

    local backup_file="$BACKUP_DIR/${name}.json"
    [[ -f "$backup_file" ]] || fail "Backup not found: $name"

    local shell pinned
    shell=$(python3 -c "import json; print(json.load(open('$backup_file'))['shell'])")
    pinned=$(python3 -c "import json; print(json.dumps(json.load(open('$backup_file'))['pinned'], indent=2))")

    local current
    case "$shell" in
        noctalia) current=$(extract_noctalia) ;;
        zigshell-cairo-pango) current=$(extract_zigshell-cairo-pango) ;;
        *) fail "Diff not supported for $shell" ;;
    esac

    local current_formatted
    current_formatted=$(echo "$current" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin), indent=2))")

    echo -e "${BOLD}Backup ($name):${NC}"
    echo "$pinned"
    echo ""
    echo -e "${BOLD}Current:${NC}"
    echo "$current_formatted"
}

# ============================================================
# Main
# ============================================================

MODE="${1:-}"
shift || true

case "$MODE" in
    save|backup)
        cmd_save "${1:-}"
        ;;
    load|restore)
        cmd_load "${1:-}"
        ;;
    list|ls)
        cmd_list
        ;;
    delete|rm)
        cmd_delete "${1:-}"
        ;;
    diff|compare)
        cmd_diff "${1:-}"
        ;;
    *)
        echo -e "${BOLD}Dock Pin Backup${NC}"
        echo ""
        echo "Usage: dock-pin-backup <command> [args]"
        echo ""
        echo "Commands:"
        echo "  save [name]      Save current pinned apps (default: timestamp)"
        echo "  load <name>      Restore pinned apps from backup"
        echo "  list             List all backups"
        echo "  delete <name>    Delete a backup"
        echo "  diff <name>      Compare backup with current"
        echo ""
        echo "Examples:"
        echo "  dock-pin-backup save work-setup"
        echo "  dock-pin-backup save gaming-setup"
        echo "  dock-pin-backup load work-setup"
        echo "  dock-pin-backup list"
        ;;
esac
