const std = @import("std");
const Mmap = @import("mmap.zig");

len: usize,
keysMmap: Mmap,
valuesMmap: Mmap,
allocator: std.mem.Allocator,
map: std.StringHashMapUnmanaged([]u8),

const Kivi = @This();

pub const Config = extern struct {
    keys_mmap_size: usize = 300 * 1024 * 1024,
    mmap_page_size: usize = 100 * 1024 * 1024,
    values_mmap_size: usize = 700 * 1024 * 1024,
};

pub fn init(allocator: std.mem.Allocator, config: *const Config) !Kivi {
    return .{
        .len = 0,
        .allocator = allocator,
        .map = std.StringHashMapUnmanaged([]u8){},
        .keysMmap = try Mmap.init(config.keys_mmap_size, config.mmap_page_size),
        .valuesMmap = try Mmap.init(config.values_mmap_size, config.mmap_page_size),
    };
}

pub export fn kivi_init(self: *Kivi, config_arg: ?*const Config) usize {
    const Arena = std.heap.ArenaAllocator;
    const GPA = std.heap.GeneralPurposeAllocator(.{});
    var arena_stack = Arena.init(std.heap.page_allocator);
    const arena = arena_stack.allocator().create(Arena) catch return 0;
    arena.* = arena_stack;
    const gpa = arena.allocator().create(GPA) catch {
        arena_stack.allocator().destroy(arena);
        return 0;
    };
    gpa.* = GPA{};
    self.len = 0;
    self.allocator = gpa.allocator();

    var config = Config{};
    if (config_arg != null) {
        config.mmap_page_size = config_arg.?.mmap_page_size;
        config.keys_mmap_size = config_arg.?.keys_mmap_size;
        config.values_mmap_size = config_arg.?.values_mmap_size;
    }

    self.keysMmap = Mmap.init(config.keys_mmap_size, config.mmap_page_size) catch {
        arena.allocator().destroy(gpa);
        arena_stack.allocator().destroy(arena);
        return 0;
    };
    self.valuesMmap = Mmap.init(config.values_mmap_size, config.mmap_page_size) catch {
        self.keysMmap.deinit();
        arena.allocator().destroy(gpa);
        arena_stack.allocator().destroy(arena);
        return 0;
    };
    self.map = .{};

    return @sizeOf(Kivi);
}

pub fn deinit(self: *Kivi) void {
    self.map.deinit(self.allocator);
    self.keysMmap.deinit();
    self.valuesMmap.deinit();
}

pub export fn kivi_deinit(self: *Kivi) void {
    self.deinit();
}

/// if val is null: returns length if pair exists, otherwise 0
/// else: returns the bytes written if pair exists and value was successfully written, otherwise 0
pub fn get(self: *const Kivi, key: []const u8, val: ?[]u8) usize {
    if (val == null) {
        if (self.map.getPtr(key)) |p| return p.len;
        return 0;
    }
    const stored = self.map.get(key);
    if (stored == null) return 0;
    if (val.?.len < stored.?.len) return 0;
    @memcpy(val.?[0..stored.?.len], stored.?);
    return stored.?.len;
}

pub export fn kivi_get(self: *const Kivi, key: [*]const u8, key_len: usize, val: ?[*]u8, val_len: usize) usize {
    return self.get(key[0..key_len], if (val) |v| v[0..val_len] else null);
}

/// Returns value length if pair was successfully stored, otherwise 0
pub fn set(self: *Kivi, key: []const u8, val: []const u8) usize {
    if (val.len == 0) return 0;
    const key_cur = self.keysMmap.cursor;
    const keys_push_res = self.keysMmap.push(key) catch return 0;
    const value_cur = self.valuesMmap.cursor;
    const values_push_res = self.valuesMmap.push(val) catch {
        self.keysMmap.cursor = key_cur;
        return 0;
    };

    self.map.put(self.allocator, keys_push_res, values_push_res) catch {
        self.keysMmap.cursor = key_cur;
        self.valuesMmap.cursor = value_cur;
        return 0;
    };
    return val.len;
}

pub export fn kivi_set(self: *Kivi, key: [*]const u8, key_len: usize, val: [*]const u8, val_len: usize) usize {
    return self.set(key[0..key_len], val[0..val_len]);
}

pub fn del(self: *Kivi, key: []const u8, val: ?[]u8) usize {
    const stored = self.map.getPtr(key);
    if (stored == null) return 0;
    const len = stored.?.len;
    if (val == null) {
        self.map.removeByPtr(stored.?);
        return len;
    }
    if (val.?.len < len) return 0;
    @memcpy(val.?[0..len], stored.?.*);
    self.map.removeByPtr(stored.?);
    return len;
}

pub export fn kivi_del(self: *Kivi, key: [*]const u8, key_len: usize, val: ?[*]u8, val_len: usize) usize {
    return self.del(key[0..key_len], if (val) |v| v[0..val_len] else null);
}
