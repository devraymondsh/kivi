const std = @import("std");
const builtin = @import("builtin");
pub const c = @import("napi-bindings.zig");

pub var napi_create_string_utf8: *const @TypeOf(c.napi_create_string_utf8) = undefined;
pub var napi_create_uint32: *const @TypeOf(c.napi_create_uint32) = undefined;
pub var napi_define_properties: *const @TypeOf(c.napi_define_properties) = undefined;
pub var napi_get_arraybuffer_info: *const @TypeOf(c.napi_get_arraybuffer_info) = undefined;
pub var napi_get_buffer_info: *const @TypeOf(c.napi_get_buffer_info) = undefined;
pub var napi_get_cb_info: *const @TypeOf(c.napi_get_cb_info) = undefined;
pub var napi_get_null: *const @TypeOf(c.napi_get_null) = undefined;
pub var napi_get_undefined: *const @TypeOf(c.napi_get_undefined) = undefined;
pub var napi_get_value_string_utf8: *const @TypeOf(c.napi_get_value_string_utf8) = undefined;
pub var napi_throw_error: *const @TypeOf(c.napi_throw_error) = undefined;

const kernel32 = std.os.windows.kernel32;
const is_windows = builtin.target.os.tag == .windows;
var windows_handle: ?std.os.windows.HMODULE = null;
fn load_sym(comptime T: type, name: []const u8) T {
    return @ptrCast(@alignCast(kernel32.GetProcAddress(windows_handle.?, name.ptr).?));
}

pub fn init_symbols() void {
    if (is_windows) {
        windows_handle = kernel32.GetModuleHandleW(null);
        if (windows_handle == null) {
            std.debug.panic("Failed to get the module handle!", .{});
        }

        napi_create_string_utf8 = load_sym(*const @TypeOf(c.napi_create_string_utf8), "napi_create_string_utf8");
        napi_create_uint32 = load_sym(*const @TypeOf(c.napi_create_uint32), "napi_create_uint32");
        napi_define_properties = load_sym(*const @TypeOf(c.napi_define_properties), "napi_define_properties");
        napi_get_arraybuffer_info = load_sym(*const @TypeOf(c.napi_get_arraybuffer_info), "napi_get_arraybuffer_info");
        napi_get_buffer_info = load_sym(*const @TypeOf(c.napi_get_buffer_info), "napi_get_buffer_info");
        napi_get_cb_info = load_sym(*const @TypeOf(c.napi_get_cb_info), "napi_get_cb_info");
        napi_get_null = load_sym(*const @TypeOf(c.napi_get_null), "napi_get_null");
        napi_get_undefined = load_sym(*const @TypeOf(c.napi_get_undefined), "napi_get_undefined");
        napi_get_value_string_utf8 = load_sym(*const @TypeOf(c.napi_get_value_string_utf8), "napi_get_value_string_utf8");
        napi_throw_error = load_sym(*const @TypeOf(c.napi_throw_error), "napi_throw_error");
    } else {
        napi_create_string_utf8 = c.napi_create_string_utf8;
        napi_create_uint32 = c.napi_create_uint32;
        napi_define_properties = c.napi_define_properties;
        napi_get_arraybuffer_info = c.napi_get_arraybuffer_info;
        napi_get_buffer_info = c.napi_get_buffer_info;
        napi_get_cb_info = c.napi_get_cb_info;
        napi_get_null = c.napi_get_null;
        napi_get_undefined = c.napi_get_undefined;
        napi_get_value_string_utf8 = c.napi_get_value_string_utf8;
        napi_throw_error = c.napi_throw_error;
    }
}
