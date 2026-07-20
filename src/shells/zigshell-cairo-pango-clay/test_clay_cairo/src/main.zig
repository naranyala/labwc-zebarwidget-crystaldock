// main.zig — Clay 0.14 + Cairo rendering test
// Renders Clay layouts to a Cairo image surface, writes PNG.
//
// Usage: zig build run
// Output: test_output.png (800x480)

const std = @import("std");
const c = @import("c.zig");
const clay_render = @import("clay_cairo_render.zig");

const WIDTH = 800;
const HEIGHT = 480;

pub fn main() !void {
    // ---- 1. Initialize Clay ----
    c.clay.clay_init(WIDTH, HEIGHT);
    c.clay.clay_set_text_measurement();
    defer c.clay.clay_cleanup();
    std.debug.print("Clay initialized: {d}x{d}\n", .{ WIDTH, HEIGHT });

    // ---- 2. Create Cairo image surface ----
    const surface = c.cairo_image_surface_create(c.CAIRO_FORMAT_ARGB32, WIDTH, HEIGHT);
    defer c.cairo_surface_destroy(surface);

    const cr = c.cairo_create(surface);
    defer c.cairo_destroy(cr);

    // Set global Cairo context for the renderer
    c.cr = cr;

    // Dark background
    c.cairo_set_source_rgba(cr, 0.07, 0.07, 0.10, 1.0);
    c.cairo_rectangle(cr, 0, 0, @floatFromInt(WIDTH), @floatFromInt(HEIGHT));
    c.cairo_fill(cr);

    std.debug.print("Cairo surface: {d}x{d}\n", .{ WIDTH, HEIGHT });

    // ---- 3. Status Bar (top 32px) ----
    {
        const count = c.clay.clay_layout_status_bar(WIDTH, 32);
        std.debug.print("Status bar: {d} Clay commands\n", .{count});
        clay_render.renderAll();
    }

    // ---- 4. Center Card ----
    {
        const count = c.clay.clay_layout_center_card(WIDTH, HEIGHT);
        std.debug.print("Center card: {d} Clay commands\n", .{count});
        clay_render.renderAll();
    }

    // ---- 5. Dock (bottom 48px) ----
    {
        const count = c.clay.clay_layout_dock(WIDTH, 48, 5);
        std.debug.print("Dock: {d} Clay commands\n", .{count});
        clay_render.renderAll();
    }

    // ---- 6. Write PNG ----
    _ = c.cairo_surface_write_to_png(surface, "test_output.png");

    std.debug.print("\nRendered test_output.png ({d}x{d})\n", .{ WIDTH, HEIGHT });
    std.debug.print("Clay + Cairo integration working!\n", .{});
}
