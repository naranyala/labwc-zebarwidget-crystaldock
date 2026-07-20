// panel.zig — Widget system for Blend2D panel
// Adapted from zigshell-cairo-pango: cairo_t → BlendRenderer, Pango → Blend2D text.
//
// Abstraction:
//   * Widget is a tagged union: a `kind` plus a per-kind `state` payload, so each
//     widget carries only the state it needs (no monolithic struct of every field).
//   * Behaviour is dispatched through a single `VTABLE` keyed by `WidgetKind`
//     (measure / draw / update / click), instead of four function pointers per widget.
//   * Visuals are centralized in a `Theme` so every widget draws consistently
//     (rounded pills, shared palette, padding, radius) and can be retuned in one place.

const std = @import("std");
const c = @import("c.zig").c;
extern "c" fn waitpid(pid: c_int, status: ?*c_int, options: c_int) c_int;
const toplevel = @import("shellcore").toplevel;
const sysread = @import("shellcore").sysread;
const icon = @import("icon.zig");
const blend2d = @import("blend2d_render.zig");

pub const MAX_WIDGETS = 64;

const spawn_log = std.log.scoped(.spawn);

/// Run a shell command via c.system, logging a diagnostic when the shell
/// cannot be started or the command exits non-zero. Widget actions are
/// fire-and-forget (most append '&'), so we only surface failures — we never
/// block or propagate. Returns true when the command was launched cleanly.
fn spawn(cmd: [*c]const u8) bool {
    const pid = c.fork();
    if (pid < 0) {
        spawn_log.err("failed to fork for command: {s}", .{std.mem.sliceTo(cmd, 0)});
        return false;
    }
    if (pid == 0) {
        const child = c.fork();
        if (child == 0) {
            _ = c.execl("/bin/sh", "sh", "-c", cmd, @as([*c]const u8, null));
            c.exit(1);
        }
        c.exit(0);
    }
    _ = waitpid(pid, null, 0);
    return true;
}

// ---- Widget kinds ----

pub const WidgetKind = enum {
    workspaces,
    toplevel_task,
    launcher,
    cpu,
    mem,
    temp,
    disk,
    battery,
    volume,
    network,
    media,
    clock,
    power,
    spacer,
    kbindicator,
    customcommand,
    showdesktop,
    wallpaper,
    worldclock,
    backlight,
    session,
    versions,
    settings,
};

// ---- Per-kind state payloads ----

const WsState = struct {
    labels: [64]u8 = std.mem.zeroes([64]u8),
};

const TlState = struct {};

const LauncherState = struct {
    cmd: [128]u8 = std.mem.zeroes([128]u8),
};

const CpuState = struct {
    prev_total: i64 = 0,
    prev_idle: i64 = 0,
    txt: [32]u8 = std.mem.zeroes([32]u8),
    cmd: [128]u8 = std.mem.zeroes([128]u8),
};

const MemState = struct {
    txt: [32]u8 = std.mem.zeroes([32]u8),
    cmd: [128]u8 = std.mem.zeroes([128]u8),
};

const TempState = struct {
    txt: [32]u8 = std.mem.zeroes([32]u8),
    cmd: [128]u8 = std.mem.zeroes([128]u8),
};

const DiskState = struct {
    txt: [32]u8 = std.mem.zeroes([32]u8),
};

const BatteryState = struct {
    lvl: i32 = -1,
    charging: bool = false,
    txt: [32]u8 = std.mem.zeroes([32]u8),
    cmd: [128]u8 = std.mem.zeroes([128]u8),
};

const VolumeState = struct {
    mute: bool = false,
    txt: [32]u8 = std.mem.zeroes([32]u8),
};

const NetworkState = struct {
    txt: [64]u8 = std.mem.zeroes([64]u8),
    iface: [32]u8 = std.mem.zeroes([32]u8),
    rx_prev: u64 = 0,
    tx_prev: u64 = 0,
    hist_rx: [16]f64 = std.mem.zeroes([16]f64),
    hist_tx: [16]f64 = std.mem.zeroes([16]f64),
    day_rx: u64 = 0,
    day_tx: u64 = 0,
    hist_day_rx: [7]u64 = .{0} ** 7,
    hist_day_tx: [7]u64 = .{0} ** 7,
    day_idx: i64 = -1,
};

const MediaState = struct {
    txt: [96]u8 = std.mem.zeroes([96]u8),
    playing: bool = false,
};

const ClockState = struct {
    fmt: [32]u8 = std.mem.zeroes([32]u8),
    txt: [64]u8 = std.mem.zeroes([64]u8),
};

const PowerState = struct {
    cmd: [128]u8 = std.mem.zeroes([128]u8),
};

const SpacerState = struct {
    w: i32 = 20,
};

const KbState = struct {
    layouts: [256]u8 = std.mem.zeroes([256]u8),
    idx: i32 = 0,
    txt: [32]u8 = std.mem.zeroes([32]u8),
};

const CustomCommandState = struct {
    cmd: [128]u8 = std.mem.zeroes([128]u8),
    out: [128]u8 = std.mem.zeroes([128]u8),
};

const ShowDesktopState = struct {
    cmd: [128]u8 = std.mem.zeroes([128]u8),
};

const WallpaperState = struct {};

const WorldClockState = struct {
    tz: [64]u8 = std.mem.zeroes([64]u8),
    label: [16]u8 = std.mem.zeroes([16]u8),
    txt: [64]u8 = std.mem.zeroes([64]u8),
};

const BacklightState = struct {
    lvl: i32 = -1,
};

const SessionState = struct {};

const VersionsState = struct {
    txt: [64]u8 = std.mem.zeroes([64]u8),
};

const SettingsState = struct {};

pub const Widget = struct {
    kind: WidgetKind,
    side: u8,
    cached_w: i32,
    hover: bool = false,
    priv: ?*anyopaque = null,
    state: State,

    const State = union(WidgetKind) {
        workspaces: WsState,
        toplevel_task: TlState,
        launcher: LauncherState,
        cpu: CpuState,
        mem: MemState,
        temp: TempState,
        disk: DiskState,
        battery: BatteryState,
        volume: VolumeState,
        network: NetworkState,
        media: MediaState,
        clock: ClockState,
        power: PowerState,
        spacer: SpacerState,
        kbindicator: KbState,
        customcommand: CustomCommandState,
        showdesktop: ShowDesktopState,
        wallpaper: WallpaperState,
        worldclock: WorldClockState,
        backlight: BacklightState,
        session: SessionState,
        versions: VersionsState,
        settings: SettingsState,
    };

    /// Compatibility alias used by main_shell (renderPanel/reload).
    pub fn wtype(self: *const Widget) WidgetKind {
        return self.kind;
    }
};

pub const PanelCtx = struct {
    toplevels: []toplevel.ToplevelInfo,
    count: *i32,
    seat: ?*c.wl_seat,
    panel_height: i32 = 28,
    pointer_x: i32 = -1,
    pointer_y: i32 = -1,
    hover_index: i32 = -1,
};

// ---- Theme ----

pub const Theme = struct {
    // surface
    bg_top: u32 = 0xFF1A1C26,
    bg_bottom: u32 = 0xFF0A0C11,
    accent: u32 = 0xFF3399DB,

    // text
    text: [3]f64 = .{ 0.85, 0.85, 0.88 },
    text_dim: [3]f64 = .{ 0.6, 0.7, 0.8 },
    text_white: [3]f64 = .{ 1.0, 1.0, 1.0 },

    // pill / chip
    pill_bg: u32 = 0x2A2D3A,
    pill_bg_hover: u32 = 0x3A3E4F,
    pill_radius: f64 = 8.0,
    pill_pad_x: f64 = 8.0,

    // meters
    meter_bg: u32 = 0xFF262633,
    meter_green: u32 = 0xFF4CCC7F,
    meter_yellow: u32 = 0xFFE6B333,
    meter_red: u32 = 0xFFE63333,
    meter_blue: u32 = 0xFF6699E6,
    meter_blue2: u32 = 0xFF80B3E6,
    meter_orange: u32 = 0xFFE6B333,

    font_size: f64 = 9.0,
    icon_size: f64 = 11.0,
};

// ---- Text / icon rendering helpers ----

pub fn rgb(r: f64, g: f64, b: f64) u32 {
    return @as(u32, 255) << 24 |
        @as(u32, @intFromFloat(r * 255)) << 16 |
        @as(u32, @intFromFloat(g * 255)) << 8 |
        @as(u32, @intFromFloat(b * 255));
}

pub fn widgetText(renderer: *blend2d.BlendRenderer, text: [*:0]const u8, x: i32, h: i32, font_size: f64, r: f64, g: f64, b: f64) i32 {
    renderer.setFontSize(font_size);
    const color = rgb(r, g, b);
    const text_slice = std.mem.sliceTo(text, 0);
    const tm = renderer.measureText(text_slice);
    const y_offset = @divTrunc(h - @as(i32, @intFromFloat(tm.height)), 2);
    renderer.drawText(text_slice, @floatFromInt(x), @floatFromInt(y_offset), color);
    return @intFromFloat(tm.width);
}

pub fn widgetIconGlyph(renderer: *blend2d.BlendRenderer, glyph: [*:0]const u8, x: i32, h: i32, r: f64, g: f64, b: f64) void {
    _ = widgetText(renderer, glyph, x, h, 11.0, r, g, b);
}

// ---- VTable dispatch ----

const DrawCtx = struct {
    renderer: *blend2d.BlendRenderer,
    x: i32,
    y: i32,
    h: i32,
    theme: *const Theme,
    ctx: *PanelCtx,
    index: i32 = -1,
};

const VTable = struct {
    measure: *const fn (*Widget, i32, *const Theme) i32,
    draw: *const fn (*Widget, *DrawCtx) void,
    update: ?*const fn (*Widget, *PanelCtx) void,
    click: ?*const fn (*Widget, u32, i32, i32, *PanelCtx) bool,
};

// ===== Workspaces =====

fn wsMeasure(w: *Widget, h: i32, _: *const Theme) i32 {
    _ = h;
    const len = std.mem.indexOfScalar(u8, &w.state.workspaces.labels, 0) orelse w.state.workspaces.labels.len;
    return @intCast(len * 7 + 8);
}

fn wsDraw(w: *Widget, dc: *DrawCtx) void {
    const t = dc.theme;
    _ = widgetText(dc.renderer, @ptrCast(&w.state.workspaces.labels), dc.x, dc.h, 10.0, t.text_dim[0], t.text_dim[1], t.text_dim[2]);
}

fn wsClick(w: *Widget, btn: u32, lx: i32, _: i32, _: *PanelCtx) bool {
    if (btn != 1) return false;
    const labels = std.mem.sliceTo(&w.state.workspaces.labels, 0);
    var char_pos: i32 = 0;
    for (labels) |ch| {
        if (ch >= '0' and ch <= '9') {
            const char_x = char_pos * 7;
            if (lx >= char_x - 3 and lx < char_x + 10) {
                var buf: [32]u8 = std.mem.zeroes([32]u8);
                _ = std.fmt.bufPrintZ(&buf, "wlrctl workgroup {c} &", .{ch}) catch return true;
                _ = spawn(@ptrCast(&buf));
                return true;
            }
        }
        char_pos += 1;
    }
    _ = spawn("wlrctl workgroup next");
    return true;
}

// ===== Toplevel task (icons) =====

fn tlMeasure(w: *Widget, h: i32, _: *const Theme) i32 {
    if (w.priv == null) return 0;
    const ctx: *PanelCtx = @ptrCast(@alignCast(w.priv.?));
    const icon_size = h - 12;
    if (ctx.count.* == 0) return 0;
    return ctx.count.* * (icon_size + 4);
}

fn tlDraw(w: *Widget, dc: *DrawCtx) void {
    if (w.priv == null) return;
    const ctx: *PanelCtx = @ptrCast(@alignCast(w.priv.?));
    const icon_size = dc.h - 12;
    const cy = dc.y + @divTrunc(dc.h - icon_size, 2);

    for (0..@intCast(ctx.count.*)) |i| {
        const icon_x = dc.x + @as(i32, @intCast(i)) * (icon_size + 4);
        const name_slice = ctx.toplevels[i].app_id[0..std.mem.indexOfScalar(u8, &ctx.toplevels[i].app_id, 0) orelse ctx.toplevels[i].app_id.len];
        const title_slice = ctx.toplevels[i].title[0..std.mem.indexOfScalar(u8, &ctx.toplevels[i].title, 0) orelse ctx.toplevels[i].title.len];
        const name = if (name_slice.len > 0) name_slice else title_slice;

        const icon_img = icon.load(@ptrCast(name.ptr), icon_size) orelse
            icon.fallback(@ptrCast(name.ptr), icon_size);

        var loaded_icon = icon_img;
        // FIX: scale the icon into the cell, centered, instead of drawing the
        // native-size PNG at (x, y) which caused spill/offset.
        renderer_drawIconScaled(dc.renderer, &loaded_icon, icon_x, cy, icon_size);

        if (ctx.toplevels[i].focused) {
            dc.renderer.fillRect(
                @floatFromInt(icon_x + 2),
                @floatFromInt(dc.h - 4),
                @floatFromInt(icon_size - 4),
                2,
                0xFF4C7FBF,
            );
        }
    }
}

fn renderer_drawIconScaled(r: *blend2d.BlendRenderer, img: *c.BLImageCore, x: i32, y: i32, size: i32) void {
    r.drawImageScaled(img, @floatFromInt(x), @floatFromInt(y), @floatFromInt(size), @floatFromInt(size));
}

fn tlClick(w: *Widget, btn: u32, lx: i32, _: i32, _: *PanelCtx) bool {
    if (w.priv == null) return false;
    const ctx: *PanelCtx = @ptrCast(@alignCast(w.priv.?));
    const icon_size = ctx.panel_height - 12;
    const idx = @divTrunc(lx, icon_size + 4);
    if (idx >= 0 and idx < ctx.count.*) {
        const handle: ?*c.zwlr_foreign_toplevel_handle_v1 = @ptrCast(@alignCast(ctx.toplevels[@intCast(idx)].handle));
        if (btn == 1) {
            if (ctx.seat) |seat| {
                _ = c.zwlr_foreign_toplevel_handle_v1_activate(handle, seat);
            }
        } else if (btn == 3) {
            _ = c.zwlr_foreign_toplevel_handle_v1_close(handle);
        }
        return true;
    }
    return false;
}

// ===== Launcher =====

fn launcherMeasure(_: *Widget, _: i32, _: *const Theme) i32 {
    return 18;
}

fn launcherDraw(w: *Widget, dc: *DrawCtx) void {
    _ = w;
    pillBackground(dc, 18);
    widgetIconGlyph(dc.renderer, "\xe2\x8c\x98", dc.x + 4, dc.h, 0.8, 0.8, 0.85);
}

fn launcherClick(w: *Widget, btn: u32, _: i32, _: i32, _: *PanelCtx) bool {
    if (btn != 1) return false;
    _ = spawn(@ptrCast(&w.state.launcher.cmd));
    return true;
}

// ===== CPU meter =====

fn cpuUpdate(w: *Widget, _: *PanelCtx) void {
    var pt: i64 = w.state.cpu.prev_total;
    var pi: i64 = w.state.cpu.prev_idle;
    sysread.cpu(&w.state.cpu.txt, &pt, &pi);
    w.state.cpu.prev_total = pt;
    w.state.cpu.prev_idle = pi;
}

fn cpuMeasure(_: *Widget, _: i32, _: *const Theme) i32 {
    return 44;
}

fn meterDraw(dc: *DrawCtx, txt: *[32]u8, bar_w: f64, fill_color: u32) void {
    const t = dc.theme;
    const bar_h: f64 = @floatFromInt(dc.h - 16);
    const bar_y: f64 = @floatFromInt(dc.y + 8);
    dc.renderer.fillRect(@floatFromInt(dc.x), bar_y, bar_w, bar_h, t.meter_bg);
    var pct: f64 = 0;
    if (c.sscanf(txt, "CPU %lf%%", &pct) == 1 or c.sscanf(txt, "MEM %lf%%", &pct) == 1) {
        const fill_w = bar_w * pct / 100.0;
        dc.renderer.fillRect(@floatFromInt(dc.x), bar_y, fill_w, bar_h, fill_color);
    }
    _ = widgetText(dc.renderer, @ptrCast(txt), dc.x + 4, dc.h, t.font_size, 1.0, 1.0, 1.0);
}

fn cpuDraw(w: *Widget, dc: *DrawCtx) void {
    const t = dc.theme;
    var pct: f64 = 0;
    if (c.sscanf(&w.state.cpu.txt, "CPU %lf%%", &pct) == 1) {
        const color: u32 = if (pct < 50.0) t.meter_green else if (pct < 80.0) t.meter_yellow else t.meter_red;
        meterDraw(dc, &w.state.cpu.txt, 44.0, color);
    } else {
        meterDraw(dc, &w.state.cpu.txt, 44.0, t.meter_red);
    }
}

fn cpuClick(w: *Widget, btn: u32, _: i32, _: i32, _: *PanelCtx) bool {
    if (btn != 1) return false;
    if (w.state.cpu.cmd[0] != 0) {
        _ = spawn(@ptrCast(&w.state.cpu.cmd));
    } else {
        _ = spawn("foot btop &");
    }
    return true;
}

// ===== Memory meter =====

fn memUpdate(w: *Widget, _: *PanelCtx) void {
    sysread.mem(&w.state.mem.txt);
}

fn memMeasure(_: *Widget, _: i32, _: *const Theme) i32 {
    return 50;
}

fn memDraw(w: *Widget, dc: *DrawCtx) void {
    meterDraw(dc, &w.state.mem.txt, 50.0, dc.theme.meter_blue);
}

fn memClick(w: *Widget, btn: u32, _: i32, _: i32, _: *PanelCtx) bool {
    if (btn != 1) return false;
    if (w.state.mem.cmd[0] != 0) {
        _ = spawn(@ptrCast(&w.state.mem.cmd));
    } else {
        _ = spawn("foot htop &");
    }
    return true;
}

// ===== Temp =====

fn tempUpdate(w: *Widget, _: *PanelCtx) void {
    sysread.temp(&w.state.temp.txt);
}

fn tempMeasure(_: *Widget, _: i32, _: *const Theme) i32 {
    return 42;
}

fn tempDraw(w: *Widget, dc: *DrawCtx) void {
    const t = dc.theme;
    widgetIconGlyph(dc.renderer, "\xe2\x99\x81", dc.x, dc.h, 0.9, 0.6, 0.4);
    _ = widgetText(dc.renderer, @ptrCast(&w.state.temp.txt), dc.x + 16, dc.h, t.font_size, 0.8, 0.8, 0.82);
}

fn tempClick(w: *Widget, btn: u32, _: i32, _: i32, _: *PanelCtx) bool {
    if (btn != 1) return false;
    if (w.state.temp.cmd[0] != 0) {
        _ = spawn(@ptrCast(&w.state.temp.cmd));
    } else {
        _ = spawn("foot sensors &");
    }
    return true;
}

// ===== Disk =====

fn diskMeasure(_: *Widget, _: i32, _: *const Theme) i32 {
    return 48;
}

fn diskDraw(w: *Widget, dc: *DrawCtx) void {
    const t = dc.theme;
    widgetIconGlyph(dc.renderer, "\xe2\xa5\xa5", dc.x, dc.h, 0.5, 0.8, 0.6);
    _ = widgetText(dc.renderer, @ptrCast(&w.state.disk.txt), dc.x + 16, dc.h, t.font_size, 0.8, 0.8, 0.82);
}

fn diskClick(_: *Widget, btn: u32, _: i32, _: i32, _: *PanelCtx) bool {
    if (btn != 1) return false;
    _ = spawn("pcmanfm-qt &");
    return true;
}

// ===== Battery =====

fn batUpdate(w: *Widget, _: *PanelCtx) void {
    sysread.battery(&w.state.battery.txt, &w.state.battery.lvl, &w.state.battery.charging);
}

fn batMeasure(_: *Widget, _: i32, _: *const Theme) i32 {
    return 48;
}

fn batDraw(w: *Widget, dc: *DrawCtx) void {
    const t = dc.theme;
    const bat_w: f64 = 18.0;
    const bat_h: f64 = 10.0;
    const bat_y: f64 = @floatFromInt(dc.y + @divTrunc(dc.h - 14, 2));

    dc.renderer.drawBorder(@as(f64, @floatFromInt(dc.x)), bat_y, bat_w, bat_h, 0xFF9999A6);
    dc.renderer.fillRect(@as(f64, @floatFromInt(dc.x)) + bat_w, bat_y + 4.0, 2.0, bat_h - 8.0, 0xFF9999A6);

    if (w.state.battery.lvl >= 0) {
        const fill_w = (bat_w - 4.0) * @as(f64, @floatFromInt(w.state.battery.lvl)) / 100.0;
        const color: u32 = if (w.state.battery.lvl > 50)
            t.meter_green
        else if (w.state.battery.lvl > 20)
            t.meter_yellow
        else
            t.meter_red;
        dc.renderer.fillRect(@as(f64, @floatFromInt(dc.x)) + 2.0, bat_y + 2.0, fill_w, bat_h - 4.0, color);
    }

    _ = widgetText(dc.renderer, @ptrCast(&w.state.battery.txt), dc.x + 24, dc.h, t.font_size, 0.8, 0.8, 0.82);
}

fn batClick(w: *Widget, btn: u32, _: i32, _: i32, _: *PanelCtx) bool {
    if (btn != 1) return false;
    if (w.state.battery.cmd[0] != 0) {
        _ = spawn(@ptrCast(&w.state.battery.cmd));
        return true;
    }
    var bat_device: [64]u8 = undefined;
    const bat_name = findBatteryDevice(&bat_device);
    if (bat_name.len > 0) {
        var cmd: [256]u8 = undefined;
        _ = std.fmt.bufPrintZ(&cmd, "foot upower -i /org/freedesktop/UPower/devices/battery_{s} &", .{bat_name}) catch {};
        _ = spawn(@ptrCast(&cmd));
    }
    return true;
}

fn findBatteryDevice(buf: *[64]u8) []u8 {
    const dir = c.opendir("/sys/class/power_supply") orelse return buf[0..0];
    defer _ = c.closedir(dir);
    while (true) {
        const ent = @as(*c.dirent, @ptrCast(c.readdir(dir) orelse break));
        const dname = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(&ent.d_name)), 0);
        if (dname.len == 0 or dname[0] == '.') continue;
        if (std.mem.startsWith(u8, dname, "BAT")) {
            const n = @min(dname.len, buf.len - 1);
            @memcpy(buf[0..n], dname[0..n]);
            buf[n] = 0;
            return buf[0..n];
        }
    }
    return buf[0..0];
}

// ===== Volume =====

fn volUpdate(w: *Widget, _: *PanelCtx) void {
    var buf: [64]u8 = std.mem.zeroes([64]u8);
    const f = c.popen("pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null", "r") orelse return;
    defer _ = c.pclose(f);
    if (c.fgets(@ptrCast(&buf), buf.len, f)) |line| {
        const s = std.mem.sliceTo(line, 0);
        w.state.volume.mute = std.mem.startsWith(u8, s, "Mute: yes");
    }
    var vbuf: [64]u8 = std.mem.zeroes([64]u8);
    const fv = c.popen("pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null", "r") orelse return;
    defer _ = c.pclose(fv);
    if (c.fgets(@ptrCast(&vbuf), vbuf.len, fv)) |line| {
        const s = std.mem.sliceTo(line, 0);
        var pct_start: usize = 0;
        var found_pct = false;
        for (s, 0..) |ch, i| {
            if (ch == '/' and i + 2 < s.len and s[i + 1] == ' ') {
                pct_start = i + 2;
                found_pct = true;
                break;
            }
        }
        if (found_pct and pct_start < s.len) {
            var pct_end = pct_start;
            while (pct_end < s.len and s[pct_end] != '%' and s[pct_end] != ' ') pct_end += 1;
            if (pct_end > pct_start) {
                const n = @min(pct_end - pct_start, w.state.volume.txt.len - 1);
                @memcpy(w.state.volume.txt[0..n], s[pct_start..pct_start + n]);
                w.state.volume.txt[n] = 0;
            }
        }
    }
}

fn volMeasure(_: *Widget, _: i32, _: *const Theme) i32 {
    return 48;
}

fn volDraw(w: *Widget, dc: *DrawCtx) void {
    const t = dc.theme;
    widgetIconGlyph(dc.renderer, if (w.state.volume.mute) "\xf0\x9f\x94\x87" else "\xf0\x9f\x94\x8a", dc.x, dc.h, 0.6, 0.8, 0.9);
    _ = widgetText(dc.renderer, @ptrCast(&w.state.volume.txt), dc.x + 18, dc.h, t.font_size, 0.8, 0.8, 0.82);
}

fn volClick(w: *Widget, btn: u32, _: i32, _: i32, _: *PanelCtx) bool {
    if (btn != 1) return false;
    w.state.volume.mute = !w.state.volume.mute;
    if (w.state.volume.mute) {
        _ = spawn("pactl set-sink-mute @DEFAULT_SINK@ 1 &");
    } else {
        _ = spawn("pactl set-sink-mute @DEFAULT_SINK@ 0 &");
    }
    return true;
}

// ===== Network =====

fn netMeasure(_: *Widget, _: i32, _: *const Theme) i32 {
    return 80;
}

fn netUpdate(w: *Widget, _: *PanelCtx) void {
    if (w.state.network.iface[0] == 0) {
        if (!sysread.netPickInterface(&w.state.network.iface)) return;
    }
    const sample = sysread.netSample(std.mem.sliceTo(&w.state.network.iface, 0));
    if (!sample.found) return;

    const rx = sample.rx_bytes;
    const tx = sample.tx_bytes;
    if (w.state.network.rx_prev != 0) {
        const drx = rx -% w.state.network.rx_prev;
        const dtx = tx -% w.state.network.tx_prev;
        const rx_kb = @as(f64, @floatFromInt(drx)) / 1024.0;
        const tx_kb = @as(f64, @floatFromInt(dtx)) / 1024.0;

        const t = c.time(null);
        var tm: c.struct_tm = std.mem.zeroes(c.struct_tm);
        _ = c.localtime_r(&t, &tm);
        const day_idx = @divTrunc(@as(i64, @intCast(t + tm.tm_gmtoff)), 86400);

        if (w.state.network.day_idx == -1) {
            loadNetBandwidth(w);
            if (w.state.network.day_idx != -1 and w.state.network.day_idx != day_idx) {
                const days_gap = @as(u64, @intCast(day_idx - w.state.network.day_idx));
                if (days_gap >= 7) {
                    w.state.network.hist_day_rx = .{0} ** 7;
                    w.state.network.hist_day_tx = .{0} ** 7;
                } else {
                    var si: u64 = 0;
                    while (si < 7 - days_gap) : (si += 1) {
                        w.state.network.hist_day_rx[si] = w.state.network.hist_day_rx[si + days_gap];
                        w.state.network.hist_day_tx[si] = w.state.network.hist_day_tx[si + days_gap];
                    }
                    w.state.network.hist_day_rx[7 - days_gap] = w.state.network.day_rx;
                    w.state.network.hist_day_tx[7 - days_gap] = w.state.network.day_tx;
                    si = 7 - days_gap + 1;
                    while (si < 7) : (si += 1) {
                        w.state.network.hist_day_rx[si] = 0;
                        w.state.network.hist_day_tx[si] = 0;
                    }
                }
                w.state.network.day_rx = 0;
                w.state.network.day_tx = 0;
            }
            w.state.network.day_idx = day_idx;
        } else if (day_idx != w.state.network.day_idx) {
            const days_gap = @as(u64, @intCast(day_idx - w.state.network.day_idx));
            if (days_gap >= 7) {
                w.state.network.hist_day_rx = .{0} ** 7;
                w.state.network.hist_day_tx = .{0} ** 7;
            } else {
                var si: u64 = 0;
                while (si < 7 - days_gap) : (si += 1) {
                    w.state.network.hist_day_rx[si] = w.state.network.hist_day_rx[si + days_gap];
                    w.state.network.hist_day_tx[si] = w.state.network.hist_day_tx[si + days_gap];
                }
                w.state.network.hist_day_rx[7 - days_gap] = w.state.network.day_rx;
                w.state.network.hist_day_tx[7 - days_gap] = w.state.network.day_tx;
                si = 7 - days_gap + 1;
                while (si < 7) : (si += 1) {
                    w.state.network.hist_day_rx[si] = 0;
                    w.state.network.hist_day_tx[si] = 0;
                }
            }
            w.state.network.day_rx = 0;
            w.state.network.day_tx = 0;
            w.state.network.day_idx = day_idx;
        }
        var k: usize = 0;
        while (k < 15) : (k += 1) {
            w.state.network.hist_rx[k] = w.state.network.hist_rx[k + 1];
            w.state.network.hist_tx[k] = w.state.network.hist_tx[k + 1];
        }
        w.state.network.hist_rx[15] = rx_kb;
        w.state.network.hist_tx[15] = tx_kb;
        _ = std.fmt.bufPrintZ(&w.state.network.txt, "{d:.0}/{d:.0} KB/s", .{ rx_kb, tx_kb }) catch |err| {
            std.log.err("net text format error: {}", .{err});
        };
    }
    w.state.network.rx_prev = rx;
    w.state.network.tx_prev = tx;
}

fn getNetBandwidthPathOut(out: *[256]u8) []u8 {
    if (c.getenv("XDG_CONFIG_HOME")) |x| {
        const dir = std.mem.sliceTo(x, 0);
        _ = std.fmt.bufPrintZ(out, "{s}/zigshell/netbandwidth.dat", .{dir}) catch return out[0..0];
    } else {
        const home_raw = c.getenv("HOME");
        const home = if (home_raw != null) std.mem.sliceTo(home_raw.?, 0) else "/tmp";
        _ = std.fmt.bufPrintZ(out, "{s}/.config/zigshell/netbandwidth.dat", .{home}) catch return out[0..0];
    }
    return out;
}

fn saveNetBandwidth(w: *Widget) void {
    var pbuf: [256]u8 = std.mem.zeroes([256]u8);
    _ = getNetBandwidthPathOut(&pbuf);
    const f = c.fopen(@as([*:0]const u8, @ptrCast(&pbuf)), "wb") orelse return;
    defer _ = c.fclose(f);
    const magic: u32 = 0x4E455442;
    const ver: u32 = 1;
    _ = c.fwrite(@as(*const anyopaque, @ptrCast(&magic)), 4, 1, f);
    _ = c.fwrite(@as(*const anyopaque, @ptrCast(&ver)), 4, 1, f);
    _ = c.fwrite(@as(*const anyopaque, @ptrCast(&w.state.network.day_rx)), 8, 1, f);
    _ = c.fwrite(@as(*const anyopaque, @ptrCast(&w.state.network.day_tx)), 8, 1, f);
    _ = c.fwrite(@as(*const anyopaque, @ptrCast(&w.state.network.hist_day_rx)), 8, 7, f);
    _ = c.fwrite(@as(*const anyopaque, @ptrCast(&w.state.network.hist_day_tx)), 8, 7, f);
    _ = c.fwrite(@as(*const anyopaque, @ptrCast(&w.state.network.day_idx)), 8, 1, f);
}

fn loadNetBandwidth(w: *Widget) void {
    var pbuf: [256]u8 = std.mem.zeroes([256]u8);
    _ = getNetBandwidthPathOut(&pbuf);
    const f = c.fopen(@as([*:0]const u8, @ptrCast(&pbuf)), "rb") orelse return;
    defer _ = c.fclose(f);
    var magic: u32 = 0;
    var ver: u32 = 0;
    if (c.fread(@as(*anyopaque, @ptrCast(&magic)), 4, 1, f) != 1) return;
    if (c.fread(@as(*anyopaque, @ptrCast(&ver)), 4, 1, f) != 1) return;
    if (magic != 0x4E455442 or ver != 1) return;
    _ = c.fread(@as(*anyopaque, @ptrCast(&w.state.network.day_rx)), 8, 1, f);
    _ = c.fread(@as(*anyopaque, @ptrCast(&w.state.network.day_tx)), 8, 1, f);
    _ = c.fread(@as(*anyopaque, @ptrCast(&w.state.network.hist_day_rx)), 8, 7, f);
    _ = c.fread(@as(*anyopaque, @ptrCast(&w.state.network.hist_day_tx)), 8, 7, f);
    _ = c.fread(@as(*anyopaque, @ptrCast(&w.state.network.day_idx)), 8, 1, f);
}

fn netDraw(w: *Widget, dc: *DrawCtx) void {
    const t = dc.theme;
    widgetIconGlyph(dc.renderer, "\xf0\x9f\x93\xb6", dc.x, dc.h, 0.5, 0.9, 0.6);

    const sp_x = dc.x + 14;
    const sp_w: f64 = 40.0;
    const sp_h: f64 = @floatFromInt(dc.h - 18);
    const sp_y: f64 = @floatFromInt(@divTrunc(dc.h - 18, 2) + 2);

    var maxv: f64 = 1.0;
    for (w.state.network.hist_rx) |v| maxv = @max(maxv, v);
    for (w.state.network.hist_tx) |v| maxv = @max(maxv, v);

    const bw = sp_w / 16.0;
    var k: usize = 0;
    while (k < 16) : (k += 1) {
        const rxh = (w.state.network.hist_rx[k] / maxv) * sp_h * 0.5;
        const txh = (w.state.network.hist_tx[k] / maxv) * sp_h * 0.5;
        dc.renderer.fillRect(@as(f64, @floatFromInt(sp_x)) + @as(f64, @floatFromInt(k)) * bw, sp_y, bw - 1, rxh, t.meter_green);
        dc.renderer.fillRect(@as(f64, @floatFromInt(sp_x)) + @as(f64, @floatFromInt(k)) * bw, sp_y + sp_h * 0.5, bw - 1, txh, t.meter_blue2);
    }

    _ = widgetText(dc.renderer, @ptrCast(&w.state.network.txt), dc.x + 58, dc.h, 8.0, 0.8, 0.8, 0.82);
}

fn netClick(_: *Widget, btn: u32, _: i32, _: i32, _: *PanelCtx) bool {
    if (btn != 1) return false;
    _ = spawn("nm-applet &");
    return true;
}

// ===== Media =====

fn mediaUpdate(w: *Widget, _: *PanelCtx) void {
    var buf: [96]u8 = std.mem.zeroes([96]u8);
    const f = c.popen("playerctl metadata --format '{{title}}' 2>/dev/null", "r") orelse {
        w.state.media.txt[0] = 0;
        return;
    };
    defer _ = c.pclose(f);
    if (c.fgets(@ptrCast(&buf), buf.len, f)) |line| {
        const raw = std.mem.sliceTo(line, 0);
        var end = raw.len;
        while (end > 0 and (raw[end - 1] == '\n' or raw[end - 1] == '\r')) : (end -= 1) {}
        if (end == 0) {
            w.state.media.txt[0] = 0;
            w.state.media.playing = false;
            return;
        }
        const trimmed = raw[0..end];
        const n = @min(trimmed.len, w.state.media.txt.len - 1);
        @memcpy(w.state.media.txt[0..n], trimmed[0..n]);
        w.state.media.txt[n] = 0;
        w.state.media.playing = false;
        var sbuf: [32]u8 = std.mem.zeroes([32]u8);
        const sf = c.popen("playerctl status 2>/dev/null", "r") orelse return;
        defer _ = c.pclose(sf);
        if (c.fgets(@ptrCast(&sbuf), sbuf.len, sf)) |sline| {
            const ss = std.mem.sliceTo(sline, 0);
            w.state.media.playing = std.mem.startsWith(u8, ss, "Playing");
        }
    } else {
        w.state.media.txt[0] = 0;
        w.state.media.playing = false;
    }
}

fn mediaMeasure(w: *Widget, _: i32, _: *const Theme) i32 {
    const len = std.mem.indexOfScalar(u8, &w.state.media.txt, 0) orelse w.state.media.txt.len;
    return @intCast(len * 6 + 20);
}

fn mediaDraw(w: *Widget, dc: *DrawCtx) void {
    const t = dc.theme;
    if (w.state.media.txt[0] == 0) return;
    widgetIconGlyph(dc.renderer, if (w.state.media.playing) "\xe2\x96\xb6" else "\xe2\x9d\x9c", dc.x, dc.h, 0.9, 0.8, 0.4);
    _ = widgetText(dc.renderer, @ptrCast(&w.state.media.txt), dc.x + 18, dc.h, t.font_size, 0.85, 0.85, 0.88);
}

fn mediaClick(_: *Widget, btn: u32, _: i32, _: i32, _: *PanelCtx) bool {
    if (btn != 1) return false;
    _ = spawn("playerctl play-pause &");
    return true;
}

// ===== Clock =====

fn clkUpdate(w: *Widget, _: *PanelCtx) void {
    const now = c.time(null);
    var tm: c.struct_tm = std.mem.zeroes(c.struct_tm);
    _ = c.localtime_r(&now, &tm);
    _ = c.strftime(&w.state.clock.txt, w.state.clock.txt.len, &w.state.clock.fmt, &tm);
}

fn clkMeasure(w: *Widget, _: i32, _: *const Theme) i32 {
    const len = std.mem.indexOfScalar(u8, &w.state.clock.txt, 0) orelse w.state.clock.txt.len;
    return @intCast(len * 7 + 16);
}

fn clkDraw(w: *Widget, dc: *DrawCtx) void {
    const t = dc.theme;
    _ = widgetText(dc.renderer, @ptrCast(&w.state.clock.txt), dc.x, dc.h, 10.0, t.text[0], t.text[1], t.text[2]);
}

fn clkClick(_: *Widget, btn: u32, _: i32, _: i32, _: *PanelCtx) bool {
    if (btn != 1) return false;
    _ = spawn("foot calcurse &");
    return true;
}

// ===== Power =====

fn pwrMeasure(_: *Widget, _: i32, _: *const Theme) i32 {
    return 18;
}

fn pwrDraw(_: *Widget, dc: *DrawCtx) void {
    pillBackground(dc, 18);
    widgetIconGlyph(dc.renderer, "\xe2\x8f\xbb", dc.x + 4, dc.h, 0.9, 0.5, 0.5);
}

fn pwrClick(w: *Widget, btn: u32, _: i32, _: i32, _: *PanelCtx) bool {
    if (btn != 1) return false;
    _ = spawn(@ptrCast(&w.state.power.cmd));
    return true;
}

// ===== Spacer =====

fn spacerMeasure(w: *Widget, _: i32, _: *const Theme) i32 {
    return w.state.spacer.w;
}

fn spacerDraw(_: *Widget, _: *DrawCtx) void {}
fn spacerClick(_: *Widget, _: u32, _: i32, _: i32, _: *PanelCtx) bool {
    return false;
}

// ===== Keyboard layout indicator =====

fn kbUpdate(w: *Widget, _: *PanelCtx) void {
    var i: usize = 0;
    var seg: usize = 0;
    var start: usize = 0;
    while (i <= w.state.kbindicator.layouts.len) : (i += 1) {
        const eof = i == w.state.kbindicator.layouts.len;
        if (eof or w.state.kbindicator.layouts[i] == ',') {
            if (seg == @as(usize, @intCast(w.state.kbindicator.idx))) {
                const slice = w.state.kbindicator.layouts[start..i];
                const n = @min(slice.len, w.state.kbindicator.txt.len - 1);
                @memcpy(w.state.kbindicator.txt[0..n], slice[0..n]);
                w.state.kbindicator.txt[n] = 0;
                return;
            }
            seg += 1;
            start = i + 1;
        }
    }
    std.mem.copyForwards(u8, &w.state.kbindicator.txt, "??");
}

fn kbMeasure(w: *Widget, _: i32, _: *const Theme) i32 {
    const len = std.mem.indexOfScalar(u8, &w.state.kbindicator.txt, 0) orelse w.state.kbindicator.txt.len;
    return @intCast(len * 8 + 12);
}

fn kbDraw(w: *Widget, dc: *DrawCtx) void {
    widgetIconGlyph(dc.renderer, "\xe2\x8c\xa8", dc.x, dc.h, 0.7, 0.8, 0.9);
    _ = widgetText(dc.renderer, @ptrCast(&w.state.kbindicator.txt), dc.x + 18, dc.h, 10.0, 0.85, 0.85, 0.9);
}

fn kbClick(w: *Widget, btn: u32, _: i32, _: i32, _: *PanelCtx) bool {
    if (btn != 1) return false;
    var count: i32 = 1;
    for (w.state.kbindicator.layouts) |ch| {
        if (ch == ',') count += 1;
    }
    w.state.kbindicator.idx = @mod(w.state.kbindicator.idx + 1, count);
    kbUpdate(w, undefined);
    var layout: [64]u8 = std.mem.zeroes([64]u8);
    const n = std.mem.indexOfScalar(u8, &w.state.kbindicator.txt, 0) orelse w.state.kbindicator.txt.len;
    @memcpy(layout[0..n], w.state.kbindicator.txt[0..n]);
    layout[n] = 0;
    var cmd: [128]u8 = std.mem.zeroes([128]u8);
    _ = std.fmt.bufPrintZ(&cmd, "setxkbmap -layout {s} &", .{std.mem.sliceTo(&layout, 0)}) catch |err| {
        std.log.err("layout cmd format error: {}", .{err});
        return true;
    };
    _ = spawn(@ptrCast(&cmd));
    return true;
}

// ===== Custom command =====

fn ccUpdate(w: *Widget, _: *PanelCtx) void {
    var tmpl: [32]u8 = std.mem.zeroes([32]u8);
    _ = std.fmt.bufPrintZ(&tmpl, "/tmp/.zigshell-cc-XXXXXX", .{}) catch return;
    const fd = c.mkstemp(@ptrCast(&tmpl));
    if (fd < 0) return;
    _ = c.unlink(@ptrCast(&tmpl));

    const cmd_slice = std.mem.sliceTo(&w.state.customcommand.cmd, 0);
    var cmd_len = cmd_slice.len;
    while (cmd_len > 0 and cmd_slice[cmd_len - 1] == ' ') cmd_len -= 1;
    if (cmd_len > 0 and cmd_slice[cmd_len - 1] == '&') cmd_len -= 1;
    while (cmd_len > 0 and cmd_slice[cmd_len - 1] == ' ') cmd_len -= 1;
    const sync_cmd = cmd_slice[0..cmd_len];

    var escaped: [320]u8 = std.mem.zeroes([320]u8);
    var ei: usize = 0;
    for (sync_cmd) |ch| {
        if (ch == '\'') {
            if (ei + 4 > escaped.len) break;
            escaped[ei] = '\'';
            escaped[ei + 1] = '\\';
            escaped[ei + 2] = '\'';
            escaped[ei + 3] = '\'';
            ei += 4;
        } else {
            if (ei >= escaped.len) break;
            escaped[ei] = ch;
            ei += 1;
        }
    }
    escaped[ei] = 0;

    const pid = c.fork();
    if (pid < 0) {
        _ = c.close(fd);
        return;
    }
    if (pid == 0) {
        _ = c.dup2(fd, 1);
        _ = c.close(fd);
        const dev_null = c.open("/dev/null", c.O_WRONLY);
        if (dev_null >= 0) {
            _ = c.dup2(dev_null, 2);
            _ = c.close(dev_null);
        }
        _ = c.execl("/bin/sh", "sh", "-c", @as([*c]const u8, @ptrCast(&escaped)), @as([*c]const u8, null));
        c.exit(1);
    }
    var status: c_int = 0;
    _ = waitpid(pid, &status, 0);

    _ = c.lseek(fd, 0, 0);
    var buf: [128]u8 = std.mem.zeroes([128]u8);
    const bytes = c.read(fd, &buf, buf.len);
    _ = c.close(fd);

    if (bytes > 0) {
        var end: usize = std.mem.indexOfScalar(u8, buf[0..@intCast(bytes)], '\n') orelse @intCast(bytes);
        while (end > 0 and (buf[end - 1] == '\n' or buf[end - 1] == '\r')) : (end -= 1) {}
        const n = @min(end, w.state.customcommand.out.len - 1);
        @memcpy(w.state.customcommand.out[0..n], buf[0..n]);
        w.state.customcommand.out[n] = 0;
    }
}

fn ccMeasure(w: *Widget, _: i32, _: *const Theme) i32 {
    const len = std.mem.indexOfScalar(u8, &w.state.customcommand.out, 0) orelse w.state.customcommand.out.len;
    return @intCast(len * 7 + 12);
}

fn ccDraw(w: *Widget, dc: *DrawCtx) void {
    const t = dc.theme;
    if (w.state.customcommand.out[0] == 0) return;
    _ = widgetText(dc.renderer, @ptrCast(&w.state.customcommand.out), dc.x, dc.h, t.font_size, 0.85, 0.85, 0.88);
}

fn ccClick(w: *Widget, btn: u32, _: i32, _: i32, _: *PanelCtx) bool {
    if (btn != 1) return false;
    ccUpdate(w, undefined);
    return true;
}

// ===== Show Desktop =====

fn sdMeasure(_: *Widget, _: i32, _: *const Theme) i32 {
    return 18;
}

fn sdDraw(_: *Widget, dc: *DrawCtx) void {
    pillBackground(dc, 18);
    widgetIconGlyph(dc.renderer, "\xe2\x96\xa3", dc.x + 4, dc.h, 0.7, 0.8, 0.9);
}

fn sdClick(w: *Widget, btn: u32, _: i32, _: i32, _: *PanelCtx) bool {
    if (btn != 1) return false;
    _ = spawn(@ptrCast(&w.state.showdesktop.cmd));
    return true;
}

// ===== World clock =====

fn wcUpdate(w: *Widget, _: *PanelCtx) void {
    var cmd: [128]u8 = std.mem.zeroes([128]u8);
    const tz_str = std.mem.sliceTo(&w.state.worldclock.tz, 0);
    _ = std.fmt.bufPrintZ(&cmd, "TZ='{s}' date +%H:%M 2>/dev/null", .{tz_str}) catch return;

    const f = c.popen(@ptrCast(&cmd), "r") orelse return;
    defer _ = c.pclose(f);

    var buf: [64]u8 = std.mem.zeroes([64]u8);
    if (c.fgets(@ptrCast(&buf), buf.len, f)) |line| {
        const line_slice: []const u8 = std.mem.sliceTo(line, 0);
        const out_len = std.mem.indexOfScalar(u8, line_slice, '\n') orelse line_slice.len;
        if (out_len > 0) {
            const n = @min(out_len, w.state.worldclock.txt.len - 1);
            @memcpy(w.state.worldclock.txt[0..n], line[0..n]);
            w.state.worldclock.txt[n] = 0;
        }
    }
}

fn wcMeasure(w: *Widget, _: i32, _: *const Theme) i32 {
    const label_len = std.mem.indexOfScalar(u8, &w.state.worldclock.label, 0) orelse w.state.worldclock.label.len;
    return @intCast(label_len * 7 + 56);
}

fn wcDraw(w: *Widget, dc: *DrawCtx) void {
    const t = dc.theme;
    _ = widgetText(dc.renderer, @ptrCast(&w.state.worldclock.label), dc.x, dc.h, t.font_size, 0.7, 0.8, 0.9);
    _ = widgetText(dc.renderer, @ptrCast(&w.state.worldclock.txt), dc.x + 28, dc.h, 10.0, t.text[0], t.text[1], t.text[2]);
}

// ===== Backlight =====

fn blUpdate(w: *Widget, _: *PanelCtx) void {
    const dir = c.opendir("/sys/class/backlight") orelse {
        w.state.backlight.lvl = -1;
        return;
    };
    defer _ = c.closedir(dir);
    var chosen: [256]u8 = std.mem.zeroes([256]u8);
    var chosen_len: usize = 0;
    while (true) {
        const ent = @as(*c.dirent, @ptrCast(c.readdir(dir) orelse break));
        const dname = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(&ent.d_name)), 0);
        if (dname.len == 0 or std.mem.eql(u8, dname, ".") or std.mem.eql(u8, dname, "..")) continue;
        const n = @min(dname.len, chosen.len - 32);
        @memcpy(chosen[0..n], dname[0..n]);
        chosen_len = n;
        break;
    }
    if (chosen_len == 0) {
        w.state.backlight.lvl = -1;
        return;
    }
    var path: [320]u8 = std.mem.zeroes([320]u8);
    _ = std.fmt.bufPrintZ(&path, "/sys/class/backlight/{s}/brightness", .{chosen[0..chosen_len]}) catch |err| {
        std.log.err("bl path format error: {}", .{err});
        w.state.backlight.lvl = -1;
        return;
    };
    const fb = c.fopen(@ptrCast(&path), "r") orelse {
        w.state.backlight.lvl = -1;
        return;
    };
    defer _ = c.fclose(fb);
    var cur: i32 = 0;
    _ = c.fscanf(fb, "%d", &cur);

    _ = std.fmt.bufPrintZ(&path, "/sys/class/backlight/{s}/max_brightness", .{chosen[0..chosen_len]}) catch |err| {
        std.log.err("bl max path format error: {}", .{err});
        w.state.backlight.lvl = -1;
        return;
    };
    const fm = c.fopen(@ptrCast(&path), "r") orelse {
        w.state.backlight.lvl = -1;
        return;
    };
    defer _ = c.fclose(fm);
    var maxv: i32 = 0;
    _ = c.fscanf(fm, "%d", &maxv);

    if (maxv > 0) {
        w.state.backlight.lvl = @divTrunc(100 * cur, maxv);
    } else {
        w.state.backlight.lvl = -1;
    }
}

fn blMeasure(_: *Widget, _: i32, _: *const Theme) i32 {
    return 48;
}

fn blDraw(w: *Widget, dc: *DrawCtx) void {
    const t = dc.theme;
    widgetIconGlyph(dc.renderer, "\xe2\x98\x80", dc.x, dc.h, 0.9, 0.7, 0.2);
    const bar_w: f64 = 18.0;
    const bar_h: f64 = 8.0;
    const bar_y: f64 = @floatFromInt(dc.y + @divTrunc(dc.h - 10, 2));
    dc.renderer.fillRect(@floatFromInt(dc.x + 18), bar_y, bar_w, bar_h, t.meter_bg);
    if (w.state.backlight.lvl >= 0) {
        const fill_w = (bar_w - 2.0) * @as(f64, @floatFromInt(w.state.backlight.lvl)) / 100.0;
        dc.renderer.fillRect(@floatFromInt(dc.x + 19), bar_y + 1, fill_w, bar_h - 2, t.meter_orange);
    }
    var txt: [16]u8 = std.mem.zeroes([16]u8);
    if (w.state.backlight.lvl >= 0) {
        _ = std.fmt.bufPrintZ(&txt, "{d}%", .{w.state.backlight.lvl}) catch |err| {
            std.log.err("bl txt format error: {}", .{err});
        };
    } else {
        std.mem.copyForwards(u8, &txt, "n/a");
    }
    _ = widgetText(dc.renderer, @ptrCast(&txt), dc.x + 36, dc.h, t.font_size, 0.8, 0.8, 0.82);
}

fn blClick(_: *Widget, btn: u32, _: i32, _: i32, _: *PanelCtx) bool {
    if (btn == 1) {
        _ = spawn("brightnessctl set +5% &");
    } else if (btn == 3) {
        _ = spawn("brightnessctl set 5%- &");
    } else {
        return false;
    }
    return true;
}

// ===== Versions =====

fn versionsUpdate(w: *Widget, _: *PanelCtx) void {
    var wl_buf: [32]u8 = std.mem.zeroes([32]u8);
    var line_buf: [64]u8 = std.mem.zeroes([64]u8);
    const f = c.popen("pkg-config --modversion wayland-client 2>/dev/null", "r");
    if (f != null) {
        defer _ = c.pclose(f.?);
        if (c.fgets(@ptrCast(&line_buf), @intCast(line_buf.len - 1), f.?)) |line| {
            const s = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(line)), 0);
            const trimmed = std.mem.trim(u8, s, " \t\n\r");
            const n = @min(trimmed.len, 15);
            wl_buf[0] = 'W';
            wl_buf[1] = 'L';
            wl_buf[2] = ':';
            @memcpy(wl_buf[3 .. 3 + n], trimmed[0..n]);
            wl_buf[3 + n] = 0;
        }
    }

    var lc_buf: [32]u8 = std.mem.zeroes([32]u8);
    const fl = c.popen("labwc --version 2>/dev/null | head -1", "r");
    if (fl != null) {
        defer _ = c.pclose(fl.?);
        if (c.fgets(@ptrCast(&lc_buf), @intCast(lc_buf.len - 1), fl.?)) |line| {
            const s = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(line)), 0);
            const trimmed = std.mem.trim(u8, s, " \t\n\r");
            var ver_start: usize = 0;
            for (trimmed, 0..) |ch, i| {
                if (ch >= '0' and ch <= '9') {
                    ver_start = i;
                    break;
                }
            }
            if (ver_start < trimmed.len) {
                const ver = trimmed[ver_start..];
                var lc_txt: [32]u8 = std.mem.zeroes([32]u8);
                const lc_txt_cap = lc_txt.len;
                const n: usize = @min(@min(ver.len, 15), lc_txt_cap - 3);
                lc_txt[0] = 'L';
                lc_txt[1] = 'C';
                lc_txt[2] = ':';
                @memcpy(lc_txt[3 .. 3 + n], ver[0..n]);
                lc_txt[3 + n] = 0;
                const wl_part = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(&wl_buf)), 0);
                const lc_part = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(&lc_txt)), 0);
                var combined: [64]u8 = std.mem.zeroes([64]u8);
                const wl_len = @min(wl_part.len, 31);
                const lc_len = @min(lc_part.len, 31);
                @memcpy(combined[0..wl_len], wl_part[0..wl_len]);
                combined[wl_len] = ' ';
                @memcpy(combined[wl_len + 1 .. wl_len + 1 + lc_len], lc_part[0..lc_len]);
                combined[wl_len + 1 + lc_len] = 0;
                const final_len = @min(wl_len + 1 + lc_len, w.state.versions.txt.len - 1);
                @memcpy(w.state.versions.txt[0..final_len], combined[0..final_len]);
                w.state.versions.txt[final_len] = 0;
            }
        }
    } else {
        const wl_part = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(&wl_buf)), 0);
        const n = wl_part.len;
        @memcpy(w.state.versions.txt[0..n], wl_part[0..n]);
        w.state.versions.txt[n] = 0;
    }
}

fn versionsMeasure(_: *Widget, _: i32, _: *const Theme) i32 {
    return 80;
}

fn versionsDraw(w: *Widget, dc: *DrawCtx) void {
    const t = dc.theme;
    const text = w.state.versions.txt[0..std.mem.indexOfScalar(u8, &w.state.versions.txt, 0) orelse w.state.versions.txt.len];
    _ = widgetText(dc.renderer, @ptrCast(text.ptr), dc.x, dc.h, t.font_size, t.text_dim[0], t.text_dim[1], t.text_dim[2]);
}

fn versionsClick(_: *Widget, _: u32, _: i32, _: i32, _: *PanelCtx) bool {
    return false;
}

// ===== Session / Settings (placeholder pills) =====

fn sessionMeasure(_: *Widget, _: i32, _: *const Theme) i32 {
    return 22;
}

fn sessionDraw(_: *Widget, dc: *DrawCtx) void {
    pillBackground(dc, 22);
    widgetIconGlyph(dc.renderer, "\xe2\x8f\xbb", dc.x + 4, dc.h, 0.9, 0.5, 0.5);
}

fn sessionClick(_: *Widget, btn: u32, _: i32, _: i32, _: *PanelCtx) bool {
    if (btn != 1) return false;
    return true;
}

fn wallpaperMeasure(_: *Widget, h: i32, theme: *const Theme) i32 {
    var sp: Widget = makeWidget(.spacer, 1);
    sp.state.spacer.w = 12;
    return spacerMeasure(&sp, h, theme);
}
fn wallpaperDraw(_: *Widget, _: *DrawCtx) void {}
fn settingsMeasure(_: *Widget, h: i32, theme: *const Theme) i32 {
    var sp: Widget = makeWidget(.spacer, 1);
    sp.state.spacer.w = 12;
    return spacerMeasure(&sp, h, theme);
}
fn settingsDraw(w: *Widget, dc: *DrawCtx) void {
    sessionDraw(w, dc);
}
fn settingsClick(_: *Widget, btn: u32, x: i32, y: i32, ctx: *PanelCtx) bool {
    var s: Widget = makeWidget(.session, 1);
    return sessionClick(&s, btn, x, y, ctx);
}

// ---- VTable ----

const vtable: [std.meta.fields(WidgetKind).len]VTable = blk: {
    var tbl: [std.meta.fields(WidgetKind).len]VTable = undefined;
    tbl[@intFromEnum(WidgetKind.workspaces)] = .{ .measure = wsMeasure, .draw = wsDraw, .update = null, .click = wsClick };
    tbl[@intFromEnum(WidgetKind.toplevel_task)] = .{ .measure = tlMeasure, .draw = tlDraw, .update = null, .click = tlClick };
    tbl[@intFromEnum(WidgetKind.launcher)] = .{ .measure = launcherMeasure, .draw = launcherDraw, .update = null, .click = launcherClick };
    tbl[@intFromEnum(WidgetKind.cpu)] = .{ .measure = cpuMeasure, .draw = cpuDraw, .update = cpuUpdate, .click = cpuClick };
    tbl[@intFromEnum(WidgetKind.mem)] = .{ .measure = memMeasure, .draw = memDraw, .update = memUpdate, .click = memClick };
    tbl[@intFromEnum(WidgetKind.temp)] = .{ .measure = tempMeasure, .draw = tempDraw, .update = tempUpdate, .click = tempClick };
    tbl[@intFromEnum(WidgetKind.disk)] = .{ .measure = diskMeasure, .draw = diskDraw, .update = null, .click = diskClick };
    tbl[@intFromEnum(WidgetKind.battery)] = .{ .measure = batMeasure, .draw = batDraw, .update = batUpdate, .click = batClick };
    tbl[@intFromEnum(WidgetKind.volume)] = .{ .measure = volMeasure, .draw = volDraw, .update = volUpdate, .click = volClick };
    tbl[@intFromEnum(WidgetKind.network)] = .{ .measure = netMeasure, .draw = netDraw, .update = netUpdate, .click = netClick };
    tbl[@intFromEnum(WidgetKind.media)] = .{ .measure = mediaMeasure, .draw = mediaDraw, .update = mediaUpdate, .click = mediaClick };
    tbl[@intFromEnum(WidgetKind.clock)] = .{ .measure = clkMeasure, .draw = clkDraw, .update = clkUpdate, .click = clkClick };
    tbl[@intFromEnum(WidgetKind.power)] = .{ .measure = pwrMeasure, .draw = pwrDraw, .update = null, .click = pwrClick };
    tbl[@intFromEnum(WidgetKind.spacer)] = .{ .measure = spacerMeasure, .draw = spacerDraw, .update = null, .click = spacerClick };
    tbl[@intFromEnum(WidgetKind.kbindicator)] = .{ .measure = kbMeasure, .draw = kbDraw, .update = kbUpdate, .click = kbClick };
    tbl[@intFromEnum(WidgetKind.customcommand)] = .{ .measure = ccMeasure, .draw = ccDraw, .update = ccUpdate, .click = ccClick };
    tbl[@intFromEnum(WidgetKind.showdesktop)] = .{ .measure = sdMeasure, .draw = sdDraw, .update = null, .click = sdClick };
    tbl[@intFromEnum(WidgetKind.wallpaper)] = .{ .measure = wallpaperMeasure, .draw = wallpaperDraw, .update = null, .click = spacerClick };
    tbl[@intFromEnum(WidgetKind.worldclock)] = .{ .measure = wcMeasure, .draw = wcDraw, .update = wcUpdate, .click = null };
    tbl[@intFromEnum(WidgetKind.backlight)] = .{ .measure = blMeasure, .draw = blDraw, .update = blUpdate, .click = blClick };
    tbl[@intFromEnum(WidgetKind.session)] = .{ .measure = sessionMeasure, .draw = sessionDraw, .update = null, .click = sessionClick };
    tbl[@intFromEnum(WidgetKind.versions)] = .{ .measure = versionsMeasure, .draw = versionsDraw, .update = versionsUpdate, .click = versionsClick };
    tbl[@intFromEnum(WidgetKind.settings)] = .{ .measure = settingsMeasure, .draw = settingsDraw, .update = null, .click = settingsClick };
    break :blk tbl;
};

fn vtbl(w: *const Widget) *const VTable {
    return &vtable[@intFromEnum(w.kind)];
}

// ---- Pill background helper ----

fn pillBackground(dc: *DrawCtx, width: i32) void {
    const h: f64 = @floatFromInt(dc.h - 8);
    const y: f64 = 4.0;
    const color = if (dc.index >= 0 and dc.index == dc.ctx.hover_index) dc.theme.pill_bg_hover else dc.theme.pill_bg;
    dc.renderer.fillRoundRect(@floatFromInt(dc.x), y, @floatFromInt(width), h, dc.theme.pill_radius, color);
}

// ---- Widget List Operations ----

pub fn widgetListUpdate(widgets: []Widget, ctx: *PanelCtx) void {
    for (widgets) |*w| {
        if (vtbl(w).update) |fn_ptr| fn_ptr(w, ctx);
    }
}

pub fn widgetListWidth(widgets: []Widget, h: i32, pad: i32, theme: *const Theme) i32 {
    var total: i32 = 0;
    for (widgets) |*w| {
        const width = vtbl(w).measure(w, h, theme);
        w.cached_w = width;
        total += width + pad;
    }
    return total;
}

// ---- Widget creation ----

pub const WidgetList = struct {
    widgets: [MAX_WIDGETS]Widget,
    count: i32,
};

fn makeWidget(kind: WidgetKind, side: u8) Widget {
    const w: Widget = .{
        .kind = kind,
        .side = side,
        .cached_w = 0,
        .state = makeState(kind),
    };
    return w;
}

fn makeState(kind: WidgetKind) Widget.State {
    var st: Widget.State = switch (kind) {
        .workspaces => .{ .workspaces = .{ .labels = std.mem.zeroes([64]u8) } },
        .toplevel_task => .{ .toplevel_task = .{} },
        .launcher => .{ .launcher = .{ .cmd = std.mem.zeroes([128]u8) } },
        .cpu => .{ .cpu = .{ .txt = std.mem.zeroes([32]u8), .cmd = std.mem.zeroes([128]u8) } },
        .mem => .{ .mem = .{ .txt = std.mem.zeroes([32]u8), .cmd = std.mem.zeroes([128]u8) } },
        .temp => .{ .temp = .{ .txt = std.mem.zeroes([32]u8), .cmd = std.mem.zeroes([128]u8) } },
        .disk => .{ .disk = .{ .txt = std.mem.zeroes([32]u8) } },
        .battery => .{ .battery = .{ .txt = std.mem.zeroes([32]u8), .cmd = std.mem.zeroes([128]u8) } },
        .volume => .{ .volume = .{} },
        .network => .{ .network = .{ .txt = std.mem.zeroes([64]u8) } },
        .media => .{ .media = .{} },
        .clock => .{ .clock = .{ .fmt = std.mem.zeroes([32]u8) } },
        .power => .{ .power = .{ .cmd = std.mem.zeroes([128]u8) } },
        .spacer => .{ .spacer = .{ .w = 12 } },
        .kbindicator => .{ .kbindicator = .{ .layouts = std.mem.zeroes([256]u8), .idx = 0, .txt = std.mem.zeroes([32]u8) } },
        .customcommand => .{ .customcommand = .{ .cmd = std.mem.zeroes([128]u8), .out = std.mem.zeroes([128]u8) } },
        .showdesktop => .{ .showdesktop = .{ .cmd = std.mem.zeroes([128]u8) } },
        .wallpaper => .{ .wallpaper = .{} },
        .worldclock => .{ .worldclock = .{ .tz = std.mem.zeroes([64]u8), .label = std.mem.zeroes([16]u8) } },
        .backlight => .{ .backlight = .{} },
        .session => .{ .session = .{} },
        .versions => .{ .versions = .{ .txt = std.mem.zeroes([64]u8) } },
        .settings => .{ .settings = .{} },
    };
    switch (kind) {
        .workspaces => std.mem.copyForwards(u8, &st.workspaces.labels, " 1 2 3 4 "),
        .launcher => std.mem.copyForwards(u8, &st.launcher.cmd, "fuzzel &"),
        .cpu => std.mem.copyForwards(u8, &st.cpu.txt, "CPU --"),
        .mem => std.mem.copyForwards(u8, &st.mem.txt, "MEM --"),
        .temp => std.mem.copyForwards(u8, &st.temp.txt, "--\xc2\xb0C"),
        .disk => std.mem.copyForwards(u8, &st.disk.txt, "SSD --"),
        .battery => std.mem.copyForwards(u8, &st.battery.txt, "BAT ?"),
        .network => std.mem.copyForwards(u8, &st.network.txt, "-- KB/s"),
        .clock => std.mem.copyForwards(u8, &st.clock.fmt, "%H:%M"),
        .power => std.mem.copyForwards(u8, &st.power.cmd, "loginctl poweroff &"),
        .kbindicator => {
            std.mem.copyForwards(u8, &st.kbindicator.layouts, "us,ru");
            std.mem.copyForwards(u8, &st.kbindicator.txt, "us");
        },
        .customcommand => std.mem.copyForwards(u8, &st.customcommand.cmd, "date +%H:%M:%S"),
        .showdesktop => std.mem.copyForwards(u8, &st.showdesktop.cmd, "wlrctl window minimize all &"),
        .worldclock => {
            std.mem.copyForwards(u8, &st.worldclock.tz, "America/New_York");
            std.mem.copyForwards(u8, &st.worldclock.label, "NYC");
        },
        .versions => std.mem.copyForwards(u8, &st.versions.txt, "WL:? LC:?"),
        else => {},
    }
    return st;
}


pub fn widgetCreateDefault() WidgetList {
    var result = WidgetList{
        .widgets = undefined,
        .count = 0,
    };
    @memset(@as([*]u8, @ptrCast(&result.widgets))[0 .. @sizeOf(@TypeOf(result.widgets))], 0);

    const defaults = [_]struct { kind: WidgetKind, side: u8 }{
        .{ .kind = .workspaces, .side = 0 },
        .{ .kind = .toplevel_task, .side = 0 },
        .{ .kind = .launcher, .side = 0 },
        .{ .kind = .versions, .side = 0 },
        .{ .kind = .cpu, .side = 1 },
        .{ .kind = .mem, .side = 1 },
        .{ .kind = .temp, .side = 1 },
        .{ .kind = .disk, .side = 1 },
        .{ .kind = .battery, .side = 1 },
        .{ .kind = .volume, .side = 1 },
        .{ .kind = .network, .side = 1 },
        .{ .kind = .media, .side = 1 },
        .{ .kind = .clock, .side = 1 },
        .{ .kind = .spacer, .side = 1 },
        .{ .kind = .kbindicator, .side = 1 },
        .{ .kind = .customcommand, .side = 1 },
        .{ .kind = .showdesktop, .side = 1 },
        .{ .kind = .worldclock, .side = 1 },
        .{ .kind = .backlight, .side = 1 },
        .{ .kind = .power, .side = 1 },
    };

    for (defaults) |d| {
        const idx: usize = @intCast(result.count);
        result.widgets[idx] = makeWidget(d.kind, d.side);
        result.count += 1;
    }

    return result;
}

pub fn widgetCreateCompact() WidgetList {
    var result = WidgetList{
        .widgets = undefined,
        .count = 0,
    };
    @memset(@as([*]u8, @ptrCast(&result.widgets))[0 .. @sizeOf(@TypeOf(result.widgets))], 0);

    const compact = [_]struct { kind: WidgetKind, side: u8 }{
        .{ .kind = .workspaces, .side = 0 },
        .{ .kind = .launcher, .side = 0 },
        .{ .kind = .clock, .side = 1 },
        .{ .kind = .battery, .side = 1 },
        .{ .kind = .volume, .side = 1 },
        .{ .kind = .network, .side = 1 },
    };

    for (compact) |d| {
        const idx: usize = @intCast(result.count);
        result.widgets[idx] = makeWidget(d.kind, d.side);
        result.count += 1;
    }

    return result;
}

// ---- Config Loading ----

pub const LoadedWidgets = struct {
    widgets: [MAX_WIDGETS]Widget,
    count: i32,
};

fn parseWidgetType(name: []const u8) ?WidgetKind {
    return std.meta.stringToEnum(WidgetKind, name);
}

pub fn configLoadWidgets(allocator: std.mem.Allocator, path: []const u8) ?LoadedWidgets {
    const path_z = allocator.dupeZ(u8, path) catch |err| {
        std.log.err("allocator dupeZ error: {}", .{err});
        return null;
    };
    defer allocator.free(path_z);
    const f = c.fopen(path_z, "r") orelse return null;
    defer _ = c.fclose(f);

    var result: LoadedWidgets = .{
        .widgets = undefined,
        .count = 0,
    };
    @memset(@as([*]u8, @ptrCast(&result.widgets))[0 .. @sizeOf(@TypeOf(result.widgets))], 0);

    var cur_type: [64]u8 = std.mem.zeroes([64]u8);

    var line_buf: [1024]u8 = std.mem.zeroes([1024]u8);
    while (c.fgets(&line_buf, line_buf.len, f) != null) {
        const trimmed = std.mem.trimStart(u8, std.mem.sliceTo(&line_buf, 0), " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        if (trimmed[0] == '[') {
            if (cur_type[0] != 0) {
                if (result.count < MAX_WIDGETS) {
                    const wtype = parseWidgetType(std.mem.sliceTo(&cur_type, 0));
                    if (wtype) |wt| {
                        result.widgets[@intCast(result.count)] = makeWidget(wt, 1);
                        result.count += 1;
                    }
                }
            }
            const end = std.mem.indexOfScalar(u8, trimmed, ']') orelse continue;
            const name = trimmed[1..end];
            const n = @min(name.len, cur_type.len - 1);
            @memcpy(cur_type[0..n], name[0..n]);
            cur_type[n] = 0;
        }
    }

    if (cur_type[0] != 0 and result.count < MAX_WIDGETS) {
        const wtype = parseWidgetType(std.mem.sliceTo(&cur_type, 0));
        if (wtype) |wt| {
            result.widgets[@intCast(result.count)] = makeWidget(wt, 1);
            result.count += 1;
        }
    }

    return result;
}

// ---- Public draw entry used by main_shell.renderPanel ----

pub fn widgetDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32, theme: *const Theme, ctx: *PanelCtx) void {
    var dc = DrawCtx{
        .renderer = renderer,
        .x = x,
        .y = y,
        .h = h,
        .theme = theme,
        .ctx = ctx,
    };
    vtbl(w).draw(w, &dc);
}

pub fn widgetClick(w: *Widget, btn: u32, lx: i32, ly: i32, ctx: *PanelCtx) bool {
    if (vtbl(w).click) |fn_ptr| return fn_ptr(w, btn, lx, ly, ctx);
    return false;
}
