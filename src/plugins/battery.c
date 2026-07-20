#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include "../libocws/plugin_api.h"

static char battery_name[64] = {0};

static void find_battery(void) {
    DIR *d = opendir("/sys/class/power_supply");
    if (!d) return;
    struct dirent *dir;
    while ((dir = readdir(d)) != NULL) {
        if (strncmp(dir->d_name, "BAT", 3) == 0) {
            strncpy(battery_name, dir->d_name, sizeof(battery_name) - 1);
            break;
        }
    }
    closedir(d);
}

static int battery_init(void) {
    find_battery();
    if (battery_name[0] == '\0') {
        printf("[BatteryPlugin] No battery found, disabling battery plugin.\n");
        return -1; /* Fail to load if no battery */
    }
    printf("[BatteryPlugin] Native battery monitor initialized for %s.\n", battery_name);
    return 0;
}

static void battery_tick(void) {
    char path[128];
    snprintf(path, sizeof(path), "/sys/class/power_supply/%s/capacity", battery_name);
    FILE *fp = fopen(path, "r");
    if (fp) {
        int capacity = 0;
        if (fscanf(fp, "%d", &capacity) == 1) {
            printf("[BatteryPlugin] %s Capacity: %d%%\n", battery_name, capacity);
        }
        fclose(fp);
    }
    
    snprintf(path, sizeof(path), "/sys/class/power_supply/%s/status", battery_name);
    fp = fopen(path, "r");
    if (fp) {
        char status[32] = {0};
        if (fscanf(fp, "%31s", status) == 1) {
            printf("[BatteryPlugin] %s Status: %s\n", battery_name, status);
        }
        fclose(fp);
    }
}

static void battery_shutdown(void) {
    printf("[BatteryPlugin] Shutting down.\n");
}

OcwsPlugin OCWS_PLUGIN_ENTRY = {
    .api_version = OCWS_PLUGIN_API_VERSION,
    .name = "Battery",
    .tick_interval_sec = 10, /* Update every 10 seconds */
    .init = battery_init,
    .on_tick = battery_tick,
    .shutdown = battery_shutdown,
    .on_event = NULL
};
