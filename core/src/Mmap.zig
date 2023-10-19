const std = @import("std");
const builtin = @import("builtin");

const maxU32 = std.math.maxInt(u32);
const maxU64 = std.math.maxInt(u64);
const is_windows: bool = builtin.os.tag == .windows;
var empty_freelist = FreeListNode8byte{ .len = 0, .next = false, .next_idx = maxU32 };

const FreeListNode8byte = packed struct {
    len: u31,
    next: bool,
    next_idx: u32,
};
// TODO: Impl
const FreeListNode16byte = packed struct {
    len: u63,
    next: bool,
    next_idx: u64,
};

cursor: usize,
freelist: *FreeListNode8byte,
mem: []align(std.mem.page_size) u8,
page_size: usize,
protected_mem_cursor: usize,

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

    var mmap = Mmap{ .mem = mem, .cursor = 0, .protected_mem_cursor = 0, .freelist = &empty_freelist, .page_size = std.mem.alignForward(usize, page_size, std.mem.page_size) };
    mmap.mprotect() catch unreachable;

    return mmap;
}

pub fn reserve(self: *Mmap, size: usize) ![]u8 {
    if (self.freelist.len != 0) {
        if (self.freelist.len >= size) {
            var freelist_slice: []u8 = undefined;
            freelist_slice.len = self.freelist.len;
            freelist_slice.ptr = @alignCast(@ptrCast(self.freelist));

            if (self.freelist.len - size != 0) {
                @memset(freelist_slice[size..self.freelist.len], 0);
            }

            if (self.freelist.next) {
                self.freelist = @ptrFromInt(@as(usize, @intCast(self.freelist.next_idx)) + @intFromPtr(self.mem.ptr));
            } else {
                self.freelist = &empty_freelist;
            }

            return freelist_slice[0..size];
        }
    }

    const starting_pos = self.cursor;
    var ending_pos: usize = starting_pos + 8;
    if (size > 8) {
        ending_pos += std.mem.alignForward(usize, size - 8, 8);
    }

    if (ending_pos > self.protected_mem_cursor) {
        try self.mprotect();
        while (ending_pos > self.protected_mem_cursor) {
            try self.mprotect();
        }
    }

    self.cursor = ending_pos;

    return self.mem[starting_pos .. starting_pos + size];
}

pub fn free(self: *Mmap, data: []u8) void {
    const freelist = @as(*FreeListNode8byte, @alignCast(@ptrCast(data.ptr)));

    if (data.len > 8) {
        freelist.*.len = @intCast(std.mem.alignForward(usize, data.len, 8));
    } else {
        freelist.*.len = 8;
    }

    if (self.freelist.len != 0) {
        freelist.*.next = true;
        freelist.*.next_idx = @intCast(@intFromPtr(self.freelist) - @intFromPtr(self.mem.ptr));
    } else {
        freelist.*.next = false;
        freelist.*.next_idx = maxU32;
    }

    self.freelist = freelist;
}

pub fn deinit(self: *Mmap) void {
    if (!is_windows) {
        std.os.munmap(self.mem);
    } else {
        std.os.windows.VirtualFree(@alignCast(@ptrCast(self.mem.ptr)), 0, std.os.windows.MEM_RELEASE);
    }
}
