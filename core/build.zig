const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const slib = b.addStaticLibrary(.{
        .name = "core",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    const dlib = b.addSharedLibrary(.{
        .name = "core",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(slib);
    b.installArtifact(dlib);

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    const ffi_test = b.addExecutable(.{ .name = "ffi-test" });
    ffi_test.linkLibC();
    ffi_test.linkLibrary(dlib);
    ffi_test.addCSourceFile(.{
        .file = .{ .path = "src/tests/ffi.c" },
        .flags = &.{
            "-std=c17",
            "-pedantic",
            "-Wall",
            "-W",
        },
    });
    const run_ffi_tests = b.addRunArtifact(ffi_test);
    _ = run_ffi_tests;
    // test_step.dependOn(&run_ffi_tests.step);
}
