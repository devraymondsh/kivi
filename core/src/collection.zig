const std = @import("std");
const Mmap = @import("mmap.zig");
const main = @import("main.zig");

len: usize,
keysMmap: Mmap,
valuesMmap: Mmap,
allocator: std.mem.Allocator,
map: std.StringHashMapUnmanaged([]u8),

const Collection = @This();

pub fn init(allocator: std.mem.Allocator, config: *const main.Config) !Collection {
    return .{
        .len = 0,
        .allocator = allocator,
        .map = std.StringHashMapUnmanaged([]u8){},
        .keysMmap = try Mmap.init(config.keys_mmap_size, config.mmap_page_size),
        .valuesMmap = try Mmap.init(config.values_mmap_size, config.mmap_page_size),
    };
}
pub fn deinit(self: *Collection) void {
    self.map.deinit(self.allocator);
    self.keysMmap.deinit();
    self.valuesMmap.deinit();
}

pub fn set(self: *Collection, key: []const u8, value: []const u8) error{OutOfMemory}!void {
    const keys_push_res = self.keysMmap.push(key) catch return error.OutOfMemory;
    const values_push_res = self.valuesMmap.push(value) catch return error.OutOfMemory;

    try self.map.put(self.allocator, keys_push_res, values_push_res);
}
pub fn get(self: *Collection, key: []const u8) ?[]const u8 {
    return self.map.get(key);
}
pub fn rm(self: *Collection, key: []const u8) void {
    if (self.map.fetchRemove(key)) |kv| {
        @memset(@constCast(kv.key), 0);
        @memset(kv.value, 0);
    }
}
