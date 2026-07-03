/* providers/system.c - System data providers
 *
 * Reads system information from:
 * - /proc/stat (CPU)
 * - /proc/meminfo (Memory)
 * - /sys/class/power_supply/ (Battery)
 * - /proc/net/ (Network)
 * - wpctl (Volume)
 * - nmcli (Network details)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <dirent.h>
#include <unistd.h>
#include <sys/stat.h>
#include "widget.h"

/* ============================================================================
 * CPU Provider
 * ============================================================================ */

static uint64_t prev_idle = 0;
static uint64_t prev_total = 0;

int provider_update_cpu(widget_provider_t *provider) {
    FILE *f = fopen("/proc/stat", "r");
    if (!f) return -1;

    char line[256];
    if (fgets(line, sizeof(line), f)) {
        uint64_t user, nice, system, idle, iowait, irq, softirq, steal;
        if (sscanf(line, "cpu %lu %lu %lu %lu %lu %lu %lu %lu",
                   &user, &nice, &system, &idle, &iowait, &irq, &softirq, &steal) == 8) {

            uint64_t total = user + nice + system + idle + iowait + irq + softirq + steal;
            uint64_t idle_time = idle + iowait;

            if (prev_total > 0) {
                uint64_t total_diff = total - prev_total;
                uint64_t idle_diff = idle_time - prev_idle;

                if (total_diff > 0) {
                    provider->data.cpu.usage = 100.0 * (1.0 - (double)idle_diff / total_diff);
                }
            }

            prev_idle = idle_time;
            prev_total = total;
        }
    }

    fclose(f);

    /* Get core count */
    FILE *cpuinfo = fopen("/proc/cpuinfo", "r");
    if (cpuinfo) {
        int cores = 0;
        char line[256];
        while (fgets(line, sizeof(line), cpuinfo)) {
            if (strncmp(line, "processor", 9) == 0) {
                cores++;
            }
        }
        provider->data.cpu.cores = cores > 0 ? cores : 1;
        fclose(cpuinfo);
    }

    /* Get temperature if available */
    FILE *temp = fopen("/sys/class/thermal/thermal_zone0/temp", "r");
    if (temp) {
        int millideg;
        if (fscanf(temp, "%d", &millideg) == 1) {
            provider->data.cpu.temperature = millideg / 1000.0;
        }
        fclose(temp);
    }

    return 0;
}

/* ============================================================================
 * Memory Provider
 * ============================================================================ */

int provider_update_memory(widget_provider_t *provider) {
    FILE *f = fopen("/proc/meminfo", "r");
    if (!f) return -1;

    uint64_t mem_total = 0, mem_free = 0, mem_available = 0;
    uint64_t swap_total = 0, swap_free = 0;
    char line[256];

    while (fgets(line, sizeof(line), f)) {
        if (sscanf(line, "MemTotal: %lu kB", &mem_total) == 1) continue;
        if (sscanf(line, "MemFree: %lu kB", &mem_free) == 1) continue;
        if (sscanf(line, "MemAvailable: %lu kB", &mem_available) == 1) continue;
        if (sscanf(line, "SwapTotal: %lu kB", &swap_total) == 1) continue;
        if (sscanf(line, "SwapFree: %lu kB", &swap_free) == 1) continue;
    }
    fclose(f);

    if (mem_total > 0) {
        uint64_t used = mem_total - mem_available;
        provider->data.memory.total = mem_total / 1024;  /* Convert to MB */
        provider->data.memory.used = used / 1024;
        provider->data.memory.free = mem_available / 1024;
        provider->data.memory.usage = 100.0 * used / mem_total;
    }

    if (swap_total > 0) {
        uint64_t swap_used = swap_total - swap_free;
        provider->data.memory.swap_usage = 100.0 * swap_used / swap_total;
    }

    return 0;
}

/* ============================================================================
 * Network Provider
 * ============================================================================ */

int provider_update_network(widget_provider_t *provider) {
    /* Check if connected via /sys/class/net */
    DIR *dir = opendir("/sys/class/net");
    if (!dir) return -1;

    struct dirent *entry;
    provider->data.network.connected = false;
    provider->data.network.is_wifi = false;
    provider->data.network.is_ethernet = false;

    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] == '.') continue;

        char path[256];
        snprintf(path, sizeof(path), "/sys/class/net/%s/operstate", entry->d_name);

        FILE *f = fopen(path, "r");
        if (f) {
            char state[16];
            if (fgets(state, sizeof(state), f)) {
                state[strcspn(state, "\n")] = 0;
                if (strcmp(state, "up") == 0) {
                    provider->data.network.connected = true;
                    strncpy(provider->data.network.interface, entry->d_name,
                            sizeof(provider->data.network.interface) - 1);

                    /* Check if wireless */
                    char wireless_path[256];
                    snprintf(wireless_path, sizeof(wireless_path),
                             "/sys/class/net/%s/wireless", entry->d_name);
                    struct stat st;
                    if (stat(wireless_path, &st) == 0) {
                        provider->data.network.is_wifi = true;
                    } else {
                        provider->data.network.is_ethernet = true;
                    }
                }
            }
            fclose(f);
        }
    }
    closedir(dir);

    /* Try to get SSID via nmcli */
    if (provider->data.network.is_wifi) {
        FILE *p = popen("nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2", "r");
        if (p) {
            char ssid[64];
            if (fgets(ssid, sizeof(ssid), p)) {
                ssid[strcspn(ssid, "\n")] = 0;
                strncpy(provider->data.network.ssid, ssid,
                        sizeof(provider->data.network.ssid) - 1);
            }
            pclose(p);
        }
    }

    return 0;
}

/* ============================================================================
 * Battery Provider
 * ============================================================================ */

int provider_update_battery(widget_provider_t *provider) {
    /* Find battery in /sys/class/power_supply/ */
    DIR *dir = opendir("/sys/class/power_supply");
    if (!dir) {
        provider->data.battery.is_present = false;
        return 0;
    }

    struct dirent *entry;
    provider->data.battery.is_present = false;

    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] == '.') continue;

        char path[256];
        snprintf(path, sizeof(path), "/sys/class/power_supply/%s/type", entry->d_name);

        FILE *f = fopen(path, "r");
        if (f) {
            char type[32];
            if (fgets(type, sizeof(type), f)) {
                type[strcspn(type, "\n")] = 0;
                if (strcmp(type, "Battery") == 0) {
                    provider->data.battery.is_present = true;

                    /* Read capacity */
                    char cap_path[256];
                    snprintf(cap_path, sizeof(cap_path),
                             "/sys/class/power_supply/%s/capacity", entry->d_name);
                    FILE *cap_f = fopen(cap_path, "r");
                    if (cap_f) {
                        int capacity;
                        if (fscanf(cap_f, "%d", &capacity) == 1) {
                            provider->data.battery.charge_percent = capacity;
                        }
                        fclose(cap_f);
                    }

                    /* Read status */
                    char status_path[256];
                    snprintf(status_path, sizeof(status_path),
                             "/sys/class/power_supply/%s/status", entry->d_name);
                    FILE *status_f = fopen(status_path, "r");
                    if (status_f) {
                        char status[32];
                        if (fgets(status, sizeof(status), status_f)) {
                            status[strcspn(status, "\n")] = 0;
                            provider->data.battery.is_charging =
                                (strcmp(status, "Charging") == 0);
                        }
                        fclose(status_f);
                    }

                    fclose(f);
                    break;
                }
            }
            fclose(f);
        }
    }
    closedir(dir);

    return 0;
}

/* ============================================================================
 * Volume Provider
 * ============================================================================ */

int provider_update_volume(widget_provider_t *provider) {
    /* Use wpctl to get volume */
    FILE *p = popen("wpctl get-volume @DEFAULT_SINK@ 2>/dev/null", "r");
    if (!p) return -1;

    char line[128];
    if (fgets(line, sizeof(line), p)) {
        float volume = 0;
        int muted = 0;

        if (sscanf(line, "Volume: %f", &volume) == 1) {
            provider->data.volume.level = volume * 100;
        }
        if (strstr(line, "[MUTED]")) {
            provider->data.volume.muted = true;
        } else {
            provider->data.volume.muted = false;
        }
    }

    pclose(p);
    return 0;
}

/* ============================================================================
 * Date Provider
 * ============================================================================ */

int provider_update_date(widget_provider_t *provider) {
    time_t now = time(NULL);
    struct tm *tm = localtime(&now);

    provider->data.date.year = tm->tm_year + 1900;
    provider->data.date.month = tm->tm_mon + 1;
    provider->data.date.day = tm->tm_mday;
    provider->data.date.hour = tm->tm_hour;
    provider->data.date.minute = tm->tm_min;
    provider->data.date.second = tm->tm_sec;

    /* Format: "Mon 03 Jul  14:30:45" */
    strftime(provider->data.date.formatted, sizeof(provider->data.date.formatted),
             "%a %d %b  %H:%M:%S", tm);

    /* Time only: "14:30" */
    strftime(provider->data.date.time_only, sizeof(provider->data.date.time_only),
             "%H:%M", tm);

    /* Date only: "Mon 03 Jul" */
    strftime(provider->data.date.date_only, sizeof(provider->data.date.date_only),
             "%a %d %b", tm);

    return 0;
}
