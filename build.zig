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
        "-Isrc",
        "-Isrc/gui",
        "-Isrc/libocws",
        "-Isrc/core",
        "-Iprotocols",
        "-Ilibs/tinyfiledialogs",
        "-Ilibs/tray",
    };

    // ====================================================================
    // Main entry point (ocws unified harness)
    // ====================================================================
    {
        const mod = b.createModule(.{
            .root_source_file = b.path("src/ocws.zig"),
            .target = target,
            .optimize = optimize,
        });
        mod.link_libc = true;
        const exe = b.addExecutable(.{
            .name = "ocws",
            .root_module = mod,
        });
        b.installArtifact(exe);
        const step = b.step("ocws", "Build the unified ocws harness");
        step.dependOn(&exe.step);
    }

    // ====================================================================
    // GTK3 GUI apps
    // ====================================================================

    // ocws-equalizer: GTK3 audio equalizer with 10-band EQ, presets, and FFT visualizer
    _ = buildGtkApp(b, target, optimize, c_flags, "ocws-equalizer", &.{
        "src/gui/ocws-equalizer.c",
        "src/libocws/audio_analysis.c",
        "src/libocws/audio_stream.c",
    }, &.{ "pulse", "pulse-simple", "fftw3", "m", "ayatana-appindicator3-0.1" }, &.{});

    _ = buildGtkApp(b, target, optimize, c_flags, "ocws-settings", &.{
        "src/gui/ocws-settings.c",
        "src/gui/settings/settings-ui.c",
        "src/gui/settings/settings-tabs.c",
        "src/core/utils.c",
    }, &.{"xml2"}, &.{"/usr/include/libxml2"});

    _ = buildGtkApp(b, target, optimize, c_flags, "ocws-welcome", &.{
        "src/gui/ocws-welcome.c",
        "src/core/utils.c",
    }, &.{}, &.{});

    _ = buildGtkApp(b, target, optimize, c_flags, "ocws-workspace-mgr", &.{
        "src/gui/ocws-workspace-mgr.c",
        "src/core/utils.c",
        "protocols/wlr-foreign-toplevel-management-unstable-v1-client.c",
    }, &.{"wayland-client"}, &.{});

    _ = buildGtkApp(b, target, optimize, c_flags, "ocws-theme-center", &.{
        "src/gui/ocws-theme-center.c",
        "src/core/utils.c",
    }, &.{}, &.{});

    _ = buildGtkApp(b, target, optimize, c_flags, "ocws-datetime", &.{"src/gui/ocws-datetime.c"}, &.{}, &.{});
    _ = buildGtkApp(b, target, optimize, c_flags, "ocws-snake-game", &.{"src/gui/ocws-snake-game.c"}, &.{}, &.{});
    _ = buildGtkApp(b, target, optimize, c_flags, "ocws-todomvc", &.{"src/gui/ocws-todomvc.c"}, &.{}, &.{});

    _ = buildGtkApp(b, target, optimize, c_flags, "ocws-llm-runner", &.{"src/gui/ocws-llm-runner.c"}, &.{"json-c"}, &.{});
    _ = buildGtkApp(b, target, optimize, c_flags, "ocws-dotdesktop-mgr", &.{"src/gui/ocws-dotdesktop-mgr.c"}, &.{"gio-2.0"}, &.{});
    _ = buildGtkApp(b, target, optimize, c_flags, "ocws-pkgmgr", &.{"src/gui/ocws-pkgmgr.c"}, &.{"gio-2.0"}, &.{});

    _ = buildGtkApp(b, target, optimize, c_flags, "ocws-fonts-mgr", &.{
        "src/gui/ocws-fonts-mgr/fonts-mgr.c",
        "src/gui/ocws-fonts-mgr/fonts-mgr-common.c",
        "src/gui/ocws-fonts-mgr/fonts-mgr-fonts.c",
        "src/gui/ocws-fonts-mgr/fonts-mgr-installer.c",
        "src/gui/ocws-fonts-mgr/fonts-mgr-preview.c",
        "src/gui/ocws-fonts-mgr/fonts-mgr-ui.c",
        "src/core/ocws-fonts.c",
    }, &.{"gio-2.0"}, &.{});

    _ = buildGtkApp(b, target, optimize, c_flags, "ocws-dock-mgr", &.{"src/gui/ocws-dock-mgr.c"}, &.{"json-c"}, &.{});

    // ====================================================================
    // OpenGL GUI apps (gtk+-3.0 + epoxy + pulse + audio_dsp)
    // ====================================================================

    _ = buildGtkApp(b, target, optimize, c_flags, "ocws-equalizer-gl", &.{
        "src/gui/ocws-equalizer-gl.c",
        "src/libocws/audio_dsp.c",
    }, &.{ "epoxy", "libpulse-simple", "m", "pthread", "gtk-layer-shell" }, &.{});

    _ = buildGtkApp(b, target, optimize, c_flags, "ocws-waveform-gl", &.{
        "src/gui/ocws-waveform-gl.c",
        "src/libocws/audio_dsp.c",
    }, &.{ "epoxy", "libpulse-simple", "m", "pthread", "gtk-layer-shell" }, &.{});

    // ocws-audio-gl / ocws-audio-qs: OpenGL speaker visualization (GTK4-only)
    // GTK4 not installed — disabled until gtk4 is available on the system.

    // ====================================================================
    // Audio-only QS backends (no GTK)
    // ====================================================================

    _ = buildCliApp(b, target, optimize, c_flags, "ocws-equalizer-qs", &.{
        "src/gui/ocws-equalizer-qs.c",
        "src/libocws/audio_dsp.c",
    }, &.{ "libpulse-simple", "m" });

    _ = buildCliApp(b, target, optimize, c_flags, "ocws-waveform-qs", &.{
        "src/gui/ocws-waveform-qs.c",
        "src/libocws/audio_dsp.c",
    }, &.{ "libpulse-simple", "m" });

    // ====================================================================
    // Layer-shell daemons
    // ====================================================================

    _ = buildGtkApp(b, target, optimize, c_flags, "ocws-live-bg", &.{"src/daemons/ocws-live-bg.c"}, &.{ "gtk-layer-shell", "cairo", "m" }, &.{});
    _ = buildGtkApp(b, target, optimize, c_flags, "ocws-osd-notify", &.{"src/daemons/ocws-osd-notify.c"}, &.{ "gio-2.0", "gtk-layer-shell" }, &.{});

    // ====================================================================
    // Wallpaper picker (tinyfiledialogs)
    // ====================================================================

    {
        const exe = b.addExecutable(.{
            .name = "ocws-wallpaper-picker",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });
        exe.root_module.addCSourceFile(.{ .file = b.path("src/gui/ocws-wallpaper-picker.c"), .flags = c_flags });
        exe.root_module.addCSourceFile(.{ .file = b.path("libs/tinyfiledialogs/tinyfiledialogs.c"), .flags = c_flags });
        b.installArtifact(exe);
        const step = b.step("ocws-wallpaper-picker", "Build wallpaper picker");
        step.dependOn(&exe.step);
    }

    // ====================================================================
    // Simple CLI apps (stdlib only, no extra libs)
    // ====================================================================

    const simple_cli_apps = [_]struct { name: []const u8, src: []const u8 }{
        .{ .name = "ocws-clip", .src = "src/cli/ocws-clip.c" },
        .{ .name = "ocws-emit", .src = "src/cli/ocws-emit.c" },
        .{ .name = "ocws-lock", .src = "src/cli/ocws-lock.c" },
        .{ .name = "ocws-network-bandwidth", .src = "src/cli/ocws-network-bandwidth.c" },
        .{ .name = "ocws-player", .src = "src/cli/ocws-player.c" },
        .{ .name = "ocws-plugin", .src = "src/cli/ocws-plugin.c" },
        .{ .name = "ocws-search", .src = "src/cli/ocws-search.c" },
        .{ .name = "ocws-shot", .src = "src/cli/ocws-shot.c" },
        .{ .name = "ocws-state", .src = "src/cli/ocws-state.c" },
        .{ .name = "ocws-style", .src = "src/cli/ocws-style.c" },
        .{ .name = "ocws-sysmon", .src = "src/cli/ocws-sysmon.c" },
        .{ .name = "ocws-recorder", .src = "src/cli/ocws-recorder.c" },
        .{ .name = "ocws-gestured", .src = "src/daemons/ocws-gestured.c" },
    };
    inline for (simple_cli_apps) |app| {
        _ = buildCliApp(b, target, optimize, c_flags, app.name, &.{app.src}, &.{});
    }

    // ====================================================================
    // CLI apps with extra library deps
    // ====================================================================

    _ = buildCliApp(b, target, optimize, c_flags, "ocws-color", &.{"src/cli/ocws-color.c"}, &.{"cairo"});
    _ = buildCliApp(b, target, optimize, c_flags, "ocws-brightness", &.{"src/cli/ocws-brightness.c"}, &.{"m"});
    _ = buildCliApp(b, target, optimize, c_flags, "ocws-volume", &.{"src/cli/ocws-volume.c"}, &.{"m"});

    // ocws-ocr: requires tesseract + leptonica — not installed on this system.
    // Uncomment and install libtesseract-dev/libleptonica-dev to enable.
    // _ = buildCliApp(b, target, optimize, c_flags, "ocws-ocr", &.{"src/cli/ocws-ocr.c"}, &.{ "tesseract", "leptonica" });

    // ====================================================================
    // CLI apps with other source dependencies
    // ====================================================================

    _ = buildCliApp(b, target, optimize, c_flags, "ocws-kv", &.{
        "src/cli/ocws-kv.c",
        "src/core/ocws-kv.c",
    }, &.{});

    _ = buildCliApp(b, target, optimize, c_flags, "ocws-fonts", &.{
        "src/cli/ocws-fonts.c",
        "src/core/ocws-fonts.c",
    }, &.{});

    // ====================================================================
    // Tray app (GTK3 + appindicator)
    // ====================================================================

    _ = buildGtkApp(b, target, optimize, c_flags, "ocws-tray", &.{"src/cli/ocws-tray.c"}, &.{"ayatana-appindicator3-0.1"}, &.{});

    // ====================================================================
    // Daemons
    // ====================================================================

    _ = buildCliApp(b, target, optimize, c_flags, "ocws-brokerd", &.{
        "src/daemons/ocws-brokerd.c",
        "src/libocws/plugin_rt.c",
        "src/libocws/bus.c",
    }, &.{ "dl", "glib-2.0" });

    _ = buildCliApp(b, target, optimize, c_flags, "ocws-appletd", &.{"src/daemons/ocws-appletd.c"}, &.{ "dl", "glib-2.0" });

    _ = buildCliApp(b, target, optimize, c_flags, "ocws-hypertile", &.{
        "src/daemons/ocws-hypertile.c",
        "protocols/wlr-foreign-toplevel-management-unstable-v1-client.c",
    }, &.{"wayland-client"});

    _ = buildCliApp(b, target, optimize, c_flags, "ocws-notify", &.{"src/daemons/ocws-notify.c"}, &.{ "glib-2.0", "gio-2.0" });
    _ = buildCliApp(b, target, optimize, c_flags, "ocws-wallpaper", &.{"src/daemons/ocws-wallpaper.c"}, &.{ "cairo", "m" });

    // ====================================================================
    // ocws-gtk-shell: Zig GTK3 wrapper library
    // ====================================================================
    {
        const shellcore = b.createModule(.{
            .root_source_file = b.path("src/shells/shared/shellcore.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        shellcore.addIncludePath(b.path("src"));
        shellcore.addIncludePath(b.path("src/libocws"));
        shellcore.addIncludePath(b.path("src/shells/zigshell-cairo-pango/src"));
        inline for (&[_][]const u8{
            "/usr/include/gtk-3.0",
            "/usr/include/pango-1.0",
            "/usr/include/cairo",
            "/usr/include/glib-2.0",
            "/usr/lib64/glib-2.0/include",
            "/usr/include/gdk-pixbuf-2.0",
            "/usr/include/harfbuzz",
            "/usr/include/freetype2",
            "/usr/include/libpng16",
            "/usr/include/pixman-1",
            "/usr/include/libmount",
            "/usr/include/blkid",
            "/usr/include/sysprof-6",
            "/usr/include/fribidi",
            "/usr/include/librsvg-2.0",
            "/usr/include/libxml2",
        }) |inc| {
            shellcore.addSystemIncludePath(.{ .cwd_relative = inc });
        }
        shellcore.addIncludePath(b.path("src/shells/shared/protocol"));
        inline for (&[_][]const u8{
            "src/shells/zigshell-cairo-pango/src/dock_c_impl.c",
            "src/shells/shared/protocol/wlr-layer-shell-unstable-v1-client-protocol.c",
            "src/shells/shared/protocol/wlr-foreign-toplevel-management-unstable-v1-client-protocol.c",
            "src/shells/shared/protocol/xdg-shell-client-protocol.c",
        }) |src| {
            shellcore.addCSourceFile(.{
                .file = b.path(src),
                .flags = &.{ "-std=gnu11", "-Wall" },
            });
        }

        const lib = b.addLibrary(.{
            .name = "ocws-gtk-shell",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/libocws/gtk_shell.zig"),
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });
        lib.root_module.addImport("shellcore", shellcore);
        lib.root_module.addIncludePath(b.path("src/libocws"));
        lib.root_module.linkSystemLibrary("gtk+-3.0", .{});
        lib.root_module.linkSystemLibrary("glib-2.0", .{});
        lib.root_module.linkSystemLibrary("wayland-client", .{});
        b.installArtifact(lib);

        const gtk_shell_step = b.step("gtk-shell", "Build the GTK shell wrapper library");
        gtk_shell_step.dependOn(&lib.step);

        const gtk_shell_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/libocws/gtk_shell.zig"),
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });
        gtk_shell_tests.root_module.addImport("shellcore", shellcore);
        gtk_shell_tests.root_module.addIncludePath(b.path("src/libocws"));
        gtk_shell_tests.root_module.linkSystemLibrary("gtk+-3.0", .{});
        gtk_shell_tests.root_module.linkSystemLibrary("glib-2.0", .{});
        gtk_shell_tests.root_module.linkSystemLibrary("wayland-client", .{});
        gtk_shell_tests.root_module.linkSystemLibrary("librsvg-2.0", .{});

        const run_gtk_shell_tests = b.addRunArtifact(gtk_shell_tests);
        const test_gtk_shell = b.step("test-gtk-shell", "Run GTK shell wrapper tests");
        test_gtk_shell.dependOn(&run_gtk_shell_tests.step);
    }

    // ====================================================================
    // Shell script installs
    // ====================================================================

    const install_validate = b.addInstallFileWithDir(
        b.path("src/cli/ocws-validate.sh"),
        .{ .bin = {} },
        "ocws-validate",
    );
    b.default_step.dependOn(&install_validate.step);

    // ====================================================================
    // Tests
    // ====================================================================

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    tests.root_module.addIncludePath(b.path("src"));

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);

    // Headless pure-C libocws unit tests (string/easing/ini/json/fs/sysfs).
    // No GTK/Wayland needed. Run under ASan/UBSan for OOB detection.
    const libocws_tests = b.addExecutable(.{
        .name = "test-libocws",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    libocws_tests.root_module.addCSourceFile(.{ .file = b.path("tests/test_libocws.c") });
    libocws_tests.root_module.addIncludePath(b.path("src"));
    libocws_tests.root_module.linkSystemLibrary("glib-2.0", .{});

    const run_libocws_tests = b.addRunArtifact(libocws_tests);
    const libocws_test_step = b.step("test-libocws", "Run headless libocws C unit tests");
    libocws_test_step.dependOn(&run_libocws_tests.step);

    // ====================================================================
    // C unit tests for libocws header-only libraries
    // Each test file is a standalone executable — no link dependencies
    // beyond libc. These test ocws_string.h, ini.h, json.h, procfs.h,
    // easing.h, log.h, cli-common.h, and security properties.
    // ====================================================================

    const unit_tests = [_]struct { name: []const u8, src: []const u8, libs: []const []const u8 }{
        .{ .name = "test-unit-string", .src = "tests/unit/test_libocws_string.c", .libs = &.{} },
        .{ .name = "test-unit-ini", .src = "tests/unit/test_libocws_ini.c", .libs = &.{} },
        .{ .name = "test-unit-json", .src = "tests/unit/test_libocws_json.c", .libs = &.{} },
        .{ .name = "test-unit-procfs", .src = "tests/unit/test_libocws_procfs.c", .libs = &.{"m"} },
        .{ .name = "test-unit-easing", .src = "tests/unit/test_libocws_easing.c", .libs = &.{"m"} },
        .{ .name = "test-unit-log", .src = "tests/unit/test_libocws_log.c", .libs = &.{} },
        .{ .name = "test-unit-cli-common", .src = "tests/unit/test_libocws_cli_common.c", .libs = &.{} },
        .{ .name = "test-unit-security", .src = "tests/unit/test_libocws_security.c", .libs = &.{} },
    };

    inline for (unit_tests) |t| {
        const exe = b.addExecutable(.{
            .name = t.name,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });
        exe.root_module.addCSourceFile(.{ .file = b.path(t.src), .flags = c_flags });
        exe.root_module.addIncludePath(b.path("src"));
        inline for (t.libs) |lib| {
            exe.root_module.linkSystemLibrary(lib, .{});
        }
        b.installArtifact(exe);
        const step = b.step(t.name, b.fmt("Build {s}", .{t.name}));
        step.dependOn(&exe.step);
    }

    // Aggregate step: run all C unit tests
    {
        const run_all = b.addSystemCommand(&.{ "bash", "tests/unit/run-unit-tests.sh" });
        const all_unit_step = b.step("test-unit", "Run all C unit tests for libocws");
        all_unit_step.dependOn(&run_all.step);
    }

    // Shared shell logging-level parser tests (log.zig parseLevel).
    const log_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/shells/shared/log_test.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    const run_log_tests = b.addRunArtifact(log_tests);
    const log_test_step = b.step("test-log", "Run shared log level parser tests");
    log_test_step.dependOn(&run_log_tests.step);
}

fn buildGtkApp(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    c_flags: []const []const u8,
    name: []const u8,
    c_sources: []const []const u8,
    extra_libs: []const []const u8,
    extra_includes: []const []const u8,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    for (c_sources) |src| {
        exe.root_module.addCSourceFile(.{ .file = b.path(src), .flags = c_flags });
    }

    exe.root_module.linkSystemLibrary("gtk+-3.0", .{});
    exe.root_module.linkSystemLibrary("glib-2.0", .{});

    for (extra_libs) |lib| {
        exe.root_module.linkSystemLibrary(lib, .{});
    }

    for (extra_includes) |inc| {
        exe.root_module.addSystemIncludePath(.{ .cwd_relative = inc });
    }

    b.installArtifact(exe);
    const step = b.step(name, b.fmt("Build {s}", .{name}));
    step.dependOn(&exe.step);

    return exe;
}

fn buildCliApp(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    c_flags: []const []const u8,
    name: []const u8,
    c_sources: []const []const u8,
    extra_libs: []const []const u8,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    for (c_sources) |src| {
        exe.root_module.addCSourceFile(.{ .file = b.path(src), .flags = c_flags });
    }

    for (extra_libs) |lib| {
        exe.root_module.linkSystemLibrary(lib, .{});
    }

    b.installArtifact(exe);
    const step = b.step(name, b.fmt("Build {s}", .{name}));
    step.dependOn(&exe.step);

    return exe;
}
