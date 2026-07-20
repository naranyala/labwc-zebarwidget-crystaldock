// log.zig — Shared logging configuration for the zigshell shells.
//
// Provides an env-controlled log level so both the cairo-pango and blend2d
// shells emit consistent, runtime-tunable diagnostics. The actual formatting
// is delegated to std.log.defaultLog (which handles the Zig 0.16 terminal I/O
// plumbing and colour tags); this module only adds a runtime severity gate.
//
// Usage in each shell's root source file (main_shell.zig):
//
//     const shlog = @import("log");
//     pub const std_options: std.Options = .{
//         .log_level = .debug,   // compile-time ceiling; runtime gate below
//         .logFn = shlog.logFn,
//     };
//
// Runtime verbosity is controlled by the ZIGSHELL_LOG environment variable:
//   ZIGSHELL_LOG=err    -> only errors
//   ZIGSHELL_LOG=warn   -> warnings + errors
//   ZIGSHELL_LOG=info   -> info + warn + err (default in release)
//   ZIGSHELL_LOG=debug  -> everything (default in debug builds)
//
// The env value is read once, lazily, on the first log call.

const std = @import("std");
const builtin = @import("builtin");

var cached_level: ?std.log.Level = null;

/// Map a ZIGSHELL_LOG string to a severity. Case-insensitive, tolerant of
/// "error"/"warning" aliases. Unknown/unset values fall back to `default`.
pub fn parseLevel(raw: []const u8, default: std.log.Level) std.log.Level {
    if (raw.len == 0) return default;
    return if (std.ascii.eqlIgnoreCase(raw, "err") or std.ascii.eqlIgnoreCase(raw, "error"))
        .err
    else if (std.ascii.eqlIgnoreCase(raw, "warn") or std.ascii.eqlIgnoreCase(raw, "warning"))
        .warn
    else if (std.ascii.eqlIgnoreCase(raw, "info"))
        .info
    else if (std.ascii.eqlIgnoreCase(raw, "debug"))
        .debug
    else
        default;
}

fn envLevel() std.log.Level {
    if (cached_level) |lvl| return lvl;
    const default: std.log.Level = if (builtin.mode == .Debug) .debug else .info;
    const raw_ptr = std.c.getenv("ZIGSHELL_LOG") orelse {
        cached_level = default;
        return default;
    };
    const raw = std.mem.sliceTo(raw_ptr, 0);
    const lvl = parseLevel(raw, default);
    cached_level = lvl;
    return lvl;
}

/// Custom log function: gates by the runtime ZIGSHELL_LOG level, then forwards
/// to the standard library formatter. Lower enum value == higher severity, so
/// a message is emitted only when its level is at or above the active gate.
pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@intFromEnum(level) > @intFromEnum(envLevel())) return;
    std.log.defaultLog(level, scope, format, args);
}
