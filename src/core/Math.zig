const Math = @This();

pub fn alignBackward(comptime T: type, addr: T, alignment: T) T {
    // TODO: Panic
    // assert(isValidAlignGeneric(T, alignment));

    // 000010000 // example alignment
    // 000001111 // subtract 1
    // 111110000 // binary not
    return addr & ~(alignment - 1);
}

pub fn alignForward(comptime T: type, addr: T, alignment: T) T {
    // TODO: Panic
    // assert(isValidAlignGeneric(T, alignment));

    return alignBackward(T, addr + (alignment - 1), alignment);
}

pub fn ceilPowerOfTwo(n_arg: u64) u64 {
    var n = n_arg;
    n -= 1;
    n |= n >> 1;
    n |= n >> 2;
    n |= n >> 4;
    n |= n >> 8;
    n |= n >> 16;
    n |= n >> 32;
    n += 1;

    return n;
}
