import { require } from "../require.js";
import { KiviRuntime } from "../runtime.js";
import { addonDllPath } from "../dll.js";
import { kiviInstanceSize } from "../../codegen-generated.js";

let addon = undefined;
export class NodeKivi extends KiviRuntime {
  #buf = new ArrayBuffer(kiviInstanceSize);

  constructor(config) {
    super(config);
    if (!addon) addon = require(addonDllPath);

    addon.kivi_init(this.#buf);
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
  rm(key) {
    addon.kivi_rm(this.#buf, key);
  }
}
