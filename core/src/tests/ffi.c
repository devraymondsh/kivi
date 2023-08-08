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

    CollectionRm(&collection, "foo", 4);
    struct Str s2 = CollectionGetOut(&collection, "foo", 4);
    assert(s2.ptr == NULL);

    CollectionDeinit(&collection_res.collection_opq);
}
void test_non_out_functions(void) {
    setup_debug_handlers();

    struct CollectionOpaque collection;
    enum CollectionInitStatus collection_res = CollectionInit(&collection);
    assert(collection_res == 0);

    bool collection_set_res = CollectionSet(&collection, "foo", 4, "bar", 5);
    assert(collection_set_res == 0);

    struct Str s1;
    CollectionGet(&collection, &s1, "foo", 4);
    assert(strcmp(s1.ptr, "bar") == 0);

    CollectionRm(&collection, "foo", 4);

    struct Str s2;
    CollectionGet(&collection, &s2, "foo", 4);
    assert(s2.ptr == NULL);

    CollectionDeinit(&collection);
}

int main(void) {
    setup_debug_handlers();

    test_out_functions();
    test_non_out_functions();
}
