// zig run test.c -L. -lmain

#include <stdio.h>
#include <assert.h>
#include <string.h>
#include "../headers/bindings.h"

int main(void) {
    struct Map_opaque map = Map_init();

    Map_set(&map, "foo", 4, "bar", 5);
    struct Str s1 = Map_get(&map, "foo", 4);

    assert(strcmp(s1.ptr, "bar") == 0);

    Map_rm(&map, "foo", 4);
    struct Str s2 = Map_get(&map, "foo", 4);

    assert(s2.ptr == NULL);

    Map_deinit(&map);
}
/*
mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7fdb20df5000
mmap(0x7fdb20df6000, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7fdb20df4000
mmap(0x7fdb20df5000, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7fdb20df3000
*/