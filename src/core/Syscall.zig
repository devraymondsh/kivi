const builtin = @import("builtin");

const Syscall = @This();

pub const page_size = switch (builtin.cpu.arch) {
    .wasm32, .wasm64 => 64 * 1024,
    .aarch64 => switch (builtin.os.tag) {
        .macos, .ios, .watchos, .tvos => 16 * 1024,
        else => 4 * 1024,
    },
    .sparc64 => 8 * 1024,
    else => 4 * 1024,
};

pub const SyscallType = enum(usize) {
    read = 0,
    write = 1,
    open = 2,
    close = 3,
    stat = 4,
    fstat = 5,
    lstat = 6,
    poll = 7,
    lseek = 8,
    mmap = 9,
    mprotect = 10,
    munmap = 11,
    brk = 12,
};

const SyscallErr = enum(u16) {
    /// No error occurred.
    /// Same code used for `NSROK`.
    SUCCESS = 0,
    /// Operation not permitted
    PERM = 1,
    /// No such file or directory
    NOENT = 2,
    /// No such process
    SRCH = 3,
    /// Interrupted system call
    INTR = 4,
    /// I/O error
    IO = 5,
    /// No such device or address
    NXIO = 6,
    /// Arg list too long
    @"2BIG" = 7,
    /// Exec format error
    NOEXEC = 8,
    /// Bad file number
    BADF = 9,
    /// No child processes
    CHILD = 10,
    /// Try again
    /// Also means: WOULDBLOCK: operation would block
    AGAIN = 11,
    /// Out of memory
    NOMEM = 12,
    /// Permission denied
    ACCES = 13,
    /// Bad address
    FAULT = 14,
    /// Block device required
    NOTBLK = 15,
    /// Device or resource busy
    BUSY = 16,
    /// File exists
    EXIST = 17,
};

pub const PROT = struct {
    /// page can not be accessed
    pub const NONE = 0x0;
    /// page can be read
    pub const READ = 0x1;
    /// page can be written
    pub const WRITE = 0x2;
    /// page can be executed
    pub const EXEC = 0x4;
    /// page may be used for atomic ops
    pub const SEM = 0x8;
    /// mprotect flag: extend change to start of growsdown vma
    pub const GROWSDOWN = 0x01000000;
    /// mprotect flag: extend change to end of growsup vma
    pub const GROWSUP = 0x02000000;
};
pub const MAP = struct {
    /// Share changes
    pub const SHARED = 0x01;
    /// Changes are private
    pub const PRIVATE = 0x02;
    /// share + validate extension flags
    pub const SHARED_VALIDATE = 0x03;
    /// Mask for type of mapping
    pub const TYPE = 0x0f;
    /// Interpret addr exactly
    pub const FIXED = 0x10;
    /// don't use a file
    pub const ANONYMOUS = 0x20;
    // MAP_ 0x0100 - 0x4000 flags are per architecture
    /// populate (prefault) pagetables
    pub const POPULATE = 0x8000;
    /// do not block on IO
    pub const NONBLOCK = 0x10000;
    /// give out an address that is best suited for process/thread stacks
    pub const STACK = 0x20000;
    /// create a huge page mapping
    pub const HUGETLB = 0x40000;
    /// perform synchronous page faults for the mapping
    pub const SYNC = 0x80000;
    /// MAP_FIXED which doesn't unmap underlying mapping
    pub const FIXED_NOREPLACE = 0x100000;
    /// For anonymous mmap, memory could be uninitialized
    pub const UNINITIALIZED = 0x4000000;
};

pub fn get_syserr(r: usize) SyscallErr {
    @setRuntimeSafety(false);
    const signed_r = @as(isize, @bitCast(r));
    const int = if (signed_r > -4096 and signed_r < 0) -signed_r else 0;
    return @as(SyscallErr, @enumFromInt(int));
}

fn syscall(syscall_type: SyscallType, args: anytype) usize {
    @setRuntimeSafety(false);
    return switch (args.len) {
        1 => asm volatile ("syscall"
            : [ret] "={rax}" (-> usize),
            : [syscall_type] "{rax}" (syscall_type),
              [a0] "{rdi}" (args[0]),
            : "rcx", "r11", "memory"
        ),
        2 => asm volatile ("syscall"
            : [ret] "={rax}" (-> usize),
            : [syscall_type] "{rax}" (syscall_type),
              [a0] "{rdi}" (args[0]),
              [a1] "{rsi}" (args[1]),
            : "rcx", "r11", "memory"
        ),
        3 => asm volatile ("syscall"
            : [ret] "={rax}" (-> usize),
            : [syscall_type] "{rax}" (syscall_type),
              [a0] "{rdi}" (args[0]),
              [a1] "{rsi}" (args[1]),
              [a2] "{rdx}" (args[2]),
            : "rcx", "r11", "memory"
        ),
        4 => asm volatile ("syscall"
            : [ret] "={rax}" (-> usize),
            : [syscall_type] "{rax}" (syscall_type),
              [a0] "{rdi}" (args[0]),
              [a1] "{rsi}" (args[1]),
              [a2] "{rdx}" (args[2]),
              [a3] "{r10}" (args[3]),
            : "rcx", "r11", "memory"
        ),
        5 => asm volatile ("syscall"
            : [ret] "={rax}" (-> usize),
            : [syscall_type] "{rax}" (syscall_type),
              [a0] "{rdi}" (args[0]),
              [a1] "{rsi}" (args[1]),
              [a2] "{rdx}" (args[2]),
              [a3] "{r10}" (args[3]),
              [a4] "{r8}" (args[4]),
            : "rcx", "r11", "memory"
        ),
        6 => asm volatile ("syscall"
            : [ret] "={rax}" (-> usize),
            : [syscall_type] "{rax}" (syscall_type),
              [a0] "{rdi}" (args[0]),
              [a1] "{rsi}" (args[1]),
              [a2] "{rdx}" (args[2]),
              [a3] "{r10}" (args[3]),
              [a4] "{r8}" (args[4]),
              [a5] "{r9}" (args[5]),
            : "rcx", "r11", "memory"
        ),
        else => @compileError("Invalid number of arguments to syscall!"),
    };
}

pub fn mmap(
    ptr: ?[*]align(page_size) u8,
    length: usize,
    prot: u32,
    flags: u32,
    fd: i32,
    offset: u64,
) ![]align(page_size) u8 {
    @setRuntimeSafety(false);
    const res = syscall(.mmap, .{
        @intFromPtr(ptr),
        length,
        prot,
        flags,
        @as(usize, @bitCast(@as(isize, fd))),
        @as(u64, @bitCast(offset)),
    });

    if (get_syserr(res) == .SUCCESS) {
        return @as([*]align(page_size) u8, @ptrFromInt(res))[0..length];
    }
    return error.FailedToAllocateMmap;
}

pub fn mprotect(memory: []align(page_size) u8, protection: u32) !void {
    @setRuntimeSafety(false);
    // TODO: Panic
    // assert(isAligned(memory.len, page_size));

    const res = syscall(.mprotect, .{ @intFromPtr(memory.ptr), memory.len, protection });
    if (get_syserr(res) != .SUCCESS) {
        return error.FailedToMprotect;
    }
}

pub fn unmap(memory: []align(page_size) const u8) void {
    @setRuntimeSafety(false);
    _ = syscall(.munmap, .{ @intFromPtr(memory.ptr), memory.len });
}
