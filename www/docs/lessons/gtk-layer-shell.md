# Lesson: GTK Layer Shell for Wayland Surfaces

## The Problem

Creating Wayland layer-shell surfaces (panels, overlays, backgrounds) requires understanding the `gtk-layer-shell` library and its anchoring/layer system.

## Layer Types

```c
gtk_layer_set_layer(GTK_WINDOW(window), GTK_LAYER_SHELL_LAYER_BACKGROUND);
```

| Layer | Z-Order | Use Case | Exclusive Zone |
|---|---|---|---|
| `BACKGROUND` | Lowest | Wallpapers, live backgrounds | `-1` (never) |
| `BOTTOM` | Above background | Docks, bottom panels | `0` or `auto` |
| `TOP` | Above bottom | Top panels, status bars | `0` or `auto` |
| `OVERLAY` | Highest | Notifications, popups | `0` (never) |

## Anchoring

Anchors define which screen edges the surface sticks to:

```c
// Fill entire screen (for backgrounds)
gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_LEFT, TRUE);
gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_RIGHT, TRUE);
gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_TOP, TRUE);
gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_BOTTOM, TRUE);

// Top-right corner (for notifications)
gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_TOP, TRUE);
gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_RIGHT, TRUE);
```

## Exclusive Zone

Controls whether the surface pushes other surfaces aside:

```c
gtk_layer_set_exclusive_zone(window, -1);   // Never pushes anything (backgrounds)
gtk_layer_set_exclusive_zone(window, 0);    // Overlaps but doesn't push
gtk_layer_set_exclusive_zone(window, 34);   // Reserves 34px (panel height)
gtk_layer_set_exclusive_zone(window, -1);   // Auto-calculate from size
```

## Example: Notification OSD (`ocws-osd-notify.c`)

```c
gtk_layer_init_for_window(GTK_WINDOW(window));
gtk_layer_set_layer(GTK_WINDOW(window), GTK_LAYER_SHELL_LAYER_OVERLAY);
gtk_layer_set_anchor(GTK_WINDOW(window), GTK_LAYER_SHELL_EDGE_TOP, TRUE);
gtk_layer_set_anchor(GTK_WINDOW(window), GTK_LAYER_SHELL_EDGE_RIGHT, TRUE);
gtk_layer_set_margin(GTK_WINDOW(window), GTK_LAYER_SHELL_EDGE_TOP, 20);
gtk_layer_set_margin(GTK_WINDOW(window), GTK_LAYER_SHELL_EDGE_RIGHT, 20);
```

This creates a notification that floats in the top-right corner, above all other windows, with 20px margin from edges.

## Example: Live Background (`ocws-live-bg.c`)

```c
gtk_layer_init_for_window(GTK_WINDOW(window));
gtk_layer_set_layer(GTK_WINDOW(window), GTK_LAYER_SHELL_LAYER_BACKGROUND);
gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_LEFT, TRUE);
gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_RIGHT, TRUE);
gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_TOP, TRUE);
gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_BOTTOM, TRUE);
gtk_layer_set_exclusive_zone(GTK_WINDOW(window), -1);
```

This creates a full-screen background that never pushes other surfaces.

## zigshell-cairo-pango's Equivalent

zigshell-cairo-pango handles layer-shell internally via config:

```ini
bar "topbar:top" {
  edge = "top"
  layer = "top"
  exclusive_zone = "auto"
}
```

The C code is equivalent to what zigshell-cairo-pango does internally — it's useful when you need custom layer-shell surfaces that zigshell-cairo-pango can't provide (like the live background or OSD notifications).
