const std = @import("std");

/// Build static and shared libraries given name and path
const Libs = struct {
    static: *std.Build.Step.Compile,
    shared: *std.Build.Step.Compile,
    fn create(b: *std.Build, name: []const u8, path: []const u8, target: std.zig.CrossTarget, optimize: std.builtin.Mode, strip: ?bool) Libs {
        const static = b.addStaticLibrary(.{ .name = name, .root_source_file = .{ .path = path }, .target = target, .optimize = optimize });
        const shared = b.addSharedLibrary(.{ .name = name, .root_source_file = .{ .path = path }, .target = target, .optimize = optimize });
        static.strip = strip;
        shared.strip = strip;
        static.force_pic = true;
        shared.force_pic = true;
        return .{ .static = static, .shared = shared };
    }
};

/// Build libs + test-running binary given name and path
const Targets = struct {
    libs: Libs,
    tests: *std.Build.Step.Compile,
    fn create(b: *std.Build, name: []const u8, path: []const u8, target: std.zig.CrossTarget, optimize: std.builtin.Mode, strip: ?bool) Targets {
        const tests = b.addTest(.{ .root_source_file = .{ .path = path }, .target = target, .optimize = optimize });
        tests.strip = strip;
        return .{ .libs = Libs.create(b, name, path, target, optimize, strip), .tests = tests };
    }
};

/// Build binaries from C code testing usage of libraries in a unity build (single translation unit) + static library build + shared library build
const FFI = struct {
    unity: *std.Build.Step.Compile,
    static: *std.Build.Step.Compile,
    shared: *std.Build.Step.Compile,
    fn create(
        b: *std.Build,
        lib_src_path: []const u8,
        lib_include_path: []const u8,
        static_lib: *std.Build.Step.Compile,
        shared_lib: *std.Build.Step.Compile,
        c_path: []const u8,
        c_flags: []const []const u8,
        target: std.zig.CrossTarget,
        optimize: std.builtin.Mode,
        strip: ?bool,
    ) FFI {
        return .{
            .unity = b: {
                const ffi = b.addExecutable(.{ .name = "ffi", .root_source_file = .{ .path = lib_src_path }, .target = target, .optimize = optimize });
                ffi.strip = strip;
                ffi.linkLibC();
                ffi.addSystemIncludePath(.{ .path = lib_include_path });
                ffi.addCSourceFile(.{ .file = .{ .path = c_path }, .flags = c_flags });
                break :b ffi;
            },
            .static = b: {
                const ffi = b.addExecutable(.{ .name = "ffi-static", .target = target, .optimize = optimize });
                ffi.strip = strip;
                ffi.linkLibC();
                ffi.linkLibrary(static_lib);
                ffi.addSystemIncludePath(.{ .path = lib_include_path });
                ffi.addCSourceFile(.{ .file = .{ .path = c_path }, .flags = c_flags });
                break :b ffi;
            },
            .shared = b: {
                const ffi = b.addExecutable(.{ .name = "ffi-shared", .target = target, .optimize = optimize });
                ffi.strip = strip;
                ffi.linkLibC();
                ffi.linkLibrary(shared_lib);
                ffi.addSystemIncludePath(.{ .path = lib_include_path });
                ffi.addCSourceFile(.{ .file = .{ .path = c_path }, .flags = c_flags });
                break :b ffi;
            },
        };
    }
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const strip = b.option(bool, "strip", "strip binaries");

    const lib_name = "kivi";
    const lib_src_path = "src/main.zig";
    const lib_include_path = "src/include";

    const c_ffi_path = "src/tests/ffi.c";
    const c_flags: []const []const u8 = switch (optimize) {
        // asserts in ffi.c go away in unsafe build modes, so we need to disable errors on unused variables
        .ReleaseFast, .ReleaseSmall => &.{ "-std=c17", "-pedantic", "-Wall", "-Werror", "-Wno-unused-variable" },
        .ReleaseSafe, .Debug => &.{ "-std=c17", "-pedantic", "-Wall", "-Werror" },
    };

    const targets = Targets.create(b, lib_name, lib_src_path, target, optimize, strip);

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
        lib_src_path,
        lib_include_path,
        targets.libs.static,
        targets.libs.shared,
        c_ffi_path,
        c_flags,
        target,
        optimize,
        strip,
    );

    const ffi_step = b.step("ffi", "Run FFI tests");

    const kivi = b.createModule(.{
        .source_file = .{ .path = "src/Kivi.zig" },
    });

    const codegen = b.addExecutable(.{
        .name = "codegen_generate",
        .root_source_file = .{ .path = "src/codegen/generate.zig" },
        .optimize = optimize,
        .target = target,
    });
    codegen.addModule("Kivi", kivi);
    const codegen_run = b.addRunArtifact(codegen);

    const codegen_step = b.step("codegen", "generate C header files");

    codegen_step.dependOn(&codegen_run.step);

    ffi.unity.step.dependOn(&codegen_run.step);
    ffi.static.step.dependOn(&codegen_run.step);
    ffi.shared.step.dependOn(&codegen_run.step);

    inline for (@typeInfo(FFI).Struct.fields) |field| {
        const run = b.addRunArtifact(@field(ffi, field.name));
        ffi_step.dependOn(&run.step);
    }

    test_step.dependOn(ffi_step);
}
