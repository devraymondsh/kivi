const std = @import("std");
const Mmap = @import("mmap.zig");

pub const MmapPositions = struct { key_slice: []u8, value_slice: []u8 };
pub const MmapPositionsWithIndex = struct {
    index: usize,
    mmapPositions: MmapPositions,
};

len: usize,
keysMmap: Mmap,
valuesMmap: Mmap,
allocator: std.mem.Allocator,
mmapPositions: std.ArrayListUnmanaged(MmapPositions),

const Collection = @This();

pub fn init(allocator: std.mem.Allocator) !Collection {
    return .{
        .len = 0,
        .allocator = allocator,
        .mmapPositions = std.ArrayListUnmanaged(MmapPositions){},
        .keysMmap = try Mmap.init(std.mem.page_size * 5, std.mem.page_size),
        .valuesMmap = try Mmap.init(std.mem.page_size * 5, std.mem.page_size),
    };
}
pub fn deinit(self: *Collection) void {
    self.keysMmap.deinit();
    self.valuesMmap.deinit();
}

fn find_by_key(self: *Collection, key: []const u8) ?MmapPositionsWithIndex {
    for (self.mmapPositions.items, 0..) |mmapPositions, index| {
        if (std.mem.eql(u8, key, mmapPositions.key_slice)) {
            return MmapPositionsWithIndex{ .index = index, .mmapPositions = mmapPositions };
        }
    }

    return null;
}
pub fn set(self: *Collection, key: []const u8, value: []const u8) error{OutOfMemory}!void {
    const keys_push_res = self.keysMmap.push(key) catch return error.OutOfMemory;
    const values_push_res = self.valuesMmap.push(value) catch return error.OutOfMemory;

    try self.mmapPositions.append(self.allocator, .{
        .key_slice = keys_push_res,
        .value_slice = values_push_res,
    });
}
pub fn get(self: *Collection, key: []const u8) ?[]const u8 {
    if (self.find_by_key(key)) |mmapPositionsWithIndex| {
        return @alignCast(mmapPositionsWithIndex.mmapPositions.value_slice);
    }

    return null;
}
pub fn rm(self: *Collection, key: []const u8) void {
    if (self.find_by_key(key)) |mmapPositionsWithIndex| {
        const mmapPositions = self.mmapPositions.swapRemove(mmapPositionsWithIndex.index);

        @memset(mmapPositions.key_slice, 0);
        @memset(mmapPositions.value_slice, 0);
    } else {
        std.debug.panic("Didn't found!", .{});
    }
}
