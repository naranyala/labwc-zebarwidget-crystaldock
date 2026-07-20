// clay_dock.zig — Declarative Clay layout for the dock bar.
//
// Provides layoutDock() which declares the dock's flexbox hierarchy
// using Clay's C API. Called between Clay_BeginLayout() and Clay_EndLayout()
// in the render loop.

const std = @import("std");
const clay_cairo = @import("clay_cairo.zig");
const cc = clay_cairo.clay;

// ---- Sizing helpers (mirror Clay macros) ----

fn sizingGrow() cc.Clay_SizingAxis {
    return .{ .size = .{ .minMax = .{ .min = 0, .max = 0 } }, .type = cc.CLAY__SIZING_TYPE_GROW };
}

fn sizingFit() cc.Clay_SizingAxis {
    return .{ .size = .{ .minMax = .{ .min = 0, .max = 0 } }, .type = cc.CLAY__SIZING_TYPE_FIT };
}

fn sizingFixed(px: f32) cc.Clay_SizingAxis {
    return .{ .size = .{ .minMax = .{ .min = px, .max = px } }, .type = cc.CLAY__SIZING_TYPE_FIXED };
}

// ---- Layout declaration ----

/// Declares the dock layout tree inside an active Clay layout pass.
/// `num_items` is the count of grouped dock icons (pinned + running).
/// `icon_size` is the base icon size in pixels (typically 28).
pub fn layoutDock(
    width: i32,
    height: i32,
    num_items: usize,
    icon_size: i32,
) void {
    const w_f: f32 = @floatFromInt(width);
    const h_f: f32 = @floatFromInt(height);
    const icon_f: f32 = @floatFromInt(icon_size);
    const pad: u16 = 8;

    // Root dock container: full width, full height, centered children
    cc.Clay__OpenElement();
    _ = cc.Clay__ConfigureOpenElement(std.mem.zeroInit(cc.Clay_ElementDeclaration, .{
        .layout = .{
            .sizing = .{ .width = sizingFixed(w_f), .height = sizingFixed(h_f) },
            .childAlignment = .{ .x = cc.CLAY_ALIGN_X_CENTER, .y = cc.CLAY_ALIGN_Y_CENTER },
            .layoutDirection = cc.CLAY_LEFT_TO_RIGHT,
        },
        .backgroundColor = .{ .r = 25, .g = 25, .b = 30, .a = 240 },
        // Top border
        .border = .{
            .color = .{ .r = 80, .g = 80, .b = 90, .a = 255 },
            .width = .{ .top = 1, .bottom = 0, .left = 0, .right = 0, .betweenChildren = 0 },
        },
    }));

    // ---- Inner centered content row ----
    cc.Clay__OpenElement();
    _ = cc.Clay__ConfigureOpenElement(std.mem.zeroInit(cc.Clay_ElementDeclaration, .{
        .layout = .{
            .sizing = .{ .width = sizingFit(), .height = sizingFit() },
            .childGap = pad,
            .childAlignment = .{ .x = cc.CLAY_ALIGN_X_CENTER, .y = cc.CLAY_ALIGN_Y_CENTER },
            .layoutDirection = cc.CLAY_LEFT_TO_RIGHT,
            .padding = .{ .left = 0, .right = 0, .top = 6, .bottom = 6 },
        },
    }));

    // ---- App icon slots ----
    for (0..num_items) |_| {
        cc.Clay__OpenElement();
        _ = cc.Clay__ConfigureOpenElement(std.mem.zeroInit(cc.Clay_ElementDeclaration, .{
            .layout = .{
                .sizing = .{ .width = sizingFixed(icon_f), .height = sizingFixed(icon_f) },
            },
            // Semi-transparent placeholder — CUSTOM elements will replace these
            .backgroundColor = .{ .r = 60, .g = 60, .b = 70, .a = 80 },
            .cornerRadius = .{ .topLeft = 6, .topRight = 6, .bottomLeft = 6, .bottomRight = 6 },
        }));
        cc.Clay__CloseElement(); // end icon slot
    }

    // ---- Vertical divider ----
    cc.Clay__OpenElement();
    _ = cc.Clay__ConfigureOpenElement(std.mem.zeroInit(cc.Clay_ElementDeclaration, .{
        .layout = .{
            .sizing = .{ .width = sizingFixed(1), .height = sizingFixed(h_f - 12) },
        },
        .backgroundColor = .{ .r = 80, .g = 80, .b = 90, .a = 200 },
    }));
    cc.Clay__CloseElement(); // end divider

    // ---- Toggle buttons (settings, launcher, home) ----
    for (0..3) |_| {
        cc.Clay__OpenElement();
        _ = cc.Clay__ConfigureOpenElement(std.mem.zeroInit(cc.Clay_ElementDeclaration, .{
            .layout = .{
                .sizing = .{ .width = sizingFixed(icon_f), .height = sizingFixed(icon_f) },
            },
            .backgroundColor = .{ .r = 50, .g = 50, .b = 60, .a = 80 },
            .cornerRadius = .{ .topLeft = 4, .topRight = 4, .bottomLeft = 4, .bottomRight = 4 },
        }));
        cc.Clay__CloseElement(); // end toggle
    }

    cc.Clay__CloseElement(); // end inner row
    cc.Clay__CloseElement(); // end root dock
}
