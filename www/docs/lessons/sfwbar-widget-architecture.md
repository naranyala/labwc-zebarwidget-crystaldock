# Lesson: zigshell-cairo-pango Widget File Structure

## Anatomy of a Widget File

A `.widget` file typically has three sections:

```ini
#Api2

# 1. SCANNER (optional) — polls commands, reads files
scanner {
  step = 2000
  exec("/bin/sh -c 'wpctl get-volume @DEFAULT_SINK@ 2>/dev/null'") {
    XVolRaw = Grab(First)
    XVolLevel = Val(RegEx("Volume: ([0-9.]+)", XVolRaw)) * 100
  }
}

# 2. WIDGET DEFINITION — exported to the bar
export button "volume-text" {
  interval = 2000
  style = "text_widget"
  tooltip = "Volume: " + Str(XVolLevel, 0) + "%"
  action = PopUp("VolPopup")

  label {
    value = Str(XVolLevel, 0) + "%"
  }
}

# 3. POPUP (optional) — detail view on click
PopUp("VolPopup") {
  style = "detail_popup"
  grid {
    style = "detail_grid"
    label { value = "Volume Control"; style = "detail_header" }
  }
}

#CSS
/* 4. WIDGET-SPECIFIC STYLES */
```

## Key Rules

### Exported Names Must Be Unique

Each `export button "name"` or `export label "name"` must have a unique name across all included widgets. Duplicate names cause silent conflicts.

### PopUp Names Must Match

```ini
# Button triggers popup
action = PopUp("VolPopup")

# Popup definition must use the same name
PopUp("VolPopup") { ... }
```

### Variables Must Be Defined Before Use

A widget that reads `XVolLevel` must either:
- Define it in a local `scanner {}` block
- Include a `.source` file that defines it
- Include another `.widget` that defines it

If the variable is never set, the widget shows empty/zero values.

### Private Blocks Scope Variables

```ini
Private {
  Var my_var = "value"  # Only visible within this widget
}
```

Variables outside `Private` blocks are global across all included files.

## Common Widget Patterns

### Text-style widget (clickable label)

```ini
export button "my-widget" {
  style = "text_widget"
  class = "module"
  tooltip = "Description"
  action = Exec("some-command")

  label { value = "Text" }
}
```

### Icon-style widget (button with icon)

```ini
export button "my-widget" {
  style = "module"
  class = "module"
  value = "icon-name-symbolic"
  tooltip = "Description"
  action = Exec("some-command")
}
```

### Scrolling text widget (marquee effect)

```ini
export button "my-widget" {
  style = "text_widget"
  css = "* { -GtkWidget-hexpand: true; }"
  label { value = "Long text that scrolls" }
}
```

## Checklist for New Widgets

- [ ] Scanner defines all variables the widget reads
- [ ] Exported name is unique (check with `grep -r 'export.*"' *.widget`)
- [ ] PopUp names match between trigger and definition
- [ ] CSS classes have matching definitions in `ocws.css` or `ocws.config`
- [ ] Widget is included in `plugins.config` (for the main config)
- [ ] Variable names match what `ocws-emit.sh` sends (for IPC-driven widgets)
