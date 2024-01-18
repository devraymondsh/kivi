const std = @import("std");
const builtin = @import("builtin");

const maxU32 = std.math.maxInt(u32);
const maxU64 = std.math.maxInt(u64);
const is_windows: bool = builtin.os.tag == .windows;
var empty_freelist = FreelistNode{ .len = 0, .next = null };

const FreelistNode = packed struct {
    len: usize,
    next: ?*FreelistNode,
};

cursor: usize,
freelist: *FreelistNode,
mem: []align(std.mem.page_size) u8,
page_size: usize,
protected_mem_cursor: usize,

const Mmap = @This();

pub fn byte_slice_cast(comptime T: type, value: []u8) []T {
    var new_slice: []T = undefined;
    new_slice.ptr = @as([*]T, @alignCast(@ptrCast(value.ptr)));
    new_slice.len = value.len;
    return new_slice;
}

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

pub fn alloc_byte(self: *Mmap, size: usize) ![]u8 {
    if (self.freelist.len != 0) {
        if (self.freelist.len >= size) {
            var freelist_slice: []u8 = undefined;
            freelist_slice.len = self.freelist.len;
            freelist_slice.ptr = @alignCast(@ptrCast(self.freelist));

            if (self.freelist.len - size != 0) {
                @memset(freelist_slice[size..self.freelist.len], 0);
            }

            if (self.freelist.next) |_| {
                self.freelist = self.freelist.next.?;
            } else {
                self.freelist = &empty_freelist;
            }

            return freelist_slice[0..size];
        }
    }

    const starting_pos = self.cursor;
    var ending_pos: usize = starting_pos + 16;
    if (size > 16) {
        ending_pos += std.mem.alignForward(usize, size - 16, 8);
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

pub fn alloc(self: *Mmap, comptime T: type, n: usize) ![]T {
    var allocated: []T = undefined;
    allocated.ptr = @alignCast(@ptrCast(try self.alloc_byte(n * @sizeOf(T))));
    allocated.len = n;
    return allocated;
}

pub fn free(self: *Mmap, data: []u8) void {
    _ = self; // autofix
    _ = data; // autofix
    // const freelist = @as(*FreelistNode, @alignCast(@ptrCast(data.ptr)));

    // if (data.len > 16) {
    //     freelist.len = @intCast(std.mem.alignForward(usize, data.len, 8));
    // } else {
    //     freelist.len = 16;
    // }

    // if (self.freelist.len != 0) {
    //     freelist.next = self.freelist;
    // } else {
    //     freelist.next = null;
    // }

    // self.freelist = freelist;
    return;
}

pub fn deinit(self: *Mmap) void {
    if (!is_windows) {
        std.os.munmap(self.mem);
    } else {
        std.os.windows.VirtualFree(@alignCast(@ptrCast(self.mem.ptr)), 0, std.os.windows.MEM_RELEASE);
    }
}
