// zig build-lib src/main.zig -O ReleaseFast

const std = @import("std");
const kv = @import("kv.zig");
const KV = kv.KV;

comptime {
    // @compileLog(@sizeOf(KV));
    std.debug.assert(@sizeOf(KV) == 48); // update map.h when this changes
}
const Map_opaque = extern struct {
    __opaque: [@sizeOf(KV)]u8 align(@alignOf(KV)),
    fn toKV(self: *Map_opaque) *KV {
        return @ptrCast(self);
    }
};

const Str = extern struct {
    // null == no result
    ptr: ?[*]const u8,
    len: usize,
};

const GPA = std.heap.GeneralPurposeAllocator(.{});
const Arena = std.heap.ArenaAllocator;

export fn Map_init() Map_opaque {
    // std.debug.print("Map_init\n", .{});
    var state = Arena.init(std.heap.page_allocator);
    _ = state.allocator().alloc(u8, 32 * 1024 * 1024) catch unreachable; // TODO
    std.debug.assert(state.reset(.retain_capacity) == true);
    const heap_state = state.allocator().create(Arena) catch unreachable; // TODO
    heap_state.* = state;
    var gpa = heap_state.allocator().create(GPA) catch unreachable; // TODO
    gpa.* = GPA{ .backing_allocator = heap_state.allocator() };
    const kv_instance = KV.init(gpa.allocator());
    var result: Map_opaque = undefined;
    for (@as(*const [@sizeOf(KV)]u8, @ptrCast(&kv_instance)), 0..) |byte, i| {
        result.__opaque[i] = byte;
    }

    return result;
}
export fn Map_deinit(map: *Map_opaque) void {
    // std.debug.print("Map_deinit\n", .{});
    const m = map.toKV();
    // m.deinit(); // will be freed by arena deinit
    const heap_state: *Arena = @ptrCast(@alignCast(@as(
        *GPA,
        @ptrCast(@alignCast(m.allocator.ptr)),
    ).backing_allocator.ptr));
    // state.allocator().destroy(heap_state); // will be freed by arena deinit
    heap_state.deinit();
}

export fn Map_get(map: *Map_opaque, key_ptr: [*]const u8, key_len: usize) Str {
    if (map.toKV().get(key_ptr[0..key_len])) |value| {
        return .{ .ptr = value.ptr, .len = value.len };
    }

    return .{ .ptr = null, .len = 0 };
}
export fn Map_set(map: *Map_opaque, key_ptr: [*]const u8, key_len: usize, value_ptr: [*]const u8, value_len: usize) bool {
    if (map.toKV().set(key_ptr[0..key_len], value_ptr[0..value_len])) |_| {
        return true;
    } else |_| {
        return false;
    }
}
export fn Map_rm(map: *Map_opaque, key_ptr: [*]const u8, key_len: usize) void {
    map.toKV().rm(key_ptr[0..key_len]);
}

test "C-like" {
    var map = Map_init();

    std.debug.assert(Map_set(&map, "foo", "foo".len, "bar", "bar".len) == true);
    const s1 = Map_get(&map, "foo", 3);

    std.debug.assert(std.mem.eql(u8, s1.ptr.?[0..s1.len], "bar"));

    Map_rm(&map, "foo", "foo".len);
    const s2 = Map_get(&map, "foo", "foo".len);

    std.debug.assert(s2.ptr == null);

    Map_deinit(&map);
}
