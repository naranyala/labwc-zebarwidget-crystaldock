# Lesson: CSS Selector Mismatches Between Widgets And Styles

## The Problem

CSS rules that look correct but never match:

```css
label#clock { font-size: 13px; font-weight: bold; }
grid#XWifiPopup { background: @shell_bg; }
grid#notification_popup { background: @shell_bg; }
```

None of these styles ever apply. The clock has no bold text, the wifi popup has no background, the notification popup is transparent.

## Root Cause

zigshell-cairo-pango widget exports map to specific GTK element types. When the CSS says `label#clock` but the widget is a `<button>`, the selector fails:

```ini
# clock.widget
export button "clock" {   # ← type is button, not label
  ...
}
```

```css
/* WRONG — no <label> element with id "clock" exists */
label#clock { ... }

/* CORRECT — matches the button element */
button#clock { ... }
```

Similarly, `PopUp()` in zigshell-cairo-pango creates a `<window>`, not a `<grid>`:

```ini
# wifi.widget
window "XWifiWindow" {            # ← creates window#XWifiPopup
  style = "XWifiPopup"
  ...
}
```

```css
/* WRONG — no <grid> with id "XWifiPopup" exists */
grid#XWifiPopup { ... }

/* CORRECT — matches the window element */
window#XWifiPopup { ... }
```

## Affected Selectors

| File | Line | Wrong Selector | Element Type | Fixed Selector |
|------|------|----------------|--------------|----------------|
| `theme.css` | 114 | `label#clock` | `button` | `button#clock` |
| `ocws.css` | 320 | `label#clock` | `button` | `button#clock` |
| `wifi.widget` | 109 | `grid#XWifiPopup` | `window` | `window#XWifiPopup` |
| `notification-center.widget` | 161 | `grid#notification_popup` | `window` | `window#notification_popup` |

## Missing Selectors

Several widgets use `style = "module_pill"` but no CSS rule exists for it:

| Widgets Affected |
|------------------|
| `weather.widget`, `sysmon.widget`, `quick-settings.widget`, `power-profile.widget` |
| `nightlight.widget`, `clipboard.widget`, `disk.widget`, `cpu-monitor.widget` |
| `memory-monitor.widget`, `keyboard-layout.widget`, `custom-script.widget` |
| `media.widget`, `idle-inhibit.widget`, `network-text.widget` |

These 14 widgets have no styling (no border-radius, no padding, no hover effects) because `.module_pill` is not defined anywhere.

## The Fix

1. **Match the element type**: Use `button#id` for buttons, `window#id` for windows, `label#id` for labels
2. **Add missing selectors**: Define `.module_pill` / `button.module_pill` in the CSS

```css
/* Fix clock */
button#clock { font-size: 13px; font-weight: bold; }

/* Fix popups */
window#XWifiPopup { background: @shell_bg; }
window#notification_popup { background: @shell_bg; }

/* Add missing module_pill style */
button.module_pill {
  padding: 2px 8px;
  border-radius: 10px;
  background-color: transparent;
}
button.module_pill:hover {
  background-color: rgba(69, 71, 90, 0.4);
}
```

## Verification

```bash
# Find widgets with style= that has no matching CSS selector
for widget in dotfiles/ocws/*.widget; do
  styles=$(grep -oP 'style\s*=\s*"([^"]+)"' "$widget" | grep -oP '"[^"]+"' | tr -d '"' | sort -u)
  for style in $styles; do
    if ! grep -q "\.${style}\|#${style}" dotfiles/ocws/ocws.config dotfiles/ocws/*.css 2>/dev/null; then
      echo "MISSING CSS: $style (in $(basename $widget))"
    fi
  done
done
```

## Pattern To Remember

CSS selectors must match the **GTK element type** that zigshell-cairo-pango creates, not the logical widget type. A `button` export is a `<button>`, a `PopUp` creates a `<window>`, a `label` is a `<label>`. Mixing these up silently discards the styling.
