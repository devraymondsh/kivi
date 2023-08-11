const addon = require("../zig-out/lib/addon.node");

class NodeJsCollection {
  #buf = new Uint8Array(120);

  init() {
    return addon.CollectionInit(this.#buf);
  }
  deinit() {
    addon.CollectionDeinit(this.#buf);
  }

  get(key) {
    return addon.CollectionGet(this.#buf, key);
  }
  set(key, value) {
    return addon.CollectionSet(this.#buf, key, value);
  }
  rm(key) {
    addon.CollectionRm(this.#buf, key);
  }
}

module.exports = { NodeJsCollection };
