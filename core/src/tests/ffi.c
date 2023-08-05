#include <stdio.h>
#include <assert.h>
#include <string.h>
#include "../headers/bindings.h"

int main(void) {
    dump_stack_trace();
    setup_debug_handlers();

    struct CollectionInitResult collection_res = CollectionInit();

    assert(collection_res.err == 0);

    struct CollectionOpaque collection = collection_res.collection_opq;

    // Collection_set(collection, "foo", 4, "bar", 5);
    // struct Str s1 = Collection_get(collection, "foo", 4);

    // assert(strcmp(s1.ptr, "bar") == 0);

    // Collection_rm(collection, "foo", 4);
    // struct Str s2 = Collection_get(collection, "foo", 4);

    // assert(s2.ptr == NULL);

    // CollectionDeinit(&collection);
}