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
   * Initializes Kivi
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
  /**
   * Releases the allocated memory and deinitializes Kivi.
   * @returns {void}
   */
  destroy() {
    this.#InnerKivi.destroy();
  }

  /**
   * Returns the value of the given key.
   * @param {string} key
   * @returns {(string|null)}
   */
  get(key) {
    return this.#InnerKivi.get(key);
  }
  /**
   * Returns values of given keys.
   * This function is noticeably faster when multiple data is given due to process in parallel.
   * @param {string[]} keys
   * @returns {(string|null)[]}
   */
  bulkGet(keys) {
    return this.#InnerKivi.bulkGet(keys);
  }

  /**
   * Sets a key to the given value.
   * @param {string} key
   * @param {string} value
   * @returns {boolean}
   */
  set(key, value) {
    if (!this.#InnerKivi.set(key, value)) {
      throw new Error("Failed to insert!");
    }
  }
  /**
   * Sets values to given keys.
   * This function is noticeably faster when multiple data is given due to process in parallel.
   * @param {{key: string, value: string}[]} data
   * @returns {boolean[]}
   */
  bulkSet(data) {
    return this.#InnerKivi.bulkSet(data);
  }

  /**
   * Removes a key with its value.
   * @param {string} key
   * @returns {void}
   */
  del(key) {
    return this.#InnerKivi.del(key);
  }
  /**
   * Removes a key with its value and returns the value.
   * @param {string} key
   * @returns {string}
   */
  fetchDel(key) {
    return this.#InnerKivi.fetchDel(key);
  }
  /**
   * Removes keys with their values and returns the values.
   * This function is noticeably faster when multiple data is given due to process in parallel.
   * @param {string[]} keys
   * @returns {string[]}
   */
  bulkFetchDel(keys) {
    return this.#InnerKivi.bulkFetchDel(keys);
  }
  /**
   * Removes keys with their values.
   * This function is noticeably faster when multiple data is given due to process in parallel.
   * @param {string[]} keys
   * @returns {void}
   */
  bulkDel(keys) {
    return this.#InnerKivi.bulkDel(keys);
  }
}
