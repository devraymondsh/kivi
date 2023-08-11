const { ok } = require("assert");

const addon = require("../zig-out/lib/addon.node");

const buf = new ArrayBuffer(120);

ok(addon.CollectionInit(buf) === 0);

console.log(addon.CollectionGet(buf, "foo"));

ok(addon.CollectionSet(buf, "foo", "bar") == 0);

console.log(addon.CollectionGet(buf, "foo"));
