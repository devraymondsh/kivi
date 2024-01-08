import { Kivi } from "../index.js";

const run = (config) => {
  const assert = (name, left, right) => {
    if (Buffer.isBuffer(left) && Buffer.isBuffer(right)) {
      if (left.toString("utf8") == right.toString("utf8")) {
        return;
      }
    } else {
      if (left == right) {
        return;
      }
    }

    throw new Error(
      `Assertion '${name}' failed! Left was '${left}' and right was '${right}'.`
    );
  };

  const k = new Kivi(config);

  assert("Null-if-uninitialized", k.get(Buffer.from("foo", "utf8")), null);

  k.set(Buffer.from("foo", "utf8"), Buffer.from("bar", "utf8"));

  assert(
    "Assert-after-set",
    Buffer.from(k.get(Buffer.from("foo", "utf8")), "utf8"),
    Buffer.from("bar", "utf8")
  );

  assert(
    "Value-when-delete",
    k.del(Buffer.from("foo", "utf8")),
    Buffer.from("bar", "utf8")
  );

  assert("Value-after-delete", k.get(Buffer.from("foo", "utf8")), null);

  // Do it again to assert the freelist

  assert("Null-if-uninitialized", k.get(Buffer.from("foo", "utf8")), null);

  k.set(Buffer.from("foo", "utf8"), Buffer.from("bar", "utf8"));

  assert(
    "Assert-after-set",
    k.get(Buffer.from("foo", "utf8")),
    Buffer.from("bar", "utf8")
  );

  assert(
    "Value-when-delete",
    k.del(Buffer.from("foo", "utf8")),
    Buffer.from("bar", "utf8")
  );

  assert("Value-after-delete", k.get(Buffer.from("foo", "utf8")), null);

  k.destroy();
};

run({ forceUseRuntimeFFI: false });
run({ forceUseRuntimeFFI: true });
