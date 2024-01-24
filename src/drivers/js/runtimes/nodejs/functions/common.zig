const Kivi = @import("Kivi");
const ntypes = @import("../napi-bindings.zig");
const symbols = @import("../symbols.zig").Symbols;

pub fn get_null(env: ntypes.napi_env) ntypes.napi_value {
    var null_value: ntypes.napi_value = undefined;
    _ = symbols.napi_get_null(env, &null_value);
    return null_value;
}
pub fn get_undefined(env: ntypes.napi_env) ntypes.napi_value {
    var undefined_value: ntypes.napi_value = undefined;
    _ = symbols.napi_get_undefined(env, &undefined_value);
    return undefined_value;
}

pub fn exception_ret(env: ntypes.napi_env, msg: [:0]const u8) ntypes.napi_value {
    _ = symbols.napi_throw_error(env, null, msg);
    return get_undefined(env);
}

pub fn get_buffer_string(env: ntypes.napi_env, buf: ntypes.napi_value) ![]u8 {
    var len: usize = 0;
    var data: ?*anyopaque = undefined;
    if (symbols.napi_get_buffer_info(env, buf, &data, &len) == ntypes.napi_ok and len != 0) {
        return @as([*]u8, @ptrCast(@alignCast(data)))[0..len];
    }
    return error.InvalidBuffer;
}
pub fn create_buffer_string(env: ntypes.napi_env, buf: []u8) !ntypes.napi_value {
    var newbuf: ntypes.napi_value = undefined;
    const lastbuf = @as(?*anyopaque, @ptrCast(@alignCast(buf.ptr)));
    if (symbols.napi_create_buffer_copy(env, buf.len, lastbuf, null, &newbuf) == ntypes.napi_ok) {
        return newbuf;
    }
    return error.FailedToCreateBufferFromString;
}

pub inline fn parse_args(env: ntypes.napi_env, info: ntypes.napi_callback_info, comptime args_count: comptime_int) ![args_count]ntypes.napi_value {
    var argc_napi: usize = args_count;
    var args: [args_count]ntypes.napi_value = undefined;
    if (symbols.napi_get_cb_info(env, info, &argc_napi, &args, null, null) == ntypes.napi_ok) {
        return args;
    }

    return error.NoArgs;
}
pub fn get_kivi(env: ntypes.napi_env, arraybuffer: ntypes.napi_value) !*Kivi {
    var length: usize = undefined;
    var ptr: ?*anyopaque = null;
    if (symbols.napi_get_arraybuffer_info(env, arraybuffer, &ptr, &length) == ntypes.napi_ok) {
        return @as(*Kivi, @ptrCast(@alignCast(ptr)));
    }

    return error.FailedToGetKiviInstance;
}
