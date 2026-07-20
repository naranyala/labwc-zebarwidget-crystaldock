const std = @import("std");
const process = std.process;

extern "c" fn printf(format: [*:0]const u8, ...) c_int;
extern "c" fn fprintf(file: ?*anyopaque, format: [*:0]const u8, ...) c_int;
extern "c" fn strcmp(s1: [*:0]const u8, s2: [*:0]const u8) c_int;
extern "c" fn fork() c_int;
extern "c" fn execvp(file: [*:0]const u8, argv: [*:null]const ?[*:0]const u8) c_int;
extern "c" fn execlp(file: [*:0]const u8, ...) c_int;
extern "c" fn waitpid(pid: c_int, status: *c_int, options: c_int) c_int;
extern "c" fn access(path: [*:0]const u8, mode: c_int) c_int;
extern "c" fn mkdir(path: [*:0]const u8, mode: c_uint) c_int;
extern "c" fn getenv(name: [*:0]const u8) ?[*:0]const u8;
extern "c" fn _exit(status: c_int) noreturn;

extern const stderr: ?*anyopaque;
const F_OK = 0;
const WNOHANG = 1;

fn WIFEXITED(status: c_int) bool {
    return (status & 0x7f) == 0;
}

fn WEXITSTATUS(status: c_int) c_int {
    return (status >> 8) & 0xff;
}

const VERSION = "0.2.0";

const Subcommand = struct {
    name: [*:0]const u8,
    description: [*:0]const u8,
    builtin: bool,
};

const subcommands = [_]Subcommand{
    // GUI apps
    .{ .name = "settings", .description = "GTK3 settings GUI", .builtin = false },
    .{ .name = "theme-center", .description = "Theme browser with live preview", .builtin = false },
    .{ .name = "fonts-mgr", .description = "Font manager with install/preview", .builtin = false },
    .{ .name = "dock-mgr", .description = "Dock layout manager", .builtin = false },
    .{ .name = "dotdesktop-mgr", .description = "Desktop entry manager", .builtin = false },
    .{ .name = "pkgmgr", .description = "Package manager frontend", .builtin = false },
    .{ .name = "welcome", .description = "First-run setup wizard", .builtin = false },
    .{ .name = "workspace-mgr", .description = "Virtual desktop kanban", .builtin = false },
    .{ .name = "llm-runner", .description = "Local LLM chat interface", .builtin = false },
    .{ .name = "equalizer", .description = "10-band graphic EQ with FFT visualizer", .builtin = false },
    .{ .name = "equalizer-gl", .description = "OpenGL-accelerated equalizer", .builtin = false },
    .{ .name = "equalizer-qs", .description = "Quick-settings equalizer backend", .builtin = false },
    .{ .name = "speaker-gl", .description = "OpenGL speaker visualization", .builtin = false },
    .{ .name = "speaker-qs", .description = "Quick-settings speaker backend", .builtin = false },
    .{ .name = "waveform-gl", .description = "OpenGL waveform viewer", .builtin = false },
    .{ .name = "waveform-qs", .description = "Quick-settings waveform backend", .builtin = false },
    .{ .name = "datetime", .description = "Floating date/time display", .builtin = false },
    .{ .name = "snake-game", .description = "Classic snake game overlay", .builtin = false },
    .{ .name = "todomvc", .description = "TODO MVC demo app", .builtin = false },
    .{ .name = "wallpaper-picker", .description = "Wallpaper browser and picker", .builtin = false },
    // CLI utils
    .{ .name = "shot", .description = "Screenshot tool (grim + slurp)", .builtin = false },
    .{ .name = "clip", .description = "Clipboard manager (cliphist + fuzzel)", .builtin = false },
    .{ .name = "lock", .description = "Screen lock wrapper (swaylock)", .builtin = false },
    .{ .name = "sysmon", .description = "System metrics (CPU/mem/net/bat)", .builtin = false },
    .{ .name = "brightness", .description = "Smooth backlight control", .builtin = false },
    .{ .name = "volume", .description = "Smooth PulseAudio control", .builtin = false },
    .{ .name = "recorder", .description = "Screen recording (wf-recorder)", .builtin = false },
    .{ .name = "emit", .description = "Event Bus API for UI state", .builtin = false },
    .{ .name = "search", .description = "Web query search with fuzzel", .builtin = false },
    .{ .name = "kv", .description = "Key-value persistent store", .builtin = false },
    .{ .name = "color", .description = "Wallpaper palette extraction", .builtin = false },
    .{ .name = "ocr", .description = "Screen OCR (Tesseract)", .builtin = false },
    .{ .name = "validate", .description = "System configuration validator", .builtin = false },
    .{ .name = "fonts", .description = "Font management CLI", .builtin = false },
    .{ .name = "tooltip", .description = "Tooltip utility", .builtin = false },
    .{ .name = "tray", .description = "System tray", .builtin = false },
    .{ .name = "network-bandwidth", .description = "Network bandwidth monitor", .builtin = false },
    // Daemons
    .{ .name = "notify", .description = "Native D-Bus notification daemon", .builtin = false },
    .{ .name = "wallpaper", .description = "Time-of-day wallpaper transitions", .builtin = false },
    .{ .name = "live-bg", .description = "Animated live background", .builtin = false },
    .{ .name = "osd-notify", .description = "Glassmorphic notification popup", .builtin = false },
    .{ .name = "hypertile", .description = "Dynamic tiling for labwc", .builtin = false },
    .{ .name = "brokerd", .description = "C-native event bus daemon", .builtin = false },
    .{ .name = "gestured", .description = "Gesture daemon", .builtin = false },
    // Built-in
    .{ .name = "help", .description = "Show this help message", .builtin = true },
};

fn eql(a: [*:0]const u8, b: [*:0]const u8) bool {
    return strcmp(a, b) == 0;
}

fn bufPrintZ(buf: []u8, comptime fmt: []const u8, args: anytype) [*:0]const u8 {
    return std.fmt.bufPrintZ(buf, fmt, args) catch unreachable;
}

fn printHelp() void {
    _ = printf(
        \\ocws — Our C-Written Shell (unified harness) v0.2.0
        \\
        \\Usage: ocws <subcommand> [args...]
        \\
    );
    for (subcommands) |sc| {
        if (sc.builtin) continue;
        _ = printf("  %-20s %s\n", sc.name, sc.description);
    }
    _ = printf(
        \\
        \\Built-in:
        \\  ocws status            Show system status
        \\  ocws rebuild           Rebuild all C utilities
        \\  ocws install           Build and install to ~/.local/bin/
        \\  ocws list              List all available binaries
        \\  ocws version           Show version info
        \\  ocws help              Show this help message
        \\
    );
}

fn printVersion() void {
    _ = printf("ocws %s\n", VERSION);
}

fn execExternal(name: [*:0]const u8, argc: c_int, argv: [*c][*:0]const u8) void {
    const pid = fork();
    if (pid == 0) {
        var new_argv_buf: [65]?[*:0]const u8 = undefined;
        var i: usize = 1;
        var j: usize = 2;
        while (j < @as(usize, @intCast(argc))) : (j += 1) {
            if (i >= 63) break;
            new_argv_buf[i] = argv[j];
            i += 1;
        }
        new_argv_buf[i] = null;
        const new_argv: [*:null]const ?[*:0]const u8 = @ptrCast(&new_argv_buf);

        var buf_local: [256]u8 = undefined;
        var buf_zig: [256]u8 = undefined;
        var buf_cmd: [256]u8 = undefined;

        const cmd = bufPrintZ(&buf_cmd, "ocws-{s}", .{name});
        new_argv_buf[0] = cmd;

        const path_zig = bufPrintZ(&buf_zig, "zig-out/bin/ocws-{s}", .{name});
        if (access(path_zig, F_OK) == 0) {
            _ = execvp(path_zig, new_argv);
        }

        const home = getenv("HOME");
        if (home != null) {
            const home_span = std.mem.span(home.?);
            const path_local = bufPrintZ(&buf_local, "{s}/.local/bin/ocws-{s}", .{home_span, name});
            if (access(path_local, F_OK) == 0) {
                _ = execvp(path_local, new_argv);
            }
        }

        // Fallback to searching PATH
        _ = execvp(cmd, new_argv);

        _ = fprintf(stderr, "ocws: command not found: %s\n", name);
        _exit(1);
    } else if (pid > 0) {
        var status: c_int = 0;
        _ = waitpid(pid, &status, 0);
        if (WIFEXITED(status)) {
            _exit(WEXITSTATUS(status));
        } else {
            _exit(1);
        }
    } else {
        _ = fprintf(stderr, "ocws: fork failed\n");
    }
}

fn printGodStatus() void {
    _ = printf("ocws: system status\n");
    _ = printf("  Version: %s\n", VERSION);
    _ = printf("  Binaries:\n");

    const home = getenv("HOME");
    const home_span = if (home != null) std.mem.span(home.?) else "";

    for (subcommands) |sc| {
        if (!sc.builtin) {
            var buf_zig: [256]u8 = undefined;
            const path_zig = bufPrintZ(&buf_zig, "zig-out/bin/ocws-{s}", .{sc.name});
            
            var buf_local: [512]u8 = undefined;
            const path_local = if (home != null) bufPrintZ(&buf_local, "{s}/.local/bin/ocws-{s}", .{home_span, sc.name}) else "";

            if (access(path_zig, F_OK) == 0) {
                _ = printf("    \x1b[32m✓\x1b[0m ocws-%s (zig-out)\n", sc.name);
            } else if (home != null and access(path_local, F_OK) == 0) {
                _ = printf("    \x1b[32m✓\x1b[0m ocws-%s (~/.local/bin)\n", sc.name);
            } else {
                _ = printf("    \x1b[31m✗\x1b[0m ocws-%s (not built in default paths)\n", sc.name);
            }
        }
    }
}

fn runGodRebuild() void {
    _ = printf("ocws: rebuilding all C utilities...\n");
    const pid = fork();
    if (pid == 0) {
        _ = execlp("zig", "zig", "build", @as(?[*:0]const u8, null));
        _exit(1);
    } else if (pid > 0) {
        var status: c_int = 0;
        _ = waitpid(pid, &status, 0);
        if (WIFEXITED(status) and WEXITSTATUS(status) == 0) {
            _ = printf("ocws: rebuild successful\n");
        } else {
            _ = fprintf(stderr, "ocws: rebuild failed\n");
        }
    }
}

fn runGodInstall() void {
    _ = printf("ocws: building release and installing to ~/.local/bin/\n");

    const pid = fork();
    if (pid == 0) {
        _ = execlp("zig", "zig", "build", "-Doptimize=ReleaseFast", @as(?[*:0]const u8, null));
        _exit(1);
    } else if (pid > 0) {
        var status: c_int = 0;
        _ = waitpid(pid, &status, 0);
        if (!WIFEXITED(status) or WEXITSTATUS(status) != 0) {
            _ = fprintf(stderr, "ocws: build failed\n");
            return;
        }
    }

    const home = getenv("HOME");
    if (home == null) {
        _ = fprintf(stderr, "ocws: HOME not set\n");
        return;
    }

    var hbuf: [512]u8 = undefined;
    const home_span = std.mem.span(home.?);
    const bin_dir_path = bufPrintZ(&hbuf, "{s}/.local/bin", .{home_span});
    _ = mkdir(bin_dir_path, 0o755);

    for (subcommands) |sc| {
        if (!sc.builtin) {
            var src_buf: [128]u8 = undefined;
            const src = bufPrintZ(&src_buf, "zig-out/bin/ocws-{s}", .{sc.name});
            var dst_buf: [128]u8 = undefined;
            const dst = bufPrintZ(&dst_buf, "{s}/.local/bin/ocws-{s}", .{ home_span, sc.name });
            const cp_pid = fork();
            if (cp_pid == 0) {
                _ = execlp("cp", "cp", src, dst, @as(?[*:0]const u8, null));
                _exit(1);
            } else if (cp_pid > 0) {
                var st: c_int = 0;
                _ = waitpid(cp_pid, &st, 0);
            }
        }
    }

    const cp_pid = fork();
    if (cp_pid == 0) {
        _ = execlp("cp", "cp", "zig-out/bin/ocws", bin_dir_path, @as(?[*:0]const u8, null));
        _exit(1);
    } else if (cp_pid > 0) {
        var st: c_int = 0;
        _ = waitpid(cp_pid, &st, 0);
    }

    _ = printf("ocws: installed to %s\n", bin_dir_path);
}

fn runList() void {
    _ = printf("ocws: available binaries:\n");
    for (subcommands) |sc| {
        if (!sc.builtin) {
            _ = printf("  ocws-%s\n", sc.name);
        }
    }
}

fn runAdmin(argc: c_int, argv: [*c][*:0]const u8) void {
    if (argc <= 2) {
        printHelp();
        return;
    }

    const cmd = argv[2];
    if (eql(cmd, "help") or eql(cmd, "--help") or eql(cmd, "-h")) {
        printHelp();
    } else if (eql(cmd, "status")) {
        printGodStatus();
    } else if (eql(cmd, "rebuild")) {
        runGodRebuild();
    } else if (eql(cmd, "install")) {
        runGodInstall();
    } else if (eql(cmd, "list")) {
        runList();
    } else {
        _ = fprintf(stderr, "ocws: unknown command: %s\n", cmd);
        printHelp();
    }
}

pub fn main(init: process.Init) void {
    const argc: c_int = @intCast(init.minimal.args.vector.len);
    const argv_ptr: [*c][*:0]const u8 = @ptrCast(@constCast(init.minimal.args.vector.ptr));

    if (argc <= 1) {
        printHelp();
        return;
    }

    const subcmd = argv_ptr[1];

    if (eql(subcmd, "help") or eql(subcmd, "--help") or eql(subcmd, "-h")) {
        printHelp();
    } else if (eql(subcmd, "version") or eql(subcmd, "--version") or eql(subcmd, "-v")) {
        printVersion();
    } else if (eql(subcmd, "status")) {
        printGodStatus();
    } else if (eql(subcmd, "rebuild")) {
        runGodRebuild();
    } else if (eql(subcmd, "install")) {
        runGodInstall();
    } else if (eql(subcmd, "list")) {
        runList();
    } else {
        execExternal(subcmd, argc, argv_ptr);
    }
}
