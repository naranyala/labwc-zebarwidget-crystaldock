// render.zig — All rendering functions extracted from main_shell.zig
// Panel, dock, launcher, modal, calendar, tooltip, dynamic island rendering.

const std = @import("std");
const c = @import("c.zig").c;
const theme = @import("theme.zig");
const panel_mod = @import("panel.zig");
const modal_mod = @import("modal.zig");
const dock_mod = @import("dock.zig");
const icon = @import("icon.zig");
const surface_mod = @import("surface.zig");
const state = @import("shell_state.zig");

const SurfaceState = surface_mod.SurfaceState;

/// Find the settings widget index.
pub fn findSettingsWidget() i32 {
    for (0..@intCast(@max(0, state.widget_count))) |i| {
        if (state.widgets[i].hidden) continue;
        if (state.widgets[i].wtype == .settings) return @intCast(i);
    }
    return -1;
}

/// Draw a rounded rectangle using Cairo arcs.
pub fn roundedRect(cr: *c.cairo_t, x: f64, y: f64, w: f64, h: f64, r: f64) void {
    const pi = std.math.pi;
    c.cairo_new_sub_path(cr);
    c.cairo_arc(cr, x + r, y + r, r, pi, 1.5 * pi);
    c.cairo_arc(cr, x + w - r, y + r, r, -0.5 * pi, 0);
    c.cairo_arc(cr, x + w - r, y + h - r, r, 0, 0.5 * pi);
    c.cairo_arc(cr, x + r, y + h - r, r, 0.5 * pi, pi);
    c.cairo_close_path(cr);
}

/// Render the panel bar.
pub fn renderPanel(ss: *SurfaceState) void {
    surface_mod.ensureBuffer(ss, state.shm);
    const cr = ss.cairo_cr orelse return;
    const w = ss.width;
    const t = &theme.current;

    c.cairo_set_operator(cr, c.CAIRO_OPERATOR_CLEAR);
    c.cairo_paint(cr);
    c.cairo_set_operator(cr, c.CAIRO_OPERATOR_OVER);

    const ph = state.panel_height;
    const grad = c.cairo_pattern_create_linear(0, 0, 0, ph);
    c.cairo_pattern_add_color_stop_rgba(grad, 0.0, t.bg_color[0], t.bg_color[1], t.bg_color[2], t.bg_color[3]);
    c.cairo_pattern_add_color_stop_rgba(grad, 1.0, t.bg_gradient_end[0], t.bg_gradient_end[1], t.bg_gradient_end[2], t.bg_gradient_end[3]);
    c.cairo_set_source(cr, grad);
    c.cairo_rectangle(cr, 0, 0, w, ph);
    c.cairo_fill(cr);
    c.cairo_pattern_destroy(grad);

    theme.setSource(cr, t.accent_color);
    c.cairo_rectangle(cr, 0, ph - 2, w, 2);
    c.cairo_fill(cr);

    const pad: i32 = 6;
    _ = panel_mod.widgetListWidth(state.widgets[0..@intCast(@max(0, state.widget_count))], ph, pad, cr);
    const x0: i32 = 8;

    var left_w: i32 = 0;
    var right_w: i32 = 0;
    for (0..@intCast(@max(0, state.widget_count))) |i| {
        if (state.widgets[i].hidden) continue;
        if (state.widgets[i].side == 1) right_w += state.widgets[i].cached_w + pad
        else left_w += state.widgets[i].cached_w + pad;
    }
    if (left_w > 0) left_w -= pad;
    if (right_w > 0) right_w -= pad;

    const settings_idx = findSettingsWidget();
    const settings_width: i32 = if (settings_idx >= 0) 28 else 0;
    var x: i32 = x0 + settings_width;
    for (0..@intCast(@max(0, state.widget_count))) |i| {
        if (state.widgets[i].hidden or state.widgets[i].side == 1) continue;
        if (i == settings_idx) continue;
        state.widget_x[i] = x;
        x += state.widgets[i].cached_w + pad;
    }
    if (settings_idx >= 0) state.widget_x[@intCast(settings_idx)] = x0;

    var rx: i32 = @intCast(@max(@as(i64, 0), @as(i64, w) - @as(i64, x0) - @as(i64, right_w)));
    if (rx < x) rx = x;
    for (0..@intCast(@max(0, state.widget_count))) |i| {
        if (state.widgets[i].hidden or state.widgets[i].side != 1) continue;
        if (i == settings_idx) continue;
        state.widget_x[i] = rx;
        rx += state.widgets[i].cached_w + pad;
    }

    for (0..@intCast(@max(0, state.widget_count))) |i| {
        if (state.widgets[i].hidden) continue;
        if (state.pointer_on_panel) {
            const wx = state.widget_x[i];
            const ww = state.widgets[i].cached_w;
            const hx0 = wx - 2;
            const hx1 = wx + ww + 2;
            if (state.pointer_x >= hx0 and state.pointer_x <= hx1 and state.pointer_y >= 0 and state.pointer_y <= ph) {
                c.cairo_set_source_rgba(cr, t.accent_color[0], t.accent_color[1], t.accent_color[2], 0.18);
                roundedRect(cr, @floatFromInt(hx0), 3, @floatFromInt(hx1 - hx0), @floatFromInt(ph - 6), 6.0);
                c.cairo_fill(cr);
            }
        }
        if (state.widgets[i].draw_fn) |fn_ptr| {
            fn_ptr(&state.widgets[i], cr, state.widget_x[i], 0, ph);
        }
    }

    if (settings_idx >= 0) {
        const sx = state.widget_x[@intCast(settings_idx)];
        const sy = @divFloor(ph - 16, 2);
        const surf = icon.load("preferences-system", 16);
        c.cairo_set_source_surface(cr, surf, @floatFromInt(sx + 6), @floatFromInt(sy));
        c.cairo_paint(cr);
    }
}

/// Render the dock bar.
pub fn renderDock(ss: *SurfaceState) void {
    surface_mod.ensureBuffer(ss, state.shm);
    const cr = ss.cairo_cr orelse return;
    const w = ss.width;
    const h = ss.height;

    c.cairo_set_operator(cr, c.CAIRO_OPERATOR_CLEAR);
    c.cairo_paint(cr);
    c.cairo_set_operator(cr, c.CAIRO_OPERATOR_OVER);

    // The dock background is drawn inside dock_mod.dock_draw
    dock_mod.draw(cr, w, h, state.toplevels[0..@intCast(@max(0, state.toplevel_count))], @intCast(@max(0, state.toplevel_count)), state.dock_hover_idx, 0.0);
}

/// Render the dock tooltip.
pub fn drawDockTooltip(cr: *c.cairo_t, surf_w: i32, surf_h: i32) void {
    if (state.dock_hover_idx < 0 or state.dock_hover_idx >= state.toplevel_count) return;
    const t = &theme.current;
    const title = &state.toplevels[@intCast(state.dock_hover_idx)].title;
    const title_len = std.mem.indexOfScalar(u8, title, 0) orelse @max(title.len, 1) - 1;
    if (title_len == 0) return;

    const tt_pad: i32 = 8;
    const tt_h: i32 = 28;
    const tt_y: i32 = surf_h - tt_h - 4;
    const tt_w: i32 = @intCast(@max(title_len * 8 + tt_pad * 2, 60));
    const tt_x: i32 = @intCast(@max(@as(i64, 0), @as(i64, surf_w) - @as(i64, tt_w)) / 2);

    c.cairo_set_source_rgba(cr, t.tooltip_bg[0], t.tooltip_bg[1], t.tooltip_bg[2], t.tooltip_bg[3]);
    roundedRect(cr, @floatFromInt(tt_x), @floatFromInt(tt_y), @floatFromInt(tt_w), @floatFromInt(tt_h), 6.0);
    c.cairo_fill(cr);

    c.cairo_set_source_rgba(cr, t.tooltip_fg[0], t.tooltip_fg[1], t.tooltip_fg[2], t.tooltip_fg[3]);
    c.cairo_select_font_face(cr, "sans-serif", c.CAIRO_FONT_SLANT_NORMAL, c.CAIRO_FONT_WEIGHT_NORMAL);
    c.cairo_set_font_size(cr, 12.0);
    var buf: [256]u8 = undefined;
    const copy_len = @min(title_len, buf.len - 1);
    @memcpy(buf[0..copy_len], title[0..copy_len]);
    buf[copy_len] = 0;
    c.cairo_move_to(cr, @floatFromInt(tt_x + tt_pad), @floatFromInt(tt_y + 20));
    _ = c.cairo_show_text(cr, @ptrCast(&buf));
}

/// Render the launcher overlay.
pub fn renderLauncher(ss: *SurfaceState) void {
    surface_mod.ensureBuffer(ss, state.shm);
    const cr = ss.cairo_cr orelse return;
    const w = ss.width;
    const h = ss.height;

    c.cairo_set_operator(cr, c.CAIRO_OPERATOR_CLEAR);
    c.cairo_paint(cr);
    c.cairo_set_operator(cr, c.CAIRO_OPERATOR_OVER);

    // Semi-transparent background
    c.cairo_set_source_rgba(cr, 0.0, 0.0, 0.0, 0.5);
    c.cairo_rectangle(cr, 0, 0, w, h);
    c.cairo_fill(cr);

    // Launcher content
    c.cairo_set_source_rgba(cr, 0.15, 0.15, 0.18, 0.95);
    roundedRect(cr, 20.0, 20.0, @floatFromInt(w - 40), @floatFromInt(h - 40), 12.0);
    c.cairo_fill(cr);

    c.cairo_set_source_rgba(cr, 1.0, 1.0, 1.0, 1.0);
    c.cairo_select_font_face(cr, "sans-serif", c.CAIRO_FONT_SLANT_NORMAL, c.CAIRO_FONT_WEIGHT_BOLD);
    c.cairo_set_font_size(cr, 18.0);
    c.cairo_move_to(cr, 40.0, 60.0);
    _ = c.cairo_show_text(cr, "App Launcher");
}

/// Render the modal dialog.
pub fn renderModal(ss: *SurfaceState) void {
    surface_mod.ensureBuffer(ss, state.shm);
    const cr = ss.cairo_cr orelse return;
    const w = ss.width;
    const h = ss.height;

    c.cairo_set_operator(cr, c.CAIRO_OPERATOR_CLEAR);
    c.cairo_paint(cr);
    c.cairo_set_operator(cr, c.CAIRO_OPERATOR_OVER);

    c.cairo_set_source_rgba(cr, 0.0, 0.0, 0.0, 0.5);
    c.cairo_rectangle(cr, 0, 0, w, h);
    c.cairo_fill(cr);

    c.cairo_set_source_rgba(cr, 0.15, 0.15, 0.18, 0.95);
    roundedRect(cr, 20.0, 20.0, @floatFromInt(w - 40), @floatFromInt(h - 40), 12.0);
    c.cairo_fill(cr);
}

/// Draw the dynamic island overlay.
pub fn drawDynamicIsland(cr: *c.cairo_t, w: i32) void {
    const di_w: i32 = 300;
    const di_h: i32 = 36;
    const di_x: i32 = (w - di_w) / 2;
    const di_y: i32 = 4;
    c.cairo_set_source_rgba(cr, 0.1, 0.1, 0.12, 0.9);
    roundedRect(cr, @floatFromInt(di_x), @floatFromInt(di_y), @floatFromInt(di_w), @floatFromInt(di_h), 18.0);
    c.cairo_fill(cr);
}
