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
pub var napi_get_element: *const @TypeOf(c.napi_get_element) = undefined;
pub var napi_get_array_length: *const @TypeOf(c.napi_get_array_length) = undefined;
pub var napi_create_array_with_length: *const @TypeOf(c.napi_create_array_with_length) = undefined;
pub var napi_set_element: *const @TypeOf(c.napi_set_element) = undefined;
pub var napi_get_named_property: *const @TypeOf(c.napi_get_named_property) = undefined;
pub var napi_get_boolean: *const @TypeOf(c.napi_get_boolean) = undefined;
pub var napi_is_buffer: *const @TypeOf(c.napi_is_buffer) = undefined;
pub var napi_is_arraybuffer: *const @TypeOf(c.napi_is_arraybuffer) = undefined;
pub var napi_create_buffer_copy: *const @TypeOf(c.napi_create_buffer_copy) = undefined;

const std = @import("std");
const kernel32 = std.os.windows.kernel32;
var windows_handle: ?std.os.windows.HMODULE = null;
fn load_sym(comptime T: type, name: []const u8) T {
    return @ptrCast(@alignCast(kernel32.GetProcAddress(windows_handle.?, name.ptr).?));
}

pub fn init_symbols() void {
    windows_handle = kernel32.GetModuleHandleW(null);
    if (windows_handle == null) {
        // TODO: Panic
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
    napi_get_element = load_sym(*const @TypeOf(c.napi_get_element), "napi_get_element");
    napi_get_array_length = load_sym(*const @TypeOf(c.napi_get_array_length), "napi_get_array_length");
    napi_create_array_with_length = load_sym(*const @TypeOf(c.napi_create_array_with_length), "napi_create_array_with_length");
    napi_set_element = load_sym(*const @TypeOf(c.napi_set_element), "napi_set_element");
    napi_get_named_property = load_sym(*const @TypeOf(c.napi_get_named_property), "napi_get_named_property");
    napi_get_boolean = load_sym(*const @TypeOf(c.napi_get_boolean), "napi_get_boolean");
    napi_is_buffer = load_sym(*const @TypeOf(c.napi_is_buffer), "napi_is_buffer");
    napi_is_arraybuffer = load_sym(*const @TypeOf(c.napi_is_arraybuffer), "napi_is_arraybuffer");
    napi_create_buffer_copy = load_sym(*const @TypeOf(c.napi_create_buffer_copy), "napi_create_buffer_copy");
}
