# Lesson: Hardcoded Developer Machine Paths In Scripts

## The Problem

Several scripts contain absolute paths locked to the developer's machine:

```bash
# scripts/theme.sh:27
PROJECT_DIR="/media/naranyala/Data/projects-remote/labwc-fuzzel-zigshell-cairo-pango"
```

These scripts will **not work on any other machine**. They either fail immediately with "directory not found" or, worse, silently create/use wrong paths.

## Root Cause

During development, hardcoding a path is the fastest way to get something working. But these paths are then committed and deployed. The project has 6 such leaks:

| File | Line | Path |
|------|------|------|
| `scripts/theme.sh` | 27 | `/media/naranyala/Data/projects-remote/labwc-fuzzel-zigshell-cairo-pango` |
| `scripts/ocws-configure.sh` | 46, 51, 56, 65, 92-93 | `/media/naranyala/Data/projects-remote/labwc-fuzzel-zigshell-cairo-pango/...` |
| `scripts/actions/workspace.sh` | 17 | `/media/naranyala/Data/projects-remote/labwc-fuzzel-zigshell-cairo-pango` |
| `scripts/actions/workspace-actions.sh` | 13 | `/media/naranyala/Data/projects-remote/labwc-fuzzel-zigshell-cairo-pango/scripts/actions` |
| `scripts/workspace-presets.sh` | 10 | `/media/naranyala/Data/projects-remote/labwc-fuzzel-zigshell-cairo-pango/scripts` |
| `scripts/theme-engine.sh` | 46 | `/media/naranyala/Data/projects-remote/labwc-fuzzel-zigshell-cairo-pango` |

## The Fix

Derive the project root from the script's own location at runtime:

```bash
# At the top of each script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"  # or walk up until you find a known marker file
```

Better: use an environment variable with a sensible fallback:

```bash
PROJECT_DIR="${LABWC_PROJECT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
```

## Verification

```bash
# Check for any remaining hardcoded paths
grep -rn '/media/naranyala' scripts/ dotfiles/ --include='*.sh'
```

## Pattern To Remember

Commit-time paths become deployment-time bugs. Any absolute path that contains a username (`/home/$USER/...`) or looks like `/media/...` is a **liability**. Always resolve paths relative to `$0` or `BASH_SOURCE[0]` at the top of the script.
