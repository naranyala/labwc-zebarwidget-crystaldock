const std = @import("std");
const c = @import("c.zig").c;
const pcfg = @import("panel_config.zig");
const dock_mod = @import("dock.zig");
const icon = @import("icon.zig");
const main = @import("main_shell.zig");
const state = @import("shell_state.zig");

// Resolve the config file path: $ZIGSHELL_CONFIG if set, otherwise
// $XDG_CONFIG_HOME/zigshell/panel.conf (falling back to ~/.config). The GTK
// settings app (settings_gtk) uses the same resolution so both processes read
// and write the same file, and SIGHUP reload stays consistent.
pub fn resolveConfigPath() []const u8 {
    if (c.getenv("ZIGSHELL_CONFIG")) |p| return std.mem.sliceTo(p, 0);
    const home = if (c.getenv("HOME")) |h| std.mem.sliceTo(h, 0) else ".";
    const xdg = if (c.getenv("XDG_CONFIG_HOME")) |x| std.mem.sliceTo(x, 0) else blk: {
        const s = std.fmt.allocPrint(std.heap.page_allocator, "{s}/.config", .{home}) catch ".";
        break :blk s;
    };
    return std.fmt.allocPrint(std.heap.page_allocator, "{s}/zigshell/panel.conf", .{xdg}) catch home;
}

// Persist the current panel + dock configuration to disk (if a path is set).
pub fn saveConfig() void {
    const path = state.config_path orelse return;
    if (pcfg.Config.save(std.heap.page_allocator, path)) {
        state.config_dirty = false;
        std.log.info("zigshell-cairo-pango: config saved to {s}", .{path});
    }
}

// Push live state into pcfg.global before a save.
pub fn syncConfigFromRuntime() void {
    pcfg.global.panel_height = state.panel_height;
    pcfg.global.font_scale = @floatCast(state.font_scale);
    pcfg.global.autohide_dock = state.autohide_dock;
    pcfg.global.autohide_panel = state.autohide_panel;
    pcfg.global.dock_icon_size = dock_mod.DOCK_ICON_SIZE;
    pcfg.global.widget_count = state.widget_count;
    for (0..@intCast(@max(0, state.widget_count))) |i| pcfg.global.widgets[i] = state.widgets[i];
    var buf: [256]u8 = undefined;
    const n = dock_mod.writePinned(&buf);
    @memcpy(pcfg.global.pins[0..n], buf[0..n]);
    pcfg.global.pins_len = n;
}

// Apply pcfg.global to live runtime state (after load / reload).
pub fn applyConfigToRuntime() void {
    if (pcfg.global.widget_count > 0) {
        state.widget_count = pcfg.global.widget_count;
        for (0..@intCast(@max(0, state.widget_count))) |i| state.widgets[i] = pcfg.global.widgets[i];
    }
    if (pcfg.global.dock_icon_size > 0) {
        dock_mod.DOCK_ICON_SIZE = pcfg.global.dock_icon_size;
        icon.clearCache();
    }
    if (pcfg.global.pins_len > 0) {
        dock_mod.loadPinned(pcfg.global.pins[0..pcfg.global.pins_len]);
    }
    if (pcfg.global.autohide_dock != state.autohide_dock) {
        main.setDockAutohide(pcfg.global.autohide_dock);
    }
    if (pcfg.global.autohide_panel != state.autohide_panel) {
        main.setPanelAutohide(pcfg.global.autohide_panel);
    }
    if (pcfg.global.font_scale > 0) {
        main.applyFontScale(@floatCast(pcfg.global.font_scale));
    }
    if (pcfg.global.panel_height > 0 and pcfg.global.panel_height != state.panel_height) {
        main.setPanelHeight(pcfg.global.panel_height);
    }
}
