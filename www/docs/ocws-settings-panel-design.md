# OCWS Settings Panel Design

## Philosophy

Inspired by DankMaterialShell and Noctalia, adapted for OCWS's C and zigshell-cairo-pango architecture. Uses GTK3 native widgets with OCWS CSS styling for glassmorphic appearance.

## Architecture

```
ocws-settings (GTK3 app)
  Sidebar navigation (icon + label)
  Content stack (scrollable cards)
  Header bar (title + actions)
```

## Tabs

### 1. Appearance (Theme Engine)

| Feature | Widget | Description |
|---------|--------|-------------|
| Active Theme | Card + Grid | Current theme name, color dots for quick switch |
| Theme Category | Button Group | Generic / Auto (matugen) / Custom / Browse |
| Color Palette | Color Grid | 10 theme colors with live preview |
| Matugen Scheme | Dropdown | Tonal Spot, Vibrant, Content, etc. |
| Wallpaper Preview | Image Card | Current wallpaper with color extraction |
| Custom Theme | File Picker | Load custom JSON theme file |
| Icon Theme | Dropdown | Papirus-Dark, Papirus-Light, etc. |
| Cursor Theme | Dropdown | Catppuccin-Mocha-Dark, etc. |
| Cursor Size | Slider | 16-48px |
| Font Scaling | Slider | 50-200% for UI elements |

### 2. Bar Configuration

| Feature | Widget | Description |
|---------|--------|-------------|
| Bar List | Card List | Up to 4 bars with position/size info |
| Add/Delete Bar | Buttons | Create new bar configs |
| Position | Button Group | Top / Bottom / Left / Right |
| Display Assignment | Toggle List | Which monitors show this bar |
| Size | Slider | Bar thickness (24-64px) |
| Spacing | Slider | Edge spacing (0-32px) |
| Transparency | Slider | Bar opacity (0-100%) |
| Corner Radius | Slider | Round corners (0-24px) |
| Auto-hide | Toggle + Delay | Hide when not hovering |
| Scroll Behavior | Dropdown | Workspace switching / Column scroll |

### 3. Widgets

| Feature | Widget | Description |
|---------|--------|-------------|
| Widget List | Toggle List | All available widgets with enable/disable |
| Widget Presets | Button Group | Standard / Full / Minimal / Custom |
| Per-widget Settings | Expandable | Individual widget configuration |
| Widget Search | Search Bar | Filter widgets by name |

### 4. Workspaces

| Feature | Widget | Description |
|---------|--------|-------------|
| Workspace Count | Slider | Number of workspaces (1-12) |
| Naming | Toggle | Show workspace names vs numbers |
| App Icons | Toggle | Show running app icons in workspace |
| Scroll Switching | Toggle | Switch workspace with scroll |
| Follow Focus | Toggle | Bar shows focused workspace |

### 5. Keybinds

| Feature | Widget | Description |
|---------|--------|-------------|
| Preset Selector | Dropdown | Default / Custom / Vim / Emacs |
| Keybind List | List View | All keybinds with search |
| Edit Keybind | Dialog | Modify key combination |
| Export/Import | Buttons | Save/load keybind configs |

### 6. Notifications

| Feature | Widget | Description |
|---------|--------|-------------|
| Daemon | Dropdown | Mako / Dunst / Disable |
| Position | Dropdown | Top-right, Top-center, etc. |
| Timeout | Slider | 1-30 seconds |
| Max Visible | Slider | 1-10 notifications |

### 7. System

| Feature | Widget | Description |
|---------|--------|-------------|
| Health Check | Button + Results | Run ocws-health, show results |
| Validate Config | Button + Results | Run ocws-validate |
| System Info | Card | OS, kernel, compositor, shell version |
| Memory Usage | Progress Bar | Current memory usage |
| CPU Load | Progress Bar | Current CPU load |

### 8. About

| Feature | Widget | Description |
|---------|--------|-------------|
| OCWS Version | Info | Current version |
| Build Info | Info | C compiler, flags, date |
| Contributors | List | Project contributors |
| License | Info | MIT License |

## CSS Styling

### Glassmorphic Card

```css
.settings-card {
  background-color: rgba(30, 30, 46, 0.85);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 16px;
  padding: 16px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
}
```

### Toggle Switch

```css
switch {
  background-color: rgba(69, 71, 90, 0.8);
  border-radius: 12px;
  min-width: 48px;
  min-height: 24px;
}
switch:checked {
  background-color: #89b4fa;
}
```

### Slider

```css
scale trough {
  background-color: rgba(69, 71, 90, 0.6);
  border-radius: 4px;
  min-height: 6px;
}
scale slider {
  background-color: #cdd6f4;
  border-radius: 50%;
  min-width: 18px;
  min-height: 18px;
}
```

## Implementation Notes

### Settings Storage

Settings are stored using the `ocws-kv` binary:

```c
char *value = ocws_kv_get("bar.transparency");
ocws_kv_set("bar.transparency", "0.85");
```

### Live Preview

- Theme changes apply immediately via `theme-engine.sh apply`
- Bar changes use `zigshell-cairo-pango-cmd` or IPC for live updates
- Widget changes toggle visibility via CSS class

### Dependencies

- GTK3 (already required)
- json-c or cJSON (for JSON parsing)
- ocws-kv (existing binary)

## Comparison with DMS and Noctalia

| Feature | DMS | Noctalia | OCWS |
|---------|-----|----------|------|
| Theme Engine | Matugen + JSON | TOML palettes | INI themes |
| Bar Config | 4 bars, drag reorder | Single bar | Up to 4 bars |
| Widget System | QML plugins | C++ widgets | .widget files |
| Live Preview | Instant | Instant | Instant |
| Multi-monitor | Full | Basic | Full |
| Memory Usage | ~80MB | ~50MB | ~15MB |
