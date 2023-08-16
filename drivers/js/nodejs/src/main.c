#include <assert.h>
#include <kivi.h>
#include <node_api.h>
#include <stdio.h>

// Fixup instructions
// FIXME: probably broken, total rework
// TODO: fixed and tested by Thomas, need to replace asserts with
//       returning proper error code or throwing

#define NEW_FUNCTION(name, func)                                               \
  { name, NULL, func, NULL, NULL, NULL, napi_enumerable, NULL }
#define GET_CB_INFO(arg_count)                                                 \
  size_t argc = arg_count;                                                     \
  napi_value args[arg_count];                                                  \
  napi_status cb_status =                                                      \
      napi_get_cb_info(env, info, &argc, args, NULL, NULL);                    \
  assert(cb_status == napi_ok);

struct CollectionOpaque *CastCollectionOpaque(napi_env env,
                                              napi_value arraybuffer) {
  void *ptr;
  size_t length;
  return napi_get_arraybuffer_info(env, arraybuffer, &ptr, &length) == napi_ok
             ? (struct CollectionOpaque *)ptr
             : NULL;
}
size_t CastKeyOrValue(napi_env env, napi_value arraybuffer, char *buf) {
  size_t len;
  return napi_get_value_string_utf8(env, arraybuffer, buf, 4096, &len) ==
                 napi_ok
             ? len
             : 0;
}

napi_value CollectionInitJs(napi_env env, napi_callback_info info) {
  // TODO: rework
  GET_CB_INFO(1);

  bool status = CollectionInit(CastCollectionOpaque(env, args[0]));

  napi_value result;
  return napi_create_uint32(env, (uint32_t)status, &result) == napi_ok ? result
                                                                       : NULL;
}
napi_value CollectionDeinitJs(napi_env env, napi_callback_info info) {
  // FIXME: rework
  GET_CB_INFO(1);

  CollectionDeinit(CastCollectionOpaque(env, args[0]));

  napi_value result;
  return napi_create_uint32(env, 0, &result) == napi_ok ? result : NULL;
}

napi_value CollectionGetJs(napi_env env, napi_callback_info info) {
  // TODO: rework
  GET_CB_INFO(2);

  char key_buf[4096];
  size_t key_len = CastKeyOrValue(env, args[1], &key_buf);

  struct Str str;
  CollectionGet(CastCollectionOpaque(env, args[0]), &str, key_buf, key_len);

  if (str.ptr == NULL) {
    napi_value null_value = 0;
    napi_get_null(env, &null_value);
    return null_value;
  }

  napi_value str_value;
  napi_status str_result =
      napi_create_string_utf8(env, str.ptr, str.len, &str_value);
  assert(str_result == napi_ok);
  return str_value;
}

napi_value CollectionSetJs(napi_env env, napi_callback_info info) {
  // TODO: rework
  GET_CB_INFO(3);

  char key_buf[4096];
  size_t key_len = CastKeyOrValue(env, args[1], &key_buf);
  char value_buf[4096];
  size_t value_len = CastKeyOrValue(env, args[2], &value_buf);
  bool status = CollectionSet(CastCollectionOpaque(env, args[0]), key_buf,
                              key_len, value_buf, value_len);

  napi_value result;
  napi_status uint32_status =
      napi_create_uint32(env, (uint32_t)status, &result);
  assert(uint32_status == napi_ok);

  return result;
}
napi_value CollectionRmJs(napi_env env, napi_callback_info info) {
  GET_CB_INFO(2);

  char key_buf[4096];
  size_t key_len = CastKeyOrValue(env, args[1], &key_buf);

  struct Str str;
  CollectionRm(CastCollectionOpaque(env, args[0]), &str, key_buf, key_len);

  if (str.ptr == NULL) {
    napi_value null_value;
    assert(napi_get_null(env, &null_value) == napi_ok);
    return null_value;
  }

  napi_value str_value;
  assert(napi_create_string_utf8(env, str.ptr, str.len, &str_value) == napi_ok);
  return str_value;
}

static napi_value Init(napi_env env, napi_value exports) {
  napi_property_descriptor bindings[] = {
      NEW_FUNCTION("CollectionInit", CollectionInitJs),
      NEW_FUNCTION("CollectionGet", CollectionGetJs),
      NEW_FUNCTION("CollectionSet", CollectionSetJs),
      NEW_FUNCTION("CollectionRm", CollectionRmJs),
      NEW_FUNCTION("CollectionDeinit", CollectionDeinitJs)};

  napi_define_properties(env, exports, sizeof(bindings) / sizeof(bindings[0]),
                         bindings);

  return exports;
}

NAPI_MODULE(BINDINGS, Init)
