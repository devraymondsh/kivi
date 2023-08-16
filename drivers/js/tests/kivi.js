import { Kivi } from "../index.js";

const assert = (name, left, right) => {
  if (left !== right) {
    throw new Error(
      `Assertion '${name}' failed! Left was '${left}' and right was '${right}'.`
    );
  }
};

const c = new Kivi();

assert("Null-if-uninitialized", c.get("foo"), null);

c.set("foo", "bar");

assert("Assert-after-set", c.get("foo"), "bar");

assert("Value-when-delete", c.del("foo"), "bar");

assert("Value-after-delete", c.get("foo"), null);

c.destroy();
