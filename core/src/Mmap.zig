const std = @import("std");
const builtin = @import("builtin");

const is_windows: bool = builtin.os.tag == .windows;

cursor: usize,
page_size: usize,
protected_mem_cursor: usize,
mem: []align(std.mem.page_size) u8,

const Mmap = @This();

fn mprotect(self: *Mmap) !void {
    const protected_mem_cursor = self.protected_mem_cursor + self.page_size;

    if (!is_windows) {
        try std.os.mprotect(@alignCast(self.mem[self.protected_mem_cursor..protected_mem_cursor]), std.os.PROT.READ | std.os.PROT.WRITE);
    } else {
        _ = try std.os.windows.VirtualAlloc(@ptrCast(@alignCast(self.mem)), protected_mem_cursor, std.os.windows.MEM_COMMIT, std.os.windows.PAGE_READWRITE);
    }

    self.protected_mem_cursor = protected_mem_cursor;
}

pub fn init(total_size: usize, page_size: usize) !Mmap {
    var mem: []align(std.mem.page_size) u8 = undefined;
    const size = std.mem.alignForward(usize, total_size, std.mem.page_size);
    if (!is_windows) {
        mem = try std.os.mmap(
            null,
            size,
            std.os.PROT.NONE,
            std.os.MAP.ANONYMOUS | std.os.MAP.PRIVATE,
            -1,
            0,
        );
    } else {
        const lpvoid = try std.os.windows.VirtualAlloc(null, size, std.os.windows.MEM_RESERVE, std.os.windows.PAGE_NOACCESS);

        mem.len = size;
        mem.ptr = @alignCast(@ptrCast(lpvoid));
    }

    var mmap = Mmap{ .mem = mem, .cursor = 0, .protected_mem_cursor = 0, .page_size = std.mem.alignForward(usize, page_size, std.mem.page_size) };
    mmap.mprotect() catch unreachable;

    return mmap;
}

pub fn push(self: *Mmap, data: []const u8) ![]u8 {
    const starting_pos = self.cursor;
    const ending_pos = starting_pos + data.len;

    if (ending_pos > self.protected_mem_cursor) {
        try self.mprotect();
    }

    const slice = self.mem[starting_pos..ending_pos];

    @memcpy(slice, data);

    self.cursor = ending_pos;

    return slice;
}

pub fn reserve(self: *Mmap, size: usize) ![]u8 {
    const starting_pos = self.cursor;
    const ending_pos = starting_pos + size;

    if (ending_pos > self.protected_mem_cursor) {
        try self.mprotect();
    }

    self.cursor = ending_pos;

    return self.mem[starting_pos..ending_pos];
}

pub fn deinit(self: *Mmap) void {
    if (!is_windows) {
        std.os.munmap(self.mem);
    } else {
        std.os.windows.VirtualFree(@alignCast(@ptrCast(self.mem.ptr)), 0, std.os.windows.MEM_RELEASE);
    }
}
