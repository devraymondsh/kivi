import { Kivi } from "../index.js";

const run = (config) => {
  const assert = (name, left, right) => {
    if (JSON.stringify(left) !== JSON.stringify(right)) {
      console.error("Left:", left);
      console.error("Right:", right);
      throw new Error(`Assertion '${name}' failed!`);
    }
  };

  const c = new Kivi(config);

  assert("Null-if-uninitialized", c.get("foo"), null);
  c.set("foo", "bar");
  assert("Assert-after-set", c.get("foo"), "bar");
  assert("Value-when-delete", c.fetchDel("foo"), "bar");
  assert("Value-after-delete", c.get("foo"), null);

  assert(
    "Value-set-with-bulk",
    c.bulkSet([
      { key: "foo1", value: "bar1" },
      { key: "foo2", value: "bar2" },
      { key: "foo3", value: "bar3" },
    ]),
    [true, true, true]
  );
  assert("Value-get-with-bulk", c.bulkGet(["foo", "foo1", "foo2", "foo3"]), [
    null,
    "bar1",
    "bar2",
    "bar3",
  ]);
  assert("Value-with-bulk", c.bulkFetchDel(["foo", "foo1", "foo2", "foo3"]), [
    null,
    "bar1",
    "bar2",
    "bar3",
  ]);
  assert("Value-get-with-bulk", c.bulkGet(["foo", "foo1", "foo2", "foo3"]), [
    null,
    null,
    null,
    null,
  ]);

  c.destroy();
};

run({ forceUseRuntimeFFI: false });
run({ forceUseRuntimeFFI: true });
