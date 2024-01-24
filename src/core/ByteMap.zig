/// This is Byte(u8) hashmap implementation that relies on the caller to handle allocations and lifetimes.
const memsimd = @import("memsimd");
const builtin = @import("builtin");
const Wyhash = @import("./Wyhash.zig");
const Math = @import("Math.zig");
const Mmap = @import("./Mmap.zig");

// Key == null and value == null : empty slot
// Key == null and value != null : tombstone
const Entry = struct {
    key: ?[]u8 = null,
    value: ?[]u8 = null,
};

// pub const CrtlEmpty: u8 = 0b10000000;
// pub const CrtlDeleted: u8 = 0b11111110;
// pub const CrtlSentinel: u8 = 0b11111111;
// const Crtl = packed struct(u8) {
//     Empty: u8 = CrtlEmpty,
// };
// fn h1(hash: usize) usize {
//     return hash >> 7;
// }
// fn h2(hash: usize) Crtl {
//     return hash & 0x7f;
// }

fn nosimd_eql_byte(a: []const u8, b: []const u8) bool {
    return memsimd.nosimd.eql(u8, a, b);
}
var eql_bye_nocheck: *const fn ([]const u8, []const u8) bool = nosimd_eql_byte;
fn eql_byte(a: []const u8, b: []const u8) bool {
    @setRuntimeSafety(false);

    if (a.len != b.len) return false;
    if (a.ptr == b.ptr) return true;
    if (a.len == 0) return true;
    if (a[0] != b[0]) {
        return false;
    }

    return eql_bye_nocheck(a, b);
}

fn unlikely() void {
    @setCold(true);
}

const ByteMap = @This();

table: []Entry,
table_size: usize,

var hasher = Wyhash.init(0);

pub fn init(self: *ByteMap, allocator: *Mmap, size_arg: usize) !void {
    self.table_size = @intCast(Math.ceilPowerOfTwo(@intCast(size_arg)));
    self.table = try allocator.alloc(Entry, self.table_size);

    for (0..self.table_size) |idx| {
        self.table[idx].key = null;
        self.table[idx].value = null;
    }

    if (memsimd.is_x86_64) {
        eql_bye_nocheck = memsimd.avx.eql_byte_nocheck;
    } else if (memsimd.is_aarch64) {
        eql_bye_nocheck = memsimd.sve.eql_byte_nocheck;
    }
}

fn get_index(self: *ByteMap, key: []const u8) usize {
    return hasher.reset_hash(@intCast(key.len), key) & (self.table_size - 1);
}

fn find_entry(self: *ByteMap, key: []const u8, comptime insertion: bool) ?*Entry {
    var index = self.get_index(key);
    var searching_second_time = false;

    while (true) {
        const entry = &self.table[index];
        const null_key = entry.key == null;
        const null_value = entry.value == null;

        if (!insertion) {
            if (null_key) {
                if (null_value) {
                    return null;
                } else index += 1;
            } else {
                if (eql_byte(key, entry.key.?)) {
                    return entry;
                } else index += 1;
            }
        } else {
            if (null_key) {
                return entry;
            }
            if (eql_byte(key, entry.key.?)) {
                return entry;
            } else {
                index += 1;
            }
        }

        if (index >= (self.table_size - 1)) {
            unlikely();
            if (!searching_second_time) {
                index = 0;
                searching_second_time = true;
            } else break;
        }
    }
    return null;
}

pub fn get(self: *ByteMap, key: []const u8) ?[]u8 {
    const found_entry = self.find_entry(key, false);
    if (found_entry) |entry| return entry.value.?;
    return null;
}
pub fn del(self: *ByteMap, allocator: *Mmap, key: []const u8) ?[]u8 {
    const found_entry = self.find_entry(key, false);
    if (found_entry) |entry| {
        allocator.free(entry.key.?);
        entry.*.key = null;
        return entry.value.?;
    }
    return null;
}
pub fn put(self: *ByteMap, key: []u8, value: []u8) !void {
    const found_entry = self.find_entry(key, true);
    if (found_entry) |entry| {
        entry.key = key;
        entry.value = value;
        return;
    }
    return error.OutOfMemory;
}

pub fn deinit(self: *ByteMap) void {
    _ = self; // autofix
    // collisions = 0;
}
