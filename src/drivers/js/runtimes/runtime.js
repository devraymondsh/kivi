export class KiviRuntime {
  /**
   * Initializes Kivi
   * @param {?Config} config
   */
  constructor(config) {}

  /**
   * Releases the allocated memory and deinitializes Kivi.
   * @returns {void}
   */
  destroy() {
    throw new Error('the method "destroy" should be implemented');
  }

  /**
   * Returns the value of the given key.
   * @param {Buffer} key
   * @returns {(Buffer|null)}
   */
  get(key) {
    throw new Error('the method "get" should be implemented');
  }

  /**
   * Sets a key to the given value.
   * @param {Buffer} key
   * @param {Buffer} value
   * @returns {boolean}
   */
  set(key, value) {
    throw new Error('the method "set" should be implemented');
  }

  /**
   * Removes a key with its value and returns it.
   * @param {Buffer} key
   * @returns {Buffer}
   */
  del(key) {
    throw new Error('the method "del" should be implemented');
  }

  /**
   * Removes a key with its value.
   * @param {Buffer} key
   * @returns {void}
   */
  rm(key) {
    throw new Error('the method "rm" should be implemented');
  }
}
