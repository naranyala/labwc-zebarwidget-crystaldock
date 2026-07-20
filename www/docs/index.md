# Documentation Overview

The Open Compositor Widget Shell (OCWS) is a high-performance, native Wayland desktop environment engineered primarily with C, GTK3, and `labwc`. This documentation repository provides comprehensive guidance on system installation, advanced configuration, architectural design, and software development practices.

## System Overview

OCWS serves as an efficient alternative to conventional desktop environments such as GNOME or KDE. It achieves this by deploying a curated suite of specialized C binaries and shell scripts. The environment operates on `labwc` (a robust Wayland compositor), utilizes `zigshell-cairo-pango` for rendering panels and widgets, and employs `fuzzel` as its application launcher.

This architecture delivers a fully featured desktop environment that operates efficiently with under 200 MB of RAM, entirely eliminating the overhead associated with JavaScript, Electron, or Qt runtimes.

## Primary Features

- **Native C and GTK3 Implementation**: All graphical utilities are compiled natively. The system strictly avoids reliance on web-based technologies.
- **Modular Design**: Interface panels, widgets, background daemons, and plugins function as distinct, independent units.
- **Centralized Theme Engine**: A singular INI configuration file dictates the aesthetic properties across 14 distinct interface surfaces.
- **Versatile Shell Layouts**: Supports multiple user paradigms, including Dual Panel, Noctalia Floating Island, Zigshell-cairo-pango, and Minimal configurations.
- **Native Configuration Interface**: Provides graphical controls for theme management, appearance parameters, keybinding assignments, and system metric analysis.
- **Security Hardened Architecture**: Integrates AddressSanitizer (ASan) in Continuous Integration (CI) pipelines, enforces shell injection prevention mechanisms, and utilizes secure temporary file handling protocols.

## Initialization

```bash
git clone --depth=1 https://github.com/naranyala/labwc-fuzzel-zigshell-cairo-pango.git
cd labwc-fuzzel-zigshell-cairo-pango
./install.sh
```

Upon successful installation, initialize the `labwc` session via your configured Display Manager, or execute `labwc` directly from a TTY interface.

## System Architecture

| Architecture Layer | Component | Functionality |
|--------------------|-----------|---------------|
| Compositor | labwc | Manages window operations, input processing, and keybinding enforcement. |
| User Interface | zigshell-cairo-pango | Renders interface panels, widgets, the system taskbar, and the notification tray. |
| Application Launcher | fuzzel | Operates as the application launcher and `dmenu`-compatible command runner. |
| Layer Shell | gtk-layer-shell | Secures interface surfaces to the designated Wayland outputs. |

## Documentation Directory

- **Getting Started**: Procedures for installation, initial configuration, and system troubleshooting.
- **Configuration**: Specifications for the Event Bus API, plugin architecture, and CSS-based customization.
- **Event API Specification**: Comprehensive documentation of the IPC event contract and associated variable mappings.
- **Graphical Interface Managers**: Details regarding native GTK3 utility applications.
- **Implementation Insights**: An extensive archive of technical notes detailing `zigshell-cairo-pango` internals, shell design patterns, and security considerations.
- **Strategic Planning**: Records of architectural decisions, unification strategies, and comprehensive dependency analyses.
