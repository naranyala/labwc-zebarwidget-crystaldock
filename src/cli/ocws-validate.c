#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>
#include <sys/stat.h>
#include <pwd.h>

#define RED     "\033[0;31m"
#define GREEN   "\033[0;32m"
#define YELLOW  "\033[1;33m"
#define CYAN    "\033[0;36m"
#define BOLD    "\033[1m"
#define NC      "\033[0m"

int pass_cnt = 0, warn_cnt = 0, fail_cnt = 0;

void pass(const char *msg) { printf("  %sPASS%s %s\n", GREEN, NC, msg); pass_cnt++; }
void warn(const char *msg) { printf("  %sWARN%s %s\n", YELLOW, NC, msg); warn_cnt++; }
void fail(const char *msg) { printf("  %sFAIL%s %s\n", RED, NC, msg); fail_cnt++; }

bool check_cmd(const char *cmd) {
    char buf[256];
    snprintf(buf, sizeof(buf), "command -v %s >/dev/null 2>&1", cmd);
    return system(buf) == 0;
}

bool check_ldd(const char *bin_path) {
    char buf[512];
    snprintf(buf, sizeof(buf), "ldd %s 2>/dev/null | grep -q 'not found'", bin_path);
    // If grep finds 'not found', system returns 0 (meaning missing libs)
    return system(buf) != 0;
}

bool file_exists(const char *path) {
    struct stat st;
    return stat(path, &st) == 0;
}

bool is_executable(const char *path) {
    struct stat st;
    if (stat(path, &st) == 0) {
        return (st.st_mode & S_IXUSR) != 0;
    }
    return false;
}

void get_home(char *home, size_t size) {
    const char *h = getenv("HOME");
    if (!h) h = getpwuid(getuid())->pw_dir;
    snprintf(home, size, "%s", h);
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    printf("%s=== OCWS Deep Validation & Healthcheck ===%s\n\n", BOLD, NC);
    
    char home[256];
    get_home(home, sizeof(home));
    
    char local_bin[512];
    snprintf(local_bin, sizeof(local_bin), "%s/.local/bin", home);

    // 1. Core Utilities
    printf("%s[1/6] Core System Utilities%s\n", CYAN, NC);
    const char *core_bins[] = {"labwc", "zigshell-cairo-pango", "fuzzel", "foot", "jq", "awk", "sed"};
    for (int i = 0; i < 7; i++) {
        if (check_cmd(core_bins[i])) {
            char msg[256];
            snprintf(msg, sizeof(msg), "Found %s", core_bins[i]);
            pass(msg);
        } else {
            char msg[256];
            snprintf(msg, sizeof(msg), "Missing core utility: %s", core_bins[i]);
            fail(msg);
        }
    }
    printf("\n");

    // 2. Multimedia & Display Utils
    printf("%s[2/6] Multimedia & Display Utilities%s\n", CYAN, NC);
    const char *mm_bins[] = {"wpctl", "playerctl", "wlr-randr", "grim", "slurp", "wl-copy", "cliphist"};
    for (int i = 0; i < 7; i++) {
        if (check_cmd(mm_bins[i])) {
            char msg[256];
            snprintf(msg, sizeof(msg), "Found %s", mm_bins[i]);
            pass(msg);
        } else {
            char msg[256];
            snprintf(msg, sizeof(msg), "Missing utility: %s (some features will be degraded)", mm_bins[i]);
            warn(msg);
        }
    }
    printf("\n");

    // 3. OCWS Compiled Binaries & Library Links
    printf("%s[3/6] OCWS Compiled Binaries (Library Link Check)%s\n", CYAN, NC);
    const char *ocws_bins[] = {
        "ocws-sysmon", "ocws-clip", "ocws-shot", "ocws-lock", 
        "ocws-kv", "ocws-brightness", "ocws-volume", "ocws-notify", 
        "ocws-wallpaper", "ocws-color", "ocws-emit", "ocws-player", 
        "ocws-state", "ocws-network-bandwidth", "ocws-live-bg", 
        "ocws-osd-notify", "ocws-hypertile", "ocws-settings", "ocws"
    };
    
    int num_ocws_bins = sizeof(ocws_bins) / sizeof(ocws_bins[0]);
    for (int i = 0; i < num_ocws_bins; i++) {
        char bin_path[512];
        snprintf(bin_path, sizeof(bin_path), "%s/%s", local_bin, ocws_bins[i]);
        
        // Also check /usr/local/bin or system PATH if not in local_bin
        char check_path[512];
        if (file_exists(bin_path)) {
            snprintf(check_path, sizeof(check_path), "%s", bin_path);
        } else {
            snprintf(check_path, sizeof(check_path), "%s", ocws_bins[i]); 
        }

        if (check_cmd(check_path) || file_exists(bin_path)) {
            if (check_ldd(check_path)) {
                char msg[256];
                snprintf(msg, sizeof(msg), "%s installed and all shared libraries found.", ocws_bins[i]);
                pass(msg);
            } else {
                char msg[256];
                snprintf(msg, sizeof(msg), "%s is MISSING shared libraries! Run 'ldd %s' to debug.", ocws_bins[i], check_path);
                fail(msg);
            }
        } else {
            char msg[256];
            snprintf(msg, sizeof(msg), "%s not found (Needs to be compiled/installed).", ocws_bins[i]);
            warn(msg);
        }
    }
    printf("\n");

    // 4. Configuration Directories
    printf("%s[4/6] Configuration Architecture%s\n", CYAN, NC);
    const char *dirs[] = {".config/ocws", ".config/labwc", ".config/ocws/plugins", ".config/ocws/state", ".config/ocws/cover-art"};
    for (int i = 0; i < 5; i++) {
        char dir_path[512];
        snprintf(dir_path, sizeof(dir_path), "%s/%s", home, dirs[i]);
        if (file_exists(dir_path)) {
            char msg[256];
            snprintf(msg, sizeof(msg), "Directory OK: ~/%s", dirs[i]);
            pass(msg);
        } else {
            char msg[256];
            snprintf(msg, sizeof(msg), "Missing directory: ~/%s", dirs[i]);
            fail(msg);
        }
    }
    printf("\n");

    // 5. Essential Fonts
    printf("%s[5/6] Fonts & Assets%s\n", CYAN, NC);
    if (check_cmd("fc-match")) {
        char buf[256];
        FILE *fp = popen("fc-match 'Noto Sans'", "r");
        if (fp && fgets(buf, sizeof(buf), fp)) {
            if (strstr(buf, "NotoSans")) {
                pass("Font 'Noto Sans' found");
            } else {
                warn("Font 'Noto Sans' missing or falling back to a different font!");
            }
            pclose(fp);
        }
        
        fp = popen("fc-match 'Material Design Icons'", "r");
        if (fp && fgets(buf, sizeof(buf), fp)) {
            if (strstr(buf, "MaterialDesignIcons") || strstr(buf, "materialdesignicons")) {
                pass("Font 'Material Design Icons' found");
            } else {
                warn("Icon font 'Material Design Icons' missing! UI icons may render as boxes.");
            }
            pclose(fp);
        }
    } else {
        warn("fc-match not installed, skipping font checks.");
    }
    printf("\n");

    // 6. Running Services
    printf("%s[6/6] Runtime Services%s\n", CYAN, NC);
    const char *services[] = {"labwc", "zigshell-cairo-pango"};
    for (int i = 0; i < 2; i++) {
        char cmd[256];
        snprintf(cmd, sizeof(cmd), "pgrep -x %s >/dev/null", services[i]);
        if (system(cmd) == 0) {
            char msg[256];
            snprintf(msg, sizeof(msg), "%s is actively running", services[i]);
            pass(msg);
        } else {
            char msg[256];
            snprintf(msg, sizeof(msg), "%s is NOT running", services[i]);
            warn(msg);
        }
    }
    printf("\n");

    printf("%s=== Validation Summary ===%s\n", BOLD, NC);
    printf("  %sPASS: %d%s\n", GREEN, pass_cnt, NC);
    printf("  %sWARN: %d%s\n", YELLOW, warn_cnt, NC);
    printf("  %sFAIL: %d%s\n\n", RED, fail_cnt, NC);

    if (fail_cnt > 0) {
        printf("%sSome critical checks failed. The environment is unstable.%s\n", RED, NC);
        return 1;
    } else if (warn_cnt > 0) {
        printf("%sWarnings found. OCWS will run, but features may be missing.%s\n", YELLOW, NC);
        return 0;
    } else {
        printf("%sAll systems nominal. Environment is perfectly healthy.%s\n", GREEN, NC);
        return 0;
    }
}
