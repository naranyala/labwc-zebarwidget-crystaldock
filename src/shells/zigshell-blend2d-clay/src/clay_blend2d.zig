// clay_blend2d.zig — Maps Clay render commands (via C accessors) to Blend2D

const std = @import("std");
const c = @import("c.zig");
const blend2d = @import("blend2d_render.zig");

/// Convert Clay Color (f32 0-255) to packed ARGB u32 for Blend2D.
inline fn colorToArgb(r: f32, g: f32, b: f32, a: f32) u32 {
    const ri: u32 = @intFromFloat(@max(0, @min(255, r)));
    const gi: u32 = @intFromFloat(@max(0, @min(255, g)));
    const bi: u32 = @intFromFloat(@max(0, @min(255, b)));
    const ai: u32 = @intFromFloat(@max(0, @min(255, a)));
    return (ai << 24) | (ri << 16) | (gi << 8) | bi;
}

/// Current scissor clip rect (0,0,0,0 = no clip).
var clip_x: f32 = 0;
var clip_y: f32 = 0;
var clip_w: f32 = 0;
var clip_h: f32 = 0;

fn outOfClip(x: f32, y: f32, w: f32, h: f32) bool {
    if ((clip_w <= 0) or (clip_h <= 0)) return false;
    return x + w <= clip_x or x >= clip_x + clip_w or
           y + h <= clip_y or y >= clip_y + clip_h;
}

/// Render all flattened Clay commands to a BlendRenderer.
pub fn renderAll(renderer: *blend2d.BlendRenderer) void {
    const count = c.clay.clay_cmd_count();
    for (0..@intCast(count)) |i| {
        const idx: c_int = @intCast(i);
        const cmd_type = c.clay.clay_cmd_type(idx);

        const x = c.clay.clay_cmd_x(idx);
        const y = c.clay.clay_cmd_y(idx);
        const w = c.clay.clay_cmd_w(idx);
        const h = c.clay.clay_cmd_h(idx);

        switch (cmd_type) {
            1 => { // RECTANGLE
                if (outOfClip(x, y, w, h)) continue;
                const color = colorToArgb(
                    c.clay.clay_cmd_bg_r(idx),
                    c.clay.clay_cmd_bg_g(idx),
                    c.clay.clay_cmd_bg_b(idx),
                    c.clay.clay_cmd_bg_a(idx),
                );
                const radius = c.clay.clay_cmd_radius(idx);
                if (radius > 0.5) {
                    renderer.fillRoundRect(x, y, w, h, radius, color);
                } else {
                    renderer.fillRect(x, y, w, h, color);
                }
            },
            2 => { // BORDER
                if (outOfClip(x, y, w, h)) continue;
                const color = colorToArgb(
                    c.clay.clay_cmd_border_r(idx),
                    c.clay.clay_cmd_border_g(idx),
                    c.clay.clay_cmd_border_b(idx),
                    c.clay.clay_cmd_border_a(idx),
                );
                renderer.drawBorder(x, y, w, h, color);
            },
            3 => { // TEXT
                if (outOfClip(x, y, w, h)) continue;
                const text_len = c.clay.clay_cmd_text_len(idx);
                if (text_len > 0) {
                    const text_ptr = c.clay.clay_cmd_text_ptr(idx);
                    const text_color = colorToArgb(
                        c.clay.clay_cmd_text_r(idx),
                        c.clay.clay_cmd_text_g(idx),
                        c.clay.clay_cmd_text_b(idx),
                        c.clay.clay_cmd_text_a(idx),
                    );
                    const font_size = c.clay.clay_cmd_font_size(idx);
                    if (font_size > 0) {
                        renderer.setFontSize(@floatFromInt(font_size));
                    }
                    const slice: []const u8 = @ptrCast(text_ptr[0..@intCast(text_len)]);
                    renderer.drawText(slice, x, y, text_color);
                }
            },
            4 => { // IMAGE
                if (outOfClip(x, y, w, h)) continue;
                const img = c.clay.clay_cmd_img(idx);
                if (img) |im| {
                    renderer.drawImageScaled(im, x, y, w, h);
                }
            },
            5 => { // SCISSOR_START
                clip_x = c.clay.clay_cmd_clip_x(idx);
                clip_y = c.clay.clay_cmd_clip_y(idx);
                clip_w = c.clay.clay_cmd_clip_w(idx);
                clip_h = c.clay.clay_cmd_clip_h(idx);
            },
            6 => { // SCISSOR_END
                clip_x = 0;
                clip_y = 0;
                clip_w = 0;
                clip_h = 0;
            },
            else => {},
        }
    }
}
