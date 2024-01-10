import os from "node:os";
import path from "node:path";
import { Buffer } from "node:buffer";
import { dlopen, FFIType, suffix, ptr } from "bun:ffi";

export const machine = os.machine();
export let platform = os.platform();
let libNamePrefix = "lib";
if (platform == "win32") {
  platform = "windows";
}
if (platform == "windows") {
  libNamePrefix = "";
}
const dllPath = path.join(
  __dirname,
  `../../../../zig-out/lib/${libNamePrefix}kivi-${machine}-${platform}.${suffix}`
);
export const lib = dlopen(dllPath, {
  kivi_init: {
    args: [FFIType.ptr, FFIType.ptr],
    returns: FFIType.u32,
  },
  kivi_deinit: {
    args: [FFIType.ptr, FFIType.ptr],
  },
  kivi_get: {
    args: [
      FFIType.ptr,
      FFIType.cstring,
      FFIType.usize,
      FFIType.ptr,
      FFIType.usize,
    ],
    returns: FFIType.u32,
  },
  kivi_set: {
    args: [
      FFIType.ptr,
      FFIType.cstring,
      FFIType.usize,
      FFIType.cstring,
      FFIType.usize,
    ],
    returns: FFIType.u32,
  },
  kivi_del: {
    args: [
      FFIType.ptr,
      FFIType.cstring,
      FFIType.usize,
      FFIType.ptr,
      FFIType.usize,
    ],
    returns: FFIType.u32,
  },
  kivi_rm: {
    args: [FFIType.ptr, FFIType.cstring, FFIType.usize],
  },
});

export class BunKivi {
  #selfbuf = new ArrayBuffer(72);
  #self = ptr(this.#selfbuf);

  value_scratch_buf = new Buffer.alloc(4096);
  value_scratch = ptr(this.value_scratch_buf);

  temp_buf;

  init() {
    return lib.symbols.kivi_init(this.#self, null);
  }
  destroy() {
    return lib.symbols.kivi_deinit(this.#self);
  }

  get(key) {
    const written_len = lib.symbols.kivi_get(
      this.#self,
      ptr(key),
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
          ptr(key),
          key.length,
          ptr(this.temp_buf),
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
        ptr(key),
        key.length,
        ptr(value),
        value.length
      )
    ) {
      throw new Error("Out of memory!");
    }
  }
  del(key) {
    const written_len = lib.symbols.kivi_del(
      this.#self,
      ptr(key),
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
          ptr(key),
          key.length,
          ptr(this.temp_buf),
          this.temp_buf.length
        );
        return this.temp_buf;
      }
    }
    return null;
  }
  rm(key) {
    lib.symbols.kivi_rm(this.#self, ptr(key), key.length);
  }
}
