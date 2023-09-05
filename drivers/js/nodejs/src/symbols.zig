const std = @import("std");
const builtin = @import("builtin");
const c = @cImport({
    @cInclude("node_api.h");
});

const kernel32 = std.os.windows.kernel32;
const is_windows = builtin.target.os.tag == .windows;
fn load_sym(name: []const u8) type {
    return @ptrFromInt(kernel32.GetProcAddress(kernel32.GetModuleHandleW(null), name));
}

pub const napi_create_string_utf8: *const @TypeOf(c.napi_create_string_utf8) = if (is_windows) load_sym("napi_create_string_utf8") else c.napi_create_string_utf8;
pub const napi_create_uint32: *const @TypeOf(c.napi_create_uint32) = if (is_windows) load_sym("napi_create_uint32") else c.napi_create_uint32;
pub const napi_define_properties: *const @TypeOf(c.napi_define_properties) = if (is_windows) load_sym("napi_define_properties") else c.napi_define_properties;
pub const napi_get_arraybuffer_info: *const @TypeOf(c.napi_get_arraybuffer_info) = if (is_windows) load_sym("napi_get_arraybuffer_info") else c.napi_get_arraybuffer_info;
pub const napi_get_cb_info: *const @TypeOf(c.napi_get_cb_info) = if (is_windows) load_sym("napi_get_cb_info") else c.napi_get_cb_info;
pub const napi_get_null: *const @TypeOf(c.napi_get_null) = if (is_windows) load_sym("napi_get_null") else c.napi_get_null;
pub const napi_get_undefined: *const @TypeOf(c.napi_get_undefined) = if (is_windows) load_sym("napi_get_undefined") else c.napi_get_undefined;
pub const napi_get_value_string_utf8: *const @TypeOf(c.napi_get_value_string_utf8) = if (is_windows) load_sym("napi_get_value_string_utf8") else c.napi_get_value_string_utf8;
pub const napi_throw_error: *const @TypeOf(c.napi_throw_error) = if (is_windows) load_sym("napi_throw_error") else c.napi_throw_error;
