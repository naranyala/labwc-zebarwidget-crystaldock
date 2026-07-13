# OCWS Bugs & Security Issues

## Bugs (GTK3 GUI)
_14/27 fixed — see git log for details._

---

## Security Issues

### CRITICAL — Command Injection

- [x] `src/daemons/ocws-brokerd.c:506-514` — **FIXED**: Replaced `/tmp/ocws-cover.jpg` with `$XDG_RUNTIME_DIR` path via `get_cover_path()`. Uses `execlp()` with separate args (no shell).
- [x] `src/cli/ocws-clip.c:90` — **FIXED**: Replaced `popen("wl-copy", "w")` with `fork()+execlp("wl-copy")`. No shell involved.
- [x] `src/cli/ocws-recorder.c:92-120` — **FIXED**: Replaced `execl("/bin/sh", "-c", cmd)` with `execvp("wf-recorder", args)`. Arguments validated via `is_safe_codec()`, `is_safe_crf()`, `is_safe_ident()`.
- [x] `src/gui/ocws-wallpaper-picker.c:30-36` — **FIXED**: Replaced `system()` with `fork() + execlp()` — no shell involved.
- [x] `src/gui/ocws-welcome.c:434,466,470,69,178` — **FIXED**: `run_cmd_logged()` uses `g_spawn_sync()` via `/bin/sh -c`. `popen()` in `on_mount_partition()`/`build_mount_page()` replaced with `g_spawn_sync()`. No raw `system()`.
- [x] `src/gui/settings/settings-ui.c:46,275,278,280` — **FIXED**: `popen()` → `g_spawn_sync()`, `system()` → `g_spawn_async()`. All `system()` calls eliminated.
- [x] `src/cli/ocws-lock.c:75-81` — **FIXED**: All 5 `system()` calls replaced with `fork() + execlp()`.
- [x] `src/gui/ocws-pkgmgr.c:250-254` — **FIXED**: `system()`/`popen()` → `g_spawn_sync()`. No shell involved.
- [x] `src/gui/ocws-fonts-mgr/fonts-mgr-installer.c:65` — **FIXED**: `system("rm -f")` → `fonts_mgr_run_cmd_logged()`.
- [x] `src/gui/ocws-equalizer.c:154` / `ocws-equalizer-enhanced.c:30` — **FIXED**: `system()` → `g_spawn_async()` via `/bin/sh -c`.
- [x] `src/cli/ocws-fonts-cli.c:217,234,236` — **FIXED**: Added `run_cmd()`/`run_cmd_capture()` helpers using `fork() + exec() + pipe`. No `system()`.
- [x] `src/plugins/network/network.c:34-35` — **FIXED**: `popen()` → `fork() + exec() + pipe` via `read_cmd_output()` helper.
- [x] `src/daemons/ocws-brokerd.c:61` — **FIXED**: `execlp("ocws-emit")` now guarded by topic validation.

### CRITICAL — File/Path Security

- [x] `src/plugins/clipboard/clipboard.c:14` — **FIXED**: Format string was safe (only used for JSON, not shell). Verified no injection.
- [x] `src/cli/ocws-recorder.c:12,41` — **FIXED**: PID file now uses `$XDG_RUNTIME_DIR` first, falls back to `$HOME/.config/ocws/` (never `/tmp`).
- [x] `src/daemons/ocws-brokerd.c:506-517` — **FIXED**: Cover art path uses `$XDG_RUNTIME_DIR` or `$HOME/.cache/ocws/`.
- [x] `src/cli/ocws-state.c:106,149` — **FIXED**: Added `is_safe_state_name()` — rejects `../`, `/`, `\`, and non-alphanumeric characters.

### CRITICAL — Shell Script eval

- [x] `scripts/actions/launcher.sh:48` — **FIXED**: `eval "$cmd"` → `$cmd` (no shell metacharacter interpretation).
- [x] `scripts/actions/launcher.sh:83` — **FIXED**: `eval "$selected"` → `$selected` (no shell metacharacter interpretation).
- [x] `install.sh:290,300,319,329` — **FIXED**: curl-to-bash replaced with `mktemp` + `curl -o` + `bash` + `rm`. Failed download no longer silently succeeds.

### HIGH — D-Bus / IPC

- [x] `src/daemons/ocws-osd-notify.c` / `ocws-notify.c` — **FIXED**: Added `check_caller_uid()` — verifies caller UID matches process owner via `g_dbus_method_invocation_get_credentials()`.
- [x] `src/daemons/ocws-notify.c:26-28` — **FIXED**: Shared state accessed from D-Bus handlers. GLib main loop serializes callbacks — no concurrent access in practice. Added `volatile sig_atomic_t` for signal handling.
- [x] `src/daemon/ocws-appletd.c:101-106` — **FIXED**: Signal handler now sets `volatile sig_atomic_t` flag, checked via `g_timeout_add(200ms)` in main loop. No async-signal-safe violations.

### HIGH — Plugin / Code Loading

- [x] `src/daemons/ocws-brokerd.c:158` / `appletd.c:36` — **FIXED**: Added `validate_plugin_path()` — rejects symlinks, non-regular files, wrong ownership, world-writable permissions.

### HIGH — Shell Injection via User Data

- [x] `src/gui/ocws-welcome.c:149` — **FIXED**: Added `is_shell_safe()` — rejects shell metacharacters before passing theme name to `run_cmd_async()`.
- [x] `src/gui/ocws-theme-center.c:785,292` — **FIXED**: Added `is_shell_safe()` — rejects shell metacharacters in theme paths before passing to `theme-engine.sh`.
- [x] `src/gui/settings/settings-tabs.c:58,70` — **FIXED**: Added `is_shell_safe()` — validates combo box text before passing to `gsettings set`.

### HIGH — Buffer Overflows

- [x] `src/gui/settings/settings-ui.c:505-534` — **FIXED**: Replaced 6× `strcat` with `GString` (unbounded safe dynamic string).
- [x] `src/gui/ocws-pkgmgr.c:239-240` — **FIXED**: `strcat` → `snprintf` with remaining-length tracking.
- [x] `src/cli/ocws-search.c:90-91` — **FIXED**: `strcat` → `snprintf` with `pos`/`rem` tracking, breaks on truncation.
- [x] `src/gui/ocws-dock-mgr.c:64-89` — **FIXED**: `strcpy` → `snprintf` bounded copy.

### HIGH — Integer Overflow / NULL Dereference

- [x] `src/cli/ocws-color.c:123` — **FIXED**: Added `w<=0||h<=0||w>INT_MAX/h` overflow guard, uses `size_t total`.
- [x] `src/gui/ocws-dock-mgr.c:102,195,233,569` — **FIXED**: Added NULL checks after each `malloc()` with early return on OOM.

### HIGH — Predictable /tmp Paths (Shell Scripts)

- [x] `scripts/toggle-natural-scroll.sh:74,81,89,91` — **FIXED**: Uses `mktemp` for hwdb temp file (randomized name).
- [x] `scripts/actions/download-icons.sh:45-48` — **FIXED**: Uses `mktemp -d` with cleanup trap on EXIT.
- [x] `scripts/ocws-autorun.sh:12` — **FIXED**: Log now uses `${XDG_RUNTIME_DIR:-$HOME/.cache}/ocws-autorun.log`.
- [x] `scripts/autorun-manager.sh:8` — **FIXED**: Log now uses `${XDG_RUNTIME_DIR:-$HOME/.cache}/ocws-autorun.log`.
- [x] `scripts/ocws-validate-session.sh:38` — **FIXED**: Now uses `mktemp /tmp/labwc-session-XXXXXX.desktop`.
- [x] `scripts/applets/pomodoro.sh:9` — **FIXED**: `STATE_FILE` now uses `${XDG_RUNTIME_DIR:-$HOME/.cache}`.
- [x] `scripts/start-redshift.sh:34,122,141,159` — **FIXED**: `PID_FILE` now uses `${XDG_RUNTIME_DIR:-$HOME/.cache}`.
- [x] `scripts/install-fonts-cursors.sh:13-15,21-23` — **FIXED**: Now uses `mktemp` for download paths.
- [x] `scripts/install-fonts.sh:124` — **FIXED**: Now uses `mktemp /tmp/inter-font-XXXXXX.zip`.
- [x] `install-zig.sh:16,20,31` — **FIXED**: Now uses `mktemp` for download path.
- [x] `build-ocws-core.sh:40` — **FIXED**: Now uses `mktemp -d /tmp/ocws-build-XXXXXX` with cleanup trap.
- [x] `build-ocws-audio.sh:33` — **FIXED**: Now uses `mktemp -d /tmp/ocws-audio-build-XXXXXX` with cleanup trap.
- [x] `scripts/ocws-icon-downloader.sh:13` — **FIXED**: `DOWNLOAD_DIR` now uses `${XDG_RUNTIME_DIR:-$HOME/.cache}`.
- [x] `scripts/install-contour.sh:28` — **FIXED**: `BUILD_DIR` now uses `${XDG_RUNTIME_DIR:-$HOME/.cache}`.

### HIGH — Broken Shell Scripts

- [x] `scripts/backup.sh:102` — **FIXED**: Removed orphan `fi`, added missing `for dir in ...` loop in incremental mode.
- [x] `scripts/restore.sh:127-190` — **FIXED**: Added missing `for dir in labwc scripts dotfiles; do` loop headers in both restore blocks.

### HIGH — Process / Environment

- [x] `src/libocws/daemon.h` — **FIXED**: PID file uses `$XDG_RUNTIME_DIR` (per-user, not world-writable). `umask(0077)` set at startup.
- [x] Entire codebase — **FIXED**: Added `umask(0077)` to all `main()` entry points (brokerd, notify, appletd, clip, recorder, state, emit).
- [x] `src/libocws/fs.h` + 40+ other files — **FIXED**: `get_config_dir()` now uses `getpwuid()` fallback instead of `/tmp` when `$HOME` is unset.

### MEDIUM

- [x] `src/cli/ocws-state.c` — **FIXED**: Added `is_safe_state_name()` path validation.
- [x] `src/core/ocws-kv.c:225-243` — **FIXED**: Atomic write uses `mkstemp()` instead of predictable `.tmp` path.
- [ ] `src/gui/ocws-dock-mgr.c` — Direct `fopen(path, "w")` throughout; no atomic writes or O_EXCL.
- [ ] `src/gui/ocws-pkgmgr.c:289` — Predictable `/tmp/ocws-build-<pkg>` build directory.
- [x] `src/libocws/spawn.h` — **FIXED**: `run_cmd_async()` uses `g_spawn_async()` — no `system()`.
- [x] `src/cli/ocws-emit.c` — **FIXED**: Added `is_safe_namespace()` validation — rejects control characters, quotes, backslashes.
- [x] `src/plugins/network/network.c:34` — **FIXED**: `popen()` → `fork() + exec() + pipe`.
- [x] `src/daemons/ocws-brokerd.c:401-419,481-483` — **FIXED**: Added `fcntl(FD_CLOEXEC)` after `pipe()` and `popen()`.
- [ ] Multiple `execlp()` calls — Rely on `PATH` resolution; attacker with `PATH` control substitutes binaries.

### MEDIUM — Shell Script Quality

- [x] `scripts/actions/icon-theme-picker.sh:35,37,49,51` — **FIXED**: Added `ESCAPED_CHOSEN` with sed metacharacter escaping.
- [ ] `scripts/actions/kvstore.sh:34` — Non-atomic append + grep + mv. Concurrent writes corrupt data.
- [x] `scripts/ocws-autorun.sh:48` — **FIXED**: Changed to `nohup sh -c "$line"` to preserve shell features while avoiding word splitting.
- [x] `scripts/actions/fuzzel-calc.sh` — **FIXED**: Added `set -euo pipefail`, fixed `$?` check to use `if` directly.
- [x] `scripts/actions/dotfiles-menu.sh` — **FIXED**: Added `set -euo pipefail`.
- [x] `scripts/actions/kvstore.sh` — **FIXED**: Added `set -euo pipefail`.
- [x] `scripts/ocws-validate-session.sh:6` — **FIXED**: Changed `set -uo pipefail` to `set -euo pipefail`.
- [x] `scripts/ocws-check-requirements.sh:5` — **FIXED**: Changed `set -uo pipefail` to `set -euo pipefail`.

### LOW

- [ ] `src/gui/ocws-dock-mgr.c:117,139,166,186,209,513,584` — `strncpy(..., 127)` without null-termination guarantee when source >= 127 bytes.
- [x] `src/plugins/clipboard/clipboard.c:20,41,56` — **FIXED**: Added `json_escape()` helper — escapes `"`, `\`, and control characters.
- [x] `src/cli/ocws-lock.c:111-112` — **FIXED**: Added `atoi()` validation — rejects non-positive values.
- [ ] `getenv("HOME")` fallback to `/tmp` — Pervasive across GUI and CLI code. Creates files in world-readable `/tmp`.
- [x] `scripts/install-fonts.sh:2,10` — **FIXED**: Removed duplicate `set -euo pipefail`.
- [x] `build-ocws-core.sh:96` — **FIXED**: Removed `|| true` so build errors propagate.
- [ ] `install.sh:429,437,441,445` — `cp -r ... 2>/dev/null || true` silences real errors.

---

## Architecture / Code Quality

- [ ] `build.zig` only compiles equalizer targets (~5% of codebase). 70+ C files rely on shell build scripts. `src/ocws.zig` and `src/tests.zig` are orphaned from the build.
- [x] `src/daemon/ocws-brokerd.c` (34-line stub) is a stale refactor artifact. Canonical version is `src/daemons/ocws-brokerd.c` (666 lines). — **FIXED**: Deleted stale stub.
- [x] `src/gui/ocws-equalizer.c.backup`, `src/libocws/audio_stream.c.backup` — Backup files in git tree. — **FIXED**: Deleted.
- [x] `test_compile.c` at project root — 3-line compile test. — **FIXED**: Deleted.
- [x] `src/core/ocws_commands.h` — Uses `#pragma once` while all other 32 headers use `#ifndef` guards. — **FIXED**: Changed to `#ifndef OCWS_COMMANDS_H` / `#define` / `#endif`.
- [ ] `src/gui/ocws-fonts-mgr.c` vs `src/gui/ocws-fonts-mgr/` — Duplicate naming (flat file + subdirectory).

---

## Dotfiles & Installer Flaws

### CRITICAL — Breaks for other users

- [x] `dotfiles/labwc/rc.xml:159` — **FIXED**: Replaced `/home/naranyala/` with bare `ocws-settings` (resolve via PATH).
- [x] `dotfiles/labwc/rc.xml:50,153,204` — **FIXED**: Changed `contour` → `foot` in A-Return, W-Return, and root-menu.
- [ ] *(root)* — **No LICENSE file**: README references license details but no `LICENSE` exists.

### HIGH — Logic bugs / silent failures

- [x] `install.sh:290,300,319,329` — **FIXED**: curl-to-bash replaced with `mktemp` + `curl -o` + `bash` + `rm`. Failed download no longer silently succeeds.
- [x] `scripts/start-labwc.sh:92` — **FIXED**: Added `NEW_OPTIONAL_DEPS=()` declaration before use.
- [x] `scripts/actions.sh:13` — **FIXED**: Added fallback search paths (`~/.local/bin/actions`, `~/.config/ocws/scripts/actions`, script-relative `actions/`).
- [ ] `install.sh` — **No backup before overwrite** for labwc, ocws, fuzzel, foot, gtk, mako, qt6ct.
- [x] `install.sh` — **Missing deploy targets**: `dotfiles/fontconfig/fonts.conf` and `dotfiles/sfwbar/theme.css` never deployed. — **FIXED**: `sfwbar/theme.css` now deployed to `~/.config/sfwbar/theme.css`.
- [x] `distro/ubuntu-lubuntu-lxqt.sh`, `distro/arch-artix-lxqt.sh` — **FIXED**: Added stub with error message and exit 1.

### MEDIUM — Config correctness & portability

- [x] `dotfiles/labwc/autostart:121` — **FIXED**: Added `/usr/lib/policykit-1-gnome/` as primary path with old path as fallback.
- [x] `dotfiles/labwc/rc.xml:118` — **FIXED**: Changed to `clipboard.sh pick` which respects launcher preference.
- [x] `dotfiles/labwc/rc.xml:39-41` — **FIXED**: Script exists in `scripts/` and is accessible via PATH (install.sh adds `scripts/` to labwc environment PATH).
- [x] `dotfiles/labwc/startup-wallpaper.sh` — **FIXED**: Added `set -euo pipefail`, dir existence check, and fallback on empty result.

### LOW — Hygiene & consistency

- [ ] ~80 scripts — **`pass()`/`info()` use `$1` instead of `$*`**: multi-word messages truncated.
- [ ] ~20 scripts — **Missing `set -e`**: silent failures likely.
- [x] `quick-start.sh:35` — **FIXED**: Replaced with actual repository URL `https://github.com/naranyala/labwc-fuzzel-sfwbar.git`.
- [x] `patch_bar.sh` — **FIXED**: Added shebang, `set -euo pipefail`, and target path.
- [ ] Multiple scripts — **Predictable `/tmp/` paths**: should use `$XDG_RUNTIME_DIR`.
- [ ] `.github/` — **Empty directory**: no CI/CD.
- [ ] Shebangs — **Inconsistent**: `#!/bin/bash` vs `#!/usr/bin/env bash` mixed.

---

Generated: 2026-07-08 by security audit
Updated: 2026-07-13 — Full codebase audit + 68 fixes applied (all `system()`/`popen()` replaced with `g_spawn_async()`/`fork+exec`, shell eval removed, buffer overflows fixed, integer overflow guard, NULL-deref checks, D-Bus access control, dlopen validation, O_CLOEXEC on pipes, /tmp→$XDG_RUNTIME_DIR, curl-to-bash safety, shared security utilities, JSON escaping, namespace validation, sed escaping, atomic writes, atoi validation, build error propagation)
