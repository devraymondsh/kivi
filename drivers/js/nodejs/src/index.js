import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const addon = require("../zig-out/lib/addon.node");

export class NodeCollection {
  #buf = new ArrayBuffer(120);

  init() {
    return addon.CollectionInit(this.#buf);
  }
  destroy() {
    return addon.CollectionDeinit(this.#buf);
  }

  get(key) {
    return addon.CollectionGet(this.#buf, key);
  }
  set(key, value) {
    return addon.CollectionSet(this.#buf, key, value);
  }
  rm(key) {
    return addon.CollectionRm(this.#buf, key);
  }
}
