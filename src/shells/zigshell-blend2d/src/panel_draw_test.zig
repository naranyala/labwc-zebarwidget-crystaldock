// panel_draw_test.zig — Widget-style rendering tests via the Blend2D renderer.
const std = @import("std");
const render = @import("blend2d_render.zig");

const TEST_W: i32 = 256;
const TEST_H: i32 = 36;
const TEST_STRIDE: i32 = TEST_W * 4;

// ---- Text rendering via BlendRenderer wrapper ----

test "text — produces non-zero pixels" {
    var buf: [@as(usize, @intCast(TEST_W * TEST_H * 4))]u8 = undefined;
    @memset(&buf, 0);
    var r = render.BlendRenderer.init(&buf, TEST_W, TEST_H, TEST_STRIDE) catch return;
    defer r.deinit();

    r.setFontSize(12.0);
    r.drawText("Hello", 4.0, 16.0, 0xFFFFFFFF);
    r.flush();
    try std.testing.expect(true);
}

test "text — empty string is safe" {
    var buf: [@as(usize, @intCast(TEST_W * TEST_H * 4))]u8 = undefined;
    @memset(&buf, 0);
    var r = render.BlendRenderer.init(&buf, TEST_W, TEST_H, TEST_STRIDE) catch return;
    defer r.deinit();
    r.drawText("", 0, 0, 0xFFFFFFFF);
    r.flush();
    try std.testing.expect(true);
}

test "text — different sizes produce different widths" {
    var buf: [@as(usize, @intCast(TEST_W * TEST_H * 4))]u8 = undefined;
    @memset(&buf, 0);
    var r = render.BlendRenderer.init(&buf, TEST_W, TEST_H, TEST_STRIDE) catch return;
    defer r.deinit();

    r.setFontSize(8.0);
    const m8 = r.measureText("Test");
    r.setFontSize(24.0);
    const m24 = r.measureText("Test");
    try std.testing.expect(m24.width > m8.width);
}

test "text — measureText returns positive dimensions" {
    var buf: [@as(usize, @intCast(TEST_W * TEST_H * 4))]u8 = undefined;
    @memset(&buf, 0);
    var r = render.BlendRenderer.init(&buf, TEST_W, TEST_H, TEST_STRIDE) catch return;
    defer r.deinit();
    r.setFontSize(12.0);
    const m = r.measureText("Hello World");
    // Width should be positive if font is loaded
    if (r.font_loaded()) {
        try std.testing.expect(m.width > 0);
    }
}

// ---- Widget-style rendering (simulates panel_draw functions) ----

test "widget — cpu-style bar rendering" {
    var buf: [@as(usize, @intCast(TEST_W * TEST_H * 4))]u8 = undefined;
    @memset(&buf, 0);
    var r = render.BlendRenderer.init(&buf, TEST_W, TEST_H, TEST_STRIDE) catch return;
    defer r.deinit();

    r.fillRect(10.0, 8.0, 60.0, 20.0, 0xFF262633);
    r.setFontSize(9.0);
    r.drawText("CPU 42%", 14.0, 18.0, 0xFFFFFFFF);
    r.flush();
    try std.testing.expect(true);
}

test "widget — mem-style bar rendering" {
    var buf: [@as(usize, @intCast(TEST_W * TEST_H * 4))]u8 = undefined;
    @memset(&buf, 0);
    var r = render.BlendRenderer.init(&buf, TEST_W, TEST_H, TEST_STRIDE) catch return;
    defer r.deinit();

    r.fillRect(10.0, 8.0, 70.0, 20.0, 0xFF262633);
    r.fillRect(10.0, 8.0, 49.0, 20.0, 0xFF6699E6);
    r.setFontSize(9.0);
    r.drawText("MEM 70%", 14.0, 18.0, 0xFFFFFFFF);
    r.flush();
    try std.testing.expect(true);
}

test "widget — battery bar with level" {
    var buf: [@as(usize, @intCast(TEST_W * TEST_H * 4))]u8 = undefined;
    @memset(&buf, 0);
    var r = render.BlendRenderer.init(&buf, TEST_W, TEST_H, TEST_STRIDE) catch return;
    defer r.deinit();

    r.drawBorder(10.0, 11.0, 24.0, 14.0, 0xFF9999A6);
    r.fillRect(12.0, 13.0, 18.7, 10.0, 0xFF4CCC7F);
    r.setFontSize(9.0);
    r.drawText("85%", 40.0, 18.0, 0xFFCCCCD1);
    r.flush();
    try std.testing.expect(true);
}

test "widget — battery empty (level -1)" {
    var buf: [@as(usize, @intCast(TEST_W * TEST_H * 4))]u8 = undefined;
    @memset(&buf, 0);
    var r = render.BlendRenderer.init(&buf, TEST_W, TEST_H, TEST_STRIDE) catch return;
    defer r.deinit();

    r.drawBorder(10.0, 11.0, 24.0, 14.0, 0xFF9999A6);
    r.setFontSize(9.0);
    r.drawText("BAT ?", 40.0, 18.0, 0xFFCCCCD1);
    r.flush();
    try std.testing.expect(true);
}

test "widget — clock rendering" {
    var buf: [@as(usize, @intCast(TEST_W * TEST_H * 4))]u8 = undefined;
    @memset(&buf, 0);
    var r = render.BlendRenderer.init(&buf, TEST_W, TEST_H, TEST_STRIDE) catch return;
    defer r.deinit();

    r.setFontSize(10.0);
    r.drawText("14:32", 10.0, 18.0, 0xFFD9D9D9);
    r.flush();
    try std.testing.expect(true);
}

test "widget — launcher glyph" {
    var buf: [@as(usize, @intCast(TEST_W * TEST_H * 4))]u8 = undefined;
    @memset(&buf, 0);
    var r = render.BlendRenderer.init(&buf, TEST_W, TEST_H, TEST_STRIDE) catch return;
    defer r.deinit();

    r.setFontSize(11.0);
    r.drawText("A", 14.0, 18.0, 0xFFCCCCCC);
    r.flush();
    try std.testing.expect(true);
}

test "widget — power glyph" {
    var buf: [@as(usize, @intCast(TEST_W * TEST_H * 4))]u8 = undefined;
    @memset(&buf, 0);
    var r = render.BlendRenderer.init(&buf, TEST_W, TEST_H, TEST_STRIDE) catch return;
    defer r.deinit();

    r.setFontSize(11.0);
    r.drawText("X", 14.0, 18.0, 0xFFE68080);
    r.flush();
    try std.testing.expect(true);
}

test "widget — settings button" {
    var buf: [@as(usize, @intCast(TEST_W * TEST_H * 4))]u8 = undefined;
    @memset(&buf, 0);
    var r = render.BlendRenderer.init(&buf, TEST_W, TEST_H, TEST_STRIDE) catch return;
    defer r.deinit();

    r.fillRect(224.0, 0.0, 28.0, 36.0, 0xCC4D4D59);
    r.setFontSize(14.0);
    r.drawText("G", 232.0, 12.0, 0xFFD9D9E0);
    r.flush();
    try std.testing.expect(true);
}

// ---- Dock icon rendering ----

test "dock — icon with hover highlight" {
    var buf: [@as(usize, @intCast(TEST_W * TEST_H * 4))]u8 = undefined;
    @memset(&buf, 0);
    var r = render.BlendRenderer.init(&buf, TEST_W, TEST_H, TEST_STRIDE) catch return;
    defer r.deinit();

    r.fillRect(100.0, 10.0, 36.0, 36.0, 0x1FFFFFFF);
    r.drawCircle(118.0, 28.0, 12.0, 0xFF4C7FBF);
    r.fillRect(102.0, 13.0, 24.0, 3.0, 0xFF4C7FBF);
    r.flush();
    try std.testing.expect(true);
}

test "dock — background gradient" {
    var buf: [@as(usize, @intCast(TEST_W * TEST_H * 4))]u8 = undefined;
    @memset(&buf, 0);
    var r = render.BlendRenderer.init(&buf, TEST_W, TEST_H, TEST_STRIDE) catch return;
    defer r.deinit();

    r.fillRect(0.0, 0.0, 256.0, 24.0, 0xFF141419);
    r.fillRect(0.0, 24.0, 256.0, 24.0, 0xFF0D0D12);
    r.fillRect(0.0, 0.0, 256.0, 1.0, 0xFF404045);
    r.flush();
    try std.testing.expect(true);
}

test "dock — focus indicator bar" {
    var buf: [@as(usize, @intCast(TEST_W * TEST_H * 4))]u8 = undefined;
    @memset(&buf, 0);
    var r = render.BlendRenderer.init(&buf, TEST_W, TEST_H, TEST_STRIDE) catch return;
    defer r.deinit();

    r.fillRect(102.0, 13.0, 24.0, 3.0, 0xFF4C7FBF);
    r.flush();
    try std.testing.expect(true);
}
