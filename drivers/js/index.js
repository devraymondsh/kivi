function isNodeJS() {
  return typeof global !== "undefined" && globalThis === global;
}
if (isNodeJS()) {
  if (Number(process.versions.node.split(".")[0]) < 14) {
    throw new Error("Kivi requires Nodejs version 14 or higher.");
  }
}

let RuntimeCollection;
const { getRuntimeKind } = await import("./runtime.js");
switch (getRuntimeKind()) {
  case "bun":
  case "deno":
    const { DenoAndBunCollection } = await import("./deno&bun/index.js");
    RuntimeCollection = DenoAndBunCollection;
    break;
  case "node":
    const { NodeCollection } = await import("./nodejs/src/index.js");
    RuntimeCollection = NodeCollection;
    break;
  default:
    throw new Error(
      "Invalid runtime! Kivi only supports Bun, Deno, and Nodejs."
    );
}

export class Collection {
  #InnerCollectionClass = new RuntimeCollection();

  constructor() {
    if (this.#InnerCollectionClass.init() !== 0) {
      throw new Error(`Failed to initialize a collection! ${res}`);
    }
  }
  destroy() {
    this.#InnerCollectionClass.destroy();
  }

  get(/** @type {string} */ key) {
    if (key.length > 4096) {
      throw new Error("Key is too long!");
    }

    return this.#InnerCollectionClass.get(key);
  }
  set(/** @type {string} */ key, /** @type {string} */ value) {
    if (key.length > 4096) {
      throw new Error("Key is too long!");
    }
    if (value.length > 4096) {
      throw new Error("Value is too long!");
    }

    if (this.#InnerCollectionClass.set(key, value)) {
      throw new Error("Failed to insert!");
    } else {
      return 0;
    }
  }
  rm(/** @type {string} */ key) {
    this.#InnerCollectionClass.rm(key);
  }
}

let c = new Collection();

c.set("foo", "bar");
console.log([c.get("foo")]);
c.rm("foo");
console.log([c.get("foo")]);

c.destroy();
