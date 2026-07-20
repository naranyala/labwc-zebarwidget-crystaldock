// dock_c_impl.c — Includes all real C headers for linking
// Compiles separately from Zig; Zig only sees dock_c.h declarations.

#include <wayland-client.h>
#include <cairo/cairo.h>
#include <pango/pangocairo.h>
#include <librsvg/rsvg.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/timerfd.h>
#include <sys/poll.h>
#include <time.h>

#include "wlr-layer-shell-unstable-v1-client-protocol.h"
#include "wlr-foreign-toplevel-management-unstable-v1-client-protocol.h"

// Shared, backend-agnostic helpers (dock_create_shm_fd, etc.)
#include "../../shared/c/shell_common.inc"

// Icon Loading Helpers
cairo_surface_t* scale_to_size_c(cairo_surface_t* src, int size) {
    int w = cairo_image_surface_get_width(src);
    int h = cairo_image_surface_get_height(src);
    if (w == size && h == size) return src;

    if (w <= 0 || h <= 0 || size <= 0) return src;

    cairo_surface_t* scaled = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, size, size);
    cairo_t* cr = cairo_create(scaled);
    cairo_scale(cr, (double)size / w, (double)size / h);
    cairo_set_source_surface(cr, src, 0, 0);
    cairo_paint(cr);
    cairo_destroy(cr);
    cairo_surface_destroy(src);
    return scaled;
}

cairo_surface_t* load_svg_and_render_c(const char* path, int size) {
    GError* error = NULL;
    RsvgHandle* handle = rsvg_handle_new_from_file(path, &error);
    if (!handle) {
        if (error) g_error_free(error);
        return NULL;
    }

    cairo_surface_t* surf = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, size, size);
    cairo_t* cr = cairo_create(surf);
    
    RsvgRectangle viewport = {0, 0, (double)size, (double)size};
    rsvg_handle_render_document(handle, cr, &viewport, NULL);
    
    cairo_destroy(cr);
    g_object_unref(handle);
    return surf;
}

// Global font-scale factor applied to every text glyph painted by the panel.
// 1.0 = no scaling. Set from the panel config (font_scale) so the whole bar
// rescales together with labwc/GTK/Qt.
double g_font_scale = 1.0;

void widget_set_font_scale(double scale) {
    if (scale > 0.0) g_font_scale = scale;
}

// Apply g_font_scale to a Pango font description parsed from `font_desc`.
static PangoFontDescription* scaled_font(const char* font_desc) {
    PangoFontDescription* font = pango_font_description_from_string(font_desc);
    if (g_font_scale != 1.0) {
        gint size = pango_font_description_get_size(font);
        if (size > 0) {
            pango_font_description_set_size(font, (gint)((double)size * g_font_scale + 0.5));
        }
    }
    return font;
}

int widget_text_c(cairo_t* cr, const char* text, int x, int h, const char* font_desc, double r, double g, double b) {
    PangoLayout* layout = pango_cairo_create_layout(cr);
    PangoFontDescription* font = scaled_font(font_desc);
    pango_layout_set_font_description(layout, font);
    pango_font_description_free(font);
    pango_layout_set_text(layout, text, -1);
    
    int tw = 0, th = 0;
    pango_layout_get_pixel_size(layout, &tw, &th);
    
    cairo_set_source_rgb(cr, r, g, b);
    cairo_move_to(cr, x, (h - th) / 2);
    pango_cairo_show_layout(cr, layout);
    
    g_object_unref(layout);
    return tw;
}

void widget_icon_glyph_c(cairo_t* cr, const char* glyph, int x, int h, double r, double g, double b) {
    PangoLayout* layout = pango_cairo_create_layout(cr);
    PangoFontDescription* font = scaled_font("Sans 11");
    pango_layout_set_font_description(layout, font);
    pango_font_description_free(font);
    pango_layout_set_text(layout, glyph, -1);

    int tw = 0, th = 0;
    pango_layout_get_pixel_size(layout, &tw, &th);

    cairo_set_source_rgb(cr, r, g, b);
    cairo_move_to(cr, x, (h - th) / 2);
    pango_cairo_show_layout(cr, layout);

    g_object_unref(layout);
}

// Measure the pixel width of `text` in `font_desc` without painting. Used by
// widget measure functions so allocated widths match what is actually drawn
// (issue #18 — the old fixed 7px/char heuristic drifted from real glyph widths).
int widget_text_width_c(cairo_t* cr, const char* text, const char* font_desc) {
    PangoLayout* layout = pango_cairo_create_layout(cr);
    PangoFontDescription* font = scaled_font(font_desc);
    pango_layout_set_font_description(layout, font);
    pango_font_description_free(font);
    pango_layout_set_text(layout, text, -1);

    int tw = 0, th = 0;
    pango_layout_get_pixel_size(layout, &tw, &th);

    g_object_unref(layout);
    return tw;
}

