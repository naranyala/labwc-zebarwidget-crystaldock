const std = @import("std");
pub fn main() !void {
    for (std.os.argv, 0..) |arg, i| {
        std.debug.print("{s}\n", .{arg});
    }
}
