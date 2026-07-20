// main_shell.zig — Wayland panel + dock shell using Blend2D
// Adapted from zigshell-cairo-pango: Cairo/Pango/librsvg → Blend2D.

const std = @import("std");
const c = @import("c.zig").c;
const toplevel = @import("shellcore").toplevel;
const panel_mod = @import("panel.zig");
const dock_mod = @import("dock.zig");
const icon = @import("icon.zig");
const blend2d = @import("blend2d_render.zig");
const damage = @import("shellcore").damage;
const apps_mod = @import("apps");
const shlog = @import("log");

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = shlog.logFn,
};

const PANEL_HEIGHT = 28;
const DOCK_HEIGHT = 48;
const MAX_TOPLEVELS = 64;
const MAX_WIDGETS = 64;

// ---- wayland globals (shared) ----
var display: ?*c.wl_display = null;
var compositor: ?*c.wl_compositor = null;
var shm: ?*c.wl_shm = null;
var layer_shell: ?*c.zwlr_layer_shell_v1 = null;
var toplevel_manager: ?*c.zwlr_foreign_toplevel_manager_v1 = null;
var registry: ?*c.wl_registry = null;
var seat: ?*c.wl_seat = null;
var pointer: ?*c.wl_pointer = null;
var keyboard: ?*c.wl_keyboard = null;

// ---- keyboard state ----
// We don't link xkbcommon, so we only map the keymap (required by the
// wl_keyboard protocol) without parsing it.
var keyboard_keymap_fd: c_int = -1;
var keyboard_keymap_size: usize = 0;
var keyboard_keymap_mapped: ?[*]align(1) u8 = null;

// ---- surface state ----
const SurfaceState = struct {
    surface: ?*c.wl_surface = null,
    layer_surface: ?*c.zwlr_layer_surface_v1 = null,
    width: i32 = 0,
    height: i32 = 0,
    scale: u32 = 1,
    frame_cb: ?*c.wl_callback = null,
    renderer: ?blend2d.BlendRenderer = null,
    shm_data: ?[*]u8 = null,
    buffer: ?*c.wl_buffer = null,
    buf_width: i32 = 0,
    buf_height: i32 = 0,
    buf_size: usize = 0,
    dirty_region: damage.Region = damage.Region.init(),
};

var panel_surface = SurfaceState{ .height = PANEL_HEIGHT };
var dock_surface = SurfaceState{ .height = DOCK_HEIGHT };
var dirty = true;
var running = true;
var timer_fd: i32 = -1;
// Written from signal handler; accessed via volatile pointer in main loop.
var reload_config: bool = false;
var config_path: ?[]const u8 = null;
var autohide_dock: bool = false;

// ---- shared toplevel tracking ----
var toplevels: [MAX_TOPLEVELS]toplevel.ToplevelInfo = undefined;
var toplevel_count: i32 = 0;

// ---- panel widgets ----
var widgets: [MAX_WIDGETS]panel_mod.Widget = undefined;
var widget_count: i32 = 0;
var widget_x: [MAX_WIDGETS]i32 = undefined;
var pctx: panel_mod.PanelCtx = undefined;
var panel_theme: panel_mod.Theme = .{};

// ---- dock state ----
var dock_hover_idx: i32 = -1;

// ---- pointer state ----
var pointer_x: i32 = 0;
var pointer_y: i32 = 0;
var pointer_on_panel = false;
var pointer_on_dock = false;

// ---- settings state ----
var settings_open = false;

// ---- dock context menu state ----
var dock_ctx_menu_open = false;
var dock_ctx_menu_idx: i32 = -1;

// ---- app launcher state ----
var launcher_surface = SurfaceState{ .height = 0 };
var launcher_open = false;
var launcher_hover_idx: i32 = -1;
var launcher_scroll: i32 = 0;
var pointer_on_launcher = false;
var keyboard_focus_surface: ?*c.wl_surface = null;

// ==== WAYLAND CALLBACKS ====

fn toplevelHandleTitle(data: ?*anyopaque, handle: ?*c.zwlr_foreign_toplevel_handle_v1, title: [*c]const u8) callconv(.c) void {
    _ = handle;
    const info: *toplevel.ToplevelInfo = @ptrCast(@alignCast(data orelse return));
    const title_str = std.mem.sliceTo(title, 0);
    const len = @min(title_str.len, info.title.len - 1);
    @memcpy(info.title[0..len], title_str[0..len]);
    info.title[len] = 0;
    dirty = true;
}

fn toplevelHandleAppId(data: ?*anyopaque, handle: ?*c.zwlr_foreign_toplevel_handle_v1, app_id: [*c]const u8) callconv(.c) void {
    _ = handle;
    const info: *toplevel.ToplevelInfo = @ptrCast(@alignCast(data orelse return));
    const id_str = std.mem.sliceTo(app_id, 0);
    const len = @min(id_str.len, info.app_id.len - 1);
    @memcpy(info.app_id[0..len], id_str[0..len]);
    info.app_id[len] = 0;
    dirty = true;
}

fn toplevelHandleState(data: ?*anyopaque, handle: ?*c.zwlr_foreign_toplevel_handle_v1, state: ?*c.wl_array) callconv(.c) void {
    _ = handle;
    const info: *toplevel.ToplevelInfo = @ptrCast(@alignCast(data orelse return));
    info.focused = false;
    info.minimized = false;
    info.maximized = false;
    if (state) |s| {
        const states: [*]u32 = @ptrCast(@alignCast(s.*.data));
        const count = s.*.size / @sizeOf(u32);
        for (0..count) |i| {
            if (states[i] == c.ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_ACTIVATED) info.focused = true;
            if (states[i] == c.ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MINIMIZED) info.minimized = true;
            if (states[i] == c.ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MAXIMIZED) info.maximized = true;
        }
    }
    dirty = true;
}

fn toplevelHandleDone(data: ?*anyopaque, handle: ?*c.zwlr_foreign_toplevel_handle_v1) callconv(.c) void {
    _ = data;
    _ = handle;
    dirty = true;
}

fn toplevelHandleClosed(data: ?*anyopaque, handle: ?*c.zwlr_foreign_toplevel_handle_v1) callconv(.c) void {
    _ = data;
    const idx = toplevel.findIndex(&toplevels, toplevel_count, @ptrCast(handle orelse return));
    if (idx >= 0) {
        toplevel.removeAt(&toplevels, &toplevel_count, idx);
        dirty = true;
    }
}

fn toplevelHandleParent(data: ?*anyopaque, handle: ?*c.zwlr_foreign_toplevel_handle_v1, parent: ?*c.zwlr_foreign_toplevel_handle_v1) callconv(.c) void {
    _ = data;
    _ = handle;
    _ = parent;
}

const toplevel_handle_listener = c.zwlr_foreign_toplevel_handle_v1_listener{
    .title = toplevelHandleTitle,
    .app_id = toplevelHandleAppId,
    .output_enter = struct {
        fn f(_: ?*anyopaque, _: ?*c.zwlr_foreign_toplevel_handle_v1, _: ?*c.wl_output) callconv(.c) void {}
    }.f,
    .output_leave = struct {
        fn f(_: ?*anyopaque, _: ?*c.zwlr_foreign_toplevel_handle_v1, _: ?*c.wl_output) callconv(.c) void {}
    }.f,
    .state = toplevelHandleState,
    .done = toplevelHandleDone,
    .closed = toplevelHandleClosed,
    .parent = toplevelHandleParent,
};

fn toplevelManagerToplevel(data: ?*anyopaque, manager: ?*c.zwlr_foreign_toplevel_manager_v1, handle: ?*c.zwlr_foreign_toplevel_handle_v1) callconv(.c) void {
    _ = data;
    _ = manager;
    const idx = toplevel.add(&toplevels, &toplevel_count, @ptrCast(handle orelse return));
    if (idx != std.math.maxInt(usize)) {
        _ = c.zwlr_foreign_toplevel_handle_v1_add_listener(handle, &toplevel_handle_listener, &toplevels[idx]);
        dirty = true;
    }
}

const toplevel_manager_listener = c.zwlr_foreign_toplevel_manager_v1_listener{
    .toplevel = toplevelManagerToplevel,
    .finished = struct {
        fn f(_: ?*anyopaque, _: ?*c.zwlr_foreign_toplevel_manager_v1) callconv(.c) void {}
    }.f,
};

// ---- registry ----
fn registryGlobal(data: ?*anyopaque, reg: ?*c.wl_registry, name: u32, iface: [*c]const u8, version: u32) callconv(.c) void {
    _ = data;
    _ = version;
    const iface_str = std.mem.sliceTo(iface, 0);
    if (std.mem.eql(u8, iface_str, "wl_compositor"))
        compositor = @ptrCast(c.wl_registry_bind(reg, name, &c.wl_compositor_interface, 4))
    else if (std.mem.eql(u8, iface_str, "wl_shm"))
        shm = @ptrCast(c.wl_registry_bind(reg, name, &c.wl_shm_interface, 1))
    else if (std.mem.eql(u8, iface_str, "zwlr_layer_shell_v1"))
        layer_shell = @ptrCast(c.wl_registry_bind(reg, name, &c.zwlr_layer_shell_v1_interface, 4))
    else if (std.mem.eql(u8, iface_str, "zwlr_foreign_toplevel_manager_v1")) {
        toplevel_manager = @ptrCast(c.wl_registry_bind(reg, name, &c.zwlr_foreign_toplevel_manager_v1_interface, 3));
        _ = c.zwlr_foreign_toplevel_manager_v1_add_listener(toplevel_manager, &toplevel_manager_listener, null);
    } else if (std.mem.eql(u8, iface_str, "wl_seat")) {
        seat = @ptrCast(c.wl_registry_bind(reg, name, &c.wl_seat_interface, 7));
        _ = c.wl_seat_add_listener(seat, &seat_listener, null);
    } else if (std.mem.eql(u8, iface_str, "wl_output")) {
        const out: ?*c.wl_output = @ptrCast(c.wl_registry_bind(reg, name, &c.wl_output_interface, 2));
        _ = c.wl_output_add_listener(out, &output_listener, null);
    }
}

const registry_listener = c.wl_registry_listener{
    .global = registryGlobal,
    .global_remove = struct {
        fn f(_: ?*anyopaque, _: ?*c.wl_registry, _: u32) callconv(.c) void {}
    }.f,
};

// ---- keyboard ----
fn keyboardKeymap(data: ?*anyopaque, kb: ?*c.wl_keyboard, format: u32, fd: c_int, size: u32) callconv(.c) void {
    _ = data;
    _ = kb;
    _ = format;
    // Per the wl_keyboard protocol the client must map the shared keymap
    // memory. Closing the fd without mapping it can leave the keyboard
    // unusable on some compositors. We don't parse it (no xkbcommon dep),
    // but we map it and keep it mapped for the lifetime of the seat.
    if (keyboard_keymap_mapped) |m| {
        _ = c.munmap(@ptrCast(m), keyboard_keymap_size);
        keyboard_keymap_mapped = null;
    }
    if (keyboard_keymap_fd >= 0) _ = c.close(keyboard_keymap_fd);
    keyboard_keymap_fd = fd;
    keyboard_keymap_size = size;
    if (size > 0 and fd >= 0) {
        const mapped = c.mmap(null, size, c.PROT_READ, c.MAP_PRIVATE, fd, 0);
        if (mapped != c.MAP_FAILED) {
            keyboard_keymap_mapped = @ptrCast(@alignCast(mapped));
        } else {
            _ = c.close(fd);
            keyboard_keymap_fd = -1;
        }
    }
}

fn keyboardEnter(data: ?*anyopaque, kb: ?*c.wl_keyboard, serial: u32, surface: ?*c.wl_surface, keys: ?*c.wl_array) callconv(.c) void {
    _ = data;
    _ = kb;
    _ = serial;
    _ = keys;
    // Track which surface has keyboard focus
    keyboard_focus_surface = surface;
    dirty = true;
}

fn keyboardLeave(data: ?*anyopaque, kb: ?*c.wl_keyboard, serial: u32, surface: ?*c.wl_surface) callconv(.c) void {
    _ = data;
    _ = kb;
    _ = serial;
    _ = surface;
    keyboard_focus_surface = null;
    dirty = true;
}

fn keyboardKey(data: ?*anyopaque, kb: ?*c.wl_keyboard, serial: u32, time: u32, key: u32, state_w: u32) callconv(.c) void {
    _ = data;
    _ = kb;
    _ = serial;
    _ = time;
    // Only handle key-down events
    if (state_w != c.WL_KEYBOARD_KEY_STATE_PRESSED) return;
    // Only handle keys when the launcher has keyboard focus
    if (keyboard_focus_surface != launcher_surface.surface) return;
    if (!launcher_open) return;
    // xkbcommon keycodes: Escape=9, Return=36, Up=111, Down=116,
    // Left=113, Right=114, PageUp=112, PageDown=117, Home=110, End=115.
    if (key == 9) {
        // Escape — close launcher
        toggleLauncher();
        return;
    }
    if (key == 36) {
        // Enter — launch selected item
        if (launcher_hover_idx >= 0) {
            const list = apps_mod.list();
            if (launcher_hover_idx < @as(i32, @intCast(list.len))) {
                launchApp(&list[@intCast(launcher_hover_idx)]);
            }
            toggleLauncher();
        }
        return;
    }

    const list = apps_mod.list();
    if (list.len == 0) return;
    var sel = if (launcher_hover_idx < 0) 0 else launcher_hover_idx;

    switch (key) {
        111 => { // Up
            sel -= LAUNCHER_COLS;
        },
        116 => { // Down
            sel += LAUNCHER_COLS;
        },
        113 => { // Left
            sel -= 1;
        },
        114 => { // Right
            sel += 1;
        },
        112 => { // PageUp
            launcherScrollBy(-launcherVisibleRows());
            sel -= launcherVisibleRows() * LAUNCHER_COLS;
        },
        117 => { // PageDown
            launcherScrollBy(launcherVisibleRows());
            sel += launcherVisibleRows() * LAUNCHER_COLS;
        },
        110 => { // Home
            launcherScrollBy(-launcherMaxScroll());
            sel = 0;
            dirty = true;
            return;
        },
        115 => { // End
            launcherScrollBy(launcherMaxScroll());
            sel = @intCast(list.len - 1);
            dirty = true;
            return;
        },
        else => return,
    }

    // Clamp selection into the catalog.
    if (sel < 0) sel = 0;
    if (sel >= list.len) sel = @intCast(list.len - 1);

    // Keep the selection in view: scroll the launcher so `sel` is visible.
    const first_visible = launcher_scroll * LAUNCHER_COLS;
    const last_visible = (launcher_scroll + launcherVisibleRows()) * LAUNCHER_COLS - 1;
    if (sel < first_visible) {
        launcherScrollBy(@divTrunc(sel, LAUNCHER_COLS) - launcher_scroll);
    } else if (sel > last_visible) {
        const row = @divTrunc(sel, LAUNCHER_COLS);
        const target = row - launcherVisibleRows() + 1;
        launcherScrollBy(target - launcher_scroll);
    }

    if (sel != launcher_hover_idx) {
        launcher_hover_idx = sel;
        dirty = true;
    }
}

fn keyboardModifiers(data: ?*anyopaque, kb: ?*c.wl_keyboard, serial: u32, mods_depressed: u32, mods_latched: u32, mods_locked: u32, group: u32) callconv(.c) void {
    _ = data;
    _ = kb;
    _ = serial;
    _ = mods_depressed;
    _ = mods_latched;
    _ = mods_locked;
    _ = group;
}

fn keyboardRepeatInfo(data: ?*anyopaque, kb: ?*c.wl_keyboard, rate: i32, delay: i32) callconv(.c) void {
    _ = data;
    _ = kb;
    _ = rate;
    _ = delay;
}

const launcher_layer_listener = c.zwlr_layer_surface_v1_listener{
    .configure = layerSurfaceConfigure,
    .closed = layerSurfaceClosed,
};

const keyboard_listener = c.wl_keyboard_listener{
    .keymap = keyboardKeymap,
    .enter = keyboardEnter,
    .leave = keyboardLeave,
    .key = keyboardKey,
    .modifiers = keyboardModifiers,
    .repeat_info = keyboardRepeatInfo,
};

// ---- pointer ----
fn pointerEnter(data: ?*anyopaque, p: ?*c.wl_pointer, serial: u32, surface: ?*c.wl_surface, x: c.wl_fixed_t, y: c.wl_fixed_t) callconv(.c) void {
    _ = data;
    _ = p;
    _ = serial;
    pointer_x = c.wl_fixed_to_int(x);
    pointer_y = c.wl_fixed_to_int(y);
    pointer_on_panel = (surface == panel_surface.surface);
    pointer_on_dock = (surface == dock_surface.surface);
    pointer_on_launcher = (surface == launcher_surface.surface);
    if (autohide_dock and pointer_on_dock) {
        if (dock_surface.layer_surface) |ls| {
            c.zwlr_layer_surface_v1_set_size(ls, 0, DOCK_HEIGHT);
            c.zwlr_layer_surface_v1_set_exclusive_zone(ls, DOCK_HEIGHT);
            dock_surface.height = DOCK_HEIGHT;
            c.wl_surface_commit(dock_surface.surface);
        }
    }
    if (pointer_on_dock) {
        dock_hover_idx = dock_mod.iconAt(dock_surface.width, dock_surface.height, &toplevels, toplevel_count, pointer_x);
    }
    dirty = true;
}

fn pointerLeave(data: ?*anyopaque, p: ?*c.wl_pointer, serial: u32, surface: ?*c.wl_surface) callconv(.c) void {
    _ = data;
    _ = p;
    _ = serial;
    _ = surface;
    pointer_on_panel = false;
    pointer_on_dock = false;
    pointer_on_launcher = false;
    dock_hover_idx = -1;
    if (autohide_dock) {
        if (dock_surface.layer_surface) |ls| {
            c.zwlr_layer_surface_v1_set_size(ls, 0, 1);
            c.zwlr_layer_surface_v1_set_exclusive_zone(ls, 0);
            dock_surface.height = 1;
            c.wl_surface_commit(dock_surface.surface);
        }
    }
    dock_ctx_menu_open = false;
    dirty = true;
}

fn pointerMotion(data: ?*anyopaque, p: ?*c.wl_pointer, time: u32, x: c.wl_fixed_t, y: c.wl_fixed_t) callconv(.c) void {
    _ = data;
    _ = p;
    _ = time;
    pointer_x = c.wl_fixed_to_int(x);
    pointer_y = c.wl_fixed_to_int(y);
    if (pointer_on_dock) {
        const new_idx = dock_mod.iconAt(dock_surface.width, dock_surface.height, &toplevels, toplevel_count, pointer_x);
        if (new_idx != dock_hover_idx) {
            dock_hover_idx = new_idx;
            dirty = true;
        }
    }
    if (pointer_on_launcher and launcher_open) {
        const new_idx = launcherItemAt(pointer_x, pointer_y);
        if (new_idx != launcher_hover_idx) {
            launcher_hover_idx = new_idx;
            dirty = true;
        }
    }
}

fn pointerButton(data: ?*anyopaque, p: ?*c.wl_pointer, serial: u32, time: u32, button: u32, state_w: u32) callconv(.c) void {
    _ = data;
    _ = p;
    _ = serial;
    _ = time;
    if (state_w != c.WL_POINTER_BUTTON_STATE_PRESSED) return;

    // Launcher click — select an app entry
    if (pointer_on_launcher and launcher_open) {
        const idx = launcherItemAt(pointer_x, pointer_y);
        if (idx >= 0) {
            const list = apps_mod.list();
            if (idx < @as(i32, @intCast(list.len))) {
                launchApp(&list[@intCast(idx)]);
            }
            toggleLauncher(); // close after launch
        }
        return;
    }

    if (pointer_on_dock) {
        // Handle settings toggle (-2) and launcher toggle (-3)
        if (dock_hover_idx == -3) {
            toggleLauncher();
            return;
        }
        if (dock_hover_idx == -2) {
            settings_open = !settings_open;
            dirty = true;
            return;
        }

        // If context menu is open, handle its clicks
        if (dock_ctx_menu_open) {
            handleDockContextMenu(pointer_x, pointer_y, button);
            dirty = true;
            return;
        }

        if (dock_hover_idx >= 0 and dock_hover_idx < toplevel_count and seat != null) {
            const info = &toplevels[@intCast(dock_hover_idx)];
            const handle: ?*c.zwlr_foreign_toplevel_handle_v1 = @ptrCast(@alignCast(info.handle));

            if (button == 273 or button == 3) { // BTN_RIGHT or fallback
                // Show context menu
                dock_ctx_menu_open = true;
                dock_ctx_menu_idx = dock_hover_idx;
                dirty = true;
            } else if (info.focused) {
                c.zwlr_foreign_toplevel_handle_v1_set_minimized(handle);
                dirty = true;
            } else {
                c.zwlr_foreign_toplevel_handle_v1_activate(handle, seat);
                dirty = true;
            }
        }
        return;
    }

    if (pointer_on_panel) {
        // Settings gear button (right edge) — generous click area
        const settings_x = panel_surface.width - 36;
        const settings_w = 32;
        if (pointer_x >= settings_x and pointer_x < settings_x + settings_w and
            pointer_y >= 0 and pointer_y < panel_surface.height)
        {
            settings_open = !settings_open;
            dirty = true;
            return;
        }

        // Settings menu clicks
        if (settings_open) {
            handleSettingsClick(pointer_x, pointer_y);
            dirty = true;
            return;
        }

        // Widget clicks — each widget gets at least MIN_WIDGET_CLICK_W of clickable width
        const MIN_WIDGET_CLICK_W: i32 = 24;
        for (0..@intCast(@max(0, widget_count))) |i| {
            const click_w = @max(widgets[i].cached_w, MIN_WIDGET_CLICK_W);
            if (pointer_x >= widget_x[i] and pointer_x < widget_x[i] + click_w and
                pointer_y >= 0 and pointer_y < panel_surface.height)
            {
                if (panel_mod.widgetClick(&widgets[i], button, pointer_x - widget_x[i], pointer_y, &pctx)) {
                    // handled
                }
                dirty = true;
                return;
            }
        }
    }
}

fn handleSettingsClick(x: i32, y: i32) void {
    const menu_items = [_]struct { label: []const u8, action: []const u8 }{
        .{ .label = "Toggle Auto-Hide Dock", .action = "autohide" },
        .{ .label = "Icon Size: Small", .action = "icon_small" },
        .{ .label = "Icon Size: Medium", .action = "icon_medium" },
        .{ .label = "Icon Size: Large", .action = "icon_large" },
        .{ .label = "Restart Shell", .action = "restart" },
        .{ .label = "Quit Shell", .action = "quit" },
    };

    const menu_x: i32 = panel_surface.width - 200;
    const menu_y: i32 = 40;
    const item_h: i32 = 28;

    for (menu_items, 0..) |item, i| {
        // +4 offset matches drawSettingsMenu's item positioning
        const iy = menu_y + 4 + @as(i32, @intCast(i)) * item_h;
        if (x >= menu_x and x < menu_x + 190 and y >= iy and y < iy + item_h) {
            executeSettingsAction(item.action);
            return;
        }
    }
}

fn executeSettingsAction(action: []const u8) void {
    if (std.mem.eql(u8, action, "quit")) {
        running = false;
    } else if (std.mem.eql(u8, action, "restart")) {
        running = false;
    } else if (std.mem.eql(u8, action, "autohide")) {
        setDockAutohide(!autohide_dock);
    } else if (std.mem.eql(u8, action, "icon_small")) {
        dock_mod.DOCK_ICON_SIZE = 22;
        c.dock_icon_size = 22;
        icon.clearCache();
        dirty = true;
    } else if (std.mem.eql(u8, action, "icon_medium")) {
        dock_mod.DOCK_ICON_SIZE = 28;
        c.dock_icon_size = 28;
        icon.clearCache();
        dirty = true;
    } else if (std.mem.eql(u8, action, "icon_large")) {
        dock_mod.DOCK_ICON_SIZE = 36;
        c.dock_icon_size = 36;
        icon.clearCache();
        dirty = true;
    }
    settings_open = false;
}

fn setDockAutohide(on: bool) void {
    autohide_dock = on;
    if (dock_surface.layer_surface) |ls| {
        if (on and !pointer_on_dock) {
            c.zwlr_layer_surface_v1_set_size(ls, 0, 1);
            c.zwlr_layer_surface_v1_set_exclusive_zone(ls, 0);
            dock_surface.height = 1;
        } else {
            c.zwlr_layer_surface_v1_set_size(ls, 0, DOCK_HEIGHT);
            c.zwlr_layer_surface_v1_set_exclusive_zone(ls, DOCK_HEIGHT);
            dock_surface.height = DOCK_HEIGHT;
        }
        c.wl_surface_commit(dock_surface.surface);
    }
    dirty = true;
}

fn handleDockContextMenu(x: i32, y: i32, button: u32) void {
    if (button != 1) { // Any button click outside menu closes it
        dock_ctx_menu_open = false;
        return;
    }

    const menu_items = [_]struct { label: []const u8, action: []const u8 }{
        .{ .label = "Close Window", .action = "close" },
        .{ .label = "Minimize", .action = "minimize" },
        .{ .label = "Maximize", .action = "maximize" },
    };

    // Menu position near the clicked icon
    const slot = dock_mod.DOCK_ICON_SIZE + 8;
    const total_w: i32 = if (toplevel_count > 0) toplevel_count * slot - 8 else 0;
    var start_x = @divTrunc(dock_surface.width - total_w, 2);
    if (start_x < 0) start_x = 0;

    const menu_x = start_x + dock_ctx_menu_idx * slot;
    const menu_y: i32 = 0; // Top of dock surface
    const item_h: i32 = 24;
    const menu_w: i32 = 120;
    const menu_h: i32 = @as(i32, @intCast(menu_items.len)) * item_h + 8;

    // Check if click is within menu bounds
    if (x < menu_x or x >= menu_x + menu_w or y < menu_y or y >= menu_y + menu_h) {
        dock_ctx_menu_open = false;
        return;
    }

    for (menu_items, 0..) |item, i| {
        const iy = menu_y + 4 + @as(i32, @intCast(i)) * item_h;
        if (x >= menu_x and x < menu_x + menu_w and y >= iy and y < iy + item_h) {
            executeDockContextAction(item.action, dock_ctx_menu_idx);
            dock_ctx_menu_open = false;
            return;
        }
    }

    // Click outside menu closes it
    dock_ctx_menu_open = false;
}

fn executeDockContextAction(action: []const u8, idx: i32) void {
    if (idx < 0 or idx >= toplevel_count or seat == null) return;
    const info = &toplevels[@intCast(idx)];
    const handle: ?*c.zwlr_foreign_toplevel_handle_v1 = @ptrCast(@alignCast(info.handle));

    if (std.mem.eql(u8, action, "close")) {
        c.zwlr_foreign_toplevel_handle_v1_close(handle);
    } else if (std.mem.eql(u8, action, "minimize")) {
        c.zwlr_foreign_toplevel_handle_v1_set_minimized(handle);
    } else if (std.mem.eql(u8, action, "maximize")) {
        c.zwlr_foreign_toplevel_handle_v1_set_maximized(handle);
    }
}

const pointer_listener = c.wl_pointer_listener{
    .enter = pointerEnter,
    .leave = pointerLeave,
    .motion = pointerMotion,
    .button = pointerButton,
    .axis = struct {
        fn f(_: ?*anyopaque, _: ?*c.wl_pointer, _: u32, axis_type: u32, value: c.wl_fixed_t) callconv(.c) void {
            // Vertical wheel only. Wayland reports scroll-up as negative.
            if (axis_type != c.WL_POINTER_AXIS_VERTICAL_SCROLL) return;
            if (!pointer_on_launcher or !launcher_open) return;
            const v = c.wl_fixed_to_int(value);
            if (v == 0) return;
            // Convert the fixed-point delta into whole rows (1 row per ~40
            // units, minimum 1 row per notch so a trackpad/ wheel always moves).
            const rows = std.math.clamp(@divTrunc(v, 40), -100, 100);
            const sign: i32 = if (rows < 0) -1 else 1;
            const mag: i32 = @intCast(@max(1, @abs(rows)));
            launcherScrollBy(sign * mag);
        }
    }.f,
    .frame = struct {
        fn f(_: ?*anyopaque, _: ?*c.wl_pointer) callconv(.c) void {}
    }.f,
    .axis_source = struct {
        fn f(_: ?*anyopaque, _: ?*c.wl_pointer, _: u32) callconv(.c) void {}
    }.f,
    .axis_stop = struct {
        fn f(_: ?*anyopaque, _: ?*c.wl_pointer, _: u32, _: u32) callconv(.c) void {}
    }.f,
    .axis_discrete = struct {
        fn f(_: ?*anyopaque, _: ?*c.wl_pointer, _: u32, _: i32) callconv(.c) void {}
    }.f,
};

fn seatCapabilities(data: ?*anyopaque, s: ?*c.wl_seat, caps: u32) callconv(.c) void {
    _ = data;
    if ((caps & c.WL_SEAT_CAPABILITY_POINTER) != 0 and pointer == null) {
        pointer = c.wl_seat_get_pointer(s);
        _ = c.wl_pointer_add_listener(pointer, &pointer_listener, null);
    } else if ((caps & c.WL_SEAT_CAPABILITY_POINTER) == 0 and pointer != null) {
        c.wl_pointer_destroy(pointer);
        pointer = null;
    }
    if ((caps & c.WL_SEAT_CAPABILITY_KEYBOARD) != 0 and keyboard == null) {
        keyboard = c.wl_seat_get_keyboard(s);
        _ = c.wl_keyboard_add_listener(keyboard, &keyboard_listener, null);
    } else if ((caps & c.WL_SEAT_CAPABILITY_KEYBOARD) == 0 and keyboard != null) {
        c.wl_keyboard_destroy(keyboard);
        keyboard = null;
    }
}

const seat_listener = c.wl_seat_listener{
    .capabilities = seatCapabilities,
    .name = struct {
        fn f(_: ?*anyopaque, _: ?*c.wl_seat, _: [*c]const u8) callconv(.c) void {}
    }.f,
};

// ==== LAYER SURFACE CALLBACKS ====

fn layerSurfaceConfigure(data: ?*anyopaque, surface: ?*c.zwlr_layer_surface_v1, serial: u32, w: u32, h: u32) callconv(.c) void {
    _ = data;
    const ss = if (surface == panel_surface.layer_surface) &panel_surface
        else if (surface == launcher_surface.layer_surface) &launcher_surface
        else &dock_surface;
    // Clamp to sane bounds to prevent absurd SHM allocations from a
    // misbehaving compositor.
    // Clamp u32 first to prevent panic on values > maxInt(i32).
    const wi: i32 = @intCast(@min(w, 16384));
    const hi: i32 = @intCast(@min(h, 16384));
    if (wi != 0 and hi != 0 and (wi != ss.width or hi != ss.height)) {
        ss.width = wi;
        ss.height = hi;
        dirty = true;
    }
    c.zwlr_layer_surface_v1_ack_configure(surface, serial);
    // The launcher is a fixed-size floating panel; do not re-request its size
    // here (that would fight toggleLauncher). Panel/dock keep their height.
    if (surface != launcher_surface.layer_surface) {
        c.zwlr_layer_surface_v1_set_size(surface, 0, @intCast(ss.height));
    }
}

fn layerSurfaceClosed(data: ?*anyopaque, surface: ?*c.zwlr_layer_surface_v1) callconv(.c) void {
    _ = data;
    _ = surface;
    running = false;
}

const panel_layer_listener = c.zwlr_layer_surface_v1_listener{
    .configure = layerSurfaceConfigure,
    .closed = layerSurfaceClosed,
};

const dock_layer_listener = c.zwlr_layer_surface_v1_listener{
    .configure = layerSurfaceConfigure,
    .closed = layerSurfaceClosed,
};

fn frameDone(data: ?*anyopaque, cb: ?*c.wl_callback, time: u32) callconv(.c) void {
    _ = data;
    _ = time;
    if (cb == panel_surface.frame_cb) {
        c.wl_callback_destroy(cb);
        panel_surface.frame_cb = null;
    } else if (cb == dock_surface.frame_cb) {
        c.wl_callback_destroy(cb);
        dock_surface.frame_cb = null;
    } else if (cb == launcher_surface.frame_cb) {
        c.wl_callback_destroy(cb);
        launcher_surface.frame_cb = null;
    }
}

const frame_listener = c.wl_callback_listener{
    .done = frameDone,
};

// ---- surface (HiDPI / fractional scale) ----
fn surfacePreferredScale(data: ?*anyopaque, surface: ?*c.wl_surface, scale: i32) callconv(.c) void {
    _ = data;
    if (scale <= 0) return;
    const ss = if (surface == panel_surface.surface) &panel_surface
        else if (surface == launcher_surface.surface) &launcher_surface
        else &dock_surface;
    ss.scale = @intCast(scale);
    if (ss.surface) |s| c.wl_surface_set_buffer_scale(s, @intCast(ss.scale));
    dirty = true;
}

const surface_listener = c.wl_surface_listener{
    .enter = struct {
        fn f(_: ?*anyopaque, _: ?*c.wl_surface, _: ?*c.wl_output) callconv(.c) void {}
    }.f,
    .leave = struct {
        fn f(_: ?*anyopaque, _: ?*c.wl_surface, _: ?*c.wl_output) callconv(.c) void {}
    }.f,
    .preferred_buffer_scale = surfacePreferredScale,
    .preferred_buffer_transform = struct {
        fn f(_: ?*anyopaque, _: ?*c.wl_surface, _: u32) callconv(.c) void {}
    }.f,
};

// ---- multi-monitor (wl_output) tracking ----
const OutputInfo = struct {
    output: ?*c.wl_output = null,
    name: [64]u8 = std.mem.zeroes([64]u8),
    x: i32 = 0,
    y: i32 = 0,
    w: i32 = 0,
    h: i32 = 0,
    scale: i32 = 1,
    present: bool = false,
};

var outputs: [16]OutputInfo = std.mem.zeroes([16]OutputInfo);
var output_count: usize = 0;

fn findOrAddOutput(out: ?*c.wl_output) *OutputInfo {
    for (&outputs) |*o| {
        if (o.output == out) return o;
    }
    if (output_count < outputs.len) {
        const o = &outputs[output_count];
        output_count += 1;
        o.output = out;
        return o;
    }
    return &outputs[0];
}

fn outputGeometry(_: ?*anyopaque, out: ?*c.wl_output, x: i32, y: i32, _: i32, _: i32, _: i32, _: ?[*:0]const u8, _: ?[*:0]const u8, _: i32) callconv(.c) void {
    const o = findOrAddOutput(out);
    o.x = x;
    o.y = y;
}

fn outputMode(_: ?*anyopaque, out: ?*c.wl_output, _: u32, w: i32, h: i32, _: i32) callconv(.c) void {
    const o = findOrAddOutput(out);
    o.w = w;
    o.h = h;
}

fn outputScale(_: ?*anyopaque, out: ?*c.wl_output, factor: i32) callconv(.c) void {
    const o = findOrAddOutput(out);
    o.scale = factor;
}

fn outputName(_: ?*anyopaque, out: ?*c.wl_output, name: ?[*:0]const u8) callconv(.c) void {
    if (name == null) return;
    const o = findOrAddOutput(out);
    const n = std.mem.sliceTo(name.?, 0);
    const len = @min(n.len, o.name.len - 1);
    @memcpy(o.name[0..len], n[0..len]);
    o.name[len] = 0;
}

fn outputDone(_: ?*anyopaque, out: ?*c.wl_output) callconv(.c) void {
    const o = findOrAddOutput(out);
    o.present = true;
    std.log.info("zigshell-blend2d: output {s}: {d}x{d} @ scale {d} pos ({d},{d})", .{ o.name, o.w, o.h, o.scale, o.x, o.y });
}

const output_listener = c.wl_output_listener{
    .geometry = outputGeometry,
    .mode = outputMode,
    .done = outputDone,
    .scale = outputScale,
    .name = outputName,
    .description = struct { fn f(_: ?*anyopaque, _: ?*c.wl_output, _: ?[*:0]const u8) callconv(.c) void {} }.f,
};

// ==== LIVE CONFIG RELOAD (SIGHUP) ====

fn wireWidgetPriv() void {
    for (0..@intCast(@max(0, widget_count))) |i| {
        if (widgets[i].kind == .toplevel_task) {
            widgets[i].priv = @ptrCast(&pctx);
        }
    }
}

fn onSighup(_: c_int) callconv(.c) void {
    reload_config = true;
}

fn reloadWidgets() void {
    const path = config_path orelse return;
    const res = panel_mod.configLoadWidgets(std.heap.page_allocator, path) orelse return;
    if (res.count <= 0) return;
    for (0..@intCast(res.count)) |i| {
        const new_w = res.widgets[i];
        // Preserve accumulated state from the old widget if the type matches
        for (0..@intCast(@max(0, widget_count))) |j| {
            if (widgets[j].kind == new_w.kind) {
                var merged = new_w;
                merged.state = widgets[j].state;
                widgets[i] = merged;
                break;
            }
        } else {
            widgets[i] = new_w;
        }
    }
    widget_count = res.count;
    wireWidgetPriv();
    dirty = true;
    std.log.info("zigshell-blend2d: reloaded {d} widgets from {s}", .{ widget_count, path });
}

// ==== RENDERING ====

const shm_log = std.log.scoped(.shm);

fn errno() c_int {
    return std.c._errno().*;
}

fn createShmFd(size: usize) ?i32 {
    var name_buf: [19]u8 = "/tmp/wl_shm-XXXXXX".* ++ .{0};
    const name_z: [*:0]u8 = @ptrCast(&name_buf);
    const fd = c.mkstemp(name_z);
    if (fd < 0) {
        shm_log.err("mkstemp failed for SHM backing file (size={d}): errno {d}", .{ size, errno() });
        return null;
    }
    _ = c.unlink(name_z);
    if (c.ftruncate(fd, @intCast(size)) < 0) {
        shm_log.err("ftruncate failed for SHM fd (size={d}): errno {d}", .{ size, errno() });
        _ = c.close(fd);
        return null;
    }
    return fd;
}

fn ensureBuffer(ss: *SurfaceState) void {
    const w = ss.width * @as(i32, @intCast(ss.scale));
    const h = ss.height * @as(i32, @intCast(ss.scale));
    if (w <= 0 or h <= 0) return;

    const stride = w * 4; // 4 bytes per pixel (ARGB32)
    const size: usize = @intCast(@as(i64, stride) * @as(i64, h));

    if (ss.buffer != null and (ss.buf_width != w or ss.buf_height != h)) {
        // Destroy old renderer
        if (ss.renderer) |*r| r.deinit();
        ss.renderer = null;

        c.wl_buffer_destroy(ss.buffer);
        ss.buffer = null;
        _ = c.munmap(ss.shm_data, ss.buf_size);
        ss.shm_data = null;
    }

    if (ss.buffer == null) {
        const fd = createShmFd(size) orelse {
            shm_log.err("cannot allocate buffer ({d}x{d}, {d} bytes): SHM fd creation failed; surface will not render", .{ w, h, size });
            return;
        };
        const data_ptr = c.mmap(null, size, c.PROT_READ | c.PROT_WRITE, c.MAP_SHARED, fd, 0);
        if (data_ptr == c.MAP_FAILED) {
            shm_log.err("mmap failed for buffer ({d}x{d}, {d} bytes): errno {d}; surface will not render", .{ w, h, size, errno() });
            _ = c.close(fd);
            return;
        }
        ss.shm_data = @ptrCast(data_ptr);
        const pool = c.wl_shm_create_pool(shm, fd, @intCast(size));
        ss.buffer = c.wl_shm_pool_create_buffer(pool, 0, w, h, stride, c.WL_SHM_FORMAT_ARGB8888);
        c.wl_shm_pool_destroy(pool);
        _ = c.close(fd);
        if (ss.buffer == null) {
            shm_log.err("wl_shm_pool_create_buffer returned null ({d}x{d}); surface will not render", .{ w, h });
            _ = c.munmap(ss.shm_data, size);
            ss.shm_data = null;
            return;
        }

        // Init Blend2D renderer on the SHM buffer
        ss.renderer = blend2d.BlendRenderer.init(@ptrCast(ss.shm_data), w, h, stride) catch |err| blk: {
            std.log.err("BlendRenderer init error: {}", .{err});
            break :blk null;
        };
        if (ss.renderer) |*r| r.setScale(@as(f64, @floatFromInt(ss.scale)));

        // Apply buffer scale to surface for HiDPI
        if (ss.surface) |s| c.wl_surface_set_buffer_scale(s, @intCast(ss.scale));

        ss.buf_width = w;
        ss.buf_height = h;
        ss.buf_size = size;
    }
}

fn renderPanel() void {
    ensureBuffer(&panel_surface);
    var renderer = panel_surface.renderer orelse return;
    const w = panel_surface.width;
    const h = panel_surface.height;

// Background gradient (two-tone dark) from theme
    renderer.fillRect(0, 0, @as(f64, @floatFromInt(w)), @as(f64, @floatFromInt(h)) / 2.0, panel_theme.bg_top);
    renderer.fillRect(0, @as(f64, @floatFromInt(h)) / 2.0, @as(f64, @floatFromInt(w)), @as(f64, @floatFromInt(h)) / 2.0, panel_theme.bg_bottom);

    // Accent line at bottom
    renderer.fillRect(0, @as(f64, @floatFromInt(h - 2)), @as(f64, @floatFromInt(w)), 2, panel_theme.accent);

    // Measure and layout widgets
    const pad: i32 = 8;
    _ = panel_mod.widgetListWidth(widgets[0..@intCast(@max(0, widget_count))], h, pad, &panel_theme);

    var left_w: i32 = 0;
    var right_w: i32 = 0;
    for (0..@intCast(@max(0, widget_count))) |i| {
        if (widgets[i].side == 1) right_w += widgets[i].cached_w + pad
        else left_w += widgets[i].cached_w + pad;
    }
    if (left_w > 0) left_w -= pad;
    if (right_w > 0) right_w -= pad;

    // Center the whole widget block (left + right groups) in the panel,
    // leaving room for the settings button on the right edge.
    const settings_btn_w: i32 = 36;
    const total_w = left_w + right_w;
    const avail = w - settings_btn_w;
    var block_x: i32 = @divTrunc(avail - total_w, 2);
    if (block_x < 8) block_x = 8;

    var x: i32 = block_x;
    for (0..@intCast(@max(0, widget_count))) |i| {
        if (widgets[i].side == 1) continue;
        widget_x[i] = x;
        x += widgets[i].cached_w + pad;
    }

    var rx: i32 = block_x + total_w - right_w;
    for (0..@intCast(@max(0, widget_count))) |i| {
        if (widgets[i].side != 1) continue;
        widget_x[i] = rx;
        rx += widgets[i].cached_w + pad;
    }

    // Draw widgets
    pctx.hover_index = -1;
    if (pointer_on_panel) {
        for (0..@intCast(@max(0, widget_count))) |i| {
            const cw = @max(widgets[i].cached_w, 24);
            if (pointer_x >= widget_x[i] and pointer_x < widget_x[i] + cw) {
                pctx.hover_index = @intCast(i);
                break;
            }
        }
    }
    for (0..@intCast(@max(0, widget_count))) |i| {
        panel_mod.widgetDraw(&widgets[i], &renderer, widget_x[i], 0, h, &panel_theme, &pctx);
    }

    // Draw settings gear icon
    drawSettingsButton(&renderer, w, h);

    if (settings_open) {
        drawSettingsMenu(&renderer, w, h);
    }

    // Flush Blend2D operations to the pixel buffer
    renderer.flush();
    panel_surface.dirty_region.add(0, 0, panel_surface.buf_width, panel_surface.buf_height);
}

fn drawSettingsButton(renderer: *blend2d.BlendRenderer, w: i32, h: i32) void {
    const btn_x = w - 36;
    renderer.fillRect(@as(f64, @floatFromInt(btn_x)), 0, 32, @as(f64, @floatFromInt(h)), 0xCC4D4D59);
    renderer.drawText("\xe2\x9a\x99", @as(f64, @floatFromInt(btn_x + 10)), @as(f64, @floatFromInt(h)) / 2.0 - 6, 0xFFD9D9E0); // ⚙
}

fn drawSettingsMenu(renderer: *blend2d.BlendRenderer, w: i32, _: i32) void {
    const menu_items = [_][]const u8{
        "Toggle Auto-Hide Dock",
        "Icon Size: Small",
        "Icon Size: Medium",
        "Icon Size: Large",
        "Restart Shell",
        "Quit Shell",
    };

    const menu_x: i32 = w - 200;
    const menu_y: i32 = 40;
    const item_h: i32 = 28;
    const menu_w: i32 = 190;
    const menu_h: i32 = @as(i32, @intCast(menu_items.len)) * item_h + 8;

    // Menu background
    renderer.fillRect(@floatFromInt(menu_x), @floatFromInt(menu_y), @floatFromInt(menu_w), @floatFromInt(menu_h), 0xF21F1F26);

    // Menu border
    renderer.drawBorder(@floatFromInt(menu_x), @floatFromInt(menu_y), @floatFromInt(menu_w), @floatFromInt(menu_h), 0xFF4D4D59);

    // Menu items
    for (menu_items, 0..) |item, i| {
        const iy = menu_y + 4 + @as(i32, @intCast(i)) * item_h;

        // Hover highlight
        if (pointer_x >= menu_x and pointer_x < menu_x + menu_w and
            pointer_y >= iy and pointer_y < iy + item_h)
        {
            renderer.fillRect(@floatFromInt(menu_x + 2), @floatFromInt(iy), @floatFromInt(menu_w - 4), @floatFromInt(item_h), 0xFF40404D);
        }

        renderer.drawText(item, @floatFromInt(menu_x + 10), @floatFromInt(iy + @divTrunc(item_h, 2) - 6), 0xFFD9D9E0);
    }
}

fn renderDock() bool {
    if (dock_surface.height <= 0) {
        // Clear the dock surface if it was previously visible
        if (dock_surface.buffer != null) {
            submitSurface(&dock_surface);
        }
        return true; // already submitted
    }
    ensureBuffer(&dock_surface);
    var renderer = dock_surface.renderer orelse return false;

    dock_mod.draw(
        &renderer,
        dock_surface.width,
        dock_surface.height,
        &toplevels,
        toplevel_count,
        dock_hover_idx,
    );

    // Draw dock context menu if open
    if (dock_ctx_menu_open) {
        drawDockContextMenu(&renderer);
    }

    drawDockTooltip(&renderer, dock_surface.width, dock_surface.height);

    // Flush Blend2D operations to the pixel buffer
    renderer.flush();
    dock_surface.dirty_region.add(0, 0, dock_surface.buf_width, dock_surface.buf_height);
    return false;
}

// ---- App launcher (floating panel) ----

const LAUNCHER_W: i32 = 520;
const LAUNCHER_H: i32 = 420;
const LAUNCHER_COLS: i32 = 2;
const LAUNCHER_ROW_H: i32 = 56;
const LAUNCHER_X: i32 = 24;
const LAUNCHER_PAD: i32 = 12;

fn toggleLauncher() void {
    launcher_open = !launcher_open;
    if (launcher_open) {
        apps_mod.scan();
        launcher_scroll = 0;
        launcher_hover_idx = -1;
        launcher_surface.width = LAUNCHER_W;
        launcher_surface.height = LAUNCHER_H;

        // Lazily create the launcher layer surface the first time it opens.
        // Creating it eagerly at init leaves a mapped TOP layer-surface that
        // holds keyboard focus (making the keyboard unusable everywhere), so
        // we defer creation until the user actually opens the launcher and
        // fully destroy it on close.
        if (launcher_surface.surface == null) {
            launcher_surface.surface = c.wl_compositor_create_surface(compositor);
            _ = c.wl_surface_add_listener(launcher_surface.surface, &surface_listener, null);
        }
        if (launcher_surface.layer_surface == null) {
            launcher_surface.layer_surface = c.zwlr_layer_shell_v1_get_layer_surface(
                layer_shell,
                launcher_surface.surface,
                null,
                c.ZWLR_LAYER_SHELL_V1_LAYER_TOP,
                "zigshell-blend2d-launcher",
            );
            _ = c.zwlr_layer_surface_v1_add_listener(launcher_surface.layer_surface, &launcher_layer_listener, null);
            const launcher_anchor = c.ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM |
                c.ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
                c.ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT;
            c.zwlr_layer_surface_v1_set_anchor(launcher_surface.layer_surface, launcher_anchor);
            c.zwlr_layer_surface_v1_set_size(launcher_surface.layer_surface, LAUNCHER_W, LAUNCHER_H);
            c.zwlr_layer_surface_v1_set_exclusive_zone(launcher_surface.layer_surface, 0);
            c.zwlr_layer_surface_v1_set_keyboard_interactivity(launcher_surface.layer_surface, 1);
            c.wl_surface_commit(launcher_surface.surface);
        }
    } else {
        launcher_surface.width = 0;
        launcher_surface.height = 0;
        // Fully destroy the launcher surface to unmap it and release keyboard
        // focus. It is recreated on the next open. This also avoids illegal
        // 0x0 size requests on the layer surface.
        if (launcher_surface.frame_cb) |cb| {
            c.wl_callback_destroy(cb);
            launcher_surface.frame_cb = null;
        }
        if (launcher_surface.renderer) |*r| {
            r.deinit();
            launcher_surface.renderer = null;
        }
        if (launcher_surface.buffer) |b| {
            c.wl_buffer_destroy(b);
            launcher_surface.buffer = null;
        }
        if (launcher_surface.shm_data) |d| {
            _ = c.munmap(d, launcher_surface.buf_size);
            launcher_surface.shm_data = null;
        }
        launcher_surface.buf_width = 0;
        launcher_surface.buf_height = 0;
        launcher_surface.buf_size = 0;
        if (launcher_surface.layer_surface) |ls| {
            c.zwlr_layer_surface_v1_destroy(ls);
            launcher_surface.layer_surface = null;
        }
        if (launcher_surface.surface) |s| {
            c.wl_surface_destroy(s);
            launcher_surface.surface = null;
        }
    }
    dirty = true;
}

fn launcherVisibleRows() i32 {
    const area = LAUNCHER_H - LAUNCHER_PAD * 2;
    return area / LAUNCHER_ROW_H;
}

// Maximum number of row-pages the launcher can be scrolled by, so the last
// page keeps its bottom edge at the popup's bottom. Returns 0 when every
// entry already fits on screen.
fn launcherMaxScroll() i32 {
    const list = apps_mod.list();
    const total_rows = @divTrunc(@as(i32, @intCast(list.len)) + LAUNCHER_COLS - 1, LAUNCHER_COLS);
    const max = total_rows - launcherVisibleRows();
    return if (max < 0) 0 else max;
}

// Apply a scroll delta (in rows) and clamp into [0, launcherMaxScroll].
// Sets `dirty` when the offset actually changes so the grid re-renders.
fn launcherScrollBy(delta_rows: i32) void {
    if (!launcher_open or delta_rows == 0) return;
    const next = launcher_scroll + delta_rows;
    const clamped = std.math.clamp(next, 0, launcherMaxScroll());
    if (clamped != launcher_scroll) {
        launcher_scroll = clamped;
        dirty = true;
    }
}

fn launcherItemAt(mx: i32, my: i32) i32 {
    if (!launcher_open) return -1;
    const list = apps_mod.list();
    const rows = launcherVisibleRows();
    const start = @as(usize, @intCast(@max(launcher_scroll, 0))) * @as(usize, LAUNCHER_COLS);
    const end = @min(start + @as(usize, @intCast(rows)) * @as(usize, LAUNCHER_COLS), list.len);

    var col: i32 = 0;
    var row: i32 = 0;
    var idx: usize = start;
    while (idx < end) : (idx += 1) {
        const y = LAUNCHER_PAD + row * LAUNCHER_ROW_H;
        if (my >= y and my < y + LAUNCHER_ROW_H - 4) {
            const bx = LAUNCHER_X + col * @divTrunc(LAUNCHER_W, 2);
            if (mx >= bx and mx < bx + (@divTrunc(LAUNCHER_W, 2) - LAUNCHER_PAD)) {
                return @intCast(idx);
            }
        }
        col += 1;
        if (col >= LAUNCHER_COLS) {
            col = 0;
            row += 1;
        }
    }
    return -1;
}

fn launchApp(entry: *const apps_mod.AppEntry) void {
    const name = entry.name[0..entry.name_len];
    const exec = entry.exec[0..entry.exec_len];
    std.log.info("launcher: launching {s} -> {s}", .{ name, exec });
    var buf: [1024]u8 = undefined;
    const cmd = std.fmt.bufPrintZ(&buf, "{s} &", .{exec}) catch |err| {
        std.log.err("exec format error for {s}: {}", .{ name, err });
        return;
    };
    const rc = c.system(cmd.ptr);
    if (rc == -1) {
        std.log.err("launcher: failed to start shell for {s} ({s})", .{ name, exec });
    } else if (rc != 0) {
        std.log.warn("launcher: {s} exited with status {d}", .{ name, rc });
    }
}

fn renderLauncher() void {
    if (!launcher_open or launcher_surface.height <= 0) return;
    ensureBuffer(&launcher_surface);
    var renderer = launcher_surface.renderer orelse return;
    const w = launcher_surface.width;
    const h = launcher_surface.height;

    // Background
    renderer.fillRect(0, 0, @as(f64, @floatFromInt(w)), @as(f64, @floatFromInt(h)), 0xF21F1F26);
    renderer.drawBorder(0.5, 0.5, @as(f64, @floatFromInt(w - 1)), @as(f64, @floatFromInt(h - 1)), 0xFF4D4D59);

    // Title
    renderer.drawText("Applications", @as(f64, @floatFromInt(LAUNCHER_X)), 26.0, 0xFFD9D9E0);

    const list = apps_mod.list();
    const rows = launcherVisibleRows();
    const max_show = @as(usize, @intCast(rows)) * @as(usize, LAUNCHER_COLS);
    const start = @as(usize, @intCast(@max(launcher_scroll, 0))) * @as(usize, LAUNCHER_COLS);
    const end = @min(start + max_show, list.len);

    var col: i32 = 0;
    var row: i32 = 0;
    var idx: usize = start;
    while (idx < end) : (idx += 1) {
        const e = &list[idx];
        const name = e.name[0..e.name_len];
        const cx = LAUNCHER_X + col * @divTrunc(w, 2);
        const cy = LAUNCHER_PAD + row * LAUNCHER_ROW_H + 6;

        if (launcher_hover_idx == @as(i32, @intCast(idx))) {
            renderer.fillRect(@floatFromInt(cx - 4), @floatFromInt(cy - 4),
                @as(f64, @floatFromInt(@divTrunc(w, 2) - LAUNCHER_PAD)),
                @as(f64, @floatFromInt(LAUNCHER_ROW_H - 8)), 0xFF40404D);
        }

        // Draw icon
        const icon_name = e.icon[0..e.icon_len];
        var icon_img = icon.load(@ptrCast(@constCast(icon_name.ptr)), 32);
        if (icon_img) |*img| {
            renderer.drawImage(img, @as(f64, @floatFromInt(cx)), @as(f64, @floatFromInt(cy)));
        }

        // Draw name text
        renderer.drawText(name, @as(f64, @floatFromInt(cx + 40)), @as(f64, @floatFromInt(cy + 12)), 0xFFD9D9E0);
        if (!e.from_desktop) {
            renderer.drawText("executable", @as(f64, @floatFromInt(cx + 40)), @as(f64, @floatFromInt(cy + 28)), 0xFF999999);
        }

        col += 1;
        if (col >= LAUNCHER_COLS) {
            col = 0;
            row += 1;
        }
    }

    renderer.flush();
    launcher_surface.dirty_region.add(0, 0, launcher_surface.buf_width, launcher_surface.buf_height);
}

fn drawDockContextMenu(renderer: *blend2d.BlendRenderer) void {
    const menu_items = [_]struct { label: []const u8 }{
        .{ .label = "Close Window" },
        .{ .label = "Minimize" },
        .{ .label = "Maximize" },
    };

    const slot = dock_mod.DOCK_ICON_SIZE + 8;
    const total_w: i32 = if (toplevel_count > 0) toplevel_count * slot - 8 else 0;
    var start_x = @divTrunc(dock_surface.width - total_w, 2);
    if (start_x < 0) start_x = 0;

    const menu_x = start_x + dock_ctx_menu_idx * slot;
    const menu_y: i32 = 0;
    const item_h: i32 = 24;
    const menu_w: i32 = 120;
    const menu_h: i32 = @as(i32, @intCast(menu_items.len)) * item_h + 8;

    // Menu background
    renderer.fillRect(@as(f64, @floatFromInt(menu_x)), @as(f64, @floatFromInt(menu_y)), @as(f64, @floatFromInt(menu_w)), @as(f64, @floatFromInt(menu_h)), 0xF21F1F26);
    renderer.drawBorder(@as(f64, @floatFromInt(menu_x)), @as(f64, @floatFromInt(menu_y)), @as(f64, @floatFromInt(menu_w)), @as(f64, @floatFromInt(menu_h)), 0xFF4D4D59);

    for (menu_items, 0..) |item, i| {
        const iy = menu_y + 4 + @as(i32, @intCast(i)) * item_h;

        // Hover highlight
        if (pointer_x >= menu_x and pointer_x < menu_x + menu_w and
            pointer_y >= iy and pointer_y < iy + item_h)
        {
            renderer.fillRect(@as(f64, @floatFromInt(menu_x + 2)), @as(f64, @floatFromInt(iy)), @as(f64, @floatFromInt(menu_w - 4)), @as(f64, @floatFromInt(item_h)), 0xFF40404D);
        }

        renderer.drawText(item.label, @as(f64, @floatFromInt(menu_x + 10)), @as(f64, @floatFromInt(iy + @divTrunc(item_h, 2) - 6)), 0xFFD9D9E0);
    }
}

fn drawDockTooltip(renderer: *blend2d.BlendRenderer, surf_w: i32, surf_h: i32) void {
    if (!pointer_on_dock) return;
    if (dock_hover_idx < 0 or dock_hover_idx >= toplevel_count) return;
    const title = std.mem.sliceTo(&toplevels[@intCast(dock_hover_idx)].title, 0);
    if (title.len == 0) return;

    const pad: i32 = 8;
    const tw: i32 = @as(i32, @intCast(title.len)) * 7 + pad * 2;
    const th: i32 = 22;
    var bx: i32 = pointer_x -| @divTrunc(tw, 2);
    if (bx < 0) bx = 0;
    if (bx + tw > surf_w) bx = surf_w - tw;
    const by: i32 = surf_h - th - 4;

    renderer.fillRect(@floatFromInt(bx), @floatFromInt(by), @floatFromInt(tw), @floatFromInt(th), 0xF21A1C26);
    _ = panel_mod.widgetText(renderer, @ptrCast(title.ptr), bx + pad, by + th, 10.0, 0.9, 0.9, 0.9);
}

fn submitSurface(ss: *SurfaceState) void {
    if (ss.buffer == null or ss.surface == null) return;
    c.wl_surface_attach(ss.surface, ss.buffer, 0, 0);
    const r = ss.dirty_region;
    if (r.active) {
        c.wl_surface_damage_buffer(ss.surface, r.x, r.y, r.w, r.h);
    } else {
        c.wl_surface_damage_buffer(ss.surface, 0, 0, ss.buf_width, ss.buf_height);
    }
    ss.dirty_region.reset();
    if (ss.frame_cb) |cb| c.wl_callback_destroy(cb);
    ss.frame_cb = c.wl_surface_frame(ss.surface);
    _ = c.wl_callback_add_listener(ss.frame_cb, &frame_listener, null);
    c.wl_surface_commit(ss.surface);
}

// ==== MAIN ====

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var render_to_png_path: ?[]const u8 = null;
    if (c.getenv("RENDER_TO_PNG")) |env_ptr| {
        render_to_png_path = std.mem.span(env_ptr);
    }
    
    if (render_to_png_path) |path| {
        const width = 800;
        const height = 100;
        const stride = width * 4;
        const buf = try allocator.alloc(u8, @intCast(height * stride));
        defer allocator.free(buf);
        
        @memset(buf, 0);
        
        var renderer = try blend2d.BlendRenderer.init(buf.ptr, width, height, stride);
        defer renderer.deinit();

        dock_mod.draw(&renderer, width, height, &toplevels, toplevel_count, -1);
        
        const path_z = try allocator.dupeZ(u8, path);
        renderer.writeToPng(path_z);
        return;
    }

    display = c.wl_display_connect(null) orelse {
        std.log.err("zigshell-blend2d: failed to connect to Wayland display", .{});
        return error.WaylandConnectFailed;
    };

    _ = c.signal(c.SIGHUP, onSighup);
    if (c.getenv("ZIGSHELL_CONFIG")) |p| {
        config_path = std.mem.sliceTo(p, 0);
    }

    registry = c.wl_display_get_registry(display);
    _ = c.wl_registry_add_listener(registry, &registry_listener, null);
    _ = c.wl_display_roundtrip(display);
    _ = c.wl_display_roundtrip(display);

    if (compositor == null or shm == null or layer_shell == null) {
        std.log.err("zigshell-blend2d: missing required Wayland globals", .{});
        return error.MissingGlobals;
    }

    if (toplevel_manager != null) {
        _ = c.wl_display_roundtrip(display);
        std.log.info("zigshell-blend2d: toplevel management enabled", .{});
    }

    if (seat != null) {
        _ = c.wl_display_roundtrip(display);
    }

    // Load widgets: compact mode if OCWS_PANEL_COMPACT=1, else full default
    const use_compact = if (c.getenv("OCWS_PANEL_COMPACT")) |v| blk: {
        const s = std.mem.span(v);
        break :blk std.mem.eql(u8, s, "1");
    } else false;
    const defaults = if (use_compact) panel_mod.widgetCreateCompact() else panel_mod.widgetCreateDefault();
    for (0..@intCast(defaults.count)) |i| {
        widgets[i] = defaults.widgets[i];
    }
    widget_count = defaults.count;

    pctx = .{
        .toplevels = &toplevels,
        .count = &toplevel_count,
        .seat = seat,
    };
    wireWidgetPriv();

    // Create panel surface (TOP)
    panel_surface.surface = c.wl_compositor_create_surface(compositor) orelse {
        std.log.err("zigshell-blend2d: wl_compositor_create_surface failed for panel", .{});
        return error.SurfaceCreateFailed;
    };
    _ = c.wl_surface_add_listener(panel_surface.surface, &surface_listener, null);
    panel_surface.layer_surface = c.zwlr_layer_shell_v1_get_layer_surface(
        layer_shell,
        panel_surface.surface,
        null,
        c.ZWLR_LAYER_SHELL_V1_LAYER_TOP,
        "zigshell-blend2d-panel",
    ) orelse {
        std.log.err("zigshell-blend2d: get_layer_surface failed for panel", .{});
        return error.LayerSurfaceCreateFailed;
    };
    _ = c.zwlr_layer_surface_v1_add_listener(panel_surface.layer_surface, &panel_layer_listener, null);

    const panel_anchor = c.ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP |
        c.ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
        c.ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT;
    c.zwlr_layer_surface_v1_set_anchor(panel_surface.layer_surface, panel_anchor);
    c.zwlr_layer_surface_v1_set_size(panel_surface.layer_surface, 0, PANEL_HEIGHT);
    c.zwlr_layer_surface_v1_set_exclusive_zone(panel_surface.layer_surface, PANEL_HEIGHT);
    // The panel/dock is an indicator+launcher bar with no in-process text
    // entry, so it must NOT grab keyboard focus. Using on-demand (2) here
    // meant that clicking the panel stole keyboard focus from other apps and
    // discarded every key press — i.e. "keyboard can't type anything".
    // Keep interactivity NONE (0); the launcher spawns external tools (fuzzel)
    // that manage their own keyboard focus.
    c.zwlr_layer_surface_v1_set_keyboard_interactivity(panel_surface.layer_surface, 0);
    c.wl_surface_commit(panel_surface.surface);

    // Create dock surface (BOTTOM)
    dock_surface.surface = c.wl_compositor_create_surface(compositor) orelse {
        std.log.err("zigshell-blend2d: wl_compositor_create_surface failed for dock", .{});
        return error.SurfaceCreateFailed;
    };
    _ = c.wl_surface_add_listener(dock_surface.surface, &surface_listener, null);
    dock_surface.layer_surface = c.zwlr_layer_shell_v1_get_layer_surface(
        layer_shell,
        dock_surface.surface,
        null,
        c.ZWLR_LAYER_SHELL_V1_LAYER_BOTTOM,
        "zigshell-blend2d-dock",
    ) orelse {
        std.log.err("zigshell-blend2d: get_layer_surface failed for dock", .{});
        return error.LayerSurfaceCreateFailed;
    };
    _ = c.zwlr_layer_surface_v1_add_listener(dock_surface.layer_surface, &dock_layer_listener, null);

    const dock_anchor = c.ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM |
        c.ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
        c.ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT;
    c.zwlr_layer_surface_v1_set_anchor(dock_surface.layer_surface, dock_anchor);
    c.zwlr_layer_surface_v1_set_size(dock_surface.layer_surface, 0, DOCK_HEIGHT);
    c.zwlr_layer_surface_v1_set_exclusive_zone(dock_surface.layer_surface, DOCK_HEIGHT);
    c.zwlr_layer_surface_v1_set_keyboard_interactivity(dock_surface.layer_surface, 0);
    c.wl_surface_commit(dock_surface.surface);

    // The app-launcher layer surface is created lazily (on first open) by
    // toggleLauncher(). Creating/committing it at init leaves a mapped TOP
    // layer-surface that holds keyboard focus — which made the keyboard
    // unusable for every other app — so we defer it entirely until the user
    // opens the launcher.

    // Wait for initial configure
    var ret: i32 = 0;
    while (panel_surface.width == 0 and ret >= 0 and c.wl_display_get_error(display) == 0) {
        ret = c.wl_display_dispatch(display);
    }

    if (c.wl_display_get_error(display) != 0) {
        std.log.err("zigshell-blend2d: Wayland protocol error during init (code {d}, errno {d}); aborting", .{ c.wl_display_get_error(display), errno() });
        return error.WaylandProtocolError;
    }

    if (panel_surface.width == 0) {
        // Fallback: use first output's width if available, else 1920
        panel_surface.width = if (output_count > 0) outputs[0].w else 1920;
    }
    if (panel_surface.height == 0) panel_surface.height = PANEL_HEIGHT;
    if (dock_surface.width == 0) dock_surface.width = panel_surface.width;
    if (dock_surface.height == 0) dock_surface.height = DOCK_HEIGHT;

    std.log.info("zigshell-blend2d: panel ({d}x{d}) dock ({d}x{d})", .{
        panel_surface.width, panel_surface.height,
        dock_surface.width, dock_surface.height,
    });

    // Timer for clock updates
    timer_fd = c.timerfd_create(c.CLOCK_MONOTONIC, c.TFD_NONBLOCK);
    if (timer_fd >= 0) {
        var ts = std.mem.zeroes(c.struct_itimerspec);
        ts.it_interval.tv_sec = 1;
        ts.it_value.tv_sec = 1;
        _ = c.timerfd_settime(timer_fd, 0, &ts, null);
    }

    dirty = true;

    const wl_fd = c.wl_display_get_fd(display);
    var pfds: [2]c.struct_pollfd = undefined;

    // Main event loop
    while (running) {
        if (reload_config) {
            reload_config = false;
            reloadWidgets();
        }
        if (dirty) {
            renderPanel();
            submitSurface(&panel_surface);

            const dock_already_submitted = renderDock();
            if (!dock_already_submitted) submitSurface(&dock_surface);

            renderLauncher();
            if (launcher_surface.buffer != null) submitSurface(&launcher_surface);

            dirty = false;
        }

        if (c.wl_display_flush(display) < 0) { running = false; continue; }

        pfds[0].fd = wl_fd;
        pfds[0].events = c.POLLIN;
        pfds[1].fd = timer_fd;
        pfds[1].events = c.POLLIN;

        const poll_ret = c.poll(&pfds, 2, 3000);
        if (poll_ret > 0) {
            if ((pfds[0].revents & (c.POLLERR | c.POLLHUP)) != 0) {
                running = false;
            } else if ((pfds[0].revents & c.POLLIN) != 0) {
                if (c.wl_display_dispatch(display) < 0) { running = false; }
            }
            if ((pfds[1].revents & c.POLLIN) != 0) {
                var exp: u64 = 0;
                _ = c.read(timer_fd, &exp, @sizeOf(u64));
                panel_mod.widgetListUpdate(widgets[0..@intCast(@max(0, widget_count))], &pctx);
                dirty = true;
            }
        } else {
            _ = c.wl_display_dispatch_pending(display);
        }
    }

    // Cleanup
    if (panel_surface.renderer) |*r| r.deinit();
    if (panel_surface.buffer) |b| c.wl_buffer_destroy(b);
    if (panel_surface.shm_data) |d| _ = c.munmap(d, panel_surface.buf_size);
    if (panel_surface.frame_cb) |cb| c.wl_callback_destroy(cb);
    if (panel_surface.layer_surface) |ls| c.zwlr_layer_surface_v1_destroy(ls);
    if (panel_surface.surface) |s| c.wl_surface_destroy(s);

    if (dock_surface.renderer) |*r| r.deinit();
    if (dock_surface.buffer) |b| c.wl_buffer_destroy(b);
    if (dock_surface.shm_data) |d| _ = c.munmap(d, dock_surface.buf_size);
    if (dock_surface.frame_cb) |cb| c.wl_callback_destroy(cb);
    if (dock_surface.layer_surface) |ls| c.zwlr_layer_surface_v1_destroy(ls);
    if (dock_surface.surface) |s| c.wl_surface_destroy(s);

    if (launcher_surface.renderer) |*r| r.deinit();
    if (launcher_surface.buffer) |b| c.wl_buffer_destroy(b);
    if (launcher_surface.shm_data) |d| _ = c.munmap(d, launcher_surface.buf_size);
    if (launcher_surface.frame_cb) |cb| c.wl_callback_destroy(cb);
    if (launcher_surface.layer_surface) |ls| c.zwlr_layer_surface_v1_destroy(ls);
    if (launcher_surface.surface) |s| c.wl_surface_destroy(s);

    if (keyboard_keymap_mapped) |m| {
        _ = c.munmap(@ptrCast(m), keyboard_keymap_size);
        keyboard_keymap_mapped = null;
    }
    if (keyboard_keymap_fd >= 0) _ = c.close(keyboard_keymap_fd);

    icon.clearCache();
    if (display) |d| _ = c.wl_display_disconnect(d);

    std.log.info("zigshell-blend2d: exiting", .{});
}
