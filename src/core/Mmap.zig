const builtin = @import("builtin");
const Syscall = @import("Syscall.zig");
const Math = @import("Math.zig");

const is_windows: bool = builtin.os.tag == .windows;

const FreelistNode = packed struct {
    len: usize,
    next: ?*FreelistNode,
};
var empty_freelist = FreelistNode{ .len = 0, .next = null };

cursor: usize,
freelist: *FreelistNode,
mem: []align(Syscall.page_size) u8,
mprotect_size: usize,
protected_mem_cursor: usize,

const Mmap = @This();

pub fn byte_slice_cast(comptime T: type, value: []u8) []T {
    var new_slice: []T = undefined;
    new_slice.ptr = @as([*]T, @alignCast(@ptrCast(value.ptr)));
    new_slice.len = value.len;
    return new_slice;
}

fn mprotect(self: *Mmap) !void {
    const protected_mem_cursor = self.protected_mem_cursor + self.mprotect_size;

    if (!is_windows) {
        try Syscall.mprotect(@alignCast(self.mem[self.protected_mem_cursor..protected_mem_cursor]), Syscall.PROT.READ | Syscall.PROT.WRITE);
    } else {
        const std = @import("std");
        _ = try std.os.windows.VirtualAlloc(@ptrCast(@alignCast(self.mem)), protected_mem_cursor, std.os.windows.MEM_COMMIT, std.os.windows.PAGE_READWRITE);
    }

    self.protected_mem_cursor = protected_mem_cursor;
}

pub fn init(total_size: usize, mprotect_size: usize) !Mmap {
    var mem: []align(Syscall.page_size) u8 = undefined;
    const size = Math.alignForward(usize, total_size, Syscall.page_size);
    if (!is_windows) {
        mem = try Syscall.mmap(
            null,
            size,
            Syscall.PROT.NONE,
            Syscall.MAP.ANONYMOUS | Syscall.MAP.PRIVATE,
            -1,
            0,
        );
    } else {
        const std = @import("std");
        const lpvoid = try std.os.windows.VirtualAlloc(null, size, std.os.windows.MEM_RESERVE, std.os.windows.PAGE_NOACCESS);

        mem.len = size;
        mem.ptr = @alignCast(@ptrCast(lpvoid));
    }

    var mmap = Mmap{ .mem = mem, .cursor = 0, .protected_mem_cursor = 0, .freelist = &empty_freelist, .mprotect_size = Math.alignForward(usize, mprotect_size, Syscall.page_size) };
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
        ending_pos += Math.alignForward(usize, size - 16, 8);
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
    const freelist = @as(*FreelistNode, @alignCast(@ptrCast(data.ptr)));

    if (data.len > 16) {
        freelist.len = @intCast(Math.alignForward(usize, data.len, 8));
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

pub fn deinit(self: *Mmap) void {
    if (!is_windows) {
        Syscall.unmap(self.mem);
    } else {
        const std = @import("std");
        std.os.windows.VirtualFree(@alignCast(@ptrCast(self.mem.ptr)), 0, std.os.windows.MEM_RELEASE);
    }
}
