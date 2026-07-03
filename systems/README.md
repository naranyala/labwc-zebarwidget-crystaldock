// systems/ - Generic systems for interoperability

// Use this directory for cross-cutting concerns:
// systems/config - Configuration loading/saving
// systems/theme - Theme management
// systems/lifecycle - Common lifecycle management
// systems/navigation - Workspace navigation
// systems/metrics - System metrics collection

// Template for adding a new system:

// Example: systems/config.c - Centralized configuration management
system.config = {
    filename: "~/.config/labwc/statusbar-configs",
    fallback: "statusbar-configs/main.conf",
    schema: {
        bar: {
            name: "string",
            height: "int",
            position: ["top", "bottom"],
            widgets: ["array"],
            theme: "string"
        }
    }
};

// Example: systems/theme.c - Cross-component theming
system.theme = {
    engine: "gtk",
    profiles: [
        "catppuccin-mocha",
        "nord", 
        "tokyo-night",
        "breeze-dark"
    ],
    apply_to: [
        "bar", "dock", "widgets", "navigation"
    ]
};
