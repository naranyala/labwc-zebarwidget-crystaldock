#include "../../libocws/plugin_api.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static time_t g_end = 0;
static int    g_running = 0;
static int    g_work = 25;   /* minutes */
static int    g_break = 5;   /* minutes */

/* Publish state to the bus (and, via the host bridge, to zigshell-cairo-pango). */
static void publish(const char *state) {
    char payload[128];
    snprintf(payload, sizeof(payload), "{\"state\":\"%s\"}", state);
    ocws_plugin_emit("Pomodoro.State", payload);
    if (strcmp(state, "finished") == 0)
        ocws_plugin_notify("Pomodoro", "Time's up! Take a break.", "timer");
}

static void on_event(const char *event, const char *payload) {
    if (!event || strcmp(event, "Pomodoro.Command") != 0) return;

    if (payload && strstr(payload, "\"start\"")) {
        g_end = time(NULL) + (time_t)g_work * 60;
        g_running = 1;
        publish("running");
    } else if (payload && strstr(payload, "\"stop\"")) {
        g_running = 0;
        publish("idle");
    }
}

static int init(void) {
    const char *w = ocws_plugin_config("work_minutes", "25");
    const char *b = ocws_plugin_config("break_minutes", "5");
    if (w) g_work  = atoi(w);
    if (b) g_break = atoi(b);
    publish("idle");
    return 0;
}

/* Driven by the host every tick_interval_sec (set in plugin.json). */
static void on_tick(void) {
    if (g_running && time(NULL) >= g_end) {
        g_running = 0;
        publish("finished");
    }
}

OcwsPlugin OCWS_PLUGIN_ENTRY = {
    .api_version       = OCWS_PLUGIN_API_VERSION,
    .name              = "Pomodoro Timer",
    .tick_interval_sec = 1,
    .init              = init,
    .on_tick           = on_tick,
    .shutdown          = NULL,
    .on_event          = on_event,
};
