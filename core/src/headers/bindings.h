#pragma once

#include <stdbool.h>
#include <stddef.h>

struct Config
{
  size_t keys_mmap_size;
  size_t mmap_page_size;
  size_t values_mmap_size;
};
struct Str
{
  const char *ptr;
  size_t len;
};
struct __attribute__((aligned(8))) CollectionOpaque
{
  char __opaque[120];
};
struct CollectionInitResult
{
  bool err;
  struct CollectionOpaque collection_opq;
};

void CollectionDeinit(struct CollectionOpaque *const map);
struct CollectionInitResult CollectionInitOut(void);
struct CollectionInitResult CollectionInitWithConfigOut(struct Config config);
bool CollectionInit(struct CollectionOpaque *collection_opaque);
bool CollectionInitWithConfig(struct Config config, struct CollectionOpaque *collection_opaque);

struct Str CollectionGetOut(struct CollectionOpaque *const map, char const *const key, size_t const key_len);
void CollectionGet(struct CollectionOpaque *const map, struct Str *str, char const *const key, size_t const key_len);
struct Str CollectionRmOut(struct CollectionOpaque *const map, char const *const key, size_t const key_len);
void CollectionRm(struct CollectionOpaque *const map, struct Str *str, char const *const key, size_t const key_len);

// Zero means ok, so that means we return false(0) on success and return true(1) on failure
bool CollectionSet(struct CollectionOpaque *const map, char const *const key,
                   size_t const key_len, char const *const value,
                   size_t const value_len);

void setup_debug_handlers(void);
void dump_stack_trace(void);

struct __attribute__((aligned(8))) Kivi {
  char __opaque[120];
};

// TODO: Behavior documented in these comments
size_t kivi_init(const struct Kivi *const);
// TODO: Behavior documented in these comments
void kivi_deinit(const struct Kivi *const);
// TODO: Behavior documented in these comments
size_t kivi_get(struct Kivi *const, const char *const key, const size_t key_len, char *const val, const size_t val_len);
// TODO: Behavior documented in these comments
size_t kivi_set(const struct Kivi *const, const char *const key, const size_t key_len, const char *const val, const size_t val_len);
// TODO: Behavior documented in these comments
size_t kivi_del(const struct Kivi *const, const char *const key, const size_t key_len, char *const val, const size_t val_len);
