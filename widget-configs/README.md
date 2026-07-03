# widget-configs/ - Configuration schemas for all swap-able widgets

# Use these patterns to create new widgets:
# widget-configs/clock.json - "Clock" - Time display widget
# widget-configs/workspaces.json - "Workspaces" - Workspace switcher
# widget-configs/system.json - "System" - CPU/memory/network/battery/volume

# Template for creating new widget configurations:

# Widget configuration template for JSON-based config
widget.<name> = {
    name: "Widget Name",
    description: "Short description",
    type: ["standard", "provider", "custom"],
    default_width: 120,
    default_height: 32,
    mandatory: true,
    position: "left|center|right|top|bottom",
    properties: {
        refresh_interval: "1000ms",
        update_on_focus: true,
        auto_center: true
    }
};

# Individual widget configurations
widget.clock = {
    name: "Clock Widget",
    description: "Real-time clock with optional date and 12/24 hour format",
    type: "standard",
    default_width: 120,
    default_height: 32,
    mandatory: false,
    position: "center",
    properties: {
        format: "24h",
        show_seconds: false,
        show_date: true,
        timezone: "UTC",
        update_frequency: "1000ms"
    }
};

widget.workspaces = {
    name: "Workspace Switcher",
    description: "Navigate between workspaces with visual indicators",
    type: "standard",
    default_width: 280,
    default_height: 32,
    mandatory: false,
    position: "left",
    properties: {
        count: 9,
        show_active: true,
        click_action: "switch",
        hover_preview: true,
        animation: "fade"
    }
};

widget.cpu = {
    name: "CPU Monitor",
    description: "CPU usage, temperature, and core information",
    type: "provider",
    default_width: 80,
    default_height: 32,
    mandatory: false,
    position: "right",
    properties: {
        show_icon: true,
        show_temperature: true,
        show_cores: true,
        temperature_unit: "celsius",
        update_frequency: "1000ms"
    }
};

widget.memory = {
    name: "Memory Monitor",
    description: "RAM and swap usage with detailed statistics",
    type: "provider",
    default_width: 80,
    default_height: 32,
    mandatory: false,
    position: "right",
    properties: {
        show_swap: true,
        show_details: true,
        graph_style: "bar",
        show_percentage: true,
        update_frequency: "1000ms"
    }
};

widget.network = {
    name: "Network Status",
    description: "WiFi/Ethernet connectivity and signal strength",
    type: "provider",
    default_width: 120,
    default_height: 32,
    mandatory: false,
    position: "right",
    properties: {
        show_icon: true,
        show_signal: true,
        show_type: true,
        show_ssid: true,
        auto_connect: false
    }
};

widget.battery = {
    name: "Battery Monitor",
    description: "Battery level, charging status, and estimated time",
    type: "provider",
    default_width: 80,
    default_height: 32,
    mandatory: false,
    position: "left",
    properties: {
        show_percent: true,
        show_time: true,
        show_charging: true,
        show_icon: true,
        alert_threshold: 20
    }
};

widget.volume = {
    name: "Volume Control",
    description: "Audio volume level with mute state indication",
    type: "provider",
    default_width: 80,
    default_height: 32,
    mandatory: false,
    position: "left",
    properties: {
        show_level: true,
        show_muted: true,
        show_sink: true,
        show_icon: true,
        control_method: "media_keys"
    }
};

widget.tray = {
    name: "Application Tray",
    description: "System tray with application icons and notifications",
    type: "standard",
    default_width: 320,
    default_height: 32,
    mandatory: false,
    position: "right",
    properties: {
        max_icons: 10,
        show_labels: false,
        notification_popup: true,
        auto_hide: false
    }
};

widget.weather = {
    name: "Weather Widget",
    description: "Current weather conditions and forecast",
    type: "provider",
    default_width: 100,
    default_height: 32,
    mandatory: false,
    position: "left",
    properties: {
        location: "auto",
        temperature_unit: "celsius",
        show_icon: true,
        show_forecast: false,
        api_provider: "openweathermap"
    }
};

widget.quicksettings = {
    name: "Quick Settings",
    description: "One-click access to system settings and actions",
    type: "standard",
    default_width: 200,
    default_height: 32,
    mandatory: false,
    position: "center",
    properties: {
        buttons: ["brightness", "wifi", "bluetooth", "audio", "night_mode"],
        collapse_on_click: true,
        show_tooltips: true
    }
};
