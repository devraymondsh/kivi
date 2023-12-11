const { isBun, isDeno } = await import("../runtime.js");

let utils = undefined;
export let machine = undefined;
export let platform = undefined;
if (isBun()) {
  const {
    bunUtils,
    machine: bunMachine,
    platform: bunPlatform,
  } = await import("./bun.js");
  utils = bunUtils;
  machine = bunMachine;
  platform = bunPlatform;
} else if (isDeno()) {
  const {
    denoUtils,
    machine: denoMachine,
    platform: denoPlatform,
  } = await import("./deno.js");
  utils = denoUtils;
  machine = denoMachine;
  platform = denoPlatform;
}

export class DenoAndBunKivi {
  #array_buf = new ArrayBuffer(56);
  #buf = utils.makeBufferPtr(this.#array_buf);

  #key_scratch = new Uint8Array(4096);
  #key_scratch_ptr = utils.makeBufferPtr(this.#key_scratch);

  #value_scratch = new Uint8Array(4096);
  #value_scratch_ptr = utils.makeBufferPtr(this.#value_scratch);

  init() {
    return utils.symbols.kivi_init(this.#buf, null);
  }
  destroy() {
    return utils.symbols.kivi_deinit(this.#buf);
  }

  get(key) {
    const encoded_str = new TextEncoder().encodeInto(key, this.#key_scratch);
    const written_len = utils.symbols.kivi_get(
      this.#buf,
      this.#key_scratch_ptr,
      encoded_str.written,
      this.#value_scratch_ptr,
      4096
    );

    if (written_len != 0) {
      return new TextDecoder().decode(
        this.#value_scratch.subarray(0, written_len)
      );
    }

    return null;
  }
  set(key, value) {
    const key_len = new TextEncoder().encodeInto(
      key,
      this.#key_scratch
    ).written;
    const value_len = new TextEncoder().encodeInto(
      value,
      this.#value_scratch
    ).written;

    return utils.symbols.kivi_set(
      this.#buf,
      this.#key_scratch_ptr,
      key_len,
      this.#value_scratch_ptr,
      value_len
    );
  }
  del(key) {
    const key_len = new TextEncoder().encodeInto(
      key,
      this.#key_scratch
    ).written;
    const written_len = utils.symbols.kivi_del(
      this.#buf,
      this.#key_scratch_ptr,
      key_len,
      this.#value_scratch_ptr,
      4096
    );

    if (written_len != 0) {
      return new TextDecoder().decode(
        this.#value_scratch.subarray(0, written_len)
      );
    }

    return null;
  }
}
