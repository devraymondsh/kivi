/// This is Byte(u8) hashmap implementation that relies on the caller to handle allocations and lifetimes.
const builtin = @import("builtin");
const Wyhash = @import("./Wyhash.zig");
const swift_lib = @import("swift_lib");

const Entry = struct {
    key: []u8,
    value: []u8,
};
const Group = struct {
    elements: [16]Entry,
};
const GroupMetadata = struct {
    // Full: 0xFF or 0b11111111
    // Empty: 0x0 or 0b00000000
    // Tombstone: 0x80 or 0b10000000
    elements: [16]u8,
};

fn nosimd_eql_byte(a: []const u8, b: []const u8) bool {
    @setRuntimeSafety(false);

    if (a.len != b.len) return false;

    for (a, b) |a_elem, b_elem| {
        if (a_elem != b_elem) return false;
    }
    return true;
}
fn simd_eql_byte(a: []const u8, b: []const u8) bool {
    @setRuntimeSafety(false);

    if (a.len != b.len) return false;
    if (a[0] != b[0]) {
        return false;
    }

    const rem: usize = a.len & 0xf;
    const len: usize = a.len -% rem;
    const ptra = a.ptr;
    const ptrb = b.ptr;

    var off: usize = 0;
    while (off < len) : (off +%= 16) {
        const xmm0: @Vector(16, u8) = ptra[off..][0..16].*;
        const xmm1: @Vector(16, u8) = ptrb[off..][0..16].*;
        if (!@reduce(.And, xmm0 == xmm1)) {
            return false;
        }
    }
    if (rem != 0) {
        if (!nosimd_eql_byte(a[off..a.len], b[off..b.len])) {
            return false;
        }
    }

    return true;
}
var eql_byte: *const fn ([]const u8, []const u8) bool = simd_eql_byte;

fn unlikely() void {
    @setCold(true);
}

const ByteMap = @This();

table: []Group,
table_metadata: []GroupMetadata,
table_size: usize,

var hasher = Wyhash.init(0);

pub fn init(self: *ByteMap, allocator: swift_lib.heap.Allocator, size: usize) !void {
    self.table_size = swift_lib.math.ceilPowerOfTwo(size);
    self.table_metadata = try allocator.alloc(GroupMetadata, self.table_size);
    self.table = try allocator.alloc(Group, self.table_size);

    for (0..self.table_size) |idx| {
        inline for (0..16) |inner_idx| {
            self.table_metadata[idx].elements[inner_idx] = 0x0;
        }
    }
}

fn hash(key: []const u8) usize {
    return hasher.reset_hash(@intCast(key.len), key);
}
fn hash_to_groupidx(self: *ByteMap, hashed: usize) usize {
    return (hashed >> 7) % self.table_size;
}
fn hash_to_elemidx(hashed: usize) usize {
    return (hashed & 0x7F) % 7;
}

fn mask_vec(metadata: @Vector(16, u8), mask: comptime_int) @Vector(16, bool) {
    return metadata == @as(@Vector(16, u8), @splat(mask));
}

const FoundEntity = struct { group_idx: usize, elem_idx: u4 };
fn find_index(self: *ByteMap, key: []const u8, comptime lookup: bool) ?FoundEntity {
    const hashed = hash(key);
    var groupidx = self.hash_to_groupidx(hashed);
    const elemidx = hash_to_elemidx(hashed);

    var searching_second_time = false;
    while (true) : (groupidx = (groupidx + 1) % self.table_size) {
        const group = &self.table[groupidx];
        const metadata = self.table_metadata[groupidx];
        const metadata_vec: @Vector(16, u8) = metadata.elements;
        const isempty_vec: @Vector(16, bool) = mask_vec(metadata_vec, 0x0);
        const isfull_vec: @Vector(16, bool) = mask_vec(metadata_vec, 0xFF);

        if (lookup) {
            for (elemidx..16) |idx| {
                if (isfull_vec[idx]) {
                    if (eql_byte(group.elements[idx].key, key)) {
                        return FoundEntity{
                            .group_idx = groupidx,
                            .elem_idx = @intCast(idx),
                        };
                    }
                } else if (isempty_vec[idx]) return null;
            }
            for (0..elemidx) |idx| {
                if (isfull_vec[idx]) {
                    if (eql_byte(group.elements[idx].key, key)) {
                        return FoundEntity{
                            .group_idx = groupidx,
                            .elem_idx = @intCast(idx),
                        };
                    }
                } else if (isempty_vec[idx]) return null;
            }
        } else {
            for (elemidx..16) |idx| {
                if (!isfull_vec[idx]) {
                    return FoundEntity{
                        .group_idx = groupidx,
                        .elem_idx = @intCast(idx),
                    };
                } else {
                    if (eql_byte(group.elements[idx].key, key)) {
                        return FoundEntity{
                            .group_idx = groupidx,
                            .elem_idx = @intCast(idx),
                        };
                    }
                }
            }
            for (0..elemidx) |idx| {
                if (!isfull_vec[idx]) {
                    return FoundEntity{
                        .group_idx = groupidx,
                        .elem_idx = @intCast(idx),
                    };
                } else {
                    if (eql_byte(group.elements[idx].key, key)) {
                        return FoundEntity{
                            .group_idx = groupidx,
                            .elem_idx = @intCast(idx),
                        };
                    }
                }
            }
        }

        if (groupidx >= (self.table_size - 1)) {
            unlikely();
            if (!searching_second_time) {
                groupidx = 0;
                searching_second_time = true;
            } else break;
        }
    }

    return null;
}

pub fn get(self: *ByteMap, key: []const u8) ?[]u8 {
    const found_entity = self.find_index(key, true);
    if (found_entity) |entity| {
        return self.table[entity.group_idx].elements[entity.elem_idx].value;
    }
    return null;
}
pub fn del(self: *ByteMap, allocator: swift_lib.heap.Allocator, key: []const u8) ?[]u8 {
    const found_entity = self.find_index(key, true);
    if (found_entity) |entity| {
        const entry = &self.table[entity.group_idx].elements[entity.elem_idx];
        allocator.free(entry.key);

        self.table_metadata[entity.group_idx].elements[entity.elem_idx] = 0x80;

        return entry.value;
    }
    return null;
}
pub fn put(self: *ByteMap, key: []u8, value: []u8) !void {
    const found_entity = self.find_index(key, false);
    if (found_entity) |entity| {
        const entry = &self.table[entity.group_idx].elements[entity.elem_idx];
        entry.key = key;
        entry.value = value;

        self.table_metadata[entity.group_idx].elements[entity.elem_idx] = 0xFF;
    } else return error.OutOfMemory;
}

pub fn deinit(self: *ByteMap) void {
    _ = self; // autofix
    // collisions = 0;
}
