/* widgets/battery/battery.c - Battery status widget
 *
 * Displays battery level and charging status.
 * Reads from /sys/class/power_supply/.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "widget.h"

/* Widget private data */
typedef struct {
    widget_provider_t *bat_provider;
    char level_str[16];
    char status_str[32];
    double level;
    bool charging;
    bool present;
} battery_priv_t;

/* Initialize battery widget */
static int battery_init(widget_context_t *ctx) {
    battery_priv_t *priv = calloc(1, sizeof(battery_priv_t));
    if (!priv) return -1;

    priv->bat_provider = provider_create(PROVIDER_BATTERY);

    ctx->widget->priv = priv;
    ctx->provider_data = priv->bat_provider;

    return 0;
}

/* Update battery data */
static void battery_update(widget_context_t *ctx) {
    battery_priv_t *priv = ctx->widget->priv;
    if (!priv) return;

    provider_update(priv->bat_provider);
    const provider_data_t *data = provider_get_data(priv->bat_provider);

    priv->level = data->battery.charge_percent;
    priv->charging = data->battery.is_charging;
    priv->present = data->battery.is_present;

    if (!priv->present) {
        snprintf(priv->level_str, sizeof(priv->level_str), "--%%");
        snprintf(priv->status_str, sizeof(priv->status_str), "No battery");
    } else {
        snprintf(priv->level_str, sizeof(priv->level_str), "%.0f%%", priv->level);
        snprintf(priv->status_str, sizeof(priv->status_str), "%s",
                 priv->charging ? "Charging" : "On battery");
    }
}

/* Get battery icon based on level */
static const char *battery_get_icon(const battery_priv_t *priv) {
    if (!priv->present) return nerd_find_icon("battery-0");

    if (priv->charging) return nerd_find_icon("battery-charging");

    if (priv->level > 90) return nerd_find_icon("battery-4");
    if (priv->level > 70) return nerd_find_icon("battery-3");
    if (priv->level > 40) return nerd_find_icon("battery-2");
    if (priv->level > 20) return nerd_find_icon("battery-1");
    return nerd_find_icon("battery-0");
}

/* Get color based on level */
static const char *battery_get_color(const widget_theme_t *theme,
                                     double level, bool charging) {
    if (charging) return theme->green;
    if (level < 20) return theme->red;
    if (level < 40) return theme->yellow;
    return theme->yellow;
}

/* Render battery widget */
static void battery_render(widget_context_t *ctx, cairo_t *cr, int width, int height) {
    battery_priv_t *priv = ctx->widget->priv;
    if (!priv || !cr) return;

    /* Hide if no battery */
    if (!priv->present) return;

    /* Clear background */
    cairo_operator_t op = cairo_get_operator(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_set_source_rgba(cr, 0, 0, 0, 0);
    cairo_paint(cr);
    cairo_set_operator(cr, op);

    /* Create layout */
    PangoLayout *layout = pango_cairo_create_layout(cr);

    /* Draw battery icon */
    PangoFontDescription *desc = pango_font_description_from_string("JetBrainsMono Nerd Font");
    pango_font_description_set_size(desc, 13 * PANGO_SCALE);
    pango_layout_set_font_description(layout, desc);

    const char *icon = battery_get_icon(priv);
    if (icon) {
        const char *color = battery_get_color(&ctx->theme, priv->level, priv->charging);
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

    const char *color = battery_get_color(&ctx->theme, priv->level, priv->charging);
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

/* Destroy battery widget */
static void battery_destroy(widget_context_t *ctx) {
    battery_priv_t *priv = ctx->widget->priv;
    if (priv) {
        provider_destroy(priv->bat_provider);
        free(priv);
    }
}

/* Widget operations */
static const widget_ops_t battery_ops = {
    .name = "battery",
    .description = "Battery level and charging status",
    .init = battery_init,
    .update = battery_update,
    .render = battery_render,
    .destroy = battery_destroy,
};

const widget_ops_t *widget_battery_get_ops(void) {
    return &battery_ops;
}

int main(int argc, char *argv[]) {
    widget_context_t *ctx = widget_context_create(&battery_ops, 80, 32);
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

    wayland_surface_set_title(surface, "labwc-battery");

    while (1) {
        widget_update(ctx);
        cairo_t *cr = cairo_create(wayland_surface_get_cairo(surface));
        widget_render(ctx);
        cairo_destroy(cr);
        wayland_surface_commit(surface);
        usleep(10000000);  /* Update every 10 seconds */
    }

    wayland_surface_destroy(surface);
    wayland_display_destroy(display);
    widget_context_destroy(ctx);
    return 0;
}
