const std = @import("std");
const MMap = @import("Mmap.zig");

pub const Config = extern struct {
    maximum_elments: usize = 3_125_000,
    mem_size: usize = 1000 * 1024 * 1024,
    mempage_size: usize = 200 * 1024 * 1024,
};
const Entry = struct {
    key: ?[]u8,
    value: []u8,
};

mem: MMap,
entries: []Entry,

const Kivi = @This();

fn upper_power_of_two(n_arg: u64) u64 {
    var n = n_arg;
    n -= 1;
    n |= n >> 1;
    n |= n >> 2;
    n |= n >> 4;
    n |= n >> 8;
    n |= n >> 16;
    n |= n >> 32;
    n += 1;

    return n;
}
inline fn key_to_possible_index(self: *const Kivi, key: []const u8) usize {
    return std.hash.Wyhash.hash(0, key) & (self.entries.len - 1);
}
inline fn stringcpy(dest: []u8, src: []const u8) void {
    @memcpy(dest.ptr[0..src.len], src.ptr[0..src.len]);
}

pub fn init_default_allocator(self: *Kivi, config: *const Config) !usize {
    const maximum_elements = upper_power_of_two(config.maximum_elments);
    self.mem = try MMap.init(config.mem_size, config.mempage_size);

    var reserved_entries = try self.mem.reserve(maximum_elements * @sizeOf(Entry));
    self.entries.ptr = @as([*]Entry, @ptrCast(@alignCast(reserved_entries.ptr)));
    self.entries.len = maximum_elements;
    @memset(self.entries, Entry{ .key = null, .value = undefined });

    return @sizeOf(Kivi);
}

pub fn init(config: *const Config) !Kivi {
    const maximum_elements = upper_power_of_two(config.maximum_elments);
    const mem = try MMap.init(config.mem_size, config.mempage_size);

    var reserved_entries = try mem.reserve(maximum_elements * @sizeOf(Entry));
    var entries: []Entry = .{
        .ptr = @as([*]Entry, @ptrCast(@alignCast(reserved_entries.ptr))),
        .len = maximum_elements,
    };
    @memset(entries, Entry{ .key = null, .value = undefined });

    return Kivi{ .entries = entries, .table_size = maximum_elements, .mem = mem };
}

pub fn comp(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) {
        return false;
    }

    var i: usize = 0;
    while (a.len > i) {
        var vec_a: @Vector(8, u8) = a.ptr[i..][0..8].*;
        var vec_b: @Vector(8, u8) = b.ptr[i..][0..8].*;
        if (!@reduce(.And, vec_a == vec_b)) {
            return false;
        }

        i += 8;
    }

    return true;
}

pub fn undo_reserve(self: *Kivi, slice: []u8) void {
    self.mem.cursor -= slice.len;
}
pub fn reserve_key(self: *Kivi, size: usize) ![]u8 {
    const key_cursor = self.mem.cursor;
    errdefer self.mem.cursor = key_cursor;

    return try self.mem.aligned_reserve(size);
}
pub fn reserve(self: *Kivi, key_slice: []u8, size: usize) ![]u8 {
    var retrying = false;
    var index = self.key_to_possible_index(key_slice);
    while (true) {
        if (self.entries[index].key == null) {
            const value_slice = try self.mem.reserve(size);
            self.entries[index] = Entry{
                .key = key_slice,
                .value = value_slice,
            };

            return value_slice;
        }

        index += 1;
        if (index >= self.entries.len) {
            if (!retrying) {
                index = 0;
                retrying = true;
            } else {
                break;
            }
        }
    }

    return error.NoFreeSlot;
}
pub fn set(self: *Kivi, key: []const u8, value: []const u8) !usize {
    const key_slice = try self.reserve_key(key.len);
    errdefer self.undo_reserve(key_slice);

    const value_slice = try self.reserve(key_slice, value.len);

    stringcpy(key_slice, key);
    stringcpy(value_slice, value);

    return value_slice.len;
}

pub fn get_slice(self: *const Kivi, key: []const u8) ![]u8 {
    var retrying = false;
    var index = self.key_to_possible_index(key);
    while (true) {
        if (self.entries[index].key) |indexed_key| {
            if (comp(key, indexed_key)) {
                return self.entries[index].value;
            }
        }

        index += 1;
        if (index >= self.entries.len) {
            if (!retrying) {
                index = 0;
                retrying = true;
            } else {
                break;
            }
        }
    }

    return error.NotFound;
}
pub fn get(self: *const Kivi, key: []const u8, value: ?[]u8) !usize {
    const value_slice = try self.get_slice(key);

    if (value != null) {
        stringcpy(value.?, value_slice);
    }

    return value_slice.len;
}

pub fn del_slice(self: *Kivi, key: []const u8) ![]u8 {
    var retrying = false;
    var index = self.key_to_possible_index(key);
    while (true) {
        if (self.entries[index].key) |indexed_key| {
            if (comp(key, indexed_key)) {
                self.mem.free(indexed_key);

                self.entries[index].key = null;

                return self.entries[index].value;
            }
        }

        index += 1;
        if (index >= self.entries.len) {
            if (!retrying) {
                index = 0;
                retrying = true;
            } else {
                break;
            }
        }
    }

    return error.NotFound;
}
pub fn del_value(self: *Kivi, value: []u8) void {
    self.mem.free(value);
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
