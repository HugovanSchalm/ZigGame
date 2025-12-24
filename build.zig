const std = @import("std");
const cimgui = @import("cimgui_zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const glbindings = @import("zigglgen").generateBindingsModule(b, .{ .api = .gl, .version = .@"3.3", .profile = .core, .extensions = &.{} });

    const zm = b.dependency("zm", .{
        .target = target,
        .optimize = optimize,
    });

    const zgltf = b.dependency("zgltf", .{
        .target = target,
        .optimize = optimize,
    });

    const cimgui_dep = b.dependency("cimgui_zig", .{
        .target = target,
        .optimize = optimize,
        .platform = cimgui.Platform.SDL3,
        .renderer = cimgui.Renderer.OpenGL3,
    });

    const sdl3 = b.dependency("sdl3", .{
        .target = target,
        .optimize = optimize,
        .ext_image = true,
        .image_enable_png = true,
    });

    const exe_mod = b.addModule("ZigGame", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    exe_mod.linkSystemLibrary("SDL3", .{});
    exe_mod.addImport("gl", glbindings);
    exe_mod.addImport("zm", zm.module("zm"));
    exe_mod.addImport("zgltf", zgltf.module("zgltf"));
    exe_mod.addImport("sdl3", sdl3.module("sdl3"));
    exe_mod.linkLibrary(cimgui_dep.artifact("cimgui"));

    const exe = b.addExecutable(.{
        .name = "ZigGame",
        .root_module = exe_mod,
    });

    b.installDirectory(.{
        .source_dir = b.path("./assets"),
        .install_dir = .{ .prefix = {} },
        .install_subdir = "bin/assets",
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_check = b.addExecutable(.{
        .name = "ZigGameCheck",
        .root_module = exe_mod,
    });

    const check_step = b.step("check", "Check if the game compiles");
    check_step.dependOn(&exe_check.step);
}
