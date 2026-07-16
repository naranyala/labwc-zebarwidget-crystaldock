const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const c_flags = &[_][]const u8{
        "-std=gnu11",
        "-Wall",
        "-Wextra",
        "-Wno-deprecated-declarations",
        "-O2",
        "-Isrc/gui",
        "-Isrc/libocws",
    };

    // ocws-equalizer: GTK3 audio equalizer with 10-band EQ, presets, and FFT visualizer
    {
        const exe = b.addExecutable(.{
            .name = "ocws-equalizer",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });

        exe.root_module.addCSourceFile(.{ .file = b.path("src/gui/ocws-equalizer.c"), .flags = c_flags });
        exe.root_module.addCSourceFile(.{ .file = b.path("src/libocws/audio_analysis.c"), .flags = c_flags });
        exe.root_module.addCSourceFile(.{ .file = b.path("src/libocws/audio_stream.c"), .flags = c_flags });

        exe.root_module.linkSystemLibrary("gtk+-3.0", .{});
        exe.root_module.linkSystemLibrary("glib-2.0", .{});
        exe.root_module.linkSystemLibrary("pulse", .{});
        exe.root_module.linkSystemLibrary("pulse-simple", .{});
        exe.root_module.linkSystemLibrary("fftw3", .{});
        exe.root_module.linkSystemLibrary("m", .{});
        exe.root_module.linkSystemLibrary("ayatana-appindicator3-0.1", .{});

        b.installArtifact(exe);
        const step = b.step("ocws-equalizer", "Build the OCWS Equalizer");
        step.dependOn(&exe.step);
    }

    // Build system unification for C GUI apps
    _ = buildGtkApp(b, target, optimize, "ocws-settings", &.{
        "src/gui/ocws-settings.c",
        "src/gui/settings/settings-ui.c",
        "src/gui/settings/settings-tabs.c",
        "src/core/utils.c",
    });
    
    _ = buildGtkApp(b, target, optimize, "ocws-welcome", &.{
        "src/gui/ocws-welcome.c",
        "src/core/utils.c",
    });

    const ws_exe = buildGtkApp(b, target, optimize, "ocws-workspace-mgr", &.{
        "src/gui/ocws-workspace-mgr.c",
        "src/core/utils.c",
        "protocols/wlr-foreign-toplevel-management-unstable-v1-client.c",
    });
    ws_exe.root_module.linkSystemLibrary("wayland-client", .{});

    _ = buildGtkApp(b, target, optimize, "ocws-theme-center", &.{
        "src/gui/ocws-theme-center.c",
        "src/core/utils.c",
    });
}

fn buildGtkApp(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
    c_sources: []const []const u8,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    const c_flags = &[_][]const u8{
        "-std=gnu11",
        "-Wall",
        "-O2",
        "-Isrc/gui",
        "-Isrc/libocws",
        "-Isrc/core",
        "-Iprotocols",
    };

    for (c_sources) |src| {
        exe.root_module.addCSourceFile(.{ .file = b.path(src), .flags = c_flags });
    }

    exe.root_module.linkSystemLibrary("gtk+-3.0", .{});
    exe.root_module.linkSystemLibrary("glib-2.0", .{});

    b.installArtifact(exe);
    const step = b.step(name, b.fmt("Build {s}", .{name}));
    step.dependOn(&exe.step);

    return exe;
}
