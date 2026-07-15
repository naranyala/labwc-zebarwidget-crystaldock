# Lesson: `include()` Inside `#CSS` Section Is Treated As CSS Text

## The Problem

A `#CSS` section that uses `include("file.css")` to load a GTK CSS file:

```ini
#Api2

Set ImagePath = "icons/misc:icons/weather"
bar "topbar:top" { ... }

#CSS

@define-color shell_bg rgba(30, 30, 46, 0.65);
button.module { padding: 0px 6px; border-radius: 6px; }

include("ocws.css")
```

The `include()` on the last line does **nothing**. Every style in `ocws.css` — including `font-family`, icon coloring, and glass panel backgrounds — is silently ignored.

## Root Cause

In zigshell-cairo-pango's config format, everything **after the `#CSS` marker** is treated as raw GTK CSS text, not as zigshell-cairo-pango configuration directives. The `include()` directive is a config-level command, not valid GTK CSS. GTK's CSS parser sees:

```css
include("ocws.css")
```

and discards it as unrecognized syntax. The file is never loaded.

The same applies to all zigshell-cairo-pango config directives (`Set`, `Exec`, `Function`, etc.) — none work inside the `#CSS` section.

## The Fix

There are two options:

### Option A: Move `include()` before `#CSS`

```ini
#Api2
...
include("ocws.css")

#CSS
@define-color shell_bg rgba(30, 30, 46, 0.65);
```

When `include()` runs before `#CSS`, zigshell-cairo-pango processes it as a config directive. If the included file contains a `#CSS` section of its own, its CSS is appended to the CSS from the parent file.

### Option B: Use a GTK CSS `@import`

```css
/* Inside the #CSS section (after #CSS marker) */
@import url("ocws.css");
```

GTK CSS supports `@import url("...")` for local file includes — but with a critical catch: the path is relative to the **current working directory** when zigshell-cairo-pango started, not relative to the config file.

## Where This Applies

- `dotfiles/ocws/ocws.config` line 394
- Any `.widget` or `.config` file with an inline `#CSS` section
- Template files that embed CSS inside config

## Pattern To Remember

| Context | Valid Syntax | Loads File |
|---------|-------------|------------|
| Before `#CSS` | `include("file.css")` | Yes |
| After `#CSS` | `include("file.css")` | **No** — treated as CSS text |
| After `#CSS` | `@import url("file.css")` | Yes — but relative to CWD |
