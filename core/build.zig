const std = @import("std");
var optimize: std.builtin.OptimizeMode = undefined;

/// Build static and shared libraries given name and path
const Libs = struct {
    static: *std.Build.Step.Compile,
    shared: *std.Build.Step.Compile,
    fn create(b: *std.Build, name: []const u8, path: []const u8, target: std.zig.CrossTarget, target_info: std.zig.system.NativeTargetInfo, optimize_mode: std.builtin.Mode, strip: bool) Libs {
        const static = b.addStaticLibrary(.{ .name = name, .root_source_file = .{ .path = path }, .target = target, .optimize = optimize_mode });
        const shared = b.addSharedLibrary(.{ .name = name, .root_source_file = .{ .path = path }, .target = target, .optimize = optimize_mode });
        static.strip = strip;
        shared.strip = strip;
        static.force_pic = true;
        shared.force_pic = true;
        shared.single_threaded = true;
        static.single_threaded = true;
        shared.linker_allow_shlib_undefined = true;
        static.linker_allow_shlib_undefined = true;
        if (target_info.target.os.tag != .macos) {
            static.want_lto = true;
            shared.want_lto = true;
        }

        return .{ .static = static, .shared = shared };
    }
};

/// Build libs + test-running binary given name and path
const Targets = struct {
    libs: Libs,
    tests: *std.Build.Step.Compile,
    fn create(b: *std.Build, name: []const u8, path: []const u8, target: std.zig.CrossTarget, target_info: std.zig.system.NativeTargetInfo, optimize_mode: std.builtin.Mode) Targets {
        const tests = b.addTest(.{ .root_source_file = .{ .path = path }, .target = target, .optimize = optimize_mode });

        var strip = false;
        if (optimize_mode != .Debug) {
            strip = true;
        }
        tests.strip = strip;

        return .{ .libs = Libs.create(b, name, path, target, target_info, optimize_mode, strip), .tests = tests };
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
        c_flags: []const []const u8,
        target: std.zig.CrossTarget,
        optimize_mode: std.builtin.Mode,
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

pub const all_targets = .{ .cpu = .{ "x86_64", "aarch64" }, .os = .{ "windows", "linux", "macos" } };
pub fn buildAllFn(self: *std.build.Step, progress: *std.Progress.Node) !void {
    _ = progress;
    inline for (all_targets.os) |os| {
        inline for (all_targets.cpu) |cpu| {
            var optimize_mode = std.ArrayList(u8).init(std.heap.page_allocator);
            try optimize_mode.writer().print("-Doptimize={s}", .{@tagName(optimize)});
            var target_mode = std.ArrayList(u8).init(std.heap.page_allocator);
            try target_mode.writer().print("-Dtarget={s}-{s}-none", .{ cpu, os });

            try self.evalChildProcess(&[_][]const u8{ "zig", "build", optimize_mode.items, target_mode.items });
        }
    }
}
pub fn buildAll(b: *std.Build) void {
    var build_all = b.step("all", "Build for all targets");
    build_all.makeFn = buildAllFn;
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    optimize = b.standardOptimizeOption(.{});
    const target_info = try std.zig.system.NativeTargetInfo.detect(target);

    var lib_name_arrlist = std.ArrayList(u8).init(std.heap.page_allocator);
    try lib_name_arrlist.writer().print("kivi-{s}-{s}", .{ @tagName(target_info.target.cpu.arch), @tagName(target_info.target.os.tag) });
    defer lib_name_arrlist.deinit();

    const lib_name = lib_name_arrlist.items;
    const lib_src_path = "src/main.zig";
    const lib_include_path = "src/include";

    const c_ffi_path = "src/tests/ffi.c";
    const c_flags: []const []const u8 = switch (optimize) {
        // asserts in ffi.c go away in unsafe build modes, so we need to disable errors on unused variables
        .ReleaseFast, .ReleaseSmall => &.{ "-std=c17", "-pedantic", "-Wall", "-Werror", "-Wno-unused-variable" },
        .ReleaseSafe, .Debug => &.{ "-std=c17", "-pedantic", "-Wall", "-Werror" },
    };

    const targets = Targets.create(b, lib_name, lib_src_path, target, target_info, optimize);

    // Run tests on `zig build test`
    const run_main_tests = b.addRunArtifact(targets.tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    // Install libraries to zig-out
    b.installArtifact(targets.libs.static);
    b.installArtifact(targets.libs.shared);

    // Build and run C programs using 3 "linkage modes"
    const ffi = FFI.create(
        b,
        lib_include_path,
        targets.libs.shared,
        c_ffi_path,
        c_flags,
        target,
        optimize,
    );

    const ffi_step = b.step("ffi", "Run FFI tests");

    const kivi_mod = b.createModule(.{
        .source_file = .{ .path = "src/Kivi.zig" },
    });
    const main_mod = b.createModule(.{
        .source_file = .{ .path = "src/main.zig" },
    });

    const codegen = b.addExecutable(.{
        .name = "codegen_generate",
        .root_source_file = .{ .path = "src/codegen/generate.zig" },
        .optimize = optimize,
        .target = target,
    });
    codegen.addModule("Kivi", kivi_mod);
    codegen.addModule("main", main_mod);
    const codegen_run = b.addRunArtifact(codegen);

    const codegen_step = b.step("codegen", "generate C header files");

    codegen_step.dependOn(&codegen_run.step);

    ffi.shared.step.dependOn(&codegen_run.step);

    inline for (@typeInfo(FFI).Struct.fields) |field| {
        const run = b.addRunArtifact(@field(ffi, field.name));
        ffi_step.dependOn(&run.step);
    }
    test_step.dependOn(ffi_step);

    // Adds `build all` command
    buildAll(b);
}
