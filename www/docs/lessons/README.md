# OCWS Bug Lessons

Post-mortems and lessons learned from real bugs found in the OCWS codebase. Each file covers one class of problem, what went wrong, and the pattern to avoid.

## Shell Correctness

| File | Topic |
|------|-------|
| shell-function-syntax.md | Corrupted function definitions crashing scripts at load time |
| case-wildcard-swallows-all.md | Wildcard `*` in the wrong case arm making all named branches unreachable |
| multiline-command-substitution.md | Unquoted line breaks inside `$(...)` silently terminating commands early |
| redundant-action-calls.md | Calling a superset action before dispatching to specific ones (runs twice) |
| shell-missing-set-e.md | Missing `set -e` allowing silent failure propagation |
| source-cd-changes-cwd.md | `source`-ing a script that calls `cd` permanently changes the caller's working directory |

## Positional Arguments and Scope

| File | Topic |
|------|-------|
| positional-args-already-consumed.md | Re-reading `$2`/`$3` after they were already captured at the top of the script |
| function-param-indexing.md | Using the wrong `$N` index inside a function |
| variable-declared-before-use.md | Passing a variable to `jq` before it is declared |

## Paths and Portability

| File | Topic |
|------|-------|
| relative-paths-in-scripts.md | `./scripts/...` paths that only work from the project root |
| hardcoded-absolute-paths.md | Absolute developer machine paths baked into portable scripts |
| hardcoded-absolute-paths-again.md | Additional hardcoded path instances |
| fallback-to-hardcoded-path.md | Walk-up path resolution that silently falls back to a hardcoded dev path |
| portable-script-paths.md | General portable path patterns |

## Process and File Safety

| File | Topic |
|------|-------|
| kill-self-on-startup.md | `pkill -f` matching and killing the script that just launched |
| non-atomic-file-write.md | Modifying a live file and building a replacement simultaneously (race condition) |
| atomic-file-writes.md | Proper atomic file write patterns |
| sed-i-on-source-files.md | `sed -i` at runtime rewriting committed widget source files |
| same-file-redirect-truncation.md | Same-file redirect truncation before read |

## Side Effects and Data

| File | Topic |
|------|-------|
| double-side-effect.md | Clipboard copy running after `satty --copy-to-clipboard` already handled it |
| json-string-concatenation.md | Building JSON by string concatenation (malformed output) |
| sysmon-output-ordering.md | Output ordering mismatch in sysmon parsing |

## Security

| File | Topic |
|------|-------|
| c-system-command-injection.md | `system()` with unsanitized argv/metadata/clipboard content |
| eval-unsanitized-input.md | `eval` on user-supplied strings (arbitrary code execution) |
| ipc-command-injection.md | IPC command injection via unsanitized values |

## C and Memory Safety

| File | Topic |
|------|-------|
| c-sscanf-buffer-overflow.md | `sscanf` `%s` into fixed buffer causes stack overflow |
| c-unchecked-realloc.md | Unchecked `realloc` return value causes use-after-free |

## IPC and Event System

| File | Topic |
|------|-------|
| ipc-variable-mapping.md | Event Bus variable mapping mismatches |
| event-driven-ipc.md | Event-driven vs polling IPC patterns |
| ipc-command-injection.md | IPC command injection vectors |

## zigshell-cairo-pango Widget DSL

| File | Topic |
|------|-------|
| zigshell-cairo-pango-config-syntax.md | zigshell-cairo-pango config file syntax pitfalls |
| zigshell-cairo-pango-css-include-inside-css.md | CSS include inside CSS block |
| zigshell-cairo-pango-css-section-vs-include.md | CSS section vs include differences |
| zigshell-cairo-pango-css-selectors.md | CSS selector compatibility |
| zigshell-cairo-pango-icon-theme-chain.md | Icon resolution depends on GTK icon theme |
| zigshell-cairo-pango-nerd-font-tabs.md | Nerd Font tab rendering issues |
| zigshell-cairo-pango-ocws-css-not-gtk.md | `ocws.css` uses web CSS, not valid GTK CSS |
| zigshell-cairo-pango-private-scope.md | Private variable scope in widgets |
| zigshell-cairo-pango-rendering-and-icons.md | Rendering and icon display quirks |
| zigshell-cairo-pango-triggers.md | Trigger conditions and evaluation order |
| zigshell-cairo-pango-variable-naming.md | Variable naming conventions and collisions |
| zigshell-cairo-pango-widget-architecture.md | Widget architecture and lifecycle |
| widget-css-selector-mismatch.md | CSS selector mismatch between widget and theme |
| widget-division-by-zero.md | Division by zero in widget expressions |
| widget-execterm-not-valid.md | `ExecTerm()` not valid in all contexts |
| widget-interval-vs-scanner-step.md | Interval vs scanner step timing differences |
| widget-unclosed-if-parens.md | Unclosed parentheses in `If()` chains cause silent failure |

## Theme Engine and Build

| File | Topic |
|------|-------|
| theme-engine-and-installer.md | Theme engine and installer interaction issues |
| theme-engine-templates.md | Template rendering edge cases |

## Other

| File | Topic |
|------|-------|
| autostart-ordering.md | Service startup order in autostart |
| build-absolute-temp-dirs.md | Build system absolute temp directory handling |
| c-utilities-data-sources.md | C utility data source patterns |
| easing-functions-ui.md | Easing function behavior in UI animations |
| foot-terminal-configuration.md | Foot terminal configuration nuances |
| gtk-layer-shell.md | GTK layer shell protocol usage |
| ocws-c-native-abstractions.md | C native abstraction patterns |

## Quick Reference: Detection Commands

```bash
# Syntax check all scripts
find scripts/ dotfiles/ -name "*.sh" -exec bash -n {} \; && echo "All OK"

# Run shellcheck on everything
find scripts/ dotfiles/ -name "*.sh" | xargs shellcheck

# Find eval on variables
grep -rn '\beval\b.*\$' scripts/ --include="*.sh"

# Find hardcoded developer paths
grep -rn '/media/\|/home/[a-z]' scripts/ dotfiles/ --include="*.sh" | grep -v '#'

# Find sed -i on committed files
grep -rn 'sed -i' scripts/ --include="*.sh" | grep -v '\.bak\|\.tmp'

# Find bare relative paths
grep -rn '^\s*\./scripts/' scripts/ --include="*.sh"

# Validate all generated JSON
find ~/.config/ocws -name "*.json" -exec jq empty {} \; 2>&1
```
