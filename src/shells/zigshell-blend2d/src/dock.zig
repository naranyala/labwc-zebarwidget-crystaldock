// dock.zig — Zig wrapper for C dock functions (dock.c)
const std = @import("std");
const c = @import("c.zig").c;

const toplevel = @import("shellcore").toplevel;
const blend2d = @import("blend2d_render.zig");

pub var DOCK_ICON_SIZE: i32 = 28;
pub const DOCK_PAD = c.DOCK_PAD;

pub fn draw(
    renderer: *blend2d.BlendRenderer,
    w: i32,
    h: i32,
    tops: []toplevel.ToplevelInfo,
    top_count: i32,
    hover_idx: i32,
) void {
    var c_app_ids: [64]?[*:0]const u8 = undefined;
    var c_titles: [64]?[*:0]const u8 = undefined;
    var c_focused: [64]c_int = undefined;

    const safe_count: usize = @min(@as(usize, @intCast(@max(top_count, 0))), 64);
    for (0..safe_count) |i| {
        const app_id_idx = std.mem.indexOfScalar(u8, &tops[i].app_id, 0) orelse @max(tops[i].app_id.len, 1) - 1;
        const title_idx = std.mem.indexOfScalar(u8, &tops[i].title, 0) orelse @max(tops[i].title.len, 1) - 1;
        const app_id_slice = tops[i].app_id[0..app_id_idx];
        const title_slice = tops[i].title[0..title_idx];
        c_app_ids[i] = @ptrCast(app_id_slice.ptr);
        c_titles[i] = @ptrCast(title_slice.ptr);
        c_focused[i] = if (tops[i].focused) 1 else 0;
    }

    // Map hover_idx to items array index for visual feedback
    const hovered_g: i32 = hover_idx;
    c.dock_draw(
        renderer.handle,
        w,
        h,
        @ptrCast(&c_app_ids),
        @ptrCast(&c_titles),
        @ptrCast(&c_focused),
        @intCast(safe_count),
        hovered_g,
    );
}

pub fn iconAt(w: i32, _: i32, _: []toplevel.ToplevelInfo, top_count: i32, mouse_x: i32) i32 {
    return c.dock_icon_at(w, 0, @intCast(top_count), @intCast(mouse_x));
}
