#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

struct Str {
  const char *ptr;
  size_t len;
};

struct Map_opaque {
  char __opaque[96];
};

struct Map_opaque Map_init(void);
struct Str Map_get(struct Map_opaque *const map, char const *const key,
                   uintptr_t const key_len);

bool Map_set(struct Map_opaque *const map, char const *const key,
             uintptr_t const key_len, char const *const value,
             uintptr_t const value_len);
void Map_rm(struct Map_opaque *const map, char const *const key,
            uintptr_t const key_len);
void Map_deinit(struct Map_opaque *const map);
