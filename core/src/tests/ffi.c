#include <stdio.h>
#include <assert.h>
#include <string.h>
#include "../headers/bindings.h"

void test_out_functions(void) {
    setup_debug_handlers();

    struct CollectionInitResult collection_res = CollectionInitOut();
    assert(collection_res.err == 0);

    struct CollectionOpaque collection = collection_res.collection_opq;

    bool collection_set_res = CollectionSet(&collection, "foo", 4, "bar", 5);
    assert(collection_set_res == 0);

    struct Str s1 = CollectionGetOut(&collection, "foo", 4);
    assert(strcmp(s1.ptr, "bar") == 0);

    struct Str s2 = CollectionRmOut(&collection, "foo", 4);
    assert(s2.ptr != NULL);

    struct Str s3 = CollectionGetOut(&collection, "foo", 4);
    assert(s3.ptr == NULL);

    CollectionDeinit(&collection_res.collection_opq);
}
void test_non_out_functions(void) {
    setup_debug_handlers();

    struct CollectionOpaque collection;
    bool collection_res = CollectionInit(&collection);
    assert(collection_res == 0);

    bool collection_set_res = CollectionSet(&collection, "foo", 4, "bar", 5);
    assert(collection_set_res == 0);

    struct Str s1;
    CollectionGet(&collection, &s1, "foo", 4);
    assert(strcmp(s1.ptr, "bar") == 0);

    struct Str s2;
    CollectionRm(&collection, &s2, "foo", 4);
    assert(s2.ptr != NULL);

    struct Str s3;
    CollectionGet(&collection, &s3, "foo", 4);
    assert(s3.ptr == NULL);

    CollectionDeinit(&collection);
}


void test_v2_functions(void) {
  struct Kivi kv;
  char v[4096];
  size_t len = 999;

  bool ok = !CollectionInit((struct CollectionOpaque *)&kv);
  assert(ok);

  len = kivi_get(&kv, "foo", 3, NULL, 0);
  assert(len == 0);

  len = kivi_set(&kv, "foo", 3, "bar", 3);
  assert(len == 3);
  len = 0;

  len = kivi_get(&kv, "foo", 3, v, 4096);
  assert(len == 3);
  assert(v[0] == 'b');
  assert(v[1] == 'a');
  assert(v[2] == 'r');
  len = 0;

  len = kivi_del(&kv, "foo", 3, v, 4096);
  assert(len == 3);

  len = kivi_get(&kv, "foo", 3, NULL, 0);
  assert(len == 0);

  CollectionDeinit((struct CollectionOpaque *)&kv);
}

int main(void) {
    setup_debug_handlers();

    test_out_functions();
    test_non_out_functions();
    test_v2_functions();
}
