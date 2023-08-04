const std = @import("std");

pub const KVMap = std.StringArrayHashMapUnmanaged([]const u8);

pub const KV = struct {
    map: KVMap,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) KV {
        return .{ .allocator = allocator, .map = KVMap{} };
    }
    pub fn deinit(self: *KV) void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.map.deinit(self.allocator);
    }

    pub fn get(self: *const KV, key: []const u8) ?[]const u8 {
        return self.map.get(key);
    }
    pub fn set(self: *KV, key: []const u8, value: []const u8) !void {
        const res = try self.map.getOrPut(self.allocator, key);
        if (res.found_existing) {
            self.allocator.free(res.key_ptr.*);
        }
        res.key_ptr.* = try self.allocator.dupe(u8, key);
        res.value_ptr.* = try self.allocator.dupe(u8, value);
    }
    pub fn rm(self: *KV, key: []const u8) void {
        if (self.map.getEntry(key)) |entry| {
            const orig_key = entry.key_ptr.*;

            self.allocator.free(entry.value_ptr.*);
            _ = self.map.swapRemove(key);
            self.allocator.free(orig_key);
        }
    }
};

test "basic" {
    var map = KV.init(std.testing.allocator);
    defer map.deinit();
}
test "items" {
    var map = KV.init(std.testing.allocator);
    defer map.deinit();

    try map.set("foo", "bar");

    const item = map.get("foo");
    try std.testing.expect(item != null);
    try std.testing.expect(std.mem.eql(u8, "bar", item.?));
}
