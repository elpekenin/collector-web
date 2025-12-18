const std = @import("std");

const zx_build = @import("zx");

pub fn build(b: *std.Build) !void {
    // options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // dependencies
    const ptz = b.dependency("ptz", .{
        .target = target,
        .optimize = optimize,
    });
    const zmig = b.dependency("zmig", .{
        .target = target,
        .optimize = optimize,
        .migrations = b.path("migrations"),
    });
    // hack: use same version of sqlite as zmig
    //       without this, compiler may complain about "different" types (zmig vs sqlite deps)
    const sqlite = zmig.builder.dependency("sqlite", .{
        .target = target,
        .optimize = optimize,
    });
    const zx = b.dependency("zx", .{
        .target = target,
        .optimize = optimize,
    });

    // backend
    const backend = b.addModule("backend", .{
        .root_source_file = b.path("backend/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "ptz", .module = ptz.module("ptz") },
            .{ .name = "sqlite", .module = sqlite.module("sqlite") },
            .{ .name = "zmig", .module = zmig.module("zmig") },
        },
    });

    // frontend
    const frontend = b.createModule(.{
        .root_source_file = b.path("frontend/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "backend", .module = backend },
        },
    });

    // put the server together
    try zx_build.init(
        b,
        b.addExecutable(.{
            .name = "collector_web",
            .root_module = frontend,
        }),
        .{
            .site = .{
                .path = "frontend",
            },
        },
    );

    // access zmig CLI
    const zmig_run = b.addRunArtifact(zmig.artifact("zmig"));
    const zmig_step = b.step("zmig", "invoke zmig's CLI");
    zmig_step.dependOn(&zmig_run.step);

    // access zx CLI
    const zx_run = b.addRunArtifact(zx.artifact("zx"));
    const zx_step = b.step("zx", "invokes zx's CLI");
    zx_step.dependOn(&zx_run.step);

    if (b.args) |args| {
        zmig_run.addArgs(args);
        zx_run.addArgs(args);
    }
}
