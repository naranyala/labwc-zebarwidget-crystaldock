# OCWS Bugs & Security Issues

## Bugs (GTK3 GUI)
_14/27 fixed — see git log for details._

---

## Security Issues

### CRITICAL — Command Injection

- [ ] `src/daemons/ocws-brokerd.c:506-514` — Playerctl `mpris:artUrl` metadata passed unescaped into `system(cp '%s' /tmp/ocws-cover.jpg)`. A `'` in album art URL breaks shell quoting → RCE. **Fix:** Use `execvp()` or validate/reject `'` in path.
- [ ] `src/cli/ocws-clip.c:90` — `echo -n "%s" | wl-copy` with unsanitized user text. `"` or `$()` in text → RCE. **Fix:** Use `execvp("wl-copy")` with pipe, or escape shell metacharacters.
- [ ] `src/cli/ocws-recorder.c:92-120` — `codec`/`crf`/`audio` from CLI args into `execl("/bin/sh", "-c", cmd)`. `;` or `$()` in arg → RCE. **Fix:** Validate against allowlist of known codecs.

### CRITICAL — File/Path Security

- [ ] `src/plugins/clipboard/clipboard.c:14` — `snprintf` format string with dangling `%s` (no variadic arg) → undefined behavior, likely crash.
- [ ] `src/cli/ocws-recorder.c:12,41` — Predictable PID file `/tmp/ocws-recorder.pid`. **Fix:** Use `$XDG_RUNTIME_DIR` (per-user, not world-writable).
- [ ] `src/daemons/ocws-brokerd.c:506-517` — Predictable `/tmp/ocws-cover.jpg` + `system()` → symlink attack + command injection.
- [ ] `src/cli/ocws-state.c:106,149` — State name from `argv[2]` used directly in `fopen(path, "w")`. Value like `../../etc/cron.d/evil` escapes the state directory.

### HIGH — D-Bus / IPC

- [ ] `src/daemons/ocws-osd-notify.c` / `ocws-notify.c` — D-Bus methods registered with no access control. Any session bus process can call `Notify()`, `CloseNotification()`, etc.
- [ ] `src/daemons/ocws-notify.c:26-28` — Shared mutable state accessed from D-Bus handlers with no synchronization. Race condition on `notif_count`/`next_id`.
- [ ] `src/daemon/ocws-appletd.c:101-106` — Signal handler calls `g_main_loop_is_running()` / `g_main_loop_quit()` (not async-signal-safe). Use `volatile sig_atomic_t` flag + check in main loop.

### HIGH — Plugin / Code Loading

- [ ] `src/daemons/ocws-brokerd.c:158` / `appletd.c:36` — `dlopen()` from `~/.local/share/ocws/plugins/` and `$OCWS_PLUGIN_DIR`. No signature/checksum verification. Any writable-plugin-path user can inject arbitrary shared libraries.

### HIGH — Shell Injection via User Data

- [ ] `src/gui/ocws-welcome.c:149` — `theme.sh %s` with theme name from `~/.local/share/ocws/themes/*.ini` filename. Filename like `$(curl ...).ini` → RCE.
- [ ] `src/gui/ocws-theme-center.c:785,292` — `theme-engine.sh apply '%s'` with theme path from CWD scan. Running from `/tmp/foo';id;'` → RCE.
- [ ] `src/gui/settings/settings-tabs.c:58,70` — Combo box text into `gsettings set` via `system()`. Currently safe (hardcoded items), but combo could become editable.

### HIGH — Process / Environment

- [ ] `src/libocws/daemon.h` — PID file read/write with TOCTOU race. PID reuse attack possible.
- [ ] Entire codebase — No `umask()` call anywhere. File permissions depend on inherited umask.
- [ ] `src/libocws/fs.h` + 40+ other files — `getenv("HOME")` with `/tmp` fallback. If `HOME` unset, world-writable `/tmp` used for config/data/state.

### MEDIUM

- [ ] `src/cli/ocws-state.c` — No path validation on state name; `../../` possible.
- [ ] `src/core/ocws-kv.c:225-243` — Atomic write symlink race: `.tmp` path is predictable, `remove()`+`rename()` fallback opens TOCTOU.
- [ ] `src/gui/ocws-dock-mgr.c` — Direct `fopen(path, "w")` throughout; no atomic writes or O_EXCL.
- [ ] `src/gui/ocws-pkgmgr.c:289` — Predictable `/tmp/ocws-build-<pkg>` build directory.
- [ ] `src/libocws/spawn.h` — `run_cmd_async()` wraps any string in `system(cmd + " &")`. Currently safe (all callers pass literals), but fragile by design.
- [ ] `src/cli/ocws-emit.c` — Unknown namespace passes through unsanitized to `sfwbar -R`.
- [ ] `plugins/network/network.c:34` — Interface name from `/proc/net/dev` into `popen()`.
- [ ] `src/daemons/ocws-brokerd.c:401-419,481-483` — Pipes/popen FDs without `O_CLOEXEC`, leaking into child processes.
- [ ] Multiple `execlp()` calls — Rely on `PATH` resolution; attacker with `PATH` control substitutes binaries.

---

Generated: 2026-07-08 by security audit
