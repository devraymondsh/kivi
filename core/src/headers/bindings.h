#pragma once

#include <stdbool.h>
#include <stddef.h>

enum CollectionInitStatus { Ok, Failed };

struct Config {
  size_t keys_mmap_size;
  size_t mmap_page_size;
  size_t values_mmap_size;
};
struct Str {
  const char *ptr;
  size_t len;
};
struct __attribute__((aligned(8))) CollectionOpaque {
  char __opaque[128];
};
struct CollectionInitResult {
  enum CollectionInitStatus err;
  struct CollectionOpaque collection_opq;
};

struct CollectionInitResult CollectionInitOut(void);
struct CollectionInitResult CollectionInitWithConfigOut(struct Config config);
enum CollectionInitStatus CollectionInit(struct CollectionOpaque* collection_opaque);
enum CollectionInitStatus CollectionInitWithConfig(struct Config config, struct CollectionOpaque* collection_opaque);

struct Str CollectionGetOut(struct CollectionOpaque *const map,
                         char const *const key, size_t const key_len);
void CollectionGet(struct CollectionOpaque *const map, struct Str* str,
                         char const *const key, size_t const key_len);

// Zero means ok, so that means we return false(0) on success and return true(1) on failure
bool CollectionSet(struct CollectionOpaque *const map, char const *const key,
                   size_t const key_len, char const *const value,
                   size_t const value_len);
void CollectionRm(struct CollectionOpaque *const map, char const *const key,
                  size_t const key_len);
void CollectionDeinit(struct CollectionOpaque *const map);

void setup_debug_handlers(void);
void dump_stack_trace(void);
