/* widgets/memory/memory.c - Memory monitor widget
 *
 * Displays memory usage with progress bar.
 * Reads from /proc/meminfo for accurate data.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "widget.h"

/* Widget private data */
typedef struct {
    widget_provider_t *mem_provider;
    char usage_str[16];
    char detail_str[32];
    double usage;
    uint64_t used_mb;
    uint64_t total_mb;
    bool show_detail;
} memory_priv_t;

/* Initialize memory widget */
static int memory_init(widget_context_t *ctx) {
    memory_priv_t *priv = calloc(1, sizeof(memory_priv_t));
    if (!priv) return -1;

    priv->mem_provider = provider_create(PROVIDER_MEMORY);
    priv->show_detail = true;

    ctx->widget->priv = priv;
    ctx->provider_data = priv->mem_provider;

    return 0;
}

/* Update memory data */
static void memory_update(widget_context_t *ctx) {
    memory_priv_t *priv = ctx->widget->priv;
    if (!priv) return;

    provider_update(priv->mem_provider);
    const provider_data_t *data = provider_get_data(priv->mem_provider);

    priv->usage = data->memory.usage;
    priv->used_mb = data->memory.used;
    priv->total_mb = data->memory.total;

    snprintf(priv->usage_str, sizeof(priv->usage_str), "%.0f%%", priv->usage);
    snprintf(priv->detail_str, sizeof(priv->detail_str), "%lu/%lu MB",
             priv->used_mb, priv->total_mb);
}

/* Get color based on usage */
static const char *memory_get_color(const widget_theme_t *theme, double usage) {
    if (usage > 90) return theme->red;
    if (usage > 80) return theme->yellow;
    return theme->green;
}

/* Render memory widget */
static void memory_render(widget_context_t *ctx, cairo_t *cr, int width, int height) {
    memory_priv_t *priv = ctx->widget->priv;
    if (!priv || !cr) return;

    /* Clear background */
    cairo_operator_t op = cairo_get_operator(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_set_source_rgba(cr, 0, 0, 0, 0);
    cairo_paint(cr);
    cairo_set_operator(cr, op);

    /* Create layout */
    PangoLayout *layout = pango_cairo_create_layout(cr);

    /* Draw memory icon */
    PangoFontDescription *desc = pango_font_description_from_string("JetBrainsMono Nerd Font");
    pango_font_description_set_size(desc, 13 * PANGO_SCALE);
    pango_layout_set_font_description(layout, desc);

    const char *icon = nerd_find_icon("memory");
    if (icon) {
        double r, g, b, a;
        hex_to_rgba(ctx->theme.green, &r, &g, &b, &a);
        cairo_set_source_rgba(cr, r, g, b, a);
        cairo_move_to(cr, 4, (height - 13) / 2);
        pango_layout_set_text(layout, icon, -1);
        pango_cairo_show_layout(cr, layout);
    }

    /* Draw usage */
    pango_font_description_set_size(desc, 11 * PANGO_SCALE);
    pango_font_description_set_weight(desc, PANGO_WEIGHT_BOLD);
    pango_layout_set_font_description(layout, desc);

    const char *color = memory_get_color(&ctx->theme, priv->usage);
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

    /* Draw detail if space allows */
    if (priv->show_detail && height > 24) {
        pango_font_description_set_size(desc, 9 * PANGO_SCALE);
        pango_font_description_set_weight(desc, PANGO_WEIGHT_NORMAL);
        pango_layout_set_font_description(layout, desc);

        hex_to_rgba(ctx->theme.fg, &r, &g, &b, &a);
        cairo_set_source_rgba(cr, r, g, b, 0.6);

        pango_layout_set_text(layout, priv->detail_str, -1);
        cairo_move_to(cr, text_x, text_y + 14);
        pango_cairo_show_layout(cr, layout);
    }

    pango_font_description_free(desc);
    g_object_unref(layout);
}

/* Destroy memory widget */
static void memory_destroy(widget_context_t *ctx) {
    memory_priv_t *priv = ctx->widget->priv;
    if (priv) {
        provider_destroy(priv->mem_provider);
        free(priv);
    }
}

/* Widget operations */
static const widget_ops_t memory_ops = {
    .name = "memory",
    .description = "Memory usage monitor",
    .init = memory_init,
    .update = memory_update,
    .render = memory_render,
    .destroy = memory_destroy,
};

/* Entry point */
const widget_ops_t *widget_memory_get_ops(void) {
    return &memory_ops;
}

int main(int argc, char *argv[]) {
    widget_context_t *ctx = widget_context_create(&memory_ops, 80, 32);
    if (!ctx) {
        fprintf(stderr, "Failed to create memory widget\n");
        return 1;
    }

    if (widget_init(ctx) != 0) {
        fprintf(stderr, "Failed to initialize memory widget\n");
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

    wayland_surface_set_title(surface, "labwc-memory");

    while (1) {
        widget_update(ctx);

        cairo_t *cr = cairo_create(wayland_surface_get_cairo(surface));
        widget_render(ctx);
        cairo_destroy(cr);

        wayland_surface_commit(surface);
        usleep(3000000);  /* Update every 3 seconds */
    }

    wayland_surface_destroy(surface);
    wayland_display_destroy(display);
    widget_context_destroy(ctx);

    return 0;
}
