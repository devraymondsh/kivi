const std = @import("std");
const collection_opq = @import("collection.zig");
const Collection = collection_opq.Collection;

comptime {
    // @compileLog(@sizeOf(Collection));
    std.debug.assert(@sizeOf(Collection) == 144); // update bindings.h when this changes
    // @compileLog(@align(Collection));
    std.debug.assert(@alignOf(Collection) == 8); // update bindings.h when this changes
}
const CollectionOpaque = extern struct {
    __opaque: [@sizeOf(Collection)]u8 align(@alignOf(Collection)),

    fn toCollection(self: *CollectionOpaque) *Collection {
        return @ptrCast(self);
    }
};

const Str = extern struct {
    // null == no result
    ptr: ?[*]const u8,
    len: usize,
};
const CollectionInitError = enum(u32) { Ok, MmapFailure, allocatorSetupFailure };
const CollectionInitResult = extern struct {
    err: CollectionInitError,
    collection_opq: CollectionOpaque,
};

export fn CollectionInit() CollectionInitResult {
    const collection_instance = Collection.init(std.heap.page_allocator) catch return CollectionInitResult{ .err = CollectionInitError.MmapFailure, .collection_opq = undefined };

    var collection_opaque: CollectionOpaque = undefined;

    for (@as(*const [@sizeOf(Collection)]u8, @ptrCast(&collection_instance)), 0..) |byte, i| {
        collection_opaque.__opaque[i] = byte;
    }

    return CollectionInitResult{ .err = CollectionInitError.Ok, .collection_opq = collection_opaque };
}
export fn CollectionDeinit(map: *CollectionOpaque) void {
    const m = map.toCollection();
    m.deinit();
}

export fn CollectionGet(map: *CollectionOpaque, key_ptr: [*]const u8, key_len: usize) Str {
    if (map.toCollection().get(key_ptr[0..key_len])) |value| {
        return .{ .ptr = value.ptr, .len = value.len };
    }

    return .{ .ptr = null, .len = 0 };
}
export fn CollectionSet(map: *CollectionOpaque, key_ptr: [*]const u8, key_len: usize, value_ptr: [*]const u8, value_len: usize) bool {
    if (map.toCollection().set(key_ptr[0..key_len], value_ptr[0..value_len])) |_| {
        return true;
    } else |_| {
        return false;
    }
}
export fn CollectionRm(map: *CollectionOpaque, key_ptr: [*]const u8, key_len: usize) void {
    map.toCollection().rm(key_ptr[0..key_len]);
}

// For debug info in FFI
export fn setup_debug_handlers() void {
    std.debug.maybeEnableSegfaultHandler();
}
export fn dump_stack_trace() void {
    std.debug.dumpCurrentStackTrace(@returnAddress());
}

test "C-like" {
    var collection_foo_res = CollectionInit();
    std.debug.assert(collection_foo_res.err == CollectionInitError.Ok);

    var collection_foo = collection_foo_res.collection_opq;

    std.debug.assert(CollectionSet(&collection_foo, "foo", "foo".len, "bar", "bar".len) == true);
    const s1 = CollectionGet(&collection_foo, "foo", 3);

    std.debug.assert(std.mem.eql(u8, s1.ptr.?[0..s1.len], "bar"));

    CollectionRm(&collection_foo, "foo", "foo".len);
    const s2 = CollectionGet(&collection_foo, "foo", "foo".len);

    std.debug.assert(s2.ptr == null);

    CollectionDeinit(&collection_foo);
}

pub const _start = {};
