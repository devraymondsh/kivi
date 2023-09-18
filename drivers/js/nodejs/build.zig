const std = @import("std");

var optimize: std.builtin.OptimizeMode = undefined;
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

fn formatTarget(target: std.Target, allocator: std.mem.Allocator, suffix: []const u8, ext: []const u8) !std.ArrayList(u8) {
    const arch = @tagName(target.cpu.arch);
    const os = @tagName(target.os.tag);

    var string = std.ArrayList(u8).init(allocator);
    try string.writer().print("{s}-{s}-{s}.{s}", .{ suffix, arch, os, ext });

    return string;
}

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    optimize = b.standardOptimizeOption(.{});
    const target_info = try std.zig.system.NativeTargetInfo.detect(target);

    // Builds the addon
    const kivi_mod = b.createModule(.{
        .source_file = .{ .path = "../../../core/src/Kivi.zig" },
    });
    const shared = b.addSharedLibrary(.{ .name = "kivi-node-addon", .root_source_file = std.Build.LazyPath.relative("src/main.zig"), .target = target, .optimize = optimize });
    shared.force_pic = true;
    shared.linker_allow_shlib_undefined = true;
    shared.addModule("Kivi", kivi_mod);
    shared.addIncludePath(std.build.LazyPath.relative("src/napi-headers"));

    if (optimize == .ReleaseFast) {
        shared.strip = true;
        shared.single_threaded = true;
        if (target_info.target.os.tag != .macos) {
            shared.want_lto = true;
        }
    }

    // Adds the build to the install artifact
    var install_step = b.getInstallStep();
    b.installArtifact(shared);

    // Makes a proper .node file in order to be used in Nodejs
    const formatted_target_obj = try formatTarget(target_info.target, std.heap.page_allocator, "kivi-addon", "node");
    defer formatted_target_obj.deinit();
    const node_addon_install = b.addInstallFileWithDir(shared.getOutputSource(), .lib, formatted_target_obj.items);
    node_addon_install.step.dependOn(&shared.step);
    install_step.dependOn(&node_addon_install.step);

    // Adds `build all` command
    buildAll(b);
}
