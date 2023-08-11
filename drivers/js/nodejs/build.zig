const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const c_flags: []const []const u8 = switch (optimize) {
        // asserts in ffi.c go away in unsafe build modes, so we need to disable errors on unused variables
        .ReleaseFast, .ReleaseSmall => &.{ "-std=c17", "-pedantic", "-Wall", "-Werror", "-Wno-unused-variable" },
        .ReleaseSafe, .Debug => &.{ "-std=c17", "-pedantic", "-Wall" },
    };

    const shared = b.addSharedLibrary(.{ .name = "node", .target = target, .optimize = optimize });
    shared.linkLibC();
    shared.addCSourceFile(.{ .flags = c_flags, .file = std.build.LazyPath.relative("src/main.c") });
    shared.addLibraryPath(std.build.LazyPath.relative("../../../core/zig-out/lib"));
    shared.linkSystemLibrary2("kivi", .{ .preferred_link_mode = .Static });

    const currentDir = std.fs.cwd();
    const includeDir = try currentDir.openDir("src/include", .{});
    if (includeDir.openFile("node_api.h", .{})) |_| {} else |_| {
        const execRes = try std.ChildProcess.exec(.{ .allocator = std.heap.page_allocator, .argv = &[_][]const u8{ "npm", "run", "install-headers" } });

        if (execRes.term.Exited == 0) {
            std.debug.print("{s}", .{execRes.stdout});
        } else {
            std.debug.print("{s}", .{execRes.stderr});
        }
    }

    shared.addIncludePath(std.build.LazyPath.relative("src/include"));
    b.installArtifact(shared);
}
