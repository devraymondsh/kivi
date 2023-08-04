// zig build-lib src/main.zig -O ReleaseFast

const std = @import("std");
const kv = @import("kv.zig");
const KV = kv.KV;

comptime {
    std.debug.assert(@sizeOf(KV) == 32); // update map.h when this changes
}
const Map_opaque = extern struct {
    __opaque: [@sizeOf(KV)]u8 align(@alignOf(KV)),
};

const Str = extern struct {
    // null == no result
    ptr: ?[*]const u8,
    len: usize,
};

inline fn cast_map_opq(map: *Map_opaque) *KV {
    return @as(*KV, @ptrCast(map));
}

export fn Map_init() Map_opaque {
    var result: Map_opaque = undefined;
    const kv_instance = KV.init(std.heap.page_allocator);

    for (@as(*const [@sizeOf(KV)]u8, @ptrCast(&kv_instance)), 0..) |byte, i| {
        result.__opaque[i] = byte;
    }

    return result;
}
export fn Map_deinit(map: *Map_opaque) void {
    cast_map_opq(map).deinit();
}

export fn Map_get(map: *Map_opaque, key_ptr: [*]u8, key_len: usize) Str {
    if (cast_map_opq(map).get(key_ptr[0..key_len])) |value| {
        return .{ .ptr = value.ptr, .len = value.len };
    }

    return .{ .ptr = null, .len = 0 };
}
export fn Map_set(map: *Map_opaque, key_ptr: [*]u8, key_len: usize, value_ptr: [*]u8, value_len: usize) bool {
    if (cast_map_opq(map).set(key_ptr[0..key_len], value_ptr[0..value_len])) |_| {
        return true;
    } else |_| {
        return false;
    }
}
export fn Map_rm(map: *Map_opaque, key_ptr: [*]u8, key_len: usize) void {
    cast_map_opq(map).rm(key_ptr[0..key_len]);
}
