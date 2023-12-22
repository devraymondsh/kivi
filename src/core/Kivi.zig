const std = @import("std");
const MMap = @import("Mmap.zig");
const StringHashMap = @import("Hashmap.zig").StringHashMap;

pub const Config = extern struct {
    maximum_elements: usize = 1_200_000,
    mem_size: usize = 1000 * 1024 * 1024,
};
const Entry = struct {
    key: ?[]u8,
    value: []u8,
};

mem: MMap,
entries: StringHashMap(Entry),
mem_allocator: std.mem.Allocator,

const Kivi = @This();

inline fn stringcpy(dest: []u8, src: []const u8) void {
    @memcpy(dest.ptr[0..src.len], src.ptr[0..src.len]);
}

pub fn init(self: *Kivi, config: *const Config) !usize {
    const maximum_elements = std.math.ceilPowerOfTwo(usize, config.maximum_elements) catch unreachable;
    self.mem = try MMap.init(config.mem_size);
    self.mem_allocator = self.mem.allocator();

    self.entries = StringHashMap(Entry){};
    try self.entries.ensureTotalCapacity(self.mem_allocator, @as(u32, @intCast(maximum_elements)));

    return @sizeOf(Kivi);
}

pub fn reserve_key(self: *Kivi, size: usize) ![]u8 {
    return self.mem_allocator.alloc(u8, size);
}
pub fn reserve(self: *Kivi, key: []u8, size: usize) ![]u8 {
    const value = try self.mem_allocator.alloc(u8, size);
    try self.entries.put(self.mem_allocator, key, Entry{ .key = key, .value = value });

    return value;
}
pub fn set(self: *Kivi, key: []const u8, value: []const u8) !usize {
    const key_slice = try self.reserve_key(key.len);
    const value_slice = try self.reserve(key_slice, value.len);

    stringcpy(key_slice, key);
    stringcpy(value_slice, value);

    return value_slice.len;
}

pub fn get_slice(self: *const Kivi, key: []const u8) ![]u8 {
    if (self.entries.get(key)) |value| {
        return value.value;
    } else {
        return error.NotFound;
    }
}
pub fn get(self: *const Kivi, key: []const u8, value: ?[]u8) !usize {
    const value_slice = try self.get_slice(key);

    if (value != null) {
        stringcpy(value.?, value_slice);
    }

    return value_slice.len;
}

pub fn del_slice(self: *Kivi, key: []const u8) ![]u8 {
    if (self.entries.fetchRemove(key)) |kv| {
        return kv.value.value;
    } else {
        return error.NotFound;
    }
}
pub fn del_value(self: *Kivi, value: []u8) void {
    self.mem_allocator.free(value);
}
pub fn del(self: *Kivi, key: []const u8, value: ?[]u8) !usize {
    const value_slice = try self.del_slice(key);
    const value_slice_len = value_slice.len;

    if (value != null) {
        stringcpy(value.?, value_slice);
    }

    self.del_value(value_slice);

    return value_slice_len;
}

pub fn deinit(self: *Kivi) void {
    self.mem.deinit();
}
