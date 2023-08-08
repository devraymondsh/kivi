const std = @import("std");

/// Build static and shared libraries given name and path
const Libs = struct {
    static: *std.Build.Step.Compile,
    shared: *std.Build.Step.Compile,
    fn create(b: *std.Build, name: []const u8, path: []const u8, target: std.zig.CrossTarget, optimize: std.builtin.Mode) Libs {
        return .{
            .static = b.addStaticLibrary(.{ .name = name, .root_source_file = .{ .path = path }, .target = target, .optimize = optimize }),
            .shared = b.addSharedLibrary(.{ .name = name, .root_source_file = .{ .path = path }, .target = target, .optimize = optimize }),
        };
    }
};

/// Build libs + test-running binary given name and path
const Targets = struct {
    libs: Libs,
    tests: *std.Build.Step.Compile,
    fn create(b: *std.Build, name: []const u8, path: []const u8, target: std.zig.CrossTarget, optimize: std.builtin.Mode) Targets {
        return .{
            .libs = Libs.create(b, name, path, target, optimize),
            .tests = b.addTest(.{ .root_source_file = .{ .path = path }, .target = target, .optimize = optimize }),
        };
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
        static_lib: *std.Build.Step.Compile,
        shared_lib: *std.Build.Step.Compile,
        c_path: []const u8,
        c_flags: []const []const u8,
        target: std.zig.CrossTarget,
        optimize: std.builtin.Mode,
    ) FFI {
        return .{
            .unity = b: {
                const ffi = b.addExecutable(.{ .name = "ffi", .root_source_file = .{ .path = lib_src_path }, .target = target, .optimize = optimize });
                ffi.linkLibC();
                ffi.addCSourceFile(.{ .file = .{ .path = c_path }, .flags = c_flags });
                break :b ffi;
            },
            .static = b: {
                const ffi = b.addExecutable(.{ .name = "ffi-static", .target = target, .optimize = optimize });
                ffi.linkLibC();
                ffi.linkLibrary(static_lib);
                ffi.addCSourceFile(.{ .file = .{ .path = c_path }, .flags = c_flags });
                break :b ffi;
            },
            .shared = b: {
                const ffi = b.addExecutable(.{ .name = "ffi-shared", .target = target, .optimize = optimize });
                ffi.linkLibC();
                ffi.linkLibrary(shared_lib);
                ffi.addCSourceFile(.{ .file = .{ .path = c_path }, .flags = c_flags });
                break :b ffi;
            },
        };
    }
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_name = "core";
    const lib_src_path = "src/main.zig";

    const c_ffi_path = "src/tests/ffi.c";
    const c_flags = &.{ "-std=c17", "-pedantic", "-Wall", "-Werror" };

    const targets = Targets.create(b, lib_name, lib_src_path, target, optimize);

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
        targets.libs.static,
        targets.libs.shared,
        c_ffi_path,
        c_flags,
        lib_src_path,
        target,
        optimize,
    );
    const ffi_step = b.step("ffi", "Run FFI tests");
    inline for (@typeInfo(FFI).Struct.fields) |field| {
        const run = b.addRunArtifact(@field(ffi, field.name));
        ffi_step.dependOn(&run.step);
    }

    test_step.dependOn(ffi_step);
}
