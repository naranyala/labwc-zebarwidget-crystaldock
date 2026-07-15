# Lesson: `#CSS` Section vs `include()` for Widget Styles

## The Problem

Widget files can contribute CSS in two ways, and mixing them up causes styles to not apply.

## Two Mechanisms

### 1. `#CSS` Section (Inline)

```ini
#Api2

export button "volume-text" {
  label { value = Str(XVolLevel, 0) + "%" }
}

#CSS

button#volume-text {
  color: #cdd6f4;
  font-size: 12px;
}
```

The `#CSS` section is appended to the **global CSS context**. Its selectors apply to all matching widgets, not just the one that defined them.

### 2. `include()` (External File)

```ini
#Api2
include("volume-text.widget")
```

The included file's `#CSS` section is also merged into the global CSS context. There's no isolation — all CSS from all included files becomes one stylesheet.

## The Gotcha: `include()` Inside `#CSS`

```ini
#Api2

#CSS
include("volume-text.css")  # ← THIS IS WRONG
```

When `include()` appears inside a `#CSS` section, zigshell-cairo-pango treats it as **literal CSS text**, not a config directive. It tries to parse `include("volume-text.css")` as a CSS rule and fails silently.

**Fix**: Put `include()` at the top of the file, outside any `#CSS` section:

```ini
#Api2
include("volume-text.css")  # ← CORRECT — at top level

#CSS
/* actual CSS rules here */
```

## CSS Specificity

All widget CSS is merged into one stylesheet. Specificity follows standard CSS rules:

```css
/* Lower specificity — applies to all buttons */
button { color: gray; }

/* Higher specificity — applies only to volume-text */
button#volume-text { color: white; }

/* Highest specificity — applies on hover */
button#volume-text:hover { color: blue; }
```

If two widgets define conflicting rules for the same selector, the last one loaded wins (determined by `include()` order in `plugins.config`).

## Best Practices

1. **Namespace your CSS selectors** — Use unique IDs or classes: `button#my-widget`, `.my-widget-class`
2. **Keep widget CSS minimal** — Only style the widget itself, not other widgets
3. **Put shared styles in `ocws.config` CSS section** or `ocws.css` — not in individual widget files
4. **Never put `include()` inside `#CSS`** — always at the top of the file
