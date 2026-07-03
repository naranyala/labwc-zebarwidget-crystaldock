/* systems/lifecycle.c - System lifecycle and callback management */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>
#include "widget.h"

/* ============================================================================
 * Lifecycle Management
 * ============================================================================ */

#define MAX_LIFECYCLE_CALLBACKS 64

typedef enum {
    LIFECYCLE_EVENT_START,
    LIFECYCLE_EVENT_STOP,
    LIFECYCLE_EVENT_UPDATE,
    LIFECYCLE_EVENT_RENDER,
    LIFECYCLE_EVENT_FOCUS,
    LIFECYCLE_EVENT_THEME,
    LIFECYCLE_EVENT_CONFIG,
    LIFECYCLE_EVENT_MAX
} lifecycle_event_t;

typedef void (*lifecycle_callback)(lifecycle_event_t event, const char *data, void *user_data);

typedef struct {
    lifecycle_event_t event;
    lifecycle_callback callback;
    void *user_data;
} lifecycle_callback_t;

static lifecycle_callback_t lifecycle_callbacks[MAX_LIFECYCLE_CALLBACKS];
static int callback_count = 0;

/* ============================================================================
 * Lifecycle API
 * ============================================================================ */

/* Register a lifecycle callback */
int register_lifecycle_callback(lifecycle_event_t event, lifecycle_callback callback, void *user_data) {
    if (callback_count >= MAX_LIFECYCLE_CALLBACKS) return -1;
    if (!callback) return -1;
    
    lifecycle_callbacks[callback_count].event = event;
    lifecycle_callbacks[callback_count].callback = callback;
    lifecycle_callbacks[callback_count].user_data = user_data;
    
    return callback_count++;
}

/* Emit a lifecycle event */
void emit_lifecycle_event(lifecycle_event_t event, const char *data) {
    for (int i = 0; i < callback_count; i++) {
        if (lifecycle_callbacks[i].event == event || lifecycle_callbacks[i].event == LIFECYCLE_EVENT_MAX) {
            lifecycle_callbacks[i].callback(event, data, lifecycle_callbacks[i].user_data);
        }
    }
}

/* Emit an event with user data */
void emit_lifecycle_event_with_data(lifecycle_event_t event, const char *data, void *user_data) {
    for (int i = 0; i < callback_count; i++) {
        if ((lifecycle_callbacks[i].event == event || lifecycle_callbacks[i].event == LIFECYCLE_EVENT_MAX) &&
            lifecycle_callbacks[i].user_data == user_data) {
            lifecycle_callbacks[i].callback(event, data, user_data);
        }
    }
}

/* Setup window creation callback */
void setup_window_creation_callback(void (*callback)(const char *title, const char *app_id, void *user_data), void *user_data) {
    if (!callback) return;
    
    /* Create a window */
    widget_context_t *ctx = widget_context_create(NULL, 0, 0);  /* Placeholder */
    if (!ctx) return;
    
    register_lifecycle_callback(LIFECYCLE_EVENT_START, 
        (lifecycle_callback)(void(*)(lifecycle_event_t, const char*, void*))callback, 
        user_data);
}

/* Setup widget focus callback */
void setup_widget_focus_callback(void (*callback)(const char *component_name, bool focused, void *user_data), void *user_data) {
    if (!callback) return;
    
    register_lifecycle_callback(LIFECYCLE_EVENT_FOCUS,
        (lifecycle_callback)(void(*)(lifecycle_event_t, const char*, void*))callback,
        user_data);
}

/* Setup theme change callback */
void setup_theme_change_callback(void (*callback)(const char *theme_name, void *user_data), void *user_data) {
    if (!callback) return;
    
    register_lifecycle_callback(LIFECYCLE_EVENT_THEME,
        (lifecycle_callback)(void(*)(lifecycle_event_t, const char*, void*))callback,
        user_data);
}

/* Setup configuration change callback */
void setup_config_change_callback(void (*callback)(const char *config_name, void *user_data), void *user_data) {
    if (!callback) return;
    
    register_lifecycle_callback(LIFECYCLE_EVENT_CONFIG,
        (lifecycle_callback)(void(*)(lifecycle_event_t, const char*, void*))callback,
        user_data);
}

/* Get all registered callbacks */
lifecycle_callback_t* get_lifecycle_callbacks(int *count) {
    *count = callback_count;
    return lifecycle_callbacks;
}

/* Clear all callbacks */
void clear_lifecycle_callbacks() {
    callback_count = 0;
    memset(lifecycle_callbacks, 0, sizeof(lifecycle_callbacks));
}

/* Initialize default lifecycle handlers */
void init_default_lifecycle_handlers() {
    /* Register default system lifecycle callbacks */
    register_lifecycle_callback(LIFECYCLE_EVENT_START, 
        (lifecycle_callback)(void(*)(lifecycle_event_t, const char*, void*))handle_system_start,
        NULL);
    
    register_lifecycle_callback(LIFECYCLE_EVENT_STOP,
        (lifecycle_callback)(void(*)(lifecycle_event_t, const char*, void*))handle_system_stop,
        NULL);
    
    register_lifecycle_callback(LIFECYCLE_EVENT_UPDATE,
        (lifecycle_callback)(void(*)(lifecycle_event_t, const char*, void*))handle_system_update,
        NULL);
    
    register_lifecycle_callback(LIFECYCLE_EVENT_RENDER,
        (lifecycle_callback)(void(*)(lifecycle_event_t, const char*, void*))handle_system_render,
        NULL);
}

/* Default lifecycle handlers */
void handle_system_start(lifecycle_event_t event, const char *data, void *user_data) {
    printf("System starting up: %s\n", data ? data : "unknown");
}

void handle_system_stop(lifecycle_event_t event, const char *data, void *user_data) {
    printf("System shutting down: %s\n", data ? data : "unknown");
}

void handle_system_update(lifecycle_event_t event, const char *data, void *user_data) {
    /* Update registered components */
    for (int i = 0; i < callback_count; i++) {
        if (lifecycle_callbacks[i].event == LIFECYCLE_EVENT_UPDATE &&
            lifecycle_callbacks[i].callback != handle_system_update) {
            lifecycle_callbacks[i].callback(event, data, lifecycle_callbacks[i].user_data);
        }
    }
}

void handle_system_render(lifecycle_event_t event, const char *data, void *user_data) {
    /* Trigger rendering on all components */
    for (int i = 0; i < callback_count; i++) {
        if (lifecycle_callbacks[i].event == LIFECYCLE_EVENT_RENDER &&
            lifecycle_callbacks[i].callback != handle_system_render) {
            lifecycle_callbacks[i].callback(event, data, lifecycle_callbacks[i].user_data);
        }
    }
}

/* Cleanup lifecycle system */
void cleanup_lifecycle_system() {
    clear_lifecycle_callbacks();
}
