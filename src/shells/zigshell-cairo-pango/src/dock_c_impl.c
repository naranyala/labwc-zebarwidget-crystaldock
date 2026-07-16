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

    gboolean has_w = FALSE, has_h = FALSE, has_vb = FALSE;
    RsvgLength rsvg_w, rsvg_h;
    RsvgRectangle vb = {0, 0, (double)size, (double)size};
    
    rsvg_handle_get_intrinsic_dimensions(handle, &has_w, &rsvg_w, &has_h, &rsvg_h, &has_vb, &vb);

    double sw = (has_vb) ? vb.width : ((has_w && has_h) ? rsvg_w.length : size);
    double sh = (has_vb) ? vb.height : ((has_w && has_h) ? rsvg_h.length : size);

    if (sw <= 0 || sh <= 0) {
        sw = size;
        sh = size;
    }

    cairo_surface_t* surf = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, size, size);
    cairo_t* cr = cairo_create(surf);
    
    double scale = ((double)size / sw < (double)size / sh) ? ((double)size / sw) : ((double)size / sh);
    double ox = (size - sw * scale) / 2.0;
    double oy = (size - sh * scale) / 2.0;
    
    cairo_translate(cr, ox, oy);
    cairo_scale(cr, scale, scale);
    
    RsvgRectangle viewport = {0, 0, sw, sh};
    rsvg_handle_render_document(handle, cr, &viewport, NULL);
    
    cairo_destroy(cr);
    g_object_unref(handle);
    return surf;
}

int widget_text_c(cairo_t* cr, const char* text, int x, int h, const char* font_desc, double r, double g, double b) {
    PangoLayout* layout = pango_cairo_create_layout(cr);
    PangoFontDescription* font = pango_font_description_from_string(font_desc);
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
    PangoFontDescription* font = pango_font_description_from_string("Sans 11");
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
