const builtin = @import("builtin");

const is_windows = builtin.target.os.tag == .windows;

pub const Symbols = if (is_windows) @import("symbols-win.zig") else @import("napi-bindings.zig");
