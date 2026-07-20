const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const c_flags: []const []const u8 = &.{ "-std=gnu11", "-Wall", "-O2" };

    // ---- Step 1: Build Blend2D via CMake ----
    const cmake_configure = b.addSystemCommand(&.{
        "cmake", "-B", "../zigshell-blend2d/build/deps",
        "-S", "../zigshell-blend2d",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DBLEND2D_NO_JIT=ON",
    });
    const cmake_build = b.addSystemCommand(&.{
        "make", "-C", "../zigshell-blend2d/build/deps",
        "blend2d", "-j4",
    });
    cmake_build.step.dependOn(&cmake_configure.step);

    // ---- Step 2: Build the test binary ----
    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // Shared shellcore module (toplevel info, damage tracking)
    const shellcore = b.createModule(.{
        .root_source_file = b.path("../shared/shellcore.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    root_mod.addImport("shellcore", shellcore);

    // Include paths
    root_mod.addIncludePath(b.path("../zigshell-blend2d/src"));
    root_mod.addIncludePath(b.path("../zigshell-blend2d/deps/blend2d"));
    root_mod.addIncludePath(b.path("../../../sources/clay"));
    root_mod.addIncludePath(b.path("../shared/protocol"));

    // Library paths
    root_mod.addLibraryPath(b.path("../zigshell-blend2d/build/deps/blend2d"));

    // Link libraries
    root_mod.linkSystemLibrary("blend2d", .{});
    root_mod.linkSystemLibrary("stdc++", .{});
    root_mod.linkSystemLibrary("m", .{});

    // C flags with include paths for the C compiler
    const c_flags_incl = &[_][]const u8{
        "-std=gnu11", "-O2",
        "-Wno-unused-variable", "-Wno-unused-but-set-variable",
        "-Wno-unused-function", "-Wno-sign-compare",
        "-I../../../sources/clay",
        "-I../zigshell-blend2d/src",
        "-I../zigshell-blend2d/deps/blend2d",
        "-I../shared/protocol",
    };

    // C sources
    root_mod.addCSourceFile(.{
        .file = b.path("src/clay_layout.c"),
        .flags = c_flags_incl,
    });
    root_mod.addCSourceFile(.{
        .file = b.path("src/dock_clay_layout.c"),
        .flags = c_flags_incl,
    });
    root_mod.addCSourceFile(.{
        .file = b.path("../zigshell-blend2d/src/blend2d_render.c"),
        .flags = c_flags,
    });

    const exe = b.addExecutable(.{
        .name = "zigshell-blend2d-clay",
        .root_module = root_mod,
    });
    exe.step.dependOn(&cmake_build.step);
    b.installArtifact(exe);

    // ---- Run step ----
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run zigshell-blend2d-clay test");
    run_step.dependOn(&run_cmd.step);

    // ---- Test step ----
    const test_step = b.step("test", "Build and run Clay+Blend2D test");
    test_step.dependOn(&run_cmd.step);
}
