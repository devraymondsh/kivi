const Kivi = @import("Kivi");
const common = @import("common.zig");
const ntypes = @import("../napi-bindings.zig");

pub export fn kivi_get_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    const args = common.parse_args(env, info, 2) catch {
        return common.exception_ret(env, "Invalid Arguments!");
    };

    const self = common.get_kivi(env, args[0]) catch {
        return common.exception_ret(env, "Invalid Kivi instance!");
    };
    const key = common.get_buffer_string(env, args[1]) catch {
        return common.exception_ret(env, "Invalid/empty key buffer!");
    };
    const value = self.get(key) catch return common.get_null(env);

    return common.create_buffer_string(env, value) catch {
        return common.exception_ret(env, "Failed to create a buffer for the results!");
    };
}
