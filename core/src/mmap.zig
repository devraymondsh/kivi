const std = @import("std");

cursor: usize,
page_size: usize,
protected_mem_cursor: usize,
mem: []align(std.mem.page_size) u8,

const Mmap = @This();

fn mprotect(self: *Mmap) std.os.MProtectError!void {
    const protected_mem_cursor = self.protected_mem_cursor + self.page_size;
    try std.os.mprotect(@alignCast(self.mem[self.protected_mem_cursor..protected_mem_cursor]), std.os.PROT.READ | std.os.PROT.WRITE);

    self.protected_mem_cursor = protected_mem_cursor;
}

pub fn init(total_size: usize, page_size: usize) !Mmap {
    const mem = try std.os.mmap(
        null,
        std.mem.alignForward(usize, total_size, std.mem.page_size),
        std.os.PROT.NONE,
        std.os.MAP.ANONYMOUS | std.os.MAP.PRIVATE,
        -1,
        0,
    );

    var mmap = Mmap{ .mem = mem, .cursor = 0, .protected_mem_cursor = 0, .page_size = std.mem.alignForward(usize, page_size, std.mem.page_size) };
    mmap.mprotect() catch unreachable;

    return mmap;
}

pub fn push(self: *Mmap, data: []const u8) std.os.MProtectError![]u8 {
    const starting_pos = self.cursor;
    const ending_pos = starting_pos + data.len;

    if (ending_pos > self.protected_mem_cursor) {
        try self.mprotect();
    }

    const slice = self.mem[starting_pos..ending_pos];

    @memcpy(slice, data);

    self.cursor += ending_pos;

    return slice;
}

pub fn read_slice(self: *Mmap, from: usize, to: usize) []u8 {
    return self.mem[from .. from + to];
}

pub fn deinit(self: *Mmap) void {
    std.os.munmap(self.mem);
}
