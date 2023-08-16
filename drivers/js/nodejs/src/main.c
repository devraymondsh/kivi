#include <assert.h>
#include <kivi.h>
#include <node_api.h>
#include <stdio.h>

#define DEFAULT_BUF_SIZE 4096

size_t get_args(napi_env env, napi_callback_info info, size_t arg_count,
                napi_value args[]) {
  napi_status cb_status =
      napi_get_cb_info(env, info, &arg_count, args, NULL, NULL);

  if (cb_status == napi_ok) {
    return arg_count;
  }

  napi_throw_error(env, "1", "INVALID_ARGS");
  return 0;
}
struct Kivi *arg_to_kivi(napi_env env, napi_value arraybuffer) {
  void *ptr;
  size_t length;

  return napi_get_arraybuffer_info(env, arraybuffer, &ptr, &length) == napi_ok
             ? (struct Kivi *)ptr
             : NULL;
}
size_t string_to_buffer(napi_env env, napi_value arraybuffer, char *buf,
                        size_t bufsize) {
  size_t len;
  return napi_get_value_string_utf8(env, arraybuffer, buf, DEFAULT_BUF_SIZE,
                                    &len) == napi_ok
             ? len
             : 0;
}
napi_value buffer_to_string(napi_env env, char *buf, size_t bufsize) {
  napi_value string;
  return napi_create_string_utf8(env, buf, bufsize, &string) == napi_ok ? string
                                                                        : NULL;
}
napi_value new_unint(napi_env env, uint32_t value) {
  napi_value result;
  return napi_create_uint32(env, value, &result) == napi_ok ? result : NULL;
}
napi_value new_null(napi_env env) {
  napi_value null_value;
  return napi_get_null(env, &null_value) == napi_ok ? null_value : NULL;
}
napi_value new_undefined(napi_env env) {
  napi_value undefined_value;
  return napi_get_undefined(env, &undefined_value) == napi_ok ? undefined_value
                                                              : NULL;
}

napi_value kivi_init_js(napi_env env, napi_callback_info info) {
  napi_value args[1];
  size_t argc = get_args(env, info, 1, args);
  if (argc == 0)
    return new_undefined(env);

  size_t kivi_result = kivi_init(arg_to_kivi(env, args[0]), NULL);
  if (kivi_result == sizeof(struct Kivi)) {
    return new_unint(env, kivi_result);
  }

  return new_null(env);
}
napi_value kivi_deinit_js(napi_env env, napi_callback_info info) {
  napi_value args[1];
  size_t argc = get_args(env, info, 1, args);
  if (argc == 0)
    return new_undefined(env);

  kivi_deinit(arg_to_kivi(env, args[0]));

  return new_null(env);
}

napi_value kivi_get_js(napi_env env, napi_callback_info info) {
  napi_value args[2];
  size_t argc = get_args(env, info, 2, args);
  if (argc == 0)
    return new_undefined(env);

  char key_buf[DEFAULT_BUF_SIZE];
  size_t key_len = string_to_buffer(env, args[1], &key_buf, DEFAULT_BUF_SIZE);

  char value_buf[DEFAULT_BUF_SIZE];
  size_t kivi_result = kivi_get(arg_to_kivi(env, args[0]), key_buf, key_len,
                                value_buf, DEFAULT_BUF_SIZE);

  if (kivi_result == 0) {
    return new_null(env);
  }

  return buffer_to_string(env, value_buf, kivi_result);
}

napi_value kivi_set_js(napi_env env, napi_callback_info info) {
  napi_value args[3];
  size_t argc = get_args(env, info, 3, args);
  if (argc == 0)
    return new_undefined(env);

  char key_buf[DEFAULT_BUF_SIZE];
  size_t key_len = string_to_buffer(env, args[1], &key_buf, DEFAULT_BUF_SIZE);

  char value_buf[DEFAULT_BUF_SIZE];
  size_t value_len =
      string_to_buffer(env, args[2], &value_buf, DEFAULT_BUF_SIZE);

  size_t kivi_result = kivi_set(arg_to_kivi(env, args[0]), key_buf, key_len,
                                value_buf, value_len);

  return new_unint(env, kivi_result);
}
napi_value kivi_del_js(napi_env env, napi_callback_info info) {
  napi_value args[2];
  size_t argc = get_args(env, info, 2, args);
  if (argc == 0)
    return new_undefined(env);

  char key_buf[DEFAULT_BUF_SIZE];
  size_t key_len = string_to_buffer(env, args[1], &key_buf, DEFAULT_BUF_SIZE);

  char value_buf[DEFAULT_BUF_SIZE];
  size_t kivi_result = kivi_del(arg_to_kivi(env, args[0]), key_buf, key_len,
                                value_buf, DEFAULT_BUF_SIZE);

  if (kivi_result == 0) {
    return new_null(env);
  }

  return buffer_to_string(env, value_buf, kivi_result);
}

#define NEW_FUNCTION(name, func)                                               \
  { name, NULL, func, NULL, NULL, NULL, napi_enumerable, NULL }
static napi_value Init(napi_env env, napi_value exports) {
  napi_property_descriptor bindings[] = {
      NEW_FUNCTION("kivi_init", kivi_init_js),
      NEW_FUNCTION("kivi_get", kivi_get_js),
      NEW_FUNCTION("kivi_set", kivi_set_js),
      NEW_FUNCTION("kivi_del", kivi_del_js),
      NEW_FUNCTION("kivi_deinit", kivi_deinit_js)};

  napi_define_properties(env, exports, sizeof(bindings) / sizeof(bindings[0]),
                         bindings);

  return exports;
}
NAPI_MODULE(BINDINGS, Init)
