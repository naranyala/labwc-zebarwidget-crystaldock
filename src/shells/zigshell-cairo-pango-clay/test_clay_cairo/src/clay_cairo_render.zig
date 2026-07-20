// clay_cairo_render.zig — Clay 0.14 → Cairo renderer
// Maps flattened Clay commands to Cairo drawing calls.

const std = @import("std");
const c = @import("c.zig");

/// Convert Clay Color (f32 0-255) to Cairo RGBA (0.0-1.0).
inline fn toCairoRGBA(r: f32, g: f32, b: f32, a: f32) void {
    c.cairo_set_source_rgba(
        @ptrCast(c.cr),
        @as(f64, @floatCast(r)) / 255.0,
        @as(f64, @floatCast(g)) / 255.0,
        @as(f64, @floatCast(b)) / 255.0,
        @as(f64, @floatCast(a)) / 255.0,
    );
}

/// Draw a rounded rectangle using Cairo arcs.
fn roundedRect(x: f64, y: f64, w: f64, h: f64, radius: f64) void {
    const cr: *c.cairo_t = @ptrCast(c.cr);
    const pi = std.math.pi;
    c.cairo_new_sub_path(cr);
    c.cairo_arc(cr, x + radius, y + radius, radius, pi, 1.5 * pi);
    c.cairo_arc(cr, x + w - radius, y + radius, radius, -0.5 * pi, 0);
    c.cairo_arc(cr, x + w - radius, y + h - radius, radius, 0, 0.5 * pi);
    c.cairo_arc(cr, x + radius, y + h - radius, radius, 0.5 * pi, pi);
    c.cairo_close_path(cr);
}

/// Render all flattened Clay commands to the current Cairo context.
pub fn renderAll() void {
    const count = c.clay.clay_cmd_count();
    const cr: *c.cairo_t = @ptrCast(c.cr);

    for (0..@intCast(count)) |i| {
        const idx: c_int = @intCast(i);
        const cmd_type = c.clay.clay_cmd_type(idx);

        const x = c.clay.clay_cmd_x(idx);
        const y = c.clay.clay_cmd_y(idx);
        const w = c.clay.clay_cmd_w(idx);
        const h = c.clay.clay_cmd_h(idx);

        switch (cmd_type) {
            1 => { // RECTANGLE
                toCairoRGBA(
                    c.clay.clay_cmd_bg_r(idx),
                    c.clay.clay_cmd_bg_g(idx),
                    c.clay.clay_cmd_bg_b(idx),
                    c.clay.clay_cmd_bg_a(idx),
                );
                const radius = c.clay.clay_cmd_radius(idx);
                if (radius > 0.5) {
                    roundedRect(@floatCast(x), @floatCast(y), @floatCast(w), @floatCast(h), @floatCast(radius));
                    c.cairo_fill(cr);
                } else {
                    c.cairo_rectangle(cr, @floatCast(x), @floatCast(y), @floatCast(w), @floatCast(h));
                    c.cairo_fill(cr);
                }
            },
            2 => { // BORDER
                toCairoRGBA(
                    c.clay.clay_cmd_border_r(idx),
                    c.clay.clay_cmd_border_g(idx),
                    c.clay.clay_cmd_border_b(idx),
                    c.clay.clay_cmd_border_a(idx),
                );
                c.cairo_set_line_width(cr, 1.0);
                c.cairo_rectangle(cr, @floatCast(x + 0.5), @floatCast(y + 0.5), @floatCast(w - 1.0), @floatCast(h - 1.0));
                c.cairo_stroke(cr);
            },
            3 => { // TEXT
                const text_len = c.clay.clay_cmd_text_len(idx);
                if (text_len > 0) {
                    const text_ptr = c.clay.clay_cmd_text_ptr(idx);
                    toCairoRGBA(
                        c.clay.clay_cmd_text_r(idx),
                        c.clay.clay_cmd_text_g(idx),
                        c.clay.clay_cmd_text_b(idx),
                        c.clay.clay_cmd_text_a(idx),
                    );
                    const font_size = c.clay.clay_cmd_font_size(idx);
                    const fs: f64 = if (font_size > 0) @floatFromInt(font_size) else 14.0;
                    c.cairo_set_font_size(cr, fs);

                    // Copy null-terminated text for Cairo
                    var buf: [512]u8 = undefined;
                    const len: usize = @intCast(text_len);
                    const copy_len = @min(len, buf.len - 1);
                    @memcpy(buf[0..copy_len], text_ptr[0..copy_len]);
                    buf[copy_len] = 0;

                    c.cairo_move_to(cr, @floatCast(x), @floatCast(y + h * 0.8));
                    _ = c.cairo_show_text(cr, @ptrCast(&buf));
                }
            },
            else => {},
        }
    }
}
