// main.zig — Clay layout + Blend2D rendering test
const std = @import("std");
const c = @import("c.zig");
const clay_bridge = @import("clay_blend2d.zig");
const dock_clay = @import("dock_clay.zig");
const blend2d = @import("blend2d_render.zig");
const toplevel = @import("shellcore").toplevel;

const WIDTH = 800;
const HEIGHT = 480;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    c.clay.clay_init(WIDTH, HEIGHT);
    c.clay.clay_set_text_measurement();
    defer c.clay.clay_cleanup();
    std.debug.print("Clay initialized: {d}x{d}\n", .{ WIDTH, HEIGHT });

    const stride = WIDTH * 4;
    const buf_size = @as(usize, @intCast(stride * HEIGHT));
    const pixel_data = try allocator.alloc(u8, buf_size);
    @memset(pixel_data, 0);
    var renderer = try blend2d.BlendRenderer.init(pixel_data.ptr, WIDTH, HEIGHT, stride);
    defer renderer.deinit();
    renderer.fillRect(0, 0, @floatFromInt(WIDTH), @floatFromInt(HEIGHT), 0xFF12121A);
    std.debug.print("Blend2D renderer: {d}x{d}, stride={d}\n", .{ WIDTH, HEIGHT, stride });

    { const count = c.clay.clay_layout_status_bar(WIDTH, 32); std.debug.print("Status bar: {d} commands\n", .{count}); clay_bridge.renderAll(&renderer); }
    { const count = c.clay.clay_layout_center_card(WIDTH, HEIGHT); std.debug.print("Center card: {d} commands\n", .{count}); clay_bridge.renderAll(&renderer); }

    {
        var tops: [5]toplevel.ToplevelInfo = undefined;
        const names = [_][]const u8{ "firefox", "foot", "code", "thunar", "settings" };
        for (0..5) |i| {
            tops[i] = std.mem.zeroes(toplevel.ToplevelInfo);
            const name = names[i];
            @memcpy(tops[i].app_id[0..name.len], name);
            tops[i].app_id[name.len] = 0;
            tops[i].focused = (i == 2);
        }
        std.debug.print("Clay dock: rendering {d} app icons\n", .{@as(i32, 5)});
        dock_clay.draw(&renderer, WIDTH, 48, &tops, 5, 1);
    }

    {
        const count = c.clay.clay_layout_launcher(WIDTH, HEIGHT, 100);
        std.debug.print("Launcher: {d} commands\n", .{count});
        clay_bridge.renderAll(&renderer);
    }

    renderer.flush();
    std.debug.print("\nClay + Blend2D layout pipeline complete ({d}x{d})\n", .{ WIDTH, HEIGHT });
    std.debug.print("No PNG output (headless smoke-test).\n", .{});
}
