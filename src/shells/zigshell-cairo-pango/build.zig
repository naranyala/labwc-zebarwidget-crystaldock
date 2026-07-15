const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const c_flags: []const []const u8 = &.{ "-std=gnu11", "-Wall" };

    // === zigshell-cairo-pango (merged panel + dock) ===
    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/main_shell.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const exe = b.addExecutable(.{
        .name = "zigshell-cairo-pango",
        .root_module = root_mod,
    });

    linkDeps(root_mod, b);
    addProtocolSources(root_mod, b, c_flags);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run zigshell-cairo-pango");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const exe_unit_tests = b.addTest(.{
        .root_module = root_mod,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

fn linkDeps(root_mod: *std.Build.Module, b: *std.Build) void {
    root_mod.linkSystemLibrary("wayland-client", .{});
    root_mod.linkSystemLibrary("cairo", .{});
    root_mod.linkSystemLibrary("pangocairo-1.0", .{});
    root_mod.linkSystemLibrary("pango-1.0", .{});
    root_mod.linkSystemLibrary("glib-2.0", .{});
    root_mod.linkSystemLibrary("gobject-2.0", .{});
    root_mod.linkSystemLibrary("gio-2.0", .{});
    root_mod.linkSystemLibrary("librsvg-2.0", .{});
    root_mod.addIncludePath(b.path("src"));
    root_mod.addIncludePath(b.path("."));
}

fn addProtocolSources(root_mod: *std.Build.Module, b: *std.Build, c_flags: []const []const u8) void {
    root_mod.addCSourceFile(.{
        .file = b.path("src/dock_c_impl.c"),
        .flags = c_flags,
    });
    root_mod.addCSourceFile(.{
        .file = b.path("wlr-layer-shell-unstable-v1-client-protocol.c"),
        .flags = c_flags,
    });
    root_mod.addCSourceFile(.{
        .file = b.path("wlr-foreign-toplevel-management-unstable-v1-client-protocol.c"),
        .flags = c_flags,
    });
    root_mod.addCSourceFile(.{
        .file = b.path("xdg-shell-client-protocol.c"),
        .flags = c_flags,
    });
}
