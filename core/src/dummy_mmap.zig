const std = @import("std");
const testing = std.testing;

const KeyValuePair = struct {
    key: []const u8,
    value: []const u8,
};

pub const Mmap = struct {
    mem: []align(std.mem.page_size) u8,

    pub fn init(size: usize) !Mmap {
        const mem = try std.os.mmap(
            null,
            std.mem.alignForward(usize, size, std.mem.page_size),
            std.os.PROT.READ | std.os.PROT.WRITE,
            std.os.MAP.MAP_ANONYMOUS,
            -1,
            0,
        );

        return Mmap{ .mem = mem };
    }

    pub fn write_slice(self: *Mmap, data: []const u8, offset: usize) void {
        @memcpy(self.mem[offset .. offset + data.len], data);
    }

    pub fn read_slice(self: *Mmap, offset: usize, length: usize) []u8 {
        return self.mem[offset .. offset + length];
    }

    pub fn deinit(self: *Mmap) void {
        std.os.munmap(self.mem);
        self.mem = undefined;
    }
};

test "basic functionality" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    _ = allocator;

    var mmap = try Mmap.init(50 * 1024); // tests can return errors, fails the test

    defer {
        mmap.deinit();
        std.debug.assert(gpa.deinit() == .ok);
    }

    mmap.write("Hi there", 0);
}
