const std = @import("std");
const c = @import("c.zig").c;

pub const Theme = struct {
    bg_color: [4]f64 = .{ 0.08, 0.08, 0.10, 0.85 }, // blur-friendly background
    bg_gradient_end: [4]f64 = .{ 0.05, 0.05, 0.07, 0.90 },
    
    border_color: [4]f64 = .{ 0.3, 0.3, 0.35, 1.0 },
    accent_color: [4]f64 = .{ 0.20, 0.61, 0.86, 0.9 }, // Focus lines, active elements
    
    text_color: [4]f64 = .{ 0.85, 0.85, 0.88, 1.0 },
    text_dim_color: [4]f64 = .{ 0.6, 0.6, 0.65, 1.0 },
    
    hover_color: [4]f64 = .{ 1.0, 1.0, 1.0, 0.12 },
    
    // Status colors
    success_color: [4]f64 = .{ 0.3, 0.8, 0.5, 1.0 },
    warning_color: [4]f64 = .{ 0.9, 0.7, 0.2, 1.0 },
    danger_color: [4]f64 = .{ 0.9, 0.2, 0.2, 1.0 },
};

pub var current: Theme = .{};

// Helper to apply cairo color
pub fn setSource(cr: *c.cairo_t, color: [4]f64) void {
    c.cairo_set_source_rgba(cr, color[0], color[1], color[2], color[3]);
}
