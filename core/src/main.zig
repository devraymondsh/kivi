const std = @import("std");
const Collection = @import("Kivi.zig");

pub const Config = extern struct {
    keys_mmap_size: usize = 300 * 1024 * 1024,
    mmap_page_size: usize = 100 * 1024 * 1024,
    values_mmap_size: usize = 700 * 1024 * 1024,
};
const Str = extern struct {
    // null == no result
    ptr: ?[*]const u8,
    len: usize,
};
const CollectionInitResult = extern struct {
    err: bool,
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
    ffi_type_assert(Collection, 120, 8);
    ffi_type_assert(CollectionInitResult, 128, 8);
}

export fn CollectionInitWithConfig(config: Config, collection_opaque: *CollectionOpaque) bool {
    const collection_instance = Collection.init(std.heap.page_allocator, &config) catch return true;

    for (@as(*const [@sizeOf(Collection)]u8, @ptrCast(&collection_instance)), 0..) |byte, i| {
        collection_opaque.__opaque[i] = byte;
    }

    return false;
}
export fn CollectionInit(collection_opaque: *CollectionOpaque) bool {
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
    const m = map.toCollection();
    const stored_len = m.get(key_ptr[0..key_len], null);
    if (stored_len == 0) {
        str.ptr = null;
        str.len = 0;
        return;
    }
    // TODO: Don't leak, remove Collection API after rewriting JS code
    const mem = m.allocator.alloc(u8, stored_len) catch {
        str.ptr = null;
        str.len = 0;
        return;
    };
    str.ptr = mem.ptr;
    str.len = m.get(key_ptr[0..key_len], mem);
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
    ) > 0) false else true;
}
export fn CollectionRm(map: *CollectionOpaque, str: *Str, key_ptr: [*]const u8, key_len: usize) void {
    const m = map.toCollection();
    const val_len = m.get(key_ptr[0..key_len], null);
    const mem = m.allocator.alloc(u8, val_len) catch {
        str.ptr = null;
        str.len = 0;
        return;
    };
    const written_len = m.del(key_ptr[0..key_len], mem);
    if (written_len > 0) {
        str.ptr = mem.ptr;
        str.len = written_len;
    } else {
        str.ptr = null;
        str.len = 0;
    }
}
export fn CollectionRmOut(map: *CollectionOpaque, key_ptr: [*]const u8, key_len: usize) Str {
    var str: Str = undefined;
    CollectionRm(map, &str, key_ptr, key_len);

    return str;
}

// For debug info in FFI
export fn setup_debug_handlers() void {
    std.debug.maybeEnableSegfaultHandler();
}
export fn dump_stack_trace() void {
    std.debug.dumpCurrentStackTrace(@returnAddress());
}

test "C-like-out-functions" {
    var collection_foo_res = CollectionInitOut();
    std.debug.assert(collection_foo_res.err == false);

    var collection_foo = collection_foo_res.collection_opq;

    std.debug.assert(CollectionSet(&collection_foo, "foo", "foo".len, "bar", "bar".len) == false);
    const s1 = CollectionGetOut(&collection_foo, "foo", 3);
    std.debug.assert(std.mem.eql(u8, s1.ptr.?[0..s1.len], "bar"));

    const s2 = CollectionRmOut(&collection_foo, "foo", "foo".len);
    std.debug.assert(s2.ptr != null);

    const s3 = CollectionGetOut(&collection_foo, "foo", "foo".len);
    std.debug.assert(s3.ptr == null);

    CollectionDeinit(&collection_foo);
}
test "C-like-non-out-functions" {
    var collection_foo: CollectionOpaque = undefined;
    var collection_foo_res = CollectionInit(&collection_foo);
    std.debug.assert(collection_foo_res == false);

    std.debug.assert(CollectionSet(&collection_foo, "foo", "foo".len, "bar", "bar".len) == false);
    var s1: Str = undefined;
    CollectionGet(&collection_foo, &s1, "foo", 3);

    std.debug.assert(std.mem.eql(u8, s1.ptr.?[0..s1.len], "bar"));

    var s2: Str = undefined;
    CollectionRm(&collection_foo, &s2, "foo", "foo".len);
    std.debug.assert(s2.ptr != null);

    var s3: Str = undefined;
    CollectionGet(&collection_foo, &s3, "foo", "foo".len);
    std.debug.assert(s3.ptr == null);

    CollectionDeinit(&collection_foo);
}

const Kivi = Collection;

test "v2 functions" {
    var kv = try Kivi.init(std.testing.allocator, &.{});
    defer kv.deinit();

    try std.testing.expect(kv.set("foo", "bar") == 3);

    var val: [1024]u8 = undefined;
    try std.testing.expect(kv.get("foo", &val) == 3);
    try std.testing.expect(std.mem.eql(u8, val[0..3], "bar"));

    try std.testing.expect(kv.del("foo", &val) == 3);
    try std.testing.expect(std.mem.eql(u8, val[0..3], "bar"));

    try std.testing.expect(kv.get("foo", null) == 0);
}

test "v2 C-like functions" {
    var kv: Kivi = undefined;
    try std.testing.expect(kv.kivi_init() == @sizeOf(Kivi));

    try std.testing.expect(kv.kivi_set("foo", "foo".len, "bar", "bar".len) == 3);

    var val: [1024]u8 = undefined;
    try std.testing.expect(kv.kivi_get("foo", "foo".len, &val, val.len) == 3);
    try std.testing.expect(std.mem.eql(u8, val[0..3], "bar"));

    try std.testing.expect(kv.kivi_del("foo", "foo".len, null, 0) == 3);

    try std.testing.expect(kv.kivi_get("foo", 3, null, 0) == 0);
}

pub const _start = {};
