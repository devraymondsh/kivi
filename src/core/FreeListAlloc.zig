const std = @import("std");
const builtin = @import("builtin");

const is_windows: bool = builtin.os.tag == .windows;

const FreelistNode = packed struct {
    len: usize,
    next: ?*FreelistNode,
};
var empty_freelist = FreelistNode{ .len = 0, .next = null };

cursor: usize,
freelist: *FreelistNode,
mem: []align(std.mem.page_size) u8,

const FreeListAlloc = @This();

pub fn init(total_size: usize) !FreeListAlloc {
    var mem: []align(std.mem.page_size) u8 = undefined;
    const size = std.mem.alignForward(usize, total_size, std.mem.page_size);
    if (!is_windows) {
        mem = try std.posix.mmap(
            null,
            size,
            std.posix.PROT.READ | std.posix.PROT.WRITE,
            std.posix.MAP{ .ANONYMOUS = true, .TYPE = .PRIVATE },
            -1,
            0,
        );
    } else {
        const lpvoid = try std.os.windows.VirtualAlloc(null, size, std.os.windows.MEM_RESERVE, std.os.windows.PAGE_NOACCESS);

        mem.len = size;
        mem.ptr = @alignCast(@ptrCast(lpvoid));
    }

    return FreeListAlloc{ .mem = mem, .cursor = 0, .freelist = &empty_freelist };
}

pub fn alloc_byte(self: *FreeListAlloc, size: usize) ![]u8 {
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

    if (ending_pos >= self.mem.len) {
        return error.OutOfMemory;
    }

    self.cursor = ending_pos;

    return self.mem[starting_pos .. starting_pos + size];
}

pub fn alloc(self: *FreeListAlloc, comptime T: type, n: usize) ![]T {
    var allocated: []T = undefined;
    allocated.ptr = @alignCast(@ptrCast(try self.alloc_byte(n * @sizeOf(T))));
    allocated.len = n;
    return allocated;
}

pub fn free(self: *FreeListAlloc, data: []u8) void {
    const freelist = @as(*FreelistNode, @alignCast(@ptrCast(data.ptr)));

    if (data.len > 16) {
        freelist.len = @intCast(std.mem.alignForward(usize, data.len, 8));
    } else {
        freelist.len = 16;
    }

    if (self.freelist.len != 0) {
        freelist.next = self.freelist;
    } else {
        freelist.next = null;
    }

    self.freelist = freelist;
}

pub fn deinit(self: *FreeListAlloc) void {
    if (!is_windows) {
        std.posix.munmap(self.mem);
    } else {
        std.os.windows.VirtualFree(@alignCast(@ptrCast(self.mem.ptr)), 0, std.os.windows.MEM_RELEASE);
    }
}
