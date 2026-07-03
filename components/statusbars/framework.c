/* statusbars/framework.c - Unified statusbar system framework */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include "widget.h"

/* ============================================================================
 * Statusbar Framework Architecture
 * ============================================================================ */

#define MAX_STATUSBAR_WIDGETS 32
#define CONFIG_MAX_PATH 512

typedef enum {
    WIDGET_TYPE_STANDARD,
    WIDGET_TYPE_SYSTEM,
    WIDGET_TYPE_CUSTOM,
    WIDGET_TYPE_PROVIDER
} widget_type_t;

typedef enum {
    STATUSBAR_STATE_IDLE,
    STATUSBAR_STATE_INITIALIZING,
    STATUSBAR_STATE_RUNNING,
    STATUSBAR_STATE_UPDATING,
    STATUSBAR_STATE_RENDERING,
    STATUSBAR_STATE_SHUTDOWN
} statusbar_state_t;

typedef struct widget_definition_t {
    const char *name;
    const char *description;
    const char *component_path;
    widget_type_t type;
    int default_width;
    int default_height;
    bool enabled;
    bool visible;
    bool has_config;
    char *config;
    bool active;
} widget_definition_t;

typedef struct statusbar_config_t {
    char name[64];
    char description[128];
    int height;
    char position;  /* 't', 'b' */
    int exclusive_zone;
    widget_definition_t *widgets;
    int widget_count;
    int max_widgets;
    widget_theme_t theme;
    struct {
        bool show_workspaces;
        bool show_clock;
        bool show_cpu;
        bool show_memory;
        bool show_network;
        bool show_battery;
        bool show_volume;
    } visibility;
    char layout[64];
    char theme_name[64];
} statusbar_config_t;

typedef struct statusbar_state_t {
    wayland_display_t *display;
    wayland_surface_t *surface;
    
    widget_context_t **widgets;
    int widget_count;
    
    statusbar_config_t config;
    
    statusbar_state_t runtime_state;
    bool running;
    int current_workspace;
} statusbar_state_t;

static statusbar_state_t statusbar_state;
static volatile sig_atomic_t running = 1;

/* ============================================================================
 * Widget Factory System
 * ============================================================================ */

/* ============================================================================
 * Configuration Management
 * ============================================================================ */

statusbar_config_t* create_statusbar_config(const char *name, const char *description,
                                            int height, char position, 
                                            widget_definition_t *widgets, int widget_count) {
    statusbar_config_t *config = calloc(1, sizeof(statusbar_config_t));
    if (!config) return NULL;
    
    strncpy(config->name, name, sizeof(config->name) - 1);
    strncpy(config->description, description, sizeof(config->description) - 1);
    config->height = height;
    config->position = position;
    config->exclusive_zone = height;
    config->widget_count = widget_count;
    
    if (widgets && widget_count > 0) {
        config->max_widgets = widget_count;
        config->widgets = calloc(widget_count, sizeof(widget_definition_t));
        if (!config->widgets) {
            free(config);
            return NULL;
        }
        
        for (int i = 0; i < widget_count; i++) {
            config->widgets[i] = widgets[i];
            config->widgets[i].active = true;
            config->widgets[i].visible = true;
        }
    }
    
    return config;
}

void destroy_statusbar_config(statusbar_config_t *config) {
    if (!config) return;
    
    if (config->widgets) {
        for (int i = 0; i < config->widget_count; i++) {
            free(config->widgets[i].config);
        }
        free(config->widgets);
    }
    
    free(config);
}

/* ============================================================================
 * Widget Management System
 * ============================================================================ */

int setup_statusbar_widget(widget_context_t **widgets, const char *type, int width, int height) {
    if (!type) return -1;
    
    int widget_count = 0;
    
    /* Generic widget setup based on type */
    if (strcmp(type, "workspaces") == 0) {
        extern const widget_ops_t workspaces_ops;
        widgets[widget_count++] = widget_context_create(&workspaces_ops, width, height);
    } else if (strcmp(type, "clock") == 0) {
        extern const widget_ops_t clock_ops;
        widgets[widget_count++] = widget_context_create(&clock_ops, width, height);
    } else if (strcmp(type, "cpu") == 0) {
        extern const widget_ops_t cpu_ops;
        widgets[widget_count++] = widget_context_create(&cpu_ops, width, height);
    } else if (strcmp(type, "memory") == 0) {
        extern const widget_ops_t memory_ops;
        widgets[widget_count++] = widget_context_create(&memory_ops, width, height);
    } else if (strcmp(type, "network") == 0) {
        extern const widget_ops_t network_ops;
        widgets[widget_count++] = widget_context_create(&network_ops, width, height);
    } else if (strcmp(type, "battery") == 0) {
        extern const widget_ops_t battery_ops;
        widgets[widget_count++] = widget_context_create(&battery_ops, width, height);
    } else if (strcmp(type, "volume") == 0) {
        extern const widget_ops_t volume_ops;
        widgets[widget_count++] = widget_context_create(&volume_ops, width, height);
    }
    
    return widget_count;
}

void destroy_statusbar_widgets(widget_context_t **widgets, int count) {
    for (int i = 0; i < count; i++) {
        if (widgets[i]) {
            widget_context_destroy(widgets[i]);
            widgets[i] = NULL;
        }
    }
}

/* ============================================================================
 * Core Statusbar Operations
 * ============================================================================ */

int init_statusbar(statusbar_config_t *config, widget_context_t ***widgets) {
    if (!config) return -1;
    
    /* Initialize Wayland display */
    statusbar_state.display = wayland_display_create();
    if (!statusbar_state.display) {
        fprintf(stderr, "Failed to create Wayland display\n");
        return -1;
    }
    
    /* Create layer surface */
    layer_anchor_t anchor = LAYER_ANCHOR_TOP | LAYER_ANCHOR_LEFT | LAYER_ANCHOR_RIGHT;
    if (config->position == 'b') {
        anchor = LAYER_ANCHOR_BOTTOM | LAYER_ANCHOR_LEFT | LAYER_ANCHOR_RIGHT;
    }
    
    statusbar_state.surface = wayland_surface_create(
        statusbar_state.display,
        LAYER_TOP,
        anchor,
        config->exclusive_zone,
        1920,
        config->height
    );
    
    if (!statusbar_state.surface) {
        fprintf(stderr, "Failed to create layer surface\n");
        wayland_display_destroy(statusbar_state.display);
        return -1;
    }
    
    wayland_surface_set_title(statusbar_state.surface, "labwc-statusbar");
    
    /* Setup widgets based on configuration */
    statusbar_state.widget_count = 0;
    statusbar_state.config = *config;
    
    for (int i = 0; i < config->widget_count; i++) {
        if (config->widgets[i].active) {
            int width = 120;
            if (strcmp(config->widgets[i].name, "clock") == 0) width = 120;
            else if (strcmp(config->widgets[i].name, "workspaces") == 0) width = 280;
            else if (strcmp(config->widgets[i].name, "cpu") == 0) width = 80;
            else if (strcmp(config->widgets[i].name, "memory") == 0) width = 80;
            else if (strcmp(config->widgets[i].name, "network") == 0) width = 120;
            else if (strcmp(config->widgets[i].name, "battery") == 0) width = 80;
            else if (strcmp(config->widgets[i].name, "volume") == 0) width = 80;
            
            int wcount = setup_statusbar_widget(&statusbar_state.widgets[i], 
                                                config->widgets[i].name, width, config->height);
            if (wcount > 0) {
                statusbar_state.widget_count += wcount;
            }
        }
    }
    
    *widgets = statusbar_state.widgets;
    statusbar_state.running = true;
    statusbar_state.runtime_state = STATUSBAR_STATE_RUNNING;
    
    return 0;
}

void cleanup_statusbar() {
    statusbar_state.running = false;
    statusbar_state.runtime_state = STATUSBAR_STATE_SHUTDOWN;
    
    /* Cleanup widgets */
    destroy_statusbar_widgets(statusbar_state.widgets, statusbar_state.widget_count);
    
    /* Cleanup Wayland */
    if (statusbar_state.surface) wayland_surface_destroy(statusbar_state.surface);
    if (statusbar_state.display) wayland_display_destroy(statusbar_state.display);
    
    statusbar_state.widget_count = 0;
}

/* ============================================================================
 * Rendering System
 * ============================================================================ */

void render_statusbar() {
    if (!statusbar_state.surface) return;
    
    cairo_surface_t *cairo_surface = wayland_surface_get_cairo(statusbar_state.surface);
    if (!cairo_surface) return;
    
    cairo_t *cr = cairo_create(cairo_surface);
    if (!cr) return;
    
    int width, height;
    wayland_surface_get_size(statusbar_state.surface, &width, &height);
    
    /* Clear background */
    double r, g, b, a;
    hex_to_rgba(statusbar_state.config.theme.bg, &r, &g, &b, &a);
    cairo_set_source_rgba(cr, r, g, b, statusbar_state.config.theme.bg_alpha);
    cairo_paint(cr);
    
    /* Draw border */
    hex_to_rgba(statusbar_state.config.theme.border, &r, &g, &b, &a);
    cairo_set_source_rgba(cr, r, g, b, 0.6);
    cairo_set_line_width(cr, 1);
    cairo_move_to(cr, 0, height - 1);
    cairo_line_to(cr, width, height - 1);
    cairo_stroke(cr);
    
    /* Render widgets */
    int x_offset = 12;
    for (int i = 0; i < statusbar_state.widget_count; i++) {
        widget_context_t *widget = statusbar_state.widgets[i];
        widget_resize(widget, widget->widget->width, statusbar_state.config.height);
        widget->widget->ops->render(widget, cr, widget->widget->width, statusbar_state.config.height);
        x_offset += widget->widget->width + 8;
    }
    
    cairo_destroy(cr);
    wayland_surface_commit(statusbar_state.surface);
    wl_display_dispatch(statusbar_state.display->display);
}

/* ============================================================================
 * Update Loop
 * ============================================================================ */

void run_statusbar_loop(void (*update_callback)(void), void (*render_callback)(void), 
                       void (*event_handler)(void)) {
    struct timespec last_update = {0, 0};
    struct timespec now;
    
    while (running && statusbar_state.running) {
        clock_gettime(CLOCK_MONOTONIC, &now);
        
        /* Handle scheduled updates */
        if (update_callback && now.tv_sec != last_update.tv_sec) {
            update_callback();
            last_update = now;
        }
        
        /* Render frame */
        if (render_callback) {
            render_callback();
        }
        
        /* Process events */
        if (event_handler) {
            event_handler();
        }
        
        /* Sleep */
        usleep(100000);
    }
}

/* ============================================================================
 * Main Entry Point
 * ============================================================================ */

int main(int argc, char *argv[]) {
    signal(SIGINT, (void (*)(int))signal_handler);
    signal(SIGTERM, (void (*)(int))signal_handler);
    
    /* Load configuration */
    statusbar_config_t *config = NULL;
    if (argc > 1) {
        /* Load from specified config file */
        char config_path[CONFIG_MAX_PATH];
        snprintf(config_path, sizeof(config_path), "%s/%s.conf", "statusbar-configs", argv[1]);
        
        FILE *f = fopen(config_path, "r");
        if (f) {
            /* Simple config parsing (would normally use JSON parser) */
            fclose(f);
        }
    }
    
    if (!config) {
        /* Create default configuration */
        widget_definition_t default_widgets[] = {
            {"workspaces", "Workspace switcher", "", WIDGET_TYPE_SYSTEM, 280, 32, true, true, false, NULL},
            {"clock", "Clock widget", "", WIDGET_TYPE_SYSTEM, 120, 32, true, true, false, NULL},
            {"cpu", "CPU usage monitor", "", WIDGET_TYPE_SYSTEM, 80, 32, true, true, false, NULL},
            {"memory", "Memory usage monitor", "", WIDGET_TYPE_SYSTEM, 80, 32, true, true, false, NULL},
            {"network", "Network status", "", WIDGET_TYPE_SYSTEM, 120, 32, true, true, false, NULL},
            {"battery", "Battery status", "", WIDGET_TYPE_SYSTEM, 80, 32, true, true, false, NULL},
            {"volume", "Volume control", "", WIDGET_TYPE_SYSTEM, 80, 32, true, true, false, NULL}
        };
        
        config = create_statusbar_config("main", "Full-featured statusbar", 
                                         32, 't', default_widgets, 7);
    }
    
    if (!config) {
        fprintf(stderr, "Failed to create statusbar configuration\n");
        return 1;
    }
    
    /* Initialize statusbar */
    if (init_statusbar(config, &statusbar_state.widgets) != 0) {
        fprintf(stderr, "Failed to initialize statusbar\n");
        destroy_statusbar_config(config);
        return 1;
    }
    
    fprintf(stderr, "%s statusbar: starting\n", config->name);
    
    /* Setup default callbacks */
    auto void update_widgets() {
        for (int i = 0; i < statusbar_state.widget_count; i++) {
            widget_update(statusbar_state.widgets[i]);
        }
    }
    
    auto void render_bar() {
        render_statusbar();
    }
    
    /* Run main loop */
    run_statusbar_loop(update_widgets, render_bar, NULL);
    
    /* Cleanup */
    cleanup_statusbar();
    destroy_statusbar_config(config);
    
    fprintf(stderr, "%s statusbar: stopped\n", config->name);
    
    return 0;
}
