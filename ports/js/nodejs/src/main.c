#include <stdio.h>
#include <assert.h>
#include <node_api.h>
#include "../../../../core/src/headers/bindings.h"

#define NEW_FUNCTION(name, func) \
  {name, NULL, func, NULL, NULL, NULL, napi_enumerable, NULL}
#define GET_CB_INFO(arg_count) \
  size_t argc = arg_count; \
  napi_value args[arg_count]; \
  napi_status cb_status = napi_get_cb_info(env, info, &argc, args, NULL, NULL); \
  assert(cb_status == napi_ok);

napi_value CollectionInitJs(napi_env env, napi_callback_info info) {
  GET_CB_INFO(1);

  void *ptr;
  size_t length = sizeof(struct CollectionOpaque);
  napi_get_arraybuffer_info(env, args[0], &ptr, &length);

  enum CollectionInitStatus status = CollectionInit((struct CollectionOpaque *)ptr);

  napi_value result;
  napi_create_uint32(env, (uint32_t)status, &result);

  return result;
}
napi_value CollectionDeinitJs(napi_env env, napi_callback_info info) {
  GET_CB_INFO(1);

  CollectionDeinit((struct CollectionOpaque *)args[0]);
}

napi_value CollectionGetJs(napi_env env, napi_callback_info info) {
  GET_CB_INFO(4);

  CollectionGet(
    (struct CollectionOpaque *)args[0], (struct Str *)args[1], 
    (char const *const)args[2], (size_t const)args[3]
  );
}
napi_value CollectionSetJs(napi_env env, napi_callback_info info) {
  GET_CB_INFO(5);

  bool status = CollectionSet(
    (struct CollectionOpaque *)args[0], (char const *const)args[1], (size_t const)args[2],
    (char const *const)args[3], (size_t const)args[4]
  );

  napi_value result;
  napi_create_uint32(env, (uint32_t)status, &result);

  return result;
}
napi_value CollectionRmJs(napi_env env, napi_callback_info info) {
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
