# Shell Architecture and Modes

OCWS uses a heavily customized instance of `zigshell-cairo-pango` to render its top panel, bottom dock, system trays, and control center popups.

## The `modes/` Architecture

Instead of a monolithic configuration file, the shell is broken into modular, composable files inside `~/.config/ocws/`.

Key structural files:

- `modes/statusbar.config` -- The main top panel definition.
- `modes/dock.config` -- The bottom glassmorphic app dock.
- `modes/full.config` -- A wrapper that includes both statusbar and dock.

When you switch between Single-Bar and Double-Panel layouts in `ocws-settings`, the background daemon swaps which `modes/` file gets loaded by `zigshell-cairo-pango`.

## Widget Sets (`widget-sets/`)

To prevent code duplication across layouts, individual widget groups are extracted into independent files inside `dotfiles/ocws/widget-sets/`:

- `status.set` -- Battery indicator, WiFi, and bluetooth modules.
- `media.set` -- Currently playing song information and controls.
- `system-metrics.set` -- CPU, RAM, and temperature monitors.

These sets are included into mode files. Editing a widget in `status.set` applies the change to all layouts across the desktop.

## CSS Theming

Widget styling is separated from layout logic. The shell reads its colors dynamically from `tokens.css`.

- The theme engine rewrites `tokens.css` when switching palettes.
- `zigshell-cairo-pango` includes `tokens.css`, so the entire desktop hot-reloads colors, border-radii, and glassmorphic blur properties without a restart.

## Mode Files

| Mode | Description |
|------|-------------|
| `doublepanel.mode` | Dual-panel: top status bar plus bottom dock/taskbar |
| `zigshell-cairo-pango.mode` | Single status bar with external zigshell-cairo-pango |
| `minimal.mode` | Minimal bar: clock, volume, battery, tray only |

## Config Modules

| Module | Purpose |
|--------|---------|
| `modes/base.config` | Common settings (ImagePath, ThicknessHint, plugin autoloader) |
| `modes/topbar.config` | Top status bar definition |
| `modes/bottombar.config` | Bottom bar with dock and taskbar |
| `modes/statusbar.config` | Single status bar (zigshell-cairo-pango mode) |
| `modes/desktop.config` | Desktop layer for floating widgets |

## CSS Modules

| Module | Purpose |
|--------|---------|
| `modes/css-glassmorphism.config` | Glassmorphism tokens and base styles |
| `modes/css-bars.config` | Bar-specific panel styles |
| `modes/css-widgets.config` | Widget button and pill styles |
| `modes/css-taskbar.config` | Taskbar item styles |
| `modes/css-dock.config` | Dock icon grid styles |
| `modes/css-popups.config` | Popup and menu styles |
