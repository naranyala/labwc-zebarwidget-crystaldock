/* statusbar/core.c - Common statusbar framework */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include "widget.h"

/* ============================================================================
 * Statusbar configuration system
 * ============================================================================ */

#define CONFIG_MAX_PATH 512

typedef struct bar_config_t {
    char name[32];
    const char **widgets;
    int widget_count;
    int height;
    char position;
    bool show_workspaces;
    bool show_clock;
    bool system_modules;
} bar_config_t;

typedef struct statusbar_state_t {
    wayland_display_t *display;
    wayland_surface_t *surface;
    
    int widget_count;
    widget_context_t **widgets;
    
    const bar_config_t *config;
    bool running;
    int current_workspace;
} statusbar_state_t;

static statusbar_state_t state;
static volatile sig_atomic_t running = 1;
static const bar_config_t *current_config = NULL;

/* ============================================================================
 * Widget management - shared across all bars
 * ============================================================================ */

/* Get widget ops based on type */
static const widget_ops_t* get_widget_ops(const char *type) {
    if (strcmp(type, "workspaces") == 0) {
        extern const widget_ops_t workspaces_ops;
        return &workspaces_ops;
    }
    if (strcmp(type, "clock") == 0) {
        extern const widget_ops_t clock_ops;
        return &clock_ops;
    }
    if (strcmp(type, "cpu") == 0) {
        extern const widget_ops_t cpu_ops;
        return &cpu_ops;
    }
    if (strcmp(type, "memory") == 0) {
        extern const widget_ops_t memory_ops;
        return &memory_ops;
    }
    if (strcmp(type, "network") == 0) {
        extern const widget_ops_t network_ops;
        return &network_ops;
    }
    if (strcmp(type, "battery") == 0) {
        extern const widget_ops_t battery_ops;
        return &battery_ops;
    }
    if (strcmp(type, "volume") == 0) {
        extern const widget_ops_t volume_ops;
        return &volume_ops;
    }
    return NULL;
}

/* ============================================================================
 * Generic bar initialization
 * ============================================================================ */

static int load_config(const char *config_path) {
    FILE *f = fopen(config_path, "r");
    if (!f) return -1;
    
    fclose(f);
    return 0;
}

static int init_bar(statusbar_state_t *st, const bar_config_t *config) {
    st->config = config;
    st->running = true;
    st->widget_count = 0;
    
    // Allocate widgets array
    st->widgets = calloc(config->widget_count, sizeof(widget_context_t*));
    if (!st->widgets) return -1;
    
    return 0;
}

static void cleanup_bar(statusbar_state_t *st) {
    for (int i = 0; i < st->widget_count; i++) {
        if (st->widgets[i]) {
            widget_context_destroy(st->widgets[i]);
        }
    }
    free(st->widgets);
}

/* ============================================================================
 * Generic rendering
 * ============================================================================ */

static void render_bar(statusbar_state_t *st) {
    if (!st->surface) return;
    
    cairo_surface_t *cairo_surface = wayland_surface_get_cairo(st->surface);
    if (!cairo_surface) return;
    
    cairo_t *cr = cairo_create(cairo_surface);
    if (!cr) return;
    
    int width, height;
    wayland_surface_get_size(st->surface, &width, &height);
    
    // Clear background
    cairo_operator_t op = cairo_get_operator(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    
    double r, g, b, a;
    hex_to_rgba(st->config->theme.bg, &r, &g, &b, &a);
    cairo_set_source_rgba(cr, r, g, b, st->config->theme.bg_alpha);
    cairo_paint(cr);
    
    cairo_set_operator(cr, op);
    
    // Render widgets
    int x = 0;
    for (int i = 0; i < st->widget_count; i++) {
        widget_context_t *widget = st->widgets[i];
        widget_resize(widget, widget->widget->width, height);
        widget->widget->ops->render(widget, cr, widget->widget->width, height);
        x += widget->widget->width;
    }
    
    cairo_destroy(cr);
}

/* ============================================================================
 * Core bar operations
 * ============================================================================ */

static void run_bar(statusbar_state_t *st) {
    struct timespec last_update = {0, 0};
    struct timespec now;
    
    while (running && st->running) {
        clock_gettime(CLOCK_MONOTONIC, &now);
        
        if (now.tv_sec != last_update.tv_sec) {
            for (int i = 0; i < st->widget_count; i++) {
                widget_update(st->widgets[i]);
            }
            last_update = now;
        }
        
        render_bar(st);
        wayland_surface_commit(st->surface);
        wl_display_dispatch(st->display->display);
        
        usleep(100000);
    }
}

static void signal_handler(int sig) {
    running = 0;
}

/* ============================================================================
 * Entry point
 * ============================================================================ */

int bar_main(const char *config_name) {
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    if (!config_name) config_name = "default";
    
    // Load config
    char config_path[CONFIG_MAX_PATH];
    snprintf(config_path, sizeof(config_path),
             ".config/labwc/statusbars/%s.conf", config_name);
    
    if (load_config(config_path) != 0) {
        fprintf(stderr, "Failed to load config: %s\n", config_name);
        return 1;
    }
    
    // Initialize bar
    if (init_bar(&state, current_config) != 0) {
        fprintf(stderr, "Failed to initialize bar\n");
        return 1;
    }
    
    fprintf(stderr, "%s bar: starting\n", state.config->name);
    
    run_bar(&state);
    
    cleanup_bar(&state);
    fprintf(stderr, "%s bar: stopped\n", state.config->name);
    
    return 0;
}
