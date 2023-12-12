const std = @import("std");
const builtin = @import("builtin");
const strcmp = @import("Strcmp.zig").strcmp;

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const StringContext = struct {
    pub fn hash(self: @This(), s: []const u8) u64 {
        _ = self;
        return std.hash.Wyhash.hash(0, s);
    }
    pub fn eql(self: @This(), a: []const u8, b: []const u8) bool {
        _ = self;
        const x = strcmp(a, b);
        return x;
    }
};
pub fn StringHashMap(comptime V: type) type {
    return HashMapUnmanaged([]const u8, V, StringContext, default_max_load_percentage);
}

pub const default_max_load_percentage = 80;

pub fn HashMapUnmanaged(
    comptime K: type,
    comptime V: type,
    comptime Context: type,
    comptime max_load_percentage: u64,
) type {
    if (max_load_percentage <= 0 or max_load_percentage >= 100)
        @compileError("max_load_percentage must be between 0 and 100.");
    return struct {
        const Self = @This();

        // This is actually a midway pointer to the single buffer containing
        // a `Header` field, the `Metadata`s and `Entry`s.
        // At `-@sizeOf(Header)` is the Header field.
        // At `sizeOf(Metadata) * capacity + offset`, which is pointed to by
        // self.header().entries, is the array of entries.
        // This means that the hashmap only holds one live allocation, to
        // reduce memory fragmentation and struct size.
        /// Pointer to the metadata.
        metadata: ?[*]Metadata = null,

        /// Current number of elements in the hashmap.
        size: Size = 0,

        // Having a countdown to grow reduces the number of instructions to
        // execute when determining if the hashmap has enough capacity already.
        /// Number of available slots before a grow is needed to satisfy the
        /// `max_load_percentage`.
        available: Size = 0,

        // This is purely empirical and not a /very smart magic constant™/.
        /// Capacity of the first grow when bootstrapping the hashmap.
        const minimal_capacity = 8;

        // This hashmap is specially designed for sizes that fit in a u32.
        pub const Size = u32;

        // u64 hashes guarantee us that the fingerprint bits will never be used
        // to compute the index of a slot, maximizing the use of entropy.
        pub const Hash = u64;

        pub const Entry = struct {
            key_ptr: *K,
            value_ptr: *V,
        };

        pub const KV = struct {
            key: K,
            value: V,
        };

        const Header = struct {
            values: [*]V,
            keys: [*]K,
            capacity: Size,
        };

        /// Metadata for a slot. It can be in three states: empty, used or
        /// tombstone. Tombstones indicate that an entry was previously used,
        /// they are a simple way to handle removal.
        /// To this state, we add 7 bits from the slot's key hash. These are
        /// used as a fast way to disambiguate between entries without
        /// having to use the equality function. If two fingerprints are
        /// different, we know that we don't have to compare the keys at all.
        /// The 7 bits are the highest ones from a 64 bit hash. This way, not
        /// only we use the `log2(capacity)` lowest bits from the hash to determine
        /// a slot index, but we use 7 more bits to quickly resolve collisions
        /// when multiple elements with different hashes end up wanting to be in the same slot.
        /// Not using the equality function means we don't have to read into
        /// the entries array, likely avoiding a cache miss and a potentially
        /// costly function call.
        const Metadata = packed struct {
            const FingerPrint = u7;

            const free: FingerPrint = 0;
            const tombstone: FingerPrint = 1;

            fingerprint: FingerPrint = free,
            used: u1 = 0,

            const slot_free = @as(u8, @bitCast(Metadata{ .fingerprint = free }));
            const slot_tombstone = @as(u8, @bitCast(Metadata{ .fingerprint = tombstone }));

            pub fn isUsed(self: Metadata) bool {
                return self.used == 1;
            }

            pub fn isTombstone(self: Metadata) bool {
                return @as(u8, @bitCast(self)) == slot_tombstone;
            }

            pub fn isFree(self: Metadata) bool {
                return @as(u8, @bitCast(self)) == slot_free;
            }

            pub fn takeFingerprint(hash: Hash) FingerPrint {
                const hash_bits = @typeInfo(Hash).Int.bits;
                const fp_bits = @typeInfo(FingerPrint).Int.bits;
                return @as(FingerPrint, @truncate(hash >> (hash_bits - fp_bits)));
            }

            pub fn fill(self: *Metadata, fp: FingerPrint) void {
                self.used = 1;
                self.fingerprint = fp;
            }

            pub fn remove(self: *Metadata) void {
                self.used = 0;
                self.fingerprint = tombstone;
            }
        };

        comptime {
            assert(@sizeOf(Metadata) == 1);
            assert(@alignOf(Metadata) == 1);
        }

        pub const Iterator = struct {
            hm: *const Self,
            index: Size = 0,

            pub fn next(it: *Iterator) ?Entry {
                assert(it.index <= it.hm.capacity());
                if (it.hm.size == 0) return null;

                const cap = it.hm.capacity();
                const end = it.hm.metadata.? + cap;
                var metadata = it.hm.metadata.? + it.index;

                while (metadata != end) : ({
                    metadata += 1;
                    it.index += 1;
                }) {
                    if (metadata[0].isUsed()) {
                        const key = &it.hm.keys()[it.index];
                        const value = &it.hm.values()[it.index];
                        it.index += 1;
                        return Entry{ .key_ptr = key, .value_ptr = value };
                    }
                }

                return null;
            }
        };

        pub const KeyIterator = FieldIterator(K);
        pub const ValueIterator = FieldIterator(V);

        fn FieldIterator(comptime T: type) type {
            return struct {
                len: usize,
                metadata: [*]const Metadata,
                items: [*]T,

                pub fn next(self: *@This()) ?*T {
                    while (self.len > 0) {
                        self.len -= 1;
                        const used = self.metadata[0].isUsed();
                        const item = &self.items[0];
                        self.metadata += 1;
                        self.items += 1;
                        if (used) {
                            return item;
                        }
                    }
                    return null;
                }
            };
        }

        pub const GetOrPutResult = struct {
            key_ptr: *K,
            value_ptr: *V,
            found_existing: bool,
        };

        fn isUnderMaxLoadPercentage(size: Size, cap: Size) bool {
            return size * 100 < max_load_percentage * cap;
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            self.deallocate(allocator);
            self.* = undefined;
        }

        fn capacityForSize(size: Size) Size {
            var new_cap: u32 = @truncate((@as(u64, size) * 100) / max_load_percentage + 1);
            new_cap = std.math.ceilPowerOfTwo(u32, new_cap) catch unreachable;
            return new_cap;
        }

        pub fn ensureTotalCapacity(self: *Self, allocator: Allocator, new_size: Size) Allocator.Error!void {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call ensureTotalCapacityContext instead.");
            return ensureTotalCapacityContext(self, allocator, new_size, undefined);
        }
        pub fn ensureTotalCapacityContext(self: *Self, allocator: Allocator, new_size: Size, ctx: Context) Allocator.Error!void {
            if (new_size > self.size)
                try self.growIfNeeded(allocator, new_size - self.size, ctx);
        }

        pub fn ensureUnusedCapacity(self: *Self, allocator: Allocator, additional_size: Size) Allocator.Error!void {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call ensureUnusedCapacityContext instead.");
            return ensureUnusedCapacityContext(self, allocator, additional_size, undefined);
        }
        pub fn ensureUnusedCapacityContext(self: *Self, allocator: Allocator, additional_size: Size, ctx: Context) Allocator.Error!void {
            return ensureTotalCapacityContext(self, allocator, self.count() + additional_size, ctx);
        }

        pub fn clearRetainingCapacity(self: *Self) void {
            if (self.metadata) |_| {
                self.initMetadatas();
                self.size = 0;
                self.available = @as(u32, @truncate((self.capacity() * max_load_percentage) / 100));
            }
        }

        pub fn clearAndFree(self: *Self, allocator: Allocator) void {
            self.deallocate(allocator);
            self.size = 0;
            self.available = 0;
        }

        pub fn count(self: *const Self) Size {
            return self.size;
        }

        fn header(self: *const Self) *Header {
            return @ptrCast(@as([*]Header, @ptrCast(@alignCast(self.metadata.?))) - 1);
        }

        fn keys(self: *const Self) [*]K {
            return self.header().keys;
        }

        fn values(self: *const Self) [*]V {
            return self.header().values;
        }

        pub fn capacity(self: *const Self) Size {
            if (self.metadata == null) return 0;

            return self.header().capacity;
        }

        pub fn iterator(self: *const Self) Iterator {
            return .{ .hm = self };
        }

        pub fn keyIterator(self: *const Self) KeyIterator {
            if (self.metadata) |metadata| {
                return .{
                    .len = self.capacity(),
                    .metadata = metadata,
                    .items = self.keys(),
                };
            } else {
                return .{
                    .len = 0,
                    .metadata = undefined,
                    .items = undefined,
                };
            }
        }

        pub fn valueIterator(self: *const Self) ValueIterator {
            if (self.metadata) |metadata| {
                return .{
                    .len = self.capacity(),
                    .metadata = metadata,
                    .items = self.values(),
                };
            } else {
                return .{
                    .len = 0,
                    .metadata = undefined,
                    .items = undefined,
                };
            }
        }

        /// Insert an entry in the map. Assumes it is not already present.
        pub fn putNoClobber(self: *Self, allocator: Allocator, key: K, value: V) Allocator.Error!void {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call putNoClobberContext instead.");
            return self.putNoClobberContext(allocator, key, value, undefined);
        }
        pub fn putNoClobberContext(self: *Self, allocator: Allocator, key: K, value: V, ctx: Context) Allocator.Error!void {
            assert(!self.containsContext(key, ctx));
            try self.growIfNeeded(allocator, 1, ctx);

            self.putAssumeCapacityNoClobberContext(key, value, ctx);
        }

        /// Asserts there is enough capacity to store the new key-value pair.
        /// Clobbers any existing data. To detect if a put would clobber
        /// existing data, see `getOrPutAssumeCapacity`.
        pub fn putAssumeCapacity(self: *Self, key: K, value: V) void {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call putAssumeCapacityContext instead.");
            return self.putAssumeCapacityContext(key, value, undefined);
        }
        pub fn putAssumeCapacityContext(self: *Self, key: K, value: V, ctx: Context) void {
            const gop = self.getOrPutAssumeCapacityContext(key, ctx);
            gop.value_ptr.* = value;
        }

        /// Insert an entry in the map. Assumes it is not already present,
        /// and that no allocation is needed.
        pub fn putAssumeCapacityNoClobber(self: *Self, key: K, value: V) void {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call putAssumeCapacityNoClobberContext instead.");
            return self.putAssumeCapacityNoClobberContext(key, value, undefined);
        }
        pub fn putAssumeCapacityNoClobberContext(self: *Self, key: K, value: V, ctx: Context) void {
            assert(!self.containsContext(key, ctx));

            const hash = ctx.hash(key);
            const mask = self.capacity() - 1;
            var idx = @as(usize, @truncate(hash & mask));

            var metadata = self.metadata.? + idx;
            while (metadata[0].isUsed()) {
                idx = (idx + 1) & mask;
                metadata = self.metadata.? + idx;
            }

            assert(self.available > 0);
            self.available -= 1;

            const fingerprint = Metadata.takeFingerprint(hash);
            metadata[0].fill(fingerprint);
            self.keys()[idx] = key;
            self.values()[idx] = value;

            self.size += 1;
        }

        /// Inserts a new `Entry` into the hash map, returning the previous one, if any.
        pub fn fetchPut(self: *Self, allocator: Allocator, key: K, value: V) Allocator.Error!?KV {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call fetchPutContext instead.");
            return self.fetchPutContext(allocator, key, value, undefined);
        }
        pub fn fetchPutContext(self: *Self, allocator: Allocator, key: K, value: V, ctx: Context) Allocator.Error!?KV {
            const gop = try self.getOrPutContext(allocator, key, ctx);
            var result: ?KV = null;
            if (gop.found_existing) {
                result = KV{
                    .key = gop.key_ptr.*,
                    .value = gop.value_ptr.*,
                };
            }
            gop.value_ptr.* = value;
            return result;
        }

        /// Inserts a new `Entry` into the hash map, returning the previous one, if any.
        /// If insertion happens, asserts there is enough capacity without allocating.
        pub fn fetchPutAssumeCapacity(self: *Self, key: K, value: V) ?KV {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call fetchPutAssumeCapacityContext instead.");
            return self.fetchPutAssumeCapacityContext(key, value, undefined);
        }
        pub fn fetchPutAssumeCapacityContext(self: *Self, key: K, value: V, ctx: Context) ?KV {
            const gop = self.getOrPutAssumeCapacityContext(key, ctx);
            var result: ?KV = null;
            if (gop.found_existing) {
                result = KV{
                    .key = gop.key_ptr.*,
                    .value = gop.value_ptr.*,
                };
            }
            gop.value_ptr.* = value;
            return result;
        }

        /// If there is an `Entry` with a matching key, it is deleted from
        /// the hash map, and then returned from this function.
        pub fn fetchRemove(self: *Self, key: K) ?KV {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call fetchRemoveContext instead.");
            return self.fetchRemoveContext(key, undefined);
        }
        pub fn fetchRemoveContext(self: *Self, key: K, ctx: Context) ?KV {
            return self.fetchRemoveAdapted(key, ctx);
        }
        pub fn fetchRemoveAdapted(self: *Self, key: anytype, ctx: anytype) ?KV {
            if (self.getIndex(key, ctx)) |idx| {
                const old_key = &self.keys()[idx];
                const old_val = &self.values()[idx];
                const result = KV{
                    .key = old_key.*,
                    .value = old_val.*,
                };
                self.metadata.?[idx].remove();
                old_key.* = undefined;
                old_val.* = undefined;
                self.size -= 1;
                self.available += 1;
                return result;
            }

            return null;
        }

        /// Find the index containing the data for the given key.
        /// Whether this function returns null is almost always
        /// branched on after this function returns, and this function
        /// returns null/not null from separate code paths.  We
        /// want the optimizer to remove that branch and instead directly
        /// fuse the basic blocks after the branch to the basic blocks
        /// from this function.  To encourage that, this function is
        /// marked as inline.
        inline fn getIndex(self: Self, key: anytype, ctx: anytype) ?usize {
            if (self.size == 0) {
                return null;
            }

            // If you get a compile error on this line, it means that your generic hash
            // function is invalid for these parameters.
            const hash = ctx.hash(key);
            // verifyContext can't verify the return type of generic hash functions,
            // so we need to double-check it here.
            if (@TypeOf(hash) != Hash) {
                @compileError("Context " ++ @typeName(@TypeOf(ctx)) ++ " has a generic hash function that returns the wrong type! " ++ @typeName(Hash) ++ " was expected, but found " ++ @typeName(@TypeOf(hash)));
            }
            const mask = self.capacity() - 1;
            const fingerprint = Metadata.takeFingerprint(hash);
            // Don't loop indefinitely when there are no empty slots.
            var limit = self.capacity();
            var idx = @as(usize, @truncate(hash & mask));

            var metadata = self.metadata.? + idx;
            while (!metadata[0].isFree() and limit != 0) {
                if (metadata[0].isUsed() and metadata[0].fingerprint == fingerprint) {
                    const test_key = &self.keys()[idx];
                    // If you get a compile error on this line, it means that your generic eql
                    // function is invalid for these parameters.
                    const eql = ctx.eql(key, test_key.*);
                    // verifyContext can't verify the return type of generic eql functions,
                    // so we need to double-check it here.
                    if (@TypeOf(eql) != bool) {
                        @compileError("Context " ++ @typeName(@TypeOf(ctx)) ++ " has a generic eql function that returns the wrong type! bool was expected, but found " ++ @typeName(@TypeOf(eql)));
                    }
                    if (eql) {
                        return idx;
                    }
                }

                limit -= 1;
                idx = (idx + 1) & mask;
                metadata = self.metadata.? + idx;
            }

            return null;
        }

        pub fn getEntry(self: Self, key: K) ?Entry {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getEntryContext instead.");
            return self.getEntryContext(key, undefined);
        }
        pub fn getEntryContext(self: Self, key: K, ctx: Context) ?Entry {
            return self.getEntryAdapted(key, ctx);
        }
        pub fn getEntryAdapted(self: Self, key: anytype, ctx: anytype) ?Entry {
            if (self.getIndex(key, ctx)) |idx| {
                return Entry{
                    .key_ptr = &self.keys()[idx],
                    .value_ptr = &self.values()[idx],
                };
            }
            return null;
        }

        /// Insert an entry if the associated key is not already present, otherwise update preexisting value.
        pub fn put(self: *Self, allocator: Allocator, key: K, value: V) Allocator.Error!void {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call putContext instead.");
            return self.putContext(allocator, key, value, undefined);
        }
        pub fn putContext(self: *Self, allocator: Allocator, key: K, value: V, ctx: Context) Allocator.Error!void {
            const result = try self.getOrPutContext(allocator, key, ctx);
            result.value_ptr.* = value;
        }

        /// Get an optional pointer to the actual key associated with adapted key, if present.
        pub fn getKeyPtr(self: Self, key: K) ?*K {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getKeyPtrContext instead.");
            return self.getKeyPtrContext(key, undefined);
        }
        pub fn getKeyPtrContext(self: Self, key: K, ctx: Context) ?*K {
            return self.getKeyPtrAdapted(key, ctx);
        }
        pub fn getKeyPtrAdapted(self: Self, key: anytype, ctx: anytype) ?*K {
            if (self.getIndex(key, ctx)) |idx| {
                return &self.keys()[idx];
            }
            return null;
        }

        /// Get a copy of the actual key associated with adapted key, if present.
        pub fn getKey(self: Self, key: K) ?K {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getKeyContext instead.");
            return self.getKeyContext(key, undefined);
        }
        pub fn getKeyContext(self: Self, key: K, ctx: Context) ?K {
            return self.getKeyAdapted(key, ctx);
        }
        pub fn getKeyAdapted(self: Self, key: anytype, ctx: anytype) ?K {
            if (self.getIndex(key, ctx)) |idx| {
                return self.keys()[idx];
            }
            return null;
        }

        /// Get an optional pointer to the value associated with key, if present.
        pub fn getPtr(self: Self, key: K) ?*V {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getPtrContext instead.");
            return self.getPtrContext(key, undefined);
        }
        pub fn getPtrContext(self: Self, key: K, ctx: Context) ?*V {
            return self.getPtrAdapted(key, ctx);
        }
        pub fn getPtrAdapted(self: Self, key: anytype, ctx: anytype) ?*V {
            if (self.getIndex(key, ctx)) |idx| {
                return &self.values()[idx];
            }
            return null;
        }

        /// Get a copy of the value associated with key, if present.
        pub fn get(self: Self, key: K) ?V {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getContext instead.");
            return self.getContext(key, undefined);
        }
        pub fn getContext(self: Self, key: K, ctx: Context) ?V {
            return self.getAdapted(key, ctx);
        }
        pub fn getAdapted(self: Self, key: anytype, ctx: anytype) ?V {
            if (self.getIndex(key, ctx)) |idx| {
                return self.values()[idx];
            }
            return null;
        }

        pub fn getOrPut(self: *Self, allocator: Allocator, key: K) Allocator.Error!GetOrPutResult {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getOrPutContext instead.");
            return self.getOrPutContext(allocator, key, undefined);
        }
        pub fn getOrPutContext(self: *Self, allocator: Allocator, key: K, ctx: Context) Allocator.Error!GetOrPutResult {
            const gop = try self.getOrPutContextAdapted(allocator, key, ctx, ctx);
            if (!gop.found_existing) {
                gop.key_ptr.* = key;
            }
            return gop;
        }
        pub fn getOrPutAdapted(self: *Self, allocator: Allocator, key: anytype, key_ctx: anytype) Allocator.Error!GetOrPutResult {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getOrPutContextAdapted instead.");
            return self.getOrPutContextAdapted(allocator, key, key_ctx, undefined);
        }
        pub fn getOrPutContextAdapted(self: *Self, allocator: Allocator, key: anytype, key_ctx: anytype, ctx: Context) Allocator.Error!GetOrPutResult {
            self.growIfNeeded(allocator, 1, ctx) catch |err| {
                // If allocation fails, try to do the lookup anyway.
                // If we find an existing item, we can return it.
                // Otherwise return the error, we could not add another.
                const index = self.getIndex(key, key_ctx) orelse return err;
                return GetOrPutResult{
                    .key_ptr = &self.keys()[index],
                    .value_ptr = &self.values()[index],
                    .found_existing = true,
                };
            };
            return self.getOrPutAssumeCapacityAdapted(key, key_ctx);
        }

        pub fn getOrPutAssumeCapacity(self: *Self, key: K) GetOrPutResult {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getOrPutAssumeCapacityContext instead.");
            return self.getOrPutAssumeCapacityContext(key, undefined);
        }
        pub fn getOrPutAssumeCapacityContext(self: *Self, key: K, ctx: Context) GetOrPutResult {
            const result = self.getOrPutAssumeCapacityAdapted(key, ctx);
            if (!result.found_existing) {
                result.key_ptr.* = key;
            }
            return result;
        }
        pub fn getOrPutAssumeCapacityAdapted(self: *Self, key: anytype, ctx: anytype) GetOrPutResult {

            // If you get a compile error on this line, it means that your generic hash
            // function is invalid for these parameters.
            const hash = ctx.hash(key);
            // verifyContext can't verify the return type of generic hash functions,
            // so we need to double-check it here.
            if (@TypeOf(hash) != Hash) {
                @compileError("Context " ++ @typeName(@TypeOf(ctx)) ++ " has a generic hash function that returns the wrong type! " ++ @typeName(Hash) ++ " was expected, but found " ++ @typeName(@TypeOf(hash)));
            }

            const mask = self.capacity() - 1;
            const fingerprint = Metadata.takeFingerprint(hash);
            var limit = self.capacity();
            var idx = @as(usize, @truncate(hash & mask));

            var first_tombstone_idx: usize = self.capacity(); // invalid index
            var metadata = self.metadata.? + idx;
            while (!metadata[0].isFree() and limit != 0) {
                if (metadata[0].isUsed() and metadata[0].fingerprint == fingerprint) {
                    const test_key = &self.keys()[idx];
                    // If you get a compile error on this line, it means that your generic eql
                    // function is invalid for these parameters.
                    const eql = ctx.eql(key, test_key.*);
                    // verifyContext can't verify the return type of generic eql functions,
                    // so we need to double-check it here.
                    if (@TypeOf(eql) != bool) {
                        @compileError("Context " ++ @typeName(@TypeOf(ctx)) ++ " has a generic eql function that returns the wrong type! bool was expected, but found " ++ @typeName(@TypeOf(eql)));
                    }
                    if (eql) {
                        return GetOrPutResult{
                            .key_ptr = test_key,
                            .value_ptr = &self.values()[idx],
                            .found_existing = true,
                        };
                    }
                } else if (first_tombstone_idx == self.capacity() and metadata[0].isTombstone()) {
                    first_tombstone_idx = idx;
                }

                limit -= 1;
                idx = (idx + 1) & mask;
                metadata = self.metadata.? + idx;
            }

            if (first_tombstone_idx < self.capacity()) {
                // Cheap try to lower probing lengths after deletions. Recycle a tombstone.
                idx = first_tombstone_idx;
                metadata = self.metadata.? + idx;
            }
            // We're using a slot previously free or a tombstone.
            self.available -= 1;

            metadata[0].fill(fingerprint);
            const new_key = &self.keys()[idx];
            const new_value = &self.values()[idx];
            new_key.* = undefined;
            new_value.* = undefined;
            self.size += 1;

            return GetOrPutResult{
                .key_ptr = new_key,
                .value_ptr = new_value,
                .found_existing = false,
            };
        }

        pub fn getOrPutValue(self: *Self, allocator: Allocator, key: K, value: V) Allocator.Error!Entry {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call getOrPutValueContext instead.");
            return self.getOrPutValueContext(allocator, key, value, undefined);
        }
        pub fn getOrPutValueContext(self: *Self, allocator: Allocator, key: K, value: V, ctx: Context) Allocator.Error!Entry {
            const res = try self.getOrPutAdapted(allocator, key, ctx);
            if (!res.found_existing) {
                res.key_ptr.* = key;
                res.value_ptr.* = value;
            }
            return Entry{ .key_ptr = res.key_ptr, .value_ptr = res.value_ptr };
        }

        /// Return true if there is a value associated with key in the map.
        pub fn contains(self: *const Self, key: K) bool {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call containsContext instead.");
            return self.containsContext(key, undefined);
        }
        pub fn containsContext(self: *const Self, key: K, ctx: Context) bool {
            return self.containsAdapted(key, ctx);
        }
        pub fn containsAdapted(self: *const Self, key: anytype, ctx: anytype) bool {
            return self.getIndex(key, ctx) != null;
        }

        fn removeByIndex(self: *Self, idx: usize) void {
            self.metadata.?[idx].remove();
            self.keys()[idx] = undefined;
            self.values()[idx] = undefined;
            self.size -= 1;
            self.available += 1;
        }

        /// If there is an `Entry` with a matching key, it is deleted from
        /// the hash map, and this function returns true.  Otherwise this
        /// function returns false.
        pub fn remove(self: *Self, key: K) bool {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call removeContext instead.");
            return self.removeContext(key, undefined);
        }
        pub fn removeContext(self: *Self, key: K, ctx: Context) bool {
            return self.removeAdapted(key, ctx);
        }
        pub fn removeAdapted(self: *Self, key: anytype, ctx: anytype) bool {
            if (self.getIndex(key, ctx)) |idx| {
                self.removeByIndex(idx);
                return true;
            }

            return false;
        }

        /// Delete the entry with key pointed to by key_ptr from the hash map.
        /// key_ptr is assumed to be a valid pointer to a key that is present
        /// in the hash map.
        pub fn removeByPtr(self: *Self, key_ptr: *K) void {
            // TODO: replace with pointer subtraction once supported by zig
            // if @sizeOf(K) == 0 then there is at most one item in the hash
            // map, which is assumed to exist as key_ptr must be valid.  This
            // item must be at index 0.
            const idx = if (@sizeOf(K) > 0)
                (@intFromPtr(key_ptr) - @intFromPtr(self.keys())) / @sizeOf(K)
            else
                0;

            self.removeByIndex(idx);
        }

        fn initMetadatas(self: *Self) void {
            @memset(@as([*]u8, @ptrCast(self.metadata.?))[0 .. @sizeOf(Metadata) * self.capacity()], 0);
        }

        // This counts the number of occupied slots (not counting tombstones), which is
        // what has to stay under the max_load_percentage of capacity.
        fn load(self: *const Self) Size {
            const max_load = (self.capacity() * max_load_percentage) / 100;
            assert(max_load >= self.available);
            return @as(Size, @truncate(max_load - self.available));
        }

        fn growIfNeeded(self: *Self, allocator: Allocator, new_count: Size, ctx: Context) Allocator.Error!void {
            if (new_count > self.available) {
                try self.grow(allocator, capacityForSize(self.load() + new_count), ctx);
            }
        }

        pub fn clone(self: Self, allocator: Allocator) Allocator.Error!Self {
            if (@sizeOf(Context) != 0)
                @compileError("Cannot infer context " ++ @typeName(Context) ++ ", call cloneContext instead.");
            return self.cloneContext(allocator, @as(Context, undefined));
        }
        pub fn cloneContext(self: Self, allocator: Allocator, new_ctx: anytype) Allocator.Error!HashMapUnmanaged(K, V, @TypeOf(new_ctx), max_load_percentage) {
            var other = HashMapUnmanaged(K, V, @TypeOf(new_ctx), max_load_percentage){};
            if (self.size == 0)
                return other;

            const new_cap = capacityForSize(self.size);
            try other.allocate(allocator, new_cap);
            other.initMetadatas();
            other.available = @truncate((new_cap * max_load_percentage) / 100);

            var i: Size = 0;
            var metadata = self.metadata.?;
            const keys_ptr = self.keys();
            const values_ptr = self.values();
            while (i < self.capacity()) : (i += 1) {
                if (metadata[i].isUsed()) {
                    other.putAssumeCapacityNoClobberContext(keys_ptr[i], values_ptr[i], new_ctx);
                    if (other.size == self.size)
                        break;
                }
            }

            return other;
        }

        /// Set the map to an empty state, making deinitialization a no-op, and
        /// returning a copy of the original.
        pub fn move(self: *Self) Self {
            const result = self.*;
            self.* = .{};
            return result;
        }

        /// Rehash the map, in-place
        pub fn rehash(self: *Self, ctx: anytype) void {
            const mask = self.capacity() - 1;

            var metadata = self.metadata.?;
            var keys_ptr = self.keys();
            var values_ptr = self.values();
            var curr: Size = 0;

            // While we are re-hashing every slot, we will use the
            // fingerprint to mark used buckets as being used and either free
            // (needing to be rehashed) or tombstone (already rehashed).

            while (curr < self.capacity()) : (curr += 1) {
                metadata[curr].fingerprint = Metadata.free;
            }

            // Now iterate over all the buckets, rehashing them

            curr = 0;
            while (curr < self.capacity()) {
                if (!metadata[curr].isUsed()) {
                    assert(metadata[curr].isFree());
                    curr += 1;
                    continue;
                }

                const hash = ctx.hash(keys_ptr[curr]);
                const fingerprint = Metadata.takeFingerprint(hash);
                var idx = @as(usize, @truncate(hash & mask));

                // For each bucket, rehash to an index:
                // 1) before the cursor, probed into a free slot, or
                // 2) equal to the cursor, no need to move, or
                // 3) ahead of the cursor, probing over already rehashed

                while ((idx < curr and metadata[idx].isUsed()) or
                    (idx > curr and metadata[idx].fingerprint == Metadata.tombstone))
                {
                    idx = (idx + 1) & mask;
                }

                if (idx < curr) {
                    assert(metadata[idx].isFree());
                    metadata[idx].fill(fingerprint);
                    keys_ptr[idx] = keys_ptr[curr];
                    values_ptr[idx] = values_ptr[curr];

                    metadata[curr].used = 0;
                    assert(metadata[curr].isFree());
                    keys_ptr[curr] = undefined;
                    values_ptr[curr] = undefined;

                    curr += 1;
                } else if (idx == curr) {
                    metadata[idx].fingerprint = fingerprint;
                    curr += 1;
                } else {
                    assert(metadata[idx].fingerprint != Metadata.tombstone);
                    metadata[idx].fingerprint = Metadata.tombstone;
                    if (metadata[idx].isUsed()) {
                        std.mem.swap(K, &keys_ptr[curr], &keys_ptr[idx]);
                        std.mem.swap(V, &values_ptr[curr], &values_ptr[idx]);
                    } else {
                        metadata[idx].used = 1;
                        keys_ptr[idx] = keys_ptr[curr];
                        values_ptr[idx] = values_ptr[curr];

                        metadata[curr].fingerprint = Metadata.free;
                        metadata[curr].used = 0;
                        keys_ptr[curr] = undefined;
                        values_ptr[curr] = undefined;

                        curr += 1;
                    }
                }
            }
        }

        fn grow(self: *Self, allocator: Allocator, new_capacity: Size, ctx: Context) Allocator.Error!void {
            @setCold(true);
            const new_cap = @max(new_capacity, minimal_capacity);
            assert(new_cap > self.capacity());
            assert(std.math.isPowerOfTwo(new_cap));

            var map = Self{};
            defer map.deinit(allocator);
            try map.allocate(allocator, new_cap);
            map.initMetadatas();
            map.available = @truncate((new_cap * max_load_percentage) / 100);

            if (self.size != 0) {
                const old_capacity = self.capacity();
                var i: Size = 0;
                var metadata = self.metadata.?;
                const keys_ptr = self.keys();
                const values_ptr = self.values();
                while (i < old_capacity) : (i += 1) {
                    if (metadata[i].isUsed()) {
                        map.putAssumeCapacityNoClobberContext(keys_ptr[i], values_ptr[i], ctx);
                        if (map.size == self.size)
                            break;
                    }
                }
            }

            self.size = 0;
            std.mem.swap(Self, self, &map);
        }

        fn allocate(self: *Self, allocator: Allocator, new_capacity: Size) Allocator.Error!void {
            const header_align = @alignOf(Header);
            const key_align = if (@sizeOf(K) == 0) 1 else @alignOf(K);
            const val_align = if (@sizeOf(V) == 0) 1 else @alignOf(V);
            const max_align = comptime @max(header_align, key_align, val_align);

            const meta_size = @sizeOf(Header) + new_capacity * @sizeOf(Metadata);
            comptime assert(@alignOf(Metadata) == 1);

            const keys_start = std.mem.alignForward(usize, meta_size, key_align);
            const keys_end = keys_start + new_capacity * @sizeOf(K);

            const vals_start = std.mem.alignForward(usize, keys_end, val_align);
            const vals_end = vals_start + new_capacity * @sizeOf(V);

            const total_size = std.mem.alignForward(usize, vals_end, max_align);

            const slice = try allocator.alignedAlloc(u8, max_align, total_size);
            const ptr = @intFromPtr(slice.ptr);

            const metadata = ptr + @sizeOf(Header);

            const hdr = @as(*Header, @ptrFromInt(ptr));
            if (@sizeOf([*]V) != 0) {
                hdr.values = @as([*]V, @ptrFromInt(ptr + vals_start));
            }
            if (@sizeOf([*]K) != 0) {
                hdr.keys = @as([*]K, @ptrFromInt(ptr + keys_start));
            }
            hdr.capacity = new_capacity;
            self.metadata = @as([*]Metadata, @ptrFromInt(metadata));
        }

        fn deallocate(self: *Self, allocator: Allocator) void {
            if (self.metadata == null) return;

            const header_align = @alignOf(Header);
            const key_align = if (@sizeOf(K) == 0) 1 else @alignOf(K);
            const val_align = if (@sizeOf(V) == 0) 1 else @alignOf(V);
            const max_align = comptime @max(header_align, key_align, val_align);

            const cap = self.capacity();
            const meta_size = @sizeOf(Header) + cap * @sizeOf(Metadata);
            comptime assert(@alignOf(Metadata) == 1);

            const keys_start = std.mem.alignForward(usize, meta_size, key_align);
            const keys_end = keys_start + cap * @sizeOf(K);

            const vals_start = std.mem.alignForward(usize, keys_end, val_align);
            const vals_end = vals_start + cap * @sizeOf(V);

            const total_size = std.mem.alignForward(usize, vals_end, max_align);

            const slice = @as([*]align(max_align) u8, @ptrFromInt(@intFromPtr(self.header())))[0..total_size];
            allocator.free(slice);

            self.metadata = null;
            self.available = 0;
        }

        /// This function is used in the debugger pretty formatters in tools/ to fetch the
        /// header type to facilitate fancy debug printing for this type.
        fn dbHelper(self: *Self, hdr: *Header, entry: *Entry) void {
            _ = self;
            _ = hdr;
            _ = entry;
        }
        comptime {
            if (builtin.mode == .Debug) {
                _ = &dbHelper;
            }
        }
    };
}
