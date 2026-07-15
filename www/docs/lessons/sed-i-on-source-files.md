# Lesson 17: Modifying Deployed Config Files at Runtime With `sed -i`

**Files affected:** `scripts/ocws-state.sh`, `scripts/ocws-media-widget-updater.sh`
**Severity:** High — permanently corrupts widget source files; changes survive reboots

---

## What Happened

Several scripts use `sed -i` to modify widget `.widget` files in-place at runtime:

```bash
# ocws-state.sh — update_media_widgets()
sed -i 's|If(XMediaStatus != "none", "Artist: ".*"No media playing")|...|g' \
    "$player_widget"

sed -i 's|value = If(XArt != "none",.*|value = "/tmp/ocws-cover.jpg"|g' \
    "$media_widget"

# ocws-media-widget-updater.sh
sed -i "s|.*\\(value = \"/tmp/ocws-cover.jpg\"\\).*|...|" "$media_widget"

sed -i '/image {/a\...' "$widget_path"
```

These `sed -i` calls rewrite the deployed widget source files every time media
state changes. This creates several problems:

1. **Idempotency breaks.** After the first run, the sed pattern no longer matches
   (the file has already been changed), so subsequent runs either silently do
   nothing or apply the substitution to already-substituted text, producing
   double-nested expressions.

2. **Git diffs are permanently dirty.** Widget files in the repo are modified by
   runtime state. Every `git status` shows changes; every `git diff` is noise.

3. **Reinstallation silently reverts.** Running `install.sh` again overwrites the
   `sed`-modified files with the originals — all runtime changes are lost.

4. **No rollback path.** There's no record of what the file looked like before the
   `sed` ran. `sed -i` with no backup flag is irreversible.

5. **Race condition.** If zigshell-cairo-pango reads the widget file while `sed -i` is writing
   it (mid-rewrite), zigshell-cairo-pango sees a partial file.

## The Fix

**Separate config from state.** Widget source files should be static templates.
Runtime values should be injected via the OCWS Event Bus (`ocws-emit`), not by
rewriting the source file.

```bash
# WRONG — modifying the source file
sed -i 's|value = ".*"|value = "/tmp/ocws-cover.jpg"|' "$media_widget"

# RIGHT — emit the value through the event bus
ocws-emit.sh Media.CoverArt "/tmp/ocws-cover.jpg"
```

The widget reads the live value from the IPC channel:
```
# media.widget (static, never modified by scripts)
image {
  value = XMediaCoverArt
  interval = 1000
  style = "media_cover"
}
```

For cover art paths specifically, the daemon already writes to `/tmp/ocws-cover.jpg`
— the widget just needs to reference that fixed path. No `sed` needed at all.

## When `sed -i` Is Acceptable at Runtime

`sed -i` is safe at runtime only when:
- The file is generated fresh on every boot/start (not a committed source file).
- The edit is idempotent — running it twice produces the same result as running once.
- A backup is made: `sed -i.bak ...` so rollback is possible.

```bash
# Acceptable: modifying a generated file, idempotent, with backup
sed -i.bak "s/__THEME__/$theme_name/g" "$generated_config"
```

## The General Rule

> **Source files in the repo must not be modified by runtime scripts.**
> Runtime data belongs in state files (`/tmp/`, `~/.config/ocws/state/`),
> environment variables, or IPC channels — never in `.widget` or `.config` files
> that are under version control.

| What changes | Where it lives |
|---|---|
| Current volume | `ocws-emit System.Volume 75` |
| Current song | `ocws-emit Media.Title "Song Name"` |
| Cover art path | Write to `/tmp/ocws-cover.jpg`; widget references fixed path |
| Theme colors | Generate CSS from template; never patch the template in-place |
| Widget layout | Edit the source `.widget` manually; never via `sed -i` at runtime |

## How to Catch It

```bash
# Find all sed -i calls targeting dotfiles or widget files
grep -rn 'sed -i' scripts/ --include="*.sh" | grep -v '\.bak\|\.tmp\|generated'

# Check if any widget files have been modified outside of git-tracked changes
git diff --name-only dotfiles/ocws/*.widget
```
