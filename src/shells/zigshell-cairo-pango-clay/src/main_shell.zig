// main_shell.zig — Slim main with event loop, Wayland setup, and glue code
// All major functionality extracted to: shell_state, surface, render, input, wayland.

const std = @import("std");
const c = @import("c.zig").c;
const theme = @import("theme.zig");
const panel_mod = @import("panel.zig");
const dock_mod = @import("dock.zig");
const icon = @import("icon.zig");
const pcfg = @import("panel_config.zig");
const config_manager = @import("config_manager.zig");
const clay_cairo = @import("clay_cairo.zig");
const shlog = @import("log");

// Extracted modules
const state = @import("shell_state.zig");
const surface_mod = @import("surface.zig");
const render_mod = @import("render.zig");
const input_mod = @import("input.zig");
const wayland_mod = @import("wayland.zig");

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = shlog.logFn,
};

// Re-export public API for other modules
pub const panel_height = &state.panel_height;
pub const font_scale = &state.font_scale;
pub const autohide_dock = &state.autohide_dock;
pub const autohide_panel = &state.autohide_panel;
pub const markDirty = state.markDirty;
pub const panel_surface = &state.panel_surface;
pub const dock_surface = &state.dock_surface;
pub const launcher_surface = &state.launcher_surface;
pub const modal_surface = &state.modal_surface;
pub const widgets = &state.widgets;
pub const widget_count = &state.widget_count;
pub const widget_x = &state.widget_x;
pub const toplevels = &state.toplevels;
pub const toplevel_count = &state.toplevel_count;
pub const dock_hover_idx = &state.dock_hover_idx;
pub const pointer_x = &state.pointer_x;
pub const pointer_y = &state.pointer_y;
pub const pointer_on_panel = &state.pointer_on_panel;
pub const pointer_on_dock = &state.pointer_on_dock;
pub const settings_open = &state.settings_open;
pub const config_dirty = &state.config_dirty;
pub const running = &state.running;
pub const config_path = &state.config_path;

fn onSighup(_: c_int) callconv(.c) void {
    state.reload_config = true;
}

fn reloadWidgets() void {
    const count = panel_mod.widgetCreateDefault(&state.widgets);
    state.widget_count = count;
    if (state.config_path) |p| {
        _ = pcfg.Config.load(std.heap.page_allocator, p, .{ .widgets = &state.widgets, .count = &state.widget_count });
        config_manager.applyConfigToRuntime();
    }
}

// ---- Wayland listener structs ----

const surface_listener = c.wl_surface_listener{
    .enter = struct {
        fn cb(_: ?*anyopaque, _: ?*c.wl_surface, _: ?*c.wl_output) callconv(.c) void {}
    }.cb,
    .leave = struct {
        fn cb(_: ?*anyopaque, _: ?*c.wl_surface, _: ?*c.wl_output) callconv(.c) void {}
    }.cb,
};

const registry_listener = c.wl_registry_listener{
    .global = wayland_mod.registryGlobal,
    .global_remove = struct {
        fn cb(_: ?*anyopaque, _: ?*c.wl_registry, _: u32) callconv(.c) void {}
    }.cb,
};

const panel_layer_listener = c.zwlr_layer_surface_v1_listener{
    .configure = wayland_mod.layerSurfaceConfigure,
    .closed = wayland_mod.layerSurfaceClosed,
};

const dock_layer_listener = c.zwlr_layer_surface_v1_listener{
    .configure = wayland_mod.layerSurfaceConfigure,
    .closed = wayland_mod.layerSurfaceClosed,
};

const launcher_layer_listener = c.zwlr_layer_surface_v1_listener{
    .configure = wayland_mod.layerSurfaceConfigure,
    .closed = wayland_mod.layerSurfaceClosed,
};

const modal_layer_listener = c.zwlr_layer_surface_v1_listener{
    .configure = wayland_mod.layerSurfaceConfigure,
    .closed = wayland_mod.layerSurfaceClosed,
};

const pointer_listener = c.wl_pointer_listener{
    .enter = input_mod.pointerEnter,
    .leave = input_mod.pointerLeave,
    .motion = input_mod.pointerMotion,
    .button = input_mod.pointerButton,
    .axis = input_mod.pointerAxis,
    .frame = struct {
        fn cb(_: ?*anyopaque, _: ?*c.wl_pointer) callconv(.c) void {}
    }.cb,
    .axis_source = struct {
        fn cb(_: ?*anyopaque, _: ?*c.wl_pointer, _: u32) callconv(.c) void {}
    }.cb,
    .axis_stop = struct {
        fn cb(_: ?*anyopaque, _: ?*c.wl_pointer, _: u32, _: u32) callconv(.c) void {}
    }.cb,
    .axis_discrete = struct {
        fn cb(_: ?*anyopaque, _: ?*c.wl_pointer, _: u32, _: i32) callconv(.c) void {}
    }.cb,
};

const keyboard_listener = c.wl_keyboard_listener{
    .keymap = input_mod.keyboardKeymap,
    .enter = input_mod.keyboardEnter,
    .leave = input_mod.keyboardLeave,
    .key = input_mod.keyboardKey,
    .modifiers = input_mod.keyboardModifiers,
    .repeat_info = struct {
        fn cb(_: ?*anyopaque, _: ?*c.wl_keyboard, _: i32, _: i32) callconv(.c) void {}
    }.cb,
};

const frame_listener = c.wl_callback_listener{
    .done = wayland_mod.frameDone,
};

const output_listener = c.wl_output_listener{
    .geometry = wayland_mod.outputGeometry,
    .mode = wayland_mod.outputMode,
    .done = wayland_mod.outputDone,
    .scale = wayland_mod.outputScale,
    .name = wayland_mod.outputName,
};

// ---- Public API for settings/config ----

pub fn applyPanelSurfaceHeight() void {
    if (state.panel_surface.layer_surface) |ls| {
        c.zwlr_layer_surface_v1_set_size(ls, 0, @intCast(state.panel_height));
        c.zwlr_layer_surface_v1_set_exclusive_zone(ls, @intCast(state.panel_height));
        state.panel_surface.height = state.panel_height;
        c.wl_surface_commit(state.panel_surface.surface);
    }
}

pub fn setPanelHeight(h: i32) void {
    state.panel_height = h;
    applyPanelSurfaceHeight();
    state.panel_surface.dirty = true;
}

pub fn applyFontScale(scale: f64) void {
    state.font_scale = scale;
    state.panel_surface.dirty = true;
}

pub fn changeFontScale(delta: f64) void {
    const new_scale = state.font_scale + delta;
    if (new_scale >= 0.5 and new_scale <= 3.0) {
        applyFontScale(new_scale);
    }
}

pub fn setDockAutohide(on: bool) void {
    state.autohide_dock = on;
    if (!on) {
        if (state.dock_surface.layer_surface) |ls| {
            c.zwlr_layer_surface_v1_set_size(ls, 0, state.DOCK_HEIGHT);
            c.zwlr_layer_surface_v1_set_exclusive_zone(ls, state.DOCK_HEIGHT);
            state.dock_surface.height = state.DOCK_HEIGHT;
            c.wl_surface_commit(state.dock_surface.surface);
        }
    }
    state.dock_surface.dirty = true;
}

pub fn setPanelAutohide(on: bool) void {
    state.autohide_panel = on;
    if (!on) {
        if (state.panel_surface.layer_surface) |ls| {
            c.zwlr_layer_surface_v1_set_size(ls, 0, @intCast(state.panel_height));
            c.zwlr_layer_surface_v1_set_exclusive_zone(ls, @intCast(state.panel_height));
            state.panel_surface.height = state.panel_height;
            c.wl_surface_commit(state.panel_surface.surface);
        }
    }
    state.panel_surface.dirty = true;
}

pub fn settingsRect() SettingsRect {
    return .{
        .x = @intCast(@max(@as(i64, 0), @as(i64, state.panel_surface.width) - @as(i64, state.PANEL_SETTINGS_HEIGHT))),
        .y = state.panel_surface.height,
        .w = state.PANEL_SETTINGS_HEIGHT,
        .h = state.PANEL_SETTINGS_HEIGHT,
    };
}

pub const SettingsRect = struct { x: i32, y: i32, w: i32, h: i32 };

// ==== MAIN ====

pub fn main() !void {
    var render_out: ?[]const u8 = null;

    if (c.getenv("RENDER_TO_PNG")) |env_ptr| {
        render_out = std.mem.span(env_ptr);
    }

    if (render_out) |out_path| {
        state.dock_surface.width = 800;
        state.dock_surface.height = 100;
        state.dock_surface.scale = 1;
        dock_mod.initOrder();

        const cairo_surface = c.cairo_image_surface_create(c.CAIRO_FORMAT_ARGB32, 800, 100);
        const cr = c.cairo_create(cairo_surface);

        c.cairo_set_source_rgba(cr, 0, 0, 0, 0);
        c.cairo_set_operator(cr, c.CAIRO_OPERATOR_SOURCE);
        c.cairo_paint(cr);
        c.cairo_set_operator(cr, c.CAIRO_OPERATOR_OVER);

        dock_mod.draw(cr, 800, 100, state.toplevels[0..0], 0, -1, 0.0);

        c.cairo_surface_flush(cairo_surface);

        var zpath: [4096]u8 = undefined;
        @memcpy(zpath[0..out_path.len], out_path);
        zpath[out_path.len] = 0;

        _ = c.cairo_surface_write_to_png(cairo_surface, @ptrCast(&zpath));
        c.cairo_destroy(cr);
        c.cairo_surface_destroy(cairo_surface);
        std.log.info("Headless rendering complete. Output: {s}", .{out_path});
        return;
    }

    state.display = c.wl_display_connect(null) orelse {
        std.log.err("zigshell-cairo-pango: failed to connect to Wayland display", .{});
        return error.WaylandConnectFailed;
    };

    _ = c.signal(c.SIGHUP, onSighup);
    if (c.getenv("ZIGSHELL_CONFIG")) |p| {
        state.config_path = std.mem.sliceTo(p, 0);
    }

    state.registry = c.wl_display_get_registry(state.display);
    _ = c.wl_registry_add_listener(state.registry, &registry_listener, null);
    _ = c.wl_display_roundtrip(state.display);
    _ = c.wl_display_roundtrip(state.display);

    if (state.compositor == null or state.shm == null or state.layer_shell == null) {
        std.log.err("zigshell-cairo-pango: missing required Wayland globals", .{});
        return error.MissingGlobals;
    }

    if (state.toplevel_manager != null) {
        _ = c.wl_display_roundtrip(state.display);
        std.log.info("zigshell-cairo-pango: toplevel management enabled", .{});
    }

    if (state.seat != null) {
        _ = c.wl_display_roundtrip(state.display);
    }

    clay_cairo.init();

    const use_compact = if (c.getenv("OCWS_PANEL_COMPACT")) |v| blk: {
        const s = std.mem.span(v);
        break :blk std.mem.eql(u8, s, "1");
    } else false;
    const count = if (use_compact)
        panel_mod.widgetCreateCompact(&state.widgets)
    else
        panel_mod.widgetCreateDefault(&state.widgets);
    state.widget_count = count;

    if (state.config_path == null) state.config_path = config_manager.resolveConfigPath();

    if (state.config_path) |p| {
        _ = pcfg.Config.load(std.heap.page_allocator, p, .{ .widgets = &state.widgets, .count = &state.widget_count });
        config_manager.applyConfigToRuntime();
        std.log.info("zigshell-cairo-pango: loaded config from {s}", .{p});
    }

    // Create panel surface
    state.panel_surface.surface = c.wl_compositor_create_surface(state.compositor) orelse {
        std.log.err("zigshell-cairo-pango: wl_compositor_create_surface failed for panel", .{});
        return error.SurfaceCreateFailed;
    };
    _ = c.wl_surface_add_listener(state.panel_surface.surface, &surface_listener, null);
    state.panel_surface.layer_surface = c.zwlr_layer_shell_v1_get_layer_surface(
        state.layer_shell, state.panel_surface.surface, null,
        c.ZWLR_LAYER_SHELL_V1_LAYER_TOP, "zigshell-cairo-pango-panel",
    ) orelse {
        std.log.err("zigshell-cairo-pango: get_layer_surface failed for panel", .{});
        return error.LayerSurfaceCreateFailed;
    };
    _ = c.zwlr_layer_surface_v1_add_listener(state.panel_surface.layer_surface, &panel_layer_listener, null);

    const panel_anchor = c.ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP |
        c.ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
        c.ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT;
    c.zwlr_layer_surface_v1_set_anchor(state.panel_surface.layer_surface, panel_anchor);
    c.zwlr_layer_surface_v1_set_size(state.panel_surface.layer_surface, 0, @intCast(state.panel_height));
    c.zwlr_layer_surface_v1_set_exclusive_zone(state.panel_surface.layer_surface, @intCast(state.panel_height));
    c.zwlr_layer_surface_v1_set_keyboard_interactivity(state.panel_surface.layer_surface, 0);
    c.wl_surface_commit(state.panel_surface.surface);

    // Create dock surface
    state.dock_surface.surface = c.wl_compositor_create_surface(state.compositor) orelse {
        std.log.err("zigshell-cairo-pango: wl_compositor_create_surface failed for dock", .{});
        return error.SurfaceCreateFailed;
    };
    _ = c.wl_surface_add_listener(state.dock_surface.surface, &surface_listener, null);
    state.dock_surface.layer_surface = c.zwlr_layer_shell_v1_get_layer_surface(
        state.layer_shell, state.dock_surface.surface, null,
        c.ZWLR_LAYER_SHELL_V1_LAYER_BOTTOM, "zigshell-cairo-pango-dock",
    ) orelse {
        std.log.err("zigshell-cairo-pango: get_layer_surface failed for dock", .{});
        return error.LayerSurfaceCreateFailed;
    };
    _ = c.zwlr_layer_surface_v1_add_listener(state.dock_surface.layer_surface, &dock_layer_listener, null);

    const dock_anchor = c.ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM |
        c.ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
        c.ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT;
    c.zwlr_layer_surface_v1_set_anchor(state.dock_surface.layer_surface, dock_anchor);
    c.zwlr_layer_surface_v1_set_size(state.dock_surface.layer_surface, 0, state.DOCK_HEIGHT);
    c.zwlr_layer_surface_v1_set_exclusive_zone(state.dock_surface.layer_surface, state.DOCK_HEIGHT);
    c.zwlr_layer_surface_v1_set_keyboard_interactivity(state.dock_surface.layer_surface, 0);
    c.wl_surface_commit(state.dock_surface.surface);

    // Wait for initial configure
    var ret: i32 = 0;
    while (state.panel_surface.width == 0 and ret >= 0 and c.wl_display_get_error(state.display) == 0) {
        ret = c.wl_display_dispatch(state.display);
    }

    if (c.wl_display_get_error(state.display) != 0) {
        std.log.err("zigshell-cairo-pango: Wayland protocol error during init", .{});
        return error.WaylandProtocolError;
    }

    if (state.panel_surface.width == 0) {
        std.log.warn("zigshell-cairo-pango: no configure event received, using fallback width", .{});
        state.panel_surface.width = if (wayland_mod.output_count > 0) wayland_mod.outputs[0].w else 1920;
    }
    if (state.panel_surface.height == 0) state.panel_surface.height = state.panel_height;
    if (state.dock_surface.width == 0) state.dock_surface.width = state.panel_surface.width;
    if (state.dock_surface.height == 0) state.dock_surface.height = state.DOCK_HEIGHT;

    std.log.info("zigshell-cairo-pango: panel ({d}x{d}) dock ({d}x{d})", .{
        state.panel_surface.width, state.panel_surface.height,
        state.dock_surface.width, state.dock_surface.height,
    });

    // Timer for clock updates
    state.timer_fd = c.timerfd_create(c.CLOCK_MONOTONIC, c.TFD_NONBLOCK);
    if (state.timer_fd >= 0) {
        var ts = std.mem.zeroes(c.struct_itimerspec);
        ts.it_interval.tv_sec = 1;
        ts.it_value.tv_sec = 1;
        _ = c.timerfd_settime(state.timer_fd, 0, &ts, null);
    }

    state.markDirty();

    const wl_fd = c.wl_display_get_fd(state.display);
    var pfds: [2]c.struct_pollfd = undefined;

    // Main event loop
    while (state.running) {
        if (state.reload_config) {
            state.reload_config = false;
            reloadWidgets();
        }

        // Animation step
        const anim_active = (state.dock_hover_idx >= 0 and state.dock_hover_idx < state.toplevel_count);
        var any_animating = false;
        if (anim_active) {
            for (0..@intCast(@max(0, state.toplevel_count))) |i| {
                const target: f64 = if (state.dock_hover_idx == @as(i32, @intCast(i))) 1.0 else 0.0;
                const diff = target - state.toplevels[i].hover_anim;
                if (@abs(diff) > 0.01) {
                    state.toplevels[i].hover_anim += diff * 0.2;
                    any_animating = true;
                    state.markDirty();
                } else {
                    state.toplevels[i].hover_anim = target;
                }
            }
        }

        // Repaint each surface when dirty
        if (state.panel_surface.dirty) render_mod.renderPanel(&state.panel_surface);
        if (state.dock_surface.dirty) render_mod.renderDock(&state.dock_surface);
        if (state.modal_surface.dirty) render_mod.renderModal(&state.modal_surface);
        if (state.launcher_surface.dirty) render_mod.renderLauncher(&state.launcher_surface);
        surface_mod.submitSurface(&state.panel_surface);
        surface_mod.submitSurface(&state.dock_surface);
        surface_mod.submitSurface(&state.modal_surface);
        surface_mod.submitSurface(&state.launcher_surface);

        if (c.wl_display_flush(state.display) < 0) { state.running = false; continue; }

        pfds[0].fd = wl_fd;
        pfds[0].events = c.POLLIN;
        pfds[1].fd = state.timer_fd;
        pfds[1].events = c.POLLIN;

        const poll_ret = c.poll(&pfds, 2, if (any_animating) 16 else 3000);
        if (poll_ret > 0) {
            if ((pfds[0].revents & (c.POLLERR | c.POLLHUP)) != 0) {
                state.running = false;
            } else if ((pfds[0].revents & c.POLLIN) != 0) {
                if (c.wl_display_dispatch(state.display) < 0) state.running = false;
            }
            if ((pfds[1].revents & c.POLLIN) != 0) {
                var exp: u64 = 0;
                _ = c.read(state.timer_fd, &exp, @sizeOf(u64));
                panel_mod.widgetListUpdate(state.widgets[0..@intCast(@max(0, state.widget_count))]);
                state.markDirty();
            }
        } else {
            _ = c.wl_display_dispatch_pending(state.display);
        }
    }

    // Cleanup
    if (state.keyboard_keymap_mapped) |m| {
        _ = c.munmap(@ptrCast(m), state.keyboard_keymap_size);
        state.keyboard_keymap_mapped = null;
    }
    if (state.keyboard_keymap_fd >= 0) {
        _ = c.close(state.keyboard_keymap_fd);
        state.keyboard_keymap_fd = -1;
    }

    surface_mod.destroySurface(&state.panel_surface);
    if (state.panel_surface.layer_surface) |ls| c.zwlr_layer_surface_v1_destroy(ls);
    if (state.panel_surface.surface) |s| c.wl_surface_destroy(s);

    surface_mod.destroySurface(&state.dock_surface);
    if (state.dock_surface.layer_surface) |ls| c.zwlr_layer_surface_v1_destroy(ls);
    if (state.dock_surface.surface) |s| c.wl_surface_destroy(s);

    surface_mod.destroySurface(&state.launcher_surface);
    if (state.launcher_surface.layer_surface) |ls| c.zwlr_layer_surface_v1_destroy(ls);
    if (state.launcher_surface.surface) |s| c.wl_surface_destroy(s);

    surface_mod.destroySurface(&state.modal_surface);
    if (state.modal_surface.layer_surface) |ls| c.zwlr_layer_surface_v1_destroy(ls);
    if (state.modal_surface.surface) |s| c.wl_surface_destroy(s);

    icon.clearCache();
    if (state.display) |d| _ = c.wl_display_disconnect(d);

    std.log.info("zigshell-cairo-pango: exiting", .{});
}

comptime {
    _ = @import("dock.zig");
    _ = @import("icon.zig");
    _ = @import("panel.zig");
    _ = @import("theme.zig");
    _ = @import("modal.zig");
    _ = @import("app_launcher.zig");
    _ = @import("ocws_apps.zig");
}
