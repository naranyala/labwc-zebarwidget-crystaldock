const std = @import("std");

// Import Clay alongside Cairo and Pango
pub const clay = @cImport({
    @cInclude("clay.h");
    @cInclude("cairo.h");
});

var clay_memory: []u8 = &.{};

pub fn init() void {
    const min_memory = clay.Clay_MinMemorySize();
    clay_memory = std.heap.c_allocator.alloc(u8, min_memory) catch unreachable;
    const arena = clay.Clay_CreateArenaWithCapacityAndMemory(min_memory, clay_memory.ptr);
    _ = clay.Clay_Initialize(arena, .{ .width = 0, .height = 0 }, .{
        .errorHandlerFunction = null,
        .userData = null,
    });
    clay.Clay_SetMeasureTextFunction(&measureText, null);
}

// ---- Color helper ----
const Rgba = struct { r: f64, g: f64, b: f64, a: f64 };

fn clayColor(color: clay.Clay_Color) Rgba {
    return .{
        .r = @as(f64, @floatCast(color.r)) / 255.0,
        .g = @as(f64, @floatCast(color.g)) / 255.0,
        .b = @as(f64, @floatCast(color.b)) / 255.0,
        .a = @as(f64, @floatCast(color.a)) / 255.0,
    };
}

// ---- Rounded rectangle helper ----
fn roundedRect(cr: *clay.cairo_t, x: f64, y: f64, w: f64, h: f64, tl: f64, tr: f64, bl: f64, br: f64) void {
    const pi = std.math.pi;
    clay.cairo_new_sub_path(cr);
    // top-left
    clay.cairo_arc(cr, x + tl, y + tl, tl, pi, 1.5 * pi);
    // top-right
    clay.cairo_arc(cr, x + w - tr, y + tr, tr, -0.5 * pi, 0);
    // bottom-right
    clay.cairo_arc(cr, x + w - br, y + h - br, br, 0, 0.5 * pi);
    // bottom-left
    clay.cairo_arc(cr, x + bl, y + h - bl, bl, 0.5 * pi, pi);
    clay.cairo_close_path(cr);
}

// ---- Text measurement (placeholder) ----
fn measureText(text: clay.Clay_StringSlice, config: [*c]clay.Clay_TextElementConfig, _: ?*anyopaque) callconv(.c) clay.Clay_Dimensions {
    const font_size: f32 = if (config != null) @floatFromInt(config.*.fontSize) else 12.0;
    const char_count: f32 = @floatFromInt(text.length);
    // Rough monospace estimate: ~0.6 * fontSize per char
    return .{ .width = char_count * font_size * 0.6, .height = font_size * 1.3 };
}

// ---- Cairo renderer for Clay render commands ----
// cr_opaque is *anyopaque to avoid type conflicts between @cImport translation units.
pub fn render(commands: clay.Clay_RenderCommandArray, cr_opaque: *anyopaque) void {
    const cr: *clay.cairo_t = @ptrCast(cr_opaque);
    const len: usize = @intCast(commands.length);
    for (0..len) |i| {
        const cmd = commands.internalArray[i];
        const bb = cmd.boundingBox;

        switch (cmd.commandType) {
            clay.CLAY_RENDER_COMMAND_TYPE_RECTANGLE => {
                const data = cmd.renderData.rectangle;
                const c_ = clayColor(data.backgroundColor);
                clay.cairo_set_source_rgba(cr, c_.r, c_.g, c_.b, c_.a);

                const cr_tl: f64 = @floatCast(data.cornerRadius.topLeft);
                const cr_tr: f64 = @floatCast(data.cornerRadius.topRight);
                const cr_bl: f64 = @floatCast(data.cornerRadius.bottomLeft);
                const cr_br: f64 = @floatCast(data.cornerRadius.bottomRight);

                if (cr_tl > 0 or cr_tr > 0 or cr_bl > 0 or cr_br > 0) {
                    roundedRect(cr, @floatCast(bb.x), @floatCast(bb.y), @floatCast(bb.width), @floatCast(bb.height), cr_tl, cr_tr, cr_bl, cr_br);
                    clay.cairo_fill(cr);
                } else {
                    clay.cairo_rectangle(cr, @floatCast(bb.x), @floatCast(bb.y), @floatCast(bb.width), @floatCast(bb.height));
                    clay.cairo_fill(cr);
                }
            },

            clay.CLAY_RENDER_COMMAND_TYPE_TEXT => {
                const data = cmd.renderData.text;
                const c_ = clayColor(data.textColor);
                clay.cairo_set_source_rgba(cr, c_.r, c_.g, c_.b, c_.a);

                // Use cairo toy text API for now (will be replaced by Pango)
                clay.cairo_select_font_face(cr, "sans-serif", clay.CAIRO_FONT_SLANT_NORMAL, clay.CAIRO_FONT_WEIGHT_NORMAL);
                clay.cairo_set_font_size(cr, @floatCast(@as(f32, @floatFromInt(data.fontSize))));

                // Clay_StringSlice is not null-terminated, copy to stack buffer
                var text_buf: [512]u8 = undefined;
                const slen: usize = @intCast(data.stringContents.length);
                const copy_len = @min(slen, text_buf.len - 1);
                if (data.stringContents.chars != null) {
                    @memcpy(text_buf[0..copy_len], data.stringContents.chars[0..copy_len]);
                }
                text_buf[copy_len] = 0;

                clay.cairo_move_to(cr, @floatCast(bb.x), @floatCast(bb.y + bb.height * 0.8));
                clay.cairo_show_text(cr, @ptrCast(&text_buf));
            },

            clay.CLAY_RENDER_COMMAND_TYPE_BORDER => {
                const data = cmd.renderData.border;
                const c_ = clayColor(data.color);
                clay.cairo_set_source_rgba(cr, c_.r, c_.g, c_.b, c_.a);

                const x: f64 = @floatCast(bb.x);
                const y: f64 = @floatCast(bb.y);
                const w: f64 = @floatCast(bb.width);
                const h: f64 = @floatCast(bb.height);

                // Draw each border side if width > 0
                if (data.width.top > 0) {
                    clay.cairo_set_line_width(cr, @floatFromInt(data.width.top));
                    clay.cairo_move_to(cr, x, y + 0.5);
                    clay.cairo_line_to(cr, x + w, y + 0.5);
                    clay.cairo_stroke(cr);
                }
                if (data.width.bottom > 0) {
                    clay.cairo_set_line_width(cr, @floatFromInt(data.width.bottom));
                    clay.cairo_move_to(cr, x, y + h - 0.5);
                    clay.cairo_line_to(cr, x + w, y + h - 0.5);
                    clay.cairo_stroke(cr);
                }
                if (data.width.left > 0) {
                    clay.cairo_set_line_width(cr, @floatFromInt(data.width.left));
                    clay.cairo_move_to(cr, x + 0.5, y);
                    clay.cairo_line_to(cr, x + 0.5, y + h);
                    clay.cairo_stroke(cr);
                }
                if (data.width.right > 0) {
                    clay.cairo_set_line_width(cr, @floatFromInt(data.width.right));
                    clay.cairo_move_to(cr, x + w - 0.5, y);
                    clay.cairo_line_to(cr, x + w - 0.5, y + h);
                    clay.cairo_stroke(cr);
                }
            },

            clay.CLAY_RENDER_COMMAND_TYPE_SCISSOR_START => {
                clay.cairo_save(cr);
                clay.cairo_rectangle(cr, @floatCast(bb.x), @floatCast(bb.y), @floatCast(bb.width), @floatCast(bb.height));
                clay.cairo_clip(cr);
            },

            clay.CLAY_RENDER_COMMAND_TYPE_SCISSOR_END => {
                clay.cairo_restore(cr);
            },

            clay.CLAY_RENDER_COMMAND_TYPE_CUSTOM => {
                // Custom render commands will be handled by the caller
                // (e.g., dock icon rendering). We skip them here.
            },

            clay.CLAY_RENDER_COMMAND_TYPE_IMAGE => {
                const data = cmd.renderData.image;
                if (data.imageData == null) break;
                const surf: *clay.cairo_surface_t = @ptrCast(@alignCast(data.imageData));
                // Icons are square; center them inside the (possibly wider) box.
                const sw: f64 = @floatFromInt(clay.cairo_image_surface_get_width(surf));
                const sh: f64 = @floatFromInt(clay.cairo_image_surface_get_height(surf));
                const bw: f64 = @as(f64, @floatCast(bb.width));
                const bh: f64 = @as(f64, @floatCast(bb.height));
                const bx: f64 = @as(f64, @floatCast(bb.x));
                const by: f64 = @as(f64, @floatCast(bb.y));
                const ox: f64 = bx + @max(0.0, (bw - sw) / 2.0);
                const oy: f64 = by + @max(0.0, (bh - sh) / 2.0);
                clay.cairo_set_source_surface(cr, surf, ox, oy);
                clay.cairo_paint(cr);
            },

            else => {},
        }
    }
}
