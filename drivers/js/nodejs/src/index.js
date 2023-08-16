import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const addon = require("../zig-out/lib/addon.node");

export class NodeKivi {
  #buf = new ArrayBuffer(120);

  init() {
    return addon.kivi_init(this.#buf);
  }
  destroy() {
    return addon.kivi_deinit(this.#buf);
  }

  get(key) {
    return addon.kivi_get(this.#buf, key);
  }
  set(key, value) {
    return addon.kivi_set(this.#buf, key, value);
  }
  del(key) {
    return addon.kivi_del(this.#buf, key);
  }
}
