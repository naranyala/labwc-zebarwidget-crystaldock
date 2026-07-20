// clay_panel.zig — Declarative Clay layout for the panel bar.
//
// Provides layoutPanel() which declares the panel's flexbox hierarchy
// using Clay's C API. Called between Clay_BeginLayout() and Clay_EndLayout()
// in the render loop.

const std = @import("std");
const clay_cairo = @import("clay_cairo.zig");
const cc = clay_cairo.clay;
const panel_mod = @import("panel.zig");

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

/// Declares the panel layout tree inside an active Clay layout pass.
/// `widgets` and `widget_count` come from the panel module's global state.
pub fn layoutPanel(
    width: i32,
    height: i32,
    widgets: []panel_mod.Widget,
    widget_count: i32,
) void {
    const w_f: f32 = @floatFromInt(width);
    const h_f: f32 = @floatFromInt(height);
    const wc: usize = @intCast(@max(@as(i32, 0), widget_count));

    // Root panel container: full width, fixed height, horizontal layout
    cc.Clay__OpenElement();
    _ = cc.Clay__ConfigureOpenElement(std.mem.zeroInit(cc.Clay_ElementDeclaration, .{
        .layout = .{
            .sizing = .{ .width = sizingFixed(w_f), .height = sizingFixed(h_f) },
            .padding = .{ .left = 8, .right = 8, .top = 0, .bottom = 0 },
            .childGap = 6,
            .childAlignment = .{ .x = cc.CLAY_ALIGN_X_LEFT, .y = cc.CLAY_ALIGN_Y_CENTER },
            .layoutDirection = cc.CLAY_LEFT_TO_RIGHT,
        },
        .backgroundColor = .{ .r = 30, .g = 30, .b = 35, .a = 240 },
    }));

    // ---- Left-side widgets ----
    cc.Clay__OpenElement();
    _ = cc.Clay__ConfigureOpenElement(std.mem.zeroInit(cc.Clay_ElementDeclaration, .{
        .layout = .{
            .sizing = .{ .width = sizingFit(), .height = sizingGrow() },
            .childGap = 6,
            .childAlignment = .{ .x = cc.CLAY_ALIGN_X_LEFT, .y = cc.CLAY_ALIGN_Y_CENTER },
            .layoutDirection = cc.CLAY_LEFT_TO_RIGHT,
        },
    }));
    for (0..wc) |i| {
        if (widgets[i].hidden or widgets[i].side == 1) continue;
        layoutWidgetSlot(&widgets[i], h_f);
    }
    cc.Clay__CloseElement(); // end left group

    // ---- Spacer (pushes right widgets to the right edge) ----
    cc.Clay__OpenElement();
    _ = cc.Clay__ConfigureOpenElement(std.mem.zeroInit(cc.Clay_ElementDeclaration, .{
        .layout = .{
            .sizing = .{ .width = sizingGrow(), .height = sizingFixed(1) },
        },
    }));
    cc.Clay__CloseElement(); // end spacer

    // ---- Right-side widgets ----
    cc.Clay__OpenElement();
    _ = cc.Clay__ConfigureOpenElement(std.mem.zeroInit(cc.Clay_ElementDeclaration, .{
        .layout = .{
            .sizing = .{ .width = sizingFit(), .height = sizingGrow() },
            .childGap = 6,
            .childAlignment = .{ .x = cc.CLAY_ALIGN_X_RIGHT, .y = cc.CLAY_ALIGN_Y_CENTER },
            .layoutDirection = cc.CLAY_LEFT_TO_RIGHT,
        },
    }));
    for (0..wc) |i| {
        if (widgets[i].hidden or widgets[i].side != 1) continue;
        layoutWidgetSlot(&widgets[i], h_f);
    }
    cc.Clay__CloseElement(); // end right group

    cc.Clay__CloseElement(); // end root panel
}

// ---- Per-widget element ----

fn layoutWidgetSlot(w: *const panel_mod.Widget, panel_h: f32) void {
    // Use cached width from the existing measure pass if available,
    // otherwise fall back to a reasonable default.
    const slot_w: f32 = if (w.cached_w > 0) @floatFromInt(w.cached_w) else 60.0;

    cc.Clay__OpenElement();
    _ = cc.Clay__ConfigureOpenElement(std.mem.zeroInit(cc.Clay_ElementDeclaration, .{
        .layout = .{
            .sizing = .{ .width = sizingFixed(slot_w), .height = sizingFixed(panel_h) },
            .childAlignment = .{ .x = cc.CLAY_ALIGN_X_CENTER, .y = cc.CLAY_ALIGN_Y_CENTER },
        },
        // Transparent background — the actual widget content is drawn by
        // the existing draw_fn callbacks on top of Clay's layout positions.
        .backgroundColor = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
    }));

    // For now we emit a placeholder text element with the widget type name
    // so the layout has measurable content. This will be replaced by CUSTOM
    // render commands that delegate to the real widget draw functions.
    const type_name = panel_mod.widgetTypeName(w.wtype);
    cc.Clay__OpenTextElement(
        .{ .length = @intCast(type_name.len), .chars = type_name.ptr, .isStaticallyAllocated = true },
        std.mem.zeroInit(cc.Clay_TextElementConfig, .{
            .fontSize = 11,
            .textColor = .{ .r = 220, .g = 220, .b = 225, .a = 255 },
            .wrapMode = cc.CLAY_TEXT_WRAP_NONE,
        }),
    );

    cc.Clay__CloseElement(); // end widget slot
}
