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
    // Convert ToplevelInfo arrays to C string arrays
    var app_ids: [64]?[*:0]const u8 = undefined;
    var titles: [64]?[*:0]const u8 = undefined;
    var focused: [64]i32 = undefined;

    for (0..@intCast(top_count)) |i| {
        const app_id_slice = tops[i].app_id[0..std.mem.indexOfScalar(u8, &tops[i].app_id, 0) orelse tops[i].app_id.len];
        const title_slice = tops[i].title[0..std.mem.indexOfScalar(u8, &tops[i].title, 0) orelse tops[i].title.len];
        app_ids[i] = @ptrCast(app_id_slice.ptr);
        titles[i] = @ptrCast(title_slice.ptr);
        focused[i] = if (tops[i].focused) 1 else 0;
    }

    // Build C-compatible arrays
    var c_app_ids: [64]?[*:0]const u8 = undefined;
    var c_titles: [64]?[*:0]const u8 = undefined;
    var c_focused: [64]c_int = undefined;
    for (0..@intCast(top_count)) |i| {
        c_app_ids[i] = app_ids[i];
        c_titles[i] = titles[i];
        c_focused[i] = focused[i];
    }

    c.dock_draw(
        renderer.handle,
        w,
        h,
        @ptrCast(&c_app_ids),
        @ptrCast(&c_titles),
        @ptrCast(&c_focused),
        @intCast(top_count),
        @intCast(hover_idx),
    );
}

pub fn iconAt(w: i32, _: i32, _: []toplevel.ToplevelInfo, top_count: i32, mouse_x: i32) i32 {
    return c.dock_icon_at(w, 0, @intCast(top_count), @intCast(mouse_x));
}
