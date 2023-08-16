const std = @import("std");
const Kivi = @import("Kivi");

const TypeMap = std.ComptimeStringMap([]const u8, .{
    .{ "usize", "const size_t" },
    .{ "*Kivi", "struct Kivi *const" },
    .{ "*const Kivi", "const struct Kivi *const" },
    .{ "?[*]u8", "char *const" },
    .{ "?*const Kivi.Config", "const struct Config *const" },
    .{ "[*]const u8", "const char *const" },
});

inline fn mapTypeStr(comptime T: type, comptime config: struct { is_return_type: bool = false, i: usize = 0 }) []const u8 {
    const str = std.fmt.comptimePrint("{}", .{T});
    // @compileLog(str);
    const mapped = comptime TypeMap.get(str) orelse return str;
    if (std.mem.endsWith(u8, str, "u8")) {
        if (config.i == 1) return mapped ++ " key";
        if (config.i == 3) return mapped ++ " val";
    }
    if (std.mem.endsWith(u8, str, "Config")) {
        return mapped ++ " config";
    }
    if (std.mem.eql(u8, str, "usize")) {
        if (config.i == 2) return mapped ++ " key_len";
        if (config.i == 4) return mapped ++ " val_len";
    }
    if (config.is_return_type and std.mem.eql(u8, str, "usize")) {
        return "size_t";
    }
    return mapped;
}

fn generate_C_headers(writer: anytype) !void {
    try writer.print(
        \\#pragma once
        \\
        \\#include <stdbool.h>
        \\#include <stddef.h>
        \\
        \\// Debugging symbols
        \\void dump_stack_trace(void);
        \\void setup_debug_handlers(void);
        \\
        \\
    , .{});
    try writer.print(
        \\struct __attribute__((aligned({}))) Kivi {{
        \\  char __opaque[{}];
        \\}};
        \\
        \\
    , .{ @alignOf(Kivi), @sizeOf(Kivi) });
    inline for (@typeInfo(Kivi).Struct.decls) |decl| {
        if (std.mem.startsWith(u8, decl.name, "kivi_") or std.mem.eql(u8, decl.name, "Config")) {
            const value = @field(Kivi, decl.name);
            const info = @typeInfo(@TypeOf(value));
            switch (info) {
                .Type => switch (@typeInfo(value)) {
                    .Struct => |s| {
                        try writer.print("struct {s} {{\n", .{decl.name});
                        inline for (s.fields) |field| {
                            try writer.print("  {s} {s};\n", .{ mapTypeStr(field.type, .{ .is_return_type = true }), field.name });
                        }
                        try writer.writeAll("};\n\n");
                    },
                    inline else => |tag| @compileError("Unhandled case: " ++ @tagName(tag)),
                },
                .Fn => |f| {
                    try writer.writeAll(
                        \\// TODO: Behavior documented in these comments
                        \\
                    );
                    try writer.writeAll(std.fmt.comptimePrint(
                        "{s} {s}(",
                        .{ comptime mapTypeStr(
                            f.return_type.?,
                            .{ .is_return_type = true },
                        ), decl.name },
                    ));
                    inline for (f.params, 0..) |param, i| {
                        if (i != 0) {
                            try writer.writeAll(", ");
                        }
                        try writer.writeAll(mapTypeStr(param.type.?, .{ .i = i }));
                    }
                    try writer.writeAll(");\n");
                },
                else => @compileError("Unhandled case: " ++ @tagName(info)),
            }
        }
    }
}

fn generate_TypeScript_Types(writer: anytype) !void {
    _ = writer;
    // TODO: 😎
}

pub fn main() !void {
    const file = try std.fs.cwd().createFile("src/headers/bindings.h", .{});
    var output = std.io.bufferedWriter(file.writer());
    defer output.flush() catch {};
    const writer = output.writer();
    try generate_C_headers(writer);
}
