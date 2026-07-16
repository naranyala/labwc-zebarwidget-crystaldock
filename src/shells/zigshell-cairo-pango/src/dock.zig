const std = @import("std");
const c = @import("c.zig").c;

const toplevel = @import("shellcore").toplevel;
const icon = @import("icon.zig");
const theme = @import("theme.zig");

const PAD = 8;
const FOCUS_BAR_H = 3;

pub var DOCK_ICON_SIZE: i32 = 28;

pub const pinned_apps = [_][]const u8{ "foot", "firefox", "nemo" };

pub var persistent_order: [100][128]u8 = std.mem.zeroes([100][128]u8);
pub var persistent_count: usize = 0;
pub var order_initialized: bool = false;

pub fn initOrder() void {
    if (order_initialized) return;
    for (pinned_apps) |app| {
        @memcpy(persistent_order[persistent_count][0..app.len], app);
        persistent_order[persistent_count][app.len] = 0;
        persistent_count += 1;
    }
    order_initialized = true;
}

pub fn launchPinned(index: usize) void {
    if (index < persistent_count) {
        const app = std.mem.sliceTo(&persistent_order[index], 0);
        var buf: [256]u8 = undefined;
        const cmd = std.fmt.bufPrintZ(&buf, "{s} &", .{app}) catch return;
        _ = c.system(cmd.ptr);
    }
}

pub fn draw(
    cr: *c.cairo_t,
    w: i32,
    h: i32,
    tops: []toplevel.ToplevelInfo,
    top_count: i32,
    hover_idx: i32,
    mouse_x: f64,
) void {
    _ = hover_idx;
    initOrder();
    
    // Background gradient
    const t = &theme.current;
    const grad = c.cairo_pattern_create_linear(0, 0, 0, @floatFromInt(h));
    c.cairo_pattern_add_color_stop_rgba(grad, 0, t.bg_color[0], t.bg_color[1], t.bg_color[2], t.bg_color[3]);
    c.cairo_pattern_add_color_stop_rgba(grad, 1, t.bg_gradient_end[0], t.bg_gradient_end[1], t.bg_gradient_end[2], t.bg_gradient_end[3]);
    c.cairo_set_source(cr, grad);
    c.cairo_paint(cr);
    c.cairo_pattern_destroy(grad);

    // Top border line
    theme.setSource(cr, t.border_color);
    c.cairo_set_line_width(cr, 1);
    c.cairo_move_to(cr, 0, 0.5);
    c.cairo_line_to(cr, @floatFromInt(w), 0.5);
    c.cairo_stroke(cr);

    const DockItem = struct {
        app_id: []const u8,
        top_idx: ?usize,
        count: u32,
        focused: bool,
    };

    var items: [100]DockItem = undefined;
    var num_items: usize = 0;

    for (0..persistent_count) |i| {
        items[num_items] = .{
            .app_id = std.mem.sliceTo(&persistent_order[i], 0),
            .top_idx = null,
            .count = 0,
            .focused = false,
        };
        num_items += 1;
    }

    // Grouping by app_id
    for (0..@intCast(top_count)) |i| {
        const app_id = tops[i].app_id[0..std.mem.indexOfScalar(u8, &tops[i].app_id, 0) orelse tops[i].app_id.len];
        var found = false;
        for (0..num_items) |g| {
            if (std.mem.eql(u8, app_id, items[g].app_id) or 
                (std.mem.eql(u8, app_id, "foot-term") and std.mem.eql(u8, items[g].app_id, "foot"))) // hack for foot
            {
                if (items[g].count == 0) items[g].top_idx = i;
                items[g].count += 1;
                if (tops[i].focused) items[g].focused = true;
                found = true;
                break;
            }
        }
        if (!found) {
            // Append to persistent order dynamically
            if (persistent_count < 100) {
                @memcpy(persistent_order[persistent_count][0..app_id.len], app_id);
                persistent_order[persistent_count][app_id.len] = 0;
                persistent_count += 1;
            }
            items[num_items] = .{
                .app_id = app_id,
                .top_idx = i,
                .count = 1,
                .focused = tops[i].focused,
            };
            num_items += 1;
        }
    }

    // Parabolic magnification sizing
    var widths = std.mem.zeroes([100]f64);
    var total_w: f64 = 0;
    const slot: f64 = DOCK_ICON_SIZE + PAD;
    const unscaled_total: f64 = if (num_items > 0) @as(f64, @floatFromInt(num_items)) * slot - PAD else 0;
    const unscaled_start_x: f64 = @max(0, (@as(f64, @floatFromInt(w)) - unscaled_total) / 2.0);

    for (0..num_items) |g| {
        const unscaled_x = unscaled_start_x + @as(f64, @floatFromInt(g)) * slot + (@as(f64, @floatFromInt(DOCK_ICON_SIZE)) / 2.0);
        var scale: f64 = 1.0;
        if (mouse_x >= 0) {
            const dist = mouse_x - unscaled_x;
            scale += 1.0 * std.math.exp(-(dist * dist) / 4000.0);
        }
        widths[g] = DOCK_ICON_SIZE * scale;
        total_w += widths[g] + PAD;
    }
    if (num_items > 0) total_w -= PAD;

    var current_x = @max(0, (@as(f64, @floatFromInt(w)) - total_w) / 2.0);

    for (0..num_items) |g| {
        const item = items[g];
        const icon_w = widths[g];
        const x = current_x;
        const icon_y = @as(f64, @floatFromInt(h)) - icon_w - 6.0;

        const name = if (item.top_idx) |idx| 
            if (tops[idx].app_id[0] != 0) tops[idx].app_id[0..std.mem.indexOfScalar(u8, &tops[idx].app_id, 0) orelse tops[idx].app_id.len] else tops[idx].title[0..std.mem.indexOfScalar(u8, &tops[idx].title, 0) orelse tops[idx].title.len]
        else item.app_id;

        const icon_surf = icon.load(@ptrCast(name.ptr), DOCK_ICON_SIZE);
        
        c.cairo_save(cr);
        c.cairo_translate(cr, x, icon_y);
        const scale_factor = icon_w / @as(f64, @floatFromInt(DOCK_ICON_SIZE));
        c.cairo_scale(cr, scale_factor, scale_factor);
        c.cairo_set_source_surface(cr, icon_surf, 0, 0);
        c.cairo_paint(cr);
        c.cairo_restore(cr);

        // Multi-Window Indicators (Dots)
        const count = item.count;
        if (count > 0) {
            const dot_spacing = 6.0;
            const total_dots_w = @as(f64, @floatFromInt(count - 1)) * dot_spacing;
            const start_dot_x = x + icon_w/2.0 - total_dots_w/2.0;

            for (0..count) |d| {
                const dot_x = start_dot_x + @as(f64, @floatFromInt(d)) * dot_spacing;
                c.cairo_arc(cr, dot_x, @as(f64, @floatFromInt(h)) - 3.0, 1.5, 0, 2.0 * std.math.pi);
                if (item.focused) {
                    theme.setSource(cr, t.accent_color);
                } else {
                    c.cairo_set_source_rgba(cr, 0.8, 0.8, 0.8, 0.8);
                }
                c.cairo_fill(cr);
            }
        }

        current_x += icon_w + PAD;
    }

    // Draw Settings Icon
    const cy = @divTrunc(h - DOCK_ICON_SIZE, 2);
    const settings_x = w - DOCK_ICON_SIZE - 20;
    const settings_surf = icon.load("preferences-system", DOCK_ICON_SIZE);
    c.cairo_set_source_surface(cr, settings_surf, @floatFromInt(settings_x), @floatFromInt(cy));
    c.cairo_paint(cr);
}

pub fn iconAt(w: i32, _: i32, tops: []toplevel.ToplevelInfo, top_count: i32, mouse_x: i32) i32 {
    const mx: f64 = @floatFromInt(mouse_x);
    initOrder();
    
    const DockItem = struct {
        app_id: []const u8,
        top_idx: ?usize,
    };
    var items: [100]DockItem = undefined;
    var num_items: usize = 0;
    
    for (0..persistent_count) |i| {
        items[num_items] = .{ .app_id = std.mem.sliceTo(&persistent_order[i], 0), .top_idx = null };
        num_items += 1;
    }
    
    for (0..@intCast(top_count)) |i| {
        const app_id = tops[i].app_id[0..std.mem.indexOfScalar(u8, &tops[i].app_id, 0) orelse tops[i].app_id.len];
        var found = false;
        for (0..num_items) |g| {
            if (std.mem.eql(u8, app_id, items[g].app_id) or 
                (std.mem.eql(u8, app_id, "foot-term") and std.mem.eql(u8, items[g].app_id, "foot")))
            {
                if (items[g].top_idx == null) items[g].top_idx = i;
                found = true;
                break;
            }
        }
        if (!found) {
            // Because iconAt might be called before draw for a new window,
            // we should also append to persistent_order here just in case.
            if (persistent_count < 100) {
                @memcpy(persistent_order[persistent_count][0..app_id.len], app_id);
                persistent_order[persistent_count][app_id.len] = 0;
                persistent_count += 1;
            }
            items[num_items] = .{ .app_id = app_id, .top_idx = i };
            num_items += 1;
        }
    }

    var widths = std.mem.zeroes([100]f64);
    var total_w: f64 = 0;
    const slot: f64 = DOCK_ICON_SIZE + PAD;
    const unscaled_total: f64 = if (num_items > 0) @as(f64, @floatFromInt(num_items)) * slot - PAD else 0;
    const unscaled_start_x: f64 = @max(0, (@as(f64, @floatFromInt(w)) - unscaled_total) / 2.0);

    for (0..num_items) |g| {
        const unscaled_x = unscaled_start_x + @as(f64, @floatFromInt(g)) * slot + (@as(f64, @floatFromInt(DOCK_ICON_SIZE)) / 2.0);
        var scale: f64 = 1.0;
        if (mx >= 0) {
            const dist = mx - unscaled_x;
            scale += 1.0 * std.math.exp(-(dist * dist) / 4000.0);
        }
        widths[g] = DOCK_ICON_SIZE * scale;
        total_w += widths[g] + PAD;
    }
    if (num_items > 0) total_w -= PAD;

    var current_x = @max(0, (@as(f64, @floatFromInt(w)) - total_w) / 2.0);

    for (0..num_items) |g| {
        const icon_w = widths[g];
        const half_w = icon_w / 2.0;
        const icon_center = current_x + half_w;

        // If the mouse is within bounds of this icon slot
        if (mx >= icon_center - half_w and mx <= icon_center + half_w) {
            if (items[g].top_idx) |idx| {
                return @intCast(idx); // return valid toplevel index
            } else {
                return @as(i32, @intCast(g)) + 1000; // special code: 1000 + group index
            }
        }

        current_x += icon_w + PAD;
    }
    
    // Check Settings Icon
    const settings_x = w - DOCK_ICON_SIZE - 20;
    if (mouse_x >= settings_x and mouse_x < settings_x + DOCK_ICON_SIZE + PAD) {
        return -2;
    }
    
    return -1;
}

pub fn groupAt(w: i32, mouse_x: i32) i32 {
    const mx: f64 = @floatFromInt(mouse_x);
    if (persistent_count == 0) return -1;

    var widths = std.mem.zeroes([100]f64);
    var total_w: f64 = 0;
    const slot: f64 = DOCK_ICON_SIZE + PAD;
    const unscaled_total: f64 = @as(f64, @floatFromInt(persistent_count)) * slot - PAD;
    const unscaled_start_x: f64 = @max(0, (@as(f64, @floatFromInt(w)) - unscaled_total) / 2.0);

    for (0..persistent_count) |g| {
        const unscaled_x = unscaled_start_x + @as(f64, @floatFromInt(g)) * slot + (@as(f64, @floatFromInt(DOCK_ICON_SIZE)) / 2.0);
        var scale: f64 = 1.0;
        if (mx >= 0) {
            const dist = mx - unscaled_x;
            scale += 1.0 * std.math.exp(-(dist * dist) / 4000.0);
        }
        widths[g] = DOCK_ICON_SIZE * scale;
        total_w += widths[g] + PAD;
    }
    total_w -= PAD;

    var current_x = @max(0, (@as(f64, @floatFromInt(w)) - total_w) / 2.0);

    for (0..persistent_count) |g| {
        const icon_w = widths[g];
        const half_w = icon_w / 2.0;
        const icon_center = current_x + half_w;

        if (mx >= icon_center - half_w and mx <= icon_center + half_w) {
            return @intCast(g);
        }
        current_x += icon_w + PAD;
    }
    return -1;
}

pub fn swapGroups(idxA: usize, idxB: usize) void {
    if (idxA >= persistent_count or idxB >= persistent_count) return;
    var tmp: [128]u8 = std.mem.zeroes([128]u8);
    @memcpy(&tmp, &persistent_order[idxA]);
    @memcpy(&persistent_order[idxA], &persistent_order[idxB]);
    @memcpy(&persistent_order[idxB], &tmp);
}

test "dock iconAt logic" {
    var tops: [10]toplevel.ToplevelInfo = undefined;
    for (0..10) |i| tops[i] = .{};
    
    // Set up 3 windows, 2 in the same group
    @memcpy(tops[0].app_id[0..9], "foot-term");
    @memcpy(tops[1].app_id[0..7], "firefox");
    @memcpy(tops[2].app_id[0..9], "foot-term");
    
    const w = 1920;
    
    // Test hitting outside
    try std.testing.expectEqual(@as(i32, -1), iconAt(w, 48, &tops, 3, 0));
    try std.testing.expectEqual(@as(i32, -1), iconAt(w, 48, &tops, 3, w / 2 - 200));
    
    // Test hitting settings icon
    const settings_x = w - DOCK_ICON_SIZE - 20;
    try std.testing.expectEqual(@as(i32, -2), iconAt(w, 48, &tops, 3, settings_x + 5));

    // Test grouping: there should be 2 groups (foot-term, firefox)
    // The total width of 2 icons = 2 * (DOCK_ICON_SIZE + PAD) - PAD.
    // They are centered. We can check if clicking near center hits group 0 or 1.
    const slot = DOCK_ICON_SIZE + PAD;
    const total_w = 2 * slot - PAD;
    const start_x = @divTrunc(w - total_w, 2);
    
    // Test hitting first group (foot-term)
    try std.testing.expectEqual(@as(i32, 0), iconAt(w, 48, &tops, 3, start_x + 5));
    
    // Test hitting second group (firefox)
    try std.testing.expectEqual(@as(i32, 1), iconAt(w, 48, &tops, 3, start_x + slot + 5));
}

test "dock groupAt logic" {
    persistent_count = 0;
    
    // Add 3 persistent groups
    @memcpy(&persistent_order[0], "foot\x00" ** 123);
    @memcpy(&persistent_order[1], "firefox\x00" ** 120);
    @memcpy(&persistent_order[2], "geary\x00" ** 122);
    persistent_count = 3;

    var widths: [128]f64 = undefined;
    widths[0] = 32.0;
    widths[1] = 32.0;
    widths[2] = 32.0;

    // Test positions
    const group0 = groupAt(0.0, &widths);
    try std.testing.expectEqual(@as(i32, 0), group0);

    const group1 = groupAt(32.0 + PAD + 10.0, &widths); // Hit group 1
    try std.testing.expectEqual(@as(i32, 1), group1);

    const group_miss = groupAt(999.0, &widths);
    try std.testing.expectEqual(@as(i32, -1), group_miss);
}

test "dock swapGroups logic" {
    persistent_count = 0;
    @memcpy(&persistent_order[0], "A\x00" ** 126);
    @memcpy(&persistent_order[1], "B\x00" ** 126);
    @memcpy(&persistent_order[2], "C\x00" ** 126);
    persistent_count = 3;

    swapGroups(0, 2);
    try std.testing.expectEqualStrings("C", std.mem.sliceTo(&persistent_order[0], 0));
    try std.testing.expectEqualStrings("B", std.mem.sliceTo(&persistent_order[1], 0));
    try std.testing.expectEqualStrings("A", std.mem.sliceTo(&persistent_order[2], 0));

    // Invalid swap should not crash
    swapGroups(0, 999);
}

test "dock initOrder logic" {
    persistent_count = 0;
    order_initialized = false;
    
    initOrder();
    
    try std.testing.expectEqual(@as(usize, 3), persistent_count);
    try std.testing.expectEqualStrings("foot", std.mem.sliceTo(&persistent_order[0], 0));
    try std.testing.expectEqualStrings("firefox", std.mem.sliceTo(&persistent_order[1], 0));
    try std.testing.expectEqualStrings("nemo", std.mem.sliceTo(&persistent_order[2], 0));
}
