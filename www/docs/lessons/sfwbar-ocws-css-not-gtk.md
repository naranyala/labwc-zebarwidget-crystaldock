# Lesson: `ocws.css` Uses Web CSS — Not Valid GTK CSS

## The Problem

The file `dotfiles/ocws/ocws.css` contains CSS that looks correct in a browser but is **entirely invalid** for GTK's CSS engine. When GTK parses it (via `@import` or `include()`), it silently rejects most or all rules. No styling from this file takes effect.

## Root Cause

`ocws.css` was written with web-browser CSS features that GTK does not support:

| Feature | Example in `ocws.css` | GTK Support |
|---------|----------------------|-------------|
| `@import url("https://...")` | `@import url("https://fonts.googleapis.com/...")` | (X) GTK supports `@import` only for local files |
| CSS custom properties | `--blur-intensity: 5;` | (X) No `var()` / custom properties |
| `backdrop-filter` | `backdrop-filter: blur(...)` | (X) Not a GTK property |
| `-webkit-*` prefixes | `-webkit-backdrop-filter: blur(...)` | (X) Not a GTK property |
| `linear-gradient()` | `background: linear-gradient(...)` | (X) Not in GTK CSS |
| `@keyframes` | `@keyframes pulse-glow { ... }` | (X) Not in GTK CSS |
| `rgba(#hex, alpha)` | `rgba(#1e1e2e, 0.85)` | (X) Use `alpha(#1e1e2e, 0.85)` instead |
| `attr(var(...))` | `calc(var(--blur-intensity) * 2px)` | (X) No `calc()` or `var()` |

## The Fix

Separate concerns:

1. **`theme.css`** (generated from `zigshell-cairo-pango.css.tmpl`) — valid GTK CSS with `@define-color`, `alpha()`, standard properties. This is what zigshell-cairo-pango should load.

2. **`ocws.css`** (generated from `ocws.css.tmpl`) — web CSS for external tools (browser previews, zebar, documentation). This is **not** meant for GTK.

The config include must point at `theme.css`, not `ocws.css`:

```ini
# CORRECT — before #CSS section
include("theme.css")

#CSS
...
```

## Where This Applies

- `dotfiles/ocws/ocws.css` — completely replaced by theme engine from `ocws.css.tmpl`
- `dotfiles/ocws/theme.css` — correct GTK CSS generated from `zigshell-cairo-pango.css.tmpl`
- Any custom CSS file added to the project

## Verification

Test whether a CSS file is valid GTK CSS:

```bash
# Use gtkcss to validate
echo '@import url("path/to/file.css");' | gtkcss-parser 2>&1

# Or run zigshell-cairo-pango with --css and watch for warnings
zigshell-cairo-pango --css path/to/file.css 2>&1 | grep -i "css\|warning\|error"
```

## Pattern To Remember

GTK CSS is a **subset** of web CSS. If it uses `backdrop-filter`, `@keyframes`, `linear-gradient`, `var(--...)`, or `rgba(#hex,...)`, GTK will ignore it silently. Stick to `@define-color`, `alpha()`, and standard CSS2.1 properties.
