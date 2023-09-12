const std = @import("std");
const Kivi = @import("Kivi");
const symbols = @import("symbols.zig");
const ntypes = @cImport({
    @cInclude("node_api.h");
});

const DEFAULT_BUF_SIZE: comptime_int = 4096;

fn get_args(env: ntypes.napi_env, info: ntypes.napi_callback_info, arg_count: [*c]usize, args: [*c]ntypes.napi_value) usize {
    var cb_status: ntypes.napi_status = symbols.napi_get_cb_info(env, info, arg_count, args, null, null);
    if (cb_status == ntypes.napi_ok) {
        return arg_count.*;
    }
    _ = symbols.napi_throw_error(env, "1", "INVALID_ARGS");

    return 0;
}
fn arg_to_kivi(env: ntypes.napi_env, arraybuffer: ntypes.napi_value) ?*Kivi {
    var length: usize = undefined;
    var ptr: ?*anyopaque = undefined;
    if (symbols.napi_get_arraybuffer_info(env, arraybuffer, &ptr, &length) == ntypes.napi_ok) {
        return @as(*Kivi, @ptrCast(@alignCast(ptr)));
    }
    return null;
}
fn string_to_buffer(env: ntypes.napi_env, arraybuffer: ntypes.napi_value, buf: []u8, bufsize: usize) usize {
    var len: usize = undefined;
    if (symbols.napi_get_value_string_utf8(env, arraybuffer, buf.ptr, bufsize, &len) == ntypes.napi_ok) {
        return len;
    }
    return 0;
}
fn buffer_to_string(env: ntypes.napi_env, buf: []u8, bufsize: usize) ntypes.napi_value {
    var string: ntypes.napi_value = undefined;
    if (symbols.napi_create_string_utf8(env, buf.ptr, bufsize, &string) == ntypes.napi_ok) {
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

pub export fn kivi_init_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    var args_count: usize = 1;
    var args: [1]ntypes.napi_value = undefined;
    var argc: usize = get_args(env, info, &args_count, &args);
    if (argc == 0) return new_undefined(env);

    var kivi_result: usize = arg_to_kivi(env, args[0]).?.init_default_allocator(&Kivi.Config{}) catch 0;
    if (kivi_result == @sizeOf(Kivi)) {
        return new_unint(env, @intCast(kivi_result));
    }
    return new_null(env);
}
pub export fn kivi_deinit_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    var args_count: usize = 1;
    var args: [1]ntypes.napi_value = undefined;
    var argc: usize = get_args(env, info, &args_count, &args);
    if (argc == 0) return new_undefined(env);

    arg_to_kivi(env, args[0]).?.deinit();

    return new_undefined(env);
}
pub export fn kivi_get_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    var args_count: usize = 2;
    var args: [2]ntypes.napi_value = undefined;
    var argc: usize = get_args(env, info, &args_count, &args);
    if (argc == 0) return new_undefined(env);

    var key_buf: [DEFAULT_BUF_SIZE]u8 = undefined;
    var key_len: usize = string_to_buffer(env, args[1], &key_buf, DEFAULT_BUF_SIZE);
    if (key_len == 0) {
        return new_null(env);
    }

    var value_buf: [DEFAULT_BUF_SIZE]u8 = undefined;
    var value_len: usize = arg_to_kivi(env, args[0]).?.get(key_buf[0..key_len], &value_buf) catch 0;
    if (value_len == 0) {
        return new_null(env);
    }

    return buffer_to_string(env, &value_buf, value_len);
}
pub export fn kivi_set_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    var args_count: usize = 3;
    var args: [3]ntypes.napi_value = undefined;
    var argc: usize = get_args(env, info, &args_count, &args);
    if (argc == 0) return new_undefined(env);

    var key_buf: [DEFAULT_BUF_SIZE]u8 = undefined;
    var key_len: usize = string_to_buffer(env, args[1], &key_buf, DEFAULT_BUF_SIZE);
    if (key_len == 0) {
        return new_unint(env, 0);
    }

    var value_buf: [DEFAULT_BUF_SIZE]u8 = undefined;
    var value_len: usize = string_to_buffer(env, args[2], &value_buf, DEFAULT_BUF_SIZE);

    var kivi_result: usize = arg_to_kivi(env, args[0]).?.set(key_buf[0..key_len], value_buf[0..value_len]) catch 0;

    return new_unint(env, @intCast(kivi_result));
}
pub export fn kivi_del_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    var args_count: usize = 2;
    var args: [2]ntypes.napi_value = undefined;
    var argc: usize = get_args(env, info, &args_count, &args);
    if (argc == 0) return new_undefined(env);

    var key_buf: [DEFAULT_BUF_SIZE]u8 = undefined;
    var key_len: usize = string_to_buffer(env, args[1], &key_buf, DEFAULT_BUF_SIZE);
    if (key_len == 0) {
        return new_null(env);
    }

    var value_buf: [DEFAULT_BUF_SIZE]u8 = undefined;
    var value_len: usize = arg_to_kivi(env, args[0]).?.del(key_buf[0..key_len], &value_buf) catch 0;
    if (value_len == 0) {
        return new_null(env);
    }

    return buffer_to_string(env, &value_buf, value_len);
}

pub export fn node_api_module_get_api_version_v1() i32 {
    return 6;
}
const Function = struct {
    name: [*c]const u8,
    method: ?*const fn (?*ntypes.struct_napi_env__, ?*ntypes.struct_napi_callback_info__) callconv(.C) ?*ntypes.struct_napi_value__,
};
const functions = [5]Function{ Function{
    .name = "kivi_init",
    .method = &kivi_init_js,
}, Function{
    .name = "kivi_get",
    .method = &kivi_get_js,
}, Function{
    .name = "kivi_set",
    .method = &kivi_set_js,
}, Function{
    .name = "kivi_del",
    .method = &kivi_del_js,
}, Function{
    .name = "kivi_deinit",
    .method = &kivi_deinit_js,
} };
pub export fn napi_register_module_v1(env: ntypes.napi_env, exports: ntypes.napi_value) ntypes.napi_value {
    symbols.init_symbols();

    var bindings: [5]ntypes.napi_property_descriptor = undefined;
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

    const define_properties_status = symbols.napi_define_properties(env, exports, 5, &bindings);
    if (define_properties_status != ntypes.napi_ok) {
        _ = symbols.napi_throw_error(env, "0", "FAILED_TO_DEFINE_FUNCTIONS");
    }

    return exports;
}
