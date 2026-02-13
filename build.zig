const std = @import("std");
const Build = std.Build;
const Step = Build.Step;

const zx = @import("zx");
const ZxOptions = zx.ZxInitOptions;

fn addConfig(comptime T: type, b: *Build, options: *Step.Options, name: []const u8, default: T) void {
    const value = b.option(T, name, name) orelse default;
    options.addOption(T, name, value);
}

pub fn build(b: *Build) !void {
    // options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options_builder = b.addOptions();
    addConfig(usize, b, options_builder, "max_awaitable_promises", 5);
    const options = options_builder.createModule();

    const database = b.createModule(.{
        .root_source_file = b.path("database/database.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "options", .module = options },
            .{
                .name = "fridge",
                .module = b.dependency("fridge", .{
                    .bundle = true, // embed SQLite in binary
                }).module("fridge"),
            },
        },
    });

    const web = b.createModule(.{
        .root_source_file = b.path("web/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "database", .module = database },
        },
    });
    web.addImport("app", web);

    // put the server together
    const exe = b.addExecutable(.{
        .name = "collector-web",
        .root_module = web,
        // work around self-hosted crashing on some code
        .use_llvm = true,
    });

    const zx_options: ZxOptions = .{
        .cli = .{
            .steps = .{
                .serve = "web",
                .dev = "dev",
            },
        },
        .plugins = &.{
            zx.plugins.tailwind(b, .{
                .bin = b.path("node_modules/.bin/tailwindcss"),
                .input = b.path("web/_/styles.css"),
                .output = b.path("{outdir}/public/styles.css"),
            }),
            zx.plugins.esbuild(b, .{
                .bin = b.path("node_modules/.bin/esbuild"),
                .input = b.path("web/main.ts"),
                .output = b.path("{outdir}/assets/main.js"),
            }),
        },
        .app = .{
            .path = b.path("web"),
        },
    };

    _ = try zx.init(b, exe, zx_options);

    // HACK: make module available to ZX modules
    // for (&[_]*Build.Step.Compile{ zx_build.zx_exe, zx_build.client_exe orelse @panic("no client exe") }) |executable| {
    //     const module = executable.root_module.import_table.get("zx") orelse continue;

    //     if (module.import_table.get("zx_meta")) |meta| {
    //         meta.addImport("options", options);
    //     }
    // }

    const cli = b.createModule(.{
        .root_source_file = b.path("cli/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "database", .module = database },
            .{ .name = "options", .module = options },
            .{
                .name = "graphqlz",
                .module = b.dependency("graphqlz", .{ // FIXME: remove after https://github.com/tcgdex/cards-database/pull/1084
                    .target = target,
                    .optimize = optimize,
                }).module("graphqlz"),
            },
            .{
                .name = "sdk",
                .module = b.dependency("sdk", .{
                    .target = target,
                    .optimize = optimize,
                }).module("sdk"),
            },
        },
    });

    const cli_step = b.step("cli", "run db-management CLI");
    const cli_run = b.addRunArtifact(
        b.addExecutable(.{
            .name = "cli",
            .root_module = cli,
        }),
    );
    if (b.args) |args| cli_run.addArgs(args);
    cli_step.dependOn(&cli_run.step);

    // tests
    const test_step = b.step("test", "run tests");
    const test_runner: Step.Compile.TestRunner = .{
        .mode = .simple,
        .path = b.path("lib/test_runner.zig"),
    };

    const test_cli = b.addTest(.{
        .root_module = cli,
        .name = "test_cli",
        .use_llvm = true,
        .test_runner = test_runner,
    });
    test_step.dependOn(&b.addRunArtifact(test_cli).step);

    const test_web = b.addTest(.{
        .root_module = web,
        .name = "test_web",
        .use_llvm = true,
        .test_runner = test_runner,
    });
    test_step.dependOn(&b.addRunArtifact(test_web).step);

    // linter
    const ephor = b.dependency("ephor", .{
        .target = target,
        .optimize = .ReleaseSafe,
    });
    const ephor_exe = ephor.artifact("ephor");
    const ephor_run = b.addRunArtifact(ephor_exe);
    if (b.args) |args| ephor_run.addArgs(args);
    const ephor_step = b.step("ephor", "Run ephor static analysis");
    ephor_step.dependOn(&ephor_run.step);
}
