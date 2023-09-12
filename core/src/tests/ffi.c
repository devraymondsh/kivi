#include <assert.h>
#include <kivi.h>
#include <stdio.h>
#include <string.h>

int main(void) {
  setup_debug_handlers();

  struct Kivi kv;
  char v[4096];

  const struct Config *config = NULL;

  assert(kivi_init(&kv, config) == sizeof(struct Kivi));

  assert(kivi_get(&kv, "foo", 3, NULL, 0) == 0);

  assert(kivi_set(&kv, "foo", 3, "bar", 3) == 3);

  assert(kivi_get(&kv, "foo", 3, v, 4096) == 3);
  assert(v[0] == 'b');
  assert(v[1] == 'a');
  assert(v[2] == 'r');

  assert(kivi_del(&kv, "foo", 3, v, 4096) == 3);

  assert(kivi_get(&kv, "foo", 3, NULL, 0) == 0);

  kivi_deinit(&kv);
}
