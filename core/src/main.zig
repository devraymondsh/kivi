const std = @import("std");
const Collection = @import("collection.zig");

const CollectionInitStatus = enum(u32) { Ok, Failed };

pub const Config = extern struct {
    keys_mmap_size: usize,
    mmap_page_size: usize,
    values_mmap_size: usize,
};
const Str = extern struct {
    // null == no result
    ptr: ?[*]const u8,
    len: usize,
};
const CollectionInitResult = extern struct {
    err: CollectionInitStatus,
    collection_opq: CollectionOpaque,
};
const CollectionOpaque = extern struct {
    __opaque: [@sizeOf(Collection)]u8 align(@alignOf(Collection)),

    fn toCollection(self: *CollectionOpaque) *Collection {
        return @ptrCast(self);
    }
};

fn ffi_type_assert(comptime structure: type, expected_size: usize, expected_alignment: usize) void {
    std.debug.assert(@sizeOf(structure) == expected_size);
    std.debug.assert(@alignOf(structure) == expected_alignment);
}
// update bindings.h when these change
comptime {
    // Structs
    ffi_type_assert(Str, 16, 8);
    ffi_type_assert(Config, 24, 8);
    ffi_type_assert(Collection, 128, 8);
    ffi_type_assert(CollectionInitResult, 136, 8);
    // Enums
    ffi_type_assert(CollectionInitStatus, 4, 4);
}

export fn CollectionInitWithConfig(config: Config, collection_opaque: *CollectionOpaque) CollectionInitStatus {
    const collection_instance = Collection.init(std.heap.page_allocator, &config) catch return CollectionInitStatus.Failed;

    for (@as(*const [@sizeOf(Collection)]u8, @ptrCast(&collection_instance)), 0..) |byte, i| {
        collection_opaque.__opaque[i] = byte;
    }

    return CollectionInitStatus.Ok;
}
export fn CollectionInit(collection_opaque: *CollectionOpaque) CollectionInitStatus {
    return CollectionInitWithConfig(Config{ .mmap_page_size = 100 * 1024 * 1024, .keys_mmap_size = 300 * 1024 * 1024, .values_mmap_size = 700 * 1024 * 1024 }, collection_opaque);
}
export fn CollectionInitWithConfigOut(config: Config) CollectionInitResult {
    var collection_opaque: CollectionOpaque = undefined;
    const collection_init_err = CollectionInitWithConfig(config, &collection_opaque);

    return CollectionInitResult{
        .err = collection_init_err,
        .collection_opq = collection_opaque,
    };
}
export fn CollectionInitOut() CollectionInitResult {
    var collection_opaque: CollectionOpaque = undefined;
    const collection_init_err = CollectionInit(&collection_opaque);

    return CollectionInitResult{
        .err = collection_init_err,
        .collection_opq = collection_opaque,
    };
}

export fn CollectionDeinit(map: *CollectionOpaque) void {
    const m = map.toCollection();
    m.deinit();
}

export fn CollectionGet(map: *CollectionOpaque, str: *Str, key_ptr: [*]const u8, key_len: usize) void {
    if (map.toCollection().get(key_ptr[0..key_len])) |value| {
        str.ptr = value.ptr;
        str.len = value.len;
    } else {
        str.ptr = null;
        str.len = 0;
    }
}
export fn CollectionGetOut(map: *CollectionOpaque, key_ptr: [*]const u8, key_len: usize) Str {
    var str: Str = undefined;
    CollectionGet(map, &str, key_ptr, key_len);

    return str;
}
// Zero means ok, so that means we return false(0) on success and return true(1) on failure
export fn CollectionSet(map: *CollectionOpaque, key_ptr: [*]const u8, key_len: usize, value_ptr: [*]const u8, value_len: usize) bool {
    return if (map.toCollection().set(
        key_ptr[0..key_len],
        value_ptr[0..value_len],
    )) |_| false else |_| true;
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
    var collection_foo_res = CollectionInitOut();
    std.debug.assert(collection_foo_res.err == CollectionInitStatus.Ok);

    var collection_foo = collection_foo_res.collection_opq;

    std.debug.assert(CollectionSet(&collection_foo, "foo", "foo".len, "bar", "bar".len) == false);
    const s1 = CollectionGetOut(&collection_foo, "foo", 3);

    std.debug.assert(std.mem.eql(u8, s1.ptr.?[0..s1.len], "bar"));

    CollectionRm(&collection_foo, "foo", "foo".len);
    const s2 = CollectionGetOut(&collection_foo, "foo", "foo".len);

    std.debug.assert(s2.ptr == null);

    CollectionDeinit(&collection_foo);
}

pub const _start = {};
