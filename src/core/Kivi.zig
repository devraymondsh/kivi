const std = @import("std");
const ByteMap = @import("ByteMap.zig");
const FreeListAlloc = @import("FreeListAlloc.zig");

pub const Config = extern struct {
    // (2 ** 18) * 16 = 4194304
    group_size: usize = 262144,
    mem_size: usize = 1 * 1024 * 1024 * 1024,
};

map: ByteMap,
mem: FreeListAlloc,

const Kivi = @This();

fn stringcpy(dest: []u8, src: []const u8) !void {
    if (dest.len < src.len) {
        return error.SmallDestMemory;
    }
    @memcpy(dest[0..src.len], src);
}

pub fn init(self: *Kivi, config: *const Config) !usize {
    self.mem = try FreeListAlloc.init(config.mem_size);
    try self.map.init(&self.mem, config.group_size);

    return @sizeOf(Kivi);
}

pub fn reserve_key(self: *Kivi, size: usize) ![]u8 {
    return self.mem.alloc(u8, size);
}
pub fn reserve_value(self: *Kivi, size: usize) ![]u8 {
    return self.mem.alloc(u8, size);
}
pub fn put_entry(self: *Kivi, key: []u8, value: []u8) !void {
    return self.map.put(key, value);
}
pub fn set(self: *Kivi, key: []const u8, value: []const u8) !usize {
    const reserved_key = try self.reserve_key(key.len);
    const reserved_value = try self.reserve_value(value.len);
    try stringcpy(reserved_key, key);
    try stringcpy(reserved_value, value);

    try self.put_entry(reserved_key, reserved_value);

    return reserved_value.len;
}

pub fn get(self: *Kivi, key: []const u8) ![]u8 {
    if (self.map.get(key)) |value| {
        return value;
    } else {
        return error.NotFound;
    }
}
pub fn get_copy(self: *Kivi, key: []const u8, value: ?[]u8) !usize {
    const value_slice = try self.get(key);

    if (value != null) {
        try stringcpy(value.?, value_slice);
    }

    return value_slice.len;
}

pub fn del(self: *Kivi, key: []const u8) ![]u8 {
    if (self.map.del(&self.mem, key)) |value| {
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

    self.mem.free(value_slice);

    return value_slice_len;
}

pub fn rm(self: *Kivi, key: []const u8) !void {
    const value_slice = try self.del(key);
    self.mem.free(value_slice);
}

pub fn deinit(self: *Kivi) void {
    self.map.deinit();
    self.mem.deinit();
}
