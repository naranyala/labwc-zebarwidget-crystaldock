#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>
#include <signal.h>
#include <sys/wait.h>
#include <fcntl.h>

#define RED     "\033[0;31m"
#define GREEN   "\033[0;32m"
#define CYAN    "\033[0;36m"
#define NC      "\033[0m"

void pass(const char *msg) { printf("%s✓%s %s\n", GREEN, NC, msg); }
void fail(const char *msg) { printf("%s✗%s %s\n", RED, NC, msg); exit(1); }

bool check_cmd(const char *cmd) {
    pid_t pid = fork();
    if (pid == 0) {
        int fd = open("/dev/null", O_WRONLY);
        if (fd >= 0) { dup2(fd, 1); dup2(fd, 2); close(fd); }
        execlp("which", "which", cmd, NULL);
        _exit(1);
    }
    if (pid > 0) {
        int status;
        waitpid(pid, &status, 0);
        return WIFEXITED(status) && WEXITSTATUS(status) == 0;
    }
    return false;
}

void lock_screen() {
    if (!check_cmd("swaylock")) {
        fail("swaylock is not installed. Please install it first.");
    }
    
    pid_t pid = fork();
    if (pid == 0) {
        execlp("swaylock", "swaylock",
               "--daemonize",
               "--color", "1e1e2e",
               "--inside-color", "1e1e2e88",
               "--inside-clear-color", "1e1e2e88",
               "--ring-color", "cba6f7",
               "--ring-clear-color", "89b4fa",
               "--ring-wrong-color", "f38ba8",
               "--text-color", "cdd6f4",
               "--line-uses-inside",
               "--key-hl-color", "a6e3a1",
               "--bs-hl-color", "f38ba8",
               "--separator-color", "00000000",
               "--indicator-radius", "60",
               "--indicator-thickness", "6",
               NULL);
        _exit(1);
    } else if (pid > 0) {
        int status;
        waitpid(pid, &status, 0);
        if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
            pass("Screen locked");
        } else {
            fail("Failed to lock screen");
        }
    }
}

void start_daemon(int timeout_lock, int timeout_dpms) {
    if (!check_cmd("swayidle")) {
        fail("swayidle is not installed. Please install it first.");
    }
    
    // Kill existing instances via fork+exec
    pid_t kill_pid = fork();
    if (kill_pid == 0) {
        int fd = open("/dev/null", O_WRONLY);
        if (fd >= 0) { dup2(fd, 1); dup2(fd, 2); close(fd); }
        execlp("killall", "killall", "swayidle", NULL);
        _exit(1);
    } else if (kill_pid > 0) {
        waitpid(kill_pid, NULL, 0);
    }
    
    char exe_path[1024];
    ssize_t len = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
    if (len != -1) {
        exe_path[len] = '\0';
    } else {
        // Fallback if readlink fails
        strcpy(exe_path, "ocws-lock");
    }
    
    char cmd[2048];
    // Example: swayidle -w timeout 300 'ocws-lock lock' timeout 330 'swaymsg "output * dpms off"' resume 'swaymsg "output * dpms on"'
    // For labwc/wlroots, swaymsg might not work for dpms, we use wlr-randr or just rely on compositor specific tools,
    // but swayidle can often use Wayland native DPMS, or we can use wlopm.
    // For universal wlroots compat without swaymsg, wlopm or just lock is safer.
    // Safe: exe_path is from readlink("/proc/self/exe") — binary's own path.

    snprintf(cmd, sizeof(cmd),
        "swayidle -w "
        "timeout %d '%s lock' "
        "timeout %d 'if command -v wlopm >/dev/null; then wlopm --off \\*; elif command -v swaymsg >/dev/null; then swaymsg \"output * dpms off\"; fi' "
        "resume 'if command -v wlopm >/dev/null; then wlopm --on \\*; elif command -v swaymsg >/dev/null; then swaymsg \"output * dpms on\"; fi' "
        "before-sleep '%s lock' &", 
        timeout_lock, exe_path, timeout_dpms, exe_path);
        
    printf("%s→%s Starting swayidle daemon (lock: %ds, sleep: %ds)...\n", CYAN, NC, timeout_lock, timeout_dpms);
    
    pid_t pid = fork();
    if (pid == 0) {
        execlp("/bin/sh", "sh", "-c", cmd, NULL);
        _exit(1);
    } else if (pid > 0) {
        int status;
        waitpid(pid, &status, 0);
        if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
            pass("Idle daemon started in background");
        } else {
            fail("Failed to start idle daemon");
        }
    }
}

void stop_daemon() {
    pid_t pid = fork();
    if (pid == 0) {
        int fd = open("/dev/null", O_WRONLY);
        if (fd >= 0) { dup2(fd, 1); dup2(fd, 2); close(fd); }
        execlp("killall", "killall", "swayidle", NULL);
        _exit(1);
    } else if (pid > 0) {
        int status;
        waitpid(pid, &status, 0);
        if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
            pass("Idle daemon stopped");
        } else {
            printf("No idle daemon running\n");
        }
    }
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    const char *mode = "lock";
    if (argc > 1) mode = argv[1];
    
    if (strcmp(mode, "lock") == 0) {
        lock_screen();
    } else if (strcmp(mode, "daemon") == 0) {
        int timeout_lock = 300; // 5 mins
        int timeout_dpms = 330; // 5.5 mins
        
        if (argc > 2) {
            int v = atoi(argv[2]);
            if (v > 0) timeout_lock = v;
        }
        if (argc > 3) {
            int v = atoi(argv[3]);
            if (v > 0) timeout_dpms = v;
        }
        
        start_daemon(timeout_lock, timeout_dpms);
    } else if (strcmp(mode, "stop") == 0) {
        stop_daemon();
    } else {
        printf("\nOCWS Lock & Idle Manager\n\nUsage: %s <command>\n\nCommands:\n", argv[0]);
        printf("  lock                          Lock the screen now (default)\n");
        printf("  daemon [lock_sec] [dpms_sec]  Start idle daemon (default 300s 330s)\n");
        printf("  stop                          Stop the idle daemon\n\n");
    }
    
    return 0;
}
