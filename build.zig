const std = @import("std");
const cwd = std.fs.cwd();

/// Build static and shared libraries given name and path
const Libs = struct {
    static: ?*std.Build.Step.Compile,
    shared: *std.Build.Step.Compile,
    fn create(b: *std.Build, name: []const u8, path: []const u8, target: std.zig.CrossTarget, target_info: std.zig.system.NativeTargetInfo, optimize_mode: std.builtin.Mode, with_static: bool) Libs {
        var strip: bool = false;
        if (optimize_mode == .ReleaseFast or optimize_mode == .ReleaseSafe or optimize_mode == .ReleaseSmall) {
            strip = true;
        }

        const shared = b.addSharedLibrary(.{ .name = name, .root_source_file = .{ .path = path }, .target = target, .optimize = optimize_mode });
        // shared.strip = strip;
        shared.force_pic = true;
        shared.single_threaded = true;
        shared.linker_allow_shlib_undefined = true;
        if (target_info.target.os.tag != .macos) {
            shared.want_lto = true;
        }

        var static: ?*std.Build.Step.Compile = null;
        if (with_static) {
            static = b.addStaticLibrary(.{ .name = name, .root_source_file = .{ .path = path }, .target = target, .optimize = optimize_mode });
            // static.?.strip = strip;
            static.?.force_pic = true;
            static.?.single_threaded = true;
            static.?.linker_allow_shlib_undefined = true;
            if (target_info.target.os.tag != .macos) {
                static.?.want_lto = true;
            }
        }

        return .{ .static = static, .shared = shared };
    }
};
/// Build libs + test-running binary given name and path
const Targets = struct {
    libs: Libs,
    tests: *std.Build.Step.Compile,
    fn create(b: *std.Build, name: []const u8, path: []const u8, target: std.zig.CrossTarget, target_info: std.zig.system.NativeTargetInfo, optimize_mode: std.builtin.Mode, with_static: bool) Targets {
        const tests = b.addTest(.{ .root_source_file = .{ .path = path }, .target = target, .optimize = optimize_mode });

        return .{ .libs = Libs.create(b, name, path, target, target_info, optimize_mode, with_static), .tests = tests };
    }
};
/// Build binaries from C code testing usage of libraries in a unity build (single translation unit) + static library build + shared library build
const FFI = struct {
    shared: *std.Build.Step.Compile,
    fn create(
        b: *std.Build,
        lib_include_path: []const u8,
        shared_lib: *std.Build.Step.Compile,
        c_path: []const u8,
        target: std.zig.CrossTarget,
        optimize_mode: std.builtin.Mode,
        c_flags: []const []const u8,
    ) FFI {
        return .{
            .shared = b: {
                const ffi = b.addExecutable(.{ .name = "ffi-shared", .target = target, .optimize = optimize_mode });
                ffi.linkLibC();
                ffi.linkLibrary(shared_lib);
                ffi.addSystemIncludePath(.{ .path = lib_include_path });
                ffi.addCSourceFile(.{ .file = .{ .path = c_path }, .flags = c_flags });
                break :b ffi;
            },
        };
    }
};

fn install_pnpm() !void {
    const command_res = try std.ChildProcess.run(.{ .allocator = std.heap.page_allocator, .argv = &[_][]const u8{ "npm", "install", "-g", "pnpm@latest" } });
    if (command_res.stderr.len > 0) {
        std.debug.print("{s}\n", .{command_res.stderr});
        return error.PnpmNotFoundAndFailedToInstall;
    }
}
fn install_pnpm_if_needed() !void {
    const pnpm_version_command = std.ChildProcess.run(.{ .allocator = std.heap.page_allocator, .argv = &[_][]const u8{ "pnpm", "--version" } });
    if (pnpm_version_command) |command_res| {
        if (command_res.stderr.len > 0) {
            try install_pnpm();
        }
    } else |_| {
        try install_pnpm();
    }
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const target_info = try std.zig.system.NativeTargetInfo.detect(target);
    const arch = @tagName(target_info.target.cpu.arch);
    const os = @tagName(target_info.target.os.tag);

    // Compiles the core then generates static and shared libraries
    const core_build_step = b.step("core", "Builds the core");
    var lib_name_arrlist = std.ArrayList(u8).init(std.heap.page_allocator);
    try lib_name_arrlist.writer().print("kivi-{s}-{s}", .{ @tagName(target_info.target.cpu.arch), @tagName(target_info.target.os.tag) });
    defer lib_name_arrlist.deinit();
    const core_targets = Targets.create(b, lib_name_arrlist.items, "src/core/main.zig", target, target_info, optimize, true);
    core_build_step.dependOn(&b.addInstallArtifact(core_targets.libs.static.?, .{}).step);
    core_build_step.dependOn(&b.addInstallArtifact(core_targets.libs.shared, .{}).step);

    // Defines modules
    const kivi_mod = b.createModule(.{
        .source_file = .{ .path = "src/core/Kivi.zig" },
    });
    const core_mod = b.createModule(.{
        .source_file = .{ .path = "src/core/main.zig" },
    });

    // Compiles the JS driver
    const drivers_build_step = b.step("drivers", "Builds all drivers");
    const js_driver_targets = Targets.create(b, "kivi-node-addon", "src/drivers/js/nodejs/main.zig", target, target_info, optimize, false);
    js_driver_targets.libs.shared.addModule("Kivi", kivi_mod);
    js_driver_targets.libs.shared.addIncludePath(std.build.LazyPath.relative("src/drivers/js/nodejs/napi-headers"));
    // Makes a proper .node file in order to be used in Nodejs
    var formatted_target_obj = std.ArrayList(u8).init(std.heap.page_allocator);
    try formatted_target_obj.writer().print("kivi-addon-{s}-{s}.node", .{ arch, os });
    defer formatted_target_obj.deinit();
    const node_addon_install = b.addInstallFileWithDir(js_driver_targets.libs.shared.getOutputSource(), .lib, formatted_target_obj.items);
    node_addon_install.step.dependOn(&js_driver_targets.libs.shared.step);
    drivers_build_step.dependOn(&b.addInstallArtifact(js_driver_targets.libs.shared, .{}).step);
    drivers_build_step.dependOn(&node_addon_install.step);

    // Executes codegens
    const codegen_step = b.step("codegen", "Generates bindings");
    const codegen = b.addExecutable(.{
        .name = "codegen_generate",
        .root_source_file = .{ .path = "src/codegen/core.zig" },
        .optimize = optimize,
        .target = target,
    });
    codegen.addModule("Kivi", kivi_mod);
    codegen.addModule("core", core_mod);
    const codegen_run = b.addRunArtifact(codegen);
    codegen_step.dependOn(&b.addRunArtifact(codegen).step);

    // Install pnpm if needed
    try install_pnpm_if_needed();

    // Runs all tests
    const test_step = b.step("test", "Runs all tests");
    test_step.dependOn(core_build_step);
    test_step.dependOn(drivers_build_step);
    test_step.dependOn(&b.addRunArtifact(core_targets.tests).step);
    // Builds and runs FFI tests using 3 "linkage modes"
    const ffi = FFI.create(
        b,
        "src/core/include",
        core_targets.libs.shared,
        "src/core/tests/ffi.c",
        target,
        optimize,
        switch (optimize) {
            // asserts in ffi.c go away in unsafe build modes, so we need to disable errors on unused variables
            .ReleaseFast, .ReleaseSmall => &.{ "-std=c17", "-pedantic", "-Wall", "-Werror", "-Wno-unused-variable" },
            .ReleaseSafe, .Debug => &.{ "-std=c17", "-pedantic", "-Wall", "-Werror" },
        },
    );
    ffi.shared.step.dependOn(&codegen_run.step);
    inline for (@typeInfo(FFI).Struct.fields) |field| {
        test_step.dependOn(&b.addRunArtifact(@field(ffi, field.name)).step);
    }

    const js_driver_test_commad1 = b.addSystemCommand(&[_][]const u8{ "pnpm", "-C", "src/drivers/js", "run", "nodejs-test" });
    js_driver_test_commad1.step.dependOn(drivers_build_step);
    test_step.dependOn(&js_driver_test_commad1.step);
    const js_driver_test_commad2 = b.addSystemCommand(&[_][]const u8{ "pnpm", "-C", "src/drivers/js", "run", "bun-test" });
    js_driver_test_commad2.step.dependOn(core_build_step);
    test_step.dependOn(&js_driver_test_commad2.step);
    const js_driver_test_commad3 = b.addSystemCommand(&[_][]const u8{ "pnpm", "-C", "src/drivers/js", "run", "deno-test" });
    js_driver_test_commad3.step.dependOn(core_build_step);
    test_step.dependOn(&js_driver_test_commad3.step);

    // Benchmarks Kivi
    const benchmark_step = b.step("bench", "Benchmarks kivi");
    const node_bench_sys_commad = b.addSystemCommand(&[_][]const u8{ "pnpm", "-C", "bench", "run", "nodejs-bench" });
    const deno_bench_sys_commad = b.addSystemCommand(&[_][]const u8{ "pnpm", "-C", "bench", "run", "deno-bench" });
    const bun_bench_sys_commad = b.addSystemCommand(&[_][]const u8{ "pnpm", "-C", "bench", "run", "bun-bench" });
    const npm_install_commad = b.addSystemCommand(&[_][]const u8{ "pnpm", "-C", "bench", "install" });
    if (cwd.openDir("bench/node_modules", .{})) |_| {} else |_| {
        node_bench_sys_commad.step.dependOn(&npm_install_commad.step);
    }
    if (cwd.openFile("bench/faker/data/data.json", .{})) |_| {} else |_| {
        const sys_commad = b.addSystemCommand(&[_][]const u8{ "pnpm", "-C", "bench", "run", "generate-fake-data" });
        sys_commad.step.dependOn(&npm_install_commad.step);
        node_bench_sys_commad.step.dependOn(&sys_commad.step);
    }
    benchmark_step.dependOn(core_build_step);
    benchmark_step.dependOn(drivers_build_step);
    benchmark_step.dependOn(&node_bench_sys_commad.step);
    benchmark_step.dependOn(&deno_bench_sys_commad.step);
    benchmark_step.dependOn(&bun_bench_sys_commad.step);
    node_bench_sys_commad.step.dependOn(drivers_build_step);
    bun_bench_sys_commad.step.dependOn(&node_bench_sys_commad.step);
    deno_bench_sys_commad.step.dependOn(&bun_bench_sys_commad.step);
}
