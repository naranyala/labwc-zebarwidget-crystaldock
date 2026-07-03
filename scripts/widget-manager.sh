#!/bin/bash
#
# widget-manager.sh — Manage C-based Wayland widget and statusbar components
#
# Swap, list, status, and configure components.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPONENTS_DIR="$PROJECT_DIR/components"
CONFIG_DIR="${HOME}/.config/labwc-widgets"
REGISTRY="$COMPONENTS_DIR/registry.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

pass()  { echo -e "  ${GREEN}✓${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
info()  { echo -e "  ${CYAN}→${NC} $1"; }
fail()  { echo -e "  ${RED}✗${NC} $1"; exit 1; }
section() { echo -e "\n${BOLD}[$1]${NC}"; }

ACTION="${1:-help}"
shift || true

# ---- JSON helpers (simple, no jq dependency) ----

json_get() {
    local file="$1" key="$2"
    grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null | \
        head -1 | sed 's/.*": *"//;s/"$//'
}

json_get_array() {
    local file="$1" key="$2"
    grep -o "\"$key\"[[:space:]]*:[[:space:]]*\[[^\]]*\]" "$file" 2>/dev/null | \
        head -1 | sed 's/.*\[//;s/\].*//' | tr ',' '\n' | tr -d ' "'
}

# ---- Config management ----

ensure_config() {
    mkdir -p "$CONFIG_DIR"
    if [[ ! -f "$CONFIG_DIR/status.json" ]]; then
        cat > "$CONFIG_DIR/status.json" << 'EOF'
{
  "statusbar": "main",
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
        pass "Created default config"
    fi
}

get_current() {
    local key="$1"
    ensure_config
    json_get "$CONFIG_DIR/status.json" "$key"
}

set_current() {
    local key="$1" value="$2"
    ensure_config

    # Simple sed replacement
    if grep -q "\"$key\"" "$CONFIG_DIR/status.json"; then
        sed -i "s|\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"|\"$key\": \"$value\"|" \
            "$CONFIG_DIR/status.json"
    else
        # Add before closing brace
        sed -i "s|}$|  ,\"$key\": \"$value\"\n}|" "$CONFIG_DIR/status.json"
    fi
}

# ---- Commands ----

cmd_list() {
    local category="${1:-all}"

    section "Available Components"

    if [[ "$category" == "all" || "$category" == "statusbars" ]]; then
        echo -e "\n${BOLD}Statusbars:${NC}"
        local current_bar=$(get_current "statusbar")
        for name in sfwbar; do
            local marker=""
            [[ "$name" == "$current_bar" ]] && marker=" ${GREEN}← active${NC}"
            local desc="SFWBar (GTK3, C-based, wayland-native) - Only accepted panel/statusbar/taskbar"
            echo -e "  ${CYAN}$name${NC}${marker}  ${DIM}$desc${NC}"
        done
    fi

    if [[ "$category" == "all" || "$category" == "widgets" ]]; then
        echo -e "\n${BOLD}Widgets:${NC}"
        for name in clock cpu memory network battery volume; do
            echo -e "  ${CYAN}$name${NC}"
        done
    fi

    if [[ "$category" == "all" || "$category" == "docks" ]]; then
        echo -e "\n${BOLD}Docks:${NC}"
        local current_dock=$(get_current "dock")
        for name in crystal none; do
            local marker=""
            [[ "$name" == "$current_dock" ]] && marker=" ${GREEN}← active${NC}"
            echo -e "  ${CYAN}$name${NC}${marker}"
        done
    fi

    echo ""
}

cmd_swap() {
    local category="${1:-}"
    local target="${2:-}"

    [[ -z "$category" ]] && fail "Usage: $0 swap <statusbar|dock> <name>"
    [[ -z "$target" ]] && fail "Usage: $0 swap <statusbar|dock> <name>"

    case "$category" in
        statusbar|bar)
            # Validate statusbar exists
            case "$target" in
                sfwbar)
                    if ! command -v sfwbar >/dev/null 2>&1; then
                        fail "sfwbar not installed. Build and install first."
                    fi
                    ;;
                *)
                    fail "Unknown statusbar: $target (use sfwbar only)"
                    ;;
            esac

            local current=$(get_current "statusbar")
            [[ "$current" == "$target" ]] && { info "Already using '$target'"; return; }

            set_current "statusbar" "$target"
            pass "Switched statusbar: $current → $target"
            echo ""
            info "Restart statusbar to apply:"
            echo "    pkill -f sfwbar; sfwbar &"
            echo ""
            ;;

        dock)
            # Check if dock exists in registry
            if [[ "$target" != "none" ]]; then
                if [[ ! -d "$COMPONENTS_DIR/dock/$target" ]]; then
                    warn "Dock '$target' not found in components/dock/"
                fi
            fi

            local current=$(get_current "dock")
            [[ "$current" == "$target" ]] && { info "Already using '$target'"; return; }

            set_current "dock" "$target"
            pass "Switched dock: $current → $target"
            echo ""
            info "Restart dock to apply:"
            if [[ "$target" == "none" ]]; then
                echo "    pkill -f crystal-dock"
            else
                echo "    pkill -f crystal-dock; crystal-dock --start --overlay &"
            fi
            echo ""
            ;;

        *)
            fail "Unknown category: $category (use 'statusbar' or 'dock')"
            ;;
    esac
}

cmd_status() {
    ensure_config

    section "Current Configuration"

    local statusbar=$(get_current "statusbar")
    local dock=$(get_current "dock")
    local theme=$(get_current "theme")

    echo -e "  ${BOLD}Statusbar:${NC}  ${CYAN}$statusbar${NC}"
    echo -e "  ${BOLD}Dock:${NC}       ${CYAN}$dock${NC}"
    echo -e "  ${BOLD}Theme:${NC}      ${CYAN}$theme${NC}"

    # Check running processes
    echo ""
    section "Running Processes"

    if pgrep -f "statusbar-" >/dev/null 2>&1; then
        local pid=$(pgrep -f "statusbar-" | head -1)
        local cmd=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
        echo -e "  ${GREEN}●${NC} Statusbar: $cmd (PID: $pid)"
    else
        echo -e "  ${RED}●${NC} Statusbar: not running"
    fi

    if pgrep -f "crystal-dock" >/dev/null 2>&1; then
        local pid=$(pgrep -f "crystal-dock" | head -1)
        echo -e "  ${GREEN}●${NC} Dock: crystal-dock (PID: $pid)"
    else
        echo -e "  ${DIM}●${NC} Dock: not running"
    fi

    echo ""
}

cmd_build() {
    section "Building Components"

    if [[ ! -d "$COMPONENTS_DIR/build" ]]; then
        info "Creating build directory..."
        mkdir -p "$COMPONENTS_DIR/build"
    fi

    info "Running meson setup..."
    cd "$COMPONENTS_DIR/build"
    meson setup .. 2>&1 | while IFS= read -r line; do
        echo "  $line"
    done

    info "Building..."
    meson compile 2>&1 | while IFS= read -r line; do
        echo "  $line"
    done

    pass "Build complete"
    echo ""
    info "Binaries in: $COMPONENTS_DIR/build/"
    echo ""
}

cmd_install() {
    section "Installing Components"

    local bindir="$HOME/.local/bin"
    mkdir -p "$bindir"

    if [[ ! -d "$COMPONENTS_DIR/build" ]]; then
        fail "Build first: $0 build"
    fi

    # Install statusbars
    for bar in main compact panel; do
        local bin="$COMPONENTS_DIR/build/statusbar-$bar"
        if [[ -f "$bin" ]]; then
            cp "$bin" "$bindir/statusbar-$bar"
            chmod +x "$bindir/statusbar-$bar"
            pass "statusbar-$bar"
        fi
    done

    # Install widgets
    for widget in clock cpu memory network battery volume; do
        local bin="$COMPONENTS_DIR/build/widget-$widget"
        if [[ -f "$bin" ]]; then
            cp "$bin" "$bindir/widget-$widget"
            chmod +x "$bindir/widget-$widget"
            pass "widget-$widget"
        fi
    done

    # Install registry
    mkdir -p "$CONFIG_DIR"
    cp "$REGISTRY" "$CONFIG_DIR/registry.json"
    pass "registry.json"

    echo ""
    pass "Installation complete"
    echo ""
    info "Components installed to: $bindir/"
    echo ""
}

cmd_start() {
    local target="${1:-}"

    if [[ -z "$target" ]]; then
        # Start current statusbar from config
        target=$(get_current "statusbar")
    fi

    section "Starting Statusbar: $target"

    # Kill existing statusbar
    pkill -f "statusbar-" 2>/dev/null || true
    pkill -f "sfwbar" 2>/dev/null || true
    pkill -f "zebar" 2>/dev/null || true
    sleep 0.5

    case "$target" in
        main|compact|panel)
            local bin="$HOME/.local/bin/statusbar-$target"
            if [[ -x "$bin" ]]; then
                "$bin" &
                pass "Started statusbar-$target"
            else
                bin="$COMPONENTS_DIR/build/statusbar-$target"
                if [[ -x "$bin" ]]; then
                    "$bin" &
                    pass "Started statusbar-$target (from build)"
                else
                    fail "statusbar-$target not found. Build and install first."
                fi
            fi
            ;;
        sfwbar)
            if command -v sfwbar >/dev/null 2>&1; then
                sfwbar &
                pass "Started sfwbar"
            else
                fail "sfwbar not installed. Build and install first."
            fi
            ;;
        zebar)
            if command -v zebar >/dev/null 2>&1; then
                zebar startup &
                pass "Started zebar"
            else
                fail "zebar not installed."
            fi
            ;;
        *)
            fail "Unknown statusbar: $target"
            ;;
    esac
}

cmd_stop() {
    section "Stopping Statusbar"

    if pgrep -f "statusbar-" >/dev/null 2>&1; then
        pkill -f "statusbar-"
        pass "Statusbar stopped"
    else
        info "No statusbar running"
    fi
}

cmd_restart() {
    cmd_stop
    sleep 0.5
    cmd_start
}

cmd_help() {
    echo ""
    echo -e "${BOLD}== Widget Manager (C-based Wayland) ==${NC}"
    echo ""
    echo "Usage: $0 <command> [args]"
    echo ""
    echo "Commands:"
    echo "  list [statusbar|widget|dock]   List available components"
    echo "  status                         Show current configuration"
    echo "  swap statusbar <name>          Switch statusbar (main|compact|panel)"
    echo "  swap dock <name>               Switch dock (crystal|none)"
    echo "  build                          Build C components with meson"
    echo "  install                        Install binaries to ~/.local/bin/"
    echo "  start [name]                   Start statusbar"
    echo "  stop                           Stop running statusbar"
    echo "  restart                        Restart statusbar"
    echo "  help                           Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 list                        # Show all components"
    echo "  $0 swap statusbar compact      # Switch to compact bar"
    echo "  $0 swap dock none              # Disable dock"
    echo "  $0 build && $0 install         # Build and install"
    echo "  $0 start                       # Start current statusbar"
    echo ""
    echo "Statusbars:"
    echo "  main        C-based full-featured bar with all widgets"
    echo "  compact     C-based space-optimized single-line bar"
    echo "  panel       C-based grid dashboard with detailed metrics"
    echo "  sfwbar      SFWBar (GTK3, C-based, wayland-native)"
    echo "  zebar       Zebar (HTML/CSS/JS widgets, legacy fallback)"
    echo ""
    echo "Widgets (standalone):"
    echo "  clock       Real-time clock with date"
    echo "  cpu         CPU usage monitor"
    echo "  memory      Memory usage monitor"
    echo "  network     Network connectivity status"
    echo "  battery     Battery level and charging"
    echo "  volume      Audio volume control"
    echo ""
    echo "Docks:"
    echo "  crystal     Crystal Wayland dock"
    echo "  none        No dock"
    echo ""
}

# ---- Dispatch ----
case "$ACTION" in
    list|ls)       cmd_list "$@" ;;
    status|st)     cmd_status ;;
    swap|sw)       cmd_swap "$@" ;;
    build|b)       cmd_build ;;
    install|i)     cmd_install ;;
    start|s)       cmd_start "$@" ;;
    stop)          cmd_stop ;;
    restart)       cmd_restart ;;
    help|--help|-h|*)  cmd_help ;;
esac
