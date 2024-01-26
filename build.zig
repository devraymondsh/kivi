const std = @import("std");

const cwd = std.fs.cwd();
var target: std.Target = undefined;
var optimize: std.builtin.OptimizeMode = undefined;
var resolved_target: std.Build.ResolvedTarget = undefined;

var global_deps: [2]Dependency = undefined;
const Dependency = struct {
    name: []const u8,
    module: *std.Build.Module,

    inline fn addExternal(
        b: *std.Build,
        comptime name: []const u8,
        comptime n: comptime_int,
    ) void {
        const dep = b.dependency(name, .{
            .target = resolved_target,
            .optimize = optimize,
        });
        global_deps[n] = .{
            .name = name,
            .module = dep.module(name),
        };
    }
    inline fn addInternal(
        b: *std.Build,
        comptime name: []const u8,
        comptime source: []const u8,
        comptime n: comptime_int,
    ) void {
        global_deps[n] = .{
            .name = name,
            .module = b.createModule(.{ .root_source_file = .{ .path = source } }),
        };
    }
};

/// Build static and shared libraries given name and path
const Libs = struct {
    shared: *std.Build.Step.Compile,
    static: ?*std.Build.Step.Compile,
    fn create(b: *std.Build, name: []const u8, path: []const u8, with_static: bool) Libs {
        var strip: bool = false;
        if (optimize == .ReleaseFast or optimize == .ReleaseSafe or optimize == .ReleaseSmall) {
            strip = true;
        }

        const shared = b.addSharedLibrary(.{ .name = name, .root_source_file = .{ .path = path }, .target = resolved_target, .optimize = optimize });
        shared.root_module.pic = true;
        shared.root_module.strip = strip;
        shared.linker_allow_shlib_undefined = true;
        if (target.os.tag != .macos) {
            shared.want_lto = true;
        }

        var static: ?*std.Build.Step.Compile = null;
        if (with_static) {
            static = b.addStaticLibrary(.{ .name = name, .root_source_file = .{ .path = path }, .target = resolved_target, .optimize = optimize });
            shared.root_module.pic = true;
            static.?.root_module.strip = strip;
            static.?.linker_allow_shlib_undefined = true;
            if (target.os.tag != .macos) {
                static.?.want_lto = true;
            }
        }

        inline for (global_deps) |global_dep| {
            shared.root_module.addImport(global_dep.name, global_dep.module);
            if (with_static) {
                static.?.root_module.addImport(global_dep.name, global_dep.module);
            }
        }

        return .{ .static = static, .shared = shared };
    }
};

fn install_pnpm() !void {
    const command_res = try std.ChildProcess.run(.{ .allocator = std.heap.page_allocator, .argv = &[_][]const u8{ "npm", "install", "-g", "pnpm@latest" } });
    if (command_res.stderr.len > 0) {
        std.debug.print("{s}\n", .{command_res.stderr});
        return error.PnpmNotFoundAndFailedToInstall;
    }
}
// Checks if pnpm is installed on the machine and insatlls it if possible
fn pnpm_check(allocator: std.mem.Allocator) !void {
    const npm_version_command = std.ChildProcess.run(.{ .allocator = allocator, .argv = &[2][]const u8{ "pnpm", "--version" } });
    if (npm_version_command) |command_res| {
        if (command_res.stderr.len > 0) {
            return install_pnpm();
        }
    } else |_| {
        return install_pnpm();
    }
}

fn get_lazypath(path: []const u8) std.Build.LazyPath {
    return std.Build.LazyPath.relative(path);
}

inline fn run_npm_command(
    b: *std.Build,
    comptime dir: []const u8,
    // comptime commands: [][]const u8
    comptime commands: anytype,
    // dependency_steps: []*std.Build.Step
    dependency_steps: anytype,
    runner_step: *std.Build.Step,
) void {
    inline for (commands, 0..) |command, idx| {
        const syscommand = b.addSystemCommand(&[3][]const u8{ "pnpm", "run", command });
        syscommand.cwd = get_lazypath(dir);

        inline for (dependency_steps) |dependency_step| {
            syscommand.step.dependOn(dependency_step);
        }
        if (idx == commands.len - 1) {
            runner_step.dependOn(&syscommand.step);
        }
    }
}

pub fn build(b: *std.Build) !void {
    optimize = b.standardOptimizeOption(.{});
    resolved_target = b.standardTargetOptions(.{});
    target = resolved_target.result;

    // Sets up the allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer {
        arena.deinit();
    }

    // Checks if npm is installed
    try pnpm_check(allocator);

    // Declares commonly used target informations
    const arch = @tagName(target.cpu.arch);
    const tag = @tagName(target.os.tag);

    // Declares dependencies
    Dependency.addInternal(b, "Kivi", "src/core/Kivi.zig", 0);
    Dependency.addInternal(b, "core", "src/core/main.zig", 1);

    // Executes codegens
    const codegen_step = b.step("codegen", "Generates bindings");
    const core_codegen = b.addExecutable(.{
        .name = "codegen_generate",
        .root_source_file = .{ .path = "src/codegen/core.zig" },
        .optimize = optimize,
        .target = resolved_target,
    });
    const js_driver_codegen = b.addExecutable(.{
        .name = "codegen_generate",
        .root_source_file = .{ .path = "src/codegen/js_driver.zig" },
        .optimize = optimize,
        .target = resolved_target,
    });
    inline for (global_deps) |global_dep| {
        core_codegen.root_module.addImport(global_dep.name, global_dep.module);
        js_driver_codegen.root_module.addImport(global_dep.name, global_dep.module);
    }
    codegen_step.dependOn(&b.addRunArtifact(core_codegen).step);
    codegen_step.dependOn(&b.addRunArtifact(js_driver_codegen).step);

    // Compiles the core then generates static and shared libraries
    const core_build_step = b.step("core", "Builds the core");
    const core_targets = Libs.create(
        b,
        try std.fmt.allocPrint(allocator, "kivi-{s}-{s}", .{ arch, tag }),
        "src/core/main.zig",
        true,
    );
    core_build_step.dependOn(codegen_step);
    core_build_step.dependOn(&b.addInstallArtifact(core_targets.shared, .{}).step);
    core_build_step.dependOn(&b.addInstallArtifact(core_targets.static.?, .{}).step);

    // Compiles the JS driver
    const drivers_build_step = b.step("drivers", "Builds all drivers");
    const js_driver_targets = Libs.create(
        b,
        "kivi-node-addon",
        "src/drivers/js/runtimes/nodejs/main.zig",
        false,
    );
    drivers_build_step.dependOn(&b.addInstallArtifact(js_driver_targets.shared, .{}).step);
    // Makes a proper .node file in order to be used in Nodejs
    const node_addon_install = b.addInstallFileWithDir(
        js_driver_targets.shared.getEmittedBin(),
        .lib,
        try std.fmt.allocPrint(allocator, "kivi-addon-{s}-{s}.node", .{ arch, tag }),
    );
    drivers_build_step.dependOn(codegen_step);
    node_addon_install.step.dependOn(&js_driver_targets.shared.step);
    drivers_build_step.dependOn(&node_addon_install.step);

    // C FFI tests
    var ffi_tests_step = b.step("test-ffi", "Runs FFI tests");
    const ffi_tests = b.addExecutable(.{ .name = "ffi-tests", .target = resolved_target, .optimize = optimize });
    ffi_tests.linkLibC();
    ffi_tests.linkLibrary(core_targets.shared);
    ffi_tests.addSystemIncludePath(.{ .path = "src/core/include" });
    ffi_tests.addCSourceFile(.{
        .file = .{ .path = "src/core/tests/ffi.c" },
        .flags = &.{"-std=c17"},
    });
    ffi_tests_step.dependOn(core_build_step);
    ffi_tests_step.dependOn(&b.addInstallArtifact(ffi_tests, .{}).step);
    ffi_tests_step.dependOn(&b.addRunArtifact(ffi_tests).step);

    // Runs all tests
    const test_step = b.step("test", "Runs all tests");
    _ = run_npm_command(
        b,
        "src/drivers/js",
        .{
            "nodejs-test",
            // "deno-test",
            // "bun-test",
        },
        // ffi_tests_step
        .{ core_build_step, drivers_build_step },
        test_step,
    );

    // Benchmarks Kivi
    const bench_step = b.step("bench", "Benchmarks kivi");
    _ = run_npm_command(
        b,
        "bench",
        .{
            // "nodejs-bench",
            // "deno-bench",
            "bun-bench",
        },
        .{ core_build_step, drivers_build_step },
        bench_step,
    );
}
