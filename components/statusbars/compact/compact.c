/* statusbars/compact/compact.c - Compact statusbar
 *
 * Space-optimized single-line bar with minimal widgets:
 * - Clock (left)
 * - CPU, Memory (right)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include "widget.h"

/* Statusbar state */
typedef struct {
    wayland_display_t *display;
    wayland_surface_t *surface;

    /* Widgets */
    widget_context_t *clock;
    widget_context_t *cpu;
    widget_context_t *memory;

    /* Config */
    int height;
    widget_theme_t theme;

    bool running;
} compact_state_t;

static compact_state_t state;
static volatile sig_atomic_t running = 1;

static void signal_handler(int sig) {
    running = 0;
}

/* Render statusbar */
static void render_statusbar(compact_state_t *st) {
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

    /* Draw background - darker, more compact */
    double r, g, b, a;
    hex_to_rgba(st->theme.bg, &r, &g, &b, &a);
    cairo_set_source_rgba(cr, r, g, b, 0.95);
    cairo_paint(cr);

    cairo_set_operator(cr, op);

    /* Left: Clock */
    if (st->clock) {
        widget_resize(st->clock, 80, height);
        st->clock->widget->ops->render(st->clock, cr, 80, height);
    }

    /* Right: CPU, Memory */
    int right_x = width - 12;

    if (st->memory) {
        right_x -= 60;
        widget_resize(st->memory, 60, height);
        st->memory->widget->ops->render(st->memory, cr, 60, height);
    }

    if (st->cpu) {
        right_x -= 60;
        widget_resize(st->cpu, 60, height);
        st->cpu->widget->ops->render(st->cpu, cr, 60, height);
    }

    cairo_destroy(cr);
}

/* Initialize */
static int init(compact_state_t *st) {
    st->height = 24;

    /* Load theme */
    theme_init_default(&st->theme);
    char *home = getenv("HOME");
    if (home) {
        char path[256];
        snprintf(path, sizeof(path), "%s/.config/labwc/themerc-override", home);
        theme_load_from_ini(&st->theme, path);
    }

    /* Create Wayland display */
    st->display = wayland_display_create();
    if (!st->display) return -1;

    /* Create layer surface - compact, top anchored */
    st->surface = wayland_surface_create(
        st->display,
        LAYER_TOP,
        LAYER_ANCHOR_TOP | LAYER_ANCHOR_LEFT | LAYER_ANCHOR_RIGHT,
        st->height,
        1920,
        st->height);

    if (!st->surface) {
        wayland_display_destroy(st->display);
        return -1;
    }

    wayland_surface_set_title(st->surface, "labwc-statusbar-compact");

    /* Create widgets */
    extern const widget_ops_t clock_ops;
    extern const widget_ops_t cpu_ops;
    extern const widget_ops_t memory_ops;

    st->clock = widget_context_create(&clock_ops, 80, st->height);
    if (st->clock) widget_init(st->clock);

    st->cpu = widget_context_create(&cpu_ops, 60, st->height);
    if (st->cpu) widget_init(st->cpu);

    st->memory = widget_context_create(&memory_ops, 60, st->height);
    if (st->memory) widget_init(st->memory);

    st->running = true;

    return 0;
}

/* Cleanup */
static void cleanup(compact_state_t *st) {
    if (st->clock) widget_context_destroy(st->clock);
    if (st->cpu) widget_context_destroy(st->cpu);
    if (st->memory) widget_context_destroy(st->memory);

    if (st->surface) wayland_surface_destroy(st->surface);
    if (st->display) wayland_display_destroy(st->display);
}

/* Main loop */
static void run(compact_state_t *st) {
    struct timespec last_update = {0, 0};
    struct timespec now;

    while (running && st->running) {
        clock_gettime(CLOCK_MONOTONIC, &now);

        if (now.tv_sec != last_update.tv_sec) {
            if (st->clock) widget_update(st->clock);
            if (st->cpu) widget_update(st->cpu);
            if (st->memory) widget_update(st->memory);
            last_update = now;
        }

        render_statusbar(st);
        wayland_surface_commit(st->surface);
        wl_display_dispatch(st->display->display);

        usleep(100000);
    }
}

int main(int argc, char *argv[]) {
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    if (init(&state) != 0) {
        fprintf(stderr, "Failed to initialize compact statusbar\n");
        return 1;
    }

    fprintf(stderr, "labwc-statusbar-compact: starting\n");

    run(&state);
    cleanup(&state);

    fprintf(stderr, "labwc-statusbar-compact: stopped\n");

    return 0;
}
