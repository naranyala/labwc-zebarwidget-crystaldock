# Lesson 6: Hardcoded Developer Machine Paths

**File affected:** `scripts/actions/menu-aesthetics.sh`
**Severity:** High — feature is completely broken on any machine other than the developer's

---

## What Happened

The theme picker listed themes with a path hardcoded to the developer's own machine:

```bash
theme_choice=$(ls /media/naranyala/Data/projects-remote/labwc-fuzzel-zigshell-cairo-pango/themes/*.ini \
    | xargs -n 1 basename -s .ini \
        | fuzzel -d -p "Theme > " -w 30 -l 12)
```

On any other system — or even on the same machine after the repo is cloned to a
different directory — this path doesn't exist. The `ls` fails silently, `fuzzel`
gets empty input, and the theme picker shows nothing.

## The Fix

Use a fallback chain that checks standard installed locations first, then falls back
to script-relative paths for development use:

```bash
_script_dir="$(cd "$(dirname "$0")" && pwd)"
_themes_dir=""
for _candidate in \
    "$HOME/.local/share/ocws/themes" \
    "$HOME/.config/ocws/themes" \
    "$_script_dir/../../themes" \
    "$_script_dir/../../../themes"
do
    if [[ -d "$_candidate" ]]; then
        _themes_dir="$_candidate"
        break
    fi
done

if [[ -z "$_themes_dir" ]]; then
    notify-send "Themes Not Found" "Could not locate a themes directory." -t 3000
else
    theme_choice=$(ls "$_themes_dir"/*.ini 2>/dev/null \
        | xargs -n 1 basename -s .ini \
    | fuzzel -d -p "Theme > " -w 30 -l 12)
fi
```

## The General Rule

> **Never hardcode absolute paths that include your username, home directory layout,
> or project clone location.** Use `$HOME`, `$XDG_CONFIG_HOME`, `BASH_SOURCE[0]`-
> relative paths, or a documented environment variable instead.

| Instead of | Use |
|---|---|
| `/home/naranyala/...` | `$HOME/...` |
| `/media/naranyala/Data/projects/...` | `$SCRIPT_DIR/../../...` relative to `BASH_SOURCE[0]` |
| Hardcoded config path | `${XDG_CONFIG_HOME:-$HOME/.config}/...` |
| Hardcoded data path | `${XDG_DATA_HOME:-$HOME/.local/share}/...` |

## Standard XDG Paths for OCWS

```bash
OCWS_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/ocws"
OCWS_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/ocws"
OCWS_THEMES="$OCWS_DATA/themes"
OCWS_PLUGINS="$OCWS_CONFIG/plugins"
```

Using these consistently means the project works on any machine with any username
and any home directory layout, including systems where `$HOME` is not under `/home`.

## How to Catch It

Grep for absolute paths that contain a username or project-specific mount point:

```bash
grep -rn '/media/\|/home/[a-z]\|/Users/' scripts/ dotfiles/ --include="*.sh"
```

Any hit is a candidate for replacement with a dynamic path.
