import path from "node:path";
import { fileURLToPath } from "node:url";

function isNodeJS() {
  return typeof global !== "undefined" && globalThis === global;
}
if (isNodeJS()) {
  if (Number(process.versions.node.split(".")[0]) < 14) {
    throw new Error("Kivi requires Nodejs version 14 or higher.");
  }
}

let RuntimeKivi;
const { NodeKivi } = await import(
  path.resolve(path.dirname(fileURLToPath(import.meta.url)), "nodejs/index.js")
);
const { getRuntimeKind } = await import(
  path.resolve(path.dirname(fileURLToPath(import.meta.url)), "runtime.js")
);
switch (getRuntimeKind()) {
  case "bun":
  case "deno":
    const { DenoAndBunKivi } = await import(
      path.resolve(
        path.dirname(fileURLToPath(import.meta.url)),
        "./deno&bun/index.js"
      )
    );
    RuntimeKivi = DenoAndBunKivi;
    break;
  case "node":
    RuntimeKivi = NodeKivi;
    break;
  default:
    throw new Error(
      "Invalid runtime! Kivi only supports Bun, Deno, and Nodejs."
    );
}

export class Kivi {
  #InnerKivi;

  /**
   * Returns the value of the given key
   * @param {{ forceUseRuntimeFFI: ?bool }} config
   */
  constructor(config) {
    if (config?.forceUseRuntimeFFI) {
      this.#InnerKivi = new RuntimeKivi();
    } else {
      this.#InnerKivi = new NodeKivi();
    }

    if (!this.#InnerKivi.init()) {
      console.log(this.#InnerKivi.init());
      throw new Error(`Failed to initialize a Kivi!`);
    }
  }
  destroy() {
    this.#InnerKivi.destroy();
  }

  /**
   * Returns the value of the given key
   * @param {string} key
   * @returns {(string|null)}
   */
  get(key) {
    return this.#InnerKivi.get(key);
  }
  /**
   * Sets a key to the given value
   * @param {string} key
   * @param {string} value
   * @returns {void}
   */
  set(key, value) {
    if (!this.#InnerKivi.set(key, value)) {
      throw new Error("Failed to insert!");
    }
  }
  /**
   * Removes a key with its value
   * @param {string} key
   * @returns {void}
   */
  del(/** @type {string} */ key) {
    return this.#InnerKivi.del(key);
  }
}
