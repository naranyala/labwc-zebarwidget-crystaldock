// statusbar-configs/ - Configuration schemas for all swappable bars

// Use these patterns to create new bars:
// statusbar-configs/main.conf - "Main" - Full featured, all widgets
// statusbar-configs/compact.conf - "Compact" - Essential widgets only
// statusbar-configs/minimalist.conf - "Minimalist" - Only clock
// statusbar-configs/detailed.conf - "Detailed" - All widgets + workspaces

// Template for creating new bar configurations:

bar.main = {
    name: "Main Statusbar",
    height: 32,
    position: "top",
    exclusive_zone: 32,
    
    widgets = [
        "workspaces",     // Can add/remove/reorder
        "clock",
        "cpu",
        "memory",
        "network",
        "battery",
        "volume"
    ],
    
    theme = "catppuccin-mocha",
    
    // Widget-specific configs
    workspaces = {
        count: 9,
        position: "left"
    },
    clock = {
        format: "24h",
        show_seconds: true,
        position: "center"
    },
    system_metrics = {
        refresh_interval: 1000ms,
        show_details: true
    }
};

bar.compact = {
    name: "Compact Bar",
    height: 24,
    position: "top",
    exclusive_zone: 24,
    
    widgets = [
        "clock",
        "cpu",
        "memory",
        "network"
    ],
    
    theme = "catppuccin-mocha"
};

bar.detailed = {
    name: "Detailed Dashboard",
    height: 40,
    position: "top",
    exclusive_zone: 40,
    
    widgets = [
        "workspaces",
        "clock",
        "cpu",
        "memory",
        "network",
        "battery",
        "volume"
    ],
    
    layout = {
        cols: 3,
        rows: 2,
        gap: 10
    },
    
    theme = "nord"
};

bar.minimalist = {
    name: "Minimal Bar",
    height: 20,
    position: "top",
    exclusive_zone: 20,
    
    widgets = [
        "clock"
    ],
    
    transparent: true,
    show_border: false
};
