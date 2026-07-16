/*
 * ocws-sysmon.c — System Monitor (KEY=VALUE output)
 *
 * Outputs CPU, memory, network, wifi, bluetooth, battery, brightness,
 * and temperature stats in KEY=VALUE format for consumption by shell
 * scripts or the panel widget system.
 *
 * Uses shared procfs.h and sysfs.h utilities from libocws.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>

#include "../libocws/procfs.h"
#include "../libocws/sysfs.h"

static void print_cpu(void) {
    ProcCpu cpu;
    if (proc_cpu_read(&cpu) == 0) {
        printf("CPU_IDLE=%ld\n", cpu.idle + cpu.iowait);
        printf("CPU_TOT=%ld\n", cpu.total);
    }
}

static void print_mem(void) {
    ProcMem mem;
    if (proc_mem_read(&mem) == 0) {
        long used = mem.total - mem.available;
        printf("MEM_TOT=%ld\n", mem.total / 1024);
        printf("MEM_USED=%ld\n", used / 1024);
        printf("MEM_PCT=%.1f\n", (used * 100.0) / mem.total);
    }
}

static void print_net(void) {
    /* Sum all non-loopback interfaces */
    FILE *f = fopen("/proc/net/dev", "r");
    if (!f) return;
    char line[512];
    unsigned long long total_rx = 0, total_tx = 0;
    fgets(line, sizeof(line), f); /* skip header */
    fgets(line, sizeof(line), f); /* skip header */
    while (fgets(line, sizeof(line), f)) {
        if (strstr(line, "lo:") || strstr(line, "Inter-") || strstr(line, " face"))
            continue;
        char *colon = strchr(line, ':');
        if (colon) {
            unsigned long long rx, tx;
            if (sscanf(colon + 1, "%llu %*u %*u %*u %*u %*u %*u %*u %llu", &rx, &tx) == 2) {
                total_rx += rx;
                total_tx += tx;
            }
        }
    }
    fclose(f);
    printf("NET_RX=%llu\n", total_rx);
    printf("NET_TX=%llu\n", total_tx);
}

static void print_wifi(void) {
    DIR *d = opendir("/sys/class/net");
    if (!d) return;
    struct dirent *dir;
    while ((dir = readdir(d)) != NULL) {
        if (dir->d_name[0] == '.') continue;
        char path[256];
        snprintf(path, sizeof(path), "/sys/class/net/%s/wireless", dir->d_name);
        if (access(path, F_OK) == 0) {
            snprintf(path, sizeof(path), "/sys/class/net/%s/operstate", dir->d_name);
            FILE *f = fopen(path, "r");
            if (f) {
                char state[64];
                if (fscanf(f, "%63s", state) == 1) {
                    if (strcmp(state, "up") == 0) printf("WIFI_STATE=connected\n");
                    else printf("WIFI_STATE=disconnected\n");
                }
                fclose(f);
            }
            break;
        }
    }
    closedir(d);
}

static void print_bluetooth(void) {
    DIR *d = opendir("/sys/class/rfkill");
    if (!d) return;
    struct dirent *dir;
    while ((dir = readdir(d)) != NULL) {
        if (strncmp(dir->d_name, "rfkill", 6) != 0) continue;
        char path[256], type[64] = {0};
        snprintf(path, sizeof(path), "/sys/class/rfkill/%s/type", dir->d_name);
        FILE *f = fopen(path, "r");
        if (f) { fscanf(f, "%63s", type); fclose(f); }

        if (strcmp(type, "bluetooth") == 0) {
            snprintf(path, sizeof(path), "/sys/class/rfkill/%s/state", dir->d_name);
            int state = sysfs_read_int(path, 0);
            printf("BT_STATE=%s\n", state == 1 ? "On" : "Off");
            break;
        }
    }
    closedir(d);
}

static void print_battery(void) {
    char dev[64];
    if (sysfs_find_device("power_supply", "capacity", dev, sizeof(dev)) != 0)
        return;

    /* Only report BAT* devices */
    if (strncmp(dev, "BAT", 3) != 0) return;

    int cap = sysfs_read_device_int("power_supply", dev, "capacity", -1);
    if (cap >= 0) printf("BAT_LVL=%d\n", cap);

    /* Read status */
    char path[256], stat[64] = {0};
    snprintf(path, sizeof(path), "/sys/class/power_supply/%s/status", dev);
    FILE *f = fopen(path, "r");
    if (f) { if (fscanf(f, "%63s", stat) == 1) printf("BAT_STAT=%s\n", stat); fclose(f); }
}

static void print_brightness(void) {
    int max_b = sysfs_read_device_int("backlight", NULL, "max_brightness", 0);
    int cur_b = sysfs_read_device_int("backlight", NULL, "brightness", 0);
    if (max_b > 0) printf("BRIGHTNESS=%d\n", (cur_b * 100) / max_b);
}

static void print_temp(void) {
    int temp = sysfs_read_int("/sys/class/thermal/thermal_zone0/temp", -1);
    if (temp > 0) printf("TEMP=%d\n", temp / 1000);
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;

    print_cpu();
    print_mem();
    print_net();
    print_wifi();
    print_bluetooth();
    print_battery();
    print_brightness();
    print_temp();

    return 0;
}
