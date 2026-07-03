/* widgets/cpu/cpu.c - CPU monitor widget
 *
 * Displays CPU usage with color-coded status.
 * Reads from /proc/stat for accurate usage data.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "widget.h"

/* Widget private data */
typedef struct {
    widget_provider_t *cpu_provider;
    char usage_str[16];
    char cores_str[16];
    double usage;
    int cores;
    bool show_cores;
} cpu_priv_t;

/* Initialize CPU widget */
static int cpu_init(widget_context_t *ctx) {
    cpu_priv_t *priv = calloc(1, sizeof(cpu_priv_t));
    if (!priv) return -1;

    priv->cpu_provider = provider_create(PROVIDER_CPU);
    priv->show_cores = true;

    ctx->widget->priv = priv;
    ctx->provider_data = priv->cpu_provider;

    return 0;
}

/* Update CPU data */
static void cpu_update(widget_context_t *ctx) {
    cpu_priv_t *priv = ctx->widget->priv;
    if (!priv) return;

    provider_update(priv->cpu_provider);
    const provider_data_t *data = provider_get_data(priv->cpu_provider);

    priv->usage = data->cpu.usage;
    priv->cores = data->cpu.cores;

    snprintf(priv->usage_str, sizeof(priv->usage_str), "%.0f%%", priv->usage);
    snprintf(priv->cores_str, sizeof(priv->cores_str), "%d cores", priv->cores);
}

/* Get color based on usage */
static const char *cpu_get_color(const widget_theme_t *theme, double usage) {
    if (usage > 85) return theme->red;
    if (usage > 70) return theme->yellow;
    return theme->accent;
}

/* Render CPU widget */
static void cpu_render(widget_context_t *ctx, cairo_t *cr, int width, int height) {
    cpu_priv_t *priv = ctx->widget->priv;
    if (!priv || !cr) return;

    /* Clear background */
    cairo_operator_t op = cairo_get_operator(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_set_source_rgba(cr, 0, 0, 0, 0);
    cairo_paint(cr);
    cairo_set_operator(cr, op);

    /* Create layout */
    PangoLayout *layout = pango_cairo_create_layout(cr);

    /* Draw CPU icon */
    PangoFontDescription *desc = pango_font_description_from_string("JetBrainsMono Nerd Font");
    pango_font_description_set_size(desc, 13 * PANGO_SCALE);
    pango_layout_set_font_description(layout, desc);

    const char *icon = nerd_find_icon("cpu");
    if (icon) {
        double r, g, b, a;
        hex_to_rgba(ctx->theme.accent, &r, &g, &b, &a);
        cairo_set_source_rgba(cr, r, g, b, a);
        cairo_move_to(cr, 4, (height - 13) / 2);
        pango_layout_set_text(layout, icon, -1);
        pango_cairo_show_layout(cr, layout);
    }

    /* Draw usage */
    pango_font_description_set_size(desc, 11 * PANGO_SCALE);
    pango_font_description_set_weight(desc, PANGO_WEIGHT_BOLD);
    pango_layout_set_font_description(layout, desc);

    const char *color = cpu_get_color(&ctx->theme, priv->usage);
    double r, g, b, a;
    hex_to_rgba(color, &r, &g, &b, &a);
    cairo_set_source_rgba(cr, r, g, b, a);

    pango_layout_set_text(layout, priv->usage_str, -1);
    PangoRectangle ink;
    pango_layout_get_pixel_extents(layout, &ink, NULL);

    int text_x = icon ? 22 : 4;
    int text_y = (height - ink.height) / 2;
    cairo_move_to(cr, text_x, text_y);
    pango_cairo_show_layout(cr, layout);

    /* Draw cores if space allows */
    if (priv->show_cores && height > 24) {
        pango_font_description_set_size(desc, 9 * PANGO_SCALE);
        pango_font_description_set_weight(desc, PANGO_WEIGHT_NORMAL);
        pango_layout_set_font_description(layout, desc);

        hex_to_rgba(ctx->theme.fg, &r, &g, &b, &a);
        cairo_set_source_rgba(cr, r, g, b, 0.6);

        pango_layout_set_text(layout, priv->cores_str, -1);
        cairo_move_to(cr, text_x, text_y + 14);
        pango_cairo_show_layout(cr, layout);
    }

    pango_font_description_free(desc);
    g_object_unref(layout);
}

/* Destroy CPU widget */
static void cpu_destroy(widget_context_t *ctx) {
    cpu_priv_t *priv = ctx->widget->priv;
    if (priv) {
        provider_destroy(priv->cpu_provider);
        free(priv);
    }
}

/* Widget operations */
static const widget_ops_t cpu_ops = {
    .name = "cpu",
    .description = "CPU usage monitor",
    .init = cpu_init,
    .update = cpu_update,
    .render = cpu_render,
    .destroy = cpu_destroy,
};

/* Entry point */
const widget_ops_t *widget_cpu_get_ops(void) {
    return &cpu_ops;
}

int main(int argc, char *argv[]) {
    widget_context_t *ctx = widget_context_create(&cpu_ops, 80, 32);
    if (!ctx) {
        fprintf(stderr, "Failed to create CPU widget\n");
        return 1;
    }

    if (widget_init(ctx) != 0) {
        fprintf(stderr, "Failed to initialize CPU widget\n");
        widget_context_destroy(ctx);
        return 1;
    }

    wayland_display_t *display = wayland_display_create();
    if (!display) {
        fprintf(stderr, "Failed to create Wayland display\n");
        widget_context_destroy(ctx);
        return 1;
    }

    wayland_surface_t *surface = wayland_surface_create(
        display,
        LAYER_TOP,
        LAYER_ANCHOR_TOP | LAYER_ANCHOR_LEFT | LAYER_ANCHOR_RIGHT,
        32,
        80,
        32
    );

    if (!surface) {
        fprintf(stderr, "Failed to create layer surface\n");
        wayland_display_destroy(display);
        widget_context_destroy(ctx);
        return 1;
    }

    wayland_surface_set_title(surface, "labwc-cpu");

    while (1) {
        widget_update(ctx);

        cairo_t *cr = cairo_create(wayland_surface_get_cairo(surface));
        widget_render(ctx);
        cairo_destroy(cr);

        wayland_surface_commit(surface);
        usleep(2000000);  /* Update every 2 seconds */
    }

    wayland_surface_destroy(surface);
    wayland_display_destroy(display);
    widget_context_destroy(ctx);

    return 0;
}
