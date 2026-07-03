/* widgets/clock/clock.c - Clock widget
 *
 * Displays current time and date.
 * Uses Nerd Font icons for decorative elements.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "widget.h"

/* Widget private data */
typedef struct {
    widget_provider_t *date_provider;
    char time_str[32];
    char date_str[64];
    bool show_seconds;
    bool use_24h;
} clock_priv_t;

/* Initialize clock widget */
static int clock_init(widget_context_t *ctx) {
    clock_priv_t *priv = calloc(1, sizeof(clock_priv_t));
    if (!priv) return -1;

    priv->date_provider = provider_create(PROVIDER_DATE);
    priv->show_seconds = true;
    priv->use_24h = true;

    ctx->widget->priv = priv;
    ctx->provider_data = priv->date_provider;

    return 0;
}

/* Update clock data */
static void clock_update(widget_context_t *ctx) {
    clock_priv_t *priv = ctx->widget->priv;
    if (!priv) return;

    provider_update(priv->date_provider);
    const provider_data_t *data = provider_get_data(priv->date_provider);

    /* Format time */
    if (priv->use_24h) {
        snprintf(priv->time_str, sizeof(priv->time_str), "%02d:%02d",
                 data->date.hour, data->date.minute);
    } else {
        int h = data->date.hour % 12;
        if (h == 0) h = 12;
        snprintf(priv->time_str, sizeof(priv->time_str), "%d:%02d %s",
                 h, data->date.minute, data->date.hour < 12 ? "AM" : "PM");
    }

    /* Format date */
    snprintf(priv->date_str, sizeof(priv->date_str), "%s %d %s",
             data->date.formatted, data->date.day,
             (char *[]){"", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}[data->date.month]);
}

/* Render clock widget */
static void clock_render(widget_context_t *ctx, cairo_t *cr, int width, int height) {
    clock_priv_t *priv = ctx->widget->priv;
    if (!priv || !cr) return;

    /* Clear background */
    cairo_operator_t op = cairo_get_operator(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_set_source_rgba(cr, 0, 0, 0, 0);
    cairo_paint(cr);
    cairo_set_operator(cr, op);

    /* Create layout */
    PangoLayout *layout = pango_cairo_create_layout(cr);

    /* Draw time */
    PangoFontDescription *desc = pango_font_description_from_string("JetBrains Mono");
    pango_font_description_set_size(desc, 12 * PANGO_SCALE);
    pango_font_description_set_weight(desc, PANGO_WEIGHT_BOLD);
    pango_layout_set_font_description(layout, desc);

    pango_layout_set_text(layout, priv->time_str, -1);
    PangoRectangle ink;
    pango_layout_get_pixel_extents(layout, &ink, NULL);

    int time_x = (width - ink.width) / 2;
    int time_y = (height - ink.height) / 2;

    /* Draw time text */
    double r, g, b, a;
    hex_to_rgba(ctx->theme.fg, &r, &g, &b, &a);
    cairo_set_source_rgba(cr, r, g, b, a);
    cairo_move_to(cr, time_x, time_y);
    pango_cairo_show_layout(cr, layout);

    /* Draw date below if there's space */
    if (height > 24) {
        pango_font_description_set_size(desc, 10 * PANGO_SCALE);
        pango_font_description_set_weight(desc, PANGO_WEIGHT_NORMAL);
        pango_layout_set_font_description(layout, desc);

        pango_layout_set_text(layout, priv->date_str, -1);
        pango_layout_get_pixel_extents(layout, &ink, NULL);

        int date_x = (width - ink.width) / 2;
        int date_y = time_y + 16;

        hex_to_rgba(ctx->theme.accent, &r, &g, &b, &a);
        cairo_set_source_rgba(cr, r, g, b, a);
        cairo_move_to(cr, date_x, date_y);
        pango_cairo_show_layout(cr, layout);
    }

    pango_font_description_free(desc);
    g_object_unref(layout);
}

/* Destroy clock widget */
static void clock_destroy(widget_context_t *ctx) {
    clock_priv_t *priv = ctx->widget->priv;
    if (priv) {
        provider_destroy(priv->date_provider);
        free(priv);
    }
}

/* Widget operations */
static const widget_ops_t clock_ops = {
    .name = "clock",
    .description = "Real-time clock with date",
    .init = clock_init,
    .update = clock_update,
    .render = clock_render,
    .destroy = clock_destroy,
};

/* Entry point */
const widget_ops_t *widget_clock_get_ops(void) {
    return &clock_ops;
}

int main(int argc, char *argv[]) {
    /* Create widget context */
    widget_context_t *ctx = widget_context_create(&clock_ops, 120, 32);
    if (!ctx) {
        fprintf(stderr, "Failed to create clock widget\n");
        return 1;
    }

    /* Initialize */
    if (widget_init(ctx) != 0) {
        fprintf(stderr, "Failed to initialize clock widget\n");
        widget_context_destroy(ctx);
        return 1;
    }

    /* Create Wayland display */
    wayland_display_t *display = wayland_display_create();
    if (!display) {
        fprintf(stderr, "Failed to create Wayland display\n");
        widget_context_destroy(ctx);
        return 1;
    }

    /* Create layer surface */
    wayland_surface_t *surface = wayland_surface_create(
        display,
        LAYER_TOP,
        LAYER_ANCHOR_TOP | LAYER_ANCHOR_LEFT | LAYER_ANCHOR_RIGHT,
        32,  /* exclusive zone */
        120, /* width */
        32   /* height */
    );

    if (!surface) {
        fprintf(stderr, "Failed to create layer surface\n");
        wayland_display_destroy(display);
        widget_context_destroy(ctx);
        return 1;
    }

    wayland_surface_set_title(surface, "labwc-clock");

    /* Main loop */
    while (1) {
        /* Update widget */
        widget_update(ctx);

        /* Render to surface */
        cairo_t *cr = cairo_create(wayland_surface_get_cairo(surface));
        widget_render(ctx);
        cairo_destroy(cr);

        /* Commit surface */
        wayland_surface_commit(surface);

        /* Sleep 1 second */
        usleep(1000000);
    }

    /* Cleanup */
    wayland_surface_destroy(surface);
    wayland_display_destroy(display);
    widget_context_destroy(ctx);

    return 0;
}
