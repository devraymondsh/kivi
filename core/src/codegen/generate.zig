const std = @import("std");
const Kivi = @import("Kivi");

const TypeMap = std.ComptimeStringMap([]const u8, .{
    .{ "usize", "const size_t" },
    .{ "*Kivi", "struct Kivi *const" },
    .{ "*const Kivi", "const struct Kivi *const" },
    .{ "?[*]u8", "char *const" },
    .{ "?*const main.Config", "const struct Config *const" },
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
        \\struct Config
        \\{{
        \\  size_t keys_mmap_size;
        \\  size_t mmap_page_size;
        \\  size_t values_mmap_size;
        \\}};
        \\struct Str
        \\{{
        \\  const char *ptr;
        \\  size_t len;
        \\}};
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
        if (std.mem.startsWith(u8, decl.name, "kivi_")) {
            const info = @typeInfo(@TypeOf(@field(Kivi, decl.name))).Fn;
            try writer.writeAll(
                \\// TODO: Behavior documented in these comments
                \\
            );
            try writer.writeAll(std.fmt.comptimePrint(
                "{s} {s}(",
                .{ comptime mapTypeStr(
                    info.return_type.?,
                    .{ .is_return_type = true },
                ), decl.name },
            ));
            inline for (info.params, 0..) |param, i| {
                if (i != 0) {
                    try writer.writeAll(", ");
                }
                try writer.writeAll(mapTypeStr(param.type.?, .{ .i = i }));
            }
            try writer.writeAll(");\n");
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
