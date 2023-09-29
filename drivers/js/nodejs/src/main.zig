const std = @import("std");
const Kivi = @import("Kivi");
const symbols = @import("symbols.zig");
const ntypes = @import("napi-bindings.zig");

const KEYS_DEFAULT_BUF_SIZE: comptime_int = 500 * 1024;
var GPA = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = GPA.allocator();

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
fn string_to_buffer(env: ntypes.napi_env, arraybuffer: ntypes.napi_value, buf: []u8) usize {
    var len: usize = undefined;
    if (symbols.napi_get_value_string_utf8(env, arraybuffer, buf.ptr, buf.len + 1, &len) == ntypes.napi_ok) {
        return len + 1;
    }
    return 0;
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
    var length = get_string_length(env, napi_buffer);

    if (length > KEYS_DEFAULT_BUF_SIZE) {
        var key_buf = allocator.alloc(u8, length) catch return error.Failed;
        should_be_freed.* = true;

        const written_len = string_to_buffer(env, napi_buffer, key_buf);
        if (written_len == 0) {
            return error.Failed;
        }

        return key_buf;
    } else if (length == 0) {
        return error.Failed;
    }

    _ = string_to_buffer(env, napi_buffer, &temp_buf);

    return temp_buf[0..length];
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

    var self = arg_to_kivi(env, args[0]).?;

    var should_be_freed = false;
    const key = allocate_temp_key(env, args[1], &should_be_freed) catch return new_null(env);
    defer {
        if (should_be_freed) {
            allocator.free(key);
        }
    }

    var value = self.get_slice(key) catch return new_null(env);
    if (value.len == 0) {
        return new_null(env);
    }

    return buffer_to_string(env, value);
}
pub export fn kivi_set_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    var args_count: usize = 3;
    var args: [3]ntypes.napi_value = undefined;
    var argc: usize = get_args(env, info, &args_count, &args);
    if (argc == 0) return new_undefined(env);

    var self = arg_to_kivi(env, args[0]).?;

    var key_len: usize = get_string_length(env, args[1]);
    if (key_len == 0) {
        return new_unint(env, 0);
    }
    var key_buf = self.reserve_key(key_len) catch return new_unint(env, 0);
    const written_key_len = string_to_buffer(env, args[1], key_buf);
    if (written_key_len == 0) {
        return new_unint(env, 0);
    }

    var value_len: usize = get_string_length(env, args[2]);
    if (value_len == 0) {
        return new_unint(env, 0);
    }
    var value_buf = self.reserve(key_buf, value_len) catch {
        self.undo_reserve(key_buf);
        return new_unint(env, 0);
    };
    const written_value_len = string_to_buffer(env, args[2], value_buf);
    if (written_value_len == 0) {
        return new_unint(env, 0);
    }

    return new_unint(env, @intCast(value_len));
}
pub export fn kivi_del_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    var args_count: usize = 2;
    var args: [2]ntypes.napi_value = undefined;
    var argc: usize = get_args(env, info, &args_count, &args);
    if (argc == 0) return new_undefined(env);

    var self = arg_to_kivi(env, args[0]).?;

    var should_be_freed = false;
    const key = allocate_temp_key(env, args[1], &should_be_freed) catch return new_null(env);
    defer {
        if (should_be_freed) {
            allocator.free(key);
        }
    }

    var value = self.del_slice(key) catch return new_null(env);
    if (value.len == 0) {
        return new_null(env);
    }
    const string = buffer_to_string(env, value);

    self.del_value(value);

    return string;
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
