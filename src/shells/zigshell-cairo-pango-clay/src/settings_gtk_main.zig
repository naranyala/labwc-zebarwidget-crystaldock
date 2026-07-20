const std = @import("std");

// Thin Zig entry point for the out-of-process GTK settings app. The real
// implementation lives in settings_gtk.c (compiled and linked into this exe);
// we just forward into it. Keeping the C `main` as `gtk_settings_main` avoids a
// symbol clash with Zig's own `main`. GTK accepts argc=0/argv=null.
extern fn gtk_settings_main(argc: c_int, argv: [*c][*c]u8) c_int;

pub fn main() void {
    _ = gtk_settings_main(0, null);
}
