#include <napi.h>
#include "../../../core/src/headers/bindings.h"

Napi::Value MakePtrJs(const Napi::CallbackInfo &info)
{
  Napi::Env env = info.Env();

  return *info[0].As<Napi::External<Napi::Value *>>().Data();
}

Napi::Number CollectionInitJs(const Napi::CallbackInfo &info)
{
  Napi::Env env = info.Env();

  enum CollectionInitStatus res = CollectionInit(info[0].As<CollectionOpaque *>());

  return Napi::Number::New(env, res);
}
void CollectionDeinitJs(const Napi::CallbackInfo &info)
{
  Napi::Env env = info.Env();

  CollectionDeinit(info[0].As<CollectionOpaque *>());
}

void CollectionGetJs(const Napi::CallbackInfo &info)
{
  Napi::Env env = info.Env();

  CollectionGet(
      info[0].As<CollectionOpaque *>(), info[1].As<Str *>(), info[2].As<char const *const>(),
      info[3].As<size_t>());
}
Napi::Boolean CollectionSetJs(const Napi::CallbackInfo &info)
{
  Napi::Env env = info.Env();

  bool res = CollectionSet(
      info[0].As<CollectionOpaque *>(), info[1].As<char const *const>(), info[2].As<size_t>(),
      info[3].As<char const *const>(), info[4].As<size_t>());

  return Napi::Boolean::New(env, res);
}
void CollectionRmJs(const Napi::CallbackInfo &info)
{
  Napi::Env env = info.Env();

  CollectionRm(info[0].As<CollectionOpaque *>(), info[1].As<char const *const>(), info[2].As<size_t>());
}

Napi::Object Init(Napi::Env env, Napi::Object exports)
{
  exports.Set(Napi::String::New(env, "CollectionInit"), Napi::Function::New(env, CollectionInitJs));
  exports.Set(Napi::String::New(env, "CollectionDeinit"), Napi::Function::New(env, CollectionDeinitJs));
  exports.Set(Napi::String::New(env, "CollectionGet"), Napi::Function::New(env, CollectionGetJs));
  exports.Set(Napi::String::New(env, "CollectionSet"), Napi::Function::New(env, CollectionSetJs));
  exports.Set(Napi::String::New(env, "CollectionRm"), Napi::Function::New(env, CollectionRmJs));
  exports.Set(Napi::String::New(env, "makePtr"), Napi::Function::New(env, MakePtrJs));

  return exports;
}

NODE_API_MODULE(kiviNodejs, Init)