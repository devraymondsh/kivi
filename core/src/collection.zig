const std = @import("std");
const mmap = @import("mmap.zig");
const Mmap = mmap.Mmap;

const testing = std.testing;

pub const MmapPositions = struct { key_starting_pos: usize, key_ending_pos: usize, value_starting_pos: usize, value_ending_pos: usize };
pub const MmapPositionsWithIndex = struct {
    index: usize,
    mmapPositions: MmapPositions,
};
pub const Collection = struct {
    len: usize,
    keysMmap: Mmap,
    valuesMmap: Mmap,
    allocator: std.mem.Allocator,
    mmapPositions: std.ArrayList(MmapPositions),

    pub fn init(allocator: std.mem.Allocator) !Collection {
        return .{
            .len = 0,
            .allocator = allocator,
            .mmapPositions = std.ArrayList(MmapPositions).init(allocator),
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
            const key_slice = self.keysMmap.read_slice(mmapPositions.key_starting_pos, mmapPositions.key_ending_pos);

            if (std.mem.eql(u8, key, key_slice)) {
                return MmapPositionsWithIndex{ .index = index, .mmapPositions = mmapPositions };
            }
        }

        return null;
    }
    pub fn set(self: *Collection, key: []const u8, value: []const u8) !void {
        const keys_push_res = try self.keysMmap.push(key);
        const values_push_res = try self.valuesMmap.push(value);

        try self.mmapPositions.append(.{
            .key_starting_pos = keys_push_res.starting_pos,
            .key_ending_pos = keys_push_res.ending_pos,
            .value_starting_pos = values_push_res.starting_pos,
            .value_ending_pos = values_push_res.ending_pos,
        });
    }
    pub fn get(self: *Collection, key: []const u8) ?[]const u8 {
        if (self.find_by_key(key)) |mmapPositionsWithIndex| {
            return self.valuesMmap.read_slice(mmapPositionsWithIndex.mmapPositions.value_starting_pos, mmapPositionsWithIndex.mmapPositions.value_ending_pos);
        }

        return null;
    }
    pub fn rm(self: *Collection, key: []const u8) void {
        if (self.find_by_key(key)) |mmapPositionsWithIndex| {
            const mmapPositions = self.mmapPositions.swapRemove(mmapPositionsWithIndex.index);

            @memset(self.keysMmap.read_slice(mmapPositions.key_starting_pos, mmapPositions.key_ending_pos), 0);
            @memset(self.valuesMmap.read_slice(mmapPositions.value_starting_pos, mmapPositions.value_ending_pos), 0);
        }
    }
};
