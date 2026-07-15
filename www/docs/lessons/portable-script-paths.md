# Portable Script Paths (Removing Hardcoded Machine Paths)

## The Problem
When scanning the codebase for portability issues, several shell scripts (`workspace-actions.sh`, `workspace.sh`, `theme-engine.sh`, `theme.sh`, `ocws-configure.sh`, `workspace-presets.sh`) contained hardcoded absolute paths pointing directly to a specific developer's machine:

```bash
PROJECT_DIR="/media/naranyala/Data/projects-remote/labwc-fuzzel-zigshell-cairo-pango"
```

If anyone cloned this repository to their home directory (`~/.dotfiles` or `~/Downloads/labwc-fuzzel-zigshell-cairo-pango`), the scripts would fail immediately because the fallback directory did not exist. 

## The Cause
It appears the original authors had trouble dynamically resolving the `PROJECT_DIR` root from deeply nested scripts (like those in `scripts/actions/`). For example, in `workspace-actions.sh`, they attempted:

```bash
# Buggy logic
if [[ -d "$SCRIPT_DIR/../actions" ]]; then
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
```

Because `$SCRIPT_DIR` was `.../scripts/actions`, `dirname $SCRIPT_DIR` resolves to `.../scripts`—which is *not* the project root (it's missing one more `dirname`). Because this relative pathing logic was flawed, they added a hardcoded `/media/naranyala/...` fallback to bypass the broken relative resolution.

## The Solution
I refactored all project root discovery blocks to use fully dynamic path resolution relative to `BASH_SOURCE[0]`.

For top-level scripts (`scripts/*.sh`):
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
```

For nested scripts (`scripts/actions/*.sh`):
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Walk two directories up
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
```

Additionally, in `ocws-configure.sh`, I replaced massive blocks of hardcoded `/media/naranyala/...` `cp` commands with `$PROJECT_DIR`. 

The repository is now fully portable and can be cloned and installed from any path!
