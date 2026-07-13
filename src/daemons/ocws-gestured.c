/*
 * ocws-gestured.c — Touchpad Gesture Daemon
 *
 * Reads multitouch evdev events from the touchpad and executes
 * labwc actions for 3-finger and 4-finger swipes.
 *
 * Features:
 *   - Auto-detects touchpad device from /proc/bus/input/devices
 *   - Tracks per-slot finger state (MT Protocol B)
 *   - Configurable swipe threshold and gesture-to-action mapping
 *   - Executes actions via fork()+execlp() (no shell)
 *   - PID file, signal handling, verbose logging (follows OCWS daemon conventions)
 *
 * Build: gcc -O2 -o ocws-gestured src/daemons/ocws-gestured.c
 * Usage: ocws-gestured [--device /dev/input/eventN] [--verbose] [--threshold 150]
 *
 * Default gesture bindings:
 *   3-finger swipe left  → wlrctl tiling right
 *   3-finger swipe right → wlrctl tiling left
 *   3-finger swipe up    → wlrctl tiling down
 *   3-finger swipe down  → wlrctl tiling up
 *   4-finger swipe left  → wlrctl workspace next
 *   4-finger swipe right → wlrctl workspace prev
 *   4-finger swipe up    → (custom)
 *   4-finger swipe down  → (custom)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#include <dirent.h>
#include <stdarg.h>
#include <time.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <linux/input.h>
#include <linux/input-event-codes.h>

/* ============================================================
 * Configuration
 * ============================================================ */

#define VERSION           "1.0.0"
#define PID_FILE          "/tmp/ocws-gestured.pid"
#define LOG_FILE          "/tmp/ocws-gestured.log"
#define MAX_SLOTS         10
#define SWIPE_THRESHOLD   150    /* pixels minimum for a swipe */
#define GESTURE_COOLDOWN  300    /* ms between gesture executions */
#define SLOT_IDLE         (-1)

typedef struct {
    int x, y;
    int active;         /* 1 = finger down, 0 = finger up */
    int start_x, start_y;
    int has_start;      /* 1 = start position recorded */
} FingerSlot;

/* State */
static FingerSlot slots[MAX_SLOTS];
static int active_fingers = 0;
static int current_slot = 0;
static struct timeval last_gesture_time = {0, 0};

/* Config */
static int verbose = 0;
static int swipe_threshold = SWIPE_THRESHOLD;
static const char *device_path = NULL;
static volatile sig_atomic_t running = 1;

/* ============================================================
 * Gesture-to-action mapping (edit these to customize)
 * ============================================================ */

typedef struct {
    int fingers;
    int dx, dy;         /* direction: +1, -1, or 0 */
    const char *cmd;
    const char *desc;
} GestureBinding;

static GestureBinding bindings[] = {
    /* 3-finger swipes — window tiling via labwc actions */
    { 3, -1,  0, "sh -c 'swaymsg tiling left 2>/dev/null || true'",  "3-finger swipe left  → tile left"   },
    { 3,  1,  0, "sh -c 'swaymsg tiling right 2>/dev/null || true'", "3-finger swipe right → tile right"  },
    { 3,  0, -1, "sh -c 'swaymsg tiling up 2>/dev/null || true'",    "3-finger swipe up    → tile up"     },
    { 3,  0,  1, "sh -c 'swaymsg tiling down 2>/dev/null || true'",  "3-finger swipe down  → tile down"   },

    /* 4-finger swipes — workspace switching */
    { 4, -1,  0, "sh -c 'swaymsg workspace next_on_output 2>/dev/null || actions.sh workspace next'", "4-finger swipe left  → next workspace" },
    { 4,  1,  0, "sh -c 'swaymsg workspace prev_on_output 2>/dev/null || actions.sh workspace prev'", "4-finger swipe right → prev workspace" },
    { 4,  0, -1, "sh -c 'actions.sh workspace first'", "4-finger swipe up    → first workspace" },
    { 4,  0,  1, "sh -c 'actions.sh workspace last'",  "4-finger swipe down  → last workspace"  },
};

#define NUM_BINDINGS (sizeof(bindings) / sizeof(bindings[0]))

/* ============================================================
 * Logging
 * ============================================================ */

static FILE *log_fp = NULL;

static void log_init(void) {
    log_fp = fopen(LOG_FILE, "a");
}

static void log_msg(const char *fmt, ...) {
    if (!log_fp) return;
    va_list args;
    va_start(args, fmt);
    time_t now = time(NULL);
    struct tm *t = localtime(&now);
    fprintf(log_fp, "[%02d:%02d:%02d] ", t->tm_hour, t->tm_min, t->tm_sec);
    vfprintf(log_fp, fmt, args);
    fprintf(log_fp, "\n");
    fflush(log_fp);
    va_end(args);
}

static void log_close(void) {
    if (log_fp) { fclose(log_fp); log_fp = NULL; }
}

/* ============================================================
 * Signal handling
 * ============================================================ */

static void signal_handler(int sig) {
    (void)sig;
    running = 0;
}

static void setup_signals(void) {
    struct sigaction sa;
    sa.sa_handler = signal_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);
}

/* ============================================================
 * PID file (follows OCWS daemon.h convention)
 * ============================================================ */

static void write_pid(void) {
    FILE *f = fopen(PID_FILE, "w");
    if (f) { fprintf(f, "%d\n", getpid()); fclose(f); }
}

static void remove_pid(void) { unlink(PID_FILE); }

/* ============================================================
 * Touchpad auto-detection
 * ============================================================ */

static char *find_touchpad(void) {
    FILE *f = fopen("/proc/bus/input/devices", "r");
    if (!f) return NULL;

    static char evdev_path[64] = {0};
    char line[512];
    int in_touchpad = 0;
    int has_abs = 0;
    int has_prop = 0;

    while (fgets(line, sizeof(line), f)) {
        /* New device block */
        if (line[0] == 'I') {
            /* Check previous device: touchpad = has ABS events + PROP flag */
            if (in_touchpad && has_abs && has_prop) {
                fclose(f);
                return evdev_path;
            }
            in_touchpad = 0;
            has_abs = 0;
            has_prop = 0;
        }

        /* Check for touchpad in name */
        if (line[0] == 'N') {
            char *name = strstr(line, "Name=\"");
            if (name) {
                name += 6;
                if (strstr(name, "Touchpad") || strstr(name, "touchpad") ||
                    strstr(name, "TrackPoint") || strstr(name, "ETPS") ||
                    strstr(name, "Synaptics") || strstr(name, "ELAN") ||
                    strstr(name, "SynPS/2") || strstr(name, "AlpsPS/2") ||
                    strstr(name, "TPPS/2") || strstr(name, "gxtp")) {
                    in_touchpad = 1;
                }
            }
        }

        /* Check for ABS events (B: ABS=...) — indicates absolute positioning */
        if (line[0] == 'B' && strncmp(line, "B: ABS=", 7) == 0) {
            char *hex = line + 7;
            /* Any non-zero ABS value means it has absolute axes */
            if (strtoul(hex, NULL, 16) != 0)
                has_abs = 1;
        }

        /* Check for PROP flag (B: PROP=5 indicates INPUT_PROP_POINTER/touchpad) */
        if (line[0] == 'B' && strncmp(line, "B: PROP=", 8) == 0) {
            int prop = atoi(line + 8);
            if (prop != 0)  /* PROP != 0 means it's a pointing device */
                has_prop = 1;
        }

        /* Extract event number from H: Handlers line */
        if (line[0] == 'H' && in_touchpad) {
            char *evt = strstr(line, "event");
            if (evt) {
                int num = atoi(evt + 5);
                snprintf(evdev_path, sizeof(evdev_path), "/dev/input/event%d", num);
            }
        }
    }

    fclose(f);

    /* Check last device in file */
    if (in_touchpad && has_abs && has_prop && evdev_path[0])
        return evdev_path;

    return NULL;
}

/* ============================================================
 * Gesture detection
 * ============================================================ */

static void update_slot_position(int slot, int x, int y) {
    if (slot < 0 || slot >= MAX_SLOTS) return;

    if (!slots[slot].active) {
        /* New finger down */
        slots[slot].active = 1;
        slots[slot].start_x = x;
        slots[slot].start_y = y;
        slots[slot].has_start = 1;
        active_fingers++;
        if (verbose) log_msg("Finger %d down at (%d,%d) [total: %d]", slot, x, y, active_fingers);
    }

    slots[slot].x = x;
    slots[slot].y = y;
}

static void on_finger_up(int slot) {
    if (slot < 0 || slot >= MAX_SLOTS) return;
    if (slots[slot].active) {
        slots[slot].active = 0;
        slots[slot].has_start = 0;
        active_fingers--;
        if (verbose) log_msg("Finger %d up [total: %d]", slot, active_fingers);
    }
}

static void check_gesture(void) {
    /* Need at least 3 fingers for a gesture */
    if (active_fingers < 3) return;

    /* Cooldown check */
    struct timeval now;
    gettimeofday(&now, NULL);
    long elapsed_ms = (now.tv_sec - last_gesture_time.tv_sec) * 1000 +
                      (now.tv_usec - last_gesture_time.tv_usec) / 1000;
    if (elapsed_ms < GESTURE_COOLDOWN) return;

    /* Find the dominant swipe direction across active fingers */
    int total_dx = 0, total_dy = 0;
    int counted = 0;

    for (int i = 0; i < MAX_SLOTS; i++) {
        if (!slots[i].active || !slots[i].has_start) continue;
        int dx = slots[i].x - slots[i].start_x;
        int dy = slots[i].y - slots[i].start_y;
        total_dx += dx;
        total_dy += dy;
        counted++;
    }

    if (counted < 3) return;

    /* Average displacement */
    int avg_dx = total_dx / counted;
    int avg_dy = total_dy / counted;

    /* Determine dominant axis */
    int adx = abs(avg_dx);
    int ady = abs(avg_dy);

    if (adx < swipe_threshold && ady < swipe_threshold) return; /* Not enough movement */

    int dir_x = 0, dir_y = 0;
    if (adx > ady) {
        dir_x = (avg_dx > 0) ? 1 : -1;
    } else {
        dir_y = (avg_dy > 0) ? 1 : -1;
    }

    /* Match against bindings */
    for (size_t i = 0; i < NUM_BINDINGS; i++) {
        if (bindings[i].fingers == active_fingers &&
            bindings[i].dx == dir_x &&
            bindings[i].dy == dir_y) {

            log_msg("Gesture: %s → %s", bindings[i].desc, bindings[i].cmd);

            /* Execute action via fork+system (commands may contain shell syntax) */
            pid_t pid = fork();
            if (pid == 0) {
                /* Redirect output to /dev/null */
                int devnull = open("/dev/null", O_WRONLY);
                if (devnull >= 0) {
                    dup2(devnull, STDOUT_FILENO);
                    dup2(devnull, STDERR_FILENO);
                    close(devnull);
                }
                system(bindings[i].cmd);
                _exit(0);
            } else if (pid > 0) {
                /* Don't wait — fire and forget for responsiveness */
            }

            gettimeofday(&last_gesture_time, NULL);

            /* Reset all finger start positions to prevent re-triggering */
            for (int j = 0; j < MAX_SLOTS; j++) {
                slots[j].has_start = 0;
                if (slots[j].active) {
                    slots[j].start_x = slots[j].x;
                    slots[j].start_y = slots[j].y;
                    slots[j].has_start = 1;
                }
            }
            return;
        }
    }
}

/* ============================================================
 * Evdev read loop
 * ============================================================ */

static int run_loop(int fd) {
    struct input_event ev;
    int current_x = 0, current_y = 0;

    while (running) {
        /* Use select() for timeout so we can check `running` periodically */
        fd_set fds;
        FD_ZERO(&fds);
        FD_SET(fd, &fds);

        struct timeval tv;
        tv.tv_sec = 0;
        tv.tv_usec = 100000; /* 100ms timeout */

        int ret = select(fd + 1, &fds, NULL, NULL, &tv);
        if (ret < 0) {
            if (errno == EINTR) continue;
            log_msg("select error: %s", strerror(errno));
            break;
        }
        if (ret == 0) continue; /* timeout, re-check running */

        ssize_t n = read(fd, &ev, sizeof(ev));
        if (n < 0) {
            if (errno == EINTR) continue;
            log_msg("read error: %s", strerror(errno));
            break;
        }
        if (n != sizeof(ev)) continue;

        switch (ev.type) {
        case EV_ABS:
            if (ev.code == ABS_MT_SLOT) {
                current_slot = ev.value;
                if (current_slot >= 0 && current_slot < MAX_SLOTS) {
                    current_x = slots[current_slot].x;
                    current_y = slots[current_slot].y;
                }
            } else if (ev.code == ABS_MT_TRACKING_ID) {
                if (ev.value == -1) {
                    /* Finger up */
                    on_finger_up(current_slot);
                }
            } else if (ev.code == ABS_MT_POSITION_X) {
                if (current_slot >= 0 && current_slot < MAX_SLOTS)
                    current_x = ev.value;
            } else if (ev.code == ABS_MT_POSITION_Y) {
                if (current_slot >= 0 && current_slot < MAX_SLOTS)
                    current_y = ev.value;
            }
            break;

        case EV_SYN:
            if (ev.code == SYN_REPORT) {
                /* Update slot position with accumulated x/y */
                if (current_slot >= 0 && current_slot < MAX_SLOTS)
                    update_slot_position(current_slot, current_x, current_y);
                check_gesture();
            }
            break;

        case EV_KEY:
            /* BTN_TOOL_FINGER etc. — used by some drivers for finger count */
            break;
        }
    }

    return 0;
}

/* ============================================================
 * Usage / argument parsing
 * ============================================================ */

static void usage(const char *prog) {
    printf("ocws-gestured %s — Touchpad Gesture Daemon\n\n", VERSION);
    printf("Usage: %s [options]\n\n", prog);
    printf("Options:\n");
    printf("  --device PATH    Touchpad device (default: auto-detect)\n");
    printf("  --threshold N    Swipe threshold in pixels (default: %d)\n", SWIPE_THRESHOLD);
    printf("  --verbose        Log gesture events\n");
    printf("  --help           Show this help\n\n");
    printf("Gesture bindings:\n");
    for (size_t i = 0; i < NUM_BINDINGS; i++) {
        printf("  %s\n", bindings[i].desc);
    }
}

/* ============================================================
 * Main
 * ============================================================ */

int main(int argc, char **argv) {
    umask(0077);

    /* Parse arguments */
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--device") == 0 && i + 1 < argc) {
            device_path = argv[++i];
        } else if (strcmp(argv[i], "--threshold") == 0 && i + 1 < argc) {
            swipe_threshold = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--verbose") == 0) {
            verbose = 1;
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            usage(argv[0]);
            return 0;
        }
    }

    setup_signals();
    log_init();

    /* Find touchpad device */
    if (!device_path) {
        device_path = find_touchpad();
        if (!device_path) {
            log_msg("No touchpad found. Use --device to specify manually.");
            fprintf(stderr, "No touchpad found. Use --device to specify manually.\n");
            return 1;
        }
    }

    log_msg("ocws-gestured %s starting", VERSION);
    log_msg("Device: %s", device_path);
    log_msg("Threshold: %d px", swipe_threshold);

    /* Open device */
    int fd = open(device_path, O_RDONLY | O_NONBLOCK);
    if (fd < 0) {
        log_msg("Failed to open %s: %s", device_path, strerror(errno));
        fprintf(stderr, "Failed to open %s: %s\n", device_path, strerror(errno));
        return 1;
    }

    /* Verify it's a multitouch device — use enough words for ABS_MT_POSITION_X (53) */
    unsigned long bits[(ABS_MT_POSITION_X / (sizeof(unsigned long) * 8)) + 1] = {0};
    if (ioctl(fd, EVIOCGBIT(EV_ABS, sizeof(bits)), bits) < 0 ||
        !(bits[ABS_MT_POSITION_X / (sizeof(unsigned long) * 8)] &
          (1UL << (ABS_MT_POSITION_X % (sizeof(unsigned long) * 8))))) {
        log_msg("Device %s does not support multitouch", device_path);
        fprintf(stderr, "Device %s does not support multitouch\n", device_path);
        close(fd);
        return 1;
    }

    /* Get device name for logging */
    char devname[256] = "unknown";
    ioctl(fd, EVIOCGNAME(sizeof(devname)), devname);
    log_msg("Device name: %s", devname);

    write_pid();
    log_msg("Listening for gestures...");

    /* Print bindings */
    for (size_t i = 0; i < NUM_BINDINGS; i++) {
        log_msg("  %s", bindings[i].desc);
    }

    int rc = run_loop(fd);

    close(fd);
    remove_pid();
    log_msg("ocws-gestured shutting down");
    log_close();

    return rc;
}
