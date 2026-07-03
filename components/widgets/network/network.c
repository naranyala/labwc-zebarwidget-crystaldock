/* widgets/network/network.c - Network status widget
 *
 * Displays network connectivity and signal strength.
 * Uses /sys/class/net for basic info, nmcli for details.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "widget.h"

/* Widget private data */
typedef struct {
    widget_provider_t *net_provider;
    char status_str[64];
    char signal_str[16];
    bool connected;
    bool is_wifi;
    double signal;
} network_priv_t;

/* Initialize network widget */
static int network_init(widget_context_t *ctx) {
    network_priv_t *priv = calloc(1, sizeof(network_priv_t));
    if (!priv) return -1;

    priv->net_provider = provider_create(PROVIDER_NETWORK);

    ctx->widget->priv = priv;
    ctx->provider_data = priv->net_provider;

    return 0;
}

/* Update network data */
static void network_update(widget_context_t *ctx) {
    network_priv_t *priv = ctx->widget->priv;
    if (!priv) return;

    provider_update(priv->net_provider);
    const provider_data_t *data = provider_get_data(priv->net_provider);

    priv->connected = data->network.connected;
    priv->is_wifi = data->network.is_wifi;
    priv->signal = data->network.signal_strength;

    if (!priv->connected) {
        snprintf(priv->status_str, sizeof(priv->status_str), "Offline");
        snprintf(priv->signal_str, sizeof(priv->signal_str), "--");
    } else if (priv->is_wifi) {
        snprintf(priv->status_str, sizeof(priv->status_str), "%s",
                 data->network.ssid[0] ? data->network.ssid : "WiFi");
        snprintf(priv->signal_str, sizeof(priv->signal_str), "%.0f%%", priv->signal);
    } else {
        snprintf(priv->status_str, sizeof(priv->status_str), "Ethernet");
        snprintf(priv->signal_str, sizeof(priv->signal_str), "100%%");
    }
}

/* Get signal icon */
static const char *network_get_icon(const network_priv_t *priv) {
    if (!priv->connected) return nerd_find_icon("wifi-off");

    if (priv->is_wifi) {
        if (priv->signal >= 80) return nerd_find_icon("wifi-4");
        if (priv->signal >= 65) return nerd_find_icon("wifi-3");
        if (priv->signal >= 40) return nerd_find_icon("wifi-2");
        if (priv->signal >= 25) return nerd_find_icon("wifi-1");
        return nerd_find_icon("wifi-0");
    }

    return nerd_find_icon("ethernet");
}

/* Get color based on status */
static const char *network_get_color(const widget_theme_t *theme, bool connected) {
    return connected ? theme->accent : theme->red;
}

/* Render network widget */
static void network_render(widget_context_t *ctx, cairo_t *cr, int width, int height) {
    network_priv_t *priv = ctx->widget->priv;
    if (!priv || !cr) return;

    /* Clear background */
    cairo_operator_t op = cairo_get_operator(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_set_source_rgba(cr, 0, 0, 0, 0);
    cairo_paint(cr);
    cairo_set_operator(cr, op);

    /* Create layout */
    PangoLayout *layout = pango_cairo_create_layout(cr);

    /* Draw network icon */
    PangoFontDescription *desc = pango_font_description_from_string("JetBrainsMono Nerd Font");
    pango_font_description_set_size(desc, 13 * PANGO_SCALE);
    pango_layout_set_font_description(layout, desc);

    const char *icon = network_get_icon(priv);
    if (icon) {
        const char *color = network_get_color(&ctx->theme, priv->connected);
        double r, g, b, a;
        hex_to_rgba(color, &r, &g, &b, &a);
        cairo_set_source_rgba(cr, r, g, b, a);
        cairo_move_to(cr, 4, (height - 13) / 2);
        pango_layout_set_text(layout, icon, -1);
        pango_cairo_show_layout(cr, layout);
    }

    /* Draw status text */
    pango_font_description_set_size(desc, 11 * PANGO_SCALE);
    pango_font_description_set_weight(desc, PANGO_WEIGHT_BOLD);
    pango_layout_set_font_description(layout, desc);

    const char *color = network_get_color(&ctx->theme, priv->connected);
    double r, g, b, a;
    hex_to_rgba(color, &r, &g, &b, &a);
    cairo_set_source_rgba(cr, r, g, b, a);

    pango_layout_set_text(layout, priv->status_str, -1);
    PangoRectangle ink;
    pango_layout_get_pixel_extents(layout, &ink, NULL);

    int text_x = icon ? 22 : 4;
    int text_y = (height - ink.height) / 2;
    cairo_move_to(cr, text_x, text_y);
    pango_cairo_show_layout(cr, layout);

    /* Draw signal if space allows */
    if (height > 24) {
        pango_font_description_set_size(desc, 9 * PANGO_SCALE);
        pango_font_description_set_weight(desc, PANGO_WEIGHT_NORMAL);
        pango_layout_set_font_description(layout, desc);

        hex_to_rgba(ctx->theme.fg, &r, &g, &b, &a);
        cairo_set_source_rgba(cr, r, g, b, 0.6);

        pango_layout_set_text(layout, priv->signal_str, -1);
        cairo_move_to(cr, text_x, text_y + 14);
        pango_cairo_show_layout(cr, layout);
    }

    pango_font_description_free(desc);
    g_object_unref(layout);
}

/* Destroy network widget */
static void network_destroy(widget_context_t *ctx) {
    network_priv_t *priv = ctx->widget->priv;
    if (priv) {
        provider_destroy(priv->net_provider);
        free(priv);
    }
}

/* Widget operations */
static const widget_ops_t network_ops = {
    .name = "network",
    .description = "Network connectivity status",
    .init = network_init,
    .update = network_update,
    .render = network_render,
    .destroy = network_destroy,
};

const widget_ops_t *widget_network_get_ops(void) {
    return &network_ops;
}

int main(int argc, char *argv[]) {
    widget_context_t *ctx = widget_context_create(&network_ops, 120, 32);
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
        32, 120, 32);

    if (!surface) {
        wayland_display_destroy(display);
        widget_context_destroy(ctx);
        return 1;
    }

    wayland_surface_set_title(surface, "labwc-network");

    while (1) {
        widget_update(ctx);
        cairo_t *cr = cairo_create(wayland_surface_get_cairo(surface));
        widget_render(ctx);
        cairo_destroy(cr);
        wayland_surface_commit(surface);
        usleep(5000000);  /* Update every 5 seconds */
    }

    wayland_surface_destroy(surface);
    wayland_display_destroy(display);
    widget_context_destroy(ctx);
    return 0;
}
