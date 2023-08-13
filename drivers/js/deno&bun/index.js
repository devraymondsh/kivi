const { isBun, isDeno } = await import("../runtime.js");

var utils = undefined;
if (isBun()) {
  const { bunUtils } = await import("./bun.js");
  utils = bunUtils;
} else if (isDeno()) {
  const { denoUtils } = await import("./deno.js");
  utils = denoUtils;
}

export class DenoAndBunCollection {
  #buf = new ArrayBuffer(120);
  #ptr = utils.makeBufferPtr(this.#buf);

  #str_buf = new ArrayBuffer(16);
  #str_ptr = utils.makeBufferPtr(this.#str_buf);
  #str_dv = new DataView(this.#str_buf);

  #key_scratch = new Uint8Array(4096);
  #key_scratch_ptr = utils.makeBufferPtr(this.#key_scratch);
  value_scratch = new Uint8Array(4096);
  #value_scratch_ptr = utils.makeBufferPtr(this.value_scratch);

  init() {
    return utils.symbols.CollectionInit(this.#ptr);
  }
  destroy() {
    return utils.symbols.CollectionDeinit(this.#ptr);
  }

  get(key) {
    const res = new TextEncoder().encodeInto(key, this.#key_scratch);
    utils.symbols.CollectionGet(
      this.#ptr,
      this.#str_ptr,
      this.#key_scratch_ptr,
      res.written
    );

    const addr = this.#str_dv.getBigUint64(0, true);
    const len = Number(this.#str_dv.getBigUint64(8, true));

    return utils.cstringToJs(addr, len, this.value_scratch);
  }
  set(key, value) {
    const key_len = new TextEncoder().encodeInto(
      key,
      this.#key_scratch
    ).written;
    const value_len = new TextEncoder().encodeInto(
      value,
      this.value_scratch
    ).written;

    return utils.symbols.CollectionSet(
      this.#ptr,
      this.#key_scratch_ptr,
      key_len,
      this.#value_scratch_ptr,
      value_len
    );
  }
  rm(key) {
    const key_len = new TextEncoder().encodeInto(
      key,
      this.#key_scratch
    ).written;

    // TODO: Replace the line below with CollectionRm.
    return utils.symbols.CollectionRmOut(
      this.#ptr,
      this.#key_scratch_ptr,
      key_len
    );
  }
}
