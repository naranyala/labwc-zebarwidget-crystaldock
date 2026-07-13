#include "../../libocws/plugin_api.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

/* Escape a string for safe JSON embedding: escapes " and \ */
static void json_escape(char *dst, size_t dstsz, const char *src) {
    if (!dst || dstsz == 0) return;
    size_t di = 0;
    for (const char *p = src; *p && di < dstsz - 1; p++) {
        if (*p == '"' || *p == '\\') {
            if (di + 2 >= dstsz) break;
            dst[di++] = '\\';
            dst[di++] = *p;
        } else if ((unsigned char)*p < 0x20) {
            /* Skip control characters */
            continue;
        } else {
            dst[di++] = *p;
        }
    }
    dst[di] = '\0';
}

static char g_clipboard_content[4096] = {0};
static time_t g_last_clipboard_time = 0;
static int g_clipboard_history_count = 0;

static void update_clipboard_history(void) {
    FILE *fp = popen("cliphist list -n 5 2>/dev/null", "r");
    if (!fp) return;
    
    char line[1024];
    while (fgets(line, sizeof(line), fp)) {
        line[strcspn(line, "\n")] = '\0';
        char escaped[1024];
        json_escape(escaped, sizeof(escaped), line);
        char json[2048];
        snprintf(json, sizeof(json), "{\"type\":\"history\",\"content\":\"%s\"}", escaped);
        ocws_plugin_emit("Clipboard.Event", json);
    }
    pclose(fp);
}

static int clip_init(void) {
    update_clipboard_history();
    return 0;
}

static void on_event(const char *event, const char *payload) {
    if (!event) return;
    
    if (strcmp(event, "Clipboard.Copy") == 0) {
        if (payload && strlen(payload) < sizeof(g_clipboard_content)) {
            strcpy(g_clipboard_content, payload);
            g_last_clipboard_time = time(NULL);
            g_clipboard_history_count++;
            
            char response[256];
            snprintf(response, sizeof(response), "{\"status\":\"copied\",timestamp:%ld,length:%d}", (long)g_last_clipboard_time, (int)strlen(payload));
            ocws_plugin_emit("Clipboard.Status", response);
            ocws_plugin_notify("Clipboard", "Content copied to clipboard", "edit-paste");
        }
    }
}

static void on_tick(void) {
    static time_t last_notify = 0;
    time_t now = time(NULL);
    
    if (g_clipboard_content[0] && now - g_last_clipboard_time > 3600) {
        /* Notify about clipboard content after being visible for 1 hour */
        if (now - last_notify >= 3600) {
            char escaped[4096];
            json_escape(escaped, sizeof(escaped), g_clipboard_content);
            char payload[512];
            snprintf(payload, sizeof(payload), "{\"content\":\"%s\",duration:%ld}", escaped, now - g_last_clipboard_time);
            ocws_plugin_notify("Clipboard", "Clipboard content has been saved:", g_clipboard_content);
            last_notify = now;
        }
    }
}

OcwsPlugin OCWS_PLUGIN_ENTRY = {
    .api_version       = OCWS_PLUGIN_API_VERSION,
    .name              = "Clipboard Monitor",
    .tick_interval_sec = 60,
    .init              = clip_init,
    .on_tick           = on_tick,
    .shutdown          = NULL,
    .on_event          = on_event,
};
