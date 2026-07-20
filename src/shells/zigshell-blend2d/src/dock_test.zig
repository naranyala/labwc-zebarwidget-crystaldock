// dock_test.zig — Unit tests for dock.zig layout functions
const std = @import("std");
const dock = @import("dock.zig");
const toplevel = @import("shellcore").toplevel;

test "DOCK_ICON_SIZE constant" {
    try std.testing.expectEqual(@as(i32, 28), dock.DOCK_ICON_SIZE);
}

test "iconAt — no windows" {
    var infos: [toplevel.MAX_TOPLEVELS]toplevel.ToplevelInfo = undefined;
    const result = dock.iconAt(1920, 48, &infos, 0, 960);
    try std.testing.expectEqual(@as(i32, -1), result);
}

test "iconAt — single window centered" {
    var infos: [toplevel.MAX_TOPLEVELS]toplevel.ToplevelInfo = undefined;
    var count: i32 = 0;
    _ = toplevel.add(&infos, &count, @ptrFromInt(0x1000));

    // Single icon centered at x=960 (center of 1920)
    const center_x: i32 = 960; // center of 1920

    // Click on the icon
    const result = dock.iconAt(1920, 48, &infos, 1, center_x);
    try std.testing.expectEqual(@as(i32, 0), result);
}

test "iconAt — miss to the left" {
    var infos: [toplevel.MAX_TOPLEVELS]toplevel.ToplevelInfo = undefined;
    var count: i32 = 0;
    _ = toplevel.add(&infos, &count, @ptrFromInt(0x1000));

    const result = dock.iconAt(1920, 48, &infos, 1, 0);
    try std.testing.expectEqual(@as(i32, -1), result);
}

test "iconAt — miss to the right" {
    var infos: [toplevel.MAX_TOPLEVELS]toplevel.ToplevelInfo = undefined;
    var count: i32 = 0;
    _ = toplevel.add(&infos, &count, @ptrFromInt(0x1000));

    const result = dock.iconAt(1920, 48, &infos, 1, 1919);
    try std.testing.expectEqual(@as(i32, -1), result);
}

test "iconAt — multiple windows" {
    var infos: [toplevel.MAX_TOPLEVELS]toplevel.ToplevelInfo = undefined;
    var count: i32 = 0;
    _ = toplevel.add(&infos, &count, @ptrFromInt(0x1000));
    _ = toplevel.add(&infos, &count, @ptrFromInt(0x2000));
    _ = toplevel.add(&infos, &count, @ptrFromInt(0x3000));

    const slot = dock.DOCK_ICON_SIZE + 8; // 36
    const total_w: i32 = 3 * slot - 8; // 100
    const start_x: i32 = @divTrunc(1920 - total_w, 2); // center

    // Click on first icon
    try std.testing.expectEqual(@as(i32, 0), dock.iconAt(1920, 48, &infos, 3, start_x));

    // Click on second icon
    try std.testing.expectEqual(@as(i32, 1), dock.iconAt(1920, 48, &infos, 3, start_x + slot));

    // Click on third icon
    try std.testing.expectEqual(@as(i32, 2), dock.iconAt(1920, 48, &infos, 3, start_x + 2 * slot));

    // Click before first icon
    try std.testing.expectEqual(@as(i32, -1), dock.iconAt(1920, 48, &infos, 3, start_x - 1));

    // Click after last icon lands on the separated-bar settings toggle (-2).
    try std.testing.expectEqual(@as(i32, -2), dock.iconAt(1920, 48, &infos, 3, start_x + 3 * slot));
}

test "iconAt — narrow screen" {
    var infos: [toplevel.MAX_TOPLEVELS]toplevel.ToplevelInfo = undefined;
    var count: i32 = 0;
    _ = toplevel.add(&infos, &count, @ptrFromInt(0x1000));
    _ = toplevel.add(&infos, &count, @ptrFromInt(0x2000));

    // Screen narrower than icons — start_x should clamp to 0
    const result = dock.iconAt(80, 48, &infos, 2, 40);
    try std.testing.expect(result >= 0);
}

test "iconAt — exact boundary" {
    var infos: [toplevel.MAX_TOPLEVELS]toplevel.ToplevelInfo = undefined;
    var count: i32 = 0;
    _ = toplevel.add(&infos, &count, @ptrFromInt(0x1000));

    const slot = dock.DOCK_ICON_SIZE + 8;
    const start_x: i32 = @divTrunc(1920 - (slot - 8), 2);

    // Click at exact left edge of icon
    try std.testing.expectEqual(@as(i32, 0), dock.iconAt(1920, 48, &infos, 1, start_x));

    // Click at exact right edge (exclusive) lands on the settings toggle (-2).
    try std.testing.expectEqual(@as(i32, -2), dock.iconAt(1920, 48, &infos, 1, start_x + dock.DOCK_ICON_SIZE + 8));
}


// ---- Toggle hit-zone tests (settings = -2, launcher = -3) ----

test "iconAt — settings toggle hit zone" {
    var infos: [toplevel.MAX_TOPLEVELS]toplevel.ToplevelInfo = undefined;
    var count: i32 = 0;
    _ = toplevel.add(&infos, &count, @ptrFromInt(0x1000));

    const slot = dock.DOCK_ICON_SIZE + 8;
    const total_w: i32 = slot - 8; // 1 icon
    const start_x: i32 = @divTrunc(1920 - total_w, 2);

    // Settings icon is after the app icons + DOCK_PAD
    const settings_x = start_x + total_w + 8;
    // Click in the middle of the settings icon
    const result = dock.iconAt(1920, 48, &infos, 1, settings_x + @divTrunc(dock.DOCK_ICON_SIZE, 2));
    try std.testing.expectEqual(@as(i32, -2), result);
}

test "iconAt — launcher toggle hit zone" {
    var infos: [toplevel.MAX_TOPLEVELS]toplevel.ToplevelInfo = undefined;
    var count: i32 = 0;
    _ = toplevel.add(&infos, &count, @ptrFromInt(0x1000));

    const slot = dock.DOCK_ICON_SIZE + 8;
    const total_w: i32 = slot - 8; // 1 icon
    const start_x: i32 = @divTrunc(1920 - total_w, 2);

    // Launcher icon is after settings + slot
    const settings_x = start_x + total_w + 8;
    const launcher_x = settings_x + slot;
    const result = dock.iconAt(1920, 48, &infos, 1, launcher_x + @divTrunc(dock.DOCK_ICON_SIZE, 2));
    // The launcher toggle (-3) opens the full .desktop app grid: it is a
    // clickable dock item, mirroring cairo-pango's home toggle.
    try std.testing.expectEqual(@as(i32, -3), result);
}

test "iconAt — launcher toggle on wide screen" {
    var infos: [toplevel.MAX_TOPLEVELS]toplevel.ToplevelInfo = undefined;
    var count: i32 = 0;
    _ = toplevel.add(&infos, &count, @ptrFromInt(0x1000));

    const w: i32 = 3840; // 4K
    const slot = dock.DOCK_ICON_SIZE + 8;
    const total_w: i32 = slot - 8;
    const start_x: i32 = @divTrunc(w - total_w, 2);

    const settings_x = start_x + total_w + 8;
    const launcher_x = settings_x + slot;
    const result = dock.iconAt(w, 48, &infos, 1, launcher_x + 5);
    try std.testing.expectEqual(@as(i32, -3), result);
}

test "iconAt — launcher toggle no windows" {
    var infos: [toplevel.MAX_TOPLEVELS]toplevel.ToplevelInfo = undefined;

    // With 0 windows total_w = 0, start_x = w/2
    const start_x: i32 = @divTrunc(1920, 2);
    const settings_x = start_x + 8; // total_w=0 + DOCK_PAD
    const launcher_x = settings_x + (dock.DOCK_ICON_SIZE + 8);
    const result = dock.iconAt(1920, 48, &infos, 0, launcher_x + 5);
    try std.testing.expectEqual(@as(i32, -3), result);
}

test "iconAt — settings toggle on wide screen" {
    var infos: [toplevel.MAX_TOPLEVELS]toplevel.ToplevelInfo = undefined;
    var count: i32 = 0;
    _ = toplevel.add(&infos, &count, @ptrFromInt(0x1000));

    const w: i32 = 3840; // 4K
    const slot = dock.DOCK_ICON_SIZE + 8;
    const total_w: i32 = slot - 8;
    const start_x: i32 = @divTrunc(w - total_w, 2);

    const settings_x = start_x + total_w + 8;
    const result = dock.iconAt(w, 48, &infos, 1, settings_x + 5);
    try std.testing.expectEqual(@as(i32, -2), result);
}

test "iconAt — no windows still shows toggles" {
    var infos: [toplevel.MAX_TOPLEVELS]toplevel.ToplevelInfo = undefined;

    // With 0 windows, total_w = 0, start_x = w/2
    // Settings should still be clickable
    const start_x: i32 = @divTrunc(1920, 2);
    const settings_x = start_x + 8; // total_w=0 + DOCK_PAD
    const result = dock.iconAt(1920, 48, &infos, 0, settings_x + 5);
    try std.testing.expectEqual(@as(i32, -2), result);
}

test "iconAt — toggle zones don't overlap with app icons" {
    var infos: [toplevel.MAX_TOPLEVELS]toplevel.ToplevelInfo = undefined;
    var count: i32 = 0;
    _ = toplevel.add(&infos, &count, @ptrFromInt(0x1000));
    _ = toplevel.add(&infos, &count, @ptrFromInt(0x2000));

    const slot = dock.DOCK_ICON_SIZE + 8;
    const total_w: i32 = 2 * slot - 8;
    const start_x: i32 = @divTrunc(1920 - total_w, 2);

    // Click on each app icon — should return 0 or 1, not -2 (settings)
    const r0 = dock.iconAt(1920, 48, &infos, 2, start_x + @divTrunc(dock.DOCK_ICON_SIZE, 2));
    const r1 = dock.iconAt(1920, 48, &infos, 2, start_x + slot + @divTrunc(dock.DOCK_ICON_SIZE, 2));
    try std.testing.expectEqual(@as(i32, 0), r0);
    try std.testing.expectEqual(@as(i32, 1), r1);

    // Click just past the last app icon — should hit settings (-2)
    const r_settings = dock.iconAt(1920, 48, &infos, 2, start_x + total_w + 8 + 5);
    try std.testing.expectEqual(@as(i32, -2), r_settings);
}

test "iconAt — gap between app icons and toggles is DOCK_PAD" {
    var infos: [toplevel.MAX_TOPLEVELS]toplevel.ToplevelInfo = undefined;
    var count: i32 = 0;
    _ = toplevel.add(&infos, &count, @ptrFromInt(0x1000));

    const slot = dock.DOCK_ICON_SIZE + 8;
    const total_w: i32 = slot - 8; // 28 for 1 icon
    const start_x: i32 = @divTrunc(1920 - total_w, 2);

    // App icon hit zone ends at start_x + dock_icon_size + DOCK_PAD = start_x + 36
    // Settings icon starts at start_x + total_w + DOCK_PAD = start_x + 36
    // There's no gap — the zones are contiguous. Verify clicking right of the
    // icon hit zone lands on the settings toggle.
    const past_icon = start_x + dock.DOCK_ICON_SIZE + 8; // first pixel past icon hit zone
    const result = dock.iconAt(1920, 48, &infos, 1, past_icon);
    try std.testing.expectEqual(@as(i32, -2), result);
}

test "iconAt — many icons with toggles" {
    var infos: [toplevel.MAX_TOPLEVELS]toplevel.ToplevelInfo = undefined;
    var count: i32 = 0;
    // Add 10 windows
    for (0..10) |i| {
        _ = toplevel.add(&infos, &count, @ptrFromInt(@as(usize, 0x1000 + i * 0x100)));
    }

    const slot = dock.DOCK_ICON_SIZE + 8;
    const total_w: i32 = 10 * slot - 8;
    const start_x: i32 = @divTrunc(1920 - total_w, 2);

    // Click on first app icon
    try std.testing.expectEqual(@as(i32, 0), dock.iconAt(1920, 48, &infos, 10, start_x));

    // Click on last app icon
    try std.testing.expectEqual(@as(i32, 9), dock.iconAt(1920, 48, &infos, 10, start_x + 9 * slot));

    // Click past last icon — settings toggle
    try std.testing.expectEqual(@as(i32, -2), dock.iconAt(1920, 48, &infos, 10, start_x + 10 * slot + 5));
}
