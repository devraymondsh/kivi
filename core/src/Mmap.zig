const std = @import("std");
const builtin = @import("builtin");

const is_windows: bool = builtin.os.tag == .windows;
const FreeListNode = struct {
    next: ?*FreeListNode,
    len: usize,
};

cursor: usize,
freelist: ?*FreeListNode,
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

    var mmap = Mmap{ .mem = mem, .cursor = 0, .protected_mem_cursor = 0, .freelist = null, .page_size = std.mem.alignForward(usize, page_size, std.mem.page_size) };
    mmap.mprotect() catch unreachable;

    return mmap;
}

pub fn reserve(self: *Mmap, size: usize) ![]u8 {
    if (self.freelist) |freelist| {
        if (freelist.len >= size) {
            var freelist_slice: []u8 = undefined;
            freelist_slice.len = freelist.len;
            freelist_slice.ptr = @alignCast(@ptrCast(freelist));

            // We go too much to use
            if (freelist.len >= size + @sizeOf(FreeListNode)) {
                self.free(freelist_slice[size..freelist.len]);
            } else if (freelist_slice.len > size) {
                @memset(freelist_slice[size..freelist.len], 0);
            }

            self.freelist = freelist.next;

            return freelist_slice[0..size];
        }
    }

    var ending_pos: usize = undefined;
    const starting_pos = self.cursor;
    if (size >= 16) {
        ending_pos = starting_pos + std.mem.alignForward(usize, size, 8);
    } else {
        ending_pos = starting_pos + 16;
    }

    if (ending_pos > self.protected_mem_cursor) {
        try self.mprotect();
    }

    self.cursor = ending_pos;

    return self.mem[starting_pos .. starting_pos + size];
}

pub fn free(self: *Mmap, data: []u8) void {
    var data_length: usize = undefined;
    if (data.len <= 16) {
        data_length = 16;
    } else {
        data_length = std.mem.alignForward(usize, data.len, 8);
    }

    const freelist = @as(*FreeListNode, @alignCast(@ptrCast(data.ptr)));
    freelist.*.len = data_length;

    if (self.freelist) |previous_freelist| {
        freelist.*.next = previous_freelist;
    } else {
        freelist.*.next = null;
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
