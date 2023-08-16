const std = @import("std");
const builtin = @import("builtin");
const Kivi = @import("Kivi.zig");

// For debug info in FFI
const is_debug = builtin.mode == std.builtin.Mode.Debug;
export fn dump_stack_trace() void {
    if (is_debug) {
        std.debug.dumpCurrentStackTrace(@returnAddress());
    }
}
export fn setup_debug_handlers() void {
    if (is_debug) {
        std.debug.maybeEnableSegfaultHandler();
    }
}

comptime {
    _ = Kivi;
}
pub const _start = {};

test "C-like" {
    var kv: Kivi = undefined;
    const config_arg: ?*const Kivi.Config = null;
    try std.testing.expect(Kivi.kivi_init(&kv, config_arg) == @sizeOf(Kivi));

    try std.testing.expect(Kivi.kivi_set(&kv, "foo", "foo".len, "bar", "bar".len) == 3);

    var val: [1024]u8 = undefined;
    try std.testing.expect(Kivi.kivi_get(&kv, "foo", "foo".len, &val, val.len) == 3);
    try std.testing.expect(std.mem.eql(u8, val[0..3], "bar"));

    try std.testing.expect(Kivi.kivi_del(&kv, "foo", "foo".len, null, 0) == 3);

    try std.testing.expect(Kivi.kivi_get(&kv, "foo", 3, null, 0) == 0);
}
