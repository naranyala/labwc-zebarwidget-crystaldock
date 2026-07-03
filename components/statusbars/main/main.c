/* statusbars/main/main.c - Main statusbar
 *
 * Full-featured statusbar with all widgets:
 * - Workspaces (left)
 * - Clock (center)
 * - System modules (right): CPU, Memory, Network, Battery, Volume
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include "widget.h"
#include "core.h"

/* Statusbar configuration */
typedef struct {
    char position;  /* 't'op, 'b'ottom */
    int height;
    int exclusive_zone;

    /* Widget visibility */
    bool show_workspaces;
    bool show_clock;
    bool show_cpu;
    bool show_memory;
    bool show_network;
    bool show_battery;
    bool show_volume;

    /* Theme */
    widget_theme_t theme;
} statusbar_config_t;

/* Statusbar state */
typedef struct {
    wayland_display_t *display;
    wayland_surface_t *surface;

    /* Dynamic widgets array */
    int widget_count;
    widget_context_t **widgets;

    /* Config */
    statusbar_config_t config;

    /* State */
    int current_workspace;
    bool running;
} statusbar_state_t;

static statusbar_state_t state;
static volatile sig_atomic_t running = 1;

/* Signal handler */
static void signal_handler(int sig) {
    running = 0;
}

/* Load configuration */
static void load_config(statusbar_config_t *config) {
    /* Default config */
    config->position = 't';
    config->height = 32;
    config->exclusive_zone = 32;

    config->show_workspaces = true;
    config->show_clock = true;
    config->show_cpu = true;
    config->show_memory = true;
    config->show_network = true;
    config->show_battery = true;
    config->show_volume = true;

    /* Load theme */
    theme_init_default(&config->theme);

    /* Try to load from theme file */
    char *home = getenv("HOME");
    if (home) {
        char path[256];
        snprintf(path, sizeof(path), "%s/.config/labwc/themerc-override", home);
        theme_load_from_ini(&config->theme, path);
    }
}

/* Render workspaces */
static void render_workspaces(cairo_t *cr, int x, int y, int height,
                              int current, const widget_theme_t *theme) {
    PangoLayout *layout = pango_cairo_create_layout(cr);

    for (int i = 1; i <= 9; i++) {
        render_workspace_button(cr, layout, x, y + 4, i,
                                i - 1 == current, false, theme);
        x += 28;
    }

    g_object_unref(layout);
}

/* Render statusbar */
static void render_statusbar(statusbar_state_t *st) {
    if (!st->surface) return;

    cairo_surface_t *cairo_surface = wayland_surface_get_cairo(st->surface);
    if (!cairo_surface) return;

    cairo_t *cr = cairo_create(cairo_surface);
    if (!cr) return;

    int width, height;
    wayland_surface_get_size(st->surface, &width, &height);

    /* Clear background */
    cairo_operator_t op = cairo_get_operator(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);

    /* Draw background */
    double r, g, b, a;
    hex_to_rgba(st->config.theme.bg, &r, &g, &b, &a);
    cairo_set_source_rgba(cr, r, g, b, st->config.theme.bg_alpha);
    cairo_paint(cr);

    /* Draw border at bottom */
    hex_to_rgba(st->config.theme.border, &r, &g, &b, &a);
    cairo_set_source_rgba(cr, r, g, b, 0.6);
    cairo_rectangle(cr, 0, height - 1, width, 1);
    cairo_fill(cr);

    cairo_set_operator(cr, op);

    int x_offset = 12;

    /* Left: Workspaces */
    if (st->config.show_workspaces) {
        render_workspaces(cr, x_offset, 0, height,
                         st->current_workspace, &st->config.theme);
        x_offset += 9 * 28 + 12;
    }

    /* Center: Clock */
    if (st->config.show_clock && st->clock) {
        widget_resize(st->clock, 120, height);
        st->clock->widget->ops->render(st->clock, cr, 120, height);
    }

    /* Right: System modules */
    int right_x = width - 12;

    if (st->config.show_volume && st->volume) {
        right_x -= 80;
        widget_resize(st->volume, 80, height);
        st->volume->widget->ops->render(st->volume, cr, 80, height);
    }

    if (st->config.show_battery && st->battery) {
        right_x -= 80;
        widget_resize(st->battery, 80, height);
        st->battery->widget->ops->render(st->battery, cr, 80, height);
    }

    if (st->config.show_network && st->network) {
        right_x -= 120;
        widget_resize(st->network, 120, height);
        st->network->widget->ops->render(st->network, cr, 120, height);
    }

    if (st->config.show_memory && st->memory) {
        right_x -= 80;
        widget_resize(st->memory, 80, height);
        st->memory->widget->ops->render(st->memory, cr, 80, height);
    }

    if (st->config.show_cpu && st->cpu) {
        right_x -= 80;
        widget_resize(st->cpu, 80, height);
        st->cpu->widget->ops->render(st->cpu, cr, 80, height);
    }

    cairo_destroy(cr);
}

/* Initialize statusbar */
static int init_statusbar(statusbar_state_t *st) {
    load_config(&st->config);

    /* Create Wayland display */
    st->display = wayland_display_create();
    if (!st->display) {
        fprintf(stderr, "Failed to create Wayland display\n");
        return -1;
    }

    /* Create layer surface */
    layer_anchor_t anchor = LAYER_ANCHOR_TOP | LAYER_ANCHOR_LEFT | LAYER_ANCHOR_RIGHT;
    if (st->config.position == 'b') {
        anchor = LAYER_ANCHOR_BOTTOM | LAYER_ANCHOR_LEFT | LAYER_ANCHOR_RIGHT;
    }

    st->surface = wayland_surface_create(
        st->display,
        LAYER_TOP,
        anchor,
        st->config.exclusive_zone,
        1920,  /* Default width, will be configured */
        st->config.height);

    if (!st->surface) {
        fprintf(stderr, "Failed to create layer surface\n");
        wayland_display_destroy(st->display);
        return -1;
    }

    wayland_surface_set_title(st->surface, "labwc-statusbar");

    /* Create widgets */
    if (st->config.show_clock) {
        extern const widget_ops_t clock_ops;
        st->clock = widget_context_create(&clock_ops, 120, st->config.height);
        if (st->clock) widget_init(st->clock);
    }

    if (st->config.show_cpu) {
        extern const widget_ops_t cpu_ops;
        st->cpu = widget_context_create(&cpu_ops, 80, st->config.height);
        if (st->cpu) widget_init(st->cpu);
    }

    if (st->config.show_memory) {
        extern const widget_ops_t memory_ops;
        st->memory = widget_context_create(&memory_ops, 80, st->config.height);
        if (st->memory) widget_init(st->memory);
    }

    if (st->config.show_network) {
        extern const widget_ops_t network_ops;
        st->network = widget_context_create(&network_ops, 120, st->config.height);
        if (st->network) widget_init(st->network);
    }

    if (st->config.show_battery) {
        extern const widget_ops_t battery_ops;
        st->battery = widget_context_create(&battery_ops, 80, st->config.height);
        if (st->battery) widget_init(st->battery);
    }

    if (st->config.show_volume) {
        extern const widget_ops_t volume_ops;
        st->volume = widget_context_create(&volume_ops, 80, st->config.height);
        if (st->volume) widget_init(st->volume);
    }

    st->running = true;

    return 0;
}

/* Cleanup */
static void cleanup_statusbar(statusbar_state_t *st) {
    if (st->clock) widget_context_destroy(st->clock);
    if (st->cpu) widget_context_destroy(st->cpu);
    if (st->memory) widget_context_destroy(st->memory);
    if (st->network) widget_context_destroy(st->network);
    if (st->battery) widget_context_destroy(st->battery);
    if (st->volume) widget_context_destroy(st->volume);

    if (st->surface) wayland_surface_destroy(st->surface);
    if (st->display) wayland_display_destroy(st->display);
}

/* Main loop */
static void run_statusbar(statusbar_state_t *st) {
    struct timespec last_update = {0, 0};
    struct timespec now;

    while (running && st->running) {
        clock_gettime(CLOCK_MONOTONIC, &now);

        /* Update widgets every second */
        if (now.tv_sec != last_update.tv_sec) {
            if (st->clock) widget_update(st->clock);
            if (st->cpu) widget_update(st->cpu);
            if (st->memory) widget_update(st->memory);
            if (st->network) widget_update(st->network);
            if (st->battery) widget_update(st->battery);
            if (st->volume) widget_update(st->volume);

            last_update = now;
        }

        /* Render */
        render_statusbar(st);
        wayland_surface_commit(st->surface);

        /* Process Wayland events */
        wl_display_dispatch(st->display->display);

        /* Sleep 100ms */
        usleep(100000);
    }
}

int main(int argc, char *argv[]) {
    /* Setup signal handlers */
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    /* Initialize */
    if (init_statusbar(&state) != 0) {
        fprintf(stderr, "Failed to initialize statusbar\n");
        return 1;
    }

    fprintf(stderr, "labwc-statusbar-main: starting\n");

    /* Run */
    run_statusbar(&state);

    /* Cleanup */
    cleanup_statusbar(&state);

    fprintf(stderr, "labwc-statusbar-main: stopped\n");

    return 0;
}
