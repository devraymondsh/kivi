const std = @import("std");
const builtin = @import("builtin");
pub const Kivi = @import("Kivi.zig");

// For debug info in FFI
const is_debug = builtin.mode == std.builtin.Mode.Debug;
pub export fn dump_stack_trace() void {
    if (is_debug) {
        std.debug.dumpCurrentStackTrace(@returnAddress());
    }
}
pub export fn setup_debug_handlers() void {
    if (is_debug) {
        std.debug.maybeEnableSegfaultHandler();
    }
}

pub export fn kivi_init(self: *Kivi, config: ?*const Kivi.Config) usize {
    return self.init(config);
}
pub export fn kivi_deinit(self: *Kivi) void {
    self.deinit();
}
pub export fn kivi_get(self: *const Kivi, key: [*]const u8, key_len: usize, val: ?[*]u8, val_len: usize) usize {
    return self.get(key[0..key_len], if (val) |v| v[0..val_len] else null);
}
pub export fn kivi_set(self: *Kivi, key: [*]const u8, key_len: usize, val: [*]const u8, val_len: usize) usize {
    return self.set(key[0..key_len], val[0..val_len]);
}
pub export fn kivi_del(self: *Kivi, key: [*]const u8, key_len: usize, val: ?[*]u8, val_len: usize) usize {
    return self.del(key[0..key_len], if (val) |v| v[0..val_len] else null);
}

comptime {
    _ = Kivi;
}
pub const _start = {};

test "C-like" {
    var kv: Kivi = undefined;
    const config_arg: ?*const Kivi.Config = null;
    try std.testing.expect(kivi_init(&kv, config_arg) == @sizeOf(Kivi));

    try std.testing.expect(kivi_set(&kv, "foo", "foo".len, "bar", "bar".len) == 3);

    var val: [1024]u8 = undefined;
    try std.testing.expect(kivi_get(&kv, "foo", "foo".len, &val, val.len) == 3);
    try std.testing.expect(std.mem.eql(u8, val[0..3], "bar"));

    try std.testing.expect(kivi_del(&kv, "foo", "foo".len, null, 0) == 3);

    try std.testing.expect(kivi_get(&kv, "foo", 3, null, 0) == 0);
}
