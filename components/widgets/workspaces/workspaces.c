/* statusbar/workspaces.c - Workspaces widget */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <wayland-client.h>
#include "widget.h"

/* Workspaces widget data */
typedef struct {
    int workspace_count;
    int current_workspace;
    bool focused;
} workspaces_priv_t;

/* Initialize workspaces widget */
static int workspaces_init(widget_context_t *ctx) {
    workspaces_priv_t *priv = calloc(1, sizeof(workspaces_priv_t));
    if (!priv) return -1;
    
    priv->workspace_count = 9;
    priv->current_workspace = 1;
    
    ctx->widget->priv = priv;
    
    return 0;
}

/* Update workspaces data */
static void workspaces_update(widget_context_t *ctx) {
    workspaces_priv_t *priv = ctx->widget->priv;
    if (!priv) return;
    
    /* Update current workspace based on external state (simplified) */
    priv->current_workspace = (priv->current_workspace % priv->workspace_count) + 1;
    ctx->widget->needs_redraw = true;
}

/* Render workspaces widget */
static void workspaces_render(widget_context_t *ctx, cairo_t *cr, int width, int height) {
    workspaces_priv_t *priv = ctx->widget->priv;
    if (!priv || !cr) return;
    
    /* Clear background */
    cairo_operator_t op = cairo_get_operator(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_set_source_rgba(cr, 0, 0, 0, 0);
    cairo_paint(cr);
    cairo_set_operator(cr, op);
    
    PangoLayout *layout = pango_cairo_create_layout(cr);
    PangoFontDescription *desc = pango_font_description_from_string("JetBrains Mono");
    pango_font_description_set_size(desc, 10 * PANGO_SCALE);
    pango_layout_set_font_description(layout, desc);
    
    /* Render workspaces */
    int x = 4;
    for (int i = 1; i <= priv->workspace_count; i++) {
        bool is_active = (i == priv->current_workspace);
        
        /* Background */
        if (is_active) {
            double r, g, b, a;
            hex_to_rgba(ctx->theme.accent, &r, &g, &b, &a);
            cairo_set_source_rgba(cr, r, g, b, 0.3);
            cairo_rectangle(cr, x, 4, 24, 20);
            cairo_fill(cr);
        }
        
        /* Text */
        char text[8];
        snprintf(text, sizeof(text), "%d", i);
        pango_layout_set_text(layout, text, -1);
        
        double r, g, b, a;
        hex_to_rgba(is_active ? ctx->theme.fg : ctx->theme.border, &r, &g, &b, &a);
        cairo_set_source_rgba(cr, r, g, b, 1.0);
        
        PangoRectangle ink;
        pango_layout_get_pixel_extents(layout, &ink, NULL);
        
        cairo_move_to(cr, x + (24 - ink.width) / 2, 14);
        pango_cairo_show_layout(cr, layout);
        
        x += 28;
    }
    
    pango_font_description_free(desc);
    g_object_unref(layout);
}

/* Destroy workspaces widget */
static void workspaces_destroy(widget_context_t *ctx) {
    if (ctx->widget->priv) {
        free(ctx->widget->priv);
    }
}

/* Widget operations for workspaces */
static const widget_ops_t workspaces_ops = {
    .name = "workspaces",
    .description = "Workspace switcher",
    .init = workspaces_init,
    .update = workspaces_update,
    .render = workspaces_render,
    .destroy = workspaces_destroy,
};

/* Entry point for workspaces widget */
const widget_ops_t *widget_workspaces_get_ops(void) {
    return &workspaces_ops;
}
