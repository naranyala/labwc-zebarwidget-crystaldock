import re

with open('/media/naranyala/Data/projects-remote/labwc-zigshell/src/shells/zigshell-blend2d/src/main_shell.zig', 'r') as f:
    code = f.read()

# 1. Add PANEL_SETTINGS_HEIGHT
code = re.sub(r'const PANEL_HEIGHT = (\d+);', r'const PANEL_HEIGHT = \1;\nconst PANEL_SETTINGS_HEIGHT = 460;', code)

# 2. Add pcfg import
code = re.sub(r'const panel_mod = @import\("panel.zig"\);', r'const panel_mod = @import("panel.zig");\nconst pcfg = @import("panel_config.zig");', code)

# 3. Add Settings state and drag_dock_group
settings_state = """// ---- dock state ----
var dock_hover_idx: i32 = -1;
var drag_dock_group: i32 = -1;

// ---- pointer state ----
var pointer_x: i32 = 0;
var pointer_y: i32 = 0;
var pointer_on_panel = false;
var pointer_on_dock = false;

// ---- settings state ----
var settings_open = false;
var settings_tab: u32 = 0;
var settings_scroll: i32 = 0;
var settings_drag_idx: i32 = -1;
var settings_add_menu: bool = false;
var config_dirty: bool = false;"""
code = re.sub(r'// ---- dock state ----[\s\S]*?var settings_open = false;', settings_state, code)

with open('/media/naranyala/Data/projects-remote/labwc-zigshell/src/shells/zigshell-blend2d/src/main_shell.zig', 'w') as f:
    f.write(code)
