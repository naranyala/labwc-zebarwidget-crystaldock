# Lesson: zigshell-cairo-pango Icon Resolution Depends On GTK Icon Theme

## The Problem

Image widgets that use named symbolic icons (not file paths) fail silently — the icon slot stays empty or shows the `missing.svg` fallback:

```
Expected: [search] [disk] [volume]   (edit-paste-symbolic, drive-harddisk-symbolic, audio-volume-high-symbolic)
Actual:   [X]  [X]  [X]   (missing.svg fallback icon)
```

zigshell-cairo-pango reports nothing. The icon just never loads.

## Root Cause

zigshell-cairo-pango's icon resolution chain in `src/gui/scaleimage.c` and `src/appinfo.c` works like this:

```
scale_image_set_image("edit-paste-symbolic", NULL)
  → scale_image_set(self)
    → app_info_icon_lookup("edit-paste-symbolic", symbolic_pref)
      → gtk_icon_theme_lookup_icon(icon_theme, "edit-paste-symbolic", 16, 0)
      →   if NULL: app_info_icon_get(app_id)    # reads .desktop file Icon= field
      →   if NULL: g_desktop_app_info_search()   # search for desktop files
      →   if NULL: check WM_CLASS map
      →   if NULL: retry with lowercase
      →   if STILL NULL: return NULL
    → if NULL: file-system lookup via get_xdg_config_file()
      → tries exts: "", ".svg", ".png", ".xpm" with/without "-symbolic"
    → if STILL NULL: fallback to icons/misc/missing.svg
```

The first step — `gtk_icon_theme_lookup_icon()` — uses the **default GTK icon theme**. If no icon theme is configured (e.g., `gtk3-settings.ini` is missing or `gtk-icon-theme-name` is empty), GTK uses its built-in fallback (`hicolor` or `Adwaita`), which may lack the themed symbolic icons the widgets request.

The template setting:

```ini
# gtk3-settings.ini.tmpl
gtk-icon-theme-name={{ICON_THEME}}
```

Defaults to empty if the theme INI file doesn't set `[icons] theme = Papirus-Dark` (or similar). An empty icon theme name means GTK picks its own default — which often lacks `-symbolic` variants.

## The Fix

1. **Set the icon theme in GTK settings** — either via the theme engine or manually:

```ini
# ~/.config/gtk-3.0/settings.ini
[Settings]
gtk-icon-theme-name=Papirus-Dark
```

```ini
# ~/.config/gtk-4.0/settings.ini
[Settings]
gtk-icon-theme-name=Papirus-Dark
```

2. **Verify the theme INI profiles have an `[icons]` section**:

```ini
# themes/catppuccin-mocha.ini
[icons]
theme=Papirus-Dark
```

3. **Ensure fallback icons exist on disk** for file-based lookups:

```
~/.config/ocws/icons/misc/missing.svg
~/.config/ocws/icons/weather/clear.svg
```

These are resolved via `get_xdg_config_file()` using the `ImagePath` scanner variable.

## Where This Applies

Widgets that reference symbolic icon names in their `image { value = ... }` blocks:

| Widget File | Icon Name |
|-------------|-----------|
| `clipboard.widget` | `edit-paste-symbolic` |
| `cpu-monitor.widget` | `utilities-system-monitor-symbolic` |
| `disk.widget` | `drive-harddisk-symbolic` |
| `keyboard-layout.widget` | `input-keyboard-symbolic` |
| `media-player.widget` | `media-skip-backward-symbolic`, `media-playback-pause-symbolic`, etc. |
| `media.widget` | `media-playback-pause-symbolic`, `media-skip-backward-symbolic`, etc. |

## Pattern To Remember

A named icon in zigshell-cairo-pango (`"edit-paste-symbolic"`) goes through these steps before falling back to `missing.svg`:

1. GTK icon theme lookup → must have an `[icons] theme` set
2. `.desktop` file `Icon=` field → app must be installed
3. File-system search via `ImagePath` → files must exist on disk

An icon that works on your machine (where you happen to have Papirus installed) will fail silently on a machine with Adwaita or hicolor alone. Always verify with at least one icon theme that only has `Adwaita` to catch missing-icons-at-deployment.
