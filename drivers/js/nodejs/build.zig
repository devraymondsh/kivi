const std = @import("std");

fn npmInstallFn(self: *std.build.Step, progress: *std.Progress.Node) !void {
    _ = progress;
    if (std.fs.cwd().openDir("node_modules/node-api-headers", .{})) |_| {} else |_| {
        try self.evalChildProcess(&[_][]const u8{ "npm", "install" });
    }
}

fn formatTarget(target: std.Target, allocator: std.mem.Allocator, suffix: []const u8, ext: []const u8) !std.ArrayList(u8) {
    const arch = @tagName(target.cpu.arch);
    const os = @tagName(target.os.tag);
    const abi = @tagName(target.abi);

    var string = std.ArrayList(u8).init(allocator);
    try string.writer().print("{s}-{s}-{s}-{s}.{s}", .{ arch, os, abi, suffix, ext });

    return string;
}

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Installs required headers
    var npmi_step = b.step("npm-install", "Install npm packages");
    npmi_step.makeFn = npmInstallFn;

    // Builds the addon
    const kivi_mod = b.createModule(.{
        .source_file = .{ .path = "../../../core/src/Kivi.zig" },
    });
    const shared = b.addSharedLibrary(.{ .name = "addon", .root_source_file = std.Build.LazyPath.relative("src/main.zig"), .target = target, .optimize = optimize });
    shared.addModule("Kivi", kivi_mod);
    shared.linker_allow_shlib_undefined = true;
    shared.addIncludePath(std.build.LazyPath.relative("node_modules/node-api-headers/include"));

    if (optimize == .ReleaseFast) {
        shared.strip = true;
    }

    // Adds the build to the install artifact
    var install_step = b.getInstallStep();
    install_step.dependOn(npmi_step);
    b.installArtifact(shared);

    // Makes an `addon.node` file in order to be used in Nodejs
    const native_target_info = try std.zig.system.NativeTargetInfo.detect(target);
    const native_target = try formatTarget(native_target_info.target, std.heap.page_allocator, "kivi-addon", "node");
    defer native_target.deinit();
    const node_addon_install = b.addInstallFileWithDir(shared.getOutputSource(), .lib, native_target.items);
    node_addon_install.step.dependOn(&shared.step);
    install_step.dependOn(&node_addon_install.step);

    // var build_all = b.step("all", "Build for all targets");
    // build_all.dependOn(&node_addon_install.step);
}
