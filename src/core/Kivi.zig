const std = @import("std");
const MMap = @import("Mmap.zig");
const memsimd = @import("memsimd");
const ByteMap = @import("ByteMap.zig");

pub const Config = extern struct {
    maximum_elements: usize = 1_200_000,
    mem_size: usize = 1000 * 1024 * 1024,
};

mem: MMap,
entries: ByteMap,
mem_allocator: std.mem.Allocator,

const Kivi = @This();

fn stringcpy(dest: []u8, src: []const u8) !void {
    if (dest.len < src.len) {
        return error.SmallDestMemory;
    }
    @memcpy(dest[0..src.len], src);
}

pub fn init(self: *Kivi, config: *const Config) !usize {
    self.mem = try MMap.init(config.mem_size);
    self.mem_allocator = self.mem.allocator();

    self.entries = try ByteMap.init(self.mem_allocator, config.maximum_elements);

    return @sizeOf(Kivi);
}

pub fn reserve_key(self: *Kivi, size: usize) ![]u8 {
    return self.mem_allocator.alloc(u8, size);
}
pub fn reserve_value(self: *Kivi, size: usize) ![]u8 {
    return try self.mem_allocator.alloc(u8, size);
}
pub fn put_entry(self: *Kivi, key: []u8, value: []u8) !void {
    return self.entries.put(key, value);
}
pub fn set(self: *Kivi, key: []const u8, value: []const u8) !usize {
    const key_slice = try self.reserve_key(key.len);
    const value_slice = try self.reserve_value(value.len);
    try stringcpy(key_slice, key);
    try stringcpy(value_slice, value);

    try self.put_entry(key_slice, value_slice);

    return value_slice.len;
}

pub fn get(self: *const Kivi, key: []const u8) ![]u8 {
    if (self.entries.get(key)) |value| {
        return value;
    } else {
        return error.NotFound;
    }
}
pub fn get_copy(self: *const Kivi, key: []const u8, value: ?[]u8) !usize {
    const value_slice = try self.get(key);

    if (value != null) {
        try stringcpy(value.?, value_slice);
    }

    return value_slice.len;
}

pub fn free_value(self: *Kivi, value: []u8) void {
    self.mem_allocator.free(value);
}
pub fn del(self: *Kivi, key: []const u8) ![]u8 {
    if (self.entries.fetchRemove(key)) |value| {
        return value;
    } else {
        return error.NotFound;
    }
}
pub fn del_copy(self: *Kivi, key: []const u8, value: ?[]u8) !usize {
    const value_slice = try self.del(key);
    const value_slice_len = value_slice.len;

    if (value != null) {
        try stringcpy(value.?, value_slice);
    }

    self.free_value(value_slice);

    return value_slice_len;
}

pub fn rm(self: *Kivi, key: []const u8) !void {
    const value_slice = try self.del(key);
    self.free_value(value_slice);
}

pub fn deinit(self: *Kivi) void {
    self.mem.deinit();
}
