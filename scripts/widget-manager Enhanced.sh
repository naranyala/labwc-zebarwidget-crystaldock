#!/bin/bash
#
# widget-manager.sh — Enhanced widget and statusbar manager
#
# Swap, list, status, and configure components.
# Now supports swap-able statusbars and widgets with centralized configuration.

# Set local path for widget registry
setup_widget_registry() {
    local registry_file="${COMPONENTS_DIR}/widget-registry.json"
    local statusbar_registry_file="${COMPONENTS_DIR}/statusbar-registry.json"

    # Create widget registry
    cat > "$registry_file" << 'EOF'
{
    "widgets": {
        "clock": {
            "binary": "widget-clock",
            "description": "Clock widget for time display",
            "component": "widgets/clock/clock.c"
        },
        "cpu": {
            "binary": "widget-cpu", 
            "description": "CPU usage monitor",
            "component": "widgets/cpu/cpu.c"
        },
        "memory": {
            "binary": "widget-memory",
            "description": "Memory usage monitor",
            "component": "widgets/memory/memory.c"
        },
        "network": {
            "binary": "widget-network",
            "description": "Network connectivity status",
            "component": "widgets/network/network.c"
        },
        "battery": {
            "binary": "widget-battery",
            "description": "Battery level and charging status", 
            "component": "widgets/battery/battery.c"
        },
        "volume": {
            "binary": "widget-volume",
            "description": "Audio volume control",
            "component": "zebar/widgets/volume/volume.c"
        },
        "workspaces": {
            "binary": "widget-workspaces",
            "description": "Workspace switcher",
            "component": "widgets/workspaces/workspaces.c"
        }
    },
    "statusbars": {
        "main": {
            "binary": "statusbar-main",
            "description": "Full-featured statusbar with all widgets",
            "component": "statusbars/main/main.c"
        },
        "compact": {
            "binary": "statusbar-compact", 
            "description": "Compact statusbar with essential widgets",
            "component": "statusbars/compact/compact.c"
        },
        "panel": {
            "binary": "statusbar-panel",
            "description": "Dashboard panel with detailed metrics",
            "component": "statusbars/panel/panel.c"
        },
        "detailed": {
            "binary": "bar-detailed",
            "description": "Detailed statusbar with grid layout",
            "component": "statusbars/detailed/detailed.c"
        },
        "minimalist": {
            "binary": "bar-minimalist",
            "description": "Minimalist bar with only clock",
            "component": "statusbars/minimalist/minimalist.c"
        }
    },
    "systems": {
        "config": {
            "binary": "system-config",
            "description": "Centralized configuration management",
            "component": "systems/config.c"
        }
    }
}
EOF

    # Create statusbar registry
    cat > "$statusbar_registry_file" << 'EOF'
{
    "statusbars": {
        "main": {
            "name": "Main Statusbar",
            "config": "statusbar-configs/main.conf",
            "widgets": ["workspaces", "clock", "cpu", "memory", "network", "battery", "volume"],
            "height": 32,
            "position": "top"
        },
        "compact": {
            "name": "Compact Statusbar",
            "config": "statusbar-configs/compact.conf", 
            "widgets": ["clock", "cpu", "memory", "network"],
            "height": 24,
            "position": "top"
        },
        "detailed": {
            "name": "Detailed Statusbar",
            "config": "statusbar-configs/detailed.conf",
            "widgets": ["workspaces", "clock", "cpu", "memory", "network", "battery", "volume"],
            "height": 40,
            "position": "top"
        },
        "minimalist": {
            "name": "Minimalist Statusbar",
            "config": "statusbar-configs/minimalist.conf",
            "widgets": ["clock"],
            "height": 20,
            "position": "top"
        },
        "panel": {
            "name": "Dashboard Panel",
            "config": "statusbar-configs/panel.conf",
            "widgets": ["cpu", "memory", "network", "battery"],
            "height": 200,
            "position": "bottom"
        }
    }
}
EOF

    # Create initial statusbar-configs directory if it doesn't exist
    mkdir -p "$CONFIG_DIR/statusbar-configs"
    
    # Create default statusbar configs if they don't exist
    mkdir -p ".config/labwc/statusbar-configs"
    if [[ ! -f ".config/labwc/statusbar-configs/main.conf" ]]; then
        cat > ".config/labwc/statusbar-configs/main.conf" << 'EOF'
{
    "name": "Main Statusbar",
    "height": 32,
    "position": "top",
    "exclusive_zone": 32,
    
    "widgets": [
        "workspaces",
        "clock",
        "cpu",
        "memory",
        "network",
        "battery",
        "volume"
    ],
    
    "widget_config": {
        "workspaces": {"count": 9, "position": "left"},
        "clock": {"format": "24h", "show_seconds": false, "position": "center"},
        "system": {"refresh_interval": 1000, "show_details": true}
    },
    
    "theme": "catppuccin-mocha"
}
EOF
    fi
    if [[ ! -f ".config/labwc/statusbar-configs/compact.conf" ]]; then
        cat > ".config/labwc/statusbar-configs/compact.conf" << 'EOF'
{
    "name": "Compact Statusbar",
    "height": 24,
    "position": "top",
    "exclusive_zone": 24,
    
    "widgets": [
        "clock",
        "cpu",
        "memory",
        "network"
    ],
    
    "widget_config": {
        "clock": {"format": "12h", "show_seconds": false, "position": "left"},
        "cpu": {"show_icon": true, "show_temp": false, "position": "right"},
        "memory": {"show_swap": false, "position": "right"},
        "network": {"show_icon": true, "show_signal": true, "position": "right"}
    },
    
    "theme": "catppuccin-mocha"
}
EOF
    fi
    if [[ ! -f ".config/labwc/statusbar-configs/detailed.conf" ]]; then
        cat > ".config/labwc/statusbar-configs/detailed.conf" << 'EOF'
{
    "name": "Detailed Statusbar",
    "height": 40,
    "position": "top",
    "exclusive_zone": 40,
    
    "layout": {"type": "grid", "cols": 3, "rows": 2, "gap": 10},
    
    "widgets": [
        "workspaces",
        "clock",
        "cpu",
        "memory",
        "network",
        "battery",
        "volume"
    ],
    
    "widget_config": {
        "workspaces": {"count": 9, "position": "top-left"},
        "clock": {"format": "24h", "show_seconds": true, "show_date": true, "position": "top-center"},
        "cpu": {"show_icon": true, "show_temp": true, "show_cores": true, "position": "bottom-left"},
        "memory": {"show_swap": true, "show_details": true, "position": "bottom-center"},
        "network": {"show_icon": true, "show_signal": true, "show_type": true, "position": "bottom-right"},
        "battery": {"show_percent": true, "show_time": true, "show_charging": true, "position": "extra-left"},
        "volume": {"show_level": true, "show_muted": true, "show_sink": true, "position": "extra-right"}
    },
    
    "theme": "nord"
}
EOF
    fi
    if [[ ! -f ".config/labwc/statusbar-configs/minimalist.conf" ]]; then
        cat > ".config/labwc/statusbar-configs/minimalist.conf" << 'EOF'
{
    "name": "Minimalist Statusbar",
    "height": 20,
    "position": "top",
    "exclusive_zone": 20,
    
    "widgets": [
        "clock"
    ],
    
    "widget_config": {
        "clock": {"format": "24h", "show_seconds": false, "show_date": false, "position": "center", "transparent": true}
    },
    
    "theme": "tokyo-night",
    
    "style": {"background_alpha": 0.0, "show_border": false, "show_shadow": false}
}
EOF
    fi

    pass "Widget and statusbar registries initialized"
}

# Export function to make it available to subshells
eval "setup_widget_registry() $(declare -f setup_widget_registry)"
