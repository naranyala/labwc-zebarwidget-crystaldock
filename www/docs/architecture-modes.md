# Shell Architecture & Modes

OCWS relies entirely on a heavily customized instance of `zigshell-cairo-pango` to draw its top panel, bottom dock, system trays, and control center popups.

## The `modes/` Architecture

Instead of one monolithic configuration file, the shell is broken down into highly modular, composable files located inside `~/.config/ocws/`. 

The most important structural change is the introduction of **Modes**.

- `dotfiles/ocws/modes/statusbar.config`: The main top panel definition.
- `dotfiles/ocws/modes/dock.config`: The bottom glassmorphic app dock.
- `dotfiles/ocws/modes/full.config`: A wrapper that simply includes both the `statusbar` and `dock`.

When you use the `ocws-settings` GUI to switch between Single-Bar and Double-Panel layouts, the background daemon is simply swapping which `modes/` file gets loaded by `zigshell-cairo-pango`.

## Widget Sets (`widget-sets/`)

To prevent code duplication (especially between different layouts), individual groups of widgets are broken out into independent files inside `dotfiles/ocws/widget-sets/`.

For example:
- `status.set`: Contains the battery indicator, WiFi, and bluetooth modules.
- `media.set`: Contains the currently playing song information and controls.
- `system-metrics.set`: Contains CPU, RAM, and Temperature monitors.

These sets are then `include`d directly into the mode files. This means if you edit the battery widget in `status.set`, the change instantly applies to all layouts/modes across the desktop.

## CSS Theming

All widget styling is separated from the layout logic. The shell draws its colors dynamically from `tokens.css`.
- When you use the theme engine to switch to a new palette, the engine rewrites `tokens.css`.
- Because `zigshell-cairo-pango` is configured to `include("tokens.css")`, the entire desktop instantly hot-reloads its colors, border-radii, and glassmorphic blur properties without needing a restart.
