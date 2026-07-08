# Security Lessons Learned: Command Injection and Buffer Overflows in C

This document summarizes the security vulnerabilities discovered and patched in the codebase, serving as a lesson and best practice guide for future development.

## 1. Command Injection via `system()`

### The Vulnerability
Many CLI utilities were using the `system()` function to execute shell commands, directly concatenating user input (`argv`) or environment variables into the command string without any sanitization. 

**Example of Vulnerable Code (`ocws-player.c`):**
```c
const char *sec = (argc > 2) ? argv[2] : "10";
char buf[64];
snprintf(buf, sizeof(buf), "seek +%ss", sec);
// Inside run_playerctl: snprintf(cmd, sizeof(cmd), "playerctl %s", buf); system(cmd);
```
If an attacker or malicious script provided crafted arguments, they could execute arbitrary shell commands. For example, running `ocws-player seek-forward "10; rm -rf /"` would execute the destructive command because it is passed directly to the shell (`/bin/sh`).

### The Fix
To eliminate this vulnerability, the insecure `system()` executions must be replaced with robust `fork()` + `execlp()` / `execvp()` calls. `exec`-family functions execute binaries directly without invoking a shell wrapper, eliminating shell-based injection entirely.

**Example of Safe Code:**
```c
pid_t pid = fork();
if (pid == 0) {
    // Arguments are strictly treated as positional parameters, not shell commands
    execlp("playerctl", "playerctl", "seek", buf, NULL);
    exit(1);
}
waitpid(pid, NULL, 0);
```

## 2. Environment Variable Injection

### The Vulnerability
In `ocws-style.c`, the `$HOME` environment variable was used to construct a directory path that was passed to a `system()` call.
```c
const char* home = getenv("HOME");
char mkdir_cmd[600];
snprintf(mkdir_cmd, sizeof(mkdir_cmd), "mkdir -p %s/.config/ocws", home);
system(mkdir_cmd); // VULNERABLE!
```
If the `$HOME` variable was manipulated (e.g., `HOME="; malicious_payload;"`), it would trigger a command injection.

### The Fix
Avoid using `system()` for standard file operations like creating a directory. Instead, use native POSIX system calls like `mkdir()`, or securely fork a process without invoking the shell.

**Example of Safe Code:**
```c
pid_t pid = fork();
if (pid == 0) {
    execlp("mkdir", "mkdir", "-p", output_dir, NULL);
    exit(1);
}
waitpid(pid, NULL, 0);
```

## 3. Buffer Overflows (Unbounded String Operations)

### The Vulnerability
There were instances of `strcpy` and `strcat` used to copy data into fixed-size character arrays without checking if the source string exceeds the destination array's capacity. 

**Example of Vulnerable Code (`ocws-network-bandwidth.c`):**
```c
strcpy(daily_stats[daily_count].date_str, cur_date);
strcpy(daily_stats[daily_count].name, current[i].name);
```

### The Fix
Always use bounded string operations such as `strncpy` and `strncat`, or use `snprintf`. Ensure the string is always null-terminated.

**Example of Safe Code:**
```c
strncpy(daily_stats[daily_count].date_str, cur_date, sizeof(daily_stats[daily_count].date_str) - 1);
strncpy(daily_stats[daily_count].name, current[i].name, sizeof(daily_stats[daily_count].name) - 1);
```

## Summary of Best Practices
1. **Never use `system()` with unsanitized dynamic input.**
2. **Use `fork()` and `execvp()`/`execlp()`** instead of `system()` when calling external programs. This treats arguments strictly as data, not as executable shell code.
3. **Avoid shelling out for basic filesystem tasks.** Use standard POSIX C libraries (`sys/stat.h`, `dirent.h`) to perform actions like creating directories, copying files, or listing directories.
4. **Always use bounded string copy operations** (`strncpy`, `snprintf`) to prevent buffer overflows.
