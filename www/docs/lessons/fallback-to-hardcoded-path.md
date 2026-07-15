# Lesson 14: Fallback to Hardcoded Path Undermines the Dynamic Lookup

**File affected:** `scripts/theme.sh`, `scripts/workspace.sh`, `scripts/workspace-presets.sh`
**Severity:** Low-Medium — the carefully written dynamic path resolution is silently bypassed

---

## What Happened

`theme.sh` has a correct, portable walk-up algorithm to find the project root:

```bash
_candidate="$SCRIPT_DIR"
while [[ "$_candidate" != "/" ]]; do
  if [[ -d "$_candidate/themes" ]]; then
    PROJECT_DIR="$_candidate"
    break
  fi
  _candidate="$(dirname "$_candidate")"
done
```

Then immediately undermines it with a hardcoded fallback:

```bash
# Fallback: known project path
[[ -z "$PROJECT_DIR" ]] && PROJECT_DIR="/media/naranyala/Data/projects-remote/labwc-fuzzel-zigshell-cairo-pango"
```

If the walk-up fails (e.g. installed to `~/.local/bin/` without the repo structure
nearby), it falls back to the developer's absolute path — which doesn't exist on
any other machine.

The same pattern appears in `workspace.sh`:

```bash
if [[ -d "$SCRIPT_DIR/.." ]]; then
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
elif [[ -d "/media/naranyala/Data/projects-remote/labwc-fuzzel-zigshell-cairo-pango/scripts" ]]; then
    PROJECT_DIR="/media/naranyala/Data/projects-remote/labwc-fuzzel-zigshell-cairo-pango"
fi
```

The `elif` branch only ever fires on the developer's machine.

And `workspace-presets.sh`:

```bash
if [[ -d "/media/naranyala/Data/projects-remote/labwc-fuzzel-zigshell-cairo-pango/scripts" ]]; then
    PROJECT_DIR="/media/naranyala/Data/projects-remote/labwc-fuzzel-zigshell-cairo-pango"
elif [[ -d "$(dirname "$SCRIPT_DIR")/scripts" ]]; then
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
else
    echo "Error: Cannot find project root" >&2
    exit 1
fi
```

Here the hardcoded path is checked *first*, before the portable one.

## The Fix

**Remove hardcoded developer paths entirely.** Replace with a clear error:

```bash
# theme.sh — after walk-up loop
if [[ -z "$PROJECT_DIR" ]]; then
    # Walk-up failed: try standard installed location
    if [[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/ocws/themes" ]]; then
        PROJECT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/ocws"
    else
        echo "Error: Cannot find OCWS themes directory." >&2
        echo "Set LABWC_PROJECT=/path/to/project or install to ~/.local/share/ocws/" >&2
        exit 1
    fi
fi
```

For `workspace-presets.sh`, fix the priority order:

```bash
# Check portable path first, hardcoded dev path last (or remove it)
if [[ -d "$(dirname "$SCRIPT_DIR")/scripts" ]]; then
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
else
    echo "Error: Cannot find project root" >&2
    exit 1
fi
```

## The General Rule

> A hardcoded fallback path that only exists on your machine is not a fallback —
> it's a trap. It makes the script appear to work in development while silently
> failing for everyone else.

A legitimate fallback chain (in priority order):
1. Explicit environment variable: `${OCWS_PROJECT:-}`
2. Walk-up from `BASH_SOURCE[0]` to find project root
3. Standard XDG install location: `~/.local/share/ocws/`
4. **Error with a helpful message** — never a hardcoded absolute path

```bash
find_project_root() {
    # 1. Explicit env var
    [[ -n "${OCWS_PROJECT:-}" && -d "$OCWS_PROJECT/themes" ]] && { echo "$OCWS_PROJECT"; return; }

    # 2. Walk up from script location
    local d
    d="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    while [[ "$d" != "/" ]]; do
        [[ -d "$d/themes" ]] && { echo "$d"; return; }
        d="$(dirname "$d")"
    done

    # 3. XDG install location
    local xdg_data="${XDG_DATA_HOME:-$HOME/.local/share}/ocws"
    [[ -d "$xdg_data/themes" ]] && { echo "$xdg_data"; return; }

    # 4. Clear error
    echo "Error: OCWS project root not found. Set OCWS_PROJECT=/path/to/ocws" >&2
    return 1
}
```

## How to Catch It

```bash
grep -rn '/media/\|/home/[a-z]\|/Users/' scripts/ --include="*.sh" | grep -v '#'
```

Any match that isn't inside a comment is a candidate for replacement.
