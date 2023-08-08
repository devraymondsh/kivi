#include <stdio.h>
#include <assert.h>
#include <string.h>
#include "../headers/bindings.h"

int main(void) {
    setup_debug_handlers();

    struct CollectionInitResult collection_res = CollectionInit();
    assert(collection_res.err == 0);

    struct CollectionOpaque collection = collection_res.collection_opq;

    enum CollectionSetResult collection_set_res = CollectionSet(&collection, "foo", 4, "bar", 5);
    assert(collection_set_res == 0);

    struct Str s1 = CollectionGet(&collection, "foo", 4);
    assert(strcmp(s1.ptr, "bar") == 0);

    CollectionRm(&collection, "foo", 4);
    struct Str s2 = CollectionGet(&collection, "foo", 4);
    assert(s2.ptr == NULL);

    CollectionDeinit(&collection_res.collection_opq);
}
