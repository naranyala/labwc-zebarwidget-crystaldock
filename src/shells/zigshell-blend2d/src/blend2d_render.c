// blend2d_render.c — Blend2D rendering abstraction for Wayland SHM buffers
// Renders to an internal Blend2D image, then copies pixels to the SHM buffer.

#include "blend2d_render.h"
#include "blend2d/blend2d.h"
#include <string.h>
#include <stdlib.h>
#include <math.h>

struct BlendRenderer {
    BLImageCore image;
    BLContextCore ctx;
    BLFontFaceCore font_face;
    BLFontCore font;
    uint8_t* shm_data;
    int buf_width;
    int buf_height;
    int stride;
    bool initialized;
    bool font_loaded;
};

// Font search paths (ordered by distro preference)
static const char* font_paths[] = {
    // Debian/Ubuntu
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    // Fedora/RHEL
    "/usr/share/fonts/TTF/DejaVuSans.ttf",
    "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/TTF/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/TTF/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf",
    // Arch
    "/usr/share/fonts/noto/NotoSans-Regular.ttf",
    "/usr/share/fonts/google-noto/NotoSans-Regular.ttf",
    "/usr/share/fonts/google-noto/NotoSans-Bold.ttf",
    // OpenMandriva
    "/usr/share/fonts/gnu-free/FreeSans.ttf",
    // User-local fonts
    "/home/naranyala/.local/share/fonts/JetBrainsMonoNerdFontMono-Regular.ttf",
    "/home/naranyala/.local/share/fonts/JetBrainsMonoNerdFont-Regular.ttf",
    "/home/naranyala/.local/share/fonts/noto-sans-mono/NotoSansMono.ttf",
    // Generic fallbacks
    "/usr/share/fonts/truetype/freefont/FreeSans.ttf",
    "/usr/share/fonts/truetype/ubuntu/Ubuntu-R.ttf",
    "/usr/share/fonts/truetype/ubuntu/Ubuntu-B.ttf",
    NULL
};

static const char* bold_paths[] = {
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/usr/share/fonts/google-noto/NotoSans-Bold.ttf",
    "/usr/share/fonts/truetype/ubuntu/Ubuntu-B.ttf",
    NULL
};

static void load_default_font(BlendRenderer* r) {
    // Initialize font structures
    bl_font_face_init(&r->font_face);
    bl_font_init(&r->font);

    for (int i = 0; font_paths[i] != NULL; i++) {
        if (bl_font_face_create_from_file(&r->font_face, font_paths[i], 0) == BL_SUCCESS) {
            if (bl_font_create_from_face(&r->font, &r->font_face, 11.0) == BL_SUCCESS) {
                r->font_loaded = true;
                return;
            }
            bl_font_face_destroy(&r->font_face);
            bl_font_face_init(&r->font_face);
        }
    }
    // No font found — keep initialized but empty
}

BlendRenderer* blend_renderer_create(uint8_t* shm_data, int width, int height, int stride) {
    BlendRenderer* r = calloc(1, sizeof(BlendRenderer));
    if (!r) return NULL;

    r->shm_data = shm_data;
    r->buf_width = width;
    r->buf_height = height;
    r->stride = stride;

    // Create internal Blend2D image
    if (bl_image_init_as(&r->image, width, height, BL_FORMAT_PRGB32) != BL_SUCCESS) {
        free(r);
        return NULL;
    }

    // Create rendering context
    if (bl_context_init_as(&r->ctx, &r->image, NULL) != BL_SUCCESS) {
        bl_image_destroy(&r->image);
        free(r);
        return NULL;
    }

    load_default_font(r);
    r->initialized = true;
    return r;
}

void blend_renderer_destroy(BlendRenderer* r) {
    if (!r || !r->initialized) return;
    bl_context_end(&r->ctx);
    bl_context_destroy(&r->ctx);
    if (r->font_loaded) {
        bl_font_destroy(&r->font);
        bl_font_face_destroy(&r->font_face);
    }
    bl_image_destroy(&r->image);
    r->initialized = false;
    free(r);
}

// Bake a solid-color square icon into a freshly allocated BLImageCore.
BLImageCore* blend_renderer_make_icon(uint8_t r, uint8_t g, uint8_t b, uint8_t a, int size) {
    BLImageCore* img = (BLImageCore*)calloc(1, sizeof(BLImageCore));
    if (!img) return NULL;
    if (bl_image_init_as(img, size, size, BL_FORMAT_PRGB32) != BL_SUCCESS) {
        free(img);
        return NULL;
    }
    BLContextCore ctx;
    if (bl_context_init_as(&ctx, img, NULL) != BL_SUCCESS) {
        bl_image_destroy(img);
        free(img);
        return NULL;
    }
    uint32_t color = ((uint32_t)a << 24) | ((uint32_t)r << 16) | ((uint32_t)g << 8) | (uint32_t)b;
    bl_context_set_fill_style_rgba32(&ctx, color);
    BLRectI rect = { 0, 0, size, size };
    bl_context_fill_rect_i(&ctx, &rect);
    bl_context_end(&ctx);
    bl_context_destroy(&ctx);
    return img;
}

void blend_renderer_free_icon(BLImageCore* img) {
    if (!img) return;
    bl_image_destroy(img);
    free(img);
}

void blend_renderer_flush(BlendRenderer* r) {
    if (!r || !r->initialized || !r->shm_data) return;

    bl_context_flush(&r->ctx, BL_CONTEXT_FLUSH_SYNC);

    BLImageData img_data;
    if (bl_image_make_mutable(&r->image, &img_data) != BL_SUCCESS) return;

    const uint8_t* src = (const uint8_t*)img_data.pixel_data;
    intptr_t src_stride = img_data.stride < 0 ? -img_data.stride : img_data.stride;
    uint8_t* dst = r->shm_data;
    intptr_t dst_stride = r->stride;
    size_t row_bytes = (size_t)r->buf_width * 4;

    for (int row = 0; row < r->buf_height; row++) {
        memcpy(dst + row * dst_stride, src + row * src_stride, row_bytes);
    }
}

void blend_renderer_fill_rect(BlendRenderer* r, double x, double y, double w, double h, uint32_t color) {
    if (!r || !r->initialized) return;
    BLRect rect = { x, y, w, h };
    bl_context_set_fill_style_rgba32(&r->ctx, color);
    bl_context_fill_rect_d(&r->ctx, &rect);
}

void blend_renderer_draw_text(BlendRenderer* r, const char* text, int text_len, double x, double y, uint32_t color) {
    if (!r || !r->initialized || !text || text_len <= 0 || !r->font_loaded) return;

    BLGlyphBufferCore gb;
    bl_glyph_buffer_init(&gb);
    bl_glyph_buffer_set_text(&gb, text, (size_t)text_len, BL_TEXT_ENCODING_UTF8);
    bl_font_shape(&r->font, &gb);

    const BLGlyphRun* glyph_run = bl_glyph_buffer_get_glyph_run(&gb);
    BLPoint origin = { x, y };
    bl_context_set_fill_style_rgba32(&r->ctx, color);
    bl_context_fill_glyph_run_d(&r->ctx, &origin, &r->font, glyph_run);

    bl_glyph_buffer_destroy(&gb);
}

TextMetrics blend_renderer_measure_text(BlendRenderer* r, const char* text, int text_len) {
    TextMetrics tm = { 0, 0 };
    if (!r || !r->initialized || !text || text_len <= 0 || !r->font_loaded) return tm;

    BLGlyphBufferCore gb;
    bl_glyph_buffer_init(&gb);
    bl_glyph_buffer_set_text(&gb, text, (size_t)text_len, BL_TEXT_ENCODING_UTF8);
    bl_font_shape(&r->font, &gb);

    BLTextMetrics btm;
    bl_font_get_text_metrics(&r->font, &gb, &btm);

    tm.width = btm.bounding_box.x1 - btm.bounding_box.x0;
    tm.height = btm.bounding_box.y1 - btm.bounding_box.y0;

    bl_glyph_buffer_destroy(&gb);
    return tm;
}

void blend_renderer_draw_image(BlendRenderer* r, void* img, double x, double y) {
    if (!r || !r->initialized || !img) return;
    BLPoint origin = { x, y };
    bl_context_blit_image_d(&r->ctx, &origin, (BLImageCore*)img, NULL);
}

void blend_renderer_draw_image_scaled(BlendRenderer* r, void* img, double x, double y, double w, double h) {
    if (!r || !r->initialized || !img) return;
    BLImageCore* image = (BLImageCore*)img;
    BLRect dst_rect = { x, y, w, h };
    bl_context_blit_scaled_image_d(&r->ctx, &dst_rect, image, NULL);
}

void blend_renderer_draw_circle(BlendRenderer* r, double cx, double cy, double radius, uint32_t color) {
    if (!r || !r->initialized) return;

    BLPathCore path;
    bl_path_init(&path);

    const double kappa = 0.5522847498;
    bl_path_move_to(&path, cx + radius, cy);
    bl_path_cubic_to(&path, cx + radius, cy + radius * kappa, cx + radius * kappa, cy + radius, cx, cy + radius);
    bl_path_cubic_to(&path, cx - radius * kappa, cy + radius, cx - radius, cy + radius * kappa, cx - radius, cy);
    bl_path_cubic_to(&path, cx - radius, cy - radius * kappa, cx - radius * kappa, cy - radius, cx, cy - radius);
    bl_path_cubic_to(&path, cx + radius * kappa, cy - radius, cx + radius, cy - radius * kappa, cx + radius, cy);
    bl_path_close(&path);

    bl_context_set_fill_style_rgba32(&r->ctx, color);
    BLPoint origin = { 0, 0 };
    bl_context_fill_path_d(&r->ctx, &origin, &path);

    bl_path_destroy(&path);
}

static void build_round_rect_path(BLPathCore* path, double x, double y, double w, double h, double r) {
    bl_path_move_to(path, x + r, y);
    bl_path_line_to(path, x + w - r, y);
    bl_path_quad_to(path, x + w, y, x + w, y + r);
    bl_path_line_to(path, x + w, y + h - r);
    bl_path_quad_to(path, x + w, y + h, x + w - r, y + h);
    bl_path_line_to(path, x + r, y + h);
    bl_path_quad_to(path, x, y + h, x, y + h - r);
    bl_path_line_to(path, x, y + r);
    bl_path_quad_to(path, x, y, x + r, y);
    bl_path_close(path);
}

void blend_renderer_fill_round_rect(BlendRenderer* r, double x, double y, double w, double h, double radius, uint32_t color) {
    if (!r || !r->initialized) return;
    BLPathCore path;
    bl_path_init(&path);
    build_round_rect_path(&path, x, y, w, h, radius);
    bl_context_set_fill_style_rgba32(&r->ctx, color);
    BLPoint origin = { 0, 0 };
    bl_context_fill_path_d(&r->ctx, &origin, &path);
    bl_path_destroy(&path);
}

void blend_renderer_draw_round_rect(BlendRenderer* r, double x, double y, double w, double h, double radius, uint32_t color) {
    if (!r || !r->initialized) return;
    BLPathCore path;
    bl_path_init(&path);
    build_round_rect_path(&path, x, y, w, h, radius);
    bl_context_set_stroke_style_rgba32(&r->ctx, color);
    bl_context_set_stroke_width(&r->ctx, 1.0);
    BLPoint origin = { 0, 0 };
    bl_context_stroke_path_d(&r->ctx, &origin, &path);
    bl_path_destroy(&path);
}

void blend_renderer_draw_border(BlendRenderer* r, double x, double y, double w, double h, uint32_t color) {
    if (!r || !r->initialized) return;
    bl_context_set_stroke_style_rgba32(&r->ctx, color);
    bl_context_set_stroke_width(&r->ctx, 1.0);
    BLRect rect = { x, y, w, h };
    bl_context_stroke_rect_d(&r->ctx, &rect);
}

void blend_renderer_set_font_size(BlendRenderer* r, double size) {
    if (!r || !r->initialized) return;
    bl_font_set_size(&r->font, (float)size);
}

double blend_renderer_get_font_size(BlendRenderer* r) {
    if (!r || !r->initialized) return 0;
    return (double)bl_font_get_size(&r->font);
}

void blend_renderer_load_bold_font(BlendRenderer* r) {
    if (!r || !r->initialized || !r->font_loaded) return;

    BLFontFaceCore bold_face;
    bl_font_face_init(&bold_face);
    double current_size = bl_font_get_size(&r->font);

    for (int i = 0; bold_paths[i] != NULL; i++) {
        if (bl_font_face_create_from_file(&bold_face, bold_paths[i], 0) == BL_SUCCESS) {
            // Try to create bold font; on failure, keep the original.
            if (bl_font_create_from_face(&r->font, &bold_face, (float)current_size) == BL_SUCCESS) {
                bl_font_face_destroy(&bold_face);
                return;
            }
            bl_font_face_destroy(&bold_face);
            bl_font_face_init(&bold_face);
        }
    }
}

bool blend_renderer_font_loaded(BlendRenderer* r) {
    return r ? r->font_loaded : false;
}

void blend_renderer_write_to_png(BlendRenderer* r, const char* path) {
    if (!r || !r->initialized || !path) return;
    
    bl_context_flush(&r->ctx, BL_CONTEXT_FLUSH_SYNC);

    BLImageCodecCore codec;
    bl_image_codec_init(&codec);
    if (bl_image_codec_find_by_name(&codec, "PNG", SIZE_MAX, NULL) == BL_SUCCESS) {
        bl_image_write_to_file(&r->image, path, &codec);
    } else {
        bl_image_write_to_file(&r->image, path, NULL);
    }
    bl_image_codec_destroy(&codec);
}
