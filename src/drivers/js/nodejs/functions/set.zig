const Kivi = @import("Kivi");
const common = @import("common.zig");
const ntypes = @import("../napi-bindings.zig");
const symbols = @import("../symbols.zig");

pub export fn kivi_set_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    const args = common.parse_args(env, info, 3) catch {
        return common.exception_ret(env, "Invalid Arguments!");
    };

    const self = common.get_kivi(env, args[0]) catch {
        return common.exception_ret(env, "Invalid Kivi instance!");
    };
    const key = common.get_buffer_string(env, args[1]) catch {
        return common.exception_ret(env, "Invalid/empty key buffer!");
    };
    const value = common.get_buffer_string(env, args[2]) catch {
        return common.exception_ret(env, "Invalid/empty value buffer!");
    };
    const reserved_key = self.reserve_key(key.len) catch {
        return common.exception_ret(env, "Not enough memory to store the key!");
    };
    const reserved_value = self.reserve_value(value.len) catch {
        self.mem_allocator.free(reserved_key);
        return common.exception_ret(env, "Not enough memory to store the value!");
    };
    @memcpy(reserved_key, key);
    @memcpy(reserved_value, value);
    self.putEntry(reserved_key, reserved_value) catch {
        self.mem_allocator.free(reserved_key);
        self.mem_allocator.free(reserved_value);
        return common.exception_ret(env, "Not enough memory to fit the new key/value pair!");
    };

    return common.get_undefined(env);
}
