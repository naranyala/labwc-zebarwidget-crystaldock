// c.zig — C imports for Blend2D + Clay
pub const c = @cImport({
    @cInclude("blend2d/blend2d.h");
    @cInclude("blend2d_render.h");
});

// Clay accessor functions (declared in clay_layout.c)
pub const clay = struct {
    pub extern "c" fn clay_init(width: c_int, height: c_int) void;
    pub extern "c" fn clay_cleanup() void;
    pub extern "c" fn clay_set_text_measurement() void;
    pub extern "c" fn clay_layout_status_bar(width: c_int, height: c_int) c_int;
    pub extern "c" fn clay_layout_center_card(width: c_int, height: c_int) c_int;
    pub extern "c" fn clay_layout_dock(width: c_int, height: c_int, icon_count: c_int) c_int;
    pub extern "c" fn clay_layout_launcher(width: c_int, height: c_int, scroll: c_int) c_int;
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
    pub extern "c" fn clay_cmd_img(i: c_int) ?*c.BLImageCore;
    pub extern "c" fn clay_cmd_clip_x(i: c_int) f32;
    pub extern "c" fn clay_cmd_clip_y(i: c_int) f32;
    pub extern "c" fn clay_cmd_clip_w(i: c_int) f32;
    pub extern "c" fn clay_cmd_clip_h(i: c_int) f32;
};
