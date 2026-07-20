import re

with open('/media/naranyala/Data/projects-remote/labwc-zigshell/src/shells/zigshell-blend2d/src/main_shell.zig', 'r') as f:
    code = f.read()

motion_replacement = """fn pointerMotion(data: ?*anyopaque, p: ?*c.wl_pointer, time: u32, x: c.wl_fixed_t, y: c.wl_fixed_t) callconv(.c) void {
    _ = data;
    _ = p;
    _ = time;
    pointer_x = c.wl_fixed_to_int(x);
    pointer_y = c.wl_fixed_to_int(y);
    if (pointer_on_dock) {
        if (drag_dock_group >= 0) {
            const hover_group = dock_mod.groupAt(dock_surface.width, pointer_x);
            if (hover_group >= 0 and hover_group != drag_dock_group) {
                dock_mod.swapGroups(@intCast(drag_dock_group), @intCast(hover_group));
                drag_dock_group = hover_group;
            }
        }
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
    if (pointer_on_panel and settings_open and settings_drag_idx >= 0 and settings_tab == 1) {
        const r = settingsRect();
        const ah_y = SET_LIST_Y;
        const is_y = ah_y + SET_ROW_H + 6;
        const pins_start = is_y + SET_ROW_H + 12;
        if (pointer_y >= pins_start and pointer_y < r.y + r.h - 8) {
            const row = @divTrunc(pointer_y - pins_start, SET_ROW_H);
            if (row >= 0 and row < dock_mod.persistent_count and row != settings_drag_idx) {
                dock_mod.swapGroups(@intCast(settings_drag_idx), @intCast(row));
                settings_drag_idx = row;
                syncConfigFromRuntime();
                config_dirty = true;
                dirty = true;
            }
        }
    }
}"""
code = re.sub(r'fn pointerMotion\([\s\S]*?\n\}', motion_replacement, code, count=1)

with open('/media/naranyala/Data/projects-remote/labwc-zigshell/src/shells/zigshell-blend2d/src/main_shell.zig', 'w') as f:
    f.write(code)
