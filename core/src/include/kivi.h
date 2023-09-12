#pragma once
#include <stddef.h>

struct __attribute__((aligned(8))) Kivi {
  char __opaque[128];
};

struct Config {
  size_t maximum_elments;
  size_t keys_mem_size;
  size_t keys_page_size;
  size_t values_mem_size;
  size_t values_page_size;
};

// TODO: Behavior documented in these comments
void dump_stack_trace();
// TODO: Behavior documented in these comments
void setup_debug_handlers();
// TODO: Behavior documented in these comments
size_t kivi_init(struct Kivi *const, const struct Config *const config);
// TODO: Behavior documented in these comments
void kivi_deinit(struct Kivi *const);
// TODO: Behavior documented in these comments
size_t kivi_get(const struct Kivi *const, const char *const key, const size_t key_len, char *const val, const size_t val_len);
// TODO: Behavior documented in these comments
size_t kivi_set(struct Kivi *const, const char *const key, const size_t key_len, const char *const val, const size_t val_len);
// TODO: Behavior documented in these comments
size_t kivi_del(struct Kivi *const, const char *const key, const size_t key_len, char *const val, const size_t val_len);
