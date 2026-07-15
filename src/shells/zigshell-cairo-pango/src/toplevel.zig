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
    for (0..@intCast(count)) |i| {
        if (infos[i].handle == handle) return @intCast(i);
    }
    return -1;
}

pub fn add(infos: []ToplevelInfo, count: *i32, handle: ?*anyopaque) usize {
    if (count.* >= MAX_TOPLEVELS) return std.math.maxInt(usize);
    const idx: usize = @intCast(count.*);
    count.* += 1;
    infos[idx] = .{ .handle = handle };
    return idx;
}

pub fn removeAt(infos: []ToplevelInfo, count: *i32, idx: i32) void {
    if (idx < 0 or idx >= count.*) return;
    count.* -= 1;
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
