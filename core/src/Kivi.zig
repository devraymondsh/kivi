const std = @import("std");
const MMap = @import("Mmap.zig");
const GPA = std.heap.GeneralPurposeAllocator(.{});

pub const Config = extern struct {
    maximum_elments: usize = 4_000_000,
    keys_mem_size: usize = 500 * 1024 * 1024,
    keys_page_size: usize = 100 * 1024 * 1024,
    values_mem_size: usize = 1000 * 1024 * 1024,
    values_page_size: usize = 200 * 1024 * 1024,
};
const Entry = struct {
    key: ?[]u8,
    value: []u8,
};

allocator: std.mem.Allocator,
entries: []Entry,
gpa: bool = false,
keys_mmap: MMap,
values_mmap: MMap,

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
fn key_to_possible_index(self: *const Kivi, key: []const u8) usize {
    return std.hash.Wyhash.hash(0, key) & (self.entries.len - 1);
}

pub fn init_default_allocator(self: *Kivi, config: *const Config) !usize {
    var gpa = GPA{};
    const heap_gpa = try gpa.allocator().create(GPA);
    heap_gpa.* = gpa;

    const maximum_elements = upper_power_of_two(config.maximum_elments);

    self.allocator = heap_gpa.allocator();
    const entries = try self.allocator.alloc(Entry, maximum_elements);
    @memset(entries, Entry{ .key = null, .value = undefined });

    self.gpa = true;
    self.entries = entries;
    self.keys_mmap = try MMap.init(config.keys_mem_size, config.keys_page_size);
    self.values_mmap = try MMap.init(config.values_mem_size, config.values_page_size);

    return @sizeOf(Kivi);
}

pub fn init(allocator: std.mem.Allocator, config: *const Config) !Kivi {
    const maximum_elements = upper_power_of_two(config.maximum_elments);
    const entries = try allocator.alloc(Entry, maximum_elements);
    const keys_mmap = try MMap.init(config.keys_mem_size, config.keys_page_size);
    const values_mmap = try MMap.init(config.values_mem_size, config.values_page_size);

    @memset(entries, Entry{ .key = null, .value = undefined });

    return Kivi{ .allocator = allocator, .entries = entries, .table_size = maximum_elements, .keys_mmap = keys_mmap, .values_mmap = values_mmap };
}

pub fn set(self: *Kivi, key: []const u8, value: []const u8) !usize {
    const key_cursor = self.keys_mmap.cursor;
    errdefer self.keys_mmap.cursor = key_cursor;

    var retrying = false;
    var rehashing = false;
    var index = self.key_to_possible_index(key);
    while (true) {
        if (self.entries[index].key == null) {
            self.entries[index] = Entry{
                .key = try self.keys_mmap.push(key),
                .value = try self.values_mmap.push(value),
            };

            return value.len;
        }

        index += 1;
        if (index >= self.entries.len) {
            if (!rehashing) {
                index = self.key_to_possible_index(key);
                rehashing = true;
            } else {
                if (!retrying) {
                    index = 0;
                    retrying = true;
                } else {
                    break;
                }
            }
        }
    }

    return error.NoFreeSlot;
}

pub fn get(self: *const Kivi, key: []const u8, value: ?[]u8) !usize {
    var retrying = false;
    var rehashing = false;
    var index = self.key_to_possible_index(key);
    while (true) {
        const entry = self.entries[index];
        if (entry.key != null) {
            if (std.mem.eql(u8, key, entry.key.?)) {
                if (value != null) {
                    @memcpy(value.?[0..entry.value.len], entry.value.ptr[0..entry.value.len]);
                }

                return entry.value.len;
            }
        } else {
            return error.NotFound;
        }

        index += 1;
        if (index >= self.entries.len) {
            if (!rehashing) {
                index = self.key_to_possible_index(key);
                rehashing = true;
            } else {
                if (!retrying) {
                    index = 0;
                    retrying = true;
                } else {
                    break;
                }
            }
        }
    }

    return error.NotFound;
}

pub fn del(self: *const Kivi, key: []const u8, value: ?[]u8) !usize {
    var retrying = false;
    var rehashing = false;
    var index = self.key_to_possible_index(key);
    while (true) {
        var entry = self.entries[index];
        if (entry.key != null) {
            if (std.mem.eql(u8, key, entry.key.?)) {
                if (value != null) {
                    @memcpy(value.?[0..entry.value.len], entry.value.ptr[0..entry.value.len]);
                }

                self.entries[index].key = null;

                return entry.value.len;
            }
        } else {
            return error.NotFound;
        }

        index += 1;
        if (index >= self.entries.len) {
            if (!rehashing) {
                index = self.key_to_possible_index(key);
                rehashing = true;
            } else {
                if (!retrying) {
                    index = 0;
                    retrying = true;
                } else {
                    break;
                }
            }
        }
    }

    return error.NotFound;
}

pub fn deinit(self: *Kivi) void {
    self.keys_mmap.deinit();
    self.values_mmap.deinit();

    self.allocator.free(self.entries);
    if (self.gpa) {
        var gpa_ptr: *GPA = @alignCast(@ptrCast(self.allocator.ptr));
        var gpa = gpa_ptr.*;
        gpa.allocator().destroy(gpa_ptr);
        std.debug.assert(gpa.deinit() == .ok);
    }
}
