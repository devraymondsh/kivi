const std = @import("std");
const Kivi = @import("Kivi");

const TypeMap = std.ComptimeStringMap([]const u8, .{
    .{ "usize", "const size_t" },
    .{ "*Kivi", "const struct Kivi *const" },
    .{ "*const Kivi", "struct Kivi *const" },
    .{ "?[*]u8", "char *const" },
    .{ "[*]const u8", "const char *const" },
});

inline fn mapTypeStr(comptime T: type, comptime config: struct { is_return_type: bool = false, i: usize = 0 }) []const u8 {
    const str = std.fmt.comptimePrint("{}", .{T});
    const mapped = comptime TypeMap.get(str) orelse return str;
    if (std.mem.endsWith(u8, str, "u8")) {
        if (config.i == 1) return mapped ++ " key";
        if (config.i == 3) return mapped ++ " val";
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
        \\struct __attribute__((aligned({}))) CollectionOpaque
        \\{{
        \\  char __opaque[{}];
        \\}};
        \\struct CollectionInitResult
        \\{{
        \\  bool err;
        \\  struct CollectionOpaque collection_opq;
        \\}};
        \\
        \\void CollectionDeinit(struct CollectionOpaque *const map);
        \\struct CollectionInitResult CollectionInitOut(void);
        \\struct CollectionInitResult CollectionInitWithConfigOut(struct Config config);
        \\bool CollectionInit(struct CollectionOpaque *collection_opaque);
        \\bool CollectionInitWithConfig(struct Config config, struct CollectionOpaque *collection_opaque);
        \\
        \\struct Str CollectionGetOut(struct CollectionOpaque *const map, char const *const key, size_t const key_len);
        \\void CollectionGet(struct CollectionOpaque *const map, struct Str *str, char const *const key, size_t const key_len);
        \\struct Str CollectionRmOut(struct CollectionOpaque *const map, char const *const key, size_t const key_len);
        \\void CollectionRm(struct CollectionOpaque *const map, struct Str *str, char const *const key, size_t const key_len);
        \\
        \\// Zero means ok, so that means we return false(0) on success and return true(1) on failure
        \\bool CollectionSet(struct CollectionOpaque *const map, char const *const key,
        \\                   size_t const key_len, char const *const value,
        \\                   size_t const value_len);
        \\
        \\void setup_debug_handlers(void);
        \\void dump_stack_trace(void);
        \\
        \\
    , .{ @alignOf(Kivi), @sizeOf(Kivi) });
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
