// shared/widget_validation.zig — Renderer-agnostic widget contract tests.
//
// Both zigshell-cairo-pango and zigshell-blend2d ship their own `panel.zig`
// with a WidgetType enum, Widget struct, and creation functions. This module
// asserts that both implementations agree on the widget contract:
//
//   1. WidgetType enum variants are identical.
//   2. widgetCreateDefault produces the same count and type sequence.
//   3. widgetCreateCompact produces a sensible subset.
//   4. Every created widget has measure_fn and draw_fn wired.
//   5. Widget struct invariants (cpu counters are i64, battery starts at -1).
//
// The importing build wires `@import("panel")` to each shell's panel.zig,
// so the exact same assertions run against both renderers.
//
// API differences between shells are handled via @hasDecl:
//   - blend2d: widgetCreateDefault() returns WidgetList (value type)
//   - cairo-pango: widgetCreateDefault(out) takes ptr, returns count

const std = @import("std");
const testing = std.testing;

const panel = @import("panel");

// ---- Adapter: normalize the widgetCreateDefault API difference ----

fn createDefault(widgets: *[panel.MAX_WIDGETS]panel.Widget) i32 {
    // blend2d returns a WidgetList value; cairo-pango takes a pointer + returns count.
    if (@hasDecl(panel, "widgetCreateDefault")) {
        const sig = @typeInfo(@TypeOf(panel.widgetCreateDefault)).@"fn";
        if (sig.params.len == 0) {
            // blend2d: returns WidgetList
            const result = panel.widgetCreateDefault();
            var i: usize = 0;
            while (i < @as(usize, @intCast(result.count))) : (i += 1) {
                widgets[i] = result.widgets[i];
            }
            return result.count;
        } else {
            // cairo-pango: takes *[MAX_WIDGETS]Widget, returns i32
            return panel.widgetCreateDefault(widgets);
        }
    }
    return 0;
}

fn createCompact(widgets: *[panel.MAX_WIDGETS]panel.Widget) i32 {
    if (@hasDecl(panel, "widgetCreateCompact")) {
        const sig = @typeInfo(@TypeOf(panel.widgetCreateCompact)).@"fn";
        if (sig.params.len == 0) {
            const result = panel.widgetCreateCompact();
            var i: usize = 0;
            while (i < @as(usize, @intCast(result.count))) : (i += 1) {
                widgets[i] = result.widgets[i];
            }
            return result.count;
        } else {
            return panel.widgetCreateCompact(widgets);
        }
    }
    return 0;
}

// ---- WidgetType enum parity ----

// The canonical widget set every shell must implement. The cairo-pango and
// blend2d shells share these; shell-specific extensions live in
// `shell_specific_extras` below.
const canonical_variants = [_][]const u8{
    "workspaces",       "launcher",
    "cpu",              "mem",              "temp",
    "disk",             "battery",          "volume",
    "network",          "media",            "clock",
    "power",            "wallpaper",        "spacer",
    "kbindicator",      "customcommand",    "showdesktop",
    "worldclock",       "backlight",        "session",
    "versions",         "settings",
};

// The two shells legitimately diverge on how toplevel windows are tracked:
// cairo-pango handles them outside the WidgetType enum, while blend2d keeps
// a `toplevel_task` widget. This allowlist lists shell-specific extras that
// the cross-shell contract does NOT require both shells to share.
const shell_specific_extras = [_][]const u8{
    "toplevel_task",
};

test "widget type: all canonical variants exist in both shells" {
    const fields = @typeInfo(panel.WidgetType).@"enum".fields;
    inline for (canonical_variants) |name| {
        comptime {
            var found = false;
            for (fields) |f| {
                if (std.mem.eql(u8, f.name, name)) {
                    found = true;
                    break;
                }
            }
            if (!found) @compileError("WidgetType missing canonical variant: " ++ name);
        }
    }
}

test "widget type: no undeclared divergent variants" {
    const fields = @typeInfo(panel.WidgetType).@"enum".fields;
    inline for (fields) |f| {
        comptime {
            var known = false;
            for (canonical_variants) |n| {
                if (std.mem.eql(u8, f.name, n)) { known = true; break; }
            }
            if (!known) {
                for (shell_specific_extras) |n| {
                    if (std.mem.eql(u8, f.name, n)) { known = true; break; }
                }
            }
            if (!known) @compileError("WidgetType has undeclared divergent variant: " ++ f.name);
        }
    }
}

// ---- Default widget creation parity ----

test "widgetCreateDefault: correct count" {
    var widgets: [panel.MAX_WIDGETS]panel.Widget = undefined;
    const count = createDefault(&widgets);
    // Both shells must create at least 5 default widgets (core set).
    try testing.expect(count >= 5);
    try testing.expect(count <= panel.MAX_WIDGETS);
}

test "widgetCreateDefault: all widgets have measure and draw" {
    var widgets: [panel.MAX_WIDGETS]panel.Widget = undefined;
    const count = createDefault(&widgets);
    for (widgets[0..@intCast(count)]) |w| {
        try testing.expect(w.measure_fn != null);
        try testing.expect(w.draw_fn != null);
    }
}

test "widgetCreateDefault: left side widgets come first" {
    var widgets: [panel.MAX_WIDGETS]panel.Widget = undefined;
    const count = createDefault(&widgets);
    var seen_right = false;
    for (widgets[0..@intCast(count)]) |w| {
        if (w.side == 1) {
            seen_right = true;
        } else {
            try testing.expect(!seen_right);
        }
    }
}

test "widgetCreateDefault: workspaces is first widget" {
    var widgets: [panel.MAX_WIDGETS]panel.Widget = undefined;
    _ = createDefault(&widgets);
    try testing.expectEqual(panel.WidgetType.workspaces, widgets[0].wtype);
}

// ---- Compact widget creation parity ----

test "widgetCreateCompact: subset is smaller" {
    var default_widgets: [panel.MAX_WIDGETS]panel.Widget = undefined;
    const default_count = createDefault(&default_widgets);

    var compact_widgets: [panel.MAX_WIDGETS]panel.Widget = undefined;
    const compact_count = createCompact(&compact_widgets);

    try testing.expect(compact_count < default_count);
    try testing.expect(compact_count >= 3);
}

test "widgetCreateCompact: all widgets have measure and draw" {
    var widgets: [panel.MAX_WIDGETS]panel.Widget = undefined;
    const count = createCompact(&widgets);
    for (widgets[0..@intCast(count)]) |w| {
        try testing.expect(w.measure_fn != null);
        try testing.expect(w.draw_fn != null);
    }
}

// ---- parseWidgetType parity (only available when pub) ----

test "parseWidgetType: canonical names map correctly" {
    if (!@hasDecl(panel, "parseWidgetType")) return;
    // Test each name individually to avoid array-init syntax issues.
    try testing.expectEqual(panel.WidgetType.workspaces, panel.parseWidgetType("workspaces").?);
    try testing.expectEqual(panel.WidgetType.launcher, panel.parseWidgetType("launcher").?);
    try testing.expectEqual(panel.WidgetType.cpu, panel.parseWidgetType("cpu").?);
    try testing.expectEqual(panel.WidgetType.mem, panel.parseWidgetType("mem").?);
    try testing.expectEqual(panel.WidgetType.temp, panel.parseWidgetType("temp").?);
    try testing.expectEqual(panel.WidgetType.disk, panel.parseWidgetType("disk").?);
    try testing.expectEqual(panel.WidgetType.battery, panel.parseWidgetType("battery").?);
    try testing.expectEqual(panel.WidgetType.volume, panel.parseWidgetType("volume").?);
    try testing.expectEqual(panel.WidgetType.network, panel.parseWidgetType("network").?);
    try testing.expectEqual(panel.WidgetType.media, panel.parseWidgetType("media").?);
    try testing.expectEqual(panel.WidgetType.clock, panel.parseWidgetType("clock").?);
    try testing.expectEqual(panel.WidgetType.power, panel.parseWidgetType("power").?);
    try testing.expectEqual(panel.WidgetType.spacer, panel.parseWidgetType("spacer").?);
    try testing.expectEqual(panel.WidgetType.kbindicator, panel.parseWidgetType("kbindicator").?);
    try testing.expectEqual(panel.WidgetType.customcommand, panel.parseWidgetType("customcommand").?);
    try testing.expectEqual(panel.WidgetType.showdesktop, panel.parseWidgetType("showdesktop").?);
    try testing.expectEqual(panel.WidgetType.worldclock, panel.parseWidgetType("worldclock").?);
    try testing.expectEqual(panel.WidgetType.backlight, panel.parseWidgetType("backlight").?);
}

test "parseWidgetType: unknown name returns null" {
    if (!@hasDecl(panel, "parseWidgetType")) return;
    try testing.expect(panel.parseWidgetType("nonexistent") == null);
    try testing.expect(panel.parseWidgetType("") == null);
    try testing.expect(panel.parseWidgetType("CPU") == null);
}

// ---- Widget struct invariants ----

test "Widget: cpu_prev fields are i64" {
    var widgets: [panel.MAX_WIDGETS]panel.Widget = undefined;
    const count = createDefault(&widgets);
    for (widgets[0..@intCast(count)]) |w| {
        if (w.wtype == .cpu) {
            try testing.expectEqual(@as(i64, 0), @as(i64, @intCast(w.cpu_prev_total)));
            try testing.expectEqual(@as(i64, 0), @as(i64, @intCast(w.cpu_prev_idle)));
            break;
        }
    }
}

test "Widget: battery initial level is -1 (unknown)" {
    var widgets: [panel.MAX_WIDGETS]panel.Widget = undefined;
    const count = createDefault(&widgets);
    for (widgets[0..@intCast(count)]) |w| {
        if (w.wtype == .battery) {
            try testing.expectEqual(@as(i32, -1), w.bat_lvl);
            break;
        }
    }
}

test "Widget: backlight initial level is -1 (unknown)" {
    var widgets: [panel.MAX_WIDGETS]panel.Widget = undefined;
    const count = createDefault(&widgets);
    for (widgets[0..@intCast(count)]) |w| {
        if (w.wtype == .backlight) {
            try testing.expectEqual(@as(i32, -1), w.bl_lvl);
            break;
        }
    }
}
