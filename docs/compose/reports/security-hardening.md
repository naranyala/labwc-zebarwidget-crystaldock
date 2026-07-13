---
feature: security-hardening
status: delivered
specs: []
plans:
  - .mimocode/plans/1783943337529-happy-island.md
branch: main
commits: (uncommitted)
---

# Security Hardening — Final Report

## What Was Built

Comprehensive security audit and hardening of the OCWS codebase, addressing command injection, buffer overflows, integer overflows, predictable temporary paths, shell script quality issues, and dotfile configuration problems. Created shared security utilities (`ocws_is_shell_safe()`, `ocws_shell_escape()`, `ocws_is_safe_name()`) in `src/libocws/ocws_string.h` for reuse across the codebase.

## Architecture

### Shared Security Utilities (`src/libocws/ocws_string.h`)

Three static inline functions added to the existing string utility header:

- `ocws_is_shell_safe(const char *s)` — Returns 1 if string contains no shell metacharacters (`;|&$\`(){}[]`\\<>'`)
- `ocws_shell_escape(char *dst, size_t dstsz, const char *src)` — Escapes single quotes for safe shell interpolation using the `'\''` pattern
- `ocws_is_safe_name(const char *s)` — Validates identifiers: alphanumeric, hyphens, underscores, dots only

### C Code Fixes

**Command Injection (CRITICAL):**
- `ocws-wallpaper-picker.c`: Replaced `system()` with `fork()+execlp()` for swaybg and wallpaper-theme.sh
- `ocws-welcome.c`: Replaced `system()` in `send_notification()` with `fork()+execlp("notify-send")`. Added `/dev/` prefix validation for device paths. Added `ocws_shell_escape()` for mount points.
- `settings-ui.c`: Added `ocws_shell_escape()` to `kv_set()` before shell interpolation
- `network.c`: Added `is_valid_interface()` validation before `popen()` calls
- `ocws-brokerd.c`: Added control character validation for plugin bus topic/value before `execlp()`

**Buffer Overflows (HIGH):** Already fixed in codebase (GString, snprintf+offset tracking).

**Integer Overflow (HIGH):** Already fixed in codebase (overflow guards, size_t casts).

**JSON Escaping (LOW):**
- `clipboard.c`: Added `json_escape()` helper for clipboard content embedded in JSON

**Namespace Validation (MEDIUM):**
- `ocws-emit.c`: Added `is_safe_namespace()` — rejects control characters, quotes, backslashes

**Atomic Writes (MEDIUM):**
- `ocws-kv.c`: Replaced predictable `.tmp` path with `mkstemp()` for atomic writes

**atoi Validation (LOW):**
- `ocws-lock.c`: Added validation for command-line timeout arguments

### Shell Script Fixes

**Shell Quality (HIGH):**
- `icon-theme-picker.sh`: Added `ESCAPED_CHOSEN` with sed metacharacter escaping
- `ocws-autorun.sh`: Changed `nohup $line` to `nohup sh -c "$line"` to avoid word splitting
- `start-labwc.sh`: Added `NEW_OPTIONAL_DEPS=()` declaration before use
- `actions.sh`: Added fallback search paths for action scripts

**Build Safety:**
- `build-ocws-core.sh`: Removed `|| true` from `make` so build errors propagate

### Dotfile Fixes

- `rc.xml`: Changed clipboard keybind from hardcoded `rofi -dmenu` to `clipboard.sh pick` which respects launcher preference

## Verification

- All C files pass `gcc -fsyntax-only` checks
- All shell scripts pass `bash -n` syntax checks
- `ocws_string.h` compiles cleanly with no warnings

## Journey Log

- Many items in TODOS.md were already fixed in previous sessions (buffer overflows, /tmp paths, eval removal, D-Bus access control, dlopen validation)
- The subagent approach failed (no output from 3 parallel agents) — switched to direct implementation
- The `ocws_string.h` include path mismatch (`string.h` vs `ocws_string.h`) required updating 3 files
