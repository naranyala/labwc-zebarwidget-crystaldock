#include "bus.h"
#include <stdlib.h>
#include <string.h>
#include <glib.h>

#define BUS_MAX 256

typedef struct {
    ocws_event_cb cb;
    void         *user;
    char          topic[64];
} Sub;

static GMutex g_lock;
static Sub    g_subs[BUS_MAX];
static int    g_nsubs = 0;
static void (*g_bridge)(const char *topic, const char *value) = NULL;

void ocws_bus_init(void) {
    g_mutex_init(&g_lock);
}

void ocws_bus_subscribe(const char *topic, ocws_event_cb cb, void *user) {
    if (!topic || !cb) return;
    g_mutex_lock(&g_lock);
    if (g_nsubs < BUS_MAX) {
        strncpy(g_subs[g_nsubs].topic, topic, sizeof(g_subs[0].topic) - 1);
        g_subs[g_nsubs].topic[sizeof(g_subs[0].topic) - 1] = '\0';
        g_subs[g_nsubs].cb   = cb;
        g_subs[g_nsubs].user = user;
        g_nsubs++;
    }
    g_mutex_unlock(&g_lock);
}

void ocws_bus_emit(const char *topic, const char *json) {
    /* Snapshot under lock, then dispatch without holding it (avoids
     * re-entrancy deadlocks if a callback emits or subscribes). */
    Sub snap[BUS_MAX];
    int n = 0;
    g_mutex_lock(&g_lock);
    for (int i = 0; i < g_nsubs; i++) {
        if (strcmp(g_subs[i].topic, topic) == 0 ||
            strcmp(g_subs[i].topic, "*") == 0) {
            snap[n++] = g_subs[i];
        }
    }
    g_mutex_unlock(&g_lock);

    for (int i = 0; i < n; i++)
        snap[i].cb(topic, json, snap[i].user);

    if (g_bridge) g_bridge(topic, json ? json : "");
}

void ocws_bus_set_zigshell_bridge(void (*fn)(const char *topic, const char *value)) {
    g_bridge = fn;
}

void ocws_bus_emit_zigshell(const char *topic, const char *value) {
    if (g_bridge) g_bridge(topic, value);
}
