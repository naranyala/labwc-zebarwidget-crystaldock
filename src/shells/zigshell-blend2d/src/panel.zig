// panel.zig — Widget system for Blend2D panel
// Adapted from zigshell-cairo-pango: cairo_t → BlendRenderer, Pango → Blend2D text.

const std = @import("std");
const c = @import("c.zig").c;
const toplevel = @import("shellcore").toplevel;
const sysread = @import("shellcore").sysread;
const icon = @import("icon.zig");
const blend2d = @import("blend2d_render.zig");

const MAX_WIDGETS = 64;

// ---- Widget System ----

pub const WidgetType = enum {
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
    worldclock,
    backlight,
};

pub const Widget = struct {
    wtype: WidgetType,
    side: u8,
    cached_w: i32,

    measure_fn: ?*const fn (*Widget, i32) i32 = null,
    draw_fn: ?*const fn (*Widget, *blend2d.BlendRenderer, i32, i32, i32) void = null,
    update_fn: ?*const fn (*Widget) void = null,
    click_fn: ?*const fn (*Widget, u32, i32, i32) bool = null,

    priv: ?*anyopaque = null,

    ws_labels: [64]u8 = std.mem.zeroes([64]u8),
    cpu_prev_total: i32 = 0,
    cpu_prev_idle: i32 = 0,
    cpu_txt: [32]u8 = std.mem.zeroes([32]u8),
    mem_txt: [32]u8 = std.mem.zeroes([32]u8),
    temp_txt: [32]u8 = std.mem.zeroes([32]u8),
    disk_txt: [32]u8 = std.mem.zeroes([32]u8),
    bat_lvl: i32 = -1,
    bat_charging: bool = false,
    bat_txt: [32]u8 = std.mem.zeroes([32]u8),
    vol_mute: bool = false,
    vol_txt: [32]u8 = std.mem.zeroes([32]u8),
    net_txt: [64]u8 = std.mem.zeroes([64]u8),
    media_txt: [96]u8 = std.mem.zeroes([96]u8),
    media_playing: bool = false,
    clock_fmt: [32]u8 = std.mem.zeroes([32]u8),
    clock_txt: [64]u8 = std.mem.zeroes([64]u8),
    cmd: [128]u8 = std.mem.zeroes([128]u8),

    // Spacer
    spacer_w: i32 = 20,

    // Keyboard layout indicator
    kb_layouts: [256]u8 = std.mem.zeroes([256]u8),
    kb_idx: i32 = 0,
    kb_txt: [32]u8 = std.mem.zeroes([32]u8),

    // Custom command
    cc_out: [128]u8 = std.mem.zeroes([128]u8),

    // World clock
    wc_tz: [64]u8 = std.mem.zeroes([64]u8),
    wc_label: [16]u8 = std.mem.zeroes([16]u8),

    // Backlight
    bl_lvl: i32 = -1,

    // Network monitor
    net_rx_prev: u64 = 0,
    net_tx_prev: u64 = 0,
    net_iface: [32]u8 = std.mem.zeroes([32]u8),
    net_hist_rx: [16]f64 = std.mem.zeroes([16]f64),
    net_hist_tx: [16]f64 = std.mem.zeroes([16]f64),
};

pub const PanelCtx = struct {
    toplevels: []toplevel.ToplevelInfo,
    count: *i32,
    seat: ?*c.wl_seat,
    panel_height: i32 = 36,
};

// ---- Text Rendering Helpers ----

pub fn widgetText(renderer: *blend2d.BlendRenderer, text: [*:0]const u8, x: i32, h: i32, font_size: f64, r: f64, g: f64, b: f64) i32 {
    renderer.setFontSize(font_size);
    const color: u32 = @as(u32, 255) << 24 | @as(u32, @intFromFloat(r * 255)) << 16 | @as(u32, @intFromFloat(g * 255)) << 8 | @as(u32, @intFromFloat(b * 255));

    const text_slice = std.mem.sliceTo(text, 0);
    const tm = renderer.measureText(text_slice);
    const y_offset = @divTrunc(h - @as(i32, @intFromFloat(tm.height)), 2);
    renderer.drawText(text_slice, @floatFromInt(x), @floatFromInt(y_offset), color);
    return @intFromFloat(tm.width);
}

pub fn widgetIconGlyph(renderer: *blend2d.BlendRenderer, glyph: [*:0]const u8, x: i32, h: i32, r: f64, g: f64, b: f64) void {
    _ = widgetText(renderer, glyph, x, h, 11.0, r, g, b);
}

// ---- Widget Measure/Draw Functions ----

fn wsMeasure(w: *Widget, h: i32) i32 {
    _ = h;
    const len = std.mem.indexOfScalar(u8, &w.ws_labels, 0) orelse w.ws_labels.len;
    return @intCast(len * 7 + 8);
}

fn wsDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32) void {
    _ = y;
    _ = widgetText(renderer, @ptrCast(&w.ws_labels), x, h, 10.0, 0.6, 0.6, 0.7);
}

fn wsClick(w: *Widget, btn: u32, _: i32, _: i32) bool {
    _ = w;
    if (btn != 1) return false;
    _ = c.system("wlrctl workgroup next");
    return true;
}

fn tlMeasure(w: *Widget, h: i32) i32 {
    if (w.priv == null) return 0;
    const ctx: *PanelCtx = @ptrCast(@alignCast(w.priv.?));
    const icon_size = h - 12;
    if (ctx.count.* == 0) return 0;
    return ctx.count.* * (icon_size + 4);
}

fn tlDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32) void {
    if (w.priv == null) return;
    const ctx: *PanelCtx = @ptrCast(@alignCast(w.priv.?));
    const icon_size = h - 12;
    const cy = y + @divTrunc(h - icon_size, 2);

    for (0..@intCast(ctx.count.*)) |i| {
        const icon_x = x + @as(i32, @intCast(i)) * (icon_size + 4);
        const name_slice = ctx.toplevels[i].app_id[0..std.mem.indexOfScalar(u8, &ctx.toplevels[i].app_id, 0) orelse ctx.toplevels[i].app_id.len];
        const title_slice = ctx.toplevels[i].title[0..std.mem.indexOfScalar(u8, &ctx.toplevels[i].title, 0) orelse ctx.toplevels[i].title.len];
        const name = if (name_slice.len > 0) name_slice else title_slice;

        const icon_img = icon.load(@ptrCast(name.ptr), icon_size) orelse
            icon.fallback(@ptrCast(name.ptr), icon_size);

        var loaded_icon = icon_img;
        renderer.drawImage(&loaded_icon, @floatFromInt(icon_x), @floatFromInt(cy));

        if (ctx.toplevels[i].focused) {
            renderer.fillRect(
                @floatFromInt(icon_x + 2),
                @floatFromInt(h - 4),
                @floatFromInt(icon_size - 4),
                2,
                0xFF4C7FBF, // blue focus indicator
            );
        }
    }
}

fn tlClick(w: *Widget, btn: u32, lx: i32, ly: i32) bool {
    _ = ly;
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
        } else if (btn == 3 or btn == 274) {
            _ = c.zwlr_foreign_toplevel_handle_v1_close(handle);
        }
        return true;
    }
    return false;
}

fn launcherMeasure(w: *Widget, h: i32) i32 {
    _ = w;
    _ = h;
    return 22;
}

fn launcherDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32) void {
    _ = w;
    _ = y;
    widgetIconGlyph(renderer, "\xe2\x8c\x98", x + 4, h, 0.8, 0.8, 0.85); // ⌘
}

fn launcherClick(w: *Widget, btn: u32, x: i32, y: i32) bool {
    _ = x;
    _ = y;
    if (btn != 1) return false;
    _ = c.system(@ptrCast(&w.cmd));
    return true;
}

fn cpuUpdate(w: *Widget) void {
    var pt: i64 = w.cpu_prev_total;
    var pi: i64 = w.cpu_prev_idle;
    sysread.cpu(&w.cpu_txt, &pt, &pi);
    w.cpu_prev_total = @intCast(pt);
    w.cpu_prev_idle = @intCast(pi);
}

fn cpuMeasure(w: *Widget, h: i32) i32 {
    _ = w;
    _ = h;
    return 60;
}

fn cpuDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32) void {
    const bar_w: f64 = 60.0;
    const bar_h: f64 = @floatFromInt(h - 16);
    const bar_y: f64 = @floatFromInt(y + 8);

    // Bar background
    renderer.fillRect(@floatFromInt(x), bar_y, bar_w, bar_h, 0xFF262633);

    // Fill based on percentage
    var pct: f64 = 0;
    if (c.sscanf(&w.cpu_txt, "CPU %lf%%", &pct) == 1) {
        const fill_w = bar_w * pct / 100.0;
        const color: u32 = if (pct < 50.0)
            0xFF4CCC7F // green
        else if (pct < 80.0)
            0xFFE6B333 // yellow
        else
            0xFFE63333; // red
        renderer.fillRect(@floatFromInt(x), bar_y, fill_w, bar_h, color);
    }

    _ = widgetText(renderer, @ptrCast(&w.cpu_txt), x + 4, h, 9.0, 1.0, 1.0, 1.0);
}

fn cpuClick(w: *Widget, btn: u32, x: i32, y: i32) bool {
    _ = w;
    _ = x;
    _ = y;
    if (btn != 1) return false;
    _ = c.system("foot btop &");
    return true;
}

fn memUpdate(w: *Widget) void {
    sysread.mem(&w.mem_txt);
}

fn memMeasure(w: *Widget, h: i32) i32 {
    _ = w;
    _ = h;
    return 70;
}

fn memDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32) void {
    const bar_w: f64 = 70.0;
    const bar_h: f64 = @floatFromInt(h - 16);
    const bar_y: f64 = @floatFromInt(y + 8);

    renderer.fillRect(@floatFromInt(x), bar_y, bar_w, bar_h, 0xFF262633);

    var pct: f64 = 0;
    if (c.sscanf(&w.mem_txt, "MEM %lf%%", &pct) == 1) {
        const fill_w = bar_w * pct / 100.0;
        renderer.fillRect(@floatFromInt(x), bar_y, fill_w, bar_h, 0xFF6699E6);
    }

    _ = widgetText(renderer, @ptrCast(&w.mem_txt), x + 4, h, 9.0, 1.0, 1.0, 1.0);
}

fn memClick(w: *Widget, btn: u32, x: i32, y: i32) bool {
    _ = w;
    _ = x;
    _ = y;
    if (btn != 1) return false;
    _ = c.system("foot htop &");
    return true;
}

fn tempUpdate(w: *Widget) void {
    sysread.temp(&w.temp_txt);
}

fn tempMeasure(w: *Widget, h: i32) i32 {
    _ = w;
    _ = h;
    return 56;
}

fn tempDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32) void {
    _ = y;
    widgetIconGlyph(renderer, "\xe2\x99\x81", x, h, 0.9, 0.6, 0.4); // ♨
    _ = widgetText(renderer, @ptrCast(&w.temp_txt), x + 16, h, 9.0, 0.8, 0.8, 0.82);
}

fn tempClick(w: *Widget, btn: u32, x: i32, y: i32) bool {
    _ = w;
    _ = x;
    _ = y;
    if (btn != 1) return false;
    _ = c.system("foot sensors &");
    return true;
}

fn diskMeasure(w: *Widget, h: i32) i32 {
    _ = w;
    _ = h;
    return 64;
}

fn diskDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32) void {
    _ = y;
    widgetIconGlyph(renderer, "\xe2\xa5\xa5", x, h, 0.5, 0.8, 0.6); // ▥
    _ = widgetText(renderer, @ptrCast(&w.disk_txt), x + 16, h, 9.0, 0.8, 0.8, 0.82);
}

fn diskClick(w: *Widget, btn: u32, x: i32, y: i32) bool {
    _ = w;
    _ = x;
    _ = y;
    if (btn != 1) return false;
    _ = c.system("pcmanfm-qt &");
    return true;
}

fn batMeasure(w: *Widget, h: i32) i32 {
    _ = w;
    _ = h;
    return 64;
}

fn batDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32) void {
    const bat_w: f64 = 24.0;
    const bat_h: f64 = 14.0;
    const bat_y: f64 = @floatFromInt(y + @divTrunc(h - 14, 2));

    // Outline
    renderer.drawBorder(@as(f64, @floatFromInt(x)), bat_y, bat_w, bat_h, 0xFF9999A6);

    // Nub
    renderer.fillRect(@as(f64, @floatFromInt(x)) + bat_w, bat_y + 4.0, 2.0, bat_h - 8.0, 0xFF9999A6);

    if (w.bat_lvl >= 0) {
        const fill_w = (bat_w - 4.0) * @as(f64, @floatFromInt(w.bat_lvl)) / 100.0;
        const color: u32 = if (w.bat_lvl > 50)
            0xFF4CCC7F
        else if (w.bat_lvl > 20)
            0xFFE6B333
        else
            0xFFE63333;
        renderer.fillRect(@as(f64, @floatFromInt(x)) + 2.0, bat_y + 2.0, fill_w, bat_h - 4.0, color);
    }

    _ = widgetText(renderer, @ptrCast(&w.bat_txt), x + 30, h, 9.0, 0.8, 0.8, 0.82);
}

fn batUpdate(w: *Widget) void {
    sysread.battery(&w.bat_txt, &w.bat_lvl, &w.bat_charging);
}

fn batClick(w: *Widget, btn: u32, x: i32, y: i32) bool {
    _ = w;
    _ = x;
    _ = y;
    if (btn != 1) return false;
    _ = c.system("foot upower -i /org/freedesktop/UPower/devices/battery_BAT0 &");
    return true;
}

fn volMeasure(w: *Widget, h: i32) i32 {
    _ = w;
    _ = h;
    return 64;
}

fn volDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32) void {
    _ = y;
    widgetIconGlyph(renderer, if (w.vol_mute) "\xf0\x9f\x94\x87" else "\xf0\x9f\x94\x8a", x, h, 0.6, 0.8, 0.9); // 🔇 or 🔊
    _ = widgetText(renderer, @ptrCast(&w.vol_txt), x + 18, h, 9.0, 0.8, 0.8, 0.82);
}

fn volClick(w: *Widget, btn: u32, x: i32, y: i32) bool {
    _ = x;
    _ = y;
    if (btn != 1) return false;
    if (w.vol_mute) {
        _ = c.system("pactl set-sink-mute @DEFAULT_SINK@ 0 &");
    } else {
        _ = c.system("pactl set-sink-mute @DEFAULT_SINK@ 1 &");
    }
    return true;
}

fn netMeasure(w: *Widget, h: i32) i32 {
    _ = w;
    _ = h;
    return 110;
}

fn netUpdate(w: *Widget) void {
    if (w.net_iface[0] == 0) {
        if (!sysread.netPickInterface(&w.net_iface)) return;
    }
    const sample = sysread.netSample(std.mem.sliceTo(&w.net_iface, 0));
    if (!sample.found) return;

    const rx = sample.rx_bytes;
    const tx = sample.tx_bytes;
    if (w.net_rx_prev != 0) {
        const drx = rx -% w.net_rx_prev;
        const dtx = tx -% w.net_tx_prev;
        const rx_kb = @as(f64, @floatFromInt(drx)) / 1024.0;
        const tx_kb = @as(f64, @floatFromInt(dtx)) / 1024.0;
        var k: usize = 0;
        while (k < 15) : (k += 1) {
            w.net_hist_rx[k] = w.net_hist_rx[k + 1];
            w.net_hist_tx[k] = w.net_hist_tx[k + 1];
        }
        w.net_hist_rx[15] = rx_kb;
        w.net_hist_tx[15] = tx_kb;
        _ = std.fmt.bufPrintZ(&w.net_txt, "{d:.0}/{d:.0} KB/s", .{ rx_kb, tx_kb }) catch {};
    }
    w.net_rx_prev = rx;
    w.net_tx_prev = tx;
}

fn netDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32) void {
    _ = y;
    widgetIconGlyph(renderer, "\xf0\x9f\x93\xb6", x, h, 0.5, 0.9, 0.6); // 📶

    const sp_x = x + 18;
    const sp_w: f64 = 56.0;
    const sp_h: f64 = @floatFromInt(h - 18);
    const sp_y: f64 = @floatFromInt(@divTrunc(h - 18, 2) + 2);

    var maxv: f64 = 1.0;
    for (w.net_hist_rx) |v| maxv = @max(maxv, v);
    for (w.net_hist_tx) |v| maxv = @max(maxv, v);

    const bw = sp_w / 16.0;
    var k: usize = 0;
    while (k < 16) : (k += 1) {
        const rxh = (w.net_hist_rx[k] / maxv) * sp_h * 0.5;
        const txh = (w.net_hist_tx[k] / maxv) * sp_h * 0.5;
        renderer.fillRect(@as(f64, @floatFromInt(sp_x)) + @as(f64, @floatFromInt(k)) * bw, sp_y, bw - 1, rxh, 0xFF4CCC7F);
        renderer.fillRect(@as(f64, @floatFromInt(sp_x)) + @as(f64, @floatFromInt(k)) * bw, sp_y + sp_h * 0.5, bw - 1, txh, 0xFF80B3E6);
    }

    _ = widgetText(renderer, @ptrCast(&w.net_txt), x + 80, h, 8.0, 0.8, 0.8, 0.82);
}

fn netClick(w: *Widget, btn: u32, x: i32, y: i32) bool {
    _ = w;
    _ = x;
    _ = y;
    if (btn != 1) return false;
    _ = c.system("nm-applet &");
    return true;
}

fn mediaMeasure(w: *Widget, h: i32) i32 {
    _ = h;
    const len = std.mem.indexOfScalar(u8, &w.media_txt, 0) orelse w.media_txt.len;
    return @intCast(len * 6 + 20);
}

fn mediaDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32) void {
    _ = y;
    if (w.media_txt[0] == 0) return;
    widgetIconGlyph(renderer, if (w.media_playing) "\xe2\x96\xb6" else "\xe2\x9d\x9c", x, h, 0.9, 0.8, 0.4); // ▶ or ❚❚
    _ = widgetText(renderer, @ptrCast(&w.media_txt), x + 18, h, 9.0, 0.85, 0.85, 0.88);
}

fn mediaClick(w: *Widget, btn: u32, x: i32, y: i32) bool {
    _ = w;
    _ = x;
    _ = y;
    if (btn != 1) return false;
    _ = c.system("playerctl play-pause &");
    return true;
}

fn clkMeasure(w: *Widget, h: i32) i32 {
    _ = h;
    const len = std.mem.indexOfScalar(u8, &w.clock_txt, 0) orelse w.clock_txt.len;
    return @intCast(len * 7 + 16);
}

fn clkDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32) void {
    _ = y;
    _ = widgetText(renderer, @ptrCast(&w.clock_txt), x, h, 10.0, 0.85, 0.85, 0.85);
}

fn clkClick(w: *Widget, btn: u32, x: i32, y: i32) bool {
    _ = w;
    _ = x;
    _ = y;
    if (btn != 1) return false;
    _ = c.system("foot calcurse &");
    return true;
}

fn pwrMeasure(w: *Widget, h: i32) i32 {
    _ = w;
    _ = h;
    return 22;
}

fn pwrDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32) void {
    _ = w;
    _ = y;
    widgetIconGlyph(renderer, "\xe2\x8f\xbb", x + 4, h, 0.9, 0.5, 0.5); // ⏻
}

fn pwrClick(w: *Widget, btn: u32, x: i32, y: i32) bool {
    _ = x;
    _ = y;
    if (btn != 1) return false;
    _ = c.system(@ptrCast(&w.cmd));
    return true;
}

// ===== New widgets extracted from lxqt-panel plugins =====

// ---- Spacer (plugin-spacer) ----
fn spacerMeasure(w: *Widget, h: i32) i32 {
    _ = h;
    return w.spacer_w;
}

fn spacerDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32) void {
    _ = w;
    _ = renderer;
    _ = x;
    _ = y;
    _ = h;
}

fn spacerClick(w: *Widget, btn: u32, x: i32, y: i32) bool {
    _ = w;
    _ = btn;
    _ = x;
    _ = y;
    return false;
}

// ---- Keyboard layout indicator (plugin-kbindicator) ----
fn kbMeasure(w: *Widget, h: i32) i32 {
    _ = h;
    const len = std.mem.indexOfScalar(u8, &w.kb_txt, 0) orelse w.kb_txt.len;
    return @intCast(len * 8 + 12);
}

fn kbUpdate(w: *Widget) void {
    var i: usize = 0;
    var seg: usize = 0;
    var start: usize = 0;
    while (i <= w.kb_layouts.len) : (i += 1) {
        const eof = i == w.kb_layouts.len;
        if (eof or w.kb_layouts[i] == ',') {
            if (seg == @as(usize, @intCast(w.kb_idx))) {
                const slice = w.kb_layouts[start..i];
                const n = @min(slice.len, w.kb_txt.len - 1);
                @memcpy(w.kb_txt[0..n], slice[0..n]);
                w.kb_txt[n] = 0;
                return;
            }
            seg += 1;
            start = i + 1;
        }
    }
    std.mem.copyForwards(u8, &w.kb_txt, "??");
}

fn kbDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32) void {
    _ = y;
    widgetIconGlyph(renderer, "\xe2\x8c\xa8", x, h, 0.7, 0.8, 0.9); // ⌨
    _ = widgetText(renderer, @ptrCast(&w.kb_txt), x + 18, h, 10.0, 0.85, 0.85, 0.9);
}

fn kbClick(w: *Widget, btn: u32, x: i32, y: i32) bool {
    _ = x;
    _ = y;
    if (btn != 1) return false;
    var count: i32 = 1;
    for (w.kb_layouts) |ch| {
        if (ch == ',') count += 1;
    }
    w.kb_idx = @mod(w.kb_idx + 1, count);
    kbUpdate(w);
    var layout: [64]u8 = std.mem.zeroes([64]u8);
    const n = std.mem.indexOfScalar(u8, &w.kb_txt, 0) orelse w.kb_txt.len;
    @memcpy(layout[0..n], w.kb_txt[0..n]);
    layout[n] = 0;
    var cmd: [128]u8 = std.mem.zeroes([128]u8);
    _ = std.fmt.bufPrintZ(&cmd, "setxkbmap -layout {s} &", .{std.mem.sliceTo(&layout, 0)}) catch {};
    _ = c.system(@ptrCast(&cmd));
    return true;
}

// ---- Custom command (plugin-customcommand) ----
fn ccMeasure(w: *Widget, h: i32) i32 {
    _ = h;
    const len = std.mem.indexOfScalar(u8, &w.cc_out, 0) orelse w.cc_out.len;
    return @intCast(len * 7 + 12);
}

fn ccUpdate(w: *Widget) void {
    var tmpl: [32]u8 = std.mem.zeroes([32]u8);
    _ = std.fmt.bufPrintZ(&tmpl, "/tmp/.zigshell-cc-XXXXXX", .{}) catch {};
    const fd = c.mkstemp(@ptrCast(&tmpl));
    if (fd < 0) return;
    _ = c.close(fd);
    var cmd: [320]u8 = std.mem.zeroes([320]u8);
    const cmd_slice = std.mem.sliceTo(&w.cmd, 0);
    _ = std.fmt.bufPrintZ(&cmd, "sh -c '{s}' > '{s}' 2>/dev/null", .{ cmd_slice, std.mem.sliceTo(&tmpl, 0) }) catch {
        _ = c.unlink(&tmpl);
        return;
    };
    _ = c.system(@ptrCast(&cmd));
    const f = c.fopen(@ptrCast(&tmpl), "r") orelse {
        _ = c.unlink(@ptrCast(&tmpl));
        return;
    };
    defer {
        _ = c.fclose(f);
        _ = c.unlink(@ptrCast(&tmpl));
    }
    var buf: [128]u8 = std.mem.zeroes([128]u8);
    if (c.fgets(@ptrCast(&buf), buf.len, f)) |line| {
        const raw = std.mem.sliceTo(line, 0);
        var end = raw.len;
        while (end > 0 and (raw[end - 1] == '\n' or raw[end - 1] == '\r')) : (end -= 1) {}
        const trimmed = raw[0..end];
        const n = @min(trimmed.len, w.cc_out.len - 1);
        @memcpy(w.cc_out[0..n], trimmed[0..n]);
        w.cc_out[n] = 0;
    }
}

fn ccDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32) void {
    _ = y;
    if (w.cc_out[0] == 0) return;
    _ = widgetText(renderer, @ptrCast(&w.cc_out), x, h, 9.0, 0.85, 0.85, 0.88);
}

fn ccClick(w: *Widget, btn: u32, x: i32, y: i32) bool {
    _ = x;
    _ = y;
    if (btn != 1) return false;
    ccUpdate(w);
    return true;
}

// ---- Show Desktop (plugin-showdesktop) ----
fn sdMeasure(w: *Widget, h: i32) i32 {
    _ = w;
    _ = h;
    return 22;
}

fn sdDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32) void {
    _ = w;
    _ = y;
    widgetIconGlyph(renderer, "\xe2\x96\xa3", x + 4, h, 0.7, 0.8, 0.9); // ▣
}

fn sdClick(w: *Widget, btn: u32, x: i32, y: i32) bool {
    _ = x;
    _ = y;
    if (btn != 1) return false;
    _ = c.system(@ptrCast(&w.cmd));
    return true;
}

// ---- World clock (plugin-worldclock) ----
fn wcMeasure(w: *Widget, h: i32) i32 {
    _ = h;
    const lbl_len = std.mem.indexOfScalar(u8, &w.wc_label, 0) orelse w.wc_label.len;
    return @intCast(lbl_len * 7 + 56);
}

fn wcUpdate(w: *Widget) void {
    const old = c.getenv("TZ");
    var old_buf: [64]u8 = std.mem.zeroes([64]u8);
    var had_old = false;
    if (old) |o| {
        const os = std.mem.sliceTo(o, 0);
        const n = @min(os.len, old_buf.len - 1);
        @memcpy(old_buf[0..n], os[0..n]);
        old_buf[n] = 0;
        had_old = true;
    }
    _ = c.setenv("TZ", @ptrCast(&w.wc_tz), 1);
    c.tzset();
    const now = c.time(null);
    var tm: c.struct_tm = std.mem.zeroes(c.struct_tm);
    _ = c.localtime_r(&now, &tm);
    _ = c.strftime(&w.clock_txt, w.clock_txt.len, "%H:%M", &tm);
    if (had_old) {
        _ = c.setenv("TZ", @ptrCast(&old_buf), 1);
    } else {
        _ = c.unsetenv("TZ");
    }
    c.tzset();
}

fn wcDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32) void {
    _ = y;
    _ = widgetText(renderer, @ptrCast(&w.wc_label), x, h, 9.0, 0.7, 0.8, 0.9);
    _ = widgetText(renderer, @ptrCast(&w.clock_txt), x + 28, h, 10.0, 0.85, 0.85, 0.85);
}

// ---- Backlight (plugin-backlight) ----
fn blMeasure(w: *Widget, h: i32) i32 {
    _ = w;
    _ = h;
    return 64;
}

fn blUpdate(w: *Widget) void {
    const dir = c.opendir("/sys/class/backlight") orelse {
        w.bl_lvl = -1;
        return;
    };
    defer _ = c.closedir(dir);
    var ent: ?*c.struct_dirent = null;
    var chosen: [256]u8 = std.mem.zeroes([256]u8);
    var chosen_len: usize = 0;
    while (true) {
        ent = c.readdir(dir);
        if (ent == null) break;
        const dname = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(@alignCast(&ent.?.d_name[0]))), 0);
        if (dname.len == 0 or std.mem.eql(u8, dname, ".") or std.mem.eql(u8, dname, "..")) continue;
        const n = @min(dname.len, chosen.len - 32);
        @memcpy(chosen[0..n], dname[0..n]);
        chosen_len = n;
        break;
    }
    if (chosen_len == 0) {
        w.bl_lvl = -1;
        return;
    }
    var path: [320]u8 = std.mem.zeroes([320]u8);
    _ = std.fmt.bufPrintZ(&path, "/sys/class/backlight/{s}/brightness", .{chosen[0..chosen_len]}) catch {
        w.bl_lvl = -1;
        return;
    };
    const fb = c.fopen(@ptrCast(&path), "r") orelse {
        w.bl_lvl = -1;
        return;
    };
    defer _ = c.fclose(fb);
    var cur: i32 = 0;
    _ = c.fscanf(fb, "%d", &cur);

    _ = std.fmt.bufPrintZ(&path, "/sys/class/backlight/{s}/max_brightness", .{chosen[0..chosen_len]}) catch {
        w.bl_lvl = -1;
        return;
    };
    const fm = c.fopen(@ptrCast(&path), "r") orelse {
        w.bl_lvl = -1;
        return;
    };
    defer _ = c.fclose(fm);
    var maxv: i32 = 0;
    _ = c.fscanf(fm, "%d", &maxv);

    if (maxv > 0) {
        w.bl_lvl = @divTrunc(100 * cur, maxv);
    } else {
        w.bl_lvl = -1;
    }
}

fn blDraw(w: *Widget, renderer: *blend2d.BlendRenderer, x: i32, y: i32, h: i32) void {
    widgetIconGlyph(renderer, "\xe2\x98\x80", x, h, 0.9, 0.7, 0.2); // ☀
    const bar_w: f64 = 26.0;
    const bar_h: f64 = 10.0;
    const bar_y: f64 = @floatFromInt(y + @divTrunc(h - 10, 2));
    renderer.fillRect(@floatFromInt(x + 18), bar_y, bar_w, bar_h, 0xFF262633);
    if (w.bl_lvl >= 0) {
        const fill_w = (bar_w - 2.0) * @as(f64, @floatFromInt(w.bl_lvl)) / 100.0;
        renderer.fillRect(@floatFromInt(x + 19), bar_y + 1, fill_w, bar_h - 2, 0xFFE6B333);
    }
    var txt: [16]u8 = std.mem.zeroes([16]u8);
    if (w.bl_lvl >= 0) {
        _ = std.fmt.bufPrintZ(&txt, "{d}%", .{w.bl_lvl}) catch {};
    } else {
        std.mem.copyForwards(u8, &txt, "n/a");
    }
    _ = widgetText(renderer, @ptrCast(&txt), x + 48, h, 9.0, 0.8, 0.8, 0.82);
}

fn blClick(w: *Widget, btn: u32, x: i32, y: i32) bool {
    _ = w;
    _ = x;
    _ = y;
    if (btn == 1) {
        _ = c.system("brightnessctl set +5% &");
    } else if (btn == 3) {
        _ = c.system("brightnessctl set 5%- &");
    } else {
        return false;
    }
    return true;
}

// ---- Widget Creation ----

pub const WidgetList = struct {
    widgets: [MAX_WIDGETS]Widget,
    count: i32,
};

pub fn widgetCreateDefault() WidgetList {
    var result = WidgetList{
        .widgets = std.mem.zeroes([MAX_WIDGETS]Widget),
        .count = 0,
    };

    const defaults = [_]struct { wtype: WidgetType, side: u8 }{
        .{ .wtype = .workspaces, .side = 0 },
        .{ .wtype = .toplevel_task, .side = 0 },
        .{ .wtype = .launcher, .side = 0 },
        .{ .wtype = .cpu, .side = 1 },
        .{ .wtype = .mem, .side = 1 },
        .{ .wtype = .temp, .side = 1 },
        .{ .wtype = .disk, .side = 1 },
        .{ .wtype = .battery, .side = 1 },
        .{ .wtype = .volume, .side = 1 },
        .{ .wtype = .network, .side = 1 },
        .{ .wtype = .media, .side = 1 },
        .{ .wtype = .clock, .side = 1 },
        .{ .wtype = .spacer, .side = 1 },
        .{ .wtype = .kbindicator, .side = 1 },
        .{ .wtype = .customcommand, .side = 1 },
        .{ .wtype = .showdesktop, .side = 1 },
        .{ .wtype = .worldclock, .side = 1 },
        .{ .wtype = .backlight, .side = 1 },
        .{ .wtype = .power, .side = 1 },
    };

    for (defaults) |d| {
        const idx: usize = @intCast(result.count);
        result.widgets[idx] = createWidget(d.wtype);
        result.widgets[idx].side = d.side;
        result.count += 1;
    }

    return result;
}

fn createWidget(wtype: WidgetType) Widget {
    var w: Widget = undefined;
    w.wtype = wtype;
    w.side = 0;
    w.cached_w = 0;
    w.priv = null;
    w.ws_labels = std.mem.zeroes([64]u8);
    w.cpu_prev_total = 0;
    w.cpu_prev_idle = 0;
    w.cpu_txt = std.mem.zeroes([32]u8);
    w.mem_txt = std.mem.zeroes([32]u8);
    w.temp_txt = std.mem.zeroes([32]u8);
    w.disk_txt = std.mem.zeroes([32]u8);
    w.bat_lvl = -1;
    w.bat_charging = false;
    w.bat_txt = std.mem.zeroes([32]u8);
    w.vol_mute = false;
    w.vol_txt = std.mem.zeroes([32]u8);
    w.net_txt = std.mem.zeroes([64]u8);
    w.media_txt = std.mem.zeroes([96]u8);
    w.media_playing = false;
    w.clock_fmt = std.mem.zeroes([32]u8);
    w.clock_txt = std.mem.zeroes([64]u8);
    w.cmd = std.mem.zeroes([128]u8);
    w.spacer_w = 20;
    w.kb_layouts = std.mem.zeroes([256]u8);
    w.kb_idx = 0;
    w.kb_txt = std.mem.zeroes([32]u8);
    w.cc_out = std.mem.zeroes([128]u8);
    w.wc_tz = std.mem.zeroes([64]u8);
    w.wc_label = std.mem.zeroes([16]u8);
    w.bl_lvl = -1;
    w.net_rx_prev = 0;
    w.net_tx_prev = 0;
    w.net_iface = std.mem.zeroes([32]u8);
    w.net_hist_rx = std.mem.zeroes([16]f64);
    w.net_hist_tx = std.mem.zeroes([16]f64);
    w.update_fn = null;
    w.click_fn = null;

    switch (wtype) {
        .workspaces => {
            std.mem.copyForwards(u8, &w.ws_labels, " 1 2 3 4 ");
            w.measure_fn = wsMeasure;
            w.draw_fn = wsDraw;
            w.click_fn = wsClick;
        },
        .toplevel_task => {
            w.measure_fn = tlMeasure;
            w.draw_fn = tlDraw;
            w.click_fn = tlClick;
        },
        .launcher => {
            std.mem.copyForwards(u8, &w.cmd, "fuzzel &");
            w.measure_fn = launcherMeasure;
            w.draw_fn = launcherDraw;
            w.click_fn = launcherClick;
        },
        .cpu => {
            std.mem.copyForwards(u8, &w.cpu_txt, "CPU --");
            w.measure_fn = cpuMeasure;
            w.draw_fn = cpuDraw;
            w.update_fn = cpuUpdate;
            w.click_fn = cpuClick;
        },
        .mem => {
            std.mem.copyForwards(u8, &w.mem_txt, "MEM --");
            w.measure_fn = memMeasure;
            w.draw_fn = memDraw;
            w.update_fn = memUpdate;
            w.click_fn = memClick;
        },
        .temp => {
            std.mem.copyForwards(u8, &w.temp_txt, "--\xc2\xb0C");
            w.measure_fn = tempMeasure;
            w.draw_fn = tempDraw;
            w.update_fn = tempUpdate;
            w.click_fn = tempClick;
        },
        .disk => {
            std.mem.copyForwards(u8, &w.disk_txt, "SSD --");
            w.measure_fn = diskMeasure;
            w.draw_fn = diskDraw;
            w.click_fn = diskClick;
        },
        .battery => {
            std.mem.copyForwards(u8, &w.bat_txt, "BAT ?");
            w.measure_fn = batMeasure;
            w.draw_fn = batDraw;
            w.click_fn = batClick;
            w.update_fn = batUpdate;
        },
        .volume => {
            w.measure_fn = volMeasure;
            w.draw_fn = volDraw;
            w.click_fn = volClick;
        },
        .network => {
            std.mem.copyForwards(u8, &w.net_txt, "-- KB/s");
            w.measure_fn = netMeasure;
            w.draw_fn = netDraw;
            w.click_fn = netClick;
            w.update_fn = netUpdate;
        },
        .media => {
            w.measure_fn = mediaMeasure;
            w.draw_fn = mediaDraw;
            w.click_fn = mediaClick;
        },
        .clock => {
            std.mem.copyForwards(u8, &w.clock_fmt, "%H:%M");
            w.measure_fn = clkMeasure;
            w.draw_fn = clkDraw;
            w.update_fn = clkUpdate;
            w.click_fn = clkClick;
        },
        .power => {
            std.mem.copyForwards(u8, &w.cmd, "loginctl poweroff &");
            w.measure_fn = pwrMeasure;
            w.draw_fn = pwrDraw;
            w.click_fn = pwrClick;
        },
        .spacer => {
            w.spacer_w = 20;
            w.measure_fn = spacerMeasure;
            w.draw_fn = spacerDraw;
            w.click_fn = spacerClick;
        },
        .kbindicator => {
            std.mem.copyForwards(u8, &w.kb_layouts, "us,ru");
            w.kb_idx = 0;
            std.mem.copyForwards(u8, &w.kb_txt, "us");
            w.measure_fn = kbMeasure;
            w.draw_fn = kbDraw;
            w.update_fn = kbUpdate;
            w.click_fn = kbClick;
        },
        .customcommand => {
            std.mem.copyForwards(u8, &w.cmd, "date +%H:%M:%S");
            w.measure_fn = ccMeasure;
            w.draw_fn = ccDraw;
            w.update_fn = ccUpdate;
            w.click_fn = ccClick;
        },
        .showdesktop => {
            std.mem.copyForwards(u8, &w.cmd, "wlrctl window minimize all &");
            w.measure_fn = sdMeasure;
            w.draw_fn = sdDraw;
            w.click_fn = sdClick;
        },
        .worldclock => {
            std.mem.copyForwards(u8, &w.wc_tz, "America/New_York");
            std.mem.copyForwards(u8, &w.wc_label, "NYC");
            w.measure_fn = wcMeasure;
            w.draw_fn = wcDraw;
            w.update_fn = wcUpdate;
        },
        .backlight => {
            w.measure_fn = blMeasure;
            w.draw_fn = blDraw;
            w.update_fn = blUpdate;
            w.click_fn = blClick;
        },
    }

    return w;
}

fn clkUpdate(w: *Widget) void {
    const now = c.time(null);
    var tm: c.struct_tm = std.mem.zeroes(c.struct_tm);
    _ = c.localtime_r(&now, &tm);
    _ = c.strftime(&w.clock_txt, w.clock_txt.len, &w.clock_fmt, &tm);
}

// ---- Widget List Operations ----

pub fn widgetListUpdate(widgets: []Widget) void {
    for (widgets) |*w| {
        if (w.update_fn) |fn_ptr| fn_ptr(w);
    }
}

pub fn widgetListWidth(widgets: []Widget, h: i32, pad: i32) i32 {
    var total: i32 = 0;
    for (widgets) |*w| {
        const width = if (w.measure_fn) |fn_ptr| fn_ptr(w, h) else 0;
        w.cached_w = width;
        total += width + pad;
    }
    return total;
}

// ---- Config Loading ----

pub const LoadedWidgets = struct {
    widgets: [MAX_WIDGETS]Widget,
    count: i32,
};

pub fn configLoadWidgets(allocator: std.mem.Allocator, path: []const u8) ?LoadedWidgets {
    const path_z = allocator.dupeZ(u8, path) catch return null;
    defer allocator.free(path_z);
    const f = c.fopen(path_z, "r") orelse return null;
    defer _ = c.fclose(f);

    var result: LoadedWidgets = .{
        .widgets = std.mem.zeroes([MAX_WIDGETS]Widget),
        .count = 0,
    };

    var cur_type: [64]u8 = std.mem.zeroes([64]u8);
    var opts_buf: [1024]u8 = std.mem.zeroes([1024]u8);
    var opts_len: usize = 0;

    var line_buf: [1024]u8 = std.mem.zeroes([1024]u8);
    while (c.fgets(&line_buf, line_buf.len, f) != null) {
        const trimmed = std.mem.trimStart(u8, std.mem.sliceTo(&line_buf, 0), " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        if (trimmed[0] == '[') {
            if (cur_type[0] != 0) {
                if (result.count < MAX_WIDGETS) {
                    const wtype = parseWidgetType(std.mem.sliceTo(&cur_type, 0));
                    if (wtype) |wt| {
                        result.widgets[@intCast(result.count)] = createWidget(wt);
                        result.count += 1;
                    }
                }
            }
            const end = std.mem.indexOfScalar(u8, trimmed, ']') orelse continue;
            opts_len = 0;
            const type_name = trimmed[1..end];
            @memcpy(cur_type[0..@min(type_name.len, 63)], type_name[0..@min(type_name.len, 63)]);
            cur_type[@min(type_name.len, 63)] = 0;
        } else {
            if (opts_len > 0 and opts_len < opts_buf.len - 1) {
                opts_buf[opts_len] = '\n';
                opts_len += 1;
            }
            const copy_len = @min(trimmed.len, opts_buf.len - opts_len - 1);
            @memcpy(opts_buf[opts_len .. opts_len + copy_len], trimmed[0..copy_len]);
            opts_len += copy_len;
            opts_buf[opts_len] = 0;
        }
    }

    if (cur_type[0] != 0 and result.count < MAX_WIDGETS) {
        const wtype = parseWidgetType(std.mem.sliceTo(&cur_type, 0));
        if (wtype) |wt| {
            result.widgets[@intCast(result.count)] = createWidget(wt);
            result.count += 1;
        }
    }

    return result;
}

fn parseWidgetType(name: []const u8) ?WidgetType {
    const map = [_]struct { n: []const u8, t: WidgetType }{
        .{ .n = "workspaces", .t = .workspaces },
        .{ .n = "toplevel", .t = .toplevel_task },
        .{ .n = "launcher", .t = .launcher },
        .{ .n = "cpu", .t = .cpu },
        .{ .n = "mem", .t = .mem },
        .{ .n = "temp", .t = .temp },
        .{ .n = "disk", .t = .disk },
        .{ .n = "battery", .t = .battery },
        .{ .n = "volume", .t = .volume },
        .{ .n = "network", .t = .network },
        .{ .n = "media", .t = .media },
        .{ .n = "clock", .t = .clock },
        .{ .n = "power", .t = .power },
        .{ .n = "spacer", .t = .spacer },
        .{ .n = "kbindicator", .t = .kbindicator },
        .{ .n = "customcommand", .t = .customcommand },
        .{ .n = "showdesktop", .t = .showdesktop },
        .{ .n = "worldclock", .t = .worldclock },
        .{ .n = "backlight", .t = .backlight },
    };
    for (map) |entry| {
        if (std.mem.eql(u8, name, entry.n)) return entry.t;
    }
    return null;
}

test "panel parseWidgetType" {
    try std.testing.expectEqual(WidgetType.clock, parseWidgetType("clock").?);
    try std.testing.expectEqual(WidgetType.cpu, parseWidgetType("cpu").?);
    try std.testing.expectEqual(@as(?WidgetType, null), parseWidgetType("unknown"));
}
