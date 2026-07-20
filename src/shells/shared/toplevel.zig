// shared/toplevel.zig — Single source of truth for toplevel tracking,
// shared by both zigshell-cairo-pango and zigshell-blend2d.
//
// This module used to be duplicated (and subtly diverged) in each shell.
// It is now imported via the `shellcore` module as `shellcore.toplevel`.

const std = @import("std");

pub const MAX_TOPLEVELS = 64;

pub const ToplevelInfo = struct {
    handle: ?*anyopaque = null,
    title: [256]u8 = std.mem.zeroes([256]u8),
    app_id: [128]u8 = std.mem.zeroes([128]u8),
    id: u32 = 0,
    focused: bool = false,
    minimized: bool = false,
    maximized: bool = false,
    hover_anim: f64 = 0.0,
};

pub fn findIndex(infos: []ToplevelInfo, count: i32, handle: ?*anyopaque) i32 {
    for (0..@intCast(@max(0, count))) |i| {
        if (infos[i].handle == handle) return @intCast(i);
    }
    return -1;
}

pub fn add(infos: []ToplevelInfo, count: *i32, handle: ?*anyopaque) usize {
    if (count.* < 0) count.* = 0;
    if (count.* >= MAX_TOPLEVELS) return std.math.maxInt(usize);
    const idx: usize = @intCast(count.*);
    count.* += 1;
    infos[idx] = .{ .handle = handle };
    return idx;
}

pub fn removeAt(infos: []ToplevelInfo, count: *i32, idx: i32) void {
    if (idx < 0 or idx >= count.* or count.* <= 0) return;
    count.* -= 1;
    if (count.* < 0) count.* = 0;
    const ui: usize = @intCast(idx);
    const uc: usize = @intCast(count.*);
    if (ui < uc) {
        std.mem.copyForwards(ToplevelInfo, infos[ui..uc], infos[ui + 1 .. uc + 1]);
    }
    infos[uc] = .{};
}

test "toplevel array operations" {
    var infos: [MAX_TOPLEVELS]ToplevelInfo = undefined;
    var count: i32 = 0;

    // Test add
    const handle1: ?*anyopaque = @ptrFromInt(1);
    const idx1 = add(&infos, &count, handle1);
    try std.testing.expectEqual(@as(usize, 0), idx1);
    try std.testing.expectEqual(@as(i32, 1), count);
    try std.testing.expectEqual(handle1, infos[0].handle);

    // Test findIndex
    const handle2: ?*anyopaque = @ptrFromInt(2);
    _ = add(&infos, &count, handle2);
    try std.testing.expectEqual(@as(i32, 1), findIndex(&infos, count, handle2));
    try std.testing.expectEqual(@as(i32, -1), findIndex(&infos, count, @ptrFromInt(3)));

    // Test removeAt
    removeAt(&infos, &count, 0);
    try std.testing.expectEqual(@as(i32, 1), count);
    try std.testing.expectEqual(handle2, infos[0].handle);

    // Add multiple and remove middle
    _ = add(&infos, &count, @ptrFromInt(3));
    _ = add(&infos, &count, @ptrFromInt(4));
    try std.testing.expectEqual(@as(i32, 3), count);

    removeAt(&infos, &count, 1);
    try std.testing.expectEqual(@as(i32, 2), count);
    try std.testing.expectEqual(handle2, infos[0].handle);
    try std.testing.expectEqual(@as(?*anyopaque, @ptrFromInt(4)), infos[1].handle);
}

test "toplevel array operations - edge cases" {
    var infos: [MAX_TOPLEVELS]ToplevelInfo = undefined;
    var count: i32 = 0;

    // test removing from empty
    removeAt(&infos, &count, 0);
    try std.testing.expectEqual(@as(i32, 0), count);

    // test negative count recovery on add
    count = -5;
    _ = add(&infos, &count, @ptrFromInt(1));
    try std.testing.expectEqual(@as(i32, 1), count);

    // test removing out of bounds
    removeAt(&infos, &count, -1);
    try std.testing.expectEqual(@as(i32, 1), count);
    removeAt(&infos, &count, 5);
    try std.testing.expectEqual(@as(i32, 1), count);

    // fill to max
    count = MAX_TOPLEVELS - 1;
    _ = add(&infos, &count, @ptrFromInt(2));
    try std.testing.expectEqual(@as(i32, MAX_TOPLEVELS), count);

    // try adding past max
    const overflow_idx = add(&infos, &count, @ptrFromInt(3));
    try std.testing.expectEqual(std.math.maxInt(usize), overflow_idx);
    try std.testing.expectEqual(@as(i32, MAX_TOPLEVELS), count);
}

test "toplevel: duplicate handles are not de-duplicated" {
    var infos: [MAX_TOPLEVELS]ToplevelInfo = undefined;
    var count: i32 = 0;

    // The dock treats each toplevel window as a distinct entry, so adding the
    // same handle twice must produce two slots (not collapse to one).
    const h: ?*anyopaque = @ptrFromInt(0xDEAD);
    _ = add(&infos, &count, h);
    _ = add(&infos, &count, h);
    try std.testing.expectEqual(@as(i32, 2), count);
    try std.testing.expectEqual(h, infos[0].handle);
    try std.testing.expectEqual(h, infos[1].handle);

    // Removing one leaves the other in place.
    removeAt(&infos, &count, 0);
    try std.testing.expectEqual(@as(i32, 1), count);
    try std.testing.expectEqual(h, infos[0].handle);
}

test "toplevel: app_id / title buffers are zeroed on add" {
    var infos: [MAX_TOPLEVELS]ToplevelInfo = undefined;
    var count: i32 = 0;
    const h: ?*anyopaque = @ptrFromInt(0x42);
    _ = add(&infos, &count, h);

    // Fresh slot must be NUL-terminated / empty, never containing stale data.
    try std.testing.expectEqual(@as(u8, 0), infos[0].app_id[0]);
    try std.testing.expectEqual(@as(u8, 0), infos[0].title[0]);
    try std.testing.expectEqual(@as(u32, 0), infos[0].id);
    try std.testing.expectEqual(false, infos[0].focused);
}

test "toplevel: removeAt removes the exact index only" {
    var infos: [MAX_TOPLEVELS]ToplevelInfo = undefined;
    var count: i32 = 0;
    const a: ?*anyopaque = @ptrFromInt(1);
    const b: ?*anyopaque = @ptrFromInt(2);
    const c: ?*anyopaque = @ptrFromInt(3);
    _ = add(&infos, &count, a);
    _ = add(&infos, &count, b);
    _ = add(&infos, &count, c);

    // Remove the middle; tail shifts left, order preserved otherwise.
    removeAt(&infos, &count, 1);
    try std.testing.expectEqual(@as(i32, 2), count);
    try std.testing.expectEqual(a, infos[0].handle);
    try std.testing.expectEqual(c, infos[1].handle);

    // A second removeAt at the old index now hits a different slot: verify the
    // list stays consistent (count decrements, no double-free / gap).
    removeAt(&infos, &count, 1);
    try std.testing.expectEqual(@as(i32, 1), count);
    try std.testing.expectEqual(a, infos[0].handle);
}
