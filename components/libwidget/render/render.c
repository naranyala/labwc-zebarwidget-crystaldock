/* render/render.c - Cairo/Pango rendering helpers */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <cairo.h>
#include <pango/pangocairo.h>
#include "widget.h"

/* ============================================================================
 * Color Conversion
 * ============================================================================ */

void hex_to_rgba(const char *hex, double *r, double *g, double *b, double *a) {
    if (!hex || !r || !g || !b || !a) return;

    /* Skip # prefix */
    if (hex[0] == '#') hex++;

    int len = strlen(hex);
    if (len == 6 || len == 8) {
        unsigned int rv, gv, bv, av = 255;
        sscanf(hex, "%02x%02x%02x", &rv, &gv, &bv);
        if (len == 8) {
            sscanf(hex + 6, "%02x", &av);
        }
        *r = rv / 255.0;
        *g = gv / 255.0;
        *b = bv / 255.0;
        *a = av / 255.0;
    } else {
        /* Default to white */
        *r = *g = *b = *a = 1.0;
    }
}

/* ============================================================================
 * Text Rendering
 * ============================================================================ */

PangoLayout *render_create_layout(cairo_t *cr, const char *font, int size) {
    if (!cr) return NULL;

    PangoLayout *layout = pango_cairo_create_layout(cr);
    if (!layout) return NULL;

    PangoFontDescription *desc = pango_font_description_from_string(font);
    if (desc) {
        pango_font_description_set_size(desc, size * PANGO_SCALE);
        pango_layout_set_font_description(layout, desc);
        pango_font_description_free(desc);
    }

    return layout;
}

void render_text(cairo_t *cr, PangoLayout *layout,
                 int x, int y, const char *text,
                 const char *color, int font_size) {
    if (!cr || !layout || !text) return;

    /* Set text */
    pango_layout_set_text(layout, text, -1);

    /* Set color */
    double r, g, b, a;
    hex_to_rgba(color, &r, &g, &b, &a);
    cairo_set_source_rgba(cr, r, g, b, a);

    /* Move to position and render */
    cairo_move_to(cr, x, y);
    pango_cairo_show_layout(cr, layout);
}

void render_icon(cairo_t *cr, PangoLayout *layout,
                 int x, int y, const char *icon,
                 const char *color, int font_size) {
    /* Icons are rendered as text using Nerd Fonts */
    render_text(cr, layout, x, y, icon, color, font_size);
}

/* ============================================================================
 * Shape Rendering
 * ============================================================================ */

void render_rounded_rect(cairo_t *cr,
                         double x, double y, double w, double h,
                         double radius, const char *color, double alpha) {
    if (!cr) return;

    double r, g, b, a;
    hex_to_rgba(color, &r, &g, &b, &a);
    cairo_set_source_rgba(cr, r, g, b, alpha);

    /* Draw rounded rectangle */
    cairo_new_sub_path(cr);
    cairo_arc(cr, x + w - radius, y + radius, radius, -M_PI / 2, 0);
    cairo_arc(cr, x + w - radius, y + h - radius, radius, 0, M_PI / 2);
    cairo_arc(cr, x + radius, y + h - radius, radius, M_PI / 2, M_PI);
    cairo_arc(cr, x + radius, y + radius, radius, M_PI, 3 * M_PI / 2);
    cairo_close_path(cr);

    cairo_fill(cr);
}

void render_progress_bar(cairo_t *cr,
                         double x, double y, double w, double h,
                         double progress, const char *bg_color, const char *fg_color) {
    if (!cr) return;

    /* Background */
    render_rounded_rect(cr, x, y, w, h, h / 2, bg_color, 0.3);

    /* Foreground */
    if (progress > 0) {
        double fw = w * (progress / 100.0);
        if (fw > h) {
            render_rounded_rect(cr, x, y, fw, h, h / 2, fg_color, 0.8);
        }
    }
}

/* ============================================================================
 * Module Rendering (for statusbar modules)
 * ============================================================================ */

typedef struct {
    int x, y;
    int width, height;
    int padding;
    char bg_color[32];
    double bg_alpha;
} module_state_t;

void render_module_begin(cairo_t *cr, module_state_t *state,
                         int x, int y, const char *bg_color) {
    if (!cr || !state) return;

    state->x = x;
    state->y = y;
    state->padding = 8;
    strcpy(state->bg_color, bg_color);
    state->bg_alpha = 0.4;

    /* Draw module background */
    render_rounded_rect(cr, x, y, 0, 24, 4, bg_color, state->bg_alpha);
}

void render_module_end(cairo_t *cr, module_state_t *state, int content_width) {
    if (!cr || !state) return;

    int total_width = content_width + state->padding * 2;

    /* Redraw with correct width */
    /* First clear, then draw */
    /* TODO: Implement proper double-buffering */

    state->width = total_width;
}

/* ============================================================================
 * Workspace Rendering
 * ============================================================================ */

void render_workspace_button(cairo_t *cr, PangoLayout *layout,
                             int x, int y, int num, bool active, bool occupied,
                             const widget_theme_t *theme) {
    if (!cr || !layout) return;

    int btn_width = 24;
    int btn_height = 20;
    int padding = 2;

    /* Background */
    const char *bg;
    double bg_alpha;
    if (active) {
        bg = theme->accent;
        bg_alpha = 1.0;
    } else if (occupied) {
        bg = theme->surface;
        bg_alpha = 0.6;
    } else {
        bg = theme->surface;
        bg_alpha = 0.3;
    }

    render_rounded_rect(cr, x, y, btn_width, btn_height, 4, bg, bg_alpha);

    /* Text */
    char num_str[4];
    snprintf(num_str, sizeof(num_str), "%d", num);

    const char *text_color = active ? theme->bg : theme->fg;
    PangoFontDescription *desc = pango_font_description_from_string("monospace");
    pango_font_description_set_size(desc, 11 * PANGO_SCALE);
    pango_layout_set_font_description(layout, desc);
    pango_font_description_free(desc);

    pango_layout_set_text(layout, num_str, -1);
    PangoRectangle ink;
    pango_layout_get_pixel_extents(layout, &ink, NULL);

    int text_x = x + (btn_width - ink.width) / 2;
    int text_y = y + (btn_height - ink.height) / 2;

    render_text(cr, layout, text_x, text_y, num_str, text_color, 11);
}
