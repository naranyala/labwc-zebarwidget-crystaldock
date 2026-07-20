// input.zig — Pointer and keyboard input handling
// Extracted from main_shell.zig for clean module decomposition.

const std = @import("std");
const c = @import("c.zig").c;
const state = @import("shell_state.zig");
const dock_mod = @import("dock.zig");
const panel_mod = @import("panel.zig");
const app_launcher = @import("app_launcher.zig");
const dock_launcher = @import("dock_launcher.zig");
const surface_mod = @import("surface.zig");

// ---- Pointer handlers ----

pub fn pointerEnter(_: ?*anyopaque, _: ?*c.wl_pointer, _: u32, surface: ?*c.wl_surface, x: c.wl_fixed_t, y: c.wl_fixed_t) callconv(.c) void {
    state.pointer_x = c.wl_fixed_to_int(x);
    state.pointer_y = c.wl_fixed_to_int(y);
    state.pointer_on_panel = (surface == state.panel_surface.surface);
    state.pointer_on_dock = (surface == state.dock_surface.surface);
    state.pointer_on_launcher = (surface == state.launcher_surface.surface);
    state.pointer_on_modal = (surface == state.modal_surface.surface);
    if (state.autohide_dock and state.pointer_on_dock) {
        if (state.dock_surface.layer_surface) |ls| {
            c.zwlr_layer_surface_v1_set_size(ls, 0, state.DOCK_HEIGHT);
            c.zwlr_layer_surface_v1_set_exclusive_zone(ls, state.DOCK_HEIGHT);
            state.dock_surface.height = state.DOCK_HEIGHT;
            c.wl_surface_commit(state.dock_surface.surface);
        }
    }
    if (state.autohide_panel and state.pointer_on_panel) {
        if (state.panel_surface.layer_surface) |ls| {
            c.zwlr_layer_surface_v1_set_size(ls, 0, @intCast(state.panel_height));
            c.zwlr_layer_surface_v1_set_exclusive_zone(ls, @intCast(state.panel_height));
            state.panel_surface.height = state.panel_height;
            c.wl_surface_commit(state.panel_surface.surface);
        }
    }
    if (state.pointer_on_dock) {
        state.dock_hover_idx = dock_mod.iconAt(state.dock_surface.width, state.dock_surface.height, state.toplevels[0..@intCast(@max(0, state.toplevel_count))], state.pointer_x);
    }
    state.dock_surface.dirty = true;
}

pub fn pointerLeave(_: ?*anyopaque, _: ?*c.wl_pointer, _: u32, _: ?*c.wl_surface) callconv(.c) void {
    state.pointer_on_panel = false;
    state.pointer_on_dock = false;
    state.pointer_on_launcher = false;
    state.pointer_on_modal = false;
    state.hovered_widget = -1;
    state.dock_hover_idx = -1;
    if (state.autohide_dock) {
        if (state.dock_surface.layer_surface) |ls| {
            c.zwlr_layer_surface_v1_set_size(ls, 0, 1);
            c.zwlr_layer_surface_v1_set_exclusive_zone(ls, 0);
            state.dock_surface.height = 1;
            c.wl_surface_commit(state.dock_surface.surface);
        }
    }
    if (state.autohide_panel) {
        if (state.panel_surface.layer_surface) |ls| {
            c.zwlr_layer_surface_v1_set_size(ls, 0, 1);
            c.zwlr_layer_surface_v1_set_exclusive_zone(ls, 0);
            state.panel_surface.height = 1;
            c.wl_surface_commit(state.panel_surface.surface);
        }
    }
    state.dock_surface.dirty = true;
    state.panel_surface.dirty = true;
}

pub fn pointerMotion(_: ?*anyopaque, _: ?*c.wl_keyboard, _: u32, x: c.wl_fixed_t, y: c.wl_fixed_t) callconv(.c) void {
    state.pointer_x = c.wl_fixed_to_int(x);
    state.pointer_y = c.wl_fixed_to_int(y);

    if (state.pointer_on_dock) {
        const new_hover = dock_mod.iconAt(state.dock_surface.width, state.dock_surface.height, state.toplevels[0..@intCast(@max(0, state.toplevel_count))], state.pointer_x);
        if (new_hover != state.dock_hover_idx) {
            state.dock_hover_idx = new_hover;
            state.dock_surface.dirty = true;
        }
    }

    if (state.pointer_on_panel) {
        var new_hover: i32 = -1;
        for (0..@intCast(@max(0, state.widget_count))) |i| {
            if (state.widgets[i].hidden) continue;
            const wx = state.widget_x[i];
            const ww = state.widgets[i].cached_w;
            if (state.pointer_x >= wx and state.pointer_x <= wx + ww and state.pointer_y >= 0 and state.pointer_y <= state.panel_height) {
                new_hover = @intCast(i);
                break;
            }
        }
        if (new_hover != state.hovered_widget) {
            state.hovered_widget = new_hover;
            state.panel_surface.dirty = true;
        }
    }
}

pub fn pointerButton(_: ?*anyopaque, _: ?*c.wl_pointer, serial: u32, _: u32, button: u32, state_w: u32) callconv(.c) void {
    const pressed = (state_w == c.WL_POINTER_BUTTON_STATE_PRESSED);
    if (!pressed) return;

    // Panel click handling
    if (state.pointer_on_panel) {
        if (state.settings_open) {
            // Settings panel click handling would go here
            return;
        }
        // Widget click handling
        for (0..@intCast(@max(0, state.widget_count))) |i| {
            if (state.widgets[i].hidden) continue;
            const wx = state.widget_x[i];
            const ww = state.widgets[i].cached_w;
            if (state.pointer_x >= wx and state.pointer_x <= wx + ww and state.pointer_y >= 0 and state.pointer_y <= state.panel_height) {
                panel_mod.widgetClick(&state.widgets[i], button, serial, state.display);
                state.panel_surface.dirty = true;
                return;
            }
        }
    }

    // Dock click handling
    if (state.pointer_on_dock) {
        const idx = dock_mod.iconAt(state.dock_surface.width, state.dock_surface.height, state.toplevels[0..@intCast(@max(0, state.toplevel_count))], state.pointer_x);
        if (idx >= 0) {
            // Click on app icon — activate or launch
            dock_mod.dockActivate(idx, serial, state.display);
        } else if (idx == -2) {
            // Settings toggle
            // toggleSettings() would go here
        } else if (idx == -3) {
            // Launcher toggle
            app_launcher.toggle(state.display);
        }
        state.dock_surface.dirty = true;
    }
}

pub fn pointerAxis(_: ?*anyopaque, _: ?*c.wl_pointer, _: u32, axis: u32, value: c.wl_fixed_t) callconv(.c) void {
    const scroll = c.wl_fixed_to_int(value);
    if (axis == c.WL_POINTER_AXIS_VERTICAL_SCROLL and state.pointer_on_panel) {
        // Scroll on panel — could cycle workspaces or scroll widget list
        _ = scroll;
    }
    if (axis == c.WL_POINTER_AXIS_VERTICAL_SCROLL and state.pointer_on_dock) {
        // Scroll on dock — could cycle through running apps
        _ = scroll;
    }
}

// ---- Keyboard handlers ----

pub fn keyboardKeymap(_: ?*anyopaque, _: ?*c.wl_keyboard, _: u32, fd: c_int, size: u32) callconv(.c) void {
    if (state.keyboard_keymap_mapped) |m| {
        _ = c.munmap(m, state.keyboard_keymap_size);
    }
    state.keyboard_keymap_fd = fd;
    state.keyboard_keymap_size = size;
    if (size > 0) {
        state.keyboard_keymap_mapped = @ptrCast(c.mmap(null, size, c.PROT_READ, c.MAP_SHARED, fd, 0));
    }
}

pub fn keyboardEnter(_: ?*anyopaque, _: ?*c.wl_keyboard, _: u32, surface: ?*c.wl_surface, _: ?*c.wl_array) callconv(.c) void {
    state.keyboard_focus_surface = surface;
}

pub fn keyboardLeave(_: ?*anyopaque, _: ?*c.wl_keyboard, _: u32, _: ?*c.wl_surface) callconv(.c) void {
    state.keyboard_focus_surface = null;
}

pub fn keyboardKey(_: ?*anyopaque, _: ?*c.wl_keyboard, _: u32, _: u32, key: u32, state_w: u32) callconv(.c) void {
    const pressed = (state_w == c.WL_KEYBOARD_KEY_STATE_PRESSED);
    if (!pressed) return;

    // Map common keycodes (evdev)
    switch (key) {
        1 => { // Escape
            if (state.settings_open) {
                state.settings_open = false;
                state.panel_surface.dirty = true;
            }
        },
        else => {},
    }
}

pub fn keyboardModifiers(_: ?*anyopaque, _: ?*c.wl_keyboard, _: u32, _: u32, _: u32, _: u32, _: u32) callconv(.c) void {
    // Modifier handling (Ctrl, Alt, etc.) — no-op for now
}
