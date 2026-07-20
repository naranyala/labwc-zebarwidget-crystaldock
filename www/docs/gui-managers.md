# Graphical Interface Managers

The Open Compositor Widget Shell (OCWS) incorporates a suite of native C/GTK3 desktop applications, compiled utilizing the Zig build system. These administrative utilities provide streamlined management of the OCWS ecosystem, eliminating the necessity for direct manipulation of configuration files.

All graphical applications adhere to a unified architectural standard: they feature a header bar with an integrated stack switcher, utilize layer-shell anchoring via the `ocws_background_app_init` protocol, and maintain a system tray icon to ensure background persistence. Furthermore, they uniformly apply the OCWS adaptive color palette and glassmorphic CSS styling.

## Settings Panel (`ocws-settings`)

The `ocws-settings` application serves as the primary configuration nexus for the OCWS environment. It provides an extensive 11-tab control interface that encompasses shell modes, aesthetic appearance, status bar configuration, widget management, workspace parameters, notification behavior, system diagnostics, quick action settings, keybinding configurations, acknowledgments, and application information.

- Comprehensive theme selection, featuring live preview capabilities and palette visualization.
- Interactive adjustments for window corner radius and margin parameters, integrated with live `labwc` reloading.
- Configuration options for font scaling, icon sets, and cursor themes.
- Seamless transition mechanisms between all supported shell modes.
- Selection of predefined keybinding profiles (Default, Custom, Vim, Emacs).
- Integrated system health diagnostics and dependency verification tools.

## Theme Center (`ocws-theme-center`)

The `ocws-theme-center` provides a specialized interface for theme management. It supports live INI file previews, palette visualization, and immediate application of aesthetic profiles. The utility facilitates the browsing, modification, importation, and exportation of OCWS themes.

## Font Manager (`ocws-fonts-mgr`)

The `ocws-fonts-mgr` delivers a structured 5-tab interface dedicated to typography management. Its capabilities include a system font scanner, an online font installation module, an inventory of managed fonts, detailed font configuration options, and a comprehensive output log. All managed fonts are deployed directly to the `~/.local/share/fonts/` directory with associated metadata tracking.

## Dock Manager (`ocws-dock-mgr`)

The `ocws-dock-mgr` application facilitates the management of pinned applications across diverse shell backends, including DankMaterialShell, Noctalia, Zigshell-cairo-pango, and the standard OCWS dock. It incorporates hot-reloading technology, ensuring that configuration saves instantly propagate to the active shell environment. Additionally, it automates the discovery of application icons and categories from existing `.desktop` files.

## Desktop Entry Manager (`ocws-dotdesktop-mgr`)

The `ocws-dotdesktop-mgr` is a comprehensive `.desktop` file editor. It offers advanced search and browsing capabilities, an icon selection interface, category assignment tools, bulk state modification (enable/disable), backup and restoration protocols, and detailed file information displays. This utility is particularly effective for integrating portable AppImages or custom executable scripts into the system application launcher.

## Package Manager (`ocws-pkgmgr`)

The `ocws-pkgmgr` functions as the primary frontend for system dependency resolution, source compilation processes, health diagnostics, and engine updates. It ensures the operational integrity of the entire OCWS component stack, encompassing `labwc`, `zigshell-cairo-pango`, and the core OCWS infrastructure.

## Welcome Wizard (`ocws-welcome`)

The `ocws-welcome` application provides a structured, 10-phase initialization protocol for new deployments. The setup sequence includes an introduction, system health validation, display monitor configuration, filesystem mounting parameters, shell mode selection, theme application, quick configuration options, an overview of available GUI tools, acknowledgments, and finalization procedures. This wizard ensures a standardized and comprehensive initial configuration process.

## Workspace Manager (`ocws-workspace-mgr`)

The `ocws-workspace-mgr` offers a robust, Kanban-style interface for workspace administration, implemented via the `wlr-foreign-toplevel-management` protocol. It provides a detailed inventory of active Wayland windows, equipped with precise controls for focus delegation, termination, minimization, and inter-workspace relocation.

## Large Language Model Interface (`ocws-llm-runner`)

The `ocws-llm-runner` is a specialized application designed for local Large Language Model (LLM) interaction, featuring integrated Optical Character Recognition (OCR) capabilities. It provisions a Python backend server, manages GGUF formatted models utilizing `llama.cpp`, and presents a sophisticated GTK3 glassmorphic interface that ensures session persistence across invocations.
