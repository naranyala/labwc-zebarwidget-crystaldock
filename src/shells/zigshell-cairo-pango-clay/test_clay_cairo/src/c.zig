// c.zig — C imports for Cairo + Clay (extern declarations to avoid @cImport issues)
pub const c = @cImport({
    @cInclude("clay.h");
});

// Cairo type aliases
pub const cairo_surface_t = opaque {};
pub const cairo_t = opaque {};

// Cairo constants
pub const CAIRO_FORMAT_ARGB32 = 0;

// Cairo functions (extern declarations)
pub extern "c" fn cairo_image_surface_create(format: c_int, width: c_int, height: c_int) ?*cairo_surface_t;
pub extern "c" fn cairo_surface_destroy(surface: ?*cairo_surface_t) void;
pub extern "c" fn cairo_create(surface: ?*cairo_surface_t) ?*cairo_t;
pub extern "c" fn cairo_destroy(cr: ?*cairo_t) void;
pub extern "c" fn cairo_set_source_rgba(cr: ?*cairo_t, r: f64, g: f64, b: f64, a: f64) void;
pub extern "c" fn cairo_rectangle(cr: ?*cairo_t, x: f64, y: f64, width: f64, height: f64) void;
pub extern "c" fn cairo_fill(cr: ?*cairo_t) void;
pub extern "c" fn cairo_stroke(cr: ?*cairo_t) void;
pub extern "c" fn cairo_set_line_width(cr: ?*cairo_t, width: f64) void;
pub extern "c" fn cairo_move_to(cr: ?*cairo_t, x: f64, y: f64) void;
pub extern "c" fn cairo_set_font_size(cr: ?*cairo_t, size: f64) void;
pub extern "c" fn cairo_show_text(cr: ?*cairo_t, text: [*:0]const u8) c_int;
pub extern "c" fn cairo_surface_write_to_png(surface: ?*cairo_surface_t, filename: [*:0]const u8) c_int;
pub extern "c" fn cairo_new_sub_path(cr: ?*cairo_t) void;
pub extern "c" fn cairo_arc(cr: ?*cairo_t, xc: f64, yc: f64, radius: f64, angle1: f64, angle2: f64) void;
pub extern "c" fn cairo_close_path(cr: ?*cairo_t) void;

// Global Cairo context (set by main before rendering)
pub var cr: ?*anyopaque = null;

// Clay accessor functions (declared in clay_layout.c)
pub const clay = struct {
    pub extern "c" fn clay_init(width: c_int, height: c_int) void;
    pub extern "c" fn clay_cleanup() void;
    pub extern "c" fn clay_set_text_measurement() void;
    pub extern "c" fn clay_layout_status_bar(width: c_int, height: c_int) c_int;
    pub extern "c" fn clay_layout_center_card(width: c_int, height: c_int) c_int;
    pub extern "c" fn clay_layout_dock(width: c_int, height: c_int, icon_count: c_int) c_int;
    pub extern "c" fn clay_cmd_count() c_int;
    pub extern "c" fn clay_cmd_x(i: c_int) f32;
    pub extern "c" fn clay_cmd_y(i: c_int) f32;
    pub extern "c" fn clay_cmd_w(i: c_int) f32;
    pub extern "c" fn clay_cmd_h(i: c_int) f32;
    pub extern "c" fn clay_cmd_type(i: c_int) c_int;
    pub extern "c" fn clay_cmd_bg_r(i: c_int) f32;
    pub extern "c" fn clay_cmd_bg_g(i: c_int) f32;
    pub extern "c" fn clay_cmd_bg_b(i: c_int) f32;
    pub extern "c" fn clay_cmd_bg_a(i: c_int) f32;
    pub extern "c" fn clay_cmd_radius(i: c_int) f32;
    pub extern "c" fn clay_cmd_text_r(i: c_int) f32;
    pub extern "c" fn clay_cmd_text_g(i: c_int) f32;
    pub extern "c" fn clay_cmd_text_b(i: c_int) f32;
    pub extern "c" fn clay_cmd_text_a(i: c_int) f32;
    pub extern "c" fn clay_cmd_font_size(i: c_int) c_int;
    pub extern "c" fn clay_cmd_text_len(i: c_int) c_int;
    pub extern "c" fn clay_cmd_text_ptr(i: c_int) [*:0]const u8;
    pub extern "c" fn clay_cmd_border_r(i: c_int) f32;
    pub extern "c" fn clay_cmd_border_g(i: c_int) f32;
    pub extern "c" fn clay_cmd_border_b(i: c_int) f32;
    pub extern "c" fn clay_cmd_border_a(i: c_int) f32;
    pub extern "c" fn clay_cmd_border_l(i: c_int) c_int;
};
