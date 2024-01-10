import path from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
import { isDeno, isNodeJS, isBun } from "../runtime.js";

const require = createRequire(import.meta.url);

let machine = undefined;
let platform = undefined;
if (isNodeJS()) {
  const os = require("os");
  machine = os.machine();
  platform = os.platform();
} else {
  if (isBun()) {
    const { machine: bunMachine, platform: bunPlatform } = await import(
      path.resolve(
        path.dirname(fileURLToPath(import.meta.url)),
        "../deno&bun/bun.js"
      )
    );
    machine = bunMachine;
    platform = bunPlatform;
  } else if (isDeno()) {
    const { machine: denoMachine, platform: denoPlatform } = await import(
      path.resolve(
        path.dirname(fileURLToPath(import.meta.url)),
        "../deno&bun/deno.js"
      )
    );
    machine = denoMachine;
    platform = denoPlatform;
  }
}
if (platform == "win32") {
  platform = "windows";
}

const addonPath = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  `../../../../zig-out/lib/kivi-addon-${machine}-${platform}.node`
);
const addon = require(addonPath);
export class NodeKivi {
  #buf = new ArrayBuffer(72);

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
  rm(key) {
    return addon.kivi_rm(this.#buf, key);
  }
}
