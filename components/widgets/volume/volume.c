/* widgets/volume/volume.c - Volume control widget
 *
 * Displays audio volume with mute status.
 * Uses wpctl (WirePipe) for volume control.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "widget.h"

/* Widget private data */
typedef struct {
    widget_provider_t *vol_provider;
    char level_str[16];
    char status_str[32];
    double level;
    bool muted;
} volume_priv_t;

/* Initialize volume widget */
static int volume_init(widget_context_t *ctx) {
    volume_priv_t *priv = calloc(1, sizeof(volume_priv_t));
    if (!priv) return -1;

    priv->vol_provider = provider_create(PROVIDER_VOLUME);

    ctx->widget->priv = priv;
    ctx->provider_data = priv->vol_provider;

    return 0;
}

/* Update volume data */
static void volume_update(widget_context_t *ctx) {
    volume_priv_t *priv = ctx->widget->priv;
    if (!priv) return;

    provider_update(priv->vol_provider);
    const provider_data_t *data = provider_get_data(priv->vol_provider);

    priv->level = data->volume.level;
    priv->muted = data->volume.muted;

    snprintf(priv->level_str, sizeof(priv->level_str), "%.0f%%", priv->level);
    snprintf(priv->status_str, sizeof(priv->status_str), "%s",
             priv->muted ? "Muted" : "Volume");
}

/* Get volume icon based on level */
static const char *volume_get_icon(const volume_priv_t *priv) {
    if (priv->muted) return nerd_find_icon("volume-mute");

    if (priv->level > 66) return nerd_find_icon("volume-high");
    if (priv->level > 33) return nerd_find_icon("volume-medium");
    if (priv->level > 0) return nerd_find_icon("volume-low");
    return nerd_find_icon("volume-off");
}

/* Get color based on state */
static const char *volume_get_color(const widget_theme_t *theme,
                                    double level, bool muted) {
    if (muted) return theme->red;
    if (level > 80) return theme->yellow;
    return theme->accent;
}

/* Render volume widget */
static void volume_render(widget_context_t *ctx, cairo_t *cr, int width, int height) {
    volume_priv_t *priv = ctx->widget->priv;
    if (!priv || !cr) return;

    /* Clear background */
    cairo_operator_t op = cairo_get_operator(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_set_source_rgba(cr, 0, 0, 0, 0);
    cairo_paint(cr);
    cairo_set_operator(cr, op);

    /* Create layout */
    PangoLayout *layout = pango_cairo_create_layout(cr);

    /* Draw volume icon */
    PangoFontDescription *desc = pango_font_description_from_string("JetBrainsMono Nerd Font");
    pango_font_description_set_size(desc, 13 * PANGO_SCALE);
    pango_layout_set_font_description(layout, desc);

    const char *icon = volume_get_icon(priv);
    if (icon) {
        const char *color = volume_get_color(&ctx->theme, priv->level, priv->muted);
        double r, g, b, a;
        hex_to_rgba(color, &r, &g, &b, &a);
        cairo_set_source_rgba(cr, r, g, b, a);
        cairo_move_to(cr, 4, (height - 13) / 2);
        pango_layout_set_text(layout, icon, -1);
        pango_cairo_show_layout(cr, layout);
    }

    /* Draw level */
    pango_font_description_set_size(desc, 11 * PANGO_SCALE);
    pango_font_description_set_weight(desc, PANGO_WEIGHT_BOLD);
    pango_layout_set_font_description(layout, desc);

    const char *color = volume_get_color(&ctx->theme, priv->level, priv->muted);
    double r, g, b, a;
    hex_to_rgba(color, &r, &g, &b, &a);
    cairo_set_source_rgba(cr, r, g, b, a);

    pango_layout_set_text(layout, priv->level_str, -1);
    PangoRectangle ink;
    pango_layout_get_pixel_extents(layout, &ink, NULL);

    int text_x = icon ? 22 : 4;
    int text_y = (height - ink.height) / 2;
    cairo_move_to(cr, text_x, text_y);
    pango_cairo_show_layout(cr, layout);

    /* Draw status if space allows */
    if (height > 24) {
        pango_font_description_set_size(desc, 9 * PANGO_SCALE);
        pango_font_description_set_weight(desc, PANGO_WEIGHT_NORMAL);
        pango_layout_set_font_description(layout, desc);

        hex_to_rgba(ctx->theme.fg, &r, &g, &b, &a);
        cairo_set_source_rgba(cr, r, g, b, 0.6);

        pango_layout_set_text(layout, priv->status_str, -1);
        cairo_move_to(cr, text_x, text_y + 14);
        pango_cairo_show_layout(cr, layout);
    }

    pango_font_description_free(desc);
    g_object_unref(layout);
}

/* Destroy volume widget */
static void volume_destroy(widget_context_t *ctx) {
    volume_priv_t *priv = ctx->widget->priv;
    if (priv) {
        provider_destroy(priv->vol_provider);
        free(priv);
    }
}

/* Widget operations */
static const widget_ops_t volume_ops = {
    .name = "volume",
    .description = "Audio volume control",
    .init = volume_init,
    .update = volume_update,
    .render = volume_render,
    .destroy = volume_destroy,
};

const widget_ops_t *widget_volume_get_ops(void) {
    return &volume_ops;
}

int main(int argc, char *argv[]) {
    widget_context_t *ctx = widget_context_create(&volume_ops, 80, 32);
    if (!ctx) return 1;

    if (widget_init(ctx) != 0) {
        widget_context_destroy(ctx);
        return 1;
    }

    wayland_display_t *display = wayland_display_create();
    if (!display) {
        widget_context_destroy(ctx);
        return 1;
    }

    wayland_surface_t *surface = wayland_surface_create(
        display, LAYER_TOP,
        LAYER_ANCHOR_TOP | LAYER_ANCHOR_LEFT | LAYER_ANCHOR_RIGHT,
        32, 80, 32);

    if (!surface) {
        wayland_display_destroy(display);
        widget_context_destroy(ctx);
        return 1;
    }

    wayland_surface_set_title(surface, "labwc-volume");

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
