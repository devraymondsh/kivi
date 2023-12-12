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

pub export fn kivi_init(self: *Kivi, config_arg: ?*const Kivi.Config) usize {
    var config = &Kivi.Config{};
    if (config_arg != null) {
        config = config_arg.?;
    }

    return self.init(config) catch 0;
}
pub export fn kivi_deinit(self: *Kivi) void {
    self.deinit();
}
pub export fn kivi_get(self: *const Kivi, key: [*]const u8, key_len: usize, val: ?[*]u8, val_len: usize) usize {
    return self.get(key[0..key_len], if (val) |v| v[0..val_len] else null) catch {
        return 0;
    };
}
pub export fn kivi_set(self: *Kivi, key: [*]const u8, key_len: usize, val: [*]const u8, val_len: usize) usize {
    return self.set(key[0..key_len], val[0..val_len]) catch 0;
}
pub export fn kivi_del(self: *Kivi, key: [*]const u8, key_len: usize, val: ?[*]u8, val_len: usize) usize {
    return self.del(key[0..key_len], if (val) |v| v[0..val_len] else null) catch 0;
}

comptime {
    _ = Kivi;
}
pub const _start = {};
