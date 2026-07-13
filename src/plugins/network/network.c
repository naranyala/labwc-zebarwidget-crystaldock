#include "../../libocws/plugin_api.h"
#include "../../libocws/ocws_string.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>

/* Simple IP parsing for demonstration */
static char g_current_ip[64] = "0.0.0.0";
static char g_interface[32] = "unknown";
static time_t g_last_check = 0;

/* Validate interface name: alphanumeric, colons, dots, hyphens only */
static int is_valid_interface(const char *s) {
    if (!s || !*s) return 0;
    for (const char *p = s; *p; p++) {
        char c = *p;
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
              (c >= '0' && c <= '9') || c == ':' || c == '.' || c == '-'))
            return 0;
    }
    return 1;
}

static void discover_network(void) {
    FILE *fp = fopen("/proc/net/dev", "r");
    if (!fp) return;

    char line[256];
    while (fgets(line, sizeof(line), fp)) {
        if (strstr(line, "eth0") || strstr(line, "wlan0") || strstr(line, "enp0s25")) {
            char *iface = strtok(line, "");
            if (iface) {
                strncpy(g_interface, iface + 1, sizeof(g_interface) - 1);
                g_interface[sizeof(g_interface) - 1] = '\0';
                break;
            }
        }
    }
    fclose(fp);

    /* Validate interface name before using in shell command */
    if (!is_valid_interface(g_interface)) return;

    /* Try to get IP via ip command with fork+exec+pipe */
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "ip -4 addr show %s | grep -oP '\\K\\d+\\.\\d+\\.\\d+\\.\\d+' | head -1", g_interface);
    int pipefd[2];
    if (pipe(pipefd) == 0) {
        pid_t pid = fork();
        if (pid == 0) {
            close(pipefd[0]);
            dup2(pipefd[1], 1);
            close(pipefd[1]);
            execlp("/bin/sh", "sh", "-c", cmd, NULL);
            _exit(127);
        }
        if (pid > 0) {
            close(pipefd[1]);
            int n = (int)read(pipefd[0], g_current_ip, sizeof(g_current_ip) - 1);
            close(pipefd[0]);
            if (n > 0) g_current_ip[n] = '\0';
            g_current_ip[strcspn(g_current_ip, "\n")] = '\0';
            int status;
            waitpid(pid, &status, 0);
        }
    }
}

static int net_init(void) {
    discover_network();
    return 0;
}

static void on_event(const char *event, const char *payload) {
    if (!event || strcmp(event, "Config.Network") != 0) return;
    if (payload && strstr(payload, "\"reset\"")) {
        /* Reset plugin state */
        discover_network();
        char payload2[256];
        snprintf(payload2, sizeof(payload2), "{\"ip\":\"%s\",\"interface\":\"%s\"}", g_current_ip, g_interface);
        ocws_plugin_emit("Network.State", payload2);
    }
}

static void on_tick(void) {
    time_t now = time(NULL);
    if (now - g_last_check >= 30) {
        char old_ip[64];
        strncpy(old_ip, g_current_ip, sizeof(old_ip));
        
        discover_network();
        
        if (strcmp(old_ip, g_current_ip) != 0) {
            char payload[256];
            snprintf(payload, sizeof(payload), "{\"old_ip\":\"%s\",\"new_ip\":\"%s\",\"interface\":\"%s\"}", old_ip, g_current_ip, g_interface);
            ocws_plugin_emit("Network.IPChanged", payload);
            char notify_body[256];
            snprintf(notify_body, sizeof(notify_body), "IP address changed: %s", g_current_ip);
            ocws_plugin_notify("Network", notify_body, "network-wireless");
        }
        
        g_last_check = now;
    }
}

OcwsPlugin OCWS_PLUGIN_ENTRY = {
    .api_version       = OCWS_PLUGIN_API_VERSION,
    .name              = "Network Monitor",
    .tick_interval_sec = 30,
    .init              = net_init,
    .on_tick           = on_tick,
    .shutdown          = NULL,
    .on_event          = on_event,
};
