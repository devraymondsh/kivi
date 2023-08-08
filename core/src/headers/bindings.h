#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

struct Str {
  const char *ptr;
  size_t len;
};

enum CollectionInitError { Ok, MmapFailure, AllocatorSetupFailure };
enum CollectionSetResult { Success, MProtectAccessDenied, MProtectOutOfMemory, MProtectUnexpectedError, MmapPositionsOutOfMemory };

struct __attribute__((aligned(8))) CollectionOpaque {
  char __opaque[144];
};
struct CollectionInitResult {
  enum CollectionInitError err;
  struct CollectionOpaque collection_opq;
};

struct CollectionInitResult CollectionInit(void);
struct Str CollectionGet(struct CollectionOpaque *const map,
                         char const *const key, uintptr_t const key_len);

enum CollectionSetResult CollectionSet(struct CollectionOpaque *const map, char const *const key,
                   uintptr_t const key_len, char const *const value,
                   uintptr_t const value_len);
void CollectionRm(struct CollectionOpaque *const map, char const *const key,
                  uintptr_t const key_len);
void CollectionDeinit(struct CollectionOpaque *const map);

void setup_debug_handlers(void);
void dump_stack_trace(void);
