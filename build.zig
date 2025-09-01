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

    const exe = b.addExecutable(.{ 
        .name = "ZigGame", 
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }) 
    });

    exe.linkLibC();
    exe.linkSystemLibrary("SDL3");
    exe.root_module.addImport("gl", glbindings);
    exe.root_module.addImport("zm", zm.module("zm"));
    exe.root_module.addImport("zgltf", zgltf.module("zgltf"));
    exe.root_module.addImport("sdl3", sdl3.module("sdl3"));
    exe.linkLibrary(cimgui_dep.artifact("cimgui"));

    b.installArtifact(exe);

    b.installDirectory(.{
        .source_dir = b.path("./assets"),
        .install_dir = .{ .prefix = {} },
        .install_subdir = "bin/assets",
    });

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
