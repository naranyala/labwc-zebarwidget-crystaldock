// shell_state.zig — Shared shell state (globals accessible from all modules)
// Extracted from main_shell.zig to enable clean module decomposition.

const std = @import("std");
const c = @import("c.zig").c;
const theme = @import("theme.zig");
const toplevel = @import("shellcore").toplevel;
const panel_mod = @import("panel.zig");
const surface_mod = @import("surface.zig");

pub const MAX_TOPLEVELS = 64;
pub const MAX_WIDGETS = 64;
pub const DOCK_HEIGHT = 48;
pub const PANEL_SETTINGS_HEIGHT = 560;

// ---- wayland globals ----
pub var display: ?*c.wl_display = null;
pub var compositor: ?*c.wl_compositor = null;
pub var shm: ?*c.wl_shm = null;
pub var layer_shell: ?*c.zwlr_layer_shell_v1 = null;
pub var toplevel_manager: ?*c.zwlr_foreign_toplevel_manager_v1 = null;
pub var registry: ?*c.wl_registry = null;
pub var seat: ?*c.wl_seat = null;
pub var pointer: ?*c.wl_pointer = null;
pub var keyboard: ?*c.wl_keyboard = null;

// ---- keyboard state ----
pub var keyboard_keymap_fd: c_int = -1;
pub var keyboard_keymap_size: usize = 0;
pub var keyboard_keymap_mapped: ?[*]align(1) u8 = null;

// ---- surface state ----
pub var panel_surface = surface_mod.SurfaceState{ .height = 24 };
pub var dock_surface = surface_mod.SurfaceState{ .height = DOCK_HEIGHT };
pub var launcher_surface = surface_mod.SurfaceState{ .height = 0 };
pub var modal_surface = surface_mod.SurfaceState{ .height = 0 };

// ---- shell state ----
pub var running = true;
pub var timer_fd: i32 = -1;
pub var reload_config: bool = false;
pub var config_path: ?[]const u8 = null;
pub var panel_height: i32 = 24;
pub var font_scale: f64 = 1.0;
pub var autohide_dock: bool = false;
pub var autohide_panel: bool = false;

// ---- toplevel tracking ----
pub var toplevels: [MAX_TOPLEVELS]toplevel.ToplevelInfo = undefined;
pub var toplevel_count: i32 = 0;

// ---- panel widgets ----
pub var widgets: [MAX_WIDGETS]panel_mod.Widget = undefined;
pub var widget_count: i32 = 0;
pub var widget_x: [MAX_WIDGETS]i32 = undefined;

// ---- dock state ----
pub var dock_hover_idx: i32 = -1;
pub var drag_dock_group: i32 = -1;

// ---- pointer state ----
pub var pointer_x: i32 = 0;
pub var pointer_y: i32 = 0;
pub var pointer_on_panel = false;
pub var pointer_on_dock = false;
pub var pointer_on_launcher = false;
pub var pointer_on_modal = false;
pub var keyboard_focus_surface: ?*c.wl_surface = null;
pub var hovered_widget: i32 = -1;

// ---- settings state ----
pub var settings_open = false;
pub var settings_tab: u32 = 0;
pub var settings_scroll: i32 = 0;
pub var settings_drag_idx: i32 = -1;
pub var settings_add_menu: bool = false;
pub var config_dirty: bool = false;

// ---- dock context menu state ----
pub var dock_ctx_menu_open = false;
pub var dock_ctx_menu_idx: i32 = -1;

/// Mark all surfaces for repaint.
pub fn markDirty() void {
    panel_surface.dirty = true;
    dock_surface.dirty = true;
    launcher_surface.dirty = true;
    modal_surface.dirty = true;
}
