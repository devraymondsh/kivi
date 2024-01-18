import { Buffer } from "node:buffer";
import { coreDllPath } from "./dll.js";
import { KiviRuntime } from "./runtime.js";
import { require } from "./require.js";
import { kiviInstanceSize } from "../codegen-generated.js";

let lib = undefined;
let bunFFI = undefined;
export class BunKivi extends KiviRuntime {
  #selfbuf = new ArrayBuffer(kiviInstanceSize);
  #self = bunFFI.ptr(this.#selfbuf);

  value_scratch_buf = new Buffer.alloc(4096);
  value_scratch = bunFFI.ptr(this.value_scratch_buf);

  temp_buf;

  constructor(config) {
    super(config);

    if (!bunFFI) bunFFI = require("bun:ffi");
    if (!lib) {
      lib = bunFFI.dlopen(coreDllPath, {
        kivi_init: {
          args: [bunFFI.FFIType.ptr, bunFFI.FFIType.ptr],
          returns: bunFFI.FFIType.u32,
        },
        kivi_deinit: {
          args: [bunFFI.FFIType.ptr, bunFFI.FFIType.ptr],
        },
        kivi_get: {
          args: [
            bunFFI.FFIType.ptr,
            bunFFI.FFIType.cstring,
            bunFFI.FFIType.usize,
            bunFFI.FFIType.ptr,
            bunFFI.FFIType.usize,
          ],
          returns: bunFFI.FFIType.u32,
        },
        kivi_set: {
          args: [
            bunFFI.FFIType.ptr,
            bunFFI.FFIType.cstring,
            bunFFI.FFIType.usize,
            bunFFI.FFIType.cstring,
            bunFFI.FFIType.usize,
          ],
          returns: bunFFI.FFIType.u32,
        },
        kivi_del: {
          args: [
            bunFFI.FFIType.ptr,
            bunFFI.FFIType.cstring,
            bunFFI.FFIType.usize,
            bunFFI.FFIType.ptr,
            bunFFI.FFIType.usize,
          ],
          returns: bunFFI.FFIType.u32,
        },
        kivi_rm: {
          args: [
            bunFFI.FFIType.ptr,
            bunFFI.FFIType.cstring,
            bunFFI.FFIType.usize,
          ],
        },
      });
    }

    lib.symbols.kivi_init(this.#self, null);
  }

  destroy() {
    return lib.symbols.kivi_deinit(this.#self);
  }

  get(key) {
    const written_len = lib.symbols.kivi_get(
      this.#self,
      bunFFI.ptr(key),
      key.length,
      this.value_scratch,
      this.value_scratch_buf.length
    );
    if (written_len) {
      return this.value_scratch_buf;
    } else {
      if (written_len > this.value_scratch_buf.length) {
        this.temp_buf = Buffer.alloc(written_len);
        lib.symbols.kivi_get(
          this.#self,
          bunFFI.ptr(key),
          key.length,
          bunFFI.ptr(this.temp_buf),
          this.temp_buf.length
        );
        return this.temp_buf;
      }
    }
    return null;
  }
  set(key, value) {
    if (
      !lib.symbols.kivi_set(
        this.#self,
        bunFFI.ptr(key),
        key.length,
        bunFFI.ptr(value),
        value.length
      )
    ) {
      throw new Error("Out of memory!");
    }
  }
  del(key) {
    const written_len = lib.symbols.kivi_del(
      this.#self,
      bunFFI.ptr(key),
      key.length,
      this.value_scratch,
      this.value_scratch_buf.length
    );
    if (written_len) {
      return this.value_scratch_buf;
    } else {
      if (written_len > this.value_scratch_buf.length) {
        this.temp_buf = Buffer.alloc(written_len);
        lib.symbols.kivi_get(
          this.#self,
          bunFFI.ptr(key),
          key.length,
          bunFFI.ptr(this.temp_buf),
          this.temp_buf.length
        );
        return this.temp_buf;
      }
    }
    return null;
  }
  rm(key) {
    lib.symbols.kivi_rm(this.#self, bunFFI.ptr(key), key.length);
  }
}
