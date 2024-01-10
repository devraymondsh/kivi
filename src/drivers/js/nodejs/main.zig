const std = @import("std");
const Kivi = @import("Kivi");
const ntypes = @import("napi-bindings.zig");
const symbols = @import("symbols.zig");

const common = @import("functions/common.zig");
pub const set = @import("functions/set.zig");
pub const get = @import("functions/get.zig");
pub const del = @import("functions/del.zig");
pub const rm = @import("functions/rm.zig");

pub export fn kivi_init_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    const args = common.parse_args(env, info, 1) catch {
        return common.exception_ret(env, "Invalid Arguments!");
    };

    const self = common.get_kivi(env, args[0]) catch {
        return common.exception_ret(env, "Invalid Kivi instance!");
    };
    _ = self.init(&Kivi.Config{}) catch {
        return common.exception_ret(env, "Failed to initialize a Kivi instance!");
    };

    return common.get_undefined(env);
}
pub export fn kivi_deinit_js(env: ntypes.napi_env, info: ntypes.napi_callback_info) ntypes.napi_value {
    const args = common.parse_args(env, info, 1) catch {
        return common.exception_ret(env, "Invalid Arguments!");
    };

    const self = common.get_kivi(env, args[0]) catch {
        return common.exception_ret(env, "Invalid Kivi instance!");
    };
    self.deinit();

    return common.get_undefined(env);
}

const Function = struct {
    name: [*c]const u8,
    method: ?*const fn (?*ntypes.struct_napi_env__, ?*ntypes.struct_napi_callback_info__) callconv(.C) ?*ntypes.struct_napi_value__,
};
const functions = [_]Function{ Function{
    .name = "kivi_init",
    .method = &kivi_init_js,
}, Function{
    .name = "kivi_get",
    .method = &get.kivi_get_js,
}, Function{
    .name = "kivi_set",
    .method = &set.kivi_set_js,
}, Function{
    .name = "kivi_del",
    .method = &del.kivi_del_js,
}, Function{
    .name = "kivi_rm",
    .method = &rm.kivi_rm_js,
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

pub export fn node_api_module_get_api_version_v1() i32 {
    return 6;
}
