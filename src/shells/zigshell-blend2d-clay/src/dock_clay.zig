// dock_clay.zig — Clay-based dock renderer for Blend2D
// Uses Clay for layout structure, Blend2D for icon/image rendering.

const std = @import("std");
const c = @import("c.zig");
const blend2d = @import("blend2d_render.zig");
const toplevel = @import("shellcore").toplevel;

// Dock constants (matching dock.c)
const ICON_SIZE: f64 = 28;
const DOCK_PAD: f64 = 8;
const DOCK_HEIGHT: f64 = 48;
const FOCUS_BAR_H: f64 = 3;

// C functions from dock_clay_layout.c
extern fn clay_layout_dock_bar(width: c_int, height: c_int, state: ?*anyopaque) c_int;

// C functions from dock.c (existing icon loading)
extern fn dock_draw(
    renderer: ?*c.BlendRenderer,
    w: c_int, h: c_int,
    app_ids: [*c]const [*c]const u8,
    titles: [*c]const [*c]const u8,
    focused: [*c]c_int,
    top_count: c_int,
    hover_idx: c_int,
) void;

/// Dock state passed to Clay layout
const DockState = extern struct {
    top_count: c_int,
    hover_idx: c_int,
    settings_hover: c_int,
    launcher_hover: c_int,
};

/// Draw the dock using Clay for layout + Blend2D for rendering.
/// This is the main entry point called from main.zig.
pub fn draw(
    renderer: *blend2d.BlendRenderer,
    width: i32,
    height: i32,
    tops: []toplevel.ToplevelInfo,
    top_count: i32,
    hover_idx: i32,
) void {
    // 1. Get Clay to compute the layout
    var state = DockState{
        .top_count = @intCast(@max(top_count, 0)),
        .hover_idx = @intCast(hover_idx),
        .settings_hover = 0,
        .launcher_hover = 0,
    };

    _ = clay_layout_dock_bar(@intCast(width), @intCast(height), &state);

    // 2. Render the Clay structural commands (background, borders, hover highlights)
    renderClayStructure(renderer);

    // 3. Render icons on top of the Clay layout
    renderIcons(renderer, width, height, tops, top_count, hover_idx);
}

/// Render the Clay-generated structural commands (background, dividers, hover areas)
fn renderClayStructure(renderer: *blend2d.BlendRenderer) void {
    const count = c.clay.clay_cmd_count();
    for (0..@intCast(count)) |i| {
        const idx: c_int = @intCast(i);
        const cmd_type = c.clay.clay_cmd_type(idx);

        const x = c.clay.clay_cmd_x(idx);
        const y = c.clay.clay_cmd_y(idx);
        const w = c.clay.clay_cmd_w(idx);
        const h = c.clay.clay_cmd_h(idx);

        switch (cmd_type) {
            1 => { // RECTANGLE
                const color = colorToArgb(
                    c.clay.clay_cmd_bg_r(idx),
                    c.clay.clay_cmd_bg_g(idx),
                    c.clay.clay_cmd_bg_b(idx),
                    c.clay.clay_cmd_bg_a(idx),
                );
                const radius = c.clay.clay_cmd_radius(idx);
                if (radius > 0.5) {
                    renderer.fillRoundRect(x, y, w, h, radius, color);
                } else {
                    renderer.fillRect(x, y, w, h, color);
                }
            },
            2 => { // BORDER
                const color = colorToArgb(
                    c.clay.clay_cmd_border_r(idx),
                    c.clay.clay_cmd_border_g(idx),
                    c.clay.clay_cmd_border_b(idx),
                    c.clay.clay_cmd_border_a(idx),
                );
                renderer.drawBorder(x, y, w, h, color);
            },
            else => {},
        }
    }
}

/// Render app icons on top of the Clay layout positions
fn renderIcons(
    renderer: *blend2d.BlendRenderer,
    width: i32,
    height: i32,
    tops: []toplevel.ToplevelInfo,
    top_count: i32,
    hover_idx: i32,
) void {
    const safe_count: usize = @min(@as(usize, @intCast(@max(top_count, 0))), 64);
    if (safe_count == 0) return;

    // Calculate icon positions (matching Clay layout math)
    const icon_size_i: i32 = @intFromFloat(ICON_SIZE);
    const dock_pad_i: i32 = @intFromFloat(DOCK_PAD);
    const icon_count_i: i32 = @intCast(safe_count);
    const icon_area_w: f64 = @floatFromInt(icon_count_i * (icon_size_i + dock_pad_i) - dock_pad_i);
    const toggle_area_w: f64 = 2.0 * (ICON_SIZE + DOCK_PAD);
    const total_content_w = icon_area_w + DOCK_PAD + 1.0 + DOCK_PAD + toggle_area_w;
    const left_pad = @max(0.0, (@as(f64, @floatFromInt(width)) - total_content_w) / 2.0);

    const cy = (@as(f64, @floatFromInt(height)) - ICON_SIZE) / 2.0;

    // Draw each app icon
    for (0..safe_count) |i| {
        const x = left_pad + @as(f64, @floatFromInt(i)) * (ICON_SIZE + DOCK_PAD);

        // Hover highlight (semi-transparent white pill)
        if (@as(i32, @intCast(i)) == hover_idx) {
            renderer.fillRoundRect(x - 4, cy - 4, ICON_SIZE + 8, ICON_SIZE + 8, 6, 0x18FFFFFF);
        }

        // Load icon via the C icon_load function
        const app_id = tops[i].app_id;

        // Get null-terminated name length
        const app_id_len = std.mem.indexOfScalar(u8, &app_id, 0) orelse @max(app_id.len, 1);
        _ = app_id_len; // Will be used when icon_load is wired up

        // We need to call the C icon_load function. For now, draw a placeholder
        // rounded rect where the icon would be.
        const slot_color: u32 = if (tops[i].focused) 0xFF4C7FBF else 0xFF3A3A4A;
        renderer.fillRoundRect(x, cy, ICON_SIZE, ICON_SIZE, 4, slot_color);

        // Focus bar (below icon)
        if (tops[i].focused) {
            renderer.fillRect(x + 2, cy + ICON_SIZE, ICON_SIZE - 4, FOCUS_BAR_H, 0xFF4C7FBF);
        }
    }

    // Settings toggle (icon placeholder)
    const settings_x = left_pad + icon_area_w + DOCK_PAD + 1.0 + DOCK_PAD;
    renderer.fillRoundRect(settings_x, cy, ICON_SIZE, ICON_SIZE, 4, 0xFF3A3A4A);

    // Launcher toggle (icon placeholder)
    const launcher_x = settings_x + ICON_SIZE + DOCK_PAD;
    renderer.fillRoundRect(launcher_x, cy, ICON_SIZE, ICON_SIZE, 4, 0xFF3A3A4A);
}

inline fn colorToArgb(r: f32, g: f32, b: f32, a: f32) u32 {
    const ri: u32 = @intFromFloat(@max(0, @min(255, r)));
    const gi: u32 = @intFromFloat(@max(0, @min(255, g)));
    const bi: u32 = @intFromFloat(@max(0, @min(255, b)));
    const ai: u32 = @intFromFloat(@max(0, @min(255, a)));
    return (ai << 24) | (ri << 16) | (gi << 8) | bi;
}
