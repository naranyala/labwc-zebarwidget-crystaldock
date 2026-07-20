// blend2d_render.h — Blend2D rendering abstraction for Wayland SHM buffers
// C implementation called from Zig via @cImport.
#ifndef BLEND2D_RENDER_H
#define BLEND2D_RENDER_H

#include <stdint.h>
#include <stdbool.h>

// Opaque renderer handle (wraps BLImageCore + BLContextCore + fonts)
typedef struct BlendRenderer BlendRenderer;

// Blend2D image type (defined in blend2d/blend2d.h, forward-declared here).
typedef struct BLImageCore BLImageCore;

// Text metrics returned by measureText
typedef struct {
    double width;
    double height;
} TextMetrics;

// Create a renderer that renders to an internal Blend2D image,
// then copies pixels to the given SHM buffer on flush().
BlendRenderer* blend_renderer_create(uint8_t* shm_data, int width, int height, int stride);

// Destroy a renderer and free its resources.
void blend_renderer_destroy(BlendRenderer* r);

// Flush Blend2D operations and copy rendered pixels to the SHM buffer.
void blend_renderer_flush(BlendRenderer* r);

// Draw a filled rectangle.
void blend_renderer_fill_rect(BlendRenderer* r, double x, double y, double w, double h, uint32_t color);

// Draw text at (x, y) with the given color.
void blend_renderer_draw_text(BlendRenderer* r, const char* text, int text_len, double x, double y, uint32_t color);

// Measure text width and height.
TextMetrics blend_renderer_measure_text(BlendRenderer* r, const char* text, int text_len);

// Draw an image at (x, y).
void blend_renderer_draw_image(BlendRenderer* r, void* img, double x, double y);

// Draw an image scaled to fit (w, h) at (x, y).
void blend_renderer_draw_image_scaled(BlendRenderer* r, void* img, double x, double y, double w, double h);

// Draw a filled circle using bezier approximation.
void blend_renderer_draw_circle(BlendRenderer* r, double cx, double cy, double radius, uint32_t color);

// Draw a filled rounded rectangle.
void blend_renderer_fill_round_rect(BlendRenderer* r, double x, double y, double w, double h, double radius, uint32_t color);

// Draw a stroked rounded rectangle border.
void blend_renderer_draw_round_rect(BlendRenderer* r, double x, double y, double w, double h, double radius, uint32_t color);

// Draw a stroked rectangle border.
void blend_renderer_draw_border(BlendRenderer* r, double x, double y, double w, double h, uint32_t color);

// Set the current font size.
void blend_renderer_set_font_size(BlendRenderer* r, double size);

// Get the current font size.
double blend_renderer_get_font_size(BlendRenderer* r);

// Load a bold font, replacing the current font.
void blend_renderer_load_bold_font(BlendRenderer* r);

// Check if a font was successfully loaded.
bool blend_renderer_font_loaded(BlendRenderer* r);

// Write the rendered image to a PNG file.
void blend_renderer_write_to_png(BlendRenderer* r, const char* path);

// Bake a solid-color square icon of `size`x`size` into a newly allocated
// BLImageCore (caller owns it; free with blend_renderer_free_icon).
BLImageCore* blend_renderer_make_icon(uint8_t r, uint8_t g, uint8_t b, uint8_t a, int size);

// Free an icon created by blend_renderer_make_icon.
void blend_renderer_free_icon(BLImageCore* img);

#endif // BLEND2D_RENDER_H
