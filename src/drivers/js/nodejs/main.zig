const std = @import("std");
const Kivi = @import("Kivi");
const symbols = @import("symbols.zig");
const ntypes = @import("napi-bindings.zig");

var allocator = std.heap.page_allocator;
const KEYS_DEFAULT_BUF_SIZE: comptime_int = 500 * 1024;

inline fn get_args(env: ntypes.napi_env, info: ntypes.napi_callback_info, comptime args_count: comptime_int) ![args_count]ntypes.napi_value {
    var args: [args_count]ntypes.napi_value = undefined;
    var argc_napi: usize = args_count;
    const cb_status: ntypes.napi_status = symbols.napi_get_cb_info(env, info, &argc_napi, &args, null, null);
    if (cb_status == ntypes.napi_ok) {
        return args;
    }
    _ = symbols.napi_throw_error(env, "1", "INVALID_ARGS");

    return error.NoArgs;
}
fn arg_to_kivi(env: ntypes.napi_env, arraybuffer: ntypes.napi_value) ?*Kivi {
    var length: usize = undefined;
    var ptr: ?*anyopaque = undefined;
    if (symbols.napi_get_arraybuffer_info(env, arraybuffer, &ptr, &length) == ntypes.napi_ok) {
        return @as(*Kivi, @ptrCast(@alignCast(ptr)));
    }
    return null;
}
fn get_string_length(env: ntypes.napi_env, arraybuffer: ntypes.napi_value) usize {
    var len: usize = undefined;
    if (symbols.napi_get_value_string_utf8(env, arraybuffer, null, 0, &len) == ntypes.napi_ok) {
        return len;
    }
    return 0;
}
fn stack_string_to_buffer(env: ntypes.napi_env, arraybuffer: ntypes.napi_value, buf: []u8) usize {
    var len: usize = undefined;
    if (symbols.napi_get_value_string_utf8(env, arraybuffer, buf.ptr, buf.len, &len) == ntypes.napi_ok) {
        return len;
    }
    return 0;
}
fn string_to_buffer(env: ntypes.napi_env, arraybuffer: ntypes.napi_value, buf: []u8) void {
    var len: usize = undefined;
    _ = symbols.napi_get_value_string_utf8(env, arraybuffer, buf.ptr, buf.len + 1, &len);
}
fn buffer_to_string(env: ntypes.napi_env, buf: []u8) ntypes.napi_value {
    var string: ntypes.napi_value = undefined;
    if (symbols.napi_create_string_utf8(env, buf.ptr, buf.len, &string) == ntypes.napi_ok) {
        return string;
    }
    return null;
}
fn new_unint(env: ntypes.napi_env, value: u32) ntypes.napi_value {
    var result: ntypes.napi_value = undefined;
    if (symbols.napi_create_uint32(env, value, &result) == ntypes.napi_ok) {
        return result;
    }
    return null;
}
fn new_null(env: ntypes.napi_env) ntypes.napi_value {
    var null_value: ntypes.napi_value = undefined;
    if (symbols.napi_get_null(env, &null_value) == ntypes.napi_ok) {
        return null_value;
    }
    return null;
}
fn new_undefined(env: ntypes.napi_env) ntypes.napi_value {
    var undefined_value: ntypes.napi_value = undefined;
    if (symbols.napi_get_undefined(env, &undefined_value) == ntypes.napi_ok) {
        return undefined_value;
    }
    return null;
}
inline fn allocate_temp_key(env: ntypes.napi_env, napi_buffer: ntypes.napi_value, should_be_freed: *bool) ![]u8 {
    var temp_buf: [KEYS_DEFAULT_BUF_SIZE]u8 = undefined;
    const length = get_string_length(env, napi_buffer);

    if (length > KEYS_DEFAULT_BUF_SIZE) {
        const key_buf = allocator.alloc(u8, length) catch return error.Failed;
        should_be_freed.* = true;

        string_to_buffer(env, napi_buffer, key_buf);

        return key_buf;
    } else if (length == 0) {
        return error.Failed;
    }

    string_to_buffer(env, napi_buffer, &temp_buf);

    return temp_buf[0..length];
}

pub export fn kivi_init_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    const args = get_args(env, info, 1) catch {
        return new_undefined(env);
    };

    const kivi_result: usize = arg_to_kivi(env, args[0]).?.init(&Kivi.Config{}) catch 0;
    if (kivi_result == @sizeOf(Kivi)) {
        return new_unint(env, @intCast(kivi_result));
    }

    return new_null(env);
}
pub export fn kivi_deinit_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    const args = get_args(env, info, 1) catch {
        return new_undefined(env);
    };

    arg_to_kivi(env, args[0]).?.deinit();

    return new_undefined(env);
}

fn fetch_single(self: *Kivi, env: ntypes.napi_env, n_keybuf: ntypes.napi_value) ![]u8 {
    var should_be_freed = false;
    const key = try allocate_temp_key(env, n_keybuf, &should_be_freed);
    defer {
        if (should_be_freed) {
            allocator.free(key);
        }
    }

    return self.get_slice(key);
}
pub export fn kivi_get_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    const args = get_args(env, info, 2) catch {
        return new_undefined(env);
    };

    const self = arg_to_kivi(env, args[0]).?;
    const value = fetch_single(self, env, args[1]) catch {
        return new_null(env);
    };

    return buffer_to_string(env, value);
}
pub export fn kivi_bulk_get_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    const args = get_args(env, info, 2) catch {
        return new_undefined(env);
    };

    const self = arg_to_kivi(env, args[0]).?;

    var array_len: u32 = 0;
    _ = symbols.napi_get_array_length(env, args[1], &array_len);
    var result_arr: ntypes.napi_value = undefined;
    _ = symbols.napi_create_array_with_length(env, @intCast(array_len), &result_arr);

    for (0..array_len) |idx| {
        var napi_key: ntypes.napi_value = undefined;
        _ = symbols.napi_get_element(env, args[1], @intCast(idx), &napi_key);

        var res: ntypes.napi_value = undefined;
        if (fetch_single(self, env, napi_key)) |value| {
            res = buffer_to_string(env, value);
        } else |_| {
            res = new_null(env);
        }

        _ = symbols.napi_set_element(env, result_arr, @intCast(idx), res);
    }

    return result_arr;
}

fn set_single(self: *Kivi, env: ntypes.napi_env, n_keybuf: ntypes.napi_value, n_valbuf: ntypes.napi_value) !usize {
    const key_len: usize = get_string_length(env, n_keybuf);
    if (key_len == 0) {
        return error.InvalidLength;
    }

    const key_buf = try self.reserve_key(key_len);
    string_to_buffer(env, n_keybuf, key_buf);

    const value_len: usize = get_string_length(env, n_valbuf);
    if (value_len == 0) {
        return error.InvalidLength;
    }

    const value_buf = try self.reserve_value(value_len);
    string_to_buffer(env, n_valbuf, value_buf);

    try self.putEntry(key_buf, value_buf);

    return value_len;
}
pub export fn kivi_set_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    const args = get_args(env, info, 3) catch {
        return new_undefined(env);
    };

    const self = arg_to_kivi(env, args[0]).?;
    const value_len = set_single(self, env, args[1], args[2]) catch 0;

    return new_unint(env, @intCast(value_len));
}
pub export fn kivi_bulk_set_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    const args = get_args(env, info, 2) catch {
        return new_undefined(env);
    };

    const self = arg_to_kivi(env, args[0]).?;

    var array_len: u32 = 0;
    _ = symbols.napi_get_array_length(env, args[1], &array_len);
    var result_arr: ntypes.napi_value = undefined;
    _ = symbols.napi_create_array_with_length(env, @intCast(array_len), &result_arr);

    for (0..array_len) |idx| {
        var napi_kivi: ntypes.napi_value = undefined;
        _ = symbols.napi_get_element(env, args[1], @intCast(idx), &napi_kivi);
        var napi_key: ntypes.napi_value = undefined;
        _ = symbols.napi_get_named_property(env, napi_kivi, "key", &napi_key);
        var napi_value: ntypes.napi_value = undefined;
        _ = symbols.napi_get_named_property(env, napi_kivi, "value", &napi_value);

        var res = true;
        if (set_single(self, env, napi_key, napi_value)) |_| {} else |_| {
            res = false;
        }

        var napi_res: ntypes.napi_value = undefined;
        _ = symbols.napi_get_boolean(env, res, &napi_res);
        _ = symbols.napi_set_element(env, result_arr, @intCast(idx), napi_res);
    }

    return result_arr;
}

fn del_single(self: *Kivi, env: ntypes.napi_env, n_keybuf: ntypes.napi_value) ![]u8 {
    var should_be_freed = false;
    const key = try allocate_temp_key(env, n_keybuf, &should_be_freed);
    defer {
        if (should_be_freed) {
            allocator.free(key);
        }
    }

    return try self.del_slice(key);
}
pub export fn kivi_fetch_del_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    const args = get_args(env, info, 2) catch {
        return new_undefined(env);
    };

    const self = arg_to_kivi(env, args[0]).?;
    const value = del_single(self, env, args[1]) catch {
        return new_null(env);
    };

    const string = buffer_to_string(env, value);

    self.del_value(value);

    return string;
}
pub export fn kivi_del_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    _ = kivi_fetch_del_js(env, info);
    return new_undefined(env);
}
pub export fn kivi_bulk_fetch_del_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    const args = get_args(env, info, 2) catch {
        return new_undefined(env);
    };

    const self = arg_to_kivi(env, args[0]).?;

    var array_len: u32 = 0;
    _ = symbols.napi_get_array_length(env, args[1], &array_len);
    var result_arr: ntypes.napi_value = undefined;
    _ = symbols.napi_create_array_with_length(env, @intCast(array_len), &result_arr);

    for (0..array_len) |idx| {
        var napi_key: ntypes.napi_value = undefined;
        _ = symbols.napi_get_element(env, args[1], @intCast(idx), &napi_key);

        var res: ntypes.napi_value = undefined;
        if (del_single(self, env, napi_key)) |value| {
            res = buffer_to_string(env, value);
            self.del_value(value);
        } else |_| {
            res = new_null(env);
        }

        _ = symbols.napi_set_element(env, result_arr, @intCast(idx), res);
    }

    return result_arr;
}
pub export fn kivi_bulk_del_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    _ = kivi_bulk_fetch_del_js(env, info);
    return new_undefined(env);
}

pub export fn node_api_module_get_api_version_v1() i32 {
    return 6;
}

const Function = struct {
    name: [*c]const u8,
    method: ?*const fn (?*ntypes.struct_napi_env__, ?*ntypes.struct_napi_callback_info__) callconv(.C) ?*ntypes.struct_napi_value__,
};
const functions = [_]Function{ Function{
    .name = "kivi_init",
    .method = &kivi_init_js,
}, Function{
    .name = "kivi_bulk_get",
    .method = &kivi_bulk_get_js,
}, Function{
    .name = "kivi_get",
    .method = &kivi_get_js,
}, Function{
    .name = "kivi_set",
    .method = &kivi_set_js,
}, Function{
    .name = "kivi_bulk_set",
    .method = &kivi_bulk_set_js,
}, Function{
    .name = "kivi_del",
    .method = &kivi_del_js,
}, Function{
    .name = "kivi_fetch_del",
    .method = &kivi_fetch_del_js,
}, Function{
    .name = "kivi_bulk_fetch_del",
    .method = &kivi_bulk_fetch_del_js,
}, Function{
    .name = "kivi_bulk_del",
    .method = &kivi_bulk_del_js,
}, Function{
    .name = "kivi_deinit",
    .method = &kivi_deinit_js,
} };
pub export fn napi_register_module_v1(env: ntypes.napi_env, exports: ntypes.napi_value) ntypes.napi_value {
    symbols.init_symbols();

    var bindings: [functions.len]ntypes.napi_property_descriptor = undefined;
    inline for (functions, 0..) |function, index| {
        bindings[index] = .{
            .utf8name = function.name,
            .name = null,
            .method = function.method,
            .getter = null,
            .setter = null,
            .value = null,
            .attributes = ntypes.napi_enumerable,
            .data = null,
        };
    }

    const define_properties_status = symbols.napi_define_properties(env, exports, bindings.len, &bindings);
    if (define_properties_status != ntypes.napi_ok) {
        _ = symbols.napi_throw_error(env, "0", "FAILED_TO_DEFINE_FUNCTIONS");
    }

    return exports;
}
