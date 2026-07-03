# labwc-widget-components

C-based Wayland-native widget and statusbar components for labwc.

## Architecture

```
components/
├── registry.json          # Component manifest
├── meson.build            # Build system
├── libwidget/             # Shared C library
│   ├── include/widget.h   # Public API
│   ├── widget.c           # Core implementation
│   ├── providers/         # System data providers
│   ├── wayland/           # wlr-layer-shell integration
│   └── render/            # Cairo/Pango rendering
├── widgets/               # Individual widget implementations
│   ├── clock/
│   ├── cpu/
│   ├── memory/
│   ├── network/
│   ├── battery/
│   └── volume/
├── statusbars/            # Complete statusbar compositions
│   ├── main/              # Full-featured statusbar
│   ├── compact/           # Space-optimized bar
│   └── panel/             # Grid dashboard
├── dock/                  # Dock configurations
└── shared/                # Shared resources (CSS, themes)
```

## Building

```bash
# Install dependencies (Ubuntu/Debian)
sudo apt install wayland-protocols libwayland-dev libwlr-dev \
    libcairo2-dev libpango1.0-dev libfontconfig1-dev libxkbcommon-dev

# Build
cd components
meson setup build
meson compile -C build
```

## Installing

```bash
# Build and install
./scripts/widget-manager.sh build
./scripts/widget-manager.sh install
```

## Usage

```bash
# List available components
widget-manager.sh list

# Show current configuration
widget-manager.sh status

# Swap statusbar
widget-manager.sh swap statusbar compact
widget-manager.sh swap statusbar main
widget-manager.sh swap statusbar panel

# Swap dock
widget-manager.sh swap dock crystal
widget-manager.sh swap dock none

# Start/stop/restart
widget-manager.sh start
widget-manager.sh stop
widget-manager.sh restart
```

## Statusbars

| Name | Description | Widgets |
|------|-------------|---------|
| `main` | Full-featured statusbar | All |
| `compact` | Space-optimized bar | clock, cpu, memory |
| `panel` | Grid dashboard | cpu, memory, network, battery |

## Widgets (standalone)

| Name | Description | Providers |
|------|-------------|-----------|
| `clock` | Real-time clock | date |
| `cpu` | CPU usage monitor | cpu |
| `memory` | Memory usage monitor | memory |
| `network` | Network status | network |
| `battery` | Battery level | battery |
| `volume` | Audio volume | volume |

## Theme Support

Built-in themes:
- Catppuccin Mocha (default)
- Nord
- Dracula
- Tokyo Night

Themes are loaded from:
1. `~/.config/labwc/themerc-override` (labwc theme)
2. `~/.config/labwc-widgets/status.json` (component config)
3. Built-in defaults

## Integration with Existing Setup

The C-based components can coexist with zebar widgets:

```bash
# Use C statusbar
widget-manager.sh swap statusbar main
widget-manager.sh start

# Or use zebar (existing)
pkill -f statusbar-
zebar startup
```

## Dependencies

- wayland-client
- wayland-protocols
- wlr-layer-shell (via pkg-config)
- cairo
- pangocairo
- fontconfig
- xkbcommon

## License

MIT
