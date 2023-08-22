const std = @import("std");

fn npmInstallFn(self: *std.build.Step, progress: *std.Progress.Node) !void {
    _ = progress;
    if (std.fs.cwd().openDir("node_modules/node-api-headers", .{})) |_| {} else |_| {
        try self.evalChildProcess(&[_][]const u8{ "npm", "install" });
    }
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
    const shared = b.addSharedLibrary(.{ .name = "addon", .root_source_file = std.Build.LazyPath.relative("src/main.zig"), .target = target, .optimize = optimize, .single_threaded = true });
    shared.addModule("Kivi", kivi_mod);
    shared.addSystemIncludePath(std.build.LazyPath.relative("node_modules/node-api-headers/include"));

    if (optimize == .ReleaseFast) {
        shared.strip = true;
    }

    // Adds the build to the install artifact
    var install_step = b.getInstallStep();
    install_step.dependOn(npmi_step);
    b.installArtifact(shared);

    // Makes an `addon.node` file in order to be used in Nodejs
    const node_addon_install = b.addInstallFileWithDir(shared.getOutputSource(), .lib, "addon.node");
    node_addon_install.step.dependOn(&shared.step);
    install_step.dependOn(&node_addon_install.step);
}
