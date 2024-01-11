const std = @import("std");
const memsimd = @import("memsimd");
const builtin = @import("builtin");

const Entry = struct {
    key: ?[]u8,
    value: []u8,
};

const ByteMap = @This();

mem: []Entry,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, size_arg: usize) !ByteMap {
    const size = try std.math.ceilPowerOfTwo(usize, size_arg);
    const mem = try allocator.alloc(Entry, size);
    @memset(mem, Entry{ .key = null, .value = undefined });
    return ByteMap{ .allocator = allocator, .mem = mem };
}

pub fn get(self: *const ByteMap, key: []const u8) ?[]u8 {
    _ = self; // autofix
    _ = key; // autofix
    return null;
}

pub fn remove(self: *ByteMap, key: []const u8) void {
    _ = self; // autofix
    _ = key; // autofix
    return;
}

pub fn fetchRemove(self: *ByteMap, key: []const u8) ?[]u8 {
    _ = self; // autofix
    _ = key; // autofix
    return null;
}

pub fn put(self: *ByteMap, key: []const u8, value: []const u8) !void {
    _ = self; // autofix
    _ = value; // autofix
    _ = key; // autofix
    return;
}
