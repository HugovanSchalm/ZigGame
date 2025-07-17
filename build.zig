const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const glbindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"3.3",
        .profile = .core,
        .extensions = &.{}
    });

    const exe = b.addExecutable(.{
        .name = "ZigGame",
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target
    });

    exe.linkLibC();
    exe.linkSystemLibrary("SDL3");
    exe.root_module.addImport("gl", glbindings);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
