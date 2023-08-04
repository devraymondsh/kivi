const std = @import("std");
const testing = std.testing;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub const MmapPositions = struct { key_starting_pos: usize, key_ending_pos: usize, value_starting_pos: usize, value_ending_pos: usize };
pub const Collection = struct {
    len: usize,
    keysMmap: Mmap,
    valuesMmap: Mmap,
    mmapPositions: std.ArrayList(MmapPositions),

    pub fn init() !Collection {
        return .{
            .len = 0,
            .mmapPositions = std.ArrayList(MmapPositions).init(allocator),
            .keysMmap = try Mmap.init(std.mem.page_size),
            .valuesMmap = try Mmap.init(std.mem.page_size),
        };
    }
    pub fn deinit(self: *Collection) void {
        self.keysMmap.deinit();
        self.valuesMmap.deinit();
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
        for (self.mmapPositions.toOwnedSlice() catch return null) |mmapPositions| {
            const key_slice = self.keysMmap.read_slice(mmapPositions.key_starting_pos, mmapPositions.key_ending_pos);

            if (std.mem.eql(u8, key, key_slice)) {
                return self.valuesMmap.read_slice(mmapPositions.value_starting_pos, mmapPositions.value_ending_pos);
            }
        }

        return null;
    }
    pub fn rm(self: *Collection, key: []const u8) void {
        _ = key;
        _ = self;
    }
};

const MmapErrors = error{OutOfBounds};
const MmmapIndecies = struct { starting_pos: usize, ending_pos: usize };
pub const Mmap = struct {
    cursor: usize,
    mem: []align(std.mem.page_size) u8,

    pub fn init(size: usize) !Mmap {
        const mem = try std.os.mmap(
            null,
            std.mem.alignForward(usize, size, std.mem.page_size),
            std.os.PROT.READ | std.os.PROT.WRITE,
            std.os.MAP.ANONYMOUS,
            -1,
            0,
        );

        return Mmap{ .mem = mem, .cursor = 0 };
    }

    pub fn push(self: *Mmap, data: []const u8) MmapErrors!MmmapIndecies {
        const starting_pos = self.cursor;
        const ending_pos = starting_pos + data.len;

        if (ending_pos <= self.mem.len) {
            @memcpy(self.mem[starting_pos..ending_pos], data);

            self.cursor += ending_pos;

            return MmmapIndecies{ .starting_pos = starting_pos, .ending_pos = ending_pos };
        }

        return MmapErrors.OutOfBounds;
    }

    pub fn read_slice(self: *Mmap, from: usize, to: usize) []u8 {
        return self.mem[from .. from + to];
    }

    pub fn deinit(self: *Mmap) void {
        std.os.munmap(self.mem);
        self.mem = undefined;
    }
};

// test "basic functionality" {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const allocator = gpa.allocator();
//     _ = allocator;

//     var mmap = try Mmap.init(50 * 1024); // tests can return errors, fails the test

//     defer {
//         mmap.deinit();
//         std.debug.assert(gpa.deinit() == .ok);
//     }

//     mmap.write("Hi there", 0);
// }
