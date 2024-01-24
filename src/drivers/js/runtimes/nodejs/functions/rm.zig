const Kivi = @import("Kivi");
const common = @import("common.zig");
const ntypes = @import("../napi-bindings.zig");

pub export fn kivi_rm_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    const args = common.parse_args(env, info, 2) catch {
        return common.exception_ret(env, "Invalid Arguments!");
    };

    const self = common.get_kivi(env, args[0]) catch {
        return common.exception_ret(env, "Invalid Kivi instance!");
    };
    const key = common.get_buffer_string(env, args[1]) catch {
        return common.exception_ret(env, "Invalid/empty key buffer!");
    };
    self.rm(key) catch {};

    return common.get_undefined(env);
}
