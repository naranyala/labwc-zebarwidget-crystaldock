const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // Include paths (relative to this build.zig location)
    root_mod.addIncludePath(b.path("../../../../sources/clay"));
    // Cairo/Pango system include paths for @cImport
    root_mod.addIncludePath(.{ .cwd_relative = "/usr/include/cairo" });
    root_mod.addIncludePath(.{ .cwd_relative = "/usr/include/pango-1.0" });
    root_mod.addIncludePath(.{ .cwd_relative = "/usr/include/glib-2.0" });
    root_mod.addIncludePath(.{ .cwd_relative = "/usr/lib64/glib-2.0/include" });
    root_mod.addIncludePath(.{ .cwd_relative = "/usr/include/harfbuzz" });
    root_mod.addIncludePath(.{ .cwd_relative = "/usr/include/freetype2" });
    root_mod.addIncludePath(.{ .cwd_relative = "/usr/include/libpng16" });
    root_mod.addIncludePath(.{ .cwd_relative = "/usr/include/pixman-1" });

    // Link libraries
    root_mod.linkSystemLibrary("cairo", .{});
    root_mod.linkSystemLibrary("pangocairo-1.0", .{});
    root_mod.linkSystemLibrary("pango-1.0", .{});
    root_mod.linkSystemLibrary("glib-2.0", .{});
    root_mod.linkSystemLibrary("m", .{});

    // C sources
    const c_flags_incl = &[_][]const u8{
        "-std=gnu11", "-O2",
        "-Wno-unused-variable", "-Wno-unused-but-set-variable",
        "-Wno-unused-function", "-Wno-sign-compare",
        "-I../../../../sources/clay",
    };

    root_mod.addCSourceFile(.{
        .file = b.path("src/clay_layout.c"),
        .flags = c_flags_incl,
    });

    const exe = b.addExecutable(.{
        .name = "test-clay-cairo",
        .root_module = root_mod,
    });
    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run Clay+Cairo test");
    run_step.dependOn(&run_cmd.step);

    // Test step
    const test_step = b.step("test", "Build and run Clay+Cairo test");
    test_step.dependOn(&run_cmd.step);
}
