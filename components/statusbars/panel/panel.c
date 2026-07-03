/* statusbars/panel/panel.c - Dashboard panel
 *
 * Grid dashboard with detailed system metrics:
 * - CPU (with cores and temperature)
 * - Memory (with swap)
 * - Network (with speed)
 * - Battery (with time remaining)
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

    /* Providers */
    widget_provider_t *cpu;
    widget_provider_t *memory;
    widget_provider_t *network;
    widget_provider_t *battery;

    /* Config */
    int height;
    widget_theme_t theme;

    bool running;
} panel_state_t;

static panel_state_t state;
static volatile sig_atomic_t running = 1;

static void signal_handler(int sig) {
    running = 0;
}

/* Render metric card */
static void render_metric_card(cairo_t *cr, PangoLayout *layout,
                               int x, int y, int card_width, int card_height,
                               const char *title, const char *value,
                               const char *detail, const char *color,
                               const widget_theme_t *theme) {
    /* Card background */
    render_rounded_rect(cr, x, y, card_width, card_height, 8,
                       theme->surface, 0.6);

    /* Border on hover (static for now) */
    double r, g, b, a;
    hex_to_rgba(color, &r, &g, &b, &a);
    cairo_set_source_rgba(cr, r, g, b, 0.3);
    cairo_set_line_width(cr, 1);
    cairo_new_sub_path(cr);
    cairo_arc(cr, x + card_width - 8, y + 8, 8, -M_PI / 2, 0);
    cairo_arc(cr, x + card_width - 8, y + card_height - 8, 8, 0, M_PI / 2);
    cairo_arc(cr, x + 8, y + card_height - 8, 8, M_PI / 2, M_PI);
    cairo_arc(cr, x + 8, y + 8, 8, M_PI, 3 * M_PI / 2);
    cairo_close_path(cr);
    cairo_stroke(cr);

    /* Title */
    PangoFontDescription *desc = pango_font_description_from_string("JetBrains Mono");
    pango_font_description_set_size(desc, 10 * PANGO_SCALE);
    pango_layout_set_font_description(layout, desc);
    pango_layout_set_text(layout, title, -1);

    hex_to_rgba(theme->fg, &r, &g, &b, &a);
    cairo_set_source_rgba(cr, r, g, b, 0.6);
    cairo_move_to(cr, x + 12, y + 16);
    pango_cairo_show_layout(cr, layout);

    /* Value */
    pango_font_description_set_size(desc, 24 * PANGO_SCALE);
    pango_font_description_set_weight(desc, PANGO_WEIGHT_BOLD);
    pango_layout_set_font_description(layout, desc);
    pango_layout_set_text(layout, value, -1);

    hex_to_rgba(color, &r, &g, &b, &a);
    cairo_set_source_rgba(cr, r, g, b, 1.0);
    cairo_move_to(cr, x + 12, y + 40);
    pango_cairo_show_layout(cr, layout);

    /* Detail */
    if (detail) {
        pango_font_description_set_size(desc, 10 * PANGO_SCALE);
        pango_font_description_set_weight(desc, PANGO_WEIGHT_NORMAL);
        pango_layout_set_font_description(layout, desc);
        pango_layout_set_text(layout, detail, -1);

        hex_to_rgba(theme->fg, &r, &g, &b, &a);
        cairo_set_source_rgba(cr, r, g, b, 0.4);
        cairo_move_to(cr, x + 12, y + 70);
        pango_cairo_show_layout(cr, layout);
    }

    pango_font_description_free(desc);
}

/* Render panel */
static void render_panel(panel_state_t *st) {
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

    double r, g, b, a;
    hex_to_rgba(st->theme.bg, &r, &g, &b, &a);
    cairo_set_source_rgba(cr, r, g, b, 0.95);
    cairo_paint(cr);

    cairo_set_operator(cr, op);

    /* Create layout */
    PangoLayout *layout = pango_cairo_create_layout(cr);

    /* Update providers */
    provider_update(st->cpu);
    provider_update(st->memory);
    provider_update(st->network);
    provider_update(st->battery);

    const provider_data_t *cpu_data = provider_get_data(st->cpu);
    const provider_data_t *mem_data = provider_get_data(st->memory);
    const provider_data_t *net_data = provider_get_data(st->network);
    const provider_data_t *bat_data = provider_get_data(st->battery);

    /* Card dimensions */
    int card_width = (width - 60) / 3;
    int card_height = (height - 40) / 2;
    int gap = 12;

    /* Row 1: CPU, Memory, Network */
    char value[64], detail[128];

    /* CPU */
    snprintf(value, sizeof(value), "%.0f%%", cpu_data->cpu.usage);
    snprintf(detail, sizeof(detail), "Cores: %d | Temp: %.0f°C",
             cpu_data->cpu.cores, cpu_data->cpu.temperature);
    render_metric_card(cr, layout,
                      20, 20, card_width, card_height,
                      "CPU STATUS", value, detail,
                      cpu_data->cpu.usage > 80 ? st->theme.red : st->theme.accent,
                      &st->theme);

    /* Memory */
    snprintf(value, sizeof(value), "%.0f%%", mem_data->memory.usage);
    snprintf(detail, sizeof(detail), "Used: %lu MB / %lu MB",
             mem_data->memory.used, mem_data->memory.total);
    render_metric_card(cr, layout,
                      20 + card_width + gap, 20, card_width, card_height,
                      "MEMORY", value, detail,
                      mem_data->memory.usage > 90 ? st->theme.red : st->theme.green,
                      &st->theme);

    /* Network */
    snprintf(value, sizeof(value), "%s",
             net_data->network.connected ? "Online" : "Offline");
    snprintf(detail, sizeof(detail), "%s | %s",
             net_data->network.is_wifi ? "WiFi" : "Ethernet",
             net_data->network.ssid);
    render_metric_card(cr, layout,
                      20 + (card_width + gap) * 2, 20, card_width, card_height,
                      "NETWORK", value, detail,
                      net_data->network.connected ? st->theme.accent : st->theme.red,
                      &st->theme);

    /* Row 2: Battery, Processes, Disk */
    /* Battery */
    if (bat_data->battery.is_present) {
        snprintf(value, sizeof(value), "%.0f%%", bat_data->battery.charge_percent);
        snprintf(detail, sizeof(detail), "%s",
                 bat_data->battery.is_charging ? "Charging" : "On battery");
    } else {
        snprintf(value, sizeof(value), "N/A");
        snprintf(detail, sizeof(detail), "No battery");
    }
    render_metric_card(cr, layout,
                      20, 20 + card_height + gap, card_width, card_height,
                      "BATTERY", value, detail,
                      bat_data->battery.is_charging ? st->theme.green : st->theme.yellow,
                      &st->theme);

    /* Placeholder: Processes */
    render_metric_card(cr, layout,
                      20 + card_width + gap, 20 + card_height + gap,
                      card_width, card_height,
                      "PROCESSES", "245", "Active: 196",
                      st->theme.green, &st->theme);

    /* Placeholder: Disk */
    render_metric_card(cr, layout,
                      20 + (card_width + gap) * 2, 20 + card_height + gap,
                      card_width, card_height,
                      "DISK", "45%", "Read: 120 MB/s",
                      st->theme.accent, &st->theme);

    g_object_unref(layout);
    cairo_destroy(cr);
}

/* Initialize */
static int init(panel_state_t *st) {
    st->height = 200;

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

    /* Create layer surface - bottom panel */
    st->surface = wayland_surface_create(
        st->display,
        LAYER_TOP,
        LAYER_ANCHOR_BOTTOM | LAYER_ANCHOR_LEFT | LAYER_ANCHOR_RIGHT,
        st->height,
        1920,
        st->height);

    if (!st->surface) {
        wayland_display_destroy(st->display);
        return -1;
    }

    wayland_surface_set_title(st->surface, "labwc-statusbar-panel");

    /* Create providers */
    st->cpu = provider_create(PROVIDER_CPU);
    st->memory = provider_create(PROVIDER_MEMORY);
    st->network = provider_create(PROVIDER_NETWORK);
    st->battery = provider_create(PROVIDER_BATTERY);

    st->running = true;

    return 0;
}

/* Cleanup */
static void cleanup(panel_state_t *st) {
    if (st->cpu) provider_destroy(st->cpu);
    if (st->memory) provider_destroy(st->memory);
    if (st->network) provider_destroy(st->network);
    if (st->battery) provider_destroy(st->battery);

    if (st->surface) wayland_surface_destroy(st->surface);
    if (st->display) wayland_display_destroy(st->display);
}

/* Main loop */
static void run(panel_state_t *st) {
    struct timespec last_update = {0, 0};
    struct timespec now;

    while (running && st->running) {
        clock_gettime(CLOCK_MONOTONIC, &now);

        if (now.tv_sec != last_update.tv_sec) {
            /* Providers are updated in render_panel */
            last_update = now;
        }

        render_panel(st);
        wayland_surface_commit(st->surface);
        wl_display_dispatch(st->display->display);

        usleep(100000);
    }
}

int main(int argc, char *argv[]) {
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    if (init(&state) != 0) {
        fprintf(stderr, "Failed to initialize panel statusbar\n");
        return 1;
    }

    fprintf(stderr, "labwc-statusbar-panel: starting\n");

    run(&state);
    cleanup(&state);

    fprintf(stderr, "labwc-statusbar-panel: stopped\n");

    return 0;
}
