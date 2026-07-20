// log_test.zig — niche cases for the shared shell logging level parser.
//
// `parseLevel` maps a ZIGSHELL_LOG value to a std.log.Level. These tests
// pin its case-insensitivity, alias handling, and default fallback so a bad
// env value can never raise the log ceiling unintentionally.

const std = @import("std");
const testing = std.testing;

const log = @import("log.zig");
const Level = std.log.Level;

test "parseLevel: exact lowercase names" {
    try testing.expectEqual(Level.err, log.parseLevel("err", .info));
    try testing.expectEqual(Level.warn, log.parseLevel("warn", .info));
    try testing.expectEqual(Level.info, log.parseLevel("info", .debug));
    try testing.expectEqual(Level.debug, log.parseLevel("debug", .info));
}

test "parseLevel: aliases error/warning" {
    try testing.expectEqual(Level.err, log.parseLevel("error", .info));
    try testing.expectEqual(Level.warn, log.parseLevel("warning", .info));
}

test "parseLevel: case-insensitive" {
    try testing.expectEqual(Level.debug, log.parseLevel("DEBUG", .info));
    try testing.expectEqual(Level.err, log.parseLevel("ERR", .info));
    try testing.expectEqual(Level.warn, log.parseLevel("Warning", .info));
}

test "parseLevel: garbage and empty fall back to default" {
    try testing.expectEqual(Level.info, log.parseLevel("verbose", .info));
    try testing.expectEqual(Level.debug, log.parseLevel("loud", .debug));
    try testing.expectEqual(Level.info, log.parseLevel("", .info));
    // Accidental whitespace-padded value should not silently raise the level.
    try testing.expectEqual(Level.info, log.parseLevel(" debug ", .info));
}
