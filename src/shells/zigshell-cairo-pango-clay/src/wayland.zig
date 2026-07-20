// wayland.zig — Wayland protocol callbacks and surface setup
// Registry, output management, layer surface configure/close, frame callbacks.

const std = @import("std");
const c = @import("c.zig").c;
const state = @import("shell_state.zig");
const surface_mod = @import("surface.zig");

const log = std.log.scoped(.wayland);

// ---- Output info ----
pub const OutputInfo = struct {
    output: ?*c.wl_output = null,
    x: i32 = 0,
    y: i32 = 0,
    w: i32 = 0,
    h: i32 = 0,
    scale: i32 = 1,
    name: [32]u8 = .{0} ** 32,
};

pub var outputs: [16]OutputInfo = undefined;
pub var output_count: i32 = 0;

pub fn findOrAddOutput(out: ?*c.wl_output) *OutputInfo {
    const count: usize = @intCast(@max(0, output_count));
    for (0..count) |i| {
        if (outputs[i].output == out) return &outputs[i];
    }
    if (output_count < 16) {
        const idx: usize = @intCast(output_count);
        output_count += 1;
        outputs[idx] = .{ .output = out };
        return &outputs[idx];
    }
    return &outputs[0];
}

// ---- Wayland protocol listeners ----

pub fn registryGlobal(_: ?*anyopaque, reg: ?*c.wl_registry, name: u32, iface: [*c]const u8, _: u32) callconv(.c) void {
    const iface_str = std.mem.span(iface);
    if (std.mem.eql(u8, iface_str, "wl_compositor")) {
        state.compositor = @ptrCast(c.wl_registry_bind(reg, name, &c.wl_compositor_interface, 4));
    } else if (std.mem.eql(u8, iface_str, "wl_shm")) {
        state.shm = @ptrCast(c.wl_registry_bind(reg, name, &c.wl_shm_interface, 1));
    } else if (std.mem.eql(u8, iface_str, "zwlr_layer_shell_v1")) {
        state.layer_shell = @ptrCast(c.wl_registry_bind(reg, name, &c.zwlr_layer_shell_v1_interface, 1));
    } else if (std.mem.eql(u8, iface_str, "zwlr_foreign_toplevel_manager_v1")) {
        state.toplevel_manager = @ptrCast(c.wl_registry_bind(reg, name, &c.zwlr_foreign_toplevel_manager_v1_interface, 1));
    } else if (std.mem.eql(u8, iface_str, "wl_seat")) {
        state.seat = @ptrCast(c.wl_registry_bind(reg, name, &c.wl_seat_interface, 1));
    } else if (std.mem.eql(u8, iface_str, "wl_output")) {
        const out: ?*c.wl_output = @ptrCast(c.wl_registry_bind(reg, name, &c.wl_output_interface, 2));
        _ = findOrAddOutput(out);
    }
}

pub fn layerSurfaceConfigure(_: ?*anyopaque, surface: ?*c.zwlr_layer_surface_v1, serial: u32, w: u32, h: u32) callconv(.c) void {
    const ss = if (surface == state.panel_surface.layer_surface)
        &state.panel_surface
    else if (surface == state.launcher_surface.layer_surface)
        &state.launcher_surface
    else if (surface == state.dock_surface.layer_surface)
        &state.dock_surface
    else if (surface == state.modal_surface.layer_surface)
        &state.modal_surface
    else {
        c.zwlr_layer_surface_v1_ack_configure(surface, serial);
        return;
    };
    ss.configured = true;
    const wi: i32 = @intCast(@min(w, 16384));
    const hi: i32 = @intCast(@min(h, 16384));
    if (wi != 0 and hi != 0 and (wi != ss.width or hi != ss.height)) {
        ss.width = wi;
        ss.height = hi;
        state.markDirty();
    }
    c.zwlr_layer_surface_v1_ack_configure(surface, serial);
    if (surface != state.launcher_surface.layer_surface) {
        c.zwlr_layer_surface_v1_set_size(surface, 0, @intCast(@max(0, ss.height)));
    }
}

pub fn layerSurfaceClosed(_: ?*anyopaque, _: ?*c.zwlr_layer_surface_v1) callconv(.c) void {
    state.running = false;
}

pub fn frameDone(_: ?*anyopaque, cb: ?*c.wl_callback, _: u32) callconv(.c) void {
    if (cb) |b| c.wl_callback_destroy(b);
    // Frame callback handled by the main loop
}

pub fn surfacePreferredScale(_: ?*anyopaque, _: ?*c.wl_surface, scale: i32) callconv(.c) void {
    // Update surface scale — applied on next repaint
    _ = scale;
}

// ---- Output listeners ----
pub fn outputGeometry(_: ?*anyopaque, out: ?*c.wl_output, x: i32, y: i32, _: i32, _: i32, _: i32, _: ?[*:0]const u8, _: ?[*:0]const u8, _: i32) callconv(.c) void {
    const info = findOrAddOutput(out);
    info.x = x;
    info.y = y;
}

pub fn outputMode(_: ?*anyopaque, out: ?*c.wl_output, _: u32, w: i32, h: i32, _: i32) callconv(.c) void {
    const info = findOrAddOutput(out);
    info.w = w;
    info.h = h;
}

pub fn outputScale(_: ?*anyopaque, out: ?*c.wl_output, factor: i32) callconv(.c) void {
    const info = findOrAddOutput(out);
    info.scale = factor;
}

pub fn outputName(_: ?*anyopaque, out: ?*c.wl_output, name: ?[*:0]const u8) callconv(.c) void {
    const info = findOrAddOutput(out);
    if (name) |n| {
        const s = std.mem.span(n);
        const len = @min(s.len, info.name.len - 1);
        @memcpy(info.name[0..len], s[0..len]);
    }
}

pub fn outputDone(_: ?*anyopaque, out: ?*c.wl_output) callconv(.c) void {
    _ = out;
    // Output configuration complete
}
