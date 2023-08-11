#include <stdio.h>
#include <assert.h>
#include <node_api.h>
#include "../../../../core/src/headers/bindings.h"

// Fixup instructions
// FIXME: probably broken, total rework
// TODO: fixed and tested by Thomas, need to replace asserts with
//       returning proper error code or throwing

#define NEW_FUNCTION(name, func) \
  {name, NULL, func, NULL, NULL, NULL, napi_enumerable, NULL}
#define GET_CB_INFO(arg_count) \
  size_t argc = arg_count; \
  napi_value args[arg_count]; \
  napi_status cb_status = napi_get_cb_info(env, info, &argc, args, NULL, NULL); \
  assert(cb_status == napi_ok);

napi_value CollectionInitJs(napi_env env, napi_callback_info info) {
  // TODO: rework
  GET_CB_INFO(1);

  void *ptr;
  size_t length = sizeof(struct CollectionOpaque);
  assert(napi_get_arraybuffer_info(env, args[0], &ptr, &length) == napi_ok);

  enum CollectionInitStatus status = CollectionInit((struct CollectionOpaque *)ptr);

  napi_value result;
  assert(napi_create_uint32(env, (uint32_t)status, &result) == napi_ok);

  return result;
}
napi_value CollectionDeinitJs(napi_env env, napi_callback_info info) {
  // FIXME: rework
  GET_CB_INFO(1);

  CollectionDeinit((struct CollectionOpaque *)args[0]);
}

napi_value CollectionGetJs(napi_env env, napi_callback_info info) {
  // TODO: rework
  GET_CB_INFO(2);

  void *ptr;
  size_t length = sizeof(struct CollectionOpaque);
  assert(napi_get_arraybuffer_info(env, args[0], &ptr, &length) == napi_ok);

  char key_buf[4096];
  size_t key_len;
  assert(napi_get_value_string_utf8(env, args[1], key_buf, 4096,  &key_len) == napi_ok);

  struct Str s = CollectionGetOut((struct CollectionOpaque *)ptr, key_buf, key_len);

  if (s.ptr == NULL) {
    napi_value null_value;
    assert(napi_get_null(env, &null_value) == napi_ok);
    return null_value;
  }

  napi_value str_value;
  assert(napi_create_string_utf8(env, s.ptr, s.len, &str_value) == napi_ok);
  return str_value;
}


napi_value CollectionSetJs(napi_env env, napi_callback_info info) {
  // TODO: rework
  GET_CB_INFO(3);

  void *ptr;
  size_t length = sizeof(struct CollectionOpaque);
  assert(napi_get_arraybuffer_info(env, args[0], &ptr, &length) == napi_ok);

  char key_buf[4096];
  size_t key_len;
  assert(napi_get_value_string_utf8(env, args[1], key_buf, 4096,  &key_len) == napi_ok);

  char value_buf[4096];
  size_t value_len;
  assert(napi_get_value_string_utf8(env, args[2], value_buf, 4096, &value_len) == napi_ok);

  bool status = CollectionSet((struct CollectionOpaque *)ptr, key_buf, key_len, value_buf, value_len);

  napi_value result;
  assert(napi_create_uint32(env, (uint32_t)status, &result) == napi_ok);

  return result;
}
napi_value CollectionRmJs(napi_env env, napi_callback_info info) {
  // FIXME: rework
  GET_CB_INFO(3);

  CollectionRm((struct CollectionOpaque *)args[0], (char const *const)args[1], (size_t const)args[2]);
}

static napi_value Init(napi_env env, napi_value exports) {
  napi_property_descriptor bindings[] = {
    NEW_FUNCTION("CollectionInit", CollectionInitJs),
    NEW_FUNCTION("CollectionGet", CollectionGetJs),
    NEW_FUNCTION("CollectionSet", CollectionSetJs),
    NEW_FUNCTION("CollectionRm", CollectionRmJs),
    NEW_FUNCTION("CollectionDeinit", CollectionDeinitJs)
  };

  napi_define_properties(env, exports, sizeof(bindings) / sizeof(bindings[0]), bindings);

  return exports;
}

NAPI_MODULE(BINDINGS, Init)
